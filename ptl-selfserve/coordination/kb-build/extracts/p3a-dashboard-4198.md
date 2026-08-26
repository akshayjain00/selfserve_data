# P3a Extract — Dashboard 4198 "PTL Business Observability"

Status: COMPLETE. Access: ok (no auth failures; one transient Metabase MCP rate-limit mid-run, resolved by backing off and retrying — no auth wall encountered). 27 of ~82 unique underlying cards opened, prioritised per the fulfilment/cancellation/orders/AOV-revenue/clubbing/retention theme list; the rest (utilization, SLA on-time pickup/delivery, call-center/support, vendor supply-side, demand-distribution breakdowns, order-share breakdowns, perfect-order-experience) deprioritised and listed with reasons at the end of this file.

## Dashboard metadata

- id: 4198
- name: "PTL Business Observability " (trailing space in actual name)
- collection: "Business Observability" (id 5199)
- created_at: 2025-05-26T07:01:02.599298Z
- updated_at (dashboard-level, last layout/save): 2026-05-05T07:09:06.988415Z
- view_count: 10481
- database_id (all cards so far): 73

### Tabs (11)
| tab id | name | position |
|---|---|---|
| 3184 | Overview | 0 |
| 3185 | Finance | 1 |
| 3518 | Demand Distribution | 2 |
| 3244 | Utilization | 3 |
| 3187 | Cancellations | 4 |
| 3223 | Support | 5 |
| 3315 | Supply | 6 |
| 3248 | SLA | 7 |
| 3640 | Route Level | 8 |
| 3684 | OKR | 9 |
| 4249 | Order Share | 10 |
| 5877 | Clubbing | 11 |

### Card count
~112 dashcard placements (including text/heading placeholder cards with `card_id: null`), resolving to ~76 unique underlying card_ids. Several cards are re-used across multiple tabs (e.g. card 33807 "On-Ground Utilization" appears on both Overview and Utilization tabs; card 42419 "Route wise Order Share" appears on both Order Share and Route Level tabs; card 34091 "Month-on-Month Vendor Retention" appears on Supply and OKR tabs; card 33722 "CPO" and 33784/33785 "On-Time Pickup/Delivery" appear on Support/SLA and OKR tabs).

### Dashboard-level filters/parameters
| name | slug | type | default |
|---|---|---|---|
| Start Date | start_date | date/single | 2026-04-01 |
| End Date | end_date | date/single | 2026-06-30 |
| Period | period | string/= (static list: Day, Week, Month) | Week |
| Is Test | is_test | string/= (static list: True, False) | False |
| Pickup City | pickup_city | string/= | (none) |
| Drop City | drop_city | string/= | (none) |
| Order State | order_state | string/= (static list: completed, cancelled) | completed |
| Return Route Name | return_route_name | string/= | (none) |
| Delivery Type | delivery_type | string/= (static list: SDD, NDD) | (none) |

Note: dashboard filters bind to native template tags per card via `parameter_bindings`; not every card consumes every filter (e.g. `delivery_type` only wired to a handful of fulfilment cards).

---

## Per-card extracts

