-- card 43406 Aggregate M1 Retention - Business, broken out per cohort (supplement; Metabase card itself ran fine)
-- Purpose: get Jul-2026 cohort M1 (retention activity in Aug) for MoM. Card logic unchanged except final SELECT is per cohort.
-- params: frequency='Month', start_date=2026-07-01, end_date=2026-08-31 (two-month window, mirroring the Aug1-Sep30 run used for the Sep value)
-- Mobile joins kept as-is: Snowflake MCP role sees orders/customers/internal_users mobiles unmasked for this period.
WITH online_filtered_orders AS (
    SELECT orders.customer_mobile as customer_mobile, DATE_TRUNC('Month', orders.created_At + INTERVAL '5 HOUR, 30 MINUTE') AS order_month
    FROM prod_curated.PARTLOAD_APPLICATION.orders
    LEFT JOIN prod_curated.oms_public.customers c ON orders.customer_mobile = c.mobile
    WHERE date(orders.created_At + INTERVAL '5 HOUR, 30 MINUTE') >= '2026-07-01'
      AND date(orders.created_At + INTERVAL '5 HOUR, 30 MINUTE') <= '2026-08-31'
      AND CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = 'Business'
      AND state = '3'
      AND customer_mobile NOT IN (SELECT MOBILE FROM prod_curated.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)
),
offline_filtered_orders AS (
    SELECT customer_mobile, CAST(DATE_TRUNC('Month', ofo.created_at::date) AS DATE) AS order_month
    FROM prod_curated.gsheet_sync.ptl_offline_orders ofo
    LEFT JOIN prod_curated.oms_public.customers c ON ofo.customer_mobile = c.mobile
    WHERE state = 3 AND ofo.created_at::date >= '2026-07-01' AND ofo.created_at::date <= '2026-08-31'
      AND CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = 'Business'
),
base_orders AS (SELECT * FROM online_filtered_orders UNION SELECT * FROM offline_filtered_orders),
first_orders AS (SELECT customer_mobile, MIN(order_month) AS first_order_month FROM base_orders GROUP BY customer_mobile)
SELECT f.first_order_month AS cohort_month,
       COUNT(DISTINCT f.customer_mobile) AS cohort_size,
       COUNT(DISTINCT CASE WHEN DATEDIFF('Month', f.first_order_month, o.order_month) = 1 THEN o.customer_mobile END) AS retained_m1,
       ROUND(retained_m1 / cohort_size, 3) AS m1_pct
FROM first_orders f JOIN base_orders o ON f.customer_mobile = o.customer_mobile
GROUP BY 1 ORDER BY 1;
