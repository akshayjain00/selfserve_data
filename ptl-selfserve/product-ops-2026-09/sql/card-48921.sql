-- card 48921 New PTL business users acquired; start_date=2026-08-01 end_date=2026-09-30 granularity=Month; city filters dropped
WITH all_business_orders AS (
    SELECT o.id, o.customer_mobile,
        CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at)) AS order_ts,
        CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at))::DATE AS order_date
    FROM prod_curated.partload_application.orders o
    LEFT JOIN prod_curated.partload_analytics.ptl_routes ON ptl_routes.route_id = o.route_id and ptl_routes.is_active = 'True'
    LEFT JOIN prod_curated.oms_public.customers c ON c.mobile = o.customer_mobile
    LEFT JOIN prod_curated.partload_analytics.ptl_internal_users iu ON iu.mobile = o.customer_mobile
    WHERE o.customer_mobile IS NOT NULL AND iu.mobile IS NULL AND o.state = 3 AND c.frequency IN (1, 2, 3, 4)
),
first_orders AS (
    SELECT abo.customer_mobile, abo.order_ts, abo.order_date, DATE_TRUNC('Month', abo.order_ts)::DATE AS period_start
    FROM all_business_orders abo
    QUALIFY ROW_NUMBER() OVER (PARTITION BY abo.customer_mobile ORDER BY abo.order_ts, abo.id) = 1
),
new_business_users AS (
    SELECT fo.period_start, COUNT(DISTINCT fo.customer_mobile) AS new_ptl_business_users_acquired
    FROM first_orders fo
    WHERE fo.order_date >= '2026-08-01' AND fo.order_date < '2026-09-30'::date + INTERVAL '1 day'
    GROUP BY 1
),
business_users_in_period AS (
    SELECT DATE_TRUNC('Month', abo.order_ts)::DATE AS period_start, COUNT(DISTINCT abo.customer_mobile) AS all_business_users_in_period
    FROM all_business_orders abo
    WHERE abo.order_date >= '2026-08-01' AND abo.order_date < '2026-09-30'::date + INTERVAL '1 day'
    GROUP BY 1
)
SELECT b.period_start, COALESCE(n.new_ptl_business_users_acquired, 0) AS new_ptl_business_users_acquired, b.all_business_users_in_period,
    ROUND(1.0 * COALESCE(n.new_ptl_business_users_acquired, 0) / NULLIF(b.all_business_users_in_period, 0), 4) AS new_ptl_business_users_acquired_pct
FROM business_users_in_period b LEFT JOIN new_business_users n ON b.period_start = n.period_start ORDER BY 1;
