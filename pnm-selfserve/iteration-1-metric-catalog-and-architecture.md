# PnM MBR Metrics — Iteration 1: Metric Catalog & Proposed NL Query Architecture

*Prepared 2026-07-07. Sources: `config.py`, `queries.py`, `runner.py`, `validator.py` (read in full).
`gsheet_client.py` was not available to read — its behavior below is taken from the program
context description only (current-month rows overwritten weekly; completed-month rows locked
after first write). No code was written or modified in this iteration. This document was
adversarially cross-checked against the four source files (completeness, flag fidelity,
definition accuracy, constraint compliance) before delivery.*

---

## Part 1 — Metric Catalog

Every column the script currently outputs, grouped by the section that produces it.
Sections are the `METRIC_SECTIONS` bundles (plus `derived`, computed in pandas in `runner.py`).
Verify flags are carried **verbatim** from source comments — none have been resolved.

**Catalog-wide scope (from `queries.py` header, verbatim):**
> Scope: intra_city = TRUE, user_flag = 'normal', exclude Nano where noted.
> Methodology source: Metabase card #30311  +  Notion MoM doc
> https://app.notion.com/p/3599c6eaaa6d8016b554fc2e8e3bf577

**Catalog-wide flag (from `config.py` TABLES header, verbatim — applies to every table reference):**
> \# Verify these against Snowflake before running for the first time.
> \# Canonical methodology: Metabase card #30311.

**Catalog-wide population caveat:** both staging tables are filtered to rows *created* in the two
queried months (`o_created_ts` / `opp_created_ts` IN target month, previous month). Every section
below inherits this window — the consequences per section are noted where they bite (OTA, P80,
TPO populations; channel attribution).

Metadata columns also written per row: `month`, `run_ts` (not metrics).

### Section: `leads` — 5 metrics

- **Grain:** calendar month of `opp_created_ts` (lead creation month)
- **Base population:** intra-city, normal-user opportunities. **Nano is included** (staging leads table has no `is_nano` filter — `is_nano` is selected but never filtered).
- **Source tables:** `fact_pnm_opprotunity` joined to `dim_pnm_opportunity`
- **Section verify flags (verbatim from `config.py`):** `"fact_opp": "PROD_CURATED.pnm_application.fact_pnm_opprotunity", # note: typo in source table` — plus the config-wide "Verify these against Snowflake before running for the first time."

| Metric | Business definition (inferred from SQL) |
|---|---|
| `leads_overall` | Distinct PnM opportunities (booking-funnel leads) created in the month. |
| `leads_app` | Leads originating from the Porter app (`source IN (1,2,3)`). |
| `leads_desktop` | Leads from the desktop website (`source_details = 'Desktop Website'`). |
| `leads_mobile` | Leads from the mobile website (`source_details = 'Mobile Website'`). |
| `leads_others` | Leads from other channels (`source = 4`). |

### Section: `orders` — 5 metrics

- **Grain:** calendar month of `o_created_ts` (order creation month)
- **Base population:** intra-city, normal-user orders with a matching `pnm_customers` row, `status != 4` (status code meaning is not documented anywhere in the files — inferred to exclude a cancelled/invalid state), **deduplicated to the first order per `sr_id`** (service request). **Nano is included** (no `is_nano` filter in this section).
- **Source attribution:** via LEFT JOIN to the leads staging table on `sr_id` — an order inherits its lead's source channel. Because the leads staging table only holds leads *created in the two queried months*, an order whose lead is older joins to nothing, gets NULL source, and drops out of **all four** channel splits (it still counts in `orders_overall`). Channel splits are therefore structurally undercounted near window boundaries.
- **Dedup edge effects:** the `QUALIFY ROW_NUMBER()` dedup runs *after* the lead join, so if one `sr_id` matches multiple in-window leads the surviving row's source channel is effectively arbitrary; and `PARTITION BY sr_id` collapses all NULL-`sr_id` orders into a single surviving row (whether `sr_id` is nullable is unverified).
- **Section verify flags:** none specific; config-wide flag applies, and the `fact_opp` typo note above is inherited through the lead-attribution join.

