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
