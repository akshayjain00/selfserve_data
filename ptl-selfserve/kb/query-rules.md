# query-rules.md — observed production practice for PTL queries

`Q-###` rows. Schema and rules: see [CONTRIBUTING.md](./CONTRIBUTING.md) §2 and §6.
Entry point: [CONTEXT.md](./CONTEXT.md). All rows `last_verified: 2026-08-11`.
Single source: `notion:36a9c6eaaa6d809db065efc12ecf4f42`. **Every rule here is `unverified`.**

> **This file records observed production practice, not governed definition.**
> Every rule is **tier 5** on the precedence ladder (CONTRIBUTING §6) — below the iteration-1
> catalog. Nothing here has been checked against card SQL or against the warehouse. It exists so
> these practices can be **checked**, not so they can be **quoted**.
>
> **Where a rule carries a `collides_with`, the KB row named there outranks it, and the rule may not
> be read alone.** A colliding rule without its collision is a back door around the ladder.

---

## 1. Namespace — which schema to read

| id | rule | tier | collides_with |
|---|---|---|---|
| Q-001 | Read `orders`, `ptl_routes` and `ptl_fe_events` **unprefixed**; read `order_vehicles`, `order_cancellation_reasons`, `load_details` and `batched_orders_v1` via **`prod_curated`**. Allocation-time queries specifically require `prod_curated.partload_application.order_vehicles`. The prefix is asserted to select a **different physical object**, not an alias. | 5 | `T-074` records this as an open question, not a settled fact — and the KB is separately inconsistent with itself on `ptl_internal_users` (`T-061` vs `M-005` vs `T-023`). **Do not treat this rule as resolving that.** → `G-155` |
| Q-002 | ⚠️ **This source does not follow its own Q-001.** It mandates the prefixed `ptl_internal_users` in one rule and uses the unprefixed form in four queries, stating explicitly *"same table as order queries, no prod_curated prefix"*. | 5 | Self-contradiction → `G-168`. It undercuts Q-001's premise; weigh accordingly. |

## 2. Date basis

| id | rule | tier | collides_with |
|---|---|---|---|
| Q-003 | **Weekly** reporting dates on `created_at`; **monthly** dates on `updated_at` (= completion timestamp for `state=3`). **Never mix them** — a cross-month next-day order lands in a different period under each, so the two bases disagree on the order **count**. | **3** — reconciled vs `metabase:dashboard/4632` | None. This is the one claim family that outranked a KB row: `T-033` was **corrected** to it. → `G-158` |
| Q-004 | Bound weeks with **explicit `BETWEEN` dates**. Do **not** use `DATE_TRUNC('week')` — Snowflake defaults to a Monday start and silently buckets Sunday orders into the prior week. | 5 | ⚠️ **The form this source writes it in wraps the timestamp column** — `WHERE DATE(created_at + interval '330 mins') BETWEEN …` — which **defeats micro-partition pruning** and contradicts **CONTEXT hard rule 7** and `T-030`(b). **Take the lesson, not the syntax.** Pruning-safe equivalent: keep the column bare and shift the bound — `created_at >= DATEADD('minute', -330, <start>::timestamp_ntz) AND created_at < DATEADD('minute', -330, <end+1>::timestamp_ntz)`. → `G-166`, `G-018`, `T-031`. ⚠️ Also: the source **uses the `DATE_TRUNC('week')` it bans**, in its own discount query → `G-168` |
| Q-005 | The source instructs `CONVERT_TIMEZONE('UTC','Asia/Kolkata', …)` rather than `+ interval '330 mins'` for comparisons involving **slot boundaries**. | 5 | `B-034` (**verified**, card 33519) treats the two as interchangeable and **outranks this**. Treated as a **source defect**: IST is a fixed +05:30 offset with no DST, no mechanism is given, and the source uses `+ interval '330 mins'` in its own slot-anchored clock. → `G-168`, `T-030` |

## 3. Denominators

