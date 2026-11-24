-- =============================================================================
-- LIT Social — Migration 20261124000004: Ticketing
-- Target: Self-hosted Supabase (PostgreSQL 15+)
-- Contents:
--   1. Separate non-truncating sequences and generator functions for
--      `order_number` (`ORD-YYYY-01001`..`ORD-YYYY-100000+`) and
--      `ticket_code` (`LIT-YYYY-00482`..`LIT-YYYY-100000+`).
--   2. `public.promo_codes` (server-only table; validated via RPC).
--   3. `public.ticket_orders` (default status `'pending'`, `on delete set null`
--      for buyer + snapshot columns so financial records are never lost).
--   4. `public.ticket_order_items` (`on delete restrict`).
--   5. `public.tickets` (`on delete restrict` / `set null` for owner + snapshot
--      columns, cryptographic 48-hex-char `qr_payload`, trigger enforcing
--      `admits_count = tier.group_size`).
--   6. `public.event_staff` (authorized door scanners per event).
--   7. `public.stripe_webhook_events` (idempotency log for Stripe webhooks).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Separate Non-Truncating Sequences & Code Generators
-- -----------------------------------------------------------------------------
create sequence if not exists public.lit_order_number_seq start 1001;
create sequence if not exists public.lit_ticket_code_seq start 482;

create or replace function public.next_order_number()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n bigint;
begin
  v_n := pg_catalog.nextval('public.lit_order_number_seq');
  return 'ORD-'
    || pg_catalog.to_char(pg_catalog.now(), 'YYYY')
    || '-'
    || pg_catalog.lpad(v_n::text, greatest(5, pg_catalog.length(v_n::text)), '0');
end;
$$;

revoke all on function public.next_order_number() from public, anon, authenticated;

create or replace function public.next_ticket_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n bigint;
begin
  v_n := pg_catalog.nextval('public.lit_ticket_code_seq');
  return 'LIT-'
    || pg_catalog.to_char(pg_catalog.now(), 'YYYY')
    || '-'
    || pg_catalog.lpad(v_n::text, greatest(5, pg_catalog.length(v_n::text)), '0');
end;
$$;

revoke all on function public.next_ticket_code() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Promo Codes (`public.promo_codes`) — Not Publicly Listable
-- -----------------------------------------------------------------------------
create table if not exists public.promo_codes (
  id                    uuid primary key default gen_random_uuid(),
  event_id              uuid references public.events (id) on delete restrict,
  code                  text not null unique
                        check (char_length(btrim(code)) between 2 and 40),
  discount_percent      smallint
                        check (discount_percent is null or (discount_percent between 1 and 100)),
  discount_amount_cents integer
                        check (discount_amount_cents is null or discount_amount_cents > 0),
  max_uses              integer check (max_uses is null or max_uses > 0),
  uses_count            integer not null default 0 check (uses_count >= 0),
  is_active             boolean not null default true,
  expires_at            timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint promo_codes_discount_kind check (
    (discount_percent is not null and discount_amount_cents is null)
    or (discount_percent is null and discount_amount_cents is not null)
  ),
  constraint promo_codes_max_uses_bound check (
    max_uses is null or uses_count <= max_uses
  )
);

create index if not exists idx_promo_codes_event_id
  on public.promo_codes (event_id);

drop trigger if exists promo_codes_set_updated_at on public.promo_codes;
create trigger promo_codes_set_updated_at
  before update on public.promo_codes
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 3. Ticket Orders (`public.ticket_orders`)
--    - Default status is `'pending'` (fulfilled only by server-side webhook).
--    - Never cascade-deleted when a profile is removed (`on delete set null`
--      plus snapshot columns).
-- -----------------------------------------------------------------------------
create table if not exists public.ticket_orders (
  id                          uuid primary key default gen_random_uuid(),
  order_number                text not null unique default public.next_order_number(),
  buyer_id                    uuid references public.profiles (id) on delete set null,
  buyer_display_name_snapshot text,
  buyer_email_snapshot        text,
  event_id                    uuid not null references public.events (id) on delete restrict,
  event_title_snapshot        text,
  promo_code_id               uuid references public.promo_codes (id) on delete set null,
  promo_code_text             text,
  subtotal_cents              integer not null default 0 check (subtotal_cents >= 0),
  service_fee_cents           integer not null default 0 check (service_fee_cents >= 0),
  discount_cents              integer not null default 0 check (discount_cents >= 0),
  total_cents                 integer not null default 0 check (total_cents >= 0),
  currency                    text not null default 'USD'
                              check (currency ~ '^[A-Z]{3}$'),
  payment_method              text not null default 'stripe'
                              check (payment_method in ('stripe', 'apple_pay', 'free')),
  stripe_payment_intent_id    text unique,
  status                      text not null default 'pending'
                              check (status in ('pending', 'paid', 'cancelled', 'refunded', 'expired')),
  stock_reserved              boolean not null default false,
  expires_at                  timestamptz not null default (now() + interval '30 minutes'),
  paid_at                     timestamptz,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);

create index if not exists idx_ticket_orders_buyer_cursor
  on public.ticket_orders (buyer_id, created_at desc, id desc);
create index if not exists idx_ticket_orders_event_cursor
  on public.ticket_orders (event_id, created_at desc, id desc);
create index if not exists idx_ticket_orders_promo_code_id
  on public.ticket_orders (promo_code_id);
