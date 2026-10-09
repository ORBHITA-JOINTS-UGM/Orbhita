import type { SupabaseClient } from "../_shared/deps.ts";
import { check } from "../_shared/supabase.ts";
import type { PlanRepo } from "./handler.ts";
import { HORIZON_DAYS, type PlanRows } from "./load.ts";

const DAY_MS = 24 * 60 * 60 * 1000;

export function supabasePlanRepo(db: SupabaseClient): PlanRepo {
  return {
    async load(userId) {
      const now = Date.now();
      const from = new Date(now - DAY_MS).toISOString();
      const to = new Date(now + (HORIZON_DAYS + 1) * DAY_MS).toISOString();

      const [profile, prefs, state, tasks, activities, plans] = await Promise.all([
        db.from("profiles").select("timezone").eq("id", userId).single(),
        db.from("preferences").select("study_windows, max_daily_minutes, session_minutes, break_minutes")
          .eq("owner_id", userId).single(),
        db.from("owner_state").select("data_version").eq("owner_id", userId).single(),
        db.from("tasks").select("id, title, official_deadline, personal_target, priority, created_at, deleted_at")
          .eq("owner_id", userId).is("deleted_at", null).neq("work_status", "done"),
        db.from("activities").select("id, start_at, end_at, busy, locked, deleted_at")
          .eq("owner_id", userId).is("deleted_at", null).lt("start_at", to).gt("end_at", from),
        db.from("plans").select("id, version, status").eq("owner_id", userId),
      ]);

      const taskRows = check(tasks) as PlanRows["tasks"];
      const taskIds = taskRows.map((t) => t.id);
      const steps = taskIds.length
        ? check(
          await db.from("steps").select("id, task_id, title, order_index, remaining_minutes, status, deleted_at")
            .eq("owner_id", userId).in("task_id", taskIds).is("deleted_at", null),
        ) as PlanRows["steps"]
        : [];
      const stepIds = steps.map((s) => s.id);
      const dependencies = stepIds.length
        ? check(
          await db.from("step_dependencies").select("step_id, depends_on_id").eq("owner_id", userId).in("step_id", stepIds),
        ) as PlanRows["dependencies"]
        : [];

      const planRows = check(plans) as { id: string; version: number; status: string }[];
      const activePlan = planRows.find((p) => p.status === "active");
      // In-progress/completed sessions stay active after their plan is superseded,
      // so select by is_active rather than by the active plan id.
      const activeSessions = check(
        await db.from("sessions").select("id, task_id, step_id, start_at, end_at, status")
          .eq("owner_id", userId).eq("is_active", true),
      ) as PlanRows["activeSessions"];

      return {
        profile: check(profile) as PlanRows["profile"],
        prefs: check(prefs) as PlanRows["prefs"],
        tasks: taskRows,
        steps,
        dependencies,
        activities: check(activities) as PlanRows["activities"],
        activeSessions,
        activePlanVersion: activePlan?.version ?? 0,
        dataVersion: (check(state) as { data_version: number }).data_version,
        maxVersion: planRows.reduce((m, p) => Math.max(m, p.version), 0),
      };
    },

    async saveProposal(userId, plan, sessions) {
      const id = check(
        await db.rpc("save_plan_proposal", {
          p_owner: userId,
          p_plan: {
            version: plan.version,
            base_plan_version: plan.basePlanVersion,
            base_data_version: plan.baseDataVersion,
            trigger: plan.trigger,
            risk_summary: plan.riskSummary,
            unscheduled: plan.unscheduled,
          },
          p_sessions: sessions.map((s) => ({
            task_id: s.taskId,
            step_id: s.stepId,
            start_at: new Date(s.start).toISOString(),
            end_at: new Date(s.end).toISOString(),
          })),
        }),
      ) as string;
      return id;
    },
  };
}
