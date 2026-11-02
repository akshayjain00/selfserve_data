with wd_fare as (
	select 
		order_id,
		total_fare/100.0 as total_fare,
		is_current_fare,
		order_fare_id,
		IS_CUSTOMER_NOTIFIED
	from prod_curated.partload_application.order_fares of_ 
	inner join prod_curated.partload_application.fare_revision_notified nf on nf.order_fare_id = of_.id and nf.IS_CUSTOMER_NOTIFIED = 'true'
	where is_current_fare = 'true'
	order by 1 desc
	-- where order_id = '741'
)
, vehicle_cost as (
	select 
		driver_mobile,
		Vehicle_Registration_Number,
		REPLACE(g.TOTAL_VENDOR_PAYOUT, ',', '') AS trip_cost,
		o.state,
		o.external_id
	from prod_curated.partload_application.order_vehicles
	
	LEFT JOIN prod_curated.partload_application.orderS o on o.id = order_vehicles.ordeR_id
	left join prod_curated.gsheet_sync.PTL_TABLE g on o.id = g.order_id
	where is_Active = 'True'
	and o.state = '3'
	AND o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
	

[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
order by o.external_id
)

, online as(
	SELECT
	        o.external_id,
	        o.created_at + INTERVAL '330 MINS' as created_at,
	        o.state,
	        customer_mobile,
			COALESCE(wd_fare.total_fare, o.estimated_fare/100.0 ) AS final_fare,
	        o.route_id,
	        CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at))) AS DATE) AS dated,
	        batch_id,
	        trip_cost,
	        Vehicle_Registration_Number
		
	FROM prod_curated.partload_application.orders o
	
	LEFT JOIN wd_fare on wd_fare.order_id = o.id
	LEFT JOIN prod_curated.partload_analytics.ptl_routes ON ptl_routes.route_id = o.route_id and ptl_routes.is_active = 'True'
	LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.BATCHED_ORDERS_V1 ON BATCHED_ORDERS_V1.order_external_id = o.external_id and BATCHED_ORDERS_V1.status = '3' -- 3 represents completed
	LEFT JOIN vehicle_cost VC on vc.external_id = O.EXTERNAL_ID
	
	-- LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.order_vehicles ON o.external_id = order_vehicles.order_external_id and order_vehicles.is_active = 'true'
	-- LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.vehicle_availability ON REPLACE(REPLACE(UPPER(vehicle_availability.vehicle_registration_no), ' ', ''), '-', '') = REPLACE(REPLACE(UPPER(order_vehicles.vehicle_registration_number), ' ', ''), '-', '')
	
	WHERE 
	o.state = 3 AND 
	o.customer_mobile NOT IN (SELECT mobile FROM prod_curated.partload_analytics.ptl_internal_users)
	and o.created_at >= {{start_date}} - INTERVAL '330 MINS'
	and o.created_at <= {{end_date}} - INTERVAL '330 MINS'+ interval '1 day'
	
	[[and {{pickup_city}}]]
	[[and {{drop_city}}]]
	-- and o.external_id = 'CRN93D740B6' --trial


[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)

-- select * from online

,offline as (
    SELECT
        external_id,
        created_at,
        state,
        customer_mobile,
        estimated_fare as final_fare,
        ptl_offline_orders.route_id,
        CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
        batch_id,
        trip_cost,
        VEHICLE_NUMBER as VEHICLE_REGISTRATION_NO
    FROM prod_curated.gsheet_sync.ptl_offline_orders
    LEFT JOIN prod_curated.partload_analytics.ptl_routes
        ON ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
    WHERE state = 3
      AND created_at::date >= {{start_date}} 
      and created_at::date <= {{end_date}} 
    [[AND {{pickup_city}}]]
    [[AND {{drop_city}}]]
)
,final AS (
	SELECT *
	FROM online
	
	UNION 
	
	SELECT *
	FROM offline
)
-- select * from final

,agg_metrics AS (
    SELECT
        dated,
        -- SUM(final_fare / 100.0) AS quotation,
        -- SUM(actual_fare - (estimated_fare / 100.0)) AS wd_fare,
        SUM(final_fare) AS total_revenue,
        SUM(final_fare) / COUNT(DISTINCT CASE WHEN state = 3 THEN external_id END) AS aov
    FROM final
    GROUP BY dated
)

, vendor_costs AS (
    SELECT
        dated,
        batch_id,
        MAX(trip_cost) AS vendor_earning
    FROM final
    GROUP BY dated, batch_id
)

, final_vendor_costs AS (
    SELECT
        dated,
        SUM(vendor_earning) AS total_cost
    FROM vendor_costs
    GROUP BY dated
)

SELECT
    agg_metrics.dated,
	agg_metrics.aov,
    agg_metrics.total_revenue,
    final_vendor_costs.total_cost,
    (agg_metrics.total_revenue - final_vendor_costs.total_cost)/(agg_metrics.total_revenue) AS gm
FROM agg_metrics
LEFT JOIN final_vendor_costs
    ON agg_metrics.dated = final_vendor_costs.dated
ORDER BY agg_metrics.dated desc;