| id | rule | tier | collides_with |
|---|---|---|---|
| Q-006 | Compute every fulfilment and cancellation ratio over **terminal orders only** — `state IN (3,4)`. Open orders (`state` 1 and 2) in the denominator understate FF and cancel %. | 5 | ⚠️ **Contradicts `M-003` (`placed = all states`), `M-005`/`M-006` (unconditional count) and `B-060` (`/demand`).** The KB metric rows are card SQL (tier 1) and **hold**; `B-060` is tier 5 and **ties**. The source names dashboard 4793 as its reconciliation, but the KB's reading of 4793's card 43237 shows an unconditional count — **the reconciliation did not happen**, which is why this is tier 5. **Both bases are defensible; numbers computed on one are not comparable to the other.** → `G-161`, `G-168` |
| Q-007 | **Triage open orders before publishing.** Count `state IN (1,2)` for the window first. In **every** case the action is the same three things — exclude them from all ratio denominators, add a scope callout, and **continue**; an open order is never a reason to suppress a report. Escalation: open orders on the **last day** of the window are *expected* (next-day advance bookings whose slot falls after the window). Open orders dated **beyond** the window end, or surviving from **a week or more earlier**, are **red flags** — surface them with a city and count breakdown, and note that earlier reports may have miscounted them. | 5 | Depends on `Q-006`'s denominator, so it inherits `G-161`. ⚠️ Also inherits `T-001a`'s unresolved state labelling — this source calls `1=placed, 2=assigned` where `T-001a` says `1=Assigned, 2=Picked_up` → `G-156` |
| Q-008 | **Sub-60s exclusion is asymmetric across metrics in this source:** fulfilment removes sub-60s cancellations from the **denominator**; cancel % removes them from the **numerator only**, leaving the terminal denominator whole. The 60 seconds is measured against `order_cancellation_reasons.created_at`. **Separately:** for advance bookings placed before 08:00, run the clock from **08:00 on the slot date**, not from order creation. | 5 | The asymmetry **corroborates** `G-002`'s two known production variants rather than adding one. The **08:00 clock is genuinely new** and is the largest in stated impact → `G-157`, `B-057`. ⚠️ The source's own mistakes register argues **both** sides of the denominator question → `G-168`. **Until `G-157` closes, any FF or cancel % must state which side of the ratio its exclusion sits on and what timestamp starts its clock, or it is not comparable to anything.** |

## 4. Join keys and silent-zero-row traps

*Every trap in this section fails **silently** — no error, just a wrong or empty answer.*

| id | rule | tier | collides_with |
|---|---|---|---|
| Q-009 | Join `batched_orders_v1` on **`order_external_id = orders.external_id`**. Joining on `order_id` returns **zero rows**, which reads as "no clubbing" rather than as an error. | 5 | `T-048` did not record this key. Row amended; no conflict. |
| Q-010 | Every `ptl_routes` join needs `AND ptl_routes.is_active = 'True'` (string, not boolean). The table carries **duplicate rows**; omitting the filter inflates city-level counts. `SELECT DISTINCT route_id` is the alternative. | 5 | `T-024` records the predicate; this adds the reason. No conflict. |
| Q-011 | Join `load_details` with `AND is_active = TRUE`. | 5 | ⚠️ The source claims **exactly one active row per order**, "safe to join without deduplication". If true, `T-004`'s declared-vs-ops weight comparison is not computable from active rows alone → `G-165` |
| Q-012 | Derive the vehicle-assignment signal from the **`is_active` predicate plus a `vehicle_name` null-check**, never from `ROW_NUMBER()`. | 5 | Matches `M-005`'s driver-found mechanic. No conflict. |
| Q-013 | Cast when crossing the mobile join: `ptl_internal_users.mobile` is numeric, `ptl_fe_events.customer_mobile_number` is a string. Also cast `variable_attr:route_id` (JSON string) with `TRY_TO_NUMBER`, and do **not** unify `vehicle_id`, which is a string in one event and a number in another. | 5 | `T-076`. No conflict. |
| Q-014 | **Zero rows is a bug report, not an answer.** Triage in this order: (1) route-name spelling — the source itself spells one route two ways; (2) a missing `is_active` filter; (3) the date range; (4) the join key (`Q-009`). **Do not conclude the data does not exist.** | 5 | Spelling inconsistency → `G-168` |

## 5. Units

