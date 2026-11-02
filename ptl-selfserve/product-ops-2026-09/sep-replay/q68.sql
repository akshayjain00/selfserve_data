WITH online AS (
  SELECT CAST(DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
         orders.external_id, orders.state
  FROM PROD_CURATED.PARTLOAD_APPLICATION.orders
  LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS piu ON piu.mobile = orders.customer_mobile
  LEFT JOIN prod_eldoria.core.dim_customers dc ON orders.customer_mobile = dc.mobile
  WHERE CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(orders.created_at)) >= DATE '2026-06-01'
    AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(orders.created_at)) <= DATE '2026-09-30' + INTERVAL '1 day'
    AND piu.mobile IS NULL
    AND (CASE WHEN dc.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END) = 'Business'
)
SELECT dated, COUNT(DISTINCT external_id) AS placed_business,
       COUNT(DISTINCT CASE WHEN state=3 THEN external_id END) AS completed_business_dimcust
FROM online GROUP BY 1 ORDER BY 1