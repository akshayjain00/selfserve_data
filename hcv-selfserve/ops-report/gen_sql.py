#!/usr/bin/env python3
"""Emit the HCV intracity ops-report SQL files plus a run manifest.

Usage:
    python3 gen_sql.py [--target-date YYYY-MM-DD] [--out sql]

``--target-date`` is the *run* date; analysis always ends the day before.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from hcvlib import (IST, Periods, orders_chunks, queries_for,  # noqa: E402
                    reasons_chunks, required_cols, tag)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--target-date")
    ap.add_argument("--out", default=str(HERE / "sql"))
    args = ap.parse_args()

    today = (_dt.date.fromisoformat(args.target_date) if args.target_date
             else _dt.datetime.now(IST).date())
    p = Periods(today - _dt.timedelta(days=1))

    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for stale in out.glob("*.sql"):       # sql/ states exactly this run's work
        stale.unlink()
    sqls = queries_for(p)
    for name, text in sqls.items():
        (out / f"{name}.sql").write_text(text + "\n")

    a, b = p.date_range()
    manifest = {
        "run_date": today.isoformat(),
        "analysis_end": p.analysis_end.isoformat(),
        "labels": p.labels,
        "windows": {k.lower(): [x.isoformat() for x in v] for k, v in p.windows.items()},
        "strip_days": [d.isoformat() for d in p.strip_days],
        "sw_days": [d.isoformat() for d in p.sw_days],
        "date_range": [a.isoformat(), b.isoformat()],
        "periods": p.period_keys(),
        "queries": list(sqls),
        "tags": {n: tag(n, p) for n in sqls},
        "required_cols": {n: required_cols(n) for n in sqls},
        "orders_chunks": {n: [a.isoformat(), b.isoformat()]
                          for n, (a, b) in orders_chunks(p).items()},
        "reasons_chunks": {n: [a.isoformat(), b.isoformat()]
                           for n, (a, b) in reasons_chunks(p).items()},
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({k: manifest[k] for k in
                      ("run_date", "analysis_end", "windows", "date_range", "queries")},
                     indent=2))
    print(f"\nRun each {out}/<name>.sql ONE AT A TIME, save each result as "
          f"inbox/hcv_<name>.json, then: python3 install_exports.py")


if __name__ == "__main__":
    main()
