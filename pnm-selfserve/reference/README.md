# Reference data (read-only baselines for validation)

## `p80_durations_baseline_2025-10_to_2026-05.csv`

Owner-provided P80/P50 duration milestones by month (Oct 2025 → May 2026), exported from the
existing PnM reporting. **This is a validation baseline for iteration 3's `p80_durations`
section** — when that section is built and executed, its output should reconcile against these
numbers (subject to the ±2.5% drift rule).

Columns: `MONTH`, `P80_VENDOR_ACCEPTED_TO_SUP_ASSIGNED`, `P80_SUP_ASSIGNED_TO_TRIP_STARTED`,
`P80_TRIP_STARTED_TO_SHIFTING_STARTED`, `P80_SHIFTING_STARTED_TO_PICKUP_COMPLETE`,
`P80_PICKUP_COMPLETE_TO_ORDER_COMPLETE`, `P50_TRIP_DURATION`, `P80_TRIP_DURATION` (minutes).

### Mapping to the catalog's `p80_durations` metrics

⚠ **Updated 2026-09-04 (`PNM-G-040`, closed) — the ids below were the pre-ship `_mins`-suffixed
names.** The shipped catalog uses the automation's own output-column names, lowercase, no `_mins`
suffix (`DECISION_LOG:D9`) — `ask.py` lowercases every result column and does `row.get(metric_id)`,
so a mismatched id cannot resolve at all. The table now reflects the ids actually shipped
(`metrics.md` §5, `PNM-M-020`–`022`).

| Baseline column | Catalog metric | Note |
|---|---|---|
| P80_TRIP_DURATION | `p80_trip_duration` | shifting_started → order_completed |
| P80_VENDOR_ACCEPTED_TO_SUP_ASSIGNED | `p80_vendor_accepted_to_sup_assigned` | Resolved: the shipped SQL uses `VENDOR_OWNER_ACCEPTED_TS_IST` → `SUPERVISOR_ACCEPTED_TS_IST` (`sqlgen.py`'s `p80_sql`) — the "which vendor accept" ambiguity this row used to flag no longer applies |
| P80_SUP_ASSIGNED_TO_TRIP_STARTED | `p80_sup_assigned_to_trip_started` | |
| P80_TRIP_STARTED_TO_SHIFTING_STARTED | `p80_trip_started_to_shifting_started` | |
| P80_SHIFTING_STARTED_TO_PICKUP_COMPLETE | `p80_shifting_started_to_pickup_complete` | |
| P80_PICKUP_COMPLETE_TO_ORDER_COMPLETE | `p80_pickup_complete_to_order_complete` | |
| P50_TRIP_DURATION | `p50_trip_duration` | Emitted and reconciled (`PNM-M-022`), but deliberately **not NL-exposed** — blocked by the `p50`/`median` closed-world guard, reachable only via `ask.py --metric` |

Sanity note: `P80_VENDOR_ACCEPTED_TO_SUP_ASSIGNED` sits around 2500–2800 (minutes ≈ ~2 days),
far larger than the other milestones — worth confirming the unit/definition before quoting.
Do not treat this table as validated catalog output; it is the target to validate against.
