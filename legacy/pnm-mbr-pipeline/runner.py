"""
PnM MBR Metrics Automation — Main Runner
=========================================
Entry point for the weekly automation.

Usage:
    python runner.py                       # computes last complete month + current MTD
    python runner.py --month 2026-05       # force a specific month (YYYY-MM)
    python runner.py --dry-run             # prints results, skips sheet write

Schedule: run every Monday (see README for cron / Windows Task Scheduler setup).
"""

import argparse
import json
import logging
import sys
from datetime import date, datetime
from dateutil.relativedelta import relativedelta
from pathlib import Path

import snowflake.connector
import pandas as pd

from config import SNOWFLAKE, LOGS_DIR, LOOKBACK_MONTHS, DRIFT_THRESHOLD_PCT
from queries import (
    CREATE_STG_LEADS, CREATE_STG_ORDERS,
    METRIC_SECTIONS,
)
from gsheet_client import GSheetClient
from validator import validate_drift

# ─── Logging setup ────────────────────────────────────────────────────────────
LOGS_DIR.mkdir(parents=True, exist_ok=True)
run_ts   = datetime.now().strftime("%Y%m%d_%H%M%S")
log_file = LOGS_DIR / f"run_{run_ts}.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(log_file),
    ],
)
log = logging.getLogger(__name__)


# ══════════════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════════════

def _month_bounds(month_date: date) -> tuple[str, str]:
    first = month_date.replace(day=1)
    last  = (first + relativedelta(months=1)) - relativedelta(days=1)
    return first.strftime("%Y-%m-%d"), last.strftime("%Y-%m-%d")


def _parse_month_arg(s: str) -> date:
    return datetime.strptime(s, "%Y-%m").date()


def _run_query(conn, sql: str, params: dict) -> pd.DataFrame:
    cursor = conn.cursor()
    cursor.execute(sql, params)
    cols = [d[0].lower() for d in cursor.description]
    rows = cursor.fetchall()
    cursor.close()
    return pd.DataFrame(rows, columns=cols)


# ══════════════════════════════════════════════════════════════════════════════
# Derived metrics (Conversion % and Order Mix %)
# ══════════════════════════════════════════════════════════════════════════════

def _compute_derived_metrics(leads_df: pd.DataFrame, orders_df: pd.DataFrame) -> pd.DataFrame:
    m = leads_df.merge(orders_df, on="month", suffixes=("_l", "_o"))

    def pct(num, denom):
        return (m[num] / m[denom].replace(0, None) * 100).round(2)

    m["conversion_overall"]  = pct("orders_overall", "leads_overall")
    m["conversion_app"]      = pct("orders_app",      "leads_app")
    m["conversion_desktop"]  = pct("orders_desktop",  "leads_desktop")
    m["conversion_mobile"]   = pct("orders_mobile",   "leads_mobile")
    m["pct_orders_app"]      = pct("orders_app",      "orders_overall")
    m["pct_orders_website"]  = ((m["orders_desktop"] + m["orders_mobile"])
                                 / m["orders_overall"].replace(0, None) * 100).round(2)
    m["pct_orders_others"]   = pct("orders_others",   "orders_overall")

    return m[[
        "month",
        "conversion_overall","conversion_app","conversion_desktop","conversion_mobile",
        "pct_orders_app","pct_orders_website","pct_orders_others",
    ]]


# ══════════════════════════════════════════════════════════════════════════════
# Core run logic
# ══════════════════════════════════════════════════════════════════════════════

