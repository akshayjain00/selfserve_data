# P4a — Verification: Dashboard 4198 card claims

Verification worker pass. Metadata reads only (`get_card`) — no query execution. Column NAMES only recorded, no data values, no creator identities.

## Fingerprint table

| card_id | name | updated_at | database_id |
|---|---|---|---|
| 33485 | Fulfillment | 2026-01-09T09:12:11.968692Z | 73 |
| 37419 | Fulfillment | 2026-01-11T18:11:46.47786Z | 73 |
| 33466 | Fullfillment % | 2026-01-11T16:16:18.244047Z | 73 |
| 43238 | Fullfillment excluding 60sec cancellations % | 2026-02-09T09:57:42.307966Z | 73 |
| 37104 | Fullfillment % - Split | 2026-01-11T17:50:47.592584Z | 73 |
| 33706 | AOV | 2026-01-11T16:14:14.926437Z | 73 |
| 37413 | Total Revenue | 2026-07-28T09:54:29.576872Z | 73 |
| 52889 | Revenue - Trend -Discount | 2026-07-08T08:01:17.807725Z | 73 (collection "Raw tables", id 5198 — the only card of the set NOT in "Business Observability" collection 5199) |
| 33460 | Orders Clubbed Distributions | 2026-06-01T07:38:50.122978Z | 73 |
| 47540 | PTL Batching Opportunity | 2026-04-06T11:49:21.009497Z | 73 |
| 48449 | PTL Batching Opportunity - City Wise | 2026-04-06T11:53:10.216579Z | 73 |
| 49365 | PTL Batching - Full/Partial Match Monthly | 2026-05-05T06:25:06.454531Z | 73 |
| 33461 | Avg orders per trip | 2026-02-09T10:07:25.59919Z | 73 |
| 33462 | Order Funnel | 2026-07-28T09:54:28.56141Z | 73 |
| 33483 | Total Orders | 2026-07-28T09:54:27.567792Z | 73 |

---

## Fulfilment family

### 33485 vs 37419 — "byte-identical duplicates" claim

**REFUTED** (not byte-identical) / formula: **CONFIRMED**.

Both compute the exact same final metric:
```
COUNT(DISTINCT CASE WHEN state = 3 THEN external_id ELSE NULL END)
    / NULLIF(COUNT(DISTINCT external_id), 0) AS fulfillment_perc
```
over the same online+offline union, no state filter on denominator → completed(state=3)/all-states. Formula claim CONFIRMED.

But the two cards are **not byte-identical text**. Diff found in both the `online` and `offline` CTE join predicates:
- 33485: `left join ... ptl_routes on ptl_routes.route_id = orders.route_id and is_active = 'True'`
- 37419: `left join ... ptl_routes on ptl_routes.route_id = orders.route_id and ptl_routes.is_active = 'True'`

(unqualified `is_active` vs `ptl_routes.is_active` — same repeated in the offline CTE). Functionally equivalent, but not a byte-identical duplicate. They also differ in `display` (33485 = `smartscalar`, 37419 = `bar`), `created_at` (2025-05-26 vs 2025-08-07), and view_count (25,454 vs 353 — 37419 looks like a rarely-used stray copy). Verdict: **PARTIAL** — same formula, not the same SQL text.

### 33466, 43238, 37104 — `<60s` denominator-exclusion + "5 metrics" claim

**`<60s` predicate, verbatim** (identical in 33466, 43238, 37104):
```sql
COUNT(DISTINCT CASE WHEN state = 3 THEN external_id END) * 1.0
    / NULLIF(
        COUNT(DISTINCT external_id) -
        COUNT(DISTINCT CASE WHEN DATEDIFF(SECOND, created_at, ocr_created_at) <= 60 THEN external_id END),
        0
      ) AS fulfillment_excluding_60second_cancellations,
```
`ocr_created_at` = `ORDER_CANCELLATION_REASONS.created_at`. The `<60s` orders are subtracted from `COUNT(DISTINCT external_id)` — i.e. dropped from the **DENOMINATOR**, numerator (`state=3` count) is untouched. **CONFIRMED** for all three cards, identical predicate and identical placement.

**"5 metrics, not 1" — CONFIRMED for 33466 and 43238, REFUTED for 37104.**
- 33466 and 43238 both return the same 5-metric block: `fulfillment_perc, fulfillment_excluding_60second_cancellations, cancellation_perc, inprocess_order_perc, unique_fulfillment_perc`. Confirmed 5 metrics.
- 37104 ("Fullfillment % - Split") only returns **3** metrics — `fulfillment_perc`, `fulfillment_excluding_60second_cancellations`, `unq_fulfillment_pct` — split by an `EDD` (Same day/Next day) dimension instead of carrying `cancellation_perc`/`inprocess_order_perc`. So the "5 metrics" claim does **not** hold uniformly across the family; only 2 of the 3 cards return 5.

