-- Optimistic concurrency: clients send the revision they last saw; the trigger rejects
-- stale writes and bumps the revision on success. Errors use SQLSTATE PTxxx so PostgREST
-- answers with HTTP xxx.
create function public.tg_revision() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.revision <> old.revision then
    raise exception 'REVISION_CONFLICT' using errcode = 'PT409';
  end if;
  new.revision := old.revision + 1;
  new.updated_at := now();
  return new;
end $$;

do $$
declare
  t text;
begin
  foreach t in array array['profiles', 'preferences', 'sources', 'proposals', 'tasks', 'steps', 'activities', 'plans', 'sessions']
  loop
    execute format('create trigger revision before update on public.%I for each row execute function public.tg_revision()', t);
  end loop;
end $$;

-- Any change to planning inputs makes pending plan proposals stale.
create function public.tg_bump_data_version() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_owner uuid := coalesce(new.owner_id, old.owner_id);
begin
  insert into public.owner_state (owner_id, data_version) values (v_owner, 1)
  on conflict (owner_id) do update set data_version = public.owner_state.data_version + 1;
  return null;
end $$;

do $$
declare
  t text;
begin
  foreach t in array array['tasks', 'steps', 'step_dependencies', 'activities', 'preferences']
  loop
    execute format(
      'create trigger bump_data_version after insert or update or delete on public.%I for each row execute function public.tg_bump_data_version()', t);
  end loop;
end $$;

create function public.tg_step_done() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.status = 'done' then
    new.remaining_minutes := 0;
  end if;
  return new;
end $$;

create trigger step_done before insert or update on public.steps
for each row execute function public.tg_step_done();

-- Keeps tasks.work_status in line with its (non-deleted) steps.
create function public.tg_task_status() returns trigger
language plpgsql set search_path = '' as $$
declare
  v_task uuid := coalesce(new.task_id, old.task_id);
  v_total int;
  v_done int;
  v_started int;
  v_status text;
begin
  select count(*), count(*) filter (where status = 'done'), count(*) filter (where status <> 'not_started')
    into v_total, v_done, v_started
  from public.steps where task_id = v_task and deleted_at is null;

  v_status := case
    when v_total > 0 and v_done = v_total then 'done'
    when v_started > 0 then 'in_progress'
    else 'not_started'
  end;
  update public.tasks set work_status = v_status where id = v_task and work_status is distinct from v_status;
  return null;
end $$;

create trigger task_status after insert or update of status, deleted_at or delete on public.steps
for each row execute function public.tg_task_status();

create function public.tg_dependency_cycle() returns trigger
language plpgsql set search_path = '' as $$
begin
  if exists (
    with recursive reach(id) as (
      select new.depends_on_id
      union
      select d.depends_on_id from public.step_dependencies d join reach r on d.step_id = r.id
    )
    select 1 from reach where id = new.step_id
  ) then
    raise exception 'DEPENDENCY_CYCLE' using errcode = 'PT422';
  end if;
  return new;
end $$;

create trigger dependency_cycle before insert or update on public.step_dependencies
for each row execute function public.tg_dependency_cycle();

-- Calendar-imported events are read-only for the app; only server processes write them.
create function public.tg_activity_source_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '') <> 'authenticated' then
    return coalesce(new, old);
  end if;
  if tg_op = 'INSERT' and new.source <> 'manual' then
    raise exception 'FORBIDDEN' using errcode = 'PT403';
  end if;
  if tg_op in ('UPDATE', 'DELETE') and old.source = 'google' then
    raise exception 'FORBIDDEN' using errcode = 'PT403';
  end if;
  if tg_op = 'UPDATE' and new.source <> old.source then
    raise exception 'FORBIDDEN' using errcode = 'PT403';
  end if;
  return coalesce(new, old);
end $$;

create trigger activity_source_guard before insert or update or delete on public.activities
for each row execute function public.tg_activity_source_guard();

-- New sign-ups get their profile, preferences and state rows.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  insert into public.preferences (owner_id) values (new.id) on conflict do nothing;
  insert into public.owner_state (owner_id) values (new.id) on conflict do nothing;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();
