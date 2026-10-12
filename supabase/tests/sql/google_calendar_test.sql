-- Dijalankan oleh runner dalam transaksi yang selalu di-rollback.
do $$
declare
  v_owner uuid := tests.create_user('calendar-test@example.com');
  v_other uuid := tests.create_user('calendar-other@example.com');
  v_connected timestamptz := now();
  v_synced timestamptz;
  v_start timestamptz := '2026-10-10T00:00:00Z';
  v_end timestamptz := '2026-10-11T00:00:00Z';
  v_result jsonb;
  v_version bigint;
  v_events jsonb := '[
    {
      "external_key": "calendar-busy",
      "title": "Kuliah",
      "start_at": "2026-10-10T08:00:00Z",
      "end_at": "2026-10-10T09:00:00Z",
      "busy": true
    },
    {
      "external_key": "calendar-free",
      "title": "Catatan",
      "start_at": "2026-10-10T10:00:00Z",
      "end_at": "2026-10-10T11:00:00Z",
      "busy": false
    }
  ]'::jsonb;
begin
  insert into public.google_calendar_connections (
    owner_id, refresh_token_encrypted, granted_scopes, connected_at
  ) values (
    v_owner, 'dummy-encrypted-token',
    array['https://www.googleapis.com/auth/calendar.events.readonly'],
    v_connected
  );

  -- Data pembanding yang tidak boleh disentuh sinkronisasi.
  insert into public.activities (
    owner_id, source, external_key, title, start_at, end_at
  ) values
    (v_owner, 'manual', null, 'Acara manual',
     '2026-10-10T12:00:00Z', '2026-10-10T13:00:00Z'),
    (v_other, 'google', 'other-event', 'Acara pengguna lain',
     '2026-10-10T08:00:00Z', '2026-10-10T09:00:00Z');

  -- 1. Impor pertama.
  v_result := public.apply_google_calendar_snapshot(
    v_owner, v_connected, null, v_start, v_end, v_events
  );
  perform tests.assert(
    (v_result->>'written')::integer = 2,
    'impor pertama harus menulis dua acara'
  );

  -- 2. Busy memblokir waktu; Free tidak memblokir waktu.
  perform tests.assert(
    exists (
      select 1 from public.activities
      where owner_id = v_owner and external_key = 'calendar-busy'
        and busy and locked and deleted_at is null
    ),
    'acara Busy harus memblokir jadwal'
  );
  perform tests.assert(
    exists (
      select 1 from public.activities
      where owner_id = v_owner and external_key = 'calendar-free'
        and not busy and not locked and deleted_at is null
    ),
    'acara Free tidak boleh memblokir jadwal'
  );

  select last_synced_at into v_synced
  from public.google_calendar_connections where owner_id = v_owner;
  select data_version into v_version
  from public.owner_state where owner_id = v_owner;

  -- 3. Impor ulang tidak menduplikasi atau mengubah acara identik.
  v_result := public.apply_google_calendar_snapshot(
    v_owner, v_connected, v_synced, v_start, v_end, v_events
  );
  perform tests.assert(
    (v_result->>'written')::integer = 0,
    'snapshot identik tidak boleh menulis ulang acara'
  );
  perform tests.assert(
    (select count(*) = 2 from public.activities
     where owner_id = v_owner and source = 'google'),
    'impor ulang tidak boleh membuat duplikat'
  );
  perform tests.assert(
    (select data_version = v_version from public.owner_state
     where owner_id = v_owner),
    'snapshot identik tidak boleh membuat rencana menjadi stale'
  );

  -- 4. Snapshot lama harus ditolak.
  begin
    perform public.apply_google_calendar_snapshot(
      v_owner, v_connected, null, v_start, v_end, v_events
    );
    raise exception 'snapshot lama ternyata diterima';
  exception when sqlstate 'PT409' then
    if sqlerrm <> 'STALE_CALENDAR_SYNC' then
      raise;
    end if;
  end;

  select last_synced_at into v_synced
  from public.google_calendar_connections where owner_id = v_owner;

  -- 5. Acara yang hilang di Google menjadi soft delete.
  v_result := public.apply_google_calendar_snapshot(
    v_owner, v_connected, v_synced, v_start, v_end,
    jsonb_build_array(v_events->1)
  );
  perform tests.assert(
    (v_result->>'removed')::integer = 1,
    'snapshot baru harus menghapus satu acara'
  );
  perform tests.assert(
    exists (
      select 1 from public.activities
      where owner_id = v_owner and external_key = 'calendar-busy'
        and deleted_at is not null
    ),
    'acara hilang harus dihapus secara soft delete'
  );
  perform tests.assert(
    exists (
      select 1 from public.activities
      where owner_id = v_owner and source = 'manual'
        and deleted_at is null
    ),
    'acara manual harus tetap aman'
  );
  perform tests.assert(
    exists (
      select 1 from public.activities
      where owner_id = v_other and external_key = 'other-event'
        and deleted_at is null
    ),
    'acara pengguna lain harus tetap aman'
  );

  select last_synced_at into v_synced
  from public.google_calendar_connections where owner_id = v_owner;
  select data_version into v_version
  from public.owner_state where owner_id = v_owner;

  -- 6. Payload duplikat gagal dan seluruh perubahan dibatalkan.
  begin
    perform public.apply_google_calendar_snapshot(
      v_owner, v_connected, v_synced, v_start, v_end,
      jsonb_build_array(v_events->0, v_events->0)
    );
    raise exception 'payload duplikat ternyata diterima';
  exception when sqlstate '21000' then
    null;
  end;
  perform tests.assert(
    exists (
      select 1 from public.activities
      where owner_id = v_owner and external_key = 'calendar-busy'
        and deleted_at is not null
    ),
    'sinkronisasi gagal tidak boleh memulihkan sebagian acara'
  );
  perform tests.assert(
    (select last_synced_at = v_synced
     from public.google_calendar_connections where owner_id = v_owner),
    'sinkronisasi gagal tidak boleh mengubah waktu sync'
  );
  perform tests.assert(
    (select data_version = v_version from public.owner_state
     where owner_id = v_owner),
    'sinkronisasi gagal tidak boleh mengubah versi data'
  );

  -- 7. Acara yang muncul kembali dipulihkan tanpa duplikat.
  v_result := public.apply_google_calendar_snapshot(
    v_owner, v_connected, v_synced, v_start, v_end, v_events
  );
  perform tests.assert(
    (select count(*) = 2 from public.activities
     where owner_id = v_owner and source = 'google'
       and deleted_at is null),
    'acara yang muncul kembali harus dipulihkan tanpa duplikat'
  );

  -- 8. Aplikasi tidak boleh membaca token atau memanggil RPC server.
  perform tests.assert(
    not has_table_privilege(
      'authenticated', 'public.google_calendar_connections', 'SELECT'
    ),
    'pengguna tidak boleh membaca token Google'
  );
  perform tests.assert(
    not has_table_privilege(
      'authenticated', 'public.google_calendar_oauth_states', 'SELECT'
    ),
    'pengguna tidak boleh membaca state OAuth'
  );
  perform tests.assert(
    not has_function_privilege(
      'authenticated',
      'public.apply_google_calendar_snapshot(uuid,timestamptz,timestamptz,timestamptz,timestamptz,jsonb)',
      'EXECUTE'
    ),
    'pengguna tidak boleh memanggil RPC sinkronisasi langsung'
  );
  perform tests.assert(
    has_function_privilege(
      'service_role',
      'public.apply_google_calendar_snapshot(uuid,timestamptz,timestamptz,timestamptz,timestamptz,jsonb)',
      'EXECUTE'
    ),
    'backend harus bisa memanggil RPC sinkronisasi'
  );
end;
$$;
