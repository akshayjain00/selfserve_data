# Distribution Architecture — Self-Serve Metric Knowledge Base

> ## ⛔ v3 DID NOT PASS ITS RE-GATE — DO NOT IMPLEMENT FROM THIS DOCUMENT
>
> The narrow blind gate on the pivoted sections returned **2 BLOCKING + 3 SEVERE** findings and
> concluded the pivot is **worse than what it replaced**, on verified evidence. Three of its
> load-bearing claims were independently re-checked by the orchestrator and hold. It also surfaced a
> third option — **annotate the metric definitions into the Metabase cards people already use** —
> which appears cheaper and higher-value than either architecture this spec has proposed.
>
> **§16 (2026-09-03) SUPERSEDES the packaging decision.** The owner challenged the MCP rejection and
> was right: §2.2 conflated a *local stdio* MCP with a *remotely hosted* one, and justified the
> rejection with `data-tools`' auth problems that a knowledge-serving MCP does not have. §16 compares
> all eight options and reaches a decision. **Read §16 first, then §15 for the gate findings.**
> Everything above §15 is the historical record.

**Status:** v4 — **§16 holds the current decision (D1 → G → D2).** §0–§14 describe Option F, which failed its gate and is retained only as the record. §15 is the gate outcome; §16 reopens and resolves the packaging question.
**Date:** 2026-08-14 · §16 added 2026-09-03
**Owner:** Akshay Jain
**Decision trail:** `coordination/DECISIONS.md` (D-001 … D-036)
**Scope:** how the self-serve metric knowledge base reaches PMs, the business team, and the Head of Business, with live Metabase + Snowflake results.

---

## 0. The decision, in one page

**Iteration 1 ships a curated Metabase collection plus a definition-lookup skill. No LLM writes SQL for anyone in v1.**

This is a deliberate reversal of the obvious design, made after a blind review established two things: the trust mechanism the first draft relied on could not fire on the case it existed for (§8.1), and the full-scope build was 8–10 person-days against a one-week constraint (D-017). Option F resolves both by removing SQL generation from v1 entirely.

| Capability | Status | Where |
|---|---|---|
| NL question → SQL → approval gate → execute | **Exists** — but deferred to iteration 2 | `data-tools:query` (porter-central v0.6) |
| A curated KB packaged as an installable Skill, gated progressive disclosure | **Exists** as a pattern | `akshayjain-mbr-brain` (porter-community) |
| **Governed answers to the questions people actually ask** | **MISSING** | this spec, iteration 1 |

**What iteration 1 is:**
1. A **Metabase collection of 8–10 cards** covering the starter question set, each built from a KB-governed definition and each *naming* that definition in its description.
2. A **`porter-community` plugin whose skill does definition lookup only** — "how is `ff` defined, what's its state, which card answers it" — with no `data-tools` dependency and no SQL generation.

**What this buys, concretely:**
- **The largest risk in the design leaves v1.** Cross-plugin composition with `data-tools:query` is unproven (§12.1); iteration 1 no longer depends on it.
- **The business team gets a surface that needs no install and no Connector.** A Metabase card is a URL in a browser. The whole desktop-app question (D-008) stops gating them.
- **The contested-definition problem gets much smaller.** A card's definition is chosen *once*, by the owner, reviewable before anyone sees a number — instead of being re-resolved per query by an LLM that stamps the winner `verified` (§8.1). It does not vanish: the cards must still declare their base and reconcile against the weekly report (§10.3).
- **It is the thing porter-central's own culture doc asks for.** *"Demand still has to be packaged"* (§1.2). A card collection is packaged demand; a terminal plus a knowledge layer is not.

**What it costs, stated plainly:** iteration 1 does **not** serve Job A's arbitrary grain-and-dimension ask, which is the actual request. Cards have fixed grains. A PM wanting "fulfilment by vendor, daily" is not served until iteration 2. That is the trade the owner made knowingly, and the iteration-2 trigger (§7) is written to fire the moment it bites.

**The eight decisions:**

| # | Decision | Choice |
|---|---|---|
| 1 | Packaging | Metabase collection + `akshayjain-selfserve-metrics` plugin (definition lookup only) in `porter-community` |
| 2 | KB shape | Per-vertical KBs under one governance model; **PTL ships first** |
| 3 | Data path | v1: Metabase cards, native. Skill is read-only over vendored KB. **No Snowflake path in v1** |
| 4 | Job contracts | Job A served at **fixed** grains via cards; arbitrary grains = iteration 2. **Job B = iteration 3** |
| 5 | Personas | Business team ✅ (cards) · PM ✅ (cards + definition skill) · **Head of Business hand-walked** |
| 6 | Iterations | Trigger-gated, not calendar-sequential. **v1 < 5 person-days** |
| 7 | Trust & failure | Card-level definition declaration + a `contested_by` state + reuse of the existing `G-###` loop |
| 8 | Adoption | 3–5 seeded users, the card collection *is* the starter question set, one Slack channel |

---

## 1. What already exists (evidence base)

From four research workers run 2026-08-14, spot-checked by a blind reviewer.

### 1.1 In this repo

- **One KB exists, and it is PTL's.** `ptl-selfserve/kb/` = 9 files, **2,091 lines** (verified): `CONTEXT.md` (router), `business.md`, `metrics.md` (513L), `data-model.md`, `dashboards.md`, `query-rules.md` (18 `Q-###`), `GAPS.md`, `CONTRIBUTING.md`, `WALKTHROUGH.md`. Row IDs `B/M/T/G/Q-###`, each with `source_ref`, `confidence` (`verified`/`unverified`/`assumption`), `source_updated_at`. A 6-tier precedence ladder resolves conflicting sources.
- **Gap count**: 48 rows carry a leading `**G-###**`; `CONTEXT.md:161` claims **66 substantive gaps**; 159 distinct `G-` IDs are referenced. The KB uses two table formats, so these count different things. **[unknown] — the reconciled figure.** Nothing here depends on it.
- **PNM has no `kb/` directory. HCV has neither KB nor harness.**
- ⚠️ **`selfserve_nlq/` is not on the path.** Single-analyst CLI prototype; **both harnesses refuse non-monthly grains and unregistered dimensions (city / route / vendor / weekly / daily / percentile) by design.** Job A is what they reject — a contract mismatch, not an extension gap. Nothing in v1 touches it.
- **The coverage-map JSON schema is shared** across all three verticals — reusable, no porting.
- **`dashboards.md` already records ~29 fingerprinted Metabase cards**, which is the seed inventory for iteration 1's collection.

### 1.2 In the Porter plugin ecosystem

