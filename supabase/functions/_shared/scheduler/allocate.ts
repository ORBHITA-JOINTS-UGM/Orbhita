import { DateTime } from "../deps.ts";
import { buildFreeSlots, localDayKey, subtractIntervals } from "./slots.ts";
import type {
  Interval,
  Ms,
  PlannedSession,
  Priority,
  SchedulerInput,
  SchedulerOutput,
  StepInput,
  TaskInput,
  TaskResult,
  Unscheduled,
} from "./types.ts";

const MIN = 60_000;
const DAY_MS = 24 * 60 * MIN;
const MIN_CHUNK = 10;
const PRIORITY_RANK: Record<Priority, number> = { high: 0, normal: 1, low: 2 };

const minutes = (i: Interval) => Math.round((i.end - i.start) / MIN);

function nextLocalMidnight(t: Ms, tz: string): Ms {
  return DateTime.fromMillis(t, { zone: tz }).startOf("day").plus({ days: 1 }).toMillis();
}

/** Splits intervals at local midnights so each piece belongs to one local day. */
function splitByDay(list: Interval[], tz: string): Interval[] {
  const out: Interval[] = [];
  for (const i of list) {
    let start = i.start;
    while (start < i.end) {
      const end = Math.min(i.end, nextLocalMidnight(start, tz));
      out.push({ start, end });
      start = end;
    }
  }
  return out;
}

/** Steps in dependency order; ties broken by orderIndex then id. */
function topoSort(steps: StepInput[]): StepInput[] {
  const byId = new Map(steps.map((s) => [s.id, s]));
  const pending = new Map(steps.map((s) => [s.id, s.dependsOn.filter((d) => byId.has(d)).length]));
  const cmp = (a: StepInput, b: StepInput) => a.orderIndex - b.orderIndex || a.id.localeCompare(b.id);
  const out: StepInput[] = [];
  let ready = steps.filter((s) => pending.get(s.id) === 0).sort(cmp);
  while (ready.length) {
    const cur = ready.shift()!;
    out.push(cur);
    for (const s of steps) {
      if (!s.dependsOn.includes(cur.id)) continue;
      const left = pending.get(s.id)! - 1;
      pending.set(s.id, left);
      if (left === 0) ready = [...ready, s].sort(cmp);
    }
  }
  // Cycles are rejected by the database; keep any leftovers in a stable order anyway.
  const placed = new Set(out.map((s) => s.id));
  return [...out, ...steps.filter((s) => !placed.has(s.id)).sort(cmp)];
}

