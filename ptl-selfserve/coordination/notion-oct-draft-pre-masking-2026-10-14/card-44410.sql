with base as (
    SELECT
        customer_mobile,
        created_at + interval '330 mins' AS first_order_date,
		TO_VARCHAR(created_at + INTERVAL '330 mins', 'YYYY-MM') AS year_month,
        external_id AS first_order_id
    FROM partload_application.orders
	WHERE 1=1
	AND (
	    ({{order_type}} = 'completed' AND orders.state = '3')
	    OR {{order_type}} = 'overall'
	)

    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_mobile ORDER BY created_at ASC) = 1
)

select 
    date_trunc({{granularity}}, date(event_timestamp)) as month,
	count(distinct case when event_name = 'vehicleselectionscreen_vehicles_loaded' then app_session_id end) as vss_sessions,
	count(distinct case when event_name = 'ptlbookingdetailspage_quote_viewed' then app_session_id end) as quote_sessions,
    COUNT(DISTINCT CASE
        WHEN event_name = 'ptlbookingdetailspage_booknow_clicked'
         AND (
              {{order_type}} = 'overall'
              OR ({{order_type}} = 'completed' AND o.state = '3')
         )
        THEN app_session_id
		END) AS book_now_sessions,
    COUNT(DISTINCT CASE
            WHEN event_name = 'ptlbookingdetailspage_booknow_clicked'
             AND (
                  {{order_type}} = 'overall'
                  OR ({{order_type}} = 'completed' AND o.state = '3')
             )
            THEN app_session_id
        END)
/ NULLIF(
    count(distinct case 
        when event_name = 'vehicleselectionscreen_vehicles_loaded' 
        then app_session_id 
    end), 
    0
) AS conversion_pct,
	book_now_sessions / NULLIF(quote_sessions, 0) AS quote_to_order


from partload_analytics.ptl_fe_events 
LEFT JOIN partload_application.orders o
    ON PARSE_JSON(variable_attr):order_id::STRING = o.external_id
left join partload_analytics.ptl_routes on ptl_routes.route_id = try_to_number(TRY_PARSE_JSON(VARIABLE_ATTR):route_id::INT) and ptl_routes.is_active = 'True'
where 1=1
and customer_mobile_number not in (select mobile from partload_analytics.ptl_internal_users) 
and event_name in ('vehicleselectionscreen_vehicles_loaded','ptlbookingdetailspage_quote_viewed', 'ptlbookingdetailspage_booknow_clicked')
and app_session_id != 'dbe3759b-bd16-4523-9f24-1c0f45e34c2a'
[[AND date(event_timestamp) >= {{START_DATE}} AND date(event_timestamp) <= {{END_DATE}}]]
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
group by 1
order by 1 asc
;