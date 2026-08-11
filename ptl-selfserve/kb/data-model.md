# data-model.md — tables, columns, enums, units

`T-###` rows. Schema and rules: see [CONTRIBUTING.md](./CONTRIBUTING.md). Entry point: [CONTEXT.md](./CONTEXT.md).
All rows `last_verified: 2026-07-29`.

**Warehouse:** Snowflake. **Primary DB in card SQL:** `PROD_CURATED` — but ⚠️ **the namespace is not
uniform across PTL tables**, and the prefix is not cosmetic. See `T-074` before writing any query.
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
| T-004 | `load_details.entry_type`: `'CUSTOMER_DECLARED'` vs `'OPS_DECLARED'`; ops rows also gated on `is_active = TRUE`. | `metabase:card/33519` | 2026-07-03T08:29:00Z | verified | Basis of the weight-discrepancy metric. ⚠️ `[unverified · notion:36a9…]` Production practice asserts **exactly one active row per order — "safe to join directly without deduplication"**. That is *not* a contradiction (a declared row may be inactive while the ops row is active), but if it holds, the declared-vs-ops comparison is not computable from active rows alone — which is the basis of catalogue #37. → `G-165`. `last_verified 2026-08-11` |
| T-005 | `order_fares.fare_reason_code`: `'INITIAL_BOOKING'` (customer-declared fare) vs `'WEIGHT_REVISION_CHANGE'` (ops fare). | `metabase:card/33519` | 2026-07-03T08:29:00Z | verified | Drives the competing AOV bases → `G-004`. |
| T-006 | `slots.EDD_BUFFER_IN_DAYS`: `0 → SDD`, `1 → NDD`, else `NULL`. | `metabase:card/33519` | 2026-07-03T08:29:00Z | verified | Acronym expansions are inferred → `G-014`. |

## Namespace — which schema a table actually resolves in

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| **T-074** | **The namespace is not uniform across PTL tables, and the `prod_curated` prefix is not cosmetic.** `[unverified · notion:36a9…]` Production practice holds that `partload_application.orders` and `prod_curated.partload_application.orders` resolve to **different physical objects with different row counts** and a material revenue delta, and prescribes: read core order/route tables (`orders`, `ptl_routes`, `ptl_fe_events`) **unprefixed**; read `order_vehicles`, `order_cancellation_reasons`, `load_details`, `batched_orders_v1` via **`prod_curated`**. Allocation-time queries specifically require `prod_curated.partload_application.order_vehicles`. | `notion:36a9c6eaaa6d809db065efc12ecf4f42` | unverified | ⚠️ **Assign tier per half.** The *internal-users* namespace claim is **tier 3** (reconciled vs `metabase:dashboard/4632`); the *orders* claim names no surface and is **tier 5**. ⚠️ **The source contradicts itself here** — it mandates the prefixed `ptl_internal_users` in one rule and then writes *"same table as order queries, no prod_curated prefix"* elsewhere, using the unprefixed form in four queries → `G-168`. **Blast radius:** `M-005`/`M-006` quote the **unprefixed** internal-users table, so if the claim holds they exclude a different population from the weekly report. **The KB is separately inconsistent with itself here, independent of this source** — `T-061` files `ptl_internal_users` under `PROD_CURATED.PARTLOAD_ANALYTICS` while `M-005` quotes card 43237's unprefixed reference and `T-023` quotes both forms. → `G-155` |
| T-075 | `partload_analytics.ptl_discount_groups` — discount-experiment assignment. Columns: `group_name` ∈ {`CG`,`TG1`,`TG2`}, `city`, `uuid`. Joined to the customer dimension on `dim_customers.customer_uuid = ptl_discount_groups.uuid`. | `notion:36a9c6eaaa6d809db065efc12ecf4f42` | unverified | Placed in this section rather than `## Tables` because that section's analytics table carries **no `source_ref` column**, and a row without provenance is not a fact (CONTRIBUTING §1). Experiment context → `B-079`. `last_verified 2026-08-11` |

