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
> all) are `unverified`: that live read happened on 2026-07-29 for a different piece of work, and
> **this KB did not run it** — it reaches us through a prose document's `[LIVE]` tags, which
> CONTRIBUTING §5 does not admit as `verified`. The live read still **outranks the Notion schema
> guide** (rung 4 vs rung 8, `PNM-G-023`); it just is not first-hand here. → `PNM-G-042`

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

*`source_ref` for every row above: `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` for the
table's identity and role — **`verified`**, the shipped SQL reads it. The `live cols` counts are
`live:INFORMATION_SCHEMA@2026-07-29` and are **`unverified`** per the header note.*

> **PNM-T-007** — `PROD_ELDORIA.CORE.DIM_GEO_REGIONS` (1 row = 1 city/geo region, 23 cols) is the
> **city lookup table**, joined `SHIFTING_REQUIREMENTS.GEO_REGION_ID = DIM_GEO_REGIONS.GEO_REGION_ID`.
> ⚠ **No catalog SQL reads it** and it is absent from `run_tests.py`'s `EXPECTED_TABLES` allow-list —
> it is listed here because it is where a **city cut would come from** if `PNM-G-070` is ever closed,
> and because card #47576 uses it. `source_ref: live:INFORMATION_SCHEMA@2026-07-29` · `unverified`

### Tables that exist but the catalog does NOT read

| id | table | statement | source_ref | confidence |
|---|---|---|---|---|
| PNM-T-015 | `PROD_ELDORIA.MART.PNM_SUPPORT` | 1 row = 1 order, 36 cols. Not read by any catalog section. | `live:INFORMATION_SCHEMA@2026-07-29` | unverified |
| PNM-T-016 | `PROD_ELDORIA.MART.PNM_ALLOCATION` | 1 row = 1 order, 34 cols — the allocation journey (`ALLOCATION_CHANNEL`, `ALLOCATION_TAT_MINUTES`, `IS_ALLOCATED`, `DEALLOCATION_COUNT`, `CANCELLATION_TYPE` CAC/PAC/PoAC). ⚠ **Carries `IS_NANO_ORDER` and `IS_TEST_USER`** — the only two tables that do. Announced 2026-07-14, refreshed every morning. | `live:INFORMATION_SCHEMA@2026-07-29` | unverified |
| PNM-T-017 | `PROD_ELDORIA.MART.PNM_FARE_MOVEMENT` | 1 row = 1 order, 31 cols — how a fare moves across the lifecycle (`BOOKING_FINAL_FARE`, `FARE_DELTA`, `IS_EDITED_POST_START`). ⚠ Also carries `IS_NANO_ORDER` and `IS_TEST_USER`. | `live:INFORMATION_SCHEMA@2026-07-29` | unverified |

> Both marts are absent from the Notion schema guide and **the MBR automation already reads them**,
> while this catalog does not → `PNM-G-072`.

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
> The *absence of any test filter in the shipped SQL* is **`verified`**
> (`repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` + the two rendered SQL files); *which tables
> carry `IS_TEST_USER`* is `live:INFORMATION_SCHEMA@2026-07-29` and **`unverified`**. → `PNM-G-073`

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
| **PNM-T-100a** | **A SECOND governed OTA implementation agrees on the thresholds and differs on the event.** `pnm_ota_capacity.sql` computes `ota_percentage` as: `action.action_time <= shifting_time + interval '30 mins'` **AND** `ST_DISTANCE(pickup_location, action.location) <= 500` metres. | `dbt@00437b8:models/mart/ni_analytics/pnm/pnm_ota_capacity.sql` | **verified** | ⚠ **30 min + 500 m is now confirmed by two independent governed models** — the threshold half of `PNM-G-024` is settled beyond doubt. ⚠ **But the anchors differ:** this one keys off a **vendor action event and its GPS location** (closer to true *arrival*); `PNM-T-100` keys off **shifting-started**. Two governed OTA numbers can legitimately disagree. |
| **PNM-T-101** | **`PNM_EXPERIENCE` rebuilds a trailing 3-month window.** Refresh is daily incremental (delete+insert) with `partition_grain: month`, **`partition_lookback: 3`**, `partition_replay_bounds: 3`. | `dbt@816fa40:models/docs/mart/pnm_experience.yml` | **verified** | ⚠ **This explains and bounds `PNM-G-025`:** a month inside the 3-month window can still change, which is exactly the observed p80 drift. **A month's p80 is structurally final once it falls outside the window.** |
| PNM-T-102 | **Edit-flag derivations:** `IS_MODIFICATION_DONE` = `'Yes'` when `pnm_support.modification_category_list` is not null, else `'No'`. `NO_OF_SUCCESSFUL_EDITS` = count of distinct successful SR modifications in **`Locations` / `ShiftingTime` / `Items` / `AddOns`**, `COALESCE`d to 0. `HAS_SUPPORT_EDIT` = 1 when ≥1 modification came from a source other than the customer app/webview. | `dbt@816fa40:models/docs/mart/pnm_experience.yml` | **verified** | Confirms the four edit categories iteration-1 flagged, and explains why `PNM-M-030` compares to the **string** `'Yes'`. |
| PNM-T-103 | **`PNM_EXPERIENCE` is owned by `DATA_ANALYTICS` / domain `CENTRAL_ANALYTICS`** (`#data-analytics-team`), **not** NI_PNM — unlike `dim_pnm_opportunity`, which is owned by **HSC** (`#hsc-analytics`) with domain `PNM`. Its grain is one row per `order_id`; `contains_pii: false`. | `dbt@816fa40:models/docs/mart/pnm_experience.yml`, `dbt@ad4ab4e:models/docs/dim/dim_pnm_opportunity.yml` | **verified** | Three different owners across the tables this catalog reads → `PNM-G-092` |
| PNM-T-104 | ⚠ **`PNM_EXPERIENCE.VENDOR_ID` carries ~111k orphan values as of 2026-07** and is **deliberately not FK-tested** against `dim_pnm_vendor`, to avoid a false-failing test. | `dbt@816fa40:models/docs/mart/pnm_experience.yml` | **verified** | A known, documented data gap. Any vendor-level join off this mart inherits it. |

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
