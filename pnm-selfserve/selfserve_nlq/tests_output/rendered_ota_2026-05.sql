WITH orders AS (
    SELECT fpo.order_id, fpo.shifting_ts, fpo.o_completed_ts,
           dpo.package_name, dpo.order_status, dpo.sr_id
    FROM PROD_ELDORIA.CORE.FACT_PNM_ORDERS fpo
    LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_ORDERS dpo ON dpo.order_id = fpo.order_id
    WHERE DATE_TRUNC('month', fpo.o_completed_ts) = '2026-05-01'
      AND dpo.shifting_type = 'intra_city'
),
pickup_loc AS (
    SELECT sr_id, location AS pickup_location
    FROM PROD_ELDORIA.RAW.PNM_APPLICATION_SR_LOCATION_DETAILS
    WHERE location_type = 0
    QUALIFY ROW_NUMBER() OVER (PARTITION BY sr_id ORDER BY id DESC) = 1
),
ts AS (
    SELECT sa.order_id, sa.event_ts_ist AS event_ts, sa.location AS event_location,
           RANK() OVER (PARTITION BY sa.order_id, sa.action ORDER BY sa.event_ts_ist DESC) AS rk
    FROM PROD_ELDORIA.RAW.PNM_APPLICATION_SUPERVISOR_ACTIONS sa
    WHERE sa.action = 'ShiftingStarted'
),
dump AS (
    SELECT o.*, pl.pickup_location, ts.event_ts, ts.event_location
    FROM orders o
    LEFT JOIN pickup_loc pl ON o.sr_id = pl.sr_id
    LEFT JOIN ts ON o.order_id = ts.order_id AND ts.rk = 1
),
ota_calc AS (
    SELECT dump.*,
           DATEDIFF(SECONDS, shifting_ts, event_ts) / 60.0 AS delay_minutes,
           CASE
               WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%'
                    AND event_ts IS NOT NULL
                    AND DATEDIFF(SECONDS, shifting_ts, event_ts) / 60 < 30
                    AND ST_DISTANCE(pickup_location, event_location) / 1000 < 2
               THEN 'On_Time'
               WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%'
                    AND event_ts IS NULL
               THEN 'Unset'
               ELSE 'Delay'
           END AS group_type
    FROM dump
)
SELECT
    DATE '2026-05-01' AS month,
    COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%'
               THEN order_id END)                                                            AS ota_total_completed_orders,
    COUNT(DISTINCT CASE WHEN group_type = 'On_Time' THEN order_id END)                        AS ota_on_time_orders,
    COUNT(DISTINCT CASE WHEN group_type = 'Unset'   THEN order_id END)                        AS ota_unset_orders,
    COUNT(DISTINCT CASE WHEN group_type = 'Delay' AND order_status = 'completed'
               AND package_name NOT ILIKE 'Nano%' THEN order_id END)                          AS ota_delay_orders,
    COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%'
               AND delay_minutes >= 60 THEN order_id END)                                     AS ota_delay_gt_60_mins_orders,
    ROUND(COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%'
               AND delay_minutes >= 60 THEN order_id END) /
        NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%'
               THEN order_id END), 0), 3)                                                     AS ota_delay_gt_60_mins_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN group_type = 'On_Time' THEN order_id END) /
        NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%'
               THEN order_id END), 0), 2)                                                     AS ota_pct
FROM ota_calc