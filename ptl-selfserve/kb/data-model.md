# data-model.md — tables, columns, enums, units

`T-###` rows. Schema and rules: see [CONTRIBUTING.md](./CONTRIBUTING.md). Entry point: [CONTEXT.md](./CONTEXT.md).
All rows `last_verified: 2026-07-29` **except** `T-022`, `T-062`, `T-074`, `T-075`, which carry
`last_verified 2026-08-07`. Per CONTRIBUTING §5 the file-level date is not bumped — only those four
were re-checked against source.

**Warehouse:** Snowflake. **Primary DB in card SQL:** `PROD_CURATED`.
**Ruling D2:** the prototype reads **raw `partload_application`** now; migration to a governed
`fact_ptl_orders` layer is deferred. → `repo@7a43470:ptl-selfserve/DECISION_LOG.md` (D2)

---

## Core enums and encodings — read these first

| id | statement | source_ref | source_updated_at | confidence | note |
|---|---|---|---|---|---|
| **T-001** | **`orders.state` enum: `3=Completed`, `4=Cancelled`.** | `metabase:card/33519` (db83) **+ re-verified on db73** across cards 33485, 33466, 43238, 37104, 47540, 48449, 49365, 39117 | 2026-07-03T08:29:00Z | **verified** | Retires the `STATE_ENUM_CONFIRMED = False` assumption. Re-verified 2026-07-30 on the metric database (db73) after `G-136` showed the original evidence came from a different Metabase connection. Still a human-authored `CASE`, not a data dictionary → `G-013`. |
| **T-001a** | **`0=Open`, `1=Assigned`, `2=Picked_up`** | `metabase:card/33519` (**db83 only**) | 2026-07-03T08:29:00Z | unverified | ⚠️ **Not confirmed on db73.** The only db73 card touching these states (33462) groups `0/1/2` as a single "in-process" bucket without naming them. Split from `T-001` so the well-evidenced half is not dragged down by the weak half → `G-136` |
| T-002 | `payment_status`: `0 = Pending`, else `Completed`. | `metabase:card/33519` | 2026-07-03T08:29:00Z | verified | Binary in SQL; other values not enumerated. |
| T-003 | `contact_details.type`: `0 = sender`, `1 = receiver`. | `metabase:card/33519` | 2026-07-03T08:29:00Z | verified | — |
| T-004 | `load_details.entry_type`: `'CUSTOMER_DECLARED'` vs `'OPS_DECLARED'`; ops rows also gated on `is_active = TRUE`. | `metabase:card/33519` | 2026-07-03T08:29:00Z | verified | Basis of the weight-discrepancy metric. |
| T-005 | `order_fares.fare_reason_code`: `'INITIAL_BOOKING'` (customer-declared fare) vs `'WEIGHT_REVISION_CHANGE'` (ops fare). | `metabase:card/33519` | 2026-07-03T08:29:00Z | verified | Drives the competing AOV bases → `G-004`. |
| T-006 | `slots.EDD_BUFFER_IN_DAYS`: `0 → SDD`, `1 → NDD`, else `NULL`. | `metabase:card/33519` | 2026-07-03T08:29:00Z | verified | Acronym expansions are inferred → `G-014`. |

## Units — silent scaling (prevents 100×/1000× errors)

| id | column | stored as | convert | source_ref | confidence |
|---|---|---|---|---|---|
| T-010 | `orders.estimated_fare` | **paise** | `/100` → rupees | `card/33519` (db83) **+ `card/33706` (db73)**: `sum(estimated_fare/100) as revenue` | **verified** — re-verified on db73 2026-07-30 |
| T-011 | `order_fares.total_fare` | **paise** | `/100` → rupees | `card/33519` (db83) **+ `card/37413`, `card/52889` (db73)**: `total_fare/100.0`, `sum(total_fare / 100)` | **verified** — re-verified on db73 2026-07-30 |
| T-012 | `load_details.chargeable_weight` | **grams** | `/1000` → kg | `metabase:card/33519` (**db83 only**) | unverified | 
| T-013 | Corroboration: card 52889 (db73) uses a column literally named **`discount_amount_minor_units`** — "minor units" is the standard term for paise, confirming the currency convention lexically as well as arithmetically | `metabase:card/52889` | — | verified |

> ⚠️ **`T-012` was NOT re-verified on db73.** No db73 card inspected references `chargeable_weight`
> at all. The grams→kg scaling rests solely on db83 card 33519. Confirm before using any weight
> figure in a db73-sourced metric → `G-136`.

## Segmentation & exclusion rules

