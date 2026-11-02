WITH personal_users AS (
    SELECT
        c.mobile AS customer_mobile_number
    FROM prod_curated.oms_public.customers c
    WHERE c.frequency NOT IN (1,2,3,4)
),

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

first_vss AS (
    SELECT
        customer_mobile_number,
        MIN(event_timestamp) AS first_vss_ts
    FROM vss_events
    GROUP BY customer_mobile_number
),

first_placed AS (
    SELECT
        e.customer_mobile_number,
        MIN(e.event_timestamp) AS first_placed_ts
    FROM partload_analytics.ptl_fe_events e
    JOIN personal_users pu
        ON e.customer_mobile_number = pu.customer_mobile_number
    LEFT JOIN partload_analytics.ptl_routes
        ON ptl_routes.route_id =
           TRY_TO_NUMBER(NULLIF(TRY_PARSE_JSON(e.variable_attr):route_id::STRING, ''))
       AND ptl_routes.is_active = 'True'
    WHERE e.event_name = 'ptlbookingdetailspage_booknow_clicked'
      AND e.customer_mobile_number NOT IN (
            SELECT mobile FROM partload_analytics.ptl_internal_users
      )
      [[AND {{pickup_city}}]]
      [[AND {{drop_city}}]]
    GROUP BY e.customer_mobile_number
),

base_users AS (
    -- First-time BUSINESS users whose first order is in selected date range
    SELECT
        customer_mobile_number,
        first_placed_ts,
        DATE_TRUNC({{frequency}}, first_placed_ts) AS period
    FROM first_placed
    WHERE DATE(first_placed_ts) BETWEEN {{start_date}} AND {{end_date}}
),

vss_to_place AS (
    SELECT
        b.period,
        b.customer_mobile_number,
        COUNT(DISTINCT v.event_timestamp) AS impressions_to_place

    FROM base_users b
    JOIN vss_events v
        ON b.customer_mobile_number = v.customer_mobile_number
    JOIN first_vss fv
        ON b.customer_mobile_number = fv.customer_mobile_number
    WHERE v.event_timestamp >= fv.first_vss_ts
      AND v.event_timestamp <= b.first_placed_ts
    GROUP BY b.period, b.customer_mobile_number
),

bucketed AS (
    SELECT
        period,
        customer_mobile_number,
        CASE
             WHEN impressions_to_place BETWEEN 1 AND 3 THEN '1–3 impressions'
            
            WHEN impressions_to_place BETWEEN 4 AND 10 THEN '4–10 impressions'
            
            WHEN impressions_to_place BETWEEN 11 AND 50 THEN '11–50 impressions'
            ELSE '51+ impressions'
        END AS impression_bucket
    FROM vss_to_place
),

period_totals AS (
    SELECT
        period,
        COUNT(DISTINCT customer_mobile_number) AS total_personal_users
    FROM base_users
    GROUP BY period
)

SELECT
    b.period,
    b.impression_bucket,
    COUNT(DISTINCT b.customer_mobile_number) AS first_time_personal_users,
    ROUND(
        COUNT(DISTINCT b.customer_mobile_number) 
        / t.total_personal_users,
        4
    ) AS users_pct
FROM bucketed b
JOIN period_totals t
    ON b.period = t.period
GROUP BY b.period, b.impression_bucket, t.total_personal_users
ORDER BY
    b.period,
    CASE
         WHEN impression_bucket = '1–3 impressions' THEN 1
        WHEN impression_bucket = '4–10 impressions' THEN 2
        WHEN impression_bucket = '11–50 impressions' THEN 3
        ELSE 6
    END;
