-- =============================================================================
-- 0001_init.sql
-- Initial schema for AI Kitchen. Includes:
--   - Enums (sex, activity_level, focus_goal, meal_type, etc.)
--   - Core tables (profiles, foods, food_logs, recipes, recipe_ingredients,
--     cooking_sessions, ai_messages, weight_logs, activity_logs, nudges)
--   - Row-Level Security policies for every user-scoped table
--   - v_daily_intake view for fast Today-screen aggregation
--   - Trigram + helper indexes for food search
--
-- Conventions:
--   - All user-scoped tables have user_id uuid references auth.users(id)
--     ON DELETE CASCADE.
--   - All tables have created_at + updated_at managed by a single trigger.
--   - All micronutrients are nullable: USDA records may not have them.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "pg_trgm";    -- fuzzy food search
create extension if not exists "citext";     -- case-insensitive text

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.sex_enum as enum ('female', 'male', 'other');

create type public.activity_level_enum as enum (
  'mostly_sitting',     -- desk job, little walking
  'some_walking',       -- a fair bit of walking
  'on_feet_a_lot',      -- service / trades / parenting
  'works_out_most_days' -- 4+ training days/week
);

create type public.focus_goal_enum as enum (
  'lose_gentle',   -- ~10% deficit
  'lose_steady',   -- ~20% deficit
  'maintain',
  'build_gentle',  -- ~10% surplus
  'eat_better'     -- no deficit, focus on quality
);

create type public.nutrition_literacy_enum as enum (
  'beginner',
  'intermediate',
  'advanced'
);

create type public.subscription_tier_enum as enum (
  'free',
  'premium',
  'pro'
);

create type public.meal_type_enum as enum (
  'breakfast',
  'lunch',
  'dinner',
  'snack'
);

create type public.food_source_enum as enum (
  'usda',          -- USDA FoodData Central seed
  'openfoodfacts', -- OFF barcode lookup
  'user',          -- user-entered (incl. label scan)
  'ai'             -- AI-generated estimate
);

create type public.activity_source_enum as enum (
  'manual',
  'healthkit',
  'googlefit'
);

create type public.weight_source_enum as enum (
  'manual',
  'healthkit',
  'googlefit'
);

create type public.cooking_session_status_enum as enum (
  'active',
  'completed',
  'abandoned'
);

create type public.ai_message_role_enum as enum (
  'system',
  'user',
  'assistant',
  'tool'
);

