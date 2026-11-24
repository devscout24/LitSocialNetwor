# `@Lit-SocialNetwor/supabase`

Shared Supabase package for the `Lit-SocialNetwor` monorepo. Replaces the old custom database/API/auth packages (`packages/db`, `packages/api`, `packages/auth`).

## Architecture Overview

- **Self-Hosted VPS Instance**: Supabase runs on the project owner's self-hosted VPS instance (Dokploy). This repository **never** starts a local Supabase stack or Docker containers, and uses zero Supabase Cloud-only features.
- **Package Contents**:
  - `src/client.ts` — Shared `createSupabaseClient(url, anonKey, options?)` factory typed against `Database`.
  - `src/types.ts` — TypeScript `Database` schema types matching `supabase/migrations/` (31 tables + 10 client-callable RPC functions).
  - `src/constants.ts` — Shared table (`TABLES`, 31 tables) and storage bucket (`STORAGE_BUCKETS`: `avatars`, `posts`, `stories`, `events`) constants.
  - `supabase/migrations/` — Ordered, re-runnable SQL migration files applied to the VPS Supabase instance:
    0. `0001_init_profiles_and_storage.sql` — Base `public.profiles`, `set_updated_at()`, `handle_new_user()`, and storage buckets/policies (kept unmodified).
    1. `20261124000001_fix_0001_and_extensions.sql` — `extensions` schema (`pgcrypto`, `pg_trgm`), `handle_new_user()` `check_violation` fix, bucket MIME/size limits, and private `stories` bucket.
    2. `20261124000002_social_core.sql` — Profiles extension, settings, blocks, mutes, vibes, locations, hashtags, posts, media, tags, likes, comments, bookmarks, shares, stories, and story views.
    3. `20261124000003_events.sql` — Events (with `timezone`), `event_media` carousel, schedules, highlights, ticket tiers, RSVPs, and ratings.
    4. `20261124000004_ticketing.sql` — Non-truncating sequences, promo codes, ticket orders, order items, QR tickets, event staff, and Stripe webhook idempotency log.
    5. `20261124000005_notifications_support.sql` — Server-triggered notifications, Expo push tokens, content reports, app ratings, FAQs, and support tickets.
    6. `20261124000006_rls_and_grants.sql` — `can_view_profile_content()` helper, RLS on all 31 tables, and column-level grants.
    7. `20261124000007_rpc_functions.sql` — Production RPCs (`get_home_feed`, `get_stories_tray`, `search_all`, `respond_to_vibe_request`, `record_story_view`, `validate_promo_code`, `check_in_ticket`, `request_account_deletion`, `create_pending_ticket_order`, `fulfill_order`, `recompute_counters`).
    8. `20261124000008_cron_jobs.sql` — Scheduled `pg_cron` maintenance functions.
  - `supabase/seed.sql` — Dev-only reference seed data (hashtags, venues, universities, FAQs with realistic zero counts).
  - `supabase/tests/rls_attacks.sql` — Security & RLS attack verification suite.
  - `SCHEMA_NOTES.md` — Full table matrix, client vs. server-only writes, Edge Function responsibilities, and open design questions.

---

## How to Apply Migrations to the VPS Supabase Instance

Apply files in `supabase/migrations/` in filename order using either method below:

### Option A: Self-Hosted Supabase Studio (SQL Editor)
Run each file in `packages/supabase/supabase/migrations/` in filename order (`0001_...` through `20261124000008_...`) inside **SQL Editor → New query**. For development environments, run `supabase/seed.sql` afterward.

### Option B: `psql` CLI against the VPS PostgreSQL port
```sh
export SUPABASE_DB_URL="postgresql://postgres:YOUR_DB_PASSWORD@YOUR_VPS_HOST:5432/postgres"

for f in packages/supabase/supabase/migrations/*.sql; do
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$f"
done
```
