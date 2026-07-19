# Live differential reconciliation — p80_durations + order_edits

*Run 2026-07-19 (read-only, Snowflake MCP). PROTOTYPE-ONLY. Numbers are findings, never nudged.*

Source: `PROD_ELDORIA.MART.PNM_EXPERIENCE` (flagged in-source "still under active construction").
Mirror targets: `TRIP_DURATION_PERCENTILE_QUERY` (p80) and `EDIT_ADOPTION_QUERY` (order_edits).

## Method

1. **Exact rendered single-month SQL** (byte-for-byte what `ask.py` ships) run live for 2026-05.
2. **Grouped open-ended version** (the automation's shape) over the reconciliation window.
3. Assert single-month row == grouped row for 2026-05 (proves the structure-only adaptation adds no divergence).
4. p80: reconcile all 8 months vs `reference/p80_durations_baseline_2025-10_to_2026-05.csv`
   (live-vs-historical-CSV → README ±2.5% drift rule; live-vs-same-run → bit-exact by construction).
5. Property / adversarial + cross-month checks.

## p80_durations — live vs baseline CSV (minutes)

Single-month (2026-05) == grouped (2026-05): **identical** — 2675.0 / 732.0 / 74.0 / 370.0 / 218.0 / 293.0 / 602.0.

| Month | n_orders | vendor→sup (CSV→live) | sup→trip | trip→shift | shift→pickup | pickup→order | p50 | p80_trip | max drift |
|---|---|---|---|---|---|---|---|---|---|
| 2025-10 | 30273 | 2755.6→2755.6 | 469→469 | 78→78 | 384→384 | 260→260 | 318→318 | 673→673 | **exact** |
| 2025-11 | 30670 | 2822→2822 | 621→621 | 76→76 | 377→377 | 242→242 | 311→311 | 645→645 | **exact** |
| 2025-12 | 29795 | 2598.4→2598.4 | 549→549 | 78→78 | 354→354 | 222→222 | 288→288 | 598→598 | **exact** |
| 2026-01 | 29035 | 2712→2712.6 | 566→566 | 80→80 | 331→331 | 221→221 | 274→274 | 579→579 | +0.6 (0.02%) |
| 2026-02 | 29826 | 2515.4→2517.2 | 622→622 | 80→80 | 336→336 | 223→223 | 278→278 | 578→578 | +1.8 (0.07%) |
| 2026-03 | 37747 | 2817.4→2818 | 730.8→731 | 78→78 | 366→366 | 237→237 | 302→302 | 622→622 | +0.6 (0.02%) |
| 2026-04 | 41421 | 2707→2708 | 769.2→769 | 76→76 | 374→374 | 237→239 | 307→308 | 624→628.6 | +4.6 (0.74%) |
| 2026-05 | 45188 | 2673→2675 | 732.2→732 | 74→74 | 370→370 | 216→218 | 292→293 | 597→602 | +5.0 (0.84%) |

**Verdict:** EXACT on the 3 settled months; ≤0.84% (all << ±2.5%) on recent months, drift concentrated in
the newest months. Signature of a live-building mart backfilling recent rows since the baseline was captured —
i.e. the mirror logic is correct (bit-exact where data has settled); divergence is data drift, not a bug.

Property: `p50 ≤ p80_trip` every month; all metrics non-null, ≥0.

## order_edits — live 2026-05 + cross-month (no baseline CSV; mirror is byte-identical to EDIT_ADOPTION_QUERY)

2026-05 (single-month, exact rendered): pct_orders_edited 61.09 · no_of_successful_edits 153726 ·
pct_support_edited 13.10 · location_adoption_pct 15.85 · pct_orders_location_modified 15.85 ·
items 43.55 · addons 55.80 · slot 27.24 · edits_per_order 3.53 · pct_edits_after_shifting_started 36.61
(total_orders 43529, orders_with_mods 26594, location_edited_orders 6901). Single-month == grouped 2026-05.

| Month | total_orders | pct_orders_edited | location_adoption_pct | edits_per_order | pct_edits_after_shifting_started |
|---|---|---|---|---|---|
| 2026-03 | 38783 | 63.22 | 17.16 | 3.74 | 35.27 |
| 2026-04 | 41571 | 62.12 | 16.84 | 3.65 | 36.11 |
| 2026-05 | 43529 | 61.09 | 15.85 | 3.53 | 36.61 |

Property / adversarial:
- `location_adoption_pct == pct_orders_location_modified` (15.85 == 15.85) — duplicate-by-design equality holds.
- All 8 %-metrics in [0,100]; `edits_per_order` a positive ratio (excluded from the [0,100] check);
  `pct_edits_after_shifting_started` (÷ no_of_successful_edits) stays <100 in all months observed.
- Cross-month stable & plausible; single-month == grouped for 2026-05.
- Zero-order / zero-edit month: not present in the data window, so the `NULLIF(...,0)` NULL paths are
  correct-by-construction but not live-exercised (documented, per board finding A-9).

## Overall

Both sections PASS reconciliation. p80 proven bit-exact against the automation output where the mart has
settled; recent-month drift explained and within tolerance. order_edits inherits EDIT_ADOPTION_QUERY's
validation (byte-identical mirror) and passes every property + cross-month check. Readiness stays
`prototype_only` — promotion is the owner's call.
