#!/usr/bin/env python3
"""Render the HCV intracity ops report: one self-contained HTML page, no script.

Every figure is formatted here from the validated exports in data/ through
metrics.Cube; nothing in the page is typed by hand. Tabs are pure CSS, so the
page works with JavaScript disabled and prints with every pane expanded.

Usage:
    python3 build_report.py [--data data] [--out PATH] [--status draft|reviewed|final]
"""

from __future__ import annotations

import argparse
import datetime as _dt
import html
import json
import pathlib
import sys
from decimal import ROUND_HALF_UP, Decimal

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from hcvlib import ORDER_TYPES  # noqa: E402
from metrics import (CUTS, META, METRICS, P_MIN_N, SUB_METRICS,  # noqa: E402
                     UNUSUAL_TOL, Cube, delta)

MINUS = "−"

# (current window, comparison window, title, comparison wording)
WINS = [
    ("D1", "SW4", "Yesterday", "avg of last 4 same weekdays"),
    ("WTD", "LWTD", "Week to date", "last week, same days"),
    ("MTD", "LMTD", "Month to date", "last month, same days"),
]
CUT_COLS = [("demand", True), ("alloc_pct", False), ("ff_pct", True), ("cadf_pct", False),
            ("cadf_customer_pct", False), ("cadf_partner_pct", False),
            ("cadf_porter_pct", False), ("cbdf_pct", False), ("cbdf_so_pct", False),
            ("cbdf_mo_pct", False), ("cbdf_customer_pct", False), ("cbdf_porter_pct", False),
            ("cbdf_other_pct", False), ("revenue", True), ("aov", False), ("dap", False),
            ("alloc_p50", False), ("alloc_p90", True)]
STRIP_COLS = ["demand", "alloc_pct", "ff_pct", "cadf_pct", "cadf_customer_pct",
              "cadf_partner_pct", "cadf_porter_pct", "cbdf_pct", "cbdf_so_pct",
              "cbdf_mo_pct", "cbdf_customer_pct", "cbdf_porter_pct", "cbdf_other_pct",
              "revenue", "aov", "dap", "alloc_p50", "alloc_p90"]
REASON_TOP = 12
ATTR_LABEL = {"customer": "Customer", "partner": "Partner", "porter": "Porter",
              "none": "None recorded", "conflict": "Conflicting"}
STAGE_LABEL = {"CADF": "After driver found (CADF)", "CBDF": "Before driver found (CBDF)"}
HEAD_KEYS = ["demand", "ff_pct", "revenue"]


# --------------------------------------------------------------------------
# Formatting — round once, half up, on the whole value
# --------------------------------------------------------------------------


def _q(x: float, places: str) -> Decimal:
    return Decimal(repr(float(x))).quantize(Decimal(places), ROUND_HALF_UP)


def f_int(n: float) -> str:
    """Whole number with Indian digit grouping (12,34,567)."""
    v = int(_q(n, "1"))
    s, neg = str(abs(v)), v < 0
    if len(s) > 3:
        head, tail = s[:-3], s[-3:]
        parts = []
        while len(head) > 2:
            parts.insert(0, head[-2:])
            head = head[:-2]
        s = ",".join(([head] if head else []) + parts + [tail])
    return (MINUS if neg else "") + s


def f_money(v: float) -> str:
    sign, a = (MINUS if v < 0 else ""), abs(v)
    if a >= 1e7:
        return f"{sign}₹{_q(a / 1e7, '0.01')} Cr"
    if a >= 1e5:
        return f"{sign}₹{_q(a / 1e5, '0.01')} L"
    return f"{sign}₹{f_int(a)}"


def f_pct(v: float) -> str:
    return f"{_q(v, '0.1')}%"


def f_time(secs: float) -> str:
    s = int(_q(abs(secs), "1"))
    return f"{s}s" if s < 60 else f"{s // 60}m {s % 60:02d}s"


def fmt(key: str, v) -> str:
    if v is None:
        return ""
    kind = META[key][3]
    if kind == "pct":
        return f_pct(v)
    if kind == "money":
        return f_money(v)
    if kind == "aov":
        return "₹" + f_int(v)
    if kind == "time":
        return f_time(v)
    return f_int(v)


