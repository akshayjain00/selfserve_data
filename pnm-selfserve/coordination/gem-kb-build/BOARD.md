# BOARD — current state & handoff
# Mutable, single-writer (orchestrator). Reference decisions by ID (see D-NNN); do not restate them.
# Done-test: a fresh zero-context agent can continue from this file alone.
Updated: 2026-07-29 18:05 IST (orchestrator)

## Status: COMPLETE — both deliverables written, reviewed, and fixed. Nothing in flight.

## Mode
**SEQUENTIAL** — see D-001. FILE 2 depends on FILE 1's section names; the work is depth not breadth;
all source context was already loaded in the orchestrator, so parallel authoring would have *lowered*
fidelity on the one thing the brief forbids absolutely (inventing tables/columns/metrics/links). One
worker was spawned, for the review gate only.

## Roster
- orchestrator (me) — read all sources, authored both files, applied the checker's fixes, sole writer
  of DECISIONS / BOARD
- blind-checker (**done**, Sonnet) — spec-conformance attack on both files; returned 7 findings, all
  accepted and fixed → see D-012

## Deliverables (both new; no existing file modified)
- `pnm-selfserve/pnm-gem-knowledge.md` — FILE 1, the Gem knowledge base. 8 sections (§0 provenance +
  deviations, §1 primer, §2 metric dictionary, §3 live-schema mapping, §4 dashboard registry, §5 SQL
  templates, §6 gotchas/FAQ, §7 open questions, §8 source inventory).
- `pnm-selfserve/pnm-gem-instructions.md` — FILE 2, paste-ready Gem instructions. **1,454 words**
  (cap 1,500). Cites all seven FILE 1 section names verbatim.
- Location rationale: D-002.

## Verified before sign-off
- FILE 2 word count 1,454 < 1,500 · refusal sentence exact · all four routing steps in priority order
- 47 metrics, per-section counts match `metrics_registry.py` exactly (5/5/7/13/7/10); checker
  independently confirmed no invented, missing or misnamed metric across its own spot-checks
- All 6 templates are fenced SQL with an edit banner; zero `{{end_date}}` inside any SQL block
- `git status` shows only untracked new files — nothing existing touched

## Open for the owner (none blocks delivery; all three are in FILE 1 §7)
1. **§7-Q1 — no city or weekly cut exists for the catalog** (D-010). The largest gap between the
   knowledge base and its audience: city ops will ask city-and-week questions constantly, and only
   the dashboards can serve them. Decide whether analytics validates a city/weekly variant or city
   ops is routed to dashboards permanently.
2. **§7-Q2 — Notion schema guide is stale in five places** (D-009). Recommend regenerating it from
   `INFORMATION_SCHEMA` and adding the two marts from §3.4.
3. **§7-Q3/Q4 — OTA definition disputed and unowned; `p80_vendor_accepted_to_sup_assigned` exposure
   undecided** (owner leaning ~55% keep hidden).

## Shared context (facts the work depends on)
- 47 metrics across 6 BUILT sections, all `readiness: prototype_only`; `ota` is `blocked` (0
  queryable metrics). Nothing is stakeholder-ready — promotion is owner-only. `[metrics_registry.py,
  DECISION_LOG V4, iteration-2-readiness-ledger]`
- Metabase base URL `https://metabase.prod-internal.porter.in` (connector-resolved, D-006).
- Card **#30311** `[DBT] Conversion %` → db **108**, collection 5001, 9 filters incl. a 14-value City
  Name list. Card **#47576** `TPO Trend` → db **97**, collection 5523, 10 filters incl. Geo Region +
  Granularity. The two named cards sit in *different* databases and dashboards.
- Canonical dashboards: **4076** Business Health (125 cards) · **4454** Operation (82 cards, 18
  filters, tabbed) · **6060** TPO Trend · **6218** Demand · **6104** AOP vs Actuals.
- Live schema (2026-07-29, D-008): `PNM_EXPERIENCE` = **71 cols**, all 20 the catalog needs present;
  `IS_MODIFICATION_DONE` and `OTA_FLAG` are **TEXT**; `PNM_APPLICATION.ORDERS` = **17 cols** with no
  `ORDER_ID` and no lifecycle timestamps; `HS_TICKETS` has **no `ORDER_ID`** (joins on `CRN`).

## Learnings / caveats for anyone resuming
- **The brief's own file pointers are partly stale.** `queries.py` = the MBR automation at
  `~/Desktop/AI_V2/ProdOps/pnm/pnm_mbr_monthly_metrics/` (1,343 lines, 14 sections), not a prototype
  file. `rendered_tpo_202605.sql` is a stale pre-Option-A artifact — **excluded** (D-004). Re-derive
  from `metrics_registry.py` + `tests_output/`, never from the flattened copies.
- **iteration-1's metric catalog is superseded and must not be quoted** (D-003) — its 49 columns,
  `_mins` names and `status=2/!=4` semantics exist nowhere now.
- **`docs/overview.html` is pre-iteration-3** — still says p80/order_edits "not built" and "31/31
  tests". Both wrong now (54/54, both built). Flagged in FILE 1 §8, not edited (read-only source).
- Many Business-Health cards have a **"- including nano" twin** (created 2026-03-30/31). Default cards
  EXCLUDE nano. Quoting the wrong twin silently changes the population.
- Dashboard **6337** is `PNM - Operation Dashboard - Duplicate` (57 of 82 cards). Never cite it.
- `p80_durations` / `order_edits` apply **no** user or test filter (`PNM_EXPERIENCE` carries neither
  `USER_FLAG` nor `IS_TEST_USER`; those live only on `PNM_ALLOCATION` / `PNM_FARE_MOVEMENT`). Do not
  describe the catalog as excluding test orders.
- **A blind checker earns its cost here.** It caught a section shipping prose where a query belonged —
  invisible to me because I knew what the prose *meant*. Keep the gate blind if these files are revised.
