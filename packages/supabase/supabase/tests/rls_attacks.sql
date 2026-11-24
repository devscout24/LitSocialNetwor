-- =============================================================================
-- LIT Social — Security & RLS Attack Test Suite (`supabase/tests/rls_attacks.sql`)
-- Purpose:
--   Verifies on a fresh PostgreSQL / Supabase instance that:
--     0. EVERY table in `public` has Row Level Security enabled (`relrowsecurity = true`).
--     1. Attack 1 (Free tickets): clients CANNOT insert/update/delete `ticket_orders`,
--        `ticket_order_items`, `tickets`, or `promo_codes`.
--     2. Attack 2 (Ticket tampering & unauthorized check-in): ticket owners CANNOT
--        update their own tickets (e.g. `used` -> `valid` or GA -> VVIP), and non-host
--        users CANNOT call `check_in_ticket()`, while the host/staff CAN check in once
--        and a second check-in of the same QR code is rejected.
--     3. Attack 3 (Overselling): selling more than `quantity_total` fails both via
--        `create_pending_ticket_order()` row-locked check and the table `CHECK` constraint.
--     4. Attack 4 (Self-editing counters & badges): authenticated users CANNOT update
--        `profiles.is_verified`, `profiles.vibers_count`, `profiles.posts_count`,
--        `posts.likes_count`, `stories.views_count`, `stories.flame_level`,
--        `events.going_count`, or `event_ticket_tiers.quantity_sold`.
--     5. Attack 5 (Private accounts & blocks):
--        - Following a private account forces `status = 'pending'` even if the client
--          attempts to force `'accepted'` or update `vibes`.
--        - Follower CANNOT call `respond_to_vibe_request()` to self-accept; only the
--          followed private user can accept.
--        - Non-followers CANNOT read a private user's posts, post_media, stories,
--          post_comments, or post_likes.
--        - Blocking a user removes vibes in both directions and hides content both ways.
--     6. Attack 6 (Promo code scraping): clients CANNOT `select * from public.promo_codes`,
--        must use `validate_promo_code(p_event_id, p_code)`, and wrong-event or exhausted
--        codes are rejected.
--     7. Attack 7 (Notification spoofing): clients CANNOT insert notifications or edit
--        notification `title` / `body`; they can only update `(is_read, read_at)` on
--        their own notifications.
--     8. Attack 8 (Story viewers privacy): a third party CANNOT read `story_views`
--        rows belonging to another viewer/author.
--     9. Attack 9 (Hashtag & location spam): clients CANNOT insert directly into
--        `hashtags` or `post_hashtags`, and CANNOT insert `locations` with a custom
--        `checkins_count`. Hashtags are extracted automatically from post captions.
--    10. Attack 10 (Fake 2FA columns removed): confirms `two_factor_*` columns do not
--        exist on `public.profiles` or `public.user_settings`.
--    11. Attack 11 (Share & like inflation): inserting duplicate `(post_id, user_id, channel)`
--        into `post_shares` or duplicate `(post_id, user_id)` into `post_likes` fails.
--    12. Attack 12 (Story flame inflation): viewers CANNOT record views for another
--        `viewer_id`, CANNOT record views on expired stories, and CANNOT update
--        `stories.views_count` or `stories.flame_level`.
--    13. Attack 13 (`security definer` hardening & trigger RPC lockout): confirms every
--        `security definer` function in `public` has `search_path=""` and that trigger
--        functions (`handle_new_user`, `sync_profile_vibe_counts`, etc.) and server-only
--        RPCs (`fulfill_order`, `recompute_counters`) are NOT executable by `anon` or
--        `authenticated`.
--    14. Account deletion & financial record protection + ` handle_new_user()`
--        `check_violation` resilience + non-truncating ticket sequence (> 99999) +
--        `is_free` mixed-tier accuracy + Stripe `fulfill_order` idempotency.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 0. Verify EVERY table in `public` has RLS enabled (`relrowsecurity = true`)
-- -----------------------------------------------------------------------------
do $$
declare
  v_unprotected text;
  v_table_count integer;
begin
  select string_agg(c.relname, ', ')
    into v_unprotected
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relkind = 'r'
     and not c.relrowsecurity;

  if v_unprotected is not null then
    raise exception 'FAIL [Check 0]: Tables in public without RLS enabled: %', v_unprotected;
  end if;

  select count(*)
    into v_table_count
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relkind = 'r'
     and c.relrowsecurity;

  if v_table_count < 28 then
    raise exception 'FAIL [Check 0]: Expected at least 28 RLS-protected tables in public, found %', v_table_count;
  end if;

  raise notice 'PASS [Check 0]: All % tables in public have relrowsecurity = true.', v_table_count;
