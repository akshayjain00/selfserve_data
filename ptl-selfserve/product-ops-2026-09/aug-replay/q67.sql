WITH biz AS (
  SELECT o.customer_mobile, o.external_id, o.id,
         CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at) AS ist
  FROM prod_curated.partload_application.orders o
  LEFT JOIN prod_curated.oms_public.customers c ON o.customer_mobile = c.mobile
  WHERE o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
    AND c.frequency IN (1,2,3,4) AND o.state = '3'
),
firsts AS (SELECT customer_mobile, MIN(ist) AS first_ist FROM biz GROUP BY 1)
SELECT DATE_TRUNC('month', b.ist)::DATE AS m,
   COUNT(DISTINCT b.customer_mobile) AS nsm_txn_business_cx,
   COUNT(DISTINCT b.external_id) AS completed_business_orders,
   COUNT(DISTINCT CASE WHEN DATE_TRUNC('month', f.first_ist) = DATE_TRUNC('month', b.ist) THEN b.customer_mobile END) AS new_business_users,
   ROUND(COUNT(DISTINCT b.external_id)/COUNT(DISTINCT b.customer_mobile),3) AS txn_per_customer
FROM biz b JOIN firsts f ON f.customer_mobile = b.customer_mobile
WHERE b.ist::DATE BETWEEN DATE '2026-06-01' AND DATE '2026-08-31'
GROUP BY 1 ORDER BY 1