def f_delta(v, unit) -> str:
    if v is None:
        return ""
    if unit == "s":
        if int(_q(abs(v), "1")) == 0:
            return "0s"
        return ("+" if v > 0 else MINUS) + f_time(v)
    q = _q(v, "0.1")
    if q == 0:
        return f"0.0{unit}"
    return ("+" if q > 0 else MINUS) + f"{abs(q)}{unit}"


def d_cls(key: str, v, unit) -> str:
    """Colour a change by whether it is good for the business, not by its sign."""
    good = META[key][4]
    if v is None or not good:
        return "flat"
    zero = int(_q(abs(v), "1")) == 0 if unit == "s" else _q(v, "0.1") == 0
    if zero:
        return "flat"
    return "pos" if (v > 0) == (good > 0) else "neg"


def e(s) -> str:
    return html.escape(str(s))


def td_delta(key: str, cur, base) -> str:
    v, u = delta(key, cur, base)
    return f'<td class="d {d_cls(key, v, u)}">{f_delta(v, u)}</td>'


# --------------------------------------------------------------------------
# Sections
# --------------------------------------------------------------------------


def win_label(cube: Cube, win: str) -> str:
    lab = cube.m["labels"]
    return {"D1": lab["day"], "SW4": lab["sw4"]}.get(win) or lab[win.lower()]


def notes(cube: Cube) -> list[str]:
    """Reading caveats, each derived from the data in hand."""
    out = []
    p = cube.p
    n_w = (p.wtd[1] - p.wtd[0]).days + 1
    if n_w == 1:
        out.append("The week so far is one day, so <b>Week to date</b> equals "
                   "<b>Yesterday</b> and compares one weekday with the same weekday last week.")
    if p.analysis_end.day <= 3:
        out.append(f"The month so far is {p.analysis_end.day} day(s); month-to-date "
                   "readings are thin until more days accumulate.")

    def days(ds):
        return ", ".join(f"{_dt.date.fromisoformat(d).strftime('%a %d %b')} "
                         f"({f_delta(v, '%')})" for d, v in ds)

    tol = f_int(100 * UNUSUAL_TOL)
    for win, title in (("MTD", "This month to date"), ("LMTD", "The comparison month"),
                       ("SW4", "Yesterday's four-weekday baseline")):
        odd = cube.unusual_days(cube.dates(win))
        if odd:
            out.append(f"<b>{title}</b> contains {len(odd)} day(s) whose demand is more than "
                       f"{tol}% away from the usual level for that weekday: {days(odd)}. "
                       "Read the changes for that window with these days in mind; the figure "
                       "in brackets is each day against the median of the same weekday over "
                       "all days loaded.")
    ip, dem = cube.in_progress("D1")
    if ip > 0 and dem:
        out.append(f"{f_int(ip)} of yesterday's orders ({f_pct(100.0 * ip / dem)} of demand) "
                   "had a driver but were neither completed nor cancelled when the data was "
                   "pulled, so yesterday's Fulfilment % can still rise by up to that much.")
    absent = [lab for code, lab in ORDER_TYPES.items() if code not in cube.members("OT")]
    if absent:
        out.append(f"No order in this scope classifies as <b>{', '.join(absent)}</b> in the "
                   "dates loaded, so the order-type cut has no row for it.")
    strip = [d.isoformat() for d in p.strip_days]
    no_dap = [d for d in strip if d not in cube.dap_days]
    if no_dap:
        out.append(f"DAP has not loaded for {len(no_dap)} of the last {len(strip)} days "
                   f"({', '.join(_dt.date.fromisoformat(d).strftime('%d %b') for d in no_dap)}). "
                   "DAP averages cover only the days that have loaded.")
    un, tot = cube.cadf_unattributed("MTD")
    if un and tot:
        out.append(f"{f_int(un)} of {f_int(tot)} month-to-date CADF orders "
                   f"({f_pct(100.0 * un / tot)}) carry no customer / partner / porter "
                   "attribution, so the three CADF splits sum to less than CADF %.")
    if "UNMAPPED" in cube.members("VM"):
        out.append("Some orders sit on a vehicle with no <code>vehicle_mapping</code>; "
                   "they appear as <b>UNMAPPED</b> in the vehicle cut and count in the total.")
    return out


