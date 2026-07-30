# GAPS.md — open questions, conflicts, and uncovered surface

`G-###` rows, append-only. Adding/closing rules: [CONTRIBUTING.md](./CONTRIBUTING.md) §8.
Seeded 2026-07-29 from Phases 2–3 of the KB build.

**A gap is not a failure — it is a known unknown with an owner and a next action.** The dangerous
state is a fact that *looks* verified and isn't. Every row below has a `next_action` specific enough
to execute.

**Status:** `OPEN` · `BLOCKED` (needs a person/decision) · `CLOSED` (with date + resolving ID).

---

## A. Metric-definition conflicts — highest priority

| id | gap | conflicting positions | next_action | status |
|---|---|---|---|---|
| **G-001** | CBDF/CADF have three unresolved residuals despite the canonical formula being verified | (a) card 42683 on dashboard 4793 applies **no** `<60s` exclusion while 43237/43242/47673/47674 do — same dashboard, same metric name; (b) `exclude_60_sec` has **no default** and is used bare, not `[[optional]]`, so its first-load value is indeterminate from metadata; (c) card 49366 (D5's named reconciliation counterpart) divides by *that reason-bucket's own cancellations*, not placed orders, and joins `o.external_id` not `o.id` — not a like-for-like check | Ask the metric owner which `<60s` treatment is canonical and what `exclude_60_sec` should default to; then decide whether the D5 4793↔49366 reconciliation gate is satisfiable at all given they compute different ratios | **BLOCKED** — owner |
| **G-002** | **Two incompatible `<60s` semantics are both in production** | Fulfilment cards 33466/43238/37104 **drop** sub-60s cancels from the *denominator*; CBDF/CADF cards on 4793 exclude them from the *numerator only*, leaving the denominator whole. Separately, the prototype's `effective_fulfilment_pct` subtracts **CBDF cancels** instead of sub-60s cancels — a third variant | Confirm with the owner which is intended per metric; they produce materially different numbers | **BLOCKED** — owner |
| ~~**G-003**~~ | ~~North Star implemented but never reconciled~~ | **CLOSED 2026-07-30 by execution.** Card 39117 run with `start_date=2026-03-01`, `end_date=2026-04-30`, `frequency=Month` returns **Mar-26 = 1879** and **Apr-26 = 2247** — an **exact match** to the reported figures. M-001 promoted to `verified`. Three consequences split out below: `G-141`, `G-142`, `G-143` | Implement it in the prototype engine (`G-010`); it still emits no column | **CLOSED** → `M-001` |
| **G-141** | **The NSM reported to leadership is inflated — internal users are excluded from the online leg only** | Card 39117's offline (gsheet-sync) CTE has **no `ptl_internal_users` filter**, while the online CTE does. Because the card's output matches the reported 2,247 exactly, **the leadership figure carries this defect**. The same gap exists on card 38287 | Add the internal-user exclusion to the offline CTE, then re-run Mar/Apr-26 to size the correction. Until then, treat NSM as an upper bound | **OPEN — high** |
| **G-142** | **Ruling D3 cannot be satisfied from card 39117** | D3 requires showing both offline-included and offline-excluded bases. 39117 **hardcodes the offline `UNION` into its CTE structure** — no parameter, no `[[optional]]` block, no way to isolate the online-only leg | Fork the query to expose a base toggle, or accept that NSM is offline-inclusive only and amend D3's scope for this metric | **BLOCKED** — owner |
| **G-143** | **39117's retention columns read 0 on narrow windows** | `RETAINED_CUSTOMERS` / `REACTIVATED_CUSTOMERS` are computed against prior periods inside the query window. Mar-26 showed `retained = 0` purely because the window began 2026-03-01. Only `ACTIVE_CUSTOMERS` is safe to read from a short window | When reading retention from this card, extend the window at least one period before the first period of interest | **OPEN** |
| **G-004** | **Three competing revenue bases for AOV** | card 33706 `estimated_fare` · card 37413 WD-revised `final_fare` · card 52889 `total_fare + discount` | Owner picks the canonical revenue base for AOV; update `M-008` | **BLOCKED** — owner |
| **G-005** | Dashboards disagree on the customer master | 4569 uses `prod_curated.oms_public.customers` exclusively; 4198 references `prod_eldoria.core.dim_customers` | Compare the two on `frequency` semantics and coverage; decide one for PTL self-serve. Note ruling D2 defers the governed-layer migration | **OPEN** |
| **G-006** | Internal/test-user exclusion uses **two mechanisms** — same outcome, different controllability | Card 33519 exposes an `is_test` parameter defaulting to `False`; the CBDF/CADF family on 4793 (43237, 42683) **hardcodes** `NOT IN (SELECT DISTINCT mobile FROM ptl_internal_users)` with no parameter. **Both DO exclude internal users** — this is an inconsistency in *how* exclusion is controlled, not a missing exclusion | Audit the ~20 remaining metric cards on 4198/4569 to confirm each excludes internal users at all, then standardise the mechanism. **Do NOT add exclusion to 43237/42683 — it is already present**, and re-adding it would double-exclude | **OPEN** — downgraded from critical; the earlier framing wrongly implied no exclusion |
| ~~**G-007**~~ | ~~AOV date basis unreconciled~~ | **CLOSED 2026-07-30.** Card 33706 verified to use **`updated_at`** — the catalog was right, the prototype's `created_at` is wrong. Fix the prototype. **New finding split out as `G-135`:** the date basis also differs *within* the AOV family (33706/52889 `updated_at`; 37413 `created_at`) | Correct `M-008`/`T-033`; then resolve `G-135` | **CLOSED** |
| **G-135** | **The AOV family disagrees on BOTH revenue base and date basis** | Three genuinely distinct revenue computations — 33706 raw `estimated_fare`; 37413 current fare gated on a customer-notified weight revision, else falling back to `estimated_fare`; 52889 current fare unconditional plus discount added back — **crossed with two date bases** (33706/52889 `updated_at`; 37413 `created_at`). These are different metrics, not variants of one | Owner picks one revenue base AND one date basis as canonical AOV; the other two become named alternates or are retired | **BLOCKED** — owner |
| **G-136** | **Three Metabase connections in play — largely resolved, one residual** | **Investigated 2026-07-30.** The three are distinct Metabase *connection profiles*, all `engine: snowflake`: **db73 `SNOWFLAKE_NEW_INI`** (every metric card), **db83 `SNOWFLAKE_BUSINESS_ENGG_PRODUCT`** (card 33519), **db108 `SNOWFLAKE_NI_ELDORIA`** (the governed dbt layer D2 defers to). **Evidence they address the same objects:** db73 cards reference the *identical fully-qualified* tables that db83 card 33519 uses — `partload_application.orders`, `.order_fares`, `.quotations`, `partload_analytics.ptl_internal_users`. Different roles/warehouses over one account is the overwhelmingly likely reading. **Re-verified on db73 and now safe:** `T-001` (`state=3` Completed, `state=4` Cancelled — 8+ db73 cards), `T-010` (`estimated_fare/100`, card 33706), `T-011` (`total_fare/100`, cards 37413/52889). **Residual, still db83-only:** `T-001a` (the `0=Open, 1=Assigned, 2=Picked_up` labels — the only db73 card touching them, 33462, groups 0/1/2 unnamed) and **`T-012`** (`chargeable_weight/1000` — **no db73 card inspected references the column at all**) | Confirm `T-012`'s grams→kg scaling against any db73 card that uses weight before quoting a weight figure from a db73 metric. Optionally confirm with a DBA that db73/db83 share one Snowflake account | **OPEN — low** (downgraded from high) |
| **G-137** | **Inert and hardcoded filters — cards accept parameters they silently ignore** | (a) Cards **47540** and **48449** expose Start/End Date parameters that do nothing: the live SQL hardcodes `pickup_date >= '2026-02-01'` and references `{{start_date}}/{{end_date}}` only in a commented-out block. (b) **48449** also hardcodes `pickup_city IN ('Bangalore','Mumbai')` despite being named "City Wise" with no city template tag. (c) **49365**'s outer date filters work, but its `completed_orders` CTE hardcodes a `>= '2026-03-01'` floor, so an earlier Start Date **returns nothing rather than erroring** | **Raised with the card owners 2026-07-30** (owner decision: escalate AND keep the KB warning). Until a fix lands, treat every clubbing number as unfiltered-by-date. A user who sets a date range on these cards gets a plausible, silently wrong answer; on 49365 they get an empty result that reads as "no data" rather than "filter ignored". **Do not remove this row when the cards are fixed — close it with the date and the fixing commit/card version**, so the KB records that the trap once existed | **OPEN — high · ESCALATED** |
| **G-138** | **`{{frequency}}` means two unrelated things on dashboard 4569** | On card 43406 it selects **cohort-lag granularity** (M1/M3/M6/M12); elsewhere `frequency` refers to `oms_public.customers.frequency`, the **business/personal tier column** (`T-020`). One token, two meanings, one dashboard | Rename one before any NL interface maps user words onto parameters | **OPEN** |
| **G-139** | **Card 52889 sits in a different collection from its family** | It lives in collection "Raw tables" (5198), not "Business Observability" (5199) like every other 4198 card inspected | Confirm it is genuinely part of dashboard 4198's AOV family and not a stray | **OPEN — low** |
| **G-012** | **Two different definitions of "business user"** | `ptl_fe_events.user_type = 'Business'` (session conversion, `M-009`) vs `oms_public.customers.frequency IN (1,2,3,4)` (everything else, `T-020`) | Quantify overlap between the two populations; if they differ materially, `M-009` is not comparable to the other business metrics | **OPEN** |

## B. Prototype code defects (found by reading the code, not its comments)

| id | gap | detail | next_action | status |
|---|---|---|---|---|
| G-010 | Registry declares behaviour the builders don't implement | (a) `new_business_users` registered `simple` but SQL plan downgrades to `"authored"` — no first-order logic; (b) `avg_orders_per_trip` and `m1_business_retention_pct` emit only `excl_offline` despite declaring `both_bases`, so **ruling D3 is not honoured**; (c) `order_cancellation_reasons` is declared for 4 metrics and **never queried**; (d) `avg_orders_per_trip` applies neither internal- nor business-user filtering, unlike every other builder | Fix the builders or correct the registry declarations, then re-run `selfserve_nlq/run_tests.py` and confirm it reports zero failures (the harness prints a pass/fail count; it has no fixed expected total) | **OPEN** |
| G-011 | Clubbing population scope differs across cards | 33460 counts all non-cancelled states; 47540/48449/49365 restrict to completed only | Decide the canonical clubbing base; affects `M-007` | **OPEN** |
| G-029 | `sqlgen.py` comment contradicts its code | Comment claims "no fan-out (EXISTS not JOIN)" but `trips_sql` uses a plain JOIN | Verify whether `trips_sql` fans out; fix code or comment | **OPEN** |
| G-035 | `total_fulfilment_pct` names an unimplemented variant | Definition text references a `<60s excluded` variant that the code never builds — yet the review reports it (66%, Apr-26) | Implement it to match whichever `<60s` semantics G-002 settles on | **OPEN** |
| G-036 | `cadf_pct` omits a caveat its sibling carries | `cbdf_pct` carries the `<60s` caveat; `cadf_pct` does not, despite identical mechanism | Align the caveats | **OPEN** |

## C. Source & provenance gaps

| id | gap | next_action | status |
|---|---|---|---|
| G-013 | The `state` enum is verified from a card's `CASE` mapping, not a warehouse data dictionary | Confirm against a data dictionary or column comment to upgrade `T-001` from "verified via card SQL" to "verified via source of truth" | **OPEN** |
| G-037 | **The Notion doc "secondBrain" does not appear to exist in the connected workspace.** Named as a source in the KB brief. **Two independent searches** — `secondBrain` and `second brain` — returned zero matching pages; every hit was an incidental match on the word "second" in unrelated documents. **No substitute page was used**, deliberately: silently adopting a similar-looking page would have injected unaudited content under a source name the brief authorised | Owner to supply the exact page ID/URL, confirm it lives in a different workspace, or confirm it does not exist | **BLOCKED** — owner |
| G-038 | Metabase database-id ambiguity | Card 33519 is `database_id: 83`; prior artifacts flagged uncertainty between db108 and db73 for PTL. Three ids now in play | Confirm which Metabase database id(s) map to which Snowflake account/warehouse | **OPEN** |
| G-019 | Sheet-backed tables have unknown freshness | `gsheet_sync.ptl_offline_orders`, `.ptl_vendor_details`, `.ptl_table` are Google-Sheet syncs, not systems of record | Establish sync cadence and staleness for each | **OPEN** |
| G-009 | Offline `status_code → state` mapping is **UNMAPPED** | Unrecognised offline status values become `NULL`, silently dropping rows from both bases under ruling D3 | Obtain the offline status-code dictionary; map it explicitly | **BLOCKED** — owner |
| G-027 | Card 33519 is day-bounded, not a historical source | It hard-bounds `pickup_slot_start` to `CURRENT_DATE −1 .. +2` | Any metric citing 33519 as its source must be re-pointed at a historical card | **OPEN** |

## D. Naming, jargon, and collisions

| id | gap | next_action | status |
|---|---|---|---|
| G-014 | `SDD`/`NDD` mappings verified (`EDD_BUFFER_IN_DAYS` 0/1) but the **word expansions are inferred** | Confirm "Same-Day Delivery"/"Next-Day Delivery" with a product source | **OPEN** |
| G-015 | `EDD` expansion never stated | Confirm (likely "Estimated Delivery Date") | **OPEN** |
| G-016 | **Acronym expansions unconfirmed: `VSS`, `TOF`, `OS`, `OLC`, `WD`.** The first four are used throughout the review and expanded nowhere; `WD` is inferred from a card *title*, which §4 says is never evidence | Owner to supply expansions; `VSS` is load-bearing — it names the top-of-funnel surface in ~8 metrics. For `WD`, read card 34284's SQL | **BLOCKED** — owner |
| G-017 | House formulas use `so`, `mo`, `cac` with no expansion given | Obtain expansions from the PTL master instruction author | **BLOCKED** — owner |
| G-028 | `is_repeated_order` (card 33519) vs "repeat user share" (review) are **different concepts sharing a word** | Keep them lexically distinct in any NL interface | **OPEN** |
| G-023 | Dashboard 4569 carries **two incompatible retention/repeat taxonomies** | 3-way new/retained/reactivated (38287, 39117) vs binary lifetime new/repeat (39107, 39149); and intra-period repeat (39118) vs lifetime-tenure repeat | Pick one taxonomy for the KB; the other becomes an alias with a warning | **OPEN** |
| G-039 | **Cross-vertical metric-name collisions** (Argus backlog B-002) | `allocation %`: PnM = vendor-allocation quality vs PTL = `allocation/demand` funnel ratio — and PTL has a *second* "allocation" family (Allocation Acceptance Rate), risking self-collision. `CBDF`/`CADF`/`CAC`: same acronym family used by PTL **and** HCV, and HCV's own docs list this as an open question. `CAC`: PnM allocation-lifecycle code vs PTL demand-funnel `cac` — third sense. Also `conversion`, `NPS`, `GM%`. **Confirmed from PnM's MBR automation SQL:** PnM uses `allocation` as a completion **timestamp** (to bucket TPO by month), where PTL uses `allocation %` as a computed **ratio** — same word, different grammatical role entirely; and PnM's `conversion` = `orders/leads` (Nano-excluded), which PTL has no metric literally named. `CBDF`/`CADF`/`CAC`/`NPS`/`GM%`/`AOV`/`fulfilment` appear **nowhere** in PnM's automation, so those collisions are asserted by reference docs but **not evidenced in PnM code** | Namespace metric IDs per vertical before any cross-vertical NL interface ships | **OPEN** |

## E. Document defects in sources (do not silently correct)

| id | gap | status |
|---|---|---|
| G-008 | Customer NPS is **not comparable across Mar-26 → Apr-26** (4.45 → 53.85): methodology/scale break mid-April | **OPEN** |
| G-030 | Review column header reads `Feb-25` where `Feb-26` is meant, across all tables | **OPEN** |
| G-031 | Review's FCR% narrative says "stable" against a Dec-25 outlier of 21.5% | **OPEN** |
| G-032 | Review's return-trip% narrative claims both a "dip" and a "1pp jump" for the same period | **OPEN** |
| G-033 | Review's median-time-to-book insight text discusses repeat-order share instead | **OPEN** |
| G-034 | Review's earnings/trip insight is truncated mid-sentence in the source | **OPEN** |
| G-018 | **The partition-pruning anti-pattern is more widespread than first recorded.** Card 33519 has it in one *optional* filter (`DATE(col + INTERVAL '330 minutes')`) in the same card that carries a `-- KEY FIX` comment warning against it. **Worse (found 2026-07-30): card 33706 — a live db73 revenue/AOV card — uses `date(updated_at + interval '330 mins')` as its primary date predicate.** Wrapping the timestamp column defeats micro-partition pruning and forces a full scan | **Raised with the card owners 2026-07-30** alongside `G-137` (same likely owners, one conversation). Recommended fix supplied: keep the column bare and shift the bound — `ts >= DATEADD('minute', -330, {{d}}::timestamp_ntz)` — rather than wrapping the column. Until fixed, expect elevated runtime and warehouse cost on 33706 and on 33519's `pickup_date` filter path | **OPEN · ESCALATED** — a real cost/latency issue, not a style note |
| G-022 | **Title-vs-SQL mismatches** (all re-verified 2026-07-30): "Fullfillment %" cards **33466 and 43238 return 5 metrics; 37104 returns 3** (split by EDD, not 5 as first recorded); "Total Revenue" (37413) also returns AOV/vendor cost/GM; card 38900 "LTO" implies lifetime but buckets are period-bound; cards 41124/41509 say "First Order **Placed**" but filter `state=3` **completed**; 33485/37419 are **not** byte-identical duplicates as first recorded — same formula, different SQL text and display type | **OPEN** |
| G-024 | Card 39104 Monthly Churn % hardcodes `DATE_TRUNC('month', …)`. **Correction (2026-07-30):** it does not "ignore" a frequency filter — the card has **no `{{frequency}}` template tag at all**, in neither template-tags nor parameters. It cannot honour a grain it never exposed | **OPEN** |
| **G-140** | **Cards 39107 / 39149: the repeat flag fires in the acquisition period itself.** A window `MAX` marks the acquiring period "repeat" whenever it holds ≥2 orders, and **every subsequent period is unconditionally "repeat" regardless of order count**. The measure therefore saturates toward ~100% far faster than "repeat customer" intuitively implies | **OPEN** |
| G-025 | Cards 35397/39117/43406/44080 **hardcode** `category='Business'` — the dashboard's Customer Category selector has no effect on them | **OPEN** |
| G-026 | Cards 38287/39117/38900/41124/41509 reference `frequency` **unprefixed**; correct only because `orders` lacks that column — latent fragility | **OPEN** |
| G-020 | The "3 charters" framing (Booking Journey / Fulfilment / Unit Economics) is unconfirmed against a charter document | **OPEN** |
| G-021 | Intervention dates (4 Feb, 2 Mar, 7 Mar, 13 Mar) state **no year**; 2026 inferred. `3W` = three-wheeler is also inferred | **OPEN** |

## F. Internal inconsistencies between prior project documents

| id | gap | status |
|---|---|---|
| G-114 | v1 metric count: the journey proposal §E proposes **12** metrics including Time-to-Allocate P50 (#51); ruling **D6 locks 11**, deferring #51 to iteration 2.5. D6 wins per precedence; the journey doc was never updated | **OPEN** |
| G-115 | Unverified-row count: the journey doc says "~62 unverified rows"; the catalog's corrected tally is **64**. The journey text was never updated after the correction | **OPEN** |
| ~~**G-116**~~ | ~~Staleness fingerprints missing for ~20 cards~~ | **CLOSED 2026-07-30.** All **29 cards** this KB relies on now carry a `source_updated_at`, tabulated in [dashboards.md](./dashboards.md). The staleness check is live across every surface. **Spin-off finding → `G-136`:** the sweep revealed `database_id` is not uniform (metric cards are db73; card 33519 is db83) | Re-run the sweep whenever a topic file adds a new card dependency | **CLOSED** |
| **G-117** | **Arithmetic discrepancy in the source review.** It states CADF moved "+1.2pp" but its own figures give 13.81% − 12.99% = **0.82pp**. One of the three numbers is wrong. Per `B-033` this is exactly the kind of figure that reaches a leadership note. **Next action:** re-read the Notion review's CADF row and establish which value is authoritative | **OPEN — high** |
| **G-118** | **M-002 lineage divergence.** Catalog #19 and `metrics_registry.py:59` both name `card/33462`; dashboard 4198 also carries `card/33483` ("Total Orders") computing the same shape. Which is canonical for Completed Orders is unresolved — recorded rather than picked, per the precedence rule. **Next action:** compare 33462 and 33483 SQL; confirm with the metric owner | **OPEN** |
| **G-119** | **Do not "fix" Business Session Conversion's single base.** `both_bases = False` on M-009 is *correct* — D6's build note explicitly exempts #14 from the dual-base requirement. This row exists so a future session reading D3 does not treat correct code as a bug | **OPEN — informational** |

---

## F2. Strategic conflicts with the cross-vertical Metric Store (Project Argus)

| id | gap | detail | next_action | status |
|---|---|---|---|---|
| **G-132** | **PTL's architecture is the shape Argus rejected** | Ruling **D2** builds on raw `partload_application` with a hand-rolled metric registry, deferring a governed dbt layer. The Metric Store POV explicitly **evaluated and rejected** a "per-metric SQL template file" approach for its own programme, choosing dbt-authored, PR-gated definitions. PnM is hitting the same fork now — its standing rule is "no dbt model → not eligible for the metric store" — and is weighing re-pointing to the eldoria dbt layer to gain Argus eligibility. Nothing in the POV names PTL, so **this is not a violation today** | Decide whether PTL self-serve targets Argus eligibility. If yes, D2's "governed layer later" needs a date and the registry becomes an interim artifact. If no, record why PTL is exempt. This is a roadmap decision, not an analysis task | **BLOCKED** — owner |
| **G-133** | **No metric in this KB has a named owner** | Argus requires a named owner + reviewer sign-off for every admitted metric. `metrics.md` records formulas and sources but no owner for any of the 11 | Assign an owner per v1 metric and add an `owner` column to `metrics.md`. Cannot be inferred — must be supplied | **BLOCKED** — owner |
| **G-134** | **Argus's trust-footer requirement is only partly met** | Argus mandates every served value carry **value + freshness + lineage + confidence**. This KB supplies lineage (`source_ref`) and confidence, and freshness *where* `source_updated_at` exists — but `G-116` shows freshness is missing for ~20 cards, and the KB serves definitions rather than values | Close `G-116` first; then decide whether the self-serve engine's output must render a trust footer | **OPEN** |

## G. Coverage — the 74 catalog metrics not covered in depth

Ruling **D6** bounds v1 to 11 metrics; the owner ratified index-only treatment for the rest at the
build's checkpoint 2. Each metric below has an index row
in [metrics.md](./metrics.md) §2 with the catalog's verbatim status. **`next_action` for all:**
locate the backing card/source, read its SQL, and promote to a full `M-###` row.

| id | catalog # | metric | id | catalog # | metric |
|---|---|---|---|---|---|
| G-040 | 3 | PTL Awareness Rate | G-077 | 47 | Vehicle Space Utilization % |
| G-041 | 4 | VSS TOF — Serviceable Sessions | G-078 | 48 | Batch Acceptance % by Partners |
| G-042 | 5 | PTL Serviceable VSS % of Sessions | G-079 | 49 | Pickup/Delivery SLA Breach % |
| G-043 | 6 | PTL Card Tap Rate | G-080 | 50 | Allocation Acceptance Rate |
| G-044 | 7 | PTL Selection Rate vs FTL | G-081 | 51 | Time to Allocate P50 *(deferred it 2.5)* |
| G-045 | 8 | Outstation Search Rate | G-082 | 52 | % Organic Allocation |
| G-046 | 9 | PTL Activation Rate | G-083 | 53 | Reallocation Rate |
| G-047 | 10 | VSS→Quote Conv (New Business) | G-084 | 54 | GM% per PTL Order |
| G-048 | 11 | Quote→Order Conv (New Business) | G-085 | 56 | Return Trip % |
| G-049 | 13 | Avg Sessions Before First Order | G-086 | 57 | Monthly Active Owners (MAO) |
| G-050 | 15 | Overall Session Conversion | G-087 | 58 | New Owners Onboarded |
| G-051 | 16 | VSS→Quote Conv (All Business) | G-088 | 59 | Monthly Active Vehicles (MAV) |
| G-052 | 17 | Quote→Order Conv (All Business) | G-089 | 60 | New Vehicles Onboarded |
| G-053 | 18 | Median Time to Book | G-090 | 61 | Owner Onboarding Activation Rate |
| G-054 | 20 | Customer Rating / NPS | G-091 | 62 | Median Days Onboarding→First Trip |
| G-055 | 21 | Support Tickets per Order | G-092 | 63 | M1 Owner Retention % |
| G-056 | 22 | Support Ticket % | G-093 | 64 | % Trips On-Time Pickup (Supply) |
| G-057 | 23 | First Contact Resolution % | G-094 | 65 | % Trips On-Time Delivery (Supply) |
| G-058 | 24 | Escalation % | G-095 | 66 | Owner Batch Acceptance Rate |
| G-059 | 25 | L4 Tickets | G-096 | 67 | Owner Batch Completion Rate |
| G-060 | 27 | Cancellation Attribution % ⚠ | G-097 | 68 | SLA Adherence % by Owner |
| G-061 | 29 | Customer/Porter Attributed CBDF % ⚠ | G-098 | 69 | Partner Attributed Damage % |
| G-062 | 31 | Cust/Porter/Partner Attributed CADF % ⚠ | G-099 | 70 | Owner Earnings per Trip |
| G-063 | 32 | Perfect Order Experience % | G-100 | 71 | Trips per MAV |
| G-064 | 33 | On-Time Pickup % + Delivery % | G-101 | 72 | Partner NPS |
| G-065 | 34 | On-Time Pickup % | G-102 | 73 | Partner Support Tickets per Trip % |
| G-066 | 35 | On-Time Delivery % | G-103 | 74 | AppSheet Adoption |
| G-067 | 36 | Damage % | G-104 | 75 | Owner Earnings per MAV |
| G-068 | 37 | Weight Discrepancy % ⚠ | G-105 | 76 | Uptime % |
| G-069 | 40 | Repeat Rate (≥2 lifetime) | G-106 | 77 | Latency P95 |
| G-070 | 41 | Share of Orders from Repeat Users | G-107 | 78 | Booking Details Page Latency P95 |
| G-071 | 42 | Avg Txns per Business Customer | G-108 | 79 | Check Serviceability API Latency P95 |
| G-072 | 43 | Reactivation % | G-109 | 80 | Quote Generation API Latency P95 |
| G-073 | 44 | Median Days Between Orders | G-110 | 81 | Booking Creation API Latency P95 |
| G-074 | 45 | Share of Business Users | G-111 | 82 | Error Rate — Ktor & Job |
| — | — | — | G-112 | 83 | Booking Details Page Error Rate |
| — | — | — | G-113 | 84–86 | Serviceability / Quote / Booking API Error Rates *(3 metrics)* |

⚠ = the catalog itself marks these `contradicted—conflict` — its **highest-risk** label, meaning
sources actively disagree. Treat as higher priority than the plain `unverified` rows.

> **ID note:** `G-075` and `G-076` were never allocated (a numbering artefact caught in review).
> Per CONTRIBUTING §2 they are **retired, not reused**. This table holds 72 rows covering 74
> metrics — `G-113` covers catalog #84–86.

## H. Coverage — 93 dashboard cards not opened

**54** on dashboard 4198 · **28** on 4569 · **11** on 4793. (An earlier draft said "83" and omitted
the 4793 group entirely — the rows below are the authoritative count.)

Grouped by tab. **`next_action` for all:** open the cards, read their SQL, and either promote to
`M-###` rows or record why they are out of scope.

| id | surface / tab | cards | why not opened |
|---|---|---|---|
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