- **`data-tools:query`** runs NL → SQL → *mandatory* approval → execute. Deferred to iteration 2, but its protocol constrains that design: Step 1A invokes `superpowers:brainstorming`; **Step 2A mandates Data Catalog schema discovery before SQL generation**; Step 3 invokes `porter-sql-patterns`. It applies MART > CORE > INTERMEDIATE > RAW priority — which will conflict with the KB's table list (§7, iteration 2).
- **`data-tools` v0.6 deleted all bundled MCP servers** (CHANGELOG 0.6.0, 2026-05-01) in favour of Claude.ai account-level **Connectors**.
- **`akshayjain-mbr-brain` proves the KB-as-plugin pattern** — per-vertical context plus `manifest.json`, user-gated progressive disclosure via `file_size_bytes / 4` token estimates, **never auto-loads**. Iteration 1's skill copies this directly.
- ⚠️ **`hypothesis-validation` is a personal, machine-local skill** (`~/.claude/skills/`), in **neither** marketplace. This is why Job B is iteration 3 (D-013).
- **Two marketplaces**: `porter-community` (15 plugins, 10 namespaces) → Team → `porter-central` (6 plugins, authoritative).
- **Community CI rules**: plugin name **must carry a `<username>-` prefix**; `marketplace.json` needs a matching entry with same name + version and `source` → `./plugins/<username>/<plugin-name>`; semver + CHANGELOG enforced.
- ⚠️ **porter-central's culture warning cuts against the *original* design and FOR this one.** `data-products/README.md` names as its canonical anti-pattern "shipping the primitive instead of the product" — handing users Claude Code plus a knowledge layer and calling that the product: *"the LLM needs Claude Code. **Demand still has to be packaged.**"* Iteration 1's card collection is the packaged demand. *(Draft v1 quoted this passage as endorsing a terminal-first design; that was an inversion, corrected in D-016.)*

### 1.3 From industry practice

- Highest-leverage cheap accuracy lever: the **verified-query bank**. Iteration 1's card collection *is* this pattern, expressed in Metabase rather than in JSON — curated, known-correct, reviewed once.
- **Benchmark reality check**: on Spider 2.0 (enterprise workflows, 800+ column schemas) an o1-preview code-agent solves **21.3%**, vs 91.2% on Spider 1.0 and 73.0% on BIRD. [research-C caveat: a far harder shape than one question against documented views, so a non-transferable floor — but the right antidote to demo-grade expectations, and part of why v1 generates no SQL.]
- **LLM-as-judge must not be the primary gate** — F1 0.70–0.76, 76–90% agreement with execution accuracy.

### 1.4 From adoption research

- **Project-ending event**: the first wrong number reaching the Head of Business. When an LLM's first answer was wrong, users agreed anyway in **9 of 13 cases**.
- A $50M SaaS company spent $400K on augmented analytics; adoption fell to **12% in six months** once users hit conflicting metric definitions.
- **Showing SQL mostly does not help a non-SQL user verify.** Its value is fast auditing by the data team.
- **Question volume is a weak signal** (novelty-inflated ~90 days).
- **Put it where users already work.** The standalone-login penalty is the largest friction found — an argument for Metabase, which the business team already opens.

---

## 2. Decision 1 — Packaging

**Chosen: a Metabase collection plus `akshayjain-selfserve-metrics` in `porter-community`, whose v1 skill does definition lookup only.**

### 2.1 Structure

```
Metabase → collection "PTL Self-Serve (governed)"
  8–10 cards, each description naming: M-### · definition state · denominator base · owner · last reviewed

plugins/<github-username>/akshayjain-selfserve-metrics/
  .claude-plugin/plugin.json          # name, description, version, author{name,email}
  skills/ptl-metrics/SKILL.md         # definition lookup ONLY — no SQL generation, no data-tools dependency
  references/
    kb/                               # vendored snapshot of ptl-selfserve/kb/ (9 files)
    card-index.json                   # question → card URL → M-### → declared base
    manifest.json                     # kb_version, kb_synced_at, per-file hashes, token estimates
  README.md
  CHANGELOG.md
```

**Plus** a matching entry in the repo-root `.claude-plugin/marketplace.json` — CI-required.

The `<username>-` prefix is CI-enforced; `selfserve-metrics` alone fails the check.

**⚠️ Interpretation flagged for owner reversal:** Option F said "plugin becomes iteration 2". Read here as *the query-composing plugin* is deferred, not the packaging decision — the KB still needs a distribution vehicle, and the plugin costs ~0.75d of scaffold + CI while preserving the container iteration 2 extends. If you meant no plugin at all in v1, the KB ships as a repo folder instead and §7's iteration-2 estimate grows by that 0.75d.

### 2.2 The options

| Option | Verdict | Reason |
|---|---|---|
| **F. Metabase collection + definition-lookup skill** | ✅ **Chosen for v1** | No LLM-generated SQL. No composition risk. No install needed by the business team. Under 5 days. Serves fixed grains only — the acknowledged cost. |
| A. Plugin composing with `data-tools:query` | **Iteration 2** | Serves arbitrary grain/dimension — the actual ask. Carries §12.1's unproven composition risk, which is why it is not first. |
| B. Skill referencing a remotely-hosted KB | Rejected | Needs hosting — Option D's cost without its benefits. |
| C. Self-contained plugin with its own query flow | Rejected | Rebuilds and maintains the approval + execution path `data-tools` owns. |
| D. MCP server fronting the KB | Rejected for now | Solves instant propagation, a problem a weekly-changing markdown KB does not yet have. Gated on §7's trigger. |
| **E. Contribute the skill INTO `data-tools`/`data-studio` in porter-central** | **Fallback for iteration 2** | One package, **zero cross-plugin invocation — dissolves §12.1 entirely.** Costs a central-tier review cycle (`data-plugin-tiers.md`: data-tools is installed org-wide, "scope must stay tight"; `@arghya-porter` co-owns `plugins/data/`). **If iteration 2's spike fails, this becomes the default.** |

### 2.3 Update propagation, versioning, drift

- **Source of truth stays `selfserve_data/ptl-selfserve/kb/`.** The plugin vendors a *published snapshot*, never a second editable copy. Editing the vendored copy is forbidden and stated in the README.
- **Cards are their own propagation channel** — edit the card, every viewer sees it immediately. This is a genuine advantage of Option F and removes the drift problem for the business team entirely.
- A **release step** (budgeted, §7) copies the KB, stamps `manifest.json` with `kb_version` + `kb_synced_at` + **per-file hashes**, bumps semver, updates CHANGELOG.
- **Drift detection for the skill, not just version display.** The PTL KB is on an active branch with corrections landing 2026-08-11 (`T-033`, `T-020`, `T-023`, `T-074` rewritten) and an open owner decision (§12.6). Per-file hashes let the skill state the diff — *"3 rows changed since your snapshot; run `/plugin update`"* — and warn when `kb_synced_at` exceeds 14 days.
- ⚠️ **New coupling introduced by Option F**: a card and the KB row it cites can now disagree. `card-index.json` records which `M-###` each card implements; the release step must re-check that mapping, and §10.6 gates it.

### 2.4 Who owns merges

