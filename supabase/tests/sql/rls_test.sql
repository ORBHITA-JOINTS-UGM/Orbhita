-- Row level security: user B must never see or change user A's data.
do $$
declare
  a uuid := tests.create_user('rls-a@test.local');
  b uuid := tests.create_user('rls-b@test.local');
  t uuid;
  s uuid;
  act uuid;
  src uuid;
  prop uuid;
  pl uuid;
  n int;
begin
  perform tests.as_user(a);
  insert into public.tasks (title) values ('Rahasia A') returning id into t;
  insert into public.steps (task_id, title, estimate_minutes, remaining_minutes) values (t, 'S', 30, 30) returning id into s;
  insert into public.activities (title, start_at, end_at) values ('Rapat A', now(), now() + interval '1 hour') returning id into act;
  perform tests.as_admin();

  insert into public.sources (owner_id, input_type, text_content) values (a, 'text', 'x') returning id into src;
  insert into public.proposals (owner_id, source_id, intent, payload, payload_hash, expires_at)
  values (a, src, 'task', '{}', 'h', now() + interval '1 day') returning id into prop;
  insert into public.plans (owner_id, version, status, base_data_version) values (a, 1, 'active', 0) returning id into pl;
  insert into public.sessions (owner_id, plan_id, task_id, step_id, start_at, end_at, is_active)
  values (a, pl, t, s, now(), now() + interval '30 minutes', true);
  insert into storage.objects (bucket_id, name, owner_id) values ('inputs', a::text || '/x.jpg', a::text);

  -- B tidak melihat apa pun milik A
  perform tests.as_user(b);
  perform tests.assert((select count(*) from public.tasks where id = t) = 0, 'tasks tersembunyi');
  perform tests.assert((select count(*) from public.steps where id = s) = 0, 'steps tersembunyi');
  perform tests.assert((select count(*) from public.activities where id = act) = 0, 'activities tersembunyi');
  perform tests.assert((select count(*) from public.sources where id = src) = 0, 'sources tersembunyi');
  perform tests.assert((select count(*) from public.proposals where id = prop) = 0, 'proposals tersembunyi');
  perform tests.assert((select count(*) from public.plans where id = pl) = 0, 'plans tersembunyi');
  perform tests.assert((select count(*) from public.sessions where plan_id = pl) = 0, 'sessions tersembunyi');
  perform tests.assert((select count(*) from public.profiles where id = a) = 0, 'profile tersembunyi');
  perform tests.assert((select count(*) from public.preferences where owner_id = a) = 0, 'preferences tersembunyi');
  perform tests.assert((select count(*) from public.owner_state where owner_id = a) = 0, 'owner_state tersembunyi');
  perform tests.assert(
    (select count(*) from storage.objects where bucket_id = 'inputs' and name like a::text || '/%') = 0,
    'file storage tersembunyi');

  -- B tidak bisa mengubah milik A
  update public.tasks set title = 'diretas', revision = 1 where id = t;
  get diagnostics n = row_count;
  perform tests.assert(n = 0, 'update tasks milik A tidak berefek');
  update public.steps set remaining_minutes = 0, revision = 1 where id = s;
  get diagnostics n = row_count;
  perform tests.assert(n = 0, 'update steps milik A tidak berefek');

  -- B tidak bisa menempelkan langkah ke tugas A
  perform tests.expect_error(
    format('insert into public.steps (task_id, title, estimate_minutes, remaining_minutes) values (%L, %L, 30, 30)', t, 'X'),
    '23503');
  -- B tidak bisa menulis atas nama A
  perform tests.expect_error(
    format('insert into public.tasks (owner_id, title) values (%L, %L)', a, 'X'), '42501');
  -- B tidak bisa mengunggah ke folder A
  perform tests.expect_error(
    format('insert into storage.objects (bucket_id, name, owner_id) values (%L, %L, %L)', 'inputs', a::text || '/y.jpg', b::text),
    '42501');
  perform tests.as_admin();

  -- tabel yang hanya ditulis server tidak bisa ditulis aplikasi
  perform tests.as_user(a);
  perform tests.expect_error(format('insert into public.sources (input_type) values (%L)', 'text'), '42501');
  perform tests.expect_error(
    format('insert into public.proposals (source_id, intent, payload, payload_hash, expires_at) values (%L, %L, %L, %L, now())', src, 'task', '{}', 'h'),
    '42501');
  perform tests.expect_error(format('insert into public.plans (version, status, base_data_version) values (9, %L, 0)', 'proposed'), '42501');
  perform tests.expect_error(format('update public.sessions set status = %L where plan_id = %L', 'completed', pl), '42501');
  perform tests.expect_error(format('update public.owner_state set data_version = 0 where owner_id = %L', a), '42501');
  perform tests.expect_error(
    format('insert into public.operations (operation_id, kind, request_hash) values (gen_random_uuid(), %L, %L)', 'x', 'h'),
    '42501');
  -- tidak ada hapus fisik pada tugas
  perform tests.expect_error(format('delete from public.tasks where id = %L', t), '42501');
  -- tetap bisa membaca miliknya sendiri
  perform tests.assert((select count(*) from public.proposals where id = prop) = 1, 'A melihat proposalnya');
  perform tests.as_admin();
end $$;
