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
| `G-201`–`G-399` | **Class G only** — one per index row, allocated mechanically: index row *N* ↔ `G-(200 + N)` |
| `G-100`–`G-199` | **Reserved for new gaps.** Take the next unused number here |

**Ids were never renumbered to fit the class scheme.** [CONTRIBUTING.md](./CONTRIBUTING.md) §2.3
forbids renumbering, and re-pointing ~40 references across four committed files to gain tidiness
would risk a silently missed reference — a worse outcome than a non-contiguous range. **Class
membership is declared here, by section, not encoded in the number.**

`G-001`, `G-002`, `G-003` were never allocated — **retired, not reused.** (`G-003` added to this
line 2026-08-27: it sits below the declared `G-004` floor and was the only wholly unexplained hole,
which [CONTRIBUTING.md](./CONTRIBUTING.md) §2.3 says "reads as a mistake to the next reader".
Unallocated numbers *inside* the declared ranges — `G-015`–`G-019`, `G-025`–`G-029`, `G-039`–`G-049`,
`G-058`–`G-059`, `G-061`–`G-069` — are covered by those ranges' "non-contiguous" note and are
**not** retirements.)

---

## A. Metric-definition conflicts — highest priority

| id | gap | conflicting positions | next_action | status |
|---|---|---|---|---|
| **G-030** | **The denominator of Allocation %, FF % and E-FF % contains rows that can never reach the numerator** | `hcv_overall_demand_mart` is `so_orders FULL OUTER JOIN fact_orders`. For SO-only rows the whole `fo.*` projection is NULL *by construction* — column docs: *"`fo_driver_id` … **Null for SO-only rows**"*, *"`order_status` … **null for SO-only rows**"*. The pack's `COALESCE(order_status,5)` maps those NULLs to **5**, admitting every SO-only row into `total_placed`, where it then fails `fo_driver_id IS NOT NULL` unconditionally. **`NULL` is overloaded**: "no driver allocated" vs "no fact-order leg exists". Cards 55586/55529/55625 make a *different* call — `or order_status is null` sweeps SO-only into **CBDF** — a classification living only in card SQL | **SIZED 2026-08-14** by one owner-authorised query. **SO-only = 32,821 of 1,891,324 placed (1.74%) across May-Jul 2026 - but 4.88% in May vs 0.22% in Jun and 0.18% in Jul.** All 32,821 have `fo_driver_id` NULL **and** `order_status` NULL **and** zero completions - the by-construction claim is now **empirically confirmed**, not merely inferred from DDL. **Decision still needed:** exclude SO-only from the base, or classify as CBDF per the cards. Route to `sandip.dogra@theporter.in` (olc) | **OPEN - high, SIZED** |
| **G-031** | **Three denominators are live under the name "fulfilment"** | (i) **total** demand — cards 55586 (status filter commented out, so *wider* than any other), 28681 cte1, 38998, 39084 (raw `FACT_ORDERS` row count, no status filter); (ii) **unique** demand — 28681 cte2; (iii) **business-hours** placed orders — 33212 only. **Pack and store agree** on (i)-as-completed+cancelled; the dashboards are what diverge | Bring the dashboards onto the pack/store position, and decide separately whether the business-hours variant is a **distinct metric** or a **defect**. This is the denominator of the north star (`D-011`) | **BLOCKED — owner** |
| **G-032** | **Two governance chains disagree on the allocation key, across three source models** | Pack + all `6406` cards use **`fo_driver_id`**; `metric.porter.allocated_orders` / `allocation_rate` use **`driver_id`** (`fact_orders`, owners `thejas.ravi@` `utkarsh.dixit@` `sanjeev.mishra@`, approved 2026-08-07, **hourly**); `metric.porter.cadf` also claims `driver_id` but **in prose only** — its `calculation_logic` is just `SUM(cadf)` (owners `vinay.nadig@` `lfc.da@`, approved 2026-06-19, daily). `fo_driver_id` exists in **exactly one model platform-wide**; `driver_id` in **414** | Route jointly to `sanjeev.mishra@theporter.in` (ALLOCATION) **and** `sandip.dogra@theporter.in` (olc) — this is not one owner's call | **BLOCKED — owner, structural** |
| **G-033** | **Revenue and AOV each have multiple live definitions** | Revenue: four formulas on `1882`, plus the pack's, plus `metric.porter.revenue` (**identical to the pack's**). AOV: three on `1882`, one on `4146` (card 32713), plus `metric.porter.average_order_value` — Finance-MIS lineage, **job-end-date** axis, numerator adds cashback + premium_discount + porter_gold + rewards_coins on a GST-stripped base | Owner picks one canonical revenue **and** one canonical AOV. Note the pack's revenue **already matches the governed metric token-for-token**, so revenue is nearly settled; AOV is not | **BLOCKED — owner** |
| **G-034** | **Card 28681 carries two competing E-FF definitions differing on two axes at once** | Live (cte1, `trucks_daily_demand_summary`): `SUM(completed_orders) / SUM(DEMAND - cadf_customer - cbdf_customer)`. Computed but suppressed at projection (cte2, `trucks_unique_demand_summary`): `… / SUM(DEMAND - cadf_cac - cbdf_cac)`. **Different attribution columns AND different source marts**, both aliased `effective_fulfillment`. The pack uses a third construction — a single `customer_cancelled` term from `dim_cancel_reasons_attribution` | Confirm which attribution basis is canonical, and whether `cac` denotes customer-attributed cancellation. **Column semantics were not looked up** — do that first | **BLOCKED — owner** |
| **G-035** | **Unique demand has two independent implementations, never compared** | The pack computes dedup from scratch (100 m / 100 m / 60 min / `order_status = 5`, `LEAD` over `customer_id`). Card 28681 reads a **pre-computed** `unique_demand` column from `trucks_unique_demand_summary` | Compare the mart's dedup rule against `B-062`. If they differ, Unique FF % differs between pack and dashboard by the difference in duplicate counts | **OPEN — high** |
| **G-036** | **Pack and store time-to-accept measure different things** | Pack: **percentiles**, clocked `order_time → fo_trip_accepted_time`, per **order**, capped `0–3600s`. Store `avg_time_to_accept_seconds`: a **mean**, clocked **notification-sent → acceptance**, per **notification batch**, **no outlier guard**. The pack's interval **strictly contains** the store's. Card 55503 is on a **third** clock (accept → trip start) | Do not present them as one metric at different precision. If a single governed measure is wanted, propose an order-clocked percentile metric to `sanjeev.mishra@theporter.in` | **OPEN — high** |
| **G-038** | **Three login thresholds are in play and none is governed for HCV** | Pack: `> 0.5 business_login_hours` per driver-day. Store sibling `total_login_days`: `> 0 total_login_hours`. Pack prose: *"at least 1 hour"*. `list_metrics(name="dap")` returns **0 rows** — the DAP the pack anchors to has **no store counterpart** | Owner picks one threshold and one column (`business_` vs `total_login_hours`); then declare DAP in the store | **BLOCKED — owner** |
| **G-081** | ⚠ **`G-030` REVERSES the reported FF % trend May-Jun 2026** | As reported, FF % rises **+1.30 pp** (54.57 to 55.87) and reads as improvement. Corrected for `G-030` it **falls -1.38 pp** (57.37 to 55.99). The distortion is **-2.80 pp in May and -0.12 pp in Jun** - the reported gain is largely the artifact disappearing. Values: [business.md](./business.md) §7 | **Establish why the SO-only share collapsed 22x between May and June** - pipeline change, backlog clearing, or a matching-logic change. Until known, **do not present a May-vs-June HCV fulfilment trend**; then restate any published May-2026 FF % figure | **OPEN - high, ESCALATED** |
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
| **G-050** | **31 cards this KB cites have no staleness fingerprint** | One `get_card` each for: **28688, 39506, 28691, 28692, 28693, 37311, 28195, 29553, 29559, 28673, 28669, 28678** (`1882` revenue/AOV family) and **32645, 32668, 32694, 32670, 32687, 32700, 33106, 33133, 33269, 32927, 36946, 32950, 28841, 28843, 28844, 28845, 29910, 39374, 43512** (`4146` families). **A literal executable list — not "sweep the dashboards."** PTL's equivalent has sat open since 2026-07-30 because its action was not specific enough | **OPEN — mechanical, do next** |
| **G-014** | The four dimension filters on `6406` (`vehicle_id`, `vehicle_mapping`, `city_name`, `Tier`) are correctly wired in **card** SQL as `[[and {{…}}]]` blocks with real aliases. Whether the **dashboard-level** parameters map through is **not determinable from the API response** | One UI check on `dashboard/6406` | **OPEN — mechanical, do next** |
| **G-004** | Nothing records **why `order_status` is ever NULL** beyond SO-only rows, yet `COALESCE(…,5)` silently makes every NULL a cancellation (12 occurrences) | Confirm SO-only is the only NULL source. If not, the `COALESCE` mislabels a second population | **OPEN — high** |
| **G-005** | `order_time`'s fallback chain means a **scheduled order with no FO leg is dated by its slot start, not its booking time** — so monthly counts mix two time semantics | Quantify how many rows use the fallback; decide whether to split the axis | **OPEN — low** |
| **G-010** | **Units of `oms_public.order_fares.fare` are undocumented** (`description: null`). Four independent lines indicate **rupees**, not paise — but no source states it | One value read for a known HCV order: a ~₹5,000 trip reads `5000.xx` if rupees, `500000` if paise. Needs owner authorisation | **OPEN — low** |
| **G-020** | **HCV's business posture — stage, unit economics, margin, strategic priority — is recorded nowhere in this KB's sources** | Ask the vertical owner. Not resolvable by more searching | **BLOCKED — owner** |
| **G-021** | **No source records HCV interventions or GTM events** — pricing changes, city launches, campaigns — so **no trend movement in HCV can be attributed** | Ask ProdOps for a dated intervention log | **BLOCKED — owner** |
| **G-024** | **`business.md` §7 is populated but only narrowly** — month × overall FF % and Allocation % for May–Jul 2026 exist; **revenue, AOV, and every category and distance split do not** | ⚠️ **Premise corrected 2026-08-27.** This row read *"§7's snapshot is **empty** — no number in this KB has been warehouse-validated"* and told the reader to *"run the pack for one month with owner authorisation and populate the snapshot"*. **That was already done** — `3dc65fd` (2026-08-14 **18:01**) added `B-091` and an 8-row snapshot table under `D-027` / `OWNER:2026-08-14`, and `G-081` quotes its figures. **This row was written by `dc898d4` (2026-08-14 **06:25**), about twelve hours before the snapshot existed, and was never revisited** — `5ab2bcb` (2026-08-18) touched `GAPS.md` but not this line. It went stale by neglect, not by surviving a re-edit. **Executing the old `next_action` verbatim would have re-run a production query that had already been run**, against `CONTEXT.md` hard rule 1. Residual scope only: populate **revenue and AOV** once `T-030`/`G-010` settle the rupees-vs-paise unit, and the **category and distance splits** once `mbr_mapping_v2` is rebuilt (`T-073`). Both preconditions are still open, so this stays blocked — on a smaller thing than it claimed | **BLOCKED — owner** |

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

