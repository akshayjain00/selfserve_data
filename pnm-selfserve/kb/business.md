# business.md — PnM business model, glossary, conventions

`PNM-B-###` rows. Schema and rules: [CONTRIBUTING.md](./CONTRIBUTING.md). Entry point: [CONTEXT.md](./CONTEXT.md).
All rows `last_verified: 2026-08-26`.

> **Why many rows here read `unverified`.** The confidence scale grades **evidence type**, not
> trustworthiness (CONTRIBUTING §5): `verified` requires underlying SQL, code, or an explicit owner
> ruling. Business context that lives only in a document can never clear that bar — and that is the
> correct signal, not a defect. Read `unverified` here as *"a document says so; no system confirms
> it."* The `verified` rows below are owner rulings (`DECISION_LOG` D1–D10) or facts read out of
> shipped code.

---

## What PnM is

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| PNM-B-001 | **PnM is Porter's house-moving vertical.** A customer says what they need moved and where; Porter quotes, the customer books, Porter allocates a vendor (a packing-and-moving crew with a vehicle) and a supervisor, the crew executes the move, and support handles what goes wrong. | `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §1 | unverified | Sourced from the Notion schema guide via the Gem KB. |
| PNM-B-002 | ⚠ **The expansion "Packers & Movers" is stated in no PnM or PTL source file in this repo.** It appears only in the out-of-repo workspace instruction file. | `local:ProdOps/CLAUDE.md` | unverified | The acronym is used everywhere and expanded nowhere in-repo → `PNM-G-060` |
| PNM-B-003 | **MBR = Monthly Business Review.** A 5-file weekly pipeline feeds it; this KB's catalog is the self-serve layer over the same logic. | `repo@851886f:pnm-selfserve/HANDOFF.md` §1 | unverified | The 5 pipeline files are **read-only and not in this repo** → `PNM-S-038` |
| PNM-B-004 | **The order lifecycle is:** customer interest → **opportunity** ("lead") → **order** ("booking") → fare calculation → vendor execution (accept → supervisor assigned → trip started → shifting started → pickup completed → order completed) → support & experience signals. | `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §1 | unverified | Stage timestamps: `PNM-T-020`. |
| PNM-B-005 | **One customer → many leads → each lead may become an order.** `SR_ID` is the thread tying a lead to its order. | `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §1 | unverified | Join keys: `PNM-T-030`. |
| PNM-B-006 | **Everything in this catalog is intra-city only** (`shifting_type = 'intra_city'`). Inter-city, vehicle-shifting and labour moves are out of scope. | `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` | **verified** | Leads additionally allow `shifting_type IS NULL` — a deliberate asymmetry (`PNM-T-041`). |
| PNM-B-007 | **PnM operates in 14 cities**, keyed by `GEO_REGION_ID`: 1 Mumbai · 2 Delhi · 3 Bangalore · 4 Hyderabad · 5 Chennai · 6 Ahmedabad · 7 Jaipur · 8 Pune · 9 Kolkata · 10 Surat · 11 Lucknow · 12 Coimbatore · 13 Indore · 14 Nagpur. | `live:INFORMATION_SCHEMA@2026-07-29` (`DIM_GEO_REGIONS`) | unverified | ⚠ The Metabase city picker spells Ahmedabad **"Ahemdabad"** and offers **"Delhi NCR"** — match on the picker's spelling, not this row's. |

## The Nano rule — the single most important business fact

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| **PNM-B-010** | **Nano packages are labour-only help — no vehicle, no vendor allocated — and belong to LA (Labour Assist), a different business group, not to PnM.** Package names: `Nano Shifting`, `Nano Shifting Medium`, `Nano Shifting Large`. | `DECISION_LOG:D4` | **verified** | Owner domain knowledge; derivable from no table. |
| **PNM-B-011** | **Leads INCLUDE Nano** — nano demand still arrives through the PnM funnel. | `DECISION_LOG:D4` | **verified** | ⚠ **CONTRADICTED for orders by iteration-1**, which says orders include Nano too → `PNM-G-030` |
| **PNM-B-012** | **Orders, TPO, p80_durations and order_edits EXCLUDE Nano** — those bookings are LA's. | `DECISION_LOG:D4`, `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` | **verified** | — |
| **PNM-B-013** | **Conversion is therefore asymmetric by design:** non-Nano orders ÷ Nano-inclusive leads. It reads slightly lower than a like-for-like ratio. **Never "correct" this.** | `DECISION_LOG:D4` | **verified** | → `PNM-M-005` |
| PNM-B-014 | **The Nano filter form differs by section on purpose:** prefix `NOT ILIKE 'Nano%'` for orders / p80 / order_edits; contains `NOT ILIKE '%Nano%'` for TPO, **applied to two different columns — `shifting_requirements.package_name` on the order side and `hs_tickets.hs_package` on the ticket side.** Faithful to two separately validated queries — **not to be unified.** | `DECISION_LOG` §3, `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` | **verified** | Listed by the log itself as an intentional non-conflict. |

