# HCV KB build — board

**Living document.** Overwrite freely; the durable record is [DECISIONS.md](./DECISIONS.md).
Last updated 2026-08-14.

**Goal:** `hcv-selfserve/kb/` — a base-context knowledge base for HCV that a cold reader can load
and trust. Spec: [DESIGN.md](./DESIGN.md).

---

## Status

| # | Step | State |
|---|---|---|
| 0 | Design agreed, branch cut | **done** |
| 0b | Query pack committed into the repo | **blocked** — macOS TCC blocks shell/subprocess reads of `~/Downloads`; needs one `mv` from the owner |
| 1 | `CONTRIBUTING.md` — schema contract | not started |
| 2 | `data-model.md` + `business.md` | not started |
| 3 | `metrics.md` — ~10 full entries, then the deduped index | not started |
| 4 | `dashboards.md` — 1882, 4146, cards, the pack | not started |
| 5 | `GAPS.md` — 25 contested definitions, ~24 filter/bug findings, uncovered surface | not started |
| 6 | `CONTEXT.md` — entry point, ≤150 lines, written last | not started |
| 7 | Verification gate — blind check, zero-context load, mechanical coherence | not started |
| 8 | `WALKTHROUGH.md` + published HTML artifact | not started |

## Sources — access confirmed 2026-08-14

| Source | Access | Notes |
|---|---|---|
| `hcv_metrics_queries.md` | ⚠️ readable, not yet committed | Top of the precedence ladder; still only in `~/Downloads` |
| Notion `HSC : HCV Dashboard` | ✅ read via connector | 54 metrics, 16 contested, snapshot 2026-07-18 |
| Notion `HSC : HCV Deep Dive` | ✅ read via connector | 34 metrics, 9 contested, snapshot 2026-07-18 |
| Sheet `HCV_Metrics_DD` | ✅ read via Drive | ~90 rows; exact count to be confirmed at build |
| Metabase `dashboard/1882`, `dashboard/4146` | not yet attempted | Metadata reads only; needed for `source_updated_at` stamps |
| Governed store `metric.porter.*` | not yet attempted | Needed for every `store_ref` (D-004) |

## Open — needs a person, not more analysis

Seeded from [DESIGN.md](./DESIGN.md) §10; these become `GAPS.md` rows at step 5.

- No north star — 1882 says Completed Orders, 4146 says Fulfilment %
- Canonical revenue — four formulas on 1882, plus the pack's, plus the store's
- Canonical AOV — three on 1882, one on 4146, plus `metric.porter.average_order_value`
- MAP/DAP — login-based (pack, dashboards) vs order-based (store)
- Allocation % — three formulas on 4146, plus the pack's `fo_driver_id IS NOT NULL`
- Fulfilment denominator — total vs unique vs business-hours demand
- CADF attribution base — total demand vs CADF
- Argus posture — is HCV self-serve targeting the store, or working around it?

## Risks being carried

- `mbr_mapping_v2` is a sandbox table with no refresh contract; pack §1–4 are unrunnable without it
- The Sheet's ~90 definitions are AI-drafted and unratified — ladder position 5, `assumption` by default
- Metabase connector auth was flaky during the PTL build; budget for it recurring
- No number will be warehouse-validated at ship unless the owner authorises executing saved cards
