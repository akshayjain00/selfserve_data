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
    FROM partload_application.slots
),

-- Count orders per route per city
route_order_count AS (
    SELECT 
        o.route_id,
        r.zone AS city,
		route_name,
        COUNT(*) AS route_orders
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS o
    LEFT JOIN prod_curated.partload_analytics.ptl_routes r 
        ON r.route_id = o.route_id and r.is_active = 'True'
	WHERE date(o.created_at + interval '330 minutes') >= {{start_date}}
      AND date(o.created_at + interval '330 minutes') <= {{end_date}}
    

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY 1,2,3
)
-- select * from route_order_count
,

-- Calculate percentile rank for bucket assignment
route_rank AS (
    SELECT
        route_id,
        city,
        route_orders,
		route_name,
        PERCENT_RANK() OVER (
            ORDER BY route_orders
        ) AS pct_rank
    FROM route_order_count
)
-- select * from route_rank
-- order by pct_rank desc
,
final AS (
SELECT
  orders.id,
  CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.created_at))::date AS dated,
  CASE 
    WHEN ORDERS.state = 0 THEN 'Open' 
    WHEN ORDERS.state = 1 THEN 'Assigned' 
    WHEN ORDERS.state = 2 THEN 'Picked_up' 
    WHEN ORDERS.state = 3 THEN 'Completed'  
    WHEN ORDERS.state = 4 THEN 'Cancelled' 
  END AS ORDER_STATUS,
  external_id AS order_id,
  CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.created_at)) AS created_at,
  CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.updated_at)) AS updated_at,

  CONCAT(
    TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_start)), 'DD Mon, YYYY, HH:MI AM'),
    ' - ',
    TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_end)), 'HH24:MI')
  ) AS pickup_slot,

  CONCAT(
    TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_start)), 'HH24:MI'),
    ' - ',
    TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_end)), 'HH24:MI')
  ) AS slot,

  CASE
    WHEN s.EDD_BUFFER_IN_DAYS = 0 THEN 'SDD'
    WHEN s.EDD_BUFFER_IN_DAYS = 1 THEN 'NDD'
    ELSE NULL
  END AS delivery_type,

  ptl_routes.route_name, 
  orders.route_id,  
  ptl_routes.zone AS city,
  orders.updated_at,
  batch_id,

  -- Overlapping buckets as array
  ARRAY_CONSTRUCT(
      IFF(rr.pct_rank >= 0.50, 'TOP_50', NULL),
      IFF(rr.pct_rank >= 0.75, 'TOP_25', NULL),
      IFF(rr.pct_rank >= 0.90, 'TOP_10', NULL),
	  IFF(rr.pct_rank < 0.50, 'BOTTOM_50', NULL))::varchar AS route_bucket_flags

FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
LEFT JOIN prod_curated.partload_analytics.ptl_routes 
    ON ptl_routes.route_id = ORDERS.route_id and ptl_routes.is_active = 'True'

LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.contact_details
    ON ORDERS.id = contact_details.order_id
  
LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.LOAD_DETAILS
    ON ORDERS.id = LOAD_DETAILS.order_id
  
LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.material_type
    ON LOAD_DETAILS.material_type_id = material_type.material_type_id

LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES
    ON ORDERS.external_id = ORDER_VEHICLES.order_external_id 
   AND ORDER_VEHICLES.is_active = TRUE

LEFT JOIN slot_intervals s
    ON ORDERS.route_id = s.route_id
   AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_start) AS TIME) = s.start_time
   AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_end)   AS TIME) = s.end_time
   AND ORDERS.created_at >= s.valid_from
   AND (ORDERS.created_at < s.valid_to OR s.valid_to IS NULL)

LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.ptl_internal_users
    ON ptl_internal_users.mobile = ORDERS.customer_mobile

LEFT JOIN (
    SELECT * 
    FROM PROD_CURATED.PARTLOAD_APPLICATION.batched_orders_v1 
    QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) = 1
) bo 
    ON bo.order_id = orders.id

LEFT JOIN prod_curated.partload_application.order_fares 
    ON ARRAY_CONTAINS(load_details.id, order_fares.load_details_ids)

-- Join percentile ranking for buckets
LEFT JOIN route_rank rr
    ON rr.route_id = orders.route_id
   AND rr.city = ptl_routes.zone

WHERE 
  date(ORDERS.created_at + interval '330 minutes') >= {{start_date}} 
  AND date(ORDERS.created_at + interval '330 minutes') <= {{end_date}}

[[AND TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_start)), 'HH24:MI') = {{pickup_slot_start}}]]
[[AND ORDER_STATUS = {{order_status}}]]
[[AND orders.external_id = {{order_id}}]]
[[AND (CASE WHEN ptl_internal_users.mobile IS NULL THEN 'False' ELSE 'True' END) = {{is_test}}]]
[[AND {{route_name}}]]
[[AND date(ORDERS.pickup_slot_start + interval '330 minutes') = {{pickup_date}}]]
AND {{city}}



[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY ALL
QUALIFY ROW_NUMBER() OVER (PARTITION BY orders.external_id ORDER BY orders.updated_at DESC) = 1
)
select 
	DATE_TRUNC({{period}}, dated) AS dated,
	route_name,
	-- slot,
	-- 100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY route_name) AS order_share_perc_on_route_level,
	-- count(case when order_status = 'Completed' then 1 end) as total_completed_orders,
	-- count(case when order_status = 'Cancelled' then 1 end) as total_cancelled_orders,
	-- 100*total_cancelled_orders/total_orders as Cancelled_Perc,
	count(case when order_status = 'Completed' then 1 end)/count(*) as Fulfillment_Perc
from final
[[WHERE route_bucket_flags ILIKE '%' || {{route_rank}} || '%']]
group by 1,2
order by 1,2