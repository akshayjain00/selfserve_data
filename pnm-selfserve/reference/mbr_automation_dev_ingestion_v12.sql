-- =====================================================================
-- PnM MBR Monthly Metrics — DEV ingestion (manual run, updated)
-- Mirrors queries.py / METRIC_SECTIONS in the pnm_mbr_monthly_metrics
-- automation package exactly — same sources, same fixes, same metric names.
-- Run this manually into DEV until prod write access is granted and
-- runner.py can do this on its own (same script, same logic, DEST switched
-- via .env at that point — this file will no longer be needed then).
--
-- Sources: PROD_ELDORIA.MART.PNM_FARE_MOVEMENT (fare/coupon/surge, vendor)
--          PROD_ELDORIA.MART.PNM_ALLOCATION (allocation quality)
--          PROD_CURATED.PNM_APPLICATION.VENDOR_WALLET_WITHDRAWAL / PAYMENT_LINKS
--            (wallet withdrawal / recharge, joined via VENDOR_OWNERS)
--          prod_eldoria.raw.pnm_application_orders / ..._order_allocation_infos /
--            ..._shifting_requirements / sfms_public_hs_tickets
--            (vendor TPO / top-5-issues breakdown)
--          PROD_ELDORIA.MART.PNM_EXPERIENCE (trip duration percentiles,
--            edit/modification adoption)
--          PROD_CURATED.PNM_APPLICATION.ORDERS / ORDER_ALLOCATION_INFOS /
--            SHIFTING_REQUIREMENTS and PROD_CURATED.SFMS_PUBLIC.HS_TICKETS
--            (TPO Trend, card #47576 — separate pipeline from the vendor
--            TPO / top-5-issues breakdown above)
--          PROD_ELDORIA.MART.PNM_EXPERIENCE (add-on adoption — deliberately
--            NOT filtered to completed/non-nano orders, unlike every other
--            section on this table)
--          PROD_ELDORIA.MART.PNM_EXPERIENCE (completion score / NPS / detractors)
--          PROD_ELDORIA.MART.PNM_EXPERIENCE / PROD_ELDORIA.CORE.FACT_PNM_ORDERS
--            (weekend order contribution — replaced 2026-07-15, previously
--            PROD_CURATED.PNM_APPLICATION.ORDERS / ORDER_ALLOCATION_INFOS /
--            SHIFTING_REQUIREMENTS)
--          PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY / DIM_PNM_OPPORTUNITY /
--            FACT_PNM_ORDERS / DIM_PNM_ORDERS and PROD_ELDORIA.MART.PNM_CUSTOMERS
--            (leads / orders / conversion by source)
--          PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES / OPPORTUNITIES_LATEST_LSM_SCORE
--            (Get a Call CTR)
--          PROD_ELDORIA.MART.PNM_EXPERIENCE / PROD_CURATED.PNM_APPLICATION.CANCELLED_ORDER_EVENTS
--            (CAC post trip started)
--          PROD_ELDORIA.MART.PNM_EXPERIENCE (vendor earnings distribution by
--            bucket — 1 metric decomposed into 5, one per vendor bucket)
-- Target:  DEV_ELDORIA.MART.PNM_MBR_MONTHLY_METRICS
-- Structure: month (DATE), metric (VARCHAR), value (FLOAT)
-- Scope: intracity / intra_city, Oct 2025 onwards (open-ended), 129 metrics
--
-- Provenance note (added 2026-09-04, PNM-G-003/PNM-G-006/PNM-G-071):
-- supplied in-session by the KB owner as the actual pnm_mbr_monthly_metrics
-- automation logic, previously citable only as `local:` (out-of-repo, no
-- SHA, per CONTRIBUTING §4.1). Committing this file gives it a real
-- `repo@<sha>` citation for the first time. This is a snapshot as supplied
-- (v12 draft) — it is NOT executed by this catalog and NOT run against any
-- warehouse from this repo; it documents what the automation computes.
-- =====================================================================

CREATE OR REPLACE TABLE DEV_ELDORIA.MART.PNM_MBR_MONTHLY_METRICS AS

WITH fare_metrics AS (
  SELECT period, service_type_bucket,
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
    SELECT order_created_month AS period, service_type_bucket,
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
    WHERE order_created_date >= '2025-10-01'
      AND service_type_bucket = 'intracity'
    GROUP BY 1, 2

    UNION ALL

    SELECT DATE_TRUNC('month', DATE(order_updated_at_ist)) AS period, service_type_bucket,
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
    WHERE DATE_TRUNC('month', DATE(order_updated_at_ist)) >= '2025-10-01'
      AND service_type_bucket = 'intracity'
    GROUP BY 1, 2
  )
  GROUP BY 1, 2
),

vendor_metrics_calc AS (
  WITH vendor_metrics AS (
    SELECT DATE_TRUNC('month', DATE(order_updated_at_ist)) AS period_start, vendor_id,
      SUM(vendor_order_fare) AS vendor_total_earnings,
      COUNT(DISTINCT order_id) AS vendor_order_count
    FROM PROD_ELDORIA.MART.PNM_FARE_MOVEMENT
    WHERE order_status = 'completed'
      AND is_nano_order = 0
      AND service_type_bucket = 'intracity'
      AND DATE_TRUNC('month', DATE(order_updated_at_ist)) >= '2025-10-01'
    GROUP BY 1, 2
  ),
  period_metrics AS (
    SELECT DATE_TRUNC('month', DATE(order_updated_at_ist)) AS period_start,
      COUNT(DISTINCT order_id) AS total_order_count,
      COUNT(DISTINCT vendor_id) AS active_vendor_count
    FROM PROD_ELDORIA.MART.PNM_FARE_MOVEMENT
    WHERE order_status = 'completed'
      AND is_nano_order = 0
      AND service_type_bucket = 'intracity'
      AND DATE_TRUNC('month', DATE(order_updated_at_ist)) >= '2025-10-01'
    GROUP BY 1
  )
  SELECT vm.period_start, pm.active_vendor_count, pm.total_order_count,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY vm.vendor_total_earnings), 2) AS p50_earnings_per_vendor,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY vm.vendor_total_earnings), 2) AS p80_earnings_per_vendor,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY vm.vendor_order_count), 2) AS p50_orders_per_vendor,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY vm.vendor_order_count), 2) AS p80_orders_per_vendor
  FROM vendor_metrics vm
  LEFT JOIN period_metrics pm ON vm.period_start = pm.period_start
  GROUP BY 1, 2, 3
),

allocation_metrics AS (
  SELECT
    DATE_TRUNC('month', shifting_ts_ist) AS period_start,
    COUNT(DISTINCT order_id) AS total_orders,
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
  WHERE TO_DATE(shifting_ts_ist) >= '2025-10-01'
    AND shifting_type = 'intra_city'
  GROUP BY 1
),

