---
status: in-progress
context: claude/ptl-metric-catalog-map
timestamp: 2026-09-03T03:45:07Z
session_id: 4c31a3c4-f0d2-4e5d-bdb7-c78fcd5c27a0
cwd: /Users/akshay.jain/Desktop/AI_V2/ProdOps/selfserve/pnm/selfserve_data
---

## Strategic Goal: Put governed metric answers in the hands of PMs and the business team

Let a PM, a business colleague, or the Head of Business ask "what was PTL fulfilment by city last week?" and get a number they can trust — with the definition, its confidence, and its source attached — instead of queuing behind an analyst. The commercial case is analyst-hours reclaimed and faster decisions; the risk case is that a *wrong* number reaching leadership ends the initiative permanently.

### Resume This Session
```bash
cd /Users/akshay.jain/Desktop/AI_V2/ProdOps/selfserve/pnm/selfserve_data && claude --resume 4c31a3c4-f0d2-4e5d-bdb7-c78fcd5c27a0
```
> If the picker shows nothing, you're in the wrong folder — the `cd` above fixes that.

### Decisions, Findings & Tradeoffs

**The reframe that drove everything.** Two of the three capabilities needed already ship inside Porter: `data-tools:query` (NL to SQL, mandatory human approval, live Connectors) and `akshayjain-mbr-brain` (knowledge base packaged as an installable skill, gated progressive disclosure). The genuinely missing piece is a **governed definition layer** — something forcing every number to resolve to an agreed definition before the query runs.

**Why that layer is load-bearing, not nice-to-have.** An LLM interface does not fix self-serve BI's historical failure — it amplifies it. It removes the SQL-literacy barrier and little else: it makes ungoverned definitions *worse* (a fluent wrong answer outranks a dashboard tooltip) and overreliance worse (explanations raise trust whether or not they are correct). Cited comparator: $400K spent on augmented analytics, adoption fell to 12% in six months once users hit conflicting definitions.

**Three architectures proposed; two are dead.**
- **Option A** — plugin composing with `data-tools:query`. Deferred: cross-plugin composition is unproven.
- **Option F** — Metabase card collection + definition-lookup skill. Chosen at Checkpoint 2, then **failed its blind re-gate. Marked NOT APPROVED (D-029).**
- **Option G** — annotate governed definitions onto the incumbent Metabase cards people already open, and archive duplicates. Proposed by the reviewer, **awaiting owner decision (D-030)**. Not yet itself reviewed.

**Why Option F died — two structural defects, both verified against the KB.**
1. **A card cannot ask.** `CONTEXT.md` Hard Rule 4: the week convention is CONTESTED and *"any weekly cut must ask the requester which convention they mean before running."* A pre-built card can't ask, refuse, or express doubt — it resolves by fiat and looks official. Option F removed the only component capable of the KB's own mandated behaviour.
2. **The incumbent already does more.** `dashboards.md:57` — `dashboard/4198`, PTL Business Observability, ~82 cards, 11 tabs, filtered by date x Day/Week/Month x pickup city x drop city x order state x route x delivery type. That *is* Job A, live, no install, tens of thousands of views. The proposed 8-10 fixed-grain cards were a *narrower* surface than what the business team already opens — and no research brief or spec draft ever named it.

**Process decisions that paid off.**
- SEQUENTIAL orchestration with one bounded PARALLEL research fan-out (4 agents), then sequential synthesis (D-003).
- Every review ran as a **BLIND** gate — reviewer gets the goal and the artifact, never the author's reasoning (D-004). Gate 1: 3 BLOCKING / 5 SEVERE / 7 MODERATE / 3 MINOR. Gate 2: 2 BLOCKING / 3 SEVERE / 4 MODERATE / 1 MINOR, verdict "worse than what it replaced". **17 findings folded in, 1 rejected on evidence (D-024 — a grep pattern that matched only one of two gap-table formats).**
- Escalated rather than pivoted a third time (D-030). Two architecture changes are already in the document; a third on my own authority would be a pattern, not a correction.