| Metric | Business definition (inferred from SQL) |
|---|---|
| `orders_overall` | Distinct booked orders created in the month (first order per service request; excludes status-4 orders). |
| `orders_app` | Booked orders attributed to an app-originated lead (`source IN (1,2,3)`), lead created within the query window. |
| `orders_desktop` | Booked orders attributed to a desktop-website lead (same window caveat). |
| `orders_mobile` | Booked orders attributed to a mobile-website lead (same window caveat). |
| `orders_others` | Booked orders attributed to an other-channel lead (`source = 4`) (same window caveat). |

### Section: `derived` — 7 metrics (computed in pandas, `runner.py::_compute_derived_metrics`)

- **Grain:** calendar month; ratio of same-month `leads` and `orders` aggregates.
- **Semantics note:** conversion is *period* conversion — orders **created** in month M ÷ leads **created** in month M. It is not lead-cohort conversion (a May lead converting in June appears in June's numerator, May's denominator). This is faithful to how the script computes it; any NL layer must preserve it. Per-channel conversions additionally pair a window-limited numerator (attributed orders only) with a full channel-lead denominator.
- **Ratio hygiene:** these are computed from raw monthly counts (numerator ÷ denominator), *not* by averaging pre-computed ratios — the NL layer must do the same.
- **Precondition:** `runner.py` computes this section only when **both** `leads` and `orders` returned rows; if either failed, all 7 derived metrics silently vanish, with no failure log line of their own.
- **Section verify flags:** none specific; inherits whatever `leads`/`orders` carry.

| Metric | Business definition |
|---|---|
| `conversion_overall` | Orders created in the month as a % of leads created in the same month. |
| `conversion_app` | App-channel orders ÷ app-channel leads, same month, %. |
| `conversion_desktop` | Desktop-web orders ÷ desktop-web leads, same month, %. |
| `conversion_mobile` | Mobile-web orders ÷ mobile-web leads, same month, %. |
| `pct_orders_app` | % of booked orders that came via the app. |
| `pct_orders_website` | % of booked orders that came via website (desktop + mobile web combined). |
| `pct_orders_others` | % of booked orders from other channels. |

### Section: `ota` — 3 metrics

- **Grain:** calendar month of `o_completed_ts` (order completion month), restricted to orders *created* in the two queried months (staging window) — so a month's OTA base excludes older-created orders completing in it, and orders completing in the month after the window emit a partial spillover row.
- **Base population:** completed (`status = 2`) non-Nano intra-city orders with a completion timestamp.
- **⚠ VERIFY (verbatim from `queries.py`):** `⚠ VERIFY: scheduled_pickup_ts, vendor_arrived_ts, coordinate column names.`

| Metric | Business definition (inferred from SQL) |
|---|---|
| `base_orders` | Completed non-Nano intra-city orders in the month (OTA denominator). |
| `ota_pct` | % of completed orders where the vendor arrived ≤ 30 minutes after the scheduled pickup time AND ≤ 2 km from the scheduled pickup location. |
| `delay_over_60_mins_pct` | % of completed orders where vendor arrival was more than 60 minutes late. |

> **Structural observation (new — surfaced, not resolved):** `QUERY_OTA` selects
> `scheduled_pickup_ts`, `vendor_arrived_ts`, `scheduled_pickup_lon/lat`, `actual_arrival_lon/lat`
> from the staging table `pnm_mbr_orders` — but `CREATE_STG_ORDERS` does **not** include any of
> those six columns in its select list. As written, the OTA query fails at runtime; `runner.py`
> catches per-section failures (`✗ ota FAILED` in the log) and the merge step then drops the empty
> section entirely, so the OTA columns are simply **absent** from the output — indistinguishable
> from "not yet run" without reading logs. This compounds the section's ⚠ VERIFY flag: OTA appears
> to be unrunnable in its current form until the column sourcing is settled.

### Section: `p80_durations` — 6 metrics

- **Grain:** calendar month of `o_completed_ts`, restricted to orders *created* in the two queried months (same staging-window caveat as OTA).
- **Base population:** completed (`status = 2`) non-Nano intra-city orders where `shifting_started_ts` AND `order_completed_ts` are both present.
- **Section verify flags:** none specific (config-wide flag applies).
- **Population caveat:** the NOT-NULL filter covers only two of the seven timestamps; `PERCENTILE_CONT` silently drops NULL diffs, so **each milestone's P80 is computed over a potentially different subset of orders**.

