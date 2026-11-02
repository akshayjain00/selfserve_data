with online as
(
select 
CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
BATCHED_ORDERS_V1.ORDER_EXTERNAL_ID,
batch_id
from PROD_CURATED.PARTLOAD_APPLICATION.BATCHED_ORDERS_V1
left join PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES
on BATCHED_ORDERS_V1.ORDER_EXTERNAL_ID=ORDER_VEHICLES.ORDER_EXTERNAL_ID
left join PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
on BATCHED_ORDERS_V1.ORDER_EXTERNAL_ID=ORDERS.external_id
left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
on PTL_INTERNAL_USERS.mobile= ORDERS.customer_mobile
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
where status=3
and orders.created_at >=  {{start_date}} - INTERVAL '330 MINS'
and orders.created_at <= {{end_date}} - INTERVAL '330 MINS' + interval '1 day'
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
[[and 
  case 
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True'
end = {{is_test}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
ORDER BY DATED
)

,offline as
(
select 
CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
ORDER_EXTERNAL_ID,
batch_id
from prod_curated.gsheet_sync.ptl_offline_orders
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
where created_at::date >=  {{start_date}} 
and created_at::date <= {{end_date}} 
and TRIP_LEVEL_CONSIDERATION='yes'
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
ORDER BY DATED
)

,final AS
(
SELECT *
FROM online

UNION 

SELECT *
FROM offline
)


select
dated,
count(distinct ORDER_EXTERNAL_ID)/NULLIF(COUNT(DISTINCT batch_id), 0) as avg_order_per_trip
from final
group by 1
ORDER BY DATED