# business.md — PTL business model, glossary, conventions

`B-###` rows. Schema and rules: see [CONTRIBUTING.md](./CONTRIBUTING.md). Entry point: [CONTEXT.md](./CONTEXT.md).
All rows `last_verified: 2026-07-29`.

> **Why almost everything here reads `unverified`.** The confidence scale grades **evidence type**,
> not trustworthiness (CONTRIBUTING §4): `verified` requires underlying SQL, code, or an explicit
> owner ruling. Business context lives in documents, so it can never clear that bar — and that is
> the correct signal, not a defect. Read `unverified` here as *"a document says so; no system
> confirms it."* Metric formulas are held to the stricter bar in [metrics.md](./metrics.md).

---

## What PTL is

| id | statement | source_ref | confidence | aliases | note |
|---|---|---|---|---|---|
| B-001 | **PTL = Part Truck Load.** Porter's intercity shared-truck vertical: multiple customers' consignments are clubbed onto one truck, versus FTL where one customer books the whole vehicle. | `notion:3449c6eaaa6d8036bb51d679b6182767` | unverified | Part Truck Load, PartLoad | Corroborated by the schema name `partload_application` (`T-040`). |
| B-002 | PTL is roughly **6 months old and pre-PMF**; the product is still operationally assisted rather than self-running. | `notion:3449c6eaaa6d8036bb51d679b6182767` | unverified | — | Explains why many metrics read `NA`: the capability doesn't exist yet, the data isn't missing. |
| B-003 | **Gross margin per order is deeply negative every month** — roughly −73% to −161% across Dec-25→Apr-26. PTL is heavily subsidised. | `notion:3449c6eaaa6d8036bb51d679b6182767` | unverified | GM%, GM%/order | Catalog metric #54. Values in the snapshot below. |
| B-004 | The review is organised around **3 charters: Booking Journey, Fulfilment, Unit Economics.** | `repo@851886f:pnm-selfserve/HANDOFF.md` | unverified | — | Charter names appear in reference material only → `G-020` |
| B-005 | **Batching/allocation is Ops-driven, not automated.** A batching engine was targeted Q2 dev / Q3 release. | `notion:3449c6eaaa6d8036bb51d679b6182767` | unverified | clubbing, combo | Explains why "% organic allocation" and "reallocation rate" report `NA`. |
| B-006 | **Partner onboarding runs through a Google Form**; there is no self-serve partner flow. | `notion:3449c6eaaa6d8036bb51d679b6182767` | unverified | owner onboarding | — |
| B-007 | The **partner order lifecycle runs on third-party AppSheet**, not a Porter partner app. | `notion:3449c6eaaa6d8036bb51d679b6182767` | unverified | — | Catalog #74 tracks AppSheet adoption. |
| B-008 | Customers split **Business vs Personal**; PTL's metrics and North Star are defined on the **Business** segment. | `DECISION_LOG:D4` | **verified** | biz, B2B | Owner ruling. The mechanical rule is `T-020`. |

## Interventions & GTM events (trend-interpretation anchors)

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| B-010 | **4 Feb** — pricing GTMs went live. | `local:01_reference_readonly/migrated_context/prod_ops_metric_assistant_updated_master_instruction.md` | unverified | Year not stated in source; 2026 inferred → `G-021` |
| B-011 | **2 Mar** — 3W pricing reduced. | `local:…/prod_ops_metric_assistant_updated_master_instruction.md` | unverified | 3W = three-wheeler (inferred, `G-021`). |
| B-012 | **7 Mar** — 3W and 7ft drop-boundary expansions. | `local:…/prod_ops_metric_assistant_updated_master_instruction.md` | unverified | — |
| B-013 | **13 Mar** — 8ft+ service-boundary expansion to ~700 km. | `local:…/prod_ops_metric_assistant_updated_master_instruction.md` | unverified | — |
| B-014 | **Mid-March** — FTUX GTM campaigns in Mumbai, Pune, Bangalore, Hyderabad, Chennai. | `notion:3449c6eaaa6d8036bb51d679b6182767` | unverified | FTUX = first-time user experience. |
| B-015 | **End-Mar/early-Apr** — entry price cuts: Blr→Chn −20.5%, Blr–Hyd −14.7%, Pune–Nashik −18%. | `notion:3449c6eaaa6d8036bb51d679b6182767` | unverified | Directly relevant to any Apr-26 AOV or GM movement. |

