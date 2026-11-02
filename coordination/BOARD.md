# BOARD — current state & handoff
# Mutable, single-writer (orchestrator). Reference decisions by ID (see D-NNN); do not restate them.
# Done-test: a fresh zero-context agent can continue from this file alone.
Updated: 2026-09-03 09:20 IST (orchestrator)

## Workstream
Design how the self-serve data knowledge base gets **exposed to the wider team** — PMs, the business
team, and the Head of Business — so they can answer day-to-day data needs through Claude Code (Mac
terminal) and/or the Claude desktop app, with Claude reaching Metabase and Snowflake for live results
(see D-001). Two named end-user jobs: build a report/BI view at a stated grain + dimension, and
validate a hypothesis against ground data.

Deliverable: **one** spec at repo root, `DISTRIBUTION-ARCHITECTURE-SPEC.md`, that DECIDES eight things
rather than surveying them — packaging, KB shape, data path, the two job contracts, persona ladder,
iteration ladder, trust/failure loop, adoption. Governing constraint from the owner: **do not
front-load.** Iteration 1 ships in ≤1 person-week and stands alone; each later iteration must state
what it makes cheaper for the next one.

**Status: spec at v3 (PIVOTED), narrow re-gate RUNNING.** All four brief steps have run; the owner then
answered Checkpoint 2 and **changed the iteration-1 architecture**. Deliverable:
`DISTRIBUTION-ARCHITECTURE-SPEC.md` (repo root).

**The pivot (D-026):** iteration 1 is no longer a SQL-generating plugin. It is a curated **Metabase
collection of 8–10 cards** plus a **definition-lookup-only** skill. **No LLM generates SQL for anyone
in v1.** The query-composing plugin moves to iteration 2, trigger-gated.

**2026-09-03 — PACKAGING QUESTION REOPENED AND RESOLVED (D-033 … D-036).** Owner challenged the MCP
rejection and was right. Spec **§16** is now the current decision; §0–§15 are the historical record.
**Decision: D1 (local stdio KB MCP) → G (annotate incumbents, generated from D1) → D2 (same contract,
hosted, becomes a Connector) → query layer only on evidence.** Neither D1 nor G has been blind-gated.

⛔ **GATE #2 FAILED THE PIVOT. v3 (Option F) IS MARKED NOT APPROVED — DO NOT IMPLEMENT (D-029).**
Gate #2 returned 2 BLOCKING / 3 SEVERE / 4 MODERATE / 1 MINOR and judged Option F **worse than what
it replaced**. Three findings were independently re-verified by the orchestrator before acceptance.
It also proposed a **third architecture (Option G)**, escalated to the owner rather than adopted
(D-030). Spec **§15** holds the full outcome and the decision needed; everything above §15 is now
the historical record.

Gate history: #1 → 3 BLOCKING / 5 SEVERE / 7 MODERATE / 3 MINOR; 17 folded in (D-013 … D-023), **one
rejected on evidence** (D-024). #2 → see above.

## Mode
**SEQUENTIAL**, with exactly one bounded PARALLEL fan-out at the research step (see D-003).

## Roster
- **orchestrator (me)** — sole writer of DECISIONS + BOARD + the spec; synthesizes all worker returns.
- research-A *repo inventory* (**done**) — verdict: the KB is transplantable, the harness is not a foundation, and the two end-user jobs are unserved by anything that exists. Findings folded into Shared context below.
- research-B *Porter packaging conventions* (**done**) — found that most of the proposed capability already ships in-house, plus the two-marketplace promotion ladder. Findings folded in below. **Highest-impact brief of the four.**
- research-C *industry practice* (**done**) — 11-pattern table with failure modes + adoption costs; 5 cheap wins, 3 named traps, benchmark figures with transferability caveats. Findings folded in below.
- research-D *adoption & governance* (**done**) — ranked kill list, the inherited-vs-solved split, 5 iteration-1 adoption moves, a governance minimum, and a named stop signal. Findings folded in below.
- blind-gate (**done**) — 3 BLOCKING / 5 SEVERE / 7 MODERATE / 3 MINOR. Spot-checked load-bearing claims against the repo and both marketplace clones. 17 folded in (D-013 … D-023), 1 rejected on evidence (D-024). **Earned its cost decisively** — see Learnings.

