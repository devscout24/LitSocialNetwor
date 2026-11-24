/**
 * Shared Supabase table and storage bucket names across all Lit-SocialNetwor apps.
 */

export const TABLES = {
  PROFILES: "profiles",
} as const;

export type TableName = (typeof TABLES)[keyof typeof TABLES];

export const STORAGE_BUCKETS = {
  AVATARS: "avatars",
  POSTS: "posts",
  STORIES: "stories",
  EVENTS: "events",
} as const;

export type StorageBucketName =
  (typeof STORAGE_BUCKETS)[keyof typeof STORAGE_BUCKETS];
