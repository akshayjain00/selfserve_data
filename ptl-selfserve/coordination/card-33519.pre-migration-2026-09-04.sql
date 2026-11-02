-- ==== RETIRED 2026-08-10 (RCA: delivery_type SDD/NDD flip) ===================
-- Kept for reference only. COALESCE below silently fell through to the
-- slot_intervals_old path whenever the QUOTATIONS row had not yet replicated
-- (~10 min after booking), flipping SDD<->NDD for ~19% of orders. slots is a
-- current-state table: (route_configuration_id, route_id, start_time,
-- end_time) is unique, so the LEAD(created_at) 'version timeline' below was
-- never a version history -- it just resolves to the newest config.
-- NOTE: rn_cfg / valid_to_cfg were computed here but never used.
-- ==========================================================================
-- WITH slots_base AS (
--       SELECT
--           route_configuration_id,
--           route_id,
--           start_time,
--           end_time,
--           EDD_BUFFER_IN_DAYS,
--           created_at,
--
--           ROW_NUMBER() OVER (
--               PARTITION BY route_id, start_time, end_time
--               ORDER BY created_at
--           ) AS rn_old,
--
--           LEAD(created_at) OVER (
--               PARTITION BY route_id, start_time, end_time
--               ORDER BY created_at
--           ) AS valid_to_old,
--
--           ROW_NUMBER() OVER (
--               PARTITION BY route_configuration_id, route_id, start_time, end_time
--               ORDER BY created_at
--           ) AS rn_cfg,
--
--           LEAD(created_at) OVER (
--               PARTITION BY route_configuration_id, route_id, start_time, end_time
--               ORDER BY created_at
--           ) AS valid_to_cfg
--       FROM partload_application.slots
--   ),
--
--   slot_intervals_old AS (
--       SELECT
--           route_id,
--           start_time,
--           end_time,
--           EDD_BUFFER_IN_DAYS,
--           CASE
--               WHEN rn_old = 1 THEN TIMESTAMP '1970-01-01 00:00:00'
--               ELSE created_at
--           END AS valid_from,
--           valid_to_old AS valid_to
--       FROM slots_base
--   ),
--
--   slot_intervals_by_config AS (
--     SELECT
--         route_configuration_id,
--         route_id,
--         start_time,
--         end_time,
--         EDD_BUFFER_IN_DAYS
--     FROM slots_base
--     QUALIFY ROW_NUMBER() OVER (
--         PARTITION BY route_configuration_id, route_id, start_time, end_time
--         ORDER BY created_at DESC
--     ) = 1
-- ),
-- ==== end retired slot CTEs ====

WITH dup_pairs AS (
      SELECT
          a.external_id AS order_id,
          a.created_at  AS order_created_at,
          b.external_id AS sibling_id,
          b.created_at  AS sibling_created_at
      FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS a
      JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDERS b
          ON a.external_id != b.external_id
         AND a.state != 4
         AND b.state != 4
         AND DATE(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(a.pickup_slot_start)))
           = DATE(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(b.pickup_slot_start)))
         AND a.customer_mobile = b.customer_mobile
         AND HAVERSINE(a.pickup_lat, a.pickup_lng, b.pickup_lat, b.pickup_lng) < 0.2
         AND HAVERSINE(a.drop_lat,   a.drop_lng,   b.drop_lat,   b.drop_lng)   < 0.2
      WHERE a.pickup_slot_start >= DATEADD('minute', -330, DATEADD('day', -1, CURRENT_DATE)::timestamp_ntz)::timestamp_ltz
        AND a.pickup_slot_start <  DATEADD('minute', -330, DATEADD('day', 2,  CURRENT_DATE)::timestamp_ntz)::timestamp_ltz
  ),

  duplicate_flag AS (
      SELECT
          p.order_id,
          COUNT(*) + 1 AS dup_count,
          LISTAGG(p.sibling_id, ', ') WITHIN GROUP (ORDER BY p.sibling_created_at ASC)
              AS repeated_sibling_order_ids,
          CASE WHEN p.order_created_at <= MIN(p.sibling_created_at) THEN 'Yes' ELSE 'No' END
              AS is_first_duplicate,
          CASE WHEN p.order_created_at <= MIN(p.sibling_created_at)
               THEN p.order_id
               ELSE MIN_BY(p.sibling_id, p.sibling_created_at)
          END AS original_order_id
      FROM dup_pairs p
      GROUP BY p.order_id, p.order_created_at
  ),

