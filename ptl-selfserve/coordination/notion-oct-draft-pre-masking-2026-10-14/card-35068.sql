with ticket as
(
select cast(date_trunc({{period}},TO_DATE("PL_Ticket_Created_Date", 'YYYY-MM-DD')) AS DATE) as dated,
count(distinct "PL_Ticket_ID") as tickets 
from GSHEET_SYNC.PTL_TICKETS
left join prod_curated.partload_analytics.PTL_INTERNAL_USERS
on PTL_TICKETS."Mobile"=PTL_INTERNAL_USERS.mobile
where  PTL_TICKETS."Mobile" not in (SELECT MOBILE FROM PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)
and (TO_DATE("PL_Ticket_Created_Date", 'YYYY-MM-DD')) >=  {{start_date}} 
and (TO_DATE("PL_Ticket_Created_Date", 'YYYY-MM-DD')) <= {{end_date}} 
AND COALESCE("Other_Issue", '') NOT ILIKE '%other%' 
AND COALESCE("Other_Issue", '') NOT ILIKE '%test%' 
AND COALESCE("Other_Issue", '') NOT ILIKE '%courier%' 
AND COALESCE("Other_Issue", '') NOT ILIKE '%packer%'
AND COALESCE("Other_Issue", '') NOT ILIKE '%depart%'
AND COALESCE("Other_Sub_Issue", '') NOT ILIKE '%courier%' 
AND COALESCE("Other_Sub_Issue", '') NOT ILIKE '%test%' 
AND COALESCE("Issue", '') NOT ILIKE '%Non PTL related%'
group by 1
)

,placed_orders as
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
ticket.dated,
tickets,
placed_orders,
tickets/placed_orders as TPO
from ticket 
left join placed_orders
on ticket.dated=placed_orders.dated
order by dated 