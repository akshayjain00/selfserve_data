# P2e — Four Missed Sources: Metric Store POV, PnM MBR Automation, Readiness Ledger Diff

Worker: P2e. Read-only pass over 4 sources. No DB queries run. No credentials/PII observed in any source (none to redact).

Access: all 4 sources read successfully.
- `Porter-Metric-Store-—-POV-05-21-2026_04_36_PM.pdf` — 27MB, but only **3 PDF pages total** (each page is a very tall rendered canvas — this is an exported long-scroll doc, not a slide deck; `pages: "1-20"` returned all 3, confirming there is no more content beyond what was read). Text-dense, not image-only — fully readable.
- `selfserve/pnm/queries.py` — 387 lines, read in full.
- `selfserve/pnm/rendered_tpo_202605.sql` — 106 lines (actually the TPO section only — file contains one rendered query, the TPO one), read in full.
- `selfserve/pnm/iteration2readinessledger.md` — 124 lines, read in full, diffed against the 151-line dev copy already on file.

---

## Metric Store POV

Doc header: Program **"Porter Product Argus"**; Audience Directors/VP+, Data, Eng, COO, Founder; status "Preliminary — Federated." Companion to a separate "27 April Metric Store Alignment doc" (not read; PM ownership scope said to live there, not here).

**Core idea (p.1, Executive Summary):** analysts author each metric once with a named owner and a tested definition; consumers ask in plain English via one skill, `/query-metrics`, in Claude Code / Claude Console / Claude AI. The system either returns the exact answer (metric already defined) or shows the computed answer plus a confidence band and its working (assembled from semantic-model parts) — never a silent guess.

**Explicitly out of scope (p.1):** not a BI tool/dashboard, not a data-quality platform (Data Engineering owns upstream reliability), not a single-source-of-truth warehouse replacement.

**Three product principles (p.1, Section 2):**
1. Determinism where guaranteed, transparency where not — defined metrics always produce the same SQL for the same ask; undefined/composed metrics are probabilistic, shown with confidence band + working, refused below a per-domain threshold.
2. Metrics only, not analysis — the store returns metric values; RCA/analysis is a downstream consumer's job, explicitly out of scope for V1 (see Annexure).
3. Adoption is the product — metrics must be embedded in tools people already use (Slack, Claude Code/AI/Desktop), not just published.

**End-state architecture (p.1, Section 3):** a **Semantic Layer platform** with the **Metric Store as a product on top of it**. V1 ships three consumption primitives (`parse_metrics_request`, `query_metrics`, `describe_metrics`) and two authoring primitives (`create_metric`, `edit_metric`). Alerts (`subscribe_metric_alerts`) and collections (`create_collection`/`get_collection`) are deferred to "Next."

**Metric definition format implied by the primitives (p.1):**
- `create_metric` — INPUT: semantic-model name, measures/dimensions, semantic-model SQL. OUTPUT: a PR against the **dbt repo**. GATE: owner approval + PR review.
- `edit_metric` — same shape, diff-based, same PR/review gate.
- `describe_metrics` — OUTPUT fields: **definition, owner, freshness, last-edited**.
- Every `query_metrics` response carries a mandatory "trust footer": **value, freshness, lineage, confidence/disclaimer** (p.2, Section 4, Step 05). Undefined-metric responses additionally show the composition "working."

**Three response-confidence tiers (p.1, Section 3):** DEFINED (exact registry match, ~100%), VARIANT of a defined metric (same metric + a supported filter/dimension cut, ~90–100%), UNDEFINED (assembled ad hoc from semantic-model measures, <70% band, refused below a per-domain threshold). "Dashboard" is explicitly *not* a primitive — a dashboard is a rendering of the semantic layer, never an authoritative definition (p.1 callout).

