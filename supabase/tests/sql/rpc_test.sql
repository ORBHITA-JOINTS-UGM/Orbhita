-- Transactional RPCs.

-- confirm_proposal: menyimpan tugas, langkah, dan dependensi; idempoten
do $$
declare
  a uuid := tests.create_user('cp@test.local');
  src uuid;
  prop uuid;
  op uuid := gen_random_uuid();
  draft jsonb := '{
    "intent": "task", "title": "Laporan", "course": "Kimia",
    "requirements": [{"text": "5 halaman", "source_locator": "pesan", "source_excerpt": "5 halaman"}],
    "official_deadline": {"at": "2026-10-09T14:00:00Z", "original_text": "Jumat", "needs_confirmation": false},
    "personal_target": {"at": "2026-10-10T00:00:00Z", "original_text": "Sabtu", "needs_confirmation": false},
    "steps": [
      {"client_step_id": "s1", "title": "Baca", "estimate_minutes": 30, "estimate_basis": "", "depends_on": []},
      {"client_step_id": "s2", "title": "Tulis", "estimate_minutes": 90, "estimate_basis": "", "depends_on": ["s1"]},
      {"client_step_id": "s3", "title": "Cek", "estimate_minutes": 15, "estimate_basis": "", "depends_on": []}
    ]}';
  r jsonb;
  r2 jsonb;
  t uuid;
begin
  insert into public.sources (owner_id, input_type) values (a, 'text') returning id into src;
  insert into public.proposals (owner_id, source_id, intent, payload, payload_hash, expires_at)
  values (a, src, 'task', draft, 'hash-1', now() + interval '1 day') returning id into prop;

  perform tests.as_user(a);
  r := public.confirm_proposal(prop, 'hash-1', draft, op);
  t := (r ->> 'task_id')::uuid;
  perform tests.assert(t is not null, 'task_id dikembalikan');
  perform tests.assert((select title from public.tasks where id = t) = 'Laporan', 'judul tersimpan');
  perform tests.assert((select source_id from public.tasks where id = t) = src, 'source tersimpan');
  perform tests.assert((select count(*) from public.steps where task_id = t) = 3, '3 langkah');
  perform tests.assert((select remaining_minutes from public.steps where task_id = t and title = 'Tulis') = 90, 'remaining = estimasi');
  perform tests.assert((
    select count(*) from public.step_dependencies d
    join public.steps s on s.id = d.step_id join public.steps p on p.id = d.depends_on_id
    where d.task_id = t and s.title = 'Tulis' and p.title = 'Baca') = 1, 'dependensi dipetakan');
  perform tests.assert((select status from public.proposals where id = prop) = 'confirmed', 'proposal confirmed');
  perform tests.assert(jsonb_array_length(r -> 'warnings') = 1, 'warning target setelah deadline');

  -- replay dengan operation_id sama
  r2 := public.confirm_proposal(prop, 'hash-1', draft, op);
  perform tests.assert(r2 = r, 'replay mengembalikan hasil sama');
  perform tests.assert((select count(*) from public.tasks) = 1, 'tidak ada tugas ganda');
  -- operation_id sama, isi berbeda
  perform tests.expect_error(format('select public.confirm_proposal(%L, %L, %L, %L)', prop, 'hash-1', '{}', op), 'OPERATION_REUSED');
  -- proposal sudah confirmed
  perform tests.expect_error(format('select public.confirm_proposal(%L, %L, %L, gen_random_uuid())', prop, 'hash-1', draft), 'PROPOSAL_STALE');
  perform tests.as_admin();
end $$;

-- confirm_proposal: hash salah, kedaluwarsa, milik orang lain, tanpa deadline
do $$
declare
  a uuid := tests.create_user('cp2-a@test.local');
  b uuid := tests.create_user('cp2-b@test.local');
  src uuid;
  p_hash uuid;
  p_exp uuid;
  p_other uuid;
  p_nodl uuid;
  draft jsonb := '{"intent": "task", "title": "Tanpa deadline", "requirements": [],
    "official_deadline": {"at": null, "original_text": null, "needs_confirmation": true},
    "personal_target": {"at": null, "original_text": null, "needs_confirmation": false},
    "steps": [{"client_step_id": "s1", "title": "A", "estimate_minutes": 10, "estimate_basis": "", "depends_on": []}]}';
  r jsonb;
