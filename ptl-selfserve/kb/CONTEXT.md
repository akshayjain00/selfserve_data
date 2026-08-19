# CONTEXT.md — PTL self-serve knowledge base

**Doing analytics work on Porter's PTL vertical? Read this file fully, then load only the topic files your task needs** — not all of them. `last_verified: 2026-07-29`

---

## Load protocol

| Your task | Load |
|---|---|
| "What is PTL / what does a term mean?" | [business.md](./business.md) |
| "How is metric X defined?" | [metrics.md](./metrics.md) → then [dashboards.md](./dashboards.md) for its card |
| "Which table/column holds X?" | [data-model.md](./data-model.md) |
| "Where does this number come from?" | [dashboards.md](./dashboards.md) |
| "Is this fact still true?" | [CONTRIBUTING.md](./CONTRIBUTING.md) §5 (staleness check) |
| "What's unresolved?" | [GAPS.md](./GAPS.md) |
| About to edit this KB | [CONTRIBUTING.md](./CONTRIBUTING.md) — **required** |

**Every fact is a table row with a stable ID** (`B-###` business, `M-###` metric, `T-###` table,
`G-###` gap), carrying its source, last-verified date, and confidence. Cite IDs when you answer.

---

## What PTL self-serve covers

**PTL = Part Truck Load** — Porter's intercity shared-truck vertical: multiple customers'
consignments clubbed onto one truck (versus FTL, where one customer books the whole vehicle). The
warehouse schema is `partload_application`.**pre-PMF**, operationally
assisted, and running **deeply negative gross margin** (−73% to −161%/order, Dec-25→till date).

**"PTL self-serve"** is the effort to turn PTL's narrative-heavy monthly ProdOps review into
governed, queryable metrics.— numbers are unvalidated and base context like human knowlegde needs to continuosly evolve through decisions and learning  .

---

## The 11 core metrics — quick reference

Full definitions, caveats and provenance: [metrics.md](./metrics.md). ⚠️ = do not quote without
reading its gap row first.

| id | metric | formula | confidence |
|---|---|---|---|
| M-001 | **North Star** — Monthly Transacting Business Customers | unique business customers with ≥1 completed order/month | ✅ `verified` — card 39117 reproduces Mar/Apr-26 exactly. ⚠️ inherits its defects: offline leg **unfiltered for internal users** (`G-141`), D3 unmeetable (`G-142`) |
| M-002 | Completed Orders (business) | `COUNT(DISTINCT external_id) WHERE state=3` | `verified` |
| M-003 | Total Fulfilment % | `100 × completed / placed` (`state=3` / all states) | `verified` |
| M-004 | Effective Fulfilment % | `100 × completed / (placed − cbdf_cancels)` | ⚠️ `unverified` (`G-002`) |
| M-005 | CBDF % | `100 × cancels(state=4, **no** vehicle) / placed_orders` | `verified` mechanic, ⚠️ `G-001` |
| M-006 | CADF % | `100 × cancels(state=4, vehicle assigned) / placed_orders` | `verified` mechanic, ⚠️ `G-001` |
| M-007 | Avg Orders per Trip (clubbing) | `orders / batches` — **all batches, no ≥2 restriction** | `verified` (formula **corrected** 2026-08-07, `G-157`), ⚠️ `G-010` |
| M-008 | AOV | `SUM(revenue WHERE state=3) / completed` | ⚠️ `unverified` — 3 revenue bases (`G-004`) |
| M-009 | Business Session Conversion % | `100 × orders / sessions` | ⚠️ **`unverified`** — cited card counts a *click*, no business filter (`G-158`); `ptl_fe_events.user_type` **does not exist** |
| M-010 | New Business Users (monthly) | first-order count in month | ⚠️ `unverified` — not implemented (`G-010`) |
| M-011 | M1 Business Retention % | `100 × m0_retained / m0_business_users` | `verified`, ⚠️ base gap (`G-010`) |

**25 of 85 catalogue rows** have a full `M-###` entry (via 23 M-numbers — some close >1 row);
**60 remain index-only** ([metrics.md](./metrics.md) §2). ⚠️ **4 of the 25 are documented but dead**
(`G-154`). Frozen original audit: 15 `confirmed` · 6 `contradicted` · 64 `unverified`, 3 of which
were **mapping errors** (`G-148`, `G-149`). Detail + the 14 possibly-untrackable supply rows
(`G-151`): [GAPS.md](./GAPS.md) §F3–§F5.

### Three facts that prevent most errors
- **`orders.state`**: `3=Completed, 4=Cancelled` — `T-001`, verified on db73. The `0/1/2` labels are db83-only (`T-001a`).
- **Business customer** = `customers.frequency IN (1,2,3,4)` on `oms_public.customers`, joined by
  mobile; unmatched customers silently fall to *Personal* (`T-020`, `T-021`).
- **Units**: fares are **paise** `/100` (`T-010`/`T-011`, verified). Weights grams `/1000` is ⚠️ db83-only (`T-012`).

---

## Precedence ladder — when sources disagree

**1.** observed card SQL *(strongest)* → **2.** `DECISION_LOG` D1–D7 *(owner rulings)* → **3.** iteration-1
catalog → **4.** journey/proposal docs → **5.** Notion Product Ops Review *(weakest for definitions)*

