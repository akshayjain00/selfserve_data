WITH personal_users AS (
    SELECT
        c.mobile AS customer_mobile_number
    FROM prod_curated.oms_public.customers c
    WHERE c.frequency NOT IN (1,2,3,4)
),

/* ---------------- VSS EVENTS ---------------- */
vss_events AS (
    SELECT
        e.customer_mobile_number,
        e.event_timestamp
    FROM partload_analytics.ptl_fe_events e
    JOIN personal_users pu
        ON e.customer_mobile_number = pu.customer_mobile_number
    LEFT JOIN partload_analytics.ptl_routes
        ON ptl_routes.route_id =
           TRY_TO_NUMBER(NULLIF(TRY_PARSE_JSON(e.variable_attr):route_id::STRING, ''))
       AND ptl_routes.is_active = 'True'
    WHERE e.event_name = 'vehicleselectionscreen_vehicles_loaded'
      AND e.customer_mobile_number NOT IN (
            SELECT mobile FROM partload_analytics.ptl_internal_users
      )
      [[AND {{pickup_city}}]]
      [[AND {{drop_city}}]]
),

/* ---------------- FIRST VSS ---------------- */
first_vss AS (
    SELECT
        customer_mobile_number,
        MIN(event_timestamp) AS first_vss_ts
    FROM vss_events
    GROUP BY customer_mobile_number
),

/* ---------------- FIRST COMPLETED ORDER ---------------- */
first_completed AS (
    SELECT
        e.customer_mobile_number,
        MIN(e.event_timestamp) AS first_completed_ts
    FROM partload_analytics.ptl_fe_events e
    JOIN personal_users pu
        ON e.customer_mobile_number = pu.customer_mobile_number
    LEFT JOIN partload_application.orders o
        ON PARSE_JSON(e.variable_attr):order_id::STRING = o.external_id
    LEFT JOIN partload_analytics.ptl_routes
        ON ptl_routes.route_id =
           TRY_TO_NUMBER(NULLIF(TRY_PARSE_JSON(e.variable_attr):route_id::STRING, ''))
       AND ptl_routes.is_active = 'True'
    WHERE e.event_name = 'ptlbookingdetailspage_booknow_clicked'
      AND o.state = '3'   -- ✅ completed order
      AND e.customer_mobile_number NOT IN (
            SELECT mobile FROM partload_analytics.ptl_internal_users
      )
      [[AND {{pickup_city}}]]
      [[AND {{drop_city}}]]
    GROUP BY e.customer_mobile_number
),

/* ---------------- BASE USERS (FIRST COMPLETION IN RANGE) ---------------- */
base_users AS (
    SELECT
        fc.customer_mobile_number,
        fc.first_completed_ts,
        DATE_TRUNC({{frequency}}, fc.first_completed_ts) AS period
    FROM first_completed fc
    WHERE DATE(fc.first_completed_ts) BETWEEN {{start_date}} AND {{end_date}}
),

/* ---------------- TIME TO COMPLETE ---------------- */
time_to_complete AS (
    SELECT
        b.period,
        b.customer_mobile_number,
        DATEDIFF('minute', fv.first_vss_ts, b.first_completed_ts) AS minutes_to_complete
    FROM base_users b
    JOIN first_vss fv
        ON b.customer_mobile_number = fv.customer_mobile_number
    WHERE fv.first_vss_ts <= b.first_completed_ts
),

/* ---------------- EXCLUSIVE BUCKETS ---------------- */
bucketed AS (
    SELECT
        period,
        customer_mobile_number,
        CASE
            WHEN minutes_to_complete < 10
                THEN 'Within 10 minutes'

            WHEN minutes_to_complete >= 10
             AND minutes_to_complete < 30
                THEN '10–30 minutes'

            WHEN minutes_to_complete >= 30
             AND minutes_to_complete < 1440
                THEN 'Within 24 hours'

            WHEN minutes_to_complete >= 1440
             AND minutes_to_complete <= 10080
                THEN 'Within 1 week'

            ELSE 'More than 1 week'
        END AS time_bucket
    FROM time_to_complete
),

/* ---------------- PERIOD TOTALS ---------------- */
period_totals AS (
    SELECT
        period,
        COUNT(DISTINCT customer_mobile_number) AS total_first_time_personal_users
    FROM base_users
    GROUP BY period
)

/* ---------------- FINAL RESULT ---------------- */
SELECT
    b.period,
    b.time_bucket,
    COUNT(DISTINCT b.customer_mobile_number) AS first_time_personal_users,
    ROUND(
        COUNT(DISTINCT b.customer_mobile_number) 
        / t.total_first_time_personal_users,
        4
    ) AS users_pct
FROM bucketed b
JOIN period_totals t
    ON b.period = t.period
GROUP BY
    b.period,
    b.time_bucket,
    t.total_first_time_personal_users
ORDER BY
    b.period,
    CASE
        WHEN b.time_bucket = 'Within 10 minutes' THEN 1
        WHEN b.time_bucket = '10–30 minutes' THEN 2
        WHEN b.time_bucket = 'Within 24 hours' THEN 3
        WHEN b.time_bucket = 'Within 1 week' THEN 4
        ELSE 5
    END;
