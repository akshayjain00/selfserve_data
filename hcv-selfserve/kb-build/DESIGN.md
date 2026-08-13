# HCV self-serve knowledge base — design spec

**Status:** agreed 2026-08-14, not yet built. **Branch:** `claude/hcv-metric-catalog-map`
(cut from `claude/ptl-metric-catalog-map` @ `28703aa`).

This is the build record, deliberately kept **out of** `kb/` — mirroring PTL, where the process
trail lived in `coordination/kb-build/` and never shipped inside the deliverable.

---

## 1. Goal

Give HCV analytics a base-context knowledge base that any future session — human or AI — can load
and trust, so nobody re-derives HCV's business context from scratch and metric definitions stop
drifting silently across five disagreeing sources.

**Deliverable:** `hcv-selfserve/kb/` — seven markdown files, plus `WALKTHROUGH.md` and a published
HTML artifact once the seven are stable.

**Explicitly out of scope:** `selfserve_nlq/` for HCV. No metric registry, no `sqlgen`, no `ask.py`.
This is a **KB-only** engagement (owner decision, 2026-08-14). PnM and PTL both have a dry-run query
layer; HCV will not, until someone decides otherwise.

### Success criteria

1. A reader with zero HCV context can load `CONTEXT.md` alone and correctly route to the right file.
2. Every fact carries provenance, confidence, and — where the source has one — a staleness stamp.
3. No conflict between sources is silently resolved anywhere in the KB.
4. Every `N of M` pairing in the KB actually sums to `M`. (PTL shipped a bug where "20 full + 62
   index-only" never added to 85; a mechanical check is now standard.)
5. Passes a blind accuracy check by a reviewer given the sources and the bare claims, never the
   reasoning behind them.

---

## 2. What HCV actually has

Four documented sources, describing four largely **different** metric universes, plus a fifth
authority nobody has reconciled against.

| Source | Size | Nature |
|---|---|---|
| `hcv_metrics_queries.md` ("Final Query Pack") | ~10 metrics, 7 sections | Owner-authored, **reconciled** SQL. Tier-1, `9ft–19ft`, May–Jul 2026, month × category × distance |
| Notion **HSC : HCV Dashboard** → Metabase `dashboard/1882` | **54** metrics (23 base, 31 derived), ids `M001`–`M047` | Inventory grounded in observed card SQL. **16 contested definitions**, **10 design callouts**, ~14 documented filter/bug findings |
| Notion **HSC : HCV Deep Dive** → Metabase `dashboard/4146` | **34** metrics (16 base, 18 derived), ids `M001`–`M033` | Ops/supply funnel. **9 contested definitions**, **8 design callouts**, ~10 filter/bug findings. Spans **three DB connections** (70, 106, 108) |
| Google Sheet `HCV_Metrics_DD` | ~90 rows (count to be confirmed at build), 4 domains | Argus target-state dictionary: Allocation-SOT, Onboarding, Partner Lifecycle, OLC-Partner. Definition column is literally `Metric Definition {AI Enhanced}`; every row `Status = Pending`; `Definition Aligned with STL + Product & Business Director = FALSE` on every row |
| Governed metric store `metric.porter.*` | unknown extent | Surfaced by the Deep Dive: `map`, `accept_rate`, `average_order_value`, `cadf_customer_attr_pct`, `cadf_partner_attr_pct`, fulfilment, missed-order, CBDF, CADF, total login hours |

### Three findings that shape the whole design

**F1 — A governed metric store already covers HCV, and disagrees with everything else.**
This is PTL's `G-132` (Argus) inverted. For PTL, Argus had *rejected* the hand-rolled architecture.
For HCV, the store already exists **and conflicts with both the dashboards and the query pack**.
The sharpest case: the pack's MAP is login-based (`SUM(business_login_hours) > 0.5` per day);
`metric.porter.map` is order-based (≥1 completed order per month). Same name, different metric.

**F2 — The two Notion inventories have colliding ID spaces.**
On `dashboard/1882`, `M016` is Revenue. On `dashboard/4146`, `M016` is DAP. A bare `M016` is
ambiguous, and would collide again with PTL's `M-###` series.

**F3 — The pack and the dashboards measure overlapping things differently.**
The pack's revenue (`ceil(fare) + coupon + referral + subscription discounts`, `fare_type = 2`,
`is_current`) is exactly the formula the 1882 inventory flags as **gross booking value, not net** —
one of *four* live Revenue formulas on that dashboard.

---

## 3. Decisions locked (owner, 2026-08-14)

