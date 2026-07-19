WITH base AS (
    SELECT
        COUNT(DISTINCT pe.ORDER_ID)                                                    AS total_orders,
        COUNT(DISTINCT CASE WHEN pe.IS_MODIFICATION_DONE = 'Yes' THEN pe.ORDER_ID END) AS orders_with_mods,
        SUM(pe.NO_OF_SUCCESSFUL_EDITS)                                                 AS no_of_successful_edits,
        SUM(pe.EDITS_AFTER_SHIFTING)                                                   AS edits_after_shifting,
        COUNT(DISTINCT CASE WHEN pe.HAS_SUPPORT_EDIT  = 1 THEN pe.ORDER_ID END)        AS support_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_LOCATION_EDIT = 1 THEN pe.ORDER_ID END)        AS location_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_ITEMS_EDIT    = 1 THEN pe.ORDER_ID END)        AS items_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_ADDONS_EDIT   = 1 THEN pe.ORDER_ID END)        AS addons_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_SLOT_EDIT     = 1 THEN pe.ORDER_ID END)        AS slot_edited_orders
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE pe
    WHERE pe.ORDER_CREATED_TS_IST >= '2026-05-01'
      AND pe.ORDER_CREATED_TS_IST <  DATEADD('month', 1, DATE '2026-05-01')
      AND pe.ORDER_STATUS = 'completed'
      AND pe.SHIFTING_TYPE = 'intra_city'
      AND pe.PACKAGE_NAME NOT ILIKE 'Nano%'
)
SELECT
    DATE '2026-05-01' AS month,
    ROUND(100.0 * orders_with_mods       / NULLIF(total_orders, 0), 2)           AS pct_orders_edited,
    no_of_successful_edits,
    ROUND(100.0 * support_edited_orders  / NULLIF(total_orders, 0), 2)           AS pct_support_edited_orders,
    ROUND(100.0 * location_edited_orders / NULLIF(total_orders, 0), 2)           AS location_adoption_pct,
    ROUND(100.0 * location_edited_orders / NULLIF(total_orders, 0), 2)           AS pct_orders_location_modified,
    ROUND(100.0 * items_edited_orders    / NULLIF(total_orders, 0), 2)           AS items_adoption_pct,
    ROUND(100.0 * addons_edited_orders   / NULLIF(total_orders, 0), 2)           AS addons_adoption_pct,
    ROUND(100.0 * slot_edited_orders     / NULLIF(total_orders, 0), 2)           AS slot_adoption_pct,
    ROUND(no_of_successful_edits * 1.0   / NULLIF(total_orders, 0), 2)           AS edits_per_order,
    ROUND(100.0 * edits_after_shifting   / NULLIF(no_of_successful_edits, 0), 2) AS pct_edits_after_shifting_started
FROM base