Verdict: **PARTIAL** overall — `<60s` denominator placement confirmed for all 3; metric-count claim confirmed only for 33466/43238, refuted for 37104.

---

## AOV family

### 33706 — "uses estimated_fare" + date basis

**CONFIRMED** on both counts.
```sql
select
	date_trunc({{period}}, date(updated_at + interval '330 mins')) as date,
	count(distinct id) as orders,
	sum(estimated_fare/100) as revenue,
	revenue/orders as aov
from partload_application.orders
...
where state ='3'
```
Uses raw `orders.estimated_fare` (no `order_fares` join at all). Date basis is **`updated_at`**, not `created_at` — resolves G-007: `date(updated_at + interval '330 mins')`.

### 37413 — weight-discrepancy-revised final_fare + revenue/vendor-cost/GM

**CONFIRMED.**
```sql
with wd_fare as (
	select order_id, total_fare/100.0 as total_fare, is_current_fare, order_fare_id, IS_CUSTOMER_NOTIFIED
	from ...order_fares of_
	inner join ...fare_revision_notified nf on nf.order_fare_id = of_.id and nf.IS_CUSTOMER_NOTIFIED = 'true'
	where is_current_fare = 'true'
)
...
COALESCE(wd_fare.total_fare, o.estimated_fare/100.0 ) AS final_fare,
```
`final_fare` = current fare **only when it came from a customer-notified fare revision** (the weight-discrepancy-notification join), else falls back to `estimated_fare`. Returns `aov`, `total_revenue` (`SUM(final_fare)`), `total_cost` (vendor payout from `PTL_TABLE.TOTAL_VENDOR_PAYOUT`), and `gm` = `(total_revenue - total_cost)/total_revenue`. Matches claim: revenue + vendor cost + gross margin, all present. Date basis here is **`created_at`** (not `updated_at` — differs from 33706/52889, see note below).

### 52889 — "uses total_fare + discount"

**CONFIRMED.**
```sql
sum(total_fare / 100)                                                as revenue_without_discount,
sum((total_fare + coalesce(q.discount_amount_minor_units, 0)) / 100) as revenue_with_discount,
...
revenue_with_discount / orders  as aov_with_discount,
revenue_without_discount / orders as aov_without_discount
from partload_application.orders
left join partload_application.order_fares f on f.order_id=orders.id and f.is_current_fare = TRUE
left join partload_application.quotations q on q.quotation_uuid = orders.quotation_uuid
```
`total_fare` here resolves to `order_fares.total_fare` (current fare, **not** filtered by customer-notification), grossed up by `quotations.discount_amount_minor_units`. Date basis is `updated_at` (same convention as 33706).

### Are these really three different bases?

**Yes — genuinely three different computations**, not naming variants of one:
1. **33706**: raw `orders.estimated_fare` — the original customer quote, no revision logic at all.
2. **37413**: `COALESCE(order_fares.total_fare WHERE customer-was-notified-of-a-weight-revision, estimated_fare)` — narrowest/most conditional base.
3. **52889**: `order_fares.total_fare` (any current fare, revision reason unconstrained) **+ discount added back** — broadest current-fare base, plus a discount gross-up neither of the other two cards performs.

Subtlety worth flagging: 37413's `total_fare` and 52889's `total_fare` both ultimately come from the same `order_fares` table, but 37413 restricts to rows joined through `fare_revision_notified` (customer-notified weight revisions only) while 52889 takes whichever row has `is_current_fare = TRUE` unconditionally — so even where both use "total_fare" as a word, the row-set behind it differs. Also note: **date basis is not uniform across the family** — 33706 and 52889 key off `updated_at`, 37413 keys off `created_at`. Any AOV reconciliation across these three cards must account for that as well as the fare-basis difference.

---

## Clubbing family

### 33460 — population = all non-cancelled states

**CONFIRMED.**
```sql
where ORDERS.state not in (4)          -- online CTE
...
where ptl_offline_orders.state not in (4)   -- offline CTE
```
Only state 4 (cancelled) excluded; states 0/1/2/3 all included. Matches "all non-cancelled states."

### 47540, 48449, 49365 — population = completed only (G-011)

**CONFIRMED** for all three, with two unrelated defects surfaced (see below).

