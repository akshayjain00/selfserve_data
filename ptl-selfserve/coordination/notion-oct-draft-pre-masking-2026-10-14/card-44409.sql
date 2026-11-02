WITH first_order_base AS (
    SELECT
        customer_mobile,
        created_at + INTERVAL '330 mins' AS first_order_date,
        TO_VARCHAR(created_at + INTERVAL '330 mins', 'YYYY-MM') AS year_month,
        external_id AS first_order_id
    FROM partload_application.orders
    WHERE 1=1
      AND (
            ({{order_type}} = 'completed' AND state = '3')
            OR {{order_type}} = 'overall'
          )
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY customer_mobile 
        ORDER BY created_at ASC
    ) = 1
),

event_base AS (
    SELECT
        fe.event_timestamp,
        fe.event_name,
        fe.app_session_id,
        fe.customer_mobile_number,

        TRY_PARSE_JSON(fe.variable_attr):order_id::STRING AS order_id,
        TRY_TO_NUMBER(TRY_PARSE_JSON(fe.variable_attr):route_id::STRING) AS route_id,

        REGEXP_REPLACE(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    TRY_PARSE_JSON(fe.variable_attr):experiment_key::STRING,
                    '^\\[|\\]$', ''
                ),
                '^"|"$', ''
            ),
            '\\\\"', ''
        ) AS experiment_key,

        REGEXP_REPLACE(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    TRY_PARSE_JSON(fe.variable_attr):variant_name::STRING,
                    '^\\[|\\]$', ''
                ),
                '^"|"$', ''
            ),
            '\\\\"', ''
        ) AS variant_name

    FROM partload_analytics.ptl_fe_events fe

    LEFT JOIN partload_analytics.ptl_routes 
        ON ptl_routes.route_id = TRY_TO_NUMBER(TRY_PARSE_JSON(fe.variable_attr):route_id::STRING)
       AND ptl_routes.is_active = 'True'

    WHERE 1=1
      AND fe.customer_mobile_number NOT IN (
          SELECT mobile 
          FROM partload_analytics.ptl_internal_users
      )
      AND fe.event_name IN (
          'vehicleselectionscreen_vehicles_loaded',
          'ptlbookingdetailspage_booknow_clicked'
      )
      AND fe.app_session_id != 'dbe3759b-bd16-4523-9f24-1c0f45e34c2a'

      AND TRY_PARSE_JSON(fe.variable_attr):experiment_key IS NOT NULL
      AND TRY_PARSE_JSON(fe.variable_attr):variant_name IS NOT NULL

      [[AND DATE(fe.event_timestamp) >= {{START_DATE}}]]
      [[AND DATE(fe.event_timestamp) <= {{END_DATE}}]]
      [[AND {{pickup_city}}]]
      [[AND {{drop_city}}]]

      [[AND REGEXP_REPLACE(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    TRY_PARSE_JSON(fe.variable_attr):experiment_key::STRING,
                    '^\\[|\\]$', ''
                ),
                '^"|"$', ''
            ),
            '\\\\"', ''
        ) = {{experiment_key}}]]

      [[AND REGEXP_REPLACE(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    TRY_PARSE_JSON(fe.variable_attr):variant_name::STRING,
                    '^\\[|\\]$', ''
                ),
                '^"|"$', ''
            ),
            '\\\\"', ''
        ) = {{variant_name}}]]
),

final AS (
    SELECT
        DATE_TRUNC({{granularity}}, DATE(eb.event_timestamp)) AS month,

        CASE
            WHEN fob.first_order_date IS NULL
                 OR DATE(eb.event_timestamp) <= DATE(fob.first_order_date)
            THEN 'new customer'
            ELSE 'repeat customer'
        END AS customer_tag,

        eb.experiment_key,
        eb.variant_name,
        eb.event_name,
        eb.app_session_id,
        o.state

    FROM event_base eb

    LEFT JOIN first_order_base fob
        ON fob.customer_mobile = eb.customer_mobile_number

    LEFT JOIN partload_application.orders o
        ON eb.order_id = o.external_id
)

SELECT 
    month,
    customer_tag,
    experiment_key,
    variant_name,

    COUNT(DISTINCT CASE 
        WHEN event_name = 'vehicleselectionscreen_vehicles_loaded' 
        THEN app_session_id 
    END) AS vss_sessions,

    COUNT(DISTINCT CASE 
        WHEN event_name = 'ptlbookingdetailspage_booknow_clicked'
         AND (
              {{order_type}} = 'overall'
              OR ({{order_type}} = 'completed' AND state = '3')
         )
        THEN app_session_id 
    END) AS book_now_sessions,

    COUNT(DISTINCT CASE 
        WHEN event_name = 'ptlbookingdetailspage_booknow_clicked'
         AND (
              {{order_type}} = 'overall'
              OR ({{order_type}} = 'completed' AND state = '3')
         )
        THEN app_session_id 
    END) * 1.0
    / NULLIF(
        COUNT(DISTINCT CASE 
            WHEN event_name = 'vehicleselectionscreen_vehicles_loaded' 
            THEN app_session_id 
        END),
        0
    ) AS conversion_pct

FROM final
GROUP BY 1,2,3,4
ORDER BY 1 DESC, 2, 3, 4;