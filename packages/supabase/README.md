# `@Lit-SocialNetwor/supabase`

Shared Supabase package for the `Lit-SocialNetwor` monorepo. Replaces the old custom database/API/auth packages (`packages/db`, `packages/api`, `packages/auth`).

## Architecture Overview

- **Self-Hosted VPS Instance**: Supabase runs on the project owner's self-hosted VPS instance. This repository **never** starts a local Supabase stack or Docker containers.
- **Package Contents**:
  - `src/client.ts` — Shared `createSupabaseClient(url, anonKey, options?)` factory typed against `Database`.
  - `src/types.ts` — TypeScript `Database` schema types matching `supabase/migrations/`.
  - `src/constants.ts` — Shared table (`profiles`) and storage bucket (`avatars`, `posts`, `stories`, `events`) constants.
  - `supabase/migrations/` — Ordered SQL migration files to be applied to the VPS Supabase instance.
  - `supabase/seed.sql` — Intentionally empty seed file.

---

## How to Apply Migrations to the VPS Supabase Instance

Apply files in `supabase/migrations/` in filename order using either method below:

### Option A: Self-Hosted Supabase Studio (SQL Editor)
1. Open your self-hosted Supabase Studio dashboard in the browser.
2. Go to **SQL Editor** → **New query**.
3. Copy and paste the contents of `supabase/migrations/20261124000000_init_profiles_and_storage.sql`.
4. Click **Run**.

### Option B: `psql` CLI against the VPS PostgreSQL port
```sh
psql "$SUPABASE_DB_URL" -f packages/supabase/supabase/migrations/20261124000000_init_profiles_and_storage.sql
```

---

## Required Supabase Auth Configuration on the VPS

For mobile password reset deep links to work in `apps/native`:
1. In your self-hosted Supabase Auth configuration (Studio → Authentication → URL Configuration, or `GOTRUE_URI_ALLOW_LIST` on the VPS), add the mobile deep-link redirect URL to the allow-list:
   - `lit-socialnetwor://auth/callback` (and `lit-socialnetwor://**` if wildcards are used)
2. Ensure your VPS Supabase Auth SMTP / email settings are configured so password recovery and verification emails can be delivered.

---

## Environment Variables per Application

Each application connects directly to the VPS Supabase instance via its `.env` file (copied from `.env.example`):

| Workspace | Environment Variables |
| :--- | :--- |
| `apps/native` | `EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_ANON_KEY`, `EXPO_PUBLIC_AUTH_REDIRECT_PATH` (default `auth/callback`), `EXPO_PUBLIC_EAS_PROJECT_ID` (optional) |
| `apps/web` | `PUBLIC_SUPABASE_URL`, `PUBLIC_SUPABASE_ANON_KEY` |
| `apps/dashboard` | `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` |
| Owner-only CLI / admin | `SUPABASE_SERVICE_ROLE_KEY` (local git-ignored `.env` only — **never** imported by any app) |

### Security Notice: Anon Key vs. Service Role Key

- **Anon / Publishable Key (`*_SUPABASE_ANON_KEY`)**: Safe to use in client applications (`native`, `web`, `dashboard`) because **Row Level Security (RLS)** is enabled on `public.profiles` and `storage.objects`.
- **Service Role Key (`SUPABASE_SERVICE_ROLE_KEY`)**: Bypasses all RLS policies. **NEVER** put the service role key in `apps/native`, `apps/web`, `apps/dashboard`, or any `EXPO_PUBLIC_*` / `PUBLIC_*` / `VITE_*` variable.