Workers return briefs only and write nothing; all four were told not to propose an architecture, so
the design reasoning stays on the orchestrator. Worker budget: 4 of 6 used (brief caps the total).

## Pending / next
1. **Architecture RESOLVED (D-036): D1 → G → D2.** See spec §16. Next concrete step is **blind-gating
   D1 and G before any build** — D-004 still stands and neither has been attacked.
2. **Design D1's tool contract carefully — it is the one thing that must not be redone.** D2 is a
   transport swap only if the contract is right the first time. Spend effort there, not on features.
   Constrain D1 to the Python **standard library** so `launch.sh` needs no `setup.sh` / venv step
   (the friction `ashwaniporter-cost-attribution-mcp` carries).
3. 🔴 **THE REAL CRITICAL PATH, and it is not engineering work (D-031).** `G-154` (week convention:
   Sat→Fri vs Sun→Sat) and `G-161` (fulfilment denominator: all-states vs terminal) are **BLOCKED —
   owner**. `GAPS.md`: *"BLOCKED gaps need an owner decision, not more analysis."* Every architecture
   proposed so far assumed one of these away. **No design can route around them.**
4. 🔴 **`CONTEXT.md:174` — "No number here has been validated against the warehouse — no query has
   been run. Nothing is stakeholder-ready."** Distribution is downstream of this. Hard Rule 1 gates
   production queries on explicit owner go-ahead, which nothing in this workstream has obtained.
5. Owner ruling on `contested_by` — belongs in `ptl-selfserve/kb/CONTRIBUTING.md`, the *other*
   workstream's file. Not amendable from here.
6. Only after the gates and rulings above: rewrite the spec around §16's decision and re-gate it.
   **Do not implement from §0–§15.**

**Owner-flagged deviation awaiting acknowledgement:** see D-006 (this `coordination/` folder vs the
brief's "exactly one new file").

**🔧 Standing blocker:** `gh auth login` — the token is invalid. Blocks the marketplace PR only.

## Shared context (facts the work depends on)
- **Repo root is `selfserve_data/`** at `/Users/akshay.jain/Desktop/AI_V2/ProdOps/selfserve/pnm/selfserve_data`; branch `claude/ptl-metric-catalog-map`. It holds three vertical folders: `ptl-selfserve/`, `pnm-selfserve/`, `hcv_selfserve/`.
### Established by research-A (2026-08-14, evidence-backed)
- **There is exactly ONE knowledge base, and it is PTL's.** `ptl-selfserve/kb/` = 9 files, **2,091 lines**,
  with an ID schema (`B-###`/`M-###`/`T-###`/`G-###`/`Q-###`), per-row `source_ref` + `confidence`
  (`verified`/`unverified`/`assumption`) + `source_updated_at`, a 6-tier source-precedence ladder, and
  CONTRIBUTING.md enforcing append-only IDs and banning `local:` citation. **PNM has no `kb/` directory
  at all. HCV has neither a KB nor a harness — only a coverage-map and an empty `resources/`.** This
  asymmetry all but settles "which vertical ships first", and it makes the KB *governance model* — not
  the KB content — the one directly transplantable artifact.
- ⚠️ **The NLQ harness is NOT a foundation for this project.** It is a single-analyst CLI prototype:
  no NL frontend of its own (it substring-matches `--question` against static aliases and refuses
  ambiguity — the actual language understanding is delegated to the Claude session); `--execute` is
  **gated OFF for PTL** (`STATE_ENUM_CONFIRMED = False`) and there is **no evidence it has ever run
  against live Snowflake for PTL**. PNM's ran once (7 metrics exact-match, 2026-07-08, per its
  DECISION_LOG) — the only recorded live-execution evidence in the repo.
