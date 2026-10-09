import type { FixedSession, Priority, SchedulerInput, StudyWindow, TaskInput, WorkStatus } from "../_shared/scheduler/mod.ts";

export const HORIZON_DAYS = 30;

export interface TaskRow {
  id: string;
  title: string;
  official_deadline: string | null;
  personal_target: string | null;
  priority: Priority;
  created_at: string;
  deleted_at: string | null;
}

export interface StepRow {
  id: string;
  task_id: string;
  title: string;
  order_index: number;
  remaining_minutes: number;
  status: WorkStatus;
  deleted_at: string | null;
}

export interface ActivityRow {
  id: string;
  start_at: string;
  end_at: string;
  busy: boolean;
  locked: boolean;
  deleted_at: string | null;
}

/** A session of the currently active plan. */
export interface SessionRow {
  id: string;
  task_id: string;
  step_id: string;
  start_at: string;
  end_at: string;
  status: string;
}

export interface PlanRows {
  profile: { timezone: string };
  prefs: { study_windows: StudyWindow[]; max_daily_minutes: number; session_minutes: number; break_minutes: number };
  tasks: TaskRow[];
  steps: StepRow[];
  dependencies: { step_id: string; depends_on_id: string }[];
  activities: ActivityRow[];
  activeSessions: SessionRow[];
}

const ms = (s: string | null) => (s === null ? null : Date.parse(s));

export function fixedFromSessions(sessions: SessionRow[]): FixedSession[] {
  return sessions
    .filter((s) => s.status === "in_progress" || s.status === "completed")
    .map((s) => ({ taskId: s.task_id, stepId: s.step_id, start: Date.parse(s.start_at), end: Date.parse(s.end_at) }));
}

export function toSchedulerInput(rows: PlanRows, now: number): SchedulerInput {
  const steps = rows.steps.filter((s) => s.deleted_at === null);
  const tasks: TaskInput[] = rows.tasks
    .filter((t) => t.deleted_at === null)
    .map((t) => ({
      id: t.id,
      title: t.title,
      officialDeadline: ms(t.official_deadline),
      personalTarget: ms(t.personal_target),
      priority: t.priority,
      createdAt: Date.parse(t.created_at),
      steps: steps
        .filter((s) => s.task_id === t.id)
        .map((s) => ({
          id: s.id,
          title: s.title,
          orderIndex: s.order_index,
          remainingMinutes: s.remaining_minutes,
          status: s.status,
          dependsOn: rows.dependencies.filter((d) => d.step_id === s.id).map((d) => d.depends_on_id),
        })),
    }));

  return {
    now,
    timezone: rows.profile.timezone,
    horizonDays: HORIZON_DAYS,
    prefs: {
      studyWindows: rows.prefs.study_windows,
      maxDailyMinutes: rows.prefs.max_daily_minutes,
      sessionMinutes: rows.prefs.session_minutes,
      breakMinutes: rows.prefs.break_minutes,
    },
    busy: rows.activities
      .filter((a) => a.deleted_at === null && (a.busy || a.locked))
      .map((a) => ({ start: Date.parse(a.start_at), end: Date.parse(a.end_at) })),
    fixedSessions: fixedFromSessions(rows.activeSessions),
    tasks,
  };
}