## Date grains — the most common cause of "your number doesn't match mine"

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| **PNM-B-020** | **Each section counts on a DIFFERENT date, and they are not interchangeable.** leads → `opp_created_ts` · orders → `o_created_ts` · derived → both, same month · tpo → allocation completion (`completed_ts` +330 min → IST) · p80_durations → `SHIFTING_TS_IST` · order_edits → `ORDER_CREATED_TS_IST`. | `repo@851886f:pnm-selfserve/selfserve_nlq/metrics_registry.py`, `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` | **verified** | **A move booked in April and executed in May appears in April's order count and May's duration figures. Both are correct.** Always state the basis when quoting. |
| PNM-B-021 | **Every metric in this catalog is monthly.** There is no daily, weekly or quarterly metric. | `repo@851886f:pnm-selfserve/selfserve_nlq/metrics_registry.py` | **verified** | Weekly/daily questions are refused (`PNM-B-032`). Dashboards do have granularity controls → `PNM-S-011`, `PNM-S-021`, `PNM-S-023`. |
| PNM-B-022 | **The catalog is PnM-wide and cannot be cut by city.** City columns exist in the warehouse and the dashboards do filter by city, but **no city-level query has ever been reconciled**, so the catalog refuses city questions. | `repo@851886f:pnm-selfserve/selfserve_nlq/metrics_registry.py` | **verified** | ⚠ **This is the largest gap between the KB and its audience** — city ops will ask exactly this → `PNM-G-070` |

## House conventions — treat as non-negotiable

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| PNM-B-030 | **Aggregate-then-ratio.** Derived metrics are computed in Python from raw counts in one query — **never** by averaging stored ratios. | `DECISION_LOG:D7`, `repo@851886f:pnm-selfserve/selfserve_nlq/metrics_registry.py` | **verified** | Independently derived in PTL too — a Porter-wide convention, not a PnM house style. |
| PNM-B-031 | **Divide-by-zero returns NULL**, via `NULLIF(<denominator>, 0)`. | `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` | **verified** | — |
| PNM-B-032 | **Closed-world refusal.** Anything off-menu is refused, never improvised: uncatalogued metrics, city/region/zone/cluster/tier cuts, weekly/daily/quarterly grains, `median`/`p50`/`p90`/`p99`/`average of`, and per-vendor splits. 40 guard terms in total. | `repo@851886f:pnm-selfserve/selfserve_nlq/metrics_registry.py` (`UNSUPPORTED_TERMS`) | **verified** | ⚠ The 15 city names are hardcoded; a city absent from the list would be silently answered PnM-wide → `PNM-G-017` |
| PNM-B-033 | **An in-progress month is answered as MTD** and never presented as a final monthly number. Future months are refused outright. | `repo@851886f:pnm-selfserve/selfserve_nlq/ask.py`, `sqlgen.py` | **verified** | ⚠ MTD detection is `today`-dependent, so the committed test report is not reproducible → `PNM-G-054` |
| PNM-B-034 | **Dry-run is the default.** No production Snowflake or Sheet write without showing the exact SQL first and getting an explicit owner go-ahead. | `DECISION_LOG:D1` | **verified** | Path A — the owner runs on their own laptop. |
| PNM-B-035 | **The AI never authors SQL.** Credentials are exercised only inside `ask.py --execute`, which rejects any metric id not in the registry — enforced by the tool boundary, not by convention. | `repo@851886f:pnm-selfserve/iteration-1-metric-catalog-and-architecture.md` Part 3 | unverified | Architecture intent; the guard itself is `PNM-T-060`. |
| PNM-B-036 | **Never silently resolve a `⚠ VERIFY` flag** — surface it as an open question. | `repo@851886f:pnm-selfserve/HANDOFF.md` §7 | unverified | Standing house rule. |
| PNM-B-037 | **When presenting choices, attach a % confidence.** | `repo@851886f:pnm-selfserve/HANDOFF.md` §7 | unverified | Owner's standing rule as of 2026-07-07. |
| PNM-B-038 | **Bug-for-bug fidelity with quirks disclosed.** The layer replicates the validated automation's semantics including its quirks, disclosing them in the answer footer rather than silently "fixing" them. Correcting a semantic is a **definition change** and is the owner's call. | `repo@851886f:pnm-selfserve/selfserve_nlq/README.md` | unverified | The three shipped quirks: `PNM-M-021`, `PNM-M-030`, `PNM-B-014`. |

