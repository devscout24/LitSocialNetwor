-- =============================================================================
-- LIT Social — Migration 20261124000008: Scheduled Maintenance & pg_cron Jobs
-- Target: Self-hosted Supabase (PostgreSQL 15+)
-- Jobs:
--   1. Hourly (`0 * * * *`): recompute `hashtags.is_trending` based on post
--      usage in the last 72 hours (not all-time).
--   2. Daily (`0 3 * * *`): delete `story_views` and clear storage references
--      for stories expired more than 30 days ago.
--   3. Every 15 min (`*/15 * * * *`): expire `pending` ticket orders older than
--      30 minutes (`expires_at <= now()`) and release held tier stock.
--   4. Daily (`30 3 * * *`): mark past published events as `completed`.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Hourly: Recompute `hashtags.is_trending` from 72h Post Window
-- -----------------------------------------------------------------------------
create or replace function public.cron_recompute_trending_hashtags()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.hashtags
     set is_trending = false
   where is_trending = true;

  with recent_tags as (
    select ph.hashtag_id,
           count(*) as recent_uses
      from public.post_hashtags ph
      join public.posts p on p.id = ph.post_id
     where not p.is_hidden
       and not p.is_archived
       and ph.created_at >= (pg_catalog.now() - interval '72 hours')
     group by ph.hashtag_id
    having count(*) >= 1
     order by count(*) desc
     limit 15
  )
  update public.hashtags h
     set is_trending = true
    from recent_tags rt
   where h.id = rt.hashtag_id;
end;
$$;

revoke all on function public.cron_recompute_trending_hashtags() from public, anon, authenticated;
grant execute on function public.cron_recompute_trending_hashtags() to service_role;

-- -----------------------------------------------------------------------------
-- 2. Daily: Purge `story_views` and Storage Paths for Stories Expired > 30 Days
-- -----------------------------------------------------------------------------
create or replace function public.cron_cleanup_expired_stories()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Remove detailed view rows for stories expired more than 30 days ago
  delete from public.story_views sv
   using public.stories s
   where sv.story_id = s.id
     and s.expires_at < (pg_catalog.now() - interval '30 days');

  -- Delete underlying private `stories` storage objects and mark purged
  delete from storage.objects so
   using public.stories s
   where so.bucket_id = 'stories'
     and so.name = s.storage_path
     and s.expires_at < (pg_catalog.now() - interval '30 days');

  update public.stories
     set storage_path      = null,
         storage_purged_at = pg_catalog.now()
   where expires_at < (pg_catalog.now() - interval '30 days')
     and storage_purged_at is null;
end;
$$;

revoke all on function public.cron_cleanup_expired_stories() from public, anon, authenticated;
grant execute on function public.cron_cleanup_expired_stories() to service_role;

-- -----------------------------------------------------------------------------
-- 3. Every 15 Minutes: Expire Pending Ticket Orders Older Than 30 Minutes
--    and Release Held Tier Stock
-- -----------------------------------------------------------------------------
create or replace function public.cron_expire_pending_orders()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order record;
  v_item record;
begin
  for v_order in
    select o.id, o.stock_reserved
      from public.ticket_orders o
     where o.status = 'pending'
       and (
         o.expires_at <= pg_catalog.now()
         or o.created_at <= (pg_catalog.now() - interval '30 minutes')
       )
       for update skip locked
  loop
    if v_order.stock_reserved then
      for v_item in
        select oi.tier_id, oi.quantity
          from public.ticket_order_items oi
         where oi.order_id = v_order.id
         order by oi.tier_id
      loop
        update public.event_ticket_tiers
           set quantity_sold = greatest(0, quantity_sold - v_item.quantity)
         where id = v_item.tier_id;
      end loop;
    end if;

    update public.ticket_orders
       set status         = 'expired',
           stock_reserved = false
     where id = v_order.id;
  end loop;
end;
$$;

revoke all on function public.cron_expire_pending_orders() from public, anon, authenticated;
grant execute on function public.cron_expire_pending_orders() to service_role;

-- -----------------------------------------------------------------------------
-- 4. Daily: Mark Past Published Events as `completed`
-- -----------------------------------------------------------------------------
create or replace function public.cron_complete_past_events()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.events
     set status = 'completed'
   where status = 'published'
     and coalesce(ends_at, starts_at + interval '6 hours') < pg_catalog.now();
end;
$$;

revoke all on function public.cron_complete_past_events() from public, anon, authenticated;
grant execute on function public.cron_complete_past_events() to service_role;

-- -----------------------------------------------------------------------------
-- 5. Register `pg_cron` Schedules (Idempotent & Safe if `pg_cron` is Not Preloaded)
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from pg_available_extensions where name = 'pg_cron'
  ) then
    begin
      create extension if not exists pg_cron;

      -- Unschedule previous definitions if re-running migration
      if exists (select 1 from cron.job where jobname = 'lit_hourly_trending_hashtags') then
        perform cron.unschedule('lit_hourly_trending_hashtags');
      end if;
      if exists (select 1 from cron.job where jobname = 'lit_daily_cleanup_expired_stories') then
        perform cron.unschedule('lit_daily_cleanup_expired_stories');
      end if;
      if exists (select 1 from cron.job where jobname = 'lit_15m_expire_pending_orders') then
        perform cron.unschedule('lit_15m_expire_pending_orders');
      end if;
      if exists (select 1 from cron.job where jobname = 'lit_daily_complete_past_events') then
        perform cron.unschedule('lit_daily_complete_past_events');
      end if;

      perform cron.schedule(
        'lit_hourly_trending_hashtags',
        '0 * * * *',
        'select public.cron_recompute_trending_hashtags();'
      );
      perform cron.schedule(
        'lit_daily_cleanup_expired_stories',
        '0 3 * * *',
        'select public.cron_cleanup_expired_stories();'
      );
      perform cron.schedule(
        'lit_15m_expire_pending_orders',
        '*/15 * * * *',
        'select public.cron_expire_pending_orders();'
      );
      perform cron.schedule(
        'lit_daily_complete_past_events',
        '30 3 * * *',
        'select public.cron_complete_past_events();'
      );
    exception
      when others then
        raise notice 'pg_cron extension is available but could not be scheduled in this session (%). Maintenance functions are installed and ready.', sqlerrm;
    end;
  end if;
end
$$;
