# metrics.md — HCV metric definitions

`M-###` entries. Schema and rules: [CONTRIBUTING.md](./CONTRIBUTING.md). Entry point: [CONTEXT.md](./CONTEXT.md).
All rows `last_verified: 2026-08-14`.

**Scope.** The **12** metrics of the reconciled query pack get full entries in §1. Every other HCV
metric across `dashboard/1882`, `dashboard/4146` and the Sheet is index-only in §2, with one
`G-###` each. The 12 is derived, not chosen — one entry per distinct **(measure, source lineage)**
pair, grain variants as dimensions, `pack:§6` recorded as a projection.

> **Read before quoting any formula.** Apply `B-030` (aggregate-then-ratio) — aggregate numerator and
> denominator at the cut you need, *then* divide. Never average daily ratios and **never average
> percentiles** (`B-031`). And read `M-001`'s denominator warning first: it applies to `M-004`,
> `M-006` and `M-007` too.

**Every entry carries `store_ref`** per `D-013` — this KB is a **migration map** toward
`metric.porter.*`, so each entry states its counterpart, the delta, **and what closing the delta
would change about the reported number.** A delta without a stated consequence is not a migration plan.

---

## §1 The 12 pack metrics

### M-001 — Fulfilment % ⚠️ `unverified` · **NORTH STAR (L0)**
- **Definition:** share of placed HCV demand that completes.
- **Formula:** `completed_orders / total_placed` — see `M-003` and `M-002`.
- **Implementation:** `repo@20f6416:hcv-selfserve/hcv_metrics_queries.md#L167-L184` (`pack:§2`);
  also `#L217-L229` (`§2a`), `#L509-L523` (`§6`)
  ```sql
  agg AS (
      SELECT
          order_month, category, distance_bucket,
          COUNT(unique_id)                                     AS total_placed,
          COUNT(CASE WHEN order_status = 4 THEN unique_id END)  AS completed_orders,
  ...
      ROUND(completed_orders / NULLIF(total_placed, 0), 4)      AS ff_pct,
  ```
- **confidence: `unverified`** — the *designation* as north star is `verified` (`OWNER:2026-08-14`),
  but the formula is not: three denominators are live in production under this one name, and the
  denominator carries a structural defect (below). Designation and definition are separate claims.
- **store_ref:** `metric.porter.completion_rate` — label **"Fulfilment Rate"**, `SUM(completed_orders) / SUM(demand)`
  · owners `vinay.nadig@theporter.in`, `lfc.da@theporter.in` · approved `sandip.dogra@theporter.in` 2026-06-19
  · `T+1` daily · `source_updated_at: 2026-08-13T18:02:11Z`
- **migration:** the store's `demand` is *"orders created (completed + cancelled)"* — **the same
  concept** as the pack's `COALESCE(order_status,5) IN (4,5)`. Pack and store **agree**; the
  dashboards are what diverge (`G-031`). Closing the delta moves FF onto the OLC KPI tree where
  FF + CADF + CBDF + stockout + missed decompose to 1 of demand. **Cost:** the number shifts by the
  test-mobile share plus any non-(4,5) rows, and **the distance split is lost entirely** (`G-037`).
- **inventory_ref:** `nb1882:M005` · `nb4146:M005`
- **grain:** `§2`/`§6` month × category × distance · `§2a` month × distance
- ⚠️ **Three denominators are live in production under the name "fulfilment"** → `G-031`
- ⚠️ **The denominator contains rows that can never reach the numerator** → `G-030`. This is the
  single most important caveat in this KB; read it before quoting any FF figure.
- **Reported values:** see the snapshot in [business.md](./business.md).
- **aliases:** FF, FF %, fulfilment rate, completion %

### M-002 — Total Placed (demand base) ⚠️ `unverified`
- **Definition:** count of HCV demand units placed in the month.
- **Formula:** `COUNT(unique_id)` over rows filtered `COALESCE(order_status, 5) IN (4,5)`.
- **Implementation:** `repo@20f6416:…#L170` (`§2`), `#L217` (`§2a`), `#L511` (`§6`)
  ```sql
  WHERE m.customer_mobile <> '0000000001'
    AND m.vehicle_mapping IN ('9ft','10ft','14ft','17ft','19ft')
    AND UPPER(g.tier) = 'TIER 1'
    AND COALESCE(m.order_status, 5) IN (4, 5)
  ```
- **confidence: `unverified`** — mechanically clear, but the population it admits is contested
  (`G-030`).
- **store_ref:** `metric.porter.demand` — `SUM(demand)` on `trucks_daily_demand_summary`
  · same owners/approval as `M-001` · **not a true counterpart**
- **migration:** the store's demand is OLC-scoped and `trucks_daily_demand_summary`-sourced; the
  pack's is HCV-mart-sourced and **includes SO-only rows**. **Cost:** adopting the store metric
  **drops every SO-only demand unit** — scheduled orders never matched to a fact order — and drops
  the inline Tier-1 / 9–19ft / test-mobile scoping. Not reconcilable without a scope contract.
  `metric.porter.total_orders` is nearer in shape but is FO-only, so it structurally cannot carry
  SO-only demand. **No dbt metric is defined on `hcv_overall_demand_mart` at all** (`metrics: null`).
- **inventory_ref:** `nb1882:M001` · `nb4146:M001`
- **grain:** month × category × distance (`§2`/`§6`); month × distance (`§2a`)
- ⚠️ `T-002` — `COALESCE(order_status, 5)` makes a NULL status a **cancellation**, and on SO-only
  rows status is NULL *by construction* → `G-030`
- ⚠️ All four `dashboard/6406` cards have `-- and o.status in (4,5)` **commented out**, so their
  "Demand" is a wider population than this (`T-029`) → `G-013`
- **Reported values:** see the snapshot in [business.md](./business.md).
- **aliases:** demand, placed orders, total placed, order requests

### M-003 — Completed Orders (mart lineage) ✅ `verified`
- **Definition:** HCV demand units that completed, counted on the demand mart.
- **Formula:** `COUNT(CASE WHEN order_status = 4 THEN unique_id END)`.
- **Implementation:** `repo@20f6416:…#L172` (`§2`), `#L219` (`§2a`), `#L513` (`§6`)
  ```sql
  COUNT(CASE WHEN order_status = 4 THEN unique_id END)  AS completed_orders
  -- order_status is fo.fo_status, UN-coalesced by the mart: NULL for SO-only rows
  ```
- **confidence: `verified`** — read directly from the SQL. `order_status` is `fo.fo_status`
  **un-coalesced** (`T-001`).
