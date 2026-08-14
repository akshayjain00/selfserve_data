# GAPS.md — open questions, conflicts, and uncovered surface

`G-###` rows, **append-only**. Adding and closing rules: [CONTRIBUTING.md](./CONTRIBUTING.md) §8.
Entry point: [CONTEXT.md](./CONTEXT.md). Seeded 2026-08-14 from steps 2–4 of the build.

> **A gap is not a failure — it is a known unknown with an owner and a next action.** The dangerous
> state is a fact that *looks* verified and isn't. Every row below has a `next_action` specific
> enough to execute, except class E, where the action is deliberately *"do nothing — record it."*

**Status:** `OPEN` · `BLOCKED` (needs a person or a decision, not more analysis) · `CLOSED` (with
date and resolving ID). Severity qualifiers: `— high` · `— low` · `— informational` ·
`— mechanical, do next` · `· ESCALATED`.

---

## How ids are allocated here — read once

Two schemes are live, and the split is **deliberate and permanent**, not an accident to be tidied:

| range | meaning |
|---|---|
| `G-004`–`G-029` | **Mixed early range.** Allocated during steps 2–3 as facts were written, before gaps were grouped into classes. Non-contiguous by class |
| `G-030`–`G-099` | Allocated during steps 3–4, **grouped loosely by class** |
| `G-201`–`G-298` | **Class G only** — one per index row, allocated mechanically: index row *N* ↔ `G-(200 + N)` |
| `G-100`–`G-199` | **Reserved for new gaps.** Take the next unused number here |

**Ids were never renumbered to fit the class scheme.** [CONTRIBUTING.md](./CONTRIBUTING.md) §2.3
forbids renumbering, and re-pointing ~40 references across four committed files to gain tidiness
would risk a silently missed reference — a worse outcome than a non-contiguous range. **Class
membership is declared here, by section, not encoded in the number.**

`G-001`, `G-002` were never allocated — **retired, not reused.**

---

## A. Metric-definition conflicts — highest priority

