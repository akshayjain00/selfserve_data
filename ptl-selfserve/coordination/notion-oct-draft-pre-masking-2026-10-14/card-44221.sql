WITH user_category AS (
    SELECT
        c.mobile AS customer_mobile_number,
        CASE
            WHEN c.frequency IN (1,2,3,4) THEN 'Business'
            ELSE 'Personal'
        END AS user_type
    FROM prod_curated.oms_public.customers c
),

placed_events AS (
    SELECT
        e.customer_mobile_number,
        e.event_timestamp
    FROM partload_analytics.ptl_fe_events e
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
),

ranked_orders AS (
    SELECT
        customer_mobile_number,
        event_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY customer_mobile_number
            ORDER BY event_timestamp
        ) AS order_rank
    FROM placed_events
),

first_second_orders AS (
    SELECT
        customer_mobile_number,
        MAX(CASE WHEN order_rank = 1 THEN event_timestamp END) AS first_order_ts,
        MAX(CASE WHEN order_rank = 2 THEN event_timestamp END) AS second_order_ts
    FROM ranked_orders
    GROUP BY customer_mobile_number
),

base_users AS (
    SELECT
        f.customer_mobile_number,
        uc.user_type,
        DATE_TRUNC({{frequency}}, f.first_order_ts) AS period,
        DATEDIFF('hour', f.first_order_ts, f.second_order_ts) AS hours_to_second_order,
        DATEDIFF('day', f.first_order_ts, f.second_order_ts) AS days_to_second_order
    FROM first_second_orders f
    JOIN user_category uc
        ON f.customer_mobile_number = uc.customer_mobile_number
    WHERE f.second_order_ts IS NOT NULL
      AND DATE(f.first_order_ts) BETWEEN {{start_date}} AND {{end_date}}
)

SELECT
    period,

    /* ---------- BUSINESS ---------- */
    COUNT(DISTINCT CASE
        WHEN user_type = 'Business'
        THEN customer_mobile_number
    END) AS business_users_with_second_order,

    ROUND(AVG(CASE
        WHEN user_type = 'Business'
        THEN hours_to_second_order
    END), 1) AS business_avg_hours_to_second_order,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY CASE
            WHEN user_type = 'Business'
            THEN hours_to_second_order
        END),
        1
    ) AS business_median_hours_to_second_order,

    ROUND(AVG(CASE
        WHEN user_type = 'Business'
        THEN days_to_second_order
    END), 1) AS business_avg_days_to_second_order,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY CASE
            WHEN user_type = 'Business'
            THEN days_to_second_order
        END),
        1
    ) AS business_median_days_to_second_order,

    /* ---------- PERSONAL ---------- */
    COUNT(DISTINCT CASE
        WHEN user_type = 'Personal'
        THEN customer_mobile_number
    END) AS personal_users_with_second_order,

    ROUND(AVG(CASE
        WHEN user_type = 'Personal'
        THEN hours_to_second_order
    END), 1) AS personal_avg_hours_to_second_order,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY CASE
            WHEN user_type = 'Personal'
            THEN hours_to_second_order
        END),
        1
    ) AS personal_median_hours_to_second_order,

    ROUND(AVG(CASE
        WHEN user_type = 'Personal'
        THEN days_to_second_order
    END), 1) AS personal_avg_days_to_second_order,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY CASE
            WHEN user_type = 'Personal'
            THEN days_to_second_order
        END),
        1
    ) AS personal_median_days_to_second_order

FROM base_users
GROUP BY period
ORDER BY period;
