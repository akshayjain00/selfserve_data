with excl as (
  select customer_uuid as customer_id from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null
  union select '550e8400-e29b-41d4-a716-446655440000'
  union select 'da9acad5-3a9d-4e99-ac66-bb9c6d57ad32'
),
top as (
  select r.route_label as label
  from prod_curated.partload_application.orders o join prod_curated.partload_application.routes r on r.id = o.route_id
  where o.state = 3 and date(o.created_at + interval '330 minutes') between '2026-10-25' and '2026-10-31' and o.customer_id not in (select customer_id from excl)
  group by 1 order by count(*) desc, 1 limit 12
),
wk as (
  select r.route_label as label,
         dateadd(day, -(dayofweekiso(date(o.created_at + interval '330 minutes')) - 1), date(o.created_at + interval '330 minutes')) as wk,
         count(*) as placed, count(case when o.state=3 then 1 end) as completed
  from prod_curated.partload_application.orders o join prod_curated.partload_application.routes r on r.id = o.route_id
  where r.route_label in (select label from top)
    and date(o.created_at + interval '330 minutes') between '2026-07-27' and '2026-10-25' and o.customer_id not in (select customer_id from excl)
  group by 1,2
)
select listagg(label||'|'||s, ';') within group (order by label) as s
from (select label, listagg(to_char(wk,'YYYYMMDD')||':'||placed||':'||completed, ',') within group (order by wk) as s from wk group by label)