# CONTRIBUTING — how to change this knowledge base

**Read this before editing any file in `kb/`.** Entry point: [CONTEXT.md](./CONTEXT.md).

This KB is designed to be corrected incrementally by AI sessions and humans alike. The rules below
are what keep it from rotting into confident nonsense. Sections are **stably numbered** — other
files deep-link to them by number (`CONTRIBUTING.md §6`), so §-numbers are part of the contract and
are never reordered.

---

## §1 The one rule that matters

> **A fact without provenance is not a fact. Do not add one.**

Every row in every topic file carries where it came from and how much to trust it.

**The demotion rule.** A row that cannot carry provenance and confidence is a
[GAPS.md](./GAPS.md) entry, **not a KB fact**. Demoting is always correct; writing an unsourced fact
never is. A well-written gap is one of the most useful things in here.

---

## §2 Row schema

| Column | Meaning | Required |
|---|---|---|
| `id` | Stable identifier — see §3. **Never reused, never renumbered.** | **always** |
| `statement` | The fact itself — one sentence or one formula | **always** |
| `source_ref` | Where it came from — see §4 | **always** |
| `confidence` | `verified` / `unverified` / `assumption` — see §5 | **always** |
| `readiness` | `prototype_only` / `stakeholder_ready` / `blocked` / `not_built` — **`metrics.md` only**, see §7 | metrics only |
| `aliases` | Other names for this thing | if any |
| `note` | Caveats, conflicts, "see `PNM-G-012`" | if any |

**`last_verified` is declared once per file**, in the header under the title — not repeated on every
row, which would widen every table for a value identical across it. A row re-checked on a different
date carries an inline override in its `note` (`last_verified 2026-08-26`). **A file-level date is a
claim about every row in that file** — do not refresh it unless you re-checked them all.

**Tables carry only the columns that apply to them.** A glossary table needs no `readiness`; a units
table replaces `statement` with `column | stored as | means`. The four **always** columns are the
contract; the rest are as-needed. `metrics.md` uses per-metric blocks rather than rows, because a
metric definition carries a formula, caveats and several sources that do not fit one line — the four
required elements are still present in every block.

**Single-source files may declare `source_ref` and `confidence` once in the header**, exactly as
`last_verified` is declared once. This is permitted **only** where every row genuinely shares both
values, and the header must say so. The moment a second source or a second confidence enters, both
become per-row columns.

---

## §3 ID namespace — `PNM-` is mandatory

**Every id in this KB carries the `PNM-` vertical prefix.**

| Series | Meaning | File |
|---|---|---|
| `PNM-B-###` | business fact, glossary term, house rule | [business.md](./business.md) |
| `PNM-M-###` | metric definition | [metrics.md](./metrics.md) |
| `PNM-T-###` | table, column, enum, unit, join key | [data-model.md](./data-model.md) |
| `PNM-S-###` | source artifact + its freshness state | [sources.md](./sources.md) |
| `PNM-G-###` | gap, conflict, open question | [GAPS.md](./GAPS.md) |

**Why the prefix is not optional.** PTL and HCV run their own knowledge bases in this repo, each
with its own `M-001`. Bare `M-001` is ambiguous across three verticals and the same acronym means
different things in each (`PNM-G-064`). The prefix makes a citation resolvable on sight.

⚠ **A third namespace exists and must not be confused with these.**
`../coverage-map/metric-coverage.json` uses bare **`PNM-###`** (`PNM-001`…`PNM-167`) for Argus data-
dictionary rows. **A bare `PNM-###` is an Argus DD id; a `PNM-<letter>-###` is a KB row.** They are
different things and no mapping between them exists — see `PNM-G-052`.

**IDs are append-only.** To add a fact, take the next unused number in that series. Never renumber —
other files and past sessions cite them. If an id is retired, record that it was retired; never
reuse the number.

---

## §4 `source_ref` format

Use the most durable form available:

