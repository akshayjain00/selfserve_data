# P3b Extract — Metabase Dashboard 4569 "Customer Dashboard"

Worker: P3b. Access: **ok** (no auth errors). Metadata reads only — no `execute_card`/`execute_query` calls made, per hard rule.
Privacy: creator blocks omitted throughout; no data values reproduced.

---

## Dashboard metadata

- **id**: 4569, **name**: "Customer Dashboard", **collection**: "Part Truck Load" (id 5134)
- **created_at**: 2025-08-28T18:03:10.47Z, **updated_at (dashboard)**: 2026-07-14T12:18:36.32Z
- **view_count**: 1322, **archived**: false
- **Tabs (7)**:
  1. Overall (id 3882)
  2. New/Repeat (id 3883)
  3. Business/Personal (id 3885)
  4. Retention (id 4007)
  5. Poor Customer Retention (id 4445)
  6. Conversion (id 4510)
  7. First-time user Metrics (id 4524)
- **Card count**: **50 real cards** (plus text/spacer dashcards with `card_id: null`, not counted). This is far above the "~14 cards" assumption in the brief — prioritization was applied (see "Cards not opened").
- **Dashboard-level parameters** (shared across cards via `parameter_bindings`):
  - `start_date` (date/single, default 2025-10-01), `end_date` (date/single, default 2026-01-31)
  - `frequency_` / `frequency` (string, default `["Month"]`, options Day/Week/Month)
  - `customer_category` (string/=, options `Business` / `Personal`) — **not wired to every card that segments by business** (see findings)
  - `pickup_city`, `drop_city`, `route_name` (string/=, optional)
  - Conversion-tab-only: `order_type`/`Customer First Order (Overall or Completed)` (completed/overall), `granularity`
  - Retention-ref params (`start_date_ref`, `end_date_ref`, `start_date_target`, `end_date_target`) — declared at dashboard level but not observed bound to any opened card

---

## Per-card extracts (22 of 50 opened)

### Card 38287 — "Customer Distribution"
- `updated_at`: 2026-07-14T10:08:52.59Z · `database_id`: 73 · `query_type`: native · tab: Overall
- **Computes**: Per period (`{{frequency}}`), COUNT(DISTINCT customer_mobile) = Active_customers, split into `new` / `retained` / `reactivated` via a lifetime-first-order (`first_ptl_order_date`, all-time MIN over completed orders, NOT windowed) + `LAG(period)` gap analysis. Percentages = each bucket / Active_customers.
- **Source tables**: `partload_application.orders` (state='3') UNION `prod_curated.gsheet_sync.ptl_offline_orders` (state=3); business flag joined from `prod_curated.oms_public.customers` (LEFT JOIN on mobile); internal-user exclusion via `partload_analytics.ptl_internal_users`.
- **Business filter**: optional — `CASE WHEN frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = {{Customer_category}}` — **note: `frequency` here is unprefixed**, not `c.frequency`; resolves correctly only because `orders` has no `frequency` column of its own (see finding below).
- **Time basis**: `created_at + INTERVAL '330 MINS'` (UTC→IST) for grain; WHERE clause uses `CONVERT_TIMEZONE('UTC','Asia/Kolkata', o.created_at)::date`.
- **Grain**: customer_mobile x period (Day/Week/Month).
- Core expression: `WHEN DATE_TRUNC({{frequency}}, first_ptl_order_date) = period THEN 'new' WHEN prev_period IS NOT NULL AND DATEADD({{frequency}},1,prev_period)=period THEN 'retained' WHEN ... < period THEN 'reactivated'`

### Card 38285 — "Route wise Customer Distribution"
- `updated_at`: 2025-10-07T11:16:05.37Z · tab: Overall
- **Computes**: route-level share of customers per period = `route_total_customers / overall_total_customers` (aggregate-then-ratio, correct pattern).
- **Business filter**: optional `category = {{category}}` where `category = CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END` (here properly prefixed `c.frequency`).
- **Source**: same orders/offline-orders union, joined to `prod_curated.partload_analytics.ptl_routes` for route_name.
- Core expression: `(r.total_cust / o.overall_cust) AS cust_pct`

