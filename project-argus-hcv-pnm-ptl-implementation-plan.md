# Project Argus / Self-Serve Metric Store — Bringing HCV, PnM & PTL Onto It

*Prepared 2026-07-06. Based on the Metric Store Kickoff Pack and Project Argus Doubts/Queries docs (Notion), PR #65 and its onboarding runbooks/backlog (GitHub, porterin/ai-marketplace-central), and the HCV/PnM/PTL product-ops and metrics reference material in this project's folder.*

## 1. What Project Argus actually is, today

Two layers, not one. The **Metric Store** is a set of metric YAML files living in the `DE-DBT-SNOWFLAKE` dbt repo — versioned, PR-reviewed, and served to consumers through a Data Catalogue MCP/UI. Each YAML defines a metric's business logic, ownership, and governance exactly once. The **query-metrics skill** ("`/metric-query`") is the consumer-facing layer on top of it — a natural-language skill inside Claude Code/Cowork/Claude AI that turns "acceptance rate for trucks yesterday" into a governed SQL query and a numeric answer, with a mandatory trust footer (source, freshness, owners, governance version, confidence). This is the literal "AI-based data discovery" surface you're trying to extend into self-serve.

The system checks the Metric Store first: a governed metric returns at **100% confidence**. Falling back to a documented mart/fact table drops confidence to **75–65%**. Staging/raw tables return **55–50%**. Below 50%, the skill refuses to answer and drafts a feedback ticket instead. This confidence gradient is the whole point — it's what makes the tool trustworthy enough for leadership-facing numbers instead of "the AI guessed."

**This already shipped.** PR #65 ("`feat(data-tools): add query-metrics skill (v0.7.0)`", authored by Ravish Jain, reviewed by pradeepd7/maneesh-dh/ambujsingh/arghya-porter, merged by shubham3saini) is live on `main`. It was smoke-tested end-to-end against real Snowflake data — e.g. a real "acceptance rate for trucks" query returned HCV: 0.1635, LCV: 0.1563 from `mart_partner_daily_performance_summary`. A follow-on PR (#67) has since replaced the mechanical SQL templating with a proper MetricFlow integration. So this isn't a pitch for something to build — it's a live tool you need to get your verticals onto.

One important continuity note: **Ravish Jain, who wrote the Kickoff Pack and drove PR #65, shows as "Deactivated" in Notion — he's left Porter.** The program still runs (shubham3saini merged the final MetricFlow work, Samiksha Asati is actively resolving data-contract questions), but you should confirm with Arghya Sarkar or the DD Pod who owns the program now, since Ravish was the one who originally asked you for a sign-off (more on this in §8).

## 2. What's solid vs. what's still genuinely open

Solid: the governance workflow, the metric definition template, the confidence/trust-footer model, the feedback loop, and the platform/user onboarding runbooks are all written, reviewed, and battle-tested against at least one real domain.

Still open, and relevant to you specifically:

- **No domain-disambiguation layer yet (backlog B-002).** A reviewer flagged, using your exact vehicle categories as the example: *"PnM, HCV and Allocation all have an allocation metric with very similar names. The only thing that differentiates them is the domain."* Today the skill has no user-preferences layer to pre-filter by domain — it relies on the question or the metric catalog structure to disambiguate. Since you're bringing three vehicle/product verticals on at once, you will hit this collision directly.
- **Production domain list isn't finalized (B-010).** The `tier_3_enabled` config currently only lists four illustrative domains (Marketplace, Finance, Support-Communication, Allocation). HCV, PnM, and PTL aren't in it yet — someone has to add them.
- **Some semantic-model YAMLs don't match their physical tables (B-012).** Already caused two real bugs during smoke testing (wrong column name, wrong time-dimension type causing silent undercounts). The skill now catches and routes these to the technical owner, but the underlying YAML-quality pass hasn't happened.
- **Amplitude-sourced metrics are unresolved (B-006).** If your funnel/usage metrics (PnM's booking-flow conversion steps, for instance) live in Amplitude rather than Snowflake, the metadata-format story for those is still an open product decision.

None of this blocks you from starting — but it means "getting HCV/PnM/PTL onto Argus" isn't just filling out templates; it's also where a couple of these backlog items will get forced to a decision.

## 3. The case for change: what MBR/ProdOps actually looks like today

This is the part worth being blunt about internally, because it's the strongest argument for prioritizing this.

**PTL** is the starkest example. Its historical MBRs are, in the evaluators' own words, *"heavily narrative and nearly metric-free — the data extract shows 0 structured metrics and 70+ narrative blocks per month."* The diagnosis is explicit: *"PTL does not need better thinking first; it needs better packaging of existing thinking into a structured review format... PTL is weak because its insight is poorly surfaced in the review artifact."* That line is close to a verbatim internal case-for-Argus. The gap register is concrete: only 2 months of visible trend data, an entirely blank Business Viability/unit-economics section (flagged as PTL's most differentiated potential section), no SLOs on any metric, no dashboard links, no "questions from last review" continuity. Meanwhile the underlying analysis is genuinely good — a November cancellation OST (n=428) already decomposed cancellations by cause, allocation time P50 improved from 64 to 20 minutes between October and March — it's just trapped in prose that gets rewritten every month instead of queried.

