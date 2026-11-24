import { createEnv } from "@t3-oss/env-core";
import { z } from "zod";

export const env = createEnv({
  clientPrefix: "EXPO_PUBLIC_",
  client: {
    EXPO_PUBLIC_SUPABASE_URL: z.url({
      error:
        "Missing or invalid EXPO_PUBLIC_SUPABASE_URL. Set it in apps/native/.env pointing at your self-hosted VPS Supabase instance.",
    }),
    EXPO_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1, {
      error:
        "Missing EXPO_PUBLIC_SUPABASE_ANON_KEY. Set it in apps/native/.env with your VPS Supabase anon key.",
    }),
    EXPO_PUBLIC_AUTH_REDIRECT_PATH: z.string().default("auth/callback"),
    EXPO_PUBLIC_EAS_PROJECT_ID: z.string().optional(),
  },
  runtimeEnv: {
    EXPO_PUBLIC_SUPABASE_URL: process.env.EXPO_PUBLIC_SUPABASE_URL,
    EXPO_PUBLIC_SUPABASE_ANON_KEY: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY,
    EXPO_PUBLIC_AUTH_REDIRECT_PATH: process.env.EXPO_PUBLIC_AUTH_REDIRECT_PATH,
    EXPO_PUBLIC_EAS_PROJECT_ID: process.env.EXPO_PUBLIC_EAS_PROJECT_ID,
  },
  emptyStringAsUndefined: true,
});
