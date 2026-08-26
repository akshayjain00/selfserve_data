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
| PNM-S-032 | **iteration-3 p80/order_edits spec** | The design behind `D8`–`D10`. ⚠ **Untracked in git — no SHA exists**, so it can only ever be cited `local:` and capped at `unverified` → `PNM-G-002` | `local:pnm-selfserve/iteration-3-p80-orderedits-spec.md` | unverified |
| PNM-S-033 | **HANDOFF.md** | ⚠ **Self-declares stale in its own header.** Where it and `DECISION_LOG` disagree, **the log wins** — it says so itself | `repo@851886f:pnm-selfserve/HANDOFF.md` | unverified |
| PNM-S-034 | **`docs/overview.html`** | ⚠ **Pre-iteration-3 and outdated:** says p80/order_edits are "not built" and cites "31/31 tests"; both are now wrong (54/54, both built). Still presents the orders-source question as open, which `D3` closed | `repo@5608e74:pnm-selfserve/docs/overview.html` | unverified → `PNM-G-053` |
| PNM-S-035 | **Notion "Eldoria PnM Schema Guide"** | ⚠ **Snapshot 2026-03-31, partly stale.** Contradicted by the live schema in **five** places; the mart grew 71 columns against its ~52. Rung 8 — the live read outranks it | Notion, via `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §7-Q2 | unverified → `PNM-G-023` |
| PNM-S-036 | **Notion MoM doc / Notion Demand DB** | `D6` makes the Demand DB a **reconciliation baseline** — a *value* authority, never a definition authority. The MoM doc is the methodology source `config.py` names alongside card #30311 | `notion:3599c6eaaa6d8016b554fc2e8e3bf577` | unverified |
| PNM-S-037 | **Argus PnM Metrics DD** — 167 rows | The metric universe PnM is expected to have. ⚠ Reached this KB only through `../coverage-map/metric-coverage.json`, which is **untracked** → `PNM-G-002`. Rung 8 | `local:pnm-selfserve/coverage-map/metric-coverage.json` | unverified |
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
