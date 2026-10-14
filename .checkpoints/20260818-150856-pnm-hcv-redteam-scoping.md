---
status: in-progress
context: chore/prodops-file-control-migration
timestamp: 2026-08-18T15:08:56+05:30
session_id: de1ee0a9-5e95-443d-a3e6-ccfa86d52d94
cwd: /Users/akshay.jain/Desktop/AI_V2/ProdOps/selfserve/pnm/selfserve_data
---

## Strategic Goal: Decide what it takes to extend the PTL trust guarantee to PnM and HCV

The three coverage maps are only worth circulating if their statuses survive an adversarial
read. PTL has been blind red-teamed; PnM and HCV have not. This session scoped that gap and
found the two verticals need **opposite** treatment — one is nearly ready, the other cannot be
gated at all yet.

### Resume This Session
```bash
cd /Users/akshay.jain/Desktop/AI_V2/ProdOps/selfserve/pnm/selfserve_data && claude --resume de1ee0a9-5e95-443d-a3e6-ccfa86d52d94
```
> If the picker shows nothing, you're in the wrong folder — the `cd` above fixes that.

### Decisions, Findings & Tradeoffs

- **No artifact update was needed.** All three published artifacts already match local state.
  Verified three ways: status counts are identical in `metric-coverage.json`, in the data
  embedded in `coverage-map.html`, and in the 2026-08-14 checkpoint's Shipped table
  (PTL 116 = 14/30/36/22/14; PnM 167 = 0/25/2/140/0; HCV 118 = 0/0/0/118/0).

- **HCV's citation layer is structurally broken — a gate would return one finding 118 times.**
  All 118 citations point at a single line: `02_specs_plans_logs/specs/2026-08-07-hcv-metric-mapping-design.md:17`.
  Three compounding problems:
  1. Fails PTL's own post-gate standard ("a citation must land on its own metric's row") on 118/118.
  2. Line 17 says `Status` is Pending on **"much of it"**; the map renders `pending` for **all** 118 — an overclaim.
  3. The cited line does not contain the per-row values the map asserts. `argus_phase`
     (P1=59, P2=44, P3=9, NA=6), `level`, `type`, `classification` came from
     `01_reference_readonly/migrated_context/HCV_Metrics_DD.csv` — which **exists** (119 lines
     = 118 metrics + header). The map cites a doc *describing* the source instead of the source.

- **PnM's mechanical citation layer is clean — verified this session, not assumed.**
  Ran the landing check directly: **all 140 `PnM_Metrics_DD.csv` citations land on a row whose
  Metric Name matches the map's name exactly. 0 mismatches, 0 unparsed.** The remaining 27
  many-to-one citations were spot-checked and are defensible, not lazy:
  `iteration-2-readiness-ledger.md:132` is the `tpo` row cited by exactly the 10 TPO sub-metrics
  it governs (PNM-154…PNM-163); `DECISION_LOG.md:69-75` is the 2026-05 reconciliation table,
  with the 4 metrics on line 73 being that line's four channel splits.

- **The PTL red-team method is NOT replayable — this is the real cost, not the checking.**
  Its validator (`validate.js`) lived in the session scratchpad and is **gone**; no coverage-map
  validator exists anywhere in the repo. It would not have transferred regardless: its exhaustive
  check parsed markdown catalogue rows (`| 53 |`) against the record's own `PTL-C53` number.
  PnM's source is a CSV; HCV's is prose. **Must be rewritten per vertical.**
  The prompt survives only in `~/.claude/projects/…/cf6a0dd9-fd42-448e-9e38-e9be7fab3a60.jsonl:288`,
  and it **mandated sampling** ("at least 20 records") — PTL only got exhaustive coverage because
  the checker exceeded its brief. Replayed verbatim on PnM it would check 20 of 167.

- **Correction to the prior checkpoint's verification note.** PTL's gate returned **22 numbered
  defects (6 HIGH / 12 MEDIUM / 4 LOW)**, not three. "One wrong citation, two missed evidence
  sources, one off-by-one" was the compressed *accepted* count. Budget triage for ~20 raw
  findings per vertical. Two PTL findings were deliberately **left open for the owner** and remain
  unresolved: `unknown` rows carrying `blocker: "not-started"`, and `not-started` vs
  `source-unavailable` across the G-150/G-151 sets.

- **Sequencing ruling implied by the above:** PnM's gate should target only the *judgment*
  surface (27 many-to-one citations, the 25 `partial` promotion-gate rows, the 3 column-shifted
  DD rows at `PnM_Metrics_DD.csv:23,79,122`). The mechanical class is already proven and should be
  frozen by a committed validator rather than re-checked by an agent.

### Remaining Execution

1. **Commit the coverage-map work.** Recommended and *not yet authorised*. A gate that finds
   defects is worth little without a baseline to diff remediation against.
2. **Rebuild HCV's citations per-row against `HCV_Metrics_DD.csv`.** Prerequisite to any HCV gate.
   Also resolve the "much" vs "all" overclaim on the 118 `pending` statuses.
3. **Write a portable citation validator and persist it in-repo** (one per source shape:
   markdown table, CSV row, prose). PTL's equivalent was ephemeral and is unrecoverable.
4. **Amend the red-team prompt from sampling to exhaustive**, then run the blind gate on PnM's
   judgment surface only.
5. Carry-over from 2026-08-14, unchanged: convert 387 `file:LINE` citations to stable IDs;
   draft the PnM promotion ruling as a `D-###` for the 25 reconciled metrics; owner rulings in
   blast-radius order (`G-005`/`G-012`/`G-163`, then `G-161`); assign per-metric owners (`G-133`).

### Blockers / Open Questions

- **Nothing is committed.** Verified earlier this session: branch is
  `chore/prodops-file-control-migration` (**not** `claude/ptl-metric-catalog-map` — this session's
  startup header was stale), 4 commits total, and `git ls-files selfserve` returns **0**. The
  entire `selfserve/` tree is untracked. **The published artifacts are currently the most durable
  copy of this work.**
- **The red-team method is recoverable only from a 2.7 MB session transcript.** If it is pruned,
  the repo retains a three-line assertion that a gate happened, with no prompt, no defect list,
  and no runnable check.
- **Environment: the shell sandbox tightened again mid-session** — `git` and `ls` fail with
  "Operation not permitted" from both the working directory and the repo root. File tools still
  work. Same failure recorded on 2026-08-14; a fresh terminal cleared it last time.
- No north star recorded for PnM or HCV; both still render "—".
- Citation drift remains the top maintenance risk — all 387 citations are line-based, and the
  anchoring check cannot catch a row inserted above a cited line.
