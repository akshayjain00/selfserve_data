import re, json, os, statistics as st
from periods import periods
P = periods(os.environ['REPORT_DATE'])      # REPORT_DATE=YYYY-MM-DD (always yesterday)
BASIS = P['RAG_BASIS']                      # 'WTD' per rules; 'MTD' on Mondays (single-day WTD) - user decision 29 Sep

D = os.environ.get('DATA_DIR','data') + '/'
SEG = os.environ.get('SEG', 'nn')   # all | nn | nano  (3-way Nano toggle, user 12 Oct)
NAN = float('nan')
isn = lambda v: v is None or v != v
def rel(a, b):
    """(a-b)/b, NaN when either side is missing or the base is 0 (e.g. Nano-only cells with no orders)."""
    return NAN if isn(a) or isn(b) or b == 0 else (a-b)/b
OVR = ' <span class="segtag">Overall &middot; Nano filter n/a</span>'   # leads + conversion are never Nano-filtered
def load_main(fn):
    out = {}
    for rec in open(D+fn).read().strip().split(';'):
        if not rec.strip(): continue
        p = rec.split('|')
        def f(x):
            try: return float(x)
            except: return None
        g = lambda i: (f(p[i]) if len(p) > i else None)
        g = (lambda gg: (lambda i: NAN if gg(i) is None else gg(i)))(g)
        # format: metric|mtd_this|mtd_last|wtd_this|wtd_last|6m_avg|3m_avg|last_week_full|n_months|6m_full|3m_full
        # b6/b3 = mean of same-days monthly values (days 1-N) -> used ONLY for colouring
        # fb6/fb3 = mean of full calendar-month values (Apr-Sep / Jul-Sep) -> shown in the 3m/6m avg columns (user 6 Oct)
        out[p[0]] = dict(mt=g(1), ml=g(2), wt=g(3), wl=g(4), b6=g(5), b3=g(6), lw=g(7), fb6=g(9), fb3=g(10))
    return out

import collections
_EMPTY = dict(mt=NAN, ml=NAN, wt=NAN, wl=NAN, b6=NAN, b3=NAN, lw=NAN, fb6=NAN, fb3=NAN)
M = collections.defaultdict(lambda: dict(_EMPTY))   # a metric absent in a segment (e.g. Nano only) renders as dashes
for fn in ['alloc.txt','leads.txt','pricing.txt','trip_edits.txt','cx.txt','ota.txt','tpo.txt','esc.txt']:
    M.update(load_main(fn))

def load_grid(txt, ncols):
    g = {}
    for rec in txt.strip().split(';'):
        if not rec.strip(): continue
        p = rec.split('|'); c, b = p[0].rsplit('.', 1)
        g[(c, b)] = [float(x) if x not in ('', None) else None for x in p[1:1+ncols]]
    return g

def section(fn, key):
    for line in open(D+fn):
        if line.startswith(key+'='): return line[len(key)+1:].strip()
    return ''   # section empty for this segment (e.g. Nano only)

G_ORD = load_grid(section('city_orders.txt','ORDERS'), 2)
CITY_LO = [(r.split('|')[0], int(r.split('|')[1]), int(r.split('|')[2])) for r in section('city_orders.txt','CITY_LO').split(';') if r.strip()]
G_AOV = load_grid(section('city_aov_surge.txt','AOV'), 2)
G_SUR = load_grid(section('city_aov_surge.txt','SURGE'), 2)
G_CD = load_grid(open(D+'city_comp_dealloc.txt').read(), 4)
G_OTA = load_grid(open(D+'city_ota.txt').read(), 2)
G_TPO = load_grid(section('city_tpo_nps.txt','TPO'), 2)
G_NPS = load_grid(section('city_tpo_nps.txt','NPS'), 5)

CITIES = ['Bangalore','Delhi NCR','Mumbai','Hyderabad','Pune','Chennai','Kolkata','Ahmedabad','Tier 2 (combined)']
BHKS = ['Nano/Micro','1BHK','2BHK','3BHK','4+BHK']
THIN = 30
MTD_DAYS = P['MTD_DAYS']

# ---------- heat scale (unchanged from scripts.py) ----------
def heat_class(d, hb):
    if hb is None or isn(d): return 'hna'
    # user 12 Oct: no neutral band any more - any worsening is Amber, at-or-better is Green (darker beyond 20%)
    d = d if hb else -d
    if d >= 0.20: return 'h5'
    if d >= 0: return 'h4'
    if d > -0.20: return 'h2'
    return 'h1'
