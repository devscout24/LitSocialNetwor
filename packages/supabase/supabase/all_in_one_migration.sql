-- =============================================================================
-- LIT Social — ALL-IN-ONE Migration Bundle (for Supabase Studio SQL Editor)
-- Generated from packages/supabase/supabase/migrations/ in exact order:
--   1. 0001_init_profiles_and_storage.sql
--   2. 20261124000001_fix_0001_and_extensions.sql
--   3. 20261124000002_social_core.sql
--   4. 20261124000003_events.sql
--   5. 20261124000004_ticketing.sql
--   6. 20261124000005_notifications_support.sql
--   7. 20261124000006_rls_and_grants.sql
--   8. 20261124000007_rpc_functions.sql
--   9. 20261124000008_cron_jobs.sql
--
-- Safe to run on a fresh self-hosted Supabase instance (or one where 0001
-- already ran). Re-runnable and includes all tables, triggers, RLS policies,
-- column-level grants, RPC functions, and pg_cron maintenance jobs.
-- =============================================================================

-- #############################################################################
-- FILE: 0001_init_profiles_and_storage.sql
-- #############################################################################

-- =====================================================================
-- LIT Social — Migration 0001: profiles + storage
-- Target: self-hosted Supabase (PostgreSQL 15+) on Nexus's VPS (Dokploy).
-- Run in Supabase Studio → SQL Editor, in filename order (this file first).
-- Safe to run once on a fresh instance; re-runnable guards included where
-- practical. No Supabase Cloud-only features are used.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Helper: keep updated_at current
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- profiles — one row per auth user (mirrors the approved Profile /
-- Edit Profile screens: username, display name, bio, avatar, website,
-- location)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  username     text unique,
  display_name text,
  bio          text,
  avatar_url   text,
  website      text,
  location     text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint profiles_username_shape
    check (username is null or username ~ '^[a-z0-9_.]{3,30}$')
);

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Auto-create a profile when a user signs up. Username / display name /
-- avatar come from the metadata the app passes to supabase.auth.signUp.
-- If the requested username is already taken, the profile is created
-- without it (the app prompts the user to pick another) instead of
-- failing the sign-up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    insert into public.profiles (id, username, display_name, avatar_url)
    values (
      new.id,
      nullif(lower(new.raw_user_meta_data ->> 'username'), ''),
      nullif(new.raw_user_meta_data ->> 'display_name', ''),
      nullif(new.raw_user_meta_data ->> 'avatar_url', '')
    )
    on conflict (id) do nothing;
  exception when unique_violation then
    insert into public.profiles (id, display_name, avatar_url)
    values (
      new.id,
      nullif(new.raw_user_meta_data ->> 'display_name', ''),
      nullif(new.raw_user_meta_data ->> 'avatar_url', '')
    )
    on conflict (id) do nothing;
  end;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- RLS — profiles
-- Anyone can read profiles (public profile screens, Discover lists).
-- A user can insert / update only their own row. No client delete.
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;

drop policy if exists "profiles are readable by everyone" on public.profiles;
create policy "profiles are readable by everyone"
  on public.profiles for select
  using (true);

drop policy if exists "users can insert their own profile" on public.profiles;
create policy "users can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "users can update their own profile" on public.profiles;
create policy "users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

grant select on public.profiles to anon, authenticated;
grant insert, update on public.profiles to authenticated;
grant all on public.profiles to service_role;

-- ---------------------------------------------------------------------
-- Storage buckets (all public-read for MVP, matching the design's
-- public feed / discover / event screens):
--   avatars — profile pictures      posts   — post photos / videos
--   stories — flame story media     events  — event cover / gallery
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('posts',   'posts',   true),
  ('stories', 'stories', true),
  ('events',  'events',  true)
on conflict (id) do nothing;

-- Storage policies: anyone can read objects in these buckets; a signed-in
-- user can upload / update / delete only inside a folder named with
-- their own user id:  <bucket>/<auth.uid()>/file.jpg
drop policy if exists "lit buckets are publicly readable" on storage.objects;
create policy "lit buckets are publicly readable"
  on storage.objects for select
  using (bucket_id in ('avatars', 'posts', 'stories', 'events'));

drop policy if exists "users can upload to their own folder" on storage.objects;
create policy "users can upload to their own folder"
  on storage.objects for insert
  with check (
    bucket_id in ('avatars', 'posts', 'stories', 'events')
    and auth.role() = 'authenticated'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users can update their own objects" on storage.objects;
create policy "users can update their own objects"
  on storage.objects for update
  using (
    bucket_id in ('avatars', 'posts', 'stories', 'events')
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id in ('avatars', 'posts', 'stories', 'events')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users can delete their own objects" on storage.objects;
create policy "users can delete their own objects"
  on storage.objects for delete
  using (
    bucket_id in ('avatars', 'posts', 'stories', 'events')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- #############################################################################
-- FILE: 20261124000001_fix_0001_and_extensions.sql
-- #############################################################################

-- =============================================================================
-- LIT Social — Migration 20261124000001: Fix 0001 & Extensions
-- Target: Self-hosted Supabase (PostgreSQL 15+)
-- Fixes against 0001_init_profiles_and_storage.sql (without editing 0001):
--   1. Creates `extensions` schema and installs `pgcrypto` and `pg_trgm` into
--      `extensions` (moving `pgcrypto` out of `public` if 0001 installed it there).
--   2. Hardens `public.set_updated_at()` with `set search_path = ''` and revokes
--      direct RPC execution from `public`, `anon`, and `authenticated`.
--   3. Fixes `public.handle_new_user()` so it catches BOTH `unique_violation`
--      AND `check_violation` (e.g. invalid username shape like "Emma Wilson"),
--      inserting the profile with `username = null` instead of failing sign-up.
--      Also sets `search_path = ''` and revokes RPC execution.
--   4. Sets `file_size_limit` and `allowed_mime_types` on all 4 storage buckets
--      (`avatars`, `posts`, `stories`, `events`).
--   5. Makes the `stories` bucket PRIVATE (`public = false`) so expired stories
--      and private-account stories are never publicly accessible forever, and
--      updates `storage.objects` policies accordingly.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Extensions Schema (`extensions.pgcrypto`, `extensions.pg_trgm`)
-- -----------------------------------------------------------------------------
create schema if not exists extensions;
grant usage on schema extensions to public, anon, authenticated, service_role;

-- Move `pgcrypto` to `extensions` if 0001 created it in `public`, or install in `extensions`
do $$
begin
  if exists (
    select 1
      from pg_extension e
      join pg_namespace n on n.oid = e.extnamespace
     where e.extname = 'pgcrypto'
       and n.nspname = 'public'
  ) then
    alter extension pgcrypto set schema extensions;
  else
    create extension if not exists pgcrypto with schema extensions;
  end if;

  if exists (
    select 1
      from pg_extension e
      join pg_namespace n on n.oid = e.extnamespace
     where e.extname = 'pg_trgm'
       and n.nspname = 'public'
  ) then
    alter extension pg_trgm set schema extensions;
  else
    create extension if not exists pg_trgm with schema extensions;
  end if;
end
$$;

-- -----------------------------------------------------------------------------
-- 2. Harden `public.set_updated_at()` (from 0001)
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = pg_catalog.now();
  return new;
end;
$$;

revoke all on function public.set_updated_at() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3. Fix `public.handle_new_user()` to catch `check_violation` as well as
--    `unique_violation`, use `set search_path = ''`, and revoke RPC execution
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_username text;
  v_display_name text;
  v_avatar_url text;
begin
  v_username := nullif(pg_catalog.lower(pg_catalog.btrim(new.raw_user_meta_data ->> 'username')), '');
  v_display_name := coalesce(
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'name'), '')
  );
  v_avatar_url := nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'avatar_url'), '');

  -- Truncate display_name if metadata exceeds 80 chars so profile creation never fails
  if v_display_name is not null and pg_catalog.char_length(v_display_name) > 80 then
    v_display_name := pg_catalog.substr(v_display_name, 1, 80);
  end if;

  begin
    insert into public.profiles (id, username, display_name, avatar_url)
    values (new.id, v_username, v_display_name, v_avatar_url)
    on conflict (id) do nothing;
  exception
    when unique_violation or check_violation then
      insert into public.profiles (id, username, display_name, avatar_url)
      values (new.id, null, v_display_name, v_avatar_url)
      on conflict (id) do nothing;
  end;

  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 4. Storage Buckets: set `file_size_limit`, `allowed_mime_types`, and make
--    `stories` bucket PRIVATE (`public = false`)
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'avatars',
    'avatars',
    true,
    5242880, -- 5 MB
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'posts',
    'posts',
    true,
    52428800, -- 50 MB
    array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime']
  ),
  (
    'stories',
    'stories',
    false, -- PRIVATE: served via short-lived signed URLs
    31457280, -- 30 MB
    array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime']
  ),
  (
    'events',
    'events',
    true,
    10485760, -- 10 MB
    array['image/jpeg', 'image/png', 'image/webp']
  )
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- -----------------------------------------------------------------------------
-- 5. Update Storage Policies so `stories` is NOT publicly readable
-- -----------------------------------------------------------------------------
drop policy if exists "lit buckets are publicly readable" on storage.objects;
drop policy if exists "Public read access for app media buckets" on storage.objects;
drop policy if exists "public buckets are publicly readable" on storage.objects;

create policy "public buckets are publicly readable"
  on storage.objects for select
  using (bucket_id in ('avatars', 'posts', 'events'));

-- Owner can always read their own story objects; follower read access for active
-- stories is added in 20261124000006_rls_and_grants.sql once `public.stories`
-- and `public.can_view_profile_content()` exist.
drop policy if exists "story authors can read their own story objects" on storage.objects;
create policy "story authors can read their own story objects"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'stories'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- #############################################################################
-- FILE: 20261124000002_social_core.sql
-- #############################################################################

-- =============================================================================
-- LIT Social — Migration 20261124000002: Social Core
-- Target: Self-hosted Supabase (PostgreSQL 15+)
-- Contents:
--   1. `public.profiles` extensions (privacy flags, socials, counters, soft-delete,
--      data validation constraints, trigram indexes using `extensions.gin_trgm_ops`).
--      No `two_factor_*` columns (2FA uses Supabase Auth MFA `auth.mfa_factors`).
--   2. `public.user_settings` (notification preferences only; no duplicate privacy/2FA).
--   3. `public.user_blocks` and `public.user_mutes` (block trigger removes vibes both ways).
--   4. `public.vibes` (follow graph; BEFORE INSERT trigger enforces `pending` on private
--      accounts and rejects blocked pairs; incremental `+1/-1` counter trigger).
--   5. `public.locations` and `public.hashtags` (lat/lng range checks, trigram indexes).
--   6. `public.posts`, `public.post_media`, `public.post_tags`, `public.post_hashtags`,
--      `public.post_likes`, `public.post_comments`, `public.post_bookmarks`,
--      `public.post_shares` (with unique `(post_id, user_id, channel)`, automatic
--      caption hashtag parser trigger, and full `location_id` + archive/hide counter sync).
--   7. `public.stories` and `public.story_views` (incremental flame engagement trigger,
--      expiry validation preventing views/likes on expired stories).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Extend `public.profiles`
-- -----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists twitter_handle text,
  add column if not exists instagram_handle text,
  add column if not exists is_private boolean not null default false,
  add column if not exists show_activity_status boolean not null default true,
  add column if not exists is_verified boolean not null default false,
  add column if not exists posts_count integer not null default 0,
  add column if not exists vibers_count integer not null default 0,
  add column if not exists vibing_count integer not null default 0,
  add column if not exists last_active_at timestamptz default now(),
  add column if not exists deleted_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_bio_length'
  ) then
    alter table public.profiles
      add constraint profiles_bio_length
      check (bio is null or char_length(bio) <= 150);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'profiles_display_name_length'
  ) then
    alter table public.profiles
      add constraint profiles_display_name_length
      check (display_name is null or char_length(display_name) <= 80);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'profiles_website_url_format'
  ) then
    alter table public.profiles
      add constraint profiles_website_url_format
      check (website is null or website ~* '^https?://[^\s/$.?#].[^\s]*$');
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'profiles_twitter_handle_length'
  ) then
    alter table public.profiles
      add constraint profiles_twitter_handle_length
      check (twitter_handle is null or char_length(twitter_handle) <= 50);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'profiles_instagram_handle_length'
  ) then
    alter table public.profiles
      add constraint profiles_instagram_handle_length
      check (instagram_handle is null or char_length(instagram_handle) <= 50);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'profiles_counts_non_negative'
  ) then
    alter table public.profiles
      add constraint profiles_counts_non_negative
      check (posts_count >= 0 and vibers_count >= 0 and vibing_count >= 0);
  end if;
end
$$;

create index if not exists idx_profiles_username_trgm
  on public.profiles using gin (username extensions.gin_trgm_ops);
create index if not exists idx_profiles_display_name_trgm
  on public.profiles using gin (display_name extensions.gin_trgm_ops);
create index if not exists idx_profiles_created_cursor
  on public.profiles (created_at desc, id desc);

-- -----------------------------------------------------------------------------
-- 2. User Settings (`public.user_settings`) — Notification Preferences Only
--    (Privacy flags live on `public.profiles`; 2FA lives in Supabase Auth MFA)
-- -----------------------------------------------------------------------------
create table if not exists public.user_settings (
  user_id             uuid primary key references public.profiles (id) on delete cascade,
  push_notifications  boolean not null default true,
  email_notifications boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

drop trigger if exists user_settings_set_updated_at on public.user_settings;
create trigger user_settings_set_updated_at
  before update on public.user_settings
  for each row execute function public.set_updated_at();

create or replace function public.handle_new_profile_settings()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

revoke all on function public.handle_new_profile_settings() from public, anon, authenticated;

drop trigger if exists on_profile_created_settings on public.profiles;
create trigger on_profile_created_settings
  after insert on public.profiles
  for each row execute function public.handle_new_profile_settings();

insert into public.user_settings (user_id)
select id from public.profiles
on conflict (user_id) do nothing;

-- -----------------------------------------------------------------------------
-- 3. Blocks (`public.user_blocks`) & Mutes (`public.user_mutes`)
-- -----------------------------------------------------------------------------
create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self_block check (blocker_id <> blocked_id)
);

create index if not exists idx_user_blocks_blocked_id
  on public.user_blocks (blocked_id);

create table if not exists public.user_mutes (
  muter_id   uuid not null references public.profiles (id) on delete cascade,
  muted_id   uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (muter_id, muted_id),
  constraint user_mutes_no_self_mute check (muter_id <> muted_id)
);

create index if not exists idx_user_mutes_muted_id
  on public.user_mutes (muted_id);