Adding a plugin edits `.claude-plugin/marketplace.json`, whose approval rule is **namespace owners of affected entries, parsed from the `source` field** — a new entry pointing into your own namespace resolves to you, the author is removed from their own required-reviewer set, and it **auto-approves**. Only `.github/` and other root files require `@ambujsingh`. *(Draft v1 stated this rule wrongly in a way that contradicted its own conclusion; corrected in D-021.)*

**Metabase cards have a separate and weaker governance story** — [unknown] who reviews a card edit, and whether the collection can be made edit-restricted. **Confirm before the collection is shared** (§10.7).

⚠️ **Blocker:** the local `gh` token is invalid (`gh auth status` → "token is invalid"). `gh auth login` required before the PR. Blocks publishing only. **Who reviews recent marketplace PRs is [unknown]** as a consequence.

---

## 3. Decision 2 — KB shape, and which vertical ships first

**Chosen: per-vertical KBs sharing one governance model. PTL ships first.** (D-007)

Not one merged KB with namespaces — the verticals have different schemas, definitions, and intervention histories, and merging creates cross-vertical definition collisions, the exact failure that dropped one company's adoption to 12%.

**The transplantable asset is the governance model, not the content**: the ID schema, per-row `confidence` + `source_ref` + `source_updated_at`, the precedence ladder (as amended by §8.1), and `CONTRIBUTING.md`'s append-only rules.

**PTL first is forced by evidence.** It has the only KB, and `dashboards.md`'s ~29 fingerprinted cards are the seed inventory for the collection.

**Load a subset, not all 2,091 lines** — `CONTEXT.md` always; the rest on demand; `GAPS.md` only when a gap is hit. Token estimates shown, never auto-loaded.

---

## 4. Decision 3 — Data path

### 4.1 Per surface and persona

| | Business team | PM | Head of Business |
|---|---|---|---|
| Primary surface | **Metabase card URL in a browser** | Metabase + definition skill in Claude Code | Metabase card, hand-walked |
| Install required | **None** | Plugin from `porter-community` | None |
| Connector required | **None** | None in v1 — the skill only reads vendored KB files | None |
| SQL generated by an LLM | **None** | **None in v1** | **None** |

**The whole desktop-app question (D-008) stops gating the business team**, because a Metabase card is a URL. D-008 is not reversed — it is made moot for v1 and returns as a live question in iteration 2, when the query layer arrives.

### 4.2 Guardrails — what is actually enforced

**Enforced in v1, genuinely:** cards run pre-written, reviewed SQL against fixed parameters. There is no generated SQL to bound, no schema exploration to restrict, and no approval gate needed because nothing novel executes. **This is the strongest guardrail position any option in this spec offers**, and it is a direct consequence of Option F.

**Blast radius** in v1 is a card's own query cost, which is known in advance and unchanged by who views it.

**Deferred to iteration 2** (when SQL generation arrives): the precedence rule over `data-tools`' schema priority, row/date bound requests, and confirming the Snowflake role is read-only with a statement timeout (§12.3).

*(Draft v1 instructed copying Snowflake's 250KB truncation and 50-tool cap "as the ceiling". Deleted in D-019 — we are a consumer of someone else's connector and can set neither.)*

---

## 5. Decision 4 — The job contracts

### 5.1 Job A — "a report at grain X, cut by dimension Y"

**v1 serves this at fixed grains only.** The card collection covers the 8–10 highest-frequency questions; anything outside it is explicitly not served.

**Business-team path:** open the card. Its description names the `M-###` definition, its state, and — critically — **its denominator base** (§8.1).

**PM path:** ask the skill *"how is `ff` defined and which card answers it?"* → skill resolves `CONTEXT.md` → `metrics.md` `M-###` → `card-index.json` → returns the definition, its state, any open `G-###`, and the card URL.

**Non-negotiable computation rules** (from `ProdOps/CLAUDE.md`) are enforced **in the card SQL**, reviewed once, rather than requested of an LLM per query:
- **Aggregate-then-ratio.** Never average daily ratios.
- **Week = Saturday–Friday**, completed weeks only, `dd mmm - dd mmm`, latest leftmost.
- **Divide-by-zero → null.** Movements in **pp**.

This is the single biggest correctness gain of Option F: these rules move from *prompt* to *reviewed SQL*.

**⚠️ Choosing the cards is where the hard problem now lives.** Tracing "PTL fulfilment by city, weekly": `ff` denominator = `M-003`, `verified` **but contested by production** (§8.1); weekly date basis = `T-033`, **`unverified`**; city = `T-024`, `verified`, requires `is_active='True'` or counts silently inflate; which `orders` table = `T-074`, **`unverified`**, and the KB is inconsistent with itself (`G-155`). **The card author must make and record each of these calls.** That is real work, and it is where §7's day budget actually goes.

**What a wrong card looks like:** a base that disagrees with the weekly report without saying so · a partial trailing week · `is_active` omitted from a city cut · the wrong `orders` table.

**Not served in v1, and named so users are not misled:** arbitrary grains, unregistered dimensions, ad-hoc cuts. → iteration 2.

### 5.2 Job B — hypothesis validation → **iteration 3** (D-013)

Its designed implementation composed with `hypothesis-validation`, which is machine-local to the owner and ships in neither marketplace. A seed PM would get the definition layer with none of the noise floor, prior-period placebo, or `INCONCLUSIVE-UNDERPOWERED` verdict lattice — i.e. exactly the single-cut confirmation that constitutes a wrong answer here, failing silently because a weaker answer is not an error.

**v1 behaviour:** the skill states hypothesis questions are out of scope, surfaces the metric definition, its state, `business.md`'s intervention dates (4 Feb pricing GTMs · 2 Mar 3W pricing · 7 Mar 3W/7ft boundary · 13 Mar 8ft+ ~700km), and any open `G-###` — then stops, rather than half-serving.

---

## 6. Decision 5 — Persona ladder

| Persona | Surface | v1? | What they get |
|---|---|---|---|
| **Business team** (no SQL) | Metabase, browser | ✅ **Yes — and first-class now** | The card collection. No install, no Connector, no generated SQL. |
| **PM** (SQL-literate) | Metabase + Claude Code | ✅ Yes | Cards, plus definition lookup: "how is this defined, what's contested, which card." |
| **Head of Business** | Metabase, hand-walked | ⚠️ **Cards yes; unattended self-serve no** | First 2–3 sessions walked through with a human. |

**Option F improves the business team's position materially** — under the original design they were the highest-risk population receiving LLM-generated SQL on an unverified surface. Now they receive reviewed cards on a surface they already open.

**The Head of Business call is unchanged and remains the highest-value judgement here.** research-D's project-ending event is the first wrong number reaching this person; users agreed with a wrong first LLM answer in 9 of 13 cases; a senior exec generalises from n=1. Cards reduce the odds substantially but do not eliminate them — a card with a mis-declared base is still a confident wrong number.

---

## 7. Decision 6 — Iteration ladder

**Trigger-gated, not calendar-sequential.** The owner watches all triggers at each KB release; unwatched triggers do not fire.