def heat_class_vol(d, hb=True):
    """Volume rows (Leads, Orders; Leads & Orders table + City x BHK Orders grid). User 12 Oct: ANY drop is Amber,
    no neutral +/-10% band any more. Up: h4 (h5 from +20%). Down: h2 (h1 from -20%)."""
    if isn(d): return 'hna'
    d = d if hb else -d
    if d >= 0.20: return 'h5'
    if d >= 0: return 'h4'
    if d > -0.20: return 'h2'
    return 'h1'
def fmt_delta(d):
    if isn(d): return ''
    return f"{'+' if d>=0 else ''}{d*100:.0f}%"

_safe = lambda fn: (lambda v: '&mdash;' if isn(v) else fn(v))
pct2 = _safe(lambda v: f"{v:.2f}%")
pct3 = _safe(lambda v: f"{v:.3f}%")
num0 = _safe(lambda v: f"{v:,.0f}")
num1 = _safe(lambda v: f"{v:,.1f}")
num2 = _safe(lambda v: f"{v:,.2f}")
rs0 = _safe(lambda v: f"{v:,.0f}")

# ---------- generic row: MTD this | MTD last | WTD this (uncoloured) | WTD last | 6mo avg ----------
def row(name, key, fmt, mtd_cell=None, wtd_cell=None):
    m = M[key]
    mt = mtd_cell if mtd_cell else f"<td>{fmt(m['mt'])}</td>"
    wt = wtd_cell if wtd_cell else f"<td>{fmt(m['wt'])}</td>"
    fm = fmt
    return (f'<tr><td class="mname">{name}</td>{wt}<td>{fm(m["wl"])}</td><td>{fm(m["lw"])}</td>'
            f'{mt}<td>{fm(m["ml"])}</td><td>{fm(m["fb3"])}</td><td>{fm(m["fb6"])}</td></tr>')

def vol_row(name, key):
    """Volume rows keep their MTD-this colour (MTD vs MTD-last; any drop = Amber, user 12 Oct) - that is an MTD rule, not WTD."""
    m = M[key]; d = rel(m['mt'], m['ml'])
    cell = (f'<td class="hcell {heat_class_vol(d)}" title="MTD last: {num0(m["ml"])}">'
            f'<div class="hval">{num0(m["mt"])}</div><div class="hdelta">{fmt_delta(d)}</div></td>')
    return row(name, key, num0, cell)

# Column headers carry their own date range on a second line (user 12 Oct): e.g. "This week (WTD) / 5-8 Oct", "6m avg / Apr-Sep"
import datetime as _dtc
def _rng(s, e):
    s, e = _dtc.date.fromisoformat(str(s)), _dtc.date.fromisoformat(str(e))
    if s == e: return f"{s.day} {s:%b}"
    if (s.year, s.month) == (e.year, e.month): return f"{s.day}&ndash;{e.day} {e:%b}"
    return f"{s.day} {s:%b}&ndash;{e.day} {e:%b}"
def _mrng(s, e):
    s, e = _dtc.date.fromisoformat(str(s)), _dtc.date.fromisoformat(str(e))
    return f"{s:%b}&ndash;{e:%b}" + (f" {e:%Y}" if s.year != e.year else '')
COL_DATES = {
    'This week (WTD)': _rng(P['WT_S'], P['R']), 'Last week (WTD)': _rng(P['WL_S'], P['WL_E']),
    'Last week (full)': _rng(P['LW_S'], P['LW_E']), 'This month (MTD)': _rng(P['MTD_S'], P['R']),
    'Last month (same days)': _rng(P['ML_S'], P['ML_E']), '3m avg': _mrng(P['F3_S'], P['F1_E']), '6m avg': _mrng(P['F6_S'], P['F1_E'])}
COLS = ''.join(f'<th>{k}<span class="thdate">{v}</span></th>' for k, v in COL_DATES.items()) + '</tr>'

HDR5 = '<tr><th>Metric</th>' + COLS

