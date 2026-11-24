import {
  createClient,
  type SupabaseClient,
  type SupabaseClientOptions,
} from "@supabase/supabase-js";

import type { Database } from "./types";

export type TypedSupabaseClient = SupabaseClient<Database>;

/**
 * Shared factory for creating a typed Supabase client pointing at the
 * self-hosted VPS Supabase instance.
 *
 * Platform-specific auth storage (such as Expo SecureStore on React Native)
 * should be passed via `options.auth.storage` by the consuming app.
 */
export function createSupabaseClient(
  url: string,
  anonKey: string,
  options?: SupabaseClientOptions<"public">,
): TypedSupabaseClient {
  if (!url || !url.trim()) {
    throw new Error(
      "Missing Supabase URL: please configure the Supabase URL environment variable pointing at the VPS instance.",
    );
  }
  if (!anonKey || !anonKey.trim()) {
    throw new Error(
      "Missing Supabase anon key: please configure the Supabase anon key environment variable.",
    );
  }

  return createClient<Database>(url, anonKey, options);
}