- **store_ref:** `metric.porter.completed_order_count` — `SUM(completed_orders)` on
  `trucks_daily_demand_summary` · owners `vinay.nadig@`, `lfc.da@` · approved `sandip.dogra@` 2026-06-19
- **migration:** the store column carries **no visible `deleted_at IS NULL`, `order_type = 0` or
  test-mobile exclusion**, so **the count would rise** by whatever those filters currently remove.
  Sibling `completed_orders_finance` is keyed on **job-end date** rather than order-creation, which
  would shift orders across month boundaries and move FF % for reasons unrelated to fulfilment.
- **inventory_ref:** `nb1882:M002` · `nb4146:M004`
- ⚠️ **Not the same metric as `M-008`.** Same name, different object, never reconciled → `G-012`
- ⚠️ All four `6406` cards add `fo_driver_id is not null` to this numerator; the pack does not
  (`D-020`). Arithmetically equivalent only if `status = 4` implies an FO leg → `G-030`
- **Reported values:** see the snapshot in [business.md](./business.md).
- **aliases:** completed orders, completions

### M-004 — Effective Fulfilment % ⚠️ `unverified`
- **Definition:** completions as a share of demand **excluding customer-attributed cancellations**.
- **Formula:** `completed_orders / (total_placed − customer_cancelled)`.
- **Implementation:** `repo@20f6416:…#L150-L151, #L173, #L182` (`§2`); `#L205-L206, #L220, #L229` (`§2a`).
  **Dropped from `§6`.**
  ```sql
  LEFT JOIN prod_eldoria.core.dim_cancel_reasons_attribution cr
         ON m.fo_cancel_reason_id = cr.cancel_reason_id
  ...
  COUNT(CASE WHEN order_status = 5 AND LOWER(attribution) = 'customer' THEN unique_id END) AS customer_cancelled
  ...
  ROUND(completed_orders / NULLIF(total_placed - customer_cancelled, 0), 4)  AS e_ff_pct
  ```
- **confidence: `unverified`** — the pack is clear, but the only live implementation disagrees with
  it and has two competing definitions of its own.
- **store_ref:** **`none`.** `list_metrics(name="effective")` returns **0 rows**. No
  effective-fulfilment metric exists in the semantic layer.
- **migration:** nothing to migrate *to*. **`next_action`: propose `metric.porter.effective_fulfilment`**
  to `vinay.nadig@theporter.in` / `lfc.da@theporter.in` — but only after `G-034` settles which
  attribution basis is canonical, since the two live implementations disagree on the columns.
- **inventory_ref:** `nb1882:M006`
- ⚠️ **Card 28681 carries two competing E-FF definitions**, differing on **two axes at once** — the
  attribution column pair *and* the source mart. Both aliased `effective_fulfillment`; only one
  reaches the dashboard → `G-034`
- ⚠️ **`§6` drops E-FF entirely** while `§2`/`§2a` keep it, unexplained in the pack's own caveats → `G-070`
- ⚠️ Inherits `G-030` — the same denominator population as `M-001`
- **Reported values:** see the snapshot in [business.md](./business.md).
- **aliases:** E-FF, E-FF %, effective fulfilment

### M-005 — Unique Demand ✅ `verified`
- **Definition:** placed demand with cancel-and-rebook duplicates suppressed.
- **Formula:** `COUNT(CASE WHEN duplicate_order = 0 THEN unique_id END)`, duplicates per `B-062`.
- **Implementation:** `repo@20f6416:…#L258-L273` (`§3`); identical at `#L332-L347` (`§3a`) and
  `#L471-L485` (`§6`)
  ```sql
  enriched AS (
      SELECT *,
          CASE WHEN pickup_location_delta <= 100 AND drop_location_delta <= 100
                AND ordertime_delta <= 60 AND order_status = 5
               THEN 1 ELSE 0 END AS duplicate_order
      FROM flagged
  ),
  ```
- **confidence: `verified`** — the dedup logic is **byte-for-byte identical** across `§3`, `§3a` and
  `§6` (whitespace aside), confirmed line by line.
- **store_ref:** **`none`.** No demand-dedup metric exists. `metric.porter.demand` is raw demand and
  is **not** a counterpart.
- **migration:** the store number is strictly **≥** the pack's, by the count of cancel-and-rebook
  duplicates — so adopting it **inflates the denominator and deflates Unique FF %**. Closing needs a
  **new store metric**, not a swap, and that metric needs geospatial columns
  (`from/to_address_lat/long`) plus `customer_id` ordering that `trucks_daily_demand_summary` is not
  documented to carry.
- **inventory_ref:** `nb4146:M002`
- ⚠️ The `LEAD` window extends to 2026-08-02 while output is cut at 2026-08-01, so late-July orders
  dedup against successors that never appear in the result. **Deliberate** — the pack comments it as
  a buffer. Recorded so nobody "fixes" it → `G-071` (informational anti-gap)
- ⚠️ Card 28681 reads a **pre-computed** `unique_demand` from `trucks_unique_demand_summary` — a
  second, independent implementation never compared to this one → `G-035`
- **Reported values:** see the snapshot in [business.md](./business.md).
- **aliases:** unique demand, deduped demand

### M-006 — Unique Fulfilment % ⚠️ `unverified`
- **Definition:** completions as a share of **unique** demand.
- **Formula:** `completed_orders / unique_demand`.
- **Implementation:** `repo@20f6416:…#L299-L302` (`§3`), `#L361-L364` (`§3a`), `#L524` (`§6`)
  ```sql
  -- §3 / §3a  (#L300, #L362)
  COUNT(DISTINCT CASE WHEN order_status = 4 THEN unique_id END) AS completed_orders
  -- §6        (#L513)  — DISTINCT dropped, same metric name
  COUNT(CASE WHEN order_status = 4 THEN unique_id END)          AS completed
  ```
- **confidence: `unverified`** — **the pack disagrees with itself.** `§3`/`§3a` count the numerator
  `COUNT(DISTINCT CASE WHEN order_status = 4 …)`; `§6` uses `COUNT(CASE WHEN order_status = 4 …)`.
  Wherever `unique_id` repeats in `cat`, the two sections return **different numbers for the same
  metric name** → `G-070`
- **store_ref:** **`none`** — depends on `M-005`, which has none.
- **migration:** blocked behind `M-005`. Nothing to migrate to.
- **inventory_ref:** `nb1882:M007` · `nb4146:M006`
- ⚠️ Inherits `G-030`
- **Reported values:** see the snapshot in [business.md](./business.md).
- **aliases:** unique FF, unique fulfilment %

