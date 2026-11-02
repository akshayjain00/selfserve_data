WITH cancelled_orders AS (
  SELECT 
    customer_mobile as customer_mobile1,
    DATE(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', orders.created_at)) AS cancel_date1,
    weight/1000 as weight_in_kg,
	pickup_lat as pickup_lat1,
	pickup_lng as pickup_lng1,
	drop_lat as drop_lat1,
	drop_lng as drop_lng1,
	MIN(orders.created_at) AS cancel_time,
  FROM PROD_CURATED.PARTLOAD_APPLICATION.orders
  LEFT JOIN PARTLOAD_ANALYTICS.PTL_ROUTES ON orders.route_id = PTL_ROUTES.route_id and PTL_ROUTES.is_active = 'True'
  LEFT JOIN PARTLOAD_APPLICATION.load_details on load_details.order_id = orders.id
  WHERE state = 4
  AND customer_mobile NOT IN (SELECT mobile FROM PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)
  AND CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', orders.created_at) >= {{start_date}}
    AND CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', orders.created_at) < {{end_date}} + INTERVAL '1 day'
	[[and {{pickup_city}}]]
	[[and {{drop_city}}]]
    and entry_type = 'CUSTOMER_DECLARED'
  

[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY 1, 2,3,4,5,6,7
)

, reorders AS (
  SELECT 
    c.customer_mobile1 as customer_mobile2,
    c.cancel_date1 as cancel_date2,
	weight/1000 as weight_in_kg,
	o.pickup_lat as pickup_lat2,
	o.pickup_lng as pickup_lng2,
	o.drop_lat as drop_lat2,
	o.drop_lng as drop_lng2,
    MIN(o.created_at) AS first_reorder_time,
    COUNT(DISTINCT o.external_id) AS total_reorders,
    COUNT(DISTINCT CASE WHEN o.state = 3 THEN o.external_id END) AS completed_reorders
  FROM cancelled_orders c
  JOIN PROD_CURATED.PARTLOAD_APPLICATION.orders o 
    ON o.customer_mobile = c.customer_mobile1
   AND DATE(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.created_at)) = c.cancel_date1
   AND o.created_at > c.cancel_time
  LEFT JOIN PARTLOAD_ANALYTICS.PTL_ROUTES ON o.route_id = PTL_ROUTES.route_id and PTL_ROUTES.is_active = 'True'
  LEFT JOIN PARTLOAD_APPLICATION.load_details on load_details.order_id = o.id
    WHERE CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.created_at) >= {{start_date}}
    AND CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.created_at) < {{end_date}} + INTERVAL '1 day'
	[[and {{pickup_city}}]]
	[[and {{drop_city}}]]
	and entry_type = 'CUSTOMER_DECLARED'
  

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY 1, 2,3,4,5,6,7 
),
final as (
SELECT
  *,
  case when c.weight_in_kg != r.weight_in_kg then 1 end as weight_change,
	CASE 
    WHEN r.pickup_lat2 IS NOT NULL
         AND (
             ST_DISTANCE(
                 TO_GEOGRAPHY(ST_POINT(c.pickup_lng1, c.pickup_lat1)),
                 TO_GEOGRAPHY(ST_POINT(r.pickup_lng2, r.pickup_lat2))
             ) > 100
             OR ST_DISTANCE(
                 TO_GEOGRAPHY(ST_POINT(c.drop_lng1, c.drop_lat1)),
                 TO_GEOGRAPHY(ST_POINT(r.drop_lng2, r.drop_lat2))) > 100)THEN 1 END AS location_change
FROM cancelled_orders c
LEFT JOIN reorders r ON c.customer_mobile1 = r.customer_mobile2 AND c.cancel_date1 = r.cancel_date2 AND C.CUSTOMER_MOBILE1 NOT IN (SELECT MOBILE FROM PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)
)
select 
	-- *,
	-- case when customer_mobile2 is not null or weight_change is not null or location_change is not null then 1 end as reordered_same_day_with_weight_and_location_change
  date_trunc({{period}}, cancel_date1) as day,
  COUNT(DISTINCT customer_mobile1) AS customers_cancelled,
  COUNT(DISTINCT customer_mobile2) AS reordered_same_day,
  COUNT(DISTINCT CASE WHEN completed_reorders > 0 THEN customer_mobile2 END) AS reordered_and_completed_same_day,
  reordered_same_day/customers_cancelled as reordered_perc,
  reordered_and_completed_same_day/customers_cancelled as reordered_and_completed_same_day_perc,
  -- count(DISTINCT case when customer_mobile2 is not null or weight_change is not null or location_change is not null then 1 end) as reordered_same_day_with_weight_and_location_change
  COUNT(DISTINCT CASE WHEN customer_mobile2 IS NOT NULL AND (weight_change = 1 OR location_change = 1)THEN customer_mobile1 END) AS reordered_same_day_with_weight_or_location_change,
  reordered_same_day_with_weight_or_location_change/customers_cancelled as reordered_with_loacation_or_weight_change,
  -- COUNT(DISTINCT CASE WHEN r.completed_reorders > 0 THEN r.customer_mobile END) AS reordered_and_completed_same_day,
  -- ROUND(COUNT(DISTINCT r.customer_mobile)::NUMERIC / COUNT(DISTINCT c.customer_mobile), 2) AS reorder_pct_same_day,
  -- ROUND(COUNT(DISTINCT CASE WHEN r.completed_reorders > 0 THEN r.customer_mobile END)::NUMERIC / COUNT(DISTINCT c.customer_mobile), 2) AS reorder_and_complete_pct_same_day
from final
group by 1
order by 1 desc
