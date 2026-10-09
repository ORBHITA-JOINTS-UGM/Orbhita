-- Row level security: every row is visible and writable only by its owner.
-- Tables the server writes (sources, proposals, plans, sessions, operations, owner_state)
-- are read-only for the app.

do $$
declare
  t text;
begin
  foreach t in array array['profiles', 'owner_state', 'preferences', 'sources', 'proposals', 'tasks', 'steps',
                           'step_dependencies', 'activities', 'plans', 'sessions', 'operations']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from anon, authenticated', t);
  end loop;
end $$;

-- profiles: keyed by id
grant select, update on public.profiles to authenticated;
create policy profiles_select on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- app-writable tables: select, insert, update (no physical delete; use deleted_at)
do $$
declare
  t text;
begin
  foreach t in array array['preferences', 'tasks', 'steps', 'activities']
  loop
    execute format('grant select, insert, update on public.%I to authenticated', t);
    execute format(
      'create policy %I on public.%I for select to authenticated using (owner_id = (select auth.uid()))', t || '_select', t);
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (owner_id = (select auth.uid()))', t || '_insert', t);
    execute format(
      'create policy %I on public.%I for update to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()))',
      t || '_update', t);
  end loop;
end $$;

-- dependencies are edited by insert/delete
grant select, insert, delete on public.step_dependencies to authenticated;
create policy step_dependencies_select on public.step_dependencies for select to authenticated
  using (owner_id = (select auth.uid()));
create policy step_dependencies_insert on public.step_dependencies for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy step_dependencies_delete on public.step_dependencies for delete to authenticated
  using (owner_id = (select auth.uid()));

-- server-written tables: read-only for the owner
do $$
declare
  t text;
begin
  foreach t in array array['owner_state', 'sources', 'proposals', 'plans', 'sessions', 'operations']
  loop
    execute format('grant select on public.%I to authenticated', t);
    execute format(
      'create policy %I on public.%I for select to authenticated using (owner_id = (select auth.uid()))', t || '_select', t);
  end loop;
end $$;

-- Private bucket for media that waits to be processed. Path: {user_id}/{file}
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('inputs', 'inputs', false, 10485760, array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do nothing;

create policy inputs_select_own on storage.objects for select to authenticated
  using (bucket_id = 'inputs' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy inputs_insert_own on storage.objects for insert to authenticated
  with check (bucket_id = 'inputs' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy inputs_delete_own on storage.objects for delete to authenticated
  using (bucket_id = 'inputs' and (storage.foldername(name))[1] = (select auth.uid())::text);
