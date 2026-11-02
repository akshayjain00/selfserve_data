with ranked_combo_format AS (
    SELECT
        t.order_id,
        LISTAGG(
            'rank=' || t.rank_num || ':' || t.combo_order,
            ' || '
        ) WITHIN GROUP (ORDER BY t.idx) AS ranked_combo_ids
    FROM (
        SELECT
            TRIM(f.value::string) AS order_id,  -- use the flattened value as order_id
            TRIM(vc."ordered_order_ids"::string) AS combo_order,
            f.index AS idx,
            ROW_NUMBER() OVER (PARTITION BY TRIM(f.value::string) ORDER BY f.index) AS rank_num
        FROM partload_analytics.valid_combo_ranking vc,
             LATERAL FLATTEN(INPUT => SPLIT(vc."ordered_order_ids", ',')) f
    ) t
    GROUP BY t.order_id
),
load_weights AS (
    -- Fallback: use ops-declared chargeable/volumetric weight when present,
    -- otherwise fall back to the customer-declared value (card 47372).
    SELECT
        order_id,
        COALESCE(
            MAX(CASE WHEN entry_type = 'OPS_DECLARED' AND is_active = TRUE THEN chargeable_weight END),
            MAX(CASE WHEN entry_type = 'CUSTOMER_DECLARED' AND is_active = TRUE THEN chargeable_weight END)
        ) AS chargeable_weight,
        COALESCE(
            MAX(CASE WHEN entry_type = 'OPS_DECLARED' AND is_active = TRUE THEN volumetric_weight END),
            MAX(CASE WHEN entry_type = 'CUSTOMER_DECLARED' AND is_active = TRUE THEN volumetric_weight END)
        ) AS volumetric_weight
    FROM PROD_CURATED.PARTLOAD_APPLICATION.LOAD_DETAILS
    GROUP BY order_id
),
-- ==== RETIRED 2026-08-10 (RCA: delivery_type SDD/NDD flip) ===================
-- Kept for reference only. COALESCE silently fell through to slot_intervals_old
-- whenever the QUOTATIONS row had not yet replicated (~10 min after booking),
-- flipping SDD<->NDD for ~19% of orders. slots is a current-state table:
-- (route_configuration_id, route_id, start_time, end_time) is unique, so the
-- LEAD(created_at) 'version timeline' was never a version history -- it just
-- resolves to the newest config. NOTE: slot_intervals_by_config here also had
-- no QUALIFY dedup, unlike the other cards.
-- ==========================================================================
--  quotation_cfg AS (
--     SELECT quotation_uuid, route_configuration_id
--     FROM PROD_CURATED.PARTLOAD_APPLICATION.QUOTATIONS
--     WHERE quotation_uuid IS NOT NULL
--     QUALIFY ROW_NUMBER() OVER (PARTITION BY quotation_uuid ORDER BY updated_at DESC) = 1
-- ),
-- slots_base AS (
--     SELECT route_configuration_id, route_id, start_time, end_time, EDD_BUFFER_IN_DAYS, created_at,
--         ROW_NUMBER() OVER (PARTITION BY route_id, start_time, end_time ORDER BY created_at) AS rn_old,
--         LEAD(created_at) OVER (PARTITION BY route_id, start_time, end_time ORDER BY created_at) AS valid_to_old
--     FROM partload_application.slots
-- ),
-- slot_intervals_old AS (
--     SELECT route_id, start_time, end_time, EDD_BUFFER_IN_DAYS,
--         CASE WHEN rn_old = 1 THEN TIMESTAMP '1970-01-01 00:00:00' ELSE created_at END AS valid_from,
--         valid_to_old AS valid_to
--     FROM slots_base
-- ),
-- slot_intervals_by_config AS (
--     SELECT route_configuration_id, route_id, start_time, end_time, EDD_BUFFER_IN_DAYS
--     FROM slots_base
-- )
-- ==== end retired quotation_cfg + slot CTEs ====
base AS (

SELECT 
  orders.id,
  CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.created_at))::date AS dated,
  ORDERS.external_id AS order_id,
  
  CASE 
    WHEN ORDERS.state = 0 THEN 'Open' 
    WHEN ORDERS.state = 1 THEN 'Assigned' 
    WHEN ORDERS.state = 2 THEN 'Picked_up' 
    WHEN ORDERS.state = 3 THEN 'Completed'  
    WHEN ORDERS.state = 4 THEN 'Cancelled' 
  END AS order_status,
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
-- CASE COALESCE(s_cfg.EDD_BUFFER_IN_DAYS, s_old.EDD_BUFFER_IN_DAYS)
--     WHEN 0 THEN 'SDD'
--     WHEN 1 THEN 'NDD'
--     ELSE NULL
--   END AS delivery_type,
-- ==== end retired delivery_type ====
  CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.created_at)) AS created_at,

  VEHICLE_REGISTRATION_NUMBER,
  ptl_routes.route_name,

 
  CONVERT_TIMEZONE('UTC','Asia/Kolkata',orders.pickup_slot_start) AS pickup_slot_start,

  orders.route_id, 
  ORDER_VEHICLES.vehicle_type,
  orders.updated_at,
  batch_id,
  ESTIMATED_DELIVERY_TS,
  
  LOAD_DETAILS.CHARGEABLE_WEIGHT/1000 AS CHARGEABLE_WEIGHT,
  LOAD_DETAILS.VOLUMETRIC_WEIGHT/1000 AS VOLUMETRIC_WEIGHT,
  ARRAY_TO_STRING(
    ARRAY_SLICE(
        SPLIT(contact_details.ADDRESS_LINE, ','),
        GREATEST(ARRAY_SIZE(SPLIT(contact_details.ADDRESS_LINE, ',')) - 4, 0),
        ARRAY_SIZE(SPLIT(contact_details.ADDRESS_LINE, ','))
    ),
', '
) AS address_line,

  MAX(
        CASE 
            WHEN weight_capacity <= 10 THEN weight_capacity * 1000 
            ELSE weight_capacity 
        END
      ) AS truck_capacity,

