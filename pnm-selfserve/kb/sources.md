# sources.md — source artifacts and their freshness state

`PNM-S-###` rows. Schema and rules: [CONTRIBUTING.md](./CONTRIBUTING.md). Entry point: [CONTEXT.md](./CONTEXT.md).
All rows `last_verified: 2026-08-26`. Metabase base URL: `https://metabase.prod-internal.porter.in`

> **Why this file is `sources.md` and not `dashboards.md`.** PTL's KB files one row per Metabase card,
> because PTL's facts come from cards. **PnM's do not.** PnM has exactly two load-bearing cards, and
> one of them is *ruled non-authoritative* (`PNM-S-010`). Its real sources are four named automation
> queries, two Notion surfaces, a 167-row CSV, a baseline CSV and a legacy pipeline. The shelf keeps
> both of PTL's jobs — *where did this number come from* and *has the source moved* — and drops the
> assumption that the answer is a dashboard.
>
> **`freshness_check` is per source type** (CONTRIBUTING §9), because PnM has four different ones and
> most of its sources carry no `updated_at` at all.

---

## The operational sources — what the catalog is actually built on

| id | source | role | freshness_check | source_ref | confidence |
|---|---|---|---|---|---|
| **PNM-S-001** | **The owner's live-validated MBR automation** — `pnm_mbr_monthly_metrics/queries.py`, ~1,343 lines, **14 sections** | **Rung 2, the catalog's highest evidentiary source.** Its `LEADS_CONVERSION_QUERY`, `TPO_TREND_QUERY`, `TRIP_DURATION_PERCENTILE_QUERY` and `EDIT_ADOPTION_QUERY` are what every catalog section mirrors | ⛔ **none exists** — out-of-repo, no SHA, not readable offline → `PNM-G-006` | `local:ProdOps/pnm/pnm_mbr_monthly_metrics/queries.py` | unverified — **`local:` ceiling** (CONTRIBUTING §4.1) |
| **PNM-S-002** | **`sqlgen.py`** — the automation's **in-repo mirror** | **The citation route that makes `verified` possible.** Reconciled field-by-field against `PNM-S-001` at `DECISION_LOG:V3`/`V4` | re-read at the SHA — free, deterministic, offline | `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` | **verified** |
| PNM-S-003 | **`metrics_registry.py`** — the declarative catalog | Authoritative for which metrics exist, their aliases, quirks, and each section's `built` / `readiness` flags | re-read at the SHA | `repo@851886f:pnm-selfserve/selfserve_nlq/metrics_registry.py` | **verified** (behavioural fields) |
| PNM-S-004 | **`rendered_*_2026-05.sql`** — 6 files, one per built section | The exact SQL that ran in the reconciliation. §-for-§ evidence behind every `PNM-M-###` formula | re-read at the SHA | `repo@851886f:pnm-selfserve/selfserve_nlq/tests_output/` | **verified** |
| PNM-S-005 | **`reconciliation_2026-07-19.md`** | The live differential-reconciliation evidence for p80_durations and order_edits (`DECISION_LOG:V4`) | re-read at the SHA | `repo@851886f:pnm-selfserve/selfserve_nlq/tests_output/reconciliation_2026-07-19.md` | unverified — **a prose report of a run, not the run** |
| PNM-S-006 | **`reference/p80_durations_baseline_2025-10_to_2026-05.csv`** + its README | Owner-provided P80/P50 baseline, 8 months, the validation target for `PNM-M-020` under the ±2.5% drift rule | re-read at the SHA | `repo@851886f:pnm-selfserve/reference/` | unverified |
| PNM-S-007 | **`DECISION_LOG.md`** — D1–D10, V1–V4 | **Rung 1.** The owner's rulings and the verification record | re-read at the SHA | `repo@851886f:pnm-selfserve/DECISION_LOG.md` | **verified** (as a record of rulings) |
| PNM-S-008 | **`pnm-gem-knowledge.md`** — 86 KB, 9 sections, provenance-tagged | The compiled PnM knowledge base this KB was re-cut from. **Richer in narrative than this KB; this KB is richer in addressability.** Its §5 SQL template library is not reproduced here | re-read at the SHA | `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` | unverified (as a document) |

