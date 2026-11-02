WITH user_category AS (
    SELECT
        c.mobile AS customer_mobile_number,
        CASE 
            WHEN c.frequency IN (1,2,3,4) THEN 'Business'
            ELSE 'Personal'
        END AS category
    FROM prod_curated.oms_public.customers c
),

first_vss AS (
    SELECT
        e.customer_mobile_number,
        DATE_TRUNC('month', MIN(e.event_timestamp)) AS vss_month,
        MIN(e.event_timestamp) AS first_vss_ts,
        ptl_routes.pickup_city,
        ptl_routes.drop_city
    FROM partload_analytics.ptl_fe_events e
    LEFT JOIN partload_analytics.ptl_routes 
        ON ptl_routes.route_id = TRY_TO_NUMBER(NULLIF(TRY_PARSE_JSON(e.variable_attr):route_id::STRING, ''))
       AND ptl_routes.is_active = 'True'
    WHERE e.event_name = 'vehicleselectionscreen_vehicles_loaded'
      AND DATE(e.event_timestamp) BETWEEN {{start_date}} AND {{end_date}}
      AND e.customer_mobile_number NOT IN (
            SELECT mobile FROM partload_analytics.ptl_internal_users
      )
      [[AND {{pickup_city}}]]
      [[AND {{drop_city}}]]
    GROUP BY e.customer_mobile_number, ptl_routes.pickup_city, ptl_routes.drop_city
),

first_placed AS (
    SELECT
        e.customer_mobile_number,
        MIN(e.event_timestamp) AS first_placed_ts,
        ptl_routes.pickup_city,
        ptl_routes.drop_city
    FROM partload_analytics.ptl_fe_events e
    LEFT JOIN partload_application.orders o
        ON PARSE_JSON(e.variable_attr):order_id::STRING = o.external_id
    LEFT JOIN partload_analytics.ptl_routes 
        ON ptl_routes.route_id = TRY_TO_NUMBER(NULLIF(TRY_PARSE_JSON(e.variable_attr):route_id::STRING, ''))
       AND ptl_routes.is_active = 'True'
    WHERE e.event_name = 'ptlbookingdetailspage_booknow_clicked'
      AND e.customer_mobile_number NOT IN (
            SELECT mobile FROM partload_analytics.ptl_internal_users
      )
      [[AND {{pickup_city}}]]
      [[AND {{drop_city}}]]
    GROUP BY e.customer_mobile_number, ptl_routes.pickup_city, ptl_routes.drop_city
),

placement_grouped AS (
    SELECT
        v.customer_mobile_number,
        v.vss_month,
        uc.category,
        CASE
            WHEN p.first_placed_ts IS NOT NULL 
                 AND DATEDIFF('day', v.first_vss_ts, p.first_placed_ts) <= 7 THEN 'within_7_days'
            WHEN p.first_placed_ts IS NOT NULL 
                 AND DATEDIFF('day', v.first_vss_ts, p.first_placed_ts) <= 30 THEN 'within_8_to_30_days'
            ELSE 'after_30_days_or_not_placed'
        END AS placement_group
    FROM first_vss v
    LEFT JOIN first_placed p
        ON v.customer_mobile_number = p.customer_mobile_number
       AND v.pickup_city = p.pickup_city
       AND v.drop_city = p.drop_city
    LEFT JOIN user_category uc
        ON v.customer_mobile_number = uc.customer_mobile_number
)

SELECT
    vss_month AS period,

    /* ---------- BUSINESS ---------- */
    COUNT(DISTINCT CASE WHEN category = 'Business' AND placement_group = 'within_7_days' THEN customer_mobile_number END) AS business_within_7_days,
    COUNT(DISTINCT CASE WHEN category = 'Business' AND placement_group = 'within_8_to_30_days' THEN customer_mobile_number END) AS business_within_8_to_30_days,
    COUNT(DISTINCT CASE WHEN category = 'Business' THEN customer_mobile_number END) AS business_total_users,
    ROUND(
        COUNT(DISTINCT CASE WHEN category = 'Business' AND placement_group = 'within_7_days' THEN customer_mobile_number END) * 100.0
        / NULLIF(COUNT(DISTINCT CASE WHEN category = 'Business' THEN customer_mobile_number END), 0), 4
    ) AS business_pct_within_7_days,
    ROUND(
        COUNT(DISTINCT CASE WHEN category = 'Business' AND placement_group = 'within_8_to_30_days' THEN customer_mobile_number END) * 100.0
        / NULLIF(COUNT(DISTINCT CASE WHEN category = 'Business' THEN customer_mobile_number END), 0), 4
    ) AS business_pct_within_8_to_30_days,

    /* ---------- PERSONAL ---------- */
    COUNT(DISTINCT CASE WHEN category = 'Personal' AND placement_group = 'within_7_days' THEN customer_mobile_number END) AS personal_within_7_days,
    COUNT(DISTINCT CASE WHEN category = 'Personal' AND placement_group = 'within_8_to_30_days' THEN customer_mobile_number END) AS personal_within_8_to_30_days,
    COUNT(DISTINCT CASE WHEN category = 'Personal' THEN customer_mobile_number END) AS personal_total_users,
    ROUND(
        COUNT(DISTINCT CASE WHEN category = 'Personal' AND placement_group = 'within_7_days' THEN customer_mobile_number END) * 100.0
        / NULLIF(COUNT(DISTINCT CASE WHEN category = 'Personal' THEN customer_mobile_number END), 0), 4
    ) AS personal_pct_within_7_days,
    ROUND(
        COUNT(DISTINCT CASE WHEN category = 'Personal' AND placement_group = 'within_8_to_30_days' THEN customer_mobile_number END) * 100.0
        / NULLIF(COUNT(DISTINCT CASE WHEN category = 'Personal' THEN customer_mobile_number END), 0), 4
    ) AS personal_pct_within_8_to_30_days

FROM placement_grouped
GROUP BY vss_month
ORDER BY vss_month;
