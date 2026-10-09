import { DateTime } from "../deps.ts";
import type { Interval, Ms, StudyWindow } from "./types.ts";

const DAY_MS = 24 * 60 * 60 * 1000;

function parseHm(hm: string): { hour: number; minute: number } {
  const [h, m] = hm.split(":").map(Number);
  return { hour: h, minute: m };
}

/** Sorts intervals and merges the ones that overlap or touch. */
export function mergeIntervals(list: Interval[]): Interval[] {
  const sorted = list
    .filter((i) => i.end > i.start)
    .map((i) => ({ ...i }))
    .sort((a, b) => a.start - b.start || a.end - b.end);
  const out: Interval[] = [];
  for (const cur of sorted) {
    const last = out[out.length - 1];
    if (last && cur.start <= last.end) {
      last.end = Math.max(last.end, cur.end);
    } else {
      out.push(cur);
    }
  }
  return out;
}

/** Removes every `cut` interval from `base`. Result is sorted and merged. */
export function subtractIntervals(base: Interval[], cut: Interval[]): Interval[] {
  const cuts = mergeIntervals(cut);
  const out: Interval[] = [];
  for (const b of mergeIntervals(base)) {
    let start = b.start;
    for (const c of cuts) {
      if (c.end <= start) continue;
      if (c.start >= b.end) break;
      if (c.start > start) out.push({ start, end: c.start });
      start = Math.max(start, c.end);
      if (start >= b.end) break;
    }
    if (start < b.end) out.push({ start, end: b.end });
  }
  return out;
}

export function localDayKey(t: Ms, timezone: string): string {
  return DateTime.fromMillis(t, { zone: timezone }).toFormat("yyyy-MM-dd");
}

export function buildFreeSlots(args: {
  now: Ms;
  timezone: string;
  horizonDays: number;
  studyWindows: StudyWindow[];
  busy: Interval[];
}): Interval[] {
  const { now, timezone, horizonDays, studyWindows, busy } = args;
  const horizonEnd = now + horizonDays * DAY_MS;
  const windows: Interval[] = [];

  // Start one day early so a window that crosses midnight from yesterday is included.
  let day = DateTime.fromMillis(now, { zone: timezone }).startOf("day").minus({ days: 1 });
  while (day.toMillis() < horizonEnd) {
    for (const w of studyWindows) {
      if (w.dow !== day.weekday) continue;
      const s = parseHm(w.start);
      const e = parseHm(w.end);
      const start = day.set({ ...s, second: 0, millisecond: 0 });
      let end = day.set({ ...e, second: 0, millisecond: 0 });
      if (end <= start) end = day.plus({ days: 1 }).set({ ...e, second: 0, millisecond: 0 });
      windows.push({ start: start.toMillis(), end: end.toMillis() });
    }
    day = day.plus({ days: 1 });
  }

  const clipped = windows
    .map((w) => ({ start: Math.max(w.start, now), end: Math.min(w.end, horizonEnd) }))
    .filter((w) => w.end > w.start);
  return subtractIntervals(clipped, busy);
}
