# dashboards.md — where HCV numbers actually come from

Card rows keyed `metabase:card/NNNNN`. **This file carries no KB ID series** — it is the one
exemption in [CONTRIBUTING.md](./CONTRIBUTING.md) §2. Entry point: [CONTEXT.md](./CONTEXT.md).
All rows `last_verified: 2026-08-14`.

**Base URL:** `https://metabase.prod-internal.porter.in` · **instance: domestic**

> **Staleness, restated.** Each card below carries its own `updated_at` as a fingerprint. To check a
> row: fetch the card's current `updated_at` (**one `get_card` metadata call — never run the query**)
> and compare. `recorded < current ⇒ STALE` → mark `unverified`, open a `G-###`, re-extract
> ([CONTRIBUTING.md](./CONTRIBUTING.md) §5).

---

## §1 Staleness-fingerprint register

Scope is **cards this KB cites** — those feeding one of the 12 metric entries or a recorded
conflict (`D-012`). Read 2026-08-14.

| card | name | db | `source_updated_at` | feeds |
|---|---|---|---|---|
| 55561 | HCV Overall View - Demand | 108 | 2026-08-12T12:24:41Z | `M-002` · `T-027` · `T-029` |
| 55586 | HCV Overall View - Allocation, FF, CADF, CBDF | 108 | 2026-08-12T12:24:27Z | `M-001` · `M-003` · `M-007` · `G-030` |
| 55529 | …– Schedule orders | 108 | 2026-08-12T12:24:46Z | `M-001` · `G-030` |
| 55625 | …– SPOT & Express | 108 | 2026-08-12T12:24:51Z | `M-001` · `G-030` |
| 55587 | HCV Overall View - Revenue and AOV | 108 | 2026-08-12T12:26:19Z | `M-009` · `M-010` |
| 55626 | …– Schedule orders | 108 | 2026-08-12T12:25:55Z | `M-009` · `M-010` |
| 55541 | …– Express & SPOT | 108 | 2026-08-12T12:27:05Z | `M-009` · `M-010` |
| 55527 | Allocation Time Distribution (seconds) | 108 | 2026-08-12T12:27:14Z | `M-011` · `G-073` |
| 55503 | HCV ATA Distribution in Minutes | 108 | 2026-08-12T12:27:37Z | `M-011` (**wrong clock** — see §5) |
| 55515 | Partner fetched distribution | 108 | 2026-08-12T12:28:21Z | index only |
| 55512 | Partner Notified distribution | 108 | 2026-08-12T12:28:26Z | index only |
| 55546 | Partner Ranked distribution | 108 | 2026-08-12T12:28:30Z | index only |
| 32713 | AOV | 108 | **2025-11-05T07:31:15Z** | `M-010` · `T-021a` · `T-022a` |
| 28681 | Fulfilment_Allocation_Missed_Stockout_% HCV (Eldoria) | **106** | 2026-06-11T09:43:04Z | `M-001` · `M-004` · `M-006` · `G-034` |
| 38998 | Cancellation %_HCV [DBT] | 108 | **2025-11-18T05:49:42Z** | `M-001` · `G-075` |
| 39084 | Hourly Fulfilment %_HCV [DBT] | 108 | **2025-11-18T05:48:02Z** | `M-001` · `G-031` |
| 33212 | Unutilisation time vs allocation and FF for business hour | **106** | **2025-07-30T06:10:01Z** | `M-001` · `G-031` · `G-076` |

**17 cards fingerprinted.**

> ⚠️ **Cards this KB cites but has NOT fingerprinted** — every one is a gap per `D-012`.
> Named in recorded conflicts but never opened: **28688, 39506, 28691, 28692, 28693, 37311, 28195,
> 29553, 29559, 28673, 28669, 28678** (the `1882` revenue/AOV family) and **32645, 32668, 32694,
> 32670, 32687, 32700, 33106, 33133, 33269, 32927, 36946, 32950, 28841, 28843, 28844, 28845, 29910,
> 39374, 43512** (the `4146` families). → `G-050`
>
> **`next_action`:** one `get_card` per id in that list — it is a literal, executable list, not
> "sweep the dashboards". Owner: this KB's maintainer. **PTL's equivalent gap has sat open since
> 2026-07-30 precisely because its action was not specific enough** (`D-012`).

---

## §2 Database-connection register

