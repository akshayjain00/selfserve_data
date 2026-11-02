with online as
(
select 
CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
external_id,
WEIGHT
from PROD_CURATED.PARTLOAD_APPLICATION.orders
left join prod_curated.partload_application.load_details 
on orders.id=load_details.order_id and IS_ACTIVE = true
left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
on PTL_INTERNAL_USERS.mobile=orders.customer_mobile
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'

where CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at)) >=  {{start_date}}
and CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))  <= {{end_Date}} + interval '1 day'
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
[[and 
  case 
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True'
end = {{is_test}}]]

[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)

,offline as
(
select 
CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
external_id,
WEIGHT
from prod_curated.gsheet_sync.ptl_offline_orders
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
where created_at::date >=  {{start_date}}
and created_at::date  <= {{end_Date}}
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
)

,final AS
(
SELECT *
FROM online

UNION ALL

SELECT *
FROM offline
)

,raw as
(
select
dated,
WEIGHT, 
count(distinct external_id) as orders
from final
group by 1,2
)


,dist AS
(
SELECT 
  dated,
    CASE 
    WHEN weight <= 250000 THEN '0–250'
    WHEN weight <= 500000 THEN '251–500'
    WHEN weight <= 1000000 THEN '501–1000'
    WHEN weight <= 2000000 THEN '1001–2000'
    WHEN weight <= 3000000 THEN '2001–3000'
    ELSE '>3000'
  END AS weight_bucket,
  orders / SUM(orders) OVER (PARTITION BY dated) AS order_distribution_perc
FROM raw
order by 1 desc, order_distribution_perc desc
)


select 
dated, 
weight_bucket,
sum(order_distribution_perc) as order_distribution_perc
from dist
group by 1,2
order by 1 asc, 3 desc

