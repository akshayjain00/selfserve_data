WITH repeat_customers AS (
      SELECT CUSTOMER_MOBILE, MIN(created_at + INTERVAL '330 mins') AS first_completed_at
      FROM prod_curated.partload_application.orders WHERE STATE = 3 GROUP BY CUSTOMER_MOBILE
),
vehicles_loaded AS (
    SELECT DATE_TRUNC('month', t.EVENT_TIMESTAMP + INTERVAL '330 mins') AS month,
           COUNT(DISTINCT t.APP_SESSION_ID) AS vehicles_loaded_sessions
    FROM prod_curated.partload_analytics.ptl_fe_events t
    CROSS JOIN LATERAL FLATTEN(INPUT => TRY_PARSE_JSON(TRY_PARSE_JSON(t.variable_attr):vehicle_ids_seq)) f
    LEFT JOIN prod_eldoria.core.dim_customers dc ON dc.customer_id = t.customer_id
    WHERE f.value::NUMBER IN (-1, 1159) AND t.event_name = 'vehicleselectionscreen_vehicles_loaded'
      AND t.customer_mobile_number NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
      AND (CASE WHEN dc.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END) = 'Business'
      AND (t.EVENT_TIMESTAMP + INTERVAL '330 mins')::date >= DATE '2026-01-01'
      AND (t.EVENT_TIMESTAMP + INTERVAL '330 mins')::date <= DATE '2026-08-31'
    GROUP BY 1
),
vehicles_ptl_selected AS (
    SELECT DATE_TRUNC('month', t.EVENT_TIMESTAMP + INTERVAL '330 mins') AS month,
           COUNT(DISTINCT t.APP_SESSION_ID) AS ptl_selected_sessions
    FROM prod_curated.partload_analytics.ptl_fe_events t
    LEFT JOIN prod_eldoria.core.dim_customers dc ON dc.customer_id = t.customer_id
    WHERE t.event_name = 'vehicleselectionscreen_confirm_clicked'
      AND TRY_PARSE_JSON(t.variable_attr):vehicle_id::STRING IN ('-1','1159')
      AND t.customer_mobile_number NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
      AND (CASE WHEN dc.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END) = 'Business'
      AND (t.EVENT_TIMESTAMP + INTERVAL '330 mins')::date >= DATE '2026-01-01'
      AND (t.EVENT_TIMESTAMP + INTERVAL '330 mins')::date <= DATE '2026-08-31'
    GROUP BY 1
),
quote_viewed AS (
    SELECT DATE_TRUNC('month', t.EVENT_TIMESTAMP + INTERVAL '330 mins') AS month,
           COUNT(DISTINCT t.APP_SESSION_ID) AS quote_viewed_sessions
    FROM prod_curated.partload_analytics.ptl_fe_events t
    LEFT JOIN prod_eldoria.core.dim_customers dc ON dc.customer_id = t.customer_id
    WHERE t.event_name = 'ptlbookingdetailspage_quote_viewed'
      AND t.customer_mobile_number NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
      AND (CASE WHEN dc.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END) = 'Business'
      AND (t.EVENT_TIMESTAMP + INTERVAL '330 mins')::date >= DATE '2026-01-01'
      AND (t.EVENT_TIMESTAMP + INTERVAL '330 mins')::date <= DATE '2026-08-31'
    GROUP BY 1
),
booknow_clicked AS (
    SELECT DATE_TRUNC('month', t.EVENT_TIMESTAMP + INTERVAL '330 mins') AS month,
           COUNT(DISTINCT t.APP_SESSION_ID) AS booknow_clicked_sessions
    FROM prod_curated.partload_analytics.ptl_fe_events t
    LEFT JOIN prod_eldoria.core.dim_customers dc ON dc.customer_id = t.customer_id
    WHERE t.event_name = 'ptlbookingdetailspage_booknow_clicked'
      AND t.customer_mobile_number NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
      AND (CASE WHEN dc.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END) = 'Business'
      AND (t.EVENT_TIMESTAMP + INTERVAL '330 mins')::date >= DATE '2026-01-01'
      AND (t.EVENT_TIMESTAMP + INTERVAL '330 mins')::date <= DATE '2026-08-31'
    GROUP BY 1
)
SELECT COALESCE(v.month, s.month, q.month, b.month)::DATE AS month,
   v.vehicles_loaded_sessions, s.ptl_selected_sessions, q.quote_viewed_sessions, b.booknow_clicked_sessions,
   ROUND(100.0*s.ptl_selected_sessions/NULLIF(v.vehicles_loaded_sessions,0),2) AS loaded_to_selected_pct,
   ROUND(100.0*b.booknow_clicked_sessions/NULLIF(v.vehicles_loaded_sessions,0),2) AS overall_conversion_pct
FROM vehicles_loaded v
FULL OUTER JOIN vehicles_ptl_selected s ON v.month = s.month
FULL OUTER JOIN quote_viewed q ON v.month = q.month
FULL OUTER JOIN booknow_clicked b ON v.month = b.month
ORDER BY month