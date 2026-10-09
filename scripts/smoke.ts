// End-to-end check against the deployed project: sign in as a test user, set study windows,
// send one text input to `extract`, confirm the draft, then ask `plan-propose` for a plan.
// Needs in .env: SUPABASE_URL, SUPABASE_ANON_KEY, TEST_EMAIL, TEST_PASSWORD.
// Run: deno run -A --env-file=.env scripts/smoke.ts
import { createClient } from "npm:@supabase/supabase-js@2.117.3";

const env = (k: string) => {
  const v = Deno.env.get(k);
  if (!v) throw new Error(`${k} belum diisi di .env`);
  return v;
};

const url = env("SUPABASE_URL");
const db = createClient(url, env("SUPABASE_ANON_KEY"));

const { data: auth, error: authError } = await db.auth.signInWithPassword({
  email: env("TEST_EMAIL"),
  password: env("TEST_PASSWORD"),
});
if (authError || !auth.session) throw new Error(`login gagal: ${authError?.message}`);
const token = auth.session.access_token;
const userId = auth.user.id;
console.log("login ok");

async function call(fn: string, body: unknown) {
  const started = performance.now();
  const res = await fetch(`${url}/functions/v1/${fn}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  console.log(`${fn}: HTTP ${res.status} dalam ${Math.round(performance.now() - started)} ms`);
  if (!res.ok) throw new Error(JSON.stringify(json.error));
  return json.data;
}

// Weekday evenings 19:00-21:00 plus weekend afternoons.
const windows = [1, 2, 3, 4, 5].map((dow) => ({ dow, start: "19:00", end: "21:00" }))
  .concat([6, 7].map((dow) => ({ dow, start: "13:00", end: "17:00" })));
const { data: pref } = await db.from("preferences").select("revision").eq("owner_id", userId).single();
const { error: prefError } = await db.from("preferences")
  .update({ study_windows: windows, revision: pref!.revision }).eq("owner_id", userId);
if (prefError) throw new Error(`gagal menyimpan jam belajar: ${prefError.message}`);

const sample = await Deno.readTextFile(new URL("./sample-task.txt", import.meta.url));
const extracted = await call("extract", {
  operation_id: crypto.randomUUID(),
  input_type: "text",
  text: sample,
  requested_assistance: ["requirements", "steps", "estimate", "schedule"],
});
const p = extracted.proposal;
console.log("judul:", p.title);
console.log("deadline:", p.official_deadline.at, `(${p.official_deadline.original_text})`);
console.log("langkah:", p.steps.map((s: any) => `${s.title} ${s.estimate_minutes}m`).join(" | "));
console.log("pertanyaan:", p.questions);

const { data: confirmed, error: confirmError } = await db.rpc("confirm_proposal", {
  p_proposal_id: extracted.proposal_id,
  p_payload_hash: extracted.payload_hash,
  p_draft: p,
  p_operation_id: crypto.randomUUID(),
});
if (confirmError) throw new Error(`konfirmasi gagal: ${confirmError.message}`);
console.log("tugas tersimpan:", confirmed.task_id);

const plan = await call("plan-propose", { trigger: "new_task" });
console.log(`usulan rencana v${plan.version}: ${plan.sessions.length} sesi`);
console.log(plan.explanation);
