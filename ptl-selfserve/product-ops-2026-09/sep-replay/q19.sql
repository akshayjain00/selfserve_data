WITH online_orders AS (
    SELECT o.customer_mobile, CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at) AS created_at,
        CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END AS category, o.route_id
    FROM prod_curated.partload_application.orders o
    LEFT JOIN prod_curated.oms_public.customers c ON o.customer_mobile = c.mobile
    WHERE o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
      AND o.state = '3'
      AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)::DATE >= DATE '2026-01-01'
      AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)::DATE <  DATE '2026-09-30' + INTERVAL '1 day'
),
offline_orders AS (
    SELECT ofo.customer_mobile, ofo.created_at,
        CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END AS category, ofo.route_id
    FROM prod_curated.gsheet_sync.ptl_offline_orders ofo
    LEFT JOIN prod_curated.oms_public.customers c ON ofo.customer_mobile = c.mobile
    WHERE ofo.state = '3' AND ofo.created_at::DATE >= DATE '2026-01-01'
      AND ofo.created_at::DATE < DATE '2026-09-30' + INTERVAL '1 day'
),
final_orders AS (SELECT * FROM online_orders UNION SELECT * FROM offline_orders)
SELECT DATE_TRUNC('month', created_at)::DATE AS period,
   COUNT(DISTINCT customer_mobile) AS total_customers,
   COUNT(DISTINCT CASE WHEN category='Business' THEN customer_mobile END) AS business_customers,
   ROUND(COUNT(DISTINCT CASE WHEN category='Business' THEN customer_mobile END)*100.0/NULLIF(COUNT(DISTINCT customer_mobile),0),2) AS business_customer_pct
FROM final_orders GROUP BY 1 ORDER BY 1