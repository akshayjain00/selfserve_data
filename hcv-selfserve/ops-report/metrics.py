#!/usr/bin/env python3
"""Metric cube for the HCV intracity ops report.

Composable sums (date x city x vehicle x order type) are windowed here in
Python; allocation-time percentiles are read per window as SQL computed them.
Definitions follow the hcv-data skill; every percentage is over Demand.
A cell with no denominator is None (rendered blank) — never zero.
"""

from __future__ import annotations

import datetime as _dt
import json
import pathlib
import re
from collections import defaultdict

from hcvlib import ORDER_TYPES, SUM_KEYS, Periods, load_export, num

P_MIN_N = 30          # a percentile on fewer allocated orders is blanked
UNUSUAL_TOL = 0.20    # a day this far from its same-weekday median is flagged

CUTS = {"VM": "Vehicle", "OT": "Order type", "CITY": "City"}

# key, label, basis (what the number is "of"), kind, good direction (+1 up is good)
METRICS = [
    ("demand", "Demand", "orders placed", "count", +1),
    ("alloc_pct", "Allocated %", "% of demand", "pct", +1),
    ("ff_pct", "Fulfilment %", "% of demand", "pct", +1),
    ("cadf_pct", "CADF %", "% of demand", "pct", -1),
    ("cadf_customer_pct", "customer", "% of demand", "pct", -1),
    ("cadf_partner_pct", "partner", "% of demand", "pct", -1),
    ("cadf_porter_pct", "porter", "% of demand", "pct", -1),
    ("cbdf_pct", "CBDF %", "% of demand", "pct", -1),
    ("cbdf_so_pct", "Stockout", "% of demand", "pct", -1),
    ("cbdf_mo_pct", "Missed order", "% of demand", "pct", -1),
    ("revenue", "Revenue", "₹, completed orders", "money", +1),
    ("aov", "AOV", "₹ per completed order", "aov", 0),
    ("dap", "DAP", "partners per day", "dap", +1),
    ("alloc_p50", "Alloc time P50", "order placed → accepted", "time", -1),
    ("alloc_p90", "Alloc time P90", "order placed → accepted", "time", -1),
]
META = {m[0]: m for m in METRICS}
SUB_METRICS = {"cadf_customer_pct", "cadf_partner_pct", "cadf_porter_pct",
               "cbdf_so_pct", "cbdf_mo_pct"}


def derive(s: dict, days: float = 1.0) -> dict:
    """Sums -> metrics. ``days`` > 1 turns counts into a per-day mean (SW4)."""
    d = s.get("DEMAND") or 0

    def pct(k):
        return (100.0 * s.get(k, 0) / d) if d else None

    comp = s.get("COMPLETED") or 0
    rev = s.get("REVENUE") or 0
    return {
        "demand": (d / days) if d else None,
        "alloc_pct": pct("ALLOCATED"),
        "ff_pct": pct("COMPLETED"),
        "cadf_pct": pct("CADF"),
        "cadf_customer_pct": pct("CADF_CUSTOMER"),
        "cadf_partner_pct": pct("CADF_PARTNER"),
        "cadf_porter_pct": pct("CADF_PORTER"),
        "cbdf_pct": pct("CBDF"),
        "cbdf_so_pct": pct("CBDF_SO"),
        "cbdf_mo_pct": pct("CBDF_MO"),
        "revenue": (rev / days) if d else None,
        "aov": (rev / comp) if comp else None,
        "completed": (comp / days) if d else None,
    }


def delta(key: str, cur, base):
    """(value, unit) of the change. Percentages move in pp, times in seconds,
    everything else in % of the base. None when either side is blank."""
    if cur is None or base is None:
        return None, None
    kind = META[key][3]
    if kind == "pct":
        return cur - base, "pp"
    if kind == "time":
        return cur - base, "s"
    if not base:
        return None, None
    return 100.0 * (cur - base) / base, "%"


def _vm_sort(v: str):
    m = re.match(r"(\d+(?:\.\d+)?)", v)
    return (0, float(m.group(1)), v) if m else (1, 0.0, v)


