# metrics.md — PTL metric definitions

`M-###` rows. Schema and rules: see [CONTRIBUTING.md](./CONTRIBUTING.md). Entry point: [CONTEXT.md](./CONTEXT.md).
All rows `last_verified: 2026-07-29`.

**Scope (ratified):** the **11 v1 metrics** (ruling D6) get full treatment below. The remaining
**74** catalog metrics are index-only — see §2 — with one `G-###` row each in [GAPS.md](./GAPS.md).

**Read this before quoting any formula:** apply `B-030` (aggregate-then-ratio) — aggregate numerator
and denominator at the cut you need, *then* divide. Never average daily ratios.

---

## 1. The 11 v1 metrics

### M-001 — North Star: Monthly Transacting Business Customers ✅ `verified` / ⚠️ inherited defects
- **Definition (owner ruling):** unique business customers completing ≥1 PTL order in a calendar month.
- **Implementation:** `metabase:card/39117` ("Business Customer Distribution"), column
  **`ACTIVE_CUSTOMERS`** · `source_updated_at: 2026-07-14T10:37:29Z` · `database_id: 73`
  ```sql
  CASE WHEN frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END AS category
  ... AND category = 'Business' AND state = '3' ...
  DATE_TRUNC({{frequency}}, o.created_at) AS period          -- template default: Month
  final_orders AS (SELECT * FROM online_filtered_orders UNION SELECT * FROM offline_filtered_orders)
  SELECT period, COUNT(DISTINCT customer_mobile) AS Active_customers ... GROUP BY 1
  ```
- **confidence: `verified`** — **RECONCILED 2026-07-30 by execution.** Run with
  `start_date=2026-03-01`, `end_date=2026-04-30`, `frequency=Month`, the card returns
  **Mar-26 = 1879** and **Apr-26 = 2247**, matching the reported figures **exactly**. `G-003` closed.
- ⚠️ **Because the match is exact, the reported number inherits this card's two defects:**
  1. **The internal-user exclusion is applied to the ONLINE leg only.** The offline (gsheet-sync)
     CTE has no `ptl_internal_users` filter, so the NSM reported to leadership **includes internal
     offline orders** and is inflated by an unknown amount. → `G-141`
  2. **The offline base is hardcoded IN — there is no toggle.** No parameter or `[[optional]]`
     block can isolate the online-only leg, so **ruling D3's dual-base requirement cannot be met
     from this card without forking the query.** → `G-142`
- ⚠️ **Windowing artifact:** `RETAINED_CUSTOMERS` / `REACTIVATED_CUSTOMERS` read **0** when the query
  window has no prior period (Mar-26 shows 0 retained purely because the window starts 2026-03-01).
  Only `ACTIVE_CUSTOMERS` is safe to read from a narrow window. → `G-143`
- **Card defaults are `start_date=2025-05-01`, `end_date=2025-08-31`** — running it unmodified
  returns four 2025 months, not the current one. Always set the dates explicitly.
- **The engine still has no implementation:** the prototype registers `nsm_txn_business_customers`
  with SQL plan `"authored"`, emitting no column. Card ✅, engine ❌. → `G-010`
- **Reported values:** see the snapshot in [business.md](./business.md) (Rule 6).
- **aliases:** NSM, North Star, monthly transacting business customers
- **note:** D4 supersedes an older "30-day repeat rate" NSM still present in stale reference docs.

### M-002 — Completed Orders (business, monthly) ✅ `verified`
- **Formula:** `COUNT(DISTINCT orders.external_id) WHERE state = 3`, business-filtered per `T-020`.
- **source_ref:** `repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L59` · catalog #19 ·
  `metabase:card/33462` (the card named by **both** the catalog and the registry)
- **confidence: `verified`**
- ⚠️ **Lineage divergence — do not collapse it.** Dashboard 4198 also carries `metabase:card/33483`
  ("Total Orders", `COUNT(DISTINCT external_id)`, online+offline union), which computes the same
  shape but is **not** the card the catalog or registry cites. Which is canonical is unresolved
  → `G-118`.
