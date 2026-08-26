# metrics.md — PnM metric definitions

`PNM-M-###` blocks. Schema and rules: [CONTRIBUTING.md](./CONTRIBUTING.md). Entry point: [CONTEXT.md](./CONTEXT.md).
All blocks `last_verified: 2026-08-26`.

**Scope: 47 metrics across 6 built sections**, plus `ota` (blocked, 0 queryable metrics). Every
section is `readiness: prototype_only` — see `PNM-B-041`.

> **What `verified` attests to here.** It means *"this is what the prototype computes"*, read from
> `sqlgen.py` / `metrics_registry.py` at the cited SHA. `DECISION_LOG:V3`/`V4` showed the prototype
> reproduces the owner's validated automation **exactly — for the months and metrics actually
> reconciled.** Outside that slice the equality is extrapolation (`PNM-G-004`). **`verified` is not
> `stakeholder_ready`** (CONTRIBUTING §7). No query was run to build this KB.

> **Before quoting any number:** apply `PNM-B-030` (aggregate-then-ratio) and **state the date basis**
> (`PNM-B-020`) — each section counts on a different date and they are not interchangeable.

> **For the 40 `source:"sql"` metrics, the id IS the SQL column alias, lowercase.** `ask.py`
> lowercases every result column and does `row.get(metric_id)`, so an id that does not match its
> alias cannot resolve (`DECISION_LOG:D9`). **The 7 `derived` ids are not SQL aliases at all** — they
> are computed in Python from the funnel query's counts via `row[numerator]` / `row[denominator]`. The iteration-1 catalog's `_mins`-suffixed names exist nowhere in the shipped
> system (`PNM-G-040`).

---

## 1. `leads` — 5 metrics · `prototype_only`

### PNM-M-001 — Leads, intra-city (overall and by channel) ✅ `verified`
- **Covers 5 metric ids:** `leads_overall`, `leads_app`, `leads_desktop`, `leads_mobile`, `leads_others`
- **Definition:** distinct **intra-city** PnM opportunities (booking-funnel leads) created in the month, split by the channel the lead arrived through.
- ⚠ **`leads_overall` is to be renamed `leads_overall_intra_city`** (`owner-ruling:2026-08-26`). **The rename is ruled but not yet shipped** — in code the id is still `leads_overall` → `PNM-G-093`.
- ⚠ **This is NOT the governed `pnm_overall_leads`.** That metric (`PNM-S-051`, owner-approved 2026-08-11) counts the same leads **across all shifting types** and is therefore **strictly larger**. **Both are correct; they measure different populations.** Never compare or substitute one for the other, and always say which you mean.
- **Formula:** `leads_overall` = `COUNT(DISTINCT opp_id)`. Each channel variant is the same count restricted to that channel bucket.
- **Counted on:** month of `opp_created_ts` — the month the lead came in (`PNM-B-020`)
- **Nano:** **INCLUDED** (`PNM-B-011`)
- **Source tables:** `PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY` + `DIM_PNM_OPPORTUNITY` (`PNM-T-001`, `PNM-T-002`)
- **Population:** `user_flag ILIKE 'normal'`, `shifting_type = 'intra_city' OR IS NULL`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`CTE_LEADS`, `AGG_LEADS`)
- **confidence: `verified`** · **readiness: `prototype_only`**
- **Channel is a `CASE`:** `source_details = 'Desktop Website'` → Desktop · `= 'Mobile Website'` → Mobile · `source IN (1,2,3)` → App · `source = 4` → Others · **`ELSE` → Mobile Website**
- ⚠ **The `ELSE` fallback is load-bearing.** A lead with an unknown or NULL `source` is counted as **Mobile Website**, not as "others" — so `leads_mobile` absorbs every unclassifiable lead. `source = 0` is Website in the enum but has no branch of its own and also lands here. No document justifies Mobile Website over an `Unknown` bucket. → `PNM-G-011`
- ⚠ **Leads allow `shifting_type IS NULL`; orders do not.** A deliberate asymmetry carried from the validated query → `PNM-T-041`
- **Reconciled:** `DECISION_LOG:V3`, 2026-05, exact. Values: [business.md](./business.md) snapshot.

## 2. `orders` — 5 metrics · `prototype_only`

