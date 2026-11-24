# LIT Social — Production Schema Notes (`SCHEMA_NOTES.md`)

Target backend: **Self-hosted Supabase** (PostgreSQL 15+, GoTrue Auth, Supabase Storage) deployed on a VPS via Dokploy. Zero Supabase Cloud-only dependencies.

---

## 1. Migration Files (Run in Filename Order)

| Order | File | Contents |
| :- | :--- | :--- |
| 0 | `0001_init_profiles_and_storage.sql` | Base `public.profiles`, `set_updated_at()`, `handle_new_user()`, storage buckets (`avatars`, `posts`, `stories`, `events`) and base policies (kept unmodified). |
| 1 | `20261124000001_fix_0001_and_extensions.sql` | Creates `extensions` schema (`pgcrypto`, `pg_trgm`), hardens `set_updated_at()`, fixes `handle_new_user()` to catch `check_violation` as well as `unique_violation`, sets `file_size_limit` and `allowed_mime_types` on all 4 buckets, and converts the `stories` bucket to **private** (`public = false`). |
| 2 | `20261124000002_social_core.sql` | Extends `profiles` (privacy flags, socials, counters, `deleted_at`, validation checks, trigram indexes), creates `user_settings` (notification toggles only), `user_blocks`, `user_mutes`, `vibes`, `locations`, `hashtags`, `posts`, `post_media`, `post_tags`, `post_hashtags`, `post_likes`, `post_comments`, `post_bookmarks`, `post_shares`, `stories`, and `story_views`. |
| 3 | `20261124000003_events.sql` | Creates `events` (with IANA `timezone`, text `category` check, incremental `rating_sum` + `ratings_count`, and FK from `posts.event_id`), `event_media` (5-dot carousel), `event_schedules`, `event_highlights`, `event_ticket_tiers` (oversell check + accurate `is_free` trigger), `event_rsvps`, and `event_ratings`. |
| 4 | `20261124000004_ticketing.sql` | Separate non-truncating sequences (`lit_order_number_seq`, `lit_ticket_code_seq`), `promo_codes`, `ticket_orders` (default `'pending'`, `on delete set null` + snapshots), `ticket_order_items`, `tickets` (48-hex-char `qr_payload`, trigger enforcing `admits_count = tier.group_size`), `event_staff`, and `stripe_webhook_events`. |
| 5 | `20261124000005_notifications_support.sql` | Creates `notifications` (server-side triggers for vibes, likes, comments, tags respecting blocks & mutes), `push_tokens`, `content_reports`, `app_ratings`, `faq_items`, and `support_tickets`. |
| 6 | `20261124000006_rls_and_grants.sql` | Defines `can_view_profile_content(p_owner uuid)`, enables RLS on all 28 tables, configures private `stories` storage read policy, and enforces strict table & **column-level grants** so clients cannot edit counters, badges, or moderation flags. |
| 7 | `20261124000007_rpc_functions.sql` | Production RPCs: `respond_to_vibe_request`, `record_story_view`, `validate_promo_code`, `create_pending_ticket_order` (`service_role`), `fulfill_order` (`service_role`), `check_in_ticket`, `request_account_deletion`, `get_home_feed`, `get_stories_tray`, `search_all`, and `recompute_counters` (`service_role`). |
| 8 | `20261124000008_cron_jobs.sql` | Scheduled `pg_cron` maintenance functions: `cron_recompute_trending_hashtags` (hourly, 72h window), `cron_cleanup_expired_stories` (daily, >30d expired), `cron_expire_pending_orders` (every 15m, >30m pending), and `cron_complete_past_events` (daily). |

---

## 2. All 28 Public Tables: Client-Allowed vs. Server-Only Writes

Every table in `public` has `relrowsecurity = true` and explicit `revoke all` followed by column-specific grants.