| Source type | Format | Example |
|---|---|---|
| Repo file | `repo@<sha>:<path>` | `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` |
| Owner ruling | `DECISION_LOG:D<n>` | `DECISION_LOG:D4` |
| Verification entry | `DECISION_LOG:V<n>` | `DECISION_LOG:V3` |
| Metabase card | `metabase:card/<id>` | `metabase:card/47576` |
| Metabase dashboard | `metabase:dashboard/<id>` | `metabase:dashboard/4076` |
| Live schema read | `live:INFORMATION_SCHEMA@<date>` | `live:INFORMATION_SCHEMA@2026-07-29` |
| Non-version-controlled file | `local:<path>` — **weakest form, use only when nothing better exists** | `local:ProdOps/pnm/pnm_mbr_monthly_metrics/queries.py` |

**Never cite a bare file path, a branch name, or a local absolute path.** Branches get merged and
deleted; local clones move between machines. A commit SHA cannot drift — a session re-verifying a
fact reads the exact bytes the last one read.

### §4.1 The `local:` ceiling, and why it bites PnM harder than PTL

A fact whose only source is `local:` **can never be more than `unverified`**. There is no SHA, so the
bytes can change with no signal.

This is not a corner case here. **PnM's single strongest source — the owner's live-validated MBR
automation — lives outside this repo** at `ProdOps/pnm/pnm_mbr_monthly_metrics/queries.py`, so it is
permanently `local:`-capped. The KB works around this: **`sqlgen.py` is that automation's in-repo
mirror**, reconciled against it field-by-field (`DECISION_LOG:V3`, `V4`), so rows cite `sqlgen.py` at
a SHA and let the automation ride as `local:` corroboration. See §6 rung 2 and `PNM-G-003`.

---

## §5 Confidence levels — use them strictly

| Value | Means | Bar to claim it |
|---|---|---|
| `verified` | Read directly from the underlying SQL, code, or an explicit owner ruling | You saw the expression. A card *title* is never sufficient |
| `unverified` | Asserted by a source, not confirmed against SQL/code — or sources conflict | Anything a document claims that you did not confirm |
| `assumption` | Inferred by reasoning, stated nowhere | You worked it out. Say so |

**Downgrading is always allowed. Upgrading requires new evidence, cited.**

Do not upgrade `unverified` → `verified` because a fact *seems* right, because two documents agree,
or because it has been in the KB a long time. **Agreement between two unverified sources is still
unverified.**

### §5.1 What `verified` attests to here — read this before quoting one

In this KB, `verified` means **"this is what the prototype computes"**, read from `sqlgen.py` or
`metrics_registry.py` at the cited SHA, or ruled explicitly in `DECISION_LOG` D1–D10.

`DECISION_LOG:V3` and `V4` showed the prototype reproduces the owner's automation **exactly** — but
only for the months and metrics actually reconciled. Outside that slice, "the mirror is exact" is an
extrapolation, not a finding (`PNM-G-004`). **`verified` is not `stakeholder_ready`** — see §7.

---

## §6 Precedence — when sources disagree

```
1. Owner ruling — DECISION_LOG D1–D10, or an explicit in-session owner ruling   ← strongest
2. The live-validated MBR automation, where a named reconciliation demonstrably
   happened (cited in-repo via its exact mirror, sqlgen.py)
3. Metabase card SQL, where actually read
4. Live schema — INFORMATION_SCHEMA / Data Catalog
5. metrics_registry.py — behavioural fields (built, readiness, section wiring)
6. iteration-1 metric catalog (the legacy 49-column pipeline catalogue)
7. iteration-2 ledger · iteration-3 spec · HANDOFF.md · reference/README.md
   · metrics_registry.py prose fields (definition, aliases)
8. Argus PnM Metrics DD · Notion MoM doc · Notion Demand DB · Notion schema guide  ← weakest
```

