# PnM Self-Serve NL Query Layer — HANDOFF

*For continuing this work in a fresh Claude Code terminal. Written 2026-07-07.
Branch: `claude/pnm-metrics-catalog-map-vg251i`. Owner: akshay.jain@theporter.in.*

> No "handoff" skill exists in this workspace (searched — none found), so this is a
> hand-written handoff doc. Read this first, then `iteration-2-readiness-ledger.md`.

> **⚠ UPDATE 2026-07-08 — read `DECISION_LOG.md` first; parts of this doc are now stale.**
> The §4 orders-source decision is **RESOLVED (Option A)** and implemented: `sqlgen.py` now
> MIRRORS the owner's live-validated MBR automation (`pnm/pnm_mbr_monthly_metrics`) —
> leads/orders/derived → `LEADS_CONVERSION_QUERY` (PROD_ELDORIA core/mart), tpo →
> `TPO_TREND_QUERY` / card #47576 (PROD_CURATED raw). Nano rule: included in leads,
> excluded from orders/tpo (→ LA). `run_tests.py` = 31/31. Sections remain PROTOTYPE-ONLY,
> pending the owner-run execution round. Where this doc and `DECISION_LOG.md` disagree, the
> log wins.

---

## 1. One-paragraph context

We're prototyping an AI-enabled, self-serve way to ask Porter's PnM MBR metrics in plain
English — **not** building a packaged Claude Code skill yet (that's a later, owner-only call
after 3 checkpoints). The source of truth is a 5-file weekly pipeline (`config.py`, `queries.py`,
`runner.py`, `validator.py`, `gsheet_client.py`) that feeds the PnM Monthly Business Review.
Those 5 files are **read-only** — never edit them; they are NOT in this repo (they were uploads).
All our work lives under `pnm-selfserve/`.

## 2. Where we are (end of iteration 2 + owner review)

- **Iteration 1** (done, reviewed): `iteration-1-metric-catalog-and-architecture.md` — full
  catalog of 49 metrics + the approved architecture.
- **Iteration 2** (done, reviewed): prototype in `selfserve_nlq/` answering **leads, orders,
  derived, tpo**; `iteration-2-readiness-ledger.md` (+ its Post-review update section).
- **Owner decisions just applied:** Path A execution (owner runs on laptop); TPO ticket-side
  adaptation approved + applied; `gsheet_client.py` received (lock behavior confirmed).
- **Nothing is READY FOR STAKEHOLDERS.** No section has been validated against real numbers yet.
- **No stakeholder access has been opened.** That is the owner's call, never ours to execute.

## 3. The architecture in one picture

```
selfserve_nlq/
  metrics_registry.py   ① the menu: 25 metrics, verbatim ⚠ flags, quirks, evidence,
                            section readiness, ORDERS_SOURCE_DECISION, alias resolver
  sqlgen.py             ② the kitchen: one read-only SELECT per section, staging inlined
                            as CTEs, assert_read_only guard
  ask.py                    CLI — DRY-RUN DEFAULT (prints SQL, executes nothing);
                            --execute runs one SELECT via SF_* env vars
  run_tests.py              31 dry-run tests + renders one SQL per section
  tests_output/             dry_run_report.md + rendered_*_2026-05.sql
  answers_log/              append-only audit of executed answers
reference/                  owner-provided validation baselines (P80 CSV) — read-only
```

Rules baked in: closed-world (refuse anything off-menu — no city/vendor/weekly/median),
dry-run by default, no new dependencies, ratios from raw counts (never averaged), MTD labeling
for in-progress months, section-level readiness only the owner promotes, **bug-for-bug fidelity
with quirks disclosed in every answer footer**.

## 4. THE decision that gates everything: orders source

> **RESOLVED 2026-07-08 — Option A chosen, implemented, and reconciled.** Verified column-level via
> Data Catalog and reconciled live against the owner's validated queries (see `DECISION_LOG.md` D3/D5/V3).
> `sqlgen.py` now MIRRORS `LEADS_CONVERSION_QUERY` (PROD_ELDORIA core/mart) and `TPO_TREND_QUERY`/#47576
> (PROD_CURATED raw). Nano: included in leads, excluded from orders/tpo (attributed to LA). 2026-05
> numbers tie out EXACTLY. The analysis below is the historical record of how the decision was reached.