| id | rule | tier | collides_with |
|---|---|---|---|
| Q-015 | `estimated_fare` and `total_fare` are **paise** — divide by 100 before display. | 5 | Corroborates `T-010`/`T-011`, both already **verified**. No upgrade (CONTRIBUTING §4). |
| Q-016 | `chargeable_weight` is **grams** — divide by 1,000, and label columns `(kg)`. **Outlier rule:** orders above **2,500 kg** are heavy-freight outliers that distort city averages; compute the average both ways, narrate the filtered figure, and state the filter in the scope line. | 5 | ⚠️ `T-012` is **`unverified` and db83-only** — no db73 card inspected references the column at all (`G-136`). This is a **second independent source** for the grams→kg scaling, which raises `G-136`'s priority but **does not upgrade `T-012`**: agreement between two unverified sources is still unverified. |

## 6. Aggregation

| id | rule | tier | collides_with |
|---|---|---|---|
| Q-017 | **Never sum city rows to produce a network total.** Recompute every total from the raw data at network level — ratios computed across all orders differ from weighted averages of city-level ratios. | 5 | A third independent derivation of `B-030`/`B-074` (aggregate-then-ratio). No conflict; strengthens both. |

## 7. Corridor map

| id | rule | tier | collides_with |
|---|---|---|---|
| Q-018 | **Clubbing is measured at CORRIDOR level, not individual route** — route-level measurement understates it. The mapping below is maintained by hand and changes; it is **not derivable** from `ptl_routes` alone. | 5 | ⚠️ `B-061` lists PTL's standard cuts as `city_name`/`vehicle_mapping`/`distance_bucket` and **does not include corridor**; `vehicle_mapping` and `distance_bucket` appear nowhere in production. Both tier 5 → neither wins. Clubbing base itself is disputed → `G-162`, `G-011` |

**Corridor → constituent routes** (as of the source's Jun 2026 revision). Recorded as a mapping
table, not as SQL — this is a business grouping, not a query.

| corridor | routes folded into it |
|---|---|
| Bangalore - Chennai | Bangalore-Chennai, Bangalore-Kanchipuram, **Bangalore-Vellore** *(moved here from Bangalore-Chittoor, Jun 2026)* |
| Bangalore - Coimbatore | Bangalore-Coimbatore, Bangalore-Tiruppur |
| Coimbatore - Bangalore | Coimbatore-Bangalore, **Tiruppur-Bangalore** *(added Jun 2026)* |
| Bangalore - Mysuru | Bangalore-Mysuru, Bangalore-Mandya, Bangalore-Chamrajnagar |
| Bangalore - Chittoor | Bangalore-Chittoor, Bangalore-Tirupati |
| Bangalore - Erode | Bangalore-Erode, Bangalore-Salem |
| Bangalore - Hubli_Dharwad | Bangalore-Hubli_Dharwad, Bangalore-Chitradurga, Bangalore-Davanagere |
| Bangalore - Hyderabad | Bangalore-Hyderabad, ⚠️ Bangalore-Kurnool *(recorded elsewhere in the same source as CLOSED)* |
| Bangalore - Chikkamagalur | Bangalore-Chikkamagalur, Bangalore-Hassan |
| Bangalore - Mangalore | Bangalore-Mangalore, Bangalore-Udupi |
| Chennai - Coimbatore | Chennai-Coimbatore, Chennai-Tiruppur, Chennai-Erode, Chennai-Salem |
| Chennai - Kanchipuram | Chennai-Kanchipuram, Chennai-Vellore, Chennai-Ranipet |
| Chennai - Puducherry | Chennai-Puducherry, ⚠️ Chennai-Tiruvannamalai and Chennai-Cuddalore *(both recorded elsewhere in the same source as CLOSED)* |
| Hyderabad - Vijayawada | Hyderabad-Vijayawada, Hyderabad-Guntur |
| *(anything else)* | falls through to its own `route_name` |

⚠️ **Three traps in this table:**
1. **`Chennai - Erode` was DISSOLVED in Jun 2026** — Erode and Salem folded into `Chennai - Coimbatore`.
   Any filter on the label `'Chennai - Erode'` now returns **zero rows**, silently.
2. **`Chennai - Puducherry` exists in the data with a TRAILING SPACE** as well as without. Both
   spellings must be matched or orders are dropped.
3. **Three routes the source records as closed still appear in this map** — Bangalore-Kurnool,
   Chennai-Tiruvannamalai, Chennai-Cuddalore. → `G-168`
