WITH base AS (
    SELECT 
        (EVENT_TIMESTAMP_IST) AS event_timestamp,
        a_app_session_id
    FROM Partload_analytics.ptl_frontend_events 
	left join PROD_CURATED.PARTLOAD_APPLICATION.orders 
	on orders.external_id=A_VARIABLE_ATTR:order_id
	left join prod_curated.partload_analytics.ptl_routes
    on ptl_routes.route_id=orders.route_id and ptl_routes.is_active = 'True'
    WHERE event_type = 'ptlorderdetailsscreen_support_bn_clicked'
    and a_user_id not in (SELECT MOBILE FROM PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)
	and EVENT_TIMESTAMP_IST>={{start_date}}::timestamp
	and EVENT_TIMESTAMP_IST<={{end_date}}::timestamp + interval '1 day'
	[[and {{pickup_city}}]]
    [[and {{drop_city}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)

,incidents AS
(
SELECT 
CAST(DATE_TRUNC({{period}}, event_timestamp) AS DATE) AS dated,
count (distinct a_app_session_id) as incidents
from base
group by 1
)

,placed_orders as
(
select 
CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
count(distinct orders.external_id) as placed_orders,
from PROD_CURATED.PARTLOAD_APPLICATION.orders 
left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
on PTL_INTERNAL_USERS.mobile= orders.customer_mobile
left join prod_curated.partload_analytics.ptl_routes
on ptl_routes.route_id=orders.route_id and ptl_routes.is_active = 'True'
where (orders.created_at)::timestamp >=  {{start_date}} - interval '330 mins'
and (orders.created_at)::timestamp <= {{end_date}} - interval '330 mins' + interval '1 day'
[[and 
  case 
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True'
end = {{is_test}}]]
[[and {{pickup_city}}]]
[[and {{drop_city}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
group by 1
order by dated desc
)

select 
incidents.dated,
incidents,
placed_orders,
incidents/placed_orders as IPO
from incidents 
left join placed_orders
on incidents.dated=placed_orders.dated
order by dated desc