### PNM-M-002 — Orders (overall and by channel) ✅ `verified`
- **Covers 5 metric ids:** `orders_overall`, `orders_app`, `orders_desktop`, `orders_mobile`, `orders_others`
- **Definition:** distinct non-Nano PnM bookings created in the month, attributed to the channel of the lead that produced them.
- **Formula:** `orders_overall` = `COUNT(DISTINCT order_id)`. Channel variants restrict to that bucket.
- **Counted on:** month of `o_created_ts` — the month the customer booked (`PNM-B-020`)
- **Nano:** **EXCLUDED** (`PNM-B-012`)
- **Source tables:** `FACT_PNM_ORDERS` + `DIM_PNM_ORDERS` + `MART.PNM_CUSTOMERS` (inner join, acts as a filter), plus the opportunity tables for channel
- **Population:** `user_flag ILIKE 'normal'`, `shifting_type = 'intra_city'`, `crn LIKE '%PNM%'`, `package_name NOT ILIKE 'Nano%' OR IS NULL`, deduped to one row per `order_id`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`CTE_ORDERS`, `AGG_ORDERS`)
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ **ALL STATUSES COUNT.** There is no cancelled filter, so `orders_overall` **includes orders later cancelled**. This is deliberate, from the validated query (`DECISION_LOG:D5`). ⚠ iteration-1 states the opposite — that `status != 4` excludes cancelled orders → `PNM-G-032`
- ⚠ **Channel is inherited from the originating lead via `sr_id`.** An order with no matching lead falls into the `ELSE` bucket and is counted as **Mobile Website** — same trap as `PNM-M-001`. → `PNM-G-011`
- ⚠ **Dedup is per `order_id`, not per SR**, using `ORDER BY fpo.opp_id DESC NULLS LAST` on the opportunity-join fan-out. The registry calls this "deterministic" — deterministic is not the same as correct, and nothing states why the highest `opp_id` is the right opportunity. → `PNM-G-013`. iteration-1 says first-order-per-`sr_id` → `PNM-G-031`
- ⚠ **The Nano filter keeps NULL-package orders** (`OR package_name IS NULL`). `D4` rules on Nano and is silent on nulls → `PNM-G-012`
- **Reconciled:** `DECISION_LOG:V3`, 2026-05, exact.

## 3. `derived` — 7 metrics · `prototype_only`

### PNM-M-005 — Conversion (overall and by channel) ✅ `verified`
- **Covers 4 metric ids:** `conversion_overall`, `conversion_app`, `conversion_desktop`, `conversion_mobile`
- **Definition:** the share of a month's leads that became bookings in that same month.
- **Formula:** `100 × orders_<channel> ÷ leads_<channel>`, computed **in Python from raw counts** (`PNM-B-030`)
- **Counted on:** calendar month; both sides same month (`PNM-B-020`)
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/metrics_registry.py`
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ **This is PERIOD conversion, not cohort conversion.** Orders created in month M ÷ leads created in month M. A May lead that books in June counts in **June's** numerator and **May's** denominator. It is not "what happened to May's leads".
- ⚠ **Carries the Nano asymmetry** (`PNM-B-013`): non-Nano orders ÷ Nano-inclusive leads. It reads **lower** than a like-for-like ratio, and lower than card #30311, which strips Nano from both sides (`PNM-S-010`).
- ⚠ **There is no `conversion_others`**, though `leads_others` and `orders_others` both exist. Absent by design or by omission — nothing says which. → `PNM-G-018`
- **Reconciled:** `conversion_overall` at `DECISION_LOG:V3`, 2026-05, exact. The three channel conversions were **not individually reconciled**.

### PNM-M-006 — Order mix ✅ `verified`
- **Covers 3 metric ids:** `pct_orders_app`, `pct_orders_website`, `pct_orders_others`
- **Definition:** the share of a month's bookings arriving through each channel group.
- **Formula:** `100 × orders_app ÷ orders_overall` · `100 × (orders_desktop + orders_mobile) ÷ orders_overall` · `100 × orders_others ÷ orders_overall`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/metrics_registry.py`
- **confidence: `verified`** · **readiness: `prototype_only`**
- **note:** `pct_orders_website` deliberately combines desktop and mobile web. Inherits `PNM-M-002`'s `ELSE`-bucket trap. Not individually reconciled in V3.

