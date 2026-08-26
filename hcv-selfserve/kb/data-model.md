# data-model.md — tables, columns, enums, units, time bases

`T-###` rows. Schema and rules: [CONTRIBUTING.md](./CONTRIBUTING.md). Entry point: [CONTEXT.md](./CONTEXT.md).
All rows `last_verified: 2026-08-14`.

**Warehouse:** Snowflake. **Primary objects:** `PROD_ELDORIA.mart` (HCV marts), `PROD_CURATED.oms_public`
(OMS), `PROD_ELDORIA.core` (dims and facts). Legacy `PROD_CURATED.trucks.*` still backs several
dashboard cards → `T-062`.

Sections are ordered highest-leverage first. **Read §1 before writing any HCV query.**

---

## §1 Core enums and encodings — read these first

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| **T-001** | **`order_status` enum: `4 = completed`, `5 = cancelled`.** | `repo@20f6416:hcv-selfserve/hcv_metrics_queries.md#L30` (`pack:§0`) — `CASE WHEN d.order_status = 4 THEN 1 ELSE 0 END AS completed_flag`; same encoding in `pack:§2`, `§3`, `§6`. `store:metric.porter.cadf` independently describes cancellation as `status = 5` | **verified** | Applies to `hcv_overall_demand_mart.order_status` **and** `oms_public.orders.status` (`pack:§1` uses `o.status = 4` for completed) |
| **T-002** | **`COALESCE(order_status, 5)` — a NULL status is silently treated as *cancelled*.** Appears **12 times** across the pack. | `repo@20f6416:…#L28` and 11 further occurrences | **verified** | A row with no status is counted in the denominator as a cancellation, never as completed. Nothing records *why* status is ever NULL → `G-004` |
| **T-003** | ⚠️ **Cross-vertical collision: `4` means the opposite thing in PTL.** PTL's `T-001` is `3 = Completed, 4 = Cancelled`. HCV's is `4 = completed, 5 = cancelled`. | `T-001` + PTL `repo@28703aa:ptl-selfserve/kb/data-model.md` (`T-001`) | **verified** | This branch is cut from PTL's and PTL's KB is the template beside it. Highest-probability misreading in this KB → `CONTEXT.md` hard rule 2 |

> ⚠️ **Never carry a status literal between PTL and HCV.** `status = 4` filters *cancelled* orders in
> PTL and *completed* orders in HCV. There is no shared enum.

---

## §2 Time basis — two coexist, applied unevenly

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| **T-010** | **`hcv_overall_demand_mart.order_time` is already IST** (`TIMESTAMP_NTZ`). No shift needed. | Data Catalog `model.porter.hcv_overall_demand_mart` → *"Canonical order timestamp in IST"* | **verified** | Confirms the pack is correct to filter `order_time` bare while shifting OMS |
| **T-010a** | **`order_time` has a fallback chain, and one fallback is not a booking time.** Express: `fact_orders.created_at` IST, falling back to SO `created_at` IST. Scheduled: `fact_orders.created_at` IST, falling back to **SO slot start timestamp** IST. | Data Catalog, same description | **verified** | A scheduled order with no FO row is dated by **when it was to be executed**, not when it was booked. Monthly counts mix two time semantics → `G-005` |
| **T-011** | **`oms_public.orders.created_at` is UTC** — needs `+ interval '330 minutes'` for IST. | `repo@20f6416:…#L88,L93` (`pack:§1`) | **verified** | The pack applies it consistently in `§1` |
| **T-012** | `fo_trip_accepted_time` is a **UTC epoch second**, converted via `CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP_NTZ(...))`. | `repo@20f6416:…#L391` (`pack:§4`) | **verified** | Guarded by `> 0` and a `0–3600s` sanity window; negatives and garbage are dropped |
| **T-013** | ⚠️ Card 28841 (ATA) has an **IST double-shift** — adds 5h30m to an already-IST column for bucketing while filtering on the un-shifted date. | `nb1882` scope notes | unverified | Reported by the inventory; **not** read from the card SQL by this KB → `G-006` |

> ⚠️ **Do not assume a time basis from a column name.** `order_time` is IST; `created_at` is UTC.
> Both appear in the same pack. Check `T-010`/`T-011` before writing any date filter.

---

## §3 Segmentation and exclusion — the standard HCV scope