### Card 38283 — "Revenue per Customer"
- `updated_at`: 2025-10-07T11:23:33.91Z · tab: Overall · display: smartscalar
- **Computes**: `Avg_Revenue_per_Customer = SUM(final_fare) / COUNT(DISTINCT customer_mobile)`; also emits `aov = SUM(final_fare)/COUNT(DISTINCT external_id WHERE state=3)` in same query.
- **final_fare**: `COALESCE(wd_fare.total_fare, o.estimated_fare/100.0)` — wd_fare = customer-notified fare-revision amount from `order_fares`/`fare_revision_notified` if present, else `estimated_fare/100`.
- **No business/personal split** in this card (category computed but not used in final SELECT — dead column).
- Filters: state=3, internal-user exclusion, date window on `created_at::date` (offset by 330 mins for start/end).

### Card 38619 — "Orders per Customer"
- `updated_at`: 2025-10-07T11:20:56.36Z · tab: Overall · display: smartscalar
- **Computes**: `order_per_customer = COUNT(DISTINCT external_id) / COUNT(DISTINCT customer_mobile)` per period.
- **Business filter**: optional `category = {{category}}`, `category = CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END` (properly prefixed).
- Filters: state='3', internal-user exclusion.

### Card 38900 — "PTL LTO customer cohorts"
- `updated_at`: 2025-09-16T11:32:57.34Z · tab: Overall
- **Computes**: customers bucketed by count of completed orders **within the selected period** (`mth = DATE_TRUNC(frequency, created_at)`), NOT lifetime: buckets `1 order / 2-3 / 4-5 / 6-10 / >10`; `pct_of_customers` = customers-in-bucket / total-customers-that-period (window function).
- **TITLE-VS-SQL MISMATCH**: card name says "LTO" (implying lifetime) but the order-count buckets are computed per-period (per month/week/day), not over customer lifetime. This is a within-period order-frequency distribution, not a lifetime-orders cohort.
- **Business filter**: optional, unprefixed `frequency IN (1,2,3,4)` again (same ambiguity as 38287).
- Source: `partload_application.orders` only (state='3') — **does not include offline orders** (`ptl_offline_orders`), unlike most other cards in this family. Inconsistent source-table scope vs. its siblings.

### Card 35397 — "Business Customer Retention - Completed"
- `updated_at`: 2025-11-28T07:21:50.96Z · collection: "Product Observability" (5207, not the PTL collection) · tab: Retention
- **Computes**: cohort retention matrix — cohort = customer's first completed-order month; `month_since_signup = DATEDIFF(month, first_order_month, order_month)`, retention % = retained_customers / cohort total_customers (aggregate-then-ratio, correct), for month_since_signup 0–12.
- **Business filter**: **hardcoded**, not parameterized — `AND category = 'Business'` unconditionally in both online and offline CTEs. **No `category`/`Customer_category` template tag exists in this card's `dataset_query`** — the dashboard's Customer Category selector cannot affect this card at all.
- **Business definition**: `CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END`, `c` = `prod_curated.oms_public.customers` LEFT JOIN on mobile.
- Time basis: `created_at + INTERVAL '5 HOUR, 30 MINUTE'` (equivalent to +330 min).

### Card 39117 — "Business Customer Distribution"
- `updated_at`: 2026-07-14T10:37:29.01Z · tab: Business/Personal
- **Computes**: identical logic to card 38287 (Active/new/retained/reactivated, lifetime-first-order based) but **hardcoded** `category = 'Business'` in both CTEs — **no Customer_category template tag** in this card either. Dashboard-level Customer Category filter has no effect on it.
- Business definition: unprefixed `frequency IN (1,2,3,4)` (same ambiguity note as 38287).

