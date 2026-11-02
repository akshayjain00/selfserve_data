with excl as (
  select customer_uuid as customer_id from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null
  union select '550e8400-e29b-41d4-a716-446655440000'
  union select 'da9acad5-3a9d-4e99-ac66-bb9c6d57ad32'
),
-- Metabase card 44691 (Return Trips): a batch is a return trip when the same vehicle's previous batch started from
-- the city this batch drops in. Orders window starts 2026-03-01 so the vehicle sequence has a warm-up.
final_return as (
  select o.id, o.external_id as order_id, o.route_id, r.route_name, r.drop_city as drop_city_o,
         ov.vehicle_registration_number, bo.batch_id, bo.created_at + interval '330 mins' as batch_created_at
  from prod_curated.partload_application.orders o
  left join prod_curated.partload_analytics.ptl_routes r on r.route_id = o.route_id and r.is_active = 'True'
  left join (select * from prod_curated.partload_application.batched_orders_v1
             qualify row_number() over (partition by order_id order by updated_at desc) = 1) bo on bo.order_id = o.id
  left join prod_curated.partload_application.order_vehicles ov on o.external_id = ov.order_external_id and ov.is_active = true
  where o.state = 3 and bo.batch_id is not null and o.created_at >= '2026-03-01'
    and o.customer_id not in (select customer_id from excl)
),
return_route_id as (
  select a.route_id as fwd_route_id
  from prod_curated.partload_analytics.ptl_routes a
  left join prod_curated.partload_analytics.ptl_routes b
    on a.route_name = split_part(b.route_name, ' - ', 2) || ' - ' || split_part(b.route_name, ' - ', 1)
  where a.is_active = 'True' and b.is_active = 'True'
),
orders_enriched as (
  select f.order_id, f.batch_id, f.vehicle_registration_number, f.route_id, f.drop_city_o as drop_city,
         f.batch_created_at as created_at, pvz.service_zone_name as vehicle_city
  from final_return f
  left join return_route_id r on r.fwd_route_id = f.route_id
  left join prod_curated.partload_application.vehicles v on v.registration_number = f.vehicle_registration_number
  left join prod_curated.partload_application.service_zones pvz on pvz.id = v.service_zone_id and service_zone_type = 'PICKUP'
),
batch_routes as (
  select distinct vehicle_registration_number, batch_id, route_id, drop_city, vehicle_city, created_at from orders_enriched
),
batch_header as (
  select vehicle_registration_number, batch_id, min(created_at) as batch_created_at from batch_routes group by 1, 2
),
sequenced_batches as (
  select vehicle_registration_number, batch_id, batch_created_at,
         lag(batch_id) over (partition by vehicle_registration_number order by batch_created_at, batch_id) as prev_batch_id
  from batch_header
),
matched_return_routes as (
  select distinct curr.vehicle_registration_number, curr.batch_id as return_batch_id, curr.route_id as return_route_id,
         sb.prev_batch_id as fwd_batch_id
  from sequenced_batches sb
  join batch_routes curr on curr.vehicle_registration_number = sb.vehicle_registration_number and curr.batch_id = sb.batch_id
  join batch_routes prev on prev.vehicle_registration_number = curr.vehicle_registration_number
    and prev.batch_id = sb.prev_batch_id and prev.batch_id <> curr.batch_id
    and prev.vehicle_city = curr.drop_city and prev.created_at < curr.created_at
  where sb.prev_batch_id is not null
),
final_ctee as (
  select curr.order_id, curr.batch_id, curr.created_at,
         case when max(case when m.fwd_batch_id is not null then 1 else 0 end) over (partition by curr.batch_id) = 1 then 'Yes' else 'No' end as batch_is_return_trip
  from orders_enriched curr
  left join matched_return_routes m on curr.vehicle_registration_number = m.vehicle_registration_number
    and curr.batch_id = m.return_batch_id and curr.route_id = m.return_route_id
),
dedup_batches as (
  select * from final_ctee qualify row_number() over (partition by order_id order by created_at desc) = 1
),
tot as (
  select date(created_at) as d, count(distinct batch_id) as total from orders_enriched
  where date(created_at) between '2026-10-12' and '2026-10-31' group by 1
),
ret as (
  select date(created_at) as d, count(distinct batch_id) as ret from dedup_batches
  where batch_is_return_trip = 'Yes' and date(created_at) between '2026-10-12' and '2026-10-31' group by 1
)
select listagg(to_char(t.d,'YYYYMMDD')||','||t.total||','||coalesce(r.ret,0), ';') within group (order by t.d) as s
from tot t left join ret r on r.d = t.d