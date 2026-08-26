# GAPS.md — open questions, conflicts, and uncovered surface

`PNM-G-###` rows, append-only. Adding/closing rules: [CONTRIBUTING.md](./CONTRIBUTING.md) §11.
Seeded 2026-08-26 from the re-cut of `pnm-gem-knowledge.md` into row-addressed form.

**A gap is not a failure — it is a known unknown with an owner and a next action.** The dangerous
state is a fact that *looks* verified and isn't. Every row below has a `next_action` specific enough
to execute.

**Status:** `OPEN` · `BLOCKED` (needs a person or a decision) · `CLOSED` (with date + resolving id).

---

## A. Provenance and citation integrity

| id | gap | next_action | status |
|---|---|---|---|
| **PNM-G-002** | **Two PnM sources are untracked in git and therefore uncitable at a SHA** — `iteration-3-p80-orderedits-spec.md` (the sole source for `D8`–`D10`'s design) and `coverage-map/metric-coverage.json` (the only in-repo carrier of the 167-row Argus universe). Their bytes can change with no signal, and both are permanently capped at `unverified` (CONTRIBUTING §4.1) | Commit both to `main`, then re-point `PNM-S-032` and `PNM-S-037` from `local:` to `repo@<sha>:` and re-grade | **OPEN** |
| **PNM-G-003** | **PnM's strongest evidentiary rung cannot itself produce a `verified` row.** The MBR automation is out-of-repo, so it is `local:`-capped. The KB works around this by citing `sqlgen.py`, its in-repo mirror — but the workaround's validity rests entirely on the reconciliation staying true | Place the automation under version control, or record a hash of it per reconciliation run so the mirror claim is checkable | **BLOCKED** — owner |
| **PNM-G-004** | **The reconciliation covers a bounded slice, and the KB leans on it everywhere.** `V3` covers 2026-05 for leads/orders/derived/tpo; `V4` covers p80 (8 baseline months) and order_edits (Mar/Apr/May). Several metrics were **never individually reconciled** — the three channel conversions, all three order-mix metrics, and all ten TPO stage metrics | Extend the differential reconciliation to more months and to the per-channel and per-stage metrics; record which ids are covered, per month | **OPEN** |
| **PNM-G-006** | **No freshness check exists for the MBR automation.** It has no SHA readable offline and no `updated_at`. If the owner edits it, this KB has no way to notice | Same action as `PNM-G-003` | **BLOCKED** — owner |
| **PNM-G-007** | **`PROD_ELDORIA.MART.PNM_EXPERIENCE` is "still under active construction" and its schema has grown mid-project more than once** — once between two verifications a day apart. All 20 columns the catalog needs were present on 2026-07-29, but p80 and order_edits could break with no warning | Run the `INFORMATION_SCHEMA.COLUMNS` pre-flight before any execution round; needs an owner go-ahead per `PNM-B-034` | **OPEN** |
| **PNM-G-008** | **No Metabase card carries a staleness fingerprint in this KB.** Cards #30311 and #47576 both have an `updated_at`, so PTL's mechanic would work — it has simply never been run for PnM | One `get_card` per card; record `source_updated_at` on `PNM-S-010` / `PNM-S-011` | **OPEN** |

## B. Code behaviour that no document ratifies

*Read out of `sqlgen.py` / `metrics_registry.py`, so `verified` as **what the code does** — but
nothing states that it is **what the business intends**. That gap is the point of these rows.*

| id | gap | next_action | status |
|---|---|---|---|
| **PNM-G-011** | **The channel `CASE` falls through to `ELSE 'Mobile Website'`.** A lead with unknown or NULL `source` — and `source = 0` (Website), which has no branch of its own — is counted as **mobile web**, not "others". This inflates `leads_mobile` / `orders_mobile` and depresses `conversion_mobile`. No document justifies Mobile Website over an `Unknown` bucket | ⚠ **Now known to be governed intent, not an accident (2026-08-26):** the owner-approved `lead_channel` dimension carries the **identical** `ELSE 'Website (Mobile)'` (`PNM-S-051`). The question is no longer *is it deliberate* but *is it right*. **Size it** by counting leads hitting the `ELSE` branch, then take that number to the owner | **OPEN** |
| **PNM-G-012** | **Null-package orders are kept as non-Nano** — the filter is `(package_name NOT ILIKE 'Nano%' OR package_name IS NULL)`. `D4` rules on Nano and is silent on nulls | Ask the owner whether a NULL package should count as PnM; size the null population | **OPEN** |
| **PNM-G-013** | **The order dedup tiebreak is `ORDER BY fpo.opp_id DESC NULLS LAST`.** The registry calls it "deterministic" — which is not the same as correct. Nothing states why the **highest** `opp_id` is the right opportunity to inherit channel from | Ask the owner; measure how many `order_id`s have >1 in-window opportunity, and whether the choice changes any channel split | **OPEN** |
| **PNM-G-014** | **Two silent population filters nobody has sized.** (a) `FACT_PNM_ORDERS → PNM_CUSTOMERS` is an **INNER** join, so an order whose mobile has no customer row is dropped from the count entirely (`PNM-T-031`); (b) TPO tickets use `COALESCE(hst.shifting_type, c.shifting_type) = 'intra_city'`, a two-source fallback described in no document (`PNM-T-049`) | Count rows dropped by each; if material, record it as a caveat on `PNM-M-002` / `PNM-M-009` | **OPEN** |
| **PNM-G-015** | **The detractor filter is `COALESCE(raised_by,'') != 'Detractor'` — exact equality.** iteration-1 records the pipeline's filter as `LOWER(raised_by) LIKE '%detractor%'`. The two disagree on **case** and on **substring**: a value like `Detractor-Customer` or `detractor` is excluded by one and kept by the other | `SELECT DISTINCT raised_by FROM HS_TICKETS` — if only `'Detractor'` occurs, the two agree in practice and this closes cheaply | **OPEN** |
| **PNM-G-016** | **TPO ratios are `ROUND(…, 4)` while the automation emits 2dp**, and `V3` asserts they "round identically" without demonstrating it. An unproven precision claim sitting exactly at the reconciliation boundary | Re-run the 2026-05 comparison at full precision and confirm the 4dp→2dp rounding is stable | **OPEN** |
| **PNM-G-017** | **`UNSUPPORTED_TERMS` hardcodes 40 terms including 15 city names**, sourced to a code comment ("card #30311 pickers") that cannot be checked offline. **A city absent from the list would be silently answered PnM-wide** rather than refused — the exact failure the closed-world guard exists to prevent | Derive the city list from `DIM_GEO_REGIONS` instead of hardcoding it; until then, note the 15 guard terms cover 14 cities — `ahmedabad` and `ahemdabad` are two spellings of one — so **the counts do not disagree; the risk is a city missing from the list entirely** | **OPEN** |
| **PNM-G-041** | **"Only the owner promotes readiness" is stated only in a docstring.** It is the rule protecting every `prototype_only` number from reaching leadership, yet it rests on **registry prose (rung 7)**, is backed by **no owner ruling** — `D1` covers dry-run and production writes, not promotion — and is enforced by convention, not by code | Ask the owner to ratify it as a `DECISION_LOG` entry, which would move it to rung 1 and make `PNM-B-042` `verified` | **BLOCKED** — owner |
| **PNM-G-042** | **~18 `data-model.md` facts rest on a live schema read this KB did not perform.** The `INFORMATION_SCHEMA` read happened 2026-07-29 for other work and reaches this KB through a prose document's `[LIVE]` tags, so every column count, data type and absence claim is `unverified`. `PNM-T-032` (`HS_TICKETS` has no `ORDER_ID`) is the load-bearing one — it is an **absence** claim, the hardest kind to inherit | Re-run `INFORMATION_SCHEMA.COLUMNS` for the 11 catalog tables under an owner go-ahead, and upgrade the rows first-hand. Pairs naturally with `PNM-G-007`'s pre-flight | **OPEN** |
| **PNM-G-043** | **"`ota`'s six columns exist in no table" is only partly evidenced.** The registry's evidence checked **two** of the six by name (`scheduled_pickup_ts`, `vendor_arrived_ts`); the four coordinate columns are covered only by "the staging table never materialises them" | Check the four coordinate names directly when `PNM-G-024` is worked, so the blocked status rests on all six | **OPEN** |
| **PNM-G-018** | **`conversion_others` does not exist**, though `leads_others` and `orders_others` both do. ⚠ **Evidence it is deliberate (2026-08-26):** the Argus DD mirrors the absence exactly — it carries Conversion Overall/App/Desktop/Mobile (`PNM-059`…`062`) and **no "Conversion — Others" row** ([metrics.md](./metrics.md) §9.3) | Confirm with the owner, now against the DD evidence rather than cold. If deliberate, record the reason on `PNM-M-005` and close | **OPEN** |
| **PNM-G-019** | **`month_bounds()` still returns an unused `month_start_prev`**, "retained for API stability". It is the last trace of the two-month attribution window, whose removal **silently voided iteration-1 §2b#5's entire undercount analysis** — which remains unannotated in that file | Confirm no caller uses it, then decide: delete it, or annotate iteration-1 as superseded. Do not do both silently | **OPEN** |
| **PNM-G-020** | **The registry's `p80_durations.month_basis` still reads "calendar month of `o_completed_ts`"** — a legacy raw-table column `D3` established does not exist, and `D8` set the basis to `SHIFTING_TS_IST` | Correct the registry's `month_basis` string to `SHIFTING_TS_IST` | **OPEN** |
| **PNM-G-021** | **The registry's `ota.base_population` still reads "completed (`status=2`)"** — `status` is the legacy numeric column that does not exist on the re-pointed tables | Correct or delete the stale string when `ota` is unblocked (`PNM-G-024`) | **OPEN** |
| **PNM-G-022** | **`CONFIG_WIDE_FLAGS` still carries "Canonical methodology: Metabase card #30311" verbatim as a live open flag**, though `D6` ruled #30311 non-authoritative for PnM | Correct the comment **at source** in `config.py` (owner-held, not in this repo), then retire the flag | **BLOCKED** — owner |

## C. iteration-1 vs the owner rulings that superseded it

> `D5` states it "corrected **six** things my initial re-point had wrong". Those corrections landed in
> `sqlgen.py`; **iteration-1 was never annotated.** A reader who opens it gets wrong answers with no
> warning. Recorded here, **not silently resolved** — `PNM-S-030` carries the standing warning.

| id | question | iteration-1 says | `D4`/`D5` + shipped SQL say | next_action | status |
|---|---|---|---|---|---|
| **PNM-G-030** | Nano in orders | **INCLUDED** | **EXCLUDED** (`package_name NOT ILIKE 'Nano%'`) | Annotate iteration-1 as superseded — do not edit its definitions | **OPEN** |
| **PNM-G-031** | Order dedup key | first order per **`sr_id`** | per **`order_id`** | as above | **OPEN** |
| **PNM-G-032** | Cancelled orders | excluded via `status != 4` | **no cancelled filter** — all created orders count | as above | **OPEN** |
| **PNM-G-033** | Intra-city predicate | `service_type IN ('Default','Default_Short')` | `shifting_type = 'intra_city'` | as above | **OPEN** |
| **PNM-G-034** | TPO denominator unit | distinct **orders** | `COUNT(DISTINCT crn)` — distinct **CRNs**; cardinality stated nowhere | Establish whether one CRN can carry >1 order; if so, `orders_base` is not an order count and `PNM-M-008` needs restating | **OPEN** |
| **PNM-G-035** | TPO ticket join key | tickets joined by **`order_id`** | joined on **`crn`** — `HS_TICKETS` has no `ORDER_ID` at all, so iteration-1's join **could never have run** | Annotate iteration-1 | **OPEN** |
| **PNM-G-036** | Vendor-ticket predicate | IN-list `('Vendor-Owner','Vendor-Supervisor')` | `raised_by ILIKE 'Vendor%'` — a **prefix match** admitting any future `Vendor-*` value | `SELECT DISTINCT raised_by` — confirm no third `Vendor-*` value exists today | **OPEN** |
| **PNM-G-037** | TPO same-month attribution | tickets counted only if raised in the allocation-completion month — a **row-level filter** | two independent CTEs joined at `t.month = o.month`; **the tickets CTE is not restricted to the order base at all** | Confirm the aggregate is equivalent for a single month, and whether a ticket on a **non-base** order can enter the numerator | **OPEN** |
| **PNM-G-040** | p80 metric ids | `_mins`-suffixed (`p80_trip_duration_mins`, `num_successful_edits`, …) — **and `reference/README.md`, which is committed and tracked, still maps the baseline CSV columns to these names** | the automation's exact output-column names, lowercase, no `_mins` — required because `ask.py` lowercases every result column and does `row.get(metric_id)`, so a mismatched id **cannot resolve at all** (`DECISION_LOG:D9`) | Update `reference/README.md`'s mapping table to the shipped ids. It is the only *tracked* artifact still carrying the dead names, so it will mislead the next person to validate p80 | **OPEN** |

## D. Live-schema and source conflicts

| id | gap | conflicting positions | next_action | status |
|---|---|---|---|---|
| **PNM-G-023** | **The Notion schema guide disagrees with the live warehouse in five places** | Notion (2026-03-31 snapshot) vs `live:INFORMATION_SCHEMA@2026-07-29`: (1) `IS_MODIFICATION_DONE` BOOLEAN vs **TEXT** — the shipped `= 'Yes'` is correct, a boolean test would fail; (2) `PNM_EXPERIENCE` ~52 cols with no `SHIFTING_TS_IST` / `HAS_*_EDIT` / `NO_OF_SUCCESSFUL_EDITS` vs **71 cols, all present**; (3) `OTA_FLAG` BOOLEAN vs **TEXT** — any `OTA_FLAG = TRUE` predicate is wrong; (4) the two dims have no `USER_FLAG` vs **both have it** — so the mandatory filter is valid; (5) `PNM_SUPPORT.MODIFICATION_CATEGORY_LIST` VARCHAR vs **ARRAY**, its flags TEXT not BOOLEAN | **Regenerate the Notion guide from `INFORMATION_SCHEMA`** and add the two marts in `PNM-T-016`/`T-017`. Until then the live read wins (CONTRIBUTING §6 rung 4) | **OPEN** |
| **PNM-G-024** | **OTA's threshold is now SETTLED; its adoption is not.** | ~~Notion: 30 min + **500 m**. Pipeline: 30 min + **2 km**.~~ **TWO independent governed models now define it, and they agree on 30 min + 500 m.** `PNM_EXPERIENCE.OTA_FLAG` (`PNM-T-100`): completed + `distance_km < 0.5` + `shifting_started <= shifting_ts + 30 min`. `pnm_ota_capacity.sql` (`PNM-T-100a`): `action.action_time <= shifting_time + 30 min` + `ST_DISTANCE(pickup_location, action.location) <= 500` m. **Notion's 500 m was right; the pipeline's 2 km was wrong.** ⚠ **The remaining fork is the EVENT, not the threshold:** one anchors on **shifting-started**, the other on a **vendor action with GPS** — so the two governed models can legitimately return different OTA numbers | Owner to rule on **which event defines PnM's OTA**, then adopt that model. `pnm_ota_capacity` already emits `ota_percentage` **by city and slot**, so adopting it would unblock `ota` *and* deliver a city cut in one move | **BLOCKED** — owner *(threshold settled 2026-08-26; fork narrowed to the event)* |
| **PNM-G-025** | **The p80 settling period is now derivable, and needs ratifying rather than inventing.** `PNM_EXPERIENCE` rebuilds a **trailing 3-month window** (`partition_lookback: 3`, `PNM-T-101`) — which is exactly why recent months drift up to 0.84% and settled ones are bit-exact. **A month's p80 is structurally final once it falls outside that window** | Owner to ratify the implied rule — *"a p80 is final at M+3, because the mart cannot rewrite it after that"* — as a `DECISION_LOG` entry, then record it as a `PNM-B-###`. ⚠ The window is a **mart config that can change**; pin it to the SHA and re-check | **BLOCKED** — owner *(evidence supplied 2026-08-26)* |
| **PNM-G-026** | **`p80_vendor_accepted_to_sup_assigned` runs ~2,500–2,800 minutes (~2 days)** in every baseline month — an order of magnitude above every other stage. Either the stage genuinely takes two days, or the definition is wrong | Confirm the definition with ops before anyone quotes it. **Flag it rather than quoting it** meanwhile | **OPEN** |
| **PNM-G-027** | **Should `p80_vendor_accepted_to_sup_assigned` be answerable in plain English?** It is currently hidden by having no aliases. **The original reason recorded for hiding it was false** — "its name contains 'vendor' so it hits `UNSUPPORTED_TERMS`" — but bare `vendor` is not in the guard list, the guard runs on the question not the metric name, and adding it would break `tpo_vendor_raised`. It is a legitimate stage metric published in the baseline like its visible siblings | Owner decision, leaning **~55% keep hidden**. Expose (add an alias + an ANSWERABLE case) or confirm hidden — and either way correct the recorded reason | **BLOCKED** — owner |

## E. Document-vs-document and document-vs-code

| id | gap | next_action | status |
|---|---|---|---|
| **PNM-G-050** | **Metric count: `HANDOFF.md` §3 and `iteration-2` §1 both say the registry holds 25 metrics.** The registry holds **30** for the four original sections (leads 5 + orders 5 + derived 7 + tpo 13) — and **iteration-1's own section headings sum to the same 30**. So "25" disagrees with the code *and* with the catalogue it derives from: a stale figure, not code drifting past docs. With p80 (7) and order_edits (10) the current total is **47** | Correct both documents to 47, or annotate them as superseded | **OPEN** |
| ~~**PNM-G-052**~~ | ~~No mapping exists between the registry metric ids and the 167 Argus DD ids~~ | — | **CLOSED 2026-08-26** → [metrics.md](./metrics.md) §9. **42 of 47** catalog metrics map to **41** Argus rows; 5 are unmapped by design (4 raw channel order counts the DD does not track, plus the `orders_base` denominator). **16 Argus rows move `pending` → `partial`** once p80/order_edits are reflected. The mapping also independently confirmed three things — see §9.3 |
| **PNM-G-053** | **`docs/overview.html` is pre-iteration-3 and wrong in three ways** — says p80/order_edits are "not built", cites "31/31 tests" (now 54/54), and still presents the orders-source question as open, which `D3` closed on 2026-07-08 | Regenerate or annotate it. It is the most public-facing artifact in the repo | **OPEN** |
| **PNM-G-054** | **The committed dry-run report is not reproducible.** `is_month_in_progress()` is `today`-dependent, so re-running the suite silently changes the committed artifact — a re-run on 2026-08-14 dropped the `[MTD-labeled]` markers the 2026-07-08 version carries, with no code change behind it | Freeze the report's "as of" date, or inject `today` as a parameter so the artifact is deterministic | **OPEN** |
| **PNM-G-055** | **Five pairs of commits carry identical messages on divergent branches**, so a `repo@<sha>` citation written from a commit *message* rather than a hash could resolve to either twin | Always copy the SHA, never re-derive it from a message. Consider deleting the superseded branches once `main` is settled | **OPEN** |

## F. Naming and jargon

| id | gap | next_action | status |
|---|---|---|---|
| **PNM-G-060** | **"Packers & Movers" — the expansion of PnM — appears in no PnM or PTL source file in this repo.** It exists only in the out-of-repo workspace instruction file | Owner to confirm the expansion; add it to a source that lives in the repo | **OPEN** |
| **PNM-G-061** | **`CRN` is never expanded in any source.** "Customer reference number" is the Gem KB's own gloss, not a cited definition — and the token is load-bearing: `crn LIKE '%PNM%'` is how PnM work is identified in every shared table | Confirm the expansion and, more importantly, **what makes a CRN match `'%PNM%'`** — that predicate is the vertical's boundary | **OPEN** |
| **PNM-G-062** | **`LMS` is never expanded.** It appears as a coverage-map metric name (`% of orders contribution — LMS`) and a dashboard card label (`[DBT] Orders View(SCF+LMS)`). ⚠ **Partial evidence (2026-08-26):** the governed `lead_channel` dimension describes `source = 4` → `Generic` as **"Generic (LMS/broker/other)"**, so LMS sits inside the Others/Generic bucket — but the acronym itself is still unexpanded | Ask in `#pnm-analytics` for the expansion. This also gates whether `PNM-065` ↔ `pct_orders_others` is a safe mapping ([metrics.md](./metrics.md) §9.3) | **OPEN** |
| **PNM-G-063** | **`OTA`, `P80` and `TPO` expansions trace only to the untracked coverage map or to code**, never to a governed definition | Fold the expansions into a tracked source once `PNM-G-002` closes | **OPEN** |
| **PNM-G-064** | **Cross-vertical metric-name collisions.** "allocation", "conversion", "cancellation" and the `CBDF`/`CADF`/`CAC` family mean **different things** in PnM, PTL and HCV, and all three verticals now keep knowledge bases in this repo. PTL's KB records the same collision from its side | Never cite a bare `M-###` across verticals — the `PNM-` prefix (CONTRIBUTING §3) exists for this. A cross-vertical disambiguation layer is an Argus-level concern | **OPEN** |

## G. Coverage — what this KB does not cover

| id | gap | next_action | status |
|---|---|---|---|
| **PNM-G-070** | **The catalog cannot be cut by city or by week, and that is exactly what city ops will ask for.** The columns exist, the dashboards do it, but **no city- or week-level query has ever been reconciled**, so the catalog refuses. **This is the largest gap between this KB and its audience** | Owner/analytics decision: validate a city and weekly variant of the six sections, or route city ops to `PNM-S-020`/`PNM-S-021` permanently and say so out loud. ⚠ **The ground shifted 2026-08-26 on two fronts:** a **governed `pickup_city_name` dimension now exists** on the leads semantic model (`PNM-S-051`), so for **leads** a city cut is a semantic-layer query rather than new work; and **`pnm_ota_capacity` already publishes `ota_percentage` by city and slot** (`PNM-S-054`), so a city cut exists in production for at least one measure. The decision is now materially cheaper than when this gap was opened | **BLOCKED** — owner *(materially changed 2026-08-26)* |
| **PNM-G-071** | **The MBR automation runs 14 sections; this catalog covers 6.** Not answerable here: fare/coupon/surge (incl. **AOV**), vendor earnings percentiles, allocation quality (allocation %, deallocation %, completion %, allocation TAT p80, CAC/PAC/PoAC), wallet withdrawals/recharges, vendor TPO top-5 issues, add-on adoption, completion score, weekend contribution, Get-a-Call CTR, CAC-post-trip-started | Decide which of the 8 uncovered sections to mirror next. Several already have dashboards | **OPEN** |
| **PNM-G-072** | **Two governed marts the catalog does not read** — `PNM_ALLOCATION` and `PNM_FARE_MOVEMENT`. Both are live, refreshed every morning, already read by the MBR automation, and **both carry `IS_TEST_USER` and `IS_NANO_ORDER`**, which no table the catalog reads carries | Evaluate them as the source for allocation metrics **and** as the fix for `PNM-G-073` | **OPEN** |
| **PNM-G-073** | **Test orders are largely NOT excluded, and nothing says so to a reader.** `IS_TEST_USER` exists only on the two marts above. leads/orders gate on `user_flag ILIKE 'normal'` as their only user filter; **p80_durations and order_edits have no user or test filter at all** | Size the test-order population via `PNM_ALLOCATION`; if material, either add the filter (a definition change) or state the caveat on every affected metric | **OPEN** |
| **PNM-G-074** | **87 PnM dashboards exist; 17 are registered here** and filters were verified card-by-card for only 4 of them. Several sit in personal collections and may 403 | Resolve filters for the dashboards ops actually uses; ask in `#pnm-analytics` for access to the personal-collection ones | **OPEN** |
| **PNM-G-075** | **The Gem KB's §5 SQL template library is not reproduced in this KB.** Six month-parameterised templates were re-cut into metric blocks as *formulas*, not as runnable SQL | Decide whether the KB should carry runnable SQL at all, or point at `tests_output/rendered_*.sql` (`PNM-S-004`) as the executable record. **Pointing is probably right** — duplicated SQL drifts | **OPEN** |
| **PNM-G-076** | **140 of the 167 Argus DD metrics are `pending` / not started**, and 2 are `blocked` on an unavailable source | Not this KB's work to close, but the count is the honest denominator for any "PnM metric coverage" claim | **OPEN** |
| **PNM-G-080** | **Five live data-integrity issues affect neighbouring dashboards** (`PNM-S-040`…`S-044`) — the stalled `ameyo_webhook_events` feed since June 2026 being the most consequential still-open one | Track to closure in `#pnm-analytics`; re-check before quoting any dashboard that depends on them | **OPEN** |

## H. The governed dbt layer vs this catalog

*Opened 2026-08-26, when `porterin/DE-DBT-SNOWFLAKE` entered the KB's sources as rung 3.*

| id | gap | conflicting positions | next_action | status |
|---|---|---|---|---|
| ~~**PNM-G-090**~~ | ~~The governed `pnm_overall_leads` and this catalog's `leads_overall` do not compute the same number~~ | — | **CLOSED 2026-08-26 by owner ruling** (`owner-ruling:2026-08-26`). **Both are correct and they measure different things.** `pnm_overall_leads` is PnM lead volume **across all shifting types**; this catalog's metric is the **intra-city** subset and is to be renamed **`leads_overall_intra_city`** to say so. Neither is retired. → the rename itself is `PNM-G-093` |
| **PNM-G-093** | **The `leads_overall` → `leads_overall_intra_city` rename is ruled but NOT implemented.** The id appears in `metrics_registry.py` (`METRICS` key + aliases), in `sqlgen.py`'s `AGG_LEADS` column alias, in `ask.py`'s derived-metric lookups (`conversion_*` reference it as a denominator), in `run_tests.py`'s ANSWERABLE cases, and in the six rendered SQL fixtures. ⚠ **`ask.py` does `row.get(metric_id)`, so the id and the SQL alias must change together or every leads answer breaks** (`DECISION_LOG:D9`) | Rename across all five call sites in one change, re-run `run_tests.py` (54/54), re-render the fixtures, and re-reconcile one month to confirm the number is unchanged. **Until it ships, `leads_overall` in code still means the intra-city metric** | **OPEN** |
| **PNM-G-091** | **~20 PnM semantic models and ~25 doc ymls in the governed repo are unmined** — `dim_pnm_orders`, `fact_pnm_orders`, `fact_pnm_opportunity`, `pnm_customers`, `pnm_support`, `pnm_allocation`, `pnm_fare_movement`, **`pnm_ota_capacity`**, `pnm_base_query`, `pnm_growth_card`, `mart_pnm_invoices`, and the vendor/fare/rechurn models. Three files mined so far settled two owner-blocked gaps and opened one conflict — **the unmined remainder is likely to do the same** | Mine them in priority order: `pnm_ota_capacity` (bears on `PNM-G-024`), `dim_pnm_orders` + `fact_pnm_orders` (bear on `PNM-M-002` and `PNM-G-090`), then `pnm_support` (the `modification_category_list` behind every edit metric) | **OPEN** |
| **PNM-G-092** | **The tables this catalog reads have at least three different owners**, and the KB had recorded none of them: `dim_pnm_opportunity` → **HSC** (`#hsc-analytics`, domain PNM, though its own tags say `owner:NI_PNM`); `pnm_experience` → **DATA_ANALYTICS** (`#data-analytics-team`, domain CENTRAL_ANALYTICS); the `PROD_CURATED` application tables → unrecorded. Argus requires a **named owner** for any metric it admits (`PNM-B-071`) | Record the owner per table as the remaining doc ymls are mined (`PNM-G-091`), and resolve the `dim_pnm_opportunity` HSC-vs-NI_PNM tag inconsistency with the model's author | **OPEN** |

---

## Summary

| Group | Rows | Of which `BLOCKED` on an owner decision |
|---|---|---|
| A. Provenance & citation integrity | 6 | 2 |
| B. Code behaviour no document ratifies | 15 | 2 |
| C. iteration-1 vs owner rulings | 9 | 0 |
| D. Live-schema and source conflicts | 5 | 3 |
| E. Document-vs-document / vs-code | 5 | 0 |
| F. Naming and jargon | 5 | 0 |
| G. Coverage | 8 | 1 |
| H. Governed dbt layer vs this catalog | 4 | 0 |
| **Total rows** | **58** | **8** |

*58 rows exist; **2 are CLOSED** (`PNM-G-052`, `PNM-G-090`), leaving **56 live** — 48 `OPEN`, 8 `BLOCKED`.*

**The eight owner-blocked rows are the ones that cannot be closed by more analysis:** `PNM-G-003`
and `PNM-G-006` (put the automation under version control), `PNM-G-022` (correct the stale
"canonical" comment at source), `PNM-G-024` (which OTA threshold), `PNM-G-025` (when is a p80
final), `PNM-G-027` (expose the vendor stage metric or not), `PNM-G-041` (ratify the
owner-only-promotes rule so it stops resting on a docstring), and `PNM-G-070` (city/weekly cuts — now
**materially cheaper**, since a governed `pickup_city_name` dimension exists).

✅ **`PNM-G-090` closed 2026-08-26 by owner ruling** — the two lead metrics measure different
populations and both stand; ours is renamed to say so. The rename itself is `PNM-G-093`, and until it
ships **`leads_overall` in code still means the intra-city metric**.

⚠ **`PNM-G-024` and `PNM-G-025` narrowed on 2026-08-26** — the governed dbt layer supplied the
facts each was waiting for. Neither is closed: both still need an owner to *adopt* what the evidence
shows.
