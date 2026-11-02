with final_return AS (
    SELECT 
        orders.id,
        orders.external_id AS order_id,
        orders.route_id,
        ptl_routes.route_name,
        ptl_routes.drop_city AS drop_city_o,
        VEHICLE_REGISTRATION_NUMBER,
        bo.batch_id,
        bo.created_at + interval '330 mins' AS batch_created_at,
        orders.created_at,
        ESTIMATED_DELIVERY_TS + interval '330 mins' AS ESTIMATED_DELIVERY_TS,
        CASE WHEN orders.state = 3 THEN 'Completed' END AS order_status
    FROM prod_curated.partload_application.orders
    LEFT JOIN prod_curated.partload_analytics.ptl_routes
        ON ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
    LEFT JOIN (
        SELECT *
        FROM prod_curated.partload_application.batched_orders_v1
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY order_id 
            ORDER BY updated_at DESC
        ) = 1
    ) bo ON bo.order_id = orders.id
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES
        ON orders.external_id = ORDER_VEHICLES.order_external_id
       AND ORDER_VEHICLES.is_active = TRUE
	left join PROD_CURATED.PARTLOAD_ANALYTICS.ptl_internal_users
       on ptl_internal_users.mobile=orders.customer_mobile
   where orders.state = 3
),

return_route_id AS (
    SELECT
        route_id AS fwd_route_id,
        return_trip_cutoff_days
    FROM partload_analytics.ptl_routes
),

orders_enriched AS (
    SELECT
        f.order_id,
        f.batch_id,
		r.fwd_route_id,
        f.VEHICLE_REGISTRATION_NUMBER,
        f.route_id,
        f.route_name,
        f.drop_city_o,
        r.return_trip_cutoff_days,
        f.batch_created_at,
        f.ESTIMATED_DELIVERY_TS,
        pvz.city AS vehicle_city
    FROM final_return f
    LEFT JOIN return_route_id r
        ON r.fwd_route_id = f.route_id
    LEFT JOIN partload_application.vehicles v
        ON v.registration_number = f.VEHICLE_REGISTRATION_NUMBER
    LEFT JOIN partload_analytics.PTL_VEHICLE_ZONE pvz
        ON pvz.service_zone_id = v.service_zone_id
    WHERE f.order_status = 'Completed'
),

vehicle_lookback AS (
    SELECT
        curr.order_id,
        curr.batch_id AS curr_batch_id,
        curr.VEHICLE_REGISTRATION_NUMBER,
        curr.batch_created_at,
        curr.return_trip_cutoff_days,
        curr.ESTIMATED_DELIVERY_TS,
        curr.vehicle_city,
        curr.route_name,
        curr.drop_city_o,
        prev.batch_id AS matched_prev_batch_id
    FROM orders_enriched curr
    LEFT JOIN orders_enriched prev
        ON curr.VEHICLE_REGISTRATION_NUMBER = prev.VEHICLE_REGISTRATION_NUMBER
       AND prev.batch_id <> curr.batch_id
       AND prev.vehicle_city = curr.drop_city_o
       AND prev.batch_created_at < curr.batch_created_at
       AND prev.batch_created_at >=
           DATEADD(day, -curr.return_trip_cutoff_days, curr.batch_created_at)
),

