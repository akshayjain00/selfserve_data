WITH exposures AS (
    SELECT e.customer_id AS statsig_customer_id, e.group_name,
           CONVERT_TIMEZONE('UTC','Asia/Kolkata', e.timestamp) AS exposure_ist
    FROM PROD_ELDORIA.RAW.STATSIG_PROD_EXPOSURES e
    WHERE e.experiment_id = {{experiment_id}}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY e.customer_id ORDER BY e.timestamp) = 1
),
variant AS (
    SELECT c.uuid AS customer_uuid,
           x.group_name AS variant,
           x.exposure_ist,
           c.frequency AS cust_frequency,
           c.platform  AS cust_platform
    FROM exposures x
    JOIN PROD_CURATED.OMS_PUBLIC.CUSTOMERS c ON TO_VARCHAR(c.id) = x.statsig_customer_id
),
routes AS (
    SELECT route_id, route_name, pickup_city
    FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_ROUTES
    QUALIFY ROW_NUMBER() OVER (PARTITION BY route_id ORDER BY route_updated_at DESC NULLS LAST) = 1
),
vehicle_assigned AS (
    SELECT order_id, MAX(created_at) AS vehicle_assigned_at
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES
    WHERE is_active = TRUE
    GROUP BY 1
),
cancellations AS (
    SELECT order_id, created_at AS cancel_at, cancellation_source
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDER_CANCELLATION_REASONS
    QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY created_at) = 1
),
first_completed AS (
    SELECT customer_id                                               AS customer_uuid,
           MIN(CONVERT_TIMEZONE('UTC','Asia/Kolkata', created_at))  AS first_completed_ist
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
    WHERE state = 3
    GROUP BY 1
),
base AS (
    SELECT
        o.id AS order_id, v.variant, o.state,
        CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)           AS order_ist,
        CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.pickup_slot_start)    AS slot_start_ist,
        CASE WHEN CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.pickup_slot_start)::date
                  = CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)::date
             THEN 'Same Day'
             WHEN CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.pickup_slot_start)::date
                  = DATEADD('day', 1, CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)::date)
             THEN 'Next Day'
             ELSE 'Later' END                                              AS pickup_slot_day,
        CONVERT_TIMEZONE('UTC','Asia/Kolkata', va.vehicle_assigned_at) AS alloc_ist,
        CONVERT_TIMEZONE('UTC','Asia/Kolkata', cx.cancel_at)           AS cancel_ist,
        CASE WHEN v.cust_frequency IN (1,2,3,4) THEN 'Business'
             ELSE 'Personal' END                                       AS customer_category,
        CASE v.cust_platform WHEN 0 THEN 'Android' WHEN 1 THEN 'iOS'
             ELSE 'Other' END                                          AS device_platform,
        CASE WHEN fc.first_completed_ist IS NULL
                   OR fc.first_completed_ist >= CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)
             THEN 'New' ELSE 'Repeat' END                              AS customer_tenure,
        CASE cx.cancellation_source WHEN 1 THEN 'Customer_App' WHEN 2 THEN 'Partner_App'
                                    WHEN 3 THEN 'Salesforce'   WHEN 4 THEN 'Appsmith' END AS cancellation_sources
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS o
    JOIN variant v
      ON v.customer_uuid = o.customer_id
     AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at) >= v.exposure_ist
    LEFT JOIN routes r ON r.route_id = o.route_id
    LEFT JOIN vehicle_assigned va ON va.order_id = o.id
    LEFT JOIN cancellations  cx   ON cx.order_id = o.id
    LEFT JOIN first_completed fc
           ON fc.customer_uuid = o.customer_id
    WHERE CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at) >= '2026-07-07'
      AND o.customer_id NOT IN (   -- keyed on customer_uuid: mobile is masked since 2026-10-05
            SELECT customer_uuid FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS
            WHERE customer_uuid IS NOT NULL)
      [[AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at) >= {{start_date}}]]
      [[AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at) <  DATEADD('day', 1, {{end_date}}::date)]]
      [[AND r.pickup_city IN ({{pickup_city}})]]
      [[AND r.route_name IN ({{route}})]]
),
enriched AS (
    SELECT *,
        DATEDIFF('minute', order_ist, alloc_ist)   AS alloc_mins,
        DATEDIFF('second', order_ist, cancel_ist)  AS cancel_secs,
        IFF(alloc_ist IS NOT NULL, 1, 0)           AS is_allocated,
        IFF(state = 3, 1, 0)                       AS is_fulfilled,
        IFF(state = 4 AND DATEDIFF('second', order_ist, cancel_ist) <= 60, 1, 0) AS within_60s_cancel,
        IFF(state = 4 AND alloc_ist IS NULL
            AND cancellation_sources IN ({{cancellation_source}}), 1, 0)         AS is_cbdf
    FROM base
    WHERE 1=1
      [[AND pickup_slot_day IN ({{pickup_slot_day}})]]
      [[AND customer_category IN ({{customer_category}})]]
      [[AND customer_tenure IN ({{new_repeat}})]]
      [[AND device_platform IN ({{device_platform}})]]
)

SELECT variant AS "Variant",
       COUNT(DISTINCT order_id) AS "Orders Placed",
       SUM(IFF(is_cbdf = 1 AND cancel_secs <= 60, 1, 0)) AS "CBDF 60s Orders",
       ROUND(100.0 * SUM(IFF(is_cbdf = 1 AND cancel_secs <= 60, 1, 0))
             / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS "CBDF 60s %"
FROM enriched GROUP BY 1 ORDER BY 1;