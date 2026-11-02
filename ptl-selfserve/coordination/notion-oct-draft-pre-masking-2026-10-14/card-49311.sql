WITH repeat_customers AS (
    SELECT
        customer_mobile,
        MIN(created_at + interval '330 mins') AS first_completed_at
    FROM partload_application.orders
    WHERE state = 3
    GROUP BY 1
),

vss_events AS (
    SELECT DISTINCT
        t.app_session_id,
        t.event_timestamp + interval '330 mins' AS vss_ts
    FROM partload_analytics.ptl_fe_events t
    CROSS JOIN LATERAL FLATTEN(
        INPUT => TRY_PARSE_JSON(
                    TRY_PARSE_JSON(t.variable_attr):vehicle_ids_seq
                )
    ) f
    LEFT JOIN prod_eldoria.core.dim_customers dc
        ON dc.customer_id = t.customer_id
    LEFT JOIN repeat_customers rc
        ON rc.customer_mobile = t.customer_mobile_number
    LEFT JOIN partload_analytics.ptl_routes
        ON ptl_routes.route_id = TRY_TO_NUMBER(TRY_PARSE_JSON(t.variable_attr):route_id::STRING)
       AND ptl_routes.is_active = 'True'
    WHERE f.value::NUMBER IN (-1, 1159)
      AND t.event_name = 'vehicleselectionscreen_vehicles_loaded'
      AND t.customer_mobile_number NOT IN (
          SELECT mobile
          FROM partload_analytics.ptl_internal_users
      )
      [[AND (
            CASE
                WHEN dc.frequency IN (1,2,3,4) THEN 'Business'
                ELSE 'Personal'
            END
      ) = {{user_type}}]]
      [[AND (
            CASE
                WHEN DATE(rc.first_completed_at) < DATE(t.event_timestamp + interval '330 mins') THEN 'Repeat'
                ELSE 'New'
            END
      ) = {{customer_type}}]]
      [[AND {{route_name}}]]
      AND DATE(t.event_timestamp + interval '330 mins') >= {{start_date}}
      AND DATE(t.event_timestamp + interval '330 mins') <= {{end_date}}
),

booking_events AS (
    SELECT DISTINCT
        t.app_session_id,
        t.event_timestamp + interval '330 mins' AS booking_ts
    FROM partload_analytics.ptl_fe_events t
    LEFT JOIN prod_eldoria.core.dim_customers dc
        ON dc.customer_id = t.customer_id
    LEFT JOIN repeat_customers rc
        ON rc.customer_mobile = t.customer_mobile_number
    LEFT JOIN partload_analytics.ptl_routes
        ON ptl_routes.route_id = TRY_TO_NUMBER(TRY_PARSE_JSON(t.variable_attr):route_id::STRING)
       AND ptl_routes.is_active = 'True'
    WHERE t.event_name = 'ptlbookingdetailspage_booknow_clicked'
      AND t.customer_mobile_number NOT IN (
          SELECT mobile
          FROM partload_analytics.ptl_internal_users
      )
      [[AND (
            CASE
                WHEN dc.frequency IN (1,2,3,4) THEN 'Business'
                ELSE 'Personal'
            END
      ) = {{user_type}}]]
      [[AND (
            CASE
                WHEN DATE(rc.first_completed_at) < DATE(t.event_timestamp + interval '330 mins') THEN 'Repeat'
                ELSE 'New'
            END
      ) = {{customer_type}}]]
      [[AND {{route_name}}]]
      AND DATE(t.event_timestamp + interval '330 mins') >= {{start_date}}
      AND DATE(t.event_timestamp + interval '330 mins') <= {{end_date}}
),

first_vss_per_session AS (
    SELECT
        app_session_id,
        MIN(vss_ts) AS first_vss_ts
    FROM vss_events
    GROUP BY 1
),

first_booking_per_session AS (
    SELECT
        fv.app_session_id,
        b.booking_ts,
        DATE_TRUNC({{granularity}}, b.booking_ts) AS month
    FROM first_vss_per_session fv
    JOIN booking_events b
        ON b.app_session_id = fv.app_session_id
       AND b.booking_ts > fv.first_vss_ts
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY fv.app_session_id
        ORDER BY b.booking_ts
    ) = 1
),

session_pairs AS (
    SELECT
        fb.month,
        fv.app_session_id,
        fv.first_vss_ts,
        fb.booking_ts AS first_booking_ts,
        DATEDIFF('second', fv.first_vss_ts, fb.booking_ts) / 60.0 AS time_to_book_mins
    FROM first_vss_per_session fv
    JOIN first_booking_per_session fb
        ON fv.app_session_id = fb.app_session_id
)

SELECT
    month,
    MEDIAN(time_to_book_mins) AS median_time_to_book_mins
FROM session_pairs
GROUP BY 1
ORDER BY month DESC;
