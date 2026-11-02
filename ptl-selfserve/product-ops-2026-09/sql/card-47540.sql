-- Card 47540 (PTL Batching Opportunity) native SQL, extracted 2026-10-09.
-- Substitutions: {{granularity}} -> 'month'; optional [[customer_type]]/[[new_repeat]] blocks dropped;
-- commented section A removed; final WHERE narrowed to Aug-Sep 2026 pickup dates (post-window, so no effect on window metrics).
-- Reason: execute_card connection lost (card avg runtime ~87s).
WITH combo_candidates AS (
    SELECT
        TRIM(REPLACE(REPLACE(f.value::STRING, '''', ''), '"', ''))  AS order_ext_id,
        vcl."ordered_order_ids" AS combo_key,
        vcl."order_count" AS order_count,
        vcl."inserted_at" AS combo_seen_at,
        ROW_NUMBER() OVER (
            PARTITION BY TRIM(REPLACE(REPLACE(f.value::STRING, '''', ''), '"', ''))
            ORDER BY vcl."order_count" DESC, vcl."inserted_at" DESC
        ) AS combo_rank
    FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_VALID_COMBO_LOGS vcl,
         LATERAL FLATTEN(INPUT => SPLIT(vcl."ordered_order_ids", ',')) f
    WHERE vcl."ordered_order_ids" IS NOT NULL
      AND vcl."order_count" > 1
),
combo_orders AS (
    SELECT order_ext_id, combo_key AS locked_combo_key, order_count AS locked_combo_size, combo_seen_at AS first_combo_at
    FROM combo_candidates WHERE combo_rank = 1
),
combo_members AS (
    SELECT co.locked_combo_key,
           TRIM(REPLACE(REPLACE(member.value::STRING, '''', ''), '"', '')) AS member_order_id
    FROM (SELECT DISTINCT locked_combo_key FROM combo_orders) co,
         LATERAL FLATTEN(INPUT => SPLIT(co.locked_combo_key, ',')) member
),
combo_achievability AS (
    SELECT cm.locked_combo_key,
           SUM(CASE WHEN o.state = 3 THEN 1 ELSE 0 END) AS completed_members,
           CASE WHEN SUM(CASE WHEN o.state = 3 THEN 1 ELSE 0 END) >= 2 THEN 1 ELSE 0 END AS has_viable_partner
    FROM combo_members cm
    JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDERS o ON cm.member_order_id = o.external_id
    GROUP BY 1
),
orders_ist AS (
    SELECT o.id, o.external_id, o.route_id, o.state,
           o.created_at + INTERVAL '330 minutes' AS created_ist,
           o.pickup_slot_start + INTERVAL '330 minutes' AS slot_start_ist,
           o.pickup_slot_end + INTERVAL '330 minutes' AS slot_end_ist,
           DATE(o.pickup_slot_end + INTERVAL '330 minutes') AS pickup_date
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS o
),
order_combo AS (
    SELECT o.*,
           CASE WHEN ca.has_viable_partner = 1 THEN 1 ELSE 0 END AS is_clubbable,
           co.locked_combo_key, co.locked_combo_size, co.first_combo_at
    FROM orders_ist o
    LEFT JOIN combo_orders co ON o.external_id = co.order_ext_id
    LEFT JOIN combo_achievability ca ON co.locked_combo_key = ca.locked_combo_key
),
multi_batches AS (
    SELECT o.external_id AS order_ext_id, b.id AS batch_id,
           b.created_at + INTERVAL '330 minutes' AS batch_created_ist,
           DATE(o.pickup_slot_start + INTERVAL '330 minutes') AS pickup_date,
           o.route_id,
           ROW_NUMBER() OVER (PARTITION BY o.external_id ORDER BY b.created_at DESC) AS rn
    FROM PROD_CURATED.PARTLOAD_APPLICATION.BATCH_V1 b
    JOIN PROD_CURATED.PARTLOAD_APPLICATION.BATCHED_ORDERS_V1 bo ON bo.batch_id = b.id
    JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDERS o ON o.id = bo.order_id AND o.state = 3
    QUALIFY COUNT(DISTINCT o.external_id) OVER (PARTITION BY b.id) > 1
),
final_multi AS (SELECT * FROM multi_batches WHERE rn = 1),
day_route AS (
    SELECT oc.pickup_date, oc.route_id, oc.id AS order_id, oc.external_id, oc.state,
           oc.created_ist, oc.slot_start_ist, oc.is_clubbable, oc.locked_combo_key,
           oc.locked_combo_size, oc.first_combo_at, fm.batch_id AS clubbed_batch_id,
           CASE WHEN oc.state = 3
                 AND COUNT(CASE WHEN oc.state = 3 THEN 1 END) OVER (PARTITION BY oc.route_id, oc.pickup_date) >= 2
                THEN 1 ELSE 0 END AS is_opportunity_clubbable
    FROM order_combo oc
    LEFT JOIN final_multi fm ON fm.order_ext_id = oc.external_id
)
SELECT
    TO_CHAR(DATE_TRUNC('month', pickup_date), 'YYYY-MM') AS month,
    COUNT(DISTINCT external_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN state=3 THEN external_id END) AS completed,
    COUNT(DISTINCT CASE WHEN state=3 AND is_opportunity_clubbable=1 THEN order_id END) AS opportunity_clubbable,
    COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 THEN order_id END) AS engine_clubbable,
    COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 AND clubbed_batch_id IS NOT NULL THEN order_id END) AS clubbed,
    COUNT(DISTINCT CASE WHEN state=3 AND is_clubbable=1 AND clubbed_batch_id IS NULL THEN order_id END) AS gap_orders,
    COUNT(DISTINCT CASE WHEN state=3 AND clubbed_batch_id IS NOT NULL THEN order_id END) AS actual_clubbed_total,
    ROUND(100.0 * clubbed / NULLIF(engine_clubbable, 0), 1) AS current_club_pct,
    ROUND(100.0 * engine_clubbable / NULLIF(completed, 0), 1) AS potential_pct,
    ROUND(100.0 * clubbed / NULLIF(completed, 0), 1) AS realized_pct,
    ROUND(100.0 * gap_orders / NULLIF(engine_clubbable, 0), 1) AS gap_pct,
    ROUND(100.0 * opportunity_clubbable / NULLIF(completed, 0), 1) AS opportunity_pct,
    ROUND(100.0 * opportunity_clubbable / NULLIF(completed, 0), 1) - ROUND(100.0 * clubbed / NULLIF(completed, 0), 1) AS gap_pct_actual
FROM day_route
WHERE pickup_date >= '2026-08-01' AND pickup_date < '2026-10-01'
GROUP BY 1
ORDER BY 1 DESC;