### M-007 — Allocation % ⚠️ `unverified`
- **Definition:** share of placed demand that reached a partner.
- **Formula:** `orders_allocated / total_placed`, where
  `orders_allocated = COUNT(CASE WHEN fo_driver_id IS NOT NULL THEN unique_id END)`.
- **Implementation:** `repo@20f6416:…#L171, #L180` (`§2`), `#L512, #L522` (`§6`). Pack prose,
  `#L537`: *"Allocation uses `fo_driver_id`."*
  ```sql
  COUNT(CASE WHEN fo_driver_id IS NOT NULL THEN unique_id END) AS allocated,
  ...
  ROUND(allocated  / NULLIF(total_placed, 0),  4) AS allocation_pct,
  ```
- **confidence: `unverified`** — the formula is clear; **the key is contested and the denominator
  is defective.**
- **store_ref:** `metric.porter.allocation_rate` — `count_distinct(order_id WHERE driver_id IS NOT NULL) / count_distinct(order_id)`
  on `fact_orders` · owners `thejas.ravi@`, `utkarsh.dixit@`, `sanjeev.mishra@` (domain **ALLOCATION**)
  · approved `sanjeev.mishra@` 2026-08-07 · `T+1` **hourly**
- **migration:** **two different migrations with different costs, both must be stated.**
  (a) *Key swap only* — moving to `driver_id` raises Allocation % by the SO-only share carrying a
  non-null `so_driver_id`. (b) *Adopting the store metric wholesale* — its denominator is
  `count_distinct(order_id)` on `fact_orders`, which **structurally cannot contain SO-only demand**,
  so those rows leave **numerator and denominator both**. That is a larger restatement than (a).
- **inventory_ref:** `nb1882:M004` · `nb4146:M007`
- ⚠️ **`fo_driver_id` vs `driver_id`** — `fo_driver_id` exists in **exactly one model
  platform-wide**; `driver_id` in 414. Two governance chains disagree across three source models → `G-032`
- ⚠️ **The denominator defect (`G-030`) bites hardest here** — SO-only rows are unallocatable *by
  construction*, not by outcome
- **Reported values:** see the snapshot in [business.md](./business.md).
- **aliases:** allocation %, allocated %, allocation rate

### M-008 — Completed Orders (OMS lineage) ✅ `verified`
- **Definition:** completed HCV orders counted on the OMS order master.
- **Formula:** `COUNT(DISTINCT o.id)` where `o.status = 4`.
- **Implementation:** `repo@20f6416:…#L86-L101, #L120` (`pack:§1`)
  ```sql
  FROM prod_curated.oms_public.orders o
  WHERE date(o.created_at + interval '330 minutes') >= '2026-05-01'
    AND o.deleted_at IS NULL
    AND o.order_type = 0
    AND o.customer_mobile <> '0000000001'
    AND o.status = 4
    AND g.tier = 'Tier 1'
  ```
- **confidence: `verified`**
- **store_ref:** `metric.porter.completed_order_count` — same as `M-003`'s
- **migration:** the store has **no distance dimension**, so `§1`'s entire reporting cut cannot be
  reproduced (`G-037`); tier is not a store dimension either (only `geo_region_id`). Time axis should
  agree — store `order_created_date_ist` vs pack `created_at + 330 min`.
- **inventory_ref:** `nb1882:M002`
- ⚠️ **Distinct from `M-003`** — different object, different date axis, different window bounds
  (`<= '2026-07-31'` inclusive vs `< '2026-08-01'` half-open), and **SO-only rows are absent here by
  construction** → `G-012`
- ⚠️ `§1` uses `g.tier = 'Tier 1'` (case-sensitive) while `§0`/`§2` use `UPPER(g.tier) = 'TIER 1'`
  → `G-072`
- **Reported values:** see the snapshot in [business.md](./business.md).
- **aliases:** completed orders (OMS), OMS completions

### M-009 — Revenue ✅ `verified`
- **Definition:** trip revenue on completed HCV orders, gross of Porter-borne discounts.
- **Formula:** `SUM(ceil(fare) + coupon_discount + referral_discount + subscription_discount)` over
  `fare_type = 2 AND is_current`.
- **Implementation:** `repo@20f6416:…#L102-L114, #L121` (`pack:§1`)
  ```sql
  ROUND(SUM(CASE WHEN A.fare_type = 2 AND A.is_current
       THEN ceil(A.fare) + A.coupon_discount + A.referral_discount + A.subscription_discount END),2) AS final_total_fare
  ```
- **confidence: `verified`** — and **reconciled**: the pack states revenue *"validated to match the
  OMS+SO canonical logic to the rupee for May–Jul (SO branch added only ~18 zero-revenue orders in
  Jul)"* (`#L536`). Units are **rupees**, not paise (`T-030`).
- **store_ref:** `metric.porter.revenue` — `SUM(revenue)` on `trucks_daily_demand_summary`, whose
  measure `daily_revenue` is documented *"ceil(fare) + coupon + referral + subscription discounts"*
  · owners `vinay.nadig@`, `lfc.da@` · approved `sandip.dogra@` 2026-06-19
- **migration:** **the per-order fare construction is token-for-token identical**, including the
  absence of any `/100`. The delta is population and grain only. **Cost: the rupee figure should not
  move on definitional grounds** — this is the cheapest migration in the set. What is lost is the
  distance bucket (`G-037`) and the explicit `deleted_at`/`order_type`/test-mobile trio.
- **inventory_ref:** `nb1882:M016` · `nb4146:M014`
- ⚠️ **Gross booking value, not net** — discounts are added back. `nb1882` flags this on the same
  formula. Do not read it as net revenue → `G-033`
- ⚠️ Cards 55587/55626/55541 fall back to `coalesce(est_total_fare, est_fare)` for schedule orders
  with no OMS fare row — a source the pack **deliberately excludes** ("Revenue is OMS-only")
- **Reported values:** see the snapshot in [business.md](./business.md).
- **aliases:** revenue, GBV, gross booking value

### M-010 — AOV ⚠️ `unverified`
- **Definition:** average revenue per completed HCV order.
- **Formula:** `div0(SUM(final_total_fare), COUNT(DISTINCT o.id))` — `M-009 / M-008`.
- **Implementation:** `repo@20f6416:…#L115-L127` (`pack:§1`)
  ```sql
  COUNT(DISTINCT o.id)    AS completed_order,
  SUM(f.final_total_fare) AS revenue,
  div0(SUM(f.final_total_fare), COUNT(DISTINCT o.id)) AS aov
  FROM oms o
  LEFT JOIN fare f ON o.id = f.order_id
  LEFT JOIN dist d ON o.id = d.id
  ```