**This ladder is PnM's own. Do not import PTL's** — theirs is topped by observed card SQL, and the
top two rungs are **inverted** here. The reasoning, rung by rung:

**1 — Owner ruling.** PnM's load-bearing facts are *business-attribution* decisions no query can
yield. `D4` — "Nano is labour-only help owned by LA; include it in leads, exclude it from orders and
TPO" — is not discoverable in any table; it states which business unit owns a booking. PTL asks
*"what does this compute?"* (SQL settles it); PnM asks *"whose population is this?"* (only the owner
settles it).

**2 — The validated automation.** Executed against production **and** reconciled field-by-field
(`V3`, `V4`). ⚠ Two limits, stated on every row that leans on it: it is out-of-repo and cited through
`sqlgen.py` (§4.1), and its reconciliation covers a bounded slice (`PNM-G-004`).

**3 — Metabase card SQL.** *Demoted from PTL's rung 1.* `config.py` names card **#30311** the
"canonical methodology", and `D6` overrides it: #30311 strips Nano from the whole funnel,
contradicting `D4`. A card that lost to a ruling on first contact cannot sit above rulings
(`PNM-G-022`).

**4 — Live schema.** *No PTL analogue.* Authoritative for **existence and type**, silent on
**definition**. It settles factual disputes — `HS_TICKETS` has no `ORDER_ID`; the six OTA columns
exist nowhere — but **it can never settle a definitional fork.** It outranks the Notion schema guide,
which is a stale snapshot contradicted in five places (`PNM-G-023`).

**5 — Registry behavioural fields.** `metrics_registry.py` is *code that runs*: `SECTIONS[…]["built"]`
and `["readiness"]` gate `ask.py` at runtime, so they bind behaviour in a way no document does.

**6 — iteration-1 catalog.** **Doubly weakened**: it documents the legacy 5-file pipeline that `D3`
established could never execute, and `D5` replaced. Its metric names exist nowhere in the shipped
system. A record of *intent*, never of behaviour.

**7 — Project documents and registry prose.** `HANDOFF.md` self-declares stale in its own header. The
registry's `definition` strings are *claims about* the SQL, not the SQL.

**8 — Argus DD and Notion.** Authoritative for **which metrics PnM is expected to have** and for
**published values** — `D6` makes the Notion Demand DB a reconciliation baseline, a *value* authority
— never for how a metric is computed.

### §6.1 Rules that ride with the ladder

- **Tier is a property of the CLAIM, never of the document.** `metrics_registry.py` holds rung-5 and
  rung-7 claims side by side and is the standing proof. Assign per claim, always.
- **A claim that names no reconciliation surface is rung 7.** Naming one is necessary, not
  sufficient: if the KB's own reading of that surface contradicts the claim, the reconciliation did
  not happen.
- **Where a higher rung outranks a KB row, that row's `statement` is CORRECTED** — not merely
  annotated — with the superseded wording preserved verbatim in its `note`. Annotation alone makes a
  precedence ruling indistinguishable from no ruling.
- **Tier governs precedence, never confidence.** A rung-1 claim can outrank every row and still be
  `unverified`. See §5.

### §6.2 The absolute exception

**When the validated automation's SQL contradicts an owner ruling — rungs 1 vs 2 — do not resolve
it.** Record both sides, set `confidence: unverified`, and open a `PNM-G-###` naming the exact action
that would settle it.

Silently picking a side converts a **known** unknown into an **invisible** error, and an invisible
error in a KB is worse than no KB, because it looks right. This exception does not extend to any
other pair of rungs.

---

## §7 Readiness — a second axis, and it is not confidence

**PnM carries a dimension PTL does not.** Every metric belongs to a section with a `readiness`:

| Value | Means |
|---|---|
| `prototype_only` | Reconciles with the owner's validated automation. **Not signed off for stakeholder or leadership use** |
| `stakeholder_ready` | Owner-promoted. **Nothing is currently in this state** |
| `blocked` | Cannot be queried at all until a structural problem is resolved |
| `not_built` | Not implemented |