## The governed dbt layer — `porterin/DE-DBT-SNOWFLAKE`

*Added 2026-08-26. **Rung 3.** A merged dbt test is code, not prose — it clears §5's `verified` bar
for the thing it pins. This layer did not exist in the KB's sources until now and it settles two
questions the KB had recorded as owner-blocked.*

| id | source | what it governs | freshness_check | source_ref | confidence |
|---|---|---|---|---|---|
| **PNM-S-050** | **`dim_pnm_opportunity.yml`** — model docs + tests. Merged in **PR #3330** (Rashmi Dutta, 2026-08-17), which lifted its trust score 64 (C) → 100 (A) | `status` **`accepted_values` 0–4 with funnel labels** (`PNM-T-066`); `source` accepted_values 0–4; **`relationships` tests** `pickup_geo_region_id` / `drop_geo_region_id` → `dim_geo_regions` (`PNM-T-007`, `PNM-T-035`); `contains_pii: true`; **`user_flag` = "a flag to separate test and normal users"** (`PNM-T-082`) | re-read at the SHA | `dbt@ad4ab4e:models/docs/dim/dim_pnm_opportunity.yml` | **verified** |
| **PNM-S-051** | **`dim_pnm_opportunity_semantic.yml`** — semantic model + the governed metric **`pnm_overall_leads`**, `approved_by: akshay.jain@theporter.in`, 2026-08-11 | The **Argus-eligible** counterpart of `leads_overall` — ⚠ **and it does not match ours** (`PNM-G-090`). Also exposes governed **`pickup_city_name`** and **`lead_channel`** dimensions (`PNM-G-070`, `PNM-G-011`, `PNM-G-062`) | re-read at the SHA | `dbt@b00ad73:models/semantics/dim_pnm_opportunity_semantic.yml` | **verified** |
| **PNM-S-052** | **`pnm_experience.yml`** — model docs for the mart p80 and order_edits read | **`ota_flag`'s actual rule** — settles `PNM-G-024`; **`partition_lookback: 3`** (trailing 3-month rebuild) — settles `PNM-G-025`; derivations for `is_modification_done`, `no_of_successful_edits`, `has_support_edit`. Owner is **DATA_ANALYTICS / CENTRAL_ANALYTICS**, not NI_PNM | re-read at the SHA | `dbt@816fa40:models/docs/mart/pnm_experience.yml` | **verified** |
| **PNM-S-054** | **`pnm_ota_capacity`** — mart + docs, owner **NI_PNM** (`da.new_initiatives@theporter.in`), domain ANALYTICS_INFRASTRUCTURE | **Computes `ota_percentage` at `city_name` x `shifting_time` x slot (morning/afternoon/evening)**, alongside per-slot load. Carries the second governed OTA rule (`PNM-T-100a`) — which reads a **supervisor `ShiftingStarted` action**, the same event as `PNM-S-052`'s, so the two do **not** fork on the event (corrected 2026-08-27). ⚠ **OTA by city already exists in a governed model** — material to `PNM-G-024` *and* `PNM-G-070`, but on a **hardcoded 6-city mapping** (`PNM-T-108`), a denominator limited to orders with a `ShiftingStarted` action (`PNM-T-111`), and `ELSE 0` publishing absent data as 0% (`PNM-T-109`) | re-read at the SHA | `dbt@00437b8:models/mart/ni_analytics/pnm/pnm_ota_capacity.sql`, `dbt@816fa40:models/docs/mart/pnm_ota_capacity.yml` | **verified** |
| **PNM-S-055** | **`pnm_support`** — mart SQL + docs, owner **NI_PNM** | **The third governed on-time rule** — `on_time_arrival_flag`, 30 min, **no distance test**, and the only one of the three with a written description (`PNM-T-105`). Also settles that **`modification_category_list` is a one-hop derivation** — `ARRAY_AGG(category) … GROUP BY sr_id` in the `sr_mod_agg` CTE, bare-aliased in the final select (`PNM-T-107`). ⚠ And that `pnm_support` defines **its own slot boundaries**, different from `pnm_ota_capacity`'s (`PNM-T-114`) | re-read at the SHA | `dbt@77f9d63:models/mart/ni_analytics/pnm/pnm_support.sql`, `dbt@816fa40:models/docs/mart/pnm_support.yml` | **verified** |
| **PNM-S-056** | **`pnm_allocation` + `pnm_fare_movement`** — mart SQL + docs, owner **DATA_** | **The only two PnM marts carrying `is_test_user`**, computed identically and documented in both: `COALESCE(user_flag,'Normal') NOT ILIKE 'Normal%'` (`PNM-T-106`). Supplies `PNM-G-073`'s sizing method. ⚠ Both are `86.7 B` with **only one document validated** — docs only, no semantic model, no few-shot | re-read at the SHA | `dbt@6068580:models/mart/ni_analytics/pnm/pnm_allocation.sql`, `dbt@9d78831:models/mart/ni_analytics/pnm/pnm_fare_movement.sql`, `dbt@816fa40:models/docs/mart/pnm_allocation.yml` | **verified** |
| **PNM-S-057** | **`fact_pnm_orders` + `dim_pnm_orders`** — docs, semantic models, SQL. Grain *"one row per `order_id`"*, owner **NI_PNM**, `contains_pii: true` | **Confirms no governed metric competes with `PNM-M-002`:** `fact_pnm_orders_semantic.yml` has a `measures:` block (`order_count`, `total_final_fare`, `avg_trip_distance`) and **no `metrics:` block at all**, so nothing is Argus-eligible here — unlike the leads model. `not_null` tests on `final_fare` / `vendor_id` / `vendor_owner_id` are conditioned `where: "o_completed_ts is not null"`, which makes "only populated once completed" **code, not prose**. ⚠ `total_final_fare` sums a completion-only field on an `o_created_ts` timeline. ⚠ Two near-identical columns, `supervisor_accepted_olc_ts` and `supervisor_accepted_ts`, with nothing saying which is authoritative | re-read at the SHA | `dbt@816fa40:models/docs/fact/fact_pnm_orders.yml`, `dbt@417b33d:models/semantics/fact_pnm_orders_semantic.yml`, `dbt@fff66f5:models/docs/dim/dim_pnm_orders.yml` | **verified** |
| **PNM-S-058** | **The `*_validation.json` trust-score layer** — 40 PnM files, **29 distinct models**, `scoring_version: v5`, generated by `data-studio/validate-semantics` | **A ranked, self-maintaining discovery loop** for which governed models are worth mining, replacing ad-hoc PR reading. Each carries `trust_score.score`/`.grade`, `summary.ci_gates_passed`, `validated_at`. **Two eras:** everything validated 2026-04-13/05-04 is C–D with `ci_gates_passed: false`; everything from 2026-07-03 is B–A and passing. ⚠ Cannot be counted naively — 11 byte-identical duplicates and one off-schema file (`PNM-G-097`) | re-read at the SHA | `dbt@main:models/docs/**/*_validation.json`, `dbt@main:bulwark/allowlists.yml` | **verified** (read directly) |
| PNM-S-053 | **~15 further PnM semantic models and doc ymls** in the same repo — `fact_pnm_opportunity`, `pnm_customers`, `pnm_base_query`, `pnm_growth_card`, `mart_pnm_invoices`, `pnm_capacity`, `pnm_experience`, `pnm_la_mis`, `pnm_automated_mis`, `pnm_cancellation_data`, `pnm_penalty_goodwill_data`, `pnm_gst_daily`, `cge_pnm_paid_lead_attribution`, vendor/fare/rechurn models | **Still unmined.** Five were mined 2026-08-27 (`PNM-S-054`…`057`) and are no longer in this row. `pnm_experience_semantic.yml` exposes dimensions but no p80 or edit metric. **Pick the next by `PNM-S-058`'s ranking, not by guesswork** | re-read at the SHA | `dbt@main:models/` | unverified → `PNM-G-091` |