-- Wallet withdrawal / recharge. vac.VENDOR_ID = v.ID is confirmed correct
-- as originally written (per domain owner) — left unchanged. Two things
-- changed vs. the query as originally supplied: month was
-- TO_CHAR(..., 'YYYY-MM') (string) -> changed to DATE_TRUNC(...)::DATE to
-- match this table's DATE column. Added the same open-ended start_date
-- filter used everywhere else (none was present originally).
wallet_withdrawals AS (
  SELECT
    DATE_TRUNC('month', w.CREATED_AT)::DATE AS month,
    ROUND(COUNT(DISTINCT CASE WHEN w.STATUS = 'Failure' THEN w.ID END) * 100.0
        / NULLIF(COUNT(DISTINCT w.ID), 0), 2) AS withdrawal_failure_pct,
    ROUND(COUNT(DISTINCT w.ID) / NULLIF(COUNT(DISTINCT w.VENDOR_OWNER_ID), 0), 2) AS withdrawals_per_vendor,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY w.AMOUNT) AS p50_withdrawal_amount
  FROM PROD_CURATED.PNM_APPLICATION.VENDOR_OWNERS v
  JOIN PROD_CURATED.PNM_APPLICATION.VENDOR_WALLET_WITHDRAWAL w
      ON v.ID = w.VENDOR_OWNER_ID
  WHERE v.vendor_id IN (SELECT DISTINCT vendor_id FROM PROD_ELDORIA.CORE.DIM_PNM_VENDOR)
    AND w.CREATED_AT >= '2025-10-01'
    AND EXISTS (
      SELECT 1
      FROM PROD_CURATED.PNM_APPLICATION.VENDOR_ALLOCATION_CONFIGS vac
      WHERE vac.VENDOR_ID = v.ID
        AND NOT ARRAY_CONTAINS('Labour'::VARIANT, vac.SERVICE_TYPES)
        AND NOT ARRAY_CONTAINS('Helper'::VARIANT, vac.SERVICE_TYPES)
        AND NOT ARRAY_CONTAINS(34::VARIANT, vac.EXCLUDED_PACKAGE_IDS)
        AND NOT ARRAY_CONTAINS(35::VARIANT, vac.EXCLUDED_PACKAGE_IDS)
        AND NOT ARRAY_CONTAINS(36::VARIANT, vac.EXCLUDED_PACKAGE_IDS)
    )
  GROUP BY 1
),
wallet_recharges AS (
  SELECT
    DATE_TRUNC('month', p.created_at)::DATE AS month,
    ROUND(COUNT(DISTINCT CASE WHEN p.STATUS = 2 THEN p.ID END) * 100.0
        / NULLIF(COUNT(DISTINCT p.ID), 0), 2) AS recharge_failure_pct,
    ROUND(COUNT(DISTINCT p.ID) / NULLIF(COUNT(DISTINCT p.VENDOR_OWNER_ID), 0), 2) AS recharges_per_vendor,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.AMOUNT) AS p50_recharge_amount
  FROM PROD_CURATED.PNM_APPLICATION.VENDOR_OWNERS v
  JOIN PROD_CURATED.PNM_APPLICATION.PAYMENT_LINKS p
      ON v.ID = p.VENDOR_OWNER_ID
  WHERE p.flow = 'VendorWalletRecharge'
    AND p.created_at >= '2025-10-01'
  GROUP BY 1
),
wallet_metrics AS (
  SELECT
    COALESCE(w.month, r.month) AS month,
    w.withdrawals_per_vendor,
    w.p50_withdrawal_amount,
    w.withdrawal_failure_pct,
    r.recharges_per_vendor,
    r.p50_recharge_amount,
    r.recharge_failure_pct
  FROM wallet_withdrawals w
  FULL OUTER JOIN wallet_recharges r ON w.month = r.month
),

-- Vendor TPO / Top-5-issues. Already outputs (metric, month, value)
-- directly, so it's just UNION ALL'd straight into the final SELECT below
-- (no unpivot required). One logic correction (per domain owner,
-- 2026-07-06): the issue-breakdown percentage's denominator is
-- tpo_total_all.total_tpo_overall (TPO off ALL tickets) rather than
-- tpo_total_filtered.vendor_tpo (TPO off only vendor-raised tickets) — i.e.
-- "what share of overall TPO does each vendor-raised issue represent."
tpo_orders AS (
    SELECT
        DATE_TRUNC('month', DATE(b.completed_ts_ist)) AS period,
        COUNT(DISTINCT a.crn) AS completed_orders
    FROM prod_eldoria.raw.pnm_application_orders a
    JOIN prod_eldoria.raw.pnm_application_order_allocation_infos b
        ON a.id = b.order_id AND b.is_active = true
    LEFT JOIN prod_eldoria.raw.pnm_application_shifting_requirements c
        ON a.sr_id = c.id
    WHERE
        a.crn LIKE '%PNM%'
        AND c.package_name NOT ILIKE '%Nano%'
        AND c.shifting_type = 'intra_city'
        AND DATE(b.completed_ts_ist) >= '2025-10-01'
    GROUP BY 1
),
tpo_tkt_all AS (
    SELECT
        DATE_TRUNC('month', DATE(hst.created_at + interval '5 hours, 30 minutes')) AS period,
        COUNT(DISTINCT hst.ticket_number) AS tickets
    FROM prod_eldoria.raw.sfms_public_hs_tickets hst
    LEFT JOIN prod_eldoria.raw.pnm_application_orders a ON hst.crn = a.crn
    LEFT JOIN prod_eldoria.raw.pnm_application_shifting_requirements c ON a.sr_id = c.id
    WHERE
        hst.crn LIKE '%PNM%'
        AND c.package_name NOT ILIKE '%Nano%'
        AND COALESCE(hst.raised_by, '') != 'Detractor'
        AND hst.issue IS NOT NULL
        AND c.shifting_type = 'intra_city'
        AND DATE(hst.created_at + interval '5 hours, 30 minutes') >= '2025-10-01'
    GROUP BY 1
),
tpo_tkt_filtered AS (
    SELECT
        DATE_TRUNC('month', DATE(hst.created_at + interval '5 hours, 30 minutes')) AS period,
        hst.issue,
        COUNT(DISTINCT hst.ticket_number) AS tickets
    FROM prod_eldoria.raw.sfms_public_hs_tickets hst
    LEFT JOIN prod_eldoria.raw.pnm_application_orders a ON hst.crn = a.crn
    LEFT JOIN prod_eldoria.raw.pnm_application_shifting_requirements c ON a.sr_id = c.id
    WHERE
        hst.crn LIKE '%PNM%'
        AND c.package_name NOT ILIKE '%Nano%'
        AND COALESCE(hst.raised_by, '') != 'Detractor'
        AND hst.issue IS NOT NULL
        AND hst.raised_by IN ('Vendor-Owner', 'Vendor-Supervisor')
        AND c.shifting_type = 'intra_city'
        AND DATE(hst.created_at + interval '5 hours, 30 minutes') >= '2025-10-01'
    GROUP BY 1, 2
),
tpo_total_all AS (
    SELECT
        ta.period,
        SUM(ta.tickets) / NULLIF(MAX(o.completed_orders), 0) AS total_tpo_overall
    FROM tpo_tkt_all ta
    JOIN tpo_orders o ON ta.period = o.period
    GROUP BY 1
),
tpo_total_filtered AS (
    SELECT
        tf.period,
        SUM(tf.tickets) / NULLIF(MAX(o.completed_orders), 0) AS vendor_tpo
    FROM tpo_tkt_filtered tf
    JOIN tpo_orders o ON tf.period = o.period
    GROUP BY 1
),
tpo_metrics AS (
    SELECT
        'Vendor TPO'         AS metric,
        period               AS month,
        ROUND(vendor_tpo, 4) AS value
    FROM tpo_total_filtered

    UNION ALL

    SELECT
        'L1: Top 5 Issues (raised by vendors) - ' || tf.issue AS metric,
        tf.period AS month,
        ROUND(
            (tf.tickets / NULLIF(o.completed_orders, 0))
            / NULLIF(tta.total_tpo_overall, 0) * 100,
            2
        ) AS value
    FROM tpo_tkt_filtered tf
    JOIN tpo_orders     o   ON tf.period = o.period
    JOIN tpo_total_all  tta ON tf.period = tta.period
    WHERE tf.issue IN (
        'Changes in order requirement',
        'Supervisor Reject order',
        'Cancellation',
        'Customer Unreachable',
        'Payment related'
    )
),

