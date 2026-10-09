import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";
import { PDFDocument } from "../_shared/deps.ts";
import { ApiError } from "../_shared/http.ts";
import { checkMedia, parseExtractRequest } from "./input.ts";

const UID = "11111111-1111-4111-8111-111111111111";
const OTHER = "22222222-2222-4222-8222-222222222222";
const OP = "33333333-3333-4333-8333-333333333333";

function body(over: Record<string, unknown> = {}) {
  return { operation_id: OP, input_type: "text", text: "Kerjakan laporan", requested_assistance: ["steps"], ...over };
}

function code(fn: () => unknown): string {
  try {
    fn();
  } catch (e) {
    if (e instanceof ApiError) return `${e.status}:${e.code}`;
    throw e;
  }
  return "no error";
}

async function codeAsync(fn: () => Promise<unknown>): Promise<string> {
  try {
    await fn();
  } catch (e) {
    if (e instanceof ApiError) return `${e.status}:${e.code}`;
    throw e;
  }
  return "no error";
}

const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

async function pdfWithPages(n: number): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  for (let i = 0; i < n; i++) doc.addPage();
  return await doc.save({ useObjectStreams: false });
}

async function encryptedPdf(): Promise<Uint8Array> {
  const text = new TextDecoder("latin1").decode(await pdfWithPages(1));
  const patched = text.replace("trailer\n<<", "trailer\n<<\n/Encrypt << /Filter /Standard /V 1 /R 2 >>");
  return Uint8Array.from(patched, (c) => c.charCodeAt(0));
}

Deno.test("teks valid diterima", () => {
  const r = parseExtractRequest(body(), UID);
  assertEquals(r, {
    operationId: OP,
    inputType: "text",
    text: "Kerjakan laporan",
    storagePaths: [],
    requestedAssistance: ["steps"],
  });
});

Deno.test("teks kosong atau lebih dari 10000 karakter ditolak INVALID_INPUT", () => {
  assertEquals(code(() => parseExtractRequest(body({ text: "   " }), UID)), "400:INVALID_INPUT");
  assertEquals(code(() => parseExtractRequest(body({ text: "a".repeat(10001) }), UID)), "400:INVALID_INPUT");
  assertEquals(code(() => parseExtractRequest(body({ text: "a".repeat(10000) }), UID)), "no error");
});

Deno.test("operation_id bukan UUID ditolak", () => {
  assertEquals(code(() => parseExtractRequest(body({ operation_id: "abc" }), UID)), "400:INVALID_INPUT");
});

Deno.test("body bukan objek ditolak", () => {
  assertEquals(code(() => parseExtractRequest(null, UID)), "400:INVALID_INPUT");
});

Deno.test("path milik pengguna lain ditolak FORBIDDEN", () => {
  const b = body({ input_type: "image", text: null, storage_paths: [`${OTHER}/a.jpg`] });
  assertEquals(code(() => parseExtractRequest(b, UID)), "403:FORBIDDEN");
  const traversal = body({ input_type: "image", text: null, storage_paths: [`${UID}/../${OTHER}/a.jpg`] });
  assertEquals(code(() => parseExtractRequest(traversal, UID)), "403:FORBIDDEN");
});

Deno.test("image tanpa path atau lebih dari 5 file ditolak", () => {
  assertEquals(code(() => parseExtractRequest(body({ input_type: "image", storage_paths: [] }), UID)), "400:INVALID_INPUT");
  const six = Array.from({ length: 6 }, (_, i) => `${UID}/${i}.jpg`);
  assertEquals(code(() => parseExtractRequest(body({ input_type: "image", storage_paths: six }), UID)), "400:INVALID_INPUT");
});

Deno.test("pdf wajib tepat satu file", () => {
  const two = [`${UID}/a.pdf`, `${UID}/b.pdf`];
  assertEquals(code(() => parseExtractRequest(body({ input_type: "pdf", storage_paths: two }), UID)), "400:INVALID_INPUT");
});

Deno.test("requested_assistance di luar enum ditolak", () => {
  assertEquals(code(() => parseExtractRequest(body({ requested_assistance: ["hack"] }), UID)), "400:INVALID_INPUT");
});

Deno.test("magic bytes tidak cocok ditolak UNSUPPORTED_MEDIA", async () => {
  const fakeJpg = new TextEncoder().encode("%PDF-1.7 not an image");
  assertEquals(await codeAsync(() => checkMedia("image", [{ path: "a.jpg", bytes: fakeJpg }])), "400:UNSUPPORTED_MEDIA");
});

Deno.test("gambar JPG dan PNG diterima sebagai base64", async () => {
  const parts = await checkMedia("image", [{ path: "a.jpg", bytes: JPEG }, { path: "b.png", bytes: PNG }]);
  assertEquals(parts.map((p) => p.mediaType), ["image/jpeg", "image/png"]);
  assertEquals(parts[0].kind, "image");
  assertEquals(parts[1].base64, "iVBORw0KGgo=");
});

Deno.test("total gambar lebih dari 10 MB ditolak PAYLOAD_TOO_LARGE", async () => {
  const big = new Uint8Array(6 * 1024 * 1024);
  big.set(JPEG);
  assertEquals(
    await codeAsync(() => checkMedia("image", [{ path: "a.jpg", bytes: big }, { path: "b.jpg", bytes: big }])),
    "413:PAYLOAD_TOO_LARGE",
  );
});

Deno.test("PDF valid diterima", async () => {
  const parts = await checkMedia("pdf", [{ path: "a.pdf", bytes: await pdfWithPages(3) }]);
  assertEquals(parts.map((p) => [p.kind, p.mediaType]), [["pdf", "application/pdf"]]);
});

Deno.test("PDF lebih dari 20 halaman ditolak PDF_TOO_MANY_PAGES", async () => {
  const bytes = await pdfWithPages(21);
  assertEquals(await codeAsync(() => checkMedia("pdf", [{ path: "a.pdf", bytes }])), "400:PDF_TOO_MANY_PAGES");
});

Deno.test("PDF terenkripsi ditolak PDF_ENCRYPTED", async () => {
  const bytes = await encryptedPdf();
  assertEquals(await codeAsync(() => checkMedia("pdf", [{ path: "a.pdf", bytes }])), "400:PDF_ENCRYPTED");
});

Deno.test("PDF rusak ditolak UNSUPPORTED_MEDIA", async () => {
  const bytes = new TextEncoder().encode("%PDF-1.7 garbage");
  await assertRejects(() => checkMedia("pdf", [{ path: "a.pdf", bytes }]), ApiError);
});

Deno.test("checkMedia tidak menerima jenis text", () => {
  assertThrows(() => {
    // @ts-expect-error runtime guard
    checkMedia("text", []);
  });
});
