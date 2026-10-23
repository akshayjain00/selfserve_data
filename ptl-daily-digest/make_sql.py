"""Write the SQL for one digest run into work/*.sql.

Usage: python3 daily-digest/make_sql.py [--end YYYY-MM-DD]
Prints the list of files. Run each through the Snowflake MCP and save the single
returned column `S` (just the string) to work/<name>.txt, then run build_digest.py.
"""
import argparse
import os
import sys
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as c

EXCL = """excl as (
  select customer_uuid as customer_id from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null
  union select '550e8400-e29b-41d4-a716-446655440000'
  union select 'da9acad5-3a9d-4e99-ac66-bb9c6d57ad32'
)"""
NOT_INTERNAL = "o.customer_id not in (select customer_id from excl)"
P = "prod_curated.partload_application"

Q = {}

Q["daily_orders"] = """with @EXCL@
select listagg(to_char(d,'YYYYMMDD')||','||orders||','||net||','||gross, ';') within group (order by d) as s
from (
  select date(o.updated_at + interval '330 minutes') as d, count(*) as orders,
         round(sum(f.total_fare)/100) as net, round(sum(f.total_fare + f.discount_amount_minor_units)/100) as gross
  from @P@.orders o
  join @P@.order_fares f on f.order_id = o.id and f.is_current_fare = TRUE
  where o.state = 3 and date(o.updated_at + interval '330 minutes') between '@S@' and '@E@'
    and @NI@
  group by 1)"""

Q["daily_created"] = """with @EXCL@
select listagg(to_char(d,'YYYYMMDD')||','||placed||','||completed||','||est_rev, ';') within group (order by d) as s
from (
  select date(o.created_at + interval '330 minutes') as d, count(*) as placed,
         count(case when o.state=3 then 1 end) as completed,
         round(sum(case when o.state=3 then o.estimated_fare else 0 end)/100) as est_rev
  from @P@.orders o
  where date(o.created_at + interval '330 minutes') between '@S@' and '@E@' and @NI@
  group by 1)"""

UTIL_CTES = """lbo as (
  select * from @P@.batched_orders_v1
  qualify row_number() over (partition by order_id order by updated_at desc) = 1
),
ow as (
  select o.id as order_id, o.route_id, date(o.pickup_slot_start + interval '330 minutes') as pickup_date,
         round(coalesce(
           max(case when ld.entry_type = 'OPS_DECLARED' and ld.is_active = true then ld.chargeable_weight end),
           max(case when ld.entry_type = 'CUSTOMER_DECLARED' then ld.chargeable_weight end)
         )/1000,0) as actual_weight
  from @P@.orders o
  left join @P@.load_details ld on ld.order_id = o.id
  where o.state = 3 and @NI@
  group by 1,2,3
),
bwt as (
  select lbo.batch_id, max(ow.pickup_date) as pickup_date, sum(ow.actual_weight) as weight
  from lbo join ow on ow.order_id = lbo.order_id
  where lbo.status = 3
  group by 1
),
rc as (select lbo.batch_id, ow.route_id, count(*) as n from lbo join ow on ow.order_id = lbo.order_id where lbo.status = 3 group by 1,2),
br as (select batch_id, route_id from rc qualify row_number() over (partition by batch_id order by n desc) = 1),
bc as (
  select j.batch_id, max(vc.weight_capacity) as capacity
  from @P@.jobs j
  join @P@.vehicles v on j.vehicle_id = v.id
  join @P@.vehicle_categories vc on vc.id = v.vehicle_categories_id
  where j.job_status = 6
  group by 1
)"""

Q["daily_util"] = """with @EXCL@,
@UTIL_CTES@
select listagg(to_char(d,'YYYYMMDD')||','||w||','||cap, ';') within group (order by d) as s
from (
  select bwt.pickup_date as d, sum(bwt.weight) as w, sum(bc.capacity) as cap
  from bwt
  join @P@.batch_v1 b on b.id = bwt.batch_id and b.status = 2
  join bc on bc.batch_id = bwt.batch_id
  where bwt.pickup_date between '@S@' and '@E@'
  group by 1)"""

OPT_CTES = """lbo as (
  select bo.order_id, bo.batch_id, bo.status from @P@.batched_orders_v1 bo
  qualify row_number() over (partition by bo.order_id order by bo.updated_at desc) = 1
),
bo as (
  select lbo.batch_id, o.id as order_id, o.route_id,
         date(min(o.created_at + interval '330 minutes') over (partition by lbo.batch_id)) as batch_day
  from lbo join @P@.orders o on o.id = lbo.order_id
  where lbo.status = 3 and o.state = 3 and @NI@
),
rc as (select batch_id, route_id, count(*) n from bo group by 1,2),
br as (select batch_id, route_id from rc qualify row_number() over (partition by batch_id order by n desc) = 1),
bs as (
  select bo.batch_id, bo.batch_day, br.route_id, count(distinct bo.order_id) as n_orders
  from bo join br on br.batch_id = bo.batch_id group by 1,2,3
)"""

