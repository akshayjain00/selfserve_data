with online as
(
select 
	CAST(DATE_TRUNC({{period}}, 
	CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at))) AS DATE) AS dated,
	PICKUP_REACHED_TIMESTAMP,
	pickup_slot_end,
	o.id
from partload_application.orders o 
join gsheet_sync.ptl_table ptl 
on o.id = ptl.order_id
left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS on PTL_INTERNAL_USERS.mobile= o.customer_mobile
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = o.route_id and ptl_routes.is_active = 'True'
where o.state = 3
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
[[and 
  case 
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True' end = {{is_test}}]]
and o.created_at >= {{start_date}} - INTERVAL '330 MINS'
and o.created_at <= {{end_date}} - INTERVAL '330 MINS'+ interval '1 day'


[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
order by 1
)

,offline as
(
select 
	CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
	PICKUP_REACHED_TIMESTAMP,
	TO_TIMESTAMP(TO_CHAR(CAST(PICKUP_REACHED_TIMESTAMP AS TIMESTAMP), 'YYYY-MM-DD') || ' ' || PICKUP_SLOT_START, 'YYYY-MM-DD HH24:MI') + INTERVAL '120 minutes' as pickup_slot_end,
	to_variant(id) as id 
from prod_curated.gsheet_sync.ptl_offline_orders
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
where state = 3
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
and created_at::date >= {{start_date}}
and created_at::date <= {{end_date}} 
order by 1
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
100*count(case when PICKUP_REACHED_TIMESTAMP::timestamp <= pickup_slot_end + interval '330 minutes' then 1 end)/ NULLIF(COUNT(id), 0) as on_time_pickup_perc
from 
final
group by 1
order by 1