| id | statement | source_ref | source_updated_at | confidence | note |
|---|---|---|---|---|---|
| **T-020** | **Business customer** = `CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END`, from `prod_curated.oms_public.customers`, joined `orders.customer_mobile = c.mobile`. | `metabase:dashboard/4569` | see card rows | **verified** | Used *identically* by every segmenting card on 4569. Retires the prototype's unconfirmed `frequency IN (1,2,3,4)` flag. |
| T-021 | Unmatched customers (no row, or `NULL` frequency) fall to **`Personal`** via the `ELSE`. There is no "unknown" bucket. | `metabase:dashboard/4569` | — | verified | Silently biases Personal upward. Material for any business-vs-personal split. |
| T-022 | `prod_eldoria.core.dim_customers` is **never used** on dashboard 4569 — but **is** referenced on dashboard 4198, and on `metabase:card/52812` (joined on `customer_id`, not mobile). Three customer-source patterns are in production. | `metabase:dashboard/4569`, `metabase:dashboard/4198`, `metabase:card/52812` | — | **verified** — *upgraded 2026-08-07* | ✅ **Materiality measured, `G-005` closed.** For the Business/Personal split on VSS sessions, `dim_customers`-on-`customer_id` and `oms_public.customers`-on-`mobile` disagree by **~0.013%** of sessions. They are interchangeable for segmentation at this grain. **Not yet measured on order-grain metrics** — do not generalise the result past sessions → `G-160`. |
| T-023 | **Internal/test users are excluded — by two different mechanisms with the same outcome.** (a) Card 33519: `LEFT JOIN prod_curated.partload_analytics.ptl_internal_users ON ptl_internal_users.mobile = orders.customer_mobile`, driven by an `is_test` parameter that **defaults to `False`**. (b) The CBDF/CADF family on dashboard 4793 (cards 43237, 42683): **hardcoded** `AND o.customer_mobile NOT IN (SELECT DISTINCT mobile FROM partload_analytics.ptl_internal_users)` — no parameter, always applied. | `metabase:card/33519`, `metabase:card/43237` | 2026-07-03T08:29:00Z · 2025-11-27T09:19:28Z | verified | **The absence of an `is_test` *parameter* is not the absence of *exclusion*** — do not re-exclude. Whether *every* metric card excludes internal users remains unaudited → `G-006`. |
| T-024 | **City** is `ptl_routes.zone`, not a column on `orders`. Joined `ptl_routes.route_id = orders.route_id AND ptl_routes.is_active = 'True'` (string, not boolean). | `metabase:card/33519` | 2026-07-03T08:29:00Z | verified | — |

## Time basis

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| T-030 | Storage is **UTC**. Two distinct patterns are in production use: **(a) display/derivation** `CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(col))`; **(b) pruning-safe filter** `col >= DATEADD('minute', -330, <date>::timestamp_ntz)`. | `metabase:card/33519` | verified | Card 33519 carries the inline comment `-- KEY FIX: UTC range enables micro-partition pruning`. |
| T-031 | **Anti-pattern present in production:** one optional filter on card 33519 wraps the column — `DATE(ORDERS.pickup_slot_start + INTERVAL '330 minutes') = {{pickup_date}}` — defeating partition pruning, in the same card that warns against it. | `metabase:card/33519` | verified | Observed, not a KB rule. Do not copy. → `G-018` |
| T-032 | The prototype's month windows use `DATEADD('minute', -330, DATE '…')` on a bare column, preserving pruning, for IST calendar-month boundaries. | `repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py` | verified | Consistent with T-030(b). |
| T-033 | Order time basis is `orders.created_at`; session metrics use `ptl_fe_events.event_ts`. **AOV's source card allegedly uses `updated_at`**, while the prototype uses `created_at` — unreconciled. | `repo@7a43470:ptl-selfserve/selfserve_nlq/`, catalog #55 | unverified | → `G-007` |

## Tables

### `PROD_CURATED.PARTLOAD_APPLICATION` (raw application schema — D2 source path)

| id | table | role | key columns | confidence |
|---|---|---|---|---|
| T-040 | `orders` | order fact table | `id`, `external_id`, `state`, `created_at`, `updated_at`, `pickup_slot_start`, `pickup_slot_end`, `customer_mobile`, `route_id`, `estimated_fare`, `quotation_uuid`, `pickup_lat/lng`, `drop_lat/lng` | verified |
| T-041 | `order_vehicles` | vehicle assignment — **the driver-found signal** | `order_external_id`, `order_id`, `is_active`, `vehicle_name` | verified |
| T-042 | `order_cancellation_reasons` | cancellation reason + timestamp | `order_id`, `order_external_id`, `created_at` | verified |
| T-043 | `quotations` | quote → order link | `quotation_uuid`, `route_configuration_id`, `updated_at` | verified |
| T-044 | `load_details` | declared vs ops weight | `order_id`, `entry_type`, `chargeable_weight`, `is_active`, `material_type_id` | verified |
| T-045 | `order_fares` | fare revisions | `load_details_ids`, `fare_reason_code`, `total_fare` | verified |
| T-046 | `contact_details` | sender/receiver | `order_id`, `type`, `name`, `mobile`, `address_line` | verified |
| T-047 | `material_type` | goods type | `material_type_id`, `display_name` | verified |
| T-048 | `batched_orders_v1` | order → batch | `order_id`, `batch_id`, `updated_at` | verified |
| T-049 | `batch_v1` | batch header | — | verified |
| T-050 | `slots` | route slot config | `route_id`, `route_configuration_id`, `start_time`, `end_time`, `EDD_BUFFER_IN_DAYS`, `created_at` | verified |
| T-051 | `fare_revision_notified` | fare-revision notifications | — | verified |

