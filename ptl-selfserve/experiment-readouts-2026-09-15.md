# Experiment readouts — 15 Sep 2026

Three experiments read to a common bar: **95% significance (α=0.05, two-sided), 80% target power, one-shot final read.**
No MDE was supplied, so power is computed against the *observed* effect (owner decision) — this is
the most generous possible reading of runtime, and the real requirement is larger if the true
effect is smaller than observed.

Method: `experiment-significance` skill. Inputs extracted from Snowflake against the production
card definitions on dashboards **6361** (`ptl_partner_found_comms`, Statsig) and **6174**
(`sdd_vs_ndd`, `resolved_experiments`).

---

## ⚠️ Read this first — two findings that affect every number below

### 1. CADF as specified is structurally unmeasurable

On both Statsig experiments, `CADF = state=4 AND vehicle allocated AND cancellation_source='Customer_App'`
returns **exactly zero events in every arm and every cut**. This is not a query bug — it was
verified by full cross-tabulation of the cohort.

In experiment 1's cohort, post-allocation cancellations are sourced **`Salesforce` (1,804)** or
**`Appsmith` (88)**. The `(state=4, allocated, Customer_App)` cell does not exist. A customer-app
cancellation after a driver is found is apparently always recorded through an ops-mediated
channel instead.

**Consequence:** CADF is reported below **without** the `Customer_App` restriction. That is almost
certainly the intended guardrail. The `Customer_App` filter is retained on CBDF, as instructed.

### 2. These are ratio metrics, not proportions

Randomisation is per **customer**; CBDF / CADF / fulfillment denominate on **orders**. Testing an
orders-denominated rate as a binomial proportion understates the variance and manufactures
significance. Every rate below uses the **delta-method ratio variance** computed from per-customer
aggregates (`mean_num`, `mean_den`, `var_num`, `var_den`, `cov`). Had these been run as proportions,
several p-values would have looked roughly 2× better than they are.

---

# 1. post_booking_partner_comms (`ptl_partner_found_comms`)

**Window** 29 Jul → 13 Sep 2026 (47 days, IST, end-exclusive) · **Unit** customer ·
**Arms** `fail`=Control, `pass`=Treatment
**Cohort** Android only · Same-Day pickup slot · internal users excluded — drops ~32% of in-window orders
**Dropped** 7–28 Jul exposures, per owner (defect / relaunch on 29 Jul)

## Decision: **HOLD** — direction is favourable on every metric, but the test is ~11× underpowered and cannot reach 80% power in any practical timeframe.

## Significance now and runtime — primary (CBDF %)

| | value |
|---|---|
| Control (fail) | **9.787%** |
| Treatment (pass) | **9.141%** |
| Absolute lift | **−0.646 pp** |
| 95% CI | **[−2.178 pp, +0.885 pp]** |
| Relative lift | −6.60% (CI −22.25% to +9.05%) |
| p | **0.408** |
| Current significance (1−p) | **59.2%** — does not clear the 95% bar |
| Power now | **13.1%** |
| n per arm | 1,551 / 1,496 |
| Needed for 80% power | **17,802 per arm** |
| Days to 80% power | **~651 more days** (≈ 28 Jun 2028) at 25 customers/arm/day |

## Metric scorecard

| Metric | Role | Control | Treatment | Δ abs | Δ rel | 95% CI | p | 1−p | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| **CBDF %** | primary | 9.787% | 9.141% | −0.65 pp | −6.60% | [−2.18, +0.89] pp | 0.408 | 59.2% | ns |
| CBDF % ≤30 min | secondary | 9.351% | 8.893% | −0.46 pp | −4.90% | [−1.95, +1.04] pp | 0.548 | 45.2% | ns |
| CADF % *(all sources)* | guardrail | 26.091% | 25.822% | −0.27 pp | −1.03% | [−3.08, +2.54] pp | 0.851 | 14.9% | **not degraded** ✅ |
| Fulfillment % | guardrail | 58.997% | 60.840% | +1.84 pp | +3.12% | [−1.58, +5.27] pp | 0.292 | 70.8% | **not degraded** ✅ |

Guardrails were set with **zero tolerance** (any adverse move blocks). Neither moved adversely —
both moved in the *favourable* direction — so both pass, though neither significantly.

## Displacement and transfer — no displacement detected ✅

