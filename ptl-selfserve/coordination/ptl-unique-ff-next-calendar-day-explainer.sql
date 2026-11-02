/* =====================================================================================
   PTL Unique Fulfilment % — standalone, step-by-step version
   Same logic as the unique_fulfillment_perc column on Metabase card 33466
   (https://metabase.prod-internal.porter.in/question/33466), live since 2026-10-19.

   Unique FF = completed orders / unique demand

   Unique demand is built in two steps:
     1. Drop orders cancelled within 60 seconds of creation
        (clock: orders.created_at -> order_cancellation_reasons.created_at).
     2. From what is left, drop DUPLICATES. An order is a duplicate of the same
        customer's immediately previous (surviving) order when ALL hold:
          - it is created on the SAME or NEXT calendar day (IST) as that previous order
          - pickup is within 100 m of the previous pickup
          - drop   is within 100 m of the previous drop
          - the previous order was NOT already completed (trip_end_time) before this
            order was created  -> a completed trip breaks the chain
        Duplicates chain: Mon -> Tue -> Wed rebookings of one route count as ONE demand.

   Completed orders (numerator) are never removed: every state = 3 order counts.

   How to use
     - Change the dates in `params` and run in Snowflake.
     - Final SELECT = monthly summary. To see individual orders, comment it out and
       run the "ORDER-LEVEL CHECK" query at the bottom instead.
     - Internal/test users are INCLUDED, as on the card's default view.
       Uncomment the line in `base` to exclude them.
   ===================================================================================== */

WITH params AS (
  SELECT '2026-01-01'::DATE AS start_date,      -- inclusive, IST
         '2026-09-30'::DATE AS end_date         -- inclusive, IST
),

-- One row per order (the cancellation-reasons join can return several rows per order)
base AS (
  SELECT
    o.external_id,
    ANY_VALUE(o.customer_id)                                              AS customer_id,
    MIN(o.created_at)                                                     AS created_at,       -- UTC
    MIN(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.created_at))::DATE      AS created_date_ist,
    ANY_VALUE(o.state)                                                    AS state,            -- 3 = completed, 4 = cancelled
    ANY_VALUE(o.trip_end_time)                                            AS trip_end_time,
    ANY_VALUE(o.pickup_lat) AS pickup_lat, ANY_VALUE(o.pickup_lng) AS pickup_lng,
    ANY_VALUE(o.drop_lat)   AS drop_lat,   ANY_VALUE(o.drop_lng)   AS drop_lng,
    MIN(ocr.created_at)                                                   AS cancelled_at
  FROM prod_curated.partload_application.orders o
  LEFT JOIN prod_curated.partload_application.order_cancellation_reasons ocr ON ocr.order_id = o.id
  CROSS JOIN params
  WHERE CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.created_at) >= params.start_date
    AND CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.created_at) <  params.end_date + 1
    -- AND o.customer_id NOT IN (SELECT customer_uuid FROM prod_curated.partload_analytics.ptl_internal_users WHERE customer_uuid IS NOT NULL)
  GROUP BY o.external_id
),

-- Step 1: flag 60-second cancellations
step1 AS (
  SELECT *,
    COALESCE(state = 4 AND DATEDIFF(SECOND, created_at, cancelled_at) <= 60, FALSE) AS is_60s_cancel
  FROM base
),

-- Step 2a: for each surviving order, look at the same customer's previous surviving order
with_prev AS (
  SELECT *,
    LAG(external_id)      OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_external_id,
    LAG(created_at)       OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_created_at,
    LAG(created_date_ist) OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_created_date_ist,
    LAG(pickup_lat)       OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_pickup_lat,
    LAG(pickup_lng)       OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_pickup_lng,
    LAG(drop_lat)         OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_drop_lat,
    LAG(drop_lng)         OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_drop_lng,
    LAG(state)            OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_state,
    LAG(trip_end_time)    OVER (PARTITION BY customer_id ORDER BY created_at, external_id) AS prev_trip_end_time
  FROM step1
  WHERE NOT is_60s_cancel
),

-- Step 2b: apply the duplicate rule (each condition kept as its own column so it can be inspected)
step2 AS (
  SELECT *,
    DATEDIFF(DAY, prev_created_date_ist, created_date_ist)                         AS days_since_prev,
    HAVERSINE(prev_pickup_lat, prev_pickup_lng, pickup_lat, pickup_lng) * 1000      AS pickup_gap_m,
    HAVERSINE(prev_drop_lat,   prev_drop_lng,   drop_lat,   drop_lng)   * 1000      AS drop_gap_m,
    COALESCE(prev_state = 3 AND prev_trip_end_time < created_at, FALSE)             AS prev_already_completed,
    COALESCE(
          prev_external_id IS NOT NULL
      AND DATEDIFF(DAY, prev_created_date_ist, created_date_ist) <= 1
      AND HAVERSINE(prev_pickup_lat, prev_pickup_lng, pickup_lat, pickup_lng) <= 0.1   -- km
      AND HAVERSINE(prev_drop_lat,   prev_drop_lng,   drop_lat,   drop_lng)   <= 0.1   -- km
      AND NOT COALESCE(prev_state = 3 AND prev_trip_end_time < created_at, FALSE),
      FALSE)                                                                          AS is_duplicate
  FROM with_prev
),

orders_flagged AS (
  SELECT s1.*, s2.is_duplicate, s2.prev_external_id, s2.days_since_prev,
         s2.pickup_gap_m, s2.drop_gap_m, s2.prev_state, s2.prev_already_completed
  FROM step1 s1
  LEFT JOIN step2 s2 USING (external_id)          -- 60s cancels have no step2 row
)

-- ===================== MONTHLY SUMMARY =====================
SELECT
  DATE_TRUNC('month', created_date_ist)                                         AS month,
  COUNT(*)                                                                      AS placed_orders,
  SUM(IFF(is_60s_cancel, 1, 0))                                                 AS cancelled_within_60s,
  SUM(IFF(is_duplicate, 1, 0))                                                  AS duplicates,
  SUM(IFF(NOT is_60s_cancel AND NOT is_duplicate, 1, 0))                        AS unique_demand,
  SUM(IFF(state = 3, 1, 0))                                                     AS completed_orders,
  SUM(IFF(state = 3 AND is_duplicate, 1, 0))                                    AS completed_marked_duplicate,
  ROUND(SUM(IFF(state = 3, 1, 0)) * 100.0 / NULLIF(COUNT(*), 0), 2)             AS ff_raw_pct,
  ROUND(SUM(IFF(state = 3, 1, 0)) * 100.0
        / NULLIF(SUM(IFF(NOT is_60s_cancel AND NOT is_duplicate, 1, 0)), 0), 2) AS unique_ff_pct
FROM orders_flagged
GROUP BY 1
ORDER BY 1;

/* ===================== ORDER-LEVEL CHECK =====================
   Replace the MONTHLY SUMMARY above with this to see why each order was kept or dropped.

SELECT
  external_id, customer_id, created_at, created_date_ist, state,
  is_60s_cancel, is_duplicate,
  prev_external_id, days_since_prev, ROUND(pickup_gap_m) AS pickup_gap_m, ROUND(drop_gap_m) AS drop_gap_m,
  prev_state, prev_already_completed
FROM orders_flagged
WHERE is_duplicate                     -- or: WHERE customer_id = '<uuid>'
ORDER BY customer_id, created_at
LIMIT 500;
*/
