with online as
(
select 
CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
state,
external_id
from PROD_CURATED.PARTLOAD_APPLICATION.orders 
left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
on PTL_INTERNAL_USERS.mobile=orders.customer_mobile
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
where orders.created_at >=  {{start_date}} - INTERVAL '330 MINS'
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
)

,offline as
(
select 
CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
state,
external_id
from prod_curated.gsheet_sync.ptl_offline_orders
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
where created_at::date >=  {{start_date}} 
and created_at::date <= {{end_date}} 
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

select 
dated,
COUNT(DISTINCT CASE WHEN state = 3 THEN external_id ELSE NULL END) 
    / NULLIF(COUNT(DISTINCT external_id), 0) AS fulfillment_perc
from 
final
GROUP BY 1
ORDER BY DATED;


