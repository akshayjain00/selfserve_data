with slots as
(
select distinct
CONCAT(
  TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_start)), 'HH24:MI'),
  ' - ',
  TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_end)), 'HH24:MI')
) AS slot,
CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_start))::TIME AS start_time,
    CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_end))::TIME AS end_time
    FROM partload_application.orders
	left join prod_curated.partload_analytics.ptl_routes
	on ptl_routes.ROUTE_ID=orders.ROUTE_ID and ptl_routes.is_active = 'True'
	where DATE(CREATED_AT) >= {{start_date}} - interval '330 minute'
	AND DATE(CREATED_AT) <= {{end_date}} - interval '330 minute'
	and customer_mobile NOT IN (SELECT mobile FROM partload_analytics.ptl_internal_users)
	[[AND {{ROUTE_NAME}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)

,os_orders AS (
  SELECT
    DATE_TRUNC({{frequency}}, oot.CREATED_AT + INTERVAL '330 minute') AS month,
    pr.ROUTE_NAME,
    'OS' AS source,
    s.slot,
	  COUNT(DISTINCT ORDER_ID) AS placed_orders,
	  COUNT(DISTINCT CASE WHEN status = 4 THEN ORDER_ID END) AS completed_orders
	FROM prod_curated.trucks.outstation_orders_temp oot
  INNER JOIN prod_curated.partload_analytics.ptl_routes pr 
    ON pr.pickup_city = oot.CITY 
   AND pr.drop_city = (
        CASE
		      WHEN oot.DROP_CITY ILIKE '%Bengaluru%' THEN 'Bangalore'
		      WHEN oot.DROP_CITY ILIKE 'Mumbai%' THEN 'Mumbai'
		      WHEN oot.DROP_CITY ILIKE '%Tumakuru%' THEN 'Tumkur'
			  WHEN oot.DROP_CITY ILIKE '%Ahmadabad%' then 'Ahmedabad'
		      ELSE oot.DROP_CITY
		    END
    )  		  AND date(oot.CREATED_AT + interval '330 minutes')
                     BETWEEN date(ROUTE_CREATED_AT)
                       AND date(
                   CASE 
                        WHEN ROUTE_CREATED_AT = ROUTE_UPDATED_AT OR ROUTE_UPDATED_AT IS NULL 
                   THEN '9999-12-31'
                   ELSE ROUTE_UPDATED_AT
               END )

  LEFT JOIN slots s
    ON (oot.CREATED_AT + INTERVAL '330 minute')::TIME >= s.start_time
   AND (oot.CREATED_AT + INTERVAL '330 minute')::TIME <= s.end_time
  WHERE DATE(oot.CREATED_AT) BETWEEN {{start_date}} - INTERVAL '330 minute' AND {{end_date}} - INTERVAL '330 minute'
  and ST_CONTAINS(TO_GEOGRAPHY(DROP_SERVICIBILITY_ZONE), TO_GEOGRAPHY(CONCAT('POINT(', to_address_long, ' ', to_address_lat, ')'))) = 'True'
  group by 1,2,3,4
)
,

first_os_order as (
	 SELECT
	  ROUTE_NAME,
	  min(date(CREATED_AT+ interval '5 hours, 30 minute')) as first_order,
	  'os_live' as flag
	FROM prod_curated.trucks.outstation_orders_temp
	INNER JOIN prod_curated.partload_analytics.ptl_routes 
	    ON ptl_routes.pickup_city = outstation_orders_temp.CITY 
	    AND ptl_routes.drop_city = (
	        CASE
		      WHEN outstation_orders_temp.DROP_CITY ILIKE '%Bengaluru%' THEN 'Bangalore'
		      WHEN outstation_orders_temp.DROP_CITY ILIKE 'Mumbai%' THEN 'Mumbai'
		      WHEN outstation_orders_temp.DROP_CITY ILIKE '%Tumakuru%' THEN 'Tumkur'
			  WHEN outstation_orders_temp.DROP_CITY ILIKE '%Ahmadabad%' then 'Ahmedabad'
		      ELSE outstation_orders_temp.DROP_CITY
		    END
	    ) and ptl_routes.is_active = 'True'
	WHERE 1=1 AND ST_CONTAINS(TRY_TO_GEOGRAPHY(DROP_SERVICIBILITY_ZONE), TO_GEOGRAPHY(CONCAT('POINT(', to_address_long, ' ', to_address_lat, ')'))) = 'True'
	GROUP BY 1
)


,ptl_orders_base AS (
    SELECT  
        DATE_TRUNC({{frequency}}, orders.created_At + INTERVAL '5 hours, 30 minutes') AS month,
        ROUTE_NAME,
        'PTL' AS source,
		CONCAT(
  TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_start)), 'HH24:MI'),
  ' - ',
  TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(pickup_slot_end)), 'HH24:MI')
) AS slot,
COUNT(DISTINCT order_id) AS placed_orders,
COUNT(DISTINCT CASE WHEN state = '3' THEN order_id END) AS completed_orders,
    FROM partload_application.orders
    LEFT JOIN prod_curated.partload_application.load_details 
        ON orders.id = load_details.order_id
	left join prod_curated.partload_analytics.ptl_routes
	on ptl_routes.ROUTE_ID=orders.ROUTE_ID and ptl_routes.is_active = 'True'
    WHERE customer_mobile NOT IN (SELECT mobile FROM partload_analytics.ptl_internal_users)
	AND orders.created_At BETWEEN {{start_date}} - INTERVAL '330 min' AND {{end_date}} - INTERVAL '330 min'
	 [[AND {{ROUTE_NAME}}]]
	 [[AND {{pickup_city}}]]
	 [[AND {{drop_city}}]]
	 

[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
group by 1,2,3,4
)


SELECT 
    date(ptl.month) as month,
	ptl.ROUTE_NAME as route,
	ptl.slot,
	COALESCE(SUM(ptl.placed_orders), 0) AS ptl_placed_orders,
    COALESCE(SUM(ptl.completed_orders), 0) AS ptl_completed_orders,
    COALESCE(SUM(os.placed_orders), 0) AS os_placed_orders,
    COALESCE(SUM(os.completed_orders), 0) AS os_completed_orders,
    COALESCE(SUM(ptl.completed_orders), 0)/nullif(SUM(ptl.placed_orders), 0) AS PTL_FULFILLMENT,
    COALESCE(SUM(os.completed_orders), 0)/nullif(SUM(os.placed_orders), 0) AS OS_FULFILLMENT
FROM ptl_orders_base ptl
LEFT JOIN os_orders os 
    ON os.ROUTE_NAME = ptl.ROUTE_NAME AND os.month = ptl.month and os.slot = ptl.slot
inner join first_os_order on first_os_order.ROUTE_NAME = ptl.ROUTE_NAME --and {{start_date}} >= first_order

WHERE 1=1
and ptl.month >= date_trunc('month', first_os_order.first_order)
GROUP BY ptl.month, 2,3
ORDER BY ptl.month desc, slot;
