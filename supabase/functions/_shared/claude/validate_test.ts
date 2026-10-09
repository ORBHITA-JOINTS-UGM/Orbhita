import { assert, assertEquals } from "jsr:@std/assert@1";
import { PROPOSAL_JSON_SCHEMA, type Proposal } from "./schema.ts";
import { validateProposal } from "./validate.ts";

function base(over: Partial<Proposal> = {}): Proposal {
  return {
    schema_version: "1",
    intent: "task",
    title: "Laporan praktikum",
    course: "Kimia Dasar",
    requirements: [{ text: "Minimal 5 halaman", source_locator: "pesan", source_excerpt: "minimal 5 halaman" }],
    official_deadline: { at: "2026-10-09T14:00:00Z", original_text: "Jumat jam 21.00", needs_confirmation: false },
    personal_target: { at: null, original_text: null, needs_confirmation: false },
    steps: [
      { client_step_id: "s1", title: "Baca modul", estimate_minutes: 30, estimate_basis: "modul 10 halaman", depends_on: [] },
      { client_step_id: "s2", title: "Tulis draf", estimate_minutes: 90, estimate_basis: "5 halaman", depends_on: ["s1"] },
    ],
    activity: null,
    requested_assistance: ["steps", "estimate"],
    assumptions: [],
    questions: [],
    warnings: [],
    first_action: "Buka modul praktikum",
    explanation: "Tugas laporan praktikum dengan dua langkah.",
    ...over,
  };
}

Deno.test("proposal valid lolos tanpa error dan tanpa perubahan", () => {
  const p = base();
  const r = validateProposal(structuredClone(p));
  assertEquals(r.errors, []);
  assertEquals(r.proposal, p);
});

Deno.test("siklus dependensi menjadi error", () => {
  const p = base();
  p.steps[0].depends_on = ["s2"];
  assert(validateProposal(p).errors.includes("dependency_cycle"));
});

Deno.test("depends_on tidak dikenal menjadi error", () => {
  const p = base();
  p.steps[1].depends_on = ["s9"];
  assert(validateProposal(p).errors.includes("unknown_dependency:s9"));
});

Deno.test("client_step_id ganda menjadi error", () => {
  const p = base();
  p.steps[1].client_step_id = "s1";
  p.steps[1].depends_on = [];
  assert(validateProposal(p).errors.includes("duplicate_step_id:s1"));
});

Deno.test("estimate_minutes di luar 1-600 menjadi error", () => {
  const p = base();
  p.steps[0].estimate_minutes = 0;
  p.steps[1].estimate_minutes = 601;
  const errors = validateProposal(p).errors;
  assert(errors.includes("invalid_estimate:s1"));
  assert(errors.includes("invalid_estimate:s2"));
});

Deno.test("estimate_minutes bukan bilangan bulat menjadi error", () => {
  const p = base();
  p.steps[0].estimate_minutes = 12.5;
  assert(validateProposal(p).errors.includes("invalid_estimate:s1"));
});

Deno.test("activity end_at sebelum start_at menjadi error", () => {
  const p = base({
    intent: "activity",
    steps: [],
    activity: { title: "Rapat", start_at: "2026-10-09T10:00:00Z", end_at: "2026-10-09T09:00:00Z", locked: true },
  });
  assert(validateProposal(p).errors.includes("activity_end_before_start"));
});

Deno.test("deadline tanpa original_text diubah menjadi null dan ditanyakan", () => {
  const p = base({ official_deadline: { at: "2026-10-09T14:00:00Z", original_text: null, needs_confirmation: false } });
  const r = validateProposal(p);
  assertEquals(r.errors, []);
  assertEquals(r.proposal.official_deadline.at, null);
  assertEquals(r.proposal.official_deadline.needs_confirmation, true);
  assertEquals(r.proposal.questions, ["Kapan deadline resmi tugas ini?"]);
});

Deno.test("target setelah deadline menambah warning", () => {
  const p = base({ personal_target: { at: "2026-10-10T00:00:00Z", original_text: "Sabtu", needs_confirmation: false } });
  const r = validateProposal(p);
  assertEquals(r.errors, []);
  assertEquals(r.proposal.warnings, ["Target pribadi berada setelah deadline resmi."]);
});

Deno.test("intent task tanpa title menjadi clarification", () => {
  const r = validateProposal(base({ title: null }));
  assertEquals(r.proposal.intent, "clarification");
  assertEquals(r.proposal.questions, ["Apa judul atau nama tugas ini?"]);
});

Deno.test("PROPOSAL_JSON_SCHEMA mewajibkan semua field top-level", () => {
  const keys = Object.keys(base()).sort();
  assertEquals([...(PROPOSAL_JSON_SCHEMA.required as string[])].sort(), keys);
  assertEquals(PROPOSAL_JSON_SCHEMA.additionalProperties, false);
});

Deno.test("PROPOSAL_JSON_SCHEMA tidak memakai constraint yang tidak didukung", () => {
  const text = JSON.stringify(PROPOSAL_JSON_SCHEMA);
  for (const banned of ["minimum", "maximum", "minLength", "maxLength", "multipleOf"]) {
    assert(!text.includes(`"${banned}"`), banned);
  }
});
