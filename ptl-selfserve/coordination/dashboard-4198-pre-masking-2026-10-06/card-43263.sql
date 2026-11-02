-- WITH monthly_orders AS (
--     SELECT
--         -- DATE_TRUNC('month', created_at) AS order_month,
-- 		TO_DATE(DATE_TRUNC('month', created_at)) AS order_month,
--         orders.route_id,
-- 		ptl_routes.route_name,
--         ptl_routes.ROLLOUT_100_DATE,
--         COUNT(*) AS order_count
--     FROM partload_application.orders
--     LEFT JOIN partload_analytics.ptl_routes 
--         ON ptl_routes.route_id = orders.route_id
-- 	left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
-- 		on PTL_INTERNAL_USERS.mobile= orders.customer_mobile
--     WHERE orders.route_id IS NOT NULL
-- 	and {{pickup_city}}
-- 	and {{drop_city}}
-- 	and PTL_INTERNAL_USERS.mobile is null
--     GROUP BY 1,2,3,4
-- )

-- SELECT
--     order_month,
--     concat(route_name,' [',ROLLOUT_100_DATE,']') as routes,
-- 	-- concat(route_name,' [',order_count,']') as routes,
--     ROUND(
--         CASE 
--             WHEN LAG(order_count) OVER (PARTITION BY route_id ORDER BY order_month) IS NULL THEN NULL
--             ELSE (order_count - LAG(order_count) OVER (PARTITION BY route_id ORDER BY order_month))
--                  / LAG(order_count) OVER (PARTITION BY route_id ORDER BY order_month) * 100
--         END, 2
--     ) AS mom_growth_percent
-- FROM monthly_orders
-- order by order_month,order_count
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
        AND {{pickup_city}}
        AND {{drop_city}}
        AND PTL_INTERNAL_USERS.mobile IS NULL
    

[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY 1,2,3
),

first_month_orders AS (
    SELECT
        route_id,
        -- Get the first month it appears
        MIN(order_month) AS first_month
    FROM monthly_orders
    GROUP BY 1
),

first_month_order_count AS (
    SELECT
        m.route_id,
        m.order_count AS first_month_order_count
    FROM monthly_orders m
    JOIN first_month_orders f
        ON m.route_id = f.route_id
       AND m.order_month = f.first_month
)

SELECT
    m.order_month,
    CONCAT(m.route_name, ' [', f.first_month_order_count, ']') AS routes,
    ROUND(
        CASE 
            WHEN LAG(m.order_count) OVER (PARTITION BY m.route_id ORDER BY m.order_month) IS NULL 
                THEN NULL
            ELSE 
                (m.order_count - LAG(m.order_count) OVER (PARTITION BY m.route_id ORDER BY m.order_month))
                / LAG(m.order_count) OVER (PARTITION BY m.route_id ORDER BY m.order_month) * 100
        END, 2
    ) AS mom_growth_percent
FROM monthly_orders m
LEFT JOIN first_month_order_count f
    ON m.route_id = f.route_id
ORDER BY m.order_month, m.order_count;