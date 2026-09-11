# data-model.md — tables, columns, enums, units, joins

`PNM-T-###` rows. Schema and rules: [CONTRIBUTING.md](./CONTRIBUTING.md). Entry point: [CONTEXT.md](./CONTEXT.md).
All rows `last_verified: 2026-08-26`.

**Warehouse:** Snowflake. **Two databases are in play and the split is not cosmetic:**
`PROD_ELDORIA` holds the governed dbt layer (`CORE`, `MART`) and serves leads / orders / derived /
p80 / order_edits; `PROD_CURATED` is closer to raw application data and serves `tpo` only.
**Ruling `D3`:** the pipeline was re-pointed off `PROD_CURATED.pnm_application` because the columns
it needed **were never there** (`PNM-T-004`).

> **How rows in this file are graded — read before trusting a `verified`.**
> Facts about **what the shipped SQL does** (which table it reads, which predicate it applies, which
> column it compares to what) are `verified` — they were read out of `sqlgen.py` at a SHA.
> Facts about **what the warehouse contains** (column counts, data types, whether a column exists at
> all) were originally `unverified`: the 2026-07-29 live read happened for a different piece of work
> and reached this KB through a prose document's `[LIVE]` tags, which CONTRIBUTING §5 does not admit
> as `verified`. ✅ **CLOSED 2026-09-04 (`PNM-G-042`)** — all 11 catalog tables' column counts were
> re-read first-hand via `INFORMATION_SCHEMA.COLUMNS`, this session, no owner go-ahead needed (it is
> a read, not a write — `PNM-B-034` governs writes). **Every count matched the inherited 2026-07-29
> figures exactly, zero drift** — see the `live cols` column below, now `verified` at
> `live:INFORMATION_SCHEMA@2026-09-04`. The load-bearing absence claim, `PNM-T-032` (`HS_TICKETS` has
> no `ORDER_ID`), was checked column-by-column, not just by count: confirmed absent — the table has
> `HS_ORDER_ID` and `SF_ORDER_ID`, neither of which is `ORDER_ID`.

---

## Tables the catalog reads

| id | table | grain (1 row =) | live cols | used by | confidence |
|---|---|---|---|---|---|
| PNM-T-001 | `PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY` | 1 lead | 12 | leads, orders, derived | **verified** |
| PNM-T-002 | `PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY` | 1 lead | 23 | leads, orders, derived | **verified** |
| PNM-T-003 | `PROD_ELDORIA.CORE.FACT_PNM_ORDERS` | 1 order | 32 | orders, derived | **verified** |
| PNM-T-004 | `PROD_ELDORIA.CORE.DIM_PNM_ORDERS` | 1 order | 35 | orders, derived | **verified** |
| PNM-T-005 | `PROD_ELDORIA.MART.PNM_EXPERIENCE` | 1 order | **71** | p80_durations, order_edits | **verified** |
| PNM-T-006 | `PROD_ELDORIA.MART.PNM_CUSTOMERS` | 1 `customer_mobile` | 35 | orders — **inner join, acts as a filter** | **verified** |
| PNM-T-008 | `PROD_CURATED.PNM_APPLICATION.ORDERS` | 1 order | **17** | tpo | **verified** |
| PNM-T-009 | `PROD_CURATED.PNM_APPLICATION.ORDER_ALLOCATION_INFOS` | 1 allocation attempt | 23 | tpo | **verified** |
| PNM-T-010 | `PROD_CURATED.PNM_APPLICATION.SHIFTING_REQUIREMENTS` | 1 SR | 19 | tpo | **verified** |
| PNM-T-011 | `PROD_CURATED.SFMS_PUBLIC.HS_TICKETS` | 1 ticket | 56 | tpo | **verified** |
| PNM-T-118 | `PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES` | 1 opportunity | 43 | gac_ctr | **verified** (`live:INFORMATION_SCHEMA@2026-09-04`) |
| PNM-T-119 | `PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES_LATEST_LSM_SCORE` | 1 opportunity's latest LSM score | 13 | gac_ctr | **verified** (`live:INFORMATION_SCHEMA@2026-09-04`) |
| PNM-T-016 | `PROD_ELDORIA.MART.PNM_ALLOCATION` | 1 order | 34 | allocation | **verified** (`live:INFORMATION_SCHEMA@2026-09-04`) — ⚠ **moved from "not read" 2026-09-04**, `DECISION_LOG:D13`. Carries `IS_NANO_ORDER`/`IS_TEST_USER` (`PNM-G-072`, closed) |
| PNM-T-017 | `PROD_ELDORIA.MART.PNM_FARE_MOVEMENT` | 1 order | 46 | fare, vendor_earnings_pctl | **verified** (`live:INFORMATION_SCHEMA@2026-09-04`) — ⚠ **moved from "not read" 2026-09-04**, `DECISION_LOG:D13`; col count corrected 31→46 (the old figure was stale). Carries `IS_NANO_ORDER`/`IS_TEST_USER` |
| PNM-T-120 | `PROD_CURATED.PNM_APPLICATION.VENDOR_OWNERS` | 1 vendor owner | 15 | wallet | **verified** (`live:INFORMATION_SCHEMA@2026-09-04`) |
| PNM-T-121 | `PROD_CURATED.PNM_APPLICATION.VENDOR_WALLET_WITHDRAWAL` | 1 withdrawal request | 15 | wallet | **verified** (`live:INFORMATION_SCHEMA@2026-09-04`) |
| PNM-T-122 | `PROD_CURATED.PNM_APPLICATION.PAYMENT_LINKS` | 1 payment link | 17 | wallet | **verified** (`live:INFORMATION_SCHEMA@2026-09-04`) |
| PNM-T-123 | `PROD_CURATED.PNM_APPLICATION.VENDOR_ALLOCATION_CONFIGS` | 1 vendor's allocation config | 18 | wallet | **verified** (`live:INFORMATION_SCHEMA@2026-09-04`) |
| PNM-T-124 | `PROD_ELDORIA.CORE.DIM_PNM_VENDOR` | ⚠ **1 (vendor_id, bucket_start_date) — NOT 1 vendor**, corrected 2026-09-07 (`PNM-G-091`) | 15 | wallet | **verified** (`live:INFORMATION_SCHEMA@2026-09-04`) |
| PNM-T-125 | `PROD_CURATED.PNM_APPLICATION.CANCELLED_ORDER_EVENTS` | 1 cancellation event | 17 | cac_post_trip | **verified** (`live:INFORMATION_SCHEMA@2026-09-04`) |
| PNM-T-126 | `PROD_ELDORIA.RAW.PNM_APPLICATION_ORDERS` | 1 order | 11 | vendor_tpo_top5 | **verified** (`live:INFORMATION_SCHEMA@2026-09-04`) — ⚠ **RAW schema, distinct from `PROD_CURATED.PNM_APPLICATION.ORDERS` (`PNM-T-008`)**, which this catalog's own `tpo` section reads instead |
| PNM-T-127 | `PROD_ELDORIA.RAW.PNM_APPLICATION_ORDER_ALLOCATION_INFOS` | 1 allocation attempt | 17 | vendor_tpo_top5 | **verified** (`live:INFORMATION_SCHEMA@2026-09-04`) |
| PNM-T-128 | `PROD_ELDORIA.RAW.PNM_APPLICATION_SHIFTING_REQUIREMENTS` | 1 SR | 12 | vendor_tpo_top5 | **verified** (`live:INFORMATION_SCHEMA@2026-09-04`) |
| PNM-T-129 | `PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS` | 1 ticket | 20 | vendor_tpo_top5 | **verified** (`live:INFORMATION_SCHEMA@2026-09-04`) — ⚠ narrower than `PROD_CURATED.SFMS_PUBLIC.HS_TICKETS` (`PNM-T-011`, 56 cols) — this RAW copy has no `SHIFTING_TYPE`/`HS_PACKAGE`, so `vendor_tpo_top5` gets those from the SR/orders join instead |