-- Trip duration / stage-to-stage TAT percentiles. Upper bound
-- (SHIFTING_TS_IST < '2026-05-01') removed to match the open-ended
-- start_date convention used everywhere else (confirmed with owner).
-- p50_trip_duration was already computed by the original query but wasn't
-- in the original 6-metric name list — included as its own metric per
-- standing convention (confirmed with owner). Two label/logic quirks
-- confirmed intentional, left as-is: "Supervisor Assigned" in two metric
-- labels below actually measures off SUPERVISOR_ACCEPTED_TS_IST (there's a
-- separate, unused SUPERVISOR_ASSIGNED_TS_IST column on this mart), and the
-- last metric is labeled "...-> Shifting Complete" but is computed as
-- Pickup Complete -> ORDER_COMPLETED_TS_IST (no "shifting complete"
-- timestamp exists on this mart).
trip_duration_metrics AS (
    SELECT
        DATE_TRUNC('month', SHIFTING_TS_IST) AS month,
        ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY
            DATEDIFF('minute', VENDOR_OWNER_ACCEPTED_TS_IST, SUPERVISOR_ACCEPTED_TS_IST)
        ), 1) AS p80_vendor_accepted_to_sup_assigned,
        ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY
            DATEDIFF('minute', SUPERVISOR_ACCEPTED_TS_IST, TRIP_STARTED_TS_IST)
        ), 1) AS p80_sup_assigned_to_trip_started,
        ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY
            DATEDIFF('minute', TRIP_STARTED_TS_IST, SHIFTING_STARTED_TS_IST)
        ), 1) AS p80_trip_started_to_shifting_started,
        ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY
            DATEDIFF('minute', SHIFTING_STARTED_TS_IST, PICKUP_COMPLETED_TS_IST)
        ), 1) AS p80_shifting_started_to_pickup_complete,
        ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY
            DATEDIFF('minute', PICKUP_COMPLETED_TS_IST, ORDER_COMPLETED_TS_IST)
        ), 1) AS p80_pickup_complete_to_order_complete,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY
            DATEDIFF('minute', SHIFTING_STARTED_TS_IST, ORDER_COMPLETED_TS_IST)
        ), 1) AS p50_trip_duration,
        ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY
            DATEDIFF('minute', SHIFTING_STARTED_TS_IST, ORDER_COMPLETED_TS_IST)
        ), 1) AS p80_trip_duration
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
    WHERE
        SHIFTING_TS_IST >= '2025-10-01'
        AND ORDER_STATUS = 'completed'
        AND PACKAGE_NAME NOT ILIKE 'Nano%'
        AND SHIFTING_TYPE = 'intra_city'
    GROUP BY 1
),

-- Edit / modification adoption. Upper bound (BETWEEN ... AND '2026-06-30')
-- removed to match the open-ended start_date convention (confirmed with
-- owner — the cap would have silently excluded the latest month on every
-- run). Raw total_orders / orders_with_mods counts are kept only as
-- intermediates for the ratio/percentage metrics below — not written to the
-- destination table (confirmed with owner). "Edit locations adoption" and
-- "% of orders where a location is modified" are confirmed to be the same
-- calculation under two labels (written twice, not a bug). Note:
-- PNM_EXPERIENCE's schema grew between this and the trip-duration section's
-- verification (these edit columns didn't exist a day earlier) — re-verify
-- columns live before adding further sections off this table.
edit_base AS (
    SELECT
        DATE_TRUNC('month', pe.ORDER_CREATED_TS_IST)                                          AS month,
        COUNT(DISTINCT pe.ORDER_ID)                                                            AS total_orders,
        COUNT(DISTINCT CASE WHEN pe.IS_MODIFICATION_DONE = 'Yes' THEN pe.ORDER_ID END)        AS orders_with_mods,
        SUM(pe.NO_OF_SUCCESSFUL_EDITS)                                                        AS no_of_successful_edits,
        SUM(pe.EDITS_AFTER_SHIFTING)                                                           AS edits_after_shifting,
        COUNT(DISTINCT CASE WHEN pe.HAS_SUPPORT_EDIT  = 1 THEN pe.ORDER_ID END)               AS support_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_LOCATION_EDIT = 1 THEN pe.ORDER_ID END)               AS location_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_ITEMS_EDIT    = 1 THEN pe.ORDER_ID END)               AS items_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_ADDONS_EDIT   = 1 THEN pe.ORDER_ID END)               AS addons_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_SLOT_EDIT     = 1 THEN pe.ORDER_ID END)               AS slot_edited_orders
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE pe
    WHERE pe.ORDER_STATUS = 'completed'
      AND pe.SHIFTING_TYPE = 'intra_city'
      AND pe.PACKAGE_NAME NOT ILIKE 'Nano%'
      AND DATE(pe.ORDER_CREATED_TS_IST) >= '2025-10-01'
    GROUP BY 1
),
edit_metrics AS (
    SELECT
        month,
        ROUND(100.0 * orders_with_mods        / NULLIF(total_orders, 0), 2)              AS pct_orders_edited,
        no_of_successful_edits,
        ROUND(100.0 * support_edited_orders   / NULLIF(total_orders, 0), 2)              AS pct_support_edited_orders,
        ROUND(100.0 * location_edited_orders  / NULLIF(total_orders, 0), 2)              AS location_adoption_pct,
        ROUND(100.0 * location_edited_orders  / NULLIF(total_orders, 0), 2)              AS pct_orders_location_modified,
        ROUND(100.0 * items_edited_orders     / NULLIF(total_orders, 0), 2)              AS items_adoption_pct,
        ROUND(100.0 * addons_edited_orders    / NULLIF(total_orders, 0), 2)              AS addons_adoption_pct,
        ROUND(100.0 * slot_edited_orders      / NULLIF(total_orders, 0), 2)              AS slot_adoption_pct,
        ROUND(no_of_successful_edits * 1.0    / NULLIF(total_orders, 0), 2)              AS edits_per_order,
        ROUND(100.0 * edits_after_shifting    / NULLIF(no_of_successful_edits, 0), 2)    AS pct_edits_after_shifting_started
    FROM edit_base
),