def headline(cube: Cube) -> str:
    cards = []
    for cur, base, title, versus in WINS:
        c, b = cube.cell(cur), cube.cell(base)
        rows = []
        for k in HEAD_KEYS:
            v, u = delta(k, c[k], b[k])
            rows.append(
                f'<div class="kpi"><div class="kl">{e(META[k][1])}</div>'
                f'<div class="kv">{fmt(k, c[k])}</div>'
                f'<div class="kd {d_cls(k, v, u)}">{f_delta(v, u)}</div></div>')
        cards.append(
            f'<div class="card"><div class="ct">{e(title)}</div>'
            f'<div class="cw">{e(win_label(cube, cur))}</div>{"".join(rows)}'
            f'<div class="cb">vs {e(versus)} ({e(win_label(cube, base))})</div></div>')
    return f'<div class="cards">{"".join(cards)}</div>'


def scorecard(cube: Cube) -> str:
    cells = {w: cube.cell(w) for pair in WINS for w in pair[:2]}
    h1 = "".join(f'<th colspan="3" class="g">{e(t)}<span class="basis">'
                 f'{e(win_label(cube, cur))}</span></th>' for cur, _, t, _ in WINS)
    h2 = "".join(f'<th>Value</th><th>{e(v.capitalize())}</th><th>Change</th>'
                 for _, _, _, v in WINS)
    body = []
    for key, label, basis, _, _ in METRICS:
        sub = " sub" if key in SUB_METRICS else ""
        tds = "".join(
            f'<td>{fmt(key, cells[cur][key])}</td>'
            f'<td class="b">{fmt(key, cells[base][key])}</td>'
            + td_delta(key, cells[cur][key], cells[base][key])
            for cur, base, _, _ in WINS)
        body.append(f'<tr class="m{sub}"><td class="lab">{e(label)}'
                    f'<span class="basis">{e(basis)}</span></td>{tds}</tr>')
    return (f'<div class="scroll"><table class="grid sc"><thead>'
            f'<tr><th rowspan="2" class="lab">Metric</th>{h1}</tr><tr>{h2}</tr></thead>'
            f'<tbody>{"".join(body)}</tbody></table></div>')


def _cut_head(first: str, delta_note: str) -> str:
    ths = []
    for key, has_d in CUT_COLS:
        _, label, basis, _, _ = META[key]
        cls = ' class="subh"' if key in SUB_METRICS else ""
        ths.append(f'<th{cls}>{e(label)}<span class="basis">{e(basis)}</span></th>')
        if has_d:
            ths.append(f'<th class="d">{e(label)} change<span class="basis">'
                       f'{e(delta_note)}</span></th>')
    return f'<thead><tr><th class="lab">{e(first)}</th>{"".join(ths)}</tr></thead>'


def _cut_row(label: str, cur: dict, base: dict, cls: str = "") -> str:
    tds = []
    for key, has_d in CUT_COLS:
        tds.append(f"<td>{fmt(key, cur[key])}</td>")
        if has_d:
            tds.append(td_delta(key, cur[key], base[key]))
    return f'<tr class="{cls}"><td class="lab">{e(label)}</td>{"".join(tds)}</tr>'


def cut_section(cube: Cube, cut: str) -> str:
    radios, tabs, panes = [], [], []
    for i, (cur, base, title, versus) in enumerate(WINS):
        rid = f"w-{cut}-{cur}"
        chk = " checked" if cur == "WTD" else ""
        radios.append(f'<input type="radio" class="r r-{cur}" name="w-{cut}" id="{rid}"{chk}>')
        tabs.append(f'<label class="l-{cur}" for="{rid}">{e(title)}</label>')
        rows = [_cut_row(cube.label(cut, k), cube.cell(cur, cut, k), cube.cell(base, cut, k))
                for k in cube.members(cut)]
        rows.append(_cut_row("Tier 1 total", cube.cell(cur), cube.cell(base), "tot"))
        panes.append(
            f'<div class="pane p-{cur}"><div class="cap">{e(title)}: '
            f'{e(win_label(cube, cur))} · change is vs {e(versus)} '
            f'({e(win_label(cube, base))})</div><div class="scroll"><table class="grid">'
            f'{_cut_head(CUTS[cut], "vs " + versus)}<tbody>{"".join(rows)}</tbody>'
            f'</table></div></div>')
    return (f'<div class="cut">{"".join(radios)}<div class="tabs">{"".join(tabs)}</div>'
            f'{"".join(panes)}</div>')


