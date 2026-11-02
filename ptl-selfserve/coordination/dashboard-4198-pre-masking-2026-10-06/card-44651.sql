 WITH slot_intervals AS (
      SELECT
          route_id,
          start_time,
          end_time,
          EDD_BUFFER_IN_DAYS,
          CASE
              WHEN ROW_NUMBER() OVER (
                  PARTITION BY route_id, start_time, end_time
                  ORDER BY created_at
              ) = 1
              THEN TIMESTAMP '1970-01-01 00:00:00'
              ELSE created_at
          END AS valid_from,
          LEAD(created_at) OVER (
              PARTITION BY route_id, start_time, end_time
              ORDER BY created_at
          ) AS valid_to
      FROM partload_application.slots
  ),

  latest_batched_orders AS (
      SELECT *
      FROM prod_curated.partload_application.batched_orders_v1
      QUALIFY ROW_NUMBER() OVER (
          PARTITION BY order_id
          ORDER BY updated_at DESC
      ) = 1
  ),

  final_return AS (
      SELECT
          orders.id,
          orders.external_id AS order_id,
          orders.route_id,
          ptl_routes.route_name,
          ptl_routes.drop_city AS drop_city_o,
          order_vehicles.vehicle_registration_number,
          bo.batch_id,
          bo.created_at + INTERVAL '330 mins' AS batch_created_at,
          orders.created_at + INTERVAL '330 mins' AS order_created_at_ist,
          orders.estimated_delivery_ts + INTERVAL '330 mins' AS estimated_delivery_ts,

          CASE
              WHEN s.EDD_BUFFER_IN_DAYS = 0 THEN 'SDD'
              WHEN s.EDD_BUFFER_IN_DAYS = 1 THEN 'NDD'
              ELSE NULL
          END AS delivery_type,

          CASE WHEN orders.state = 3 THEN 'Completed' END AS order_status

      FROM prod_curated.partload_application.orders

      LEFT JOIN prod_curated.partload_analytics.ptl_routes
          ON ptl_routes.route_id = orders.route_id
         AND ptl_routes.is_active = 'True'

      LEFT JOIN latest_batched_orders bo
          ON bo.order_id = orders.id

      LEFT JOIN prod_curated.partload_application.order_vehicles
          ON orders.external_id = order_vehicles.order_external_id
         AND order_vehicles.is_active = TRUE

      LEFT JOIN prod_curated.partload_analytics.ptl_internal_users
          ON ptl_internal_users.mobile = orders.customer_mobile

      LEFT JOIN slot_intervals s
          ON orders.route_id = s.route_id
         AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', orders.pickup_slot_start) AS TIME) = s.start_time
         AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', orders.pickup_slot_end) AS TIME) = s.end_time
         AND orders.created_at >= s.valid_from
         AND (orders.created_at < s.valid_to OR s.valid_to IS NULL)

      WHERE orders.state = 3
        AND bo.batch_id IS NOT NULL
        AND bo.status = 3

        [[and case
              when ptl_internal_users.mobile is null then 'False'
              when ptl_internal_users.mobile is not null then 'True'
            end = {{is_test}}]]
  

[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
),

  return_route_id AS (
      SELECT
          a.route_id AS fwd_route_id,
          a.route_name,
          SPLIT_PART(a.route_name, ' - ', 2) || ' - ' || SPLIT_PART(a.route_name, ' - ', 1) AS reverse_route,
          b.route_id AS reverse_route_id,
          a.return_trip_cutoff_days
      FROM partload_analytics.ptl_routes a
      LEFT JOIN partload_analytics.ptl_routes b
          ON a.route_name = SPLIT_PART(b.route_name, ' - ', 2) || ' - ' || SPLIT_PART(b.route_name, ' - ', 1)
      WHERE a.is_active = 'True'
        AND b.is_active = 'True'
  ),


  orders_enriched AS (
      SELECT
          f.order_id,
          f.batch_id,
          f.vehicle_registration_number,
          f.route_id,
          r.reverse_route_id,
          f.delivery_type,
          f.route_name,
          f.drop_city_o AS drop_city,
          r.return_trip_cutoff_days,
          f.batch_created_at AS created_at,
          f.estimated_delivery_ts,
           pvz.service_zone_name AS vehicle_city
      FROM final_return f
      LEFT JOIN return_route_id r
          ON r.fwd_route_id = f.route_id
      LEFT JOIN partload_application.vehicles v
          ON v.registration_number = f.vehicle_registration_number
     LEFT JOIN partload_application.service_zones pvz
        ON pvz.id = v.service_zone_id and SERVICE_ZONE_TYPE = 'PICKUP'
  ),

  batch_routes AS (
      SELECT DISTINCT
          vehicle_registration_number,
          batch_id,
          route_id,
          reverse_route_id,
          route_name,
          drop_city,
          vehicle_city,
          created_at,
          estimated_delivery_ts,
          return_trip_cutoff_days
      FROM orders_enriched
  ),

  batch_header AS (
      SELECT
          vehicle_registration_number,
          batch_id,
          MIN(created_at) AS batch_created_at,
          MAX(estimated_delivery_ts) AS batch_estimated_delivery_ts
      FROM batch_routes
      GROUP BY 1, 2
  ),

  sequenced_batches AS (
      SELECT
          vehicle_registration_number,
          batch_id,
          batch_created_at,
          batch_estimated_delivery_ts,
          LAG(batch_id) OVER (
              PARTITION BY vehicle_registration_number
              ORDER BY batch_created_at, batch_id
          ) AS prev_batch_id
      FROM batch_header
  ),

  matched_return_routes AS (
      SELECT DISTINCT
          curr.vehicle_registration_number,
          curr.batch_id AS return_batch_id,
          curr.route_id AS return_route_id,
          sb.prev_batch_id AS fwd_batch_id
      FROM sequenced_batches sb
      JOIN batch_routes curr
          ON curr.vehicle_registration_number = sb.vehicle_registration_number
         AND curr.batch_id = sb.batch_id
      JOIN batch_routes prev
          ON prev.vehicle_registration_number = curr.vehicle_registration_number
         AND prev.batch_id = sb.prev_batch_id
         AND prev.batch_id <> curr.batch_id
         AND prev.vehicle_city = curr.drop_city
         AND prev.created_at < curr.created_at
         --AND prev.route_id = curr.reverse_route_id
      WHERE sb.prev_batch_id IS NOT NULL
  ),

  dedup_batches AS (
      SELECT
          curr.order_id,
          curr.batch_id,
          curr.route_id,
          curr.route_name,
          curr.created_at,
          curr.delivery_type,
          CASE
              WHEN MAX(
                  CASE WHEN m.fwd_batch_id IS NOT NULL THEN 1 ELSE 0 END
              ) OVER (PARTITION BY curr.batch_id) = 1
              THEN 'Yes'
              ELSE 'No'
          END AS batch_is_return_trip
      FROM orders_enriched curr
      LEFT JOIN matched_return_routes m
          ON curr.vehicle_registration_number = m.vehicle_registration_number
         AND curr.batch_id = m.return_batch_id
         AND curr.route_id = m.return_route_id
      QUALIFY ROW_NUMBER() OVER (
          PARTITION BY curr.order_id
          ORDER BY curr.created_at DESC
      ) = 1
  ),

  return_trip_batches AS (
      SELECT DISTINCT
          db.batch_id
      FROM dedup_batches db
      LEFT JOIN partload_analytics.ptl_routes
          ON db.route_id = ptl_routes.route_id
         AND ptl_routes.is_active = 'True'
      WHERE db.batch_is_return_trip = 'Yes'
        AND DATE(db.created_at) >= {{start_date}}
        AND DATE(db.created_at) <= {{end_date}}
        [[AND {{route_name}}]]
        [[AND db.delivery_type = {{delivery_type}}]]
  ),

  old_order_weight AS (
      SELECT
          o.id AS order_id,
          o.external_id,
          DATE(o.pickup_slot_start + INTERVAL '330 minutes') AS pickup_date,
          ROUND(MAX(ld.volumetric_weight) / 1000, 0) AS volumetric_weight_in_kg,
          ROUND(
              COALESCE(
                  MAX(ptl.actual_weight),
                  MAX(ld.volumetric_weight) / 1000
              ),
              0
          ) AS actual_weight
      FROM partload_application.orders o
      LEFT JOIN partload_application.load_details ld
          ON ld.order_id = o.id
      LEFT JOIN gsheet_sync.ptl_table ptl
          ON ptl.order_id = o.id
      WHERE CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at)) <= '2025-07-11'
        AND o.state = 3
      

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY 1, 2, 3
  ),

  new_order_weight AS (
      SELECT
          o.id AS order_id,
          o.external_id,
          DATE(o.pickup_slot_start + INTERVAL '330 minutes') AS pickup_date,
          ROUND(MAX(ld.volumetric_weight) / 1000, 0) AS volumetric_weight_in_kg,
          ROUND(
              COALESCE(
                  MAX(CASE
                      WHEN ld.entry_type = 'OPS_DECLARED'
                       AND ld.is_active = TRUE
                      THEN ld.chargeable_weight
                  END),
                  MAX(CASE
                      WHEN ld.entry_type = 'CUSTOMER_DECLARED'
                      THEN ld.chargeable_weight
                  END)
              ) / 1000,
              0
          ) AS actual_weight
      FROM partload_application.orders o
      LEFT JOIN partload_application.load_details ld
          ON ld.order_id = o.id
      WHERE CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at)) > '2025-07-11'
        AND o.state = 3
      

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY 1, 2, 3
  ),

  online AS (
      SELECT
          jobs.vehicle_id,
          b.id AS batch_id,
          CAST(DATE_TRUNC({{period}}, ow.pickup_date) AS DATE) AS dated,
          LISTAGG(DISTINCT ow.external_id, ', ') AS order_external_ids,
          SUM(ow.volumetric_weight_in_kg) AS volumetric_weight_in_kg,
          ROUND(MAX(vc.weight_capacity)) AS truck_capacity,
          SUM(ow.actual_weight) AS actual_weight
      FROM partload_application.batch_v1 b
      JOIN return_trip_batches rtb
          ON rtb.batch_id = b.id
      JOIN latest_batched_orders bo
          ON b.id = bo.batch_id
         AND bo.status = 3
      JOIN old_order_weight ow
          ON ow.order_id = bo.order_id
      JOIN partload_application.jobs
          ON jobs.batch_id = b.id
         AND jobs.job_status = 6
      JOIN partload_application.vehicles v
          ON jobs.vehicle_id = v.id
      JOIN partload_application.vehicle_categories vc
          ON vc.id = v.vehicle_categories_id
      JOIN partload_application.orders o
          ON o.id = bo.order_id
      LEFT JOIN prod_curated.partload_analytics.ptl_internal_users
          ON ptl_internal_users.mobile = o.customer_mobile
      LEFT JOIN prod_curated.partload_analytics.ptl_routes
          ON ptl_routes.route_id = o.route_id
         AND ptl_routes.is_active = 'True'
      WHERE b.status = 2
        AND ow.pickup_date >= {{start_date}}
        AND ow.pickup_date <= {{end_date}}
        [[and case when ptl_internal_users.mobile is null then 'False' when ptl_internal_users.mobile is not null then 'True' end = {{is_test}}]]
        [[and {{pickup_city}}]]
        [[and {{drop_city}}]]
      

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY 1, 2, 3
  ),

  new_online AS (
      SELECT
          jobs.vehicle_id,
          b.id AS batch_id,
          CAST(DATE_TRUNC({{period}}, nw.pickup_date) AS DATE) AS dated,
          LISTAGG(DISTINCT nw.external_id, ', ') AS order_external_ids,
          SUM(nw.volumetric_weight_in_kg) AS volumetric_weight_in_kg,
          ROUND(MAX(vc.weight_capacity)) AS truck_capacity,
          SUM(nw.actual_weight) AS actual_weight
      FROM partload_application.batch_v1 b
      JOIN return_trip_batches rtb
          ON rtb.batch_id = b.id
      JOIN latest_batched_orders bo
          ON b.id = bo.batch_id
         AND bo.status = 3
      JOIN new_order_weight nw
          ON nw.order_id = bo.order_id
      JOIN partload_application.jobs
          ON jobs.batch_id = b.id
         AND jobs.job_status = 6
      JOIN partload_application.vehicles v
          ON jobs.vehicle_id = v.id
      JOIN partload_application.vehicle_categories vc
          ON vc.id = v.vehicle_categories_id
      JOIN partload_application.orders o
          ON o.id = bo.order_id
      LEFT JOIN prod_curated.partload_analytics.ptl_internal_users
          ON ptl_internal_users.mobile = o.customer_mobile
      LEFT JOIN prod_curated.partload_analytics.ptl_routes
          ON ptl_routes.route_id = o.route_id
         AND ptl_routes.is_active = 'True'
      WHERE b.status = 2
        AND nw.pickup_date >= {{start_date}}
        AND nw.pickup_date <= {{end_date}}
        [[and case when ptl_internal_users.mobile is null then 'False' when ptl_internal_users.mobile is not null then 'True' end = {{is_test}}]]
        [[and {{pickup_city}}]]
        [[and {{drop_city}}]]
      

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY 1, 2, 3
  ),

  offline AS (
      SELECT
          vehicle_id,
          ptl_offline_orders.batch_id,
          CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
          LISTAGG(order_external_id, ', ') AS order_external_ids,
          ROUND(SUM(volumetric_weight)) AS volumetric_weight_in_kg,
          ROUND(MAX(weight_capacity)) AS truck_capacity,
          ROUND(SUM(COALESCE(actual_weight, volumetric_weight))) AS actual_weight
      FROM prod_curated.gsheet_sync.ptl_offline_orders
      JOIN return_trip_batches rtb
          ON rtb.batch_id = ptl_offline_orders.batch_id
      LEFT JOIN prod_curated.partload_analytics.ptl_routes
          ON ptl_routes.route_id = ptl_offline_orders.route_id
         AND ptl_routes.is_active = 'True'
      WHERE created_at >= {{start_date}}
        AND created_at <= {{end_date}}
        AND trip_level_consideration = 'yes'
        [[and {{pickup_city}}]]
        [[and {{drop_city}}]]
      GROUP BY 1, 2, 3
  ),

  final AS (
      SELECT * FROM online
      UNION ALL
      SELECT * FROM offline
      UNION ALL
      SELECT * FROM new_online
  )

  SELECT
      dated,
      SUM(COALESCE(actual_weight, volumetric_weight_in_kg)) AS total_actual_weight,
      SUM(truck_capacity) AS total_capacity,
      SUM(COALESCE(actual_weight, volumetric_weight_in_kg))
          / NULLIF(SUM(truck_capacity), 0) AS return_trip_utilization
  FROM final
  GROUP BY 1
  ORDER BY 1;