export function planSchedule(input: SchedulerInput): SchedulerOutput {
  const { now, timezone: tz, prefs } = input;
  const horizonEnd = now + input.horizonDays * DAY_MS;
  const pinned = input.pinned ?? [];

  let free = buildFreeSlots({
    now,
    timezone: tz,
    horizonDays: input.horizonDays,
    studyWindows: prefs.studyWindows,
    busy: [...input.busy, ...input.fixedSessions, ...pinned, ...(input.blocked ?? [])],
  });

  const dailyUsed = new Map<string, number>();
  const addDaily = (t: Ms, m: number) => {
    const k = localDayKey(t, tz);
    dailyUsed.set(k, (dailyUsed.get(k) ?? 0) + m);
  };
  for (const s of [...input.fixedSessions, ...pinned]) addDaily(s.start, minutes(s));

  // Capacity snapshot before any allocation, used for the capacity summary.
  const initialFree = splitByDay(free, tz);
  const initialDaily = new Map(dailyUsed);
  const capacityBefore = (t: Ms): number => {
    const perDay = new Map<string, number>();
    for (const i of initialFree) {
      if (i.start >= t) continue;
      const k = localDayKey(i.start, tz);
      perDay.set(k, (perDay.get(k) ?? 0) + minutes({ start: i.start, end: Math.min(i.end, t) }));
    }
    let total = 0;
    for (const [k, m] of perDay) {
      total += Math.max(0, Math.min(m, prefs.maxDailyMinutes - (initialDaily.get(k) ?? 0)));
    }
    return total;
  };

  const sessions: PlannedSession[] = pinned.map((p) => ({ ...p, pinned: true }));
  const unscheduled: Unscheduled[] = [];
  const perTask: TaskResult[] = [];

  const active = input.tasks.filter((t) =>
    t.steps.some((s) => s.status !== "done" && s.remainingMinutes > 0)
  );
  const remainingOf = (t: TaskInput) =>
    t.steps.reduce((sum, s) => sum + (s.status === "done" ? 0 : s.remainingMinutes), 0);

  const schedulable: TaskInput[] = [];
  for (const t of active) {
    if (t.officialDeadline === null || t.officialDeadline <= now) {
      const reason = t.officialDeadline === null ? "missing_deadline" : "overdue";
      unscheduled.push({ taskId: t.id, stepId: null, minutes: remainingOf(t), reason });
      perTask.push({
        taskId: t.id,
        risk: reason,
        remainingMinutes: remainingOf(t),
        allocatedMinutes: 0,
        unallocatedMinutes: remainingOf(t),
        capacityBeforeTarget: null,
        capacityBeforeDeadline: null,
        lastSessionEnd: null,
      });
    } else {
      schedulable.push(t);
    }
  }
  schedulable.sort((a, b) =>
    a.officialDeadline! - b.officialDeadline! ||
    PRIORITY_RANK[a.priority] - PRIORITY_RANK[b.priority] ||
    a.createdAt - b.createdAt ||
    a.id.localeCompare(b.id)
  );

  /** Places one session for the step; returns its length in minutes, or 0 if nothing fits. */
  const placeOne = (taskId: string, stepId: string, remaining: number, earliest: Ms, deadline: Ms): number => {
    const minLen = Math.min(MIN_CHUNK, remaining);
    for (const slot of free) {
      let s = Math.max(slot.start, earliest);
      const hardEnd = Math.min(slot.end, deadline);
      while (s < hardEnd) {
        const limit = Math.min(hardEnd, nextLocalMidnight(s, tz));
        const dayLeft = prefs.maxDailyMinutes - (dailyUsed.get(localDayKey(s, tz)) ?? 0);
        const len = Math.min(prefs.sessionMinutes, remaining, Math.floor((limit - s) / MIN), dayLeft);
        if (len >= minLen && len > 0) {
          const end = s + len * MIN;
          sessions.push({ taskId, stepId, start: s, end, pinned: false });
          addDaily(s, len);
          free = subtractIntervals(free, [{ start: s, end: end + prefs.breakMinutes * MIN }]);
          return len;
        }
        s = limit;
      }
      if (slot.start >= deadline) break;
    }
    return 0;
  };

  for (const t of schedulable) {
    const deadline = t.officialDeadline!;
    let allocated = 0;
    let unallocatedNoCapacity = 0;
    let unallocatedBeyond = 0;
    const lastEnd = new Map<string, Ms>();
    const blocked = new Set<string>();
    for (const p of pinned.filter((p) => p.taskId === t.id)) {
      lastEnd.set(p.stepId, Math.max(lastEnd.get(p.stepId) ?? 0, p.end));
      allocated += minutes(p);
    }
    for (const f of input.fixedSessions.filter((f) => f.taskId === t.id)) {
      lastEnd.set(f.stepId, Math.max(lastEnd.get(f.stepId) ?? 0, f.end));
    }

    for (const st of topoSort(t.steps)) {
      if (st.status === "done") continue;
      let remaining = st.remainingMinutes -
        pinned.filter((p) => p.stepId === st.id).reduce((sum, p) => sum + minutes(p), 0);
      if (remaining <= 0) continue;

      const deps = st.dependsOn.filter((d) => t.steps.some((s) => s.id === d && s.status !== "done"));
      if (deps.some((d) => blocked.has(d))) {
        blocked.add(st.id);
        unscheduled.push({ taskId: t.id, stepId: st.id, minutes: remaining, reason: "blocked_by_dependency" });
        unallocatedNoCapacity += remaining;
        continue;
      }
      const earliest = Math.max(now, ...deps.map((d) => lastEnd.get(d) ?? now));

      while (remaining > 0) {
        const len = placeOne(t.id, st.id, remaining, earliest, deadline);
        if (len === 0) break;
        remaining -= len;
        allocated += len;
        const placed = sessions[sessions.length - 1];
        lastEnd.set(st.id, Math.max(lastEnd.get(st.id) ?? 0, placed.end));
      }
      if (remaining > 0) {
        blocked.add(st.id);
        const reason = deadline > horizonEnd ? "beyond_horizon" : "no_capacity";
        unscheduled.push({ taskId: t.id, stepId: st.id, minutes: remaining, reason });
        if (reason === "beyond_horizon") unallocatedBeyond += remaining;
        else unallocatedNoCapacity += remaining;
      }
    }

    const ends = sessions.filter((s) => s.taskId === t.id).map((s) => s.end);
    const lastSessionEnd = ends.length ? Math.max(...ends) : null;
    const unallocated = unallocatedNoCapacity + unallocatedBeyond;
    const target = t.personalTarget;
    let risk: TaskResult["risk"] = "ok";
    if (unallocatedNoCapacity > 0) risk = "deadline_risk";
    else if (target !== null && (unallocated > 0 || (lastSessionEnd !== null && lastSessionEnd > target))) {
      risk = "target_risk";
    }
    perTask.push({
      taskId: t.id,
      risk,
      remainingMinutes: remainingOf(t),
      allocatedMinutes: allocated,
      unallocatedMinutes: unallocated,
      capacityBeforeTarget: target === null ? null : capacityBefore(target),
      capacityBeforeDeadline: capacityBefore(deadline),
      lastSessionEnd,
    });
  }

  sessions.sort((a, b) => a.start - b.start || a.taskId.localeCompare(b.taskId));
  const totals = perTask.reduce(
    (acc, r) => ({
      remainingMinutes: acc.remainingMinutes + r.remainingMinutes,
      allocatedMinutes: acc.allocatedMinutes + r.allocatedMinutes,
      unallocatedMinutes: acc.unallocatedMinutes + r.unallocatedMinutes,
    }),
    { remainingMinutes: 0, allocatedMinutes: 0, unallocatedMinutes: 0 },
  );
  return { sessions, perTask, unscheduled, totals };
}
