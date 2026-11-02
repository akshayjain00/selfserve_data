WITH online AS (
    SELECT  
        CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC','Asia/Kolkata',TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
        route_name,
        external_id,
        weight
    FROM PROD_CURATED.PARTLOAD_APPLICATION.orders
    LEFT JOIN prod_curated.partload_application.load_details 
        ON orders.id = load_details.order_id
    LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
        ON PTL_INTERNAL_USERS.mobile = orders.customer_mobile
    LEFT JOIN prod_curated.partload_analytics.ptl_routes 
        ON ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
    WHERE CONVERT_TIMEZONE('UTC','Asia/Kolkata',TO_TIMESTAMP(orders.created_at)) >= {{start_date}}
      AND CONVERT_TIMEZONE('UTC','Asia/Kolkata',TO_TIMESTAMP(orders.created_at)) <= {{end_Date}} + INTERVAL '1 day'
      [[AND {{pickup_city}}]]
      [[AND {{drop_city}}]]
      [[AND CASE WHEN ptl_internal_users.mobile IS NULL THEN 'False'
                 ELSE 'True' END = {{is_test}}]]
	   AND load_details.is_active = True


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
),

offline AS (
    SELECT  
        CAST(DATE_TRUNC({{period}}, created_at::date) AS DATE) AS dated,
        route_name,
        external_id,
        weight
    FROM prod_curated.gsheet_sync.ptl_offline_orders
    LEFT JOIN prod_curated.partload_analytics.ptl_routes 
        ON ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
    WHERE created_at::date >= {{start_date}}
      AND created_at::date <= {{end_Date}}
      [[AND {{pickup_city}}]]
      [[AND {{drop_city}}]]
),

final AS (
    SELECT * FROM online
    UNION ALL
    SELECT * FROM offline
),

raw AS (
    SELECT 
        dated,
        route_name,
        weight,
        COUNT(DISTINCT external_id) AS orders
    FROM final
    GROUP BY 1,2,3
),

dist AS (
    SELECT
        dated,
        route_name,
        CASE
            WHEN weight <= 250000 THEN '0_250'
            WHEN weight <= 500000 THEN '251_500'
            WHEN weight <= 1000000 THEN '501_1000'
            WHEN weight <= 2000000 THEN '1001_2000'
            WHEN weight <= 3000000 THEN '2001_3000'
            ELSE 'gt_3000'
        END AS weight_bucket,
        orders,
        orders / SUM(orders) OVER (PARTITION BY dated, route_name) AS order_distribution_perc
    FROM raw
)

SELECT
    dated,
    route_name,
    SUM(orders) AS total_orders,
    SUM(CASE WHEN weight_bucket = '0_250'     THEN order_distribution_perc ELSE 0 END) AS bucket_0_250,
    SUM(CASE WHEN weight_bucket = '251_500'   THEN order_distribution_perc ELSE 0 END) AS bucket_251_500,
    SUM(CASE WHEN weight_bucket = '501_1000'  THEN order_distribution_perc ELSE 0 END) AS bucket_501_1000,
    SUM(CASE WHEN weight_bucket = '1001_2000' THEN order_distribution_perc ELSE 0 END) AS bucket_1001_2000,
    SUM(CASE WHEN weight_bucket = '2001_3000' THEN order_distribution_perc ELSE 0 END) AS bucket_2001_3000,
    SUM(CASE WHEN weight_bucket = 'gt_3000'   THEN order_distribution_perc ELSE 0 END) AS bucket_gt_3000

FROM dist
GROUP BY 1,2
ORDER BY 1, total_orders DESC; 