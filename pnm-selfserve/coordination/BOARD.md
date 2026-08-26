# BOARD — current state & handoff
# Mutable, single-writer (orchestrator). Reference decisions by ID (see D-NNN); do not restate them.
# Done-test: a fresh zero-context agent can continue from this file alone.
Updated: 2026-08-27 00:47 IST (orchestrator)

## Workstream
Close gaps in the PnM row-addressed knowledge base at `pnm-selfserve/kb/`, and mine the governed dbt
layer (`porterin/DE-DBT-SNOWFLAKE`) into it. Resumed from a handoff written 2026-08-26.
**Scope is `pnm-selfserve/**` only** — HCV runs as a parallel sibling, see Roster.

The completed 2026-07-29 Gem-KB workstream lives at `./gem-kb-build/` with its own `D-001..D-015`
(see D-001). **Decision ids here are a fresh space.**

## Status
**PnM step 1 SHIPPED. PnM step 2 written but UNCOMMITTED, in blind review. HCV in flight.**

## Mode
**PARALLEL across verticals, SEQUENTIAL within PnM** — see D-003. Workers touch disjoint trees
(`pnm-selfserve/**` vs `hcv-selfserve/**`) so they cannot collide. PnM's own mining is
single-orchestrator because the findings interlock — three OTA definitions had to be compared against
each other before any could be written down.

## Roster
- **orchestrator (me)** — read all sources, authored every KB edit, sole writer of DECISIONS / BOARD
- **blind-checker #1 (done)** — 14 provenance claims on the `PNM-G-002` change → returned 4 defects in
  my draft, all fixed pre-commit; see D-006 and Learnings
- **blind-checker #2 (running)** — ~40 claims on the dbt-mining diff: every cited SHA/path, the three
  OTA definitions, `is_test_user` logic, the trust-score table, and the KB's internal count
  consistency → will gate the step-2 commit
- **hcv-workstream (running)** — audits the never-examined HCV coverage-map artifact
  (`c6f3e837-29fc-4a8a-bdd8-30321ce13dc8`), reconciles HCV's gap counts, premise-checks its
  "untracked" rows, ranks HCV dbt models by trust score, and greps for this session's defect patterns.
  Carries all 7 transferable learnings below. Reports back; commits nothing without saying so.

## Pending / next
1. **Fold blind-checker #2's must-fixes into the uncommitted diff, then commit + push.** Four files
   staged in spirit: `GAPS.md`, `sources.md`, `data-model.md`, `CONTEXT.md`.
2. **Commit `coordination/` itself** — D-002 settles that it is version-controlled; the filing move and
   these two files are not yet committed.
3. Synthesize the HCV worker's report; decide whether HCV needs its own `coordination/` record.
4. **Remaining §3.1 mining — ~15 models unmined** (`PNM-S-053`). Next by evidentiary yield:
   `fact_pnm_opportunity` (97.5 A), `dim_pnm_vendor` (95 A), `pnm_gst_daily` (100 A),
   `cge_pnm_paid_lead_attribution` (100 A). **State which ordering you use** (see D-007).
5. Untouched from the handoff queue: `PNM-G-093` (the `leads_overall` → `leads_overall_intra_city`
   rename — five call sites, a live metric id; treat as its own session with blast-radius analysis).

## Shipped
- **`e7b8f72`** — closed `PNM-G-002`, pushed to `origin/main` (`68d46cb..e7b8f72`). See D-004, D-005,
  D-006.

## Shared context (facts the work depends on)
- **Canonical repo is `~/dev/selfserve` on `main`.** `~/Desktop/AI_V2/...` is DLP-locked: `getcwd()`
  fails so **every `git` command dies** while relative-path `cat`/`ls` still work. A file that "doesn't
  exist" almost always means the wrong clone.
- `PNM-G-002`'s two files were tracked all along — spec at `83011b2` (2026-07-19), coverage map at
  `03f1653` (2026-08-26). The Desktop clone holds an **older** 2026-07-12 draft of the spec. Never copy
  it over the tracked one (D-004).
