WITH online as (
SELECT 
	orders.id,
    CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
	CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.PICKUP_SLOT_START)) as pickup_start,
	COALESCE(

    TRY_TO_TIMESTAMP(PICKUP_REACHED_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'),

    TRY_TO_TIMESTAMP(PICKUP_REACHED_TIMESTAMP, 'DD/MM/YYYY HH12:MIam')

    ) as pickup_reached,
	DATE_TRUNC('day',CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.PICKUP_SLOT_START))) + interval '36 hour' as delivery_time,
	COALESCE(

    TRY_TO_TIMESTAMP(drop_start_timestamp, 'YYYY-MM-DD HH24:MI:SS'),

    TRY_TO_TIMESTAMP(drop_start_timestamp, 'DD/MM/YYYY HH12:MIam')

    ) as dts,
	TIMESTAMPDIFF(hour,delivery_time,dts) AS delayed_by,
	case when TIMESTAMPDIFF(hour,delivery_time,dts) <= 0 then 1 end as ontime_delivery_flag,

	case when COALESCE(

    TRY_TO_TIMESTAMP(PICKUP_REACHED_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'),

    TRY_TO_TIMESTAMP(PICKUP_REACHED_TIMESTAMP, 'DD/MM/YYYY HH12:MIam')

    )::timestamp <= pickup_slot_end + interval '330 minutes' then 1 end ontime_pickup_flag
FROM partload_application.orders
LEFT JOIN gsheet_sync.ptl_table 
    ON orders.id = ptl_table.order_id
LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS
    ON PTL_INTERNAL_USERS.mobile = orders.customer_mobile
LEFT JOIN partload_analytics.ptl_routes
    ON ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
WHERE orders.state = 3
  AND orders.created_at >= {{start_date}} - INTERVAL '330 MINS'
  and orders.created_at <= {{end_date}} - INTERVAL '330 MINS' + interval '1 day'
  [[AND CASE WHEN PTL_INTERNAL_USERS.mobile IS NULL THEN 'False' ELSE 'True' END = {{is_test}}]]
  [[AND {{pickup_city}}]]
  [[AND {{drop_city}}]]

[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)

,offline as
(
SELECT 
  TO_VARIANT(id) AS id,
  CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
  TO_TIMESTAMP(TO_CHAR(CAST(PICKUP_REACHED_TIMESTAMP AS TIMESTAMP), 'YYYY-MM-DD') || ' ' || PICKUP_SLOT_START, 'YYYY-MM-DD HH24:MI') AS pickup_start,
  PICKUP_REACHED_TIMESTAMP AS pickup_reached,
  DATE_TRUNC('day', TO_TIMESTAMP(TO_CHAR(CAST(PICKUP_REACHED_TIMESTAMP AS TIMESTAMP), 'YYYY-MM-DD') || ' ' || PICKUP_SLOT_START, 'YYYY-MM-DD HH24:MI')) + INTERVAL '36 hour' AS delivery_time,
  drop_start_timestamp AS dts,
  TIMESTAMPDIFF(hour, 
    DATE_TRUNC('day', TO_TIMESTAMP(TO_CHAR(CAST(PICKUP_REACHED_TIMESTAMP AS TIMESTAMP), 'YYYY-MM-DD') || ' ' || PICKUP_SLOT_START, 'YYYY-MM-DD HH24:MI')) + INTERVAL '36 hour',
    drop_start_timestamp
  ) AS delayed_by,
  CASE 
    WHEN TIMESTAMPDIFF(hour, 
      DATE_TRUNC('day', TO_TIMESTAMP(TO_CHAR(CAST(PICKUP_REACHED_TIMESTAMP AS TIMESTAMP), 'YYYY-MM-DD') || ' ' || PICKUP_SLOT_START, 'YYYY-MM-DD HH24:MI')) + INTERVAL '36 hour',
      drop_start_timestamp
    ) <= 0 THEN 1 
  END AS ontime_delivery_flag,
  CASE 
    WHEN PICKUP_REACHED_TIMESTAMP <= 
         TO_TIMESTAMP(TO_CHAR(CAST(PICKUP_REACHED_TIMESTAMP AS TIMESTAMP), 'YYYY-MM-DD') || ' ' || PICKUP_SLOT_START, 'YYYY-MM-DD HH24:MI') + INTERVAL '120 minutes' 
    THEN 1 
  END AS ontime_pickup_flag
FROM prod_curated.gsheet_sync.ptl_offline_orders
LEFT JOIN prod_curated.partload_analytics.ptl_routes
    ON ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
WHERE state = 3
	[[AND {{pickup_city}}]]
	[[AND {{drop_city}}]]
  AND dated >= {{start_date}} 
and dated <= {{end_date}}
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
	count(case when ontime_delivery_flag = 1 and ontime_pickup_flag = 1 then 1 end) as perfect_order_count,
	count(id) as total_order,
	count(case when ontime_delivery_flag = 1 and ontime_pickup_flag = 1 then 1 end)/count(id) as perfect_order_exp
from final
group by 1
order by 1