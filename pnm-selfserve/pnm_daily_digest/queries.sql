-- ============================================================
-- PNM Leadership Digest — Master Query Reference
-- All metrics, organized by group. Swap the literal date below
-- for a fresh refresh. Report policy: always report_date = yesterday.
-- ============================================================

-- Set this to yesterday's date before running anything below.
-- Every query in this file uses '2026-09-28'::DATE as report_date —
-- find/replace that literal to refresh.

-- ============================================================
-- ============================================================
-- REFRESH 2026-09-28 NOTES (definitions confirmed/fixed this refresh)
--  * Periods: MTD this 09-01..09-28, MTD last 08-01..08-28, WTD this = 09-28 only, WTD last = 09-21 only
--    (Monday refresh: same-weekday like-for-like). WTD-this NOT colour-coded this refresh (user instruction).
--  * SUPERSEDED 30 Sep: 3m/6m avg = mean of previous 3/6 months over the same days as MTD. Live SQL is in sql/*.sql
--    (rendered by render_sql.py); this file is the historical reference only.
--  * Order channel (for Conversion by channel / % Orders by channel): FACT_PNM_ORDERS.sr_id ->
--    RAW.PNM_APPLICATION_OPPORTUNITIES.sr_id (latest per sr_id) -> DIM_PNM_OPPORTUNITY channel CASE; unmatched -> Mobile Website.
--  * % orders fare increased / Median fare increase: date basis DATE(shifting_started_ts_ist), NOW Nano-excluded
--    (package_name NOT ILIKE 'Nano%' AND is_test_user=0 on numerator AND denominator). Previous page included Nano.
--  * Edits & Add-ons: date basis ORDER_CREATED_TS_IST, order_status='completed', Nano excluded (incl. Add-on Adoption,
--    which matches the MTD values the page showed; the old add-on 6mo hover baseline did not use these filters).
--  * Trip Duration: date basis SHIFTING_TS_IST.
--  * Damage %: numerator = damage tickets (by ticket date) whose crn is an intra-city, completed, non-Nano order.
--  * TPO Key Metrics: original MTD query (ticket window from MTD-last start). Group/City TPO: ticket window from 03-30.
--  * City x BHK: city via DIM_GEO_REGIONS on pickup_geo_region_id; cur = MTD this, base = pooled 03-30..09-27;
--    Orders base scaled (pooled/26)*(28/7). Leads-by-city excludes leads with NULL pickup_geo_region_id (noted on page).
-- ============================================================

-- GROUP: KEY METRICS (11 metrics, MTD-this vs MTD-last basis, ±10% tolerance)
-- ============================================================

-- Leads / Orders / Conversion — Overall
WITH leads AS (
    SELECT fpo.opp_id,
        CASE WHEN DATE(fpo.opp_created_ts) BETWEEN DATE_TRUNC('month','2026-09-28'::DATE) AND '2026-09-28'::DATE THEN 'mtd_this'
             WHEN DATE(fpo.opp_created_ts) BETWEEN DATE_TRUNC('month',DATEADD(month,-1,'2026-09-28'::DATE)) AND DATEADD(month,-1,'2026-09-28'::DATE) THEN 'mtd_last' END AS mtd_p
    FROM PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY fpo
    LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY dpo ON dpo.opp_id = fpo.opp_id
    WHERE dpo.user_flag ILIKE 'normal' AND (dpo.shifting_type = 'intra_city' OR dpo.shifting_type IS NULL)
      AND DATE(fpo.opp_created_ts) BETWEEN DATEADD(month,-1,DATE_TRUNC('month','2026-09-28'::DATE)) AND '2026-09-28'::DATE
),
orders AS (
    SELECT o.order_id,
        CASE WHEN DATE(o.o_created_ts) BETWEEN DATE_TRUNC('month','2026-09-28'::DATE) AND '2026-09-28'::DATE THEN 'mtd_this'
             WHEN DATE(o.o_created_ts) BETWEEN DATE_TRUNC('month',DATEADD(month,-1,'2026-09-28'::DATE)) AND DATEADD(month,-1,'2026-09-28'::DATE) THEN 'mtd_last' END AS mtd_p
    FROM PROD_ELDORIA.CORE.FACT_PNM_ORDERS o
    INNER JOIN PROD_ELDORIA.MART.PNM_CUSTOMERS pc ON pc.customer_mobile = o.customer_mobile
    LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_ORDERS dpord ON dpord.order_id = o.order_id
    WHERE dpord.user_flag ILIKE 'normal' AND dpord.shifting_type = 'intra_city' AND (o.crn LIKE '%PNM%')
      AND DATE(o.o_created_ts) BETWEEN DATEADD(month,-1,DATE_TRUNC('month','2026-09-28'::DATE)) AND '2026-09-28'::DATE
)
SELECT 'leads' t, mtd_p, COUNT(DISTINCT opp_id) cnt FROM leads WHERE mtd_p IS NOT NULL GROUP BY mtd_p
UNION ALL
SELECT 'orders' t, mtd_p, COUNT(DISTINCT order_id) FROM orders WHERE mtd_p IS NOT NULL GROUP BY mtd_p;
-- Conversion% = orders/leads*100

-- AOV / % orders with surge
WITH fare AS (
    SELECT order_id, total_order_fare, order_status, package_name, is_test_user, booking_surge_multiplier,
        CASE WHEN DATE(order_updated_at_ist) BETWEEN DATE_TRUNC('month','2026-09-28'::DATE) AND '2026-09-28'::DATE THEN 'mtd_this'
             WHEN DATE(order_updated_at_ist) BETWEEN DATE_TRUNC('month',DATEADD(month,-1,'2026-09-28'::DATE)) AND DATEADD(month,-1,'2026-09-28'::DATE) THEN 'mtd_last' END AS mtd_p
    FROM PROD_ELDORIA.MART.PNM_FARE_MOVEMENT
    WHERE service_type_bucket='intracity'
      AND DATE(order_updated_at_ist) BETWEEN DATEADD(month,-1,DATE_TRUNC('month','2026-09-28'::DATE)) AND '2026-09-28'::DATE
)
SELECT mtd_p,
  ROUND(SUM(CASE WHEN order_status='completed' AND package_name NOT ILIKE 'Nano%' AND is_test_user=0 THEN total_order_fare END)/NULLIF(COUNT(DISTINCT CASE WHEN order_status='completed' AND package_name NOT ILIKE 'Nano%' AND is_test_user=0 THEN order_id END),0),0) AS aov
FROM fare WHERE mtd_p IS NOT NULL GROUP BY mtd_p ORDER BY 1;

-- Surge% uses is_nano_order=0 (NOT package_name pattern) — separate query for exact consistency:
SELECT
  CASE WHEN order_created_date BETWEEN DATE_TRUNC('month','2026-09-28'::DATE) AND '2026-09-28'::DATE THEN 'mtd_this'
       WHEN order_created_date BETWEEN DATE_TRUNC('month',DATEADD(month,-1,'2026-09-28'::DATE)) AND DATEADD(month,-1,'2026-09-28'::DATE) THEN 'mtd_last' END AS mtd_p,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN booking_surge_multiplier<>1 AND booking_surge_multiplier IS NOT NULL THEN order_id END)/NULLIF(COUNT(DISTINCT order_id),0),2) AS surge_pct
FROM PROD_ELDORIA.MART.PNM_FARE_MOVEMENT
WHERE service_type_bucket = 'intracity' AND is_nano_order = 0
  AND order_created_date BETWEEN DATEADD(month,-1,DATE_TRUNC('month','2026-09-28'::DATE)) AND '2026-09-28'::DATE
GROUP BY 1 HAVING mtd_p IS NOT NULL ORDER BY 1;

-- Cancellation % (=CAC+PAC+PoAC combined) / Deallocation %
WITH base AS (
    SELECT order_id, cancellation_type, is_deallocated_post_accept,
        CASE WHEN TO_DATE(shifting_ts_ist) BETWEEN DATE_TRUNC('month','2026-09-28'::DATE) AND '2026-09-28'::DATE THEN 'mtd_this'
             WHEN TO_DATE(shifting_ts_ist) BETWEEN DATE_TRUNC('month',DATEADD(month,-1,'2026-09-28'::DATE)) AND DATEADD(month,-1,'2026-09-28'::DATE) THEN 'mtd_last' END AS mtd_p
    FROM PROD_ELDORIA.MART.PNM_ALLOCATION
    WHERE shifting_type='intra_city' AND is_nano_order=0 AND is_test_user=0
      AND TO_DATE(shifting_ts_ist) BETWEEN DATEADD(month,-1,DATE_TRUNC('month','2026-09-28'::DATE)) AND '2026-09-28'::DATE
)
SELECT mtd_p,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN cancellation_type IN ('CAC','PAC','PoAC') THEN order_id END)/NULLIF(COUNT(DISTINCT order_id),0),2) AS cancel_pct,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN is_deallocated_post_accept=1 THEN order_id END)/NULLIF(COUNT(DISTINCT order_id),0),2) AS dealloc_pct
FROM base WHERE mtd_p IS NOT NULL GROUP BY mtd_p ORDER BY 1;

-- On Time Arrival % — Card #37409 definition (authoritative; supersedes any PNM_SUPPORT.ON_TIME_ARRIVAL_FLAG version)
WITH orders AS (
    SELECT fpo.order_id, fpo.SHIFTING_TS, fpo.o_completed_ts, dpo.package_name, dpo.order_status, dpo.sr_id,
        CASE WHEN DATE(fpo.o_completed_ts) BETWEEN DATE_TRUNC('month','2026-09-28'::DATE) AND '2026-09-28'::DATE THEN 'mtd_this'
             WHEN DATE(fpo.o_completed_ts) BETWEEN DATE_TRUNC('month',DATEADD(month,-1,'2026-09-28'::DATE)) AND DATEADD(month,-1,'2026-09-28'::DATE) THEN 'mtd_last' END AS mtd_p
    FROM prod_eldoria.core.FACT_PNM_ORDERS fpo
    LEFT JOIN prod_eldoria.core.DIM_PNM_ORDERS dpo ON dpo.ORDER_ID = fpo.ORDER_ID
    WHERE DATE(fpo.o_completed_ts) BETWEEN DATEADD(month,-1,DATE_TRUNC('month','2026-09-28'::DATE)) AND '2026-09-28'::DATE
      AND dpo.shifting_type = 'intra_city'
),
pickup_loc AS (
    SELECT sr_id, location AS pickup_location FROM dev_eldoria.raw.pnm_application_sr_location_details
    WHERE location_type = 0 QUALIFY ROW_NUMBER() OVER (PARTITION BY sr_id ORDER BY id DESC) = 1
),
ts AS (
    SELECT sa.order_id, sa.event_ts_ist AS event_ts, sa.location AS event_location,
        RANK() OVER (PARTITION BY sa.order_id, sa.action ORDER BY sa.event_ts_ist DESC) AS rk
    FROM dev_eldoria.raw.pnm_application_supervisor_actions sa WHERE sa.action = 'ShiftingStarted'
),
dump AS (
    SELECT o.*, pl.pickup_location, ts.event_ts, ts.event_location
    FROM orders o LEFT JOIN pickup_loc pl ON o.sr_id = pl.sr_id LEFT JOIN ts ON o.order_id = ts.order_id AND ts.rk = 1
),
ota_calc AS (
    SELECT dump.*,
        CASE
            WHEN order_status='completed' AND package_name NOT ILIKE 'Nano%' AND event_ts IS NOT NULL
                 AND DATEDIFF(SECONDS, shifting_ts, event_ts) / 60 < 30 AND ST_DISTANCE(pickup_location, event_location) / 1000 < 2
            THEN 'On_Time'
            WHEN order_status='completed' AND package_name NOT ILIKE 'Nano%' AND event_ts IS NULL THEN 'Unset'
            ELSE 'Delay'
        END AS group_type
    FROM dump
)
SELECT mtd_p,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN group_type='On_Time' THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_status='completed' AND package_name NOT ILIKE 'Nano%' THEN order_id END),0),2) AS ota_pct
FROM ota_calc WHERE mtd_p IS NOT NULL GROUP BY mtd_p ORDER BY 1;

-- TPO — Overall
WITH orders_p AS (
    SELECT crn, order_id,
        CASE WHEN DATE(completed_ts_ist) BETWEEN DATE_TRUNC('month','2026-09-28'::DATE) AND '2026-09-28'::DATE THEN 'mtd_this'
             WHEN DATE(completed_ts_ist) BETWEEN DATE_TRUNC('month',DATEADD(month,-1,'2026-09-28'::DATE)) AND DATEADD(month,-1,'2026-09-28'::DATE) THEN 'mtd_last' END AS mtd_p
    FROM PROD_ELDORIA.MART.PNM_SUPPORT
    WHERE package_name NOT ILIKE '%Nano%' AND shifting_type = 'intra_city'
      AND DATE(completed_ts_ist) BETWEEN DATEADD(month,-1,DATE_TRUNC('month','2026-09-28'::DATE)) AND '2026-09-28'::DATE
),
tkt_p AS (
    SELECT hst.ticket_number, o.mtd_p
    FROM PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS hst
    JOIN orders_p o ON hst.crn = o.crn
    WHERE COALESCE(hst.raised_by,'')!='Detractor'
      AND DATE(hst.created_at + interval '5 hours, 30 minutes') BETWEEN DATEADD(month,-1,DATE_TRUNC('month','2026-09-28'::DATE)) AND '2026-09-28'::DATE
)
SELECT o.mtd_p, ROUND(t.tkts/NULLIF(o.orders,0),2) AS tpo
FROM (SELECT mtd_p, COUNT(DISTINCT crn) AS orders FROM orders_p WHERE mtd_p IS NOT NULL GROUP BY mtd_p) o
LEFT JOIN (SELECT mtd_p, COUNT(DISTINCT ticket_number) AS tkts FROM tkt_p WHERE mtd_p IS NOT NULL GROUP BY mtd_p) t ON t.mtd_p=o.mtd_p
ORDER BY o.mtd_p;

-- NPS / Detractors % — Overall (ORDER_COMPLETED_TS_IST basis)
WITH base AS (
    SELECT order_id, classification,
        CASE WHEN order_completed_ts_ist::date BETWEEN DATE_TRUNC('month','2026-09-28'::DATE) AND '2026-09-28'::DATE THEN 'mtd_this'
             WHEN order_completed_ts_ist::date BETWEEN DATE_TRUNC('month',DATEADD(month,-1,'2026-09-28'::DATE)) AND DATEADD(month,-1,'2026-09-28'::DATE) THEN 'mtd_last' END AS mtd_p
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
    WHERE package_name NOT ILIKE 'Nano%' AND shifting_type = 'intra_city' AND order_status='completed'
      AND order_completed_ts_ist::date BETWEEN DATEADD(month,-1,DATE_TRUNC('month','2026-09-28'::DATE)) AND '2026-09-28'::DATE
)
SELECT mtd_p,
  CASE WHEN COUNT(DISTINCT CASE WHEN classification IS NOT NULL THEN order_id END) > 0
    THEN ROUND(100.0*COUNT(DISTINCT CASE WHEN classification='Promoter' THEN order_id END)/COUNT(DISTINCT CASE WHEN classification IS NOT NULL THEN order_id END)
             - 100.0*COUNT(DISTINCT CASE WHEN classification='Detractor' THEN order_id END)/COUNT(DISTINCT CASE WHEN classification IS NOT NULL THEN order_id END),2)
    ELSE NULL END AS nps,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN classification='Detractor' THEN order_id END)/NULLIF(COUNT(DISTINCT order_id),0),2) AS detr
FROM base WHERE mtd_p IS NOT NULL GROUP BY mtd_p ORDER BY 1;


-- ============================================================
-- GROUP: LEADS & ORDERS (Nano INCLUDED — only exception to Nano-excluded rule)
-- Same leads/orders CTEs as Key Metrics, but broken out by channel
-- (App / Website Desktop / Website Mobile / Generic-LMS) and by
-- MTD+WTD, plus city breakdown. Channel logic:
--   dpo.source_details = 'Desktop Website' -> 'Website (Desktop)'
--   dpo.source_details = 'Mobile Website'  -> 'Website (Mobile)'
--   dpo.source IN (1,2,3)                  -> 'App'
--   dpo.source = 4                          -> 'Generic'
--   ELSE                                    -> 'Website (Mobile)'
-- 6-month baseline: same CTEs, date window DATEADD(week,-27,DATE_TRUNC('week',report_date))
--   to DATEADD(week,-1,DATE_TRUNC('week',report_date)), weekly P50.
-- Booked Orders (Nano excluded) adds: dpord.package_name NOT ILIKE 'Nano%'
-- % Orders by channel = orders_by_channel / total_orders * 100, no RAG (channel mix has no direction)
-- (Full CTEs identical in shape to Key Metrics' leads/orders block above — just add
--  opp_source/GROUP BY city_group where needed. See conversation history for exact text
--  if reconstructing city-level cut.)


-- ============================================================
-- GROUP: PRICING (Nano EXCLUDED, all 6 metrics)
-- ============================================================
-- AOV, % fare increased, Median fare increase — PNM_FARE_MOVEMENT, package_name NOT ILIKE 'Nano%'
-- + is_test_user=0, fare_delta>0 for increase metrics, shifting_started_ts_ist IS NOT NULL as denominator
-- % surge / +ve / -ve surge — PNM_FARE_MOVEMENT, is_nano_order=0 (see Key Metrics block above)
-- +ve surge = higher-is-better (revenue), -ve surge = lower-is-better
-- KNOWN ISSUE: -ve surge's 6mo baseline is artificially low — discounting didn't exist
--   in the earlier months of the 6-month window. Confirmed via raw distribution check
--   (early Aug: every booking_surge_multiplier >= 1.0, zero negative-surge orders).
--   Treat any metric tied to a recently-launched behavior with this same suspicion.


-- ============================================================
-- GROUP: ALLOCATION & COMPLETION (22 metrics)
-- Nano EXCLUDED except: Allocation%, Deallocation%, %no vendor before slot,
--   Reschedule%, %>2 deallocations, %supervisor changed — these have no Nano
--   filter in PNM_ALLOCATION's source columns.
-- Source: PROD_ELDORIA.MART.PNM_ALLOCATION, shifting_type='intra_city'
-- Key columns: is_allocated, is_deallocated_post_accept, order_status, order_bucket
--   (SPOT/SCHEDULED), dry_run_distance_kms, cancellation_type (CAC/PAC/PoAC),
--   allocation_tat_minutes, no_vendor_before_slot, last_rescheduled_shift_ts,
--   deallocation_count, is_supervisor_changed, pickup_km_deviation, drop_km_deviation
-- % supervisor changed excludes package_name IN ('Nano Shifting','Nano Shifting Large','Nano Shifting Medium')
-- Percentiles: Dry Run P75, Allocation Time P80, Pickup/Drop Deviation P80
WITH g4_periods AS (
    SELECT
        CASE WHEN TO_DATE(shifting_ts_ist) BETWEEN DATE_TRUNC('month','2026-09-28'::DATE) AND '2026-09-28'::DATE THEN 'mtd_this'
             WHEN TO_DATE(shifting_ts_ist) BETWEEN DATE_TRUNC('month',DATEADD(month,-1,'2026-09-28'::DATE)) AND DATEADD(month,-1,'2026-09-28'::DATE) THEN 'mtd_last' END AS mtd_p,
        order_id, is_allocated, is_deallocated_post_accept, order_status, order_bucket, is_nano_order, is_test_user,
        dry_run_distance_kms, cancellation_type, allocation_tat_minutes, no_vendor_before_slot, last_rescheduled_shift_ts,
        deallocation_count, is_supervisor_changed, package_name, pickup_km_deviation, drop_km_deviation
    FROM PROD_ELDORIA.MART.PNM_ALLOCATION
    WHERE shifting_type = 'intra_city'
      AND TO_DATE(shifting_ts_ist) BETWEEN DATEADD(month,-1,DATE_TRUNC('month','2026-09-28'::DATE)) AND '2026-09-28'::DATE
)
SELECT mtd_p,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN order_bucket='SPOT' AND is_allocated=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SPOT' THEN order_id END),0),2) AS alloc_spot,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN order_bucket='SCHEDULED' AND is_allocated=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SCHEDULED' THEN order_id END),0),2) AS alloc_sched,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN is_deallocated_post_accept=1 THEN order_id END)/NULLIF(COUNT(DISTINCT order_id),0),2) AS dealloc_overall,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN order_status='completed' AND is_nano_order=0 AND is_test_user=0 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN is_nano_order=0 AND is_test_user=0 THEN order_id END),0),2) AS comp_overall,
  ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY CASE WHEN order_bucket='SPOT' AND is_nano_order=0 AND is_test_user=0 THEN dry_run_distance_kms END),2) AS dry_run_p75,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN cancellation_type='CAC' AND order_bucket='SPOT' AND is_nano_order=0 AND is_test_user=0 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SPOT' AND is_nano_order=0 AND is_test_user=0 THEN order_id END),0),2) AS cac_spot,
  ROUND(PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY CASE WHEN is_allocated=1 THEN allocation_tat_minutes END),2) AS alloc_time_p80,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN no_vendor_before_slot=1 THEN order_id END)/NULLIF(COUNT(DISTINCT order_id),0),2) AS pct_no_vendor,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN last_rescheduled_shift_ts IS NOT NULL AND is_nano_order=0 AND is_test_user=0 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN is_nano_order=0 AND is_test_user=0 THEN order_id END),0),2) AS reschedule_pct,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN deallocation_count>2 THEN order_id END)/NULLIF(COUNT(DISTINCT order_id),0),2) AS pct_2plus_dealloc,
  ROUND(100.0*COUNT(DISTINCT CASE WHEN is_supervisor_changed=1 AND order_status='completed' AND package_name NOT IN ('Nano Shifting','Nano Shifting Large','Nano Shifting Medium') AND is_test_user=0 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_status='completed' AND package_name NOT IN ('Nano Shifting','Nano Shifting Large','Nano Shifting Medium') AND is_test_user=0 THEN order_id END),0),2) AS pct_sup_changed,
  ROUND(PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY CASE WHEN order_status='completed' AND is_nano_order=0 AND is_test_user=0 THEN pickup_km_deviation END),2) AS pickup_dev_p80,
  ROUND(PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY CASE WHEN order_status='completed' AND is_nano_order=0 AND is_test_user=0 THEN drop_km_deviation END),2) AS drop_dev_p80
FROM g4_periods WHERE mtd_p IS NOT NULL GROUP BY mtd_p ORDER BY mtd_p;
-- Remaining columns (dealloc_spot/sched, comp_spot/sched, PAC/PoAC SPOT+Scheduled x3, CAC/PAC/PoAC
-- Scheduled) follow the exact same CASE-filter pattern, just swapping the bucket/cancellation_type value.


-- ============================================================
-- GROUP: TRIP DURATION (6 metrics, Nano EXCLUDED)
-- No RAG — plain delta vs 6mo avg. Source: PNM_EXPERIENCE, ORDER_STATUS='completed',
-- PACKAGE_NAME NOT ILIKE 'Nano%', SHIFTING_TYPE='intra_city'. All PERCENTILE_CONT(0.8).
-- Stages (DATEDIFF minutes between):
--   S1: VENDOR_OWNER_ACCEPTED_TS_IST -> SUPERVISOR_ACCEPTED_TS_IST
--   S2: SUPERVISOR_ACCEPTED_TS_IST -> TRIP_STARTED_TS_IST
--   S3: TRIP_STARTED_TS_IST -> SHIFTING_STARTED_TS_IST
--   S4: SHIFTING_STARTED_TS_IST -> PICKUP_COMPLETED_TS_IST
--   S5: PICKUP_COMPLETED_TS_IST -> ORDER_COMPLETED_TS_IST
--   S6 (full): SHIFTING_STARTED_TS_IST -> ORDER_COMPLETED_TS_IST
-- KNOWN FINDING: S1 (~2400-2700 min, 40-46hrs) is NOT a bug — genuinely bimodal
--   distribution (32% get supervisor within 1hr, ~30% take 1+ day), consistent with
--   Scheduled/advance-booked orders where vendor accepts days before shift.


-- ============================================================
-- GROUP: EDITS & ADD-ONS (5 metrics, Nano EXCLUDED)
-- Source: PNM_EXPERIENCE, ORDER_STATUS='completed', PACKAGE_NAME NOT ILIKE 'Nano%'
--   IS_MODIFICATION_DONE='Yes' -> % orders edited
--   HAS_SUPPORT_EDIT=1 -> % support-edited
--   HAS_LOCATION_EDIT=1 -> % location modified
--   SUM(EDITS_AFTER_SHIFTING)/SUM(NO_OF_SUCCESSFUL_EDITS) -> % edits after shifting
--   Add-on Adoption %: ADD_ONS IS NOT NULL AND ADD_ONS != '' (NOTE: no Nano filter,
--     no order_status filter — uses whole SHIFTING_TYPE='intra_city' population)
-- KNOWN FINDING: ~87-98% Add-on Adoption is real, not a bug — only ~17% of orders
--   have a genuinely empty ADD_ONS field; basic packing is near-default for this service.


-- ============================================================
-- GROUP: CUSTOMER EXPERIENCE (3 metrics + vendor-bucket breakdown)
-- Nano EXCLUDED. TWO DIFFERENT DATE BASES (deliberate, per instruction):
--   Completion Score: anchored on SHIFTING_TS_IST (needs non-completed orders in denominator too)
--   NPS / Detractors %: anchored on ORDER_COMPLETED_TS_IST
-- Completion Score: PNM_EXPERIENCE, completed/vendor-assigned ratio
WITH g12_periods AS (
    SELECT
        CASE WHEN shifting_ts_ist::date BETWEEN DATE_TRUNC('month','2026-09-28'::DATE) AND '2026-09-28'::DATE THEN 'mtd_this'
             WHEN shifting_ts_ist::date BETWEEN DATE_TRUNC('month',DATEADD(month,-1,'2026-09-28'::DATE)) AND DATEADD(month,-1,'2026-09-28'::DATE) THEN 'mtd_last' END AS mtd_p,
        order_id, vendor_id, order_status
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
    WHERE package_name NOT ILIKE 'Nano%' AND shifting_type = 'intra_city'
      AND shifting_ts_ist::date BETWEEN DATEADD(month,-1,DATE_TRUNC('month','2026-09-28'::DATE)) AND '2026-09-28'::DATE
)
SELECT mtd_p, ROUND(100.0*COUNT(DISTINCT CASE WHEN order_status='completed' THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN vendor_id IS NOT NULL THEN order_id END),0),2) comp
FROM g12_periods WHERE mtd_p IS NOT NULL GROUP BY mtd_p ORDER BY mtd_p;
-- NPS/Detractors query: same shape as Key Metrics block above (ORDER_COMPLETED_TS_IST basis).
-- Bucket breakdown: add COALESCE(vendor_bucket_type,'Unknown') AS vendor_bucket to SELECT+GROUP BY.
--   VENDOR_BUCKET_TYPE lives directly on PNM_EXPERIENCE — already point-in-time correct,
--   no join to DIM_PNM_VENDOR needed (that table's BUCKET_TYPE/BUCKET_START_DATE/END_DATE
--   requires a fan-out-prone point-in-time join; PNM_EXPERIENCE's column avoids that entirely).


-- ============================================================
-- GROUP: FULFILLMENT TIMING (2 metrics, Nano EXCLUDED)
-- Same Card #37409 OTA definition as Key Metrics. Delay >60min uses the same
-- `delay_minutes` CTE column (DATEDIFF(SECONDS,shifting_ts,event_ts)/60.0), thresholded >=60.
-- KNOWN ISSUE (corrected): earlier claim that Delay>60min existed pre-built in
--   PNM_ALLOCATION was WRONG — no delay-duration data exists there. Only buildable
--   via the Card #37409 GPS+timing join (pnm_application_sr_location_details +
--   pnm_application_supervisor_actions), which is what's used above.


-- ============================================================
-- GROUP: ESCALATIONS & DAMAGE (2 metrics, new — not cross-validated independently)
-- ============================================================
-- Social Media Escalation % — sources: PROD_CURATED.GSHEET_SYNC.PNM_SOCIAL_MEDIA_ESCALATIONS_DETAILS
--   + PNM_CEO_ESCALATIONS_DETAILS, joined to FACT_PNM_ORDERS by crn (after CRN normalization:
--   CASE WHEN crn ILIKE '%NM%' OR crn ILIKE '%PM%' THEN 'PNM'||REGEXP_REPLACE(crn,'[^0-9]','') ELSE crn END).
--   NO RAG — absolute counts (3-10/month, 3-4/week) too thin for any color to be signal not noise.
WITH sm_data AS (
    SELECT sm."Order_ID" AS crn, sm."Key_reason" AS Key_reason, sm."Received_Date" AS Received_Date
    FROM PROD_CURATED.GSHEET_SYNC.PNM_SOCIAL_MEDIA_ESCALATIONS_DETAILS sm
    WHERE "Received_Date" != '#N/A' AND (sm."Order_ID" ILIKE '%NM%' OR sm."Order_ID" ILIKE '%PM%')
),
ceo_data AS (
    SELECT sm."Order_ID" AS crn, sm."Key_reason" AS Key_reason, sm."Received_Date" AS Received_Date
    FROM PROD_CURATED.GSHEET_SYNC.PNM_CEO_ESCALATIONS_DETAILS sm
    WHERE "Received_Date" != '#N/A' AND (sm."Order_ID" ILIKE '%NM%' OR sm."Order_ID" ILIKE '%PM%')
),
sm_merged AS (
    SELECT CASE WHEN (sm.crn ILIKE '%NM%' OR sm.crn ILIKE '%PM%') THEN 'PNM' || REGEXP_REPLACE(sm.crn, '[^0-9]', '') ELSE sm.crn END AS crn, Key_reason,
        COALESCE(TRY_TO_DATE(NULLIF(Received_Date,'#N/A'),'DD/MM/YYYY'), TRY_TO_DATE(NULLIF(Received_Date,'#N/A'),'DD-MON-YY'), TRY_TO_DATE(NULLIF(Received_Date,'#N/A'),'MM/DD/YYYY')) AS ticket_ts
    FROM sm_data sm
    UNION ALL
    SELECT CASE WHEN (sm.crn ILIKE '%NM%' OR sm.crn ILIKE '%PM%') THEN 'PNM' || REGEXP_REPLACE(sm.crn, '[^0-9]', '') ELSE sm.crn END AS crn, Key_reason,
        COALESCE(TRY_TO_DATE(NULLIF(Received_Date,'#N/A'),'DD-MON-YY'), TRY_TO_DATE(NULLIF(Received_Date,'#N/A'),'MM/DD/YYYY')) AS ticket_ts
    FROM ceo_data sm
)
SELECT trim(sm.crn)||' - '||trim(sm.Key_reason) AS uuid, sm.ticket_ts
FROM sm_merged sm
JOIN prod_eldoria.core.FACT_PNM_ORDERS fpo ON fpo.crn = sm.crn
LEFT JOIN prod_eldoria.core.DIM_PNM_ORDERS dpo ON dpo.Order_ID = fpo.Order_ID
WHERE dpo.shifting_type = 'intra_city';
-- Divide distinct uuid count in the target period by distinct completed-order crn count (same
-- period, same shifting_type='intra_city' + ORDER_STATUS='completed' filter as elsewhere) *100.

-- Damage % — source: PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS, ACTION_TAKEN='Damage form sent',
--   RAISED_BY='Customer', CRN LIKE '%PNM%'. Has RAG (MTD volume 40-70/month supports it;
--   WTD volume 5-22 still thin, treat with caution).
SELECT a.ticket_number, a.crn, (a.created_at + INTERVAL '330 min') AS tkt_created_at_ist
FROM PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS a
WHERE a.action_taken = 'Damage form sent' AND a.raised_by = 'Customer' AND a.crn LIKE '%PNM%';
-- Divide by completed-order count in the same window (join by crn to FACT_PNM_ORDERS/DIM_PNM_ORDERS,
-- shifting_type='intra_city', package_name NOT ILIKE '%Nano%', ORDER_STATUS='completed').


-- ============================================================
-- GROUP: CITY x BHK CATEGORY (9 metrics x 45 cells + city-only Leads/Conversion)
-- ============================================================
-- City grouping (via DIM_GEO_REGIONS, joined on pickup_geo_region_id):
--   Tier 1 (shown individually): Bangalore, Delhi NCR, Mumbai, Hyderabad, Pune, Chennai, Kolkata, Ahmedabad
--   Everything else -> 'Tier 2 (combined)'   [source of truth: DIM_GEO_REGIONS.TIER]
-- BHK grouping (via package_name, case-insensitive):
--   Nano% or Micro% -> 'Nano/Micro'
--   1 RK% or 1 BHK% -> '1BHK'
--   2 BHK%          -> '2BHK'
--   3 BHK%          -> '3BHK'
--   4 BHK% or 5 BHK% -> '4+BHK'
--   else            -> 'Unknown' (excluded from grid)
-- Leads/Conversion: CITY ONLY, no BHK split — ~26% of leads have no package assigned yet
--   at lead stage, so BHK isn't well-defined for them.
-- All 9 metric grids (Orders booked, AOV, Surge%, Completion%, Deallocation%, OTA%, TPO,
--   NPS, Detractors%) use the SAME city_group/bhk_group CASE expressions as above, joined
--   into each metric's normal source table via DIM_PNM_ORDERS -> DIM_GEO_REGIONS.
-- RAG basis: each cell vs ITS OWN 6-month trailing average (not the network-wide average
--   used elsewhere on the page) — pooled aggregate over 26 weeks, not weekly-percentile
--   (weekly percentile would fragment already-thin cells further).
-- Orders booked baseline: scaled to MTD-equivalent — (6mo pooled count / 26 weeks) * (days_in_MTD/7)
-- Thin-cell threshold: <30 orders MTD in that cell (checked against the Orders grid,
--   reused as the volume proxy for every other metric's same cell).
-- KNOWN FINDING: NPS declines / Detractors % rises monotonically with BHK size, in nearly
--   every city — bigger moves are harder to execute well. Hidden by the network-wide
--   "Overall NPS" aggregate. Small-sample artifacts do occur in 4+BHK cells for smaller
--   cities (e.g. Ahmedabad NPS = -100.00 off a handful of rated orders) — always sanity-check
--   absolute order count before trusting an extreme cell value.