**107 index rows, one gap each.** Ids are allocated mechanically: **index row *N* ↔ `G-(200 + N)`**,
so row 1 is `G-201` and row 107 is `G-307`.

**The rows are not duplicated here.** They live in **[metrics.md](./metrics.md) §2**, with their
source, `inventory_ref`, level, Doshi category, verbatim source-status and dedup rule. Maintaining
two copies of a 107-row list guarantees they diverge, and a diverged index is worse than a single one.

> **Class-level `next_action`, applying to all 107:** promote to a full `M-###` entry — which requires
> (a) locating its implementing card SQL, (b) fingerprinting that card, (c) establishing its
> `store_ref` or recording `none`. **Do not promote in id order.** Promote by the source's own
> priority signal: the Sheet's `Argus P1` rows and the inventories' `contested` rows first.

⚠️ marks the source's own highest-risk labels — `CONTESTED`, `MAJOR FINDING`, and every row whose
verbatim status names a bug. Those are in `metrics.md` §2's `source-status` column.

**The two rows below are about the `coverage-map` projection itself, not about an index row.**

| id | gap | conflicting positions / evidence | next_action | status |
|---|---|---|---|---|
| ~~**G-082**~~ | ⚠️ **`coverage-map` asserted `not-started` for metrics that are demonstrably started** | It stamped **all 118 rows** `status: pending`, `blocker: not-started`, `north_star: null` and one identical `blocker_note` — a uniform stamp, not an assessment. On the **6** rows that a full `M-###` entry retires, and against the north star designated by `D-011` (`OWNER:2026-08-14`), that was **factually wrong** | **CLOSED 2026-08-27** by `coverage-map/derive.py`, which derives `status`/`blocker`/`source`/`resolves_to`/`kb_row` from `metrics.md` §1+§2 and sets `north_star` from `M-001`. Mix is now **6 partial / 112 pending**; `derive.py --check` fails on drift. **The original "counts a different universe" charge was itself a unit error** — the map's **118** is the Argus DD's *row* count and this KB's **119** is its *deduped distinct-metric* count. Those are the two units `metrics.md` §3 opens by separating (`D-015`); they were never two answers to one question. The real count finding is `G-100` | **CLOSED — resolved by `derive.py`, 2026-08-27** |
| **G-083** | The `coverage-map` cited **the wrong artifact** for all 118 rows | It cited `ProdOps/02_specs_plans_logs/specs/2026-08-07-hcv-metric-mapping-design.md:17`. That line is **three sentences *about* a CSV** — a bolded lead *"The Argus catalogue defines metrics, not computations."*, then *"`01_reference_readonly/migrated_context/HCV_Metrics_DD.csv` holds 118 HCV metrics (109 Snowflake-sourced, 37 at L0), but carries prose definitions and dimension lists — no table names, no filter expressions."*, then *"`Status` is `Pending` on much of it."* — and it contains **none of the 118 rows**. The rows come from that CSV, which the spec only summarises. Verified 2026-08-27: the CSV's `level` tally (L0 37 · L1 69 · L2 12), `classification` tally (Health 12 · Usage 37 · Adoption 17 · Satisfaction 29 · Outcome 23) and `system` tally (Snowflake 109 · Amplitude 5 · DataDog 3 · Jira 1) are **each identical to the JSON's**, and its 113 distinct metric names overlap the JSON's 113 with **zero difference either way**. ⚠️ The **thread-owner tally does not match, on exactly one row** — see `G-103` | **Partly done 2026-08-27.** `derive.py` now cites the CSV row-wise (`…/HCV_Metrics_DD.csv:<line>`) for the 20 unindexed rows and `metrics.md` for the 98 indexed ones — the same citation form PnM's re-derivation already uses in `pnm-selfserve/coverage-map/metric-coverage.json`, whose rows cite `ProdOps/01_reference_readonly/migrated_context/PnM_Metrics_DD.csv:<line>`. **Committing the design spec would not help and is no longer the action.** Residual: the CSV lives in a read-only reference zone outside this repo, so under [CONTRIBUTING.md](./CONTRIBUTING.md) §3 these rows stay **`unverified`** on citation form regardless — and independently stay `unverified` under §4 because the CSV *asserts* definitions rather than implementing them. **Two caps, both binding; fixing the citation lifts neither.** | **OPEN — low** |
| **G-100** | ⚠️ **`gsheet:HCV_Metrics_DD` and `coverage-map` are the SAME artifact, so "a fourth source arrived" is false and the Sheet's row count is wrong** | The KB records two sources: `gsheet:HCV_Metrics_DD` at **"90 rows — counted, not estimated"** (`metrics.md` §2) and `coverage-map` as **118 rows from a fourth source** (`D-028`, `metrics.md` §3 delta). **They are one artifact:** `01_reference_readonly/migrated_context/HCV_Metrics_DD.csv`, **118 data rows**, and `HCV-NNN` **is** CSV row *NNN*. Proof, four independent ways: (i) every `gsheet:<row>` citation in this KB resolves exactly — `15`→CBDF, `19`→CADF, `20/21/22`→Customer/Porter/Partner CADF, `31`→"Dry Run", `78`→"Fare breach", `88/89/90`→CADF/CAC/PAC; (ii) `metrics.md` §2 cites gsheet rows **1–90 and nothing above 90** (max cited = 90); (iii) §2b's *"`Status` lands at index 22 for **84** rows and index 21 for **6**"* — the offset rows are data rows **4, 25, 48, 50, 53, 54**, all ≤ 90, and **84 + 6 = 90** exactly, while over the full file it is **112 + 6 = 118**; (iv) the 8 "new identities" are CSV rows 103–115 and the `Finance`-on-AOV value appears **only** in rows 91–118. **So the 2026-08-14 build read rows 1–90 of a 118-row file and recorded 90 as the file's length.** No fourth source ever arrived — the same source was re-read more completely | **Owner call, do not resolve here** ([CONTRIBUTING.md](./CONTRIBUTING.md) §6 absolute exception). The §3 chain `178 − 25 − 57 + 3 = 99` is arithmetically sound *for the 90 rows it read* and is left intact and auditable. Deciding whether the raw base becomes **206 across three sources** (54 + 34 + **118**) and what that does to the **119** total is the owner's, because it moves this KB's headline count. Bring `G-101` to the same decision | **BLOCKED — owner, structural** |
| **G-101** | **20 rows of the Argus DD were never indexed by this KB, and nothing recorded the boundary** | Of CSV rows 91–118, **8** were harvested into `metrics.md` §2 rows 100–107; the other **20** — rows 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 108, 109, 111, 112, 114, 116, 117, 118 — appear in **no** §1 entry and **no** §2 index row. **15 of the 20 carry names that appear nowhere in the KB** (case-insensitive match; exact-case gives **17**, because rows 95 `Sprinklr Sessions created (Px)` and 111 `Avg Order rating` differ from `metrics.md` only in capitalisation — 15 is the right semantic reading, but the figure is method-dependent): `PoAC` · `Order-related TPO rate (Px)` · `Order-related TPO rate (Cx)` · `Sprinklr Sessions created (Px)` · `% Orders with Manual fare adjustment` · `Underpayment %` · `Total Placed Orders` · `Wallet Share` · `Transactions per user per month` · `M1 Retention` · `CBDF + CADF (CAC)` · `Time to Cancel` · `% Orders with pick up delay` · `% Orders with fare breach` · `ETA distribution`. **This KB's own §2d already names several of them** (Order-related TPO Px/Cx, % orders pickup delay, % orders fare breach, OLC CADF/CAC/PAC) when assigning thread ownership — so they were *seen* and not *indexed*. Consequently `metrics.md` §3's *"**110** map to metrics already covered or indexed"* is wrong: only **90** sheet rows were ever indexed, so **98** of 118 are accounted for and 20 are not — **overstated by 20** | Decide per row whether it is a **new identity** or a **duplicate of an already-indexed one** (row 98 "Total Placed Orders" vs row 27 "Total Placed orders"; row 99 "Unique Demand" vs row 28; row 117 "% Orders with fare breach" vs row 78 "Fare breach" are the likely duplicates). **Do not assume all 20 are new** — that is exactly why the count is not corrected here. Each is `pending` / `blocker: source-unread` in `metric-coverage.json` and traceable by `kb_row: G-101` | **OPEN — high** |
| **G-102** | **`G-060`/§2c's "the Sheet supplies 18 Satisfaction metrics" matches neither reading of the Sheet** | The artifact's `Metric Classification` column holds **29** `Satisfaction` rows over all 118, and **17** over rows 1–90. The stated **18** is neither. Both Notion inventories independently stating their dashboards carry **none** is unaffected — the divergence `G-060` describes is real and, at 29 vs 0, **larger** than recorded | Restate `G-060`'s figure to **29** once `G-100` settles which row universe the Sheet legs of §3 are counted over. Left unfixed here so one owner decision covers all three rows | **OPEN — low** |
| **G-103** | ⚠️ **The `coverage-map` transcription lost one cell, and this KB's §2d repeats the loss** | The six short rows of `G-079` are misaligned by **two** columns, not one, so the `Rightful Thread owning the metric` value sits at cell index **23** on those rows and index **24** on the other 112. Reading index 24 uniformly — which both the `coverage-map` transcription and this KB's own first check did — silently drops **row 4, `L4 Tickets` → `Core Platforms`**. Shift-aware, the CSV carries **31** thread-owned rows with **Core Platforms 7**; the JSON carries **30** with **Core Platforms 6**, and `metrics.md` §2d publishes the JSON's figures. **Exactly one row differs; the other 117 agree.** Found by a blind check on 2026-08-27 after the author's own audit reproduced the same off-by-one and asserted the tallies matched | Two things, both mechanical. (a) `derive.py` must not propagate it: it deliberately leaves the descriptive fields alone, so **fix `cross_thread` on `HCV-004` at source** — this is the one descriptive cell known wrong, and until it is fixed the JSON's `cross_thread` is `unverified`. (b) Restate `metrics.md` §2d to **31 of 118**, **Core Platforms 7**, and add `L4 Tickets` to the Core Platforms list. **Do not re-read the other five short rows' owners as non-blank** — shift-aware, rows 25, 48, 50, 53, 54 are genuinely blank | **OPEN — mechanical, do next** |

