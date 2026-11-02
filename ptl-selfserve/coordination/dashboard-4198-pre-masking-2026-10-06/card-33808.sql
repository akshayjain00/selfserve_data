with online AS
(
    select 
        vehicle_id, 
        b.id as batch_id,
		CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(b.created_at))) AS DATE) AS batch_date,
        listagg(order_external_id, ', ') as order_external_ids, 
        round(sum(weight / 1000)) as weight_in_kg,
        round(sum(volumetric_weight / 1000)) as volumetric_weight_in_kg,
        round(max(weight_capacity)) as truck_capacity
    from partload_application.BATCH_V1 b 
    join partload_application.BATCHED_ORDERS_V1 bo on b.id = bo.batch_id
	join partload_application.jobs on jobs.batch_id = bo.batch_id
    join partload_application.load_details ld on ld.order_id = bo.order_id
    join partload_application.vehicles v on jobs.vehicle_id = v.id 
    join partload_application.vehicle_categories vc on vc.id = v.vehicle_categories_id
    join gsheet_sync.ptl_table ptl on ptl.order_id = bo.order_id
    join partload_application.orders o on o.id = bo.order_id
    left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS on PTL_INTERNAL_USERS.mobile = o.customer_mobile
    left join prod_curated.partload_analytics.ptl_routes 
    on ptl_routes.route_id=o.route_id and ptl_routes.is_active = 'True'
    where b.status = 2
    and b.created_at >= {{start_date}} - INTERVAL '330 MINS'
    and b.created_at <= {{end_date}} - INTERVAL '330 MINS'+ interval '1 day'
    [[and case when ptl_internal_users.mobile is null then 'False' when ptl_internal_users.mobile is not null then 'True' end = {{is_test}}]]
	[[and {{pickup_city}}]]
[[and {{drop_city}}]]
    

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
group by 1, 2, 3
)

,offline AS
(
    select 
        vehicle_id, 
        batch_id,
        CAST(DATE_TRUNC({{period}}, PICKUP_REACHED_TIMESTAMP::date) AS DATE) as batch_date,
        listagg(order_external_id, ', ') as order_external_ids, 
        round(sum(weight / 1000)) as weight_in_kg,
        round(sum(volumetric_weight / 1000)) as volumetric_weight_in_kg,
        round(max(weight_capacity)) as truck_capacity
    from prod_curated.gsheet_sync.ptl_offline_orders
    left join prod_curated.partload_analytics.ptl_routes
    on ptl_routes.route_id=ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
    where PICKUP_REACHED_TIMESTAMP::date >= {{start_date}}
    and PICKUP_REACHED_TIMESTAMP::date <= {{end_date}} 
	[[and {{pickup_city}}]]
    [[and {{drop_city}}]]
    group by 1, 2, 3
)

,final AS
(
SELECT *
FROM online

UNION ALL

SELECT *
FROM offline
)


select
	CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(batch_date))) AS DATE) AS dated,
    100 * sum(volumetric_weight_in_kg) / sum(truck_capacity) as estimated_utilization
from final
GROUP BY 1
ORDER BY 1