**Governance model (p.3, Section 9 "Governance & trust"):**
- **Ownership model: Federated** — "Reviewers" (Analytics Managers) decide meaning; "Builders" (Analysts) author definitions; the platform owns the collection, CI/CD, and the registry gate. Rationale: avoids a single bottleneck, scales with team growth.
- **Confidence tier (response level):** three tiers as above, shown inline on every response; silent guessing is disallowed by design; below-threshold asks refuse.
- **Access control (V0):** Snowflake row/column-level ACL preferred over a bespoke gate — warehouse-native ACL is auditable and avoids a parallel permissions path. Marked as a **PoC in progress, not yet committed** (appears again in the "Pending decisions — explicitly open" table on p.3).
- **Access control (Later):** lightweight RBAC layer in front of `query_metrics` if warehouse ACL proves insufficient — not decided.
- **Observability stance:** log structured request/outcome metadata only; explicitly **do not log the raw text of user questions** — an intentional under-monitoring stance to protect user trust.
- **Trust display:** every response shows freshness, lineage, and confidence/disclaimer inline — never silent.
- **Versioning (V0):** every edit is diff-based and goes through PR + CI/CD review; "no blanket revert" language noted but the git/PR history is the version record — no separate versioning datastore in V1.
- **Conflicting definitions rule:** platform default is a hard reject on conflicting definitions rather than silent merge (p.3 table row "Conflicting definitions").

**Pending decisions — explicitly still open (p.3 table):** final per-domain confidence threshold, Snowflake row/column ACL cost model, Slack engineering ownership/Agent SDK POC, distribution to business users beyond Slack, two-phased V1 release, consumer command-name entry point, subscribe-authoring persona, Amplitude's long-term role. None of these are settled — treat the governance model above as directional, not finalized.

**Does it name PTL specifically?** **No.** No occurrence of "PTL," "Part Truck Load," or `partload_application` was found anywhere across the 3 pages. Worked examples reference "Daily Active Partners (DAP)," "Revenue for Trucks," "Allocation time for Bangalore," "Orders" — generic/cross-vertical Porter terms, not PTL-labeled. Section 10 (GTM & adoption) discusses a phased charter/thread rollout across several business domains but does not single out PTL as a named pilot vertical in the visible text. **This is a cross-vertical, Porter-wide initiative — it does not bind PTL by name, but its principles are framed as company-wide defaults ("Argus" is the program name for this exact effort).**

**Target architecture vs. raw-table approach (p.2, Section 7 "Alternates considered"):** the POV explicitly evaluates and rejects "Per-metric SQL template file" (hand-written SQL per metric, no semantic layer) as an alternative — noted as fastest-to-value but weakest on governance/consistency. Chosen direction is a semantic-layer/MetricFlow-style layer with dbt-authored metric definitions, built as "skills + MetricFlow, V1 pilot federated authored metrics on top of existing catalog MCPs Porter already runs." **This is a real conflict with a registry built directly on raw application tables** — see below.

**Kill criteria (p.3, Section 11):** include "<50% of in-scope metrics merged by end of V1 pilot cohort → pause/re-scope," "PR gate pass rate <75% → redesign flow," "p95 latency >5s sustained → kill switch for that domain," "undefined-answer sampled accuracy drops below rolling threshold → kill switch back to dashboards-only." These are Argus-program-level gates, not currently binding on PTL, but indicate the bar this initiative expects once a domain onboards.

**Scope boundary annexure (p.3):** V1 explicitly stops at metric *values*; RCA/"why did X move" is called out as a separate, much larger engineering program (driver trees, contribution/mix-shift analysis, change-point detection, correlated-metric graphs, agent-with-tools) — deliberately not attempted in V1.

---

## Governance/schema requirements that bind a metric KB (summary)

If/when PTL is asked to onboard to Argus, a metric would need, at minimum:
1. A **named owner** (Builder) and a **Reviewer** (Analytics Manager) sign-off.
2. A **dbt-repo-resident definition** (semantic model measures/dimensions + SQL), authored via PR, gated by review + CI/CD — not a hand-maintained registry file outside dbt.
3. A **describe_metrics-compatible metadata shape**: definition text, owner, freshness, last-edited timestamp.
4. Every served value must carry **freshness + lineage + confidence** — silent/undisclosed answers are disallowed by design.
5. A **confidence tier** classification (defined / variant / undefined) with a per-domain refusal threshold for undefined composition.