*`source_ref` for every row above: `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` for the
table's identity and role — **`verified`**, the shipped SQL reads it. The `live cols` counts were
originally `live:INFORMATION_SCHEMA@2026-07-29` and `unverified` (inherited, not first-hand); **all
11 re-read live 2026-09-04, zero drift — now `live:INFORMATION_SCHEMA@2026-09-04`, `verified`**
(`PNM-G-042`, closed).*

> **PNM-T-131** — `DIM_PNM_VENDOR`'s true grain (`dbt@<pending>:models/docs/dim/dim_pnm_vendor.yml`,
> mined 2026-09-07, `PNM-G-091`): **a vendor gets a NEW ROW every time its performance-tier bucket
> (`bucket_type`: New/Bronze/Silver/Gold/GoldPlus) changes** — composite key `(vendor_id,
> bucket_start_date)`, model-level `dbt_utils.unique_combination_of_columns`, no single-column
> unique test (inherent to a composite grain). The current row is the one with the max
> `bucket_start_date` or a null/future `bucket_end_date`. ⚠ **This catalog's own `wallet_sql` reads
> this table via `SELECT DISTINCT vendor_id`** (`PNM-T-124`) — DISTINCT collapses the composite-key
> rows down to one per vendor before the fan-out could matter, so **this is a checked, not-a-risk
> finding**, unlike `PNM-G-096`'s `RANK()` tie. No catalog SQL reads `bucket_type` from this table at
> all — `vendor_earnings_bucket_sql` gets its own bucket classification from a **different** column,
> `PNM_EXPERIENCE.vendor_bucket_type`, already using `ROW_NUMBER()` + an explicit tiebreak for
> exactly this kind of time-varying grain. The two bucket taxonomies match (New/Bronze/Silver/Gold/
> GoldPlus) — a real, if minor, cross-check that the catalog's home-grown bucket logic agrees with
> the governed dimension's. **Verified, no fix needed.**

