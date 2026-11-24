/**
 * Supabase Database schema types for Lit-SocialNetwor.
 *
 * Source of truth: `packages/supabase/supabase/migrations/`
 *   0. `0001_init_profiles_and_storage.sql`
 *   1. `20261124000001_fix_0001_and_extensions.sql`
 *   2. `20261124000002_social_core.sql`
 *   3. `20261124000003_events.sql`
 *   4. `20261124000004_ticketing.sql`
 *   5. `20261124000005_notifications_support.sql`
 *   6. `20261124000006_rls_and_grants.sql`
 *   7. `20261124000007_rpc_functions.sql`
 *   8. `20261124000008_cron_jobs.sql`
 *
 * To regenerate later from the self-hosted VPS Supabase instance:
 *   SUPABASE_DB_URL="postgresql://postgres:<password>@<vps-host>:5432/postgres" \
 *   bun run db:types
 */

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type VibeStatus = "pending" | "accepted";
export type MediaKind = "image" | "video";
export type EventCategory =
  | "nightlife"
  | "music"
  | "party"
  | "festival"
  | "art"
  | "sports"
  | "food"
  | "tech"
  | "business"
  | "other";
export type EventStatus = "draft" | "published" | "cancelled" | "completed";
export type RsvpStatus = "going" | "interested" | "not_going";
export type OrderStatus = "pending" | "paid" | "cancelled" | "refunded" | "expired";
export type TicketStatus = "valid" | "used" | "cancelled" | "transferred";
export type NotificationType =
  | "vibe_request"
  | "new_viber"
  | "vibe_accepted"
  | "post_like"
  | "post_comment"
  | "post_tag"
  | "event_rsvp"
  | "ticket_purchased"
  | "event_reminder"
  | "system";
export type ContentReportTargetType =
  | "profile"
  | "post"
  | "comment"
  | "story"
  | "event";
export type ContentReportReason =
  | "spam"
  | "harassment"
  | "inappropriate"
  | "scam"
  | "fake_event"
  | "other";
