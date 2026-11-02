-- Derived from card 43237 (Funnel View- Cancellations - CADF/CBDF) native SQL, 2026-10-09.
-- No Metabase card exists for CBDF/CADF x cancellation_source (siblings 43242/47673/47674 are timing splits).
-- Substitutions: {{start_date}} -> '2026-08-01'; {{granularity}} -> 'month'; [[pickup_city]]/[[route]] dropped.
-- Changes vs card: base keeps the same joins/filters (no internal-user filter, no offline orders), unused weight cols dropped;
-- output adds cancellation_source split and computes both exclude_60_sec = YES and NO in one pass; capped at < 2026-10-01 IST.
-- Source codes (from card 33465): 1 Customer_App, 2 Partner_App, 3 Salesforce, 4 Appsmith.
WITH base AS (
    SELECT o.id AS order_id, o.state, cr.cancellation_source,
           o.created_at + INTERVAL '330 mins' AS order_ts,
           cr.created_at + INTERVAL '330 mins' AS cancellation_ts,
           (o.created_at + INTERVAL '330 mins')::DATE AS order_date,
           ov.vehicle_name,
           CASE WHEN DATEDIFF(SECOND, o.created_at + INTERVAL '330 mins', cr.created_at + INTERVAL '330 mins') <= 60 THEN o.id END AS within_1_cancel
    FROM prod_curated.partload_application.orders o
    LEFT JOIN prod_curated.partload_application.order_cancellation_reasons cr ON cr.order_id = o.id
    LEFT JOIN prod_curated.partload_application.order_vehicles ov ON o.id = ov.order_id AND ov.is_active
    WHERE o.created_at + INTERVAL '330 mins' >= '2026-08-01'::DATE
      AND o.created_at + INTERVAL '330 mins' <  '2026-10-01'::DATE
),
placed AS (SELECT DATE_TRUNC('month', order_date) m, COUNT(DISTINCT order_id) placed_orders FROM base GROUP BY 1)
SELECT DATE_TRUNC('month', b.order_date) AS order_month,
       CASE b.cancellation_source WHEN '1' THEN 'Customer_App' WHEN '2' THEN 'Partner_App' WHEN '3' THEN 'Salesforce' WHEN '4' THEN 'Appsmith' ELSE COALESCE(b.cancellation_source::string,'NULL') END AS src,
       p.placed_orders,
       COUNT(DISTINCT CASE WHEN b.vehicle_name IS NULL AND b.state = 4 AND b.within_1_cancel IS NULL THEN b.order_id END) AS cbdf_orders_excl60,
       COUNT(DISTINCT CASE WHEN b.vehicle_name IS NOT NULL AND b.state = 4 AND b.within_1_cancel IS NULL THEN b.order_id END) AS cadf_orders_excl60,
       COUNT(DISTINCT CASE WHEN b.vehicle_name IS NULL AND b.state = 4 THEN b.order_id END) AS cbdf_orders_incl60,
       COUNT(DISTINCT CASE WHEN b.vehicle_name IS NOT NULL AND b.state = 4 THEN b.order_id END) AS cadf_orders_incl60
FROM base b JOIN placed p ON p.m = DATE_TRUNC('month', b.order_date)
WHERE b.state = 4
GROUP BY 1,2,3
ORDER BY 1,2;
