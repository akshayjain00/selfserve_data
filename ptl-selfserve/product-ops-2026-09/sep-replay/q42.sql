WITH payouts AS (
      SELECT DATE_TRUNC('month', b.created_at + INTERVAL '330 mins')::DATE AS period, b.id AS batch_id,
             TRY_TO_DECIMAL(v.total_vendor_pay,38,4) AS total_vendor_pay
      FROM prod_curated.partload_application.batch_v1 b
      INNER JOIN prod_curated.partload_analytics.vendor_payout_batch_level v ON v.batch_id = b.id
      WHERE DATE(b.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-01-01' AND DATE '2026-09-30'
),
mav AS (
      SELECT DATE_TRUNC('month', ov.created_at + INTERVAL '330 mins')::DATE AS period,
             COUNT(DISTINCT REGEXP_REPLACE(UPPER(TRIM(ov.vehicle_registration_number)),'[^A-Z0-9]','')) AS mav
      FROM prod_curated.partload_application.order_vehicles ov
      WHERE ov.vehicle_registration_number IS NOT NULL AND ov.is_active = TRUE
        AND DATE(ov.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-01-01' AND DATE '2026-09-30'
      GROUP BY 1
),
pay_by_period AS (SELECT period, COUNT(DISTINCT batch_id) AS trips, SUM(total_vendor_pay) AS pay FROM payouts GROUP BY 1)
SELECT m.period, p.trips, ROUND(p.pay,0) AS total_vendor_pay, m.mav,
       ROUND(p.pay/NULLIF(m.mav,0),0) AS owner_earning_per_mav
FROM mav m LEFT JOIN pay_by_period p ON m.period = p.period ORDER BY 1