> **B-075…B-081 added 2026-08-11** from `notion:36a9c6eaaa6d809db065efc12ecf4f42`, **tier 5**
> (CONTRIBUTING §6 — none names a reconciled Metabase surface). All `unverified`; all
> `last_verified: 2026-08-11`. These are dated events and stated methods — **no measured values are
> recorded here**, per CONTRIBUTING §7/§9. Where the source attached figures, they were dropped.

| B-075 | **Pickup-slot configuration has changed four times in 2026 and is the single biggest trend-interpretation trap in PTL.** Sequence: **2-hour** slots (until Jun 13) → **3.5-hour** (Jun 14 – Jul 8, network-wide) → **2-hour** (Jul 9) → **2.5-hour / 150-minute** (Jul 11 onward, current). ⚠️ **Jul 8 and Jul 10 are mixed transition days carrying both configurations — exclude them from any slot-level analysis.** Some routes run 240/300/630-minute slots throughout as route-specific experiments; isolate the network configuration by filtering on slot duration rather than assuming it. | `notion:36a9c6eaaa6d809db065efc12ecf4f42` | unverified | Do not cite 3.5-hour slot windows in anything dated Jul 11 or later. |
| B-076 | **Jun 14 2026 is a hard structural break — metrics are not comparable across it.** The network moved from 2-hour to 3.5-hour slots on that date. **Total** CBDF%/CADF% remain comparable week to week; the **Before / In / After slot** sub-buckets do **not** compare across a configuration boundary, because the buckets themselves change meaning. Compare sub-buckets within a single week only. | `notion:36a9c6eaaa6d809db065efc12ecf4f42` | unverified | The mechanism, where stated: morning-slot demand rose sharply without matching supply, and the evening slot was extended past the hour supply reliably persists. Allow a multi-week driver-adaptation window before judging any slot change. ⚠️ The source dates this Jun 14 throughout and Jun 11 once → `G-168`. |
| B-077 | **Bangalore's dominant cancellation driver is a structural mechanism, not noise: CADF after slot close.** A driver is assigned; the pickup-slot window closes; **the system does not auto-expire or reassign**; the order stays open past slot close and the cancellation lands hours later. ⚠️ **Execution status during that window is not captured** — whether the driver reached the customer (customer unreachable, shipment not ready) or never went is unknowable from the data. Engineering fix — auto-expire or reassign at slot close — is pending. | `notion:36a9c6eaaa6d809db065efc12ecf4f42` | unverified | ⚠️ **The source explicitly instructs: do NOT call this "ghost assignment"** — that label asserts an execution outcome the data cannot support. Slot bucketing for this pattern is by **cancellation** timestamp against the slot window, never by order-creation time. → `M-006` |
| B-078 | **Surat is a structural driver shortage, not a noisy small city.** Sustained elevated cancellation across consecutive weeks with CBDF concentrated *before* slot, alongside declining volume. Treat as a standing watch route in any review. | `notion:36a9c6eaaa6d809db065efc12ecf4f42` | unverified | Distinct from the small-sample caveat that applies to low-volume cities generally — this is a persistent pattern, not a swing. |
| B-079 | **Experiment registry.** Two slot-width experiments (`slot_width_mumbai`; `pickup-slot-width-experiment-4hr-6hr-slot`) are **CONCLUDED**, superseded by the Jun 14 network rollout — their findings are historical and **must not be applied to anything dated Jun 14 or later**. A **discount experiment on New Business users** (CG / TG1 / TG2, table `T-075`) was live as of Jul 2026. | `notion:36a9c6eaaa6d809db065efc12ecf4f42` | unverified | ⚠️ The source cites a companion document, `references/experiment_report_prompt.md`, as the authority for experiment reporting. **That document has never been read** — this row is incomplete until it is. |
| B-080 | **Experiment arm classification is route-level and go-live gated.** An order counts as Test Group only if **all four** hold: (1) its route has a live experiment; (2) the user was assigned TG **on that specific experiment**, not another; (3) the order was placed on or after that experiment's go-live date **on that route**; (4) the user's first experiment-exposure date is on or before the order date. **Never classify at user level across routes.** Exposure is any of three front-end events (vehicles-loaded, quote-viewed, book-now-clicked), and condition 4 is unusable without that event set. **Normalisation:** placed-orders-per-unique-user is the only normalisation needed; ratio metrics (completion %, cancel %) need none; **never compare absolute placed counts between arms** — pool sizes are unequal even in a nominal 50/50 split. | `notion:36a9c6eaaa6d809db065efc12ecf4f42` | unverified | Arm labels are inconsistent in the raw data and must be normalised — see `T-062`. |
| B-081 | **SDD/NDD is classified at BATCH level, not order level.** A batch is **NDD** if the earliest order-creation date in it precedes the pickup-slot date (i.e. at least one order was booked the day before); **SDD** if all its orders were booked on the pickup date. Classifying individual orders and aggregating manufactures false "mixed batches" that do not exist. | `notion:36a9c6eaaa6d809db065efc12ecf4f42` | unverified | ⚠️ **A second, different mechanism for the same two labels already exists in this KB** — `T-006` maps them from `slots.EDD_BUFFER_IN_DAYS` (0/1). Two mechanisms, same vocabulary, unreconciled → `G-170`, `B-044`, `B-045`, `G-014`. Structurally: long-haul routes carry the highest NDD share, short-haul are almost entirely SDD. |

