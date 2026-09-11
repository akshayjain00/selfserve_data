WITH weekend_base AS (
    SELECT
        pe.order_id,
        pe.shifting_ts_ist,
        CASE WHEN DAYOFWEEK(pe.shifting_ts_ist) IN (0,6) THEN 'Weekend' ELSE 'Weekday' END AS day_type
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE pe
    JOIN PROD_ELDORIA.CORE.FACT_PNM_ORDERS fpo ON pe.order_id = fpo.order_id
    WHERE pe.vendor_id IS NOT NULL
      AND fpo.crn ILIKE 'PNM%'
      AND pe.package_name NOT ILIKE 'nano%'
      AND DATE_TRUNC('month', pe.shifting_ts_ist) = '2026-05-01'
)
SELECT
    DATE '2026-05-01' AS month,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN day_type = 'Weekend' THEN order_id END)
        / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS weekend_order_share_pct
FROM weekend_base