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
)
SELECT
    DATE_TRUNC('month', opp_created_ts)                                          AS month,
    COUNT(DISTINCT opp_id)                                                       AS leads_overall,
    COUNT(DISTINCT CASE WHEN source IN (1,2,3)                  THEN opp_id END) AS leads_app,
    COUNT(DISTINCT CASE WHEN source_details = 'Desktop Website' THEN opp_id END) AS leads_desktop,
    COUNT(DISTINCT CASE WHEN source_details = 'Mobile Website'  THEN opp_id END) AS leads_mobile,
    COUNT(DISTINCT CASE WHEN source = 4                         THEN opp_id END) AS leads_others
FROM leads_base
GROUP BY 1
ORDER BY 1