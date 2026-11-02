"""Build the two Snowflake load CSVs from PTL AppSheet daily backups.

Usage: python3 appsheet-backup-build.py <raw_dir> <out_dir> <tag>

<raw_dir> holds orders_YYYY-MM-DD.csv / batches_YYYY-MM-DD.csv (eligible_vehicles is ignored:
it maps to neither target table). Writes, with and without header:
  PTL_APP_SHEET_BACKFILLED_DATA_<tag>.csv   <- orders LEFT JOIN batches on batch_id
  PTL_BATCH_LEVEL_APP_SHEET_OLD_<tag>.csv   <- batches only

The trap: two timestamp formats coexist, fixed by column. Month-first `M/D/YYYY H:MM:SS` for
reached_pickup_at / reached_drop_at / accepted_at; day-first `DD-MM-YYYY h:MM AM/PM` for
created_at / picked_up_at / assigned_at; delivered_at holds BOTH, so parse by shape per value.
See memory: appsheet-backup-to-snowflake-pipeline.
"""
import os
import sys

import pandas as pd

raw, out, tag = sys.argv[1:4]
os.makedirs(out, exist_ok=True)


def load(prefix):
    files = sorted(f for f in os.listdir(raw) if f.startswith(prefix + "_"))
    return pd.concat([pd.read_csv(os.path.join(raw, f), dtype=str) for f in files], ignore_index=True)


def ts(series):
    """Parse by the shape of each value: '/' = month-first 24h, '-' = day-first 12h."""
    s = series.str.strip()
    slash = s.str.contains("/", na=False)
    dash = s.str.contains("-", na=False)
    res = pd.Series(pd.NaT, index=s.index, dtype="datetime64[ns]")
    res[slash] = pd.to_datetime(s[slash], format="%m/%d/%Y %H:%M:%S")
    res[dash] = pd.to_datetime(s[dash], format="%d-%m-%Y %I:%M %p")
    return res


def fmt(df, tscols):
    df = df.copy()
    for c in tscols:
        df[c] = df[c].dt.strftime("%Y-%m-%d %H:%M:%S")
    return df


def num(series):
    return pd.to_numeric(series, errors="raise").astype("Int64")


orders, batches = load("orders"), load("batches")

# ---- batch-level table
b = pd.DataFrame({
    "BATCH_ID": num(batches["id"]),
    "BATCH_STATUS": batches["batch_status"],
    "ROUTE_NAME": batches["ROUTE"],
    "BATCH_CREATED_AT": ts(batches["created_at"]),
    "ACCEPTED_BY_EMAIL": batches["accepted_by_email"],
    "ACCEPTED_AT": ts(batches["accepted_at"]),
    "ASSIGNED_VEHICLE_ID": num(batches["assigned_vehicle_id"]),
    "ASSIGNED_AT": ts(batches["assigned_at"]),
})

# ---- order-level table; ACCEPTED_AT / ASSIGNED_AT come from the batch
o = pd.DataFrame({
    "ORDER_ID": num(orders["order id"]),
    "BATCH_ID": num(orders["batch_id"]),
    "WEIGHT": orders["weight"],
    "REACHED_PICKUP_AT": ts(orders["reached_pickup_at"]),
    "PICKED_UP_AT": ts(orders["picked_up_at"]),
    "REACHED_DROP_AT": ts(orders["reached_drop_at"]),
    "DELIVERED_AT": ts(orders["delivered_at"]),
})
o = o.merge(b[["BATCH_ID", "ACCEPTED_AT", "ASSIGNED_AT"]], on="BATCH_ID", how="left")

assert not o["ORDER_ID"].duplicated().any() and not b["BATCH_ID"].duplicated().any()

for name, df, cols in (
    ("PTL_APP_SHEET_BACKFILLED_DATA", o, ["REACHED_PICKUP_AT", "PICKED_UP_AT", "REACHED_DROP_AT",
                                          "DELIVERED_AT", "ACCEPTED_AT", "ASSIGNED_AT"]),
    ("PTL_BATCH_LEVEL_APP_SHEET_OLD", b, ["BATCH_CREATED_AT", "ACCEPTED_AT", "ASSIGNED_AT"]),
):
    f = fmt(df, cols)
    f.to_csv(os.path.join(out, f"{name}_{tag}.csv"), index=False)
    f.to_csv(os.path.join(out, f"{name}_{tag}_noheader.csv"), index=False, header=False)
    print(name, len(f), "rows")