None of this is currently enforced on PTL (no evidence PTL has been pulled into the Argus rollout), but it is the standard this program is building toward company-wide.

---

## queries.py patterns (PnM MBR automation)

- **Aggregate-then-ratio, confirmed as the pattern in use**: TPO ratios (`tpo_overall`, `tpo_pre_trip`, etc.) are computed as `tickets_X / orders_base` at the aggregated month grain inside a single `monthly` CTE — never a per-row ratio averaged after the fact. Consistent with PTL's own aggregate-then-ratio rule (this is a Porter-wide convention, not PnM-specific).
- **Divide-by-zero → NULL, confirmed pattern**: every ratio uses `NULLIF(denominator, 0)` in the denominator, so a zero denominator yields NULL, never 0 or an error. Matches PTL's rule 3 exactly — good corroboration this is a house-wide SQL convention, not something to re-derive.
- **Dedup via window function**: `QUALIFY ROW_NUMBER() OVER (PARTITION BY o.sr_id ORDER BY o.o_created_ts) = 1` to take the first order per service request. Generic, reusable pattern for "first occurrence per key" dedup.
- **Percentile milestones**: `PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY ...)` for P80 duration metrics across six lifecycle-stage transitions. Standard Snowflake window/aggregate usage, reusable if PTL ever needs milestone-duration percentiles.
- **Staging-table pattern**: two `CREATE OR REPLACE TABLE` staging tables (`pnm_mbr_leads`, `pnm_mbr_orders`) are (re)built every run into `PROD_CURATED.NEW_INITIATIVE_ANALYTICS`, and all downstream metric queries `SELECT` from those staging tables rather than re-joining raw tables each time. This buys consistency across the leads/orders/OTA/TPO/edits queries in one run. **Not directly applicable to PTL as currently scoped** (PTL is read-only against raw `partload_application`; this pattern requires write access to a staging schema).
- **Named-colon SQL parameter binds** (`:month_start`, `:month_start_prev`) are used throughout — **flagged by the readiness-ledger diff (see below) as apparently broken/never validated in production**. Worth a caution if PTL's own query layer uses colon-style bind parameters against Snowflake: verify they actually bind before trusting them, this exact pattern reportedly never completed a real run.
- **Derived-in-application-code pattern**: conversion % and order-mix metrics (Section 4) are explicitly *not* computed in SQL — the file comment says they are "Derived in Python after fetching leads + orders rows" in a separate runner. Worth noting as an alternative architecture choice (ratio computed in the app layer post-fetch rather than in SQL) — differs from PTL's current approach of computing ratios in SQL/Metabase.
- **Month grain via `DATE_TRUNC('month', ts)`, not week**: this automation buckets by calendar month, not PTL's Saturday–Friday week. Not transferable as a convention — just note the difference so nobody assumes PnM's month-grain pattern applies to PTL's week-based reporting.
- **Timezone handling**: no explicit UTC→IST conversion visible in these queries — all timestamps appear to be used as-is (UTC), with no `+330 minutes` shift or `CONVERT_TIMEZONE` calls in this file. Contrast with PTL's mandatory IST conversion rule — if PnM's file is silent on this, it doesn't establish a Porter-wide house rule either way; PTL's own IST-conversion rule stands independent of this file.

## rendered SQL patterns (rendered_tpo_202605.sql)

This is the rendered TPO query only (parameters substituted with `'2026-05-01'` / `'2026-04-01'` literals) — confirms `queries.py`'s `QUERY_TPO`/staging CTEs render correctly as literals when the colon-binds are replaced. No new patterns beyond what's in `queries.py`; it is literally that section's output with substituted literals, referencing tables like `PROD_CURATED.pnm_application.fact_pnm_opprotunity` (note the table-name typo "opprotunity," which the readiness-ledger diff also flags as unconfirmed/possibly wrong).