### Card 33483 — "Total Orders"
- updated_at: 2026-07-28T09:54:27.567792Z
- database_id: 73, query_type: native
- **Computation**: `total_orders = COUNT(DISTINCT orders.external_id)`, unioned across an "online" CTE (`PROD_CURATED.PARTLOAD_APPLICATION.orders`) and an "offline" CTE (`prod_curated.gsheet_sync.ptl_offline_orders`), summed per period bucket. No numerator/denominator — this is a raw count, not a ratio.
- Source tables: `PROD_CURATED.PARTLOAD_APPLICATION.orders`, `PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS`, `prod_curated.partload_analytics.ptl_routes`, `prod_eldoria.core.dim_customers`, `prod_curated.gsheet_sync.ptl_offline_orders`. Key columns: `external_id`, `created_at`, `customer_mobile`, `route_id`.
- Filters: date window on `orders.created_at` (`>= {{start_date}} - interval '330 mins'`, `<= {{end_date}} - interval '330 mins' + interval '1 day'` — i.e., correctly shifts the UTC boundary by IST offset before comparing, avoiding a wrap-in-expression on the column itself in the sense that the shift is applied to the bind parameter, not to `orders.created_at`); optional pickup/drop city; **internal-user exclusion** via `CASE WHEN ptl_internal_users.mobile IS NULL THEN 'False' ELSE 'True' END = {{is_test}}` (only applied when `is_test` filter is supplied); optional `customer_type` (Business = customer with historical order frequency in (1,2,3,4) via `dim_customers.frequency`, else Personal) and `new_repeat` (New = order id equals customer's first order id, else Repeat) — these two are card-local filters not wired at dashboard level.
- Time basis: `orders.created_at`, converted UTC→IST via `CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(...))`. Offline orders use `created_at::date` directly (gsheet data assumed already in local date).
- Grain: `dated` (day/week/month per `{{period}}`), summed online+offline.
- No TITLE-VS-SQL mismatch — title matches computation.
- Core expression: `count(distinct orders.external_id) as total_orders ... group by 1 order by dated asc` (online), UNION ALL with offline, then `sum(total_orders) group by 1`.

### Card 33485 — "Fulfillment" (Overview tab)
- updated_at: 2026-01-09T09:12:11.968692Z
- database_id: 73, query_type: native
- **Computation**: `fulfillment_perc = COUNT(DISTINCT CASE WHEN state = 3 THEN external_id END) / NULLIF(COUNT(DISTINCT external_id), 0)`. Numerator = distinct completed orders (state 3). Denominator = all distinct orders (online ∪ offline) in the window, i.e. **demand = all orders regardless of terminal state** (open/assigned/picked-up/cancelled/completed all count in denominator).
- Source tables: `PROD_CURATED.PARTLOAD_APPLICATION.orders`, `PTL_INTERNAL_USERS`, `ptl_routes`, `gsheet_sync.ptl_offline_orders`.
- Filters: date window on `created_at` (IST-shifted bind params), optional pickup/drop city, optional internal-user exclusion (`is_test`).
- Time basis: `orders.created_at` → IST.
- Grain: per `{{period}}` bucket (online+offline unioned then grouped again would be needed for a true combined ratio, but note: this query computes `fulfillment_perc` **inside the online CTE and inside the offline CTE separately is NOT what happens** — actually the `final` CTE unions raw rows (dated, state, external_id) from both online and offline, and the ratio is computed once on the unioned `final` set. So aggregate-then-ratio is respected across sources.)
- No TITLE-VS-SQL mismatch.
- Core expression: `COUNT(DISTINCT CASE WHEN state = 3 THEN external_id ELSE NULL END) / NULLIF(COUNT(DISTINCT external_id), 0) AS fulfillment_perc`

### Card 37419 — "Fulfillment" (OKR tab)
- updated_at: 2026-01-11T18:11:46.47786Z
- **DUPLICATE of card 33485** — byte-for-byte identical SQL (same CTE names, same filters, same core expression), only `display` differs (bar vs smartscalar) and it lives on the OKR tab. Not a distinct metric.

### Card 33466 — "Fullfillment %" (Overview tab, line chart)
- updated_at: 2026-01-11T16:16:18.244047Z
- database_id: 73, query_type: native
- **Computation**: a multi-metric query returning 5 columns per `dated`, NOT a single fulfilment number:
  1. `fulfillment_perc` = COUNT(DISTINCT state=3)/NULLIF(COUNT(DISTINCT external_id),0)
  2. `fulfillment_excluding_60second_cancellations` = COUNT(DISTINCT state=3) / NULLIF(COUNT(DISTINCT external_id) − COUNT(DISTINCT CASE WHEN DATEDIFF(SECOND, created_at, ocr_created_at) <= 60 THEN external_id END), 0) — i.e. orders cancelled within 60 seconds of order creation (measured via `ORDER_CANCELLATION_REASONS.created_at`) are **dropped from the denominator entirely** (not reclassified, just excluded).
  3. `cancellation_perc` = COUNT(DISTINCT state=4)/NULLIF(COUNT(DISTINCT external_id),0)
  4. `inprocess_order_perc` = COUNT(DISTINCT state IN (0,1,2))/NULLIF(COUNT(DISTINCT external_id),0)
  5. `unique_fulfillment_perc` — a de-duplicated "clustered" fulfilment metric: online orders are clustered by `customer_mobile || hour(created_at) || round(pickup_lat,3) || round(pickup_lng,3) || round(drop_lat,3) || round(drop_lng,3)` (i.e. same customer, same hour, same rounded pickup/drop coords = 1 cluster/"unique demand"); a cluster counts as fulfilled if ANY order in it has state=3. `unique_fulfillment_perc = SUM(is_fulfilled)/NULLIF(COUNT(cluster_id),0)`. Offline orders are excluded from this metric (`WHERE customer_mobile IS NOT NULL`).
- Source tables: `PARTLOAD_APPLICATION.orders`, `PTL_INTERNAL_USERS`, `ptl_routes`, `PARTLOAD_APPLICATION.ORDER_CANCELLATION_REASONS` (joined on `orders.id = ocr.order_id`), `gsheet_sync.ptl_offline_orders`.
- Filters: date window on IST-converted `created_at` BETWEEN start/end+1day; optional pickup/drop city; optional `is_test` internal-user exclusion.
- Time basis: `orders.created_at` → IST via `CONVERT_TIMEZONE`.
- Grain: per `dated`.
- **TITLE-VS-SQL MISMATCH**: titled "Fullfillment %" (singular metric) but SQL returns 5 distinct metrics including a 60-second-exclusion variant, a raw cancellation %, an in-process %, and a clustered/deduped fulfilment number. The dashboard tile likely only surfaces one series by default but the underlying question is multi-metric.
- Core expression (60s exclusion): `COUNT(DISTINCT CASE WHEN state = 3 THEN external_id END)*1.0 / NULLIF(COUNT(DISTINCT external_id) - COUNT(DISTINCT CASE WHEN DATEDIFF(SECOND, created_at, ocr_created_at) <= 60 THEN external_id END), 0) AS fulfillment_excluding_60second_cancellations`

### Card 43238 — "Fullfillment excluding 60sec cancellations %"
- updated_at: 2026-02-09T09:57:42.307966Z
- **Near-duplicate of 33466's logic** (identical 5-metric SELECT block and identical 60-second exclusion expression using `ORDER_CANCELLATION_REASONS.created_at`), but adds a `slot_intervals` CTE off `partload_application.slots` to derive **delivery_type (SDD/NDD)** per order from `EDD_BUFFER_IN_DAYS` (0 = SDD, 1 = NDD) matched by route_id + pickup slot start/end time, time-windowed by slot-config validity (`valid_from`/`valid_to` via `LEAD(created_at)` per route+slot). Adds `[[and delivery_type filter]]`.
- Source tables: adds `partload_application.slots`.
- **TITLE-VS-SQL MISMATCH**: same as 33466 — title names one metric, SQL returns 5, including plain `fulfillment_perc` and `cancellation_perc` alongside the 60s-exclusion variant.

### Card 37104 — "Fullfillment % - Split"
- updated_at: 2026-01-11T17:50:47.592584Z
- **Computation**: same-day (SDD) vs next-day (NDD) split of the same fulfilment logic as above, keyed off `EDD_BUFFER_IN_DAYS` joined via `partload_application.slots` (`s.enabled = true` join condition, no time-windowing by slot-config validity here — simpler/older join style than 43238). Returns `fulfillment_perc`, `fulfillment_excluding_60second_cancellations`, and `unq_fulfillment_pct` (clustered) split by `EDD` (Same day / Next day), full-outer-joined between order-level and cluster-level aggregates.
- Note: uses `UNION` (not `UNION ALL`) between online/offline CTEs — a potential silent row-drop if an online and offline row happen to be identical across all selected columns (unlikely in practice given distinct external_id/created_at, but worth flagging as inconsistent with 33466/43238 which use `UNION ALL`).
- **TITLE-VS-SQL MISMATCH**: none beyond the shared multi-metric issue above.

### Card 43897 — "Fulfillment Rate - Route"
- updated_at: 2026-01-11T18:10:33.171958Z
- **Computation**: `Fulfillment_Perc = count(state='Completed')/count(*)` per route_name per period, after a route-level percentile-rank bucketing (TOP_10/TOP_25/TOP_50/BOTTOM_50 by order volume). State mapping here is explicit: 0=Open, 1=Assigned, 2=Picked_up, 3=Completed, 4=Cancelled.
- Source tables: `orders`, `ptl_routes`, `contact_details`, `LOAD_DETAILS`, `material_type`, `ORDER_VEHICLES`, `slots`, `PTL_INTERNAL_USERS`, `batched_orders_v1`, `order_fares`.
- Denominator here is `count(*)` over ALL rows post a `QUALIFY ROW_NUMBER() ... = 1` dedupe per order (latest by updated_at) — includes cancelled/open/assigned/picked-up, same "all orders" demand definition as other fulfilment cards.
- Time basis: `orders.created_at` → IST via `date(created_at + interval '330 minutes')`.

### Card 33462 — "Order Funnel"
- updated_at: 2026-07-28T09:54:28.56141Z (most recently modified card seen so far)
- database_id: 73, query_type: native
- **Computation**: returns 4 raw counts per `dated`, no ratios computed in-SQL (ratios would be computed by the chart display, i.e. this card is likely the source of `ff = co/demand` external to SQL):
  - `total_orders` = COUNT(DISTINCT external_id) — all orders (all states)
  - `completed_orders` = COUNT(DISTINCT CASE WHEN state=3 THEN external_id END)
  - `cancelled_orders` = COUNT(DISTINCT CASE WHEN state=4 THEN external_id END)
  - `inprocess_order` = COUNT(DISTINCT CASE WHEN state IN (0,1,2) THEN external_id END)
- **No CBDF/CADF split anywhere in this query.** Cancellation is a single bucket (`state=4`); there is no join to `ORDER_VEHICLES` or any "vehicle assigned" timestamp to distinguish cancelled-before-vs-after allocation. This is the dashboard's canonical "funnel" card and it does NOT decompose cancellation further.
- Source tables: `orders`, `ORDER_VEHICLES` (joined but only used for... actually not selected — dead join, left in for filtering compatibility only), `PTL_INTERNAL_USERS`, `ptl_routes`, `prod_eldoria.core.dim_customers`, `PARTLOAD_APPLICATION.QUOTATIONS`, `partload_application.slots` (twice — once via a "by config" join keyed on `quotation.route_configuration_id`, once via a legacy time-windowed join), `gsheet_sync.ptl_offline_orders`.
- Filters: date window on IST `created_at`; optional pickup/drop city; optional `is_test`; optional `delivery_type` (SDD/NDD derived from slot `EDD_BUFFER_IN_DAYS`, preferring the new `route_configuration_id`-keyed slot join — active only for orders created on/after `2026-04-29 16:58:08.421` — falling back to the legacy time-windowed slot join via `COALESCE`); optional `new_repeat`; optional `user_type` (Business/Personal via `dim_customers.frequency`).
- Time basis: `orders.created_at` → IST.
- Grain: per `dated`, no dimension breakdown beyond the optional filters above.
- No TITLE-VS-SQL mismatch (funnel = raw stage counts, as named), but worth flagging: **the funnel stops at "cancelled" as one bucket — it does not expose CBDF/CADF stages that the orchestrator's project is contesting.**
- Core expression: `count(distinct external_id) as total_orders, count(distinct case when state=3 then external_id end) as completed_orders, count(distinct case when state=4 then external_id end) as cancelled_orders, COUNT(DISTINCT CASE WHEN state in (0,1,2) THEN external_id END) inprocess_order`

---

## Cancellation logic specifically

**Key finding: no card on this dashboard computes CBDF or CADF as named/distinct metrics.** Every cancellation-related card treats cancellation as a single, undifferentiated bucket: `orders.state = 4`. None of the 7 cancellation-tab cards inspected join `ORDER_VEHICLES` (or any vehicle-assignment timestamp) to split "cancelled before a vehicle/driver was assigned" from "cancelled after assignment." This appears to be a genuine gap on this dashboard relative to the CBDF/CADF vocabulary used elsewhere in the project.

### Card 33539 — "Cancellation %"
- updated_at: 2026-01-11T16:34:26.54781Z
- `cancellation_perc = COUNT(DISTINCT CASE WHEN state = 4 THEN external_id END) / NULLIF(COUNT(DISTINCT external_id), 0)` where denominator = `placed_orders` = all distinct orders in window (online only — this card has **no offline union**, unlike Total Orders/Fulfillment).
- No `<60s` exclusion applied here.
- Time basis: `orders.created_at` → IST, `date(...)` comparison (not the `- interval 330 mins` shift-then-compare pattern used elsewhere — uses `date(CONVERT_TIMEZONE(...))` directly, functionally equivalent but a different SQL idiom).
- Quote: `COUNT(DISTINCT CASE WHEN state = 4 THEN external_id ELSE NULL END) as cancelled_orders, cancelled_orders / NULLIF(placed_orders, 0) AS cancellation_perc`

### Card 34506 — "Cancellation % - Number"
- updated_at: 2026-04-29T12:02:45.776123Z
- Same `state=4` definition, returns both `fulfillment_perc` and `cancellation_perc` side by side, denominator = all distinct orders. No `<60s` exclusion. Online-only (no offline union).
- Quote: `COUNT(DISTINCT CASE WHEN state = 4 THEN external_id ELSE NULL END) / NULLIF(COUNT(DISTINCT external_id), 0) AS cancellation_perc`

### Card 33464 — "Cancellation distribution reason wise"
- updated_at: 2026-01-11T16:35:07.9556Z
- Grain: cancelled orders by `reason` (free-text from `ORDER_CANCELLATION_REASONS.reason`; any value starting with "other" is collapsed to `'Text Box'`). `count(distinct order_id)`. No vehicle-assigned split, no `<60s` exclusion — this is simply every row in `ORDER_CANCELLATION_REASONS` joined to `orders` in the date window, grouped by reason.
- Source: `PARTLOAD_APPLICATION.ORDER_CANCELLATION_REASONS` LEFT JOIN `orders` on `order_external_id = orders.external_id`.

### Card 33465 — "Cancellation distribution source wise"
- updated_at: 2026-01-11T16:35:30.231494Z
- Grain: cancelled orders by `cancellation_source` code: 1=Customer_App, 2=Partner_App, 3=Salesforce, 4=Appsmith. Same source table as above, no vehicle-assigned split, no `<60s` exclusion.

### Card 35252 — "Cancellation (Median/P90)"
- updated_at: 2026-01-11T16:35:47.989329Z
- Computes **time-to-cancel** = `DATEDIFF('second', orders.created_at, orders.updated_at)` (note: uses `orders.updated_at`, NOT `ORDER_CANCELLATION_REASONS.created_at` — a different timestamp source than the 60s-exclusion logic in cards 33466/43238/37104). Avg/median/P90 in minutes. Filters `state = 4` and excludes internal users via `CUSTOMER_MOBILE NOT IN (SELECT MOBILE FROM PTL_INTERNAL_USERS)` (a `NOT IN` anti-pattern rather than `NOT EXISTS`, and structurally different from the `is_test` CASE/param pattern used elsewhere — this card has no `is_test` toggle, internal users are unconditionally excluded).
- No `<60s` exclusion — in fact the fastest bucket (0–5 min, see card 35253) is included in the average/percentile, i.e. **this card's numbers would include the same sub-60-second cancellations that 33466/43238 explicitly strip out elsewhere.**
- Quote: `ROUND(AVG(DATEDIFF('second', created_at, updated_at)) / 60.0, 2) AS avg_cancel_time_mins ... PERCENTILE_CONT(0.5) ... PERCENTILE_CONT(0.9) ...`

### Card 35253 — "Cancellation (Time Bucket)"
- updated_at: 2026-01-11T16:36:01.649168Z
- Same `DATEDIFF('second', created_at, updated_at)` basis as 35252. Buckets: 0–5 min, 5–15 min, 15–30 min, >30 min. Same unconditional internal-user exclusion, `state = 4` filter, no `<60s` exclusion (the 0-5 min bucket explicitly includes anything from 0 seconds up).
- Quote: `CASE WHEN DATEDIFF('second', created_at, updated_at) / 60 <= 5 THEN '0–5 mins' ... ELSE '> 30 mins' END AS cancellation_time_bucket`

### Card 39941 — "Route Level - Orders Cancelled Trends" (Route Level tab)
- updated_at: 2026-01-11T18:02:20.696335Z
- collection_id 5207 ("Product Observability" — different collection than the rest, worth noting)
- `cancellation_pct = ROUND(cancel_orders / NULLIF(total_orders, 0), 2)` per route per period, `cancel_orders = COUNT(DISTINCT CASE WHEN state='4' THEN order_id END)`. Unconditional internal-user exclusion via `NOT IN`. No `<60s` exclusion.

### Cancellation logic — summary table
| Card | Cancel definition | Time-to-cancel source | `<60s` exclusion? | Internal-user handling |
|---|---|---|---|---|
| 33539, 34506, 39941 | `state=4` | n/a | No | `is_test` param (33539/34506) or unconditional `NOT IN` (39941) |
| 33464, 33465 | row exists in `ORDER_CANCELLATION_REASONS` | n/a | No | `is_test` param |
| 35252, 35253 | `state=4` | `orders.updated_at` | No | unconditional `NOT IN` |
| 33466, 43238, 37104 | `state=4` (for `cancellation_perc`); separately, orders with `DATEDIFF(sec, created_at, ocr.created_at) <= 60` are dropped from the fulfilment denominator | `ORDER_CANCELLATION_REASONS.created_at` | **Yes**, but only inside the fulfilment-percentage calculation, not as a standalone cancellation metric | `is_test` param |

**CONFLICT: no CBDF/CADF split exists anywhere in this dashboard's SQL.** All cancellation is a flat `state=4`. `UNRESOLVED` — cannot verify from this dashboard whether CBDF/CADF is computed elsewhere (a different card set, a dbt model, or another dashboard).

**CONFLICT: two different "time to cancel" timestamp sources.** Cards 35252/35253 use `orders.updated_at`; cards 33466/43238/37104 use `ORDER_CANCELLATION_REASONS.created_at`. These will not agree if `updated_at` is touched by any other mutation between order creation and the cancellation-reason write. `UNRESOLVED`.

---

## Revenue / AOV

### Card 33706 — "AOV" (Overview tab)
- updated_at: 2026-01-11T16:14:14.926437Z
- **Computation**: `orders = COUNT(DISTINCT id)` where `state='3'` (completed only, online orders only — no offline union); `revenue = SUM(estimated_fare/100)`; `aov = revenue/orders`.
- Filters: `state='3'`; unconditional internal-user exclusion via `customer_mobile NOT IN (SELECT mobile FROM ptl_internal_users)` (no `is_test` toggle here, unlike most other cards); optional pickup/drop city.
- Time basis: `date(updated_at + interval '330 mins')` — buckets by order **update** time, not creation time. This differs from Total Orders/Fulfillment which bucket by `created_at`.
- Quote: `sum(estimated_fare/100) as revenue, revenue/orders as aov`

### Card 37413 — "Total Revenue" (Finance/OKR tabs)
- updated_at: 2026-07-28T09:54:29.576872Z (very recently modified)
- **Computation**: builds a `wd_fare` CTE (weight-discrepancy revised fare: `order_fares.total_fare` where a customer-notified fare revision exists and `is_current_fare='true'`), and falls back to `orders.estimated_fare/100` via `COALESCE` when no such revision exists. `total_revenue = SUM(final_fare)` over completed (`state=3`) orders, online+offline combined via `UNION` (not `UNION ALL`). Also returns `aov = total_revenue / COUNT(DISTINCT CASE WHEN state=3 THEN external_id END)` and **Gross Margin** `gm = (total_revenue − total_cost) / total_revenue`, where `total_cost` is vendor payout (`gsheet_sync.PTL_TABLE.TOTAL_VENDOR_PAYOUT`, matched via `order_vehicles`, taken as `MAX(trip_cost)` **per batch_id** then summed across batches per day — i.e. cost is a per-batch figure, not per-order).
- **TITLE-VS-SQL MISMATCH**: titled "Total Revenue" but the query returns revenue, AOV, vendor cost, and gross margin together — same multi-metric-under-one-name pattern seen in the Fulfillment cards.
- Filters: `state=3`; unconditional internal-user `NOT IN` exclusion; optional pickup/drop city, customer_type, new_repeat.
- Time basis: `orders.created_at` → IST (differs from card 33706's `updated_at` basis).
- Quote: `SUM(final_fare) AS total_revenue, SUM(final_fare) / COUNT(DISTINCT CASE WHEN state = 3 THEN external_id END) AS aov ... (agg_metrics.total_revenue - final_vendor_costs.total_cost)/(agg_metrics.total_revenue) AS gm`

### Card 52889 — "Revenue - Trend -Discount" (Finance tab; lives in collection "Raw tables" id 5198, not "Business Observability" id 5199)
- updated_at: 2026-07-08T08:01:17.807725Z
- **Computation**: `revenue_without_discount = SUM(order_fares.total_fare/100)` (current fare only); `revenue_with_discount = SUM((total_fare + quotations.discount_amount_minor_units)/100)`; `total_discount_rs = SUM(discount/100)`; `aov_with_discount`/`aov_without_discount` = respective revenue / distinct completed order count.
- Filters: `state='3'`, unconditional internal-user `NOT IN` exclusion, optional pickup/drop city.
- Time basis: `date(orders.updated_at + interval '330 mins')`.
- **This is a THIRD distinct revenue basis** alongside 33706 (`estimated_fare`) and 37413 (WD-revised `final_fare`) — see Conflicts.

### Card 34284 — "WD Share in Revenue Trend"
- updated_at: 2026-01-11T16:19:30.387259Z
- **Computation**: `wd_share_in_revenue = SUM(actual_fare − estimated_fare) / SUM(fares)`, where `fares = actual_fare` if the order was weight-discrepancy ("WD") revised else `estimated_fare`. Reconciles three sourcing paths for WD status: `old_online` (`gsheet_sync.ptl_table.wd_marked`), `new_online` (derived from `order_fares`/`fare_revision_notified`/`is_current_fare`), and `offline`. `state=3` only.
- This card documents the WD fare-revision mechanism that underlies card 37413's `wd_fare` CTE and explains why AOV differs between 33706 (pre-revision `estimated_fare`) and 37413 (post-revision `final_fare`).

## Clubbing / Batching

### Card 33460 — "Orders Clubbed Distributions"
- updated_at: 2026-06-01T07:38:50.122978Z
- **Computation**: distribution of `no_of_orders_batched` (distinct orders per `batch_id`, from the latest-status row per order in `BATCHED_ORDERS_V1`) vs `trips` (distinct batch_id count at that bucket), plus `order_distribution_perc = trips / SUM(trips) OVER ()`.
- Filter: `orders.state NOT IN (4)` — **excludes only cancelled orders, includes open/assigned/picked-up (0,1,2) as well as completed (3)** in the batching population. This is broader than the other clubbing cards (47540/48449/49365), which restrict to completed (`state=3`) only. Flagged as a scope difference, not necessarily an error.
- Source: `BATCHED_ORDERS_V1` (deduped via `QUALIFY ROW_NUMBER() ... = 1` on `updated_at`), `orders`, `ORDER_VEHICLES`, `ptl_offline_orders`.

### Card 47540 — "PTL Batching Opportunity" — richest self-documented card on the dashboard
- updated_at: 2026-04-06T11:49:21.009497Z
- The SQL carries an explicit metric-definition comment block (quoted verbatim, abridged):
  - `is_clubbable (v6)` = "completed order locked to a combo where AT LEAST ONE other partner also completed (state=3). Stricter than v4 (any combo), looser than v5 (all complete)."
  - `is_opportunity_clubbable` = "completed order on route+date where ≥2 completed orders exist (no distance/slot cap — pure demand overlap)."
  - `clubbed` = `is_clubbable=1 AND clubbed_batch_id IS NOT NULL`
  - `engine_clubbable` = "completed orders with at least 1 other completed combo partner"
  - `actual_clubbed_total` = "all completed orders placed in a multi-order batch (superset of clubbed — includes ~127/mo with cancelled partners)"
  - `current_club_pct = clubbed / engine_clubbable` ("execution efficiency")
  - `potential_pct = engine_clubbable / completed` ("realistic demand engine sees")
  - `realized_pct = clubbed / completed` ("net outcome")
  - `gap_pct = gap_orders / engine_clubbable` ("missed opportunity"), where `gap_orders = is_clubbable=1 AND clubbed_batch_id IS NULL`
  - `opportunity_pct = opportunity_clubbable / completed` ("theoretical max")
  - `gap_pct_actual = opportunity_pct − realized_pct` ("headroom vs actuals")
  - The comment also documents a version history: v4 (any locked combo) gave Feb `potential_pct` 82%; v5 (all combo partners completed) gave 58.8% but "breaks invariant: actual_clubbed can exceed engine_clubbable"; v6 (current, ≥1 partner completed) gives 78.9% and preserves `clubbed ≤ engine_clubbable`.
- Combo source: `PROD_CURATED.PARTLOAD_ANALYTICS.PTL_VALID_COMBO_LOGS` (engine-generated valid combos as comma-separated order-id lists). Each order is locked to exactly one "best" combo via `ROW_NUMBER()` (highest `order_count` first, tie-broken by most recent `inserted_at`) — documented in-SQL as "a greedy approximation."
- Batch source: `BATCH_V1` + `BATCHED_ORDERS_V1`, restricted (`QUALIFY COUNT(...) OVER (PARTITION BY b.id) > 1`) to batches carrying more than one completed order.
- Time basis: `pickup_date = DATE(pickup_slot_end + INTERVAL '330 minutes')` — **anchored to pickup slot, not order-created-at** — different from almost every other card on this dashboard.
- Denominators for the percentage metrics are all `completed` (`state=3` distinct orders) or `engine_clubbable`, per the formula list above — aggregate-then-ratio is respected (all `COUNT(DISTINCT ...)` first, ratio computed once per period row).

### Card 48449 — "PTL Batching Opportunity - City Wise"
- updated_at: 2026-04-06T11:53:10.216579Z
- Identical logic/comment block to 47540, adds `pickup_city` (joined from `ptl_routes` **without** the `is_active='True'` filter used almost everywhere else on this dashboard) as a grouping dimension.
- **Note**: the saved question's active SQL block (the templated `{{variables}}`/date-range section is commented out) has a **hardcoded `pickup_city in ('Bangalore', 'Mumbai')` filter** — i.e., as saved, this card is scoped to 2 cities regardless of dashboard filters, not templated city selection.

### Card 49365 — "PTL Batching - Full/Partial Match Monthly"
- updated_at: 2026-05-05T06:25:06.454531Z
- **Computation**: classifies every completed order by comparing its actual batch composition to the routing engine's top-2 distance-ranked combo suggestions (`partload_analytics.ALLOCATION_OSRM_v2_DISTANCE`):
  - `FULL_MATCH` = batch members exactly equal either top-2 suggested combo
  - `PARTIAL_MATCH` = batch shares ≥2 orders with either top-2 combo
  - `NO_MATCH` = batched, had a suggestion, but 0-1 shared orders
  - `NO_SUGGESTION` = batched, but no OSRM combo existed for this order
  - `NO_BATCH` = completed but never batched
  - The batch key is built from **all** orders in the batch, completed + cancelled, "so cancelled-partner batches match their combo" (in-SQL comment).
  - `match_pct = (FULL_MATCH + PARTIAL_MATCH) / total_completed`, with per-bucket percentages also reported.
- This measures **routing-engine-accuracy** (did dispatch match what the engine suggested), a different question from 47540's clubbing-opportunity/gap metrics.

### Card 49373 — "PTL Batching RCA - Raw Data"
- updated_at: 2026-05-05T07:02:41.170605Z
- Order-level, non-aggregated version of 49365's classification (exposes `top1_combo_key`, `top1_osrm_pickup_dist_km`, `top2_*`, `batch_key`, `match_type` per order) — a debug/RCA table, no ratio computed at this grain.

## Retention / repeat behavior

### Card 34091 — "Month-on-Month Vendor Retention" (Supply + OKR tabs)
- updated_at: 2026-01-11T17:43:54.671522Z
- **This is VENDOR retention, not customer retention.** Cohorts vendors by their first completed+batched-order month; `month_since_signup = DATEDIFF('month', first_order_month, month)` (0-12 range); retention value = absolute new-vendor count at month 0, else `100 * retained_vendor_name / total_vendor_name` (percent of original cohort still transacting that month).
- Vendor identity is resolved via a **fuzzy join**: normalized (`REPLACE`/`UPPER`) vehicle registration number matched between `order_vehicles` and `gsheet_sync.ptl_vendor_details` — not a hard key, a potential source of mis-attribution.
- Filters: `state=3`, `BATCHED_ORDERS_V1.status=3`, optional `is_test`, optional pickup/drop city.
- Time basis: `orders.updated_at` → IST.

### Card 43896 — "Customer Re-order" (Cancellations tab)
- updated_at: 2026-01-11T16:40:24.805619Z
- The closest thing to customer-side reorder/retention behavior on this dashboard, but narrowly scoped to **same-calendar-day reorder after a cancellation**: for customers who cancelled (`state=4`, `entry_type='CUSTOMER_DECLARED'`, internal users excluded via unconditional `NOT IN`), checks whether the same customer placed a later order the same IST calendar day. Reports `reordered_perc`, `reordered_and_completed_same_day_perc`, and a stricter variant requiring a weight change or a >100m `ST_DISTANCE` shift in pickup/drop coordinates (proxy for "a genuinely different shipment attempt" vs. same-shipment retry).
- Not a general repeat-purchase or cohort-retention metric — cancellation-recovery specific.

### Card 33461 — "Avg orders per trip"
- updated_at: 2026-02-09T10:07:25.59919Z
- `avg_order_per_trip = COUNT(DISTINCT ORDER_EXTERNAL_ID) / NULLIF(COUNT(DISTINCT batch_id), 0)`, restricted to `BATCHED_ORDERS_V1.status=3` (completed batches only), online+offline combined via `UNION` (not `UNION ALL` — same silent-dedup risk noted for card 37104). Optional `delivery_type` (SDD/NDD) filter via the same slot-interval join pattern used in the fulfilment cards.

---

## Metric definitions table

| metric | numerator | denominator | source tables | key filters | card id | card updated_at | confidence |
|---|---|---|---|---|---|---|---|
| Total Orders | — (raw count) | — | orders, ptl_offline_orders | date window, optional is_test/city | 33483 | 2026-07-28 | verified-from-SQL |
| Fulfilment % | COUNT(DISTINCT state=3) | COUNT(DISTINCT external_id), all states | orders, ptl_offline_orders | date window, optional is_test/city | 33485 / 37419 (dup) | 2026-01-09 / 2026-01-11 | verified-from-SQL |
| Fulfilment excl. 60s cancellations | COUNT(DISTINCT state=3) | COUNT(DISTINCT external_id) − COUNT(DISTINCT orders cancelled within 60s of `created_at`, via `ORDER_CANCELLATION_REASONS.created_at`) | orders, ORDER_CANCELLATION_REASONS | date window, optional is_test/city/delivery_type | 33466, 43238, 37104 | 2026-01-11 / 2026-02-09 / 2026-01-11 | verified-from-SQL |
| Cancellation % | COUNT(DISTINCT state=4) | COUNT(DISTINCT external_id) | orders | date window, optional is_test/city | 33539, 34506, 39941 | 2026-01-11 / 2026-04-29 / 2026-01-11 | verified-from-SQL |
| CBDF % | not found | not found | — | — | — | — | **unverified — not computed anywhere on this dashboard** |
| CADF % | not found | not found | — | — | — | — | **unverified — not computed anywhere on this dashboard** |
| AOV (estimated fare basis) | SUM(estimated_fare/100), state=3 | COUNT(DISTINCT id), state=3 | orders | state=3, unconditional internal-user exclusion | 33706 | 2026-01-11 | verified-from-SQL |
| AOV (WD-revised fare basis) | SUM(final_fare), state=3 | COUNT(DISTINCT external_id), state=3 | orders, order_fares, fare_revision_notified, ptl_offline_orders | state=3, unconditional internal-user exclusion | 37413 | 2026-07-28 | verified-from-SQL |
| AOV (with/without discount) | SUM(total_fare±discount)/100, state=3 | COUNT(DISTINCT orders.id), state=3 | orders, order_fares, quotations | state=3, unconditional internal-user exclusion | 52889 | 2026-07-08 | verified-from-SQL |
| Total Revenue | SUM(final_fare), state=3 | — | orders, order_fares, fare_revision_notified, ptl_offline_orders | state=3, internal-user exclusion | 37413 | 2026-07-28 | verified-from-SQL |
| Gross Margin | total_revenue − total_cost (vendor payout, per-batch MAX) | total_revenue | orders, order_vehicles, gsheet_sync.PTL_TABLE | state=3, batch-level cost | 37413 | 2026-07-28 | verified-from-SQL |
| WD Share in Revenue | SUM(actual_fare − estimated_fare) | SUM(fares) | orders, gsheet_sync.ptl_table, order_fares, fare_revision_notified | state=3 | 34284 | 2026-01-11 | verified-from-SQL |
| Orders Clubbed Distribution | trips (distinct batch_id) per order-count bucket | SUM(trips) over all buckets | BATCHED_ORDERS_V1, orders, order_vehicles | state NOT IN (4) | 33460 | 2026-06-01 | verified-from-SQL |
| Clubbing current_club_pct | clubbed (is_clubbable & batched) | engine_clubbable (is_clubbable) | PTL_VALID_COMBO_LOGS, BATCH_V1, BATCHED_ORDERS_V1, orders | state=3 | 47540 / 48449 | 2026-04-06 | verified-from-SQL |
| Clubbing potential_pct | engine_clubbable | completed (state=3) | same as above | state=3 | 47540 / 48449 | 2026-04-06 | verified-from-SQL |
| Clubbing realized_pct | clubbed | completed (state=3) | same as above | state=3 | 47540 / 48449 | 2026-04-06 | verified-from-SQL |
| Clubbing opportunity_pct | opportunity_clubbable (≥2 completed same route+pickup_date) | completed (state=3) | same as above | state=3 | 47540 / 48449 | 2026-04-06 | verified-from-SQL |
| Batching FULL/PARTIAL match % | FULL_MATCH + PARTIAL_MATCH orders | total_completed | ALLOCATION_OSRM_v2_DISTANCE, BATCH_V1, BATCHED_ORDERS_V1, orders | state=3 | 49365 | 2026-05-05 | verified-from-SQL |
| Vendor Retention (M-on-M) | retained_vendor_name (vendors active in month N) | total_vendor_name (original cohort size) | orders, BATCHED_ORDERS_V1, gsheet_sync.ptl_vendor_details | state=3, batch status=3 | 34091 | 2026-01-11 | verified-from-SQL |
| Customer same-day reorder % | reordered_same_day (distinct customers) | customers_cancelled | orders, load_details | state=4 → state=3/4, CUSTOMER_DECLARED | 43896 | 2026-01-11 | verified-from-SQL |
| Avg orders per trip | COUNT(DISTINCT ORDER_EXTERNAL_ID) | COUNT(DISTINCT batch_id) | BATCHED_ORDERS_V1, orders, order_vehicles, ptl_offline_orders | batch status=3, optional delivery_type | 33461 | 2026-02-09 | verified-from-SQL |
| Order Funnel stages | COUNT(DISTINCT external_id) by state bucket (total/completed/cancelled/inprocess) | n/a (raw counts) | orders, order_vehicles, quotations, slots, ptl_offline_orders | date window, optional delivery_type/user_type/new_repeat | 33462 | 2026-07-28 | verified-from-SQL |

---

## Cancellation logic specifically

**Key finding: no card on this dashboard computes CBDF or CADF as named/distinct metrics.** Every cancellation-related card treats cancellation as a single, undifferentiated bucket: `orders.state = 4`. None of the 7 cancellation-related cards inspected (33539, 34506, 33464, 33465, 35252, 35253, 39941) — nor the Order Funnel (33462) or Fulfilment cards (33466/43238/37104) — join `ORDER_VEHICLES` (or any vehicle-assignment timestamp) to split "cancelled before a vehicle/driver was assigned" from "cancelled after assignment." This appears to be a genuine gap on this dashboard relative to the CBDF/CADF vocabulary used elsewhere in the project.

### Card 33539 — "Cancellation %"
- updated_at: 2026-01-11T16:34:26.54781Z
- `cancellation_perc = COUNT(DISTINCT CASE WHEN state = 4 THEN external_id END) / NULLIF(COUNT(DISTINCT external_id), 0)`, denominator = `placed_orders` = all distinct orders in window (online only — no offline union, unlike Total Orders/Fulfillment).
- No `<60s` exclusion.
- Quote: `COUNT(DISTINCT CASE WHEN state = 4 THEN external_id ELSE NULL END) as cancelled_orders, cancelled_orders / NULLIF(placed_orders, 0) AS cancellation_perc`

### Card 34506 — "Cancellation % - Number"
- updated_at: 2026-04-29T12:02:45.776123Z
- Same `state=4` definition, returns `fulfillment_perc` and `cancellation_perc` side by side, denominator = all distinct orders. No `<60s` exclusion. Online-only.
- Quote: `COUNT(DISTINCT CASE WHEN state = 4 THEN external_id ELSE NULL END) / NULLIF(COUNT(DISTINCT external_id), 0) AS cancellation_perc`

### Card 33464 — "Cancellation distribution reason wise"
- updated_at: 2026-01-11T16:35:07.9556Z
- Grain: cancelled orders by `reason` (free-text from `ORDER_CANCELLATION_REASONS.reason`; values starting with "other" collapsed to `'Text Box'`). `count(distinct order_id)`. No vehicle-assigned split, no `<60s` exclusion.

### Card 33465 — "Cancellation distribution source wise"
- updated_at: 2026-01-11T16:35:30.231494Z
- Grain: cancelled orders by `cancellation_source` code: 1=Customer_App, 2=Partner_App, 3=Salesforce, 4=Appsmith. Same source table, no vehicle-assigned split, no `<60s` exclusion.

### Card 35252 — "Cancellation (Median/P90)"
- updated_at: 2026-01-11T16:35:47.989329Z
- Time-to-cancel = `DATEDIFF('second', orders.created_at, orders.updated_at)` — **uses `orders.updated_at`, NOT `ORDER_CANCELLATION_REASONS.created_at`** (a different timestamp source than cards 33466/43238/37104's 60s-exclusion logic). Avg/median/P90 in minutes. Filters `state = 4`; excludes internal users via unconditional `CUSTOMER_MOBILE NOT IN (SELECT MOBILE FROM PTL_INTERNAL_USERS)` (no `is_test` toggle on this card).
- No `<60s` exclusion — the fastest bucket (0-5 min, see 35253) is included in the average/percentile, i.e. this card's numbers **include** the same sub-60-second cancellations that 33466/43238 explicitly strip out elsewhere.
- Quote: `ROUND(AVG(DATEDIFF('second', created_at, updated_at)) / 60.0, 2) AS avg_cancel_time_mins ... PERCENTILE_CONT(0.5) ... PERCENTILE_CONT(0.9) ...`

### Card 35253 — "Cancellation (Time Bucket)"
- updated_at: 2026-01-11T16:36:01.649168Z
- Same `DATEDIFF('second', created_at, updated_at)` basis as 35252. Buckets: 0-5 min, 5-15 min, 15-30 min, >30 min. Same unconditional internal-user exclusion, `state = 4` filter, no `<60s` exclusion.
- Quote: `CASE WHEN DATEDIFF('second', created_at, updated_at) / 60 <= 5 THEN '0–5 mins' ... ELSE '> 30 mins' END AS cancellation_time_bucket`

### Card 39941 — "Route Level - Orders Cancelled Trends" (Route Level tab; collection_id 5207 "Product Observability" — different collection)
- updated_at: 2026-01-11T18:02:20.696335Z
- `cancellation_pct = ROUND(cancel_orders / NULLIF(total_orders, 0), 2)` per route per period, `cancel_orders = COUNT(DISTINCT CASE WHEN state='4' THEN order_id END)`. Unconditional internal-user exclusion via `NOT IN`. No `<60s` exclusion.

### Cancellation logic — summary table
| Card | Cancel definition | Time-to-cancel source | `<60s` exclusion? | Internal-user handling |
|---|---|---|---|---|
| 33539, 34506, 39941 | `state=4` | n/a | No | `is_test` param (33539/34506) or unconditional `NOT IN` (39941) |
| 33464, 33465 | row exists in `ORDER_CANCELLATION_REASONS` | n/a | No | `is_test` param |
| 35252, 35253 | `state=4` | `orders.updated_at` | No | unconditional `NOT IN` |
| 33466, 43238, 37104 | `state=4` (for `cancellation_perc`); separately, orders with `DATEDIFF(sec, created_at, ocr.created_at) <= 60` dropped from the fulfilment denominator | `ORDER_CANCELLATION_REASONS.created_at` | **Yes**, but only inside the fulfilment-percentage calculation, not as a standalone cancellation metric | `is_test` param |

---

## Conflicts

`CONFLICT: CBDF/CADF do not exist on this dashboard.` All cancellation logic across every card inspected (33539, 34506, 33464, 33465, 35252, 35253, 39941, 33462, 33466, 43238, 37104) uses a single flat `state=4` bucket. No card joins `ORDER_VEHICLES` or any vehicle/driver-assignment timestamp to distinguish cancelled-before-assignment from cancelled-after-assignment. `UNRESOLVED` — cannot verify from this dashboard whether CBDF/CADF is computed elsewhere (a different Metabase collection, a dbt model, or another dashboard); other P3x workers' extracts should be checked.

`CONFLICT: two different "time to cancel" timestamp sources.` Cards 35252/35253 use `orders.updated_at`; cards 33466/43238/37104 use `ORDER_CANCELLATION_REASONS.created_at`. These will disagree if `updated_at` is touched by any other mutation between order creation and the cancellation-reason write. `UNRESOLVED`.

`CONFLICT: three distinct "revenue"/AOV bases coexist.` Card 33706 uses `orders.estimated_fare` (pre-any-revision, completed orders, `updated_at` time basis). Card 37413 uses a WD-revised `final_fare` (falls back to `estimated_fare` only if no customer-notified weight revision exists, `created_at` time basis). Card 52889 uses `order_fares.total_fare` with a separate discount add-back from `quotations.discount_amount_minor_units` (`updated_at` time basis). All three are live on the dashboard simultaneously (Overview, Finance/OKR, and Finance tabs respectively) and will produce different AOV/revenue numbers for the same date range. `UNRESOLVED`.

`CONFLICT: "Fulfilment %"-titled cards are multi-metric, not single-metric.` Cards 33466, 43238, and 37104 are each titled around one fulfilment concept but their SQL returns 4-5 different percentages (plain fulfilment, 60s-exclusion fulfilment, cancellation %, in-process %, and a clustered/deduped "unique fulfilment" %) in the same result set. Card 37413 similarly bundles revenue + AOV + vendor cost + gross margin under the title "Total Revenue." Not a numeric conflict, but a title-vs-content mismatch pattern repeated across the dashboard — see per-card mismatch notes above.

`CONFLICT: online/offline union style is inconsistent (UNION vs UNION ALL).` Cards 33483, 33485, 33466, 43238, 33462, 33460 use `UNION ALL` between online and offline order sets; cards 37104 and 33461 use plain `UNION`, which silently de-duplicates any fully-identical row between the two sources. Given the two sources use different id spaces (app `external_id` vs gsheet `ORDER_EXTERNAL_ID`) an accidental collision is unlikely but not structurally impossible. `UNRESOLVED` (low-severity, flagged for completeness).

`CONFLICT: batching-population scope differs across clubbing cards.` Card 33460 ("Orders Clubbed Distributions") includes all non-cancelled orders (states 0,1,2,3) in its batching population; cards 47540/48449/49365 restrict to completed (`state=3`) orders only. Numbers from these card families are not directly comparable. `UNRESOLVED`.

---

## Cards not opened

~55 of the ~82 unique underlying cards were not opened, deprioritized because they fall outside the fulfilment/cancellation/orders/AOV-revenue/clubbing/retention theme list given in the brief. Grouped by theme with reason:

**Utilization (Utilization tab — vehicle capacity/volumetric metrics, not order economics)**: 33807 (On-Ground Utilization), 33808 (Overall Estimated Utilization), 34498 (Estimated & On-Ground Utilization Trend), 44651 (Return Trip On-Ground Utilization).

**SLA / on-time performance (SLA tab — delivery timing, not fulfilment/cancellation definitions)**: 33784 (On-Time Pickup), 33785 (On-Time Delivery), 33823 (Overall On-Time Pickup), 33824 (Overall On-Time Delivery), 34049 (Batch Pick-Up Dry runs), 34051 (Batch Drop Dry run), 34052 (Perfect Order Experience %), 34364 (Perfect Order Experience % - Trend), 34392 (Pickup Delay distribution), 34490 (Delivery delay distribution), 34522 (Loading and Unloading Time - Modified).

**Support / call-center (Support tab — CX ops metrics, unrelated to order/cancellation/revenue definitions)**: 33722 (CPO), 33732 (IPO), 33737 (Calls AHT), 33815 (Dialed Back%/Attempted %/Connected %), 33817 (Unique Request Not Dialed), 33830 (Overall Agent Count And Occupancy), 33832 (Agent Calls), 33851 (Outbound dialed back P90 TAT), 34093 (TPO at Issues Level), 34094 (Overall FCR%), 35064/35066/35068 (IPO/CPO/TPO smartscalar duplicates), 38800 (TPO line-chart duplicate).

**Supply / vendor ops (Supply tab — vendor-side cost/rejection metrics, not demand-side metric definitions)**: 34089 (Vendor's Earning), 34090 (Trip Per Vendor), 34092 (Rejected Trip by Vendor), 33555 (Vehicle category supply).

**Demand distribution (Demand Distribution tab — dimensional breakdowns of already-defined order counts, not new metric logic)**: 33468 (Order Distribution Weight Slab Wise), 33469 (Demand Distribution slot wise), 33470 (Demand Distribution Goods type wise), 36096 (Declared Goods Discrepancy Distribution), 36089 (Declared–Actual Pair Order Share), 41418 (Distance Level - Order Share), 43252 (Order Distribution Route and Weight Slab Wise), 43263 (Month on Month Growth - Routes).

**Order Share tab (dimensional cuts of order share, not new metric logic)**: 42417 (Pickup City wise Order Share), 42439 (Distance bucket wise order share), 42419 (Route wise Order Share, also duplicated on Route Level tab).

**Route Level tab (route-dimensional cuts of metrics already extracted at the aggregate level)**: 36360 (Route Level Overview), 36361 (Route Level - Orders Placed Trend), 36682 (Overall Metrics - Slot wise), 39164 (Slot Changes), 37638 (Route Level - Orders Completed Trend), 43872 (Month on Month Growth - Routes, current-month-excluded variant).

**Finance tab, deprioritized**: 33703 (Earnings per trip — driver/vendor earnings, not customer-facing revenue), 37416 (Gross Margin, OKR-tab duplicate of the gross-margin logic already extracted from card 37413).

**Overview/OKR-tab duplicates already covered by an opened sibling**: 34174 (Order Status Distribution by Pickup Slot — dimensional cut of the Order Funnel's state buckets), 44691 (Return Trips % — utilization-adjacent, not a fulfilment/cancellation/revenue metric), 37417 (Avg orders per trip, OKR-tab duplicate of card 33461, not independently opened but presumed identical by naming/placement pattern — **not verified**, flag as such rather than asserting duplication).

All of the above were judged out of scope for the fulfilment / cancellation (CBDF/CADF) / orders / AOV-revenue / allocation / clubbing-batching / retention priority list in the task brief. None were skipped due to access issues — Metabase access remained available (`ok`) throughout, apart from one transient rate-limit that was resolved by retrying after a backoff.
