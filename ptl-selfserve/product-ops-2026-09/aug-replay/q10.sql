WITH all_business_orders AS (
    SELECT o.id, o.customer_mobile,
        CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(o.created_at)) AS order_ts,
        CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(o.created_at))::DATE AS order_date
    FROM prod_curated.partload_application.orders o
    LEFT JOIN prod_curated.oms_public.customers c ON c.mobile = o.customer_mobile
    LEFT JOIN prod_curated.partload_analytics.ptl_internal_users iu ON iu.mobile = o.customer_mobile
    WHERE o.customer_mobile IS NOT NULL AND iu.mobile IS NULL AND o.state = 3
      AND c.frequency IN (1,2,3,4)
),
first_orders AS (
    SELECT abo.customer_mobile, abo.order_date, DATE_TRUNC('month', abo.order_ts)::DATE AS period_start
    FROM all_business_orders abo
    QUALIFY ROW_NUMBER() OVER (PARTITION BY abo.customer_mobile ORDER BY abo.order_ts, abo.id) = 1
),
new_business_users AS (
    SELECT fo.period_start, COUNT(DISTINCT fo.customer_mobile) AS new_users
    FROM first_orders fo
    WHERE fo.order_date >= DATE '2026-01-01' AND fo.order_date < DATE '2026-08-31' + INTERVAL '1 day'
    GROUP BY 1
),
business_users_in_period AS (
    SELECT DATE_TRUNC('month', abo.order_ts)::DATE AS period_start,
           COUNT(DISTINCT abo.customer_mobile) AS all_business_users
    FROM all_business_orders abo
    WHERE abo.order_date >= DATE '2026-01-01' AND abo.order_date < DATE '2026-08-31' + INTERVAL '1 day'
    GROUP BY 1
)
SELECT b.period_start, COALESCE(n.new_users,0) AS new_ptl_business_users, b.all_business_users,
       ROUND(100.0*COALESCE(n.new_users,0)/NULLIF(b.all_business_users,0),2) AS new_pct
FROM business_users_in_period b LEFT JOIN new_business_users n ON b.period_start = n.period_start
ORDER BY 1