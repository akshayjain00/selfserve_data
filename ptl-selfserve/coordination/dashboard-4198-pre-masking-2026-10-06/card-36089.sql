select
ACTUAL_GOODS_TYPE,
display_name as declared_good,
COUNT(DISTINCT external_id) * 1.0 / SUM(COUNT(DISTINCT external_id)) OVER () AS order_distribution_perc
from PROD_CURATED.PARTLOAD_APPLICATION.orders
left join gsheet_sync.ptl_table 
on ptl_table.order_id=orders.id
left join prod_curated.partload_application.load_details
on orders.id=load_details.order_id
left join prod_curated.partload_application.material_type
on material_type.material_type_id=load_details.material_type_id
left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
on PTL_INTERNAL_USERS.mobile= orders.customer_mobile
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
where CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at)) >=  {{start_date}}
and CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))  <= {{end_Date}}+ interval '1 day'
[[and case when ptl_internal_users.mobile is null then 'False' when ptl_internal_users.mobile is not null then 'True' end = {{is_test}}]]
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
and NOT (LOWER(actual_goods_type) LIKE '%' || LOWER(display_name) || '%')
AND NOT (LOWER(display_name) LIKE '%' || LOWER(actual_goods_type) || '%')
and ACTUAL_GOODS_TYPE is not null


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
group by 1,2
order by order_distribution_perc desc