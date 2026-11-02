WITH combined AS (
    SELECT * FROM prod_curated.partload_analytics.ptl_batch_level_app_sheet_old
    UNION ALL
    SELECT * FROM prod_curated.gsheet_sync."PTL_BATCH_APP_SHEET_DATA"
),
deduped AS (
    SELECT * FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY batch_id ORDER BY accepted_at DESC NULLS LAST) AS rn FROM combined) WHERE rn = 1
)
SELECT date_trunc('month', date(created_at + INTERVAL '330 mins'))::DATE AS date_,
    COUNT(DISTINCT batch_id) AS batches,
    COUNT(DISTINCT CASE WHEN accepted_by_email IS NOT NULL THEN batch_id END) AS accepted_batches,
    ROUND(100.0*COUNT(DISTINCT CASE WHEN accepted_by_email IS NOT NULL THEN batch_id END)/NULLIF(COUNT(DISTINCT batch_id),0),2) AS owner_adoption_pct
FROM deduped d
LEFT JOIN prod_curated.partload_application.batch_v1 bv1 ON bv1.id = batch_id
WHERE batch_status != 'CANCELLED'
  AND created_at + INTERVAL '330 mins' >= DATE '2026-01-01'
  AND created_at + INTERVAL '330 mins' <= DATE '2026-08-31' + INTERVAL '1 day'
GROUP BY 1 ORDER BY 1