- **confidence: `unverified`** — **five** AOV formulas are live: three on `1882`, one on `4146`, plus the store.
- **store_ref:** `metric.porter.average_order_value` —
  `SUM(total_revenue_without_registration_income) / NULLIF(SUM(comp_orders), 0)` on
  `finance_mis_india_calculated_metrics` · owners `arpanbarnwal@`, `mahiteshpoojary@`,
  `finanalytix@` (domain **finance business**) · approved `satyavijay.sawarkar@` 2026-05-18 · **`T-1`** daily
- **migration: `NOT EQUIVALENT`.** This is the one metric where the store is a **genuinely different
  number**, not a differently-filtered one. Three divergences compound: the numerator adds
  **cashback, premium_discount, porter_gold and rewards_coins** on a **GST-stripped** base; the
  denominator is keyed on **job-end date**, not order-creation, so months assign differently; and the
  source is Finance MIS, not OMS. **The correct analogue — `revenue / completed_order_count` on the
  OLC mart, matching the pack's own definitions — does not exist.**
  **`next_action`: propose it** as a `ratio` metric (numerator `revenue`, denominator
  `completed_order_count`, domain `olc`), plus a distance dimension on the mart (`G-037`).
- **inventory_ref:** `nb1882:M016a` · `nb4146:M015`
- ⚠️ **Two governed AOVs would disagree if both were quoted** — Finance-MIS (gross-of-all-discounts,
  job-end-date) vs an OLC-lineage ratio (fare_type-2, order-created-date) → `G-033`
- **Reported values:** see the snapshot in [business.md](./business.md).
- **aliases:** AOV, average order value

### M-011 — Time to Accept (p50 / p75 / p90) ✅ `verified`
- **Definition:** seconds from customer order placement to partner acceptance.
- **Formula:** `PERCENTILE_CONT(0.50 | 0.75 | 0.90) WITHIN GROUP (ORDER BY time_to_accept_sec)`,
  filtered `BETWEEN 0 AND 3600`.
- **Implementation:** `repo@20f6416:…#L388-L392, #L404-L412` (`pack:§4`)
  ```sql
  DATEDIFF(
      second,
      m.order_time,
      CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP_NTZ(m.fo_trip_accepted_time))
  ) AS time_to_accept_sec
  ```
- **confidence: `verified`** — read directly from the SQL.
- **store_ref:** `metric.porter.avg_time_to_accept_seconds` —
  `total_accept_seconds / accepted_notifications` on `fact_notification_services_order_acceptances_v2`
  · owner `sanjeev.mishra@` (domain **ALLOCATION**) · approved 2026-07-23
- **migration: `NOT EQUIVALENT` — three axes differ at once.** The pack starts the clock at **order
  placement**; the store at **notification sent**. The pack reports **percentiles**; the store a
  **mean**. The pack's unit is **one order**; the store's is **one notification batch**.
  **Stated precisely: the pack measures customer-perceived wait; the store measures driver
  responsiveness.** The pack's interval **strictly contains** the store's — the gap is the
  matchmaking latency the store's clock never sees. **A mean cannot be reconciled to a p50 by any
  adjustment**, and the store declares no outlier guard where the pack caps at 3600s → `G-036`
- **inventory_ref:** `nb4146:M026` (allocation-time family)
- ⚠️ **`metabase:card/55503` is NOT the reconciliation target** — its clock is
  `TRIP_ACCEPTED_TIME → TRIP_START_ENTRY_TIMESTAMP`, i.e. **arrival**, a third clock.
  **`metabase:card/55527` is** — but it aliases the result `allocation_time_minutes` while computing
  **seconds**, and applies no upper guard → `G-073`
- ⚠️ `§4` has **no order-status filter** — accepted-then-cancelled orders are in scope
- ⚠️ `§4`'s category is the **exclusive** `CASE` form with no 10ft overall row, unlike `§2`/`§3`/`§6`
  (`T-024a`)
- **Reported values:** see the snapshot in [business.md](./business.md).
- **aliases:** ATA, time to accept, acceptance latency, allocation time

### M-012 — MAP (Monthly Active Partners) ✅ `verified`
- **Definition:** distinct HCV Tier-1 partners with at least one qualifying login-day in the month.
- **Formula:** `COUNT(DISTINCT driver_id)` over driver-days passing `SUM(business_login_hours) > 0.5`.
- **Implementation:** `repo@20f6416:…#L423-L442` (`pack:§5`)
  ```sql
  GROUP BY l.day, l.driver_id, g.geo_region_id
  HAVING SUM(l.business_login_hours) > 0.5
  ```
- **confidence: `verified`** — read directly from the SQL.
- **store_ref:** `metric.porter.map` — `COUNT(DISTINCT driver_id) WHERE total_completed_orders >= 1`
  on `mart_partner_daily_performance_summary` · owner `ankush.lohani@theporter.in` (domain `plc`)
  · approved `sandip.dogra@` 2026-06-24 · `T+1` daily
- **migration: definition change only — no new modelling.** The store's source model **already
  carries `business_login_hours`**, plus `date`, `driver_id`, `geo_region_id`, `tier` and
  `vehicle_mapping`; and the pack's own source `fact_active_partners` is a **direct upstream** of it.
  Only a **measure declaration** is missing. **`next_action`: declare a login-based measure in
  `models/semantics/mart_partner_daily_performance_summary_semantic.yml`**, owner `ankush.lohani@`.
  **Cost, and it is not small:** (a) the store column is deduplicated to the **first-ranked vehicle
  per driver-day** while the pack **sums across** vehicles, so a literal re-implementation qualifies
  **fewer** driver-days; (b) adopting the store's *order-based* definition instead **reduces** MAP,
  and MAP is the denominator of `payout_per_active`, `orders_per_active` and `login_hrs_per_active`,
  so all three **rise** for unchanged numerators → `G-023`
- **inventory_ref:** `nb1882:M041` (DAP family) · `nb4146:M016`
- ⚠️ **Three login thresholds are in play and none is governed for HCV** — pack `> 0.5
  business_login_hours`; store sibling `total_login_days` `> 0 total_login_hours`; pack prose *"at
  least 1 hour"*. `list_metrics(name="dap")` returns **0 rows** — the DAP the pack anchors to has no
  store counterpart → `G-038`
- ⚠️ The inner `GROUP BY` includes `geo_region_id` but the `SELECT` does not, so the `> 0.5` test is
  applied **per region**, not per driver-day. A driver splitting a day across two regions may fail
  both halves while passing the combined day → `G-074`