create type public.nudge_kind_enum as enum (
  'low_fiber',
  'high_sodium',
  'low_protein',
  'low_micronutrient',
  'inactive_day',
  'balanced_day',
  'streak',
  'goal_progress',
  'general'
);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
-- Single shared trigger function to keep updated_at fresh.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- profiles
-- One row per auth user. Created by a trigger on auth.users insert.
-- ---------------------------------------------------------------------------
create table public.profiles (
  user_id              uuid primary key references auth.users(id) on delete cascade,
  display_name         text,
  sex                  public.sex_enum,
  dob                  date,
  height_cm            numeric(5,1),
  weight_kg            numeric(5,2),
  activity_level       public.activity_level_enum,
  focus_goal           public.focus_goal_enum,
  weight_goal_kg       numeric(5,2),

  -- Computed at onboarding from Mifflin-St Jeor + activity multiplier + focus_goal.
  kcal_goal            integer check (kcal_goal is null or kcal_goal between 800 and 6000),
  protein_g_goal       integer,
  carb_g_goal          integer,
  fat_g_goal           integer,
  fiber_g_goal         integer default 28,
  sodium_mg_cap        integer default 2300,
  sugar_g_cap          integer default 50,

  nutrition_literacy   public.nutrition_literacy_enum not null default 'beginner',
  subscription_tier    public.subscription_tier_enum not null default 'free',

  -- Usage counters reset by the monthly cron / RevenueCat webhook.
  voice_sessions_used_this_month  integer not null default 0,
  label_scans_used_this_month     integer not null default 0,
  usage_period_started_at         date not null default date_trunc('month', now())::date,

  onboarded_at         timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Auto-create a profile row when a user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- foods
-- Master food catalog. Seeded with USDA top items + OFF on-demand barcodes.
-- User-created foods carry owner_id; system foods have owner_id = null.
-- ---------------------------------------------------------------------------
create table public.foods (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid references auth.users(id) on delete cascade,
  source            public.food_source_enum not null,
  external_id       text,        -- USDA fdc_id, OFF barcode, etc.
  barcode           text,        -- UPC/EAN if known
  name              citext not null,
  brand             citext,
  serving_size_g    numeric(8,2),
  serving_label     text,        -- e.g. "1 cup", "2 tbsp"

  kcal_per_100g     numeric(7,2) not null,
  protein_g         numeric(7,2) not null default 0,
  carb_g            numeric(7,2) not null default 0,
  fat_g             numeric(7,2) not null default 0,

  fiber_g           numeric(7,2),
  sugar_g           numeric(7,2),
  sodium_mg         numeric(8,2),
  vit_c_mg          numeric(8,2),
  iron_mg           numeric(8,2),
  calcium_mg        numeric(8,2),
  potassium_mg      numeric(8,2),

  -- Plain-language one-liner for the food. Used by the AI for context, and
  -- optionally shown in the UI ("a creamy strained yogurt high in protein").
  blurb             text,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create trigger foods_set_updated_at
  before update on public.foods
  for each row execute function public.set_updated_at();

create index foods_owner_id_idx on public.foods (owner_id);
create index foods_barcode_idx on public.foods (barcode) where barcode is not null;
create index foods_name_trgm_idx on public.foods using gin (name gin_trgm_ops);
create index foods_brand_trgm_idx on public.foods using gin (brand gin_trgm_ops) where brand is not null;
create unique index foods_source_external_id_idx
  on public.foods (source, external_id)
  where external_id is not null;

-- ---------------------------------------------------------------------------
-- food_logs
-- A single eating event by a user.
-- ---------------------------------------------------------------------------
create table public.food_logs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  food_id       uuid not null references public.foods(id) on delete restrict,
  grams         numeric(8,2) not null check (grams > 0 and grams < 10000),
  meal_type     public.meal_type_enum not null default 'snack',
  logged_at     timestamptz not null default now(),
  source_note   text,    -- "from recipe: Chicken bowl" / "barcode scan" / etc.

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create trigger food_logs_set_updated_at
  before update on public.food_logs
  for each row execute function public.set_updated_at();

create index food_logs_user_id_logged_at_idx
  on public.food_logs (user_id, logged_at desc);

-- ---------------------------------------------------------------------------
-- recipes
-- Seeded recipes have owner_id = null. User-imported / generated have owner_id.
-- ---------------------------------------------------------------------------
create table public.recipes (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid references auth.users(id) on delete cascade,
  slug              text unique,
  title             text not null,
  description       text,
  servings          integer not null default 1 check (servings > 0),
  total_time_min    integer,
  hero_image_url    text,
  instructions      jsonb not null default '[]'::jsonb,
                    -- Array of { step: int, body: text, timer_seconds?: int }
  tags              text[] not null default array[]::text[],
                    -- e.g. {"beginner", "30-min", "high-protein"}
  published         boolean not null default false,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create trigger recipes_set_updated_at
  before update on public.recipes
  for each row execute function public.set_updated_at();

create index recipes_owner_id_idx on public.recipes (owner_id);
create index recipes_published_idx on public.recipes (published) where published = true;

-- ---------------------------------------------------------------------------
-- recipe_ingredients
-- Per-ingredient ties recipes -> foods with grams + substitution hints.
-- ---------------------------------------------------------------------------
create table public.recipe_ingredients (
  id                  uuid primary key default gen_random_uuid(),
  recipe_id           uuid not null references public.recipes(id) on delete cascade,
  food_id             uuid not null references public.foods(id) on delete restrict,
  grams               numeric(8,2) not null check (grams >= 0),
  optional            boolean not null default false,
  substitute_food_ids uuid[] not null default array[]::uuid[],
  display_order       integer not null default 0,
  note                text,

  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create trigger recipe_ingredients_set_updated_at
  before update on public.recipe_ingredients
  for each row execute function public.set_updated_at();

create index recipe_ingredients_recipe_id_idx
  on public.recipe_ingredients (recipe_id, display_order);

-- ---------------------------------------------------------------------------
-- cooking_sessions
-- One per "Cook with me" interaction. Holds the per-session adjusted recipe
-- state so the AI can read/write deterministically.
-- ---------------------------------------------------------------------------
create table public.cooking_sessions (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users(id) on delete cascade,
  recipe_id         uuid not null references public.recipes(id) on delete restrict,
  status            public.cooking_session_status_enum not null default 'active',

  -- Snapshot of {ingredient_id: grams} after any adjustments. Defaults to the
  -- recipe's grams at session start; updated by the adjust_ingredient tool.
  adjustments       jsonb not null default '{}'::jsonb,

  voice_turns_used  integer not null default 0,
  voice_seconds     integer not null default 0,

  final_kcal        integer,
  final_protein_g   numeric(6,1),
  final_carb_g      numeric(6,1),
  final_fat_g       numeric(6,1),

  started_at        timestamptz not null default now(),
  ended_at          timestamptz,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create trigger cooking_sessions_set_updated_at
  before update on public.cooking_sessions
  for each row execute function public.set_updated_at();

create index cooking_sessions_user_id_started_at_idx
  on public.cooking_sessions (user_id, started_at desc);

-- ---------------------------------------------------------------------------
-- ai_messages
-- Per-turn conversation history for cooking sessions (and future Ask-anything).
-- Audio is stored in Supabase Storage; only the URL is kept here.
-- ---------------------------------------------------------------------------
create table public.ai_messages (
  id              uuid primary key default gen_random_uuid(),
  session_id      uuid not null references public.cooking_sessions(id) on delete cascade,
  role            public.ai_message_role_enum not null,
  content         text,
  tool_calls      jsonb,
  tool_call_id    text,
  audio_path      text,
  created_at      timestamptz not null default now()
);

create index ai_messages_session_id_created_at_idx
  on public.ai_messages (session_id, created_at);

-- ---------------------------------------------------------------------------
-- weight_logs
-- ---------------------------------------------------------------------------
create table public.weight_logs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  weight_kg     numeric(5,2) not null check (weight_kg > 20 and weight_kg < 400),
  recorded_at   timestamptz not null default now(),
  source        public.weight_source_enum not null default 'manual',

  created_at    timestamptz not null default now()
);

create index weight_logs_user_id_recorded_at_idx
  on public.weight_logs (user_id, recorded_at desc);

-- ---------------------------------------------------------------------------
-- activity_logs
-- ---------------------------------------------------------------------------
create table public.activity_logs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  kind          text not null,      -- "walk", "run", "gym", "yoga", custom
  duration_min  integer not null check (duration_min > 0),
  kcal_burned   integer not null check (kcal_burned >= 0),
  steps         integer,
  source        public.activity_source_enum not null default 'manual',
  recorded_at   timestamptz not null default now(),

  created_at    timestamptz not null default now()
);

create index activity_logs_user_id_recorded_at_idx
  on public.activity_logs (user_id, recorded_at desc);

-- ---------------------------------------------------------------------------
-- nudges
-- AI-generated daily nudges. Cron-populated by the nudges-daily Edge Function.
-- ---------------------------------------------------------------------------
create table public.nudges (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  kind            public.nudge_kind_enum not null,
  title           text not null,
  body            text not null,
  for_date        date not null default current_date,
  scheduled_for   timestamptz,
  delivered_at    timestamptz,
  dismissed_at    timestamptz,
  acted_on        boolean not null default false,

  created_at      timestamptz not null default now()
);

create index nudges_user_id_for_date_idx on public.nudges (user_id, for_date desc);
create index nudges_user_id_dismissed_idx
  on public.nudges (user_id, dismissed_at) where dismissed_at is null;

-- ---------------------------------------------------------------------------
-- v_daily_intake
-- One row per (user, day) with totals computed from food_logs.
-- The Today screen queries this view for the current date.
-- ---------------------------------------------------------------------------
create or replace view public.v_daily_intake
with (security_invoker = true)
as
select
  fl.user_id,
  (fl.logged_at at time zone 'UTC')::date as for_date,
  count(*)::integer as entries,
  round(sum(f.kcal_per_100g * fl.grams / 100.0))::integer as kcal,
  round(sum(f.protein_g    * fl.grams / 100.0), 1)        as protein_g,
  round(sum(f.carb_g       * fl.grams / 100.0), 1)        as carb_g,
  round(sum(f.fat_g        * fl.grams / 100.0), 1)        as fat_g,
  round(sum(coalesce(f.fiber_g,    0) * fl.grams / 100.0), 1) as fiber_g,
  round(sum(coalesce(f.sugar_g,    0) * fl.grams / 100.0), 1) as sugar_g,
  round(sum(coalesce(f.sodium_mg,  0) * fl.grams / 100.0), 0) as sodium_mg
from public.food_logs fl
join public.foods f on f.id = fl.food_id
group by fl.user_id, (fl.logged_at at time zone 'UTC')::date;

-- ---------------------------------------------------------------------------
-- Row-Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles            enable row level security;
alter table public.foods               enable row level security;
alter table public.food_logs           enable row level security;
alter table public.recipes             enable row level security;
alter table public.recipe_ingredients  enable row level security;
alter table public.cooking_sessions    enable row level security;
alter table public.ai_messages         enable row level security;
alter table public.weight_logs         enable row level security;
alter table public.activity_logs       enable row level security;
alter table public.nudges              enable row level security;

-- profiles: a user can read and update only their own row.
create policy profiles_select_own on public.profiles
  for select using (auth.uid() = user_id);
create policy profiles_update_own on public.profiles
  for update using (auth.uid() = user_id);
-- Insert is handled by the on_auth_user_created trigger (security definer).

-- foods: system rows (owner_id IS NULL) are readable by all. Users can CRUD
-- their own custom foods.
create policy foods_select_system_or_own on public.foods
  for select using (owner_id is null or auth.uid() = owner_id);
create policy foods_insert_own on public.foods
  for insert with check (auth.uid() = owner_id);
create policy foods_update_own on public.foods
  for update using (auth.uid() = owner_id);
create policy foods_delete_own on public.foods
  for delete using (auth.uid() = owner_id);

-- food_logs: only own.
create policy food_logs_select_own on public.food_logs
  for select using (auth.uid() = user_id);
create policy food_logs_insert_own on public.food_logs
  for insert with check (auth.uid() = user_id);
create policy food_logs_update_own on public.food_logs
  for update using (auth.uid() = user_id);
create policy food_logs_delete_own on public.food_logs
  for delete using (auth.uid() = user_id);

-- recipes: published system recipes (owner_id IS NULL AND published) readable
-- by anyone. Owner CRUD on their own recipes.
create policy recipes_select_published_or_own on public.recipes
  for select using (
    (owner_id is null and published = true)
    or auth.uid() = owner_id
  );
create policy recipes_insert_own on public.recipes
  for insert with check (auth.uid() = owner_id);
create policy recipes_update_own on public.recipes
  for update using (auth.uid() = owner_id);
create policy recipes_delete_own on public.recipes
  for delete using (auth.uid() = owner_id);

-- recipe_ingredients: readable iff parent recipe readable; writable iff owner.
create policy recipe_ingredients_select on public.recipe_ingredients
  for select using (
    exists (
      select 1 from public.recipes r
      where r.id = recipe_ingredients.recipe_id
        and ((r.owner_id is null and r.published) or auth.uid() = r.owner_id)
    )
  );
create policy recipe_ingredients_modify_own on public.recipe_ingredients
  for all using (
    exists (
      select 1 from public.recipes r
      where r.id = recipe_ingredients.recipe_id
        and auth.uid() = r.owner_id
    )
  )
  with check (
    exists (
      select 1 from public.recipes r
      where r.id = recipe_ingredients.recipe_id
        and auth.uid() = r.owner_id
    )
  );

-- cooking_sessions: only own.
create policy cooking_sessions_all_own on public.cooking_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ai_messages: only if parent session is owned.
create policy ai_messages_select_own on public.ai_messages
  for select using (
    exists (
      select 1 from public.cooking_sessions s
      where s.id = ai_messages.session_id and s.user_id = auth.uid()
    )
  );
-- Inserts to ai_messages are intentionally not granted to anon/authed clients;
-- only the voice-turn Edge Function (service role) writes here.

-- weight_logs: only own.
create policy weight_logs_all_own on public.weight_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- activity_logs: only own.
create policy activity_logs_all_own on public.activity_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- nudges: read + dismiss own. Inserts come from the daily cron Edge Function.
create policy nudges_select_own on public.nudges
  for select using (auth.uid() = user_id);
create policy nudges_update_own on public.nudges
  for update using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
-- The Supabase default roles (authenticated, anon, service_role) inherit
-- usage on the public schema. Explicit grants for clarity:
grant usage on schema public to authenticated, anon, service_role;
grant select on public.v_daily_intake to authenticated, service_role;
