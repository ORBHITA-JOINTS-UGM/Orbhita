import { ApiError, ok, withErrors } from "../_shared/http.ts";
import { type Interval, type PinnedSlot, type PlannedSession, planSchedule } from "../_shared/scheduler/mod.ts";
import { diffPlans } from "./diff.ts";
import { explainPlan } from "./explain.ts";
import { fixedFromSessions, type PlanRows, toSchedulerInput } from "./load.ts";
import { checkManualSlot } from "./postpone.ts";

export interface PlanState {
  activePlanVersion: number;
  dataVersion: number;
  maxVersion: number;
}

export interface SavedPlan {
  version: number;
  basePlanVersion: number;
  baseDataVersion: number;
  trigger: string;
  riskSummary: unknown;
  unscheduled: unknown;
}

export interface PlanRepo {
  load(userId: string): Promise<PlanRows & PlanState>;
  /** Supersedes older proposals and stores the new plan with its sessions atomically. */
  saveProposal(userId: string, plan: SavedPlan, sessions: PlannedSession[]): Promise<string>;
}

const TRIGGERS = ["new_task", "progress", "activity_change", "postpone", "manual"];
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

interface PostponeRequest {
  sessionId: string;
  mode: "manual" | "auto";
  startAt: number | null;
}

function parseBody(body: unknown): { trigger: string; postpone: PostponeRequest | null } {
  const invalid = (field: string, msg: string) =>
    new ApiError(400, "INVALID_INPUT", msg, { fieldErrors: { [field]: msg } });
  if (!body || typeof body !== "object") throw invalid("body", "Body harus berupa objek JSON.");
  const b = body as Record<string, any>;
  if (!TRIGGERS.includes(b.trigger)) throw invalid("trigger", "trigger tidak dikenal.");
  if (b.trigger !== "postpone") return { trigger: b.trigger, postpone: null };

  const p = b.postpone;
  if (!p || typeof p.session_id !== "string" || !UUID_RE.test(p.session_id)) {
    throw invalid("postpone.session_id", "session_id harus UUID.");
  }
  if (p.mode !== "manual" && p.mode !== "auto") throw invalid("postpone.mode", "mode harus manual atau auto.");
  const startAt = p.mode === "manual" ? Date.parse(p.start_at) : null;
  if (p.mode === "manual" && Number.isNaN(startAt)) throw invalid("postpone.start_at", "start_at harus waktu ISO.");
  return { trigger: b.trigger, postpone: { sessionId: p.session_id, mode: p.mode, startAt } };
}

const toIso = (s: PlannedSession) => ({ ...s, start: new Date(s.start).toISOString(), end: new Date(s.end).toISOString() });

export function createPlanProposeHandler(deps: {
  authUserId(req: Request): Promise<string>;
  repo: PlanRepo;
  now(): number;
}): (req: Request) => Promise<Response> {
  return withErrors(async (req) => {
    if (req.method !== "POST") throw new ApiError(405, "METHOD_NOT_ALLOWED", "Gunakan POST.");
    const userId = await deps.authUserId(req);
    let body: unknown;
    try {
      body = await req.json();
    } catch {
      throw new ApiError(400, "INVALID_INPUT", "Body harus berupa JSON.");
    }
    const { trigger, postpone } = parseBody(body);

    const data = await deps.repo.load(userId);
    if (!data.prefs.study_windows?.length) {
      throw new ApiError(422, "NO_STUDY_WINDOWS", "Atur jam belajar dulu sebelum membuat rencana.");
    }

    const now = deps.now();
    const input = toSchedulerInput(data, now);
    let pinned: PinnedSlot[] = [];
    let blocked: Interval[] = [];

    if (postpone) {
      const row = data.activeSessions.find((s) => s.id === postpone.sessionId);
      if (!row) throw new ApiError(404, "NOT_FOUND", "Sesi tidak ditemukan.");
      if (row.status !== "planned" && row.status !== "in_progress") {
        throw new ApiError(400, "INVALID_INPUT", "Sesi ini tidak bisa ditunda.");
      }
      // A planned session frees its old slot. An in-progress one stays active after confirm_plan,
      // so its slot must stay taken or the new plan could never be confirmed.
      if (row.status === "planned") {
        input.fixedSessions = fixedFromSessions(data.activeSessions.filter((s) => s.id !== row.id));
      }
      const session = { taskId: row.task_id, stepId: row.step_id, start: Date.parse(row.start_at), end: Date.parse(row.end_at) };
      if (postpone.mode === "manual") {
        const check = checkManualSlot(input, session, postpone.startAt!);
        if (!check.ok) {
          throw new ApiError(422, "SLOT_CONFLICT", "Waktu yang dipilih tidak bisa dipakai.", {
            fieldErrors: { start_at: check.reason },
          });
        }
        pinned = [check.pinned];
      } else {
        blocked = [{ start: session.start, end: session.end }];
      }
    }

    const out = planSchedule({ ...input, pinned, blocked });
    const active: PlannedSession[] = data.activeSessions
      .filter((s) => s.status === "planned" || s.status === "in_progress")
      .map((s) => ({ taskId: s.task_id, stepId: s.step_id, start: Date.parse(s.start_at), end: Date.parse(s.end_at), pinned: false }));
    const diff = diffPlans(active, out.sessions);
    const titles = Object.fromEntries(data.tasks.map((t) => [t.id, t.title]));
    const riskSummary = { perTask: out.perTask, totals: out.totals };

    const version = data.maxVersion + 1;
    const planId = await deps.repo.saveProposal(userId, {
      version,
      basePlanVersion: data.activePlanVersion,
      baseDataVersion: data.dataVersion,
      trigger,
      riskSummary,
      unscheduled: out.unscheduled,
    }, out.sessions);

    return ok({
      plan_id: planId,
      version,
      sessions: out.sessions.map(toIso),
      diff: {
        added: diff.added.map(toIso),
        moved: diff.moved.map((m) => ({ from: toIso(m.from), to: toIso(m.to) })),
        removed: diff.removed.map(toIso),
        affected_task_ids: diff.affectedTaskIds,
      },
      risk_summary: riskSummary,
      unscheduled: out.unscheduled,
      explanation: explainPlan(out, titles, input.timezone),
    });
  });
}
