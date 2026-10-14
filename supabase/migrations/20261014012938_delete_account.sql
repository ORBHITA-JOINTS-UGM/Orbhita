-- Jangan membuat ulang owner_state saat akun dihapus lewat cascade.
create or replace function public.tg_bump_data_version() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_owner uuid := coalesce(new.owner_id, old.owner_id);
begin
  if not exists (select 1 from auth.users where id = v_owner) then
    return null;
  end if;

  insert into public.owner_state (owner_id, data_version)
  values (v_owner, 1)
  on conflict (owner_id) do update
    set data_version = public.owner_state.data_version + 1;

  return null;
end $$;

-- Penanda tetap ada saat pembersihan gagal, agar proses bisa dilanjutkan.
create table public.account_deletions (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  requested_at timestamptz not null default now()
);

alter table public.account_deletions enable row level security;
revoke all on public.account_deletions from public, anon, authenticated;
grant select, insert, update, delete
  on public.account_deletions to service_role;

-- Penghapusan hanya dimulai backend setelah memverifikasi sesi pengguna.
create function public.begin_account_deletion(p_owner_id uuid)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from auth.users where id = p_owner_id for update;
  if not found then
    raise exception 'NOT_FOUND' using errcode = 'PT404';
  end if;

  insert into public.account_deletions(owner_id)
  values (p_owner_id)
  on conflict (owner_id) do nothing;
end;
$$;

revoke all on function public.begin_account_deletion(uuid)
  from public, anon, authenticated;
grant execute on function public.begin_account_deletion(uuid)
  to service_role;

-- Juga menolak akses menggunakan JWT lama setelah akun terhapus.
create function public.account_accepts_requests()
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from auth.users u
    where u.id = auth.uid()
      and not exists (
        select 1 from public.account_deletions d
        where d.owner_id = u.id
      )
  );
$$;

revoke all on function public.account_accepts_requests()
  from public, anon;
grant execute on function public.account_accepts_requests()
  to authenticated;

-- Kebijakan restrictive digabung dengan kebijakan owner yang sudah ada.
do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'owner_state', 'preferences', 'sources', 'proposals',
    'tasks', 'steps', 'step_dependencies', 'activities',
    'plans', 'sessions', 'operations'
  ]
  loop
    execute format(
      'create policy account_available on public.%I
       as restrictive for all to authenticated
       using ((select public.account_accepts_requests()))
       with check ((select public.account_accepts_requests()))',
      t
    );
  end loop;
end;
$$;

create policy inputs_account_available on storage.objects
as restrictive for all to authenticated
using (
  bucket_id <> 'inputs'
  or (select public.account_accepts_requests())
)
with check (
  bucket_id <> 'inputs'
  or (select public.account_accepts_requests())
);

-- Membatasi penulisan backend juga, termasuk pekerjaan yang masih berjalan.
-- Lock membuat awal penghapusan menunggu transaksi penulisan sebelumnya.
create function public.tg_account_write_guard()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_row jsonb;
  v_owner uuid;
begin
  if tg_op = 'DELETE' then
    v_row := to_jsonb(old);
  else
    v_row := to_jsonb(new);
  end if;

  v_owner := coalesce(v_row ->> 'owner_id', v_row ->> 'id')::uuid;

  perform 1 from auth.users where id = v_owner for key share;
  if not found then
    -- Cascade dapat menghapus baris atau mengosongkan foreign key.
    if tg_op = 'DELETE' then
      return old;
    elsif tg_op = 'UPDATE' then
      return new;
    end if;
    raise exception 'ACCOUNT_UNAVAILABLE' using errcode = 'PT403';
  end if;

  if exists (
    select 1 from public.account_deletions where owner_id = v_owner
  ) then
    raise exception 'ACCOUNT_DELETING' using errcode = 'PT409';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function public.tg_account_write_guard()
  from public, anon, authenticated;

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'owner_state', 'preferences', 'sources', 'proposals',
    'tasks', 'steps', 'step_dependencies', 'activities',
    'plans', 'sessions', 'operations',
    'google_calendar_connections', 'google_calendar_oauth_states'
  ]
  loop
    execute format(
      'create trigger account_write_guard
       before insert or update or delete on public.%I
       for each row execute function public.tg_account_write_guard()',
      t
    );
  end loop;
end;
$$;

-- Mencegah unggahan baru ke inputs selama/setelah penghapusan akun.
create function public.tg_inputs_account_guard()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_prefix text;
  v_owner uuid;
begin
  if new.bucket_id <> 'inputs' then
    return new;
  end if;

  v_prefix := split_part(new.name, '/', 1);
  if v_prefix !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     or position('/' in new.name) = 0 then
    raise exception 'INVALID_INPUT_PATH' using errcode = 'PT400';
  end if;

  v_owner := v_prefix::uuid;
  perform 1 from auth.users where id = v_owner for key share;
  if not found then
    raise exception 'ACCOUNT_UNAVAILABLE' using errcode = 'PT403';
  end if;

  if exists (
    select 1 from public.account_deletions where owner_id = v_owner
  ) then
    raise exception 'ACCOUNT_DELETING' using errcode = 'PT409';
  end if;

  return new;
end;
$$;

revoke all on function public.tg_inputs_account_guard()
  from public, anon, authenticated;

create trigger inputs_account_guard
before insert or update on storage.objects
for each row execute function public.tg_inputs_account_guard();

-- Tidak perlu menghitung ulang progres saat pemilik akun sudah dihapus.
create or replace function public.tg_task_status() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_task uuid := coalesce(new.task_id, old.task_id);
  v_owner uuid := coalesce(new.owner_id, old.owner_id);
  v_total int;
  v_done int;
  v_started int;
  v_status text;
begin
  if not exists (select 1 from auth.users where id = v_owner) then
    return null;
  end if;

  select count(*),
         count(*) filter (where status = 'done'),
         count(*) filter (where status <> 'not_started')
    into v_total, v_done, v_started
  from public.steps
  where task_id = v_task and deleted_at is null;

  v_status := case
    when v_total > 0 and v_done = v_total then 'done'
    when v_started > 0 then 'in_progress'
    else 'not_started'
  end;

  update public.tasks set work_status = v_status
  where id = v_task and work_status is distinct from v_status;
  return null;
end;
$$;
