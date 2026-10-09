import type { PlanRows } from "./load.ts";

export const TZ = "Asia/Jakarta";
/** Local Jakarta time. 2026-10-08 is a Thursday. */
export const J = (s: string) => Date.parse(`${s}:00+07:00`);
export const iso = (s: string) => new Date(J(s)).toISOString();
export const NOW = J("2026-10-08T08:00");

export function rows(over: Partial<PlanRows> = {}): PlanRows {
  return {
    profile: { timezone: TZ },
    prefs: {
      study_windows: [{ dow: 4, start: "19:00", end: "21:00" }, { dow: 5, start: "19:00", end: "21:00" }],
      max_daily_minutes: 240,
      session_minutes: 120,
      break_minutes: 0,
    },
    tasks: [{
      id: "A",
      title: "Laporan",
      official_deadline: iso("2026-10-09T21:00"),
      personal_target: null,
      priority: "normal",
      created_at: iso("2026-10-01T08:00"),
      deleted_at: null,
    }],
    steps: [{
      id: "A1",
      task_id: "A",
      title: "Tulis",
      order_index: 0,
      remaining_minutes: 60,
      status: "not_started",
      deleted_at: null,
    }],
    dependencies: [],
    activities: [],
    activeSessions: [],
    ...over,
  };
}
