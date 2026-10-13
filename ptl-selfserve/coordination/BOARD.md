# BOARD — current state & handoff
# Mutable, single-writer (orchestrator). Reference decisions by ID (see D-NNN); do not restate them.
# Done-test: a fresh zero-context agent can continue from this file alone.
Updated: 2026-08-11 17:02 IST (orchestrator)

## Workstream
Import the PTL weekly-report operational playbook — `notion:36a9c6eaaa6d809db065efc12ecf4f42` —
into the PTL self-serve knowledge base at `ptl-selfserve/kb/`. Scope is the PTL KB only (see D-001).

**Pass 1 is EXECUTED and COMMITTED.** Pass 2 is scoped but unspecified.

## Mode
**SEQUENTIAL**, with review gates as returning workers. Step-0 answers: decomposable = only the
gates, not the file edits (interdependent, single writer); **depth not breadth** (one import, done
correctly) — which alone rules out PARALLEL; workers never wrote shared state, they returned findings;
the gate cost was worth it and the execution fan-out would not have been.

## Roster
- **orchestrator (me)** — sole writer of DECISIONS, BOARD, and all `kb/` edits.
- gate-1 *fidelity* (done) — did the spec say true things about source + KB? → 22 findings; 2 of 5 headline conflicts misidentified (see D-015, D-016).
- gate-2 *source coverage* (done) — what did the spec leave out? → 259 units classified, **52 missed**, 41 of them KB-worthy. Produced the framing that shaped D-007: the import would have carried the source's *plumbing* and left its *reasoning* behind.
- gate-3 *reverse coverage* (done) — what in the KB does the source bear on that the spec never connected? → **14 HIGH** unconnected findings across ten existing gaps.
- gate-4 *dry-run implementability* (done) — could an executor run the spec without inventing content? → **not executable**; 2 of 8 verification checks worked.
- gate-5 *spec v2 review* (done) — 12 fixed / 3 partial / 0 unfixed, **4 severe new**.
- gate-6 *spec v3 review* (done) — 6 blocking, incl. "the tier-3 machinery has no output" → drove D-009.
- **blind-output-test (done)** — zero-context agent, `kb/` only. **PASSED 8/8, adversarial row clean** (see D-021). Also surfaced 5 real KB defects, 2 of them mine (D-022, D-023), 3 pre-existing and left alone (D-024).

## Pending / next
1. ⚠️ **OWNER DECISION — D-025 is the live one.** Tier 3's entire evidentiary basis is `dashboard/4632`, which this KB has **never opened**, from a source whose *other* reconciliation claim was proven false (D-012). Either confirm it with one metadata read of 4632, or accept that the two corrections it authorised (`T-033`, `M-008`) rest on an unaudited assertion. **One `get_card` on any 4632 card probably settles it.**
2. **Two prerequisites nobody has closed** — see Shared context. Both cheap, both gate real work.
3. Three pre-existing defects for the owner, not repaired here (D-024): `G-134`→closed `G-116`; `G-047` card **48923** vs `M-014` card **44469**; CONTEXT's garbled opening paragraph.
4. Pass 2 — the ~41-item analytical layer. Own spec, own blind gate. Inventory in the import spec §13.
5. Five owner-blocked gaps need decisions, not analysis: `G-154` week · `G-155` namespace · `G-161` denominator · `G-163` business definition · `G-164` exclusion mechanism.

