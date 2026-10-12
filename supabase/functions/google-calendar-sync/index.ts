import { ApiError, ok, withErrors } from "../_shared/http.ts";
import { makeAuthUserId, serviceClient } from "../_shared/supabase.ts";
import { decryptToken } from "../_shared/google-calendar/crypto.ts";
import {
  normalizeEvent,
  type GoogleEvent,
} from "../_shared/google-calendar/events.ts";

const db = serviceClient();
const authUserId = makeAuthUserId(db);
const DAY = 86400000;
const MAX_EVENTS = 10000;

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`missing env ${name}`);
  return value;
}

Deno.serve(withErrors(async (req) => {
  if (req.method !== "POST") {
    throw new ApiError(405, "METHOD_NOT_ALLOWED", "Gunakan POST.");
  }

  const ownerId = await authUserId(req);

  const { data: connection, error: connectionError } = await db
    .from("google_calendar_connections")
    .select(
      "refresh_token_encrypted,calendar_id,connected_at,last_synced_at",
    )
    .eq("owner_id", ownerId)
    .maybeSingle();

  if (connectionError) throw new Error("calendar connection query failed");
  if (!connection) {
    throw new ApiError(
      409, "CALENDAR_NOT_CONNECTED", "Hubungkan Google Calendar terlebih dahulu.",
    );
  }

  const refreshToken = await decryptToken(
    connection.refresh_token_encrypted,
    ownerId,
  );

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: requiredEnv("GOOGLE_CLIENT_ID"),
      client_secret: requiredEnv("GOOGLE_CLIENT_SECRET"),
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
    signal: AbortSignal.timeout(15000),
  });

  if (!tokenResponse.ok) {
    if (tokenResponse.status === 400 || tokenResponse.status === 401) {
      throw new ApiError(
        409, "GOOGLE_RECONNECT_REQUIRED",
        "Akses Google perlu diperbarui. Hubungkan Calendar lagi.",
      );
    }
    throw new ApiError(
      502, "GOOGLE_UNAVAILABLE", "Google belum bisa diakses.",
      { retryable: true },
    );
  }

  const tokens = await tokenResponse.json();
  if (typeof tokens.access_token !== "string" || !tokens.access_token) {
    throw new Error("google access token missing");
  }

  const now = Date.now();
  const rangeStart = new Date(now - 7 * DAY).toISOString();
  const rangeEnd = new Date(now + 90 * DAY).toISOString();

  const events: NonNullable<ReturnType<typeof normalizeEvent>>[] = [];
  const eventKeys = new Set<string>();
  const pageTokens = new Set<string>();
  let pageToken: string | undefined;
  let received = 0;
  let finished = false;

  // Database baru diubah setelah SEMUA halaman berhasil dibaca.
  for (let page = 0; page < 20; page++) {
    const url = new URL(
      "https://www.googleapis.com/calendar/v3/calendars/" +
      encodeURIComponent(connection.calendar_id) + "/events",
    );
    url.search = new URLSearchParams({
      timeMin: rangeStart,
      timeMax: rangeEnd,
      singleEvents: "true",
      showDeleted: "false",
      maxResults: "1000",
      ...(pageToken ? { pageToken } : {}),
    }).toString();

    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${tokens.access_token}` },
      signal: AbortSignal.timeout(15000),
    });

    if (!response.ok) {
      throw new ApiError(
        response.status === 401 || response.status === 403 ? 409 : 502,
        response.status === 401 || response.status === 403
          ? "GOOGLE_RECONNECT_REQUIRED"
          : "GOOGLE_CALENDAR_FETCH_FAILED",
        "Calendar belum bisa dibaca. Periksa izin atau coba hubungkan lagi.",
        { retryable: response.status === 429 || response.status >= 500 },
      );
    }

    const body = await response.json();
    if (typeof body.timeZone !== "string" || !body.timeZone) {
      throw new Error("calendar timezone missing");
    }
    if (body.items !== undefined && !Array.isArray(body.items)) {
      throw new Error("invalid calendar response");
    }

    const items: GoogleEvent[] = body.items ?? [];
    received += items.length;
    if (received > MAX_EVENTS) {
      throw new ApiError(
        422, "CALENDAR_TOO_LARGE",
        "Jumlah acara melebihi batas sinkronisasi versi awal.",
      );
    }

    for (const item of items) {
      if (!item || typeof item !== "object") {
        throw new Error("invalid calendar event");
      }
      const event = normalizeEvent(
        item, connection.calendar_id, body.timeZone,
      );
      if (!event) continue;

      // Abaikan acara yang tidak bertumpang tindih dengan rentang impor.
      if (Date.parse(event.end_at) <= Date.parse(rangeStart) ||
          Date.parse(event.start_at) >= Date.parse(rangeEnd)) continue;

      if (eventKeys.has(event.external_key)) {
        throw new Error("duplicate calendar event");
      }
      eventKeys.add(event.external_key);
      events.push(event);
    }

    if (body.nextPageToken === undefined || body.nextPageToken === "") {
      finished = true;
      break;
    }
    if (typeof body.nextPageToken !== "string" ||
        pageTokens.has(body.nextPageToken)) {
      throw new Error("invalid calendar pagination");
    }
    pageToken = body.nextPageToken;
    pageTokens.add(body.nextPageToken);
  }

  if (!finished) {
    throw new ApiError(
      422, "CALENDAR_TOO_LARGE",
      "Sinkronisasi belum mencakup semua acara. Database tidak diubah.",
    );
  }

  const { data: result, error: saveError } = await db.rpc(
    "apply_google_calendar_snapshot",
    {
      p_owner_id: ownerId,
      p_connected_at: connection.connected_at,
      p_last_synced_at: connection.last_synced_at,
      p_start: rangeStart,
      p_end: rangeEnd,
      p_events: events,
    },
  );

  if (saveError) {
    if (saveError.code === "PT409") {
      throw new ApiError(
        409, "STALE_CALENDAR_SYNC",
        "Koneksi atau hasil sinkronisasi sudah berubah. Coba sync lagi.",
        { retryable: true },
      );
    }
    throw new Error("calendar snapshot save failed");
  }

  const response = ok({
    calendar_id: connection.calendar_id,
    range_start: rangeStart,
    range_end: rangeEnd,
    ...result,
  });
  response.headers.set("Cache-Control", "no-store");
  return response;
}));