final AS (
    SELECT
        orders.id,
        CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.created_at))::date AS dated,
        external_id AS order_id,
        CASE
            WHEN ORDERS.state = 0 THEN 'Open'
            WHEN ORDERS.state = 1 THEN 'Assigned'
            WHEN ORDERS.state = 2 THEN 'Picked_up'
            WHEN ORDERS.state = 3 THEN 'Completed'
            WHEN ORDERS.state = 4 THEN 'Cancelled'
        END AS order_status,
        CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.created_at))      AS created_at,
        CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.updated_at))      AS updated_at,
        CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.pickup_slot_start)) AS pickup_slot_start,
        CONCAT(
            TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_start)), 'DD Mon, YYYY, HH:MI AM')
            || ' - ' ||
            TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_end)), 'HH24:MI')
        ) AS pickup_slot,
         -- ==== delivery_type: derived from the order itself ===================
         -- estimated_delivery_ts is produced by applying EDD_BUFFER_IN_DAYS at
         -- booking, so invert it rather than re-reading slots. Immutable at T+0.
         -- ====================================================================
         CASE DATEDIFF(
                day,
                CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_start)     AS DATE),
                CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.estimated_delivery_ts) AS DATE)
              )
      WHEN 0 THEN 'SDD'
      WHEN 1 THEN 'NDD'
      ELSE NULL
  END AS delivery_type,
-- ==== RETIRED 2026-08-10 (RCA: delivery_type SDD/NDD flip) ===================
--          CASE COALESCE(s_cfg.EDD_BUFFER_IN_DAYS, s_old.EDD_BUFFER_IN_DAYS)
--       WHEN 0 THEN 'SDD'
--       WHEN 1 THEN 'NDD'
--       ELSE NULL
--   END AS delivery_type,
-- ==== end retired delivery_type ====


        CONCAT(pickup_lat, ' , ', pickup_lng) AS pickup_lat_lng,
        CONCAT(drop_lat,   ' , ', drop_lng)   AS drop_lat_lng,
        estimated_fare / 100 AS final_fare,
        -- ROUND(MAX(CASE WHEN load_details.entry_type = 'CUSTOMER_DECLARED'
        --                THEN load_details.chargeable_weight END) / 1000, 0) AS customer_declared_weight,
		ROUND(MAX(CASE WHEN load_details.entry_type = 'CUSTOMER_DECLARED'
               AND load_details.id = (
                   SELECT MIN(id) 
                   FROM PROD_CURATED.PARTLOAD_APPLICATION.LOAD_DETAILS ld2
                   WHERE ld2.order_id = ORDERS.id 
                   AND ld2.entry_type = 'CUSTOMER_DECLARED'
               )
               THEN load_details.chargeable_weight END) / 1000, 0) AS customer_declared_weight,
        ROUND(MAX(CASE WHEN load_details.entry_type = 'OPS_DECLARED' AND load_details.is_active = TRUE
                       THEN load_details.chargeable_weight END) / 1000, 0) AS ops_declared_weight,
        MAX(CASE WHEN order_fares.fare_reason_code = 'INITIAL_BOOKING'
                 THEN ROUND(total_fare / 100, 0) END) AS customer_declared_fare,
        MAX(CASE WHEN order_fares.fare_reason_code = 'WEIGHT_REVISION_CHANGE' AND load_details.is_active = TRUE
                 THEN ROUND(total_fare / 100, 0) END) AS ops_fare,
        display_name    AS goods_type,
        customer_name   AS booker_name,
        customer_mobile AS booker_mobile_no,
        MAX(CASE WHEN contact_details.type = 0 THEN contact_details.name        END) AS sender_name,
        MAX(CASE WHEN contact_details.type = 0 THEN contact_details.mobile      END) AS sender_mobile,
        MAX(CASE WHEN contact_details.type = 1 THEN contact_details.name        END) AS receiver_name,
        MAX(CASE WHEN contact_details.type = 1 THEN contact_details.mobile      END) AS receiver_mobile,
        MAX(CASE WHEN contact_details.type = 0 THEN contact_details.address_line END) AS pickup_address,
        MAX(CASE WHEN contact_details.type = 1 THEN contact_details.address_line END) AS drop_address,
        driver_name,
        driver_mobile,
        VEHICLE_REGISTRATION_NUMBER,
        vehicle_type,
        CASE WHEN payment_status = 0 THEN 'Pending' ELSE 'Completed' END AS payment_status,
        REPLACE(r.route_label, '-', ' - ') AS route_name,
        orders.route_id,
        ptl_routes.zone AS city,
        orders.updated_at,
        bo.batch_id,
        -- From distance_osrm (ALLOCATION_OSRM_v2_DISTANCE) — explicit columns replacing distance_osrm.*
        

    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