## Units — silent scaling (prevents 100×/1000× errors)

| id | column | stored as | convert | source_ref | confidence |
|---|---|---|---|---|---|
| T-010 | `orders.estimated_fare` | **paise** | `/100` → rupees | `card/33519` (db83) **+ `card/33706` (db73)**: `sum(estimated_fare/100) as revenue` | **verified** — re-verified on db73 2026-07-30 |
| T-011 | `order_fares.total_fare` | **paise** | `/100` → rupees | `card/33519` (db83) **+ `card/37413`, `card/52889` (db73)**: `total_fare/100.0`, `sum(total_fare / 100)` | **verified** — re-verified on db73 2026-07-30 |
| T-012 | `load_details.chargeable_weight` | **grams** | `/1000` → kg | `metabase:card/33519` (**db83 only**) | unverified | 
| T-013 | Corroboration: card 52889 (db73) uses a column literally named **`discount_amount_minor_units`** — "minor units" is the standard term for paise, confirming the currency convention lexically as well as arithmetically. `[unverified · notion:36a9…]` The same column is used in production to reconstruct gross-of-discount revenue and to flag discounted orders (`quotations.discount_amount_minor_units > 0`) → `M-008` | `metabase:card/52889` | — | verified |
| **T-076** | **Type traps requiring an explicit cast** `[unverified · notion:36a9…]` — three, all silent: (a) `ptl_internal_users.mobile` is **numeric** while `ptl_fe_events.customer_mobile_number` is a **string**, so exclusion joins across the two need `TO_VARCHAR`; (b) `variable_attr:vehicle_id` is a **string** in `vehicleselectionscreen_confirm_clicked` but a **number** in the VSS event — do not unify them; (c) `variable_attr:route_id` is a JSON **string** needing `TRY_TO_NUMBER` before joining `ptl_routes.route_id`. | `notion:36a9c6eaaa6d809db065efc12ecf4f42` | unverified | Column **names** only, no values (CONTRIBUTING §9). Extends `T-023`'s two exclusion mechanisms with a third call site — `ptl_fe_events` — that neither `T-023` nor `G-006` covers. `last_verified 2026-08-11` |

> ⚠️ **`T-012` was NOT re-verified on db73.** No db73 card inspected references `chargeable_weight`
> at all. The grams→kg scaling rests solely on db83 card 33519. Confirm before using any weight
> figure in a db73-sourced metric → `G-136`.

## Segmentation & exclusion rules