-- Helper: true if either user has blocked the other
create or replace function public.is_blocked_between(p_user_a uuid, p_user_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_user_a is null or p_user_b is null then false
    else exists (
      select 1
        from public.user_blocks b
       where (b.blocker_id = p_user_a and b.blocked_id = p_user_b)
          or (b.blocker_id = p_user_b and b.blocked_id = p_user_a)
    )
  end;
$$;

revoke all on function public.is_blocked_between(uuid, uuid) from public;
grant execute on function public.is_blocked_between(uuid, uuid) to anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4. Vibe / Follow System (`public.vibes`)
--    - `follower_id` = user who is Vibing (following)
--    - `following_id` = user who gains a Viber (follower)
-- -----------------------------------------------------------------------------
create table if not exists public.vibes (
  id           uuid primary key default gen_random_uuid(),
  follower_id  uuid not null references public.profiles (id) on delete cascade,
  following_id uuid not null references public.profiles (id) on delete cascade,
  status       text not null default 'accepted'
               check (status in ('pending', 'accepted')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint vibes_no_self_follow check (follower_id <> following_id),
  constraint vibes_unique_pair unique (follower_id, following_id)
);

create index if not exists idx_vibes_follower_cursor
  on public.vibes (follower_id, status, created_at desc, id desc);
create index if not exists idx_vibes_following_cursor
  on public.vibes (following_id, status, created_at desc, id desc);

drop trigger if exists vibes_set_updated_at on public.vibes;
create trigger vibes_set_updated_at
  before update on public.vibes
  for each row execute function public.set_updated_at();

-- BEFORE INSERT trigger on `public.vibes`:
--   1. Rejects follow if either user blocked the other or target is deleted.
--   2. Forces `status = 'pending'` if target `is_private = true`, else `'accepted'`.
--      Clients can never override initial status.
create or replace function public.enforce_vibe_initial_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target_private boolean;
  v_target_deleted timestamptz;
begin
  if public.is_blocked_between(new.follower_id, new.following_id) then
    raise exception 'Cannot vibe with this user due to a block.';
  end if;

  select p.is_private, p.deleted_at
    into v_target_private, v_target_deleted
    from public.profiles p
   where p.id = new.following_id;

  if not found or v_target_deleted is not null then
    raise exception 'Target profile is not available.';
  end if;

  new.status := case when v_target_private then 'pending' else 'accepted' end;
  return new;
end;
$$;

revoke all on function public.enforce_vibe_initial_status() from public, anon, authenticated;

drop trigger if exists before_vibes_insert_status on public.vibes;
create trigger before_vibes_insert_status
  before insert on public.vibes
  for each row execute function public.enforce_vibe_initial_status();

-- AFTER INSERT OR UPDATE OR DELETE trigger on `public.vibes`:
-- Incrementally maintains `vibing_count` and `vibers_count` on `public.profiles`.
create or replace function public.sync_profile_vibe_counts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (tg_op = 'INSERT' and new.status = 'accepted') then
    update public.profiles set vibing_count = vibing_count + 1 where id = new.follower_id;
    update public.profiles set vibers_count = vibers_count + 1 where id = new.following_id;
  elsif (tg_op = 'DELETE' and old.status = 'accepted') then
    update public.profiles set vibing_count = greatest(0, vibing_count - 1) where id = old.follower_id;
    update public.profiles set vibers_count = greatest(0, vibers_count - 1) where id = old.following_id;
  elsif (tg_op = 'UPDATE' and old.status <> new.status) then
    if (new.status = 'accepted') then
      update public.profiles set vibing_count = vibing_count + 1 where id = new.follower_id;
      update public.profiles set vibers_count = vibers_count + 1 where id = new.following_id;
    elsif (old.status = 'accepted') then
      update public.profiles set vibing_count = greatest(0, vibing_count - 1) where id = new.follower_id;
      update public.profiles set vibers_count = greatest(0, vibers_count - 1) where id = new.following_id;
    end if;
  end if;
  return coalesce(new, old);
end;
$$;

revoke all on function public.sync_profile_vibe_counts() from public, anon, authenticated;

drop trigger if exists on_vibes_count_change on public.vibes;
create trigger on_vibes_count_change
  after insert or update or delete on public.vibes
  for each row execute function public.sync_profile_vibe_counts();

-- Block trigger: inserting a block removes vibes in BOTH directions
create or replace function public.handle_user_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.vibes
   where (follower_id = new.blocker_id and following_id = new.blocked_id)
      or (follower_id = new.blocked_id and following_id = new.blocker_id);
  return new;
end;
$$;

revoke all on function public.handle_user_block() from public, anon, authenticated;

drop trigger if exists on_user_block_remove_vibes on public.user_blocks;
create trigger on_user_block_remove_vibes
  after insert on public.user_blocks
  for each row execute function public.handle_user_block();

-- -----------------------------------------------------------------------------
-- 5. Locations (`public.locations`) & Hashtags (`public.hashtags`)
-- -----------------------------------------------------------------------------
create table if not exists public.locations (
  id             uuid primary key default gen_random_uuid(),
  name           text not null
                 check (char_length(btrim(name)) between 1 and 120),
  address        text check (address is null or char_length(address) <= 250),
  city           text check (city is null or char_length(city) <= 100),
  country        text check (country is null or char_length(country) <= 100),
  latitude       double precision
                 check (latitude is null or (latitude between -90 and 90)),
  longitude      double precision
                 check (longitude is null or (longitude between -180 and 180)),
  checkins_count integer not null default 0
                 check (checkins_count >= 0),
  created_at     timestamptz not null default now(),
  constraint locations_name_city_unique unique (name, city)
);

create index if not exists idx_locations_name_trgm
  on public.locations using gin (name extensions.gin_trgm_ops);
create index if not exists idx_locations_checkins_cursor
  on public.locations (checkins_count desc, id desc);

create table if not exists public.hashtags (
  id           uuid primary key default gen_random_uuid(),
  tag          text not null unique
               check (tag ~ '^[a-z0-9_]{1,64}$'),
  display_tag  text not null
               check (display_tag ~ '^#[A-Za-z0-9_]{1,64}$'),
  usage_count  integer not null default 0
               check (usage_count >= 0),
  is_trending  boolean not null default false,
  last_used_at timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

create index if not exists idx_hashtags_trending_cursor
  on public.hashtags (is_trending desc, usage_count desc, id desc);
create index if not exists idx_hashtags_tag_trgm
  on public.hashtags using gin (tag extensions.gin_trgm_ops);

-- -----------------------------------------------------------------------------
-- 6. Posts (`public.posts`) & Related Social Tables
-- -----------------------------------------------------------------------------
create table if not exists public.posts (
  id              uuid primary key default gen_random_uuid(),
  author_id       uuid not null references public.profiles (id) on delete cascade,
  caption         text check (caption is null or char_length(caption) <= 2200),
  event_id        uuid, -- FK to `public.events` added in 20261124000003_events.sql
  location_id     uuid references public.locations (id) on delete set null,
  location_name   text check (location_name is null or char_length(location_name) <= 120),
  likes_count     integer not null default 0 check (likes_count >= 0),
  comments_count  integer not null default 0 check (comments_count >= 0),
  shares_count    integer not null default 0 check (shares_count >= 0),
  bookmarks_count integer not null default 0 check (bookmarks_count >= 0),
  is_archived     boolean not null default false,
  is_hidden       boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_posts_author_cursor
  on public.posts (author_id, created_at desc, id desc);
create index if not exists idx_posts_feed_cursor
  on public.posts (created_at desc, id desc)
  where is_archived = false and is_hidden = false;
create index if not exists idx_posts_location_id
  on public.posts (location_id);

drop trigger if exists posts_set_updated_at on public.posts;
create trigger posts_set_updated_at
  before update on public.posts
  for each row execute function public.set_updated_at();

-- Maintain `profiles.posts_count` and `locations.checkins_count` across INSERT,
-- DELETE, and UPDATE (including changes to `location_id`, `is_archived`, `is_hidden`).
create or replace function public.sync_profile_posts_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_active boolean := false;
  v_new_active boolean := false;
begin
  if (tg_op = 'INSERT') then
    v_new_active := (not new.is_archived and not new.is_hidden);
    if v_new_active then
      update public.profiles set posts_count = posts_count + 1 where id = new.author_id;
      if new.location_id is not null then
        update public.locations set checkins_count = checkins_count + 1 where id = new.location_id;
      end if;
    end if;
    return new;
  elsif (tg_op = 'DELETE') then
    v_old_active := (not old.is_archived and not old.is_hidden);
    if v_old_active then
      update public.profiles set posts_count = greatest(0, posts_count - 1) where id = old.author_id;
      if old.location_id is not null then
        update public.locations set checkins_count = greatest(0, checkins_count - 1) where id = old.location_id;
      end if;
    end if;
    return old;
  elsif (tg_op = 'UPDATE') then
    v_old_active := (not old.is_archived and not old.is_hidden);
    v_new_active := (not new.is_archived and not new.is_hidden);

    if v_old_active and not v_new_active then
      update public.profiles set posts_count = greatest(0, posts_count - 1) where id = old.author_id;
      if old.location_id is not null then
        update public.locations set checkins_count = greatest(0, checkins_count - 1) where id = old.location_id;
      end if;
    elsif not v_old_active and v_new_active then
      update public.profiles set posts_count = posts_count + 1 where id = new.author_id;
      if new.location_id is not null then
        update public.locations set checkins_count = checkins_count + 1 where id = new.location_id;
      end if;
    elsif v_old_active and v_new_active then
      if old.location_id is distinct from new.location_id then
        if old.location_id is not null then
          update public.locations set checkins_count = greatest(0, checkins_count - 1) where id = old.location_id;
        end if;
        if new.location_id is not null then
          update public.locations set checkins_count = checkins_count + 1 where id = new.location_id;
        end if;
      end if;
    end if;
    return new;
  end if;
  return null;
end;
$$;

revoke all on function public.sync_profile_posts_count() from public, anon, authenticated;

drop trigger if exists on_posts_count_change on public.posts;
create trigger on_posts_count_change
  after insert or update of is_archived, is_hidden, location_id or delete on public.posts
  for each row execute function public.sync_profile_posts_count();

-- Post Media (`public.post_media`)
create table if not exists public.post_media (
  id               uuid primary key default gen_random_uuid(),
  post_id          uuid not null references public.posts (id) on delete cascade,
  media_url        text not null,
  storage_path     text,
  thumbnail_url    text,
  media_type       text not null default 'image'
                   check (media_type in ('image', 'video')),
  width            integer check (width is null or width > 0),
  height           integer check (height is null or height > 0),
  duration_seconds numeric(6,2) check (duration_seconds is null or duration_seconds >= 0),
  crop_metadata    jsonb,
  sort_order       smallint not null default 0,
  created_at       timestamptz not null default now()
);

create index if not exists idx_post_media_post_sort
  on public.post_media (post_id, sort_order asc);

-- Post Tags (`public.post_tags`)
create table if not exists public.post_tags (
  id             uuid primary key default gen_random_uuid(),
  post_id        uuid not null references public.posts (id) on delete cascade,
  tagged_user_id uuid not null references public.profiles (id) on delete cascade,
  position_x     double precision
                 check (position_x is null or (position_x between 0 and 1)),
  position_y     double precision
                 check (position_y is null or (position_y between 0 and 1)),
  created_at     timestamptz not null default now(),
  constraint post_tags_unique unique (post_id, tagged_user_id)
);

create index if not exists idx_post_tags_post_id
  on public.post_tags (post_id);
create index if not exists idx_post_tags_tagged_user_cursor
  on public.post_tags (tagged_user_id, created_at desc, id desc);

-- Prevent tagging when a block exists between post author and tagged user
create or replace function public.enforce_post_tag_not_blocked()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author_id uuid;
begin
  select p.author_id into v_author_id
    from public.posts p
   where p.id = new.post_id;

  if v_author_id is null then
    raise exception 'Post not found.';
  end if;

  if public.is_blocked_between(v_author_id, new.tagged_user_id) then
    raise exception 'Cannot tag a user when a block exists.';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_post_tag_not_blocked() from public, anon, authenticated;

drop trigger if exists before_post_tags_check_block on public.post_tags;
create trigger before_post_tags_check_block
  before insert or update on public.post_tags
  for each row execute function public.enforce_post_tag_not_blocked();

-- Post <-> Hashtags join table (`public.post_hashtags`)
create table if not exists public.post_hashtags (
  post_id    uuid not null references public.posts (id) on delete cascade,
  hashtag_id uuid not null references public.hashtags (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, hashtag_id)
);

create index if not exists idx_post_hashtags_hashtag_cursor
  on public.post_hashtags (hashtag_id, created_at desc, post_id desc);

create or replace function public.sync_hashtag_usage_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (tg_op = 'INSERT') then
    update public.hashtags
       set usage_count  = usage_count + 1,
           last_used_at = pg_catalog.now()
     where id = new.hashtag_id;
  elsif (tg_op = 'DELETE') then
    update public.hashtags
       set usage_count = greatest(0, usage_count - 1)
     where id = old.hashtag_id;
  end if;
  return coalesce(new, old);
end;
$$;

revoke all on function public.sync_hashtag_usage_count() from public, anon, authenticated;

drop trigger if exists on_post_hashtags_change on public.post_hashtags;
create trigger on_post_hashtags_change
  after insert or delete on public.post_hashtags
  for each row execute function public.sync_hashtag_usage_count();

-- Server-side trigger on `public.posts` that parses `#hashtags` from `caption`
-- so clients never write to `public.hashtags` or `public.post_hashtags` directly.
create or replace function public.sync_post_hashtags_from_caption()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_match text[];
  v_raw_tag text;
  v_norm_tag text;
  v_hashtag_id uuid;
  v_seen_ids uuid[] := '{}';
begin
  if (tg_op = 'UPDATE') then
    delete from public.post_hashtags where post_id = new.id;
  end if;

  if new.caption is not null and not new.is_hidden then
    for v_match in
      select pg_catalog.regexp_matches(new.caption, '#([A-Za-z0-9_]{1,64})', 'g')
    loop
      v_raw_tag := v_match[1];
      v_norm_tag := pg_catalog.lower(v_raw_tag);

      insert into public.hashtags (tag, display_tag, usage_count, is_trending, last_used_at)
      values (v_norm_tag, '#' || v_raw_tag, 0, false, pg_catalog.now())
      on conflict (tag) do update
        set last_used_at = pg_catalog.now()
      returning id into v_hashtag_id;

      if not (v_hashtag_id = any(v_seen_ids)) then
        v_seen_ids := pg_catalog.array_append(v_seen_ids, v_hashtag_id);
        insert into public.post_hashtags (post_id, hashtag_id)
        values (new.id, v_hashtag_id)
        on conflict do nothing;
      end if;
    end loop;
  end if;

  return new;
end;
$$;

revoke all on function public.sync_post_hashtags_from_caption() from public, anon, authenticated;

drop trigger if exists on_post_caption_hashtags on public.posts;
create trigger on_post_caption_hashtags
  after insert or update of caption, is_hidden on public.posts
  for each row execute function public.sync_post_hashtags_from_caption();

-- Post Likes (`public.post_likes`)
create table if not exists public.post_likes (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint post_likes_unique unique (post_id, user_id)
);

create index if not exists idx_post_likes_post_cursor
  on public.post_likes (post_id, created_at desc, id desc);
create index if not exists idx_post_likes_user_id
  on public.post_likes (user_id);

create or replace function public.sync_post_likes_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (tg_op = 'INSERT') then
    update public.posts set likes_count = likes_count + 1 where id = new.post_id;
  elsif (tg_op = 'DELETE') then
    update public.posts set likes_count = greatest(0, likes_count - 1) where id = old.post_id;
  end if;
  return coalesce(new, old);
end;
$$;

revoke all on function public.sync_post_likes_count() from public, anon, authenticated;

drop trigger if exists on_post_likes_change on public.post_likes;
create trigger on_post_likes_change
  after insert or delete on public.post_likes
  for each row execute function public.sync_post_likes_count();

-- Post Comments (`public.post_comments`)
create table if not exists public.post_comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.posts (id) on delete cascade,
  author_id   uuid not null references public.profiles (id) on delete cascade,
  parent_id   uuid references public.post_comments (id) on delete cascade,
  content     text not null
              check (char_length(btrim(content)) between 1 and 1000),
  likes_count integer not null default 0 check (likes_count >= 0),
  is_hidden   boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists idx_post_comments_post_cursor
  on public.post_comments (post_id, created_at asc, id asc);
create index if not exists idx_post_comments_author_id
  on public.post_comments (author_id);
create index if not exists idx_post_comments_parent_id
  on public.post_comments (parent_id);

drop trigger if exists post_comments_set_updated_at on public.post_comments;
create trigger post_comments_set_updated_at
  before update on public.post_comments
  for each row execute function public.set_updated_at();

create or replace function public.enforce_comment_not_blocked()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post_author uuid;
begin
  select p.author_id into v_post_author
    from public.posts p
   where p.id = new.post_id;

  if v_post_author is null then
    raise exception 'Post not found.';
  end if;

  if public.is_blocked_between(new.author_id, v_post_author) then
    raise exception 'Cannot comment on this post due to a block.';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_comment_not_blocked() from public, anon, authenticated;

drop trigger if exists before_post_comments_check_block on public.post_comments;
create trigger before_post_comments_check_block
  before insert on public.post_comments
  for each row execute function public.enforce_comment_not_blocked();

create or replace function public.sync_post_comments_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (tg_op = 'INSERT' and not new.is_hidden) then
    update public.posts set comments_count = comments_count + 1 where id = new.post_id;
  elsif (tg_op = 'DELETE' and not old.is_hidden) then
    update public.posts set comments_count = greatest(0, comments_count - 1) where id = old.post_id;
  elsif (tg_op = 'UPDATE' and old.is_hidden <> new.is_hidden) then
    if new.is_hidden then
      update public.posts set comments_count = greatest(0, comments_count - 1) where id = new.post_id;
    else
      update public.posts set comments_count = comments_count + 1 where id = new.post_id;
    end if;
  end if;
  return coalesce(new, old);
end;
$$;

revoke all on function public.sync_post_comments_count() from public, anon, authenticated;

drop trigger if exists on_post_comments_change on public.post_comments;
create trigger on_post_comments_change
  after insert or update of is_hidden or delete on public.post_comments
  for each row execute function public.sync_post_comments_count();

-- Post Bookmarks (`public.post_bookmarks`)
create table if not exists public.post_bookmarks (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint post_bookmarks_unique unique (post_id, user_id)
);

create index if not exists idx_post_bookmarks_user_cursor
  on public.post_bookmarks (user_id, created_at desc, id desc);
create index if not exists idx_post_bookmarks_post_id
  on public.post_bookmarks (post_id);

create or replace function public.sync_post_bookmarks_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (tg_op = 'INSERT') then
    update public.posts set bookmarks_count = bookmarks_count + 1 where id = new.post_id;
  elsif (tg_op = 'DELETE') then
    update public.posts set bookmarks_count = greatest(0, bookmarks_count - 1) where id = old.post_id;
  end if;
  return coalesce(new, old);
end;
$$;

revoke all on function public.sync_post_bookmarks_count() from public, anon, authenticated;

drop trigger if exists on_post_bookmarks_change on public.post_bookmarks;
create trigger on_post_bookmarks_change
  after insert or delete on public.post_bookmarks
  for each row execute function public.sync_post_bookmarks_count();

-- Post Shares (`public.post_shares`) — unique `(post_id, user_id, channel)` prevents inflation
create table if not exists public.post_shares (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  channel    text not null default 'in_app'
             check (channel in ('in_app', 'copy_link', 'external')),
  created_at timestamptz not null default now(),
  constraint post_shares_unique_per_channel unique (post_id, user_id, channel)
);

create index if not exists idx_post_shares_post_id
  on public.post_shares (post_id);
create index if not exists idx_post_shares_user_id
  on public.post_shares (user_id);

create or replace function public.sync_post_shares_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (tg_op = 'INSERT') then
    update public.posts set shares_count = shares_count + 1 where id = new.post_id;
  elsif (tg_op = 'DELETE') then
    update public.posts set shares_count = greatest(0, shares_count - 1) where id = old.post_id;
  end if;
  return coalesce(new, old);
end;
$$;

revoke all on function public.sync_post_shares_count() from public, anon, authenticated;

drop trigger if exists on_post_shares_change on public.post_shares;
create trigger on_post_shares_change
  after insert or delete on public.post_shares
  for each row execute function public.sync_post_shares_count();

-- -----------------------------------------------------------------------------
-- 7. Stories (`public.stories`) & Story Views (`public.story_views`)
-- -----------------------------------------------------------------------------
create table if not exists public.stories (
  id                uuid primary key default gen_random_uuid(),
  author_id         uuid not null references public.profiles (id) on delete cascade,
  media_url         text not null,
  storage_path      text,
  media_type        text not null default 'image'
                    check (media_type in ('image', 'video')),
  caption           text check (caption is null or char_length(caption) <= 500),
  text_overlay      text check (text_overlay is null or char_length(text_overlay) <= 300),
  font_family       text default 'Impact',
  text_color        text default '#FFFFFF',
  text_position_x   double precision default 0.5
                    check (text_position_x is null or (text_position_x between 0 and 1)),
  text_position_y   double precision default 0.5
                    check (text_position_y is null or (text_position_y between 0 and 1)),
  views_count       integer not null default 0 check (views_count >= 0),
  likes_count       integer not null default 0 check (likes_count >= 0),
  flame_level       smallint not null default 1 check (flame_level between 1 and 5),
  is_hidden         boolean not null default false,
  expires_at        timestamptz not null default (now() + interval '24 hours'),
  storage_purged_at timestamptz,
  created_at        timestamptz not null default now(),
  constraint stories_expires_after_created check (expires_at > created_at)
);

create index if not exists idx_stories_author_expires
  on public.stories (author_id, expires_at desc, id desc);
create index if not exists idx_stories_active_cursor
  on public.stories (expires_at desc, created_at desc, id desc)
  where is_hidden = false;

create table if not exists public.story_views (
  id        uuid primary key default gen_random_uuid(),
  story_id  uuid not null references public.stories (id) on delete cascade,
  viewer_id uuid not null references public.profiles (id) on delete cascade,
  liked     boolean not null default false,
  viewed_at timestamptz not null default now(),
  constraint story_views_unique unique (story_id, viewer_id)
);

create index if not exists idx_story_views_story_cursor
  on public.story_views (story_id, viewed_at desc, id desc);
create index if not exists idx_story_views_viewer_id
  on public.story_views (viewer_id);

-- Reject views/likes on expired or hidden stories or when blocked
create or replace function public.enforce_story_view_valid()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_author_id uuid;
  v_expires_at timestamptz;
  v_is_hidden boolean;
begin
  select s.author_id, s.expires_at, s.is_hidden
    into v_author_id, v_expires_at, v_is_hidden
    from public.stories s
   where s.id = new.story_id;

  if not found or v_is_hidden then
    raise exception 'Story is not available.';
  end if;

  if v_expires_at <= pg_catalog.now() then
    raise exception 'Cannot record view or reaction on an expired story.';
  end if;

  if public.is_blocked_between(new.viewer_id, v_author_id) then
    raise exception 'Cannot view story due to a block.';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_story_view_valid() from public, anon, authenticated;

drop trigger if exists before_story_views_validate on public.story_views;
create trigger before_story_views_validate
  before insert or update on public.story_views
  for each row execute function public.enforce_story_view_valid();

-- Incremental story engagement counter trigger (O(1) updates, no table scan)
create or replace function public.sync_story_engagement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_story_id uuid;
  v_delta_views integer := 0;
  v_delta_likes integer := 0;
begin
  v_story_id := coalesce(new.story_id, old.story_id);

  if (tg_op = 'INSERT') then
    v_delta_views := 1;
    if new.liked then
      v_delta_likes := 1;
    end if;
  elsif (tg_op = 'DELETE') then
    v_delta_views := -1;
    if old.liked then
      v_delta_likes := -1;
    end if;
  elsif (tg_op = 'UPDATE') then
    if not old.liked and new.liked then
      v_delta_likes := 1;
    elsif old.liked and not new.liked then
      v_delta_likes := -1;
    end if;
  end if;

  if v_delta_views <> 0 or v_delta_likes <> 0 then
    update public.stories
       set views_count = greatest(0, views_count + v_delta_views),
           likes_count = greatest(0, likes_count + v_delta_likes),
           flame_level = case
             when (greatest(0, views_count + v_delta_views) + greatest(0, likes_count + v_delta_likes) * 3) >= 200 then 5
             when (greatest(0, views_count + v_delta_views) + greatest(0, likes_count + v_delta_likes) * 3) >= 100 then 4
             when (greatest(0, views_count + v_delta_views) + greatest(0, likes_count + v_delta_likes) * 3) >= 40  then 3
             when (greatest(0, views_count + v_delta_views) + greatest(0, likes_count + v_delta_likes) * 3) >= 10  then 2
             else 1
           end
     where id = v_story_id;
  end if;

  return coalesce(new, old);
end;
$$;

revoke all on function public.sync_story_engagement() from public, anon, authenticated;

drop trigger if exists on_story_views_change on public.story_views;
create trigger on_story_views_change
  after insert or update of liked or delete on public.story_views
  for each row execute function public.sync_story_engagement();

-- #############################################################################
-- FILE: 20261124000003_events.sql
-- #############################################################################

-- =============================================================================
-- LIT Social — Migration 20261124000003: Events
-- Target: Self-hosted Supabase (PostgreSQL 15+)
-- Contents:
--   1. `public.events` (with `timezone` IANA column, `category` text + check
--      constraint with TODO note, incremental `rating_sum` + `ratings_count`,
--      no duplicate `has_parking` / `has_food_and_drinks` columns, `is_free`
--      defaulting to `false`, and FK from `public.posts.event_id`).
--   2. `public.event_media` (backs the 5-dot image carousel on Events cards).
--   3. `public.event_schedules` (timeline slots: 7:00 PM Door Open, etc.).
--   4. `public.event_highlights` (single source of truth for event amenity pills).
--   5. `public.event_ticket_tiers` (`quantity_sold <= quantity_total` oversell
--      constraint, plus `sync_event_pricing` trigger where `is_free` is true
--      ONLY when active tiers exist, ALL active tiers are 0, and
--      `external_ticket_url is null`).
--   6. `public.event_rsvps` (incremental `+1/-1` counter trigger).
--   7. `public.event_ratings` (incremental `+1/-1` sum & count trigger).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Events (`public.events`)
-- -----------------------------------------------------------------------------
create table if not exists public.events (
  id                   uuid primary key default gen_random_uuid(),
  host_id              uuid not null references public.profiles (id) on delete restrict,
  title                text not null
                       check (char_length(btrim(title)) between 1 and 150),
  slug                 text unique,
  subtitle             text check (subtitle is null or char_length(subtitle) <= 200),
  description          text check (description is null or char_length(description) <= 5000),
  -- TODO: confirm against Figma filter chips (Events screen vs Create Event screen)
  category             text not null default 'nightlife'
                       check (category in (
                         'nightlife',
                         'music',
                         'party',
                         'festival',
                         'art',
                         'sports',
                         'food',
                         'tech',
                         'business',
                         'other'
                       )),
  status               text not null default 'published'
                       check (status in ('draft', 'published', 'cancelled', 'completed')),
  cover_image_url      text,
  cover_storage_path   text,
  venue_name           text not null
                       check (char_length(btrim(venue_name)) between 1 and 150),
  address              text check (address is null or char_length(address) <= 250),
  city                 text check (city is null or char_length(city) <= 100),
  latitude             double precision
                       check (latitude is null or (latitude between -90 and 90)),
  longitude            double precision
                       check (longitude is null or (longitude between -180 and 180)),
  location_id          uuid references public.locations (id) on delete set null,
  timezone             text not null default 'UTC'
                       check (char_length(btrim(timezone)) between 2 and 64),
  starts_at            timestamptz not null,
  ends_at              timestamptz,
  doors_open_at        timestamptz,
  -- An event with no tiers is NOT free by default; computed by `sync_event_pricing`
  is_free              boolean not null default false,
  starting_price_cents integer not null default 0
                       check (starting_price_cents >= 0),
  currency             text not null default 'USD'
                       check (currency ~ '^[A-Z]{3}$'),
  capacity             integer check (capacity is null or capacity > 0),
  going_count          integer not null default 0 check (going_count >= 0),
  interested_count     integer not null default 0 check (interested_count >= 0),
  tickets_sold_count   integer not null default 0 check (tickets_sold_count >= 0),
  rating_sum           integer not null default 0 check (rating_sum >= 0),
  ratings_count        integer not null default 0 check (ratings_count >= 0),
  rating_avg           numeric(3,2) not null default 0.00
                       check (rating_avg between 0 and 5),
  external_ticket_url  text
                       check (external_ticket_url is null or external_ticket_url ~* '^https?://[^\s/$.?#].[^\s]*$'),
  is_featured          boolean not null default false,
  is_hidden            boolean not null default false,
  published_at         timestamptz default now(),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint events_ends_after_starts check (ends_at is null or ends_at > starts_at)
);

create index if not exists idx_events_starts_cursor
  on public.events (starts_at asc, id asc)
  where status = 'published' and is_hidden = false;
create index if not exists idx_events_category_starts_cursor
  on public.events (category, starts_at asc, id asc);
create index if not exists idx_events_host_cursor
  on public.events (host_id, created_at desc, id desc);
create index if not exists idx_events_location_id
  on public.events (location_id);
create index if not exists idx_events_title_trgm
  on public.events using gin (title extensions.gin_trgm_ops);

drop trigger if exists events_set_updated_at on public.events;
create trigger events_set_updated_at
  before update on public.events
  for each row execute function public.set_updated_at();

-- Wire `public.posts.event_id` FK and composite cursor index now that `events` exists
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'posts_event_id_fkey'
  ) then
    alter table public.posts
      add constraint posts_event_id_fkey
      foreign key (event_id) references public.events (id) on delete set null;
  end if;
end
$$;

create index if not exists idx_posts_event_cursor
  on public.posts (event_id, created_at desc, id desc);

-- -----------------------------------------------------------------------------
-- 2. Event Media (`public.event_media`) — Backs the 5-dot Carousel on Events
-- -----------------------------------------------------------------------------
create table if not exists public.event_media (
  id           uuid primary key default gen_random_uuid(),
  event_id     uuid not null references public.events (id) on delete cascade,
  media_url    text not null,
  storage_path text,
  media_type   text not null default 'image'
               check (media_type in ('image', 'video')),
  sort_order   smallint not null default 0,
  created_at   timestamptz not null default now()
);

create index if not exists idx_event_media_event_sort
  on public.event_media (event_id, sort_order asc);

-- -----------------------------------------------------------------------------
-- 3. Event Schedules (`public.event_schedules`)
-- -----------------------------------------------------------------------------
create table if not exists public.event_schedules (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events (id) on delete cascade,
  time_label  text not null check (char_length(btrim(time_label)) between 1 and 40),
  title       text not null check (char_length(btrim(title)) between 1 and 120),
  description text check (description is null or char_length(description) <= 500),
  starts_at   timestamptz,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now()
);

create index if not exists idx_event_schedules_event_sort
  on public.event_schedules (event_id, sort_order asc);

-- -----------------------------------------------------------------------------
-- 4. Event Highlights (`public.event_highlights`) — Single Source of Truth
--    (e.g. "Live Performances", "Food & Drinks", "Parking Available", "18+ Event")
-- -----------------------------------------------------------------------------
create table if not exists public.event_highlights (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events (id) on delete cascade,
  label      text not null check (char_length(btrim(label)) between 1 and 80),
  icon_name  text check (icon_name is null or char_length(icon_name) <= 50),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_event_highlights_event_sort
  on public.event_highlights (event_id, sort_order asc);

-- -----------------------------------------------------------------------------
-- 5. Event Ticket Tiers (`public.event_ticket_tiers`)
-- -----------------------------------------------------------------------------
create table if not exists public.event_ticket_tiers (
  id             uuid primary key default gen_random_uuid(),
  event_id       uuid not null references public.events (id) on delete cascade,
  name           text not null check (char_length(btrim(name)) between 1 and 100),
  description    text check (description is null or char_length(description) <= 500),
  perks          text[] not null default '{}',
  price_cents    integer not null default 0 check (price_cents >= 0),
  currency       text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
  quantity_total integer not null default 100 check (quantity_total >= 0),
  quantity_sold  integer not null default 0 check (quantity_sold >= 0),
  max_per_order  integer not null default 10 check (max_per_order > 0),
  group_size     smallint not null default 1 check (group_size > 0),
  sort_order     integer not null default 0,
  is_active      boolean not null default true,
  sales_start_at timestamptz,
  sales_end_at   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint event_ticket_tiers_no_oversell check (quantity_sold <= quantity_total),
  constraint event_ticket_tiers_sales_window check (
    sales_end_at is null or sales_start_at is null or sales_end_at > sales_start_at
  )
);

create index if not exists idx_event_ticket_tiers_event_sort
  on public.event_ticket_tiers (event_id, sort_order asc);

drop trigger if exists event_ticket_tiers_set_updated_at on public.event_ticket_tiers;
create trigger event_ticket_tiers_set_updated_at
  before update on public.event_ticket_tiers
  for each row execute function public.set_updated_at();

-- Must-fix #3: `is_free` is true ONLY when:
--   1. The event has at least 1 active tier (`v_active_count > 0`),
--   2. ALL active tiers have `price_cents = 0` (`v_max_price = 0`), AND
--   3. `external_ticket_url is null`.
create or replace function public.recompute_event_pricing(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_active_count integer;
  v_min_price integer;
  v_max_price integer;
begin
  select count(*),
         coalesce(min(price_cents), 0),
         coalesce(max(price_cents), 0)
    into v_active_count, v_min_price, v_max_price
    from public.event_ticket_tiers
   where event_id = p_event_id
     and is_active = true;

  update public.events
     set starting_price_cents = v_min_price,
         is_free = (
           v_active_count > 0
           and v_max_price = 0
           and external_ticket_url is null
         )
   where id = p_event_id;
end;
$$;

revoke all on function public.recompute_event_pricing(uuid) from public, anon, authenticated;

create or replace function public.sync_event_pricing_from_tier()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.recompute_event_pricing(coalesce(new.event_id, old.event_id));
  return coalesce(new, old);
end;
$$;

revoke all on function public.sync_event_pricing_from_tier() from public, anon, authenticated;

drop trigger if exists on_ticket_tier_price_change on public.event_ticket_tiers;
create trigger on_ticket_tier_price_change
  after insert or update of price_cents, is_active, event_id or delete on public.event_ticket_tiers
  for each row execute function public.sync_event_pricing_from_tier();

create or replace function public.sync_event_pricing_on_event_url()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.recompute_event_pricing(new.id);
  return new;
end;
$$;

revoke all on function public.sync_event_pricing_on_event_url() from public, anon, authenticated;

drop trigger if exists on_event_external_url_change on public.events;
create trigger on_event_external_url_change
  after update of external_ticket_url on public.events
  for each row execute function public.sync_event_pricing_on_event_url();

-- -----------------------------------------------------------------------------
-- 6. Event RSVPs (`public.event_rsvps`) — Incremental `+1/-1` Counter Trigger
-- -----------------------------------------------------------------------------
create table if not exists public.event_rsvps (
  id           uuid primary key default gen_random_uuid(),
  event_id     uuid not null references public.events (id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  status       text not null default 'going'
               check (status in ('going', 'interested', 'not_going')),
  guests_count smallint not null default 0 check (guests_count >= 0),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint event_rsvps_unique unique (event_id, user_id)
);

create index if not exists idx_event_rsvps_event_cursor
  on public.event_rsvps (event_id, status, created_at desc, id desc);
create index if not exists idx_event_rsvps_user_cursor
  on public.event_rsvps (user_id, status, created_at desc, id desc);

drop trigger if exists event_rsvps_set_updated_at on public.event_rsvps;
create trigger event_rsvps_set_updated_at
  before update on public.event_rsvps
  for each row execute function public.set_updated_at();

create or replace function public.sync_event_rsvp_counts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event_id uuid;
  v_delta_going integer := 0;
  v_delta_interested integer := 0;
begin
  v_event_id := coalesce(new.event_id, old.event_id);

  if (tg_op = 'INSERT' or tg_op = 'UPDATE') then
    if new.status = 'going' then
      v_delta_going := v_delta_going + 1;
    elsif new.status = 'interested' then
      v_delta_interested := v_delta_interested + 1;
    end if;
  end if;

  if (tg_op = 'DELETE' or tg_op = 'UPDATE') then
    if old.status = 'going' then
      v_delta_going := v_delta_going - 1;
    elsif old.status = 'interested' then
      v_delta_interested := v_delta_interested - 1;
    end if;
  end if;

  if v_delta_going <> 0 or v_delta_interested <> 0 then
    update public.events
       set going_count      = greatest(0, going_count + v_delta_going),
           interested_count = greatest(0, interested_count + v_delta_interested)
     where id = v_event_id;
  end if;

  return coalesce(new, old);
end;
$$;

revoke all on function public.sync_event_rsvp_counts() from public, anon, authenticated;

drop trigger if exists on_event_rsvps_change on public.event_rsvps;
create trigger on_event_rsvps_change
  after insert or update of status or delete on public.event_rsvps
  for each row execute function public.sync_event_rsvp_counts();

-- -----------------------------------------------------------------------------
-- 7. Event Ratings (`public.event_ratings`) — Incremental Sum & Count Trigger
-- -----------------------------------------------------------------------------
create table if not exists public.event_ratings (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  rating      smallint not null check (rating between 1 and 5),
  review_text text check (review_text is null or char_length(review_text) <= 1000),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint event_ratings_unique unique (event_id, user_id)
);

create index if not exists idx_event_ratings_event_cursor
  on public.event_ratings (event_id, created_at desc, id desc);
create index if not exists idx_event_ratings_user_id
  on public.event_ratings (user_id);

drop trigger if exists event_ratings_set_updated_at on public.event_ratings;
create trigger event_ratings_set_updated_at
  before update on public.event_ratings
  for each row execute function public.set_updated_at();

create or replace function public.sync_event_rating_stats()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event_id uuid;
  v_delta_sum integer := 0;
  v_delta_count integer := 0;
begin
  v_event_id := coalesce(new.event_id, old.event_id);

  if (tg_op = 'INSERT') then
    v_delta_sum := new.rating;
    v_delta_count := 1;
  elsif (tg_op = 'DELETE') then
    v_delta_sum := -old.rating;
    v_delta_count := -1;
  elsif (tg_op = 'UPDATE') then
    v_delta_sum := new.rating - old.rating;
  end if;

  if v_delta_sum <> 0 or v_delta_count <> 0 then
    update public.events
       set rating_sum    = greatest(0, rating_sum + v_delta_sum),
           ratings_count = greatest(0, ratings_count + v_delta_count),
           rating_avg    = case
             when greatest(0, ratings_count + v_delta_count) > 0 then
               pg_catalog.round(
                 greatest(0, rating_sum + v_delta_sum)::numeric
                 / greatest(0, ratings_count + v_delta_count),
                 2
               )
             else 0.00
           end
     where id = v_event_id;
  end if;

  return coalesce(new, old);
end;
$$;

revoke all on function public.sync_event_rating_stats() from public, anon, authenticated;

drop trigger if exists on_event_ratings_change on public.event_ratings;
create trigger on_event_ratings_change
  after insert or update of rating or delete on public.event_ratings
  for each row execute function public.sync_event_rating_stats();

-- #############################################################################
-- FILE: 20261124000004_ticketing.sql
-- #############################################################################

-- =============================================================================
-- LIT Social — Migration 20261124000004: Ticketing
-- Target: Self-hosted Supabase (PostgreSQL 15+)
-- Contents:
--   1. Separate non-truncating sequences and generator functions for
--      `order_number` (`ORD-YYYY-01001`..`ORD-YYYY-100000+`) and
--      `ticket_code` (`LIT-YYYY-00482`..`LIT-YYYY-100000+`).
--   2. `public.promo_codes` (server-only table; validated via RPC).
--   3. `public.ticket_orders` (default status `'pending'`, `on delete set null`
--      for buyer + snapshot columns so financial records are never lost).
--   4. `public.ticket_order_items` (`on delete restrict`).
--   5. `public.tickets` (`on delete restrict` / `set null` for owner + snapshot
--      columns, cryptographic 48-hex-char `qr_payload`, trigger enforcing
--      `admits_count = tier.group_size`).
--   6. `public.event_staff` (authorized door scanners per event).
--   7. `public.stripe_webhook_events` (idempotency log for Stripe webhooks).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Separate Non-Truncating Sequences & Code Generators
-- -----------------------------------------------------------------------------
create sequence if not exists public.lit_order_number_seq start 1001;
create sequence if not exists public.lit_ticket_code_seq start 482;

create or replace function public.next_order_number()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n bigint;
begin
  v_n := pg_catalog.nextval('public.lit_order_number_seq');
  return 'ORD-'
    || pg_catalog.to_char(pg_catalog.now(), 'YYYY')
    || '-'
    || pg_catalog.lpad(v_n::text, greatest(5, pg_catalog.length(v_n::text)), '0');
end;
$$;

revoke all on function public.next_order_number() from public, anon, authenticated;

create or replace function public.next_ticket_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n bigint;
begin
  v_n := pg_catalog.nextval('public.lit_ticket_code_seq');
  return 'LIT-'
    || pg_catalog.to_char(pg_catalog.now(), 'YYYY')
    || '-'
    || pg_catalog.lpad(v_n::text, greatest(5, pg_catalog.length(v_n::text)), '0');
end;
$$;

revoke all on function public.next_ticket_code() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Promo Codes (`public.promo_codes`) — Not Publicly Listable
-- -----------------------------------------------------------------------------
create table if not exists public.promo_codes (
  id                    uuid primary key default gen_random_uuid(),
  event_id              uuid references public.events (id) on delete restrict,
  code                  text not null unique
                        check (char_length(btrim(code)) between 2 and 40),
  discount_percent      smallint
                        check (discount_percent is null or (discount_percent between 1 and 100)),
  discount_amount_cents integer
                        check (discount_amount_cents is null or discount_amount_cents > 0),
  max_uses              integer check (max_uses is null or max_uses > 0),
  uses_count            integer not null default 0 check (uses_count >= 0),
  is_active             boolean not null default true,
  expires_at            timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint promo_codes_discount_kind check (
    (discount_percent is not null and discount_amount_cents is null)
    or (discount_percent is null and discount_amount_cents is not null)
  ),
  constraint promo_codes_max_uses_bound check (
    max_uses is null or uses_count <= max_uses
  )
);

create index if not exists idx_promo_codes_event_id
  on public.promo_codes (event_id);

drop trigger if exists promo_codes_set_updated_at on public.promo_codes;
create trigger promo_codes_set_updated_at
  before update on public.promo_codes
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 3. Ticket Orders (`public.ticket_orders`)
--    - Default status is `'pending'` (fulfilled only by server-side webhook).
--    - Never cascade-deleted when a profile is removed (`on delete set null`
--      plus snapshot columns).
-- -----------------------------------------------------------------------------
create table if not exists public.ticket_orders (
  id                          uuid primary key default gen_random_uuid(),
  order_number                text not null unique default public.next_order_number(),
  buyer_id                    uuid references public.profiles (id) on delete set null,
  buyer_display_name_snapshot text,
  buyer_email_snapshot        text,
  event_id                    uuid not null references public.events (id) on delete restrict,
  event_title_snapshot        text,
  promo_code_id               uuid references public.promo_codes (id) on delete set null,
  promo_code_text             text,
  subtotal_cents              integer not null default 0 check (subtotal_cents >= 0),
  service_fee_cents           integer not null default 0 check (service_fee_cents >= 0),
  discount_cents              integer not null default 0 check (discount_cents >= 0),
  total_cents                 integer not null default 0 check (total_cents >= 0),
  currency                    text not null default 'USD'
                              check (currency ~ '^[A-Z]{3}$'),
  payment_method              text not null default 'stripe'
                              check (payment_method in ('stripe', 'apple_pay', 'free')),
  stripe_payment_intent_id    text unique,
  status                      text not null default 'pending'
                              check (status in ('pending', 'paid', 'cancelled', 'refunded', 'expired')),
  stock_reserved              boolean not null default false,
  expires_at                  timestamptz not null default (now() + interval '30 minutes'),
  paid_at                     timestamptz,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);

create index if not exists idx_ticket_orders_buyer_cursor
  on public.ticket_orders (buyer_id, created_at desc, id desc);
create index if not exists idx_ticket_orders_event_cursor
  on public.ticket_orders (event_id, created_at desc, id desc);
create index if not exists idx_ticket_orders_promo_code_id
  on public.ticket_orders (promo_code_id);
create index if not exists idx_ticket_orders_pending_expiry
  on public.ticket_orders (expires_at asc)
  where status = 'pending';

drop trigger if exists ticket_orders_set_updated_at on public.ticket_orders;
create trigger ticket_orders_set_updated_at
  before update on public.ticket_orders
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 4. Ticket Order Items (`public.ticket_order_items`)
-- -----------------------------------------------------------------------------
create table if not exists public.ticket_order_items (
  id               uuid primary key default gen_random_uuid(),
  order_id         uuid not null references public.ticket_orders (id) on delete restrict,
  tier_id          uuid not null references public.event_ticket_tiers (id) on delete restrict,
  tier_name        text not null,
  group_size       smallint not null default 1 check (group_size > 0),
  unit_price_cents integer not null check (unit_price_cents >= 0),
  quantity         integer not null check (quantity > 0),
  line_total_cents integer not null check (line_total_cents >= 0),
  created_at       timestamptz not null default now()
);

create index if not exists idx_ticket_order_items_order_id
  on public.ticket_order_items (order_id);
create index if not exists idx_ticket_order_items_tier_id
  on public.ticket_order_items (tier_id);

-- -----------------------------------------------------------------------------
-- 5. Digital QR Tickets (`public.tickets`)
--    - `ticket_code` is for human display only (`LIT-2026-00482`).
--    - `qr_payload` is random, 48-hex-char unguessable token encoded in QR.
--    - `admits_count` is enforced to match `event_ticket_tiers.group_size`.
-- -----------------------------------------------------------------------------
create table if not exists public.tickets (
  id                   uuid primary key default gen_random_uuid(),
  ticket_code          text not null unique default public.next_ticket_code(),
  order_id             uuid not null references public.ticket_orders (id) on delete restrict,
  order_item_id        uuid references public.ticket_order_items (id) on delete restrict,
  event_id             uuid not null references public.events (id) on delete restrict,
  tier_id              uuid not null references public.event_ticket_tiers (id) on delete restrict,
  owner_id             uuid references public.profiles (id) on delete set null,
  holder_name_snapshot text,
  event_title_snapshot text,
  tier_name            text not null,
  seat_or_table_label  text,
  admits_count         smallint not null default 1 check (admits_count > 0),
  qr_payload           text not null unique default encode(extensions.gen_random_bytes(24), 'hex'),
  status               text not null default 'valid'
                       check (status in ('valid', 'used', 'cancelled', 'transferred')),
  checked_in_at        timestamptz,
  checked_in_by        uuid references public.profiles (id) on delete set null,
  transferred_to_id    uuid references public.profiles (id) on delete set null,
  transferred_at       timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index if not exists idx_tickets_owner_cursor
  on public.tickets (owner_id, created_at desc, id desc);
create index if not exists idx_tickets_event_status_cursor
  on public.tickets (event_id, status, created_at desc, id desc);
create index if not exists idx_tickets_order_id
  on public.tickets (order_id);
create index if not exists idx_tickets_order_item_id
  on public.tickets (order_item_id);
create index if not exists idx_tickets_tier_id
  on public.tickets (tier_id);
create index if not exists idx_tickets_checked_in_by
  on public.tickets (checked_in_by);
create index if not exists idx_tickets_transferred_to_id
  on public.tickets (transferred_to_id);

drop trigger if exists tickets_set_updated_at on public.tickets;
create trigger tickets_set_updated_at
  before update on public.tickets
  for each row execute function public.set_updated_at();

-- Must-fix #12: Enforce that `tickets.admits_count` matches `event_ticket_tiers.group_size`
-- and `tickets.event_id` matches `event_ticket_tiers.event_id`.
create or replace function public.enforce_ticket_tier_consistency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tier_group_size smallint;
  v_tier_event_id uuid;
begin
  select t.group_size, t.event_id
    into v_tier_group_size, v_tier_event_id
    from public.event_ticket_tiers t
   where t.id = new.tier_id;

  if not found then
    raise exception 'Ticket tier % does not exist.', new.tier_id;
  end if;

  if new.event_id <> v_tier_event_id then
    raise exception 'Ticket event_id (%) does not match tier event_id (%).', new.event_id, v_tier_event_id;
  end if;

  if new.admits_count <> v_tier_group_size then
    raise exception 'Ticket admits_count (%) must equal tier group_size (%).', new.admits_count, v_tier_group_size;
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_ticket_tier_consistency() from public, anon, authenticated;

drop trigger if exists before_tickets_check_tier on public.tickets;
create trigger before_tickets_check_tier
  before insert or update of tier_id, event_id, admits_count on public.tickets
  for each row execute function public.enforce_ticket_tier_consistency();

-- -----------------------------------------------------------------------------
-- 6. Event Staff (`public.event_staff`) — Authorized Door Scanners
-- -----------------------------------------------------------------------------
create table if not exists public.event_staff (
  event_id   uuid not null references public.events (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  role       text not null default 'scanner'
             check (role in ('scanner', 'manager')),
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create index if not exists idx_event_staff_user_id
  on public.event_staff (user_id);

-- -----------------------------------------------------------------------------
-- 7. Stripe Webhook Idempotency Log (`public.stripe_webhook_events`)
-- -----------------------------------------------------------------------------
create table if not exists public.stripe_webhook_events (
  id           text primary key, -- Stripe event id, e.g. 'evt_1Q...'
  type         text not null,
  payload      jsonb not null default '{}'::jsonb,
  processed_at timestamptz not null default now()
);

-- #############################################################################
-- FILE: 20261124000005_notifications_support.sql
-- #############################################################################

-- =============================================================================
-- LIT Social — Migration 20261124000005: Notifications, Moderation & Support
-- Target: Self-hosted Supabase (PostgreSQL 15+)
-- Contents:
--   1. `public.notifications` (created server-side only via triggers / service_role;
--      respects blocks and mutes).
--   2. `public.push_tokens` (Expo push notification device tokens).
--   3. `public.content_reports` (user moderation reports; admin status is service_role).
--   4. `public.app_ratings` ("Rate Lit Social" modal).
--   5. `public.faq_items` and `public.support_tickets` ("Help Center").
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Notifications (`public.notifications`) — Server-Only Creation
-- -----------------------------------------------------------------------------
create table if not exists public.notifications (
  id           uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  actor_id     uuid references public.profiles (id) on delete set null,
  type         text not null
               check (type in (
                 'vibe_request',
                 'new_viber',
                 'vibe_accepted',
                 'post_like',
                 'post_comment',
                 'post_tag',
                 'event_rsvp',
                 'ticket_purchased',
                 'event_reminder',
                 'system'
               )),
  title        text not null check (char_length(btrim(title)) between 1 and 160),
  body         text check (body is null or char_length(body) <= 500),
  post_id      uuid references public.posts (id) on delete cascade,
  event_id     uuid references public.events (id) on delete cascade,
  ticket_id    uuid references public.tickets (id) on delete cascade,
  metadata     jsonb not null default '{}'::jsonb,
  is_read      boolean not null default false,
  read_at      timestamptz,
  created_at   timestamptz not null default now()
);

create index if not exists idx_notifications_recipient_cursor
  on public.notifications (recipient_id, created_at desc, id desc);
create index if not exists idx_notifications_recipient_unread_cursor
  on public.notifications (recipient_id, is_read, created_at desc, id desc);
create index if not exists idx_notifications_actor_id
  on public.notifications (actor_id);
create index if not exists idx_notifications_post_id
  on public.notifications (post_id);
create index if not exists idx_notifications_event_id
  on public.notifications (event_id);
create index if not exists idx_notifications_ticket_id
  on public.notifications (ticket_id);

-- Internal helper to insert a notification only when recipient <> actor,
-- neither has blocked the other, and recipient has not muted actor.
create or replace function public.create_notification_internal(
  p_recipient_id uuid,
  p_actor_id uuid,
  p_type text,
  p_title text,
  p_body text default null,
  p_post_id uuid default null,
  p_event_id uuid default null,
  p_ticket_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_recipient_id is null then
    return;
  end if;

  if p_actor_id is not null and p_recipient_id = p_actor_id then
    return;
  end if;

  if p_actor_id is not null and public.is_blocked_between(p_recipient_id, p_actor_id) then
    return;
  end if;

  if p_actor_id is not null and exists (
    select 1
      from public.user_mutes m
     where m.muter_id = p_recipient_id
       and m.muted_id = p_actor_id
  ) then
    return;
  end if;

  insert into public.notifications (
    recipient_id,
    actor_id,
    type,
    title,
    body,
    post_id,
    event_id,
    ticket_id,
    metadata
  )
  values (
    p_recipient_id,
    p_actor_id,
    p_type,
    p_title,
    p_body,
    p_post_id,
    p_event_id,
    p_ticket_id,
    coalesce(p_metadata, '{}'::jsonb)
  );
end;
$$;

revoke all on function public.create_notification_internal(uuid, uuid, text, text, text, uuid, uuid, uuid, jsonb)
  from public, anon, authenticated;

-- Trigger: notify on new vibe / vibe request / accepted vibe
create or replace function public.notify_on_vibe_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_name text;
begin
  if (tg_op = 'INSERT') then
    select coalesce(p.display_name, '@' || p.username, 'Someone')
      into v_actor_name
      from public.profiles p
     where p.id = new.follower_id;

    if new.status = 'pending' then
      perform public.create_notification_internal(
        new.following_id,
        new.follower_id,
        'vibe_request',
        v_actor_name || ' requested to vibe with you',
        null
      );
    else
      perform public.create_notification_internal(
        new.following_id,
        new.follower_id,
        'new_viber',
        v_actor_name || ' started vibing with you',
        null
      );
    end if;
  elsif (tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'accepted') then
    select coalesce(p.display_name, '@' || p.username, 'Someone')
      into v_actor_name
      from public.profiles p
     where p.id = new.following_id;

    perform public.create_notification_internal(
      new.follower_id,
      new.following_id,
      'vibe_accepted',
      v_actor_name || ' accepted your vibe request',
      null
    );
  end if;

  return new;
end;
$$;

revoke all on function public.notify_on_vibe_change() from public, anon, authenticated;

drop trigger if exists after_vibes_notify on public.vibes;
create trigger after_vibes_notify
  after insert or update of status on public.vibes
  for each row execute function public.notify_on_vibe_change();

-- Trigger: notify post author on like
create or replace function public.notify_on_post_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post_author uuid;
  v_actor_name text;
begin
  select p.author_id into v_post_author
    from public.posts p
   where p.id = new.post_id;

  select coalesce(pr.display_name, '@' || pr.username, 'Someone')
    into v_actor_name
    from public.profiles pr
   where pr.id = new.user_id;

  perform public.create_notification_internal(
    v_post_author,
    new.user_id,
    'post_like',
    v_actor_name || ' liked your post',
    null,
    new.post_id
  );

  return new;
end;
$$;

revoke all on function public.notify_on_post_like() from public, anon, authenticated;

drop trigger if exists after_post_likes_notify on public.post_likes;
create trigger after_post_likes_notify
  after insert on public.post_likes
  for each row execute function public.notify_on_post_like();

-- Trigger: notify post author on comment
create or replace function public.notify_on_post_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post_author uuid;
  v_actor_name text;
begin
  select p.author_id into v_post_author
    from public.posts p
   where p.id = new.post_id;

  select coalesce(pr.display_name, '@' || pr.username, 'Someone')
    into v_actor_name
    from public.profiles pr
   where pr.id = new.author_id;

  perform public.create_notification_internal(
    v_post_author,
    new.author_id,
    'post_comment',
    v_actor_name || ' commented on your post',
    pg_catalog.substr(new.content, 1, 140),
    new.post_id
  );

  return new;
end;
$$;

revoke all on function public.notify_on_post_comment() from public, anon, authenticated;

drop trigger if exists after_post_comments_notify on public.post_comments;
create trigger after_post_comments_notify
  after insert on public.post_comments
  for each row execute function public.notify_on_post_comment();

-- Trigger: notify tagged user on post tag
create or replace function public.notify_on_post_tag()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post_author uuid;
  v_actor_name text;
begin
  select p.author_id into v_post_author
    from public.posts p
   where p.id = new.post_id;

  select coalesce(pr.display_name, '@' || pr.username, 'Someone')
    into v_actor_name
    from public.profiles pr
   where pr.id = v_post_author;

  perform public.create_notification_internal(
    new.tagged_user_id,
    v_post_author,
    'post_tag',
    v_actor_name || ' tagged you in a post',
    null,
    new.post_id
  );

  return new;
end;
$$;

revoke all on function public.notify_on_post_tag() from public, anon, authenticated;

drop trigger if exists after_post_tags_notify on public.post_tags;
create trigger after_post_tags_notify
  after insert on public.post_tags
  for each row execute function public.notify_on_post_tag();

-- -----------------------------------------------------------------------------
-- 2. Expo Push Tokens (`public.push_tokens`)
-- -----------------------------------------------------------------------------
create table if not exists public.push_tokens (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles (id) on delete cascade,
  expo_push_token text not null unique
                  check (char_length(btrim(expo_push_token)) between 8 and 255),
  device_label    text check (device_label is null or char_length(device_label) <= 100),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint push_tokens_user_token_unique unique (user_id, expo_push_token)
);

create index if not exists idx_push_tokens_user_id
  on public.push_tokens (user_id);

drop trigger if exists push_tokens_set_updated_at on public.push_tokens;
create trigger push_tokens_set_updated_at
  before update on public.push_tokens
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 3. Content Reports & Moderation (`public.content_reports`)
-- -----------------------------------------------------------------------------
create table if not exists public.content_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  target_type text not null
              check (target_type in ('profile', 'post', 'comment', 'story', 'event')),
  target_id   uuid not null,
  reason      text not null
              check (reason in ('spam', 'harassment', 'inappropriate', 'scam', 'fake_event', 'other')),
  details     text check (details is null or char_length(details) <= 1000),
  status      text not null default 'open'
              check (status in ('open', 'reviewing', 'actioned', 'dismissed')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists idx_content_reports_reporter_cursor
  on public.content_reports (reporter_id, created_at desc, id desc);
create index if not exists idx_content_reports_status_cursor
  on public.content_reports (status, created_at desc, id desc);

drop trigger if exists content_reports_set_updated_at on public.content_reports;
create trigger content_reports_set_updated_at
  before update on public.content_reports
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 4. App Ratings (`public.app_ratings`) — "Rate Lit Social" Modal
-- -----------------------------------------------------------------------------
create table if not exists public.app_ratings (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  rating      smallint not null check (rating between 1 and 5),
  feedback    text check (feedback is null or char_length(feedback) <= 1000),
  app_version text default '1.0.0' check (app_version is null or char_length(app_version) <= 30),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint app_ratings_user_unique unique (user_id)
);

drop trigger if exists app_ratings_set_updated_at on public.app_ratings;
create trigger app_ratings_set_updated_at
  before update on public.app_ratings
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 5. Help Center FAQs (`public.faq_items`) & Support Tickets (`public.support_tickets`)
-- -----------------------------------------------------------------------------
create table if not exists public.faq_items (
  id           uuid primary key default gen_random_uuid(),
  question     text not null check (char_length(btrim(question)) between 1 and 250),
  answer       text not null check (char_length(btrim(answer)) between 1 and 2000),
  category     text not null default 'general'
               check (char_length(btrim(category)) between 1 and 60),
  sort_order   integer not null default 0,
  is_published boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists idx_faq_items_published_sort
  on public.faq_items (is_published, sort_order asc);

drop trigger if exists faq_items_set_updated_at on public.faq_items;
create trigger faq_items_set_updated_at
  before update on public.faq_items
  for each row execute function public.set_updated_at();

create table if not exists public.support_tickets (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  subject    text not null check (char_length(btrim(subject)) between 1 and 160),
  message    text not null check (char_length(btrim(message)) between 1 and 2000),
  category   text not null default 'support'
             check (category in ('support', 'ticket_transfer', 'report_content', 'billing', 'other')),
  status     text not null default 'open'
             check (status in ('open', 'in_progress', 'resolved', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_support_tickets_user_cursor
  on public.support_tickets (user_id, created_at desc, id desc);

drop trigger if exists support_tickets_set_updated_at on public.support_tickets;
create trigger support_tickets_set_updated_at
  before update on public.support_tickets
  for each row execute function public.set_updated_at();

-- #############################################################################
-- FILE: 20261124000006_rls_and_grants.sql
-- #############################################################################

-- =============================================================================
-- LIT Social — Migration 20261124000006: RLS Policies & Column-Level Grants
-- Target: Self-hosted Supabase (PostgreSQL 15+)
-- Contents:
--   1. `public.can_view_profile_content(p_owner uuid)` helper (stable,
--      security definer, `set search_path = ''`): checks `deleted_at is null`,
--      no block in either direction, and (`not is_private` OR caller is owner
--      OR caller is an accepted viber).
--   2. Enables Row Level Security (`relrowsecurity = true`) on EVERY table
--      in `public`.
--   3. Explicit `revoke all` + column-level `grant insert (...)` /
--      `grant update (...)` so clients can NEVER self-edit counters, badges,
--      moderation flags (`is_verified`, `vibers_count`, `posts_count`,
--      `likes_count`, `views_count`, `flame_level`, `is_hidden`,
--      `checkins_count`, `quantity_sold`, `rating_avg`, etc.).
--   4. Server-only write lockouts on `ticket_orders`, `ticket_order_items`,
--      `tickets`, `promo_codes`, `stripe_webhook_events`, `notifications`,
--      `hashtags`, and `post_hashtags`.
--   5. Private `stories` storage bucket read policy for active stories from
--      viewable profiles.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Helper: `public.can_view_profile_content(p_owner uuid)`
-- -----------------------------------------------------------------------------
create or replace function public.can_view_profile_content(p_owner uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_caller uuid;
  v_is_private boolean;
  v_deleted_at timestamptz;
begin
  if p_owner is null then
    return false;
  end if;

  select p.is_private, p.deleted_at
    into v_is_private, v_deleted_at
    from public.profiles p
   where p.id = p_owner;

  if not found or v_deleted_at is not null then
    return false;
  end if;

  v_caller := auth.uid();

  if v_caller is not null and v_caller = p_owner then
    return true;
  end if;

  if v_caller is not null and public.is_blocked_between(v_caller, p_owner) then
    return false;
  end if;

  if not v_is_private then
    return true;
  end if;

  if v_caller is null then
    return false;
  end if;

  return exists (
    select 1
      from public.vibes v
     where v.follower_id = v_caller
       and v.following_id = p_owner
       and v.status = 'accepted'
  );
end;
$$;

revoke all on function public.can_view_profile_content(uuid) from public;
grant execute on function public.can_view_profile_content(uuid) to anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2. Enable RLS on Every Table in `public`
-- -----------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.user_blocks enable row level security;
alter table public.user_mutes enable row level security;
alter table public.vibes enable row level security;
alter table public.locations enable row level security;
alter table public.hashtags enable row level security;
alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.post_tags enable row level security;
alter table public.post_hashtags enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;
alter table public.post_bookmarks enable row level security;
alter table public.post_shares enable row level security;
alter table public.stories enable row level security;
alter table public.story_views enable row level security;
alter table public.events enable row level security;
alter table public.event_media enable row level security;
alter table public.event_schedules enable row level security;
alter table public.event_highlights enable row level security;
alter table public.event_ticket_tiers enable row level security;
alter table public.event_rsvps enable row level security;
alter table public.event_ratings enable row level security;
alter table public.promo_codes enable row level security;
alter table public.ticket_orders enable row level security;
alter table public.ticket_order_items enable row level security;
alter table public.tickets enable row level security;
alter table public.event_staff enable row level security;
alter table public.stripe_webhook_events enable row level security;
alter table public.notifications enable row level security;
alter table public.push_tokens enable row level security;
alter table public.content_reports enable row level security;
alter table public.app_ratings enable row level security;
alter table public.faq_items enable row level security;
alter table public.support_tickets enable row level security;

-- -----------------------------------------------------------------------------
-- 3. `public.profiles` — RLS & Column-Level Grants
--    Clients CANNOT update `is_verified`, `posts_count`, `vibers_count`,
--    `vibing_count`, `deleted_at`, `created_at`, `updated_at`, or `id`.
-- -----------------------------------------------------------------------------
drop policy if exists "profiles are readable by everyone" on public.profiles;
drop policy if exists "Profiles are viewable by everyone" on public.profiles;
drop policy if exists "profiles are readable when not blocked or deleted" on public.profiles;
create policy "profiles are readable when not blocked or deleted"
  on public.profiles for select
  using (
    deleted_at is null
    and not public.is_blocked_between(auth.uid(), id)
  );

drop policy if exists "users can insert their own profile" on public.profiles;
create policy "users can insert their own profile"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id and deleted_at is null);

drop policy if exists "users can update their own profile" on public.profiles;
create policy "users can update their own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id and deleted_at is null)
  with check (auth.uid() = id and deleted_at is null);

revoke all on public.profiles from public, anon, authenticated;
grant select on public.profiles to anon, authenticated;
grant insert (
  id,
  username,
  display_name,
  bio,
  avatar_url,
  website,
  location,
  twitter_handle,
  instagram_handle,
  is_private,
  show_activity_status
) on public.profiles to authenticated;
grant update (
  username,
  display_name,
  bio,
  avatar_url,
  website,
  location,
  twitter_handle,
  instagram_handle,
  is_private,
  show_activity_status,
  last_active_at
) on public.profiles to authenticated;
grant all on public.profiles to service_role;

-- -----------------------------------------------------------------------------
-- 4. `public.user_settings` — RLS & Grants
-- -----------------------------------------------------------------------------
drop policy if exists "users can read their own settings" on public.user_settings;
create policy "users can read their own settings"
  on public.user_settings for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "users can insert their own settings" on public.user_settings;
create policy "users can insert their own settings"
  on public.user_settings for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "users can update their own settings" on public.user_settings;
create policy "users can update their own settings"
  on public.user_settings for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke all on public.user_settings from public, anon, authenticated;
grant select on public.user_settings to authenticated;
grant insert (user_id, push_notifications, email_notifications) on public.user_settings to authenticated;
grant update (push_notifications, email_notifications) on public.user_settings to authenticated;
grant all on public.user_settings to service_role;

-- -----------------------------------------------------------------------------
-- 5. `public.user_blocks` & `public.user_mutes` — RLS & Grants
-- -----------------------------------------------------------------------------
drop policy if exists "users can view their own blocks" on public.user_blocks;
create policy "users can view their own blocks"
  on public.user_blocks for select
  to authenticated
  using (auth.uid() = blocker_id);

drop policy if exists "users can block others" on public.user_blocks;
create policy "users can block others"
  on public.user_blocks for insert
  to authenticated
  with check (auth.uid() = blocker_id and blocker_id <> blocked_id);

drop policy if exists "users can unblock others" on public.user_blocks;
create policy "users can unblock others"
  on public.user_blocks for delete
  to authenticated
  using (auth.uid() = blocker_id);

revoke all on public.user_blocks from public, anon, authenticated;
grant select, delete on public.user_blocks to authenticated;
grant insert (blocker_id, blocked_id) on public.user_blocks to authenticated;
grant all on public.user_blocks to service_role;

drop policy if exists "users can view their own mutes" on public.user_mutes;
create policy "users can view their own mutes"
  on public.user_mutes for select
  to authenticated
  using (auth.uid() = muter_id);

drop policy if exists "users can mute others" on public.user_mutes;
create policy "users can mute others"
  on public.user_mutes for insert
  to authenticated
  with check (auth.uid() = muter_id and muter_id <> muted_id);

drop policy if exists "users can unmute others" on public.user_mutes;
create policy "users can unmute others"
  on public.user_mutes for delete
  to authenticated
  using (auth.uid() = muter_id);

revoke all on public.user_mutes from public, anon, authenticated;
grant select, delete on public.user_mutes to authenticated;
grant insert (muter_id, muted_id) on public.user_mutes to authenticated;
grant all on public.user_mutes to service_role;

-- -----------------------------------------------------------------------------
-- 6. `public.vibes` — RLS & Grants
--    - On insert, clients can only supply `(follower_id, following_id)`. The
--      trigger `enforce_vibe_initial_status` forces `pending` or `accepted`.
--    - Clients have NO direct `update` grant on `vibes`! Accepting or rejecting
--      a follow request goes exclusively through `respond_to_vibe_request()`.
-- -----------------------------------------------------------------------------
drop policy if exists "vibes are readable when not blocked" on public.vibes;
create policy "vibes are readable when not blocked"
  on public.vibes for select
  using (
    auth.uid() = follower_id
    or auth.uid() = following_id
    or (
      status = 'accepted'
      and public.can_view_profile_content(following_id)
    )
  );

drop policy if exists "users can request or create a vibe" on public.vibes;
create policy "users can request or create a vibe"
  on public.vibes for insert
  to authenticated
  with check (
    auth.uid() = follower_id
    and not public.is_blocked_between(follower_id, following_id)
  );

drop policy if exists "users can unvibe or remove a viber" on public.vibes;
create policy "users can unvibe or remove a viber"
  on public.vibes for delete
  to authenticated
  using (auth.uid() = follower_id or auth.uid() = following_id);

revoke all on public.vibes from public, anon, authenticated;
grant select on public.vibes to anon, authenticated;
grant insert (follower_id, following_id) on public.vibes to authenticated;
grant delete on public.vibes to authenticated;
grant all on public.vibes to service_role;

-- -----------------------------------------------------------------------------
-- 7. `public.locations` & `public.hashtags` — RLS & Grants
--    - Clients can insert locations (only `name, address, city, country,
--      latitude, longitude` — never `checkins_count`).
--    - Clients have ZERO write access to `hashtags` or `post_hashtags`!
-- -----------------------------------------------------------------------------
drop policy if exists "locations are readable by everyone" on public.locations;
create policy "locations are readable by everyone"
  on public.locations for select
  using (true);

drop policy if exists "authenticated users can add locations" on public.locations;
create policy "authenticated users can add locations"
  on public.locations for insert
  to authenticated
  with check (checkins_count = 0);

revoke all on public.locations from public, anon, authenticated;
grant select on public.locations to anon, authenticated;
grant insert (name, address, city, country, latitude, longitude) on public.locations to authenticated;
grant all on public.locations to service_role;

drop policy if exists "hashtags are readable by everyone" on public.hashtags;
create policy "hashtags are readable by everyone"
  on public.hashtags for select
  using (true);

revoke all on public.hashtags from public, anon, authenticated;
grant select on public.hashtags to anon, authenticated;
grant all on public.hashtags to service_role;

-- -----------------------------------------------------------------------------
-- 8. `public.posts`, `public.post_media`, `public.post_tags`, `public.post_hashtags`
--    - Select rules enforce `not is_hidden` and `public.can_view_profile_content`.
--    - Column-level grants block clients from editing `likes_count`,
--      `comments_count`, `shares_count`, `bookmarks_count`, or `is_hidden`.
-- -----------------------------------------------------------------------------
drop policy if exists "posts are readable when profile is viewable" on public.posts;
create policy "posts are readable when profile is viewable"
  on public.posts for select
  using (
    not is_hidden
    and (not is_archived or auth.uid() = author_id)
    and public.can_view_profile_content(author_id)
  );

drop policy if exists "users can create their own posts" on public.posts;
create policy "users can create their own posts"
  on public.posts for insert
  to authenticated
  with check (auth.uid() = author_id and not is_hidden);

drop policy if exists "users can update their own posts" on public.posts;
create policy "users can update their own posts"
  on public.posts for update
  to authenticated
  using (auth.uid() = author_id and not is_hidden)
  with check (auth.uid() = author_id and not is_hidden);

drop policy if exists "users can delete their own posts" on public.posts;
create policy "users can delete their own posts"
  on public.posts for delete
  to authenticated
  using (auth.uid() = author_id);

revoke all on public.posts from public, anon, authenticated;
grant select on public.posts to anon, authenticated;
grant insert (author_id, caption, event_id, location_id, location_name, is_archived) on public.posts to authenticated;
grant update (caption, event_id, location_id, location_name, is_archived) on public.posts to authenticated;
grant delete on public.posts to authenticated;
grant all on public.posts to service_role;

-- `post_media`
drop policy if exists "post media is readable when post is viewable" on public.post_media;
create policy "post media is readable when post is viewable"
  on public.post_media for select
  using (
    exists (
      select 1
        from public.posts p
       where p.id = post_media.post_id
         and not p.is_hidden
         and (not p.is_archived or auth.uid() = p.author_id)
         and public.can_view_profile_content(p.author_id)
    )
  );

drop policy if exists "post authors can insert post media" on public.post_media;
create policy "post authors can insert post media"
  on public.post_media for insert
  to authenticated
  with check (
    exists (
      select 1 from public.posts p
       where p.id = post_media.post_id and p.author_id = auth.uid()
    )
  );

drop policy if exists "post authors can update post media" on public.post_media;
create policy "post authors can update post media"
  on public.post_media for update
  to authenticated
  using (
    exists (
      select 1 from public.posts p
       where p.id = post_media.post_id and p.author_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.posts p
       where p.id = post_media.post_id and p.author_id = auth.uid()
    )
  );

drop policy if exists "post authors can delete post media" on public.post_media;
create policy "post authors can delete post media"
  on public.post_media for delete
  to authenticated
  using (
    exists (
      select 1 from public.posts p
       where p.id = post_media.post_id and p.author_id = auth.uid()
    )
  );

revoke all on public.post_media from public, anon, authenticated;
grant select on public.post_media to anon, authenticated;
grant insert (post_id, media_url, storage_path, thumbnail_url, media_type, width, height, duration_seconds, crop_metadata, sort_order) on public.post_media to authenticated;
grant update (media_url, storage_path, thumbnail_url, media_type, width, height, duration_seconds, crop_metadata, sort_order) on public.post_media to authenticated;
grant delete on public.post_media to authenticated;
grant all on public.post_media to service_role;

-- `post_tags`
drop policy if exists "post tags are readable when post is viewable" on public.post_tags;
create policy "post tags are readable when post is viewable"
  on public.post_tags for select
  using (
    not public.is_blocked_between(auth.uid(), tagged_user_id)
    and exists (
      select 1
        from public.posts p
       where p.id = post_tags.post_id
         and not p.is_hidden
         and (not p.is_archived or auth.uid() = p.author_id)
         and public.can_view_profile_content(p.author_id)
    )
  );

drop policy if exists "post authors can tag users" on public.post_tags;
create policy "post authors can tag users"
  on public.post_tags for insert
  to authenticated
  with check (
    not public.is_blocked_between(auth.uid(), tagged_user_id)
    and exists (
      select 1 from public.posts p
       where p.id = post_tags.post_id and p.author_id = auth.uid()
    )
  );

drop policy if exists "post authors or tagged users can remove tags" on public.post_tags;
create policy "post authors or tagged users can remove tags"
  on public.post_tags for delete
  to authenticated
  using (
    auth.uid() = tagged_user_id
    or exists (
      select 1 from public.posts p
       where p.id = post_tags.post_id and p.author_id = auth.uid()
    )
  );

revoke all on public.post_tags from public, anon, authenticated;
grant select, delete on public.post_tags to authenticated;
grant select on public.post_tags to anon;
grant insert (post_id, tagged_user_id, position_x, position_y) on public.post_tags to authenticated;
grant all on public.post_tags to service_role;

-- `post_hashtags` (read-only for clients; populated by post trigger)
drop policy if exists "post hashtags are readable when post is viewable" on public.post_hashtags;
create policy "post hashtags are readable when post is viewable"
  on public.post_hashtags for select
  using (
    exists (
      select 1
        from public.posts p
       where p.id = post_hashtags.post_id
         and not p.is_hidden
         and (not p.is_archived or auth.uid() = p.author_id)
         and public.can_view_profile_content(p.author_id)
    )
  );

revoke all on public.post_hashtags from public, anon, authenticated;
grant select on public.post_hashtags to anon, authenticated;
grant all on public.post_hashtags to service_role;

-- -----------------------------------------------------------------------------
-- 9. `public.post_likes`, `public.post_comments`, `public.post_bookmarks`, `public.post_shares`
-- -----------------------------------------------------------------------------
drop policy if exists "post likes are readable when post is viewable" on public.post_likes;
create policy "post likes are readable when post is viewable"
  on public.post_likes for select
  using (
    not public.is_blocked_between(auth.uid(), user_id)
    and exists (
      select 1
        from public.posts p
       where p.id = post_likes.post_id
         and not p.is_hidden
         and (not p.is_archived or auth.uid() = p.author_id)
         and public.can_view_profile_content(p.author_id)
    )
  );

drop policy if exists "users can like viewable posts" on public.post_likes;
create policy "users can like viewable posts"
  on public.post_likes for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1
        from public.posts p
       where p.id = post_likes.post_id
         and not p.is_hidden
         and not p.is_archived
         and public.can_view_profile_content(p.author_id)
    )
  );

drop policy if exists "users can unlike posts" on public.post_likes;
create policy "users can unlike posts"
  on public.post_likes for delete
  to authenticated
  using (auth.uid() = user_id);

revoke all on public.post_likes from public, anon, authenticated;
grant select on public.post_likes to anon, authenticated;
grant insert (post_id, user_id) on public.post_likes to authenticated;
grant delete on public.post_likes to authenticated;
grant all on public.post_likes to service_role;

-- `post_comments`
drop policy if exists "post comments are readable when post is viewable" on public.post_comments;
create policy "post comments are readable when post is viewable"
  on public.post_comments for select
  using (
    not is_hidden
    and not public.is_blocked_between(auth.uid(), author_id)
    and exists (
      select 1
        from public.posts p
       where p.id = post_comments.post_id
         and not p.is_hidden
         and (not p.is_archived or auth.uid() = p.author_id)
         and public.can_view_profile_content(p.author_id)
    )
  );

drop policy if exists "users can comment on viewable posts" on public.post_comments;
create policy "users can comment on viewable posts"
  on public.post_comments for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and not is_hidden
    and exists (
      select 1
        from public.posts p
       where p.id = post_comments.post_id
         and not p.is_hidden
         and not p.is_archived
         and public.can_view_profile_content(p.author_id)
    )
  );

drop policy if exists "users can edit their own comments" on public.post_comments;
create policy "users can edit their own comments"
  on public.post_comments for update
  to authenticated
  using (auth.uid() = author_id and not is_hidden)
  with check (auth.uid() = author_id and not is_hidden);

drop policy if exists "authors or post owners can delete comments" on public.post_comments;
create policy "authors or post owners can delete comments"
  on public.post_comments for delete
  to authenticated
  using (
    auth.uid() = author_id
    or exists (
      select 1 from public.posts p
       where p.id = post_comments.post_id and p.author_id = auth.uid()
    )
  );

revoke all on public.post_comments from public, anon, authenticated;
grant select on public.post_comments to anon, authenticated;
grant insert (post_id, author_id, parent_id, content) on public.post_comments to authenticated;
grant update (content) on public.post_comments to authenticated;
grant delete on public.post_comments to authenticated;
grant all on public.post_comments to service_role;

-- `post_bookmarks`
drop policy if exists "users can read their own bookmarks" on public.post_bookmarks;
create policy "users can read their own bookmarks"
  on public.post_bookmarks for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "users can bookmark viewable posts" on public.post_bookmarks;
create policy "users can bookmark viewable posts"
  on public.post_bookmarks for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1
        from public.posts p
       where p.id = post_bookmarks.post_id
         and not p.is_hidden
         and not p.is_archived
         and public.can_view_profile_content(p.author_id)
    )
  );

drop policy if exists "users can remove their own bookmarks" on public.post_bookmarks;
create policy "users can remove their own bookmarks"
  on public.post_bookmarks for delete
  to authenticated
  using (auth.uid() = user_id);

revoke all on public.post_bookmarks from public, anon, authenticated;
grant select, delete on public.post_bookmarks to authenticated;
grant insert (post_id, user_id) on public.post_bookmarks to authenticated;
grant all on public.post_bookmarks to service_role;

-- `post_shares`
drop policy if exists "post shares are readable by post author or sharer" on public.post_shares;
create policy "post shares are readable by post author or sharer"
  on public.post_shares for select
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.posts p
       where p.id = post_shares.post_id and p.author_id = auth.uid()
    )
  );

drop policy if exists "users can record shares on viewable posts" on public.post_shares;
create policy "users can record shares on viewable posts"
  on public.post_shares for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1
        from public.posts p
       where p.id = post_shares.post_id
         and not p.is_hidden
         and not p.is_archived
         and public.can_view_profile_content(p.author_id)
    )
  );

revoke all on public.post_shares from public, anon, authenticated;
grant select on public.post_shares to authenticated;
grant insert (post_id, user_id, channel) on public.post_shares to authenticated;
grant all on public.post_shares to service_role;

-- -----------------------------------------------------------------------------
-- 10. `public.stories` & `public.story_views` — RLS, Grants & Private Bucket Policy
--     - `stories`: no client `update` grant (counters & flame_level are trigger-only).
--     - `story_views`: readable ONLY by `viewer_id = auth.uid()` or the story's
--       `author_id = auth.uid()` (Must-fix Security #8).
--     - Viewers cannot insert view rows for other users or expired stories.
-- -----------------------------------------------------------------------------
drop policy if exists "stories are readable when profile is viewable" on public.stories;
create policy "stories are readable when profile is viewable"
  on public.stories for select
  using (
    not is_hidden
    and (
      auth.uid() = author_id
      or (
        expires_at > now()
        and public.can_view_profile_content(author_id)
      )
    )
  );

drop policy if exists "users can create their own stories" on public.stories;
create policy "users can create their own stories"
  on public.stories for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and not is_hidden
    and expires_at > now()
  );

drop policy if exists "users can delete their own stories" on public.stories;
create policy "users can delete their own stories"
  on public.stories for delete
  to authenticated
  using (auth.uid() = author_id);

revoke all on public.stories from public, anon, authenticated;
grant select on public.stories to anon, authenticated;
grant insert (
  author_id,
  media_url,
  storage_path,
  media_type,
  caption,
  text_overlay,
  font_family,
  text_color,
  text_position_x,
  text_position_y,
  expires_at
) on public.stories to authenticated;
grant delete on public.stories to authenticated;
grant all on public.stories to service_role;

-- `story_views`: ONLY viewer and story author can read!
drop policy if exists "story views readable only by viewer and story author" on public.story_views;
create policy "story views readable only by viewer and story author"
  on public.story_views for select
  to authenticated
  using (
    auth.uid() = viewer_id
    or exists (
      select 1
        from public.stories s
       where s.id = story_views.story_id
         and s.author_id = auth.uid()
    )
  );

drop policy if exists "users can record their own view on active viewable stories" on public.story_views;
create policy "users can record their own view on active viewable stories"
  on public.story_views for insert
  to authenticated
  with check (
    auth.uid() = viewer_id
    and exists (
      select 1
        from public.stories s
       where s.id = story_views.story_id
         and not s.is_hidden
         and s.expires_at > now()
         and public.can_view_profile_content(s.author_id)
    )
  );

drop policy if exists "users can toggle like on their own view of active stories" on public.story_views;
create policy "users can toggle like on their own view of active stories"
  on public.story_views for update
  to authenticated
  using (
    auth.uid() = viewer_id
    and exists (
      select 1
        from public.stories s
       where s.id = story_views.story_id
         and not s.is_hidden
         and s.expires_at > now()
         and public.can_view_profile_content(s.author_id)
    )
  )
  with check (
    auth.uid() = viewer_id
    and exists (
      select 1
        from public.stories s
       where s.id = story_views.story_id
         and not s.is_hidden
         and s.expires_at > now()
         and public.can_view_profile_content(s.author_id)
    )
  );

revoke all on public.story_views from public, anon, authenticated;
grant select on public.story_views to authenticated;
grant insert (story_id, viewer_id, liked) on public.story_views to authenticated;
grant update (liked) on public.story_views to authenticated;
grant all on public.story_views to service_role;

-- Storage policy for private `stories` bucket: allow authenticated users to
-- read/sign objects for active stories whose author they are allowed to view.
drop policy if exists "authenticated users can read active viewable story objects" on storage.objects;
create policy "authenticated users can read active viewable story objects"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'stories'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1
          from public.stories s
         where s.storage_path = storage.objects.name
           and not s.is_hidden
           and s.expires_at > now()
           and public.can_view_profile_content(s.author_id)
      )
    )
  );

-- -----------------------------------------------------------------------------
-- 11. `public.events` & Child Event Tables — RLS & Column-Level Grants
-- -----------------------------------------------------------------------------
drop policy if exists "published events are readable when not hidden or blocked" on public.events;
create policy "published events are readable when not hidden or blocked"
  on public.events for select
  using (
    not is_hidden
    and not public.is_blocked_between(auth.uid(), host_id)
    and (status <> 'draft' or auth.uid() = host_id)
  );

drop policy if exists "users can create events as host" on public.events;
create policy "users can create events as host"
  on public.events for insert
  to authenticated
  with check (auth.uid() = host_id and not is_hidden);

drop policy if exists "hosts can update their own events" on public.events;
create policy "hosts can update their own events"
  on public.events for update
  to authenticated
  using (auth.uid() = host_id and not is_hidden)
  with check (auth.uid() = host_id and not is_hidden);

revoke all on public.events from public, anon, authenticated;
grant select on public.events to anon, authenticated;
grant insert (
  host_id,
  title,
  slug,
  subtitle,
  description,
  category,
  status,
  cover_image_url,
  cover_storage_path,
  venue_name,
  address,
  city,
  latitude,
  longitude,
  location_id,
  timezone,
  starts_at,
  ends_at,
  doors_open_at,
  currency,
  capacity,
  external_ticket_url
) on public.events to authenticated;
grant update (
  title,
  slug,
  subtitle,
  description,
  category,
  status,
  cover_image_url,
  cover_storage_path,
  venue_name,
  address,
  city,
  latitude,
  longitude,
  location_id,
  timezone,
  starts_at,
  ends_at,
  doors_open_at,
  currency,
  capacity,
  external_ticket_url
) on public.events to authenticated;
grant all on public.events to service_role;

-- `event_media`
drop policy if exists "event media is readable when event is readable" on public.event_media;
create policy "event media is readable when event is readable"
  on public.event_media for select
  using (
    exists (
      select 1 from public.events e
       where e.id = event_media.event_id
         and not e.is_hidden
         and not public.is_blocked_between(auth.uid(), e.host_id)
         and (e.status <> 'draft' or auth.uid() = e.host_id)
    )
  );

drop policy if exists "hosts can manage event media" on public.event_media;
create policy "hosts can manage event media"
  on public.event_media for all
  to authenticated
  using (
    exists (
      select 1 from public.events e
       where e.id = event_media.event_id and e.host_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.events e
       where e.id = event_media.event_id and e.host_id = auth.uid()
    )
  );

revoke all on public.event_media from public, anon, authenticated;
grant select on public.event_media to anon, authenticated;
grant insert (event_id, media_url, storage_path, media_type, sort_order) on public.event_media to authenticated;
grant update (media_url, storage_path, media_type, sort_order) on public.event_media to authenticated;
grant delete on public.event_media to authenticated;
grant all on public.event_media to service_role;

-- `event_schedules`
drop policy if exists "event schedules are readable when event is readable" on public.event_schedules;
create policy "event schedules are readable when event is readable"
  on public.event_schedules for select
  using (
    exists (
      select 1 from public.events e
       where e.id = event_schedules.event_id
         and not e.is_hidden
         and not public.is_blocked_between(auth.uid(), e.host_id)
         and (e.status <> 'draft' or auth.uid() = e.host_id)
    )
  );

drop policy if exists "hosts can manage event schedules" on public.event_schedules;
create policy "hosts can manage event schedules"
  on public.event_schedules for all
  to authenticated
  using (
    exists (
      select 1 from public.events e
       where e.id = event_schedules.event_id and e.host_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.events e
       where e.id = event_schedules.event_id and e.host_id = auth.uid()
    )
  );

revoke all on public.event_schedules from public, anon, authenticated;
grant select on public.event_schedules to anon, authenticated;
grant insert (event_id, time_label, title, description, starts_at, sort_order) on public.event_schedules to authenticated;
grant update (time_label, title, description, starts_at, sort_order) on public.event_schedules to authenticated;
grant delete on public.event_schedules to authenticated;
grant all on public.event_schedules to service_role;

-- `event_highlights`
drop policy if exists "event highlights are readable when event is readable" on public.event_highlights;
create policy "event highlights are readable when event is readable"
  on public.event_highlights for select
  using (
    exists (
      select 1 from public.events e
       where e.id = event_highlights.event_id
         and not e.is_hidden
         and not public.is_blocked_between(auth.uid(), e.host_id)
         and (e.status <> 'draft' or auth.uid() = e.host_id)
    )
  );

drop policy if exists "hosts can manage event highlights" on public.event_highlights;
create policy "hosts can manage event highlights"
  on public.event_highlights for all
  to authenticated
  using (
    exists (
      select 1 from public.events e
       where e.id = event_highlights.event_id and e.host_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.events e
       where e.id = event_highlights.event_id and e.host_id = auth.uid()
    )
  );

revoke all on public.event_highlights from public, anon, authenticated;
grant select on public.event_highlights to anon, authenticated;
grant insert (event_id, label, icon_name, sort_order) on public.event_highlights to authenticated;
grant update (label, icon_name, sort_order) on public.event_highlights to authenticated;
grant delete on public.event_highlights to authenticated;
grant all on public.event_highlights to service_role;

-- `event_ticket_tiers`: hosts can manage tier settings, but NEVER `quantity_sold`
drop policy if exists "event ticket tiers are readable when event is readable" on public.event_ticket_tiers;
create policy "event ticket tiers are readable when event is readable"
  on public.event_ticket_tiers for select
  using (
    exists (
      select 1 from public.events e
       where e.id = event_ticket_tiers.event_id
         and not e.is_hidden
         and not public.is_blocked_between(auth.uid(), e.host_id)
         and (e.status <> 'draft' or auth.uid() = e.host_id)
    )
  );

drop policy if exists "hosts can insert event ticket tiers" on public.event_ticket_tiers;
create policy "hosts can insert event ticket tiers"
  on public.event_ticket_tiers for insert
  to authenticated
  with check (
    quantity_sold = 0
    and exists (
      select 1 from public.events e
       where e.id = event_ticket_tiers.event_id and e.host_id = auth.uid()
    )
  );

drop policy if exists "hosts can update event ticket tiers" on public.event_ticket_tiers;
create policy "hosts can update event ticket tiers"
  on public.event_ticket_tiers for update
  to authenticated
  using (
    exists (
      select 1 from public.events e
       where e.id = event_ticket_tiers.event_id and e.host_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.events e
       where e.id = event_ticket_tiers.event_id and e.host_id = auth.uid()
    )
  );

revoke all on public.event_ticket_tiers from public, anon, authenticated;
grant select on public.event_ticket_tiers to anon, authenticated;
grant insert (
  event_id,
  name,
  description,
  perks,
  price_cents,
  currency,
  quantity_total,
  max_per_order,
  group_size,
  sort_order,
  is_active,
  sales_start_at,
  sales_end_at
) on public.event_ticket_tiers to authenticated;
grant update (
  name,
  description,
  perks,
  price_cents,
  currency,
  quantity_total,
  max_per_order,
  group_size,
  sort_order,
  is_active,
  sales_start_at,
  sales_end_at
) on public.event_ticket_tiers to authenticated;
grant all on public.event_ticket_tiers to service_role;

-- `event_rsvps`
drop policy if exists "event rsvps are readable when not blocked" on public.event_rsvps;
create policy "event rsvps are readable when not blocked"
  on public.event_rsvps for select
  using (not public.is_blocked_between(auth.uid(), user_id));

drop policy if exists "users can insert their own event rsvp" on public.event_rsvps;
create policy "users can insert their own event rsvp"
  on public.event_rsvps for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.events e
       where e.id = event_rsvps.event_id
         and not e.is_hidden
         and e.status = 'published'
         and not public.is_blocked_between(auth.uid(), e.host_id)
    )
  );

drop policy if exists "users can update their own event rsvp" on public.event_rsvps;
create policy "users can update their own event rsvp"
  on public.event_rsvps for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "users can delete their own event rsvp" on public.event_rsvps;
create policy "users can delete their own event rsvp"
  on public.event_rsvps for delete
  to authenticated
  using (auth.uid() = user_id);

revoke all on public.event_rsvps from public, anon, authenticated;
grant select on public.event_rsvps to anon, authenticated;
grant insert (event_id, user_id, status, guests_count) on public.event_rsvps to authenticated;
grant update (status, guests_count) on public.event_rsvps to authenticated;
grant delete on public.event_rsvps to authenticated;
grant all on public.event_rsvps to service_role;

-- `event_ratings`
drop policy if exists "event ratings are readable when not blocked" on public.event_ratings;
create policy "event ratings are readable when not blocked"
  on public.event_ratings for select
  using (not public.is_blocked_between(auth.uid(), user_id));

drop policy if exists "users can insert their own event rating" on public.event_ratings;
create policy "users can insert their own event rating"
  on public.event_ratings for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.events e
       where e.id = event_ratings.event_id
         and not e.is_hidden
         and not public.is_blocked_between(auth.uid(), e.host_id)
    )
  );

