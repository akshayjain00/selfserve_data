WITH combined AS (
      SELECT * FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_APP_SHEET_BACKFILLED_DATA
      UNION ALL
      SELECT * FROM PROD_CURATED.GSHEET_SYNC."ptl_app_sheet_data"
),
deduped AS (
      SELECT * FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY reached_pickup_at DESC NULLS LAST) AS rn FROM combined) WHERE rn = 1
),
agg AS (
      SELECT date_trunc('month', o.created_at + INTERVAL '330 mins')::DATE AS ct,
          COUNT(DISTINCT d.order_id) AS orders,
          COUNT(DISTINCT CASE WHEN d.batch_id IS NOT NULL THEN d.order_id END) AS batch_filled,
          COUNT(DISTINCT CASE WHEN d.batch_id IS NOT NULL AND d.reached_pickup_at IS NOT NULL AND d.picked_up_at IS NOT NULL
                              AND d.reached_drop_at IS NOT NULL AND d.delivered_at IS NOT NULL THEN d.order_id END) AS all_details_filled
      FROM deduped d
      INNER JOIN prod_curated.partload_application.orders o ON o.id = d.order_id AND o.state = '3'
      WHERE o.created_at + INTERVAL '330 mins' >= DATE '2026-01-01'
        AND o.created_at + INTERVAL '330 mins' <= DATE '2026-08-31' + INTERVAL '1 day'
      GROUP BY 1
)
SELECT ct, orders, batch_filled, all_details_filled,
       ROUND(100.0*batch_filled/NULLIF(orders,0),2) AS batch_filled_pct,
       ROUND(100.0*all_details_filled/NULLIF(batch_filled,0),2) AS all_details_filled_pct
FROM agg ORDER BY ct