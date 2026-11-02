WITH online_filtered_orders AS (
  SELECT o.customer_mobile,
         o.created_at + INTERVAL '330 MINS' AS created_at,
         CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END AS category
  FROM prod_curated.partload_application.orders o
  LEFT JOIN prod_curated.oms_public.customers c ON o.customer_mobile = c.mobile
  WHERE o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
    AND CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = 'Business'
    AND o.state = '3'
    AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)::DATE >= DATE '2026-01-01'
    AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)::DATE <  DATE '2026-08-31' + INTERVAL '1 day'
),
offline_filtered_orders AS (
  SELECT ofo.customer_mobile,
         ofo.created_at AS created_at,
         CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END AS category
  FROM prod_curated.gsheet_sync.ptl_offline_orders ofo
  LEFT JOIN prod_curated.oms_public.customers c ON ofo.customer_mobile = c.mobile
  WHERE ofo.state = 3
    AND CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = 'Business'
    AND ofo.created_at::DATE >= DATE '2026-01-01'
    AND ofo.created_at::DATE <= DATE '2026-08-31'
),
final_orders AS (SELECT * FROM online_filtered_orders UNION SELECT * FROM offline_filtered_orders)
SELECT DATE_TRUNC('month', created_at)::DATE AS period,
       COUNT(DISTINCT customer_mobile) AS active_customers
FROM final_orders GROUP BY 1 ORDER BY 1