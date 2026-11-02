WITH online AS (
  SELECT CAST(DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
         orders.created_at, orders.state, orders.external_id, orders.id AS oid, ocr.created_at AS ocr_created_at,
         ov.vehicle_name
  FROM PROD_CURATED.PARTLOAD_APPLICATION.orders
  LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS ON PTL_INTERNAL_USERS.mobile = orders.customer_mobile
  LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDER_CANCELLATION_REASONS ocr ON orders.id = ocr.order_id
  LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES ov ON orders.id = ov.order_id AND ov.is_active
  WHERE CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(orders.created_at))
        BETWEEN DATE '2026-06-01' AND DATE '2026-09-30' + INTERVAL '1 day'
    AND PTL_INTERNAL_USERS.mobile IS NULL
)
SELECT dated,
  COUNT(DISTINCT external_id) AS placed,
  COUNT(DISTINCT CASE WHEN state=3 THEN external_id END) AS completed,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN state=3 THEN external_id END)/NULLIF(COUNT(DISTINCT external_id),0),2) AS ff_pct,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN state=3 THEN external_id END)
    / NULLIF(COUNT(DISTINCT external_id) - COUNT(DISTINCT CASE WHEN DATEDIFF(SECOND, created_at, ocr_created_at) <= 60 THEN external_id END),0),2) AS ff_excl60s_pct,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN vehicle_name IS NULL AND state=4 THEN oid END)/COUNT(DISTINCT oid),2) AS cbdf_pct,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN vehicle_name IS NOT NULL AND state=4 THEN oid END)/COUNT(DISTINCT oid),2) AS cadf_pct
FROM online GROUP BY 1 ORDER BY 1