> **PNM-T-132** — `FACT_PNM_OPPORTUNITY`'s governed doc (`dbt@<pending>:models/docs/fact/
> fact_pnm_opportunity.yml`, mined 2026-09-07, `PNM-G-091`) confirms grain = 1 row per `opp_id`
> (matches `PNM-T-001`) and that `opp_uuid` is **not** unique per opportunity (one customer can have
> several) — consistent with this catalog's existing understanding, no correction needed. Owner:
> `NI_PNM`, domain `ANALYTICS_INFRASTRUCTURE` — **a different domain than `DIM_PNM_OPPORTUNITY`'s
> `PNM`** (`PNM-T-103`) even though both tables are joined by this catalog and share the same `NI_PNM`
> owner tag; not a conflict, just two different domain tags on two halves of the same fact/dim pair.
> Carries `opp_latest_score`/`hash_score` — the same lead-scoring (LSM) concept `gac_ctr` reads from
> a **different** table, `PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES_LATEST_LSM_SCORE` (`PNM-T-119`).
> Neither this catalog nor `gac_ctr` reads `FACT_PNM_OPPORTUNITY`'s score columns — noted so a future
> LSM-score question isn't assumed to have only one source table.

> **PNM-T-007** — `PROD_ELDORIA.CORE.DIM_GEO_REGIONS` (1 row = 1 city/geo region, 23 cols) is the
> **city lookup table**, joined `SHIFTING_REQUIREMENTS.GEO_REGION_ID = DIM_GEO_REGIONS.GEO_REGION_ID`.
> ⚠ **No catalog SQL reads it** and it is absent from `run_tests.py`'s `EXPECTED_TABLES` allow-list —
> it is listed here because it is where a **city cut would come from** if `PNM-G-070` is ever closed,
> and because card #47576 uses it. `source_ref: live:INFORMATION_SCHEMA@2026-09-04` · **verified**
> (re-read 2026-09-04, `PNM-G-042`; 23 cols confirmed, unchanged)

### Tables that exist but the catalog does NOT read

| id | table | statement | source_ref | confidence |
|---|---|---|---|---|
| PNM-T-015 | `PROD_ELDORIA.MART.PNM_SUPPORT` | 1 row = 1 order, 36 cols. Not read by any catalog section. | `live:INFORMATION_SCHEMA@2026-07-29` | unverified |

> ✅ **`PNM_ALLOCATION`/`PNM_FARE_MOVEMENT` (formerly `PNM-T-016`/`017` here) are no longer absent
> from the Notion schema guide** — added 2026-09-04 (`PNM-G-023`, closed) — **and are no longer
> unread by the catalog either** — both are now read (`allocation`, `fare`, `vendor_earnings_pctl`
> sections, `DECISION_LOG:D13`, `PNM-G-072` closed). Moved to "Tables the catalog reads" above.

## Join keys — and the traps

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| **PNM-T-030** | **The joins the catalog actually uses:** `FACT_PNM_OPPORTUNITY.OPP_ID = DIM_PNM_OPPORTUNITY.OPP_ID` · `FACT_PNM_OPPORTUNITY.SR_ID = FACT_PNM_ORDERS.SR_ID` (lead → order) · `FACT_PNM_ORDERS.ORDER_ID = DIM_PNM_ORDERS.ORDER_ID` · `FACT_PNM_ORDERS.CUSTOMER_MOBILE = PNM_CUSTOMERS.CUSTOMER_MOBILE` · `PNM_APPLICATION.ORDERS.ID = ORDER_ALLOCATION_INFOS.ORDER_ID` · `ORDERS.SR_ID = SHIFTING_REQUIREMENTS.ID` · `HS_TICKETS.CRN = ORDERS.CRN` | `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` | **verified** | Note `ORDERS.**ID**` — not `ORDER_ID` — on the allocation join. |
| **PNM-T-031** | **`FACT_PNM_ORDERS → PNM_CUSTOMERS` is an INNER JOIN and therefore a FILTER**, not an enrichment. An order whose `customer_mobile` has no `PNM_CUSTOMERS` row is **dropped from the order count entirely**. | `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` | **verified** | Silent population effect; size unmeasured → `PNM-G-014` |
| **PNM-T-032** | ⚠ **`HS_TICKETS` has NO `ORDER_ID` column.** Tickets join to orders on **`CRN`** (or `HS_ORDER_ID`). | `live:INFORMATION_SCHEMA@2026-07-29` | unverified — **an absence claim, and this KB did not run the read**. Corroborated but not proven by `sqlgen.py`, which joins on `crn` | An early TPO query assumed `order_id` and **could never have run** → `PNM-G-035` |
| **PNM-T-033** | ⚠ **`PROD_CURATED.PNM_APPLICATION.ORDERS` holds only** `ID, CRN, SR_ID, SOURCE, CREATED_AT, UPDATED_AT, STATUS (TEXT), SERVICE_TYPE, MOBILE` + ETL/Kafka columns. **No `ORDER_ID`, no lifecycle timestamps, and its `STATUS` is text, not a number.** The lifecycle columns are *assembled* in `CORE.FACT_PNM_ORDERS`. | `live:INFORMATION_SCHEMA@2026-07-29` | unverified | **This is why the whole pipeline was re-pointed to `PROD_ELDORIA`** (`DECISION_LOG:D3`). Any doc citing `status = 2` / `status != 4` on this table is describing something that cannot execute. |
| PNM-T-034 | **`FACT_PNM_ORDERS` carries no `USER_FLAG`, `SHIFTING_TYPE`, `PACKAGE_NAME` or `ORDER_STATUS`** — and no `STATUS` column at all. Every order query must join `DIM_PNM_ORDERS` to filter. | `live:INFORMATION_SCHEMA@2026-07-29` | unverified — though the join's *existence* in `sqlgen.py` corroborates it | Explains the shape of `PNM-M-002`. |
| PNM-T-035 | **Keys and which tables carry them:** `ORDER_ID` — `FACT_PNM_ORDERS`, `DIM_PNM_ORDERS`, `PNM_EXPERIENCE`, `PNM_SUPPORT`, `PNM_ALLOCATION`, `PNM_FARE_MOVEMENT`, `ORDER_ALLOCATION_INFOS` · `SR_ID` — the opportunity fact, both order tables, the three marts, `ORDERS` · `OPP_ID` — the two opportunity tables · `CRN` — `FACT_PNM_ORDERS`, `PNM_SUPPORT`, `PNM_ALLOCATION`, `ORDERS`, `HS_TICKETS` · `CUSTOMER_MOBILE` — opportunity fact, order fact, `PNM_CUSTOMERS`, `PNM_SUPPORT` · `PICKUP_GEO_REGION_ID` → `DIM_GEO_REGIONS.GEO_REGION_ID` | `live:INFORMATION_SCHEMA@2026-07-29` | unverified | — |

## Mandatory filters — never remove these

| id | filter | applies to | why | confidence |
|---|---|---|---|---|
| PNM-T-040 | `shifting_type = 'intra_city'` | every section | catalog is intra-city only (`PNM-B-006`) | **verified** |
| PNM-T-041 | `shifting_type = 'intra_city' **OR IS NULL**` | **leads only** | deliberate asymmetry — leads admit NULL, orders do not | **verified** |
| PNM-T-042 | `user_flag ILIKE 'normal'` | leads, orders (**on the dims**) | excludes non-normal / experiment users | **verified** |
| PNM-T-043 | `crn LIKE '%PNM%'` | orders, tpo | restricts to PnM business (`PNM-B-056`) | **verified** |
| PNM-T-044 | `package_name NOT ILIKE 'Nano%'` (prefix) | orders, p80, order_edits | Nano is LA's (`PNM-B-012`) | **verified** |
| PNM-T-045 | `NOT ILIKE '%Nano%'` (**contains**), applied to **two columns**: `shifting_requirements.package_name` (order side) **and `hs_tickets.hs_package` (ticket side)** | tpo | faithful to the TPO query as validated — **do not unify with `PNM-T-044`** (`PNM-B-014`) | **verified** |
| PNM-T-046 | `ORDER_STATUS = 'completed'` | p80_durations, order_edits | completed moves only | **verified** |
| PNM-T-047 | `is_active = true` on `ORDER_ALLOCATION_INFOS` | tpo | the live allocation only | **verified** |
| PNM-T-048 | `COALESCE(raised_by,'') != 'Detractor'` | tpo tickets | detractor tickets excluded everywhere | **verified** |
| PNM-T-049 | `COALESCE(hst.shifting_type, c.shifting_type) = 'intra_city'` | tpo tickets | a **two-source fallback chain** described in no document; changes which tickets count when the ticket's own `shifting_type` is null → `PNM-G-014` | **verified** (that it is there) |
| PNM-T-051 | `hst.crn LIKE '%PNM%'` | tpo tickets | ⚠ **The ticket side carries its own full population filter** — `crn LIKE '%PNM%'` + `hs_package NOT ILIKE '%Nano%'` + `PNM-T-049` — separate from the order base's. A TPO numerator is not simply "tickets on base orders" | **verified** |

*All rows above: `source_ref: repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py`.*

> **PNM-T-050** — ⚠ **TEST-ORDER EXCLUSION IS SPLIT, AND THE SPLIT IS THE POINT.**
> **CORRECTED 2026-08-26.** Superseded wording: *"Test orders are largely NOT excluded."* That was
> too strong. The governed dbt docs define `user_flag` as **"a flag to separate test and normal
> users"** (`PNM-T-082`), so **leads and orders DO exclude test users** via `user_flag ILIKE 'normal'`.
> **`p80_durations` and `order_edits` still do not** — `PNM_EXPERIENCE` carries neither `user_flag`
> nor `IS_TEST_USER`, so those two sections have **no test filter of any kind**. State it per section;
> never as one blanket claim. The original note follows.
>
> `IS_TEST_USER` exists **only** on
> `PNM_ALLOCATION` and `PNM_FARE_MOVEMENT` — neither of which the catalog reads. leads and orders
> rely on `user_flag ILIKE 'normal'` as their **only** user gate; **`p80_durations` and `order_edits`
> have no user or test filter at all**, because `PNM_EXPERIENCE` carries neither column.
> **Do not claim the catalog excludes test orders.**
>
> ⚠ **QUALIFIED 2026-08-27.** `IS_TEST_USER`'s derivation is now read (`PNM-T-106`) and it is **not the
> complement of `user_flag ILIKE 'normal'`**. It is `COALESCE(user_flag,'Normal') NOT ILIKE 'Normal%'`,
> which differs on **NULL** and on **prefix-vs-exact** matching. So "leads and orders DO exclude test
> users" and "`IS_TEST_USER` marks test users" are **two different partitions of the population**, and
> a count from one cannot be subtracted from a count from the other (`PNM-G-099`).
> The *absence of any test filter in the shipped SQL* is **`verified`**
> (`repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` + the two rendered SQL files); *which tables
> carry `IS_TEST_USER`* is `live:INFORMATION_SCHEMA@2026-07-29` and **`unverified`**. → `PNM-G-073`
>
> ⚠ **SIZED 2026-09-04 — the predicate divergence above is theoretical, not observed.** Live
> `GROUP BY user_flag` on `DIM_PNM_ORDERS` returns only `NORMAL`/`TEST`, no `NULL`s, no prefix
> variants — so on today's data `user_flag ILIKE 'normal'` and `IS_TEST_USER` select exactly
> complementary rows (`PNM-G-099`, closed). And `p80_durations`/`order_edits`' missing test filter
> was sized as a proxy via `PNM_ALLOCATION.IS_TEST_USER`: 0.024%–0.590% of monthly orders across 10
> months — immaterial (`PNM-G-073`, closed). **Neither closure changes the shipped SQL** — both
> gaps closed on "immaterial, no code change" rather than "filter added."

## Time basis and units

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| PNM-T-020 | **The seven execution-stage timestamps**, in order: `VENDOR_OWNER_ACCEPTED_TS_IST` (vendor owner accepted) → `SUPERVISOR_ASSIGNED_TS_IST` (supervisor assigned) → `SUPERVISOR_ACCEPTED_TS_IST` (supervisor accepted) → `TRIP_STARTED_TS_IST` (crew set off) → `SHIFTING_STARTED_TS_IST` (move began) → `PICKUP_COMPLETED_TS_IST` (everything loaded) → `ORDER_COMPLETED_TS_IST` (move finished). | `live:INFORMATION_SCHEMA@2026-07-29` | **verified** | ⚠ Every "Supervisor Assigned" duration actually reads `SUPERVISOR_ACCEPTED_TS_IST` → `PNM-M-021` |
| PNM-T-021 | **`PNM_EXPERIENCE` timestamps are already IST** — every `*_TS_IST` column is `TIMESTAMP_NTZ` in IST, so **no conversion is applied and none is needed.** Naive month-literal bounds do not shift. | `live:INFORMATION_SCHEMA@2026-07-29`, `DECISION_LOG:D8` | **verified** | Applies to p80_durations and order_edits. |
| PNM-T-022 | **`PROD_CURATED` timestamps are UTC and are shifted in SQL** with `DATEADD(minute, 330, …)` to get IST. Used on `order_allocation_infos.completed_ts` and `hs_tickets.created_at` for the TPO month. | `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` | **verified** | The two conventions coexist by database — **do not mix them.** |
| PNM-T-023 | **The shipped SQL compares `IS_MODIFICATION_DONE` to the string `'Yes'` and the `HAS_*_EDIT` flags to the number `1`.** | `repo@851886f:pnm-selfserve/selfserve_nlq/tests_output/rendered_order_edits_2026-05.sql` | **verified** | The *types* behind those comparisons (`TEXT` and `NUMBER`, and `OTA_FLAG` `TEXT` not boolean) are a live-schema claim → `PNM-T-023a`. The Notion guide calls all three BOOLEAN; a boolean comparison would fail → `PNM-G-023` |
| PNM-T-023a | `IS_MODIFICATION_DONE` is **TEXT**; the `HAS_*_EDIT` flags are **NUMBER**; `OTA_FLAG` is **TEXT**. | `live:INFORMATION_SCHEMA@2026-07-29` | unverified | Consistent with the comparisons the shipped SQL actually makes (`PNM-T-023`), which is corroboration, not proof. |
| PNM-T-024 | **Units:** p80 durations are **minutes** (`DATEDIFF('minute', …)`, rounded to 1dp) · TPO ratios are **tickets/order**, rounded to **4dp** · order_edits percentages are **percent**, rounded to 2dp · `no_of_successful_edits` is a **count**. | `repo@851886f:pnm-selfserve/selfserve_nlq/tests_output/rendered_p80_durations_2026-05.sql`, `rendered_order_edits_2026-05.sql`, `sqlgen.py` | **verified** | TPO's 4dp vs the automation's 2dp → `PNM-G-016` |

## Enums

| id | column | values | source_ref | confidence |
|---|---|---|---|---|
| PNM-T-060 | **`ORDER_STATUS`** (`DIM_PNM_ORDERS`, `PNM_EXPERIENCE`) | `open`, `vendor_accepted`, `supervisor_assigned`, `supervisor_accepted`, `trip_started`, `shifting_started`, `pickup_completed`, `completed`, `cancelled` — **lowercase** | Notion schema guide via `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §3.6 | unverified |
| PNM-T-061 | **`ORDER_STATUS_WHEN_TICKET_CREATED`** (`HS_TICKETS`) | same value space; drives every TPO stage bucket (`PNM-M-011`) | `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` | **verified** |
| PNM-T-062 | **`RAISED_BY`** (`HS_TICKETS`) | `Customer`, `Vendor-Owner`, `Vendor-Supervisor`, `Porter Support`, `Detractor`, `Chat` | `repo@851886f:pnm-selfserve/iteration-2-readiness-ledger.md` §3 | unverified |
| PNM-T-063 | **`SHIFTING_TYPE`** | `intra_city`, `inter_city`, `vehicle_shifting` (+ `labour` on the opportunity dim) | Notion via `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §3.6 | unverified |
| PNM-T-064 | **`PACKAGE_NAME`** | `1 RK`, `1 RK/Studio`, `1–5 BHK Small\|Medium\|Big`, `Micro Shifting`, `Nano Shifting`, `Nano Shifting Medium`, `Nano Shifting Large`, `vehicle_shifting_default` | Notion via `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §3.6 | unverified |
| PNM-T-065 | **Opportunity `SOURCE`** (NUM) | value space **`0,1,2,3,4`** is pinned by a merged `accepted_values` test. The *labels* — `0` Website · `1` App · `2` App Home · `3` App Promo · `4` Generic — remain Notion-only | `dbt@ad4ab4e:models/docs/dim/dim_pnm_opportunity.yml` (values) · Notion (labels) | **verified** (value space) / unverified (labels) |
| PNM-T-066 | **Opportunity `STATUS`** (NUM) | `0` Open (lead in, no contact) · `1` Prospect (sales working it) · `2` Quoted (price shared) · `3` Closed (dropped off) · `4` Converted (order placed) | `dbt@ad4ab4e:models/docs/dim/dim_pnm_opportunity.yml` — a merged **`accepted_values` test** pins 0–4, and the column description carries the labels | **verified** — *upgraded 2026-08-26; was `unverified` on Notion alone* |
| PNM-T-067 | **`SOURCE_DETAILS`** | free text — e.g. `Desktop Website`, `Mobile Website`, `Inbound Call` | Notion via `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §3.6 | unverified |
| PNM-T-068 | **`SERVICE_TYPE`** | `Default`, `Default_Short`, `Lite`, `Standard`, `Premium`, `FourWheeler`, `PTL`, `FTL` | Notion via `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §3.6 | unverified |
| PNM-T-069 | **`VENDOR_BUCKET_TYPE`** | `New`, `Bronze`, `Silver`, `Gold`, `GoldPlus` | Notion via `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §3.6 | unverified |
| PNM-T-070 | **`CLASSIFICATION`** (NPS) | `Promoter`, `Neutral`, `Detractor` | Notion via `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §3.6 | unverified |
| PNM-T-071 | **`CANCELLED_BY`** | `Customer`, `Vendor Owner`, `Vendor-Supervisor`, `Porter Support`, `Backend Team`, `Detractor`, `system-automation` | Notion via `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §3.6 | unverified |

> ⚠ **`PNM-T-060`, `T-063`–`T-071` come from the Notion schema guide** — a 2026-03-31 snapshot,
> already proven wrong on types in five places (`PNM-G-023`). The *values* have not been
> independently checked against the warehouse. Confirm before writing a predicate on one.

## Column meanings — the non-obvious ones

| id | column | meaning | source_ref | confidence |
|---|---|---|---|---|
| PNM-T-080 | `CRN` | Customer reference number on the order; PnM work matches `'%PNM%'` | Notion via `repo@df25d22:pnm-selfserve/pnm-gem-knowledge.md` §3.7 | unverified |
| PNM-T-081 | `SR_ID` | Shifting-requirement id — the thread linking a lead to its order | as above | unverified |
| PNM-T-082 | `USER_FLAG` | **"A flag to separate test and normal users."** | `dbt@ad4ab4e:models/docs/dim/dim_pnm_opportunity.yml` | **verified** — ⚠ **CORRECTED 2026-08-26.** Superseded wording: *"User classification used for experiments/segmentation; normal traffic is `normal`"* (Notion). This matters: `user_flag ILIKE 'normal'` **is** a test-user exclusion, so leads and orders **do** exclude test users — see `PNM-T-050` |
| PNM-T-083 | `SYSTEM_DISPOSITION` | System-assigned lead outcome, e.g. `Not Interested`, `RNR` (ring-no-response), `Quotation Shared` | as above | unverified |
| PNM-T-084 | `DEALLOCATION_STATUS` | Whether the vendor assignment changed during the order's life | as above | unverified |
| PNM-T-085 | `DRY_RUN_DISTANCE_KMS` | Distance the vendor travelled before pickup | as above | unverified |
| PNM-T-086 | `INITIAL_CFT` / `FINAL_CFT` | Item volume in cubic feet at booking vs after modifications | as above | unverified |
| PNM-T-088 | `PICKUP_CITY_NAME` / `DROP_CITY_NAME` | City name on the order and opportunity dims and on `PNM_EXPERIENCE`, `PNM_SUPPORT`, `PNM_ALLOCATION`, `PNM_FARE_MOVEMENT`. ⚠ **This is the column a city cut would use** — with `PICKUP_GEO_REGION_ID` → `DIM_GEO_REGIONS` (`PNM-T-007`). The data exists; **no city query has been reconciled**, which is why the catalog still refuses (`PNM-G-070`) | `live:INFORMATION_SCHEMA@2026-07-29` | unverified |
| PNM-T-087 | `OTA_FLAG` / `OTA_BREACH_TAT_MINUTES` | Whether the vendor arrived inside the SLA window, and by how many minutes it was missed — ⚠ **the SLA definition is disputed** | as above | unverified → `PNM-G-024` |

## Governed facts from the dbt layer

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| **PNM-T-100** | **`PNM_EXPERIENCE.OTA_FLAG`'s actual rule:** `On_Time` when the order is **completed**, **`distance_km < 0.5`**, and **`shifting_started_event <= shifting_ts + 30 minutes`**. `OTA_BREACH_TAT_MINUTES` = `DATEDIFF(minute, shifting_ts + 30 minutes, shifting_started_event_ts)`, populated only for valid breached cases. | `dbt@816fa40:models/docs/mart/pnm_experience.yml` | **verified** | ⚠ **This settles the threshold half of `PNM-G-024`: 500 m, not 2 km.** ⚠ It also keys off **shifting-started**, not vendor arrival — so it is not literally an *arrival* measure. Adopting it as PnM's OTA is still an owner call. |
| **PNM-T-100a** | **A SECOND governed OTA implementation — same event, plus a GPS proximity test.** `pnm_ota_capacity.sql` computes `ota_percentage` as: `action.action_time <= shifting_time + interval '30 mins'` **AND** `ST_DISTANCE(TO_GEOGRAPHY(opp.pickup_location), TO_GEOGRAPHY(action.location)) <= 500` metres. `action` is the **latest `supervisor_actions` row with `action = 'ShiftingStarted'`** per order (`RANK() … ORDER BY event_ts_ist DESC`, `rnk = 1`). | `dbt@00437b8:models/mart/ni_analytics/pnm/pnm_ota_capacity.sql` (L46-53, L80-89) | **verified** | ⚠ **CORRECTED 2026-08-27 — the earlier "differs on the event" reading was wrong.** This is a **supervisor** action of type `ShiftingStarted`, not a vendor arrival event, so it anchors on **the same event as `PNM-T-100`**. The 30 min threshold is corroborated; the real divergence is the **distance term** — see `PNM-T-105a`. **There is no event fork** → rewrites `PNM-G-024`. |
| **PNM-T-101** | **`PNM_EXPERIENCE` rebuilds a trailing 3-month window.** Refresh is daily incremental (delete+insert) with `partition_grain: month`, **`partition_lookback: 3`**, `partition_replay_bounds: 3`. | `dbt@816fa40:models/docs/mart/pnm_experience.yml` | **verified** | ⚠ **This explains and bounds `PNM-G-025`:** a month inside the 3-month window can still change, which is exactly the observed p80 drift. **A month's p80 is structurally final once it falls outside the window.** |
| PNM-T-102 | **Edit-flag derivations:** `IS_MODIFICATION_DONE` = `'Yes'` when `pnm_support.modification_category_list` is not null, else `'No'`. `NO_OF_SUCCESSFUL_EDITS` = count of distinct successful SR modifications in **`Locations` / `ShiftingTime` / `Items` / `AddOns`**, `COALESCE`d to 0. `HAS_SUPPORT_EDIT` = 1 when ≥1 modification came from a source other than the customer app/webview. | `dbt@816fa40:models/docs/mart/pnm_experience.yml` | **verified** | Confirms the four edit categories iteration-1 flagged, and explains why `PNM-M-030` compares to the **string** `'Yes'`. |
| PNM-T-103 | **`PNM_EXPERIENCE` is owned by `DATA_ANALYTICS` / domain `CENTRAL_ANALYTICS`** (`#data-analytics-team`), **not** NI_PNM — unlike `dim_pnm_opportunity`, which is owned by **HSC** (`#hsc-analytics`) with domain `PNM`. Its grain is one row per `order_id`; `contains_pii: false`. | `dbt@816fa40:models/docs/mart/pnm_experience.yml`, `dbt@ad4ab4e:models/docs/dim/dim_pnm_opportunity.yml` | **verified** | These are the governed repo's own `owner:` tags. **The business-accountable owner, per `PNM-T-130`, is PnM Analytics for both** — the dbt tags and the accountable team are not the same question. → `PNM-G-092`, **CLOSED** |
| **PNM-T-130** | **Named PnM-side owner per table, ruled 2026-09-04** (Argus requires one, `PNM-B-071`): `dim_pnm_opportunity` and `pnm_experience` → **PnM Analytics team**; the `PROD_CURATED.PNM_APPLICATION.*` raw application tables (`PNM-T-008`, `PNM-T-009`, `PNM-T-010`, `PNM-T-118`, `PNM-T-119`, `PNM-T-120`…`123`, `PNM-T-125`) → **PnM Engineering team**. This is the accountable team for PnM's purposes, not a replacement for the dbt `owner:` tag (`PNM-T-103`) — the two can legitimately differ. | `owner-ruling:2026-09-04` | **verified** | Closes `PNM-G-092`. Does not resolve the `dim_pnm_opportunity` HSC-vs-`NI_PNM` tag self-contradiction in the governed repo itself — that is a separate question for the model's author, not settled by this ruling. |
| PNM-T-104 | ⚠ **`PNM_EXPERIENCE.VENDOR_ID` carries ~111k orphan values as of 2026-07** and is **deliberately not FK-tested** against `dim_pnm_vendor`, to avoid a false-failing test. | `dbt@816fa40:models/docs/mart/pnm_experience.yml` | **verified** | A known, documented data gap. Any vendor-level join off this mart inherits it. |
| **PNM-T-105** | **A THIRD governed on-time definition exists, and it applies NO distance test.** `pnm_support.on_time_arrival_flag` = `'Yes'` when `ts_ShiftingStarted <= shifting_ts_ist + interval '30 mins'`, else `'No'`. `ts_ShiftingStarted` is the **latest `supervisor_actions` row with `action = 'ShiftingStarted'`** — the *same* rows `PNM-T-100a` reads. It is **documented**: *"Flag that marks if shifting started within 30 minutes of the scheduled time (Yes = on time, No = delayed)."* | `dbt@77f9d63:models/mart/ni_analytics/pnm/pnm_support.sql` (L37-40, L61-68, L158, L175), `dbt@816fa40:models/docs/mart/pnm_support.yml` (L111-113) | **verified** | ⚠ **The 30 min threshold is corroborated three ways. The 500 m is in only two of three.** `pnm_support` + `pnm_ota_capacity` are **not independent** — same table, same action filter, same latest-of rank. ⚠ **But they do NOT differ solely in the distance term** (corrected after review): `pnm_support` filters `user_flag ILIKE 'NORMAL'` and `pnm_ota_capacity` applies no user filter; `pnm_ota_capacity` restricts to intra-city / 6 regions / non-nano / `status='completed'` while `pnm_support` runs over all of `fact_pnm_orders`; and the 30-min baseline is `shifting_requirements.shifting_ts_ist` in one against `fact_pnm_orders.shifting_ts` in the other, never shown equal. **Three population differences on top of the distance one** → `PNM-G-024` |
| **PNM-T-105a** | **The three definitions agree on the event and diverge on the distance term — and on population.** All three anchor on shifting-started. `PNM-T-100` requires **`distance_km < 0.5`**. `PNM-T-100a` requires **`ST_DISTANCE(opportunity pickup → supervisor GPS) <= 500 m`** — a genuine proximity test. `PNM-T-105` requires **no distance at all**, and additionally filters to normal users over a wider order population. | `dbt@816fa40:models/docs/mart/pnm_experience.yml` (L128-129, L241-242), `dbt@00437b8:…pnm_ota_capacity.sql`, `dbt@77f9d63:…pnm_support.sql` | **verified** (each expression read) | ✅ **`PNM-G-098` closed 2026-09-04 — `distance_km`'s formula read directly.** It is `ST_DISTANCE(pickup_point, first_ShiftingStarted_event_location) / 1000` — the **same kind** of proximity test as `PNM-T-100a`'s and the documented `pickup_km_deviation`, not trip distance. `PNM-T-100` **does** test proximity after all. One residual wrinkle: it anchors on the **earliest** `ShiftingStarted` row, where `PNM-T-100a` anchors on the **latest** — so the three definitions' distance terms may still disagree in edge cases with multiple `ShiftingStarted` rows, not just in threshold |
| **PNM-T-106** | **`is_test_user` is governed and identical in two marts:** `CASE WHEN COALESCE(do.user_flag, 'Normal') NOT ILIKE 'Normal%' THEN 1 ELSE 0 END`, off `dim_pnm_orders.user_flag`. Documented in both ymls as *"1 if the order was placed by a non-normal (test) user flag, else 0."* | `dbt@6068580:models/mart/ni_analytics/pnm/pnm_allocation.sql` (L251-252), `dbt@9d78831:models/mart/ni_analytics/pnm/pnm_fare_movement.sql` (L153-154), `dbt@816fa40:models/docs/mart/pnm_allocation.yml` (L59-61) | **verified** | ⚠ **Not the complement *by predicate construction*, but IS the complement on live data (checked 2026-09-04).** The catalog gates on `user_flag ILIKE 'normal'`; this gates on `NOT ILIKE 'Normal%'` over a `COALESCE(…,'Normal')` — two divergences exist on paper: **NULL** and **prefix vs exact** (`'Normal_Test'`). Live `GROUP BY user_flag` on `DIM_PNM_ORDERS` found only `NORMAL`/`TEST`, no NULLs, no third value — neither divergence is currently triggered. Re-check if a new `user_flag` value ever appears. → `PNM-G-073`, `PNM-G-099` (both closed 2026-09-04) |
| PNM-T-107 | **`pnm_support.modification_category_list` IS a derivation — one hop.** The final select is a bare alias (`sr.category_list AS modification_category_list`, L161), but `sr` is the **`sr_mod_agg` CTE**, where `category_list` is built as **`ARRAY_AGG(category) … GROUP BY sr_id`** (L37-40) over the modification records. So the column is a per-`sr_id` array aggregation, not a passthrough. It has **no description** in the yml. | `dbt@77f9d63:models/mart/ni_analytics/pnm/pnm_support.sql` (L37-40, L161), `dbt@816fa40:models/docs/mart/pnm_support.yml` (L117-118) | **verified** | ⚠ **CORRECTED 2026-08-27 — an earlier draft of this row called it "a plain alias, not a derivation". That was wrong**; it read only the final select and missed the CTE. `PNM-T-102`'s `IS_MODIFICATION_DONE` therefore tests an `ARRAY_AGG` result for null, so it is `'No'` exactly when an order has **no** modification rows at all. The same CTE also builds `source_list` and the `tele_agent_modification_flag`. |
| **PNM-T-108** | **`pnm_ota_capacity`'s city cut is a hardcoded 6-city `CASE`, not the governed dimension.** `geo_region_id IN (1,2,3,4,5,8)` → Mumbai / Delhi / Bangalore / Hyderabad / Chennai / Pune, **written out three times** in the model (`ranked_action`, `intracity_orders_with_slot`, `outstation_orders`). Slots are `EXTRACT(HOUR FROM shifting_ts_ist)`: `4-10` morning, `11-15` afternoon, **everything else** evening (so 00:00-03:59 is "evening"). | `dbt@00437b8:models/mart/ni_analytics/pnm/pnm_ota_capacity.sql` (L30-42, L108-120) | **verified** | ⚠ **Anything adopting this model for a city cut inherits a hardcoded mapping** that can drift from `dim_geo_regions`, which `dim_pnm_opportunity` *does* FK-test against (`PNM-T-007`, `PNM-T-035`). → `PNM-G-070` |
| **PNM-T-109** | ⚠ **Two governed models report absent data as a bad outcome.** `pnm_ota_capacity`'s final select uses `MAX(CASE WHEN slot = … THEN ota_percentage ELSE 0 END)`, so a city/date/slot with no OTA row publishes **0%**, not null. `pnm_support.on_time_arrival_flag` uses `ELSE 'No'`, so an order with no `ShiftingStarted` action is labelled **delayed**. | `dbt@00437b8:…pnm_ota_capacity.sql` (L233-235), `dbt@77f9d63:…pnm_support.sql` (L158) | **verified** | ⚠ **Missing data reads as failure in both.** 0% OTA is indistinguishable from "no orders that slot". Directly contrary to the divide-by-zero-returns-null rule this workspace treats as non-negotiable. → `PNM-G-094` |
| PNM-T-110 | **`pnm_ota_capacity` is tagged `exclude_daily`** in the model config, which `bulwark/allowlists.yml` defines as *"excluded from the daily dbt run (DAG tag-based exclusion)"*. Its own docs yml declares `refresh_frequency: "daily"`. It carries no `monthly_run` tag — **which is the norm, not an anomaly:** of 35 non-archive models tagged `exclude_daily`, **34 carry no `monthly_run`**. | `dbt@00437b8:models/mart/ni_analytics/pnm/pnm_ota_capacity.sql` (L1-5), `dbt@816fa40:models/docs/mart/pnm_ota_capacity.yml` (L7), `dbt@main:bulwark/allowlists.yml` (L68) | **verified** (the three cited files read; the 34-of-35 count enumerated across the repo) | ⚠ **Doc-vs-code conflict on refresh cadence.** What cadence it *does* run on is **not** determined by these files — it is untagged for hourly, so it may ride the hourly DAG. Do not infer staleness; establish the cadence. → `PNM-G-095` |
| PNM-T-111 | **`pnm_ota_capacity`'s OTA denominator covers only orders that have a `ShiftingStarted` action.** The `ota` CTE takes `city_name` / `slot` / `shifting_date` from a **`LEFT JOIN`** to `max_action`; orders with no such action get NULL keys, and the final join on `(city_name, slot, shifting_date)` drops them. The `city_name is not null` guard is present but **commented out** (L98-99). | `dbt@00437b8:models/mart/ni_analytics/pnm/pnm_ota_capacity.sql` (L74-102, L237) | **verified** | The published `ota_percentage` is therefore **not** over all completed orders. An unstated population filter. |
| PNM-T-112 | ⚠ **`pnm_ota_capacity`'s "outstation" split is entirely intra-city.** Both `intracity_orders_with_slot` and `outstation_orders` filter `sr.shifting_type = 'intra_city'`; they differ by `cof.distance_meters` `< 50000` vs `>= 50000` **and** by `outstation_orders` omitting the slot `CASE` and the `slot` GROUP BY entirely. All "outstation" load is then attributed to the **morning** slot (`'morning' AS slot`, inline comment *"adding outstation to morning slot"*). | `dbt@00437b8:models/mart/ni_analytics/pnm/pnm_ota_capacity.sql` (L126, L151, L212) | **verified** | A naming trap: `outstation_load` is intra-city ≥50 km by construction, and it inflates `morning_load` regardless of the order's real slot. |
| **PNM-T-114** | ⚠ **Two governed models define "slot" differently, and neither cites the other.** `pnm_ota_capacity`: hours **4-10** morning, **11-15** afternoon, **ELSE** evening (so 00:00-03:59 and 16:00-23:59 are both "evening"). `pnm_support`: hours **6-11** Morning, **12-16** Afternoon, **17-21** Evening — a *bounded* evening, leaving 22:00-05:59 in neither. Different boundaries, different casing, and one has an uncovered range. | `dbt@00437b8:models/mart/ni_analytics/pnm/pnm_ota_capacity.sql` (L38-42), `dbt@77f9d63:models/mart/ni_analytics/pnm/pnm_support.sql` (L131-133) | **verified** | ⚠ **Any slot-level cut must name which model it came from** — "morning" is not one concept across the governed layer. Material to `PNM-G-070`, since a slot cut was part of what made the city cut look cheap. |
| PNM-T-113 | **The capacity load model rests on three hardcoded TAT tables** (`VALUES` lists, per `package_name`): intracity-morning, intracity-afternoon/evening, and outstation. The same package can carry three different TATs — `4 BHK Medium` is `24` / `28.2` / `26.6`. No source, owner, or test attaches to these constants. | `dbt@00437b8:models/mart/ni_analytics/pnm/pnm_ota_capacity.sql` (L160-191) | **verified** | Load-bearing business constants with no provenance. Any capacity figure quoted from this model inherits them. |
| **PNM-T-115** | **A FOURTH OTA definition — outside the dbt layer, and the one the owner adopted (2026-09-04).** Metabase card #37409 ("On Time Arrival %"): on-time = completed, non-Nano, intra-city order where the latest `supervisor_actions` row with `action='ShiftingStarted'` is **within 30 minutes AND within 2 km** of the order's pickup location. Same event as `PNM-T-100`/`100a`/`105` (`ShiftingStarted`); the **2 km** distance matches neither `PNM-T-100`'s 0.5 km nor `PNM-T-100a`'s 0.5 km — a third distance value, not a typo of either. Orders with no `ShiftingStarted` action are bucketed `'Unset'` (excluded from the numerator, kept in the denominator) — **not** folded into a bad outcome, unlike `PNM-T-109`. | `owner-ruling:2026-09-04`; `repo@<pending>:pnm-selfserve/selfserve_nlq/sqlgen.py` (`ota_sql`) | **verified** (both the card SQL and the shipped mirror were read) | **Settles `PNM-G-024`** by adopting a source outside the three it had narrowed to — not by choosing among `PNM-T-100`/`100a`/`105`. Built into the catalog as section `ota`, 7 metrics, `DECISION_LOG:D11`. |
| PNM-T-116 | **`PROD_ELDORIA.RAW.PNM_APPLICATION_SUPERVISOR_ACTIONS`**: `ORDER_ID` (NUMBER), `ACTION` (TEXT), `EVENT_TS_IST` (TIMESTAMP_NTZ), `LOCATION` (GEOGRAPHY), `SUPERVISOR_ID` (NUMBER), `ID` (NUMBER). Same table the two dbt OTA models read (`PNM-T-100a`, `PNM-T-105`), confirmed here independently via live `INFORMATION_SCHEMA`. `DEV_ELDORIA.RAW.*` of the same name is a **byte-identical mirror** — same row count (11,821,346) and `MAX(EVENT_TS_IST)`, checked 2026-09-04. | `live:INFORMATION_SCHEMA@2026-09-04` | **verified** | The catalog's `ota_sql` reads the `PROD_ELDORIA.RAW` copy; Card #37409's own SQL reads the `DEV_ELDORIA.RAW` copy — a deliberate substitution, not a definition change (`PNM-G-024`). |
| PNM-T-117 | **`PROD_ELDORIA.RAW.PNM_APPLICATION_SR_LOCATION_DETAILS`**: `SR_ID` (NUMBER), `LOCATION_TYPE` (NUMBER, `0` = pickup), `LOCATION` (GEOGRAPHY), `ID` (NUMBER), plus address/floor/parking metadata columns not used by the `ota` section. Same row count (67,856,125) and max `CREATED_AT_IST` as its `DEV_ELDORIA.RAW` counterpart, checked 2026-09-04. | `live:INFORMATION_SCHEMA@2026-09-04` | **verified** | Pickup location for the `ota` section's distance test; deduped to the latest row per `sr_id` (`QUALIFY ROW_NUMBER() … ORDER BY id DESC`). |

