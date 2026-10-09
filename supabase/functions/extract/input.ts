import { encodeBase64, PDFDocument } from "../_shared/deps.ts";
import { ApiError } from "../_shared/http.ts";
import { ASSISTANCE_VALUES, type Assistance } from "../_shared/claude/schema.ts";
import type { MediaPart } from "../_shared/claude/extract.ts";

export type InputType = "text" | "image" | "pdf" | "voice";

export interface ExtractRequest {
  operationId: string;
  inputType: InputType;
  text: string | null;
  storagePaths: string[];
  requestedAssistance: Assistance[];
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const INPUT_TYPES: InputType[] = ["text", "image", "pdf", "voice"];
const MAX_TEXT = 10_000;
const MAX_IMAGES = 5;
const MAX_BYTES = 10 * 1024 * 1024;
const MAX_PDF_PAGES = 20;
const FILE_NAME_RE = /^[A-Za-z0-9_-]{1,100}\.(jpe?g|png|pdf)$/i;

const invalid = (field: string, message: string) =>
  new ApiError(400, "INVALID_INPUT", message, { fieldErrors: { [field]: message } });

export function parseExtractRequest(body: unknown, userId: string): ExtractRequest {
  if (!body || typeof body !== "object" || Array.isArray(body)) throw invalid("body", "Body harus berupa objek JSON.");
  const b = body as Record<string, unknown>;

  if (typeof b.operation_id !== "string" || !UUID_RE.test(b.operation_id)) {
    throw invalid("operation_id", "operation_id harus UUID.");
  }
  if (!INPUT_TYPES.includes(b.input_type as InputType)) throw invalid("input_type", "input_type tidak dikenal.");
  const inputType = b.input_type as InputType;

  const rawText = typeof b.text === "string" ? b.text.trim() : null;
  if (b.text != null && typeof b.text !== "string") throw invalid("text", "text harus berupa string.");
  if ((inputType === "text" || inputType === "voice") && !rawText) throw invalid("text", "Teks tidak boleh kosong.");
  if (rawText && rawText.length > MAX_TEXT) throw invalid("text", `Teks maksimal ${MAX_TEXT} karakter.`);

  const paths = b.storage_paths ?? [];
  if (!Array.isArray(paths) || paths.some((p) => typeof p !== "string")) {
    throw invalid("storage_paths", "storage_paths harus daftar string.");
  }
  const storagePaths = paths as string[];
  if ((inputType === "text" || inputType === "voice") && storagePaths.length) {
    throw invalid("storage_paths", "Input teks tidak boleh membawa file.");
  }
  if (inputType === "image" && (storagePaths.length < 1 || storagePaths.length > MAX_IMAGES)) {
    throw invalid("storage_paths", `Kirim 1 sampai ${MAX_IMAGES} gambar.`);
  }
  if (inputType === "pdf" && storagePaths.length !== 1) throw invalid("storage_paths", "Kirim tepat satu PDF.");
  // Strict allow-list: the storage client does not encode paths, so "%2e%2e" would traverse.
  for (const p of storagePaths) {
    if (!p.startsWith(`${userId}/`) || !FILE_NAME_RE.test(p.slice(userId.length + 1))) {
      throw new ApiError(403, "FORBIDDEN", "File bukan milik pengguna ini.");
    }
  }

  const assistance = b.requested_assistance ?? [];
  if (!Array.isArray(assistance) || assistance.some((a) => !ASSISTANCE_VALUES.includes(a as Assistance))) {
    throw invalid("requested_assistance", "Pilihan bantuan tidak dikenal.");
  }

  return {
    operationId: b.operation_id,
    inputType,
    text: rawText || null,
    storagePaths,
    requestedAssistance: [...new Set(assistance as Assistance[])],
  };
}

function startsWith(bytes: Uint8Array, sig: number[]): boolean {
  return sig.every((v, i) => bytes[i] === v);
}

const unsupported = () => new ApiError(400, "UNSUPPORTED_MEDIA", "Format file tidak didukung.");

async function checkPdf(bytes: Uint8Array): Promise<void> {
  // pdf-lib's encryption error is not distinguishable by class/name, so load with
  // ignoreEncryption and check the flag. Broken files can load and then fail on access.
  let pages: number;
  try {
    const doc = await PDFDocument.load(bytes, { updateMetadata: false, ignoreEncryption: true });
    if (doc.isEncrypted) {
      throw new ApiError(400, "PDF_ENCRYPTED", "PDF terkunci kata sandi tidak dapat diproses.");
    }
    pages = doc.getPageCount();
  } catch (e) {
    if (e instanceof ApiError) throw e;
    throw unsupported();
  }
  if (pages > MAX_PDF_PAGES) {
    throw new ApiError(400, "PDF_TOO_MANY_PAGES", `PDF maksimal ${MAX_PDF_PAGES} halaman.`);
  }
}

/** Verifies file contents (not just names) and returns base64 parts for Claude. */
export function checkMedia(
  inputType: "image" | "pdf",
  files: { path: string; bytes: Uint8Array }[],
): Promise<MediaPart[]> {
  if (inputType !== "image" && inputType !== "pdf") throw new Error(`checkMedia: unsupported type ${inputType}`);
  return (async () => {
    const total = files.reduce((sum, f) => sum + f.bytes.byteLength, 0);
    if (total > MAX_BYTES) throw new ApiError(413, "PAYLOAD_TOO_LARGE", "Total ukuran file maksimal 10 MB.");

    const parts: MediaPart[] = [];
    for (const f of files) {
      if (inputType === "image") {
        let mediaType: MediaPart["mediaType"];
        if (startsWith(f.bytes, [0xff, 0xd8, 0xff])) mediaType = "image/jpeg";
        else if (startsWith(f.bytes, [0x89, 0x50, 0x4e, 0x47])) mediaType = "image/png";
        else throw unsupported();
        parts.push({ kind: "image", mediaType, base64: encodeBase64(f.bytes) });
      } else {
        if (!startsWith(f.bytes, [0x25, 0x50, 0x44, 0x46])) throw unsupported();
        await checkPdf(f.bytes);
        parts.push({ kind: "pdf", mediaType: "application/pdf", base64: encodeBase64(f.bytes) });
      }
    }
    return parts;
  })();
}
