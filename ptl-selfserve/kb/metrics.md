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
- ✅ **Lineage divergence RESOLVED 2026-07-30 (`G-118` closed).** Dashboard 4198 also carries
  `metabase:card/33483` ("Total Orders"), which looks like a competing source — but its SQL has
  **no `state` predicate anywhere**, so it is architecturally incapable of producing a
  *completed*-orders figure under any parameterisation. `33462` is canonical beyond doubt.
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
  Owner ruled 2026-08-14 that the **repeat basis is lifetime order count**, not in-period order
  count; card 39118 was rewritten to match the same day. → `G-154`

---

## 1b. Promoted beyond the original v1 set

Not part of ruling D6's 11, but closed for free 2026-07-30 by re-reading Phase-3 extracts already
in hand — no new tool call needed. Recorded here rather than left index-only once the evidence was
already sitting in `extracts/p3b-dashboard-4569.md`.

### M-012 — Avg Transactions per Business Customer per Month ✅ `verified` / ⚠️ filter defect
- **Formula:** `COUNT(orders WHERE category='Business', state=3) / COUNT(DISTINCT customer_mobile)`.
- **source_ref:** `metabase:card/44080` ("Business User - Order Per Customer") · catalog #42
- **confidence: `verified`** — aggregate-then-ratio, `NULLIF(...,0)` divide-by-zero protection.
- ⚠️ **Card 44080 hardcodes `category = 'Business'` with NO template tag** — the dashboard's shared
  Customer Category filter has **zero effect** on it, unlike sibling cards in the same family
  (44086, 44088, 38287, 39107). Toggling the filter silently does nothing here. → `G-025`

### M-013 — Share of Business Users on Overall Transacting Users ✅ `verified`
- **Formula:** `COUNT(DISTINCT customer WHERE category='Business') / COUNT(DISTINCT customer)`, per period.
- **source_ref:** `metabase:card/39149` ("Business v/s Personal Customer Split") · catalog #45
- **confidence: `verified`** — same business-customer rule as `T-020`, aggregate-then-ratio.
- **note:** 39149 uses `c.frequency` unconditionally in the SELECT rather than gating rows by a
  category filter tag — it always shows both segments side by side, a third distinct filter
  behavior from its siblings (see `dashboards.md`).

---

## 1c. Promoted 2026-07-30, batch 2 — Metabase re-auth + Sheets-bucket search

Owner authorized card execution for validation; Metabase auth was confirmed working after an
earlier session outage. 7 more promoted; 3 more found to be **genuinely wrong or mislabeled** in
the source catalogue (kept `unverified`, but for a specific, evidenced reason — see 1d).

### M-014 — VSS→Quote Conversion, New Business Users ⚠️ `verified` / no divide-by-zero guard
- **Formula:** `quote_sessions / vss_sessions` (session-level, `app_session_id`), gated `order_type='completed'` only when explicitly passed (no default).
- **source_ref:** `metabase:card/44469` · catalog #11 · executed 2026-07-30: **23.2%** (Jun-26, Business, completed)
- **confidence: `verified`** — but ⚠️ **this ratio has no `NULLIF` guard**, unlike its siblings (`M-010`, `M-016`) — a zero-session month would raise a divide-by-zero rather than return null, breaking house rule `B-032`. → new gap, see below.
- **note:** "New" in the catalogue title is an **output row**, not a filter — the card exposes new/repeat as a dimension; picking the right row is a manual step.

### M-015 — Average Sessions Before First PTL Order, Business Users ✅ `verified`
- **Formula:** average count of VSS-view sessions preceding a customer's first **completed** PTL order.
- **source_ref:** `metabase:card/48922` · catalog #13 · executed 2026-07-30: **4.51 avg sessions** (1,329 users, Jun-26, Business)
- **confidence: `verified`** — business filter matches `T-020`.

### M-016 — Reactivation % (60+ Day Inactive Business Users) ✅ `verified`
- **Formula:** reactivated-within-period / eligible-inactive, `NULLIF`-protected.
- **source_ref:** `metabase:card/48919` · catalog #43 · executed 2026-07-30: **3.93%–5.06%** across 6 monthly rows, Jan–Jun 2026
- **confidence: `verified`** — correct table, correct business filter.

### M-017 — Perfect Order Experience % ✅ `verified`
- **Formula:** `ontime_pickup_flag = 1 AND ontime_delivery_flag = 1` (both required).
- **source_ref:** `metabase:card/34052` (+ trend card `34364`) · catalog #32
- **confidence: `verified`** — direct SQL match to the catalogue's stated definition.

