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

---

## 3. Known non-conflicts (intentional, do not "fix")
- **`ORDERS_SOURCE_DECISION.finding/evidence`** still describe the original raw-table problem — kept as the historical record of how D3 was reached; `status` = RESOLVED + `resolution` documents the outcome.
- **Nano filter form differs by section** — leads/orders use `package_name NOT ILIKE 'Nano%'` (prefix); TPO uses `NOT ILIKE '%Nano%'` (contains) on `package_name`/`hs_package`. This is faithful to the two different validated queries, not an inconsistency to unify.

---

## 4. Open items / execution round (owner-run, per D1)
1. ~~Run the 4 rendered SQLs for 2026-05 and reconcile vs the automation.~~ **DONE 2026-07-08 — see V3, exact match.** Remaining (optional): owner cross-check vs the Notion Demand DB; extend to more months.
2. Update the readiness ledger; owner decides any promotion (still all `prototype_only`).
3. **Not built (by design this iteration):** `p80_durations` (not_built), `ota` (blocked — no data source), `order_edits` (not_built). Their `month_basis` still references legacy `o_completed_ts` and will need an eldoria/mart mapping when built (the automation already has `TRIP_DURATION_PERCENTILE_QUERY` and `EDIT_ADOPTION_QUERY` to mirror).
4. **Housekeeping (owner call):** stale flattened copies exist in the parent working folder `selfserve/pnm/` (`dry_run_report.md`, `rendered_tpo_202605.sql`, old `config/queries/...py`) — these predate the clone and are NOT the deliverable; left untouched (pre-existing, not created by this work).
5. **DONE 2026-07-09:** committed + pushed to `claude/pnm-metrics-catalog-map-vg251i`; `HANDOFF.md` §4/§6 updated to RESOLVED.
