WITH appsheet AS (
  SELECT * FROM prod_curated.partload_analytics.ptl_app_sheet_backfilled_data
  UNION ALL SELECT * FROM prod_curated.gsheet_sync."ptl_app_sheet_data"
),
as_ded AS (SELECT * FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY reached_pickup_at DESC NULLS LAST) rn FROM appsheet) WHERE rn=1),
completed AS (
  SELECT DATE_TRUNC('month', o.created_at + INTERVAL '330 mins')::DATE AS m, COUNT(DISTINCT o.id) AS completed_orders
  FROM prod_curated.partload_application.orders o
  WHERE o.state = 3 AND o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
    AND DATE(o.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-06-01' AND DATE '2026-09-30'
  GROUP BY 1
),
as_cov AS (
  SELECT DATE_TRUNC('month', o.created_at + INTERVAL '330 mins')::DATE AS m, COUNT(DISTINCT d.order_id) AS appsheet_orders
  FROM as_ded d INNER JOIN prod_curated.partload_application.orders o ON o.id = d.order_id AND o.state = 3
  WHERE DATE(o.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-06-01' AND DATE '2026-09-30'
  GROUP BY 1
),
payout AS (
  SELECT DATE_TRUNC('month', b.created_at + INTERVAL '330 mins')::DATE AS m,
         COUNT(DISTINCT b.id) AS payout_batches, ROUND(SUM(TRY_TO_DECIMAL(v.total_vendor_pay,38,4)),0) AS pay
  FROM prod_curated.partload_application.batch_v1 b
  INNER JOIN prod_curated.partload_analytics.vendor_payout_batch_level v ON v.batch_id = b.id
  WHERE DATE(b.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-06-01' AND DATE '2026-09-30'
  GROUP BY 1
),
ptl_table AS (
  SELECT DATE_TRUNC('month', o.created_at + INTERVAL '330 mins')::DATE AS m,
         COUNT(DISTINCT CASE WHEN g.TOTAL_VENDOR_PAYOUT IS NOT NULL THEN o.id END) AS orders_with_cost
  FROM prod_curated.partload_application.orders o
  LEFT JOIN prod_curated.gsheet_sync.PTL_TABLE g ON o.id = g.order_id
  WHERE o.state = 3 AND DATE(o.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-06-01' AND DATE '2026-09-30'
  GROUP BY 1
)
SELECT c.m, c.completed_orders, a.appsheet_orders,
       ROUND(100.0*a.appsheet_orders/c.completed_orders,1) AS appsheet_cov_pct,
       p.payout_batches, p.pay, t.orders_with_cost
FROM completed c
LEFT JOIN as_cov a ON a.m=c.m LEFT JOIN payout p ON p.m=c.m LEFT JOIN ptl_table t ON t.m=c.m
ORDER BY 1