# ---------- Key Metrics (MTD-this vs MTD-last; colouring rule as the page already runs it) ----------
def key_row(name, mt, ml, fmt, hb, vol=False):
    d = rel(mt, ml)
    if hb is None or isn(d):
        cls, rc = 'hna', 'rowna'
    else:
        # user 12 Oct: ANY drop is Amber, volume rows included (the old -10% tolerance for Leads/Orders is gone)
        good = (d >= 0) if hb else (d <= 0)
        cls, rc = ('h4','rowgreen') if good else ('h2','rowamber')
    if vol:
        dt = '' if isn(d) else f'{"+" if d>=0 else ""}{d*100:.2f}%'
        cell = f'<td class="hcell {cls}"><div class="hval">{fmt(mt)}</div><div class="hdelta">{dt}</div></td>'
    else:
        cell = f'<td class="hcell {cls}">{fmt(mt)}</td>'
    return (rc, cell)

def key_full(name, key, fmt, hb, vol=False, mkey=None, alt=None):
    """Key Metrics row: This week | Last week (full Mon-Sun) | This month | Last month | 3m avg | 6m avg.
    Colour stays on This month vs Last month. mkey overrides MTD this/last source (Key TPO); alt = source for the rest."""
    m = M[mkey or key]; a = M[alt or key]
    rc, cell = key_row(name, m['mt'], m['ml'], fmt, hb, vol)
    fm = fmt
    return (f'<tr class="{rc}"><td class="mname">{name}</td><td>{fm(a["wt"])}</td><td>{fm(a["wl"])}</td><td>{fm(a["lw"])}</td>'
            f'{cell}<td>{fm(m["ml"])}</td><td>{fm(a["fb3"])}</td><td>{fm(a["fb6"])}</td></tr>')

KEY = ['<tr><th>Metric</th>' + COLS,
    key_full('No. of orders booked', 'o_all', num0, True, vol=True),
    key_full('Conversion % &mdash; Overall' + OVR, 'c_all', pct2, True),
    key_full('Leads &mdash; Overall' + OVR, 'l_all', num0, True, vol=True),
    key_full('AOV (&#8377;)', 'aov', rs0, True),
    key_full('% orders with surge', 'surge', pct2, None),
    key_full('Cancellation %', 'k_cancel', pct2, False),
    key_full('Deallocation %', 'k_dealloc', pct2, False),
    key_full('On Time Arrival %', 'ota', pct2, True),
    key_full('TPO &mdash; Overall', 'tpo', num2, False, mkey='k_tpo', alt='tpo'),
    key_full('Overall NPS', 'nps.Overall', num2, True),
    key_full('Overall Detractors %', 'detr.Overall', pct2, False),
    key_full('Social Media Escalation %', 'sm', pct3, None),
]

LEADS = [HDR5,
    vol_row('Leads &mdash; Overall' + OVR,'l_all'), vol_row('Leads &mdash; App' + OVR,'l_app'),
    vol_row('Leads &mdash; Mobile Website' + OVR,'l_mob'), vol_row('Leads &mdash; Desktop Website' + OVR,'l_desk'),
    vol_row('Leads &mdash; Others' + OVR,'l_oth'),
    row('Conversion &mdash; Overall %' + OVR,'c_all',pct2), row('Conversion &mdash; App %' + OVR,'c_app',pct2),
    row('Conversion &mdash; Desktop Web %' + OVR,'c_desk',pct2), row('Conversion &mdash; Mobile Web %' + OVR,'c_mob',pct2),
    vol_row('Booked Orders','o_all'),
    row('% Orders &mdash; App','s_app',pct2), row('% Orders &mdash; Website','s_web',pct2), row('% Orders &mdash; LMS','s_lms',pct2)]

PRICING = [HDR5, row('AOV (&#8377;)','aov',rs0), row('% orders with surge','surge',pct2),
    row('% orders +ve surge','pos',pct2), row('% orders -ve surge','neg',pct2),
    row('% orders fare increased','fi_nn',pct2), row('Median fare increase (&#8377;)','med_nn',num2)]

