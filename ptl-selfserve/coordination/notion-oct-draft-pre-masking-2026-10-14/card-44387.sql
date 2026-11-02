WITH first_order AS (
    SELECT
        customer_mobile,
        created_at + INTERVAL '330 mins' AS first_order_date,
        DATE_TRUNC({{granularity}}, created_at + INTERVAL '330 mins') AS first_order_period
    FROM partload_application.orders
    WHERE state = '3'
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY customer_mobile
        ORDER BY created_at
    ) = 1
),

base_events AS (
    SELECT
        DATE_TRUNC({{granularity}}, DATE(e.event_timestamp)) AS period,
        e.customer_mobile_number,
        e.app_session_id,
        e.event_name,
        o.state AS order_state,
        CASE
            WHEN f.first_order_date IS NULL
              OR DATE(e.event_timestamp) <= DATE(f.first_order_date)
            THEN 'new'
            ELSE 'repeat'
        END AS user_type
    FROM partload_analytics.ptl_fe_events e
    LEFT JOIN first_order f
        ON f.customer_mobile = e.customer_mobile_number
    LEFT JOIN partload_application.orders o
        ON PARSE_JSON(e.variable_attr):order_id::STRING = o.external_id
    LEFT JOIN partload_analytics.ptl_routes
        ON ptl_routes.route_id = TRY_TO_NUMBER(TRY_PARSE_JSON(e.variable_attr):route_id::INT)
       AND ptl_routes.is_active = 'True'
    WHERE e.event_name IN (
        'ptlbookingdetailspage_quote_viewed',
        'ptlbookingdetailspage_booknow_clicked'
    )
      AND e.app_session_id IS NOT NULL
      AND e.customer_mobile_number NOT IN (
            SELECT mobile FROM partload_analytics.ptl_internal_users
      )
      [[AND DATE(e.event_timestamp) BETWEEN {{START_DATE}} AND {{END_DATE}}]]
      [[AND {{pickup_city}}]]
      [[AND {{drop_city}}]]
)

/* ---------------- FINAL OUTPUT ---------------- */
SELECT
    period,
    user_type,

    COUNT(DISTINCT CASE
        WHEN event_name = 'ptlbookingdetailspage_quote_viewed'
        THEN app_session_id
    END) AS quoted_sessions,

    COUNT(DISTINCT CASE
        WHEN event_name = 'ptlbookingdetailspage_booknow_clicked'
             AND order_state = '3'
        THEN app_session_id
    END) AS completed_sessions,

    ROUND(
        COUNT(DISTINCT CASE
            WHEN event_name = 'ptlbookingdetailspage_booknow_clicked'
                 AND order_state = '3'
            THEN app_session_id
        END) * 1.0
        / NULLIF(
            COUNT(DISTINCT CASE
                WHEN event_name = 'ptlbookingdetailspage_quote_viewed'
                THEN app_session_id
            END),
            0
        ),
        4
    ) AS quote_to_pay_pct

FROM base_events
GROUP BY period, user_type

UNION ALL

/* ---------------- OVERALL (NEW + REPEAT) ---------------- */
SELECT
    period,
    'overall' AS user_type,

    COUNT(DISTINCT CASE
        WHEN event_name = 'ptlbookingdetailspage_quote_viewed'
        THEN app_session_id
    END) AS quoted_sessions,

    COUNT(DISTINCT CASE
        WHEN event_name = 'ptlbookingdetailspage_booknow_clicked'
             AND order_state = '3'
        THEN app_session_id
    END) AS completed_sessions,

    ROUND(
        COUNT(DISTINCT CASE
            WHEN event_name = 'ptlbookingdetailspage_booknow_clicked'
                 AND order_state = '3'
            THEN app_session_id
        END) * 1.0
        / NULLIF(
            COUNT(DISTINCT CASE
                WHEN event_name = 'ptlbookingdetailspage_quote_viewed'
                THEN app_session_id
            END),
            0
        ),
        4
    ) AS quote_to_pay_pct

FROM base_events
GROUP BY period

ORDER BY period, user_type;
