import { assertEquals } from "jsr:@std/assert@1";
import type { PlannedSession } from "../_shared/scheduler/mod.ts";
import { diffPlans } from "./diff.ts";

const s = (taskId: string, stepId: string, start: number, end: number): PlannedSession => ({
  taskId,
  stepId,
  start,
  end,
  pinned: false,
});

Deno.test("sesi sama tidak muncul di diff", () => {
  const d = diffPlans([s("A", "A1", 0, 10)], [s("A", "A1", 0, 10)]);
  assertEquals(d, { added: [], moved: [], removed: [], affectedTaskIds: [] });
});

Deno.test("sesi bergeser muncul di moved", () => {
  const d = diffPlans([s("A", "A1", 0, 10)], [s("A", "A1", 20, 30)]);
  assertEquals(d.moved, [{ from: s("A", "A1", 0, 10), to: s("A", "A1", 20, 30) }]);
  assertEquals(d.affectedTaskIds, ["A"]);
});

Deno.test("sesi baru dan sesi hilang dipisahkan", () => {
  const d = diffPlans(
    [s("B", "B1", 0, 10), s("B", "B1", 20, 30)],
    [s("B", "B1", 0, 10), s("C", "C1", 40, 50)],
  );
  assertEquals(d.added, [s("C", "C1", 40, 50)]);
  assertEquals(d.removed, [s("B", "B1", 20, 30)]);
});

Deno.test("affectedTaskIds unik dan terurut", () => {
  const d = diffPlans(
    [s("B", "B1", 0, 10), s("A", "A1", 0, 10)],
    [s("B", "B1", 5, 15), s("A", "A1", 5, 15), s("A", "A1", 20, 30)],
  );
  assertEquals(d.affectedTaskIds, ["A", "B"]);
});
