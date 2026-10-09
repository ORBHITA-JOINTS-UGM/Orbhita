import type { Proposal, ProposalStep } from "./schema.ts";

export const QUESTION_DEADLINE = "Kapan deadline resmi tugas ini?";
export const QUESTION_TITLE = "Apa judul atau nama tugas ini?";
export const WARNING_TARGET_AFTER_DEADLINE = "Target pribadi berada setelah deadline resmi.";

const MAX_ESTIMATE = 600;

function hasCycle(steps: ProposalStep[]): boolean {
  const deps = new Map(steps.map((s) => [s.client_step_id, s.depends_on]));
  const state = new Map<string, 0 | 1 | 2>(); // 0 = new, 1 = visiting, 2 = done
  const visit = (id: string): boolean => {
    const st = state.get(id) ?? 0;
    if (st === 1) return true;
    if (st === 2) return false;
    state.set(id, 1);
    for (const d of deps.get(id) ?? []) {
      if (deps.has(d) && visit(d)) return true;
    }
    state.set(id, 2);
    return false;
  };
  return steps.some((s) => visit(s.client_step_id));
}

/**
 * Checks what the JSON schema cannot express. `errors` are hard violations that
 * warrant a repair round-trip; soft issues are corrected in the returned proposal.
 */
export function validateProposal(p: Proposal): { proposal: Proposal; errors: string[] } {
  const errors: string[] = [];
  const proposal: Proposal = structuredClone(p);

  const seen = new Set<string>();
  for (const s of proposal.steps) {
    if (seen.has(s.client_step_id)) errors.push(`duplicate_step_id:${s.client_step_id}`);
    seen.add(s.client_step_id);
    if (!Number.isInteger(s.estimate_minutes) || s.estimate_minutes < 1 || s.estimate_minutes > MAX_ESTIMATE) {
      errors.push(`invalid_estimate:${s.client_step_id}`);
    }
  }
  for (const s of proposal.steps) {
    for (const d of s.depends_on) {
      if (!seen.has(d)) errors.push(`unknown_dependency:${d}`);
    }
  }
  if (hasCycle(proposal.steps)) errors.push("dependency_cycle");

  if (proposal.activity && Date.parse(proposal.activity.end_at) <= Date.parse(proposal.activity.start_at)) {
    errors.push("activity_end_before_start");
  }

  // A deadline must be quoted from the source; otherwise it is a guess.
  if (proposal.official_deadline.at !== null && !proposal.official_deadline.original_text?.trim()) {
    proposal.official_deadline = { at: null, original_text: null, needs_confirmation: true };
    if (!proposal.questions.includes(QUESTION_DEADLINE)) proposal.questions.push(QUESTION_DEADLINE);
  }

  const deadline = proposal.official_deadline.at;
  const target = proposal.personal_target.at;
  if (deadline && target && Date.parse(target) > Date.parse(deadline)) {
    if (!proposal.warnings.includes(WARNING_TARGET_AFTER_DEADLINE)) {
      proposal.warnings.push(WARNING_TARGET_AFTER_DEADLINE);
    }
  }

  if (proposal.intent === "task" && !proposal.title?.trim()) {
    proposal.intent = "clarification";
    if (!proposal.questions.includes(QUESTION_TITLE)) proposal.questions.push(QUESTION_TITLE);
  }

  return { proposal, errors };
}
