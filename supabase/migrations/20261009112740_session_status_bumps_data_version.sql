-- Starting or finishing a session changes what the scheduler must treat as fixed, so
-- pending plan proposals become stale.
create or replace function public.set_session_status(p_session_id uuid, p_status text, p_revision int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_session public.sessions;
  v_revision int;
begin
  select * into v_session from public.sessions where id = p_session_id and owner_id = auth.uid() for update;
  if not found then
    raise exception 'NOT_FOUND' using errcode = 'PT404';
  end if;
  if v_session.revision <> p_revision then
    raise exception 'REVISION_CONFLICT' using errcode = 'PT409';
  end if;
  if not (
    (v_session.status = 'planned' and p_status in ('in_progress', 'postponed')) or
    (v_session.status = 'in_progress' and p_status in ('completed', 'postponed'))
  ) then
    raise exception 'INVALID_INPUT' using errcode = 'PT400', detail = 'status';
  end if;

  update public.sessions set status = p_status where id = p_session_id returning revision into v_revision;
  update public.owner_state set data_version = data_version + 1 where owner_id = v_session.owner_id;
  return jsonb_build_object('session_id', p_session_id, 'status', p_status, 'revision', v_revision);
end $$;
