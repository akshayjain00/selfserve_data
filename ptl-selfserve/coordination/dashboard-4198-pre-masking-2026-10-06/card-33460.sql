 WITH latest_batched_orders AS (
      SELECT *
      FROM PROD_CURATED.PARTLOAD_APPLICATION.BATCHED_ORDERS_V1
      QUALIFY ROW_NUMBER() OVER (
          PARTITION BY order_id
          ORDER BY updated_at DESC
      ) = 1
  ),
 online as
(
select 
CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(bo.created_at))) AS DATE) AS dated,
batch_id, 
count(distinct bo.ORDER_EXTERNAL_ID) as no_of_orders_batched
 FROM latest_batched_orders bo

      LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
          ON orders.id = bo.order_id


left join PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES
on bo.ORDER_EXTERNAL_ID=ORDER_VEHICLES.ORDER_EXTERNAL_ID

left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
on PTL_INTERNAL_USERS.mobile=ORDERS.customer_mobile
left join prod_curated.partload_analytics.ptl_routes
on ptl_routes.route_id=orders.route_id and ptl_routes.is_active = 'True'
where 
 ORDERS.state not in (4)
and bo.created_at >= {{start_date}} - INTERVAL '330 MINS'
and bo.created_at <= {{end_date}} - INTERVAL '330 MINS'+ interval '1 day'
[[and 
  case 
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True'
end = {{is_test}}]]
[[and {{pickup_city}}]]
[[and {{drop_city}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
group by 1,2
)

,offline as
(
select 
CAST(DATE_TRUNC({{period}}, PICKUP_REACHED_TIMESTAMP::date) AS DATE) AS dated,
batch_id, 
count(distinct ORDER_EXTERNAL_ID) as no_of_orders_batched
from prod_curated.gsheet_sync.ptl_offline_orders
left join prod_curated.partload_analytics.ptl_routes
on ptl_routes.route_id=ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
where 
ptl_offline_orders.state not in (4)
and PICKUP_REACHED_TIMESTAMP::date >= {{start_date}} 
and PICKUP_REACHED_TIMESTAMP::date <= {{end_date}} 
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
group by 1,2
)

,final AS
(
SELECT *
FROM online

UNION ALL

SELECT *
FROM offline
)

,trip_per_order as
(
select 
dated,
no_of_orders_batched,
count(distinct batch_id) as trips 
from final
group by 1,2
)

SELECT 
  dated,
  no_of_orders_batched,
  trips,
  trips / SUM(trips) OVER () AS order_distribution_perc
FROM trip_per_order
ORDER BY no_of_orders_batched; 