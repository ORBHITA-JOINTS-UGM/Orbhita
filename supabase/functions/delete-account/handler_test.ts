import { ApiError } from "../_shared/http.ts";
import {
  createDeleteAccountHandler,
  type DeleteAccountDeps,
} from "./handler.ts";

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

function fixture(failure?: string) {
  const calls: string[] = [];
  const action = (name: string) => async (ownerId: string) => {
    calls.push(`${name}:${ownerId}`);
    if (failure === name) throw new Error("simulated failure");
  };

  const deps: DeleteAccountDeps = {
    authUserId: async () => {
      calls.push("auth");
      if (failure === "auth") {
        throw new ApiError(401, "UNAUTHENTICATED", "Sesi tidak valid.");
      }
      return "verified-owner";
    },
    beginDeletion: action("begin"),
    revokeCalendar: action("calendar"),
    removeFiles: action("files"),
    deleteAuthUser: action("delete"),
  };

  return { calls, handler: createDeleteAccountHandler(deps) };
}

function request(body: unknown = { confirmation: "DELETE_MY_ACCOUNT" }) {
  return new Request("https://example.test/delete-account", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

Deno.test("hapus akun: metode selain POST tidak melakukan perubahan", async () => {
  const f = fixture();
  const res = await f.handler(new Request("https://example.test/delete-account"));
  equal(res.status, 405);
  equal(f.calls, []);
});

Deno.test("hapus akun: pengguna tanpa sesi ditolak", async () => {
  const f = fixture("auth");
  const res = await f.handler(request());
  equal(res.status, 401);
  equal(f.calls, ["auth"]);
});

Deno.test("hapus akun: konfirmasi salah dan owner dari body ditolak", async () => {
  for (const body of [
    {},
    { confirmation: "yes" },
    { confirmation: "DELETE_MY_ACCOUNT", owner_id: "other-owner" },
    ["DELETE_MY_ACCOUNT"],
    null,
  ]) {
    const f = fixture();
    const res = await f.handler(request(body));
    equal(res.status, 400);
    equal(f.calls, ["auth"]);
  }
});

Deno.test("hapus akun: JSON rusak tidak memulai penghapusan", async () => {
  const f = fixture();
  const res = await f.handler(new Request("https://example.test/delete-account", {
    method: "POST",
    body: "{",
  }));
  equal(res.status, 400);
  equal(f.calls, ["auth"]);
});

Deno.test("hapus akun: semua operasi memakai pemilik terverifikasi", async () => {
  const f = fixture();
  const res = await f.handler(request());
  equal(res.status, 200);
  equal(await res.json(), { data: { deleted: true } });
  equal(res.headers.get("Cache-Control"), "no-store");
  equal(f.calls, [
    "auth",
    "begin:verified-owner",
    "calendar:verified-owner",
    "files:verified-owner",
    "delete:verified-owner",
  ]);
});

Deno.test("hapus akun: gagal mencabut Calendar menghentikan penghapusan", async () => {
  const f = fixture("calendar");
  const res = await f.handler(request());
  const body = await res.json();
  equal(res.status, 503);
  equal(body.error.code, "DELETION_INCOMPLETE");
  equal(body.error.retryable, true);
  equal(f.calls, [
    "auth",
    "begin:verified-owner",
    "calendar:verified-owner",
  ]);
});

Deno.test("hapus akun: gagal membersihkan file tidak menghapus akun Auth", async () => {
  const f = fixture("files");
  const res = await f.handler(request());
  equal(res.status, 503);
  equal(f.calls, [
    "auth",
    "begin:verified-owner",
    "calendar:verified-owner",
    "files:verified-owner",
  ]);
});

Deno.test("hapus akun: kegagalan Auth tidak dilaporkan sebagai berhasil", async () => {
  const f = fixture("delete");
  const res = await f.handler(request());
  const body = await res.json();
  equal(res.status, 503);
  equal(body.error.code, "DELETION_INCOMPLETE");
  equal(body.error.retryable, true);
  equal(body.error.message.includes("simulated failure"), false);
});

Deno.test("hapus akun: gagal mengunci akun menghentikan semua pembersihan", async () => {
  const f = fixture("begin");
  const res = await f.handler(request());
  equal(res.status, 500);
  equal(f.calls, ["auth", "begin:verified-owner"]);
});
