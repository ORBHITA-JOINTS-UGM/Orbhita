import { Anthropic } from "../deps.ts";
import { buildUserContent, PROMPT_VERSION, SYSTEM_PROMPT } from "./prompt.ts";
import { type Assistance, type Proposal, PROPOSAL_JSON_SCHEMA } from "./schema.ts";
import { validateProposal } from "./validate.ts";

export interface MediaPart {
  kind: "image" | "pdf";
  mediaType: "image/jpeg" | "image/png" | "application/pdf";
  base64: string;
}

export interface ExtractInput {
  inputType: "text" | "image" | "pdf" | "voice";
  text: string | null;
  media: MediaPart[];
  requestedAssistance: Assistance[];
  referenceNow: number;
  timezone: string;
}

/** The subset of the SDK's beta messages client this module relies on. */
export interface MessagesApi {
  create(params: Record<string, unknown>): Promise<any>;
}

export type ExtractResult =
  | { ok: true; proposal: Proposal; usage: Record<string, number>; modelId: string; promptVersion: string }
  | { ok: false; code: "AI_REFUSED" | "AI_FAILED" | "AI_INVALID_OUTPUT"; message: string };

const MAX_TOKENS = 16000;
const FALLBACK_BETA = "server-side-fallback-2026-07-01";

export function anthropicMessagesApi(apiKey: string): MessagesApi {
  const client = new Anthropic({ apiKey, maxRetries: 2 });
  return { create: (params) => client.beta.messages.create(params as any) };
}

function addUsage(total: Record<string, number>, usage: Record<string, unknown> | undefined) {
  for (const [k, v] of Object.entries(usage ?? {})) {
    if (typeof v === "number") total[k] = (total[k] ?? 0) + v;
  }
}

function parse(response: any): { proposal: Proposal | null; errors: string[] } {
  const text = (response.content ?? [])
    .filter((b: any) => b.type === "text")
    .map((b: any) => b.text)
    .join("");
  try {
    const { proposal, errors } = validateProposal(JSON.parse(text) as Proposal);
    return { proposal, errors };
  } catch {
    return { proposal: null, errors: ["invalid_json"] };
  }
}

export async function extractProposal(
  api: MessagesApi,
  cfg: { model: string; effort: string },
  input: ExtractInput,
): Promise<ExtractResult> {
  const messages: unknown[] = [{ role: "user", content: buildUserContent(input) }];
  const usage: Record<string, number> = {};

  for (let attempt = 0; attempt < 2; attempt++) {
    let response: any;
    try {
      response = await api.create({
        model: cfg.model,
        max_tokens: MAX_TOKENS,
        betas: [FALLBACK_BETA],
        fallbacks: "default",
        system: SYSTEM_PROMPT,
        output_config: { effort: cfg.effort, format: { type: "json_schema", schema: PROPOSAL_JSON_SCHEMA } },
        messages,
      });
    } catch {
      return { ok: false, code: "AI_FAILED", message: "Layanan AI sedang tidak dapat dihubungi." };
    }
    addUsage(usage, response.usage);

    if (response.stop_reason === "refusal") {
      return { ok: false, code: "AI_REFUSED", message: "AI menolak memproses input ini." };
    }
    if (response.stop_reason === "max_tokens") {
      return { ok: false, code: "AI_FAILED", message: "Jawaban AI terpotong." };
    }

    const { proposal, errors } = parse(response);
    if (proposal && errors.length === 0) {
      return { ok: true, proposal, usage, modelId: response.model ?? cfg.model, promptVersion: PROMPT_VERSION };
    }

    // One repair round: keep the original turn intact and append a correction request.
    messages.push({ role: "assistant", content: response.content });
    messages.push({
      role: "user",
      content: [{
        type: "text",
        text: `Draf sebelumnya melanggar aturan berikut: ${errors.join(", ")}. ` +
          "Kirim ulang draf lengkap yang sudah diperbaiki sesuai schema.",
      }],
    });
  }

  return { ok: false, code: "AI_INVALID_OUTPUT", message: "AI tidak menghasilkan draf yang valid." };
}