return_trip_batches AS (
    SELECT
        curr_batch_id AS batch_id,
        CASE 
            WHEN COUNT(matched_prev_batch_id) > 0 THEN 'yes'
            ELSE 'no'
        END AS is_return_trip,
        MAX(matched_prev_batch_id) AS return_trip_batch_id
    FROM vehicle_lookback
    GROUP BY curr_batch_id
)
-- ==== RETIRED 2026-08-10 (RCA: delivery_type SDD/NDD flip) ===================
-- Kept for reference only. The COALESCE below silently fell through to the
-- slot_intervals_old path whenever the QUOTATIONS row had not yet replicated
-- (~10 min after booking), flipping SDD<->NDD for ~19% of orders. slots is a
-- current-state table: (route_configuration_id, route_id, start_time,
-- end_time) is unique, so the LEAD(created_at) 'version timeline' below was
-- never a version history -- it just resolves to the newest config.
-- ==========================================================================
-- , slots_base AS (
--   SELECT
--         route_configuration_id,
--         route_id,
--         start_time,
--         end_time,
--         EDD_BUFFER_IN_DAYS,
--         created_at,
--         ROW_NUMBER() OVER (
--             PARTITION BY route_id, start_time, end_time
--             ORDER BY created_at
--         ) AS rn_old,
--         LEAD(created_at) OVER (
--             PARTITION BY route_id, start_time, end_time
--             ORDER BY created_at
--         ) AS valid_to_old
--     FROM partload_application.slots
-- ),
-- slot_intervals_old AS (
--     SELECT
--         route_id,
--         start_time,
--         end_time,
--         EDD_BUFFER_IN_DAYS,
--         CASE WHEN rn_old = 1 THEN TIMESTAMP '1970-01-01 00:00:00'
--              ELSE created_at END AS valid_from,
--         valid_to_old AS valid_to
--     FROM slots_base
-- ),
-- slot_intervals_by_config AS (
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
-- )
-- ==== end retired slot CTEs ==============================================
,final as (



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
  CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.created_at)) AS created_at,
  CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.updated_at)) AS updated_at,
   CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.pickup_slot_start)) AS pickup_slot_start,
  CONCAT(
  TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_start)), 'DD Mon, YYYY, HH:MI AM') 
    || ' - ' || 
    TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_end)), 'HH24:MI')
  ) AS pickup_slot,

 -- ==== delivery_type: derived from the order itself ==========================
 -- estimated_delivery_ts is produced by applying EDD_BUFFER_IN_DAYS at booking,
 -- so invert it rather than re-reading slots. Immutable and available at T+0.
 -- ===========================================================================
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
--  CASE COALESCE(s_cfg.EDD_BUFFER_IN_DAYS, s_old.EDD_BUFFER_IN_DAYS)
--       WHEN 0 THEN 'SDD'
--       WHEN 1 THEN 'NDD'
--       ELSE NULL
--   END AS delivery_type,
-- ==== end retired delivery_type ===========================================

  CONCAT(pickup_lat, ' , ', pickup_lng) AS pickup_lat_lng,
  CONCAT(drop_lat, ' , ', drop_lng) AS drop_lat_lng,
	estimated_fare/100 as final_fare,
   -- ROUND(MAX(CASE WHEN load_details.entry_type = 'CUSTOMER_DECLARED' THEN load_details.chargeable_weight END) / 1000, 0) AS customer_declared_weight,
   ROUND(MAX(CASE WHEN load_details.entry_type = 'CUSTOMER_DECLARED'
               AND load_details.id = (
                   SELECT MIN(id) 
                   FROM PROD_CURATED.PARTLOAD_APPLICATION.LOAD_DETAILS ld2
                   WHERE ld2.order_id = ORDERS.id 
                   AND ld2.entry_type = 'CUSTOMER_DECLARED'
               )
               THEN load_details.chargeable_weight END) / 1000, 0) AS customer_declared_weight,
    ROUND(MAX(CASE WHEN load_details.entry_type = 'OPS_DECLARED' AND load_details.is_active = TRUE THEN load_details.chargeable_weight END) / 1000, 0) AS ops_declared_weight,
    max(case when order_fares.fare_reason_code = 'INITIAL_BOOKING' then round(total_fare/100,0) end) as Customer_declared_fare,
    max(case when order_fares.fare_reason_code = 'WEIGHT_REVISION_CHANGE' and load_details.is_active = True then round(total_fare/100,0) end) as Ops_fare,
  display_name AS goods_type,
  customer_name AS booker_name,
  customer_mobile AS booker_mobile_no,

  MAX(CASE WHEN contact_details.type = 0 THEN contact_details.name END) AS sender_name,
  MAX(CASE WHEN contact_details.type = 0 THEN contact_details.mobile END) AS sender_mobile,
  MAX(CASE WHEN contact_details.type = 1 THEN contact_details.name END) AS receiver_name,
  MAX(CASE WHEN contact_details.type = 1 THEN contact_details.mobile END) AS receiver_mobile,

  MAX(CASE WHEN contact_details.type = 0 THEN contact_details.address_line END) AS pickup_address,
  MAX(CASE WHEN contact_details.type = 1 THEN contact_details.address_line END) AS drop_address,

  driver_name,
  driver_mobile,
  VEHICLE_REGISTRATION_NUMBER,
  vehicle_type,
  -- estimated_fare / 100 AS upfront_fare_in_rs,
  CASE WHEN payment_status = 0 THEN 'Pending' ELSE 'Completed' END AS payment_status, 
  REPLACE(r.route_label, '-', ' - ') AS route_name, 
  orders.route_id, 
  
 
   ptl_routes.zone  AS city,
--   CASE
--     WHEN oac.all_ranked_combos = ORDERS.external_id
--     THEN NULL
--     ELSE oac.all_ranked_combos
-- END AS ranked_combo_order_ids
-- ,

  -- case when orders.route_id = '1' then 'BLR-CHE' when orders.route_id = '2' then 'CHE-BLR' when orders.route_id = '3' then 'BLR-COI' 
  -- when orders.route_id = '5' then 'BLR-MYS' else 'UNKNOWN' end as Route,
  orders.updated_at,
  batch_id,







FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
-- ==== RETIRED 2026-08-10 (RCA: delivery_type SDD/NDD flip) ===================
-- LEFT JOIN (
--     SELECT quotation_uuid, route_configuration_id
--     FROM PROD_CURATED.PARTLOAD_APPLICATION.QUOTATIONS
--     WHERE quotation_uuid IS NOT NULL
--     QUALIFY ROW_NUMBER() OVER (
--         PARTITION BY quotation_uuid ORDER BY updated_at DESC
--     ) = 1
-- ) q
--     ON q.quotation_uuid = ORDERS.quotation_uuid
--    AND ORDERS.created_at >= '2026-04-29 16:58:08.421000'::timestamp_ntz
-- ==== end retired QUOTATIONS join =========================================
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = ORDERS.route_id and ptl_routes.is_active = 'True'
LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ROUTES r
    ON r.id = ORDERS.route_id
   AND r.is_active = TRUE

LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.contact_details
  ON ORDERS.id = contact_details.order_id
  
LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.LOAD_DETAILS
  ON ORDERS.id = LOAD_DETAILS.order_id
  
-- LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.material_type
--   ON LOAD_DETAILS.material_type_id = material_type.material_type_id
  LEFT JOIN (
    SELECT ld.order_id, mt.display_name
    FROM PROD_CURATED.PARTLOAD_APPLICATION.LOAD_DETAILS ld
    JOIN PROD_CURATED.PARTLOAD_APPLICATION.material_type mt
        ON ld.material_type_id = mt.material_type_id
    WHERE ld.entry_type = 'CUSTOMER_DECLARED'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY ld.order_id ORDER BY ld.id) = 1
) material_type ON material_type.order_id = ORDERS.id


  
LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES
  ON ORDERS.external_id = ORDER_VEHICLES.order_external_id and ORDER_VEHICLES.is_active = TRUE

-- ==== RETIRED 2026-08-10 (RCA: delivery_type SDD/NDD flip) ===================
--   LEFT JOIN slot_intervals_by_config s_cfg
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
-- ==== end retired slot joins ==============================================
  
 left join PROD_CURATED.PARTLOAD_ANALYTICS.ptl_internal_users
 on ptl_internal_users.mobile=ORDERS.customer_mobile
left JOIN (SELECT * FROM PROD_CURATED.PARTLOAD_APPLICATION.batched_orders_v1 QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) = 1) bo ON bo.order_id = orders.id
LEFT JOIN prod_curated.partload_application.order_fares ON ARRAY_CONTAINS(load_details.id, order_fares.load_details_ids)


WHERE 
 
  date(ORDERS.created_at + interval '330 minutes') >= {{start_date}}
  AND date(ORDERS.created_at + interval '330 minutes') <= {{end_date}}  --+ interval '1 day'
[[AND TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_start)), 'HH24:MI') = {{pickup_slot_start}}]]
[[AND 
  CASE 
    WHEN ORDERS.state = 0 THEN 'Open' 
    WHEN ORDERS.state = 1 THEN 'Assigned' 
    WHEN ORDERS.state = 2 THEN 'Picked_up' 
    WHEN ORDERS.state = 3 THEN 'Completed'  
    WHEN ORDERS.state = 4 THEN 'Cancelled' 
  END = {{order_status}}]]
[[AND orders.external_id =  {{order_id}}]]
[[and 
  case 
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True'
end = {{is_test}}]]
[[and {{route_name}}]]
[[and batch_id = {{batch_id}}]]
[[AND date(ORDERS.pickup_slot_start + interval '330 minutes') = {{pickup_date}}]]
[[and VEHICLE_REGISTRATION_NUMBER = {{VEHICLE_REGISTRATION_NUMBER}}]]
and {{city}}
-- and order_status = 'Open' and pickup_slot_start > orders.updated_at
GROUP BY ALL
QUALIFY ROW_NUMBER() OVER (PARTITION BY orders.external_id ORDER BY orders.updated_at DESC) = 1

--, pickup_slot ASC

)




SELECT
    f.*,
   rtb.is_return_trip as is_return_trip
FROM final f
LEFT JOIN return_trip_batches rtb
    ON f.batch_id = rtb.batch_id
WHERE 1=1
[[AND f.delivery_type = {{delivery_type}}]]	
ORDER BY f.pickup_slot_start, f.created_at ;



-- select * FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS limit 10