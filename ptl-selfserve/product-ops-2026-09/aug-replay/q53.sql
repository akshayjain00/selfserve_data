with cte as (
SELECT orders.id, DATE(orders.pickup_slot_start + interval '330 minutes') as pickup_date, orders.external_id, route_id,
    ROUND(MAX(CASE WHEN load_details.entry_type = 'CUSTOMER_DECLARED' THEN load_details.chargeable_weight END)/1000,0) AS customer_declared_weight,
    ROUND(MAX(CASE WHEN load_details.entry_type = 'OPS_DECLARED' AND load_details.is_active = TRUE THEN load_details.chargeable_weight END)/1000,0) AS ops_declared_weight,
    coalesce(ops_declared_weight, customer_declared_weight) as final_weight
FROM prod_curated.partload_application.orders
LEFT JOIN prod_curated.partload_application.load_details ON load_details.order_id = orders.id
WHERE DATE(orders.created_at + interval '330 minutes') > '2025-07-11'
  AND orders.state = 3
  AND orders.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
GROUP BY orders.id, pickup_date, orders.external_id, route_id),
bt_details as (
select batched_orders_v1.batch_id, batched_orders_v1.order_external_id, jobs.vehicle_id
from prod_curated.partload_application.batch_v1
left join prod_curated.partload_application.batched_orders_v1 on batched_orders_v1.batch_id = batch_v1.id
left join prod_curated.partload_application.jobs on jobs.batch_id = batch_v1.id
join prod_curated.partload_application.vehicles v on v.id = jobs.vehicle_id
where batch_v1.status = 2 and batched_orders_v1.status = 3 and jobs.job_status = 6
and date(batched_orders_v1.created_at + interval '330 minutes') > '2025-07-11'),
route_base as (select c.pickup_date, c.final_weight, bt.batch_id, bt.order_external_id, bt.vehicle_id
  from cte c join bt_details bt on bt.order_external_id = c.external_id),
trip_data as (select pickup_date, batch_id, listagg(distinct vehicle_id) as vehicle_id,
    count(distinct order_external_id) as total_order_count, sum(final_weight) as total_weight
  from route_base group by 1,2),
final_base as (
  select t.*, date_trunc('month', date(t.pickup_date)) as dt, vc.weight_capacity
  from trip_data t
  left join prod_curated.PARTLOAD_APPLICATION.VEHICLES v on v.id = t.vehicle_id
  LEFT JOIN prod_curated.PARTLOAD_APPLICATION.vehicle_categories vc ON vc.id = v.VEHICLE_CATEGORIES_ID
  where date(t.pickup_date) >= DATE '2026-01-01' and date(t.pickup_date) <= DATE '2026-08-31'
)
SELECT dt::DATE AS month, ROUND(AVG(batch_actual_weight),0) as avg_batch_weight,
    ROUND(100.0*SUM(batch_actual_weight)/SUM(batch_capacity),2) AS total_utilization_pct
FROM (SELECT batch_id, dt, MAX(weight_capacity) AS batch_capacity, SUM(total_weight) AS batch_actual_weight
      FROM final_base WHERE weight_capacity is not null GROUP BY 1,2) t
GROUP BY 1 ORDER BY 1