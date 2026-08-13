# HCV KB build — board

**Living document.** Overwrite freely; the durable record is [DECISIONS.md](./DECISIONS.md).
Last updated 2026-08-14. Spec: [DESIGN.md](./DESIGN.md) (v2).

**Goal:** `hcv-selfserve/kb/` — a base-context knowledge base for HCV that a cold reader can load
and trust.

---

## Coordination mode

**This folder is the coordination record** — `DECISIONS.md` (append-only, orchestrator-only) +
`BOARD.md` (living state) + `DESIGN.md` (the spec). It is named `kb-build/` rather than
`coordination/` to mirror PTL, whose trail lived in `coordination/kb-build/`. No separate
`coordination/` folder exists in this repo; do not create one.

**Mode: SEQUENTIAL** (recorded 2026-08-14, per the four-question test)

| Question | Answer |
|---|---|
| Decomposable into sub-tasks not needing each other's live output? | **Partly.** Steps 2 → 3 → 4 → 5 → 6 are strictly ordered — `CONTRIBUTING.md` sets the schema every later file conforms to, and `CONTEXT.md` summarises all of them |
| Breadth or depth? | **Depth** for steps 2 and 6. **Breadth** only inside step 3's per-metric comparison |
| Can parallel workers avoid writing the same section? | Only in step 3 — every other step writes one file end-to-end |
| Worth the token cost + a synthesis step? | Not for steps 2, 4, 6. **Arguably yes for step 3's ~12 independent store-vs-pack-vs-card comparisons** |

**Decision:** SEQUENTIAL throughout, with one reviewed exception — **step 3's evidence-gathering is
a candidate for parallel fan-out and will be put to the owner before spawning**, since house rules
require explicit approval for parallel fan-out on production work. Blind checkers used as gates
(steps 0 and 7) are standing-authorised and are not fan-out.

**Roles:** orchestrator (this session) is the sole writer of `DECISIONS.md` and `BOARD.md`. Workers
return findings; they never write the shared record.

---

## Status

Steps map 1:1 onto DESIGN.md §14.

| # | Step | State |
|---|---|---|
| 0 | Design agreed, branch cut, query pack committed | **done** — `5a06a81`, `20f6416` |
| 1 | `CONTRIBUTING.md` — schema contract (§6.3) | **done** |
| 2 | `data-model.md` (§6.5) + `business.md` (§6.4) | **done** |
| 3 | `metrics.md` — full blocks (§6.7), then the deduped index; counts fixed (§11.2) | not started |
| 4 | `dashboards.md` — registers first, then cards (§6.8) | not started |
| 5 | `GAPS.md` — 25 contested defs, ~24 filter/bug findings, 18 design callouts, seed gaps, coverage rows (§6.6) | not started |
| 6 | `CONTEXT.md` — entry point, ≤150 lines, written last (§6.2) | not started |
| 7 | Verification gate (§15) | not started |
| 8 | `WALKTHROUGH.md` + published artifact (§6.9) | not started |

## Sources

| Source | Access | Notes |
|---|---|---|
| `hcv_metrics_queries.md` | ✅ committed `20f6416` | Top of the ladder; anatomy verified in DESIGN §10 |
| Notion `HSC : HCV Dashboard` | ✅ read | 54 metrics, 16 contested, 10 callouts, snapshot 2026-07-18 |
| Notion `HSC : HCV Deep Dive` | ✅ read | 34 metrics, 9 contested, 8 callouts, snapshot 2026-07-18 |
| Sheet `HCV_Metrics_DD` | ✅ read | ~90 rows; exact count confirmed at step 3 |
| Metabase (domestic) | ✅ live, pre-authenticated | `get_card` verified on 32713; returns `updated_at`, `database_id`, parameter defaults, native SQL |
| Governed store `metric.porter.*` | ✅ live via Data Catalog | `list_metrics` / `get_metric` verified. `D-004` is executable |

**Store metrics confirmed to exist** (read 2026-08-14, not reported second-hand):
`map` · `accept_rate` · `accepted_notifications` · `notification_acceptance_rate` ·
`avg_time_to_accept_seconds` · `total_accept_seconds` · `total_accepted_pings` · `cadf` ·
`cadf_customer` · `cadf_partner` · `cadf_customer_attr_pct` · `cadf_partner_attr_pct` ·
`login_hrs_per_active` · `orders_per_active` · `payout_per_active` · `spot_acquisition` ·
`cge_rc_m1_retained_customers`