- **note:** offline-union base per ruling D3 — must be shown **both** incl. and excl. offline (`T-071`).
- **Reported values:** see the snapshot in [business.md](./business.md).

### M-003 — Total Fulfilment % ✅ `verified`
- **Formula:** `100 × completed / placed`, where `completed = state 3` and `placed = all states`.
- **source_ref:** `metabase:card/33485`, `metabase:card/37419` (reported byte-identical) · catalog #26
- **confidence: `verified`** · **aliases:** ff, total FF, fulfilment rate
- A separate **"excl-60s" variant** is a *different metric*, not a restatement: cards
  33466 / 43238 / 37104 compute `completed / (all − orders cancelled within 60s of creation)`,
  **dropping those orders from the denominator**. The prototype names this variant but never
  implements it. → `G-002`, `G-035`
- **Reported values:** see the snapshot in [business.md](./business.md).

### M-004 — Effective Fulfilment % ⚠️ `unverified`
- **Prototype formula:** `100 × completed / (placed − cbdf_cancels)` — the code itself flags this as
  an **approximation**.
- **source_ref:** `repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py` · catalog #38
- **confidence: `unverified`** — the prototype's denominator subtracts **CBDF cancellations**, while
  dashboard 4198's nearest equivalent subtracts **sub-60-second cancellations**. Different exclusions,
  similar intent, not reconciled. → `G-002`
- **note:** catalog records offline **excluded** here, versus offline-union for M-003 — the two
  fulfilment metrics do not share a base.

### M-005 — CBDF % (Cancelled Before Driver Found) ✅ `verified` (mechanic) / ⚠️ residuals
- **Canonical formula** (`metabase:card/43237`, `source_updated_at: 2025-11-27T09:19:28Z`):
  ```sql
  100 * COUNT(DISTINCT CASE WHEN vehicle_name IS NULL AND state = 4
                AND (within_1_cancel IS NULL OR {{exclude_60_sec}} = 'NO')
              THEN order_id END) / placed_orders
  ```
- **Driver-found signal:** `LEFT JOIN order_vehicles ov ON o.id = ov.order_id AND ov.is_active`,
  then `vehicle_name IS NULL`.
- **Denominator:** `placed_orders` = unconditional `COUNT(DISTINCT order_id)` — i.e. **% of demand**,
  matching house formula `B-060`. Not a share of cancellations.
- **source_ref:** `metabase:card/43237` on `metabase:dashboard/4793` (canonical per `DECISION_LOG:D5`) · catalog #28
- **Internal users ARE excluded** — hardcoded in the `base` CTE:
  `AND o.customer_mobile NOT IN (SELECT DISTINCT mobile FROM partload_analytics.ptl_internal_users)`.
  There is no `is_test` *parameter*, which is a different thing from no *exclusion* (`T-023`).
- ⚠️ **Not yet promoted.** D5 carries 65% confidence and is gated; D6 states CBDF/CADF promote
  **only after** the 4793↔49366 reconciliation gate, which `G-001` shows may not be satisfiable as
  written. `verified` below refers to the mechanic, not to promotion status.
- **confidence: `verified`** for the classification mechanic. **Three residuals stay open:**
  1. `<60s` is excluded from the **numerator only** — *not* dropped from the denominator, *not*
     reclassified. This differs from the `<60s` treatment in M-003. → `G-002`
  2. Card **42683 on the same dashboard applies no `<60s` exclusion at all** — 4793 contradicts
     itself for the same metric name. → `G-001`
  3. `exclude_60_sec` has **no default** and is used bare (not `[[optional]]`); its value on first
     load is not determinable from metadata. → `G-001`
- **vs card 49366** (the D5 reconciliation counterpart): **different ratios.** 49366 computes
  CBDF ÷ *that reason-bucket's own cancellations*, joins on `o.external_id` not `o.id`, and has no
  `<60s` logic. Not a like-for-like check. → `G-001`
- **vs prototype** (`state=4 AND vehicle_assigned=0`): conceptually equivalent; the prototype has a
  literal `vehicle_assigned` column where 4793 derives it via join + null-check.