| id | statement | source_ref | source_updated_at | confidence | note |
|---|---|---|---|---|---|
| **T-020** | **Business customer** = `CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END`, from `prod_curated.oms_public.customers`, joined `orders.customer_mobile = c.mobile`. | `metabase:dashboard/4569` | see card rows | **verified** | Used *identically* by every segmenting card on 4569. Retires the prototype's unconfirmed `frequency IN (1,2,3,4)` flag. ⚠️ **The PREDICATE is settled; the TABLE is not.** `[unverified · notion:36a9…]` Production reporting applies the identical `frequency IN (1,2,3,4)` test to **`prod_eldoria.core.dim_customers`**, joined on `customer_uuid` — a different customer master. This is `G-005`'s 4198-vs-4569 split surfacing a third time, now in live reporting, and it compounds `G-012`'s `user_type`-vs-`frequency` clash. Card SQL (tier 1) outranks the tier-5 claim, so **this row holds** — but CONTEXT names it as an error-prevention fact, and a contested fact must say so. → `G-163`, `T-072`. `last_verified 2026-08-11` |
| T-021 | Unmatched customers (no row, or `NULL` frequency) fall to **`Personal`** via the `ELSE`. There is no "unknown" bucket. | `metabase:dashboard/4569` | — | verified | Silently biases Personal upward. Material for any business-vs-personal split. |
| T-022 | `prod_eldoria.core.dim_customers` is **never used** on dashboard 4569 — but **is** referenced on dashboard 4198. The two dashboards disagree on customer source. | `metabase:dashboard/4569`, `metabase:dashboard/4198` | — | unverified | Unresolved cross-dashboard conflict → `G-005`. |
| T-023 | **Internal/test users are excluded — by two different mechanisms with the same outcome.** (a) Card 33519: `LEFT JOIN prod_curated.partload_analytics.ptl_internal_users ON ptl_internal_users.mobile = orders.customer_mobile`, driven by an `is_test` parameter that **defaults to `False`**. (b) The CBDF/CADF family on dashboard 4793 (cards 43237, 42683): **hardcoded** `AND o.customer_mobile NOT IN (SELECT DISTINCT mobile FROM partload_analytics.ptl_internal_users)` — no parameter, always applied. | `metabase:card/33519`, `metabase:card/43237` | 2026-07-03T08:29:00Z · 2025-11-27T09:19:28Z | verified | **The absence of an `is_test` *parameter* is not the absence of *exclusion*** — do not re-exclude. Whether *every* metric card excludes internal users remains unaudited → `G-006`. ⚠️ `[unverified · notion:36a9…]` **The "same outcome" clause is CONTESTED.** Production practice states the two mechanisms return **different counts** — "`LEFT JOIN` anti-join instead of `NOT IN` → different result from Metabase 4632 (verified gap)". Recorded, **not corrected**: this row is card SQL (tier 1), the contrary claim is tier 3, so the row holds. The claim is also confounded — its `NOT IN` form reads the `prod_curated`-prefixed table while the anti-join form reads the unprefixed one (`T-074`), so mechanism and namespace are not separable as stated. → `G-164`. `last_verified 2026-08-11` |
| T-024 | **City** is `ptl_routes.zone`, not a column on `orders`. Joined `ptl_routes.route_id = orders.route_id AND ptl_routes.is_active = 'True'` (string, not boolean). | `metabase:card/33519` | 2026-07-03T08:29:00Z | verified | `[unverified · notion:36a9…]` **Why the `is_active` predicate is mandatory, not optional:** `ptl_routes` carries **duplicate rows**, so omitting it inflates city-level order counts silently. Either filter on `is_active = 'True'` or `SELECT DISTINCT route_id`. Source *adds* this consequence; it does not contradict the row. `last_verified 2026-08-11` |

## Time basis

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| T-030 | Storage is **UTC**. Two distinct patterns are in production use: **(a) display/derivation** `CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(col))`; **(b) pruning-safe filter** `col >= DATEADD('minute', -330, <date>::timestamp_ntz)`. | `metabase:card/33519` | verified | Card 33519 carries the inline comment `-- KEY FIX: UTC range enables micro-partition pruning`. **This row does not claim the two are interchangeable** — they serve different purposes. `B-034` and CONTEXT hard rule 7 *do* imply interchangeability, and `[unverified · notion:36a9…]` production practice denies it at slot boundaries. That denial is treated as a **source defect**, not a KB conflict: IST is a fixed +05:30 offset with no DST, the source supplies no mechanism, and the same source uses `+ interval '330 mins'` inside its own slot-anchored allocation formula. → `G-168`. `last_verified 2026-08-11` |
| T-031 | **Anti-pattern present in production:** one optional filter on card 33519 wraps the column — `DATE(ORDERS.pickup_slot_start + INTERVAL '330 minutes') = {{pickup_date}}` — defeating partition pruning, in the same card that warns against it. | `metabase:card/33519` | verified | Observed, not a KB rule. Do not copy. → `G-018` |
| T-032 | The prototype's month windows use `DATEADD('minute', -330, DATE '…')` on a bare column, preserving pruning, for IST calendar-month boundaries. | `repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py` | verified | Consistent with T-030(b). |
| T-033 | **Date basis is per-cadence, and the two must never be mixed.** `[unverified · notion:36a9…]` **Weekly** reporting uses `orders.created_at`; **monthly** reporting uses `orders.updated_at`, which for `state=3` is the completion/delivery timestamp. A cross-month next-day order (placed on the last of a month, completed on the first of the next) lands in different periods under each, so the two bases disagree on the **order count**, not merely on AOV. Session metrics use `ptl_fe_events` (⚠️ column name contested, `T-062` → `G-159`). | `notion:36a9c6eaaa6d809db065efc12ecf4f42` (tier 3, reconciled vs `metabase:dashboard/4632`) · `repo@7a43470:ptl-selfserve/selfserve_nlq/`, catalog #55 | unverified | **CORRECTED 2026-08-11** per CONTRIBUTING §6 tier 3 — the superseded wording was: *"Order time basis is `orders.created_at`; session metrics use `ptl_fe_events.event_ts`. **AOV's source card allegedly uses `updated_at`**, while the prototype uses `created_at` — unreconciled."* That wording also pointed at **`G-007`, which closed 2026-07-30**; the live successor is **`G-135`**. Cadence rule → `G-158`; count impact → `M-002`. `last_verified 2026-08-11` |

