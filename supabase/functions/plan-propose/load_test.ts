import { assertEquals } from "jsr:@std/assert@1";
import { toSchedulerInput } from "./load.ts";
import { iso, J, NOW, rows } from "./fixtures_test_util.ts";

const activity = (over: Record<string, unknown>) => ({
  id: "act",
  start_at: iso("2026-10-08T19:00"),
  end_at: iso("2026-10-08T20:00"),
  busy: true,
  locked: true,
  deleted_at: null,
  ...over,
});

Deno.test("preferensi dan zona waktu dipetakan", () => {
  const input = toSchedulerInput(rows(), NOW);
  assertEquals(input.timezone, "Asia/Jakarta");
  assertEquals(input.horizonDays, 30);
  assertEquals(input.prefs.sessionMinutes, 120);
  assertEquals(input.prefs.studyWindows.length, 2);
  assertEquals(input.tasks[0].officialDeadline, J("2026-10-09T21:00"));
  assertEquals(input.tasks[0].steps[0].remainingMinutes, 60);
});

Deno.test("tugas dan langkah terhapus diabaikan", () => {
  const r = rows();
  r.tasks.push({ ...r.tasks[0], id: "B", deleted_at: iso("2026-10-08T07:00") });
  r.steps.push({ ...r.steps[0], id: "A2", deleted_at: iso("2026-10-08T07:00") });
  const input = toSchedulerInput(r, NOW);
  assertEquals(input.tasks.map((t) => t.id), ["A"]);
  assertEquals(input.tasks[0].steps.map((s) => s.id), ["A1"]);
});

Deno.test("aktivitas busy atau locked menjadi busy", () => {
  const input = toSchedulerInput(rows({
    activities: [
      activity({ id: "x", busy: true, locked: false }),
      activity({ id: "y", busy: false, locked: true }),
    ],
  }), NOW);
  assertEquals(input.busy.length, 2);
});

Deno.test("aktivitas tidak busy dan tidak locked tidak memblokir", () => {
  const input = toSchedulerInput(rows({ activities: [activity({ busy: false, locked: false })] }), NOW);
  assertEquals(input.busy, []);
});

Deno.test("sesi aktif in_progress dan completed menjadi fixedSessions, planned tidak", () => {
  const session = (id: string, status: string) => ({
    id,
    task_id: "A",
    step_id: "A1",
    start_at: iso("2026-10-08T19:00"),
    end_at: iso("2026-10-08T19:30"),
    status,
  });
  const input = toSchedulerInput(rows({
    activeSessions: [session("s1", "completed"), session("s2", "in_progress"), session("s3", "planned")],
  }), NOW);
  assertEquals(input.fixedSessions.length, 2);
});

Deno.test("dependensi dipetakan ke dependsOn", () => {
  const r = rows();
  r.steps.push({ ...r.steps[0], id: "A2", order_index: 1 });
  r.dependencies = [{ step_id: "A2", depends_on_id: "A1" }];
  const input = toSchedulerInput(r, NOW);
  assertEquals(input.tasks[0].steps.find((s) => s.id === "A2")?.dependsOn, ["A1"]);
});
