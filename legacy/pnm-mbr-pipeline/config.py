"""
PnM MBR Metrics Automation — Configuration
============================================
Edit this file to set credentials, sheet IDs, and thresholds.

Snowflake credentials are read from environment variables (see README).
Google Sheets auth uses a service-account JSON key file.
"""

import os
from pathlib import Path

# ─── Snowflake ────────────────────────────────────────────────────────────────
SNOWFLAKE = {
    "account":    os.environ.get("SF_ACCOUNT", ""),          # e.g. "xy12345.ap-south-1"
    "user":       os.environ.get("SF_USER", ""),
    "password":   os.environ.get("SF_PASSWORD", ""),
    "warehouse":  os.environ.get("SF_WAREHOUSE", "COMPUTE_WH"),
    "database":   os.environ.get("SF_DATABASE", "PROD_CURATED"),
    "schema":     os.environ.get("SF_SCHEMA", "pnm_application"),
    "role":       os.environ.get("SF_ROLE", ""),
}

# ─── Google Sheets ────────────────────────────────────────────────────────────
GSHEET_KEY_FILE   = os.environ.get("GSHEET_KEY_FILE", "service_account.json")
OUTPUT_SHEET_ID   = "1LxCSQ9TlbpUvMXLsyfV9mKUpKi9fC33HA818H9T1WAw"  # HSC PNM sheet
OUTPUT_TAB_NAME   = "PnM_MBR_Automated"       # Tab where script writes results
LOG_TAB_NAME      = "PnM_MBR_RunLog"          # Tab for run logs / validation alerts

# ─── Validation ───────────────────────────────────────────────────────────────
DRIFT_THRESHOLD_PCT = 2.5      # ±% beyond which a metric is flagged as "off"

# ─── Runtime ──────────────────────────────────────────────────────────────────
# How many historical months to pull from the output sheet for trend comparison
LOOKBACK_MONTHS = 6

# Logs directory (relative to this file)
LOGS_DIR = Path(__file__).parent / "logs"

# ─── Intermediate / staging schema ────────────────────────────────────────────
# Temp base tables are written here each run and reused across all metric queries.
# This is a persistent schema — tables are overwritten (CREATE OR REPLACE) on each run.
STAGING_SCHEMA = "PROD_CURATED.NEW_INITIATIVE_ANALYTICS"

# ─── Table references ─────────────────────────────────────────────────────────
# Verify these against Snowflake before running for the first time.
# Canonical methodology: Metabase card #30311.
TABLES = {
    # Fact + dim for leads / booking funnel
    "fact_opp":       "PROD_CURATED.pnm_application.fact_pnm_opprotunity",   # note: typo in source table
    "dim_opp":        "PROD_CURATED.pnm_application.dim_pnm_opportunity",
    "orders":         "PROD_CURATED.pnm_application.orders",
    "dim_orders":     "PROD_CURATED.pnm_application.dim_pnm_orders",
    "pnm_customers":  "PROD_CURATED.pnm_application.pnm_customers",

    # Allocation / OTA
    "order_alloc":    "PROD_CURATED.pnm_application.order_allocation_infos",

    # Tickets / TPO
    "tickets":        "PROD_CURATED.pnm_application.tickets",                 # verify table name

    # Order modifications / edits
    "order_mods":     "PROD_CURATED.pnm_application.order_modifications",     # verify table name

    # Staging / intermediate tables (written by this script each run)
    "stg_leads":      "PROD_CURATED.NEW_INITIATIVE_ANALYTICS.pnm_mbr_leads",
    "stg_orders":     "PROD_CURATED.NEW_INITIATIVE_ANALYTICS.pnm_mbr_orders",
}
