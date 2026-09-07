WITH fare_metrics AS (
    SELECT
        MAX(total_orders) AS total_orders,
        MAX(aov) AS aov,
        MAX(no_of_orders_with_surge) AS no_of_orders_with_surge,
        MAX(pct_orders_with_surge) AS pct_orders_with_surge,
        MAX(pct_orders_positive_surge) AS pct_orders_positive_surge,
        MAX(pct_orders_negative_surge) AS pct_orders_negative_surge,
        MAX(pct_orders_with_coupon) AS pct_orders_with_coupon,
        MAX(orders_with_shifting_started) AS orders_with_shifting_started,
        MAX(pct_cases_with_price_change_post_shifting_start) AS pct_cases_with_price_change_post_shifting_start,
        MAX(pct_orders_fare_increased) AS pct_orders_fare_increased,
        MAX(median_fare_increase_amt) AS median_fare_increase_amt,
        MAX(pct_orders_fare_decreased) AS pct_orders_fare_decreased,
        MAX(median_fare_decrease_amt) AS median_fare_decrease_amt,
        MAX(pct_edited_orders_with_fare_change) AS pct_edited_orders_with_fare_change
    FROM (
        SELECT
            COUNT(DISTINCT order_id) AS total_orders,
            NULL::FLOAT AS aov,
            COUNT(DISTINCT CASE WHEN booking_surge_multiplier <> 1 AND booking_surge_multiplier IS NOT NULL THEN order_id END) AS no_of_orders_with_surge,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN booking_surge_multiplier <> 1 AND booking_surge_multiplier IS NOT NULL THEN order_id END) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS pct_orders_with_surge,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN booking_surge_multiplier > 1 THEN order_id END) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS pct_orders_positive_surge,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN booking_surge_multiplier < 1 THEN order_id END) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS pct_orders_negative_surge,
            NULL::FLOAT AS pct_orders_with_coupon,
            COUNT(DISTINCT CASE WHEN shifting_started_ts_ist IS NOT NULL THEN order_id END) AS orders_with_shifting_started,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN fare_delta <> 0 THEN order_id END) / NULLIF(COUNT(DISTINCT CASE WHEN shifting_started_ts_ist IS NOT NULL THEN order_id END), 0), 2) AS pct_cases_with_price_change_post_shifting_start,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN fare_delta > 0 THEN order_id END) / NULLIF(COUNT(DISTINCT CASE WHEN shifting_started_ts_ist IS NOT NULL THEN order_id END), 0), 2) AS pct_orders_fare_increased,
            ROUND(MEDIAN(CASE WHEN fare_delta > 0 THEN fare_delta END), 0) AS median_fare_increase_amt,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN fare_delta < 0 THEN order_id END) / NULLIF(COUNT(DISTINCT CASE WHEN shifting_started_ts_ist IS NOT NULL THEN order_id END), 0), 2) AS pct_orders_fare_decreased,
            ROUND(MEDIAN(CASE WHEN fare_delta < 0 THEN ABS(fare_delta) END), 0) AS median_fare_decrease_amt,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_edited_post_start = 1 AND fare_delta <> 0 THEN order_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_edited_post_start = 1 THEN order_id END), 0), 2) AS pct_edited_orders_with_fare_change
        FROM PROD_ELDORIA.MART.PNM_FARE_MOVEMENT
        WHERE order_created_month = '2026-05-01'
          AND service_type_bucket = 'intracity'

        UNION ALL

        SELECT
            NULL::NUMBER AS total_orders,
            ROUND(SUM(CASE WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%' AND is_test_user = 0 THEN total_order_fare END) / NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%' AND is_test_user = 0 THEN order_id END), 0), 0) AS aov,
            NULL::NUMBER AS no_of_orders_with_surge,
            NULL::FLOAT AS pct_orders_with_surge,
            NULL::FLOAT AS pct_orders_positive_surge,
            NULL::FLOAT AS pct_orders_negative_surge,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT IN ('Nano Shifting','Nano Shifting Large','Nano Shifting Medium') AND discount_coupon IS NOT NULL AND discount_coupon != '' THEN order_id END) / NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT IN ('Nano Shifting','Nano Shifting Large','Nano Shifting Medium') THEN order_id END), 0), 2) AS pct_orders_with_coupon,
            NULL::NUMBER AS orders_with_shifting_started,
            NULL::FLOAT AS pct_cases_with_price_change_post_shifting_start,
            NULL::FLOAT AS pct_orders_fare_increased,
            NULL::FLOAT AS median_fare_increase_amt,
            NULL::FLOAT AS pct_orders_fare_decreased,
            NULL::FLOAT AS median_fare_decrease_amt,
            NULL::FLOAT AS pct_edited_orders_with_fare_change
        FROM PROD_ELDORIA.MART.PNM_FARE_MOVEMENT
        WHERE DATE_TRUNC('month', DATE(order_updated_at_ist)) = '2026-05-01'
          AND service_type_bucket = 'intracity'
    )
)
SELECT DATE '2026-05-01' AS month, * FROM fare_metrics