## Readiness — a second axis, and it is not confidence

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| **PNM-B-040** | **Readiness is per section**, inherited by every metric in it: `prototype_only` · `stakeholder_ready` · `blocked` · `not_built`. | `repo@851886f:pnm-selfserve/selfserve_nlq/metrics_registry.py` | **verified** | Full semantics: CONTRIBUTING §7. |
| **PNM-B-041** | **Nothing is `stakeholder_ready`. All six built sections are `prototype_only`; `ota` is `blocked`.** | `repo@851886f:pnm-selfserve/selfserve_nlq/metrics_registry.py`, `repo@851886f:pnm-selfserve/iteration-2-readiness-ledger.md` §4 | **verified** | Reconciling exactly with the automation does **not** promote a section. |
| **PNM-B-042** | **Only the owner promotes readiness**, by editing `metrics_registry.py` deliberately. No AI session may promote anything. | `repo@851886f:pnm-selfserve/selfserve_nlq/metrics_registry.py` (module docstring) | unverified | ⚠ **Registry *prose*, which is rung 7** — not an owner ruling. `DECISION_LOG:D1` covers dry-run and production writes, **not promotion**, so it cannot support this row. The rule is stated only in a docstring and is honoured by convention, not enforced by code → `PNM-G-041` |
| PNM-B-043 | **`verified` ≠ `stakeholder_ready`.** A metric can be `verified` (its SQL was read) and still `prototype_only` (not safe for leadership). Reporting one when asked for the other is a defect. | `repo@851886f:pnm-selfserve/selfserve_nlq/metrics_registry.py` | **verified** | CONTRIBUTING §7. |

## Glossary

| id | term | expansion | source_ref | confidence |
|---|---|---|---|---|
| PNM-B-050 | **PnM** | Packers & Movers — ⚠ **stated in no in-repo source** | `local:ProdOps/CLAUDE.md` | unverified → `PNM-G-060` |
| PNM-B-051 | **MBR** | Monthly Business Review | `repo@851886f:pnm-selfserve/HANDOFF.md` | unverified |
| PNM-B-052 | **TPO** | **Tickets Per Order** — support tickets ÷ orders. A quality/pain measure: **higher is worse** | `repo@851886f:pnm-selfserve/selfserve_nlq/metrics_registry.py` | **verified** |
| PNM-B-053 | **LA** | Labour Assist — the business group that owns Nano bookings | `DECISION_LOG:D4` | **verified** |
| PNM-B-054 | **Nano** | Labour-only help, no vehicle or vendor allocated | `DECISION_LOG:D4` | **verified** |
| PNM-B-055 | **SR** | Shifting Requirement — `SR_ID` threads a lead to its order | `repo@851886f:pnm-selfserve/iteration-1-metric-catalog-and-architecture.md` | unverified |
| PNM-B-056 | **CRN** | Customer Reference Number on the order; PnM orders match `'%PNM%'` — how PnM work is identified in shared tables | `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §3.7 | unverified → `PNM-G-061` |
| PNM-B-057 | **Opportunity / lead** | A customer requirement before commitment; becomes an *order* on booking | `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §1 | unverified |
| PNM-B-058 | **P80** | 80th percentile — **80% of moves were faster; the slowest 20% were slower.** Not an average: it describes the bad tail, which is why ops uses it | `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §2.5 | unverified |
| PNM-B-059 | **OTA** | On-Time Arrival — ⚠ **two conflicting definitions, no owner, section blocked** | `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §7-Q3 | unverified → `PNM-G-024` |
| PNM-B-060 | **Detractor** | An NPS classification (`Promoter` / `Neutral` / `Detractor`); also a `raised_by` value whose tickets are excluded from TPO everywhere | `live:INFORMATION_SCHEMA@2026-07-29`, `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` | **verified** (the filter) |
| PNM-B-061 | **MTD** | Month-to-date — how an in-progress month is labelled | `repo@851886f:pnm-selfserve/selfserve_nlq/ask.py` | **verified** |
| PNM-B-062 | **LMS** | ⚠ **expansion stated nowhere.** Appears only as a coverage-map metric name and a dashboard card label | `repo@03f1653:pnm-selfserve/coverage-map/metric-coverage.json` | unverified → `PNM-G-062` |
| PNM-B-063 | **Argus** | Porter's cross-vertical Metric Store programme | `repo@851886f:pnm-selfserve/iteration-2-readiness-ledger.md` §6 | unverified |

