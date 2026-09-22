-- VaaniX Phase 1: user-owned application data.
--
-- This migration deliberately models the aggregates the Flutter repositories
-- already persist locally. JSONB is used only at an aggregate boundary where
-- the existing model is serialized as a document; it is not a substitute for
-- a fabricated content catalog. Trusted curriculum and official syllabus stay
-- bundled, versioned application assets.
--
-- Every mutable cloud record has an authenticated owner, optimistic revision,
-- and server timestamp. SharedPreferences remains the offline cache; applying
-- this migration alone does not switch the app to cloud persistence.

create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  companion_name text,
  personality_mode text,
  selected_class smallint check (selected_class between 6 and 10),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0)
);

create table public.app_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  theme_mode text,
  app_language text,
  active_app_mode text,
  daily_goal_minutes smallint check (daily_goal_minutes in (5, 10, 15, 20)),
  reduced_motion boolean,
  sound_enabled boolean,
  sound_volume numeric(3,2) check (sound_volume between 0 and 1),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0)
);

create table public.learner_profiles (
  user_id uuid not null references auth.users(id) on delete cascade,
  language_code text not null check (language_code ~ '^[a-z]{2,3}$'),
  profile jsonb not null check (jsonb_typeof(profile) = 'object'),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, language_code)
);

create table public.learning_states (
  user_id uuid not null references auth.users(id) on delete cascade,
  language_code text not null check (language_code ~ '^[a-z]{2,3}$'),
  state jsonb not null check (jsonb_typeof(state) = 'object'),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, language_code)
);

create table public.learning_plans (
  user_id uuid not null references auth.users(id) on delete cascade,
  language_code text not null check (language_code ~ '^[a-z]{2,3}$'),
  plan jsonb not null check (jsonb_typeof(plan) = 'object'),
  plan_source text not null check (plan_source in ('deterministic', 'cached', 'ai')),
  expires_at timestamptz,
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, language_code)
);

create table public.generated_content (
  user_id uuid not null references auth.users(id) on delete cascade,
  content_key text not null,
  language_code text not null check (language_code ~ '^[a-z]{2,3}$'),
  concept_id text not null,
  content jsonb not null check (jsonb_typeof(content) = 'object'),
  source text not null check (source in ('trusted', 'generated')),
  trusted boolean not null default false,
  input_hash text,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, content_key),
  check ((source = 'trusted' and trusted) or (source = 'generated' and not trusted))
);

create table public.progress_states (
  user_id uuid primary key references auth.users(id) on delete cascade,
  xp_total integer not null default 0 check (xp_total >= 0),
  completed_lesson_ids jsonb not null default '[]'::jsonb check (jsonb_typeof(completed_lesson_ids) = 'array'),
  completed_quiz_ids jsonb not null default '[]'::jsonb check (jsonb_typeof(completed_quiz_ids) = 'array'),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0)
);

create table public.quiz_attempts (
  user_id uuid not null references auth.users(id) on delete cascade,
  quiz_id text not null,
  attempts jsonb not null check (jsonb_typeof(attempts) = 'array'),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, quiz_id)
);

create table public.achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id text not null,
  unlocked_at timestamptz not null,
  evidence jsonb not null default '{}'::jsonb check (jsonb_typeof(evidence) = 'object'),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, achievement_id)
);

create table public.daily_activity (
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_date date not null,
  activity jsonb not null check (jsonb_typeof(activity) = 'object'),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, activity_date)
);

create table public.streak_states (
  user_id uuid primary key references auth.users(id) on delete cascade,
  current_streak integer not null default 0 check (current_streak >= 0),
  last_active_date date,
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0)
);

create table public.ai_conversations (
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id text not null,
  messages jsonb not null check (jsonb_typeof(messages) = 'array'),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, conversation_id)
);

create table public.ai_usage_records (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null,
  usage jsonb not null check (jsonb_typeof(usage) = 'object'),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, usage_date)
);

create table public.exam_scopes (
  user_id uuid not null references auth.users(id) on delete cascade,
  track_id text not null,
  scope jsonb not null check (jsonb_typeof(scope) = 'object'),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, track_id)
);

create table public.exam_profiles (
  user_id uuid not null references auth.users(id) on delete cascade,
  track_id text not null,
  profile jsonb not null check (jsonb_typeof(profile) = 'object'),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, track_id)
);

create table public.exam_learner_profiles (
  user_id uuid not null references auth.users(id) on delete cascade,
  track_id text not null,
  profile jsonb not null check (jsonb_typeof(profile) = 'object'),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, track_id)
);

create table public.exam_plans (
  user_id uuid not null references auth.users(id) on delete cascade,
  track_id text not null,
  plan jsonb not null check (jsonb_typeof(plan) = 'object'),
  plan_source text not null check (plan_source in ('deterministic', 'cached', 'ai')),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, track_id)
);

