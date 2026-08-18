# dashboards.md — sources, cards, and staleness fingerprints

Entry point: [CONTEXT.md](./CONTEXT.md). Rules: [CONTRIBUTING.md](./CONTRIBUTING.md).
All rows `last_verified: 2026-07-29`. Base URL: `https://metabase.prod-internal.porter.in`

**Staleness check** — one metadata call, no query execution:
`get_card(card_id=<id>)` → if its `updated_at` > the `source_updated_at` recorded here, the fact
built on it is **STALE**. Re-extract before trusting it. See CONTRIBUTING §5.

## Staleness fingerprints — every card this KB relies on
*(`G-116` closed 2026-07-30. Compare a card's current `updated_at` to the value here; newer ⇒ STALE.)*

| card | `source_updated_at` | db | card | `source_updated_at` | db |
|---|---|---|---|---|---|
| **33519** | 2026-07-03T08:29:00Z | **83** | 39117 | 2026-07-14T10:37:29Z | 73 |
| 33462 | 2026-07-28T09:54:28Z | 73 | 38287 | 2026-07-14T10:08:52Z | 73 |
| 33483 | 2026-07-28T09:54:27Z | 73 | 39149 | 2026-07-14T10:55:48Z | 73 |
| 33485 | 2026-01-09T09:12:11Z | 73 | 39107 | 2026-07-14T09:15:34Z | 73 |
| 37419 | 2026-01-11T18:11:46Z | 73 | 39118 | 2026-08-14T07:56:55Z | 73 |
| 33466 | 2026-01-11T16:16:18Z | 73 | 43406 | 2025-12-01T09:46:29Z | 73 |
| 43238 | 2026-02-09T09:57:42Z | 73 | 39104 | 2025-10-07T11:59:16Z | 73 |
| 37104 | 2026-01-11T17:50:47Z | 73 | 38900 | 2025-09-16T11:32:57Z | 73 |
| 33706 | 2026-01-11T16:14:14Z | 73 | 41124 | 2025-10-08T05:44:03Z | 73 |
| 37413 | 2026-07-28T09:54:29Z | 73 | 44410 | 2026-05-12T07:07:49Z | 73 |
| 52889 | 2026-07-08T08:01:17Z | 73 | **43237** | 2025-11-27T09:19:28Z | 73 |
| 33460 | 2026-06-01T07:38:50Z | 73 | **42683** | 2025-11-18T10:09:14Z | 73 |
| 47540 | 2026-04-06T11:49:21Z | 73 | **49366** | 2026-05-14T10:39:36Z | 73 |
| 48449 | 2026-04-06T11:53:10Z | 73 | 49365 | 2026-05-05T06:25:06Z | 73 |
| 33461 | 2026-02-09T10:07:25Z | 73 | 44469 | 2026-07-14T12:18:05Z | 73 |
| 48922 | 2026-04-16T18:52:37Z | 73 | 48984 | 2026-05-06T12:12:04Z | 73 |
| 48919 | 2026-04-16T17:23:19Z | 73 | 49311 | 2026-05-05T16:00:39Z | 73 |

> ⚠️ **9 cards added 2026-07-30 (batch 2: 34052, 34364, 33784, 33823, 33785, 33824, 42081, 42080,
> 37416) have NO fingerprint yet.** The worker that found them was scoped to metadata search, not
> fingerprint capture — recorded here rather than guessed. → `G-152`

### The three Metabase database connections
| id | name | role here |
|---|---|---|
| **73** | `SNOWFLAKE_NEW_INI` | every metric card on 4198 / 4569 / 4793 |
| **83** | `SNOWFLAKE_BUSINESS_ENGG_PRODUCT` | card 33519 only |
| **108** | `SNOWFLAKE_NI_ELDORIA` | the governed dbt layer ruling D2 defers migrating to |

All three are `engine: snowflake`. db73 and db83 cards reference the **identical fully-qualified
tables** (`partload_application.orders`, `.order_fares`, `.quotations`,
`partload_analytics.ptl_internal_users`), so they are near-certainly different roles/warehouses over
one account rather than different data. `T-001`, `T-010` and `T-011` were re-verified directly on
db73 on 2026-07-30. Two facts remain db83-only — `T-001a` (the `0/1/2` state labels) and **`T-012`**
(the grams→kg weight scaling) → `G-136`.

---

## Surfaces covered

| Surface | id | Scale | Opened | Role |
|---|---|---|---|---|
| PTL Business Observability | `dashboard/4198` | ~82 unique cards / 11 tabs / ~112 placements | 27 | Fulfilment, cancellation, AOV/revenue, clubbing |
| Customer Dashboard | `dashboard/4569` | 50 cards / 7 tabs | 22 | Customers, retention, conversion, business/personal |
| Ops - Orders Details | `card/33519` | single card | 1 | Order-level operational detail |
| Cancellation (canonical, D5) | `dashboard/4793` | 6 CBDF/CADF-family cards read | 6 | **The only verified source of CBDF/CADF** |

> **93 cards were NOT opened** — 54 on 4198, 28 on 4569, 11 on 4793. Every one is listed with a
> reason in [GAPS.md](./GAPS.md) `G-120`…`G-131`. This is a stated boundary, not implied coverage.

---

## `dashboard/4198` — PTL Business Observability

**Tabs:** Overview, Finance, Demand Distribution, Utilization, Cancellations, Support, Supply, SLA,
Route Level, OKR, Order Share, Clubbing.
**Filters:** Start/End Date · Period (Day/Week/Month, default **Week**) · Is Test (default **False**)
· Pickup City · Drop City · Order State · Return Route Name · Delivery Type (SDD/NDD).

| Card | Name | Computes | Feeds |
|---|---|---|---|
| 33483 | Total Orders | `COUNT(DISTINCT external_id)`, online+offline union | M-002 |
| 33485 / 37419 | Fulfilment % | `state=3 / all states` — **same formula, NOT byte-identical**: the SQL text differs (`is_active` vs `ptl_routes.is_active` join qualifier) and the display type differs (smartscalar vs bar) | M-003 |
| 33466 / 43238 / 37104 | Fulfilment excl-60s | `completed / (all − cancels ≤60s)`, `<60s` **dropped from the DENOMINATOR** — verbatim: `COUNT(DISTINCT external_id) - COUNT(DISTINCT CASE WHEN DATEDIFF(SECOND, created_at, ocr_created_at) <= 60 THEN external_id END)`, numerator untouched. **33466 and 43238 return 5 metrics; 37104 returns only 3** (split by EDD dimension instead) | M-003, `G-002` |
| 43897 | Fulfilment Rate — Route | completed/all per route percentile bucket | — |
| 33462 | Order Funnel | raw counts only (total/completed/cancelled/in-process); **no ratio in SQL** | — |
| 33539 / 34506 / 39941 | Cancellation % | `state=4 / all` — **flat, no CBDF/CADF split** | `G-001` |
| 33464 / 33465 | Cancellation by reason / source | dimensional cuts of `order_cancellation_reasons` | — |
| 35252 / 35253 | Cancellation time median / P90 | `DATEDIFF(created_at, updated_at)` — **different time source**, no `<60s` exclusion | `G-002` |
| 33706 | AOV (base 1) | `estimated_fare` | M-008, `G-004` |
| 37413 | Total Revenue + GM + AOV (base 2) | WD-revised `final_fare` | M-008, `G-004` |
| 52889 | AOV (base 3) | `total_fare + discount` | M-008, `G-004` |
| 34284 | WD Share in Revenue | weight-discrepancy revenue share | — |
| 33460 | Orders Clubbed Distribution | all non-cancelled states | M-007, `G-011` |
| 47540 / 48449 | PTL Batching Opportunity | `current_club_pct`, `potential_pct`, `realized_pct`, `opportunity_pct`, `gap_pct` — **self-documented in SQL comments** | M-007 |
| 49365 / 49373 | Batch vs engine-suggestion match | FULL / PARTIAL / NO_MATCH | — |
| 33461 | Avg orders per trip | clubbed orders / clubbing trips | M-007 |
| 34091 | Vendor retention | cohort M-on-M | — |
| 43896 | Same-day reorder after cancellation | — | — |

**Title-vs-SQL mismatches:** the three "Fullfillment %" cards each return **5 metrics**, not one
(cancellation %, in-process %, and a clustered "unique fulfilment %" ride along). "Total Revenue"
(37413) also returns AOV, vendor cost and gross margin. → `G-022`

**⚠️ This dashboard contains no CBDF/CADF split.** All 11 cancellation cards use flat `state = 4`
with no join to `order_vehicles`. Use `dashboard/4793` instead.

---

## `dashboard/4569` — Customer Dashboard

**Collection:** "Part Truck Load". **Tabs:** Overall, New/Repeat, Business/Personal, Retention,
Poor Customer Retention, Conversion, First-time User Metrics.
**Filters:** start_date / end_date · frequency (Day/Week/Month) · customer_category
(Business/Personal) · pickup_city / drop_city / route_name · order_type · granularity.

| Card | Name | Computes | Feeds |
|---|---|---|---|
| 38287 | Customer Distribution | `COUNT(DISTINCT customer_mobile)` per period, `state='3'`; new/retained/reactivated | **closest analog to NSM** — `M-001` |
| 39117 | Business Customer Distribution | as above, business-filtered | `M-001` |
| 39149 / 39150 | Business vs Personal customer % | segment shares | `T-020` |
| 38283 | Revenue per Customer | — | — |
| 39101 | AOV (overall / business / personal) | — | `M-008` |
| 38619 / 44080 | Orders per Customer | — | — |
| 39118 | Repeat Purchase Rate | **lifetime** order count >1 through end of period — *rewritten 2026-08-14, was intra-period ≥2* | `G-154` |
| 39107 / 39149 | New vs Repeat % | **binary, lifetime-based** | `G-023` |
| 35397 / 44086 | Cohort Retention M0–M12 | — | `M-011` |
| 43406 / 44088 | Aggregate M1/M3/M6/M12 Retention | — | `M-011` |
| 39104 | Monthly Churn % | grain **hardcoded to month**, ignores `{{frequency}}` | `G-024` |
| 38900 | "LTO" customer cohorts | order-count buckets — **period-bound, not lifetime** | `G-022` |
| 41124 / 41509 | First-acquisition thread (PTL/PNM/OS/Courier) | filters `state=3` **completed**, not "placed" | `G-022` |
| 39109 | Outstation acquisition split | — | — |
| 44410 / 44409 | VSS→Quote→BookNow session conversion | — | `M-009` |

**Business-customer rule — uniform across every segmenting card:**
`CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END` from
`prod_curated.oms_public.customers`, joined `customer_mobile = c.mobile`. See `T-020`.

**Two latent defects worth knowing:**
- Cards 35397, 39117, 43406, 44080 **hardcode** `category = 'Business'` with no template tag — the
  dashboard's Customer Category selector has **zero effect** on them. → `G-025`
- Cards 38287, 39117, 38900, 41124, 41509 reference `frequency` **unprefixed**. This resolves
  correctly today only because `orders` happens to have no `frequency` column — a latent fragility,
  not a live bug. → `G-026`

---

## `card/33519` — Ops - Orders Details

**`source_updated_at`: `2026-07-03T08:29:00Z`** · created 2025-05-26 · `database_id: 83` ·
collection "Raw tables" · native SQL · avg runtime ~7.7 s · **heavily used** (view count is in the
tens of thousands and rises continuously — a drifting counter, deliberately not recorded as a fact).

**Why it matters:** this card is the source of the verified `orders.state` enum (`T-001`),
`delivery_type` mapping (`T-006`), unit scaling (`T-010`–`T-012`), the internal-user mechanism
(`T-023`), and city = `ptl_routes.zone` (`T-024`).

**⚠️ Not a historical metric source.** It hard-bounds to `pickup_slot_start` between
`CURRENT_DATE − 1` and `CURRENT_DATE + 2`. It is an operational day-level card. Any metric claiming
33519 as its source must account for that window. → `G-027`

**Parameters:** route_name · city · pickup_slot_start · is_repeated_order · delivery_type ·
VEHICLE_REGISTRATION_NUMBER · is_test (**default False**) · order_id · batch_id · order_status · pickup_date.

**`is_repeated_order`** = same `customer_mobile`, same IST pickup date, both `state != 4`, and both
pickup **and** drop within `HAVERSINE(...) < 0.1` (~100 m). This is an **operational duplicate-booking
flag** — *not* the "repeat user share" metric of the review. Name collision. → `G-028`

---

## `dashboard/4793` — canonical cancellation (D5)

Outside the originally-scoped surfaces; read on explicit owner instruction to resolve CBDF/CADF.

| Card | `source_updated_at` | `<60s` exclusion |
|---|---|---|
| 43237 | 2025-11-27T09:19:28Z | yes — numerator only |
| 43242 / 47673 / 47674 | 2025-11-27T09:19:28Z | yes — numerator only |
| **42683** (Funnel tab) | 2025-11-18T10:09:14Z | **none** — same metric name, different logic |

Full formulas in [metrics.md](./metrics.md) `M-005` / `M-006`.

**Three defects recorded, none resolved:**
1. Internal inconsistency — 42683 vs the other four on `<60s`. → `G-001`
2. `exclude_60_sec` has **no default** and is used bare rather than `[[optional]]`. → `G-001`
3. The CBDF/CADF cards carry **no `is_test` binding**, unlike sibling cancellation cards on the same
   dashboard — test-order exclusion is inconsistent. → `G-006`

**`card/49366`** — the D5 reconciliation counterpart. It is **not a like-for-like check**: it divides
by *that reason-bucket's own cancellations* rather than placed orders, joins on `o.external_id`
rather than `o.id`, and has no `<60s` logic. → `G-001`
