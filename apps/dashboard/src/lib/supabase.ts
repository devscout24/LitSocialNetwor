import { env } from "@Lit-SocialNetwor/env/dashboard";
import { createSupabaseClient, type TypedSupabaseClient } from "@Lit-SocialNetwor/supabase";

export function isSupabaseConfigured(): boolean {
  const url = import.meta.env.VITE_SUPABASE_URL;
  const key = import.meta.env.VITE_SUPABASE_ANON_KEY;
  return Boolean(
    typeof url === "string" &&
      url.trim().length > 0 &&
      typeof key === "string" &&
      key.trim().length > 0,
  );
}

let clientInstance: TypedSupabaseClient | null = null;

/**
 * Returns the typed browser Supabase client for the dashboard app.
 * Throws a clear error if VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY is missing.
 */
export function getSupabaseClient(): TypedSupabaseClient {
  if (!clientInstance) {
    clientInstance = createSupabaseClient(
      env.VITE_SUPABASE_URL,
      env.VITE_SUPABASE_ANON_KEY,
    );
  }
  return clientInstance;
}