-- TPO Trend (card #47576) — a separate, independently-sourced TPO pipeline
-- from PROD_CURATED (not PROD_ELDORIA.RAW, which the tpo_metrics CTE above
-- uses). Upper bound (BETWEEN ... AND '2026-06-30') removed to match the
-- open-ended start_date convention (confirmed with owner). Raw total_orders
-- kept only as an intermediate denominator — not written to the destination
-- table (confirmed with owner, same call as edit adoption). "Vendor raised
-- TPO" here was checked against the existing "Vendor TPO" metric above and
-- found to produce essentially identical values off the same orders
-- denominator — confirmed with owner to keep both as separate metrics.
tpo_trend_orders AS (
    SELECT
        DATE_TRUNC('month', DATEADD(minute, 330, b.completed_ts)) AS month,
        COUNT(DISTINCT a.crn) AS total_orders
    FROM PROD_CURATED.PNM_APPLICATION.ORDERS a
    JOIN PROD_CURATED.PNM_APPLICATION.ORDER_ALLOCATION_INFOS b
        ON a.id = b.order_id AND b.is_active = true
    LEFT JOIN PROD_CURATED.PNM_APPLICATION.SHIFTING_REQUIREMENTS c
        ON a.sr_id = c.id
    WHERE
        a.crn LIKE '%PNM%'
        AND c.package_name NOT ILIKE '%Nano%'
        AND c.shifting_type = 'intra_city'
        AND DATE(DATEADD(minute, 330, b.completed_ts)) >= '2025-10-01'
    GROUP BY 1
),
tpo_trend_tickets AS (
    SELECT
        DATE_TRUNC('month', DATEADD(minute, 330, hst.created_at)) AS month,
        COUNT(DISTINCT hst.ticket_number) AS tickets_overall,
        COUNT(DISTINCT CASE WHEN hst.raised_by ILIKE 'Vendor%' THEN hst.ticket_number END) AS tickets_vendor,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN ('open','supervisor_assigned','supervisor_accepted','vendor_accepted') THEN hst.ticket_number END) AS tickets_pretip_overall,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN ('open','supervisor_assigned','supervisor_accepted','vendor_accepted') AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_pretip_customer,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN ('trip_started','shifting_started') THEN hst.ticket_number END) AS tickets_trip_overall,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN ('trip_started','shifting_started') AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_trip_customer,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'pickup_completed' THEN hst.ticket_number END) AS tickets_pickup_overall,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'pickup_completed' AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_pickup_customer,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'completed' THEN hst.ticket_number END) AS tickets_completed_overall,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'completed' AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_completed_customer,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'cancelled' THEN hst.ticket_number END) AS tickets_cancelled_overall,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'cancelled' AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_cancelled_customer
    FROM PROD_CURATED.SFMS_PUBLIC.HS_TICKETS hst
    LEFT JOIN PROD_CURATED.PNM_APPLICATION.ORDERS a ON hst.crn = a.crn
    LEFT JOIN PROD_CURATED.PNM_APPLICATION.SHIFTING_REQUIREMENTS c ON a.sr_id = c.id
    WHERE
        hst.crn LIKE '%PNM%'
        AND hst.hs_package NOT ILIKE '%Nano%'
        AND COALESCE(hst.shifting_type, c.shifting_type) = 'intra_city'
        AND DATE(DATEADD(minute, 330, hst.created_at)) >= '2025-10-01'
        AND COALESCE(hst.raised_by, '') != 'Detractor'
    GROUP BY 1
),
tpo_trend_metrics AS (
    SELECT
        o.month,
        ROUND(t.tickets_overall / NULLIF(o.total_orders, 0), 2) AS tpo_overall,
        ROUND(t.tickets_vendor / NULLIF(o.total_orders, 0), 2) AS tpo_vendor_raised,
        ROUND(t.tickets_pretip_overall / NULLIF(o.total_orders, 0), 2) AS tpo_till_trip_start,
        ROUND(t.tickets_pretip_customer / NULLIF(o.total_orders, 0), 2) AS tpo_till_trip_start_customer,
        ROUND(t.tickets_trip_overall / NULLIF(o.total_orders, 0), 2) AS tpo_shifting_start,
        ROUND(t.tickets_trip_customer / NULLIF(o.total_orders, 0), 2) AS tpo_shifting_start_customer,
        ROUND(t.tickets_pickup_overall / NULLIF(o.total_orders, 0), 2) AS tpo_pickup_complete,
        ROUND(t.tickets_pickup_customer / NULLIF(o.total_orders, 0), 2) AS tpo_pickup_complete_customer,
        ROUND(t.tickets_completed_overall / NULLIF(o.total_orders, 0), 2) AS tpo_complete,
        ROUND(t.tickets_completed_customer / NULLIF(o.total_orders, 0), 2) AS tpo_complete_customer,
        ROUND(t.tickets_cancelled_overall / NULLIF(o.total_orders, 0), 2) AS tpo_order_cancelled,
        ROUND(t.tickets_cancelled_customer / NULLIF(o.total_orders, 0), 2) AS tpo_order_cancelled_customer
    FROM tpo_trend_orders o
    LEFT JOIN tpo_trend_tickets t
        ON t.month = o.month
),

-- Add-on adoption. Date filter switched from closed window
-- (BETWEEN '2026-02-01' AND '2026-06-30') to open-ended start_date
-- convention (confirmed with owner). Deliberately kept WITHOUT
-- ORDER_STATUS = 'completed' / PACKAGE_NAME NOT ILIKE 'Nano%' filters,
-- unlike every other PNM_EXPERIENCE section — confirmed with owner this is
-- intentional (covers all orders regardless of status/package). Adding
-- those filters would raise "Overall Add-on Adoption %" from ~86-89% to
-- ~97-98% — a real difference. Do not "fix" this without checking first.
addon_metrics AS (
    SELECT
        DATE_TRUNC('month', TO_DATE(ORDER_CREATED_TS_IST)) AS month,
        ROUND(100.0 * COUNT(DISTINCT CASE WHEN ADD_ONS IS NOT NULL AND ADD_ONS != '' THEN ORDER_ID END)
            / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_any_addon,
        ROUND(100.0 * COUNT(DISTINCT CASE WHEN
            LOWER(ADD_ONS) LIKE '%single-layer packing%' OR LOWER(ADD_ONS) LIKE '%multi-layer packing%'
            THEN ORDER_ID END)
            / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_packing,
        ROUND(100.0 * COUNT(DISTINCT CASE WHEN
            LOWER(ADD_ONS) LIKE '%ac installation%' OR LOWER(ADD_ONS) LIKE '%ac uninstallation%'
            THEN ORDER_ID END)
            / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_ac,
        ROUND(100.0 * COUNT(DISTINCT CASE WHEN
            LOWER(ADD_ONS) LIKE '%professional carpenter%'
            OR LOWER(ADD_ONS) LIKE '%dismantling and reassembly%'
            OR LOWER(ADD_ONS) LIKE '%dismantelling and reassembly%'
            THEN ORDER_ID END)
            / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_carpentry,
        ROUND(100.0 * COUNT(DISTINCT CASE WHEN
            LOWER(ADD_ONS) LIKE '%rope pull%'
            THEN ORDER_ID END)
            / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_rope_pulling,
        ROUND(100.0 * COUNT(DISTINCT CASE WHEN
            LOWER(ADD_ONS) LIKE '%bigger vehicle%'
            THEN ORDER_ID END)
            / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_bigger_vehicle,
        ROUND(100.0 * COUNT(DISTINCT CASE WHEN
            LOWER(ADD_ONS) LIKE '%extra labour%'
            THEN ORDER_ID END)
            / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_extra_labour
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
    WHERE SHIFTING_TYPE = 'intra_city'
        AND TO_DATE(ORDER_CREATED_TS_IST) >= '2025-10-01'
    GROUP BY 1
),

-- Completion score / NPS / detractors. Fixed a trailing comma after
-- classification, before FROM (invalid SQL) in the original query. Date
-- filter switched from a closed window (BETWEEN '2026-01-01' AND
-- '2026-04-30') to the open-ended start_date convention (confirmed with
-- owner). 9 raw-count columns are kept only as intermediates — not written
-- to the destination table (confirmed with owner).
completion_base AS (
    SELECT
        DATE_TRUNC('month', shifting_ts_ist) AS month,
        order_id,
        vendor_id,
        order_status,
        deallocation_status,
        classification
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
    WHERE package_name NOT ILIKE 'Nano%'
        AND shifting_type = 'intra_city'
        AND shifting_ts_ist::date >= '2025-10-01'
),
completion_metrics AS (
    SELECT
        month,
        ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' THEN order_id END)
            / NULLIF(COUNT(DISTINCT CASE WHEN vendor_id IS NOT NULL THEN order_id END), 0), 2)
                                                                                       AS completion_score_pct,
        CASE
            WHEN COUNT(DISTINCT CASE WHEN order_status = 'completed'
                AND classification IS NOT NULL THEN order_id END) > 0
            THEN ROUND(
                100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed'
                    AND classification = 'Promoter'  THEN order_id END)
                      / COUNT(DISTINCT CASE WHEN order_status = 'completed'
                    AND classification IS NOT NULL    THEN order_id END)
              - 100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed'
                    AND classification = 'Detractor' THEN order_id END)
                      / COUNT(DISTINCT CASE WHEN order_status = 'completed'
                    AND classification IS NOT NULL    THEN order_id END), 2)
            ELSE 0
        END                                                                              AS nps,
        ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed'
            AND classification = 'Detractor' THEN order_id END)
            / NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed'
            THEN order_id END), 0), 2)                                                   AS detractor_pct
    FROM completion_base
    GROUP BY 1
),