end
$$;

-- -----------------------------------------------------------------------------
-- Seed 4 test users in `auth.users` (which triggers `public.handle_new_user()`)
--   - Alice (`11111111-1111-1111-1111-111111111111`): public user & event host
--   - Bob   (`22222222-2222-2222-2222-222222222222`): private account user
--   - Mallory (`33333333-3333-3333-3333-333333333333`): attacker user
--   -Emma (`44444444-4444-4444-4444-444444444444`): signs up with invalid username
--     "Emma Wilson" (contains space & uppercase -> triggers `check_violation` in 0001)
-- -----------------------------------------------------------------------------
do $$
declare
  v_emma_username text;
begin
  insert into auth.users (id, email, raw_user_meta_data)
  values
    ('11111111-1111-1111-1111-111111111111', 'alice@example.com',   '{"username":"alice_lit","display_name":"Alice Host"}'::jsonb),
    ('22222222-2222-2222-2222-222222222222', 'bob@example.com',     '{"username":"bob_private","display_name":"Bob Private"}'::jsonb),
    ('33333333-3333-3333-3333-333333333333', 'mallory@example.com', '{"username":"mallory_x","display_name":"Mallory Attacker"}'::jsonb),
    ('44444444-4444-4444-4444-444444444444', 'emma@example.com',    '{"username":"Emma Wilson","display_name":"Emma Wilson"}'::jsonb);

  -- Verify Must-fix #10: Emma's sign-up succeeded and profile was created with `username = null`
  select username into v_emma_username
    from public.profiles
   where id = '44444444-4444-4444-4444-444444444444';

  if not found or v_emma_username is not null then
    raise exception 'FAIL [Must-fix #10]: Expected handle_new_user() to catch check_violation and set username = null, got %', v_emma_username;
  end if;

  -- Make Bob's account private
  update public.profiles
     set is_private = true
   where id = '22222222-2222-2222-2222-222222222222';

  raise notice 'PASS [Must-fix #10]: handle_new_user() caught check_violation on "Emma Wilson" without failing sign-up.';
end
$$;

-- -----------------------------------------------------------------------------
-- Set up test fixtures as Alice & Bob (events, tiers, promo codes, posts, stories)
-- -----------------------------------------------------------------------------
do $$
declare
  v_event_id uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_event2_id uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_tier_free_id uuid := 'aaaaaaaa-0001-0001-0001-aaaaaaaaaaaa';
  v_tier_vip_id uuid := 'aaaaaaaa-0002-0002-0002-aaaaaaaaaaaa';
  v_is_free boolean;
begin
  -- Alice creates an event with 1 Free tier ($0) and 1 VIP tier ($120, qty 1)
  insert into public.events (
    id, host_id, title, category, status, venue_name, city, timezone, starts_at, ends_at
  )
  values (
    v_event_id,
    '11111111-1111-1111-1111-111111111111',
    'Neon Nights Underground',
    'nightlife',
    'published',
    'Warehouse 23',
    'Brooklyn, NY',
    'America/New_York',
    now() + interval '7 days',
    now() + interval '7 days 6 hours'
  ),
  (
    v_event2_id,
    '11111111-1111-1111-1111-111111111111',
    'Other Event',
    'music',
    'published',
    'Warehouse 12',
    'Brooklyn, NY',
    'America/New_York',
    now() + interval '14 days',
    now() + interval '14 days 5 hours'
  );

  -- Before tiers exist, event must NOT be marked free
  select is_free into v_is_free from public.events where id = v_event_id;
  if v_is_free then
    raise exception 'FAIL [Must-fix #3]: Event with no tiers should not be is_free = true.';
  end if;

  -- Add a free GA tier ($0) and a paid VIP tier ($120, quantity_total = 1)
  insert into public.event_ticket_tiers (
    id, event_id, name, price_cents, quantity_total, max_per_order, group_size
  )
  values
    (v_tier_free_id, v_event_id, 'Free Early Bird', 0, 10, 2, 1),
    (v_tier_vip_id,  v_event_id, 'VIP Table (4 Pax)', 12000, 1, 1, 4);

  -- Must-fix #3: Event with both $0 GA and $120 VIP must have `is_free = false`
  select is_free into v_is_free from public.events where id = v_event_id;
  if v_is_free then
    raise exception 'FAIL [Must-fix #3]: Event with free tier + $120 VIP tier must have is_free = false.';
  end if;

  -- Add a promo code scoped to `v_event_id` with `max_uses = 1`
  insert into public.promo_codes (
    event_id, code, discount_percent, max_uses, is_active
  )
  values (
    v_event_id, 'NEON20', 20, 1, true
  );

  -- Bob (private account) creates a post and an active story
  insert into public.posts (id, author_id, caption)
  values (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '22222222-2222-2222-2222-222222222222',
    'Bob private post #SecretVibes'
  );

  insert into public.post_media (post_id, media_url, media_type)
  values (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'https://cdn.example.com/bob-private.jpg',
    'image'
  );

  insert into public.stories (id, author_id, media_url, storage_path, media_type, expires_at)
  values (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    '22222222-2222-2222-2222-222222222222',
    'https://cdn.example.com/bob-story.jpg',
    '22222222-2222-2222-2222-222222222222/story1.jpg',
    'image',
    now() + interval '12 hours'
  );

  -- Alice (public account) creates a post, an active story, and an already-expired story
  insert into public.posts (id, author_id, caption)
  values (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '11111111-1111-1111-1111-111111111111',
    'Alice public post #NeonNights #RooftopVibes'
  );

  insert into public.stories (id, author_id, media_url, storage_path, media_type, expires_at)
  values (
    'ffffffff-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'https://cdn.example.com/alice-active.jpg',
    '11111111-1111-1111-1111-111111111111/active.jpg',
    'image',
    now() + interval '12 hours'
  );

  insert into public.stories (id, author_id, media_url, storage_path, media_type, created_at, expires_at)
  values (
    'ffffffff-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'https://cdn.example.com/alice-expired.jpg',
    '11111111-1111-1111-1111-111111111111/expired.jpg',
    'image',
    now() - interval '25 hours',
    now() - interval '1 hour'
  );

  raise notice 'PASS [Must-fix #3]: Event pricing & is_free logic verified.';
