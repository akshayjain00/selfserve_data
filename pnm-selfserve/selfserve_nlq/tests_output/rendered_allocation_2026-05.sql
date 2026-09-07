SELECT
    DATE '2026-05-01' AS month,
    COUNT(DISTINCT order_id) AS alloc_total_orders,
    COUNT(DISTINCT CASE WHEN is_allocated = 1 THEN order_id END) AS allocated_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_allocated = 1 THEN order_id END)
        / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS allocation_pct,
    COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' THEN order_id END) AS total_spot_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' AND is_allocated = 1 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' THEN order_id END), 0), 2) AS allocation_pct_spot,
    COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' THEN order_id END) AS total_scheduled_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' AND is_allocated = 1 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' THEN order_id END), 0), 2) AS allocation_pct_scheduled,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN allocation_channel = 'Engine' AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN allocation_channel IN ('Engine', 'Open Pool') AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS allocation_share_via_engine_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN allocation_channel = 'Open Pool' AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN allocation_channel IN ('Engine', 'Open Pool') AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS allocation_share_via_open_pool_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_deallocated_post_accept = 1 THEN order_id END)
        / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS deallocation_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_deallocated_post_accept = 1 AND order_bucket = 'SPOT' THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' THEN order_id END), 0), 2) AS deallocation_pct_spot,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_deallocated_post_accept = 1 AND order_bucket = 'SCHEDULED' THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' THEN order_id END), 0), 2) AS deallocation_pct_scheduled,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS completion_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS completion_pct_spot,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' AND order_bucket = 'SCHEDULED'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS completion_pct_scheduled,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (
        ORDER BY CASE WHEN order_bucket = 'SPOT' AND is_nano_order = 0 AND is_test_user = 0
            AND dry_run_distance_kms IS NOT NULL THEN dry_run_distance_kms END
    ), 2) AS dry_run_p75_kms_spot,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cancellation_type = 'CAC' AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS cac_pct_spot,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cancellation_type = 'PAC' AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS pac_pct_spot,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cancellation_type = 'PoAC' AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS poac_pct_spot,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cancellation_type = 'CAC' AND order_bucket = 'SCHEDULED'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS cac_pct_scheduled,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cancellation_type = 'PAC' AND order_bucket = 'SCHEDULED'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS pac_pct_scheduled,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cancellation_type = 'PoAC' AND order_bucket = 'SCHEDULED'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS poac_pct_scheduled,
    ROUND(PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY CASE WHEN is_allocated = 1 AND allocation_tat_minutes IS NOT NULL THEN allocation_tat_minutes END
    ), 2) AS allocation_time_p80_minutes,
    ROUND(PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY CASE WHEN is_allocated = 1 AND order_bucket = 'SPOT' AND allocation_tat_minutes IS NOT NULL THEN allocation_tat_minutes END
    ), 2) AS allocation_time_p80_spot_minutes,
    ROUND(PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY CASE WHEN is_allocated = 1 AND allocation_tat_minutes IS NOT NULL
            AND datediff('day', order_created_ts_ist, shifting_ts_ist) <= 2 THEN allocation_tat_minutes END
    ), 2) AS allocation_time_p80_within_2days_minutes,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN no_vendor_before_slot = 1 THEN order_id END)
        / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS pct_no_vendor_before_slot,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_supervisor_changed = 1 AND order_status = 'completed'
        AND package_name NOT IN ('Nano Shifting', 'Nano Shifting Large', 'Nano Shifting Medium') AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed'
        AND package_name NOT IN ('Nano Shifting', 'Nano Shifting Large', 'Nano Shifting Medium') AND is_test_user = 0 THEN order_id END), 0), 2) AS pct_supervisor_changed,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_supervisor_changed_post_trip = 1 AND order_status = 'completed'
        AND package_name NOT IN ('Nano Shifting', 'Nano Shifting Large', 'Nano Shifting Medium') AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed'
        AND package_name NOT IN ('Nano Shifting', 'Nano Shifting Large', 'Nano Shifting Medium') AND is_test_user = 0 THEN order_id END), 0), 2) AS pct_supervisor_changed_post_trip,
    ROUND(PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY CASE WHEN order_status = 'completed' AND is_nano_order = 0 AND is_test_user = 0
            AND pickup_km_deviation IS NOT NULL THEN pickup_km_deviation END
    ), 2) AS p80_pickup_km_deviation,
    ROUND(PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY CASE WHEN order_status = 'completed' AND is_nano_order = 0 AND is_test_user = 0
            AND drop_km_deviation IS NOT NULL THEN drop_km_deviation END
    ), 2) AS p80_drop_km_deviation,
    COUNT(DISTINCT CASE WHEN deallocation_count > 2 THEN order_id END) AS orders_with_more_than_2_deallocations,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN deallocation_count > 2 THEN order_id END)
        / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS pct_orders_with_more_than_2_deallocations,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN last_rescheduled_shift_ts IS NOT NULL
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS reschedule_pct
FROM PROD_ELDORIA.MART.PNM_ALLOCATION
WHERE DATE_TRUNC('month', shifting_ts_ist) = '2026-05-01'
  AND shifting_type = 'intra_city'