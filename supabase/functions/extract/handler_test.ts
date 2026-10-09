import { assert, assertEquals } from "jsr:@std/assert@1";
import { ApiError } from "../_shared/http.ts";
import type { ExtractInput, ExtractResult } from "../_shared/claude/extract.ts";
import type { Proposal } from "../_shared/claude/schema.ts";
import { createExtractHandler, type ExtractDeps, type ExtractRepo } from "./handler.ts";

const UID = "11111111-1111-4111-8111-111111111111";
const OP = "33333333-3333-4333-8333-333333333333";
const NOW = Date.parse("2026-10-08T10:00:00Z");
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);

const PROPOSAL: Proposal = {
  schema_version: "1",
  intent: "task",
  title: "Laporan",
  course: null,
  requirements: [],
  official_deadline: { at: null, original_text: null, needs_confirmation: true },
  personal_target: { at: null, original_text: null, needs_confirmation: false },
  steps: [],
  activity: null,
  requested_assistance: [],
  assumptions: [],
  questions: ["Kapan deadline resmi tugas ini?"],
  warnings: [],
  first_action: null,
  explanation: "ok",
};

class FakeRepo implements ExtractRepo {
  operations = new Map<string, { requestHash: string; response: unknown }>();
  sources: { id: string; createdAt: number; status: string; errorCode: string | null; cleaned: boolean }[] = [];
  proposals: unknown[] = [];
  recentCount = 0;
  processing = false;

  findOperation(_u: string, op: string) {
    return Promise.resolve(this.operations.get(op) ?? null);
  }
  countSourcesSince(_u: string, _since: number) {
    return Promise.resolve(this.recentCount);
  }
  processingSince: number | null = null;
  hasProcessing(_u: string, since: number) {
    this.processingSince = since;
    return Promise.resolve(this.processing);
  }
  getTimezone(_u: string) {
    return Promise.resolve("Asia/Jakarta");
  }
  insertSource(_u: string, _s: unknown) {
    const id = `src-${this.sources.length + 1}`;
    this.sources.push({ id, createdAt: NOW, status: "processing", errorCode: null, cleaned: false });
    return Promise.resolve(id);
  }
  finishSource(id: string, status: "completed" | "failed", errorCode: string | null) {
    const s = this.sources.find((x) => x.id === id)!;
    s.status = status;
    s.errorCode = errorCode;
    return Promise.resolve();
  }
  markMediaCleaned(id: string) {
    this.sources.find((x) => x.id === id)!.cleaned = true;
    return Promise.resolve();
  }
  insertProposal(_u: string, p: unknown) {
    this.proposals.push(p);
    return Promise.resolve(`prop-${this.proposals.length}`);
  }
  saveOperation(_u: string, op: string, requestHash: string, response: unknown) {
    this.operations.set(op, { requestHash, response });
    return Promise.resolve();
  }
}

function setup(result: ExtractResult = {
  ok: true,
  proposal: PROPOSAL,
  usage: { input_tokens: 10 },
  modelId: "claude-sonnet-5-5",
  promptVersion: "extract-v1",
}) {
  const repo = new FakeRepo();
  const removed: string[][] = [];
  const extractCalls: ExtractInput[] = [];
  const deps: ExtractDeps = {
    authUserId: (req) => {
      if (req.headers.get("Authorization") !== "Bearer good") {
        return Promise.reject(new ApiError(401, "UNAUTHENTICATED", "Sesi tidak valid."));
      }
      return Promise.resolve(UID);
    },
    repo,
    storage: {
      download: () => Promise.resolve(JPEG),
      remove: (paths) => {
        removed.push(paths);
        return Promise.resolve();
      },
    },
    extract: (input) => {
      extractCalls.push(input);
      return Promise.resolve(result);
    },
    now: () => NOW,
  };
  return { handler: createExtractHandler(deps), repo, removed, extractCalls };
}