export type ContentReportStatus =
  | "open"
  | "reviewing"
  | "actioned"
  | "dismissed";

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          username: string | null;
          display_name: string | null;
          bio: string | null;
          avatar_url: string | null;
          website: string | null;
          location: string | null;
          twitter_handle: string | null;
          instagram_handle: string | null;
          is_private: boolean;
          show_activity_status: boolean;
          is_verified: boolean;
          posts_count: number;
          vibers_count: number;
          vibing_count: number;
          last_active_at: string | null;
          deleted_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          username?: string | null;
          display_name?: string | null;
          bio?: string | null;
          avatar_url?: string | null;
          website?: string | null;
          location?: string | null;
          twitter_handle?: string | null;
          instagram_handle?: string | null;
          is_private?: boolean;
          show_activity_status?: boolean;
        };
        Update: {
          username?: string | null;
          display_name?: string | null;
          bio?: string | null;
          avatar_url?: string | null;
          website?: string | null;
          location?: string | null;
          twitter_handle?: string | null;
          instagram_handle?: string | null;
          is_private?: boolean;
          show_activity_status?: boolean;
          last_active_at?: string | null;
        };
        Relationships: [];
      };
      user_settings: {
        Row: {
          user_id: string;
          push_notifications: boolean;
          email_notifications: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          user_id: string;
          push_notifications?: boolean;
          email_notifications?: boolean;
        };
        Update: {
          push_notifications?: boolean;
          email_notifications?: boolean;
        };
        Relationships: [];
      };
      user_blocks: {
        Row: {
          blocker_id: string;
          blocked_id: string;
          created_at: string;
        };
        Insert: {
          blocker_id: string;
          blocked_id: string;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      user_mutes: {
        Row: {
          muter_id: string;
          muted_id: string;
          created_at: string;
        };
        Insert: {
          muter_id: string;
          muted_id: string;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      vibes: {
        Row: {
          id: string;
          follower_id: string;
          following_id: string;
          status: VibeStatus;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          follower_id: string;
          following_id: string;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      locations: {
        Row: {
          id: string;
          name: string;
          address: string | null;
          city: string | null;
          country: string | null;
          latitude: number | null;
          longitude: number | null;
          checkins_count: number;
          created_at: string;
        };
        Insert: {
          name: string;
          address?: string | null;
          city?: string | null;
          country?: string | null;
          latitude?: number | null;
          longitude?: number | null;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      hashtags: {
        Row: {
          id: string;
          tag: string;
          display_tag: string;
          usage_count: number;
          is_trending: boolean;
          last_used_at: string;
          created_at: string;
        };
        Insert: {
          [_ in never]: never;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      stories: {
        Row: {
          id: string;
          author_id: string;
          media_url: string;
          storage_path: string | null;
          media_type: MediaKind;
          caption: string | null;
          text_overlay: string | null;
          font_family: string | null;
          text_color: string | null;
          text_position_x: number | null;
          text_position_y: number | null;
          views_count: number;
          likes_count: number;
          flame_level: number;
          is_hidden: boolean;
          expires_at: string;
          storage_purged_at: string | null;
          created_at: string;
        };
        Insert: {
          author_id: string;
          media_url: string;
          storage_path?: string | null;
          media_type?: MediaKind;
          caption?: string | null;
          text_overlay?: string | null;
          font_family?: string | null;
          text_color?: string | null;
          text_position_x?: number | null;
          text_position_y?: number | null;
          expires_at?: string;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      story_views: {
        Row: {
          id: string;
          story_id: string;
          viewer_id: string;
          liked: boolean;
          viewed_at: string;
        };
        Insert: {
          story_id: string;
          viewer_id: string;
          liked?: boolean;
        };
        Update: {
          liked?: boolean;
        };
        Relationships: [];
      };
      events: {
        Row: {
          id: string;
          host_id: string;
          title: string;
          slug: string | null;
          subtitle: string | null;
          description: string | null;
          category: EventCategory;
          status: EventStatus;
          cover_image_url: string | null;
          cover_storage_path: string | null;
          venue_name: string;
          address: string | null;
          city: string | null;
          latitude: number | null;
          longitude: number | null;
          location_id: string | null;
          timezone: string;
          starts_at: string;
          ends_at: string | null;
          doors_open_at: string | null;
          is_free: boolean;
          starting_price_cents: number;
          currency: string;
          capacity: number | null;
          going_count: number;
          interested_count: number;
          tickets_sold_count: number;
          rating_sum: number;
          ratings_count: number;
          rating_avg: number;
          external_ticket_url: string | null;
          is_featured: boolean;
          is_hidden: boolean;
          published_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          host_id: string;
          title: string;
          slug?: string | null;
          subtitle?: string | null;
          description?: string | null;
          category?: EventCategory;
          status?: EventStatus;
          cover_image_url?: string | null;
          cover_storage_path?: string | null;
          venue_name: string;
          address?: string | null;
          city?: string | null;
          latitude?: number | null;
          longitude?: number | null;
          location_id?: string | null;
          timezone?: string;
          starts_at: string;
          ends_at?: string | null;
          doors_open_at?: string | null;
          currency?: string;
          capacity?: number | null;
          external_ticket_url?: string | null;
        };
        Update: {
          title?: string;
          slug?: string | null;
          subtitle?: string | null;
          description?: string | null;
          category?: EventCategory;
          status?: EventStatus;
          cover_image_url?: string | null;
          cover_storage_path?: string | null;
          venue_name?: string;
          address?: string | null;
          city?: string | null;
          latitude?: number | null;
          longitude?: number | null;
          location_id?: string | null;
          timezone?: string;
          starts_at?: string;
          ends_at?: string | null;
          doors_open_at?: string | null;
          currency?: string;
          capacity?: number | null;
          external_ticket_url?: string | null;
        };
        Relationships: [];
      };
      event_media: {
        Row: {
          id: string;
          event_id: string;
          media_url: string;
          storage_path: string | null;
          media_type: MediaKind;
          sort_order: number;
          created_at: string;
        };
        Insert: {
          event_id: string;
          media_url: string;
          storage_path?: string | null;
          media_type?: MediaKind;
          sort_order?: number;
        };
        Update: {
          media_url?: string;
          storage_path?: string | null;
          media_type?: MediaKind;
          sort_order?: number;
        };
        Relationships: [];
      };
      event_schedules: {
        Row: {
          id: string;
          event_id: string;
          time_label: string;
          title: string;
          description: string | null;
          starts_at: string | null;
          sort_order: number;
          created_at: string;
        };
        Insert: {
          event_id: string;
          time_label: string;
          title: string;
          description?: string | null;
          starts_at?: string | null;
          sort_order?: number;
        };
        Update: {
          time_label?: string;
          title?: string;
          description?: string | null;
          starts_at?: string | null;
          sort_order?: number;
        };
        Relationships: [];
      };
      event_highlights: {
        Row: {
          id: string;
          event_id: string;
          label: string;
          icon_name: string | null;
          sort_order: number;
          created_at: string;
        };
        Insert: {
          event_id: string;
          label: string;
          icon_name?: string | null;
          sort_order?: number;
        };
        Update: {
          label?: string;
          icon_name?: string | null;
          sort_order?: number;
        };
        Relationships: [];
      };
      event_ticket_tiers: {
        Row: {
          id: string;
          event_id: string;
          name: string;
          description: string | null;
          perks: string[];
          price_cents: number;
          currency: string;
          quantity_total: number;
          quantity_sold: number;
          max_per_order: number;
          group_size: number;
          sort_order: number;
          is_active: boolean;
          sales_start_at: string | null;
          sales_end_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          event_id: string;
          name: string;
          description?: string | null;
          perks?: string[];
          price_cents?: number;
          currency?: string;
          quantity_total?: number;
          max_per_order?: number;
          group_size?: number;
          sort_order?: number;
          is_active?: boolean;
          sales_start_at?: string | null;
          sales_end_at?: string | null;
        };
        Update: {
          name?: string;
          description?: string | null;
          perks?: string[];
          price_cents?: number;
          currency?: string;
          quantity_total?: number;
          max_per_order?: number;
          group_size?: number;
          sort_order?: number;
          is_active?: boolean;
          sales_start_at?: string | null;
          sales_end_at?: string | null;
        };
        Relationships: [];
      };
      event_rsvps: {
        Row: {
          id: string;
          event_id: string;
          user_id: string;
          status: RsvpStatus;
          guests_count: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          event_id: string;
          user_id: string;
          status?: RsvpStatus;
          guests_count?: number;
        };
        Update: {
          status?: RsvpStatus;
          guests_count?: number;
        };
        Relationships: [];
      };
      event_ratings: {
        Row: {
          id: string;
          event_id: string;
          user_id: string;
          rating: number;
          review_text: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          event_id: string;
          user_id: string;
          rating: number;
          review_text?: string | null;
        };
        Update: {
          rating?: number;
          review_text?: string | null;
        };
        Relationships: [];
      };
      event_staff: {
        Row: {
          event_id: string;
          user_id: string;
          role: "scanner" | "manager";
          created_at: string;
        };
        Insert: {
          event_id: string;
          user_id: string;
          role?: "scanner" | "manager";
        };
        Update: {
          role?: "scanner" | "manager";
        };
        Relationships: [];
      };
      posts: {
        Row: {
          id: string;
          author_id: string;
          caption: string | null;
          event_id: string | null;
          location_id: string | null;
          location_name: string | null;
          likes_count: number;
          comments_count: number;
          shares_count: number;
          bookmarks_count: number;
          is_archived: boolean;
          is_hidden: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          author_id: string;
          caption?: string | null;
          event_id?: string | null;
          location_id?: string | null;
          location_name?: string | null;
          is_archived?: boolean;
        };
        Update: {
          caption?: string | null;
          event_id?: string | null;
          location_id?: string | null;
          location_name?: string | null;
          is_archived?: boolean;
        };
        Relationships: [];
      };
      post_media: {
        Row: {
          id: string;
          post_id: string;
          media_url: string;
          storage_path: string | null;
          thumbnail_url: string | null;
          media_type: MediaKind;
          width: number | null;
          height: number | null;
          duration_seconds: number | null;
          crop_metadata: Json | null;
          sort_order: number;
          created_at: string;
        };
        Insert: {
          post_id: string;
          media_url: string;
          storage_path?: string | null;
          thumbnail_url?: string | null;
          media_type?: MediaKind;
          width?: number | null;
          height?: number | null;
          duration_seconds?: number | null;
          crop_metadata?: Json | null;
          sort_order?: number;
        };
        Update: {
          media_url?: string;
          storage_path?: string | null;
          thumbnail_url?: string | null;
          media_type?: MediaKind;
          width?: number | null;
          height?: number | null;
          duration_seconds?: number | null;
          crop_metadata?: Json | null;
          sort_order?: number;
        };
        Relationships: [];
      };
      post_tags: {
        Row: {
          id: string;
          post_id: string;
          tagged_user_id: string;
          position_x: number | null;
          position_y: number | null;
          created_at: string;
        };
        Insert: {
          post_id: string;
          tagged_user_id: string;
          position_x?: number | null;
          position_y?: number | null;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      post_hashtags: {
        Row: {
          post_id: string;
          hashtag_id: string;
          created_at: string;
        };
        Insert: {
          [_ in never]: never;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      post_likes: {
        Row: {
          id: string;
          post_id: string;
          user_id: string;
          created_at: string;
        };
        Insert: {
          post_id: string;
          user_id: string;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      post_comments: {
        Row: {
          id: string;
          post_id: string;
          author_id: string;
          parent_id: string | null;
          content: string;
          likes_count: number;
          is_hidden: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          post_id: string;
          author_id: string;
          parent_id?: string | null;
          content: string;
        };
        Update: {
          content?: string;
        };
        Relationships: [];
      };
      post_bookmarks: {
        Row: {
          id: string;
          post_id: string;
          user_id: string;
          created_at: string;
        };
        Insert: {
          post_id: string;
          user_id: string;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      post_shares: {
        Row: {
          id: string;
          post_id: string;
          user_id: string;
          channel: "in_app" | "copy_link" | "external";
          created_at: string;
        };
        Insert: {
          post_id: string;
          user_id: string;
          channel?: "in_app" | "copy_link" | "external";
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      promo_codes: {
        Row: {
          id: string;
          event_id: string | null;
          code: string;
          discount_percent: number | null;
          discount_amount_cents: number | null;
          max_uses: number | null;
          uses_count: number;
          is_active: boolean;
          expires_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          [_ in never]: never;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      ticket_orders: {
        Row: {
          id: string;
          order_number: string;
          buyer_id: string | null;
          buyer_display_name_snapshot: string | null;
          buyer_email_snapshot: string | null;
          event_id: string;
          event_title_snapshot: string | null;
          promo_code_id: string | null;
          promo_code_text: string | null;
          subtotal_cents: number;
          service_fee_cents: number;
          discount_cents: number;
          total_cents: number;
          currency: string;
          payment_method: "stripe" | "apple_pay" | "free";
          stripe_payment_intent_id: string | null;
          status: OrderStatus;
          stock_reserved: boolean;
          expires_at: string;
          paid_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          [_ in never]: never;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      ticket_order_items: {
        Row: {
          id: string;
          order_id: string;
          tier_id: string;
          tier_name: string;
          group_size: number;
          unit_price_cents: number;
          quantity: number;
          line_total_cents: number;
          created_at: string;
        };
        Insert: {
          [_ in never]: never;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      tickets: {
        Row: {
          id: string;
          ticket_code: string;
          order_id: string;
          order_item_id: string | null;
          event_id: string;
          tier_id: string;
          owner_id: string | null;
          holder_name_snapshot: string | null;
          event_title_snapshot: string | null;
          tier_name: string;
          seat_or_table_label: string | null;
          admits_count: number;
          qr_payload: string;
          status: TicketStatus;
          checked_in_at: string | null;
          checked_in_by: string | null;
          transferred_to_id: string | null;
          transferred_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          [_ in never]: never;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      stripe_webhook_events: {
        Row: {
          id: string;
          type: string;
          payload: Json;
          processed_at: string;
        };
        Insert: {
          [_ in never]: never;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      notifications: {
        Row: {
          id: string;
          recipient_id: string;
          actor_id: string | null;
          type: NotificationType;
          title: string;
          body: string | null;
          post_id: string | null;
          event_id: string | null;
          ticket_id: string | null;
          metadata: Json;
          is_read: boolean;
          read_at: string | null;
          created_at: string;
        };
        Insert: {
          [_ in never]: never;
        };
        Update: {
          is_read?: boolean;
          read_at?: string | null;
        };
        Relationships: [];
      };
      push_tokens: {
        Row: {
          id: string;
          user_id: string;
          expo_push_token: string;
          device_label: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          user_id: string;
          expo_push_token: string;
          device_label?: string | null;
        };
        Update: {
          expo_push_token?: string;
          device_label?: string | null;
        };
        Relationships: [];
      };
      content_reports: {
        Row: {
          id: string;
          reporter_id: string;
          target_type: ContentReportTargetType;
          target_id: string;
          reason: ContentReportReason;
          details: string | null;
          status: ContentReportStatus;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          reporter_id: string;
          target_type: ContentReportTargetType;
          target_id: string;
          reason: ContentReportReason;
          details?: string | null;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      app_ratings: {
        Row: {
          id: string;
          user_id: string;
          rating: number;
          feedback: string | null;
          app_version: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          user_id: string;
          rating: number;
          feedback?: string | null;
          app_version?: string | null;
        };
        Update: {
          rating?: number;
          feedback?: string | null;
          app_version?: string | null;
        };
        Relationships: [];
      };
      faq_items: {
        Row: {
          id: string;
          question: string;
          answer: string;
          category: string;
          sort_order: number;
          is_published: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          [_ in never]: never;
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
      support_tickets: {
        Row: {
          id: string;
          user_id: string;
          subject: string;
          message: string;
          category: "support" | "ticket_transfer" | "report_content" | "billing" | "other";
          status: "open" | "in_progress" | "resolved" | "closed";
          created_at: string;
          updated_at: string;
        };
        Insert: {
          user_id: string;
          subject: string;
          message: string;
          category?: "support" | "ticket_transfer" | "report_content" | "billing" | "other";
        };
        Update: {
          [_ in never]: never;
        };
        Relationships: [];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      can_view_profile_content: {
        Args: { p_owner: string };
        Returns: boolean;
      };
      is_blocked_between: {
        Args: { p_user_a: string; p_user_b: string };
        Returns: boolean;
      };
      respond_to_vibe_request: {
        Args: { p_follower: string; p_accept: boolean };
        Returns: string;
      };
      record_story_view: {
        Args: { p_story_id: string; p_liked?: boolean };
        Returns: undefined;
      };
      validate_promo_code: {
        Args: { p_event_id: string; p_code: string };
        Returns: {
          promo_code_id: string;
          code: string;
          discount_percent: number | null;
          discount_amount_cents: number | null;
        }[];
      };
      check_in_ticket: {
        Args: { p_qr_payload: string; p_event_id?: string | null };
        Returns: Json;
      };
      request_account_deletion: {
        Args: Record<PropertyKey, never>;
        Returns: undefined;
      };
      get_home_feed: {
        Args: {
          p_before_created_at?: string | null;
          p_before_id?: string | null;
          p_limit?: number;
        };
        Returns: {
          id: string;
          author_id: string;
          author_username: string | null;
          author_display_name: string | null;
          author_avatar_url: string | null;
          author_is_verified: boolean;
          caption: string | null;
          event_id: string | null;
          location_id: string | null;
          location_name: string | null;
          likes_count: number;
          comments_count: number;
          shares_count: number;
          bookmarks_count: number;
          liked_by_me: boolean;
          bookmarked_by_me: boolean;
          created_at: string;
        }[];
      };
      get_stories_tray: {
        Args: Record<PropertyKey, never>;
        Returns: {
          author_id: string;
          author_username: string | null;
          author_display_name: string | null;
          author_avatar_url: string | null;
          stories_count: number;
          has_unseen: boolean;
          max_flame_level: number;
          latest_story_at: string;
        }[];
      };
      search_all: {
        Args: { p_query: string; p_limit?: number };
        Returns: {
          entity_type: string;
          entity_id: string;
          title: string;
          subtitle: string;
          image_url: string | null;
          metric_value: number;
        }[];
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

export type Profile = Database["public"]["Tables"]["profiles"]["Row"];
export type ProfileInsert = Database["public"]["Tables"]["profiles"]["Insert"];
export type ProfileUpdate = Database["public"]["Tables"]["profiles"]["Update"];

export type UserSettings = Database["public"]["Tables"]["user_settings"]["Row"];
export type UserBlock = Database["public"]["Tables"]["user_blocks"]["Row"];
export type UserMute = Database["public"]["Tables"]["user_mutes"]["Row"];
export type Vibe = Database["public"]["Tables"]["vibes"]["Row"];
export type Location = Database["public"]["Tables"]["locations"]["Row"];
export type Hashtag = Database["public"]["Tables"]["hashtags"]["Row"];
export type Story = Database["public"]["Tables"]["stories"]["Row"];
export type StoryView = Database["public"]["Tables"]["story_views"]["Row"];
export type Event = Database["public"]["Tables"]["events"]["Row"];
export type EventMedia = Database["public"]["Tables"]["event_media"]["Row"];
export type EventSchedule = Database["public"]["Tables"]["event_schedules"]["Row"];
export type EventHighlight = Database["public"]["Tables"]["event_highlights"]["Row"];
export type EventTicketTier = Database["public"]["Tables"]["event_ticket_tiers"]["Row"];
export type EventRsvp = Database["public"]["Tables"]["event_rsvps"]["Row"];
export type EventRating = Database["public"]["Tables"]["event_ratings"]["Row"];
export type EventStaff = Database["public"]["Tables"]["event_staff"]["Row"];
export type Post = Database["public"]["Tables"]["posts"]["Row"];
export type PostMedia = Database["public"]["Tables"]["post_media"]["Row"];
export type PostTag = Database["public"]["Tables"]["post_tags"]["Row"];
export type PostLike = Database["public"]["Tables"]["post_likes"]["Row"];
export type PostComment = Database["public"]["Tables"]["post_comments"]["Row"];
export type PostBookmark = Database["public"]["Tables"]["post_bookmarks"]["Row"];
export type TicketOrder = Database["public"]["Tables"]["ticket_orders"]["Row"];
export type TicketOrderItem = Database["public"]["Tables"]["ticket_order_items"]["Row"];
export type Ticket = Database["public"]["Tables"]["tickets"]["Row"];
export type Notification = Database["public"]["Tables"]["notifications"]["Row"];
export type PushToken = Database["public"]["Tables"]["push_tokens"]["Row"];
export type ContentReport = Database["public"]["Tables"]["content_reports"]["Row"];
export type AppRating = Database["public"]["Tables"]["app_ratings"]["Row"];
export type FaqItem = Database["public"]["Tables"]["faq_items"]["Row"];
export type SupportTicket = Database["public"]["Tables"]["support_tickets"]["Row"];
