WITH combined AS (
    SELECT * FROM prod_curated.partload_analytics.ptl_app_sheet_backfilled_data
    UNION ALL SELECT * FROM prod_curated.gsheet_sync."ptl_app_sheet_data"
),
deduped AS (SELECT * FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY reached_pickup_at DESC NULLS LAST) AS rn FROM combined) WHERE rn = 1),
latest_order_vehicle AS (
    SELECT order_id, vehicle_registration_number FROM prod_curated.partload_application.order_vehicles
    WHERE is_active = TRUE QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY created_at DESC) = 1
),
latest_vendor_map AS (SELECT vehicle_registration_number, vendor_name, mobile_number FROM prod_curated.gsheet_sync.ptl_vendor_vehicle_map),
owner_level AS (
    SELECT DATE_TRUNC('month', o.created_at + INTERVAL '330 mins')::DATE AS ct,
        vm.mobile_number AS owner_mobile, vm.vendor_name AS owner_name,
        COUNT(DISTINCT CASE WHEN d.reached_drop_at::timestamp IS NOT NULL THEN d.order_id END) AS total_orders_drop,
        COUNT(DISTINCT CASE WHEN d.reached_drop_at IS NOT NULL
             AND d.reached_drop_at::timestamp <= (o.estimated_delivery_ts + INTERVAL '330 mins') THEN d.order_id END) * 1.0
        / NULLIF(COUNT(DISTINCT CASE WHEN d.reached_drop_at::timestamp IS NOT NULL THEN d.order_id END),0) AS owner_ontime_delivery_pct
    FROM deduped d
    INNER JOIN prod_curated.partload_application.orders o ON o.id = d.order_id AND o.state = '3'
    LEFT JOIN latest_order_vehicle ov ON ov.order_id = o.id
    LEFT JOIN latest_vendor_map vm ON vm.vehicle_registration_number = ov.vehicle_registration_number
    WHERE d.order_id != '22041'
      AND DATE(o.created_at + INTERVAL '330 mins') >= DATE '2026-01-01'
      AND DATE(o.created_at + INTERVAL '330 mins') <= DATE '2026-09-30'
    GROUP BY 1,2,3
)
SELECT ct, ROUND(100.0*AVG(owner_ontime_delivery_pct),2) AS avg_owner_ontime_delivery_pct
FROM owner_level WHERE total_orders_drop > 0 GROUP BY 1 ORDER BY 1