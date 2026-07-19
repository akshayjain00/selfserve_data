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

---

## 3. Known non-conflicts (intentional, do not "fix")
- **`ORDERS_SOURCE_DECISION.finding/evidence`** still describe the original raw-table problem — kept as the historical record of how D3 was reached; `status` = RESOLVED + `resolution` documents the outcome.
- **Nano filter form differs by section** — leads/orders use `package_name NOT ILIKE 'Nano%'` (prefix); TPO uses `NOT ILIKE '%Nano%'` (contains) on `package_name`/`hs_package`. This is faithful to the two different validated queries, not an inconsistency to unify.

---

## 4. Open items / execution round (owner-run, per D1)
1. ~~Run the 4 rendered SQLs for 2026-05 and reconcile vs the automation.~~ **DONE 2026-07-08 — see V3, exact match.** Remaining (optional): owner cross-check vs the Notion Demand DB; extend to more months.
2. Update the readiness ledger; owner decides any promotion (still all `prototype_only`).
3. **Section status:** `p80_durations` + `order_edits` **now BUILT** (`prototype_only`) via D8–D10 / V4 (2026-07-19). `ota` stays **blocked** (no clean data source — needs an owner definition decision; note `PNM_EXPERIENCE` now exposes `OTA_FLAG` / `OTA_BREACH_TAT_MINUTES`, a candidate source to evaluate later).
4. **Housekeeping (owner call):** stale flattened copies exist in the parent working folder `selfserve/pnm/` (`dry_run_report.md`, `rendered_tpo_202605.sql`, old `config/queries/...py`) — these predate the clone and are NOT the deliverable; left untouched (pre-existing, not created by this work).
5. **DONE 2026-07-09:** committed + pushed to `claude/pnm-metrics-catalog-map-vg251i`; `HANDOFF.md` §4/§6 updated to RESOLVED.
