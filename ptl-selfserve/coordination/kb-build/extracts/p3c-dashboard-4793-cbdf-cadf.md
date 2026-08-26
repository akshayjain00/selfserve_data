# P3c Extract — Dashboard 4793 CBDF/CADF SQL (Metadata-only)

Worker: P3c. Method: `get_dashboard`/`get_card` metadata reads only. No `execute_card`/`execute_query` calls made. No data values, names, emails reproduced (creator emails below are the only PII-adjacent field retained, per instructions column-names-only rule this is a borderline case — recorded as `[creator email]` placeholder in the summary; raw emails omitted from this report).

## Dashboard metadata

- **Dashboard 4793**: "PTL Cancellations", collection "Cancellations" (id 5756)
- `updated_at`: 2026-06-02T05:52:10.268361Z
- `created_at` (dashboard shell, from parameters): first tab structure dates to 2025-11-04/05
- Tabs: **Overview** (id 4275, position 0), **Funnel** (id 4276, position 1), **CBDF & CADF** (id 4360, position 2, created 2025-11-18)
- Dashboard-level filters relevant to CBDF/CADF: `Start Date` (default 2025-05-01), `Cancel Type` (CADF/CBDF, default CBDF), `Exclude under 60 sec cancellations?` (values YES/NO, **no default value set** at dashboard level), `Granularity` (Month/Week/Day), `Pickup City`, `Route Name`, `Drop City`

## Per-card extract

### Card 42683 — "Funnel View- Cancellations" (Funnel tab, id 4276)
- `updated_at`: 2025-11-18T10:09:14.091206Z / `created_at`: 2025-11-04T18:15:20.886553Z
- Creator: [creator email redacted]
- Computes CBDF/CADF as two rows in an unpivoted funnel table (`E. CBDF`, `F. CADF`), plus separate diagnostic rows `D. 60_SECOND_CANCELLATIONS%` and `D1. EXCLUDING_60_SECOND_CANCELLATIONS%`.
- **CBDF/CADF formula in this card does NOT apply the 60-second exclusion at all** — see verbatim SQL below.
- No `is_test`/business-user filter parameter present on this card.

### Card 43237 — "Funnel View- Cancellations - CADF/CBDF" (CBDF & CADF tab, id 4360)
- `updated_at`: 2025-11-27T09:19:28.826099Z / `created_at`: 2025-11-18T10:50:28.514455Z
- Creator: [creator email redacted]
- Headline CBDF%/CADF% card for the dedicated tab. Also breaks each into `_in_slot`/`_before_slot`/`_after_slot` sub-metrics.
- Applies the `{{exclude_60_sec}}` parameter to the CBDF/CADF numerator (see below).
- No `is_test` parameter.

### Card 43242 — "Cancellations - CADF/CBDF (Time distribution)" (CBDF & CADF tab)
- `updated_at`: 2025-11-27T09:19:54.23343Z / `created_at`: 2025-11-18T12:32:02.142582Z
- Creator: [creator email redacted]
- Same base logic as 43237, pivoted into `cancel_time_bucket` (0-1hr/1-2hr/.../>3hr before or after slot, plus in_slot), filtered to a single `{{cancel_type}}` (CADF or CBDF) selected via dashboard filter.
- Applies `{{exclude_60_sec}}` identically to 43237.
- Uses an unwrapped WHERE clause for the date filter (`o.created_at >= {{start_date}}::DATE - INTERVAL '5 hours, 30 mins'`) — unlike 43237/47673 which wrap the column on the left side (`o.created_at + INTERVAL '330 mins' >= {{start_date}}::DATE`). Not a business-logic issue, just an internal inconsistency in pruning-friendliness across sibling cards.

### Card 47673 — "Slot wise Cancellation Time" (CBDF & CADF tab)
- `updated_at`: 2026-03-23T06:28:52.89589Z / `created_at`: 2026-03-23T06:24:33.676562Z
- Creator: [creator email redacted]
- Both CBDF and CADF computed side-by-side (`cbdf_orders`/`cbdf_pct`, `cadf_orders`/`cadf_pct`) per month × slot_bucket (before/in/after) × cancel_time_bucket (<1min, 1-5min, 6-20min, 20-30min, 30-60min, 60+min).
- Applies `{{exclude_60_sec}}` identically to 43237/43242.
- `HAVING slot_bucket IS NOT NULL` — rows where slot bucket couldn't be computed (e.g. no matching slot_intervals row) are dropped from this particular view only.