def reasons_section(cube: Cube) -> str:
    """Cancelled orders by reason. Rows are ranked once, on month to date, so
    the same reasons sit in the same order under every tab."""
    rank = cube.reason_counts("MTD")
    keys = sorted(rank, key=lambda k: (-rank[k], k))
    top, rest = keys[:REASON_TOP], set(keys[REASON_TOP:])
    radios, tabs, panes = [], [], []
    for cur, base, title, versus in WINS:
        rid = f"w-RS-{cur}"
        chk = " checked" if cur == "MTD" else ""
        radios.append(f'<input type="radio" class="r r-{cur}" name="w-RS" id="{rid}"{chk}>')
        tabs.append(f'<label class="l-{cur}" for="{rid}">{e(title)}</label>')
        c, b = cube.reason_counts(cur), cube.reason_counts(base)
        dc, db = cube.cell(cur)["demand"], cube.cell(base)["demand"]

        def row(label, stage, attr, n_c, n_b, cls=""):
            pc = (100.0 * n_c / dc) if dc else None
            pb = (100.0 * n_b / db) if db else None
            v, u = delta("cadf_pct", pc, pb)
            return (f'<tr class="{cls}"><td class="lab">{e(label)}</td>'
                    f'<td class="t">{e(stage)}</td><td class="t">{e(attr)}</td>'
                    f'<td>{f_int(n_c) if n_c else ""}</td>'
                    f'<td>{f_pct(pc) if pc is not None and n_c else ""}</td>'
                    f'<td class="d {d_cls("cadf_pct", v, u)}">{f_delta(v, u)}</td></tr>')

        rows = [row(k[2], STAGE_LABEL[k[0]], ATTR_LABEL.get(k[1], k[1]),
                    c.get(k, 0), b.get(k, 0)) for k in top]
        other_c = sum(v for k, v in c.items() if k not in top)
        other_b = sum(v for k, v in b.items() if k not in top)
        if rest or other_c or other_b:
            rows.append(row(f"All other reasons ({len(rest)})", "", "", other_c, other_b))
        rows.append(row("All cancelled orders", "CADF + CBDF", "",
                        sum(c.values()), sum(b.values()), "tot"))
        panes.append(
            f'<div class="pane p-{cur}"><div class="cap">{e(title)}: '
            f'{e(win_label(cube, cur))} · change is vs {e(versus)} '
            f'({e(win_label(cube, base))})</div><div class="scroll"><table class="grid">'
            f'<thead><tr><th class="lab">Cancel reason</th><th class="t">Stage</th>'
            f'<th class="t">Attributed to</th><th>Orders</th>'
            f'<th>Share<span class="basis">% of demand</span></th>'
            f'<th class="d">Share change<span class="basis">vs {e(versus)}</span></th>'
            f'</tr></thead><tbody>{"".join(rows)}</tbody></table></div></div>')
    return (f'<div class="cut">{"".join(radios)}<div class="tabs">{"".join(tabs)}</div>'
            f'{"".join(panes)}</div>')


def strip(cube: Cube) -> str:
    ths = "".join(f'<th{" class=subh" if k in SUB_METRICS else ""}>{e(META[k][1])}'
                  f'<span class="basis">{e(META[k][2])}</span></th>' for k in STRIP_COLS)
    rows = []
    for d in cube.p.strip_days:
        c = cube.cell(f"DAY|{d.isoformat()}")
        cls = "sun" if d.weekday() == 6 else ("wk" if d.weekday() == 0 else "")
        rows.append(f'<tr class="{cls}"><td class="lab">{d.strftime("%a %d %b")}</td>'
                    + "".join(f"<td>{fmt(k, c[k])}</td>" for k in STRIP_COLS) + "</tr>")
    return (f'<div class="scroll"><table class="grid"><thead><tr><th class="lab">Day</th>'
            f'{ths}</tr></thead><tbody>{"".join(rows)}</tbody></table></div>')