ALLOC = [HDR5] + [row(n,k,f) for n,k,f in [
    ('Allocation % &mdash; SPOT','alloc_spot',pct2),('Allocation % &mdash; Scheduled','alloc_sched',pct2),
    ('Deallocation %','dealloc',pct2),('Deallocation % &mdash; SPOT','dealloc_spot',pct2),('Deallocation % &mdash; Scheduled','dealloc_sched',pct2),
    ('Completion %','comp',pct2),('Completion % &mdash; SPOT','comp_spot',pct2),('Completion % &mdash; Scheduled','comp_sched',pct2),
    ('Dry Run P75 (km)','dry_p75',num2),('CAC &mdash; SPOT','cac_spot',pct2),('PAC &mdash; SPOT','pac_spot',pct2),('PoAC &mdash; SPOT','poac_spot',pct2),
    ('CAC &mdash; Scheduled','cac_sched',pct2),('PAC &mdash; Scheduled','pac_sched',pct2),('PoAC &mdash; Scheduled','poac_sched',pct2),
    ('Allocation Time P80 (min)','alloc_p80',num2),('% no vendor before slot','no_vendor',pct2),('Reschedule %','resched',pct2),
    ('% orders &gt;2 deallocations','dealloc2',pct2),('% supervisor changed','sup_chg',pct2),
    ('Pickup Deviation P80 (km)','pick_p80',num2),('Drop Deviation P80 (km)','drop_p80',num2)]]

TRIP = [HDR5] + [row(n,k,num1) for n,k in [
    ('Vendor Accepted &rarr; Supervisor Assigned P80','s1'),('Supervisor Assigned &rarr; Trip Started P80','s2'),
    ('Trip Started &rarr; Shifting Started P80','s3'),('Shifting Started &rarr; Pickup Complete P80','s4'),
    ('Pickup Complete &rarr; Shifting Complete P80','s5'),('Full Trip Duration P80 (Shifting Started &rarr; Order Completed)','s6')]]

EDITS = [HDR5] + [row(n,k,pct2) for n,k in [
    ('% orders edited','edited'),('% support-edited orders','sup_edit'),('% edits after shifting started','eas'),
    ('% orders where location modified','loc_edit'),('Overall Add-on Adoption %','addon')]]

BHDR = '<tr><th>Bucket</th>' + COLS
def bucket(m, fmt):
    return [BHDR] + [row(b, f'{m}.{b}', fmt) for b in ['GoldPlus','Gold','Silver','Bronze','New']]
CX_COMP, CX_NPS, CX_DETR = bucket('comp',pct2), bucket('nps',num2), bucket('detr',pct2)

FT = [HDR5, row('On Time Arrival %','ota',pct2), row('Delay &gt; 60 minutes %','delay60',pct2)]
ESC = [HDR5, row('Social Media Escalation %','sm',pct3), row('Damage %','dmg',pct3)]

# ---------- City x BHK ----------
orders_cur = {k: v[0] for k, v in G_ORD.items()}
def cell(cur, base, hb, fmt, c, b, vol=False, base_label='6m avg'):
    if cur is None or base in (None, 0):
        return '<td class="hcell hna">&mdash;</td>'
    if hb is None:
        return f'<td class="hcell hna" title="6mo avg: n/a"><div class="hval">{fmt(cur)}</div></td>'
    d = rel(cur, base)
    cls = heat_class_vol(d) if vol else heat_class(d, hb)
    thin = orders_cur.get((c,b),0) < THIN
    return (f'<td class="hcell {cls}{" thin" if thin else ""}" title="{base_label}: {fmt(base)}{" &middot; thin cell" if thin else ""}">'
            f'<div class="hval">{fmt(cur)}</div><div class="hdelta">{fmt_delta(d)}</div></td>')

def grid(getter, hb, fmt, vol=False, base_label='6m avg'):
    rows = ['<tr><th>City</th><th>Nano/Micro</th><th>1BHK</th><th>2BHK</th><th>3BHK</th><th>4+BHK</th></tr>']
    counts = {'bad':0,'near':0,'good':0}
    for c in CITIES:
        cells = []
        for b in BHKS:
            cur, base = getter(c, b)
            cells.append(cell(cur, base, hb, fmt, c, b, vol, base_label))
            if hb is not None and cur is not None and base:
                d = rel(cur, base)
                k = heat_class_vol(d) if vol else heat_class(d, hb)
                counts['bad' if k in ('h1','h2') else 'good' if k in ('h4','h5') else 'near'] += 1
        rows.append(f'<tr><td class="mname">{c}</td>' + ''.join(cells) + '</tr>')
    summ = ("no single direction &mdash; not banded" if hb is None else
            f"{counts['bad']} worse than baseline, {counts['good']} at or better (of {counts['bad']+counts['good']} cells)")
    return rows, summ, counts

def g2(G, i=0, j=1):
    return lambda c, b: (G[(c,b)][i], G[(c,b)][j]) if (c,b) in G else (None, None)

