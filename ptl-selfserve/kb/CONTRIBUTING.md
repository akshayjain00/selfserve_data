# CONTRIBUTING — how to change this knowledge base

**Read this before editing any file in `kb/`.** This KB is designed to be corrected incrementally
by AI sessions and humans alike. The rules below are what keep it from rotting into confident
nonsense.

---

## 1. The one rule that matters

> **A fact without provenance is not a fact. Do not add one.**

Every row in every topic file carries where it came from, when it was last checked, and how much
to trust it. A row that cannot carry those is a `GAPS.md` entry, not a KB fact.

---

## 2. Row schema

Every fact in `business.md`, `metrics.md` and `data-model.md` is a table row, never prose:

| Column | Meaning | Required |
|---|---|---|
| `id` | Stable identifier — `B-###` business, `M-###` metric, `T-###` table/column, `G-###` gap. **Never reused, never renumbered.** | **always** |
| `statement` | The fact itself, one sentence or one formula. | **always** |
| `source_ref` | Where it came from. See §3. | **always** |
| `confidence` | `verified` / `unverified` / `assumption`. See §4. | **always** |
| `source_updated_at` | The *source artifact's* own last-modified timestamp. See §5. | **only when the source has one** — Metabase cards do; documents and repo files do not, so the column is simply absent from tables whose sources have no such stamp |
| `aliases` | Other names for this thing (jargon, acronyms, card titles). | if any |
| `note` | Caveats, conflicts, "see G-012". | if any |

**`last_verified` is declared once per file**, in the header line under the title — not repeated on
every row, which would triple the width of every table for a value that is identical across it. If a
single row is re-checked on a different date, it carries an inline override in its `note`
(`last_verified 2026-08-04`). **A file-level date is a claim about every row in that file**, so do not
refresh it unless you actually re-checked them all; re-check one row → override that row only.

**Tables may carry only the columns that apply to them.** A glossary table needs no
`source_updated_at`; a units table replaces `statement` with `column | stored as | convert`. The four
**always** columns are the contract; the rest are as-needed. `metrics.md` deliberately uses
per-metric blocks rather than a row, because a metric definition carries a formula, caveats and
multiple sources that do not fit one line — the same four required elements are still present in
every block.

**IDs are append-only.** To add a fact, take the next unused number in that series. Never renumber
existing rows — other files and past sessions cite them. If an ID is retired, record that it was
retired; never reuse the number.

---

## 3. `source_ref` format

Use the most durable form available:

| Source type | Format | Example |
|---|---|---|
| Repo file | `repo@<commit-sha>:<path>#L<n>` | `repo@7a43470:ptl-selfserve/DECISION_LOG.md#L18` |
| Metabase card | `metabase:card/<id>` | `metabase:card/33519` |
| Metabase dashboard | `metabase:dashboard/<id>` | `metabase:dashboard/4198` |
| Notion page | `notion:<page-id>` | `notion:3449c6eaaa6d8036bb51d679b6182767` |
| Owner ruling | `DECISION_LOG:D<n>` | `DECISION_LOG:D4` |
| Non-version-controlled file | `local:<path>` — **weakest form, use only when nothing better exists** | `local:01_reference_readonly/…/master_instruction.md` |

The `local:` form is an explicit escape hatch for source documents that live outside any repo (the
ProdOps workspace files, for instance). It carries a real cost: there is no SHA, so the bytes can
change without any signal. **Prefer any other form.** A fact whose only source is `local:` can never
be more than `unverified`.

**Never cite a bare file path, a branch name, or a local absolute path.** Branch names get merged,
rebased and deleted; line numbers shift on the next commit; local clones move between machines.
A commit SHA cannot drift — a session re-verifying a fact reads the exact bytes the last one read.
The local clone paths appear exactly once, in `CONTEXT.md`, as a convenience alias.

---

## 4. Confidence levels — use them strictly

| Value | Means | Bar to claim it |
|---|---|---|
| `verified` | Read directly from the underlying SQL, code, or an explicit owner ruling. | You saw the expression. A card *title* is never sufficient. |
| `unverified` | Asserted by a source, not confirmed against SQL/code — or sources conflict. | Anything a doc claims that you did not confirm. |
| `assumption` | Inferred by reasoning, stated nowhere. | You worked it out. Say so. |