--  CONCAT(
--     COALESCE(distance_osrm.combo_ids,''),
--     CASE 
--         WHEN distance_osrm.combo_ids IS NOT NULL 
--          AND rcf.ranked_combo_ids IS NOT NULL 
--         THEN ' || '
--         ELSE ''
--     END,
--     COALESCE(rcf.ranked_combo_ids,'')
-- ) AS combo_ids,
distance_osrm.combo_ids,
  distance_osrm.leg_distances_array,
  rcf.ranked_combo_ids,
  driver_name

FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS

-- ==== RETIRED 2026-08-10 (RCA: delivery_type SDD/NDD flip) ===================
-- LEFT JOIN quotation_cfg q
--     ON q.quotation_uuid = ORDERS.quotation_uuid
--    AND ORDERS.created_at >= '2026-04-29 16:58:08.421000'::timestamp_ntz
-- ==== end retired quotation join ====


LEFT JOIN prod_curated.partload_analytics.ptl_routes 
    ON ptl_routes.route_id = ORDERS.route_id 
    AND ptl_routes.is_active = 'True'

LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES
    ON ORDERS.external_id = ORDER_VEHICLES.order_external_id 
    AND ORDER_VEHICLES.is_active = TRUE

LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.contact_details 
    ON ORDERS.id = contact_details.order_id 
    AND contact_details.type = 0

LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.ptl_internal_users 
    ON ptl_internal_users.mobile = ORDERS.customer_mobile

LEFT JOIN load_weights AS LOAD_DETAILS
    ON ORDERS.id = LOAD_DETAILS.order_id

LEFT JOIN (
    SELECT * 
    FROM PROD_CURATED.PARTLOAD_APPLICATION.batched_orders_v1 
    QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) = 1
) bo 
ON bo.order_id = orders.id 
AND bo.status NOT IN (1,2)

LEFT JOIN partload_application.vehicles v 
    ON ORDER_VEHICLES.vehicle_id = v.id 
    AND ORDER_VEHICLES.is_active = TRUE

LEFT JOIN partload_application.vehicle_categories vc 
    ON vc.id = v.vehicle_categories_id
