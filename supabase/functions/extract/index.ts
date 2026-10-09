import { anthropicMessagesApi, extractProposal } from "../_shared/claude/extract.ts";
import { makeAuthUserId, serviceClient } from "../_shared/supabase.ts";
import { createExtractHandler } from "./handler.ts";
import { supabaseExtractRepo, supabaseStorage } from "./repo.ts";

const db = serviceClient();
const api = anthropicMessagesApi(Deno.env.get("ANTHROPIC_API_KEY") ?? "");
const cfg = {
  model: Deno.env.get("CLAUDE_MODEL") ?? "claude-sonnet-5-5",
  effort: Deno.env.get("CLAUDE_EFFORT") ?? "medium",
};

Deno.serve(createExtractHandler({
  authUserId: makeAuthUserId(db),
  repo: supabaseExtractRepo(db),
  storage: supabaseStorage(db),
  extract: (input) => extractProposal(api, cfg, input),
  now: () => Date.now(),
}));
