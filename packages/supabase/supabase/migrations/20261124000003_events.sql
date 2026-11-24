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