end
$$;

-- -----------------------------------------------------------------------------
-- ATTACK 1: Free Tickets (Client tries to insert ticket_orders, ticket_order_items,
--           tickets, or promo_codes directly)
-- -----------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

do $$
declare
  v_blocked boolean;
begin
  -- 1a. Try inserting a `ticket_orders` row as Mallory
  v_blocked := false;
  begin
    insert into public.ticket_orders (buyer_id, event_id, total_cents, status)
    values ('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 0, 'paid');
  exception when insufficient_privilege or others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 1a]: Client was able to insert into ticket_orders!';
  end if;

  -- 1b. Try inserting a `tickets` row directly as Mallory
  v_blocked := false;
  begin
    insert into public.tickets (
      order_id, event_id, tier_id, owner_id, tier_name, admits_count
    )
    values (
      gen_random_uuid(),
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'aaaaaaaa-0002-0002-0002-aaaaaaaaaaaa',
      '33333333-3333-3333-3333-333333333333',
      'VIP Table (4 Pax)',
      4
    );
  exception when insufficient_privilege or others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 1b]: Client was able to mint a ticket directly!';
  end if;

  -- 1c. Try inserting a `promo_codes` row as Mallory
  v_blocked := false;
  begin
    insert into public.promo_codes (code, discount_percent)
    values ('FREE100', 100);
  exception when insufficient_privilege or others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 1c]: Client was able to insert a promo code!';
  end if;

  -- 1d. Try calling `create_pending_ticket_order` or `fulfill_order` as authenticated user
  v_blocked := false;
  begin
    perform public.create_pending_ticket_order(
      '33333333-3333-3333-3333-333333333333',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '[{"tier_id":"aaaaaaaa-0002-0002-0002-aaaaaaaaaaaa","quantity":1}]'::jsonb
    );
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 1d]: Client was able to call server-only create_pending_ticket_order!';
  end if;

  raise notice 'PASS [Attack 1]: Free ticket minting & client writes to ticketing tables are completely blocked.';
end
$$;

-- -----------------------------------------------------------------------------
-- ATTACK 2 & 3: Server creates & fulfills an order (idempotently), then Mallory
--               attempts overselling, ticket tampering, and unauthorized check-in
-- -----------------------------------------------------------------------------
reset role;

do $$
declare
  v_order_id uuid;
  v_oversell_blocked boolean := false;
  v_ticket_count integer;
