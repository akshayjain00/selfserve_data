WITH vendor_earnings_order_base AS (
    SELECT
        order_id, vendor_id,
        COALESCE(vendor_bucket_type, 'New') AS bucket,
        order_completed_ts_ist, total_order_fare
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
    WHERE order_status = 'completed'
      AND package_name NOT ILIKE 'Nano%'
      AND shifting_type = 'intra_city'
      AND DATE_TRUNC('month', order_completed_ts_ist) = '2026-05-01'
),
vendor_earnings_period_bucket AS (
    SELECT vendor_id, bucket
    FROM (
        SELECT vendor_id, bucket,
            ROW_NUMBER() OVER (PARTITION BY vendor_id ORDER BY order_completed_ts_ist DESC, order_id DESC) AS rn
        FROM vendor_earnings_order_base
    ) ranked
    WHERE rn = 1
),
vendor_earnings_effective_bucket AS (
    SELECT vpb.bucket, pob.order_id, pob.total_order_fare
    FROM vendor_earnings_order_base pob
    INNER JOIN vendor_earnings_period_bucket vpb ON pob.vendor_id = vpb.vendor_id
),
vendor_earnings_bucket_totals AS (
    SELECT bucket, SUM(total_order_fare) AS total_revenue
    FROM vendor_earnings_effective_bucket
    GROUP BY 1
),
vendor_earnings_bucket_pct AS (
    SELECT bucket,
        ROUND(total_revenue * 100.0 / NULLIF(SUM(total_revenue) OVER (), 0), 2) AS revenue_pct
    FROM vendor_earnings_bucket_totals
)
SELECT
    DATE '2026-05-01' AS month,
    MAX(CASE WHEN bucket = 'GoldPlus' THEN revenue_pct END) AS revenue_pct_goldplus,
    MAX(CASE WHEN bucket = 'Gold' THEN revenue_pct END) AS revenue_pct_gold,
    MAX(CASE WHEN bucket = 'Silver' THEN revenue_pct END) AS revenue_pct_silver,
    MAX(CASE WHEN bucket = 'Bronze' THEN revenue_pct END) AS revenue_pct_bronze,
    MAX(CASE WHEN bucket = 'New' THEN revenue_pct END) AS revenue_pct_new
FROM vendor_earnings_bucket_pct