## 4. `tpo` — 13 metrics · `prototype_only`

**TPO = tickets per order.** A quality/pain measure: **higher is worse** (`PNM-B-052`).

### PNM-M-008 — `orders_base` (the TPO denominator) ✅ `verified`
- **Definition:** distinct non-Nano intra-city PnM CRNs whose allocation completed in the month.
- **Formula:** `COUNT(DISTINCT a.crn)` where the allocation is active and completed in the month
- **Counted on:** month of **allocation completion** — `order_allocation_infos.completed_ts` + 330 min → IST
- **Source tables:** `PROD_CURATED.PNM_APPLICATION.ORDERS` + `ORDER_ALLOCATION_INFOS` + `SHIFTING_REQUIREMENTS`
- **Population:** `crn LIKE '%PNM%'`, `is_active = true`, `package_name NOT ILIKE '%Nano%'`, `shifting_type = 'intra_city'`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`tpo_sql`)
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ **The denominator counts distinct CRNs, not orders.** The CRN↔order cardinality is stated nowhere, so whether this equals an order count is unestablished. iteration-1 describes it as an order count → `PNM-G-034`
- **Reconciled:** `DECISION_LOG:V3`, 2026-05 — exact. Value in the [business.md](./business.md) snapshot (CONTRIBUTING §8).

### PNM-M-009 — `tpo_overall` ✅ `verified`
- **Definition:** all non-detractor support tickets in the month ÷ `orders_base`.
- **Formula:** `ROUND(COUNT(DISTINCT ticket_number) / NULLIF(orders_base, 0), 4)`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py`
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ **A ticket counts only if raised in the SAME IST month the allocation completed.** Tickets from any other month — earlier or later — are attributed to **no month at all**. They are not deferred; they vanish.
- ⚠ **Detractor tickets are excluded everywhere**, via `COALESCE(raised_by,'') != 'Detractor'` — **exact equality**. iteration-1 records the pipeline's filter as `LOWER(raised_by) LIKE '%detractor%'`; the two disagree on values like `Detractor-Customer` and on case. → `PNM-G-015`
- ⚠ **Rounded to 4dp**; V3 compared against the automation's 2dp and asserts they "round identically" — an unproven precision claim at the reconciliation boundary → `PNM-G-016`
- **Reconciled:** `DECISION_LOG:V3`, 2026-05 — rounds identically to the automation's 2dp figure. Values in the [business.md](./business.md) snapshot.

### PNM-M-010 — `tpo_vendor_raised` ✅ `verified`
- **Definition:** tickets raised by vendors ÷ `orders_base`.
- **Numerator predicate:** `raised_by ILIKE 'Vendor%'`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py`
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ **This is a PREFIX match**, not the IN-list `('Vendor-Owner','Vendor-Supervisor')` iteration-1 specifies. It admits any future `Vendor-*` value the IN-list would exclude. → `PNM-G-036`
- ⚠ **Do not read this as "TPO broken down per vendor."** It means *tickets raised by vendors*. Per-vendor splits are refused (`PNM-B-032`).
- **Reconciled:** `DECISION_LOG:V3`, 2026-05 — exact. Value in the [business.md](./business.md) snapshot.

### PNM-M-011 — TPO by order stage ✅ `verified`
- **Covers 10 metric ids:** `tpo_pre_trip`, `tpo_trip_shift`, `tpo_pickup`, `tpo_completed`, `tpo_cancelled`, and each one's `_customer` twin.
- **Definition:** tickets raised while the order was at a given stage ÷ `orders_base`. Each `_customer` twin adds `raised_by = 'Customer'`.
- **Stage comes from `order_status_when_ticket_created`** — the order's state **at the moment the ticket was raised**, not its state now:

  | metric id | stage predicate |
  |---|---|
  | `tpo_pre_trip` | status ∈ `open`, `supervisor_assigned`, `supervisor_accepted`, `vendor_accepted` |
  | `tpo_trip_shift` | status ∈ `trip_started`, `shifting_started` |
  | `tpo_pickup` | status = `pickup_completed` |
  | `tpo_completed` | status = `completed` |
  | `tpo_cancelled` | status = `cancelled` |

- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py`
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ **`tpo_cancelled` needs care.** It counts tickets by the order's status *at ticket creation*, which is independent of the order base — and the base has **no** status filter (`PNM-M-002`). The two are not the same population.
- **Not individually reconciled** in V3 — the section reconciled at `tpo_overall` and `tpo_vendor_raised` only.
- ⚠ **Attribution mechanism differs from iteration-1's description.** The shipped SQL builds two independent CTEs — orders bucketed on `completed_ts`, tickets on `hst.created_at` — and joins them at `t.month = o.month`; the tickets CTE is not restricted to the order base at all. Same aggregate for a single month, but not the row-level filter iteration-1 describes. → `PNM-G-037`
- ⚠ **Tickets join to orders on `CRN`, not `order_id`** — `HS_TICKETS` has no `ORDER_ID` column. iteration-1's stated `order_id` join could never have run. → `PNM-G-035`, `PNM-T-032`

## 5. `p80_durations` — 7 metrics · `prototype_only`

**Unit: minutes.** P80 = 80% of moves were faster than this; the slowest 20% were slower (`PNM-B-058`).

### PNM-M-020 — Stage durations, P80 ✅ `verified`
- **Covers 6 metric ids:**

  | metric id | measured between | NL-exposed? |
  |---|---|---|
  | `p80_trip_duration` | `SHIFTING_STARTED_TS_IST` → `ORDER_COMPLETED_TS_IST` | yes |
  | `p80_sup_assigned_to_trip_started` | `SUPERVISOR_ACCEPTED_TS_IST` → `TRIP_STARTED_TS_IST` | yes |
  | `p80_trip_started_to_shifting_started` | `TRIP_STARTED_TS_IST` → `SHIFTING_STARTED_TS_IST` | yes |
  | `p80_shifting_started_to_pickup_complete` | `SHIFTING_STARTED_TS_IST` → `PICKUP_COMPLETED_TS_IST` | yes |
  | `p80_pickup_complete_to_order_complete` | `PICKUP_COMPLETED_TS_IST` → `ORDER_COMPLETED_TS_IST` | yes |
  | `p80_vendor_accepted_to_sup_assigned` | `VENDOR_OWNER_ACCEPTED_TS_IST` → `SUPERVISOR_ACCEPTED_TS_IST` | **no** — `--metric` only |

- **Formula:** `ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', <start>, <end>)), 1)`
- **Counted on:** month of `SHIFTING_TS_IST` — the month the move was scheduled (`PNM-B-020`)
- **Nano:** EXCLUDED · **Source:** `PROD_ELDORIA.MART.PNM_EXPERIENCE` (`PNM-T-005`)
- **Population:** `ORDER_STATUS = 'completed'`, `SHIFTING_TYPE = 'intra_city'`, `PACKAGE_NAME NOT ILIKE 'Nano%'`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/tests_output/rendered_p80_durations_2026-05.sql`, `DECISION_LOG:D8`
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ **Each stage's percentile can be over a DIFFERENT set of orders.** An order missing either endpoint drops out of *that stage only* — `PERCENTILE_CONT` silently ignores NULL diffs. The stages are not a decomposition of a common denominator and **must not be summed**.
- ⚠ **`p80_vendor_accepted_to_sup_assigned` runs at roughly two days** — an order of magnitude above every other stage, in every baseline month. **Flag it rather than quoting it as a normal stage time.** → `PNM-G-026`
- **Validation:** `DECISION_LOG:V4` — bit-exact vs the baseline CSV for 2025-10/11/12; drift ≤0.84% on recent months, inside the ±2.5% rule. Drift is the mart backfilling, not a logic error. → `PNM-G-025`

### PNM-M-021 — The "Supervisor Assigned" quirk ⚠ replicate, do not fix
- **Statement:** every duration labelled **"Supervisor Assigned"** is measured from **`SUPERVISOR_ACCEPTED_TS_IST`**, not `SUPERVISOR_ASSIGNED_TS_IST` — even though both columns exist on `PNM_EXPERIENCE`.
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/tests_output/rendered_p80_durations_2026-05.sql`, `repo@851886f:pnm-selfserve/iteration-3-p80-orderedits-spec.md` §6
- **confidence: `verified`**
- **Affects:** `p80_sup_assigned_to_trip_started` and `p80_vendor_accepted_to_sup_assigned`.
- **Copied deliberately from the validated automation. Must not be "fixed"** (`PNM-B-038`) — correcting it is a definition change and the owner's call.
- **A second label quirk:** `p80_pickup_complete_to_order_complete` is labelled "… → Shifting Complete" in the MBR sheet but measures pickup → **order** complete. There is no shifting-complete timestamp.