## Tables

### `PROD_CURATED.PARTLOAD_APPLICATION` (raw application schema — D2 source path)

| id | table | role | key columns | confidence |
|---|---|---|---|---|
| T-040 | `orders` | order fact table | `id`, `external_id`, `state`, `created_at`, `updated_at`, `pickup_slot_start`, `pickup_slot_end`, `customer_mobile`, `route_id`, `estimated_fare`, `quotation_uuid`, `pickup_lat/lng`, `drop_lat/lng` | verified |
| T-041 | `order_vehicles` | vehicle assignment — **the driver-found signal**; also the allocation-time clock (`M-021`/`M-022`) and the only known reallocation signal | `order_external_id`, `order_id`, `is_active`, `vehicle_name`, `created_at` `[unverified · notion:36a9…]`, `vehicle_id` `[unverified · notion:36a9…]` | verified |
| T-042 | `order_cancellation_reasons` | cancellation reason + timestamp | `order_id`, `order_external_id`, `created_at` | verified |
| T-043 | `quotations` | quote → order link | `quotation_uuid`, `route_configuration_id`, `updated_at` | verified |
| T-044 | `load_details` | declared vs ops weight | `order_id`, `entry_type`, `chargeable_weight`, `is_active`, `material_type_id` | verified |
| T-045 | `order_fares` | fare revisions. ⚠️ **Two different fare-selection paths are in use:** `T-005`'s `fare_reason_code`, and `[unverified · notion:36a9…]` a boolean `is_current_fare = TRUE` joined on `order_id` — the monthly-revenue path (`M-008`) | `load_details_ids`, `fare_reason_code`, `total_fare`, `order_id` `[unverified · notion:36a9…]`, `is_current_fare` `[unverified · notion:36a9…]` | verified |
| T-046 | `contact_details` | sender/receiver | `order_id`, `type`, `name`, `mobile`, `address_line` | verified |
| T-047 | `material_type` | goods type | `material_type_id`, `display_name` | verified |
| T-048 | `batched_orders_v1` | order → batch. ⚠️ **`[unverified · notion:36a9…]` The join key is `order_external_id = orders.external_id`, NOT `order_id`.** Joining on `order_id` returns **zero rows silently** — no error, just an empty result that reads as "no clubbing". The table also holds **every** completed trip including solo 1-order batches → `M-007`, `G-162` | `order_id`, `batch_id`, `updated_at`, `order_external_id` `[unverified · notion:36a9…]`, `status` `[unverified · notion:36a9…]` | verified |
| T-049 | `batch_v1` | batch header | — | verified |
| T-050 | `slots` | route slot config | `route_id`, `route_configuration_id`, `start_time`, `end_time`, `EDD_BUFFER_IN_DAYS`, `created_at` | verified |
| T-051 | `fare_revision_notified` | fare-revision notifications | — | verified |

