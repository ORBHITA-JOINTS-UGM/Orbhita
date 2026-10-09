import type { SupabaseClient } from "../_shared/deps.ts";
import { check } from "../_shared/supabase.ts";
import type { ExtractRepo } from "./handler.ts";

const PROPOSAL_TTL_MS = 24 * 60 * 60 * 1000;
const BUCKET = "inputs";

export function supabaseExtractRepo(db: SupabaseClient): ExtractRepo {
  return {
    async findOperation(userId, operationId) {
      const row = check(
        await db.from("operations").select("request_hash, response")
          .eq("owner_id", userId).eq("operation_id", operationId).maybeSingle(),
      ) as { request_hash: string; response: unknown } | null;
      return row ? { requestHash: row.request_hash, response: row.response } : null;
    },

    async countSourcesSince(userId, since) {
      const res = await db.from("sources").select("id", { count: "exact", head: true })
        .eq("owner_id", userId).gte("created_at", new Date(since).toISOString());
      check(res);
      return res.count ?? 0;
    },

    async hasProcessing(userId) {
      const res = await db.from("sources").select("id", { count: "exact", head: true })
        .eq("owner_id", userId).eq("status", "processing");
      check(res);
      return (res.count ?? 0) > 0;
    },

    async getTimezone(userId) {
      const row = check(
        await db.from("profiles").select("timezone").eq("id", userId).maybeSingle(),
      ) as { timezone: string } | null;
      return row?.timezone ?? "Asia/Jakarta";
    },

    async insertSource(userId, s) {
      const row = check(
        await db.from("sources").insert({
          owner_id: userId,
          input_type: s.inputType,
          text_content: s.text,
          storage_paths: s.storagePaths,
          status: "processing",
        }).select("id").single(),
      ) as { id: string };
      return row.id;
    },

    async finishSource(sourceId, status, errorCode) {
      check(await db.from("sources").update({ status, error_code: errorCode }).eq("id", sourceId));
    },

    async markMediaCleaned(sourceId) {
      check(await db.from("sources").update({ media_cleaned_at: new Date().toISOString() }).eq("id", sourceId));
    },

    async insertProposal(userId, p) {
      check(
        await db.from("proposals").update({ status: "superseded" })
          .eq("owner_id", userId).eq("source_id", p.sourceId).eq("status", "proposed"),
      );
      const row = check(
        await db.from("proposals").insert({
          owner_id: userId,
          source_id: p.sourceId,
          intent: p.payload.intent,
          payload: p.payload,
          payload_hash: p.payloadHash,
          status: "proposed",
          expires_at: new Date(Date.now() + PROPOSAL_TTL_MS).toISOString(),
          model_id: p.modelId,
          prompt_version: p.promptVersion,
          usage: p.usage,
        }).select("id").single(),
      ) as { id: string };
      return row.id;
    },

    async saveOperation(userId, operationId, requestHash, response) {
      check(
        await db.from("operations").insert({
          owner_id: userId,
          operation_id: operationId,
          kind: "extract",
          request_hash: requestHash,
          response,
        }),
      );
    },
  };
}

export function supabaseStorage(db: SupabaseClient) {
  return {
    async download(path: string): Promise<Uint8Array> {
      const { data, error } = await db.storage.from(BUCKET).download(path);
      if (error || !data) throw new Error("storage download failed");
      return new Uint8Array(await data.arrayBuffer());
    },
    async remove(paths: string[]): Promise<void> {
      const { error } = await db.storage.from(BUCKET).remove(paths);
      if (error) throw new Error("storage remove failed");
    },
  };
}
