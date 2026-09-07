WITH vendor_metrics AS (
    SELECT vendor_id,
        SUM(vendor_order_fare) AS vendor_total_earnings,
        COUNT(DISTINCT order_id) AS vendor_order_count
    FROM PROD_ELDORIA.MART.PNM_FARE_MOVEMENT
    WHERE order_status = 'completed'
      AND is_nano_order = 0
      AND service_type_bucket = 'intracity'
      AND DATE_TRUNC('month', DATE(order_updated_at_ist)) = '2026-05-01'
    GROUP BY 1
),
period_metrics AS (
    SELECT
        COUNT(DISTINCT order_id) AS total_order_count,
        COUNT(DISTINCT vendor_id) AS active_vendor_count
    FROM PROD_ELDORIA.MART.PNM_FARE_MOVEMENT
    WHERE order_status = 'completed'
      AND is_nano_order = 0
      AND service_type_bucket = 'intracity'
      AND DATE_TRUNC('month', DATE(order_updated_at_ist)) = '2026-05-01'
)
SELECT
    DATE '2026-05-01' AS month,
    pm.active_vendor_count,
    pm.total_order_count,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY vm.vendor_total_earnings), 2) AS p50_earnings_per_vendor,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY vm.vendor_total_earnings), 2) AS p80_earnings_per_vendor,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY vm.vendor_order_count), 2) AS p50_orders_per_vendor,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY vm.vendor_order_count), 2) AS p80_orders_per_vendor
FROM vendor_metrics vm
CROSS JOIN period_metrics pm
GROUP BY pm.active_vendor_count, pm.total_order_count