begin
  insert into public.sources (owner_id, input_type) values (a, 'text') returning id into src;
  insert into public.proposals (owner_id, source_id, intent, payload, payload_hash, expires_at)
  values (a, src, 'task', draft, 'h', now() + interval '1 day') returning id into p_hash;
  insert into public.proposals (owner_id, source_id, intent, payload, payload_hash, expires_at)
  values (a, src, 'task', draft, 'h', now() - interval '1 minute') returning id into p_exp;
  insert into public.proposals (owner_id, source_id, intent, payload, payload_hash, expires_at)
  values (a, src, 'task', draft, 'h', now() + interval '1 day') returning id into p_nodl;
  insert into public.sources (owner_id, input_type) values (b, 'text') returning id into src;
  insert into public.proposals (owner_id, source_id, intent, payload, payload_hash, expires_at)
  values (b, src, 'task', draft, 'h', now() + interval '1 day') returning id into p_other;

  perform tests.as_user(a);
  perform tests.expect_error(format('select public.confirm_proposal(%L, %L, %L, gen_random_uuid())', p_hash, 'salah', draft), 'PROPOSAL_STALE');
  perform tests.expect_error(format('select public.confirm_proposal(%L, %L, %L, gen_random_uuid())', p_exp, 'h', draft), 'PROPOSAL_STALE');
  perform tests.expect_error(format('select public.confirm_proposal(%L, %L, %L, gen_random_uuid())', p_other, 'h', draft), 'NOT_FOUND');
  r := public.confirm_proposal(p_nodl, 'h', draft, gen_random_uuid());
  perform tests.assert((select official_deadline from public.tasks where id = (r ->> 'task_id')::uuid) is null, 'deadline null tersimpan');
  perform tests.as_admin();
end $$;

-- confirm_proposal: aktivitas
do $$
declare
  a uuid := tests.create_user('cp3@test.local');
  src uuid;
  prop uuid;
  draft jsonb := '{"intent": "activity", "steps": [],
    "activity": {"title": "Rapat BEM", "start_at": "2026-10-09T10:00:00Z", "end_at": "2026-10-09T12:00:00Z", "locked": true}}';
  r jsonb;
begin
  insert into public.sources (owner_id, input_type) values (a, 'text') returning id into src;
  insert into public.proposals (owner_id, source_id, intent, payload, payload_hash, expires_at)
  values (a, src, 'activity', draft, 'h', now() + interval '1 day') returning id into prop;
  perform tests.as_user(a);
  r := public.confirm_proposal(prop, 'h', draft, gen_random_uuid());
  perform tests.assert((select title from public.activities where id = (r ->> 'activity_id')::uuid) = 'Rapat BEM', 'aktivitas tersimpan');
  perform tests.as_admin();
end $$;

-- save_plan_proposal + confirm_plan + reject_plan
do $$
declare
  a uuid := tests.create_user('plan@test.local');
  t uuid;
  s uuid;
  old_plan uuid;
  kept uuid;
  dropped uuid;
  p1 uuid;
  p2 uuid;
  dv bigint;
  r jsonb;
begin
  insert into public.tasks (owner_id, title) values (a, 'T') returning id into t;
  insert into public.steps (owner_id, task_id, title, estimate_minutes, remaining_minutes) values (a, t, 'S', 120, 120) returning id into s;
  insert into public.plans (owner_id, version, status, base_data_version) values (a, 1, 'active', 0) returning id into old_plan;
  insert into public.sessions (owner_id, plan_id, task_id, step_id, start_at, end_at, status, is_active)
  values (a, old_plan, t, s, '2026-10-08 10:00+00', '2026-10-08 10:30+00', 'completed', true) returning id into kept;
  insert into public.sessions (owner_id, plan_id, task_id, step_id, start_at, end_at, status, is_active)
  values (a, old_plan, t, s, '2026-10-08 12:00+00', '2026-10-08 12:30+00', 'planned', true) returning id into dropped;
  select data_version into dv from public.owner_state where owner_id = a;

  -- save_plan_proposal hanya untuk server
  perform tests.as_user(a);
  perform tests.expect_error(format('select public.save_plan_proposal(%L, %L, %L)', a, '{}', '[]'), '42501');
  perform tests.as_admin();

  p1 := public.save_plan_proposal(a,
    jsonb_build_object('version', 2, 'base_plan_version', 1, 'base_data_version', dv, 'trigger', 'manual',
                       'risk_summary', '{}'::jsonb, 'unscheduled', '[]'::jsonb),
    jsonb_build_array(jsonb_build_object('task_id', t, 'step_id', s,
                      'start_at', '2026-10-08T12:15:00Z', 'end_at', '2026-10-08T13:15:00Z')));
  perform tests.assert((select status from public.plans where id = p1) = 'proposed', 'usulan tersimpan');
  perform tests.assert((select count(*) from public.sessions where plan_id = p1 and not is_active) = 1, 'sesi usulan tidak aktif');

  -- usulan baru menggantikan usulan lama
  p2 := public.save_plan_proposal(a,
    jsonb_build_object('version', 3, 'base_plan_version', 1, 'base_data_version', dv, 'trigger', 'manual',
                       'risk_summary', '{}'::jsonb, 'unscheduled', '[]'::jsonb),
    jsonb_build_array(jsonb_build_object('task_id', t, 'step_id', s,
                      'start_at', '2026-10-08T12:15:00Z', 'end_at', '2026-10-08T13:15:00Z')));
  perform tests.assert((select status from public.plans where id = p1) = 'superseded', 'usulan lama superseded');

  perform tests.as_user(a);
  perform tests.expect_error(format('select public.confirm_plan(%L, gen_random_uuid())', p1), 'STALE_PLAN');
  r := public.confirm_plan(p2, gen_random_uuid());
  perform tests.assert((r ->> 'version')::int = 3, 'versi dikembalikan');
  perform tests.as_admin();

  perform tests.assert((select status from public.plans where id = p2) = 'active', 'rencana baru aktif');
  perform tests.assert((select status from public.plans where id = old_plan) = 'superseded', 'rencana lama superseded');
  perform tests.assert((select is_active from public.sessions where id = kept), 'sesi completed dipertahankan');
  perform tests.assert(not (select is_active from public.sessions where id = dropped), 'sesi planned lama dinonaktifkan');
  perform tests.assert((select count(*) from public.sessions where plan_id = p2 and is_active) = 1, 'sesi baru aktif');