**Downgrading is always allowed. Upgrading requires new evidence, cited.**

Do not upgrade `unverified` → `verified` because a fact *seems* right, because two documents agree,
or because it has been in the KB a long time. Agreement between two unverified sources is still
unverified.

---

## 5. Staleness — the `source_updated_at` check

No upstream system tells us when a metric *definition* drifts. dbt's freshness checks cover raw
source data, not SQL definitions. So we detect drift ourselves, cheaply:

```
if  source_updated_at (recorded in the row)  <  source's CURRENT updated_at
then the row is STALE — re-extract before trusting it
```

For a Metabase card, that is one metadata call:
`get_card(card_id=<id>)` → compare its `updated_at` to the row's `source_updated_at`.
**Do not run the query.** The timestamp alone tells you whether re-reading is needed.

A STALE row is not wrong — it is *unchecked*. Mark it `unverified`, open a `G-###`, then re-extract.

---

## 6. Precedence — when sources disagree

```
1. Observed card SQL          ← strongest
2. DECISION_LOG D1–D7         ← owner rulings
3. iteration-1 metric catalog
4. journey / proposal docs
5. Notion Product Ops Review  ← weakest for definitions
```

**The exception, and it is absolute:** when observed SQL contradicts an owner ruling (levels 1 vs 2),
**do not resolve it.** Record both sides, set `confidence: unverified`, and open a `G-###` row naming
the exact action that would settle it. Silently picking a side is the single most damaging thing you
can do to this KB — it converts a known unknown into an invisible error.

The Notion review is authoritative for *which metrics leadership cares about* and for reported
values. It is **not** authoritative for how a metric is computed.

---

## 7. Numbers vs definitions

**Definitions are durable. Values are point-in-time.**

- Metric *definitions* live in `metrics.md` as normal rows.
- Reported *values* live ONLY in the clearly-labelled snapshot section of `business.md`, and every
  one carries its data period (`Apr-26`), not the review's name (`May '26` review) — those differ.
- **Never inline a value into a definition row.** A KB that says "fulfilment is 56%" is wrong the
  moment the month rolls, while still looking authoritative.

---

## 8. Adding, correcting, and logging

**To correct a fact:** edit that row in place. Update `statement`, refresh `last_verified` to today,
re-check `source_updated_at`, and adjust `confidence` if the evidence changed. Add a `note` saying
what changed and why. Do not delete the row and add a new one — the ID is a stable reference.

**To add coverage:** append a new row with the next ID in that series. If it closes a gap, mark that
`G-###` row `CLOSED` with the date and the new ID — do not delete it. A closed gap is a record that
the question was asked and answered.

**To log a gap you found but cannot close:** append to `GAPS.md`. A gap row needs a `next_action`
that is specific enough to execute — "read dashboard 4793 and compare its CBDF SQL to card 49366",
not "investigate cancellation."

**When to bump `last_verified`:** only when you actually re-checked against the source *this session*.
Bumping it because you read the row, or because it looks fine, destroys the field's only purpose.

---

## 9. Never put in this KB

- Credentials, API keys, tokens, connection strings, account identifiers.
- Personal data of any kind: customer/driver/employee names, mobile numbers, email addresses,
  physical addresses, or card `creator` blocks. **Column *names* are schema facts and are fine
  (`customer_mobile` is fine; a mobile number is not.)**
- Live or derived query results. This KB documents definitions; it is not a data extract.
- Anything from a production query run. Metadata reads only.

---

## 10. Session protocol

When you finish work that touched this KB:
1. Every row you touched has a refreshed `last_verified` and an honest `confidence`.
2. Every unresolved thing you hit is a `G-###` row with a real `next_action`.
3. `CONTEXT.md` stays **under 150 lines** — it is loaded every time. If it grew, move detail into a
   topic file and leave a pointer. An over-long entry point is how instructions start getting
   ignored.
4. If you added a topic file, add it to the `CONTEXT.md` topic map, or nothing will ever load it.
