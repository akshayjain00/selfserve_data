
WITH orders_base AS (
    SELECT  
        o.id AS order_id,
        o.customer_id,
        o.customer_mobile,
        o.route_id,
        
        CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.created_at) AS created_at,
        o.state
    FROM partload_application.orders o
    
    WHERE o.customer_mobile NOT IN (
        SELECT mobile FROM partload_analytics.ptl_internal_users
    )
    AND DATE(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.created_at)) >= {{start_date}} 
      AND DATE(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', o.created_at)) <= {{end_date}}


[[and case when o.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = o.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < o.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
)


, orders_summary AS (
    SELECT  
        DATE_TRUNC({{frequency}}, DATE(created_at)) AS month,
        ptl_routes.pickup_city,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(DISTINCT CASE WHEN o.state = '3' THEN o.order_id END) AS completed_orders,
        COUNT(DISTINCT CASE WHEN o.state = '4' THEN o.order_id END) AS cancelled_orders
    FROM orders_base o
    LEFT JOIN prod_curated.partload_analytics.ptl_routes  
        ON ptl_routes.route_id = o.route_id and ptl_routes.is_active = 'True'
    GROUP BY 1,2
)

, route_orders AS (
  SELECT
    month,
    pickup_city,
    CASE 
      WHEN {{order_state}} = 'completed' THEN SUM(completed_orders)
      WHEN {{order_state}} = 'cancelled' THEN SUM(cancelled_orders)
      ELSE SUM(total_orders)
    END AS filtered_orders
  FROM orders_summary
  GROUP BY 1,2
)

SELECT 
    month,
    pickup_city,
    ROUND(
        filtered_orders / NULLIF(SUM(filtered_orders) OVER (PARTITION BY month), 0), 
        4
    ) AS pct_of_month_orders
FROM route_orders
ORDER BY month DESC, pct_of_month_orders DESC;
