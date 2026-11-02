-- Derived from card 34284 "WD Share in Revenue Trend" (dashboard 4198 Finance tab). 2026-10-09.
-- No 4198 card reports weight-discrepancy ORDER %; 34284 reports WD share of revenue. This reuses 34284's new_online CTE
-- verbatim for the WD flag (wd_marked = order has any order_fares row with is_current_fare = 'FALSE', i.e. fare was revised)
-- and counts orders instead of summing fares.
-- Rewrites: internal-user exclusion customer_mobile NOT IN ptl_internal_users.mobile -> customer_id NOT IN customer_uuid (PII masking).
--   old_online (gsheet ptl_table) and offline CTEs contribute nothing for Aug/Sep 2026 and are omitted.
-- Params: 2026-08-01..2026-09-30 IST, Month, state=3.
with new_online as (
  select cast(date_trunc('month', convert_timezone('UTC','Asia/Kolkata', to_timestamp(o.created_at))) as date) dated,
         o.external_id,
         max(case when is_current_fare = 'FALSE' then 'TRUE' end) wd_marked,
         max(case when is_current_fare = 'TRUE' then total_fare end)/100 actual_fare,
         max(case when fare_reason_code = 'INITIAL_BOOKING' then total_fare end)/100 estimated_fare
  from prod_curated.partload_application.load_details
  left join prod_curated.partload_application.orders o on load_details.order_id = o.id
  left join prod_curated.partload_application.order_fares on order_fares.order_id = load_details.order_id
  left join prod_curated.partload_application.fare_revision_notified on fare_revision_notified.order_fare_id = order_fares.id
  where o.state = 3
    and o.customer_id not in (select customer_uuid from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null)
    and o.created_at >= '2026-08-01'::timestamp - interval '330 mins'
    and o.created_at <= '2026-09-30'::timestamp - interval '330 mins' + interval '1 day'
  group by 1,2
)
select dated, count(distinct external_id) completed_orders,
  count(distinct case when wd_marked = 'TRUE' then external_id end) wd_orders,
  count(distinct case when wd_marked = 'TRUE' then external_id end)/count(distinct external_id) wd_order_pct,
  sum(actual_fare - estimated_fare) revenue_from_wd,
  sum(case when wd_marked = 'TRUE' then actual_fare else estimated_fare end) total_fare
from new_online group by 1 order by 1;
