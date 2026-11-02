WITH vehicle_onboarding AS (
    SELECT REGEXP_REPLACE(UPPER(TRIM(registration_number)),'[^A-Z0-9]','') AS reg_no,
           MIN(created_at + INTERVAL '330 mins') AS onboarding_ts
    FROM PROD_CURATED.PARTLOAD_APPLICATION.VEHICLES WHERE registration_number IS NOT NULL GROUP BY 1
),
latest_vendor_map AS (
    SELECT REGEXP_REPLACE(UPPER(TRIM(vehicle_registration_number)),'[^A-Z0-9]','') AS reg_no,
           TRIM(mobile_number) AS vendor_mobile
    FROM PROD_CURATED.GSHEET_SYNC.PTL_VENDOR_VEHICLE_MAP
    WHERE vehicle_registration_number IS NOT NULL AND NULLIF(TRIM(mobile_number),'') IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY REGEXP_REPLACE(UPPER(TRIM(vehicle_registration_number)),'[^A-Z0-9]','')
                               ORDER BY TRY_TO_DATE(date,'MM/DD/YYYY') DESC NULLS LAST) = 1
),
owner_onboarding AS (
    SELECT m.vendor_mobile, MIN(v.onboarding_ts) AS owner_onboarding_ts
    FROM latest_vendor_map m INNER JOIN vehicle_onboarding v ON v.reg_no = m.reg_no GROUP BY 1
),
new_owners AS (
    SELECT DATE_TRUNC('month', owner_onboarding_ts)::DATE AS period, COUNT(*)::FLOAT AS val
    FROM owner_onboarding WHERE DATE(owner_onboarding_ts) BETWEEN DATE '2026-01-01' AND DATE '2026-08-31' GROUP BY 1
),
new_vehicles AS (
    SELECT DATE_TRUNC('month', onboarding_ts)::DATE AS period, COUNT(DISTINCT reg_no)::FLOAT AS val
    FROM vehicle_onboarding WHERE DATE(onboarding_ts) BETWEEN DATE '2026-01-01' AND DATE '2026-08-31' GROUP BY 1
),
mao AS (
    SELECT DATE_TRUNC('month', ov.created_at + INTERVAL '330 mins')::DATE AS period,
           COUNT(DISTINCT vm.vendor_mobile)::FLOAT AS val
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES ov
    INNER JOIN latest_vendor_map vm ON REGEXP_REPLACE(UPPER(TRIM(ov.vehicle_registration_number)),'[^A-Z0-9]','') = vm.reg_no
    WHERE ov.vehicle_registration_number IS NOT NULL AND ov.is_active = TRUE
      AND DATE(ov.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-01-01' AND DATE '2026-08-31'
    GROUP BY 1
),
mav AS (
    SELECT DATE_TRUNC('month', ov.created_at + INTERVAL '330 mins')::DATE AS period,
           COUNT(DISTINCT ov.vehicle_registration_number)::FLOAT AS val
    FROM prod_curated.partload_application.order_vehicles ov
    LEFT JOIN prod_curated.partload_application.orders o ON o.external_id = ov.order_external_id
    LEFT JOIN prod_curated.partload_analytics.ptl_internal_users iu ON iu.mobile = o.customer_mobile
    WHERE ov.vehicle_registration_number IS NOT NULL AND ov.is_active = TRUE AND iu.mobile IS NULL
      AND DATE(ov.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-01-01' AND DATE '2026-08-31'
    GROUP BY 1
),
tpv_base AS (
    SELECT DATE_TRUNC('month', orders.created_at + INTERVAL '330 mins')::DATE AS period,
           bo.batch_id, ov.vehicle_registration_number
    FROM prod_curated.partload_application.orders orders
    LEFT JOIN (SELECT * FROM prod_curated.partload_application.batched_orders_v1
               QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) = 1) bo ON bo.order_id = orders.id
    LEFT JOIN prod_curated.partload_application.order_vehicles ov
           ON orders.external_id = ov.order_external_id AND ov.is_active = TRUE
    LEFT JOIN prod_curated.partload_analytics.ptl_internal_users iu ON iu.mobile = orders.customer_mobile
    WHERE ov.vehicle_registration_number IS NOT NULL AND bo.batch_id IS NOT NULL AND iu.mobile IS NULL
      AND DATE(orders.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-01-01' AND DATE '2026-08-31'
),
trips_per_mav AS (
    SELECT period, ROUND(COUNT(DISTINCT batch_id)::FLOAT/NULLIF(COUNT(DISTINCT vehicle_registration_number),0),2) AS val
    FROM tpv_base GROUP BY 1
),
earn_base AS (
    SELECT DATE_TRUNC('month', b.created_at + INTERVAL '330 mins')::DATE AS period, b.id AS batch_id,
           TRY_TO_DECIMAL(v.total_vendor_pay,38,4) AS total_vendor_pay
    FROM prod_curated.partload_application.batch_v1 b
    JOIN prod_curated.partload_analytics.vendor_payout_batch_level v ON v.batch_id = b.id
    WHERE DATE(b.created_at + INTERVAL '330 mins') BETWEEN DATE '2026-01-01' AND DATE '2026-08-31'
),
earn_per_trip AS (
    SELECT period, ROUND(SUM(total_vendor_pay)/NULLIF(COUNT(DISTINCT batch_id),0),0)::FLOAT AS val
    FROM earn_base GROUP BY 1
)
SELECT 'new_owners' AS metric, period, val FROM new_owners
UNION ALL SELECT 'new_vehicles', period, val FROM new_vehicles
UNION ALL SELECT 'monthly_active_owners', period, val FROM mao
UNION ALL SELECT 'monthly_active_vehicles', period, val FROM mav
UNION ALL SELECT 'trips_per_mav', period, val FROM trips_per_mav
UNION ALL SELECT 'earnings_per_trip', period, val FROM earn_per_trip
ORDER BY metric, period