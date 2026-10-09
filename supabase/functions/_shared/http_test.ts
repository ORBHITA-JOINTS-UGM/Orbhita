import { assert, assertEquals } from "jsr:@std/assert@1";
import { ApiError, fail, ok, withErrors } from "./http.ts";
import { canonicalJson, sha256Hex } from "./hash.ts";

Deno.test("ApiError menjadi envelope dengan status dan kode", async () => {
  const res = fail(new ApiError(409, "STALE_PLAN", "Rencana sudah berubah", { retryable: false }), "req-1");
  assertEquals(res.status, 409);
  assertEquals(await res.json(), {
    error: { code: "STALE_PLAN", message: "Rencana sudah berubah", field_errors: {}, retryable: false },
    request_id: "req-1",
  });
});

Deno.test("RATE_LIMITED menyertakan header Retry-After", () => {
  const res = fail(new ApiError(429, "RATE_LIMITED", "Terlalu sering", { retryable: true, retryAfter: 120 }), "r");
  assertEquals(res.headers.get("Retry-After"), "120");
});

Deno.test("error tak dikenal menjadi 500 tanpa pesan internal", async () => {
  const res = fail(new Error("connection string postgres://user:pass@host"), "req-2");
  assertEquals(res.status, 500);
  const body = await res.json();
  assertEquals(body.error.code, "INTERNAL");
  assert(!JSON.stringify(body).includes("postgres://"));
});

Deno.test("ok membungkus data dan operation_id", async () => {
  const res = ok({ a: 1 }, "op-1");
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { data: { a: 1 }, operation_id: "op-1" });
});

Deno.test("withErrors menangkap ApiError dari handler", async () => {
  const handler = withErrors(() => {
    throw new ApiError(400, "INVALID_INPUT", "x");
  });
  const res = await handler(new Request("http://x"));
  assertEquals(res.status, 400);
  assert((await res.json()).request_id);
});

Deno.test("canonicalJson tidak bergantung urutan key", async () => {
  const a = canonicalJson({ b: 1, a: { d: [1, { y: 2, x: 1 }], c: null } });
  const b = canonicalJson({ a: { c: null, d: [1, { x: 1, y: 2 }] }, b: 1 });
  assertEquals(a, b);
  assertEquals(await sha256Hex(a), await sha256Hex(b));
  assertEquals((await sha256Hex("abc")).length, 64);
});
