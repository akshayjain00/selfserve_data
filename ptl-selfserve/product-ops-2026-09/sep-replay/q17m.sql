WITH first_ptl_order AS (
    SELECT o.customer_mobile,
        CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(o.created_at)) AS first_order_ts,
        CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(o.created_at))::DATE AS first_order_date,
        DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(o.created_at)))::DATE AS period_start
    FROM prod_curated.partload_application.orders o
    LEFT JOIN prod_curated.oms_public.customers c ON c.mobile = o.customer_mobile
    LEFT JOIN prod_curated.partload_analytics.ptl_internal_users iu ON iu.mobile = o.customer_mobile
    WHERE o.customer_mobile IS NOT NULL AND iu.mobile IS NULL AND o.state = 3
      AND CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = 'Business'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY o.customer_mobile
        ORDER BY CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(o.created_at)), o.id) = 1
),
first_orders_in_scope AS (
    SELECT * FROM first_ptl_order
    WHERE first_order_date >= DATE '2026-01-01' AND first_order_date < DATE '2026-09-30' + INTERVAL '1 day'
),
vehicles_loaded_events AS (
    SELECT DISTINCT TRY_TO_NUMBER(e.customer_mobile_number) AS customer_mobile, e.app_session_id,
           e.event_timestamp + INTERVAL '330 minutes' AS event_ts_ist
    FROM prod_curated.partload_analytics.ptl_fe_events e,
         LATERAL FLATTEN(INPUT => TRY_PARSE_JSON(TRY_PARSE_JSON(e.variable_attr):vehicle_ids_seq)) f
    WHERE e.event_name = 'vehicleselectionscreen_vehicles_loaded'
      AND TRY_TO_NUMBER(e.customer_mobile_number) IS NOT NULL
      AND TRY_TO_NUMBER(e.customer_mobile_number) NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
      AND f.value::NUMBER IN (-1, 1159)
),
sessions_before_first_order AS (
    SELECT fo.period_start, fo.customer_mobile, COUNT(DISTINCT v.app_session_id) AS sessions_before
    FROM first_orders_in_scope fo
    LEFT JOIN vehicles_loaded_events v ON v.customer_mobile = fo.customer_mobile AND v.event_ts_ist < fo.first_order_ts
    GROUP BY 1,2
)
SELECT period_start, COUNT(DISTINCT customer_mobile) AS users_with_first_order,
       ROUND(AVG(COALESCE(sessions_before,0)),2) AS avg_sessions_before_first_order
FROM sessions_before_first_order GROUP BY 1 ORDER BY 1