WITH combined AS (
      SELECT * FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_APP_SHEET_BACKFILLED_DATA
      UNION ALL SELECT * FROM PROD_CURATED.GSHEET_SYNC."ptl_app_sheet_data"
),
deduped AS (SELECT * FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY reached_pickup_at DESC NULLS LAST) AS rn FROM combined) WHERE rn=1),
partner AS (
      SELECT date_trunc('month', o.created_at + INTERVAL '330 mins')::DATE AS m,
          COUNT(DISTINCT CASE WHEN d.batch_id IS NOT NULL THEN d.order_id END) AS batch_filled,
          COUNT(DISTINCT CASE WHEN d.batch_id IS NOT NULL AND d.reached_pickup_at IS NOT NULL AND d.picked_up_at IS NOT NULL
                              AND d.reached_drop_at IS NOT NULL AND d.delivered_at IS NOT NULL THEN d.order_id END) AS all_filled
      FROM deduped d
      INNER JOIN prod_curated.partload_application.orders o ON o.id = d.order_id AND o.state = '3'
      WHERE DATE(o.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-01-01' AND DATE '2026-08-31'
      GROUP BY 1
),
ob_comb AS (
    SELECT * FROM prod_curated.partload_analytics.ptl_batch_level_app_sheet_old
    UNION ALL SELECT * FROM prod_curated.gsheet_sync."PTL_BATCH_APP_SHEET_DATA"
),
ob_ded AS (SELECT * FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY batch_id ORDER BY accepted_at DESC NULLS LAST) rn FROM ob_comb) WHERE rn=1),
owner AS (
    SELECT date_trunc('month', date(created_at + INTERVAL '330 mins'))::DATE AS m,
        COUNT(DISTINCT batch_id) AS batches,
        COUNT(DISTINCT CASE WHEN accepted_by_email IS NOT NULL THEN batch_id END) AS accepted
    FROM ob_ded d LEFT JOIN prod_curated.partload_application.batch_v1 bv1 ON bv1.id = batch_id
    WHERE batch_status != 'CANCELLED'
      AND created_at + INTERVAL '330 mins' >= DATE '2026-01-01'
      AND created_at + INTERVAL '330 mins' <= DATE '2026-08-31' + INTERVAL '1 day'
    GROUP BY 1
)
SELECT COALESCE(p.m,o.m) AS month,
       o.batches, ROUND(100.0*o.accepted/NULLIF(o.batches,0),2) AS owner_adoption_pct,
       p.batch_filled, ROUND(100.0*p.all_filled/NULLIF(p.batch_filled,0),2) AS partner_adoption_pct
FROM partner p FULL OUTER JOIN owner o ON o.m = p.m ORDER BY 1