import { assert, assertEquals } from "jsr:@std/assert@1";
import { ApiError } from "../_shared/http.ts";
import type { PlannedSession } from "../_shared/scheduler/mod.ts";
import { createPlanProposeHandler, type PlanRepo, type SavedPlan } from "./handler.ts";
import type { PlanRows } from "./load.ts";
import { iso, J, NOW, rows } from "./fixtures_test_util.ts";

const SESSION_ID = "44444444-4444-4444-8444-444444444444";

function setup(data: PlanRows = rows(), state = { activePlanVersion: 3, dataVersion: 17, maxVersion: 5 }) {
  const saved: { plan: SavedPlan; sessions: PlannedSession[] }[] = [];
  const repo: PlanRepo = {
    load: () => Promise.resolve({ ...data, ...state }),
    saveProposal: (_u, plan, sessions) => {
      saved.push({ plan, sessions });
      return Promise.resolve("plan-new");
    },
  };
  const handler = createPlanProposeHandler({
    authUserId: (req) =>
      req.headers.get("Authorization") === "Bearer good"
        ? Promise.resolve("user-1")
        : Promise.reject(new ApiError(401, "UNAUTHENTICATED", "x")),
    repo,
    now: () => NOW,
  });
  return { handler, saved };
}

const post = (body: unknown) =>
  new Request("http://localhost/plan-propose", {
    method: "POST",
    headers: { Authorization: "Bearer good" },
    body: JSON.stringify(body),
  });

const activeSession = (start: string, end: string, status = "planned") => ({
  id: SESSION_ID,
  task_id: "A",
  step_id: "A1",
  start_at: iso(start),
  end_at: iso(end),
  status,
});

Deno.test("respons memuat plan_id, sessions, diff, risk_summary, unscheduled, explanation", async () => {
  const { handler } = setup();
  const res = await handler(post({ trigger: "new_task" }));
  assertEquals(res.status, 200);
  const { data } = await res.json();
  assertEquals(data.plan_id, "plan-new");
  assertEquals(data.version, 6);
  assertEquals(data.sessions.length, 1);
  assertEquals(data.sessions[0].start, new Date(J("2026-10-08T19:00")).toISOString());
  assert(Array.isArray(data.diff.added));
  assertEquals(data.risk_summary.totals.unallocatedMinutes, 0);
  assertEquals(data.unscheduled, []);
  assert(typeof data.explanation === "string" && data.explanation.length > 0);
});

Deno.test("versi usulan = maxVersion + 1 dan base sesuai state", async () => {
  const { handler, saved } = setup();
  await handler(post({ trigger: "manual" }));
  assertEquals(saved[0].plan.version, 6);
  assertEquals(saved[0].plan.basePlanVersion, 3);
  assertEquals(saved[0].plan.baseDataVersion, 17);
  assertEquals(saved[0].plan.trigger, "manual");
});

Deno.test("tanpa jendela belajar ditolak NO_STUDY_WINDOWS", async () => {
  const r = rows();
  r.prefs.study_windows = [];
  const { handler, saved } = setup(r);
  const res = await handler(post({ trigger: "new_task" }));
  assertEquals(res.status, 422);
  assertEquals((await res.json()).error.code, "NO_STUDY_WINDOWS");
  assertEquals(saved.length, 0);
});

Deno.test("trigger tidak dikenal ditolak INVALID_INPUT", async () => {
  const { handler } = setup();
  const res = await handler(post({ trigger: "x" }));
  assertEquals(res.status, 400);
});

Deno.test("postpone manual bentrok ditolak SLOT_CONFLICT dengan reason", async () => {
  const { handler, saved } = setup(rows({ activeSessions: [activeSession("2026-10-08T19:00", "2026-10-08T19:30")] }));
  const res = await handler(post({
    trigger: "postpone",
    postpone: { session_id: SESSION_ID, mode: "manual", start_at: iso("2026-10-09T15:00") },
  }));
  assertEquals(res.status, 422);
  const body = await res.json();
  assertEquals(body.error.code, "SLOT_CONFLICT");
  assertEquals(body.error.field_errors.start_at, "outside_study_window");
  assertEquals(saved.length, 0);
});

Deno.test("postpone manual valid menyematkan sesi di waktu pilihan", async () => {
  const { handler, saved } = setup(rows({ activeSessions: [activeSession("2026-10-08T19:00", "2026-10-08T19:30")] }));
  const res = await handler(post({
    trigger: "postpone",
    postpone: { session_id: SESSION_ID, mode: "manual", start_at: iso("2026-10-09T20:00") },
  }));
  assertEquals(res.status, 200);
  const pinned = saved[0].sessions.filter((s) => s.pinned);
  assertEquals(pinned.map((s) => [s.start, s.end]), [[J("2026-10-09T20:00"), J("2026-10-09T20:30")]]);
});

Deno.test("postpone auto memblokir slot lama", async () => {
  const { handler, saved } = setup(rows({ activeSessions: [activeSession("2026-10-08T19:00", "2026-10-08T20:00")] }));
  const res = await handler(post({ trigger: "postpone", postpone: { session_id: SESSION_ID, mode: "auto" } }));
  assertEquals(res.status, 200);
  const overlapsOld = saved[0].sessions.some((s) => s.start < J("2026-10-08T20:00") && s.end > J("2026-10-08T19:00"));
  assertEquals(overlapsOld, false);
});

Deno.test("postpone sesi in_progress tidak membuka slot lamanya", async () => {
  const data = rows({ activeSessions: [activeSession("2026-10-08T19:00", "2026-10-08T20:00", "in_progress")] });
  const auto = setup(data);
  assertEquals((await auto.handler(post({ trigger: "postpone", postpone: { session_id: SESSION_ID, mode: "auto" } }))).status, 200);
  const overlapsOld = auto.saved[0].sessions.some((s) => s.start < J("2026-10-08T20:00") && s.end > J("2026-10-08T19:00"));
  assertEquals(overlapsOld, false);

  const manual = setup(data);
  const res = await manual.handler(post({
    trigger: "postpone",
    postpone: { session_id: SESSION_ID, mode: "manual", start_at: iso("2026-10-08T19:30") },
  }));
  assertEquals(res.status, 422);
});

Deno.test("postpone sesi yang tidak ada ditolak NOT_FOUND", async () => {
  const { handler } = setup();
  const res = await handler(post({ trigger: "postpone", postpone: { session_id: SESSION_ID, mode: "auto" } }));
  assertEquals(res.status, 404);
});

Deno.test("postpone sesi yang sudah selesai ditolak INVALID_INPUT", async () => {
  const { handler } = setup(rows({
    activeSessions: [activeSession("2026-10-08T19:00", "2026-10-08T19:30", "completed")],
  }));
  const res = await handler(post({ trigger: "postpone", postpone: { session_id: SESSION_ID, mode: "auto" } }));
  assertEquals(res.status, 400);
});

Deno.test("tanpa JWT valid ditolak", async () => {
  const { handler } = setup();
  const res = await handler(new Request("http://localhost/plan-propose", { method: "POST", body: "{}" }));
  assertEquals(res.status, 401);
});
