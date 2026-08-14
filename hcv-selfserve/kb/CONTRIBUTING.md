# CONTRIBUTING — how to change this knowledge base

**Read this before editing any file in `kb/`.** Entry point: [CONTEXT.md](./CONTEXT.md).

This KB is designed to be corrected incrementally by AI sessions and humans alike. The rules below
are what keep it from rotting into confident nonsense. Sections are **stably numbered** — other
files deep-link to them by number (`CONTRIBUTING.md §5`), so §-numbers are part of the contract and
are never reordered.

---

## §1 The one rule that matters

> **A fact without provenance is not a fact. Do not add one.**

Every row in every topic file carries where it came from, when it was last checked, and how much to
trust it.

**The demotion rule.** A row that cannot carry provenance, confidence, and (where its source has
one) a staleness stamp is a **[GAPS.md](./GAPS.md) entry, not a KB fact.** Demoting is always
correct; writing an unsourced fact never is.

---

## §2 Row schema

| Column | Meaning | Required |
|---|---|---|
| `id` | Stable identifier — `B-###` business, `M-###` metric, `T-###` table/column, `G-###` gap. **Never reused, never renumbered.** | **always** |
| `statement` | The fact itself — one sentence or one formula | **always** |
| `source_ref` | Where it came from. See §3 | **always** |
| `confidence` | `verified` / `unverified` / `assumption`. See §4 | **always** |
| `source_updated_at` | The *source artifact's* own last-modified stamp. See §5 | **only when the source has one** |
| `inventory_ref` | Cross-reference to the Notion inventories — **never bare**, always `nb1882:M###` or `nb4146:M###`. See §2.4 | metrics, if present there |
| `store_ref` | The `metric.porter.*` counterpart, or the literal `none` | **full `M-###` entries, always** |
| `aliases` | Other names — jargon, acronyms, card titles | if any |
| `note` | Caveats, conflicts, `see G-###` | if any |

**[dashboards.md](./dashboards.md) is exempt from `id`.** Its rows are keyed by
`metabase:card/NNNNN` and carry no KB ID series. It is the only exemption.

### §2.1 Tables may carry only the columns that apply to them

The four **always** columns are the contract; everything else is as-needed. A glossary table needs
no `source_updated_at`. A units table replaces `statement` with `column | stored as | convert`. A
tables listing may drop `source_ref` where the whole section shares one. Do not pad a table with
empty columns to make it match another table.

**[metrics.md](./metrics.md) §1 deliberately uses per-metric blocks rather than rows**, because a
metric definition carries a formula, a SQL excerpt, several sources and multiple caveats that do not
fit one line. The four required elements are still present in every block.

### §2.2 `last_verified` is declared once per file

In the header, under the title — not repeated on every row. **A file-level date is a claim about
every row in that file**, so do not refresh it unless you actually re-checked them all.

Re-checked a single row? Leave the file header alone and put an inline override in that row's
`note`: `last_verified 2026-08-20`.

### §2.3 IDs are append-only, and allocated in themed blocks

To add a fact, take the next unused number **inside that fact's block** (§2.5). Never renumber.

- **Splitting a row** — use a letter suffix: `T-001` → `T-001` + `T-001a`. Say in the `note` why it
  was split (usually: so a well-evidenced half is not dragged down by a weak half).
- **Inserting** near existing kin — letter suffix again (`B-053b`). Never shift the numbers around it.
- **Retiring an ID** — record that it was retired. A never-explained missing number reads as a
  mistake to the next reader. **Retired IDs are never reused.**

### §2.4 Two ID hazards specific to this KB

> ⚠️ **The two Notion inventories have colliding ID spaces.** On `dashboard/1882`, `M016` is
> Revenue. On `dashboard/4146`, `M016` is DAP. **Never write a bare `M0##`.** Always
> `nb1882:M016` or `nb4146:M016`. A bare reference also collides with this KB's own `M-###`
> (hyphenated) series.

> ⚠️ **The inventories' ID ranges are not their metric counts.** They use lettered children
> (`M001a`, `M016a`, `M020a`), so `M001`–`M047` carries 54 metrics. Do not "correct" this.

**One exemption: a bare `M0##` inside a verbatim source quote stays unaltered.** When this KB quotes
a source's own words — the `source-status` column, a contested-definition note — the quote is
evidence, and **editing a quote to satisfy a naming rule corrupts the evidence.** Leave it, and rely
on the row's own `inventory_ref` to disambiguate. The rule binds **this KB's own prose**, not
material it is quoting. Any automated check for bare ids must exclude quoted spans, or it will
report these two known-good cases forever.

### §2.5 ID block map

