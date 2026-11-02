select 

CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
COUNT(DISTINCT external_id) as placed_orders,
COUNT(DISTINCT CASE WHEN state = 4 THEN external_id ELSE NULL END) as cancelled_orders,
cancelled_orders / NULLIF(placed_orders, 0) AS cancellation_perc

from PROD_CURATED.PARTLOAD_APPLICATION.orders 
left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS on PTL_INTERNAL_USERS.mobile= orders.customer_mobile
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id=orders.route_id and ptl_routes.is_active = 'True'

where 1=1
and date(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) >= {{start_date}}
and date(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) <= {{end_date}} 
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
[[and 
  case 
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True'
end = {{is_test}}]]



[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
group by 1
order by dated desc