| Table | Client `SELECT` | Client `INSERT` (Allowed Columns) | Client `UPDATE` (Allowed Columns) | Client `DELETE` | Server-Only / Trigger / Edge Function Writes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `profiles` | Public (if not deleted/blocked) | Own row (`id, username, display_name, bio, avatar_url, website, location, twitter_handle, instagram_handle, is_private, show_activity_status`) | Own row (`username, display_name, bio, avatar_url, website, location, twitter_handle, instagram_handle, is_private, show_activity_status, last_active_at`) | **No** (use `request_account_deletion()` RPC) | `is_verified`, `posts_count`, `vibers_count`, `vibing_count`, `deleted_at` are trigger/server-only. |
| `user_settings` | Own row | Own row (`user_id, push_notifications, email_notifications`) | Own row (`push_notifications, email_notifications`) | **No** | Auto-created on profile insert. |
| `user_blocks` | Own blocks | Own (`blocker_id, blocked_id`) | **No** | Own blocks | Trigger removes `vibes` in both directions. |
| `user_mutes` | Own mutes | Own (`muter_id, muted_id`) | **No** | Own mutes | Used by feed, stories tray, and notification triggers. |
| `vibes` | Own or accepted on viewable profiles | Own (`follower_id, following_id` only) | **No** (use `respond_to_vibe_request()` RPC) | Follower or followed user | Trigger sets `status` (`pending` if target `is_private`, else `accepted`) and updates profile counters. |
| `locations` | Public | Authenticated (`name, address, city, country, latitude, longitude`) | **No** | **No** | `checkins_count` maintained by `posts` trigger. |
| `hashtags` | Public | **No** | **No** | **No** | Created by `sync_post_hashtags_from_caption` trigger on `posts`; `is_trending` updated by hourly cron job. |
| `posts` | Viewable profiles (`not is_hidden`) | Own (`author_id, caption, event_id, location_id, location_name, is_archived`) | Own (`caption, event_id, location_id, location_name, is_archived`) | Own posts | `likes_count`, `comments_count`, `shares_count`, `bookmarks_count`, `is_hidden` are trigger/moderation-only. |
| `post_media` | Viewable posts | Post author | Post author | Post author | — |
| `post_tags` | Viewable posts (not blocked) | Post author (`post_id, tagged_user_id, position_x, position_y`) | **No** | Post author or tagged user | Trigger checks blocks & sends `post_tag` notification. |
| `post_hashtags` | Viewable posts | **No** | **No** | **No** | Populated automatically by `posts` caption trigger. |
| `post_likes` | Viewable posts | Authenticated (`post_id, user_id`) | **No** | Own likes | Trigger updates `posts.likes_count` & sends notification. |
| `post_comments` | Viewable posts (`not is_hidden`) | Authenticated (`post_id, author_id, parent_id, content`) | Comment author (`content` only) | Comment author or post owner | `likes_count`, `is_hidden` are server/trigger-only. |
| `post_bookmarks` | Own bookmarks | Own (`post_id, user_id`) | **No** | Own bookmarks | Trigger updates `posts.bookmarks_count`. |
| `post_shares` | Post author or sharer | Authenticated (`post_id, user_id, channel`) | **No** | **No** | Unique `(post_id, user_id, channel)` prevents share inflation. |
| `stories` | Active stories on viewable profiles | Own (`author_id, media_url, storage_path, media_type, caption, text_overlay, font_family, text_color, text_position_x, text_position_y, expires_at`) | **No** | Own stories | `views_count`, `likes_count`, `flame_level`, `is_hidden`, `storage_purged_at` are trigger/cron-only. |
| `story_views` | **Viewer and story author only** | Via `record_story_view()` RPC (or own `story_id, viewer_id, liked` on active story) | Own (`liked` only, on active story) | **No** | Trigger rejects expired stories and updates `views_count`, `likes_count`, `flame_level`. |
| `events` | Published (`not is_hidden`) or own draft | Host (`host_id, title, slug, subtitle, description, category, status, cover_image_url, cover_storage_path, venue_name, address, city, latitude, longitude, location_id, timezone, starts_at, ends_at, doors_open_at, currency, capacity, external_ticket_url`) | Host (same editable columns) | **No** (cancel via `status = 'cancelled'`) | `is_free`, `starting_price_cents`, `going_count`, `interested_count`, `tickets_sold_count`, `rating_sum`, `ratings_count`, `rating_avg`, `is_featured`, `is_hidden` are trigger/server-only. |
| `event_media` | Readable events | Event host | Event host | Event host | Backs the 5-dot carousel on Event cards. |
| `event_schedules` | Readable events | Event host | Event host | Event host | — |
| `event_highlights` | Readable events | Event host | Event host | Event host | Single source of truth for event amenity pills. |
| `event_ticket_tiers` | Readable events | Event host (excluding `quantity_sold`) | Event host (excluding `quantity_sold`) | **No** | `quantity_sold` updated only by `create_pending_ticket_order`, `fulfill_order`, and `cron_expire_pending_orders`. |
| `event_rsvps` | Public (if not blocked) | Own (`event_id, user_id, status, guests_count`) | Own (`status, guests_count`) | Own RSVP | Trigger updates `events.going_count` & `interested_count` incrementally. |
| `event_ratings` | Public (if not blocked) | Own (`event_id, user_id, rating, review_text`) | Own (`rating, review_text`) | Own rating | Trigger updates `events.rating_sum`, `ratings_count`, `rating_avg` incrementally. |
| `promo_codes` | **No** (use `validate_promo_code()` RPC) | **No** | **No** | **No** | Managed by admin (`service_role`); `uses_count` incremented in `fulfill_order()`. |
| `ticket_orders` | Buyer or event host | **No** | **No** | **No** | Created by Checkout Edge Function via `create_pending_ticket_order()`; paid via `fulfill_order()`. |
| `ticket_order_items` | Buyer or event host | **No** | **No** | **No** | Created inside `create_pending_ticket_order()`. |
| `tickets` | Owner, event host, or `event_staff` | **No** | **No** (use `check_in_ticket()` RPC) | **No** | Minted inside `fulfill_order()`; checked in via `check_in_ticket(p_qr_payload, p_event_id)`. |
| `event_staff` | Event host or staff member | Event host (`event_id, user_id, role`) | Event host (`role`) | Event host | Authorizes door scanners for `check_in_ticket()`. |
| `stripe_webhook_events` | **No** | **No** | **No** | **No** | `service_role` only (Stripe webhook idempotency log). |
| `notifications` | Recipient only | **No** | Recipient (`is_read, read_at` only) | **No** | Created by `security definer` triggers and `fulfill_order()`. |
| `push_tokens` | Own tokens | Own (`user_id, expo_push_token, device_label`) | Own (`expo_push_token, device_label`) | Own tokens | Used by push notification dispatcher worker. |
| `content_reports` | Reporter only | Reporter (`reporter_id, target_type, target_id, reason, details`) | **No** | **No** | Admin moderation status & `is_hidden` flags are `service_role` only. |
| `app_ratings` | Own rating | Own (`user_id, rating, feedback, app_version`) | Own (`rating, feedback, app_version`) | Own rating | — |
| `faq_items` | Public (`is_published = true`) | **No** | **No** | **No** | Admin (`service_role`) / `seed.sql`. |
| `support_tickets` | Own tickets | Own (`user_id, subject, message, category`) | **No** | **No** | Support resolution status is `service_role` only. |