-- Weekend order contribution. REPLACED 2026-07-15 with a new source per
-- owner (PNM_EXPERIENCE + FACT_PNM_ORDERS, supersedes the
-- PROD_CURATED.PNM_APPLICATION-based version above). Found and fixed two
-- real bugs in the new query as supplied: (1) the final SELECT aliased two
-- different columns "weekend_orders" (raw count AND the ratio) — ambiguous/
-- invalid, renamed the ratio column; (2) the ratio was a bare 0-1 fraction,
-- not multiplied by 100 like every other percentage metric in this
-- pipeline — added * 100.0. Checked live that the fixed numbers land in the
-- same ~32-51% range as the prior implementation, so this is a re-source,
-- not a behavior change. DAYOFWEEK(...) IN (0, 6) is correct as supplied
-- (Sun=0, Sat=6) — the correct version of the bug fixed in the prior
-- weekend query (DAYOFWEEKISO(...) IN (6, 7)), just via a different
-- Snowflake function. Date filter switched from a closed window to the
-- open-ended start_date convention.
weekend_base AS (
    SELECT
        pe.order_id,
        pe.shifting_ts_ist,
        CASE
            WHEN DAYOFWEEK(pe.shifting_ts_ist) IN (0,6) THEN 'Weekend'
            ELSE 'Weekday'
        END AS day_type
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE pe
    JOIN PROD_ELDORIA.CORE.FACT_PNM_ORDERS fpo ON pe.order_id = fpo.order_id
    WHERE pe.vendor_id IS NOT NULL
      AND pe.shifting_ts_ist >= '2025-10-01'
      AND fpo.crn ILIKE 'PNM%'
      AND pe.package_name NOT ILIKE 'nano%'
),
weekend_metrics AS (
    SELECT
        DATE_TRUNC('month', shifting_ts_ist) AS month,
        ROUND(100.0 * COUNT(DISTINCT CASE WHEN day_type = 'Weekend' THEN order_id END)
            / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS weekend_order_share_pct
    FROM weekend_base
    GROUP BY 1
),

-- Leads / Orders / Conversion by source. Fixed a trailing comma before
-- FROM leads l (invalid SQL). Date filter switched from a closed window
-- (BETWEEN '2025-10-01' AND '2026-06-30') to the open-ended start_date
-- convention (confirmed with owner). "leads_app_pct" etc. are intentionally
-- percentages of total leads, not raw counts (confirmed with owner, despite
-- looking parallel to "leads_overall" which IS a raw count). "orders_app"
-- etc. (raw per-source order counts) were added — the original query never
-- surfaced these even though "Orders - App" etc. were requested as metrics
-- (confirmed with owner). The leads CTE's shifting_type filter
-- (= 'intra_city' OR shifting_type IS NULL) is looser than the orders CTE's
-- (= 'intra_city' only) — left as originally written. The
-- ELSE 'Website (Mobile)' catch-all in both source-classification CASE
-- statements currently matches zero rows (verified live) — left unchanged.
leads AS (
    SELECT
        DATE_TRUNC('MONTH', fpo.opp_created_ts) AS month,
        CASE
            WHEN dpo.source_details = 'Desktop Website' THEN 'Website (Desktop)'
            WHEN dpo.source_details = 'Mobile Website'  THEN 'Website (Mobile)'
            WHEN dpo.source IN (1,2,3)                   THEN 'App'
            WHEN dpo.source = 4                           THEN 'Generic'
            ELSE 'Website (Mobile)'
        END AS opp_source,
        COUNT(DISTINCT fpo.opp_id) AS lead_count
    FROM PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY fpo
    LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY dpo ON dpo.opp_id = fpo.opp_id
    WHERE dpo.user_flag ILIKE 'normal'
      AND DATE(fpo.opp_created_ts) >= '2025-10-01'
      AND (dpo.shifting_type = 'intra_city' OR dpo.shifting_type IS NULL)
    GROUP BY 1, 2
),
leads_order_with_source AS (
    SELECT
        o.order_id,
        o.o_created_ts,
        CASE
            WHEN dpo.source_details = 'Desktop Website' THEN 'Website (Desktop)'
            WHEN dpo.source_details = 'Mobile Website'  THEN 'Website (Mobile)'
            WHEN dpo.source IN (1,2,3)                   THEN 'App'
            WHEN dpo.source = 4                           THEN 'Generic'
            ELSE 'Website (Mobile)'
        END AS opp_source
    FROM PROD_ELDORIA.CORE.FACT_PNM_ORDERS o
    INNER JOIN PROD_ELDORIA.MART.PNM_CUSTOMERS   pc    ON pc.customer_mobile = o.customer_mobile
    LEFT JOIN  PROD_ELDORIA.CORE.DIM_PNM_ORDERS  dpord ON dpord.order_id = o.order_id
    LEFT JOIN  PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY fpo   ON fpo.sr_id = o.sr_id
    LEFT JOIN  PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY dpo ON dpo.opp_id = fpo.opp_id
    WHERE dpord.user_flag ILIKE 'normal'
      AND DATE(o.o_created_ts) >= '2025-10-01'
      AND dpord.shifting_type = 'intra_city'
      AND (o.crn LIKE '%PNM%')
      AND (dpord.package_name NOT ILIKE 'Nano%' OR dpord.package_name IS NULL)
    QUALIFY ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY fpo.opp_id DESC NULLS LAST) = 1
),
leads_orders AS (
    SELECT
        DATE_TRUNC('MONTH', o_created_ts) AS month,
        opp_source,
        COUNT(DISTINCT order_id) AS order_count
    FROM leads_order_with_source
    GROUP BY 1, 2
),
leads_conversion_metrics AS (
    SELECT
        l.month,
        SUM(l.lead_count) AS leads_overall,
        SUM(COALESCE(o.order_count, 0)) AS booked_orders,
        ROUND(100.0 * SUM(COALESCE(o.order_count,0))
              / NULLIF(SUM(l.lead_count),0), 2) AS conversion_overall_pct,
        ROUND(100.0 * SUM(CASE WHEN l.opp_source='App' THEN COALESCE(o.order_count,0) ELSE 0 END)
              / NULLIF(SUM(CASE WHEN l.opp_source='App' THEN l.lead_count ELSE 0 END),0), 2)
            AS conversion_app_pct,
        ROUND(100.0 * SUM(CASE WHEN l.opp_source='Website (Desktop)' THEN COALESCE(o.order_count,0) ELSE 0 END)
              / NULLIF(SUM(CASE WHEN l.opp_source='Website (Desktop)' THEN l.lead_count ELSE 0 END),0), 2)
            AS conversion_desktop_web_pct,
        ROUND(100.0 * SUM(CASE WHEN l.opp_source='Website (Mobile)' THEN COALESCE(o.order_count,0) ELSE 0 END)
              / NULLIF(SUM(CASE WHEN l.opp_source='Website (Mobile)' THEN l.lead_count ELSE 0 END),0), 2)
            AS conversion_mobile_web_pct,
        ROUND(100.0 * SUM(CASE WHEN o.opp_source='App' THEN COALESCE(o.order_count,0) ELSE 0 END)
              / NULLIF(SUM(COALESCE(o.order_count,0)),0), 2) AS pct_orders_app,
        ROUND(100.0 * (
                SUM(CASE WHEN o.opp_source='Website (Desktop)' THEN COALESCE(o.order_count,0) ELSE 0 END)
              + SUM(CASE WHEN o.opp_source='Website (Mobile)' THEN COALESCE(o.order_count,0) ELSE 0 END)
              ) / NULLIF(SUM(COALESCE(o.order_count,0)),0), 2) AS pct_orders_website,
        ROUND(100.0 * SUM(CASE WHEN o.opp_source='Generic' THEN COALESCE(o.order_count,0) ELSE 0 END)
              / NULLIF(SUM(COALESCE(o.order_count,0)),0), 2) AS pct_orders_others,
        ROUND(100.0 * SUM(CASE WHEN l.opp_source = 'App' THEN l.lead_count ELSE 0 END)
              / NULLIF(SUM(l.lead_count), 0), 2) AS leads_app_pct,
        ROUND(100.0 * SUM(CASE WHEN l.opp_source = 'Website (Desktop)' THEN l.lead_count ELSE 0 END)
              / NULLIF(SUM(l.lead_count), 0), 2) AS leads_desktop_web_pct,
        ROUND(100.0 * SUM(CASE WHEN l.opp_source = 'Website (Mobile)' THEN l.lead_count ELSE 0 END)
              / NULLIF(SUM(l.lead_count), 0), 2) AS leads_mobile_web_pct,
        ROUND(100.0 * SUM(CASE WHEN l.opp_source = 'Generic' THEN l.lead_count ELSE 0 END)
              / NULLIF(SUM(l.lead_count), 0), 2) AS leads_others_pct,
        SUM(CASE WHEN o.opp_source='App' THEN COALESCE(o.order_count,0) ELSE 0 END) AS orders_app,
        SUM(CASE WHEN o.opp_source='Website (Desktop)' THEN COALESCE(o.order_count,0) ELSE 0 END) AS orders_desktop_web,
        SUM(CASE WHEN o.opp_source='Website (Mobile)' THEN COALESCE(o.order_count,0) ELSE 0 END) AS orders_mobile_web,
        SUM(CASE WHEN o.opp_source='Generic' THEN COALESCE(o.order_count,0) ELSE 0 END) AS orders_others
    FROM leads l
    LEFT JOIN leads_orders o ON o.month = l.month AND o.opp_source = l.opp_source
    GROUP BY l.month
),

