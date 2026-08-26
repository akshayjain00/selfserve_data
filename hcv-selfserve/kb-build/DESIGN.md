# HCV self-serve knowledge base — design spec

**Status:** v2, revised 2026-08-14 after two blind checks. Not yet built.
**Branch:** `claude/hcv-metric-catalog-map`, cut from `claude/ptl-metric-catalog-map` @ `28703aa`.

Build record, deliberately kept **out of** `kb/` — mirroring PTL, where the process trail lived in
`coordination/kb-build/` and never shipped inside the deliverable.

> **v2 changelog.** v1 specified the reference architecture's *rules* (precedence, confidence tiers,
> the never-resolve-a-conflict doctrine) but not its *shapes*. Two blind checks found 28 coherence
> defects and 14 classes of missing structure. v2 adds §6 (per-file anatomy), §7 (ID allocation),
> and §10 (verified pack anatomy); resolves every ambiguity the checks named; and merges the `H#`
> and `D-###` decision series into one. Decisions themselves are unchanged.

---

## 1. Goal

Give HCV analytics a base-context knowledge base that any future session — human or AI — can load
and trust, so nobody re-derives HCV's business context from scratch and metric definitions stop
drifting silently across five disagreeing sources.

**Deliverable:** `hcv-selfserve/kb/` — seven markdown files, plus `WALKTHROUGH.md` and a published
HTML artifact once the seven are stable.

**Out of scope:** `selfserve_nlq/` for HCV. No metric registry, no `sqlgen`, no `ask.py` (`D-001`).

### Success criteria

1. A reader with zero HCV context loads `CONTEXT.md` alone and correctly routes three tasks.
2. Every fact carries provenance, confidence, and — where the source has one — a staleness stamp.
3. No conflict between sources is silently resolved anywhere in the KB.
4. Every complementary partition stated in the KB sums to its whole (§11.4).
5. Passes a blind accuracy check by a reviewer given the sources and the bare claims, never the
   reasoning behind them.

---

## 2. Sources

Four documented sources describing largely **different** metric universes, plus a fifth authority
nobody has reconciled against.

| Source | Size | Nature |
|---|---|---|
| `hcv_metrics_queries.md` | 8 sections → 11–13 metrics (§11.2) | Owner-authored, **reconciled** SQL. Committed at `repo@20f6416:hcv-selfserve/hcv_metrics_queries.md` |
| Notion **HSC : HCV Dashboard** → `metabase:dashboard/1882` | **54** metrics (23 base, 31 derived) | Grounded in observed card SQL. **16 contested definitions**, **10 design callouts**, ~14 filter/bug findings. Snapshot 2026-07-18 |
| Notion **HSC : HCV Deep Dive** → `metabase:dashboard/4146` | **34** metrics (16 base, 18 derived) | Ops/supply funnel. **9 contested definitions**, **8 design callouts**, ~10 filter/bug findings. Spans **three DB connections** (70, 106, 108). Snapshot 2026-07-18 |
| Google Sheet `HCV_Metrics_DD` | ~90 rows, 4 domains | Argus target-state dictionary. Column is literally `Metric Definition {AI Enhanced}`; every row `Status = Pending`; `Definition Aligned with STL + Product & Business Director = FALSE` throughout |
| Governed store `metric.porter.*` | extent unknown | `map`, `accept_rate`, `average_order_value`, `cadf_customer_attr_pct`, `cadf_partner_attr_pct`, fulfilment, missed-order, CBDF, CADF, total login hours |

**Notation.** Both inventories use lettered children (`M001a`, `M016a`, `M020a`…), so `M001`–`M047`
carries 54 metrics and `M001`–`M033` carries 34. The id range is *not* the metric count; do not
"correct" it.

**Source-internal discrepancy to record, not fix:** the Deep Dive's summary says **34** unique
metrics; its own design callout says *"~26 of 33 metrics are ratios or percentile distributions."*
Both are the source's own words. → gap row, §6.6 class E.

### Three findings that shape the design

**F1 — A governed metric store already covers HCV, and disagrees with everything else.** PTL's
Argus gap inverted: there, Argus had *rejected* the architecture; here the store exists **and
conflicts with both the dashboards and the pack**. Sharpest case: the pack's MAP is login-based
(`SUM(business_login_hours) > 0.5`/day); `metric.porter.map` is order-based (≥1 completed order/
month). Same name, different metric.

**F2 — The two inventories have colliding ID spaces.** On `1882`, `M016` is Revenue. On `4146`,
`M016` is DAP. A bare `M016` is ambiguous, and would collide again with PTL's `M-###`.