## Argus — the metric store this KB will eventually answer to

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| PNM-B-070 | **Argus's standing rule: no dbt model → not eligible for the metric store.** This prototype is explicitly the bridge until eligibility is met. | `repo@851886f:pnm-selfserve/iteration-1-metric-catalog-and-architecture.md` Part 3 | unverified | — |
| PNM-B-071 | **PnM already has an NI_PNM-owned dbt layer** in `PROD_ELDORIA` (fact/dim opportunity + orders, `mart.pnm_customers`, `pnm_support` / `experience` / `allocation`), with semantic models generated — so the eligibility rule may be moot for PnM sooner than planned. | `repo@851886f:pnm-selfserve/iteration-2-readiness-ledger.md` §6 | unverified | This is what made ruling `D3` possible. |
| PNM-B-072 | **The registry is deliberately shaped like a pre-YAML Argus metric definition**, so exporting to the governed format is mechanical when eligibility is met. | `repo@851886f:pnm-selfserve/iteration-1-metric-catalog-and-architecture.md` Part 3 | unverified | — |
| PNM-B-073 | Argus's confidence gradient: governed ≈ 100% · documented mart 75–65% · raw 55–50% · **below 50% refuse**. Convergent with this KB's own confidence scale and with `PNM-B-032`'s closed-world refusal. | `local:ProdOps/selfserve/project-argus-team-guide.html` | unverified | Both systems forbid guessing silently. |

## SNAPSHOT — reconciled values, 2026-05

> **Point-in-time values, not definitions.** Recorded as reconciliation anchors: if a query
> reproduces these, the definition behind it is probably right. They go stale by design and are
> deliberately kept out of the definition blocks in [metrics.md](./metrics.md) (CONTRIBUTING §8).
> Source: `DECISION_LOG:V3` and `DECISION_LOG:V4`. **These are the only values in this KB.**

| Metric | 2026-05 | Match vs the validated automation |
|---|---|---|
| `leads_overall` | 336,338 | exact |
| `orders_overall` | 51,277 | exact |
| `conversion_overall` | 15.25% | exact |
| orders app / desktop / mobile / others | 40,775 / 1,413 / 7,554 / 1,535 | exact |
| leads app / desktop / mobile / others | 234,449 / 11,164 / 67,197 / 23,528 | channels sum to overall |
| `orders_base` (TPO denominator) | 45,414 | exact |
| `tpo_overall` / `tpo_vendor_raised` | 0.9853 / 0.2988 (4dp) | rounds identically to the automation's 0.99 / 0.30 |
| `pct_orders_edited` | 61.09 | byte-identical mirror |
| `no_of_successful_edits` | 153,726 | byte-identical mirror |
| `location_adoption_pct` | 15.85 | = its duplicate `pct_orders_location_modified` |
| `edits_per_order` | 3.53 | byte-identical mirror |
| `pct_edits_after_shifting_started` | 36.61 | byte-identical mirror |
| order_edits `total_orders` (denominator, **not emitted**) | 43,529 | context only — `PNM-M-030` |

**p80 baseline reconciliation** (`DECISION_LOG:V4`): bit-exact for 2025-10/11/12; drift ≤0.84% on
recent months (worst: `p80_trip_duration` 2026-05, baseline 597 vs live 602) — well inside the ±2.5%
rule. The drift is the mart backfilling recent rows, not a logic error. `p50 ≤ p80_trip_duration`
holds in all 8 months. ⚠ **No policy exists for how old a month must be before its p80 is quotable as
final** → `PNM-G-025`.