- **Reported values:** see the snapshot in [business.md](./business.md).
- **aliases:** MAP, monthly active partners, active partners

---

## §1d Checked and found genuinely wrong — not silently corrected

Rows where **a source is in error**, held at their stated confidence for a specific, evidenced
reason. Per [CONTRIBUTING.md](./CONTRIBUTING.md) §8.5 these are recorded, never quietly fixed.

| what | the error | evidence | gap |
|---|---|---|---|
| **The pack's own caveat list** | States *"sections 1–4 depend on `mbr_mapping_v2`"*. **`§6` depends on it too** — every section except `§5` does | `#L532` vs `#L494`, `#L505` | `G-011` |
| **`pack:§6` vs `§3`/`§3a`** | `§6` drops `DISTINCT` on the completed count, so `unique_ff_pct` **disagrees between sections of the same pack** | `#L300` vs `#L513` | `G-070` |
| **`pack:§1` vs `§0`/`§2`** | Tier predicate is case-sensitive `g.tier = 'Tier 1'` in `§1`, defensive `UPPER(g.tier) = 'TIER 1'` elsewhere | `#L100` vs `#L42`, `#L154` | `G-072` |
| **`metabase:card/55527`** | Column aliased `allocation_time_minutes` and commented *"(minutes)"* while the expression computes **seconds**. Only the alias and comment are wrong | card native SQL | `G-073` |
| **`metabase:card/38998`** | Hardcodes `Vehicle_Category in ('9ft','10ft','14ft','17ft')` — **silently excludes 19ft** while offering `19ft` in its own filter widget | card native SQL | `G-075` |
| **`metabase:card/33212`** | Numerator and denominator come from **different tables at different grains** joined on date, so `FF_bh` is **not bounded at 1 by construction**. Also mixes `login_date <= end` against `created_at < end` | card native SQL | `G-076` |
| **`nb4146` (the Deep Dive itself)** | Its summary says **34** unique metrics; its own design callout says *"~26 of **33**"*. The source contradicts itself | `nb4146` summary vs callouts | `G-077` |
| **`metric.porter.cadf`** | Its `driver_id IS NOT NULL` claim lives in **prose only** — `calculation_logic` is just `SUM(cadf)`, which cannot evidence it | `store:metric.porter.cadf` | `G-032` |

---

## §2 Index — every other HCV metric

**98 rows.** One per un-promoted metric, deduped across `nb1882` (54), `nb4146` (34) and
`gsheet:HCV_Metrics_DD` (**90 rows — counted, not estimated**). Each carries one `G-###` in
`GAPS.md` class G (`D-010`), sharing a class-level `next_action`.

**Gap ids are allocated mechanically: index row *N* ↔ `G-(200 + N)`.** So row 1 is `G-201`, row 98
is `G-298`. This is checkable by script rather than by hand, and no id can drift.

> ⚠️ **`source-status` is the source's OWN wording, carried verbatim — `Pending`, `contested`,
> `Argus P1`, `GAP`. It is NOT a KB confidence value** ([CONTRIBUTING.md](./CONTRIBUTING.md) §4).
> Where `level` or `Doshi` differ between sources, **all values are listed in source order** rather
> than one being picked — the divergence is the finding.

**Dedup rules:** `R1` filter→dimension · `R2` bucketed CASE→bucket dimension · `R3` ratio parented
to base · `R4` genuinely different SQL kept distinct.