## Metabase — the two cards that matter, and why one is demoted

| id | source | role | freshness_check | source_ref | confidence |
|---|---|---|---|---|---|
| **PNM-S-010** | **Card #30311 — `[DBT] Conversion %`** · database 108 · 6,496 views. Returns `OpportunityCount`, `OrderCount`, `ConversionPercentage` per period. **9 filters**, including a real 14-city `City Name` picker | ⚠ **Named "canonical methodology" by `config.py` and RULED NON-AUTHORITATIVE by `D6`.** It strips Nano from **both** leads and orders and uses `service_type IN ('Default','Default_Short')` for intra-city, so **its conversion reads HIGHER than `conversion_overall`**. Reconcile against the MBR note / Notion Demand DB, **not** this card | `get_card` → compare `updated_at`. **Not yet fingerprinted** → `PNM-G-008` | `metabase:card/30311`, `DECISION_LOG:D6` | unverified |
| **PNM-S-011** | **Card #47576 — `TPO Trend`** · database 97. Returns `completed_orders`, `tickets`, `tpo` per period. **10 filters** incl. `Geo Region` (city) and `Granularity` | **The card the `tpo` section mirrors** — it enters at rung 2 as part of `PNM-S-001`, not as a card. ⚠ **It supports city and granularity; the catalog does not.** For "TPO in Bangalore last week", this card is the answer, not `PNM-M-009` | as above → `PNM-G-008` | `metabase:card/47576`, `DECISION_LOG:D5` | unverified |