**F3 — The pack and the dashboards measure overlapping things differently.** The pack's revenue
(`ceil(fare) + coupon + referral + subscription discounts`, `fare_type = 2`, `is_current`) is
exactly the formula `1882` flags as **gross booking value, not net** — one of *four* live Revenue
formulas there.

**F4 — The status enum means opposite things in PTL and HCV, in the same repo.** PTL `T-001`:
`3=Completed, 4=Cancelled`. HCV: `4=completed, 5=cancelled`, with `COALESCE(order_status, 5)`
appearing **12 times** so NULL silently becomes cancelled. `status = 4` therefore reads as
*Cancelled* to anyone carrying PTL context. HCV's branch is cut from PTL's and PTL's KB is the
template a builder is told to mirror. This is the highest-probability error in the engagement.

---

## 3. Decisions locked

One series. `DECISIONS.md` holds the same ids with full rationale; the v1 `H1`–`H5` labels are
retired and must not be cited.

| id | Decision |
|---|---|
| `D-001` | **KB only.** No `selfserve_nlq/` for HCV |
| `D-002` | Branch `claude/hcv-metric-catalog-map` off `claude/ptl-metric-catalog-map` @ `28703aa`; directory `hcv-selfserve` (hyphen) |
| `D-003` | **Coverage:** pack metrics get full `M-###` entries; everything else is an index row + one `G-###` **each** |
| `D-004` | **Anchor on the metric store:** every full entry carries `store_ref` |
| `D-005` | **Namespaced inventory refs** — never bare; always `nb1882:M016` / `nb4146:M016` |
| `D-006` | **Three confidence tiers**, not four; reconciliation recorded in `note` |
| `D-007` | Ship `WALKTHROUGH.md` + a published artifact, built last |
| `D-008` | **Themed decade-block ID allocation** (§7), not flat sequential |
| `D-009` | **Owner rulings are citable as `OWNER:<yyyy-mm-dd>`** (§5), since `D-001` removes the DECISION_LOG that PTL cited as `DECISION_LOG:D<n>` |

---

## 4. File layout

```
hcv-selfserve/
  hcv_metrics_queries.md      the pack — committed, top of the precedence ladder
  kb/
    CONTEXT.md                ≤150 lines, HARD CAP — entry point, written last
    business.md               B-###
    metrics.md                M-###  full blocks + index table
    data-model.md             T-###
    dashboards.md             card rows + registers — no new ID series
    GAPS.md                   G-###  append-only, lettered sections
    CONTRIBUTING.md           §1–§10, stable numbering (other files deep-link to it)
    WALKTHROUGH.md            built last
  kb-build/
    DESIGN.md  DECISIONS.md  BOARD.md
```

Four ID series only — `B-` `M-` `T-` `G-`. `dashboards.md` carries **no** ID series; its rows are
keyed by `metabase:card/NNNNN` and are exempt from the §6.1 `id` requirement.

**Self-containment:** every link inside `kb/` is relative, so the KB works from any branch. No
absolute path or branch name appears in a link.

---

## 5. Provenance and citation forms

| Form | Use | Strength |
|---|---|---|
| `repo@<sha>:<path>#L<n>` | Anything version-controlled, including the pack | strongest |
| `metabase:card/NNNNN` / `metabase:dashboard/NNNN` | Cards, with `database_id` where known | strong |
| `nb1882:M###` / `nb4146:M###` | The Notion inventories — **never bare** (`D-005`) | medium |
| `gsheet:HCV_Metrics_DD#<row>` | The Sheet, snapshot-dated | weak |
| `store:metric.porter.<name>` | The governed store | medium |
| `OWNER:<yyyy-mm-dd>` | An explicit owner ruling (`D-009`) | strong |
| `local:<path>` | Anything not version-controlled | **weakest — a fact whose only source is `local:` can never exceed `unverified`** |

`pack:§N` is a **human shorthand only**. It must always accompany a `repo@<sha>:…#L<n>`, never
replace it. A bare `pack:§N` is not a citation.

Local clone paths appear **exactly once**, in `CONTEXT.md`, as a convenience alias.

---

## 6. Per-file anatomy

The contract v1 lacked. Each file's shape, not just its topic.

### 6.0 Conventions applying to every file

- **Header, 3 lines:** title · what the file holds + back-links to `CONTRIBUTING.md` **and**
  `CONTEXT.md` · `All rows last_verified: YYYY-MM-DD`.
