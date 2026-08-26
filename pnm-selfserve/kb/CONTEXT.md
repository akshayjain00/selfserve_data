# CONTEXT.md — PnM self-serve knowledge base

**Doing analytics work on Porter's PnM vertical? Read this file fully, then load only the topic files
your task needs** — not all of them. `last_verified: 2026-08-26`

## Load protocol

| Your task | Load |
|---|---|
| "What is PnM / what does this term mean?" | [business.md](./business.md) |
| "How is metric X defined?" | [metrics.md](./metrics.md) |
| "Which table/column holds X?" | [data-model.md](./data-model.md) |
| "Where did this number come from?" / "can I get it by city?" | [sources.md](./sources.md) |
| "Is this fact still true?" | [CONTRIBUTING.md](./CONTRIBUTING.md) §9 — staleness |
| "What's unresolved?" | [GAPS.md](./GAPS.md) |
| **About to edit this KB** | [CONTRIBUTING.md](./CONTRIBUTING.md) — **required** |

**Every fact is an addressable row** — `PNM-B-###` business · `PNM-M-###` metric · `PNM-T-###` table ·
`PNM-S-###` source · `PNM-G-###` gap. **The `PNM-` prefix is mandatory**: PTL and HCV keep their own
KBs in this repo and each has its own `M-001` (CONTRIBUTING §3). **Cite ids** — an uncited answer
cannot be checked.

## What PnM self-serve covers

**PnM is Porter's house-moving vertical** (`PNM-B-001`): a customer books a move, Porter allocates a
vendor crew and a supervisor, the crew executes, support handles what goes wrong. The funnel is
**opportunity ("lead") → order ("booking") → allocation → execution → support signals**, threaded by
`SR_ID` (`PNM-B-004`, `PNM-B-005`).

**"PnM self-serve"** is a closed-world natural-language layer over **the same Snowflake logic that
feeds the monthly business review** — removing the analyst-in-the-loop for routine metric questions
without loosening the numbers. It answers one catalogued metric at a time and **refuses everything
else** (`PNM-B-032`).

## The catalog — 47 metrics, 6 sections, all `prototype_only`

| Section | n | Counted on | Nano | Full detail |
|---|---|---|---|---|
| `leads` | 5 | `opp_created_ts` | **INCLUDED** | `PNM-M-001` |
| `orders` | 5 | `o_created_ts` | EXCLUDED | `PNM-M-002` |
| `derived` | 7 | both, same month | inherits both | `PNM-M-005`, `PNM-M-006` |
| `tpo` | 13 | **allocation completion** (+330 min → IST) | EXCLUDED | `PNM-M-008`…`PNM-M-011` |
| `p80_durations` | 7 | `SHIFTING_TS_IST` | EXCLUDED | `PNM-M-020`…`PNM-M-022` |
| `order_edits` | 10 | `ORDER_CREATED_TS_IST` | EXCLUDED | `PNM-M-030` |
| `ota` | **0** | — | — | ⛔ **BLOCKED** — `PNM-M-040` |

## Five facts that prevent most errors

1. **Nano is LA's, not PnM's — and the rule is asymmetric.** Leads **include** Nano; orders, TPO, p80
   and order_edits **exclude** it. So **conversion = non-Nano orders ÷ Nano-inclusive leads**, by
   design. Never "correct" it. (`PNM-B-010`…`PNM-B-013`)
2. **Every section counts on a different date.** A move booked in April and executed in May is in
   **April's** order count and **May's** duration figures. Both are right. **Always state the basis.**
   (`PNM-B-020`)
3. **The catalog is monthly and PnM-wide. It cannot be cut by city or by week.** The columns exist and
   the dashboards do it, but no city/weekly query was ever reconciled — so the catalog refuses and
   routes to [sources.md](./sources.md). (`PNM-B-021`, `PNM-B-022`, `PNM-G-070`)
4. **`orders_overall` includes orders that were later cancelled.** There is no cancelled filter.
   (`PNM-M-002`)
5. **Test orders are largely NOT excluded.** `IS_TEST_USER` exists only on two marts the catalog does
   not read; p80 and order_edits have **no user or test filter at all**. Do not claim otherwise.
   (`PNM-T-050`, `PNM-G-073`)

## Precedence ladder — when sources disagree

```
1. Owner ruling — DECISION_LOG D1–D10                                    ← strongest
2. The live-validated MBR automation, where reconciliation demonstrably
   happened (cited in-repo via its mirror, sqlgen.py)
3. Metabase card SQL, where actually read
4. Live schema — INFORMATION_SCHEMA / Data Catalog
5. metrics_registry.py — behavioural fields (built, readiness)
6. iteration-1 metric catalog (legacy, superseded)
7. iteration-2 · iteration-3 · HANDOFF · registry prose
8. Argus DD · Notion MoM / Demand DB / schema guide                      ← weakest
```