Every pack section applies these unless noted. A query missing any one of them is not comparable to
a reported HCV number.

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| **T-020** | Test customer excluded: `customer_mobile <> '0000000001'`. | `repo@20f6416:…#L38` | **verified** | Single hardcoded literal; no `is_test` parameter exists in the pack |
| **T-021** | HCV vehicle scope: `vehicle_mapping IN ('9ft','10ft','14ft','17ft','19ft')`. | `repo@20f6416:…#L37` | **verified** | `v.level0_mapping = 'HCV'` is used instead in `pack:§5` (partner side) — a different filter reaching the same intent → `G-007` |
| **T-021a** | ⚠️ Card 32713's `vehicle_category` picklist offers **`8ft`**, outside `T-021`'s scope. | `metabase:card/32713` (`database_id: 108`), read 2026-08-14 | **verified** | A dashboard user can select a category the HCV definition excludes → `G-008` |
| **T-022** | Tier 1 scope: `dim_geo_regions.tier = 'Tier 1'`, written `UPPER(g.tier) = 'TIER 1'` in the mart-based sections. | `repo@20f6416:…#L39,L100` | **verified** | — |
| **T-022a** | ⚠️ **Tier encoding drifts.** Card 32713 uses `Tier1` / `Tier2` (**no space**) against `TIER_STATUS` on `prod_curated.trucks.GEO_REGIONS_ROI`, not `dim_geo_regions.tier`. | `metabase:card/32713`, read 2026-08-14 | **verified** | Different column, different literal. A Tier selection can silently return empty → `CONTEXT.md` hard rule 9 |
| **T-022b** | ⚠️ Tier is also derived by a hardcoded `CASE geo_region_id IN (1,2,3,4,5,6,8,9) THEN 'Tier 1' ELSE 'Tier 2'` repeated across ≥8 cards on `4146`. | `nb4146` scope notes | unverified | A business rule buried in SQL rather than a governed dimension → `G-009` |
| **T-023** | **NCR = `geo_region_id = 2`.** Used only to split 10ft. | `repo@20f6416:…#L381,L499` | **verified** | The same id is "Delhi" in card 32713's default → `T-024a` |

---

## §3a Booking-type taxonomy — SO / Express / SPOT

Defined in card SQL and **nowhere else in this KB's sources**. It is how `dashboard/6406`
consolidates the OMS and SO legs.

| id | statement | source_ref | confidence |
|---|---|---|---|
| **T-027** | `so_is_express_booking = FALSE` → **Schedule Order** | `metabase:card/55561` (`database_id: 108`) · `source_updated_at: 2026-08-12T12:24:41Z` | **verified** |
| **T-027a** | `so_is_express_booking = TRUE` **and** `so_driver_assignment_type <> 4` → **Express Order** | same | **verified** |
| **T-027b** | `so_is_express_booking = TRUE` **and** `so_driver_assignment_type = 4` → **SPOT on Tray Order**. `so_driver_assignment_type = 4` is the SOT marketplace marker | same | **verified** |
| **T-027c** | else → **SPOT Order** (reachable only when `so_is_express_booking` is NULL) | same | **verified** |
| **T-028** | Demand on `6406` is `COUNT(DISTINCT unique_id)` — the same grain key the pack uses | `metabase:card/55561` | **verified** |
| **T-029** | ⚠️ **`6406`'s Demand card has its status filter commented out** (`-- and o.status in (4,5)`), so it counts **every** status. The pack's demand base is `COALESCE(order_status,5) IN (4,5)` (`T-001`, `T-002`). `-- and o.order_type = 0` is commented out too | `metabase:card/55561` native SQL | **verified** |

> ⚠️ **"Demand" on `dashboard/6406` and "total placed" in the pack are different populations.**
> The dashboard counts all statuses; the pack counts `(4,5)` only. Do not compare the two numbers
> without restating one of them → `G-013`.

---

