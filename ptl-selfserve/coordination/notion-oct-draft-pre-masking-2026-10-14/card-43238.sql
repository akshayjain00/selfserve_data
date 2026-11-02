
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
,online AS (
  SELECT 
    CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
    orders.customer_mobile,
    orders.created_at,
    orders.state,
    orders.external_id,
    orders.pickup_lat, orders.pickup_lng,
    orders.drop_lat, orders.drop_lng,
    ocr.created_at AS ocr_created_at
  FROM PROD_CURATED.PARTLOAD_APPLICATION.orders 
  LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS ON PTL_INTERNAL_USERS.mobile = orders.customer_mobile
  LEFT JOIN prod_curated.partload_analytics.ptl_routes ON ptl_routes.route_id = orders.route_id and is_active = 'True'
  LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDER_CANCELLATION_REASONS ocr ON orders.id = ocr.order_id
  LEFT JOIN slot_intervals s
ON orders.route_id = s.route_id
 AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', orders.pickup_slot_start) AS TIME) = s.start_time
   AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', orders.pickup_slot_end)   AS TIME) = s.end_time
 AND orders.created_at >= s.valid_from
 AND (orders.created_at < s.valid_to OR s.valid_to IS NULL)
 
  WHERE CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at)) BETWEEN {{start_date}} AND {{end_date}} + interval '1 day'
    [[AND {{pickup_city}}]]
    [[AND {{drop_city}}]]
    [[AND 
      CASE 
        WHEN PTL_INTERNAL_USERS.mobile IS NULL THEN 'False'
        ELSE 'True'
      END = {{is_test}}]]
 [[and 
  CASE
      WHEN s.EDD_BUFFER_IN_DAYS = 0 THEN 'SDD'
      WHEN s.EDD_BUFFER_IN_DAYS = 1 THEN 'NDD'
      ELSE NULL
  END = {{delivery_type}}
]]	  


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
),

offline AS (
  SELECT 
    CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
    NULL AS customer_mobile,
    created_at,
    state,
    external_id,
    NULL AS pickup_lat, NULL AS pickup_lng,
    NULL AS drop_lat, NULL AS drop_lng,
    NULL AS ocr_created_at
  FROM prod_curated.gsheet_sync.ptl_offline_orders
  LEFT JOIN prod_curated.partload_analytics.ptl_routes ON ptl_routes.route_id = ptl_offline_orders.route_id and is_active = 'True'
  LEFT JOIN slot_intervals s
ON ptl_offline_orders.route_id = s.route_id
 AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ptl_offline_orders.pickup_slot_start) AS TIME) = s.start_time
   --AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ptl_offline_orders.pickup_slot_end)   AS TIME) = s.end_time
 AND ptl_offline_orders.created_at >= s.valid_from
 AND (ptl_offline_orders.created_at < s.valid_to OR s.valid_to IS NULL)
 
  WHERE created_at::date BETWEEN {{start_date}} AND {{end_date}}
    [[AND {{pickup_city}}]]
    [[AND {{drop_city}}]]
	[[and 
  CASE
      WHEN s.EDD_BUFFER_IN_DAYS = 0 THEN 'SDD'
      WHEN s.EDD_BUFFER_IN_DAYS = 1 THEN 'NDD'
      ELSE NULL
  END = {{delivery_type}}
]]

),

final AS (
  SELECT * FROM online
  UNION ALL
  SELECT * FROM offline
),

clustered_orders AS (
  SELECT *,
    customer_mobile || '-' || DATE_TRUNC('HOUR', created_at) || '-' ||
    ROUND(pickup_lat, 3) || '-' || ROUND(pickup_lng, 3) || '-' ||
    ROUND(drop_lat, 3) || '-' || ROUND(drop_lng, 3) AS cluster_id
  FROM final
  WHERE customer_mobile IS NOT NULL  -- Only online orders used for clustering
),

cluster_level_agg AS (
  SELECT
    MIN(dated) AS dated,
    cluster_id,
    COUNT(DISTINCT external_id) AS order_count,
    SUM(CASE WHEN state = 3 THEN 1 ELSE 0 END) AS is_fulfilled
  FROM clustered_orders
  GROUP BY cluster_id
)

SELECT
  f.dated,
  
  -- Daily Order-Level Metrics
  COUNT(DISTINCT CASE WHEN state = 3 THEN external_id END) * 1.0 
    / NULLIF(COUNT(DISTINCT external_id), 0) AS fulfillment_perc,

  COUNT(DISTINCT CASE WHEN state = 3 THEN external_id END) * 1.0 
    / NULLIF(
        COUNT(DISTINCT external_id) - 
        COUNT(DISTINCT CASE WHEN DATEDIFF(SECOND, created_at, ocr_created_at) <= 60 THEN external_id END),
        0
      ) AS fulfillment_excluding_60second_cancellations,

  COUNT(DISTINCT CASE WHEN state = 4 THEN external_id END) * 1.0 
    / NULLIF(COUNT(DISTINCT external_id), 0) AS cancellation_perc,

  COUNT(DISTINCT CASE WHEN state IN (0,1,2) THEN external_id END) * 1.0 
    / NULLIF(COUNT(DISTINCT external_id), 0) AS inprocess_order_perc,

  -- Clustered Fulfillment Metric (only online)
  (
    SELECT 
      SUM(is_fulfilled) * 1.0 / NULLIF(COUNT(cluster_id), 0)
    FROM cluster_level_agg c
    WHERE c.dated = f.dated
  ) AS unique_fulfillment_perc

FROM final f
GROUP BY f.dated
ORDER BY f.dated;