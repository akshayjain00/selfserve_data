WITH base_data AS (
    SELECT
        CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
        actual_goods_type,
        display_name,
        orders.external_id
    FROM
        PROD_CURATED.PARTLOAD_APPLICATION.orders
    LEFT JOIN
        gsheet_sync.ptl_table ON ptl_table.order_id = orders.id
    LEFT JOIN
        prod_curated.partload_application.load_details ON orders.id = load_details.order_id
    LEFT JOIN
        prod_curated.partload_application.material_type ON material_type.material_type_id = load_details.material_type_id
    LEFT JOIN
        PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS ON PTL_INTERNAL_USERS.mobile = orders.customer_mobile
    LEFT JOIN
        prod_curated.partload_analytics.ptl_routes ON ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
    WHERE
        CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at)) >= {{start_date}}
        AND CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at)) <= {{end_date}}+ interval '1 day'
        [[AND
          CASE
            WHEN ptl_internal_users.mobile IS NULL THEN 'False'
            ELSE 'True'
          END = {{is_test}}]]
        [[AND {{pickup_city}}]]
        [[AND {{drop_city}}]]
        AND orders.state = 3 


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
),
flagged_data AS (
    SELECT
        dated,
        external_id,
        display_name,
        CASE
            WHEN actual_goods_type IS NOT NULL AND (
                
                (
                    LOWER(display_name) = 'general / others'
                    AND LOWER(actual_goods_type) != 'general / others'
                    AND (
                        LOWER('general / others') LIKE '%' || LOWER(actual_goods_type) || '%'
                        OR LOWER(actual_goods_type) LIKE '%pvc / plaster of paris%'
                        OR LOWER(actual_goods_type) LIKE '%packaging material (foam, thermocol)%'
                        OR LOWER(actual_goods_type) LIKE '%furniture%'
                        OR LOWER(actual_goods_type) LIKE '%plastic%'
                    )
                )
                OR
                (
                    LOWER(display_name) != 'general / others'
                    AND LOWER(display_name) != LOWER(actual_goods_type)
                    AND (
                        NOT (LOWER(actual_goods_type) LIKE '%' || LOWER(display_name) || '%')
                        AND NOT (LOWER(display_name) LIKE '%' || LOWER(actual_goods_type) || '%')
                    )
                )
            ) THEN 1
            ELSE 0
        END AS is_discrepancy_flag
    FROM
        base_data
),

daily_category_summary AS (
    SELECT
        dated,
        LOWER(display_name) AS display_name_lower, 
        COUNT(DISTINCT external_id) AS total_orders_category,
        COUNT(DISTINCT CASE WHEN is_discrepancy_flag = 1 THEN external_id END) AS discrepancy_orders_category
    FROM
        flagged_data
    GROUP BY
        dated,
        LOWER(display_name)
)

SELECT
    dated,
    SUM(total_orders_category) AS total_orders,
    COALESCE(SUM(discrepancy_orders_category), 0) * 1.0 / NULLIF(SUM(total_orders_category), 0) AS overall_goods_discrepancy_ratio,
    COALESCE(SUM(CASE WHEN display_name_lower = 'general / others' THEN discrepancy_orders_category ELSE 0 END), 0) * 1.0 /
    NULLIF(SUM(total_orders_category), 0) AS "General / Others",
    COALESCE(SUM(CASE WHEN display_name_lower = 'pvc / plaster of paris' THEN discrepancy_orders_category ELSE 0 END), 0) * 1.0 /
    NULLIF(SUM(total_orders_category), 0) AS "PVC / Plaster of Paris",
    COALESCE(SUM(CASE WHEN display_name_lower = 'packaging material (foam, thermocol)' THEN discrepancy_orders_category ELSE 0 END), 0) * 1.0 /
    NULLIF(SUM(total_orders_category), 0) AS "Packaging material",
    COALESCE(SUM(CASE WHEN display_name_lower = 'furniture' THEN discrepancy_orders_category ELSE 0 END), 0) * 1.0 /
    NULLIF(SUM(total_orders_category), 0) AS "Furniture",
    COALESCE(SUM(CASE WHEN display_name_lower = 'plastic' THEN discrepancy_orders_category ELSE 0 END), 0) * 1.0 /
    NULLIF(SUM(total_orders_category), 0) AS "Plastic"
FROM
    daily_category_summary
GROUP BY
    dated
ORDER BY
    dated DESC;