## Metabase — dashboards to route questions the catalog refuses

*The catalog is monthly and PnM-wide (`PNM-B-021`, `PNM-B-022`). **These are where city, weekly and
off-catalog questions go.***

| id | dashboard | answers | source_ref |
|---|---|---|---|
| **PNM-S-020** | **PnM — Business Health** [dashboard/4076](https://metabase.prod-internal.porter.in/dashboard/4076) · 125 cards · 3,988 views · ★ **start here for business questions** | leads and conversion by source, booked/completed orders, **city splits**, cancellation, revenue and gross, package/add-on mix, discounts, surge, NPS/detractor, call-centre connect rates | `metabase:dashboard/4076` |
| **PNM-S-021** | **PNM — Operation Dashboard** [dashboard/4454](https://metabase.prod-internal.porter.in/dashboard/4454) · 82 cards · 4,097 views · tabbed · ★ **start here for ops / TPO / support** | 18 filters incl. **`nano_filter`**, `pickup_city_name`, `granularity_`, `order_status`, `package_name`, `issue` / `sub_issue`, `rasied_by` *(spelled that way in the URL)* | `metabase:dashboard/4454` |
| PNM-S-022 | **TPO Trend** [dashboard/6060](https://metabase.prod-internal.porter.in/dashboard/6060) · 5 cards | filterable TPO trend, issue-wise and sub-issue-wise views. Its main card is `PNM-S-011` | `metabase:dashboard/6060` |
| PNM-S-023 | PnM :: Demand [dashboard/6218](https://metabase.prod-internal.porter.in/dashboard/6218) | top-of-funnel, conversion, created orders (3 tabs); created-vs-shifting date, DoD/WoW/MoM, **city**, Nano include/exclude | `metabase:dashboard/6218` |
| PNM-S-024 | PnM :: AOP vs Actuals [dashboard/6104](https://metabase.prod-internal.porter.in/dashboard/6104) | monthly AOP vs actuals, orders, cancellation, revenue, paid vs organic; **normalised city buckets** | `metabase:dashboard/6104` |
| PNM-S-025 | PnM Demand Metacard [dashboard/6206](https://metabase.prod-internal.porter.in/dashboard/6206) | daily leads, bookings, completions, LMS share; origin/drop city | `metabase:dashboard/6206` |
| PNM-S-026 | PnM Demand :: Lead-to-Order Conversion [dashboard/6222](https://metabase.prod-internal.porter.in/dashboard/6222) | IC vs IA conversion by lead source (**Nano excluded**) | `metabase:dashboard/6222` |
| PNM-S-027 | NPS Dashboard PnM-City level [dashboard/1068](https://metabase.prod-internal.porter.in/dashboard/1068) | **NPS by city** | `metabase:dashboard/1068` |
| PNM-S-028 | [DBT] Feedback Dashboard : PnM Only [dashboard/1062](https://metabase.prod-internal.porter.in/dashboard/1062) · 4,306 views | customer feedback | `metabase:dashboard/1062` |
| PNM-S-029 | Others — Zones & Clusters [4826](https://metabase.prod-internal.porter.in/dashboard/4826) · Demand and Supply [4005](https://metabase.prod-internal.porter.in/dashboard/4005) · Growth Card [4166](https://metabase.prod-internal.porter.in/dashboard/4166) · CPO [2619](https://metabase.prod-internal.porter.in/dashboard/2619) · Daily Alert [6070](https://metabase.prod-internal.porter.in/dashboard/6070) · Analytics [1505](https://metabase.prod-internal.porter.in/dashboard/1505) · legacy PNM :: Dashboard [1132](https://metabase.prod-internal.porter.in/dashboard/1132) (45,492 views) | filters unresolved | `metabase:dashboard/*` |

*All dashboard rows: `confidence: unverified` — resolved from Metabase/Data Catalog **metadata only**
on 2026-07-29. **No card was executed and no MBR number was pulled.***

> ⚠ **Three traps on these dashboards.**
> 1. **Many Business-Health cards have an "- including nano" twin** created 2026-03-30/31 (e.g.
>    `[DBT] Conversion %` vs `[DBT] Sigma Conversions - including nano`). **The default card EXCLUDES
>    Nano.** Opening the wrong twin silently changes the population.
> 2. **The "City Split" cards have NO city filter — they emit one column per city.** Verified on
>    `[DBT] PNM :: Booked Order City Split` (#30433): 7 filters, none of them City Name. You **read**
>    the city off the result rather than filtering to it. Card #30311 is the exception — it does have
>    a real city picker.
> 3. **Do not use `PNM - Operation Dashboard - Duplicate`** ([6337](https://metabase.prod-internal.porter.in/dashboard/6337)) — a partial copy, 57 of 82 cards.
>
> **A `—` in a filters column means "not yet resolved", not "has no filters".** Filters were verified
> card-by-card only for #30311, #47576, #30433 and dashboard 4454. **87 PnM dashboards exist in
> total**; the 16 usable ones above (plus the do-not-use duplicate 6337) are those with the clearest
> ops relevance. Several sit in personal
> collections (1132, 1505, 1068) and may 403 → `PNM-G-074`.

## Documentary sources — superseded, stale, or weakest-rung

| id | source | state | source_ref | confidence |
|---|---|---|---|---|
| PNM-S-030 | **iteration-1 metric catalog** — the legacy 49-column pipeline catalogue | ⚠ **SUPERSEDED.** Documents a pipeline `D3` established could never execute; `D5` replaced it. **Its metric names (`p80_trip_duration_mins`, `num_successful_edits`, …) exist nowhere in the shipped system.** Rung 6. Read for history and cross-cutting caveats only — **six of its definitions are actively wrong** (`PNM-G-030`…`037`) | `repo@851886f:pnm-selfserve/iteration-1-metric-catalog-and-architecture.md` | unverified |
| PNM-S-031 | **iteration-2 readiness ledger** | Authoritative for the readiness **vocabulary** and for "nothing is READY FOR STAKEHOLDERS". ⚠ Its **per-section table is superseded** by `DECISION_LOG:V4` — it lists p80 and order_edits as NOT BUILT; both were built and reconciled 2026-07-19 | `repo@851886f:pnm-selfserve/iteration-2-readiness-ledger.md` | unverified |
| PNM-S-032 | **iteration-3 p80/order_edits spec** | The design behind `D8`–`D10`. ✅ **Tracked since 2026-07-19** (`83011b2`) — the `§4.1` `local:` ceiling no longer applies, so it is now re-readable at a SHA. ⚠ The tracked revision is the **board-reviewed** one (3 `[board-fix]` tags, 2026-07-14); an **older 2026-07-12 draft survives in the Desktop clone** — never copy that over it. Still `unverified` under `§5`, as a design document rather than code | `repo@83011b2:pnm-selfserve/iteration-3-p80-orderedits-spec.md` | unverified (as a document) |
| PNM-S-033 | **HANDOFF.md** | ⚠ **Self-declares stale in its own header.** Where it and `DECISION_LOG` disagree, **the log wins** — it says so itself | `repo@851886f:pnm-selfserve/HANDOFF.md` | unverified |
| PNM-S-034 | **`docs/overview.html`** | ⚠ **Pre-iteration-3 and outdated:** says p80/order_edits are "not built" and cites "31/31 tests"; both are now wrong (54/54, both built). Still presents the orders-source question as open, which `D3` closed | `repo@5608e74:pnm-selfserve/docs/overview.html` | unverified → `PNM-G-053` |
| PNM-S-035 | **Notion "Eldoria PnM Schema Guide"** | ⚠ **Snapshot 2026-03-31, partly stale.** Contradicted by the live schema in **five** places; the mart grew 71 columns against its ~52. Rung 8 — the live read outranks it | Notion, via `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §7-Q2 | unverified → `PNM-G-023` |
| PNM-S-036 | **Notion MoM doc / Notion Demand DB** | `D6` makes the Demand DB a **reconciliation baseline** — a *value* authority, never a definition authority. The MoM doc is the methodology source `config.py` names alongside card #30311 | `notion:3599c6eaaa6d8016b554fc2e8e3bf577` | unverified |
| PNM-S-037 | **Argus PnM Metrics DD** — 167 rows | The metric universe PnM is expected to have. Reached this KB only through `../coverage-map/metric-coverage.json`, which is ✅ **tracked since 2026-08-26** (`03f1653`) — the carrier is now pinnable, so the `§4.1` ceiling is lifted. ⚠ Still `unverified` under `§5`: the DD itself is out-of-repo and this is a projection of it, not the DD. Rung 8 | `repo@03f1653:pnm-selfserve/coverage-map/metric-coverage.json` | unverified (a projection, not the DD) |
| PNM-S-038 | **The 5-file MBR pipeline** — `config.py`, `queries.py`, `runner.py`, `validator.py`, `gsheet_client.py` | ⚠ **Read-only and NOT in this repo** — they were uploads. Never edit them. The origin of every `⚠ VERIFY` flag | `local:` (not in repo) | unverified |

## Known live data-integrity issues

*None touches the six catalog sections directly — but all affect neighbouring dashboards. **Check
this list before escalating a dashboard number that looks wrong.***

| id | since | issue | effect |
|---|---|---|---|
| PNM-S-040 | 2026-07-22 (**open**) | `ameyo_webhook_events` has had **no data flowing since June 2026** | call / rechurn metacards built on it may be wrong or empty |
| PNM-S-041 | 2026-07-13 | PnM vendor-bucket Google Sheet has duplicate rows (7-Jan-2026 batch, 78 vendors — same period, different bucket) | anything cut by `VENDOR_BUCKET_TYPE` may **double-count** |
| PNM-S-042 | 2026-06-22 | Default Short pricing model changed: `surge_rebate_campaign_id` is now always NULL and the 15% discount is baked into `base_fare` | **do not** reconstruct a DS price as `base × surge × 0.85` — it double-counts |
| PNM-S-043 | 2026-07-14 | `pickup_boundary` / `drop_boundary`: `is_active` being dropped for `status`, still NULL in Snowflake pending backfill | boundary-based logic may break |
| PNM-S-044 | 2026-07-31 (planned) | Vendor Aadhaar moved to encrypted storage; plaintext fields dropped | `vendor_onboarding_infos.aadhaar_number` is now ciphertext |

*All rows: `source_ref: repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §6 (reported in
`#pnm-analytics`) · `confidence: unverified` · → `PNM-G-080`*