-- Get a Call CTR. Date filter switched from a closed window
-- (BETWEEN '2025-10-01' AND '2026-04-30') to the open-ended start_date
-- convention (checked live: no data gap, applied without a separate
-- confirmation round per standing precedent). total_opportunities /
-- gac_opportunities (raw counts) dropped, keeping only the named metric.
gac_ctr_metrics AS (
    SELECT
        DATE_TRUNC('month', DATE(opp.created_at + interval'5 hours, 30 minutes')) AS month,
        ROUND(
            100.0 * COUNT(DISTINCT CASE WHEN olls.opportunity_id IS NOT NULL THEN opp.id END)
            / NULLIF(COUNT(DISTINCT opp.id), 0),
            2
        ) AS gac_ctr_pct
    FROM PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES opp
    LEFT JOIN PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES_LATEST_LSM_SCORE olls
        ON opp.id = olls.opportunity_id
        AND olls.opportunity_latest_score = 999
    WHERE
        opp.shifting_type = 'intra_city'
        AND DATE(opp.created_at + interval'5 hours, 30 minutes') >= '2025-10-01'
    GROUP BY 1
),

-- CAC post trip started. Date filter switched from a closed window
-- (BETWEEN '2026-01-01' AND '2026-05-31') to the open-ended start_date
-- convention (checked live: no data gap, applied without a separate
-- confirmation round per standing precedent). total_orders /
-- orders_with_cancel_event (raw counts) dropped, keeping only the named
-- metric.
cac_post_trip_started_metrics AS (
    SELECT
        DATE_TRUNC('MONTH', pe.SHIFTING_TS_IST) AS month,
        ROUND(
            COUNT(DISTINCT CASE WHEN
                pe.TRIP_STARTED_TS_IST IS NOT NULL
                AND pe.ORDER_STATUS = 'cancelled'
                AND coe.CANCELLED_BY = 'Customer'
            THEN pe.ORDER_ID END) * 100.0
            / NULLIF(COUNT(DISTINCT pe.ORDER_ID), 0),
            2) AS cac_post_trip_started_pct
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE pe
    LEFT JOIN PROD_CURATED.PNM_APPLICATION.CANCELLED_ORDER_EVENTS coe
        ON coe.order_id = pe.order_id
    WHERE pe.SHIFTING_TYPE = 'intra_city'
        AND pe.PACKAGE_NAME NOT ILIKE '%Nano%'
        AND DATE(pe.SHIFTING_TS_IST) >= '2025-10-01'
    GROUP BY 1
),

-- Vendor earnings distribution by bucket. Date filter switched from a
-- closed window (BETWEEN '2026-01-01' AND '2026-06-30') to the open-ended
-- start_date convention (checked live: all 5 buckets present with no gap
-- back to Oct 2025). Confirmed with owner that this one metric name
-- becomes 5 metrics, one per bucket, using revenue_percentage. Dropped the
-- "cof" column from the original query — it was total_order_fare aliased
-- and summed under a different name, an exact duplicate never used for
-- anything else.
vendor_earnings_order_base AS (
    SELECT
        order_id,
        vendor_id,
        COALESCE(vendor_bucket_type, 'New') AS bucket,
        order_completed_ts_ist,
        total_order_fare
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
    WHERE order_status = 'completed'
      AND package_name NOT ILIKE 'Nano%'
      AND shifting_type = 'intra_city'
      AND DATE(order_completed_ts_ist) >= '2025-10-01'
),
vendor_earnings_periodized AS (
    SELECT
        DATE_TRUNC('month', order_completed_ts_ist) AS month,
        order_id,
        vendor_id,
        bucket,
        order_completed_ts_ist,
        total_order_fare
    FROM vendor_earnings_order_base
),
vendor_earnings_period_bucket AS (
    SELECT month, vendor_id, bucket
    FROM (
        SELECT
            month,
            vendor_id,
            bucket,
            ROW_NUMBER() OVER (
                PARTITION BY month, vendor_id
                ORDER BY order_completed_ts_ist DESC, order_id DESC
            ) AS rn
        FROM vendor_earnings_periodized
    ) ranked
    WHERE rn = 1
),
vendor_earnings_effective_bucket AS (
    SELECT
        pob.month,
        vpb.bucket,
        pob.order_id,
        pob.vendor_id,
        pob.total_order_fare
    FROM vendor_earnings_periodized pob
    INNER JOIN vendor_earnings_period_bucket vpb
        ON  pob.month = vpb.month
        AND pob.vendor_id = vpb.vendor_id
),
vendor_earnings_bucket_totals AS (
    SELECT
        month,
        bucket,
        SUM(total_order_fare) AS total_revenue
    FROM vendor_earnings_effective_bucket
    GROUP BY 1, 2
),
vendor_earnings_bucket_pct AS (
    SELECT
        month,
        bucket,
        ROUND(total_revenue * 100.0 / NULLIF(SUM(total_revenue) OVER (PARTITION BY month), 0), 2) AS revenue_pct
    FROM vendor_earnings_bucket_totals
),
vendor_earnings_bucket_metrics AS (
    SELECT
        month,
        MAX(CASE WHEN bucket = 'GoldPlus' THEN revenue_pct END) AS revenue_pct_goldplus,
        MAX(CASE WHEN bucket = 'Gold' THEN revenue_pct END) AS revenue_pct_gold,
        MAX(CASE WHEN bucket = 'Silver' THEN revenue_pct END) AS revenue_pct_silver,
        MAX(CASE WHEN bucket = 'Bronze' THEN revenue_pct END) AS revenue_pct_bronze,
        MAX(CASE WHEN bucket = 'New' THEN revenue_pct END) AS revenue_pct_new
    FROM vendor_earnings_bucket_pct
    GROUP BY 1
)

