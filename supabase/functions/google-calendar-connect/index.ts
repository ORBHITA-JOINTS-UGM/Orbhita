import { ApiError, ok, withErrors } from "../_shared/http.ts";
import { makeAuthUserId, serviceClient } from "../_shared/supabase.ts";

const db = serviceClient();
const authUserId = makeAuthUserId(db);

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`missing env ${name}`);
  return value;
}

Deno.serve(withErrors(async (req) => {
  if (req.method !== "POST") {
    throw new ApiError(405, "METHOD_NOT_ALLOWED", "Gunakan POST.");
  }

  // Identitas pemilik selalu berasal dari token Supabase.
  const ownerId = await authUserId(req);
  const clientId = requiredEnv("GOOGLE_CLIENT_ID");
  const redirectUri = requiredEnv("GOOGLE_CALENDAR_REDIRECT_URI");

  // State acak berlaku 10 menit; database hanya menyimpan hash-nya.
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const state = Array.from(bytes, b => b.toString(16).padStart(2, "0")).join("");
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(state),
  );
  const stateHash = Array.from(
    new Uint8Array(digest),
    b => b.toString(16).padStart(2, "0"),
  ).join("");

  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

  const { error } = await db
    .from("google_calendar_oauth_states")
    .insert({
      owner_id: ownerId,
      state_hash: stateHash,
      expires_at: expiresAt,
    });

  if (error) throw new Error("oauth state insert failed");

  const url = new URL("https://accounts.google.com/o/oauth2/v2/auth");
  url.search = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUri,
    response_type: "code",
    scope: "https://www.googleapis.com/auth/calendar.events.readonly",
    access_type: "offline",
    prompt: "consent",
    state,
  }).toString();

  const response = ok({
    authorization_url: url.toString(),
    expires_at: expiresAt,
  });
  response.headers.set("Cache-Control", "no-store");
  return response;
}));