## H. Coverage — cards and surfaces not opened

| id | gap | next_action | status |
|---|---|---|---|
| **G-051** | **9 of 21 question cards on `dashboard/6406` were not opened** — 55554, 55620, 55612 (cancellations), 55555, 55583, 55585 (cancellation-time), 55610, 55540, 55601 (ETA). None feeds one of the 12 full entries | `get_card` on those nine. **A stated boundary, not implied coverage** | **OPEN — low** |
| **G-052** | **The card counts for `dashboard/1882` and `dashboard/4146` are unknown to this KB.** Only their Notion inventories were read; neither dashboard was opened via `get_dashboard`. Their *metric* counts (54, 34) are source-stated | One `get_dashboard` each. Until then, **no statement about their card-level coverage can be made** | **OPEN — low** |

---

## Closed

**52 gap rows · 1 closed · 13 `BLOCKED` · 31 `OPEN` · 7 class-E/E2 rows carrying no status cell**
(class E's `next_action` is "do nothing — record it", so those tables omit the column per
[CONTRIBUTING.md](./CONTRIBUTING.md) §2.1). Recounted 2026-08-27.

| id | closed | resolved by |
|---|---|---|
| ~~`G-082`~~ | 2026-08-27 | `coverage-map/derive.py` — coverage fields are now derived from `metrics.md`, not asserted. Spin-offs `G-100`, `G-101`, `G-102` carry what outlived the closure |

When one closes, **strike the id through** (`~~G-0xx~~`), keep the row **in place**, and
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
