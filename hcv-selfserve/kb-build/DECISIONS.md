# HCV KB build — decision trail

**Append-only.** Newest at the bottom. Never edit or delete a prior entry; supersede it with a new
one that names what it replaces. Full rationale for the initial set: [DESIGN.md](./DESIGN.md).

> **Note on ids.** DESIGN.md v1 carried a parallel `H1`–`H5` series for the same decisions. Those
> labels are **retired and must not be cited** — `D-###` here is the single series. Mapping, for
> anyone reading a v1 quote: `H1→D-001`, `H2→D-002`, `H3→D-003`, `H4→D-004`, `H5→D-007`.

---

### D-001 · 2026-08-14 · KB only, no query layer
**Decision:** Build `hcv-selfserve/kb/` only. No `selfserve_nlq/` for HCV — no metric registry, no
`sqlgen`, no `ask.py`.
**Why:** Owner call. PnM and PTL each have a dry-run query layer; HCV's value is concentrated in
base context, because HCV already has a reconciled query pack and two rich dashboard inventories.
**Consequence:** `core.py`'s stated third consumer ("PnM and PTL — and later HCV") does not
materialise in this engagement. The shared-core promotion question stays open.

### D-002 · 2026-08-14 · Location and branch
**Decision:** New branch `claude/hcv-metric-catalog-map`, cut from `claude/ptl-metric-catalog-map`
@ `28703aa`, in the clone at `dev/selfserve/pnm/selfserve_data`. Directory `hcv-selfserve` (hyphen).
**Why:** Puts `ptl-selfserve/kb/` beside it as the live template and PnM reference material one
directory over. Hyphen matches `ptl-selfserve`.
**Note:** An untracked `hcv_selfserve/` (underscore, containing only a `.DS_Store`) already existed
in this clone. Left in place rather than deleted — it is not tracked and not mine to remove.

### D-003 · 2026-08-14 · Coverage — pack full, everything else indexed
**Decision:** The ~10 query-pack metrics get full `M-###` write-ups. Every other HCV metric across
`dashboard/1882`, `dashboard/4146`, and the Sheet gets an index-only row plus one `G-###`.
**Why:** Mirrors PTL's shape (23 full / 62 index-only of 85) and makes the uncovered surface
visible rather than invisible.

### D-004 · 2026-08-14 · Anchor on the governed metric store
**Decision:** Every full `M-###` entry carries a `store_ref` naming its `metric.porter.*`
counterpart or the literal `none`, plus an explicit statement of how the definitions differ.
**Why:** The Deep Dive shows the governed store already carries HCV metrics that the dashboards
re-derive in raw SQL — and disagrees with both the dashboards and the query pack (MAP is the
sharpest case: login-based vs order-based). Anchoring turns "we hand-rolled a fifth definition"
into a documented, closeable gap instead of an invisible one.
**Rejected alternative:** putting the store at the top of the precedence ladder. That would mark
the owner's own reconciled MBR numbers as non-canonical, and the evidence does not support that yet.

### D-005 · 2026-08-14 · Namespaced inventory references
**Decision:** KB metric ids stay `M-###` (hyphenated). References to the Notion inventories are
**never bare** — always `nb1882:M016` or `nb4146:M016`.
**Why:** The two inventories have colliding id spaces (`M016` is Revenue on 1882, DAP on 4146), and
a bare `M016` would also collide with PTL's `M-###` series.

### D-006 · 2026-08-14 · Three confidence tiers, not four
**Decision:** Keep PTL's `verified` / `unverified` / `assumption`. Record reconciliation-against-
numbers in `note`, not as a fourth tier.
**Why:** "Same architecture across verticals" is a design constraint; forking the confidence schema
for one vertical breaks it. The distinction still gets stated, just in prose that names what was
reconciled, against what, on what date.

### D-007 · 2026-08-14 · Ship WALKTHROUGH.md and a published artifact
**Decision:** Both, built after the seven KB files are stable.
**Why:** PTL's pair landed with people who do not open repos. Building last stops the two drifting
at birth — PTL's drifted once and was caught by audit rather than by process.
**Consequence:** A manual-sync burden with no automation. Stated in `CONTRIBUTING.md`, not left to
memory.

### D-008 · 2026-08-14 · Themed decade-block ID allocation
**Decision:** Allocate `B-`/`T-`/`M-`/`G-` ids in themed decade blocks (DESIGN.md §7). Insertions
and splits use letter suffixes (`T-001a`, `B-053b`) — never a renumber.
**Why:** Flat sequential allocation is **irreversible** once renumbering is forbidden. PTL allocates
in blocks (`B-030–034` conventions, `B-060–061` formulas, `T-030/031` time basis); v1 of this spec
said only "next unused number", which would have yielded `B-001…B-140` sequential across ~140 rows
with no way to recover the structure or file a future fact near its kin.
**Found by:** blind coverage check, ranked its highest-rework-cost omission.

### D-009 · 2026-08-14 · Owner rulings citable as `OWNER:<yyyy-mm-dd>`
**Decision:** Add `OWNER:<yyyy-mm-dd>` to the `source_ref` forms.
**Why:** `D-006` admits "an explicit owner ruling" as grounds for `verified`, but `D-001` removes
the `DECISION_LOG` that PTL cited as `DECISION_LOG:D<n>`. Without a replacement form,
`verified`-by-ruling had no expressible provenance — a live contradiction between two locked
decisions.
**Found by:** blind coverage check.

