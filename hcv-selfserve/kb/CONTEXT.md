# CONTEXT.md — HCV self-serve knowledge base

**Doing analytics work on Porter's HCV vertical? Read this file fully, then load only the topic files
your task needs** — not all of them. `last_verified: 2026-09-07`

## Load protocol

| Your task | Load |
|---|---|
| "What is HCV / what does this term mean?" | [business.md](./business.md) |
| "How is metric X defined?" | [metrics.md](./metrics.md) → **then** [dashboards.md](./dashboards.md) for its card |
| "Which table/column holds X?" | [data-model.md](./data-model.md) |
| "Where does this number come from?" | [dashboards.md](./dashboards.md) |
| "Is this fact still true?" | [CONTRIBUTING.md](./CONTRIBUTING.md) §5 — staleness |
| "What's unresolved?" | [GAPS.md](./GAPS.md) |
| **About to edit this KB** | [CONTRIBUTING.md](./CONTRIBUTING.md) — **required** |

**Every fact is an addressable row** — `B-###` business · `M-###` metric · `T-###` table · `G-###` gap
— each with source, confidence, staleness. **Cite IDs:** an uncited answer cannot be checked.

## What HCV covers

**HCV = Heavy Commercial Vehicle** — Porter's trucking vertical, `9ft`–`19ft` (`B-002`), reported
**Tier 1** only (`B-003`). Demand arrives as **Schedule / Express / SPOT-on-Tray / SPOT** orders
(`B-004`); **SOT** is the tray marketplace (`B-005`). The primary object is a **full outer join of
Scheduled and Fact Orders** (`B-006`) — why allocation keys off `fo_driver_id`, and why `G-030` exists.

⚠️ **HCV's business posture — stage, margin, strategic priority — is recorded nowhere in this KB's
sources** (`B-008`, `G-020`). This is a reference desk, not a strategy document.

## The 12 metrics — quick reference

Full definitions: [metrics.md](./metrics.md). ⚠️ = **do not quote without reading its gap row first.**

| id | metric | formula | confidence |
|---|---|---|---|
| **M-001** | **Fulfilment % — NORTH STAR (L0)** | `completed / total_placed` | ⚠️ `unverified` — three denominators live (`G-031`); inherits `G-030` |
| M-002 | Total Placed (demand base) | `COUNT(unique_id)` where `COALESCE(order_status,5) IN (4,5)` | ⚠️ `unverified` (`G-030`) |
| M-003 | Completed Orders (mart) | `COUNT(CASE WHEN order_status = 4 …)` | `verified` |
| M-004 | Effective Fulfilment % | `completed / (placed − customer-attributed cancels)` | ⚠️ `unverified` (`G-034`) |
| M-005 | Unique Demand | placed minus cancel-and-rebook duplicates (`B-062`) | `verified` |
| M-006 | Unique Fulfilment % | `completed / unique_demand` | ⚠️ `unverified` — §6 and §3 disagree (`G-070`) |
| M-007 | Allocation % | `COUNT(fo_driver_id IS NOT NULL) / total_placed` | ⚠️ `unverified` (`G-030`, `G-032`) |
| M-008 | Completed Orders (OMS) | `COUNT(DISTINCT o.id)` where `status = 4` | `verified` |
| M-009 | Revenue | `SUM(ceil(fare) + coupon + referral + subscription)`, `fare_type=2` | `verified`, reconciled |
| M-010 | AOV | `revenue / completed` | ⚠️ `unverified` — **5** live formulas (`G-033`) |
| M-011 | Time to Accept p50/p75/p90 | `order_time → fo_trip_accepted_time`, capped 0–3600s | `verified` |
| M-012 | MAP | distinct partners with a day of `business_login_hours > 0.5` | `verified` |

**141 distinct HCV metrics: 12 full entries + 129 index rows** ([metrics.md](./metrics.md) §2).
Sources: `nb1882` (54) · `nb4146` (34) · `gsheet:HCV_Metrics_DD` · `cov` (8, `D-028`) · and since
`D-029` two dashboard inventories — `dash6248` (16) · `dash3823` (5) · 1 cross-confirmed on both.
**12 `M-###` numbers retire 11 *source* identities across 25 *source rows*.** Never swap those units.

⚠️ **The raw base behind this count is an open owner decision** (`G-100`). The old *"296 rows across
four sources"* double-counted — `coverage-map` transcribes the Sheet, which holds **118** rows where
§3 read **90**. Corrected base **206** (54+34+118) or **178** as-read; which rebuilds the total is the
owner's call, not a typo fix. ⚠️ **Rows 108-129 are `local:`-capped** and none of their 177 cards is
fingerprinted (`G-084`, `G-085`).

### Three facts that prevent most errors

1. **`order_status`: `4 = completed`, `5 = cancelled` — the OPPOSITE of PTL**, whose KB sits beside
   this one (`T-001`, `T-003`, `G-078`). `COALESCE(order_status, 5)` silently makes NULL a
   cancellation, 12 times over (`T-002`).
2. **The category dimension contains overlapping members.** In `pack:§2`/`§3`/`§6` a `10ft` row
   coexists with `10ft - NCR` and `10ft - non NCR`, so **summing across category double-counts every
   10ft order** (`T-024`). `§4` does not (`T-024a`).
3. **The denominator of FF %, E-FF %, Unique FF % and Allocation % contains rows that can never reach
   the numerator.** SO-only rows have NULL `fo_driver_id` and NULL `order_status` **by construction**
   (`G-030`). **Sized: 1.74 % of May-Jul placed — 4.88 % in May vs 0.22 % in June, which REVERSES the
   reported FF % trend** (`G-081`).

