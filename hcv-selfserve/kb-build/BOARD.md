# HCV KB build — board

**Living document.** Overwrite freely; the durable record is [DECISIONS.md](./DECISIONS.md).
Last updated 2026-08-14. Spec: [DESIGN.md](./DESIGN.md) (v2).

**Goal:** `hcv-selfserve/kb/` — a base-context knowledge base for HCV that a cold reader can load
and trust.

---

## Status

Steps map 1:1 onto DESIGN.md §14.

| # | Step | State |
|---|---|---|
| 0 | Design agreed, branch cut, query pack committed | **done** — `5a06a81`, `20f6416` |
| 1 | `CONTRIBUTING.md` — schema contract (§6.3) | not started |
| 2 | `data-model.md` (§6.5) + `business.md` (§6.4) | not started |
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
| Metabase `dashboard/1882`, `dashboard/4146` | ⛔ not attempted | **Blocks step 4** — one `get_card` per card for the fingerprint register. Metadata only |
| Governed store `metric.porter.*` | ⛔ not attempted | **Blocks step 3** — `store_ref` is mandatory on every full entry (`D-004`) |

> ⚠️ If the store is unreachable, `store_ref` degrades from a fact to an open gap on **every** full
> entry, which materially weakens `D-004`. Worth establishing before step 3, not during it.

## Open — needs a person, not more analysis

DESIGN.md §13; these become `GAPS.md` rows at step 5 and `WALKTHROUGH.md` §9 at step 8.

- No north star — `1882` says Completed Orders, `4146` says Fulfilment %
- Canonical revenue — four formulas on `1882`, plus the pack's, plus the store's
- Canonical AOV — three on `1882`, one on `4146`, plus `metric.porter.average_order_value`
- MAP/DAP — login-based (pack, dashboards) vs order-based (store)
- Allocation % — three formulas on `4146`, plus the pack's `fo_driver_id IS NOT NULL`
- Fulfilment denominator — total vs unique vs business-hours demand
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