DEFINITIONS = [
    ("Scope",
     "Porter HCV (9ft and above), <b>intracity</b> orders, <b>Tier 1</b> cities "
     "(<code>dim_geo_regions.tier = 'Tier 1'</code>). Source: "
     "<code>PROD_ELDORIA.MART.HCV_OVERALL_DEMAND_MART</code>, one row per order, with the "
     "standard filters <code>fo_deleted_at IS NULL</code> and "
     "<code>customer_mobile &lt;&gt; '0000000001'</code>. An order is dated on "
     "<code>date(order_time)</code>."),
    ("Intracity",
     "<code>lower(dim_vehicles.serviceability_segment) = 'vanilla'</code>, which leaves out "
     "Outstation vehicles. This is the vehicle-level definition and the same field dashboard "
     "6406 offers as its Serviceability Segment filter. “Outstation” has other governed "
     "definitions (KB gap G-104); this report does not use a route-distance rule."),
    ("Demand", "<code>count(distinct unique_id)</code>. Every order placed, whatever its outcome."),
    ("Allocated %", "Orders with <code>fo_driver_id IS NOT NULL</code> ÷ Demand."),
    ("Fulfilment %",
     "Completed orders (<code>fo_driver_id IS NOT NULL AND order_status = 4</code>) ÷ "
     "<b>Demand</b>. This is the hcv-data / dashboard 6406 definition (card 55586). The HCV "
     "knowledge base disputes this denominator (gaps G-030, G-031): schedule-only rows that "
     "never became a trip can never reach the numerator, so they pull the percentage down. "
     "This report keeps Demand as the denominator so it ties to dashboard 6406."),
    ("CADF %",
     "Cancelled after a driver was found (<code>fo_driver_id IS NOT NULL AND order_status = 5"
     "</code>) ÷ Demand. Split into customer / partner / porter by "
     "<code>dim_cancel_reasons_attribution.attribution</code>, joined on "
     "<code>fo_cancel_reason_id</code>; each split is also a % of Demand."),
    ("CBDF %",
     "Cancelled before a driver was found (<code>fo_driver_id IS NULL AND (order_status = 5 "
     "OR order_status IS NULL)</code>) ÷ Demand. <b>Stockout</b>: no matchmaking batch was "
     "ever created (<code>num_batches_created = 0</code>). <b>Missed order</b>: a batch was "
     "created and no driver accepted (<code>&gt; 0</code>). <code>num_batches_created</code> "
     "is the greater of the two production matchmaking marts "
     "(<code>HCV_FO_MATCHMAKING_MART</code>, <code>HCV_SO_MATCHMAKING_MART</code>). Dashboard "
     "card 55612 also reads a dev sandbox table here; this report does not, so its "
     "Stockout / Missed split can differ slightly from that card. A schedule booking "
     "cancelled before matchmaking starts has no batch, so it counts as Stockout."),
    ("CBDF by attribution",
     "The same CBDF orders, split a second way: by the attribution of the cancel reason "
     "recorded on the order (customer or porter), as dashboard card 60002 does. CBDF orders "
     "whose reason carries another attribution, or that have no reason recorded, are shown as "
     "<b>no attribution</b>, so the three add up to CBDF %."),
    ("Cancel reasons",
     "Cancelled orders (CADF and CBDF as defined above) grouped by "
     "<code>dim_cancel_reasons_attribution.name</code> for the order's "
     "<code>fo_cancel_reason_id</code>. The rows add up to CADF + CBDF; this is checked "
     "against the order counts before the data is used."),
    ("Revenue", "<code>sum(FO_CUSTOMER_FARE_WITHOUT_PREVIOUS_DUE)</code> on completed orders."),
    ("AOV", "Revenue ÷ completed orders."),
    ("DAP",
     "Daily active partners: a driver counts on a day when "
     "<code>sum(business_login_hours) &gt; 0.5</code> in <code>core.fact_active_partners</code>, "
     "for HCV vehicles in Tier 1 with the same intracity vehicle filter. A window shows the "
     "<b>mean of the daily counts</b> over the days that have loaded. DAP is not split by "
     "order type, because a partner is not an order type."),
    ("Allocation time",
     "Seconds from <code>order_time</code> to driver acceptance "
     "(<code>fo_trip_accepted_time</code>), over orders that have an acceptance time and a "
     "non-negative duration, as dashboard card 55527 computes it. P50 and P90 are computed in SQL for each window; a percentile cannot "
     f"be re-aggregated from daily values. A cell with fewer than {P_MIN_N} accepted orders "
     "is left blank."),
    ("Comparisons",
     "<b>Yesterday</b> is set against the average of the last four same weekdays (counts are "
     "the mean per day, percentages pool the four days, allocation time is the mean of the "
     "four daily percentiles). <b>Week to date</b> starts on Monday and is set against last "
     "week cut to the same number of days. <b>Month to date</b> is set against last month cut "
     "to the same day of the month. Percentages change in percentage points (pp), times in "
     "seconds, everything else in % of the comparison value. Green means better for the "
     "business and red worse; AOV is not coloured."),
    ("Totals and cuts",
     "Each order sits in exactly one city, one vehicle mapping and one order type, so every "
     "cut is a partition of the same orders and the Tier 1 total is computed from the orders "
     "themselves. No total is built by adding vehicle categories together."),
    ("Data maturity",
     "Orders are read as they stood when the data was pulled. The newest day can still hold "
     "trips in progress, so its Fulfilment % may rise slightly on a later pull; a note at the "
     "top of the page gives the count."),
    ("Card and gap references",
     "Card numbers are dashboard 6406 cards, whose stored SQL was read from "
     "<code>PROD_ELDORIA.CORE.FACT_MB_CARDS</code> on 27 Nov 2026. G-numbers are entries in the "
     "HCV knowledge base file <code>hcv-selfserve/kb/GAPS.md</code>. The week-level tie-out "
     "to cards 55586 and 55587 is in the reconciliation note beside this report."),
    ("Blank cells", "A blank cell means there is nothing to measure (no demand, no completed "
     "order, DAP not loaded, or too few orders for a percentile). It never means zero."),
]


