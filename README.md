# Lit-SocialNetwor

Monorepo for **Lit Social**, powered by **Bun workspaces**, **Turborepo**, and a **self-hosted Supabase** backend running on the project owner's VPS.

## Applications and Packages

- **`apps/native`** (Expo / React Native + Uniwind): Primary mobile application. Connects directly to the self-hosted VPS Supabase instance (Auth, Postgres with RLS, Storage).
- **`apps/web`** (Astro + Tailwind CSS v4): Web landing page (future use), pre-wired with a Supabase browser client.
- **`apps/dashboard`** (Vite + React + TypeScript): Admin dashboard shell (future use), pre-wired with a Supabase browser client.
- **`packages/supabase`** (`@Lit-SocialNetwor/supabase`): Shared Supabase client factory, `Database` TypeScript types, table/bucket constants, and SQL migration files (`packages/supabase/supabase/migrations/`).
- **`packages/env`** (`@Lit-SocialNetwor/env`): Zod-validated environment variable loaders for `native`, `web`, and `dashboard`.
- **`packages/config`** (`@Lit-SocialNetwor/config`): Shared TypeScript base configuration.

## Setup

1. Install dependencies from the workspace root:

```sh
bun install
```

2. Apply the SQL migrations in `packages/supabase/supabase/migrations/` to your self-hosted VPS Supabase instance (via Supabase Studio SQL Editor or `psql`). See [packages/supabase/README.md](packages/supabase/README.md) for step-by-step instructions.

3. Copy `.env.example` to `.env` in each app (`apps/native/.env`, `apps/web/.env`, `apps/dashboard/.env`) and fill in your self-hosted VPS Supabase URL and anon key.

## Local Development

Start the development servers:

```sh
# All apps via Turborepo
bun run dev

# Or run individual apps:
bun run dev:native
bun run dev:web
bun run dev:dashboard
```

## Type Checking & Builds

```sh
bun run check-types
bun run build
bun test
```