drop policy if exists "users can update their own event rating" on public.event_ratings;
create policy "users can update their own event rating"
  on public.event_ratings for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "users can delete their own event rating" on public.event_ratings;
create policy "users can delete their own event rating"
  on public.event_ratings for delete
  to authenticated
  using (auth.uid() = user_id);

revoke all on public.event_ratings from public, anon, authenticated;
grant select on public.event_ratings to anon, authenticated;
grant insert (event_id, user_id, rating, review_text) on public.event_ratings to authenticated;
grant update (rating, review_text) on public.event_ratings to authenticated;
grant delete on public.event_ratings to authenticated;
grant all on public.event_ratings to service_role;

-- -----------------------------------------------------------------------------
-- 12. Ticketing & Financial Tables — SERVER-ONLY Writes
--     - `promo_codes`: NO client select, insert, update, or delete!
--       Validated only via `validate_promo_code(p_event_id, p_code)`.
--     - `ticket_orders`, `ticket_order_items`, `tickets`: clients have READ
--       ONLY (`select`) on their own rows (or event host rows). ZERO client
--       insert, update, or delete!
--     - `stripe_webhook_events`: service_role only.
-- -----------------------------------------------------------------------------
revoke all on public.promo_codes from public, anon, authenticated;
grant all on public.promo_codes to service_role;

