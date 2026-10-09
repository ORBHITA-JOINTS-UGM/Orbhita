import { assertEquals } from "jsr:@std/assert@1";
import { toSchedulerInput } from "./load.ts";
import { checkManualSlot } from "./postpone.ts";
import { iso, J, NOW, rows } from "./fixtures_test_util.ts";

const session = { taskId: "A", stepId: "A1", start: J("2026-10-08T19:00"), end: J("2026-10-08T19:30") };

function reason(newStart: number, over = {}) {
  const r = checkManualSlot(toSchedulerInput(rows(over), NOW), session, newStart);
  return r.ok ? "ok" : r.reason;
}

Deno.test("slot valid menghasilkan pinned dengan durasi sama", () => {
  const r = checkManualSlot(toSchedulerInput(rows(), NOW), session, J("2026-10-09T19:00"));
  assertEquals(r, { ok: true, pinned: { taskId: "A", stepId: "A1", start: J("2026-10-09T19:00"), end: J("2026-10-09T19:30") } });
});

Deno.test("slot di masa lalu ditolak in_past", () => {
  assertEquals(reason(J("2026-10-08T07:00")), "in_past");
});

Deno.test("slot di luar jendela belajar ditolak outside_study_window", () => {
  assertEquals(reason(J("2026-10-09T15:00")), "outside_study_window");
  assertEquals(reason(J("2026-10-09T20:45")), "outside_study_window"); // ends 21:15
});

Deno.test("slot bentrok kegiatan ditolak overlaps_busy", () => {
  const activities = [{
    id: "x",
    start_at: iso("2026-10-09T19:15"),
    end_at: iso("2026-10-09T20:00"),
    busy: true,
    locked: true,
    deleted_at: null,
  }];
  assertEquals(reason(J("2026-10-09T19:00"), { activities }), "overlaps_busy");
});

Deno.test("slot setelah deadline ditolak after_deadline", () => {
  const r = rows();
  r.tasks[0].official_deadline = iso("2026-10-09T19:15");
  assertEquals(checkManualSlot(toSchedulerInput(r, NOW), session, J("2026-10-09T19:00")).ok, false);
  const res = checkManualSlot(toSchedulerInput(r, NOW), session, J("2026-10-09T19:00"));
  assertEquals(res.ok ? "ok" : res.reason, "after_deadline");
});

Deno.test("slot yang melewati batas harian ditolak daily_cap", () => {
  const r = rows();
  r.prefs.max_daily_minutes = 30;
  r.activeSessions = [{
    id: "f",
    task_id: "A",
    step_id: "A1",
    start_at: iso("2026-10-09T20:00"),
    end_at: iso("2026-10-09T20:15"),
    status: "completed",
  }];
  const res = checkManualSlot(toSchedulerInput(r, NOW), session, J("2026-10-09T19:00"));
  assertEquals(res.ok ? "ok" : res.reason, "daily_cap");
});
