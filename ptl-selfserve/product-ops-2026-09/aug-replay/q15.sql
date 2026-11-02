WITH online_filtered_orders AS (
  SELECT o.customer_mobile, o.created_at + INTERVAL '330 MINS' AS created_at, o.route_id,
         CASE WHEN customers.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END AS category
  FROM prod_curated.partload_application.orders o
  LEFT JOIN prod_curated.oms_public.customers ON o.customer_mobile = customers.mobile
  WHERE o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
    AND o.state = '3'
    AND DATE(o.created_at) >= DATE '2026-01-01' - INTERVAL '330 MINS'
    AND DATE(o.created_at) <  DATE '2026-08-31' - INTERVAL '330 MINS' + INTERVAL '1 day'
    AND CASE WHEN customers.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = 'Business'
),
online_lifetime_orders AS (
  SELECT o.customer_mobile, o.created_at + INTERVAL '330 MINS' AS created_at, o.route_id,
         CASE WHEN customers.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END AS category
  FROM prod_curated.partload_application.orders o
  LEFT JOIN prod_curated.oms_public.customers ON o.customer_mobile = customers.mobile
  WHERE o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
    AND o.state = '3'
    AND CASE WHEN customers.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = 'Business'
),
lifetime_period_counts AS (
  SELECT DATE_TRUNC('month', created_at) AS period, customer_mobile, COUNT(*) AS orders_in_period
  FROM online_lifetime_orders GROUP BY 1,2
),
lifetime_orders AS (
  SELECT period, customer_mobile,
         SUM(orders_in_period) OVER (PARTITION BY customer_mobile ORDER BY period
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS lifetime_order_count
  FROM lifetime_period_counts
),
customer_orders AS (
  SELECT DATE_TRUNC('month', created_at) AS period, customer_mobile, COUNT(*) AS order_count
  FROM online_filtered_orders GROUP BY 1,2
)
SELECT co.period::DATE AS period,
       COUNT(DISTINCT co.customer_mobile) AS total_customers,
       COUNT(DISTINCT CASE WHEN lo.lifetime_order_count > 1 THEN co.customer_mobile END) AS repeat_customers,
       ROUND(COUNT(DISTINCT CASE WHEN lo.lifetime_order_count > 1 THEN co.customer_mobile END) * 100.0
             / NULLIF(COUNT(DISTINCT co.customer_mobile),0), 2) AS repeat_purchase_rate_pct
FROM customer_orders co
LEFT JOIN lifetime_orders lo ON lo.customer_mobile = co.customer_mobile AND lo.period = co.period
GROUP BY 1 ORDER BY 1