import { buildFreeSlots, localDayKey, type PinnedSlot, type SchedulerInput } from "../_shared/scheduler/mod.ts";

export type PostponeReason = "outside_study_window" | "overlaps_busy" | "after_deadline" | "daily_cap" | "in_past";
export type PostponeCheck = { ok: true; pinned: PinnedSlot } | { ok: false; reason: PostponeReason };

const MIN = 60_000;

/** Validates a user-chosen time for a postponed session; the session keeps its length. */
export function checkManualSlot(
  input: SchedulerInput,
  session: { taskId: string; stepId: string; start: number; end: number },
  newStart: number,
): PostponeCheck {
  const newEnd = newStart + (session.end - session.start);
  if (newStart < input.now) return { ok: false, reason: "in_past" };

  const windows = buildFreeSlots({
    now: input.now,
    timezone: input.timezone,
    horizonDays: input.horizonDays,
    studyWindows: input.prefs.studyWindows,
    busy: [],
  });
  if (!windows.some((w) => w.start <= newStart && newEnd <= w.end)) {
    return { ok: false, reason: "outside_study_window" };
  }

  const taken = [...input.busy, ...input.fixedSessions];
  if (taken.some((b) => b.start < newEnd && newStart < b.end)) return { ok: false, reason: "overlaps_busy" };

  const deadline = input.tasks.find((t) => t.id === session.taskId)?.officialDeadline ?? null;
  if (deadline !== null && newEnd > deadline) return { ok: false, reason: "after_deadline" };

  const day = localDayKey(newStart, input.timezone);
  const usedThatDay = input.fixedSessions
    .filter((f) => localDayKey(f.start, input.timezone) === day)
    .reduce((sum, f) => sum + (f.end - f.start) / MIN, 0);
  if (usedThatDay + (newEnd - newStart) / MIN > input.prefs.maxDailyMinutes) {
    return { ok: false, reason: "daily_cap" };
  }

  return { ok: true, pinned: { taskId: session.taskId, stepId: session.stepId, start: newStart, end: newEnd } };
}