## Shared context (facts the work depends on)
- **Artifacts.** Spec: `repo@1f008cd:ptl-selfserve/iteration-2-weekly-report-skill-import-spec.md` (v4, survived 6 gates). Execution: commit **`cd365a0`**, 8 files. Branch `claude/ptl-metric-catalog-map`, pushed to origin.
- **What Pass 1 changed.** 13 conflicts recorded two-sided · 18 gaps `G-154`–`G-171` · **exactly 2 rows corrected** under tier 3 (`T-033` date basis, `M-008` revenue base) · new `query-rules.md` with 18 `Q-###` rules, all tier 5 · `dashboard/4632` recorded as a live surface the KB has never opened.
- **Verification at commit time.** Confidence declarations 57→57 (nothing upgraded) · all 5 file-level `last_verified` still `2026-07-29` · 13/13 new rows `unverified` · CONTEXT 172/175 lines · 34 inline `[unverified · notion:36a9…]` markers.
- ⚠️ **PREREQUISITE 1 — the Notion page ID is UNCONFIRMED.** Every `source_ref` written in Pass 1 assumes `36a9c6eaaa6d809db065efc12ecf4f42` is a real Notion page id (inferred from the export filename plus a sibling id sharing its `36a9c6eaaa6d80` prefix). If wrong, all of them degrade to `local:` — which caps **confidence**, not precedence (see D-005), so the tier assignments survive, but the rows become permanently unupgradeable through that path. Also still uncaptured: the page's last-edited timestamp, needed for `source_updated_at`.
- ⚠️ **PREREQUISITE 2 — a second source has never been read.** The playbook's front matter cites `references/experiment_report_prompt.md` as the authority for the experiment reporting flow. `B-079` and the whole Pass 2 experiment plan depend on it. Nobody has retrieved it.
- **The source is not trustworthy on its own say-so.** 12 self-contradictions logged in `G-168`, and its one auditable reconciliation claim (dashboard 4793) is falsified by the KB's own reading of that dashboard's card (see D-012).

## Learnings / caveats
- **Blind gates earned their cost, repeatedly and non-trivially.** Every round found defects that would have shipped: v1 was structurally broken, v2 had 4 severe, v3 had 6 blocking. Three of the 13 final conflicts were, at some revision, confidently recorded as *non*-conflicts. The spec's own §1 keeps that history rather than presenting a clean document — a clean document would misrepresent its own reliability.
- **The recurring defect class is verification that cannot detect its own failure.** A values grep that missed the very values the spec smuggled in; a `git diff` check that returned empty and read as a pass; a no-drift check that counted prose (D-019). Reasoning about a check is not testing it — **run every check against real content before trusting it.**
- **Annotating a pointer is not annotating the row** (D-020). Bit twice: once in spec v2 (`B-031`), once by me during execution (`T-020`) *after* I had written the rule forbidding it.
- **A precedence ruling with no differentiated outcome is not a ruling.** Tier 3 spent two revisions producing dispositions identical to having no tier at all (D-009).
- **Provenance determines disposition, so check it before asserting one.** Three rows this import contests turned out to rest on `local:…master_instruction.md` at `unverified` — the weakest form the KB admits — while three others rest on card SQL at `verified`. Same conflict, opposite outcomes.
- **This import deliberately made the KB less certain.** No `verified` row was upgraded; several long-standing facts are now marked contested. That is the correct outcome of importing a source that disagrees with you, not a failure of the import.
- **The output test earned its place independently of the gates.** Six spec gates read the *plan*; the blind reader used the *product* and found things none of them could — a stale budget restatement in `WALKTHROUGH`, a self-contradicting count inside `CONTEXT`, and the tier-3 circularity (D-025). **Reading a spec and using an artifact are different tests.** Do the same for Pass 2.
- **The KB's design goal is demonstrably working.** The blind reader: *"four of eight questions had a trap in them, and the KB flagged all four. A KB that just listed formulas would have let me be confidently wrong on every one."* Its stated cost is equally real — the KB is strong at *"how is this defined"* and near-incapable of *"what is the number"*, and on the two corrected rows the reader could not tell whether to quote the correction or the superseded wording preserved beside it.
- **`verified` is being asked to carry two incompatible meanings.** The reader flagged `M-019` (stamped `verified`, evidence is a card cited by title — which CONTRIBUTING §4 says is never sufficient) and `T-020` (`verified`, then "the TABLE is contested"). Its words: *"a label that survives its own disqualifying evidence stops being a signal."* Not acted on — D-008 was an explicit owner ruling — but worth revisiting if it recurs.
