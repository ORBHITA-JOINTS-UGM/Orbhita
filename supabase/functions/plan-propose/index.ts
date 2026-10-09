import { makeAuthUserId, serviceClient } from "../_shared/supabase.ts";
import { createPlanProposeHandler } from "./handler.ts";
import { supabasePlanRepo } from "./repo.ts";

const db = serviceClient();

Deno.serve(createPlanProposeHandler({
  authUserId: makeAuthUserId(db),
  repo: supabasePlanRepo(db),
  now: () => Date.now(),
}));