CSS = """
:root{--ink:#16202e;--mute:#5d6b7c;--line:#d8dee6;--navy:#1b365d;--band:#eef2f7;
--pos:#0b6b3a;--posbg:#e6f4ec;--neg:#a4262c;--negbg:#fbe9ea;--bg:#fff;--page:#f4f6f9}
*{box-sizing:border-box}
body{margin:0;background:var(--page);color:var(--ink);
font:14px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
.wrap{max-width:1280px;margin:0 auto;padding:20px 16px 48px}
header.mast{background:var(--navy);color:#fff;padding:18px 22px;border-radius:4px}
header.mast h1{margin:0;font-size:22px;font-weight:650;letter-spacing:.1px}
header.mast .sub{margin-top:4px;color:#cfd9e8;font-size:13px}
.about{background:var(--bg);border:1px solid var(--line);border-top:0;padding:10px 22px;
font-size:12.5px;color:var(--mute);display:grid;grid-template-columns:150px 1fr;gap:2px 12px}
.about b{color:var(--ink);font-weight:600}
h2{font-size:16px;margin:30px 0 4px;color:var(--navy);border-bottom:2px solid var(--navy);
padding-bottom:5px}
p.lead{margin:6px 0 10px;color:var(--mute);font-size:13px;max-width:900px}
.notes{margin:14px 0 0;padding:10px 14px 10px 30px;background:#fff8e6;border:1px solid #ecd9a0;
border-radius:4px;font-size:13px}
.notes li{margin:3px 0}
.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-top:10px}
.card{background:var(--bg);border:1px solid var(--line);border-top:3px solid var(--navy);
border-radius:3px;padding:12px 14px}
.ct{font-weight:650;font-size:15px}.cw{color:var(--mute);font-size:12.5px;margin-bottom:8px}
.kpi{display:grid;grid-template-columns:1fr auto auto;gap:10px;align-items:baseline;
padding:5px 0;border-top:1px solid var(--line)}
.kl{color:var(--mute)}.kv{font-size:18px;font-weight:650;font-variant-numeric:tabular-nums}
.kd{font-variant-numeric:tabular-nums;font-weight:600;min-width:64px;text-align:right;
padding:1px 6px;border-radius:2px}
.cb{margin-top:8px;color:var(--mute);font-size:12px}
.scroll{overflow-x:auto;background:var(--bg);border:1px solid var(--line);border-radius:3px;
-webkit-overflow-scrolling:touch}
table.grid{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums;font-size:13px}
table.grid th,table.grid td{padding:6px 9px;text-align:right;white-space:nowrap;
border-bottom:1px solid var(--line)}
table.grid thead th{background:var(--navy);color:#fff;font-weight:600;vertical-align:bottom;
border-bottom:0;border-left:1px solid rgba(255,255,255,.18)}
table.grid thead th.g{text-align:center}
table.grid th.t,table.grid td.t{text-align:left}
table.grid thead th.subh{font-weight:400;font-style:italic}
table.grid th.lab,table.grid td.lab{text-align:left;position:sticky;left:0;z-index:1}
table.grid td.lab{background:var(--bg);font-weight:600;border-right:1px solid var(--line)}
table.grid thead th.lab{background:var(--navy);z-index:2}
.basis{display:block;font-weight:400;font-size:11px;opacity:.75}
td.lab .basis{color:var(--mute);opacity:1}
tr.sub td.lab{font-weight:400;padding-left:24px}
tr.sub td{color:#3c4858}
td.b{color:var(--mute)}
td.d,.kd{font-weight:600}
.pos{color:var(--pos);background:var(--posbg)}.neg{color:var(--neg);background:var(--negbg)}
.flat{color:var(--mute)}
tr.tot td{background:var(--band);font-weight:650;border-top:2px solid var(--navy)}
tr.tot td.lab{background:var(--band)}
tr.tot td.pos{background:var(--posbg)}tr.tot td.neg{background:var(--negbg)}
tr.sun td,tr.sun td.lab{background:#f7f8fa;color:var(--mute)}
tr.wk td{border-top:2px solid #9aa7b8}
.cut{margin-top:8px}.cut>input.r{position:absolute;opacity:0;pointer-events:none}
.tabs{display:flex;gap:6px;margin-bottom:8px;flex-wrap:wrap}
.tabs label{padding:5px 12px;border:1px solid var(--navy);border-radius:2px;cursor:pointer;
color:var(--navy);background:var(--bg);font-size:13px;font-weight:600}
.cut .pane{display:none}
.cut>input.r-D1:checked~.p-D1,.cut>input.r-WTD:checked~.p-WTD,
.cut>input.r-MTD:checked~.p-MTD{display:block}
.cut>input.r-D1:checked~.tabs .l-D1,.cut>input.r-WTD:checked~.tabs .l-WTD,
.cut>input.r-MTD:checked~.tabs .l-MTD{background:var(--navy);color:#fff}
.cut>input.r:focus-visible~.tabs{outline:2px solid #5b8def;outline-offset:2px}
.cap{font-size:12.5px;color:var(--mute);margin-bottom:5px}
dl.defs{display:grid;grid-template-columns:170px 1fr;gap:0;background:var(--bg);
border:1px solid var(--line);border-radius:3px;margin:8px 0 0;font-size:13px}
dl.defs dt,dl.defs dd{margin:0;padding:8px 12px;border-bottom:1px solid var(--line)}
dl.defs dt{font-weight:650;background:var(--band)}
code{font:12px/1.3 ui-monospace,SFMono-Regular,Menlo,monospace;background:#eef1f5;
padding:1px 4px;border-radius:2px;overflow-wrap:anywhere}
footer{margin-top:26px;padding-top:10px;border-top:2px solid var(--navy);color:var(--mute);
font-size:12px}
footer table{border-collapse:collapse;margin-top:6px}
footer td,footer th{padding:2px 14px 2px 0;text-align:left;font-variant-numeric:tabular-nums}
@media (max-width:820px){.cards{grid-template-columns:1fr}.wrap{padding:10px 8px 32px}
.about{grid-template-columns:1fr}dl.defs{grid-template-columns:1fr}
table.grid td.lab,table.grid th.lab{max-width:130px;white-space:normal}}
@media print{body{background:#fff}.tabs{display:none}.cut .pane{display:block;
margin-bottom:14px}.scroll{overflow:visible;border:0}table.grid{font-size:10px}
table.grid th.lab,table.grid td.lab{position:static}}
"""


