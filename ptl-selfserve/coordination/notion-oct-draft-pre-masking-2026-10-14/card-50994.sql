WITH 

-- STEP 1: Identify users who saw PTL on VSS BEFORE the selected period
-- This is used to exclude them from the "new" user definition
-- A user is only "new" if they have never seen PTL on VSS before start_date
prior_ptl_vss_users AS (
    SELECT DISTINCT e2.customer_mobile_number
    FROM prod_curated.partload_analytics.ptl_fe_events e2
    CROSS JOIN LATERAL FLATTEN(
        INPUT => TRY_PARSE_JSON(
                     TRY_PARSE_JSON(e2.variable_attr):vehicle_ids_seq
                 )
    ) f2
    WHERE e2.event_name = 'vehicleselectionscreen_vehicles_loaded'
      AND f2.value::NUMBER IN (-1, 1159)          -- PTL vehicle type IDs
      AND e2.customer_mobile_number IS NOT NULL
      AND DATE(e2.event_timestamp + INTERVAL '330 minutes') < {{start_date}}
),

-- STEP 2: Find first-time PTL VSS users within the selected period
-- Conditions for a user to qualify:
--   a) Saw PTL card on VSS (vehicle_ids_seq contains -1 or 1159)
--   b) Is a business user (c.frequency IN 1,2,3,4)
--   c) Is not an internal Porter user
--   d) Has NEVER seen PTL on VSS before start_date (excluded via prior_ptl_vss_users)
--   e) Their first VSS falls within start_date and end_date
new_vss_users AS (
    SELECT
        e.customer_mobile_number,
        MIN(e.event_timestamp + INTERVAL '330 minutes') AS first_vss_ts,
        DATE_TRUNC({{granularity}}, MIN(e.event_timestamp + INTERVAL '330 minutes'))::DATE AS period_start
    FROM prod_curated.partload_analytics.ptl_fe_events e
    CROSS JOIN LATERAL FLATTEN(
        INPUT => TRY_PARSE_JSON(
                     TRY_PARSE_JSON(e.variable_attr):vehicle_ids_seq
                 )
    ) f
    LEFT JOIN prod_curated.partload_analytics.ptl_routes
        ON ptl_routes.route_id = TRY_TO_NUMBER(NULLIF(TRY_PARSE_JSON(e.variable_attr):route_id::STRING, ''))
       AND ptl_routes.is_active = 'True'
    LEFT JOIN prod_curated.oms_public.customers c
        ON c.mobile = e.customer_mobile_number
    WHERE e.event_name = 'vehicleselectionscreen_vehicles_loaded'
      AND f.value::NUMBER IN (-1, 1159)
      AND e.customer_mobile_number IS NOT NULL
      AND e.customer_mobile_number NOT IN (
          SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users
      )
      AND c.frequency IN (1, 2, 3, 4)             -- business users only
      AND DATE(e.event_timestamp + INTERVAL '330 minutes') BETWEEN {{start_date}} AND {{end_date}}
      [[AND {{pickup_city}}]]
      [[AND {{drop_city}}]]
      -- Exclude anyone who saw PTL on VSS before the period (from Step 1)
      AND e.customer_mobile_number NOT IN (
          SELECT customer_mobile_number FROM prior_ptl_vss_users
      )
    GROUP BY e.customer_mobile_number
),

-- STEP 3: Find the first COMPLETED order (state=3) for every user, across all time
-- Not date-filtered — we want to capture completions that happen after VSS
-- even if they fall slightly outside the period window
-- Internal users are excluded again as a safety filter
first_completed_order AS (
    SELECT
        o.customer_mobile,
        MIN(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at))) AS first_completed_ts
    FROM prod_curated.partload_application.orders o
    LEFT JOIN prod_curated.partload_analytics.ptl_internal_users iu
        ON iu.mobile = o.customer_mobile
    WHERE o.state = 3
      AND iu.mobile IS NULL
    GROUP BY o.customer_mobile
),

-- STEP 4: Join new VSS users with their first completed order
-- Check if the completed order happened:
--   a) AFTER their first VSS (not before)
--   b) Within 7 days of their first VSS
-- This gives us the activation flag per user
activation_base AS (
    SELECT
        v.period_start,
        v.customer_mobile_number,
        v.first_vss_ts,
        fco.first_completed_ts,
        CASE
            WHEN fco.first_completed_ts IS NOT NULL
             AND fco.first_completed_ts >= v.first_vss_ts
             AND DATEDIFF('day', v.first_vss_ts, fco.first_completed_ts) <= {{Days}}
            THEN 1 ELSE 0
        END AS activated_within_days
    FROM new_vss_users v
    LEFT JOIN first_completed_order fco
        ON fco.customer_mobile = v.customer_mobile_number
)

-- STEP 5: Aggregate by period
-- new_business_vss_users  = denominator (new business users who saw PTL card)
-- activated_within_7_days = numerator (subset who completed first order within 7 days)
-- activation_rate_pct     = numerator / denominator * 100
SELECT
    period_start,
    COUNT(DISTINCT customer_mobile_number)                                      AS new_business_vss_users,
    COUNT(DISTINCT CASE WHEN activated_within_days = 1
                        THEN customer_mobile_number END)                        AS activated_within_days,
    ROUND(
        COUNT(DISTINCT CASE WHEN activated_within_days = 1
                            THEN customer_mobile_number END) * 100.0
        / NULLIF(COUNT(DISTINCT customer_mobile_number), 0), 2
    )                                                                           AS activation_rate_pct
FROM activation_base
GROUP BY 1
ORDER BY 1;