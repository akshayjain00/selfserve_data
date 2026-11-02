WITH combined AS (
    SELECT * FROM prod_curated.partload_analytics.ptl_app_sheet_backfilled_data
    UNION ALL SELECT * FROM prod_curated.gsheet_sync."ptl_app_sheet_data"
),
deduped AS (SELECT * FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY reached_pickup_at DESC NULLS LAST) AS rn FROM combined) WHERE rn = 1),
lov AS (SELECT order_id, vehicle_registration_number FROM prod_curated.partload_application.order_vehicles
        WHERE is_active = TRUE QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY created_at DESC) = 1),
vm AS (SELECT vehicle_registration_number, mobile_number FROM prod_curated.gsheet_sync.ptl_vendor_vehicle_map),
owner_level AS (
    SELECT DATE_TRUNC('month', o.created_at + INTERVAL '330 mins')::DATE AS ct, vm.mobile_number AS owner_mobile,
        COUNT(DISTINCT CASE WHEN d.reached_pickup_at::timestamp IS NOT NULL THEN d.order_id END) AS base_pickup,
        COUNT(DISTINCT CASE WHEN d.reached_drop_at::timestamp IS NOT NULL THEN d.order_id END) AS base_drop,
        COUNT(DISTINCT CASE WHEN d.reached_pickup_at IS NOT NULL
             AND d.reached_pickup_at::timestamp <= (o.pickup_slot_end + INTERVAL '330 mins' + INTERVAL '1 hour') THEN d.order_id END)*1.0
          /NULLIF(COUNT(DISTINCT CASE WHEN d.reached_pickup_at::timestamp IS NOT NULL THEN d.order_id END),0) AS ontime_pickup,
        COUNT(DISTINCT CASE WHEN d.reached_drop_at IS NOT NULL
             AND d.reached_drop_at::timestamp <= (o.estimated_delivery_ts + INTERVAL '330 mins') THEN d.order_id END)*1.0
          /NULLIF(COUNT(DISTINCT CASE WHEN d.reached_drop_at::timestamp IS NOT NULL THEN d.order_id END),0) AS ontime_delivery,
        COUNT(DISTINCT CASE WHEN d.reached_pickup_at IS NOT NULL AND d.reached_drop_at IS NOT NULL
             AND d.reached_pickup_at::timestamp <= (o.pickup_slot_end + INTERVAL '330 mins' + INTERVAL '1 hour')
             AND d.reached_drop_at::timestamp <= (o.estimated_delivery_ts + INTERVAL '330 mins') THEN d.order_id END)*1.0
          /NULLIF(COUNT(DISTINCT CASE WHEN d.reached_drop_at::timestamp IS NOT NULL THEN d.order_id END),0) AS opod
    FROM deduped d
    INNER JOIN prod_curated.partload_application.orders o ON o.id = d.order_id AND o.state = '3'
    LEFT JOIN lov ov ON ov.order_id = o.id
    LEFT JOIN vm ON vm.vehicle_registration_number = ov.vehicle_registration_number
    WHERE d.order_id != '22041'
      AND DATE(o.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-01-01' AND DATE '2026-08-31'
    GROUP BY 1,2
)
SELECT ct,
  ROUND(100.0*AVG(CASE WHEN base_drop>0 THEN opod END),2) AS owner_sla_adherence_pct,
  ROUND(100.0*AVG(CASE WHEN base_pickup>0 THEN ontime_pickup END),2) AS owner_ontime_pickup_pct,
  ROUND(100.0*AVG(CASE WHEN base_drop>0 THEN ontime_delivery END),2) AS owner_ontime_delivery_pct
FROM owner_level GROUP BY 1 ORDER BY 1