| Metric | Business definition (inferred from SQL) |
|---|---|
| `p80_trip_duration_mins` | 80th-percentile minutes from shifting start to order completion (the customer-visible "move duration"). |
| `p80_vendor_accept_to_sup_assign_mins` | P80 minutes from vendor acceptance to supervisor assignment. |
| `p80_sup_assign_to_trip_start_mins` | P80 minutes from supervisor assignment to trip start. |
| `p80_trip_start_to_shifting_start_mins` | P80 minutes from trip start to shifting start (travel to pickup). |
| `p80_shifting_start_to_pickup_complete_mins` | P80 minutes from shifting start to pickup completion (loading). |
| `p80_pickup_complete_to_order_complete_mins` | P80 minutes from pickup completion to order completion (transit + unloading). |

### Section: `tpo` — 13 metrics

- **Grain:** calendar month of **allocation completion** (`order_allocation_infos.completed_ts`) — *not* order creation or completion month. Unique among the sections; NL answers must state this. Restricted to orders *created* in the two queried months (staging window), so "orders whose allocation completed in month M" really means "orders created in the window whose allocation completed in M."
- **Base population (denominator):** distinct non-Nano intra-city orders (from the staging order base, so also first-order-per-SR, `status != 4`) with a completed allocation in the month.
- **Ticket scope (numerators):** tickets joined by `order_id` and counted **only if created in the same calendar month** as the allocation completion — tickets raised in any other month (earlier *or* later) are excluded entirely, attributed to no month. Tickets where `LOWER(raised_by) LIKE '%detractor%'` are excluded everywhere.
- **⚠ VERIFY (verbatim from `queries.py`):** `⚠ VERIFY: tickets table name, raised_by / order_status_at_creation column names.`
- **verify (verbatim from `config.py`):** `"tickets": "PROD_CURATED.pnm_application.tickets", # verify table name`

| Metric | Business definition (inferred from SQL) |
|---|---|
| `orders_base` | Distinct non-Nano intra-city orders (created in the query window) whose allocation completed in the month (TPO denominator). |
| `tpo_overall` | Support tickets per order — all non-detractor tickets ÷ orders_base. |
| `tpo_vendor_raised` | Tickets raised by vendors (`'Vendor-Owner','Vendor-Supervisor'`) per order. |
| `tpo_pre_trip` | Tickets raised while the order was pre-trip (status at creation in open / supervisor_assigned / supervisor_accepted / vendor_accepted) per order. |
| `tpo_pre_trip_customer` | Customer-raised subset of pre-trip tickets, per order. |
| `tpo_trip_shift` | Tickets raised during trip/shifting (trip_started / shifting_started) per order. |
| `tpo_trip_shift_customer` | Customer-raised subset, per order. |
| `tpo_pickup` | Tickets raised at the pickup_completed stage, per order. |
| `tpo_pickup_customer` | Customer-raised subset, per order. |
| `tpo_completed` | Tickets raised after order completion, per order. |
| `tpo_completed_customer` | Customer-raised subset, per order. |
| `tpo_cancelled` | Tickets whose order status **at ticket creation** was `cancelled`, per order — see the status-code tension in Part 2b #3. |
| `tpo_cancelled_customer` | Customer-raised subset of the above, per order. |

> **Structural observation (new — surfaced, not resolved):** if `order_allocation_infos` can hold
> more than one completed-allocation row per order, ticket numerators inflate **quadratically**
> (the `ticket_data` CTE joins tickets to the duplicated order base once — ×k — and the `monthly`
> CTE joins the duplicated base to those duplicated tickets again — ×k²), while
> `COUNT(DISTINCT order_id)` protects only the denominator. An order whose completed allocations
> span different months would also enter multiple months' denominators. Whether multiple
> allocation rows per order exist is unverified either way — it belongs on the same open-questions
> list as the ⚠ VERIFY flags.

### Section: `order_edits` — 10 metrics

