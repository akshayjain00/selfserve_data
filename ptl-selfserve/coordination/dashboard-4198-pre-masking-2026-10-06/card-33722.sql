with calls_irrelevant as
(
select 
date_trunc({{period}},dated) as dated,
count(distinct call_id) as calls_irrelevant
from prod_eldoria.core.fact_calls
left join prod_curated.partload_analytics.ptl_internal_users
on fact_calls.phone=ptl_internal_users.mobile
where campaign_id in ('119','143')
-- and dated::date >= '2025-05-26'
and ptl_internal_users.mobile is null
and dated::date>={{start_date}} 
and dated::date<={{end_date}}
[[ and case when campaign_id= '119' then 'Outbound_auto_dial'
when campaign_id= '143' then 'Manual_outbound'
end = {{Call_type}}]]
group by 1
order by 1 desc
)

,calls_relevant as 
(
select 
date_trunc({{period}}, CH_CALL_ORIGINATE_TIME::date) as dated,
count(distinct ch_call_id) as calls_relevant
from PROD_CURATED.REPORTS_PUBLIC.ACD_INTERVAL_DENORMALIZED_ENTITY
left join prod_curated.partload_analytics.ptl_internal_users
on ACD_INTERVAL_DENORMALIZED_ENTITY.ch_phone=ptl_internal_users.mobile
where ch_campaign_id in ('119','143')
and CH_CALL_ORIGINATE_TIME::date >= '2025-05-26'
and ptl_internal_users.mobile is null
and CH_CALL_ORIGINATE_TIME::date>={{start_date}} 
and CH_CALL_ORIGINATE_TIME::date<={{end_date}}
and rec_no = 1
and ch_campaign_id != 65
and ch_call_type != 'transferred.to.campaign.dial'
and first_queue_answered = True
and UDH_DISPOSITION_CODE in ('wrap.timeout','Already Issue Resolved','TIcket_Raised_PTL')
[[ and case when ch_campaign_id= '119' then 'Outbound_auto_dial'
when ch_campaign_id= '143' then 'Manual_outbound'
end = {{Call_type}}]]
group by 1
order by 1 desc
)

,completed_orders as
(
select 
CAST(DATE_TRUNC({{period}}, CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(orders.created_at))) AS DATE) AS dated,
count(distinct orders.external_id) as placed_orders,
from PROD_CURATED.PARTLOAD_APPLICATION.orders 
left join PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS 
on PTL_INTERNAL_USERS.mobile= orders.customer_mobile
where (orders.created_at)::timestamp >=  {{start_date}} - interval '330 mins'
and (orders.created_at)::timestamp <= {{end_date}} - interval '330 mins' + interval '1 day'
--[[and {{vehicle_type}}]]
[[and 
  case 
  when ptl_internal_users.mobile is null then 'False'
  when ptl_internal_users.mobile is not null then 'True'
end = {{is_test}}]]


[[and case when orders.customer_mobile in (select mobile from prod_curated.oms_public.customers where frequency in (1,2,3,4)) then 'Business' else 'Personal' end = {{customer_type}}]]
[[and case when exists (select 1 from prod_curated.partload_application.orders nr_prior where nr_prior.customer_mobile = orders.customer_mobile and nr_prior.state = 3 and nr_prior.created_at < orders.created_at) then 'Repeat' else 'New' end = {{new_repeat}}]]
group by 1
order by dated desc
)


select 
calls_irrelevant.dated,
calls_relevant,
calls_irrelevant,
placed_orders,
calls_relevant/placed_orders as CPO,
--calls_irrelevant/placed_orders as CPO_with_irrelevant
from calls_irrelevant 
left join completed_orders
on calls_irrelevant.dated=completed_orders.dated
left join calls_relevant
on calls_relevant.dated=completed_orders.dated
order by dated desc