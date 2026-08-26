# PnM Self-Serve — Gem Knowledge Base

**Audience:** Porter Packers & Movers (PnM) city operations teams, via a Gemini Gem.
**Purpose:** the single grounding document for that Gem. If a table, column, metric or dashboard is
not in this file, it does not exist as far as the Gem is concerned.

**Compiled** 2026-07-29. **Nothing here is stakeholder-approved.** Every metric in §2 is
`prototype_only` — validated against the owner's live MBR automation, but not signed off for
leadership-facing use. Only the owner (akshay.jain@theporter.in) promotes readiness.

---

## §0 · Provenance — where each fact comes from

Every fact below carries one of these tags. Nothing is written here without one.

| Tag | Meaning |
|---|---|
| `[REG]` | `pnm-selfserve/selfserve_nlq/metrics_registry.py` — the shipped metric registry |
| `[SQL]` | `pnm-selfserve/selfserve_nlq/tests_output/rendered_*_2026-05.sql` — the exact SQL that runs |
| `[AUTO]` | `ProdOps/pnm/pnm_mbr_monthly_metrics/queries.py` — the owner's live-validated MBR automation |
| `[LOG]` | `pnm-selfserve/DECISION_LOG.md` (D1–D10, V1–V4) |
| `[LEDGER]` | `pnm-selfserve/iteration-2-readiness-ledger.md` |
| `[IT1]` / `[IT3]` | `iteration-1-metric-catalog-and-architecture.md` / `iteration-3-p80-orderedits-spec.md` |
| `[RECON]` | `selfserve_nlq/tests_output/reconciliation_2026-07-19.md` |
| `[NOTION]` | Notion "Eldoria PnM Schema Guide" — **snapshot 2026-03-31, partly stale** (see §7) |
| `[LIVE]` | Snowflake `INFORMATION_SCHEMA.COLUMNS`, queried read-only **2026-07-29** |
| `[MB]` | Metabase / Data Catalog card + dashboard metadata, resolved **2026-07-29** |
| `[SLACK]` | `#pnm-analytics` (C02FQDRAAUT), attributed by poster + date |

**Precedence when sources disagree.** The brief for this file said: prefer the Notion schema guide for
schema facts, and the readiness ledger for metric status. The second half is applied as written —
`[LEDGER]`/`[LOG]` decide readiness. **The first half is deliberately reversed, and that is a
deviation you should know about:** `[LIVE]` wins for column names and types, because the warehouse
itself contradicts Notion in five specific places and a query written to Notion's types would fail
outright (all five are itemised in §7-Q2). `[NOTION]` remains the best source for *business meaning*
and enum values, and is cited as such throughout. No conflict is hidden — §7 lists every one.

### Deviations from the requested spec — read these three
1. **`[LIVE]` overrides `[NOTION]` for column names and types**, reversing the stated precedence rule.
   Reason and evidence: §7-Q2.
2. **There is no `{{city}}` placeholder in §5's SQL templates**, though the brief asked for one. The
   six metric sections are PnM-wide by construction and no city-filtered variant has ever been
   reconciled; emitting one would give city ops a query that looks validated but is not. City
   questions route to §4's dashboards, which do have real city filters. This is the largest gap
   between this file and its audience — see §7-Q1.
3. **`{{end_date}}` is derived, not exposed.** Every template in §5 takes `{{start_date}}` only and
   computes the month's exclusive upper bound itself. The bound is `<` the first day of the *next*
   month, so hand-entering it is a footgun for a non-technical user (enter the month's last day and
   you silently lose a day). Deriving it removes that failure mode.
4. **Readiness comes from the readiness ledger's *rules*, but which sections exist comes from the
   later decision log.** The brief said to prefer the readiness ledger for metric status. Its
   vocabulary and its central verdict are applied unchanged — `prototype_only` / `blocked`, and
   "nothing is READY FOR STAKEHOLDERS". But that ledger is dated 2026-07-07 and lists
   `p80_durations` and `order_edits` as **NOT BUILT**; both were built and reconciled on 2026-07-19
   `[LOG D8–D10, V4]` `[RECON]`. Following the ledger literally would delete 17 of the 47 metrics
   below and tell city ops that working measures do not exist. §2 therefore uses the registry + V4
   for existence and the ledger for status.

**One thing this file deliberately does NOT contain:** any metric from `iteration-1`'s original
49-column catalog. That catalog was superseded — its metric names (`p80_trip_duration_mins`,
`num_successful_edits`, …) exist nowhere. `[LOG D3/D5/D8]`

---

## §1 · PnM business primer

### What the business does
A customer moving house tells Porter what they need moving and where. Porter quotes a price, the
customer books, Porter allocates a vendor (a packing-and-moving crew with a vehicle) and a supervisor,
and the crew executes the move. Support handles anything that goes wrong. `[NOTION]`

### The order lifecycle
```
Customer interest
   ↓
Opportunity  ("lead")      — customer has expressed a requirement
   ↓
Order        ("booking")   — customer has committed
   ↓
Fare calculation
   ↓
Vendor execution           — accept → supervisor assigned → trip started
                             → shifting started → pickup completed → order completed
   ↓
Support & experience signals (tickets, NPS)
```
`[NOTION]`

### Execution stages, in plain words
These six timestamps are what every duration metric is built from. `[LIVE]` `[SQL]`

| Stage timestamp | What actually happened |
|---|---|
| `VENDOR_OWNER_ACCEPTED_TS_IST` | The vendor owner accepted the job |
| `SUPERVISOR_ASSIGNED_TS_IST` | A supervisor was assigned to it |
| `SUPERVISOR_ACCEPTED_TS_IST` | The supervisor accepted it |
| `TRIP_STARTED_TS_IST` | The crew set off towards the customer's pickup address |
| `SHIFTING_STARTED_TS_IST` | The crew began the actual move |
| `PICKUP_COMPLETED_TS_IST` | Everything was loaded |
| `ORDER_COMPLETED_TS_IST` | The move finished |

> ⚠ **The trap:** every duration metric labelled "Supervisor Assigned" is actually measured from
> `SUPERVISOR_ACCEPTED_TS_IST`, not `SUPERVISOR_ASSIGNED_TS_IST` — even though both columns exist.
> This is copied deliberately from the validated automation and must not be "fixed". `[REG]` `[AUTO]` `[IT3]`

### Key entities and their grain

| Entity | Grain (one row =) | Where it lives `[LIVE]` |
|---|---|---|
| Opportunity / lead | one lead | `PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY` + `DIM_PNM_OPPORTUNITY` |
| Order / booking | one order | `PROD_ELDORIA.CORE.FACT_PNM_ORDERS` + `DIM_PNM_ORDERS` |
| Shifting requirement (SR) | one requirement | `PROD_CURATED.PNM_APPLICATION.SHIFTING_REQUIREMENTS` |
| Customer | one mobile number | `PROD_ELDORIA.MART.PNM_CUSTOMERS` |
| Order experience | one order | `PROD_ELDORIA.MART.PNM_EXPERIENCE` |
| Support ticket | one ticket | `PROD_CURATED.SFMS_PUBLIC.HS_TICKETS` |
| Vendor | one vendor owner | `PROD_ELDORIA.CORE.DIM_PNM_VENDORS` |

One customer → many leads → each lead may become an order. `SR_ID` is the thread that ties a lead to
its order. `[NOTION]` `[LIVE]`

### Date grains — which date a number is counted on

This is the most common source of "your number doesn't match mine". Each metric section counts on a
**different** date, and they are not interchangeable. `[REG]`

| Section | Counted on | Plain English |
|---|---|---|
| leads | `opp_created_ts` | the month the lead came in |
| orders | `o_created_ts` | the month the customer booked |
| derived | both, same month | ratio of the two above |
| tpo | allocation completion (`completed_ts` + 330 min → IST) | the month the job's allocation completed |
| p80_durations | `SHIFTING_TS_IST` | the month the move was scheduled to happen |
| order_edits | `ORDER_CREATED_TS_IST` | the month the customer booked |

So a move booked in April and executed in May appears in **April's** order count and **May's**
duration figures. Both are correct. `[REG]` `[IT3]`

### City grain — read this before answering any city question
The catalog in §2 is **PnM-wide only. It cannot be cut by city.** City columns do exist in the
warehouse (`PICKUP_CITY_NAME`, `PICKUP_GEO_REGION_ID` on the order/opportunity dims and on
`PNM_EXPERIENCE`, `PNM_SUPPORT`, `PNM_ALLOCATION`, `PNM_FARE_MOVEMENT`) `[LIVE]`, and the
**dashboards in §4 do filter by city** `[MB]` — but no city-level query has ever been reconciled, so
§5's templates have no city parameter. City questions go to §4 or to a data request. `[REG]` `[LOG]`

The 14 cities PnM operates in, with their `GEO_REGION_ID` `[LIVE DIM_GEO_REGIONS]` `[NOTION]`:

| ID | City | ID | City | ID | City |
|---|---|---|---|---|---|
| 1 | Mumbai | 6 | Ahmedabad | 11 | Lucknow |
| 2 | Delhi | 7 | Jaipur | 12 | Coimbatore |
| 3 | Bangalore | 8 | Pune | 13 | Indore |
| 4 | Hyderabad | 9 | Kolkata | 14 | Nagpur |
| 5 | Chennai | 10 | Surat | | |

Note the Metabase city picker spells Ahmedabad **"Ahemdabad"** and offers **"Delhi NCR"**. `[MB]`

### Nano — the single most important business rule
"Nano" packages (`Nano Shifting`, `Nano Shifting Medium`, `Nano Shifting Large`) `[NOTION]` are
**labour-only help — no vehicle, no vendor allocated**. They belong to **LA (Labour Assist)**, a
different business group, not to PnM. `[LOG D4]`

- **Leads INCLUDE Nano** — nano demand still arrives through the PnM funnel.
- **Orders, TPO, p80, order_edits EXCLUDE Nano** — those bookings are LA's.

So conversion = *non-Nano orders ÷ Nano-inclusive leads*. It is deliberately asymmetric and reads
slightly lower than a like-for-like ratio. Never "correct" this. `[LOG D4]` `[REG]`

### Intra-city only
Everything in §2 is filtered to `shifting_type = 'intra_city'`. Inter-city / vehicle-shifting /
labour moves are out of scope for the catalog. `[REG]` `[SQL]`

---

## §2 · Metric dictionary

**47 metrics in 6 sections, all `readiness: prototype_only`.** Plus `ota`, which is `blocked` and has
no queryable metrics. `[REG]` `[LEDGER]` `[LOG V4]`

Readiness meanings `[REG]`:
- `prototype_only` — reconciles with the owner's validated automation; **not** signed off for
  stakeholder or leadership use.
- `blocked` — cannot be queried at all until a structural problem is resolved.

Grain is **monthly** for every metric. There is no daily, weekly or quarterly metric in the catalog. `[REG]`

### 2.1 `leads` — 5 metrics · prototype_only
- **Counted on:** month of `opp_created_ts` · **Nano:** INCLUDED
- **Source:** `PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY` + `DIM_PNM_OPPORTUNITY`
- **Population:** `user_flag ILIKE 'normal'`, `shifting_type = 'intra_city'` **or NULL**

| Metric | Plain English | Formula |
|---|---|---|
| `leads_overall` | How many leads came in | `COUNT(DISTINCT opp_id)` |
| `leads_app` | Leads from the Porter app | channel = App (`source IN (1,2,3)`) |
| `leads_desktop` | Leads from the desktop website | `source_details = 'Desktop Website'` |
| `leads_mobile` | Leads from the mobile website | `source_details = 'Mobile Website'` |
| `leads_others` | Leads from other channels | `source = 4` |

**Caveats.** Channel is a `CASE` whose **`ELSE` is 'Mobile Website'** — so a lead with an unknown or
NULL source is counted as mobile web, not as "others". `source = 0` is Website in the enum `[NOTION]`
but has no branch of its own, so it also lands in Mobile Website. `[REG]` `[SQL]` Leads allow
`shifting_type IS NULL`; orders do not — a small, deliberate asymmetry. `[SQL]`

