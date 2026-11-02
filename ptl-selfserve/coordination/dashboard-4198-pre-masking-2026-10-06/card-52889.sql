select 
    date_trunc({{granularity}}, date(orders.updated_at + interval '330 mins')) as date,
    count(distinct orders.id)                                                               as orders, 

    sum(total_fare / 100)                                                     as revenue_without_discount,
    sum((total_fare + coalesce(q.discount_amount_minor_units, 0)) / 100)      as revenue_with_discount,
    sum(coalesce(q.discount_amount_minor_units, 0) / 100)                                   as total_discount_rs,

    revenue_with_discount / orders                                                          as aov_with_discount,
    revenue_without_discount / orders                                                       as aov_without_discount

from partload_application.orders 
left join partload_analytics.ptl_routes
    on ptl_routes.route_id = orders.route_id
    and ptl_routes.is_active = 'True'
left join partload_application.order_fares f on f.order_id=orders.id and f.is_current_fare = TRUE
left join partload_application.quotations q
    on q.quotation_uuid = orders.quotation_uuid
where 1=1
and (date(orders.updated_at + interval '330 mins') >= {{start_date}} and date(orders.updated_at + interval '330 mins') <= {{end_date}})
and state ='3'
AND orders.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
[[and {{pickup_city}}]]
[[and {{drop_city}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
group by 1
order by 1 desc

-- 4632
-- 9771305


-- -- (date(created_At + interval '330 mins') >= '2025-12-01' and date(created_At + interval '330 mins') <= '2025-12-31')
-- -- (date(updated_at + interval '330 mins') >= '2025-12-01' and date(updated_at + interval '330 mins') <= '2025-12-31')

-- with base as (
-- select 
-- 	orders.id,
-- 	date(ESTIMATED_DELIVERY_TS + interval '330 mins') as delivery_date,
--     max(case when order_fares.fare_reason_code = 'INITIAL_BOOKING' then round(total_fare/100,0) end) as Customer_declared_fare,
--     max(case when order_fares.fare_reason_code = 'WEIGHT_REVISION_CHANGE' and is_active = True then round(total_fare/100,0) end) as Ops_fare,
--     coalesce(Ops_fare,Customer_declared_fare) as final_fare,
-- FROM prod_curated.partload_application.orders
-- LEFT JOIN prod_curated.partload_application.load_details ON load_details.order_id = orders.id
-- LEFT JOIN prod_curated.partload_application.order_fares ON ARRAY_CONTAINS(load_details.id, order_fares.load_details_ids)
-- where (date(orders.updated_at + interval '330 mins') >= '2025-12-01' and date(orders.updated_at + interval '330 mins') <= '2025-12-31')
-- AND orders.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
-- and state ='3'
-- group by 1,2
-- )

-- select 
-- 	count(distinct id) distinct_orders,
-- 	count(id) as orders,
-- 	sum(final_fare) as fare
-- from base