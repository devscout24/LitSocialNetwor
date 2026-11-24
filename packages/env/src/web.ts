import { createEnv } from "@t3-oss/env-core";
import { z } from "zod";

type ImportMetaEnvRecord = Record<string, string | boolean | undefined>;

export const env = createEnv({
  clientPrefix: "PUBLIC_",
  client: {
    PUBLIC_SUPABASE_URL: z.url({
      error:
        "Missing or invalid PUBLIC_SUPABASE_URL. Set it in apps/web/.env pointing at your self-hosted VPS Supabase instance.",
    }),
    PUBLIC_SUPABASE_ANON_KEY: z.string().min(1, {
      error:
        "Missing PUBLIC_SUPABASE_ANON_KEY. Set it in apps/web/.env with your VPS Supabase anon key.",
    }),
  },
  runtimeEnv: (import.meta as ImportMeta & { env: ImportMetaEnvRecord }).env,
  emptyStringAsUndefined: true,
});