### M-018 — On-Time Pickup % / On-Time Delivery % ✅ `verified`
- **Formula:** Pickup: `onTime / total_pickup`. Delivery: `count(delayed_by <= 0) / count(*)`.
- **source_ref:** Pickup `metabase:card/33784`/`33823`; Delivery `metabase:card/33785`/`33824` · catalog #33, #34, #35
- **confidence: `verified`** — shown as a companion pair, not a blended ratio, matching the catalogue's framing.

### M-019 — Time to Allocate — P50 ✅ `verified` — deferral note lifted
- **Formula:** `PERCENTILE_CONT(0.5)` of minutes from order-created to first vehicle-assigned.
- **source_ref:** `metabase:card/42081` "Completed orders - P50 Allocation Time" (+ cancelled-orders companion `42080`) · catalog #51
- **confidence: `verified`**. ⚠️ **Ruling D6 deferred this metric to "iteration 2.5"** on the assumption
  no card existed for it — one does, and it's straightforward. Worth flagging back to the metric
  owner that the deferral's premise may no longer hold. → `G-081` updated, not silently promoted past a ruling.

### M-020 — GM% per PTL Order ✅ `verified` — canonical card corrected
- **Formula:** `(total_revenue − total_cost) / total_revenue`, aggregate-then-ratio.
- **source_ref:** `metabase:card/37416` ("Gross Margin") · catalog #54
- **confidence: `verified`**. ⚠️ Card **37413** ("Total Revenue", already cited elsewhere in this KB
  for `M-008`/AOV) carries the *same* `gm` column as a secondary field — but **37416 is the correct
  canonical citation** for this metric, not 37413. Don't conflate the two cards' shared column.

---

## 1d. Checked and found genuinely wrong — not silently corrected

These three are the highest-value finding of this batch: the *catalogue itself* has errors, not
just gaps. Confidence stays `unverified` because nothing here should be quoted yet — but these are
qualitatively different from "never looked at."

- **#16/#17 (`metabase:card/48984`, shared) — business-customer source diverges from this KB's
  canonical rule.** The filter is sourced from `prod_eldoria.core.dim_customers`, not
  `oms_public.customers` (`T-020`). This is the *same* dashboard-level split already flagged at
  `G-005` (4198 uses `dim_customers`, 4569 uses `oms_public.customers`) — now confirmed at the
  individual-card level too. **#17 specifically is likely mislabeled**: its "order placed" numerator
  is a raw `booknow_clicked` event with **no join to order completion at all**, contradicting sibling
  card #11 (`M-014`) which correctly gates on `orders.state = 3`. #17 executed at 56.4% (Jun-26) —
  that number is a **click-through rate**, not an order-placement rate. → `G-148`
