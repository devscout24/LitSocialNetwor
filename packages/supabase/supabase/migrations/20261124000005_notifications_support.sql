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
