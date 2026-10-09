-- Constraints and triggers.

-- user baru otomatis punya profiles, preferences, owner_state
do $$
declare
  a uuid := tests.create_user('new@test.local');
begin
  perform tests.assert((select count(*) from public.profiles where id = a) = 1, 'profile dibuat');
  perform tests.assert((select count(*) from public.preferences where owner_id = a) = 1, 'preferences dibuat');
  perform tests.assert((select count(*) from public.owner_state where owner_id = a) = 1, 'owner_state dibuat');
  perform tests.assert((select session_minutes from public.preferences where owner_id = a) = 25, 'default sesi 25');
end $$;

-- revision lama ditolak, revision benar dinaikkan
do $$
declare
  a uuid := tests.create_user('rev@test.local');
  t uuid;
  r int;
begin
  perform tests.as_user(a);
  insert into public.tasks (title) values ('T') returning id into t;
  perform tests.expect_error(format('update public.tasks set title = %L, revision = 5 where id = %L', 'X', t), 'REVISION_CONFLICT');
  update public.tasks set title = 'X', revision = 1 where id = t;
  select revision into r from public.tasks where id = t;
  perform tests.assert(r = 2, 'revision naik ke 2');
  perform tests.as_admin();
end $$;

-- status done memaksa remaining 0 dan status tugas mengikuti langkah
do $$
declare
  a uuid := tests.create_user('steps@test.local');
  t uuid;
  s1 uuid;
  s2 uuid;
begin
  perform tests.as_user(a);
  insert into public.tasks (title) values ('T') returning id into t;
  insert into public.steps (task_id, title, estimate_minutes, remaining_minutes) values (t, 'S1', 30, 30) returning id into s1;
  insert into public.steps (task_id, title, estimate_minutes, remaining_minutes, order_index) values (t, 'S2', 30, 30, 1) returning id into s2;
  update public.steps set status = 'done', revision = 1 where id = s1;
  perform tests.assert((select remaining_minutes from public.steps where id = s1) = 0, 'remaining 0 saat done');
  perform tests.assert((select work_status from public.tasks where id = t) = 'in_progress', 'tugas in_progress');
  update public.steps set status = 'done', revision = 1 where id = s2;
  perform tests.assert((select work_status from public.tasks where id = t) = 'done', 'tugas done');
  perform tests.as_admin();
end $$;

-- estimasi harus positif
do $$
declare
  a uuid := tests.create_user('est@test.local');
  t uuid;
begin
  perform tests.as_user(a);
  insert into public.tasks (title) values ('T') returning id into t;
  perform tests.expect_error(
    format('insert into public.steps (task_id, title, estimate_minutes, remaining_minutes) values (%L, %L, 0, 0)', t, 'S'),
    '23514');
  perform tests.as_admin();
end $$;

-- dependensi: siklus ditolak, lintas tugas ditolak
do $$
declare
  a uuid := tests.create_user('dep@test.local');
  t uuid;
  t2 uuid;
  s1 uuid;
  s2 uuid;
  s3 uuid;
begin
  perform tests.as_user(a);
  insert into public.tasks (title) values ('T') returning id into t;
  insert into public.tasks (title) values ('T2') returning id into t2;
  insert into public.steps (task_id, title, estimate_minutes, remaining_minutes) values (t, 'S1', 30, 30) returning id into s1;
  insert into public.steps (task_id, title, estimate_minutes, remaining_minutes) values (t, 'S2', 30, 30) returning id into s2;
  insert into public.steps (task_id, title, estimate_minutes, remaining_minutes) values (t2, 'S3', 30, 30) returning id into s3;
  insert into public.step_dependencies (task_id, step_id, depends_on_id) values (t, s2, s1);
  perform tests.expect_error(
    format('insert into public.step_dependencies (task_id, step_id, depends_on_id) values (%L, %L, %L)', t, s1, s2),
    'DEPENDENCY_CYCLE');
  perform tests.expect_error(
    format('insert into public.step_dependencies (task_id, step_id, depends_on_id) values (%L, %L, %L)', t2, s3, s1),
    '23503');
  perform tests.as_admin();