-- ==== RETIRED 2026-08-10 (RCA: delivery_type SDD/NDD flip) ===================
-- 	 LEFT JOIN (
--       SELECT
--           quotation_uuid,
--           route_configuration_id
--       FROM PROD_CURATED.PARTLOAD_APPLICATION.QUOTATIONS
--       WHERE quotation_uuid IS NOT NULL
--       QUALIFY ROW_NUMBER() OVER (
--           PARTITION BY quotation_uuid
--           ORDER BY updated_at DESC
--       ) = 1
--   ) q
--       ON q.quotation_uuid = ORDERS.quotation_uuid
--      AND ORDERS.created_at >= '2026-04-29 16:58:08.421000'::timestamp_ntz
-- 	 -- quotation_uuid is null before this '2026-04-29 16:58:08.421000'
-- ==== end retired QUOTATIONS join ====
    LEFT JOIN prod_curated.partload_analytics.ptl_routes
           ON ptl_routes.route_id = ORDERS.route_id
		   and ptl_routes.is_active = 'True'
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ROUTES r
           ON r.id = ORDERS.route_id
          AND r.is_active = TRUE
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.contact_details
           ON ORDERS.id = contact_details.order_id
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.LOAD_DETAILS
           ON ORDERS.id = LOAD_DETAILS.order_id
    -- LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.material_type
    --        ON LOAD_DETAILS.material_type_id = material_type.material_type_id
	LEFT JOIN (
    SELECT ld.order_id, mt.display_name
    FROM PROD_CURATED.PARTLOAD_APPLICATION.LOAD_DETAILS ld
    JOIN PROD_CURATED.PARTLOAD_APPLICATION.material_type mt
        ON ld.material_type_id = mt.material_type_id
    WHERE ld.entry_type = 'CUSTOMER_DECLARED'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY ld.order_id ORDER BY ld.id) = 1
) material_type ON material_type.order_id = ORDERS.id
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES
           ON ORDERS.external_id = ORDER_VEHICLES.order_external_id AND ORDER_VEHICLES.is_active = TRUE
