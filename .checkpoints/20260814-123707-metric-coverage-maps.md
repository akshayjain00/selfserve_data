---
status: in-progress
context: claude/ptl-metric-catalog-map
timestamp: 2026-08-14T12:37:07+05:30
session_id: cf6a0dd9-fd42-448e-9e38-e9be7fab3a60
cwd: /Users/akshay.jain/Desktop/AI_V2/ProdOps/selfserve/pnm/selfserve_data
---

## Strategic Goal: Make metric coverage legible across all three verticals

Ship an interactive coverage map per vertical (PTL, PnM, HCV) that answers one question with
receipts: **which metrics are actually delivered, and what is blocking the rest?** Every status
carries a `file:line` citation back to the document that asserts it, so the map can be trusted
in a leadership conversation and can be argued with rather than believed.

### Resume This Session
```bash
cd /Users/akshay.jain/Desktop/AI_V2/ProdOps/selfserve/pnm/selfserve_data && claude --resume cf6a0dd9-fd42-448e-9e38-e9be7fab3a60
```
> If the picker shows nothing, you're in the wrong folder — the `cd` above fixes that.

### Shipped

| Vertical | Metrics | shipped | partial | blocked | pending | unknown | Artifact |
|---|---:|---:|---:|---:|---:|---:|---|
| PTL | 116 | 14 | 30 | 36 | 22 | 14 | `claude.ai/code/artifact/510a8015-09d8-4759-ab4a-150d75d0e085` |
| PnM | 167 | 0 | 25 | 2 | 140 | 0 | `claude.ai/code/artifact/ebc29081-f66c-4080-a21c-3f26eca69f7b` |
| HCV | 118 | 0 | 0 | 0 | 118 | 0 | `claude.ai/code/artifact/c6f3e837-29fc-4a8a-bdd8-30321ce13dc8` |

Files (one JSON + one HTML per vertical, nothing committed):
`{ptl-selfserve,pnm-selfserve,hcv_selfserve}/coverage-map/`

### Decisions, Findings & Tradeoffs

- **The map is a projection, not a source.** Status mirrors what the source documents assert;
  it is never a re-adjudication of their evidence. Consequence: updates start by changing the
  KB / ledger / DD, then re-deriving — editing the JSON directly makes its own citation a lie.
- **The Argus DD CSVs are the metric universe for PnM (167) and HCV (118)** — the direct
  analogue of PTL's 85-row catalogue sheet, and they populate `type` / `domain` / `level` /
  `system` directly.
- **Owner rulings taken this session:** three separate artifacts rather than one combined;
  PnM universe = DD catalogue with the pipeline supplying status; `blocker: null` permitted
  for `unknown` (asserting "not started" about a metric with no evidence was an overclaim).
- **PnM's real finding: 25 metrics reconcile EXACTLY against live 2026-05 data** (leads,
  orders, conversion, channel mix, TPO) **yet all sit at PROTOTYPE-ONLY.** That is a promotion
  gate on finished work, not a technical gap.
- **HCV has nothing built** — its mapping spec is "Approved for planning" and states the
  catalogue holds definitions and no computations. Its useful axis is Argus phase: 59 at P1,
  33 of those at L0. That is a build queue, not a coverage map.
- **Zero unknowns in PnM and HCV** because the DD and spec assert something citable about
  every row; "catalogued but not delivered" is honest `pending` with a source.
- **Conflicts split into two kinds needing opposite treatment:** definitional forks (`G-161`,
  `G-002`, `G-154`, `G-004`) need an owner ruling and cannot be closed by analysis; factual
  disputes (`G-159`, `G-167`, `G-156`) need a cheap check and would be corrupted by a ruling.
  **Rule the definition, never the number** — a declared number is an output that the next
  person recomputes differently.
- **Engineering:** one renderer serves all three, with filter dimensions derived from the data
  (a chip group appears only where the data varies). Output is pure ASCII — the page carries no
  guaranteed charset, and raw UTF-8 glyphs were rendering as windows-1252 mojibake.
- **Verification:** a blind red-team on PTL found a wrong citation plus two missed evidence
  sources; chasing it exposed an off-by-one line reference. Sampled citation checking was
  replaced with exhaustive checking (a citation must land on its own metric's row).

### Remaining Execution

1. **Convert all 387 citations from `file:LINE` to stable IDs** (`kb/GAPS.md#G-141`), resolving
   the line at build time. Offered, not started. Highest-value hardening — see Blockers.
2. **Draft the PnM promotion ruling as a `D-###`** for the 25 reconciled metrics. Offered, not
   started. Cheapest coverage win available: one drift-check plus one ruling turns 25 rows green.
3. **Blind red-team the PnM and HCV maps** — not yet run. PTL's equivalent found real defects.
4. **Owner rulings, in blast-radius order:** `G-005`/`G-012`/`G-163` (one question asked three
   times — the business-customer definition), then `G-161` (terminal vs demand denominator,
   which touches fulfilment and both cancellation metrics).
5. **Assign per-metric owners (`G-133`)** — the structural unblock for most of the BLOCKED list.

### Blockers / Open Questions

- **Citation drift is the top maintenance risk.** All 387 citations are line-based. A row
  inserted near the top of `GAPS.md` shifts everything below it, and the current anchoring check
  will NOT catch it — a shifted citation still lands on *a* `G-###` row, just the wrong one.
- **No north star is recorded for PnM or HCV.** Both render "—" rather than an invented one.
- **Three PnM DD rows are column-shifted** in the source sheet (`Overall Add-on Adoption %`,
  `% of orders where fare decreased`, `Interactions per vendor on notifications tab`) — their
  sign-off cells hold prose, so status cannot be read. Same defect class as PTL's F18.
- **Cross-vertical name collisions (`G-039`)** are now visible: `allocation %`, `CBDF`, `CAC`
  mean different things per vertical. Every ruling must state whether it is vertical-scoped.
- **Nothing is committed.** Branch `claude/ptl-metric-catalog-map`; three untracked
  `coverage-map/` directories. No commit, branch or push was authorised.
- **Environment note:** the shell sandbox tightened mid-session and can no longer read the
  working directory (`git`, `ls` fail with "Operation not permitted"). File tools still work.
  A fresh terminal will likely clear it.