The failure mode to rule out: CBDF falls while CADF rises, total cancellation flat, nothing won.
That did **not** happen here. Leading with the union, as required:

| | Control | Treatment | Δ abs | p |
|---|---|---|---|---|
| **UNION — total cancellation %** | **41.003%** | **39.161%** | **−1.84 pp** | 0.292 |
| CBDF % (all sources) | 14.913% | 13.339% | −1.57 pp | 0.129 |
| CADF % (all sources) | 26.091% | 25.822% | −0.27 pp | 0.851 |

Both components fell and the union fell with them. The gain is real in direction, not displaced —
it simply isn't statistically distinguishable from zero. **Transfer check:** fulfillment rose
+1.84 pp, exactly matching the union's −1.84 pp fall. The reduction did reach the downstream
outcome; it is just not significant.

## Where the gains are — entirely in New customers

| Cut | Metric | Control | Treatment | Δ abs | Δ rel | p |
|---|---|---|---|---|---|---|
| **New** | CBDF % | 16.448% | 14.164% | **−2.28 pp** | **−13.89%** | 0.212 |
| **Repeat** | CBDF % | 7.813% | 7.672% | −0.14 pp | −1.78% | 0.862 |
| New | CBDF ≤30 min | 15.614% | 13.797% | −1.82 pp | −11.63% | 0.311 |
| Repeat | CBDF ≤30 min | 7.494% | 7.459% | −0.03 pp | −0.47% | 0.964 |
| New | Fulfillment % | 46.603% | 47.741% | +1.14 pp | +2.44% | 0.652 |
| Repeat | Fulfillment % | 62.672% | 64.668% | +2.00 pp | +3.18% | 0.329 |
| New | CADF % (all src) | 30.751% | 32.112% | +1.36 pp | +4.43% | 0.564 |
| Repeat | CADF % (all src) | 24.708% | 23.983% | −0.73 pp | −2.94% | 0.670 |

The whole of the CBDF movement sits in **New** customers (−13.9% relative); Repeat is flat
(−1.8%). That is mechanistically plausible — partner-found comms should matter most to someone
who has never seen the flow. **No Simpson's paradox**: pooled and both slices share the same sign.

⚠️ Dimension results are **directional only**. No multiplicity correction is applied; across 12
tests at α=0.05 you would expect ~0.6 false positives by chance.

## Validity gates

| Gate | Result |
|---|---|
| **SRM on true exposures** | **PASS** — 6,459 fail vs 6,482 pass (50.09%/49.91%), p=0.319 |
| **Assignment stability** | ⚠️ 1,752 / 12,941 units (13.5%) carry **multiple `group_id`s** — but **zero** straddle `pass`/`fail`. Arm integrity holds; this is a Statsig layer/rule version change, not re-randomisation. **Test is not void.** Worth raising with the Statsig config owner. |
| Arm contamination | 0 customers in both arms |
| Interference | n/a — no pooled denominator; metrics are customer-attributable |
| Peeking | n/a — one-shot final read, no interim decision taken |
| Window | 29 Jul → 13 Sep IST, end-exclusive. 7–28 Jul dropped per owner (defect/relaunch) |

---

## Reconciliation against the 1 Sep artifact ("PTL experiment readouts")

The earlier artifact reported different exp-1 numbers. **It is not in conflict with this readout** —
it answered a different question. Reproducing its exact window and cohort recovers its numbers:

| Quantity | 1 Sep artifact | Re-run today on **its** window + cohort | Match |
|---|---|---|---|
| CG customers / orders | 1,435 / 3,230 | **1,435 / 3,230** | ✅ exact |
| TG customers / orders | 1,442 / 3,222 | **1,442 / 3,222** | ✅ exact |
| CBDF ≤60 sec | 3.78% / 3.85% | **3.78% / 3.85%** | ✅ exact |
| CBDF ≤5 min | 6.75% / 6.64% | **6.75% / 6.64%** | ✅ exact |
| Fulfilment | 60.34% / 62.32% | **60.34% / 62.32%** | ✅ exact |
| CBDF ≤30 min | 9.35% / 8.63% | 9.38% / 8.63% | ~0.03 pp |
| CBDF overall | 9.66% / 8.88% | 9.81% / 8.88% | ~0.15 pp |
| CADF | 24.89% / 24.43% | 24.61% / 24.39% | ~0.28 pp |

**The three sources of difference, in order of size:**

