import { createClient, type SupabaseClient } from "./deps.ts";
import { ApiError } from "./http.ts";

function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing env ${name}`);
  return v;
}

/** Service-role client. Every query made with it must filter by the verified owner id. */
export function serviceClient(): SupabaseClient {
  return createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Resolves the caller's user id from the Bearer JWT; never from the request body. */
export function makeAuthUserId(client: SupabaseClient): (req: Request) => Promise<string> {
  return async (req) => {
    const header = req.headers.get("Authorization") ?? "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : "";
    if (!token) throw new ApiError(401, "UNAUTHENTICATED", "Sesi tidak valid. Silakan masuk lagi.");
    const { data, error } = await client.auth.getUser(token);
    if (error || !data.user) throw new ApiError(401, "UNAUTHENTICATED", "Sesi tidak valid. Silakan masuk lagi.");
    return data.user.id;
  };
}

/** Throws a generic 500 for a failed query without exposing database details. */
export function check<T>(res: { data: T; error: unknown }): T {
  if (res.error) throw new Error("database query failed");
  return res.data;
}
