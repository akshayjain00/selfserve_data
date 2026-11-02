with excl as (
  select customer_uuid as customer_id from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null
  union select '550e8400-e29b-41d4-a716-446655440000'
  union select 'da9acad5-3a9d-4e99-ac66-bb9c6d57ad32'
)
select listagg(to_char(d,'YYYYMMDD')||','||placed||','||completed||','||est_rev, ';') within group (order by d) as s
from (
  select date(o.created_at + interval '330 minutes') as d, count(*) as placed,
         count(case when o.state=3 then 1 end) as completed,
         round(sum(case when o.state=3 then o.estimated_fare else 0 end)/100) as est_rev
  from prod_curated.partload_application.orders o
  where date(o.created_at + interval '330 minutes') between '2026-10-12' and '2026-10-31' and o.customer_id not in (select customer_id from excl)
  group by 1)