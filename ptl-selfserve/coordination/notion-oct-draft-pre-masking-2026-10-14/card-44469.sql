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
-- *,
    date_trunc({{granularity}}, date(event_timestamp)) as month,
	CASE
        WHEN base.first_order_date IS NULL
             OR DATE(event_timestamp) <= DATE(base.first_order_date)
        THEN 'new customer'
        ELSE 'repeat customer'
    END AS customer_tag,
	
	count(distinct case when event_name = 'ptlbookingdetailspage_quote_viewed' then app_session_id end) as quote_sessions,
    count(distinct case when event_name = 'ptlbookingdetailspage_booknow_clicked'  AND (
              {{order_type}} = 'overall'
              OR ({{order_type}} = 'completed' AND o.state = '3')
         )  then app_session_id end) as book_now_sessions,
    count(distinct case when event_name = 'ptlbookingdetailspage_booknow_clicked'  AND (
              {{order_type}} = 'overall'
              OR ({{order_type}} = 'completed' AND o.state = '3')
         )  then app_session_id end) /count(distinct case when event_name = 'ptlbookingdetailspage_quote_viewed' then app_session_id end)  as conversion_pct

from partload_analytics.ptl_fe_events 
left join base on base.customer_mobile = ptl_fe_events.customer_mobile_number
left join partload_analytics.ptl_routes on ptl_routes.route_id = try_to_number(TRY_PARSE_JSON(VARIABLE_ATTR):route_id::INT) and ptl_routes.is_active = 'True'
left JOIN partload_application.orders o ON PARSE_JSON(variable_attr):order_id::STRING = o.external_id
LEFT JOIN prod_curated.oms_public.customers c
        ON c.mobile = ptl_fe_events.customer_mobile_number
where 1=1
and customer_mobile_number not in (select mobile from partload_analytics.ptl_internal_users) 
and event_name in ('ptlbookingdetailspage_quote_viewed', 'ptlbookingdetailspage_booknow_clicked')
and app_session_id != 'dbe3759b-bd16-4523-9f24-1c0f45e34c2a'
[[AND date(event_timestamp) >= {{START_DATE}} AND date(event_timestamp) <= {{END_DATE}}]]
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
 [[AND (
    CASE
        WHEN c.frequency IN (1, 2, 3, 4) THEN 'Business'
        ELSE 'Personal'
    END
) = {{category}}]]
group by 1,2
order by 1 desc
;