def build(cube: Cube, install: dict, status: str) -> str:
    m = cube.m
    lab = m["labels"]
    nts = notes(cube)
    notes_html = (f'<ul class="notes">{"".join(f"<li>{n}</li>" for n in nts)}</ul>'
                  if nts else "")
    cut_lead = {"OT": '<p class="lead">For Schedule orders, “Stockout” mostly means the '
                'booking was cancelled before matchmaking began, because no batch exists '
                'until then. It is not on its own evidence of a supply shortage.</p>'}
    cuts_html = "".join(
        f'<h2>By {e(CUTS[c].lower())}</h2>{cut_lead.get(c, "")}{cut_section(cube, c)}'
        for c in CUTS)
    defs = "".join(f"<dt>{e(t)}</dt><dd>{d}</dd>" for t, d in DEFINITIONS)
    exp_rows = "".join(
        f'<tr><td><code>{e(n)}</code></td><td>{f_int(v["rows"])} rows</td>'
        f'<td><code>{e(m["tags"][n])}</code></td></tr>'
        for n, v in install["exports"].items())
    warn = "".join(f"<div>Note: {e(w)}</div>" for w in install.get("warnings", []))
    gen = _dt.datetime.now().astimezone().strftime("%d %b %Y %H:%M %Z")
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>HCV intracity ops report · {e(lab['day'])}</title>
<style>{CSS}</style></head><body><div class="wrap">
<header class="mast"><h1>HCV intracity ops report</h1>
<div class="sub">Data to {e(lab['day'])} · Tier 1 · intracity · 9ft and above · generated {e(gen)}</div>
</header>
<div class="about">
<b>What this is</b><span>A daily read of Porter's HCV intracity marketplace: how yesterday went, and how the week and the month are going.</span>
<b>Who it's for</b><span>HCV business and operations leads. No knowledge of the underlying tables is assumed; every metric is defined at the bottom.</span>
<b>What to do with it</b><span>Find where demand, fulfilment or revenue moved, then use the vehicle, order-type and city cuts to see which part moved it.</span>
<b>Status</b><span>{e(status)}</span>
</div>
{notes_html}
<h2>Headline</h2>
<p class="lead">Tier 1 total. Each change is against the comparison named under the card.</p>
{headline(cube)}
<h2>Scorecard</h2>
<p class="lead">Tier 1 total, every metric, in each window beside its like-for-like comparison. Indented rows are parts of the row above them.</p>
{scorecard(cube)}
{cuts_html}
<h2>Cancel reasons</h2>
<p class="lead">Tier 1 total. Every cancelled order, by the reason recorded on it, whether it was cancelled before or after a driver was found, and who the reason is attributed to. The {REASON_TOP} largest reasons month to date are listed; the rest are grouped.</p>
{reasons_section(cube)}
<h2>Last 14 days</h2>
<p class="lead">Tier 1 total by day. A heavier rule marks each Monday; Sundays are shaded.</p>
{strip(cube)}
<h2>Definitions</h2>
<p class="lead">Definitions follow the hcv-data reference for dashboard 6406. Where the HCV knowledge base disagrees, the choice made here is stated.</p>
<dl class="defs">{defs}</dl>
<footer>
<div>Every figure on this page is rendered by code from the exports below, which were validated against the run manifest before use (installed {e(install['installed_at'])}).</div>
{warn}
<table><tr><th>Export</th><th>Size</th><th>Run tag</th></tr>{exp_rows}</table>
<div style="margin-top:6px">Pipeline: <code>hcv-selfserve/ops-report</code> · re-run instructions in its <code>SKILL.md</code>.</div>
</footer>
</div></body></html>
"""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=str(HERE / "data"))
    ap.add_argument("--out")
    ap.add_argument("--status", default="draft", choices=["draft", "reviewed", "final"])
    args = ap.parse_args()

    data = pathlib.Path(args.data)
    cube = Cube(data)
    install = json.loads((data / "install_report.json").read_text())
    if install["analysis_end"] != cube.m["analysis_end"]:
        sys.exit("data/ holds exports from a different run than its manifest")
    out = pathlib.Path(args.out) if args.out else (
        HERE / "docs" / f"{cube.m['run_date']}-hcv-intracity-ops-report.html")
    out.parent.mkdir(parents=True, exist_ok=True)
    page = build(cube, install, args.status)
    for bad in (">None<", "nan<", ">nan"):
        if bad in page:
            sys.exit(f"refusing to write: rendered page contains {bad!r}")
    out.write_text(page)
    print(out)


if __name__ == "__main__":
    main()
