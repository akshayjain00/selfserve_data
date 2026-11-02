WITH lod AS (SELECT order_id, WD_Kg, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY WD_marked_ts DESC) rn FROM prod_eldoria.core.FACT_PTL_WD_LOGS),
lo AS (SELECT order_id, WD_Kg AS wd FROM lod WHERE rn=1),
all_orders AS (
  SELECT CAST(DATE_TRUNC('month', fo.created_at) AS DATE) AS dated, fo.order_id, lo.wd
  FROM prod_eldoria.core.FACT_PTL_WD_LOGS fwd
  INNER JOIN prod_eldoria.core.FACT_PTL_ORDERS fo ON fwd.order_id = fo.order_id
  LEFT JOIN lo ON lo.order_id = fo.order_id
  WHERE fo.status = 3 AND fo.created_at >= DATE '2026-06-01' AND fo.created_at <= DATE '2026-09-30' + INTERVAL '1 day'
  GROUP BY 1,2,3),
tot AS (SELECT CAST(DATE_TRUNC('month', fo.created_at) AS DATE) AS dated, COUNT(DISTINCT fo.order_id) AS total_orders
  FROM prod_eldoria.core.FACT_PTL_ORDERS fo
  WHERE fo.created_at >= DATE '2026-06-01' AND fo.created_at < DATE '2026-09-30' + INTERVAL '1 day' AND fo.status = 3 GROUP BY 1),
agg AS (SELECT dated, COUNT(DISTINCT CASE WHEN wd > 25 THEN order_id END) AS gt25 FROM all_orders GROUP BY 1)
SELECT a.dated, a.gt25, t.total_orders, ROUND(100.0*a.gt25/NULLIF(t.total_orders,0),2) AS wd_pct
FROM agg a JOIN tot t ON a.dated=t.dated ORDER BY 1