| id | gap | conflicting positions | next_action | status |
|---|---|---|---|---|
| **G-030** | **The denominator of Allocation %, FF % and E-FF % contains rows that can never reach the numerator** | `hcv_overall_demand_mart` is `so_orders FULL OUTER JOIN fact_orders`. For SO-only rows the whole `fo.*` projection is NULL *by construction* — column docs: *"`fo_driver_id` … **Null for SO-only rows**"*, *"`order_status` … **null for SO-only rows**"*. The pack's `COALESCE(order_status,5)` maps those NULLs to **5**, admitting every SO-only row into `total_placed`, where it then fails `fo_driver_id IS NOT NULL` unconditionally. **`NULL` is overloaded**: "no driver allocated" vs "no fact-order leg exists". Cards 55586/55529/55625 make a *different* call — `or order_status is null` sweeps SO-only into **CBDF** — a classification living only in card SQL | **Size it.** `COUNT(*) BY demand_type`, and `so_driver_id IS NOT NULL` within `so_only`, over the Tier-1 / 9–19ft base. **Existence is verified from DDL; magnitude is unknown and metadata cannot answer it.** Needs one owner-authorised query. Then choose: exclude SO-only from the base, or classify as CBDF per the cards — **the two produce different numbers** | **OPEN — high** |
| **G-031** | **Three denominators are live under the name "fulfilment"** | (i) **total** demand — cards 55586 (status filter commented out, so *wider* than any other), 28681 cte1, 38998, 39084 (raw `FACT_ORDERS` row count, no status filter); (ii) **unique** demand — 28681 cte2; (iii) **business-hours** placed orders — 33212 only. **Pack and store agree** on (i)-as-completed+cancelled; the dashboards are what diverge | Bring the dashboards onto the pack/store position, and decide separately whether the business-hours variant is a **distinct metric** or a **defect**. This is the denominator of the north star (`D-011`) | **BLOCKED — owner** |
| **G-032** | **Two governance chains disagree on the allocation key, across three source models** | Pack + all `6406` cards use **`fo_driver_id`**; `metric.porter.allocated_orders` / `allocation_rate` use **`driver_id`** (`fact_orders`, owners `thejas.ravi@` `utkarsh.dixit@` `sanjeev.mishra@`, approved 2026-08-07, **hourly**); `metric.porter.cadf` also claims `driver_id` but **in prose only** — its `calculation_logic` is just `SUM(cadf)` (owners `vinay.nadig@` `lfc.da@`, approved 2026-06-19, daily). `fo_driver_id` exists in **exactly one model platform-wide**; `driver_id` in **414** | Route jointly to `sanjeev.mishra@theporter.in` (ALLOCATION) **and** `sandip.dogra@theporter.in` (olc) — this is not one owner's call | **BLOCKED — owner, structural** |
| **G-033** | **Revenue and AOV each have multiple live definitions** | Revenue: four formulas on `1882`, plus the pack's, plus `metric.porter.revenue` (**identical to the pack's**). AOV: three on `1882`, one on `4146` (card 32713), plus `metric.porter.average_order_value` — Finance-MIS lineage, **job-end-date** axis, numerator adds cashback + premium_discount + porter_gold + rewards_coins on a GST-stripped base | Owner picks one canonical revenue **and** one canonical AOV. Note the pack's revenue **already matches the governed metric token-for-token**, so revenue is nearly settled; AOV is not | **BLOCKED — owner** |
| **G-034** | **Card 28681 carries two competing E-FF definitions differing on two axes at once** | Live (cte1, `trucks_daily_demand_summary`): `SUM(completed_orders) / SUM(DEMAND - cadf_customer - cbdf_customer)`. Computed but suppressed at projection (cte2, `trucks_unique_demand_summary`): `… / SUM(DEMAND - cadf_cac - cbdf_cac)`. **Different attribution columns AND different source marts**, both aliased `effective_fulfillment`. The pack uses a third construction — a single `customer_cancelled` term from `dim_cancel_reasons_attribution` | Confirm which attribution basis is canonical, and whether `cac` denotes customer-attributed cancellation. **Column semantics were not looked up** — do that first | **BLOCKED — owner** |
| **G-035** | **Unique demand has two independent implementations, never compared** | The pack computes dedup from scratch (100 m / 100 m / 60 min / `order_status = 5`, `LEAD` over `customer_id`). Card 28681 reads a **pre-computed** `unique_demand` column from `trucks_unique_demand_summary` | Compare the mart's dedup rule against `B-062`. If they differ, Unique FF % differs between pack and dashboard by the difference in duplicate counts | **OPEN — high** |
| **G-036** | **Pack and store time-to-accept measure different things** | Pack: **percentiles**, clocked `order_time → fo_trip_accepted_time`, per **order**, capped `0–3600s`. Store `avg_time_to_accept_seconds`: a **mean**, clocked **notification-sent → acceptance**, per **notification batch**, **no outlier guard**. The pack's interval **strictly contains** the store's. Card 55503 is on a **third** clock (accept → trip start) | Do not present them as one metric at different precision. If a single governed measure is wanted, propose an order-clocked percentile metric to `sanjeev.mishra@theporter.in` | **OPEN — high** |
| **G-038** | **Three login thresholds are in play and none is governed for HCV** | Pack: `> 0.5 business_login_hours` per driver-day. Store sibling `total_login_days`: `> 0 total_login_hours`. Pack prose: *"at least 1 hour"*. `list_metrics(name="dap")` returns **0 rows** — the DAP the pack anchors to has **no store counterpart** | Owner picks one threshold and one column (`business_` vs `total_login_hours`); then declare DAP in the store | **BLOCKED — owner** |
| **G-007** | HCV scope is expressed two ways | `vehicle_mapping IN ('9ft'…'19ft')` (pack §0–§4, §6) vs `v.level0_mapping = 'HCV'` (pack §5, cards 32713/55587) | Confirm the two select the same population; if so, standardise | **OPEN — low** |
| **G-012** | **Three different objects answer "how many HCV orders completed"** | `hcv_overall_demand_mart` (`M-003`) · `oms_public.orders` (`M-008`) · `cge_completed_spot_orders_fast_mv` (card 32713). Different date axes, different window bounds, SO-only rows present in one and absent by construction from another | Reconcile at least `M-003` against `M-008` for one month before either is quoted alongside the other | **OPEN — high** |
| **G-013** | `dashboard/6406`'s "Demand" and the pack's "total placed" are **different populations** | `6406` cards have `-- and o.status in (4,5)` commented out, so they count every status; the pack counts `(4,5)` | Decide whether `6406`'s Demand is intentionally all-status. If not, uncomment. Owner: `chetan.sharma2@theporter.in` | **OPEN — high · ESCALATED** |

## B. Code defects in source cards

