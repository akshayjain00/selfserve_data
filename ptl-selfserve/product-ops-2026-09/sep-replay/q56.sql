WITH vehicle_onboarding AS (
    SELECT REGEXP_REPLACE(UPPER(TRIM(registration_number)),'[^A-Z0-9]','') AS reg_no, MIN(created_at + INTERVAL '330 mins') AS onboarding_ts
    FROM PROD_CURATED.PARTLOAD_APPLICATION.VEHICLES WHERE registration_number IS NOT NULL GROUP BY 1
),
latest_vendor_map AS (
    SELECT REGEXP_REPLACE(UPPER(TRIM(vehicle_registration_number)),'[^A-Z0-9]','') AS reg_no, TRIM(mobile_number) AS vendor_mobile
    FROM PROD_CURATED.GSHEET_SYNC.PTL_VENDOR_VEHICLE_MAP
    WHERE vehicle_registration_number IS NOT NULL AND NULLIF(TRIM(mobile_number),'') IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY REGEXP_REPLACE(UPPER(TRIM(vehicle_registration_number)),'[^A-Z0-9]','')
                               ORDER BY TRY_TO_DATE(date,'MM/DD/YYYY') DESC NULLS LAST) = 1
),
owner_onboarding AS (
    SELECT m.vendor_mobile, MIN(v.onboarding_ts) AS owner_onboarding_ts
    FROM latest_vendor_map m INNER JOIN vehicle_onboarding v ON v.reg_no = m.reg_no GROUP BY 1
),
completed_trips AS (
    SELECT bo.batch_id, REGEXP_REPLACE(UPPER(TRIM(ov.vehicle_registration_number)),'[^A-Z0-9]','') AS reg_no,
           MAX(CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(o.created_at))) AS completed_trip_ts
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS o
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES ov ON o.external_id = ov.order_external_id AND ov.is_active = TRUE
    LEFT JOIN (SELECT * FROM PROD_CURATED.PARTLOAD_APPLICATION.batched_orders_v1
               QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) = 1) bo ON bo.order_id = o.id
    LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.ptl_internal_users iu ON iu.mobile = o.customer_mobile
    WHERE iu.mobile IS NULL AND o.state = 3 AND bo.batch_id IS NOT NULL AND ov.vehicle_registration_number IS NOT NULL
    GROUP BY 1,2
),
owner_first_trip AS (
    SELECT m.vendor_mobile, MIN(c.completed_trip_ts) AS first_completed_trip_ts
    FROM completed_trips c INNER JOIN latest_vendor_map m ON c.reg_no = m.reg_no GROUP BY 1
),
owner_activation AS (
    SELECT o.vendor_mobile, o.owner_onboarding_ts,
        CASE WHEN f.first_completed_trip_ts IS NOT NULL AND f.first_completed_trip_ts >= o.owner_onboarding_ts
              AND f.first_completed_trip_ts <= o.owner_onboarding_ts + INTERVAL '30 days' THEN 1 ELSE 0 END AS activated
    FROM owner_onboarding o LEFT JOIN owner_first_trip f ON o.vendor_mobile = f.vendor_mobile
)
SELECT DATE_TRUNC('month', owner_onboarding_ts)::DATE AS onboarded_period, COUNT(*) AS new_owners,
       COUNT(CASE WHEN activated = 1 THEN 1 END) AS activated_owners,
       ROUND(100.0*COUNT(CASE WHEN activated=1 THEN 1 END)/NULLIF(COUNT(*),0),2) AS activation_rate_pct
FROM owner_activation
WHERE DATE(owner_onboarding_ts) >= DATE '2026-01-01' AND DATE(owner_onboarding_ts) <= DATE '2026-09-30'
GROUP BY 1 ORDER BY 1