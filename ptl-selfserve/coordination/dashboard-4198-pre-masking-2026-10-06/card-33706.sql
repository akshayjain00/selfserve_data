select 
	date_trunc({{period}}, date(updated_at + interval '330 mins')) as date,
	count(distinct id) as orders, 
	sum(estimated_fare/100) as revenue,
	revenue/orders as aov
from partload_application.orders 
left join partload_analytics.ptl_routes on ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'

where 1=1
and (date(updated_at + interval '330 mins') >= {{start_date}} and date(updated_at + interval '330 mins') <= {{end_date}})
and state ='3'
AND orders.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
[[and {{pickup_city}}]]
[[and {{drop_city}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
group by 1
order by 1 asc