## §4 Category — a dimension whose members overlap

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| **T-024** | ⚠️ **In `pack:§2`, `§3` and `§6` the category dimension contains overlapping members.** A `UNION ALL` emits a `10ft` row **plus** `10ft - NCR` **plus** `10ft - non NCR`, so **every 10ft order appears twice**. | `repo@20f6416:…#L496–L507` (`pack:§6` `cat` CTE); same construct in `§2`, `§3` | **verified** | Summing any measure across category **double-counts 10ft** → `CONTEXT.md` hard rule 6 |
| **T-024a** | `pack:§4` uses a `CASE`, not a `UNION ALL` — its categories are **mutually exclusive** and there is no `10ft` overall row. | `repo@20f6416:…#L380–L384` | **verified** | Three different category treatments exist across the pack; `§1`/`§2a`/`§3a`/`§5` have no category dimension at all |
| **T-025** | Distance bucket: `< 100km` → `'<100km'`, `>= 100km` → `'>=100km'`, else `'unknown'`. **Exactly 100km falls in `>=100km`.** | `repo@20f6416:…#L117–L119,L534` | **verified** | — |
| **T-026** | `'unknown'` distance = no estimate in **either** `fact_order_fares` or `fact_quotations`. | `repo@20f6416:…#L533` | **verified** | Not a small residual class — it is a real bucket in every distance-cut result. Ratios computed within `unknown` are not comparable to the other two |

> ⚠️ **`10ft` and `10ft - NCR` / `10ft - non NCR` are not siblings — the first contains the other
> two.** Do not chart them on one axis, do not sum the column, and do not "normalise" the overall
> row away: `pack:§2`/`§3`/`§6` deliberately keep it and `§4` deliberately does not.

---

## §5 Units — unresolved for HCV

| id | column | stored as | convert | source_ref | confidence |
|---|---|---|---|---|---|
| **T-030** | `order_fares.fare` (`fare_type = 2`, `is_current`) | **rupees** | **none — do not divide** | `repo@20f6416:…#L104` · `metabase:card/32713` · `store:metric.porter.revenue` — all three compute `ceil(fare) + coupon_discount + referral_discount + subscription_discount` with **no `/100`** | **unverified** (`D-018`) — evidenced four ways, but the catalog documents no unit for this column (`description: null`) |

> **Why `unverified` and not `verified`.** The catalog documents **no unit** for this column
> (`description: null`). Four independent lines point to rupees: the **governed, approved**
> `metric.porter.revenue` uses the identical expression with no divisor; its measure `daily_revenue`
> repeats it; `ceil(fare)` is **semantically inert on an integer paise column** and only earns its
> place on a fractional rupee value; and pack, four cards and the store all apply `ceil()` while none
> applies `/100`. **One value read closes it** — a ~₹5,000 trip reads `5000.xx` if rupees,
> `500000` if paise. → `G-010`, **OPEN — low**
>
> ⚠️ **Paise is a *per-table* convention at Porter, not a platform-wide one.** `ra_public` and
> `partload_application` (PTL) fare columns are documented in paise; `pnm_application` fare columns
> are documented **"in INR"**. **Do not infer HCV's scaling from PTL's** — that inference was made
> once in this KB's drafting and was wrong (`D-018`).

---

## §6 The `mbr_mapping_v2` precondition

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| **T-070** | `pack:§0` **writes a physical table**: `CREATE OR REPLACE TABLE dev_eldoria.sandbox.mbr_mapping_v2`. | `repo@20f6416:…#L26` | **verified** | The only write in the pack. Everything else is `SELECT` |
| **T-071** | **Every pack section except `§5` depends on it** — `§1`, `§2`, `§2a`, `§3`, `§3a`, `§4`, `§6`. | Read from the SQL of each section, 2026-08-14 | **verified** | — |
| **T-072** | ⚠️ **The pack's own caveat is wrong.** It states *"sections 1–4 depend on `mbr_mapping_v2`"* and omits **`§6`**, which joins it twice. | `repo@20f6416:…#L532` vs `#L494,L505` | **verified** | A source contradicting itself, recorded not corrected (`CONTRIBUTING.md` §8.5) → `G-011` |
| **T-073** | It is a **sandbox table with no refresh contract**. Nothing schedules it; nothing records when it was last built. | `repo@20f6416:…#L26`; absence of any orchestration reference | **verified** | Any number derived from it is exactly as stale as the last manual run → `CONTEXT.md` hard rule 7 |
| **T-074** | Its distance columns come from `fact_order_fares` (`fare_type = 1`, `is_current`, FO leg) and `fact_quotations.google_distance_in_kms` (SO leg), coalesced FO-first. **Both already in km.** | `repo@20f6416:…#L44–L57,L69` | **verified** | — |

---

## §7 Tables