drop policy if exists "buyers and hosts can read ticket orders" on public.ticket_orders;
create policy "buyers and hosts can read ticket orders"
  on public.ticket_orders for select
  to authenticated
  using (
    auth.uid() = buyer_id
    or exists (
      select 1 from public.events e
       where e.id = ticket_orders.event_id and e.host_id = auth.uid()
    )
  );

revoke all on public.ticket_orders from public, anon, authenticated;
grant select on public.ticket_orders to authenticated;
grant all on public.ticket_orders to service_role;

drop policy if exists "buyers and hosts can read ticket order items" on public.ticket_order_items;
create policy "buyers and hosts can read ticket order items"
  on public.ticket_order_items for select
  to authenticated
  using (
    exists (
      select 1
        from public.ticket_orders o
       where o.id = ticket_order_items.order_id
         and (
           o.buyer_id = auth.uid()
           or exists (
             select 1 from public.events e
              where e.id = o.event_id and e.host_id = auth.uid()
           )
         )
    )
  );

revoke all on public.ticket_order_items from public, anon, authenticated;
grant select on public.ticket_order_items to authenticated;
grant all on public.ticket_order_items to service_role;

drop policy if exists "owners, hosts, and staff can read tickets" on public.tickets;
create policy "owners, hosts, and staff can read tickets"
  on public.tickets for select
  to authenticated
  using (
    auth.uid() = owner_id
    or exists (
      select 1 from public.events e
       where e.id = tickets.event_id and e.host_id = auth.uid()
    )
    or exists (
      select 1 from public.event_staff es
       where es.event_id = tickets.event_id and es.user_id = auth.uid()
    )
  );