-- ==== RETIRED 2026-08-10 (RCA: delivery_type SDD/NDD flip) ===================
-- LEFT JOIN slot_intervals_by_config s_cfg
--     ON q.route_configuration_id IS NOT NULL
--    AND ORDERS.route_id = s_cfg.route_id
--    AND q.route_configuration_id = s_cfg.route_configuration_id
--    AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_start) AS TIME) = s_cfg.start_time
--    AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_end)   AS TIME) = s_cfg.end_time
-- LEFT JOIN slot_intervals_old s_old
--     ON ORDERS.route_id = s_old.route_id
--    AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_start) AS TIME) = s_old.start_time
--    AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_end)   AS TIME) = s_old.end_time
--    AND ORDERS.created_at >= s_old.valid_from
--    AND (ORDERS.created_at < s_old.valid_to OR s_old.valid_to IS NULL)
-- ==== end retired slot joins ====

LEFT JOIN (
    SELECT
    order_id,

    LISTAGG(
        'rank=' || order_rank || ':' || combo_id,
        ' || '
    ) WITHIN GROUP (ORDER BY order_rank) AS combo_ids,

    LISTAGG(
        'rank=' || order_rank || ':' || leg_distances_array::STRING,
        ' || '
    ) WITHIN GROUP (ORDER BY order_rank) AS leg_distances_array

    FROM (
        SELECT
            TRIM(f.value) AS order_id,
            base.combo_id,
            base.slot_sequence,
            base.order_count,
            base.osrm_pickup_dist_km,
            base.leg_distances_array,
            base.created_at AS osrm_created,

            ROW_NUMBER() OVER (
                PARTITION BY TRIM(f.value)
                ORDER BY base.order_count DESC,
                         base.osrm_pickup_dist_km ASC
            ) AS order_rank

        FROM (

            SELECT
                t."combo_id" AS combo_id,
                t."slot_sequence" AS slot_sequence,
                t."order_count" AS order_count,
                t."osrm_pickup_dist_km" AS osrm_pickup_dist_km,
                t."leg_distances_array" AS leg_distances_array,
                t."created_at" AS created_at
            FROM partload_analytics.ALLOCATION_OSRM_v2_DISTANCE t

            QUALIFY ROW_NUMBER() OVER (
                PARTITION BY t."combo_id"
                ORDER BY t."created_at" DESC
            ) = 1

        ) base,
        LATERAL FLATTEN(INPUT => SPLIT(base.combo_id, ',')) f
    )
    WHERE order_rank <= 2
    GROUP BY order_id
) distance_osrm
ON distance_osrm.order_id = orders.external_id
LEFT JOIN ranked_combo_format rcf
ON rcf.order_id = ORDERS.external_id


WHERE 
  ptl_internal_users.mobile IS NULL
  AND ORDERS.state IN (1,2)


  [[AND CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.pickup_slot_start))::date = {{date}}]]
  
  [[and {{route_name}}]]

GROUP BY ALL



--QUALIFY ROW_NUMBER() OVER (PARTITION BY orders.external_id ORDER BY orders.updated_at DESC) = 1
)


,vehicle_orders AS (
    SELECT 
        VEHICLE_REGISTRATION_NUMBER,
        vehicle_type,
        truck_capacity,
        order_id,
		delivery_type,
        batch_id, 
        chargeable_weight,
        address_line,
        pickup_slot_start,
        combo_ids,
        leg_distances_array,
		ranked_combo_ids,
		driver_name,
 ROW_NUMBER() OVER (
            PARTITION BY VEHICLE_REGISTRATION_NUMBER
            ORDER BY pickup_slot_start DESC, created_at desc
        ) AS rn


    FROM base
),
vehicle_summary AS (
    SELECT
        VEHICLE_REGISTRATION_NUMBER,
        MAX(vehicle_type) AS vehicle_type,
		max(delivery_type) as delivery_type,
        MAX(truck_capacity) AS truck_capacity,
        COUNT(order_id) AS order_count,
		MAX(driver_name) as driver_name,
        SUM(chargeable_weight) AS total_chargeable_weight,
		LISTAGG(order_id, ' , ') 
            WITHIN GROUP (ORDER BY pickup_slot_start) AS order_ids,

        MAX(batch_id) as batch_id

    FROM vehicle_orders
    GROUP BY VEHICLE_REGISTRATION_NUMBER
),