### Card 47674 — "Cancellation distribution based Time" (CBDF & CADF tab)
- `updated_at`: 2026-03-23T06:25:51.3963Z / `created_at`: 2026-03-23T06:25:51.3963Z
- Creator: [creator email redacted]
- Same base/CBDF/CADF logic as 47673, minus the slot_bucket split (cancel_time_bucket only). Same `{{exclude_60_sec}}` treatment.

### Card 49366 — "Category wise Cancellation" (reconciliation counterpart named by the D5 ruling)
- **Not on dashboard 4793** — lives in collection "Cancellation Analysis" (id 5695), not "Cancellations" (id 5756).
- `updated_at`: 2026-05-14T10:39:36.215228Z / `created_at`: 2026-05-04T18:32:03.904903Z
- Creator: [creator email redacted]
- Computes CBDF/CADF **as a share of each cancellation-reason category's own cancellation count** (`customer_cbdf_pct = customer_cbdf / customer_cancel`, etc. for Customer/Porter/Partner categories derived from a large `reason ILIKE` mapping), NOT as a share of total placed orders.
- No `exclude_60_sec` logic anywhere in this card.
- Joins `order_cancellation_reasons` to `orders` via `ocr.order_external_id = o.external_id` — **not** `cr.order_id = o.id` as all five 4793 cards do.

## CBDF definition (verbatim SQL)

From card 43237 (representative of the parameterized family 43237/43242/47673/47674 — identical predicate structure in all four):

```sql
100 * COUNT(DISTINCT CASE
    WHEN vehicle_name IS NULL
         AND state = 4
         AND (within_1_cancel IS NULL OR {{exclude_60_sec}} = 'NO')
    THEN order_id END
) / placed_orders AS CBDF,
```

Where `vehicle_name` comes from:
```sql
LEFT JOIN prod_curated.partload_application.order_vehicles ov
    ON o.id = ov.order_id AND ov.is_active
...
ov.vehicle_name
```
and `within_1_cancel`:
```sql
CASE WHEN DATEDIFF(
        SECOND,
        o.created_at + INTERVAL '5 hours, 30 mins',
        cr.created_at + INTERVAL '330 mins'
    ) <= 60 THEN o.id END AS within_1_cancel
```
and `placed_orders`:
```sql
COUNT(DISTINCT order_id) AS placed_orders   -- from base CTE, unconditional on state/cancellation
```

From card 42683 (Funnel tab, no exclusion applied):
```sql
100*Count(Distinct case when vehicle_name is null and state = 4  then order_id end)/placed_orders as CBDF,
```

## CADF definition (verbatim SQL)

Card 43237 (same family as above):
```sql
100 * COUNT(DISTINCT CASE
    WHEN vehicle_name IS NOT NULL
         AND state = 4
         AND (within_1_cancel IS NULL OR {{exclude_60_sec}} = 'NO')
    THEN order_id END
) / placed_orders AS CADF,
```

Card 42683 (no exclusion applied):
```sql
100*Count(Distinct case when vehicle_name is not null and  state = 4  then order_id end)/placed_orders as CADF
```

Card 43242's simplified single-label classifier (used before pivoting into time buckets):
```sql
CASE
    WHEN vehicle_name IS NULL AND state = 4 THEN 'CBDF'
    WHEN vehicle_name IS NOT NULL AND state = 4 THEN 'CADF'
    ELSE 'Non-cancelled'
END AS cancel_type
```

## `<60s` treatment — precise

Applies only to cards 43237, 43242, 47673, 47674 (the "CBDF & CADF" tab). Card 42683 (Funnel tab) has no `<60s` handling in its CBDF/CADF numbers at all — those cancellations are always counted as CBDF or CADF there.

Mechanism, from the shared predicate `(within_1_cancel IS NULL OR {{exclude_60_sec}} = 'NO')`:

- `within_1_cancel` is `order_id` when `DATEDIFF(SECOND, order_ts, cancellation_ts) <= 60`, else `NULL`.
- If `{{exclude_60_sec}}` = `'YES'`: predicate reduces to `within_1_cancel IS NULL` → orders cancelled within 60 seconds are **excluded from the CBDF/CADF numerator only**. They are **not** removed from `placed_orders` (the denominator, which is an unconditional `COUNT(DISTINCT order_id)` over the whole `base` CTE with no cancellation-timing filter). They are also **not reclassified** into a third bucket — they simply stop counting as CBDF, CADF, or "cancelled" in this metric's own aggregate rows.
- If `{{exclude_60_sec}}` = `'NO'`: predicate is always `TRUE` (second disjunct) → all cancellations, including <60s ones, are counted normally. No exclusion.
- **Open question, unresolvable from metadata**: the dashboard-level parameter "Exclude under 60 sec cancellations?" has **no default value** set (absent `default` key in the dashboard's `parameters` array), while the template tag is referenced as a bare `{{exclude_60_sec}}` (not wrapped in `[[ ]]` optional syntax) inside a string-equality expression. What value (if any) is substituted when a viewer has not touched this filter is not determinable from SQL/metadata text alone — flagged as `[unverified]`, not resolved by running the query (per hard rule).

**Verdict on the three options in the task**: (a) dropped from denominator — NO. (b) reclassified — NO. (c) excluded from numerator only — YES, this is what happens, when the exclusion is switched on.

## 4793-vs-49366 comparison

Same building block, different question and different plumbing — this is the reconciliation gap the D5 ruling anticipated:

1. **Cancellation join key differs**: 4793's cards join `cr.order_id = o.id` (direct FK). 49366 joins `ocr.order_external_id = o.external_id`. Different join path — could produce different match/row counts if the external_id mapping has gaps, duplicates, or different coverage than the direct order_id FK.
2. **Denominator differs entirely**: 4793's CBDF%/CADF% = (CBDF or CADF order count) ÷ `placed_orders` (all orders placed in the period — i.e., % of demand). 49366's `customer_cbdf_pct`/`porter_cbdf_pct`/`partner_cbdf_pct` = (category CBDF count) ÷ (that category's own total cancellation count) — i.e., % of a reason-category's cancellations, not % of demand. **These two are not the same ratio and cannot be compared number-for-number.**
3. **`<60s` exclusion**: present (optional, numerator-only) in 4793's CBDF&CADF-tab cards; **entirely absent** in 49366 — no `within_1_cancel`, no `exclude_60_sec` tag.
4. **Extra dimension**: 49366 additionally slices by attributed cancellation category (Customer/Porter/Partner) via a large `reason ILIKE` string-matching CASE tree; 4793's cards instead slice by slot-timing (before/in/after slot, minute buckets). Neither card reproduces the other's cut.
5. **What does match**: the core "driver found" primitive is identical in both — `LEFT JOIN order_vehicles ov ON o.id = ov.order_id AND ov.is_active [= TRUE]`, then `vehicle_name IS NULL` → CBDF / `vehicle_name IS NOT NULL` → CADF, gated on `state = 4`. Internal-user exclusion is also present in both (4793: `NOT IN (SELECT mobile FROM ptl_internal_users)`; 49366: `LEFT JOIN ptl_internal_users ... WHERE mobile IS NULL` — functionally equivalent anti-join, different SQL idiom).

**UNRESOLVED**: 4793 and 49366 answer structurally different questions using the same classification primitive. They cannot be reconciled into a single number without picking one denominator/join-key convention over the other — that decision is not made anywhere in the SQL text of either card.

## 4793-vs-prototype comparison (`state=4 AND vehicle_assigned=0/1`)

- **Core predicate**: conceptually the same — both use `state = 4` as "cancelled," and both split on vehicle-assignment presence/absence. 4793 does **not** have a column literally named `vehicle_assigned`; it derives the equivalent boolean by `LEFT JOIN order_vehicles ov ON o.id = ov.order_id AND ov.is_active` and testing `vehicle_name IS NULL/NOT NULL`. Same signal, different mechanism (join-derived null-check vs a presumed precomputed flag column) — this worker did not have access to the prototype's SQL text, only the background description, so the comparison of the join mechanism itself is inferential, not a side-by-side SQL diff.
- **`<60s` exclusion**: the background states the prototype applies **no** `<60s` exclusion. Within 4793:
  - Card 42683 (Funnel tab) **matches** the prototype exactly on this point — no `<60s` handling in its CBDF/CADF numbers either.
  - Cards 43237/43242/47673/47674 (CBDF & CADF tab) **differ** from the prototype — they parameterize an optional numerator-only `<60s` exclusion. When that parameter is effectively "NO" (or unset — see open question above), their output would match the prototype/42683; when "YES", their CBDF/CADF numbers would be lower than the prototype's for the same period.
- Net: 4793 is not internally uniform on this point, so "does 4793 match the prototype" has no single answer — one of 4793's own cards (42683) matches, four others (43237/43242/47673/47674) only match conditionally on a parameter whose default is not determinable from metadata.

## Tables / columns referenced

- `partload_application.orders` (aliased `o`) — `id`, `state`, `created_at`, `customer_mobile`, `pickup_slot_start`, `pickup_slot_end`, `route_id`, `estimated_delivery_ts`, `external_id` (49366 only)
- `partload_application.order_cancellation_reasons` (aliased `cr`/`ocr`) — `order_id` (4793) / `order_external_id` (49366), `created_at`, `reason`, `cancellation_source`
- `partload_application.slots` — `route_id`, `start_time`, `end_time`, `edd_buffer_in_days`, `created_at`
- `prod_curated.partload_analytics.ptl_routes` — `route_id`, `route_name`, `pickup_city`, `is_active` (49366 only)
- `prod_curated.partload_application.load_details` — `order_id`, `entry_type`, `is_active`, `chargeable_weight`
- `prod_curated.partload_application.order_vehicles` (aliased `ov`) — `order_id`, `is_active`, `vehicle_name`, `vehicle_type` — **this is the driver-found join**
- `partload_analytics.ptl_internal_users` — `mobile` — internal-user exclusion

## Conflicts (count: 3, all UNRESOLVED — not adjudicated per hard rules)

1. **4793 internal inconsistency (Funnel tab vs CBDF&CADF tab)**: card 42683 computes CBDF/CADF with no `<60s` exclusion; cards 43237/43242/47673/47674 apply an optional numerator-only `<60s` exclusion. Same dashboard, two different formulas for the same-named metric.
2. **4793 vs 49366**: different denominator (% of placed orders vs % of within-category cancellations), different join key (`order_id` vs `order_external_id`), `<60s` exclusion present vs absent. This is the gap the D5 ruling flagged as pending reconciliation.
3. **Business-user/test-order filter gap**: several *other* Overview-tab cards on 4793 (e.g. 33539 "Cancellation %", 33465, 33464, 41075, 34506, 49302 — not opened, inferred from their `is_test` parameter binding in the dashboard payload) carry an `is_test` filter; none of the five CBDF/CADF cards (42683, 43237, 43242, 47673, 47674) have an `is_test` parameter at all. So test/internal-business orders are excluded from CBDF/CADF only via the mobile-number-based internal-user list, not via any `is_test` flag — inconsistent with the rest of the same dashboard's cancellation cards.

Additionally flagged (not a conflict between sources, but an unresolved metadata gap): the `exclude_60_sec` dashboard filter has no default value, and is referenced as a bare (non-optional-bracketed) template tag — its effective value on a fresh dashboard load is not determinable from SQL/metadata text.

## Cards not opened (count: 11) and why

Overview-tab (id 4275) cards not opened: 33539 "Cancellation %", 40398 "P/B cancellation %", 33465 "Cancellation distribution source wise", 41075 "Route wise cancellation", 33464 "Cancellation distribution reason wise", 35253 "Cancellation (Time Bucket)", 34506 "Cancellation % - Number", 35255 "Customer Re-order Overview", 35252 "Cancellation (Median/P90)", 43253 "Slot time based cancellations - Overall - Modified", 49302 "Cancellations % - SDD vs NDD".

Reason: none of these card names reference CBDF/CADF or a driver-found split, and (per the dashboard payload's `parameter_bindings`) most carry an `is_test` binding that the CBDF/CADF-family cards (42683/43237/43242/47673/47674) do not — consistent with them being flat `state = 4` cancellation-rate cards analogous to dashboard 4198's pattern described in the background, not CBDF/CADF cards. This is an inference from card names and parameter bindings, not a verified SQL read — flagged as such rather than opened, per the task's scope (CBDF/CADF specifically) and to conserve budget.