---

## 3. What the Server / Edge Functions Must Do

Because financial and administrative actions are locked out of client writes, your Edge Functions (or server endpoints using `SUPABASE_SERVICE_ROLE_KEY`) handle these 4 workflows:

1. **`create-checkout-intent` (Edge Function)**:
   - Verifies the caller's Supabase Auth JWT (`auth.uid()`).
   - Calls `select public.create_pending_ticket_order(p_buyer_id, p_event_id, p_items, p_promo_code, p_service_fee_cents)` using the `service_role` client. This locks `event_ticket_tiers` rows `for update`, reserves stock so two buyers cannot buy the last ticket, and returns `order_id`.
   - If `total_cents > 0`, creates a Stripe `PaymentIntent` with `metadata: { order_id }` and returns `{ order_id, client_secret }` to the mobile app.
   - If `total_cents = 0` (100% free tier or 100% promo discount), immediately calls `public.fulfill_order(order_id, 'free_' || order_id)`.
2. **`stripe-webhook` (Edge Function)**:
   - Verifies the `Stripe-Signature` header.
   - Inserts `event.id` into `public.stripe_webhook_events (id, type, payload) on conflict (id) do nothing`. If already present, returns `200 OK` immediately.
   - On `payment_intent.succeeded`, extracts `order_id` from metadata and calls `select public.fulfill_order(order_id, payment_intent.id)`.
   - On `payment_intent.canceled` or `payment_intent.payment_failed`, marks the pending order expired/cancelled and releases reserved tier stock.
