-- Test helpers. Loaded by run.mjs inside the same transaction as each test, then rolled back.
create schema tests;
grant usage on schema tests to public;

create function tests.create_user(p_email text) returns uuid
language plpgsql as $$
declare
  v uuid := gen_random_uuid();
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', p_email, '',
          now(), '{}', '{}', now(), now());
  return v;
end $$;

create function tests.as_user(p_uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_uid::text, true);
  execute 'set local role authenticated';
end $$;

create function tests.as_admin() returns void
language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
end $$;

create function tests.assert(p_ok boolean, p_msg text) returns void
language plpgsql as $$
begin
  if p_ok is not true then
    raise exception 'assertion failed: %', p_msg;
  end if;
end $$;

-- Passes when p_sql raises an error whose message contains p_expect or whose SQLSTATE equals it.
create function tests.expect_error(p_sql text, p_expect text) returns void
language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if sqlerrm like '%' || p_expect || '%' or sqlstate = p_expect then
      return;
    end if;
    raise exception 'expected error "%" but got "%" (%) for: %', p_expect, sqlerrm, sqlstate, p_sql;
  end;
  raise exception 'expected error "%" but statement succeeded: %', p_expect, p_sql;
end $$;

grant execute on all functions in schema tests to public;
