import type { PlannedSession } from "../_shared/scheduler/mod.ts";

export interface PlanDiff {
  added: PlannedSession[];
  moved: { from: PlannedSession; to: PlannedSession }[];
  removed: PlannedSession[];
  affectedTaskIds: string[];
}

function byStep(list: PlannedSession[]): Map<string, PlannedSession[]> {
  const map = new Map<string, PlannedSession[]>();
  for (const s of [...list].sort((a, b) => a.start - b.start)) {
    map.set(s.stepId, [...(map.get(s.stepId) ?? []), s]);
  }
  return map;
}

/** Pairs sessions of the same step in time order; unpaired ones are added or removed. */
export function diffPlans(active: PlannedSession[], proposed: PlannedSession[]): PlanDiff {
  const before = byStep(active);
  const after = byStep(proposed);
  const diff: PlanDiff = { added: [], moved: [], removed: [], affectedTaskIds: [] };

  for (const stepId of new Set([...before.keys(), ...after.keys()])) {
    const a = before.get(stepId) ?? [];
    const b = after.get(stepId) ?? [];
    for (let i = 0; i < Math.max(a.length, b.length); i++) {
      if (a[i] && b[i]) {
        if (a[i].start !== b[i].start || a[i].end !== b[i].end) diff.moved.push({ from: a[i], to: b[i] });
      } else if (b[i]) {
        diff.added.push(b[i]);
      } else {
        diff.removed.push(a[i]);
      }
    }
  }

  const ids = [...diff.added, ...diff.removed, ...diff.moved.map((m) => m.to)].map((s) => s.taskId);
  diff.affectedTaskIds = [...new Set(ids)].sort();
  return diff;
}