### `PROD_CURATED.PARTLOAD_ANALYTICS` (curated analytics)

| id | table | role | confidence |
|---|---|---|---|
| T-060 | `ptl_routes` | route master — `route_id`, `route_name`, **`zone` (= city)**, `is_active` | verified |
| T-061 | `ptl_internal_users` | internal/test users, matched by `mobile` | verified |
| T-062 | `ptl_fe_events` | front-end events — `event_ts`, `user_type` (`'Business'`). ⚠️ **Time-column name is CONTESTED:** this row records `event_ts`; `[unverified · notion:36a9…]` five working production queries use **`event_timestamp`** → `G-159`. ⚠️ **`user_type` is not used in practice** — it appears **zero** times in the source, whose four queries segment Business via `dim_customers.frequency` instead → `G-012`, `G-163`. Further columns `[unverified · notion:36a9…]`: `app_session_id` (one session = one booking attempt; a user has many), `variable_attr` (JSON — carries `route_id` as a **string** needing `TRY_TO_NUMBER`, `vehicle_ids_seq`, `experiment_key`, `variant_name`, `vehicle_id`), `customer_mobile_number` (string — see `T-076`), `application_version_code`. `variant_name` value space is inconsistent and must be normalised: TG ∈ {`Target Group`,`TG`,`TG1`}, CG ∈ {`Control Group`,`control`,`Control`} | verified |
| T-063 | `valid_combo_ranking` | clubbing combo ranking, `total_distance_km`, `ordered_order_ids` | verified |
| T-064 | `ALLOCATION_OSRM_v2_DISTANCE` | OSRM combo distances, slot sequences | verified |
| T-065 | `PTL_VALID_COMBO_LOGS` | combo logs | verified |

### Other schemas

| id | table | role | confidence | note |
|---|---|---|---|---|
| T-070 | `PROD_CURATED.OMS_PUBLIC.customers` | **customer master — `frequency` drives the Business/Personal split (T-020)**, joined on `mobile` | verified | — |
| T-071 | `PROD_CURATED.GSHEET_SYNC.ptl_offline_orders` | **offline orders — a Google-Sheet sync, not a system of record** | verified | Ruling D3: show BOTH bases (incl./excl. offline), do not pick. `status_code → state` mapping is **UNMAPPED**; unrecognised values become `NULL` → `G-009` |
| T-072 | `PROD_ELDORIA.CORE.dim_customers` | governed customer dimension | unverified | Referenced on 4198, never on 4569 → `G-005`. ⚠️ `[unverified · notion:36a9…]` **It is in live PTL production use** — the funnel and discount-experiment queries segment Business off `dim_customers.frequency IN (1,2,3,4)`, i.e. the same rule as `T-020` but a *different table*. Join keys observed: `customer_uuid` and `customer_id` (the latter in a filter its own CTE never projects, so that path cannot execute). This bears on `G-005` (which table is canonical), `G-163` (the Business definition), and `G-132` (PTL already depends on the governed dbt layer D2 defers). `last_verified 2026-08-11` |
| T-073 | `PROD_CURATED.GSHEET_SYNC.ptl_vendor_details`, `.ptl_table` | vendor/ops sheets | unverified | Sheet-backed; freshness unknown → `G-019` |

> **Cross-vertical tables** appearing in 4569's acquisition-thread cards — `pnm_application.orders`,
> `oms_public.orders`, `courier_application.orders`, `oms_public.vehicles`,
> `trucks.vehicle_segment_mapping_v2` — are used to classify a customer's *first* Porter product.
> They are **not** PTL order sources. Do not aggregate PTL metrics over them.

## Privacy

`orders.customer_mobile`, `contact_details.name/mobile/address_line`, `driver_name`, `driver_mobile`
and `VEHICLE_REGISTRATION_NUMBER` carry personal data. Column **names** are schema facts and are
recorded here; **no values** appear in this KB and none may be added. See CONTRIBUTING §9.
