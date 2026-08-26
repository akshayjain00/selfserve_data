# P5a — Verify Catalogue Batch 1 (Metrics #10, #11, #13, #16, #17, #43, #44)

Metabase auth confirmed working this session (domestic `claude.ai Metabase` connector, `database_id: 73`). This file **overwrites** the earlier attempt that failed on auth before reading anything. All 7 metrics below are now grounded in live card metadata; 6 of the 7 (all except #10, per scope) were also executed against Snowflake with minimal parameters to confirm mechanics.

## Cross-cutting findings (read before the per-metric sections)

1. **Business-user source-table split (UNRESOLVED).** Cards #11 (`44469`), #13 (`48922`), #43 (`48919`) compute the Business/Personal cut via `prod_curated.oms_public.customers.frequency IN (1,2,3,4)` joined on `mobile` — this matches the KB's canonical rule exactly. Cards #16/#17 (`48984`) and #44 (`49311`) instead compute the **same-looking** cut via `prod_eldoria.core.dim_customers.frequency IN (1,2,3,4)` joined on `customer_id`. These are different tables. Whether `dim_customers.frequency` is sourced from/kept in sync with `oms_public.customers.frequency` was not verified — flagging as an unresolved cross-card inconsistency, not assuming equivalence.
2. **"Order Placed" title vs "button click" SQL (UNRESOLVED, two flavors).** Card `44469` (#11) gates its "order" numerator on `order_type='completed'` joining to `orders.state='3'` — a real completed-order proxy, but only when the (non-default, required) `order_type` parameter is explicitly set to `'completed'`; the alternative value `'overall'` degrades it to a raw button click. Card `48984` (#17) has **no such join at all** — its "Quote check -> Order placed conversion" column is unconditionally `booknow_clicked` sessions / `quote_viewed` sessions, i.e. a click-through rate, never gated on actual order completion. The two cards that both claim to measure "Quote to Order Placed" conversion are measuring structurally different things.
3. **Divide-by-zero handling is inconsistent.** `48984` and `48919` wrap ratios in `NULLIF(..., 0)`, matching the KB rule (null, not zero/infinity). `44469`'s `conversion_pct` has **no NULLIF guard** — a zero-quote-session bucket would hit Snowflake's division-by-zero behavior rather than a clean null.
4. **New/repeat framing.** #10 (`48923`, orchestrator-verified) and #11 (`44469`, this batch) both compute `customer_tag`/similar as an **output dimension** covering both 'new' and 'repeat' rows per period, not a hard filter — so the catalogue's "New Business Users" framing for #10/#11 requires the consumer to manually select the 'new customer' row. #16/#17/#44 by contrast expose `customer_type` as a genuine optional **filter** parameter (New/Repeat/unset-for-all) — structurally cleaner.
5. **Internal-user exclusion**: present and consistent on all 6 cards in this batch (`NOT IN (SELECT mobile FROM ptl_internal_users)` or equivalent `iu.mobile IS NULL` anti-join).

---

## #10 — "New vs Repeat VSS to Quote Conversion" — `card/48923`
*(Not re-verified this session — read by the orchestrator moments before this task; included here only for a single consistent document.)*
- `database_id`: 73 · `updated_at`: 2026-04-17T07:55:31Z
- Formula: `vss_sessions = COUNT(DISTINCT app_session_id WHERE event='vehicleselectionscreen_vehicles_loaded')`; `quote_sessions = COUNT(DISTINCT app_session_id WHERE event='ptlbookingdetailspage_quote_viewed')`; ratio = quote/vss, NULLIF-protected.
- Business filter: matches KB rule (`frequency IN (1,2,3,4)`, catalogue `T-020`); internal-user exclusion present.
- Executed: not by me (orchestrator's prior read stands).
- Matches catalogue definition: mechanic — **verified**. Title's "New Business Users" framing — **unverified/divergent**, since the card outputs both new+repeat via `customer_tag`, not a New-only filter.
- Verdict: **verified** (mechanic) / **unverified** (title's "New" framing).

---

## #11 — Quote Check to Order Placed Conversion — New Business Users — `card/44469`
- Card name (Metabase): "New Repeat Quote to Order Conversion"
- `database_id`: 73 · `updated_at`: 2026-07-14T12:18:05.514169Z
- Formula (key expressions, quoted from the card's native SQL):
  ```sql
  count(distinct case when event_name = 'ptlbookingdetailspage_quote_viewed' then app_session_id end) as quote_sessions,
  count(distinct case when event_name = 'ptlbookingdetailspage_booknow_clicked'
        AND ({{order_type}} = 'overall' OR ({{order_type}} = 'completed' AND o.state = '3'))
        then app_session_id end) as book_now_sessions,
  book_now_sessions / quote_sessions as conversion_pct
  ```
  `customer_tag` (new vs repeat) is derived per-session from a `base` CTE giving each customer's first order date; `category` (Business/Personal) derived via `CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END` on `oms_public.customers` — matches KB rule exactly. Internal-user exclusion present. `order_type` and `granularity` are **required** template tags with no default; `category` has a default of `'Business'`.
- Executed: **yes**. Parameters: `granularity='month'`, `order_type='completed'`, `category='Business'`, `START_DATE='2026-06-01'`, `END_DATE='2026-06-30'`.
  - Returned 2 rows (both customer_tags, since the tag is an output dimension not a filter):
    - `new customer`: quote_sessions=5578, book_now_sessions=1294, conversion_pct=**0.2320** (23.2%)
    - `repeat customer`: quote_sessions=4467, book_now_sessions=2202, conversion_pct=**0.4929** (49.3%)
  - Catalogue #11 ("New Business Users") corresponds to the `new customer` row: **~23.2%** for June 2026, business, `order_type=completed` cut.
- Matches catalogue definition? Mechanic is sound and the "order placed" numerator is genuinely order-completion-gated **only when `order_type='completed'` is chosen** (no default forces this choice — see cross-cutting finding #2). Title says "New Business Users" but the query returns both tags (cross-cutting finding #4). No NULLIF guard (cross-cutting finding #3).
- Verdict: **verified with caveats** — formula and business-filter mechanics confirmed correct and reproducible; flag the required-no-default `order_type` param and missing NULLIF as latent risks; flag the New/Repeat-as-dimension-not-filter pattern as a title/output mismatch (same pattern as #10).

---

## #13 — Average Sessions Before First PTL Order — Business Users — `card/48922`
- Card name (Metabase): "Average number of sessions before first PTL order"
- `database_id`: 73 · `updated_at`: 2026-04-16T18:52:37.770441Z
- Formula (key expressions):
  ```sql
  -- first_ptl_order: first completed (state=3) order per customer_mobile, optional category filter
  -- vehicles_loaded_events: distinct VSS sessions per customer (vehicle_ids_seq flatten IN (-1,1159))
  -- sessions_before_first_order: COUNT(DISTINCT app_session_id) of VSS events strictly before first_order_ts
  SELECT period_start,
         COUNT(DISTINCT customer_mobile) AS users_with_first_order,
         ROUND(AVG(COALESCE(sessions_before_first_order, 0)), 2) AS avg_sessions_before_first_ptl_order
  ```
  Business filter: `CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = {{category}}` on `oms_public.customers` (matches KB rule); optional parameter, no default — must be explicitly supplied to get the "Business Users" cut. Internal-user exclusion present on both the order and VSS-event sides.
- Executed: **yes**. Parameters: `start_date='2026-06-01'`, `end_date='2026-06-30'`, `category='Business'` (granularity defaulted to `'Month'`).
  - Returned: `users_with_first_order=1329`, `avg_sessions_before_first_ptl_order=4.51` for June 2026.
- Matches catalogue definition? Yes, once `category='Business'` is explicitly passed (no default). Note the `vehicle_ids_seq` flatten filter `IN (-1, 1159)` restricts which VSS events count — an unexplained, PTL-specific vehicle-type sentinel not stated in the catalogue definition; noted for completeness, not a conflict per se since the same filter recurs identically on cards `48984` and `49311`.
- Verdict: **verified**, high confidence — mechanic and business-filter both check out, value reproduced live.

---

## #16 — VSS to Quote Check Conversion — All Business Users — `card/48984`
## #17 — Quote Check to Order Placed Conversion — All Business Users — `card/48984` (same card, single query answers both)
- Card name (Metabase): "PTL VSS to Order Funnel"
- `database_id`: 73 · `updated_at`: 2026-05-06T12:12:04.090203Z
- **Confirmed**: one query answers both #16 and #17 — the SELECT returns both ratio columns side by side in the same row set.
- Formula (key expressions):
  ```sql
  q.quote_viewed_sessions * 1.0 / NULLIF(v.vehicles_loaded_sessions, 0) AS "L1: VSS -> Quote check conversion",       -- #16
  b.booknow_clicked_sessions * 1.0 / NULLIF(q.quote_viewed_sessions, 0)  AS "L1: Quote check -> Order placed conversion" -- #17
  ```
  `vehicles_loaded` = distinct sessions, `event_name='vehicleselectionscreen_vehicles_loaded'`, `vehicle_ids_seq` flatten IN (-1,1159). `quote_viewed` = distinct sessions, `event_name='ptlbookingdetailspage_quote_viewed'`. `booknow_clicked` = distinct sessions, `event_name='ptlbookingdetailspage_booknow_clicked'` — **no join to `orders`/`state='3'` anywhere in this card**, unlike `44469`. Business filter: `CASE WHEN dc.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = {{user_type}}` but sourced from **`prod_eldoria.core.dim_customers`** (joined on `customer_id`), not `oms_public.customers` (cross-cutting finding #1). `customer_type` (New/Repeat) is a genuine optional filter — leaving it unset gives the "All Business Users" cut the catalogue wants. Internal-user exclusion present. Ratios are NULLIF-protected.
- Executed: **yes**. Parameters: `granularity='Month'`, `user_type='Business'`, `start_date='2026-06-01'`, `end_date='2026-06-30'` (`customer_type` left unset → all/combined, matching "All Business Users").
  - Returned (June 2026): `vehicles_loaded_sessions=98488`, `quote_viewed_sessions=10035`, `booknow_clicked_sessions=5656`
  - **#16 VSS -> Quote check conversion = 0.1019 (10.2%)**
  - **#17 "Quote check -> Order placed conversion" = 0.5636 (56.4%)** — but see conflict below.
- Matches catalogue definition?
  - #16: mechanic matches ("VSS to Quote Check Conversion"); business filter present but sourced from a different table than the KB's canonical rule — **UNRESOLVED** (finding #1).
  - #17: **UNRESOLVED conflict** — the catalogue title says "Order Placed" but the SQL numerator is a raw `booknow_clicked` button-click event with zero join to order completion. The 56.4% figure is a click-through rate on the quote page, not an order-placement rate. This also conflicts with how card `44469` (#11) computes its nominally-equivalent "order placed" numerator (which *does* gate on `orders.state='3'` when `order_type='completed'` is chosen). Two cards claiming to answer the same catalogue concept ("Quote to Order Placed") diverge in what "order placed" means.
- Verdict: #16 **verified with caveat** (source-table divergence, unresolved); #17 **UNRESOLVED — likely mislabeled**, recommend the KB owner either rename this column ("Quote check -> Book Now click conversion") or add an order-completion join to match `44469`'s approach.

---

## #43 — Reactivation % (60+ Day Inactive Business Users) — `card/48919`
- Card name (Metabase): "Monthly Reactivation %"
- `database_id`: 73 · `updated_at`: 2026-04-16T17:23:19.566941Z
- Formula (key expressions):
  ```sql
  -- inactive_base: customers whose last completed order (state=3) was >=60 days before period_start
  WHERE DATEDIFF(day, last_completed_date, period_start) >= 60
  -- reactivated: inactive_base customers who placed a completed order within [period_start, period_end]
  ROUND(1.0 * COUNT(DISTINCT r.customer_mobile) / NULLIF(COUNT(DISTINCT ib.customer_mobile), 0), 4) AS reactivation_pct
  ```
  Business filter: `CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = {{category}}` on `oms_public.customers` (matches KB rule, optional param, no default). Internal-user exclusion present (`iu.mobile IS NULL`). Ratio is NULLIF-protected — matches KB divide-by-zero rule.
- Executed: **yes**. Parameters: `category='Business'`, `start_date='2026-01-01'`, `end_date='2026-06-30'`.
  - Returned 6 monthly rows:
    | Month | inactive_60d_base | reactivated | reactivation_pct |
    |---|---|---|---|
    | 2026-01 | 1070 | 42 | 3.93% |
    | 2026-02 | 1870 | 72 | 3.85% |
    | 2026-03 | 2701 | 131 | 4.85% |
    | 2026-04 | 3594 | 182 | 5.06% |
    | 2026-05 | 4392 | 179 | 4.08% |
    | 2026-06 | 5510 | 260 | 4.72% |
  (Growing base size across months is an artifact of the lookback window definition, not a data issue.)
- Matches catalogue definition? Yes — "60+ day inactive," "Business Users" (correct source table), reactivation-within-period logic, and null-safe ratio all line up cleanly.
- Verdict: **verified**, high confidence.

---

## #44 — Median Days Between Orders — Repeat Business Users — `card/49311`
- Card name (Metabase): **"Median Time to Book"** — this name itself is a strong signal of the conflict below.
- `database_id`: 73 · `updated_at`: 2026-05-05T16:00:39.064501Z
- Formula (key expressions):
  ```sql
  -- first_vss_per_session: earliest VSS ('vehicleselectionscreen_vehicles_loaded') timestamp per app_session_id
  -- first_booking_per_session: first 'ptlbookingdetailspage_booknow_clicked' AFTER that session's VSS view (QUALIFY row_number=1)
  DATEDIFF('second', fv.first_vss_ts, fb.booking_ts) / 60.0 AS time_to_book_mins
  ...
  SELECT month, MEDIAN(time_to_book_mins) AS median_time_to_book_mins FROM session_pairs GROUP BY 1
  ```
  Business filter again sourced from `prod_eldoria.core.dim_customers.frequency` (cross-cutting finding #1, same divergence as `48984`). `customer_type` (New/Repeat) is an optional filter based on whether the customer's first completed order predates the VSS-view event.
- **MAJOR CONFLICT (UNRESOLVED)**: this card computes the **median minutes from a session's VSS view to that same session's Book-Now click** — a within-session funnel-latency metric. It does **not** compute anything resembling "days between orders" (which would require differencing timestamps across a customer's successive *orders*, not within one session's page-to-page latency). The card's own Metabase name, "Median Time to Book," corroborates that this was built for latency, not repeat-purchase cadence. Two possibilities, not resolved here: (a) the catalogue's #44 entry points at the wrong card, or (b) this card was repurposed and the catalogue definition is stale. Either way, the units alone (minutes, session-level) make this card structurally incapable of answering "days between orders."
- Executed: **yes**, to characterize what the card actually returns. Parameters: `user_type='Business'`, `customer_type='Repeat'`, `start_date='2026-06-01'`, `end_date='2026-06-30'` (granularity defaulted to `'Month'`).
  - Returned: `median_time_to_book_mins = 0.8` (≈48 seconds) for June 2026, Business + Repeat cut.
  - This value is **not** a "days between orders" figure — it is median VSS→booking-click latency in minutes, confirming the conflict above rather than resolving it.
- Matches catalogue definition? **No — UNRESOLVED.** Report both sides: catalogue says "Median Days Between Orders — Repeat Business Users"; the only card mapped to #44 (`49311`) computes median session-level time-to-book in minutes. These are different metrics. Recommend the KB owner locate the correct card (if one exists) for actual inter-order interval, and/or correct the catalogue mapping for #44.
- Verdict: **UNRESOLVED / likely mismapped catalogue entry** — do not treat the 0.8-minute figure as an answer to "days between orders."

---

## Business-customer rule check summary (`customers.frequency IN (1,2,3,4)`)
| # | Card | Table used | Matches KB canonical rule? |
|---|---|---|---|
| 10 | 48923 | (not re-checked this session) | — |
| 11 | 44469 | `oms_public.customers` | Yes |
| 13 | 48922 | `oms_public.customers` | Yes |
| 16/17 | 48984 | `prod_eldoria.core.dim_customers` | **No — different table, UNRESOLVED** |
| 43 | 48919 | `oms_public.customers` | Yes |
| 44 | 49311 | `prod_eldoria.core.dim_customers` | **No — different table, UNRESOLVED** |