**HCV** has the opposite failure mode: the review template exists, but the monthly numbers get manually reconciled by hand from separate "MBR Brain" files every cycle — the V1 review document literally ships with blank data cells and a note that actuals were "backfilled from brain files." There's also a real automation precedent here: a 667-line master-instruction file already exists that walks an LLM through turning HCV's raw daily CSV into a finished leadership note, with a hard rule that's exactly the kind of thing a metric store is supposed to enforce structurally ("always aggregate numerator and denominator first, then compute the ratio — never average pre-computed daily ratios"). That's real intellectual investment in getting the logic right; it just isn't wired to a governed store or a query interface yet, and it still assumes someone manually exports and shares a CSV every month.

**PnM** is different again: extensive, well-designed metric instrumentation (funnel latency down to each page, a tiered A/B/C/D vendor-quality system, a whole edit-flow section distinguishing self-service edits from ones support had to handle manually) — but no equivalent gap-analysis document exists for its review process the way it does for HCV and PTL. That's a real blind spot: we know PnM's metric surface area, not its current review pain.

The common thread across all three verticals' data dictionaries: **every single metric row is marked "Status: Pending," ownership (POC) columns are blank, and the "Definition Aligned with STL + Product & Business Director" column is FALSE for every row, in every vertical.** AI-drafted definitions exist for essentially the whole catalog already. What's missing isn't analysis — it's sign-off and ownership assignment. That's the single highest-leverage, lowest-effort unblock available to you.

## 4. How the governance loop works (so you know what you're committing your team to)

Every metric that goes into the store follows the same shape, and it's worth internalizing before you scope anything:

1. **Fill the metric definition template** (business logic, technical formula, source semantic model, grain/dimensions, owner, KPI-tree relationships). One per metric.
2. **Your AM signs off** — this is a hard gate. Nothing generates YAML without it.
3. **Run the plugin** (`/data-studio:document`) to generate the semantic model + metric YAML, then `validate-semantics` for a trust score and CI check.
4. **Raise a PR.** AM reviews business correctness; DD Pod/DE reviews structure. SLAs are 2 business days (AM) and 2+1 business days (AM + DD).
5. **Merge, audit, then verify by actually querying it** — ask the skill a real business question and confirm it routes at 100% confidence.

Before any of that, there's a **deferral policy** worth knowing because it directly protects a lean team from overcommitting: metrics are triaged into (a) clean migration — 1-2 hours per model, model already has clear columns/tests/docs; (b) needs cleanup first — 3-5 hours per model; (c) defer — logged in a debt catalog with one of five tags (Pipeline / Model Readiness / Alignment / Instrumentation / Infra) and revisited bi-weekly; or (d) the Amplitude path for app-event metrics. Critically, there's a **priority × effort rule**: L0/NSM/L1/L2 metrics get built "agnostic of effort," but L3 metrics costing more than a day, or L4/L5 costing more than three hours, get deferred by default. That rule is your friend — it's explicit permission to not build everything at once.

## 5. Getting HCV, PnM and PTL onto this — as a lean team

### 5.1 Before you request a pilot slot

The platform team's onboarding runbook has a binding, three-part gate, and it will stop the process cold if any part is missing:

- A **metric-fluent PM co-owner**, named, per charter.
- An **exec sponsor at Director/VP level** for the thread.
- A **declared willingness to make `/metric-query` the charter's default** for ad-hoc metric questions — not "let's try it."

The runbook is explicit: *"Without all three, the pilot is a tech demo."* Line these up before anything else — this is the actual first step, and it's yours to do as the manager, not something the DD Pod can do for you.

One thing to sort out with the DD Pod/Program Manager before you scope work: **HCV, PnM, and PTL aren't in the illustrative charter list** the arch doc uses as examples (Marketplace, Core Platform, LFC, CGE). And the HCV and PnM data dictionaries already flag several of their own metrics — missed order, stock-out, allocation rate, cancellation/fare-breach/rating metrics — as owned by **"Marketplace"**, **"LFC,"** or **"Core Platforms."** So it's worth explicitly confirming whether HCV/PnM/PTL should register as their own charter(s), or whether they're sub-domains that should coordinate with (rather than duplicate) an existing thread's metric definitions. Get this wrong and you'll build a second, slightly different definition of a metric someone else already owns — precisely the "contested definition" scenario the framework treats as a deferral trigger.

