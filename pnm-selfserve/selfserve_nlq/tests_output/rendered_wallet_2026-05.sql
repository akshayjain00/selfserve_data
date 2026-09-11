WITH wallet_withdrawals AS (
    SELECT
        ROUND(COUNT(DISTINCT CASE WHEN w.STATUS = 'Failure' THEN w.ID END) * 100.0
            / NULLIF(COUNT(DISTINCT w.ID), 0), 2) AS withdrawal_failure_pct,
        ROUND(COUNT(DISTINCT w.ID) / NULLIF(COUNT(DISTINCT w.VENDOR_OWNER_ID), 0), 2) AS withdrawals_per_vendor,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY w.AMOUNT) AS p50_withdrawal_amount
    FROM PROD_CURATED.PNM_APPLICATION.VENDOR_OWNERS v
    JOIN PROD_CURATED.PNM_APPLICATION.VENDOR_WALLET_WITHDRAWAL w
        ON v.ID = w.VENDOR_OWNER_ID
    WHERE v.vendor_id IN (SELECT DISTINCT vendor_id FROM PROD_ELDORIA.CORE.DIM_PNM_VENDOR)
      AND DATE_TRUNC('month', w.CREATED_AT) = '2026-05-01'
      AND EXISTS (
        SELECT 1
        FROM PROD_CURATED.PNM_APPLICATION.VENDOR_ALLOCATION_CONFIGS vac
        WHERE vac.VENDOR_ID = v.ID
          AND NOT ARRAY_CONTAINS('Labour'::VARIANT, vac.SERVICE_TYPES)
          AND NOT ARRAY_CONTAINS('Helper'::VARIANT, vac.SERVICE_TYPES)
          AND NOT ARRAY_CONTAINS(34::VARIANT, vac.EXCLUDED_PACKAGE_IDS)
          AND NOT ARRAY_CONTAINS(35::VARIANT, vac.EXCLUDED_PACKAGE_IDS)
          AND NOT ARRAY_CONTAINS(36::VARIANT, vac.EXCLUDED_PACKAGE_IDS)
      )
),
wallet_recharges AS (
    SELECT
        ROUND(COUNT(DISTINCT CASE WHEN p.STATUS = 2 THEN p.ID END) * 100.0
            / NULLIF(COUNT(DISTINCT p.ID), 0), 2) AS recharge_failure_pct,
        ROUND(COUNT(DISTINCT p.ID) / NULLIF(COUNT(DISTINCT p.VENDOR_OWNER_ID), 0), 2) AS recharges_per_vendor,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.AMOUNT) AS p50_recharge_amount
    FROM PROD_CURATED.PNM_APPLICATION.VENDOR_OWNERS v
    JOIN PROD_CURATED.PNM_APPLICATION.PAYMENT_LINKS p
        ON v.ID = p.VENDOR_OWNER_ID
    WHERE p.flow = 'VendorWalletRecharge'
      AND DATE_TRUNC('month', p.created_at) = '2026-05-01'
)
SELECT
    DATE '2026-05-01' AS month,
    w.withdrawals_per_vendor, w.p50_withdrawal_amount, w.withdrawal_failure_pct,
    r.recharges_per_vendor, r.p50_recharge_amount, r.recharge_failure_pct
FROM wallet_withdrawals w
CROSS JOIN wallet_recharges r