create table public.exam_attempts (
  user_id uuid not null references auth.users(id) on delete cascade,
  track_id text not null,
  attempt_id text not null,
  attempt jsonb not null check (jsonb_typeof(attempt) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, track_id, attempt_id)
);

create table public.exam_weak_areas (
  user_id uuid not null references auth.users(id) on delete cascade,
  track_id text not null,
  weak_areas jsonb not null check (jsonb_typeof(weak_areas) = 'object'),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, track_id)
);

create table public.pyq_performance (
  user_id uuid not null references auth.users(id) on delete cascade,
  track_id text not null,
  performance jsonb not null check (jsonb_typeof(performance) = 'object'),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, track_id)
);

create table public.mock_results (
  user_id uuid not null references auth.users(id) on delete cascade,
  track_id text not null,
  mock_id text not null,
  result jsonb not null check (jsonb_typeof(result) = 'object'),
  completed_at timestamptz not null,
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, track_id, mock_id)
);

create table public.exam_hub_states (
  user_id uuid not null references auth.users(id) on delete cascade,
  track_id text not null,
  state jsonb not null check (jsonb_typeof(state) = 'object'),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0 check (revision >= 0),
  primary key (user_id, track_id)
);

create index generated_content_user_concept_idx on public.generated_content (user_id, concept_id);
create index generated_content_expiry_idx on public.generated_content (expires_at) where expires_at is not null;
create index daily_activity_user_date_desc_idx on public.daily_activity (user_id, activity_date desc);
create index ai_conversations_user_updated_desc_idx on public.ai_conversations (user_id, updated_at desc);
create index exam_attempts_user_track_created_desc_idx on public.exam_attempts (user_id, track_id, created_at desc);
create index mock_results_user_track_completed_desc_idx on public.mock_results (user_id, track_id, completed_at desc);

create or replace function public.set_row_updated_at_and_revision()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  new.revision = old.revision + 1;
  return new;
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'app_preferences', 'learner_profiles', 'learning_states',
    'learning_plans', 'generated_content', 'progress_states', 'quiz_attempts',
    'achievements', 'daily_activity', 'streak_states', 'ai_conversations',
    'ai_usage_records', 'exam_scopes', 'exam_profiles', 'exam_learner_profiles',
    'exam_plans', 'exam_attempts', 'exam_weak_areas', 'pyq_performance',
    'mock_results', 'exam_hub_states'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_row_updated_at_and_revision()',
      table_name || '_set_updated_at_and_revision', table_name
    );
  end loop;
end;
$$;

alter table public.profiles enable row level security;
alter table public.app_preferences enable row level security;
alter table public.learner_profiles enable row level security;
alter table public.learning_states enable row level security;
alter table public.learning_plans enable row level security;
alter table public.generated_content enable row level security;
alter table public.progress_states enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.achievements enable row level security;
alter table public.daily_activity enable row level security;
alter table public.streak_states enable row level security;
alter table public.ai_conversations enable row level security;
alter table public.ai_usage_records enable row level security;
alter table public.exam_scopes enable row level security;
alter table public.exam_profiles enable row level security;
alter table public.exam_learner_profiles enable row level security;
alter table public.exam_plans enable row level security;
alter table public.exam_attempts enable row level security;
alter table public.exam_weak_areas enable row level security;
alter table public.pyq_performance enable row level security;
alter table public.mock_results enable row level security;
alter table public.exam_hub_states enable row level security;

-- User-owned tables intentionally receive four explicit policies. The client
-- only ever authenticates with the anon key; service-role credentials are not
-- present in Flutter and are not needed to satisfy these policies.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'app_preferences', 'learner_profiles', 'learning_states', 'learning_plans',
    'generated_content', 'progress_states', 'quiz_attempts', 'achievements',
    'daily_activity', 'streak_states', 'ai_conversations', 'ai_usage_records',
    'exam_scopes', 'exam_profiles', 'exam_learner_profiles', 'exam_plans',
    'exam_attempts', 'exam_weak_areas', 'pyq_performance', 'mock_results',
    'exam_hub_states'
  ] loop
    execute format('create policy %I on public.%I for select using (auth.uid() = user_id)', table_name || '_select_own', table_name);
    execute format('create policy %I on public.%I for insert with check (auth.uid() = user_id)', table_name || '_insert_own', table_name);
    execute format('create policy %I on public.%I for update using (auth.uid() = user_id) with check (auth.uid() = user_id)', table_name || '_update_own', table_name);
    execute format('create policy %I on public.%I for delete using (auth.uid() = user_id)', table_name || '_delete_own', table_name);
  end loop;
end;
$$;

create policy profiles_select_own on public.profiles for select using (auth.uid() = id);
create policy profiles_insert_own on public.profiles for insert with check (auth.uid() = id);
create policy profiles_update_own on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
create policy profiles_delete_own on public.profiles for delete using (auth.uid() = id);
