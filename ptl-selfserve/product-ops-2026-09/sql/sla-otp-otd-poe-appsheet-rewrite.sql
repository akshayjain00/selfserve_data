-- REWRITE of cards 33784/33823 (OTP), 33785/33824 (OTD), 34052/34364 (Perfect Order = OTP AND OTD)
-- Why: all six cards read pickup/drop timestamps from gsheet_sync.ptl_table, which has no rows for any
--      order created after 2026-01-29 (max joined orders.id = 33,620). The cards therefore return 0% / no rows
--      for Aug-Sep 2026.
-- Rewrite: timestamp source swapped to PROD_CURATED.PARTLOAD_ANALYTICS.PTL_APP_SHEET_BACKFILLED_DATA
--   (AppSheet backup; IST-naive), deduped to one row per ORDER_ID (MAX of each column; table has dup ORDER_IDs).
--   PICKUP_REACHED_TIMESTAMP -> REACHED_PICKUP_AT ; drop_start_timestamp -> REACHED_DROP_AT.
--   Card flag logic kept verbatim:
--     OTP: reached_pickup <= pickup_slot_end (UTC-naive) + 330 min
--     OTD: reached_drop  <= DATE_TRUNC('day', pickup_slot_start IST) + 36h
--   Internal users: mobile join replaced by customer_id NOT IN ptl_internal_users.customer_uuid (PII masking).
--   Offline orders CTE (gsheet_sync.ptl_offline_orders) contributes 0 rows for Aug/Sep (verified: card totals = online only).
--   Period = Month, dated = DATE_TRUNC(month, IST(created_at)); state = 3; 2026-08-01..2026-09-30 IST.
with a as (
  select order_id, max(reached_pickup_at) reached_pickup_at, max(reached_drop_at) reached_drop_at
  from prod_curated.partload_analytics.ptl_app_sheet_backfilled_data group by 1
), o as (
  select o.id,
    cast(date_trunc('month', convert_timezone('UTC','Asia/Kolkata', to_timestamp(o.created_at))) as date) dated,
    a.reached_pickup_at, a.reached_drop_at,
    case when a.reached_pickup_at <= o.pickup_slot_end + interval '330 minutes' then 1 end otp,
    case when timestampdiff(hour, date_trunc('day', convert_timezone('UTC','Asia/Kolkata', to_timestamp(o.pickup_slot_start))) + interval '36 hour', a.reached_drop_at) <= 0 then 1 end otd
  from prod_curated.partload_application.orders o
  left join a on a.order_id = o.id
  where o.state = 3
    and o.created_at >= '2026-08-01'::timestamp - interval '330 mins'
    and o.created_at <= '2026-09-30'::timestamp - interval '330 mins' + interval '1 day'
    and o.customer_id not in (select customer_uuid from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null)
)
select dated,
  count(*) total_orders,
  count(reached_pickup_at) with_pickup_ts, count(reached_drop_at) with_drop_ts,
  count(case when reached_pickup_at is not null and reached_drop_at is not null then 1 end) with_both_ts,
  count(otp) otp_n, count(otd) otd_n, count(case when otp=1 and otd=1 then 1 end) poe_n,
  count(otp)/count(*) otp_pct_card_denominator,
  count(otd)/count(*) otd_pct_card_denominator,
  count(case when otp=1 and otd=1 then 1 end)/count(*) poe_pct_card_denominator,
  count(otp)/nullif(count(reached_pickup_at),0) otp_pct_of_tracked,
  count(otd)/nullif(count(reached_drop_at),0) otd_pct_of_tracked,
  count(case when otp=1 and otd=1 then 1 end)/nullif(count(case when reached_pickup_at is not null and reached_drop_at is not null then 1 end),0) poe_pct_of_tracked
from o group by 1 order by 1;
