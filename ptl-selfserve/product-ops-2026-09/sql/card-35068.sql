-- Card 35068 "TPO" (tickets per placed order), dashboard 4198 Support tab. Extracted + rewritten 2026-10-09.
-- Card failed in Metabase: "Can't parse '23-05-2025' as date with format 'YYYY-MM-DD'".
-- Rewrites:
--  1. TO_DATE("PL_Ticket_Created_Date",'YYYY-MM-DD') -> COALESCE(TRY_TO_DATE(x,'DD-MM-YYYY'),TRY_TO_DATE(x,'YYYY-MM-DD'))
--  2. Ticket internal-user exclusion: "Mobile" NOT IN ptl_internal_users.mobile (masked) ->
--     "Order_Id" NOT IN external_ids of orders whose customer_id is in ptl_internal_users.customer_uuid
--     (tickets with NULL Order_Id are kept, as before).
--  3. placed_orders is_test='False': mobile join -> customer_id NOT IN ptl_internal_users.customer_uuid.
--  Params: start_date=2026-08-01, end_date=2026-09-30, period=Month, is_test=False; customer_type/new_repeat/vehicle_type unset.
with internal_orders as (
  select external_id from prod_curated.partload_application.orders
  where customer_id in (select customer_uuid from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null)
), t as (
  select *, coalesce(try_to_date("PL_Ticket_Created_Date",'DD-MM-YYYY'), try_to_date("PL_Ticket_Created_Date",'YYYY-MM-DD')) tdate
  from prod_curated.gsheet_sync.ptl_tickets
), ticket as (
  select cast(date_trunc('month', tdate) as date) dated, count(distinct "PL_Ticket_ID") tickets
  from t
  where coalesce("Order_Id",'') not in (select external_id from internal_orders)
    and tdate >= '2026-08-01' and tdate <= '2026-09-30'
    and coalesce("Other_Issue",'') not ilike '%other%'
    and coalesce("Other_Issue",'') not ilike '%test%'
    and coalesce("Other_Issue",'') not ilike '%courier%'
    and coalesce("Other_Issue",'') not ilike '%packer%'
    and coalesce("Other_Issue",'') not ilike '%depart%'
    and coalesce("Other_Sub_Issue",'') not ilike '%courier%'
    and coalesce("Other_Sub_Issue",'') not ilike '%test%'
    and coalesce("Issue",'') not ilike '%Non PTL related%'
  group by 1
), placed_orders as (
  select cast(date_trunc('month', convert_timezone('UTC','Asia/Kolkata', to_timestamp(o.created_at))) as date) dated,
         count(distinct o.external_id) placed_orders
  from prod_curated.partload_application.orders o
  where o.created_at::timestamp >= '2026-08-01'::timestamp - interval '330 mins'
    and o.created_at::timestamp <= '2026-09-30'::timestamp - interval '330 mins' + interval '1 day'
    and o.customer_id not in (select customer_uuid from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null)
  group by 1
)
select ticket.dated, tickets, placed_orders, tickets/placed_orders as tpo
from ticket left join placed_orders on ticket.dated = placed_orders.dated
order by 1;
