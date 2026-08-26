# P5c — "Snowflake → Sheets + Others" bucket re-search

Targeted re-search of the 24 (actually 26-numbered) catalogue metrics previously mapped to "Snowflake → Sheets + Others"
(no Metabase card identified). Method: enumerated dashboard 4198's full card list (all tabs), read SQL for every
plausible match, then ran targeted Metabase-wide searches (`search`, `get_collection_items`) for terms not covered by
4198's tabs. Metadata-only reads throughout; no `execute_card` calls.

## FOUND — grounded in SQL

### #32 Perfect Order Experience %
- **Cards:** 34052 "Perfect Order Experience %" (smartscalar), 34364 "Perfect Order Experience % - Trend" (line)
- **Dashboard:** 4198, SLA tab (tab id 3248)
- **SQL grounding:** `perfect_order_exp = count(ontime_delivery_flag=1 AND ontime_pickup_flag=1) / count(id)`, where
  `ontime_pickup_flag` = pickup_reached ≤ pickup_slot_end (+330min IST offset) and `ontime_delivery_flag` = delivery
  timestamp ≤ (pickup-slot-start day-truncated + 36h EDD). Aggregate-then-ratio, matches catalogue definition of a
  "perfect order" = both on-time pickup AND on-time delivery.
- **Verdict:** Direct match. Card note warns the metric depends on ops manually filling pickup/drop timestamps in
  gsheet — worth flagging as a data-completeness caveat, not a definitional issue.

### #33 On Time Pickup % + Delivery %
- **Cards:** 33784 "On-Time Pickup" (combo/trend) + 33785 "On-Time Delivery" (combo/trend); scalar siblings 33823
  "Overall On-Time Pickup" + 33824 "Overall On-Time Delivery"
- **Dashboard:** 4198, SLA tab
- **SQL grounding:** Two separate ratios computed and shown side-by-side on the same tab (not a single combined
  formula) — `on_time_pickup_perc` and `ontime_delivery_perc` as in #34/#35 below.
- **Verdict:** Found as a pair of companion cards, which is what the catalogue row "Pickup % + Delivery %" describes
  (two figures reported together, not one blended ratio).

### #34 On Time Pickup %
- **Cards:** 33784 "On-Time Pickup" (trend), 33823 "Overall On-Time Pickup" (scalar)
- **SQL grounding:** `on_time_pickup_perc = count(PICKUP_REACHED_TIMESTAMP <= pickup_slot_end + 330min) / count(state>0)`,
  unions online (app) orders with `gsheet_sync.ptl_offline_orders`.
- **Verdict:** Direct match.

### #35 On Time Delivery %
- **Cards:** 33785 "On-Time Delivery" (trend), 33824 "Overall On-Time Delivery" (scalar)
- **SQL grounding:** `ontime_delivery_perc = count(delayed_by <= 0) / count(*)`, where `delayed_by` = hours between
  actual drop timestamp and EDD (pickup-slot-start day + 36h).
- **Verdict:** Direct match.

- Note: A second, independently-built pair exists — 43882 "Overall Ontime pickup sla" and 43883 "OND - On Time
  Delivery" — sourced from `gsheet_sync.ptl_app_sheet_data` (ops-entered "reached_pickup_at"/"reached_drop_at")
  rather than the original order-timestamp path. Both are actively used (last used 2026-07-28) and compute the same
  on-time concept via a cleaner data source. Worth flagging to the orchestrator as a possible more-current source for
  #34/#35 if the "app sheet" data pipeline is now preferred over the original `ptl_table`/`PICKUP_REACHED_TIMESTAMP`
  path — did not chase down which is authoritative, out of scope for this pass.

### #51 Time to Allocate P50
- **Cards:** 42081 "Completed orders - P50 Allocation Time" (table), companion 42080 "Cancelled orders - P50
  Allocation Time for Same day orders"
- **Location:** Business Observability collection (5199), not on dashboard 4198 itself but same collection/DB (73)
- **SQL grounding:** `alloc__` = minutes between `order_created_time` and first `vehicle_assigned_time` (from
  `partload_application.order_vehicles`, first row per order by `created_at`), with a same-day/next-day pickup
  adjustment. `p50_alloc = ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY alloc__), 2)` — also computes p90,
  avg, and median in the same query.
- **Verdict:** Direct match, well-grounded — this is exactly "time to allocate, P50" computed from order-creation to
  first-vehicle-assignment.

### #54 GM% per PTL Order
- **Card:** 37416 "Gross Margin" (table) — checked as instructed against 37413 "Total Revenue" (bar), which computes
  the identical `gm` column as a bonus field.
- **Dashboard:** 4198, OKR tab (tab id 3684)
- **SQL grounding:** `gm = (total_revenue - total_cost) / total_revenue`, where `total_revenue` = sum of final fare
  (order-fare-revision-aware) and `total_cost` = sum of max `trip_cost` per batch (vendor payout from
  `gsheet_sync.PTL_TABLE`), aggregated per period (day/week/month) — consistent with the aggregate-then-ratio rule.