| id | gap | next_action | status |
|---|---|---|---|
| **G-053** | `dashboard/6406`'s `Vehicle Mapping` default is `["14ft","10ft","9ft"]` — **excludes 17ft and 19ft**, both in HCV scope. The default view **under-reports** | Add 17ft and 19ft to the default. Owner: `chetan.sharma2@theporter.in` | **OPEN — high** |
| **G-054** | Card-level and dashboard-level defaults **disagree**. Dashboard: `2025-04-01 → 2025-09-30`, `Period=Month`. Card 55561: `2025-12-10 → 2025-12-10` (**a single day**), `Period=DAY` | Align both, and move the window to a rolling recent period | **OPEN — high** |
| **G-055** | On `6406` the **Demand card has no `Tier` default** while the three ratio cards default to `Tier 1` — so at default settings numerator and denominator cards **do not share a population** | Set `Tier=Tier 1` on 55561, or remove it from the ratio cards | **OPEN — high** |
| **G-056** | `group by all` in 55587/55626/55541's fare CTEs groups by `order_id + travel_distance + fare`, so a multi-row order can **fan out** on the `LEFT JOIN` | Group by `order_id` only | **OPEN — high** |
| **G-057** | 55515/55512/55546 apply **no test-customer exclusion, no status filter, no Tier default**, and carry a hardcoded `>= '2024-06-05'` floor. 55546 merges `NUM_SELECTED_DRIVERS` (SO) with `NUM_RANKED_DRIVERS` (FO) as one measure | Add the standard scope filters (`B-060`); confirm the two driver-count columns are comparable | **OPEN — high** |
| **G-073** | Card 55527 aliases its output `allocation_time_minutes` and comments *"(minutes)"* while computing **seconds**; the title says seconds. It also applies **no upper guard** where the pack caps at 3600s | Fix the alias and comment. Decide whether the cap should be adopted | **OPEN — mechanical, do next** |
| **G-075** | Card 38998 hardcodes `Vehicle_Category in ('9ft','10ft','14ft','17ft')` — **silently excludes 19ft** while offering `19ft` in its own filter widget. Card 39084's widget offers `8ft` and omits `17ft` — a third vehicle universe | Standardise every HCV card's vehicle universe on `B-060` | **OPEN — high** |
| **G-076** | Card 33212's numerator (`trucks_driver_daily_performance_business_hours`, driver-login grain) and denominator (`oms_public.orders`, order grain) are **different tables joined on date**, so `FF_bh` is **not bounded at 1 by construction**. It also mixes `login_date <= end` against `created_at < end` | **Do not use 33212 as a fulfilment reference** until rebuilt on one grain | **OPEN — high** |
| **G-006** | Card 28841 (ATA) reportedly has an **IST double-shift** — adds 5h30m to an already-IST column while filtering on the un-shifted date | Re-read 28841's SQL. **Reported by `nb1882`, not read by this KB** | **OPEN — low** |
| **G-008** | Card 32713's `vehicle_category` picklist offers **`8ft`**, outside HCV scope | Remove `8ft` from the picklist | **OPEN — low** |
| **G-009** | Tier is derived by a hardcoded `CASE geo_region_id IN (1,2,3,4,5,6,8,9)` across ≥8 cards on `4146` — a business rule buried in SQL rather than a governed dimension | Replace with a `dim_geo_regions` join. **Reported by `nb4146`, not read by this KB** | **OPEN — low** |

## C. Source and provenance gaps

| id | gap | next_action | status |
|---|---|---|---|
| **G-050** | **~19 cards this KB cites have no staleness fingerprint** | One `get_card` each for: **28688, 39506, 28691, 28692, 28693, 37311, 28195, 29553, 29559, 28673, 28669, 28678** (`1882` revenue/AOV family) and **32645, 32668, 32694, 32670, 32687, 32700, 33106, 33133, 33269, 32927, 36946, 32950, 28841, 28843, 28844, 28845, 29910, 39374, 43512** (`4146` families). **A literal executable list — not "sweep the dashboards."** PTL's equivalent has sat open since 2026-07-30 because its action was not specific enough | **OPEN — mechanical, do next** |
| **G-014** | The four dimension filters on `6406` (`vehicle_id`, `vehicle_mapping`, `city_name`, `Tier`) are correctly wired in **card** SQL as `[[and {{…}}]]` blocks with real aliases. Whether the **dashboard-level** parameters map through is **not determinable from the API response** | One UI check on `dashboard/6406` | **OPEN — mechanical, do next** |
| **G-004** | Nothing records **why `order_status` is ever NULL** beyond SO-only rows, yet `COALESCE(…,5)` silently makes every NULL a cancellation (12 occurrences) | Confirm SO-only is the only NULL source. If not, the `COALESCE` mislabels a second population | **OPEN — high** |
| **G-005** | `order_time`'s fallback chain means a **scheduled order with no FO leg is dated by its slot start, not its booking time** — so monthly counts mix two time semantics | Quantify how many rows use the fallback; decide whether to split the axis | **OPEN — low** |
| **G-010** | **Units of `oms_public.order_fares.fare` are undocumented** (`description: null`). Four independent lines indicate **rupees**, not paise — but no source states it | One value read for a known HCV order: a ~₹5,000 trip reads `5000.xx` if rupees, `500000` if paise. Needs owner authorisation | **OPEN — low** |
| **G-020** | **HCV's business posture — stage, unit economics, margin, strategic priority — is recorded nowhere in this KB's sources** | Ask the vertical owner. Not resolvable by more searching | **BLOCKED — owner** |
| **G-021** | **No source records HCV interventions or GTM events** — pricing changes, city launches, campaigns — so **no trend movement in HCV can be attributed** | Ask ProdOps for a dated intervention log | **BLOCKED — owner** |
| **G-024** | `business.md` §7's snapshot is **empty** — no number in this KB has been warehouse-validated | After `G-010` and `G-030` resolve, run the pack for one month with owner authorisation and populate the snapshot with current + prior period | **BLOCKED — owner** |