1. **Window.** The artifact ran 29 Jul → 30 Aug (33 days). You specified 29 Jul → **13 Sep**
   today — 14 extra days, ~14% more orders.
2. **Cohort.** The artifact used **SDD only, no platform filter**. Today you added
   **Android only**, which removes ~23% of same-day orders. This is why today's CG is
   1,551 customers / 3,668 orders rather than a simple scale-up of 1,435 / 3,230.
3. **Metric set.** The artifact published a full cancellation *ladder* (≤60s, ≤5m, ≤10m, ≤15m,
   ≤30m, overall). This readout publishes **overall** and **≤30 min**, because you named those two
   as the primaries. The ladder values nest correctly against today's numbers
   (3.78 < 6.75 < 9.35 < 9.79), so the two are mutually consistent.

✅ **The artifact also computed CADF across all cancellation sources** ("CADF is all sources", stated
on its own face). My decision to drop the `Customer_App` filter from CADF therefore *matches*
established practice rather than departing from it.

### ⚠️ A finding that falls out of this reconciliation

Four quantities reproduce **exactly**; three drift by 0.03–0.28 pp. The drifting ones are precisely
the three that depend on `alloc_ist` — i.e. on `ORDER_VEHICLES.is_active = TRUE`. In CG, CADF fell
0.28 pp while CBDF rose 0.15 pp between 1 Sep and today, **on identical rows**: orders migrated from
CADF into CBDF as their vehicle assignments were deactivated after the fact.

**`is_active = TRUE` reads *current* state, not state-as-of-the-order.** A historical window
therefore returns different CBDF/CADF every time it is re-run, and the drift is one-directional
(CADF → CBDF). This is a direct consequence of keeping `is_active = TRUE`, which you ruled correct —
so it is recorded, not "fixed". Two practical implications:

- Any CBDF/CADF figure should be quoted **with the date it was computed**, or it will not reproduce.
- The drift is small here (≤0.3 pp) and affects both arms nearly symmetrically, so it does **not**
  change any arm contrast or any verdict in this document.

**Bottom line: the conclusion is identical in both readouts** — CBDF directionally down, fulfillment
directionally up, nothing significant at 95%.

---

# 2. ptl_service_comprhension

**Window** 18 Aug → 13 Sep 2026 (27 days, IST, end-exclusive) · **Unit** customer ·
**Arms** `Control` / `Test`
Note the Statsig ID is misspelled in production — `ptl_service_comprhension` is the literal string.
Amplitude-sourced metrics are **deferred**, per your instruction.

## Decision: **EXTEND** — primary is directionally positive with clean guardrails, and unlike experiment 1 this test can realistically reach power (45–145 more days).

## Significance now and runtime — primary (ptl_confirm → book_now)

Measured two ways. The **customer-grain proportion** is the methodologically correct primary: its
denominator is the randomisation unit. The session-grain ratio is the like-for-like comparison
against the existing dashboard rate.

| | Customer-grain (primary) | Session-grain ratio |
|---|---|---|
| Control | **66.026%** | 54.180% |
| Treatment | **67.383%** | 57.100% |
| Absolute lift | **+1.356 pp** | +2.920 pp |
| 95% CI | **[−1.039, +3.752] pp** | [−0.398, +6.237] pp |
| Relative lift | +2.05% | +5.39% |
| p | **0.267** | **0.084** |
| Current significance (1−p) | **73.3%** | **91.6%** |
| Power now | 19.9% | 40.7% |
| n per arm | 2,967 / 2,980 | 2,967 / 2,980 |
| Needed for 80% power | 18,909 / arm | 7,825 / arm |
| Days to 80% power | **~145 more** (≈ 6 Feb 2027) | **~45 more** (≈ 28 Oct 2026) |

Neither clears 95%. The session-grain view reaches 91.6% significance — suggestive, but it is the
weaker of the two designs (heavy-session customers are over-weighted, and Control's variance is
outlier-inflated: `var_den` 8.10 vs 2.67).

## Metric scorecard

