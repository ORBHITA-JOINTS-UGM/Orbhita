import { ApiError, ok, withErrors } from "../_shared/http.ts";
import { canonicalJson, sha256Hex } from "../_shared/hash.ts";
import type { ExtractInput, ExtractResult, MediaPart } from "../_shared/claude/extract.ts";
import type { Proposal } from "../_shared/claude/schema.ts";
import { checkMedia, parseExtractRequest } from "./input.ts";

export interface ExtractRepo {
  findOperation(userId: string, operationId: string): Promise<{ requestHash: string; response: unknown } | null>;
  countSourcesSince(userId: string, since: number): Promise<number>;
  /** True if a source started after `since` is still processing; older ones count as abandoned. */
  hasProcessing(userId: string, since: number): Promise<boolean>;
  getTimezone(userId: string): Promise<string>;
  insertSource(userId: string, s: { inputType: string; text: string | null; storagePaths: string[] }): Promise<string>;
  finishSource(sourceId: string, status: "completed" | "failed", errorCode: string | null): Promise<void>;
  markMediaCleaned(sourceId: string): Promise<void>;
  insertProposal(userId: string, p: {
    sourceId: string;
    payload: Proposal;
    payloadHash: string;
    modelId: string;
    promptVersion: string;
    usage: unknown;
  }): Promise<string>;
  saveOperation(userId: string, operationId: string, requestHash: string, response: unknown): Promise<void>;
}

export interface ExtractDeps {
  authUserId(req: Request): Promise<string>;
  repo: ExtractRepo;
  storage: { download(path: string): Promise<Uint8Array>; remove(paths: string[]): Promise<void> };
  extract(input: ExtractInput): Promise<ExtractResult>;
  now(): number;
}

const RATE_WINDOW_MS = 10 * 60 * 1000;
const RATE_LIMIT = 10;
const STALE_PROCESSING_MS = 5 * 60 * 1000;

export function createExtractHandler(deps: ExtractDeps): (req: Request) => Promise<Response> {
  const { repo } = deps;

  return withErrors(async (req) => {
    if (req.method !== "POST") throw new ApiError(405, "METHOD_NOT_ALLOWED", "Gunakan POST.");
    const userId = await deps.authUserId(req);

    let body: unknown;
    try {
      body = await req.json();
    } catch {
      throw new ApiError(400, "INVALID_INPUT", "Body harus berupa JSON.");
    }
    const input = parseExtractRequest(body, userId);
    const requestHash = await sha256Hex(canonicalJson(body));

    const previous = await repo.findOperation(userId, input.operationId);
    if (previous) {
      if (previous.requestHash !== requestHash) {
        throw new ApiError(409, "OPERATION_REUSED", "operation_id sudah dipakai untuk permintaan lain.");
      }
      return ok(previous.response, input.operationId);
    }

    if (await repo.countSourcesSince(userId, deps.now() - RATE_WINDOW_MS) >= RATE_LIMIT) {
      throw new ApiError(429, "RATE_LIMITED", "Terlalu banyak input. Coba lagi beberapa menit lagi.", {
        retryable: true,
        retryAfter: RATE_WINDOW_MS / 1000,
      });
    }
    // A worker killed by the runtime time limit never reaches `finally`; don't lock the user out.
    if (await repo.hasProcessing(userId, deps.now() - STALE_PROCESSING_MS)) {
      throw new ApiError(429, "RATE_LIMITED", "Masih ada input yang sedang diproses.", {
        retryable: true,
        retryAfter: 30,
      });
    }

    const timezone = await repo.getTimezone(userId);
    const sourceId = await repo.insertSource(userId, {
      inputType: input.inputType,
      text: input.text,
      storagePaths: input.storagePaths,
    });

    let finished = false;
    try {
      let media: MediaPart[] = [];
      if (input.inputType === "image" || input.inputType === "pdf") {
        const files = await Promise.all(
          input.storagePaths.map(async (path) => ({ path, bytes: await deps.storage.download(path) })),
        );
        media = await checkMedia(input.inputType, files);
      }

      const result = await deps.extract({
        inputType: input.inputType,
        text: input.text,
        media,
        requestedAssistance: input.requestedAssistance,
        referenceNow: deps.now(),
        timezone,
      });
      if (!result.ok) {
        throw new ApiError(502, result.code, result.message, { retryable: result.code === "AI_FAILED" });
      }

      const payloadHash = await sha256Hex(canonicalJson(result.proposal));
      const proposalId = await repo.insertProposal(userId, {
        sourceId,
        payload: result.proposal,
        payloadHash,
        modelId: result.modelId,
        promptVersion: result.promptVersion,
        usage: result.usage,
      });
      await repo.finishSource(sourceId, "completed", null);
      finished = true;

      const response = { source_id: sourceId, proposal_id: proposalId, payload_hash: payloadHash, proposal: result.proposal };
      await repo.saveOperation(userId, input.operationId, requestHash, response);
      return ok(response, input.operationId);
    } catch (err) {
      if (!finished) {
        await repo.finishSource(sourceId, "failed", err instanceof ApiError ? err.code : "INTERNAL");
      }
      throw err;
    } finally {
      if (input.storagePaths.length) {
        try {
          await deps.storage.remove(input.storagePaths);
          await repo.markMediaCleaned(sourceId);
        } catch {
          // Left for the cleanup job; media_cleaned_at stays null so it can be found.
          console.error(JSON.stringify({ source_id: sourceId, code: "MEDIA_CLEANUP_FAILED" }));
        }
      }
    }
  });
}