- **`GAPS.md` now: 63 rows · 3 CLOSED · 8 BLOCKED · 52 OPEN · 60 live.** `CONTEXT.md` restates the live
  figure, so a miscount propagates across files (D-006).
- **Three governed on-time definitions exist, all anchored on shifting-started** (D-008):
  `PNM_EXPERIENCE.OTA_FLAG` (`distance_km < 0.5`), `pnm_ota_capacity` (`ST_DISTANCE(pickup → supervisor
  GPS) <= 500 m`), `pnm_support.on_time_arrival_flag` (**no distance term**). The latter two read the
  same `supervisor_actions` rows with the same `action = 'ShiftingStarted'` filter and the same
  latest-of rank — **not independent corroboration**.
- **The trust-score discovery loop** (`PNM-S-058`): `models/docs/**/*_validation.json` carry
  `trust_score.score`/`.grade`, `summary.ci_gates_passed`, `validated_at`. 40 PnM files → **29 distinct
  models**. Two eras: 2026-04-13/05-04 are C–D with gates **failing**; 2026-07-03 onward are B–A and
  passing.
- Use **`gh`, never the GitHub MCP tools** for `porterin/*` — the MCP authenticates outside the org and
  returns bare 404s. Quote whole URLs; zsh globs on `?`.
- `readiness` and `confidence` are orthogonal and both matter. Nothing is `stakeholder_ready`; **only
  the owner promotes.** Reporting one axis when asked for the other is the defect this KB exists to
  prevent.
- PnM's precedence ladder is its own — the **top two rungs are inverted** vs PTL's (owner ruling above
  SQL), because PnM's load-bearing facts are business-attribution decisions no query can yield. Card
  #30311 is deliberately demoted. Do not import PTL's or HCV's.

## Learnings / caveats
- **Verify a gap row's premise before executing its `next_action`.** `PNM-G-002` was false when
  written and its instruction was destructive (D-004). Check every "untracked"/"missing" claim with
  `git ls-files` and `git log -- <path>` first.
- **Recount; never carry a total forward.** One stale total published four wrong figures across two
  files and survived multiple sessions (D-006).
- **A blind checker earns its cost every time.** Checker #1 found four defects in work I believed
  sound — including a "two days" that was really **38 days**, the load-bearing figure in the very
  argument the row was making. Give it the sources and the bare claims, **never the reasoning**.
- **`§4.1`-style citation caps and `§5`-style evidence caps are independent.** Lifting one does not
  lift the other; a doc pinned at a SHA is still a doc (D-005).
- **High trust and low trust are opposite priorities.** Low = documentation debt; high = evidentiary
  yield, because only a merged *test* clears `verified`. Say which you are using (D-007).
- **Recurring defect patterns in the governed layer**, worth grepping for in any vertical: `ELSE 0` /
  `ELSE 'No'` making missing data read as failure · `exclude_daily` contradicting a docs
  `refresh_frequency: daily` · hardcoded city `CASE` instead of `dim_geo_regions` · `RANK()` where
  `ROW_NUMBER()` was meant · a CTE named for one population that filters to another (an "outstation"
  CTE filtering `shifting_type = 'intra_city'`) · hardcoded constant `VALUES` tables with no owner ·
  two near-identical columns for one concept with nothing saying which is authoritative · **multiple
  governed definitions of one business concept** — when you find two, look for a third.
- **Environment:** `PATH` intermittently drops in compound Bash calls; export
  `PATH=/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin`. zsh does not word-split unquoted variables.
  `export -f` does **not** survive into `bash -c` from zsh — write a real script file.
- **Never edit `coverage-map/` by hand** — it is a projection: fix the KB, then re-derive. This
  workstream verified no re-derive was needed rather than assuming (`metric-coverage.json` carries no
  gap counts, no `local:` refs, no mention of `iteration-3`).
- Seven pre-existing malformed table rows remain in `GAPS.md` groups D and H, deliberately unfixed
  (D-011). Also flagged and unfixed: `business.md:94` cites
  `local:ProdOps/selfserve/project-argus-team-guide.html`, a file sitting **untracked** in the repo
  root — same defect class as `PNM-G-002`, on a file it never named. Needs its own row and an owner
  call on whether that HTML belongs here.
