# iteration-2 — importing the PTL weekly-report skill doc into `kb/`

**Status:** spec v4, awaiting owner review. Nothing written to `kb/` yet.
**Date:** 2026-08-11
**Source:** `notion:36a9c6eaaa6d809db065efc12ecf4f42` ("Skill.md — ptl-weekly-report", created
2026-05-25, content stamped through Aug 2026).

**Revision history.** Six blind gates across four revisions: fidelity · source coverage · reverse
coverage · dry-run implementability · v2 review · v3 review. **Three of the thirteen conflicts below
were, at some revision, confidently recorded as non-conflicts.** The audit trail is part of the
deliverable — a future session should be able to see which claims survived scrutiny and which were
corrected, rather than reading a clean document that hides its own error rate.

---

## 1. What this is

The source is the operational playbook for the PTL weekly report — the queries actually run and the
reconciliations actually performed. Scope split per R3: **Pass 1 takes the plumbing and the
conflicts; Pass 2 takes the reasoning.**

Three structural facts about the source govern everything below:

1. **It is newer than the KB** — Aug 2026 content vs `last_verified: 2026-07-29` → staleness sweep
   (`G-160`), independent of the import.
2. **It contradicts itself in at least twelve places** (§4.3). A self-contradicting source gets less
   weight, and the owner must see that rather than a smoothed version.
3. **Only 7 of its 1,079 lines name a Metabase surface** — and of those, one is a bare code comment
   and one is provably false. **Two claims survive the tier-3 bar** (§3).

---

## 2. Owner rulings — 2026-08-11

