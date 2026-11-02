select 
date_trunc({{period}},ORDERS.created_at + interval '330 mins' ) as month,
case 
when cancellation_source = '1' then 'Customer_App' 
when cancellation_source = '2' then 'Partner_App' 
when cancellation_source = '3' then 'Salesforce' 
when cancellation_source = '4' then 'Appsmith' 
end as cancellation_sources, 
count(distinct order_id) as cancelled_orders

from PROD_CURATED.PARTLOAD_APPLICATION.ORDER_CANCELLATION_REASONS
left join PROD_CURATED.PARTLOAD_APPLICATION.ORDERS on ORDER_CANCELLATION_REASONS.order_external_id=ORDERS.external_id
left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS on PTL_INTERNAL_USERS.mobile= ORDERS.customer_mobile
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id=orders.route_id and ptl_routes.is_active = 'True'

where 1=1
and (ORDERS.created_at)::timestamp >=  {{start_date}}- interval '330 mins'
and (ORDERS.created_at)::timestamp <= {{end_Date}}- interval '330 mins'+ interval '1 day'
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
[[and 
  case 
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True'
end = {{is_test}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
group by 1, 2