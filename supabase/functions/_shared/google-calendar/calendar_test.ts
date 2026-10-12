import { normalizeEvent } from "./events.ts";
import { encryptToken, decryptToken } from "./crypto.ts";

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

async function rejects(fn: () => Promise<unknown>) {
  try {
    await fn();
  } catch {
    return;
  }
  throw new Error("Expected operation to be rejected");
}

Deno.test("acara Jakarta dikonversi ke UTC", () => {
  const event = normalizeEvent({
    id: "meeting",
    start: { dateTime: "2026-10-10T08:00:00+07:00" },
    end: { dateTime: "2026-10-10T09:00:00+07:00" },
  }, "primary", "Asia/Jakarta");

  equal(event?.start_at, "2026-10-10T01:00:00Z");
  equal(event?.end_at, "2026-10-10T02:00:00Z");
});

Deno.test("acara seharian memakai tengah malam zona kalender", () => {
  const event = normalizeEvent({
    id: "holiday",
    start: { date: "2026-10-10" },
    end: { date: "2026-10-11" },
  }, "primary", "Asia/Jakarta");

  equal(event?.start_at, "2026-10-09T17:00:00Z");
  equal(event?.end_at, "2026-10-10T17:00:00Z");
});

Deno.test("acara seharian menangani perubahan DST", () => {
  const event = normalizeEvent({
    id: "dst",
    start: { date: "2026-03-08" },
    end: { date: "2026-03-09" },
  }, "primary", "America/New_York");

  equal(event?.start_at, "2026-03-08T05:00:00Z");
  equal(event?.end_at, "2026-03-09T04:00:00Z");
});

Deno.test("acara dibatalkan atau ditolak pengguna tidak diimpor", () => {
  equal(normalizeEvent({ status: "cancelled" }, "primary", "UTC"), null);
  equal(normalizeEvent({
    attendees: [{ self: true, responseStatus: "declined" }],
  }, "primary", "UTC"), null);
});

Deno.test("acara free tidak memblokir waktu belajar", () => {
  const event = normalizeEvent({
    id: "free",
    transparency: "transparent",
    start: { dateTime: "2026-10-10T01:00:00Z" },
    end: { dateTime: "2026-10-10T02:00:00Z" },
  }, "primary", "UTC");

  equal(event?.busy, false);
});

Deno.test("durasi acara tidak valid ditolak", () => {
  let rejected = false;
  try {
    normalizeEvent({
      id: "invalid",
      start: { dateTime: "2026-10-10T02:00:00Z" },
      end: { dateTime: "2026-10-10T01:00:00Z" },
    }, "primary", "UTC");
  } catch {
    rejected = true;
  }
  equal(rejected, true);
});

Deno.test("enkripsi: roundtrip, pemilik, kunci, dan manipulasi", async () => {
  const name = "GOOGLE_CALENDAR_ENCRYPTION_KEY";
  const previous = Deno.env.get(name);
  Deno.env.set(name, "11".repeat(32));

  try {
    const encrypted = await encryptToken("dummy-refresh-token", "owner-a");
    const second = await encryptToken("dummy-refresh-token", "owner-a");

    equal(await decryptToken(encrypted, "owner-a"), "dummy-refresh-token");
    equal(encrypted === second, false);

    await rejects(() => decryptToken(encrypted, "owner-b"));

    const parts = encrypted.split(".");
    parts[2] = (parts[2][0] === "0" ? "1" : "0") + parts[2].slice(1);
    await rejects(() => decryptToken(parts.join("."), "owner-a"));

    Deno.env.set(name, "22".repeat(32));
    await rejects(() => decryptToken(encrypted, "owner-a"));
  } finally {
    if (previous === undefined) Deno.env.delete(name);
    else Deno.env.set(name, previous);
  }
});
