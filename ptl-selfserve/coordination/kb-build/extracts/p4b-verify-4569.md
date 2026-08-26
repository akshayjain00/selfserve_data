# P4b — Verification: Dashboard 4569 card claims

Verification worker pass. Metadata reads only (`get_card`) — no query execution, no `execute_card`/`execute_query`/`sql-exec` used. Column NAMES only recorded, no data values, no creator identities (creator blocks omitted below).

## Fingerprint table

| card_id | name | updated_at | database_id |
|---|---|---|---|
| 39117 | Business Customer Distribution (trailing space in title) | 2026-07-14T10:37:29.014707Z | 73 |
| 38287 | Customer Distribution | 2026-07-14T10:08:52.588226Z | 73 |
| 39149 | Business v/s Personal Customer Split | 2026-07-14T10:55:48.018831Z | 73 |
| 39107 | New v/s Repeat Customer Split (trailing space in title) | 2026-07-14T09:15:34.562895Z | 73 |
| 39118 | Repeat Purchase Rate (trailing space in title) | 2025-10-07T11:47:51.763503Z | 73 |
| 43406 | Aggregate M1, M3, M6, M12 Retention - Business | 2025-12-01T09:46:29.789673Z | 73 |
| 39104 | Monthly Churn PCT  P/B split | 2025-10-07T11:59:16.999949Z | 73 |
| 38900 | PTL LTO customer cohorts (trailing space in title) | 2025-09-16T11:32:57.342774Z | 73 |
| 41124 | PTL New Customer Split by Business (Based on First Order Placed) | 2025-10-08T05:44:03.974593Z | 73 |
| 44410 | Overall Conversion | 2026-05-12T07:07:49.712712Z | 73 |

All ten cards sit on `database_id 73` (same Snowflake connection). Card 39117/38287/39149/39107/39118/38900/44410/41124 last-updated dates cluster Sep–Oct 2025 except 39117/38287/39149/39107, which were all re-touched on **2026-07-14** (same day, ~50 min apart — looks like a single batch edit pass across the segmentation-card family). 44410 is the most recently touched card overall (2026-05-12).

---

## 39117 — "Business Customer Distribution" (NORTH STAR — detailed section)

Six-part claim, tested against the verbatim SQL:

1. **`COUNT(DISTINCT customer_mobile) AS Active_customers`** — CONFIRMED, verbatim in final SELECT:
   ```sql
   SELECT 
     period,
     COUNT(DISTINCT customer_mobile) AS Active_customers,
     ...
   FROM classified
   GROUP BY 1
   ```
2. **`category='Business'` via `frequency IN (1,2,3,4)` on `oms_public.customers`** — CONFIRMED, in both the online and offline CTEs:
   ```sql
   CASE 
       WHEN frequency IN (1, 2, 3, 4) THEN 'Business'
       ELSE 'Personal'
     END as category
   ...
   and category = 'Business'
   ```
   (hardcoded filter, not an optional `[[AND ...]]` — there is no parameter to turn this off on this card).
3. **`state='3'`** — CONFIRMED. Online CTE: `AND state = '3'`. Offline CTE: `WHERE state = 3` (integer, not string, but same completed-state semantics).
4. **grain `DATE_TRUNC({{frequency}}…)` defaulting to Month** — CONFIRMED: `DATE_TRUNC({{frequency}}, o.created_at) AS period`; template tag `frequency` has `"default":["Month"]`.
5. **internal users excluded** — PARTIAL. Confirmed for the **online** leg only: `WHERE o.customer_mobile NOT IN (SELECT mobile FROM partload_analytics.ptl_internal_users)`. The **offline** CTE (`prod_curated.gsheet_sync.ptl_offline_orders`) has **no internal-user exclusion at all** — it is missing from that branch's WHERE clause entirely. This is a gap not called out in the original claim.
6. **online `UNION` offline** — CONFIRMED: `final_orders AS (SELECT * FROM online_filtered_orders UNION SELECT * FROM offline_filtered_orders)`.