## Cross-vertical collisions

Checked specifically for: allocation %, CBDF, CADF, CAC, conversion, NPS, GM%, AOV, fulfilment. Found in these 4 files:

| Term | PnM meaning (as used here) | PTL meaning | Collision? |
|---|---|---|---|
| **allocation** | A timestamp/event (`order_alloc.completed_ts`) used only to bucket TPO by month — not a ratio metric in this file. | `allocation %` = allocation / demand, a fulfilment-funnel ratio. | Soft collision — same word, structurally different (event-timestamp vs. computed ratio). Flag if either KB writes "allocation" without qualifying which sense. |
| **conversion** | Referenced in a comment ("Section 4 — Conversion & Order Mix") and in the readiness ledger ("card #30311 is `[DBT] Conversion %`") = orders / leads, Nano-excluded, joined on `customer_mobile`. | No metric literally named "conversion" in the given PTL metric table; `ff` (co/demand) is structurally analogous but not named "conversion." | No direct name collision, but conceptually adjacent — don't let "conversion %" language bleed into PTL docs as if it meant `ff`. |
| CBDF, CADF, CAC, NPS, GM%, AOV, fulfilment | **Not present anywhere in `queries.py` or the rendered SQL.** | Defined in PTL's metric table. | No collision evidenced in these specific files — nothing to flag beyond generic vigilance. |

No fabricated collisions reported — only what's actually in the text.

---

## Readiness ledger diff

**ProdOps copy** (`selfserve/pnm/iteration2readinessledger.md`, 124 lines) is **byte-identical through line ~125** to the dev copy, then **stops**. **Dev copy** (`~/dev/selfserve/pnm-selfserve/iteration-2-readiness-ledger.md`, 151 lines) has everything the ProdOps copy has, **plus an appended section**:

```
## Post-review update (2026-07-07, owner decisions applied)
```

