WITH orders_base AS (
    SELECT  
        o.id AS order_id,
        o.customer_id,
        o.customer_mobile,
        o.route_id,
        ROUND(ld.weight / 1000, 0) AS weight_,
        ld.material_type_id,
        CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.created_at) AS created_at_ist,
        o.state,
        ptl_routes.pickup_city,
        ptl_routes.drop_city,
        
        -- Dynamically choose distance column
        CASE 
            WHEN {{distance_type}} = 'google_based_km' THEN ptl_routes.actual_google_distance
			WHEN {{distance_type}} = 'geo_based_km' THEN ptl_routes.distance_km
            ELSE ptl_routes.distance_km
        END AS selected_distance_km

    FROM partload_application.orders o
    LEFT JOIN prod_curated.partload_application.load_details ld 
        ON o.id = ld.order_id
    LEFT JOIN partload_analytics.ptl_routes
        ON o.route_id = ptl_routes.route_id and ptl_routes.is_active = 'True'
    WHERE o.customer_mobile NOT IN (
        SELECT mobile FROM partload_analytics.ptl_internal_users
    )
    AND DATE(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.created_at)) >= {{start_date}} 
    AND DATE(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.created_at)) <= {{end_date}}
 


[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)

, orders_with_bucket AS (
    SELECT
        *,
        CASE 
            WHEN selected_distance_km IS NULL THEN 'Unknown'
            WHEN selected_distance_km <= 100 THEN '0-100 km'
            WHEN selected_distance_km <= 250 THEN '101-250 km'
            WHEN selected_distance_km <= 500 THEN '251-500 km'
            ELSE '>500 km'
        END AS distance_bucket
    FROM orders_base
)

, bucket_summary AS (
    SELECT  
        DATE_TRUNC({{frequency}}, DATE(created_at_ist)) AS month,
        distance_bucket,
        COUNT(DISTINCT CASE WHEN state = '3' THEN order_id END) AS completed_orders,
        COUNT(DISTINCT CASE WHEN state = '4' THEN order_id END) AS cancelled_orders,
        COUNT(DISTINCT order_id) AS total_orders
    FROM orders_with_bucket
    GROUP BY 1,2
)

, filtered_orders AS (
    SELECT
        month,
        distance_bucket,
        SUM(
            CASE 
                WHEN {{order_state}} = 'completed' THEN completed_orders
                WHEN {{order_state}} = 'cancelled' THEN cancelled_orders
                ELSE total_orders
            END
        ) AS filtered_orders
    FROM bucket_summary
    GROUP BY 1,2
)

SELECT 
    month,
    distance_bucket,
    ROUND(
        filtered_orders / NULLIF(SUM(filtered_orders) OVER (PARTITION BY month), 0),
        4
    ) AS pct_of_month_orders
FROM filtered_orders
ORDER BY 
    month DESC,
    CASE 
        WHEN distance_bucket = '0-100 km' THEN 1
        WHEN distance_bucket = '101-250 km' THEN 2
        WHEN distance_bucket = '251-500 km' THEN 3
        WHEN distance_bucket = '>500 km' THEN 4
        ELSE 5
    END;