**~95% confidence:** the pipeline's orders staging reads `order_id`, `o_created_ts`,
`o_completed_ts`, `customer_id`, and lifecycle timestamps from `PROD_CURATED.pnm_application.orders`
— but that raw table only has `id, crn, sr_id, source, created_at, updated_at, status(TEXT),
service_type, mobile`. The needed columns are **assembled** in `PROD_ELDORIA.core.fact_pnm_orders`
(confirmed by reading that model's compiled dbt SQL). So **leads/orders/derived/tpo cannot execute
against the configured raw tables at all.**

Implication: "bug-for-bug fidelity to the pipeline" is fidelity to a pipeline that almost
certainly never ran (unsupported named-colon binds + missing columns + "verify before first run").
There is no sheet baseline to reconcile against, which weakens the case for staying on raw tables.

**Choice for the owner (present with % confidence — house rule):**
- **(A) Re-point all sections to the PROD_ELDORIA core/mart dbt models — RECOMMENDED (~85%).**
  A definition change, but it makes the numbers real, matches Metabase card #30311, and unblocks
  Argus eligibility (governed models + semantic models already exist). Requires re-mapping column
  names (e.g. `trip_started_ts` → `trip_started_olc_ts`, `vendor_accepted_ts` →
  `vendor_owner_accepted_ts`), and re-mapping `status = 2 / != 4` to
  `o_completed_ts IS NOT NULL` / `o_cancelled_ts IS NULL` semantics, then re-validating.
- **(B) Keep bug-for-bug on raw `pnm_application` tables (~15%).** Won't execute; only a record
  of the original (broken) intent.

Full detail: `selfserve_nlq/metrics_registry.py` → `ORDERS_SOURCE_DECISION`.
**Do not silently make this change — it needs an explicit owner yes, exactly like the TPO one did.**

## 5. Verify-flag status (evidence gathered via Data Catalog / Metabase — none silently resolved)

| Flag | Finding | Confidence | State |
|---|---|---|---|
| TPO `tickets` table + `order_status_at_creation` | Real table is `sfms_public.hs_tickets`; status col `order_status_when_ticket_created`; join on `crn` (no order_id) | ~90% | **APPLIED** (owner-approved), pending execution validation |
| OTA columns (`scheduled_pickup_ts`, `vendor_arrived_ts`, coords) | Do not exist in any catalogued table | high | **BLOCKED** — needs a real OTA data-source definition |
| `order_modifications` (order_edits) | Not found; `sr_modifications` matches the 4 categories but is keyed on SR, not order | medium | open — iteration-3 decision |
| Methodology card #30311 | Is `[DBT] Conversion %`, reads `prod_eldoria` core/mart, EXCLUDES Nano everywhere, intra-city via `service_type IN ('Default','Default_Short')`, customers on `customer_mobile`, no status filter, no first-order dedup | — | script diverges from its own stated methodology → owner ruling needed |
| `fact_pnm_opprotunity` typo | `core.fact_pnm_opportunity` (correct spelling) exists in eldoria, NI_PNM-owned, semantic model generated | — | verify at execution / see decision §4 |

## 6. What to do next (iteration 3 scope — do NOT start until owner says go)

> **STATUS 2026-07-08:** steps 1-2 DONE (orders source = A, implemented & reconciled — V3). Step 3
> execution round DONE for 2026-05 (exact match vs the validated queries). Remaining: extend to more
> months + optional Notion Demand DB cross-check; then steps 4-6 (build p80/order_edits/ota, final
> readiness ledger, formalize-as-skill verdict). Sections remain PROTOTYPE-ONLY.

1. **Get the owner's orders-source decision (§4).** Everything else depends on it.
2. If **(A)**: re-point leads/orders/derived/tpo to eldoria models, re-map columns + status
   semantics, re-run `run_tests.py`, then the execution round.
3. **Execution round (Path A):** owner runs `python ask.py --metric <id> --month 2026-05 --execute`
   with `SF_*` env vars on their laptop. Validate numbers; run drift/sanity vs any known baseline
   and vs `reference/p80_durations_baseline_*.csv` (for p80).
4. **Build the remaining sections:** `p80_durations` (cleanest — timestamps only; has a baseline
   CSV to validate against), then `order_edits` (pending its source-table ruling), then `ota`
   (still BLOCKED until its data source is defined).
5. **Final readiness ledger across all 6 sections** + recommendation on which bundle(s) are ready
   to open to stakeholders vs which still need work.
6. **Verdict on formalizing as a Claude Code skill** — ready now, or blocked on a data-quality
   flag / missing dbt model / ambiguous definition. Do NOT build the skill; do NOT open access.

## 7. House rules to carry forward

- **Treat the 5 original files as read-only.** They are not in the repo.
- **No production Snowflake / Google Sheet write without showing the exact SQL/write first and
  getting an explicit go-ahead.** Dry-run is the default.
- **Never silently resolve a `⚠ VERIFY` / `# verify` name** — surface it as an open question.
- **Never classify a section READY FOR STAKEHOLDERS** with an open flag, failed drift, or an
  answer you're not confident in — default to PROTOTYPE-ONLY (or BLOCKED).
- **Never average pre-aggregated ratios; never change MTD-vs-locked-month semantics** without
  flagging.
- **Ask before adding any dependency.**
- **When presenting choices, attach a % confidence** (owner's standing rule as of 2026-07-07).
- **"Opening" a bundle to stakeholders and "formalizing the skill" are owner-only** — produce
  the ledger and recommendation, nothing more.
- End each iteration with a one-line status + a specific decision for the owner.

## 8. Fast start for the new terminal

```bash
cd pnm-selfserve/selfserve_nlq
python run_tests.py                 # should print 31 passed, 0 failed
python ask.py --list                # see the menu + readiness
python ask.py --metric tpo_overall --month 2026-05   # dry-run: prints adapted SQL + footer
cat ../HANDOFF.md ../iteration-2-readiness-ledger.md  # full context
```

Connectors available in-session (owner-authenticated): **Data Catalog** (`mcp__Data_Catalog__*`)
and **Metabase** (`mcp__Metabase__*`, database 108 = the PnM Business Health DB). These are how
the flag evidence above was gathered — use them for metadata, not for pulling MBR numbers without
owner sign-off.

**~~First question for the owner in the new terminal~~ — CLOSED 2026-07-08:** Orders source = **Option A**
(re-point to the eldoria dbt models), implemented and reconciled. See `DECISION_LOG.md`. (Historical
prompt was: "Orders source — go with option A, ~85% recommended, or A/B something else?")
