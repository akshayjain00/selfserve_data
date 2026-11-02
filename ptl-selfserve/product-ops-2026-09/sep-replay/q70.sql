WITH clubbing AS (
  SELECT CAST(DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS m,
         BATCHED_ORDERS_V1.ORDER_EXTERNAL_ID, batch_id
  FROM PROD_CURATED.PARTLOAD_APPLICATION.BATCHED_ORDERS_V1
  LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDERS ON BATCHED_ORDERS_V1.ORDER_EXTERNAL_ID = ORDERS.external_id
  LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS piu ON piu.mobile = ORDERS.customer_mobile
  WHERE status = 3 AND piu.mobile IS NULL
    AND orders.created_at >= DATE '2026-06-01' - INTERVAL '330 MINS'
    AND orders.created_at <= DATE '2026-09-30' - INTERVAL '330 MINS' + INTERVAL '1 day'
),
aov AS (
  SELECT date_trunc('month', date(updated_at + INTERVAL '330 mins'))::DATE AS m,
         ROUND(SUM(estimated_fare/100)/COUNT(DISTINCT id),0) AS aov
  FROM prod_curated.partload_application.orders
  WHERE date(updated_at + INTERVAL '330 mins') BETWEEN DATE '2026-06-01' AND DATE '2026-09-30' AND state='3'
    AND customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
  GROUP BY 1
),
fv AS (SELECT * FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY created_at ASC) rn
                      FROM prod_curated.partload_application.order_vehicles) WHERE rn=1),
alloc AS (
  SELECT DATE_TRUNC('month', o.created_at + INTERVAL '330 mins')::DATE AS m,
     CASE WHEN DATE(o.created_at + INTERVAL '330 mins') = DATE(o.pickup_slot_end + INTERVAL '330 minutes')
            THEN NULLIF(DATEDIFF('second', o.created_at + INTERVAL '330 mins', fv.created_at + INTERVAL '330 mins'),0)/60.0
          WHEN DATE(o.created_at + INTERVAL '330 mins') < DATE(o.pickup_slot_end + INTERVAL '330 minutes')
            THEN NULLIF(DATEDIFF('second', CAST(CONCAT(TO_DATE(fv.created_at + INTERVAL '330 mins'),' ','08:00:00') AS TIMESTAMP_NTZ), fv.created_at + INTERVAL '330 mins'),0)/60.0
     END AS alloc_min
  FROM prod_curated.partload_application.orders o
  LEFT JOIN fv ON fv.order_id = o.id
  WHERE o.state = 3 AND o.customer_mobile NOT IN (SELECT MOBILE FROM prod_curated.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)
    AND DATE(o.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-06-01' AND DATE '2026-09-30'
),
mav AS (
  SELECT DATE_TRUNC('month', ov.created_at + INTERVAL '330 mins')::DATE AS m,
         COUNT(DISTINCT ov.vehicle_registration_number) AS mav
  FROM prod_curated.partload_application.order_vehicles ov
  LEFT JOIN prod_curated.partload_application.orders o ON o.external_id = ov.order_external_id
  LEFT JOIN prod_curated.partload_analytics.ptl_internal_users iu ON iu.mobile = o.customer_mobile
  WHERE ov.vehicle_registration_number IS NOT NULL AND ov.is_active = TRUE AND iu.mobile IS NULL
    AND DATE(ov.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-06-01' AND DATE '2026-09-30'
  GROUP BY 1
)
SELECT c.m,
  ROUND(COUNT(DISTINCT c.ORDER_EXTERNAL_ID)/NULLIF(COUNT(DISTINCT c.batch_id),0),3) AS orders_per_trip,
  MAX(a.aov) AS aov,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY al.alloc_min),2) AS p50_alloc,
  MAX(v.mav) AS monthly_active_vehicles
FROM clubbing c
LEFT JOIN aov a ON a.m = c.m
LEFT JOIN mav v ON v.m = c.m
LEFT JOIN alloc al ON al.m = c.m
GROUP BY c.m ORDER BY c.m