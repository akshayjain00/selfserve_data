# DECISIONS — append-only decision log
# Writer: ORCHESTRATOR ONLY. Workers propose (in their return); the orchestrator commits here.
# Append at the END. IDs strictly increasing. Never edit an existing entry in place.
# Format: [D-NNN] YYYY-MM-DD (orchestrator) — decision — rationale

# Workstream: importing the PTL weekly-report playbook
# (notion:36a9c6eaaa6d809db065efc12ecf4f42) into ptl-selfserve/kb/.
# D-001..D-020 are BACK-FILLED 2026-08-11 from the originating session — the work
# predates this log. Entries marked (owner) were ruled by Akshay; the rest are
# orchestrator calls. Nothing here is reconstructed from memory alone: every entry
# traces to a spec revision or a commit in this repo.

[D-001] 2026-08-11 (owner) — Scope is the PTL KB only — `ptl-selfserve/kb/`. — Ruled in response to a broader reading of "our knowledge base"; `pnm-selfserve/` and `hcv_selfserve/` are out of scope entirely and were never touched.

[D-002] 2026-08-11 (owner) — Import shape: extract rows into the existing topic files AND add one new topic file for operational practice, rather than rows-only or a verbatim appendix. — A verbatim appendix would place an unprovenanced document inside a provenance-strict KB and invite future sessions to cite it as fact.

[D-003] 2026-08-11 (owner) — The Sat→Fri vs Sun→Sat week conflict is NOT resolved; instead any weekly cut must ask the requester which convention they mean. — Better than either of the three options offered: it picks no side, which is what CONTRIBUTING §6 requires of an unresolved conflict, while still changing behaviour at the point the ambiguity actually bites.

[D-004] 2026-08-11 (owner) — Exclude every numeric value from the source; dated structural events and rule thresholds are not values. — CONTRIBUTING §7 bans values in definition rows, §9 bans derived query results. The source is dense with measured outcomes (revenue, conversion series, experiment baselines); the methodology is what has durable worth.

[D-005] 2026-08-11 (owner) — Add a precedence tier for "reconciled operational SQL", below observed card SQL and above the iteration-1 catalog, ASSIGNED PER CLAIM rather than per source. — The ladder had no rung for hand-authored analyst SQL that had been executed and reconciled. Per-claim assignment came in a later revision after a gate showed a single document holds tier-3 and tier-5 claims side by side.

[D-006] 2026-08-11 (owner) — `query-rules.md` is created, but every rule carries a `collides_with` column naming the KB row it contradicts, stated inline. — Without it the file is a back door around the precedence ladder. A rule with a non-empty `collides_with` may never be read alone.

[D-007] 2026-08-11 (owner) — Split the import: Pass 1 = conflicts, corrections, cross-links, stale pointers; Pass 2 = the analytical layer (~41 items). Each gets its own blind gate. — The import roughly doubled once reverse-coverage was checked; one pass would have produced a diff touching most of the KB under a single gate.

[D-008] 2026-08-11 (owner) — `M-019` keeps `confidence: verified`; the raw-vs-slot-anchored clock divergence becomes its own conflict and gap rather than a downgrade. — Offered as a downgrade and declined. The confidence question was routed to `G-171`/`G-152` (the card is cited by title and unfingerprinted) so the premise is recorded rather than silently relied on.

[D-009] 2026-08-11 (owner) — Tier 3 gets teeth: where a tier-3 claim outranks a KB row, that row's `statement` is CORRECTED, with superseded wording preserved verbatim in its `note`. — A gate found that every tier-3 disposition resolved to "annotate + open a gap" — indistinguishable from no ruling at all. Without this the ~50 lines of ladder machinery bought nothing.

[D-010] 2026-08-11 (owner) — `T-023`'s "same outcome" clause is ANNOTATED as contested, not corrected. — `T-023` is tier-1 card SQL; the contrary claim is tier 3, so the ladder says the row holds. Three sections of spec v3 disagreed on this; the ruling settled it against the direction I had drafted.

[D-011] 2026-08-11 (owner) — Relax the CONTEXT length budget from ≤150 to ≤175 lines (CONTRIBUTING §10.3). — CONTEXT was at exactly 150 and the import needed ~7 more. The rule's intent — an entry point short enough that it is actually read — survives at 175.

[D-012] 2026-08-11 (orchestrator) — Applying tier 3's own bar honestly DEMOTES the terminal-denominator claim to tier 5, which removes `B-060` as the correction target and moves the only corrections onto `T-033` and `M-008`. — The bar says "reconciled", not "claims to be reconciled". The source says *"match dashboard 4793 exactly"* then mandates a denominator that `metrics.md:89` shows 4793's own card 43237 does not use. Two prior revisions accepted the assertion as the evidence. Logged as first-order evidence about source reliability in `G-168`.

[D-013] 2026-08-11 (orchestrator) — The conversion-funnel claim is tier 5, not tier 3. — Its sole evidence is a code comment reading `-- Dashboard reference: Metabase 4632 / 9771305`. A reference is not a reconciliation, and `9771305` is 7 digits against 5-digit card ids elsewhere, so it is not even established to be a card (`G-167`).

