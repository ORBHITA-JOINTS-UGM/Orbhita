import { assertEquals } from "jsr:@std/assert@1";
import { buildFreeSlots, localDayKey } from "./slots.ts";

const utc = (s: string) => Date.parse(s);

// 2026-10-08 is a Thursday. Asia/Jakarta is UTC+7 with no DST.

Deno.test("jendela Kamis 19:00-21:00 Jakarta menjadi 12:00-14:00 UTC", () => {
  const slots = buildFreeSlots({
    now: utc("2026-10-08T00:00:00Z"),
    timezone: "Asia/Jakarta",
    horizonDays: 1,
    studyWindows: [{ dow: 4, start: "19:00", end: "21:00" }],
    busy: [],
  });
  assertEquals(slots, [
    { start: utc("2026-10-08T12:00:00Z"), end: utc("2026-10-08T14:00:00Z") },
  ]);
});

Deno.test("busy di tengah jendela memotong slot menjadi dua", () => {
  const slots = buildFreeSlots({
    now: utc("2026-10-08T00:00:00Z"),
    timezone: "Asia/Jakarta",
    horizonDays: 1,
    studyWindows: [{ dow: 4, start: "19:00", end: "21:00" }],
    busy: [{ start: utc("2026-10-08T12:30:00Z"), end: utc("2026-10-08T13:00:00Z") }],
  });
  assertEquals(slots, [
    { start: utc("2026-10-08T12:00:00Z"), end: utc("2026-10-08T12:30:00Z") },
    { start: utc("2026-10-08T13:00:00Z"), end: utc("2026-10-08T14:00:00Z") },
  ]);
});

Deno.test("slot yang sudah lewat dipotong di now", () => {
  const slots = buildFreeSlots({
    now: utc("2026-10-08T12:45:00Z"), // 19:45 Jakarta
    timezone: "Asia/Jakarta",
    horizonDays: 1,
    studyWindows: [{ dow: 4, start: "19:00", end: "21:00" }],
    busy: [],
  });
  assertEquals(slots, [
    { start: utc("2026-10-08T12:45:00Z"), end: utc("2026-10-08T14:00:00Z") },
  ]);
});

Deno.test("jendela melewati tengah malam berlanjut ke hari berikutnya", () => {
  const slots = buildFreeSlots({
    now: utc("2026-10-08T00:00:00Z"),
    timezone: "Asia/Jakarta",
    horizonDays: 2,
    studyWindows: [{ dow: 4, start: "22:00", end: "01:00" }],
    busy: [],
  });
  // Thursday 22:00 Jakarta -> Friday 01:00 Jakarta
  assertEquals(slots, [
    { start: utc("2026-10-08T15:00:00Z"), end: utc("2026-10-08T18:00:00Z") },
  ]);
});

Deno.test("zona ber-DST memakai offset yang benar di kedua sisi pergantian", () => {
  // Europe/Berlin leaves DST on Sunday 2026-10-25 (UTC+2 -> UTC+1).
  const slots = buildFreeSlots({
    now: utc("2026-10-24T00:00:00Z"),
    timezone: "Europe/Berlin",
    horizonDays: 2,
    studyWindows: [
      { dow: 6, start: "09:00", end: "10:00" },
      { dow: 7, start: "09:00", end: "10:00" },
    ],
    busy: [],
  });
  assertEquals(slots, [
    { start: utc("2026-10-24T07:00:00Z"), end: utc("2026-10-24T08:00:00Z") },
    { start: utc("2026-10-25T08:00:00Z"), end: utc("2026-10-25T09:00:00Z") },
  ]);
});

Deno.test("tanpa jendela belajar hasilnya kosong", () => {
  const slots = buildFreeSlots({
    now: utc("2026-10-08T00:00:00Z"),
    timezone: "Asia/Jakarta",
    horizonDays: 7,
    studyWindows: [],
    busy: [],
  });
  assertEquals(slots, []);
});

Deno.test("slot berhenti di batas horizon", () => {
  const slots = buildFreeSlots({
    now: utc("2026-10-08T00:00:00Z"), // 07:00 Jakarta Thursday
    timezone: "Asia/Jakarta",
    horizonDays: 1, // until Friday 07:00 Jakarta
    studyWindows: [
      { dow: 4, start: "19:00", end: "21:00" },
      { dow: 5, start: "19:00", end: "21:00" },
    ],
    busy: [],
  });
  assertEquals(slots.length, 1);
});

Deno.test("localDayKey memakai tanggal lokal", () => {
  assertEquals(localDayKey(utc("2026-10-08T18:00:00Z"), "Asia/Jakarta"), "2026-10-09");
  assertEquals(localDayKey(utc("2026-10-08T16:59:00Z"), "Asia/Jakarta"), "2026-10-08");
});