### 5.2 Sequencing: which vertical first

With a lean team, doing all three at once isn't realistic. My recommendation, in order:

**PTL first.** It has the smallest surface area (one product, six months old), the most vivid and best-quantified "before" state, an already-designated North Star Metric (30-day repeat rate — the only one of the three with an explicit NSM tier), and existing executive attention (these gap-analysis docs were written specifically to prep a CTO review). It's the cleanest pilot story: you can point to "0 structured metrics, 70+ narrative blocks/month" today and a structured, queryable, trended review in a defined number of weeks.

**HCV second.** Largest metric catalog and most cross-thread complexity, but also the most "Argus-ready" — its data dictionary already has explicit P1/P2/P3 phase tags for every metric, and the master-instruction file proves the team already thinks rigorously about metric logic for this vertical. It's more work, but less ambiguous work.

**PnM third, with a prerequisite.** Before it's genuinely scoped, someone should write the equivalent product-ops review/gap-analysis document HCV and PTL already have — otherwise you're guessing at PnM's actual review pain rather than working from evidence, the way you can for the other two.

### 5.3 Scoping the work realistically

You are not starting from zero — that's the most important framing for your team. `HCV_Metrics_DD.csv`, `PnM_Metrics_DD.csv`, and `PTL_Metrics_DD.csv` already contain AI-drafted definitions for roughly 100+ metrics apiece, several dozen of which are already tagged with an Implementation Phase for Project Argus (P1/P2/P3/NA). Step 1 of the official workflow ("Metric Listing & Alignment") is largely done in draft form. What's missing is the sign-off and the ownership assignment — not the analysis.

Concretely, for whichever vertical you start with:

1. Filter its DD csv to P1 + L0/NSM/L1 metrics only. Apply the priority/effort rule to defer everything else into the debt catalog with a tag — don't try to migrate the full catalog in one pass.
2. Resolve the cross-thread dependencies flagged in the DD *before* building — if Marketplace or LFC already owns a metric your vertical also uses, get their definition, don't fork one.
3. Get the actual STL + Product + Business Director sign-off on the shortlisted metrics. This is the one step every vertical is currently missing on 100% of rows, and it's a scheduling/alignment problem, not an analytical one.
4. Only then run the plugin (`/data-studio:document` → `validate-semantics` → PR). For a model that's already clean, this is genuinely 1-2 hours of work; budget 3-5 hours per model for anything needing cleanup first.

### 5.4 The platform-team embed, once metrics exist

Getting metrics into the store and getting people actually using them are two different workstreams, and the runbook is precise about the second one — three phases, each with a real exit gate, not a date range:

- **Phase 1 — stress test / eval-set authoring**, before any pilot user is invited in. Your AMs write 15-25 test questions per domain; the platform team holds back 20% as a blind slice you don't see. Exit requires ≥98% pass on the full set and ≥95% on the blind slice. This is also, not coincidentally, exactly the artifact that's needed to eventually flip on tier-3 ("undefined-composed") answers for your domain — see §7.
- **Phase 2 — pilot execution**, roughly two weeks. First 10 real sessions observed, friction logged, at least 3 real feedback tickets raised (not test ones).
- **Phase 3 — domain release**, roughly two weeks. Charter goes fully self-serve; a real decision gets made on whether to enable tier-3 for your domain.

The mechanical setup underneath this: every charter member needs three MCP connectors authenticated (Data Catalog, Snowflake, Slack) and the `data-tools` plugin installed; everyone needs to be added to `#metric-store-feedback` (channel ID `C0B7SJGEAHH`); and a domain-specific `@dd-{thread}-analysts` Slack subteam should exist for triage routing. That subteam almost certainly doesn't exist yet for HCV, PnM, or PTL — creating it is a five-minute task worth doing early rather than discovering it's missing mid-pilot.

## 6. Tying this directly back to MBR / ProdOps

This is where the "tangible output" comes from, vertical by vertical:

**PTL** — the first governed bundle should deliberately include the Business Viability section that's currently entirely blank, since the evaluators already flagged it as PTL's most differentiated potential section. Once GM%, Orders, FF%, Cancellation rate, NPS, Clubbing ratio, and Allocation Time are governed metrics instead of numbers re-typed from prose each month (most of these values already exist, mined out of the historical MBRs in the reference docs — the raw material for a multi-month trend table already exists, it just needs to become queryable), the monthly review stops being a rewriting exercise and starts being a query. Keep the "Monthly Pulse" narrative format (Happy/Concerned/Expect) — it was called out as worth preserving, just relocated out of the metrics table itself.

