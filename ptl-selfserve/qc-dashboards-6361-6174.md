# QC — dashboards 6361 and 6174

`qc_date: 2026-08-31` · auditor: SQL read + Snowflake verification
Source of truth for card SQL: `PROD_ELDORIA.raw.metabase_public_report_card`
(Metabase app-DB replica, max `updated_at` 2026-08-31T04:51Z at time of audit).

> The Metabase session token in `~/.claude/mcp.json` is expired (401), so **dashboard-level
> filter defaults and parameter→card mappings could not be read**. Everything below is derived
> from card SQL, card-level template tags, and direct Snowflake verification.

## The two dashboards track different experiments

| | `dashboard/6361` | `dashboard/6174` |
|---|---|---|
| Name | A/B: Experiment observability | Experiment Observability |
| Owner | Devansh Sharma | Tanishq Keswani |
| Experiment | `ptl_partner_found_comms` | `sdd_vs_ndd` |
| Assignment source | `PROD_ELDORIA.RAW.STATSIG_PROD_EXPOSURES` | `quotations.resolved_experiments` (JSON flatten) |
| Randomisation unit | customer (`customers.id` → `uuid`) | quotation |
| Cards | 15 SQL + 6 text | 27 SQL + 2 text |
| Arms | `pass` / `fail` | `variant_name` per `experiment_key` |

**They are not duplicates and will not reconcile.** Nothing on 6174 reads Statsig; nothing on
6361 reads `resolved_experiments`.

---

## Verified clean (6361)

| Check | Result |
|---|---|
| Definition drift across cards | 14/15 metric cards share a **byte-identical** prelude (md5 `36724d62…`) |
| Timezone idiom | `orders.created_at` / `pickup_slot_start` are `TIMESTAMP_NTZ` → 3-arg `CONVERT_TIMEZONE` is correct; **no LTZ double-shift** |
| Statsig → customers join | 10,154 / 10,154 exposed customers matched (100%) |
| Arm contamination | 0 customers appear in both `pass` and `fail` |
| Sample ratio | SDD 4,631 (fail) vs 4,622 (pass) — no SRM |
| FE-events join key (card 59439) | 10,150 / 10,154 matched — `PTL_FE_EVENTS.customer_id` is the numeric id, join is right |
| `cancellation_source` CASE | all 3 live codes (1, 3, 4) mapped — no silent NULL drop |
| `NOT IN (… ptl_internal_users)` | 62 rows, 0 NULL mobiles — NULL trap not currently firing |
| `MAX` vs `MIN` inside `is_active` | 0 orders ever have >1 active assignment row — moot *given* the filter |

---

## Findings — `dashboard/6361`

### 1. HIGH — `is_active = TRUE` distorts allocation time and inflates CBDF

`vehicle_assigned` reads only currently-active assignment rows:

```sql
SELECT order_id, MAX(created_at) AS vehicle_assigned_at
FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES
WHERE is_active = TRUE GROUP BY 1
```

On reassignment the earlier row is deactivated, so `alloc_ist` becomes the time the **final**
driver was attached, not the time a driver was first found.

Measured on assignments since 2026-07-07:

| | value |
|---|---|
| Allocated orders with an earlier now-inactive assignment | **1,735 / 19,802 = 8.76%** |
| Median overstatement | **101 min** |
| Mean / max overstatement | 234 min / 2,513 min |
| Orders whose only assignment rows are inactive | 63 (→ `alloc_ist` NULL → counted as CBDF) |

Effect on the readout (SDD cohort, as-built vs first-assignment):

| Metric | fail (as-built → fixed) | pass (as-built → fixed) |
|---|---|---|
| P50 alloc mins | 16.0 → 15.0 | 15.0 → 14.0 |
| **P90 alloc mins** | **44.0 → 33.0** | **50.0 → 33.0** |
| CBDF orders | 468 → 463 | 400 → 399 |