**Honest self-assessment recorded in BOARD learnings.** The Checkpoint-2 options were not equally researched — Option A had four research briefs behind it, Option F had one line from a gate. The owner chose the under-researched one on my framing. Also: the same porter-central citation was inverted **twice, in opposite directions** (D-016, D-032) — motivated reading, not a quoting slip.

### Remaining Execution

1. **Settle `G-154` — the week convention.** Sat→Fri or Sun→Saturday? Both live in production, neither outranks the other, marked BLOCKED — owner. Until settled, every weekly figure any design produces is a coin-flip presented as fact.
2. **Settle `G-161` — the fulfilment denominator.** All-states or terminal-state? The weekly report and the KB disagree today; the gap entry states plainly this is "a definitional choice, not a discoverable fact." This is the number most likely to reach leadership and be wrong.
3. **Choose the approach** — Option G (cheapest, no install, governance where the traffic already is), Option F with fixes, or pause until 1 and 2 are settled and decide with better information.
4. **Rule on `contested_by`** — the KB stamps precedence-resolved winners as `verified`, destroying the signal that a conflict existed. Adding a fourth state changes the contributor contract in `ptl-selfserve/kb/CONTRIBUTING.md`, which belongs to the *other* workstream.
5. **Then, and only then**: rewrite the spec to the chosen architecture and re-gate it. **Do not implement from the current document.**
6. Housekeeping: `gh auth login` (token invalid, blocks any marketplace PR — Option G needs none of it); confirm Metabase collection edit permissions.

### Blockers / Open Questions

- **The critical path is not engineering work.** `G-154` and `G-161` are owner rulings. `GAPS.md`: "BLOCKED gaps need an owner decision, not more analysis." Every architecture so far assumed one of them away.
- **`CONTEXT.md:174` — "No number here has been validated against the warehouse — no query has been run. Nothing is stakeholder-ready."** Distribution is downstream of this. Hard Rule 1 gates production queries on explicit owner go-ahead, never obtained.
- **21 further gaps are BLOCKED — owner**, sitting on exactly the metrics anyone would publish first (`G-001`/`G-002` two incompatible <60s semantics; `G-004`/`G-135` three AOV bases x two date bases; `G-142`).
- **Adding a governed surface without touching the incumbents makes the problem worse.** Metabase already holds 3-6 competing definitions per metric. A new collection becomes a fourth opinion in the same tool — the 12%-adoption failure caused rather than prevented.
- **REPO HYGIENE — R3 violation, needs action.** 13 commits on `claude/ptl-metric-catalog-map` are unpushed; the branch has **no upstream set** (remote `origin` does exist: `github.com/akshayjain00/selfserve_data.git`). Fix: `git push -u origin claude/ptl-metric-catalog-map`.
- **R1/R2 violation — a sibling clone exists** at `~/dev/selfserve` (branch `main`). This session's work happened in the Desktop path instead. Two homes means no home. Note: a stored memory claims the Desktop path is DLP-locked and kills git — **that is stale; git has worked normally throughout this session.** Worth correcting or deleting that memory.
- **Option G has never been blind-reviewed.** It is the reviewer's own proposal, so it carries none of the scrutiny the other two received. Do not treat its apparent strength as validated.

### Artifacts

- `DISTRIBUTION-ARCHITECTURE-SPEC.md` — the spec. **Banner-marked NOT APPROVED.** Read §15 first; everything above it is the historical record.
- `coordination/DECISIONS.md` — D-001 to D-032, append-only, IDs strictly increasing.
- `coordination/BOARD.md` — current state, roster, shared context, learnings. Passes the cold-resume test.
- `DISTRIBUTION-ARCHITECTURE-VISUAL.html` — published artifact: https://claude.ai/code/artifact/f87e9b34-d8ec-450b-89a0-96bdbac542fc