-- fare / coupon / surge (14 metrics)
SELECT period AS month, 'total_orders' AS metric, total_orders::FLOAT AS value FROM fare_metrics
UNION ALL SELECT period, 'aov', aov::FLOAT FROM fare_metrics
UNION ALL SELECT period, 'pct_orders_with_coupon', pct_orders_with_coupon::FLOAT FROM fare_metrics
UNION ALL SELECT period, 'no_of_orders_with_surge', no_of_orders_with_surge::FLOAT FROM fare_metrics
UNION ALL SELECT period, 'pct_orders_with_surge', pct_orders_with_surge::FLOAT FROM fare_metrics
UNION ALL SELECT period, 'pct_orders_positive_surge', pct_orders_positive_surge::FLOAT FROM fare_metrics
UNION ALL SELECT period, 'pct_orders_negative_surge', pct_orders_negative_surge::FLOAT FROM fare_metrics
UNION ALL SELECT period, 'orders_with_shifting_started', orders_with_shifting_started::FLOAT FROM fare_metrics
UNION ALL SELECT period, 'pct_cases_with_price_change_post_shifting_start', pct_cases_with_price_change_post_shifting_start::FLOAT FROM fare_metrics
UNION ALL SELECT period, 'pct_orders_fare_increased', pct_orders_fare_increased::FLOAT FROM fare_metrics
UNION ALL SELECT period, 'median_fare_increase_amt', median_fare_increase_amt::FLOAT FROM fare_metrics
UNION ALL SELECT period, 'pct_orders_fare_decreased', pct_orders_fare_decreased::FLOAT FROM fare_metrics
UNION ALL SELECT period, 'median_fare_decrease_amt', median_fare_decrease_amt::FLOAT FROM fare_metrics
UNION ALL SELECT period, 'pct_edited_orders_with_fare_change', pct_edited_orders_with_fare_change::FLOAT FROM fare_metrics

-- vendor P50/P80 (6 metrics)
UNION ALL SELECT period_start, 'active_vendor_count', active_vendor_count::FLOAT FROM vendor_metrics_calc
UNION ALL SELECT period_start, 'total_order_count', total_order_count::FLOAT FROM vendor_metrics_calc
UNION ALL SELECT period_start, 'p50_earnings_per_vendor', p50_earnings_per_vendor::FLOAT FROM vendor_metrics_calc
UNION ALL SELECT period_start, 'p80_earnings_per_vendor', p80_earnings_per_vendor::FLOAT FROM vendor_metrics_calc
UNION ALL SELECT period_start, 'p50_orders_per_vendor', p50_orders_per_vendor::FLOAT FROM vendor_metrics_calc
UNION ALL SELECT period_start, 'p80_orders_per_vendor', p80_orders_per_vendor::FLOAT FROM vendor_metrics_calc

-- allocation quality (33 metrics) — note: "total_orders" here is renamed
-- "alloc_total_orders" since it's a different table/definition than the
-- fare section's "total_orders" and would otherwise silently collide.
UNION ALL SELECT period_start, 'alloc_total_orders', total_orders::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'allocated_orders', allocated_orders::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'allocation_pct', allocation_pct::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'total_spot_orders', total_spot_orders::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'allocation_pct_spot', allocation_pct_spot::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'total_scheduled_orders', total_scheduled_orders::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'allocation_pct_scheduled', allocation_pct_scheduled::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'allocation_share_via_engine_pct', allocation_share_via_engine_pct::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'allocation_share_via_open_pool_pct', allocation_share_via_open_pool_pct::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'deallocation_pct', deallocation_pct::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'deallocation_pct_spot', deallocation_pct_spot::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'deallocation_pct_scheduled', deallocation_pct_scheduled::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'completion_pct', completion_pct::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'completion_pct_spot', completion_pct_spot::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'completion_pct_scheduled', completion_pct_scheduled::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'dry_run_p75_kms_spot', dry_run_p75_kms_spot::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'cac_pct_spot', cac_pct_spot::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'pac_pct_spot', pac_pct_spot::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'poac_pct_spot', poac_pct_spot::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'cac_pct_scheduled', cac_pct_scheduled::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'pac_pct_scheduled', pac_pct_scheduled::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'poac_pct_scheduled', poac_pct_scheduled::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'allocation_time_p80_minutes', allocation_time_p80_minutes::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'allocation_time_p80_spot_minutes', allocation_time_p80_spot_minutes::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'allocation_time_p80_within_2days_minutes', allocation_time_p80_within_2days_minutes::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'pct_no_vendor_before_slot', pct_no_vendor_before_slot::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'pct_supervisor_changed', pct_supervisor_changed::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'pct_supervisor_changed_post_trip', pct_supervisor_changed_post_trip::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'p80_pickup_km_deviation', p80_pickup_km_deviation::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'p80_drop_km_deviation', p80_drop_km_deviation::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'orders_with_more_than_2_deallocations', orders_with_more_than_2_deallocations::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'pct_orders_with_more_than_2_deallocations', pct_orders_with_more_than_2_deallocations::FLOAT FROM allocation_metrics
UNION ALL SELECT period_start, 'reschedule_pct', reschedule_pct::FLOAT FROM allocation_metrics

-- wallet withdrawal / recharge (6 metrics)
UNION ALL SELECT month, 'withdrawals_per_vendor', withdrawals_per_vendor::FLOAT FROM wallet_metrics
UNION ALL SELECT month, 'p50_withdrawal_amount', p50_withdrawal_amount::FLOAT FROM wallet_metrics
UNION ALL SELECT month, 'withdrawal_failure_pct', withdrawal_failure_pct::FLOAT FROM wallet_metrics
UNION ALL SELECT month, 'recharges_per_vendor', recharges_per_vendor::FLOAT FROM wallet_metrics
UNION ALL SELECT month, 'p50_recharge_amount', p50_recharge_amount::FLOAT FROM wallet_metrics
UNION ALL SELECT month, 'recharge_failure_pct', recharge_failure_pct::FLOAT FROM wallet_metrics

-- vendor TPO / top-5-issues (6 metrics) — already (metric, month, value), no unpivot needed
UNION ALL SELECT month, metric, value::FLOAT FROM tpo_metrics

-- trip duration percentiles (7 metrics)
UNION ALL SELECT month, 'P80 — Vendor Accepted → Supervisor Assigned', p80_vendor_accepted_to_sup_assigned::FLOAT FROM trip_duration_metrics
UNION ALL SELECT month, 'P80 — Supervisor Assigned → Trip Started', p80_sup_assigned_to_trip_started::FLOAT FROM trip_duration_metrics
UNION ALL SELECT month, 'P80 — Trip Started → Shifting Started', p80_trip_started_to_shifting_started::FLOAT FROM trip_duration_metrics
UNION ALL SELECT month, 'P80 — Shifting Started → Pickup Complete', p80_shifting_started_to_pickup_complete::FLOAT FROM trip_duration_metrics
UNION ALL SELECT month, 'P80 — Pickup Complete → Shifting Complete', p80_pickup_complete_to_order_complete::FLOAT FROM trip_duration_metrics
UNION ALL SELECT month, 'P50 trip duration (Shifting Started → Order Completed)', p50_trip_duration::FLOAT FROM trip_duration_metrics
UNION ALL SELECT month, 'P80 trip duration (Shifting Started → Order Completed)', p80_trip_duration::FLOAT FROM trip_duration_metrics

