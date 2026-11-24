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