| id | table | role | key columns | confidence |
|---|---|---|---|---|
| T-050 | `prod_eldoria.mart.hcv_overall_demand_mart` | **Primary demand object.** Full outer join of Scheduled Orders and Fact Orders; grain = one demand unit per `so_id` **or** `oms_crn_number` | `unique_id`, `order_time`, `order_status`, `fo_driver_id`, `customer_id`, `vehicle_mapping`, `geo_region_id` | **verified** |
| T-050a | — | ⚠️ Because it is a **full outer join**, a row may be SO-only (never fulfilled), FO-only (direct booking, no SO), or both. `fo_driver_id` is null for SO-only rows **by construction**, not only when unallocated | Data Catalog description | **verified** |
| T-051 | `prod_curated.oms_public.orders` | OMS order master — the revenue base in `pack:§1` | `id`, `created_at` (UTC), `status`, `order_type`, `deleted_at`, `customer_mobile`, `vehicle_id`, `geo_region_id` | **verified** |
| T-052 | `prod_curated.oms_public.order_fares` | Fare components | `order_id`, `fare_type`, `is_current`, `fare`, `coupon_discount`, `referral_discount`, `subscription_discount` | **verified** |
| T-053 | `prod_eldoria.core.fact_order_fares` | Distance (FO leg) for `mbr_mapping_v2` | `order_id`, `travel_distance`, `fare_type`, `is_current` | **verified** |
| T-054 | `prod_eldoria.core.fact_quotations` | Distance (SO leg) | `uuid`, `google_distance_in_kms` | **verified** |
| T-055 | `prod_eldoria.core.fact_active_partners` | Partner login-hours — the only source in `pack:§5` | `day`, `driver_id`, `vehicle_id`, `geo_region_id`, `business_login_hours` | **verified** |
| T-056 | `prod_eldoria.core.dim_vehicles` | Vehicle classification | `vehicle_id`, `vehicle_mapping`, `level0_mapping` | **verified** |
| T-057 | `prod_eldoria.core.dim_geo_regions` | Geography and tier | `geo_region_id`, `tier` | **verified** |
| T-058 | `prod_eldoria.core.dim_cancel_reasons_attribution` | Cancellation attribution — drives E-FF% | `attribution` (`'customer'`) | **verified** |
| T-059 | `prod_eldoria.mart.cge_completed_spot_orders_fast_mv` | Revenue base used by card 32713 — **not** the pack's base | `order_id`, `order_date`, `vehicle_id`, `geo_region_id` | **verified** |
| T-060 | `prod_eldoria.mart.hcv_fo_matchmaking_mart` · `hcv_so_matchmaking_mart` | Matchmaking funnel, FO and SO legs. **Not used by the pack** | — | **verified** |
| T-061 | `mart_partner_daily_performance_summary` | Semantic model behind `store:metric.porter.map` | `driver_id`, `total_completed_orders` | **verified** |
| T-062 | ⚠️ `prod_curated.trucks.*` — `VEHICLE_SEGMENT_MAPPING_V2`, `GEO_REGIONS_ROI`, `order_batching_info`, `order_level_matchmaking_funnel` | **Legacy (redshift-era) schema still backing dashboard cards.** Card 32713 joins it for both vehicle and geo | — | **verified** |

> ⚠️ **Three different objects answer "how many HCV orders completed."** `hcv_overall_demand_mart`
> (`pack:§2`/`§3`/`§6`), `oms_public.orders` (`pack:§1`), and `cge_completed_spot_orders_fast_mv`
> (card 32713). They are not interchangeable and have never been reconciled → `G-012`.

---

## §8 Privacy — columns that carry personal data

Column *names* are schema facts and belong here. **Their values never do** ([CONTRIBUTING.md](./CONTRIBUTING.md) §9).

| id | column | why it is sensitive |
|---|---|---|
| T-080 | `customer_mobile` | Direct personal identifier. Appears in `T-020`'s exclusion literal and as a join key |
| T-081 | `from_address_lat` · `from_address_long` · `to_address_lat` · `to_address_long` | Precise origin/destination coordinates. Used in `pack:§3`/`§6` duplicate detection via `ST_DISTANCE` at 100m resolution |
| T-082 | `customer_id` · `driver_id` · `fo_driver_id` | Pseudonymous identifiers — safe as column names, never to be listed as values |
