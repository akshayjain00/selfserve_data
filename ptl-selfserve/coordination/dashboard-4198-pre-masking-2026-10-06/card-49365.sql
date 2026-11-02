-- ⏺ -- ============================================================
  -- BATCH vs ENGINE SUGGESTION MATCH ANALYSIS
  -- Source: ALLOCATION_OSRM_v2_DISTANCE (top 2 suggestions shown to ops)
  -- Only completed orders (state=3)
  --
  -- MATCH TYPES:
  --   FULL_MATCH    = batch members exactly = either of top 2 suggested combos
  --   PARTIAL_MATCH = batch shares ≥2 orders with either top 2 combo
  --   NO_MATCH      = batched, had suggestion, but 0-1 shared orders
  --   NO_SUGGESTION = batched, no OSRM combo existed for this order
  --   NO_BATCH      = completed but never batched
  -- ============================================================

  WITH 

  -- ── STEP 1: Latest OSRM record per combo ─────────────────────
  latest_osrm AS (
      SELECT
          t."combo_id"             AS combo_id,
          t."order_count"          AS order_count,
          t."osrm_pickup_dist_km"  AS osrm_pickup_dist_km,
          t."created_at"           AS created_at
      FROM partload_analytics.ALLOCATION_OSRM_v2_DISTANCE t
      QUALIFY ROW_NUMBER() OVER (
          PARTITION BY t."combo_id"
          ORDER BY t."created_at" DESC
      ) = 1
  ),

  -- ── STEP 2: Expand combo → order level + rank ─────────────────
  -- Mirrors exactly what the ops suggestion UI does:
  -- best combo = most orders first, shortest distance second
  ranked_suggestions AS (
      SELECT
          TRIM(f.value)            AS order_ext_id,
          lo.combo_id              AS raw_combo,
          lo.order_count,
          lo.osrm_pickup_dist_km,
          ROW_NUMBER() OVER (
              PARTITION BY TRIM(f.value)
              ORDER BY lo.order_count DESC, lo.osrm_pickup_dist_km ASC
          ) AS order_rank
      FROM latest_osrm lo,
           LATERAL FLATTEN(INPUT => SPLIT(lo.combo_id, ',')) f
  ),

  -- ── STEP 3: Keep only top 2 per order (what ops sees) ─────────
  top2_suggestions AS (
      SELECT order_ext_id, raw_combo, order_count, osrm_pickup_dist_km
      FROM ranked_suggestions
      WHERE order_rank <= 2
  ),

  -- ── STEP 4: Sorted canonical key for each top-2 combo ─────────
  -- Sorted so "CRN001,CRN002" = "CRN002,CRN001" for matching
  top2_combo_keys AS (
      SELECT
          ts.order_ext_id,
          ts.order_count,
          ts.osrm_pickup_dist_km,
          LISTAGG(TRIM(f.value), ',') WITHIN GROUP (ORDER BY TRIM(f.value)) AS combo_key
      FROM top2_suggestions ts,
           LATERAL FLATTEN(INPUT => SPLIT(ts.raw_combo, ',')) f
      GROUP BY ts.order_ext_id, ts.raw_combo, ts.order_count, ts.osrm_pickup_dist_km
  ),

  -- ── STEP 5: All completed orders ──────────────────────────────
  completed_orders AS (
      SELECT
          o.id                                            AS order_id,
          o.external_id                                   AS order_ext_id,
          o.created_at + INTERVAL '330 minutes'           AS order_created_ist
      FROM prod_curated.partload_application.orders o
      WHERE o.state = 3
        AND DATE_TRUNC('month', o.created_at + INTERVAL '330 minutes') >= '2026-03-01'
  

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
),

  -- ── STEP 6: Latest batch per completed order ───────────────────
  order_batch AS (
      SELECT
          bo.order_id,
          b.id AS batch_id
      FROM prod_curated.partload_application.batched_orders_v1 bo
      JOIN prod_curated.partload_application.batch_v1 b ON b.id = bo.batch_id
      QUALIFY ROW_NUMBER() OVER (PARTITION BY bo.order_id ORDER BY b.created_at DESC) = 1
  ),

  -- ── STEP 7: Batch key using ALL orders (completed + cancelled) ─
  -- Using all orders so cancelled-partner batches match their combo
  batch_key AS (
      SELECT
          bo.batch_id,
          LISTAGG(o.external_id, ',') WITHIN GROUP (ORDER BY o.external_id) AS batch_key,
          COUNT(DISTINCT o.external_id)                                       AS batch_size
      FROM prod_curated.partload_application.batched_orders_v1 bo
      JOIN prod_curated.partload_application.orders o ON o.id = bo.order_id
      
where 1=1

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY bo.batch_id
  ),

  -- ── STEP 8: Compare batch against top 2 suggestions per order ──
  match_check AS (
      SELECT
          co.order_ext_id,
          ob.batch_id,
          bk.batch_key,
          bk.batch_size,
          -- 1 if batch exactly matches either top-2 combo
          MAX(CASE WHEN bk.batch_key = tck.combo_key THEN 1 ELSE 0 END)   AS any_full_match,
          -- max shared orders between batch and either top-2 combo
          MAX(
              ARRAY_SIZE(
                  ARRAY_INTERSECTION(
                      SPLIT(bk.batch_key, ','),
                      SPLIT(tck.combo_key, ',')
                  )
              )
          )                                                                 AS max_shared_orders,
          -- did engine have any suggestion for this order at all?
          MAX(CASE WHEN tck.order_ext_id IS NOT NULL THEN 1 ELSE 0 END)   AS has_suggestion
      FROM completed_orders co
      LEFT JOIN order_batch ob        ON ob.order_id      = co.order_id
      LEFT JOIN batch_key bk          ON bk.batch_id      = ob.batch_id
      LEFT JOIN top2_combo_keys tck   ON tck.order_ext_id = co.order_ext_id
      GROUP BY 1,2,3,4
  ),

  -- ── STEP 9: Classify each order ───────────────────────────────
  final AS (
      SELECT
          co.order_created_ist,
          mc.order_ext_id,
          mc.batch_id,
          mc.batch_size,
          CASE
              WHEN mc.batch_id IS NULL       THEN 'NO_BATCH'
              WHEN mc.has_suggestion = 0     THEN 'NO_SUGGESTION'
              WHEN mc.any_full_match = 1     THEN 'FULL_MATCH'
              WHEN mc.max_shared_orders >= 2 THEN 'PARTIAL_MATCH'
              ELSE                                'NO_MATCH'
          END AS match_type
      FROM completed_orders co
      LEFT JOIN match_check mc ON mc.order_ext_id = co.order_ext_id
  )

  -- ── FINAL: Aggregate ───────────────────────────────────────────
  SELECT
      DATE_TRUNC({{granularity}}, order_created_ist)                      AS period,
      COUNT(*)                                                            AS total_completed,
      SUM(CASE WHEN match_type = 'FULL_MATCH'    THEN 1 ELSE 0 END)      AS full_match,
      SUM(CASE WHEN match_type = 'PARTIAL_MATCH' THEN 1 ELSE 0 END)      AS partial_match,
      SUM(CASE WHEN match_type = 'NO_MATCH'      THEN 1 ELSE 0 END)      AS no_match,
      SUM(CASE WHEN match_type = 'NO_SUGGESTION' THEN 1 ELSE 0 END)      AS no_suggestion,
      SUM(CASE WHEN match_type = 'NO_BATCH'      THEN 1 ELSE 0 END)      AS no_batch,
      ROUND(100.0 * SUM(CASE WHEN match_type IN ('FULL_MATCH','PARTIAL_MATCH') THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*),0), 1)                                        AS match_pct,
      ROUND(100.0 * SUM(CASE WHEN match_type = 'FULL_MATCH'    THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*),0), 1)                                        AS full_match_pct,
      ROUND(100.0 * SUM(CASE WHEN match_type = 'PARTIAL_MATCH' THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*),0), 1)                                        AS partial_pct,
      ROUND(100.0 * SUM(CASE WHEN match_type = 'NO_MATCH'      THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*),0), 1)                                        AS no_match_pct,
      ROUND(100.0 * SUM(CASE WHEN match_type = 'NO_SUGGESTION' THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*),0), 1)                                        AS no_suggestion_pct,
      ROUND(100.0 * SUM(CASE WHEN match_type = 'NO_BATCH'      THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*),0), 1)                                        AS no_batch_pct
  FROM final
  WHERE DATE_TRUNC('day', order_created_ist)  >= {{start_Date}} and DATE_TRUNC('day', order_created_ist)  <= {{end_Date}}
  GROUP BY 1
  ORDER BY 1 DESC;