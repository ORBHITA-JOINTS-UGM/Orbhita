do $$
declare
  v_a uuid := tests.create_user('delete-a-' || gen_random_uuid() || '@example.test');
  v_b uuid := tests.create_user('delete-b-' || gen_random_uuid() || '@example.test');
  v_source uuid;
  v_task uuid;
  v_other_task uuid;
  v_step uuid;
  v_second_step uuid;
  v_other_step uuid;
  v_plan uuid;
  v_count bigint;
  v_table text;
begin
  insert into public.sources(owner_id, input_type, text_content)
  values (v_a, 'text', 'Input pengujian')
  returning id into v_source;

  insert into public.proposals(
    owner_id, source_id, intent, payload, payload_hash, expires_at
  )
  values (
    v_a, v_source, 'task', '{}', 'test-hash', now() + interval '1 day'
  );

  insert into public.tasks(owner_id, source_id, title)
  values (v_a, v_source, 'Tugas akun yang dihapus')
  returning id into v_task;

  insert into public.steps(
    owner_id, task_id, title, estimate_minutes, remaining_minutes
  )
  values (v_a, v_task, 'Langkah pertama', 30, 30)
  returning id into v_step;

  insert into public.steps(
    owner_id, task_id, title, estimate_minutes, remaining_minutes
  )
  values (v_a, v_task, 'Langkah kedua', 30, 30)
  returning id into v_second_step;

  insert into public.step_dependencies(owner_id, task_id, step_id, depends_on_id)
  values (v_a, v_task, v_second_step, v_step);

  insert into public.plans(
    owner_id, version, status, base_data_version
  )
  values (v_a, 1, 'active', 0)
  returning id into v_plan;

  insert into public.sessions(
    owner_id, plan_id, task_id, step_id, start_at, end_at, is_active
  )
  values (
    v_a, v_plan, v_task, v_step,
    now() + interval '1 day',
    now() + interval '1 day 30 minutes',
    true
  );

  insert into public.activities(owner_id, title, start_at, end_at)
  values (
    v_a, 'Kegiatan uji',
    now() + interval '2 days',
    now() + interval '2 days 1 hour'
  );

  insert into public.operations(
    owner_id, operation_id, kind, request_hash, response
  )
  values (v_a, gen_random_uuid(), 'extract', 'test', '{}');

  insert into public.google_calendar_connections(
    owner_id, refresh_token_encrypted, granted_scopes
  )
  values (v_a, 'dummy-test-token', array['calendar.events.readonly']);

  insert into public.google_calendar_oauth_states(
    state_hash, owner_id, expires_at
  )
  values (repeat('a', 64), v_a, now() + interval '10 minutes');

  insert into public.tasks(owner_id, title)
  values (v_b, 'Tugas pengguna lain')
  returning id into v_other_task;

  insert into public.steps(
    owner_id, task_id, title, estimate_minutes, remaining_minutes
  )
  values (v_b, v_other_task, 'Langkah pengguna lain', 30, 30)
  returning id into v_other_step;

  perform tests.assert(
    not has_function_privilege(
      'authenticated', 'public.begin_account_deletion(uuid)', 'EXECUTE'
    ),
    'pengguna tidak boleh mengunci akun lewat RPC backend'
  );
  perform tests.assert(
    has_function_privilege(
      'service_role', 'public.begin_account_deletion(uuid)', 'EXECUTE'
    ),
    'backend harus bisa memulai penghapusan'
  );
  perform tests.assert(
    not has_table_privilege(
      'authenticated', 'public.account_deletions', 'INSERT'
    ),
    'pengguna tidak boleh menulis penanda penghapusan langsung'
  );

  perform tests.as_user(v_a);
  perform tests.assert(
    public.account_accepts_requests(),
    'akun normal harus dapat mengakses aplikasi'
  );
  select count(*) into v_count from public.tasks;
  perform tests.assert(v_count = 1, 'akun A hanya melihat tugasnya sendiri');
  perform tests.as_admin();

  perform public.begin_account_deletion(v_a);
  perform public.begin_account_deletion(v_a);
  select count(*) into v_count
    from public.account_deletions where owner_id = v_a;
  perform tests.assert(v_count = 1, 'permintaan ulang tidak menggandakan penanda');

  perform tests.expect_error(
    format(
      'insert into public.tasks(owner_id, title) values (%L, %L)',
      v_a, 'Tugas baru setelah penghapusan dimulai'
    ),
    'PT409'
  );

  perform tests.expect_error(
    format(
      'insert into storage.objects(bucket_id, name) values (%L, %L)',
      'inputs', v_a::text || '/blocked.pdf'
    ),
    'PT409'
  );

  perform tests.as_user(v_a);
  perform tests.assert(
    not public.account_accepts_requests(),
    'akun yang sedang dihapus harus terkunci'
  );
  select count(*) into v_count from public.tasks;
  perform tests.assert(v_count = 0, 'RLS menutup data akun yang sedang dihapus');
  perform tests.as_admin();

  -- Akun lain tetap dapat memperbarui progres lewat izin pengguna biasa.
  perform tests.as_user(v_b);
  update public.steps set status = 'in_progress' where id = v_other_step;
  perform tests.assert(
    (select work_status = 'in_progress'
     from public.tasks where id = v_other_task),
    'trigger progres harus tetap bekerja untuk pengguna lain'
  );
  perform tests.as_admin();

  -- Menguji cascade database; penghapusan file asli dilakukan Storage API.
  delete from auth.users where id = v_a;

  perform tests.assert(
    not exists (select 1 from auth.users where id = v_a),
    'akun Auth A harus terhapus'
  );
  perform tests.assert(
    not exists (select 1 from public.profiles where id = v_a),
    'profil A harus ikut terhapus'
  );

  foreach v_table in array array[
    'owner_state', 'preferences', 'sources', 'proposals',
    'tasks', 'steps', 'step_dependencies', 'activities',
    'plans', 'sessions', 'operations', 'account_deletions',
    'google_calendar_connections', 'google_calendar_oauth_states'
  ]
  loop
    execute format(
      'select count(*) from public.%I where owner_id = $1', v_table
    ) into v_count using v_a;
    perform tests.assert(v_count = 0, v_table || ' harus bersih untuk akun A');
  end loop;

  perform tests.assert(
    exists (select 1 from auth.users where id = v_b),
    'akun pengguna B harus tetap ada'
  );
  perform tests.assert(
    exists (select 1 from public.tasks where id = v_other_task),
    'tugas pengguna B tidak boleh terhapus'
  );

  -- Klaim JWT lama tidak boleh membuka akses atau mengunggah file baru.
  perform tests.as_user(v_a);
  perform tests.assert(
    not public.account_accepts_requests(),
    'klaim akun terhapus harus ditolak'
  );
  perform tests.as_admin();

  perform tests.expect_error(
    format(
      'insert into storage.objects(bucket_id, name) values (%L, %L)',
      'inputs', v_a::text || '/after-delete.pdf'
    ),
    'PT403'
  );
end;
$$;