| # | Decision |
|---|---|
| **H1** | **KB only.** No `selfserve_nlq/` for HCV. |
| **H2** | **Location:** new branch `claude/hcv-metric-catalog-map` in `akshayjain00/selfserve_data`, cut from `claude/ptl-metric-catalog-map`, so `ptl-selfserve/kb/` sits beside it as the live template. Directory named `hcv-selfserve` (hyphen), matching `ptl-selfserve`. |
| **H3** | **Coverage:** the ~10 query-pack metrics get full `M-###` write-ups; every other HCV metric found across the two inventories and the Sheet gets an index-only row plus one `G-###`. |
| **H4** | **Metric store:** anchor on it. Every full `M-###` entry carries a `store_ref` naming its `metric.porter.*` counterpart (or `none`), plus an explicit statement of how the definitions differ. The KB becomes a migration map toward the store, not a competing definition set. |
| **H5** | **Ship `WALKTHROUGH.md` + a published HTML artifact**, built last, once the seven KB files are stable. |

---

## 4. File layout

Exact mirror of `ptl-selfserve/kb/`:

```
hcv-selfserve/
  kb/
    CONTEXT.md        ≤150 lines, HARD CAP — load protocol, precedence, hard rules, state of work
    business.md       B-###  HCV primer, glossary, dated value snapshot
    metrics.md        M-###  full entries + index-only rows
    data-model.md     T-###  tables, columns, enums, units, time bases
    dashboards.md            card rows keyed `metabase:card/NNNNN` — no new ID series
    GAPS.md           G-###  append-only
    CONTRIBUTING.md          row schema, provenance format, staleness, ID rules
    WALKTHROUGH.md           zero-context team guide (built last)
  kb-build/
    DESIGN.md                this file
    DECISIONS.md             append-only decision trail
    BOARD.md                 living status board
```

Four ID series only — `B-` business, `M-` metric, `T-` table/column, `G-` gap. Append-only, never
renumbered, never reused.

---

## 5. Row schema

Carried from PTL's `CONTRIBUTING.md` §2, with **two HCV-specific additions**.

| Column | Meaning | Required |
|---|---|---|
| `id` | `B-###` / `M-###` / `T-###` / `G-###` | always |
| `statement` | The fact, one sentence or one formula | always |
| `source_ref` | Where it came from (§5.1) | always |
| `confidence` | `verified` / `unverified` / `assumption` | always |
| `source_updated_at` | The source artifact's own last-modified stamp | only when the source has one |
| **`inventory_ref`** | **NEW.** Cross-reference to the Notion inventories, **never bare** — always `nb1882:M016` or `nb4146:M016` | metrics, if the metric appears there |
| **`store_ref`** | **NEW (H4).** The `metric.porter.*` counterpart, or the literal `none`. When one exists and differs, the difference is stated explicitly, not implied | full `M-###` entries, always |
| `aliases` | Other names — jargon, acronyms, card titles | if any |
| `note` | Caveats, conflicts, `see G-0##` | if any |

`last_verified` is declared **once per file** in the header, not per row. A file-level date is a
claim about every row in that file — do not refresh it unless every row was actually re-checked.

### 5.1 Provenance format

`repo@<commit-sha>:<path>#L<n>` for repo files — never a bare path or branch name. Two clones of
this repo exist on diverged branches; commit SHAs are the only stable citation.

- Metabase: `metabase:card/NNNNN` / `metabase:dashboard/NNNN`, with `database_id` where known
- Notion: `notion:HSC-HCV-Dashboard` / `notion:HSC-HCV-Deep-Dive`, snapshot-dated
- Sheet: `gsheet:HCV_Metrics_DD` + row identity, snapshot-dated
- Query pack: `pack:§N` (e.g. `pack:§2a`)

---

## 6. Precedence ladder

Replaces PTL's, HCV-specific:

1. **`hcv_metrics_queries.md`** — owner-authored, reconciled SQL, *for the metrics it covers*
2. **Observed Metabase card SQL**, as recorded in the two Notion inventories (`1882`, `4146`)
3. **Governed store `metric.porter.*`** — authoritative for **naming and governance**, but its
   formulas conflict with (1) and (2) in at least five places
