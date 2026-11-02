WITH latest_batched_orders AS (
      SELECT *
      FROM partload_application.BATCHED_ORDERS_V1
      QUALIFY ROW_NUMBER() OVER (
          PARTITION BY order_id
          ORDER BY updated_at DESC
      ) = 1
  ),

  old_order_weight AS (
      SELECT
          o.id AS order_id,
          o.external_id,
          DATE(o.pickup_slot_start + INTERVAL '330 minutes') AS pickup_date,
          o.route_id,
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
GROUP BY 1,2,3,4
  ),

  new_order_weight AS (
      SELECT
          o.id AS order_id,
          o.external_id,
          DATE(o.pickup_slot_start + INTERVAL '330 minutes') AS pickup_date,
          o.route_id,

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
GROUP BY 1,2,3,4
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
      FROM partload_application.BATCH_V1 b
      JOIN latest_batched_orders bo
          ON b.id = bo.batch_id
      JOIN old_order_weight ow
          ON ow.order_id = bo.order_id
      JOIN partload_application.jobs
          ON jobs.batch_id = b.id
      JOIN partload_application.vehicles v
          ON jobs.vehicle_id = v.id
      JOIN partload_application.vehicle_categories vc
          ON vc.id = v.vehicle_categories_id
      JOIN partload_application.orders o
          ON o.id = bo.order_id
      LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS
          ON PTL_INTERNAL_USERS.mobile = o.customer_mobile
      LEFT JOIN prod_curated.partload_analytics.ptl_routes
          ON ptl_routes.route_id = o.route_id
         AND ptl_routes.is_active = 'True'
      WHERE b.status = 2
        AND bo.status = 3
        AND jobs.job_status = 6
        AND ow.pickup_date >= {{start_date}}
        AND ow.pickup_date <= {{end_date}}
        [[and case when ptl_internal_users.mobile is null then 'False' when ptl_internal_users.mobile is not null then 'True' end = {{is_test}}]]
        [[and {{pickup_city}}]]
        [[and {{drop_city}}]]
      

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY 1,2,3
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
      FROM partload_application.BATCH_V1 b
      JOIN latest_batched_orders bo
          ON b.id = bo.batch_id
      JOIN new_order_weight nw
          ON nw.order_id = bo.order_id
      JOIN partload_application.jobs
          ON jobs.batch_id = b.id
      JOIN partload_application.vehicles v
          ON jobs.vehicle_id = v.id
      JOIN partload_application.vehicle_categories vc
          ON vc.id = v.vehicle_categories_id
      JOIN partload_application.orders o
          ON o.id = bo.order_id
      LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS
          ON PTL_INTERNAL_USERS.mobile = o.customer_mobile
      LEFT JOIN prod_curated.partload_analytics.ptl_routes
          ON ptl_routes.route_id = o.route_id
         AND ptl_routes.is_active = 'True'
      WHERE b.status = 2
        AND bo.status = 3
        AND jobs.job_status = 6
        AND nw.pickup_date >= {{start_date}}
        AND nw.pickup_date <= {{end_date}}
        [[and case when ptl_internal_users.mobile is null then 'False' when ptl_internal_users.mobile is not null then 'True' end = {{is_test}}]]
        [[and {{pickup_city}}]]
        [[and {{drop_city}}]]
      

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY 1,2,3
  ),

  offline AS (
      SELECT
          vehicle_id,
          batch_id,
          CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
          LISTAGG(order_external_id, ', ') AS order_external_ids,
          ROUND(SUM(volumetric_weight)) AS volumetric_weight_in_kg,
          ROUND(MAX(weight_capacity)) AS truck_capacity,
          ROUND(SUM(COALESCE(actual_weight, volumetric_weight))) AS actual_weight
      FROM prod_curated.gsheet_sync.ptl_offline_orders
      LEFT JOIN prod_curated.partload_analytics.ptl_routes
          ON ptl_routes.route_id = ptl_offline_orders.route_id
         AND ptl_routes.is_active = 'True'
      WHERE created_at >= {{start_date}}
        AND created_at <= {{end_date}}
        AND TRIP_LEVEL_CONSIDERATION = 'yes'
        [[and {{pickup_city}}]]
        [[and {{drop_city}}]]
      GROUP BY 1,2,3
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
      SUM(COALESCE(actual_weight, volumetric_weight_in_kg))
          / NULLIF(SUM(truck_capacity), 0) AS utilization
  FROM final
  GROUP BY 1
  ORDER BY 1;
