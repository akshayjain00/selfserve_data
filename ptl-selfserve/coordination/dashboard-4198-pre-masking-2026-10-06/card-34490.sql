WITH online as (
SELECT 
	orders.id,
    CAST(DATE_TRUNC({{period}}, 
	CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
	DATE_TRUNC('day',CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.PICKUP_SLOT_START))) + interval '36 hour' as delivery_time,
	COALESCE(
    TRY_TO_TIMESTAMP(drop_start_timestamp, 'YYYY-MM-DD HH24:MI:SS'),
    TRY_TO_TIMESTAMP(drop_start_timestamp, 'DD/MM/YYYY HH12:MIam')
  )::timestamp as dts,
	TIMESTAMPDIFF(hour,delivery_time,dts) AS delayed_by,
	case
		when delayed_by is null then 'Time not Entered'
		when delayed_by > 0 and delayed_by <= 1 then '<=1 hr'
		when delayed_by > 1 and delayed_by <= 2 then '1-2 hr'
		when delayed_by >2 and delayed_by <= 5 then '2-5 hr'
		when delayed_by > 5 then '>= 5 hr'
	end as delay_bucket
FROM partload_application.orders 
LEFT JOIN gsheet_sync.ptl_table ptl 
    ON orders.id = ptl.order_id
LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS iu
    ON iu.mobile = orders.customer_mobile
LEFT JOIN prod_curated.partload_analytics.ptl_routes
    ON ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
WHERE orders.state = 3
  AND DATE(orders.created_at)>= {{start_date}} - INTERVAL '330 MINS'
  AND DATE(orders.created_at)<= {{end_date}} - INTERVAL '330 MINS' + interval '1 day'
  [[AND CASE WHEN iu.mobile IS NULL THEN 'False' ELSE 'True' END = {{is_test}}]]
  [[AND {{pickup_city}}]]
  [[AND {{drop_city}}]]
  AND (delayed_by > 0 or dts is null)


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)


,offline as
(
SELECT 
	to_variant(id) as id,
    CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
	DATE_TRUNC('day', TO_TIMESTAMP(TO_CHAR(CAST(PICKUP_REACHED_TIMESTAMP AS TIMESTAMP), 'YYYY-MM-DD') || ' ' || PICKUP_SLOT_START, 'YYYY-MM-DD HH24:MI')) 
    + INTERVAL '36 hour' as delivery_time,
	drop_start_timestamp::timestamp as dts,
	TIMESTAMPDIFF(hour,delivery_time,dts) AS delayed_by,
	case
		when delayed_by is null then 'Time not Entered'
		when delayed_by > 0 and delayed_by <= 1 then '<=1 hr'
		when delayed_by > 1 and delayed_by <= 2 then '1-2 hr'
		when delayed_by >2 and delayed_by <= 5 then '2-5 hr'
		when delayed_by > 5 then '>= 5 hr'
	end as delay_bucket
FROM prod_curated.gsheet_sync.ptl_offline_orders
LEFT JOIN prod_curated.partload_analytics.ptl_routes
    ON ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
WHERE state = 3
  AND dated >= {{start_date}}
  and dated <= {{end_date}} 
  [[AND {{pickup_city}}]]
  [[AND {{drop_city}}]]
  AND (delayed_by > 0 or dts is null)
)

,final AS
(
SELECT *
FROM online

UNION ALL

SELECT *
FROM offline
)


select delay_bucket,
count(id) 
from final
group by 1
order by 1;