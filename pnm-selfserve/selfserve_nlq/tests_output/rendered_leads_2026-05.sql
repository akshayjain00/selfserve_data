WITH leads_base AS (
    SELECT
        f.opp_id,
        CASE
            WHEN d.source_details = 'Desktop Website' THEN 'Desktop Website'
            WHEN d.source_details = 'Mobile Website'  THEN 'Mobile Website'
            WHEN d.source IN (1, 2, 3)                 THEN 'App'
            WHEN d.source = 4                           THEN 'Others'
            ELSE 'Mobile Website'
        END AS channel
    FROM PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY f
    LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY d ON d.opp_id = f.opp_id
    WHERE d.user_flag ILIKE 'normal'
      AND DATE_TRUNC('month', f.opp_created_ts) = '2026-05-01'
      AND (d.shifting_type = 'intra_city' OR d.shifting_type IS NULL)
)
SELECT
    DATE '2026-05-01'                                                AS month,
    COUNT(DISTINCT opp_id)                                              AS leads_overall,
    COUNT(DISTINCT CASE WHEN channel = 'App'             THEN opp_id END) AS leads_app,
    COUNT(DISTINCT CASE WHEN channel = 'Desktop Website' THEN opp_id END) AS leads_desktop,
    COUNT(DISTINCT CASE WHEN channel = 'Mobile Website'  THEN opp_id END) AS leads_mobile,
    COUNT(DISTINCT CASE WHEN channel = 'Others'          THEN opp_id END) AS leads_others
FROM leads_base