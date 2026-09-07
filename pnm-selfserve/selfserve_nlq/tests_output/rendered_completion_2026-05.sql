WITH completion_base AS (
    SELECT order_id, vendor_id, order_status, classification
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
    WHERE package_name NOT ILIKE 'Nano%'
      AND shifting_type = 'intra_city'
      AND DATE_TRUNC('month', shifting_ts_ist) = '2026-05-01'
)
SELECT
    DATE '2026-05-01' AS month,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN vendor_id IS NOT NULL THEN order_id END), 0), 2) AS completion_score_pct,
    CASE
        WHEN COUNT(DISTINCT CASE WHEN order_status = 'completed' AND classification IS NOT NULL THEN order_id END) > 0
        THEN ROUND(
            100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' AND classification = 'Promoter' THEN order_id END)
                  / COUNT(DISTINCT CASE WHEN order_status = 'completed' AND classification IS NOT NULL THEN order_id END)
          - 100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' AND classification = 'Detractor' THEN order_id END)
                  / COUNT(DISTINCT CASE WHEN order_status = 'completed' AND classification IS NOT NULL THEN order_id END), 2)
        ELSE 0
    END AS nps,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' AND classification = 'Detractor' THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed' THEN order_id END), 0), 2) AS detractor_pct
FROM completion_base