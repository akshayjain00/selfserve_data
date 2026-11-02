WITH slot_intervals AS (
    SELECT 
        route_id,
        start_time,
        end_time,
        EDD_BUFFER_IN_DAYS,
    
        CASE 
            WHEN ROW_NUMBER() OVER (PARTITION BY route_id, start_time, end_time ORDER BY created_at) = 1 
            THEN TIMESTAMP '1970-01-01 00:00:00'   
            ELSE created_at 
        END AS valid_from,
        LEAD(created_at) OVER (
            PARTITION BY route_id, start_time, end_time
            ORDER BY created_at
        ) AS valid_to
    FROM partload_application.slots)
,final_return AS (
    SELECT 
        orders.id,
        orders.external_id AS order_id,
        orders.route_id,
        ptl_routes.route_name,
        ptl_routes.drop_city AS drop_city_o,
        ORDER_VEHICLES.VEHICLE_REGISTRATION_NUMBER,
        bo.batch_id,
        bo.created_at + interval '330 mins' AS batch_created_at,
        orders.created_at + interval '330 mins' AS order_created_at_ist,
        ESTIMATED_DELIVERY_TS + interval '330 mins' AS ESTIMATED_DELIVERY_TS,
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
    LEFT JOIN (
        SELECT *
        FROM prod_curated.partload_application.batched_orders_v1
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY order_id 
            ORDER BY updated_at DESC
        ) = 1
    ) bo 
        ON bo.order_id = orders.id
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES
        ON orders.external_id = ORDER_VEHICLES.order_external_id
       AND ORDER_VEHICLES.is_active = TRUE
    LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.ptl_internal_users
        ON ptl_internal_users.mobile = orders.customer_mobile
	LEFT JOIN slot_intervals s
ON ORDERS.route_id = s.route_id
 AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_start) AS TIME) = s.start_time
   AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_end)   AS TIME) = s.end_time
 AND ORDERS.created_at >= s.valid_from
 AND (ORDERS.created_at < s.valid_to OR s.valid_to IS NULL)

    WHERE orders.state = 3
	-- [[and delivery_type = {{delivery_type}}]]
      AND bo.batch_id IS NOT NULL
      [[and case 
            when ptl_internal_users.mobile is null then 'False'
            when ptl_internal_users.mobile is not null then 'True'
          end = {{is_test}}]]
),

return_route_id AS (
    SELECT
        a.route_id AS fwd_route_id,
        a.pickup_city AS fwd_pickup_city,
        a.drop_city,
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
        r.fwd_route_id,
        f.VEHICLE_REGISTRATION_NUMBER,
        f.route_id,
        r.reverse_route_id,
        f.delivery_type,
        f.route_name,
        r.reverse_route,
        f.drop_city_o AS drop_city,
        r.return_trip_cutoff_days,
        f.batch_created_at AS created_at,
        f.ESTIMATED_DELIVERY_TS,
        pvz.service_zone_name AS vehicle_city
    FROM final_return f
    LEFT JOIN return_route_id r
        ON r.fwd_route_id = f.route_id
    LEFT JOIN partload_application.vehicles v
        ON v.registration_number = f.VEHICLE_REGISTRATION_NUMBER
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
        ) AS prev_batch_id,
        LAG(batch_created_at) OVER (
            PARTITION BY vehicle_registration_number
            ORDER BY batch_created_at, batch_id
        ) AS prev_ct,
        LAG(batch_estimated_delivery_ts) OVER (
            PARTITION BY vehicle_registration_number
            ORDER BY batch_created_at, batch_id
        ) AS prev_estimated_delivery_ts
    FROM batch_header
),

matched_return_routes AS (
    SELECT DISTINCT
        curr.vehicle_registration_number,
        curr.batch_id AS return_batch_id,
        curr.route_id AS return_route_id,
        curr.route_name AS return_route_name,
        curr.created_at,
        curr.return_trip_cutoff_days,
        sb.prev_batch_id AS fwd_batch_id,
        prev.created_at AS prev_ct,
        prev.drop_city,
        curr.vehicle_city,
        prev.route_id AS forward_route_id,
        prev.route_name AS forward_route_name
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
      -- AND prev.route_id = curr.reverse_route_id
    WHERE sb.prev_batch_id IS NOT NULL
),

final_ctee AS (
    SELECT
        curr.order_id,
        curr.batch_id,
        curr.vehicle_registration_number,
        curr.route_id,
        curr.route_name,
        curr.created_at,
		curr.delivery_type,
        curr.return_trip_cutoff_days,
        m.prev_ct,
        m.drop_city,
        curr.vehicle_city,
        m.fwd_batch_id,
        m.forward_route_name,
        curr.route_name AS return_route_name,

        CASE
            WHEN m.fwd_batch_id IS NOT NULL THEN 'Yes'
            ELSE 'No'
        END AS is_return_route_wise,

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
),

dedup_batches AS (
    SELECT *
    FROM final_ctee
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY order_id
        ORDER BY created_at DESC
    ) = 1
)

, total_batches_period AS (
    SELECT
        DATE_TRUNC({{period}}, created_at) AS period,
        COUNT(DISTINCT batch_id) AS total_batches
    FROM orders_enriched
	
	left join partload_analytics.ptl_routes
	on orders_enriched.route_id = ptl_routes.route_id and ptl_routes.is_active = 'True'
	where 1=1
	[[and  {{route_name}}]]
	[[and delivery_type = {{delivery_type}}]]
	and date(created_at ) >= {{start_date}} 
  AND date(created_at ) <= {{end_date}}  

    
    GROUP BY 1
),

return_batches_period AS (
    SELECT
        DATE_TRUNC({{period}}, created_at) AS period,
        COUNT(DISTINCT batch_id) AS return_trip_batches
    FROM dedup_batches db
    LEFT JOIN partload_analytics.ptl_routes
        ON db.route_id = ptl_routes.route_id
       AND ptl_routes.is_active = 'True'
    WHERE batch_is_return_trip = 'Yes'
      [[AND {{route_name}}]]
      AND DATE(created_at) >= {{start_date}}
      AND DATE(created_at) <= {{end_date}}
	  [[and delivery_type = {{delivery_type}}]]
    GROUP BY 1
)

SELECT
    t.period,
    t.total_batches,
    COALESCE(r.return_trip_batches, 0) AS return_trip_batches,
    ROUND(
        COALESCE(r.return_trip_batches, 0)::decimal
        / NULLIF(t.total_batches, 0),
        4
    ) AS return_trip_pct
FROM total_batches_period t
LEFT JOIN return_batches_period r
    ON t.period = r.period
ORDER BY t.period;