def run(target_month: date, dry_run: bool = False):
    log.info("=" * 70)
    log.info(f"PnM MBR Metrics Run  |  target_month={target_month}  |  dry_run={dry_run}")
    log.info("=" * 70)

    prev_month  = target_month - relativedelta(months=1)
    m_start, _  = _month_bounds(target_month)
    pm_start, _ = _month_bounds(prev_month)

    params = {
        "month_start":      m_start,
        "month_start_prev": pm_start,
    }
    log.info(f"Querying months: {pm_start}  and  {m_start}")

    # ── Connect ───────────────────────────────────────────────────────────────
    log.info("Connecting to Snowflake …")
    conn = snowflake.connector.connect(
        account=SNOWFLAKE["account"],
        user=SNOWFLAKE["user"],
        password=SNOWFLAKE["password"],
        warehouse=SNOWFLAKE["warehouse"],
        database=SNOWFLAKE["database"],
        schema=SNOWFLAKE["schema"],
        role=SNOWFLAKE["role"],
    )
    log.info("Connected.")

    try:
        # ── Build staging tables in PROD_CURATED.NEW_INITIATIVE_ANALYTICS ────
        log.info("Building staging tables in PROD_CURATED.NEW_INITIATIVE_ANALYTICS …")
        _run_query(conn, CREATE_STG_LEADS,  params)
        log.info("  ✓ pnm_mbr_leads")
        _run_query(conn, CREATE_STG_ORDERS, params)
        log.info("  ✓ pnm_mbr_orders")

        # ── Run metric queries ────────────────────────────────────────────────
        results: dict[str, pd.DataFrame] = {}
        for section in METRIC_SECTIONS:
            name = section["name"]
            log.info(f"Running: {name} …")
            try:
                df = _run_query(conn, section["query"], params)
                results[name] = df
                log.info(f"  ✓ {name}  ({len(df)} rows)")
            except Exception as exc:
                log.error(f"  ✗ {name} FAILED: {exc}")
                results[name] = pd.DataFrame()

        # ── Derived metrics ───────────────────────────────────────────────────
        if not results.get("leads", pd.DataFrame()).empty and \
           not results.get("orders", pd.DataFrame()).empty:
            results["derived"] = _compute_derived_metrics(
                results["leads"], results["orders"]
            )
            log.info("  ✓ derived (conversion + order mix)")

    finally:
        conn.close()
        log.info("Snowflake connection closed.")

    # ── Merge all sections into one wide DataFrame ────────────────────────────
    combined = _merge_all_results(results)
    log.info(f"Combined shape: {combined.shape}")

    # ── Load history from GSheet and validate drift ───────────────────────────
    gsheet    = GSheetClient()
    historical = gsheet.read_historical(lookback=LOOKBACK_MONTHS)
    log.info(f"Loaded {len(historical)} historical rows from GSheet.")

    alerts = validate_drift(combined, historical, threshold_pct=DRIFT_THRESHOLD_PCT)
    if alerts:
        log.warning(f"DRIFT ALERTS ({len(alerts)} metrics flagged):")
        for a in alerts:
            log.warning(f"  [{a['metric']}] month={a['month']}  "
                        f"prev={a['prev_stored']}  new={a['new_value']}  "
                        f"drift={a['drift_pct']:+.2f}%")
    else:
        log.info(f"All metrics within ±{DRIFT_THRESHOLD_PCT}%% threshold. ✓")

    # current_month_str = in-progress MTD month → overwrite on every Monday run
    # prev month = complete → locked after first write
    current_month_str = target_month.strftime("%Y-%m")

    # ── Write to GSheet ───────────────────────────────────────────────────────
    if dry_run:
        log.info("[DRY RUN] Skipping GSheet write. Preview:")
        print(combined.to_string())
    else:
        log.info("Writing to Google Sheet …")
        gsheet.upsert_results(combined, current_month_str=current_month_str)
        gsheet.write_run_log(
            run_ts=run_ts,
            target_month=str(target_month),
            alerts=alerts,
            rows_written=len(combined),
        )
        log.info("GSheet write complete.")

    _save_run_log(run_ts, target_month, combined, alerts)
    log.info(f"Run log saved → logs/run_{run_ts}.json")
    log.info("Done.")
    return combined, alerts


# ══════════════════════════════════════════════════════════════════════════════
# Merge helper
# ══════════════════════════════════════════════════════════════════════════════

def _merge_all_results(results: dict[str, pd.DataFrame]) -> pd.DataFrame:
    merged = None
    for name, df in results.items():
        if df.empty or "month" not in df.columns:
            log.warning(f"Skipping empty result for: {name}")
            continue
        df = df.copy()
        if merged is None:
            merged = df
        else:
            dup_cols = [c for c in df.columns if c != "month" and c in merged.columns]
            df = df.drop(columns=dup_cols)
            merged = merged.merge(df, on="month", how="outer")

    if merged is None:
        return pd.DataFrame()

    merged = merged.sort_values("month").reset_index(drop=True)
    merged["run_ts"] = run_ts
    return merged


# ══════════════════════════════════════════════════════════════════════════════
# Local run log
# ══════════════════════════════════════════════════════════════════════════════

def _save_run_log(run_ts, target_month, combined, alerts):
    def _fix(obj):
        if hasattr(obj, "isoformat"): return obj.isoformat()
        if hasattr(obj, "item"):      return obj.item()
        return str(obj)

    payload = {
        "run_ts":       run_ts,
        "target_month": str(target_month),
        "rows_written": len(combined),
        "columns":      list(combined.columns),
        "drift_alerts": alerts,
        "data_preview": combined.head(4).to_dict(orient="records"),
    }
    with open(LOGS_DIR / f"run_{run_ts}.json", "w") as f:
        json.dump(payload, f, indent=2, default=_fix)


# ══════════════════════════════════════════════════════════════════════════════
# CLI
# ══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="PnM MBR Metrics Runner")
    parser.add_argument("--month",   default=None, help="YYYY-MM  (default: last complete month)")
    parser.add_argument("--dry-run", action="store_true", help="Print only, no sheet write")
    args = parser.parse_args()

    if args.month:
        target = _parse_month_arg(args.month)
    else:
        today  = date.today()
        target = today.replace(day=1) - relativedelta(months=1)

    run(target_month=target, dry_run=args.dry_run)
