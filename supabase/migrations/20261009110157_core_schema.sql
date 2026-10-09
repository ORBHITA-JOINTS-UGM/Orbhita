-- Core tables for phase 1. All timestamps are UTC; the user's IANA zone lives on profiles.
create extension if not exists btree_gist with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  timezone text not null default 'Asia/Jakarta',
  locale text not null default 'id',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision integer not null default 1,
  deleted_at timestamptz
);

-- Bumped by triggers whenever planning inputs change; kept apart from profiles so it
-- does not touch the profile revision.
create table public.owner_state (
  owner_id uuid primary key references auth.users (id) on delete cascade,
  data_version bigint not null default 0
);

create table public.preferences (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique default auth.uid() references auth.users (id) on delete cascade,
  study_windows jsonb not null default '[]' check (jsonb_typeof(study_windows) = 'array'),
  max_daily_minutes integer not null default 120 check (max_daily_minutes between 1 and 1440),
  session_minutes integer not null default 25 check (session_minutes between 10 and 240),
  break_minutes integer not null default 5 check (break_minutes between 0 and 60),
  reminder_defaults jsonb not null default '{"deadline":[1440,60],"session":[10],"channel":"app"}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision integer not null default 1,
  deleted_at timestamptz
);

create table public.sources (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  input_type text not null check (input_type in ('text', 'image', 'pdf', 'voice')),
  text_content text,
  storage_paths text[] not null default '{}',
  status text not null default 'processing' check (status in ('processing', 'completed', 'failed')),
  error_code text,
  media_cleaned_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision integer not null default 1,
  deleted_at timestamptz,
  unique (id, owner_id)
);
create index sources_owner_created_idx on public.sources (owner_id, created_at);

create table public.proposals (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  source_id uuid not null,
  intent text not null check (intent in ('task', 'activity', 'clarification')),
  payload jsonb not null,
  payload_hash text not null,
  status text not null default 'proposed' check (status in ('proposed', 'confirmed', 'expired', 'superseded')),
  expires_at timestamptz not null,
  model_id text,
  prompt_version text,
  usage jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision integer not null default 1,
  deleted_at timestamptz,
  foreign key (source_id, owner_id) references public.sources (id, owner_id) on delete cascade
);
create index proposals_source_idx on public.proposals (source_id);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  source_id uuid,
  title text not null check (length(trim(title)) > 0),
  course text,
  requirements jsonb not null default '[]' check (jsonb_typeof(requirements) = 'array'),
  official_deadline timestamptz,
  personal_target timestamptz,
  priority text not null default 'normal' check (priority in ('high', 'normal', 'low')),
  work_status text not null default 'not_started' check (work_status in ('not_started', 'in_progress', 'done')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision integer not null default 1,
  deleted_at timestamptz,
  unique (id, owner_id),
  foreign key (source_id, owner_id) references public.sources (id, owner_id) on delete set null (source_id)
);
create index tasks_owner_updated_idx on public.tasks (owner_id, updated_at);

create table public.steps (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  task_id uuid not null,
  title text not null check (length(trim(title)) > 0),
  order_index integer not null default 0,
  estimate_minutes integer not null check (estimate_minutes > 0),
  remaining_minutes integer not null check (remaining_minutes >= 0),
  estimate_basis text,
  status text not null default 'not_started' check (status in ('not_started', 'in_progress', 'done')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision integer not null default 1,
  deleted_at timestamptz,
  unique (id, owner_id),
  unique (id, task_id),
  foreign key (task_id, owner_id) references public.tasks (id, owner_id) on delete cascade
);
create index steps_task_idx on public.steps (task_id);

-- Both ends must be steps of the same task, which itself must belong to the owner.
create table public.step_dependencies (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  task_id uuid not null,
  step_id uuid not null,
  depends_on_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (step_id, depends_on_id),
  check (step_id <> depends_on_id),
  foreign key (task_id, owner_id) references public.tasks (id, owner_id) on delete cascade,
  foreign key (step_id, task_id) references public.steps (id, task_id) on delete cascade,
  foreign key (depends_on_id, task_id) references public.steps (id, task_id) on delete cascade
);

create table public.activities (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  source text not null default 'manual' check (source in ('manual', 'google', 'orbhita')),
  external_key text,
  title text not null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  busy boolean not null default true,
  locked boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision integer not null default 1,
  deleted_at timestamptz,
  check (end_at > start_at)
);
create unique index activities_external_key_idx on public.activities (owner_id, source, external_key)
  where external_key is not null;
create index activities_owner_range_idx on public.activities (owner_id, start_at);

create table public.plans (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  version integer not null,
  status text not null check (status in ('proposed', 'active', 'superseded', 'rejected')),
  base_plan_version integer not null default 0,
  base_data_version bigint not null,
  trigger text,
  risk_summary jsonb,
  unscheduled jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision integer not null default 1,
  deleted_at timestamptz,
  unique (id, owner_id),
  unique (owner_id, version)
);
create unique index plans_one_active_idx on public.plans (owner_id) where status = 'active';
create unique index plans_one_proposed_idx on public.plans (owner_id) where status = 'proposed';

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  plan_id uuid not null,
  task_id uuid not null,
  step_id uuid not null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  status text not null default 'planned'
    check (status in ('planned', 'in_progress', 'completed', 'postponed', 'cancelled')),
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision integer not null default 1,
  deleted_at timestamptz,
  check (end_at > start_at),
  foreign key (plan_id, owner_id) references public.plans (id, owner_id) on delete cascade,
  foreign key (task_id, owner_id) references public.tasks (id, owner_id) on delete cascade,
  foreign key (step_id, owner_id) references public.steps (id, owner_id) on delete cascade,
  constraint sessions_no_overlap exclude using gist (
    owner_id with =,
    tstzrange(start_at, end_at) with &&
  ) where (is_active and status in ('planned', 'in_progress'))
);
create index sessions_plan_idx on public.sessions (plan_id);
create index sessions_owner_active_idx on public.sessions (owner_id) where is_active;

-- Idempotency receipts for mutations that may be retried.
create table public.operations (
  owner_id uuid not null references auth.users (id) on delete cascade,
  operation_id uuid not null,
  kind text not null,
  request_hash text not null,
  response jsonb,
  created_at timestamptz not null default now(),
  primary key (owner_id, operation_id)
);
