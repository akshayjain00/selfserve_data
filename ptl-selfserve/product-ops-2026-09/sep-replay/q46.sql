WITH latest_ops_declared AS (
  SELECT order_id, WD_Kg, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY WD_marked_ts DESC) AS rn
  FROM prod_eldoria.core.FACT_PTL_WD_LOGS
),
latest_ops AS (SELECT order_id, WD_Kg AS latest_ops_wd FROM latest_ops_declared WHERE rn = 1),
all_orders AS (
  SELECT CAST(DATE_TRUNC('month', fo.created_at) AS DATE) AS dated, fo.order_id, latest_ops.latest_ops_wd AS wd
  FROM prod_eldoria.core.FACT_PTL_WD_LOGS fwd
  INNER JOIN prod_eldoria.core.FACT_PTL_ORDERS fo ON fwd.order_id = fo.order_id
  LEFT JOIN latest_ops ON latest_ops.order_id = fo.order_id
  WHERE fo.status = 3 AND fo.created_at >= DATE '2026-01-01' AND fo.created_at <= DATE '2026-09-30' + INTERVAL '1 day'
  GROUP BY dated, fo.order_id, wd
),
total_orders_by_date AS (
  SELECT CAST(DATE_TRUNC('month', fo.created_at) AS DATE) AS dated, COUNT(DISTINCT fo.order_id) AS total_orders
  FROM prod_eldoria.core.FACT_PTL_ORDERS fo
  WHERE fo.created_at >= DATE '2026-01-01' AND fo.created_at < DATE '2026-09-30' + INTERVAL '1 day' AND fo.status = 3
  GROUP BY 1
),
agg_all_orders AS (
  SELECT dated, COUNT(DISTINCT CASE WHEN wd > 25 THEN order_id END) AS orders_gt_25 FROM all_orders GROUP BY 1
)
SELECT a.dated, a.orders_gt_25, t.total_orders,
       ROUND(100.0*a.orders_gt_25/NULLIF(t.total_orders,0),2) AS wd_order_pct
FROM agg_all_orders a JOIN total_orders_by_date t ON a.dated = t.dated ORDER BY a.dated