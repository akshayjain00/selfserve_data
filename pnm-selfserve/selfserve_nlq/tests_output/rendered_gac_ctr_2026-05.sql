SELECT
    DATE '2026-05-01' AS month,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN olls.opportunity_id IS NOT NULL THEN opp.id END)
        / NULLIF(COUNT(DISTINCT opp.id), 0),
        2
    ) AS gac_ctr_pct
FROM PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES opp
LEFT JOIN PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES_LATEST_LSM_SCORE olls
    ON opp.id = olls.opportunity_id
    AND olls.opportunity_latest_score = 999
WHERE opp.shifting_type = 'intra_city'
  AND DATE_TRUNC('month', DATE(opp.created_at + INTERVAL '5 hours, 30 minutes')) = '2026-05-01'