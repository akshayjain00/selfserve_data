WITH online_filtered_orders AS (
  SELECT o.customer_mobile, CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at) AS created_at, o.external_id
  FROM prod_curated.partload_application.orders o
  LEFT JOIN prod_curated.oms_public.customers c ON o.customer_mobile = c.mobile
  WHERE o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
    AND o.state = '3'
    AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)::DATE >= DATE '2026-01-01'
    AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)::DATE <  DATE '2026-08-31' + INTERVAL '1 day'
    AND CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = 'Business'
),
offline_filtered_orders AS (
  SELECT ofo.customer_mobile, ofo.created_at, ofo.external_id
  FROM prod_curated.gsheet_sync.ptl_offline_orders ofo
  LEFT JOIN prod_curated.oms_public.customers c ON ofo.customer_mobile = c.mobile
  WHERE ofo.state = '3' AND ofo.created_at::date >= DATE '2026-01-01' AND ofo.created_at::date <= DATE '2026-08-31'
    AND CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = 'Business'
),
final AS (SELECT * FROM online_filtered_orders UNION ALL SELECT * FROM offline_filtered_orders)
SELECT CAST(DATE_TRUNC('month', created_at) AS DATE) AS dated,
       ROUND(COUNT(DISTINCT external_id)/COUNT(DISTINCT customer_mobile), 3) AS order_per_customer
FROM final GROUP BY 1 ORDER BY 1