## Porter metric conventions — treat as non-negotiable

> Source for B-030…B-033 and B-060/061 is the PTL master instruction, a document — hence
> `unverified` per the note above. They are nonetheless **binding house rules**, not suggestions.

| id | statement | source_ref | confidence |
|---|---|---|---|
| B-030 | **Aggregate-then-ratio.** For any derived ratio, aggregate numerator and denominator at the required cut first, *then* divide. **Never** average daily ratios. | `local:…/prod_ops_metric_assistant_updated_master_instruction.md` | unverified |
| B-031 | **Week = Saturday→Friday.** Completed weeks only. Label `dd mmm - dd mmm`; weeks as columns, latest leftmost. ⚠️ **CONTESTED — do not quote this without reading `G-154`.** `[unverified · notion:36a9…]` PTL weekly production reporting uses **Sunday→Saturday**, and warns that `DATE_TRUNC('week')` (Snowflake's Monday default) silently buckets Sunday orders into the prior week. **Neither side wins:** both are tier 5, this row's source being a document and the source's week claim naming no reconciled surface — and the source contradicts itself, using the very `DATE_TRUNC('week')` it bans. A third voice, the workspace `CLAUDE.md`, also says Sat→Fri. **Until ruled: ask the requester which convention they mean before running any weekly cut.** → `G-154`. `last_verified 2026-08-11` |
| B-032 | **Divide-by-zero returns null**, never 0 and never infinity. | `local:…/prod_ops_metric_assistant_updated_master_instruction.md` | unverified |
| B-033 | Movements in percentage metrics are stated in **"pp" (percentage points)**, not "%". | `local:…/prod_ops_metric_assistant_updated_master_instruction.md` | unverified |
| B-034 | Snowflake timestamps are **UTC**; convert to IST with `+330 min` / `CONVERT_TIMEZONE`. ⚠️ **The slash implies the two are interchangeable, and that is disputed** — `[unverified · notion:36a9…]` production practice says never use `+ interval '330 mins'` for comparisons involving **slot boundaries**. Treated as a **source defect, not a KB conflict**: IST is a fixed +05:30 offset with no DST, no mechanism is given, and the same source uses `+ interval '330 mins'` inside its own slot-anchored allocation clock. Confidence unchanged. → `G-168`, `T-030`. `last_verified 2026-08-11` | `metabase:card/33519` | **verified** |

## Glossary

| id | term | expansion | source_ref | confidence |
|---|---|---|---|---|
| B-040 | **PTL** | Part Truck Load | `notion:3449c6eaaa6d8036bb51d679b6182767` | unverified |
| B-041 | **FTL** | Full Truck Load (the contrast product) | `notion:3449c6eaaa6d8036bb51d679b6182767` | unverified |
| B-042 | **CBDF** | Cancelled **B**efore **D**river **F**ound | `metabase:card/43237` | **verified** |
| B-043 | **CADF** | Cancelled **A**fter **D**river **F**ound | `metabase:card/43237` | **verified** |
| B-044 | **SDD** | Same-Day Delivery — `EDD_BUFFER_IN_DAYS = 0` | `metabase:card/33519` | verified (mapping) / assumption (words) → `G-014` |
| B-045 | **NDD** | Next-Day Delivery — `EDD_BUFFER_IN_DAYS = 1` | `metabase:card/33519` | verified (mapping) / assumption (words) → `G-014` |
| B-046 | **EDD** | Estimated Delivery Date (column `EDD_BUFFER_IN_DAYS` on `slots`) | `metabase:card/33519` | assumption → `G-015` |
| B-047 | **NSM** | North Star Metric | `DECISION_LOG:D4` | **verified** |
| B-048 | **AOV** | Average Order Value = revenue / completed orders | `DECISION_LOG:D6` | **verified** |
| B-049 | **MAV** | Monthly Active Vehicles | `notion:3449c6eaaa6d8036bb51d679b6182767` | unverified |
| B-050 | **MAO** | Monthly Active Owners | `notion:3449c6eaaa6d8036bb51d679b6182767` | unverified |
| B-051 | **VSS** | **Vehicle Selection Screen.** Confirmed from literal Amplitude event names (`vehicleselectionscreen_vehicles_loaded`, `ce:OS Vehicle Loaded - VSS`) | `amplitude:773228/chart/3jh9upju` | **verified** (2026-07-30) |
| B-052 | **TOF** | Top of Funnel | `notion:3449c6eaaa6d8036bb51d679b6182767` | assumption → `G-016` |
| B-053 | **OS** | Outstation (an acquisition thread alongside PTL/PnM/Courier). Consistent with Amplitude event `ce:OS Vehicle Loaded - VSS` | `metabase:card/41124`, `amplitude:773228/chart/l9brfm70` | assumption → `G-016` |
| B-053b | **FTL** *(as used in Amplitude event taxonomy)* | **Not a literal taxonomy term.** Chart `gjvatdh3` implements it as an enumerated list of non-PTL `vehicle_id` codes (100,101,102,103,104,105,106,107,108,111,112,114,1141,1150,1151,1152,132), contrasted against PTL's own `vehicle_id 1159`. The acronym is a human title label over that list, not a property value | `amplitude:773228/chart/gjvatdh3` | **verified** (2026-07-30) |
| B-054 | **OLC** | used in the review; **expansion never stated** | `notion:3449c6eaaa6d8036bb51d679b6182767` | unverified → `G-016` |
| B-055 | **WD** | Weight Discrepancy (revenue from weight revision) | `metabase:card/34284` | unverified → `G-016` — expansion inferred from the card *title*, and a card title is never evidence (§4) |
| B-056 | **FF** | Fulfilment (`ff = co / demand`) | `local:…/prod_ops_metric_assistant_updated_master_instruction.md` | unverified |
| B-057 | **"excl 60s"** | excludes cancellations within 60 seconds of booking — measured against `order_cancellation_reasons.created_at`, not the order row. ⚠️ **A THIRD variant exists, and it is the largest.** `[unverified · notion:36a9…]` For advance bookings placed before 08:00, production runs the 60-second clock from **08:00 on the slot date**, not from actual order creation; without that correction the sub-60s count is understated and the cancel rate materially overstated on the morning slot. This is a different **clock**, where `G-002`'s two are different **sides of the ratio** — so it stacks with them rather than replacing either. → `G-157` | `metabase:card/43237`, `metabase:card/33466` | **verified** — ⚠ **two different implementations exist**, see `G-002`; a third clock variant `G-157`. `last_verified 2026-08-11` |
| B-058 | **3W** | three-wheeler vehicle class | `local:…/prod_ops_metric_assistant_updated_master_instruction.md` | assumption → `G-021` |

## House formulas (PTL leadership-note base metrics)

| id | statement | source_ref | confidence |
|---|---|---|---|
| B-060 | `ff = co / demand` · `qualified ff = co / qualified_demand` · `allocation % = allocation / demand` · `cadf % = cadf / demand` · `cbdf % = cbdf / demand` · `so % = so / demand` · `mo % = mo / demand` · `cac % = cac / demand` · `aov = revenue / co` ⚠️ **`demand` is contested.** `[unverified · notion:36a9…]` Production reporting denominates on **terminal** orders (`state IN (3,4)`) rather than all placed orders, on the grounds that open orders inflate the denominator and understate FF. **Neither side wins** — both tier 5 (this row is a document; the source's claim names dashboard 4793 but the KB's reading of 4793's card 43237 shows an unconditional count, so the reconciliation did not happen → `G-168`). The consequence is live: **the weekly report and the canonical 4793 dashboard do not compute the same ratio, and both are currently defensible.** → `G-161`, `M-003`, `M-005`, `M-006`. `last_verified 2026-08-11` | `local:…/prod_ops_metric_assistant_updated_master_instruction.md` | unverified |
| B-061 | Standard dimensional cuts: `city_name`, `vehicle_mapping`, `distance_bucket` (11 buckets). ⚠️ **Divergent from practice.** `[unverified · notion:36a9…]` Production cuts by pickup city, **corridor** (a maintained many-routes→one-corridor mapping, first-class and not derivable from `city_name`), route, slot window, weight band, user type, tenure and experiment arm. `vehicle_mapping` and `distance_bucket` appear **nowhere**. Both tier 5 → neither wins; treat this row as incomplete rather than wrong. Corridor mapping lives in [query-rules.md](./query-rules.md) §7. `last_verified 2026-08-11` | `local:…/prod_ops_metric_assistant_updated_master_instruction.md` | unverified |

> `co` = completed orders. `so` / `mo` / `cac` expansions are stated in no source read → `G-017`.

---

## Project Argus — the cross-vertical Metric Store this KB will eventually answer to

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| B-070 | **"Porter Product Argus"** is a live cross-vertical Metric Store programme built on a semantic-layer platform. It names **no vertical**, including PTL — its worked examples are generic. | `local:01_reference_readonly/Porter-Metric-Store-—-POV-05-21-2026_04_36_PM.pdf` | unverified | Nothing in it currently binds PTL by name. |
| B-071 | Argus requires, for any metric admitted: a **named owner**, **reviewer sign-off** (federated — Builders author, Analytics-Manager Reviewers approve), and definitions authored as **PRs against a dbt repo gated by CI/CD**. | `local:…/Porter-Metric-Store-POV.pdf` | unverified | **This KB records no owner for any metric** → `G-133` |
| B-072 | Argus mandates a **three-tier response confidence** model — defined (~100%) / variant (~90–100%) / undefined (<70%), refusing to answer below a per-domain threshold — and a **"trust footer"** on every served value carrying value + freshness + lineage + confidence. | `local:…/Porter-Metric-Store-POV.pdf` | unverified | Independently convergent with this KB's own `verified`/`unverified`/`assumption` scale and its `source_ref` + `source_updated_at` provenance. Never guess silently — both systems forbid it. |
| B-073 | ⚠️ **Argus evaluated and REJECTED a "per-metric SQL template file" approach** (hand-rolled, no semantic layer) in favour of dbt-authored, PR-gated definitions. **PTL's current architecture under ruling D2 — raw `partload_application` + a hand-rolled registry, dbt deferred — is structurally the shape Argus passed over.** | `local:…/Porter-Metric-Store-POV.pdf` | unverified | Not a mandate on PTL today. But PnM is hitting the identical fork live, with a standing rule "no dbt model → not eligible for the metric store". Treat raw-table self-serve as **provisional, not permanent** → `G-132` |
| B-074 | **Aggregate-then-ratio and `NULLIF(denominator, 0)` → NULL are Porter-WIDE conventions**, not PTL-local — the same rules appear independently in the PnM MBR automation's SQL. | `local:ProdOps/selfserve/pnm/queries.py` | unverified | Strengthens `B-030` and `B-032`: two independent derivations, not one house style. **Now three** — `[unverified · notion:36a9…]` PTL's weekly reporting derives it again from scratch: *"every total row must be recomputed at network level; ratios computed across all orders together give different results than weighted averages of city-level ratios"*, with the operational corollary **never sum city rows to make a network total**. Three independent derivations across two verticals and one operational playbook. `last_verified 2026-08-11` |

## SNAPSHOT — reported values, Apr-26

> **Point-in-time values, not definitions.** Recorded as reconciliation anchors: if a query
> reproduces these, the definition behind it is probably right. They go stale by design and are
> deliberately kept out of the definition rows in [metrics.md](./metrics.md).
> Source: `notion:3449c6eaaa6d8036bb51d679b6182767`, captured 2026-07-29. **All `unverified`** — no
> production query was run to confirm any figure.
>
> ⚠ The document is titled **"May '26"** but its latest complete data column is **Apr-26**. Always
> label by data period, never by review name.

| Metric | Apr-26 | Mar-26 | Note |
|---|---|---|---|
| NSM — monthly transacting business customers | 2,247 | 1,879 | Not reconciled to any implementation — `M-001`, `G-003` |
| Completed orders (business) | 3,341 | 2,824 | `M-002` |
| Total Fulfilment % | 56% | ~57% (stable) | `M-003` |
| Fulfilment % excl-60s | 66% | — | Different denominator treatment — `G-002` |
| CADF % | 13.81% | 12.99% | ⚠ **source states "+1.2pp"; 13.81 − 12.99 = 0.82pp.** One of the three figures is wrong — `G-117`. Attributed to an Ops-driven batching push |
| Business session conversion | 5.43% | 4.62% | `M-009` |
| AOV | ₹2,920 | ₹2,834 | Three competing revenue bases exist — `G-004` |
| GM % per order | −78.28% | −73.50% | Dec-25 was −160.79% |
| Monthly Active Vehicles | 739 | 676 | — |
| New owners onboarded | 2 | 11 | — |
| Owner earnings per MAV | ₹63,952 | ₹61,643 | — |
| Customer NPS | 53.85 | 4.45 | ⚠ **Not comparable** — methodology/scale break mid-Apr — `G-008` |

**Known defects in the source document** (do not silently correct): a column header reads `Feb-25`
where `Feb-26` is meant, across all tables; the FCR% narrative says "stable" against a Dec-25 outlier
of 21.5%; the return-trip% narrative claims both a "dip" and a "1pp jump" for the same period; the
median-time-to-book insight text discusses repeat-order share instead; the earnings/trip insight is
truncated mid-sentence. Logged `G-030`…`G-034`.
