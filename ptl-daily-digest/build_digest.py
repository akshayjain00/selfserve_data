"""Build the PTL daily digest HTML from saved query results.

Usage: python3 daily-digest/build_digest.py [--end YYYY-MM-DD] [--no-downloads]
Reads work/*.txt (written after running make_sql.py), merges daily rows into
data/daily.json, then writes the digest to out/, the project artifact file and ~/Downloads.
"""
import argparse
import json
import os
import re
import shutil
import sys
from datetime import date, datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as c


# ----------------------------------------------------------------------------- merge daily rows
def merge_daily(hist):
    spec = {
        "daily_orders": ("orders", "net", "gross"),
        "daily_created": ("placed", "completed", "est_rev"),
        "daily_util": ("uw", "uc"),
        "daily_opt": ("on", "ot"),
        "daily_return": ("bt", "br"),
    }
    for name, keys in spec.items():
        s = c.read_s(name)
        if not s:
            print(f"! missing work/{name}.txt - keeping existing history for those fields")
            continue
        for rec in s.split(";"):
            p = rec.split(",")
            d = str(c.parse8(p[0]))
            row = hist.setdefault(d, {})
            for k, v in zip(keys, p[1:]):
                row[k] = float(v) if v != "" else None
    return hist


# ----------------------------------------------------------------------------- metric maths
M = {
    "orders": ("add", lambda r: r["orders"]),
    "netrev": ("add", lambda r: r["net"]),
    "grossrev": ("add", lambda r: r["gross"] if r.get("gross") is not None else r["net"]),
    "ff": ("ratio", lambda r: (r["completed"], r["placed"]), 100),
    "aov": ("ratio", lambda r: (r["est_rev"], r["completed"]), 1),
    "util": ("ratio", lambda r: (r["uw"], r["uc"]), 100),
    "opt": ("ratio", lambda r: (r["on"], r["ot"]), 1),
    "ret": ("ratio", lambda r: (r["br"], r["bt"]), 100),
}
REQ = ["orders", "net", "placed", "completed", "est_rev", "uw", "uc", "on", "ot", "bt", "br"]
dd = timedelta


def days(a, b):
    return [a + dd(days=i) for i in range((b - a).days + 1)]


