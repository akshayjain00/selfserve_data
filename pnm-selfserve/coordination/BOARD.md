# BOARD — current state & handoff
# Mutable, single-writer (orchestrator). Reference decisions by ID (see D-NNN); do not restate them.
# Done-test: a fresh zero-context agent can continue from this file alone.
Updated: 2026-08-27 01:20 IST (orchestrator)

## Workstream
Close gaps in the PnM row-addressed knowledge base at `pnm-selfserve/kb/`, and mine the governed dbt
layer (`porterin/DE-DBT-SNOWFLAKE`) into it. Resumed from a handoff written 2026-08-26.
**Scope is `pnm-selfserve/**` only** — HCV runs as a parallel sibling, see Roster.

The completed 2026-07-29 Gem-KB workstream lives at `./gem-kb-build/` with its own `D-001..D-015`
(see D-001). **Decision ids here are a fresh space.**

## Status
**PnM steps 1 and 2 both SHIPPED and pushed. HCV in flight.** Nothing of PnM's is uncommitted.

## Mode
**PARALLEL across verticals, SEQUENTIAL within PnM** — see D-003. Workers touch disjoint trees
(`pnm-selfserve/**` vs `hcv-selfserve/**`) so they cannot collide. PnM's own mining is
single-orchestrator because the findings interlock — three OTA definitions had to be compared against
each other before any could be written down.

## Roster
- **orchestrator (me)** — read all sources, authored every KB edit, sole writer of DECISIONS / BOARD
- **blind-checker #1 (done)** — 14 provenance claims on the `PNM-G-002` change → returned 4 defects in
  my draft, all fixed pre-commit; see D-006 and Learnings
- **blind-checker #2 (done)** — ~40 claims on the dbt-mining diff. Confirmed the trust-score table
  exactly (11/11 scores), `is_test_user` logic, all 13 citations, and the gap arithmetic. **Returned 6
  defects, all accepted and fixed pre-commit** — one of them inverted a claim I had graded `verified`.
  See D-012…D-018.
- **hcv-workstream (running)** — audits the never-examined HCV coverage-map artifact
  (`c6f3e837-29fc-4a8a-bdd8-30321ce13dc8`), reconciles HCV's gap counts, premise-checks its
  "untracked" rows, ranks HCV dbt models by trust score, and greps for this session's defect patterns.
  Carries all 7 transferable learnings below. Reports back; commits nothing without saying so.

## Pending / next
1. **Synthesize the HCV worker's report** when it returns; decide whether HCV needs its own
   `coordination/` record.
2. **`PNM-G-098` is the cheapest open lead** — read `PNM_EXPERIENCE`'s `distance_km` derivation in the
   mart SQL. If it is not a pickup-proximity measure, then only **one** of the three governed OTA
   definitions tests proximity at all, and `PNM-G-024`'s framing changes again. Evidence already
   points that way (D-015).
3. **Remaining §3.1 mining — ~15 models unmined** (`PNM-S-053`). Next by evidentiary yield:
   `fact_pnm_opportunity` (97.5 A), `dim_pnm_vendor` (95 A), `pnm_gst_daily` (100 A),
   `cge_pnm_paid_lead_attribution` (100 A). **State which ordering you use** (see D-007).
4. Untouched from the handoff queue: `PNM-G-093` (the `leads_overall` → `leads_overall_intra_city`
   rename — five call sites, a live metric id; treat as its own session with blast-radius analysis).
5. Owner-facing, none blocking: `PNM-G-024` needs a ruling on **whether OTA requires GPS proximity**
   (narrower than the "which event" question it replaced); `PNM-G-094` and `PNM-G-095` are defects to
   route to `NI_PNM`; `PNM-G-097`'s duplicate validation files belong to the dbt repo's owners.

## Shipped
- **`e7b8f72`** — closed `PNM-G-002`, pushed (`68d46cb..e7b8f72`). See D-004, D-005, D-006.
- **`951057b`** — put `coordination/` under version control, filed the 2026-07-29 workstream to
  `gem-kb-build/`. See D-001, D-002.
- **`bdfbe2c`** — the five-model dbt mining, post-blind-check. See D-007…D-018.

## Shared context (facts the work depends on)
- **Canonical repo is `~/dev/selfserve` on `main`.** `~/Desktop/AI_V2/...` is DLP-locked: `getcwd()`
  fails so **every `git` command dies** while relative-path `cat`/`ls` still work. A file that "doesn't
  exist" almost always means the wrong clone.
- `PNM-G-002`'s two files were tracked all along — spec at `83011b2` (2026-07-19), coverage map at
  `03f1653` (2026-08-26). The Desktop clone holds an **older** 2026-07-12 draft of the spec. Never copy
  it over the tracked one (D-004).
- **`GAPS.md` now: 63 rows · 3 CLOSED · 8 BLOCKED · 52 OPEN · 60 live.** `CONTEXT.md` restates the live
  figure, so a miscount propagates across files (D-006).
- ⚠ **"Slot" is not one concept** (`PNM-T-114`, D-017): `pnm_ota_capacity` buckets hours 4-10/11-15/ELSE;
  `pnm_support` buckets 6-11/12-16/17-21 and leaves 22:00-05:59 in no bucket. Name the model.
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
  ⚠ **This bit a verifier, not just the work** (D-018): a citation-resolution loop lost `PATH`, `gh` was
  not found, and all 13 citations reported FAIL. A check that fails open reads as "everything is
  broken". Put the `export` *inside* the script, and re-run a check before believing a total failure.
- **Never edit `coverage-map/` by hand** — it is a projection: fix the KB, then re-derive. This
  workstream verified no re-derive was needed rather than assuming (`metric-coverage.json` carries no
  gap counts, no `local:` refs, no mention of `iteration-3`).
- Seven pre-existing malformed table rows remain in `GAPS.md` groups D and H, deliberately unfixed
  (D-011). Also flagged and unfixed: `business.md:94` cites
  `local:ProdOps/selfserve/project-argus-team-guide.html`, a file sitting **untracked** in the repo
  root — same defect class as `PNM-G-002`, on a file it never named. Needs its own row and an owner
  call on whether that HTML belongs here.