## Precedence — when sources disagree

**1.** the query pack *(reconciled SQL)* → **2.** observed card SQL → **3.** governed store
`metric.porter.*` *(authoritative for **naming and governance**, not formulas)* → **4.** Notion
inventories' judgement → **5.** unratified catalogues — Sheet, `coverage-map`, `dash6248`/`dash3823`
*(→* `assumption`*)* → **6.** card titles — **never evidence**.

> **Absolute exception:** when pack, card and store disagree — **and they do** — **do not resolve it.**
> Record every side, set `unverified`, open a `G-###`. Picking a side silently converts a known
> unknown into an invisible error.

⚠️ **The Notion inventories under-report.** Three store-vs-pack conflicts found on 2026-08-14 appear
in neither. Do not treat their contested-definition lists as complete.

## Confidence and staleness

`verified` — read from SQL/code, or an owner ruling (`OWNER:<date>`) · `unverified` — asserted but
unconfirmed, **or sources conflict** · `assumption` — inferred, stated nowhere. Agreement between two
unverified sources is still `unverified`. **A card title is never evidence.** Downgrading is always
allowed; upgrading needs new cited evidence.

**Staleness:** each row carries `source_updated_at`. `recorded < current ⇒ STALE` → mark `unverified`,
open a `G-###`, re-extract — for a card that is **one `get_card` call, never a query** (§5).

## Hard rules

1. **Never run a production query** without explicit owner go-ahead. Metadata reads only.
2. **HCV `status`: `4 = completed`, `5 = cancelled` — the opposite of PTL** (`T-003`).
3. Never put credentials, personal data, or **live/derived query results** in this KB (`T-080`–`T-082`).
4. **Aggregate-then-ratio** (`B-030`). Never average daily ratios; **never average percentiles** (`B-031`).
5. **Non-additive counts are never summed across periods** — DAP, active customers, cohorts (`B-034`).
6. **The category dimension has overlapping members** — summing across it double-counts 10ft (`B-035`, `T-024`).
7. **`dev_eldoria.sandbox.mbr_mapping_v2` is a write AND a prerequisite**, gating every pack section
   except `§5`. **No refresh contract** (`T-073`). ⚠️ A **`v3` is reported to supersede it** (`G-090`).
8. **Two time bases coexist** — `order_time` is IST, `created_at` is UTC (`+330`) (`T-010`, `T-011`).
9. **Tier is a business rule buried in SQL**, encoded `'Tier 1'` and `'Tier1'` on different columns
   (`T-022`, `T-022a`). A Tier selection can silently return empty.
10. Never inline a metric value into a definition — values live only in [business.md](./business.md)'s
    snapshot, tagged by **data period** (`B-090`+). Divide-by-zero → null (`B-032`); movements in **pp** (`B-033`).

## Source locations

Repo `github.com/akshayjain00/selfserve_data`. **Every link inside `kb/` is relative, so this KB
works from any branch.**

```
hcv-selfserve/
  hcv_metrics_queries.md   ← the pack, rung 1 — pinned repo@20f6416
  kb/                      ← you are here
  coverage-map/            ← derived PROJECTION, NOT a source · regenerate with `derive.py`, never hand-edit
  kb-build/                ← DESIGN · DECISIONS (D-001..D-030) · BOARD — process trail, not KB content
```

**Provenance format:** `repo@<sha>:<path>#L<n>` — never a bare path or branch name. Two clones exist
on diverged branches; SHAs are the only stable citation. PTL template: `claude/ptl-metric-catalog-map`
@ `28703aa`. PnM reference: `claude/pnm-p80-orderedits` @ `851886f`.

**Dashboards** — `metabase.prod-internal.porter.in`, instance **domestic**: `dashboard/6406`
(**go-forward demand**, `D-014`) · `1882` (legacy) · `4146` (ops/supply) · ⚠️ `6248` and `3823`
(registered `D-029`, **177 cards, none opened** — `G-084`/`G-085`). **Store:** `metric.porter.*`.

## State of the work — read before promising anything

- **The north star is designated, its denominator is not.** Fulfilment % is L0 by owner ruling
  (`D-011`, `OWNER:2026-08-14`); three denominators remain live (`G-031`) and it inherits `G-030`.
- **This KB is a migration map toward `metric.porter.*`** (`D-013`). Every full entry states its store
  delta **and its cost**; three metrics have **no store counterpart**, two are **`NOT EQUIVALENT`**.
- **Units are rupees, not paise** (`T-030`) — evidenced four ways, still `unverified` (`G-010`).
- **Gaps needing a person, not more analysis, are marked `BLOCKED — owner`.** Mechanical and
  immediately valuable: `G-050`, `G-014`, `G-073`, `G-103`.
- ⚠️ **One series is warehouse-validated** (`D-027`) — FF % and Allocation % at **month x overall**
  grain ([business.md](./business.md) §7). **Nothing else is:** no category or distance split, no
  `mbr_mapping_v2` rebuild, revenue and AOV absent pending `T-030`.
- ⚠️ **`G-030` reverses the reported FF % trend May-Jun 2026** (`G-081`). Reported **+1.30 pp**;
  corrected **-1.38 pp**. **Do not present a May-vs-June HCV fulfilment trend until `G-081` closes.**
- ⚠️ **Two dashboards registered but never opened** (`D-029`); `6248` clones four `6406` defects (`G-086`).
- **Nothing here is stakeholder-ready.**
