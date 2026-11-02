SELECT 
	CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
    CASE 
        WHEN DATEDIFF('second', created_at, updated_at) / 60 <= 5 THEN '0–5 mins'
        WHEN DATEDIFF('second', created_at, updated_at) / 60 <= 15 THEN '5–15 mins'
        WHEN DATEDIFF('second', created_at, updated_at) / 60 <= 30 THEN '15–30 mins'
        ELSE '> 30 mins'
    END AS cancellation_time_bucket,
    COUNT(*) AS cancelled_orders,
    
    SUM(COUNT(*)) OVER (PARTITION BY dated) AS total_cancelled_orders,
	cancelled_orders/total_cancelled_orders as pct

FROM PROD_CURATED.PARTLOAD_APPLICATION.orders
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id=orders.route_id and ptl_routes.is_active = 'True'
WHERE CUSTOMER_MOBILE NOT IN (SELECT MOBILE FROM PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)
AND state = 4
and CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))::date >=  {{start_date}}
	and CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))::date <= {{end_date}}
[[and {{pickup_city}}]]
[[and {{drop_city}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
GROUP by 1, 2