-- edit / modification adoption (10 metrics)
UNION ALL SELECT month, '% of orders edited', pct_orders_edited::FLOAT FROM edit_metrics
UNION ALL SELECT month, 'No. of successful edits', no_of_successful_edits::FLOAT FROM edit_metrics
UNION ALL SELECT month, '% of support-edited orders', pct_support_edited_orders::FLOAT FROM edit_metrics
UNION ALL SELECT month, 'Edit locations adoption', location_adoption_pct::FLOAT FROM edit_metrics
UNION ALL SELECT month, '% of orders where a location is modified', pct_orders_location_modified::FLOAT FROM edit_metrics
UNION ALL SELECT month, 'Edit items adoption', items_adoption_pct::FLOAT FROM edit_metrics
UNION ALL SELECT month, 'Edit add-ons adoption', addons_adoption_pct::FLOAT FROM edit_metrics
UNION ALL SELECT month, 'Edit slot adoption', slot_adoption_pct::FLOAT FROM edit_metrics
UNION ALL SELECT month, 'Number of edits per order', edits_per_order::FLOAT FROM edit_metrics
UNION ALL SELECT month, '% of edits after shifting started', pct_edits_after_shifting_started::FLOAT FROM edit_metrics

-- TPO Trend (12 metrics)
UNION ALL SELECT month, 'TPO — Overall', tpo_overall::FLOAT FROM tpo_trend_metrics
UNION ALL SELECT month, 'Vendor raised TPO', tpo_vendor_raised::FLOAT FROM tpo_trend_metrics
UNION ALL SELECT month, 'TPO — Till Trip Start stage', tpo_till_trip_start::FLOAT FROM tpo_trend_metrics
UNION ALL SELECT month, 'TPO — Till Trip Start (raised by customer)', tpo_till_trip_start_customer::FLOAT FROM tpo_trend_metrics
UNION ALL SELECT month, 'TPO — Shifting Start stage', tpo_shifting_start::FLOAT FROM tpo_trend_metrics
UNION ALL SELECT month, 'TPO — Shifting Start (raised by customer)', tpo_shifting_start_customer::FLOAT FROM tpo_trend_metrics
UNION ALL SELECT month, 'TPO — Pickup Complete stage', tpo_pickup_complete::FLOAT FROM tpo_trend_metrics
UNION ALL SELECT month, 'TPO — Pickup Complete (raised by customer)', tpo_pickup_complete_customer::FLOAT FROM tpo_trend_metrics
UNION ALL SELECT month, 'TPO — Complete stage', tpo_complete::FLOAT FROM tpo_trend_metrics
UNION ALL SELECT month, 'TPO — Complete (raised by customer)', tpo_complete_customer::FLOAT FROM tpo_trend_metrics
UNION ALL SELECT month, 'TPO — Order Cancelled stage', tpo_order_cancelled::FLOAT FROM tpo_trend_metrics
UNION ALL SELECT month, 'TPO — Order Cancelled (raised by customer)', tpo_order_cancelled_customer::FLOAT FROM tpo_trend_metrics

-- add-on adoption (7 metrics)
UNION ALL SELECT month, 'Overall Add-on Adoption %', pct_orders_with_any_addon::FLOAT FROM addon_metrics
UNION ALL SELECT month, 'Packing related add-ons adoption', pct_orders_with_packing::FLOAT FROM addon_metrics
UNION ALL SELECT month, 'AC related add-ons adoption', pct_orders_with_ac::FLOAT FROM addon_metrics
UNION ALL SELECT month, 'Carpentry related add-ons adoption', pct_orders_with_carpentry::FLOAT FROM addon_metrics
UNION ALL SELECT month, 'Rope pulling related add-ons adoption', pct_orders_with_rope_pulling::FLOAT FROM addon_metrics
UNION ALL SELECT month, 'Bigger vehicle related add-ons adoption', pct_orders_with_bigger_vehicle::FLOAT FROM addon_metrics
UNION ALL SELECT month, 'Extra labour related add-ons adoption', pct_orders_with_extra_labour::FLOAT FROM addon_metrics

-- completion score / NPS / detractors (3 metrics)
UNION ALL SELECT month, 'Overall Completion Score', completion_score_pct::FLOAT FROM completion_metrics
UNION ALL SELECT month, 'Overall NPS', nps::FLOAT FROM completion_metrics
UNION ALL SELECT month, 'Overall Detractors %', detractor_pct::FLOAT FROM completion_metrics

-- weekend order contribution (1 metric)
UNION ALL SELECT month, 'Overall Weekend Order Contribution', weekend_order_share_pct::FLOAT FROM weekend_metrics

-- leads / orders / conversion by source (17 metrics)
UNION ALL SELECT month, 'Leads - Overall', leads_overall::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, 'Leads - App', leads_app_pct::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, 'Leads - Mobile Website', leads_mobile_web_pct::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, 'Leads - Desktop Website', leads_desktop_web_pct::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, 'Leads - Others', leads_others_pct::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, 'Booked Orders', booked_orders::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, 'Orders - App', orders_app::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, 'Orders - Desktop Website', orders_desktop_web::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, 'Orders - Mobile Website', orders_mobile_web::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, 'Orders - Others', orders_others::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, 'Conversion - Overall %', conversion_overall_pct::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, 'Conversion - App %', conversion_app_pct::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, 'Conversion - Desktop Web %', conversion_desktop_web_pct::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, 'Conversion - Mobile Web %', conversion_mobile_web_pct::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, '% Orders - App', pct_orders_app::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, '% Orders - Website', pct_orders_website::FLOAT FROM leads_conversion_metrics
UNION ALL SELECT month, '% Orders - LMS', pct_orders_others::FLOAT FROM leads_conversion_metrics

-- Get a Call CTR (1 metric)
UNION ALL SELECT month, 'Get a Call CTR', gac_ctr_pct::FLOAT FROM gac_ctr_metrics

-- CAC post trip started (1 metric)
UNION ALL SELECT month, 'CAC post trip started', cac_post_trip_started_pct::FLOAT FROM cac_post_trip_started_metrics

-- vendor earnings distribution by bucket (5 metrics)
UNION ALL SELECT month, 'Vendor earnings distribution by bucket - GoldPlus', revenue_pct_goldplus::FLOAT FROM vendor_earnings_bucket_metrics
UNION ALL SELECT month, 'Vendor earnings distribution by bucket - Gold', revenue_pct_gold::FLOAT FROM vendor_earnings_bucket_metrics
UNION ALL SELECT month, 'Vendor earnings distribution by bucket - Silver', revenue_pct_silver::FLOAT FROM vendor_earnings_bucket_metrics
UNION ALL SELECT month, 'Vendor earnings distribution by bucket - Bronze', revenue_pct_bronze::FLOAT FROM vendor_earnings_bucket_metrics
UNION ALL SELECT month, 'Vendor earnings distribution by bucket - New', revenue_pct_new::FLOAT FROM vendor_earnings_bucket_metrics

ORDER BY 1, 2;

-- Sanity check:
-- SELECT COUNT(*), COUNT(DISTINCT month), COUNT(DISTINCT metric) FROM DEV_ELDORIA.MART.PNM_MBR_MONTHLY_METRICS;
-- Expect: 129 distinct metrics.
