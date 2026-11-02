-- Derived from card 34090 "Trip Per Vendor" (dashboard 4198 Supply tab) online CTE. 2026-10-09.
-- No card on 4198 reports Monthly Active Vehicles / trips per MAV / new vehicles directly; 34090 groups by vendor_name,
-- and vendor_name (gsheet_sync."ptl_vendor_details" joined on reg no) is NULL for ~99% of trips (Aug: 4,116 of 4,151 batches),
-- so owner-level metrics are not computable. This keeps 34090's trip definition and swaps the grouping to vehicle:
--   trip = distinct BATCHED_ORDERS_V1.batch_id with status=3, orders.state=3, ORDER_VEHICLES.is_active=TRUE
--   vehicle = normalised ORDER_VEHICLES.VEHICLE_REGISTRATION_NUMBER (upper, no spaces/hyphens)
--   month = IST month of orders.created_at (as in the card)
-- Rewrites: internal-user exclusion via orders.customer_id NOT IN ptl_internal_users.customer_uuid (PII masking);
--   contact_details/load_details/material_type/routes/vendor joins dropped (unused with no city/segment filter).
--   Offline orders CTE omitted (ptl_offline_orders has no Aug/Sep 2026 rows).
-- new_vehicles = vehicles whose first-ever qualifying trip (since 2025-01-01) falls in that month.
-- m1_vehicle_retention (Aug) = share of Aug-active vehicles also active in Sep. Proxy only; NOT owner retention.
with t as (
  select distinct
    cast(date_trunc('month', convert_timezone('UTC','Asia/Kolkata', to_timestamp(o.created_at))) as date) dated,
    replace(replace(upper(v.vehicle_registration_number),' ',''),'-','') veh,
    b.batch_id
  from prod_curated.partload_application.orders o
  join prod_curated.partload_application.order_vehicles v on o.external_id = v.order_external_id and v.is_active = true
  join prod_curated.partload_application.batched_orders_v1 b on b.order_external_id = o.external_id and b.status = 3
  where o.state = 3
    and o.created_at >= '2025-01-01'::timestamp - interval '330 mins'
    and o.created_at <= '2026-09-30'::timestamp - interval '330 mins' + interval '1 day'
    and o.customer_id not in (select customer_uuid from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null)
), firsts as (select veh, min(dated) first_month from t group by 1)
, m as (
  select dated, count(distinct veh) mav, count(distinct batch_id) trips, count(distinct batch_id)/count(distinct veh) trips_per_mav
  from t where dated >= '2026-08-01' group by 1
)
select m.*,
  (select count(*) from firsts f where f.first_month = m.dated) new_vehicles,
  case when m.dated = '2026-08-01' then
    (select count(distinct a.veh) from t a join t s on a.veh = s.veh and s.dated = '2026-09-01' where a.dated = '2026-08-01') / m.mav end m1_vehicle_retention
from m order by 1;