- **Verdict:** 37416 is the better/canonical answer for #54 (dedicated "Gross Margin" card); 37413 "Total Revenue"
  bundles the same `gm` field as a secondary column but is titled/purposed around revenue, not GM. Both match the
  catalogue formula `GM% = (revenue - cost) / revenue`. Recommend citing 37416.

## NOT FOUND — real attempt made, no qualifying card

- **#36 Damage %** — Searched "damage", "damage %", "Partner Attributed Damage". Only hits are PnM-vertical (Packers
  & Movers) dashboards (4140, 4774, 4811 in collection "Damage compensation"/"PPM Data"). No PTL damage-percentage
  card exists in Metabase.
- **#48 Batch Acceptance % by Partners** — Found "Partner Acceptance Sizing Dashboard" (4557) / card 38353
  "Notification Batches", which computes `allocation_rate` and `allocated_orders_ff_rate` from
  `prod_eldoria.mart.cge_partner_acceptance_sizing_final` — but this runs on database_id 103 (not PTL's database 73),
  covers all Porter vehicle categories (2W/LCV/HCV/Micro LCV/Outstation) and all cities, with no PTL-specific
  filter. This is a core-marketplace/CGE partner-notification-acceptance sizing tool, not a PTL batch-acceptance
  metric — different entity grain, rejected as a match per the "don't force a weak match" rule. The PTL Supply tab's
  "Rejected Trip by Vendor" (34092) counts rejections but does not compute an acceptance-rate ratio.
- **#49 Pickup/Delivery SLA Breach % (Guardrail)** — Searched "SLA Breach" directly: no hits. Closest adjacent
  cards are 43882/43883 (see #34/#35 note above), which compute the on-time % (not the breach %, and not labeled as
  a guardrail metric). Not counted as a match.
- **#50 Allocation Acceptance Rate** — Searched "Allocation Acceptance": no hits. Dashboard 4767 "PTL:
  Allocation/Cancellation Trends vs. Pickup Slot Timing" (collection 5738) / card 42317 computes
  `Non_Cancelled_allocated_orders / Total_Placed_orders` — an "orders allocated" rate, not a partner/vendor
  "acceptance of an allocation offer" rate. Different concept; rejected.
- **#52 % Organic Allocation** — Searched "organic allocation": zero hits anywhere in Metabase.
- **#53 Reallocation Rate** — Searched "reallocation": zero hits. (Adjacent-but-different: card 48535 "Vehicle
  Change %" in the Business Observability collection tracks vehicle swaps on an order, which is conceptually close
  but not verified/read in depth given budget; flagging as a lead, not a match.)
- **#57 Monthly Active Owners (MAO), #58 New Owners Onboarded/Month, #59 Monthly Active Vehicles (MAV), #60 New
  Vehicles Onboarded/Month, #61 Owner Onboarding Activation Rate, #62 Median Days Onboarding→First Trip, #63 M1
  Owner Retention %, #66 Owner Batch Acceptance Rate, #67 Owner Batch Completion Rate, #68 SLA Adherence % by
  Owner, #69 Partner Attributed Damage %, #75 Owner Earnings per MAV** — Searched "owner", "Monthly Active Owners",
  "Owner Onboarding", "Owner Retention", "Earnings per Vehicle", "active vehicles": zero hits. Read all 5 cards on
  the Supply tab (dashboard 4198, tab 3315): 34089 "Vendor's Earning", 34090 "Trip Per Vendor", 34091
  "Month-on-Month Vendor Retention", 34092 "Rejected Trip by Vendor", 33555 "Vehicle category supply". All five
  operate at **vendor** (transport-company) grain via `vendor_name` / `gsheet_sync.VENDOR_DETAILS_NEW_DATA` /
  `ptl_vendor_details`, not individual **owner** or **vehicle** grain. 34091's cohort-retention logic is the closest
  conceptual analog to #63 (M1 retention), but it retains vendors (companies), not owners (individuals) — a genuine
  entity-grain mismatch, not a valid substitute. 33555 counts vehicle-registration occurrences per period (not a
  distinct "active vehicle" count), so it doesn't satisfy #59 either. No qualifying cards found for any of these 12
  metrics.
- **#64 % Trips On-Time Pickup (Owner/Supply), #65 % Trips On-Time Delivery (Owner/Supply)** — The overall on-time
  pickup/delivery metrics exist (#34/#35 above) but nothing splits them by owner/vendor grain. No card found at the
  owner cut specifically.

## Summary count
- Found: 6 metrics (#32, #33, #34, #35, #51, #54)
- Not found: 20 metrics (#36, #48, #49, #50, #52, #53, #57, #58, #59, #60, #61, #62, #63, #64, #65, #66, #67, #68,
  #69, #75) — all owner/vehicle-supply and damage/batch-acceptance/allocation-acceptance/organic-allocation/
  reallocation metrics appear to be genuinely absent from Metabase, consistent with the original "Sheets + Others"
  classification.