def compute(hist, D):
    ok = lambda x: str(x) in hist and all(hist[str(x)].get(k) is not None for k in REQ)
    if not ok(D):
        missing = [k for k in REQ if hist.get(str(D), {}).get(k) is None]
        raise SystemExit(f"latest day {D} is missing fields {missing} - rerun the daily queries")

    def win(m, ds):
        sp = M[m]
        rows = [hist[str(x)] for x in ds]
        if sp[0] == "add":
            return sum(sp[1](r) for r in rows)
        n = sum(sp[1](r)[0] for r in rows)
        den = sum(sp[1](r)[1] for r in rows)
        return n / den * sp[2]

    def avg_windows(m, windows):
        windows = [w for w in windows if all(ok(x) for x in w)]
        if not windows:
            return None, 0
        sp = M[m]
        if sp[0] == "add":
            return sum(win(m, w) for w in windows) / len(windows), len(windows)
        return win(m, [x for w in windows for x in w]), len(windows)

    week_start = D - dd(days=D.weekday())
    k_week = (D - week_start).days + 1
    mt0 = date(D.year, D.month, 1)
    kd = D.day

    def month_back(n):
        y, mo = D.year, D.month - n
        while mo <= 0:
            mo += 12
            y -= 1
        return date(y, mo, 1)

    res = {}
    for m in M:
        pp = M[m][0] == "ratio" and M[m][-1] == 100
        r = {"unit_pp": pp}
        r["day"] = win(m, [D])
        r["day_lw"] = win(m, [D - dd(days=7)])
        r["day_4w"] = win(m, [D - dd(days=28)])
        r["day_avg3"], _ = avg_windows(m, [[x] for x in days(D - dd(days=90), D - dd(days=1))])
        r["day_avg6"], _ = avg_windows(m, [[x] for x in days(D - dd(days=180), D - dd(days=1))])
        r["wtd"] = win(m, days(week_start, D))
        r["wtd_4w"] = win(m, days(week_start - dd(days=28), D - dd(days=28)))
        wk = lambda i: days(week_start - dd(weeks=i), week_start - dd(weeks=i) + dd(days=k_week - 1))
        r["wtd_avg3"], _ = avg_windows(m, [wk(i) for i in range(1, 14)])
        r["wtd_avg6"], _ = avg_windows(m, [wk(i) for i in range(1, 27)])
        r["mtd"] = win(m, days(mt0, D))
        ms1 = month_back(1)
        r["mtd_lm"] = win(m, days(ms1, ms1 + dd(days=kd - 1)))
        mm = lambda i: days(month_back(i), month_back(i) + dd(days=kd - 1))
        r["mtd_avg3"], _ = avg_windows(m, [mm(i) for i in range(1, 4)])
        r["mtd_avg6"], _ = avg_windows(m, [mm(i) for i in range(1, 7)])
        f = (lambda a, b: a - b) if pp else (lambda a, b: (a - b) / b * 100)
        r["d_lw"] = f(r["day"], r["day_lw"])
        r["d_4w"] = f(r["day"], r["day_4w"])
        r["d_mtd"] = f(r["mtd"], r["mtd_lm"])
        r["d_wtd"] = f(r["wtd"], r["wtd_4w"])
        r["spark"] = [win(m, [x]) for x in days(D - dd(days=29), D)]
        res[m] = r
    return res, dict(week_start=week_start, k_week=k_week, mt0=mt0, kd=kd, lm0=month_back(1))


# ----------------------------------------------------------------------------- formatting
LABEL = {"orders": "Orders Completed", "netrev": "Net Revenue", "grossrev": "Gross Revenue", "ff": "Fulfilment Rate",
         "aov": "Average Order Value", "util": "Truck Utilization", "opt": "Orders per Trip", "ret": "Return Trip Share"}
ORDER = ["orders", "netrev", "grossrev", "ff", "aov", "util", "opt", "ret"]
PROV = {"ff", "aov", "util", "opt", "ret"}
ARW = {"good": "▲", "warn": "▬", "crit": "▼"}


def dl(d, wd=False):
    s = f"{d.day} {d.strftime('%b')}"
    return (d.strftime("%a ") + s) if wd else s


def rg(a, b):
    return dl(a) if a == b else f"{dl(a)}&ndash;{dl(b)}"


def money(v):
    return f"₹{v/1e7:.2f} Cr" if abs(v) >= 1e7 else f"₹{v/1e5:.2f} L"


def fmtv(m, v):
    if v is None:
        return "&mdash;"
    if m == "orders":
        return f"{round(v):,}"
    if m in ("netrev", "grossrev"):
        return money(v)
    if m in ("ff", "util", "ret"):
        return f"{v:.1f}%"
    if m == "aov":
        return f"₹{round(v):,}"
    return f"{v:.2f}"


def band(x, pp):
    t = 1.0 if pp else 2.0
    return "good" if x > t else ("crit" if x < -t else "warn")


def dtxt(x, pp):
    return f"{'+' if x >= 0 else '−'}{abs(x):.1f}{'pp' if pp else '%'}"


def disp(label):
    return " &rarr; ".join(x.replace("Mysore", "Mysuru") for x in label.split("-"))


def disp_js(label):
    return " → ".join(x.replace("Mysore", "Mysuru") for x in label.split("-"))


def span(d0, n):
    names = [(d0 + dd(days=i)).strftime("%a") for i in range(n)]
    return names[0] if n == 1 else f"{names[0]}&ndash;{names[-1]}"