| Metric | Role | Control | Treatment | Δ abs | Δ rel | 95% CI | p | 1−p | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| **confirm→book_now** (customer) | primary | 66.026% | 67.383% | +1.36 pp | +2.05% | [−1.04, +3.75] pp | 0.267 | 73.3% | ns |
| confirm→book_now (session) | secondary | 54.180% | 57.100% | +2.92 pp | +5.39% | [−0.40, +6.24] pp | 0.084 | 91.6% | ns |
| CBDF % *(Customer_App)* | guardrail | 21.287% | 19.954% | −1.33 pp | −6.26% | [−3.34, +0.67] pp | 0.192 | 80.8% | **not degraded** ✅ |
| CBDF % *(all sources)* | guardrail | 23.300% | 22.083% | −1.22 pp | −5.22% | [−3.27, +0.83] pp | 0.245 | 75.5% | **not degraded** ✅ |
| CADF % *(all sources)* | guardrail | 24.134% | 24.600% | **+0.47 pp** | +1.93% | [−1.39, +2.33] pp | 0.624 | 37.6% | ⚠️ adverse, ns |
| Fulfillment % | context | 52.366% | 53.247% | +0.88 pp | +1.68% | [−1.42, +3.18] pp | 0.452 | 54.8% | — |

## Displacement — partial displacement detected ⚠️

Unlike experiment 1, the two halves move in **opposite** directions here:

| | Control | Treatment | Δ abs | p |
|---|---|---|---|---|
| **UNION — total cancellation %** | **47.434%** | **46.683%** | **−0.75 pp** | 0.521 |
| CBDF % (all sources) | 23.300% | 22.083% | **−1.22 pp** | 0.245 |
| CADF % (all sources) | 24.134% | 24.600% | **+0.47 pp** | 0.624 |

CBDF improves by 1.22 pp but CADF worsens by 0.47 pp, so roughly **38% of the CBDF gain is
displaced** into later-stage cancellation rather than eliminated. The union falls only 0.75 pp and
is far from significant (p=0.52).

**This is the single most important caveat on this experiment.** If the CBDF guardrail is read
alone it looks like a clear win; the union says most of that is cancellations moving later in the
funnel, not disappearing. **Transfer check:** fulfillment rose only +0.88 pp against a union fall
of −0.75 pp, consistent with a partial, non-significant transfer.

## Where the gains are — again concentrated in New customers

| Cut | Metric | Control | Treatment | Δ abs | Δ rel | p |
|---|---|---|---|---|---|---|
| **New** | confirm→book_now | 58.857% | 60.843% | **+1.99 pp** | +3.37% | 0.189 |
| **Repeat** | confirm→book_now | 78.097% | 78.776% | +0.68 pp | +0.87% | 0.711 |
| New | CBDF % | 29.581% | 27.845% | −1.74 pp | −5.87% | 0.235 |
| Repeat | CBDF % | 10.208% | 10.294% | +0.09 pp | +0.84% | 0.927 |

Same pattern as experiment 1: the effect lives in **New** customers. Repeat customers already
convert at 78% — there is little headroom, and a comprehension intervention should not be expected
to move people who already understand the product. Pooled and slice signs agree; **no Simpson's
paradox**.

## Validity gates

| Gate | Result |
|---|---|
| **SRM on true exposures** | **PASS** — 7,609 Control vs 7,766 Test (49.49%/50.51%), p=0.866 |
| **Assignment stability** | **CLEAN** — 0 units with multiple `group_id`s, 0 arm straddlers |
| Statsig → customers join | 15,375 / 15,375 resolved (100%) |
| Timezone | `PTL_FE_EVENTS.EVENT_TIMESTAMP` is **`TIMESTAMP_LTZ`** — the 3-arg `CONVERT_TIMEZONE('UTC','Asia/Kolkata', …)` idiom double-shifts by +5:30 and was **avoided**; 2-arg form verified byte-identical to card 59439 |
| PTL scoping | `vehicleselectionscreen_confirm_clicked` is **not** PTL-only. Denominator scoped to `vehicle_id='1159'` exactly as card 59439 does; without it the denominator would be ~38% larger and contaminated with non-PTL traffic |
| Peeking | one-shot read; **experiment is still running** past the window close |
| `ptl_service_comprehension_eligible` | **Not an eligibility gate** — only 24.5% of its units appear in the main experiment and `fail` customers enter at nearly the same rate as `pass` (1,097 vs 1,276). Kept separate, not merged. |

---

# 3. sdd_vs_ndd

