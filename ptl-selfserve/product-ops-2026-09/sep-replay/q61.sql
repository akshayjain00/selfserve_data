WITH latest_ops_declared AS (
    SELECT order_id, chargeable_weight, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY created_at DESC) AS rn
    FROM prod_curated.partload_application.load_details WHERE entry_type = 'OPS_DECLARED'
),
latest_ops AS (SELECT order_id, chargeable_weight AS latest_ops_weight FROM latest_ops_declared WHERE rn = 1),
wd_base AS (
    SELECT o.id AS order_id,
        (lo.latest_ops_weight/1000.0) - (MAX(CASE WHEN ld.entry_type='CUSTOMER_DECLARED' THEN ld.chargeable_weight END)/1000.0) AS wd
    FROM prod_curated.partload_application.orders o
    LEFT JOIN prod_curated.partload_application.load_details ld ON ld.order_id = o.id
    LEFT JOIN latest_ops lo ON lo.order_id = o.id
    WHERE o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
      AND o.state = 3
      AND DATE(o.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-01-01' AND DATE '2026-09-30'
    GROUP BY 1, lo.latest_ops_weight
),
combined AS (
    SELECT * FROM prod_curated.partload_analytics.ptl_app_sheet_backfilled_data
    UNION ALL SELECT * FROM prod_curated.gsheet_sync."ptl_app_sheet_data"
),
deduped AS (SELECT * FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY reached_pickup_at DESC NULLS LAST) AS rn FROM combined) WHERE rn = 1)
SELECT DATE_TRUNC('month', o.created_at + INTERVAL '330 mins')::DATE AS period,
    COUNT(DISTINCT CASE WHEN d.reached_drop_at::timestamp IS NOT NULL THEN d.order_id END) AS base,
    ROUND(100.0*COUNT(DISTINCT CASE WHEN d.reached_pickup_at IS NOT NULL AND d.reached_drop_at IS NOT NULL
         AND d.reached_pickup_at::timestamp <= (o.pickup_slot_end + INTERVAL '330 mins' + INTERVAL '1 hour')
         AND d.reached_drop_at::timestamp <= (o.estimated_delivery_ts + INTERVAL '330 mins')
         AND COALESCE(w.wd,0) < 25 THEN d.order_id END)
      /NULLIF(COUNT(DISTINCT CASE WHEN d.reached_drop_at::timestamp IS NOT NULL THEN d.order_id END),0),2) AS perfect_order_pct
FROM deduped d
INNER JOIN prod_curated.partload_application.orders o ON o.id = d.order_id AND o.state = 3
LEFT JOIN wd_base w ON w.order_id = o.id
WHERE d.order_id != '22041'
  AND o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
  AND DATE(o.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-01-01' AND DATE '2026-09-30'
GROUP BY 1 ORDER BY 1