[D-014] 2026-08-11 (orchestrator) — Every review gate runs as a BLIND subagent given the sources and the bare claims, never the reasoning for why they are right. — Standing authorization in the user's global CLAUDE.md §7. Vindicated: gate 1 found that two of five headline conflicts were misidentified and two real conflicts had been recorded as agreements.

[D-015] 2026-08-11 (orchestrator) — Reverse a spec claim: the source's FF-denominator / cancel-numerator split is CORROBORATION of `G-002`'s two known variants, not "a fourth semantics". The genuinely new variant is the morning-slot 08:00 effective clock. — Gate 1 evidence. The original claim would have opened a duplicate gap describing an already-recorded thing while missing the largest-impact variant entirely.

[D-016] 2026-08-11 (orchestrator) — Route the date-basis conflict to `G-135`, not `G-007`. — `G-007` closed 2026-07-30. The error's root cause is instructive and is now fixed: `T-033` still carried a dangling `→ G-007` pointer, so reading the KB faithfully produced a wrong conclusion. Repointing that pointer is part of Pass 1.

[D-017] 2026-08-11 (orchestrator) — Open the terminal-denominator and clubbing-base conflicts, both of which two spec revisions had recorded as AGREEMENTS. — Found independently by three gates. Terminal denominator contradicts `M-003`/`M-005`/`M-006`/`B-060`; clubbing base contradicts `M-007`, proven by the source's own QC assertion that clubbing ≥ 1.0, a floor only possible on a solo-inclusive base.

[D-018] 2026-08-11 (orchestrator) — `Q-###` rows carry 4 columns, with `source_ref` and `confidence` declared once in the file header; CONTRIBUTING §2 amended to permit this for single-source files. — Repeating one identical `source_ref` down 18 rows is noise, not provenance, and §2 already sets this precedent for `last_verified`. Recorded as a deliberate deviation from spec v4 rather than left quietly off-spec.

[D-019] 2026-08-11 (orchestrator) — Replace the no-drift verification check. — As written it counted every occurrence of the backticked word `verified`, so prose *about* confidence ("no `verified` row was upgraded") registered as drift; it reported 56→62 and failed. The corrected check counts confidence DECLARATIONS and reports 57→57. Same defect class the gates repeatedly charged the spec with, found in my own verification.

[D-020] 2026-08-11 (orchestrator) — Annotate `T-020` directly, not only CONTEXT's "three facts" pointer. — Caught by the two-sided-conflict check during execution. This is precisely the `B-031` defect gate 2 charged spec v2 with — annotating the pointer rather than the row — repeated by me at execution time despite having written the rule that forbids it.

[D-021] 2026-08-11 (orchestrator) — Blind output test PASSED 8/8 with the mandatory adversarial row clean; `query-rules.md` is retained. — A zero-context agent given only `kb/` answered the CBDF-definition question from `metrics.md`/`dashboards.md` and never cited `query-rules.md` as a governed definition. That was the stated cut condition for the file (D-006). It also flagged four of four planted traps — week convention, cross-config slot comparison, dissolved corridor, and a fulfilment number matching neither recorded figure.

[D-022] 2026-08-11 (orchestrator) — Fix `WALKTHROUGH.md`'s two "150 lines" references to 175. — Orphaned by D-011: I amended the budget in CONTRIBUTING §10.3 and left the two restatements of it stale, so the KB contradicted itself on its own governance rule. Found by the blind reader, not by my ladder-parity check, which only compared CONTEXT against CONTRIBUTING.

[D-023] 2026-08-11 (orchestrator) — Correct CONTEXT's "74 uncovered metrics" to 62, with a note that 74 is the superseded pre-promotion count. — I edited that bullet during Pass 1 (48→66 gaps) and left the adjacent figure stale, so one file disagreed with itself ~100 lines apart. In scope because I touched the line.

[D-024] 2026-08-11 (orchestrator) — Do NOT fix three pre-existing defects the blind reader surfaced; record them for the owner instead. — CLAUDE.md §3: repair only what your own change orphaned. (a) `G-134`'s next_action says "close `G-116` first" but `G-116` is CLOSED — the live successor is `G-152`; (b) `G-047` cites card **48923** for catalogue #10 while `M-014` cites **44469**, and 48923 appears exactly once in the whole KB; (c) `CONTEXT.md`'s opening paragraph is garbled mid-sentence and carries two spelling errors, which is the first thing any new reader hits.

[D-025] 2026-08-11 (orchestrator) — Escalate the blind reader's strongest finding to the owner rather than acting on it: **tier 3's entire evidentiary basis is a dashboard nobody has opened.** — Every tier-3 claim names `dashboard/4632`, which `dashboards.md` records as never opened — zero cards read, no SQL, no fingerprint. `G-168` simultaneously records that the *same source's* other reconciliation claim (dashboard 4793) is demonstrably false. So the KB caught this source overclaiming reconciliation once, then accepted an unaudited reconciliation claim from it as its highest-trust evidence — and that evidence is what authorised the only two row corrections in the import (`T-033`, `M-008`). This is D-012's own logic applied one step further than I applied it. Reversing it would revert both corrections; confirming it needs one metadata read of 4632. **Owner's call — not mine to make unilaterally, and not safe to leave unstated.**