### `PROD_CURATED.PARTLOAD_ANALYTICS` (curated analytics)

| id | table | role | confidence |
|---|---|---|---|
| T-060 | `ptl_routes` | route master — `route_id`, `route_name`, **`zone` (= city)**, `is_active` | verified |
| T-061 | `ptl_internal_users` | internal/test users, matched by `mobile` | verified |
| T-062 | `ptl_fe_events` | front-end events. **Actual columns:** `record_metadata`, `variable_attr`, `event_timestamp`, `application_version_code`, `customer_mobile_number`, `customer_id`, `event_id`, `device_id`, `device_platform_name`, `app_session_id`, `device_platform_version`, `device_model`, `device_make`, `arrival_timestamp`, `application_version_name`, `event_name`, `screen_name`. Event payloads live in `variable_attr` as JSON. | **verified** — *corrected 2026-08-07* |
| T-063 | `valid_combo_ranking` | clubbing combo ranking, `total_distance_km`, `ordered_order_ids` | verified |
| T-064 | `ALLOCATION_OSRM_v2_DISTANCE` | OSRM combo distances, slot sequences | verified |
| T-065 | `PTL_VALID_COMBO_LOGS` | combo logs | verified |

### Other schemas

| id | table | role | confidence | note |
|---|---|---|---|---|
| T-070 | `PROD_CURATED.OMS_PUBLIC.customers` | **customer master — `frequency` drives the Business/Personal split (T-020)**, joined on `mobile` | verified | — |
| T-071 | `PROD_CURATED.GSHEET_SYNC.ptl_offline_orders` | **offline orders — a Google-Sheet sync, not a system of record** | verified | Ruling D3: show BOTH bases (incl./excl. offline), do not pick. `status_code → state` mapping is **UNMAPPED**; unrecognised values become `NULL` → `G-009` |
| T-072 | `PROD_ELDORIA.CORE.dim_customers` | governed customer dimension | unverified | Referenced on 4198, never on 4569 → `G-005` |
| T-073 | `PROD_CURATED.GSHEET_SYNC.ptl_vendor_details`, `.ptl_table` | vendor/ops sheets | unverified | Sheet-backed; freshness unknown → `G-019`. **See `T-074` — `ptl_table` is no longer live.** |
| **T-074** | `PROD_CURATED.GSHEET_SYNC.PTL_TABLE` | ops order sheet — `PICKUP_REACHED_TIMESTAMP`, `DROP_START_TIMESTAMP`, `WD_MARKED`, `DAMAGED_AT` | **verified** — *added 2026-08-07* | 🛑 **SYNC IS DEAD.** No completed order created after **Jan-2026** has a row here. Even within Jan-2026 its timestamp text had already drifted past the two `TRY_TO_TIMESTAMP` patterns its consumers use. Every card reading it does so with `LEFT JOIN`, so the failure is **silent**: flags resolve `NULL` and ratios render `0%` instead of erroring. Kills `M-017` and `M-018` → `G-154`. **`DAMAGED_AT` is free text (`''`/`'NO'`/`'No'`/`'N0'`/`'YES'`), not a boolean** — reconfirms `G-150`. Live successors: `partload_analytics.ptl_app_sheet_backfilled_data` ∪ `gsheet_sync.ptl_app_sheet_data` (see `M-022`). |
| **T-075** | `PARTLOAD_APPLICATION.VEHICLES.OWNER_ID`, `PARTLOAD_APPLICATION.DRIVERS.OWNER_ID` | the owner foreign key on PTL supply | **verified** — *added 2026-08-07* | ⚠️ **Both columns exist and are 100% `NULL`** (0 populated of 2,750 vehicles and 2,973 drivers). This is stronger than `G-151`'s "may not exist at owner grain": the key is *present and empty*, so no query, card, or dbt model can produce an owner-grain supply metric. Needs instrumentation, not searching. Vehicle grain (`order_vehicles.vehicle_registration_number`) is populated and usable; vendor grain depends on frozen snapshot sheets (`T-073`). → `G-151` |

> **Cross-vertical tables** appearing in 4569's acquisition-thread cards — `pnm_application.orders`,
> `oms_public.orders`, `courier_application.orders`, `oms_public.vehicles`,
> `trucks.vehicle_segment_mapping_v2` — are used to classify a customer's *first* Porter product.
> They are **not** PTL order sources. Do not aggregate PTL metrics over them.

## Privacy

`orders.customer_mobile`, `contact_details.name/mobile/address_line`, `driver_name`, `driver_mobile`
and `VEHICLE_REGISTRATION_NUMBER` carry personal data. Column **names** are schema facts and are
recorded here; **no values** appear in this KB and none may be added. See CONTRIBUTING §9.