### Iteration 1 — card collection + definition skill (**< 5 person-days**)

| Work | Est. |
|---|---|
| **Select 8–10 questions and adjudicate each card's definition calls** (§5.1) — the real work | 1.5d |
| Build/adapt the cards in Metabase from `dashboards.md`'s ~29 fingerprinted cards; write descriptions naming `M-###` + state + base | 1.0d |
| Plugin scaffold, `plugin.json`, **`marketplace.json` entry**, CI compliance, `gh auth login` | 0.75d |
| Vendor KB snapshot + `manifest.json` (hashes, token estimates, gated loading) + `card-index.json` | 0.5d |
| `SKILL.md`: definition lookup, refusal behaviour, out-of-scope statement for Job B | 0.5d |
| Release step (copy, stamp, semver, CHANGELOG) | 0.25d |
| Reconcile the card set against the weekly report (§10.3) | 0.25d |
| Seed 3–5 users; open the Slack channel | 0.25d |
| **Total** | **~5.0d** |

**Standalone value:** a business user gets a governed number without installing anything, and a PM can ask what a metric means and get the definition, its contested status, and the card that implements it. Neither is obtainable today without reading 2,091 lines by hand.

**Estimate risk:** the 1.5d adjudication row. `GAPS.md` holds **21 `BLOCKED — owner`** entries sitting on exactly the metrics worth carding — `G-001`/`G-002` (two incompatible `<60s` CBDF/CADF semantics both in production), `G-004`/`G-135` (three AOV revenue bases × two date bases), `G-142` (NSM base cannot be isolated). **Under Option F these become card-scoping decisions rather than blockers** — you pick a base, declare it on the card, and move on — which is precisely why Option F fits the week and the original design did not. But you must actually make those calls, and they are yours to make.

### Iteration 2 — the query layer (**trigger: PMs hit the card set's limits — logged as out-of-collection asks in the Slack channel, ≥5 in a fortnight**)

Add SQL generation to the same plugin, composing with `data-tools:query` under an explicit precedence rule: *resolve the definition from the KB before any Data Catalog lookup; the KB's `data-model.md` table list overrides data-tools' MART > CORE > INTERMEDIATE > RAW priority.* Serves arbitrary grain and dimension — the original ask.
**Starts with the §12.1 spike and its kill criterion.** If the spike fails, Option E (§2.2) is the default, not a rebuild.
**Compounding, concretely:** the cards become the verified-query bank the generated SQL is validated against, and the golden set is already written. That is a real mechanism, not an assertion.

### Iteration 3 — Job B (**trigger: iteration 2 stable, plus repeat hypothesis asks**)

Vendor `hypothesis-validation` into the plugin (+0.5–2d). **Compounding:** the definition layer it needs underneath already exists from v1.

### Iteration 4 — PNM (**trigger: PTL shows week-2/3 repeat use**)

Port the governance contract; author PNM's rows; add `skills/pnm-metrics/`.
**Compounding, honestly bounded:** protocol, citation format, manifest machinery, and publishing pipeline are written, so this authors content into an existing frame — **but KB authoring is ~90% of the cost** (PTL: 2,091 lines, still unfinished; PNM's coverage map is 0/167). Real saving, immaterial to total effort. Do not call it "half the cost".

### Iteration 5 — hosted KB / semantic layer (**triggers below**)

- **Hosted MCP** — trigger: *any KB row that changed since a shipped snapshot is queried by a user still on the old snapshot*, detectable from the query log plus §2.3's per-file hashes. *(Draft v1's trigger was conditioned on users detecting a harm the design is blind to, so it could never fire — D-022.)* **Compounding, corrected:** the read protocol carries over intact; the file-based loading layer is exactly what an MCP replaces and gets rewritten.
- **Semantic layer** (dbt MetricFlow) — trigger: golden-set failures traceable to definition ambiguity rather than SQL error. **Compounding (sound as written):** the card set and golden set become the migration's test suite and specification. LookML disfavoured — proprietary syntax turns a future migration into a remodeling project.

### NOT doing now — and what would change our mind

| Not doing | What would change our mind |
|---|---|
| LLM-generated SQL for anyone | Iteration 2's trigger |
| Semantic layer / dbt MetricFlow / Cube | Golden-set failures traced to definition ambiguity |
| Our own MCP server | The iteration-5 trigger above |
| Extending **or** retiring `selfserve_nlq/` | Nothing touches it; it refuses Job A's grains. Not ours to clean up here. |
| HCV | Only after PNM proves the porting template |
| A general-purpose MCP exposing 70+ tools | Never on current evidence |
| LLM-as-judge as primary accuracy gate | Never as *primary*; usable as secondary triage |
| Automated KB→plugin sync | The manual release step proving too slow |
| Broad org-wide launch | Seed cohort showing week-2/3 repeat use first |

---

## 8. Decision 7 — Trust and failure

### 8.1 The core defect, and how Option F changes it

**The problem.** `metrics.md` `M-003` (`ff`) is stamped **`confidence: verified`**. Its own row says:

> ⚠️ `placed = all states` is contradicted by production reporting, which uses a TERMINAL denominator. … The weekly report restricts every fulfilment and cancellation denominator to `state IN (3,4)` … **The KB row holds:** it is card SQL (tier 1) and the contrary claim is tier 5 … Recorded as a **production deviation**, not a correction: *a number computed on one base is not comparable to a number computed on the other.* → `G-161`

Precedence resolution and confidence labelling are **the same signal**. Once the ladder adjudicates, nobody can distinguish an uncontested `verified` row from one that beat a materially different production definition on a tie-break.

**Under the original design this was unfixable at query time** — an LLM would resolve `M-003`, find no live conflict, and emit a clean `verified` label on a number that disagrees with the weekly report.

**Under Option F the adjudication moves to card-authoring time**, where a human makes it once, in the open, and records it. That is a genuine structural improvement — but it is not a solution, and the spec should not claim one. The fix has two parts:

1. **A `contested_by` field (or fourth state) on any row where the ladder overruled a source producing a materially different number.** `M-003`, `T-020`, `T-023`, `T-030`, `T-033`, `T-074` qualify today. The definition-lookup skill refuses-or-shows-both on these. **This changes the KB's governance contract, needs an owner ruling, and belongs in `CONTRIBUTING.md` — which is the other workstream's file.**
2. **Every card declares its base in its description**, in words a non-analyst reads: *"Fulfilment = CO / all-state demand. The weekly report uses a terminal-state denominator; these two numbers are not comparable."* This is the one place the information can live such that it travels with the number — because unlike a chat disclosure block, **a card description is attached to the card wherever it is viewed or shared**.

That second point is why Option F helps here specifically: the original design's fatal gap was that a chat disclosure block does not survive a copy-paste into Slack, while the number does. A card's provenance is part of the card.

### 8.2 Refusal behaviour (definition-lookup skill)