- ⚠️ **Both harnesses REFUSE the exact thing Job A asks for.** They reject non-monthly grains and
  non-registered dimensions (city / route / vendor / weekly / daily / percentile) *by design*. So
  "build me a report at grain X cut by dimension Y" is not a matter of extending the harness — it is
  outside its stated contract. Job B is partially served by PTL's KB epistemics and not at all elsewhere.
- **PTL and PNM harnesses have diverged into two independent implementations** despite a logged
  intent to share a core (PNM `DECISION_LOG` D7, unexecuted). PTL has `core.py` (157L); PNM has none
  and reimplements resolution in a 405-line registry. Porting to a new vertical means re-authoring
  `sqlgen.py` against that schema — [research-A estimate] 1–2 analyst-days per vertical, not mechanical.
- **Tests pass but prove mechanics, not numbers.** PTL 39/39, PNM 31/31 — and both READMEs state
  explicitly that they validate resolver/guard/rendering, never data correctness. PNM's suite also
  only runs under Python 3.12 (crashes on the machine default 3.9.6).
- **The coverage-map JSON schema IS genuinely shared** across all three verticals (same field set;
  PNM/HCV add `classification`/`argus_phase`/`cross_thread`). Reusable as-is, no porting.
- **Shipped coverage is low everywhere**: PTL 14/116 rows shipped (~12%), PNM 0/167 shipped (25
  partial), HCV 0/118 (all pending). [research-A inference — "shipped" is a `status` value being used
  as a stakeholder-ready proxy; no file defines a "coverage %" metric.]
- **Reusable conventions**: the `D-###` decision-log format and single-writer BOARD pattern already in
  `ptl-selfserve/`, and `ptl-selfserve/kickoff-prompt.md` (121L) as a session-bootstrap template.
- **Three questions are known-open and must reach Checkpoint 1**: which vertical ships first; whether the Claude desktop app is in iteration-1 scope; what Snowflake/Metabase access the business team actually holds today.
- **`porterin/*` repos: use the `gh` CLI, never the GitHub MCP** — the MCP authenticates as a non-org account and returns bare 404s. Quote whole URLs (zsh globs `?`).
- **The source prompt for this workstream** is saved at `/tmp/claude-502/copy.txt` (7,411 chars) — it carries the full 8-decision contract, the four worker briefs, and the constraint list.

### Established by research-C (2026-08-14, industry practice)
- **The highest-leverage cheap pattern is the verified-query / query-bank**: curate 15–30 known-correct
  question→SQL pairs the agent searches and *adapts* rather than authoring SQL from scratch. Snowflake
  names this its top accuracy lever for Cortex Analyst. It is pure authoring, no new infrastructure —
  and it maps onto an asset this team already half-owns (`query-rules.md`, plus Metabase card numbers
  already cited throughout the KB). Solves: the LLM mis-authoring joins and business logic.
- **Point the agent at curated views, never the raw schema.** Solves schema-linking error, the dominant
  failure mode on wide schemas. Hours of work if the Metabase models already exist.
- **MCP guardrails are config, not build**: read-only role, row limits, query timeout. Snowflake's own
  managed MCP server caps at **50 tools per server** (stated reason: tool-selection accuracy degrades
  above it) and truncates responses at **250KB** — concrete blast-radius numbers worth copying.
- **Cheapest credible eval loop = 15–20 golden questions scored by execution-match**, run after every
  KB or schema change. ~1–2 days to build. Solves silent drift.
- **Named traps for a team this size**: (1) a full semantic layer (dbt MetricFlow / Cube / LookML) —
  real payoff, multi-week dbt modeling cost, and LookML adds vendor lock-in; that is iteration 3+, not
  iteration 1. (2) General-purpose MCP servers exposing 70+ tools "for flexibility" — more surface,
  worse tool selection, no accuracy gain on a narrow read-only job. (3) **LLM-as-judge as the primary
  accuracy gate** — Arize reports F1 0.70–0.76 and only 76–90% agreement with execution accuracy, i.e.
  wrong roughly 1 time in 4–5. Execution-match must be the primary gate; judge is triage only.