### PNM-M-022 — `p50_trip_duration` ✅ `verified` · **not NL-exposed**
- **Definition:** the median (typical) move duration, `SHIFTING_STARTED_TS_IST` → `ORDER_COMPLETED_TS_IST`.
- **Formula:** as `PNM-M-020` with `PERCENTILE_CONT(0.5)`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/tests_output/rendered_p80_durations_2026-05.sql`, `DECISION_LOG:D10`
- **confidence: `verified`** · **readiness: `prototype_only`**
- **Emitted and reconciled but deliberately unreachable in plain English.** It is needed for exact reconciliation against the baseline CSV, which carries a P50. `median` / `p50` are refused outright by the closed-world guard (`PNM-B-032`); it is reachable only via `ask.py --metric`.
- **Property check:** `p50 ≤ p80_trip_duration` holds in all 8 baseline months (`DECISION_LOG:V4`).

> ⚠ **Two p80 metrics are computed and reconciled but have no natural-language route:**
> `p50_trip_duration` (blocked by the `p50`/`median` guard) and `p80_vendor_accepted_to_sup_assigned`
> (given **no aliases**; `resolve()` skips zero-alias metrics entirely). The original reason recorded
> for hiding the vendor metric — *"its name contains 'vendor', so it hits `UNSUPPORTED_TERMS`"* — was
> **found to be false**: bare `vendor` is not in the guard list, the guard runs on the question rather
> than the metric name, and adding it would break `tpo_vendor_raised`. **The owner's decision on
> whether to expose it is open, leaning ~55% keep hidden** (`DECISION_LOG:D10`) → `PNM-G-027`.

## 6. `order_edits` — 10 metrics · `prototype_only`

An "edit" is a change to a booking after it was made — address, item list, add-ons, or time slot.
High support-edit rates mean customers could not self-serve.

### PNM-M-030 — Edit adoption ✅ `verified`
- **Covers 10 metric ids:**

  | metric id | means | denominator |
  |---|---|---|
  | `pct_orders_edited` | % of bookings changed at least once (`IS_MODIFICATION_DONE = 'Yes'`) | `total_orders` |
  | `no_of_successful_edits` | total edits — **a count, not a %** | — |
  | `pct_support_edited_orders` | % where support had to make the change (`HAS_SUPPORT_EDIT = 1`) | `total_orders` |
  | `location_adoption_pct` | % where an address was changed (`HAS_LOCATION_EDIT = 1`) | `total_orders` |
  | `pct_orders_location_modified` | **identical value to the row above** | `total_orders` |
  | `items_adoption_pct` | % where the item list changed (`HAS_ITEMS_EDIT = 1`) | `total_orders` |
  | `addons_adoption_pct` | % where add-ons changed (`HAS_ADDONS_EDIT = 1`) | `total_orders` |
  | `slot_adoption_pct` | % where the time slot changed (`HAS_SLOT_EDIT = 1`) | `total_orders` |
  | `edits_per_order` | average edits per booking | `total_orders` |
  | `pct_edits_after_shifting_started` | % of **edits** made after the move began | ⚠ `no_of_successful_edits` |

- **Counted on:** month of `ORDER_CREATED_TS_IST` — the month the customer booked (`PNM-B-020`)
- **Nano:** EXCLUDED · **Source:** `PROD_ELDORIA.MART.PNM_EXPERIENCE` (`PNM-T-005`)
- **Population:** `ORDER_STATUS = 'completed'`, `SHIFTING_TYPE = 'intra_city'`, `PACKAGE_NAME NOT ILIKE 'Nano%'`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/tests_output/rendered_order_edits_2026-05.sql`, `DECISION_LOG:D8`
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ **`location_adoption_pct` and `pct_orders_location_modified` are the same number under two names** — one calculation, duplicated from the MBR automation on purpose. If both are asked for, say they are identical.
- ⚠ **`pct_edits_after_shifting_started` is the only metric dividing by the edit count rather than the order count — so it CAN EXCEED 100%.** That is not a bug.
- ⚠ **No denominator is published.** Unlike TPO's `orders_base`, these percentages ship with **no visible sample size**, by owner decision (`DECISION_LOG:D8`, iteration-3 §12). The month's `total_orders` is recorded in the [business.md](./business.md) snapshot for context only.
- **Type traps, both confirmed live:** `IS_MODIFICATION_DONE` is compared to the **string `'Yes'`**; the `HAS_*_EDIT` flags to the **number `1`**. The Notion schema guide says `IS_MODIFICATION_DONE` is BOOLEAN — it is TEXT, and a boolean comparison would fail. → `PNM-T-023`, `PNM-G-023`
- **Validation:** byte-identical mirror of the automation's `EDIT_ADOPTION_QUERY`; stable across Mar/Apr/May 2026 (`DECISION_LOG:V4`).