## D. Naming and ID collisions

| id | gap | next_action | status |
|---|---|---|---|
| **G-022** | **"SO" is overloaded** — **Scheduled Order** in column names and SQL (`so_is_express_booking`, `so_id`), **Stock Out** in card titles and descriptions (`"MO, SO, CADF, PAC, CAC and PoAC"`) | Rename one. Until then, **read the SQL, not the label** | **OPEN — high** |
| **G-060** | **Taxonomy divergence across sources.** The Sheet supplies **18 Satisfaction metrics**; both Notion inventories independently state their dashboards carry **none**. The Sheet also assigns systematically higher levels. Level or Doshi category conflict for **20** merged metrics | One owner ratifies a single level + Doshi assignment per metric before the store is built. Every conflicting value is listed in `metrics.md` §2 in source order | **BLOCKED — owner, structural** |
| **G-078** | ⚠️ **`status = 4` means *Cancelled* in PTL and *completed* in HCV**, in KBs sitting side by side on branches cut from each other | No fix — this is a fact about two systems. Recorded so nobody carries a status literal across verticals. `CONTEXT.md` hard rule 2 exists for this | **OPEN — informational** |

## E. Defects inside a single source — recorded, deliberately NOT corrected

**`next_action` for this entire class is: do nothing. Record it, quote the source verbatim, and do
not silently correct it** ([CONTRIBUTING.md](./CONTRIBUTING.md) §8.5).

| id | source | the defect |
|---|---|---|
| **G-011** | the query pack | Its caveat says *"sections 1–4 depend on `mbr_mapping_v2`"*. **`§6` depends on it too** — every section except `§5` does |
| **G-070** | the query pack | **`§6` drops `DISTINCT`** on the completed count where `§3`/`§3a` keep it, so `unique_ff_pct` **disagrees between sections of the same pack** |
| **G-072** | the query pack | `§1` uses case-sensitive `g.tier = 'Tier 1'`; every other section uses defensive `UPPER(g.tier) = 'TIER 1'` |
| **G-074** | the query pack | `§5`'s inner `GROUP BY` includes `geo_region_id` while the `SELECT` does not, so the `> 0.5` login test is applied **per region**, not per driver-day |
| **G-077** | `nb4146` | Its summary says **34** unique metrics; its own design callout says *"~26 of **33**"*. The source contradicts itself |
| **G-079** | `gsheet` | `#78` "Fare breach" defines a **P50/P90 of a percentage** — not well-formed. `#31` "Dry Run" is one row spanning **two measures** (distance *and* time). The `Status` column is **offset by one** for 6 of 90 rows |

### E2. Informational anti-gaps — correct behaviour that looks like a defect

**These rows exist so a future session does not "fix" something that is already right**
([CONTRIBUTING.md](./CONTRIBUTING.md) §8.5). They are **not** defects.

| id | what looks wrong | why it is correct |
|---|---|---|
| **G-071** | The dedup `LEAD` window in `pack:§3`/`§3a`/`§6` extends to **2026-08-02** while the output is cut at **2026-08-01**, so late-July orders are deduplicated against successors that never appear in the result | **Deliberate.** The pack comments it inline as *"buffer for late-July next-order"* at `#L256`, `#L330`, `#L469`. Without the buffer, the last orders in the window could never be identified as duplicates. Applied **identically** in all three sections. **Do not "tighten" it to 2026-08-01** |

