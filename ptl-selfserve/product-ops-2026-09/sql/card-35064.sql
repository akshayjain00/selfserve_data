-- Card 35064 "IPO" (support-button sessions per placed order), dashboard 4198 Support tab. Extracted + rewritten 2026-10-09.
-- Card returned ZERO rows: source partload_analytics.ptl_frontend_events has no events after 2026-01-19.
-- Rewrites:
--  1. Source ptl_frontend_events -> PROD_CURATED.PARTLOAD_ANALYTICS.PTL_FE_EVENTS (live), same event
--     'ptlorderdetailsscreen_support_bn_clicked'; a_app_session_id -> APP_SESSION_ID;
--     EVENT_TIMESTAMP_IST -> CONVERT_TIMEZONE('Asia/Kolkata', EVENT_TIMESTAMP)::TIMESTAMP_NTZ (column is LTZ).
--  2. Internal-user exclusion: a_user_id NOT IN internal mobiles (masked) -> CUSTOMER_ID (numeric OMS id) NOT IN
--     oms_public.customers.id whose uuid is in ptl_internal_users.customer_uuid.
--  3. placed_orders is_test='False': mobile join -> orders.customer_id NOT IN ptl_internal_users.customer_uuid.
--  4. Unused orders/routes joins in the event CTE dropped (only used for city / segment filters, which are unset).
--  Params: start_date=2026-08-01, end_date=2026-09-30, period=Month, is_test=False.
with internal_oms as (
  select id::varchar id from prod_curated.oms_public.customers
  where uuid in (select customer_uuid from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null)
), base as (
  select convert_timezone('Asia/Kolkata', event_timestamp)::timestamp_ntz event_ts, app_session_id
  from prod_curated.partload_analytics.ptl_fe_events
  where event_name = 'ptlorderdetailsscreen_support_bn_clicked'
    and coalesce(customer_id,'') not in (select id from internal_oms)
    and convert_timezone('Asia/Kolkata', event_timestamp)::timestamp_ntz >= '2026-08-01'
    and convert_timezone('Asia/Kolkata', event_timestamp)::timestamp_ntz <= '2026-09-30'::timestamp + interval '1 day'
), incidents as (
  select cast(date_trunc('month', event_ts) as date) dated, count(distinct app_session_id) incidents from base group by 1
), placed_orders as (
  select cast(date_trunc('month', convert_timezone('UTC','Asia/Kolkata', to_timestamp(o.created_at))) as date) dated,
         count(distinct o.external_id) placed_orders
  from prod_curated.partload_application.orders o
  where o.created_at::timestamp >= '2026-08-01'::timestamp - interval '330 mins'
    and o.created_at::timestamp <= '2026-09-30'::timestamp - interval '330 mins' + interval '1 day'
    and o.customer_id not in (select customer_uuid from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null)
  group by 1
)
select incidents.dated, incidents, placed_orders, incidents/placed_orders as ipo
from incidents left join placed_orders on incidents.dated = placed_orders.dated
order by 1;
