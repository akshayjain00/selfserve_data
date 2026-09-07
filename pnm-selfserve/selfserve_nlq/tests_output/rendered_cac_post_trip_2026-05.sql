SELECT
    DATE '2026-05-01' AS month,
    ROUND(
        COUNT(DISTINCT CASE WHEN
            pe.TRIP_STARTED_TS_IST IS NOT NULL
            AND pe.ORDER_STATUS = 'cancelled'
            AND coe.CANCELLED_BY = 'Customer'
        THEN pe.ORDER_ID END) * 100.0
        / NULLIF(COUNT(DISTINCT pe.ORDER_ID), 0),
        2) AS cac_post_trip_started_pct
FROM PROD_ELDORIA.MART.PNM_EXPERIENCE pe
LEFT JOIN PROD_CURATED.PNM_APPLICATION.CANCELLED_ORDER_EVENTS coe
    ON coe.order_id = pe.order_id
WHERE pe.SHIFTING_TYPE = 'intra_city'
  AND pe.PACKAGE_NAME NOT ILIKE '%Nano%'
  AND DATE_TRUNC('month', pe.SHIFTING_TS_IST) = '2026-05-01'