### The precise question: does 39117, run for a calendar month with default params, compute "unique business customers with ≥1 completed PTL order that month"?

**Yes, with one caveat.** When `start_date`/`end_date` are set to bound a single calendar month and `frequency` is left at its default (`Month`), the pipeline resolves to exactly that behavior:
- `final_orders` = union of online+offline orders where `state='3'` (completed) and `category='Business'`.
- `orders_with_period` collapses to one row per `(customer_mobile, period)` via `GROUP BY 1,2,3` — so a customer with N completed orders in the month is counted once.
- Final `COUNT(DISTINCT customer_mobile)` per `period` = distinct business customers with ≥1 completed order that month.

Caveat: because internal-user exclusion is missing on the offline leg (point 5 above), if any offline/manual (gsheet-sync) rows belong to internal-user mobiles, they would leak into `Active_customers` — a data-quality risk the claim didn't surface.

Note also: the card's **stored defaults** for `start_date`/`end_date` are `2025-05-01` / `2025-08-31` — a 4-month span, not a single month. Run unmodified, the card returns one row per month across that whole range (not "the" calendar month) — the "single calendar month" framing only holds once a user narrows the date parameters to one month.

### Is the offline base included by default? Is there an incl./excl. toggle?

**No toggle exists.** The offline `UNION` is hardcoded into the CTE structure — there is no parameter (no `[[...]]` optional block, no template tag) that lets a user run this card online-only vs. online+offline. It **always** includes the offline base. Any "D3" ruling that requires showing both an offline-included and offline-excluded view **cannot be produced from this card as-is** — a modified/forked query would be needed to isolate the online-only leg.

---

## 38287 — "Customer Distribution" (not business-filtered)

**CONFIRMED.** Structurally identical to 39117 (same online/offline CTEs, same `first_ptl_order`/`orders_with_period`/`with_flags`/`classified` pipeline, same final `Active_customers`/new/retained/reactivated shape), but the Business/Personal split is **optional**, not hardcoded:
```sql
[[AND 
  CASE 
    WHEN frequency IN (1, 2, 3, 4) THEN 'Business'
    ELSE 'Personal'
  END = {{Customer_category}}]]
```
`Customer_category` is a static-list parameter (`Business`/`Personal`) with no default set — if left blank, **both** segments are included, confirming "not business-filtered" (by default). Same hardcoded online+offline `UNION`, same offline-leg gap on internal-user exclusion as 39117 (also missing there).

---

## Business-customer rule — 39149, 39107

**CONFIRMED for both.** Identical rule, verbatim:
```sql
CASE 
    WHEN c.frequency IN (1,2,3,4) THEN 'Business' 
    ELSE 'Personal' 
END AS category
...
LEFT JOIN prod_curated.oms_public.customers c ON o.customer_mobile = c.mobile   -- (39149: o.customer_mobile / offline: ofo.customer_mobile)
```
- 39149 ("Business v/s Personal Customer Split"): identical CASE/JOIN in both `online_orders` and `offline_orders` CTEs.
- 39107 ("New v/s Repeat Customer Split"): identical CASE/JOIN in both `online_orders` and `offline_orders` CTEs.

Because the join is a `LEFT JOIN`, an unmatched `customer_mobile` yields `c.frequency IS NULL`; `NULL IN (1,2,3,4)` evaluates to `NULL` (not TRUE), so the `CASE` falls to `ELSE 'Personal'`. **Unmatched → Personal, confirmed** by construction in both cards.

---

## Retention / repeat taxonomies (G-023)

### 39118 — repeat = intra-period

**CONFIRMED.**
```sql
customer_orders AS (
  SELECT DATE_TRUNC({{frequency}}, created_at) AS period, customer_mobile, COUNT(*) AS order_count
  FROM final GROUP BY 1,2
)
SELECT period, COUNT(DISTINCT customer_mobile) AS total_customers,
  COUNT(DISTINCT CASE WHEN order_count > 1 THEN customer_mobile END) AS repeat_customers, ...
```
"Repeat" = ≥2 orders **within the same period bucket**, full stop — no reference to lifetime order history anywhere in the query.

