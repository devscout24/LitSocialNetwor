-- =============================================================================
-- LIT Social — Dev-Only Seed Data (`packages/supabase/supabase/seed.sql`)
-- Purpose:
--   Seeds initial reference data from the Figma Final Design (hashtags,
--   NYC venues, Dhaka universities, and Help Center FAQ items) for local/dev
--   environments only.
--   - Uses realistic zero counts (`usage_count = 0`, `checkins_count = 0`).
--   - Safe to run multiple times (`on conflict do nothing`).
-- =============================================================================

-- 1. Figma Discover Hashtags (zero initial usage counts)
insert into public.hashtags (tag, display_tag, usage_count, is_trending)
values
  ('rooftopvibes',    '#RooftopVibes',    0, false),
  ('neonnights',      '#NeonNights',      0, false),
  ('luminousjourney', '#LuminousJourney', 0, false),
  ('electricdreams',  '#ElectricDreams',  0, false),
  ('urbanvibes',      '#UrbanVibes',      0, false),
  ('starlitescape',   '#StarlitEscape',   0, false),
  ('midnightglow',    '#MidnightGlow',    0, false),
  ('cosmicbeats',     '#CosmicBeats',     0, false),
  ('radiantreverie',  '#RadiantReverie',  0, false)
on conflict (tag) do nothing;

-- 2. Figma Event Venues & Add-Location Places (zero initial check-in counts)
insert into public.locations (name, city, country, latitude, longitude, checkins_count)
values
  ('Warehouse 23', 'Brooklyn, NY', 'USA', 40.7081, -73.9571, 0),
  ('Warehouse 12', 'Brooklyn, NY', 'USA', 40.7128, -73.9495, 0),
  ('Sky Lounge', 'New York, NY', 'USA', 40.7505, -73.9934, 0),
  ('The Gallery District', 'New York, NY', 'USA', 40.7465, -74.0014, 0),
  ('Bangladesh University of Engineering and Technology (BUET)', 'Dhaka', 'Bangladesh', 23.7260, 90.3925, 0),
  ('University of Dhaka', 'Dhaka', 'Bangladesh', 23.7340, 90.3928, 0),
  ('BRAC University', 'Dhaka', 'Bangladesh', 23.7732, 90.4254, 0),
  ('Govt. Titumir College', 'Dhaka', 'Bangladesh', 23.7796, 90.4051, 0),
  ('North South University', 'Dhaka', 'Bangladesh', 23.8151, 90.4255, 0),
  ('Jagannath University', 'Dhaka', 'Bangladesh', 23.7088, 90.4114, 0),
  ('Dhaka College', 'Dhaka', 'Bangladesh', 23.7336, 90.3834, 0),
  ('East West University', 'Dhaka', 'Bangladesh', 23.7685, 90.4256, 0),
  ('IUBAT', 'Dhaka', 'Bangladesh', 23.8883, 90.3907, 0)
on conflict (name, city) do nothing;

-- 3. Figma Help Center FAQ Items (screen 607:13647)
insert into public.faq_items (question, answer, category, sort_order, is_published)
values
  (
    'How do I RSVP for an event?',
    'Open any event from the Discover or Events tab and tap the RSVP or Buy Ticket button on the Event Details screen.',
    'events',
    1,
    true
  ),
  (
    'Can I cancel my ticket?',
    'Tickets are non-refundable once purchased. You can transfer your ticket to another user by contacting our support team within 48 hours of purchase.',
    'tickets',
    2,
    true
  ),
  (
    'How does the Vibe system work?',
    'Tap Vibe on any user profile or Discover card to follow their posts, stories, and event activity. Your followers are your Vibers, and people you follow are your Vibing list.',
    'social',
    3,
    true
  ),
  (
    'How do I report inappropriate content?',
    'Tap the menu icon on any post or profile and select Report, or submit a ticket through Contact Support below.',
    'safety',
    4,
    true
  ),
  (
    'Can I make my account private?',
    'Yes! Go to Profile -> Settings -> Privacy & Safety and toggle on Private Account so only approved Vibers can see your content.',
    'privacy',
    5,
    true
  ),
  (
    'How do I delete my account?',
    'Go to Profile -> Settings -> Account Action and tap Delete Account.',
    'account',
    6,
    true
  )
on conflict do nothing;
