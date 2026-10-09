import { assert, assertEquals } from "jsr:@std/assert@1";
import { planSchedule } from "./mod.ts";
import { localDayKey } from "./slots.ts";
import type {
  Interval,
  SchedulerInput,
  SchedulerOutput,
  StepInput,
  StudyWindow,
  TaskInput,
} from "./types.ts";

const TZ = "Asia/Jakarta";
/** Local Jakarta time, e.g. J("2026-10-08T19:00"). 2026-10-08 is a Thursday. */
const J = (s: string) => Date.parse(`${s}:00+07:00`);
const MIN = 60_000;

function step(id: string, minutes: number, extra: Partial<StepInput> = {}): StepInput {
  return { id, title: id, orderIndex: 0, remainingMinutes: minutes, status: "not_started", dependsOn: [], ...extra };
}

function task(
  id: string,
  opts: { deadline?: string | null; target?: string | null; priority?: TaskInput["priority"]; createdAt?: number; steps: StepInput[] },
): TaskInput {
  return {
    id,
    title: id,
    officialDeadline: opts.deadline ? J(opts.deadline) : null,
    personalTarget: opts.target ? J(opts.target) : null,
    priority: opts.priority ?? "normal",
    createdAt: opts.createdAt ?? 0,
    steps: opts.steps,
  };
}

function input(
  over: Partial<Omit<SchedulerInput, "prefs">> & { windows?: StudyWindow[]; prefs?: Partial<SchedulerInput["prefs"]> },
): SchedulerInput {
  const { windows, prefs, ...rest } = over;
  return {
    now: J("2026-10-08T08:00"),
    timezone: TZ,
    horizonDays: 30,
    busy: [],
    fixedSessions: [],
    tasks: [],
    ...rest,
    prefs: {
      studyWindows: windows ?? [],
      maxDailyMinutes: 240,
      sessionMinutes: 120,
      breakMinutes: 0,
      ...prefs,
    },
  };
}

const thu = (start: string, end: string): StudyWindow => ({ dow: 4, start, end });
const fri = (start: string, end: string): StudyWindow => ({ dow: 5, start, end });

function minutesOn(out: SchedulerOutput, taskId: string, day: string): number {
  return out.sessions
    .filter((s) => s.taskId === taskId && localDayKey(s.start, TZ) === day)
    .reduce((sum, s) => sum + (s.end - s.start) / MIN, 0);
}

function result(out: SchedulerOutput, taskId: string) {
  const r = out.perTask.find((t) => t.taskId === taskId);
  if (!r) throw new Error(`no result for ${taskId}`);
  return r;
}

function overlaps(list: Interval[]): boolean {
  const sorted = [...list].sort((a, b) => a.start - b.start);
  return sorted.some((cur, i) => i > 0 && cur.start < sorted[i - 1].end);
}

function tc08(thursdayWindow: [string, string]): SchedulerInput {
  return input({
    windows: [thu(...thursdayWindow), fri("19:00", "21:00")],
    tasks: [
      task("A", { deadline: "2026-10-08T21:00", steps: [step("A1", 90)] }),
      task("B", { deadline: "2026-10-09T21:00", target: "2026-10-08T21:00", steps: [step("B1", 150)] }),
    ],
  });
}

Deno.test("TC08: kapasitas 120+120", () => {
  const out = planSchedule(tc08(["19:00", "21:00"]));
  assertEquals(minutesOn(out, "A", "2026-10-08"), 90);
  assertEquals(minutesOn(out, "B", "2026-10-08"), 30);
  assertEquals(minutesOn(out, "B", "2026-10-09"), 120);
  assertEquals(result(out, "A").risk, "ok");
  assertEquals(result(out, "B").risk, "target_risk");
  assertEquals(result(out, "A").capacityBeforeDeadline, 120);
  assertEquals(result(out, "B").capacityBeforeTarget, 120);
  assertEquals(result(out, "B").capacityBeforeDeadline, 240);
  assertEquals(out.totals, { remainingMinutes: 240, allocatedMinutes: 240, unallocatedMinutes: 0 });
});

Deno.test("TC08: kapasitas Kamis tinggal 60", () => {
  const out = planSchedule(tc08(["20:00", "21:00"]));
  assertEquals(result(out, "A").unallocatedMinutes, 30);
  assertEquals(result(out, "A").risk, "deadline_risk");
  assertEquals(minutesOn(out, "B", "2026-10-09"), 120);
  assertEquals(result(out, "B").unallocatedMinutes, 30);
  assertEquals(out.totals.unallocatedMinutes, 60);
  assert(out.perTask.every((r) => r.risk !== "ok"));
});