### 2.2 `orders` — 5 metrics · prototype_only
- **Counted on:** month of `o_created_ts` · **Nano:** EXCLUDED
- **Source:** `FACT_PNM_ORDERS` + `DIM_PNM_ORDERS` + `MART.PNM_CUSTOMERS` (+ opportunity tables for channel)
- **Population:** `user_flag ILIKE 'normal'`, `shifting_type = 'intra_city'`, `crn LIKE '%PNM%'`,
  `package_name NOT ILIKE 'Nano%'` (or NULL), deduped to one row per `order_id`

| Metric | Plain English | Formula |
|---|---|---|
| `orders_overall` | How many bookings | `COUNT(DISTINCT order_id)` |
| `orders_app` | Bookings whose lead came from the app | channel = App |
| `orders_desktop` | Bookings whose lead came from desktop web | channel = Desktop Website |
| `orders_mobile` | Bookings whose lead came from mobile web | channel = Mobile Website |
| `orders_others` | Bookings whose lead came from elsewhere | channel = Others |

**Caveats.** **All statuses count** — there is no cancelled filter, so `orders_overall` includes
orders later cancelled. `[REG]` `[LOG D5]` An order's channel is inherited from its originating lead
via `sr_id`; an order with no matching lead falls into the `ELSE` bucket and is counted as **Mobile
Website**. `[REG]` Dedup is per `order_id` (not per SR) using `ORDER BY opp_id DESC NULLS LAST`. `[SQL]`

### 2.3 `derived` — 7 metrics · prototype_only
- **Counted on:** calendar month; ratios of the same month's leads and orders
- Computed **in Python from raw counts**, never by averaging ratios. `[REG]` `[LOG D7]`

| Metric | Plain English | Formula |
|---|---|---|
| `conversion_overall` | % of leads that became bookings | `100 × orders_overall ÷ leads_overall` |
| `conversion_app` | Same, app only | `100 × orders_app ÷ leads_app` |
| `conversion_desktop` | Same, desktop web only | `100 × orders_desktop ÷ leads_desktop` |
| `conversion_mobile` | Same, mobile web only | `100 × orders_mobile ÷ leads_mobile` |
| `pct_orders_app` | Share of bookings from the app | `100 × orders_app ÷ orders_overall` |
| `pct_orders_website` | Share of bookings from either website | `100 × (orders_desktop + orders_mobile) ÷ orders_overall` |
| `pct_orders_others` | Share of bookings from other channels | `100 × orders_others ÷ orders_overall` |

**Caveats.** This is **period conversion, not cohort conversion**: orders created in month M ÷ leads
created in month M. A May lead that books in June counts in June's numerator and May's denominator.
`[REG]` `[IT1]` Carries the Nano asymmetry from §1. There is **no `conversion_others`** metric. `[REG]`

### 2.4 `tpo` — 13 metrics · prototype_only
"TPO" = **tickets per order** — support tickets divided by orders. A quality/pain measure: higher is worse.
- **Counted on:** month of **allocation completion** (`order_allocation_infos.completed_ts` + 330 min → IST)
- **Nano:** EXCLUDED · **Source:** `PROD_CURATED.PNM_APPLICATION.ORDERS` + `ORDER_ALLOCATION_INFOS`
  + `SHIFTING_REQUIREMENTS` + `PROD_CURATED.SFMS_PUBLIC.HS_TICKETS`
- **Denominator:** `COUNT(DISTINCT crn)` where the allocation is active (`is_active = true`) and completed

Every metric except `orders_base` is `ROUND(<a ticket count> / NULLIF(orders_base, 0), 4)`. The
formula column below gives the ticket count used as that numerator. `[SQL]`

| Metric | Plain English | Numerator (all counted as `COUNT(DISTINCT ticket_number)`) |
|---|---|---|
| `orders_base` | The denominator: orders whose allocation completed this month | `COUNT(DISTINCT crn)` — allocation active + completed in month |
| `tpo_overall` | Tickets per order, all sources | all non-detractor tickets |
| `tpo_vendor_raised` | Tickets per order raised by vendors | `raised_by ILIKE 'Vendor%'` |
| `tpo_pre_trip` | Tickets raised before the trip started, per order | status ∈ `open`, `supervisor_assigned`, `supervisor_accepted`, `vendor_accepted` |
| `tpo_pre_trip_customer` | …of those, the ones customers raised | the same, **and** `raised_by = 'Customer'` |
| `tpo_trip_shift` | Tickets raised during trip / shifting, per order | status ∈ `trip_started`, `shifting_started` |
| `tpo_trip_shift_customer` | …customer-raised subset | the same, **and** `raised_by = 'Customer'` |
| `tpo_pickup` | Tickets raised at the pickup-completed stage, per order | status = `pickup_completed` |
| `tpo_pickup_customer` | …customer-raised subset | the same, **and** `raised_by = 'Customer'` |
| `tpo_completed` | Tickets raised after the order completed, per order | status = `completed` |
| `tpo_completed_customer` | …customer-raised subset | the same, **and** `raised_by = 'Customer'` |
| `tpo_cancelled` | Tickets whose order was cancelled at the time the ticket was raised, per order | status = `cancelled` |
| `tpo_cancelled_customer` | …customer-raised subset | the same, **and** `raised_by = 'Customer'` |

"status" above means `order_status_when_ticket_created` — the order's state **at the moment the ticket
was raised**, not its state now.

Ticket stage comes from `order_status_when_ticket_created`: pre-trip = `open`,
`supervisor_assigned`, `supervisor_accepted`, `vendor_accepted`; trip/shift = `trip_started`,
`shifting_started`; then `pickup_completed`, `completed`, `cancelled`. `[SQL]`

**Caveats.** The month basis is unique to this section — **allocation completion, not booking or
completion**. Say so when quoting it. `[REG]` A ticket is only counted if it was raised in the *same*
IST month as the allocation completed; tickets from any other month are attributed to **no** month at
all. `[REG]` Detractor tickets are excluded everywhere (`raised_by != 'Detractor'`). `[SQL]`
Denominator counts distinct `crn`; numerators count distinct `ticket_number`. `[REG]`
`tpo_cancelled` counts tickets by the order's status *at ticket creation*, which is independent of the
order base (which has no status filter) — read it carefully. `[REG]`

### 2.5 `p80_durations` — 7 metrics · prototype_only
"p80" = the 80th percentile. **80% of moves were faster than this number; the slowest 20% were
slower.** It is not an average — it describes the bad tail, which is why ops uses it. Unit: **minutes**.
- **Counted on:** month of `SHIFTING_TS_IST` · **Nano:** EXCLUDED
- **Source:** `PROD_ELDORIA.MART.PNM_EXPERIENCE`
- **Population:** `ORDER_STATUS = 'completed'`, `SHIFTING_TYPE = 'intra_city'`, `PACKAGE_NAME NOT ILIKE 'Nano%'`

| Metric | Plain English | Measured between |
|---|---|---|
| `p80_trip_duration` | How long the move itself took | `SHIFTING_STARTED_TS_IST` → `ORDER_COMPLETED_TS_IST` |
| `p80_sup_assigned_to_trip_started` | Supervisor on board → crew sets off | `SUPERVISOR_ACCEPTED_TS_IST` → `TRIP_STARTED_TS_IST` |
| `p80_trip_started_to_shifting_started` | Travel to the customer | `TRIP_STARTED_TS_IST` → `SHIFTING_STARTED_TS_IST` |
| `p80_shifting_started_to_pickup_complete` | Loading | `SHIFTING_STARTED_TS_IST` → `PICKUP_COMPLETED_TS_IST` |
| `p80_pickup_complete_to_order_complete` | Transit + unloading | `PICKUP_COMPLETED_TS_IST` → `ORDER_COMPLETED_TS_IST` |
| `p80_vendor_accepted_to_sup_assigned` | Vendor accepts → supervisor on board | `VENDOR_OWNER_ACCEPTED_TS_IST` → `SUPERVISOR_ACCEPTED_TS_IST` |
| `p50_trip_duration` | The *typical* move duration (median) | `SHIFTING_STARTED_TS_IST` → `ORDER_COMPLETED_TS_IST` |

All are `ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', <start>, <end>)), 1)`;
`p50_trip_duration` uses `0.5`. `[SQL]`

**Not answerable in plain English — by design.** `p50_trip_duration` and
`p80_vendor_accepted_to_sup_assigned` are computed and reconciled but have **no natural-language
aliases**; they are reachable only via `ask.py --metric`. Asking for a median or a p50 is refused
outright. `[REG]` `[LOG D10]` **The owner has an open decision on whether to expose
`p80_vendor_accepted_to_sup_assigned`** — see §7-Q4.

**Caveats.** "Supervisor Assigned" reads `SUPERVISOR_ACCEPTED_TS_IST` (see §1). The
pickup→completion stage is labelled "… → Shifting Complete" in the MBR sheet but measures
pickup→**order** complete; there is no shifting-complete timestamp. `[REG]` `[AUTO]` An order missing
either endpoint drops out of *that stage only*, so **each stage's percentile can be over a different
set of orders**. `[REG]` `[IT1]` `p80_vendor_accepted_to_sup_assigned` runs ~2,500–2,800 minutes
(~2 days), far larger than every other stage — confirm the definition before quoting it. `[reference/README.md]`

**Validation.** Reconciled against `reference/p80_durations_baseline_2025-10_to_2026-05.csv` across
8 months: **bit-exact** for 2025-10/11/12; drift ≤0.84% on recent months (worst: `p80_trip_duration`
2026-05, baseline 597 vs live 602), well inside the ±2.5% rule. The drift is the mart backfilling
recent rows, not a logic error. `p50 ≤ p80_trip_duration` holds in all 8 months. `[RECON]` `[LOG V4]`

### 2.6 `order_edits` — 10 metrics · prototype_only
An "edit" is a change to a booking after it was made — the address, the item list, add-ons, or the
time slot. High support-edit rates mean customers could not self-serve.
- **Counted on:** month of `ORDER_CREATED_TS_IST` · **Nano:** EXCLUDED
- **Source:** `PROD_ELDORIA.MART.PNM_EXPERIENCE`
- **Population:** `ORDER_STATUS = 'completed'`, `SHIFTING_TYPE = 'intra_city'`, `PACKAGE_NAME NOT ILIKE 'Nano%'`

| Metric | Plain English | Formula (÷ `total_orders` unless noted) |
|---|---|---|
| `pct_orders_edited` | % of bookings changed at least once | `IS_MODIFICATION_DONE = 'Yes'` orders |
| `no_of_successful_edits` | Total number of edits (a count, not a %) | `SUM(NO_OF_SUCCESSFUL_EDITS)` |
| `pct_support_edited_orders` | % where support had to make the change | `HAS_SUPPORT_EDIT = 1` orders |
| `location_adoption_pct` | % where an address was changed | `HAS_LOCATION_EDIT = 1` orders |
| `pct_orders_location_modified` | **Identical value** to the row above | same expression |
| `items_adoption_pct` | % where the item list was changed | `HAS_ITEMS_EDIT = 1` orders |
| `addons_adoption_pct` | % where add-ons were changed | `HAS_ADDONS_EDIT = 1` orders |
| `slot_adoption_pct` | % where the time slot was changed | `HAS_SLOT_EDIT = 1` orders |
| `edits_per_order` | Average edits per booking | `no_of_successful_edits ÷ total_orders` |
| `pct_edits_after_shifting_started` | % of **edits** made after the move began | `÷ no_of_successful_edits` ⚠ |

**Caveats.** `location_adoption_pct` and `pct_orders_location_modified` are **the same number under
two names** — duplicated from the MBR automation on purpose. If both are asked for, say they are
identical. `[REG]` `[AUTO]` `pct_edits_after_shifting_started` is the only metric that divides by the
edit count rather than the order count, so it **can exceed 100%**. `[REG]` **No denominator is
published** — unlike TPO's `orders_base`, these percentages come with no visible sample size, by
owner decision. `[REG]` `[IT3]` `IS_MODIFICATION_DONE` is compared to the **string `'Yes'`**; the
`HAS_*_EDIT` flags to the **number `1`** — both confirmed live `[LIVE]`.

**Validation.** Byte-identical mirror of the automation's `EDIT_ADOPTION_QUERY`. 2026-05 live:
`pct_orders_edited` 61.09, `no_of_successful_edits` 153,726, `location_adoption_pct` 15.85 (= its
duplicate), `edits_per_order` 3.53, `pct_edits_after_shifting_started` 36.61, over `total_orders`
43,529. Stable across Mar/Apr/May. `[RECON]`

