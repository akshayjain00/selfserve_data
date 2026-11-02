WITH slot_intervals AS (
    SELECT 
        route_id,
        start_time,
        end_time,
        EDD_BUFFER_IN_DAYS,
    
        CASE 
            WHEN ROW_NUMBER() OVER (PARTITION BY route_id, start_time, end_time ORDER BY created_at) = 1 
            THEN TIMESTAMP '1970-01-01 00:00:00'   
            ELSE created_at 
        END AS valid_from,
        LEAD(created_at) OVER (
            PARTITION BY route_id, start_time, end_time
            ORDER BY created_at
        ) AS valid_to
    FROM partload_application.slots)
, online as
(
select 
CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
BATCHED_ORDERS_V1.ORDER_EXTERNAL_ID,
batch_id
from PROD_CURATED.PARTLOAD_APPLICATION.BATCHED_ORDERS_V1
left join PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES
on BATCHED_ORDERS_V1.ORDER_EXTERNAL_ID=ORDER_VEHICLES.ORDER_EXTERNAL_ID
left join PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
on BATCHED_ORDERS_V1.ORDER_EXTERNAL_ID=ORDERS.external_id
left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
on PTL_INTERNAL_USERS.mobile= ORDERS.customer_mobile
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
LEFT JOIN slot_intervals s
ON ORDERS.route_id = s.route_id
 AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_start) AS TIME) = s.start_time
   AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ORDERS.pickup_slot_end)   AS TIME) = s.end_time
 AND ORDERS.created_at >= s.valid_from
 AND (ORDERS.created_at < s.valid_to OR s.valid_to IS NULL)
where status=3
and orders.created_at >=  {{start_date}} - INTERVAL '330 MINS'
and orders.created_at <= {{end_date}} - INTERVAL '330 MINS' + interval '1 day'
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
[[and 
  case 
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True'
end = {{is_test}}]]
[[and 
  CASE
      WHEN s.EDD_BUFFER_IN_DAYS = 0 THEN 'SDD'
      WHEN s.EDD_BUFFER_IN_DAYS = 1 THEN 'NDD'
      ELSE NULL
  END = {{delivery_type}}
]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
ORDER BY DATED
)

,offline as
(
select 
CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
ORDER_EXTERNAL_ID,
batch_id
from prod_curated.gsheet_sync.ptl_offline_orders
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
LEFT JOIN slot_intervals s
ON ptl_offline_orders.route_id = s.route_id
 AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ptl_offline_orders.pickup_slot_start) AS TIME) = s.start_time
   --AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ptl_offline_orders.pickup_slot_end)   AS TIME) = s.end_time
 AND ptl_offline_orders.created_at >= s.valid_from
 AND (ptl_offline_orders.created_at < s.valid_to OR s.valid_to IS NULL)
where created_at::date >=  {{start_date}} 
and created_at::date <= {{end_date}} 
and TRIP_LEVEL_CONSIDERATION='yes'
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
[[and 
  CASE
      WHEN s.EDD_BUFFER_IN_DAYS = 0 THEN 'SDD'
      WHEN s.EDD_BUFFER_IN_DAYS = 1 THEN 'NDD'
      ELSE NULL
  END = {{delivery_type}}
]]

ORDER BY DATED
)

,final AS
(
SELECT *
FROM online

UNION 

SELECT *
FROM offline
)


select
dated,
count(distinct ORDER_EXTERNAL_ID)/NULLIF(COUNT(DISTINCT batch_id), 0) as avg_order_per_trip
from final
group by 1
ORDER BY DATED