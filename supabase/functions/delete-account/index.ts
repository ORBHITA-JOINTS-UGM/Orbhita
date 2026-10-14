import { makeAuthUserId, serviceClient } from "../_shared/supabase.ts";
import { createDeleteAccountHandler } from "./handler.ts";
import { supabaseDeleteAccountRepo } from "./repo.ts";

const db = serviceClient();
const repo = supabaseDeleteAccountRepo(db);

Deno.serve(createDeleteAccountHandler({
  authUserId: makeAuthUserId(db),
  ...repo,
}));
