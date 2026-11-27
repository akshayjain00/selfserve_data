#!/usr/bin/env python3
"""Reconcile the report against dashboard 6406's own card SQL for one week.

The card results in docs/reconciliation/ are the verbatim Snowflake responses
from running each card's STORED SQL (read from PROD_ELDORIA.CORE.FACT_MB_CARDS
and executed with EXECUTE IMMEDIATE) with Tier = 'Tier 1' and Serviceability
Segment = 'Vanilla'. See SKILL.md for the exact statement.

Usage:
    python3 reconcile.py 2026-11-16 2026-11-22 [--out docs/<file>.md]
"""
from __future__ import annotations

import argparse
import datetime as _dt
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from build_report import f_int, f_money, f_pct  # noqa: E402
from hcvlib import load_export, num  # noqa: E402
from metrics import Cube  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("start")
    ap.add_argument("end")
    ap.add_argument("--data", default=str(HERE / "data"))
    ap.add_argument("--out")
    args = ap.parse_args()

    a, b = _dt.date.fromisoformat(args.start), _dt.date.fromisoformat(args.end)
    dates = [(a + _dt.timedelta(days=i)).isoformat() for i in range((b - a).days + 1)]
    rec = HERE / "docs" / "reconciliation"
    c86 = load_export(rec / f"card_55586_{args.start}_{args.end}.json")
    c87 = load_export(rec / f"card_55587_{args.start}_{args.end}.json")
    if len(c86) != 1 or len(c87) != 1:
        sys.exit("each card result must be exactly one row (one week)")
    c86, c87 = c86[0], c87[0]

    s = Cube(args.data).sums(dates)
    r_ff = 100.0 * s["COMPLETED"] / s["DEMAND"]
    k_ff = 100.0 * num(c86["COMPLETED"]) / num(c86["DEMAND"])

    def gap(x, y):
        return f"{100.0 * (x - y) / y:+.2f}%"

    rows = [
        ("Demand", f_int(s["DEMAND"]), f_int(num(c86["DEMAND"])),
         f_int(s["DEMAND"] - num(c86["DEMAND"])), gap(s["DEMAND"], num(c86["DEMAND"])), "55586"),
        ("Completed orders", f_int(s["COMPLETED"]), f_int(num(c86["COMPLETED"])),
         f_int(s["COMPLETED"] - num(c86["COMPLETED"])),
         gap(s["COMPLETED"], num(c86["COMPLETED"])), "55586"),
        *[(lab, f_int(s[k]), f_int(num(c86[ck])), f_int(s[k] - num(c86[ck])),
           gap(s[k], num(c86[ck])), "55586")
          for lab, k, ck in (("Allocated orders", "ALLOCATED", "ALLOCATED"),
                             ("CADF orders", "CADF", "CADF_ORDERS"),
                             ("CBDF orders", "CBDF", "CBDF_ORDERS"))],
        ("Fulfilment %", f"{r_ff:.2f}%", f"{k_ff:.2f}%", f"{r_ff - k_ff:+.2f}pp", "", "55586"),
        ("Revenue", f_money(s["REVENUE"]), f_money(num(c87["REVEUNE"])),
         f_money(s["REVENUE"] - num(c87["REVEUNE"])),
         gap(s["REVENUE"], num(c87["REVEUNE"])), "55587"),
        ("Completed orders (revenue card)", f_int(s["COMPLETED"]),
         f_int(num(c87["COMPLETED_ORDER"])),
         f_int(s["COMPLETED"] - num(c87["COMPLETED_ORDER"])),
         gap(s["COMPLETED"], num(c87["COMPLETED_ORDER"])), "55587"),
    ]
    lines = [
        "```text",
        "What this is:      Reconciliation of the HCV intracity ops report against dashboard 6406's card SQL for one full week.",
        "Who it's for:      The report owner, checking that the report ties to the dashboard.",
        "What to do with it: Accept or question the report's Demand, Fulfilment % and Revenue.",
        "Status:            reviewed",
        "```", "",
        f"# Reconciliation vs dashboard 6406 — {args.start} to {args.end}", "",
        "Scope on both sides: Tier 1, serviceability segment Vanilla (intracity).", "",
        "| Metric | Report | Dashboard 6406 card | Difference | Gap | Card |",
        "|---|---:|---:|---:|---:|---|",
    ] + [f"| {' | '.join(r)} |" for r in rows] + [
        "",
        f"Unrounded revenue: report {s['REVENUE']:.2f}, card {num(c87['REVEUNE']):.2f}.", "",
        "Card 55587 does not use the report's revenue definition: it reads raw OMS and "
        "schedule-order tables, sums the final fare from `order_fares`, and dates orders on "
        "`created_at`. The report follows hcv-data: `sum(FO_CUSTOMER_FARE_WITHOUT_PREVIOUS_DUE)` "
        "on completed orders in `HCV_OVERALL_DEMAND_MART`, dated on `order_time`.", "",
        "Sources: `data/hcv_daily_orders_*.json` (report side) and "
        f"`docs/reconciliation/card_*_{args.start}_{args.end}.json` (card side, verbatim "
        "Snowflake responses including their query ids).",
    ]
    text = "\n".join(lines) + "\n"
    if args.out:
        pathlib.Path(args.out).write_text(text)
    print(text)


if __name__ == "__main__":
    main()
