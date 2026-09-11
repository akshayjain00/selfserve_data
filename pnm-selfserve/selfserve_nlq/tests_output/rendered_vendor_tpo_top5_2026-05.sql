WITH tpo_orders AS (
    SELECT
        DATE_TRUNC('month', DATE(b.completed_ts_ist)) AS period,
        COUNT(DISTINCT a.crn) AS completed_orders
    FROM PROD_ELDORIA.RAW.PNM_APPLICATION_ORDERS a
    JOIN PROD_ELDORIA.RAW.PNM_APPLICATION_ORDER_ALLOCATION_INFOS b
        ON a.id = b.order_id AND b.is_active = true
    LEFT JOIN PROD_ELDORIA.RAW.PNM_APPLICATION_SHIFTING_REQUIREMENTS c
        ON a.sr_id = c.id
    WHERE a.crn LIKE '%PNM%'
      AND c.package_name NOT ILIKE '%Nano%'
      AND c.shifting_type = 'intra_city'
      AND DATE_TRUNC('month', DATE(b.completed_ts_ist)) = '2026-05-01'
    GROUP BY 1
),
tpo_tkt_all AS (
    SELECT
        DATE_TRUNC('month', DATE(hst.created_at + interval '5 hours, 30 minutes')) AS period,
        COUNT(DISTINCT hst.ticket_number) AS tickets
    FROM PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS hst
    LEFT JOIN PROD_ELDORIA.RAW.PNM_APPLICATION_ORDERS a ON hst.crn = a.crn
    LEFT JOIN PROD_ELDORIA.RAW.PNM_APPLICATION_SHIFTING_REQUIREMENTS c ON a.sr_id = c.id
    WHERE hst.crn LIKE '%PNM%'
      AND c.package_name NOT ILIKE '%Nano%'
      AND COALESCE(hst.raised_by, '') != 'Detractor'
      AND hst.issue IS NOT NULL
      AND c.shifting_type = 'intra_city'
      AND DATE_TRUNC('month', DATE(hst.created_at + interval '5 hours, 30 minutes')) = '2026-05-01'
    GROUP BY 1
),
tpo_tkt_filtered AS (
    SELECT
        DATE_TRUNC('month', DATE(hst.created_at + interval '5 hours, 30 minutes')) AS period,
        hst.issue,
        COUNT(DISTINCT hst.ticket_number) AS tickets
    FROM PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS hst
    LEFT JOIN PROD_ELDORIA.RAW.PNM_APPLICATION_ORDERS a ON hst.crn = a.crn
    LEFT JOIN PROD_ELDORIA.RAW.PNM_APPLICATION_SHIFTING_REQUIREMENTS c ON a.sr_id = c.id
    WHERE hst.crn LIKE '%PNM%'
      AND c.package_name NOT ILIKE '%Nano%'
      AND COALESCE(hst.raised_by, '') != 'Detractor'
      AND hst.issue IS NOT NULL
      AND hst.raised_by IN ('Vendor-Owner', 'Vendor-Supervisor')
      AND c.shifting_type = 'intra_city'
      AND DATE_TRUNC('month', DATE(hst.created_at + interval '5 hours, 30 minutes')) = '2026-05-01'
    GROUP BY 1, 2
),
tpo_total_all AS (
    SELECT ta.period, SUM(ta.tickets) / NULLIF(MAX(o.completed_orders), 0) AS total_tpo_overall
    FROM tpo_tkt_all ta JOIN tpo_orders o ON ta.period = o.period
    GROUP BY 1
),
tpo_total_filtered AS (
    SELECT tf.period, SUM(tf.tickets) / NULLIF(MAX(o.completed_orders), 0) AS vendor_tpo
    FROM tpo_tkt_filtered tf JOIN tpo_orders o ON tf.period = o.period
    GROUP BY 1
)
SELECT DATE '2026-05-01' AS month, 'vendor_tpo' AS metric, ROUND(vendor_tpo, 4) AS value
FROM tpo_total_filtered
UNION ALL
SELECT
    DATE '2026-05-01' AS month,
    'l1_top5_issues_vendor_raised_' || REPLACE(LOWER(tf.issue), ' ', '_') AS metric,
    ROUND((tf.tickets / NULLIF(o.completed_orders, 0)) / NULLIF(tta.total_tpo_overall, 0) * 100, 2) AS value
FROM tpo_tkt_filtered tf
JOIN tpo_orders o ON tf.period = o.period
JOIN tpo_total_all tta ON tf.period = tta.period
WHERE tf.issue IN (
    'Changes in order requirement', 'Supervisor Reject order', 'Cancellation',
    'Customer Unreachable', 'Payment related'
)