| # | Ruling |
|---|---|
| **R1** | New ladder tier: **reconciled operational SQL**, below card SQL, above the catalog. **Assigned per claim, not per source.** |
| **R2** | `query-rules.md` is created, but every rule carries an ID, a `source_ref`, a `tier`, and — where a KB row contradicts it — that collision **inline**. A colliding rule never ships alone. |
| **R3** | Import is **split**. Pass 1 = conflicts, corrections, cross-links, stale pointers. Pass 2 = the analytical layer. Each gets its own blind gate. |
| **R4** | **No numeric values** from the source. Dated events and rule thresholds are not values. |
| **R5** | `M-019` keeps `verified`. The clock divergence is its own conflict (#11) and gap (`G-169`). |
| **R6** | Weekly cuts **ask the requester which week convention they mean** before running. |
| **R7** | CONTEXT.md budget ≤150 → **≤175**. |
| **R8** | Where a tier-3 claim outranks a KB row, that row's `statement` is **CORRECTED**, not merely annotated — with the superseded wording preserved verbatim in its `note`. Without this, tier 3 produces outcomes indistinguishable from no ruling at all. |
| **R9** | Every Notion-sourced addition to an **existing** row carries an inline `[unverified · notion:36a9…]` marker at the point of insertion. Amended rows have one row-level `confidence`; without the marker an unverified addition silently inherits `verified`. |
| **R10** | **Every row this import creates or amends is `unverified`.** Tier governs precedence, never confidence. Stated as a ruling because three revisions carried it only as a pass condition. |

> **Recorded objection to R6** (v2 gate): making the interrogative a *pass condition* changes KB
> behaviour before `G-154` is ruled. **Answered:** R6 picks no side, which is what CONTRIBUTING §6
> requires of an unresolved conflict. Recorded so a later session sees it was raised and addressed.

---

## 3. Precedence — R1 applied per claim

```
1. Observed card SQL                            ← strongest
2. DECISION_LOG D1–D7                           ← owner rulings
3. Reconciled operational SQL                   ← NEW (R1)
4. iteration-1 metric catalog
5. journey / proposal docs · UNreconciled operational SQL
6. Notion Product Ops Review                    ← weakest for definitions
```

**Tier 3's bar:** executed against production **and** reconciled against a **named** Metabase surface.
Tier is a property of the *claim*, never of the document. The absolute no-resolve exception (levels 1
vs 2) does not extend to tier 3.

**"Reconciled" means the reconciliation demonstrably happened** — not that the source asserts it.
Two claims that name a surface fail on exactly this, for reasons a reader will otherwise miss:

### 3.1 The audit — seven lines name a surface, two claims clear the bar

| source claim | surface | verdict |
|---|---|---|
| Monthly date basis (`updated_at`) | 4632 — *"Consistent with"*, *"verified against"* | **tier 3** |
| Monthly internal-user exclusion (`NOT IN` vs anti-join) | 4632 — *"Different result… (verified gap)"* | **tier 3** |
| Monthly revenue base (`order_fares.total_fare`) | 4632 — *"Does not match… discount not applied"* | **tier 3** |
| Cancellation family / terminal denominators | 4793 — *"match… exactly"* | **tier 5** — the reconciliation is **falsified** (§3.2) |
| Conversion funnel | *"— Dashboard reference: Metabase 4632 / 9771305"* | **tier 5** — a bare code comment asserting a *reference*, not a reconciliation; and §6.3 records `9771305` as not established to be a card |
| Week Sun→Sat · namespace · corridor/clubbing · allocation clock ("Metabase", no ID) · morning-slot `<60s` · Business = `dim_customers` · one-active-row | — | **tier 5** |

### 3.2 The 4793 claim is falsified — which demotes it

The source says *"match Metabase dashboard 4793 exactly"*, then mandates `state IN (3,4)` denominators.
`metrics.md:89` records 4793's own card 43237 using an **unconditional** `COUNT(DISTINCT order_id)`.
The reconciliation the claim rests on did not happen, so the claim does not clear tier 3's bar.

**This is not a new falsification clause** — it is the existing bar applied honestly. v2 and v3 both
accepted a *claim of* reconciliation as reconciliation. Recorded in `G-168` as first-order evidence
about the source's reliability.

### 3.3 Dispositions — where R8 actually bites

| KB row | its provenance | source tier | outcome |
|---|---|---|---|
| `T-033` order/AOV time basis | `repo@…` + catalog, **`unverified`** | **3** (4632) | **source wins → CORRECT the row** (R8), superseded wording to `note` |
| `M-008` AOV revenue base | **`unverified`** — 3 competing bases | **3** (4632) | **source wins → CORRECT the framing** to the cadence split (R8) |
| `T-023` exclusion mechanisms | cards 33519 + 43237, **`verified`** | 3 (4632) | **source loses** (tier 1 > 3) → annotate both, do **not** correct |
| `B-060` house formulas | `local:…`, `unverified` | **5** (§3.2) | **neither wins** → annotate both, `G-161` |
| `M-003`/`M-005`/`M-006` | cards, **`verified`** | 5 | **source loses** → record as a production deviation |
| `B-031` week · `B-061` cuts | `local:…`, `unverified` | 5 | **neither wins** → annotate both |
| `B-034` timezone | card 33519, `verified` | 5 | source loses, and is self-contradicted → §4.3, not a KB conflict |
| `T-024` | card 33519, `verified` | 5 | source *adds* a consequence → **no conflict** |
| `T-041`,`T-045`,`T-048`,`T-062` | `## Tables` — **no `source_ref` column** | 5 | source adds columns. `T-062` **is** in conflict on the time-column name → conflict #13 |

> **Where the teeth landed, and where they did not.** v3 expected R8 to bite on `B-060`. Applying the
> bar honestly moved it off `B-060` entirely and onto `T-033` and `M-008` — both `unverified`, both
> squarely inside the monthly reporting the 4632 reconciliation actually covers. Tier 3 now corrects
> two rows and overreaches into none.

---

## 4. Conflict register — thirteen

| # | KB position | source position | disposition |
|---|---|---|---|
| **1** | `B-031` + CONTEXT hard rule 4: **Sat→Fri** | **Sun→Sat**; `DATE_TRUNC('week')` rebuckets Sunday | `G-154`. Both tier 5 → neither wins. Annotate `B-031` itself — it is a **binding house rule**; annotating CONTEXT alone is insufficient. Source self-contradictory here (§4.3a). Workspace `CLAUDE.md` is a third voice. **BLOCKED — owner.** |
| **2** | data-model header + `T-040`–`T-051`: one namespace | `partload_application.orders` ≠ `prod_curated.…orders` | `T-074` + `G-155`. ⚠️ **Straddles tiers:** the *internal-users* half is tier 3 (4632); the *orders* half is tier 5. Record per-half. Weakened by §4.3f. Scope includes a **pre-existing** KB inconsistency (§4.2). |
| **3** | `T-001a`: `1=Assigned, 2=Picked_up` | `1=placed, 2=assigned` | note on `T-001a`; `G-156` → folds into `G-136` |
| **4** | `T-033`: basis "unreconciled → `G-007`" | weekly `created_at` / monthly `updated_at` | **`T-033` is CORRECTED** (R8, tier 3). Repoint its dangling `→ G-007` at **`G-135`** (`G-007` closed 2026-07-30). Amend `M-002` — the basis shifts the **order count**, not only AOV. `G-158` |
| **5** | `M-003`/`M-005`/`M-006` (tier 1) · `B-060` (tier 5) | terminal-only `state IN (3,4)` | **`G-161`.** Source is tier 5 (§3.2) → loses to the metric rows, **ties** with `B-060`. Annotate all four; correct none. |
| **6** | `M-007`: batches **≥2 orders** | all `status=3` batches incl. solo; denominates on `batch_id` | **`G-162`**, cross-link `G-011`, `G-137`. The source's own QC check proves it: it asserts *clubbing ≥ 1.0*, but a ≥2-orders base floors at **2.0**. |
| **7** | `T-020` + CONTEXT "three facts" #2: `oms_public.customers` | **`dim_customers.frequency IN (1,2,3,4)`**, two join keys | **`G-163`**, cross-link `G-005`, `G-012`. ⚠️ One of the two joins is **not runnable** (§4.3k) — cite one, not two. |
| **8** | `T-023`: the two mechanisms have **the same outcome** | `NOT IN` vs anti-join give **different counts** | **`G-164`.** Owner ruling 2026-08-11: **annotate both, do not correct** — `T-023` is tier 1. Confounded with §4.3f anyway. **BLOCKED — owner.** |
| **9** | CONTEXT hard rule 7 + `T-031`/`G-018` | **prescribes** the wrapped-timestamp filter, 5 places | **`G-166`** (→ §E), extend `G-018`. Under R2 ships **paired with the pruning-safe rewrite**. |
| **10** | `B-057` + `G-002`: two `<60s` implementations | a **genuinely new third** — pre-08:00 bookings run the clock from 08:00 | **`G-157`.** ⚠️ v1 called the FF-denominator/cancel-numerator split "a fourth semantics"; it is **corroboration** of `G-002`'s two. |
| **11** | `M-019`: raw *order-created → first vehicle-assigned* | the **three-branch slot-anchored** clock | **`G-169`.** Different metrics, not one metric on two cards. R5 keeps `verified`; see §4.4. |
| **12** | `T-006`: SDD/NDD via `EDD_BUFFER_IN_DAYS` 0/1 | SDD/NDD by pickup-slot date vs earliest order-creation date in the **batch** | **`G-170`**, cross-link `B-044`/`B-045`, `G-014` |
| **13** | `T-062`: time column is `event_ts` | `event_timestamp`, in five working queries | **`G-159`.** v3 declared this a conflict in §3.3 but omitted it from the register, so its two-sidedness went unchecked. |

**Not conflicts:** `T-004` one-active-row (declared-inactive / ops-active satisfies both positions) →
note + `G-165`. Timezone non-equivalence → source defect (§4.3e).

### 4.2 Pre-existing KB inconsistency — in scope for `G-155`

`data-model.md:75-84` files `ptl_internal_users` under `PROD_CURATED.PARTLOAD_ANALYTICS`; `metrics.md:93`
quotes card 43237's **unprefixed** reference; `T-023` quotes both. Independent of this source.

### 4.3 The source's self-contradictions and defects — `G-168` (§E)

(a) bans `DATE_TRUNC('week')`, uses it · (b) mistakes register argues both sides of the sub-60s
denominator · (c) spells one route two ways · (d) dates the slot change Jun 14 throughout and Jun 11
once · (e) forbids `+ interval '330 mins'` at slot boundaries then uses it in the slot-anchored
allocation formula — the most boundary-sensitive computation in the document, and IST has no DST, so
the prohibition has no stated mechanism · (f) mandates the prefixed internal-users table, then writes
*"same table as order queries, no prod_curated prefix"* — **directly undercuts conflict #2** · (g) an
allocation branch heading says "ORDER's PICKUP SLOT DATE" while the SQL compares `created_at` to
`pickup_slot_start` · (h) **three** routes recorded as closed still appear in the corridor map ·
(i) **Rule 2 states `updated_at` is "NOT used", flatly**, while the monthly rules mandate it — conflict
#4 presents as an orderly cadence split what the source states as a prohibition · (j) section numbering
is broken: no `Step 10` or `Step 12` heading exists; `§10.x` is nested under Step 11 and `§12.x` sits
after Step 13, so **section anchors cited anywhere are unstable** · (k) the funnel's Business filter
joins `dc.customer_id = el.customer_id`, but the CTE never projects `customer_id` — **the filter
cannot execute**, which weakens conflict #7 · (l) two byte-identical duplicated lines.

### 4.4 `M-019` — R5 stands, premise recorded

Card 42081 is in `G-152`'s **unfingerprinted** list and `metrics.md:226` cites it **by title**, which
CONTRIBUTING §4 says is never sufficient. The confidence question rides on `G-152`, not this import.
`G-171` asks the narrow question (does 42081's SQL match the wording?); `G-169` the substantive one.

---

## 5. Pass 1 — `data-model.md`

### 5.1 Amend in place — R9 applies to every row here

**Eight of the rows below carry row-level `confidence: verified`** — `T-004`, `T-023`, `T-024`,
`T-030`, `T-041`, `T-045`, `T-048`, `T-062`. `T-033`, `T-022`, `T-072` are `unverified`.

**Target cell for markers and `→ G-###` pointers:** the row's `note` column where one exists
(`T-004`, `T-023`, `T-024`, `T-030`, `T-033`). The `## Tables` rows (`T-041`, `T-045`, `T-048`,
`T-062`) have **no `note` and no `source_ref` column** — their additions go in the `key columns` /
`role` cell with the marker inline, and the `→ G-###` pointer moves to the **gap row**, which
back-references the table row. This asymmetry is a consequence of the existing schema, not a choice.

| row | change |
|---|---|
| file header | qualify `Primary DB in card SQL: PROD_CURATED` → `T-074` |
| `T-004` | add the source's actual new fact — *exactly one active row per order, safe to join without dedup* — and its implication for catalogue #37 → `G-165`. **Not a conflict.** |
| `T-023` | **annotate** "same outcome" as contested (owner ruling; do **not** correct) → `G-164` |
| `T-024` | add the consequence: duplicate rows; omitting `is_active` inflates city counts |
| `T-030` | note the source's slot-boundary claim → `G-168`. `T-030` does **not** assert equivalence; `B-034` and CONTEXT hard rule 7 do |
| `T-033` | **CORRECT** (R8): weekly `created_at` / monthly `updated_at`; superseded wording to `note`; repoint `→ G-007` at `G-135` |
| `T-041` | add `created_at`, `vehicle_id` |
| `T-045` | add `order_id`, `is_current_fare`; note the join-path and fare-selector divergence from `T-005` |
| `T-048` | add `order_external_id`, `status`; joining on `order_id` returns **zero rows silently** |
| `T-062` | add `app_session_id`, `variable_attr`, `customer_mobile_number`, `application_version_code`, the `variant_name` value space; time-column conflict → `G-159`; record that four production queries segment via `dim_customers` and **`user_type` appears zero times in the source** → `G-012` |
| `T-022`/`T-072` | operational evidence that `dim_customers` is in live PTL use → `G-005`, `G-132` |

**Dropped as redundant** (CONTRIBUTING §8): `T-044` (already lists `is_active`), `T-013` (already *is*
the `discount_amount_minor_units` row).

### 5.2 New rows — three, contiguous

| id | home | content |
|---|---|---|
| `T-074` | **new** `## Namespace — which schema a table resolves in` (5-col, with `source_ref`) | Namespace is not uniform. ⚠️ **Record per half:** the internal-users claim is tier 3, the orders claim tier 5. Blast radius: `M-005`/`M-006` quote the unprefixed table. Source self-contradicts (§4.3f). → `G-155` |
| `T-075` | **same new section** — *not* `## Tables`, whose analytics table is 4-col with **no `source_ref`** and would ship this row with no provenance (CONTRIBUTING §1) | `ptl_discount_groups` — `group_name` ∈ {CG,TG1,TG2}, `city`, `uuid`; joins `dim_customers` on `customer_uuid = uuid` |
| `T-076` | **Units** block, beside `T-010`–`T-013` | Type traps requiring casts: `ptl_internal_users.mobile` numeric vs `ptl_fe_events.customer_mobile_number` string; `vehicle_id` string in the confirm-click event, number in VSS; `route_id` a JSON string needing `TRY_TO_NUMBER` |

---

## 6. Pass 1 — `metrics.md`, `business.md`, `dashboards.md`

**R9 applies to every amendment below.** Ten of these rows carry `verified`: `M-002`, `M-003`,
`M-005`, `M-006`, `M-007`, `M-009`, `M-014`, `M-019`, `B-034`, `B-057`. v3's marker rule covered only
`data-model.md`, leaving v1's worst defect alive in two further files.

### 6.1 `metrics.md`

**Correct (R8):** `M-008` — the source splits revenue by cadence (weekly `estimated_fare`, monthly
`order_fares.total_fare` with the discount join), mapping the KB's three competing bases onto a
cadence split. Tier 3 vs `unverified`. Superseded framing to `note`. → `G-004`, `G-135`, `T-013`.

**Annotate:** `M-002` (basis shifts the count; KB counts `DISTINCT external_id`, source `DISTINCT id`)
· `M-003`/`M-005`/`M-006` (terminal-denominator **deviation**, source tier 5 → `G-161`) · `M-007`
(solo-batch conflict → `G-162`, `G-011`, `G-137`) · `M-009`, `M-014` (→ `M-023`, `G-012`) · `M-019`
(§4.4 → `G-169`, `G-171`).

**New — three, contiguous:** `M-021` First Vehicle Allocation Time · `M-022` Final Confirmed Vehicle
Allocation Time · `M-023` VSS→BookNow conversion. All `unverified` (R10).

`M-021`/`M-022` carry the three-branch slot-anchored clock **with the source's ⚠️ CRITICAL warning in
its actual mechanic**: compare the **order-creation date** to the **pickup-slot date**, never to the
assignment date. Base `state=3`; 0-minute orders retained. `M-022` − `M-021` is the driver-replacement
signal → candidate coverage for catalogue **#53** (`G-083`; the "possibly untrackable" language is
`G-151`'s and does not cover #53).

### 6.2 `business.md`

**Annotate:** `B-031` (on the binding-house-rule row) · `B-034` (source defect; confidence unchanged)
· `B-057` (the new third `<60s` variant) · `B-060` (**neither wins** — both tier 5) · `B-061` · `B-074`
(a third independent derivation of aggregate-then-ratio).

**New — seven, contiguous**, into *Interventions & GTM events*: `B-075` slot-config timeline incl. the
two mixed transition days · `B-076` Jun 14 as a hard structural break · `B-077` Bangalore after-slot
mechanism, carrying the instruction **not** to call it "ghost assignment" · `B-078` Surat as a standing
watch route · `B-079` experiment registry · `B-080` TG/CG classification **including the exposure event
set and `first_seen_date`** · `B-081` SDD/NDD batch-level classification → conflict #12.

### 6.3 `dashboards.md`

Add **`dashboard/4632`** — the monthly reconciliation surface, referenced **six** times, recorded
nowhere in the KB, absent from the 93-unopened count. Record `9771305` as an **unresolved reference**
(7 digits against 5-digit card IDs). Note the Metabase-P90-vs-report-P80 mismatch. → `G-167`.

---

## 7. `query-rules.md` — R2

New **`Q-###`** series (CONTRIBUTING §2 amendment, §8). Columns:
`| id | rule | source_ref | tier | confidence | collides_with |`

`tier` per §3.1 — **every rule in this file is tier 5**, since both tier-3 claims are monthly-report
definitions that live in `metrics.md`/`data-model.md`, not query rules. `collides_with` names the KB
row and states its position inline. **A rule with a non-empty `collides_with` may never be read alone.**

**Header:**

> This file records **observed production practice, not governed definition.** Every rule here is
> **tier 5** — below the iteration-1 catalog. Nothing here has been checked against card SQL or the
> warehouse. Where a rule carries a `collides_with`, **the KB row named there outranks it.**

**Pass 1 sections:** 1 Namespace · 2 Date basis · 3 Denominators · 4 Join keys and silent-zero-row
traps · 5 Units · 6 Aggregation · 7 Corridor map.
**Pass 2:** QC harness · scrubbed mistake register · interpretation heuristics · decomposition methods.

⚠️ The mistake register **cannot** be imported "near-verbatim" — v1 said so and contradicted its own
no-values rule. Pass 2 imports it scrubbed, or not at all.

**Section 7** carries the corridor `CASE` as a **mapping table**, not a query — including that
`'Chennai - Erode'` is dissolved, that `'Chennai - Puducherry '` carries a **trailing space**, and that
**three** closed routes still appear (`G-168`).

---

## 8. `CONTRIBUTING.md` — three amendments, **in this order**

1. **§6** — insert tier 3, its per-claim bar, the "reconciled means demonstrably reconciled" clause,
   R8's correction authority, and the note that the no-resolve exception does not extend to it.
2. **§2** — authorise the **`Q-###`** series, with `tier` and `collides_with` required.
3. **§10.3** — budget ≤150 → **≤175** (R7).

**Sequencing is mandatory** — amendment 3 is a prerequisite for §9 (CONTEXT is **150 lines today**,
lands at ~159 with the ladder edit).

**Rollback.** If Pass 1's gate rejects the import after these land, amendments 1–2 authorise a tier and
an ID series no file uses. Inert, not harmful — but record it so a later session does not read tier 3
as evidence an import succeeded.

---

## 9. `CONTEXT.md`

- **The precedence ladder** (CONTEXT restates it in full) → six tiers + the tier-3 exception note.
  **v3 amended CONTRIBUTING's ladder and missed this one** — and CONTEXT is loaded on *every* task
  while CONTRIBUTING is loaded only when editing, so the entry point would have contradicted the
  rulebook.
- **Hard rule 4** → R6.
- **Hard rule 7** → carries the same `+330 min`/`CONVERT_TIMEZONE` equivalence as `B-034`; add the
  source-defect note here too.
- **"Three facts" #2** → flag that production segments Business off `dim_customers` (`G-163`).
- Topic map: a **routing row** for `query-rules.md` with a task phrasing — *"How do I write this query
  / why did my query return zero rows?"*
- Source locations; Dashboards line → 4632; State of the work → the import, the sweep, revised counts.

---

## 10. `GAPS.md` — `G-154` → `G-171`, routed to schemas they can satisfy

| section | schema | gaps |
|---|---|---|
| **§A** conflicts | `id \| gap \| conflicting positions \| next_action \| status` (5) | `G-154`, `G-155`, `G-156`, `G-157`, `G-158`, `G-159`, `G-161`, `G-162`, `G-163`, `G-164`, `G-169`, `G-170` (12) |
| **§C** source & provenance | `id \| gap \| next_action \| status` (4) | `G-160`, `G-165`, `G-167`, `G-171` (4) |
| **§E** document defects | `id \| gap \| status` (3) | `G-166`, `G-168` (2) |

**Pass 1 does not begin until every column is authored for every row.** v2 and v3 both stated the rule
and supplied three columns.

`status` ∈ `OPEN` · `OPEN — high` · `OPEN — low` · `BLOCKED — owner`.

**Five gaps are `BLOCKED — owner`** — reconciled with §12.3, which v3 contradicted: `G-154` (ruling),
`G-155` (row-count divergence is not settleable by reading which object a card names), `G-161`
(denominator choice is a definitional decision), `G-163` (business definition), `G-164` (settleable
only by running both forms). GAPS.md defines `BLOCKED` as "needs a person/decision" — v3 filed
`G-161`/`G-163` as `OPEN — high` while §12.3 listed them as needing owner decisions.

---

## 11. Verification

| check | how | pass condition |
|---|---|---|
| **Values** | before: `grep -oHE '₹\|[0-9]+,[0-9]{3}\|[0-9]+(\.[0-9]+)?[ -]*([a-z]+ )?(%\|pp\|kg\|min\|hr\|orders\|batches\|trips\|sessions)\|~[0-9]\|[0-9]{2}:[0-9]{2}' kb/*.md \| sort \| uniq -c > before.txt`; after → `after.txt`; `diff`. Unescape `\|` when running. | only the diff's added lines are inspected; each individually justified as a dated event or rule threshold. Baseline ~162 across 129 lines, so a count delta is not a signal — the diff is. `grep -o`, never `-c` |
| **New rows** | grep the 13 new rows | every one `unverified` (R10) |
| **Amended rows** | grep every row named in **§5.1, §6.1 and §6.2** | every Notion-sourced addition carries `[unverified · notion:36a9…]` (R9) |
| **R8 corrections** | inspect `T-033`, `M-008` | statement corrected; superseded wording preserved verbatim in `note` |
| **No upgrades** | `git -C <repo-root> diff -- ptl-selfserve/kb/`; if committed, `git diff <base-sha>` | zero `unverified`→`verified`; `M-019` still `verified` |
| **No drift** | `grep -ohE '\x60verified\x60' kb/*.md \| wc -l` before/after. **Baseline is 56.** Do not grep bare `verified` — it matches `unverified`; and `confidence: verified` occurs **zero** times, the KB writes it backticked | count does not increase. Pair with the diff check — a count cannot detect a swap |
| **Conflicts two-sided** | inspect | each of the **13** annotates the KB row *and* opens/links a gap |
| **Gap rows complete** | inspect | 5 columns on the 12 §A rows, 4 on the 4 §C rows, 3 on the 2 §E rows |
| **Gaps executable** | inspect | metadata read, card-SQL read, or owner decision. Five are `BLOCKED — owner`; none implies a read that cannot settle it |
| **`last_verified`** | `git diff` **five** headers — `business.md`, `metrics.md`, `data-model.md`, `dashboards.md`, `CONTEXT.md` | all still `2026-07-29`; and every corrected/amended row carries an inline `last_verified 2026-08-11` override in its `note` (CONTRIBUTING §2/§8) |
| **Routing** | inspect CONTEXT | `query-rules.md` has a task phrasing, not a mention |
| **Ladder parity** | diff CONTEXT's ladder against CONTRIBUTING §6 | identical six tiers in both |
| **Budget** | `wc -l kb/CONTEXT.md` after §8.3 | ≤175 |

### 11.1 Output test — blind, post-implementation

Fresh agent, `kb/` only. Grader: a second agent given this table and the transcript. Pass = 7 of 8,
**last row mandatory**.

| question | correct behaviour |
|---|---|
| "Completed orders last week by city" | **asks which week convention** (R6) |
| "Revenue for June" | monthly `updated_at` + the namespace trap |
| "Allocation P80?" | two metrics exist; asks which |
| "Why is Bangalore cancel high?" | the mechanism; **never "ghost assignment"** |
| "CBDF slot-split, Jun vs Jul" | refuses the sub-bucket comparison across the break |
| "Clubbing on Chennai–Erode" | corridor dissolved |
| "Is fulfilment 62%?" | no number; definition + the denominator conflict |
| **"CBDF definition on 4793?"** | quotes `metrics.md`, **not** `query-rules.md` |

**If `query-rules.md` is quoted as governed definition, R2 has failed and the file is cut.**

---

## 12. Open items

1. **Confirm the Notion page ID**; capture its last-edited timestamp for `source_updated_at`.
   If wrong, every `source_ref` becomes `local:` — which caps **confidence**, not **precedence**, so
   §3.1's tier assignments survive (R10 already puts everything at `unverified`). The real cost is
   that these rows become permanently unupgradeable via this path.
2. **A second source exists and nobody has read it** — `references/experiment_report_prompt.md`, cited
   in the front matter as the authority for the experiment reporting flow. `B-079` and the Pass-2 plan
   both depend on it.
3. **Corroboration, deliberately not banked as an upgrade.** The source independently supports the
   KB's weakest units facts — `chargeable_weight` in grams (`T-012`, flagged db83-only under `G-136`)
   and `estimated_fare` in paise (`T-010`). CONTRIBUTING §4 forbids an upgrade on agreement between
   unverified sources. Record the corroboration **in `G-136`**, where it changes the next_action's
   priority, and nowhere else.
4. Owner decisions: `G-154`, `G-155`, `G-161`, `G-163`, `G-164`.

---

## 13. Pass 2 — scoped, not specified

~41 items: demand-vs-fulfilment decomposition and the >3% MTD trigger · `completed = booknow × FF%` ·
the MTD window rule (first day of W1's **end** month) · route closures and the proportional
counterfactual · the price-change method and inbound/outbound separation · CADF bucket schemes and the
>15% trigger · CBDF/CADF spike and time-bucket meanings · the VSS pattern→action table · the experiment
verdict lattice · the negative knowledge that allocation P50/P80 is **uncorrelated** with FF dips · the
QC harness · the scrubbed mistake register. Own spec, own gate.

---

## 14. Out of scope

- `pnm-selfserve/`, `hcv_selfserve/`. **PTL KB only.**
- Running any query · resolving any gap.
- Report-production mechanics: Notion publication, section templates, column formats, rerun prompts,
  canonical query bodies. The corridor `CASE` as a **mapping table** is the one deliberate exception.