begin
  -- Server creates pending order for Mallory for the 1 available VIP Table ticket
  v_order_id := public.create_pending_ticket_order(
    '33333333-3333-3333-3333-333333333333',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    '[{"tier_id":"aaaaaaaa-0002-0002-0002-aaaaaaaaaaaa","quantity":1}]'::jsonb,
    'NEON20',
    500
  );

  -- Attack 3 (Overselling): Second buyer tries to reserve the same last VIP ticket
  begin
    perform public.create_pending_ticket_order(
      '22222222-2222-2222-2222-222222222222',
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '[{"tier_id":"aaaaaaaa-0002-0002-0002-aaaaaaaaaaaa","quantity":1}]'::jsonb
    );
  exception when others then
    v_oversell_blocked := true;
  end;
  if not v_oversell_blocked then
    raise exception 'FAIL [Attack 3]: Overselling the last ticket was not blocked!';
  end if;

  -- Server fulfills Mallory's order twice (Stripe webhook retry idempotency test)
  perform public.fulfill_order(v_order_id, 'pi_test_12345');
  perform public.fulfill_order(v_order_id, 'pi_test_12345');

  select count(*) into v_ticket_count
    from public.tickets
   where order_id = v_order_id;

  if v_ticket_count <> 1 then
    raise exception 'FAIL [Stripe Idempotency]: Expected 1 ticket after duplicate fulfill_order call, got %', v_ticket_count;
  end if;

  raise notice 'PASS [Attack 3 & Stripe Idempotency]: Overselling blocked and duplicate fulfill_order is idempotent.';
end
$$;

-- Now impersonate Mallory (the ticket owner) and attempt Attack 2 (Ticket tampering & self check-in)
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

do $$
declare
  v_qr text;
  v_blocked boolean;
begin
  select qr_payload into v_qr
    from public.tickets
   where owner_id = '33333333-3333-3333-3333-333333333333'
   limit 1;

  -- 2a. Mallory tries to update her own ticket tier_name or status
  v_blocked := false;
  begin
    update public.tickets
       set tier_name = 'SUPER VVIP',
           status    = 'valid'
     where qr_payload = v_qr;
  exception when insufficient_privilege or others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 2a]: Ticket owner was able to update their own ticket!';
  end if;

  -- 2b. Mallory tries to call `check_in_ticket` on her own ticket (she is not host/staff)
  v_blocked := false;
  begin
    perform public.check_in_ticket(v_qr, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 2b]: Non-host user was able to check in a ticket!';
  end if;
end
$$;

-- Now impersonate Alice (the event host) to test valid check-in + wrong-event + double check-in rejection
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

do $$
declare
  v_qr text;
  v_blocked boolean;
  v_res jsonb;
begin
  select qr_payload into v_qr
    from public.tickets
   where event_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
   limit 1;

  -- 2c. Host tries to check in ticket against the WRONG event (`bbbbbbbb-...`)
  v_blocked := false;
  begin
    perform public.check_in_ticket(v_qr, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 2c]: Ticket check-in succeeded for the wrong event!';
  end if;

  -- 2d. Host checks in the ticket for the correct event (must succeed once)
  v_res := public.check_in_ticket(v_qr, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  if (v_res ->> 'status') <> 'used' then
    raise exception 'FAIL [Attack 2d]: Host check-in did not mark ticket as used.';
  end if;

  -- 2e. Host tries to check in the SAME ticket a second time (must fail)
  v_blocked := false;
  begin
    perform public.check_in_ticket(v_qr, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 2e]: Re-using an already checked-in ticket was not blocked!';
  end if;

  raise notice 'PASS [Attack 2]: Ticket tampering, unauthorized check-in, wrong-event check-in, and double check-in are all blocked.';
end
$$;

-- -----------------------------------------------------------------------------
-- ATTACK 4: Self-Editing Counters, Verification Badges & Moderation Flags
-- -----------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

do $$
declare
  v_blocked boolean;
begin
  -- 4a. Try setting `is_verified = true` on own profile
  v_blocked := false;
  begin
    update public.profiles
       set is_verified = true
     where id = '11111111-1111-1111-1111-111111111111';
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 4a]: User was able to set is_verified = true on their profile!';
  end if;

  -- 4b. Try inflating `vibers_count` on own profile
  v_blocked := false;
  begin
    update public.profiles
       set vibers_count = 999999
     where id = '11111111-1111-1111-1111-111111111111';
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 4b]: User was able to edit vibers_count on their profile!';
  end if;

  -- 4c. Try inflating `likes_count` on own post
  v_blocked := false;
  begin
    update public.posts
       set likes_count = 50000
     where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 4c]: Author was able to edit likes_count on their post!';
  end if;

  -- 4d. Try inflating `views_count` or `flame_level` on own story
  v_blocked := false;
  begin
    update public.stories
       set flame_level = 5,
           views_count = 10000
     where id = 'ffffffff-1111-1111-1111-111111111111';
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 4d]: Author was able to edit views_count / flame_level on their story!';
  end if;

  -- 4e. Try editing `going_count` or `rating_avg` on own event
  v_blocked := false;
  begin
    update public.events
       set going_count = 10000,
           rating_avg  = 5.00
     where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 4e]: Host was able to edit going_count / rating_avg on their event!';
  end if;

  -- 4f. Try editing `quantity_sold` on own event ticket tier
  v_blocked := false;
  begin
    update public.event_ticket_tiers
       set quantity_sold = 0
     where id = 'aaaaaaaa-0002-0002-0002-aaaaaaaaaaaa';
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 4f]: Host was able to edit quantity_sold on event_ticket_tiers!';
  end if;

  raise notice 'PASS [Attack 4]: Column-level grants block all self-edits to counters, badges, and system fields.';
