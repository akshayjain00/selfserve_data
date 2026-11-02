WITH base AS (
    SELECT o.id AS order_id, o.state,
        (o.created_at + INTERVAL '5 hours, 30 mins')::DATE AS order_date,
        ov.vehicle_name,
        CASE WHEN DATEDIFF(SECOND, o.created_at + INTERVAL '5 hours, 30 mins', cr.created_at + INTERVAL '330 mins') <= 60
             THEN o.id END AS within_1_cancel
    FROM prod_curated.partload_application.orders o
    LEFT JOIN prod_curated.partload_application.order_cancellation_reasons cr ON cr.order_id = o.id
    LEFT JOIN prod_curated.partload_application.order_vehicles ov ON o.id = ov.order_id AND ov.is_active
    WHERE o.created_at + INTERVAL '330 mins' >= DATE '2026-01-01'
      AND o.created_at + INTERVAL '330 mins' <  DATE '2026-10-01'
      AND o.customer_mobile NOT IN (SELECT DISTINCT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
)
SELECT date_trunc('month', order_date)::DATE AS order_month,
    COUNT(DISTINCT order_id) AS placed_orders,
    ROUND(100.0*COUNT(DISTINCT CASE WHEN state=4 THEN order_id END)/COUNT(DISTINCT order_id),2) AS cancelled_pct,
    ROUND(100.0*COUNT(DISTINCT CASE WHEN vehicle_name IS NULL AND state=4 THEN order_id END)/COUNT(DISTINCT order_id),2) AS cbdf_no_excl,
    ROUND(100.0*COUNT(DISTINCT CASE WHEN vehicle_name IS NOT NULL AND state=4 THEN order_id END)/COUNT(DISTINCT order_id),2) AS cadf_no_excl,
    ROUND(100.0*COUNT(DISTINCT CASE WHEN vehicle_name IS NULL AND state=4 AND within_1_cancel IS NULL THEN order_id END)/COUNT(DISTINCT order_id),2) AS cbdf_excl_60s,
    ROUND(100.0*COUNT(DISTINCT CASE WHEN vehicle_name IS NOT NULL AND state=4 AND within_1_cancel IS NULL THEN order_id END)/COUNT(DISTINCT order_id),2) AS cadf_excl_60s
FROM base GROUP BY 1 ORDER BY 1