### 2.7 `ota` — BLOCKED, 0 queryable metrics
On-time arrival. **Cannot be answered.** The original query referenced six columns
(`scheduled_pickup_ts`, `vendor_arrived_ts`, and four coordinates) that exist in no table. `[REG]` `[LEDGER]`

There is now a **candidate** source: `PNM_EXPERIENCE.OTA_FLAG` and `OTA_BREACH_TAT_MINUTES` both
exist `[LIVE]`. Nobody has defined OTA against them, and the definition itself is disputed (§7-Q3).
Until the owner rules, OTA questions get the §7 answer, not a number. `[LOG]`

### 2.8 Metrics that exist in the MBR automation but NOT in this catalog
The automation `[AUTO]` runs 14 sections. Only 6 are in the catalog above. Also present there —
and **not answerable by the Gem** — are: fare/coupon/surge (incl. AOV), vendor earnings percentiles,
allocation quality (allocation %, deallocation %, completion %, allocation TAT p80, CAC/PAC/PoAC),
wallet withdrawals/recharges, vendor TPO top-5 issues, add-on adoption, completion score, weekend
contribution, Get-a-Call CTR, and CAC-post-trip-started. If asked for any of these, treat them as
not in knowledge (§6) — several have dashboards in §4.

---

## §3 · Schema guide — live INFORMATION_SCHEMA mapping

All column names and types below are from Snowflake `INFORMATION_SCHEMA.COLUMNS`, read **2026-07-29**
`[LIVE]`. Types are abbreviated: `TS_NTZ` = `TIMESTAMP_NTZ`, `NUM` = `NUMBER`, `TEXT` = `VARCHAR`.

**Where things live** `[NOTION]`: `prod_eldoria.raw.*` → `prod_eldoria.core.*` → `prod_eldoria.mart.*`.
Governed dbt models are in `CORE` and `MART`; `PROD_CURATED.*` is closer to raw application data.

### 3.1 The common tables

| Table | Grain (1 row =) | Live cols | Used by |
|---|---|---|---|
| `PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY` | 1 lead | 12 | leads, orders, derived |
| `PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY` | 1 lead | 23 | leads, orders, derived |
| `PROD_ELDORIA.CORE.FACT_PNM_ORDERS` | 1 order | 32 | orders, derived |
| `PROD_ELDORIA.CORE.DIM_PNM_ORDERS` | 1 order | 35 | orders, derived |
| `PROD_ELDORIA.CORE.DIM_GEO_REGIONS` | 1 city/geo region | 23 | city lookup; card #47576 |
| `PROD_ELDORIA.MART.PNM_CUSTOMERS` | 1 customer_mobile | 35 | orders (inner join gate) |
| `PROD_ELDORIA.MART.PNM_EXPERIENCE` | 1 order | **71** | p80_durations, order_edits |
| `PROD_ELDORIA.MART.PNM_SUPPORT` | 1 order | 36 | not used by the catalog |
| `PROD_ELDORIA.MART.PNM_ALLOCATION` | 1 order | 34 | not used by the catalog `[SLACK]` |
| `PROD_ELDORIA.MART.PNM_FARE_MOVEMENT` | 1 order | 31 | not used by the catalog `[SLACK]` |
| `PROD_CURATED.PNM_APPLICATION.ORDERS` | 1 order | **17** | tpo |
| `PROD_CURATED.PNM_APPLICATION.ORDER_ALLOCATION_INFOS` | 1 allocation attempt | 23 | tpo |
| `PROD_CURATED.PNM_APPLICATION.SHIFTING_REQUIREMENTS` | 1 SR | 19 | tpo |
| `PROD_CURATED.SFMS_PUBLIC.HS_TICKETS` | 1 ticket | 56 | tpo |

### 3.2 Join-key correlation — which tables share which key

| Key | Tables carrying it `[LIVE]` |
|---|---|
| `ORDER_ID` | `FACT_PNM_ORDERS`, `DIM_PNM_ORDERS`, `PNM_EXPERIENCE`, `PNM_SUPPORT`, `PNM_ALLOCATION`, `PNM_FARE_MOVEMENT`, `ORDER_ALLOCATION_INFOS` |
| `SR_ID` | `FACT_PNM_OPPORTUNITY`, `FACT_PNM_ORDERS`, `DIM_PNM_ORDERS`, `PNM_SUPPORT`, `PNM_ALLOCATION`, `PNM_FARE_MOVEMENT`, `ORDERS.SR_ID` |
| `OPP_ID` | `FACT_PNM_OPPORTUNITY`, `DIM_PNM_OPPORTUNITY` |
| `CRN` | `FACT_PNM_ORDERS`, `PNM_SUPPORT`, `PNM_ALLOCATION`, `ORDERS`, `HS_TICKETS` |
| `CUSTOMER_MOBILE` | `FACT_PNM_OPPORTUNITY`, `FACT_PNM_ORDERS`, `PNM_CUSTOMERS`, `PNM_SUPPORT` |
| `VENDOR_ID` | `FACT_PNM_ORDERS`, `PNM_EXPERIENCE`, `PNM_SUPPORT`, `PNM_FARE_MOVEMENT`, `ORDER_ALLOCATION_INFOS` |
| `PICKUP_GEO_REGION_ID` | `DIM_PNM_OPPORTUNITY`, `DIM_PNM_ORDERS`, `PNM_EXPERIENCE`, `PNM_SUPPORT`, `PNM_ALLOCATION`, `PNM_FARE_MOVEMENT` → `DIM_GEO_REGIONS.GEO_REGION_ID` |

**The joins actually used** `[NOTION]` `[SQL]`:
```
FACT_PNM_OPPORTUNITY.OPP_ID   = DIM_PNM_OPPORTUNITY.OPP_ID
FACT_PNM_OPPORTUNITY.SR_ID    = FACT_PNM_ORDERS.SR_ID          -- lead → order
FACT_PNM_ORDERS.ORDER_ID      = DIM_PNM_ORDERS.ORDER_ID
FACT_PNM_ORDERS.ORDER_ID      = PNM_EXPERIENCE.ORDER_ID
FACT_PNM_ORDERS.CUSTOMER_MOBILE = PNM_CUSTOMERS.CUSTOMER_MOBILE  -- INNER JOIN, acts as a filter
PNM_APPLICATION.ORDERS.ID     = ORDER_ALLOCATION_INFOS.ORDER_ID  -- note: ORDERS.ID, not ORDER_ID
PNM_APPLICATION.ORDERS.SR_ID  = SHIFTING_REQUIREMENTS.ID
HS_TICKETS.CRN                = ORDERS.CRN                       -- tickets have NO order_id
SHIFTING_REQUIREMENTS.GEO_REGION_ID = DIM_GEO_REGIONS.GEO_REGION_ID
```

> ⚠ `HS_TICKETS` has **no `ORDER_ID`** column `[LIVE]`. Tickets join to orders on `CRN` (or
> `HS_ORDER_ID`). An early version of the TPO query assumed `order_id` and could never have run. `[LEDGER]` `[LOG]`

> ⚠ `PROD_CURATED.PNM_APPLICATION.ORDERS` holds only `ID, CRN, SR_ID, SOURCE, CREATED_AT,
> UPDATED_AT, STATUS (TEXT), SERVICE_TYPE, MOBILE` + ETL/Kafka columns `[LIVE]`. It has **no
> `ORDER_ID`, no lifecycle timestamps, and its `STATUS` is text, not a number.** The lifecycle
> columns are *assembled* in `CORE.FACT_PNM_ORDERS`. This is why the whole pipeline was re-pointed to
> PROD_ELDORIA. `[LOG D3]`

### 3.3 Column reference for the tables the catalog reads

**`FACT_PNM_OPPORTUNITY`** (12) `[LIVE]` — `SR_ID` NUM · `OPP_ID` NUM · `CUSTOMER_MOBILE` TEXT ·
`OPP_LATEST_SCORE` NUM · `HASH_SCORE` NUM · `OPP_CREATED_TS` TS_NTZ · `OPP_CREATED_DATE` DATE ·
`OPP_UPDATED_TS` TS_NTZ · `OPP_SHIFTING_TS` TS_NTZ · `OPP_SHIFTING_DATE` DATE · `FOLLOW_UP_TS` TS_NTZ ·
`OPP_UUID` TEXT. All timestamps are already IST. `[NOTION]`

**`DIM_PNM_OPPORTUNITY`** (23) `[LIVE]` — `OPP_ID` NUM · `CUSTOMER_NAME` TEXT · `OPP_CREATED_TS` /
`OPP_UPDATED_TS` TS_NTZ · **`SOURCE` NUM** · `STATUS` NUM · `PICKUP_LOCATION` / `DROP_LOCATION`
GEOGRAPHY · `PICKUP_ADDRESS` / `DROP_ADDRESS` TEXT · `PICKUP_GEO_REGION_ID` / `DROP_GEO_REGION_ID`
NUM · `PICKUP_CITY_NAME` / `DROP_CITY_NAME` TEXT · **`SOURCE_DETAILS` TEXT** · `PLATFORM` TEXT ·
`SHIFTING_TYPE` TEXT · `EMAIL` TEXT · `ITEMS_VOLUME_CFT` NUM · `PACKAGE_NAME` TEXT ·
`SYSTEM_DISPOSITION` TEXT · **`USER_FLAG` TEXT** · `REFERRAL_CODE` TEXT.

**`FACT_PNM_ORDERS`** (32) `[LIVE]` — `SR_ID` · `ORDER_ID` · `CUSTOMER_MOBILE` · `CRN` ·
`O_CREATED_TS` TS_NTZ · `O_CREATED_DATE` DATE · `SHIFTING_TS` · `O_COMPLETED_TS` · `O_CANCELLED_TS` ·
`O_UPDATED_TS` · `SUPERVISOR_ACCEPTED_OLC_TS` · `TRIP_STARTED_OLC_TS` · `SHIFTING_STARTED_OLC_TS` ·
`PICKUP_COMPLETED_OLC_TS` · `ORDER_COMPLETED_OLC_TS` · `PACKAGE_ID` · `FINAL_FARE` ·
`SURGE_CAMPAIGN_ID` · pickup/drop lat-long · `TRIP_DISTANCE` · `DISTANCE_METERS` · `VENDOR_ID` ·
`VENDOR_OWNER_ID` · `VENDOR_OWNER_ACCEPTED_TS` · `SUPERVISOR_ID` · `SUPERVISOR_ASSIGNED_TS` ·
`SUPERVISOR_ACCEPTED_TS` · `SUPERVISOR_MOBILE` · `_ETL_INSERT_DATE_TS`.
**No `USER_FLAG`, `SHIFTING_TYPE`, `PACKAGE_NAME` or `ORDER_STATUS`** — that is why every order query
joins `DIM_PNM_ORDERS`. **No `STATUS` column at all.**

**`DIM_PNM_ORDERS`** (35) `[LIVE]` — `SR_ID` · `ORDER_ID` · `ORDER_CREATED_TS` · `O_UPDATED_TS` ·
`SERVICE_TYPE` · **`ORDER_STATUS` TEXT** · `SOURCE` NUM · **`SHIFTING_TYPE` TEXT** ·
**`PACKAGE_NAME` TEXT** · `CUSTOMER_NAME` · `PICKUP_GEO_REGION_ID` · `PICKUP_CITY_NAME` ·
`PICKUP_FLOOR` · pickup waypoints 1–2 · `PICKUP_LIFT_STATUS` · `DROP_GEO_REGION_ID` ·
`DROP_CITY_NAME` · `DROP_FLOOR` · drop waypoints 1–2 · `ADDITIONAL_COMMENTS` · `ITEMS_LIST` ·
`ITEMS_VOLUME_CFT` · `ADD_ON_SERVICES_LIST` · `CANCELLED_BY` · `CANCELLATION_REASON` ·
`DISCOUNT_COUPON` · `FARE_VERSION_ID` · `SURGE_MULTIPLIER` · `WAYPOINT_CHARGE` ·
`VENDOR_LEGAL_NAME` · `VENDOR_TRADE_NAME` · `VENDOR_BUCKET_TYPE` · **`USER_FLAG` TEXT**.