- **`last_verified` is a file-level claim about every row in it.** Do not refresh unless every row
  was re-checked. Re-checked one row → inline override in that row's `note`
  (`last_verified 2026-08-20`).
- **`> ⚠️` blockquote callouts** are the cross-cutting warning channel between tables. Reserved for
  "do not do X" instructions; never used for ordinary notes.
- **`✅` / `⚠️` glyphs** encode confidence at a glance in headings and index tables. `⚠️` in an index
  means *do not quote without reading its gap row first*, and that meaning is stated in-file.
- **Tables may carry only the columns that apply to them.** The four always-columns (§6.1) are the
  contract; a units table needs no `statement`, a glossary needs no `source_updated_at`.
- **Monotonic counters (view counts, run counts) are never recorded as facts** — they drift.

### 6.1 Row schema

| Column | Meaning | Required |
|---|---|---|
| `id` | `B-###` / `M-###` / `T-###` / `G-###` | always (except `dashboards.md`) |
| `statement` | The fact — one sentence or one formula | always |
| `source_ref` | §5 | always |
| `confidence` | `verified` / `unverified` / `assumption` | always |
| `source_updated_at` | The source artifact's own last-modified stamp | when the source has one |
| `inventory_ref` | `nb1882:M###` / `nb4146:M###` | metrics, if present there |
| `store_ref` | `metric.porter.<name>` or the literal `none` | **full `M-###` entries, always** |
| `aliases` | Jargon, acronyms, card titles | if any |
| `note` | Caveats, conflicts, `see G-###` | if any |

### 6.2 `CONTEXT.md` — entry point, ≤150 lines, written last

Required sections, in order:

1. Bold imperative header + inline `last_verified`.
2. **Load-protocol routing table** (task → file), including chained routes ("metric definition →
   `metrics.md` → *then* `dashboards.md` for its card") and the mandatory row *"About to edit this
   KB → `CONTRIBUTING.md` — **required**"*.
3. **ID legend + the instruction "Cite IDs when you answer."** This is the habit the whole
   addressable-row design exists to produce; without the instruction it does not form.
4. **What HCV is** — vertical definition, warehouse schema, business posture.
5. **Core-metrics quick-reference table** — `id | metric | formula | confidence`, a compressed
   duplicate of `metrics.md`, with the `⚠️` legend. Success criterion 1 fails without it: a reader
   loading `CONTEXT.md` alone would otherwise get no formulas.
6. **"Three facts that prevent most errors"** — curated high-leverage digest, each with its ID.
   For HCV these are near-certainly `F4` (status enum), the overlapping category dimension (§10),
   and the `mbr_mapping_v2` precondition.
7. Precedence ladder + absolute exception (§8).
8. Confidence and staleness (§9).
9. **Hard rules, each backed by a `B-###` / `T-###`** (§12) — pointers to sourced rows, not
   free-standing assertions.
10. **Source locations** — repo, ASCII tree of which siblings exist on which branch, pinned SHAs,
    dashboard index, and the relative-link self-containment note.
11. **State of the work**, closing with the non-readiness disclaimer.

### 6.3 `CONTRIBUTING.md` — §1–§10, stable numbering

Other files deep-link by section number, so the numbering is part of the contract.

§1 *"A fact without provenance is not a fact"* + **the demotion rule** — a row that cannot carry
provenance/confidence is a `GAPS.md` entry, not a KB fact · §2 row schema, column-variance rule,
per-row `last_verified` override, retired-ID recording · §3 `source_ref` forms (§5) · §4 confidence
table **with a "bar to claim it" column**, incl. *"agreement between two unverified sources is
still unverified"* · §5 **staleness procedure**: `recorded < current ⇒ STALE`; *a STALE row is not
wrong, it is unchecked* → mark `unverified`, open a `G-###`, re-extract · §6 precedence + absolute
exception + per-rung scope of authority · §7 numbers vs definitions · §8 **correction, closure and
ID protocols** — edit in place, refresh `last_verified`, re-check `source_updated_at`, adjust
confidence, add a `note` saying what changed, *never delete and re-add*; close a `G-###` as
`CLOSED` with date + resolving ID, *never delete*; record retired IDs as retired, not reused; gap
rows require a `next_action` specific enough to execute · §9 never-put list, incl. **live or
derived query results** · §10 **session exit checklist**, incl. *"if you added a topic file, add it
to `CONTEXT.md`'s routing table or nothing will ever load it"*, and the `WALKTHROUGH`↔artifact
manual-sync obligation (§15).

### 6.4 `business.md`

Header · **calibration blockquote** — *why almost everything here reads `unverified`: the scale
grades **evidence type**, not trustworthiness; for a file sourced from Notion inventories and an
AI-drafted Sheet, `unverified` is the correct signal, not a defect* · What HCV is · Interventions &
GTM timeline (trend-interpretation anchors) · Porter metric conventions as `B-###` rows that
`CONTEXT.md`'s hard rules cite · Glossary (own schema: `id | term | expansion | source_ref |
confidence`) · **House formulas and standard dimensional cuts** — HCV's `month × category ×
distance`, Tier 1, `9ft–19ft` · **The governed store's own requirements** as `B-###` rows ·
**Known defects in the source documents (do not silently correct)** — an in-file register for a
*single source being internally wrong*, distinct from two sources conflicting · **Snapshot** —
blockquoted preamble (point-in-time, source, capture date, all `unverified`), current *and prior*
period columns, inline `⚠️` + gap ids, tagged by **data period**, never by review name.

### 6.5 `data-model.md`

Header + warehouse/primary-DB statement. Sections **highest-leverage first**: Core enums and
encodings — *read these first* → Units → Segmentation & exclusion → Time basis → The
`mbr_mapping_v2` precondition → Tables listing → **Privacy** (PII-bearing column inventory,
pointing at `CONTRIBUTING.md` §9). Per-section schema variance per §6.0. Row-splitting is a stated
design move: split a row (`T-001a`) so a well-evidenced half is not dragged down by a weak half,
and say so in the `note`.

### 6.6 `GAPS.md`

**Status vocabulary:** `OPEN` · `BLOCKED` (needs a person, not more analysis) · `CLOSED` (with date
+ resolving ID). **Severity qualifiers:** `OPEN — high` / `— low` / `— informational` /
`— mechanical, do next` / `OPEN · ESCALATED` / `BLOCKED — owner, structural`.

**`next_action` is a required column** on every section except the source-defect register — the
thing that makes GAPS a backlog rather than a complaint list.

**Closed rows stay in place, struck through** (`~~G-003~~`) with closure evidence; consequences
that outlive the closure get **spin-off ids appended at the series end**, not inserted.

**Lettered sections, grown by suffix (`F` → `F2` → `F3`), never renumbered:**

| § | Class |
|---|---|
| A | Metric-definition conflicts — pack vs card vs store |
| B | Code defects in source cards (hard-coded filters, inert parameters, logic bugs) |
| C | Source & provenance gaps (missing fingerprints, unreachable systems) |
| D | **Naming / ID collisions** — `F2` (`M016`), `F4` (status enum), cross-vertical PTL↔HCV |
| E | **Defects inside a single source** — incl. the Deep Dive's own 34-vs-33 discrepancy |
| F | Strategic / metric-store posture |
| G | **Coverage — metrics.** One row per index-only metric (`D-003`), with a **class-level
`next_action`** so ~120–130 rows are not each given bespoke intent, plus `⚠️` marking the source's own highest-risk labels |
| H | **Coverage — cards.** Surfaces and cards not opened, as a stated boundary |

Three content types with no analogue elsewhere, each required:
- **Informational anti-gaps** — rows that exist so a future session does not "fix" correct work.
- **Escalation records** — *"raised with the card owner on <date>; do not remove this row when
  fixed — close it with the date and the fixing card version"*, so the KB records that the trap existed.
- **Negative evidence** — *searched, zero hits* / *rejected, not a match*, kept explicitly distinct
  from *not looked at*.

### 6.7 `metrics.md`

Scope header (N full / N index-only) + *"read this before quoting any formula"* pointer to the
aggregate-then-ratio rule.

**§1 — full entries are per-metric blocks, not table rows.** Shape:

```
### M-00X — Name ✅ `verified`  /  ⚠️ `unverified`
- **Definition:** one line.
- **Formula:** the expression.
- **Implementation:** `repo@<sha>:hcv-selfserve/hcv_metrics_queries.md#L<n>` (`pack:§2`)
  · `source_updated_at: …` · `database_id: …`
  ```sql
  -- verbatim excerpt: the evidence, not a paraphrase
  ```
- **confidence:** … — with what was reconciled, against what, on what date.
- **store_ref:** `metric.porter.<name>` — and **how it differs**, or `none`.
- **inventory_ref:** `nb1882:M###` / `nb4146:M###`
- **grain:** which pack sections emit it, at which cuts (§10)
- ⚠️ caveats → `G-###`
- **Reported values:** see the snapshot in [business.md](./business.md).
- **aliases:** …
```

The verbatim SQL excerpt is load-bearing: the ladder rests on observed SQL, so a full entry that
paraphrases its evidence is not a full entry.

**§1d — "Checked and found genuinely wrong, not silently corrected."** Rows where the *source
itself* is in error, held `unverified` for a specific evidenced reason. PTL called this its
highest-value output; HCV's Sheet (`{AI Enhanced}`, all `Pending`) is the same hazard class.

**§2 — index table.** Columns: `metric | source | inventory_ref | level | Doshi category |
source-status (verbatim) | G-###`. With the standing warning: **the source-status column is the
source's own wording, carried verbatim — it is not a KB confidence value.** HCV needs this for the
Sheet's `Status = Pending` and the inventories' "contested".

Closing reconciliation arithmetic per §11.4.

### 6.8 `dashboards.md`

Header: base URL + restated staleness procedure. Then:

- **Staleness-fingerprint register** — `card | source_updated_at | database_id` for every card the
  KB **cites** (`D-012`): those feeding a covered metric or a recorded conflict. One `get_card`
  metadata call each; no queries. **Any cited card without a fingerprint is recorded as a `G-###`.**
  A single `G-###` commits to the full-dashboard sweep, with a `next_action` naming **a specific
  card list and a named owner** — PTL's equivalent has sat open, and "sweep the dashboards" is not
  an executable action.
- **DB-connection register** — `id | name | role here`. HCV spans **70, 106, 108**.
- **Surfaces-covered table** — `surface | id | scale (cards/tabs) | opened | role`, with the
  explicit boundary statement: *N cards were not opened. This is a stated boundary, not implied coverage.*
- **Per dashboard:** `Tabs:` and `Filters:` **with defaults** — precisely what hard rule 7 warns
  about — then the card table with a **`Feeds` column** back-referencing `M-###`/`G-###`, then
  prose blocks for title-vs-SQL mismatches and latent defects.
- **The query pack as a source-of-record entry**, with its own dependency graph (§10).

### 6.9 `WALKTHROUGH.md`

Audience line + explicit reading-time promise. Ten sections: narrative problem statement + source
table + pull-quote statistic + the **orthogonality table** (the inventories' "contested" count vs
KB coverage are two different cuts — ship them conflated and the doc lies) · ASCII architecture
diagram + "reference desk, not a textbook" framing + specimen row + ID-prefix legend **including
the `dashboards.md` exception** · question→file table + *"when you quote a fact, quote its ID"* ·
**"words you'll see that are NOT confidence labels"** — `contested`, `Pending`, `stale` · **worked
example** (see below) · maintenance rules + the honest caveat that no linter enforces any of it ·
contribution modes + *"when a gap closes, don't delete the row"* · status & roadmap tables ·
**"where we want your input"** — the `D-###` seed gaps as a `gap | question | needs` table ·
a second, plain-language glossary distinct from `business.md`'s sourced one · closing
non-readiness disclaimer.

> ⚠️ **The worked example needs a substitute device.** PTL's centres on tracing one metric
> find → execute → inherit-its-defects, with real numbers. §15 forbids warehouse validation, so
> that device is unavailable to HCV. **Use instead:** trace MAP end-to-end through its three-way
> conflict — pack (login-based) vs dashboard vs `metric.porter.map` (order-based) — which needs no
> execution and demonstrates the absolute exception doing its job.

---

## 7. ID allocation — themed decade blocks

**`D-008`.** Flat sequential allocation is irreversible once renumbering is forbidden. IDs are
allocated in themed blocks so a future fact can be filed near its kin. **Insertions and splits use
letter suffixes** (`T-001a`, `B-053b`) — never a renumber.

| Series | Block | Theme |
|---|---|---|
| `B-` | 001–019 | What HCV is — vertical, scope, stage, schema |
| | 020–029 | Interventions & GTM timeline |
| | 030–039 | Porter metric conventions (cited by the hard rules) |
| | 040–059 | Glossary |
| | 060–069 | House formulas & standard dimensional cuts |
| | 070–079 | Governance — Argus / metric-store requirements |
| | 090–099 | Snapshot anchors |
| `T-` | 001–019 | Core enums & encodings (incl. `F4`, `NULL → 5`) |
| | 020–029 | Segmentation & exclusion (test mobile, Tier, `vehicle_mapping`) |
| | 030–039 | Units & silent scaling |
| | 040–049 | Time basis — IST/UTC, `order_time` vs `created_at`, the double-shift |
| | 050–069 | Tables listing |
| | 070–079 | `mbr_mapping_v2` and its dependency graph |
| | 080–089 | Privacy — PII-bearing columns |
| `M-` | 001–029 | Full entries from the pack |
| | 100+ | Reserved for later promotions out of the index |
| `G-` | grouped by lettered section (§6.6), each section starting a fresh decade |

---

## 8. Precedence ladder

1. **`hcv_metrics_queries.md`** — owner-authored, reconciled SQL, *for the metrics it covers*
2. **Observed Metabase card SQL**, as recorded in the two inventories
3. **Governed store `metric.porter.*`** — authoritative for **naming and governance**; its formulas
   conflict with (1) and (2) in the four places enumerated in §13
4. **The inventories' editorial judgement** — KPI tree, de-dup rules, Doshi categories
5. **Sheet `HCV_Metrics_DD`** — target state, AI-drafted, unratified → `assumption` by default
6. **Card titles — never evidence.** Both inventories document title/SQL mismatches

> **Absolute exception.** When pack, card, and store disagree — and they do — **do not resolve it.**
> Record every side, set `confidence: unverified`, open a `G-###`. Silently picking a side converts
> a known unknown into an invisible error.

---

## 9. Confidence and staleness

`verified` — read directly from underlying SQL/code, or an explicit owner ruling (`OWNER:<date>`) ·
`unverified` — asserted but not confirmed against SQL, or sources conflict · `assumption` —
inferred, stated nowhere.

**Agreement between two unverified sources is still `unverified`.** Downgrading is always allowed;
upgrading needs new cited evidence. Reconciliation-against-numbers goes in `note`, not a fourth tier
(`D-006`) — phrased as what was reconciled, against what, on what date.

**Staleness procedure.** Compare the row's recorded `source_updated_at` against the source's current
value. `recorded < current ⇒ STALE`. **A STALE row is not wrong — it is unchecked.** Mark it
`unverified`, open a `G-###`, then re-extract. For a Metabase card this is one `get_card` metadata
call, **not** a query.

---

## 10. Verified anatomy of the query pack

Read from the SQL at `repo@20f6416:hcv-selfserve/hcv_metrics_queries.md`, not from the pack's prose.

| § | creates | needs `mbr_mapping_v2` | month | category | distance |
|---|---|---|---|---|---|
| 0 | ✓ | — | | | |
| 1 | | ✓ | ✓ | — | ✓ |
| 2 | | ✓ | ✓ | ✓ **overlapping** | ✓ |
| 2a | | ✓ | ✓ | — | ✓ |
| 3 | | ✓ | ✓ | ✓ **overlapping** | ✓ |
| 3a | | ✓ | ✓ | — | ✓ |
| 4 | | ✓ | ✓ | ✓ exclusive | ✓ |
| 5 | | **✗** | ✓ | — | — |
| 6 | | ✓ | ✓ | ✓ **overlapping** | ✓ |

**10.1 — The pack's own caveat is wrong.** It states *"sections 1–4 depend on `mbr_mapping_v2`"*.
**§6 depends on it too.** Every section except §5 does. → `G-###`, class E.

**10.2 — Category has three treatments, and one is a double-count.** §2/§3/§6 use `UNION ALL`,
emitting a `10ft` row **plus** `10ft - NCR` **plus** `10ft - non NCR` — so **every 10ft order is
counted twice** when summing across category. §4 uses `CASE` (mutually exclusive, no overall row).
§1/§2a/§3a/§5 have no category dimension. This is a `T-###` fact **and** hard rule 6; it must not be
"helpfully" normalised away during the build.

**10.3 — Duplication is broader than §6.** §2a is §2 without category; §3a is §3 without category;
§6 is a projection of §2 + §3 that **drops E-FF%**. Grain variants are **dimensions of one metric,
not separate metrics**. A builder writing one `M-###` per section produces four spurious duplicates.

**10.4 — Two `completed` lineages.** §1 counts `oms_public.orders.status = 4`; §2/§3/§6 count
`hcv_overall_demand_mart.order_status = 4`. Same name, different source. Record both; do not merge.

---

## 11. Coverage plan and the counting contract

**11.1 Full entries:** the pack's metrics, each per §6.7.

**11.2 Deriving the count.** One `M-###` per distinct **(measure, source lineage)** pair. Grain
variants are dimensions (§10.3); §6 is recorded as a projection, not a metric; ratio denominators
are first-class (de-dup rule 3). On that rule the pack yields **11–13** full entries — the spread is
`total_placed`/`unique_demand` as bases, and whether §10.4's two `completed` lineages are one entry
or two. **The exact number is fixed once, during the build, and every count in the KB then agrees
with it.**

**11.3 Index-only rows.** The deduped union of `1882`'s 54, `4146`'s 34 and the Sheet's ~90, minus
those promoted. The dashboards' union is **72** (54 + 34 − ~16 shared). The Sheet overlaps that
union by roughly **20–30** rows — the overlap is *real, not thin*: CBDF, CADF, missed order,
stockout, allocation rate, FF %, E-FF %, ATA, DAP, total placed orders, unique demand, acceptance
rate, dry run, delay, allocation time, partner earnings, M1 retention, notification undelivery all
appear on both sides. Union ≈ **132–142**; index-only ≈ **120–130** after promotions.
**These are estimates and must be labelled as such until the de-dup is done.**

**11.4 The counting contract.** Once de-dup is complete the counts are fixed once and **every
complementary partition stated anywhere in the KB must sum to its whole.** A "partition" is any set
of counts the KB presents as jointly exhausting a named total.

> ⚠️ **Count rows and ID-numbers separately, and say which you mean.** PTL shipped exactly this bug:
> **23 catalogue rows** were closed by **20 `M-numbers`** (two `M-###` each closed more than one
> row), and "20 full + 62 index-only" was printed against a total of 85 — which it never summed to.
> The correct statement was `23 + 62 = 85`. HCV has the identical hazard, since one `M-###` will
> close several deduped inventory rows. Where the two units differ, state both and say why.

**11.5 De-duplication** follows the four rules `1882` already states — filter→dimension; bucketed
`CASE`→bucket dimension; ratios parented to their base; genuinely different SQL stays distinct — so
every collapse is traceable to a stated rule, not to judgement.

**11.6 The 18 design callouts** (10 from `1882`, 8 from `4146`) are routed to `metrics.md` notes
where metric-specific, and to `GAPS.md` class B or F where structural. They are not dropped.

---

## 12. Hard rules for `CONTEXT.md`

**Ten rules: seven carried from PTL (1, 3, 4, 5, 8, 9, 10), three HCV-specific (2, 6, 7).** Each is
backed by a `B-###` or `T-###` row; the hard-rule list is pointers, not free-standing assertions.

1. **Never run a production query** without explicit owner go-ahead. Metadata reads only. An
   unresolvable definition is an `unverified` finding, not a licence to run it.
2. **HCV `status`: `4 = completed`, `5 = cancelled` — the opposite of PTL's `4 = Cancelled`**, and
   `COALESCE(order_status, 5)` (12 occurrences) silently makes NULL a cancellation. PTL's KB sits
   beside this one and is the template; nothing else in this KB is likelier to be misread. (`F4`)
3. Never put credentials, tokens, personal data, or live/derived query results in this KB. Column
   *names* are schema facts; values are not.
4. **Aggregate-then-ratio.** Never average daily ratios, **and never average percentiles** — a
   weekly p50 is not the mean of daily p50s. ~26 of the Deep Dive's metrics are ratios or percentile
   distributions.
5. **Non-additive counts are never summed across periods** — DAP, active customers, unique booking
   sessions, cross-serviceable drivers, every cohort matrix.
6. **The category dimension contains overlapping members.** In pack §2/§3/§6, `10ft` and
   `10ft - NCR`/`10ft - non NCR` coexist, so summing across category double-counts 10ft. §4 does not.
   (§10.2)
7. **`dev_eldoria.sandbox.mbr_mapping_v2` is a write AND a prerequisite**, gating every pack section
   except §5. No refresh contract — any number derived from it is exactly as stale as the last manual
   run, and nothing in the warehouse records when that was.
8. **Two time bases coexist.** `hcv_overall_demand_mart.order_time` reads as already-IST;
   `oms_public.orders.created_at` is UTC and needs `+330 min`. Card 28841 has a documented IST
   double-shift. Check; never assume.
9. **Tier is a business rule buried in SQL.** `CASE geo_region_id IN (1,2,3,4,5,6,8,9)` is repeated
   across ≥8 cards, and Tier is encoded `'Tier 1'` vs `'Tier1'` on different columns. A Tier
   selection can silently return empty.
10. Never inline a metric value into a definition — values live only in `business.md`'s snapshot,
    tagged by data period. Divide-by-zero → null. Percentage movements in **"pp"**.

---

## 13. Seed gaps — owner-blocked

`D-001` removes the separate decision log, so unresolved owner calls are `GAPS.md` rows,
`BLOCKED — owner`. `WALKTHROUGH.md` §9 surfaces them as a `gap | question | needs` table.

| Question | Conflict |
|---|---|
| ~~**No north star**~~ | **SETTLED `D-011` — Fulfilment % is L0** (`OWNER:2026-08-14`). Its *denominator* stays BLOCKED, below |
| **Fulfilment denominator** | Total vs unique vs business-hours demand — three live under one name. `D-011` designates the metric, **not** its formula |
| **Canonical revenue** | Four formulas on `1882`, plus the pack's, plus the store's |
| **Canonical AOV** | Three on `1882`, one on `4146` (card 32713), plus `metric.porter.average_order_value` |
| **MAP / DAP** | Login-based (pack, dashboards) vs order-based (store) |
| **Allocation %** | Three formulas on `4146`, plus the pack's `fo_driver_id IS NOT NULL` |
| **Allocation key** | `metric.porter.cadf` detects allocation via `driver_id`; the pack uses `fo_driver_id` and says explicitly *"not `driver_id`"* |
| **Time-to-accept** | Store `avg_time_to_accept_seconds` is a **mean**, clocked **notification-sent → acceptance**; pack §4 is **P50/75/90**, clocked **`order_time` → `fo_trip_accepted_time`** |
| **CADF attribution base** | Card 32670 divides by total demand; the store divides by CADF |
| **Argus posture** | The store already carries HCV metrics the dashboards re-derive against legacy `trucks.*` |

**Store-vs-pack/card conflicts (§8 rung 3), verified first-hand 2026-08-14:** revenue · AOV ·
MAP/DAP · CADF attribution base · **allocation key** · **time-to-accept**. The last two appear in
**neither Notion inventory**.

> ⚠️ **The inventories under-report.** `GAPS.md` cannot be assembled by transcribing their
> contested-definition lists. Every metric the KB covers gets its own store-vs-pack-vs-card
> comparison, done at **step 3**, not step 5.

---

## 14. Build order

`CONTEXT.md` last — it summarises everything and is hard-capped.

0. ~~Branch, scaffold, commit the pack~~ — **done** (`5a06a81`, `20f6416`)
1. `CONTRIBUTING.md` — the schema contract, so everything downstream conforms
2. `data-model.md` + `business.md`
3. `metrics.md` — full blocks (§6.7), then the deduped index; fix the counts (§11.2)
4. `dashboards.md` — registers first (fingerprints, connections, surfaces), then cards
5. `GAPS.md` — 25 contested definitions, ~24 filter/bug findings, the 18 design callouts (§11.6),
   the §13 seed gaps, the coverage rows
6. `CONTEXT.md`
7. Verification gate (§15)
8. `WALKTHROUGH.md` + published artifact

---

## 15. Verification gate

- **Blind accuracy check** — sources and bare claims, never the reasoning.
- **Zero-context loadability test** — a fresh reader loads `CONTEXT.md` alone and routes three tasks.
- **Mechanical coherence pass:**
  - every `B-`/`M-`/`T-`/`G-` cross-reference resolves to a row that exists
  - every row carries a `confidence` value, and no value outside the three
  - `CONTEXT.md` ≤150 lines
  - **every complementary partition sums to its whole**, with rows and ID-numbers counted separately
    and labelled (§11.4)
  - every full `M-###` block carries `store_ref` — reading `none` rather than being absent — and a
    verbatim SQL excerpt
  - no `inventory_ref` appears bare; all are `nb1882:` / `nb4146:` prefixed
  - no `pack:§N` appears without an accompanying `repo@<sha>:…#L<n>`
  - every gap row outside class E carries a `next_action`
  - every card in `dashboards.md` either has a `source_updated_at` or a `G-###` recording its absence

---

## 16. Risks

- **`WALKTHROUGH.md` and the artifact have no automated sync.** PTL's drifted once, caught by audit
  rather than process. Stated in `CONTRIBUTING.md` §10, not left to memory.
- **The Sheet is an unratified AI draft.** Ladder position 5 and `assumption` confidence are the
  guard; both must survive review pressure.
- **No number will be warehouse-validated at ship** unless the owner authorises executing saved
  cards. Nothing is stakeholder-ready. This also removes `WALKTHROUGH.md`'s natural worked example
  (§6.9).
- **PTL has moved on.** Remote `claude/ptl-metric-catalog-map` is one commit ahead of this branch's
  base — `1f008cd`, "iteration-2 spec: import PTL weekly-report skill doc into kb/". It does not
  touch `kb/`, so the template is unaffected, but PTL is mid-iteration-2 and this spec mirrors
  iteration-1's shape.
- **Metabase connector auth was flaky during the PTL build.** Budget for it recurring; §6.8's
  fingerprint register needs one metadata call per card.
