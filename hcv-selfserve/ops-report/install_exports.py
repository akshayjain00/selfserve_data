#!/usr/bin/env python3
"""Move query exports from inbox/ into data/, validating each before it is trusted.

Adapted from the reference pipeline's install_exports.py. Nothing reaches
data/ unless EVERY export of the run passes; a failure names the export and
the reason and exits non-zero. Checks, per export:

  * present, valid, non-empty, and complete (row count == Snowflake numRows)
  * carries THIS run's tag (a day-stale file with the same shape is refused)
  * has every column the manifest requires
  * daily_orders: dates inside the chunk's range and every date of the range
    present; one row per key; N_ROWS == DEMAND (no join fan-out);
    CBDF_SO + CBDF_MO == CBDF; CADF splits <= CADF; COMPLETED + CADF <= ALLOCATED
  * daily_dap: dates inside the run's range, one row per key
  * period_alloc: every window of the manifest present, one row per key

Conservation: rows read == rows installed; there is no row-level rejection —
an export is installed whole or not at all.

Usage:
    python3 install_exports.py [--inbox inbox] [--data data] [--sql sql]
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import pathlib
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from hcvlib import SUM_KEYS, ExportError, num, parse_export  # noqa: E402


def _dates(a: str, b: str) -> set[str]:
    x, y = _dt.date.fromisoformat(a), _dt.date.fromisoformat(b)
    return {(x + _dt.timedelta(days=i)).isoformat() for i in range((y - x).days + 1)}


def _dupes(rows: list[dict], key: tuple[str, ...]) -> int:
    seen = set()
    n = 0
    for r in rows:
        k = tuple(r[c] for c in key)
        n += k in seen
        seen.add(k)
    return n


def check_orders(rows: list[dict], rng: list[str]) -> list[str]:
    out = []
    want = _dates(*rng)
    have = {r["D"] for r in rows}
    if have - want:
        out.append(f"dates outside {rng}: {sorted(have - want)[:5]}")
    if want - have:
        out.append(f"dates with no rows: {sorted(want - have)}")
    if _dupes(rows, ("D", "CITY", "VM", "OT")):
        out.append("duplicate (D, CITY, VM, OT) keys")
    bad = {"fan-out (N_ROWS != DEMAND)": 0, "CBDF_SO + CBDF_MO != CBDF": 0,
           "CADF splits > CADF": 0, "COMPLETED + CADF > ALLOCATED": 0,
           "negative or blank value": 0}
    for r in rows:
        v = {k: num(r[k]) for k in ["N_ROWS"] + SUM_KEYS}
        if any(x is None or x < 0 for x in v.values()):
            bad["negative or blank value"] += 1
            continue
        bad["fan-out (N_ROWS != DEMAND)"] += v["N_ROWS"] != v["DEMAND"]
        bad["CBDF_SO + CBDF_MO != CBDF"] += v["CBDF_SO"] + v["CBDF_MO"] != v["CBDF"]
        bad["CADF splits > CADF"] += (v["CADF_CUSTOMER"] + v["CADF_PARTNER"]
                                      + v["CADF_PORTER"]) > v["CADF"]
        bad["COMPLETED + CADF > ALLOCATED"] += v["COMPLETED"] + v["CADF"] > v["ALLOCATED"]
    out += [f"{k}: {n} rows" for k, n in bad.items() if n]
    return out


def check_dap(rows: list[dict], rng: list[str]) -> list[str]:
    out = []
    have = {r["D"] for r in rows}
    if have - _dates(*rng):
        out.append(f"dates outside {rng}: {sorted(have - _dates(*rng))[:5]}")
    if _dupes(rows, ("D", "CITY", "VM")):
        out.append("duplicate (D, CITY, VM) keys")
    return out


def check_alloc(rows: list[dict], periods: list[str]) -> list[str]:
    out = []
    have = {r["PERIOD"] for r in rows if r["CUT"] == "ALL"}
    if set(periods) - have:
        out.append(f"missing windows {sorted(set(periods) - have)}")
    if {r["PERIOD"] for r in rows} - set(periods):
        out.append("carries windows this run did not ask for")
    if _dupes(rows, ("PERIOD", "CUT", "K")):
        out.append("duplicate (PERIOD, CUT, K) keys")
    return out


def validate(name: str, text: str, manifest: dict) -> tuple[list[dict], list[str]]:
    """Return (rows, problems) for one export."""
    try:
        rows, tag = parse_export(text)
    except ExportError as e:
        return [], [str(e)]
    if not rows:
        return rows, ["export is empty"]
    probs = []
    if tag != manifest["tags"][name]:
        probs.append(f"tag {tag!r} is not this run's {manifest['tags'][name]!r} "
                     "(stale or mis-named export)")
    lacking = [c for c in manifest["required_cols"][name] if c not in rows[0]]
    if lacking:
        return rows, probs + [f"missing columns {lacking}"]
    if name in manifest["orders_chunks"]:
        probs += check_orders(rows, manifest["orders_chunks"][name])
    elif name == "daily_dap":
        probs += check_dap(rows, manifest["date_range"])
    elif name == "period_alloc":
        probs += check_alloc(rows, manifest["periods"])
    return rows, probs


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--inbox", default=str(HERE / "inbox"))
    ap.add_argument("--data", default=str(HERE / "data"))
    ap.add_argument("--sql", default=str(HERE / "sql"))
    args = ap.parse_args()

    inbox, data = pathlib.Path(args.inbox), pathlib.Path(args.data)
    manifest = json.loads((pathlib.Path(args.sql) / "manifest.json").read_text())

    report, problems, ok = {}, [], {}
    for name in manifest["queries"]:
        f = inbox / f"hcv_{name}.json"
        if not f.exists():
            problems.append(f"{name}: no export at {f}")
            continue
        rows, probs = validate(name, f.read_text(), manifest)
        problems += [f"{name}: {p} — NOT installed" for p in probs]
        if not probs:
            ok[name] = f
            report[name] = {"rows": len(rows)}
            if name in manifest["orders_chunks"]:
                report[name]["demand"] = sum(num(r["DEMAND"]) for r in rows)

    warnings = []
    if not problems:
        data.mkdir(parents=True, exist_ok=True)
        for stale in data.glob("hcv_*.json"):     # no export of an older shape survives
            stale.unlink()
        for name, f in ok.items():
            shutil.copy2(f, data / f"hcv_{name}.json")
        # DAP lands late: a missing newest day is a caveat, not a refusal.
        dap_rows, _ = parse_export((data / "hcv_daily_dap.json").read_text())
        last = max(r["D"] for r in dap_rows)
        if last < manifest["analysis_end"]:
            warnings.append(f"daily_dap: newest day is {last}, analysis ends "
                            f"{manifest['analysis_end']} — DAP is averaged over covered days")
        (data / "install_report.json").write_text(json.dumps({
            "analysis_end": manifest["analysis_end"],
            "installed_at": _dt.datetime.now().astimezone().isoformat(timespec="seconds"),
            "exports": report, "warnings": warnings}, indent=2) + "\n")
        shutil.copy2(pathlib.Path(args.sql) / "manifest.json", data / "manifest.json")

    print(json.dumps({"installed": {} if problems else report,
                      "warnings": warnings, "problems": problems}, indent=2))
    if problems:
        sys.exit(1)


if __name__ == "__main__":
    main()