Q["daily_opt"] = """with @EXCL@,
@OPT_CTES@
select listagg(to_char(d,'YYYYMMDD')||','||n||','||t, ';') within group (order by d) as s
from (select batch_day as d, sum(n_orders) as n, count(*) as t from bs
      where batch_day between '@S@' and '@E@' group by 1)"""

Q["daily_return"] = """with @EXCL@,
-- Metabase card 44691 (Return Trips): a batch is a return trip when the same vehicle's previous batch started from
-- the city this batch drops in. Orders window starts 2026-03-01 so the vehicle sequence has a warm-up.
final_return as (
  select o.id, o.external_id as order_id, o.route_id, r.route_name, r.drop_city as drop_city_o,
         ov.vehicle_registration_number, bo.batch_id, bo.created_at + interval '330 mins' as batch_created_at
  from prod_curated.partload_application.orders o
  left join prod_curated.partload_analytics.ptl_routes r on r.route_id = o.route_id and r.is_active = 'True'
  left join (select * from prod_curated.partload_application.batched_orders_v1
             qualify row_number() over (partition by order_id order by updated_at desc) = 1) bo on bo.order_id = o.id
  left join prod_curated.partload_application.order_vehicles ov on o.external_id = ov.order_external_id and ov.is_active = true
  where o.state = 3 and bo.batch_id is not null and o.created_at >= '2026-03-01'
    and @NI@
),
return_route_id as (
  select a.route_id as fwd_route_id
  from prod_curated.partload_analytics.ptl_routes a
  left join prod_curated.partload_analytics.ptl_routes b
    on a.route_name = split_part(b.route_name, ' - ', 2) || ' - ' || split_part(b.route_name, ' - ', 1)
  where a.is_active = 'True' and b.is_active = 'True'
),
orders_enriched as (
  select f.order_id, f.batch_id, f.vehicle_registration_number, f.route_id, f.drop_city_o as drop_city,
         f.batch_created_at as created_at, pvz.service_zone_name as vehicle_city
  from final_return f
  left join return_route_id r on r.fwd_route_id = f.route_id
  left join prod_curated.partload_application.vehicles v on v.registration_number = f.vehicle_registration_number
  left join prod_curated.partload_application.service_zones pvz on pvz.id = v.service_zone_id and service_zone_type = 'PICKUP'
),
batch_routes as (
  select distinct vehicle_registration_number, batch_id, route_id, drop_city, vehicle_city, created_at from orders_enriched
),
batch_header as (
  select vehicle_registration_number, batch_id, min(created_at) as batch_created_at from batch_routes group by 1, 2
),
sequenced_batches as (
  select vehicle_registration_number, batch_id, batch_created_at,
         lag(batch_id) over (partition by vehicle_registration_number order by batch_created_at, batch_id) as prev_batch_id
  from batch_header
),
matched_return_routes as (
  select distinct curr.vehicle_registration_number, curr.batch_id as return_batch_id, curr.route_id as return_route_id,
         sb.prev_batch_id as fwd_batch_id
  from sequenced_batches sb
  join batch_routes curr on curr.vehicle_registration_number = sb.vehicle_registration_number and curr.batch_id = sb.batch_id
  join batch_routes prev on prev.vehicle_registration_number = curr.vehicle_registration_number
    and prev.batch_id = sb.prev_batch_id and prev.batch_id <> curr.batch_id
    and prev.vehicle_city = curr.drop_city and prev.created_at < curr.created_at
  where sb.prev_batch_id is not null
),
final_ctee as (
  select curr.order_id, curr.batch_id, curr.created_at,
         case when max(case when m.fwd_batch_id is not null then 1 else 0 end) over (partition by curr.batch_id) = 1 then 'Yes' else 'No' end as batch_is_return_trip
  from orders_enriched curr
  left join matched_return_routes m on curr.vehicle_registration_number = m.vehicle_registration_number
    and curr.batch_id = m.return_batch_id and curr.route_id = m.return_route_id
),
dedup_batches as (
  select * from final_ctee qualify row_number() over (partition by order_id order by created_at desc) = 1
),
tot as (
  select date(created_at) as d, count(distinct batch_id) as total from orders_enriched
  where date(created_at) between '@S@' and '@E@' group by 1
),
ret as (
  select date(created_at) as d, count(distinct batch_id) as ret from dedup_batches
  where batch_is_return_trip = 'Yes' and date(created_at) between '@S@' and '@E@' group by 1
)
select listagg(to_char(t.d,'YYYYMMDD')||','||t.total||','||coalesce(r.ret,0), ';') within group (order by t.d) as s
from tot t left join ret r on r.d = t.d"""