### D-010 · 2026-08-14 · Resolve the coverage ambiguity: one `G-###` per index-only metric
**Decision:** Each index-only metric gets its own `G-###` row, in `GAPS.md` class G, sharing a
**class-level `next_action`**.
**Why:** v1 said "each gets one `G-###`" in one place and "the uncovered surface" in another — a
fork of two orders of magnitude in output size (~130 rows vs 1). Per-row matches PTL, which is the
architecture being replicated; the class-level action stops ~130 rows each needing bespoke intent.
**Supersedes:** nothing — it resolves an ambiguity `D-003` left open rather than changing it.

### D-011 · 2026-08-14 · North star = Fulfilment % — `OWNER:2026-08-14`
**Decision:** **Fulfilment %** is HCV's north star (L0). Demand, Completed Orders and Allocation %
are demoted to L1 supporting. This is an explicit owner ruling and is citable as
`OWNER:2026-08-14`, which under `D-009` makes the *designation* `verified`.
**Why:** `metabase:dashboard/4146` recommends it; `dashboard/1882` recommends Completed Orders;
neither dashboard had a single primary metric. Owner settled it in favour of 4146.

> ⚠️ **The designation is `verified`; the metric's own definition is not.** Fulfilment %'s
> denominator is unresolved — total demand vs unique demand vs business-hours placed orders are all
> in production under the name "fulfilment" (`4146` contested-definition list). That gap stays
> **BLOCKED — owner** and must not be treated as closed by this ruling. An L0 with a contested
> denominator is a known, recorded tension, not an oversight.
>
> The pack's `ff_pct` = `completed / total_placed` (§2/§2a/§6) is therefore *one* of the three live
> denominators, not automatically the canonical one.

### D-012 · 2026-08-14 · Fingerprint the cited cards now; commit to a full sweep as a tracked gap
**Decision:** `dashboards.md`'s staleness register covers the cards the KB actually cites — those
feeding a covered metric or a recorded conflict. Every other card on `1882`/`4146` is listed in the
surfaces-covered table as **not opened**, a stated boundary. A single `G-###` commits to the full
sweep.
**Why:** ~100+ cards across the two dashboards; most will never be cited. Cited-first unblocks
step 4 without pretending the boundary is permanent.
**Guard against rot:** PTL's equivalent (`G-152`, nine unfingerprinted cards) is still open. This
gap's `next_action` therefore names **a specific card list and a named owner**, not "sweep the
dashboards" — a `next_action` that cannot be executed without further thought is the failure mode
`CONTRIBUTING.md` §8 exists to prevent.

### D-013 · 2026-08-14 · Argus posture — the KB is a migration map · `OWNER:2026-08-14`
**Decision:** This KB reads as a **migration map toward the governed metric store**, not a parallel
definition set. The goal state is **one source of truth and one definition per metric**, and that
source is `metric.porter.*`.
**Why:** Owner ruling. Settles the `G-###` seeded as "Argus posture" and resolves PTL's `G-132`
question in the opposite direction for HCV — where PTL's architecture had been *rejected* by Argus,
HCV's store already exists and is the target.

**What changes:**
- Every full `M-###` entry's `store_ref` carries a **`migration:` line** — the delta to close, and
  **what closing it would change about the reported number**. A delta with no stated consequence is
  not a migration plan.
- Where no store counterpart exists, `store_ref: none` becomes a **gap with a `next_action`**
  ("propose `metric.porter.<name>`"), not a dead end.
- `GAPS.md` class F is reframed: rows record *distance from the target*, not *posture undecided*.

**What does NOT change — read this before "simplifying" the ladder:**
> ⚠️ The precedence ladder (`CONTRIBUTING.md` §6) is an **evidentiary** ordering — what is
> demonstrably true *today*. `D-013` sets the **target**. These are different axes and the ladder
> does not move. The pack stays rung 1 because it is reconciled SQL; the store stays rung 3 for
> formulas because its definitions have not been reconciled against anything here.
>
> The absolute exception still holds. `D-013` tells you **which direction convergence runs**; it
> does **not** decide which formula is correct, and it is not licence to overwrite a pack definition
> with a store definition.

> ⚠️ **Convergence is not free, and one case is already known.** `metric.porter.map` is
> **order-based** (≥1 completed order/month); the pack's MAP is **login-based**
> (`business_login_hours > 0.5`/day). Migrating MAP to the store **changes the number reported in
> the MBR** — it is a business decision with a visible consequence, not a mechanical repoint. Each
> such case ships as a gap stating the delta *and its cost*, for the owner to accept or reject
> per metric.

### D-014 · 2026-08-14 · `dashboard/6406` is the go-forward demand source · `OWNER:2026-08-14`
**Decision:** `metabase:dashboard/6406` ("HCV Demand Dashboard", created 2026-08-12) is the
canonical HCV **demand** surface going forward. `dashboard/1882`'s Traffic & Demand tab becomes
legacy. The owner states Experience and Supply will migrate into `6406` over time.
**Why:** Owner ruling. `6406` consolidates OMS and SO demand in one place with data from Jan-2025;
`1882` splits the same measures across incompatible lineages.

**What it resolves:** the three-objects-answer-"completed orders" problem (`T-050`/`T-051`/`T-059`,
`G-012`) now has a stated target — one consolidated demand object rather than three.

