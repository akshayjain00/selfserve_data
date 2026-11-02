-- ============================================================
  -- RAW ORDER-LEVEL VIEW
  -- Query 1 classification + debug columns for top-2 suggestions
  -- ============================================================

  WITH latest_osrm AS (
      SELECT
          t."combo_id"            AS combo_id,
          t."order_count"         AS order_count,
          t."osrm_pickup_dist_km" AS osrm_pickup_dist_km,
          t."created_at"          AS created_at
      FROM partload_analytics.ALLOCATION_OSRM_v2_DISTANCE t
      QUALIFY ROW_NUMBER() OVER (
          PARTITION BY t."combo_id"
          ORDER BY t."created_at" DESC
      ) = 1
  ),

  ranked_suggestions AS (
      SELECT
          TRIM(f.value::string) AS order_ext_id,
          lo.combo_id           AS raw_combo,
          lo.order_count,
          lo.osrm_pickup_dist_km,
          lo.created_at,
          ROW_NUMBER() OVER (
              PARTITION BY TRIM(f.value::string)
              ORDER BY lo.order_count DESC, lo.osrm_pickup_dist_km ASC, lo.created_at DESC, lo.combo_id
          ) AS order_rank
      FROM latest_osrm lo,
           LATERAL FLATTEN(INPUT => SPLIT(lo.combo_id, ',')) f
  ),

  top2_suggestions AS (
      SELECT
          order_ext_id,
          raw_combo,
          order_count,
          osrm_pickup_dist_km,
          created_at,
          order_rank
      FROM ranked_suggestions
      WHERE order_rank <= 2
  ),

  top2_combo_keys AS (
      SELECT
          ts.order_ext_id,
          ts.order_rank,
          ts.raw_combo,
          ts.order_count,
          ts.osrm_pickup_dist_km,
          ts.created_at AS suggestion_created_at,
          LISTAGG(TRIM(f.value::string), ',') WITHIN GROUP (ORDER BY TRIM(f.value::string)) AS combo_key
      FROM top2_suggestions ts,
           LATERAL FLATTEN(INPUT => SPLIT(ts.raw_combo, ',')) f
      GROUP BY
          ts.order_ext_id,
          ts.order_rank,
          ts.raw_combo,
          ts.order_count,
          ts.osrm_pickup_dist_km,
          ts.created_at
  ),

  top2_combo_pivot AS (
      SELECT
          order_ext_id,
          MAX(IFF(order_rank = 1, combo_key, NULL)) AS top1_combo_key,
          MAX(IFF(order_rank = 1, order_count, NULL)) AS top1_order_count,
          MAX(IFF(order_rank = 1, osrm_pickup_dist_km, NULL)) AS top1_osrm_pickup_dist_km,
          MAX(IFF(order_rank = 1, suggestion_created_at + INTERVAL '330 minutes', NULL)) AS
  top1_suggestion_created_ist,
          MAX(IFF(order_rank = 2, combo_key, NULL)) AS top2_combo_key,
          MAX(IFF(order_rank = 2, order_count, NULL)) AS top2_order_count,
          MAX(IFF(order_rank = 2, osrm_pickup_dist_km, NULL)) AS top2_osrm_pickup_dist_km,
          MAX(IFF(order_rank = 2, suggestion_created_at + INTERVAL '330 minutes', NULL)) AS
  top2_suggestion_created_ist
      FROM top2_combo_keys
      GROUP BY order_ext_id
  ),

  completed_orders AS (
      SELECT
          o.id AS order_id,
          o.external_id AS order_ext_id,
          o.created_at + INTERVAL '330 minutes' AS order_created_ist,
          o.pickup_slot_start + INTERVAL '330 minutes' AS pickup_slot_start_ist
      FROM prod_curated.partload_application.orders o
      WHERE o.state = 3
        AND DATE(o.created_at + INTERVAL '330 minutes') >= {{start_date}}
        AND DATE(o.created_at + INTERVAL '330 minutes') <= {{end_date}}
  

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
),

  order_batch AS (
      SELECT
          bo.order_id,
          b.id AS batch_id,
          b.created_at + INTERVAL '330 minutes' AS batch_created_ist
      FROM prod_curated.partload_application.batched_orders_v1 bo
      JOIN prod_curated.partload_application.batch_v1 b
        ON b.id = bo.batch_id
      QUALIFY ROW_NUMBER() OVER (
          PARTITION BY bo.order_id
          ORDER BY b.created_at DESC, b.id DESC
      ) = 1
  ),

  batch_membership AS (
      SELECT DISTINCT
          bo.batch_id,
          bo.order_id
      FROM prod_curated.partload_application.batched_orders_v1 bo
  ),

  batch_key AS (
      SELECT
          bm.batch_id,
          LISTAGG(o.external_id, ',') WITHIN GROUP (ORDER BY o.external_id) AS batch_key,
          COUNT(*) AS batch_size
      FROM batch_membership bm
      JOIN prod_curated.partload_application.orders o
        ON o.id = bm.order_id
      
where 1=1

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY bm.batch_id
  ),

  match_check AS (
      SELECT
          co.order_id,
          co.order_ext_id,
          ob.batch_id,
          ob.batch_created_ist,
          bk.batch_key,
          bk.batch_size,
          COALESCE(
              MAX(CASE WHEN bk.batch_key = tck.combo_key THEN 1 ELSE 0 END),
              0
          ) AS any_full_match,
          COALESCE(
              MAX(
                  IFF(
                      bk.batch_key IS NOT NULL AND tck.combo_key IS NOT NULL,
                      ARRAY_SIZE(
                          ARRAY_INTERSECTION(
                              SPLIT(bk.batch_key, ','),
                              SPLIT(tck.combo_key, ',')
                          )
                      ),
                      0
                  )
              ),
              0
          ) AS max_shared_orders,
          COALESCE(
              MAX(CASE WHEN tck.order_ext_id IS NOT NULL THEN 1 ELSE 0 END),
              0
          ) AS has_suggestion
      FROM completed_orders co
      LEFT JOIN order_batch ob
        ON ob.order_id = co.order_id
      LEFT JOIN batch_key bk
        ON bk.batch_id = ob.batch_id
      LEFT JOIN top2_combo_keys tck
        ON tck.order_ext_id = co.order_ext_id
      GROUP BY
          co.order_id,
          co.order_ext_id,
          ob.batch_id,
          ob.batch_created_ist,
          bk.batch_key,
          bk.batch_size
  ),

  final AS (
      SELECT
          co.order_created_ist,
          co.pickup_slot_start_ist,
          mc.order_id,
          mc.order_ext_id,
          mc.batch_id,
          mc.batch_created_ist,
          mc.batch_key,
          mc.batch_size,
          mc.any_full_match,
          mc.max_shared_orders,
          mc.has_suggestion,
          CASE
              WHEN mc.batch_id IS NULL       THEN 'NO_BATCH'
              WHEN mc.has_suggestion = 0     THEN 'NO_SUGGESTION'
              WHEN mc.any_full_match = 1     THEN 'FULL_MATCH'
              WHEN mc.max_shared_orders >= 2 THEN 'PARTIAL_MATCH'
              ELSE                                'NO_MATCH'
          END AS match_type
      FROM completed_orders co
      LEFT JOIN match_check mc
        ON mc.order_id = co.order_id
  ),

  final_enriched AS (
      SELECT
          f.*,
          p.top1_combo_key,
          p.top1_order_count,
          p.top1_osrm_pickup_dist_km,
          p.top1_suggestion_created_ist,
          p.top2_combo_key,
          p.top2_order_count,
          p.top2_osrm_pickup_dist_km,
          p.top2_suggestion_created_ist
      FROM final f
      LEFT JOIN top2_combo_pivot p
        ON p.order_ext_id = f.order_ext_id
  )

  SELECT
      order_created_ist,
      pickup_slot_start_ist,
      order_id,
      order_ext_id,
      batch_id,
      batch_created_ist,
      batch_key,
      batch_size,
      top1_combo_key,
      top1_order_count,
      top1_osrm_pickup_dist_km,
      top1_suggestion_created_ist,
      top2_combo_key,
      top2_order_count,
      top2_osrm_pickup_dist_km,
      top2_suggestion_created_ist,
      any_full_match,
      max_shared_orders,
      has_suggestion,
      match_type
  FROM final_enriched
  ORDER BY order_created_ist DESC;