4. **The inventories' own editorial judgement** — KPI tree, de-duplication rules, Doshi categories
5. **Sheet `HCV_Metrics_DD`** — target state, AI-drafted, unratified → `assumption` by default
6. **Card titles — never evidence.** Both inventories document title/SQL mismatches (a "Rejection
   rate" card computing acceptance rate; "wallet share" returning orders-per-customer; "Dryrun
   Completed/Accepted orders" returning distance distributions)

> **Absolute exception, carried from PTL.** When pack, card, and store disagree — and they do —
> **do not resolve it.** Record every side, set `confidence: unverified`, open a `G-###`. Silently
> picking a side converts a known unknown into an invisible error. It is the worst thing you can do
> to this KB.

---

## 7. Confidence and staleness

Three tiers, unchanged from PTL — deliberately **not** forked, because "same architecture across
verticals" is a design constraint:

- **`verified`** — read directly from underlying SQL/code, or an explicit owner ruling
- **`unverified`** — asserted by a source but not confirmed against SQL, or sources conflict
- **`assumption`** — inferred by reasoning, stated nowhere

**Reconciliation is recorded in `note`, not as a fourth tier.** The pack claims its revenue matches
the OMS+SO canonical logic to the rupee for May–Jul 2026; that claim is a `note` on a `verified`
row, phrased as what was reconciled, against what, on what date. Downgrading confidence is always
allowed; upgrading needs new cited evidence.

**Staleness:** each row carries `source_updated_at` where the source has one. Metabase cards do
(one `get_card` metadata call, **not** a query). Notion pages carry a snapshot date. Documents and
repo files do not, so the column is simply absent from tables whose sources have none.

---

## 8. Hard rules for `CONTEXT.md`

PTL's seven, adapted, plus three HCV-specific ones (**bold**).

1. **Never run a production query** without explicit owner go-ahead. Metadata reads only. If a
   definition can't be resolved from SQL text, that is an `unverified` finding — not a licence to run it.
2. **`dev_eldoria.sandbox.mbr_mapping_v2` is a write AND a prerequisite.** Pack sections 1–4 are
   unrunnable until someone `CREATE OR REPLACE`s it. It is a sandbox table with **no refresh
   contract** — any number derived from it is exactly as stale as the last manual run, and nothing
   in the warehouse will tell you when that was.
3. Never put credentials, tokens, or personal data in this KB. Column *names* are schema facts
   (`customer_mobile` ✓); values, phone numbers, emails, addresses are not.
4. **Aggregate-then-ratio** for every derived ratio. Never average daily ratios. **And never average
   percentiles** — a weekly p50 is not the mean of daily p50s. Both inventories name this as the
   single biggest roll-up trap; ~26 of the Deep Dive's 33 metrics are ratios or percentile
   distributions and cannot be summed or averaged across periods or segments.
5. **Non-additive counts must never be summed across periods** — DAP, Active Customers, Unique
   Booking Sessions, cross-serviceable drivers, and every cohort-retention matrix are
   `COUNT(DISTINCT)`. Summing daily DAP to a weekly figure double-counts partners.
6. **Two time bases coexist and are applied unevenly.** `hcv_overall_demand_mart.order_time` reads
   as already-IST; `oms_public.orders.created_at` is UTC and needs `+330 min`. Card 28841 (ATA) has
   a documented **IST double-shift** — it adds 5h30m to an already-IST column for bucketing while
   filtering on the un-shifted date. Never assume which basis a card uses; check.
7. **Tier is a business rule buried in SQL, not a governed dimension.** A hard-coded
   `CASE geo_region_id IN (1,2,3,4,5,6,8,9) THEN 'Tier 1' ELSE 'Tier 2'` is repeated across at
   least eight cards, and Tier is encoded inconsistently as `'Tier 1'` vs `'Tier1'` on different
   columns (`tier`, `tier_status`, `TIER`). A dashboard Tier selection can silently return empty.
8. Never inline a metric value into a definition. Values are point-in-time; they live only in
   `business.md`'s labelled snapshot section, tagged by **data period**, never by review name.
9. Divide-by-zero → **null**. Percentage movements in **"pp"**.

---

## 9. Coverage plan and the counting contract

**Full `M-###` write-ups — the query pack (~10):** completed orders, revenue, AOV, allocated %,
FF %, E-FF %, unique FF %, time-to-accept p50/p75/p90, MAP. Each carries `store_ref` per **H4**.

**Index-only rows:** the deduped union of `1882`'s 54, `4146`'s 34, and the Sheet's ~90 rows, minus
those promoted. Each gets one `G-###`. Rough estimate **130–140 rows** — the union of 1882 and 4146
is around 72 after their ~16 shared metrics collapse, and the Sheet overlaps that set only thinly
because it is largely partner/supply/onboarding surface that neither dashboard measures.

**The counting contract.** The estimate above is an estimate and must be labelled as one until the
de-duplication is actually done. Once done, the exact counts are established once and every
`N of M` pairing anywhere in the KB must sum to `M`. This is checked mechanically before ship.

**De-duplication** follows the four rules the 1882 inventory already states (filter→dimension;
bucketed CASE→bucket dimension; ratios parented to their base; genuinely different SQL stays
distinct), so the KB's collapse is traceable to a stated rule rather than to judgement.

---

## 10. Seed gaps — owner-blocked, already visible

KB-only means there is no separate `DECISION_LOG`; unresolved owner calls land in `GAPS.md` as
`BLOCKED — owner`. These exist before the build starts:

| Question | Conflict |
|---|---|
| **No north star** | `1882` recommends Completed Orders; `4146` recommends Fulfilment %. They disagree, and three-to-four co-equal headline scalars sit atop each dashboard |
| **Canonical revenue** | Four formulas on `1882`, plus the pack's, plus `metric.porter.*` |
| **Canonical AOV** | Three on `1882`, one more on `4146` (card 32713), plus `metric.porter.average_order_value` (`total_revenue_without_registration_income`) |
| **MAP / DAP definition** | Pack + dashboard: login-based (`business_login_hours > 0.5`, daily). Store: order-based (≥1 completed order, monthly) |
| **Allocation %** | Three formulas on `4146` (`(demand−CBDF)/demand`; `COUNT(allocated_driver_id)/COUNT(order_id)`; business-hours variant), plus the pack's `fo_driver_id IS NOT NULL` |
| **Fulfilment denominator** | Total demand vs unique demand vs business-hours placed — three denominators all presented as "fulfilment" |
| **CADF attribution base** | Card 32670 divides by total demand; the store divides by CADF, and has no "Porter" attribution variant |
| **Argus posture** | The store already carries HCV metrics that the dashboards re-derive in raw SQL against legacy `trucks.*`. Is HCV self-serve targeting the store, or working around it? |

---

## 11. Build order

Dependency-ordered; `CONTEXT.md` is written **last** because it summarises everything and is
hard-capped at 150 lines.

1. `CONTRIBUTING.md` — the schema contract first, so everything downstream conforms to it
2. `data-model.md` + `business.md` — from the two inventories, the pack's filter block, and the
   Deep Dive's source-table listing
3. `metrics.md` — the ~10 full entries from the pack, then the deduped index
4. `dashboards.md` — `1882`, `4146`, their cards, and the query pack itself as a source-of-record entry
5. `GAPS.md` — the 16 + 9 contested definitions, the ~24 filter/bug findings, the uncovered surface
6. `CONTEXT.md` — entry point, written last, line-capped
7. Verification gate (§12)
8. `WALKTHROUGH.md` + published HTML artifact

---

## 12. Verification gate

Runs before anything is called done, and before the artifact is published.

- **Blind accuracy check.** A reviewer is given the sources and the bare claims — never the
  reasoning for why they are right. Independence is the whole point.
- **Zero-context loadability test.** A fresh reader loads `CONTEXT.md` alone and is asked to route
  three tasks to the right file.
- **Mechanical coherence pass**, standard since PTL's post-fix audit found the fix had introduced
  a fresh bug:
  - every `G-###` / `M-###` / `T-###` / `B-###` cross-reference resolves to a row that exists
  - confidence tags balance — no row missing one, no tag outside the three
  - `CONTEXT.md` ≤150 lines
  - **every `N of M` pairing actually sums to `M`**
  - every `store_ref` is present on every full entry, and reads `none` rather than being absent
  - no `inventory_ref` appears bare — all are `nb1882:` or `nb4146:` prefixed

---

## 13. Known risks

- **`WALKTHROUGH.md` and the published artifact have no automated sync.** PTL's pair drifted once
  and was caught by audit, not by process. Any edit to one needs a deliberate matching edit to the
  other; this is stated in `CONTRIBUTING.md`, not left to memory.
- **The Sheet is an unratified AI draft.** Treating any of its ~90 definitions as authoritative
  would inject confident nonsense at scale. Ladder position 5 and `assumption` confidence are the
  guard; both must survive review pressure.
- **No number in this KB will have been validated against the warehouse** unless the owner
  explicitly authorises executing existing saved cards. Nothing is stakeholder-ready at ship.
- **`hcv_metrics_queries.md` currently lives in `~/Downloads`.** It is the top of the precedence
  ladder and is not version-controlled. It must be committed into `hcv-selfserve/` before anything
  cites it, or every `pack:§N` reference is unresolvable.
