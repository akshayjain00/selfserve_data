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
-- NTZ-in-UTC once (funnel_events) and then converted to IST with the single house idiom.
-- Do NOT apply CONVERT_TIMEZONE('UTC','Asia/Kolkata', ...) to the raw LTZ column.

WITH first_exposure AS (
    -- Each customer's FIRST Statsig exposure for the chosen experiment -> which arm they're in.
    SELECT exp.customer_id                                        AS statsig_customer_id,
           exp.group_name                                         AS arm_name,
           CONVERT_TIMEZONE('UTC','Asia/Kolkata', exp.timestamp)  AS exposed_at_ist
    FROM PROD_ELDORIA.RAW.STATSIG_PROD_EXPOSURES exp
    WHERE exp.experiment_id = {{experiment_id}}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY exp.customer_id ORDER BY exp.timestamp) = 1
),
customer_profile AS (
    -- OMS customer: id (what FE events carry) <-> uuid (what ORDERS carries) + segment fields.
    SELECT TO_VARCHAR(cust.id) AS customer_id,
           cust.uuid           AS customer_uuid,
           cust.frequency,
           cust.platform
    FROM PROD_CURATED.OMS_PUBLIC.CUSTOMERS cust
),
internal_user_uuids AS (
    SELECT DISTINCT customer_uuid
    FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS
    WHERE customer_uuid IS NOT NULL
),
funnel_events AS (
    -- The three app events of the funnel, with JSON attributes pulled out.
    SELECT fe_event.app_session_id,
           fe_event.customer_id,
           fe_event.event_name,
           CONVERT_TIMEZONE('UTC', fe_event.event_timestamp)::TIMESTAMP_NTZ            AS event_at_utc,  -- LTZ -> NTZ-in-UTC once
           TRY_PARSE_JSON(fe_event.variable_attr):vehicle_id::STRING                  AS vehicle_id,
           TRY_TO_NUMBER(TRY_PARSE_JSON(fe_event.variable_attr):route_id::STRING)     AS route_id,
           TRY_PARSE_JSON(fe_event.variable_attr):order_id::STRING                    AS order_external_id
    FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_FE_EVENTS fe_event
    WHERE fe_event.app_session_id IS NOT NULL
      AND fe_event.event_name IN (
            'vehicleselectionscreen_confirm_clicked',   -- step 1 Confirm
            'ptlbookingdetailspage_quote_viewed',       -- step 2 Quote viewed
            'ptlbookingdetailspage_booknow_clicked')    -- step 3 Book now
),
route_latest AS (
    SELECT route_id, route_name, pickup_city
    FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_ROUTES
    QUALIFY ROW_NUMBER() OVER (PARTITION BY route_id ORDER BY route_updated_at DESC NULLS LAST) = 1
),
customer_first_completed_order AS (
    -- Used for New vs Repeat: had they completed a PTL order before this session's Confirm?
    SELECT customer_id AS customer_uuid,
           MIN(CONVERT_TIMEZONE('UTC','Asia/Kolkata', created_at)) AS first_completed_at_ist
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
    WHERE state = 3
    GROUP BY 1
),
exposed_events AS (
    -- Keep only events that happened AFTER the customer was exposed; tag each with the arm.
    SELECT fev.*,
           fx.arm_name,
           CONVERT_TIMEZONE('UTC','Asia/Kolkata', fev.event_at_utc) AS event_at_ist
    FROM funnel_events fev
    JOIN first_exposure fx
      ON fev.customer_id = fx.statsig_customer_id
     AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', fev.event_at_utc) >= fx.exposed_at_ist
),
session_orders AS (
    -- Steps 4/5: did a Book-now click in the session create an order, and did it complete?
    SELECT xe.app_session_id,
           MAX(1)                           AS has_order_placed,
           MAX(IFF(ord.state = 3, 1, 0))    AS has_order_completed
    FROM exposed_events xe
    JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDERS ord
      ON ord.external_id = xe.order_external_id
    WHERE xe.event_name = 'ptlbookingdetailspage_booknow_clicked'
    GROUP BY 1
),
session_summary AS (
    -- Collapse events to one row per session with the time of each step.
    SELECT app_session_id,
           MIN(arm_name)            AS arm_name,
           COUNT(DISTINCT arm_name) AS arm_count,          -- >1 = session mixes both arms
           MIN(customer_id)         AS customer_id,
           MAX(route_id)            AS route_id,
           MIN(CASE WHEN event_name = 'vehicleselectionscreen_confirm_clicked'
                     AND vehicle_id = '1159'                                 THEN event_at_ist END) AS confirm_at,   -- first PTL Confirm
           MAX(CASE WHEN event_name = 'ptlbookingdetailspage_quote_viewed'    THEN event_at_ist END) AS quote_at,     -- last Quote view
           MAX(CASE WHEN event_name = 'ptlbookingdetailspage_booknow_clicked' THEN event_at_ist END) AS booknow_at    -- last Book now
    FROM exposed_events
    GROUP BY 1
),
session_flags AS (
    -- Add segments + 0/1 flag per funnel step (steps must happen in order).
    SELECT ss.*,
           rl.pickup_city,
           rl.route_name,
           CASE WHEN cp.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END AS customer_category,
           CASE cp.platform WHEN 0 THEN 'Android' WHEN 1 THEN 'iOS' ELSE 'Other' END AS device_platform,
           CASE WHEN fco.first_completed_at_ist IS NULL
                  OR fco.first_completed_at_ist >= ss.confirm_at
                THEN 'New' ELSE 'Repeat' END                                    AS customer_tenure,
           IFF(ss.quote_at >= ss.confirm_at, 1, 0)                              AS reached_quote,
           IFF(ss.quote_at >= ss.confirm_at AND ss.booknow_at >= ss.quote_at, 1, 0) AS reached_booknow,
           IFF(ss.quote_at >= ss.confirm_at AND ss.booknow_at >= ss.quote_at
               AND COALESCE(so.has_order_placed, 0) = 1, 1, 0)                  AS reached_order_placed,
           IFF(ss.quote_at >= ss.confirm_at AND ss.booknow_at >= ss.quote_at
               AND COALESCE(so.has_order_completed, 0) = 1, 1, 0)               AS reached_completed
    FROM session_summary ss
    LEFT JOIN customer_profile cp                ON cp.customer_id    = ss.customer_id
    LEFT JOIN route_latest rl                    ON rl.route_id       = ss.route_id
    LEFT JOIN customer_first_completed_order fco ON fco.customer_uuid = cp.customer_uuid
    LEFT JOIN session_orders so                  ON so.app_session_id = ss.app_session_id
    WHERE ss.confirm_at IS NOT NULL              -- entry condition: a PTL Confirm after exposure
      AND ss.arm_count = 1                       -- drop arm-mixing sessions
      AND (cp.customer_uuid IS NULL OR cp.customer_uuid NOT IN (SELECT customer_uuid FROM internal_user_uuids))
      [[AND ss.confirm_at >= {{start_date}}]]
      [[AND ss.confirm_at <  DATEADD('day', 1, {{end_date}}::date)]]
      [[AND rl.pickup_city IN ({{pickup_city}})]]
      [[AND rl.route_name  IN ({{route}})]]
),
sessions_in_scope AS (
    SELECT * FROM session_flags
    WHERE 1=1
      [[AND customer_category IN ({{customer_category}})]]
      [[AND customer_tenure   IN ({{new_repeat}})]]
      [[AND device_platform   IN ({{device_platform}})]]
)
