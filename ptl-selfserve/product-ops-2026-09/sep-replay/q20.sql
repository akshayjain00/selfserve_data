WITH base AS (
    SELECT o.customer_mobile, o.created_at + INTERVAL '330 mins' AS first_order_date,
           TO_VARCHAR(o.created_at + INTERVAL '330 mins', 'YYYY-MM') AS year_month
    FROM prod_curated.partload_application.orders o
    WHERE o.state = 3
    QUALIFY ROW_NUMBER() OVER (PARTITION BY o.customer_mobile ORDER BY o.created_at ASC) = 1
)
SELECT DATE_TRUNC('month', DATE(e.event_timestamp + INTERVAL '330 mins')) AS month,
    CASE WHEN (TO_VARCHAR(e.event_timestamp + INTERVAL '330 mins','YYYY-MM') <= base.year_month OR base.year_month IS NULL)
         THEN 'new customer' ELSE 'repeat customer' END AS customer_tag,
    COUNT(DISTINCT CASE WHEN e.event_name='vehicleselectionscreen_vehicles_loaded' THEN e.app_session_id END) AS vss_sessions,
    COUNT(DISTINCT CASE WHEN e.event_name='ptlbookingdetailspage_quote_viewed' THEN e.app_session_id END) AS quote_sessions,
    ROUND(100.0*COUNT(DISTINCT CASE WHEN e.event_name='ptlbookingdetailspage_quote_viewed' THEN e.app_session_id END)
      / NULLIF(COUNT(DISTINCT CASE WHEN e.event_name='vehicleselectionscreen_vehicles_loaded' THEN e.app_session_id END),0),2) AS vss_to_quote_pct
FROM prod_curated.partload_analytics.ptl_fe_events e
LEFT JOIN base ON base.customer_mobile = e.customer_mobile_number
LEFT JOIN prod_curated.oms_public.customers c ON c.mobile = e.customer_mobile_number
WHERE e.customer_mobile_number NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
  AND e.event_name IN ('vehicleselectionscreen_vehicles_loaded','ptlbookingdetailspage_quote_viewed')
  AND e.app_session_id != 'dbe3759b-bd16-4523-9f24-1c0f45e34c2a'
  AND DATE(e.event_timestamp + INTERVAL '330 mins') >= DATE '2026-01-01'
  AND DATE(e.event_timestamp + INTERVAL '330 mins') <= DATE '2026-09-30'
  AND (CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END) = 'Business'
GROUP BY 1,2 ORDER BY 1,2