ord_get = lambda c, b: (G_ORD[(c,b)][0], G_ORD[(c,b)][1]) if (c,b) in G_ORD else (None,None)   # base = mean of 6 prior months' same-days counts
GRIDS = {
 'orders': grid(ord_get, True, num0, vol=True, base_label='6m avg (same days)'),
 'aov':    grid(g2(G_AOV), True, lambda v: f"&#8377;{v:,.0f}"),
 'surge':  grid(g2(G_SUR), None, lambda v: f"{v:.1f}%"),
 'comp':   grid(g2(G_CD,0,1), True, lambda v: f"{v:.1f}%"),
 'dealloc':grid(g2(G_CD,2,3), False, lambda v: f"{v:.1f}%"),
 'ota':    grid(g2(G_OTA), True, lambda v: f"{v:.1f}%"),
 'tpo':    grid(g2(G_TPO), False, lambda v: f"{v:.2f}"),
 'nps':    grid(g2(G_NPS,0,1), True, lambda v: f"{v:.0f}"),
 'detr':   grid(g2(G_NPS,2,3), False, lambda v: f"{v:.1f}%"),
}

CITY_ORDER = ['Delhi NCR','Bangalore','Mumbai','Hyderabad','Pune','Chennai','Tier 2 (combined)','Ahmedabad','Kolkata','(No city yet)']
clo = {c:(l,o) for c,l,o in CITY_LO}
CITYLEADS = ['<tr><th>City</th><th>Leads</th><th>Orders</th><th>Conversion %' + OVR + '</th></tr>']
for c in sorted([x for x in clo if x!='(No city yet)'], key=lambda x: -clo[x][0]):
    l, o = clo[c]
    conv = f"{100*o/l:.2f}%" if o else '&mdash;'
    CITYLEADS.append(f'<tr><td class="mname">{c}</td><td>{l:,}</td><td>{o:,}</td><td>{conv}</td></tr>')
LEADS_SUM = sum(v[0] for v in clo.values()); ORD_SUM = sum(v[1] for v in clo.values())

json.dump({'leads_sum':LEADS_SUM,'ord_sum':ORD_SUM,
           'grid_summ':{k:v[1] for k,v in GRIDS.items()}}, open('build_meta.json','w'), indent=1)

# ================= RAG on MTD-this vs 6mo avg (user instruction 2026-09-29, single-day WTD refresh) =================
def rrow(name, key, fmt, hb, dfmt=None):
    """hb: True/False = higher/lower better -> heat_class on MTD/WTD-this vs 6m avg (any worsening = Amber, darker beyond 20%);
       'na' = no direction (grey hna); 'delta' = no colour, neutral h3 tint + plain delta (Trip Duration, fare-increase)."""
    m = M[key]; mt, b6 = (m['mt'] if BASIS == 'MTD' else m['wt']), m['b6']
    if hb == 'na':
        cell = f'<td class="hcell hna">{fmt(mt)}</td>'
    elif hb == 'delta':
        dtxt = dfmt(mt, b6) if dfmt else fmt_delta(rel(mt, b6))
        cell = (f'<td class="hcell h3" title="Colour basis &mdash; 6m avg (same days 1&ndash;N): {fmt(b6)}"><div class="hval">{fmt(mt)}</div>'
                f'<div class="hdelta">{dtxt}</div></td>')
    else:
        cls = heat_class(rel(mt, b6), hb)
        cell = f'<td class="hcell {cls}" title="Colour basis &mdash; 6m avg (same days 1&ndash;N): {fmt(b6)}">{fmt(mt)}</td>'
    return row(name, key, fmt, cell) if BASIS == 'MTD' else row(name, key, fmt, None, cell)

pp = lambda a, b: f"{'+' if a-b>=0 else ''}{a-b:.2f}pp"
rsd = lambda a, b: f"{'+' if a-b>=0 else '-'}&#8377;{abs(a-b):.2f}"

LEADS = [HDR5,
    vol_row('Leads &mdash; Overall' + OVR,'l_all'), vol_row('Leads &mdash; App' + OVR,'l_app'),
    vol_row('Leads &mdash; Mobile Website' + OVR,'l_mob'), vol_row('Leads &mdash; Desktop Website' + OVR,'l_desk'),
    vol_row('Leads &mdash; Others' + OVR,'l_oth'),
    rrow('Conversion &mdash; Overall %' + OVR,'c_all',pct2,True), rrow('Conversion &mdash; App %' + OVR,'c_app',pct2,True),
    rrow('Conversion &mdash; Desktop Web %' + OVR,'c_desk',pct2,True), rrow('Conversion &mdash; Mobile Web %' + OVR,'c_mob',pct2,True),
    vol_row('Booked Orders','o_all'),
    rrow('% Orders &mdash; App','s_app',pct2,'na'), rrow('% Orders &mdash; Website','s_web',pct2,'na'), rrow('% Orders &mdash; LMS','s_lms',pct2,'na')]

