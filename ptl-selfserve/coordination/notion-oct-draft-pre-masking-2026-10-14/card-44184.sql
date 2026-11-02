WITH user_category AS (
    SELECT
        c.mobile AS customer_mobile_number,
        CASE 
            WHEN c.frequency IN (1,2,3,4) THEN 'Business'
            ELSE 'Personal'
        END AS category
    FROM prod_curated.oms_public.customers c
),

vss_users AS (
    SELECT
        e.customer_mobile_number,
        DATE_TRUNC({{frequency}}, e.event_timestamp) AS period
    FROM partload_analytics.ptl_fe_events e
   LEFT JOIN partload_analytics.ptl_routes
  ON ptl_routes.route_id =
     TRY_TO_NUMBER(NULLIF(TRY_PARSE_JSON(VARIABLE_ATTR):route_id::STRING, ''))
 AND ptl_routes.is_active = 'True'


    WHERE e.event_name = 'vehicleselectionscreen_vehicles_loaded'
      AND DATE(e.event_timestamp) BETWEEN {{start_date}} AND {{end_date}}
      AND e.customer_mobile_number NOT IN (
            SELECT mobile FROM partload_analytics.ptl_internal_users
      )
	  [[and {{pickup_city}}]]
    [[and {{drop_city}}]]
	) 
,

first_placed AS (
    SELECT
        e.customer_mobile_number,
        MIN(e.event_timestamp) AS first_placed_ts
    FROM partload_analytics.ptl_fe_events e
    LEFT JOIN partload_application.orders o
       ON PARSE_JSON(e.variable_attr):order_id::STRING = o.external_id
   LEFT JOIN partload_analytics.ptl_routes
  ON ptl_routes.route_id =
     TRY_TO_NUMBER(NULLIF(TRY_PARSE_JSON(VARIABLE_ATTR):route_id::STRING, ''))
 AND ptl_routes.is_active = 'True'

    WHERE e.event_name = 'ptlbookingdetailspage_booknow_clicked'
      AND e.customer_mobile_number NOT IN (
            SELECT mobile FROM partload_analytics.ptl_internal_users
      )
       [[and {{pickup_city}}]]
    [[and {{drop_city}}]]
    GROUP BY e.customer_mobile_number
),

placed_in_period AS (
    SELECT
        customer_mobile_number,
        DATE_TRUNC({{frequency}}, first_placed_ts) AS period
    FROM first_placed
)

SELECT
    v.period,

    /* ---------- BUSINESS ---------- */
    COUNT(DISTINCT CASE
        WHEN uc.category = 'Business'
        THEN v.customer_mobile_number
    END) AS business_vss_users,

    COUNT(DISTINCT CASE
        WHEN uc.category = 'Business'
             AND p.customer_mobile_number IS NOT NULL
        THEN v.customer_mobile_number
    END) AS business_placed_users,

    ROUND(
        COUNT(DISTINCT CASE
            WHEN uc.category = 'Business'
                 AND p.customer_mobile_number IS NOT NULL
            THEN v.customer_mobile_number
        END)
        / NULLIF(
            COUNT(DISTINCT CASE
                WHEN uc.category = 'Business'
                THEN v.customer_mobile_number
            END),
            0
        ),
        4
    ) AS business_activation_pct,

    /* ---------- PERSONAL ---------- */
    COUNT(DISTINCT CASE
        WHEN uc.category = 'Personal'
        THEN v.customer_mobile_number
    END) AS personal_vss_users,

    COUNT(DISTINCT CASE
        WHEN uc.category = 'Personal'
             AND p.customer_mobile_number IS NOT NULL
        THEN v.customer_mobile_number
    END) AS personal_placed_users,

    ROUND(
        COUNT(DISTINCT CASE
            WHEN uc.category = 'Personal'
                 AND p.customer_mobile_number IS NOT NULL
            THEN v.customer_mobile_number
        END)
        / NULLIF(
            COUNT(DISTINCT CASE
                WHEN uc.category = 'Personal'
                THEN v.customer_mobile_number
            END),
            0
        ),
        4
    ) AS personal_activation_pct

FROM vss_users v
LEFT JOIN user_category uc
    ON v.customer_mobile_number = uc.customer_mobile_number
LEFT JOIN placed_in_period p
    ON v.customer_mobile_number = p.customer_mobile_number
   AND v.period = p.period

GROUP BY v.period
ORDER BY v.period;