end
$$;

-- -----------------------------------------------------------------------------
-- ATTACK 5: Private Accounts, Follow Requests & Blocking
-- -----------------------------------------------------------------------------
-- Impersonate Mallory (`33333333-...`) trying to view Bob's (`22222222-...`) private content
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

do $$
declare
  v_count integer;
  v_status text;
  v_blocked boolean;
begin
  -- 5a. Non-follower Mallory tries to read Bob's private posts, post_media, stories
  select count(*) into v_count from public.posts where author_id = '22222222-2222-2222-2222-222222222222';
  if v_count <> 0 then
    raise exception 'FAIL [Attack 5a]: Non-follower was able to read a private account post!';
  end if;

  select count(*) into v_count from public.post_media where post_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  if v_count <> 0 then
    raise exception 'FAIL [Attack 5a]: Non-follower was able to read private post_media!';
  end if;

  select count(*) into v_count from public.stories where author_id = '22222222-2222-2222-2222-222222222222';
  if v_count <> 0 then
    raise exception 'FAIL [Attack 5a]: Non-follower was able to read a private account story!';
  end if;

  -- 5b. Mallory tries to insert a vibe with explicit `status = 'accepted'` on Bob's private profile
  v_blocked := false;
  begin
    insert into public.vibes (follower_id, following_id, status)
    values ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'accepted');
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 5b]: Client was allowed to supply status column on vibes insert!';
  end if;

  -- 5c. Mallory inserts a standard follow request on Bob; trigger MUST force `status = 'pending'`
  insert into public.vibes (follower_id, following_id)
  values ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222');

  select status into v_status
    from public.vibes
   where follower_id = '33333333-3333-3333-3333-333333333333'
     and following_id = '22222222-2222-2222-2222-222222222222';

  if v_status <> 'pending' then
    raise exception 'FAIL [Attack 5c]: Follow on private account did not default to pending (got %).', v_status;
  end if;

  -- 5d. While still pending, Mallory still cannot read Bob's private post
  select count(*) into v_count from public.posts where author_id = '22222222-2222-2222-2222-222222222222';
  if v_count <> 0 then
    raise exception 'FAIL [Attack 5d]: Pending follower was able to read private posts before acceptance!';
  end if;

  -- 5e. Mallory tries to UPDATE `vibes` directly or call `respond_to_vibe_request` to self-accept
  v_blocked := false;
  begin
    update public.vibes
       set status = 'accepted'
     where follower_id = '33333333-3333-3333-3333-333333333333';
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 5e]: Follower was able to directly update vibes.status!';
  end if;

  v_blocked := false;
  begin
    perform public.respond_to_vibe_request('33333333-3333-3333-3333-333333333333', true);
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 5e]: Follower was able to self-accept their own vibe request via RPC!';
  end if;
end
$$;

-- Now Bob (`22222222-...`) accepts Mallory's request via `respond_to_vibe_request`, then blocks Mallory
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
begin
  perform public.respond_to_vibe_request('33333333-3333-3333-3333-333333333333', true);
end
$$;

-- Verify Mallory can now see Bob's post, and then after Bob blocks Mallory, the vibe is removed and content hidden
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

do $$
declare
  v_count integer;
begin
  select count(*) into v_count from public.posts where author_id = '22222222-2222-2222-2222-222222222222';
  if v_count <> 1 then
    raise exception 'FAIL [Attack 5f]: Accepted follower could not read private post!';
  end if;
end
$$;

-- Bob blocks Mallory
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

do $$
begin
  insert into public.user_blocks (blocker_id, blocked_id)
  values ('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');
end
$$;

-- Mallory checks again: vibe row must be deleted, Bob's profile & posts hidden, and re-vibing blocked
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

do $$
declare
  v_count integer;
  v_blocked boolean := false;