### 39107 / 39149 — new-vs-repeat is binary and lifetime-based

**CONFIRMED**, but with an important nuance the KB claim doesn't mention. Both use an all-time, unwindowed `first_ptl_order`/`base` CTE (`MIN(created_at)` over all history) and then:
```sql
CASE 
  WHEN MAX(CASE WHEN f.created_at > fp.first_ptl_order_date THEN 1 ELSE 0 END)
         OVER (PARTITION BY customer_mobile, period) = 1
    THEN 'repeat' ELSE 'new'
END AS customer_type
```
This is a **per-customer-per-period** binary flag driven by comparison to the customer's lifetime first order — confirmed lifetime-based, confirmed binary (only 'new'/'repeat', unlike 39117/38287's three-way new/retained/reactivated).

**Nuance (worth flagging):** because the flag is a window-function MAX over `(customer_mobile, period)`, a customer's very first active period is tagged `'repeat'` too if they place ≥2 orders in that acquisition period (the 2nd+ order's `created_at` is `>` the 1st order's `created_at`, which equals `first_ptl_order_date`). So the "new" bucket only ever appears for a customer's single-order acquisition period; every subsequent active period is unconditionally `'repeat'` regardless of order count that period. This makes 39107/39149's repeat definition even more different from 39118's than the flat claim suggests.

### Are 39118 vs 39107/39149 genuinely incompatible taxonomies?

**Yes — confirmed incompatible**, and the mechanism is now precisely characterized:
- **39118**: resets every period. A long-tenured customer with exactly 1 order this period is **not** "repeat" this period.
- **39107/39149**: never resets. Any period after the customer's acquisition period is **always** "repeat," even with just 1 order that period; the acquisition period itself can also flip to "repeat" if multi-order.

These will diverge sharply on any cohort with steady 1-order/period cadence: 39118 would show ~0% repeat, 39107/39149 would show ~100% repeat for the same population (post-acquisition). G-023's claim that two incompatible taxonomies coexist is **CONFIRMED**, with the exact divergence mechanism identified above.

### 43406 — aggregate M1/M3/M6/M12 retention

