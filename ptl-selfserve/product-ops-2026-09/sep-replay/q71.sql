WITH lifetime AS (
  SELECT o.customer_mobile, o.created_at + INTERVAL '330 MINS' AS ist
  FROM prod_curated.partload_application.orders o
  LEFT JOIN prod_curated.oms_public.customers c ON o.customer_mobile = c.mobile
  WHERE o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
    AND o.state = '3' AND c.frequency IN (1,2,3,4)
),
lpc AS (SELECT DATE_TRUNC('month', ist) AS period, customer_mobile, COUNT(*) AS n FROM lifetime GROUP BY 1,2),
lo AS (SELECT period, customer_mobile,
         SUM(n) OVER (PARTITION BY customer_mobile ORDER BY period ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS lifetime_n
       FROM lpc),
co AS (SELECT DATE_TRUNC('month', ist) AS period, customer_mobile FROM lifetime
       WHERE DATE(ist) BETWEEN DATE '2026-06-01' AND DATE '2026-09-30' GROUP BY 1,2),
repeat_share AS (
  SELECT co.period::DATE AS m,
    ROUND(100.0*COUNT(DISTINCT CASE WHEN lo.lifetime_n > 1 THEN co.customer_mobile END)/COUNT(DISTINCT co.customer_mobile),2) AS repeat_share_pct
  FROM co LEFT JOIN lo ON lo.customer_mobile = co.customer_mobile AND lo.period = co.period
  GROUP BY 1
),
firsts AS (SELECT REGEXP_REPLACE(customer_mobile::varchar,'[^0-9]','') AS mob,
                  MIN(CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)) AS first_ist
  FROM prod_curated.partload_application.orders o
  WHERE o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users) AND o.state='3' GROUP BY 1),
ordflag AS (
  SELECT DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at))::DATE AS m, o.external_id,
     CASE WHEN CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at) > f.first_ist THEN 'repeat' ELSE 'new' END AS order_type
  FROM prod_curated.partload_application.orders o
  LEFT JOIN firsts f ON REGEXP_REPLACE(o.customer_mobile::varchar,'[^0-9]','') = f.mob
  LEFT JOIN prod_curated.oms_public.customers c ON o.customer_mobile = c.mobile
  WHERE o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
    AND c.frequency IN (1,2,3,4) AND o.state='3'
    AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)::date BETWEEN DATE '2026-06-01' AND DATE '2026-09-30'
),
from_repeat AS (
  SELECT m, ROUND(100.0*COUNT(DISTINCT CASE WHEN order_type='repeat' THEN external_id END)/COUNT(DISTINCT external_id),2) AS orders_from_repeat_pct
  FROM ordflag GROUP BY 1
),
allcx AS (
  SELECT DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at))::DATE AS m, o.customer_mobile,
         CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END AS cat
  FROM prod_curated.partload_application.orders o
  LEFT JOIN prod_curated.oms_public.customers c ON o.customer_mobile = c.mobile
  WHERE o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users) AND o.state='3'
    AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)::date BETWEEN DATE '2026-06-01' AND DATE '2026-09-30'
),
biz_share AS (
  SELECT m, ROUND(100.0*COUNT(DISTINCT CASE WHEN cat='Business' THEN customer_mobile END)/COUNT(DISTINCT customer_mobile),2) AS business_share_pct
  FROM allcx GROUP BY 1
)
SELECT r.m, r.repeat_share_pct, fr.orders_from_repeat_pct, bs.business_share_pct
FROM repeat_share r LEFT JOIN from_repeat fr ON fr.m=r.m LEFT JOIN biz_share bs ON bs.m=r.m ORDER BY 1