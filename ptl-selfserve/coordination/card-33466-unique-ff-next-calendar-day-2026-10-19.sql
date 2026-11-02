
WITH online AS (
  SELECT 
    CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
    orders.customer_mobile,
    orders.customer_id,
    orders.created_at,
    orders.trip_end_time,
    orders.state,
    orders.external_id,
    orders.pickup_lat, orders.pickup_lng,
    orders.drop_lat, orders.drop_lng,
    ocr.created_at AS ocr_created_at
  FROM PROD_CURATED.PARTLOAD_APPLICATION.orders 
  LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS ON PTL_INTERNAL_USERS.mobile = orders.customer_mobile
  LEFT JOIN prod_curated.partload_analytics.ptl_routes ON ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
  LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDER_CANCELLATION_REASONS ocr ON orders.id = ocr.order_id
  WHERE CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at)) BETWEEN {{start_date}} AND {{end_date}} + interval '1 day'
    [[AND {{pickup_city}}]]
    [[AND {{drop_city}}]]
    [[AND 
      CASE 
        WHEN PTL_INTERNAL_USERS.mobile IS NULL THEN 'False'
        ELSE 'True'
      END = {{is_test}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
),

offline AS (
  SELECT 
    CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
    NULL AS customer_mobile,
    NULL AS customer_id,
    created_at,
    NULL AS trip_end_time,
    state,
    external_id,
    NULL AS pickup_lat, NULL AS pickup_lng,
    NULL AS drop_lat, NULL AS drop_lng,
    NULL AS ocr_created_at
  FROM prod_curated.gsheet_sync.ptl_offline_orders
  LEFT JOIN prod_curated.partload_analytics.ptl_routes ON ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
  WHERE created_at::date BETWEEN {{start_date}} AND {{end_date}}
    [[AND {{pickup_city}}]]
    [[AND {{drop_city}}]]
),

final AS (
  SELECT * FROM online
  UNION ALL
  SELECT * FROM offline
),

-- Unique demand (actual demand), online only. One row per order first: the OCR join can fan out.
ptl_orders AS (
  SELECT
    external_id,
    MIN(dated) AS dated,
    ANY_VALUE(customer_id) AS customer_id,
    MIN(created_at) AS created_at,
    ANY_VALUE(state) AS state,
    ANY_VALUE(trip_end_time) AS trip_end_time,
    ANY_VALUE(pickup_lat) AS pickup_lat, ANY_VALUE(pickup_lng) AS pickup_lng,
    ANY_VALUE(drop_lat) AS drop_lat, ANY_VALUE(drop_lng) AS drop_lng,
    MIN(ocr_created_at) AS ocr_created_at
  FROM final
  WHERE customer_id IS NOT NULL
  GROUP BY external_id
),

-- Step 1: drop orders cancelled within 60s of creation
survivors AS (
  SELECT * FROM ptl_orders
  WHERE NOT (state = 4 AND DATEDIFF(SECOND, created_at, ocr_created_at) <= 60)
),

-- Step 2: compare each survivor with the same customer's immediately preceding survivor
with_prev AS (
  SELECT *,
    LAG(created_at)    OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_created_at,
    LAG(pickup_lat)    OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_pickup_lat,
    LAG(pickup_lng)    OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_pickup_lng,
    LAG(drop_lat)      OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_drop_lat,
    LAG(drop_lng)      OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_drop_lng,
    LAG(state)         OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_state,
    LAG(trip_end_time) OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_trip_end_time
  FROM survivors
),

-- Duplicate = rebooked on the same or next IST calendar day as the predecessor, pickup AND drop within 100 m (chained);
-- the chain breaks if the predecessor was already completed before this order was created
unique_orders AS (
  SELECT *,
    COALESCE(
      prev_created_at IS NOT NULL
      AND DATEDIFF(DAY,
            CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(prev_created_at))::DATE,
            CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(created_at))::DATE) <= 1
      AND HAVERSINE(prev_pickup_lat, prev_pickup_lng, pickup_lat, pickup_lng) <= 0.1
      AND HAVERSINE(prev_drop_lat, prev_drop_lng, drop_lat, drop_lng) <= 0.1
      AND NOT (prev_state = 3 AND prev_trip_end_time < created_at),
      FALSE) AS is_duplicate
  FROM with_prev
),

unique_agg AS (
  SELECT
    p.dated,
    COUNT(DISTINCT CASE WHEN p.state = 3 THEN p.external_id END) AS completed_orders,
    COUNT(DISTINCT CASE WHEN u.is_duplicate = FALSE THEN u.external_id END) AS unique_demand
  FROM ptl_orders p
  LEFT JOIN unique_orders u ON u.external_id = p.external_id
  GROUP BY p.dated
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

  -- Unique Fulfillment: completed / actual demand (excl. 60s cancels, then deduplicated). Online only
  (
    SELECT completed_orders * 1.0 / NULLIF(unique_demand, 0)
    FROM unique_agg u
    WHERE u.dated = f.dated
  ) AS unique_fulfillment_perc

FROM final f
GROUP BY f.dated
ORDER BY f.dated;