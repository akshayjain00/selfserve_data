# The PTL Knowledge Base — a walkthrough

*For anyone joining PTL self-serve analytics. No prior context assumed. ~10 minute read.*

---

## 1. Why this exists

PTL — **Part Truck Load**, Porter's intercity vertical where several customers' consignments share
one truck — is roughly six months old and **pre-PMF** (before product–market fit; the product is
still changing shape). Its monthly Product Ops review is written mostly in prose, with numbers
pasted in from various dashboards.

That works right up until someone asks a simple question:

> *"How exactly is fulfilment calculated?"*

Then you discover the answer lives in four places, all of which sound authoritative:

| Where | What it gives you |
|---|---|
| The monthly review (a Notion doc) | a number, no formula |
| The metric catalogue (an earlier mapping exercise, 85 rows) | a one-line definition |
| The **prototype engine** — `selfserve_nlq/`, a small read-only Python tool that generates SQL for a fixed list of metrics | an actual SQL formula |
| The Metabase card SQL (the query a dashboard tile really runs) | a *different* actual SQL formula |

Nobody is wrong on purpose. Definitions drifted, and there was no single place where the real one
was written down with evidence attached.

Here is the number that captures the stakes:

> ### 🔢 70 of 85
> **When the metric catalogue audited PTL's 85 tracked metrics, only 15 could be confirmed against
> the SQL that produces them.** 6 came back *contradicted* — sources actively disagree. 64 were
> never checked at all. That leaves **70 of 85 not confirmed.**

The knowledge base is where that gets fixed — one metric at a time, with receipts.

### Two different cuts of the same 85 — don't confuse them

This trips people up, so it's worth being explicit. The 85 metrics carry **two independent
statuses**:

| Cut | What it measures | Breakdown |
|---|---|---|
| **The catalogue's audit** (done before this KB) | did anyone ever check this against SQL? | 15 confirmed · 6 contradicted · 64 unverified |
| **This KB's coverage** (what we've written up) | has this KB documented it in depth? | **23 rows in full** (20 M-numbers — 2 close more than one row) · 62 index-only |

That second row moves — it's a live number, not a historical one. 23+62=85; see §8 for what's changed and why.

They are **orthogonal**, not two versions of the same number. The 11 we wrote up in full are the
metrics leadership steers by; they are not the same set as the 15 the catalogue happened to confirm.
A metric can be catalogue-confirmed but not yet written up here, or written up here and still
unverified.

---

## 2. The architecture, in plain language

**It's built like a reference desk, not a textbook.** You never read it cover to cover. You arrive
with a question, and the front desk sends you to the right shelf.

```
                    ┌──────────────────────────┐
   your question →  │      CONTEXT.md          │   the front desk
                    │  "what do you need?"     │   (~150 lines, always read this first)
                    └────────────┬─────────────┘
                                 │ routes you to the shelf you need
     ┌───────────┬───────────┬───┴───────┬────────────┬──────────────┐
     ▼           ▼           ▼           ▼            ▼              ▼
 business.md  metrics.md  data-model  dashboards   GAPS.md   CONTRIBUTING.md
 what PTL is  formulas    tables &    which card   what we    how to change
 & jargon     & sources   columns     & how fresh  don't know  the KB safely
```

Two design choices make it work, and both are worth understanding:

**One — the front desk stays small.** `CONTEXT.md` is capped at 150 lines, deliberately. It holds
the index, the routing table, and the handful of facts that prevent most errors. Everything else
loads only when needed. This isn't tidiness: when an instruction file grows too long, readers —
human or AI — start losing the rules inside it. A small entry point is a *functional* requirement.

**Two — every fact is a row with a receipt.** Not prose. A row:

| id | statement | source_ref | confidence |
|---|---|---|---|
| `T-001` | `orders.state`: `3=Completed`, `4=Cancelled` | `metabase:card/33519` + 8 cards on **db73** (one of two Metabase connections to Snowflake; most PTL metrics live on db73) | `verified` |

That shape buys three things at once. Facts become **addressable** (`T-001` is quotable and
citable). Corrections become **surgical** — fix one row, not a paragraph. And two people editing
different rows produce a **clean merge** instead of a conflict.