**What it does not resolve, and must be recorded before anyone treats `6406` as settled:**
- **`T-029`** — the Demand card's status filter is **commented out**, so `6406`'s "Demand" counts
  every status while the pack's base is `(4,5)`. Two different populations under one word.
- **`T-021`** — the dashboard's `vehicle_mapping` default is `["14ft","10ft","9ft"]`, which
  **excludes 17ft and 19ft**. The default view under-reports HCV against the pack's scope.
- **Stale defaults** — dashboard defaults to `2025-04-01 → 2025-09-30`; card 55561 defaults to
  `2025-12-10 → 2025-12-10`, a single day. The two disagree, and neither is current.
- **No distance dimension**, which is the pack's primary economic cut (6 of 8 sections use it), and
  **no 10ft NCR/non-NCR split** (`T-023`, `T-024`). Both confirmed absent; the owner has flagged
  distance and Business/Retail as planned.
- **Matchmaking data exists only from Jan-2026**, so those cards are empty for the pack's own
  reporting history.
- The four dimension filters (`vehicle_id`, `vehicle_mapping`, `city_name`, `Tier`) are wired in
  card SQL as optional `[[and {{…}}]]` blocks with real dimension aliases. Whether the
  **dashboard-level** parameters are mapped through to them is not determinable from the API
  response and needs a UI check → `G-014`.

### D-015 · 2026-08-14 · The pack yields exactly **12** full `M-###` entries
**Decision:** Applying `DESIGN.md` §11.2's rule — one `M-###` per distinct **(measure, source
lineage)** pair, grain variants as dimensions, `§6` as a projection, ratio denominators first-class
— the count is **fixed at 12**. Every count stated anywhere in the KB now agrees with this number.

| # | metric | pack § | lineage |
|---|---|---|---|
| 1 | Completed Orders (OMS) | §1 | `oms_public.orders.status = 4` |
| 2 | Revenue | §1 | `oms_public.order_fares` |
| 3 | AOV | §1 | derived, OMS |
| 4 | Total Placed (demand base) | §2/§2a/§3/§3a/§6 | mart |
| 5 | Allocation % | §2/§2a/§6 | mart, `fo_driver_id` |
| 6 | Completed Orders (mart) | §2/§2a/§3/§3a/§6 | `order_status = 4` |
| 7 | **Fulfilment % — L0** (`D-011`) | §2/§2a/§6 | mart |
| 8 | Effective Fulfilment % | §2/§2a | mart + `dim_cancel_reasons_attribution` |
| 9 | Unique Demand | §3/§3a/§6 | mart + dedup (`B-062`) |
| 10 | Unique Fulfilment % | §3/§3a/§6 | mart |
| 11 | Time to Accept p50/p75/p90 | §4 | mart |
| 12 | MAP | §5 | `fact_active_partners` |

**Why 1 and 6 are separate:** §1 counts `oms_public.orders.status = 4`; §2/§3/§6 count
`hcv_overall_demand_mart.order_status = 4`. Same name, different object, never reconciled (`T-050`
vs `T-051`, `G-012`). Merging them would hide the conflict this KB exists to expose.

**Why 11 is one entry, not three:** p50/p75/p90 are three aggregations of one measure over one
population — percentiles are a dimension of the metric, not separate metrics.

### D-016 · 2026-08-14 · Parallel evidence-gathering for step 3, approved by the owner
**Decision:** Four read-only workers, three metrics each, gathering pack SQL excerpts, store
counterparts, card metadata and migration deltas. **The orchestrator writes all 12 `metrics.md`
blocks**; workers return findings only and never write the shared record.
**Why:** Approved by the owner, as `BOARD.md`'s coordination mode required for production fan-out.
Beyond wall-clock, the binding reason is context: each `get_metric` returns ~4KB of JSON and 12 of
them would crowd out step 6 (`CONTEXT.md`), the file that must summarise everything.
**Rejected alternative:** workers drafting their own blocks. Shape and confidence-tagging would
drift between workers on exactly the file where consistency matters most, and that drift is subtle
enough to survive review.

**Each worker was also given one high-priority open question** rather than only transcription work:
units (paise vs rupees, `T-030`) · the allocation key and whether `fo_driver_id` is NULL for SO-only
rows *by construction* · the three live fulfilment denominators, mapped card by card · whether a
login-based MAP is buildable on the store's own source model.

### D-017 · 2026-08-14 · The north-star denominator gap is a *dashboard* problem, not a pack-vs-store problem
**Finding (W3):** `metric.porter.completion_rate` exists, labelled **"Fulfilment Rate"** —
`SUM(completed_orders) / SUM(demand)`, where `metric.porter.demand` is *"count of orders created
(completed + cancelled)"*. Owners `vinay.nadig@theporter.in` / `lfc.da@theporter.in`, approved by
`sandip.dogra@theporter.in` 2026-06-19, `T+1` daily.

**Decision:** Record the denominator gap as **the dashboards diverging from an agreed pack/store
position**, not as a three-way stand-off. The pack's `COALESCE(order_status,5) IN (4,5)` and the
store's `demand` (completed + cancelled) are **the same concept**. The three "live denominators"
are a *dashboard* inconsistency.

**The map, all five cards, verbatim SQL held in the worker record:**

