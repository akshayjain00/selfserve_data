WITH leads_base AS (
    SELECT
        f.opp_id,
        f.opp_created_ts,
        f.source,
        f.source_details,
        f.sr_id,
        d.intra_city,
        d.user_flag,
        d.is_nano
    FROM PROD_CURATED.pnm_application.fact_pnm_opprotunity f
    JOIN PROD_CURATED.pnm_application.dim_pnm_opportunity  d USING (opp_id)
    WHERE DATE_TRUNC('month', f.opp_created_ts) IN ('2026-05-01', '2026-04-01')
      AND d.intra_city = TRUE
      AND d.user_flag  = 'normal'
),
orders_base_raw AS (
    SELECT
        o.order_id,
        o.crn,
        o.sr_id,
        o.o_created_ts,
        o.o_completed_ts,
        o.status,
        d.intra_city,
        d.user_flag,
        d.is_nano,
        l.source,
        l.source_details,
        o.vendor_accepted_ts,
        o.supervisor_assigned_ts,
        o.supervisor_accepted_ts,
        o.trip_started_ts,
        o.shifting_started_ts,
        o.pickup_completed_ts,
        o.order_completed_ts
    FROM PROD_CURATED.pnm_application.orders o
    INNER JOIN PROD_CURATED.pnm_application.pnm_customers  c ON o.customer_id = c.customer_id
    LEFT  JOIN PROD_CURATED.pnm_application.dim_pnm_orders d USING (order_id)
    LEFT  JOIN leads_base                                  l ON o.sr_id = l.sr_id
    WHERE DATE_TRUNC('month', o.o_created_ts) IN ('2026-05-01', '2026-04-01')
      AND d.intra_city = TRUE
      AND d.user_flag  = 'normal'
      AND o.status    != 4
    QUALIFY ROW_NUMBER() OVER (PARTITION BY o.sr_id ORDER BY o.o_created_ts) = 1
)
SELECT
    DATE_TRUNC('month', o_created_ts)                                                AS month,
    COUNT(DISTINCT order_id)                                                         AS orders_overall,
    COUNT(DISTINCT CASE WHEN source IN (1,2,3)                  THEN order_id END)   AS orders_app,
    COUNT(DISTINCT CASE WHEN source_details = 'Desktop Website' THEN order_id END)   AS orders_desktop,
    COUNT(DISTINCT CASE WHEN source_details = 'Mobile Website'  THEN order_id END)   AS orders_mobile,
    COUNT(DISTINCT CASE WHEN source = 4                         THEN order_id END)   AS orders_others
FROM orders_base_raw
GROUP BY 1
ORDER BY 1