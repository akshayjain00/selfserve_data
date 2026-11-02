with excl as (
  select customer_uuid as customer_id from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null
  union select '550e8400-e29b-41d4-a716-446655440000'
  union select 'da9acad5-3a9d-4e99-ac66-bb9c6d57ad32'
),
lbo as (
  select * from prod_curated.partload_application.batched_orders_v1
  qualify row_number() over (partition by order_id order by updated_at desc) = 1
),
ow as (
  select o.id as order_id, o.route_id, date(o.pickup_slot_start + interval '330 minutes') as pickup_date,
         round(coalesce(
           max(case when ld.entry_type = 'OPS_DECLARED' and ld.is_active = true then ld.chargeable_weight end),
           max(case when ld.entry_type = 'CUSTOMER_DECLARED' then ld.chargeable_weight end)
         )/1000,0) as actual_weight
  from prod_curated.partload_application.orders o
  left join prod_curated.partload_application.load_details ld on ld.order_id = o.id
  where o.state = 3 and o.customer_id not in (select customer_id from excl)
  group by 1,2,3
),
bwt as (
  select lbo.batch_id, max(ow.pickup_date) as pickup_date, sum(ow.actual_weight) as weight
  from lbo join ow on ow.order_id = lbo.order_id
  where lbo.status = 3
  group by 1
),
rc as (select lbo.batch_id, ow.route_id, count(*) as n from lbo join ow on ow.order_id = lbo.order_id where lbo.status = 3 group by 1,2),
br as (select batch_id, route_id from rc qualify row_number() over (partition by batch_id order by n desc) = 1),
bc as (
  select j.batch_id, max(vc.weight_capacity) as capacity
  from prod_curated.partload_application.jobs j
  join prod_curated.partload_application.vehicles v on j.vehicle_id = v.id
  join prod_curated.partload_application.vehicle_categories vc on vc.id = v.vehicle_categories_id
  where j.job_status = 6
  group by 1
)
select listagg(to_char(d,'YYYYMMDD')||','||w||','||cap, ';') within group (order by d) as s
from (
  select bwt.pickup_date as d, sum(bwt.weight) as w, sum(bc.capacity) as cap
  from bwt
  join prod_curated.partload_application.batch_v1 b on b.id = bwt.batch_id and b.status = 2
  join bc on bc.batch_id = bwt.batch_id
  where bwt.pickup_date between '2026-10-12' and '2026-10-31'
  group by 1)