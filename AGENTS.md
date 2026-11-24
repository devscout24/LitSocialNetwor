# Lit-SocialNetwor

This file provides context about the project for AI assistants.

## Project Overview

- **Product**: Lit Social (social + events platform)
- **Ecosystem**: TypeScript monorepo (Bun workspaces + Turborepo)
- **Backend Architecture**: 100% self-hosted **Supabase** running on the owner's VPS (Supabase Auth, PostgreSQL with Row Level Security, Supabase Storage, and Supabase-managed auth emails). There is no custom backend server and no local Docker stack in this repository.

## Tech Stack

- **Runtime & Package Manager**: Bun (`bun@1.4.4`)
- **Monorepo Runner**: Turborepo

### Mobile App (`apps/native` — Current Priority)

- **Framework**: Expo (~58) / React Native (0.88.1)
- **Navigation**: Expo Router (Drawer + Tabs + Modal)
- **Styling & UI**: Uniwind (Tailwind v4 for React Native), HeroUI Native
- **Backend Client**: `@supabase/supabase-js` via `@Lit-SocialNetwor/supabase` with `expo-secure-store` session persistence
- **Deep Linking Scheme**: `lit-socialnetwor://`

### Web Landing Page (`apps/web` — Future Use)

- **Framework**: Astro 7
- **CSS**: Tailwind CSS v4 (`@tailwindcss/vite`)
- **Backend Client**: `@Lit-SocialNetwor/supabase` (`apps/web/src/lib/supabase.ts`)

### Admin Dashboard (`apps/dashboard` — Future Use)

- **Framework**: Vite + plain React 19 + TypeScript (plain CSS, no UI library)
- **Backend Client**: `@Lit-SocialNetwor/supabase` (`apps/dashboard/src/lib/supabase.ts`)

### Shared Packages (`packages/*`)

- **`packages/supabase` (`@Lit-SocialNetwor/supabase`)**:
  - `src/client.ts` — Shared `createSupabaseClient` factory
  - `src/types.ts` — `Database` TypeScript definitions mirroring the SQL schema
  - `src/constants.ts` — Central table names (`profiles`) and storage bucket names (`avatars`, `posts`, `stories`, `events`)
  - `supabase/migrations/` — Ordered SQL migration files applied to the owner's self-hosted VPS Supabase instance
  - `supabase/seed.sql` — Intentionally empty seed file
- **`packages/env` (`@Lit-SocialNetwor/env`)**:
  - Zod-validated environment loaders (`./native`, `./web`, `./dashboard`)
- **`packages/config` (`@Lit-SocialNetwor/config`)**:
  - Base TypeScript configuration (`tsconfig.base.json`)

## Project Structure

```
Lit-SocialNetwor/
├── apps/
│   ├── native/      # Mobile application (Expo / React Native — primary focus)
│   ├── web/         # Astro web landing page (future use)
│   └── dashboard/   # Vite + React admin dashboard shell (future use)
├── packages/
│   ├── supabase/    # Shared Supabase client, types, constants & SQL migrations
│   ├── env/         # Validated environment schemas (native, web, dashboard)
│   └── config/      # Shared TypeScript configuration
```

## Environment Variables

All applications connect directly to the self-hosted VPS Supabase instance via environment variables:

- **`apps/native/.env`** (see `apps/native/.env.example`):
  - `EXPO_PUBLIC_SUPABASE_URL`
  - `EXPO_PUBLIC_SUPABASE_ANON_KEY`
  - `EXPO_PUBLIC_AUTH_REDIRECT_PATH` (default: `auth/callback`)
  - `EXPO_PUBLIC_EAS_PROJECT_ID` (optional)
- **`apps/web/.env`** (see `apps/web/.env.example`):
  - `PUBLIC_SUPABASE_URL`
  - `PUBLIC_SUPABASE_ANON_KEY`
- **`apps/dashboard/.env`** (see `apps/dashboard/.env.example`):
  - `VITE_SUPABASE_URL`
  - `VITE_SUPABASE_ANON_KEY`
- **Owner-only admin/CLI (`.env` at repo root, git-ignored)**:
  - `SUPABASE_SERVICE_ROLE_KEY` — **NEVER** import or bundle the service role key in any client app (`native`, `web`, `dashboard`). Client apps use only the anon key, protected by Postgres RLS.

## Common Commands

- `bun install` — Install dependencies
- `bun dev` — Start development servers via Turborepo
- `bun run dev:native` — Start Expo development server for mobile
- `bun run dev:web` — Start Astro web server
- `bun run dev:dashboard` — Start Vite dashboard server (port 5173)
- `bun run build` — Build applications for production
- `bun run check-types` — Run TypeScript type checks across all workspaces
- `bun test` — Run test suites
- `bun run db:types` — Print instructions to regenerate `packages/supabase/src/types.ts` from the VPS Supabase instance

## Better Fullstack Governance Notice

This repository was originally scaffolded with Better Fullstack (`bts.jsonc`), but the backend has been intentionally migrated to a self-hosted VPS Supabase architecture (`packages/supabase`).
- **Do NOT run `create-better-fullstack` to regenerate or mutate the backend, database, or auth layers.**
- `bts.jsonc` has been pruned to reflect only the remaining frontend, mobile, and workspace tooling parts.

## Maintenance

Keep `AGENTS.md` and `CLAUDE.md` updated when:
- Adding/removing dependencies
- Changing project structure or Supabase schema migrations
- Adding new features or services
- Modifying build/dev workflows
