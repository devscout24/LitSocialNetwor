/**
 * Shared Supabase table and storage bucket names across all Lit-SocialNetwor apps.
 */

export const TABLES = {
  PROFILES: "profiles",
  USER_SETTINGS: "user_settings",
  USER_BLOCKS: "user_blocks",
  USER_MUTES: "user_mutes",
  VIBES: "vibes",
  LOCATIONS: "locations",
  HASHTAGS: "hashtags",
  STORIES: "stories",
  STORY_VIEWS: "story_views",
  EVENTS: "events",
  EVENT_MEDIA: "event_media",
  EVENT_SCHEDULES: "event_schedules",
  EVENT_HIGHLIGHTS: "event_highlights",
  EVENT_TICKET_TIERS: "event_ticket_tiers",
  EVENT_RSVPS: "event_rsvps",
  EVENT_RATINGS: "event_ratings",
  EVENT_STAFF: "event_staff",
  POSTS: "posts",
  POST_MEDIA: "post_media",
  POST_TAGS: "post_tags",
  POST_HASHTAGS: "post_hashtags",
  POST_LIKES: "post_likes",
  POST_COMMENTS: "post_comments",
  POST_BOOKMARKS: "post_bookmarks",
  POST_SHARES: "post_shares",
  PROMO_CODES: "promo_codes",
  TICKET_ORDERS: "ticket_orders",
  TICKET_ORDER_ITEMS: "ticket_order_items",
  TICKETS: "tickets",
  STRIPE_WEBHOOK_EVENTS: "stripe_webhook_events",
  NOTIFICATIONS: "notifications",
  PUSH_TOKENS: "push_tokens",
  CONTENT_REPORTS: "content_reports",
  APP_RATINGS: "app_ratings",
  FAQ_ITEMS: "faq_items",
  SUPPORT_TICKETS: "support_tickets",
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
