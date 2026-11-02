WITH latest_vendor_map AS (
      SELECT REGEXP_REPLACE(UPPER(TRIM(vehicle_registration_number)),'[^A-Z0-9]','') AS reg_no, TRIM(mobile_number) AS owner_mobile
      FROM PROD_CURATED.GSHEET_SYNC.PTL_VENDOR_VEHICLE_MAP
      WHERE vehicle_registration_number IS NOT NULL AND NULLIF(TRIM(mobile_number),'') IS NOT NULL
      QUALIFY ROW_NUMBER() OVER (PARTITION BY REGEXP_REPLACE(UPPER(TRIM(vehicle_registration_number)),'[^A-Z0-9]','')
                                 ORDER BY TRY_TO_DATE(date,'MM/DD/YYYY') DESC NULLS LAST) = 1
),
owner_activity AS (
      SELECT DISTINCT DATE_TRUNC('month', ov.created_at + INTERVAL '330 mins') AS active_month, vm.owner_mobile
      FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES ov
      INNER JOIN latest_vendor_map vm ON REGEXP_REPLACE(UPPER(TRIM(ov.vehicle_registration_number)),'[^A-Z0-9]','') = vm.reg_no
      WHERE ov.vehicle_registration_number IS NOT NULL AND ov.is_active = TRUE
),
m1 AS (
      SELECT c.active_month AS cohort_month, c.owner_mobile,
             CASE WHEN n.owner_mobile IS NOT NULL THEN 1 ELSE 0 END AS retained_m1
      FROM owner_activity c
      LEFT JOIN owner_activity n ON n.owner_mobile = c.owner_mobile AND n.active_month = DATEADD(month, 1, c.cohort_month)
)
SELECT cohort_month::DATE AS cohort_month, COUNT(DISTINCT owner_mobile) AS cohort_owners,
       COUNT(DISTINCT CASE WHEN retained_m1=1 THEN owner_mobile END) AS retained_m1,
       ROUND(100.0*COUNT(DISTINCT CASE WHEN retained_m1=1 THEN owner_mobile END)/NULLIF(COUNT(DISTINCT owner_mobile),0),2) AS m1_retention_pct
FROM m1 WHERE cohort_month >= DATE '2026-01-01' GROUP BY 1 ORDER BY 1