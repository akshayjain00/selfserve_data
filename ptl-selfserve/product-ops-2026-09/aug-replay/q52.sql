WITH wd_fare AS (
  SELECT order_id, total_fare/100.0 AS total_fare
  FROM prod_curated.partload_application.order_fares of_
  INNER JOIN prod_curated.partload_application.fare_revision_notified nf
    ON nf.order_fare_id = of_.id AND nf.IS_CUSTOMER_NOTIFIED = 'true'
  WHERE is_current_fare = 'true'
),
vehicle_cost AS (
  SELECT REPLACE(g.TOTAL_VENDOR_PAYOUT, ',', '') AS trip_cost, o.external_id
  FROM prod_curated.partload_application.order_vehicles
  LEFT JOIN prod_curated.partload_application.orders o ON o.id = order_vehicles.order_id
  LEFT JOIN prod_curated.gsheet_sync.PTL_TABLE g ON o.id = g.order_id
  WHERE is_active = 'True' AND o.state = '3'
    AND o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
),
online AS (
  SELECT o.external_id, o.state,
     COALESCE(wd_fare.total_fare, o.estimated_fare/100.0) AS final_fare,
     CAST(DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(o.created_at))) AS DATE) AS dated,
     BATCHED_ORDERS_V1.batch_id, vc.trip_cost
  FROM prod_curated.partload_application.orders o
  LEFT JOIN wd_fare ON wd_fare.order_id = o.id
  LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.BATCHED_ORDERS_V1
       ON BATCHED_ORDERS_V1.order_external_id = o.external_id AND BATCHED_ORDERS_V1.status = '3'
  LEFT JOIN vehicle_cost vc ON vc.external_id = o.EXTERNAL_ID
  WHERE o.state = 3
    AND o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
    AND o.created_at >= DATE '2026-01-01' - INTERVAL '330 MINS'
    AND o.created_at <= DATE '2026-08-31' - INTERVAL '330 MINS' + INTERVAL '1 day'
),
final AS (SELECT DISTINCT external_id, state, final_fare, dated, batch_id, trip_cost FROM online),
agg_metrics AS (
    SELECT dated, SUM(final_fare) AS total_revenue,
           SUM(final_fare)/COUNT(DISTINCT CASE WHEN state=3 THEN external_id END) AS aov
    FROM final GROUP BY dated
),
vendor_costs AS (SELECT dated, batch_id, MAX(trip_cost) AS vendor_earning FROM final GROUP BY dated, batch_id),
final_vendor_costs AS (SELECT dated, SUM(vendor_earning) AS total_cost FROM vendor_costs GROUP BY dated)
SELECT a.dated, ROUND(a.aov,0) AS aov, ROUND(a.total_revenue,0) AS total_revenue,
       ROUND(f.total_cost,0) AS total_cost,
       ROUND(100.0*(a.total_revenue - f.total_cost)/NULLIF(a.total_revenue,0),2) AS gm_pct
FROM agg_metrics a LEFT JOIN final_vendor_costs f ON a.dated = f.dated ORDER BY a.dated