- **Grain:** calendar month of `o_created_ts` (order creation month) — note the denominator is *completed* orders bucketed by *creation* month.
- **Base population (denominator):** completed (`status = 2`) non-Nano intra-city orders.
- **Edit scope:** only modification events with `category IN ('Locations','ShiftingTime','Items','AddOns')`; edits are **not** time-filtered — any qualifying edit on a base order counts, whenever it happened.
- **⚠ VERIFY (verbatim from `queries.py`):** `⚠ VERIFY: order_modifications table name; category / source / order_phase columns.`
- **verify (verbatim from `config.py`):** `"order_mods": "PROD_CURATED.pnm_application.order_modifications", # verify table name`

| Metric | Business definition (inferred from SQL) |
|---|---|
| `total_orders` | Completed non-Nano intra-city orders created in the month (edits denominator). |
| `pct_orders_edited` | % of those orders with at least one edit in the four tracked categories. |
| `num_successful_edits` | Total qualifying edit events (whenever made) on orders created in the month — events, not distinct orders. |
| `pct_support_edited_orders` | % of orders with at least one edit made outside customer self-serve channels (`source NOT IN ('customer_app_webview','customer')`) — i.e., support/ops had to do it. |
| `pct_edit_location_adoption` | % of orders with ≥ 1 location edit. |
| `pct_edit_items_adoption` | % of orders with ≥ 1 items edit. |
| `pct_edit_addons_adoption` | % of orders with ≥ 1 add-ons edit. |
| `pct_edit_slot_adoption` | % of orders with ≥ 1 shifting-time (slot) edit. |
| `edits_per_order` | Total edit events ÷ total orders. |
| `pct_edits_after_shifting` | % of edit events made after shifting started (`order_phase IN ('after_shifting_started','after_pickup_completed')`). |

### Catalog totals

**49 metric columns** across 7 producing units: leads (5) + orders (5) + derived (7) + ota (3) +
p80_durations (6) + tpo (13) + order_edits (10) — 51 columns in the merged output including
`month` and `run_ts` metadata.

---

## Part 2 — Open flags & cross-cutting observations

### 2a. Verify flags carried verbatim (the canonical open-questions list)

| # | Where | Flag (verbatim) |
|---|---|---|
| 1 | `config.py` TABLES header | `# Verify these against Snowflake before running for the first time.` |
| 2 | `config.py` `fact_opp` | `# note: typo in source table` (table is spelled `fact_pnm_opprotunity`) |
| 3 | `config.py` `tickets` | `# verify table name` |
| 4 | `config.py` `order_mods` | `# verify table name` |
| 5 | `queries.py` §5 OTA | `⚠ VERIFY: scheduled_pickup_ts, vendor_arrived_ts, coordinate column names.` |
| 6 | `queries.py` §7 TPO | `⚠ VERIFY: tickets table name, raised_by / order_status_at_creation column names.` |
| 7 | `queries.py` §8 ORDER EDITS | `⚠ VERIFY: order_modifications table name; category / source / order_phase columns.` |