# ----------------------------------------------------------------------------- route data
def parse_rows(name, n):
    s = c.read_s(name)
    if not s:
        raise SystemExit(f"missing work/{name}.txt")
    out = {}
    for rec in s.split(";"):
        p = rec.split(",")
        out[p[0]] = tuple(float(x) for x in p[1:1 + n])
    return out


def build(D, res, per, w, ago):
    week_start, kd, mt0, lm0 = per["week_start"], per["kd"], per["mt0"], per["lm0"]
    lm1 = lm0 + dd(days=kd - 1)
    wk4_0, wk4_1 = week_start - dd(days=28), D - dd(days=28)
    D7, D28 = D - dd(days=7), D - dd(days=28)

    A = parse_rows("route_a", 4)   # placed, completed, quick, est_rev
    B = parse_rows("route_b", 2)   # net, gross
    C = parse_rows("route_c", 2)   # orders in batches, trips
    Dd = parse_rows("route_d", 2)  # weight, capacity

    # ---- cards
    cards = []
    for m in ORDER:
        r = res[m]
        pp = r["unit_pp"]
        bm, bw = band(r["d_mtd"], pp), band(r["d_wtd"], pp)
        cards.append(
            f'<div class="kpi {bm}"><p class="label">{LABEL[m]}</p>'
            f'<p class="value"><span class="tag">MTD</span>{fmtv(m, r["mtd"])}</p>'
            f'<p class="delta"><span class="arrow {bm}">{ARW[bm]}</span> {dtxt(r["d_mtd"], pp)} vs {rg(lm0, lm1)}</p>'
            f'<p class="wtd"><span class="tag">WTD</span><b>{fmtv(m, r["wtd"])}</b> &middot; '
            f'<span class="arrow {bw}">{ARW[bw]}</span> {dtxt(r["d_wtd"], pp)} vs {rg(wk4_0, wk4_1)}</p></div>')

    # ---- trend table
    def trow(m):
        r = res[m]
        pp = r["unit_pp"]
        prov = m in PROV
        f = lambda k: fmtv(m, r[k])
        vcls = "num prov" if prov else "num"
        dag = "<sup>†</sup>" if prov else ""
        o = [f'<tr id="row-{m}"><th scope="row"><span class="rowlabel"><button class="disc" type="button" aria-expanded="false" '
             f'aria-controls="chart-{m}" data-slot="{m}"><span class="tri">▶</span></button>{LABEL[m]}</span></th>',
             f'<td class="{vcls} sep">{f("day")}{dag}</td>']
        for k in ("d_lw", "d_4w"):
            b = "prov" if prov else band(r[k], pp)
            o.append(f'<td class="num"><span class="dot {b}"></span>{dtxt(r[k], pp)}</td>')
        o.append(f'<td class="num">{f("day_avg3")}</td><td class="num">{f("day_avg6")}</td>')
        o.append(f'<td class="{vcls} sep">{f("mtd")}{dag}</td><td class="num">{f("mtd_lm")}</td>')
        o.append(f'<td class="num"><span class="dot {band(r["d_mtd"], pp)}"></span>{dtxt(r["d_mtd"], pp)}</td>')
        o.append(f'<td class="num">{f("mtd_avg3")}</td><td class="num">{f("mtd_avg6")}</td>')
        o.append(f'<td class="{vcls} sep">{f("wtd")}{dag}</td><td class="num">{f("wtd_4w")}</td>')
        o.append(f'<td class="num"><span class="dot {band(r["d_wtd"], pp)}"></span>{dtxt(r["d_wtd"], pp)}</td>')
        o.append(f'<td class="num">{f("wtd_avg3")}</td><td class="num">{f("wtd_avg6")}</td></tr>')
        o.append(f'<tr class="chartrow" id="chart-{m}" hidden><td colspan="16"></td></tr>')
        return "\n".join(o)

    rows = "\n".join(trow(m) for m in ORDER)
    hdr = f'''<thead>
<tr class="grp">
  <th scope="col" rowspan="2" class="stick">Metric</th>
  <th scope="colgroup" colspan="5" class="sep">Latest day &middot; {dl(D, True)}</th>
  <th scope="colgroup" colspan="5" class="sep">Month to date &middot; {rg(mt0, D)}</th>
  <th scope="colgroup" colspan="5" class="sep">Week to date &middot; {rg(week_start, D)}</th>
</tr>
<tr>
  <th scope="col" class="sep">Value</th><th scope="col">vs {dl(D7, True)}</th><th scope="col">vs {dl(D28, True)}</th><th scope="col">3-Mo Avg / day</th><th scope="col">6-Mo Avg / day</th>
  <th scope="col" class="sep">{rg(mt0, D)}</th><th scope="col">{rg(lm0, lm1)}</th><th scope="col">Change</th><th scope="col">3-Mo Avg (days 1&ndash;{kd})</th><th scope="col">6-Mo Avg (days 1&ndash;{kd})</th>
  <th scope="col" class="sep">{rg(week_start, D)}</th><th scope="col">{rg(wk4_0, wk4_1)}</th><th scope="col">Change</th><th scope="col">3-Mo Avg / week</th><th scope="col">6-Mo Avg / week</th>
</tr></thead>'''

    # ---- routes (last 7 days)
    ranked = sorted(A, key=lambda k: (-A[k][1], -B.get(k, (0, 0))[0], k))
    top10 = ranked[:10]

    def agg(labels):
        pl = sum(A[k][0] for k in labels)
        co = sum(A[k][1] for k in labels)
        qc = sum(A[k][2] for k in labels)
        rev = sum(A[k][3] for k in labels)
        g = lambda D_, k: D_.get(k, (0, 0))
        on, tr = sum(g(C, k)[0] for k in labels), sum(g(C, k)[1] for k in labels)
        wt, cp = sum(g(Dd, k)[0] for k in labels), sum(g(Dd, k)[1] for k in labels)
        return dict(orders=co, net=sum(g(B, k)[0] for k in labels), gross=sum(g(B, k)[1] for k in labels),
                    ff=100 * co / pl if pl else float("nan"), ffx=100 * co / (pl - qc) if pl - qc else float("nan"),
                    aov=rev / co if co else float("nan"), opt=on / tr if tr else float("nan"),
                    util=100 * wt / cp if cp else float("nan"))

    def rrow(name, a, cls=""):
        cl = f' class="{cls}"' if cls else ""
        ffx = "&mdash;" if cls == "totalrow" else f'{a["ffx"]:.1f}%'
        return (f'<tr{cl}><th scope="row">{name}</th><td class="num">{a["orders"]:,.0f}</td><td class="num">{money(a["net"])}</td>'
                f'<td class="num">{money(a["gross"])}</td><td class="num">{a["ff"]:.1f}%</td><td class="num">{ffx}</td>'
                f'<td class="num">₹{round(a["aov"]):,}</td><td class="num">{a["opt"]:.2f}</td><td class="num">{a["util"]:.1f}%</td></tr>')

    rest = [k for k in A if k not in top10]
    route_rows = [rrow(disp(k), agg([k])) for k in top10]
    route_rows.append(rrow(f"Other routes ({len(rest)})", agg(rest), "otherrow"))
    route_rows.append(rrow("All routes", agg(list(A)), "totalrow"))

    def corr(a, b):
        f_, r_ = f"{a}-{b}", f"{b}-{a}"
        labs = [k for k in (f_, r_) if k in A]
        return agg(labs), (A[f_][1] if f_ in A else 0), (A[r_][1] if r_ in A else 0)

    # corridors: pair each route with its reverse leg; hub city is listed first so direction stays stable day to day
    HUBS = ["Mumbai", "Bangalore", "Hyderabad", "Chennai", "Pune"]

    def hub_order(a, b):
        ia = HUBS.index(a) if a in HUBS else 99
        ib = HUBS.index(b) if b in HUBS else 99
        if ia != ib:
            return (a, b) if ia < ib else (b, a)
        return (a, b) if a <= b else (b, a)

    two, one, seen = [], [], set()
    for k in ranked[:30]:
        a, b = k.split("-", 1)
        key = frozenset((a, b))
        if key in seen:
            continue
        seen.add(key)
        fa, fb = hub_order(a, b)
        f_, r_ = f"{fa}-{fb}", f"{fb}-{fa}"
        if f_ in A and r_ in A:
            two.append((fa, fb) + corr(fa, fb))
        else:
            x, y = (fa, fb) if f_ in A else (fb, fa)
            one.append((x, y) + corr(x, y))
    two.sort(key=lambda x: -x[2]["orders"])
    one.sort(key=lambda x: -x[2]["orders"])
    corr_rows = []
    for a, b, t, fo, ro in two[:8]:
        nm = f"{a} &harr; {b}".replace("Mysore", "Mysuru")
        corr_rows.append(f'<tr><th scope="row">{nm}</th><td class="num">{t["orders"]:,.0f}</td><td class="num">{money(t["net"])}</td>'
                         f'<td class="num">{money(t["gross"])}</td><td class="num">{t["ff"]:.1f}%</td>'
                         f'<td class="num">{fo:.0f} / {ro:.0f}</td><td class="num">{100*ro/(fo+ro):.0f}%</td></tr>')
    for a, b, t, fo, ro in one[:3]:
        corr_rows.append(f'<tr class="otherrow"><th scope="row">{a} &rarr; {b} (one-way)</th><td class="num">{t["orders"]:,.0f}</td>'
                         f'<td class="num">{money(t["net"])}</td><td class="num">{money(t["gross"])}</td><td class="num">{t["ff"]:.1f}%</td>'
                         f'<td class="num">{fo:.0f} / &mdash;</td><td class="num">&mdash;</td></tr>')

    # ---- weekly route trends (full Monday-Sunday weeks)
    wkly = {}
    s = c.read_s("route_weekly")
    if not s:
        raise SystemExit("missing work/route_weekly.txt")
    for rec in s.split(";"):
        label, body = rec.split("|", 1)
        wkly[label] = {c.parse8(x.split(":")[0]): (int(x.split(":")[1]), int(x.split(":")[2])) for x in body.split(",")}
    starts = [w["weekly0"] + dd(weeks=i) for i in range(13)]
    routes_js = {}
    for k in top10:
        if k not in wkly:
            print(f"! no weekly data for {k}, skipping its trend card")
            continue
        pts = [wkly[k].get(sd, (0, 0)) for sd in starts]
        routes_js[disp_js(k)] = {"orders": [p[1] for p in pts],
                                 "ff": [round(100 * p[1] / p[0], 2) if p[0] else 0 for p in pts]}

    series = {m: {"unit": {"orders": "count", "netrev": "rev", "grossrev": "rev", "ff": "pct", "aov": "rupee", "util": "pct", "opt": "ratio", "ret": "pct"}[m],
                  "vals": [round(v, 2) for v in res[m]["spark"]]} for m in ORDER}
    js_series = "var SERIES = {\n" + ",\n".join(f'  {m}: {json.dumps(v, separators=(",", ":"))}' for m, v in series.items()) + "\n};"
    js_routes = "var ROUTES = " + json.dumps(routes_js, ensure_ascii=False, separators=(",", ":")) + ";"
    tl = lambda d: f"{d.day:02d} {d.strftime('%b')}"
    d0 = D - dd(days=29)
    day_ticks = [[0, tl(d0)], [7, tl(d0 + dd(days=7))], [14, tl(d0 + dd(days=14))], [21, tl(d0 + dd(days=21))], [29, tl(D)]]
    week_all = [[i, tl(sd)] for i, sd in enumerate(starts)]

    this_sp, last_sp = span(mt0, kd), span(lm0, kd)
    mix = f" against {last_sp} last month, so weekday mix differs" if this_sp != last_sp else " against the same days last month"
    mtd_note = (f"MTD covers only {kd} day{'s' if kd > 1 else ''} so far ({this_sp}){mix}. " if kd < 15 else "")
    kw = per["k_week"]
    wtd_note = (f"WTD covers only {kw} day{'s' if kw > 1 else ''} so far ({span(week_start, kw)}). " if kw < 3 else "")
    stamp = datetime.now(c.IST).strftime("%d %b %H:%M IST")

    body = f'''<main>

  <div class="pagehead">
    <div>
      <h1>PTL Daily Digest</h1>
      <p class="sub">Latest day {dl(D, True)} ({ago} days ago) &middot; week {rg(week_start, D)} &middot; month {rg(mt0, D)} &middot; internal test users excluded &middot; generated {stamp}</p>
    </div>
  </div>

  <div class="tabs">
    <button type="button" class="active" data-tab="overview">Overview</button>
    <button type="button" data-tab="deepdive">Route Deep Dive</button>
  </div>

  <div class="tabpanel" id="tab-overview">

    <section aria-labelledby="kpihead">
      <h2 class="sectitle" id="kpihead">This month (MTD) &amp; this week (WTD) at a glance</h2>
      <div class="kpi-grid">
        {chr(10).join("        " + x for x in cards).strip()}
      </div>
      <p class="fnotes">{mtd_note}{wtd_note}Fulfilment, Order Value, Orders per Trip and Utilization include {dl(D)}, which is still settling.</p>
    </section>

    <section aria-labelledby="trendhead">
      <h2 class="sectitle" id="trendhead">How each number is trending</h2>
      <div class="tablewrap">
        <table>
          {hdr}
          <tbody>
{rows}
          </tbody>
        </table>
      </div>
      <p class="fnotes"><b>Latest day</b> is the day before yesterday. Grey dots and &dagger; mark numbers that are still settling at that age (26 Sep read 49.6% Fulfilment at 2 days old and settled at 55.0%); Orders and Revenue are final.<br>
      <b>Compared with:</b> same weekday last week and 4 weeks ago; same first {kd} day{'s' if kd > 1 else ''} of last month; same Monday-to-date span 4 weeks earlier.<br>
      <b>3-Mo / 6-Mo Avg:</b> per day for the day view; the same {kd}-day window of each previous 3 / 6 months for month; the same week-to-date span of the previous 13 / 26 weeks for week. Ratios are pooled, not averaged. Dots: green or red beyond &plusmn;2% (&plusmn;1pp for rates).</p>
    </section>

    <section aria-labelledby="routehead">
      <h2 class="sectitle" id="routehead">Top routes, last 7 days</h2>
      <p class="note">Top 10 routes by orders completed, {rg(w["route0"], D)}; the other {len(rest)} routes are grouped as Other.</p>
      <div class="tablewrap">
        <table>
          <thead><tr>
            <th scope="col" class="stick">Route</th><th scope="col">Orders</th><th scope="col">Net Revenue</th><th scope="col">Gross Revenue</th>
            <th scope="col">Fulfilment Rate</th><th scope="col">Fulfilment Rate (excl. quick cancels)</th>
            <th scope="col">Average Order Value</th><th scope="col">Orders per Trip</th><th scope="col">Truck Utilization</th>
          </tr></thead>
          <tbody>
{chr(10).join(route_rows)}
          </tbody>
        </table>
      </div>
      <p class="fnotes">Average Order Value uses the quoted fare at booking; Orders per Trip and Truck Utilization are batch-level for the same days.</p>
    </section>

    <section aria-labelledby="corridorhead">
      <h2 class="sectitle" id="corridorhead">Corridors: forward + return, last 7 days</h2>
      <p class="note">Each route paired with its reverse leg. Lanes marked one-way have no return route configured.</p>
      <div class="tablewrap">
        <table>
          <thead><tr>
            <th scope="col" class="stick">Corridor</th><th scope="col">Total Orders</th><th scope="col">Net Revenue</th><th scope="col">Gross Revenue</th>
            <th scope="col">Fulfilment Rate</th><th scope="col">Forward / Return Orders</th><th scope="col">Return Share</th>
          </tr></thead>
          <tbody>
{chr(10).join(corr_rows)}
          </tbody>
        </table>
      </div>
    </section>

  </div>

  <div class="tabpanel" id="tab-deepdive" hidden>
    <section aria-labelledby="deephead">
      <h2 class="sectitle" id="deephead">Route trends, weekly (last 13 full weeks)</h2>
      <p class="note">Orders completed and Fulfilment Rate per full Monday&ndash;Sunday week for the top 10 routes; latest full week is {rg(w["last_mon"], w["weekly1"])}.</p>
      <div class="route-grid" id="routeGrid"></div>
    </section>
  </div>

</main>'''
    return body, js_series, js_routes, day_ticks, week_all


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--end", default=None)
    ap.add_argument("--no-downloads", action="store_true")
    a = ap.parse_args()
    D = date.fromisoformat(a.end) if a.end else c.default_end()
    hist = merge_daily(c.load_hist())
    c.save_hist(hist)
    w = c.windows(D, hist)
    res, per = compute(hist, D)
    ago = (c.today_ist() - D).days
    body, js_series, js_routes, day_ticks, week_all = build(D, res, per, w, ago)

    tpl = open(os.path.join(c.ROOT, "template.html")).read()
    tpl = re.sub(r"<main>.*?</main>", lambda m: body, tpl, flags=re.S)
    tpl = re.sub(r"var SERIES = \{.*?\n\};", lambda m: js_series, tpl, flags=re.S)
    tpl = re.sub(r"var ROUTES = .*?;\n", lambda m: js_routes + "\n", tpl)
    tpl = re.sub(r"var DAY_TICKS = .*?;\n", lambda m: "var DAY_TICKS = " + json.dumps(day_ticks) + ";\n", tpl)
    tpl = re.sub(r"var WEEK_ALL = .*?;\n", lambda m: "var WEEK_ALL = " + json.dumps(week_all) + ";\n", tpl)
    tpl = tpl.replace("orders this week", "orders, latest full week")
    # chart axis labels should reflect that routes use full weeks
    os.makedirs(c.OUT, exist_ok=True)
    name = f"PTL-Daily-Digest-{D}.html"
    open(os.path.join(c.OUT, name), "w").write(tpl)
    proj = os.path.join(c.OUT, "PTL-Daily-Digest-LATEST.html")
    open(proj, "w").write(tpl)
    print(f"built {name} ({len(tpl):,} bytes) for latest day {D}")
    dl_dir = os.path.expanduser("~/Downloads")
    if not a.no_downloads and os.path.isdir(dl_dir):
        shutil.copy(proj, os.path.join(dl_dir, name))
        shutil.copy(proj, os.path.join(dl_dir, "PTL-Daily-Digest-LATEST.html"))
        print(f"saved to {dl_dir}/{name} and PTL-Daily-Digest-LATEST.html")
    r = res
    print("\nKEY NUMBERS")
    for m in ORDER:
        print(f"  {LABEL[m]:22s} day {fmtv(m, r[m]['day']):>10s} | MTD {fmtv(m, r[m]['mtd']):>10s} ({dtxt(r[m]['d_mtd'], r[m]['unit_pp'])}) | WTD {fmtv(m, r[m]['wtd']):>10s} ({dtxt(r[m]['d_wtd'], r[m]['unit_pp'])})")


if __name__ == "__main__":
    main()
