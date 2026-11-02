WITH online AS (
  SELECT CAST(DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
         orders.created_at, orders.state, orders.external_id, ocr.created_at AS ocr_created_at
  FROM PROD_CURATED.PARTLOAD_APPLICATION.orders
  LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS ON PTL_INTERNAL_USERS.mobile = orders.customer_mobile
  LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDER_CANCELLATION_REASONS ocr ON orders.id = ocr.order_id
  WHERE CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(orders.created_at))
        BETWEEN DATE '2026-01-01' AND DATE '2026-08-31' + INTERVAL '1 day'
    AND CASE WHEN PTL_INTERNAL_USERS.mobile IS NULL THEN 'False' ELSE 'True' END = 'False'
),
offline AS (
  SELECT CAST(DATE_TRUNC('month', created_at::date) AS DATE) AS dated,
         created_at, state, external_id, NULL AS ocr_created_at
  FROM prod_curated.gsheet_sync.ptl_offline_orders
  WHERE created_at::date BETWEEN DATE '2026-01-01' AND DATE '2026-08-31'
),
final AS (SELECT * FROM online UNION ALL SELECT * FROM offline)
SELECT dated,
  COUNT(DISTINCT external_id) AS placed,
  COUNT(DISTINCT CASE WHEN state=3 THEN external_id END) AS completed,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN state=3 THEN external_id END)/NULLIF(COUNT(DISTINCT external_id),0),2) AS ff_pct,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN state=3 THEN external_id END)
    / NULLIF(COUNT(DISTINCT external_id) - COUNT(DISTINCT CASE WHEN DATEDIFF(SECOND, created_at, ocr_created_at) <= 60 THEN external_id END),0),2) AS ff_excl_60s_pct,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN state=4 THEN external_id END)/NULLIF(COUNT(DISTINCT external_id),0),2) AS cancellation_pct
FROM final GROUP BY 1 ORDER BY 1