revoke all on public.tickets from public, anon, authenticated;
grant select on public.tickets to authenticated;
grant all on public.tickets to service_role;

-- `event_staff`: readable by host or the staff member; managed by event host
drop policy if exists "hosts and staff can read event staff" on public.event_staff;
create policy "hosts and staff can read event staff"
  on public.event_staff for select
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.events e
       where e.id = event_staff.event_id and e.host_id = auth.uid()
    )
  );

drop policy if exists "hosts can manage event staff" on public.event_staff;
create policy "hosts can manage event staff"
  on public.event_staff for all
  to authenticated
  using (
    exists (
      select 1 from public.events e
       where e.id = event_staff.event_id and e.host_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.events e
       where e.id = event_staff.event_id and e.host_id = auth.uid()
    )
  );

revoke all on public.event_staff from public, anon, authenticated;
grant select, delete on public.event_staff to authenticated;
grant insert (event_id, user_id, role) on public.event_staff to authenticated;
grant update (role) on public.event_staff to authenticated;
grant all on public.event_staff to service_role;

-- `stripe_webhook_events`: service_role only
revoke all on public.stripe_webhook_events from public, anon, authenticated;
grant all on public.stripe_webhook_events to service_role;

-- -----------------------------------------------------------------------------
-- 13. Notifications, Push Tokens, Reports, Ratings, FAQs & Support
-- -----------------------------------------------------------------------------
-- `notifications`: NO client insert or delete! Column-level update on `(is_read, read_at)` only.
drop policy if exists "users can read their own notifications" on public.notifications;
create policy "users can read their own notifications"
  on public.notifications for select
  to authenticated
  using (auth.uid() = recipient_id);

