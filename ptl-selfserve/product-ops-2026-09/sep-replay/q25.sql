WITH vehicles_loaded AS (
    SELECT DATE_TRUNC('month', t.EVENT_TIMESTAMP + INTERVAL '330 mins') AS month,
           COUNT(DISTINCT t.APP_SESSION_ID) AS vl
    FROM prod_curated.partload_analytics.ptl_fe_events t
    CROSS JOIN LATERAL FLATTEN(INPUT => TRY_PARSE_JSON(TRY_PARSE_JSON(t.variable_attr):vehicle_ids_seq)) f
    WHERE f.value::NUMBER IN (-1, 1159) AND t.event_name = 'vehicleselectionscreen_vehicles_loaded'
      AND t.customer_mobile_number NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
      AND (t.EVENT_TIMESTAMP + INTERVAL '330 mins')::date BETWEEN DATE '2026-01-01' AND DATE '2026-09-30'
    GROUP BY 1
),
booknow AS (
    SELECT DATE_TRUNC('month', t.EVENT_TIMESTAMP + INTERVAL '330 mins') AS month,
           COUNT(DISTINCT t.APP_SESSION_ID) AS bn
    FROM prod_curated.partload_analytics.ptl_fe_events t
    WHERE t.event_name = 'ptlbookingdetailspage_booknow_clicked'
      AND t.customer_mobile_number NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
      AND (t.EVENT_TIMESTAMP + INTERVAL '330 mins')::date BETWEEN DATE '2026-01-01' AND DATE '2026-09-30'
    GROUP BY 1
)
SELECT v.month::DATE AS month, v.vl AS vss_sessions, b.bn AS booknow_sessions,
       ROUND(100.0*b.bn/NULLIF(v.vl,0),2) AS overall_session_conversion_pct
FROM vehicles_loaded v LEFT JOIN booknow b ON v.month = b.month ORDER BY 1