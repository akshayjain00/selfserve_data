WITH final AS (
    SELECT 
        b.id AS batch_id,
        DATE(b.created_at + INTERVAL '330 minutes') AS batch_date,
        order_external_id,
        ptl.PICKUP_REACHED_TIMESTAMP,
        pickup_lat,
        pickup_lng,
        LAG(pickup_lat) OVER (PARTITION BY b.id ORDER BY ptl.PICKUP_REACHED_TIMESTAMP) AS prev_pickup_lat,
        LAG(pickup_lng) OVER (PARTITION BY b.id ORDER BY ptl.PICKUP_REACHED_TIMESTAMP) AS prev_pickup_lng,
        
        -- ptl.DROP_START_TIMESTAMP,
        -- drop_lat,
        -- drop_lng,
        -- LAG(drop_lat) OVER (PARTITION BY b.id ORDER BY TO_TIMESTAMP(ptl.DROP_START_TIMESTAMP)) AS prev_drop_lat,
        -- LAG(drop_lng) OVER (PARTITION BY b.id ORDER BY TO_TIMESTAMP(ptl.DROP_START_TIMESTAMP)) AS prev_drop_lng,
    FROM partload_application.BATCH_V1 b 
    JOIN partload_application.BATCHED_ORDERS_V1 bo ON b.id = bo.batch_id
	JOIN partload_application.jobs on jobs.batch_id = bo.batch_id
    JOIN partload_application.load_details ld ON ld.order_id = bo.order_id
    JOIN partload_application.vehicles v ON jobs.vehicle_id = v.id 
    JOIN partload_application.vehicle_categories vc ON vc.id = v.vehicle_categories_id
    JOIN gsheet_sync.ptl_table ptl ON ptl.order_id = bo.order_id
    JOIN partload_application.orders o ON o.id = bo.order_id
    LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
        ON PTL_INTERNAL_USERS.mobile = o.customer_mobile
	left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = o.route_id and ptl_routes.is_active = 'True'

    WHERE b.status = 2
      AND DATE(b.created_at + INTERVAL '330 minutes') 
          BETWEEN {{start_date}}::DATE
              AND {{end_date}}::DATE
    [[AND 
      CASE 
        WHEN ptl_internal_users.mobile IS NULL THEN 'False'
        WHEN ptl_internal_users.mobile IS NOT NULL THEN 'True'
      END = {{is_test}}]]
	  [[and {{pickup_city}}]]
	[[and {{drop_city}}]]
    

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
ORDER BY batch_id--, TO_TIMESTAMP(PICKUP_REACHED_TIMESTAMP)
)

SELECT 
    batch_date,
    avg(6371 * 2 * ASIN(SQRT(
        POWER(SIN(RADIANS(pickup_lat - prev_pickup_lat) / 2), 2) +
        COS(RADIANS(pickup_lat)) * COS(RADIANS(prev_pickup_lat)) *
        POWER(SIN(RADIANS(pickup_lng - prev_pickup_lng) / 2), 2)
    ))) AS avg_pick_dry_run_distance_km
    -- ,
    -- 6371 * 2 * ASIN(SQRT(
    --     POWER(SIN(RADIANS(drop_lat - prev_drop_lat) / 2), 2) +
    --     COS(RADIANS(drop_lat)) * COS(RADIANS(prev_drop_lat)) *
    --     POWER(SIN(RADIANS(drop_lng - prev_drop_lng) / 2), 2)
    -- )) AS drop_dry_run_distance_km
FROM final
group by 1;