| Series | Block | Theme |
|---|---|---|
| `B-` | 001–019 | What HCV is — vertical, scope, stage, schema |
| | 020–029 | Interventions & GTM timeline |
| | 030–039 | Porter metric conventions (cited by CONTEXT's hard rules) |
| | 040–059 | Glossary |
| | 060–069 | House formulas & standard dimensional cuts |
| | 070–079 | Governance — Argus / metric-store requirements |
| | 090–099 | Snapshot anchors |
| `T-` | 001–019 | Core enums & encodings |
| | 020–029 | Segmentation & exclusion |
| | 030–039 | Units & silent scaling |
| | 040–049 | Time basis |
| | 050–069 | Tables listing |
| | 070–079 | `mbr_mapping_v2` and its dependency graph |
| | 080–089 | Privacy — PII-bearing columns |
| `M-` | 001–029 | Full entries from the query pack |
| | 100+ | Reserved for later promotions out of the index |
| `G-` | per lettered section (§8.4), each starting a fresh decade |

Flat sequential allocation is **irreversible** once renumbering is forbidden. Blocks let a future
fact be filed near its kin.

---

## §3 `source_ref` forms

| Form | Use | Strength |
|---|---|---|
| `repo@<sha>:<path>#L<n>` | Anything version-controlled, **including the query pack** | strongest |
| `metabase:card/NNNNN` · `metabase:dashboard/NNNN` | Cards and dashboards, with `database_id` where known | strong |
| `OWNER:<yyyy-mm-dd>` | An explicit owner ruling | strong |
| `store:metric.porter.<name>` | The governed metric store | medium |
| `nb1882:M###` · `nb4146:M###` | The Notion inventories (§2.4) | medium |
| `gsheet:HCV_Metrics_DD#<row>` | The Sheet, snapshot-dated | weak |
| `local:<path>` | Anything not version-controlled | **weakest** |

**Never a bare path or branch name.** Two clones of this repo exist on diverged branches; commit
SHAs are the only stable citation.

**`pack:§N` is a human shorthand, not a citation.** It must always accompany a
`repo@<sha>:hcv-selfserve/hcv_metrics_queries.md#L<n>`, never replace it.

> **A fact whose only source is `local:` can never be more than `unverified`.** If it matters,
> commit the source and re-cite it.

Local clone paths appear **exactly once**, in [CONTEXT.md](./CONTEXT.md), as a convenience alias.

---

## §4 Confidence

| Tier | Means | Bar to claim it |
|---|---|---|
| `verified` | Read directly from underlying SQL/code, or an explicit owner ruling | You have read the SQL yourself, or can cite `OWNER:<date>` |
| `unverified` | Asserted by a source but not confirmed against SQL, **or sources conflict** | The default for anything sourced from a document rather than code |
| `assumption` | Inferred by reasoning; stated nowhere | Say what you inferred it from |

**Agreement between two unverified sources is still `unverified`.** Two documents copying each
other is one source, not two.

**A card title is never evidence.** Both Notion inventories document titles that contradict their
own SQL — a "Rejection rate" card computing acceptance rate, a "wallet share" column returning
orders-per-customer.

**Downgrading confidence is always allowed. Upgrading needs new cited evidence.**

**Reconciliation goes in `note`, not in a fourth tier.** Write what was reconciled, against what,
on what date — e.g. *"pack reconciles to OMS+SO canonical logic to the rupee, May–Jul 2026"*.

---

## §5 Staleness

Every row whose source has a last-modified stamp carries it as `source_updated_at`.

**The check:** compare the recorded stamp against the source's current one.
`recorded < current ⇒ **STALE**`.

For a Metabase card this is **one `get_card` metadata call — not a query.** Notion pages carry a
snapshot date. Repo files carry their commit SHA. Documents and the Sheet have no usable stamp, so
the column is simply absent from tables whose sources have none.

> **A STALE row is not wrong — it is unchecked.** Mark it `unverified`, open a `G-###`, then
> re-extract. Do not delete it and do not leave it reading `verified`.

**A cited card with no fingerprint at all is itself a gap.** Record it rather than leaving the
column blank.

---

## §6 Precedence — when sources disagree

1. **`hcv_metrics_queries.md`** — owner-authored, reconciled SQL, *for the metrics it covers*
2. **Observed Metabase card SQL**, as recorded in the two Notion inventories
3. **Governed store `metric.porter.*`** — authoritative for **naming and governance**; its formulas
   conflict with (1) and (2) in six known places
4. **The inventories' editorial judgement** — KPI tree, de-duplication rules, Doshi categories
5. **Sheet `HCV_Metrics_DD`** — target state, AI-drafted, unratified → `assumption` by default
6. **Card titles — never evidence** (§4)

Each rung's authority is scoped. Rung 1 is strongest **only for the metrics the pack covers** — it
is silent on the ~120 it does not. Rung 3 is strongest for **naming and governance**, not formulas.

> ### The absolute exception
> When pack, card, and store disagree — **and they do** — **do not resolve it.** Record every side,
> set `confidence: unverified`, open a `G-###`.
>
> Silently picking a side converts a known unknown into an invisible error. It is the worst thing
> you can do to this KB.

> ⚠️ **The Notion inventories under-report conflicts.** Three store-vs-pack conflicts found on
> 2026-08-14 appear in neither. Do not treat their contested-definition lists as complete — every
> metric this KB covers gets its own store-vs-pack-vs-card comparison.

---

## §7 Numbers versus definitions

**Never inline a metric value into a definition.** Values are point-in-time; definitions are not.

Values live in **one place**: [business.md](./business.md)'s labelled snapshot section, tagged by
**data period** (`May-2026`), never by review name ("June MBR"). A definition may say *"see the
snapshot in business.md"* and nothing more.

**Monotonic counters are never recorded as facts.** View counts, run counts and query-time averages
drift every time anyone opens the card. They are not facts about the business.

---

## §8 Correction, closure, and gap protocols

### §8.1 Correcting a row

**Edit it in place.** Then: refresh its `last_verified` override (§2.2) · re-check its
`source_updated_at` · adjust `confidence` · add a `note` saying **what changed and why**.

> **Do not delete the row and add a new one.** The ID is how other files point at this fact. A
> replaced ID silently breaks every reference to it, and the KB loses the record that it was ever
> wrong.

### §8.2 Adding a gap

Every `G-###` needs:

- **`statement`** — what is unknown or in conflict
- **`conflicting positions`** where two sources disagree — *both* sides, quoted, with their refs
- **`next_action` — specific enough to execute.** This is what makes GAPS a backlog rather than a
  complaint list. *"Ask the metric owner which `<60s` treatment is canonical"* is executable.
  *"Investigate fulfilment"* is not.
- **`status`** — §8.3

### §8.3 Status vocabulary

`OPEN` · `BLOCKED` (needs a person or a decision, not more analysis) · `CLOSED` (with date and
resolving ID).

Severity qualifiers: `OPEN — high` · `OPEN — low` · `OPEN — informational` ·
`OPEN — mechanical, do next` · `OPEN · ESCALATED` · `BLOCKED — owner, structural`.

**Closing a gap:** mark the row `CLOSED` with the date and the resolving ID, and **strike the ID
through** (`~~G-0nn~~`). **Do not delete it.** Consequences that outlive the closure get **spin-off
IDs appended at the end of the series**, never inserted into the gap.

**Escalations stay after the fix.** Write *"raised with the card owner on `<date>`; do not remove
this row when fixed — close it with the date and the fixing card version"*, so the KB records that
the trap once existed.

### §8.4 GAPS section map

Lettered, grown by suffix (`F` → `F2` → `F3`), never renumbered.

| § | Class |
|---|---|
| A | Metric-definition conflicts — pack vs card vs store |
| B | Code defects in source cards — hard-coded filters, inert parameters, logic bugs |
| C | Source & provenance gaps — missing fingerprints, unreachable systems |
| D | Naming / ID collisions, including cross-vertical PTL↔HCV |
| E | Defects *inside a single source* — where one document contradicts itself |
| F | Strategic / metric-store posture |
| G | Coverage — metrics. One row per index-only metric, sharing a class-level `next_action` |
| H | Coverage — cards and surfaces not opened, as a stated boundary |

### §8.5 Three gap types that are easy to omit

- **Informational anti-gaps** — a row whose purpose is to stop a future session "fixing" something
  that is already correct. *"This row exists so nobody treats correct code as a bug."*
- **Negative evidence** — *searched, zero hits* / *rejected, not a match*, kept explicitly distinct
  from *not looked at*. Knowing something was searched for and is absent is a finding.
- **Source-defect rows** — where a single source is internally wrong (arithmetic that does not add
  up, a summary contradicting its own detail). **Do not silently correct it.** Record the defect and
  keep quoting the source verbatim.

---

## §9 Never put this in the KB

- Credentials, tokens, connection strings
- Personal data — phone numbers, emails, names, addresses. **Column *names* are schema facts**
  (`customer_mobile` ✓); their *values* are not
- **Live or derived query results.** A number pulled from a query is not a schema fact and does not
  belong in a topic file. If it is a reported figure, it goes in the snapshot (§7) with its period
- Monotonic counters (§7)
- Anything you would not want a new joiner to read as settled truth

---

## §10 Session exit checklist

Before you finish a session that touched `kb/`:

1. **Did you add a topic file?** Add it to [CONTEXT.md](./CONTEXT.md)'s routing table — **or
   nothing will ever load it.**
2. **Did you re-check every row in a file?** Only then refresh that file's `last_verified`.
   Otherwise use a per-row override (§2.2).
3. **Did every new fact get a `source_ref` and a `confidence`?** If one could not, is it in
   [GAPS.md](./GAPS.md) instead (§1)?
4. **Did you close a gap?** Strike it through with the date and resolving ID — do not delete it
   (§8.3).
5. **Did you change `WALKTHROUGH.md` or the published artifact?**

   > ⚠️ **These two have no automated sync.** No linter, no CI check, no review gate enforces it.
   > PTL's equivalent pair drifted once and was caught by audit rather than by process. Any edit to
   > one needs a deliberate matching edit to the other, in the same session.