- 47540: every clubbing metric (`engine_clubbable`, `clubbed`, `gap_orders`, `current_club_pct`, `potential_pct`, `realized_pct`, `opportunity_pct`, etc.) is computed with an explicit `state=3` predicate inside every `COUNT(DISTINCT CASE WHEN state=3 AND ... THEN order_id END)`. Population is completed-only.
- 48449: identical CTE stack to 47540 (same `is_clubbable`/`has_viable_partner` logic, same `state=3` gating), plus a `pickup_city` breakout. Completed-only confirmed.
- 49365: `completed_orders` CTE is explicitly `WHERE o.state = 3 ...`. Completed-only confirmed.

**Two defects found, not asked about, worth flagging to the KB:**
1. **47540 and 48449 have inert Start/End Date parameters.** Both cards declare `{{start_date}}`/`{{end_date}}`/`{{variables}}` template tags, but the *active* query (Section B, "MONTHLY") only uses `{{granularity}}` and hardcodes `WHERE pickup_date >= '2026-02-01'` (48449 additionally hardcodes `AND pickup_city in ('Bangalore', 'Mumbai')`). The `{{start_date}}`/`{{end_date}}`/`{{variables}}` tags are only referenced in a **commented-out** "Section A" block. So changing Start Date / End Date in the Metabase UI for these two cards currently does nothing — the card silently floors at Feb 2026 (and 48449 is silently hardcoded to only Bangalore/Mumbai, not the general "city-wise" tool its name implies).
2. **49365 has a stricter hidden floor than its own date parameters imply.** The final `WHERE` clause correctly uses `{{start_Date}}`/`{{end_Date}}`, but the upstream `completed_orders` CTE independently hardcodes `DATE_TRUNC('month', o.created_at + INTERVAL '330 minutes') >= '2026-03-01'`. Setting Start Date earlier than March 2026 will silently return nothing for that earlier window rather than erroring.

### 33461 — avg orders per trip = clubbed orders / clubbing trips

**CONFIRMED.**
```sql
select dated,
count(distinct ORDER_EXTERNAL_ID)/NULLIF(COUNT(DISTINCT batch_id), 0) as avg_order_per_trip
from final
group by 1
```
Numerator = distinct order_external_id from `BATCHED_ORDERS_V1` (online, filtered `status=3` i.e. completed batch) unioned with offline orders filtered `TRIP_LEVEL_CONSIDERATION='yes'`; denominator = distinct `batch_id`. Matches "clubbed orders / clubbing trips" exactly.

---

## Lineage question (G-118): 33462 vs 33483

**Not the same computation — 33483 cannot answer "completed orders" at all.**

- **33462 ("Order Funnel")** final select:
```sql
select dated,
count(distinct external_id) as total_orders,
count(distinct case when state=3 then external_id end) as completed_orders,
count(distinct case when state=4 then external_id end) as cancelled_orders,
COUNT(DISTINCT CASE WHEN state in (0,1,2) THEN external_id ELSE NULL END) inprocess_order
from final
group by 1
```
Returns **4** state-based order counts in one row per date: total, completed (state=3), cancelled (state=4), in-process (0/1/2).

- **33483 ("Total Orders")** final select:
```sql
select dated, sum(total_orders) AS total_orders
from FINAL
group by 1
order by dated asc
```
Returns **only** `total_orders` — a straight `count(distinct external_id)` with **no state filter anywhere** in the query. There is no `completed_orders` column, and no `state=3` predicate exists in 33483's SQL at all.

**Precise difference:** 33462 computes a 4-way state breakdown (including `completed_orders`, `state=3`) over an order universe built with a newer, migration-aware join stack (`ORDER_VEHICLES` is_active filter, `dim_customers` direct join, a `route_configuration_id`-based slot-mapping that only applies to orders created on/after the hardcoded cutover `'2026-04-29 16:58:08.421000'`, falling back to the legacy `slot_intervals_old` logic before that date). 33483 computes a single all-states total using the legacy slot/customer-frequency join style only (aggregated `dcust` subquery, no `ORDER_VEHICLES` join, no route_configuration cutover logic).

**Which is canonical for "completed orders, business":** **33462**. It is the only one of the two whose SQL contains a `completed_orders` formula at all; 33483 is architecturally a total-orders-only card (all states) and cannot be repurposed for a completed-orders metric regardless of how its `customer_type=Business` parameter is set — filtering it to Business customers still only yields a **total**, not a **completed**, count. The catalog/registry pointing at 33462 for "Completed Orders" is the right call, even though 33462's own card title is "Order Funnel," not "Completed Orders" — the two cards were both last edited within 1 second of each other (33462: 09:54:28.56Z, 33483: 09:54:27.57Z) on 2026-07-28, suggesting a coordinated edit pass, but they are not interchangeable.