**`readiness` and `confidence` are orthogonal and neither substitutes for the other.** A metric can
be `verified` (its SQL was read) and still `prototype_only` (not safe to put in front of leadership).
Reporting one when asked for the other is a defect.

**Only the owner promotes readiness**, by editing `metrics_registry.py` deliberately. No AI session
may promote anything, and no amount of successful reconciliation promotes a section on its own.
⚠ **This rule is stated only in the registry's module docstring — rung 7 prose, enforced by
convention rather than by code, and backed by no owner ruling** (`PNM-B-042`, `PNM-G-041`).

---

## §8 Numbers vs definitions

**Definitions are durable. Values are point-in-time.**

- Metric *definitions* live in `metrics.md` as normal blocks.
- Reconciled *values* live **only** in the clearly-labelled snapshot section of `business.md`, and
  each carries its data period (`2026-05`).
- **Never inline a value into a definition.** A KB that says "conversion is 15.25%" is wrong the
  moment the month rolls, while still looking authoritative.

---

## §9 Staleness — PnM's check is not PTL's

PTL detects drift with one Metabase `get_card` metadata call. **PnM has almost no source carrying an
`updated_at`**, so `source_updated_at` is simply absent from most tables here (§2 permits this). The
check is per source type instead:

| Source type | Freshness check |
|---|---|
| In-repo file at a SHA | Re-read at the SHA. Free, deterministic, offline — a SHA cannot drift |
| MBR automation (out-of-repo) | **No check exists.** → `PNM-G-006` |
| `PROD_ELDORIA.MART.PNM_EXPERIENCE` | `INFORMATION_SCHEMA.COLUMNS` pre-flight — **the mart is under active construction and its schema has grown mid-project more than once.** Re-verify before any run → `PNM-G-007` |
| Metabase cards | `get_card` → compare `updated_at`. Not yet fingerprinted here → `PNM-G-008` |
| Notion schema guide | Snapshot-dated; already contradicted in five places → `PNM-G-023` |

A stale row is not wrong — it is **unchecked**. Mark it `unverified`, open a `PNM-G-###`, re-extract.

---

## §10 Never put in this KB

- Credentials, API keys, tokens, connection strings.
- Personal data: customer/vendor/supervisor names, mobile numbers, email addresses, physical
  addresses, Aadhaar numbers. **Column *names* are schema facts and are fine** (`CUSTOMER_MOBILE` is
  fine; a mobile number is not).
- Live or derived query results beyond the labelled snapshot in `business.md` (§8).
- Anything from a production query run without an owner go-ahead (`DECISION_LOG:D1`).

---

## §11 Adding, correcting, and logging

**To correct a fact:** edit that row in place. Update `statement`, adjust `confidence` if the
evidence changed, and add a `note` saying what changed and why, preserving the superseded wording.
Do not delete the row and add a new one — the id is a stable reference.

**To add coverage:** append a new row with the next id in that series. If it closes a gap, mark that
`PNM-G-###` row `CLOSED` with the date and the resolving id — **do not delete it.** A closed gap
records that the question was asked and answered.

**To log a gap you cannot close:** append to [GAPS.md](./GAPS.md). A gap row needs a `next_action`
specific enough to execute — "ask the owner which OTA threshold is correct, 500 m or 2 km", not
"investigate OTA".

**When you finish work that touched this KB:**
1. Every row you touched carries an honest `confidence`.
2. Every unresolved thing you hit is a `PNM-G-###` row with a real `next_action`.
3. [CONTEXT.md](./CONTEXT.md) stays **under 175 lines** — it is loaded every time. If it grew, move
   detail into a topic file and leave a pointer. An over-long entry point is how instructions start
   getting ignored.
4. If you added a topic file, add it to the `CONTEXT.md` load protocol, or nothing will ever load it.