## The read-only guard

| id | statement | source_ref | confidence |
|---|---|---|---|
| PNM-T-090 | **`assert_read_only()` rejects**, in this order: any `;` (multiple statements); anything not starting `WITH` or `SELECT`; any of `CREATE INSERT UPDATE DELETE MERGE DROP ALTER TRUNCATE COPY GRANT`; and any unsubstituted `:month` / `{month` parameter left in the SQL. | `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` | **verified** |
| PNM-T-091 | **Defence in depth, not the only gate.** `run_tests.py` separately enforces a table allow-list (`EXPECTED_TABLES`), so a query touching an unexpected table fails the suite even if it is a valid `SELECT`. | `repo@851886f:pnm-selfserve/selfserve_nlq/run_tests.py` | **verified** |

## Privacy

`CUSTOMER_MOBILE`, `MOBILE`, `SUPERVISOR_MOBILE`, `CUSTOMER_NAME`, `PICKUP_ADDRESS`,
`DROP_ADDRESS`, `EMAIL`, `VENDOR_LEGAL_NAME` and `vendor_onboarding_infos.aadhaar_number` carry
personal data. **Column *names* are schema facts and are recorded here; no values appear in this KB
and none may be added** (CONTRIBUTING §10).

⚠ Vendor Aadhaar moved to encrypted storage on 2026-07-31 and the plaintext fields were dropped —
that column is now ciphertext (`PNM-G-080`).
