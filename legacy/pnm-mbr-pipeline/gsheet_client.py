"""
PnM MBR Metrics Automation — Google Sheets Client
===================================================
Reads historical data from, and appends / updates rows in, the PnM MBR output tab.

Write behaviour:
  - Current MTD month  → always overwrite in-place (numbers are still accumulating)
  - Last complete month → append once, never overwrite (treated as final)

Auth: Google service account key JSON file (path set in config.GSHEET_KEY_FILE).
Scopes required: spreadsheets, drive.readonly
"""

import logging
import gspread
import pandas as pd
from google.oauth2.service_account import Credentials

from config import GSHEET_KEY_FILE, OUTPUT_SHEET_ID, OUTPUT_TAB_NAME, LOG_TAB_NAME

log = logging.getLogger(__name__)

SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive.readonly",
]


def _row_to_list(row) -> list:
    """Convert a pandas Series to a plain Python list safe for GSheet."""
    out = []
    for v in row.values:
        if hasattr(v, "isoformat"):
            out.append(v.isoformat())
        elif hasattr(v, "item"):
            out.append(v.item())
        elif pd.isna(v):
            out.append("")
        else:
            out.append(v)
    return out


class GSheetClient:
    def __init__(self):
        creds = Credentials.from_service_account_file(GSHEET_KEY_FILE, scopes=SCOPES)
        gc = gspread.authorize(creds)
        self._sheet = gc.open_by_key(OUTPUT_SHEET_ID)
        log.info(f"GSheet opened: {self._sheet.title}")

    # ── Read history ──────────────────────────────────────────────────────────

    def read_historical(self, lookback: int = 6) -> pd.DataFrame:
        try:
            ws = self._sheet.worksheet(OUTPUT_TAB_NAME)
        except gspread.WorksheetNotFound:
            log.warning(f"Tab '{OUTPUT_TAB_NAME}' not found — empty history.")
            return pd.DataFrame()

        records = ws.get_all_records()
        if not records:
            return pd.DataFrame()

        df = pd.DataFrame(records)
        if "month" not in df.columns:
            return pd.DataFrame()

        df["month"] = pd.to_datetime(df["month"], errors="coerce")
        df = df.dropna(subset=["month"]).sort_values("month")
        return df.tail(lookback).reset_index(drop=True)

    # ── Upsert results ────────────────────────────────────────────────────────

    def upsert_results(self, df: pd.DataFrame, current_month_str: str):
        """
        current_month_str : YYYY-MM of the in-progress (MTD) month.
        That month's row is always overwritten. All other months are
        appended once and then left untouched.
        """
        try:
            ws = self._sheet.worksheet(OUTPUT_TAB_NAME)
            all_values = ws.get_all_values()
        except gspread.WorksheetNotFound:
            ws = self._sheet.add_worksheet(
                title=OUTPUT_TAB_NAME, rows=500, cols=len(df.columns) + 2
            )
            all_values = []
            ws.append_row(list(df.columns))
            log.info(f"Created tab '{OUTPUT_TAB_NAME}' with headers.")

        # Build YYYY-MM → sheet row index (1-based; row 1 = header)
        month_to_row: dict[str, int] = {}
        if all_values:
            header = all_values[0]
            month_col = header.index("month") if "month" in header else 0
            for i, row in enumerate(all_values[1:], start=2):
                if row and len(row) > month_col:
                    month_to_row[str(row[month_col])[:7]] = i

        for _, row in df.iterrows():
            month_str = str(row.get("month", ""))[:7]
            values    = _row_to_list(row)

            if month_str == current_month_str:
                # MTD month: overwrite or append
                if month_str in month_to_row:
                    sheet_row  = month_to_row[month_str]
                    start_cell = gspread.utils.rowcol_to_a1(sheet_row, 1)
                    end_cell   = gspread.utils.rowcol_to_a1(sheet_row, len(values))
                    ws.update(f"{start_cell}:{end_cell}", [values],
                              value_input_option="USER_ENTERED")
                    log.info(f"  ✎ Overwrote MTD row for {month_str} (sheet row {sheet_row}).")
                else:
                    ws.append_row(values, value_input_option="USER_ENTERED")
                    log.info(f"  + Appended new MTD row for {month_str}.")
            else:
                # Complete month: write once, never touch again
                if month_str in month_to_row:
                    log.info(f"  — Locked: skipping {month_str} (already in sheet).")
                else:
                    ws.append_row(values, value_input_option="USER_ENTERED")
                    log.info(f"  + Appended complete month {month_str}.")

    # ── Run log ───────────────────────────────────────────────────────────────

    def write_run_log(self, run_ts, target_month, alerts, rows_written):
        try:
            ws = self._sheet.worksheet(LOG_TAB_NAME)
        except gspread.WorksheetNotFound:
            ws = self._sheet.add_worksheet(title=LOG_TAB_NAME, rows=500, cols=8)
            ws.append_row(["run_ts","target_month","rows_written",
                           "alert_count","alerted_metrics","status","notes"])
            log.info(f"Created run-log tab '{LOG_TAB_NAME}'.")

        ws.append_row([
            run_ts,
            target_month,
            rows_written,
            len(alerts),
            ", ".join(a["metric"] for a in alerts) if alerts else "—",
            "⚠ DRIFT ALERTS" if alerts else "✓ OK",
            "",
        ])
        log.info(f"Run log written to '{LOG_TAB_NAME}'.")