The ID prefix tells you which file a fact lives in: **`B-`** business/glossary · **`M-`** metric
definitions · **`T-`** tables & columns · **`G-`** gaps. IDs are never reused or renumbered, so a
citation written today still resolves in a year. (`dashboards.md` is the exception — its rows are
keyed by the Metabase card number itself, e.g. `39117`, since that's already a stable identifier.)

---

## 3. How to use it

**If you're using Claude Code or any AI assistant:** point it at `kb/CONTEXT.md` and ask your
question in plain English. The load protocol tells it which file to open next.

**If you're reading it yourself:** open `CONTEXT.md`, find your question in the routing table, go to
that file.

| Your question | Where it takes you |
|---|---|
| "What does CBDF mean?" | `business.md` — glossary |
| "How is fulfilment calculated?" | `metrics.md` — the formula plus its caveats |
| "Which table holds order state?" | `data-model.md` |
| "Where does this number come from?" | `dashboards.md` — the card, and when it last changed |
| "Is this still true?" | `CONTRIBUTING.md` §5 — the staleness check |
| "What don't we know?" | `GAPS.md` |

**The one habit that matters:** when you quote a fact, quote its ID. "Completed orders is
`COUNT(DISTINCT external_id) WHERE state=3` (`M-002`, verified)" is a different claim from the bare
formula — the first can be checked by the next person, the second can't.

---

## 4. How a fact earns its confidence

Every row in this KB carries one of **three** labels:

| Label | Means | Bar |
|---|---|---|
| `verified` | read directly from the SQL, the code, or an explicit owner ruling | you saw the expression |
| `unverified` | a source asserts it, but it isn't confirmed — or sources conflict | anything you didn't check |
| `assumption` | you worked it out; it's stated nowhere | say so |

> ⚠️ **Two words you'll see that are NOT confidence labels.**
> **`contradicted`** is the *metric catalogue's* own wording for its 6 worst rows, and it predates
> this KB. When one of those rows gets written up here it becomes `unverified` with both conflicting
> sides recorded.
> **`stale`** is a *freshness* state, not a confidence one (see §6). A row can be `verified` **and**
> stale — meaning it was correct when checked, and its source has changed since.

**A card title is never evidence.** A Metabase card called "Fulfilment %" tells you what someone
*intended*. Only its SQL tells you what it *computes*, and on this project those diverged more than
once.

When sources disagree, there's a fixed ladder:

```
observed card SQL  >  owner rulings (D1–D7)  >  metric catalogue  >  proposal docs  >  the review
```

**D1–D7** are seven decisions the PTL metric owner locked in writing — things like which dashboard
is canonical for cancellations, and what the North Star actually is. They live in
`repo@7a43470:ptl-selfserve/DECISION_LOG.md`.

*(This is not a contradiction with `G-133` in §9, which says no metric has a named owner. One person
made these seven programme-level rulings. What's missing is **per-metric ownership** — a named
person accountable for each individual metric definition, which the Metric Store programme requires.
Rung 2 exists; it just doesn't scale to all 85 metrics.)*

**What the ladder is for, and the one thing it is not for.** Use it to decide which source to
*believe* when they cover the same ground with different detail. Do **not** use it to overrule a
direct head-on contradiction between the top two rungs: if observed SQL contradicts an owner ruling,
you record **both sides**, mark it `unverified`, and open a gap. Silently choosing converts a
*known* unknown into an *invisible* error — and an invisible error in a KB is worse than no KB,
because it looks right.

---

## 5. What it found — following the North Star

Here's the whole method in one worked example.

**The North Star Metric** — the single number PTL is steered by — is *monthly transacting business
customers*: unique business customers who completed at least one PTL order that month. The May-26
review reports **2,247** for April, up from **1,879** in March.

**Step 1 — find what computes it.** Nothing obvious did. The prototype engine registered the metric
but emitted no column. No card on the Customer Dashboard carried it as a headline tile. A number was
going to leadership with no traceable source.

**Step 2 — look harder.** Card **39117** ("Business Customer Distribution") turned out to compute
the right shape: `COUNT(DISTINCT customer_mobile)`, filtered to business customers, completed orders
only, grouped by month. *(Note the proxy: it counts distinct mobile numbers, not customer records.
One business using two numbers counts twice. That's not wrong, but it isn't literally "customers" —
worth knowing before you quote it.)*

**Step 3 — actually run it.** Not read it — run it, for March and April 2026:

```
metabase.prod-internal.porter.in/question/39117   (Snowflake connection db73)
parameters: frequency=Month · start_date=2026-03-01 · end_date=2026-04-30

2026-03-01    ACTIVE_CUSTOMERS = 1879      review said 1,879   ✓
2026-04-01    ACTIVE_CUSTOMERS = 2247      review said 2,247   ✓
```

An exact match on both months. You can re-run this yourself — it's a saved card, and those are the
exact parameters. **Two months is strong evidence, not proof**; a third month would make it
near-certain. *(Card 39117's "fingerprint" — the timestamp Metabase records when the card was last
edited — was `2026-07-14T10:37:29Z` when this was checked. If it reads newer now, someone has edited
the card and this result needs re-running. That's the staleness rule in §6, applied to itself.)*

**Step 4 — and here's the part that matters.** Because the match is exact, the reported figure is
almost certainly produced by this card — which means it inherits this card's defects. And the card
has one: its internal-user filter is applied only to the online orders. The offline leg — orders
synced from a Google Sheet — has **no such filter**.

> **The North Star reported to leadership includes Porter's own internal test orders.**
> It is inflated by an unknown amount. That's gap `G-141`, and it was invisible until the number
> reconciled.

That's the pattern the whole KB is built around: *verifying a number doesn't just confirm it — it
tells you what else you've been believing.*

Three more findings from the same method:

- **CBDF and CADF** (Cancelled Before / After Driver Found) do not exist on "PTL Business
  Observability", the dashboard we were told was canonical. All 11 of its cancellation cards use a
  flat `state = 4` filter with no driver split. The real definitions were on a different dashboard
  (4793); the card IDs are listed in `dashboards.md`.
- **Three cards show date filters that do nothing.** Cards **47540** and **48449** hardcode
  `pickup_date >= '2026-02-01'`; card **49365** returns *empty* rather than erroring if you pick an
  earlier start date. You set a filter, get a plausible number, and it answers a different question
  than you asked.
- **"Fulfilment excluding 60-second cancellations"** exists in two incompatible forms in production —
  one drops those orders from the denominator, the other from the numerator only. Both are live.

---

## 6. How to maintain it

Full protocol is in `CONTRIBUTING.md`. Four rules carry most of the weight:

**Never add a fact without a source.** A statement you can't attribute isn't a KB fact — it's a
`GAPS.md` entry. That's not a lesser outcome; a well-written gap is genuinely useful.

**Cite by commit SHA, never by file path.** Write
`repo@7a43470:ptl-selfserve/DECISION_LOG.md#L18`, not `DECISION_LOG.md`. Here `repo` means
**`github.com/akshayjain00/selfserve_data`** and `7a43470` is the commit. Branches get merged and
renamed, line numbers shift, local paths differ per machine. A SHA can't drift — the next person
reads the exact bytes you read.

**Check staleness before trusting a row.** Rows sourced from a Metabase card carry that card's
`source_updated_at` — the timestamp Metabase records when anyone edits the card. We call storing
that timestamp **fingerprinting**. If the card's current timestamp is newer than the one in the row,
someone edited the card and the row is **stale** — re-check before quoting. This is a manual lookup
today, not an automated alert: one metadata call per card, no query run. All 29 cards the KB depends
on are fingerprinted, so the check is cheap; remembering to do it is the hard part.

**Downgrading confidence is always allowed. Upgrading needs new evidence, cited.** Two unverified
sources agreeing is still unverified. Time doesn't promote a fact.

> **Honest caveat.** Every rule above depends on individual discipline. There is no linter, no CI
> check, no review gate enforcing any of it — and the drift this KB exists to fix was itself a
> discipline failure. If these habits don't stick under deadline pressure, the KB decays into
> exactly the thing it replaced. Building a check that flags stale rows automatically is probably
> the highest-leverage improvement available.

---

## 7. How to enhance it

`GAPS.md` is not a list of failures — **it's the backlog**, already prioritised. Every row names a
next action specific enough to execute. Three ways to add value:

**Deepen accuracy.** Take an `unverified` row, read the underlying SQL, promote or correct it. The
6 rows the catalogue marked `contradicted` are the highest-value targets — those are metrics whose
sources actively disagree, so someone may be reading a wrong number today.

**Widen coverage.** 23 catalogue rows have full treatment (20 `M-###` entries — two close more than
one row each); **62 are index-only** — a name and a pointer,
nothing verified here. Each has a gap row waiting. Pick one, trace it to its card, write it up.

**Close the structural gaps.** These are grind, not judgment — nobody needs to decide anything, they
just need doing. 93 dashboard cards were never opened (all listed, with reasons). The `orders.state`
labels for `0/1/2`, and the weight grams→kg conversion, are still confirmed on only one of the two
Snowflake connections. *(For scale: the KB draws on 29 cards spread across four surfaces — dashboards
**4198** "PTL Business Observability", **4569** "Customer Dashboard", **4793** (cancellations), and
the standalone card **33519**. The 93 unopened cards sit on those same four surfaces, so the
coverage gap is depth on known ground, not unexplored territory.)*

**The one rule when enhancing:** when a gap closes, mark it closed with the date and the evidence —
**don't delete the row.** A deleted gap loses the record that the trap ever existed, and that record
is exactly what the next person needs when a number looks wrong.

### The strategic question hanging over all of this

**Project Argus** is Porter's cross-vertical Metric Store programme — a governed semantic layer with
owner sign-off and definitions authored as reviewed code. Argus evaluated a hand-rolled,
per-metric-SQL approach for its own programme and **rejected it** in favour of that governed path.

PTL's current architecture — raw application tables plus a hand-rolled registry — is structurally
the shape Argus passed over. Nothing in Argus names PTL, so nothing binds us today. But the sibling
vertical PnM is already hitting the same fork under a standing rule that *"no governed model → not
eligible for the metric store."*

So the honest framing is: **this KB is deliberately a stopgap that buys correctness now.** Whether it
becomes the foundation or gets folded into Argus is an open roadmap decision (`G-132`), not a
settled one. Worth knowing before you invest heavily in extending it.

---

## 8. Current status & roadmap

**Foundational — not stakeholder-ready** (as of 2026-07-30). A low number in any of the four areas
below is the KB doing its job, not failing at it.

| Area | Current | Roadmap |
|---|---|---|
| **Coverage** | 23 of 85 catalogue rows fully written up, via 20 `M-###` entries (was 11 rows this morning). 29+ of 122 known cards read in depth | Promote index-only rows one at a time; work through the remaining unopened cards, surface by surface |
| **Verification** | 8 of 11 v1 metrics verified from SQL; 15 of 85 confirmed catalogue-wide; 1 metric execution-validated against live data | The 6 `contradicted` rows first — sources actively disagree today — then the rest |
| **Freshness** | 29 cards fingerprinted; 9 more found today still need one | Script the fingerprint comparison; stop relying on someone remembering to check |
| **Governance** | 7 programme-level rulings exist (D1–D7); 0 of 85 metrics have a named per-metric owner | Assign an owner per metric — unblocks most of §9 below |

**How we got here:**

| Phase | Status | What happened |
|---|---|---|
| 1 — Research | ✅ Complete | Surveyed AI-consumable KB patterns; picked the addressable-row shape |
| 2 — Inventory | ✅ Complete | Read every named source across both clones, Notion, and reference material |
| 3 — Ground in SQL | ✅ Complete | Traced every v1 metric to card SQL, not titles, across four dashboard surfaces |
| 4 — Enhance & resolve | 🟡 In progress | Promote index-only rows, close blocked gaps, assign owners — you're joining here |

**What today's validation push actually found**, beyond the raw count:

- **The catalogue itself has errors, not just gaps.** Two rows (#16/#17, #44) turned out to point at the wrong card, or a card that answers a different question than the one asked (`G-148`, `G-149`). Grounding in SQL doesn't just fill in blanks — it catches mistakes that have been sitting there since the catalogue was built.
- **14 metrics may be structurally untrackable right now** (12 fully, 2 partially), not just unwritten. Every card covering owner/vehicle-level supply health (monthly active owners, owner retention, earnings per vehicle) actually operates at *vendor* grain — a different entity than the catalogue assumes. No amount of searching Metabase fixes that; it's a data-model question for the metric owner (`G-151`).
- **6 metrics are confirmed genuinely absent** after a real search, with the negative evidence kept rather than a bare "unverified" (`G-150`).
- Coverage and confidence keep moving independently of each other, exactly as §1 warned — writing up more metrics didn't make the harder ones any less broken.

**Right now:** next priority is `G-141` (fix the North Star's offline-leg filter). Risk is **high** for any number quoted externally before reconciliation, **low** for the KB's own process — it's been blind-reviewed once and stranger-audited twice. No committed timeline — that's honest, not an oversight; see `G-133` for what's actually blocking one.

---

## 9. Where we want your input

Most of these need a decision or an owner, not more analysis:

| Gap | The question | Needs |
|---|---|---|
| `G-141` | Fix card 39117's offline leg so the North Star stops counting internal orders | an owner for that card |
| `G-002` | Two live definitions of "excluding 60-second cancellations". Which is canonical? | a decision |
| `G-004` / `G-135` | Three competing revenue bases for AOV (**Average Order Value** = revenue ÷ completed orders), crossed with two date bases | a decision |
| `G-137` | The inert date filters — fix the cards, or leave them and rely on the KB warning? | a decision *(already raised with card owners)* |
| `G-016` | `TOF`, `OS`, `OLC` are used throughout the review and defined nowhere *(`VSS` resolved 2026-07-30 — see glossary)* | a lookup: someone who knows |
| `G-132` | Do we target Argus eligibility? | a roadmap decision |
| `G-133` | No metric has a named owner. Argus requires one | assignment |
| `G-148` | Two cards use different customer-source tables, and one of them (#17) may be measuring clicks, not order placements | a decision on which table is canonical, and whether #17 needs rebuilding |
| `G-150` | 6 metrics (damage %, batch acceptance, allocation rate, reallocation rate...) have no card anywhere after a real search | confirm whether these are tracked at all, anywhere |
| `G-151` | 14 owner/vehicle-level supply metrics may not be buildable (12 fully, 2 partially) — the data that exists is at vendor grain, not owner/vehicle grain | a data-model decision, not more searching |

> Note the circularity worth naming: `G-141`, `G-002` and `G-004` all need an owner to decide, and
> `G-133` says no metric has a **per-metric** owner. (The programme-level owner who wrote D1–D7
> could rule on any of them — but seven rulings don't scale to 85 metrics, which is exactly the gap.)
> **Assigning per-metric owners unblocks most of this list.**

---

## 10. Glossary

| Term | Meaning |
|---|---|
| **PTL** | Part Truck Load — several customers' consignments share one truck |
| **FTL** | Full Truck Load — one customer books the whole vehicle |
| **pre-PMF** | before product–market fit; the product is still changing shape |
| **NSM** | North Star Metric — monthly transacting business customers. ⚠️ *computed as distinct mobile numbers, a proxy for customers; see §5* |
| **CBDF / CADF** | Cancelled Before / After Driver Found |
| **VSS** | Vehicle Selection Screen — confirmed from literal Amplitude event names, closing a gap that had sat open since Phase 2. A good example of the method in §5 working on jargon, not just numbers |
| **AOV** | Average Order Value = revenue ÷ completed orders — ⚠️ *three competing revenue bases are live; see `G-004`* |
| **Fulfilment (ff)** | completed orders ÷ orders placed — ⚠️ *an "excluding-60s" variant exists in two incompatible forms; see `G-002`* |
| **excl-60s** | excludes cancellations within 60 seconds of booking — ⚠️ *contested: numerator-only vs denominator; see `G-002`* |
| **Business customer** | `customers.frequency IN (1,2,3,4)` on `oms_public.customers`; everyone else is Personal (`T-020`, verified) |
| **Metabase card** | one saved query; a dashboard is a collection of cards |
| **db73 / db83** | two Metabase connections to Snowflake; most PTL metrics live on db73 |
| **Project Argus** | Porter's cross-vertical Metric Store programme (see §7) |
| **prototype engine** | `selfserve_nlq/` — a read-only Python tool that generates SQL for a fixed metric list. Generates queries; does not validate numbers |
| **D1–D7** | seven written decisions from the PTL metric owner (`repo@7a43470:ptl-selfserve/DECISION_LOG.md`) |
| **Offline orders** | PTL orders captured via Google Sheet rather than the app |

---

## Where everything lives

Repo: **`github.com/akshayjain00/selfserve_data`**

```
ptl-selfserve/kb/          ← the KB (this file included)
  CONTEXT.md        start here
  business.md · metrics.md · data-model.md · dashboards.md
  GAPS.md           the backlog
  CONTRIBUTING.md   the update protocol
```

Dashboards referenced throughout live at **`metabase.prod-internal.porter.in`**.

First published at commit `5fddacb` on `claude/ptl-metric-catalog-map` (cherry-picked to
`claude/pnm-metrics-catalog-map-vg251i` as `49d1d85`), updated since as coverage grew — check
`git log -- ptl-selfserve/kb/` for the latest. *(Two branches because the KB was written on
the PTL branch but also needed to be visible from the PnM-named branch the team was already using;
the content is identical, and every link inside `kb/` is relative so it works from either. The
sibling assets — `DECISION_LOG.md`, the catalogue, `selfserve_nlq/` — exist only on the PTL branch.)*

The build's full decision trail — every ruling and why — lives outside this repo in the ProdOps
workspace at `ptl-selfserve/coordination/kb-build/`.

**Nothing here is stakeholder-ready.** Exactly one metric has been reconciled against live data
(the North Star, §5). The other ten written up in full document *definitions*, not validated
numbers. Say so when you quote them.
