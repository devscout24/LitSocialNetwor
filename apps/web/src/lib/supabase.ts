import { env } from "@Lit-SocialNetwor/env/web";
import { createSupabaseClient, type TypedSupabaseClient } from "@Lit-SocialNetwor/supabase";

/**
 * Browser Supabase client for the Astro web app.
 * Configured via PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_ANON_KEY in apps/web/.env.
 */
export const supabase: TypedSupabaseClient = createSupabaseClient(
  env.PUBLIC_SUPABASE_URL,
  env.PUBLIC_SUPABASE_ANON_KEY,
);