### Card 39149 — "Business v/s Personal Customer Split"
- `updated_at`: 2026-07-14T10:55:48.02Z · tab: Business/Personal
- **Computes**: `business_customers = COUNT(DISTINCT CASE WHEN category='Business' THEN customer_mobile END)`; `business_customer_pct = business_customers*100/total_customers` (aggregate-then-ratio); mirrors for Personal; also `business_orders`/`business_order_pct` at order-row grain.
- **Business definition**: `CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END` (properly prefixed `c.frequency`, `c` = `prod_curated.oms_public.customers`).
- Also computes a separate "new customer"/"repeat customer" tag (`customer_tag`) based on whether the order occurred after the customer's lifetime first completed order — optional filter `customer_type = {{customer_type}}`.
- **Different "new" logic than 38287/39117**: here new/repeat is a binary per-order flag windowed by period (`MAX(...) OVER (PARTITION BY mobile, period)`), not the 3-way new/retained/reactivated taxonomy. See CONFLICT section.

### Card 39150 — "Business v/s Personal Order Split"
- `updated_at`: 2025-10-07T11:57:33.998Z · tab: Business/Personal
- **Computes**: same business/personal customer & order % split as 39149, without the new/repeat customer_tag dimension. `business_customer_pct`, `personal_customer_pct`, `business_order_pct`, `personal_order_pct`, all aggregate-then-ratio with `NULLIF(...,0)` divide-by-zero protection (returns NULL correctly).
- Business definition: `CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END` (prefixed).

### Card 41124 — "PTL New Customer Split by Business (Based on First Order Placed)"
- `updated_at`: 2025-10-08T05:44:03.97Z · collection " Customer Cards" (5508) · tab: New/Repeat
- **Computes**: classifies each customer's first-ever order across **PTL + PNM + Outstation/2W + Courier** verticals, picks the earliest (`LEAST(...)`), and reports the "first_thread" (which vertical acquired them) as % of customers whose **first PTL order** falls in the selected window, split by `customer_category`.
- **Cross-vertical sources**: `pnm_application.orders`+`customer_order_fares`, `oms_public.orders`+`oms_public.vehicles`+`trucks.vehicle_segment_mapping_v2` (Outstation/2W), `courier_application.orders`.
- **Business filter**: optional `customer_category = {{customer_category}}`, defined as unprefixed `frequency IN (1,2,3,4)` inside the `ptl_orders` CTE (joined to `prod_curated.oms_public.customers`).
- **TITLE-VS-SQL note**: title says "Based on First Order Placed" but `ptl_orders` CTE filters `ORDERS.state = '3'` (i.e., first **completed** PTL order, not first placed/attempted order). Possible mismatch between "placed" wording and the completed-order filter actually used.

### Card 41509 — "PTL New Customer Split by Business (Based on First Order Placed) - P/B Flows" (sankey)
- `updated_at`: 2025-10-08T05:44:25.37Z · tab: New/Repeat
- **Identical underlying query** to 41124 (same CTEs, same cross-vertical LEAST() logic), minus the `DATE_TRUNC` month grouping and with `customer_category` always in the SELECT (no optional filter) — a sankey-display variant of the same metric, not a distinct definition.

### Card 44080 — "Business User - Order Per Customer"
- `updated_at`: 2026-01-07T09:58:06.03Z · tab: Business/Personal
- **Computes**: `order_per_customer = COUNT(DISTINCT external_id)/COUNT(DISTINCT customer_mobile)` per period, **hardcoded** `category = 'Business'` (no template tag for category) in both online/offline CTEs.
- Business definition: `CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END` (prefixed).

### Card 43406 — "Aggregate M1, M3, M6, M12 Retention - Business"
- `updated_at`: 2025-12-01T09:46:29.79Z · collection "Cancellation Analysis" (5695) · tab: Retention
- **Computes**: cohort-based aggregate retention at fixed lags (M1/M3/M6/M12): `m{N}_agg_pct = SUM(retained at lag N, only for cohorts old enough) / SUM(cohort size, only for cohorts old enough)` — correct aggregate-then-ratio, and correctly excludes cohorts too young to have reached lag N (`periods_passed > N`) and excludes the current incomplete period from being a cohort.
- **Business filter**: hardcoded `CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END = 'Business'` (prefixed `c.frequency`), no template tag for category.

