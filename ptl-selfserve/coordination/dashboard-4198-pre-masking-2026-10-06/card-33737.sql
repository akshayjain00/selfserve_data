select 
date_trunc({{period}}, CH_CALL_ORIGINATE_TIME::date) as dated,
sum((coalesce((udh_talk_time / 1000.00),0) + coalesce((udh_hold_time / 1000.00),0) + coalesce((udh_wrap_time / 1000.00),0))) as THT,
count(distinct ch_crt_object_id) as calls,
round(sum((coalesce((udh_talk_time / 1000.00),0) + coalesce((udh_hold_time / 1000.00),0) + coalesce((udh_wrap_time / 1000.00),0)))/count(distinct ch_crt_object_id)::float, 2) as aht_sec 
from PROD_CURATED.REPORTS_PUBLIC.ACD_INTERVAL_DENORMALIZED_ENTITY
left join prod_curated.partload_analytics.ptl_internal_users
on ACD_INTERVAL_DENORMALIZED_ENTITY.ch_phone=ptl_internal_users.mobile
where ch_campaign_id in ('119','143')
and CH_CALL_ORIGINATE_TIME::date >= '2025-05-26'
and ptl_internal_users.mobile is null
and CH_CALL_ORIGINATE_TIME::date>={{start_date}} 
and CH_CALL_ORIGINATE_TIME::date<={{end_date}}
[[ and case when ch_campaign_id= '119' then 'Outbound_auto_dial'
when ch_campaign_id= '143' then 'Manual_outbound'
end = {{Call_type}}]]
group by 1
order by 1 desc