PRICING = [HDR5, rrow('AOV (&#8377;)','aov',rs0,True), rrow('% orders with surge','surge',pct2,'na'),
    rrow('% orders +ve surge','pos',pct2,True), rrow('% orders -ve surge','neg',pct2,False),
    rrow('% orders fare increased','fi_nn',pct2,'delta',pp), rrow('Median fare increase (&#8377;)','med_nn',num2,'delta',rsd)]

ALLOC = [HDR5] + [rrow(n,k,f,hb) for n,k,f,hb in [
    ('Allocation % &mdash; Overall','alloc_all',pct2,True),
    ('Allocation % &mdash; SPOT','alloc_spot',pct2,True),('Allocation % &mdash; Scheduled','alloc_sched',pct2,True),
    ('Deallocation %','dealloc',pct2,False),('Deallocation % &mdash; SPOT','dealloc_spot',pct2,False),('Deallocation % &mdash; Scheduled','dealloc_sched',pct2,False),
    ('Completion %','comp',pct2,True),('Completion % &mdash; SPOT','comp_spot',pct2,True),('Completion % &mdash; Scheduled','comp_sched',pct2,True),
    ('Dry Run P75 (km)','dry_p75',num2,False),('CAC &mdash; SPOT','cac_spot',pct2,False),('PAC &mdash; SPOT','pac_spot',pct2,False),('PoAC &mdash; SPOT','poac_spot',pct2,False),
    ('CAC &mdash; Scheduled','cac_sched',pct2,False),('PAC &mdash; Scheduled','pac_sched',pct2,False),('PoAC &mdash; Scheduled','poac_sched',pct2,False),
    ('Allocation Time P80 (min)','alloc_p80',num2,False),('% no vendor before slot','no_vendor',pct2,False),('Reschedule %','resched',pct2,False),
    ('% orders &gt;2 deallocations','dealloc2',pct2,False),('% supervisor changed','sup_chg',pct2,False),
    ('Pickup Deviation P80 (km)','pick_p80',num2,False),('Drop Deviation P80 (km)','drop_p80',num2,False)]]

TRIP = [HDR5] + [rrow(n,k,num1,'delta', lambda a,b: '' if isn(rel(a,b)) else f"{rel(a,b)*100:+.1f}%") for n,k in [
    ('Vendor Accepted &rarr; Supervisor Assigned P80','s1'),('Supervisor Assigned &rarr; Trip Started P80','s2'),
    ('Trip Started &rarr; Shifting Started P80','s3'),('Shifting Started &rarr; Pickup Complete P80','s4'),
    ('Pickup Complete &rarr; Shifting Complete P80','s5'),('Full Trip Duration P80 (Shifting Started &rarr; Order Completed)','s6')]]

EDITS = [HDR5] + [rrow(n,k,pct2,hb) for n,k,hb in [
    ('% orders edited','edited',False),('% support-edited orders','sup_edit',False),('% edits after shifting started','eas',False),
    ('% orders where location modified','loc_edit',False),('Overall Add-on Adoption %','addon',True)]]

def bucket(m, fmt, hb):
    return [BHDR] + [rrow(b, f'{m}.{b}', fmt, hb) for b in ['GoldPlus','Gold','Silver','Bronze','New']]
CX_COMP, CX_NPS, CX_DETR = bucket('comp',pct2,True), bucket('nps',num2,True), bucket('detr',pct2,False)

FT = [HDR5, rrow('On Time Arrival %','ota',pct2,True), rrow('Delay &gt; 60 minutes %','delay60',pct2,False)]
ESC = [HDR5, rrow('Social Media Escalation %','sm',pct3,'na'), rrow('Damage %','dmg',pct3,False)]

def cx_pill(key, hb):
    m = M[key]; k = heat_class(rel(m['mt'], m['b6']), hb)
    return {'h1':'amber','h2':'amber','h3':'green','h4':'green','h5':'green'}[k], k
