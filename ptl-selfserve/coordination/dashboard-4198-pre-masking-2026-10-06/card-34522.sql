WITH online as (
SELECT 
	o.id,
	date(o.created_at) as dt,
	timestampdiff(minute,PICKUP_REACHED_TIMESTAMP::timestamp,PICKUP_COMPLETED_TIMESTAMP::timestamp) as order_pickup_time_taken,
	timestampdiff(minute,loading_start_time::timestamp,loading_end_time::timestamp) as load_time,
	timestampdiff(minute,un_loading_start_time::timestamp,un_loading_end_time::timestamp) as unload_time,
	timestampdiff(minute,DROP_START_TIMESTAMP::timestamp,DROP_END_TIMESTAMP::timestamp) as order_drop_time_taken
FROM partload_application.orders o 
LEFT JOIN gsheet_sync.ptl_table ptl 
    ON o.id = ptl.order_id
LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS iu
    ON iu.mobile = o.customer_mobile
LEFT JOIN prod_curated.partload_analytics.ptl_routes
    ON ptl_routes.route_id = o.route_id and ptl_routes.is_active = 'True'
WHERE o.state = 3
  AND o.created_at >= {{start_date}} - INTERVAL '330 MINS'
  and o.created_at <= {{end_date}} - INTERVAL '330 MINS' + interval '1 day'
  [[AND CASE WHEN iu.mobile IS NULL THEN 'False' ELSE 'True' END = {{is_test}}]]
  [[AND {{pickup_city}}]]
  [[AND {{drop_city}}]]


[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)

,offline as
(
SELECT 
	to_variant(id) as id,
	date(created_at) as dt,
	timestampdiff(minute,PICKUP_REACHED_TIMESTAMP,PICKUP_COMPLETED_TIMESTAMP) as order_pickup_time_taken,
	timestampdiff(minute,loading_start_time,loading_end_time) as load_time,
	timestampdiff(minute,un_loading_start_time,un_loading_end_time) as unload_time,
	timestampdiff(minute,DROP_START_TIMESTAMP,DROP_END_TIMESTAMP) as order_drop_time_taken
FROM prod_curated.gsheet_sync.ptl_offline_orders
LEFT JOIN prod_curated.partload_analytics.ptl_routes
    ON ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
WHERE state = 3
  AND DATE(created_at) >= {{start_date}} 
  and DATE(created_at) <= {{end_date}}
  [[AND {{pickup_city}}]]
  [[AND {{drop_city}}]]
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
	DATE_TRUNC({{period}}, dt) as dated,
	avg(load_time) as Avg_loading_time,
	avg(unload_time) as Avg_unloading_time,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY load_time) AS p50_load_time,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY unload_time) AS p50_unload_time,
	PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY load_time) AS p90_load_time,
	PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY unload_time) AS p90_unload_time
from final
group by 1
order by 1;