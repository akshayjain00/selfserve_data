with base as (
	select 
		id as o_id,
		EXTERNAL_ID,
		pickup_slot_Start + interval '330 mins' as slot_Start,
		ptl_routes.pickup_City,
		ESTIMATED_DELIVERY_TS + interval '330 mins' as edd,
		CASE 
	    WHEN ORDERS.state = 0 THEN 'Open' 
	    WHEN ORDERS.state = 1 THEN 'Assigned' 
	    WHEN ORDERS.state = 2 THEN 'Picked_up' 
	    WHEN ORDERS.state = 3 THEN 'Completed'  
	    WHEN ORDERS.state = 4 THEN 'Cancelled' 
		end 
		as order_state
	from partload_application.orders
	left join partload_analytics.ptl_routes on ptl_routes.route_id = orders.route_id
	where 1=1
	and date(pickup_slot_Start + interval '330 mins') <= CURRENT_DATE -- Interval '1 day'
	and date(edd) <= CURRENT_DATE -- Interval '1 day'
	and orders.state not in ('4', '3')
	and edd is not null
	and customer_mobile not in (select mobile from partload_analytics.PTL_INTERNAL_USERS )
	[[and {{route_name}}]]
	[[and {{pickup_City}}]]
	order by edd asc
)
select 
	edd,
	pickup_City,
	order_state,
	count(distinct o_id) as orders,
	array_agg(distinct o_id) as orders_id,
	array_agg(distinct external_id) as external_id,
	-- ARRAY_SORT(ARRAY_AGG(DISTINCT TO_VARCHAR(edd, 'DD-MM HH24:MI'))) AS edd_list
from base
WHERE EDD <= CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', CURRENT_TIMESTAMP())
group by 1,2,3
order by 1 desc