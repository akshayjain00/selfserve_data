-- Supplement (not a card): M1 retention for lifetime-NEW business users (first completed online PTL order in cohort month), customer_id keys
with b as (
  select o.customer_id, date_trunc('month', convert_timezone('UTC','Asia/Kolkata', o.created_at))::date m
  from prod_curated.partload_application.orders o
  where o.state = 3
    and o.customer_id in (select uuid from prod_curated.oms_public.customers where frequency in (1,2,3,4))
    and o.customer_id not in (select customer_uuid from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null)
), f as (select customer_id, min(m) fm from b group by 1)
select f.fm cohort, count(distinct f.customer_id) n, count(distinct iff(b.m = dateadd(month,1,f.fm), b.customer_id, null)) r, round(r/n,4) pct
from f join b using (customer_id) where f.fm in ('2026-07-01','2026-08-01') group by 1 order by 1;
