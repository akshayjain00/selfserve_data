# GAPS.md — open questions, conflicts, and uncovered surface

`G-###` rows, append-only. Adding/closing rules: [CONTRIBUTING.md](./CONTRIBUTING.md) §8.
Seeded 2026-07-29 from Phases 2–3 of the KB build.

**A gap is not a failure — it is a known unknown with an owner and a next action.** The dangerous
state is a fact that *looks* verified and isn't. Every entry below has a **Next** line specific
enough to execute.

## How to read this file

Each gap is a `###` block, not a table row — long evidence goes in prose so it stays readable.
Every block opens with one status line:

> `` `STATUS` · owner-or-area · P# ``

| Field | Allowed values | Meaning |
|---|---|---|
| Status | `OPEN` | Actionable now by whoever picks it up |
| | `BLOCKED` | Needs a named person's decision before any work is possible |
| | `CLOSED` | Resolved — moved to the [Closed](#closed-gaps) appendix with date and resolving ID |
| Priority | `P1` | Wrong numbers reaching a decision, or active cost/latency harm |
| | `P2` | Real defect, no immediate blast radius |
| | `P3` | Low, cosmetic, mechanical, or informational |

Priority is a **separate field from status** — do not encode it in the status string.
Coverage inventories (§10, §11) stay as tables; they are genuinely tabular.

---

## Dashboard

Last updated **2026-08-20** — Return Trips % (card 44691) reconciled; 3 gaps added (`G-156`–`G-158`).
Previously **2026-08-14** — 11 owner rulings applied; 6 gaps closed, 4 narrowed, 1 corrected.

| Status | Count | Change |
|---|---:|---|
| `OPEN` | 47 | +2 |
| `BLOCKED` — awaiting an owner decision | 11 | — |
| `CLOSED` | 14 | +1 |
| **Named gaps total** | **72** | +3 |
| Coverage rows — §10 catalogue metrics | 72 | — |
| Coverage rows — §11 unopened cards | 12 | — |

**The P1 list — read these first**

| id | gap | status |
|---|---|---|
| [G-156](#g-156) | Return Trips % 14 % vs 28 % — **reconciled**; denominator scope, fix specified | `OPEN` |
| [G-018](#g-018) | Partition-pruning anti-pattern on a live revenue card — real cost and latency | `OPEN` |
| [G-117](#g-117) | Arithmetic discrepancy in the source review's CADF row | `OPEN` |
| [G-137](#g-137) | Three clubbing cards silently ignore their date/city filters — **cards named, owner accepted for fix** | `OPEN` |
| [G-001](#g-001) | CBDF/CADF `<60s` — **semantics ruled**; two card defects remain (42683, 49366) | `OPEN` |
| [G-002](#g-002) | `<60s` semantics — **ruled: three distinct metrics, three denominators, all intended** | `OPEN` |

**Cleared off the P1 list on 2026-08-14**

| id | outcome |
|---|---|
| G-141 | `CLOSED` — offline flow deprecated since 2025; the inflation is at most 19 orders and zero in 2026 |
| G-151 | Downgraded to `OPEN`/P2 — the cards exist; scope cut from 14 metrics to 4 |

---

## Index

| id | gap | status | P |
|---|---|---|---|
| [G-001](#g-001) | CBDF/CADF `<60s` residuals | `OPEN` | P1 |
| [G-002](#g-002) | Two `<60s` semantics in production | `OPEN` | P1 |
| [G-004](#g-004) | AOV revenue base ruled; date basis still open | `BLOCKED` | P2 |
| [G-006](#g-006) | Internal-user exclusion uses two mechanisms | `OPEN` | P2 |
| [G-008](#g-008) | Customer NPS not comparable across Mar→Apr 26 | `OPEN` | P2 |
| [G-010](#g-010) | Registry declares behaviour the builders don't implement | `OPEN` | P2 |
| [G-011](#g-011) | Clubbing population scope differs across cards | `OPEN` | P2 |
| [G-013](#g-013) | `state` enum verified from a card, not a data dictionary | `OPEN` | P3 |
| [G-014](#g-014) | `SDD`/`NDD` word expansions inferred | `OPEN` | P3 |
| [G-015](#g-015) | `EDD` expansion never stated | `OPEN` | P3 |
| [G-016](#g-016) | Acronyms unconfirmed: VSS, TOF, OS, OLC, WD | `BLOCKED` | P2 |
| [G-017](#g-017) | House formulas use `so`, `mo`, `cac` unexpanded | `BLOCKED` | P3 |
| [G-018](#g-018) | Partition-pruning anti-pattern on live cards | `OPEN` | P1 |
| [G-019](#g-019) | Sheet-backed tables have unknown freshness | `OPEN` | P2 |
| [G-020](#g-020) | "3 charters" framing unconfirmed | `OPEN` | P3 |
| [G-021](#g-021) | Intervention dates state no year | `OPEN` | P3 |
| [G-022](#g-022) | Title-vs-SQL mismatches across seven cards | `OPEN` | P2 |
| [G-023](#g-023) | Two incompatible retention/repeat taxonomies | `OPEN` | P2 |
| [G-024](#g-024) | Card 39104 hardcodes month grain | `OPEN` | P3 |
| [G-025](#g-025) | Four cards hardcode `category='Business'` | `OPEN` | P2 |
| [G-026](#g-026) | Five cards reference `frequency` unprefixed | `OPEN` | P3 |
| [G-027](#g-027) | Card 33519 is day-bounded, not historical | `OPEN` | P2 |
| [G-028](#g-028) | `is_repeated_order` vs "repeat user share" | `OPEN` | P3 |
| [G-029](#g-029) | `sqlgen.py` comment contradicts its code | `OPEN` | P3 |
| [G-030](#g-030) | Review header reads `Feb-25` for `Feb-26` | `OPEN` | P3 |
| [G-031](#g-031) | Review FCR narrative says "stable" against an outlier | `OPEN` | P3 |
| [G-032](#g-032) | Review return-trip narrative self-contradicts | `OPEN` | P3 |
| [G-033](#g-033) | Review median-time-to-book text discusses repeat share | `OPEN` | P3 |
| [G-034](#g-034) | Review earnings/trip insight truncated | `OPEN` | P3 |
| [G-035](#g-035) | `total_fulfilment_pct` names an unimplemented variant | `OPEN` | P2 |
| [G-036](#g-036) | `cadf_pct` omits a caveat its sibling carries | `OPEN` | P3 |
| [G-037](#g-037) | Notion doc "secondBrain" not found in the workspace | `BLOCKED` | P2 |
| [G-038](#g-038) | Metabase database-id ambiguity | `OPEN` | P3 |
| [G-039](#g-039) | Cross-vertical metric-name collisions | `OPEN` | P2 |
| [G-114](#g-114) | v1 metric count: journey doc says 12, D6 locks 11 | `OPEN` | P3 |
| [G-115](#g-115) | Unverified-row count: 62 vs 64 | `OPEN` | P3 |
| [G-117](#g-117) | Review CADF "+1.2pp" vs its own 0.82pp | `OPEN` | P1 |
| [G-119](#g-119) | Do **not** "fix" M-009's single base — informational | `OPEN` | P3 |
| [G-132](#g-132) | PTL's architecture is the shape Argus rejected | `BLOCKED` | P2 |
| [G-133](#g-133) | No metric in this KB has a named owner | `BLOCKED` | P2 |
| [G-134](#g-134) | Argus trust-footer requirement only partly met | `OPEN` | P3 |
| [G-136](#g-136) | Metabase db ruled (db73); `T-012` unit residual | `OPEN` | P3 |
| [G-137](#g-137) | Inert and hardcoded filters | `OPEN` | P1 |
| [G-138](#g-138) | `{{frequency}}` means two things on one dashboard | `OPEN` | P2 |
| [G-139](#g-139) | Card 52889 sits in the wrong collection | `OPEN` | P3 |
| [G-140](#g-140) | Cards 39107/39149 repeat flag saturates to ~100% | `OPEN` | P2 |
| [G-143](#g-143) | 39117 retention columns read 0 on narrow windows | `OPEN` | P3 |
| [G-145](#g-145) | Two chart ids don't resolve post-migration | `BLOCKED` | P2 |
| [G-146](#g-146) | PTL Awareness Rate has no chart anywhere | `OPEN` | P2 |
| [G-147](#g-147) | Catalogue #18's candidate ends at the wrong event | `OPEN` | P2 |
| [G-148](#g-148) | Card 48984 diverges on customer master; #17 mislabeled | `BLOCKED` | P2 |
| [G-149](#g-149) | Catalogue #44's card assignment is wrong | `OPEN` | P2 |
| [G-150](#g-150) | Six metrics confirmed absent from Metabase | `BLOCKED` | P2 |
| [G-151](#g-151) | Owner-grain supply: cards exist, 4 metrics genuinely absent | `OPEN` | P2 |
| [G-152](#g-152) | Nine batch-2 cards lack a staleness fingerprint | `OPEN` | P3 |
| [G-153](#g-153) | Catalogue #4/#7/#8 verified but never given `M-###` rows | `OPEN` | P2 |
| [G-155](#g-155) | Should 39118's lifetime flag ignore dimension filters? | `BLOCKED` | P2 |
| [G-156](#g-156) | Return Trips % 14% vs 28% — reconciled, denominator scope | `OPEN` | P1 |
| [G-157](#g-157) | Return Trips %: reverse-route predicate and cutoff-days bound | `CLOSED` | P2 |
| [G-158](#g-158) | `ptl_routes` joined without `is_active` in 42081 / 48581 | `OPEN` | P2 |

Coverage inventories are indexed separately — see [§10](#10-coverage--74-catalogue-metrics) and
[§11](#11-coverage--93-dashboard-cards-not-opened).

---

## Action queue — P1

Six gaps. **None of these need a decision from you** — the calls are made and the detail below is
enough to execute. Ordered by how ready they are to fix.

### G-137
**Inert and hardcoded filters — cards accept parameters they silently ignore**
`OPEN` · escalated · P1 · **owner accepted for fix 2026-08-14**

**The three cards to fix.**

| card | name | defect | fix |
|---|---|---|---|
| **47540** | clubbing (date-param) | Start/End Date tags exist but SQL hardcodes `pickup_date >= '2026-02-01'`; the `{{start_date}}`/`{{end_date}}` block is commented out | Uncomment the date block, delete the hardcoded floor |
| **48449** | clubbing "City Wise" | Same dead date params, **plus** hardcodes `pickup_city IN ('Bangalore','Mumbai')` with no city template tag despite the name | Restore date params; add a `pickup_city` tag or rename the card to state the two cities |
| **49365** | clubbing (completed) | Outer date filters work, but the `completed_orders` CTE hardcodes a `>= '2026-03-01'` floor, so an earlier Start Date returns **nothing rather than erroring** | Remove the CTE floor so the outer filter governs |

**Detail.**
- Cards **47540** and **48449** expose Start/End Date parameters that do nothing: the live SQL
  hardcodes `pickup_date >= '2026-02-01'` and references `{{start_date}}`/`{{end_date}}` only in a
  commented-out block.
- **48449** also hardcodes `pickup_city IN ('Bangalore','Mumbai')` despite being named "City Wise"
  with no city template tag.
- **49365**'s outer date filters work, but its `completed_orders` CTE hardcodes a `>= '2026-03-01'`
  floor, so an earlier Start Date **returns nothing rather than erroring**.

**Why P1.** A user who sets a date range on these cards gets a plausible, silently wrong answer; on
49365 they get an empty result that reads as "no data" rather than "filter ignored".

**Next.** Raised with the card owners 2026-07-30 (owner decision: escalate **and** keep the KB
warning). Until a fix lands, treat every clubbing number as unfiltered-by-date.

> **Do not delete this entry when the cards are fixed** — close it with the date and the fixing
> commit/card version, so the KB records that the trap once existed.
> ask the user for session_id and his preferences to fix the card then use metabase-chart builder skill to fix the cards

### G-001
**CBDF/CADF `<60s` residuals — semantics ruled, two card defects remain**
`OPEN` · P1

**Ruling 2026-08-14 (Devansh), verbatim:** *"`<60s` means excluding the orders that got cancelled
in 60 seconds. it should be defaulted to yes."*

**Applied as.** `<60s` means **excluding orders cancelled within 60 seconds**, and
`exclude_60_sec` **should default to Yes**. The parameter is a deliberate user-facing dashboard
control (a Yes/No selector), not an oversight — so the "indeterminate first-load value" residual is
closed: the answer is that it should load as Yes.

**Still open — two card defects, not decisions.**
- Card **42683** applies **no** `<60s` exclusion while 43237 / 43242 / 47673 / 47674 do — same
  dashboard, same metric name. Under the ruling, 42683 is wrong and needs the exclusion added.
- Card **49366** — D5's named reconciliation counterpart — divides by *that reason-bucket's own
  cancellations*, not placed orders, and joins `o.external_id` not `o.id`. Not a like-for-like
  check, so D5's 4793↔49366 gate cannot be satisfied as written.

**Next.** (1) Set `exclude_60_sec`'s default to Yes on every card in the family. (2) Add the
exclusion to 42683. (3) Amend or drop D5's reconciliation gate, since the two cards compute
different ratios by construction.

> Status moved `BLOCKED` → `OPEN`: this no longer needs an owner decision, it needs card edits.
> ask the user for session_id and his preferences to fix the card then use metabase-chart builder skill to fix the cards

### G-002
**`<60s` semantics — ruled. Three metrics, three different denominators, all intended**
`OPEN` · P1

**Ruling 2026-08-14 (Devansh), verbatim:**
> *"Fulfillment: No exclusion of 60 secs cancelled orders from deno.*
> *Fullfillment excluding 60sec: remove orders cancelled within 60sec from the deno*
> *other one is i think cbdf you misunderstood it"*

The third line is a correction of this entry, and it was right — see below.

**Applied as.** These are not competing variants of one metric — they are three
distinct metrics, and each denominator is correct for its own metric:

| metric | denominator | `<60s` cancels |
|---|---|---|
| **Total fulfilment %** | all placed orders | **kept** in the denominator |
| **Total fulfilment, excl `<60s` %** | placed − orders cancelled within 60s | **removed** from the denominator |
| **Effective fulfilment %** | placed − customer-attributed cancels | not a `<60s` metric at all |

**The KB's original third-variant claim was wrong, and the owner caught it.** This entry previously
stated that `effective_fulfilment_pct` "subtracts CBDF cancels". It does not. Card **48581** was read
directly 2026-08-14: it subtracts **customer-attributed cancellations**, classified by a keyword
mapping over free-text cancellation reasons. Verified by execution — May/Jun/Jul 2026 return
66.55% / 68.00% / 68.88%, reproducing the published series exactly. The prototype's comment, not the
card, was the source of the error.

**Consequence to carry.** Effective fulfilment **rises when customers cancel more**, because customer
cancels leave the denominator. June's 66.55% → 68.00% is almost entirely customer cancels growing
1,888 → 2,020, while total fulfilment barely moved. Owner confirms this is intended — it is the
controllable-failure view — but it must be labelled so nobody reads it as an ops win.

**Next.** Align the prototype's `effective_fulfilment_pct` comment and implementation with card
48581. Ensure all three metrics are named distinctly enough that they are never read as one number
with variants.

> Status moved `BLOCKED` → `OPEN`: semantics are ruled; what remains is making the code match.
> ask the user for session_id and his preferences to fix the card then use metabase-chart builder skill to fix the cards
### G-018
**The partition-pruning anti-pattern is more widespread than first recorded**
`OPEN` · escalated · P1

**Detail.** Card 33519 has it in one *optional* filter (`DATE(col + INTERVAL '330 minutes')`) — in
the same card that carries a `-- KEY FIX` comment warning against it. **Worse, found 2026-07-30:
card 33706 — a live db73 revenue/AOV card — uses `date(updated_at + interval '330 mins')` as its
primary date predicate.** Wrapping the timestamp column defeats micro-partition pruning and forces
a full scan.

**Next.** Raised with the card owners 2026-07-30 alongside `G-137` (same likely owners, one
conversation). Recommended fix supplied: keep the column bare and shift the bound —
`ts >= DATEADD('minute', -330, {{d}}::timestamp_ntz)` — rather than wrapping the column.

**Until fixed.** Expect elevated runtime and warehouse cost on 33706 and on 33519's `pickup_date`
filter path. This is a real cost/latency issue, not a style note.

**Action.** reassess the card, there has been some changes in it .

### G-117
**Arithmetic discrepancy in the source review**
`OPEN` · P1

**Detail.** It states CADF moved "+1.2pp" but its own figures give 13.81% − 12.99% = **0.82pp**. One
of the three numbers is wrong. Per `B-033` this is exactly the kind of figure that reaches a
leadership note.

**Next.** Re-read the Notion review's CADF row and establish which value is authoritative.
**Answer** Notion is not important here there can be few mismatches.

### G-156
**Return Trips % — the 14% vs 28% conflict is a denominator-scope difference, not a computation error**
`OPEN` · P1 · *card 44691 · dashboard 4198 "Overview"*

**Reconciled 2026-08-20.** The last metric of 74 still marked a conflict. Both numbers are correct;
they use different denominators. Reconstructed card 44691's SQL in Snowflake and reproduced **both**
sides on identical inputs (`is_test='False'`, period = Month):

| month | numerator | denom = all 96 active routes | denom = 28 bidirectional routes |
|---|---:|---:|---:|
| May-26 | 598 | 4,204 → **14.22 %** | 2,170 → **27.56 %** |
| Jun-26 | 604 | 3,928 → **15.38 %** | 2,204 → **27.40 %** |
| Jul-26 | 527 | 4,002 → **13.17 %** | 2,222 → **23.72 %** |

The all-routes column reproduces the previously reported 14.22 / 15.38 / 13.17 exactly, which
validates the reconstruction. The bidirectional column reproduces the published ~28 %. **The
published review number is the bidirectional one** — consistent with the catalogue name,
"Return Trip % (Bidirectional Routes)" (`kb/metrics.md:319`).

**The numerator is identical in both columns** (598 / 604 / 527). Empirically, over all three
months, *every* batch flagged as a return trip already sits on a bidirectional route — so the route
filter only ever moves the denominator. A denominator of all 96 routes therefore divides a
bidirectional-only numerator by an all-routes base. That is the defect.

**Why the dashboard disagrees with the review.** Dashboard 4198's `Return Route Name` parameter
(`648db78c`) has **no default**, and the card's own `route_name` tag has none either. So the tile on
4198 renders the **unfiltered ~13–15 %**, while the review quotes ~28 % produced by someone typing
routes into the filter by hand. The hand-maintained 19-route list is not stored in the card, the
dashboard, or this repo — it exists only in whoever ran it.

**Fix.** Gate the denominator on `reverse_route_id IS NOT NULL` rather than a typed route list. The
card already computes reverse pairing internally, so this is self-maintaining as routes launch and
close, and it removes the drift that made the list stale. Verified: 28 of 96 active routes are
bidirectional (29.2 %), 0 route names are off the `'City - City'` convention, 1 route's name
disagrees with its `PICKUP_CITY`/`DROP_CITY` columns.

**Blast radius.** Card 44691 has 21,651 views. Dashboard 4198 had **62 distinct users since
2026-05-01, 44 in the last 30 days, 25,480 queries in 30 days**, active every one of 112 days. The
tile will move from ~13 % to ~24 % on apply. **Announce before applying** — this reads as a metric
jump, not a fix.

**Also fix while in here** (same card, lower stakes): defaults are `start_date=2025-09-01` /
`end_date=2025-12-31`, so an unparameterised run silently returns 2025.

**Next.** Apply the patch in `kb/patches/44691-return-trips.sql`. It is complete — `G-157` is ruled
and folded in, and the patch has been executed end-to-end against Snowflake, returning
27.56 / 27.40 / 23.72 % for May / Jun / Jul 2026. Metabase MCP is read-only for card SQL and the
stored session token is expired (401), so this is a human paste into the card, not an API write.
Also clear the 2025 date defaults in the card's parameter sidebar — the SQL cannot reach them.

---

## Decisions needed — BLOCKED

Ten gaps, each waiting on one answer. (`G-157` also sits in this section — **answered 2026-08-20**,
left in place until the next tidy-up.) Every block ends with a **Decision needed** line and a blank
**Answer:** for you to fill in — the same pattern you used last round. Nothing here can move until
the question is answered, so these are the highest-leverage minutes you can spend on this file.

Two of them (`G-148`, `G-150`) are **partly answered already** by work done since they were written —
read those two first, they may collapse to nothing.

### G-004
**AOV revenue base — ruled, but the ruling needs one clarification**
`BLOCKED` · owner · P2 · *absorbs `G-135`*

**The three bases.** Card 33706 raw `estimated_fare` · card 37413 WD-revised `final_fare` · card
52889 `total_fare + discount`. Crossed with **two date bases**: 33706 and 52889 use `updated_at`,
37413 uses `created_at`. (This crossing was tracked separately as `G-135`; the owner confirmed
2026-08-14 that it is the same question, so `G-135` is closed into this entry.)

**Ruling 2026-08-14 (Devansh).** "Use final fare, and total fare + discount."

**My reading, needs a yes/no.** I take this as **one** base, not two: revenue = the **final
(weight-revision-adjusted) fare, with discount added back** — i.e. gross revenue before discount,
computed on the post-revision fare. That is 37413's fare column combined with 52889's discount
add-back.

**If that reading is right, no existing card implements it.** 37413 has the right fare but does not
add discount back; 52889 adds discount back but uses the unconditional current fare rather than the
weight-revision-gated one. A new or amended card is needed either way.

**Still unresolved.** The **date basis** is untouched by the ruling, and the two cards named sit on
opposite sides of it (`created_at` vs `updated_at`). AOV cannot be pinned without this — the
difference is roughly 7% on the months measured.

**Next.** Confirm the single-base reading above, then pick `created_at` or `updated_at`. Then update
`M-008` and retire the two non-canonical cards or rename them as explicit alternates.

**Decision needed.** Two things. (1) Confirm the single-base reading: revenue = **final (weight-revision-adjusted) fare, with discount added back**? (2) Date basis — **`created_at` or `updated_at`**? AOV cannot be pinned without both; the date basis alone moves it ~7%.

**Answer:** do not add discount,use final fare weight adjusted on updated_at

### G-148
**Card 48984 (#16/#17) diverges from the canonical business-customer rule, and #17 is likely mislabeled**
`BLOCKED` · owner · P2

**Detail.** The filter is sourced from `prod_eldoria.core.dim_customers`, not
`oms_public.customers` (`T-020`) — the same 4198-vs-4569 split already flagged at `G-005`, now
confirmed at individual-card level.

Separately, **#17's "order placed" numerator is a raw `booknow_clicked` click event with no join to
order completion**, contradicting sibling card #11 (`M-014`) which correctly gates on `state=3`.
Executed value 56.4% (Jun-26) is a click-through rate, not an order-placement rate.

**Next.** Ask the metric owner which customer-source table is canonical for this card family, and
whether #17 should be redefined or rebuilt against actual order completion.

**Decision needed.** Only one half remains. The customer-source question is answered by `G-005` (use `oms_public.customers`). The "#17 is mislabeled" claim is **disproven** — clicks and orders are 1:1 (12,135 of 12,136 book-now click order-ids exist in `orders`), so a click numerator is a valid order proxy. **Decide:** accept #17 as-is, or still rebuild it to join order completion explicitly for clarity?

**Answer:** accept it as is

### G-150
**Six metrics confirmed genuinely absent from Metabase after a real search**
`BLOCKED` · owner · P2

**Detail.** #36 Damage%, #48 Batch Acceptance%, #49 SLA Breach%, #50 Allocation Acceptance Rate,
#52 % Organic Allocation, #53 Reallocation Rate.

Not a "didn't look" gap — each was searched by name and concept. #48 turned up a wrong-grain
CGE-wide tool (rejected), #50 turned up a different-concept "orders allocated" rate (rejected), #53
has one unconfirmed loose lead (card 48535 "Vehicle Change %").

**Next.** Confirm with the metric owner whether these are tracked anywhere at all (a sheet? not yet
built?) before spending more search effort.

**Decision needed.** Are these tracked anywhere — a sheet, or simply not built? **Partly answered already:** #36 Damage% appears in the July'26 review at 0.4%, marked "tracked offline", so at least one of the six has a source. Remaining: **#48, #49, #50, #52, #53**.

**Answer:** they are all tracked offline

### G-155
**Should the 39118 lifetime repeat flag ignore the dimension filters?**
`BLOCKED` · owner · P2

**Detail.** Today a route/city filter narrows the lifetime history too, so a customer new to route X
but with long PTL history reads as *new* under a route filter. The alternative — lifetime measured
across all routes, dimension filters applied only to the measured slice — makes "repeat" a stable
customer property but decouples numerator from the filtered slice. Not covered by the 2026-08-14
ruling, so left as-is.

**Next.** Owner to pick. If all-route lifetime is wanted, drop the four `[[...]]` clauses from
`online_lifetime_orders` / `offline_lifetime_orders` only.

---

**Decision needed.** Should 39118's lifetime repeat flag **ignore** the `pickup_city` / `drop_city` / `route_name` / `category` filters? Today a route filter narrows the lifetime history too, so a customer new to route X but with long PTL history reads as *new*.

**Answer:**

### G-145
**Two chart ids don't resolve post-migration**
`BLOCKED` · owner · P2

**Detail.** #5 card `42065` and #6 card `49312`. The org migrated Mixpanel→Amplitude 2026-01-01;
these numeric ids are likely stale Mixpanel references never carried forward.

**Next.** Ask the metric owner for the current chart backing #5/#6, or confirm neither was rebuilt.

**Decision needed.** Current ids for catalogue **#5** and **#6**. WARNING — **this entry's premise looks wrong**: it calls 42065 and 49312 "Amplitude chart ids", but the July'26 review links `metabase.prod-internal.porter.in/question/42065-ptl-coverage-based-on-os-quotes`. They appear to be **Metabase question ids**, and 42065 resolves. If so this is not a migration casualty at all — confirm and re-scope.

**Answer:**

### G-133
**No metric in this KB has a named owner**
`BLOCKED` · owner · P2

**Detail.** Argus requires a named owner + reviewer sign-off for every admitted metric.
`metrics.md` records formulas and sources but no owner for any of the 11.

**Next.** Assign an owner per v1 metric and add an `owner` column to `metrics.md`. Cannot be
inferred — must be supplied.

**Decision needed.** **Name an owner per v1 metric** (all 11). This cannot be inferred from code or dashboards — it has to be supplied.

**Answer:** it is not needed here but this is different from argus

### G-016
**Acronym expansions unconfirmed: `VSS`, `TOF`, `OS`, `OLC`, `WD`**
`BLOCKED` · owner · P2

**Detail.** The first four are used throughout the review and expanded nowhere. `WD` is inferred
from a card *title*, which §4 says is never evidence.

**Next.** Owner to supply expansions. `VSS` is load-bearing — it names the top-of-funnel surface in
~8 metrics. For `WD`, read card 34284's SQL.

**Decision needed.** Expansions for **VSS**, **TOF**, **OS**, **OLC**, **WD**. `VSS` is the urgent one — it names the top-of-funnel surface in ~8 metrics and is expanded nowhere.

**Answer:** vss- vehicleselectionscreen, tof- top of funnel,os-outstation,olc- order life cycle, wd - weight discrepency

### G-017
**House formulas use `so`, `mo`, `cac` with no expansion given**
`BLOCKED` · owner · P3

**Next.** Obtain expansions from the PTL master instruction author.

**Decision needed.** Expansions for **`so`**, **`mo`**, **`cac`** as used in the house formulas.

**Answer:**

### G-037
**The Notion doc "secondBrain" does not appear to exist in the connected workspace**
`BLOCKED` · owner · P2

**Detail.** Named as a source in the KB brief. **Two independent searches** — `secondBrain` and
`second brain` — returned zero matching pages; every hit was an incidental match on the word
"second" in unrelated documents. **No substitute page was used**, deliberately: silently adopting a
similar-looking page would have injected unaudited content under a source name the brief authorised.

**Next.** Owner to supply the exact page ID/URL, confirm it lives in a different workspace, or
confirm it does not exist.

**Decision needed.** Where is the "secondBrain" doc? A page URL, a different workspace, or confirm it never existed. Two searches found nothing and no substitute was used.

**Answer:**

### G-132
**PTL's architecture is the shape Argus rejected**
`BLOCKED` · owner · P2

**Detail.** Ruling **D2** builds on raw `partload_application` with a hand-rolled metric registry,
deferring a governed dbt layer. The Metric Store POV explicitly **evaluated and rejected** a
"per-metric SQL template file" approach for its own programme, choosing dbt-authored, PR-gated
definitions. PnM is hitting the same fork now — its standing rule is "no dbt model → not eligible
for the metric store" — and is weighing re-pointing to the eldoria dbt layer to gain Argus
eligibility. **Nothing in the POV names PTL, so this is not a violation today.**

**Next.** Decide whether PTL self-serve targets Argus eligibility. If yes, D2's "governed layer
later" needs a date and the registry becomes an interim artifact. If no, record why PTL is exempt.
This is a roadmap decision, not an analysis task.

**Decision needed.** Does PTL self-serve **target Argus eligibility**? If yes, ruling D2's governed-layer migration needs a date and the metric registry becomes an interim artifact. If no, record why PTL is exempt. Roadmap decision, not an analysis task.

**Answer:**

### G-157
**Return Trips % — two predicates the card computes and then ignores**
`CLOSED` · **ruled 2026-08-20 (Devansh)** · P2 · *card 44691 · folded into the `G-156` patch*

Separate from the denominator question (`G-156`, already settled). These two are genuine semantic
calls, not bugs, and they change the headline number by up to 9 points.

**1. The reverse-route condition is not applied.** `matched_return_routes` joins on
`prev.vehicle_city = curr.drop_city AND prev.created_at < curr.created_at` — the
`prev.route_id = curr.reverse_route_id` predicate is absent. So the whole `return_route_id`
self-join produces a `reverse_route_id` that gates nothing. What the card actually counts is *"the
same vehicle had a previous batch, and this batch drops in the vehicle's home service zone"* —
i.e. **the vehicle came home**, not **the vehicle ran the reverse route**. Defensible as a proxy,
but it is not what the metric name implies.

**2. `return_trip_cutoff_days` is loaded and never used.** It is selected in `return_route_id` and
carried through `orders_enriched` → `batch_routes` → `final_ctee`, but appears in **no predicate
anywhere**. So "was Porter able to arrange a return" has no time bound at all. Values are 2 or 3
days, populated on all 132 rows. Observed gap between the forward and return batch reaches
**147 days**, with a mean of ~2.2.

**What each choice is worth** (denominator = bidirectional routes, per `G-156`):

| variant | May-26 | Jun-26 | Jul-26 |
|---|---:|---:|---:|
| as-is today | 27.56 % | 27.40 % | **23.72 %** |
| + reverse-route predicate | 19.03 % | 17.56 % | 16.11 % |
| + cutoff-days bound | 23.41 % | 22.10 % | 18.95 % |
| + both | 17.88 % | 15.97 % | **14.90 %** |

About 20 % of currently-counted return trips exceed their own route's cutoff; about 32 % are not on
the true reverse route.

**Independent of the choice:** the metric **declines in July in all four variants**. That drop is
real and is currently hidden by reporting a flat 28 %.

**Decision needed.** (a) Re-enable `prev.route_id = curr.reverse_route_id`, or keep the
vehicle-came-home proxy and rename the metric to match what it measures? (b) Apply
`return_trip_cutoff_days` as a bound on `curr.created_at - prev.created_at`, or drop the column?

**Answer (2026-08-20, Devansh).**
- **(a) Keep the proxy and the name as-is.** The reverse-route predicate is *not* applied. The
  metric stays "the vehicle came home". `reverse_route_id` now serves exactly one purpose —
  scoping the denominator per `G-156`.
- **(b) Drop the column.** Verbatim: *"there is no logic of route cutoff entirely."*
  `return_trip_cutoff_days` is removed from all five CTEs rather than left looking like an
  unimplemented rule.

**Consequence, accepted knowingly.** With (a) declined and (b) dropped, *nothing* bounds the gap
between the forward and return batch. Pairs like vehicle …4978 — Mumbai→Ratnagiri on 1 Mar 2026,
then Pune→Mumbai on 26 Jul 2026, **147 days apart on unrelated routes** — keep counting as return
trips, as do same-direction repeats a week apart. This is the accepted behaviour of the proxy.
Shipped numbers are therefore the as-is row: **27.56 / 27.40 / 23.72 %**.

**Anyone reopening this** should reread the example table above before re-proposing either
predicate — both were put to the owner with sizing and declined.

---

> **The themed sections below carry only the remaining `OPEN` P2/P3 gaps.**
> Everything P1 or BLOCKED has been lifted into the two sections above.

## 1. Metric-definition conflicts
### G-006
**Internal/test-user exclusion uses two mechanisms — same outcome, different controllability**
`OPEN` · P2

**Detail.** Card 33519 exposes an `is_test` parameter defaulting to `False`. The CBDF/CADF family on
4793 (43237, 42683) **hardcodes** `NOT IN (SELECT DISTINCT mobile FROM ptl_internal_users)` with no
parameter. **Both DO exclude internal users** — this is an inconsistency in *how* exclusion is
controlled, not a missing exclusion.

**Next.** Audit the ~20 remaining metric cards on 4198/4569 to confirm each excludes internal users
at all, then standardise the mechanism. **Do not add exclusion to 43237/42683 — it is already
present**, and re-adding would double-exclude.

> Downgraded from critical: the earlier framing wrongly implied no exclusion.

### G-136
**Three Metabase connections — canonical db ruled, one unit residual remains**
`OPEN` · P3

**Ruling 2026-08-14 (Devansh), verbatim:** *"db73 is the right db, as all curated tables work on
this."*

**Applied as.** **db73 is canonical** — all curated tables live there. db83 and
db108 are not to be used as sources for PTL metrics. This closes the "which connection is
authoritative" half of the gap.

**Resolved 2026-07-30.** The three are distinct Metabase *connection profiles*, all
`engine: snowflake`:

| db | profile | used by |
|---|---|---|
| 73 | `SNOWFLAKE_NEW_INI` | every metric card |
| 83 | `SNOWFLAKE_BUSINESS_ENGG_PRODUCT` | card 33519 |
| 108 | `SNOWFLAKE_NI_ELDORIA` | the governed dbt layer D2 defers to |

Evidence they address the same objects: db73 cards reference the *identical fully-qualified* tables
db83 card 33519 uses — `partload_application.orders`, `.order_fares`, `.quotations`,
`partload_analytics.ptl_internal_users`. Different roles/warehouses over one account is the
overwhelmingly likely reading.

Re-verified on db73 and now safe: `T-001` (`state=3` Completed, `state=4` Cancelled — 8+ db73
cards), `T-010` (`estimated_fare/100`, card 33706), `T-011` (`total_fare/100`, cards 37413/52889).

**Residual, still db83-only — and now sharper given the ruling.** `T-001a` (the
`0=Open, 1=Assigned, 2=Picked_up` labels — the only db73 card touching them, 33462, groups 0/1/2
unnamed) and **`T-012`** (`chargeable_weight/1000` — no db73 card inspected references the column at
all). Because db73 is now the only sanctioned source, **these two facts currently rest entirely on a
db the KB has just ruled out of scope.** That makes confirming them more urgent, not less.

### G-138
**`{{frequency}}` means two unrelated things on dashboard 4569**
`OPEN` · P2

**Conflict.** On card 43406 it selects **cohort-lag granularity** (M1/M3/M6/M12); elsewhere
`frequency` refers to `oms_public.customers.frequency`, the **business/personal tier column**
(`T-020`). One token, two meanings, one dashboard.

**Ruling 2026-08-14 (Devansh), verbatim:** *"rename it in 43406 retention card."*

**Applied as.** Rename the parameter on **card 43406** (the retention card), since
that is the one using `frequency` in the cohort-lag sense. `frequency` keeps its
`oms_public.customers` meaning everywhere else.

**Next.** Rename the tag on 43406 — `cohort_lag` or similar — and update any dashboard filter
mapping that binds to it. Then this closes.

### G-139
**Card 52889 sits in a different collection from its family**
`OPEN` · P3

**Detail.** It lives in collection "Raw tables" (5198), not "Business Observability" (5199) like
every other 4198 card inspected.

**Ruling 2026-08-14 (Devansh), verbatim:** *"It should sit in Business observability."*

**Applied as.** It is genuinely part of the family and **should sit in "Business
Observability" (5199)**, not "Raw tables" (5198).

**Next.** Move card 52889 to collection 5199. Then this closes.

### G-143
**39117's retention columns read 0 on narrow windows**
`OPEN` · informational · P3

**Detail.** `RETAINED_CUSTOMERS` / `REACTIVATED_CUSTOMERS` are computed against prior periods
*inside* the query window. Mar-26 showed `retained = 0` purely because the window began 2026-03-01.
Only `ACTIVE_CUSTOMERS` is safe to read from a short window.

**Accepted 2026-08-14 (Devansh):** "this is known." The behaviour is understood and is not being
changed — this entry stays as a standing read-warning rather than a defect to fix.

**Next.** When reading retention from this card, extend the window at least one period before the
first period of interest. Keep this entry `OPEN` as documentation; do not close it, or the warning
disappears.

---

## 2. Prototype code defects
*Found by reading the code, not its comments.*

### G-010
**Registry declares behaviour the builders don't implement**
`OPEN` · P2

**Detail.**
- `new_business_users` registered `simple` but the SQL plan downgrades to `"authored"` — no
  first-order logic.
- `avg_orders_per_trip` and `m1_business_retention_pct` emit only `excl_offline` despite declaring
  `both_bases`, so **ruling D3 is not honoured**.
- `order_cancellation_reasons` is declared for 4 metrics and **never queried**.
- `avg_orders_per_trip` applies neither internal- nor business-user filtering, unlike every other
  builder.

**Next.** Fix the builders or correct the registry declarations, then re-run
`selfserve_nlq/run_tests.py` and confirm zero failures. (The harness prints a pass/fail count; it
has no fixed expected total.)

### G-011
**Clubbing population scope differs across cards**
`OPEN` · P2

**Conflict.** 33460 counts all non-cancelled states; 47540 / 48449 / 49365 restrict to completed only.

**Next.** Decide the canonical clubbing base; affects `M-007`.

### G-029
**`sqlgen.py` comment contradicts its code**
`OPEN` · P3

**Detail.** The comment claims "no fan-out (EXISTS not JOIN)" but `trips_sql` uses a plain JOIN.

**Next.** Verify whether `trips_sql` fans out; fix the code or the comment.

### G-035
**`total_fulfilment_pct` names an unimplemented variant**
`OPEN` · P2

**Detail.** The definition text references a `<60s excluded` variant the code never builds — yet the
review reports it (66%, Apr-26).

**Next.** Implement it to match whichever `<60s` semantics `G-002` settles on.

### G-036
**`cadf_pct` omits a caveat its sibling carries**
`OPEN` · P3

**Detail.** `cbdf_pct` carries the `<60s` caveat; `cadf_pct` does not, despite an identical mechanism.

**Next.** Align the caveats.

### G-158
**`ptl_routes` joined without `is_active` — one card is damaged, one escapes by accident**
`OPEN` · P2 · *found while working `G-156`*

`PROD_CURATED.PARTLOAD_ANALYTICS.PTL_ROUTES` holds **132 rows for 96 distinct `route_id`s** — up to
3 rows per route, differing on `IS_ACTIVE`. Filtering `is_active = 'True'` de-duplicates
**perfectly**: 96 rows, 96 ids, zero dupes. Any join that omits the filter fans out.

| card | name | views | joins `ptl_routes` w/o `is_active` | damaged? |
|---|---|---:|---|---|
| **42081** | Completed orders – P50 Allocation Time | 857 | yes, 1 join | **yes** |
| **48581** | Effective Fulfilment Trend | 25 | yes, 2 joins | no — by accident |

**42081 is wrong.** `COUNT(DISTINCT id)` protects the order counts, but `AVG`, `median` and
`PERCENTILE_CONT` **do not** — they run over duplicated rows. Measured on Jul-26 completed orders:
**9,489 rows for 7,618 distinct orders** (24.6 % inflation). Published **P50 15.77 vs 16.33 correct**
(understated 0.56 min, ~3.4 %); P90 42.90 vs 43.37. Real, but a modest distortion — P2, not P1. Its
own `array_agg(external_id)` output shows the repeated CRNs. Note 42081 carries a **second**
fan-out source, `left join gsheet_sync.ptl_table`, not assessed here.

**48581 is fine today.** Same missing filter in both its `total_orders` and `base` CTEs, but every
aggregate is `COUNT(DISTINCT …)`, so the fan-out cancels. It is protected by accident, not by
design — the next non-distinct aggregate added to it will break silently.

Card 44691 filters `is_active` on all four of its `ptl_routes` joins and is safe. **Do not remove
those filters** while applying `G-156`.

**Next.** Add `AND ptl_routes.is_active = 'True'` to the join in 42081 (one line) and to both joins
in 48581 (defensive). Re-check 42081's published P50 after.

---

## 3. Source and provenance gaps
### G-013
**The `state` enum is verified from a card's `CASE` mapping, not a warehouse data dictionary**
`OPEN` · P3

**Next.** Confirm against a data dictionary or column comment to upgrade `T-001` from "verified via
card SQL" to "verified via source of truth".

### G-019
**Sheet-backed tables have unknown freshness**
`OPEN` · P2

**Detail.** `gsheet_sync.ptl_offline_orders`, `.ptl_vendor_details`, `.ptl_table` are Google-Sheet
syncs, not systems of record.

**Next.** Establish sync cadence and staleness for each.

### G-027
**Card 33519 is day-bounded, not a historical source**
`OPEN` · P2

**Detail.** It hard-bounds `pickup_slot_start` to `CURRENT_DATE −1 .. +2`.

**Next.** Any metric citing 33519 as its source must be re-pointed at a historical card.

### G-038
**Metabase database-id ambiguity**
`OPEN` · P3

**Detail.** Card 33519 is `database_id: 83`; prior artifacts flagged uncertainty between db108 and
db73 for PTL. Three ids now in play. See `G-136`, which largely resolves this.

**Next.** Confirm which Metabase database id(s) map to which Snowflake account/warehouse.

---

## 4. Naming, jargon, and collisions
### G-014
**`SDD`/`NDD` mappings verified but the word expansions are inferred**
`OPEN` · P3

**Detail.** `EDD_BUFFER_IN_DAYS` 0/1 is verified; "Same-Day Delivery"/"Next-Day Delivery" is not.

**Next.** Confirm with a product source.

### G-015
**`EDD` expansion never stated**
`OPEN` · P3

**Next.** Confirm — likely "Estimated Delivery Date".

### G-028
**`is_repeated_order` vs "repeat user share" are different concepts sharing a word**
`OPEN` · P3

**Detail.** `is_repeated_order` is card 33519's column; "repeat user share" is the review's metric.

**Next.** Keep them lexically distinct in any NL interface.

### G-023
**Dashboard 4569 carries two incompatible retention/repeat taxonomies**
`OPEN` · narrowed · P2

**Conflict.** 3-way new/retained/reactivated (38287, 39117) vs binary lifetime new/repeat
(39107, 39149); and intra-period repeat (39118) vs lifetime-tenure repeat.

**Half-settled 2026-08-14.** Owner ruled the repeat basis is **lifetime order count**, not orders
inside the selected date range. Card 39118 was rewritten accordingly and now agrees with
39107/39149 on basis (`G-154` closed).

**Still open.** The 3-way new/retained/reactivated vs binary new/repeat split.

**Next.** Pick one taxonomy for the KB; the other becomes an alias with a warning.

### G-039
**Cross-vertical metric-name collisions**
`OPEN` · P2 · *(Argus backlog B-002)*

**Collisions asserted by reference docs.**
- `allocation %` — PnM = vendor-allocation quality vs PTL = `allocation/demand` funnel ratio. PTL
  also has a *second* "allocation" family (Allocation Acceptance Rate), risking self-collision.
- `CBDF` / `CADF` / `CAC` — same acronym family used by PTL **and** HCV; HCV's own docs list this as
  an open question.
- `CAC` — PnM allocation-lifecycle code vs PTL demand-funnel `cac`: a third sense.
- Also `conversion`, `NPS`, `GM%`.

**Confirmed from PnM's MBR automation SQL.** PnM uses `allocation` as a completion **timestamp**
(to bucket TPO by month) where PTL uses `allocation %` as a computed **ratio** — same word,
different grammatical role entirely. PnM's `conversion` = `orders/leads` (Nano-excluded), which PTL
has no metric literally named.

**Not evidenced in PnM code.** `CBDF` / `CADF` / `CAC` / `NPS` / `GM%` / `AOV` / `fulfilment` appear
**nowhere** in PnM's automation — those collisions are asserted by reference docs only.

**Next.** Namespace metric IDs per vertical before any cross-vertical NL interface ships.

---

## 5. Document defects in sources
**Do not silently correct these.** They are defects in documents the KB cites, not in the KB.

### G-008
**Customer NPS is not comparable across Mar-26 → Apr-26**
`OPEN` · P2

**Detail.** 4.45 → 53.85. Methodology/scale break mid-April.

### G-022
**Title-vs-SQL mismatches**
`OPEN` · P2

**All re-verified 2026-07-30.**

| card | title claims | SQL actually does |
|---|---|---|
| 33466, 43238 | "Fullfillment %" | returns **5** metrics |
| 37104 | "Fullfillment %" | returns **3**, split by EDD |
| 37413 | "Total Revenue" | also returns AOV, vendor cost, GM |
| 38900 | "LTO" implies lifetime | buckets are period-bound |
| 41124, 41509 | "First Order **Placed**" | filters `state=3` **completed** |
| 33485, 37419 | recorded as byte-identical duplicates | same formula, **different SQL text and display type** |

### G-024
**Card 39104 Monthly Churn % hardcodes `DATE_TRUNC('month', …)`**
`OPEN` · P3

**Correction 2026-07-30.** It does not "ignore" a frequency filter — the card has **no
`{{frequency}}` template tag at all**, in neither template-tags nor parameters. It cannot honour a
grain it never exposed.

### G-025
**Four cards hardcode `category='Business'`**
`OPEN` · P2

**Detail.** Cards 35397 / 39117 / 43406 / 44080 — the dashboard's Customer Category selector has no
effect on them.

### G-026
**Five cards reference `frequency` unprefixed**
`OPEN` · P3

**Detail.** Cards 38287 / 39117 / 38900 / 41124 / 41509. Correct only because `orders` lacks that
column — latent fragility.

### G-030
**Review column header reads `Feb-25` where `Feb-26` is meant**
`OPEN` · P3

**Detail.** Across all tables.

### G-031
**Review's FCR% narrative says "stable" against a Dec-25 outlier of 21.5%**
`OPEN` · P3

### G-032
**Review's return-trip% narrative claims both a "dip" and a "1pp jump" for the same period**
`OPEN` · P3

### G-033
**Review's median-time-to-book insight text discusses repeat-order share instead**
`OPEN` · P3

### G-034
**Review's earnings/trip insight is truncated mid-sentence in the source**
`OPEN` · P3

### G-140
**Cards 39107 / 39149: the repeat flag fires in the acquisition period itself**
`OPEN` · P2

**Detail.** A window `MAX` marks the acquiring period "repeat" whenever it holds ≥2 orders, and
**every subsequent period is unconditionally "repeat" regardless of order count**. The measure
therefore saturates toward ~100% far faster than "repeat customer" intuitively implies.

### G-020
**The "3 charters" framing is unconfirmed**
`OPEN` · P3

**Detail.** Booking Journey / Fulfilment / Unit Economics — never checked against a charter document.

### G-021
**Intervention dates state no year**
`OPEN` · P3

**Detail.** 4 Feb, 2 Mar, 7 Mar, 13 Mar; 2026 inferred. `3W` = three-wheeler is also inferred.

---

## 6. Internal inconsistencies between prior project documents
### G-114
**v1 metric count disagrees between documents**
`OPEN` · P3

**Detail.** The journey proposal §E proposes **12** metrics including Time-to-Allocate P50 (#51);
ruling **D6 locks 11**, deferring #51 to iteration 2.5. D6 wins per precedence; the journey doc was
never updated.

### G-115
**Unverified-row count disagrees**
`OPEN` · P3

**Detail.** The journey doc says "~62 unverified rows"; the catalog's corrected tally is **64**. The
journey text was never updated after the correction.

### G-119
**Do not "fix" Business Session Conversion's single base**
`OPEN` · informational · P3

**Detail.** `both_bases = False` on `M-009` is *correct* — D6's build note explicitly exempts #14
from the dual-base requirement. This entry exists so a future session reading D3 does not treat
correct code as a bug.

---

## 7. Strategic conflicts with the cross-vertical Metric Store (Project Argus)
### G-134
**Argus's trust-footer requirement is only partly met**
`OPEN` · P3

**Detail.** Argus mandates every served value carry **value + freshness + lineage + confidence**.
This KB supplies lineage (`source_ref`) and confidence, and freshness *where* `source_updated_at`
exists — but the KB serves definitions rather than values.

**Next.** Decide whether the self-serve engine's output must render a trust footer.

---

## 8. Tooling blockers hit while validating the catalogue
*From the 2026-07-30 pass over the 64 `unverified` catalogue rows.*

### G-146
**Catalogue #3 (PTL Awareness Rate) has no chart anywhere**
`OPEN` · P2

**Detail.** A 100-result name search returned nothing. Not substituted.

**Next.** Confirm with the metric owner whether this metric is tracked anywhere at all.

### G-147
**Catalogue #18's only candidate ends at the wrong event**
`OPEN` · P2

**Detail.** Candidate `9soyf565` ends at "book now clicked", not "order placed". The definition and
the candidate chart measure different funnel endpoints.

**Next.** Either find a chart ending at order-placed, or narrow #18's definition to match what is
actually tracked.

---

## 9. Catalogue errors and structural gaps
*From the 2026-07-30 batch-2 validation pass.*

### G-149
**Catalogue's card assignment for #44 appears to be simply wrong**
`OPEN` · P2

**Detail.** Catalogue says "Median Days Between Orders — Repeat Business Users". Card `49311`
actually computes median VSS-view→booknow-click latency **in minutes** — a session-funnel timing
metric. Executed: 0.8 min median (Jun-26), a value and unit that cannot be "days between orders"
under any reading. Likely mismapped when the catalogue was built; may actually answer a *different*
row (possibly overlapping #18).

**Next.** Find the correct card for #44's actual definition (inter-order interval, in days);
separately confirm whether 49311 belongs to a different catalogue row entirely.

### G-151
**Owner-grain supply metrics — this entry was mostly wrong. The cards exist**
`OPEN` · P2 · **scope cut from 14 metrics to 4, 2026-08-14**

**Correction 2026-08-14.** This entry claimed 12 metrics "may not exist in current PTL tooling at
all" and framed it as an entity-model mismatch needing new instrumentation. **That was wrong.** The
cards were located and executed for May–Jul 2026. What looked like a structural data gap was a
tool-access gap — the Metabase connector was down when the original assessment was made.

| # | metric | card | May / Jun / Jul 2026 |
|---|---|---|---|
| 57 | Monthly Active Owners | **49629** | 105 / 85 / 67 |
| 58 | New Owners Onboarded | **49615** | 6 / 0 / 0 |
| 59 | Monthly Active Vehicles | **49314** | 694 / 657 / 735 |
| 60 | New Vehicles Onboarded | — *(warehouse)* | 167 / 143 / 222 |
| 61 | Owner Onboarding Activation Rate | **49919** | 50% / n/a / n/a |
| 63 | M1 Owner Retention % | **49630** | 78.10 / 74.12 / n/a |
| 68 | SLA Adherence % by Owner | **49446** | 56.33 / 38.95 / 46.63 |
| 71 | Trips per MAV | **49313** | 6.64 / 6.50 / 6.01 |
| 74 | AppSheet Adoption — owners / partners | **43422** / **43499** | 51.12 / 46.42 / 45.69 · 24.46 / 21.36 / 19.62 |
| 75 | Owner Earnings per MAV | **49635** | 85,559 / 92,973 / *withheld* |
| 70 | Owner Earnings per Trip | **49316** | 14,124 / 15,559 / *withheld* |
| 64 | % Trips On-Time Pickup (owner view) | **49704** | 66.90 / 61.45 / 66.13 |
| 65 | % Trips On-Time Delivery (owner view) | **49706** | 68.15 / 52.42 / 57.21 |

MAO, MAV and Trips-per-MAV reproduce the published July'26 review **exactly**.

**Still genuinely absent — the real scope of this gap.** Four metrics, not fourteen:

| # | metric | why |
|---|---|---|
| 62 | Median Days Onboarding → First Trip | no card; review reports NA |
| 66 | Owner Batch Acceptance Rate | no product — acceptance is not captured |
| 67 | Owner Batch Completion Rate | same |
| 69 | Partner Attributed Damage % | not tracked anywhere |

**Two caveats on the numbers above.**
- **#75 and #70 are May/Jun only.** Cards 49316/49635 see just **1,253 July trips** against ~4,000
  actual — the vendor payout source is roughly 31% loaded for July. July figures are withheld, not
  estimated.
- **#74's name is wrong** — card 43422 measures AppSheet-accepted *batches* ÷ all batches, and 43499
  measures *orders* with all milestones filled. Neither counts owners or partners. Owner ruled
  2026-08-14 that the name is wrong and the cards stay as they are.

**Next.** Promote #57–61, #63–65, #68, #70–71, #74–75 to full `M-###` rows in `metrics.md` — the SQL
work is done, only the write-up remains. Keep this entry open for the four genuinely-absent metrics
and re-scope its title accordingly.

> Status moved `BLOCKED`/structural → `OPEN`/P2. Kept rather than closed so the KB records that a
> tool outage was once mistaken for a missing data model.

### G-152
**Nine batch-2 cards have no staleness fingerprint yet**
`OPEN` · mechanical · P3

**Detail.** Cards 34052, 34364, 33784, 33823, 33785, 33824, 42081, 42080, 37416. Found by a
metadata-search worker scoped to definitions, not fingerprinting.

**Next.** One `get_card` per card; record `updated_at` in [dashboards.md](./dashboards.md).

### G-153
**Catalogue #4, #7, #8 are verified but were never given full `M-###` entries**
`OPEN` · mechanical, do next · P2

**Detail.** Verified from their chart definitions (`G-041`, `G-044`, `G-045`) but never written into
`metrics.md` §1 — an asymmetry against the Metabase-sourced promotions, and the root cause of a real
bug: their §2 index rows sat unchanged (bare "unverified") for a full session after the underlying
finding was recorded, because GAPS.md was updated and metrics.md §2 was not.

**Next.** Write full `M-###` entries for #4/#7/#8 (formula, chart id, confidence, any caveat),
matching the format used for `M-012`–`M-020`.

---

## 10. Coverage — 74 catalogue metrics

*Counted in catalogue rows, not M-numbers — `M-014` alone closes 2 rows, `M-018` closes 3. An
earlier same-day pass said "65" by conflating the two units; **62 remain** is the reconciled figure.*

Ruling **D6** bounds v1 to 11 metrics; the owner ratified index-only treatment for the rest at the
build's checkpoint 2. **9 were promoted 2026-07-30** (→ `M-012`–`M-020`); 2 more were checked and
found to be catalogue errors rather than simple gaps (`G-148`, `G-149`).

Each remaining metric has an index row in [metrics.md](./metrics.md) §2 with the catalog's verbatim
status. **Next action for most:** locate the backing card/source, read its SQL, and promote to a full
`M-###` row — except rows marked *structural* (`G-151`), which need an owner decision on data
availability before any SQL work is possible.

| id | # | metric | state |
|---|---:|---|---|
| G-040 | 3 | PTL Awareness Rate | **checked** — no matching chart in 100 search results; not substituted. Genuinely no known source |
| G-041 | 4 | VSS TOF | **checked** — chart `3jh9upju` matches, but counts unique *users* not *sessions* as the title claims |
| G-042 | 5 | PTL Serviceable VSS % of Sessions | **checked** — id `42065` does not resolve; likely stale Mixpanel-era id → `G-145` |
| G-043 | 6 | PTL Card Tap Rate | **checked** — id `49312` does not resolve; same pattern as #5 → `G-145` |
| G-044 | 7 | PTL Selection Rate vs FTL | **checked** — chart `gjvatdh3` matches, `verified`. "FTL" is not a literal taxonomy term, see `B-053b` |
| G-045 | 8 | Outstation Search Rate | **checked** — chart `l9brfm70` matches cleanly, `verified` |
| G-046 | 9 | PTL Activation Rate | not covered |
| ~~G-047~~ | 10 | ~~VSS→Quote Conv (New Business)~~ | **promoted → `M-014`** (card 48923) |
| ~~G-048~~ | 11 | ~~Quote→Order Conv (New Business)~~ | **promoted → `M-014`** (card 44469) |
| ~~G-049~~ | 13 | ~~Avg Sessions Before First Order~~ | **promoted → `M-015`** (card 48922) |
| G-050 | 15 | Overall Session Conversion | not covered |
| G-051 | 16 | VSS→Quote Conv (All Business) | **checked** — card 48984 uses `dim_customers` not `oms_public.customers` → `G-148` |
| G-052 | 17 | Quote→Order Conv (All Business) | **checked** — likely mislabeled; numerator is a raw click event → `G-148` |
| G-053 | 18 | Median Time to Book | **checked** — candidate `9soyf565` terminates at "book now clicked", not "order placed" → `G-147` |
| G-054 | 20 | Customer Rating / NPS | not covered |
| G-055 | 21 | Support Tickets per Order | not covered |
| G-056 | 22 | Support Ticket % | not covered |
| G-057 | 23 | First Contact Resolution % | not covered |
| G-058 | 24 | Escalation % | not covered |
| G-059 | 25 | L4 Tickets | not covered |
| G-060 | 27 | Cancellation Attribution % | ⚠ catalog says `contradicted—conflict` |
| G-061 | 29 | Customer/Porter Attributed CBDF % | ⚠ catalog says `contradicted—conflict` |
| G-062 | 31 | Cust/Porter/Partner Attributed CADF % | ⚠ catalog says `contradicted—conflict` |
| ~~G-063~~ | 32 | ~~Perfect Order Experience %~~ | **promoted → `M-017`** |
| ~~G-064~~ | 33 | ~~On-Time Pickup % + Delivery %~~ | **promoted → `M-018`** |
| ~~G-065~~ | 34 | ~~On-Time Pickup %~~ | **promoted → `M-018`** |
| ~~G-066~~ | 35 | ~~On-Time Delivery %~~ | **promoted → `M-018`** |
| G-067 | 36 | Damage % | **searched, genuinely not found** (PnM-only dashboards exist) → `G-150` |
| G-068 | 37 | Weight Discrepancy % | ⚠ catalog says `contradicted—conflict` |
| G-069 | 40 | Repeat Rate (≥2 lifetime) | not covered |
| G-070 | 41 | Share of Orders from Repeat Users | not covered |
| ~~G-071~~ | 42 | ~~Avg Txns per Business Customer~~ | **promoted → `M-012`** |
| ~~G-072~~ | 43 | ~~Reactivation %~~ | **promoted → `M-016`** (card 48919) |
| G-073 | 44 | Median Days Between Orders | **checked** — catalogue's card assignment is wrong → `G-149` |
| ~~G-074~~ | 45 | ~~Share of Business Users~~ | **promoted → `M-013`** |
| G-077 | 47 | Vehicle Space Utilization % | not covered |
| G-078 | 48 | Batch Acceptance % | **searched** — wrong-grain CGE tool found, rejected → `G-150` |
| G-079 | 49 | Pickup/Delivery SLA Breach % | **searched, zero hits** → `G-150` |
| G-080 | 50 | Allocation Acceptance Rate | **searched, zero hits**, wrong-concept lead found → `G-150` |
| ~~G-081~~ | 51 | ~~Time to Allocate P50~~ | **promoted → `M-019`.** The "deferred to 2.5" premise (no card exists) turned out false — card 42081 is straightforward. Flagged back to the ruling owner, not silently overridden |
| G-082 | 52 | % Organic Allocation | **searched, zero hits anywhere** → `G-150` |
| G-083 | 53 | Reallocation Rate | **searched, zero hits**; loose unconfirmed lead card 48535 → `G-150` |
| ~~G-084~~ | 54 | ~~GM% per PTL Order~~ | **promoted → `M-020`** |
| ~~G-085~~ | 56 | Return Trip % | **covered — card 44691; conflict reconciled 2026-08-20** → `G-156`, `G-157` |
| **G-151** | 57 | Monthly Active Owners (MAO) | **structural gap** → `G-151` |
| **G-151** | 58 | New Owners Onboarded | **structural gap** |
| **G-151** | 59 | Monthly Active Vehicles (MAV) | **structural gap** |
| **G-151** | 60 | New Vehicles Onboarded | **structural gap** |
| **G-151** | 61 | Owner Onboarding Activation Rate | **structural gap** |
| **G-151** | 62 | Median Days Onboarding→First Trip | **structural gap** |
| **G-151** | 63 | M1 Owner Retention % | **structural gap** |
| G-093 | 64 | % Trips On-Time Pickup (Supply) | overall exists (`M-018`), no owner-split found → `G-151` |
| G-094 | 65 | % Trips On-Time Delivery (Supply) | overall exists (`M-018`), no owner-split found → `G-151` |
| **G-151** | 66 | Owner Batch Acceptance Rate | **structural gap** |
| **G-151** | 67 | Owner Batch Completion Rate | **structural gap** |
| **G-151** | 68 | SLA Adherence % by Owner | **structural gap** |
| **G-151** | 69 | Partner Attributed Damage % | **structural gap** |
| G-099 | 70 | Owner Earnings per Trip | not covered |
| G-100 | 71 | Trips per MAV | not covered |
| G-101 | 72 | Partner NPS | not covered |
| G-102 | 73 | Partner Support Tickets per Trip % | not covered |
| G-103 | 74 | AppSheet Adoption | not covered |
| **G-151** | 75 | Owner Earnings per MAV | **structural gap** |
| G-105 | 76 | Uptime % | not covered |
| G-106 | 77 | Latency P95 | not covered |
| G-107 | 78 | Booking Details Page Latency P95 | not covered |
| G-108 | 79 | Check Serviceability API Latency P95 | not covered |
| G-109 | 80 | Quote Generation API Latency P95 | not covered |
| G-110 | 81 | Booking Creation API Latency P95 | not covered |
| G-111 | 82 | Error Rate — Ktor & Job | not covered |
| G-112 | 83 | Booking Details Page Error Rate | not covered |
| G-113 | 84–86 | Serviceability / Quote / Booking API Error Rates *(3 metrics)* | not covered |

⚠ = the catalog itself marks these `contradicted—conflict` — its **highest-risk** label, meaning
sources actively disagree. Treat as higher priority than the plain `unverified` rows.

> **ID note.** `G-075` and `G-076` were never allocated (a numbering artefact caught in review).
> Per CONTRIBUTING §2 they are **retired, not reused**. This table holds 72 rows covering 74
> metrics — `G-113` covers catalog #84–86.

---

## 11. Coverage — 93 dashboard cards not opened

**54** on dashboard 4198 · **28** on 4569 · **11** on 4793. *(An earlier draft said "83" and omitted
the 4793 group entirely — the rows below are the authoritative count.)*

**Next action for all:** open the cards, read their SQL, and either promote to `M-###` rows or record
why they are out of scope.

| id | surface / tab | cards | why not opened |
|---|---|---:|---|
| G-120 | 4198 / SLA & on-time | 11 | Supply-side SLA; outside the 11 v1 metrics |
| G-121 | 4198 / Support & call-centre | 13 | Support metrics; catalog #21–25, all unverified |
| G-122 | 4198 / Demand Distribution | 8 | Dimensional cuts, not new definitions |
| G-123 | 4198 / Route Level | 6 | Route cuts of already-extracted metrics |
| G-124 | 4198 / Utilization | 4 | Only #47 is in the catalog; not a v1 metric |
| G-125 | 4198 / Supply & vendor | 4 | Supply-side; catalog #57–75 |
| G-126 | 4198 / Order Share | 3 | Share cuts |
| G-127 | 4198 / Overview + OKR + Finance | 5 | Duplicates of extracted cards (one duplicate flagged but unverified) |
| G-128 | 4569 / near-duplicate cards | 10 | Personal-only twins and order-level variants of extracted patterns |
| G-129 | 4569 / Poor Customer Retention | 8 | Service-quality cohorts; outside NSM/business scope |
| G-130 | 4569 / First-time User Metrics | 10 | Activation/funnel; deprioritised at 50-card volume |
| G-131 | 4793 / Overview cancellation | 11 | Flat cancellation-rate/reason/route cards; none reference CBDF/CADF by name |

---

## Closed gaps

Kept for the record — a closed gap documents that a trap once existed.

### G-003 — North Star implemented but never reconciled
`CLOSED 2026-07-30` → `M-001`

Closed **by execution**. Card 39117 run with `start_date=2026-03-01`, `end_date=2026-04-30`,
`frequency=Month` returns **Mar-26 = 1879** and **Apr-26 = 2247** — an **exact match** to the
reported figures. `M-001` promoted to `verified`.

Three consequences split out as live gaps: `G-141`, `G-142`, `G-143`.
Still to do: implement it in the prototype engine (`G-010`) — it emits no column.

### G-007 — AOV date basis unreconciled
`CLOSED 2026-07-30`

Card 33706 verified to use **`updated_at`** — the catalog was right, the prototype's `created_at` is
wrong. Fix the prototype. New finding split out as `G-135`: the date basis also differs *within* the
AOV family (33706/52889 `updated_at`; 37413 `created_at`).

### G-116 — Staleness fingerprints missing for ~20 cards
`CLOSED 2026-07-30`

All **29 cards** this KB relies on now carry a `source_updated_at`, tabulated in
[dashboards.md](./dashboards.md). The staleness check is live across every surface.

Spin-off finding → `G-136`: the sweep revealed `database_id` is not uniform (metric cards are db73;
card 33519 is db83). Re-run the sweep whenever a topic file adds a new card dependency.

### G-118 — M-002 lineage divergence
`CLOSED 2026-07-30` → `M-002`

Card 33483 ("Total Orders") has **no `state` predicate anywhere in its SQL** — architecturally
incapable of a completed-orders figure under any parameterisation. `33462` (named by both the
catalog and the registry) is canonical beyond doubt.

### G-144 — Metabase domestic connector auth expired mid-session
`CLOSED 2026-07-30`

Resolved same session — the connector reconnected without owner action. All 7 blocked metrics were
re-attempted and closed: 5 promoted (`M-014` / `M-015` / `M-016`), 2 found mislabeled
(`G-148` / `G-149`).

### G-154 — Card 39118 "Repeat Purchase Rate" counted repeat on the wrong basis
`CLOSED 2026-08-14`

**The defect.** It classified a customer as repeat from orders **inside the selected date range**:
`customer_orders` grouped `final`, already date-bounded, and tested `order_count > 1`.

**The ruling.** Owner (Devansh), 2026-08-14: the basis is the customer's **lifetime** order count.

**The fix**, saved to the card 2026-08-14 (`updated_at` now `2026-08-14T07:56:55Z`). Two extra CTEs
`online_lifetime_orders` / `offline_lifetime_orders` repeat the same population and the same
non-date filters with the `{{start_date}}`/`{{end_date}}` predicates removed. A cumulative
`SUM(...) OVER (PARTITION BY customer_mobile ORDER BY period ROWS UNBOUNDED PRECEDING)` then gives
the lifetime count through the end of each period, and the flag becomes `lifetime_order_count > 1`.
The date range now selects only the periods shown and the denominator. Output columns are unchanged,
so the line-chart visualisation still binds.

**Verification.** Jul-2026 = **39.69%** under both a 1-month and a 7-month range — range-independent
— against **18.60% / 18.63%** under the old SQL. A **+21pp** correction that also drifted with range
width.

Original SQL and card JSON were backed up to the session scratchpad before the write.

**Open sub-question, deliberately left alone.** The lifetime lookup still honours the `pickup_city` /
`drop_city` / `route_name` / `category` filters, so under a route filter "lifetime" means
lifetime-on-that-route. Changing that was outside the ruling → `G-155`.

### G-005 — Dashboards disagree on the customer master
`CLOSED 2026-08-14`

**Ruling (Devansh), verbatim:** *"Use `prod_curated.oms_public.customers`."*

**Applied as.** Use **`prod_curated.oms_public.customers`**. Dashboard 4569 was already
correct; 4198's use of `prod_eldoria.core.dim_customers` is the deviation.

Impact is small — measured over the 23,385 PTL customers in Apr–Jul 2026, the two tables matched on
100% of customers and disagreed on the Business/Personal bucket for only **6** of them. So existing
4198 figures are not materially wrong, but new work should use `oms_public.customers` and `T-020`
stands unchanged.

Consequence: `G-148`'s customer-source half is answered by this ruling; only its #17 labelling
question remains.

### G-012 — Two different definitions of "business user"
`CLOSED 2026-08-14`

**Ruling (Devansh), verbatim:** *"one considers frontend events that's why it is using an attribute
otherwise the correct definition is `oms_public.customers.frequency IN (1,2,3,4)`."*

**Applied as.** The canonical definition is **`oms_public.customers.frequency IN (1,2,3,4)`**.
The `ptl_fe_events` variant exists only because session metrics run on frontend events and had to
carry the segment as an event attribute — it is an eventing artifact, not a competing definition.

**Additional finding 2026-08-14:** the premise of this gap was partly stale. `ptl_fe_events` has
**no `user_type` column at all** in the current schema. Session cards derive the segment by joining
out to a customer master — card 48491 does so via `prod_eldoria.core.dim_customers` on
`customer_id`, which is the `G-005` deviation rather than a separate definition.

### G-135 — AOV family disagrees on revenue base and date basis
`CLOSED 2026-08-14` → merged into `G-004`

**Ruling (Devansh):** "this is related to prev one G004." Confirmed as the same question; the
revenue-base and date-basis strands are tracked together in `G-004` rather than split across two
entries. No content lost — `G-004` carries the full three-base × two-date-base detail.

### G-141 — NSM inflated because the offline leg lacks the internal-user filter
`CLOSED 2026-08-14`

**Ruling (Devansh):** "Offline flow is deprecated" — disabled since 2025 and no longer in use.

**Corroborated by the data.** `gsheet_sync.ptl_offline_orders` holds **19 orders in total**, all
between May and July **2025**, and nothing since. So the missing internal-user filter on the offline
CTE can inflate NSM by at most 19 orders across all history, and by **exactly zero** in any 2026
month. The defect is real but immaterial; NSM no longer needs to be treated as an upper bound.

### G-142 — Ruling D3 cannot be satisfied from card 39117
`CLOSED 2026-08-14`

**Ruling (Devansh):** "Offline flow is deprecated."

D3's dual-base requirement — show figures both including and excluding offline — is moot when the
offline leg contributes nothing. Card 39117's hardcoded offline `UNION` is therefore harmless: it
unions an empty set for every current period. **The dual-base rule can be retired** for all metrics,
not just this card.

### G-009 — Offline `status_code → state` mapping is UNMAPPED
`CLOSED 2026-08-14` · *closed by inference, please confirm*

Follows from the same offline-deprecation ruling: unrecognised offline status values can only drop
rows from a 19-row table that stopped receiving data in July 2025.

> **Flagging this as my inference, not your explicit answer.** You ruled on `G-141` and `G-142`
> directly; I extended the same reasoning here because the gap is entirely about offline rows. If you
> want the status dictionary obtained anyway — for reprocessing 2025 history, say — reopen it.