| card | denominator | which |
|---|---|---|
| 55586 | `count(distinct unique_id)` with `-- and o.status in (4,5)` **commented out** | (i) total, but **wider than any other** — all statuses |
| 28681 | `Sum(Demand)` (cte1) **and** `SUM(unique_demand)` (cte2) | **(i) and (ii) side by side**, plus E-FF on a third |
| 38998 | `Sum(Demand)` on `trucks_daily_demand_summary` | (i) — agrees with 28681 cte1 by construction |
| 39084 | `count(oid.order_id)` on `FACT_ORDERS`, **no status filter** | (i), wider. Despite "Hourly" it **groups by** hour, it does not filter to business hours |
| 33212 | `placed_orders_bh` — orders created in hours 10–19 | **(iii)** — the only card implementing it |

**Consequence for `D-011`:** the north-star gap narrows from "pick one of three" to "bring the
dashboards onto the pack/store position, and decide separately whether the business-hours variant
on 33212 is a distinct metric or a defect."

**Two defects found while mapping, neither in any inventory:**
- Card 55586's numerator is `fo_driver_id is not null AND order_status = 4` — it counts
  completed-**and-allocated**. The pack's numerator does not require allocation.
- Card 38998 hardcodes `Vehicle_Category in ('9ft','10ft','14ft','17ft')`, **silently excluding
  19ft** while offering `19ft` in its own filter widget. Card 39084's widget offers `8ft` and omits
  `17ft` — a third distinct vehicle universe.

**Card 33212 is structurally unsound and must not be used as a fulfilment reference:** its numerator
(`trucks_driver_daily_performance_business_hours`, driver-login grain) and denominator
(`oms_public.orders`, order grain) are different tables joined on date, so `FF_bh` is a ratio of two
independently filtered populations — **not bounded at 1 by construction**. It also mixes
`login_date <= {{end_date}}` against `created_at < {{end_date}}`.

