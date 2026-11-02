WITH online as (
SELECT 
    o.id,
    PICKUP_REACHED_TIMESTAMP,
    pickup_slot_end + INTERVAL '330 minutes' AS adjusted_pickup_slot_end,
    TIMESTAMPDIFF(HOUR, pickup_slot_end + INTERVAL '330 MINUTE', PICKUP_REACHED_TIMESTAMP) AS diff_hours,
FROM partload_application.orders o 
JOIN gsheet_sync.ptl_table ptl 
    ON o.id = ptl.order_id
LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
    ON PTL_INTERNAL_USERS.mobile = o.customer_mobile
LEFT JOIN prod_curated.partload_analytics.ptl_routes 
    ON ptl_routes.route_id = o.route_id and ptl_routes.is_active = 'True'
WHERE o.state = 3
[[AND {{pickup_city}}]]
[[AND {{drop_city}}]]
[[AND CASE WHEN ptl_internal_users.mobile IS NULL THEN 'False' ELSE 'True' END = {{is_test}}]]
AND DATE(o.created_at)>= {{start_date}} - INTERVAL '330 MINS'
AND DATE(o.created_at)<= {{end_date}} - INTERVAL '330 MINS'+ interval '1 day'
AND (PICKUP_REACHED_TIMESTAMP::timestamp > pickup_slot_end + INTERVAL '330 minutes' OR PICKUP_REACHED_TIMESTAMP IS NULL OR TRIM(PICKUP_REACHED_TIMESTAMP) = '')


[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)


,offline as
(
SELECT 
    to_variant(id) as id,
    PICKUP_REACHED_TIMESTAMP,
    TO_TIMESTAMP(TO_CHAR(CAST(PICKUP_REACHED_TIMESTAMP AS TIMESTAMP), 'YYYY-MM-DD') || ' ' || PICKUP_SLOT_START, 'YYYY-MM-DD HH24:MI') + INTERVAL '120 minutes' AS adjusted_pickup_slot_end,
    TIMESTAMPDIFF(HOUR, adjusted_pickup_slot_end, PICKUP_REACHED_TIMESTAMP) AS diff_hours,
FROM prod_curated.gsheet_sync.ptl_offline_orders
LEFT JOIN prod_curated.partload_analytics.ptl_routes 
    ON ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
WHERE state = 3
[[AND {{pickup_city}}]]
[[AND {{drop_city}}]]
AND DATE(created_at)>= {{start_date}} 
AND DATE(created_at)<= {{end_date}} 
AND (PICKUP_REACHED_TIMESTAMP::timestamp > adjusted_pickup_slot_end OR PICKUP_REACHED_TIMESTAMP IS NULL OR TRIM(PICKUP_REACHED_TIMESTAMP) = '')
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
    to_variant(id) as id,
    PICKUP_REACHED_TIMESTAMP,
    adjusted_pickup_slot_end,
diff_hours,
CASE  
    	WHEN PICKUP_REACHED_TIMESTAMP IS NULL OR TRIM(PICKUP_REACHED_TIMESTAMP::timestamp) = '' THEN 'Time not Entered'
    	WHEN TIMESTAMPDIFF(HOUR, adjusted_pickup_slot_end, PICKUP_REACHED_TIMESTAMP::timestamp) > 0 
        	AND TIMESTAMPDIFF(HOUR, adjusted_pickup_slot_end, PICKUP_REACHED_TIMESTAMP::timestamp) <= 1 THEN '<1 hr'
    	WHEN TIMESTAMPDIFF(HOUR, adjusted_pickup_slot_end, PICKUP_REACHED_TIMESTAMP::timestamp) > 1 
         	AND TIMESTAMPDIFF(HOUR, adjusted_pickup_slot_end, PICKUP_REACHED_TIMESTAMP::timestamp) <= 2 THEN '1-2 hr'
    	WHEN TIMESTAMPDIFF(HOUR, adjusted_pickup_slot_end, PICKUP_REACHED_TIMESTAMP::timestamp) > 2 
         	AND TIMESTAMPDIFF(HOUR, adjusted_pickup_slot_end, PICKUP_REACHED_TIMESTAMP::timestamp) <= 5 THEN '2-5 hr'
    	WHEN TIMESTAMPDIFF(HOUR, adjusted_pickup_slot_end, PICKUP_REACHED_TIMESTAMP::timestamp) > 5 THEN '>5 hr'
	END AS delay_bucket
	from final
)

select 
delay_bucket,
count(id) as order_count
from raw
group by 1
order by 1