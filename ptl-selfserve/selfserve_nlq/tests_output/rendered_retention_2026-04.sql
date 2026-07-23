WITH m0 AS (
    SELECT DISTINCT o.customer_mobile AS mobile
    FROM prod_curated.partload_application.orders o
    WHERE o.created_at >= DATEADD('minute', -330, DATE '2026-04-01')
      AND o.created_at <  DATEADD('minute', -330, DATE '2026-05-01') AND o.state = 3
      AND NOT EXISTS (SELECT 1 FROM prod_curated.partload_analytics.ptl_internal_users u WHERE u.mobile = o.customer_mobile)
      AND EXISTS (SELECT 1 FROM prod_curated.oms_public.customers c WHERE c.mobile = o.customer_mobile AND c.frequency IN (1,2,3,4)) /*⚠VERIFY business filter (§3.5); completed-vs-placed basis vs dashboard 4569*/
),
m1 AS (
    SELECT DISTINCT o.customer_mobile AS mobile
    FROM prod_curated.partload_application.orders o
    WHERE o.created_at >= DATEADD('minute', -330, DATE '2026-05-01')
      AND o.created_at <  DATEADD('minute', -330, DATE '2026-06-01') AND o.state = 3
)
SELECT 'excl_offline' AS basis,
       (SELECT COUNT(*) FROM m0)                                        AS m0_business_users,
       (SELECT COUNT(*) FROM m0 WHERE mobile IN (SELECT mobile FROM m1)) AS m0_retained
