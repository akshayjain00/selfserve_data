WITH monthly_orders AS (
    SELECT
        TO_DATE(DATE_TRUNC('month', created_at)) AS order_month,
        orders.route_id,
        ptl_routes.route_name,
        COUNT(*) AS order_count
    FROM partload_application.orders
    LEFT JOIN partload_analytics.ptl_routes 
        ON ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
    LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
        ON PTL_INTERNAL_USERS.mobile = orders.customer_mobile
    WHERE orders.route_id IS NOT NULL
        [[AND {{pickup_city}}]]
        [[AND {{drop_city}}]]
		[[AND {{route}}]]
		[[AND 
            CASE {{DISTANCE_RANGE}}
                WHEN '<=100' THEN ptl_routes.distance_km <= 100
                WHEN '101-200' THEN ptl_routes.distance_km BETWEEN 101 AND 200
                WHEN '201-500' THEN ptl_routes.distance_km BETWEEN 201 AND 500
                WHEN '>500' THEN ptl_routes.distance_km > 500
                ELSE TRUE
            END
        ]]
        AND PTL_INTERNAL_USERS.mobile IS NULL
    

[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY 1,2,3
),

first_month AS (
    SELECT 
        route_id,
        MIN(order_month) AS first_order_month
    FROM monthly_orders
    GROUP BY route_id
),

cohort_base AS (
    SELECT 
        m.route_id,
        m.route_name,
        f.first_order_month,
        m.order_month,
        DATEDIFF(month, f.first_order_month, m.order_month) AS month_number,
        m.order_count,
        
        -- previous month's count (needed for MoM %)
        LAG(m.order_count) OVER (
            PARTITION BY m.route_id ORDER BY m.order_month
        ) AS prev_month_order_count
    FROM monthly_orders m
    JOIN first_month f ON m.route_id = f.route_id
)

SELECT
    -- concat(route_name,' [',first_order_month,']') as route_and_month_launched,
	CONCAT(route_name, ' [', TO_CHAR(first_order_month, 'YYYY-MM'), ']') AS route_and_month_launched,
    first_order_month AS cohort_start_month,
    month_number,

    /* ----------- METRIC VALUE (raw for month 0, % for others) ----------- */
    CASE 
        WHEN month_number = 0 
            THEN TO_VARCHAR(order_count)
        ELSE 
            TO_VARCHAR(
                ROUND(
                    (order_count - prev_month_order_count) 
                    / NULLIF(prev_month_order_count, 0) * 100
                , 2)
            ) || '%'
    END AS metric_value,

    /* ----------- DISPLAY VALUE (same formatting) ----------- */
    CASE 
        WHEN month_number = 0 
            THEN TO_VARCHAR(order_count)
        ELSE 
            TO_VARCHAR(
                ROUND(
                    (order_count - prev_month_order_count) 
                    / NULLIF(prev_month_order_count, 0) * 100
                , 2)
            ) || '%'
    END AS display_value

FROM cohort_base
WHERE order_month < (SELECT MAX(order_month) FROM monthly_orders)
ORDER BY route_id, month_number;