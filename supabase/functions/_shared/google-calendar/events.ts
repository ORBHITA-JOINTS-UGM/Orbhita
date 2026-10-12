import { Temporal } from "npm:@js-temporal/polyfill@0.5.1";

type EventTime = {
  date?: string;
  dateTime?: string;
  timeZone?: string;
};

export type GoogleEvent = {
  id?: string;
  summary?: string;
  status?: string;
  transparency?: string;
  start?: EventTime;
  end?: EventTime;
  attendees?: Array<{ self?: boolean; responseStatus?: string }>;
};

function instant(value: EventTime | undefined, calendarZone: string): string {
  if (!value) throw new Error("event time missing");

  const zone = value.timeZone ?? calendarZone;

  if (value.dateTime) {
    if (/([zZ]|[+-]\d{2}:\d{2})$/.test(value.dateTime)) {
      return Temporal.Instant.from(value.dateTime).toString();
    }
    return Temporal.PlainDateTime.from(value.dateTime)
      .toZonedDateTime(zone)
      .toInstant()
      .toString();
  }

  if (value.date) {
    return Temporal.PlainDate.from(value.date)
      .toZonedDateTime(zone)
      .toInstant()
      .toString();
  }

  throw new Error("event time missing");
}

export function normalizeEvent(
  event: GoogleEvent,
  calendarId: string,
  calendarZone: string,
) {
  if (event.status === "cancelled") return null;
  if (event.attendees?.some(a => a.self && a.responseStatus === "declined")) {
    return null;
  }

  if (!event.id) throw new Error("event id missing");

  const start = instant(event.start, calendarZone);
  const end = instant(event.end, calendarZone);

  if (Date.parse(end) <= Date.parse(start)) {
    throw new Error("invalid event duration");
  }

  return {
    external_key: JSON.stringify([calendarId, event.id]),
    title: event.summary?.trim() || "(Tanpa judul)",
    start_at: start,
    end_at: end,
    busy: event.transparency !== "transparent",
  };
}