## 7. `ota` — BLOCKED, 0 queryable metrics

### PNM-M-040 — On-Time Arrival ⛔ `blocked`
- **readiness: `blocked`** · **This section cannot be answered. Do not produce a number for it.**
- **Why:** the original query referenced six columns — `scheduled_pickup_ts`, `vendor_arrived_ts`, and four coordinate columns. **Two were checked by name against the Data Catalog and exist in no catalogued table**; the staging table materialises none of the six. → `PNM-G-043`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/metrics_registry.py`, `repo@851886f:pnm-selfserve/iteration-2-readiness-ledger.md` §3
- **confidence: `verified`** (that it is blocked)
- **Two governed candidates now exist, and they agree on the thresholds.** `PNM_EXPERIENCE.OTA_FLAG` (`PNM-T-100`) and the `pnm_ota_capacity` mart (`PNM-T-100a`) both implement **30 minutes + 500 m** — settling the old 500 m-vs-2 km dispute in Notion's favour. ⚠ **They differ on the event**: shifting-started vs a vendor action with GPS. ⚠ `pnm_ota_capacity` also publishes `ota_percentage` **by city and slot**, which no catalog metric can do. **The section stays blocked until the owner rules which event defines PnM's OTA** → `PNM-G-024`
- ⚠ The registry's stale `base_population` for this section still reads "completed (`status=2`)" — a **numeric** `status` exists on none of the re-pointed tables (`PROD_CURATED…ORDERS.STATUS` is TEXT; the governed `FACT_PNM_ORDERS` has no `status` at all), so the predicate cannot execute as written → `PNM-G-021`, `PNM-T-033`
- **Until the owner rules, OTA questions get the gap, not a number.**

---

## 8. Metrics that exist in the MBR automation but NOT in this catalog

The owner's automation runs **14 sections**; only **6** are catalogued above. Also present there —
and **not answerable from this KB** — are:

fare / coupon / surge (including **AOV**) · vendor earnings percentiles · allocation quality
(allocation %, deallocation %, completion %, allocation TAT p80, CAC / PAC / PoAC) · wallet
withdrawals and recharges · vendor TPO top-5 issues · add-on adoption · completion score · weekend
contribution · Get-a-Call CTR · CAC-post-trip-started.

**If asked for any of these, treat them as not in knowledge.** Several have dashboards →
[sources.md](./sources.md). → `PNM-G-071`

## 9. The 167-row Argus metric universe — and how this catalog maps onto it

`../coverage-map/metric-coverage.json` catalogues **167** PnM metrics from the Argus data dictionary
(`PNM-001`…`PNM-167` — a **different namespace**, CONTRIBUTING §3).

**The mapping below was derived 2026-08-26 and closes `PNM-G-052`.** It is built by matching Argus
metric names to this catalog's ids; every row is a name-level match, not a reconciled one.

### 9.1 Mapped — 42 of 47 catalog metrics reach 41 Argus rows

| Argus id | Argus name | this catalog |
|---|---|---|
| `PNM-012` | No. of orders booked (Monthly) | `orders_overall` |
| `PNM-054`…`058` | Leads — Overall / App / Desktop Website / Mobile Website / Others | `leads_overall`, `leads_app`, `leads_desktop`, `leads_mobile`, `leads_others` |
| `PNM-059`…`062` | Conversion — Overall / App / Desktop Website / Mobile Website | `conversion_overall`, `conversion_app`, `conversion_desktop`, `conversion_mobile` |
| `PNM-063`, `064` | % of orders contribution — App / Website | `pct_orders_app`, `pct_orders_website` |
| `PNM-065` | % of orders contribution — **LMS** | `pct_orders_others` ⚠ see 9.3 |
| `PNM-152`…`163` | TPO — Overall, Vendor raised, and the 5 stage pairs | `tpo_overall`, `tpo_vendor_raised`, and the 10 stage/`_customer` ids |
| **`PNM-145`** | P50/P80 trip duration (Shifting Started → Order Completed) | **`p50_trip_duration` AND `p80_trip_duration`** — one Argus row, two catalog metrics |
| **`PNM-146`** | P80 — Vendor Accepted → Supervisor Assigned | `p80_vendor_accepted_to_sup_assigned` |
| **`PNM-147`** | P80 — Supervisor Assigned → Trip Started | `p80_sup_assigned_to_trip_started` |
| **`PNM-148`** | P80 — Trip Started → Shifting Started | `p80_trip_started_to_shifting_started` |
| **`PNM-149`** | P80 — Shifting Started → Pickup Complete | `p80_shifting_started_to_pickup_complete` |
| **`PNM-150`** | P80 — Pickup Complete → **Shifting Complete** | `p80_pickup_complete_to_order_complete` ⚠ see 9.3 |
| **`PNM-039`** | % of orders edited | `pct_orders_edited` |
| **`PNM-041`** | No. of successful edits | `no_of_successful_edits` |
| **`PNM-043`** | % of support-edited orders | `pct_support_edited_orders` |
| **`PNM-045`** | Edit locations adoption | `location_adoption_pct` |
| **`PNM-051`** | % of orders where a location is modified | `pct_orders_location_modified` ⚠ see 9.3 |
| **`PNM-046`**, **`047`**, **`048`** | Edit items / add-ons / slot adoption | `items_adoption_pct`, `addons_adoption_pct`, `slot_adoption_pct` |
| **`PNM-049`** | Number of edits per order | `edits_per_order` |
| **`PNM-050`** | % of edits after shifting started | `pct_edits_after_shifting_started` |

**Bold rows are new**: the 16 Argus rows that `p80_durations` and `order_edits` reach, which the
coverage map still shows as `pending` because it predates iteration-3.

### 9.2 Unmapped — 5 catalog metrics reach no Argus row

`orders_app` · `orders_desktop` · `orders_mobile` · `orders_others` — the Argus DD tracks the
**percentage** contribution per channel (`PNM-063`…`065`), never the raw channel counts.
`orders_base` — a TPO denominator, not a published metric.

### 9.3 Three things the mapping independently confirms

1. **`PNM-045` and `PNM-051` are two Argus rows for one computation** — "Edit locations adoption" and
   "% of orders where a location is modified". This is exactly the `location_adoption_pct` /
   `pct_orders_location_modified` duplicate pair in `PNM-M-030`, so **the duplication originates
   upstream in the MBR definition set, not in this prototype's code.**
2. **`PNM-150` is named "Pickup Complete → Shifting Complete" in the Argus DD** — the same misleading
   label `PNM-M-021` records, against a metric that measures pickup → **order** complete. **The label
   quirk is inherited, not introduced.**
3. **Argus has no "Conversion — Others" row**, exactly as this catalog has no `conversion_others`.
   The absence is mirrored on both sides, which is evidence it is **deliberate** rather than an
   omission → materially advances `PNM-G-018`.

⚠ **`PNM-065` is the one uncertain mapping.** Argus calls it "% of orders contribution — **LMS**";
this catalog calls it `pct_orders_others`. The governed `lead_channel` dimension describes
`source = 4` → `Generic` as **"Generic (LMS/broker/other)"**, which supports the equation — but LMS
itself is still expanded nowhere (`PNM-G-062`). Treat the mapping as probable, not settled.

**The coverage map is a projection of this KB, not a progress tracker** — never edit it to say a
metric shipped; fix the KB, then re-derive it.