| id | role in this KB | evidence |
|---|---|---|
| **108** | Carries every `6406` card and most `1882` cards. The connection the pack's marts sit behind | `get_card` on 13 cards, read 2026-08-14 |
| **106** | Carries `28681` and `33212` — the `trucks_*` mart family | `get_card` on 2 cards, read 2026-08-14 |
| **70** | Named by `nb4146` as one of three connections `4146` spans. **Not observed by this KB** | `nb4146` scope notes — `unverified` |

> ⚠️ **`4146` spans three connections and mixes legacy `trucks.*` (redshift-era) with
> `prod_eldoria.*` (Snowflake)** — a migration and lineage risk flagged by `nb4146` and confirmed
> for `32713`, which joins `prod_curated.trucks.VEHICLE_SEGMENT_MAPPING_V2` and
> `prod_curated.trucks.GEO_REGIONS_ROI` rather than the `dim_*` equivalents (`T-062`).

---

## §3 Surfaces covered

| surface | id | scale | opened | role |
|---|---|---|---|---|
| **HCV Demand Dashboard** | `6406` | 1 tab · **21 question cards** (+5 text cards) | **12 of 21** | **Go-forward demand source** (`D-014`) |
| HCV Dashboard | `1882` | 5 tabs · **54 metrics** · card count unknown | **3 cards** | Legacy demand; `nb1882` inventory |
| HCV Deep Dive | `4146` | 3 tabs · **34 metrics** · card count unknown | **2 cards** | Ops/supply funnel; `nb4146` inventory |
| **Query pack** | — | 8 sections · 12 metrics | **all** | Top of the precedence ladder — §6 |

> ⚠️ **This is a stated boundary, not implied coverage.** On `6406`, **9 of 21 cards were not
> opened** — 55554, 55620, 55612 (cancellations), 55555, 55583, 55585 (cancellation-time), 55610,
> 55540, 55601 (ETA). None feeds one of the 12 metric entries. → `G-051`
>
> **The card counts for `1882` and `4146` are unknown to this KB.** Their *metric* counts come from
> the Notion inventories; neither dashboard was opened via `get_dashboard`. Any statement about
> their card-level coverage would be a guess. → `G-052`

---

## §4 `dashboard/6406` — HCV Demand Dashboard

**Collection** 2127 (" Category Dashboard") · **creator** `chetan.sharma2@theporter.in` ·
**created** 2026-08-12T12:11:45Z · **updated** 2026-08-12T12:12:57Z
**Tabs:** one — `6380` "HCV overall database"

**Filters, with defaults — read these before quoting anything from this dashboard:**

| filter | type | **default** |
|---|---|---|
| `Start_date` | date/single | **2025-04-01** |
| `End_Date` | date/single | **2025-09-30** |
| `Period` | Day / Week / Month | **Month** |
| `Tier` | Tier 1 / Tier 2 | **Tier 1** — *with* a space (`T-022`) |
| `Vehicle Mapping` | string | **`["14ft","10ft","9ft"]`** |
| `Vehicle_id` | number | none |
| `City` | string | none |

> ⚠️ **Three defaults make the out-of-the-box view unrepresentative of HCV.**
> 1. **`Vehicle Mapping` excludes 17ft and 19ft**, both inside HCV scope (`T-021`). The default view
>    **under-reports**. → `G-053`
> 2. **The date window defaults to Apr–Sep 2025** — not current, and not the pack's May–Jul 2026.
> 3. **Card-level defaults disagree with dashboard-level defaults.** Card 55561 defaults to
>    `2025-12-10 → 2025-12-10` — a **single day**; `Period` defaults to `DAY` at card level and
>    `Month` at dashboard level. Opening the card standalone and reading the dashboard give
>    different answers. → `G-054`

**Cards** — `Feeds` back-references the metric or gap each supports.

| card | name | feeds | note |
|---|---|---|---|
| 55561 | HCV Overall View - Demand | `M-002` `T-027` | **status filter commented out** — counts every status |
| 55586 | Allocation, FF, CADF, CBDF | `M-001` `M-003` `M-007` | numerator requires `fo_driver_id is not null` |
| 55529 / 55625 | …Schedule / SPOT & Express | `M-001` | same SQL + one `order_type` predicate |
| 55587 | Revenue and AOV | `M-009` `M-010` | OMS ∪ SO union; pack is OMS-only |
| 55626 / 55541 | …Schedule / Express & SPOT | `M-009` `M-010` | partition of 55587 |
| 55527 | Allocation Time Distribution (seconds) | `M-011` `G-073` | **correct clock** for `M-011` |
| 55503 | HCV ATA Distribution in Minutes | `G-036` | **third clock** — arrival, not accept |
| 55515 / 55512 / 55546 | Partner fetched / notified / ranked | index | hardcoded `>= '2024-06-05'` floor |
| 55554 / 55620 / 55612 | Cancellations family | — | **not opened** → `G-051` |
| 55555 / 55583 / 55585 | Cancellation-time family | — | **not opened** → `G-051` |
| 55610 / 55540 / 55601 | ETA family | — | **not opened** → `G-051` |

