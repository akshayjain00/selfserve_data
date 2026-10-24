"""City-level weekly trend section (user request 1 Oct): 11 Key Metrics x (Network + 9 cities) x last 13 full weeks.
Cells are tinted vs that row's own 13-week mean (same scale: any worsening = Amber, darker beyond 20%; no neutral band, user 12 Oct); last column = sparkline."""
import os, datetime as dt

CW = os.environ.get('DATA_DIR', 'data') + '/city_weekly/'
ROWS = ['Network', 'Bangalore', 'Delhi NCR', 'Mumbai', 'Hyderabad', 'Pune', 'Chennai', 'Tier 2 (combined)', 'Ahmedabad', 'Kolkata']

def _load(fn, names):
    out = {}
    for rec in open(CW + fn).read().strip().split(';'):
        if not rec.strip(): continue
        p = rec.split('|'); city, wk = p[0], p[1]
        for i, n in enumerate(names):
            if len(p) > 2 + i and p[2 + i] not in ('',):
                out.setdefault(n, {}).setdefault(city, {})[wk] = float(p[2 + i])
    return out

def load_all():
    D = {}
    D.update(_load('leads_orders.txt', ['leads', 'orders', 'conv']))
    D.update(_load('aov_surge.txt', ['aov', 'surge']))
    D.update(_load('canc_dealloc.txt', ['canc', 'dealloc']))
    D.update(_load('ota.txt', ['ota']))
    D.update(_load('tpo_nps.txt', ['tpo', 'nps', 'detr']))
    return D

# (key, title, direction: True higher-better / False lower-better / None no colour, formatter)
METRICS = [
    ('orders', 'No. of orders booked', True, lambda v: f"{v:,.0f}"),
    ('conv', 'Conversion % &mdash; Overall <span class="segtag">Overall &middot; Nano filter n/a</span>', True, lambda v: f"{v:.1f}%"),
    ('leads', 'Leads &mdash; Overall <span class="segtag">Overall &middot; Nano filter n/a</span>', True, lambda v: f"{v:,.0f}"),
    ('aov', 'AOV (&#8377;)', True, lambda v: f"{v:,.0f}"),
    ('surge', '% orders with surge', None, lambda v: f"{v:.1f}%"),
    ('canc', 'Cancellation %', False, lambda v: f"{v:.1f}%"),
    ('dealloc', 'Deallocation %', False, lambda v: f"{v:.1f}%"),
    ('ota', 'On Time Arrival %', True, lambda v: f"{v:.1f}%"),
    ('tpo', 'TPO &mdash; Overall', False, lambda v: f"{v:.2f}"),
    ('nps', 'Overall NPS', True, lambda v: f"{v:.0f}"),
    ('detr', 'Overall Detractors %', False, lambda v: f"{v:.1f}%"),
]

def _spark(vals, w=92, h=22):
    lo, hi = min(vals), max(vals); rng = (hi - lo) or 1
    pts = [(2 + i * (w - 4) / (len(vals) - 1), h - 3 - (v - lo) / rng * (h - 6)) for i, v in enumerate(vals)]
    poly = ' '.join(f"{x:.1f},{y:.1f}" for x, y in pts)
    lx, ly = pts[-1]
    return (f'<svg class="spark" width="{w}" height="{h}" viewBox="0 0 {w} {h}" aria-hidden="true">'
            f'<polyline points="{poly}" fill="none" stroke="var(--ink-soft)" stroke-width="1.4" stroke-linejoin="round"/>'
            f'<circle cx="{lx:.1f}" cy="{ly:.1f}" r="2.2" fill="var(--ink)"/></svg>')

def section(heat_class, weeks):
    D = load_all()
    lab = lambda w: dt.date.fromisoformat(w).strftime('%-d %b')
    keys = [dt.date.fromisoformat(w).strftime('%m%d') for w in weeks]
    out = ['<div class="metric-group city-trend" id="city-trend">',
           f'<div class="group-label">City trends &mdash; weekly</div>',
           f'<div class="trend-sub">Last {len(weeks)} full weeks (Mon&ndash;Sun, week starting {lab(weeks[0])} &ndash; {lab(weeks[-1])}). '
           'Cell colour vs that city&rsquo;s own {0}-week average.</div>'.format(len(weeks))]
    for i, (k, title, hb, fmt) in enumerate(METRICS):
        hdr = '<tr><th>City</th>' + ''.join(f'<th>{lab(w)}</th>' for w in weeks) + '<th>Trend</th></tr>'
        rows = []
        for c in ROWS:
            series = D.get(k, {}).get(c, {})
            vals = [series.get(kk) for kk in keys]
            present = [v for v in vals if v is not None]
            mean = sum(present) / len(present) if present else None
            cells = []
            for v in vals:
                if v is None:
                    cells.append('<td class="hcell hna">&mdash;</td>'); continue
                cls = 'hna' if hb is None or not mean else heat_class((v - mean) / mean, hb)
                cells.append(f'<td class="hcell {cls}">{fmt(v)}</td>')
            sp = _spark(present) if len(present) > 1 else ''
            rc = ' class="trend-net"' if c == 'Network' else ''
            rows.append(f'<tr{rc}><td class="mname">{c}</td>' + ''.join(cells) + f'<td class="sparkcell">{sp}</td></tr>')
        out.append(f'<details class="bucket-detail trend-detail"{" open" if i == 0 else ""}><summary><span class="exp-metric-header" style="display:inline;margin:0;">{title}</span></summary>'
                   '<div class="scroll" tabindex="0" role="region" aria-label="Scrollable data table">'
                   f'<table class="metric-table trend-table">{hdr}{"".join(rows)}</table></div></details>')
    out.append('</div>')
    return '\n'.join(out)

CSS = """
  /* ---- City weekly trends ---- */
  .city-trend .trend-sub{font-size:12px;color:var(--ink-faint);margin:2px 0 12px;}
  table.trend-table td, table.trend-table th{padding:6px 7px;font-size:12px;white-space:nowrap;text-align:right;}
  table.trend-table td.mname, table.trend-table th:first-child{text-align:left;}
  table.trend-table tr.trend-net td{font-weight:700;border-bottom:2px solid var(--line);}
  table.trend-table td.sparkcell{background:var(--panel);text-align:center;padding:2px 6px;}
  .trend-detail summary{cursor:pointer;}
"""