| # | metric | src | inventory_ref | level | Doshi | source-status (verbatim) | rule |
|---|---|---|---|---|---|---|---|
| 1 | Hourly Demand Share % | 1882 | `nb1882:M001a` | L3 | Health | — | R3 |
| 2 | Repeat Demand % | 4146 | `nb4146:M003` | L2 | Usage | "No governed store equivalent - GAP" | R3 |
| 3 | Average Daily Completed Orders | 1882 | `nb1882:M002a` | L2 | Outcome | — | R3 |
| 4 | **Fulfilment % — business-hours basis** | 4146 | `nb4146:M005`-variant (card 33212) | — | — | "Three denominators presented as 'fulfilment'" | R4 |
| 5 | **Fulfilment % — hourly, non-distinct** | 1882 | `nb1882:M005`-variant (card 39084) | — | — | "a third non-distinct-count hourly form" | R4 |
| 6 | **Allocation % — business-hours basis** | 4146 | `nb4146:M007`-variant (card 33212) | — | — | "Three formulas/sources." | R4 |
| 7 | Cancelled Orders | 1882 | `nb1882:M003` | L2 | Health | "contested status taxonomy in the legend" | R4 |
| 8 | Cancellation % | 1882, 4146 | `nb1882:M010` · `nb4146:M009` | L2/L2 | Health | "Card 32670 has NO level0_mapping filter - it is NOT scoped to HCV" | R1 |
| 9 | CBDF % | 1882, 4146, gs | `nb1882:M012` · `nb4146:M010` · `gsheet:15` | L3/L2/L0 | Health/Health/Usage | "Governed store equivalent EXISTS" · "Pending; Argus P1" | R1+R2 |
| 10 | CADF % (by attribution) | 1882, 4146, gs | `nb1882:M013` · `nb4146:M011` · `gsheet:19,20,21,22,88,89,90` | L3/L2/L0–L1 | Health/Health/Usage | "CONTESTED denominator" · "Pending; Argus P1" | R2+R1 |
| 11 | Missed Order % | 1882, 4146, gs | `nb1882:M008` · `nb4146:M013` · `gsheet:16` | L2/L2/L1 | Health/Health/Usage | "Governed store equivalents EXIST and align" | R1 |
| 12 | Missed Order due to Notification Undelivery % | 4146 | `nb4146:M013a` | L3 | Health | "No governed store equivalent - GAP" | R3 |
| 13 | Stockout % | 1882, 4146, gs | `nb1882:M009` · `nb4146:M012` · `gsheet:17` | L2/L2/L1 | Health/Health/Usage | "No standalone governed store metric - GAP (store folds stockout into cbdf)" | R1 |
| 14 | Cancellation Time Distribution (by scope) | 1882, 4146, gs | `nb1882:M047` · `nb4146:M027` · `gsheet:18,23,24,25` | L3/L3/L1 | Health/Health/Usage | "Status-semantics conflict" · "Pending; Argus P2" | R1+R2 |
| 15 | Batch Acceptance % (by batch) | 4146, gs | `nb4146:M008` · `gsheet:11` | L3/L1 | Health/Usage | "No governed store equivalent - GAP" | R2 |
| 16 | Persistence Gain % | gs | `gsheet:12` | L1 | Usage | "Pending; Argus P2" | R4 |
| 17 | Time to Allocate Post Tray Listing P50/P90 | gs | `gsheet:13` | L1 | Usage | "Pending; Argus P1" | R4 |
| 18 | Orders in Tray P50/P90 | gs | `gsheet:14` | L1 | Usage | "Pending; Argus P2" | R4 |
| 19 | Matchmaking Funnel Size (by stage) | 4146, gs | `nb4146:M025` · `gsheet:38,40,41,42` | L3/L1–L2 | Health | "No governed store equivalent - GAP" | R1+R2 |
| 20 | Notified Partners per Batch P50/P90 | gs | `gsheet:39` | L2 | Health | "Pending; Argus P3" | R4 |
| 21 | Partner Pings (sent/accepted/rejected) | 4146 | `nb4146:M021` | L2 | Health | "No governed store base for pings found - GAP" | R4 |
| 22 | Partner Acceptance Rate | 4146, gs | `nb4146:M022` · `gsheet:10` | L2/L0 | Health/Usage | "MAJOR FINDING… Contested definition" | R1 |
| 23 | Order Rejection % (notification level) | 4146 | `nb4146:M023` | L2 | Health | "No governed store equivalent - GAP" | R4 |
| 24 | Notification Delivery / Undelivery Rate | 4146, gs | `nb4146:M024` · `gsheet:5` | L2/L0 | Health | "No governed store equivalent - GAP" | R1+R3 |
| 25 | Time Between Partner Pings P50/P90 | gs | `gsheet:9` | L1 | Health | "Pending; Argus P3" | R4 |
| 26 | **Daily Active Partners (DAP)** | 1882, 4146, gs | `nb1882:M041` · `nb4146:M016` · `gsheet:26,71` | L1/L1/L0 | Adoption | "CONTESTED" (login-based vs order-based) | R1 |
| 27 | Completed Orders per DAP per Day | 1882, gs | `nb1882:M042` · `gsheet:7,67` | L2/L0–L1 | Usage/Usage,Outcome | "Average-of-averages… cannot be reconciled to the weighted form" | R1 |
| 28 | Supply-to-Demand Ratio (DAP per Demand) | 4146 | `nb4146:M017` | L2 | Ecosystem | "No governed store equivalent - GAP"; "Bug: uses unique_demand in the numerator" | R4 |
| 29 | Under-utilised Driver Count (by state) | 4146 | `nb4146:M018` | L3 | Health | "CONTESTED definitions of 'zero orders'… operator-precedence bug" | R2 |
| 30 | Business Login Hours Distribution P50/P75 | 4146, gs | `nb4146:M019` · `gsheet:6` | L3/L0 | Usage | "Related governed store base metric: `metric.porter.total_login_hours`" | R1 |
| 31 | Partner Idle Time excl. Dry Run P50/P90 | gs | `gsheet:8,72` | L1 | Usage/Adoption | "Pending; Argus P2" | R1 |
| 32 | Partner Utilization % / Unutilised Liquidity % | 4146, gs | `nb4146:M020` · `gsheet:37` | L2/L1 | Health/Outcome | "No governed store equivalent - GAP"; "Date-boundary bug" | R3+R1 |
| 33 | Partner Earnings per Business Login Hour | 4146 | `nb4146:M031` | L2 | Ecosystem | "Bug: vehicle mapping joined on vehicle_category" | R4 |
| 34 | Partner Daily Earnings Distribution P50/P90 | 4146, gs | `nb4146:M032` · `gsheet:36,64` | L3/L0–L1 | Ecosystem/Outcome | "No governed store equivalent - GAP" | R1 |
| 35 | Avg Earnings per Completed Order | gs | `gsheet:68` | L1 | Outcome | "Pending; Argus P2" | R3 |
| 36 | Partner Incentive Amount (by component) | 1882 | `nb1882:M021` | L3 | Ecosystem | "the earnings-to-goodwill join is INNER on period… the timeline under-reports" | R2 |
| 37 | Cross-Serviceable Driver Count | 4146 | `nb4146:M033` | L3 | Ecosystem | "Ignores all dashboard filters" | R4 |
| 38 | Drivers Onboarded | 1882, gs | `nb1882:M039` · `gsheet:43` | L1/L0 | Ecosystem/Outcome | "Contested source: `dim_drivers.date_of_join` vs `mart.driver_first_last_order_date`" | R1 |
| 39 | Partner Activation % | 1882, gs | `nb1882:M040` · `gsheet:46` | L2/L1 | Ecosystem/Outcome | "Pending; Argus P1" | R1 |
| 40 | Active Days per Month per Partner P50/P90 | gs | `gsheet:70` | L1 | Usage | "Pending; Argus P2" | R4 |
| 41 | % Partners Active 20+ Days per Month | gs | `gsheet:69` | L0 | Usage | "Pending; Argus P1" | R3 |
| 42 | Partner Retention % (by month offset) | gs | `gsheet:65,66` | L0 | Outcome | "Pending; Argus P1–P2" | R1 |
| 43 | % Suspended Partners per DAP | gs | `gsheet:77` | L1 | Satisfaction | "Pending; Argus P2" | R3 |
| 44 | Noticeboard Engagement Rate % | gs | `gsheet:73` | L2 | Adoption | "Pending; Argus P3" | R3 |
| 45 | Wallet Withdrawal Rate % | gs | `gsheet:74` | L2 | Adoption | "Pending; Argus P3" | R3 |
| 46 | Non-Order TPO Rate | gs | `gsheet:75` | L0 | Satisfaction | "Pending; Argus NA" | R4 |
| 47 | Non-Order Sprinklr Sessions | gs | `gsheet:76` | L1 | Satisfaction | "Pending; Argus NA" | R4 |
| 48 | Signup-to-Milestone Conversion % (15d) | gs | `gsheet:45,47,48,49` | L1–L2 | Outcome | "Pending; Argus P1–P2" | R2 |
| 49 | Doc Upload to Driver Creation % (15d) | gs | `gsheet:50` | L2 | Outcome | "Pending; Argus P2" | R4 |
| 50 | Signup to Active Driver Rate % | gs | `gsheet:44` | L0 | Outcome | "Pending; Argus P1" | R4 |
| 51 | Onboarding Channel Mix % | gs | `gsheet:51` | L2 | Outcome | "Pending; Argus P3" | R2 |
| 52 | E2E Onboarding TAT P90 (days) | gs | `gsheet:52` | L0 | Usage | "Pending; Argus P1" | R4 |
| 53 | Onboarding Stage TAT P75 (days) | gs | `gsheet:53,54,55` | L1 | Usage | "Pending; Argus P2" | R1 |
| 54 | Onboarding Support Requests | gs | `gsheet:56` | L0 | Satisfaction | "Pending; Argus NA" | R4 |
| 55 | Onboarding City Office Visits | gs | `gsheet:57` | L1 | Satisfaction | "Pending; Argus P2" | R4 |
| 56 | Time to First Login Post Onboarding P50/P90 | gs | `gsheet:58` | L0 | Adoption | "Pending; Argus P1" | R4 |
| 57 | First Order Completion Rate % post onboarding | gs | `gsheet:59,60,61` | L0–L1 | Adoption | "Pending; Argus P1–P2" | R1 |
| 58 | Time to First Order Acceptance P50/P90 | gs | `gsheet:62` | L1 | Adoption | "Pending; Argus P2" | R4 |
| 59 | New Partner Login Hours, first 15d P50/P90 | gs | `gsheet:63` | L1 | Adoption | "Pending; Argus P2" | R4 |
| 60 | Trip Breach Orders (count, by type) | 1882 | `nb1882:M014` | L3 | Health | "Uses plain COUNT (not COUNT DISTINCT), so it double-counts" | R2 |
| 61 | Trip Breach % (by breach type) | 1882, gs | `nb1882:M014a` · `gsheet:78,79,80,81` | L3/L0–L1 | Health/Satisfaction | "Not a clean ratio of M014… lineages diverge" | R2+R3 |
| 62 | Actual Waiting Time P50/P90 | 1882 | `nb1882:M015` | L3 | Health | "Major scope bug: the filter `estimated_waiting_time <> actual_waiting_time` drops every order where actual equalled the estimate" | R4 |
| 63 | ATA Distribution (mins) | 1882, 4146, gs | `nb1882:M046` · `nb4146:M028` · `gsheet:82` | L3/L2/L0 | Health/Health/Satisfaction | "IST double-shift bug" · "No governed store equivalent - GAP" | R1 |
| 64 | ETA / Estimated Dry-Run Time Distribution | 1882, 4146 | `nb1882:M045` · `nb4146:M030` | L3/L2 | Health | "Card names say 'ETA' but the SQL uses `estimated_google_dry_run_mins`" | R1+R4 |
| 65 | Dry-Run Distance Distribution (km) | 1882, 4146, gs | `nb1882:M044` · `nb4146:M029` · `gsheet:31` | L3/L2/L0 | Health/Health/Satisfaction | "Contested source and population" | R1+R4 |
| 66 | Partner Pickup Delay Time P50/P90 | gs | `gsheet:32,84` | L1 | Satisfaction | "Pending; Argus P1–P2" | R1 |
| 67 | % Orders with Pickup Delay | gs | `gsheet:83` | L1 | Satisfaction | "Pending; Argus P1" | R3 |
| 68 | Avg Order Rating | gs | `gsheet:85` | L0 | Satisfaction | "Pending; Argus P1" | R4 |
| 69 | Payment Success % | gs | `gsheet:86` | L1 | Health | "Pending; Argus P2" | R4 |
| 70 | Payment Online/Offline Split % | gs | `gsheet:87` | L2 | Usage | "Pending; Argus P3" | R2 |
| 71 | Trip Fare | 1882 | `nb1882:M017` | L2 | Outcome | "Contested definition: raw `SUM(trip_fare)` vs `SUM(ceil(trip_fare))`" | R4 |
| 72 | Discount Amount (by component) | 1882 | `nb1882:M018` | L3 | Outcome | "Contested definition… 28688 includes cashback while 28691/28692 exclude it" | R2 |
| 73 | Surge Amount (by component) | 1882 | `nb1882:M019` | L3 | Outcome | "No total-surge measure is emitted; only the two components." | R2 |
| 74 | Surge % of Revenue | 1882 | `nb1882:M019a` | L3 | Outcome | "output is a fraction 0-1, not a scaled percentage" | R3 |
| 75 | Fare Component per Order | 1882 | `nb1882:M020` | L3 | Outcome | "Denominator inconsistency" | R2 |
| 76 | Fare Component % of AOV | 1882 | `nb1882:M020a` | L3 | Outcome | "Components need not sum to 100%" | R3 |
| 77 | ARPU | 1882 | `nb1882:M023` | L2 | Outcome | "Inherits the contested revenue source"; "mislabelled 'average_transactions'" | R3 |
| 78 | Active Customers | 1882 | `nb1882:M022` | L1 | Adoption | "Duplicate source pairs: 28647/29811, 29553/29559" | R1 |
| 79 | Orders per Customer | 1882 | `nb1882:M024` | L2 | Usage | "Pervasive mislabel: columns named 'wallet_share' actually compute orders-per-customer" | R3 |
| 80 | Order Share by Customer Status % | 1882 | `nb1882:M025` | L3 | Usage | "Non-additive." | R2+R3 |
| 81 | Median Time Between Orders (days) | 1882 | `nb1882:M026` | L3 | Usage | "Bug: the median is taken over a cumulative sum of gaps" | R4 |
| 82 | Average Time Between Orders (days) | 1882 | `nb1882:M027` | L3 | Usage | "Title/display mismatch" | R4 |
| 83 | Unique Booking Sessions | 1882 | `nb1882:M028` | L1 | Usage | "Contested source: 28199/28677 read mart while 28537/30140 read `prod_curated`" | R1 |
| 84 | Converted Sessions | 1882 | `nb1882:M029` | L2 | Usage | "Consistent definition across cards" | R3 |
| 85 | Session Conversion % | 1882 | `nb1882:M030` | L2 | Usage | "Scaling inconsistency"; "card 30140 has a grain bug" | R3 |
| 86 | Customer-Level Session Conversion % | 1882 | `nb1882:M031` | L2 | Usage | "Distinct source lineage" | R4 |
| 87 | Sessions Created (by Click Band) | 1882 | `nb1882:M032` | L3 | Usage | "Contested source"; "Not HCV-scoped by default" | R2 |
| 88 | Session Creation Share by Click Band % | 1882 | `nb1882:M032a` | L3 | Usage | "Inherits the contested source split from M032" | R2+R3 |
| 89 | Session Conversion by Click Band % | 1882 | `nb1882:M033` | L3 | Usage | "Inconsistent 'click' definition" | R4 |
| 90 | Cohort Size (Acquired Customers) | 1882 | `nb1882:M034` | L1 | Adoption | "Hard-coded cohort date windows override the dashboard date filter" | R1 |
| 91 | Monthly Cohort Retention % | 1882 | `nb1882:M035` | L1 | Adoption | "Contested source across the cohort family"; "asymmetric scoping" | R1+R3 |
| 92 | Cross-Sell Base Customers | 1882 | `nb1882:M036` | L2 | Ecosystem | "Trucks (28660) = HCV+LCV whereas HCV (28665) = HCV only" | R1 |
| 93 | Category Cross-Sell Customers | 1882 | `nb1882:M037` | L2 | Ecosystem | "`vehicle_category` is effectively mandatory" | R1 |
| 94 | Cross-Sell to Category Share % | 1882 | `nb1882:M038` | L2 | Ecosystem | "Bug: the 2W card (28661) divides without a NULLIF guard" | R3 |
| 95 | HCV Allocation System Uptime % | gs | `gsheet:1` | L0 | Health | "Pending; Argus P1" — **DataDog** | R4 |
| 96 | HCV Allocation Error Rate % | gs | `gsheet:2` | L1 | Health | "Pending; Argus P1" — **DataDog** | R4 |
| 97 | HCV Allocation API Latency P95 | gs | `gsheet:3` | L1 | Health | "Pending; Argus P1" — **DataDog** | R4 |
| 98 | HCV Allocation L4 Tickets | gs | `gsheet:4` | L1 | Health | "Pending; Argus NA" — **Jira** | R4 |