Q["route_a"] = """with @EXCL@
select listagg(label||','||placed||','||completed||','||quick||','||est_rev, ';') within group (order by completed desc, label) as s
from (
  select r.route_label as label, count(*) as placed, count(case when o.state=3 then 1 end) as completed,
         count(case when o.state != 3 and datediff('second', o.created_at, o.updated_at) <= 60 then 1 end) as quick,
         round(sum(case when o.state=3 then o.estimated_fare else 0 end)/100) as est_rev
  from @P@.orders o join @P@.routes r on r.id = o.route_id
  where date(o.created_at + interval '330 minutes') between '@R0@' and '@E@' and @NI@
  group by 1)"""

Q["route_b"] = """with @EXCL@
select listagg(label||','||net||','||gross, ';') within group (order by net desc, label) as s
from (
  select r.route_label as label, round(sum(f.total_fare)/100) as net,
         round(sum(f.total_fare + f.discount_amount_minor_units)/100) as gross
  from @P@.orders o
  join @P@.routes r on r.id = o.route_id
  join @P@.order_fares f on f.order_id = o.id and f.is_current_fare = TRUE
  where o.state = 3 and date(o.updated_at + interval '330 minutes') between '@R0@' and '@E@' and @NI@
  group by 1)"""

Q["route_c"] = """with @EXCL@,
@OPT_CTES@
select listagg(label||','||n||','||t, ';') within group (order by n desc, label) as s
from (select r.route_label as label, sum(bs.n_orders) as n, count(*) as t
      from bs join @P@.routes r on r.id = bs.route_id
      where bs.batch_day between '@R0@' and '@E@' group by 1)"""

Q["route_d"] = """with @EXCL@,
@UTIL_CTES@
select listagg(label||','||w||','||cap, ';') within group (order by w desc, label) as s
from (select r.route_label as label, sum(bwt.weight) as w, sum(bc.capacity) as cap
      from bwt
      join br on br.batch_id = bwt.batch_id
      join @P@.batch_v1 b on b.id = bwt.batch_id and b.status = 2
      join bc on bc.batch_id = bwt.batch_id
      join @P@.routes r on r.id = br.route_id
      where bwt.pickup_date between '@R0@' and '@E@' group by 1)"""

Q["route_weekly"] = """with @EXCL@,
top as (
  select r.route_label as label
  from @P@.orders o join @P@.routes r on r.id = o.route_id
  where o.state = 3 and date(o.created_at + interval '330 minutes') between '@R0@' and '@E@' and @NI@
  group by 1 order by count(*) desc, 1 limit 12
),
wk as (
  select r.route_label as label,
         dateadd(day, -(dayofweekiso(date(o.created_at + interval '330 minutes')) - 1), date(o.created_at + interval '330 minutes')) as wk,
         count(*) as placed, count(case when o.state=3 then 1 end) as completed
  from @P@.orders o join @P@.routes r on r.id = o.route_id
  where r.route_label in (select label from top)
    and date(o.created_at + interval '330 minutes') between '@W0@' and '@W1@' and @NI@
  group by 1,2
)
select listagg(label||'|'||s, ';') within group (order by label) as s
from (select label, listagg(to_char(wk,'YYYYMMDD')||':'||placed||':'||completed, ',') within group (order by wk) as s from wk group by label)"""

Q["freshness"] = """select to_char(max(created_at + interval '330 minutes'),'YYYY-MM-DD HH24:MI') as s
from @P@.orders"""


def render(sql, w):
    sql = sql.replace("@UTIL_CTES@", UTIL_CTES).replace("@OPT_CTES@", OPT_CTES)
    for k, v in {"@EXCL@": EXCL, "@NI@": NOT_INTERNAL, "@P@": P,
                 "@S@": str(w["start"]), "@E@": str(w["end"]), "@R0@": str(w["route0"]),
                 "@W0@": str(w["weekly0"]), "@W1@": str(w["weekly1"])}.items():
        sql = sql.replace(k, v)
    return sql


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--end", default=None)
    a = ap.parse_args()
    D = date.fromisoformat(a.end) if a.end else c.default_end()
    w = c.windows(D, c.load_hist())
    os.makedirs(c.WORK, exist_ok=True)
    for old in os.listdir(c.WORK):
        os.remove(os.path.join(c.WORK, old))
    print(f"latest day D = {D} ({D.strftime('%A')}) | daily fetch {w['start']}..{w['end']} | routes {w['route0']}..{w['end']} | weekly {w['weekly0']}..{w['weekly1']}")
    for name, sql in Q.items():
        p = os.path.join(c.WORK, name + ".sql")
        open(p, "w").write(render(sql, w))
        print(p)