## F. Strategic and metric-store posture

| id | gap | next_action | status |
|---|---|---|---|
| **G-037** | **The governed store has no distance dimension.** `trucks_daily_demand_summary` is grained day × hour × geo_region × vehicle × vehicle_category × vehicle_sla_category × level0_mapping. Tier is absent too. **Six of eight pack sections cut by distance**, so migrating today would **delete the pack's primary economic split** | Propose a distance-bucket dimension to `vinay.nadig@theporter.in` / `lfc.da@theporter.in`. Depends on productionising `est_distance_km`, today sourced from a **dev sandbox table** (`T-070`) | **BLOCKED — owner, structural** |
| **G-023** | **Migrating MAP to the store changes the reported number, and the blast radius is three metrics.** Store is order-based; pack is login-based. MAP is the denominator of `payout_per_active`, `orders_per_active`, `login_hrs_per_active` — reducing MAP **raises all three** | Declare a login-based measure in `models/semantics/mart_partner_daily_performance_summary_semantic.yml`. **No new modelling needed** — `business_login_hours` already exists there and `fact_active_partners` is its direct upstream. Owner `ankush.lohani@theporter.in`. Note the store dedups to one vehicle per driver-day where the pack sums | **BLOCKED — owner** |
| **G-080** | **The pack has no freshness contract at all.** Its base table is a hand-run sandbox object with nothing scheduling it and nothing recording when it last ran. Every governed store metric declares one (`T+1`, daily) | Productionise `mbr_mapping_v2` as a scheduled model, or accept that every pack number is as stale as the last manual run | **BLOCKED — owner, structural** |

## G. Coverage — metrics

**98 index rows, one gap each.** Ids are allocated mechanically: **index row *N* ↔ `G-(200 + N)`**,
so row 1 is `G-201` and row 98 is `G-298`.

**The rows are not duplicated here.** They live in **[metrics.md](./metrics.md) §2**, with their
source, `inventory_ref`, level, Doshi category, verbatim source-status and dedup rule. Maintaining
two copies of a 98-row list guarantees they diverge, and a diverged index is worse than a single one.

> **Class-level `next_action`, applying to all 98:** promote to a full `M-###` entry — which requires
> (a) locating its implementing card SQL, (b) fingerprinting that card, (c) establishing its
> `store_ref` or recording `none`. **Do not promote in id order.** Promote by the source's own
> priority signal: the Sheet's `Argus P1` rows and the inventories' `contested` rows first.

⚠️ marks the source's own highest-risk labels — `CONTESTED`, `MAJOR FINDING`, and every row whose
verbatim status names a bug. Those are in `metrics.md` §2's `source-status` column.

## H. Coverage — cards and surfaces not opened

| id | gap | next_action | status |
|---|---|---|---|
| **G-051** | **9 of 21 question cards on `dashboard/6406` were not opened** — 55554, 55620, 55612 (cancellations), 55555, 55583, 55585 (cancellation-time), 55610, 55540, 55601 (ETA). None feeds one of the 12 full entries | `get_card` on those nine. **A stated boundary, not implied coverage** | **OPEN — low** |
| **G-052** | **The card counts for `dashboard/1882` and `dashboard/4146` are unknown to this KB.** Only their Notion inventories were read; neither dashboard was opened via `get_dashboard`. Their *metric* counts (54, 34) are source-stated | One `get_dashboard` each. Until then, **no statement about their card-level coverage can be made** | **OPEN — low** |

---

## Closed

None yet. When one closes, **strike the id through** (`~~G-0xx~~`), keep the row **in place**, and
record the date and resolving ID. Consequences that outlive the closure get **new ids appended at
the end of the series**, never inserted ([CONTRIBUTING.md](./CONTRIBUTING.md) §8.3).

## Negative evidence — searched and confirmed absent

Distinct from *not looked at*. Recorded so nobody repeats the search.

| what was searched | result |
|---|---|
| `list_metrics(name="effective")` | **0 rows** — no effective-fulfilment metric in the store |
| `list_metrics(name="dap")` | **0 rows** — DAP has no store counterpart |
| `list_metrics(name="ata")`, `name="arrival"` | **0 rows** — no ATA metric in the store |
| `list_metrics(name="unique")` | 17 rows, **all** callback/SMS/SnC/wallet — no demand dedup |
| dbt metrics on `hcv_overall_demand_mart` | `metrics: null`, `downstream: []` — **no governed metric is defined on the pack's primary object** |
| `level0_mapping` column on `mart_partner_daily_performance_summary` | **not present** in what the catalog returned — bears on `G-023` |
