with old_online as 
(
select 
	CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at))) AS DATE) AS dated,
	o.external_id,
    ptl.wd_marked,
    ptl.actual_fare,
	o.estimated_fare/100 as estimated_fare
from partload_application.orders o 
join gsheet_sync.ptl_table ptl 
on o.id = ptl.order_id
left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS on PTL_INTERNAL_USERS.mobile= o.customer_mobile
left join prod_curated.partload_analytics.ptl_routes
on ptl_routes.route_id=o.route_id and ptl_routes.is_active = 'True'
where o.state = 3
[[and 
  case 
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True' end = {{is_test}}]]
and o.created_at >= {{start_date}} - INTERVAL '330 MINS'
and o.created_at <= {{end_date}} - INTERVAL '330 MINS'+ interval '1 day'
[[and {{pickup_city}}]]
[[and {{drop_city}}]]


[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)

,new_online as
( 
SELECT
CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at))) AS DATE) AS dated,
  o.external_id,
  MAX(CASE WHEN is_current_fare = 'FALSE' THEN 'TRUE' END) AS wd_marked,
  MAX(CASE WHEN is_current_fare = 'TRUE' THEN total_fare END)/100 AS actual_fare,
  MAX(CASE WHEN FARE_REASON_CODE = 'INITIAL_BOOKING' THEN total_fare END)/100 AS estimated_fare
FROM prod_curated.partload_application.load_details
LEFT JOIN prod_curated.partload_application.orders o
  ON load_details.order_id = o.id
LEFT JOIN prod_curated.partload_application.order_fares
  ON order_fares.order_id = load_details.order_id
LEFT JOIN prod_curated.partload_application.fare_revision_notified
  ON fare_revision_notified.order_fare_id = order_fares.id
LEFT JOIN prod_curated.partload_analytics.ptl_internal_users
  ON PTL_INTERNAL_USERS.mobile = o.customer_mobile
LEFT JOIN prod_curated.partload_analytics.ptl_routes 
  ON ptl_routes.route_id = o.route_id and ptl_routes.is_active = 'True'
WHERE o.state = 3
  AND o.customer_mobile NOT IN (
    SELECT mobile 
    FROM prod_curated.partload_analytics.ptl_internal_users
  )
  and o.created_at >= {{start_date}} - INTERVAL '330 MINS'
and o.created_at <= {{end_date}} - INTERVAL '330 MINS'+ interval '1 day'
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
  

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
group by 1,2
)

,offline as
(
select 
	CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
    external_id,
    wd_marked,
    actual_fare,
	estimated_fare
from prod_curated.gsheet_sync.ptl_offline_orders
left join prod_curated.partload_analytics.ptl_routes
on ptl_routes.route_id=ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
where state = 3
and created_at::date >= {{start_date}}
and created_at::date <= {{end_date}} 
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
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
    external_id,
    wd_marked,
    (actual_fare - estimated_fare) as wd_revenue,
    case when wd_marked = 'TRUE' then actual_fare else estimated_fare end as fares
	from final 
	group by 1,2,3,4,5
)

	
SELECT
	dated,
    sum(wd_revenue) as revenue_from_wd,sum(fares) as total_fare,sum(wd_revenue)/sum(fares) as wd_share_in_revenue
FROM raw
group by 1
order by 1