with online as (
SELECT 
  orders.id,
  CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.created_at))) AS DATE) AS dated,
  external_id AS order_id,
  VEHICLE_REGISTRATION_NUMBER,
  -- trip_cost,
  batch_id,
  vendor_name
FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.contact_details
  ON ORDERS.id = contact_details.order_id
LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.LOAD_DETAILS
  ON ORDERS.id = LOAD_DETAILS.order_id
LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.material_type
  ON LOAD_DETAILS.material_type_id = material_type.material_type_id
LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES
  ON ORDERS.external_id = ORDER_VEHICLES.order_external_id
left join PROD_CURATED.PARTLOAD_ANALYTICS.ptl_internal_users
 on ptl_internal_users.mobile=ORDERS.customer_mobile
left join PROD_CURATED.gsheet_sync."ptl_vendor_details" ptl
	ON REPLACE(REPLACE(UPPER(ptl.REGISTRATION_NUMBER), ' ', ''), '-', '') = REPLACE(REPLACE(UPPER(order_vehicles.VEHICLE_REGISTRATION_NUMBER), ' ', ''), '-', '') 
left join PROD_CURATED.PARTLOAD_APPLICATION.BATCHED_ORDERS_V1 on BATCHED_ORDERS_V1.order_external_id = ORDERS.external_id
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = oRDERS.route_id and ptl_routes.is_active = 'True'
WHERE ORDERS.created_at >= {{start_date}} - INTERVAL '330 MINS'
and ORDERS.created_at <= {{end_date}} - INTERVAL '330 MINS' + interval '1 day'
[[and case when ptl_internal_users.mobile is null then 'False' when ptl_internal_users.mobile is not null then 'True' end = {{is_test}}]]
and ORDER_VEHICLES.is_active = True
and BATCHED_ORDERS_V1.status = 3
AND orders.state = 3 
[[and {{pickup_city}}]]
[[and {{drop_city}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY ALL
)

,offline as
(
SELECT 
  id,
  CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
  order_id,
  VEHICLE_NUMBER,
  -- trip_cost,
  batch_id,
  vendor_name
FROM prod_curated.gsheet_sync.ptl_offline_orders
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
WHERE created_at::date >= {{start_date}}
and created_at::date <= {{end_date}}
AND state = 3
and TRIP_LEVEL_CONSIDERATION = 'yes'
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
GROUP BY ALL
)

,final AS
(
SELECT *
FROM online

UNION ALL

SELECT *
FROM offline
)

,raw as (
select 
    batch_id,
    vendor_name,
    -- max(trip_cost) as vendor_earning
from final
group by all
)

select vendor_name,count(batch_id) as Trip_per_vendor
from raw
group by 1
order by 2 desc;
