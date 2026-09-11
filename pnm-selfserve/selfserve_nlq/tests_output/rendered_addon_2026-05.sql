SELECT
    DATE '2026-05-01' AS month,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ADD_ONS IS NOT NULL AND ADD_ONS != '' THEN ORDER_ID END)
        / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_any_addon,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN
        LOWER(ADD_ONS) LIKE '%single-layer packing%' OR LOWER(ADD_ONS) LIKE '%multi-layer packing%'
        THEN ORDER_ID END) / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_packing,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN
        LOWER(ADD_ONS) LIKE '%ac installation%' OR LOWER(ADD_ONS) LIKE '%ac uninstallation%'
        THEN ORDER_ID END) / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_ac,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN
        LOWER(ADD_ONS) LIKE '%professional carpenter%'
        OR LOWER(ADD_ONS) LIKE '%dismantling and reassembly%'
        OR LOWER(ADD_ONS) LIKE '%dismantelling and reassembly%'
        THEN ORDER_ID END) / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_carpentry,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN LOWER(ADD_ONS) LIKE '%rope pull%'
        THEN ORDER_ID END) / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_rope_pulling,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN LOWER(ADD_ONS) LIKE '%bigger vehicle%'
        THEN ORDER_ID END) / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_bigger_vehicle,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN LOWER(ADD_ONS) LIKE '%extra labour%'
        THEN ORDER_ID END) / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_extra_labour
FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
WHERE SHIFTING_TYPE = 'intra_city'
  AND DATE_TRUNC('month', TO_DATE(ORDER_CREATED_TS_IST)) = '2026-05-01'