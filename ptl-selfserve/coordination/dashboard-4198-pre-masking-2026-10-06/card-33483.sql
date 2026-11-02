with online as
(
select 
CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
count(distinct orders.external_id) as total_orders
from PROD_CURATED.PARTLOAD_APPLICATION.orders 
-- left join gsheet_sync.ptl_table 
-- on orders.id=ptl_table.order_id
left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
on PTL_INTERNAL_USERS.mobile= orders.customer_mobile
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = orders.route_id 
and is_active = 'True'
where orders.created_at >= {{start_date}} - interval '330 mins' 
and orders.created_at <= {{end_date}} - interval '330 mins' + interval '1 day'
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
order by dated asc
)

,offline as
(
select 
CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
count(distinct external_id) as total_orders
from prod_curated.gsheet_sync.ptl_offline_orders
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = ptl_offline_orders.route_id 
and is_active = 'True'
where created_at::date >= {{start_date}} 
and created_at::date <= {{end_date}} 
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
group by 1
order by dated asc
)

,FINAL AS
(
SELECT *
FROM online

UNION ALL

SELECT *
FROM offline
)

select dated,
sum(total_orders) AS total_orders
from FINAL
group by 1
order by dated asc