import { assert, assertEquals } from "jsr:@std/assert@1";
import { type ExtractInput, extractProposal, type MessagesApi } from "./extract.ts";
import { PROMPT_VERSION, SYSTEM_PROMPT } from "./prompt.ts";
import { PROPOSAL_JSON_SCHEMA, type Proposal } from "./schema.ts";

const CFG = { model: "claude-sonnet-5-5", effort: "medium" };

function proposal(over: Partial<Proposal> = {}): Proposal {
  return {
    schema_version: "1",
    intent: "task",
    title: "Laporan",
    course: null,
    requirements: [],
    official_deadline: { at: "2026-10-09T14:00:00Z", original_text: "Jumat 21.00", needs_confirmation: false },
    personal_target: { at: null, original_text: null, needs_confirmation: false },
    steps: [{ client_step_id: "s1", title: "Tulis", estimate_minutes: 60, estimate_basis: "2 halaman", depends_on: [] }],
    activity: null,
    requested_assistance: ["steps"],
    assumptions: [],
    questions: [],
    warnings: [],
    first_action: "Buka instruksi",
    explanation: "ok",
    ...over,
  };
}

function reply(body: unknown, stop_reason = "end_turn") {
  return {
    model: CFG.model,
    stop_reason,
    content: [{ type: "thinking", thinking: "" }, { type: "text", text: JSON.stringify(body) }],
    usage: { input_tokens: 100, output_tokens: 50 },
  };
}

function fakeApi(responses: Array<unknown | Error>): MessagesApi & { calls: Record<string, any>[] } {
  const calls: Record<string, any>[] = [];
  return {
    calls,
    create(params) {
      calls.push(structuredClone(params));
      const next = responses.shift();
      if (next instanceof Error) return Promise.reject(next);
      return Promise.resolve(next);
    },
  };
}

const textInput = (over: Partial<ExtractInput> = {}): ExtractInput => ({
  inputType: "text",
  text: "Buat laporan praktikum, kumpul Jumat jam 21.00",
  media: [],
  requestedAssistance: ["steps"],
  referenceNow: Date.parse("2026-10-08T17:30:00Z"),
  timezone: "Asia/Jakarta",
  ...over,
});

Deno.test("request memakai model, effort, schema, dan fallback dari konfigurasi", async () => {
  const api = fakeApi([reply(proposal())]);
  await extractProposal(api, CFG, textInput());
  const p = api.calls[0];
  assertEquals(p.model, "claude-sonnet-5-5");
  assertEquals(p.output_config.effort, "medium");
  assertEquals(p.output_config.format, { type: "json_schema", schema: PROPOSAL_JSON_SCHEMA });
  assertEquals(p.fallbacks, "default");
  assertEquals(p.betas, ["server-side-fallback-2026-07-01"]);
  assertEquals(p.system, SYSTEM_PROMPT);
});

Deno.test("system prompt tidak memuat waktu atau data pengguna", () => {
  assert(!SYSTEM_PROMPT.includes("2026"));
  assert(!SYSTEM_PROMPT.includes("laporan praktikum"));
});

Deno.test("reference_now dikirim dalam waktu lokal dengan offset", async () => {
  const api = fakeApi([reply(proposal())]);
  await extractProposal(api, CFG, textInput());
  const blocks = api.calls[0].messages[0].content;
  const text = blocks[blocks.length - 1].text as string;
  assert(text.includes("2026-10-09T00:30:00+07:00"), text);
  assert(text.includes("Asia/Jakarta"));
  assert(text.includes("Buat laporan praktikum"));
});

Deno.test("gambar dan PDF dikirim sebelum blok teks", async () => {
  const api = fakeApi([reply(proposal())]);
  await extractProposal(api, CFG, textInput({
    inputType: "image",
    text: null,
    media: [
      { kind: "image", mediaType: "image/png", base64: "AAAA" },
      { kind: "pdf", mediaType: "application/pdf", base64: "BBBB" },
    ],
  }));
  const blocks = api.calls[0].messages[0].content;
  assertEquals(blocks.map((b: any) => b.type), ["image", "document", "text"]);
  assertEquals(blocks[0].source, { type: "base64", media_type: "image/png", data: "AAAA" });
  assertEquals(blocks[1].source, { type: "base64", media_type: "application/pdf", data: "BBBB" });
});

Deno.test("respons valid menghasilkan ok dengan usage dan model", async () => {
  const api = fakeApi([reply(proposal())]);
  const r = await extractProposal(api, CFG, textInput());
  assert(r.ok);
  assertEquals(r.proposal.title, "Laporan");
  assertEquals(r.modelId, "claude-sonnet-5-5");
  assertEquals(r.promptVersion, PROMPT_VERSION);
  assertEquals(r.usage.input_tokens, 100);
});

Deno.test("stop_reason refusal menghasilkan AI_REFUSED", async () => {
  const api = fakeApi([{ model: CFG.model, stop_reason: "refusal", content: [], usage: {} }]);
  const r = await extractProposal(api, CFG, textInput());
  assertEquals(r.ok ? null : r.code, "AI_REFUSED");
});

Deno.test("stop_reason max_tokens menghasilkan AI_FAILED", async () => {
  const api = fakeApi([reply(proposal(), "max_tokens")]);
  const r = await extractProposal(api, CFG, textInput());
  assertEquals(r.ok ? null : r.code, "AI_FAILED");
});

Deno.test("output melanggar validasi dicoba perbaiki sekali", async () => {
  const bad = proposal({
    steps: [{ client_step_id: "s1", title: "Tulis", estimate_minutes: 60, estimate_basis: "", depends_on: ["s9"] }],
  });
  const api = fakeApi([reply(bad), reply(proposal())]);
  const r = await extractProposal(api, CFG, textInput());
  assert(r.ok);
  assertEquals(api.calls.length, 2);
  const second = api.calls[1].messages;
  assertEquals(second.map((m: any) => m.role), ["user", "assistant", "user"]);
  assert(JSON.stringify(second[2].content).includes("unknown_dependency:s9"));
  assertEquals(r.usage.input_tokens, 200);
});

Deno.test("masih tidak valid setelah perbaikan menghasilkan AI_INVALID_OUTPUT", async () => {
  const bad = proposal({
    steps: [{ client_step_id: "s1", title: "Tulis", estimate_minutes: 0, estimate_basis: "", depends_on: [] }],
  });
  const api = fakeApi([reply(bad), reply(bad)]);
  const r = await extractProposal(api, CFG, textInput());
  assertEquals(r.ok ? null : r.code, "AI_INVALID_OUTPUT");
  assertEquals(api.calls.length, 2);
});

Deno.test("teks bukan JSON dianggap tidak valid dan dicoba perbaiki", async () => {
  const notJson = { model: CFG.model, stop_reason: "end_turn", content: [{ type: "text", text: "maaf" }], usage: {} };
  const api = fakeApi([notJson, reply(proposal())]);
  const r = await extractProposal(api, CFG, textInput());
  assert(r.ok);
  assertEquals(api.calls.length, 2);
});

Deno.test("exception dari API menghasilkan AI_FAILED tanpa membocorkan detail", async () => {
  const api = fakeApi([new Error("401 invalid x-api-key sk-ant-secret")]);
  const r = await extractProposal(api, CFG, textInput());
  assertEquals(r.ok ? null : r.code, "AI_FAILED");
  assert(!JSON.stringify(r).includes("sk-ant"));
});
