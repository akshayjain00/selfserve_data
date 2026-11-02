SELECT date_trunc('month', date(updated_at + INTERVAL '330 mins')) AS date,
       COUNT(DISTINCT id) AS orders, ROUND(SUM(estimated_fare/100),0) AS revenue,
       ROUND(SUM(estimated_fare/100)/COUNT(DISTINCT id),0) AS aov
FROM prod_curated.partload_application.orders
WHERE date(updated_at + INTERVAL '330 mins') >= DATE '2026-01-01'
  AND date(updated_at + INTERVAL '330 mins') <= DATE '2026-08-31'
  AND state = '3'
  AND orders.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
GROUP BY 1 ORDER BY 1