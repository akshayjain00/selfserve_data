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
| M-007 | Avg Orders per Trip (clubbing) | `clubbed_orders / clubbing_trips` (batches ≥2 orders) | `verified`, ⚠️ filter gap `G-010` |
| M-008 | AOV | `SUM(revenue WHERE state=3) / completed` | ⚠️ `unverified` — 3 revenue bases (`G-004`) |
| M-009 | Business Session Conversion % | `100 × orders / sessions` | `verified`, ⚠️ different "business" def (`G-012`) |
| M-010 | New Business Users (monthly) | first-order count in month | ⚠️ `unverified` — not implemented (`G-010`) |
| M-011 | M1 Business Retention % | `100 × m0_retained / m0_business_users` | `verified`, ⚠️ base gap (`G-010`) |

**65 further catalog metrics remain index-only** ([metrics.md](./metrics.md) §2). **20 of 85 are now
fully written up** (11 v1 + 9 promoted 2026-07-30: `M-012`–`M-020`), up from 11. The original catalog
audit (frozen) = **85 rows**: 15 `confirmed`, 6 `contradicted`, 64 `unverified` → 70 not confirmed
*at audit time* — 2 of those 64 turned out to be **catalogue mapping errors** (`G-148`, `G-149`).
See [GAPS.md](./GAPS.md) §F3/§F4, incl. 12 owner/vehicle-supply metrics possibly untrackable (`G-151`).

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
self-contained — every link inside it is relative, so it works from either.** Its sibling assets are
**only** on `claude/ptl-metric-catalog-map`:
```
ptl-selfserve/kb/               ← you are here (on BOTH branches)
─── the following exist ONLY on claude/ptl-metric-catalog-map ───
ptl-selfserve/DECISION_LOG.md         ← owner rulings D1–D7 (domain authority)
ptl-selfserve/iteration-1-ptl-*.md    ← the 85-row catalog + ranked open questions
ptl-selfserve/selfserve_nlq/          ← prototype (metrics_registry, sqlgen, ask.py)
```
If you are on `claude/pnm-metrics-catalog-map-vg251i` those four are absent — switch branches or
use the pinned SHA below to read them.
**Provenance format:** `repo@<commit-sha>:<path>#L<n>` — never a bare path or branch name. Two
clones of this repo exist on **diverged branches**; PTL work is on `claude/ptl-metric-catalog-map`
(pinned `7a43470`), PnM reference material on `claude/pnm-p80-orderedits` (pinned `851886f`).
Neither branch holds both. Commit SHAs are the only stable citation.

**Dashboards:** `metabase.prod-internal.porter.in` — `dashboard/4198` (Business Observability),
`dashboard/4569` (Customer), `card/33519` (Ops Orders Details), `dashboard/4793` (**canonical
cancellation**, ruling D5).

---

## State of the work — read before promising anything

- **Resolved:** `state` enum and business-customer rule, both from card SQL (`T-001`, `T-020`).
- **NSM is RECONCILED** (2026-07-30) — card 39117 reproduces Mar/Apr-26 exactly, so the leadership
  figure inherits its defects (`G-141` internal users, `G-142` D3). **Still unverified:** the `<60s`
  treatment for **CBDF/CADF/fulfilment** — three incompatible semantics live in production.
- **D3 is breached by one builder** (`trips_sql`); `retention_sql`'s single base is a registry
  mismatch, not a D3 breach; Business Session Conversion's is **correct** — D6 exempts it (`G-119`).
- ⚠️ **Strategic:** Project Argus (the cross-vertical Metric Store) **rejected** the hand-rolled,
  no-semantic-layer shape ruling D2 builds on. Treat raw-table self-serve as provisional (`G-132`).
- **48 substantive gaps** + 74 uncovered metrics + 93 unopened cards → [GAPS.md](./GAPS.md).
  **BLOCKED** gaps need an owner decision, not more analysis.
- Reviewed by a blind accuracy checker and a zero-context loadability test. **No number here has
  been validated against the warehouse — no query has been run.** Nothing is stakeholder-ready.