**`PNM_EXPERIENCE`** (71) `[LIVE]` — the table both p80 and order_edits read. Keys/dims: `ORDER_ID` ·
`VENDOR_ID` · `SUPERVISOR_ID` · `PICKUP_CITY_NAME` / `DROP_CITY_NAME` · pickup/drop
`GEO_REGION_ID`, `ZONE_ID`, `ZONE_NAME` · `ORDER_STATUS` · `ITEMS_LIST` · `PACKAGE_NAME` · `ADD_ONS` ·
`SHIFTING_TYPE` · `SAME_DAY_OR_SCHEDULED` · `PEAK_OR_NON_PEAK_DAYS` · `SHIFTING_DAY_TYPE` ·
`VENDOR_BUCKET_TYPE`.
Timestamps (all TS_NTZ, all IST): `ORDER_CREATED_TS_IST` · `ORDER_UPDATED_TS_IST` ·
**`SHIFTING_TS_IST`** · `VENDOR_OWNER_ACCEPTED_TS_IST` · `SUPERVISOR_ASSIGNED_TS_IST` ·
`SUPERVISOR_ACCEPTED_TS_IST` · `TRIP_STARTED_TS_IST` · `SHIFTING_STARTED_TS_IST` ·
`PICKUP_COMPLETED_TS_IST` · `ORDER_COMPLETED_TS_IST` · `ORDER_CANCELLED_TS_IST`.
Edit flags: **`IS_MODIFICATION_DONE` TEXT** · `NO_OF_SUCCESSFUL_EDITS` NUM · `HAS_SUPPORT_EDIT` NUM ·
`HAS_LOCATION_EDIT` NUM · `HAS_ITEMS_EDIT` NUM · `HAS_ADDONS_EDIT` NUM · `HAS_SLOT_EDIT` NUM ·
`EDITS_AFTER_SHIFTING` NUM.
Experience: **`OTA_FLAG` TEXT** · `OTA_BREACH_TAT_MINUTES` NUM · `CLASSIFICATION` TEXT ·
`ON_TIME_DELIVERY_FLAG` TEXT · `FIRST_CONTACT_RESOLUTION_FLAG` TEXT ·
`ESCALATED_TO_CITY_TEAM_FLAG` TEXT · `DEALLOCATION_STATUS` BOOL · `AVG_RESOLUTION_TAT` NUM ·
`ISSUE_SUBISSUE_DICTIONARY` TEXT.
Tickets: `TOTAL_TICKETS` · `CUSTOMER_TICKETS` · `VENDOR_SUPERVISOR_TICKETS` · `VENDOR_OWNER_TICKETS` ·
`PORTER_SUPPORT_TICKETS` · `DETRACTOR_TICKETS` · `SPRINKLR_TICKETS` · `FCR_TICKETS` ·
`SPRINKLR_SESSION_COUNT`.
Money/size: `FINAL_FARE` · `TOTAL_ORDER_FARE` · `SURGE_MULTIPLIER` · `DISCOUNT_COUPON` ·
`DISCOUNT_AMOUNT` · `INITIAL_CFT` · `FINAL_CFT` · `PICKUP_FLOOR` · `DROP_FLOOR` ·
`PICKUP_LIFT_STATUS` · `DRY_RUN_DISTANCE_KMS` · `PICKUP_KM_DEVIATION` · `DROP_KM_DEVIATION` ·
`IMAGE_COUNT`.
> ⚠ **This mart is flagged "still under active construction"** and its schema has grown mid-project
> more than once. All 20 columns the catalog needs were re-verified present on 2026-07-29 `[LIVE]`,
> but re-verify before trusting a run. **It carries no `USER_FLAG` and no `IS_TEST_USER`** — see §6.
> `[REG]` `[IT3]` `[AUTO]`

**`PNM_APPLICATION.ORDER_ALLOCATION_INFOS`** (23) `[LIVE]` — `ID` · `ORDER_ID` · `ALLOCATION_STATUS` ·
`SHIFTING_TS` · `VENDOR_ID` · `VENDOR_OWNER_ID` · `VENDOR_OWNER_ACCEPTED_TS` · `SUPERVISOR_ID` ·
`SUPERVISOR_NAME` · `SUPERVISOR_ASSIGNED_TS` · `SUPERVISOR_ACCEPTED_TS` · **`COMPLETED_TS`** ·
`CREATED_AT` · `UPDATED_AT` · **`IS_ACTIVE` BOOL** · `CANCELLED_TS` · `VENDOR_BUCKET_TYPE` + ETL/Kafka.

**`PNM_APPLICATION.SHIFTING_REQUIREMENTS`** (19) `[LIVE]` — `ID` · `EXTERNAL_ID` ·
**`GEO_REGION_ID`** · `HOUSE_TYPE_ID` · `SHIFTING_TS` · `CREATED_AT` · `UPDATED_AT` · `SOURCE` TEXT ·
`ITEMS_VOLUME_CFT` · **`SHIFTING_TYPE`** · `DROP_GEO_REGION_ID` · `PACKAGE_ID` · **`PACKAGE_NAME`** + ETL/Kafka.

**`SFMS_PUBLIC.HS_TICKETS`** (56) `[LIVE]` — the ones that matter: **`TICKET_NUMBER`** · `CRN` ·
`HS_ORDER_ID` · `HS_ORDER_NUMBER` · **`RAISED_BY`** · **`ORDER_STATUS_WHEN_TICKET_CREATED`** ·
`ORDER_STATUS` · `ORDER_STAGE` · **`HS_PACKAGE`** · **`SHIFTING_TYPE`** · `SERVICE_TYPE` ·
`GEO_REGION` TEXT · `ISSUE` · `SUB_ISSUE` · `ISSUE_DESCRIPTION` · `STATUS` · `DISPOSITION` ·
`ORIGIN` · `FCR` BOOL · `IS_CLOSED` BOOL · `ESCALATION_COUNT` · `ESCALATED_TO_CITY_AT` ·
`COMPLETION_TAT` · `CREATED_AT` · `CLOSED_AT` · `SHIFTING_TIME_SLOT`.

**`DIM_GEO_REGIONS`** (23) `[LIVE]` — `GEO_REGION_ID` · **`CITY_NAME`** · **`ZONE`** · **`TIER`** ·
`STATUS` NUM · `OFFICE_ADDRESS` · `CITY_SUPPLY_EMAIL` · `GSTIN` · `STATE_ID` · `STD_CODE` ·
`TIMEZONE` · office hours · vicinity/threshold settings · `IS_OUTSTATION_ENABLED` ·
`IS_HOUSE_SHIFTING_ENABLED` · `CREATED_AT` · `UPDATED_AT`. **This is the city lookup table.**

### 3.4 Two marts the Notion guide does not list
Announced in `#pnm-analytics` by Rashmi Dutta on **2026-07-14**, both "refreshed every morning"
`[SLACK]`, both confirmed live `[LIVE]`. The MBR automation already reads them `[AUTO]`; the Gem's
catalog does not.

- **`PROD_ELDORIA.MART.PNM_ALLOCATION`** (34 cols) — the allocation journey. `ALLOCATION_CHANNEL`
  (Engine / Open Pool), `ALLOCATION_TAT_MINUTES`, `IS_ALLOCATED`, `NO_VENDOR_BEFORE_SLOT`,
  `DEALLOCATION_COUNT`, `IS_DEALLOCATED_POST_ACCEPT`, `IS_SUPERVISOR_CHANGED`,
  `IS_SUPERVISOR_CHANGED_POST_TRIP`, `DRY_RUN_DISTANCE_KMS`, `PICKUP_KM_DEVIATION`,
  `DROP_KM_DEVIATION`, `LAST_RESCHEDULED_SHIFT_TS`, `ORDER_BUCKET` (SPOT/SCHEDULED), `ORDER_TYPE`
  (Normal/Outstation), `CANCELLATION_TYPE` (CAC/PAC/PoAC), plus **`IS_NANO_ORDER`** and
  **`IS_TEST_USER`**.
- **`PROD_ELDORIA.MART.PNM_FARE_MOVEMENT`** (31 cols) — how a fare moves across the lifecycle.
  `BOOKING_FINAL_FARE`, `PRE_START_FINAL_FARE`, `POST_START_FINAL_FARE`, `FARE_DELTA`,
  `IS_EDITED_POST_START`, `BOOKING_SURGE_MULTIPLIER`, `TOTAL_ORDER_FARE`, `VENDOR_ORDER_FARE`,
  `SERVICE_TYPE_BUCKET`, `ORDER_CREATED_DATE/WEEK/MONTH`, plus `IS_NANO_ORDER` and `IS_TEST_USER`.

### 3.5 Mandatory filters

**Applied by the catalog's SQL — never remove these:** `[SQL]`

| Filter | Where it applies | Why |
|---|---|---|
| `shifting_type = 'intra_city'` | every section (leads also allow NULL) | catalog is intra-city only |
| `user_flag ILIKE 'normal'` | leads, orders (on the **dims**) | excludes non-normal/experiment users |
| `crn LIKE '%PNM%'` | orders, tpo | restricts to PnM business |
| `package_name NOT ILIKE 'Nano%'` | orders, p80, order_edits | Nano is LA's, not PnM's |
| `package_name NOT ILIKE '%Nano%'` | tpo (contains, not prefix) | faithful to the TPO query as validated |
| `ORDER_STATUS = 'completed'` | p80_durations, order_edits | completed moves only |
| `is_active = true` | tpo (on `ORDER_ALLOCATION_INFOS`) | the live allocation only |
| `raised_by != 'Detractor'` | tpo tickets | detractor tickets excluded everywhere |

> ⚠ **Test orders are largely NOT excluded.** `IS_TEST_USER` exists only on `PNM_ALLOCATION` and
> `PNM_FARE_MOVEMENT` `[LIVE]` — neither of which the catalog reads. leads/orders rely on
> `user_flag ILIKE 'normal'` as their only user gate; **p80_durations and order_edits have no user or
> test filter at all**, because `PNM_EXPERIENCE` carries neither column. Do not claim the catalog
> excludes test orders. `[LIVE]` `[SQL]`

The nano filter form differs by section on purpose (prefix for leads/orders/p80/edits, contains for
tpo). This is faithful to two separately validated queries and is **not** to be unified. `[LOG §3]`

### 3.6 Enum values (values these columns actually take) `[NOTION]`

- **`ORDER_STATUS`** (`DIM_PNM_ORDERS`, `PNM_EXPERIENCE`): `open`, `vendor_accepted`,
  `supervisor_assigned`, `supervisor_accepted`, `trip_started`, `shifting_started`,
  `pickup_completed`, `completed`, `cancelled` — **lowercase**.
- **`SHIFTING_TYPE`**: `intra_city`, `inter_city`, `vehicle_shifting` (+ `labour` on the
  opportunity dim).
- **`PACKAGE_NAME`**: `1 RK`, `1 RK/Studio`, `1/2/3/4/5 BHK Small|Medium|Big`, `Micro Shifting`,
  `Nano Shifting`, `Nano Shifting Medium`, `Nano Shifting Large`, `vehicle_shifting_default`.
- **Opportunity `SOURCE`** (NUM): `0` Website · `1` App · `2` App Home · `3` App Promo · `4` Generic.
- **Opportunity `STATUS`** (NUM): `0` Open · `1` Prospect · `2` Quoted · `3` Closed · `4` Converted.
- **`SOURCE_DETAILS`**: free text, e.g. `Desktop Website`, `Mobile Website`, `Inbound Call`.
- **`CANCELLED_BY`**: `Customer`, `Vendor Owner`, `Vendor-Supervisor`, `Porter Support`,
  `Backend Team`, `Detractor`, `system-automation`.
- **`VENDOR_BUCKET_TYPE`**: `New`, `Bronze`, `Silver`, `Gold`, `GoldPlus`.
- **`CLASSIFICATION`** (NPS): `Promoter`, `Neutral`, `Detractor`.
- **`SERVICE_TYPE`**: `Default`, `Default_Short`, `Lite`, `Standard`, `Premium`, `FourWheeler`,
  `PTL`, `FTL`.
- **`RAISED_BY`** (`HS_TICKETS`): `Customer`, `Vendor-Owner`, `Vendor-Supervisor`, `Porter Support`,
  `Detractor`, `Chat`. `[LEDGER]`
- **`SHIFTING_SLOT`**: `Morning`, `Afternoon`, `Evening`.
- **`ON_TIME_DELIVERY_FLAG`** (inter-city only): `On_Time`, `Delay_1_Day`, `Delay_2_Days`,
  `Delay_3_Plus_Days`.