**This ladder is PnM's own — do not import PTL's.** PTL is topped by observed card SQL; **here the top
two rungs are inverted**, because PnM's load-bearing facts are *business-attribution* decisions no
query can yield (`D4`'s Nano rule is in no table). PTL asks *"what does this compute?"*; PnM asks
*"whose population is this?"* — and only the owner answers that.

**Rung 3 is demoted deliberately:** `config.py` calls card **#30311** the "canonical methodology" and
`D6` overrides it, because #30311 strips Nano from the whole funnel and contradicts `D4`
(`PNM-S-010`, `PNM-G-022`).

**Assign tier per CLAIM, never per document** — `metrics_registry.py` holds rung-5 and rung-7 claims
side by side. Where a higher rung outranks a row, **correct the row** and keep the superseded wording
in its `note`. Full rules: [CONTRIBUTING.md](./CONTRIBUTING.md) §6.

**The absolute exception (rungs 1 vs 2 only):** where the automation's SQL contradicts an owner
ruling, **do not resolve it.** Record both sides, set `confidence: unverified`, open a `PNM-G-###`.
Silently picking a side turns a known unknown into an invisible error.

## Confidence — and the second axis, readiness

- **`verified`** — read directly from underlying SQL, code, or an explicit owner ruling.
- **`unverified`** — asserted by a source but not confirmed against SQL, or sources conflict.
- **`assumption`** — inferred by reasoning, stated nowhere.

Downgrading is always allowed; **upgrading needs new cited evidence.** Two unverified sources agreeing
is still unverified.

⚠ **`verified` here means "this is what the prototype computes"** — read from `sqlgen.py` /
`metrics_registry.py` at a SHA. `V3`/`V4` proved the prototype matches the owner's automation exactly,
**for the months and metrics actually reconciled**; outside that slice it is extrapolation
(`PNM-G-004`). **No query was run to build this KB.**

⚠ **`readiness` is a separate axis and neither substitutes for the other.** A metric can be
`verified` **and** `prototype_only`. **Nothing is `stakeholder_ready`** — all six built sections are
`prototype_only`, `ota` is `blocked`, and **only the owner promotes** (`PNM-B-040`…`PNM-B-043`,
CONTRIBUTING §7).

## Hard rules

1. **Never run a production query without an explicit owner go-ahead.** Dry-run is the default
   (`PNM-B-034`).
2. **Never put credentials or personal data in this KB.** Column *names* are schema facts
   (`CUSTOMER_MOBILE` ✓); values, numbers, names, addresses are not (CONTRIBUTING §10).
3. **Aggregate-then-ratio.** Ratios are built from raw counts, never by averaging stored ratios
   (`PNM-B-030`). Divide-by-zero → **NULL** (`PNM-B-031`).
4. **Never inline a value into a definition.** Values live only in the labelled snapshot in
   [business.md](./business.md), tagged by data period (CONTRIBUTING §8).
5. **An in-progress month is MTD and must be labelled so.** Future months are refused
   (`PNM-B-033`).
6. **Replicate quirks, disclose them, never silently fix them.** Correcting a semantic is a
   *definition change* and the owner's call (`PNM-B-038`). The three shipped quirks: "Supervisor
   Assigned" actually reads `SUPERVISOR_ACCEPTED_TS_IST` (`PNM-M-021`); `location_adoption_pct` and
   `pct_orders_location_modified` are one number under two names (`PNM-M-030`); the Nano filter form
   differs by section on purpose (`PNM-B-014`).
7. **Never edit `../coverage-map/`.** It is a **projection** of this KB, not a progress tracker — its
   rows cite back into these files. Fix the KB, then re-derive it.

## Source locations

Repo `github.com/akshayjain00/selfserve_data`, branch **`main`**. `kb/` is self-contained — all links
relative. **Provenance format:** `repo@<sha>:<path>` — never a bare path or a branch name.

Siblings, referenced but never modified by this KB: `../DECISION_LOG.md` (D1–D10, V1–V4 — rung 1) ·
`../selfserve_nlq/` (the prototype) · `../coverage-map/` (the 167-row Argus projection) ·
`../pnm-gem-knowledge.md` (the 86 KB narrative KB this was re-cut from).

⚠ **PnM's strongest source is out-of-repo** — the MBR automation at
`ProdOps/pnm/pnm_mbr_monthly_metrics/queries.py`. It can only be cited `local:` and is therefore
capped at `unverified`; the KB reaches it through `sqlgen.py`, its in-repo mirror
(CONTRIBUTING §4.1, `PNM-G-003`).

## State of the work — read before promising anything

- **What was actually reconciled, and what was not.** `V3` matched 12 values for 2026-05
  (leads, orders, `conversion_overall`, the 8 channel counts, `orders_base`, `tpo_overall`,
  `tpo_vendor_raised`). `V4` matched p80 against the baseline CSV — **bit-exact on 3 of 8 months**,
  within ±2.5% on the rest — and validated order_edits by **byte-identity with the automation plus
  property checks, as it has no baseline**. **16 of the 47 ids were never individually reconciled**
  (3 channel conversions, 3 order-mix, 10 TPO stage metrics) → `PNM-G-004`. **Nothing is promoted.
  Nothing has been opened to stakeholders.**
- **`ota` is BLOCKED** — its six original columns exist in no table, and the definition itself is
  disputed: 30 min + **500 m** (Notion) vs 30 min + **2 km** (pipeline). `OTA_FLAG` now exists and
  encodes an undocumented third rule (`PNM-G-024`).
- **53 open gaps**, **8 owner-blocked**. The biggest: **no city or weekly cut exists, and that is
  precisely what city ops will ask for** (`PNM-G-070`).
- ⚠ **iteration-1's metric catalog is superseded and unannotated.** Six of its definitions are
  actively wrong (`PNM-G-030`…`PNM-G-037`). Do not read it as current.
- ⚠ **`PNM_EXPERIENCE` is "under active construction"** and has grown mid-project more than once —
  re-verify its schema before any run (`PNM-G-007`).
- **No number in this KB has been validated against the warehouse in this pass. No query was run.**