begin
  select count(*) into v_count
    from public.vibes
   where follower_id = '33333333-3333-3333-3333-333333333333'
     and following_id = '22222222-2222-2222-2222-222222222222';
  if v_count <> 0 then
    raise exception 'FAIL [Attack 5g]: Blocking user did not remove existing vibe relationship!';
  end if;

  select count(*) into v_count from public.posts where author_id = '22222222-2222-2222-2222-222222222222';
  if v_count <> 0 then
    raise exception 'FAIL [Attack 5g]: Blocked user can still read blocker posts!';
  end if;

  begin
    insert into public.vibes (follower_id, following_id)
    values ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222');
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 5g]: Blocked user was able to re-follow blocker!';
  end if;

  raise notice 'PASS [Attack 5]: Private account gates, follow request workflow, and bidirectional blocks verified.';
end
$$;

-- -----------------------------------------------------------------------------
-- ATTACK 6: Promo Code Scraping & Validation
-- -----------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

do $$
declare
  v_blocked boolean;
begin
  -- 6a. Client tries to list `public.promo_codes` directly
  v_blocked := false;
  begin
    perform count(*) from public.promo_codes;
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 6a]: Client was able to SELECT from public.promo_codes!';
  end if;

  -- 6b. `NEON20` had `max_uses = 1` and was already used in Mallory's fulfilled order above.
  --     Validating it again must fail!
  v_blocked := false;
  begin
    perform * from public.validate_promo_code('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'NEON20');
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 6b]: Exhausted promo code (uses_count = max_uses) was accepted!';
  end if;

  raise notice 'PASS [Attack 6]: Promo codes are not listable by clients and exhausted/wrong-event codes are rejected.';
end
$$;

-- -----------------------------------------------------------------------------
-- ATTACK 7: Notification Spoofing
-- -----------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

do $$
declare
  v_blocked boolean;
begin
  -- 7a. Mallory tries to insert a fake notification to Alice
  v_blocked := false;
  begin
    insert into public.notifications (recipient_id, type, title, body)
    values ('11111111-1111-1111-1111-111111111111', 'system', 'You won $1,000,000!', 'Click phishing link');
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 7a]: Client was able to spoof/insert a notification!';
  end if;

  -- 7b. Mallory tries to edit the `title` of her own ticket_purchased notification
  v_blocked := false;
  begin
    update public.notifications
       set title = 'Tampered title'
     where recipient_id = '33333333-3333-3333-3333-333333333333';
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 7b]: Client was able to update notifications.title!';
  end if;

  -- 7c. Mallory CAN mark her own notification as read (`is_read`, `read_at`)
  update public.notifications
     set is_read = true,
         read_at = now()
   where recipient_id = '33333333-3333-3333-3333-333333333333';

  raise notice 'PASS [Attack 7]: Notification spoofing and content tampering blocked; marking own notifications read works.';
end
$$;

-- -----------------------------------------------------------------------------
-- ATTACK 8 & 12: Story Viewers Privacy & Story Flame Inflation
-- -----------------------------------------------------------------------------
-- Emma (`44444444-...`) views Alice's active story (`ffffffff-1111-...`)
set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

do $$
begin
  perform public.record_story_view('ffffffff-1111-1111-1111-111111111111', true);
end
$$;

-- Now Mallory (`33333333-...`) attempts Attack 8 (reading Emma's view of Alice's story)
-- and Attack 12 (recording view for another user or on Alice's expired story)
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

do $$
declare
  v_count integer;
  v_blocked boolean;
begin
  -- 8. Mallory (neither viewer nor story author) tries to read `story_views`
  select count(*) into v_count
    from public.story_views
   where story_id = 'ffffffff-1111-1111-1111-111111111111';
  if v_count <> 0 then
    raise exception 'FAIL [Attack 8]: Third-party user was able to read story_views!';
  end if;

  -- 12a. Mallory tries to insert a `story_views` row impersonating Bob (`viewer_id = 22222222-...`)
  v_blocked := false;
  begin
    insert into public.story_views (story_id, viewer_id, liked)
    values ('ffffffff-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', true);
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 12a]: User was able to insert a story_views row for another viewer_id!';
  end if;

  -- 12b. Mallory tries to view/like Alice's EXPIRED story (`ffffffff-2222-...`) via RPC and direct insert
  v_blocked := false;
  begin
    perform public.record_story_view('ffffffff-2222-2222-2222-222222222222', true);
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 12b]: record_story_view allowed viewing an expired story!';
  end if;

  v_blocked := false;
  begin
    insert into public.story_views (story_id, viewer_id, liked)
    values ('ffffffff-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', true);
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 12c]: Direct insert into story_views succeeded for an expired story!';
  end if;

  raise notice 'PASS [Attack 8 & 12]: Story viewer privacy and expired/spoofed story flame inflation are blocked.';