- **The benchmark reality check**: on Spider 2.0 (enterprise workflows, 800+ column schemas) an
  o1-preview code-agent solves **21.3%**, against 91.2% on Spider 1.0 and 73.0% on BIRD. [research-C
  caveat, and it matters: Spider 2.0's shape is much harder than one NL question against a handful of
  curated documented views, so 21.3% is a floor that does not transfer directly — but it is the right
  antidote to demo-grade expectations.] A "semantic layer 83% vs raw text-to-SQL 40%" figure surfaced
  in search but **could not be fetched**, so it is excluded rather than cited.

### Established by research-D (2026-08-14, adoption & governance)
- ⚠️ **An LLM interface WORSENS the two failures that actually kill self-serve BI.** It solves the SQL
  literacy barrier — and that is roughly the only thing it solves outright. It *worsens*: (a)
  ungoverned metric definitions, because a fluent wrong answer is far more persuasive than a dashboard
  tooltip, so conflicting definitions become conflicting confident prose; and (b) overreliance, because
  explanations raise user trust **whether or not they are correct**. It inherits the data-literacy gap
  untouched. **Design consequence: the KB's confidence/precedence machinery is not a nice-to-have here,
  it is the load-bearing mitigation.**
- **The project-ending event is specific and nameable: the first wrong number reaching the Head of
  Business.** Evidence: when an LLM's first answer was wrong, users agreed with it anyway in 9 of 13
  cases. A senior exec generalises from n=1, so one bad number ends the tool for that user permanently.
  Mitigation is cheap — hand-run their first 2–3 sessions rather than letting them cold-start.
- **Cited adoption failure**: a $50M SaaS company spent $400K on augmented analytics; adoption fell to
  **12% in six months** once users hit conflicting metric definitions.
- **The "accountability sink" risk**: self-serve gets tolerated precisely because it lets an org defer
  the harder governance work while looking like progress. Mitigation: a named human owner accountable
  for *correctness*, not uptime.
- **Five cheapest adoption moves, in value-per-hour order**: seed 3–5 named users not a broad launch ·
  put it in a surface they already open (the standalone-login penalty is the largest friction found) ·
  hand-run the Head of Business's first sessions · ship a starter question set mapped 1:1 to the KB so
  early queries hit the gold path · one Slack channel for wrong-answer reports with a visible owner
  replying (doubles as the adoption signal and the governance signal).
- **Governance minimum that is not negligent**: read-only role scoped to KB-covered schemas only · a
  hard per-user daily credit cap, not a dashboard someone might check · query audit log (who asked
  what, what SQL ran) · SQL + definition citation shown with every numeric answer · a defined refusal
  behaviour for out-of-KB questions. Note the honest caveat: showing SQL **mostly does not help a
  non-SQL user verify** — its real value is letting the data team audit fast.
- **Question volume is a weak signal** (novelty-inflated for ~90 days). The signal that matters is the
  *same* person returning in weeks 2–3 with *different* questions, and questions escalating from
  lookups to decision-support. **Stop signal: a contested number reaches the Head of Business or gets
  forwarded onward before any review gate catches it.**
- [research-D could not verify] no named practitioner post-mortem of runaway warehouse cost was found;
  the risk is documented in principle only. Two adoption statistics were dropped rather than cited
  unverified.

### Established by research-B (2026-08-14, Porter packaging) — highest-impact brief
- ⚠️ **`data-tools:query` already implements the end-to-end query path.** NL question → SQL → *mandatory*
  human approval ("This step is mandatory. Never skip it. … Wait for explicit approval") → execute via
  Claude.ai Connectors. Catalog/Metabase lookups are pre-approved as autonomous; only Snowflake
  execution is gated. **The missing piece in the house today is not an engine — it is a governed
  definition layer feeding that engine.** This collapses the scope of iteration 1 dramatically.