3. **`purge-deleted-auth-users` (Scheduled Server Job)**:
   - After a user calls `public.request_account_deletion()`, their `public.profiles` row is soft-deleted (`deleted_at is not null`) and anonymized (`deleted_<shortid>`), while their `ticket_orders` and `tickets` remain intact.
   - A background admin job can delete `auth.users` via `supabase.auth.admin.deleteUser(id)` for soft-deleted profiles that do not host any events (`on delete set null` on `ticket_orders.buyer_id` and `tickets.owner_id` preserves financial rows when `profiles` is removed).
4. **Two-Factor Authentication (Supabase Auth MFA) in the App**:
   - All `two_factor_*` columns have been removed from `public.profiles` and `public.user_settings`.
   - The mobile app should use `supabase.auth.mfa.enroll({ factorType: 'totp' })` (or `'phone'` if an SMS provider like Twilio/MessageBird is configured in self-hosted GoTrue), `supabase.auth.mfa.challenge()`, and `supabase.auth.mfa.verify()`.

---

## 4. Open Questions for Product / Design Confirmation

1. **Event Categories (`events.category`)**:
   - On the **Events discovery filter bar (`283:2042`)**, the chips are `All`, `Nightlife`, `Music`, `Arts & Culture`, `Sports`, `Food & Drink`.
   - On the **Create Event — Basic Info screen (`607:12091`)**, the chips are `Music`, `Party`, `Festival`, `Food`, `Art`, `Tech`, `Business`, `Other`.
   - Currently, `public.events.category` allows the union of both sets (`'nightlife', 'music', 'party', 'festival', 'art', 'sports', 'food', 'tech', 'business', 'other'`). Which exact list should be canonical across both screens?
2. **Post Likes vs. LIT / MISS Reactions**:
   - The Figma **Home Feed (`283:833`)** and **Post View (`374:1109`)** show a single Heart (Like) counter (`post_likes`), while the other AI's draft (`0002_domain_schema.sql`) had a `reactions` table with `kind in ('lit', 'miss')`. We implemented `post_likes` to match the Figma Home Feed UI. Should we keep standard Heart likes (`post_likes`) or add a `'lit' | 'miss'` reaction kind?
3. **SMS 2FA vs. TOTP Authenticator App**:
   - The Figma 2FA screens (`607:13141`..`607:13736`) show SMS phone number verification (`+880 ••••••4821` and 6-digit SMS code). Self-hosted GoTrue supports Phone MFA (`factorType: 'phone'`), **but requires a paid SMS provider (Twilio, MessageBird, Vonage, or Textlocal) configured in GoTrue env vars**. Do you have an SMS provider configured on the Dokploy VPS, or should the app fall back to TOTP Authenticator / Email OTP until SMS is configured?
4. **Post Share Counting (`post_shares`)**:
   - To prevent share count inflation without requiring an Edge Function round-trip on every native share sheet open, we enforced `unique (post_id, user_id, channel)` where `channel in ('in_app', 'copy_link', 'external')` (so one user can increment `shares_count` at most once per channel per post). Is once-per-user-per-channel acceptable for MVP, or do you prefer moving share tracking to a rate-limited Edge Function?
