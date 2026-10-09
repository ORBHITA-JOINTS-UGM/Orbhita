export type Intent = "task" | "activity" | "clarification";
export type Assistance = "requirements" | "steps" | "estimate" | "schedule" | "reminder";
export const ASSISTANCE_VALUES: Assistance[] = ["requirements", "steps", "estimate", "schedule", "reminder"];

export interface Requirement {
  text: string;
  source_locator: string;
  source_excerpt: string;
}

export interface TimePoint {
  at: string | null;
  original_text: string | null;
  needs_confirmation: boolean;
}

export interface ProposalStep {
  client_step_id: string;
  title: string;
  estimate_minutes: number;
  estimate_basis: string;
  depends_on: string[];
}

export interface ProposalActivity {
  title: string;
  start_at: string;
  end_at: string;
  locked: boolean;
}

export interface Proposal {
  schema_version: "1";
  intent: Intent;
  title: string | null;
  course: string | null;
  requirements: Requirement[];
  official_deadline: TimePoint;
  personal_target: TimePoint;
  steps: ProposalStep[];
  activity: ProposalActivity | null;
  requested_assistance: Assistance[];
  assumptions: string[];
  questions: string[];
  warnings: string[];
  first_action: string | null;
  explanation: string;
}

const str = { type: "string" };
const nullable = (schema: Record<string, unknown>) => ({ anyOf: [schema, { type: "null" }] });
const strArray = { type: "array", items: str };

function obj(properties: Record<string, unknown>) {
  return { type: "object", properties, required: Object.keys(properties), additionalProperties: false };
}

const timePoint = obj({
  at: nullable({ type: "string", format: "date-time" }),
  original_text: nullable(str),
  needs_confirmation: { type: "boolean" },
});

/**
 * JSON schema sent as output_config.format. Structured outputs reject numeric and
 * length constraints, so ranges are enforced in validateProposal instead.
 */
export const PROPOSAL_JSON_SCHEMA: Record<string, unknown> = obj({
  schema_version: { type: "string", const: "1" },
  intent: { type: "string", enum: ["task", "activity", "clarification"] },
  title: nullable(str),
  course: nullable(str),
  requirements: {
    type: "array",
    items: obj({ text: str, source_locator: str, source_excerpt: str }),
  },
  official_deadline: timePoint,
  personal_target: timePoint,
  steps: {
    type: "array",
    items: obj({
      client_step_id: str,
      title: str,
      estimate_minutes: { type: "integer" },
      estimate_basis: str,
      depends_on: strArray,
    }),
  },
  activity: nullable(obj({
    title: str,
    start_at: { type: "string", format: "date-time" },
    end_at: { type: "string", format: "date-time" },
    locked: { type: "boolean" },
  })),
  requested_assistance: { type: "array", items: { type: "string", enum: ASSISTANCE_VALUES } },
  assumptions: strArray,
  questions: strArray,
  warnings: strArray,
  first_action: nullable(str),
  explanation: str,
});
