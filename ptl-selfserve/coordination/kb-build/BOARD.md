# BOARD — PTL self-serve: build `kb/` base-context knowledge base

*Living current-state + handoff. Orchestrator is the only writer. A fresh agent should be able to
continue from this file alone. Decisions by ID live in `./DECISIONS.md` (this workstream).
Domain rulings live in the repo `ptl-selfserve/DECISION_LOG.md` (D1–D7). The sibling
`../BOARD.md` is a DIFFERENT, COMPLETE workstream — do not edit it.*

## Goal
Create `ptl-selfserve/kb/` — a base-context KB any future Claude Code session can load to work on
PTL self-serve analytics without re-learning the business. Must be incrementally enhanceable in
both accuracy and coverage. **Done-when:** a fresh session pointed only at `kb/CONTEXT.md` can
correctly answer "what does PTL self-serve cover, and how is [any core metric] defined."

## Mode
**HYBRID** — PARALLEL for Phases 1–3, SEQUENTIAL for Phase 4. see D-001

## Roster
- Orchestrator: main session (Opus). Sole writer of BOARD + DECISIONS + all `kb/` files.
- Phase 1: 3 research workers (Sonnet 5) — agent-context patterns / llms.txt+docs-for-AI / semantic-layer metric docs.
- Phase 2: source-inventory workers (Sonnet 5) — read local sources across BOTH clones, return structured summaries.
- Phase 3: dashboard-SQL workers (Sonnet 5) — extract metric SQL from 3 Metabase surfaces.
- Phase 4: orchestrator only. Review gate: BLIND checker before finalizing (KB is spec-validated against DECISION_LOG + card SQL).

## Environment reality (carry forward)
- **TWO clones, diverged branches** (see D-005) — neither has both verticals' latest:
  - `~/dev/selfserve` @ `claude/pnm-p80-orderedits` — full PnM (eldoria re-point, p80/order_edits, gem-knowledge, gem-instructions, reference/, reconciliation). `ptl-selfserve/` here holds ONLY `kickoff-prompt.md`.
  - `~/Desktop/AI_V2/ProdOps/selfserve/pnm/selfserve_data` @ `claude/ptl-metric-catalog-map` — full PTL (`iteration-1-ptl-metric-catalog.md` 396L, `DECISION_LOG.md` 95L D1–D7, `iteration-1-ptl-journey-proposal.md` 254L, `selfserve_nlq/` 615L, 4 rendered SQL). ← **KB target**
  - Both are `origin https://github.com/akshayjain00/selfserve_data.git`.
- macOS may transiently EPERM-lock git clones under `~/Desktop/AI_V2`. Workaround: run git as `cd /private/tmp && git -C <repo> …`. Retry absolute-path Write on EPERM.
- Metabase connector: needs re-auth before Phase 3 (prior BOARD recorded it dropped). Data Catalog likewise.
- Untracked non-ours files in the Desktop clone — do NOT stage: `.DS_Store`, `pnm-selfserve/.DS_Store`, `pnm-selfserve/iteration-3-p80-orderedits-spec.md`, `ptl-selfserve/kickoff-prompt 2.md`.

## Hard constraints (from the task brief)
- MUST NOT modify any existing file. Only NEW files, inside `ptl-selfserve/kb/` (+ this `coordination/kb-build/`).
- MUST NOT include credentials, tokens, or personal data in KB files.
- Only PTL self-serve scope. No extra dashboards or features.
- Where sources conflict: DECISION_LOG D1–D7 wins (see D-004); flag the rest `[unverified]` — never silently pick.
- Every KB fact carries provenance (clone+branch+path), last-verified date, and confidence (verified / unverified / assumption).

## Pending / Next
1. [DONE] Phase 1 — 2 Sonnet workers (trimmed 3→2, see D-013). Recommended structure = progressive disclosure + addressable fact rows. Research saved to `research-2026-07-29-ai-consumable-kb-patterns.md`. Ratified at CP1, see D-015.
2. [DONE] Phase 2 — 4 workers. Extracts: `extracts/p2a-ptl-core.md`, `p2b-ptl-code.md`, `p2c-reference.md`, `p2d-notion-review.md`. **`secondBrain` NOT FOUND** (one search, zero results; worker correctly refused to substitute) → GAPS row.
3. [DONE] Phase 3 — orchestrator did card 33519 itself (auth probe, D-012a) → `extracts/p3-card-33519.md`; 2 workers did the dashboards → `extracts/p3a-dashboard-4198.md`, `p3b-dashboard-4569.md`. Metabase auth GREEN this session.
3b. [DONE] Phase 3 extension — dashboard 4793 read on owner instruction at CP2 (scope widened deliberately). CBDF/CADF mechanic now `verified`; three residuals remain. `extracts/p3c-dashboard-4793-cbdf-cadf.md`. see D-018 (superseded in part)
4. [DONE] Phase 4 — `kb/` written: `CONTEXT.md` (149L, under the 150 cap), `business.md`, `metrics.md`, `data-model.md`, `dashboards.md`, `GAPS.md`, `CONTRIBUTING.md`, plus `KB-POINTER.md` in the session folder. 1,085 lines total.
5. [DONE] Both review gates run. BLIND checker → SHIP WITH FIXES; **4 false claims + ~31 provenance violations + 2 arithmetic errors found and all folded in** (see D-021). Zero-context acceptance test → **PASS, 5/5**, including the deliberate NSM trap (see D-022).
6. [DONE] Post-fix verification: CONTEXT.md 149/150 ✅ · all cross-references resolve (220 defined, 222 cited — the 2 unresolved are documented ID retirements) · zero stale claims · PII/secret scan clean · 11 full M-rows + 74 index rows + 92 G-rows.
7. [OPEN — owner] Commit intent. `kb/` is **UNCOMMITTED** on branch `claude/ptl-metric-catalog-map`, showing as `?? ptl-selfserve/kb/`. Nothing staged, nothing pushed. Committing is the owner's call (checker LF-5). Do NOT stage the pre-existing untracked files listed under Environment reality.

