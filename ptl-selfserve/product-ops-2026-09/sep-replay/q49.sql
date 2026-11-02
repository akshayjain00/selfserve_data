WITH first_vehicle AS (
    SELECT * FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY created_at ASC) AS rn
                   FROM prod_curated.partload_application.order_vehicles) t WHERE rn = 1
),
final_cte AS (
    SELECT o.id, o.created_at + INTERVAL '330 mins' AS order_created_time,
        ov.created_at + INTERVAL '330 mins' AS vehicle_assigned_time,
        pickup_slot_end + INTERVAL '330 minutes' AS slot_end,
        CASE WHEN DATE(o.created_at + INTERVAL '330 mins') = DATE(pickup_slot_end + INTERVAL '330 minutes') THEN 'same_day'
             WHEN DATE(o.created_at + INTERVAL '330 mins') <  DATE(pickup_slot_end + INTERVAL '330 minutes') THEN 'next_day'
             ELSE 'invalid/early' END AS final_pickup_flag,
        NULLIF(DATEDIFF('second', o.created_at + INTERVAL '330 mins', ov.created_at + INTERVAL '330 mins'),0)/60.0 AS alloc_min
    FROM prod_curated.partload_application.orders o
    LEFT JOIN first_vehicle ov ON ov.order_id = o.id
    WHERE o.state = 3
      AND o.customer_mobile NOT IN (SELECT MOBILE FROM prod_curated.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)
      AND DATE(o.created_at + INTERVAL '330 mins') >= DATE '2026-01-01'
      AND DATE(o.created_at + INTERVAL '330 mins') <= DATE '2026-09-30'
),
withalloc AS (
   SELECT *, CASE WHEN final_pickup_flag = 'same_day' THEN alloc_min
                  WHEN final_pickup_flag = 'next_day' THEN
                    NULLIF(DATEDIFF('second', CAST(CONCAT(TO_DATE(vehicle_assigned_time),' ','08:00:00') AS TIMESTAMP_NTZ), vehicle_assigned_time),0)/60.0
             END AS alloc__
   FROM final_cte
)
SELECT DATE_TRUNC('month', order_created_time)::DATE AS order_month,
   COUNT(DISTINCT id) AS total_orders,
   ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY alloc__),2) AS p50_alloc_min,
   ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY alloc__),2) AS p80_alloc_min
FROM withalloc GROUP BY 1 ORDER BY 1