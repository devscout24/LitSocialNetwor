/**
 * Migrate `packages/supabase/supabase/migrations/` to your self-hosted VPS Supabase instance
 * using the official Supabase CLI (`bunx supabase db push`).
 *
 * Usage:
 *   SUPABASE_DB_URL="postgresql://postgres:<password>@<host>:5432/postgres" bun run db:migrate
 *
 * Or pass just the password (auto-encoded) for the configured VPS host:
 *   SUPABASE_DB_PASSWORD="<raw-password>" bun run db:migrate
 *
 * Optional flags:
 *   --dry-run            Preview pending migrations without modifying the database
 *   --seed               Also apply `supabase/seed.sql` (dev environments only)
 *   --mark-0001-applied  Mark `0001` as already applied if you ran it manually in Studio
 */

import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { config as loadEnv } from "dotenv";

const REPO_ROOT = resolve(import.meta.dir, "../../..");
const SUPABASE_WORKDIR = resolve(import.meta.dir, "..");

// Load root `.env` if present (git-ignored)
const rootEnvPath = resolve(REPO_ROOT, ".env");
if (existsSync(rootEnvPath)) {
  loadEnv({ path: rootEnvPath });
}

const args = new Set(process.argv.slice(2));
const isDryRun = args.has("--dry-run");
const includeSeed = args.has("--seed");
const mark0001Applied = args.has("--mark-0001-applied");

function buildDbUrl(): string {
  const directUrl = process.env.SUPABASE_DB_URL?.trim();
  if (directUrl) {
    return directUrl;
  }

  const password = process.env.SUPABASE_DB_PASSWORD?.trim();
  if (password) {
    const host =
      process.env.SUPABASE_DB_HOST?.trim() ||
      "lit-social-supabase-ff3798-187-77-98-46.sslip.io";
    const port = process.env.SUPABASE_DB_PORT?.trim() || "5432";
    const user = process.env.SUPABASE_DB_USER?.trim() || "postgres";
    const dbName = process.env.SUPABASE_DB_NAME?.trim() || "postgres";
    return `postgresql://${encodeURIComponent(user)}:${encodeURIComponent(password)}@${host}:${port}/${dbName}`;
  }

  console.error(
    [
      "Error: Missing database connection credentials.",
      "",
      "Set either:",
      '  export SUPABASE_DB_URL="postgresql://postgres:<PASSWORD>@lit-social-supabase-ff3798-187-77-98-46.sslip.io:5432/postgres"',
      "or:",
      '  export SUPABASE_DB_PASSWORD="<RAW_POSTGRES_PASSWORD>"',
      "",
      "You can find POSTGRES_PASSWORD in Dokploy -> Supabase -> Environment.",
    ].join("\n"),
  );
  process.exit(1);
}

function runSupabaseCli(cliArgs: string[]): void {
  const proc = Bun.spawnSync(["bunx", "supabase", ...cliArgs], {
    cwd: REPO_ROOT,
    stdout: "inherit",
    stderr: "inherit",
    stdin: "inherit",
  });

  if (proc.exitCode !== 0) {
    process.exit(proc.exitCode ?? 1);
  }
}

const dbUrl = buildDbUrl();

if (mark0001Applied) {
  console.log("Marking migration 0001 as already applied...");
  runSupabaseCli([
    "migration",
    "repair",
    "--workdir",
    SUPABASE_WORKDIR,
    "--db-url",
    dbUrl,
    "--status",
    "applied",
    "0001",
  ]);
}

const pushArgs = [
  "db",
  "push",
  "--workdir",
  SUPABASE_WORKDIR,
  "--db-url",
  dbUrl,
];

if (isDryRun) {
  pushArgs.push("--dry-run");
}

if (includeSeed) {
  pushArgs.push("--include-seed");
}

console.log(
  isDryRun
    ? "Running dry-run migration check against self-hosted Supabase..."
    : "Applying migrations to self-hosted Supabase...",
);

runSupabaseCli(pushArgs);

console.log("\nDone! Refresh Database -> Migrations in Supabase Studio to verify.");
