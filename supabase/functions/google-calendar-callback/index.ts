import { ApiError, withErrors } from "../_shared/http.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { encryptToken } from "../_shared/google-calendar/crypto.ts";

const db = serviceClient();
const CALENDAR_SCOPE =
  "https://www.googleapis.com/auth/calendar.events.readonly";

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`missing env ${name}`);
  return value;
}

Deno.serve(withErrors(async (req) => {
  if (req.method !== "GET") {
    throw new ApiError(405, "METHOD_NOT_ALLOWED", "Gunakan GET.");
  }

  const url = new URL(req.url);
  const state = url.searchParams.get("state") ?? "";
  if (!/^[0-9a-f]{64}$/.test(state)) {
    throw new ApiError(400, "INVALID_STATE", "Permintaan koneksi tidak valid.");
  }

  const clientId = requiredEnv("GOOGLE_CLIENT_ID");
  const clientSecret = requiredEnv("GOOGLE_CLIENT_SECRET");
  const redirectUri = requiredEnv("GOOGLE_CALENDAR_REDIRECT_URI");

  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(state),
  );
  const stateHash = Array.from(
    new Uint8Array(digest),
    b => b.toString(16).padStart(2, "0"),
  ).join("");

  // DELETE ... RETURNING mengonsumsi state secara atomik.
  // Callback kedua dengan state yang sama akan ditolak.
  const { data: pending, error: stateError } = await db
    .from("google_calendar_oauth_states")
    .delete()
    .eq("state_hash", stateHash)
    .gt("expires_at", new Date().toISOString())
    .select("owner_id")
    .maybeSingle();

  if (stateError) throw new Error("oauth state consume failed");
  if (!pending) {
    throw new ApiError(
      400, "INVALID_STATE",
      "Link sudah kedaluwarsa atau sudah dipakai. Hubungkan Calendar lagi.",
    );
  }

  if (url.searchParams.has("error")) {
    throw new ApiError(
      400, "GOOGLE_CONSENT_DENIED",
      "Izin Calendar belum diberikan. Kamu bisa mencoba lagi.",
    );
  }

  const code = url.searchParams.get("code");
  if (!code) {
    throw new ApiError(400, "MISSING_CODE", "Kode izin Google tidak tersedia.");
  }

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: clientId,
      client_secret: clientSecret,
      redirect_uri: redirectUri,
      grant_type: "authorization_code",
    }),
    signal: AbortSignal.timeout(15000),
  });

  if (!tokenResponse.ok) {
    throw new ApiError(
      502, "GOOGLE_TOKEN_EXCHANGE_FAILED",
      "Koneksi Google belum berhasil. Hubungkan Calendar lagi.",
    );
  }

  const tokens = await tokenResponse.json();
  const scopes: string[] = typeof tokens.scope === "string"
    ? tokens.scope.split(/\s+/).filter(Boolean)
    : [];

  if (!scopes.includes(CALENDAR_SCOPE)) {
    throw new ApiError(
      403, "CALENDAR_PERMISSION_MISSING",
      "Berikan izin membaca acara Calendar saat menghubungkan akun.",
    );
  }

  // Jangan menggunakan token lama jika Google tidak memberikan refresh token.
  if (typeof tokens.refresh_token !== "string" || !tokens.refresh_token) {
    throw new ApiError(
      400, "GOOGLE_REFRESH_TOKEN_MISSING",
      "Google belum memberikan akses berkelanjutan. Hubungkan Calendar lagi.",
    );
  }

  const encrypted = await encryptToken(
    tokens.refresh_token,
    pending.owner_id,
  );
  const now = new Date().toISOString();

  const { error: saveError } = await db
    .from("google_calendar_connections")
    .upsert({
      owner_id: pending.owner_id,
      refresh_token_encrypted: encrypted,
      granted_scopes: scopes,
      calendar_id: "primary",
      connected_at: now,
      updated_at: now,
      last_synced_at: null,
    }, { onConflict: "owner_id" });

  if (saveError) throw new Error("calendar connection save failed");

  return new Response(
    "<!doctype html><html lang='id'><meta charset='utf-8'>" +
    "<meta name='viewport' content='width=device-width,initial-scale=1'>" +
    "<title>Calendar terhubung</title>" +
    "<h1>Google Calendar berhasil terhubung</h1>" +
    "<p>Kembali ke Orbhita untuk menyinkronkan jadwal.</p></html>",
    {
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
        "Referrer-Policy": "no-referrer",
        "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
      },
    },
  );
}));