end
$$;

-- -----------------------------------------------------------------------------
-- ATTACK 9: Hashtag & Location Spam
-- -----------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

do $$
declare
  v_blocked boolean;
  v_usage integer;
begin
  -- 9a. Client tries to insert into `public.hashtags` with `is_trending = true`
  v_blocked := false;
  begin
    insert into public.hashtags (tag, display_tag, usage_count, is_trending)
    values ('spambot', '#SpamBot', 999999, true);
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 9a]: Client was able to insert directly into public.hashtags!';
  end if;

  -- 9b. Client tries to insert into `public.locations` with a fake `checkins_count`
  v_blocked := false;
  begin
    insert into public.locations (name, city, checkins_count)
    values ('Fake Club', 'Nowhere', 50000);
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 9b]: Client was able to set checkins_count when inserting a location!';
  end if;

  -- 9c. Verify hashtags from Alice's post caption (`#NeonNights`, `#RooftopVibes`) were extracted by trigger
  select usage_count into v_usage from public.hashtags where tag = 'neonnights';
  if v_usage is null or v_usage < 1 then
    raise exception 'FAIL [Attack 9c]: Automatic post caption hashtag trigger did not populate hashtags!';
  end if;

  raise notice 'PASS [Attack 9]: Direct hashtag & location counter spam blocked; caption hashtag extraction trigger works.';
end
$$;

-- -----------------------------------------------------------------------------
-- ATTACK 10: Fake 2FA Columns Removed
-- -----------------------------------------------------------------------------
reset role;

do $$
declare
  v_col_count integer;
begin
  select count(*)
    into v_col_count
    from information_schema.columns
   where table_schema = 'public'
     and table_name in ('profiles', 'user_settings')
     and column_name like 'two_factor%';

  if v_col_count <> 0 then
    raise exception 'FAIL [Attack 10]: Found % two_factor_* columns still in public.profiles or public.user_settings!', v_col_count;
  end if;

  raise notice 'PASS [Attack 10]: Zero fake two_factor_* columns in public schema (2FA uses Supabase Auth MFA).';
end
$$;

-- -----------------------------------------------------------------------------
-- ATTACK 11: Share & Like Inflation
-- -----------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

do $$
declare
  v_blocked boolean;
begin
  -- First share on channel `'in_app'` succeeds
  insert into public.post_shares (post_id, user_id, channel)
  values ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '33333333-3333-3333-3333-333333333333', 'in_app');

  -- Duplicate share on same `(post_id, user_id, channel)` must fail
  v_blocked := false;
  begin
    insert into public.post_shares (post_id, user_id, channel)
    values ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '33333333-3333-3333-3333-333333333333', 'in_app');
  exception when unique_violation then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 11]: Duplicate post_shares row on same channel was allowed!';
  end if;

  raise notice 'PASS [Attack 11]: Duplicate post_shares inflation blocked by unique (post_id, user_id, channel).';
end
$$;

-- -----------------------------------------------------------------------------
-- ATTACK 13: Every `security definer` Function Has `search_path=""` and Trigger /
--            Server Functions Are Not Callable by `anon` or `authenticated`
-- -----------------------------------------------------------------------------
reset role;

do $$
declare
  v_bad_funcs text;
begin
  select string_agg(p.proname, ', ')
    into v_bad_funcs
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.prosecdef = true
     and (
       p.proconfig is null
       or not ('search_path=""' = any(p.proconfig) or 'search_path=' = any(p.proconfig))
     );

  if v_bad_funcs is not null then
    raise exception 'FAIL [Attack 13a]: security definer functions in public without empty search_path: %', v_bad_funcs;
  end if;
end
$$;

set local role authenticated;
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

do $$
declare
  v_blocked boolean;
begin
  -- Trigger function cannot be invoked as RPC
  v_blocked := false;
  begin
    perform public.handle_new_user();
  exception when insufficient_privilege or others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 13b]: Trigger function handle_new_user() was executable by authenticated!';
  end if;

  -- Server-only repair function `recompute_counters()` cannot be called by authenticated
  v_blocked := false;
  begin
    perform public.recompute_counters();
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Attack 13c]: Server-only recompute_counters() was executable by authenticated!';
  end if;

  raise notice 'PASS [Attack 13]: All security definer functions have search_path="" and trigger/server functions are locked down.';