### Card 44086 — "Overall Customer Retention - Completed"
- `updated_at`: 2025-12-17T06:30:29.91Z · tab: Retention
- Same cohort-retention query family as 35397/43406, but with an **optional** `[[AND category = {{category}}]]` filter (has a real `category` template tag, values Business/Personal) instead of a hardcoded value — this one DOES respond to the dashboard's Customer Category selector.
- Business definition: `CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END` (prefixed).

### Card 44088 — "Aggregate M1, M3, M6, M12 Retention - Overall"
- `updated_at`: 2025-12-17T06:25:27.46Z · tab: Retention
- Same M1/M3/M6/M12 aggregate-retention logic as 43406, but with optional `[[and category = {{category}}]]` (real template tag) rather than hardcoded 'Business'.

### Card 39107 — "New v/s Repeat Customer Split"
- `updated_at`: 2026-07-14T09:15:34.56Z · tab: New/Repeat
- **Computes**: per period, `new_customer_pct`/`repeat_customer_pct` at customer grain (binary, based on whether customer's order in period occurred after their lifetime-first completed order) and `repeat_orders_pct` at order grain.
- **Business filter**: optional `category = {{Customer_category}}`, `CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END` (prefixed).
- Same binary new/repeat taxonomy as card 39149 (not the 3-way new/retained/reactivated taxonomy of 38287/39117) — see CONFLICT.

### Card 39118 — "Repeat Purchase Rate"
- `updated_at`: 2025-10-07T11:47:51.76Z · tab: New/Repeat
- Description (verbatim, in-tool): *"% of customers in the period who placed more than one order. Formula: (Customers with >1 order ÷ Total unique customers) × 100"*
- **Computes**: `repeat_purchase_rate_pct = COUNT(DISTINCT customer WHERE order_count>1 in period) / COUNT(DISTINCT customer in period) * 100` — this is an **intra-period** repeat-order rate (≥2 orders within the same period), a different concept from the lifetime-repeat definitions used elsewhere on the dashboard.
- Business filter: optional `category = {{category}}`, `customers.frequency IN (1,2,3,4)` (prefixed, alias `customers` not `c`).

### Card 39101 — "AOV P/B split"
- `updated_at`: 2025-10-07T11:58:36.31Z · tab: Business/Personal
- **Computes**: `business_aov = SUM(fare WHERE category='Business')/COUNT(DISTINCT external_id WHERE state=3 AND category='Business')`, mirrored for Personal and overall — all aggregate-then-ratio with `NULLIF(...,0)`.
- Business definition: `CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END` (prefixed), applied identically in online & offline CTEs.
- `final_fare` = `COALESCE(wd_fare.total_fare, estimated_fare/100)` for online; `estimated_fare` (offline, already presumed in rupees) for offline — **no `/100` division applied to offline estimated_fare**, unlike online — potential unit inconsistency between online (`/100`, implies paise stored) and offline (`gsheet_sync.ptl_offline_orders`, no `/100`) fare values feeding the same blended AOV. Not verified against actual data (execute forbidden) — flag as **[unverified]** unit-consistency risk.

### Card 39104 — "Monthly Churn PCT P/B split"
- `updated_at`: 2025-10-07T11:59:16.999Z · tab: Business/Personal
- **Computes**: churn = customer active in month `t` but NOT active in month `t-1` (same category); `business_churn_pct = SUM(is_churned WHERE Business)/COUNT(DISTINCT business_customers) * 100`.
- **Grain hardcoded to month** — `DATE_TRUNC('month', created_at)` is literal, **ignoring the `{{frequency}}` template tag** entirely (the tag exists for filters like pickup_city but churn's own period grain is not parameterized, unlike its dashboard siblings which use `{{frequency}}` throughout). Worth flagging: Week/Day frequency selections on the dashboard won't change this card's grain.
- Business definition: `CASE WHEN customers.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END` (prefixed).

### Card 39109 — "OS Customer Split"
- `updated_at`: 2025-11-19T10:56:21.43Z · tab: New/Repeat
- **Computes**: for customers whose first PTL completed order falls in-window, splits them into "Aq New" (no prior Outstation-vertical order, or PTL first-order predates it) vs "Existing OS" (already had an Outstation order before their first PTL order). % of customers per period (aggregate-then-ratio).
- **"OS" = Outstation** (`oms_public.orders` filtered `v.vas_tag = 3`), i.e., cross-sell/acquisition-source analysis, not a business-vs-personal segmentation card despite living in the customer-segmentation set. No business/personal filter used at all.

### Card 44410 — "Overall Conversion"
- `updated_at`: 2026-05-12T07:07:49.71Z · collection " Customer Cards" (5508) · tab: Conversion
- **Computes**: session funnel — `vss_sessions` (event `vehicleselectionscreen_vehicles_loaded`), `quote_sessions` (`ptlbookingdetailspage_quote_viewed`), `book_now_sessions` (`ptlbookingdetailspage_booknow_clicked`, optionally restricted to completed orders via `{{order_type}}`); `conversion_pct = book_now_sessions/vss_sessions`; `quote_to_order = book_now_sessions/quote_sessions`.
- **Source**: `partload_analytics.ptl_fe_events` (event-level clickstream), joined to `partload_application.orders` via `variable_attr:order_id`. Internal-user exclusion via `customer_mobile_number NOT IN (ptl_internal_users)`.
- **Time-basis inconsistency [unverified]**: unlike the order-level cards (which convert `created_at` UTC→IST via `+330 mins`/`CONVERT_TIMEZONE`), this card buckets directly on `DATE(event_timestamp)` with no timezone conversion applied. Whether `ptl_fe_events.event_timestamp` is already stored in IST could not be confirmed from SQL text alone (no execute permitted) — flagged as [unverified] rather than assumed a bug.
- No business/personal segmentation in this card.

### Card 44409 — "New Repeat Conversion"
- `updated_at`: 2026-07-14T12:18:04.26Z · tab: Conversion
- **Computes**: same VSS→booknow funnel as 44410, but grouped by `customer_tag` ('new customer' if event predates or has no first-order record, else 'repeat customer') and by A/B experiment `experiment_key`/`variant_name` parsed out of `variable_attr` JSON.
- Same event source and internal-user exclusion as 44410. Same timezone caveat.
- No business/personal segmentation.

---

## Business-customer definition — DEDICATED SECTION

**Every card on this dashboard that segments Business vs Personal uses the identical rule, with no exceptions found:**

```sql
CASE WHEN c.frequency IN (1,2,3,4) THEN 'Business' ELSE 'Personal' END
```

- **Table**: `prod_curated.oms_public.customers` (aliased `c` or `customers`)
- **Column**: `frequency`
- **Join**: `LEFT JOIN prod_curated.oms_public.customers c ON <orders_table>.customer_mobile = c.mobile`
- **Values that mean "Business"**: `frequency IN (1,2,3,4)`. Everything else (including `NULL`, i.e., no match in `oms_public.customers`) falls to `ELSE 'Personal'` — **no explicit "unknown"/excluded bucket exists; unmatched customers default to Personal.**
- `prod_eldoria.core.dim_customers` was **never referenced** in any of the 22 cards opened — no card uses it as a business/consumer source. Only `prod_curated.oms_public.customers` is used across this dashboard.

**Two implementation variants found (functionally equivalent, but worth flagging as inconsistent style)**:
1. **Properly prefixed** (`c.frequency` / `customers.frequency`) — cards 38285, 38619, 39149, 39150, 44086, 44088, 39107, 39118 (alias `customers`), 39101, 39104 (alias `customers`), 39118.
2. **Unprefixed bare `frequency`** — cards 38287, 39117, 38900, 41124, 41509. These still LEFT JOIN `oms_public.customers c` but reference the bare column name `frequency` with no table qualifier. This resolves correctly today only because `orders`/`ptl_offline_orders` have no column literally named `frequency`; Snowflake resolves the unqualified reference to the sole table that defines it. **This is a latent fragility**, not a current bug — if a `frequency` column were ever added to the orders tables, these ~5 cards would silently break or change meaning. Reported as a risk finding, not a currently-wrong result.

**Hardcoded-vs-parameterized inconsistency**: Several "Business ___" titled cards (35397, 39117, 43406, 44080) **hardcode** `category = 'Business'` in the SQL with **no `category`/`Customer_category` template tag defined at all** — the dashboard's shared "Customer Category" filter (parameter `cb692fc3`) has **no effect** on these cards even though the dashboard UI binds a value to them. Other cards in the same family (44086, 44088, 38287 [with 3-way filter], 39107) properly expose an optional template tag that the shared filter can drive. This means toggling "Customer Category" on the dashboard silently does nothing for a subset of cards — a real UX/consistency gap, independent of the metric definition itself.

---

## NSM / monthly transacting customers — DEDICATED SECTION

**No card on this dashboard computes "Monthly Transacting Business Customers" as a named or dedicated metric.** No card title, description, or SQL alias mentions "NSM," "North Star," or produces a single headline transacting-customer count gated to Business + Monthly + Transacting in one purpose-built tile.

**Closest analogs** (neither is a drop-in NSM implementation):
1. **Card 38287 "Customer Distribution"** and its hardcoded-Business twin **39117 "Business Customer Distribution"** — compute `COUNT(DISTINCT customer_mobile)` ("Active_customers") per period (parameterized Day/Week/Month via `{{frequency}}`), from the UNION of completed (`state='3'`) online + offline PTL orders, excluding internal users. When run with `frequency = Month` and (for 38287) `Customer_category = Business`, this yields a monthly count of distinct customers who transacted (completed order) and are classified Business — which is conceptually the NSM's numerator population. But:
   - It is a distribution/segmentation chart (further split into new/retained/reactivated), not a single NSM number.
   - "Transacting" here = placed ≥1 **completed** order in the period; this matches a reasonable NSM "transacting" definition but is not labeled as such anywhere.
   - Card 39117 hardcodes Business and cannot be toggled off; card 38287 needs the dashboard filter set correctly to reproduce a Business-only count.
2. No card was found that reproduces or is labeled with the previously-reported NSM figures (2247 for Apr-26, 1879 for Mar-26) — cannot confirm or reproduce those numbers from this dashboard's SQL (execution forbidden regardless).

**Conclusion: the NSM (Monthly Transacting Business Customers) has no dedicated implementation on Dashboard 4569.** The building blocks exist (business classification rule + monthly distinct-transacting-customer count), but they live in general-purpose distribution cards, not a purpose-built NSM card.

---

## Metric definitions table

| metric | numerator | denominator | source tables | key filters | card id | card updated_at | confidence |
|---|---|---|---|---|---|---|---|
| Active/transacting customers (period) | COUNT(DISTINCT customer_mobile) | — | partload_application.orders, gsheet_sync.ptl_offline_orders | state=3, internal-user excl., optional Business/Personal | 38287 | 2026-07-14 | verified |
| Business Active customers (period) | COUNT(DISTINCT customer_mobile), category hardcoded Business | — | same | state=3, internal-user excl. | 39117 | 2026-07-14 | verified |
| New/Retained/Reactivated % | count per bucket (lifetime-first-order + gap logic) | Active_customers (period) | same | same | 38287 / 39117 | 2026-07-14 | verified |
| Business vs Personal customer % | COUNT(DISTINCT cust WHERE category='Business') | COUNT(DISTINCT cust, period) | same + oms_public.customers | frequency IN(1,2,3,4) | 39149, 39150 | 2026-07-14 / 2025-10-07 | verified |
| Business vs Personal order % | COUNT(orders WHERE category='Business') | COUNT(all orders, period) | same | same | 39149, 39150 | same | verified |
| Revenue / Customer | SUM(final_fare) | COUNT(DISTINCT customer_mobile) | orders, order_fares, fare_revision_notified | state=3 | 38283 | 2025-10-07 | verified |
| AOV (overall / business / personal) | SUM(final_fare, segment) | COUNT(DISTINCT external_id, state=3, segment) | same + oms_public.customers | state=3, category | 39101 | 2025-10-07 | verified (offline `/100` unit gap [unverified]) |
| Orders / Customer (overall / business) | COUNT(DISTINCT external_id) | COUNT(DISTINCT customer_mobile) | orders, ptl_offline_orders | state=3/'3' | 38619, 44080 | 2025-10-07 / 2026-01-07 | verified |
| Repeat Purchase Rate | COUNT(DISTINCT cust, order_count>1 in period) | COUNT(DISTINCT cust, period) | same | intra-period only | 39118 | 2025-10-07 | verified |
| New vs Repeat customer % (binary, lifetime-based) | COUNT(DISTINCT cust tagged 'new'/'repeat') | COUNT(DISTINCT cust, period) | same + oms_public.customers | lifetime first completed order | 39107, 39149 | 2026-07-14 | verified |
| Cohort Retention (M0–M12, %) | retained_customers (cohort, lag) | cohort total_customers | same | first completed order = cohort anchor | 35397, 44086 | 2025-11-28 / 2025-12-17 | verified |
| Aggregate M1/M3/M6/M12 Retention % | SUM(retained at lag N, mature cohorts) | SUM(cohort size, mature cohorts) | same | excludes immature cohorts | 43406, 44088 | 2025-12-01 / 2025-12-17 | verified |
| Monthly Churn % (business/personal) | customers active in month t not in t-1 | customers active in month t | same + oms_public.customers | grain hardcoded to month, ignores {{frequency}} | 39104 | 2025-10-07 | verified |
| Order-count cohort distribution ("LTO") | COUNT(DISTINCT cust) per order-count bucket, **within period** | total customers, period | partload_application.orders only (no offline) | state='3' | 38900 | 2025-09-16 | verified (title says lifetime, SQL is period-bound — mismatch) |
| First-acquisition-thread split (PTL/PNM/OS/Courier) | COUNT(DISTINCT mobile) per first_thread | total customers (period, LEAST() first-ever order across verticals) | orders, pnm_application.orders, oms_public.orders, courier_application.orders | first_ptl_order state=3; "Placed" in title but filter is completed | 41124, 41509 | 2025-10-08 | verified (title/SQL wording mismatch) |
| Outstation acquisition split ("OS Customer Split") | COUNT(DISTINCT mobile) per aq_type | total customers (period) | orders, oms_public.orders, vehicles, vehicle_segment_mapping_v2 | vas_tag=3 | 39109 | 2025-11-19 | verified |
| VSS→Quote→BookNow session conversion | COUNT(DISTINCT app_session_id, booknow) | COUNT(DISTINCT app_session_id, vss) | partload_analytics.ptl_fe_events, orders | internal-user excl.; no tz conversion on event_timestamp [unverified] | 44410, 44409 | 2026-05-12 / 2026-07-14 | verified (tz handling unverified) |

---

## Conflicts

- **CONFLICT: what counts as "new" within a period.**
  - Side A (38287, 39117): three-way taxonomy — `new` (period = lifetime first order month), `retained` (immediately consecutive period), `reactivated` (gap > 1 period since last activity).
  - Side B (39107, 39149): binary taxonomy — `new` vs `repeat`, determined purely by whether the order postdates the customer's lifetime-first completed order, with no distinction between "just came back after 1 gap period" vs "just came back after 10 gap periods."
  - **UNRESOLVED** — not reconciled anywhere in the dashboard; both patterns are actively used side-by-side.

- **CONFLICT: intra-period vs lifetime "repeat."**
  - Card 39118 ("Repeat Purchase Rate") defines repeat as ≥2 orders **within the same period** (a frequency/intensity metric).
  - Cards 39107/39149 define repeat as "has a lifetime order history before this period" (a tenure/lifecycle metric).
  - Both are labeled with overlapping vocabulary ("repeat") but measure different things. **UNRESOLVED.**

- **CONFLICT: is the Customer Category dashboard filter authoritative?**
  - Cards with a real `category`/`Customer_category` template tag (38287, 38285, 38619, 44086, 44088, 39107, 39149\*, 39150\*, 39101, 39104, 39118, 41124) respond to the shared dashboard filter (\*39149/39150 use `c.frequency` unconditionally in the SELECT and don't gate rows by a category filter tag at all — they always show both segments side by side, which is a third distinct behavior).
  - Cards with **no** category template tag but a hardcoded 'Business' value (35397, 39117, 43406, 44080) ignore the dashboard filter entirely.
  - **UNRESOLVED** — this is a dashboard-authoring inconsistency, not a business-logic conflict, but it affects how "Business" numbers should be read off the dashboard.

- **CONFLICT: "first order" = placed vs completed.**
  - Cards 41124/41509 title themselves "Based on First Order Placed" but filter `state = '3'` (completed) for the PTL leg — i.e., SQL measures first **completed** order, not first placed/attempted order. Other cards (35397, 44086, etc.) are explicitly titled "...Completed" and correctly filter to completed. **UNRESOLVED** — titling inconsistency, not cross-checked against an actual "placed" (non-completed) event.

---

## Cards not opened (28 of 50)

Prioritization applied per brief (customers/users, sessions/conversion, transacting customers, NSM, business-vs-consumer, orders/customer, AOV were prioritized). Reasons grouped:

**Group A — near-duplicate of an already-extracted pattern (same SQL logic, Personal-mirror or display variant), opening would not add new definitional information:**
- 39103 "Personal Customer Distribution" — Personal-only mirror of 39117 (Business Customer Distribution)
- 44081 "Personal User - Orders Per Customer" — Personal-only mirror of 44080
- 43540 "Personal Customer Retention - Completed" — Personal-only mirror of 35397/44086
- 43541 "Aggregate M1,M3,M6,M12 Retention - Personal" — Personal-only mirror of 43406
- 39119 "New v/s Repeat Orders Split" — order-level variant of 39107's customer-level split
- 41371 "New v/s Repeat Orders Spit" (Overall tab) — appears to be a near-duplicate/rename of 39119's order split
- 44805 "Raw Data - New/Repeat" — raw data table dump, not an aggregate metric card
- 44412 "Overall Conversion - Funnel" — funnel-display variant of 44410, same base query expected
- 44469 "New Repeat Quote to Order Conversion" — quote-stage variant of 44409's funnel
- 44387 "Quote to Completed Order- Session Conversion (Completed) - New vs Repeat" — another funnel-stage variant of the 44409/44410 family

**Group B — "Poor Customer Retention" tab (8 cards): retention cut by service-quality/experience cohorts (SLA breach, poor experience, cancellations, WD/wrong-delivery), not by business-vs-consumer or NSM — out of scope per prioritization instructions:**
- 43857 "SLA customer retention", 43860 "Poor experienced customer retention", 43827 "WD customer Retention", 43859 "Cancel order customer retention", 44169 "Cancel Order customer Aggregate M1, M3 Retention", 44170 "WD Customer Aggregate M1, M3 Retention", 43908 "Good Experience Customer Retention", 44281 "First Order cancelled Customer Retention"

**Group C — "First-time user Metrics" tab (10 cards): activation/VSS-to-order/cancellation funnels for first-time users; adjacent to but not core to NSM or business/consumer segmentation — deprioritized given the 50-card volume:**
- 44527 "Activation % (Completed Order) - First Time User", 44536 "VSS Impressions to First Placed Order – Personal Users %", 44219 "VSS Impressions to First Placed Order – Business Users %", 44222 "Quote to booking conversion -first time user", 44215 "First-Time Users: Placed Orders Within 7 & 30 Days", 44218 "First Time User - cancellation %", 44350 "First Impression to First Order Completion – Business Users %", 44560 "First Impression to First Order Completion – Personal Users %", 44221 "Time for second order by first time user", 44184 "Activation % (Placed Order) - First Time User"

If deeper verification of the business/personal split specifically within Groups A/C is needed later (e.g., to confirm 39103/44081 truly mirror their Business counterparts exactly), those are the next-highest-value follow-ups.