latest_order_details AS (
    SELECT
        VEHICLE_REGISTRATION_NUMBER,
        address_line AS latest_order_address,
        combo_ids,
		order_id,          
        batch_id,
		delivery_type,
        leg_distances_array,
		ranked_combo_ids
    FROM vehicle_orders
    WHERE rn = 1
)
,

  orders_split AS (

SELECT
    lo.VEHICLE_REGISTRATION_NUMBER,
    lo.order_id AS latest_order_id,

    combo.index AS combo_index,

    SPLIT_PART(combo.value::string,':',1) AS rank_label,
    SPLIT_PART(combo.value::string,':',2) AS combo_orders,

    f.index,
    TRIM(f.value::string) AS combo_order_id

FROM latest_order_details lo,

LATERAL FLATTEN(INPUT => SPLIT(lo.combo_ids,'||')) combo,

LATERAL FLATTEN(INPUT => SPLIT(SPLIT_PART(combo.value::string,':',2),',')) f


),

orders_filtered AS (

SELECT
    VEHICLE_REGISTRATION_NUMBER,
    latest_order_id,
    combo_order_id,
    combo_index,
    rank_label,

    ROW_NUMBER() OVER (
        PARTITION BY VEHICLE_REGISTRATION_NUMBER, combo_index
        ORDER BY index
    ) - 1 AS new_index

FROM orders_split
WHERE combo_order_id <> latest_order_id

),

distances AS (

SELECT
    lo.VEHICLE_REGISTRATION_NUMBER,
    combo.index AS combo_index,
    d.index,
    d.value::float AS leg_distance

FROM latest_order_details lo,

LATERAL FLATTEN(INPUT => SPLIT(lo.leg_distances_array,'||')) combo,

LATERAL FLATTEN(INPUT => PARSE_JSON(SPLIT_PART(combo.value::string,':',2))) d

)
, latest_combo_orders as (
SELECT
    ofo.VEHICLE_REGISTRATION_NUMBER,
    ofo.latest_order_id,
    ofo.combo_order_id,
    d.leg_distance,

    REPLACE(ofo.rank_label,'rank=','')::INT AS rank

FROM orders_filtered ofo

LEFT JOIN distances d
ON ofo.combo_index = d.combo_index
AND ofo.new_index = d.index
AND ofo.VEHICLE_REGISTRATION_NUMBER = d.VEHICLE_REGISTRATION_NUMBER

ORDER BY
    ofo.VEHICLE_REGISTRATION_NUMBER,
    rank,
    ofo.combo_order_id

)
 , open_combo_orders AS (

SELECT
    lco.VEHICLE_REGISTRATION_NUMBER,
    lco.latest_order_id,
    lco.combo_order_id,
    lco.leg_distance,
    lco.rank,
	round(ld.CHARGEABLE_WEIGHT/1000,0) AS combo_chargeable_weight,
         CASE DATEDIFF(
                day,
                CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.pickup_slot_start)     AS DATE),
                CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.estimated_delivery_ts) AS DATE)
              )
        WHEN 0 THEN 'SDD'
        WHEN 1 THEN 'NDD'
        ELSE NULL
    END AS combo_delivery_type,
-- ==== RETIRED 2026-08-10 (RCA: delivery_type SDD/NDD flip) ===================
-- 	 	 CASE COALESCE(s_cfg_combo.EDD_BUFFER_IN_DAYS, s_old_combo.EDD_BUFFER_IN_DAYS)
--         WHEN 0 THEN 'SDD'
--         WHEN 1 THEN 'NDD'
--         ELSE NULL
--     END AS combo_delivery_type,
-- ==== end retired combo_delivery_type ====

    -- o.pickup_lat  AS combo_pickup_lat,
    -- o.pickup_lng AS combo_pickup_lon,

    -- lo.pickup_lat  AS latest_pickup_lat,
    -- lo.pickup_lng AS latest_pickup_lon,

    /* pickup-to-pickup distance */
    2 * 6371 * ASIN(
        SQRT(
            POWER(SIN(RADIANS(o.pickup_lat - lo.pickup_lat)/2),2) +
            COS(RADIANS(lo.pickup_lat)) *
            COS(RADIANS(o.pickup_lat)) *
            POWER(SIN(RADIANS(o.pickup_lng - lo.pickup_lng)/2),2)
        )
    ) AS pickup__haversine_distance_km