function post(body: unknown, auth = "Bearer good") {
  return new Request("http://localhost/extract", {
    method: "POST",
    headers: { Authorization: auth, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

const textBody = { operation_id: OP, input_type: "text", text: "Buat laporan", requested_assistance: ["steps"] };
const imageBody = { operation_id: OP, input_type: "image", storage_paths: [`${UID}/a.jpg`] };

Deno.test("teks valid menghasilkan proposal tersimpan dan respons 200", async () => {
  const { handler, repo } = setup();
  const res = await handler(post(textBody));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.operation_id, OP);
  assertEquals(body.data.source_id, "src-1");
  assertEquals(body.data.proposal_id, "prop-1");
  assertEquals(body.data.payload_hash.length, 64);
  assertEquals(body.data.proposal.title, "Laporan");
  assertEquals(repo.sources[0].status, "completed");
});

Deno.test("operation_id sama dipanggil ulang mengembalikan respons tersimpan tanpa memanggil Claude", async () => {
  const { handler, repo, extractCalls } = setup();
  const first = await (await handler(post(textBody))).json();
  const second = await (await handler(post(textBody))).json();
  assertEquals(second, first);
  assertEquals(extractCalls.length, 1);
  assertEquals(repo.sources.length, 1);
});

Deno.test("operation_id sama dengan body berbeda ditolak OPERATION_REUSED", async () => {
  const { handler } = setup();
  await handler(post(textBody));
  const res = await handler(post({ ...textBody, text: "lain" }));
  assertEquals(res.status, 409);
  assertEquals((await res.json()).error.code, "OPERATION_REUSED");
});

Deno.test("lebih dari 10 input dalam 10 menit ditolak RATE_LIMITED dengan retry_after", async () => {
  const { handler, repo, extractCalls } = setup();
  repo.recentCount = 10;
  const res = await handler(post(textBody));
  assertEquals(res.status, 429);
  assertEquals((await res.json()).error.code, "RATE_LIMITED");
  assert(Number(res.headers.get("Retry-After")) > 0);
  assertEquals(extractCalls.length, 0);
});

Deno.test("sudah ada source processing ditolak RATE_LIMITED", async () => {
  const { handler, repo } = setup();
  repo.processing = true;
  const res = await handler(post(textBody));
  assertEquals(res.status, 429);
});

Deno.test("source processing yang lebih tua dari 5 menit tidak menghalangi", async () => {
  const { handler, repo } = setup();
  await handler(post(textBody));
  assertEquals(repo.processingSince, NOW - 5 * 60 * 1000);
});

Deno.test("media dihapus dari storage saat Claude gagal", async () => {
  const { handler, repo, removed } = setup({ ok: false, code: "AI_FAILED", message: "x" });
  const res = await handler(post(imageBody));
  assertEquals(res.status, 502);
  assertEquals((await res.json()).error.code, "AI_FAILED");
  assertEquals(removed, [[`${UID}/a.jpg`]]);
  assertEquals(repo.sources[0].status, "failed");
  assertEquals(repo.sources[0].errorCode, "AI_FAILED");
  assertEquals(repo.sources[0].cleaned, true);
});

Deno.test("media dihapus dari storage saat berhasil", async () => {
  const { handler, repo, removed, extractCalls } = setup();
  const res = await handler(post(imageBody));
  assertEquals(res.status, 200);
  assertEquals(removed, [[`${UID}/a.jpg`]]);
  assertEquals(repo.sources[0].cleaned, true);
  assertEquals(extractCalls[0].media.map((m) => m.mediaType), ["image/jpeg"]);
});

Deno.test("media tidak valid ditandai gagal dan tetap dihapus", async () => {
  const { handler, repo, removed } = setup();
  const res = await handler(post({ ...imageBody, input_type: "pdf", storage_paths: [`${UID}/a.pdf`] }));
  assertEquals(res.status, 400);
  assertEquals(repo.sources[0].status, "failed");
  assertEquals(removed.length, 1);
});

Deno.test("tanpa JWT valid ditolak UNAUTHENTICATED", async () => {
  const { handler } = setup();
  const res = await handler(post(textBody, "Bearer bad"));
  assertEquals(res.status, 401);
});

Deno.test("timezone dan waktu server diteruskan ke extract", async () => {
  const { handler, extractCalls } = setup();
  await handler(post(textBody));
  assertEquals(extractCalls[0].timezone, "Asia/Jakarta");
  assertEquals(extractCalls[0].referenceNow, NOW);
  assertEquals(extractCalls[0].requestedAssistance, ["steps"]);
});

Deno.test("metode selain POST ditolak", async () => {
  const { handler } = setup();
  const res = await handler(new Request("http://localhost/extract", { method: "GET" }));
  assertEquals(res.status, 405);
});