end $$;

-- perubahan data menaikkan owner_state.data_version
do $$
declare
  a uuid := tests.create_user('dv@test.local');
  before_v bigint;
  after_v bigint;
begin
  select data_version into before_v from public.owner_state where owner_id = a;
  perform tests.as_user(a);
  insert into public.activities (title, start_at, end_at) values ('Rapat', now(), now() + interval '1 hour');
  update public.preferences set max_daily_minutes = 90, revision = 1 where owner_id = a;
  perform tests.as_admin();
  select data_version into after_v from public.owner_state where owner_id = a;
  perform tests.assert(after_v >= before_v + 2, 'data_version naik');
end $$;

-- sesi aktif tidak boleh tumpang tindih untuk owner yang sama
do $$
declare
  a uuid := tests.create_user('ov-a@test.local');
  b uuid := tests.create_user('ov-b@test.local');
  ta uuid;
  sa uuid;
  tb uuid;
  sb uuid;
  pa uuid;
  pb uuid;
begin
  insert into public.tasks (owner_id, title) values (a, 'T') returning id into ta;
  insert into public.steps (owner_id, task_id, title, estimate_minutes, remaining_minutes) values (a, ta, 'S', 60, 60) returning id into sa;
  insert into public.tasks (owner_id, title) values (b, 'T') returning id into tb;
  insert into public.steps (owner_id, task_id, title, estimate_minutes, remaining_minutes) values (b, tb, 'S', 60, 60) returning id into sb;
  insert into public.plans (owner_id, version, status, base_data_version) values (a, 1, 'active', 0) returning id into pa;
  insert into public.plans (owner_id, version, status, base_data_version) values (b, 1, 'active', 0) returning id into pb;

  insert into public.sessions (owner_id, plan_id, task_id, step_id, start_at, end_at, is_active)
  values (a, pa, ta, sa, '2026-10-08 12:00+00', '2026-10-08 13:00+00', true);
  perform tests.expect_error(format(
    'insert into public.sessions (owner_id, plan_id, task_id, step_id, start_at, end_at, is_active) values (%L, %L, %L, %L, %L, %L, true)',
    a, pa, ta, sa, '2026-10-08 12:30+00', '2026-10-08 13:30+00'), '23P01');
  -- owner lain boleh di waktu yang sama
  insert into public.sessions (owner_id, plan_id, task_id, step_id, start_at, end_at, is_active)
  values (b, pb, tb, sb, '2026-10-08 12:30+00', '2026-10-08 13:30+00', true);
  -- sesi tidak aktif boleh tumpang tindih
  insert into public.sessions (owner_id, plan_id, task_id, step_id, start_at, end_at, is_active)
  values (a, pa, ta, sa, '2026-10-08 12:30+00', '2026-10-08 13:30+00', false);
end $$;

-- aktivitas: akhir harus setelah awal; acara Google tidak bisa diubah dari aplikasi
do $$
declare
  a uuid := tests.create_user('act@test.local');
  g uuid;
begin
  insert into public.activities (owner_id, source, external_key, title, start_at, end_at)
  values (a, 'google', 'evt-1', 'Kuliah', now(), now() + interval '1 hour') returning id into g;
  perform tests.as_user(a);
  perform tests.expect_error(
    format('insert into public.activities (title, start_at, end_at) values (%L, now(), now())', 'X'), '23514');
  perform tests.expect_error(format('update public.activities set title = %L, revision = 1 where id = %L', 'X', g), 'FORBIDDEN');
  perform tests.expect_error(
    format('insert into public.activities (source, title, start_at, end_at) values (%L, %L, now(), now() + interval %L)', 'google', 'X', '1 hour'),
    'FORBIDDEN');
  perform tests.as_admin();
end $$;