- ⚠️ **`akshayjain-mbr-brain` already implements "KB packaged as a Skill for PMs".** It bundles
  `business-context/{pnm,hcv,ptl}/YYYY-MM.md` monthly snapshots (~280KB) inside the plugin with a
  `manifest.json`, and does **user-gated progressive disclosure** — estimates tokens
  (`file_size_bytes/4`) and offers "meta only / latest 3 months / all N months", **never auto-loading**.
  Gap vs this workstream: snapshots are manually refreshed, not live-queried. This is the owner's own
  plugin, so the packaging pattern is already proven in their hands.
- **Two house marketplaces with a documented promotion ladder** — `porter-community` (repo
  `ai-marketplace-community`, 14 plugins, individual contributions) → Team → `porter-central` (repo
  `ai-marketplace-central`, 6 plugins, "authoritative org-wide standards", holds `data-tools`/
  `data-ops`/`data-studio`). A `promotion-guide.md` documents the ladder. **This is the single best
  structural fit for the owner's "don't front-load, compound per iteration" constraint** — ship to
  community under your own namespace, earn promotion to central on evidence.
- **Both repos are already cloned locally** at `~/.claude/plugins/marketplaces/`, so no GitHub access
  is needed to read conventions.
- **Packaging shape**: plugin = `.claude-plugin/plugin.json` (`name`, `description`, `version`,
  `author{name,email}`) + `skills/<name>/SKILL.md` + optional `commands/`, `references/`, README,
  CHANGELOG. Marketplace = `.claude-plugin/marketplace.json` listing `name/version/description/source`.
- **Publishing path (community)**: namespace folder MUST equal your GitHub username (CI-enforced) →
  copy `templates/starter-plugin` → test with `claude --plugin-dir` → PR. An `approval-gate.yml`
  auto-computes reviewers per changed namespace; **you auto-approve changes inside your own
  namespace**; root files need `@ambujsingh`. Semver + CHANGELOG are CI-enforced.
- **Desktop-app viability, with the strongest available evidence**: `data-tools` v0.2/v0.3 bundled a
  local Python stdio MCP proxy (OAuth PKCE, keychain, VPN-fragile, macOS-process-dependent); **v0.6
  deliberately deleted all bundled MCP code** in favour of Claude.ai-hosted **Connectors**, which are
  account-level and shared across web + desktop. Countervailing: `commands/query.md` declares
  `allowed-tools`, and `data-studio`'s decision log D8 calls `allowed-tools` / `Skill` /
  `AskUserQuestion` "Claude Code-specific" — but its stated neutrality target was Claude Code + Codex,
  **never verified against the Claude desktop app**. So: connectors port, command scaffolding may not.
  [This is the sharpest remaining [unknown] and it gates the persona ladder.]
- **House-culture guardrail, worth quoting into the spec verbatim** — `data-products/README.md` in
  porter-central warns against "shipping the primitive instead of the product": *"It sounds like
  semantic layer is LLM. I'll give you Claude Code… I want a user-facing product."*
- 🔧 **Blocked and worth the owner's attention: the `gh` CLI token is invalid** (`gh auth status` →
  "token is invalid"), and unauthenticated fallback hit GitHub's 60/hr limit. Consequence: **who
  actually reviews recent marketplace PRs is [unknown]**. Everything else above came from the local
  clones. Re-auth needed before any publishing step.

## Learnings / caveats
- **Carried in from the PTL workstream, which is the closest prior art in this repo and worth not
  re-learning the hard way:** blind gates repeatedly caught defects that all non-blind review missed;
  the recurring defect class was *verification that cannot detect its own failure* (a check that
  returns clean because it is measuring the wrong thing); and reading a spec and *using* the artifact
  are different tests — its six spec gates all passed things that a zero-context agent using the
  product immediately broke. Whatever this spec proposes for "how a user knows an answer is right"
  should be tested by use, not by review.