This appended section (dev copy only, ~27 extra lines) records:
1. **Decision 1 → Path A** confirmed (execution on owner's laptop, no production Snowflake touch from that session).
2. **Decision 2 → TPO adaptation APPROVED**: re-point TPO from the guessed `pnm_application.tickets` to `sfms_public.hs_tickets` + `crn` join + `order_status_when_ticket_created` column — applied to `sqlgen.py`, ~90% confidence per Data Catalog evidence.
3. **Decision 3 → `gsheet_client.py` received**; confirms lock/upsert behavior (current MTD row overwritten in place, completed months appended once via `upsert_results`, never touched again).
4. **A new, more severe blocker surfaced (~95% confidence)**: the raw `pnm_application.orders` table is missing `order_id` and the lifecycle timestamps the staging query depends on — those columns are actually assembled only in the **`core.fact_pnm_orders` eldoria dbt model**, not in the raw app table. This means the entire leads/orders/derived/tpo chain **cannot execute against the raw tables as configured, at all**. Recommendation (~85% confidence): re-point to the eldoria dbt models — which "happens to unblock Argus eligibility."
5. Owner sets a **going-forward global rule**: always present choices with an attached confidence %.
6. Pointer to continuation via a `HANDOFF.md` at the `pnm-selfserve` repo root.

**Verdict: the dev copy (151 lines) is newer.** The ProdOps copy is a stale snapshot frozen *before* the owner's post-review decisions were applied — it still shows all three items as open questions rather than resolved decisions, and it doesn't carry the newly-surfaced raw-table-missing-columns blocker at all.

**Does anything here transfer to PTL as a readiness *criterion*?** The ledger's classification scheme (PROTOTYPE-ONLY / BLOCKED / NOT BUILT / READY FOR STAKEHOLDERS, with an explicit rule "open flag or unvalidated answer ⇒ NOT ready") is a clean, reusable **promotion-gate pattern**: no section is called ready until (a) all ⚠ VERIFY flags are resolved with real evidence, and (b) numbers have been validated against a live execution round. This gating discipline is generic and worth adopting for PTL's own registry promotion process, independent of PnM's specific metrics. The specific evidence (missing columns on `pnm_application.orders`, wrong ticket table, etc.) is PnM-only and must not be treated as informative about `partload_application`'s schema.

---

## What transfers to PTL

- The **aggregate-then-ratio + NULLIF-divide-by-zero** SQL pattern, corroborated as a Porter-wide convention (not just a PTL-local rule) by its independent use in `queries.py`.
- The **QUALIFY-based first-row dedup** pattern and **PERCENTILE_CONT** milestone pattern — generic Snowflake techniques, reusable if PTL needs analogous computations.
- The **readiness-ledger promotion-gate discipline** ("no section is ready until every flag is resolved with evidence and numbers are validated live") as a process pattern for PTL's own registry maturity tracking.
- Awareness that **Argus / Porter Product Argus is a live, named, cross-vertical initiative** with a defined governance model (federated ownership, dbt-authored definitions, PR-gated changes, confidence-tiered responses, mandatory trust footers) that Porter is actively building — PTL should know this exists even though it isn't (yet) named as a participant.
- A general **risk pattern, not a PTL-specific fact**: raw application-layer tables can be missing columns that only exist in a governed dbt/eldoria layer — a reason to verify column existence empirically before trusting a hand-built registry against `partload_application`, rather than an indictment of `partload_application` itself (no evidence was gathered about `partload_application`'s actual schema).

## What must NOT transfer

- Any PnM metric **definition or value** as if it were a PTL one: TPO (Tickets Per Order) and its ticket-phase buckets, OTA (On-Time Arrival: ≤30min late AND ≤2km deviation), P80 duration milestones keyed to PnM's own lifecycle stages (`vendor_accepted`, `supervisor_assigned`, `shifting_started`, etc.), order-edit categories (Locations/ShiftingTime/Items/AddOns), leads/orders channel splits (App/Desktop/Mobile/Others), "conversion %" as orders/leads with Nano exclusion, and all the `is_nano` / `intra_city` / `user_flag='normal'` scoping rules.
- PnM's lifecycle stage vocabulary (shifting, trip, pickup) — structurally different from PTL's demand→co/allocation/cadf/cbdf/so/mo/cac funnel; do not map one onto the other.
- The specific ⚠ VERIFY evidence about PnM's tables (`hs_tickets`, `sr_modifications`, `fact_pnm_orders`) — PnM-schema facts only, irrelevant to PTL's own tables.

## Conflicts with current PTL approach

**Yes — one real, blunt conflict.** The Metric Store POV's chosen target architecture is a **dbt-authored semantic layer** (`create_metric`/`edit_metric` output PRs against a **dbt repo**, gated by owner + reviewer approval and CI/CD) sitting under a Metric Store product (`Porter Product Argus`). It explicitly evaluated and did not choose a "per-metric SQL template file" (hand-rolled, no semantic layer) alternative for its own program, citing weaker governance/consistency as the tradeoff.

PTL's current approach — building directly on **raw `partload_application`** with a **hand-rolled metric registry**, deferring a governed dbt layer — is structurally the same shape as the alternative the POV's authors passed over for their own initiative. This is not a rule that *currently binds* PTL (the POV never names PTL, and several of its own governance decisions are still marked "pending/open" even for its own scope), but it is a directional signal: **if or when PTL is asked to plug into Argus, the raw-table + hand-rolled-registry approach will not qualify as-is** — it would need metric definitions moved into dbt with named owners and PR-gated review, per the standing rule referenced independently in the PnM readiness ledger ("no dbt model → not eligible for the metric store"). The PnM team is already facing exactly this fork (keep bug-for-bug on raw `pnm_application` vs. re-point to eldoria dbt models to gain "Argus eligibility") — PTL should expect the same choice eventually, not treat raw-table-based self-serve as a permanent architecture.
