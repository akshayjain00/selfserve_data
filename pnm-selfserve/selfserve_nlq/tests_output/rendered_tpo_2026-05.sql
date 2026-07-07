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
),
order_base AS (
    SELECT
        o.order_id,
        DATE_TRUNC('month', a.completed_ts) AS alloc_month
    FROM orders_base_raw o
    JOIN PROD_CURATED.pnm_application.order_allocation_infos a ON o.order_id = a.order_id
    WHERE o.is_nano = FALSE
      AND a.completed_ts IS NOT NULL
),
ticket_data AS (
    SELECT t.order_id, t.created_at, t.raised_by, t.order_status_at_creation
    FROM PROD_CURATED.pnm_application.tickets t
    JOIN order_base b ON t.order_id = b.order_id
    WHERE LOWER(t.raised_by) NOT LIKE '%detractor%'
),
monthly AS (
    SELECT
        b.alloc_month                                                                   AS month,
        COUNT(DISTINCT b.order_id)                                                      AS orders_base,
        COUNT(t.order_id)                                                               AS tickets_overall,
        COUNT(CASE WHEN t.raised_by IN ('Vendor-Owner','Vendor-Supervisor') THEN 1 END) AS tickets_vendor,
        COUNT(CASE WHEN t.order_status_at_creation IN
                        ('open','supervisor_assigned','supervisor_accepted','vendor_accepted')
                   THEN 1 END)                                                          AS tickets_pre_trip,
        COUNT(CASE WHEN t.order_status_at_creation IN
                        ('open','supervisor_assigned','supervisor_accepted','vendor_accepted')
                        AND t.raised_by = 'Customer' THEN 1 END)                        AS tickets_pre_trip_cust,
        COUNT(CASE WHEN t.order_status_at_creation IN ('trip_started','shifting_started')
                   THEN 1 END)                                                          AS tickets_trip_shift,
        COUNT(CASE WHEN t.order_status_at_creation IN ('trip_started','shifting_started')
                        AND t.raised_by = 'Customer' THEN 1 END)                        AS tickets_trip_shift_cust,
        COUNT(CASE WHEN t.order_status_at_creation = 'pickup_completed' THEN 1 END)     AS tickets_pickup,
        COUNT(CASE WHEN t.order_status_at_creation = 'pickup_completed'
                        AND t.raised_by = 'Customer' THEN 1 END)                        AS tickets_pickup_cust,
        COUNT(CASE WHEN t.order_status_at_creation = 'completed' THEN 1 END)            AS tickets_completed,
        COUNT(CASE WHEN t.order_status_at_creation = 'completed'
                        AND t.raised_by = 'Customer' THEN 1 END)                        AS tickets_completed_cust,
        COUNT(CASE WHEN t.order_status_at_creation = 'cancelled' THEN 1 END)            AS tickets_cancelled,
        COUNT(CASE WHEN t.order_status_at_creation = 'cancelled'
                        AND t.raised_by = 'Customer' THEN 1 END)                        AS tickets_cancelled_cust
    FROM order_base b
    LEFT JOIN ticket_data t ON b.order_id = t.order_id
                             AND DATE_TRUNC('month', t.created_at) = b.alloc_month
    GROUP BY 1
)
SELECT
    month,
    orders_base,
    ROUND(tickets_overall        / NULLIF(orders_base,0), 4) AS tpo_overall,
    ROUND(tickets_vendor         / NULLIF(orders_base,0), 4) AS tpo_vendor_raised,
    ROUND(tickets_pre_trip       / NULLIF(orders_base,0), 4) AS tpo_pre_trip,
    ROUND(tickets_pre_trip_cust  / NULLIF(orders_base,0), 4) AS tpo_pre_trip_customer,
    ROUND(tickets_trip_shift     / NULLIF(orders_base,0), 4) AS tpo_trip_shift,
    ROUND(tickets_trip_shift_cust/ NULLIF(orders_base,0), 4) AS tpo_trip_shift_customer,
    ROUND(tickets_pickup         / NULLIF(orders_base,0), 4) AS tpo_pickup,
    ROUND(tickets_pickup_cust    / NULLIF(orders_base,0), 4) AS tpo_pickup_customer,
    ROUND(tickets_completed      / NULLIF(orders_base,0), 4) AS tpo_completed,
    ROUND(tickets_completed_cust / NULLIF(orders_base,0), 4) AS tpo_completed_customer,
    ROUND(tickets_cancelled      / NULLIF(orders_base,0), 4) AS tpo_cancelled,
    ROUND(tickets_cancelled_cust / NULLIF(orders_base,0), 4) AS tpo_cancelled_customer
FROM monthly
ORDER BY 1