- **Absent entirely from dashboard 4198** — all 11 of its cancellation cards use flat `state = 4`.

### M-006 — CADF % (Cancelled After Driver Found) ✅ `verified` (mechanic) / ⚠️ residuals
- **Formula:** identical to M-005 with `vehicle_name IS NOT NULL`.
- **source_ref:** `metabase:card/43237` · `source_updated_at: 2025-11-27T09:19:28Z` · catalog #30
- **confidence: `verified`** (mechanic); **same three residuals as M-005**, same un-promoted status,
  same hardcoded internal-user exclusion → `G-001`, `G-002`
- **Reported values:** see the snapshot in [business.md](./business.md). ⚠️ the source states a
  "+1.2pp" movement but its own figures give 13.81 − 12.99 = **0.82pp** → `G-117`.

### M-007 — Avg Orders per Trip (clubbing) ✅ `verified` / ⚠️ filter gap
- **Formula:** `clubbed_orders / clubbing_trips`, over batches containing ≥2 orders.
- **source_ref:** `repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py` · `metabase:card/33461` · catalog #46
- **confidence: `verified`** (formula) — but the prototype's `trips_sql` applies **neither the
  internal-user exclusion nor the business-user filter**, unlike every other builder. → `G-010`
- **note:** clubbing population scope differs across 4198 cards — 33460 counts all non-cancelled
  states, while 47540 / 48449 / 49365 restrict to completed only. → `G-011`

### M-008 — AOV (Average Order Value) ⚠️ `unverified`
- **Prototype formula:** `SUM(revenue WHERE state = 3) / completed_orders`.
- **source_ref:** `repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py` · catalog #55
- **confidence: `unverified`** — **three competing revenue bases coexist** on dashboard 4198:
  `estimated_fare` (card 33706), weight-discrepancy-revised `final_fare` (card 37413), and
  `total_fare + discount` (card 52889). → `G-004`
- **Date basis RESOLVED 2026-07-30:** card 33706 uses **`updated_at`** — the catalog was right and
  the prototype's `created_at` is wrong; fix the prototype (`G-007` closed). But the date basis
  **also splits within the family**: 33706 and 52889 use `updated_at`, **37413 uses `created_at`**.
  So AOV has 3 revenue bases **×** 2 date bases. → `G-135`
- Fares are stored in **paise** (`T-010`). **Reported values:** see [business.md](./business.md).

### M-009 — Business Session Conversion % ✅ `verified` / ⚠️ definition clash
- **Formula:** `100 × orders / sessions`, business identified by `ptl_fe_events.user_type = 'Business'`.
- **source_ref:** `repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L76` · catalog #14
- **confidence: `verified`** (formula)
- ⚠️ **This metric uses a different "business" definition from every other metric here:**
  `ptl_fe_events.user_type = 'Business'`, versus `oms_public.customers.frequency IN (1,2,3,4)`
  (`T-020`). Whether the two populations agree is unverified. → `G-012`
- ✅ **`both_bases = False` here is CORRECT, not a defect.** Ruling **D6's build note explicitly
  exempts this metric** from the dual-base requirement. Do not "fix" it. → `G-119`
- **Reported values:** see [business.md](./business.md).

### M-010 — New Business Users Acquired (monthly, first order) ⚠️ `unverified`
- **Intended:** count of business users placing their first PTL order in the month.
- **source_ref:** catalog #12 (`confirmed-via-metadata`) · `metabase:card/48921`
- **confidence: `unverified`** — the prototype registers it as `simple` but its SQL plan **downgrades
  to `"authored"`; no first-order logic is implemented.** Catalog and code disagree. → `G-010`

### M-011 — M1 Business User Retention % ✅ `verified` / ⚠️ base gap
- **Formula:** `100 × m0_retained / m0_business_users`.
- **source_ref:** `repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py` · catalog #39
- **confidence: `verified`** (formula) — but the builder **emits only the `excl_offline` base**
  despite the registry declaring `both_bases = True`. **This is a registry-vs-builder mismatch, not
  a D3 violation** — retention is not among the metrics D3 enumerates. → `G-010`