class Cube:
    def __init__(self, data_dir, manifest: dict | None = None):
        data = pathlib.Path(data_dir)
        self.m = manifest or json.loads((data / "manifest.json").read_text())
        self.p = Periods(_dt.date.fromisoformat(self.m["analysis_end"]))

        self.orders: dict[tuple, dict] = {}
        for f in sorted(data.glob("hcv_daily_orders_*.json")):
            for r in load_export(f):
                k = (r["D"], str(r["CITY"]), r["VM"], r["OT"])
                if k in self.orders:
                    raise ValueError(f"duplicate order cell {k} across chunks")
                self.orders[k] = {c: num(r[c]) for c in SUM_KEYS}

        self.dap: dict[tuple, int] = {}
        for r in load_export(data / "hcv_daily_dap.json"):
            self.dap[(r["D"], str(r["CITY"]), r["VM"])] = num(r["DAP"])
        self.dap_days = {k[0] for k in self.dap}

        self.alloc: dict[tuple, tuple] = {}
        self.city_names: dict[str, str] = {}
        for r in load_export(data / "hcv_period_alloc.json"):
            self.alloc[(r["PERIOD"], r["CUT"], str(r["K"]))] = (
                num(r["ALLOC_N"]), num(r["P50"]), num(r["P90"]))
            if r["CUT"] == "CITY" and r.get("LABEL"):
                self.city_names[str(r["K"])] = r["LABEL"]

    # -- windows ----------------------------------------------------------
    def dates(self, win: str) -> list[str]:
        p = self.p
        if win == "D1":
            return [p.analysis_end.isoformat()]
        if win == "SW4":
            return [d.isoformat() for d in p.sw_days]
        if win.startswith("DAY|"):
            return [win[4:]]
        a, b = p.windows[win]
        return [(a + _dt.timedelta(days=i)).isoformat() for i in range((b - a).days + 1)]

    # -- members ----------------------------------------------------------
    def members(self, cut: str) -> list[str]:
        """Members of a cut, in a stable business order."""
        idx = {"CITY": 1, "VM": 2, "OT": 3}[cut]
        seen = {k[idx] for k in self.orders}
        if cut == "OT":
            return [o for o in ORDER_TYPES if o in seen]
        if cut == "VM":
            return sorted(seen, key=_vm_sort)
        tot = defaultdict(float)
        mtd = set(self.dates("MTD"))
        for k, v in self.orders.items():
            if k[0] in mtd:
                tot[k[1]] += v["DEMAND"]
        return sorted(seen, key=lambda c: -tot[c])

    def label(self, cut: str, k: str) -> str:
        if cut == "OT":
            return ORDER_TYPES.get(k, k)
        if cut == "CITY":
            return self.city_names.get(k, f"City {k}")
        return k

    # -- aggregation ------------------------------------------------------
    @staticmethod
    def _match(key: tuple, cut: str, k: str | None) -> bool:
        return cut == "ALL" or key[{"CITY": 1, "VM": 2, "OT": 3}[cut]] == k

    def sums(self, dates: list[str], cut: str = "ALL", k: str | None = None) -> dict:
        ds = set(dates)
        out = dict.fromkeys(SUM_KEYS, 0)
        for key, v in self.orders.items():
            if key[0] in ds and self._match(key, cut, k):
                for c in SUM_KEYS:
                    out[c] += v[c]
        return out

    def dap_avg(self, dates: list[str], cut: str = "ALL", k: str | None = None):
        """Mean daily DAP over the days of the window that HAVE DAP rows."""
        if cut == "OT":
            return None        # a partner is not an order type
        covered = [d for d in dates if d in self.dap_days]
        if not covered:
            return None
        ds = set(covered)
        tot = sum(v for key, v in self.dap.items()
                  if key[0] in ds and (cut == "ALL" or key[{"CITY": 1, "VM": 2}[cut]] == k))
        return tot / len(covered)

    def _pctl(self, period: str, cut: str, k: str | None):
        n, p50, p90 = self.alloc.get((period, cut, "ALL" if cut == "ALL" else k),
                                     (None, None, None))
        if not n or n < P_MIN_N:
            return None, None
        return p50, p90

    def cell(self, win: str, cut: str = "ALL", k: str | None = None) -> dict:
        dates = self.dates(win)
        out = derive(self.sums(dates, cut, k), days=len(dates) if win == "SW4" else 1.0)
        out["dap"] = self.dap_avg(dates, cut, k)
        if win == "SW4":       # mean of the same-weekday percentiles that exist
            ps = [self._pctl(f"SWD|{d}", cut, k) for d in dates]
            for i, key in enumerate(("alloc_p50", "alloc_p90")):
                vals = [x[i] for x in ps if x[i] is not None]
                out[key] = (sum(vals) / len(vals)) if vals else None
        else:
            period = f"DAY|{dates[0]}" if win == "D1" else win
            out["alloc_p50"], out["alloc_p90"] = self._pctl(period, cut, k)
        return out

    def daily_demand(self) -> dict[str, float]:
        out: dict[str, float] = defaultdict(float)
        for k, v in self.orders.items():
            out[k[0]] += v["DEMAND"]
        return dict(out)

    def unusual_days(self, dates: list[str], tol: float = UNUSUAL_TOL) -> list[tuple[str, float]]:
        """Days whose Tier 1 demand is more than ``tol`` away from the median of
        the same weekday across every day loaded. Returns (date, % vs median)."""
        dd = self.daily_demand()
        by_wd = defaultdict(list)
        for d, v in dd.items():
            by_wd[_dt.date.fromisoformat(d).weekday()].append(v)
        out = []
        for d in dates:
            vals = sorted(by_wd[_dt.date.fromisoformat(d).weekday()])
            if len(vals) < 4 or d not in dd:
                continue
            n = len(vals)
            med = vals[n // 2] if n % 2 else (vals[n // 2 - 1] + vals[n // 2]) / 2
            dev = 100.0 * (dd[d] - med) / med
            if abs(dev) > 100.0 * tol:
                out.append((d, dev))
        return out

    def in_progress(self, win: str) -> tuple[int, int]:
        """(allocated orders neither completed nor cancelled, demand)."""
        s = self.sums(self.dates(win))
        return s["ALLOCATED"] - s["COMPLETED"] - s["CADF"], s["DEMAND"]

    def cadf_unattributed(self, win: str) -> tuple[int, int]:
        """(CADF orders with no customer/partner/porter attribution, CADF orders)."""
        s = self.sums(self.dates(win))
        return (s["CADF"] - s["CADF_CUSTOMER"] - s["CADF_PARTNER"] - s["CADF_PORTER"],
                s["CADF"])
