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
