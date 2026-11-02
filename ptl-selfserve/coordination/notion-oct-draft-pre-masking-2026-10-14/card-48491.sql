WITH repeat_customers AS (                                                                      
      -- First completed order date per customer (STATE=3 = completed)
      SELECT CUSTOMER_MOBILE, MIN(created_at+interval '330 mins') AS first_completed_at                          
      FROM partload_application.orders                                                            
      WHERE STATE = 3                                                                       
      GROUP BY CUSTOMER_MOBILE                                                             
  ),                                                                                              
                  
  vehicles_loaded AS (
      SELECT
          DATE_TRUNC({{granularity}}, t.EVENT_TIMESTAMP + interval '330 mins') AS month,
          COUNT(DISTINCT t.APP_SESSION_ID) AS vehicles_loaded_sessions
      FROM partload_analytics.ptl_fe_events t                                                     
      CROSS JOIN LATERAL FLATTEN(
          INPUT => TRY_PARSE_JSON(                                                                
                      TRY_PARSE_JSON(t.variable_attr):vehicle_ids_seq                             
                  )                                                                               
      ) f                                                                                         
      LEFT JOIN prod_eldoria.core.dim_customers dc                                                
          ON dc.customer_id = t.customer_id                                                       
      LEFT JOIN repeat_customers rc                                                               
          ON rc.CUSTOMER_MOBILE = t.customer_mobile_number     
	 LEFT JOIN partload_analytics.ptl_routes
        ON ptl_routes.route_id = TRY_TO_NUMBER(TRY_PARSE_JSON(t.variable_attr):route_id::STRING)
       AND ptl_routes.is_active = 'True'
      WHERE f.value::NUMBER IN (-1, 1159)                                                         
        AND t.event_name = 'vehicleselectionscreen_vehicles_loaded'                               
        AND t.customer_mobile_number NOT IN (                                                     
            SELECT mobile FROM partload_analytics.ptl_internal_users                              
        )                                                                                         
        [[AND (                                                                                   
              CASE                                                                                
                  WHEN dc.frequency IN (1,2,3,4) THEN 'Business'
                  ELSE 'Personal'                                                                 
              END
          ) = {{user_type}}]]                                                                     
        [[AND (                                                                                   
              CASE
                  WHEN date(rc.first_completed_at) < date(t.EVENT_TIMESTAMP  + interval '330 mins') THEN 'Repeat'                    
                  ELSE 'New'                                                                      
              END                                                                                 
          ) = {{customer_type}}]]  
		   [[AND {{route_name}}]]
        AND (t.EVENT_TIMESTAMP + interval '330 mins')::date >= {{start_date}}        
        AND (t.EVENT_TIMESTAMP + interval '330 mins')::date <= {{end_date}}          
      GROUP BY 1                                                                                  
  ),                                                                                              