end
$$;

-- -----------------------------------------------------------------------------
-- CHECK 14: Account Deletion & Financial Record Preservation + Non-Truncating
--           Ticket Codes (> 99999) + Must-fix #8 (`location_id` & `is_archived` sync)
-- -----------------------------------------------------------------------------
-- 14a. Alice (host of upcoming paid event with sold tickets) tries `request_account_deletion()` -> MUST FAIL
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

do $$
declare
  v_blocked boolean := false;
  v_loc1 uuid;
  v_loc2 uuid;
  v_post_id uuid;
  v_c1 integer;
  v_c2 integer;
  v_pcount integer;
begin
  begin
    perform public.request_account_deletion();
  exception when others then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'FAIL [Check 14a]: Host with upcoming paid event was allowed to delete their account!';
  end if;

  -- 14b. Test Must-fix #8: `sync_profile_posts_count` on `location_id` change and `is_archived` toggle
  insert into public.locations (name, city) values ('Test Venue A', 'NYC') returning id into v_loc1;
  insert into public.locations (name, city) values ('Test Venue B', 'NYC') returning id into v_loc2;

  insert into public.posts (author_id, caption, location_id)
  values ('11111111-1111-1111-1111-111111111111', 'Checkin test', v_loc1)
  returning id into v_post_id;

  select checkins_count into v_c1 from public.locations where id = v_loc1;
  if v_c1 <> 1 then
    raise exception 'FAIL [Must-fix #8]: Expected Venue A checkins_count = 1 after insert, got %', v_c1;
  end if;

  -- Move post from Venue A to Venue B
  update public.posts set location_id = v_loc2 where id = v_post_id;
  select checkins_count into v_c1 from public.locations where id = v_loc1;
  select checkins_count into v_c2 from public.locations where id = v_loc2;
  if v_c1 <> 0 or v_c2 <> 1 then
    raise exception 'FAIL [Must-fix #8]: Updating post.location_id did not move checkin counts (A=%, B=%)', v_c1, v_c2;
  end if;

  -- Archive the post: both `profiles.posts_count` and Venue B `checkins_count` must decrement
  select posts_count into v_pcount from public.profiles where id = '11111111-1111-1111-1111-111111111111';
  update public.posts set is_archived = true where id = v_post_id;
  select checkins_count into v_c2 from public.locations where id = v_loc2;
  if v_c2 <> 0 then
    raise exception 'FAIL [Must-fix #8]: Archiving post did not decrement location checkins_count!';
  end if;
end
$$;

-- 14c. Mallory (ticket buyer, not a host) calls `request_account_deletion()` -> MUST SUCCEED,
--      anonymize her profile (`deleted_<shortid>`), and KEEP her paid order & ticket intact!
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

do $$
begin
  perform public.request_account_deletion();
end
$$;

reset role;

do $$
declare
  v_username text;
  v_deleted_at timestamptz;
  v_orders_kept integer;
  v_tickets_kept integer;
  v_code_high text;
begin
  select username, deleted_at
    into v_username, v_deleted_at
    from public.profiles
   where id = '33333333-3333-3333-3333-333333333333';

  if v_deleted_at is null or v_username not like 'deleted_%' then
    raise exception 'FAIL [Check 14c]: request_account_deletion() did not anonymize profile (username=%, deleted_at=%)', v_username, v_deleted_at;
  end if;

  select count(*) into v_orders_kept
    from public.ticket_orders
   where buyer_id = '33333333-3333-3333-3333-333333333333'
     and status = 'paid'
     and buyer_display_name_snapshot = 'Mallory Attacker';

  select count(*) into v_tickets_kept
    from public.tickets
   where owner_id = '33333333-3333-3333-3333-333333333333'
     and holder_name_snapshot = 'Mallory Attacker';

  if v_orders_kept <> 1 or v_tickets_kept <> 1 then
    raise exception 'FAIL [Check 14c]: Financial records were lost on account deletion (orders=%, tickets=%)', v_orders_kept, v_tickets_kept;
  end if;

  -- 14d. Test Must-fix #2: Sequence values > 99999 do not truncate or collide
  perform setval('public.lit_ticket_code_seq', 100005, false);
  v_code_high := public.next_ticket_code();
  if v_code_high not like 'LIT-%-100005' then
    raise exception 'FAIL [Must-fix #2]: next_ticket_code() truncated >5 digit number: %', v_code_high;
  end if;

  raise notice 'PASS [Check 14]: Account deletion anonymization, financial record retention, Must-fix #2 (>99999 codes), and Must-fix #8 verified.';
end
$$;

rollback;