**CONFIRMED**, and it's a **third**, distinct cohort-based framework (neither of the above): builds `cohort_month` = customer's first Business order month, then `retention_matrix` measures whether the customer had **any** order at exactly `DATEDIFF({{frequency}}, cohort_month, order_month) IN (1,3,6,12)`, aggregated as `SUM(retained_Mx)/SUM(total_customers)` gated on `periods_passed > x` (only fully-matured cohorts counted — no partial-period bias). Hardcodes `= 'Business'` (matches title's "- Business" suffix); `{{frequency}}` here controls cohort/lag granularity (Day/Week/Month/Quarter), unlike the business/personal `frequency` column used elsewhere — different meaning of the same template-tag name across cards, worth noting as a KB terminology trap.

---

## Known-defect claims

### 39104 — "hardcodes month grain and ignores the `{{frequency}}` filter"

**PARTIAL — refute the "ignores" framing.** The grain IS hardcoded:
```sql
DATE_TRUNC('month', created_at) AS period
```
literal `'month'`, no template substitution. **CONFIRMED** on hardcoding.

But: **there is no `{{frequency}}` template tag defined on this card at all** — `template-tags` only contains `start_date, pickup_city, drop_city, end_date, route_name`; `parameters` likewise has no Frequency entry. So the card cannot "ignore" a `{{frequency}}` filter — no such filter/parameter exists on it to be ignored. The KB phrasing implies a frequency selector is present and silently bypassed by the SQL; in fact the card was simply never given one. Net effect on the leadership note is the same (always monthly, un-adjustable) but the mechanism claimed is wrong — this should be corrected to "39104 has no frequency parameter at all; grain is hardcoded to month" rather than "ignores {{frequency}}."

### 38900 — titled "LTO" but buckets are period-bound

**CONFIRMED.**
```sql
user_orders AS (
  SELECT customer_mobile, DATE_trunc({{frequency}}, orders.created_At + INTERVAL '330 minutes') as mth,
         COUNT(DISTINCT orders.id) AS completed_orders
  FROM partload_application.orders ...
  GROUP BY 1, 2   -- customer_mobile, mth
)
...
CASE WHEN completed_orders = 1 THEN '1 order' WHEN completed_orders BETWEEN 2 AND 3 THEN '2-3 orders' ... END AS order_cohort
```
`completed_orders` is `COUNT(DISTINCT orders.id)` **grouped by `(customer_mobile, mth)`** — i.e., orders **within that period only**, not a lifetime/all-time order count. A customer with 20 lifetime orders spread 1/month would sit in the "1 order" bucket every month. Title says "LTO" (implying lifetime), buckets are in fact period-bound. Confirmed as claimed.

### 41124 — titled "Based on First Order Placed" but filters completed, not placed

**CONFIRMED.**
```sql
ptl_orders AS (
  SELECT customer_mobile AS mobile, ...,
    MIN(date(ORDERS.created_at + interval '330 minutes')) AS first_ptl_order_date
  FROM partload_application.orders
  ...
  WHERE customer_mobile NOT IN (...)
  and ORDERS.state = '3'      -- completed, not "placed"
  GROUP BY 1,2
)
```
`state = '3'` filters to completed orders only; "first order placed" would imply any booking attempt regardless of completion. Confirmed mismatch between title and SQL.

### 44410 — VSS→Quote→BookNow session conversion

**CONFIRMED**, with one precision note. The card counts distinct `app_session_id` for exactly three events:
```sql
count(distinct case when event_name = 'vehicleselectionscreen_vehicles_loaded' then app_session_id end) as vss_sessions,
count(distinct case when event_name = 'ptlbookingdetailspage_quote_viewed' then app_session_id end) as quote_sessions,
COUNT(DISTINCT CASE WHEN event_name = 'ptlbookingdetailspage_booknow_clicked' AND (...) THEN app_session_id END) AS book_now_sessions,
```
plus two ratios: `conversion_pct = book_now_sessions / vss_sessions` (overall VSS→BookNow, skips the middle stage) and `quote_to_order = book_now_sessions / quote_sessions` (Quote→BookNow). There is **no explicit VSS→Quote ratio column** — the three named events are all present and tracked (confirming the funnel's stages), but the computed ratios are VSS→BookNow and Quote→BookNow, not a strict three-stage chained funnel (VSS→Quote, then Quote→BookNow). Minor precision gap in the claim, not a refutation of the funnel's existence.

---

## Anything the KB got wrong that wasn't asked about

1. **39117/38287 offline-leg internal-user exclusion gap**: both cards apply `NOT IN (SELECT mobile FROM ptl_internal_users)` only to the **online** CTE; the offline (gsheet-sync manual entry) CTE has no such filter. Any internal/test mobiles entered through the offline sheet would inflate Active_customers/business counts undetected.
2. **39104's "ignores {{frequency}}" framing is technically wrong**: there is no `{{frequency}}` parameter on the card at all (not defined in template-tags, not in parameters) — so nothing is being "ignored." The observable symptom (always-monthly, no way to switch grain) is real, but the root cause is "parameter never added," not "parameter present but bypassed."
3. **43406's `{{frequency}}` template tag is semantically different from the `frequency` column used in the Business/Personal CASE logic elsewhere** — in 43406 it's a Day/Week/Month/Quarter cohort-lag granularity selector, unrelated to `oms_public.customers.frequency` (the 1/2/3/4 business-tier column). Same tag name, two unrelated meanings across the card family — a real footgun for anyone reading cards side-by-side.
4. **39107/39149's "repeat" flag can fire in a customer's very first active period** if they place ≥2 orders that period (see nuance above) — the KB's "lifetime-based" description is directionally right but understates how aggressively it converges to 100%-repeat after acquisition.
5. All ten cards share `database_id 73` — consistent single Snowflake connection, no cross-database drift risk for this family.

---

**File written by verification worker; metadata-only, no card/dashboard writes made.**
