# metrics.md — PnM metric definitions

`PNM-M-###` blocks. Schema and rules: [CONTRIBUTING.md](./CONTRIBUTING.md). Entry point: [CONTEXT.md](./CONTEXT.md).
All blocks `last_verified: 2026-08-26`.

**Scope: 137 metrics across 18 built sections** (`ota` + `gac_ctr` + 10 more sections built
2026-09-04 — see each block's inline `last_verified` override below; this file-level date was
not refreshed for them). Every section is `readiness: prototype_only` — see `PNM-B-041`.

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
- **Covers 5 metric ids:** `leads_overall_intra_city`, `leads_app`, `leads_desktop`, `leads_mobile`, `leads_others`
- **Definition:** distinct **intra-city-only** PnM opportunities (booking-funnel leads) created in the month, split by the channel the lead arrived through. The id says so explicitly — this is not PnM's full lead volume.
- **`leads_overall` was renamed `leads_overall_intra_city`** 2026-09-04 (`owner-ruling:2026-08-26`, shipped `PNM-G-093` — CLOSED). Same query, alias only.
- ⚠ **This is NOT the governed `pnm_overall_leads`.** That metric (`PNM-S-051`, owner-approved 2026-08-11) counts the same leads **across all shifting types** and is therefore **strictly larger**. **Both are correct; they measure different populations.** Never compare or substitute one for the other, and always say which you mean.
- ⚠ **A THIRD thing is also called a "PnM lead" — mined 2026-09-07 (`PNM-G-091`), a different concept from either of the above, not a conflict.** `cge_pnm_paid_lead_attribution` (owner `CGE_ACQUISITION`, domain `CUSTOMER_ACQUISITION`) tracks **paid marketing touchpoints** (web opportunities filtered to `utm_medium='cpc'`/paid channel-source, or Adjust app installs) and attributes completed orders back to them within a 30-day window. It is **not read by this catalog**, has a completely different grain (`lead_id` = one marketing event, not one opportunity) and a completely different purpose (marketing attribution, not demand volume) — but the name collision is real. If asked for "PnM leads" and a marketing/paid/campaign angle is in the question, check which of the three is meant before answering.
- **Formula:** `leads_overall_intra_city` = `COUNT(DISTINCT opp_id)`. Each channel variant is the same count restricted to that channel bucket.
- **Counted on:** month of `opp_created_ts` — the month the lead came in (`PNM-B-020`)
- **Nano:** **INCLUDED** (`PNM-B-011`)
- **Source tables:** `PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY` + `DIM_PNM_OPPORTUNITY` (`PNM-T-001`, `PNM-T-002`)
- **Population:** `user_flag ILIKE 'normal'`, `shifting_type = 'intra_city' OR IS NULL`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`CTE_LEADS`, `AGG_LEADS`)
- **confidence: `verified`** · **readiness: `prototype_only`**
- **Channel is a `CASE`:** `source_details = 'Desktop Website'` → Desktop · `= 'Mobile Website'` → Mobile · `source IN (1,2,3)` → App · `source = 4` → Others · **`ELSE` → Mobile Website**
- ⚠ **The `ELSE` fallback is load-bearing.** A lead with an unknown or NULL `source` is counted as **Mobile Website**, not as "others" — so `leads_mobile` absorbs every unclassifiable lead. `source = 0` is Website in the enum but has no branch of its own and also lands here. No document justifies Mobile Website over an `Unknown` bucket. → `PNM-G-011`
- ⚠ **Leads allow `shifting_type IS NULL`; orders do not.** A deliberate asymmetry carried from the validated query → `PNM-T-041`
- **Reconciled:** `DECISION_LOG:V3`, 2026-05, exact (336,338 at reconciliation). Re-verified live 2026-09-04 post-rename: 336,291 — 47-lead (0.014%) drift from late-arriving/backfilled records, not from the rename (identical SQL, alias-only change; `DECISION_LOG:V8`). Values: [business.md](./business.md) snapshot.

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
- ⚠ **There is no `conversion_others`**, though `leads_others` and `orders_others` both exist. ✅ **Deliberate, not an omission (closed 2026-09-04, `PNM-G-018`)** — corroborated twice: the Argus DD carries no "Conversion — Others" row, and a separately-built "business conversion" query computes `generic_leads`/`generic_orders`/`generic_order_pct` but never a `generic_conv_pct`. Others-channel conversion is a metric nobody publishes, by consistent convention.
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
- ✅ **The denominator counts distinct CRNs — confirmed 1:1 with orders (closed 2026-09-04, `PNM-G-034`).** Checked live across 11 months / 394,174 CRN-months in this population: max orders per CRN in a month = 1, no exceptions. `COUNT(DISTINCT crn)` is a genuine order count here.
- **Reconciled:** `DECISION_LOG:V3`, 2026-05 — exact. Value in the [business.md](./business.md) snapshot (CONTRIBUTING §8).