Deno.test("sesi tidak melewati deadline", () => {
  const out = planSchedule(input({
    windows: [thu("19:00", "21:00")],
    tasks: [task("A", { deadline: "2026-10-08T20:00", steps: [step("A1", 120)] })],
  }));
  assert(out.sessions.every((s) => s.end <= J("2026-10-08T20:00")));
  assertEquals(result(out, "A").unallocatedMinutes, 60);
});

Deno.test("sesi tidak menabrak busy maupun sesi lain", () => {
  const busy = [{ start: J("2026-10-08T19:30"), end: J("2026-10-08T20:00") }];
  const out = planSchedule(input({
    windows: [thu("19:00", "21:00"), fri("19:00", "21:00")],
    busy,
    tasks: [
      task("A", { deadline: "2026-10-09T21:00", steps: [step("A1", 60)] }),
      task("B", { deadline: "2026-10-09T21:00", createdAt: 1, steps: [step("B1", 60)] }),
    ],
  }));
  assertEquals(out.totals.unallocatedMinutes, 0);
  assert(!overlaps([...busy, ...out.sessions]));
});

Deno.test("panjang sesi maksimal sessionMinutes dan diikuti jeda", () => {
  const out = planSchedule(input({
    windows: [thu("19:00", "21:00")],
    prefs: { sessionMinutes: 25, breakMinutes: 5 },
    tasks: [task("A", { deadline: "2026-10-08T21:00", steps: [step("A1", 60)] })],
  }));
  assertEquals(out.sessions.map((s) => (s.end - s.start) / MIN), [25, 25, 10]);
  for (let i = 1; i < out.sessions.length; i++) {
    assert(out.sessions[i].start - out.sessions[i - 1].end >= 5 * MIN);
  }
});

Deno.test("total harian tidak melewati maxDailyMinutes", () => {
  const out = planSchedule(input({
    windows: [thu("18:00", "21:00"), fri("18:00", "21:00")],
    prefs: { maxDailyMinutes: 60 },
    tasks: [task("A", { deadline: "2026-10-10T21:00", steps: [step("A1", 150)] })],
  }));
  assertEquals(minutesOn(out, "A", "2026-10-08"), 60);
  assertEquals(minutesOn(out, "A", "2026-10-09"), 60);
  assertEquals(result(out, "A").unallocatedMinutes, 30);
});

Deno.test("langkah bergantung dijadwalkan setelah prasyaratnya selesai", () => {
  const out = planSchedule(input({
    windows: [thu("19:00", "21:00"), fri("19:00", "21:00")],
    prefs: { sessionMinutes: 30 },
    tasks: [task("A", {
      deadline: "2026-10-09T21:00",
      steps: [step("S2", 60, { orderIndex: 0, dependsOn: ["S1"] }), step("S1", 60, { orderIndex: 1 })],
    })],
  }));
  const s1End = Math.max(...out.sessions.filter((s) => s.stepId === "S1").map((s) => s.end));
  const s2Start = Math.min(...out.sessions.filter((s) => s.stepId === "S2").map((s) => s.start));
  assert(s2Start >= s1End);
});

Deno.test("prasyarat tidak teralokasi penuh membuat langkah berikutnya tidak dijadwalkan", () => {
  const out = planSchedule(input({
    windows: [thu("19:00", "20:00")],
    tasks: [task("A", {
      deadline: "2026-10-08T21:00",
      steps: [step("S1", 90), step("S2", 30, { orderIndex: 1, dependsOn: ["S1"] })],
    })],
  }));
  assertEquals(out.sessions.filter((s) => s.stepId === "S2"), []);
  const s2 = out.unscheduled.find((u) => u.stepId === "S2");
  assertEquals(s2?.reason, "blocked_by_dependency");
  assertEquals(s2?.minutes, 30);
  assertEquals(result(out, "A").risk, "deadline_risk");
});

Deno.test("potongan slot kurang dari 10 menit dilewati", () => {
  const out = planSchedule(input({
    windows: [thu("19:00", "19:08"), fri("19:00", "21:00")],
    tasks: [task("A", { deadline: "2026-10-09T21:00", steps: [step("A1", 30)] })],
  }));
  assertEquals(minutesOn(out, "A", "2026-10-08"), 0);
  assertEquals(minutesOn(out, "A", "2026-10-09"), 30);
});

Deno.test("sisa langkah kurang dari 10 menit tetap dijadwalkan", () => {
  const out = planSchedule(input({
    windows: [thu("19:00", "21:00")],
    tasks: [task("A", { deadline: "2026-10-08T21:00", steps: [step("A1", 5)] })],
  }));
  assertEquals(out.sessions.map((s) => (s.end - s.start) / MIN), [5]);
});