**Window** 6 Aug → 13 Sep 2026 (39 days, IST, end-exclusive) · **Unit** quotation ·
**Arms** `control` / `TG` · **Split** intentionally uneven ~80/20
**Source** `quotations.resolved_experiments` (not Statsig) · dashboard 6174
The `end_date::DATE` truncation bug was **not** reproduced; card **49544** used for fulfillment, not 49543.

## Decision: **KILL for Personal customers; HOLD for Business.** The primary metric cannot be read at all, and the quote→book_now guardrail is significantly breached — driven entirely by Personal.

## ❌ The primary metric (clubbing, pre vs post NDD) cannot be computed. Three independent reasons.

**1. Interference — disqualifying.** Clubbing denominates on `BATCH_ID`, which pools orders across
quotations and therefore across arms:

| | value |
|---|---|
| NDD batches mixing both arms | **676 / 2,231 = 30.3%** |
| Batched **TG** NDD orders sitting in a mixed batch | **1,150 / 1,335 = 86.1%** |
| Batched **control** NDD orders in a mixed batch | 2,140 / 5,672 = 37.7% |

Orders-per-batch is a property of the **batch**, not of an arm. With 86% of treated batched orders
sharing a batch with control orders, clubbing is not attributable to the treatment. Restricting to
arm-pure batches does not rescue it — that leaves 160 TG batches against 1,395 control, a ~10×
depletion against a 4:1 traffic ratio, and the exclusion is **correlated with the outcome itself**
(pure batches are disproportionately solo). Per method, the shared-resource metric is **not run**.

**2. No pre-period exists, so no difference-in-differences is possible.** The `sdd_vs_ndd`
experiment key first appears **2026-08-06 04:05 IST** — the window start. There is nothing before
it. The traffic split is flat ~80/20 throughout with no ramp and no structural break.

**3. The treatment is not observable in the data used to define NDD.** NDD share runs **89–92% in
both arms every single week**:

| Week | TG NDD share | CG NDD share |
|---|---|---|
| 1 | 0.925 | 0.890 |
| 2 | 0.907 | 0.906 |
| 3 | 0.890 | 0.915 |
| 4 | 0.885 | 0.909 |
| 5 | 0.912 | 0.914 |
| 6 | 0.918 | 0.908 |

If the experiment shifts orders between same-day and next-day delivery, `slots.EDD_BUFFER_IN_DAYS`
does not show it. Either the manipulation lands somewhere else, or the slot-derived delivery type
does not reflect it — **and that undermines the "NDD-only" restriction on the primary metric
regardless of the interference problem.**

## Metric scorecard — guardrails (quotation grain; denominator IS the randomisation unit)

| Metric | Role | Control | TG | Δ abs | Δ rel | 95% CI | p | 1−p | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| **quote → book_now** | guardrail | 33.762% | 31.409% | **−2.35 pp** | **−6.97%** | [−3.66, −1.05] pp | **0.0005** | **99.95%** | 🔴 **SIGNIFICANTLY WORSE** |
| quote → completed | guardrail | 17.276% | 16.678% | −0.60 pp | −3.46% | [−1.65, +0.45] pp | 0.267 | 73.3% | ns |
| Fulfillment % | guardrail | 51.169% | 53.097% | +1.93 pp | +3.77% | [−0.55, +4.41] pp | 0.128 | 87.2% | not degraded ✅ |
| quote → book_now *(session grain)* | secondary | 53.064% | 49.532% | −3.53 pp | −6.66% | [−5.35, −1.71] pp | **0.0001** | **99.99%** | 🔴 confirms the above |
| quote → completed *(session grain)* | secondary | 28.208% | 27.163% | −1.04 pp | −3.70% | [−2.67, +0.58] pp | 0.210 | 79.0% | ns |

### Guardrail tolerance test (your bar: 7.5% relative on quote→book_now)

A guardrail passes only if its CI **excludes** the tolerance — not merely if the point estimate sits inside it.

| Cut | Tolerance (7.5% rel) | Observed | 95% CI | Breach excluded? |
|---|---|---|---|---|
| Overall | −2.53 pp | −2.35 pp | [−3.66, −1.05] pp | ❌ **No** — CI reaches −3.66 pp, worse than tolerance |
| **Personal** | −2.23 pp | **−4.08 pp** | **[−5.74, −2.42] pp** | 🔴 **Definitive breach — the entire CI is beyond tolerance** |
| Business | −2.88 pp | +0.27 pp | [−1.77, +2.31] pp | ✅ Passes |

