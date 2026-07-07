# Reference data (read-only baselines for validation)

## `p80_durations_baseline_2025-10_to_2026-05.csv`

Owner-provided P80/P50 duration milestones by month (Oct 2025 → May 2026), exported from the
existing PnM reporting. **This is a validation baseline for iteration 3's `p80_durations`
section** — when that section is built and executed, its output should reconcile against these
numbers (subject to the ±2.5% drift rule).

Columns: `MONTH`, `P80_VENDOR_ACCEPTED_TO_SUP_ASSIGNED`, `P80_SUP_ASSIGNED_TO_TRIP_STARTED`,
`P80_TRIP_STARTED_TO_SHIFTING_STARTED`, `P80_SHIFTING_STARTED_TO_PICKUP_COMPLETE`,
`P80_PICKUP_COMPLETE_TO_ORDER_COMPLETE`, `P50_TRIP_DURATION`, `P80_TRIP_DURATION` (minutes).

### Mapping to the catalog's `p80_durations` metrics (for iteration 3)

| Baseline column | Catalog metric | Note |
|---|---|---|
| P80_TRIP_DURATION | `p80_trip_duration_mins` | shifting_started → order_completed |
| P80_VENDOR_ACCEPTED_TO_SUP_ASSIGNED | `p80_vendor_accept_to_sup_assign_mins` | ⚠ script uses `vendor_accepted_ts`; core model calls this `vendor_owner_accepted_ts` — confirm which "vendor accept" is meant |
| P80_SUP_ASSIGNED_TO_TRIP_STARTED | `p80_sup_assign_to_trip_start_mins` | |
| P80_TRIP_STARTED_TO_SHIFTING_STARTED | `p80_trip_start_to_shifting_start_mins` | |
| P80_SHIFTING_STARTED_TO_PICKUP_COMPLETE | `p80_shifting_start_to_pickup_complete_mins` | |
| P80_PICKUP_COMPLETE_TO_ORDER_COMPLETE | `p80_pickup_complete_to_order_complete_mins` | |
| P50_TRIP_DURATION | *(no catalog metric)* | baseline has a P50 the script does not compute |

Sanity note: `P80_VENDOR_ACCEPTED_TO_SUP_ASSIGNED` sits around 2500–2800 (minutes ≈ ~2 days),
far larger than the other milestones — worth confirming the unit/definition before quoting.
Do not treat this table as validated catalog output; it is the target to validate against.