## Workstream status: COMPLETE (pending owner decision on commit)

## Checkpoints (owner-gated, from the brief)
- **CP1** after Phase 1 — confirm recommended structure before proceeding. ← next stop
- **CP2** after Phase 3 — show proposed file list w/ one-line scope each before writing any KB file.

## Shared context
- Prior PTL state: v1 = 11 Snowflake metrics (D6). Source path = raw `partload_application` (D2). Offline base = show BOTH (D3). Cancellation = 4793 logic (D5). NSM authored, has NO backing card.
- **CORRECTED tally** — the catalog is **85 rows (#2–#86)**: 15 confirmed-via-metadata + 6 unverified + **64 never-opened** = 85. An earlier line in this BOARD read "64 total"; 64 was the never-opened count. Fixed 2026-07-29 from `extracts/p2a-ptl-core.md`.
- **RESOLVED this workstream** (see D-017): `orders.state` enum = 0 Open / 1 Assigned / 2 Picked_up / 3 Completed / 4 Cancelled, from card 33519 SQL. Business customer = `c.frequency IN (1,2,3,4)` on `oms_public.customers`. Both were blocking flags.
- **STILL UNVERIFIED after grounding** (D-018, D-019): CBDF, CADF (absent from dashboard 4198 entirely; canonical source D5 names dashboard 4793, out of scope), and NSM (defined by D4, reported in the review, implemented nowhere).
- Prior work is PROTOTYPE-ONLY: numbers unvalidated, `--execute` gated. The KB documents definitions and must not imply the numbers are stakeholder-ready.
- Notion review: titled "May '26" but its latest complete data column is **Apr-26**. Snapshot values are labelled by DATA period, never by review name (D-014).
- Dashboard scale: 4198 ≈ 82 unique cards / 11 tabs; 4569 = 50 cards / 7 tabs. 83 cards not opened, all listed with reasons (D-020).

## Learnings
- **Every source was confident, and the confident sources disagreed.** Grounding in SQL did not merely verify definitions — it showed three headline metrics (NSM, CBDF, CADF) are reported to leadership but computed nowhere in the scoped surfaces. Treat "a number exists in a review" as evidence a metric is *wanted*, never that it is *implemented*.
- **Cross-worker triangulation pays.** P2c reported no corroboration for the UTC+330 IST convention; P2b independently found `DATEADD('minute',-330,…)` in the SQL generator, and card 33519 carries it with the comment `-- KEY FIX: UTC range enables micro-partition pruning`. One worker's gap was another's primary evidence — only the central node holding both could see it.
- **The maker-checker gate on the PLAN (not the artifact) caught a self-defeating design.** Provenance was originally specified as clone+branch+path+line — coordinates destroyed by the very branch/clone churn they were meant to survive. Gate plans before executing them, not just outputs before shipping them.
- Workers reliably follow "list what you did NOT do, with reasons" when told a silent cap is a defect. Both P3 workers volunteered complete not-opened inventories (55 and 28).

## Done-test / handoff
A fresh agent can: read `./DECISIONS.md` D-001…D-023 for every ruling and its reasoning; open
`selfserve_data/ptl-selfserve/kb/CONTEXT.md` (proven loadable — a zero-context agent scored it 5/5);
find all seven raw extracts in `./extracts/`; and resume at item 7 (commit decision) or at any
`G-###` row in `kb/GAPS.md`.

**CLOSED since first completion:** `G-003` (NSM reconciled exactly — 1879/2247, see D-027) ·
`G-007` (AOV date basis = `updated_at`) · `G-116` (all 29 fingerprints recorded) · `G-118`
(33483 has no state predicate; 33462 canonical) · `G-136` downgraded high→low after re-verifying
`T-001`/`T-010`/`T-011` on db73 (see D-030).

**Highest-value next actions, in order:**
1. `G-141` — add the internal-user exclusion to card 39117's **offline** CTE, then re-run Mar/Apr-26 to size the correction. The NSM reported to leadership is currently inflated by internal offline orders.
2. `G-137` + `G-018` — **ESCALATED to card owners 2026-07-30**; message drafted at `owner-message-2026-07-30-card-defects.md` with a follow-up tracking table. KB warnings stand until fixes land (D-031).
3. `G-142` — decide whether NSM stays offline-inclusive only, or fork 39117 to expose a base toggle. Ruling D3 cannot be met from the card as written.
4. `G-132` — roadmap call: does PTL self-serve target Argus eligibility? If yes, D2's "governed layer later" needs a date.
5. Owner-blocked batch — `G-001`, `G-002`, `G-004`, `G-009`, `G-016`, `G-017`, `G-037`, `G-133`, `G-135`. All need a decision, not more analysis. One conversation.
6. `G-012` — `T-012` (grams→kg) and `T-001a` (state labels 0/1/2) are still db83-only; confirm on db73 before quoting a weight from a db73 metric.
7. `G-117` — re-read the review's CADF row; its stated "+1.2pp" contradicts its own 13.81/12.99 figures.

**Do not repeat:** the three dashboards + 4793 have been ground-truthed; the 85-row catalog is fully
enumerated; the PnM/Argus reference material is inventoried. Re-reading them adds nothing.