**Latent defects worth knowing**

- **The same commented-out block appears in all four demand/ratio cards**, verbatim:
  `--and o.vehicle_id in (3,114)` · `--and v.vehicle_category in ('17ft')` ·
  `--and o.geo_region_id in (2)` · `-- and o.order_type = 0` · `-- and o.status in (4,5)`.
  The last two are load-bearing.
- **The Demand card has no `Tier` default while the three ratio cards default to `Tier 1`** — so at
  default settings the numerator and denominator cards **do not share a population**. → `G-055`
- **`group by all`** in 55587/55626/55541's fare CTEs groups by `order_id + travel_distance + fare`,
  so a multi-row order can **fan out** on the `LEFT JOIN`. → `G-056`
- Output alias typo **`Reveune`** in 55587/55626/55541.
- 55515/55512/55546 apply **no test-customer exclusion, no status filter and no Tier default**, so
  they cover a wider population than any pack section. 55546 merges **differently-named columns** —
  `NUM_SELECTED_DRIVERS` (SO) with `NUM_RANKED_DRIVERS` (FO) — as one measure. → `G-057`

---

## §5 Title-vs-SQL mismatches

**A card title is never evidence** ([CONTRIBUTING.md](./CONTRIBUTING.md) §4, ladder rung 6). Every
row here is a case where the title or comment contradicts the SQL.

| card | title / comment says | SQL actually does |
|---|---|---|
| **55527** | alias `allocation_time_minutes`; comment *"Allocation time (minutes)"*; title *"(seconds)"* | computes **seconds**. Only the alias and comment are wrong → `G-073` |
| **55503** | *"HCV ATA Distribution"* — reads as arrival-time-at-pickup | clocks `TRIP_ACCEPTED_TIME → TRIP_START_ENTRY_TIMESTAMP`. **Not** time-to-accept; a third clock → `G-036` |
| **39084** | *"Hourly Fulfilment %"* | **groups by** hour rather than filtering to business hours. Not the business-hours denominator → `G-031` |
| **36946** | *"Rejection rate at Partner level"*, description gives `rejected/(accepted+rejected)` | SQL computes `accepted/(accepted+rejected)` — **acceptance** rate. Reported by `nb4146`, **not** re-read by this KB |
| **32687** | *"demand per dap"* | numerator is `unique_demand`, not total demand. Reported by `nb4146`, not re-read |
| — | *"wallet_share"* columns on `1882` | compute **orders-per-customer**, not share of wallet. Reported by `nb1882`, not re-read |

---

## §6 The query pack as a source of record

`repo@20f6416:hcv-selfserve/hcv_metrics_queries.md` — **rung 1 of the precedence ladder.** It is not
a dashboard, but it is where every one of the 12 full metric entries is implemented, so it is
registered here as a surface.

**Dependency graph** — verified from the SQL, not from the pack's prose (`T-071`):

| § | writes | needs `mbr_mapping_v2` | emits |
|---|---|---|---|
| 0 | ✓ `dev_eldoria.sandbox.mbr_mapping_v2` | — | the distance base |
| 1 | | ✓ | `M-008` `M-009` `M-010` |
| 2 / 2a | | ✓ | `M-001` `M-002` `M-003` `M-004` `M-007` |
| 3 / 3a | | ✓ | `M-005` `M-006` |
| 4 | | ✓ | `M-011` |
| **5** | | **✗ — the only independent section** | `M-012` |
| 6 | | ✓ | projection of `§2` + `§3`, **minus E-FF** |

> ⚠️ **`§0` is a `CREATE OR REPLACE TABLE` into a dev sandbox with no refresh contract.** Nothing
> schedules it; nothing records when it last ran. **Every number from `§1`–`§4` and `§6` is exactly
> as stale as the last manual run** (`T-073`). This is the single largest operational difference
> between the pack and any governed store metric, all of which carry a declared freshness contract
> (`B-072`, `B-072a`).

> ⚠️ **The pack's own caveat is wrong** — it says *"sections 1–4 depend on `mbr_mapping_v2`"* and
> omits `§6`, which joins it twice. Recorded, not corrected (`G-011`).