drop policy if exists "users can mark their own notifications read" on public.notifications;
create policy "users can mark their own notifications read"
  on public.notifications for update
  to authenticated
  using (auth.uid() = recipient_id)
  with check (auth.uid() = recipient_id);

revoke all on public.notifications from public, anon, authenticated;
grant select on public.notifications to authenticated;
grant update (is_read, read_at) on public.notifications to authenticated;
grant all on public.notifications to service_role;

-- `push_tokens`
drop policy if exists "users can manage their own push tokens" on public.push_tokens;
create policy "users can manage their own push tokens"
  on public.push_tokens for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke all on public.push_tokens from public, anon, authenticated;
grant select, delete on public.push_tokens to authenticated;
grant insert (user_id, expo_push_token, device_label) on public.push_tokens to authenticated;
grant update (expo_push_token, device_label) on public.push_tokens to authenticated;
grant all on public.push_tokens to service_role;

-- `content_reports`: users can create and read their own; admin status updates are service_role only
drop policy if exists "users can read their own content reports" on public.content_reports;
create policy "users can read their own content reports"
  on public.content_reports for select
  to authenticated
  using (auth.uid() = reporter_id);

drop policy if exists "users can submit content reports" on public.content_reports;
create policy "users can submit content reports"
  on public.content_reports for insert
  to authenticated
  with check (auth.uid() = reporter_id and status = 'open');

revoke all on public.content_reports from public, anon, authenticated;
grant select on public.content_reports to authenticated;
grant insert (reporter_id, target_type, target_id, reason, details) on public.content_reports to authenticated;
grant all on public.content_reports to service_role;

-- `app_ratings`
drop policy if exists "users can manage their own app rating" on public.app_ratings;
create policy "users can manage their own app rating"
  on public.app_ratings for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke all on public.app_ratings from public, anon, authenticated;
grant select on public.app_ratings to authenticated;
grant insert (user_id, rating, feedback, app_version) on public.app_ratings to authenticated;
grant update (rating, feedback, app_version) on public.app_ratings to authenticated;
grant all on public.app_ratings to service_role;

