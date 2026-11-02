with excl as (
  select customer_uuid as customer_id from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null
  union select '550e8400-e29b-41d4-a716-446655440000'
  union select 'da9acad5-3a9d-4e99-ac66-bb9c6d57ad32'
)
select listagg(label||','||net||','||gross, ';') within group (order by net desc, label) as s
from (
  select r.route_label as label, round(sum(f.total_fare)/100) as net,
         round(sum(f.total_fare + f.discount_amount_minor_units)/100) as gross
  from prod_curated.partload_application.orders o
  join prod_curated.partload_application.routes r on r.id = o.route_id
  join prod_curated.partload_application.order_fares f on f.order_id = o.id and f.is_current_fare = TRUE
  where o.state = 3 and date(o.updated_at + interval '330 minutes') between '2026-10-25' and '2026-10-31' and o.customer_id not in (select customer_id from excl)
  group by 1)