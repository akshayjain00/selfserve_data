-- First, define the date range CTE
with date_range as (
    select
        CAST(DATE_TRUNC({{period}}, {{start_date}}::DATE) AS DATE) AS start_date,
        CAST(DATE_TRUNC({{period}}, DATEADD({{period}}, 1, {{end_date}}::DATE)) AS DATE)  AS end_date
),
cte as (SELECT 
  orders.id,
  CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.created_at))::date AS dated,
  external_id AS order_id,
  CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.created_at)) AS created_at,
  CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.updated_at)) AS updated_at,
  VEHICLE_REGISTRATION_NUMBER,
  trip_cost,
  batch_id,
  VENDOR_DETAILS_NEW_DATA.vendor_name
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
left join prod_curated.gsheet_sync.VENDOR_DETAILS_NEW_DATA
	on VENDOR_DETAILS_NEW_DATA.REGISTRATION_NUMBER = ORDER_VEHICLES.VEHICLE_REGISTRATION_NUMBER
-- left join PROD_CURATED.PARTLOAD_ANALYTICS.vehicle_availability
--     ON REPLACE(REPLACE(UPPER(vehicle_availability.VEHICLE_REGISTRATION_NO), ' ', ''), '-', '') = REPLACE(REPLACE(UPPER(order_vehicles.VEHICLE_REGISTRATION_NUMBER), ' ', ''), '-', '') 
left join PROD_CURATED.gsheet_sync."ptl_vendor_details" ptl
	ON REPLACE(REPLACE(UPPER(ptl.REGISTRATION_NUMBER), ' ', ''), '-', '') = REPLACE(REPLACE(UPPER(order_vehicles.VEHICLE_REGISTRATION_NUMBER), ' ', ''), '-', '') 
left join PROD_CURATED.PARTLOAD_APPLICATION.BATCHED_ORDERS_V1 on BATCHED_ORDERS_V1.order_external_id = ORDERS.external_id
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = oRDERS.route_id and ptl_routes.is_active = 'True'

WHERE date(orders.updated_at) between (select start_date from date_range) and (select end_date from date_range)
[[and case when ptl_internal_users.mobile is null then 'False' when ptl_internal_users.mobile is not null then 'True' end = {{is_test}}]]
and ORDER_VEHICLES.is_active = False
and BATCHED_ORDERS_V1.status = 3
AND orders.state = 3 
[[and {{pickup_city}}]]
[[and {{drop_city}}]]



[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP BY ALL)
select 
    vendor_name,
    count(batch_id) as rejected_trip_by_vendors
from cte
group by 1
order by 2 desc