## Where the losses are — 100% of the damage is in Personal customers

| Cut | Metric | Control | TG | Δ abs | Δ rel | p | Verdict |
|---|---|---|---|---|---|---|---|
| **Personal** | quote → book_now | 29.688% | 25.609% | **−4.08 pp** | **−13.74%** | **<0.0001** | 🔴 significant, wrong way |
| **Business** | quote → book_now | 38.426% | 38.694% | +0.27 pp | +0.70% | 0.796 | flat |
| **Personal** | quote → completed | 14.786% | 12.893% | **−1.89 pp** | **−12.81%** | **0.0051** | 🔴 significant, wrong way |
| **Business** | quote → completed | 20.125% | 21.431% | +1.31 pp | +6.49% | 0.129 | ns, favourable |
| Personal | Fulfillment % | 49.805% | 50.344% | +0.54 pp | +1.08% | 0.774 | flat |
| Business | Fulfillment % | 52.374% | 55.386% | +3.01 pp | +5.75% | 0.079 | ns, favourable |

**This is a textbook segment split, and it is the most actionable finding across all three
experiments.** The pooled −6.97% is not a uniform effect — Business is completely unaffected
(+0.70%, p=0.80) while Personal loses −13.74% of quote→book_now conversion at p<0.0001, and the
loss **transfers downstream** to completed orders (−12.81%, p=0.0051). Fulfillment is unharmed in
both, which confirms this is a **demand-side loss, not an ops problem**: fewer people book, but
those who do are served just as well.

Unlike the dimension slices in experiments 1 and 2, these are **not** merely directional — Personal
quote→book_now is powered at 99.8% and survives any reasonable multiplicity correction
(p<0.0001 against 11 tests).

## Validity gates

| Gate | Result |
|---|---|
| **SRM** | **PASS** against the intended 80/20 — observed 79.91/20.09, p=0.699. (Against 50/50 it would fail catastrophically; the uneven split is by design and confirmed flat day-to-day.) |
| **Interference** | 🔴 **FAIL for clubbing** — 30.3% of NDD batches mix arms. Guardrails are unaffected (quotation-grain, no pooled denominator). |
| Contamination | **0** customers straddle variants; 0 quotations carry two variants. Assignment is customer-deterministic in practice, though the guarantee is incidental rather than enforced. |
| Pre-period / DiD | ❌ **Not computable** — no pre-period exists |
| Window | End-date truncation bug **corrected** (the buggy cards silently drop the final day, ~9% of sample) |
| Internal users | Excluded explicitly — the 6174 cards do **not** exclude them by default (`is_test` is an optional filter with no default). Dropped only 4 orders / 53 quotations here. |
| Customer master | `PROD_CURATED.OMS_PUBLIC.CUSTOMERS.frequency IN (1,2,3,4)` — confirmed used by every 6174-family card, **not** `dim_customers` |
| Batch dedup | 1,508 of 15,505 batched orders appear under more than one `BATCH_ID`; latest assignment kept |

---

# Assumptions I supplied

Everything below was **not measured** — it was assumed, and each could change a number.

| # | Assumption | Where it bites |
|---|---|---|
| 1 | **CADF computed without the `Customer_App` source filter** (exps 1–2). As specified it is identically zero. | The CADF guardrail on both Statsig experiments |
| 2 | Marginal accrual **exp 1 = 25 customers/arm/day** — derived as ~100 new exposures/day × ~24% that transact and survive the Android+Same-Day filters | Days-to-power for exp 1 (651 d) |
| 3 | Marginal accrual **exp 2 = 110/arm/day** (primary) and **125/arm/day** (guardrails) | Days-to-power for exp 2 |
| 4 | Marginal accrual **exp 3 = 151 quotations/day**, using TG as the limiting arm | Days-to-power for exp 3 |
| 5 | **No MDE supplied** (your decision) → power is computed against the *observed* effect. This is the most optimistic possible runtime; a smaller true effect needs more sample. | Every days-to-power figure |
| 6 | Guardrail tolerance **0 pp on cancellation metrics** ("no tolerance") and **7.5% relative on quote→book_now**. The 7.5% was **extended by me** to quote→completed and fulfillment, which you did not specify. | Guardrail pass/fail on exps 1–3 |
| 7 | Exp 1 arm map **pass = Treatment** (your confirmation) | Sign of every exp 1 effect |
| 8 | Exp 1: 7–28 Jul dropped as a defect/relaunch (your statement) | Exp 1 sample size |
| 9 | Exp 3 intended split assumed **80/20** — inferred from flat observed data, not from a design doc | Exp 3 SRM verdict |
| 10 | Exp 3 batch dedup tie-break = latest `(updated_at, id)` | Batch sizes, though clubbing is unreadable anyway |
| 11 | `is_active = TRUE` retained on `ORDER_VEHICLES` per your ruling. Note this is *why* CADF collapses — a post-allocation cancellation deactivates the vehicle row, so `alloc_ist` reads NULL and the order classifies as CBDF. **CBDF is therefore somewhat over-counted and CADF under-counted throughout.** | CBDF/CADF levels on exps 1–2 (not the arm *contrast*, which is affected symmetrically) |