vehicles_ptl_selected as(
 SELECT
        DATE_TRUNC({{granularity}}, t.EVENT_TIMESTAMP + interval '330 mins') AS month,
        COUNT(DISTINCT t.APP_SESSION_ID) AS ptl_selected_sessions
    FROM partload_analytics.ptl_fe_events t
    LEFT JOIN prod_eldoria.core.dim_customers dc ON dc.customer_id = t.customer_id
    LEFT JOIN repeat_customers rc ON rc.CUSTOMER_MOBILE = t.customer_mobile_number
    LEFT JOIN partload_analytics.ptl_routes
        ON ptl_routes.route_id = TRY_TO_NUMBER(TRY_PARSE_JSON(t.variable_attr):route_id::STRING)
       AND ptl_routes.is_active = 'True'
    WHERE t.event_name = 'vehicleselectionscreen_confirm_clicked'
      AND TRY_PARSE_JSON(t.variable_attr):vehicle_id::STRING IN ('-1', '1159')
      AND t.customer_mobile_number NOT IN (SELECT mobile FROM partload_analytics.ptl_internal_users)
      [[AND (CASE WHEN dc.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END) = {{user_type}}]]
      [[AND (CASE WHEN date(rc.first_completed_at) < date(t.EVENT_TIMESTAMP + interval '330 mins') THEN 'Repeat' ELSE 'New' END) = {{customer_type}}]]
      [[AND {{route_name}}]]
      AND (t.EVENT_TIMESTAMP + interval '330 mins')::date >= {{start_date}}
      AND (t.EVENT_TIMESTAMP + interval '330 mins')::date <= {{end_date}}
    GROUP BY 1
) ,
quote_viewed as(
SELECT
        DATE_TRUNC({{granularity}}, t.EVENT_TIMESTAMP + interval '330 mins') AS month,
        COUNT(DISTINCT t.APP_SESSION_ID) AS quote_viewed_sessions
    FROM partload_analytics.ptl_fe_events t
    LEFT JOIN prod_eldoria.core.dim_customers dc ON dc.customer_id = t.customer_id
    LEFT JOIN repeat_customers rc ON rc.CUSTOMER_MOBILE = t.customer_mobile_number
    LEFT JOIN partload_analytics.ptl_routes
        ON ptl_routes.route_id = TRY_TO_NUMBER(TRY_PARSE_JSON(t.variable_attr):route_id::STRING)
       AND ptl_routes.is_active = 'True'
    WHERE t.event_name = 'ptlbookingdetailspage_quote_viewed'
      AND t.customer_mobile_number NOT IN (SELECT mobile FROM partload_analytics.ptl_internal_users)
      [[AND (CASE WHEN dc.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END) = {{user_type}}]]
      [[AND (CASE WHEN date(rc.first_completed_at) < date(t.EVENT_TIMESTAMP + interval '330 mins') THEN 'Repeat' ELSE 'New' END) = {{customer_type}}]]
      [[AND {{route_name}}]]
      AND (t.EVENT_TIMESTAMP + interval '330 mins')::date >= {{start_date}}
      AND (t.EVENT_TIMESTAMP + interval '330 mins')::date <= {{end_date}}
    GROUP BY 1
)
 , booknow_clicked AS (
      SELECT
          DATE_TRUNC({{granularity}}, EVENT_TIMESTAMP + interval '330 mins') AS month,
          COUNT(DISTINCT APP_SESSION_ID) AS booknow_clicked_sessions                              
      FROM partload_analytics.ptl_fe_events
      LEFT JOIN prod_eldoria.core.dim_customers dc                                                
          ON dc.customer_id = ptl_fe_events.customer_id                                           
      LEFT JOIN repeat_customers rc                                                               
          ON rc.CUSTOMER_MOBILE = ptl_fe_events.customer_mobile_number       
	 LEFT JOIN partload_analytics.ptl_routes
        ON ptl_routes.route_id = TRY_TO_NUMBER(TRY_PARSE_JSON(ptl_fe_events.variable_attr):route_id::STRING)
       AND ptl_routes.is_active = 'True'
      WHERE event_name = 'ptlbookingdetailspage_booknow_clicked'                                  
        AND customer_mobile_number NOT IN (                                                       
            SELECT mobile FROM partload_analytics.ptl_internal_users                              
        )                                                                                         
        [[AND (   
              CASE                                                                                
                  WHEN dc.frequency IN (1,2,3,4) THEN 'Business'
                  ELSE 'Personal'                                                                 
              END                                                                                 
          ) = {{user_type}}]]
        [[AND (                                                                                   
              CASE
                  WHEN date(rc.first_completed_at) < date(ptl_fe_events.EVENT_TIMESTAMP + interval '330 mins') THEN 'Repeat'        
                  ELSE 'New'
              END                                                                                 
          ) = {{customer_type}}]]
		  [[AND {{route_name}}]]
        AND (EVENT_TIMESTAMP + interval '330 mins')::date >= {{start_date}}          
        AND (EVENT_TIMESTAMP + interval '330 mins')::date <= {{end_date}}
      GROUP BY 1                                                                                  
  )                                                                                               
                                                                                                  
  SELECT
    COALESCE(v.month, s.month, q.month, b.month) AS month,
    v.vehicles_loaded_sessions,
    s.ptl_selected_sessions,
    q.quote_viewed_sessions,
    b.booknow_clicked_sessions,
    ROUND(100.0 * s.ptl_selected_sessions   / NULLIF(v.vehicles_loaded_sessions, 0), 2) AS loaded_to_selected_pct,
    ROUND(100.0 * q.quote_viewed_sessions   / NULLIF(s.ptl_selected_sessions, 0), 2)    AS selected_to_quote_pct,
    ROUND(100.0 * b.booknow_clicked_sessions / NULLIF(q.quote_viewed_sessions, 0), 2)   AS quote_to_booknow_pct,
    ROUND(100.0 * b.booknow_clicked_sessions / NULLIF(v.vehicles_loaded_sessions, 0), 2) AS overall_conversion_pct
FROM vehicles_loaded v
FULL OUTER JOIN vehicles_ptl_selected s ON v.month = s.month
FULL OUTER JOIN quote_viewed          q ON v.month = q.month
FULL OUTER JOIN booknow_clicked       b ON v.month = b.month
ORDER BY month DESC; 