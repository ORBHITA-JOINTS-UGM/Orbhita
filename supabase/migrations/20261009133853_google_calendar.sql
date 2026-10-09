-- Koneksi Calendar: token dienkripsi oleh backend sebelum disimpan.
create table public.google_calendar_connections (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  refresh_token_encrypted text not null,
  granted_scopes text[] not null,
  calendar_id text not null default 'primary',
  connected_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_synced_at timestamptz
);

-- State OAuth sekali pakai untuk menghubungkan callback ke pengguna.
-- Yang disimpan adalah hash state, bukan state asli.
create table public.google_calendar_oauth_states (
  state_hash text primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check (expires_at > created_at)
);

create index google_calendar_oauth_states_expires_idx
  on public.google_calendar_oauth_states(expires_at);

alter table public.google_calendar_connections enable row level security;
alter table public.google_calendar_oauth_states enable row level security;

-- Tidak ada akses langsung dari aplikasi Flutter.
revoke all on public.google_calendar_connections
  from public, anon, authenticated;
revoke all on public.google_calendar_oauth_states
  from public, anon, authenticated;

grant select, insert, update, delete
  on public.google_calendar_connections to service_role;
grant select, insert, update, delete
  on public.google_calendar_oauth_states to service_role;

-- Menerapkan snapshot Calendar setelah semua halaman Google berhasil diambil.
create function public.apply_google_calendar_snapshot(
  p_owner_id uuid,
  p_connected_at timestamptz,
  p_last_synced_at timestamptz,
  p_start timestamptz,
  p_end timestamptz,
  p_events jsonb
) returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_connection public.google_calendar_connections%rowtype;
  v_written integer;
  v_removed integer;
begin
  if p_start is null or p_end is null or p_end <= p_start
     or p_end - p_start > interval '120 days' then
    raise exception 'INVALID_RANGE' using errcode = 'PT422';
  end if;

  if p_events is null or jsonb_typeof(p_events) <> 'array' then
    raise exception 'INVALID_EVENTS' using errcode = 'PT422';
  end if;

  -- Serialisasi sinkronisasi dan cegah snapshot dari koneksi lama diterapkan.
  select * into v_connection
  from public.google_calendar_connections
  where owner_id = p_owner_id
  for update;

  if not found then
    raise exception 'CALENDAR_NOT_CONNECTED' using errcode = 'PT409';
  end if;

  if v_connection.connected_at is distinct from p_connected_at
     or v_connection.last_synced_at is distinct from p_last_synced_at then
    raise exception 'STALE_CALENDAR_SYNC' using errcode = 'PT409';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_events) as e(
      external_key text, title text,
      start_at timestamptz, end_at timestamptz, busy boolean
    )
    where e.external_key is null or length(e.external_key) = 0
       or e.title is null
       or e.start_at is null or e.end_at is null
       or e.end_at <= e.start_at or e.busy is null
       or e.end_at <= p_start or e.start_at >= p_end
  ) then
    raise exception 'INVALID_EVENT' using errcode = 'PT422';
  end if;

  insert into public.activities as a (
    owner_id, source, external_key, title,
    start_at, end_at, busy, locked, deleted_at
  )
  select p_owner_id, 'google', e.external_key, e.title,
         e.start_at, e.end_at, e.busy, true, null
  from jsonb_to_recordset(p_events) as e(
    external_key text, title text,
    start_at timestamptz, end_at timestamptz, busy boolean
  )
  on conflict (owner_id, source, external_key)
    where external_key is not null
  do update set
    title = excluded.title,
    start_at = excluded.start_at,
    end_at = excluded.end_at,
    busy = excluded.busy,
    locked = true,
    deleted_at = null
  where (a.title, a.start_at, a.end_at, a.busy, a.locked, a.deleted_at)
    is distinct from
    (excluded.title, excluded.start_at, excluded.end_at,
     excluded.busy, true, null::timestamptz);

  get diagnostics v_written = row_count;

  -- Acara yang hilang/dibatalkan di Google dihapus secara soft delete.
  update public.activities as a
  set deleted_at = now()
  where a.owner_id = p_owner_id
    and a.source = 'google'
    and a.deleted_at is null
    and a.end_at > p_start
    and a.start_at < p_end
    and not exists (
      select 1
      from jsonb_to_recordset(p_events) as e(external_key text)
      where e.external_key = a.external_key
    );

  get diagnostics v_removed = row_count;

  update public.google_calendar_connections
  set last_synced_at = clock_timestamp(),
      updated_at = clock_timestamp()
  where owner_id = p_owner_id;

  return jsonb_build_object(
    'received', jsonb_array_length(p_events),
    'written', v_written,
    'removed', v_removed
  );
end;
$$;

revoke all on function public.apply_google_calendar_snapshot(
  uuid, timestamptz, timestamptz, timestamptz, timestamptz, jsonb
) from public, anon, authenticated;

grant execute on function public.apply_google_calendar_snapshot(
  uuid, timestamptz, timestamptz, timestamptz, timestamptz, jsonb
) to service_role;
