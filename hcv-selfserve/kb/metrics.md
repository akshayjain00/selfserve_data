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
- **confidence: `unverified`** — four AOV formulas are live across `1882`, `4146` and the store.
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

**Not yet built.** This section will carry one row per un-promoted metric from the deduped union of
`nb1882`'s 54, `nb4146`'s 34 and the Sheet's ~90 rows, each with a `G-###` in `GAPS.md` class G
(`D-010`), sharing a class-level `next_action`.

Columns: `metric | source | inventory_ref | level | Doshi category | source-status (verbatim) | G-###`.

> ⚠️ **The `source-status` column carries the source's own wording verbatim — `Pending`,
> `contested`, `unverified`. It is NOT a KB confidence value** ([CONTRIBUTING.md](./CONTRIBUTING.md) §4).

**Estimate, and it is labelled as one until the de-dup runs:** the dashboards' union is **72**
(54 + 34 − ~16 shared); the Sheet overlaps it by roughly **20–30** rows — a real overlap, not a thin
one. Union ≈ **132–142**; index-only ≈ **120–130** after the 12 promotions.

**The counting contract (`D-015`) binds when this section is written**, not before: at that point the
counts are fixed once and every `N of M` pairing in the KB must agree with them. **Count rows and
`M-###` numbers separately and say which you mean** — that conflation is the exact bug PTL shipped.

---

## §3 Reconciliation

| | count | basis |
|---|---|---|
| | count | which |
|---|---|---|
| Full `M-###` entries | **12** | `D-015` — one per (measure, source lineage) pair |
| `store_ref` **named** | **9** | `M-001` `M-002` `M-003` `M-007` `M-008` `M-009` `M-010` `M-011` `M-012` |
| `store_ref: none` — must be **proposed** | **3** | `M-004` E-FF · `M-005` Unique Demand · `M-006` Unique FF (blocked behind `M-005`) |
| **9 + 3 = 12** ✓ | | the partition is complete |

Of the 9 named, **one is flagged as not a true counterpart** — `M-002`'s `metric.porter.demand` is
OLC-scoped and cannot carry SO-only demand. It is counted as named because a counterpart is
identified; the delta is stated in its entry.

| migration verdict | count | which |
|---|---|---|
| Identical definition — cheapest | **1** | `M-009` Revenue |
| Definition change, no new modelling | **1** | `M-012` MAP |
| Differently-filtered same measure | **4** | `M-001` `M-002` `M-003` `M-008` |
| Key/population contested | **1** | `M-007` Allocation % |
| **`NOT EQUIVALENT`** — different measurement | **2** | `M-010` AOV · `M-011` Time to Accept |
| No target exists | **3** | `M-004` `M-005` `M-006` |
| **1+1+4+1+2+3 = 12** ✓ | | |

**Entries inheriting the `G-030` denominator defect: 4** — `M-001`, `M-004`, `M-006`, `M-007`. All
four are ratios whose denominator is `M-002`.

**Two counts on this page are estimates, not facts**, and are labelled so in §2: the index-only row
count and the deduped union. They are fixed when §2 is written, per `D-015`.
