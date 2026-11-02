WITH first_ptl_order AS (
  SELECT mobile, MIN(created_at) AS first_ptl_order_date FROM (
    SELECT REGEXP_REPLACE(o.customer_mobile::varchar,'[^0-9]','') AS mobile,
           CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at) AS created_at
    FROM prod_curated.partload_application.orders o
    WHERE o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
      AND o.state = '3'
  ) GROUP BY 1
),
orders_with_flag AS (
  SELECT o.customer_mobile, o.external_id, f.first_ptl_order_date,
    DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)) AS period,
    CASE WHEN MAX(CASE WHEN CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at) > f.first_ptl_order_date THEN 1 ELSE 0 END)
           OVER (PARTITION BY o.customer_mobile, DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at))) = 1
      THEN 'repeat' ELSE 'new' END AS customer_type,
    CASE WHEN CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at) > f.first_ptl_order_date THEN 'repeat' ELSE 'new' END AS order_type
  FROM prod_curated.partload_application.orders o
  LEFT JOIN first_ptl_order f ON REGEXP_REPLACE(o.customer_mobile::varchar,'[^0-9]','') = f.mobile
  LEFT JOIN prod_curated.oms_public.customers c ON o.customer_mobile = c.mobile
  WHERE o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
    AND CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = 'Business'
    AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)::date >= DATE '2026-01-01'
    AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)::date <  DATE '2026-09-30' + INTERVAL '1 day'
    AND o.state = '3'
)
SELECT period::DATE AS month,
  COUNT(DISTINCT customer_mobile) AS total_customers,
  ROUND(COUNT(DISTINCT CASE WHEN customer_type='repeat' THEN customer_mobile END)*100.0/COUNT(DISTINCT customer_mobile),2) AS repeat_cust_pct,
  COUNT(DISTINCT external_id) AS total_orders,
  COUNT(DISTINCT CASE WHEN order_type='repeat' THEN external_id END) AS repeat_orders,
  ROUND(COUNT(DISTINCT CASE WHEN order_type='repeat' THEN external_id END)*100.0/COUNT(DISTINCT external_id),2) AS repeat_orders_pct
FROM orders_with_flag GROUP BY 1 ORDER BY 1