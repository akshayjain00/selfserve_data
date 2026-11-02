with old_online as 
(
select 
	CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
	BATCHED_ORDERS_V1.batch_id,
	ACTUAL_FARE,
	ESTIMATED_FARE/100 as ESTIMATED_FARE,
	TRIP_COST as vendor_cost
from prod_curated.partload_application.orders
left join gsheet_sync.ptl_table 
on orders.id=ptl_table.order_id

left join prod_curated.partload_application.BATCHED_ORDERS_V1
on BATCHED_ORDERS_V1.order_external_id=orders.external_id

left join prod_curated.partload_application.BATCH_V1
on BATCH_V1.id=BATCHED_ORDERS_V1.batch_id

left join prod_curated.partload_application.jobs
on BATCHED_ORDERS_V1.batch_id=jobs.batch_id

left join prod_curated.partload_application.ORDER_VEHICLES
on jobs.vehicle_id=ORDER_VEHICLES.vehicle_id

left join prod_curated.partload_analytics.vehicle_availability
ON REGEXP_SUBSTR(ORDER_VEHICLES.vehicle_type, '\\d+') = REGEXP_SUBSTR(vehicle_availability.vehicle_type, '\\d+')

left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
on PTL_INTERNAL_USERS.mobile= orders.customer_mobile 

left join prod_curated.partload_analytics.ptl_routes
on ptl_routes.route_id=orders.route_id and ptl_routes.is_active = 'True'

where (orders.created_at)::timestamp >=  {{start_date}}- interval '330 mins'
and (orders.created_at)::timestamp <= {{end_Date}}- interval '330 mins' + interval '1 day'
[[and 
  case 
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True'
end = {{is_test}}]]
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
and CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))<='2025-07-11'
and BATCHED_ORDERS_V1.batch_id is not null
and orders.state = 3


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)

,new_online as
(
select 
	CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at))) AS DATE) AS dated,
	BATCHED_ORDERS_V1.batch_id,
	MAX(CASE WHEN is_current_fare = 'TRUE' THEN total_fare END)/100 AS actual_fare,
    MAX(CASE WHEN FARE_REASON_CODE = 'INITIAL_BOOKING' THEN total_fare END)/100 AS estimated_fare,
	TRIP_COST as vendor_cost
FROM prod_curated.partload_application.load_details
LEFT JOIN prod_curated.partload_application.orders o
  ON load_details.order_id = o.id
left join gsheet_sync.ptl_table 
on o.id=ptl_table.order_id

left join prod_curated.partload_application.BATCHED_ORDERS_V1
on BATCHED_ORDERS_V1.order_external_id=o.external_id

LEFT JOIN prod_curated.partload_application.order_fares
  ON order_fares.order_id = load_details.order_id
LEFT JOIN prod_curated.partload_application.fare_revision_notified
  ON fare_revision_notified.order_fare_id = order_fares.id

left join prod_curated.partload_application.BATCH_V1
on BATCH_V1.id=BATCHED_ORDERS_V1.batch_id

left join prod_curated.partload_application.jobs
on BATCHED_ORDERS_V1.batch_id=jobs.batch_id

left join prod_curated.partload_application.ORDER_VEHICLES
on jobs.vehicle_id=ORDER_VEHICLES.vehicle_id

left join prod_curated.partload_analytics.vehicle_availability
ON REGEXP_SUBSTR(ORDER_VEHICLES.vehicle_type, '\\d+') = REGEXP_SUBSTR(vehicle_availability.vehicle_type, '\\d+')

left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
on PTL_INTERNAL_USERS.mobile= o.customer_mobile 

left join prod_curated.partload_analytics.ptl_routes
on ptl_routes.route_id=o.route_id and ptl_routes.is_active = 'True'

where (o.created_at)::timestamp >=  {{start_date}}- interval '330 mins'
and (o.created_at)::timestamp <= {{end_Date}}- interval '330 mins' + interval '1 day'
[[and 
  case 
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True'
end = {{is_test}}]]
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
and CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at))>'2025-07-11'
and BATCHED_ORDERS_V1.batch_id is not null
and o.state = 3


[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
group by 1,2,5
)

,offline as
(
select 
	CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
	batch_id,
	ACTUAL_FARE,
	ESTIMATED_FARE,
	TRIP_COST as vendor_cost
from prod_curated.gsheet_sync.ptl_offline_orders
left join prod_curated.partload_analytics.ptl_routes
on ptl_routes.route_id=ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
where dated >= {{start_date}}
and dated <=  {{end_Date}}
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
and batch_id is not null
and state = 3
and TRIP_LEVEL_CONSIDERATION = 'yes'
)

,final AS
(
SELECT *
FROM old_online

UNION ALL

SELECT *
FROM offline

UNION ALL

select * 
from new_online
)

,raw as
(
select 
dated,
batch_id,
case when ACTUAL_FARE is null then ESTIMATED_FARE else ACTUAL_FARE end as trip_fare,
vendor_cost
from final 
group by 1,2,3,4
)

	
select 
dated,
(sum(trip_fare) - sum(vendor_cost) - (sum(vendor_cost) * 0.01))/count(distinct batch_id) as total_earnings 
from raw
group by 1
order by 1