WITH s AS (
    SELECT e.session_id                                                 AS session_id, /*⚠VERIFY fe_events schema vs card 48491*/
           MAX(CASE WHEN e.event = 'order_placed' THEN 1 ELSE 0 END)    AS placed_order
    FROM prod_curated.partload_analytics.ptl_fe_events e
    WHERE e.event_ts >= DATEADD('minute', -330, DATE '2026-04-01')
      AND e.event_ts <  DATEADD('minute', -330, DATE '2026-05-01')
      AND e.user_type = 'Business'                                      /*⚠VERIFY business classification*/
      AND NOT EXISTS (SELECT 1 FROM prod_curated.partload_analytics.ptl_internal_users u WHERE u.mobile = e.mobile)
    GROUP BY e.session_id
)
SELECT 'excl_offline' AS basis, SUM(placed_order) AS orders, COUNT(*) AS sessions
FROM s
