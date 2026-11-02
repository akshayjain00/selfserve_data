with excl as (
  select customer_uuid as customer_id from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null
  union select '550e8400-e29b-41d4-a716-446655440000'
  union select 'da9acad5-3a9d-4e99-ac66-bb9c6d57ad32'
),
lbo as (
  select bo.order_id, bo.batch_id, bo.status from prod_curated.partload_application.batched_orders_v1 bo
  qualify row_number() over (partition by bo.order_id order by bo.updated_at desc) = 1
),
bo as (
  select lbo.batch_id, o.id as order_id, o.route_id,
         date(min(o.created_at + interval '330 minutes') over (partition by lbo.batch_id)) as batch_day
  from lbo join prod_curated.partload_application.orders o on o.id = lbo.order_id
  where lbo.status = 3 and o.state = 3 and o.customer_id not in (select customer_id from excl)
),
rc as (select batch_id, route_id, count(*) n from bo group by 1,2),
br as (select batch_id, route_id from rc qualify row_number() over (partition by batch_id order by n desc) = 1),
bs as (
  select bo.batch_id, bo.batch_day, br.route_id, count(distinct bo.order_id) as n_orders
  from bo join br on br.batch_id = bo.batch_id group by 1,2,3
)
select listagg(label||','||n||','||t, ';') within group (order by n desc, label) as s
from (select r.route_label as label, sum(bs.n_orders) as n, count(*) as t
      from bs join prod_curated.partload_application.routes r on r.id = bs.route_id
      where bs.batch_day between '2026-10-25' and '2026-10-31' group by 1)