- **note:** dashboard 4569 carries **two incompatible retention taxonomies** —
  new/retained/reactivated (38287, 39117) vs a binary lifetime-based new/repeat (39107, 39149). → `G-023`

---

## 2. Index-only — the remaining 74 catalog metrics

Not covered in depth this pass — ruling **D6** bounds v1 to 11 metrics, and the owner ratified
index-only treatment for the rest at the build's checkpoint 2. Each has a `G-###` row in
[GAPS.md](./GAPS.md). The status column is the catalog's **own** wording, carried verbatim — it is
**not** a KB confidence value, and must be re-verified against SQL before use.
`contradicted—conflict` is the catalog's *highest-risk* label, not a middling one.

| # | metric | catalog status (verbatim) |
|---|---|---|
| 3 | PTL Awareness Rate amongst Porter Business MAU (L0) | unverified |
| 4 | VSS Top-of-Funnel — PTL Serviceable Sessions (L1) | unverified |
| 5 | PTL Serviceable VSS as % of Overall Porter Sessions on VSS (L1) | unverified |
| 6 | PTL Card Tap Rate in Serviceable Sessions (Business) (L1) | unverified |
| 7 | PTL Selection Rate vs FTL (L1) | unverified |
| 8 | Outstation Search Rate (Business Users) (L1) | unverified |
| 9 | PTL Activation Rate — Business (First Order ≤7d of Card View) (L0) | unverified |
| 10 | VSS→Quote Check Conversion — New Business Users (L1) | unverified |
| 11 | Quote Check→Order Placed Conversion — New Business Users (L1) | unverified |
| 13 | Average Sessions Before First PTL Order — Business (L1) | unverified |
| 15 | Overall Session Conversion Rate (Session→Order) (L1) | confirmed-via-metadata |
| 16 | VSS→Quote Check Conversion — All Business Users (L1) | unverified |
| 17 | Quote Check→Order Placed Conversion — All Business Users (L1) | unverified |
| 18 | Median Time to Book (VSS→Order Placed) (L1) | unverified |
| 20 | Customer Rating / NPS — Business Users (L0) | unverified · flag §5 |
| 21 | Support Tickets per Order (L0) | unverified |
| 22 | Support Ticket % (L1) | unverified |
| 23 | First Contact Resolution % (FCR) (L1) | unverified |
| 24 | Escalation % (to Social Media / Founder) (L1) | unverified |
| 25 | L4 Tickets (Social / Mystery Shopping / Support) (L1) | unverified (review: NA) |
| 27 | Cancellation Attribution % — Customer/Porter/Partner (L1) | **contradicted—conflict** (no card + column-shift) |
| 29 | Customer/Porter Attributed CBDF % (L2) | **contradicted—conflict** |
| 31 | Customer/Porter/Partner Attributed CADF % (L2) | **contradicted—conflict** |
| 32 | Perfect Order Experience % (L0) | unverified · column-shift |
| 33 | On-Time Pickup % + On-Time Delivery % (L1) | unverified (review: Apr corrupted) |
| 34 | On-Time Pickup % (L2) | unverified |
| 35 | On-Time Delivery % (L2) | unverified |
| 36 | Damage % (L1) | unverified |
| 37 | Orders with Weight Discrepancy % (L1) | **contradicted—conflict** (missing `route_name`) |
| 40 | Repeat Rate (Business, ≥2 Lifetime PTL Orders) (L1) | confirmed · offline-union; column-shift |
| 41 | Share of Monthly Business Orders from Repeat Users (L2) | confirmed · base differs from #40 |
| 42 | Avg Transactions per Business Customer per Month (L1) | unverified |
| 43 | Reactivation % (60+ Day Inactive Business Users) (L1) | unverified (review: low base) |
| 44 | Median Days Between Orders — Repeat Business Users (L1) | unverified |
| 45 | Share of Business Users on Overall Transacting Users (L1) | unverified |
| 47 | Vehicle Space Utilization % (Clubbing Trips) (L1) | confirmed · hardcoded `created_at > '2025-07-11'` |
| 48 | Batch Acceptance % by Partners (L1) | unverified (review: NA) |
| 49 | Pickup/Delivery SLA Breach % due to Batching (L1) | unverified · column-shift |
| 50 | Allocation Acceptance Rate — Batches Accepted by Owners (L0) | unverified (review: NA) |
| 51 | Time to Allocate — P50 (minutes) (L1) | unverified — **deferred to iteration 2.5** |
| 52 | % Organic Allocation (No Manual Ops Intervention) (L1) | unverified (review: NA, engine Q3) |
| 53 | Reallocation Rate (L1) | unverified (review: NA) |
| 54 | GM% per PTL Order (L0) | unverified · Finance cross-thread; column-shift |
| 56 | Return Trip % (Bidirectional Routes) (L1) | confirmed-via-metadata |
| 57 | Monthly Active Owners (MAO) (L0) | unverified |
| 58 | New Owners Onboarded per Month (L1) | unverified |
| 59 | Monthly Active Vehicles (MAV) (L0) | unverified |
| 60 | New Vehicles Onboarded per Month (L1) | unverified |
| 61 | Owner Onboarding Activation Rate (1st Trip ≤30d) (L1) | unverified |
| 62 | Median Days Owner Onboarding→First Trip (L1) | unverified (review: NA) |
| 63 | M1 Owner Retention % (L0) | unverified |
| 64 | % Trips with On-Time Pickup (Supply View) (L1) | unverified |
| 65 | % Trips with On-Time Delivery (Supply View) (L1) | unverified |
| 66 | Owner Batch Acceptance Rate (Pings→Acceptance %) (L0) | unverified |
| 67 | Owner Batch Completion Rate (Accepted→Completed %) (L0) | unverified |
| 68 | SLA Adherence % — On-Time Pickup + Delivery by Owner (L0) | unverified |
| 69 | Partner Attributed Damage % (L0) | unverified |
| 70 | Owner Earnings per Trip (L0) | confirmed · `status=3` filter **commented out** |
| 71 | Trips per Monthly Active Vehicle (L1) | confirmed · joins `customer_uuid=customer_id` (key drift) |
| 72 | Partner NPS (L0) | unverified (review: NA, no instrumentation) |
| 73 | Partner Support Tickets per Trip % (L0) | unverified · column-shift |
| 74 | AppSheet Adoption amongst Owners and Partners (L0) | unverified |
| 75 | Owner Earnings per Monthly Active Vehicle (L0) | unverified · blank definition in source |
| 76 | Uptime % — PartLoad-Ktor & PartLoad-Job Servers (L0) | unverified · flag §5 |
| 77 | Latency P95 — PartLoad-Ktor & PartLoad-Job (L1) | unverified |
| 78 | Booking Details Page Load Latency P95 (L2) | unverified (sheet-only) |
| 79 | Check Serviceability API Latency P95 (L2) | unverified (sheet-only) |
| 80 | Quote Generation API Latency P95 (L2) | unverified (sheet-only) |
| 81 | Booking Creation API Latency P95 (L2) | unverified (sheet-only) |
| 82 | Error Rate — PartLoad-Ktor & PartLoad-Job (L1) | unverified |
| 83 | Booking Details Page Load Error Rate (L2) | unverified · column-shift |
| 84 | Check Serviceability API Error Rate (L2) | unverified (sheet-only) |
| 85 | Quote Generation API Error Rate (L2) | unverified (sheet-only) |
| 86 | Booking Creation API Error Rate (L2) | unverified (sheet-only) |

**Catalog totals** (per `DECISION_LOG` §Drift 2, verified by parsing all 85 rows):
85 rows (#2–#86) = **15 `confirmed-via-metadata` + 6 `contradicted—conflict` + 64 `unverified`.**
Note the risk ordering: the **6 contradicted rows are the highest-risk bucket**, not a middle tier —
they are metrics whose sources actively disagree. **70 of 85 are not confirmed.**
11 are covered in full above; **74 are index-only here.**