### PNM-M-009 — `tpo_overall` ✅ `verified`
- **Definition:** all non-detractor support tickets in the month ÷ `orders_base`.
- **Formula:** `ROUND(COUNT(DISTINCT ticket_number) / NULLIF(orders_base, 0), 4)`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py`
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ **A ticket counts only if raised in the SAME IST month the allocation completed.** Tickets from any other month — earlier or later — are attributed to **no month at all**. They are not deferred; they vanish.
- ⚠ **The numerator is not restricted to the denominator's orders — confirmed material, not an edge case (closed 2026-09-04, `PNM-G-037`).** Tickets and orders are matched only by calendar month, not by whether the ticket's CRN is actually one of that month's completed orders. Measured live, 11 months / 376,631 tickets: **33.8% of all tickets belong to a CRN not in that month's `orders_base`** — 28.3% never appear as a completed order in *any* of the 11 months (in progress, cancelled, or filtered out elsewhere), 5.5% belong to a different month. **Confirmed deliberate**: an independently-sourced query citing card #47576 (the same card this section mirrors) uses the identical unrestricted month-only join — this is the intended TPO methodology, not a defect to fix.
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
- ⚠ **Attribution mechanism differs from iteration-1's description.** The shipped SQL builds two independent CTEs — orders bucketed on `completed_ts`, tickets on `hst.created_at` — and joins them at `t.month = o.month`; the tickets CTE is not restricted to the order base at all. Not the row-level filter iteration-1 describes, and — closed 2026-09-04, `PNM-G-037` — **not equivalent to it either**: 33.8% of tickets belong to a CRN outside that month's order base. Confirmed deliberate (matches card #47576's own logic), not a bug.
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
- ⚠ **`p80_vendor_accepted_to_sup_assigned` runs at roughly two days** — an order of magnitude above every other stage, in every baseline month. ✅ **Confirmed genuine 2026-09-04, not a data/definition bug** (`owner-ruling:2026-09-04`, `PNM-G-026` closed) — real operational latency between vendor-owner acceptance and supervisor assignment. Still worth flagging as an outlier stage when quoting it, just not as a suspected error.
- ⚠ **No test-order filter exists on this section.** `PNM_EXPERIENCE` carries no `user_flag`/`is_test_user` column, so p80 durations cannot filter test orders directly. Sized as a proxy 2026-09-04 via `PROD_ELDORIA.MART.PNM_ALLOCATION.IS_TEST_USER` (governed, same underlying `dim_pnm_orders.user_flag`): test-order share ran **0.024%–0.590%** of monthly order volume across 10 months (2025-11 to 2026-08), never above 0.6%. Immaterial at that magnitude — no filter added. → `PNM-G-073` (closed 2026-09-04)
- ✅ **`PNM_EXPERIENCE` is fixed as this section's source** (`owner-ruling:2026-09-04`) and is now confirmed in its final shape and form, no longer "under active construction" (`owner-ruling:2026-09-07`, `PNM-G-007` closed).
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
- ✅ **`PNM_EXPERIENCE` is fixed as this section's source** (`owner-ruling:2026-09-04`) and is now confirmed in its final shape and form, no longer "under active construction" (`owner-ruling:2026-09-07`, `PNM-G-007` closed).
- ⚠ **No test-order filter exists on this section**, for the same reason as `p80_durations` (`PNM_EXPERIENCE` carries no `user_flag`/`is_test_user`). Sized as a proxy via `PNM_ALLOCATION.IS_TEST_USER` at **0.024%–0.590%** of monthly order volume — immaterial, no filter added. → `PNM-G-073` (closed 2026-09-04)
- **Validation:** byte-identical mirror of the automation's `EDIT_ADOPTION_QUERY`; stable across Mar/Apr/May 2026 (`DECISION_LOG:V4`).

## 7. `ota` — 7 metrics · `prototype_only`

### PNM-M-040 — On-Time Arrival ✅ `verified`
- **readiness: `prototype_only`** · **Built 2026-09-04.** Formerly blocked — see history below.
- **last_verified: 2026-09-04** (inline override — the file-level 2026-08-26 date above does not cover this block, per CONTRIBUTING §2)
- **Covers 7 metric ids:**

  | metric id | means | denominator |
  |---|---|---|
  | `ota_pct` | **Headline.** % of completed orders where the `ShiftingStarted` supervisor action was within 30 min AND 2 km of pickup | `ota_total_completed_orders` |
  | `ota_total_completed_orders` | completed, non-Nano, intra-city orders in the month (the OTA base) | — |
  | `ota_on_time_orders` | orders passing the 30 min + 2 km test | — |
  | `ota_unset_orders` | orders with **no** `ShiftingStarted` action recorded — excluded from `ota_pct`'s numerator, kept in the denominator, **not** treated as delayed | — |
  | `ota_delay_orders` | orders failing the on-time test (excludes `ota_unset_orders`, its own bucket) | — |
  | `ota_delay_gt_60_mins_orders` | orders where the delay was 60+ minutes — an independent threshold, not a subset of `ota_delay_orders` by definition | — |
  | `ota_delay_gt_60_mins_pct` | % of `ota_total_completed_orders` delayed 60+ minutes | `ota_total_completed_orders` |

- **Counted on:** month of `o_completed_ts` (order completion month) — same grain the pre-build stub guessed, now for a verified reason (`PNM-G-020`'s lesson doesn't apply here: this coincidence was checked, not assumed)
- **Nano:** EXCLUDED · **Source:** Metabase card #37409 (`PNM-S-059`), mirrored in `PROD_ELDORIA.CORE.FACT_PNM_ORDERS`/`DIM_PNM_ORDERS` + `PROD_ELDORIA.RAW.PNM_APPLICATION_SUPERVISOR_ACTIONS`/`SR_LOCATION_DETAILS` (`PNM-T-116`, `PNM-T-117`)
- **Population:** `order_status = 'completed'`, `shifting_type = 'intra_city'`, `package_name NOT ILIKE 'Nano%'`
- **source_ref:** `repo@<pending>:pnm-selfserve/selfserve_nlq/sqlgen.py` (`ota_sql`), `owner-ruling:2026-09-04`, `DECISION_LOG:D11`
- **confidence: `verified`** · **readiness: `prototype_only`**
- **Validation (2026-09-04):** live-executed for 7 months (2025-10 to 2026-04), `ota_pct` 86.93%–91.49%, `ota_unset_orders` <0.3% of base each month, `ota_delay_gt_60_mins_pct` 3.6%–6.0% — sane and stable. Single-month rendered SQL for 2026-05 (`ota_total_completed_orders` = 45,414) **matches `orders_base`/TPO's denominator for the same month exactly** — an independent cross-check that the two sections' population definitions agree.
- ⚠ **This is a FOURTH OTA definition, not a resolution among the three governed dbt ones.** `PNM_EXPERIENCE.OTA_FLAG` (`PNM-T-100`, 0.5 km), `pnm_ota_capacity` (`PNM-T-100a`, 0.5 km) and `pnm_support.on_time_arrival_flag` (`PNM-T-105`, no distance test) all still exist, unedited, and disagree with the adopted 2 km. The owner chose a source outside that layer entirely.
- ⚠ **Same `RANK()`-not-`ROW_NUMBER()` tie risk as `PNM-T-100a`/`PNM-T-105`, now measured, not just latent** (`PNM-G-096`, closed 2026-09-04). Exact `event_ts_ist` ties on `ShiftingStarted` are real: 880 of 2,107,392 orders (0.042%) across `PROD_ELDORIA.RAW.PNM_APPLICATION_SUPERVISOR_ACTIONS`, always exactly 2 tied rows (never more). **Zero of those 880 fell inside the 2026-05 reconciled OTA population** (49,400 orders) — so `V3`/this section's own reconciliation is unaffected, but the risk is confirmed real and could fan-out a future month's counts. Not fixed (would need `ROW_NUMBER()` + an explicit secondary tiebreak, an unreviewed definition change to code that mirrors an owner-ruled source) — logged and bounded instead.
- **History:** originally blocked — the registry's `QUERY_OTA` referenced six columns (`scheduled_pickup_ts`, `vendor_arrived_ts`, four coordinate columns) that exist in no catalogued table. That claim was never fully re-checked (`PNM-G-043`, closed as superseded, not resolved) — it turned out not to matter, because Card #37409 computes OTA from entirely different, existing columns.

---

## 8. `gac_ctr` — 1 metric · `prototype_only`

### PNM-M-050 — Get-a-Call CTR ✅ `verified`
- **Built 2026-09-04**, the first of the 11 groups `PNM-G-071` identified as uncovered.
- **Covers 1 metric id:** `gac_ctr_pct` — % of intra-city opportunities carrying a Get-a-Call request
- **Formula:** `100 × COUNT(DISTINCT opp.id WHERE a matching OPPORTUNITIES_LATEST_LSM_SCORE row exists) ÷ COUNT(DISTINCT opp.id)`
- **Counted on:** month of `OPPORTUNITIES.created_at`, UTC shifted +5h30m to IST
- **Nano:** not applicable (this section has no package/Nano dimension) · **Source:** `PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES` + `OPPORTUNITIES_LATEST_LSM_SCORE`
- **Population:** `shifting_type = 'intra_city'`, created in the requested month
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`gac_ctr_sql`), `repo@0deb488:pnm-selfserve/reference/mbr_automation_dev_ingestion_v12.sql` (`PNM-S-060`)
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ **A "GAC request" is identified by `OPPORTUNITIES_LATEST_LSM_SCORE.opportunity_latest_score = 999`** — a sentinel value taken as given from the automation, not independently documented anywhere. If that sentinel is ever repurposed, this metric silently breaks.
- **Reconciled 2026-09-04:** single-month rendered SQL for 2026-05 = **10.54%**, exact match to the automation's open-ended query grouped and filtered to the same month. 12 months sampled (2025-10 to 2026-08), range 9.59%–10.94% — sane, stable, no anomalies.

## 9. `weekend` — 1 metric · `prototype_only`

### PNM-M-060 — Weekend order contribution ✅ `verified`
- **Built 2026-09-04** (`DECISION_LOG:D13`), mirroring the MBR automation exactly (`PNM-S-060`).
- **Covers 1 metric id:** `weekend_order_share_pct` — % of vendor-assigned, PnM, non-Nano orders whose `shifting_ts_ist` falls on Sat/Sun (`DAYOFWEEK` 0/6)
- **Counted on:** month of `SHIFTING_TS_IST` · **Nano:** EXCLUDED · **Source:** `PROD_ELDORIA.MART.PNM_EXPERIENCE` + `CORE.FACT_PNM_ORDERS`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`weekend_sql`), `PNM-S-060`
- **confidence: `verified`** · **readiness: `prototype_only`**
- **Reconciled 2026-09-04:** 2026-05 = 43.12%, within the automation's own documented ~32-51% range.

## 10. `cac_post_trip` — 1 metric · `prototype_only`

### PNM-M-061 — CAC post trip started ✅ `verified`
- **Built 2026-09-04** (`DECISION_LOG:D13`).
- **Covers 1 metric id:** `cac_post_trip_started_pct` — % of orders customer-cancelled AFTER `TRIP_STARTED_TS_IST` was set
- **Counted on:** month of `SHIFTING_TS_IST` · **Nano:** EXCLUDED · **Source:** `PROD_ELDORIA.MART.PNM_EXPERIENCE` + `PROD_CURATED.PNM_APPLICATION.CANCELLED_ORDER_EVENTS`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`cac_post_trip_sql`), `PNM-S-060`
- **confidence: `verified`** · **readiness: `prototype_only`**
- **Reconciled 2026-09-04:** 2026-05 = 2.37% — sane.

## 11. `vendor_earnings_pctl` — 6 metrics · `prototype_only`

### PNM-M-062 — Vendor earnings/orders percentiles ✅ `verified`
- **Built 2026-09-04** (`DECISION_LOG:D13`). Percentiles are over PER-VENDOR aggregates (one row per vendor after summing that vendor's month), not individual orders.
- **Covers 6 metric ids:** `active_vendor_count`, `total_order_count`, `p50_earnings_per_vendor`⚠, `p80_earnings_per_vendor`⚠, `p50_orders_per_vendor`⚠, `p80_orders_per_vendor`⚠
- ⚠ **The 4 P50/P80 ids are `--metric`-only** — their natural phrasing unavoidably contains `'p50'`/`'median'` or `'per vendor'`, both blocked by `UNSUPPORTED_TERMS`. Same treatment as `p50_trip_duration` (`D10`), not a new exception.
- **Counted on:** month of `PNM_FARE_MOVEMENT.order_updated_at_ist` · **Nano:** EXCLUDED · **Source:** `PROD_ELDORIA.MART.PNM_FARE_MOVEMENT`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`vendor_earnings_pctl_sql`), `PNM-S-060`
- **confidence: `verified`** · **readiness: `prototype_only`**
- **Reconciled 2026-09-04:** 2026-05 = 2,126 active vendors, **45,413 total orders — matches TPO's `orders_base` (45,414, `V3`) almost exactly**, a real cross-check between independently-sourced sections. P50/P80 earnings ₹89,570/₹214,684; P50/P80 orders 16/35.

## 12. `allocation` — 33 metrics · `prototype_only`

### PNM-M-063 — Allocation quality ✅ `verified`
- **Built 2026-09-04** (`DECISION_LOG:D13`) — the largest single group. Most sub-metrics split by `order_bucket` ('SPOT'/'SCHEDULED') and additionally filter `is_nano_order=0, is_test_user=0` — but the top-line `allocation_pct`/`deallocation_pct` do NOT apply the nano/test filters, an asymmetry copied verbatim from the automation.
- **Covers 33 metric ids:** `alloc_total_orders`, `allocated_orders`, `allocation_pct`, `total_spot_orders`, `allocation_pct_spot`, `total_scheduled_orders`, `allocation_pct_scheduled`, `allocation_share_via_engine_pct`, `allocation_share_via_open_pool_pct`, `deallocation_pct`, `deallocation_pct_spot`, `deallocation_pct_scheduled`, `completion_pct`, `completion_pct_spot`, `completion_pct_scheduled`, `dry_run_p75_kms_spot`, `cac_pct_spot`, `pac_pct_spot`, `poac_pct_spot`, `cac_pct_scheduled`, `pac_pct_scheduled`, `poac_pct_scheduled`, `allocation_time_p80_minutes`, `allocation_time_p80_spot_minutes`, `allocation_time_p80_within_2days_minutes`, `pct_no_vendor_before_slot`, `pct_supervisor_changed`, `pct_supervisor_changed_post_trip`, `p80_pickup_km_deviation`, `p80_drop_km_deviation`, `orders_with_more_than_2_deallocations`, `pct_orders_with_more_than_2_deallocations`, `reschedule_pct`
- **Counted on:** month of `PNM_ALLOCATION.shifting_ts_ist` · **Source:** `PROD_ELDORIA.MART.PNM_ALLOCATION` (also carries `IS_TEST_USER`/`IS_NANO_ORDER`, `PNM-G-072`)
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`allocation_sql`), `PNM-S-060`
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ CAC/PAC/PoAC exist only as SPOT/SCHEDULED splits — no overall CAC/PAC/PoAC metric in this section.
- ⚠ `allocation_time_p80_within_2days_minutes` restricts to a booking-lead-time subset (`datediff(day, order_created_ts_ist, shifting_ts_ist) <= 2`), not a duration threshold.
- **Reconciled 2026-09-04:** all 33 columns execute live for 2026-05; `allocation_pct` 97.14%, `completion_pct` 84.68%, `allocation_time_p80_minutes` 41 — sane.

## 13. `wallet` — 6 metrics · `prototype_only`

### PNM-M-064 — Wallet withdrawal/recharge ✅ `verified`
- **Built 2026-09-04** (`DECISION_LOG:D13`). Withdrawals and recharges are two INDEPENDENT queries sharing only "same month" — a vendor with one but not the other still counts in whichever half applies.
- **Covers 6 metric ids:** `withdrawals_per_vendor`⚠, `p50_withdrawal_amount`⚠, `withdrawal_failure_pct`, `recharges_per_vendor`⚠, `p50_recharge_amount`⚠, `recharge_failure_pct`
- ⚠ **4 of the 6 ids are `--metric`-only** (`'per vendor'` or `'p50'`/`'median'` guard conflict, same treatment as `p50_trip_duration`).
- **Counted on:** month of `VENDOR_WALLET_WITHDRAWAL.CREATED_AT` (withdrawals) / `PAYMENT_LINKS.created_at` (recharges) · **Source:** `PROD_CURATED.PNM_APPLICATION.VENDOR_OWNERS` + `VENDOR_WALLET_WITHDRAWAL` + `PAYMENT_LINKS` + `VENDOR_ALLOCATION_CONFIGS`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`wallet_sql`), `PNM-S-060`
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ The `VENDOR_ALLOCATION_CONFIGS` EXISTS filter (excludes Labour/Helper service types + 3 package ids) applies ONLY to withdrawals, not recharges — copied verbatim; the automation's own note confirms the join (`vac.VENDOR_ID = v.ID`) is correct as written, not a bug.
- **Reconciled 2026-09-04:** 2026-05 = 4.68 withdrawals/vendor, 3.62% withdrawal failure — sane.

## 14. `vendor_tpo_top5` — 6 metrics · `prototype_only`

### PNM-M-065 — Vendor TPO / top-5-issues ✅ `verified`
- **Built 2026-09-04** (`DECISION_LOG:D13`). **A pipeline SEPARATE from this catalog's own `tpo` section** — reads `PROD_ELDORIA.RAW.*`, not `PROD_CURATED`.
- **Covers 6 metric ids:** `vendor_tpo`, `l1_top5_issues_vendor_raised_changes_in_order_requirement`, `l1_top5_issues_vendor_raised_supervisor_reject_order`, `l1_top5_issues_vendor_raised_cancellation`, `l1_top5_issues_vendor_raised_customer_unreachable`, `l1_top5_issues_vendor_raised_payment_related`
- **Counted on:** month of allocation completion (`RAW.pnm_application_order_allocation_infos.completed_ts_ist`) · **Nano:** EXCLUDED · **Source:** `PROD_ELDORIA.RAW.PNM_APPLICATION_ORDERS`/`_ORDER_ALLOCATION_INFOS`/`_SHIFTING_REQUIREMENTS`/`SFMS_PUBLIC_HS_TICKETS`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`vendor_tpo_top5_sql`), `PNM-S-060`
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ The top-5-issues %'s denominator is **overall TPO** (all tickets), not vendor TPO — each issue's % answers "what share of OVERALL TPO", not "what share of vendor tickets". Automation's own note: an explicit owner correction, 2026-07-06.
- ⚠ Only 5 named issues are surfaced; other vendor-raised issues exist in the data but aren't emitted as metrics.
- **Reconciled 2026-09-04:** 2026-05 `vendor_tpo` = **0.2989 — matches this catalog's own, differently-sourced `tpo_vendor_raised` (0.2988, `V3`) almost exactly**, despite a completely different table set. A real cross-check, not a tautology.

## 15. `addon` — 7 metrics · `prototype_only`

### PNM-M-066 — Add-on adoption ✅ `verified`
- **Built 2026-09-04** (`DECISION_LOG:D13`).
- **Covers 7 metric ids:** `pct_orders_with_any_addon`, `pct_orders_with_packing`, `pct_orders_with_ac`, `pct_orders_with_carpentry`, `pct_orders_with_rope_pulling`, `pct_orders_with_bigger_vehicle`, `pct_orders_with_extra_labour`
- **Counted on:** month of `ORDER_CREATED_TS_IST` · **Source:** `PROD_ELDORIA.MART.PNM_EXPERIENCE`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`addon_sql`), `PNM-S-060`
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ **DELIBERATELY has no `order_status='completed'` or Nano filter** — every other `PNM_EXPERIENCE` section here has both. Automation's own note: intentional; adding those filters raises the overall rate from ~86-89% to ~97-98%, a real difference, not a bug.
- ⚠ Categories are `LOWER(ADD_ONS) LIKE` substring matches — not mutually exclusive.
- **Reconciled 2026-09-04:** 2026-05 `pct_orders_with_any_addon` = 87.86%, within the automation's documented ~86-89% range.

## 16. `completion` — 3 metrics · `prototype_only`

### PNM-M-067 — Completion score / NPS / detractors ✅ `verified`
- **Built 2026-09-04** (`DECISION_LOG:D13`). Fixed a trailing-comma syntax error present in the automation's own original SQL (owner-confirmed typo, not a definition change).
- **Covers 3 metric ids:** `completion_score_pct`, `nps`, `detractor_pct`
- **Counted on:** month of `SHIFTING_TS_IST` · **Nano:** EXCLUDED · **Source:** `PROD_ELDORIA.MART.PNM_EXPERIENCE`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`completion_sql`), `PNM-S-060`
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ `completion_score_pct`'s denominator is orders WITH A VENDOR ASSIGNED — narrower than `detractor_pct`'s, which denominates on completed orders.
- **Reconciled 2026-09-04:** 2026-05 = `completion_score_pct` 86.23%, `nps` 75.06, `detractor_pct` 4.25% — sane.

## 17. `fare` — 14 metrics · `prototype_only`

### PNM-M-068 — Fare / coupon / surge (incl. AOV) ✅ `verified`
- **Built 2026-09-04** (`DECISION_LOG:D13`). ⚠ **Computed as TWO independently-filtered sub-queries UNIONed and MAX()-aggregated**: one on `order_created_month` (counts/surge/timing, NO completed/Nano/test filter), the other on `order_updated_at_ist` (`aov`/`pct_orders_with_coupon`, WITH completed+non-Nano+non-test filters). Each metric therefore has a DIFFERENT population than its neighbors in this section — copied verbatim from the automation, not simplified, since collapsing to one filter would change what each metric measures.
- **Covers 14 metric ids:** `total_orders`, `aov`, `no_of_orders_with_surge`, `pct_orders_with_surge`, `pct_orders_positive_surge`, `pct_orders_negative_surge`, `pct_orders_with_coupon`, `orders_with_shifting_started`, `pct_cases_with_price_change_post_shifting_start`, `pct_orders_fare_increased`, `median_fare_increase_amt`⚠, `pct_orders_fare_decreased`, `median_fare_decrease_amt`⚠, `pct_edited_orders_with_fare_change`
- ⚠ `median_fare_increase_amt`/`median_fare_decrease_amt` are `--metric`-only (`'median'` guard conflict).
- **Source:** `PROD_ELDORIA.MART.PNM_FARE_MOVEMENT`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`fare_sql`), `PNM-S-060`
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ `aov`/`pct_orders_with_coupon` use `package_name NOT IN (3 literal Nano names)`, a different exclusion form than every other section's `NOT ILIKE 'Nano%'` — also copied verbatim.
- **Reconciled 2026-09-04:** 2026-05 = `total_orders` 58,821, `aov` ₹6,261, 75.09% surge, 11.99% coupon — sane.

## 18. `vendor_earnings_bucket` — 5 metrics · `prototype_only`

### PNM-M-069 — Vendor earnings distribution by bucket ✅ `verified`
- **Built 2026-09-04** (`DECISION_LOG:D13`). One automation metric name decomposes into 5 catalog ids, one per vendor bucket.
- **Covers 5 metric ids:** `revenue_pct_goldplus`, `revenue_pct_gold`, `revenue_pct_silver`, `revenue_pct_bronze`, `revenue_pct_new`
- **Counted on:** month of `order_completed_ts_ist` · **Nano:** EXCLUDED · **Source:** `PROD_ELDORIA.MART.PNM_EXPERIENCE`
- **source_ref:** `repo@851886f:pnm-selfserve/selfserve_nlq/sqlgen.py` (`vendor_earnings_bucket_sql`), `PNM-S-060`
- **confidence: `verified`** · **readiness: `prototype_only`**
- ⚠ Revenue is attributed using each vendor's single LATEST bucket in the month (by `order_completed_ts_ist DESC`), applied to ALL of that vendor's orders that month — NOT each order's own bucket at its own completion time. A vendor promoted mid-month has their entire month's revenue counted under their end-of-month bucket. Missing `vendor_bucket_type` is COALESCEd to `'New'`.
- **Reconciled 2026-09-04:** 2026-05 = GoldPlus 47.08% / Gold 13.46% / Silver 10.05% / Bronze 23.06% / New 6.35% — **sums to exactly 100.00%**.

## 19. The 167-row Argus metric universe — and how this catalog maps onto it

`../coverage-map/metric-coverage.json` catalogues **167** PnM metrics from the Argus data dictionary
(`PNM-001`…`PNM-167` — a **different namespace**, CONTRIBUTING §3).

**The mapping below was derived 2026-08-26 and closes `PNM-G-052`.** It is built by matching Argus
metric names to this catalog's ids; every row is a name-level match, not a reconciled one.
⚠ **Stale as of 2026-09-04 — predates the 82 metrics added in `DECISION_LOG:D13`.** The mapping
below only covers the 55 metrics that existed when it was derived; the 10 new sections
(`fare`, `allocation`, `wallet`, etc.) have not been cross-checked against the 167-row Argus DD.
That remapping is explicitly out of scope for D13 (stated there) — treat the %s below as the
**pre-D13 catalog only**, not the current 137-metric one.

### 19.1 Mapped — 46 of 55 catalog metrics reach 44 Argus rows (pre-D13 count)

| Argus id | Argus name | this catalog |
|---|---|---|
| `PNM-012` | No. of orders booked (Monthly) | `orders_overall` |
| `PNM-054`…`058` | Leads — Overall / App / Desktop Website / Mobile Website / Others | `leads_overall_intra_city`, `leads_app`, `leads_desktop`, `leads_mobile`, `leads_others` |
| `PNM-059`…`062` | Conversion — Overall / App / Desktop Website / Mobile Website | `conversion_overall`, `conversion_app`, `conversion_desktop`, `conversion_mobile` |
| `PNM-063`, `064` | % of orders contribution — App / Website | `pct_orders_app`, `pct_orders_website` |
| `PNM-065` | % of orders contribution — **LMS** | `pct_orders_others` ⚠ see 19.3 |
| `PNM-152`…`163` | TPO — Overall, Vendor raised, and the 5 stage pairs | `tpo_overall`, `tpo_vendor_raised`, and the 10 stage/`_customer` ids |
| **`PNM-145`** | P50/P80 trip duration (Shifting Started → Order Completed) | **`p50_trip_duration` AND `p80_trip_duration`** — one Argus row, two catalog metrics |
| **`PNM-146`** | P80 — Vendor Accepted → Supervisor Assigned | `p80_vendor_accepted_to_sup_assigned` |
| **`PNM-147`** | P80 — Supervisor Assigned → Trip Started | `p80_sup_assigned_to_trip_started` |
| **`PNM-148`** | P80 — Trip Started → Shifting Started | `p80_trip_started_to_shifting_started` |
| **`PNM-149`** | P80 — Shifting Started → Pickup Complete | `p80_shifting_started_to_pickup_complete` |
| **`PNM-150`** | P80 — Pickup Complete → **Shifting Complete** | `p80_pickup_complete_to_order_complete` ⚠ see 19.3 |
| **`PNM-039`** | % of orders edited | `pct_orders_edited` |
| **`PNM-041`** | No. of successful edits | `no_of_successful_edits` |
| **`PNM-043`** | % of support-edited orders | `pct_support_edited_orders` |
| **`PNM-045`** | Edit locations adoption | `location_adoption_pct` |
| **`PNM-051`** | % of orders where a location is modified | `pct_orders_location_modified` ⚠ see 19.3 |
| **`PNM-046`**, **`047`**, **`048`** | Edit items / add-ons / slot adoption | `items_adoption_pct`, `addons_adoption_pct`, `slot_adoption_pct` |
| **`PNM-049`** | Number of edits per order | `edits_per_order` |
| **`PNM-050`** | % of edits after shifting started | `pct_edits_after_shifting_started` |
| **`PNM-106`** | On Time Arrival % | `ota_pct` |
| **`PNM-107`** | Delay more than 60 minutes | `ota_delay_gt_60_mins_pct`, `ota_delay_gt_60_mins_orders` |
| **`PNM-031`** | Get a Call CTR | `gac_ctr_pct` |

**Bold rows are new**: the 16 Argus rows that `p80_durations` and `order_edits` reach (predates
iteration-3), `PNM-106`/`107` which the coverage map carried as `blocked` until `ota` was built
2026-09-04 (`PNM-G-024`), and `PNM-031` which was `pending` until `gac_ctr` was built the same day
(`DECISION_LOG:D12`) — all now `partial`, same as every other reconciled-but-`prototype_only` row
here. `PNM-031`'s `system: Amplitude` tag in the coverage map is stale/not the operative source —
confirmed 2026-09-04 the metric is Snowflake-only, as the automation defines it (`PNM-G-100`, closed).

### 19.2 Unmapped — 9 catalog metrics reach no Argus row

`orders_app` · `orders_desktop` · `orders_mobile` · `orders_others` — the Argus DD tracks the
**percentage** contribution per channel (`PNM-063`…`065`), never the raw channel counts.
`orders_base` — a TPO denominator, not a published metric.
`ota_total_completed_orders` · `ota_on_time_orders` · `ota_unset_orders` · `ota_delay_orders` — the
Argus DD tracks `ota_pct` and the 60-min delay rate (`PNM-106`, `107`) but none of the supporting
counts behind them, the same pattern as `orders_base`.

### 19.3 Three things the mapping independently confirms

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
