---
status: in-progress
context: claude/ptl-metric-catalog-map
timestamp: 2026-08-11T12:19:49Z
session_id: e39437e0-94ed-40d1-81f4-507e959c33ff
cwd: /Users/akshay.jain/Desktop/AI_V2/ProdOps/selfserve/pnm/selfserve_data
---

## Strategic Goal: Make the PTL self-serve KB survive contact with how PTL is actually reported

Porter's PTL weekly report runs on an operational playbook full of hard-won production SQL, while the
PTL self-serve KB holds governed definitions that have never had a query run against them. The
hypothesis being tested is that **merging the two makes the KB less certain and more useful at the
same time** — that surfacing where production and the governed definitions disagree is worth more
than a KB that looks internally consistent because nobody checked it against practice. Pass 1 is
shipped and that hypothesis held: the KB now flags four of four planted traps to a zero-context
reader, and no `verified` row was upgraded to get there.

### Resume This Session
```bash
cd /Users/akshay.jain/Desktop/AI_V2/ProdOps/selfserve/pnm/selfserve_data && claude --resume e39437e0-94ed-40d1-81f4-507e959c33ff
```
> If the picker shows nothing, you're in the wrong folder — the `cd` above fixes that.

### Decisions, Findings & Tradeoffs

Full trail: `ptl-selfserve/coordination/DECISIONS.md` (25 entries, D-001…D-025 — 11 owner rulings,
14 orchestrator calls). Load-bearing ones:

- **The precedence ladder gained a tier, assigned per claim, not per source** (D-005). Only **2 of the
  source's claims** cleared its "reconciled against a named Metabase surface" bar, so exactly two rows
  were *corrected* — `T-033` (weekly `created_at` / monthly `updated_at`) and `M-008` (revenue is a
  cadence split, not three rivals). Everything else was annotated.
- **The bar demoted the claim it was built to serve** (D-012). The source says *"match dashboard 4793
  exactly"* then mandates a denominator 4793's own card does not use. "Reconciled" has to mean it
  demonstrably happened, not that the source says so. Two spec revisions accepted the assertion.
- **Tier 3 initially had no output** (D-009) — every disposition resolved to "annotate + open a gap",
  identical to no ruling at all. Owner gave it teeth: source-wins now means the row is *corrected*,
  superseded wording kept in its `note`.
- **The week conflict was deliberately not resolved** (D-003). Instead any weekly cut must ask the
  requester which convention they mean. Picks no side, changes behaviour where the ambiguity bites.
- **No values imported** (D-004). Methodology and dated structural events only.
- **Seven blind gates ran** (D-014). v1 was structurally broken; v2 had 4 severe; v3 had 6 blocking.
  **Three of the 13 final conflicts were, at some revision, confidently recorded as non-conflicts.**
- **The output test found what six spec gates could not** (D-021–D-023) — because they read the plan
  and it used the product. Reading a spec and using an artifact are different tests.

**Shipped:** `1f008cd` spec · `cd365a0` Pass 1 execution (8 files, 13 conflicts, 18 gaps
`G-154`–`G-171`, new `query-rules.md`) · `822b8de` output-test fixes. All pushed to origin.

**Verification held:** confidence declarations 57→57 (nothing upgraded) · 5/5 file-level
`last_verified` untouched · 13/13 new rows `unverified` · CONTEXT 174/175 lines · blind output test
**8/8 with the adversarial row clean**, so `query-rules.md` is not being read as governed definition.

### Remaining Execution

1. **Settle D-025 — the one live decision.** Tier 3's whole evidentiary basis is `dashboard/4632`,
   which this KB has **never opened**, from a source whose *other* reconciliation claim was proven
   false. It authorised both corrections. **One `get_card` on any 4632 card probably settles it** —
   metadata read, inside hard rule 1. Reversing it reverts `T-033` and `M-008`.
2. **Confirm the Notion page ID** `36a9c6eaaa6d809db065efc12ecf4f42` and capture its last-edited
   timestamp for `source_updated_at`. Every `source_ref` written in Pass 1 assumes it.
3. **Retrieve `references/experiment_report_prompt.md`** — the source's own cited authority for
   experiment reporting. `B-079` and all of Pass 2's experiment work depend on it.
4. **Pass 2** — the ~41-item analytical layer (decomposition methods, interpretation heuristics,
   threshold triggers, the QC harness, the scrubbed mistake register). Inventory in the import spec
   §13. Own spec, own blind gate, and its own output test.
5. **Decide `coordination/`'s fate** — currently untracked. Commit deliberately or `.gitignore`.
6. Three pre-existing KB defects for the owner, deliberately not repaired (D-024): `G-134` points at
   closed `G-116`; `G-047` cites card 48923 where `M-014` cites 44469; CONTEXT's opening paragraph is
   garbled and is the first thing a new reader hits.

### Blockers / Open Questions

- **Five gaps are owner-blocked and need decisions, not analysis:** `G-154` week convention ·
  `G-155` namespace divergence · `G-161` denominator (demand vs terminal) · `G-163` business-customer
  table · `G-164` exclusion mechanism.
- **The strategic one:** the weekly report and the canonical 4793 dashboard compute cancellation
  ratios on **different denominators, and both are currently defensible**. Every PTL cancellation
  number in circulation depends on which one its author used, and nobody has ruled.
- **`verified` is carrying two incompatible meanings.** The blind reader flagged `M-019` (stamped
  `verified`, evidence is a card cited by *title*, which CONTRIBUTING §4 says is never sufficient) and
  `T-020` (`verified`, then "the TABLE is contested"). Its words: *"a label that survives its own
  disqualifying evidence stops being a signal."* Not acted on — D-008 was an explicit owner ruling.
- **Still true and worth repeating:** no number in this KB has ever been validated against the
  warehouse. Nothing here is stakeholder-ready.