FROM latest_combo_orders lco

/* combo order pickup */
JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDERS o
    ON o.external_id = lco.combo_order_id

/* latest open order pickup */
JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDERS lo
    ON lo.external_id = lco.latest_order_id
	
LEFT JOIN load_weights ld
    ON ld.order_id = o.id

-- ==== RETIRED 2026-08-10 (RCA: delivery_type SDD/NDD flip) ===================
-- LEFT JOIN quotation_cfg q_combo
--     ON q_combo.quotation_uuid = o.quotation_uuid
--    AND o.created_at >= '2026-04-29 16:58:08.421000'::timestamp_ntz
-- ==== end retired combo quotation join ====
-- ==== RETIRED 2026-08-10 (RCA: delivery_type SDD/NDD flip) ===================
-- LEFT JOIN slot_intervals_by_config s_cfg_combo
--     ON q_combo.route_configuration_id IS NOT NULL
--    AND o.route_id = s_cfg_combo.route_id
--    AND q_combo.route_configuration_id = s_cfg_combo.route_configuration_id
--    AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.pickup_slot_start) AS TIME) = s_cfg_combo.start_time
--    AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.pickup_slot_end)   AS TIME) = s_cfg_combo.end_time
-- LEFT JOIN slot_intervals_old s_old_combo
--     ON o.route_id = s_old_combo.route_id
--    AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.pickup_slot_start) AS TIME) = s_old_combo.start_time
--    AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.pickup_slot_end)   AS TIME) = s_old_combo.end_time
--    AND o.created_at >= s_old_combo.valid_from
--    AND (o.created_at < s_old_combo.valid_to OR s_old_combo.valid_to IS NULL)
-- ==== end retired combo slot joins ====

WHERE o.state = 0

QUALIFY RANK() OVER (
    PARTITION BY lco.latest_order_id
    ORDER BY lco.rank
) = 1


-- --WHERE o.state = 0

  ),
--ranked_combo_ids ctes

--   ranked_orders_split AS (

-- SELECT
--     lo.VEHICLE_REGISTRATION_NUMBER,
--     lo.order_id AS latest_order_id,

--     combo.index AS combo_index,

--     SPLIT_PART(combo.value::string,':',1) AS rank_label,
--     SPLIT_PART(combo.value::string,':',2) AS combo_orders,

--     f.index,
--     TRIM(f.value::string) AS combo_order_id

-- FROM latest_order_details lo,

-- LATERAL FLATTEN(INPUT => SPLIT(lo.ranked_combo_ids,'||')) combo,

-- LATERAL FLATTEN(INPUT => SPLIT(SPLIT_PART(combo.value::string,':',2),',')) f

-- ),
-- ranked_orders_filtered AS (

-- SELECT
--     VEHICLE_REGISTRATION_NUMBER,
--     latest_order_id,
--     combo_order_id,
--     combo_index,
--     rank_label,

--     ROW_NUMBER() OVER (
--         PARTITION BY VEHICLE_REGISTRATION_NUMBER, combo_index
--         ORDER BY index
--     ) - 1 AS new_index

-- FROM ranked_orders_split
-- WHERE combo_order_id <> latest_order_id

-- ),
-- ranked_open_combo_orders AS (

-- SELECT
--     rof.VEHICLE_REGISTRATION_NUMBER,
--     rof.latest_order_id,
--     rof.combo_order_id,

--     REPLACE(rof.rank_label,'rank=','')::INT AS rank,
-- 	round(ld.CHARGEABLE_WEIGHT/1000,0) AS ranked_combo_chargeable_weight,

--    ROUND(
--     2 * 6371 * ASIN(
--         SQRT(
--             POWER(SIN(RADIANS(o.pickup_lat - lo.pickup_lat)/2),2) +
--             COS(RADIANS(lo.pickup_lat)) *
--             COS(RADIANS(o.pickup_lat)) *
--             POWER(SIN(RADIANS(o.pickup_lng - lo.pickup_lng)/2),2)
--         )
--     ),
-- 2) AS ranked_pickup_haversine_km
-- FROM ranked_orders_filtered rof

-- JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDERS o
--     ON o.external_id = rof.combo_order_id

-- JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDERS lo
--     ON lo.external_id = rof.latest_order_id
	
-- LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.LOAD_DETAILS ld
--     ON ld.order_id = o.id
--     AND ld.is_active = TRUE
	
-- --WHERE o.state = 0

-- ),
-- ranked_filtered_combo AS (

-- SELECT
--     VEHICLE_REGISTRATION_NUMBER,

--     LISTAGG(combo_order_id, ',')
--         WITHIN GROUP (ORDER BY rank) AS ranked_combo_ids,

-- 	LISTAGG(ranked_combo_chargeable_weight, ',')
--         WITHIN GROUP (ORDER BY rank) AS ranked_combo_chargeable_weight,

--     LISTAGG(ranked_pickup_haversine_km, ',')
--         WITHIN GROUP (ORDER BY rank) AS ranked_pickup_haversine_km

-- FROM ranked_open_combo_orders

-- GROUP BY VEHICLE_REGISTRATION_NUMBER

-- ),

