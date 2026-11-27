# DECISIONS — append-only decision log (HCV intracity ops report)
# Writer: ORCHESTRATOR ONLY. Append at the END. IDs strictly increasing. Never edit an entry in place.
# Format: [D-NNN] YYYY-MM-DD (orchestrator) — decision — rationale

[D-001] 2026-11-27 (orchestrator) — Mode is SEQUENTIAL, single orchestrator — the modules depend on each other's live output (SQL shape → installer → cube → HTML) and it is one deep build, not breadth.

[D-002] 2026-11-27 (orchestrator) — "Intracity" = `lower(dim_vehicles.serviceability_segment) = 'vanilla'` — owner's pick at Gate 0 (option 1). Gate-0 query (30 days to 2026-11-26, hcv-data base filters): Vanilla 690,392 of 738,544 orders (93.5%), Outstation 48,152 (6.5%). It is the same field dashboard 6406's cards expose as the `serviceability_segment` filter (alias `vv.serviceability_segment`), so the reconciliation is direct. Rejected: adding `drop_zone IS NOT NULL` (drops 11,973 Vanilla orders on an unconfirmed reading of a NULL drop zone). Caveat: GAPS.md G-104 — "Outstation" has four governed definitions; this is the vehicle-level one.

[D-003] 2026-11-27 (orchestrator) — All vehicle_mapping values present in the mart are in scope, 9ft included — owner's Gate-0 note ("across categories, 9 … you will add"), read by me as "9ft is included"; matches the goal line "9ft and above".

[D-004] 2026-11-27 (orchestrator) — Metric definitions follow hcv-data, verified against live card SQL read from `PROD_ELDORIA.CORE.FACT_MB_CARDS` on 2026-11-27 (cards 55561 Demand, 55586 Allocation/FF/CADF/CBDF, 55527 Allocation time, 55612 Cancellations, 55573 DAP, 55587 Revenue). Every % is over Demand (`div0(x, Demand)` in card 55586). Fulfilment % = Completed ÷ Demand, SO-only rows stay in the denominator — the KB's G-030/G-031 objection is noted in the report's Definitions, not applied (owner instruction).

[D-005] 2026-11-27 (orchestrator) — CBDF Stockout/Missed-Order uses `GREATEST` of the two PROD matchmaking marts only — hcv-data's definition. Card 55612 additionally folds in `DEV_ELDORIA.SANDBOX.TEMP_ORDER_ALLOCATION_SUMMARY`, which hcv-data flags as a data-quality problem; not used. Consequence: the Stockout/Missed split can differ slightly from card 55612; CBDF itself is unaffected.

[D-006] 2026-11-27 (orchestrator) — Revenue = `sum(FO_CUSTOMER_FARE_WITHOUT_PREVIOUS_DUE)` on completed orders, dated on `order_time` — hcv-data. Card 55587 computes revenue differently (raw OMS ∪ SO union, `order_fares` final fare, dated on `created_at`); hcv-data records the two as agreeing within ~0.3%. The reconciliation therefore reports the Revenue gap rather than expecting zero.

[D-007] 2026-11-27 (orchestrator) — DAP = per day, count of (driver × city) with `SUM(business_login_hours) > 0.5` from `core.fact_active_partners`, `level0_mapping = 'HCV'`, Tier 1 (card 55573 logic), plus the intracity filter on the driver's vehicle; a window shows the mean of daily DAP over days that have DAP rows. DAP has no order-type cut (a partner is not an order type) — shown blank there.

[D-008] 2026-11-27 (orchestrator) — Allocation time population and clock copied from card 55527: `datediff(second, order_time, to_timestamp(fo_trip_accepted_time) + 330 min)`, `fo_trip_accepted_time IS NOT NULL`, value ≥ 0; `PERCENTILE_CONT` at 0.5 and 0.9, computed in SQL per window (non-composable). A percentile on fewer than 30 allocated orders is blanked (reference pipeline's `P90_MIN_N`).

[D-009] 2026-11-27 (orchestrator) — Composable sums are exported at date × city × vehicle_mapping × order_type (the full cross) — every order sits in exactly one cell, so any one-way cut and the Tier-1 total are sums over a partition and T-024's overlap problem cannot arise; the installer asserts `N_ROWS == DEMAND` per cell to prove no join fan-out.

[D-010] 2026-11-27 (orchestrator) — No pandas/numpy; stdlib only — neither is installed on this machine and the data is a few thousand rows. Stays inside the "no dependency beyond numpy and pandas" limit.

[D-011] 2026-11-27 (orchestrator) — Each query stamps a run tag into a column name (`TAG__<query>__<analysis_end>`), and the installer refuses an export whose tag is not this run's — closes the gap the reference SKILL.md documents, where a day-stale file with identical period keys passed the installer.

[D-012] 2026-11-27 (orchestrator) — Transport of query results to disk: the Snowflake MCP returns results into the agent's tool output, and no local Snowflake client is installed (adding one needs owner approval). `capture_exports.py` lifts each tagged result out of the context-mode capture store into `inbox/`. It is the only harness-specific step; `install_exports.py` validates whatever lands in `inbox/` regardless of how it got there.

[D-013] 2026-11-27 (orchestrator) — Blind check returned NO HIGH findings: 1,461 of 1,461 printed cells reproduced from the raw exports with the checker's own code; SQL matched hcv-data on every definition it could test. Six MEDIUM and ten LOW findings; dispositions in D-014 to D-018. The check ran on the build before those changes; the changes are notes, labels and wording, and no figure moved.

[D-014] 2026-11-27 (orchestrator) — Checker M1/M2 (a six-day demand dip on 7–12 Nov drives MTD −10.7% and sits in yesterday's baseline): the report now flags any day more than 20% from its same-weekday median, per window (`Cube.unusual_days`, `UNUSUAL_TOL`) — the reference pipeline's "unusual day" rule. The report states the dates and sizes only; it does not name a cause (the checker's Diwali reading is an inference, not in the data). No ex-dip comparison added: that would be a new window, which needs owner approval.

[D-015] 2026-11-27 (orchestrator) — Checker M3 (yesterday not settled): the report prints the count of yesterday's allocated orders that are neither completed nor cancelled (`Cube.in_progress`), and Definitions gains a "Data maturity" entry.

[D-016] 2026-11-27 (orchestrator) — Checker M4/L5 (Schedule "Stockout" reads as a supply shortage; no Express row): explained in the order-type section and in the CBDF definition; an absent order type is now named in a note. Definition unchanged.

[D-017] 2026-11-27 (orchestrator) — Checker M5 (attribution tie-break was a silent alphabetical MAX): the SQL now labels a cancel reason with conflicting attributions 'conflict', so it shows as unattributed CADF, which the report already surfaces. Verified today: 102 cancel reasons, 0 with conflicting attributions, 0 with more than one row — so the exports already installed are identical under the new SQL and were not re-pulled.

[D-018] 2026-11-27 (orchestrator) — Checker M6 (claims of matching the dashboard were unsupported from the spec alone): the reconciliation now also covers Allocated, CADF and CBDF orders against card 55586 (all exact for 16–22 Nov), Definitions says where card and gap numbers come from, and the unreconciled phrase "CBDF % itself matches" was removed. Also: allocation-time filter disclosed (L1), CADF split added to the 14-day strip (L4), change columns name their metric (L8). Not changed: DAP grain (L2, card 55573's own logic), inner joins (L3, the card's field filters behave the same way), mixed ₹ units (L7), mean-of-percentiles baseline (L9, disclosed).