**Refuses when**: the metric is not in the KB · two definitions are in live conflict · the row is `unverified` · the row carries `contested_by` and the user has not been shown both bases · the question needs a grain no card covers **and** iteration 2 has not shipped. If a metric is absent, say so and offer the nearest — never guess.

**Output**: a one-line answer plus the `M-###`, its state, the card URL, and any open `G-###`. The skill never produces a number itself in v1.

### 8.3 The wrong-answer loop — reuse, do not reinvent

`GAPS.md` already exists with a governed append-only format and an established `G-###` scheme.

> user reports a wrong or missing answer in the Slack channel → owner triages → if it is a KB gap it becomes a `G-###` row under existing `CONTRIBUTING.md` rules → next release ships the fix (**card edit, KB release, or both**) → the golden set gains a question covering it.

**No parallel mechanism.** A second gap tracker fragments the one governed record the KB has.

### 8.4 Evaluation

**v1's eval is card reconciliation, not NL→SQL scoring**, because v1 generates no SQL. Every card is reconciled against a known-good source — the weekly report or a fingerprinted card in `dashboards.md` — for the same window, within a stated tolerance (§10.3).

**Deferred to iteration 2**: the 12 golden questions by execution-match. LLM-as-judge is explicitly *not* the primary gate then either — at F1 0.70–0.76 it is wrong roughly 1 time in 4–5.

**Preserve the adversarial property.** The PTL blind-reader test found the KB flagged four of four planted traps and called that its single most valuable characteristic. The definition skill must keep it: ask it a trap question (a dissolved corridor, a cross-config comparison) and it should warn, not answer.

---

## 9. Decision 8 — Adoption

### 9.1 Onboarding the first five

1. **Seed 3–5 named users** — mix of PM and business team, not a broad launch.
2. **The card collection *is* the starter question set.** One artifact, three jobs: gold path, packaged demand (§1.2), and iteration 2's verified-query bank.
3. **Hand-walk the Head of Business's first 2–3 sessions.**
4. **One Slack channel for wrong-answer reports and out-of-collection asks, with a visible owner replying** — simultaneously the adoption signal, the governance signal, **and iteration 2's trigger counter**.
5. **Name a human owner accountable for correctness, not uptime.** [unknown] — not assigned here; owner's call.

### 9.2 Signals

- **Week 1 instrumentation**: card view counts by user; out-of-collection asks in Slack; whether the same user returns within 7 days. Metabase already provides view counts, so this is close to free.
- **Weak signal, do not steer on it**: raw view volume (novelty-inflated ~90 days).
- **Real leading signal**: the *same* person returning in weeks 2–3 to a *different* card, and asks escalating from lookups to decision-support.
- 🛑 **Stop signal**: a contested or wrong number reaches the Head of Business, or is forwarded onward, before a gate catches it.

---

## 10. Iteration-1 acceptance criteria

Falsifiable, each naming an oracle.

