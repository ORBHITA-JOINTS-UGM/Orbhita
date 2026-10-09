-- Transactional operations. Callable by signed-in users unless noted; each one resolves the
-- owner from auth.uid() and never trusts an owner id from the caller.

create function public.confirm_proposal(
  p_proposal_id uuid,
  p_payload_hash text,
  p_draft jsonb,
  p_operation_id uuid
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_hash text := md5(p_draft::text || coalesce(p_payload_hash, ''));
  v_op public.operations;
  v_prop public.proposals;
  v_intent text := p_draft ->> 'intent';
  v_title text := nullif(trim(p_draft ->> 'title'), '');
  v_deadline timestamptz := (p_draft -> 'official_deadline' ->> 'at')::timestamptz;
  v_target timestamptz := (p_draft -> 'personal_target' ->> 'at')::timestamptz;
  v_task_id uuid;
  v_activity_id uuid;
  v_step jsonb;
  v_step_id uuid;
  v_dep text;
  v_map jsonb := '{}';
  v_warnings jsonb := '[]';
  v_result jsonb;
  v_ord int;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'PT401';
  end if;

  select * into v_op from public.operations where owner_id = v_uid and operation_id = p_operation_id;
  if found then
    if v_op.request_hash <> v_hash then
      raise exception 'OPERATION_REUSED' using errcode = 'PT409';
    end if;
    return v_op.response;
  end if;

  select * into v_prop from public.proposals where id = p_proposal_id and owner_id = v_uid for update;
  if not found then
    raise exception 'NOT_FOUND' using errcode = 'PT404';
  end if;
  if v_prop.status <> 'proposed' or v_prop.expires_at < now() or v_prop.payload_hash <> p_payload_hash then
    raise exception 'PROPOSAL_STALE' using errcode = 'PT409';
  end if;

  if v_intent = 'task' then
    if v_title is null then
      raise exception 'INVALID_INPUT' using errcode = 'PT400', detail = 'title';
    end if;
    insert into public.tasks (owner_id, source_id, title, course, requirements, official_deadline, personal_target)
    values (v_uid, v_prop.source_id, v_title, nullif(trim(p_draft ->> 'course'), ''),
            coalesce(p_draft -> 'requirements', '[]'), v_deadline, v_target)
    returning id into v_task_id;

    for v_step, v_ord in
      select value, ordinality from jsonb_array_elements(coalesce(p_draft -> 'steps', '[]')) with ordinality
    loop
      insert into public.steps (owner_id, task_id, title, order_index, estimate_minutes, remaining_minutes, estimate_basis)
      values (v_uid, v_task_id, v_step ->> 'title', v_ord - 1, (v_step ->> 'estimate_minutes')::int,
              (v_step ->> 'estimate_minutes')::int, v_step ->> 'estimate_basis')
      returning id into v_step_id;
      v_map := v_map || jsonb_build_object(v_step ->> 'client_step_id', v_step_id);
    end loop;

    for v_step in select value from jsonb_array_elements(coalesce(p_draft -> 'steps', '[]'))
    loop
      for v_dep in select jsonb_array_elements_text(coalesce(v_step -> 'depends_on', '[]'))
      loop
        if v_map ->> v_dep is null then
          raise exception 'INVALID_INPUT' using errcode = 'PT400', detail = 'depends_on';
        end if;
        insert into public.step_dependencies (owner_id, task_id, step_id, depends_on_id)
        values (v_uid, v_task_id, (v_map ->> (v_step ->> 'client_step_id'))::uuid, (v_map ->> v_dep)::uuid);
      end loop;
    end loop;

    if v_deadline is not null and v_target is not null and v_target > v_deadline then
      v_warnings := v_warnings || to_jsonb('Target pribadi berada setelah deadline resmi.'::text);
    end if;
    v_result := jsonb_build_object('task_id', v_task_id, 'warnings', v_warnings);

  elsif v_intent = 'activity' then
    insert into public.activities (owner_id, source, title, start_at, end_at, locked)
    values (v_uid, 'manual', p_draft -> 'activity' ->> 'title',
            (p_draft -> 'activity' ->> 'start_at')::timestamptz, (p_draft -> 'activity' ->> 'end_at')::timestamptz,
            coalesce((p_draft -> 'activity' ->> 'locked')::boolean, true))
    returning id into v_activity_id;
    v_result := jsonb_build_object('activity_id', v_activity_id, 'warnings', v_warnings);

  else
    raise exception 'NEEDS_CLARIFICATION' using errcode = 'PT422';
  end if;

  update public.proposals set status = 'confirmed' where id = p_proposal_id;
  insert into public.operations (owner_id, operation_id, kind, request_hash, response)
  values (v_uid, p_operation_id, 'confirm_proposal', v_hash, v_result);
  return v_result;
end $$;

-- Server-only: stores a plan proposal and its sessions in one transaction.
create function public.save_plan_proposal(p_owner uuid, p_plan jsonb, p_sessions jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  update public.plans set status = 'superseded' where owner_id = p_owner and status = 'proposed';

  insert into public.plans (owner_id, version, status, base_plan_version, base_data_version, trigger, risk_summary, unscheduled)
  values (p_owner, (p_plan ->> 'version')::int, 'proposed', coalesce((p_plan ->> 'base_plan_version')::int, 0),
          (p_plan ->> 'base_data_version')::bigint, p_plan ->> 'trigger', p_plan -> 'risk_summary', p_plan -> 'unscheduled')
  returning id into v_id;

  insert into public.sessions (owner_id, plan_id, task_id, step_id, start_at, end_at, is_active)
  select p_owner, v_id, (s ->> 'task_id')::uuid, (s ->> 'step_id')::uuid,
         (s ->> 'start_at')::timestamptz, (s ->> 'end_at')::timestamptz, false
  from jsonb_array_elements(coalesce(p_sessions, '[]')) s;

  return v_id;
end $$;

create function public.confirm_plan(p_plan_id uuid, p_operation_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_hash text := md5(p_plan_id::text);
  v_op public.operations;
  v_plan public.plans;
  v_active_version int;
  v_data_version bigint;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'PT401';
  end if;

  select * into v_op from public.operations where owner_id = v_uid and operation_id = p_operation_id;
  if found then
    if v_op.request_hash <> v_hash then
      raise exception 'OPERATION_REUSED' using errcode = 'PT409';
    end if;
    return v_op.response;
  end if;

  select * into v_plan from public.plans where id = p_plan_id and owner_id = v_uid for update;
  if not found then
    raise exception 'NOT_FOUND' using errcode = 'PT404';
  end if;

  select coalesce(max(version), 0) into v_active_version from public.plans where owner_id = v_uid and status = 'active';
  select data_version into v_data_version from public.owner_state where owner_id = v_uid for update;
  if v_plan.status <> 'proposed'
     or v_plan.base_plan_version <> v_active_version
     or v_plan.base_data_version <> coalesce(v_data_version, 0) then
    raise exception 'STALE_PLAN' using errcode = 'PT409';
  end if;

  -- Old planned sessions go inactive first so the overlap constraint only sees the new plan.
  -- Sessions already started or finished stay active as history.
  update public.sessions set is_active = false
  where owner_id = v_uid and is_active and plan_id <> p_plan_id and status not in ('in_progress', 'completed');
  update public.plans set status = 'superseded' where owner_id = v_uid and status = 'active';
  update public.plans set status = 'active' where id = p_plan_id;
  update public.sessions set is_active = true where plan_id = p_plan_id;

  v_result := jsonb_build_object('plan_id', p_plan_id, 'version', v_plan.version);
  insert into public.operations (owner_id, operation_id, kind, request_hash, response)
  values (v_uid, p_operation_id, 'confirm_plan', v_hash, v_result);
  return v_result;
end $$;

create function public.reject_plan(p_plan_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.plans set status = 'rejected'
  where id = p_plan_id and owner_id = auth.uid() and status = 'proposed';
  if not found then
    raise exception 'NOT_FOUND' using errcode = 'PT404';
  end if;
end $$;

create function public.set_session_status(p_session_id uuid, p_status text, p_revision int) returns jsonb
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
  return jsonb_build_object('session_id', p_session_id, 'status', p_status, 'revision', v_revision);
end $$;

revoke all on function public.confirm_proposal(uuid, text, jsonb, uuid) from public, anon;
revoke all on function public.confirm_plan(uuid, uuid) from public, anon;
revoke all on function public.reject_plan(uuid) from public, anon;
revoke all on function public.set_session_status(uuid, text, int) from public, anon;
revoke all on function public.save_plan_proposal(uuid, jsonb, jsonb) from public, anon, authenticated;

grant execute on function public.confirm_proposal(uuid, text, jsonb, uuid) to authenticated;
grant execute on function public.confirm_plan(uuid, uuid) to authenticated;
grant execute on function public.reject_plan(uuid) to authenticated;
grant execute on function public.set_session_status(uuid, text, int) to authenticated;
grant execute on function public.save_plan_proposal(uuid, jsonb, jsonb) to service_role;

-- Trigger functions are not part of the API.
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.tg_bump_data_version() from public, anon, authenticated;
revoke all on function public.tg_revision() from public, anon, authenticated;
revoke all on function public.tg_step_done() from public, anon, authenticated;
revoke all on function public.tg_task_status() from public, anon, authenticated;
revoke all on function public.tg_dependency_cycle() from public, anon, authenticated;
revoke all on function public.tg_activity_source_guard() from public, anon, authenticated;