-- `faq_items`: read-only for clients
drop policy if exists "published faq items are readable by everyone" on public.faq_items;
create policy "published faq items are readable by everyone"
  on public.faq_items for select
  using (is_published = true);

revoke all on public.faq_items from public, anon, authenticated;
grant select on public.faq_items to anon, authenticated;
grant all on public.faq_items to service_role;

-- `support_tickets`: users can create and read their own; status changes are service_role only
drop policy if exists "users can read their own support tickets" on public.support_tickets;
create policy "users can read their own support tickets"
  on public.support_tickets for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "users can create support tickets" on public.support_tickets;
create policy "users can create support tickets"
  on public.support_tickets for insert
  to authenticated
  with check (auth.uid() = user_id and status = 'open');

revoke all on public.support_tickets from public, anon, authenticated;
grant select on public.support_tickets to authenticated;
grant insert (user_id, subject, message, category) on public.support_tickets to authenticated;
grant all on public.support_tickets to service_role;

-- #############################################################################
-- FILE: 20261124000007_rpc_functions.sql
-- #############################################################################

-- =============================================================================
-- LIT Social — Migration 20261124000007: RPC Functions
-- Target: Self-hosted Supabase (PostgreSQL 15+)
-- Security Rules:
--   - Every `security definer` function uses `set search_path = ''`, fully
--     schema-qualified identifiers, `revoke all ... from public, anon`, and
--     explicit `grant execute` ONLY to the roles that need it.
-- Contents:
--   1. `public.respond_to_vibe_request(p_follower uuid, p_accept boolean)`
--   2. `public.record_story_view(p_story_id uuid, p_liked boolean)`
--   3. `public.validate_promo_code(p_event_id uuid, p_code text)`
--   4. `public.create_pending_ticket_order(...)` (service_role only; locks tiers
--      `for update` to prevent overselling)
--   5. `public.fulfill_order(p_order_id uuid, p_payment_intent text)`
--      (service_role only; idempotent Stripe fulfillment)
--   6. `public.check_in_ticket(p_qr_payload text, p_event_id uuid)`
--      (host or `event_staff` only; row lock `for update`)
--   7. `public.request_account_deletion()` (soft-delete & anonymization while
--      preserving financial records; blocks hosts with upcoming paid events)
--   8. `public.get_home_feed(...)` (security invoker; keyset cursor pagination)
--   9. `public.get_stories_tray()` (security invoker; grouped by author, unseen first)
--  10. `public.search_all(p_query text, p_limit int)` (security invoker; trigram search)
--  11. `public.recompute_counters()` (service_role only; drift repair function)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. `public.respond_to_vibe_request(p_follower uuid, p_accept boolean)`
--    Only the FOLLOWED user (`following_id = auth.uid()`) can accept or decline
--    a pending follow request.
-- -----------------------------------------------------------------------------
create or replace function public.respond_to_vibe_request(
  p_follower uuid,
  p_accept boolean
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid;
  v_vibe_id uuid;
begin
  v_caller := auth.uid();
  if v_caller is null then
    raise exception 'Not authenticated.';
  end if;

  if p_follower is null then
    raise exception 'Follower user ID is required.';
  end if;

  select v.id
    into v_vibe_id
    from public.vibes v
   where v.follower_id = p_follower
     and v.following_id = v_caller
     and v.status = 'pending'
     for update;

  if not found then
    raise exception 'No pending vibe request found from this user.';
  end if;

  if p_accept then
    update public.vibes
       set status     = 'accepted',
           updated_at = pg_catalog.now()
     where id = v_vibe_id;
    return 'accepted';
  else
    delete from public.vibes
     where id = v_vibe_id;
    return 'declined';
  end if;
end;
$$;

revoke all on function public.respond_to_vibe_request(uuid, boolean) from public, anon;
grant execute on function public.respond_to_vibe_request(uuid, boolean) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2. `public.record_story_view(p_story_id uuid, p_liked boolean default false)`
-- -----------------------------------------------------------------------------
create or replace function public.record_story_view(
  p_story_id uuid,
  p_liked boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid;
  v_author_id uuid;
  v_expires_at timestamptz;
  v_is_hidden boolean;
begin
  v_caller := auth.uid();
  if v_caller is null then
    raise exception 'Not authenticated.';
  end if;

  select s.author_id, s.expires_at, s.is_hidden
    into v_author_id, v_expires_at, v_is_hidden
    from public.stories s
   where s.id = p_story_id;

  if not found or v_is_hidden then
    raise exception 'Story not found.';
  end if;

  if v_expires_at <= pg_catalog.now() then
    raise exception 'Story has expired.';
  end if;

  if not public.can_view_profile_content(v_author_id) then
    raise exception 'Not authorized to view this story.';
  end if;

  insert into public.story_views (story_id, viewer_id, liked, viewed_at)
  values (p_story_id, v_caller, coalesce(p_liked, false), pg_catalog.now())
  on conflict (story_id, viewer_id) do update
    set liked = excluded.liked;
end;
$$;

revoke all on function public.record_story_view(uuid, boolean) from public, anon;
grant execute on function public.record_story_view(uuid, boolean) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. `public.validate_promo_code(p_event_id uuid, p_code text)`
--    Validates a promo code without exposing the `promo_codes` table.
-- -----------------------------------------------------------------------------
create or replace function public.validate_promo_code(
  p_event_id uuid,
  p_code text
)
returns table (
  promo_code_id uuid,
  code text,
  discount_percent smallint,
  discount_amount_cents integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_caller uuid;
  v_clean_code text;
begin
  v_caller := auth.uid();
  if v_caller is null then
    raise exception 'Not authenticated.';
  end if;

  v_clean_code := pg_catalog.btrim(coalesce(p_code, ''));
  if v_clean_code = '' then
    raise exception 'Promo code is required.';
  end if;

  return query
  select pc.id,
         pc.code,
         pc.discount_percent,
         pc.discount_amount_cents
    from public.promo_codes pc
   where pg_catalog.upper(pc.code) = pg_catalog.upper(v_clean_code)
     and pc.is_active = true
     and (pc.event_id is null or pc.event_id = p_event_id)
     and (pc.expires_at is null or pc.expires_at > pg_catalog.now())
     and (pc.max_uses is null or pc.uses_count < pc.max_uses)
   limit 1;

  if not found then
    raise exception 'Invalid, expired, or exhausted promo code.';
  end if;
end;
$$;

revoke all on function public.validate_promo_code(uuid, text) from public, anon;
grant execute on function public.validate_promo_code(uuid, text) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4. `public.create_pending_ticket_order(...)` — SERVER-ONLY (`service_role`)
--    Atomically locks ticket tier rows `for update`, reserves stock so two
--    buyers cannot both claim the last ticket, validates optional promo code,
--    and creates a `'pending'` order ready for Stripe PaymentIntent creation.
--    `p_items` format: `[{"tier_id": "<uuid>", "quantity": 2}, ...]`
-- -----------------------------------------------------------------------------
create or replace function public.create_pending_ticket_order(
  p_buyer_id uuid,
  p_event_id uuid,
  p_items jsonb,
  p_promo_code text default null,
  p_service_fee_cents integer default 0
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event_title text;
  v_event_status text;
  v_event_currency text;
  v_buyer_name text;
  v_order_id uuid;
  v_item jsonb;
  v_tier_id uuid;
  v_qty integer;
  v_tier record;
  v_subtotal integer := 0;
  v_discount integer := 0;
  v_total integer := 0;
  v_promo_id uuid;
  v_promo_code_norm text;
  v_promo_pct smallint;
  v_promo_amt integer;
begin
  if p_buyer_id is null or p_event_id is null then
    raise exception 'Buyer ID and Event ID are required.';
  end if;

  if p_items is null or pg_catalog.jsonb_typeof(p_items) <> 'array' or pg_catalog.jsonb_array_length(p_items) = 0 then
    raise exception 'Order must contain at least one ticket item.';
  end if;

  select e.title, e.status, e.currency
    into v_event_title, v_event_status, v_event_currency
    from public.events e
   where e.id = p_event_id and not e.is_hidden;

  if not found or v_event_status <> 'published' then
    raise exception 'Event is not available for ticket sales.';
  end if;

  select coalesce(p.display_name, p.username)
    into v_buyer_name
    from public.profiles p
   where p.id = p_buyer_id and p.deleted_at is null;

  if not found then
    raise exception 'Buyer profile not found.';
  end if;

  -- Create the pending order shell first
  insert into public.ticket_orders (
    buyer_id,
    buyer_display_name_snapshot,
    event_id,
    event_title_snapshot,
    currency,
    status,
    stock_reserved,
    service_fee_cents
  )
  values (
    p_buyer_id,
    v_buyer_name,
    p_event_id,
    v_event_title,
    v_event_currency,
    'pending',
    true,
    greatest(0, coalesce(p_service_fee_cents, 0))
  )
  returning id into v_order_id;

  -- Lock each tier `for update` in deterministic order and reserve stock
  for v_item in
    select value
      from pg_catalog.jsonb_array_elements(p_items)
     order by (value ->> 'tier_id')
  loop
    v_tier_id := (v_item ->> 'tier_id')::uuid;
    v_qty := (v_item ->> 'quantity')::integer;

    if v_qty is null or v_qty <= 0 then
      raise exception 'Ticket quantity must be positive.';
    end if;

    select t.*
      into v_tier
      from public.event_ticket_tiers t
     where t.id = v_tier_id
       and t.event_id = p_event_id
       and t.is_active = true
       for update;

    if not found then
      raise exception 'Ticket tier % is not active for this event.', v_tier_id;
    end if;

    if v_qty > v_tier.max_per_order then
      raise exception 'Quantity (%) exceeds max_per_order (%) for tier %.', v_qty, v_tier.max_per_order, v_tier.name;
    end if;

    if v_tier.quantity_sold + v_qty > v_tier.quantity_total then
      raise exception 'Not enough tickets remaining for tier % (requested %, available %).',
        v_tier.name, v_qty, (v_tier.quantity_total - v_tier.quantity_sold);
    end if;

    update public.event_ticket_tiers
       set quantity_sold = quantity_sold + v_qty
     where id = v_tier_id;

    insert into public.ticket_order_items (
      order_id,
      tier_id,
      tier_name,
      group_size,
      unit_price_cents,
      quantity,
      line_total_cents
    )
    values (
      v_order_id,
      v_tier_id,
      v_tier.name,
      v_tier.group_size,
      v_tier.price_cents,
      v_qty,
      v_tier.price_cents * v_qty
    );

    v_subtotal := v_subtotal + (v_tier.price_cents * v_qty);
  end loop;

  -- Optional promo code validation (without incrementing uses_count until paid)
  if p_promo_code is not null and pg_catalog.btrim(p_promo_code) <> '' then
    select pc.id, pc.code, pc.discount_percent, pc.discount_amount_cents
      into v_promo_id, v_promo_code_norm, v_promo_pct, v_promo_amt
      from public.promo_codes pc
     where pg_catalog.upper(pc.code) = pg_catalog.upper(pg_catalog.btrim(p_promo_code))
       and pc.is_active = true
       and (pc.event_id is null or pc.event_id = p_event_id)
       and (pc.expires_at is null or pc.expires_at > pg_catalog.now())
       and (pc.max_uses is null or pc.uses_count < pc.max_uses)
       for update;

    if not found then
      raise exception 'Invalid, expired, or exhausted promo code.';
    end if;

    if v_promo_pct is not null then
      v_discount := (v_subtotal * v_promo_pct) / 100;
    else
      v_discount := least(v_subtotal, coalesce(v_promo_amt, 0));
    end if;
  end if;

  v_total := greatest(0, v_subtotal - v_discount) + greatest(0, coalesce(p_service_fee_cents, 0));

  update public.ticket_orders
     set promo_code_id = v_promo_id,
         promo_code_text = v_promo_code_norm,
         subtotal_cents = v_subtotal,
         discount_cents = v_discount,
         total_cents = v_total
   where id = v_order_id;

  return v_order_id;
end;
$$;

revoke all on function public.create_pending_ticket_order(uuid, uuid, jsonb, text, integer)
  from public, anon, authenticated;
grant execute on function public.create_pending_ticket_order(uuid, uuid, jsonb, text, integer)
  to service_role;

-- -----------------------------------------------------------------------------
-- 5. `public.fulfill_order(p_order_id uuid, p_payment_intent text)`
--    SERVER-ONLY (`service_role`). Idempotent: calling twice for the same order
--    returns `true` without issuing duplicate tickets or double-counting stock.
-- -----------------------------------------------------------------------------
create or replace function public.fulfill_order(
  p_order_id uuid,
  p_payment_intent text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order record;
  v_item record;
  v_tier record;
  v_i integer;
  v_tickets_created integer := 0;
  v_first_ticket_id uuid;
begin
  if p_order_id is null or p_payment_intent is null or pg_catalog.btrim(p_payment_intent) = '' then
    raise exception 'Order ID and payment intent ID are required.';
  end if;

  select o.*
    into v_order
    from public.ticket_orders o
   where o.id = p_order_id
     for update;

  if not found then
    raise exception 'Order % not found.', p_order_id;
  end if;

  -- Idempotency guard: if already paid, do nothing and succeed
  if v_order.status = 'paid' then
    return true;
  end if;

  if v_order.status <> 'pending' then
    raise exception 'Cannot fulfill order % with status %.', p_order_id, v_order.status;
  end if;

  -- Increment promo code `uses_count` server-side with row lock
  if v_order.promo_code_id is not null then
    update public.promo_codes
       set uses_count = uses_count + 1
     where id = v_order.promo_code_id
       and is_active = true
       and (max_uses is null or uses_count < max_uses);

    if not found then
      raise exception 'Promo code on order % is no longer available.', p_order_id;
    end if;
  end if;

  -- Issue individual QR tickets for each order item
  for v_item in
    select oi.*
      from public.ticket_order_items oi
     where oi.order_id = p_order_id
     order by oi.tier_id
  loop
    select t.*
      into v_tier
      from public.event_ticket_tiers t
     where t.id = v_item.tier_id
       for update;

    -- If stock was not pre-reserved on the order, reserve/decrement now with lock
    if not v_order.stock_reserved then
      if v_tier.quantity_sold + v_item.quantity > v_tier.quantity_total then
        raise exception 'Tier % is sold out.', v_tier.name;
      end if;

      update public.event_ticket_tiers
         set quantity_sold = quantity_sold + v_item.quantity
       where id = v_item.tier_id;
    end if;

    for v_i in 1..v_item.quantity loop
      insert into public.tickets (
        order_id,
        order_item_id,
        event_id,
        tier_id,
        owner_id,
        holder_name_snapshot,
        event_title_snapshot,
        tier_name,
        admits_count,
        status
      )
      values (
        v_order.id,
        v_item.id,
        v_order.event_id,
        v_item.tier_id,
        v_order.buyer_id,
        v_order.buyer_display_name_snapshot,
        v_order.event_title_snapshot,
        v_item.tier_name,
        v_tier.group_size,
        'valid'
      )
      returning id into v_first_ticket_id;

      v_tickets_created := v_tickets_created + 1;
    end loop;
  end loop;

  -- Mark order paid
  update public.ticket_orders
     set status                   = 'paid',
         stripe_payment_intent_id = pg_catalog.btrim(p_payment_intent),
         stock_reserved           = true,
         paid_at                  = pg_catalog.now()
   where id = p_order_id;

  -- Increment `tickets_sold_count` on the event
  update public.events
     set tickets_sold_count = tickets_sold_count + v_tickets_created
   where id = v_order.event_id;

  -- Auto-upsert `'going'` RSVP for the buyer
  if v_order.buyer_id is not null then
    insert into public.event_rsvps (event_id, user_id, status)
    values (v_order.event_id, v_order.buyer_id, 'going')
    on conflict (event_id, user_id) do update
      set status     = 'going',
          updated_at = pg_catalog.now();

    perform public.create_notification_internal(
      v_order.buyer_id,
      null,
      'ticket_purchased',
      'Ticket Confirmed: ' || coalesce(v_order.event_title_snapshot, 'Event'),
      'Your ' || v_tickets_created::text || ' ticket(s) are ready.',
      null,
      v_order.event_id,
      v_first_ticket_id
    );
  end if;

  return true;
end;
$$;

revoke all on function public.fulfill_order(uuid, text) from public, anon, authenticated;
grant execute on function public.fulfill_order(uuid, text) to service_role;

-- -----------------------------------------------------------------------------
-- 6. `public.check_in_ticket(p_qr_payload text, p_event_id uuid default null)`
--    Must-fix Security #2:
--    - Verifies caller is the event's `host_id` or listed in `public.event_staff`.
--    - Locks the ticket row (`for update`).
--    - Rejects tickets that are already `'used'`, `'cancelled'`, `'transferred'`,
--      or for another event.
--    - Sets `status = 'used'`, `checked_in_at`, and `checked_in_by`.
-- -----------------------------------------------------------------------------
create or replace function public.check_in_ticket(
  p_qr_payload text,
  p_event_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid;
  v_ticket record;
  v_authorized boolean;
begin
  v_caller := auth.uid();
  if v_caller is null then
    raise exception 'Not authenticated.';
  end if;

  if p_qr_payload is null or pg_catalog.btrim(p_qr_payload) = '' then
    raise exception 'QR payload is required.';
  end if;

  select t.*
    into v_ticket
    from public.tickets t
   where t.qr_payload = pg_catalog.btrim(p_qr_payload)
     for update;

  if not found then
    raise exception 'Ticket not found.';
  end if;

  if p_event_id is not null and v_ticket.event_id <> p_event_id then
    raise exception 'Ticket belongs to a different event.';
  end if;

  select exists (
    select 1
      from public.events e
     where e.id = v_ticket.event_id
       and e.host_id = v_caller
    union all
    select 1
      from public.event_staff es
     where es.event_id = v_ticket.event_id
       and es.user_id = v_caller
  ) into v_authorized;

  if not v_authorized then
    raise exception 'Not authorized to check in tickets for this event.';
  end if;

  if v_ticket.status <> 'valid' then
    raise exception 'Ticket cannot be checked in (current status: %).', v_ticket.status;
  end if;

  update public.tickets
     set status        = 'used',
         checked_in_at = pg_catalog.now(),
         checked_in_by = v_caller
   where id = v_ticket.id;

  return pg_catalog.jsonb_build_object(
    'ticket_id', v_ticket.id,
    'ticket_code', v_ticket.ticket_code,
    'event_id', v_ticket.event_id,
    'tier_name', v_ticket.tier_name,
    'admits_count', v_ticket.admits_count,
    'status', 'used',
    'checked_in_at', pg_catalog.now(),
    'checked_in_by', v_caller
  );
end;
$$;

revoke all on function public.check_in_ticket(text, uuid) from public, anon;
grant execute on function public.check_in_ticket(text, uuid) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 7. `public.request_account_deletion()`
--    - Blocks deletion if caller hosts upcoming paid/ticketed events.
--    - Preserves financial records (`ticket_orders`, `ticket_order_items`, `tickets`)
--      with snapshots.
--    - Deletes user's posts, stories, vibes, blocks, mutes, push_tokens, RSVPs.
--    - Anonymizes `public.profiles` (`deleted_at = now()`, `username = 'deleted_<shortid>'`).
-- -----------------------------------------------------------------------------
create or replace function public.request_account_deletion()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid;
  v_short_id text;
  v_display_name text;
begin
  v_caller := auth.uid();
  if v_caller is null then
    raise exception 'Not authenticated.';
  end if;

  -- Block hosts who have upcoming non-cancelled events with ticket sales or paid tiers
  if exists (
    select 1
      from public.events e
     where e.host_id = v_caller
       and e.status in ('draft', 'published')
       and e.starts_at > pg_catalog.now()
       and (
         e.tickets_sold_count > 0
         or not e.is_free
         or exists (
           select 1
             from public.ticket_orders o
            where o.event_id = e.id
              and o.status in ('pending', 'paid')
         )
       )
  ) then
    raise exception 'Cannot delete account while hosting upcoming paid events. Cancel and refund those events first.';
  end if;

  select coalesce(p.display_name, p.username, 'Deleted User')
    into v_display_name
    from public.profiles p
   where p.id = v_caller
     for update;

  if not found then
    raise exception 'Profile not found.';
  end if;

  -- Snapshot buyer/holder name on financial records before anonymizing
  update public.ticket_orders
     set buyer_display_name_snapshot = coalesce(buyer_display_name_snapshot, v_display_name)
   where buyer_id = v_caller;

  update public.tickets
     set holder_name_snapshot = coalesce(holder_name_snapshot, v_display_name)
   where owner_id = v_caller;

  -- Delete user's social content (triggers decrement counters cleanly)
  delete from public.posts where author_id = v_caller;
  delete from public.stories where author_id = v_caller;
  delete from public.vibes where follower_id = v_caller or following_id = v_caller;
  delete from public.user_blocks where blocker_id = v_caller or blocked_id = v_caller;
  delete from public.user_mutes where muter_id = v_caller or muted_id = v_caller;
  delete from public.push_tokens where user_id = v_caller;
  delete from public.event_rsvps where user_id = v_caller;

  v_short_id := pg_catalog.lower(pg_catalog.substr(pg_catalog.replace(v_caller::text, '-', ''), 1, 12));

  update public.profiles
     set username             = 'deleted_' || v_short_id,
         display_name         = 'Deleted User',
         bio                  = null,
         avatar_url           = null,
         website              = null,
         location             = null,
         twitter_handle       = null,
         instagram_handle     = null,
         is_private           = true,
         show_activity_status = false,
         is_verified          = false,
         posts_count          = 0,
         vibers_count         = 0,
         vibing_count         = 0,
         deleted_at           = pg_catalog.now()
   where id = v_caller;
end;
$$;

revoke all on function public.request_account_deletion() from public, anon;
grant execute on function public.request_account_deletion() to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 8. `public.get_home_feed(...)` — Keyset-Paginated Home Feed (`security invoker`)
--    Uses fan-out-on-read: posts from accepted vibing + own posts, excluding
--    hidden, archived, blocked, and muted authors.
--    NOTE: Fan-out-on-write (a materialized `feed_items` table) is the upgrade
--    path at scale; fan-out-on-read with `(author_id, created_at desc, id desc)`
--    is used for MVP.
-- -----------------------------------------------------------------------------
create or replace function public.get_home_feed(
  p_before_created_at timestamptz default null,
  p_before_id uuid default null,
  p_limit int default 20
)
returns table (
  id uuid,
  author_id uuid,
  author_username text,
  author_display_name text,
  author_avatar_url text,
  author_is_verified boolean,
  caption text,
  event_id uuid,
  location_id uuid,
  location_name text,
  likes_count integer,
  comments_count integer,
  shares_count integer,
  bookmarks_count integer,
  liked_by_me boolean,
  bookmarked_by_me boolean,
  created_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select p.id,
         p.author_id,
         pr.username as author_username,
         pr.display_name as author_display_name,
         pr.avatar_url as author_avatar_url,
         pr.is_verified as author_is_verified,
         p.caption,
         p.event_id,
         p.location_id,
         p.location_name,
         p.likes_count,
         p.comments_count,
         p.shares_count,
         p.bookmarks_count,
         exists (
           select 1
             from public.post_likes pl
            where pl.post_id = p.id
              and pl.user_id = auth.uid()
         ) as liked_by_me,
         exists (
           select 1
             from public.post_bookmarks pb
            where pb.post_id = p.id
              and pb.user_id = auth.uid()
         ) as bookmarked_by_me,
         p.created_at
    from public.posts p
    join public.profiles pr on pr.id = p.author_id
   where not p.is_hidden
     and not p.is_archived
     and pr.deleted_at is null
     and (
       p.author_id = auth.uid()
       or exists (
         select 1
           from public.vibes v
          where v.follower_id = auth.uid()
            and v.following_id = p.author_id
            and v.status = 'accepted'
       )
     )
     and not public.is_blocked_between(auth.uid(), p.author_id)
     and not exists (
       select 1
         from public.user_mutes m
        where m.muter_id = auth.uid()
          and m.muted_id = p.author_id
     )
     and (
       p_before_created_at is null
       or (p.created_at, p.id) < (p_before_created_at, coalesce(p_before_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid))
     )
   order by p.created_at desc, p.id desc
   limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;

revoke all on function public.get_home_feed(timestamptz, uuid, int) from public, anon;
grant execute on function public.get_home_feed(timestamptz, uuid, int) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 9. `public.get_stories_tray()` — Active Stories Grouped by Author (`security invoker`)
--    Returns active (`expires_at > now()`) stories from people the caller vibes
--    with (plus own stories), excluding blocked/muted users, ordered with
--    `has_unseen` first.
-- -----------------------------------------------------------------------------
create or replace function public.get_stories_tray()
returns table (
  author_id uuid,
  author_username text,
  author_display_name text,
  author_avatar_url text,
  stories_count bigint,
  has_unseen boolean,
  max_flame_level smallint,
  latest_story_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select s.author_id,
         pr.username as author_username,
         pr.display_name as author_display_name,
         pr.avatar_url as author_avatar_url,
         count(s.id) as stories_count,
         pg_catalog.bool_or(sv.id is null) as has_unseen,
         max(s.flame_level) as max_flame_level,
         max(s.created_at) as latest_story_at
    from public.stories s
    join public.profiles pr on pr.id = s.author_id
    left join public.story_views sv
      on sv.story_id = s.id
     and sv.viewer_id = auth.uid()
   where not s.is_hidden
     and s.expires_at > pg_catalog.now()
     and pr.deleted_at is null
     and (
       s.author_id = auth.uid()
       or exists (
         select 1
           from public.vibes v
          where v.follower_id = auth.uid()
            and v.following_id = s.author_id
            and v.status = 'accepted'
       )
     )
     and not public.is_blocked_between(auth.uid(), s.author_id)
     and not exists (
       select 1
         from public.user_mutes m
        where m.muter_id = auth.uid()
          and m.muted_id = s.author_id
     )
   group by s.author_id, pr.username, pr.display_name, pr.avatar_url
   order by (s.author_id = auth.uid()) desc,
            pg_catalog.bool_or(sv.id is null) desc,
            max(s.created_at) desc;
$$;

revoke all on function public.get_stories_tray() from public, anon;
grant execute on function public.get_stories_tray() to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 10. `public.search_all(p_query text, p_limit int default 20)` (`security invoker`)
--     Powers "Search people, events, tags…" using trigram indexes while
--     respecting blocks, soft-deleted profiles, and hidden content.
-- -----------------------------------------------------------------------------
create or replace function public.search_all(
  p_query text,
  p_limit int default 20
)
returns table (
  entity_type text,
  entity_id uuid,
  title text,
  subtitle text,
  image_url text,
  metric_value integer
)
language sql
stable
security invoker
set search_path = ''
as $$
  with clean_q as (
    select pg_catalog.btrim(coalesce(p_query, '')) as q,
           least(greatest(coalesce(p_limit, 20), 1), 50) as lim
  )
  (
    select 'person'::text as entity_type,
           pr.id as entity_id,
           coalesce(pr.display_name, pr.username) as title,
           '@' || coalesce(pr.username, '') as subtitle,
           pr.avatar_url as image_url,
           pr.vibers_count as metric_value
      from public.profiles pr
      cross join clean_q cq
     where cq.q <> ''
       and pr.deleted_at is null
       and not public.is_blocked_between(auth.uid(), pr.id)
       and (
         pr.username ilike '%' || cq.q || '%'
         or pr.display_name ilike '%' || cq.q || '%'
       )
     order by pr.vibers_count desc, pr.id desc
     limit (select lim from clean_q)
  )
  union all
  (
    select 'event'::text as entity_type,
           e.id as entity_id,
           e.title as title,
           e.venue_name || coalesce(' · ' || e.city, '') as subtitle,
           e.cover_image_url as image_url,
           e.going_count as metric_value
      from public.events e
      cross join clean_q cq
     where cq.q <> ''
       and not e.is_hidden
       and e.status = 'published'
       and not public.is_blocked_between(auth.uid(), e.host_id)
       and (
         e.title ilike '%' || cq.q || '%'
         or e.venue_name ilike '%' || cq.q || '%'
         or e.city ilike '%' || cq.q || '%'
       )
     order by e.starts_at asc, e.id asc
     limit (select lim from clean_q)
  )
  union all
  (
    select 'hashtag'::text as entity_type,
           h.id as entity_id,
           h.display_tag as title,
           h.usage_count::text || ' posts' as subtitle,
           null::text as image_url,
           h.usage_count as metric_value
      from public.hashtags h
      cross join clean_q cq
     where cq.q <> ''
       and h.tag ilike '%' || pg_catalog.ltrim(cq.q, '#') || '%'
     order by h.is_trending desc, h.usage_count desc, h.id desc
     limit (select lim from clean_q)
  );
$$;

revoke all on function public.search_all(text, int) from public;
grant execute on function public.search_all(text, int) to anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 11. `public.recompute_counters()` — Drift Repair Function (`service_role` Only)
-- -----------------------------------------------------------------------------
create or replace function public.recompute_counters()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Profiles: posts_count, vibers_count, vibing_count
  update public.profiles pr
     set posts_count = (
           select count(*)
             from public.posts p
            where p.author_id = pr.id
              and not p.is_archived
              and not p.is_hidden
         ),
         vibers_count = (
           select count(*)
             from public.vibes v
            where v.following_id = pr.id
              and v.status = 'accepted'
         ),
         vibing_count = (
           select count(*)
             from public.vibes v
            where v.follower_id = pr.id
              and v.status = 'accepted'
         );

  -- Posts: likes_count, comments_count, shares_count, bookmarks_count
  update public.posts p
     set likes_count = (
           select count(*) from public.post_likes pl where pl.post_id = p.id
         ),
         comments_count = (
           select count(*) from public.post_comments pc where pc.post_id = p.id and not pc.is_hidden
         ),
         shares_count = (
           select count(*) from public.post_shares ps where ps.post_id = p.id
         ),
         bookmarks_count = (
           select count(*) from public.post_bookmarks pb where pb.post_id = p.id
         );

  -- Stories: views_count, likes_count, flame_level
  update public.stories s
     set views_count = sub.v_count,
         likes_count = sub.l_count,
         flame_level = case
           when (sub.v_count + sub.l_count * 3) >= 200 then 5
           when (sub.v_count + sub.l_count * 3) >= 100 then 4
           when (sub.v_count + sub.l_count * 3) >= 40  then 3
           when (sub.v_count + sub.l_count * 3) >= 10  then 2
           else 1
         end
    from (
      select st.id,
             count(sv.id)::integer as v_count,
             count(sv.id) filter (where sv.liked)::integer as l_count
        from public.stories st
        left join public.story_views sv on sv.story_id = st.id
       group by st.id
    ) sub
   where s.id = sub.id;

  -- Locations: checkins_count
  update public.locations l
     set checkins_count = (
           select count(*)
             from public.posts p
            where p.location_id = l.id
              and not p.is_archived
              and not p.is_hidden
         );

  -- Hashtags: usage_count
  update public.hashtags h
     set usage_count = (
           select count(*)
             from public.post_hashtags ph
             join public.posts p on p.id = ph.post_id
            where ph.hashtag_id = h.id
              and not p.is_hidden
         );

  -- Events: going_count, interested_count, tickets_sold_count, rating_sum, ratings_count, rating_avg
  update public.events e
     set going_count = (
           select count(*) from public.event_rsvps r where r.event_id = e.id and r.status = 'going'
         ),
         interested_count = (
           select count(*) from public.event_rsvps r where r.event_id = e.id and r.status = 'interested'
         ),
         tickets_sold_count = (
           select count(*) from public.tickets t where t.event_id = e.id and t.status in ('valid', 'used', 'transferred')
         ),
         rating_sum = coalesce((
           select sum(er.rating)::integer from public.event_ratings er where er.event_id = e.id
         ), 0),
         ratings_count = (
           select count(*) from public.event_ratings er where er.event_id = e.id
         ),
         rating_avg = coalesce((
           select pg_catalog.round(avg(er.rating)::numeric, 2) from public.event_ratings er where er.event_id = e.id
         ), 0.00);
end;
$$;

revoke all on function public.recompute_counters() from public, anon, authenticated;
grant execute on function public.recompute_counters() to service_role;

-- #############################################################################
-- FILE: 20261124000008_cron_jobs.sql
-- #############################################################################

-- =============================================================================
-- LIT Social — Migration 20261124000008: Scheduled Maintenance & pg_cron Jobs
-- Target: Self-hosted Supabase (PostgreSQL 15+)
-- Jobs:
--   1. Hourly (`0 * * * *`): recompute `hashtags.is_trending` based on post
--      usage in the last 72 hours (not all-time).
--   2. Daily (`0 3 * * *`): delete `story_views` and clear storage references
--      for stories expired more than 30 days ago.
--   3. Every 15 min (`*/15 * * * *`): expire `pending` ticket orders older than
--      30 minutes (`expires_at <= now()`) and release held tier stock.
--   4. Daily (`30 3 * * *`): mark past published events as `completed`.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Hourly: Recompute `hashtags.is_trending` from 72h Post Window
-- -----------------------------------------------------------------------------
create or replace function public.cron_recompute_trending_hashtags()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.hashtags
     set is_trending = false
   where is_trending = true;

  with recent_tags as (
    select ph.hashtag_id,
           count(*) as recent_uses
      from public.post_hashtags ph
      join public.posts p on p.id = ph.post_id
     where not p.is_hidden
       and not p.is_archived
       and ph.created_at >= (pg_catalog.now() - interval '72 hours')
     group by ph.hashtag_id
    having count(*) >= 1
     order by count(*) desc
     limit 15
  )
  update public.hashtags h
     set is_trending = true
    from recent_tags rt
   where h.id = rt.hashtag_id;
end;
$$;

revoke all on function public.cron_recompute_trending_hashtags() from public, anon, authenticated;
grant execute on function public.cron_recompute_trending_hashtags() to service_role;

-- -----------------------------------------------------------------------------
-- 2. Daily: Purge `story_views` and Storage Paths for Stories Expired > 30 Days
-- -----------------------------------------------------------------------------
create or replace function public.cron_cleanup_expired_stories()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Remove detailed view rows for stories expired more than 30 days ago
  delete from public.story_views sv
   using public.stories s
   where sv.story_id = s.id
     and s.expires_at < (pg_catalog.now() - interval '30 days');

  -- Delete underlying private `stories` storage objects and mark purged
  delete from storage.objects so
   using public.stories s
   where so.bucket_id = 'stories'
     and so.name = s.storage_path
     and s.expires_at < (pg_catalog.now() - interval '30 days');

  update public.stories
     set storage_path      = null,
         storage_purged_at = pg_catalog.now()
   where expires_at < (pg_catalog.now() - interval '30 days')
     and storage_purged_at is null;
end;
$$;

revoke all on function public.cron_cleanup_expired_stories() from public, anon, authenticated;
grant execute on function public.cron_cleanup_expired_stories() to service_role;

-- -----------------------------------------------------------------------------
-- 3. Every 15 Minutes: Expire Pending Ticket Orders Older Than 30 Minutes
--    and Release Held Tier Stock
-- -----------------------------------------------------------------------------
create or replace function public.cron_expire_pending_orders()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order record;
  v_item record;
begin
  for v_order in
    select o.id, o.stock_reserved
      from public.ticket_orders o
     where o.status = 'pending'
       and (
         o.expires_at <= pg_catalog.now()
         or o.created_at <= (pg_catalog.now() - interval '30 minutes')
       )
       for update skip locked
  loop
    if v_order.stock_reserved then
      for v_item in
        select oi.tier_id, oi.quantity
          from public.ticket_order_items oi
         where oi.order_id = v_order.id
         order by oi.tier_id
      loop
        update public.event_ticket_tiers
           set quantity_sold = greatest(0, quantity_sold - v_item.quantity)
         where id = v_item.tier_id;
      end loop;
    end if;

    update public.ticket_orders
       set status         = 'expired',
           stock_reserved = false
     where id = v_order.id;
  end loop;
end;
$$;

revoke all on function public.cron_expire_pending_orders() from public, anon, authenticated;
grant execute on function public.cron_expire_pending_orders() to service_role;

-- -----------------------------------------------------------------------------
-- 4. Daily: Mark Past Published Events as `completed`
-- -----------------------------------------------------------------------------
create or replace function public.cron_complete_past_events()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.events
     set status = 'completed'
   where status = 'published'
     and coalesce(ends_at, starts_at + interval '6 hours') < pg_catalog.now();
end;
$$;

revoke all on function public.cron_complete_past_events() from public, anon, authenticated;
grant execute on function public.cron_complete_past_events() to service_role;

-- -----------------------------------------------------------------------------
-- 5. Register `pg_cron` Schedules (Idempotent & Safe if `pg_cron` is Not Preloaded)
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from pg_available_extensions where name = 'pg_cron'
  ) then
    begin
      create extension if not exists pg_cron;

      -- Unschedule previous definitions if re-running migration
      if exists (select 1 from cron.job where jobname = 'lit_hourly_trending_hashtags') then
        perform cron.unschedule('lit_hourly_trending_hashtags');
      end if;
      if exists (select 1 from cron.job where jobname = 'lit_daily_cleanup_expired_stories') then
        perform cron.unschedule('lit_daily_cleanup_expired_stories');
      end if;
      if exists (select 1 from cron.job where jobname = 'lit_15m_expire_pending_orders') then
        perform cron.unschedule('lit_15m_expire_pending_orders');
      end if;
      if exists (select 1 from cron.job where jobname = 'lit_daily_complete_past_events') then
        perform cron.unschedule('lit_daily_complete_past_events');
      end if;

      perform cron.schedule(
        'lit_hourly_trending_hashtags',
        '0 * * * *',
        'select public.cron_recompute_trending_hashtags();'
      );
      perform cron.schedule(
        'lit_daily_cleanup_expired_stories',
        '0 3 * * *',
        'select public.cron_cleanup_expired_stories();'
      );
      perform cron.schedule(
        'lit_15m_expire_pending_orders',
        '*/15 * * * *',
        'select public.cron_expire_pending_orders();'
      );
      perform cron.schedule(
        'lit_daily_complete_past_events',
        '30 3 * * *',
        'select public.cron_complete_past_events();'
      );
    exception
      when others then
        raise notice 'pg_cron extension is available but could not be scheduled in this session (%). Maintenance functions are installed and ready.', sqlerrm;
    end;
  end if;
end
$$;
