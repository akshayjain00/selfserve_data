WITH params AS (SELECT DATE '2026-01-01' AS start_date, DATE '2026-08-31' AS end_date),
orders_base AS (
    SELECT o.customer_mobile,
           CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(o.created_at))::DATE AS order_date
    FROM prod_curated.partload_application.orders o
    LEFT JOIN prod_curated.oms_public.customers c ON c.mobile = o.customer_mobile
    LEFT JOIN prod_curated.partload_analytics.ptl_internal_users iu ON iu.mobile = o.customer_mobile
    CROSS JOIN params p
    WHERE o.customer_mobile IS NOT NULL AND iu.mobile IS NULL AND o.state = 3
      AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(o.created_at))::DATE <= p.end_date
      AND CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = 'Business'
),
months AS (
    SELECT DATEADD(month, SEQ4(), DATE_TRUNC('month', p.start_date))::DATE AS period_start,
           LAST_DAY(DATEADD(month, SEQ4(), DATE_TRUNC('month', p.start_date)))::DATE AS period_end
    FROM params p, TABLE(GENERATOR(ROWCOUNT => 60))
    WHERE DATEADD(month, SEQ4(), DATE_TRUNC('month', p.start_date)) <= DATE_TRUNC('month', p.end_date)
),
customer_last_completed_before_period AS (
    SELECT m.period_start, m.period_end, ob.customer_mobile, MAX(ob.order_date) AS last_completed_date
    FROM months m JOIN orders_base ob ON ob.order_date < m.period_start GROUP BY 1,2,3
),
inactive_base AS (
    SELECT period_start, period_end, customer_mobile FROM customer_last_completed_before_period
    WHERE DATEDIFF(day, last_completed_date, period_start) >= 60
),
reactivated AS (
    SELECT DISTINCT ib.period_start, ib.customer_mobile
    FROM inactive_base ib JOIN orders_base ob ON ob.customer_mobile = ib.customer_mobile
     AND ob.order_date BETWEEN ib.period_start AND ib.period_end
)
SELECT ib.period_start AS month,
       COUNT(DISTINCT ib.customer_mobile) AS inactive_60d_base,
       COUNT(DISTINCT r.customer_mobile) AS reactivated,
       ROUND(100.0*COUNT(DISTINCT r.customer_mobile)/NULLIF(COUNT(DISTINCT ib.customer_mobile),0), 2) AS reactivation_pct
FROM inactive_base ib LEFT JOIN reactivated r ON ib.period_start = r.period_start AND ib.customer_mobile = r.customer_mobile
GROUP BY 1 ORDER BY 1