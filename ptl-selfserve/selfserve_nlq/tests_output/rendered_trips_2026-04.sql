WITH trips AS (
    SELECT b.batch_id                                                   AS batch_id,   /*⚠VERIFY batch grain vs card 33461*/
           COUNT(DISTINCT o.external_id)                                AS orders_on_trip
    FROM prod_curated.partload_application.batched_orders_v1 b
    JOIN prod_curated.partload_application.orders o ON o.external_id = b.order_external_id             /*⚠VERIFY join*/
    WHERE o.created_at >= DATEADD('minute', -330, DATE '2026-04-01')
      AND o.created_at <  DATEADD('minute', -330, DATE '2026-05-01')
      AND o.state = 3
    GROUP BY b.batch_id
)
SELECT 'excl_offline' AS basis,
       SUM(CASE WHEN orders_on_trip >= 2 THEN orders_on_trip ELSE 0 END) AS clubbed_orders,
       COUNT(CASE WHEN orders_on_trip >= 2 THEN 1 END)                   AS clubbing_trips
FROM trips