1. The Metabase collection exists with 8–10 cards; **every card description names its `M-###`, the definition's state, its denominator base, an owner, and a review date.**
2. **A business-team user who installed nothing opens a card from a URL and reads a governed number.**
3. **Card reconciliation**: each card matches the weekly report or a `dashboards.md`-fingerprinted card for the same window, within a stated tolerance. **Any card that cannot be reconciled ships with that stated on its description, or does not ship.**
4. Plugin installs from `porter-community` in Claude Code and loads the KB with visible `kb_version` + `kb_synced_at`.
5. **A PM who is not the author, on a machine that is not the author's**, asks "how is `ff` defined and which card answers it" and gets the definition, its state, the contested-base warning, and the card URL.
6. `card-index.json` maps every card to an `M-###`, and the release step re-checks that mapping (§2.3).
7. **Metabase collection permissions confirmed** — [unknown] today: who can edit a card, and whether the collection can be made edit-restricted.
8. Refusal verified: an out-of-collection grain produces "not covered in v1", not an improvised answer; a `contested_by` metric produces both bases.
9. 3–5 seed users onboarded; Slack channel open with a named owner; out-of-collection asks being counted (iteration 2's trigger).
10. `gh auth login` completed and the marketplace PR merged.

**Prerequisite before the Head of Business sees anything:** §8.1's `contested_by` ruling made, or every card in the collection carries an explicit base declaration reconciled against the weekly report.

---

## 11. Recommendations adopted from research

| Recommendation | Source | Where it lands |
|---|---|---|
| Verified-query bank as top accuracy lever | research-C — Snowflake VQR docs | §0 — the card collection **is** this pattern |
| Curated views, never raw schema | research-C — Spider 2.0 (arXiv 2411.07763) | §4.2 — moot in v1; §7 iteration 2 |
| Enterprise text-to-SQL is much worse than demos (21.3%) | research-C | §1.3 — part of why v1 generates no SQL |
| Golden questions by execution-match | research-C — Arize | §8.4 — deferred to iteration 2 |
| LLM-as-judge NOT primary (F1 0.70–0.76) | research-C — Arize | §8.4; §7 NOT-doing |
| Semantic layer is late, not first | research-C | §7 iteration 5 |
| Human approval before execution | research-C + research-B | §4.2 — moot in v1; inherited in iteration 2 |
| LLM interface *worsens* ungoverned definitions | research-D — Microsoft Research; arXiv 2502.08554 | §0; §8.1 — the central premise |
| First wrong answer to the exec is project-ending (9/13) | research-D — ScienceDirect | §6; §9.1.3 |
| Seed 3–5 users, not broad launch | research-D | §9.1.1 |
| Starter question set on the gold path | research-D | §9.1.2 — one artifact, three jobs |
| **Put it where users already work; the standalone-login penalty is the biggest friction** | research-D | §4.1 — Metabase needs no install. **The strongest single argument for Option F.** |
| Named owner accountable for correctness | research-D — dsaber | §9.1.5 |
| Showing SQL doesn't help non-SQL users verify | research-D | §6 — v1 shows none |
| Question volume is a weak signal | research-D | §9.2 |
| KB-as-plugin with gated progressive disclosure | research-B — `akshayjain-mbr-brain` | §2.1; §3 |
| Compose with `data-tools:query`, don't rebuild | research-B | §7 iteration 2 |
| No runtime-specific scaffolding | research-B — `data-studio` D8 | §7 iteration 2 |
| Community → central promotion ladder | research-B | §2; the compounding model as infrastructure |
| **"Package the demand, don't ship the primitive"** | research-B — porter-central `data-products/README.md` | §0; §1.2 — **Option F is the response** |
| The harness refuses Job A's grains | research-A | §1.1; §7 NOT-doing |
| PTL is the only KB that exists | research-A | §3; D-007 |
| Governance model is the transplantable asset | research-A | §3 |
| ~29 fingerprinted cards already in `dashboards.md` | research-A | §1.1; §7 — the seed inventory |

---

## 12. Open unknowns and carried risks

| # | Item | Status | Handling |
|---|---|---|---|
| 1 | Cross-plugin composition + precedence over `data-tools`' schema priority | ⚠️ Unproven — **but no longer in v1** | Iteration 2 opens with the spike + kill criterion; Option E is the fallback |
| 2 | **Metabase collection permissions** — who can edit a card, can the collection be edit-restricted | [unknown] — **new risk introduced by Option F** | §10.7, before sharing |
| 3 | **Card/KB divergence** — a card and the `M-###` it cites drifting apart | **New coupling from Option F** | `card-index.json` + release-step re-check (§2.3); §10.6 |
| 4 | `verified` collapsing resolved conflicts | **Confirmed defect** (M-003) | §8.1 — needs an owner ruling on `CONTRIBUTING.md` |
| 5 | Snowflake read-only role, statement timeout, credit cap | [unknown] | Not needed in v1; required before iteration 2 |
| 6 | PTL KB's open owner decision (its D-025: tier-3 evidence rests on a dashboard never opened) | Open in the *other* workstream | Affects which rows are safe to card |
| 7 | `gh` token invalid | Confirmed blocked | `gh auth login`; blocks the PR only |
| 8 | Who reviews marketplace PRs | [unknown] | Unblocked by #7 |
| 9 | Ground truth for contested metrics | **Confirmed absent** — 21 `BLOCKED — owner` gaps | Under Option F these become card-scoping calls, not blockers (§7) |
| 10 | Claude desktop app viability | [unverified] | Moot for v1; live again in iteration 2 |
| 11 | Reconciled gap count (48 vs 66) | [unknown] | Nothing depends on it |
| 12 | **Fixed grains frustrate PMs faster than expected** | **The main risk Option F accepts** | Iteration 2's trigger is a counter, not a judgement call — ≥5 out-of-collection asks in a fortnight |

---

## 13. Verification of this spec

Drafted from four research briefs, then submitted to a **blind red-team agent** given only the stated goal and the finished spec, not the reasoning behind it (D-004). It returned 3 BLOCKING, 5 SEVERE, 7 MODERATE, 3 MINOR findings, spot-checking load-bearing claims against the repo and both marketplace clones.

**Folded in:** all 3 BLOCKING (Job B's absent dependency · the contested-label defect · the D-011/D-012 contradiction), all 5 SEVERE (the inverted porter-central citation · the 2–3× estimate · standalone-value dependencies · two missing packaging options · guardrails-as-intentions), all 7 MODERATE.

**Rejected, with evidence — one finding.** The gate reported `GAPS.md` at 48 rows and concluded "neither number is 66". Its grep pattern counts one of the KB's two gap-table formats; `G-150`–`G-171` are present as rows (`GAPS.md:74` → `| **G-160** | …`), 60 bolded `G-` IDs appear in total, and `CONTEXT.md:161` claims 66. A counting convention, not an error. §1.1 states the ambiguity rather than any single number.

**Then the owner selected Option F at Checkpoint 2** (D-026), which the gate had itself surfaced as an unconsidered option. That pivot removed three of the gate's own findings at the root rather than by mitigation: the composition risk left v1, the estimate came back under the week, and the disclosure-block-doesn't-travel problem became a card description that does.

**Not yet verified:** the pivoted sections (§0, §2, §4, §5, §7, §8.1, §10) have **not** been through a blind gate in this form. A narrow re-gate on those sections is the next step, and this spec should not be treated as reviewed until it runs.

**The gate's closing judgement on the previous design, kept because it is what drove the pivot:** *"Every mechanism in §8 makes a wrong number better documented. None of them stops it."*

---

## 14. Resolved scope calls

- **§14.1 Job B** — owner chose **descope to iteration 3**. No `hypothesis-validation` vendoring in v1. (D-013)
- **§14.2 Scope vs time** — owner chose **Option F**, holding the week. (D-026)
- **Open interpretation, reversible:** whether "plugin deferred to iteration 2" means no plugin at all in v1 (§2.1). Read here as deferring the *query-composing* plugin while keeping the packaging container. **The re-gate says this call was wrong — see §15.**

---

## 15. Re-gate outcome — what is actually true, and the decision needed

The narrow blind gate on the pivoted sections returned **2 BLOCKING, 3 SEVERE, 4 MODERATE, 1 MINOR**. Its verdict: *"Worse as specified — but for a reason that also points at something better than either."*

### 15.1 The two blocking defects in Option F

**1. A Metabase card cannot do what the KB instructs.** `CONTEXT.md` Hard Rule 4, verified verbatim:

> **Week — CONTESTED, ask before running.** Two conventions are live and unreconciled: **Sat→Fri** (`B-031`) and **Sun→Sat** (production weekly reporting). **Any weekly cut must ask the requester which convention they mean before running** — neither side outranks the other (`G-154`).

`G-161` says the same of the fulfilment denominator: *"Both bases are currently defensible … This is a definitional choice, not a discoverable fact — no card read settles it."* Both gaps are **BLOCKED — owner**.

So of §5.1's three "non-negotiable" rules, only **aggregate-then-ratio** and **divide-by-zero → null** are actually settled. The week convention and the denominator are open owner decisions whose prescribed handling is *ask the requester*. **A card cannot ask, cannot refuse, and cannot express uncertainty — it resolves by fiat at author time and presents the result as governed.** §7's line *"you pick a base, declare it on the card, and move on"* overrides the KB's most valuable property: its refusal to fake certainty. An LLM with an approval gate was *capable* of asking and simply had not been built to; a card makes it impossible. That is a worse position, because the first is a prompt fix and the second is an architecture.

**2. §10.3's reconciliation criterion is unfalsifiable.** Its two branches both fail. Reconciling against a `dashboards.md`-fingerprinted card is circular — §7 says to *build* the cards from those cards, and `M-003`'s `source_ref` **is** `card/33485`, the very card whose base disagrees with production. And the weekly-report branch has no data: `business.md` holds only *monthly* snapshots, `unverified`, ~4 months stale. Compounding it, `CONTEXT.md:174` states verbatim: **"No number here has been validated against the warehouse — no query has been run. Nothing is stakeholder-ready."**

### 15.2 The three severe findings

- **Card descriptions do not travel.** §8.1's claim — *"a card's provenance is part of the card"* — was asserted, never verified. A Metabase description sits behind an info icon; it does not survive a **screenshot**, a **CSV/XLSX export**, a **dashboard subscription email**, or a **number pasted into Slack**. What travels is the URL, not the number. The first gate's finding reproduces with one noun swapped. *(Free fix: put the base in the card **title** — `Fulfilment % (all-state denom)` — which survives a screenshot.)*
- **The refusal guardrail is attached to the wrong persona.** §8.2 gives refuse-or-show-both to the *definition-lookup skill*, which only PMs install. The business user — whose number reaches the Head of Business — routes to cards (§4.1) and never touches it. The strongest guardrail in v1 protects the population least at risk.
- ⚠️ **The incumbent already serves more of Job A than v1 does.** `dashboards.md:57` records **`dashboard/4198` — PTL Business Observability, ~82 unique cards, 11 tabs**, filtered by **Start/End Date · Period (Day/Week/Month) · Pickup City · Drop City · Order State · Return Route · Delivery Type**. That filter set *is* Job A — arbitrary grain × arbitrary dimension, in a browser, no install, today. `card/33519` has view counts "in the tens of thousands and rising." **v1's 8–10 fixed-grain cards are a narrower Job A surface than what the business team already opens**, and this spec never once named 4198 as the incumbent.

### 15.3 The estimate, corrected again

§7's table sums to **exactly 5.0d** against a stated constraint of *"< 5 person-days"* — it fails its own bound at zero slack. The gate identified eight unbudgeted items, of which five are **external dependencies on other people**: the `G-154` week ruling, the `G-161` denominator ruling, the `contested_by` amendment to `CONTRIBUTING.md` (*the other workstream's file*), obtaining real weekly-report numbers, and owner go-ahead to execute production queries at all (`CONTEXT.md` Hard Rule 1). Honest range: **7–9 person-days with ≥3 external blockers on the critical path.**

### 15.4 Option G — what the gate proposes instead

> **Write the governed definition, its base, its contested status, and its owner into the incumbent cards people already open, and annotate or archive the duplicates.**

The argument, which is stronger than either previous design's:
- The KB's verified problem is **not** an absent surface. It is that Metabase **already holds three-to-six competing definitions** of every metric that matters — three AOV bases on one dashboard (`G-004`), `4793` contradicting itself on `<60s` (`G-001`), `33485`/`37419` as near-duplicate FF cards — on dashboards with tens of thousands of views. **Adding a governed collection without touching the incumbents creates a fourth opinion in the same tool**, which is the "$400K → 12% adoption" failure this spec cites in §3, caused rather than prevented.
- It puts governance **where the traffic already is** — the literal form of research-D's "put it where users already work", which §11 called the strongest single argument for Option F while proposing a surface nobody currently opens.
- It needs **no plugin, no install, no marketplace PR, and no `gh auth login`** — removing the standing blocker entirely.
- It makes iteration 2 **strictly cheaper**, because the verified-query bank becomes the real card estate rather than ten synthetic cards beside it.
- It is a fraction of five days.

**What it does not do:** it does not resolve `G-154` or `G-161`. Nothing can, except an owner ruling — which is the honest finding underneath all three architectures.

### 15.5 Corrections to facts stated earlier in this document

| Claim | Correction |
|---|---|
| "~29 fingerprinted cards" (§1.1, §3, §7, §11) | **34** distinct card IDs in the fingerprint table, **+9 added 2026-07-30 with no fingerprint** (`G-152`) |
| §5.1 "non-negotiable computation rules" incl. week | Only aggregate-then-ratio and divide-by-zero→null are settled. **Week is contested and must be asked** |
| §8.1's `M-003` quote | Its ellipsis drops the falsifier: the contrary source *"names dashboard 4793 but the KB's own reading of 4793's card 43237 shows an unconditional count, so the claimed reconciliation did not happen (→ `G-168`)"*. That clause is **why** the KB row was allowed to hold. Restoring it strengthens the argument |
| §0/§1.2/§11 on porter-central's README | **Inverted a second time, in the opposite direction.** The same doc warns that over-respecting demand means *"every use case gets its own surface, the system fragments"* and that skills are the *"unit of safe delivery — skills install, use cases don't."* A card neither installs nor versions. Cite it as a tension, never as endorsement |
| §4.2 "blast radius is a card's own query cost, unchanged by who views it" | True only for **fully-fixed** cards. Whether v1's cards are parameterised is an unstated design decision; if they inherit 4198-style filters, a user can set an unbounded range **and switch a Sat–Fri weekly card to Month grain**, breaking the rule §5.1 claims is enforced |
| §7 iteration-2 trigger ("≥5 out-of-collection asks") | **Not observable.** Business users ask the analyst they already ask; PMs blocked by a fixed grain write the SQL themselves in ten minutes. Zero logged asks is ambiguous between "cards suffice" and "everyone routed around them" |

### 15.6 Risks Option F introduced that §12 missed

1. **No named maintainer or version control for the cards.** The plugin has semver, per-file hashes, and a release step; the cards have none — an unreviewed card edit propagates instantly to every viewer with no diff. **The higher-risk half of v1 has the weaker governance.**
2. **No detection path when a card silently breaks.** `dashboards.md` already documents cards that mis-serve — `frequency` unprefixed (`G-026`), hardcoded `category='Business'` defeating the dashboard filter (`G-025`), hardcoded month grain ignoring `{{frequency}}` (`G-024`). View counts and Slack reports catch neither.
3. **The 18 `Q-###` query rules are orphaned** — nothing checks card SQL against them.
4. **Ratios are sometimes computed in the visualisation layer, not in SQL** (`card/33462`: *"raw counts only; no ratio in SQL"*), so "reviewed once in SQL" holds only if every card is authored native-SQL with the ratio inside.

### 15.7 The decision

**This is the owner's call, and it is the third architecture in this document — which is itself a signal worth heeding.** The gate's closing judgement:

> *"The project's own named stop-signal — a contested or wrong number reaching the Head of Business — is not merely unguarded by v1. It is the **expected** outcome of v1 operating exactly as designed."*

**Whatever is chosen, one thing is now established independently of architecture:** `G-154` and `G-161` are owner rulings that no design can route around, and `CONTEXT.md` says no number in this KB has ever been validated against the warehouse. **Those are the real critical path.**

---

## 16. Reopened: why skill/plugin cannot work, and the case for MCP

**Owner challenge, 2026-09-03:** *"want to understand why skill/plugin won't work… MCP server fronting is a potential gate — okay to break frontload as easy to setup MCP and try, thus not too much frontload."*

The challenge is correct on both counts. §2.2's rejection of MCP was built on a misread, and this section supersedes it.

### 16.1 The misread that produced the wrong rejection

§2.2 rejected MCP citing "weeks plus permanent hosting ownership", leaning on `data-tools` v0.6 having deleted its bundled MCP server. Reading that decision's actual design doc (`data-tools/docs/specs/2026-03-26-oauth-design.md`), all three stated problems are about **authenticating to Snowflake** — none is about serving knowledge:

| `data-tools`' stated problem | Does a KB-serving MCP have it? |
|---|---|
| "`uvx` dependency — requires installing `uv`, unfamiliar to non-technical users" (pulls `snowflake-labs-mcp` → `pyarrow`, `cryptography`, ~200MB) | **No.** No warehouse connector. Their own comparison table records Python 3 as "pre-installed on macOS". |
| "No reconnect resilience — VPN blips kill the local process with no retry" | **No.** No persistent connection; it reads local markdown files. |
| "Broken credential caching — browser popups recur on every restart" | **No.** No auth at all. |

**Two in-house precedents already ship this exact pattern**, both in `porter-community` under the `ashwaniporter` namespace: `ashwaniporter-cost-attribution-mcp` and `ashwaniporter-sonarqube-mcp`. The wiring is 8 lines:

```json
{ "mcpServers": { "cost-attribution": { "type": "stdio",
    "command": "${PLUGIN_DIR}/scripts/launch.sh" } } }
```

plus a 23-line `launch.sh`. **A local stdio MCP and a remotely-hosted MCP are different options with different costs, and §2.2 collapsed them into one rejection.** They are separated here as D1 and D2.

### 16.2 Why skill/plugin cannot do the job — the decisive argument

Both blind gates converged on the same defect from different directions, and neither named its cause:

> Gate 1: *"Every mechanism makes a wrong number better documented. None of them stops it."*
> Gate 2: *A card cannot ask, cannot refuse, and cannot express uncertainty.*

The cause is this: **`CONTEXT.md` Hard Rule 4 requires an action, not a disclosure.**

> **Week — CONTESTED, ask before running.** … **Any weekly cut must ask the requester which convention they mean before running** — neither side outranks the other (`G-154`).

Rank the candidate surfaces by what they can actually do with that instruction:

| Surface | What it is | Can it execute Hard Rule 4? |
|---|---|---|
| Metabase card | Saved SQL | **No.** Cannot ask, refuse, or express doubt. It picks silently and looks official. |
| Skill / plugin | **Instruction text in a context window** | **Only probabilistically.** The model may follow it, or skip it under context pressure, or be overridden — `data-tools:query` Step 2A mandates its own catalog lookup and `porter-sql-patterns` writes the SQL, so our rule competes with another skill's protocol in the same window. |
| **MCP server** | **Code with a typed contract** | **Yes, deterministically.** A tool call can return a structured elicitation, refuse with an error, or return `contested: true` with both bases as a typed field the model cannot silently flatten. |

**That is the answer to "why won't skill/plugin work".** Not that a skill is weak at retrieval — it is fine at retrieval. It is that governance stated as instruction is advisory, and this KB's governance is not advisory: it *forbids* answering a weekly question without asking first. Only code can hold that line.

**The corollary is the important part: an MCP server is the only option that can ship BEFORE `G-154` and `G-161` are settled** — because it does not need them settled. It elicits instead of picking, which is precisely what the KB instructs. Every other design has to resolve them by fiat first. **The blocker that stops A, C, F and G is not a blocker for D1.**

### 16.3 All options compared

Decisive column first.

| | Enforces Hard Rule 4 | Serves business team w/o install | Reaches desktop app | Setup | Ongoing ownership | Ships before `G-154`/`G-161`? |
|---|---|---|---|---|---|---|
| **A** — plugin + skill composing with `data-tools:query` | ✗ prompt-level | ✗ | [unverified] | ~5d + unproven composition spike | Low | ✗ |
| **B** — skill over remotely-hosted KB | ✗ prompt-level | ✗ | [unverified] | Hosting cost, no hosting benefit | Medium | ✗ |
| **C** — self-contained plugin, own query flow | ✗ prompt-level | ✗ | [unverified] | 2–3 weeks | High — rebuilds an owned path | ✗ |
| **D1** — **local stdio MCP bundled in a plugin** | **✓ code** | ✗ (install needed) | ✗ (Claude Code) | **~1–2d; 2 in-house precedents** | **Low — no hosting, no auth, no network** | **✓** |
| **D2** — remote hosted MCP / Connector | **✓ code** | **✓ account-level** | **✓** | Days + deploy | **Real — hosting, on-call** | ✓ |
| **E** — fold into `data-tools` (porter-central) | ✗ prompt-level | ✗ | [unverified] | ~5d + central review cycle | Shared | ✗ |
| **F** — Metabase card collection | **✗ cannot ask at all** | ✓ | ✓ | ~5d (est. 7–9d) | Cards unversioned | ✗ — **killed, D-029** |
| **G** — annotate the incumbent cards | ✗ cannot ask | **✓ where traffic already is** | ✓ | **< 2d** | Low | ✗ — must pick a base |

### 16.4 Decision

**Ship D1 first, then G generated from it, then D2 as a transport swap. Reassess the query layer only on evidence.**

**Iteration 1 — D1, the KB MCP server (~1–2 days).** A local stdio MCP bundled in a `porter-community` plugin, exposing a small typed contract over the PTL KB: resolve a metric to its definition, return its confidence *and* contested state as typed fields, list which Metabase card implements it, and — the load-bearing one — **refuse or elicit on a contested cut instead of answering.** No warehouse connection, no auth, no network, no hosting. Two in-house precedents to copy from.

Why first, given "don't frontload": it is the smallest thing that is *not* a prompt, it is the only option that ships despite the blocked gaps, and every later step reuses its tool contract rather than replacing it.

**Iteration 2 — G, but generated rather than hand-written.** Annotate the definition, base, contested state, and owner onto the incumbent cards on `dashboard/4198` and its siblings, and archive the duplicates. **Generated from D1's own output**, so the annotations cannot drift from the KB — which is the coupling risk D-028 flagged when G was to be done by hand. This is what reaches the business team, where their traffic already is.

**Iteration 3 — D2, same contract, hosted.** Stand the same tool surface up at `tools.porter.in` alongside the existing Catalog and Metabase MCPs, so it becomes an account-level Connector. **This is a transport swap, not a rewrite** — provided D1's contract is designed once and honestly. That is what finally reaches non-technical users on the desktop app with no install, which is the thing no earlier step achieves.
*Trigger:* business-team demand that annotation alone cannot serve.

**Iteration 4 — the query layer (A, or E as fallback).** Only if PMs demonstrably hit the limits of definitions-plus-cards.

**Compounding, stated as mechanism rather than assertion:** D1's tool contract is reused verbatim by D2 · D1's resolved definitions become G's annotation text · D1's refusal behaviour becomes the query layer's precondition · the contract is the eval surface throughout.

**What this does NOT fix.** `G-154` and `G-161` remain owner rulings (D-031). D1 makes them *survivable* — the system asks instead of guessing — but every weekly number stays a question until they are settled, and `CONTEXT.md:174` still holds: no number in this KB has ever been validated against the warehouse.

### 16.5 Carried risks specific to D1

| Risk | Status |
|---|---|
| Install still required — D1 does not reach the business team | **Accepted.** That is G's job in iteration 2 and D2's in iteration 3. D1 targets PMs deliberately. |
| Does the Claude desktop app load a Claude-Code-marketplace plugin's bundled MCP? | **[unknown]** — do not assume. D2 is the desktop answer, via Connectors. |
| `setup.sh` / venv friction | `cost-attribution-mcp` needs a venv step. Design D1 for the **stdlib only** so `launch.sh` needs no setup at all. |
| The tool contract is designed once and lived with | The real risk here. A sloppy contract makes D2 a rewrite instead of a swap. **Spend the design effort here, not on features.** |
| MCP tool-count discipline | Keep the surface tiny — a handful of tools, well under the 50-tool ceiling research-C recorded. |
| D1 has never been blind-gated | Neither has G. Gate both before building. |
