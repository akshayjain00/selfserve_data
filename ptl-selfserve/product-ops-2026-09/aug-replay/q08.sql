WITH online AS (
  SELECT CAST(DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
         orders.external_id, orders.state
  FROM PROD_CURATED.PARTLOAD_APPLICATION.orders
  LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS piu ON piu.mobile = orders.customer_mobile
  LEFT JOIN prod_eldoria.core.dim_customers dc ON orders.customer_mobile = dc.mobile
  WHERE CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(orders.created_at)) >= DATE '2026-01-01'
    AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(orders.created_at)) <= DATE '2026-08-31' + INTERVAL '1 day'
    AND CASE WHEN piu.mobile IS NULL THEN 'False' ELSE 'True' END = 'False'
    AND (CASE WHEN dc.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END) = 'Business'
),
offline AS (
  SELECT CAST(DATE_TRUNC('month', ptl_offline_orders.created_at::date) AS DATE) AS dated, external_id, state
  FROM prod_curated.gsheet_sync.ptl_offline_orders
  LEFT JOIN prod_eldoria.core.dim_customers dc ON ptl_offline_orders.customer_mobile = dc.mobile
  WHERE ptl_offline_orders.created_at >= DATE '2026-01-01' AND ptl_offline_orders.created_at <= DATE '2026-08-31'
    AND (CASE WHEN dc.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END) = 'Business'
),
final AS (SELECT * FROM online UNION ALL SELECT * FROM offline)
SELECT dated,
       COUNT(DISTINCT external_id) AS total_orders,
       COUNT(DISTINCT CASE WHEN state=3 THEN external_id END) AS completed_orders,
       COUNT(DISTINCT CASE WHEN state=4 THEN external_id END) AS cancelled_orders
FROM final GROUP BY 1 ORDER BY 1