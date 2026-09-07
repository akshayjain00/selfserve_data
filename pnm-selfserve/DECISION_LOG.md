# PnM Self-Serve NL Query Layer — DECISION LOG

*Living record of every consequential decision, its rationale, evidence, and status.
Newest decisions at the bottom of each section. Keep this updated whenever a decision
is made, changed, or verified. Supersedes stale framing in `HANDOFF.md`.*

Owner: akshay.jain@theporter.in · Repo: `akshayjain00/selfserve_data` @ `claude/pnm-metrics-catalog-map-vg251i`

---

## 1. Decisions

### D1 — Execution model: Path A (owner runs on laptop)
- **Date:** 2026-07-07 (carried from HANDOFF) · **Status:** ACTIVE
- No production Snowflake/Sheet write without showing exact SQL + explicit go-ahead. Dry-run is the default.

### D2 — Bring the prototype local via git clone
- **Date:** 2026-07-08 · **Status:** DONE
- The `selfserve_nlq/` code existed only on the GitHub branch. Owner chose to clone the branch into `selfserve/pnm/selfserve_data/` so `run_tests.py`/`ask.py` run locally. The 5 read-only pipeline files stay where they are (never in the repo).

### D3 — Orders source = **Option A**: re-point to PROD_ELDORIA governed models
- **Date:** 2026-07-08 · **Status:** DONE (implemented) · **Confidence at decision:** ~92% (verified, up from HANDOFF's asserted ~85%)
- **Context:** The configured raw `PROD_CURATED.pnm_application` tables never carried the columns the pipeline reads → leads/orders/derived/tpo could not execute.
- **Evidence:** Data Catalog `get_column_metadata` on `fact_pnm_orders`/`fact_pnm_opportunity`/`dim_pnm_orders`/`dim_pnm_opportunity` confirmed every needed field exists in the governed dbt models (incl. `SOURCE`, `SOURCE_DETAILS`, `USER_FLAG` on the opportunity dim — my earlier `search_columns` read missed the dims and wrongly concluded they were absent; the per-model check is authoritative). Cross-checked with Metabase card #30311 SQL.
- **Option B (stay on raw tables) rejected:** would never execute; no baseline exists to validate against.

### D4 — Nano business rule (owner domain knowledge)
- **Date:** 2026-07-08 · **Status:** ACTIVE (baked into SQL)
- **Rule:** Nano = labour-only help (no vehicle/vendor allocated), owned by **LA (Labour Assist)**, a separate business group.
  - **Leads (demand):** INCLUDE nano — nano demand stays with PnM through the funnel.
  - **Orders + TPO (and later NPS/detractor):** EXCLUDE nano — those bookings are attributed to LA.
- **Consequence:** conversion = non-nano PnM orders ÷ nano-inclusive PnM leads (asymmetric, by design). Confirmed to match the owner's validated `LEADS_CONVERSION_QUERY`.

### D5 — Mirror the owner's live-validated automation (not a hand re-derivation)
- **Date:** 2026-07-08 · **Status:** DONE · **Trigger:** owner nudge to `pnm/pnm_mbr_monthly_metrics`
- Rather than hand-map the old raw-table staging, `sqlgen.py` now **mirrors** the validated queries:
  - leads / orders / derived → `LEADS_CONVERSION_QUERY` (validated 2026-07-08 vs PROD_ELDORIA core/mart)
  - tpo → `TPO_TREND_QUERY` / card #47576 (validated 2026-07-07 vs PROD_CURATED raw)
- This corrected **six** things my initial re-point had wrong: nano asymmetry, no cancelled filter, dedup per `order_id` (not per SR), intra-city via `shifting_type` (not `service_type`), `crn LIKE '%PNM%'` + single month (no prev-month window), and TPO on PROD_CURATED raw with a real allocation-completion join (not the `o_completed_ts` shortcut).

### D6 — Reconcile against the MBR note / Notion Demand DB, NOT card #30311
- **Date:** 2026-07-08 · **Status:** ACTIVE
- Card #30311 strips nano from the whole funnel (wrong per D4). The validated automation + Notion Demand DB are the correct baselines.

### D7 — Structure-only adaptations of the validated queries
- **Date:** 2026-07-08 · **Status:** DONE
- (a) Single requested month (`DATE_TRUNC('month', …) = month_start`) instead of the automation's open-ended `>= start_date`.
- (b) This layer emits raw per-channel **counts**; %s and conversion are computed in Python from those counts (never averaged) — the automation emits %s directly. Same underlying numbers, preserves the registry's count-metric ids.
- (c) A validated-literal `month` column is emitted on every section so `ask.py` can match the single result row uniformly.

### D8 — `p80_durations` + `order_edits` source = **`PROD_ELDORIA.MART.PNM_EXPERIENCE`**
- **Date:** 2026-07-12 (owner) · built 2026-07-19 · **Status:** DONE · **Confidence:** ~95% (schema verified live)
- Both sections mirror the automation's `TRIP_DURATION_PERCENTILE_QUERY` / `EDIT_ADOPTION_QUERY` over the single governed mart `PNM_EXPERIENCE` (via `config.EXPERIENCE_SOURCE_TABLE`). The p80 baseline CSV **is** this automation's output.
- **Pre-flight (2026-07-19, live `INFORMATION_SCHEMA`):** all 20 required columns exist; `SHIFTING_TS_IST` and `ORDER_CREATED_TS_IST` are `TIMESTAMP_NTZ` (so naive-literal month bounds don't shift — no cast needed). Types: `IS_MODIFICATION_DONE` TEXT (`='Yes'`), `HAS_*_EDIT` NUMBER (`=1`).
- **Supersedes** the old `order_edits` stub that sourced from `PROD_CURATED.pnm_application.sr_modifications` / `order_modifications`; those `verify_flags`+`evidence` were **replaced, not appended**. (Board B-8: the spec's claim to also supersede a p80→`FACT_PNM_ORDERS` note was an overstatement — no such p80 note existed; only the stub's generic `o_completed_ts` month_basis needed correcting, now `SHIFTING_TS_IST`.)

### D9 — Metric ids = the automation's exact output-column names, lowercase
- **Date:** 2026-07-12 · **Status:** DONE
- `resolve()` lowercases the question and `execute()` lowercases every result column (`[d[0].lower() …]`), and `compute_value` does `row.get(metric_id)` — so ids MUST be lowercase to match. Verified end-to-end by the board. All 17 new metrics are `source:"sql"` (order_edits emits final %s in SQL, unlike leads/orders which emit counts and derive in Python).

### D10 — `p50_trip_duration` and `p80_vendor_accepted_to_sup_assigned` are emitted + reconciled but NOT NL-exposed
- **Date:** 2026-07-12 · **Status:** DONE · **⚠ one leg rests on a corrected premise — owner input wanted (see below)**
- Both are reachable only via `ask.py --metric`; both are emitted and reconciled (the p80 baseline needs p50). Mechanism: `p50` is blocked by the pre-existing `p50`/`median` guard; the vendor-stage metric is given **no aliases** and `resolve()` now skips zero-alias metrics entirely (so not even the id-form resolves).
- **CORRECTION (board A-1/B-1, blocker):** the spec's stated reason for hiding the vendor metric — *"its name contains 'vendor' → hits `UNSUPPORTED_TERMS`"* — is **false**. Bare `"vendor"` is not in the guard list (only `by vendor`/`per vendor`/`vendor wise`/`vendorwise`), the guard runs on the question not the metric name, and adding bare `"vendor"` would break the existing `tpo_vendor_raised` NL metric. Exclusion is therefore done by no-aliases, not the guard.
- **OWNER DECISION PENDING (~55% keep hidden):** `p80_vendor_accepted_to_sup_assigned` is a legitimate stage-duration metric (vendor-owner accept → supervisor assigned), published in the baseline like its NL-exposed siblings. Its original "hide it" call rested on the false guard premise. **Do you want it NL-exposed** (give it an alias + an ANSWERABLE case) like the other p80 stages, or kept `--metric`-only? Default shipped = hidden.

### D11 — `ota` source = **Metabase card #37409** ("On Time Arrival %"), 30 min AND 2 km
- **Date:** 2026-09-04 (owner-ruling:2026-09-04, in-session — not yet logged by the file's named owner) · **Status:** DONE (implemented) · **Trigger:** owner supplied the card's SQL directly and ruled on the threshold
- **Context:** `ota` had been `blocked` since iteration-2 (`PNM-G-043`'s six missing columns), then narrowed but left `BLOCKED` on 2026-08-27 once three governed dbt-layer definitions were found (`PNM_EXPERIENCE.OTA_FLAG` 0.5 km, `pnm_ota_capacity` 0.5 km, `pnm_support.on_time_arrival_flag` no distance test — `PNM-G-024`).
- **Decision:** the owner did not choose among those three. They supplied a **fourth** definition — Metabase card #37409 — and ruled **30 minutes AND 2 km** is correct. Same anchor event as all three dbt definitions (latest `supervisor_actions` row, `action='ShiftingStarted'`), but a different, larger distance threshold and a different source entirely (`PROD_ELDORIA.RAW.PNM_APPLICATION_SR_LOCATION_DETAILS`/`SUPERVISOR_ACTIONS`, not `PNM_EXPERIENCE` or `pnm_ota_capacity`).
- **Adaptation (structure-only, per the D7 pattern):** the card's own SQL reads `DEV_ELDORIA.RAW.*` and an open-ended date range; the shipped `ota_sql` reads `PROD_ELDORIA.RAW.*` (confirmed byte-identical row counts and `MAX` timestamps — 67,856,125 / 11,821,346 rows — to the card's dev tables, live-checked 2026-09-04) and a single-month equality filter on `o_completed_ts`, matching every other section.
- **7 new metrics** (`ota_pct`, `ota_total_completed_orders`, `ota_on_time_orders`, `ota_unset_orders`, `ota_delay_orders`, `ota_delay_gt_60_mins_orders`, `ota_delay_gt_60_mins_pct`) — catalog now **54 metrics, 7 sections**, all still `prototype_only`.
- **Closed as a side effect:** `PNM-G-043` (superseded — the six-column blocker was never the only path to building OTA), `PNM-G-021` (the stale `status=2` `base_population` string, corrected as part of the build).
- **Not resolved by this decision:** `PNM_EXPERIENCE.OTA_FLAG`, `pnm_ota_capacity`, and `pnm_support.on_time_arrival_flag` still exist, unedited, and still disagree with each other and with the adopted 2 km (`PNM-T-100`/`100a`/`105`). `PNM-G-098` (what `PNM_EXPERIENCE.distance_km` measures) is now decoupled from `PNM-G-024`, not answered by it.

### D12 — Build `gac_ctr`, the first of `PNM-G-071`'s 11 uncovered MBR groups
- **Date:** 2026-09-04 · **Status:** DONE (implemented) · **Trigger:** owner supplied the full MBR automation DEV-ingestion SQL (`PNM-S-060`) in-session, which for the first time makes all 14 MBR sections citable at a SHA rather than `local:`-capped (`PNM-G-003`/`PNM-G-006`, partially relieved not closed)
- **Context:** `PNM-G-071` had undercounted the uncovered MBR sections as 8; the real SQL showed 11 (correcting a conflation of two distinct "vendor earnings" groups and a false equivalence between the catalog's own TPO Trend section and the automation's separate vendor-TPO/top-5-issues pipeline). Get-a-Call CTR was chosen as the first to build: a single metric, a single CTE, no ambiguous population filters — the smallest possible proof that the D7 structure-only adaptation pattern extends cleanly to a new, previously-uncovered MBR group.
- **Implementation:** `sqlgen.gac_ctr_sql()` mirrors the automation's `gac_ctr_metrics` CTE exactly — `PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES` LEFT JOIN `OPPORTUNITIES_LATEST_LSM_SCORE` (`opportunity_latest_score = 999` as the GAC-request sentinel), filtered to `shifting_type = 'intra_city'`. Only change: the automation's open-ended `>= start_date` becomes a single-month `DATE_TRUNC(...) = month_start` equality filter, the same adaptation every other section uses.
- **1 new metric** (`gac_ctr_pct`) — catalog now **55 metrics, 8 sections**, all still `prototype_only`.
- **Not resolved by this decision:** whether Argus DD row `PNM-031` ("Get a Call CTR", `system: Amplitude`) measures the same population as this Snowflake-backend metric — flagged, not assumed equal (`PNM-G-100`). **Superseded same day** — owner confirmed in-session the metric is Snowflake-only as supplied; `PNM-G-100` closed, `PNM-031` mapped.

### D13 — Build the remaining 10 MBR groups (all 15, catalog now complete against the automation)
- **Date:** 2026-09-04 · **Status:** DONE (implemented) · **Trigger:** owner instruction — "don't leave any metrics from [the MBR file], add/make changes accordingly for all"
- **Context:** After `gac_ctr` (D12) proved the pattern, the owner asked for full coverage rather than picking sections one at a time. Pre-flighted every table the remaining 10 sections touch (`INFORMATION_SCHEMA.COLUMNS`, live, 2026-09-04) before writing any SQL — all columns the automation references exist as named, no surprises.
- **Implementation — same D7 structure-only adaptation for all 10** (open-ended `>= start_date` → single-month `= month_start` equality; nothing else changed vs. `PNM-S-060`):
  - `weekend_sql` — weekend order share (1 metric), `PNM_EXPERIENCE` + `FACT_PNM_ORDERS`
  - `cac_post_trip_sql` — CAC post trip started (1), `PNM_EXPERIENCE` + `CANCELLED_ORDER_EVENTS`
  - `vendor_earnings_pctl_sql` — vendor earnings/orders P50/P80 (6), `PNM_FARE_MOVEMENT`
  - `allocation_sql` — allocation quality (33, the largest group), `PNM_ALLOCATION`
  - `wallet_sql` — wallet withdrawal/recharge (6), `VENDOR_OWNERS`/`VENDOR_WALLET_WITHDRAWAL`/`PAYMENT_LINKS`/`VENDOR_ALLOCATION_CONFIGS`
  - `vendor_tpo_top5_sql` — vendor TPO + top-5-issues (6), a RAW-table pipeline SEPARATE from this catalog's own `tpo` section
  - `addon_sql` — add-on adoption (7), `PNM_EXPERIENCE` — deliberately no completed/Nano filter, matching the automation's own owner-confirmed intent
  - `completion_sql` — completion score/NPS/detractors (3), `PNM_EXPERIENCE`
  - `fare_sql` — fare/coupon/surge/AOV (14), `PNM_FARE_MOVEMENT` — replicates the automation's two-population UNION/MAX() structure verbatim, since collapsing it would change what each metric measures
  - `vendor_earnings_bucket_sql` — vendor earnings by bucket (5), `PNM_EXPERIENCE`
- **82 new metrics, 10 new sections** — catalog now **137 metrics, 18 sections**, all still `prototype_only`. `PNM-G-071` closed — every MBR group the automation runs is now built.
- **Guard conflict found and resolved, not gamed:** 10 of the 82 new metric ids have a natural phrasing that unavoidably contains `'p50'`/`'median'` or `'per vendor'`, both of which `UNSUPPORTED_TERMS` blocks (correctly, for the cases it was designed for — no vendor-level cuts, no ad-hoc percentiles). Rather than invent alias wording to dodge the guard, all 10 were made `--metric`-only (no NL aliases), the same treatment `p50_trip_duration` already had (D10): `p50_earnings_per_vendor`, `p80_earnings_per_vendor`, `p50_orders_per_vendor`, `p80_orders_per_vendor`, `withdrawals_per_vendor`, `recharges_per_vendor`, `p50_withdrawal_amount`, `p50_recharge_amount`, `median_fare_increase_amt`, `median_fare_decrease_amt`.
- **Test coverage tradeoff, stated plainly:** given the size (82 metrics), each new section got a representative NL question (proving real resolution + rendering) plus a **comprehensive column-production check** — for every metric id in every new section, assert the rendered SQL actually produces a column of that name. This catches registry-id ↔ SQL-alias typos (the most common real bug class) without requiring 82 hand-written NL phrasings. `vendor_tpo_top5`'s 5 issue-breakdown ids are built via runtime string concatenation, not a static alias, so they're excluded from the static check and verified instead by direct live execution (see V-mbr-build below).
- **Corrected the automation's own casing in one spot:** `vendor_tpo_top5_sql`'s table references were lowercase in the supplied SQL (`prod_eldoria.raw...`); uppercased to match this codebase's convention and so the read-only table allow-list check (`check_sql`, case-sensitive regex) actually validates them. Snowflake itself is case-insensitive, so this changes nothing about what runs.
- **Not done in this pass:** cross-mapping the 82 new metrics against the 167-row Argus DD (the `PNM-052`-style mapping exercise) — a separate, sizeable task, not requested here.

### D14 — Ship the `leads_overall` rename; name the PnM-side table owners
- **Date:** 2026-09-04 · **Status:** DONE (implemented)
- **`leads_overall` → `leads_overall_intra_city`** (`PNM-G-093`): the rename itself was already ruled `owner-ruling:2026-08-26` (`PNM-G-090`) but sat unshipped in code. Trigger to finally ship it: "if we want to keep [the generic name] then tell the user its just for intracity" — i.e. don't leave a metric that reads as PnM's overall lead volume when it isn't one. Implementation and live re-verification: `DECISION_LOG:V8`.
- **Named owner per table** (`PNM-G-092`), `owner-ruling:2026-09-04`: `dim_pnm_opportunity` and `pnm_experience` → **PnM Analytics team**; the `PROD_CURATED.PNM_APPLICATION.*` raw application tables → **PnM Engineering team**. Recorded at `PNM-T-130`. This is the business-accountable owner for PnM's purposes and is explicitly independent of the governed repo's own `owner:` tags (`PNM-T-103`, HSC / DATA_ANALYTICS) — the two questions can have different answers, and this ruling does not touch the `dim_pnm_opportunity` HSC-vs-`NI_PNM` self-contradiction in that repo (still a question for the model's author).

### D15 — `PNM_EXPERIENCE` stays the fixed source for `p80_durations`/`order_edits` (`PNM-G-007`)
- **Date:** 2026-09-04 · **Status:** DONE (ruling recorded) · **Trigger:** asked what would actually close `PNM-G-007` (the mart's schema-drift risk); laid out three options — wait for NI_PNM to declare the mart stable, migrate the two sections off it, or automate the pre-flight check.
- **Ruling:** option 2 (migrate away) is rejected — `PNM_EXPERIENCE` remains the fixed source for both sections. Recorded at `metrics.md` §5 (`p80_durations`) and §6 (`order_edits`).
- **Consequence:** this settles the source question but does **not** close `PNM-G-007` — the schema-drift risk is a property of the mart's "under active construction" status (NI_PNM's fact, not this KB's to change), unaffected by which sections read from it. `PNM-G-007` stays **OPEN**, narrowed, as a standing pre-flight check — same shape as `PNM-G-004`, not a one-time-closable fact.
- ⚠ **SUPERSEDED 2026-09-07** — see `D20`: the mart's status itself changed, so the "stays open, standing check" consequence above no longer holds.

### D16 — Mine 4 more governed models by evidentiary yield (`PNM-G-091`, round 3)
- **Date:** 2026-09-07 · **Status:** DONE · Read-only, local clone of `porterin/DE-DBT-SNOWFLAKE` at `~/Documents/test_dbt/DE-DBT-SNOWFLAKE` (owner confirmed OK to read from, no edits made there).
- **Targets, evidentiary-yield ordering** (continuing `PNM-G-091`'s stated next list): `fact_pnm_opportunity` (97.5 A), `dim_pnm_vendor` (95 A), `pnm_gst_daily` (100 A), `cge_pnm_paid_lead_attribution` (100 A).
- **Findings:** `dim_pnm_vendor`'s true grain is `(vendor_id, bucket_start_date)`, not `1 vendor` (`data-model.md` `PNM-T-124` corrected, `PNM-T-131`) — checked against this catalog's own `wallet_sql`, which only does `SELECT DISTINCT vendor_id` against it, so the composite grain never fanned anything out. `fact_pnm_opportunity`'s doc confirms assumptions already held (`opp_id` grain, non-unique `opp_uuid`) and surfaces a second LSM-score column pair (`opp_latest_score`/`hash_score`) distinct from what `gac_ctr` actually reads (`PNM-T-132`). `pnm_gst_daily` and `cge_pnm_paid_lead_attribution` have zero table overlap with this catalog; the latter is a third, unrelated concept sharing the name "PnM leads" (marketing attribution, not opportunity funnel) — recorded at `metrics.md` §1.
- **Net effect:** zero new gaps opened, one doc correction, two non-conflicts documented, one naming clarification. `PNM-G-091` stays **OPEN** — this is an open-ended mining task, not one round closes it; next targets are `pnm_gst_daily`'s sibling marts and the remaining vendor/fare/rechurn models.
- **Ruled 2026-09-07: `PNM-G-091` is not closable, by design** — same shape as `PNM-G-004`. The governed repo's PnM model set keeps growing, so "every model mined" is a moving target, not a fact this KB can ever assert true. Each round narrows it; none closes it. Treat as a standing, recurring task — pick it up periodically, do not wait for or expect a final round that clears it. (Contrast `PNM-G-007`, closed the same day by `D20` — its root cause was a fact that could become false and did, unlike this one's ever-growing repo.)

### D17 — This KB carries formulas, never runnable SQL (`PNM-G-075`)
- **Date:** 2026-09-07 · **Status:** DONE (ruling recorded) · `owner-ruling:2026-09-07`.
- **Ruling:** `metrics.md` describes every metric as a formula, never as copy-pasteable SQL. The one executable record is `tests_output/rendered_*.sql` (`PNM-S-004`), regenerated fresh by every `run_tests.py` run — so there is exactly one copy of any query's actual SQL, and it cannot drift from what the prototype runs.
- **Consequence:** `pnm-gem-knowledge.md` §5's six month-parameterised SQL templates are superseded narrative, not migrated into this KB. `PNM-G-075` closed on this basis.

### D18 — Ratify: only the owner promotes readiness (`PNM-G-041`)
- **Date:** 2026-09-07 · **Status:** ACTIVE · `owner-ruling:2026-09-07`.
- **Ruling:** confirmed as a real rule, not just registry prose — **no AI session, and no analysis result however strong, may move any metric from `prototype_only` to `stakeholder_ready`. Only the owner does that, explicitly.** This is now an owner ruling in its own right (rung 1), not merely `metrics_registry.py`'s module docstring (rung 7) describing itself.
- **Consequence:** `PNM-B-042` upgraded `unverified` → `verified`, citing this entry. Nothing else changes in practice — every section has been `prototype_only` throughout this KB's history and stays that way; this closes the gap between "how the KB has always actually behaved" and "what the KB can cite as the reason why." `PNM-G-041` closed.

### D19 — Ratify: a `p80_durations` number is final at M+3 (`PNM-G-025`)
- **Date:** 2026-09-07 · **Status:** ACTIVE · `owner-ruling:2026-09-07`.
- **Ruling:** confirmed as the official rule, not just an observed pattern. `PNM_EXPERIENCE` keeps full history but only re-processes/corrects the trailing 3 months on each daily refresh (`partition_lookback: 3`, mined `PNM-T-101`). So: **a p80 duration number is provisional while its scheduled month (`SHIFTING_TS_IST`) is within 3 months of today, and permanently settled once it ages past that** — not because old rows are deleted, but because the rebuild stops touching them.
- **Consequence:** recorded at `PNM-B-074` (`verified`, was `unverified`/unratified pattern). `PNM-G-025` closed. ⚠ The 3-month lookback is mart config, not a law of nature — re-check `PNM-T-101` before leaning on this rule again after a long gap.

### D20 — `PNM_EXPERIENCE` is no longer under active construction (`PNM-G-007`)
- **Date:** 2026-09-07 · **Status:** ACTIVE · `owner-ruling:2026-09-07`.
- **Ruling:** `PNM_EXPERIENCE` is now in its **final shape and form** — the "still under active construction" status that made `PNM-G-007` a standing, never-fully-closable risk (`D15`) no longer applies. This is a change to the underlying fact, not a new interpretation of an old one.
- **Consequence:** `PNM-G-007` closed outright, not just re-narrowed — there is no more "wait and see" left to do; option (1) from `D15`'s three-way framing (wait for NI_PNM to declare it stable) has actually happened. Updated: `CONTEXT.md`, `CONTRIBUTING.md`'s freshness-check table, `metrics.md` §5/§6. `D15`'s "stays open" consequence is superseded by this entry, not deleted — see its own superseded note.
- **Unaffected:** `PNM_EXPERIENCE`'s 3-month rebuild-lookback behavior (`PNM-T-101`, `PNM-B-074`, `D19`) is a separate, ongoing fact about how the mart refreshes — "final shape" means the *schema* is settled, not that historical p80 values stop settling on their usual 3-month cadence.

---

## 2. Verification log

### V1 — Dry-run harness green
- **Date:** 2026-07-08 · `python3.12 run_tests.py` → **31 passed, 0 failed** (re-run after every edit batch). Validates: NL resolution, `assert_read_only`, single-month substitution, table allow-list (eldoria core/mart + curated raw), MTD labeling, refusals.

### V2 — Final adversarial pass: gaps + conflicts (this pass)
- **CRITICAL (fixed):** `ask.py:182` matched result rows by `r["month"]`, but the rewritten leads/orders/funnel aggregates had dropped the `month` column → `--execute` would `KeyError`. Fixed by emitting a validated-literal `month` column (D7c). Offline-simulated `ask.compute_value` for `conversion_*`/`pct_orders_*` → correct.
- **CONFLICT (fixed):** `ask.py` footer said *"Computed: live from PROD_CURATED.pnm_application"* → corrected to name the actual mixed sources (PROD_ELDORIA core/mart for leads/orders/derived; PROD_CURATED for tpo).
- **COHERENCE (fixed):** `ask.py` footer *"bug-for-bug from queries.py"* → *"mirrors the validated MBR automation"*.
- **Confirmed clean:** no stale intermediate terms (`service_type IN`, `o_cancelled_ts`, `o_completed_ts`, first-order-per-SR, `status != 4`) remain in the shipped SQL; grep hits are TPO's correct `%Nano%` filters and the intentionally-historical `ORDERS_SOURCE_DECISION` finding text.

### V3 — Live reconciliation vs the owner's validated queries (2026-05) — **PASS**
- **Date:** 2026-07-08 · Run via Snowflake connector (owner-authenticated), read-only. Selfserve rendered SQL vs the automation's `LEADS_CONVERSION_QUERY` / `TPO_TREND_QUERY`, both for 2026-05.

  | Metric | Selfserve | Authoritative | Match |
  |---|---|---|---|
  | leads_overall | 336,338 | 336,338 | OK |
  | orders_overall / booked_orders | 51,277 | 51,277 | OK |
  | conversion_overall | 15.25% | 15.25% | OK |
  | orders app / desktop / mobile / others | 40,775 / 1,413 / 7,554 / 1,535 | same | OK |
  | leads app / desktop / mobile / others | 234,449 / 11,164 / 67,197 / 23,528 | channels sum to overall | OK |
  | tpo orders_base | 45,414 | 45,414 | OK |
  | tpo_overall / vendor_raised | 0.9853 / 0.2988 (4dp) | 0.99 / 0.30 (2dp) | OK (rounds identically) |

- **Verdict:** the selfserve NL layer reproduces the owner's live-validated pipeline numbers EXACTLY for 2026-05. Leads/orders/derived and TPO all tie out. Optional owner cross-check: Notion Demand DB published values.

### V4 — Build + reconcile `p80_durations` + `order_edits` (iteration 3) — **PASS**
- **Date:** 2026-07-19 · Branch `claude/pnm-p80-orderedits` (off `112c992`). Method: board A/B spec re-review → live schema pre-flight (hard gate) → TDD (red harness first) → mirror implementation → live differential reconciliation → blind checker.
- **Board (A coverage + B coherence), re-run now that files are unlocked:** found + fixed 2 real spec defects before build — (1) the vendor-guard exclusion mechanism does not exist (D10 correction), (2) `ask.py` footer's `Source`/`Computed` lines were hard-coded and would misattribute the new sections → made per-section via `source_desc`/`computed_desc` with the old strings as defaults (4 existing sections unchanged). Also folded: section-scoped `AS month` assertion (a global one would red derived/tpo), repurposed the obsolete `metric_not_built` test to `metric_unknown`, and replaced (not appended) the stale `order_edits` provenance.
- **Harness:** `python3.12 run_tests.py` → **54 passed, 0 failed** (15 new answerable, 4 new guard refusals, 2 structural render checks, 2 `--metric`-only checks incl. NL-unreachability).
- **Live reconciliation (read-only, `tests_output/reconciliation_2026-07-19.md`):**
  - **p80** vs the baseline CSV (8 months): **bit-exact** on the 3 settled months (2025-10/11/12); ≤0.84% on recent months (max: p80_trip 2026-05 597→602), all well under the README ±2.5% rule, drift concentrated in the newest months = mart-still-building backfill, **not** a logic bug. Single-month rendered SQL == grouped/automation row for 2026-05 (structure-only adaptation adds no divergence). `p50 ≤ p80_trip` every month.
  - **order_edits** (no baseline CSV): byte-identical mirror of `EDIT_ADOPTION_QUERY`; all properties pass — `location_adoption_pct == pct_orders_location_modified` (15.85), all 8 %s in [0,100], `edits_per_order` positive ratio, cross-month (Mar/Apr/May) stable, single-month == grouped. Zero-edit/zero-order NULLIF path correct-by-construction, not live-exercised (documented).
- **Blind checker (maker-checker gate):** **PASS-WITH-NITS** — no silent mirror-divergence, no wiring bug, no regressions; SQL character-exact incl. both quirks. Sole nit (vendor metric NL-reachable via verbatim id-form) **closed** by skipping zero-alias metrics in `resolve()`.
- **Readiness:** both sections `built:True`, `readiness:prototype_only`. **No stakeholder promotion — owner's call.**

### V5 — Build + verify `ota` (Card #37409, D11) — **PASS**
- **Date:** 2026-09-04 · Live Snowflake reads (read-only SELECTs), same session as the owner's ruling.
- **Table existence:** `INFORMATION_SCHEMA.COLUMNS` confirmed `PROD_ELDORIA.RAW.PNM_APPLICATION_SR_LOCATION_DETAILS` and `PROD_ELDORIA.RAW.PNM_APPLICATION_SUPERVISOR_ACTIONS` exist with every column the card reads (`LOCATION` GEOGRAPHY, `LOCATION_TYPE`, `SR_ID` / `ORDER_ID`, `ACTION`, `EVENT_TS_IST`).
- **Dev/prod equivalence:** `DEV_ELDORIA.RAW.*` (the card's own tables) vs `PROD_ELDORIA.RAW.*` (what the catalog reads) — identical row counts (67,856,125 / 11,821,346) and identical `MAX(created/event ts)`. Confirmed mirrors, not divergent data; the schema substitution changes nothing.
- **Card execution (open-ended, 7 months, 2025-10 to 2026-04):** `ota_pct` 86.93%–91.49%, `ota_unset_orders` 13–96 (<0.3% of base each month), `ota_delay_gt_60_mins_pct` 3.6%–6.0% — sane, stable, no anomalies.
- **Single-month rendered SQL (2026-05), cross-checked two ways:**
  1. Same numbers as a hand-run equivalent of the open-ended query restricted to May: `ota_total_completed_orders`=45,414, `ota_pct`=84.70%.
  2. **`ota_total_completed_orders` (45,414) exactly matches `orders_base`, the TPO section's denominator for the same month**, independently validated in `V3`. Two sections built from different source tables (`PROD_ELDORIA.CORE` vs `PROD_CURATED.PNM_APPLICATION`) agreeing on a population count is a real cross-check, not a tautology.
- **Harness:** `python3 run_tests.py` → **62 passed, 0 failed** (8 new answerable cases, 1 new structural-render check; the now-impossible `metric_blocked` refusal case and its dead code path were removed, not left stale).
- **Not independently reconciled against a second source-of-truth baseline** (unlike `V3`/`V4`, which matched a separately-computed automation output) — this is the card's own logic re-run, so it validates "the mirror is byte-faithful and produces sane numbers," not "an independent system agrees with the number." No such independent OTA baseline is known to exist.
- **Readiness:** `ota` `built:True`, `readiness:prototype_only`. **No stakeholder promotion — owner's call.**

### V6 — Build + verify `gac_ctr` (D12) — **PASS**
- **Date:** 2026-09-04 · Live Snowflake reads (read-only SELECTs), same session as `PNM-S-060` being supplied.
- **Table existence:** `INFORMATION_SCHEMA.COLUMNS` confirmed `PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES` (43 cols) and `OPPORTUNITIES_LATEST_LSM_SCORE` (13 cols) exist with every column the automation reads (`opp.id`, `opp.created_at`, `opp.shifting_type`, `olls.opportunity_id`, `olls.opportunity_latest_score`).
- **Automation execution (open-ended, 12 months, 2025-10 to 2026-08):** `gac_ctr_pct` 9.59%–10.94%, one partial current month (2026-09, 6.31%) — sane, stable, no anomalies.
- **Single-month rendered SQL (2026-05), cross-checked:** rendered `gac_ctr_sql("2026-05")` executed live → `gac_ctr_pct` = **10.54%** (324,275 total opportunities, 34,169 GAC requests) — **exact match** to the automation's open-ended query grouped and restricted to the same month.
- **Harness:** `python3 run_tests.py` → **65 passed, 0 failed** (2 new answerable cases, 1 new structural-render check).
- **Not independently reconciled against a second source-of-truth baseline** — this is the automation's own logic re-run at a single month, so it validates "the mirror is byte-faithful," not "an independent system agrees." No such independent baseline is known to exist for this metric.
- **Readiness:** `gac_ctr` `built:True`, `readiness:prototype_only`. **No stakeholder promotion — owner's call.**

### V7 — Build + verify the remaining 10 MBR sections (D13) — **PASS**
- **Date:** 2026-09-04 · Live Snowflake reads (read-only SELECTs), same session as D13.
- **Pre-flight:** `INFORMATION_SCHEMA.COLUMNS` confirmed every table/column all 10 sections reference exists as named: `PNM_FARE_MOVEMENT` (46 cols), `PNM_ALLOCATION` (34 cols, already confirmed for `PNM-G-073`), `VENDOR_WALLET_WITHDRAWAL`/`PAYMENT_LINKS`/`VENDOR_OWNERS`/`VENDOR_ALLOCATION_CONFIGS`/`CANCELLED_ORDER_EVENTS` (PROD_CURATED), `DIM_PNM_VENDOR` (CORE), and the RAW-schema `pnm_application_orders`/`_order_allocation_infos`/`_shifting_requirements`/`sfms_public_hs_tickets` quartet the vendor-TPO pipeline needs.
- **Each section's single-month rendered SQL executed live for 2026-05**, all sane, several cross-checked against independent numbers already in this KB:
  - `weekend_order_share_pct` = 43.12% (automation's documented range: ~32-51%)
  - `cac_post_trip_started_pct` = 2.37%
  - `vendor_earnings_pctl`: 2,126 active vendors, **45,413 total orders — matches TPO's `orders_base` (45,414, `V3`) almost exactly**, a real cross-check between independently-sourced sections; P50/P80 earnings ₹89,570/₹214,684; P50/P80 orders 16/35
  - `allocation`: all 33 columns execute; `allocation_pct` 97.14%, `completion_pct` 84.68%, `allocation_time_p80_minutes` 41
  - `wallet`: 4.68 withdrawals/vendor, 3.62% withdrawal failure
  - `vendor_tpo_top5`: `vendor_tpo` = **0.2989 — matches this catalog's own, differently-sourced `tpo_vendor_raised` (0.2988, `V3`) almost exactly**, despite reading a completely different table set (RAW vs the `tpo` section's `PROD_CURATED`); the 5 issue-breakdown values (2.57%-11.09%) confirmed present with the exact literal metric-name strings the registry expects (these 5 are built via runtime string concatenation, not a static alias — verified by direct execution, not the static column-production check)
  - `addon`: `pct_orders_with_any_addon` = 87.86% (automation's documented range: ~86-89%)
  - `completion`: `completion_score_pct` 86.23%, `nps` 75.06, `detractor_pct` 4.25%
  - `fare`: `total_orders` 58,821, `aov` ₹6,261, 75.09% of orders carry surge, 11.99% carry a coupon
  - `vendor_earnings_bucket`: GoldPlus 47.08% / Gold 13.46% / Silver 10.05% / Bronze 23.06% / New 6.35% — **sums to exactly 100.00%**, confirming the bucket-attribution logic partitions revenue cleanly
- **Harness:** `python3 run_tests.py` → **110 passed, 0 failed** (16 new answerable cases across the 10 sections, 10 new structural-render checks, 10 new column-production checks covering all 82 metric ids, 10 metric ids added to `--metric`-only after a guard-conflict fix — see D13).
- **Not independently reconciled against a second source-of-truth baseline for most sections** — same caveat as `V5`/`V6`: this validates "the mirror is byte-faithful and produces sane numbers," not "an independent system agrees with the number," except where noted above (`vendor_earnings_pctl` vs TPO's `orders_base`, `vendor_tpo_top5` vs this catalog's own `tpo_vendor_raised` — two real, non-tautological cross-checks that happened to be available).
- **Readiness:** all 10 sections `built:True`, `readiness:prototype_only`. **No stakeholder promotion — owner's call.**

### V8 — Ship the `leads_overall` → `leads_overall_intra_city` rename (`PNM-G-093`) — **PASS**
- **Date:** 2026-09-04 · Live Snowflake read-only SELECT, same session.
- **Trigger:** the rename itself was ruled `owner-ruling:2026-08-26` (`PNM-G-090`) but not implemented until now; user directed that if the metric stays scoped to intra-city, the id/definition must say so explicitly rather than reading as PnM's overall lead volume.
- **Change:** renamed the id at every call site in one pass — `metrics_registry.py`'s `METRICS` key and `conversion_overall`'s `"denominator"` field, `sqlgen.py`'s `AGG_LEADS` column alias and `funnel_sql`'s select list, `run_tests.py`'s 2 `ANSWERABLE` cases. No SQL logic changed, only the alias text (`ask.py`'s `row.get(metric_id)` requires id == alias, `D9`).
- **Harness:** `run_tests.py --today=2026-09-04` → **110 passed, 0 failed**.
- **Live re-reconciliation:** rendered `leads_sql('2026-05')` pre- and post-rename — identical except the alias — and executed it live: **336,291**, vs the `V3` anchor of 336,338 (2026-07-08). The 47-lead (0.014%) gap is attributed to late-arriving/backfilled records in the source tables between the two run dates, not the rename; the query text proves it (no filter or join changed).
- **Docs:** `metrics.md` §1, `business.md`'s snapshot row label, `sources.md`'s `PNM-S-051` cross-reference, `CONTEXT.md`'s state-of-the-work note all updated to the new id.
- **Readiness:** unchanged — `leads` section stays `built:True`, `readiness:prototype_only`.

### V9 — Measure the `RANK()` tie risk on `supervisor_actions` (`PNM-G-096`) — **PASS**
- **Date:** 2026-09-04 · Live Snowflake read-only SELECTs.
- **Query 1 (all-time):** partitioned `PROD_ELDORIA.RAW.PNM_APPLICATION_SUPERVISOR_ACTIONS` by `order_id` for `action = 'ShiftingStarted'`, ranked by `event_ts_ist DESC`, grouped the rank-1 rows by `order_id`. Result: **2,107,392 orders have a `ShiftingStarted` action; 880 (0.042%) have an exact-timestamp tie at the max, always exactly 2 rows (`max_tie_group_size = 2`).** The risk `PNM-G-096` flagged as latent is real, at low but non-zero incidence.
- **Query 2 (materiality check):** joined the 880 tied `order_id`s against the same population `ota_sql` builds for 2026-05 (`FACT_PNM_ORDERS`/`DIM_PNM_ORDERS`, `o_completed_ts` month = 2026-05, `shifting_type = 'intra_city'`, 49,400 orders). **Zero overlap** — none of the 880 ties fell inside the month this catalog's `ota` section actually reconciled (`V5`), so that reconciliation stands unaffected.
- **Disposition:** not fixed — `RANK()` → `ROW_NUMBER()` + a secondary tiebreak would be a definition change to code that deliberately mirrors an owner-ruled source (Card #37409, `D11`), not something to alter unreviewed. Logged and bounded instead: `metrics.md` §7, `PNM-G-096` closed with the measurement as evidence, not by fixing the tie.

---

## 3. Known non-conflicts (intentional, do not "fix")
- **`ORDERS_SOURCE_DECISION.finding/evidence`** still describe the original raw-table problem — kept as the historical record of how D3 was reached; `status` = RESOLVED + `resolution` documents the outcome.
- **Nano filter form differs by section** — leads/orders use `package_name NOT ILIKE 'Nano%'` (prefix); TPO uses `NOT ILIKE '%Nano%'` (contains) on `package_name`/`hs_package`. This is faithful to the two different validated queries, not an inconsistency to unify.

---

## 4. Open items / execution round (owner-run, per D1)
1. ~~Run the 4 rendered SQLs for 2026-05 and reconcile vs the automation.~~ **DONE 2026-07-08 — see V3, exact match.** Remaining (optional): owner cross-check vs the Notion Demand DB; extend to more months.
2. Update the readiness ledger; owner decides any promotion (still all `prototype_only`).
3. **Section status:** `p80_durations` + `order_edits` **now BUILT** (`prototype_only`) via D8–D10 / V4 (2026-07-19). `ota` stays **blocked** (no clean data source — needs an owner definition decision; note `PNM_EXPERIENCE` now exposes `OTA_FLAG` / `OTA_BREACH_TAT_MINUTES`, a candidate source to evaluate later). ⚠ **SUPERSEDED 2026-09-04** — `ota` is now **BUILT** (`prototype_only`) via D11 / V5, on a source (Metabase card #37409) neither `PNM_EXPERIENCE.OTA_FLAG` nor any candidate named here.
4. **Housekeeping (owner call):** stale flattened copies exist in the parent working folder `selfserve/pnm/` (`dry_run_report.md`, `rendered_tpo_202605.sql`, old `config/queries/...py`) — these predate the clone and are NOT the deliverable; left untouched (pre-existing, not created by this work).
5. **DONE 2026-07-09:** committed + pushed to `claude/pnm-metrics-catalog-map-vg251i`; `HANDOFF.md` §4/§6 updated to RESOLVED.
6. **DONE 2026-09-04:** `ota` (D11/V5) and `gac_ctr` (D12/V6) built, then the remaining 10 MBR groups built in one pass (D13/V7). Catalog now **137 metrics across 18 sections**, matching every group the MBR automation runs (`PNM-G-071` closed). All still `prototype_only` — no stakeholder promotion.
