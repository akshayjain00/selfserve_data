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
),
orders_base_raw AS (
    SELECT
        o.order_id,
        CASE
            WHEN d.source_details = 'Desktop Website' THEN 'Desktop Website'
            WHEN d.source_details = 'Mobile Website'  THEN 'Mobile Website'
            WHEN d.source IN (1, 2, 3)                 THEN 'App'
            WHEN d.source = 4                           THEN 'Others'
            ELSE 'Mobile Website'
        END AS channel
    FROM PROD_ELDORIA.CORE.FACT_PNM_ORDERS o
    INNER JOIN PROD_ELDORIA.MART.PNM_CUSTOMERS       pc  ON pc.customer_mobile = o.customer_mobile
    LEFT  JOIN PROD_ELDORIA.CORE.DIM_PNM_ORDERS      dord ON dord.order_id = o.order_id
    LEFT  JOIN PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY fpo ON fpo.sr_id = o.sr_id
    LEFT  JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY  d   ON d.opp_id = fpo.opp_id
    WHERE dord.user_flag ILIKE 'normal'
      AND DATE_TRUNC('month', o.o_created_ts) = '2026-05-01'
      AND dord.shifting_type = 'intra_city'
      AND o.crn LIKE '%PNM%'
      AND (dord.package_name NOT ILIKE 'Nano%' OR dord.package_name IS NULL)
    QUALIFY ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY fpo.opp_id DESC NULLS LAST) = 1
),
leads_monthly AS (
SELECT
    DATE '2026-05-01'                                                AS month,
    COUNT(DISTINCT opp_id)                                              AS leads_overall,
    COUNT(DISTINCT CASE WHEN channel = 'App'             THEN opp_id END) AS leads_app,
    COUNT(DISTINCT CASE WHEN channel = 'Desktop Website' THEN opp_id END) AS leads_desktop,
    COUNT(DISTINCT CASE WHEN channel = 'Mobile Website'  THEN opp_id END) AS leads_mobile,
    COUNT(DISTINCT CASE WHEN channel = 'Others'          THEN opp_id END) AS leads_others
FROM leads_base
),
orders_monthly AS (
SELECT
    DATE '2026-05-01'                                                    AS month,
    COUNT(DISTINCT order_id)                                                AS orders_overall,
    COUNT(DISTINCT CASE WHEN channel = 'App'             THEN order_id END) AS orders_app,
    COUNT(DISTINCT CASE WHEN channel = 'Desktop Website' THEN order_id END) AS orders_desktop,
    COUNT(DISTINCT CASE WHEN channel = 'Mobile Website'  THEN order_id END) AS orders_mobile,
    COUNT(DISTINCT CASE WHEN channel = 'Others'          THEN order_id END) AS orders_others
FROM orders_base_raw
)
SELECT
    l.month,
    l.leads_overall, l.leads_app, l.leads_desktop, l.leads_mobile, l.leads_others,
    o.orders_overall, o.orders_app, o.orders_desktop, o.orders_mobile, o.orders_others
FROM leads_monthly l
CROSS JOIN orders_monthly o