Per your constraint, none of these are resolved here — they are the open-question list any
readiness classification in iteration 2 will be scored against. Counting only the `⚠ VERIFY`
markers: **ota, tpo, order_edits** carry direct section flags. Flag #2 attaches directly to
**leads** (its primary fact table), and **orders**/**derived** inherit it through the lead-attribution
join. Flag #1 (config-wide) covers every section, including **p80_durations**.

### 2b. New observations (surfaced by this mapping — labeled mine, not resolutions)

1. **OTA is structurally unrunnable as written** — its query references six columns the staging
   table never materializes (detail in the OTA section above). Runner fail-soft means this
   surfaces only as a log line, and the merge drops the section, so OTA columns are silently
   absent from the sheet.
2. **The parameter binding style appears broken under every paramstyle the Snowflake Python
   connector supports.** The queries use named `:month_start` binds with a dict;
   `snowflake-connector-python` supports `pyformat` (default), `qmark`, and `numeric` — not
   named-colon binding. Under the default `pyformat`, the literal `%detractor%` wildcards in
   `QUERY_TPO` would additionally break client-side `%`-interpolation. Combined with flag #1
   ("before running for the first time"), this strongly suggests the pipeline has **not yet
   completed a real end-to-end run** — which changes how much trust any "existing" numbers
   deserve, and means iteration 2's first Snowflake touch is a first-ever validation of this
   logic, not a re-run.
3. **Status codes are undocumented, and one metric depends on the tension.** `status != 4`
   (staging exclusion) and `status = 2` (treated as "completed" in ota / p80 / order_edits) are
   load-bearing but confirmed nowhere. If 4 does mean "cancelled," then `tpo_cancelled` — which
   counts tickets whose order status *at ticket creation* was `cancelled`, over a base that
   excludes currently-cancelled orders — could only ever count tickets on orders that were later
   un-cancelled, making it structurally near-zero. Either the status-code inference or that
   metric's usefulness is wrong; not resolved here.
4. **Nano inclusion differs by section.** leads, orders, and all derived conversion/mix metrics
   include Nano; ota, p80, tpo, order_edits exclude it. Consistent with the header's "exclude
   Nano where noted," but a stakeholder comparing `orders_overall` to `total_orders` is comparing
   different populations — the NL layer must say so.
5. **The staging creation-month window shapes every section, and produces spillover months.**
   OTA/P80/TPO group by completion/allocation month but read only orders *created* in the two
   queried months. So (a) their month-M populations exclude older-created orders, (b) in-window
   orders completing/allocating in the following month emit a **partial extra-month row**, which
   the outer merge carries into the sheet write (whether the lock logic then freezes a partial
   month is unknown — `gsheet_client.py` unread), and (c) channel attribution only works for
   leads created inside the window (see orders section). My earlier framing "the pipeline only
   ever computes 2 months" is true of the creation-grain sections only.
6. **The drift validator is weaker than it looks.** Its month pick is positional
   (`sorted_months[-2]`), not semantically "last complete month" — and spillover rows from #5
   can shift which month actually gets checked. Denominators (`total_orders`, `orders_base`,
   `base_orders`) are exempt via SKIP_COLS, so a base-population shift never alerts — everything
   else numeric is guarded (ratios, counts, p80 durations alike). Columns absent from the stored
   history row are silently skipped, so newly added metrics are never drift-checked. And since
   Snowflake returns NUMBER as `decimal.Decimal` and the runner builds DataFrames from raw
   tuples, metric columns may land as `object` dtype and fail the `is_numeric_dtype` gate —
   potentially excluding many metrics from the check entirely. Worth confirming in iteration 2
   before trusting any "passed drift" result.
7. **The runner's MTD story contradicts its own code.** The docstring says a default run computes
   "last complete month + current MTD," but the default target is
   `today.replace(day=1) - 1 month` — i.e., the **last complete month** — so a default run
   computes last-complete + the month before, and never touches the actual in-progress month.
   `current_month_str`, commented as the "in-progress MTD month → overwrite on every Monday run,"
   is therefore a *complete* month under default invocation, shifting which sheet row is
   overwritable vs locked by one month from the documented intent. Either the docstring or the
   target selection is wrong; this must be settled before iteration 2 hard-codes any MTD answer
   wording.
8. **Sections fail soft, and `derived` fails softest.** Any section's query failure yields an
   empty DataFrame plus a log line; the merged output simply lacks those columns. `derived` is
   computed only when both `leads` and `orders` returned rows, and is otherwise skipped with no
   failure line of its own. A missing metric in the sheet is indistinguishable from "not yet run"
   without reading logs.
9. **Dedup edge effects in the order base.** Because dedup happens after the lead join, an
   `sr_id` with multiple in-window leads gets a nondeterministic source channel; all NULL-`sr_id`
   orders collapse into one surviving row (nullability unverified).
10. **TPO join fan-out risk** — see the TPO section blockquote: unverified possibility of
    quadratic numerator inflation and multi-month denominator duplication if orders can have
    multiple completed allocation rows.
11. **`gsheet_client.py` unread.** Lock semantics (completed months locked after first write) are
    taken on faith from your description. Iteration 2's drift/sanity checks should not assume its
    behavior until it's been read — please upload it.

---

## Part 3 — Proposed architecture: a minimal local NL query layer

### Design constraints taken as requirements

- Answers **one metric question at a time**; no weekly run, no staging-table writes, no Sheet round-trip.
- **Read-only against Snowflake**, and even then: show the exact SQL first, execute only on explicit go-ahead (your dry-run-default rule becomes the tool's default mode).
- **Closed-world**: it can only answer questions that resolve to a catalog metric. Anything else — new dimensions ("OTA in Bangalore"), new grains ("weekly TPO"), uncataloged metrics — is refused with "not in the catalog," never improvised. This mirrors the Argus confidence model, where below-threshold questions refuse rather than guess.
- **Section = release unit**, matching `METRIC_SECTIONS`; readiness is a per-section switch only you flip. Metrics inherit their section's readiness — no per-metric overrides.
- **Verify flags travel with every answer.** A TPO answer arrives wearing flags #3 and #6, verbatim.
- **No new dependencies** (uses `snowflake-connector-python` + `pandas`, already required by the existing pipeline). No LLM API calls inside the tool.
- Existing five files remain untouched; everything lives in a new subfolder.

### Shape: three layers, only one of which is "AI"

```
pnm/selfserve_nlq/                      ← new subfolder (iteration 2)
  metrics_registry.py    ① declarative catalog  (data, no logic)
  sqlgen.py + ask.py     ② deterministic query engine (logic, no AI)
  (Claude session)       ③ NL resolution layer  (AI, no SQL authority)
  answers_log/           append-only audit: question → SQL → result → flags shown
```

**① Metric registry** — Part 1 of this document turned into a data structure. One entry per
metric: id, section, business definition, unit, SQL template + params, grain (month),
base-population description, `verify_flags` (verbatim strings), plain-English aliases ("tickets
per order", "TPO", "how many complaints per move"). Readiness lives at the **section** level:
`readiness: prototype_only | stakeholder_ready | blocked` — everything starts `prototype_only`
(`blocked` for anything unrunnable, e.g. OTA today); only you promote to `stakeholder_ready`.
The registry is deliberately shaped like a pre-YAML Argus metric definition, so when dbt models
eventually exist, exporting to the governed Metric Store format is mechanical — and until then
this stays explicitly *outside* the store, per the program rule that Metabase-sourced metrics
without dbt models aren't eligible.

**② Deterministic query engine** — one parameterized, **read-only** SELECT per section that
inlines the staging logic as CTEs. To be precise, the staging bodies are **adapted, not copied**:
the `CREATE OR REPLACE` wrapper is dropped, the orders CTE's reference to the physical
`pnm_mbr_leads` staging table is rewritten to point at the inlined leads CTE (otherwise we'd
silently reintroduce the cron-staleness and Monday-run race this design exists to avoid), and the
broken named-colon binds are converted to a supported paramstyle (observation 2b #2). The inlined
leads CTE always covers **requested month + previous month**, replicating the pipeline's
attribution window exactly. No writes to `NEW_INITIATIVE_ANALYTICS`, no dependence on when the
cron last ran, any month parameterizable.

**Fidelity stance:** the engine replicates the pipeline's semantics **bug-for-bug** — including
the staging-window population quirks and attribution undercount of 2b #5 — so answers reconcile
with the MBR sheet, and the quirks are disclosed in the answer footer rather than silently
"fixed." Correcting semantics is a definition change and stays out of scope unless you order it.

Derived metrics (conversion, order mix) are computed the same way `runner.py` does — from raw
counts fetched in the same call, ratios built from aggregated numerator ÷ denominator, **never**
by averaging stored ratios. A multi-month ratio question ("OTA across Q2") is answered by
re-aggregating numerator and denominator over the period, flagged as a non-MBR aggregation.
A multi-month **percentile** question is answered only by recomputing `PERCENTILE_CONT` over the
pooled orders in one query — never by averaging monthly P80s; if pooling isn't expressible for
the ask, refuse.

CLI contract:

```
python ask.py --metric tpo_overall --month 2026-05           # prints rendered SQL and exits (default = dry-run)
python ask.py --metric tpo_overall --month 2026-05 --execute # runs the single read-only SELECT
python ask.py --list                                         # catalog with sections, flags, readiness
```

**③ NL resolution stays in the Claude session** — the "AI-enabled" part is me (or later, a
skill) reading the registry and mapping "how many tickets per order did we get in May?" →
`tpo_overall, 2026-05` → calling `ask.py`. The AI never authors SQL — and that's enforced by the
tool boundary, not convention: Snowflake credentials are exercised only through `ask.py`, which
rejects any metric id not in the registry, so the session layer has no free-form query path.
This is exactly the query-metrics-skill shape from Project Argus, minus packaging — which keeps
your checkpoint-3 decision genuinely open: formalizing later means wrapping the registry + CLI in
a skill definition, not rebuilding anything.

### Answer contract (every answer, no exceptions)

```
TPO (overall) for May 2026: 0.41 tickets/order   (orders_base = 8,214)

Source: PnM MBR catalog §tpo — non-detractor tickets ÷ orders with allocation completed in month
Month basis: allocation-completion month (NOT order creation month); population limited to
  orders created in May–April window (pipeline staging semantics, replicated deliberately)
Computed: live from PROD_CURATED.pnm_application at query time
  (may differ from the locked MBR sheet value, which is a frozen weekly snapshot)
Readiness: PROTOTYPE-ONLY
⚠ Open flags on this section:
  - "⚠ VERIFY: tickets table name, raised_by / order_status_at_creation column names."
  - "tickets table: # verify table name" (config.py)
```

Questions about a month that is still in progress are always answered as **"MTD as of <date>"**
and never presented as a final monthly number. Note this labeling is defined by the NL layer
itself (incomplete month ⇒ MTD), *not* inherited from the pipeline — whose own MTD handling is
internally contradictory (observation 2b #7) and must be settled before iteration 2 finalizes
the wording for "which sheet value am I diverging from."

### Sanity hook (stand-in for the Sheet round-trip)

Optional `--check`: for a completed month, compare the live answer against the most recent local
run log (`logs/run_*.json` `data_preview`) if one exists, reusing `validator.py`'s ±2.5% drift
logic. Local files only — no Sheet access. A failed check downgrades the answer's presentation
("live value diverges from last pipeline snapshot by X% — investigate before quoting"). Caveat:
given 2b #2, such run logs may not exist yet at all.

### What v0 deliberately does not do

No free-form text-to-SQL. No new dimensions or grains. No city/vendor/category cuts. No Sheet
reads or writes. No scheduling. No caching beyond the append-only answers log. No stakeholder
access mechanism — readiness classification is an output of iteration 2/3, and opening access is
your call, outside this tool.

### Alternatives considered and rejected

| Alternative | Why rejected |
|---|---|
| Free text-to-SQL over `pnm_application` | Untrustworthy for MBR-grade numbers; would silently "resolve" ⚠ VERIFY columns by guessing — the exact failure the constraint forbids. Argus's own design (confidence gradient, refusal below threshold) points the same direction. |
| Query the Google Sheet instead of Snowflake | Explicitly excluded (the round-trip is what we're removing); only stores whatever the weekly run wrote; can't answer months/params beyond the snapshots. |
| Reuse the weekly staging tables | Couples every answer to cron freshness; tables only ever hold ~2 months of created-orders; racing the Monday `CREATE OR REPLACE` mid-question is possible; keeps an unnecessary write dependency in what should be a read-only path. |
| Onboard straight into the Argus metric store | Blocked by the program's own rule — Metabase-sourced metrics with no dbt model behind them aren't eligible. This prototype is the bridge; its registry is designed to export to metric YAML when eligibility is met. |

### Known limits to state up front

- Monthly grain only; the catalog's baked-in filters (intra-city, normal users, per-section Nano
  handling) are not user-adjustable.
- The `ota` section carries both a ⚠ VERIFY flag **and** the structural staging-column mismatch
  (2b #1) — it cannot be live-queried at all until its column sourcing is settled, so it enters
  iteration 2 as `blocked`, not merely PROTOTYPE-ONLY.
- Live answers replicate the pipeline's staging-window semantics (2b #5) by design; that fidelity
  choice means known population quirks are reproduced, disclosed, and not corrected.
- Live answers for months older than the pipeline's window run the same logic against today's
  tables; retention/backfill behavior of the underlying `pnm_application` tables is unverified
  for older periods.
- Observation 2b #2 means iteration 2's first Snowflake touch should be treated as the first-ever
  end-to-end validation of the query logic — every query shown to you before execution, per the
  standing rule.