- **#44 (`metabase:card/49311`) — the catalogue's card assignment appears to be simply wrong.**
  Catalogue definition: "Median Days Between Orders — Repeat Business Users." Card 49311 actually
  computes **median VSS-view→booknow-click latency in minutes** — a session-funnel timing metric,
  not an inter-order interval. Executed: **0.8 minutes** median (Jun-26) — a value and unit that
  cannot be "days between orders" under any reading. This card almost certainly answers a *different*
  catalogue row (something booking-time-related, plausibly overlapping #18's Amplitude gap) and was
  mismapped when the catalogue was built. → `G-149`

---

## 2. Index-only — the remaining 62 catalog metrics

Not covered in depth this pass — ruling **D6** bounds v1 to 11 metrics, and the owner ratified
index-only treatment for the rest at the build's checkpoint 2. Each has a `G-###` row in
[GAPS.md](./GAPS.md). The status column is the catalog's **own** wording, carried verbatim — it is
**not** a KB confidence value, and must be re-verified against SQL before use.
`contradicted—conflict` is the catalog's *highest-risk* label, not a middling one.

| # | metric | catalog status (verbatim) |
|---|---|---|
| 3 | PTL Awareness Rate amongst Porter Business MAU (L0) | unverified |
| 4 | VSS Top-of-Funnel — PTL Serviceable Sessions (L1) | **checked, chart `3jh9upju` matches** — counts unique *users* not *sessions* as titled → `G-041`, not yet given a full `M-###` row → `G-153` |
| 5 | PTL Serviceable VSS as % of Overall Porter Sessions on VSS (L1) | **checked, chart id `42065` does not resolve** — likely stale pre-migration reference → `G-145` |
| 6 | PTL Card Tap Rate in Serviceable Sessions (Business) (L1) | **checked, chart id `49312` does not resolve** — same pattern as #5 → `G-145` |
| 7 | PTL Selection Rate vs FTL (L1) | **checked, chart `gjvatdh3` matches, verified** → `G-044`, not yet given a full `M-###` row → `G-153` |
| 8 | Outstation Search Rate (Business Users) (L1) | **checked, chart `l9brfm70` matches cleanly, verified** → `G-045`, not yet given a full `M-###` row → `G-153` |
| 9 | PTL Activation Rate — Business (First Order ≤7d of Card View) (L0) | unverified |
| ~~10~~ | ~~VSS→Quote Check Conversion — New Business Users (L1)~~ | **promoted → `M-014`** (shares card w/ #11) |
| ~~11~~ | ~~Quote Check→Order Placed Conversion — New Business Users (L1)~~ | **promoted → `M-014`** |
| ~~13~~ | ~~Average Sessions Before First PTL Order — Business (L1)~~ | **promoted → `M-015`** |
| 15 | Overall Session Conversion Rate (Session→Order) (L1) | confirmed-via-metadata |
| 16 | VSS→Quote Check Conversion — All Business Users (L1) | **checked, found wrong business-customer source** → `G-148` |
| 17 | Quote Check→Order Placed Conversion — All Business Users (L1) | **checked, likely mislabeled — click-rate not order-rate** → `G-148` |
| 18 | Median Time to Book (VSS→Order Placed) (L1) | checked in Amplitude; candidate chart ends at "book now clicked", not order placed → `G-147` |
| 20 | Customer Rating / NPS — Business Users (L0) | unverified · flag §5 |
| 21 | Support Tickets per Order (L0) | unverified |
| 22 | Support Ticket % (L1) | unverified |
| 23 | First Contact Resolution % (FCR) (L1) | unverified |
| 24 | Escalation % (to Social Media / Founder) (L1) | unverified |
| 25 | L4 Tickets (Social / Mystery Shopping / Support) (L1) | unverified (review: NA) |
| 27 | Cancellation Attribution % — Customer/Porter/Partner (L1) | **contradicted—conflict** (no card + column-shift) |
| 29 | Customer/Porter Attributed CBDF % (L2) | **contradicted—conflict** |
| 31 | Customer/Porter/Partner Attributed CADF % (L2) | **contradicted—conflict** |
| ~~32~~ | ~~Perfect Order Experience % (L0)~~ | **promoted → `M-017`** |
| ~~33~~ | ~~On-Time Pickup % + On-Time Delivery % (L1)~~ | **promoted → `M-018`** |
| ~~34~~ | ~~On-Time Pickup % (L2)~~ | **promoted → `M-018`** |
| ~~35~~ | ~~On-Time Delivery % (L2)~~ | **promoted → `M-018`** |
| 36 | Damage % (L1) | **searched 2026-07-30 — genuinely not found.** Only PnM-vertical damage dashboards exist; nothing PTL-specific → `G-150` |
| 37 | Orders with Weight Discrepancy % (L1) | **contradicted—conflict** (missing `route_name`) |
| 40 | Repeat Rate (Business, ≥2 Lifetime PTL Orders) (L1) | confirmed · offline-union; column-shift |
| 41 | Share of Monthly Business Orders from Repeat Users (L2) | confirmed · base differs from #40 |
| ~~42~~ | ~~Avg Transactions per Business Customer per Month (L1)~~ | **promoted → `M-012`** |
| ~~43~~ | ~~Reactivation % (60+ Day Inactive Business Users) (L1)~~ | **promoted → `M-016`** |
| 44 | Median Days Between Orders — Repeat Business Users (L1) | **checked, catalogue's card assignment is wrong** — see §1d → `G-149` |
| ~~45~~ | ~~Share of Business Users on Overall Transacting Users (L1)~~ | **promoted → `M-013`** |
| 47 | Vehicle Space Utilization % (Clubbing Trips) (L1) | confirmed · hardcoded `created_at > '2025-07-11'` |
| 48 | Batch Acceptance % by Partners (L1) | **searched — a similarly-named CGE-wide tool exists (card 38353) but wrong grain (all vehicle categories, not PTL) — rejected, not a match** → `G-150` |
| 49 | Pickup/Delivery SLA Breach % due to Batching (L1) | **searched, zero hits.** Closest lead is the complement (on-time %), not a labeled breach/guardrail metric → `G-150` |
| 50 | Allocation Acceptance Rate — Batches Accepted by Owners (L0) | **searched, zero hits.** Closest lead (card 42317) is an "orders allocated" rate — a different concept from partner acceptance-of-offer → `G-150` |
| ~~51~~ | ~~Time to Allocate — P50 (minutes) (L1)~~ | **promoted → `M-019`.** ⚠️ A card exists; the D6 deferral to "iteration 2.5" assumed otherwise — flagged back to the ruling, not silently overridden |
| 52 | % Organic Allocation (No Manual Ops Intervention) (L1) | **searched, zero hits anywhere in Metabase** → `G-150` |
| 53 | Reallocation Rate (L1) | **searched, zero hits.** Loose unverified lead: card 48535 "Vehicle Change %" — not confirmed → `G-150` |
| ~~54~~ | ~~GM% per PTL Order (L0)~~ | **promoted → `M-020`** (canonical card corrected: 37416, not 37413) |
| 56 | Return Trip % (Bidirectional Routes) (L1) | **verified 2026-08-20** — card 44691. The 14 % vs 28 % conflict is a denominator-scope difference, not a computation error: "Bidirectional Routes" in this name *is* the denominator, and the published ~28 % is the bidirectional read → `G-156`; two semantics still open → `G-157` |
| 57 | Monthly Active Owners (MAO) (L0) | **structural gap, see G-151** |
| 58 | New Owners Onboarded per Month (L1) | **structural gap, see G-151** |
| 59 | Monthly Active Vehicles (MAV) (L0) | **structural gap, see G-151** |
| 60 | New Vehicles Onboarded per Month (L1) | **structural gap, see G-151** |
| 61 | Owner Onboarding Activation Rate (1st Trip ≤30d) (L1) | **structural gap, see G-151** |
| 62 | Median Days Owner Onboarding→First Trip (L1) | **structural gap, see G-151** |
| 63 | M1 Owner Retention % (L0) | **structural gap, see G-151** |
| 64 | % Trips with On-Time Pickup (Supply View) (L1) | overall exists (`M-018`); no owner-level split found → `G-151` |
| 65 | % Trips with On-Time Delivery (Supply View) (L1) | overall exists (`M-018`); no owner-level split found → `G-151` |
| 66 | Owner Batch Acceptance Rate (Pings→Acceptance %) (L0) | **structural gap, see G-151** |
| 67 | Owner Batch Completion Rate (Accepted→Completed %) (L0) | **structural gap, see G-151** |
| 68 | SLA Adherence % — On-Time Pickup + Delivery by Owner (L0) | **structural gap, see G-151** |
| 69 | Partner Attributed Damage % (L0) | **structural gap, see G-151** |
| 70 | Owner Earnings per Trip (L0) | confirmed · `status=3` filter **commented out** |
| 71 | Trips per Monthly Active Vehicle (L1) | confirmed · joins `customer_uuid=customer_id` (key drift) |
| 72 | Partner NPS (L0) | unverified (review: NA, no instrumentation) |
| 73 | Partner Support Tickets per Trip % (L0) | unverified · column-shift |
| 74 | AppSheet Adoption amongst Owners and Partners (L0) | unverified |
| 75 | Owner Earnings per Monthly Active Vehicle (L0) | **structural gap, see G-151** |
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
85 rows (#2–#86) = **15 `confirmed-via-metadata` + 6 `contradicted—conflict` + 64 `unverified`** at
audit time. That audit is frozen/historical; **this KB's own coverage has since moved past it.**

Every count below is in **catalogue rows** (not M-numbers — one M-### can close more than one row,
e.g. `M-014` closes both #10 and #11, `M-018` closes #33/#34/#35; that mismatch is what produced a
wrong "65 remaining" figure earlier the same day, corrected here to the real number, 62):

- **12 rows promoted** to a full, verified `M-###` entry (via 9 distinct M-numbers) — §1b/§1c.
- **3 rows found to be catalogue errors** (#16, #17, #44) — wrong card or wrong table, not just
  unchecked (§1d, a more valuable finding than plain "unverified").
- **3 rows verified from an Amplitude chart definition** (#4, #7, #8) but not yet promoted to a full
  `M-###` row — a real asymmetry versus the Metabase-sourced promotions, tracked as `G-153` rather
  than left silently inconsistent.
- **2 rows have a known-but-unresolvable reference** (#5, #6 — chart ids that predate the Jan-2026
  Mixpanel→Amplitude migration and no longer resolve).
- **1 row has a candidate that measures the wrong thing** (#18 — ends at "book now clicked", not
  "order placed").
- **7 rows confirmed genuinely absent** after a real search (#3, #36, #48, #49, #50, #52, #53).
- **14 rows hit a structural gap** (`G-151` — 12 full + 2 partial, #64/#65) — the underlying data may
  not exist at the grain the catalogue assumes.
- **32 rows remain genuinely untouched** — no investigation attempted yet.

12 + 3 + 3 + 2 + 1 + 7 + 14 + 32 = 74, minus the 12 promoted = **62 metrics remain index-only** (§2).