end $$;

-- confirm_plan basi karena rencana aktif berubah atau data berubah; reject_plan
do $$
declare
  a uuid := tests.create_user('stale@test.local');
  t uuid;
  p uuid;
  dv bigint;
begin
  insert into public.tasks (owner_id, title) values (a, 'T') returning id into t;
  select data_version into dv from public.owner_state where owner_id = a;

  -- base_plan_version tidak cocok (belum ada rencana aktif = versi 0)
  p := public.save_plan_proposal(a, jsonb_build_object('version', 1, 'base_plan_version', 5, 'base_data_version', dv), '[]');
  perform tests.as_user(a);
  perform tests.expect_error(format('select public.confirm_plan(%L, gen_random_uuid())', p), 'STALE_PLAN');
  perform tests.as_admin();

  -- data berubah setelah usulan dibuat
  p := public.save_plan_proposal(a, jsonb_build_object('version', 2, 'base_plan_version', 0, 'base_data_version', dv), '[]');
  perform tests.as_user(a);
  update public.tasks set title = 'T2', revision = 1 where id = t;
  perform tests.expect_error(format('select public.confirm_plan(%L, gen_random_uuid())', p), 'STALE_PLAN');

  -- reject_plan
  perform public.reject_plan(p);
  perform tests.assert((select status from public.plans where id = p) = 'rejected', 'usulan ditolak');
  perform tests.as_admin();
end $$;

-- set_session_status
do $$
declare
  a uuid := tests.create_user('sess@test.local');
  t uuid;
  s uuid;
  pl uuid;
  ses uuid;
  r jsonb;
begin
  insert into public.tasks (owner_id, title) values (a, 'T') returning id into t;
  insert into public.steps (owner_id, task_id, title, estimate_minutes, remaining_minutes) values (a, t, 'S', 60, 60) returning id into s;
  insert into public.plans (owner_id, version, status, base_data_version) values (a, 1, 'active', 0) returning id into pl;
  insert into public.sessions (owner_id, plan_id, task_id, step_id, start_at, end_at, is_active)
  values (a, pl, t, s, now(), now() + interval '30 minutes', true) returning id into ses;

  perform tests.as_user(a);
  r := public.set_session_status(ses, 'in_progress', 1);
  perform tests.assert(r ->> 'status' = 'in_progress' and (r ->> 'revision')::int = 2, 'mulai');
  perform tests.expect_error(format('select public.set_session_status(%L, %L, 1)', ses, 'completed'), 'REVISION_CONFLICT');
  r := public.set_session_status(ses, 'completed', 2);
  perform tests.assert(r ->> 'status' = 'completed', 'selesai');
  perform tests.expect_error(format('select public.set_session_status(%L, %L, 3)', ses, 'planned'), 'INVALID_INPUT');
  perform tests.assert((select remaining_minutes from public.steps where id = s) = 60, 'progres langkah tidak berubah otomatis');
  perform tests.as_admin();
end $$;