- **The KB's known asymmetry constrains what iteration 1 can honestly promise.** PTL's blind reader
  found the KB strong at *"how is this defined"* and near-incapable of *"what is the number"*. The two
  end-user jobs in this workstream are both *"what is the number"* jobs. That gap is the central design
  problem here, not an incidental caveat.
- **Scope discipline is the owner's stated primary constraint.** The failure mode to guard against is a
  complete-looking architecture that never ships, not an under-specified one.

### Learnings from this workstream (2026-08-14)
- **The blind gate earned its cost decisively, again.** Three BLOCKING findings, all real: a v1
  dependency on a skill that ships in no marketplace; a trust mechanism that provably could not fire
  on the case it existed for; and two decisions (D-011, D-012) that were mutually exclusive. None of
  these were catchable by re-reading my own reasoning — which is the entire argument for blindness.
- **The most dangerous defect was the one that looked most like a strength.** Draft v1's §8 was its
  proudest section. The gate's verdict: *"Every mechanism in §8 makes a wrong number better
  documented. None of them stops it."* A confidently wrong number with a complete disclosure block
  passed every acceptance criterion the draft defined.
- **A misquotation can invert an argument.** Draft v1 cited porter-central's "shipping the primitive
  instead of the product" as endorsing this design; the full passage names this design's shape as its
  canonical anti-pattern. Ellipsed quotes from authority documents deserve a full re-read before use —
  especially when they are load-bearing for a rejection.
- **Estimates omit the work you did not think of, not the work you underrated.** The 5→8–10 day
  correction came almost entirely from six *missing* line items, not from any single row being wrong.
  Notably the spec's own "spike this first" risk had no budget at all.
- **A blind gate's findings are evidence, not verdicts.** One of 18 did not survive checking (D-024) —
  a grep pattern that counted one of two table formats. Accepting it wholesale would have written a
  false correction into the spec. Verify before folding in.
- **Two findings needed the owner, not the orchestrator.** Both removed or reshaped stated
  requirements (Job B; the ≤1-week constraint). Escalating beats silently descoping.

### Learnings after gate #2 — the expensive ones
- ⚠️ **I pivoted the architecture on a scope answer without re-checking the new design against the
  KB's own standing rules.** The Checkpoint-2 options I offered were not equally researched: Option A
  had four research briefs behind it, Option F had one line from a blind gate. The owner chose the
  under-researched one on my framing, and it turned out structurally unable to execute
  `CONTEXT.md` Hard Rule 4. **A menu of options is only as honest as its least-researched entry.**
- **The same citation was inverted twice, in opposite directions** (D-032). First quoted as endorsing
  a terminal-first design, then as endorsing a card-first one. That is not a quoting slip — it is
  motivated reading, in both directions. The document was reaching for authority rather than reading
  it. **Stop citing porter-central's README as support at all.**
- **A pivot that removes three risks is not a pivot that removes risk.** Option F genuinely deleted the
  composition risk, the estimate overrun, and the disclosure-doesn't-travel problem — and introduced
  a card that cannot ask, an unfalsifiable eval, no card versioning, and a surface narrower than the
  incumbent it never mentioned.
- **The incumbent was invisible to four research briefs and two spec drafts.** `dashboard/4198` — 82
  cards, 11 tabs, the exact Job A filter set, tens of thousands of views — is recorded in
  `dashboards.md:57`, a file every agent read. Nobody asked "what already answers this question for
  users today?" **Add that question to any future distribution-design brief.**
- **Estimates that land exactly on their own ceiling are failures, not successes.** §7's table summed
  to precisely 5.0d against a "< 5 days" constraint. I wrote and reviewed that table without noticing.
- **Blind gates keep earning their cost, and the second one earned more than the first.** Gate #1
  improved a design; gate #2 stopped one from being built. Neither finding was reachable by
  re-reading my own reasoning — which is the whole argument for blindness, restated twice in one day.
