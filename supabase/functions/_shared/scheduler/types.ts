export type Ms = number; // epoch milliseconds, UTC

export interface Interval {
  start: Ms;
  end: Ms;
}

/** Weekly study window in the user's local time. dow: 1 = Monday ... 7 = Sunday. */
export interface StudyWindow {
  dow: 1 | 2 | 3 | 4 | 5 | 6 | 7;
  start: string; // "HH:MM"
  end: string; // "HH:MM"; end <= start means the window runs past midnight
}

export interface Prefs {
  studyWindows: StudyWindow[];
  maxDailyMinutes: number;
  sessionMinutes: number;
  breakMinutes: number;
}

export type Priority = "high" | "normal" | "low";
export type WorkStatus = "not_started" | "in_progress" | "done";

export interface StepInput {
  id: string;
  title: string;
  orderIndex: number;
  remainingMinutes: number;
  status: WorkStatus;
  dependsOn: string[];
}

export interface TaskInput {
  id: string;
  title: string;
  officialDeadline: Ms | null;
  personalTarget: Ms | null;
  priority: Priority;
  createdAt: Ms;
  steps: StepInput[];
}

export interface FixedSession {
  taskId: string;
  stepId: string;
  start: Ms;
  end: Ms;
}

export type PinnedSlot = FixedSession;

export interface SchedulerInput {
  now: Ms;
  timezone: string;
  horizonDays: number;
  prefs: Prefs;
  busy: Interval[];
  fixedSessions: FixedSession[];
  tasks: TaskInput[];
  pinned?: PinnedSlot[];
  blocked?: Interval[];
}

export interface PlannedSession {
  taskId: string;
  stepId: string;
  start: Ms;
  end: Ms;
  pinned: boolean;
}

export type Risk =
  | "ok"
  | "target_risk"
  | "deadline_risk"
  | "overdue"
  | "missing_deadline";

export interface TaskResult {
  taskId: string;
  risk: Risk;
  remainingMinutes: number;
  allocatedMinutes: number;
  unallocatedMinutes: number;
  capacityBeforeTarget: number | null;
  capacityBeforeDeadline: number | null;
  lastSessionEnd: Ms | null;
}

export type UnscheduledReason =
  | "missing_deadline"
  | "no_capacity"
  | "overdue"
  | "beyond_horizon"
  | "blocked_by_dependency";

export interface Unscheduled {
  taskId: string;
  stepId: string | null;
  minutes: number;
  reason: UnscheduledReason;
}

export interface SchedulerOutput {
  sessions: PlannedSession[];
  perTask: TaskResult[];
  unscheduled: Unscheduled[];
  totals: {
    remainingMinutes: number;
    allocatedMinutes: number;
    unallocatedMinutes: number;
  };
}
