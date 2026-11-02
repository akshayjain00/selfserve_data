WITH user_category AS (
    SELECT
        c.mobile AS customer_mobile_number,
        CASE
            WHEN c.frequency IN (1,2,3,4) THEN 'Business'
            ELSE 'Personal'
        END AS user_type
    FROM prod_curated.oms_public.customers c
),

/* ---------- FIRST QUOTE ---------- */
first_quote AS (
    SELECT
        e.customer_mobile_number,
        MIN(e.event_timestamp) AS first_quote_ts
    FROM partload_analytics.ptl_fe_events e
    LEFT JOIN partload_analytics.ptl_routes
        ON ptl_routes.route_id =
           TRY_TO_NUMBER(NULLIF(TRY_PARSE_JSON(e.variable_attr):route_id::STRING, ''))
       AND ptl_routes.is_active = 'True'
    WHERE e.event_name = 'ptlbookingdetailspage_quote_viewed'
      AND e.customer_mobile_number NOT IN (
            SELECT mobile FROM partload_analytics.ptl_internal_users
      )
      [[AND {{pickup_city}}]]
      [[AND {{drop_city}}]]
    GROUP BY e.customer_mobile_number
),

/* ---------- FIRST BOOK NOW ---------- */
first_placed AS (
    SELECT
        e.customer_mobile_number,
        MIN(e.event_timestamp) AS first_placed_ts
    FROM partload_analytics.ptl_fe_events e
    LEFT JOIN partload_application.orders o
        ON PARSE_JSON(e.variable_attr):order_id::STRING = o.external_id
    LEFT JOIN partload_analytics.ptl_routes
        ON ptl_routes.route_id =
           TRY_TO_NUMBER(NULLIF(TRY_PARSE_JSON(e.variable_attr):route_id::STRING, ''))
       AND ptl_routes.is_active = 'True'
    WHERE e.event_name = 'ptlbookingdetailspage_booknow_clicked'
      AND e.customer_mobile_number NOT IN (
            SELECT mobile FROM partload_analytics.ptl_internal_users
      )
      /* -------- ORDER TYPE FILTER -------- */
      AND (
            {{order_type}} = 'placed'
            OR ({{order_type}} = 'completed' AND o.state = '3')
          )
      [[AND {{pickup_city}}]]
      [[AND {{drop_city}}]]
    GROUP BY e.customer_mobile_number
),

/* ---------- BASE USERS (FIRST TIME) ---------- */
base_users AS (
    SELECT
        q.customer_mobile_number,
        uc.user_type,
        DATE_TRUNC({{frequency}}, q.first_quote_ts) AS period,
        q.first_quote_ts,
        p.first_placed_ts
    FROM first_quote q
    LEFT JOIN first_placed p
        ON q.customer_mobile_number = p.customer_mobile_number
       AND p.first_placed_ts > q.first_quote_ts
    JOIN user_category uc
        ON q.customer_mobile_number = uc.customer_mobile_number
    WHERE DATE(q.first_quote_ts) BETWEEN {{start_date}} AND {{end_date}}
)

/* ---------- FINAL ---------- */
SELECT
    period,
    user_type,

    /* --- Denominator --- */
    COUNT(DISTINCT customer_mobile_number) AS quoted_users,

    /* --- Numerator --- */
    COUNT(DISTINCT CASE
        WHEN first_placed_ts IS NOT NULL
        THEN customer_mobile_number
    END) AS converted_users,

    /* --- Conversion % --- */
    ROUND(
        COUNT(DISTINCT CASE
            WHEN first_placed_ts IS NOT NULL
            THEN customer_mobile_number
        END) 
        / NULLIF(COUNT(DISTINCT customer_mobile_number), 0),
        4
    ) AS quote_to_booking_pct

FROM base_users
GROUP BY period, user_type
ORDER BY period, user_type;
