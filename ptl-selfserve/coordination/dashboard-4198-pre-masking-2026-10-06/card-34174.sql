WITH old_online AS (
  SELECT 
    CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(PICKUP_SLOT_START))) AS DATE) AS dated,
    external_id,
    state,
    WD_MARKED,
    --DAMAGED_FLAG,
	DAMAGED_AT
  FROM PROD_CURATED.PARTLOAD_APPLICATION.orders
    left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
  LEFT JOIN gsheet_sync.ptl_table 
    ON orders.id = ptl_table.order_id
  left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
  on PTL_INTERNAL_USERS.mobile= ORDERS.customer_mobile
  where (ORDERS.PICKUP_SLOT_START)::timestamp >=  {{start_date}}- interval '330 mins'
  and (ORDERS.PICKUP_SLOT_START)::timestamp <= {{end_Date}}- interval '330 mins' + interval '1 day'
  [[and {{pickup_city}}]]
 [[and {{drop_city}}]]
  [[and 
  case 
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True'
  end = {{is_test}}]]
  

[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
order by 1 desc
)

,offline as
(
 SELECT 
    CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
    external_id,
    state,
    WD_MARKED,
    --'FALSE' as DAMAGED_FLAG,
	null as DAMAGED_AT
  FROM prod_curated.gsheet_sync.ptl_offline_orders
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
  where created_at::date >=  {{start_date}}
  and created_at::date <= {{end_Date}}
  [[and {{pickup_city}}]]
  [[and {{drop_city}}]]
  order by 1 desc
)

,new_online as
(
SELECT 
  CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(PICKUP_SLOT_START))) AS DATE) AS dated,
  external_id,
  state,
  CASE WHEN is_current_fare = 'FALSE' then 'TRUE' end as wd_marked,
  --'FALSE' as DAMAGED_FLAG,
   null as DAMAGED_AT
FROM prod_curated.partload_application.load_details
LEFT JOIN prod_curated.partload_application.orders
  ON load_details.order_id = orders.id
LEFT JOIN prod_curated.partload_application.order_fares
  ON order_fares.order_id = load_details.order_id
LEFT JOIN prod_curated.partload_application.fare_revision_notified
  ON fare_revision_notified.order_fare_id = order_fares.id
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
WHERE orders.customer_mobile NOT IN (
    SELECT mobile 
    FROM prod_curated.partload_analytics.ptl_internal_users
)
and (ORDERS.PICKUP_SLOT_START)::timestamp >=  {{start_date}}- interval '330 mins'
  and (ORDERS.PICKUP_SLOT_START)::timestamp <= {{end_Date}}- interval '330 mins'+ interval '1 day'
[[and {{pickup_city}}]]
[[and {{drop_city}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)

,final AS
(
SELECT *
FROM old_online

UNION ALL

SELECT *
FROM offline

union all

select *
FROM new_online
)

,base as
(
select 
    dated,
    COUNT(DISTINCT external_id) AS placed_orders,
    COUNT(DISTINCT CASE WHEN state = 3 THEN external_id END) AS completed_count,
    COUNT(DISTINCT CASE WHEN state = 4 THEN external_id END) AS cancelled_count,
    COUNT(DISTINCT CASE WHEN state = 2 THEN external_id END) AS in_transit_count,
    COUNT(DISTINCT CASE WHEN state = 1 THEN external_id END) AS assign_count,
    COUNT(DISTINCT CASE WHEN state = 3 AND WD_MARKED = 'TRUE' THEN external_id END) AS wd_count,
    COUNT(DISTINCT CASE WHEN state = 3 AND DAMAGED_AT in ('Intransit','Drop') THEN external_id END) AS damaged_count, 
    COUNT(DISTINCT CASE WHEN state = 3 AND DAMAGED_AT = 'Intransit' THEN external_id END) AS damaged_intransit_count,
    COUNT(DISTINCT CASE WHEN state = 3 AND DAMAGED_AT = 'Drop' THEN external_id END) AS damaged_drop_count,
    COUNT(DISTINCT CASE WHEN state = 0 THEN external_id END) AS open_count
	from final
	group by 1
	order by 1
),




end_cte as (	
SELECT dated, 'Completed' AS status, (completed_count - wd_count - damaged_count) / NULLIF(placed_orders, 0) FROM base
UNION ALL
SELECT dated, 'Completed - WD' as status, wd_count / NULLIF(placed_orders, 0) FROM base
UNION ALL
SELECT dated, 'Completed - Damaged at Intransit', damaged_intransit_count / NULLIF(placed_orders, 0) FROM base
UNION ALL
SELECT dated, 'Completed - Damaged at Drop', damaged_drop_count / NULLIF(placed_orders, 0) FROM base
UNION ALL
SELECT dated, 'Cancelled', cancelled_count / NULLIF(placed_orders, 0) FROM base
UNION ALL
SELECT dated, 'In Transit', in_transit_count / NULLIF(placed_orders, 0) FROM base
UNION ALL
SELECT dated, 'Open', open_count / NULLIF(placed_orders, 0) FROM base
UNION ALL
SELECT dated, 'Assigned', assign_count / NULLIF(placed_orders, 0) FROM base
)
select * from end_cte
order by dated desc, status asc