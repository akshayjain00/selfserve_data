-- Card: "PTL Booking Funnel - Confirm > Quote > Book Now"
-- Dashboard 6361 (A/B: Experiment observability) | Database 73 (SNOWFLAKE_NEW_INI)
-- Unit: app_session_id (matches Statsig session unit)
-- Cohort: Statsig exposure, first exposure per customer, events on/after exposure
--
-- TIMESTAMP CONTRACT (read before editing):
--   Every timestamp below is TIMESTAMP_NTZ holding UTC wall time, and is converted to IST
--   with exactly one idiom: CONVERT_TIMEZONE('UTC','Asia/Kolkata', <ts>).
--   PTL_FE_EVENTS.EVENT_TIMESTAMP is the sole exception at source -- it is TIMESTAMP_LTZ
--   (an absolute instant, rendering as IST). It is normalised to NTZ-in-UTC exactly once,
--   in the ptl_events CTE, so that no downstream expression needs a different idiom.
--   Do NOT apply CONVERT_TIMEZONE('UTC','Asia/Kolkata', ...) directly to the raw LTZ
--   column: that double-shifts it by +5:30 and inflates step 1 by ~80%.

WITH ptl_events AS (
    -- Sole timezone normalisation in this card: LTZ (absolute instant) -> NTZ holding UTC.
    -- After this CTE, every timestamp in the card shares one contract.
    SELECT fe.app_session_id,
           fe.customer_id,
           fe.event_name,
           CONVERT_TIMEZONE('UTC', fe.event_timestamp)::TIMESTAMP_NTZ AS event_ts_utc,
           TRY_PARSE_JSON(fe.variable_attr):vehicle_id::STRING          AS vehicle_id,
           TRY_TO_NUMBER(TRY_PARSE_JSON(fe.variable_attr):route_id::STRING) AS route_id,
           REGEXP_REPLACE(fe.customer_mobile_number::varchar,'[^0-9]','')   AS mobile
    FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_FE_EVENTS fe
    WHERE fe.app_session_id IS NOT NULL
      AND fe.event_name IN (
            'vehicleselectionscreen_confirm_clicked',
            'ptlbookingdetailspage_quote_viewed',
            'ptlbookingdetailspage_booknow_clicked')
      AND fe.customer_mobile_number NOT IN (
            SELECT DISTINCT mobile FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)
),
exposures AS (
    SELECT e.customer_id AS statsig_customer_id, e.group_name,
           CONVERT_TIMEZONE('UTC','Asia/Kolkata', e.timestamp) AS exposure_ist
    FROM PROD_ELDORIA.RAW.STATSIG_PROD_EXPOSURES e
    WHERE e.experiment_id = {{experiment_id}}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY e.customer_id ORDER BY e.timestamp) = 1
),
routes AS (
    SELECT route_id, route_name, pickup_city
    FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_ROUTES
    QUALIFY ROW_NUMBER() OVER (PARTITION BY route_id ORDER BY route_updated_at DESC NULLS LAST) = 1
),
cust AS (
    SELECT REGEXP_REPLACE(mobile::varchar,'[^0-9]','') AS mobile, frequency, platform
    FROM PROD_CURATED.OMS_PUBLIC.CUSTOMERS
    QUALIFY ROW_NUMBER() OVER (PARTITION BY REGEXP_REPLACE(mobile::varchar,'[^0-9]','') ORDER BY id DESC) = 1
),
first_completed AS (
    SELECT REGEXP_REPLACE(customer_mobile::varchar,'[^0-9]','') AS mobile,
           MIN(CONVERT_TIMEZONE('UTC','Asia/Kolkata', created_at)) AS first_completed_ist
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
    WHERE state = 3
    GROUP BY 1
),
ev AS (
    SELECT pe.app_session_id,
           x.group_name AS variant,
           pe.event_name,
           CONVERT_TIMEZONE('UTC','Asia/Kolkata', pe.event_ts_utc) AS ts_ist,
           pe.vehicle_id,
           pe.route_id,
           pe.mobile
    FROM ptl_events pe
    JOIN exposures x
      ON pe.customer_id = x.statsig_customer_id
     AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', pe.event_ts_utc) >= x.exposure_ist
),
sess AS (
    SELECT app_session_id,
           ANY_VALUE(variant) AS variant,
           ANY_VALUE(mobile)  AS mobile,
           MAX(route_id)      AS route_id,
           MIN(CASE WHEN event_name='vehicleselectionscreen_confirm_clicked'
                     AND vehicle_id='1159' THEN ts_ist END) AS t1,
           MAX(CASE WHEN event_name='ptlbookingdetailspage_quote_viewed'    THEN ts_ist END) AS t2,
           MAX(CASE WHEN event_name='ptlbookingdetailspage_booknow_clicked' THEN ts_ist END) AS t3
    FROM ev
    GROUP BY 1
),
filtered AS (
    SELECT s.*,
           r.pickup_city, r.route_name,
           CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END AS customer_category,
           CASE c.platform WHEN 0 THEN 'Android' WHEN 1 THEN 'iOS' ELSE 'Other' END AS device_platform,
           CASE WHEN fc.first_completed_ist IS NULL
                     OR fc.first_completed_ist >= s.t1
                THEN 'New' ELSE 'Repeat' END AS customer_tenure
    FROM sess s
    LEFT JOIN routes r           ON r.route_id = s.route_id
    LEFT JOIN cust c             ON c.mobile   = s.mobile
    LEFT JOIN first_completed fc ON fc.mobile  = s.mobile
    WHERE s.t1 IS NOT NULL
      [[AND s.t1 >= {{start_date}}]]
      [[AND s.t1 <  DATEADD('day', 1, {{end_date}}::date)]]
      [[AND r.pickup_city IN ({{pickup_city}})]]
      [[AND r.route_name  IN ({{route}})]]
),
scoped AS (
    SELECT * FROM filtered
    WHERE 1=1
      [[AND customer_category IN ({{customer_category}})]]
      [[AND customer_tenure   IN ({{new_repeat}})]]
      [[AND device_platform   IN ({{device_platform}})]]
),
steps AS (
    SELECT 1 AS step_no, '1. PTL Confirm' AS step, variant,
           COUNT(DISTINCT app_session_id) AS sessions
    FROM scoped GROUP BY 1,2,3
    UNION ALL
    SELECT 2, '2. Quote Viewed', variant,
           COUNT(DISTINCT CASE WHEN t2 >= t1 THEN app_session_id END)
    FROM scoped GROUP BY 1,2,3
    UNION ALL
    SELECT 3, '3. Book Now', variant,
           COUNT(DISTINCT CASE WHEN t2 >= t1 AND t3 >= t2 THEN app_session_id END)
    FROM scoped GROUP BY 1,2,3
)
SELECT step     AS "Step",
       variant  AS "Variant",
       sessions AS "Sessions",
       ROUND(100.0*sessions
             / NULLIF(FIRST_VALUE(sessions) OVER (PARTITION BY variant ORDER BY step_no),0),2) AS "% of PTL Confirm",
       ROUND(100.0*sessions
             / NULLIF(LAG(sessions) OVER (PARTITION BY variant ORDER BY step_no),0),2)         AS "% of Previous Step"
FROM steps
ORDER BY step_no, variant;
