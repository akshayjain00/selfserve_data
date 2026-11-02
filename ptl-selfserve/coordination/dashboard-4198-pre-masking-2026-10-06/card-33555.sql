 select 
-- distinct weight_capacity as capacity,
date_trunc({{granularity}}, date(o.created_At + interval '330 mins')) as month,
count(VEHICLE_REGISTRATION_NUMBER) as supply,
( vehicle_type) as vehcile_types
from partload_application.ORDER_VEHICLES v
left join partload_application.orders o on o.external_id = v.ORDER_EXTERNAL_ID
left join partload_analytics.ptl_routes on ptl_routes.route_id = o.route_id
-- LEFT JOIN partoad_analytics.PTL_VEHICLE_ZONE pvz 
    -- ON pvz.service_zone_id = v.service_zone_id
where date(o.created_At + interval '330 mins') >= {{start_date}} and date(o.created_At + interval '330 mins') <= {{end_date}}
and date(o.created_At + interval '330 mins') >= '2026-01-01'
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
and v.is_active = 'true'
and o.state = '3'


[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
group by 1,3
order by 1 asc
-- limit 10
