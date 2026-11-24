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