As-built, P90 says the treatment arm is **6 minutes worse**. Corrected, the two arms are
**identical (33 vs 33)**. The artifact manufactures an arm difference in the metric closest to
the experiment's own mechanism.

**Fix:** use the pattern already on 6174 (cards 48947 / 49537) — `ROW_NUMBER() OVER (PARTITION BY
order_id ORDER BY created_at ASC) = 1` over **all** rows, no `is_active` filter.
Cards affected: 54220 (worst), 54215, 54216, 54218, 54219, 54221, 54223, 54224, 54225, 54226.

### 2. HIGH — the "SDD-only cohort" in the description is not enforced in SQL

The dashboard description states *"Cohort: SDD (same-day) orders"*, but `pickup_slot_day` is an
optional filter and the card-level tag is `required: false, default: null`:

```sql
[[AND pickup_slot_day IN ({{pickup_slot_day}})]]
```

Cohort composition and why it matters:

| Slot day | orders (fail / pass) | P50 alloc mins |
|---|---|---|
| Same Day | 4,631 / 4,622 | **16** |
| Next Day | 571 / 537 | **737** |
| Later | 11 / 13 | 2,015 |

**1,132 orders (10.9%) are not same-day, with a 46× different allocation time.** If the
dashboard-level filter default is empty, every percentile and rate card silently mixes them.

**Fix:** hardcode the scope in `base`, or set the tag `required: true, default: 'Same Day'`.
Do not rely on a dashboard filter default for a cohort definition.
Also note `pickup_slot_day` here is *pickup-slot date vs order date* — not the `delivery_type`
SDD/NDD used on `dashboard/4198`, and not `slots.EDD_BUFFER_IN_DAYS`. Three different "same day"s.

### 3. MEDIUM — "excludes offline orders" is unverifiable

`PROD_CURATED.PARTLOAD_APPLICATION.ORDERS` has no offline and no `is_test` column. The only
exclusion in the SQL is `ptl_internal_users`. Either the description claim is vacuous or an
intended filter was never added.

### 4. MEDIUM — CBDF % has a source-restricted numerator over an all-orders denominator

`is_cbdf` requires `cancellation_sources IN ({{cancellation_source}})` (default `Customer_App`),
while the denominator is `COUNT(DISTINCT order_id)` over all placed orders. Lifetime cancellation
rows by source: Customer_App 32,845 · Salesforce 18,436 · Appsmith 2,110. The metric is really
**"customer-app CBDF %"** — rename it or state the restriction on the card.

### 5. LOW — New/Repeat diverges from `dashboard/4569`

Here: `'New'` when the customer's first **completed** PTL order is at/after this order.
Card 39118 on 4569: lifetime **placed** order count > 1. Same label, different rule.

### 6. LOW — card 59439 funnel can undercount step 3

Step 1 uses `MIN(...)`, steps 2 and 3 use `MAX(...)`, then require `t2 >= t1 AND t3 >= t2`. A
session that views a quote → books → views another quote fails `t3 >= t2` and is dropped from
Book Now. Use the earliest step-N event **after** step N−1.

### 7. LOW — card 59439 internal inconsistencies

- `vehicle_id = '1159'` hardcoded as "PTL" with no comment.
- Customers resolved by normalised mobile (`ORDER BY id DESC`) while every metric card resolves by
  `uuid` → New/Repeat and Business/Personal can disagree between the funnel and the rest of the page.
- The card's timestamp-contract header comment is exemplary; the other 14 cards have no header.

### 8. LOW / latent — `NOT IN` over a nullable column

`o.customer_mobile NOT IN (SELECT DISTINCT mobile FROM … PTL_INTERNAL_USERS)` returns **zero rows**
the day any `mobile` goes NULL. 62 rows, 0 NULLs today. Use `NOT EXISTS`.

---

## Findings — `dashboard/6174`

### 9. HIGH — three cards drop the final day of the selected range

```sql
o.created_at + INTERVAL '330 mins' >= {{start_date}}::DATE
AND o.created_at + INTERVAL '330 mins' <= {{end_date}}::DATE
```