- **`PEAK_OR_NON_PEAK_DAYS`**: `Peak Days`, `Non Peak Days`.
- **`SAME_DAY_OR_SCHEDULED`**: `Same Day`, `Scheduled`.

### 3.7 What the less obvious columns mean `[NOTION]` unless marked

Names in §3.3 that are not self-explanatory:

| Column | Meaning |
|---|---|
| `CRN` | Customer reference number on the order. PnM orders match `'%PNM%'` — this is how PnM work is identified in shared tables |
| `SR_ID` | Shifting-requirement id — the thread linking a lead to its order |
| `OPP_ID` | Opportunity (lead) id |
| `USER_FLAG` | User classification used for experiments/segmentation; normal traffic is `normal` |
| `SYSTEM_DISPOSITION` | System-assigned lead outcome, e.g. `Not Interested`, `RNR` (ring-no-response), `Quotation Shared` |
| `OPP_LATEST_SCORE` | Latest lead-quality score on the opportunity |
| `VENDOR_BUCKET_TYPE` | Vendor performance tier: New / Bronze / Silver / Gold / GoldPlus |
| `DEALLOCATION_STATUS` | Whether the vendor assignment changed during the order's life |
| `DRY_RUN_DISTANCE_KMS` | Distance the vendor travelled before pickup |
| `PICKUP_KM_DEVIATION` / `DROP_KM_DEVIATION` | How far actual pickup/drop was from the booked location |
| `INITIAL_CFT` / `FINAL_CFT` | Item volume in cubic feet at booking vs after modifications |
| `OTA_FLAG` | Whether the vendor arrived inside the SLA window (definition disputed — §7-Q3) |
| `OTA_BREACH_TAT_MINUTES` | Minutes beyond the allowed SLA window |
| `CLASSIFICATION` | NPS bucket for the order: Promoter / Neutral / Detractor |
| `ON_TIME_DELIVERY_FLAG` | Inter-city delivery performance bucket (not meaningful for intra-city) |
| `AVG_RESOLUTION_TAT` | Average time to resolve the order's support tickets |
| `FIRST_CONTACT_RESOLUTION_FLAG` | Issue resolved in the first interaction |
| `ESCALATED_TO_CITY_TEAM_FLAG` | Ticket was escalated to the city operations team |
| `ISSUE_SUBISSUE_DICTIONARY` | Map of issues and sub-issues raised on the order |
| `SPRINKLR_TICKETS` / `SPRINKLR_SESSION_COUNT` | Tickets and chat sessions from the Sprinklr chat platform |
| `PEAK_OR_NON_PEAK_DAYS` | Whether the date falls in a peak demand window (weekends, month ends, month starts) |
| `SAME_DAY_OR_SCHEDULED` | Booked for the same day, or scheduled ahead |
| `PORTER_LTO` / `COMPLETED_PORTER_LTO` | Customer's lifetime orders across all Porter services |
| `ACQUIRED_BY` | Which Porter service first acquired this customer |
| `ORDER_STATUS_WHEN_TICKET_CREATED` | The order's stage at the moment the ticket was raised — drives every TPO stage split |
| `HS_PACKAGE` | The package recorded on the support ticket (used for the TPO Nano filter) |
| `COMPLETION_TAT` | Time taken to close the ticket |
| `ORDER_BUCKET` | `SPOT` (immediate) vs `SCHEDULED` `[SLACK]` |
| `ALLOCATION_TAT_MINUTES` | Minutes taken to allocate a vendor `[SLACK]` |
| `CANCELLATION_TYPE` | `CAC` / `PAC` / `PoAC` — cancellation stage classes `[SLACK]` |
| `IS_TEST_USER` / `IS_NANO_ORDER` | Test-traffic and Nano flags — **only on `PNM_ALLOCATION` / `PNM_FARE_MOVEMENT`** `[LIVE]` |
| `FARE_DELTA` | Change in fare between booking and execution `[SLACK]` |

**Columns present live but documented nowhere** `[LIVE]` — meaning unverified, do not interpret:
`SHIFTING_DAY_TYPE`, `IMAGE_COUNT`, `FCR_TICKETS` (probably first-contact-resolution tickets, but
unconfirmed), `HASH_SCORE`. Treat these as not-in-knowledge (§6) until analytics documents them.

### 3.8 Business glossary `[NOTION]`
**Conversion** orders ÷ opportunities · **Net conversion** non-cancelled orders ÷ opportunities ·
**TPO** total tickets ÷ total orders · **ATS / AOV** revenue ÷ orders · **ARPL** revenue ÷
opportunity · **Cancellation** cancelled ÷ orders · **NPS** net promoter score (~30% response rate) ·
**OTA** on-time arrival · **OTD / ETD** on-time / estimated delivery, inter-city only ·
**TOTF** top of the funnel · **Price shock** an unexpected fare jump.

---

## §4 · Dashboard registry

All URLs, filters and card counts resolved from Metabase + Data Catalog metadata on **2026-07-29**
`[MB]`, except where marked `[SLACK]`. Base URL: `https://metabase.prod-internal.porter.in`.
**No dashboard URL appears in any project file** — these were resolved from the live tools.

### 4.1 PnM — Business Health Dashboard ★ start here for business questions
- **URL:** https://metabase.prod-internal.porter.in/dashboard/4076
- 125 cards · 3,988 views · collection `Packers & Movers / Eldoria / Business Health Dashboard - PnM`
- **Answers:** leads and conversion by source, booked/completed orders, city splits, cancellation,
  revenue and gross, package and add-on mix, discounts, surge, NPS/detractor, call-centre
  connect rates.

Notable cards inside it `[MB]`:

| Card | ID / URL | Answers |
|---|---|---|
| `[DBT] Conversion %` | [30311](https://metabase.prod-internal.porter.in/question/30311) | lead → order conversion (see 4.2) |
| `[DBT] OverView` | [30343](https://metabase.prod-internal.porter.in/question/30343) | headline summary |
| `[DBT] Source wise Lead creation to conversion %` | [30567](https://metabase.prod-internal.porter.in/question/30567) | conversion split by lead source |
| `[DBT] PNM :: Booked Order City Split` | [30433](https://metabase.prod-internal.porter.in/question/30433) | bookings **by city** |
| `[DBT] PNM :: Completed Order City Split` | [41256](https://metabase.prod-internal.porter.in/question/41256) | completed orders **by city** |
| `[DBT] PNM :: Shifting City Split` | [30571](https://metabase.prod-internal.porter.in/question/30571) | moves **by city** |
| `[DBT] PNM :: Cancellation% Shifting City Split` | [36642](https://metabase.prod-internal.porter.in/question/36642) | cancellation % **by city** |
| `[DBT] Response rate, NPS and Detractor%` | [37431](https://metabase.prod-internal.porter.in/question/37431) | NPS + detractor % |
| `[DBT] Shifting Types` | [30395](https://metabase.prod-internal.porter.in/question/30395) | intra vs inter split |
| `[DBT] Service Add-on (%)` | [30484](https://metabase.prod-internal.porter.in/question/30484) | add-on adoption |
| `[DBT] Package Add-on (%)` | [30510](https://metabase.prod-internal.porter.in/question/30510) | add-ons by package |
| `[DBT] Surge Check` | [30344](https://metabase.prod-internal.porter.in/question/30344) | surge incidence |
| `[DBT] Revenue Growth - Completed Orders` | [30337](https://metabase.prod-internal.porter.in/question/30337) | revenue growth |
| `[DBT] PnM :: Monthly Gross` | [35267](https://metabase.prod-internal.porter.in/question/35267) | monthly gross |
| `[DBT] PNM:: Discount Code Usages` | [30582](https://metabase.prod-internal.porter.in/question/30582) | coupon usage |
| `[DBT] PNM :: Connected %` | [30554](https://metabase.prod-internal.porter.in/question/30554) | call connect rate |
| `[DBT] PNM :: Call Disposition Split` | [30556](https://metabase.prod-internal.porter.in/question/30556) | call outcomes |
| `[DBT] Orders View(SCF+LMS)` | [30304](https://metabase.prod-internal.porter.in/question/30304) | orders by booking system |
| `[DBT] PNM :: Orders Shifting Date Wise` | [30570](https://metabase.prod-internal.porter.in/question/30570) | orders by shifting date |

> ⚠ **Many of these cards have a "- including nano" twin** created 2026-03-30/31 (e.g.
> `[DBT] Conversion %` vs `[DBT] Sigma Conversions - including nano`). **The default card EXCLUDES
> Nano.** Opening the wrong twin silently changes the population. `[MB]`

> ⚠ **The "City Split" cards have NO city filter — they emit one column per city.** Verified on
> `[DBT] PNM :: Booked Order City Split` (#30433), whose 7 filters are Granularity, Start Date,
> End Date, Tier Filter, Is Peak, User Type, Shifting Type — no City Name. It returns a
> `SUM(CASE WHEN pickup_geo_region_id = N)` column per city, so you **read** the city off the result
> rather than filtering to it. The other city-split cards (#41256, #30571, #36642) appear to follow
> the same pattern — confirm on the card before promising a city filter. Card **#30311** is different:
> it does have a real `City Name` picker (§4.2). `[MB]`

### 4.2 Card #30311 — `[DBT] Conversion %`
- **URL:** https://metabase.prod-internal.porter.in/question/30311 · database **108** · 6,496 views
- **Answers:** `OpportunityCount`, `OrderCount`, `ConversionPercentage` per period.
- **Filters (9):** `Granularity` · `Start Date` · `End Date` · `City Name` (list of 14: Bangalore,
  Chennai, Coimbatore, **Delhi NCR**, Hyderabad, Indore, Jaipur, Kolkata, Lucknow, Mumbai, Nagpur,
  Pune, Surat, **Ahemdabad**) · `Drop City Name` · `Shifting Type` (`intra_city` / `inter_city`) ·
  `Tier Filter` (TIER1 / TIER2) · `Is Peak` · `User Type`.
- ⚠ **It does not match the catalog's conversion.** It excludes Nano from **both** leads and orders,
  and uses `service_type IN ('Default','Default_Short')` for its intra-city split. The catalog keeps
  Nano in leads. Its conversion will read **higher** than `conversion_overall`. Reconcile the catalog
  against the MBR note / Notion Demand DB, **not** this card. `[LOG D4/D6]` `[LEDGER]` `[MB]`

### 4.3 PNM — Operation Dashboard ★ start here for ops / TPO / support questions
- **URL:** https://metabase.prod-internal.porter.in/dashboard/4454
- 82 cards · 4,097 views · collection `Packers & Movers / Eldoria / PNM Operations Dashboard` · tabbed
- **Filters (18)** `[SLACK, Rohit Kanaujiya 2026-06-23]` `[MB]`: `start_date` · `end_date` ·
  `granularity_` · `pickup_city_name` · `city_name` · `drop_city_name` · `tier_filter` · `is_peak` ·
  **`nano_filter`** (`Without Nano` / with) · `order_status` · `package_name` · `service_type` ·
  `shifting_type` · `route_type` · `old/new_model` · `issue` · `sub_issue` · `rasied_by` *(spelled
  that way in the URL)*.
- ⚠ A colleague reported this dashboard "not working" on 2026-06-23 `[SLACK]`. If it errors, that is
  a known issue — raise it in `#pnm-analytics`.
- ⚠ **Do not use** `PNM - Operation Dashboard - Duplicate`
  ([6337](https://metabase.prod-internal.porter.in/dashboard/6337)) — a partial copy, 57 of 82 cards. `[MB]`

### 4.4 TPO Trend Dashboard
- **URL:** https://metabase.prod-internal.porter.in/dashboard/6060 · 5 cards
- **Answers:** "PNM TPO dashboard with filterable trend, issue-wise, and sub-issue-wise views."
- Its main card is **#47576 `TPO Trend`**
  ([question/47576](https://metabase.prod-internal.porter.in/question/47576), database **97**),
  which returns `completed_orders`, `tickets`, `tpo` per period.
- **Filters (10):** `Granularity` (default `month`) · `Start Date` (default 2024-01-01) ·
  `End Date` (default 2026-12-31) · **`Geo Region`** (city) · `Service Type` · `Shifting Type` ·
  `Raised By` · `Issue` · `Sub Issue` · `Is Peak`.
- This is the card the catalog's `tpo` section mirrors — but the card supports **city and
  granularity**, which the catalog does not. For "TPO in Bangalore last week", this dashboard is the
  answer. `[MB]` `[LOG D5]`

### 4.5 Other PnM dashboards `[MB]`

| Dashboard | URL | Answers | Filters (where known) |
|---|---|---|---|
| PnM :: Demand Dashboard | [6218](https://metabase.prod-internal.porter.in/dashboard/6218) | top-of-funnel, conversion, created orders (3 tabs) | created vs shifting date, DoD/WoW/MoM, shifting type, source group, source details, **city**, customer type, frequency bucket, Nano include/exclude |
| PnM :: AOP vs Actuals | [6104](https://metabase.prod-internal.porter.in/dashboard/6104) | monthly AOP vs actuals, orders, cancellation, revenue, paid vs organic | date range, **normalised city buckets** |
| PnM Demand Metacard | [6206](https://metabase.prod-internal.porter.in/dashboard/6206) | daily leads, bookings, completions, LMS share | date range, origin city, drop city |
| PnM Demand :: Lead-to-Order Conversion | [6222](https://metabase.prod-internal.porter.in/dashboard/6222) | IC vs IA conversion by lead source (Nano excluded) | date range, days-X, day/week/month |
| [DBT] Feedback Dashboard : PnM Only | [1062](https://metabase.prod-internal.porter.in/dashboard/1062) | customer feedback (4,306 views) | — |
| NPS Dashboard PnM-City level | [1068](https://metabase.prod-internal.porter.in/dashboard/1068) | NPS **by city** | — |
| PnM Dashboard w.r.t Zones and Clusters | [4826](https://metabase.prod-internal.porter.in/dashboard/4826) | zone / cluster view | — |
| PnM Demand and Supply | [4005](https://metabase.prod-internal.porter.in/dashboard/4005) | demand vs supply | — |
| [DBT] PnM Growth Card | [4166](https://metabase.prod-internal.porter.in/dashboard/4166) | growth, inter-city | — |
| PNM CPO Dashboard | [2619](https://metabase.prod-internal.porter.in/dashboard/2619) | cost per order | — |
| PnM Daily Alert | [6070](https://metabase.prod-internal.porter.in/dashboard/6070) | daily alerting | — |
| PnM Analytics Dashboard | [1505](https://metabase.prod-internal.porter.in/dashboard/1505) | general analytics | — |
| PNM :: Dashboard | [1132](https://metabase.prod-internal.porter.in/dashboard/1132) | legacy, 45,492 views | — |

> A `—` in the Filters column means **not yet resolved**, not "has no filters". Filters were verified
> card-by-card only for #30311, #47576 and #30433, plus dashboard 4454 (read off its URL). For every
> other entry, open the dashboard's own filter bar rather than assuming a filter exists.

87 PnM dashboards exist in total; the 17 above are the ones with the clearest ops relevance. Several
sit in **personal collections** (1132, 1505, 1068) and may not be shared — if a link 403s, ask in
`#pnm-analytics`. `[MB]`

---

## §5 · SQL template library

These are **exactly** the queries that were reconciled against the owner's validated MBR automation
`[SQL]` `[RECON]`. Each one is a single read-only `SELECT` for **one month, PnM-wide**.

**How the placeholders work.** Every template takes exactly one placeholder: `{{start_date}}` = the
**first day of the month** you want (`YYYY-MM-01`). It appears on two or three lines per template,
each marked `<<< EDIT THIS LINE`. **No template exposes `{{end_date}}`** — each one works out the end
of the month itself, so there is no second date to get wrong (see §0, deviation 3).

> ### ⚠ There is no `{{city}}` placeholder — and that is deliberate
> All six sections are PnM-wide by construction. No city-filtered variant of these queries has ever
> been reconciled, and adding a city line would produce a number that looks validated but is not.
> **For any city question, use a dashboard from §4** (they have real city filters) or raise a data
> request (§6). `[LOG D8-equivalent]` `[REG]`

### 5.1 `leads` — 5 lead metrics for one month
```sql
-- ══════════════════════════════════════════════════════════════════════════════
-- YOU MAY EDIT ONLY THE DATES ON THE LINES MARKED  <<< EDIT THIS LINE
-- Change NOTHING else. Every other line is validated and reconciled.
-- ══════════════════════════════════════════════════════════════════════════════
WITH leads_base AS (
    SELECT
        f.opp_id,
        CASE
            WHEN d.source_details = 'Desktop Website' THEN 'Desktop Website'
            WHEN d.source_details = 'Mobile Website'  THEN 'Mobile Website'
            WHEN d.source IN (1, 2, 3)                 THEN 'App'
            WHEN d.source = 4                           THEN 'Others'
            ELSE 'Mobile Website'
        END AS channel
    FROM PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY f
    LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY d ON d.opp_id = f.opp_id
    WHERE d.user_flag ILIKE 'normal'
      AND DATE_TRUNC('month', f.opp_created_ts) = '{{start_date}}'   -- <<< EDIT THIS LINE
      AND (d.shifting_type = 'intra_city' OR d.shifting_type IS NULL)
)
SELECT
    DATE '{{start_date}}'                                                 AS month,  -- <<< EDIT THIS LINE
    COUNT(DISTINCT opp_id)                                                AS leads_overall,
    COUNT(DISTINCT CASE WHEN channel = 'App'             THEN opp_id END) AS leads_app,
    COUNT(DISTINCT CASE WHEN channel = 'Desktop Website' THEN opp_id END) AS leads_desktop,
    COUNT(DISTINCT CASE WHEN channel = 'Mobile Website'  THEN opp_id END) AS leads_mobile,
    COUNT(DISTINCT CASE WHEN channel = 'Others'          THEN opp_id END) AS leads_others
FROM leads_base
```
**What this answers:** how many PnM intra-city leads came in during `{{start_date}}`'s month, split
by the channel they arrived through.

### 5.2 `orders` — 5 order metrics for one month
```sql
-- ══════════════════════════════════════════════════════════════════════════════
-- YOU MAY EDIT ONLY THE TWO DATES ON THE LINES MARKED  <<< EDIT THIS LINE
-- Change NOTHING else — especially not the joins, the Nano filter, or the QUALIFY.
-- ══════════════════════════════════════════════════════════════════════════════
WITH orders_base_raw AS (
    SELECT
        o.order_id,
        CASE
            WHEN d.source_details = 'Desktop Website' THEN 'Desktop Website'
            WHEN d.source_details = 'Mobile Website'  THEN 'Mobile Website'
            WHEN d.source IN (1, 2, 3)                 THEN 'App'
            WHEN d.source = 4                           THEN 'Others'
            ELSE 'Mobile Website'
        END AS channel
    FROM PROD_ELDORIA.CORE.FACT_PNM_ORDERS o
    INNER JOIN PROD_ELDORIA.MART.PNM_CUSTOMERS        pc   ON pc.customer_mobile = o.customer_mobile
    LEFT  JOIN PROD_ELDORIA.CORE.DIM_PNM_ORDERS       dord ON dord.order_id = o.order_id
    LEFT  JOIN PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY fpo  ON fpo.sr_id = o.sr_id
    LEFT  JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY  d    ON d.opp_id = fpo.opp_id
    WHERE dord.user_flag ILIKE 'normal'
      AND DATE_TRUNC('month', o.o_created_ts) = '{{start_date}}'      -- <<< EDIT THIS LINE
      AND dord.shifting_type = 'intra_city'
      AND o.crn LIKE '%PNM%'
      AND (dord.package_name NOT ILIKE 'Nano%' OR dord.package_name IS NULL)
    QUALIFY ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY fpo.opp_id DESC NULLS LAST) = 1
)
SELECT
    DATE '{{start_date}}'                                                   AS month,  -- <<< EDIT THIS LINE
    COUNT(DISTINCT order_id)                                                AS orders_overall,
    COUNT(DISTINCT CASE WHEN channel = 'App'             THEN order_id END) AS orders_app,
    COUNT(DISTINCT CASE WHEN channel = 'Desktop Website' THEN order_id END) AS orders_desktop,
    COUNT(DISTINCT CASE WHEN channel = 'Mobile Website'  THEN order_id END) AS orders_mobile,
    COUNT(DISTINCT CASE WHEN channel = 'Others'          THEN order_id END) AS orders_others
FROM orders_base_raw
```
**What this answers:** how many non-Nano PnM intra-city orders were booked in `{{start_date}}`'s
month, split by the channel of the lead they came from.

### 5.3 `derived` — leads + orders in one query, for conversion and order mix
```sql
-- ══════════════════════════════════════════════════════════════════════════════
-- YOU MAY EDIT ONLY THE DATES ON THE LINES MARKED  <<< EDIT THIS LINE
-- Change NOTHING else. This returns the raw counts; the ratios are worked out below.
-- ══════════════════════════════════════════════════════════════════════════════
WITH leads_base AS (
    SELECT
        f.opp_id,
        CASE
            WHEN d.source_details = 'Desktop Website' THEN 'Desktop Website'
            WHEN d.source_details = 'Mobile Website'  THEN 'Mobile Website'
            WHEN d.source IN (1, 2, 3)                 THEN 'App'
            WHEN d.source = 4                           THEN 'Others'
            ELSE 'Mobile Website'
        END AS channel
    FROM PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY f
    LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY d ON d.opp_id = f.opp_id
    WHERE d.user_flag ILIKE 'normal'
      AND DATE_TRUNC('month', f.opp_created_ts) = '{{start_date}}'      -- <<< EDIT THIS LINE
      AND (d.shifting_type = 'intra_city' OR d.shifting_type IS NULL)
),
orders_base_raw AS (
    SELECT
        o.order_id,
        CASE
            WHEN d.source_details = 'Desktop Website' THEN 'Desktop Website'
            WHEN d.source_details = 'Mobile Website'  THEN 'Mobile Website'
            WHEN d.source IN (1, 2, 3)                 THEN 'App'
            WHEN d.source = 4                           THEN 'Others'
            ELSE 'Mobile Website'
        END AS channel
    FROM PROD_ELDORIA.CORE.FACT_PNM_ORDERS o
    INNER JOIN PROD_ELDORIA.MART.PNM_CUSTOMERS        pc   ON pc.customer_mobile = o.customer_mobile
    LEFT  JOIN PROD_ELDORIA.CORE.DIM_PNM_ORDERS       dord ON dord.order_id = o.order_id
    LEFT  JOIN PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY fpo  ON fpo.sr_id = o.sr_id
    LEFT  JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY  d    ON d.opp_id = fpo.opp_id
    WHERE dord.user_flag ILIKE 'normal'
      AND DATE_TRUNC('month', o.o_created_ts) = '{{start_date}}'        -- <<< EDIT THIS LINE
      AND dord.shifting_type = 'intra_city'
      AND o.crn LIKE '%PNM%'
      AND (dord.package_name NOT ILIKE 'Nano%' OR dord.package_name IS NULL)
    QUALIFY ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY fpo.opp_id DESC NULLS LAST) = 1
),
leads_monthly AS (
SELECT
    DATE '{{start_date}}'                                                 AS month,  -- <<< EDIT THIS LINE
    COUNT(DISTINCT opp_id)                                                AS leads_overall,
    COUNT(DISTINCT CASE WHEN channel = 'App'             THEN opp_id END) AS leads_app,
    COUNT(DISTINCT CASE WHEN channel = 'Desktop Website' THEN opp_id END) AS leads_desktop,
    COUNT(DISTINCT CASE WHEN channel = 'Mobile Website'  THEN opp_id END) AS leads_mobile,
    COUNT(DISTINCT CASE WHEN channel = 'Others'          THEN opp_id END) AS leads_others
FROM leads_base
),
orders_monthly AS (
SELECT
    DATE '{{start_date}}'                                                   AS month,  -- <<< EDIT THIS LINE
    COUNT(DISTINCT order_id)                                                AS orders_overall,
    COUNT(DISTINCT CASE WHEN channel = 'App'             THEN order_id END) AS orders_app,
    COUNT(DISTINCT CASE WHEN channel = 'Desktop Website' THEN order_id END) AS orders_desktop,
    COUNT(DISTINCT CASE WHEN channel = 'Mobile Website'  THEN order_id END) AS orders_mobile,
    COUNT(DISTINCT CASE WHEN channel = 'Others'          THEN order_id END) AS orders_others
FROM orders_base_raw
)
SELECT
    l.month,
    l.leads_overall, l.leads_app, l.leads_desktop, l.leads_mobile, l.leads_others,
    o.orders_overall, o.orders_app, o.orders_desktop, o.orders_mobile, o.orders_others
FROM leads_monthly l
CROSS JOIN orders_monthly o
```
The query returns counts. Work the 7 `derived` metrics out from them:
```
conversion_overall  = 100 × orders_overall  ÷ leads_overall
conversion_app      = 100 × orders_app      ÷ leads_app
conversion_desktop  = 100 × orders_desktop  ÷ leads_desktop
conversion_mobile   = 100 × orders_mobile   ÷ leads_mobile
pct_orders_app      = 100 × orders_app      ÷ orders_overall
pct_orders_website  = 100 × (orders_desktop + orders_mobile) ÷ orders_overall
pct_orders_others   = 100 × orders_others   ÷ orders_overall
```
**Never average monthly percentages together.** For a multi-month figure, add the numerators and
denominators first, then divide once. `[REG]` `[LOG D7]`
**What this answers:** what share of leads turned into bookings, and which channels those bookings
came from, for one month.

### 5.4 `tpo` — 13 tickets-per-order metrics for one month
```sql
-- ══════════════════════════════════════════════════════════════════════════════
-- YOU MAY EDIT ONLY THE TWO DATES ON THE LINES MARKED  <<< EDIT THIS LINE
-- Change NOTHING else. Note the month is ALLOCATION-COMPLETION month, not booking month.
-- ══════════════════════════════════════════════════════════════════════════════
WITH orders AS (
    SELECT
        DATE_TRUNC('month', DATEADD(minute, 330, b.completed_ts)) AS month,
        COUNT(DISTINCT a.crn) AS total_orders
    FROM PROD_CURATED.PNM_APPLICATION.ORDERS a
    JOIN PROD_CURATED.PNM_APPLICATION.ORDER_ALLOCATION_INFOS b ON a.id = b.order_id AND b.is_active = true
    LEFT JOIN PROD_CURATED.PNM_APPLICATION.SHIFTING_REQUIREMENTS c ON a.sr_id = c.id
    WHERE a.crn LIKE '%PNM%'
      AND c.package_name NOT ILIKE '%Nano%'
      AND c.shifting_type = 'intra_city'
      AND DATE_TRUNC('month', DATEADD(minute, 330, b.completed_ts)) = '{{start_date}}'  -- <<< EDIT THIS LINE
    GROUP BY 1
),
tickets AS (
    SELECT
        DATE_TRUNC('month', DATEADD(minute, 330, hst.created_at)) AS month,
        COUNT(DISTINCT hst.ticket_number) AS tickets_overall,
        COUNT(DISTINCT CASE WHEN hst.raised_by ILIKE 'Vendor%' THEN hst.ticket_number END) AS tickets_vendor,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN
                        ('open','supervisor_assigned','supervisor_accepted','vendor_accepted')
                   THEN hst.ticket_number END) AS tickets_pre_trip,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN
                        ('open','supervisor_assigned','supervisor_accepted','vendor_accepted')
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_pre_trip_cust,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN ('trip_started','shifting_started')
                   THEN hst.ticket_number END) AS tickets_trip_shift,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN ('trip_started','shifting_started')
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_trip_shift_cust,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'pickup_completed'
                   THEN hst.ticket_number END) AS tickets_pickup,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'pickup_completed'
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_pickup_cust,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'completed'
                   THEN hst.ticket_number END) AS tickets_completed,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'completed'
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_completed_cust,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'cancelled'
                   THEN hst.ticket_number END) AS tickets_cancelled,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'cancelled'
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_cancelled_cust
    FROM PROD_CURATED.SFMS_PUBLIC.HS_TICKETS hst
    LEFT JOIN PROD_CURATED.PNM_APPLICATION.ORDERS a ON hst.crn = a.crn
    LEFT JOIN PROD_CURATED.PNM_APPLICATION.SHIFTING_REQUIREMENTS c ON a.sr_id = c.id
    WHERE hst.crn LIKE '%PNM%'
      AND hst.hs_package NOT ILIKE '%Nano%'
      AND COALESCE(hst.shifting_type, c.shifting_type) = 'intra_city'
      AND COALESCE(hst.raised_by, '') != 'Detractor'
      AND DATE_TRUNC('month', DATEADD(minute, 330, hst.created_at)) = '{{start_date}}'  -- <<< EDIT THIS LINE
    GROUP BY 1
)
SELECT
    o.month,
    o.total_orders                                                  AS orders_base,
    ROUND(t.tickets_overall         / NULLIF(o.total_orders, 0), 4) AS tpo_overall,
    ROUND(t.tickets_vendor          / NULLIF(o.total_orders, 0), 4) AS tpo_vendor_raised,
    ROUND(t.tickets_pre_trip        / NULLIF(o.total_orders, 0), 4) AS tpo_pre_trip,
    ROUND(t.tickets_pre_trip_cust   / NULLIF(o.total_orders, 0), 4) AS tpo_pre_trip_customer,
    ROUND(t.tickets_trip_shift      / NULLIF(o.total_orders, 0), 4) AS tpo_trip_shift,
    ROUND(t.tickets_trip_shift_cust / NULLIF(o.total_orders, 0), 4) AS tpo_trip_shift_customer,
    ROUND(t.tickets_pickup          / NULLIF(o.total_orders, 0), 4) AS tpo_pickup,
    ROUND(t.tickets_pickup_cust     / NULLIF(o.total_orders, 0), 4) AS tpo_pickup_customer,
    ROUND(t.tickets_completed       / NULLIF(o.total_orders, 0), 4) AS tpo_completed,
    ROUND(t.tickets_completed_cust  / NULLIF(o.total_orders, 0), 4) AS tpo_completed_customer,
    ROUND(t.tickets_cancelled       / NULLIF(o.total_orders, 0), 4) AS tpo_cancelled,
    ROUND(t.tickets_cancelled_cust  / NULLIF(o.total_orders, 0), 4) AS tpo_cancelled_customer
FROM orders o
LEFT JOIN tickets t ON t.month = o.month
ORDER BY o.month
```
**What this answers:** how many support tickets were raised per order for jobs whose allocation
completed in `{{start_date}}`'s month, broken down by who raised them and at which stage.

### 5.5 `p80_durations` — 7 stage-duration percentiles for one month
```sql
-- ══════════════════════════════════════════════════════════════════════════════
-- YOU MAY EDIT ONLY THE DATES ON THE LINES MARKED  <<< EDIT THIS LINE
-- Change NOTHING else. "Supervisor Assigned" reads SUPERVISOR_ACCEPTED_TS_IST — intentional.
-- ══════════════════════════════════════════════════════════════════════════════
SELECT
    DATE '{{start_date}}' AS month,                                        -- <<< EDIT THIS LINE
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', VENDOR_OWNER_ACCEPTED_TS_IST, SUPERVISOR_ACCEPTED_TS_IST)), 1) AS p80_vendor_accepted_to_sup_assigned,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', SUPERVISOR_ACCEPTED_TS_IST, TRIP_STARTED_TS_IST)), 1)           AS p80_sup_assigned_to_trip_started,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', TRIP_STARTED_TS_IST, SHIFTING_STARTED_TS_IST)), 1)              AS p80_trip_started_to_shifting_started,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', SHIFTING_STARTED_TS_IST, PICKUP_COMPLETED_TS_IST)), 1)          AS p80_shifting_started_to_pickup_complete,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', PICKUP_COMPLETED_TS_IST, ORDER_COMPLETED_TS_IST)), 1)           AS p80_pickup_complete_to_order_complete,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY DATEDIFF('minute', SHIFTING_STARTED_TS_IST, ORDER_COMPLETED_TS_IST)), 1)           AS p50_trip_duration,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', SHIFTING_STARTED_TS_IST, ORDER_COMPLETED_TS_IST)), 1)           AS p80_trip_duration
FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
WHERE SHIFTING_TS_IST >= '{{start_date}}'                                  -- <<< EDIT THIS LINE
  AND SHIFTING_TS_IST <  DATEADD('month', 1, DATE '{{start_date}}')        -- <<< EDIT THIS LINE
  AND ORDER_STATUS = 'completed'
  AND PACKAGE_NAME NOT ILIKE 'Nano%'
  AND SHIFTING_TYPE = 'intra_city'
```
**What this answers:** for completed non-Nano intra-city moves scheduled in `{{start_date}}`'s month,
how long each execution stage took for the slowest 20% of jobs (and the median overall duration), in
minutes.

### 5.6 `order_edits` — 10 edit-adoption metrics for one month
```sql
-- ══════════════════════════════════════════════════════════════════════════════
-- YOU MAY EDIT ONLY THE DATES ON THE LINES MARKED  <<< EDIT THIS LINE
-- Change NOTHING else. The last metric divides by edits, not orders — that is correct.
-- ══════════════════════════════════════════════════════════════════════════════
WITH base AS (
    SELECT
        COUNT(DISTINCT pe.ORDER_ID)                                                    AS total_orders,
        COUNT(DISTINCT CASE WHEN pe.IS_MODIFICATION_DONE = 'Yes' THEN pe.ORDER_ID END) AS orders_with_mods,
        SUM(pe.NO_OF_SUCCESSFUL_EDITS)                                                 AS no_of_successful_edits,
        SUM(pe.EDITS_AFTER_SHIFTING)                                                   AS edits_after_shifting,
        COUNT(DISTINCT CASE WHEN pe.HAS_SUPPORT_EDIT  = 1 THEN pe.ORDER_ID END)        AS support_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_LOCATION_EDIT = 1 THEN pe.ORDER_ID END)        AS location_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_ITEMS_EDIT    = 1 THEN pe.ORDER_ID END)        AS items_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_ADDONS_EDIT   = 1 THEN pe.ORDER_ID END)        AS addons_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_SLOT_EDIT     = 1 THEN pe.ORDER_ID END)        AS slot_edited_orders
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE pe
    WHERE pe.ORDER_CREATED_TS_IST >= '{{start_date}}'                                  -- <<< EDIT THIS LINE
      AND pe.ORDER_CREATED_TS_IST <  DATEADD('month', 1, DATE '{{start_date}}')        -- <<< EDIT THIS LINE
      AND pe.ORDER_STATUS = 'completed'
      AND pe.SHIFTING_TYPE = 'intra_city'
      AND pe.PACKAGE_NAME NOT ILIKE 'Nano%'
)
SELECT
    DATE '{{start_date}}' AS month,                                                    -- <<< EDIT THIS LINE
    ROUND(100.0 * orders_with_mods       / NULLIF(total_orders, 0), 2)           AS pct_orders_edited,
    no_of_successful_edits,
    ROUND(100.0 * support_edited_orders  / NULLIF(total_orders, 0), 2)           AS pct_support_edited_orders,
    ROUND(100.0 * location_edited_orders / NULLIF(total_orders, 0), 2)           AS location_adoption_pct,
    ROUND(100.0 * location_edited_orders / NULLIF(total_orders, 0), 2)           AS pct_orders_location_modified,
    ROUND(100.0 * items_edited_orders    / NULLIF(total_orders, 0), 2)           AS items_adoption_pct,
    ROUND(100.0 * addons_edited_orders   / NULLIF(total_orders, 0), 2)           AS addons_adoption_pct,
    ROUND(100.0 * slot_edited_orders     / NULLIF(total_orders, 0), 2)           AS slot_adoption_pct,
    ROUND(no_of_successful_edits * 1.0   / NULLIF(total_orders, 0), 2)           AS edits_per_order,
    ROUND(100.0 * edits_after_shifting   / NULLIF(no_of_successful_edits, 0), 2) AS pct_edits_after_shifting_started
FROM base
```
**What this answers:** for completed non-Nano intra-city orders booked in `{{start_date}}`'s month,
what share had changes made to them, of what kind, by whom, and how many happened after the move had
already started.

### 5.7 The CLI these templates come from `[REG]` `selfserve_nlq/README.md`
```bash
python ask.py --list                                          # the menu + readiness
python ask.py --metric tpo_overall --month 2026-05            # DRY RUN — prints SQL, runs nothing
python ask.py --metric tpo_overall --month 2026-05 --execute  # one read-only SELECT
```
Dry-run is the default and the printed SQL is byte-for-byte what would run. `--execute` needs `SF_*`
environment variables. Every executed answer is appended to `answers_log/answers.jsonl`.

---

## §6 · Known gotchas / FAQ

**"Why doesn't this match the number in my dashboard?"** Most likely one of: (a) Nano — the catalog
keeps Nano in leads but the dashboards mostly strip it everywhere (§1, §4.2); (b) date basis — the
catalog counts leads on lead-creation, orders on booking, TPO on allocation-completion, p80 on
shifting date (§1); (c) cancelled orders — the catalog's `orders_overall` includes them; (d) you are
looking at an "- including nano" twin card (§4.1).

**"Can I get this by city?"** Not from the metric catalog — it is PnM-wide only. Use §4 (dashboard
4076 city-split cards, 4454, 6218, 6104, 6206, or 1068 for NPS) or raise a data request. The
underlying city columns do exist, so analytics *can* build it. `[REG]` `[LIVE]`

**"Can I get this weekly or daily?"** Not from the catalog — every metric is monthly. Dashboards
4454, 6218 and card #47576 have granularity controls. `[REG]` `[MB]`

**"Can I get the median / average instead of p80?"** No. `median`, `p50`, `p90`, `p99` and
`average of` are all refused. `p50_trip_duration` is computed but has no plain-English route to it.
`[REG]` `[LOG D10]`

**"Can I split by vendor?"** No — `by vendor`, `per vendor`, `vendor wise` are refused. Note
`tpo_vendor_raised` is different: it means *tickets raised by vendors*, not TPO broken down per
vendor. `[REG]`

**"Is this month's number final?"** If the month is still running, it is month-to-date and will move.
Always say so. Future months are refused outright. `[REG]` `[SQL]`

**"Why is `p80_vendor_accepted_to_sup_assigned` about 2 days?"** It genuinely runs 2,500–2,800
minutes across every baseline month. Flag it rather than quoting it as a normal stage time.
`[reference/README.md]` `[RECON]`

**"`location_adoption_pct` and `pct_orders_location_modified` are the same number."** Correct — one
calculation, two names, copied from the MBR sheet. `[REG]`

**"`pct_edits_after_shifting_started` is over 100%."** Possible — it divides by edits, not orders. `[REG]`

**"Are test orders excluded?"** Largely **no** (§3.5). Leads and orders gate on
`user_flag ILIKE 'normal'`; p80 and order_edits have no user or test filter at all.

**The words the system refuses outright** `[REG]`: any of the 14 city names, plus `city`, `cities`,
`citywise`, `city-wise`, `region`, `zone`, `cluster`, `tier`; `weekly`, `daily`, `per week`,
`per day`, `by week`, `by day`, `quarterly`, `quarter`; `median`, `p50`, `p90`, `p99`, `average of`;
`vendor wise`, `vendorwise`, `by vendor`, `per vendor`.

### Live data-integrity issues to be aware of `[SLACK]`

| Since | Issue | Effect |
|---|---|---|
| 2026-07-22 (open) | `ameyo_webhook_events` has had no data flowing **since June 2026** (raised by Hrushikesh Kene) | call/rechurn metacards built on it may be wrong or empty |
| 2026-07-13 | PnM vendor-bucket Google Sheet has duplicate rows (7-Jan-2026 batch, 78 vendors) — same period, different bucket | anything cut by `VENDOR_BUCKET_TYPE` may double-count |
| 2026-06-22 | Default Short pricing model changed: `surge_rebate_campaign_id` is now always NULL, and the 15% discount is baked into `base_fare` | do **not** reconstruct a DS price as `base × surge × 0.85` — it double-counts |
| 2026-07-14 | `pickup_boundary` / `drop_boundary`: `is_active` being dropped for `status`, which is still NULL in Snowflake pending backfill | boundary-based logic may break |
| 2026-07-31 (planned) | Vendor Aadhaar moves to encrypted storage; plaintext fields dropped | `vendor_onboarding_infos.aadhaar_number` becomes ciphertext |

None of these touch the six catalog sections directly, but they affect neighbouring dashboards — so
if a dashboard number looks wrong, check this list before escalating.

---

## §7 · Open questions & source conflicts

Unresolved. Each needs an owner or analytics decision — the Gem must not resolve any of them itself.

**Q1 — No city or weekly cut exists for the catalog, but that is what city ops will ask for.**
This is the biggest gap between this knowledge base and its audience. The columns exist `[LIVE]`, the
dashboards do it `[MB]`, but no city- or week-level metric has been reconciled, so the catalog
refuses. **Decision needed:** should analytics validate a city/weekly variant of the six sections, or
should city ops be routed to dashboards permanently?

**Q2 — Notion's schema guide is out of date; live schema disagrees with it in five places.**
The stated precedence rule is to prefer Notion for schema facts, but the warehouse itself
contradicts it. All five are recorded with both readings; §3 uses the live values because a query
written against Notion's types would fail.

| # | Notion says `[NOTION]` | Live says `[LIVE]` | Consequence |
|---|---|---|---|
| 1 | `PNM_EXPERIENCE.IS_MODIFICATION_DONE` is BOOLEAN (TRUE/FALSE) | **TEXT** | the shipped `= 'Yes'` comparison is correct; a boolean comparison would fail |
| 2 | `PNM_EXPERIENCE` has ~52 columns, no `SHIFTING_TS_IST`, no `HAS_*_EDIT`, no `NO_OF_SUCCESSFUL_EDITS` | **71 columns, all present** | the mart grew after the Notion snapshot; 9 columns the catalog needs are simply missing from Notion |
| 3 | `PNM_EXPERIENCE.OTA_FLAG` is BOOLEAN | **TEXT** | any `OTA_FLAG = TRUE` predicate is wrong |
| 4 | `DIM_PNM_OPPORTUNITY` / `DIM_PNM_ORDERS` have no `USER_FLAG` | **both have `USER_FLAG` TEXT** | the mandatory `user_flag ILIKE 'normal'` filter is valid |
| 5 | `PNM_SUPPORT.MODIFICATION_CATEGORY_LIST` is VARCHAR; three `*_FLAG` columns BOOLEAN | **ARRAY**; the flags are **TEXT** | affects anyone querying `PNM_SUPPORT` |

**Recommendation:** re-generate the Notion guide from `INFORMATION_SCHEMA`, and add the two marts
from §3.4 to it.

**Q3 — OTA has two conflicting definitions and no owner.** Notion's glossary says on-time arrival
means within the first 30 minutes **and within a 500 m radius** `[NOTION]`. The original pipeline
metric said within 30 minutes **and within 2 km** `[IT1]`. `PNM_EXPERIENCE.OTA_FLAG` /
`OTA_BREACH_TAT_MINUTES` now exist `[LIVE]` and encode *someone's* rule, undocumented.
**Decision needed:** which threshold is correct, and is `OTA_FLAG` the sanctioned source? Until then
`ota` stays blocked. `[LOG]`

**Q4 — Should `p80_vendor_accepted_to_sup_assigned` be answerable in plain English?**
Currently hidden. The original reason for hiding it was **wrong** — a "vendor guard" that does not
actually block it — and the correction is on record. It is a legitimate stage metric published in the
baseline like its visible siblings. Owner leaning ~55% keep hidden; **unresolved**. `[LOG D10]`

**Q5 — Card #30311 is labelled the "canonical methodology" but the catalog deliberately diverges.**
`config.py` names card #30311 as canonical `[IT1]`, yet D6 rules that the catalog reconciles against
the MBR note / Notion Demand DB instead, because #30311 strips Nano from the whole funnel `[LOG D6]`.
Both statements are in the sources. **The readiness ledger and decision log win** — but the stale
"canonical" comment should be corrected at source.

**Q6 — `PNM_EXPERIENCE` is "still under active construction".** Its schema grew twice during the
project, once between two checks a day apart `[AUTO]` `[IT3]`. All required columns were present on
2026-07-29 `[LIVE]`, but p80 and order_edits could break without warning. **Re-verify before any run.**

**Q7 — Recent-month p80 drift is explained but not monitored.** p80 is bit-exact for settled months
and drifts up to 0.84% for recent ones as the mart backfills `[RECON]`. Nobody has set a policy for
how old a month must be before its p80 is quotable as final.

**Q8 — Nothing has been promoted, and nothing has been opened to stakeholders.** All six sections are
`prototype_only`; promotion is owner-only. `ota` is blocked. Two owner action items from the handoff
remain open: a multi-month extension of the reconciliation, and a cross-check against the Notion
Demand DB. `[LEDGER]` `[LOG]` `[HANDOFF]`

---

## §8 · Source inventory and accessibility

Every source consulted, and its state. **Nothing was skipped.**

| Source | State | Note |
|---|---|---|
| `pnm-selfserve/iteration-1-metric-catalog-and-architecture.md` | read in full | metric catalog **superseded**; used for history + cross-cutting caveats only |
| `pnm-selfserve/iteration-2-readiness-ledger.md` | read in full | readiness definitions; its per-section table is superseded by `DECISION_LOG` V4 |
| `pnm-selfserve/iteration-3-p80-orderedits-spec.md` | read in full | the p80 / order_edits design |
| `pnm-selfserve/DECISION_LOG.md` | read in full | **authoritative** for decisions + validation (D1–D10, V1–V4) |
| `pnm-selfserve/HANDOFF.md` | read in full | partly stale by its own admission; the decision log wins |
| `selfserve_nlq/metrics_registry.py` | read in full | **authoritative** for metric definitions, aliases, quirks, readiness |
| `selfserve_nlq/sqlgen.py`, `ask.py`, `run_tests.py`, `README.md` | read | CLI contract, guards, footer format |
| `selfserve_nlq/tests_output/rendered_*_2026-05.sql` (6 files) | read in full | source of §5's templates |
| `selfserve_nlq/tests_output/dry_run_report.md` | read in full | 54/54 pass, incl. the refusal cases |
| `selfserve_nlq/tests_output/reconciliation_2026-07-19.md` | read in full | live reconciliation evidence |
| `reference/p80_durations_baseline_2025-10_to_2026-05.csv` + README | read in full | the p80 validation baseline |
| `docs/overview.html` | read | **pre-iteration-3**: says p80/order_edits "not built" and "31/31 tests". Both now outdated — 54/54, both built. |
| Notion "Eldoria PnM Schema Guide" | **read in full** | snapshot **2026-03-31**; five conflicts with live schema (Q2) |
| `project-argus-hcv-pnm-ptl-implementation-plan.md` | read in full | Argus programme context; confidence-gradient model |
| `project-argus-team-guide.html` | **partially accessible** — compiled React bundle; prose extracted from the JS, no clean DOM. Substantively duplicates the `.md` plan, plus the confidence tiers (governed = 100%; documented mart = 75–65%; raw = 55–50%; below 50% refuse). |
| Snowflake `INFORMATION_SCHEMA.COLUMNS` | queried read-only 2026-07-29 | 14 tables; source of all §3 types |
| Metabase + Data Catalog card/dashboard metadata | queried 2026-07-29 | source of all §4 URLs and filters. Metadata only — **no card was executed, no MBR number pulled** |
| Slack `#pnm-analytics` (C02FQDRAAUT) | read (recent history) | dashboard 4454 filters, the two new marts, the §6 integrity issues |

**Source pointers in the original brief that resolved differently — worth correcting:**
1. **`queries.py`** is the MBR automation at `ProdOps/pnm/pnm_mbr_monthly_metrics/queries.py`
   (1,343 lines, 14 sections). The self-serve prototype has no `queries.py`; its equivalents are
   `metrics_registry.py` + `sqlgen.py`.
2. **`rendered_tpo_202605.sql`** exists at `ProdOps/selfserve/pnm/rendered_tpo_202605.sql` but is a
   **stale pre-Option-A artifact** — it queries `PROD_CURATED.pnm_application.fact_pnm_opprotunity`
   with `intra_city = TRUE` and `is_nano`, none of which is current. `DECISION_LOG` §4.4 already
   flags these flattened copies as "NOT the deliverable". §5 uses
   `tests_output/rendered_tpo_2026-05.sql` instead. **Do not use the 202605 file.**
3. The live working copy is `~/dev/selfserve/pnm-selfserve/`, relocated 2026-07-19 out of the
   DLP-locked `~/Desktop/AI_V2` tree.