Deno.test("tugas tanpa deadline tidak dijadwalkan", () => {
  const out = planSchedule(input({
    windows: [thu("19:00", "21:00")],
    tasks: [task("A", { deadline: null, steps: [step("A1", 60)] })],
  }));
  assertEquals(out.sessions, []);
  assertEquals(result(out, "A").risk, "missing_deadline");
  assertEquals(out.unscheduled, [{ taskId: "A", stepId: null, minutes: 60, reason: "missing_deadline" }]);
});

Deno.test("deadline sudah lewat menjadi overdue tanpa sesi", () => {
  const out = planSchedule(input({
    windows: [thu("19:00", "21:00")],
    tasks: [task("A", { deadline: "2026-10-07T21:00", steps: [step("A1", 60)] })],
  }));
  assertEquals(out.sessions, []);
  assertEquals(result(out, "A").risk, "overdue");
  assertEquals(out.unscheduled[0].reason, "overdue");
});

Deno.test("deadline di luar horizon: sisa yang tidak muat diberi reason beyond_horizon", () => {
  const out = planSchedule(input({
    horizonDays: 1,
    windows: [thu("19:00", "21:00")],
    tasks: [task("A", { deadline: "2026-10-20T21:00", steps: [step("A1", 180)] })],
  }));
  assertEquals(result(out, "A").allocatedMinutes, 120);
  assertEquals(out.unscheduled, [{ taskId: "A", stepId: "A1", minutes: 60, reason: "beyond_horizon" }]);
  assertEquals(result(out, "A").risk, "ok");
});

Deno.test("urutan: deadline lalu prioritas lalu createdAt", () => {
  const out = planSchedule(input({
    windows: [thu("19:00", "20:00"), fri("19:00", "20:00")],
    tasks: [
      task("X", { deadline: "2026-10-09T21:00", createdAt: 0, steps: [step("X1", 60)] }),
      task("Y", { deadline: "2026-10-09T21:00", createdAt: 1, priority: "high", steps: [step("Y1", 60)] }),
    ],
  }));
  assertEquals(minutesOn(out, "Y", "2026-10-08"), 60);
  assertEquals(minutesOn(out, "X", "2026-10-09"), 60);
});

Deno.test("langkah done dilewati", () => {
  const out = planSchedule(input({
    windows: [thu("19:00", "21:00")],
    tasks: [task("A", {
      deadline: "2026-10-08T21:00",
      steps: [step("S1", 0, { status: "done" }), step("S2", 30, { orderIndex: 1, dependsOn: ["S1"] })],
    })],
  }));
  assertEquals(out.sessions.map((s) => s.stepId), ["S2"]);
  assertEquals(result(out, "A").remainingMinutes, 30);
});

Deno.test("fixedSessions dihitung ke batas harian dan tidak ditimpa", () => {
  const fixed = { taskId: "Z", stepId: "Z1", start: J("2026-10-08T19:00"), end: J("2026-10-08T19:30") };
  const out = planSchedule(input({
    windows: [thu("19:00", "21:00"), fri("19:00", "21:00")],
    prefs: { maxDailyMinutes: 60 },
    fixedSessions: [fixed],
    tasks: [task("A", { deadline: "2026-10-09T21:00", steps: [step("A1", 60)] })],
  }));
  assertEquals(minutesOn(out, "A", "2026-10-08"), 30);
  assertEquals(minutesOn(out, "A", "2026-10-09"), 30);
  assert(!overlaps([fixed, ...out.sessions]));
});

Deno.test("pinned dipakai apa adanya dan mengurangi sisa langkah", () => {
  const pin = { taskId: "A", stepId: "A1", start: J("2026-10-09T19:00"), end: J("2026-10-09T19:30") };
  const out = planSchedule(input({
    windows: [thu("19:00", "21:00"), fri("19:00", "21:00")],
    pinned: [pin],
    tasks: [task("A", { deadline: "2026-10-09T21:00", steps: [step("A1", 60)] })],
  }));
  const pinned = out.sessions.filter((s) => s.pinned);
  assertEquals(pinned, [{ ...pin, pinned: true }]);
  assertEquals(result(out, "A").allocatedMinutes, 60);
  assert(!overlaps(out.sessions));
});

Deno.test("blocked tidak dipakai", () => {
  const out = planSchedule(input({
    windows: [thu("19:00", "21:00"), fri("19:00", "21:00")],
    blocked: [{ start: J("2026-10-08T19:00"), end: J("2026-10-08T21:00") }],
    tasks: [task("A", { deadline: "2026-10-09T21:00", steps: [step("A1", 60)] })],
  }));
  assertEquals(minutesOn(out, "A", "2026-10-08"), 0);
  assertEquals(minutesOn(out, "A", "2026-10-09"), 60);
});

Deno.test("deterministik", () => {
  const a = planSchedule(tc08(["20:00", "21:00"]));
  const b = planSchedule(tc08(["20:00", "21:00"]));
  assertEquals(a, b);
});
