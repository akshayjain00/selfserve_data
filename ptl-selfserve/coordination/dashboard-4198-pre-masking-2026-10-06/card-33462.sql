WITH slots_base AS (
    SELECT route_configuration_id, route_id, start_time, end_time, EDD_BUFFER_IN_DAYS, created_at,
           ROW_NUMBER() OVER (PARTITION BY route_id, start_time, end_time ORDER BY created_at) AS rn_old,
           LEAD(created_at)  OVER (PARTITION BY route_id, start_time, end_time ORDER BY created_at) AS valid_to_old
    FROM partload_application.slots
),
slot_intervals_old AS (
    SELECT route_id, start_time, end_time, EDD_BUFFER_IN_DAYS,
           CASE WHEN rn_old = 1 THEN TIMESTAMP '1970-01-01 00:00:00' ELSE created_at END AS valid_from,
           valid_to_old AS valid_to
    FROM slots_base
),
slot_intervals_by_config AS (
    SELECT route_configuration_id, route_id, start_time, end_time, EDD_BUFFER_IN_DAYS
    FROM slots_base
    QUALIFY ROW_NUMBER() OVER (PARTITION BY route_configuration_id, route_id, start_time, end_time
                               ORDER BY created_at DESC) = 1
)

,online as
(
select
CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
orders.external_id,
orders.state
from PROD_CURATED.PARTLOAD_APPLICATION.orders
left join PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES
  on orders.EXTERNAL_ID = ORDER_VEHICLES.ORDER_EXTERNAL_ID and ORDER_VEHICLES.is_active = TRUE
left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS
  on PTL_INTERNAL_USERS.mobile = orders.customer_mobile
left join prod_curated.partload_analytics.ptl_routes
  on ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'
left join prod_eldoria.core.dim_customers dc
  on orders.customer_mobile = dc.mobile
left join (
    SELECT quotation_uuid, route_configuration_id
    FROM PROD_CURATED.PARTLOAD_APPLICATION.QUOTATIONS
    WHERE quotation_uuid IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY quotation_uuid ORDER BY updated_at DESC) = 1
) q
  on q.quotation_uuid = orders.quotation_uuid
 and orders.created_at >= '2026-04-29 16:58:08.421000'::timestamp_ntz
left join slot_intervals_by_config s_cfg
  on q.route_configuration_id IS NOT NULL
 and orders.route_id = s_cfg.route_id
 and q.route_configuration_id = s_cfg.route_configuration_id
 and CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', orders.pickup_slot_start) AS TIME) = s_cfg.start_time
 and CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', orders.pickup_slot_end)   AS TIME) = s_cfg.end_time
left join slot_intervals_old s_old
  on orders.route_id = s_old.route_id
 and CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', orders.pickup_slot_start) AS TIME) = s_old.start_time
 and CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', orders.pickup_slot_end)   AS TIME) = s_old.end_time
 and orders.created_at >= s_old.valid_from
 and (orders.created_at < s_old.valid_to OR s_old.valid_to IS NULL)
where CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at)) >=  {{start_date}}
and CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))  <= {{end_Date}} + interval '1 day'
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
[[and
  case
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True'
end = {{is_test}}]]
[[and
  CASE COALESCE(s_cfg.EDD_BUFFER_IN_DAYS, s_old.EDD_BUFFER_IN_DAYS)
      WHEN 0 THEN 'SDD'
      WHEN 1 THEN 'NDD'
      ELSE NULL
  END = {{delivery_type}}
]]
[[AND (
            CASE
                WHEN dc.frequency IN (1,2,3,4) THEN 'Business'
                ELSE 'Personal'
            END
      ) = {{user_type}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
order by dated desc
)

,offline as
(
select
CAST(DATE_TRUNC({{period}}, ptl_offline_orders.created_at::date) AS DATE) AS dated,
external_id,
state
from prod_curated.gsheet_sync.ptl_offline_orders
left join prod_curated.partload_analytics.ptl_routes on ptl_routes.route_id = ptl_offline_orders.route_id and ptl_routes.is_active = 'True'
LEFT JOIN slot_intervals_old s
ON ptl_offline_orders.route_id = s.route_id
 AND CAST(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', ptl_offline_orders.pickup_slot_start) AS TIME) = s.start_time
 AND ptl_offline_orders.created_at >= s.valid_from
 AND (ptl_offline_orders.created_at < s.valid_to OR s.valid_to IS NULL)
left join prod_eldoria.core.dim_customers dc on ptl_offline_orders.customer_mobile = dc.mobile
where ptl_offline_orders.created_at >=  {{start_date}}
and ptl_offline_orders.created_at <= {{end_Date}}
[[and {{pickup_city}}]]
[[and {{drop_city}}]]
[[and
  CASE
      WHEN s.EDD_BUFFER_IN_DAYS = 0 THEN 'SDD'
      WHEN s.EDD_BUFFER_IN_DAYS = 1 THEN 'NDD'
      ELSE NULL
  END = {{delivery_type}}
]]
[[AND (
            CASE
                WHEN dc.frequency IN (1,2,3,4) THEN 'Business'
                ELSE 'Personal'
            END
      ) = {{user_type}}]]
order by dated desc
)

,final as
(
SELECT * FROM online
UNION ALL
SELECT * FROM offline
)

select
dated,
count(distinct external_id) as total_orders,
count(distinct case when state=3 then external_id end) as completed_orders,
count(distinct case when state=4 then external_id end) as cancelled_orders,
COUNT(DISTINCT CASE WHEN state in (0,1,2) THEN external_id ELSE NULL END) inprocess_order
from final
group by 1