### Conflicts verified first-hand — two are NOT in either Notion inventory

| # | Conflict | Status |
|---|---|---|
| 1 | **MAP** — `metric.porter.map` = "distinct partners who **completed at least 1 order**" (order-based); pack §5 = `SUM(business_login_hours) > 0.5`/day (login-based) | Reported by `4146`, now **verified from both sides** |
| 2 | **Allocation key** — `metric.porter.cadf` detects allocation via `driver_id IS NOT NULL`; the pack states explicitly *"Allocation uses `fo_driver_id` (fact-orders driver), **not** `driver_id`"* | ⚠️ **NEW — in neither inventory** |
| 3 | **Time-to-accept** — store `avg_time_to_accept_seconds` is a **mean**, measured **notification-sent → acceptance**; pack §4 is **P50/P75/P90**, measured **order_time → `fo_trip_accepted_time`**. Different aggregation *and* different start point | ⚠️ **NEW — in neither inventory** |
| 4 | **Card 32713 defaults silently scope to Delhi + 14ft + a 2-week 2025 window** (`geo_region_id=2`, `vehicle_category=14ft`, `Start_date=2025-04-28`, `End_date=2025-05-11`). `4146` flagged card 33106 for *hardcoding* Delhi but not this | ⚠️ **NEW — in neither inventory** |
| 5 | `32713`'s `vehicle_category` picklist offers **`8ft`**, outside the pack's `9ft–19ft` HCV scope; `Tier` values are `Tier1`/`Tier2` (no space) — confirms hard rule 9 first-hand | ⚠️ **NEW** |

> ⚠️ **Consequence for the build:** the inventories under-report. `GAPS.md` cannot be assembled by
> transcribing their contested-definition lists — each metric the KB covers needs its own
> store-vs-pack-vs-card comparison. Costed into step 3, not step 5.

## Open — needs a person, not more analysis

DESIGN.md §13; these become `GAPS.md` rows at step 5 and `WALKTHROUGH.md` §9 at step 8.

- ~~No north star~~ — **SETTLED `D-011`: Fulfilment % is L0** (`OWNER:2026-08-14`)
- **Fulfilment denominator** — total vs unique vs business-hours demand. `D-011` designates the
  metric, not its formula; this stays open and is now the highest-priority gap, since it is the
  denominator of the north star
- Canonical revenue — four formulas on `1882`, plus the pack's, plus the store's
- Canonical AOV — three on `1882`, one on `4146`, plus `metric.porter.average_order_value`
- MAP/DAP — login-based (pack, dashboards) vs order-based (store)
- Allocation % — three formulas on `4146`, plus the pack's `fo_driver_id IS NOT NULL`
- **Allocation key** — store `cadf` uses `driver_id`; pack uses `fo_driver_id` (new, 2026-08-14)
- **Time-to-accept** — store mean/notification-clocked vs pack percentiles/order-clocked (new)
- CADF attribution base — total demand vs CADF
- Argus posture — is HCV self-serve targeting the store, or working around it?

## Risks being carried

- `mbr_mapping_v2` is a sandbox table with no refresh contract; gates every pack section except §5
- The Sheet's ~90 definitions are AI-drafted and unratified — ladder position 5, `assumption` by default
- Metabase connector auth was flaky during the PTL build; budget for it recurring
- No number will be warehouse-validated at ship; this also removes `WALKTHROUGH.md`'s natural
  worked example (DESIGN §6.9 names the substitute)
- PTL has moved on — remote is one commit ahead of this branch's base (`1f008cd`, iteration-2 spec);
  does not touch `kb/`, so the template is unaffected

## Verification history

| Date | Check | Result |
|---|---|---|
| 2026-08-14 | Blind coherence audit of DESIGN/DECISIONS/BOARD v1 | 28 defects — 5 design-changing, 7 contradictions, rest ambiguity/underspecification. All accepted except the `M001`–`M047` id-range flag (explicable: lettered children) |
| 2026-08-14 | Blind coverage audit vs `ptl-selfserve/kb/` | *"Reproduces the reference's rules but not its shapes."* 14 classes of missing structure; highest rework cost = flat ID allocation (`D-008`) |
| — | Blind accuracy check of the built KB | pending, step 7 |
| — | Zero-context loadability test | pending, step 7 |
