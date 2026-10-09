import { assert, assertStringIncludes } from "jsr:@std/assert@1";
import { planSchedule } from "../_shared/scheduler/mod.ts";
import { toSchedulerInput } from "./load.ts";
import { explainPlan } from "./explain.ts";
import { iso, NOW, rows, TZ } from "./fixtures_test_util.ts";

const titles = { A: "Laporan", B: "Presentasi" };

Deno.test("menyebut tugas yang kurang waktu beserta menitnya", () => {
  const r = rows();
  r.steps[0].remaining_minutes = 270; // 240 available before Friday 21:00
  const text = explainPlan(planSchedule(toSchedulerInput(r, NOW)), titles, TZ);
  assertStringIncludes(text, "Laporan");
  assertStringIncludes(text, "kurang 30 menit");
});

Deno.test("tanpa risiko menyebut semua teralokasi", () => {
  const text = explainPlan(planSchedule(toSchedulerInput(rows(), NOW)), titles, TZ);
  assertStringIncludes(text, "Semua langkah sudah teralokasi sebelum deadline");
  assertStringIncludes(text, "Sesi pertama: Laporan, Kam 8 Okt 19.00");
});

Deno.test("tugas tanpa deadline diminta dilengkapi", () => {
  const r = rows();
  r.tasks[0].official_deadline = null;
  const text = explainPlan(planSchedule(toSchedulerInput(r, NOW)), titles, TZ);
  assertStringIncludes(text, "deadline belum diisi");
  assert(!text.includes("Semua langkah sudah teralokasi"));
});

Deno.test("target pribadi terlewat disebut terpisah dari deadline", () => {
  const r = rows();
  r.tasks[0].personal_target = iso("2026-10-08T20:00");
  r.steps[0].remaining_minutes = 180;
  const text = explainPlan(planSchedule(toSchedulerInput(r, NOW)), titles, TZ);
  assertStringIncludes(text, "target pribadi terlewat");
});
