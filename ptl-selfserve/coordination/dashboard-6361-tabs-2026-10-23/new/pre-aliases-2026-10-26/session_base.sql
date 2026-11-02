-- Dashboard 6361 (A/B: Experiment observability) | Database 73
-- SESSION CONVERSION BASE (shared by every card on the "Session Conversion" tab)
--
-- Unit of analysis: app_session_id. Entry = a PTL Confirm (vehicle 1159) on/after the
-- customer's first Statsig exposure. Steps must happen in order within the session:
--   1 Confirm -> 2 Quote viewed -> 3 Book now -> 4 Order placed -> 5 Completed (state 3)
-- Steps 4/5 link the Book-now event's variable_attr:order_id to ORDERS.external_id
-- (same join as dashboard 6174 card 49611; 99.8% of Book-now sessions match an order).
--
-- RANDOMISATION: Statsig assigns per CUSTOMER, not per session. Session-level rates are
-- fine to read, but any significance test must cluster sessions by customer (see the
-- "Lift & Significance" card, delta method).
--
-- PII MASKING (live 2026-10-05): never join on mobile. PTL_FE_EVENTS.customer_id = OMS
-- customers.id (text); ORDERS.customer_id = customers.uuid; internal users are excluded by
-- PTL_INTERNAL_USERS.customer_uuid.
--
-- TIMESTAMP CONTRACT: PTL_FE_EVENTS.EVENT_TIMESTAMP is TIMESTAMP_LTZ. It is normalised to
-- NTZ-in-UTC once (ptl_events) and then converted to IST with the single house idiom.
-- Do NOT apply CONVERT_TIMEZONE('UTC','Asia/Kolkata', ...) to the raw LTZ column.

WITH exposures AS (
    SELECT e.customer_id AS statsig_customer_id, e.group_name,
           CONVERT_TIMEZONE('UTC','Asia/Kolkata', e.timestamp) AS exposure_ist
    FROM PROD_ELDORIA.RAW.STATSIG_PROD_EXPOSURES e
    WHERE e.experiment_id = {{experiment_id}}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY e.customer_id ORDER BY e.timestamp) = 1
),
cust AS (
    SELECT TO_VARCHAR(c.id) AS customer_id, c.uuid AS customer_uuid, c.frequency, c.platform
    FROM PROD_CURATED.OMS_PUBLIC.CUSTOMERS c
),
internal_users AS (
    SELECT DISTINCT customer_uuid
    FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS
    WHERE customer_uuid IS NOT NULL
),
ptl_events AS (
    SELECT fe.app_session_id,
           fe.customer_id,
           fe.event_name,
           CONVERT_TIMEZONE('UTC', fe.event_timestamp)::TIMESTAMP_NTZ          AS event_ts_utc,
           TRY_PARSE_JSON(fe.variable_attr):vehicle_id::STRING                AS vehicle_id,
           TRY_TO_NUMBER(TRY_PARSE_JSON(fe.variable_attr):route_id::STRING)   AS route_id,
           TRY_PARSE_JSON(fe.variable_attr):order_id::STRING                  AS order_external_id
    FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_FE_EVENTS fe
    WHERE fe.app_session_id IS NOT NULL
      AND fe.event_name IN (
            'vehicleselectionscreen_confirm_clicked',
            'ptlbookingdetailspage_quote_viewed',
            'ptlbookingdetailspage_booknow_clicked')
),
routes AS (
    SELECT route_id, route_name, pickup_city
    FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_ROUTES
    QUALIFY ROW_NUMBER() OVER (PARTITION BY route_id ORDER BY route_updated_at DESC NULLS LAST) = 1
),
first_completed AS (
    SELECT customer_id AS customer_uuid,
           MIN(CONVERT_TIMEZONE('UTC','Asia/Kolkata', created_at)) AS first_completed_ist
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
    WHERE state = 3
    GROUP BY 1
),
ev AS (
    SELECT pe.*,
           x.group_name AS variant,
           CONVERT_TIMEZONE('UTC','Asia/Kolkata', pe.event_ts_utc) AS ts_ist
    FROM ptl_events pe
    JOIN exposures x
      ON pe.customer_id = x.statsig_customer_id
     AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', pe.event_ts_utc) >= x.exposure_ist
),
booked_orders AS (
    -- every order created from a Book-now click in the session
    SELECT ev.app_session_id,
           MAX(1)                         AS order_placed,
           MAX(IFF(o.state = 3, 1, 0))    AS order_completed
    FROM ev
    JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDERS o
      ON o.external_id = ev.order_external_id
    WHERE ev.event_name = 'ptlbookingdetailspage_booknow_clicked'
    GROUP BY 1
),
sess AS (
    SELECT app_session_id,
           MIN(variant)           AS variant,
           COUNT(DISTINCT variant) AS n_variants,  -- >1 = events from customers in both arms
           MIN(customer_id)       AS customer_id,
           MAX(route_id)          AS route_id,
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
                THEN 'New' ELSE 'Repeat' END AS customer_tenure,
           IFF(s.t2 >= s.t1, 1, 0)                                         AS is_quote,
           IFF(s.t2 >= s.t1 AND s.t3 >= s.t2, 1, 0)                        AS is_booknow,
           IFF(s.t2 >= s.t1 AND s.t3 >= s.t2
               AND COALESCE(bo.order_placed, 0) = 1, 1, 0)                 AS is_placed,
           IFF(s.t2 >= s.t1 AND s.t3 >= s.t2
               AND COALESCE(bo.order_completed, 0) = 1, 1, 0)              AS is_completed
    FROM sess s
    LEFT JOIN cust c             ON c.customer_id = s.customer_id
    LEFT JOIN routes r           ON r.route_id    = s.route_id
    LEFT JOIN first_completed fc ON fc.customer_uuid = c.customer_uuid
    LEFT JOIN booked_orders bo   ON bo.app_session_id = s.app_session_id
    WHERE s.t1 IS NOT NULL
      AND s.n_variants = 1          -- drop sessions that mix arms (shared device / re-login)
      AND (c.customer_uuid IS NULL OR c.customer_uuid NOT IN (SELECT customer_uuid FROM internal_users))
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
)
