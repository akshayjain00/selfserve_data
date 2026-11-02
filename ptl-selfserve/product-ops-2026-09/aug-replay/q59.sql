WITH combined AS (
    SELECT * FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_APP_SHEET_BACKFILLED_DATA
    UNION ALL SELECT * FROM PROD_CURATED.GSHEET_SYNC."ptl_app_sheet_data"
),
deduped AS (SELECT * FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY reached_pickup_at DESC NULLS LAST) AS rn FROM combined) WHERE rn = 1)
SELECT date_trunc('month', o.created_at + INTERVAL '330 mins')::DATE AS ct,
    COUNT(DISTINCT CASE WHEN reached_pickup_at::timestamp IS NOT NULL THEN d.order_id END) AS base_pickup,
    COUNT(DISTINCT CASE WHEN reached_drop_at::timestamp IS NOT NULL THEN d.order_id END) AS base_drop,
    ROUND(100.0*COUNT(DISTINCT CASE WHEN reached_pickup_at::timestamp <= (o.PICKUP_SLOT_END + INTERVAL '330 mins' + INTERVAL '1 hour') THEN d.order_id END)
       /NULLIF(COUNT(DISTINCT CASE WHEN reached_pickup_at::timestamp IS NOT NULL THEN d.order_id END),0),2) AS pickup_sla_pct,
    ROUND(100.0*COUNT(DISTINCT CASE WHEN reached_drop_at::timestamp <= (o.estimated_delivery_ts + INTERVAL '330 mins') THEN d.order_id END)
       /NULLIF(COUNT(DISTINCT CASE WHEN reached_drop_at::timestamp IS NOT NULL THEN d.order_id END),0),2) AS drop_sla_actual_pct,
    ROUND(100.0*COUNT(DISTINCT CASE WHEN reached_pickup_at IS NOT NULL AND reached_drop_at IS NOT NULL
         AND reached_pickup_at::timestamp <= (o.PICKUP_SLOT_END + INTERVAL '330 mins' + INTERVAL '1 hour')
         AND reached_drop_at::timestamp <= (o.estimated_delivery_ts + INTERVAL '330 mins') THEN d.order_id END)
       /NULLIF(COUNT(DISTINCT CASE WHEN reached_drop_at::timestamp IS NOT NULL THEN d.order_id END),0),2) AS opod_pct
FROM deduped d
INNER JOIN prod_curated.partload_application.orders o ON o.id = d.order_id AND o.state = '3'
   AND DATE(o.created_at + INTERVAL '330 mins') >= DATE '2026-01-01'
   AND DATE(o.created_at + INTERVAL '330 mins') <= DATE '2026-08-31'
WHERE d.order_id != '22041'
GROUP BY 1 ORDER BY 1