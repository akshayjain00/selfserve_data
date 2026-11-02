WITH online AS (
    SELECT 
        DISTINCT
        vendor_name,
        DATE_TRUNC('month', CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS month
    FROM PROD_CURATED.PARTLOAD_APPLICATION.orders
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.contact_details
        ON orders.id = contact_details.order_id
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.load_details
        ON orders.id = load_details.order_id
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.material_type
        ON load_details.material_type_id = material_type.material_type_id
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.order_vehicles
        ON orders.external_id = order_vehicles.order_external_id
    LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.ptl_internal_users
        ON ptl_internal_users.mobile = orders.customer_mobile
    LEFT JOIN PROD_CURATED.gsheet_sync."ptl_vendor_details" ptl
        ON REPLACE(REPLACE(UPPER(ptl.REGISTRATION_NUMBER), ' ', ''), '-', '') = REPLACE(REPLACE(UPPER(order_vehicles.VEHICLE_REGISTRATION_NUMBER), ' ', ''), '-', '') 
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.BATCHED_ORDERS_V1 
        ON BATCHED_ORDERS_V1.order_external_id = orders.external_id
    LEFT JOIN prod_curated.partload_analytics.ptl_routes 
        ON ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
    WHERE orders.updated_at >= {{start_date}} - INTERVAL '330 MINUTES'
      AND orders.updated_at <= {{end_date}} - INTERVAL '330 MINUTES' + INTERVAL '1 day'
      [[AND CASE WHEN ptl_internal_users.mobile IS NULL THEN 'False' ELSE 'True' END = {{is_test}}]]
      AND BATCHED_ORDERS_V1.status = 3
      AND orders.state = 3
      AND vendor_name IS NOT NULL
      [[AND {{pickup_city}}]]
      [[AND {{drop_city}}]]
	  

[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
order by 1
),

offline AS (
    SELECT 
        DISTINCT
        vendor_name,
        DATE_TRUNC('month', created_at::date) AS month
    FROM prod_curated.gsheet_sync.ptl_offline_orders
    LEFT JOIN prod_curated.partload_analytics.ptl_routes 
        ON ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
    WHERE created_at::date >= {{start_date}} 
      AND created_at::date <= {{end_date}}
      AND state = 3
      AND vendor_name IS NOT NULL
      [[AND {{pickup_city}}]]
      [[AND {{drop_city}}]]
),

final AS (
    SELECT * FROM online
    UNION ALL
    SELECT * FROM offline
),

vendor_months AS (
    SELECT DISTINCT vendor_name, month FROM final
),


first_orders AS (
    SELECT 
        vendor_name,
        MIN(month) AS first_order_month
    FROM vendor_months
    GROUP BY vendor_name
),

retention_matrix AS (
    SELECT 
        f.first_order_month AS cohort_month,
        DATEDIFF('month', f.first_order_month, o.month) AS month_since_signup,
        o.vendor_name
    FROM first_orders f
    JOIN final o
      ON f.vendor_name = o.vendor_name
    WHERE DATEDIFF('month', f.first_order_month, o.month) BETWEEN 0 AND 12
),

retention_summary AS (
    SELECT 
        cohort_month,
        month_since_signup,
        COUNT(DISTINCT vendor_name) AS retained_vendor_name
    FROM retention_matrix
    GROUP BY cohort_month, month_since_signup
),

cohort_sizes AS (
    SELECT 
        first_order_month AS cohort_month,
        COUNT(DISTINCT vendor_name) AS total_vendor_name
    FROM first_orders
    GROUP BY first_order_month
)


SELECT 
    date(r.cohort_month) as aquired_month,
    r.month_since_signup,
    CASE 
        WHEN r.month_since_signup = 0 THEN r.retained_vendor_name     -- Absolute for new signups (0)
        ELSE ROUND(100.0 * r.retained_vendor_name / c.total_vendor_name, 1)  -- % retention from month 1+
    END AS retention_value
FROM retention_summary r
JOIN cohort_sizes c ON r.cohort_month = c.cohort_month
ORDER BY r.cohort_month, r.month_since_signup;




