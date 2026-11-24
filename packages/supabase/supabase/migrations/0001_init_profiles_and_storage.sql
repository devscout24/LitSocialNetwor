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
