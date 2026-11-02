-- Card 63201 | Session Conversion - Lift & Significance (customer-clustered) | Dashboard 6361
-- READABLE REWRITE: same logic as session_cards.py BASE + SIGNIFICANCE, only aliases/CTE
-- names changed and comments added. Output columns are identical.
--
-- The question it answers: "For each funnel step, did the test arm convert more PTL-Confirm
-- sessions than control, and is that gap bigger than noise?"
-- Unit: app_session_id (a session), but the significance test groups sessions by customer,
-- because Statsig randomises customers, not sessions.

-- =========================================================================================
-- PART A — build one row per qualifying session (shared by every card on the tab)
-- =========================================================================================
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
),

-- =========================================================================================
-- PART B — significance test, clustered by customer (delta method)
-- =========================================================================================
customer_totals AS (
    -- One row per customer: how many sessions they had, and how many reached each step.
    SELECT arm_name, customer_id,
           COUNT(*)                  AS confirm_sessions,
           SUM(reached_quote)        AS quote_sessions,
           SUM(reached_booknow)      AS booknow_sessions,
           SUM(reached_order_placed) AS placed_sessions,
           SUM(reached_completed)    AS completed_sessions
    FROM sessions_in_scope GROUP BY 1,2
),
customer_metric_rows AS (
    -- Stack the 5 metrics: numerator / denominator per customer per metric.
              SELECT 1 AS metric_order, 'Confirm → Quote Viewed' AS metric, arm_name, confirm_sessions AS denominator, quote_sessions     AS numerator FROM customer_totals
    UNION ALL SELECT 2,                 'Quote Viewed → Book Now',          arm_name, quote_sessions,                   booknow_sessions                FROM customer_totals WHERE quote_sessions > 0
    UNION ALL SELECT 3,                 'Confirm → Book Now',               arm_name, confirm_sessions,                 booknow_sessions                FROM customer_totals
    UNION ALL SELECT 4,                 'Confirm → Order Placed',           arm_name, confirm_sessions,                 placed_sessions                 FROM customer_totals
    UNION ALL SELECT 5,                 'Confirm → Completed',              arm_name, confirm_sessions,                 completed_sessions              FROM customer_totals
),
arm_stats AS (
    -- Per metric x arm: totals, per-customer means, variances and covariance.
    SELECT metric_order, metric, arm_name,
           IFF(LOWER(arm_name) IN ('control','fail'), 'C', 'T') AS arm_role,
           COUNT(*)                            AS customers,
           SUM(numerator)                      AS total_num,
           SUM(denominator)                    AS total_den,
           AVG(numerator)                      AS mean_num,
           AVG(denominator)                    AS mean_den,
           VAR_POP(numerator)                  AS var_num,
           VAR_POP(denominator)                AS var_den,
           COVAR_POP(numerator, denominator)   AS cov_num_den
    FROM customer_metric_rows GROUP BY 1,2,3
),
arm_rate AS (
    -- Conversion rate = total_num / total_den, and its variance via the delta method.
    SELECT *,
           total_num / NULLIF(total_den, 0) AS conv_rate,
           ( var_num / POWER(mean_den, 2)
             - 2 * mean_num * cov_num_den / POWER(mean_den, 3)
             + POWER(mean_num, 2) * var_den / POWER(mean_den, 4) ) / customers AS conv_rate_var
    FROM arm_stats
),
control_vs_test AS (
    -- Pair each test arm with control for the same metric.
    SELECT ctl.metric_order, ctl.metric,
           ctl.arm_name   AS control_arm,  tst.arm_name   AS test_arm,
           ctl.customers  AS control_customers, tst.customers AS test_customers,
           ctl.total_den  AS control_sessions,  tst.total_den AS test_sessions,
           ctl.conv_rate  AS control_rate,      tst.conv_rate AS test_rate,
           SQRT(ctl.conv_rate_var + tst.conv_rate_var)                                   AS std_error,
           ABS(tst.conv_rate - ctl.conv_rate) / NULLIF(SQRT(ctl.conv_rate_var + tst.conv_rate_var), 0)
             / SQRT(2)                                                                   AS z_over_root2   -- |z|/√2, input to erfc
    FROM arm_rate ctl
    JOIN arm_rate tst
      ON tst.metric = ctl.metric AND ctl.arm_role = 'C' AND tst.arm_role = 'T'
),
pvalue_prep AS (
    SELECT *, 1 / (1 + 0.3275911 * z_over_root2) AS erfc_t FROM control_vs_test
)
SELECT metric                                              AS "Metric",
       control_arm || ' vs ' || test_arm                    AS "Arms",
       control_customers                                   AS "Control Customers",
       test_customers                                      AS "Test Customers",
       control_sessions                                    AS "Control Sessions",
       test_sessions                                       AS "Test Sessions",
       ROUND(100 * control_rate, 2)                        AS "Control %",
       ROUND(100 * test_rate, 2)                           AS "Test %",
       ROUND(100 * (test_rate - control_rate), 2)          AS "Δ (pp)",
       ROUND(100 * (test_rate / NULLIF(control_rate, 0) - 1), 2) AS "Lift %",
       ROUND(100 * (test_rate - control_rate - 1.96 * std_error), 2) AS "95% CI Low (pp)",
       ROUND(100 * (test_rate - control_rate + 1.96 * std_error), 2) AS "95% CI High (pp)",
       -- two-sided p = erfc(|z|/√2), Abramowitz–Stegun 7.1.26 polynomial
       ROUND(erfc_t*(0.254829592+erfc_t*(-0.284496736+erfc_t*(1.421413741+erfc_t*(-1.453152027+erfc_t*1.061405429))))
             * EXP(-z_over_root2*z_over_root2), 4)         AS "p-value",
       IFF(erfc_t*(0.254829592+erfc_t*(-0.284496736+erfc_t*(1.421413741+erfc_t*(-1.453152027+erfc_t*1.061405429))))
             * EXP(-z_over_root2*z_over_root2) < 0.05, 'Yes', 'No') AS "Significant (95%)"
FROM pvalue_prep
ORDER BY metric_order, test_arm;
