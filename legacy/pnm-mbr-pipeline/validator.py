"""
PnM MBR Metrics Automation — Drift Validator
=============================================
Compares this run's values against the last stored values for the same month.
Flags any metric where the relative change exceeds ±THRESHOLD_PCT.

Logic:
    1. Take the last COMPLETE month's values from the current run.
    2. Find that same month in the GSheet historical data.
    3. For each numeric metric: drift% = (new - old) / |old| × 100.
    4. If |drift%| > threshold → emit an alert dict.
"""

import logging
import pandas as pd

log = logging.getLogger(__name__)

SKIP_COLS = {"run_ts", "month", "total_orders", "orders_base", "base_orders"}


def validate_drift(
    current_df: pd.DataFrame,
    historical_df: pd.DataFrame,
    threshold_pct: float = 2.5,
) -> list[dict]:

    alerts = []

    if current_df.empty or historical_df.empty:
        log.warning("Drift validation skipped — one DataFrame is empty.")
        return alerts

    current_df    = current_df.copy()
    historical_df = historical_df.copy()

    current_df["_mk"]    = pd.to_datetime(current_df["month"],    errors="coerce").dt.to_period("M").astype(str)
    historical_df["_mk"] = pd.to_datetime(historical_df["month"], errors="coerce").dt.to_period("M").astype(str)

    sorted_months = sorted(current_df["_mk"].dropna().unique())
    if not sorted_months:
        return alerts

    # Use the second-most-recent month (last complete month, not current MTD)
    check_month = sorted_months[-2] if len(sorted_months) >= 2 else sorted_months[-1]

    current_row = current_df[current_df["_mk"] == check_month]
    stored_rows = historical_df[historical_df["_mk"] == check_month]

    if current_row.empty or stored_rows.empty:
        log.info(f"No paired data for month {check_month} — skipping drift check.")
        return alerts

    current_row = current_row.iloc[0]
    stored_row  = stored_rows.iloc[-1]

    numeric_cols = [
        c for c in current_df.columns
        if c not in SKIP_COLS and c != "_mk"
        and pd.api.types.is_numeric_dtype(current_df[c])
    ]

    for col in numeric_cols:
        if col not in stored_row.index:
            continue
        try:
            new_val = float(current_row[col])
            old_val = float(stored_row[col])
        except (ValueError, TypeError):
            continue

        if old_val == 0:
            drift_pct = float("inf") if new_val != 0 else 0.0
        else:
            drift_pct = (new_val - old_val) / abs(old_val) * 100

        if abs(drift_pct) > threshold_pct:
            alerts.append({
                "metric":      col,
                "month":       check_month,
                "prev_stored": round(old_val, 4),
                "new_value":   round(new_val, 4),
                "drift_pct":   round(drift_pct, 2),
                "threshold":   threshold_pct,
            })

    if alerts:
        log.warning(f"{len(alerts)} metric(s) drifted beyond ±{threshold_pct}% for {check_month}.")
    else:
        log.info(f"Drift check passed for {check_month} ({len(numeric_cols)} metrics). ✓")

    return alerts
