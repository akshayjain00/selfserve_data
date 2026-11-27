# BOARD — HCV intracity ops report: current state & handoff
# Mutable, single-writer (orchestrator). Decisions are referenced by ID; see DECISIONS.md.
Updated: 2026-11-27 21:05 IST (orchestrator)

**Goal:** a daily, self-contained HTML ops report for Porter HCV intracity (Tier 1, 9ft and
above): yesterday, week to date, month to date. Re-run instructions: [../SKILL.md](../SKILL.md).

## Mode
SEQUENTIAL — one deep build whose steps need each other's live output (D-001).

## Roster
- orchestrator (me) — build, synthesis, sole writer of DECISIONS / BOARD
- blind-checker (done) — review of the built HTML against the hcv-data definitions, given only
  the spec, the SQL and the raw exports → no HIGH; findings and dispositions in D-013 to D-018

## Done-when status
1. Pipeline produces `docs/YYYY-MM-DD-hcv-intracity-ops-report.html` — **DELIVERED**
   (`docs/2026-11-27-hcv-intracity-ops-report.html`, data to 2026-11-26; 5 queries, all exports
   validated; 21 tests pass; status `reviewed`).
2. One-week reconciliation vs dashboard 6406 card SQL — **DELIVERED**
   (`docs/2026-11-27-reconciliation-dashboard-6406.md`, week 2026-11-16 to 2026-11-22).
3. Blind checker review — **DELIVERED** (D-013): no HIGH, 1,461 of 1,461 cells reproduced.
4. `SKILL.md` — **DELIVERED**.

## Pending / next
1. All four done-when items are delivered. Only owner decisions remain: see "Open for the owner".

## Shared context (facts the work depends on)
- Branch `hcv-ops-report` of `~/dev/selfserve` (remote `akshayjain00/selfserve_data`), cut from
  `origin/main` at fa39797. Not merged, no PR (owner approval needed for either).
- Scope and definitions: D-002 … D-008. Export grain: D-009.
- Snowflake MCP truncates results at ~468 KB; order facts are chunked by 20 days (SKILL.md).
- Results reach disk via `capture_exports.py` (D-012).
- Dashboard 6406 card SQL is readable from `PROD_ELDORIA.CORE.FACT_MB_CARDS.dataset_query`
  (`stages[0].native`); no Metabase connector is needed.

## Learnings / caveats
- Revenue is 0.68% below card 55587 for the reconciled week (report ₹17.86 Cr vs card ₹17.99 Cr).
  hcv-data states the two revenue calculations agree within ~0.3%; this week's gap is wider than
  that. Definition kept as hcv-data's (D-006); the gap is reported, not explained.
- In Tier 1 intracity data, month to date 2026-11-01..26, 98% of demand classifies as
  "SPOT on Tray" and no order classifies as "Express". The classification is hcv-data's CASE,
  unchanged; the cut is therefore dominated by one member.
- Schedule orders show a Stockout share near half of their demand, because schedule-only rows
  have no matchmaking batch. This follows from the definitions as given; not adjusted.

## Defaulted decisions (made without asking; how to undo)
- Stdlib only, no pandas (D-010) — undo: none needed; add pandas later if wanted.
- Report committed to the repo under `docs/`; `sql/`, `inbox/`, `data/` git-ignored — undo: edit
  `.gitignore`.
- Cut tables open on "Week to date" — undo: change `chk` in `build_report.cut_section`.
- Percentile sample floor of 30 accepted orders (D-008) — undo: `P_MIN_N` in `metrics.py`.
- DAP carries the intracity vehicle filter (D-007) — undo: drop `INTRACITY_SQL` from `sql_daily_dap`.

## Open for the owner
- An ex-dip month comparison (checker M1) would be a new window; not built without approval.
- Revenue gap vs card 55587 (0.68%): accept as-is, or investigate the two fare sources?
- Whether to merge the branch / open a PR, and whether and with whom to share the report.
