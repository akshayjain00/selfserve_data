-- card 48922 Average number of sessions before first PTL order
-- params: start_date=2026-08-01 end_date=2026-09-30 granularity='Month' category='Business'; pickup/drop city blocks dropped
-- Metabase run failed: Numeric value 'XXXXXX7760' is not recognized (ptl_fe_events mobile masked vs ptl_internal_users.mobile NUMBER)
-- REWRITE (PII masking): customer_mobile -> orders.customer_id (uuid); business flag = customer_id IN customers.uuid with frequency 1-4;
--   internal users = customer_id NOT IN ptl_internal_users.customer_uuid; events mapped via customers.id = ptl_fe_events.customer_id -> c.uuid
WITH first_ptl_order AS (
    SELECT o.customer_id,
        CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at)) AS first_order_ts,
        CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at))::DATE AS first_order_date,
        DATE_TRUNC('Month', CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at)))::DATE AS period_start
    FROM prod_curated.partload_application.orders o
    LEFT JOIN prod_curated.oms_public.customers c ON c.uuid = o.customer_id
    WHERE o.customer_id IS NOT NULL
      AND o.customer_id NOT IN (SELECT customer_uuid FROM prod_curated.partload_analytics.ptl_internal_users WHERE customer_uuid IS NOT NULL)
      AND o.state = 3
      AND CASE WHEN c.frequency IN (1, 2, 3, 4) THEN 'Business' ELSE 'Personal' END = 'Business'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at)), o.id) = 1
),
first_orders_in_scope AS (
    SELECT * FROM first_ptl_order
    WHERE first_order_date >= '2026-08-01' AND first_order_date < '2026-09-30'::date + INTERVAL '1 day'
),
vehicles_loaded_events AS (
    SELECT DISTINCT c.uuid AS customer_id, e.app_session_id, e.event_timestamp + INTERVAL '330 minutes' AS event_ts_ist
    FROM prod_curated.partload_analytics.ptl_fe_events e
    JOIN prod_curated.oms_public.customers c ON c.id = e.customer_id,
         LATERAL FLATTEN(INPUT => TRY_PARSE_JSON(TRY_PARSE_JSON(e.variable_attr):vehicle_ids_seq)) f
    WHERE e.event_name = 'vehicleselectionscreen_vehicles_loaded'
      AND c.uuid NOT IN (SELECT customer_uuid FROM prod_curated.partload_analytics.ptl_internal_users WHERE customer_uuid IS NOT NULL)
      AND f.value::NUMBER IN (-1, 1159)
),
sessions_before_first_order AS (
    SELECT fo.period_start, fo.customer_id, COUNT(DISTINCT v.app_session_id) AS sessions_before_first_order
    FROM first_orders_in_scope fo
    LEFT JOIN vehicles_loaded_events v ON v.customer_id = fo.customer_id AND v.event_ts_ist < fo.first_order_ts
    GROUP BY 1, 2
)
SELECT period_start, COUNT(DISTINCT customer_id) AS users_with_first_order,
    ROUND(AVG(COALESCE(sessions_before_first_order, 0)), 2) AS avg_sessions_before_first_ptl_order
FROM sessions_before_first_order GROUP BY 1 ORDER BY 1;