-- ==== RETIRED 2026-08-10 (RCA: delivery_type SDD/NDD flip) ===================
--     LEFT JOIN slot_intervals_by_config s_cfg
--       ON q.route_configuration_id IS NOT NULL
--      AND ORDERS.route_id = s_cfg.route_id
--      AND q.route_configuration_id = s_cfg.route_configuration_id
--      AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_start) AS TIME) = s_cfg.start_time
--      AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_end) AS TIME) = s_cfg.end_time
--
--   LEFT JOIN slot_intervals_old s_old
--       ON ORDERS.route_id = s_old.route_id
--      AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_start) AS TIME) = s_old.start_time
--      AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_end) AS TIME) = s_old.end_time
--      AND ORDERS.created_at >= s_old.valid_from
--      AND (ORDERS.created_at < s_old.valid_to OR s_old.valid_to IS NULL)
-- ==== end retired slot joins ====

    LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.ptl_internal_users
           ON ptl_internal_users.mobile = ORDERS.customer_mobile
    LEFT JOIN (
        SELECT * FROM PROD_CURATED.PARTLOAD_APPLICATION.batched_orders_v1
        QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) = 1
    ) bo ON bo.order_id = orders.id
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.order_fares
           ON ARRAY_CONTAINS(load_details.id, order_fares.load_details_ids)
    -- LEFT JOIN (
    --     -- valid_combo_ranking: ranked combo order IDs + allocated batch IDs + total distance
    --     SELECT
    --         order_id,
    --         LISTAGG(ordered_order_ids, '  |  ')
    --             WITHIN GROUP (ORDER BY combo_rank ASC) AS all_ranked_combos,
    --         LISTAGG(TRIM(base_allocation_batch_id), '  |  ')
    --             WITHIN GROUP (ORDER BY combo_rank ASC) AS all_allocated_batch_ids,
    --         LISTAGG(total_distance_km, '  |  ')
    --             WITHIN GROUP (ORDER BY combo_rank ASC) AS total_distance_km
    --     FROM (
    --         SELECT
    --             TRIM(f.value)              AS order_id,
    --             base."ordered_order_ids"   AS ordered_order_ids,
    --             base.combo_rank,
    --             base."order_count",
    --             base."allocated_batch_ids" AS base_allocation_batch_id,
    --             base."total_distance_km"   AS total_distance_km,
    --             MAX(base."order_count") OVER (PARTITION BY TRIM(f.value)) AS max_order_count
    --         FROM partload_analytics.valid_combo_ranking base,
    --              LATERAL FLATTEN(INPUT => SPLIT(base."ordered_order_ids", ',')) f
    --     ) t
    --     WHERE "order_count" = max_order_count
    --     GROUP BY order_id
    -- ) oac ON oac.order_id = ORDERS.external_id
    -- LEFT JOIN (
    --     -- ALLOCATION_OSRM_v2_DISTANCE: combo-level OSRM distances, slot sequences
    --     SELECT
    --         order_id,
    --         LISTAGG(combo_id, '  ||  ')
    --             WITHIN GROUP (ORDER BY order_rank) AS combo_ids,
    --         LISTAGG(leg_distances_array::STRING, '  ||  ')
    --             WITHIN GROUP (ORDER BY order_rank) AS leg_distances_array,
    --         LISTAGG(osrm_pickup_dist_km::STRING, '  ||  ')
    --             WITHIN GROUP (ORDER BY order_rank) AS distances,
    --         LISTAGG(slot_sequence, '  ||  ')
    --             WITHIN GROUP (ORDER BY order_rank) AS slot_sequences,
    --         LISTAGG(osrm_created::STRING, '  ||  ')
    --             WITHIN GROUP (ORDER BY order_rank) AS created_times
    --     FROM (
    --         SELECT
    --             TRIM(f.value)            AS order_id,
    --             base.combo_id,
    --             base.slot_sequence,
    --             base.order_count,
    --             base.osrm_pickup_dist_km,
    --             base.leg_distances_array,
    --             base.created_at          AS osrm_created,
    --             ROW_NUMBER() OVER (
    --                 PARTITION BY TRIM(f.value)
    --                 ORDER BY base.order_count DESC, base.osrm_pickup_dist_km ASC
    --             ) AS order_rank
    --         FROM (
    --             SELECT
    --                 t."combo_id"            AS combo_id,
    --                 t."slot_sequence"       AS slot_sequence,
    --                 t."order_count"         AS order_count,
    --                 t."osrm_pickup_dist_km" AS osrm_pickup_dist_km,
    --                 t."leg_distances_array" AS leg_distances_array,
    --                 t."created_at"          AS created_at
    --             FROM partload_analytics.ALLOCATION_OSRM_v2_DISTANCE t
    --             QUALIFY ROW_NUMBER() OVER (
    --                 PARTITION BY t."combo_id" ORDER BY t."created_at" DESC
    --             ) = 1
    --         ) base,
    --         LATERAL FLATTEN(INPUT => SPLIT(base.combo_id, ',')) f
    --     )
    --     WHERE order_rank <= 2
    --     GROUP BY order_id
    -- ) distance_osrm ON distance_osrm.order_id = ORDERS.external_id

    WHERE
        -- KEY FIX: UTC range enables micro-partition pruning
        ORDERS.pickup_slot_start >= DATEADD(
      'minute',
      -330,
      DATEADD('day', -1, CURRENT_DATE)::timestamp_ntz
  )::timestamp_ltz

  AND ORDERS.pickup_slot_start < DATEADD(
      'minute',
      -330,
      DATEADD('day', 2, CURRENT_DATE)::timestamp_ntz
  )::timestamp_ltz


        [[AND TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_start)), 'HH24:MI') = {{pickup_slot_start}}]]
        [[AND CASE
              WHEN ORDERS.state = 0 THEN 'Open'
              WHEN ORDERS.state = 1 THEN 'Assigned'
              WHEN ORDERS.state = 2 THEN 'Picked_up'
              WHEN ORDERS.state = 3 THEN 'Completed'
              WHEN ORDERS.state = 4 THEN 'Cancelled'
          END = {{order_status}}]]
        [[AND orders.external_id = {{order_id}}]]
        [[AND CASE
              WHEN ptl_internal_users.mobile IS NULL     THEN 'False'
              WHEN ptl_internal_users.mobile IS NOT NULL THEN 'True'
          END = {{is_test}}]]
        [[AND {{route_name}}]]
        [[AND bo.batch_id = {{batch_id}}]]
        [[AND DATE(ORDERS.pickup_slot_start + INTERVAL '330 minutes') = {{pickup_date}}]]
        [[AND VEHICLE_REGISTRATION_NUMBER = {{VEHICLE_REGISTRATION_NUMBER}}]]
        [[AND {{city}}]]

    GROUP BY ALL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY orders.external_id ORDER BY orders.updated_at DESC) = 1
)

SELECT
    f.*,
    CASE WHEN df.dup_count > 1 THEN 'Yes' ELSE 'No' END  AS is_repeated_order,
    df.repeated_sibling_order_ids,
    df.is_first_duplicate,
    df.original_order_id
FROM final f
LEFT JOIN duplicate_flag df ON f.order_id = df.order_id
[[WHERE f.delivery_type = {{delivery_type}}]]
[[AND (CASE WHEN df.dup_count > 1 THEN 'Yes' ELSE 'No' END) = {{is_repeated_order}}]]
ORDER BY f.pickup_slot_start, f.created_at