### §2a Merges a reader may contest

Recorded so they can be overturned, per [CONTRIBUTING.md](./CONTRIBUTING.md) §6.

- **Row 32 — Partner Utilization % ↔ Unutilised Liquidity %.** Merged as complements. If
  "utilisation" means on-trip *time* and "unutilised liquidity" means *login hours with no orders*,
  these have different denominators and must be split.
- **Row 22 — Acceptance Rate.** Names align, but by *grain* `gsheet:10` matches `nb4146:M023`
  (notification-event level), not `nb4146:M022` (ping-count level). Merged on name; needs a
  definition owner.
- **Row 14 — pre- and post-allocation cancellation timing collapsed into one row.** If they have
  different owners, split.
- **Row 10 — CADF attribution merged across three different denominators** — share of total demand
  (card 32670), share of CADF (the governed metrics), share of *allocated* orders (`gsheet:89/90`).
  One row, three denominators. Resolve before promoting.

### §2b Source rows that are internally contradictory

- **`gsheet:78` "Fare breach"** — *"P50/P90 % HCV orders with fare exceeding quoted threshold."*
  A P50/P90 **of a percentage** is not well-formed. Indexed as a rate; if breach *magnitude* was
  meant, it needs its own row.
- **`gsheet:31` "Dry Run"** — one row spanning **two measures** (*"P50 and P90 dry run
  distance/**time**"*). Both inventories treat distance and time as distinct. Attached to row 65,
  cross-referenced on row 64, counted once.
- **`gsheet:88` vs `gsheet:19`** — "HCV CADF %" and "HCV OLC CADF %" describe the same measure from
  two domains. Merged; the Sheet should decide whether the domain split is real.
- **Sheet column alignment** — all 90 rows carry 27 cells, but `Status` lands at index 22 for 84
  rows and index 21 for 6. It resolves unambiguously to **`Pending` for all 90**; no other value
  appears in the sheet.

### §2c A taxonomy divergence that needs one owner

The Sheet systematically assigns **higher levels** (more L0s) than either inventory, and files
experience metrics under **Satisfaction** where both Notion docs use **Health**. Both inventories
independently state their dashboards carry **no Satisfaction metric at all**; the Sheet supplies
**18**. Level or Doshi category conflict across sources for **20** merged metrics — every value is
listed in source order above rather than reconciled. **This is a real taxonomy divergence, not a
data error.** → `G-060`

---

## §3 Reconciliation

**Two units are counted here and they are not interchangeable** — this is the distinction PTL
shipped wrong (`D-015`).

### Source rows → KB rows

```
nb1882 unique metrics                 54   (source-stated: 23 base + 31 derived)
nb4146 unique metrics                 34   (source-stated: 16 base + 18 derived)
gsheet:HCV_Metrics_DD rows            90   (counted)
                             raw =   178

− source rows covered by full entries −26   nb1882 ×10 · nb4146 ×9 · gsheet ×7
                                    = 152
− cross-source merges                 −47   (21 merge groups spanning 2+ sources)
− within-sheet merges                 −10   (6 merge groups inside the sheet)
                                    =  95
+ variant rows split out               +3   business-hours FF · hourly FF · business-hours Allocation %
                             INDEX =   98
```

**178 − 26 − 57 + 3 = 98** ✓

### The KB's own totals

| | count |
|---|---|
| Full `M-###` entries (§1) | **12** |
| Index rows (§2) | **98** |
| **Total distinct HCV metrics in this KB** | **110** |

> ⚠️ **12 full entries ≠ 12 source metric identities.** They retire **11** — **MAP has no metric row
> in any of the three sources.** It appears only inside `nb4146:M016`'s notes, as the governed-store
> counterpart cited against DAP. The pack implements it; no inventory catalogues it. So: **12
> `M-###` numbers, 11 source identities, 26 source rows.** Never state one of those as another.

### Partition of the full entries

| | n | which |
|---|---|---|
| `store_ref` **named** | **9** | `M-001` `M-002` `M-003` `M-007` `M-008` `M-009` `M-010` `M-011` `M-012` |
| `store_ref: none` — must be **proposed** | **3** | `M-004` · `M-005` · `M-006` |
| **9 + 3 = 12** ✓ | | |

Of the 9 named, **one is not a true counterpart** — `M-002`'s `metric.porter.demand` is OLC-scoped
and cannot carry SO-only demand. Counted as named; the delta is stated in its entry.

| migration verdict | n | which |
|---|---|---|
| Identical definition — cheapest | 1 | `M-009` Revenue |
| Definition change, no new modelling | 1 | `M-012` MAP |
| Differently-filtered same measure | 4 | `M-001` `M-002` `M-003` `M-008` |
| Key/population contested | 1 | `M-007` Allocation % |
| **`NOT EQUIVALENT`** | 2 | `M-010` AOV · `M-011` Time to Accept |
| No target exists | 3 | `M-004` `M-005` `M-006` |
| **1+1+4+1+2+3 = 12** ✓ | | |

**Entries inheriting the `G-030` denominator defect: 4** — `M-001`, `M-004`, `M-006`, `M-007`. All
four are ratios whose denominator is `M-002`.
