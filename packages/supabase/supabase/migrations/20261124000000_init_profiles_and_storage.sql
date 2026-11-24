-- =============================================================================
-- Migration: 20261124000000_init_profiles_and_storage.sql
-- Target: Self-hosted Supabase on VPS (PostgreSQL + Supabase Auth + Storage)
-- Description:
--   1. Creates `public.profiles` linked to `auth.users`
--   2. Configures `updated_at` maintenance trigger and `auth.users` auto-profile trigger
--   3. Enables Row Level Security (RLS) and policies on `public.profiles`
--   4. Creates Storage buckets (`avatars`, `posts`, `stories`, `events`) and RLS policies
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Profiles Table
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text,
  bio text,
  avatar_url text,
  website text,
  location text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- -----------------------------------------------------------------------------
-- 2. Triggers & Functions
-- -----------------------------------------------------------------------------

-- Keep `updated_at` current on row updates
create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
  before update on public.profiles
  for each row
  execute function public.handle_updated_at();

-- Automatically insert a `public.profiles` row when a new `auth.users` row is created
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  raw_username text;
  raw_display_name text;
begin
  raw_username := nullif(trim(new.raw_user_meta_data->>'username'), '');
  raw_display_name := coalesce(
    nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
    nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
    nullif(trim(new.raw_user_meta_data->>'name'), '')
  );

  insert into public.profiles (
    id,
    username,
    display_name,
    avatar_url
  )
  values (
    new.id,
    raw_username,
    raw_display_name,
    nullif(trim(new.raw_user_meta_data->>'avatar_url'), '')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 3. Row Level Security (RLS) on `public.profiles`
-- -----------------------------------------------------------------------------
alter table public.profiles enable row level security;

-- Anyone can read profiles
drop policy if exists "Profiles are viewable by everyone" on public.profiles;
create policy "Profiles are viewable by everyone"
  on public.profiles
  for select
  using (true);

-- Authenticated user can insert only their own profile row
drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile"
  on public.profiles
  for insert
  to authenticated
  with check (auth.uid() = id);

-- Authenticated user can update only their own profile row
drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Note: No client delete policy on `public.profiles` in MVP (deletions cascade from `auth.users`).

-- -----------------------------------------------------------------------------
-- 4. Storage Buckets (`avatars`, `posts`, `stories`, `events`)
-- -----------------------------------------------------------------------------
-- `avatars` and `events` are public; `posts` and `stories` are public-read for MVP.
insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('posts', 'posts', true),
  ('stories', 'stories', true),
  ('events', 'events', true)
on conflict (id) do update
  set public = excluded.public;

-- -----------------------------------------------------------------------------
-- 5. Storage Policies on `storage.objects`
-- -----------------------------------------------------------------------------
-- Public read access for objects in the MVP buckets
drop policy if exists "Public read access for app media buckets" on storage.objects;
create policy "Public read access for app media buckets"
  on storage.objects
  for select
  using (bucket_id in ('avatars', 'posts', 'stories', 'events'));

-- Authenticated users can upload only into a folder prefixed with their own user ID:
--   <bucket>/<user_id>/<filename>
drop policy if exists "Authenticated users can upload to their own folder" on storage.objects;
create policy "Authenticated users can upload to their own folder"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id in ('avatars', 'posts', 'stories', 'events')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Authenticated users can update only their own objects in their own folder
drop policy if exists "Authenticated users can update their own objects" on storage.objects;
create policy "Authenticated users can update their own objects"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id in ('avatars', 'posts', 'stories', 'events')
    and (storage.foldername(name))[1] = auth.uid()::text
    and owner = auth.uid()
  )
  with check (
    bucket_id in ('avatars', 'posts', 'stories', 'events')
    and (storage.foldername(name))[1] = auth.uid()::text
    and owner = auth.uid()
  );

-- Authenticated users can delete only their own objects in their own folder
drop policy if exists "Authenticated users can delete their own objects" on storage.objects;
create policy "Authenticated users can delete their own objects"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id in ('avatars', 'posts', 'stories', 'events')
    and (storage.foldername(name))[1] = auth.uid()::text
    and owner = auth.uid()
  );
