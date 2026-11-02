-- =========================
-- 1️⃣ QUOTES DATA
-- =========================
WITH quotes_base AS (
    SELECT 
        QUOTE_REQUESTS.id AS quote_id,
        QUOTE_REQUESTS.ROUTE_ID,
        ROUND(weight, 0) AS weight_,
        material_type_id,
        TO_TIMESTAMP(QUOTE_REQUESTS.PICKUP_SLOT, 'DD-MM-YYYY:HH24:MI') + INTERVAL '330 MINUTES' AS pickup_slot_start_,
        QUOTE_REQUESTS.created_At + INTERVAL '330 MINUTES' AS created_at,
        dc.mobile,
        QUOTE_REQUESTS.customer_uuid
    FROM PARTLOAD_APPLICATION.QUOTE_REQUESTS
    LEFT JOIN PROD_CURATED.oms_public.customers dc 
        ON dc.uuid = QUOTE_REQUESTS.customer_uuid
    WHERE dc.mobile NOT IN (SELECT MOBILE FROM PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)
    [[and date(QUOTE_REQUESTS.created_at) >= {{start_date}} and date(QUOTE_REQUESTS.created_at) <= {{end_date}}]]
)

-- =========================
-- 2️⃣ ORDERS DATA
-- =========================
, orders_base AS (
    SELECT  
        orders.id AS order_id,
        customer_id,
        customer_mobile,
        orders.ROUTE_ID,
        ROUND(weight / 1000, 0) AS weight_,
        material_type_id,
        orders.created_At + INTERVAL '330 MINUTES' AS created_At,
        orders.STATE
    FROM PARTLOAD_APPLICATION.orders
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.LOAD_DETAILS 
        ON ORDERS.id = LOAD_DETAILS.order_id
    WHERE customer_mobile NOT IN (SELECT MOBILE FROM PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)
    [[and date(orders.created_at) >= {{start_date}} and date(orders.created_at) <= {{end_date}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)

-- =========================
-- 3️⃣ QUOTES AGGREGATION
-- =========================
, quotes_summary AS (
    SELECT  
        DATE_TRUNC({{frequency}}, date(created_at)) AS month,
        ptl_routes.route_name,
        COUNT(DISTINCT quote_id) AS quotes,
        0 AS orders,
        0 AS completed_orders,
        0 AS cancelled_orders,
        COUNT(DISTINCT customer_uuid) AS quote_users,
        0 AS order_users
    FROM quotes_base
    LEFT JOIN prod_curated.partload_analytics.ptl_routes 
        ON ptl_routes.route_id = quotes_base.route_id and ptl_routes.is_active = 'True'
    WHERE 1=1
    [[and {{pickup_city}}]]
    [[and {{drop_city}}]]
    GROUP BY 1,2
)

-- =========================
-- 4️⃣ ORDERS AGGREGATION
-- =========================
, orders_summary AS (
    SELECT  
        DATE_TRUNC({{frequency}}, date(created_at)) AS month,
        ptl_routes.route_name,
        0 AS quotes,
        COUNT(DISTINCT order_id) AS orders,
        COUNT(DISTINCT CASE WHEN state = '3' THEN order_id END) AS completed_orders,
        COUNT(DISTINCT CASE WHEN state = '4' THEN order_id END) AS cancelled_orders,
        0 AS quote_users,
        COUNT(DISTINCT customer_mobile) AS order_users
    FROM orders_base
    LEFT JOIN prod_curated.partload_analytics.ptl_routes 
        ON ptl_routes.route_id = orders_base.route_id and ptl_routes.is_active = 'True'
    WHERE 1=1
    [[and {{pickup_city}}]]
    [[and {{drop_city}}]]
    GROUP BY 1,2
)

-- =========================
-- 5️⃣ FINAL UNION + MERGE
-- =========================
, combined AS (
    SELECT * FROM quotes_summary
    UNION ALL
    SELECT * FROM orders_summary
)
SELECT
    month,
    route_name,
    -- SUM(quotes) AS quotes,
    -- SUM(orders) AS orders,
    SUM(completed_orders) AS completed_orders,
    -- SUM(cancelled_orders) AS cancelled_orders,
    -- SUM(quote_users) AS quote_check_users,
    -- SUM(order_users) AS order_placed_users,
    -- CASE WHEN SUM(quotes) > 0 THEN SUM(orders)::float / SUM(quotes) ELSE 0 END AS quote_to_pay,
    -- CASE WHEN SUM(quotes) > 0 THEN SUM(completed_orders)::float / SUM(quotes) ELSE 0 END AS quote_to_completed
FROM combined
GROUP BY 1,2
ORDER BY month ASC, route_name;
