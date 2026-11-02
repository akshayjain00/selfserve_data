WITH base AS (
    SELECT
        o.customer_mobile,
        o.created_at + INTERVAL '330 mins' AS first_order_date,
        TO_VARCHAR(o.created_at + INTERVAL '330 mins', 'YYYY-MM') AS year_month,
        o.external_id AS first_order_id
    FROM partload_application.orders o
    WHERE 1 = 1
      AND (
            ({{order_type}} = 'completed' AND o.state = 3)
            OR {{order_type}} = 'overall'
          )
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY o.customer_mobile
        ORDER BY o.created_at ASC
    ) = 1
)

SELECT
    DATE_TRUNC({{granularity}}, DATE(e.event_timestamp + INTERVAL '330 mins')) AS month,
    CASE
        WHEN {{customer_segment}} = 'Customer is new only till their first-order month'
             AND (
                    TO_VARCHAR(e.event_timestamp + INTERVAL '330 mins', 'YYYY-MM') <= base.year_month
                    OR base.year_month IS NULL
                 )
        THEN 'new customer'

        WHEN {{customer_segment}} = 'Customer is new only on till their first-order day'
             AND (
                    DATE(e.event_timestamp + INTERVAL '330 mins') <= DATE(base.first_order_date)
                    OR base.first_order_date IS NULL
                 )
        THEN 'new customer'

        ELSE 'repeat customer'
    END AS customer_tag,

    COUNT(DISTINCT CASE
        WHEN e.event_name = 'vehicleselectionscreen_vehicles_loaded'
        THEN e.app_session_id
    END) AS vss_sessions,

    COUNT(DISTINCT CASE
        WHEN e.event_name = 'ptlbookingdetailspage_quote_viewed'
        THEN e.app_session_id
    END) AS quote_sessions,

    1.0 * COUNT(DISTINCT CASE
        WHEN e.event_name = 'ptlbookingdetailspage_quote_viewed'
        THEN e.app_session_id
    END)
    / NULLIF(
        COUNT(DISTINCT CASE
            WHEN e.event_name = 'vehicleselectionscreen_vehicles_loaded'
            THEN e.app_session_id
        END),
        0
    ) AS vss_to_quote_conversion_pct

FROM partload_analytics.ptl_fe_events e
LEFT JOIN base
    ON base.customer_mobile = e.customer_mobile_number
LEFT JOIN partload_analytics.ptl_routes
    ON ptl_routes.route_id = TRY_TO_NUMBER(TRY_PARSE_JSON(e.variable_attr):route_id::INT)
   AND ptl_routes.is_active = 'True'
 LEFT JOIN prod_curated.oms_public.customers c
        ON c.mobile = e.customer_mobile_number
WHERE 1 = 1
  AND e.customer_mobile_number NOT IN (
        SELECT mobile
        FROM partload_analytics.ptl_internal_users
  )
  AND e.event_name IN (
        'vehicleselectionscreen_vehicles_loaded',
        'ptlbookingdetailspage_quote_viewed'
  )
  AND e.app_session_id != 'dbe3759b-bd16-4523-9f24-1c0f45e34c2a'
  [[AND DATE(e.event_timestamp + INTERVAL '330 mins') >= {{start_date}}]]
  [[AND DATE(e.event_timestamp + INTERVAL '330 mins') <= {{end_date}}]]
  [[AND {{pickup_city}}]]
  [[AND {{drop_city}}]]
   [[AND (
    CASE
        WHEN c.frequency IN (1, 2, 3, 4) THEN 'Business'
        ELSE 'Personal'
    END
) = {{category}}]]

GROUP BY 1, 2
ORDER BY 1 DESC, 2;