create index if not exists idx_ticket_orders_pending_expiry
  on public.ticket_orders (expires_at asc)
  where status = 'pending';

drop trigger if exists ticket_orders_set_updated_at on public.ticket_orders;
create trigger ticket_orders_set_updated_at
  before update on public.ticket_orders
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 4. Ticket Order Items (`public.ticket_order_items`)
-- -----------------------------------------------------------------------------
create table if not exists public.ticket_order_items (
  id               uuid primary key default gen_random_uuid(),
  order_id         uuid not null references public.ticket_orders (id) on delete restrict,
  tier_id          uuid not null references public.event_ticket_tiers (id) on delete restrict,
  tier_name        text not null,
  group_size       smallint not null default 1 check (group_size > 0),
  unit_price_cents integer not null check (unit_price_cents >= 0),
  quantity         integer not null check (quantity > 0),
  line_total_cents integer not null check (line_total_cents >= 0),
  created_at       timestamptz not null default now()
);

create index if not exists idx_ticket_order_items_order_id
  on public.ticket_order_items (order_id);
create index if not exists idx_ticket_order_items_tier_id
  on public.ticket_order_items (tier_id);

-- -----------------------------------------------------------------------------
-- 5. Digital QR Tickets (`public.tickets`)
--    - `ticket_code` is for human display only (`LIT-2026-00482`).
--    - `qr_payload` is random, 48-hex-char unguessable token encoded in QR.
--    - `admits_count` is enforced to match `event_ticket_tiers.group_size`.
-- -----------------------------------------------------------------------------
create table if not exists public.tickets (
  id                   uuid primary key default gen_random_uuid(),
  ticket_code          text not null unique default public.next_ticket_code(),
  order_id             uuid not null references public.ticket_orders (id) on delete restrict,
  order_item_id        uuid references public.ticket_order_items (id) on delete restrict,
  event_id             uuid not null references public.events (id) on delete restrict,
  tier_id              uuid not null references public.event_ticket_tiers (id) on delete restrict,
  owner_id             uuid references public.profiles (id) on delete set null,
  holder_name_snapshot text,
  event_title_snapshot text,
  tier_name            text not null,
  seat_or_table_label  text,
  admits_count         smallint not null default 1 check (admits_count > 0),
  qr_payload           text not null unique default encode(extensions.gen_random_bytes(24), 'hex'),
  status               text not null default 'valid'
                       check (status in ('valid', 'used', 'cancelled', 'transferred')),
  checked_in_at        timestamptz,
  checked_in_by        uuid references public.profiles (id) on delete set null,
  transferred_to_id    uuid references public.profiles (id) on delete set null,
  transferred_at       timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index if not exists idx_tickets_owner_cursor
  on public.tickets (owner_id, created_at desc, id desc);
create index if not exists idx_tickets_event_status_cursor
  on public.tickets (event_id, status, created_at desc, id desc);
create index if not exists idx_tickets_order_id
  on public.tickets (order_id);
create index if not exists idx_tickets_order_item_id
  on public.tickets (order_item_id);
create index if not exists idx_tickets_tier_id
  on public.tickets (tier_id);
create index if not exists idx_tickets_checked_in_by
  on public.tickets (checked_in_by);
create index if not exists idx_tickets_transferred_to_id
  on public.tickets (transferred_to_id);

drop trigger if exists tickets_set_updated_at on public.tickets;
create trigger tickets_set_updated_at
  before update on public.tickets
  for each row execute function public.set_updated_at();

-- Must-fix #12: Enforce that `tickets.admits_count` matches `event_ticket_tiers.group_size`
-- and `tickets.event_id` matches `event_ticket_tiers.event_id`.
create or replace function public.enforce_ticket_tier_consistency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tier_group_size smallint;
  v_tier_event_id uuid;
begin
  select t.group_size, t.event_id
    into v_tier_group_size, v_tier_event_id
    from public.event_ticket_tiers t
   where t.id = new.tier_id;

  if not found then
    raise exception 'Ticket tier % does not exist.', new.tier_id;
  end if;

  if new.event_id <> v_tier_event_id then
    raise exception 'Ticket event_id (%) does not match tier event_id (%).', new.event_id, v_tier_event_id;
  end if;

  if new.admits_count <> v_tier_group_size then
    raise exception 'Ticket admits_count (%) must equal tier group_size (%).', new.admits_count, v_tier_group_size;
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_ticket_tier_consistency() from public, anon, authenticated;

drop trigger if exists before_tickets_check_tier on public.tickets;
create trigger before_tickets_check_tier
  before insert or update of tier_id, event_id, admits_count on public.tickets
  for each row execute function public.enforce_ticket_tier_consistency();

-- -----------------------------------------------------------------------------
-- 6. Event Staff (`public.event_staff`) — Authorized Door Scanners
-- -----------------------------------------------------------------------------
create table if not exists public.event_staff (
  event_id   uuid not null references public.events (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  role       text not null default 'scanner'
             check (role in ('scanner', 'manager')),
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create index if not exists idx_event_staff_user_id
  on public.event_staff (user_id);

-- -----------------------------------------------------------------------------
-- 7. Stripe Webhook Idempotency Log (`public.stripe_webhook_events`)
-- -----------------------------------------------------------------------------
create table if not exists public.stripe_webhook_events (
  id           text primary key, -- Stripe event id, e.g. 'evt_1Q...'
  type         text not null,
  payload      jsonb not null default '{}'::jsonb,
  processed_at timestamptz not null default now()
);
