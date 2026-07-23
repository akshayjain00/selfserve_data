WITH online AS (
    SELECT
        'ON:' || o.external_id                                          AS okey,
        o.state                                                         AS state,   /*⚠VERIFY enum 3=completed,4=cancelled (P1)*/
        o.estimated_fare                                                AS revenue, /*⚠VERIFY revenue col + AOV date-basis updated_at vs created_at (§3.6)*/
        CASE WHEN EXISTS (SELECT 1 FROM prod_curated.partload_application.order_vehicles ov
                          WHERE ov.order_external_id = o.external_id)    /*⚠VERIFY join key + is_active; 49366-style signal, reconcile vs 4793 (D5)*/
             THEN 1 ELSE 0 END                                          AS vehicle_assigned
    FROM prod_curated.partload_application.orders o
    WHERE o.created_at >= DATEADD('minute', -330, DATE '2026-04-01')          -- IST month start (data is UTC; CLAUDE.md rule; bare column preserves pruning)
      AND o.created_at <  DATEADD('minute', -330, DATE '2026-05-01')
      AND NOT EXISTS (SELECT 1 FROM prod_curated.partload_analytics.ptl_internal_users u WHERE u.mobile = o.customer_mobile)   -- internal/test exclusion (NOT EXISTS avoids NULL trap)
      AND EXISTS (SELECT 1 FROM prod_curated.oms_public.customers c
                  WHERE c.mobile = o.customer_mobile AND c.frequency IN (1,2,3,4)) /*⚠VERIFY business filter: oms_public vs dim_customers + join key (§3.5)*/
),
offline AS (
    SELECT
        'OFF:' || so.order_crn                                          AS okey,    /*⚠VERIFY offline col names*/
        CASE so.status_code                                                          /*⚠VERIFY offline status_code -> enum UNMAPPED; unrecognised -> NULL (not counted). Gated by OFFLINE_STATUS_CONFIRMED*/
             WHEN 'completed' THEN 3 WHEN 'cancelled' THEN 4 ELSE NULL END AS state,
        so.fare                                                         AS revenue, /*⚠VERIFY*/
        0                                                               AS vehicle_assigned /*⚠VERIFY offline allocation unknown -> excluded from cbdf/cadf (state gated NULL anyway)*/
    FROM prod_curated.gsheet_sync.ptl_offline_orders so
    WHERE so.month_start = DATE '2026-04-01'                                  /*⚠VERIFY offline month column + IST alignment*/
)
SELECT
        'incl_offline' AS basis,
        COUNT(DISTINCT okey)                                            AS placed,
        COUNT(DISTINCT CASE WHEN state = 3 THEN okey END)               AS completed,
        COUNT(DISTINCT CASE WHEN state = 4 AND vehicle_assigned = 0 THEN okey END) AS cbdf_cancels,
        COUNT(DISTINCT CASE WHEN state = 4 AND vehicle_assigned = 1 THEN okey END) AS cadf_cancels,
        COUNT(DISTINCT okey)
          - COUNT(DISTINCT CASE WHEN state = 4 AND vehicle_assigned = 0 THEN okey END) AS placed_less_cbdf,
        SUM(CASE WHEN state = 3 THEN revenue ELSE 0 END)               AS revenue_completed
    FROM (SELECT okey,state,revenue,vehicle_assigned FROM online UNION ALL SELECT okey,state,revenue,vehicle_assigned FROM offline)
UNION ALL
SELECT
        'excl_offline' AS basis,
        COUNT(DISTINCT okey)                                            AS placed,
        COUNT(DISTINCT CASE WHEN state = 3 THEN okey END)               AS completed,
        COUNT(DISTINCT CASE WHEN state = 4 AND vehicle_assigned = 0 THEN okey END) AS cbdf_cancels,
        COUNT(DISTINCT CASE WHEN state = 4 AND vehicle_assigned = 1 THEN okey END) AS cadf_cancels,
        COUNT(DISTINCT okey)
          - COUNT(DISTINCT CASE WHEN state = 4 AND vehicle_assigned = 0 THEN okey END) AS placed_less_cbdf,
        SUM(CASE WHEN state = 3 THEN revenue ELSE 0 END)               AS revenue_completed
    FROM online