filtered_combo AS (

SELECT
    VEHICLE_REGISTRATION_NUMBER,

   LISTAGG(combo_order_id, ',')
    WITHIN GROUP (ORDER BY rank) AS combo_ids,

LISTAGG(leg_distance, ',')
    WITHIN GROUP (ORDER BY rank) AS leg_distance,
	
  LISTAGG(combo_chargeable_weight, ',')
        WITHIN GROUP (ORDER BY rank) AS combo_chargeable_weight,
		
LISTAGG(combo_delivery_type, ',')
        WITHIN GROUP (ORDER BY rank) AS combo_delivery_type,

LISTAGG(pickup__haversine_distance_km, ',')
    WITHIN GROUP (ORDER BY rank) AS pickup__haversine_distance_km,

    MIN(rank) AS rank

FROM open_combo_orders

GROUP BY VEHICLE_REGISTRATION_NUMBER

)
SELECT
    vs.VEHICLE_REGISTRATION_NUMBER,
    vs.vehicle_type,
	vs.driver_name,
    --vs.truck_capacity as vehicle_capacity,
    vs.order_count,
    --vs.total_chargeable_weight,
    vs.truck_capacity - vs.total_chargeable_weight AS remaining_capacity,
	 vs.order_ids,
 --    vs.batch_ids,

    lo.latest_order_address as latest_order_pickup_address,
	 lo.order_id as latest_order,  
	 lo.batch_id as latest_batch,
 --    lo.batch_id,  
    -- lo.combo_ids,
    -- lo.leg_distances_array
	lo.delivery_type,
	--vs.delivery_type as vs_delivery_type,
	fc.combo_chargeable_weight,
	fc.leg_distance as osrm_distance,
	fc.combo_ids,
	fc.combo_delivery_type
   -- fc.pickup__haversine_distance_km,
    --fc.rank,
-- 	rfc.ranked_combo_ids,
-- rfc.ranked_pickup_haversine_km,
-- rfc.ranked_combo_chargeable_weight


FROM vehicle_summary vs

LEFT JOIN latest_order_details lo
ON vs.VEHICLE_REGISTRATION_NUMBER = lo.VEHICLE_REGISTRATION_NUMBER

LEFT JOIN filtered_combo fc
ON vs.VEHICLE_REGISTRATION_NUMBER = fc.VEHICLE_REGISTRATION_NUMBER

-- LEFT JOIN ranked_filtered_combo rfc
-- ON vs.VEHICLE_REGISTRATION_NUMBER = rfc.VEHICLE_REGISTRATION_NUMBER

WHERE 1=1
[[and vs.order_count = {{order_count}}]]

ORDER BY vs.VEHICLE_REGISTRATION_NUMBER

