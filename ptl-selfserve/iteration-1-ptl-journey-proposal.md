# PTL Self-Serve — Iteration 1: Journey Proposal

*Prepared 2026-07-09. Companion to `iteration-1-ptl-metric-catalog.md`. Iteration 1 is MAP ONLY —
this proposes the path; it builds nothing. Every recommendation carries a % confidence. Nothing
here is READY FOR STAKEHOLDERS; opening access and skill-formalization remain your calls.*

---

## A. Top open questions — only you can answer these (ranked by architecture impact)

Ranked by whether your answer **changes the architecture**, not by ease. The first four each
fork the design; #5 scopes it.

### Q1 — Source path: build on RAW `partload_application`, or push for the GOVERNED layer? ⟶ changes everything
`fact_ptl_orders` exists (CATEGORY_ANALYTICS-owned) but has **0 measures**, **0 catalog metrics**,
and **no cancellation/allocation/leads/trip sibling models**; 13/14 cards bypass it for raw
`partload_application` (catalog §2–3). This is PTL's version of PnM's "orders source" decision —
but the answer is likely the opposite of PnM's, because for PTL the governed layer is *not* yet
where the numbers live.
- **(A) Prototype on raw `partload_application`, bug-for-bug with the chosen dashboards — RECOMMENDED (~75%).** It's where the review's numbers actually come from; unblocks a working prototype now; quirks disclosed in the footer (the PnM move).
- **(B) Push CATEGORY_ANALYTICS to add measures + build governed cancellation/allocation models first (~25%).** Cleaner long-term and the true Argus path, but it's a **cross-team dependency on a fact you don't own** — slow, and gates the prototype on another team's roadmap.
- *Why only you:* it commits (or doesn't commit) another team's effort, and it's a program-level bet.

### Q2 — Offline-order base: do PTL numbers include the manual `gsheet_sync.ptl_offline_orders`? ⟶ changes every ratio
Cards disagree today: avg-orders/trip, completed-orders and repeat-rate **union offline in**;
effective-FF, AOV, new-users, new-v-repeat **exclude it** (catalog §3.3). Until you rule, PTL has
no single order denominator, so FF/AOV/conversion aren't mutually comparable.
- My lean: **one base, applied everywhere** — most likely "include offline" since PTL is
  operationally-assisted and offline is real GMV, but **~55%**; genuinely your call.
- *Why only you:* it's a business definition of "what counts as a PTL order," not a data fact.

### Q3 — North Star: "Monthly Transacting Business Customers" or "30-day repeat rate"? ⟶ anchors the whole review
Review + sheet say the former (Apr = 2247); the Project-Argus plan says the latter (catalog §1.2).
The NSM anchors the registry's top and the review's narrative.
- *Why only you:* reconciling your own two source documents; I won't pick silently. **Confidence I've stated the conflict correctly: 95%.**

### Q4 — Cancellation canonical definition: dashboard 4793 or card 49366? ⟶ core Marketplace metric
Two parallel CBDF/CADF definitions, no shared model (catalog §3.4). One must be source-of-truth
before CBDF/CADF enter the registry.
- *Why only you:* picking the canonical operational definition is an owner/analytics-lead ruling.

### Q5 — v1 scope: which metrics are in the first governed bundle? ⟶ scopes iteration 2
The sheet's `Important for v1` column is **blank for all 85 rows** (catalog F2). I recommend the
**Snowflake-backed Marketplace + Demand core** (~12 metrics: NSM, completed orders, FF, effective
FF, CBDF, CADF, avg-orders/trip, AOV, session conversion, new business users, M1 retention, time-
to-allocate) — the intersection of "in the May review," "Snowflake-sourced," and "named in the
Argus PTL bundle." **Confidence this is the right v1 cut: 70%.**
- *Why only you:* scope is a priority call, and it decides what ships first to a CTO-facing review.

> **Secondary (I can progress without these, but they'll bite):** (a) MTD-vs-locked-month cadence
> — the "May'26" doc reviews **Apr** data; is the review always "last completed month"? (b) Are
> Finance-owned (GM%, owner earnings) and Core-Platforms-owned (DataDog health) metrics **in scope**
> for ProdOps self-serve, or federated out? (c) Who is the audience, and what triggers "open to
> stakeholders"?

---

## B. Blind-spot pass — anchored to THIS catalog & review (ranked by architecture impact)

What you're likely not thinking about, most-likely-to-change-the-design first:

1. **PTL is multi-source; PnM was single-source. This is the biggest divergence.** Of 85 metrics,
   only ~40 are Snowflake; the rest are **Amplitude (5), Freshdesk/Survey/Manual (≈15), DataDog
   (11), Finance (2), and "Sheets + Others" manual (many).** The PnM "deterministic read-only SQL
   engine" can only ever serve the **Snowflake subset (~half the review).** Any plan that implies
   the engine "answers the review" is wrong unless it also states what it *can't* answer. **This
   should shape iteration 2's scope explicitly.**
2. **A large slice of the review isn't in any queryable DB — it's manual sheets, or no product
   yet.** Batching/allocation (#48–#53), Partner NPS, L4 tickets show `NA` in the review because
   the product/instrumentation doesn't exist. De-manualizing those isn't a data task; it's a
   product/eng ask. The self-serve layer can't conjure them.
3. **You don't own the governed fact.** `fact_ptl_orders` is CATEGORY_ANALYTICS's, not NI_PTL's.
   Any "make it governed" path is a cross-team negotiation — schedule and control risk, not code.
4. **Cross-vertical collision (Argus B-002) is sharper for PTL than for PnM.** CBDF, CADF,
   allocation %, FF, uptime all collide by name with HCV and Allocation. If iteration 2+ ever
   *generalizes* the engine across verticals, disambiguation is unsolved — argues for **forking,
   not generalizing, now** (§D).
5. **Denominator/exclusion landmines beyond offline orders.** The `ptl_internal_users` (~53 test
   mobiles) exclusion is applied **inconsistently** across cards; customer Business/Personal
   classification is read from **two different sources with two different join keys** (catalog
   §3.5); AOV buckets by `updated_at` while others use `created_at` (§3.6). A trend table that
   ingests these as-is will silently mis-stack months.
6. **Trend continuity is already broken in the source.** NPS methodology changed mid-April (Sean
   Ellis → promoter-minus-detractor); April on-time pickup/delivery flagged corrupted. A
   de-manualized trend table **must annotate discontinuities**, or it will look like a real move.
7. **"May'26" reviews April data.** Whatever cadence you pick, the month-basis and the
   created_at-vs-updated_at choice must be explicit in the registry, or MTD-vs-locked-month drift
   creeps in (a house-rule tripwire).
8. **The premise inversion changes the pitch.** Because the review is already structured, the
   demo isn't "we turned prose into metrics" — it's "we reconciled N conflicting definitions into
   one governed, queryable, trended source, and killed the manual monthly refresh." Frame the CTO
   story on **trust + de-manualization**, not on structuring.

---

## C. Proposed journey (leads with what could change your mind)

### What could change my mind (surface first, per your rule)
- **Definition conflicts (catalog §3.3–3.6):** until Q2/Q4 are ruled, the core ratios have no
  single definition — any prototype would encode a guess. **This is why I do NOT recommend
  building a query CLI in iteration 2 before a reconciliation pass.**
- **Semantic risk:** the `state=3/4` enum, the internal-user exclusion, and the customer-key
  drift are all unconfirmed against a data dictionary (catalog F17). Numbers could be subtly wrong
  in ways metadata can't catch.
- **Cross-vertical collision (B-002):** argues against generalizing the engine now.
- **Stakeholder-facing:** the output feeds a CTO-facing review; a wrong reconciled number is worse
  than an honest "unresolved." Default stays PROTOTYPE-ONLY.

### The journey — diverges from PnM's map → prototype → extend

**Iteration 1 (this): Map + conflict surfacing.** Done. 85-row catalog, source-of-truth chain
walked, 7 conflicts + 18 verbatim flags surfaced, review cross-referenced. **Confidence complete
& faithful: 90%** (the −10% is the ~62 unverified rows and the unconfirmed state enum).

**Iteration 2 (proposed): Reconciliation & Definition-Lock — *then* a prototype for the v1 subset.**
Not a query CLI first. Sequence:
  1. **Reconcile the v1 bundle (Q5) definitions** — one ruling each on Q2 (offline base), Q4
     (cancellation), customer key, date-basis — captured in a `DECISION_LOG.md` exactly like PnM's.
     *No code; owner rulings + evidence.*
  2. **Fork the PnM engine** (§D) and encode **only the locked, Snowflake-backed v1 metrics** into
     a closed-world registry + read-only `sqlgen`/`ask.py`, **bug-for-bug with the chosen card**,
     quirks disclosed in the footer, dry-run default, `assert_read_only` guard.
  3. **Readiness ledger** — every section PROTOTYPE-ONLY until an owner-run execution round
     validates real numbers (Path A, your laptop; no prod query from the session).
  - **Confidence this is the right iteration-2 shape: 75%.** The 25% doubt: if you'd rather see a
    tangible artifact sooner, we flip to the alternative below.
  - **Alternative (explicitly on the table):** make iteration 2 **generate the monthly review/trend
    table itself** (the real de-manualization win the Argus plan points to). I recommend *against*
    leading with this (**~35%**) — it would automate the production of the *unreconciled* numbers;
    reconcile first, then generating the doc is nearly free from the locked registry.

**Iteration 3 (proposed): Extend + de-manualize + decide.**
  - Generate the monthly trend table / review doc from the locked registry (the tangible output),
    with discontinuity annotations (blind-spot 6). **~70%.**
  - Decide the governed-layer push (Q1-B) with CATEGORY_ANALYTICS if warranted. **~50%.**
  - Rule on non-Snowflake sources: Amplitude via its connector vs leave-manual; Finance/Core-
    Platforms federated or in-scope. **~60%.**
  - Owner-only: skill-formalization + open-to-stakeholders verdict. *I produce the ledger; you decide.*

---

## D. Reuse recommendation: FORK `selfserve_nlq` for PTL (not generalize, not rebuild) — ~70%

- **Fork (recommended, ~70%).** The PnM engine's shape is exactly right — closed-world registry,
  `assert_read_only`, dry-run default, section-level readiness only you promote, answer-footer
  disclosure. Fork it into `ptl-selfserve/selfserve_nlq/`, and **add one field per metric:
  `source ∈ {snowflake, amplitude, freshdesk, datadog, finance, manual}`.** The SQL engine
  generates only for `snowflake` metrics; everything else is registered but returns an explicit
  "not SQL-servable — source = X" instead of a wrong answer. This makes the multi-source reality
  (blind-spot 1) a first-class, honest part of the menu.
- **Don't generalize into a shared multi-vertical engine yet (~65% that's the *eventual* end
  state, but not now).** B-002 (domain disambiguation) is unsolved; PTL/HCV/Allocation share metric
  names; coupling two immature prototypes would entangle them before either is validated.
- **Don't rebuild (~5%).** Rebuilding discards proven guardrails for no gain.

---

## E. Mechanical detail (bottom, as requested)

**Proposed v1 registry shortlist (Q5, all Snowflake-backed, all in the May review):** NSM
Monthly Transacting Business Customers (#2), Completed Orders–Business (#19), Total FF (#26),
Effective FF (#38), CBDF (#28), CADF (#30), Avg Orders/Trip–clubbing (#46), AOV (#55), Business
Session Conversion (#14), New Business Users (#12), M1 Business Retention (#39), Time to Allocate
P50 (#51, pending a card/source). Each carries: `id`, `domain`, `level`, `definition`, `unit`,
`source`, `card_id`, `underlying_tables`, `verify_flags` (verbatim), `readiness` (starts
`prototype_only`), aliases.

**Proposed file layout (iteration 2, forked):**
```
ptl-selfserve/
  DECISION_LOG.md            reconciliation rulings (Q1–Q5), PnM-style
  selfserve_nlq/
    metrics_registry.py      v1 bundle only; `source` field; verbatim flags; 0 promoted
    sqlgen.py                one read-only SELECT per section; assert_read_only; snowflake-only
    ask.py                   dry-run default; --execute owner-only (Path A); answers_log/
    run_tests.py             dry-run + rendered SQL per section
```

**Non-negotiables carried from PnM (verbatim intent):** AI never authors SQL; closed-world refuse
off-menu; ratios from raw counts, never averaged; MTD labeling flagged; dry-run default; no new
deps without asking; section readiness owner-promoted only; every choice carries % confidence;
governance-vs-value blocks presented as explicit follow-vs-break choices.

**What iteration 2 will NOT do:** touch production data (Path A only, exact SQL shown first);
open access; formalize a skill; build non-Snowflake source connectors; generalize across verticals.

---

## F. Maker–Checker addendum (2026-07-09)

*Added after a manager-orchestrated Maker–Checker pass. The maker = iteration-1 above. A Checker
critiqued it; two subagents were dispatched to research existing implementation + industry
practice (the existing-impl agent was blocked by a macOS file-access sandbox on `~/Desktop` and
its role was absorbed by the manager from prior deep-reads; the research agent completed). Still
iteration-1 map scope — no code, no new deps, no new files.*

### F.1 Checker findings (ranked; most severe first)
| # | Sev | Flaw | Fix |
|---|---|---|---|
| C1 | **Critical** | "confirmed-via-metadata" reads as "green" but only confirms card existence + lineage, not that any number is right. | Rename to **`lineage-traced (unvalidated)`**; reserve "confirmed" for post-reconciliation numbers. |
| C2 | **Critical** | Reconcile-first sequencing risks paralysis; the real critical path is other teams' roadmaps (CATEGORY_ANALYTICS / Finance / Core Platforms). | **Decouple**: ship an *exposing* prototype (emits both offline/online bases & both cancellation defs side-by-side) **in parallel** with reconciliation. The demo value is exposing conflicts, not hiding them. |
| C3 | **High** | Multi-source is an architecture risk, not a coverage footnote: ~45/85 metrics (incl. NPS, GM%, on-time, batching) can't be SQL-served. "Register but refuse" is a hollow menu. | Add a **`passthrough/attest`** source type — surface last-known manual value + provenance + staleness, not a refusal. |
| C4 | **High** | The seed Google Sheet is itself unversioned, column-shifted (8 rows), single-owner. Mirroring it inherits its fragility. | The **git-versioned registry replaces the sheet as source of truth**; the sheet is a one-time input. |
| C5 | **High** | "Fork, don't generalize" invites N rotting registries; shared guardrails won't get bugfixes. | **Shared engine core (imported) + per-vertical registries (forked)** — factor guardrails/CLI/SQL-safety/harness into a shared module now; only metric *data* is per-vertical. |
| C6 | **Med** | Consumption model never established (generated Notion doc? live queries? cadence? audience?). Could re-order the whole journey. | New **Owner Q0** (§F.5). |
| C7 | **Med** | `orders.state` enum (3=completed/4=cancelled) assumed across all FF/CBDF/CADF but only flagged, not prioritized — and it's the cheapest thing to confirm. | Make confirming the enum the **#1 pre-work item**. |
| C8 | **Med** | 62/85 unverified with no per-source verification *plan*; manual-sheet metrics are unverifiable by metadata at all. | Add a per-source verification plan; state manual metrics need *process*, not queries. |
| C9 | **Low** | Some % confidences are decorative. | Attach an evidence basis to each %, or drop it. |

**Single most important change:** reframe from *"query CLI"* → *"governed metric register that
exposes conflicts, serves the Snowflake subset read-only, and attests the manual rest"* — and
**ship it exposing conflicts rather than gating delivery on resolving them** (fixes C1+C2+C3).

### F.2 Reuse verdict (from deep-read of `selfserve_nlq/`)
- **Fork verbatim:** `assert_read_only`, dry-run-default CLI, trust footer, section `readiness`
  model, resolver refusal logic, `funnel_sql`'s derive-ratios-in-Python-from-raw-counts.
- **Breaks for PTL:** single-source assumption; leads/orders/derived/tpo section shape; eldoria
  re-point; single-month window (PTL needs the 7-month trend).
- **Verdict:** registry = fork-with-changes (add `source` + MetricFlow schema + governance
  fields); SQL engine = **extract shared core** + PTL templates (the C5 fix); harness =
  fork-with-changes (add metamorphic + reconciliation + golden).

### F.3 Research-backed recommendations (adopt into the spec; sources cited)
The locked architecture matches where the field landed in 2024–2026. Prioritized:
1. **[adopt-now]** Shape each metric like **dbt MetricFlow** (`type/agg/numerator/denominator/agg_time_dimension`) → aggregate-then-ratio becomes structural; export later is mechanical. *(docs.getdbt.com/docs/build/metrics-overview)*
2. **[adopt-now]** LLM contract = **resolve→gate→refuse**, never a text-to-SQL fallback (grounding ~40%→~83%, 100% in-scope; fallback reintroduces silent drift). *(dbt SL-vs-text-to-SQL 2026; omni.co/blog/why-text-to-sql-fails)*
3. **[adopt-now]** Add **sqlglot AST validation** (single-statement + root-is-SELECT + table allow-list) beside the regex; parse-failure ⇒ refuse. *(github.com/tobymao/sqlglot)*
4. **[adopt-now]** Enforce a **read-only Snowflake role** — the boundary a bypassed string check can't defeat.
5. **[adopt-now]** Formalize **maker–checker**: engine renders → owner approves → ship (Airbnb Midas-style certification).
6. **[adopt-iteration-2]** Unit fixtures + **metamorphic invariants** in the harness.
7. **[adopt-iteration-2]** **Reconciliation harness** (engine vs trusted card) + **golden frozen month**.
8. **[consider-later]** Governance fields (`certification`, `owner`, `version`, `deprecated_on`) surfaced in every answer. *(ODCS v3.1.0; dbt model versions)*

### F.4 Verification strategy (six-layer ladder; no production queries)
- **L0 Triangulation (map):** sheet-def vs card-SQL vs warehouse-schema vs review's published number must agree. First move: **confirm `orders.state` enum**.
- **L1 Logic:** hand-computed unit fixtures per ratio; property tests (`ff∈[0,1]`, `co≤demand`, ÷0→null); fuzz the read-only guard.
- **L2 Metamorphic (no oracle):** `CBDF+CADF ≤ total cancellations`; weekly sums→monthly; partitions reconstruct total; aggregate-then-ratio invariance.
- **L3 Differential:** normalize engine SQL **and** source card SQL to sqlglot ASTs and diff (fidelity before any run); then diff results (owner-run) vs the card per cut.
- **L4 Back-test against the review's own 7-month history (free oracle):** the engine must reproduce Oct-25→Apr-26 published values per v1 metric. **A metric that can't reproduce its own review history is not stakeholder-ready.** This is the acceptance test.
- **L5 Adversarial NL eval:** golden question set (15–25); each resolves to the right `metric_id` **or refuses**; track resolution accuracy *and* false-answer rate.
- **Conflict-exposure test (novel):** for any unresolved-conflict metric, assert the engine emits **both variants side-by-side with the flag** until the owner rules — an automated proof we never silently pick. All under maker-checker.

### F.5 Re-evaluated way forward + new owner question
**Reframed product (80%):** a git-versioned governed metric register that (a) exposes conflicts,
(b) serves the Snowflake subset read-only (dry-run + sqlglot + role guard), (c) attests the
manual/Amplitude/DataDog/Finance rest with provenance + staleness, (d) is back-tested against the
review's own history, (e) ultimately generates the monthly review — under a maker-checker gate.
**Re-sequenced:** pre-work (confirm state enum; extract shared engine core; add `source` +
MetricFlow schema) → **Track A reconciliation** and **Track B exposing-prototype in parallel**
(Track B ships without waiting on Finance/CATEGORY_ANALYTICS) → verification L0–L4 wired in, L4 =
promotion gate → iteration 3 generates the doc + governed-layer / non-SQL-source decisions.

- **Q0 (new, prepend to §A) — Consumption model & cadence:** generated monthly review doc
  (Notion), live ad-hoc queries, or both? May re-order the entire journey. *(Only you can answer.)*
