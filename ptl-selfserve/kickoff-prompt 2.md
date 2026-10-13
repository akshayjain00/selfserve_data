# PTL Self-Serve & MBR Automation — Kickoff Prompt

Paste everything below the line into a fresh Claude Code session opened on
`akshayjain00/selfserve_data` (branch `claude/pnm-metrics-catalog-map-vg251i` or a branch cut
from it). Before pasting: authenticate the Notion, Metabase, and Data Catalog connectors.

---

Non-negotiables up front: every source is read-only; NEVER query production data in this
session; this is Iteration 1 ONLY — map, don't build, no code.

<context>
## Carry forward (do not re-derive)
- I'm Akshay (ProdOps, Porter). Repo: akshayjain00/selfserve_data. Completed here: PnM
  self-serve prototype, iterations 1–2 of 3.
- Architecture is LOCKED from the PnM engagement: closed-world metric registry +
  deterministic read-only SQL engine (dry-run default) + AI as translator, investigator, and
  narrator only. The AI NEVER authors SQL.
- House rules carry over verbatim (see <constraints>), plus two standing rules: attach a
  % confidence to every choice you present me; where a governance/Argus rule blocks value,
  present follow-vs-break-temporarily as an explicit choice with costs — never silently comply
  or silently break.
- Reference implementation — you MUST read all four before proposing anything:
  1. pnm-selfserve/HANDOFF.md  (architecture, house rules, decision log, open decisions)
  2. pnm-selfserve/iteration-1-metric-catalog-and-architecture.md  (catalog format; flags carried verbatim)
  3. pnm-selfserve/iteration-2-readiness-ledger.md  (readiness ledger + evidence-table format)
  4. pnm-selfserve/selfserve_nlq/  (working pattern: metrics_registry.py, sqlgen.py, ask.py, run_tests.py)
- PnM lessons to apply proactively (each cost us real time):
  1. Walk the source-of-truth chain FIRST: stated source → Metabase card → physical tables →
     existing dbt/semantic model in the Data Catalog. PnM's script referenced columns that
     don't exist while a governed PROD_ELDORIA dbt layer already had them. PTL's definitions
     come from live Metabase dashboards, so the governed path may exist on day one — establish
     this before designing anything.
  2. Metadata before SQL: verify every table/column via Data Catalog + Metabase metadata
     (schemas, card definitions, lineage) only.
  3. Assess reuse of selfserve_nlq/ — fork for PTL vs generalize into a shared multi-vertical
     engine vs rebuild — and recommend one with % confidence. Flag cross-vertical metric-name
     collisions (PnM/HCV/Allocation have similarly named metrics; Argus backlog B-002).
  4. The map lies: treat every sheet/dashboard definition as UNVERIFIED until checked. Where
     sheet, dashboard, and warehouse disagree, surface the conflict — NEVER pick silently.
</context>

<task>
Replicate the PnM approach for PTL (Part Truck Load), a parallel Porter vertical: transfer the
principles, but re-derive the plan from PTL's own context. PTL's pathology differs from PnM's —
its ProdOps reviews are narrative-heavy with almost no structured metrics, so the win is
structuring prose into governed, queryable metrics, not de-manualizing an existing pipeline.

Resources:
- Notion — PTL Product Ops Review, May '26 (read in full via the Notion connector):
  https://www.notion.so/porter-logistics/PTL-Product-Ops-Review-May-26-3449c6eaaa6d8036bb51d679b6182767
  This is the review whose manual effort we are automating — extract which metrics/sections
  appear in it, and what is narrative vs number.
- Google Sheet — use ONLY the PTL metric tab:
  https://docs.google.com/spreadsheets/d/1Y5_b9okcgKK1gMx-KLv8Zr-7U2Q_kAK26YIgkvF-0jU/edit?gid=279537508#gid=279537508
  It maps each metric → source Metabase dashboard → query/logic → definition → PTL tables used.
  This is your catalog seed; per lesson 4, every row is unverified until proven.

Steps:
1. Read the four PnM reference files, then both PTL resources in full.
2. Build the PTL metric catalog — one row per metric in the PTL metric tab:
   metric | one-line business definition | source dashboard/card | underlying tables |
   verification status (confirmed-via-metadata / unverified / contradicted—conflict described) |
   uncertainty flags carried VERBATIM. Cross-reference which metrics actually appear in the
   May '26 review, and which review sections have no metric behind them at all (PTL's blank
   spots are part of the map).
3. Blind-spot pass anchored to THIS catalog and THIS review — not generic: list what I am
   likely not thinking about, ranked by whether the answer would change the architecture. Put
   the top 3–5 questions that only I can answer at the TOP of your deliverable.
4. Keep a visible running log of judgment calls — what you excluded, assumed, or found
   implausible while mapping. I review the calls, not just the conclusions.
5. Propose the PTL journey. It may legitimately diverge from PnM's map → prototype → extend
   shape (for example: if governed dbt models already back most PTL metrics, iteration 2 might
   target generating the review document itself rather than a query CLI). Lead with what could
   change my mind — definition conflicts, semantic risks, cross-vertical collisions, anything
   stakeholder-facing — and put mechanical detail at the bottom. % confidence on every
   recommendation.
6. Self-quiz on your own catalog: could you defend every definition if a stakeholder pushed
   back? Include the 3 hardest quiz Q&As in the deliverable. An unanswerable one is a finding —
   say so, don't hide it.
7. Commit the deliverables under ptl-selfserve/ and push to the designated branch.
</task>

<constraints>
- MUST create files only under ptl-selfserve/. NEVER edit pnm-selfserve/ or any source
  doc, sheet, or dashboard — all sources are read-only.
- NEVER run a production Snowflake query; NEVER write to any Sheet or Notion page. Connector
  metadata reads are allowed. If a data query ever seems necessary, show the exact SQL and
  STOP for my explicit go-ahead.
- NEVER silently resolve a flagged, unverified, or conflicting table/column/definition —
  surface it with evidence and % confidence instead.
- Readiness defaults to PROTOTYPE-ONLY or BLOCKED. READY FOR STAKEHOLDERS, opening access,
  and formalizing anything as a skill are MY decisions — you produce ledgers and
  recommendations only.
- NEVER average pre-aggregated ratios; NEVER change MTD-vs-locked-month semantics without
  flagging — these numbers feed a real business review.
- Ask before adding any dependency. Only do what this iteration asks — no code, no extra
  files beyond the two deliverables, no refactors, no features.
- Stop and ask before: deleting any file, installing anything, or touching production data.
</constraints>

<stop_conditions>
- STOP after step 7 and show me the catalog + journey proposal + ranked open questions. Do
  NOT write code. Do NOT start iteration 2. Do NOT open anything to anyone.
- STOP immediately and tell me if the Notion, Metabase, or Data Catalog connector is
  unavailable, or if you cannot read the Google Sheet — there is no Sheets connector, so ask
  me for a CSV export of the PTL metric tab rather than guessing its contents.
</stop_conditions>

<output_format>
Two markdown files committed under ptl-selfserve/:
1. iteration-1-ptl-metric-catalog.md — catalog + verbatim flags + judgment-call log + self-quiz
2. iteration-1-ptl-journey-proposal.md — ranked open questions FIRST, then the proposed journey
   with % confidence throughout
Final message: TL;DR of findings first, then a one-line status, then the specific decision(s)
you need from me.
</output_format>

Done when: every PTL-metric-tab row appears in the catalog with a verification status; the top
open questions are ranked and only-owner-answerable; the journey proposal carries % confidence
throughout; zero production queries were executed; zero code was written.