### D-018 · 2026-08-14 · Units are **rupees**, not paise — `T-030` downgraded, my earlier alarm withdrawn
**Finding (W1):** the catalog has **no** documented unit for `oms_public.order_fares.FARE`
(`description: null`). The paise descriptions that exist belong to **different tables** —
`ra_public.ra_order_fares.FARE` and `partload_application.order_fares.total_fare` (**PTL's**).
Counter-examples in the same catalog document `pnm_application` fare columns as **"in INR"**.

**Decision:** Record `T-030` as **rupees**, `confidence: unverified`, and **downgrade `G-010` from
OPEN—high to OPEN—low**. Paise is a *per-table* convention at Porter, not a platform-wide one, so
the inference from PTL was unsound.

**Why the evidence is strong even without executing a query — four independent lines:**
1. The governed, approved `metric.porter.revenue` uses the **identical expression with no `/100`**.
2. Its measure `daily_revenue` repeats it with no divisor.
3. `ceil(A.fare)` is **semantically inert on an integer paise column** — it only earns its place if
   `fare` carries a fractional rupee part.
4. Pack, four Metabase cards and the store all apply `ceil()`; none applies `/100`.

**What would close it:** one value read of `fare` for a known HCV order — a ~₹5,000 trip reads
`5000.xx` if rupees, `500000` if paise. Needs owner authorisation to execute; until then the row
stays `unverified`.

> **Correction to the record.** I previously flagged this as *"either HCV differs from PTL or a
> 100× error is widespread."* The second branch is not supported. The KB will not carry that framing.

### D-019 · 2026-08-14 · The store has **no distance dimension** — the pack's primary cut cannot survive migration today
**Finding (W1, corroborated across all three OMS metrics):** `trucks_daily_demand_summary` is
grained day × hour × geo_region × vehicle × vehicle_category × vehicle_sla_category ×
level0_mapping. **No distance.** Tier is absent too — only `geo_region_id`.

**Decision:** Record this as a **first-class migration blocker** in `GAPS.md` class F, not as a note
on individual metrics. `D-013` makes the store the target; six of eight pack sections cut by
distance (`T-071`), so migrating today would **delete the pack's primary economic split**.

**`next_action`:** propose a distance-bucket dimension on `trucks_daily_demand_summary` to
`vinay.nadig@theporter.in` / `lfc.da@theporter.in` (the `completion_rate` / `revenue` owners), noting
it depends on productionising `est_distance_km`, today sourced from a **dev-schema sandbox table**
(`T-070`).

**Three store-migration verdicts now settled, and they differ sharply:**
- **Revenue** — `metric.porter.revenue` is **token-for-token identical** to the pack's fare
  construction. Delta is population and grain only; the rupee figure should not move on
  definitional grounds. Cheapest migration in the set.
- **Completed Orders** — `metric.porter.completed_order_count` exists, but carries no visible
  `deleted_at IS NULL`, `order_type = 0` or test-mobile exclusion, so the count would **rise** by
  whatever those remove.
- **AOV** — `metric.porter.average_order_value` is a **genuinely different number**, not a
  differently-filtered one: Finance-MIS lineage, numerator adds cashback + premium_discount +
  porter_gold + rewards_coins on a GST-stripped base, denominator keyed on **job-end date** not
  order-created date, owned by `finance business` not `olc`. The correct analogue —
  `revenue / completed_order_count` on the OLC mart — **does not exist and must be proposed**.

### D-020 · 2026-08-14 · **Allocation %, FF % and E-FF % carry a silent denominator defect** — `NULL` in `fo_driver_id` is overloaded
**Finding (W2), `confidence: verified` from schema and compiled DDL — no query run.**

`hcv_overall_demand_mart` is `so_orders FULL OUTER JOIN fact_orders ON so.so_order_crn =
fo.fo_crn_number`. For an `so_only` row the entire `fo.*` projection is join-produced NULL. Column
docs, verbatim:

- `fo_driver_id` — *"Driver assigned to the fact order. **Null for SO-only rows**."*
- `order_status` — *"Order status from fact_orders (**null for SO-only rows**)."* The mart does
  **not** coalesce status the way it coalesces driver: `fo.fo_status as order_status`, verbatim.
- `driver_id` — *"Assigned driver identifier — fact_orders driver_id preferred, falls back to SO
  driver_id."* Compiled: `coalesce(fo.fo_driver_id, so.so_driver_id) as driver_id`.

**The mechanism.** The pack filters `COALESCE(m.order_status, 5) IN (4,5)`. `so_only` rows have NULL
status, so `COALESCE` maps them to **5** and **admits every one of them into `total_placed`**. Those
same rows then fail `fo_driver_id IS NOT NULL` unconditionally — **not because no driver was found,
but because no FO leg exists to carry one.**

**`NULL` in `fo_driver_id` therefore means two different things**, and the metric reads the second as
if it were the first:
- on `both` / `fact_only` rows → *no driver was allocated*
- on `so_only` rows → *there is no fact-order leg at all*

**Consequences, in order of severity:**
1. Every `so_only` row sits **permanently in the denominator** of Allocation %, FF % **and** E-FF %,
   and can never enter any numerator. **FF % is the north star (`D-011`)**, so this reaches the
   headline metric.
2. Allocation % is **understated**, one-directionally, by the `so_only` share carrying a non-null
   `so_driver_id`.
3. The defect is **silent** — the query returns a well-formed number with no warning, and the pack's
   own caveats (L531–537) note only *"Allocation uses `fo_driver_id`"* without the denominator
   consequence.

**The cards make a different call, and it is a real choice made nowhere else.** Cards 55586 / 55529 /
55625, verbatim:
```sql
count(distinct case when fo_driver_id is null and  (order_status=5 or order_status is null) then unique_id end) as CBDF_orders,
```
The `or order_status is null` disjunct exists to sweep `so_only` rows into **CBDF (Cancelled Before
Driver Found)** — treating an unmatched scheduled order as a cancellation-before-allocation. That is
defensible, but it is a classification decision living in card SQL, absent from the mart, the store
**and** the pack. The pack inherits the population without inheriting the classification.

**Decision:** record as a `T-###` row, a hard-rule amendment, and a **`GAPS.md` class A row at
`OPEN — high`**. Do **not** "fix" the pack. Two candidate resolutions exist (exclude `so_only` from
the base, or classify it as CBDF per the cards) and they produce different numbers; picking one
silently is precisely what `CONTRIBUTING.md` §6's absolute exception forbids.

**`next_action`:** size it — `COUNT(*) BY demand_type`, and `so_driver_id IS NOT NULL` within
`so_only`, over the Tier-1 / 9–19ft base. **Existence is verified; magnitude is undetermined and
needs one owner-authorised query.** If `so_driver_id` is always NULL on `so_only` rows the two keys
agree and the key-swap is nil-magnitude — but the denominator inflation persists either way, because
those rows are unallocatable under both definitions while still counting as placed demand.

### D-021 · 2026-08-14 · Two governance chains disagree on the allocation key, across three source models
**Finding (W2):** `fo_driver_id` exists in **exactly one model platform-wide** (`modelCount: 1` —
this mart). `driver_id` appears in **414**. The store's `driver_id` convention is the platform
default; `fo_driver_id` is mart-local with **no store metric attached to it anywhere**.

| | `metric.porter.allocation_rate` / `allocated_orders` | `metric.porter.cadf` |
|---|---|---|
| key | `driver_id IS NOT NULL` | `driver_id IS NOT NULL` (in **prose only** — `calculation_logic` is just `SUM(cadf)`) |
| source model | `fact_orders` | `trucks_daily_demand_summary` |
| owners | thejas.ravi@ · utkarsh.dixit@ · sanjeev.mishra@ — domain **ALLOCATION** | vinay.nadig@ · lfc.da@ — domain **olc** |
| approved | sanjeev.mishra@, **2026-08-07** | sandip.dogra@, **2026-06-19** |
| freshness | T+1, **hourly** | T+1, daily |

**Decision:** the `store_ref` on Allocation % names `metric.porter.allocation_rate` **and** records
that its denominator (`count_distinct(order_id)` on `fact_orders`) is structurally incapable of
containing `so_only` demand — so migrating removes those rows from numerator *and* denominator, a
**larger restatement than a key swap**. Both must be stated; they are different migrations with
different costs.

**`next_action`:** the allocation key is not the owner's call alone — it spans two approval chains.
Route to `sanjeev.mishra@theporter.in` (ALLOCATION) **and** `sandip.dogra@theporter.in` (olc)
jointly. Note `metric.porter.cadf`'s `driver_id` claim is unverifiable from its expression.

### D-022 · 2026-08-14 · MAP migration is a **definition change, not a modelling change** — but it is not free
**Finding (W4), confidence HIGH.** `mart_partner_daily_performance_summary` (the store's source for
`metric.porter.map`) **already carries the exact column the pack filters on**:
`business_login_hours` — *"Login hours within the business hours window… Deduplicated to the
first-ranked vehicle per driver-day."* It also carries `date`, `driver_id`, `geo_region_id`, `tier`
and `vehicle_mapping`. **And the pack's own source, `fact_active_partners`, is a direct upstream of
that model** (`dependsOn.nodes`). The two definitions read the same login lineage at different
depths — not two independent systems.

**Decision:** record the MAP gap's `next_action` as **"declare a login-based measure in
`models/semantics/mart_partner_daily_performance_summary_semantic.yml`"**, owned by
`ankush.lohani@theporter.in`. No new model is required. This is the cheapest structural migration in
the set — but three caveats ship with it, all recorded, none resolved:

1. **The dedup rule differs and will move the number.** The store column is deduplicated to the
   first-ranked vehicle per driver-day; the pack **sums across** a driver's vehicle rows within a
   day. Pack ≥ store for multi-vehicle driver-days, so a literal re-implementation on the store
   column qualifies **fewer** driver-days at the `> 0.5` bar.
2. **`vehicle_mapping` vocabularies may not match.** The store column documents examples as
   *"Trucks, 2W, Micro LCV"* — level-0 style. The pack needs the `9ft–19ft` split **and** a separate
   `level0_mapping = 'HCV'`, and no `level0_mapping` column was returned for the store model. Needs
   a value check before build.
3. **`tier` casing** — the store documents `Tier 1/2/3`; pack §5 uses `g.tier = 'Tier 1'` while
   §3/§3a/§4/§6 use `UPPER(g.tier) = 'TIER 1'`. Harmonise on one.

**Blast radius, verbatim from the store's own `meta.relationship`:** *"All three per-active metrics
use MAP as their denominator"* → `payout_per_active`, `orders_per_active`, `login_hrs_per_active`.
Adopting the store's order-based MAP **reduces** the HCV Tier-1 count, which **raises** all three
per-active metrics for unchanged numerators. This is why `D-013`'s "state the cost" rule exists.

**Three login thresholds are in play and none is governed for HCV:** pack `> 0.5 business_login_hours`;
store sibling `total_login_days` uses `> 0 total_login_hours`; the pack's own prose says *"at least
1 hour"*. Separately, `list_metrics(name="dap")` returns **0 rows** — the DAP the pack anchors its
threshold to has **no store counterpart at all**.

### D-023 · 2026-08-14 · Time-to-accept: the pack and the store measure **different things**, and card 55503 is the wrong reconciliation target
**Finding (W4).** The two differ on **three axes at once**, not one:

| | pack §4 | `store:metric.porter.avg_time_to_accept_seconds` |
|---|---|---|
| starts at | `order_time` — **customer places the order** | **notification sent to the driver** |
| statistic | `PERCENTILE_CONT` 0.50 / 0.75 / 0.90 | **mean** — `total_accept_seconds / accepted_notifications` |
| unit of analysis | one **order** | one **notification batch** |
| outlier guard | `BETWEEN 0 AND 3600` | **none declared** |

**Stated precisely: the pack measures customer-perceived wait; the store measures driver
responsiveness.** The pack's interval **strictly contains** the store's — the difference is the
matchmaking/queueing latency from order placement to first ping, which the store's clock never sees.

**Decision:** record `store_ref` as `avg_time_to_accept_seconds` with `migration: NOT EQUIVALENT`.
A mean cannot be reconciled to a p50 by any adjustment, and the store's undeclared outlier handling
absorbs exactly the tail the pack deliberately caps. Do not present them as the same metric at
different precision.

**Card correction:** `metabase:card/55503` ("HCV ATA Distribution in Minutes") is **not** the
reconciliation target — its clock is `TRIP_ACCEPTED_TIME → TRIP_START_ENTRY_TIMESTAMP`, i.e.
**arrival**, a third clock. **`metabase:card/55527` is the correct target** — it sits on the pack's
clock. But 55527 carries its own defect: the column is aliased `allocation_time_minutes` and
commented *"Allocation time (minutes)"* while the expression computes **seconds**; only the alias and
comment are wrong. It also has no upper guard where the pack caps at 3600, and defaults to
`2023-07-01 → 2023-12-31`.

**Within-pack inconsistency found while checking dedup (W4), `verified`:** the dedup logic is
**byte-for-byte identical** across §3, §3a and §6 (whitespace aside). But **§6 drops `DISTINCT` on
the completed count** — §3/§3a use `COUNT(DISTINCT CASE WHEN order_status = 4 …)`, §6 uses
`COUNT(CASE WHEN order_status = 4 …)`. So `unique_ff_pct` **disagrees between §3 and §6** wherever
`unique_id` repeats in `cat`. Record as a pack defect (`GAPS.md` class E); do not silently correct.

**Also recorded:** pack §5's inner `GROUP BY` includes `geo_region_id` while the `SELECT` does not,
so the `> 0.5` login test is applied **per region**, not per driver-day — a driver splitting a day
across two regions may fail both halves while passing the combined day.

### D-024 · 2026-08-14 · **The step-7 verification gate did NOT run** — session limit
**What happened:** all three blind checkers (spec-conformance, accuracy-vs-sources, adversarial
blind-spot hunt) were spawned and **all three terminated early** on an API session limit, each
having read only part of the artifact. Reset: 08:20 Asia/Calcutta.

**Decision: the KB is NOT verified, and must not be described as verified.** What has passed is the
**mechanical** pass only (`DESIGN.md` §15's third bullet) — 10/10, listed in `BOARD.md`. The other
two gate components — **blind accuracy check** and **zero-context loadability test** — have **not
run at all**.

**Why this is recorded as a decision rather than a note:** `D-007` and `DESIGN.md` §15 make the gate
a precondition for step 8 (`WALKTHROUGH.md` + published artifact). **Step 8 must not start until the
gate completes.** Shipping a team-facing walkthrough off an unverified KB would propagate any defect
into the artifact people actually read — the failure mode PTL hit and audited its way out of.

**The prior says the gate will find things.** Every verification pass in this build found real
defects in freshly-written work: 28 in the spec, a knowingly-wrong count and four missing SQL
excerpts in `metrics.md`, a dangling `G-071` in `GAPS.md`, a dangling `B-090` in `CONTEXT.md`, two
phantom ids in `CONTRIBUTING.md`. **Expected findings from a completed gate: not zero.**

**Resource constraint, recorded as a first-class finding.** The adversarial checker's own brief asked
it to identify *"what assumes effort, access, or attention that will not be available."* It answered
by dying of exactly that. Three full-artifact blind reads is a real budget, and this build did not
plan for it. **Any future KB of this size should budget the gate as its own session**, not as a tail
task after seven files are written.

**Re-spawn briefs are recorded in `BOARD.md` §Gate** so a cold session can re-run all three verbatim
without reconstructing them.

### D-025 · 2026-08-14 · Blind conformance check: **42 findings.** Fixed 7, deferred 5, 1 needs recount
**The gate found real defects, as the prior said it would.** Checker A (spec conformance) completed;
B (accuracy vs sources) and C (adversarial) still have **not run** (`D-024`).

**Fixed immediately — all verified before and after:**
| # | defect | fix |
|---|---|---|
| F25 | **`metrics.md` §3 was DUPLICATED** — my §2 edit left the stale copy in place, opening with a malformed doubled table header | Truncated 643→611 lines; one §3 remains |
| F30 | **`T-030` held four contradictory states across four files**, and shipped verbatim the 100×-error framing `D-018` explicitly retracted — reachable by a reader following the documented load protocol | `T-030` now `rupees` / `unverified` per `D-018`; retracted framing replaced with the four evidence lines and the per-table-convention warning |
| F20 | `dashboards.md` DB partition **13 + 2 = 15 ≠ 17** | 13→**15** |
| F21 | `G-050` said **"~19 cards"** against a list of **31** | →**31**, and the "~" removed (it is a literal list) |
| F22 | `CONTEXT.md` said **11** `BLOCKED — owner`; there are **12** | →**12** |
| F27 | `CONTEXT.md` + `metrics.md` said **4** live AOV formulas; `G-033` enumerates **5** | →**5** in both |
| F26 | Closing line claimed two counts were "estimates, not facts" **after** they were resolved to 98/110 | removed with the duplicate §3 |

**Deferred, and why — these are honest debts, not oversights:**
- **F1** — 10 of 12 blocks omit the spec-mandated `grain:` line. Real; needs 10 edits.
- **F17** — `T-` time-basis ids sit at `010–013` inside the core-enums block; the mandated `040–049`
  block is **entirely unused**. **Permanent** — `D-008`/`CONTRIBUTING.md` §2.3 forbid the renumber
  that would fix it. The block map is now aspirational for `T-`, and that must be stated.
- **F18/F41** — the `G-` series does not start a fresh decade per class, and `GAPS.md` **overrides the
  spec in writing** without an authorising decision. **This entry is that decision**: the four-range
  scheme in `GAPS.md` supersedes `DESIGN.md` §7's `G-` rule, for the reason stated there.
- **F32** — `D-010`'s per-metric `G-201`–`G-298` rows do not exist as rows; only as an arithmetic
  rule. Implemented differently from how it was recorded. **This entry supersedes that half of `D-010`.**
- **F35** — a reader of `kb/` alone **cannot learn the gate did not run**, and `CONTEXT.md` cites the
  trail as "D-001..D-023", omitting `D-024` — the decision that says the KB is unverified.

**Needs a recount before anything downstream is trusted — `F23`/`F24`, HIGH:**
The `−26` term in `metrics.md` §3 is **wrong and mis-split**. Recomputed from the blocks' own
`inventory_ref` lines: `nb1882` = **9** distinct (not 10 — `nb1882:M002` is claimed by both `M-003`
and `M-008`), `nb4146` = **10** (not 9), and **`gsheet` = 0, not 7 — no full entry carries a single
`gsheet:` reference.** Worse, `M-012` MAP cites `nb1882:M041` + `nb4146:M016`, and index row 26 (DAP)
cites the same two — **the same source rows are counted as both covered and indexed**, so the
partition is not complementary. This also contradicts §3's own headline that *"MAP has no metric row
in any of the three sources."*
**`−26` produces the 98, which produces the 110.** Until recounted, **treat 98 and 110 as unverified.**

**The lesson, recorded:** the mechanical pass scored **16/16** on this same artifact. It checks that
numbers *are stated*, not that they are *right* — every one of F20/F21/F22/F23/F24/F27 is an
arithmetic error the mechanical pass declared clean. **A self-written checker cannot find what its
author did not think to check.** That is the argument for the blind gate, made empirically.

### D-026 · 2026-08-14 · Recount closes `F23`/`F24` — the headline numbers were **wrong**, and are now 25 / 99 / 111
**The blind checker was right.** Recomputed from the 12 blocks' own `inventory_ref` lines:

| | claimed | actual |
|---|---|---|
| `nb1882` rows covered | 10 | **10** ✓ (after fixes) |
| `nb4146` rows covered | 9 | **9** ✓ |
| `gsheet` rows covered | 7 | **6** |
| **total covered** | **26** | **25** |
| index rows | 98 | **99** |
| KB total | 110 | **111** |

**Two genuine defects caused it, both now fixed:**

1. **`M-012` MAP cited `nb1882:M041` and `nb4146:M016` — both are DAP, not MAP.** DAP is login-based
   and daily; MAP is monthly. Those two rows are **index row 26**, so citing them in a full entry
   **double-counted them** — the partition was not complementary. It also flatly contradicted §3's own
   headline that *"MAP is catalogued by no source."* **`M-012`'s `inventory_ref` is now `none`**, with
   the retracted citation recorded inline so the error is visible rather than erased.
2. **Eight source rows the index-builder excluded were cited by no block at all** — so they were
   deducted from the index while appearing in no full entry. Added where the mapping is sound:
   `nb1882:M011` ("Completion %", which the inventory itself calls *"redundant with Fulfilment %"*)
   and `gsheet:33` → `M-001` · `gsheet:27` → `M-002` · `gsheet:34` → `M-004` · `gsheet:28` → `M-005`
   · `gsheet:35` → `M-007` · `nb1882:M043` + `gsheet:29` → `M-011`.

**One excluded row genuinely belongs in the index, and is now row 99:** `gsheet:30` *"Time to accept
after listing on tray"* is **tray-clocked**, not order-clocked — a different measurement from the
pack's `M-011` (`order_time → fo_trip_accepted_time`), and distinct from index row 17
(tray-listing → *allocation*). Excluding it assumed an equivalence that does not hold.

**Arithmetic now reconciles: `178 − 25 − 57 + 3 = 99`, and `12 + 99 = 111`.** Propagated to
`CONTEXT.md`, `GAPS.md` (class G now `G-201`–`G-299`) and `metrics.md`.

**What this says about the counting contract.** `DESIGN.md` §11.4 required that every partition sum —
and it *did* sum, at 178−26−57+3=98. **A partition can be internally consistent and still wrong,
because the inputs were never audited against the artifact's own citations.** The mechanical pass
checked the addition; nothing checked the addends. That is the gap a blind reader found and a
self-written checker structurally cannot.

### D-027 · 2026-08-14 · `G-030` SIZED by query — and it **reverses the reported FF % trend**
**Owner granted Snowflake query permission.** Two read-only `SELECT`s against
`prod_eldoria.mart.hcv_overall_demand_mart` at the pack's standard scope (`B-060`). First values ever
entered in `business.md` §7.

**The by-construction claim is empirically confirmed.** All **32,821** SO-only rows have
`fo_driver_id` NULL **and** `order_status` NULL **and** **zero completions**. Not one can reach the
numerator of FF %, E-FF %, Unique FF % or Allocation %. The DDL inference was right.

**Magnitude — and the average hides the finding:**

| | May-26 | Jun-26 | Jul-26 |
|---|---|---|---|
| SO-only share of placed | **4.88 %** | 0.22 % | 0.18 % |
| FF % as reported | 54.57 | 55.87 | 56.11 |
| FF % excluding SO-only | **57.37** | 55.99 | 56.21 |
| `G-030` distortion | **−2.80 pp** | −0.12 pp | −0.10 pp |

**Reported FF % rises +1.30 pp May→Jun and reads as improvement. Corrected, it falls −1.38 pp.**
The "improvement" is largely the artifact disappearing. **Any May-vs-June HCV fulfilment narrative
built on the reported series is directionally wrong.** → new gap `G-081`, `OPEN — high · ESCALATED`.

**I framed the test wrong, and the record should say so.** I told the owner *"at 2 % it's a footnote,
at 20 % materially wrong."* The average is **1.74 %** — by that test, a footnote. **The test was the
wrong one.** What breaks a trend is not the level of a distortion but its **variance across periods**,
and I did not think to check for that until the monthly cut showed a 22× collapse. A stable 5 %
distortion would have been harmless to trend reading; a 4.88 %→0.22 % swing is not.

**Second finding, unprompted by the DDL analysis: the allocation-key divergence is NOT confined to
SO-only rows.** `driver_id IS NOT NULL AND fo_driver_id IS NULL` holds for **13,225 `both`-type rows**
as well as 4,155 SO-only — **17,380 total**. `D-020`/`G-032` assumed the divergence lived in the
SO-only set. It does not. Allocation % on the store's key is **+1.43 pp** (May), +0.75, +0.59 — also
shrinking, and the shrink is unexplained.

**Snapshot scope, stated precisely so it is not over-read:** month × **overall** only. **No category
and no distance split** — `mbr_mapping_v2` was not rebuilt (`T-073`). **Revenue and AOV absent** —
`T-030` leaves unit scaling `unverified`. These are **not** the pack's published figures.

**`G-024` (empty snapshot) is partially closed**; the rest waits on `T-030` and a rebuilt base table.