`{{end_date}}::DATE` is midnight, so the whole end day is excluded. Measured on the
`sdd_vs_ndd` cohort for 24–30 Aug 2026:

| Window as written | orders |
|---|---|
| Card **49543** (`<= end_date::DATE`) | **1,592** |
| Card **49544** (`end_date − 330min + 1 day`) | 1,751 |
| Correct IST window | 1,751 |

**9.1% of the sample silently missing.** Cards affected: **49543, 49609, 50182**.

### 10. HIGH — two identically-purposed fulfilment cards, one of them wrong

`49543 "A/B Fullfillment"` and `49544 "A/B: Fulfillment"` both sit on the dashboard and both
compute `state=3 / all`. 49543 carries the finding-9 window bug (1,592) and 49544 does not
(1,751). Whichever a reader looks at changes the answer by 9%. Retire one.
Same duplication pattern: `48947` vs `49537` (P50 allocation), `44284` vs `49550` (SLA drop),
`44409` vs `49623` (New/Repeat conversion).

### 11. MEDIUM — `is_test` is optional with no default

On 49543 / 49544 the internal-user join feeds only an optional predicate:

```sql
[[AND CASE WHEN PTL_INTERNAL_USERS.mobile IS NULL THEN 'False' ELSE 'True' END = {{is_test}}]]
```

With the filter empty, internal/test orders are **included** — the opposite of 6361, which
excludes them unconditionally.

### 12. MEDIUM — a third definition of "driver found"

| Card | Pattern | Verdict |
|---|---|---|
| 48947, 49537 | `ROW_NUMBER() … ORDER BY created_at ASC`, all rows | correct |
| 49609 | `LEFT JOIN order_vehicles ov ON … AND ov.is_active` | same defect as finding 1 |
| 6361 all cards | `is_active = TRUE` + `MAX(created_at)` | same defect as finding 1 |

### 13. MEDIUM — 10 cards on an experiment dashboard have no arm split

`33485, 34506, 43238, 43551, 43778, 44387, 44410, 44412, 44469, 48947` return pooled metrics with
no `variant_name`. Sitting beside `A/B:` cards they read as experiment results.

### 14. LOW — dead code in 49543

The `slot_intervals` CTE (a full `LEAD` window over `partload_application.slots`) is defined and
never referenced.

### 15. LOW — unqualified column + boolean-as-string

`LEFT JOIN … ptl_routes ON ptl_routes.route_id = orders.route_id AND is_active = 'True'` —
`is_active` is unprefixed (same latent pattern as kb `G-026`) and compared to a string.

### 16. LOW — quotation-level randomisation

Assignment comes from `quotations.resolved_experiments`, so the unit is the quotation, not the
customer. **Empirically 0% of customers straddle variants** for `sdd_vs_ndd` (4,061 customers
checked), so there is no live contamination — but the guarantee is incidental, not enforced.

---

## Not verified (needs a live Metabase session)

1. Dashboard-level filter **defaults** on both dashboards — this is what decides finding 2 and
   finding 11 in practice.
2. Parameter → card **mappings** (an unmapped filter is a silently inert filter; kb `G-025`
   records exactly this failure on 4569).
3. Card **placement / layout**, and whether the 6 text cards on 6361 still describe the current SQL.
4. The 19 cards on 6174 in the "other end_date handling" bucket were classified by pattern match,
   not individually read: `34506, 43551, 43778, 44284, 44387, 44409, 44410, 44412, 44469, 48947,
   49537, 49541, 49548, 49549, 49550, 49611, 49623, 49624, 49625`.

## Suggested order of work

1. Fix `vehicle_assigned` on 6361 (finding 1) — it currently reverses the P90 read.
2. Hardcode the SDD cohort on 6361 (finding 2).
3. Fix the `end_date::DATE` window on 49543 / 49609 / 50182 (finding 9).
4. Retire the duplicate fulfilment card on 6174 (finding 10).
5. Refresh the Metabase token and close out the four unverified items above.