**HCV** — the win is killing the manual "MBR Brain file" reconciliation step outright. As part of the sign-off push in §5.3, deliberately resolve the six open semantic questions the V1 review already surfaced: the exact definition of `CBDF + CADF − CAC`, whether `ATA` means allocation time or acceptance time, the attribution boundary between Missed Order and Stock Out, whether uptime/latency should cover SOT only or the full allocation stack, whether Unique FF should replace FF% as the primary outcome metric, and whether organic (non-FOS) supply growth needs its own tracked line. These are precisely the ambiguities a metric YAML forces you to settle once instead of re-litigating every month.

**PnM** — commission the missing review-process gap-analysis first. Without it, you don't actually know where PnM's manual-effort pain is concentrated, and you'd be guessing at what to prioritize.

## 7. What this contributes back to self-serve

You asked specifically about adding "semantics and examples for AI-based data discovery" — this maps to two concrete, already-required artifacts, not extra scope invented for the pitch:

- **Glossary/terminology-map entries.** `porter_glossary.json` already has a pattern for exactly this: the colloquial term "trucks" maps to `VEHICLE_CATEGORY IN ('LCV', 'HCV')`. Your team is the natural owner of the equivalent entries for SOT, drop-boundary, CBDF/CADF, clubbing ratio, and PTL/FTL — terms an AI (or a new analyst) would otherwise guess wrong.
- **Golden eval cases.** The 15-25 test questions per domain required for Phase 1 of the embed (§5.4) *are* the "examples for AI-based data discovery" — you're not writing these for a pitch deck, you're writing them because the platform team requires them before your domain can go live at all.

It's also worth explicitly flagging backlog item **B-002** (the user-preferences/domain-disambiguation layer) to the DD Pod. It was raised using your own verticals as the motivating example, and onboarding three vehicle-based charters at once is exactly the forcing function that would justify prioritizing it.

## 8. Decisions that need you specifically, before this moves

- **Close the loop on the April sign-off.** On Apr 28, Ravish Jain tagged you directly — along with Sanjeev Mishra, Sandip Dogra, and Satyavijay D Sawarkar, cc Arghya Sarkar — asking for policy review and sign-off in the Doubts/Queries doc. There's no visible reply from you in the thread, and Ravish has since left. Worth checking whether that sign-off happened elsewhere, or whether it's still sitting open.
- **Charter framing.** One bundled "Supply Verticals" charter covering HCV/PnM/PTL, or three separate charters? Given a lean team, I'd lean toward one bundled application with three domains inside it, but this affects exec-sponsor and PM-co-owner staffing, so it's your call.
- **Pilot order.** I've recommended PTL → HCV → PnM (§5.2) — flag if you'd rather lead with a different vertical for political or resourcing reasons.
- **Slack access.** I couldn't read `#C0A8A8J9WBS` — the Slack connector is linked to your account but not enabled in this chat, and it wasn't logged in via browser either. If you enable it (there should be a connect prompt from this conversation) I can pull that channel's context directly; otherwise, paste the relevant threads and I'll fold them in.

## Sources

- [Metric Store Kickoff Pack](https://www.notion.so/porter-logistics/Metric-Store-Kickoff-Pack-33a9c6eaaa6d80bcba8ddc22da45e719) — Notion
- [Project Argus Workflow: Doubts/Queries](https://www.notion.so/porter-logistics/Project-Argus-Workflow-Doubts-Queries-34b9c6eaaa6d80a59258dccbf25fc9f0) — Notion
- [PR #65 — feat(data-tools): add query-metrics skill (v0.7.0)](https://github.com/porterin/ai-marketplace-central/pull/65) — GitHub
- [Platform-team onboarding runbook](https://github.com/porterin/ai-marketplace-central/blob/main/plugins/data/data-tools/docs/runbooks/2026-06-03-query-metrics-platform-onboarding.md) — GitHub
- [End-user onboarding runbook](https://github.com/porterin/ai-marketplace-central/blob/main/plugins/data/data-tools/docs/runbooks/2026-06-03-query-metrics-user-onboarding.md) — GitHub
- [data-tools plugin backlog](https://github.com/porterin/ai-marketplace-central/blob/main/plugins/data/data-tools/docs/backlog.md) — GitHub
- Internal reference material: HCV/PnM/PTL product-ops review docs and metric data dictionaries (project folder, `01_reference_readonly/migrated_context/`)