**Absolute exception:** when observed SQL contradicts an owner ruling, **do not resolve it.** Record
both sides, set `confidence: unverified`, open a `G-###`. Silently picking a side converts a known
unknown into an invisible error — it is the worst thing you can do to this KB.

---

## Confidence and staleness

- **`verified`** — read directly from underlying SQL/code, or an explicit owner ruling.
- **`unverified`** — asserted by a source but not confirmed against SQL, or sources conflict.
- **`assumption`** — inferred by reasoning, stated nowhere.

A **card title is never evidence.** Downgrading confidence is always allowed; upgrading needs new
cited evidence.

**Staleness:** each row carries `source_updated_at` (the source's own last-modified stamp). If the
source's current `updated_at` is newer, the row is **STALE** — re-extract. For a Metabase card that
is one metadata call (`get_card`), **not** a query. See [CONTRIBUTING.md](./CONTRIBUTING.md) §5.

---

## Hard rules

1. **Never run a production query** without explicit owner go-ahead. Metadata reads only. If a
   definition can't be resolved from SQL text, that's an `[unverified]` finding — not a reason to run it.
2. **Never put credentials, tokens, or personal data in this KB.** Column *names* are schema facts
   (`customer_mobile` ✓); values, phone numbers, emails, names, addresses are not.
3. **Aggregate-then-ratio** for every derived ratio. Never average daily ratios (`B-030`).
4. **Week = Saturday→Friday**, completed weeks only, latest leftmost (`B-031`).
5. Divide-by-zero → **null** (`B-032`). Percentage movements in **"pp"** (`B-033`).
6. **Never inline a metric value into a definition.** Values are point-in-time; they live only in
   `business.md`'s labelled snapshot section, tagged by **data period** (Apr-26), not review name.
7. Timestamps are **UTC**; convert with `+330 min` / `CONVERT_TIMEZONE`. Never wrap a timestamp column
   in an expression inside `WHERE` — it kills partition pruning (`T-030`, `T-031`).

---

## Source locations

Repo `github.com/akshayjain00/selfserve_data`. **`kb/` is published on two branches and is
self-contained** — every link inside is relative. Siblings exist **only** on
`claude/ptl-metric-catalog-map`: `ptl-selfserve/DECISION_LOG.md` (owner rulings D1–D7),
`iteration-1-ptl-*.md` (the 85-row catalog + open questions), `selfserve_nlq/` (prototype). On
`claude/pnm-metrics-catalog-map-vg251i` those are absent — switch branches or use the pinned SHA.
**Provenance:** `repo@<sha>:<path>#L<n>`, never a bare path or branch name. PTL work is pinned
`7a43470`; PnM reference material is `claude/pnm-p80-orderedits` pinned `851886f`. Neither branch
holds both; SHAs are the only stable citation.

**Dashboards** (`metabase.prod-internal.porter.in`): `4198` Business Observability · `4569` Customer ·
`card/33519` Ops Orders Details · `4793` **canonical cancellation** (D5). Card index: dashboards.md.

---

## State of the work — read before promising anything

- 🛑 **FOUR METRICS ARE DEAD, NOT JUST UNVERIFIED (2026-08-07).** `M-017` Perfect Order Experience
  returns **0% for every month since Feb-26** on a live leadership dashboard; `M-018`'s on-time cards
  return **zero rows**. Cause: `gsheet_sync.ptl_table` stopped syncing after Jan-2026 (`T-074`), and
  the `LEFT JOIN` renders the failure as a confident `0%` instead of an error. All four were ✅
  `verified` here for a quarter — **this KB tracked whether definitions were right, never whether
  metrics still produced a number.** Live replacement: `M-022` (`card/43551`). → `G-154`, `G-155`
- **Resolved:** `state` enum and business-customer rule, both from card SQL (`T-001`, `T-020`).
- **Closed 2026-08-07:** `G-005` (customer masters agree to ~0.013% at session grain — closed by
  *measurement*, not a ruling) · `G-012` (`ptl_fe_events.user_type` never existed) · `G-041` → `M-021`.
- **NSM is RECONCILED** (2026-07-30) — card 39117 reproduces Mar/Apr-26 exactly, so the leadership
  figure inherits its defects (`G-141` internal users, `G-142` D3). **Still unverified:** the `<60s`
  treatment for **CBDF/CADF/fulfilment** — three incompatible semantics live in production.
- **D3 is breached by one builder** (`trips_sql`); `retention_sql`'s single base is a registry
  mismatch, not a D3 breach; Business Session Conversion's is **correct** — D6 exempts it (`G-119`).
- ⚠️ **Strategic:** Project Argus (the cross-vertical Metric Store) **rejected** the hand-rolled,
  no-semantic-layer shape ruling D2 builds on. Treat raw-table self-serve as provisional (`G-132`).
- **67 substantive gaps open** (74 rows in §A–§F5, 7 closed) + 60 uncovered metrics (§G) + 93
  unopened cards (§H) → [GAPS.md](./GAPS.md). *(Corrected 2026-08-07; the prior "48" reconciled to
  nothing.)* **BLOCKED** gaps need an owner decision, not more analysis.
- ⚠️ **Rule 1 has been relaxed twice under explicit owner go-ahead** (2026-07-30 card execution,
  2026-08-07 card execution + read-only warehouse queries). Every fact so sourced says so inline.
  Definitions here are documentation; **no metric *value* is recorded in this KB** (CONTRIBUTING §7/§9).
  Nothing is stakeholder-ready.
