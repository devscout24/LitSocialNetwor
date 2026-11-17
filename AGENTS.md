# Lit-SocialNetwor

This file provides context about the project for AI assistants.

## Project Overview

- **Ecosystem**: Typescript

## Tech Stack

- **Runtime**: bun
- **Package Manager**: bun

### Frontend

- Framework: astro, native-uniwind
- CSS: tailwind

### Backend

- Framework: hono
- API: trpc
- Validation: zod

### Database

- Database: postgres
- ORM: drizzle

### Authentication

- Provider: better-auth

### Additional Features

- Testing: vitest-playwright
- Email: resend
- Realtime: socket-io
- Job Queue: bullmq
- Caching: redis
- Logging: winston

## Project Structure

```
Lit-SocialNetwor/
├── apps/
│   ├── web/         # Frontend application
│   ├── native/      # Mobile application (React Native)
│   └── server/      # Backend API
├── packages/
│   ├── api/         # API layer
│   ├── auth/        # Authentication
│   └── db/          # Database schema
```

## Common Commands

- `bun install` - Install dependencies
- `bun dev` - Start development server
- `bun build` - Build for production
- `bun test` - Run tests
- `bun db:push` - Push database schema
- `bun db:studio` - Open database UI

## Better Fullstack project context

`bts.jsonc` is the authority for the current Stack Graph. Its `stackParts` array owns role selection and `ownerPartId` bindings. Top-level option fields are a compatibility projection and must not become a second mutation path.

### Stack Parts, ownership, and evidence

- `backend.api:typescript:trpc`. It belongs to `backend:typescript:hono`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `backend.auth:typescript:better-auth`. It belongs to `backend:typescript:hono`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `backend.caching:typescript:redis`. It belongs to `backend:typescript:hono`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `backend.email:typescript:resend`. It belongs to `backend:typescript:hono`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `backend.jobQueue:typescript:bullmq`. It belongs to `backend:typescript:hono`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `backend.logging:typescript:winston`. It belongs to `backend:typescript:hono`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `backend.orm:typescript:drizzle`. It belongs to `backend:typescript:hono`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `backend.rateLimit:typescript:arcjet`. It belongs to `backend:typescript:hono`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `backend.realtime:typescript:socket-io`. It belongs to `backend:typescript:hono`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `backend.runtime:typescript:bun`. It belongs to `backend:typescript:hono`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `backend.search:typescript:elasticsearch`. It belongs to `backend:typescript:hono`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `backend.testing:typescript:vitest-playwright`. It belongs to `backend:typescript:hono`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `backend.validation:typescript:zod`. It belongs to `backend:typescript:hono`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `backend:typescript:hono`. Its generated target is `apps/server`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `codeQuality:universal:eslint`. Evidence is not mapped for this installed option.
- `codeQuality:universal:prettier`. Evidence is not mapped for this installed option.
- `containerOrchestration:universal:docker-compose`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `continuousIntegration:universal:github-actions`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `database:universal:postgres`. Its generated target is `packages/db`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `frontend.css:typescript:tailwind`. It belongs to `frontend:typescript:astro`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `frontend.forms:typescript:react-hook-form`. It belongs to `frontend:typescript:astro`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `frontend:typescript:astro`. Its generated target is `apps/web`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `mobile.auth:react-native:better-auth`. It belongs to `mobile:react-native:native-uniwind`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `mobile.deepLinking:react-native:expo-linking`. It belongs to `mobile:react-native:native-uniwind`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `mobile.navigation:react-native:expo-router`. It belongs to `mobile:react-native:native-uniwind`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `mobile.ota:react-native:expo-updates`. It belongs to `mobile:react-native:native-uniwind`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `mobile.push:react-native:expo-notifications`. It belongs to `mobile:react-native:native-uniwind`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `mobile.testing:react-native:maestro-react-native-testing-library`. It belongs to `mobile:react-native:native-uniwind`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `mobile.ui:react-native:uniwind`. It belongs to `mobile:react-native:native-uniwind`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `mobile:react-native:native-uniwind`. Its generated target is `apps/native`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.
- `workspaceRunner:universal:turborepo`. Evidence is `listed` with `unverified` freshness. Verification maintainer: @Marve10s.

### Installed-version authority

Use `bts.jsonc` for the generator and schema version. Use local package manifests and lockfiles for installed dependency versions. Do not assume that documentation for a newer Better Fullstack release matches this project.

### Compatibility and lifecycle safety

Run `create-better-fullstack context --json` for bounded roles, capabilities, evidence, compatibility issues, and safe next actions. Run `create-better-fullstack doctor --json` before repairing graph drift. Existing-project writes must start with a plan and use the exact review token. Use `create-better-fullstack recipes check --json` before editing recipe-owned paths or managed regions, and use recipe history plus project recovery commands to undo a reviewed operation.

User code outside an explicit Better Fullstack managed region is not generator-owned. Missing or changed managed-region hashes stop recipe planning for manual review.

<!-- <better-fullstack:recipes sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855> -->

<!-- </better-fullstack:recipes> -->

## Maintenance

Keep AGENTS.md updated when:

- Adding/removing dependencies
- Changing project structure
- Adding new features or services
- Modifying build/dev workflows

AI assistants should suggest updates to this file when they notice relevant changes.
