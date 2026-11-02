-- ============================================================
-- PARTLOAD CLUBBING ANALYSIS  (IST-corrected, v6)
-- Application table = UTC → +330 min for IST
-- PTL_VALID_COMBO_LOGS columns are lowercase-quoted → must use "col" syntax
--
-- STATE MAPPING (confirmed from data):
--   state = 3 → COMPLETED
--   state = 4 → CANCELLED
--
-- DATE FILTER RULE:
--   Always use >= / < on full timestamps, never <= on a date.
--   ✅ pickup_date >= '2026-02-01' AND pickup_date < '2026-03-01'
--   ❌ pickup_date <= '2026-02-28'  ← drops all Feb 28 orders after midnight
--
-- METRIC DEFINITIONS:
--   is_clubbable (v6)        = completed order locked to a combo where AT LEAST ONE
--                              other partner also completed (state=3).
--                              Enforces clubbed ≤ engine_clubbable invariant.
--                              Stricter than v4 (any combo), looser than v5 (all complete).
--   locked_combo_key         = the definitive combo assigned to this order
--   locked_combo_size        = number of orders in the locked combo (2, 3, …)
--   has_viable_partner       = ≥2 members of the locked combo completed (this + 1 partner)
--   is_opportunity_clubbable = completed order on route+date where ≥2 completed orders exist
--                              (no distance/slot cap — pure demand overlap)
--   clubbed_batch_id IS NOT NULL = actually placed in a multi-order batch
--   engine_clubbable         = completed orders with at least 1 other completed combo partner
--   actual_clubbed_total     = all completed orders placed in a multi-order batch
--                              (superset of clubbed — includes ~127/mo with cancelled partners)
--   current_club_pct         = clubbed / engine_clubbable       (execution efficiency)
--   potential_pct            = engine_clubbable / completed      (realistic demand engine sees)
--   realized_pct             = clubbed / completed               (net outcome)
--   gap_pct                  = gap_orders / engine_clubbable     (missed opportunity)
--   opportunity_pct          = opportunity_clubbable / completed  (theoretical max)
--   gap_pct_actual           = opportunity_pct − realized_pct   (headroom vs actuals)
--
-- COMBO ASSIGNMENT:
--   Each order locked to exactly one best combo via ROW_NUMBER():
--   Best = highest order_count first, tie-break by most recent inserted_at.
--   One-order-one-combo enforced per-order (greedy approximation).
--
-- VERSION HISTORY:
--   v4 → is_clubbable = any locked combo (order_count > 1). Feb potential_pct: 82%
--   v5 → is_clubbable = all combo partners completed. Feb potential_pct: 58.8%
--        ❌ breaks invariant: actual_clubbed can exceed engine_clubbable
--   v6 → is_clubbable = ≥1 combo partner completed. Feb potential_pct: 78.9% ✅
--        ✅ clubbed ≤ engine_clubbable always holds
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- BASE CTEs  (shared across all sections)
-- ────────────────────────────────────────────────────────────
WITH combo_candidates AS (
    -- Expand every PTL_VALID_COMBO_LOGS row to one row per (order, combo).
    -- Only keep multi-order combos (order_count > 1).
    -- Rank: best combo = highest order_count, tie-break most recent inserted_at.
    SELECT
        TRIM(REPLACE(REPLACE(f.value::STRING, '''', ''), '"', ''))  AS order_ext_id,
        vcl."ordered_order_ids"                                      AS combo_key,
        vcl."order_count"                                            AS order_count,
        vcl."inserted_at"                                            AS combo_seen_at,
        ROW_NUMBER() OVER (
            PARTITION BY TRIM(REPLACE(REPLACE(f.value::STRING, '''', ''), '"', ''))
            ORDER BY vcl."order_count" DESC, vcl."inserted_at" DESC
        )                                                            AS combo_rank
    FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_VALID_COMBO_LOGS vcl,
         LATERAL FLATTEN(INPUT => SPLIT(vcl."ordered_order_ids", ',')) f
    WHERE vcl."ordered_order_ids" IS NOT NULL
      AND vcl."order_count" > 1
),
combo_orders AS (
    -- Lock each order to exactly one combo (its best-ranked one).
    SELECT
        order_ext_id,
        combo_key     AS locked_combo_key,   -- definitive combo for this order
        order_count   AS locked_combo_size,  -- how many orders in that combo
        combo_seen_at AS first_combo_at      -- when engine produced this combo
    FROM combo_candidates
    WHERE combo_rank = 1
),
combo_members AS (
    -- Expand each unique locked combo to individual member order IDs.
    SELECT
        co.locked_combo_key,
        TRIM(REPLACE(REPLACE(member.value::STRING, '''', ''), '"', '')) AS member_order_id
    FROM (SELECT DISTINCT locked_combo_key FROM combo_orders) co,
         LATERAL FLATTEN(INPUT => SPLIT(co.locked_combo_key, ',')) member
),
combo_achievability AS (
    -- has_viable_partner = 1 if ≥2 members of this combo completed (state=3).
    -- Means: this order + at least 1 real partner = a real clubbing opportunity.
    -- Guarantees clubbed ≤ engine_clubbable invariant holds.
    SELECT
        cm.locked_combo_key,
        SUM(CASE WHEN o.state = 3 THEN 1 ELSE 0 END)          AS completed_members,
        CASE WHEN SUM(CASE WHEN o.state = 3 THEN 1 ELSE 0 END) >= 2
             THEN 1 ELSE 0 END                                 AS has_viable_partner
    FROM combo_members cm
    JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDERS o
        ON cm.member_order_id = o.external_id
    
where 1=1

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY 1
),
orders_ist AS (
    -- Application table stores timestamps in UTC → convert to IST (+330 min)
    SELECT
        o.id, o.external_id, o.route_id, o.state,
		pr.pickup_city,
        o.created_at        + INTERVAL '330 minutes'     AS created_ist,
        o.pickup_slot_start + INTERVAL '330 minutes'     AS slot_start_ist,
        o.pickup_slot_end   + INTERVAL '330 minutes'     AS slot_end_ist,
        DATE(o.pickup_slot_end + INTERVAL '330 minutes') AS pickup_date
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS o
	left join PARTLOAD_ANALYTICS.ptl_routes pr on pr.route_id = o.route_id 
    -- Optional: add WHERE o.route_id = 14 to filter a single route

where 1=1

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
),
order_combo AS (
    -- 1:1 join — pre-deduplicated by combo_orders.
    -- is_clubbable = 1 only when locked combo had ≥1 partner that also completed.
    SELECT
        o.*,
        CASE WHEN ca.has_viable_partner = 1 THEN 1 ELSE 0 END  AS is_clubbable,
        co.locked_combo_key,   -- which combo this order is locked to
        co.locked_combo_size,  -- size of that combo (2, 3, …)
        co.first_combo_at
    FROM orders_ist o
    LEFT JOIN combo_orders co        ON o.external_id = co.order_ext_id
    LEFT JOIN combo_achievability ca ON co.locked_combo_key = ca.locked_combo_key
),
multi_batches AS (
    -- Batches that actually carried more than one completed order
    SELECT
        o.external_id                                               AS order_ext_id,
        b.id                                                        AS batch_id,
        b.created_at + INTERVAL '330 minutes'                       AS batch_created_ist,
        DATE(o.pickup_slot_start + INTERVAL '330 minutes')          AS pickup_date,
        o.route_id,
        ROW_NUMBER() OVER (PARTITION BY o.external_id ORDER BY b.created_at DESC) AS rn
    FROM PROD_CURATED.PARTLOAD_APPLICATION.BATCH_V1 b
    JOIN PROD_CURATED.PARTLOAD_APPLICATION.BATCHED_ORDERS_V1 bo ON bo.batch_id = b.id
    JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDERS o
      ON o.id = bo.order_id AND o.state = 3
    
where 1=1

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
QUALIFY COUNT(DISTINCT o.external_id) OVER (PARTITION BY b.id) > 1
),
final_multi AS (
    SELECT * FROM multi_batches WHERE rn = 1
),
day_route AS (
    -- Order-grain table: all metrics computed here, aggregate above as needed
    SELECT
        oc.pickup_date,
        oc.route_id,
		pickup_city,
        oc.id             AS order_id,
        oc.external_id,
        oc.state,
        oc.created_ist,
        oc.slot_start_ist,
        oc.is_clubbable,
        oc.locked_combo_key,
        oc.locked_combo_size,
        oc.first_combo_at,
        fm.batch_id       AS clubbed_batch_id,
        -- IST-corrected timing
        DATEDIFF('minute', oc.created_ist, oc.slot_start_ist) / 60.0       AS booking_lead_hrs,
        DATEDIFF('minute', oc.first_combo_at, oc.slot_start_ist) / 60.0    AS combo_to_slot_hrs,
        -- Opportunity clubbable: completed order on route+date where ≥2 completed exist
        CASE WHEN oc.state = 3
              AND COUNT(CASE WHEN oc.state = 3 THEN 1 END)
                      OVER (PARTITION BY oc.route_id, oc.pickup_date) >= 2
             THEN 1 ELSE 0 END                                              AS is_opportunity_clubbable
    FROM order_combo oc
    LEFT JOIN final_multi fm ON fm.order_ext_id = oc.external_id
)

-- ============================================================
-- UNCOMMENT THE SECTION YOU WANT TO RUN
-- ============================================================


-- ── A. OVERALL (filtered range) ──────────────────────────────
/*
SELECT
    COUNT(DISTINCT external_id)                                                  AS total_orders,
    COUNT(DISTINCT CASE WHEN state=3 THEN external_id END)                       AS completed,
    COUNT(DISTINCT CASE WHEN state=3 AND is_opportunity_clubbable=1 THEN order_id END) AS opportunity_clubbable,
    COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 THEN order_id END)       AS engine_clubbable,
    COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 AND clubbed_batch_id IS NOT NULL THEN order_id END) AS clubbed,
    COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 AND clubbed_batch_id IS NULL    THEN order_id END) AS gap_orders,
    COUNT(DISTINCT CASE WHEN state=3 AND clubbed_batch_id IS NOT NULL THEN order_id END) AS actual_clubbed_total,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 AND clubbed_batch_id IS NOT NULL THEN order_id END)
                / NULLIF(COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 THEN order_id END), 0), 1) AS current_club_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 THEN order_id END)
                / NULLIF(COUNT(DISTINCT CASE WHEN state=3 THEN external_id END), 0), 1)                 AS potential_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 AND clubbed_batch_id IS NOT NULL THEN order_id END)
                / NULLIF(COUNT(DISTINCT CASE WHEN state=3 THEN external_id END), 0), 1)                 AS realized_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 AND clubbed_batch_id IS NULL    THEN order_id END)
                / NULLIF(COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 THEN order_id END), 0), 1) AS gap_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN state=3 AND is_opportunity_clubbable=1 THEN order_id END)
                / NULLIF(COUNT(DISTINCT CASE WHEN state=3 THEN external_id END), 0), 1)                 AS opportunity_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN state=3 AND is_opportunity_clubbable=1 THEN order_id END)
                / NULLIF(COUNT(DISTINCT CASE WHEN state=3 THEN external_id END), 0), 1)
    - ROUND(100.0 * COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 AND clubbed_batch_id IS NOT NULL THEN order_id END)
                / NULLIF(COUNT(DISTINCT CASE WHEN state=3 THEN external_id END), 0), 1)                 AS gap_pct_actual
FROM day_route
WHERE pickup_date >= {{start_date}}
  AND pickup_date <  {{end_date}};
*/


-- ── B. MONTHLY (Metabase: swap hardcoded values for {{variables}}) ───────────

SELECT
    TO_CHAR(DATE_TRUNC({{granularity}}, pickup_date), 'YYYY-MM')                 AS month,
	pickup_city,
    COUNT(DISTINCT external_id)                                                   AS total_orders,
    COUNT(DISTINCT CASE WHEN state=3 THEN external_id END)                        AS completed,
    COUNT(DISTINCT CASE WHEN state=3 AND is_opportunity_clubbable=1 THEN order_id END) AS opportunity_clubbable,
    COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 THEN order_id END)        AS engine_clubbable,
    COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 AND clubbed_batch_id IS NOT NULL THEN order_id END) AS clubbed,
    COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 AND clubbed_batch_id IS NULL    THEN order_id END) AS gap_orders,
    COUNT(DISTINCT CASE WHEN state=3 AND clubbed_batch_id IS NOT NULL THEN order_id END) AS actual_clubbed_total,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 AND clubbed_batch_id IS NOT NULL THEN order_id END)
                / NULLIF(COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 THEN order_id END), 0), 1) AS current_club_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 THEN order_id END)
                / NULLIF(COUNT(DISTINCT CASE WHEN state=3 THEN external_id END), 0), 1)                 AS potential_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 AND clubbed_batch_id IS NOT NULL THEN order_id END)
                / NULLIF(COUNT(DISTINCT CASE WHEN state=3 THEN external_id END), 0), 1)                 AS realized_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 AND clubbed_batch_id IS NULL    THEN order_id END)
                / NULLIF(COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 THEN order_id END), 0), 1) AS gap_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN state=3 AND is_opportunity_clubbable=1 THEN order_id END)
                / NULLIF(COUNT(DISTINCT CASE WHEN state=3 THEN external_id END), 0), 1)                 AS opportunity_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN state=3 AND is_opportunity_clubbable=1 THEN order_id END)
                / NULLIF(COUNT(DISTINCT CASE WHEN state=3 THEN external_id END), 0), 1)
    - ROUND(100.0 * COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 AND clubbed_batch_id IS NOT NULL THEN order_id END)
                / NULLIF(COUNT(DISTINCT CASE WHEN state=3 THEN external_id END), 0), 1)                 AS gap_pct_actual
FROM day_route
WHERE pickup_date >= '2026-02-01'
and pickup_city in ('Bangalore', 'Mumbai')
GROUP BY 1,2
ORDER BY 1 DESC;