# What would change the answer — and the next action

| Priority | Action | Why |
|---|---|---|
| 🔴 **P0** | **Investigate the Personal quote→book_now regression on sdd_vs_ndd.** −13.7% relative, p<0.0001, transferring to completed orders. | This is the only significant result across all three experiments, and it is a loss. Personal is ~53% of exp 3 quotation volume. |
| 🔴 **P0** | **Decide whether sdd_vs_ndd ships Business-only.** Business is unaffected (+0.70%) and even trends favourable on completion (+6.49%) and fulfillment (+5.75%). | A segmented rollout captures the upside without the Personal loss. |
| 🟠 P1 | **Confirm the intended CADF definition.** As written it is unmeasurable. | Both Statsig experiments currently have a vacuous cancellation guardrail. |
| 🟠 P1 | **Re-instrument clubbing at batch-arm purity, or randomise by batch/route rather than quotation.** | Clubbing is unreadable as designed and will stay unreadable on any re-run. |
| 🟠 P1 | **Establish why the sdd_vs_ndd treatment is invisible in `EDD_BUFFER_IN_DAYS`.** | If the manipulation is not where we think, the whole experiment measures something other than intended. |
| 🟡 P2 | **Exp 1: stop or redesign.** 651 days to power is not viable; relaxing the Android+Same-Day filters only reaches ~2,179/arm against 17,802 needed. | Sunk-cost avoidance. |
| 🟡 P2 | **Exp 2: extend 45–145 days**, or accept the session-grain read at 91.6% significance as directional. | It is the one test that can still reach a verdict. |
| 🟡 P2 | Raise the **1,752 `group_id` changes** on exp 1 with the Statsig config owner. | Harmless here, but it would void a future test if it ever crossed arms. |
| ⚪ P3 | **Route-level dimension for exp 3 — still outstanding.** | Deferred to keep the extraction tractable; see note below. |

> **Route-level breakdown is not yet run.** You asked for it on experiment 3. Route-level
> *clubbing* would inherit the same interference disqualification, so it is not worth computing.
> Route-level *conversion* is worth doing — it would show whether the Personal regression is
> concentrated on particular corridors. Say the word and I will run it.

# References

| Item | Source |
|---|---|
| Exposures (exps 1–2) | `PROD_ELDORIA.RAW.STATSIG_PROD_EXPOSURES`; ids `ptl_partner_found_comms`, `ptl_service_comprhension` |
| Assignment (exp 3) | `PROD_CURATED.PARTLOAD_APPLICATION.QUOTATIONS.resolved_experiments`, key `sdd_vs_ndd` |
| Metric definitions, exps 1–2 | Metabase card **54215** (dashboard 6361), funnel card **59439** |
| Metric definitions, exp 3 | Metabase cards **49544** (fulfillment), **49609**, **49623/49624/49625** (conversions) — dashboard 6174 |
| Card SQL source of truth | `PROD_ELDORIA.raw.metabase_public_report_card` |
| Known dashboard defects | `qc-dashboards-6361-6174.md` (this repo, 2026-08-31) |
| Assignment stability | 0 arm straddlers on both Statsig experiments; 1,752 `group_id` changes on exp 1 |
| Internal-user exclusion | `PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS` |
| Method | `experiment-significance` skill; ratio metrics use delta-method variance |

⚠️ **No multiplicity correction is applied anywhere.** Across ~30 tests at α=0.05, expect ~1.5
false positives by chance. The exp 3 Personal results (p<0.0001) survive any reasonable
correction; nothing else in this document is significant to begin with.
