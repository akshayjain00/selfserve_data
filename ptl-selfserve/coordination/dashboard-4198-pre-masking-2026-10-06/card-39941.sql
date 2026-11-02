WITH orders_base AS (
    SELECT  
        id AS order_id,
        route_id,
        state,
        orders.created_at + INTERVAL '5 HOURS, 30 MINUTES' AS created_at
    FROM PARTLOAD_APPLICATION.orders
    WHERE customer_mobile NOT IN (SELECT mobile FROM PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)
      AND (orders.created_at)::timestamp >= {{start_date}} - interval '330 mins'
      AND (orders.created_at)::timestamp <= {{end_date}} - interval '330 mins' + interval '1 day'


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)

, route_orders_summary AS (
    SELECT
        DATE_TRUNC({{frequency}}, created_at) AS period,
        route_id,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(DISTINCT CASE WHEN state = '4' THEN order_id END) AS cancel_orders
    FROM orders_base
    GROUP BY 1, 2
)

SELECT
    ros.period AS period,
    r.route_name,
    ros.cancel_orders,
    ros.total_orders,
    ROUND(ros.cancel_orders  / NULLIF(ros.total_orders, 0), 2) AS cancellation_pct
FROM route_orders_summary ros
LEFT JOIN prod_curated.partload_analytics.ptl_routes r
    ON r.route_id = ros.route_id and r.is_active = 'True'
WHERE 1=1
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
ORDER BY ros.period DESC, ros.cancel_orders DESC;
