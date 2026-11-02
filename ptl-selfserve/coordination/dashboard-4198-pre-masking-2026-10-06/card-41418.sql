SELECT
    CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
    CASE 
        WHEN ptl_routes.distance_km <= 100 THEN '0-100 km'
        WHEN ptl_routes.distance_km <= 250 THEN '101-250 km'
        WHEN ptl_routes.distance_km <= 500 THEN '251-500 km'
        ELSE '>500 km'
    END AS distance_bucket,
    -- COUNT(DISTINCT orders.external_id) AS total_orders,
	ROUND(COUNT(DISTINCT orders.external_id) / SUM(COUNT(DISTINCT orders.external_id)) OVER (PARTITION BY dated),  3) AS order_share_percent
FROM PROD_CURATED.PARTLOAD_APPLICATION.orders
LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_ROUTES ON ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
where 1=1
and customer_mobile NOT IN (SELECT MOBILE FROM PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)
and state ='3' --completed
[[AND {{Pickup_city}}]]
[[and {{Drop_city}}]]
and CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))::date >= {{start_date}} 
and CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))::date <= {{end_date}} 


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY 1, 2
ORDER BY 1, 2;
