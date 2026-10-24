import re
exec(open('build.py').read())
import datetime as _dt
_d = lambda s: _dt.date.fromisoformat(s)
R = P['R']; RD = _d(R)
lab = lambda s: f"{_d(s).strftime('%a')} {_d(s).day} {_d(s).strftime('%b')}"
WT_LAB = lab(P['WT_S']) if P['SINGLE_DAY'] else f"{lab(P['WT_S'])} &ndash; {lab(R)}"
WL_LAB = lab(P['WL_S']) if P['SINGLE_DAY'] else f"{lab(P['WL_S'])} &ndash; {lab(P['WL_E'])}"
BASE_LAB = f"{_d(P['B_S']).day} {_d(P['B_S']).strftime('%b')} &ndash; {_d(P['B_E']).day} {_d(P['B_E']).strftime('%b')}"
COL = 'MTD-this' if BASIS == 'MTD' else 'WTD-this'
BASIS_TXT = f'{COL} vs 6mo avg' + (' this refresh (single-day WTD)' if BASIS == 'MTD' else '')

h = open('base.html').read()

# ---------- volume colour rule (user 12 Oct): any drop = Amber, the +/-10% band is gone everywhere ----------
for _a, _b in [
    ("var BASIS_VOLUME = 'MTD vs MTD-last, \\u00b110%';", "var BASIS_VOLUME = 'MTD vs MTD-last, any drop = Amber';"),
    ("' tolerance, Amber only on a worse-direction move beyond 10% &middot; <b>% and experience metrics</b>: '",
     "' (Green at or above last month, Amber on any drop) &middot; <b>% and experience metrics</b>: '"),
    ("Orders booked uses the same &plusmn;10% tolerance as its main-table rule;", "Orders booked: any drop vs the cell baseline is Amber;"),
    ("{ metric: 'Booked Orders (both variants)',", "{ metric: 'Booked Orders',"),
]:
    assert h.count(_a) == 1, _a
    h = h.replace(_a, _b)

# ---------- heat legend (user 12 Oct): no neutral band ----------
for _a, _b in [
    ('<span class="heatlegend-item"><span class="heatlegend-swatch h2"></span>-20 to -5%</span>', '<span class="heatlegend-item"><span class="heatlegend-swatch h2"></span>worse, up to -20%</span>'),
    ('<span class="heatlegend-item"><span class="heatlegend-swatch h3"></span>&plusmn;5%</span>\n', ''),
    ('<span class="heatlegend-item"><span class="heatlegend-swatch h4"></span>+5 to +20%</span>', '<span class="heatlegend-item"><span class="heatlegend-swatch h4"></span>same or better, up to +20%</span>'),
]:
    assert h.count(_a) == 1, _a
    h = h.replace(_a, _b)

# ---------- 1. Swap table bodies by position, asserting identity first ----------
tables = list(re.finditer(r'(<table[^>]*>)(.*?)(</table>)', h, re.S))
assert len(tables) == 22, len(tables)
plan = [
 (0,  'No. of orders booked', KEY),
 (1,  'Leads &mdash; Overall', LEADS),
 (2,  'AOV (&#8377;)', PRICING),
 (3,  'Allocation % &mdash; SPOT', ALLOC),
 (4,  'Vendor Accepted', TRIP),
 (5,  '% orders edited', EDITS),
 (6,  'GoldPlus', CX_COMP),
 (7,  'GoldPlus', CX_NPS),
 (8,  'GoldPlus', CX_DETR),
 (9,  'On Time Arrival %', FT),
 (10, 'Social Media Escalation %', ESC),
 (11, 'Delhi NCR', CITYLEADS),
 (12, None, GRIDS['orders'][0]), (13, None, GRIDS['aov'][0]), (14, None, GRIDS['surge'][0]),
 (15, None, GRIDS['comp'][0]), (16, None, GRIDS['dealloc'][0]), (17, None, GRIDS['ota'][0]),
 (18, None, GRIDS['tpo'][0]), (19, None, GRIDS['nps'][0]), (20, None, GRIDS['detr'][0]),
]
# identity checks for the City x BHK grids: the <summary>/header text right before each table
grid_headers = {12:'No. of orders booked',13:'AOV (&#8377;)',14:'% orders with surge',15:'Completion %',
                16:'Deallocation %',17:'On Time Arrival %',18:'TPO &mdash; Overall',19:'Overall NPS',20:'Overall Detractors %'}
out, last = [], 0
for idx, marker, rows in plan:
    m = tables[idx]
    body = m.group(2)
    if marker:
        first = re.findall(r'<td class="mname">(.*?)</td>', body)[0]
        assert first.startswith(marker), (idx, first)
    else:
        pre = h[max(0, m.start()-900):m.start()]
        heads = re.findall(r'class="exp-metric-header"[^>]*>([^<]*)', pre)
        assert heads and heads[-1].strip() == grid_headers[idx], (idx, heads[-1:] )
    indent = '\n        '
    out.append(h[last:m.start()]); out.append(m.group(1) + indent + indent.join(rows) + '\n      ' + m.group(3))
    last = m.end()
out.append(h[last:])
h = ''.join(out)

# ---------- 2. Text edits (each must match exactly once) ----------
def rep(old, new, count=1):
    global h
    n = h.count(old)
    assert n == count, (n, old[:80])
    h = h.replace(old, new)

def rep_re(pat, new):
    global h
    ms = re.findall(pat, h, re.S)
    assert len(ms) == 1, (len(ms), pat[:80])
    h = re.sub(pat, new, h, flags=re.S)

rep('Report date: 2026-09-27 &middot; Intra-city', f'Report date: {R} &middot; Intra-city')

# single-day WTD banner, right under the orientation box
if P['SINGLE_DAY']:
    BANNER = ('<p class="rag-note" style="margin:0 0 18px;"><b>Single-day WTD this refresh.</b> Report date ' + R + ' is a Monday, so '
          f'<b>WTD-this = {WT_LAB} only</b> and <b>WTD-last = {WL_LAB} only</b> (same day of the week, like-for-like). '
          'Because one day is too thin to judge, <b>WTD-this is not colour-coded</b> this refresh. Instead, in every table below Key Metrics the colour sits on '
          '<b>MTD-this vs the 6mo avg</b> (same directions as the normal WTD rule; any worsening = Amber). ')
else:
    BANNER = ('<p class="rag-note" style="margin:0 0 18px;"><b>WTD window:</b> '
          f'<b>This week (WTD) = {WT_LAB}</b> ({P["WTD_DAYS"]} day{"s" if P["WTD_DAYS"]>1 else ""}); <b>Last week (WTD) = {WL_LAB}</b> (same weekdays); '
          f'<b>Last week (full) = {lab(P["LW_S"])} &ndash; {lab(P["LW_E"])}</b>. '
          'Per the rules, tables below Key Metrics colour <b>WTD-this vs the 6mo avg</b> (any worsening = Amber, darker beyond 20%). '
          + ('<b>Early-week caution:</b> with only a few days in the window, WTD rates are noisier than a full week. ' if P["WTD_DAYS"] < 4 else ''))
_M = lambda k: _d(P[k]).strftime('%b')
BANNER += (f'<b>3m avg / 6m avg</b> = simple average of the previous 3 / 6 months, each taken over the <b>same days as this month</b> '
          f'(day 1&ndash;{RD.day}): 3m = {_M("M3_S")}&ndash;{_M("M1_S")}, 6m = {_M("M6_S")}&ndash;{_M("M1_S")}. For counts (Leads, Orders) that is a '
          'month-to-date count, directly comparable with This month; for % and score metrics it is the average of the monthly rates. '
          'Key Metrics (MTD vs MTD-last), Leads/Orders volume rows (MTD vs MTD-last, any drop = Amber) and the City &times; BHK grids keep their own rules. Hover a coloured cell for its 6mo avg.</p>\n\n')
rep('  </dl>\n\n  <div class="key-metrics-section">', '  </dl>\n\n  ' + BANNER + '  <div class="key-metrics-section">')

# Key Metrics identity note
o, l, c = M['o_all'], M['l_all'], M['c_all']
rep_re(r'<p class="rag-note" style="margin-top:10px;"><b>Orders booked = Leads &times; Conversion %</b>.*?</p>',
       '<p class="rag-note" style="margin-top:10px;"><b>Orders booked = Leads &times; Conversion %</b> &mdash; these three rows aren\'t independent. '
       f'MTD-over-MTD: Leads {100*rel(l["mt"],l["ml"]):+.2f}%, Conversion {c["mt"]-c["ml"]:+.2f}pp, Orders {100*rel(o["mt"],o["ml"]):+.2f}% &mdash; '
       + ('Leads and Conversion moved the same way, so Orders reflects both together.' if (l["mt"]-l["ml"])*(c["mt"]-c["ml"]) >= 0
          else 'Leads and Conversion moved in opposite directions, partly offsetting each other in Orders.') + '</p>')

# Leads & Orders note
rep_re(r'<p class="rag-note">WTD-this now spans a genuine full 7-day week.*?</p>',
       f'<p class="rag-note">Volume rows are coloured MTD-this vs MTD-last (any drop = Amber). Conversion rows are coloured {BASIS_TXT}. % Orders by channel has no direction (grey). WTD-this = {WT_LAB} &mdash; see the note at the top.</p>')
rep('<p class="status-note">Status: fully validated, no flags. Cross-checked (% Orders by channel sums to 99.9-100%, rounding).</p>',
    f'<p class="status-note">Status: refreshed for report_date {R}. Cross-checked: % Orders by channel sums to {M["s_app"]["mt"]+M["s_web"]["mt"]+M["s_lms"]["mt"]:.2f}% (rounding).</p>')

# Pricing note
rep_re(r'<p class="rag-note">\+ve surge is higher-is-better.*?</p>',
       '<p class="rag-note">+ve surge is higher-is-better (contributes to revenue), -ve surge is lower-is-better (colour on {BASIS_TXT}). '
       '-ve surge\'s dark-red cell carries a caveat: <span id="noteNegSurge"></span> Fare-increase metrics carry no direction/color, per instruction &mdash; the tinted cell just shows the delta vs 6mo avg. '
       '<b>% orders fare increased and Median fare increase now exclude Nano</b>, per the Pricing rule; the previous refresh included Nano by mistake, '
       'which is why MTD-this reads about 2pp higher than the 16.76% shown last time.</p>')
rep('<p class="status-note">Status: fully validated (see note above on -ve surge).</p>',
    f'<p class="status-note">Status: refreshed for report_date {R} (see notes above on -ve surge and the fare-increase Nano fix).</p>')
rep("' \\u2014 the color reflects a stale baseline more than real performance.'",
    "' \\u2014 read any comparison against it with that in mind.'")

# Allocation note
rep_re(r'<p class="status-note">Status: refreshed for report_date 2026-09-27 \(Sunday\), giving a full 7-day WTD window\..*?</p>',
       f'<p class="status-note">Status: refreshed for report_date {R}. MTD-this is close to the 6mo avg on most rows. '
       f'Completion % is {M["comp"]["mt"]:.2f}% MTD vs {M["comp"]["ml"]:.2f}% MTD-last and {M["comp"]["b6"]:.2f}% 6mo avg; '
       f'Deallocation % is {M["dealloc"]["mt"]:.2f}% vs {M["dealloc"]["b6"]:.2f}% 6mo avg. Colour is {BASIS_TXT}' + ('; the one-day WTD-this values are indicative only.</p>' if P['SINGLE_DAY'] else '.</p>'))

# Trip duration note: remove the claim about WTD-this tinted cells
rep('Cells here are neutral-tinted (no direction/color, per instruction) &mdash; they just mark WTD-this as the reference column, showing % vs 6mo avg on hover.',
    'Cells here are neutral-tinted (no direction/color, per instruction) &mdash; the MTD-this cell shows its % delta vs 6mo avg.')

# Edits note
rep_re(r'<p class="status-note">Status: refreshed\. Add-on Adoption %.*?</p>',
       f'<p class="status-note">Status: refreshed for report_date {R}. Add-on Adoption % (~{M["addon"]["mt"]:.0f}%) now has a like-for-like 6mo avg '
       f'({M["addon"]["b6"]:.2f}%), built with the same completed/non-Nano filter as the other columns.</p>')

# Customer Experience summary lines (drop the WTD-based RAG pills)
def cx_sum(key, fmt):
    m = M[key]
    return (f'This week {fmt(m["wt"])} &middot; Last week (WTD) {fmt(m["wl"])} &middot; Last week (full) {fmt(m["lw"])} &middot; This month {fmt(m["mt"])} &middot; '
            f'Last month {fmt(m["ml"])} &middot; 3m avg {fmt(m["fb3"])} &middot; 6m avg {fmt(m["fb6"])} &middot; {pill(key)}')
HB = {'comp.Overall':True,'nps.Overall':True,'detr.Overall':False}
def pill(key):
    m = M[key]; hb = HB[key]; v = m['mt'] if BASIS == 'MTD' else m['wt']
    if isn(v) or isn(m['b6']): return '<span class="rag-pill" style="background:var(--panel);color:var(--ink-faint);">N/A</span>'
    good = (v >= m['b6']) if hb else (v <= m['b6'])
    return f'<span class="rag-pill {"green" if good else "amber"}">{"GREEN" if good else "AMBER"}</span> <span style="color:var(--ink-faint);">({COL.split("-")[0]} vs 6mo)</span>'
rep_re(r'<div class="exp-metric-summary">MTD this 86\.17%.*?</div>', f'<div class="exp-metric-summary">{cx_sum("comp.Overall", pct2)}</div>')
rep_re(r'<div class="exp-metric-summary">MTD this 74\.31 .*?</div>', f'<div class="exp-metric-summary">{cx_sum("nps.Overall", num2)}</div>')
rep_re(r'<div class="exp-metric-summary">MTD this 3\.73%.*?</div>', f'<div class="exp-metric-summary">{cx_sum("detr.Overall", pct2)}</div>')
rep('<p class="status-note">Status: fully refreshed for report_date 2026-09-27, including vendor-bucket breakdowns. No small-sample outliers this pass.</p>',
    f'<p class="status-note">Status: refreshed for report_date {R}, including vendor-bucket breakdowns. RAG pill and bucket colours are {BASIS_TXT} (Amber = worse than the 6mo avg). '
    'Bucket WTD-this values are one day of data and swing widely on small counts &mdash; don\'t read them as a trend.</p>')

# Fulfillment note
rep_re(r'<p class="status-note">Status: refreshed for report_date 2026-09-27\. Both metrics genuinely improved.*?</p>',
       f'<p class="status-note">Status: refreshed for report_date {R}. MTD-this OTA {M["ota"]["mt"]:.2f}% vs {M["ota"]["b6"]:.2f}% 6mo avg; '
       f'Delay &gt;60 min {M["delay60"]["mt"]:.2f}% vs {M["delay60"]["b6"]:.2f}% 6mo avg &mdash; both essentially at baseline.</p>')

# Escalations note
rep_re(r'Damage % now has 22 WTD tickets \(vs 12 last week\).*?hence the Amber\.',
       f'Damage % has {int(M["dmg_n"]["mt"])} tickets MTD (vs {int(M["dmg_n"]["ml"])} MTD-last) and {int(M["dmg_n"]["wt"])} in WTD-this ({WT_LAB}) &mdash; '
       f'WTD counts are small, so read the colour ({BASIS_TXT}) with care.')
rep('<p class="status-note">Status: refreshed for report_date 2026-09-27. Still newly added, not yet cross-validated against an independent source the way earlier metrics were.</p>',
    f'<p class="status-note">Status: refreshed for report_date {R}. Still newly added, not yet cross-validated against an independent source the way earlier metrics were. '
    'Damage % counts only damage tickets on intra-city, completed, non-Nano orders (same population as its denominator).</p>')

# City x BHK
rep('Single comparison basis for every row: <b>MTD-this vs. MTD-last</b> &mdash; consistent across all 11 metrics, rather than mixing MTD, WTD, and 6-month-average bases in one table.',
    'Colour for every row: <b>This month (MTD) vs Last month (same days)</b>. The other columns are context. '
    'Social Media Escalation % carries no colour (counts too small), as elsewhere.')
rep('MTD-this (Sept 1&ndash;27)', f'MTD-this ({RD.strftime("%b")} 1&ndash;{RD.day})')
o_tot_base = sum((v[1] or 0) for v in G_ORD.values())   # sum of per-cell 6m averages (same days)
o_dev = rel(M['o_all']['mt'], o_tot_base)*100
oc, ac = GRIDS['orders'][2], GRIDS['aov'][2]
rep_re(r'<p class="rag-note" style="margin-bottom:18px;"><b>Two things worth reading before the grids below:</b>.*?</p>',
       '<p class="rag-note" style="margin-bottom:18px;"><b>Two things worth reading before the grids below:</b> '
       f'(1) <b>Orders booked: {oc["bad"]} of 45 cells below baseline, {oc["good"]} above</b> &mdash; network-wide, MTD-this Orders is '
       f'<b>{o_dev:+.1f}% vs its 6-month trailing baseline</b> (MTD-equivalent), compared with '
       f'{100*(M["o_all"]["mt"]-M["o_all"]["ml"])/M["o_all"]["ml"]:+.2f}% vs last month in the Key Metrics table. '
       f'(2) <b>AOV: {ac["bad"]} of 45 cells below baseline, {ac["good"]} above.</b></p>')
rep_re(r'<p class="rag-note" style="margin-bottom:10px;">Several cells remain thin on data.*?</p>',
       f'<p class="rag-note" style="margin-bottom:10px;">Thin cells (&lt;30 orders MTD in that city &times; BHK combo &mdash; this refresh: {", ".join(b+" "+c for (c,b),v in sorted(orders_cur.items()) if v<THIN) or "none"}) '
       'are shown at reduced opacity with a trailing &middot; marker, so the eye naturally discounts them rather than reading them at equal weight.</p>')
rep('<p class="status-note" style="margin-bottom:24px;">Cross-checked: both columns sum exactly to the whole-network MTD-this totals (Leads 172,109; Orders 29,575) validated earlier in this file.</p>',
    f'<p class="status-note" style="margin-bottom:24px;">Cross-checked: Orders sum exactly to the whole-network MTD-this total ({ORD_SUM:,}). '
    f'Leads sum to {LEADS_SUM-clo["(No city yet)"][0]:,} of the network {LEADS_SUM:,} &mdash; the other {clo["(No city yet)"][0]:,} leads have no pickup city captured yet at lead stage, so they aren\'t in any city row.</p>')

# grid summaries
for hdr, key in [('No. of orders booked','orders'),('AOV (&#8377;)','aov'),('Completion %','comp'),('Deallocation %','dealloc'),
                 ('On Time Arrival %','ota'),('TPO &mdash; Overall','tpo'),('Overall NPS','nps')]:
    pat = (r'(<summary><span class="exp-metric-header" style="display:inline;margin:0;">' + re.escape(hdr) +
           r'</span> <span class="foldbtn-sub" style="margin-left:10px;">)[^<]*(</span></summary>)')
    ms = re.findall(pat, h)
    assert len(ms) == 1, (hdr, len(ms))
    h = re.sub(pat, lambda m: m.group(1) + GRIDS[key][1] + m.group(2), h)

rep('<p class="status-note" style="margin-bottom:24px;">TPO rises with BHK size in most cities &mdash; bigger, more complex moves generate more support tickets, a sensible pattern.</p>',
    '<p class="status-note" style="margin-bottom:24px;">TPO rises with BHK size in most cities &mdash; bigger, more complex moves generate more support tickets. '
    '<b>Caveat on the &ldquo;above baseline&rdquo; count:</b> September orders have had less time to collect tickets than the older orders in the 6-month pool, '
    'so current TPO reads better than baseline almost everywhere partly for that reason alone.</p>')
dnote = GRIDS['detr'][1]
rep('<div class="exp-metric-header">Overall Detractors %</div>\n    <div class="scroll"',
    f'<div class="exp-metric-header">Overall Detractors % <span class="foldbtn-sub" style="margin-left:10px;">{dnote}</span></div>\n    <div class="scroll"')
rep_re(r'<p class="rag-note"><b>The real finding in this whole section:</b>.*?</p>',
       '<p class="rag-note"><b>The real finding in this whole section:</b> NPS broadly declines and Detractors % broadly rises with BHK size in nearly every city '
       '&mdash; bigger, more complex moves are harder to execute well. The aggregate &ldquo;Overall NPS&rdquo; hides this entirely. '
       '<b>Read the 4+BHK column with real caution</b> &mdash; cells with very few rated orders swing wildly '
       f'(this refresh: {", ".join(f"{c} {b} NPS {G_NPS[(c,b)][0]:.0f} off {int(G_NPS[(c,b)][4])} rated" for (c,b) in sorted(G_NPS, key=lambda k: G_NPS[k][4])[:2])}), '
       'a small-sample artifact, not a real signal. This is exactly the thin-cell problem the reference wireframe\'s own-baseline banding was designed to solve '
       '&mdash; worth building properly before this section is read as more than directional.</p>')

rep("{ metric: 'Allocation % (SPOT/Scheduled)',", "{ metric: 'Allocation % (Overall/SPOT/Scheduled)',")
h = h.replace('62 metrics validated across 7 groups', '63 metrics validated across 7 groups')   # + Allocation % Overall (30 Sep)
rep('Nano policy: <b>Excluded</b>, except Allocation %, Deallocation %, % no vendor before slot, Reschedule %, % &gt;2 deallocations, and % supervisor changed &mdash; these have no Nano filter in their source table',
    'Nano policy: <b>Excluded</b> (all metrics; Nano and test users filtered out via <code>is_nano_order</code> / <code>is_test_user</code>)')
rep("Nano policy: <b>Not applicable</b> (these sources don't carry a Nano flag)",
    "Nano policy: <b>Excluded</b> (escalations and damage tickets counted only on non-Nano orders, matched by CRN)")
# RAG_RULES stale counts
rep("notes: 'MTD counts (41-47) support this; WTD counts (5-8) are still thin' }",
    "notes: 'MTD counts (~70-75/month) support this; WTD counts are thin (~20/week, 0-4/day)' }")


# ---------- Amplified heat colours (user request 2026-09-29: "Medium" intensity). Override block only; no CSS deleted ----------
AMP = """
  /* ---- Amplified heat scale (medium intensity) - overrides the muted h1-h5 tints above ---- */
  td.hcell.h1{background:#E3A9A0;color:#5E1D1D;font-weight:600;}
  td.hcell.h2{background:#F6D3A8;color:#7A430F;font-weight:600;}
  td.hcell.h3{background:#EEF0EE;color:#5B6360;}
  td.hcell.h4{background:#BFE0CF;color:#1F5A46;font-weight:600;}
  td.hcell.h5{background:#7FC4A4;color:#0F3D2E;font-weight:600;}
  .heatlegend-swatch.h1{background:#E3A9A0;border:1px solid #5E1D1D;}
  .heatlegend-swatch.h2{background:#F6D3A8;border:1px solid #7A430F;}
  .heatlegend-swatch.h3{background:#EEF0EE;border:1px solid var(--line);}
  .heatlegend-swatch.h4{background:#BFE0CF;border:1px solid #1F5A46;}
  .heatlegend-swatch.h5{background:#7FC4A4;border:1px solid #0F3D2E;}
  table.metric-table tr:has(.hcell.h1) td.mname{border-left-color:#B5473A;}
  table.metric-table tr:has(.hcell.h5) td.mname{border-left-color:#1E7A55;}
"""
assert h.count('</style>') == 1
h = h.replace('</style>', AMP + '</style>')


# ================= Minimal-text layout + City weekly trends (user, 1 Oct) =================
import city_trend
_wk0 = _d(P['CW_S'])   # same 13-full-week window as the city-weekly queries (includes the current week on Sundays)
TREND_WEEKS = [(_wk0 + _dt.timedelta(weeks=i)).isoformat() for i in range(13)]
# 1) strip prose: orientation box, every note/status/scope paragraph, subtitle, footer (keep titles, headers, legends, rules register)
h = re.sub(r'\s*<dl class="orientbox">.*?</dl>', '', h, flags=re.S)
h = re.sub(r'\s*<p class="(?:rag-note|status-note)"[^>]*>.*?</p>', '', h, flags=re.S)
h = re.sub(r'\s*<div class="group-scope"(?! id=)[^>]*>.*?</div>', '', h, flags=re.S)
h = re.sub(r'\s*<div class="subtitle">.*?</div>', '', h, flags=re.S)
h = re.sub(r'\s*<footer>.*?</footer>', '', h, flags=re.S)
# JS hooks that lived inside removed notes -> null-safe
for _id in ['noteNegSurge', 'noteEditedTol', 'noteLocationTol']:
    h = h.replace(f"document.getElementById('{_id}').textContent =", f"if (document.getElementById('{_id}')) document.getElementById('{_id}').textContent =")
# 2) one-line definitions strip under the header
_mn = lambda d: __import__('datetime').date.fromisoformat(str(d)).strftime('%b')
_DEF = (f'<div class="defline">Intra-city &middot; This week = {WT_LAB} &middot; Last week (WTD) = {WL_LAB} &middot; '
        f'Last week (full) = {lab(P["LW_S"])} &ndash; {lab(P["LW_E"])} &middot; 3m avg = mean of full months {_mn(P["F3_S"])}&ndash;{_mn(P["F1_S"])}, 6m avg = {_mn(P["F6_S"])}&ndash;{_mn(P["F1_S"])} &middot; colours use the same days 1&ndash;{RD.day} of those 6 months &middot; '
        f'Colour: Key Metrics = this month vs last month; other tables = {COL} vs 6m avg</div>')
h = h.replace('</header>', '</header>\n  ' + _DEF, 1)
h = h.replace('at or better than MTD-last', 'this month at or better than last month').replace('worse than MTD-last', 'this month worse than last month')
# 3) city trend section right below Key Metrics (before the jump-to-section list)
assert h.count('<div class="toc">') == 1
h = h.replace('<div class="toc">', city_trend.section(heat_class, TREND_WEEKS) + '\n\n  <div class="toc">', 1)
h = h.replace('<li><a href="#leads-orders">', '<li><a href="#city-trend">City trends (weekly)</a></li>\n      <li><a href="#leads-orders">', 1)
h = h.replace('</style>', city_trend.CSS + '  .defline{font-size:12px;color:var(--ink-soft);margin:6px 0 18px;}\n  .legend{display:flex;flex-wrap:wrap;gap:6px 18px;font-size:12px;color:var(--ink-soft);margin-top:10px;}\n  .legend-swatch{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:6px;vertical-align:-1px;}\n</style>', 1)
h = h.replace('6mo avg', '6m avg').replace('6mo cell baseline', '6m cell baseline').replace('6mo baseline', '6m baseline').replace('(MTD vs 6mo)', '(MTD vs 6m)').replace('(WTD vs 6mo)', '(WTD vs 6m)')
open(os.environ.get('OUT','pnm-leadership-digest.html'), 'w').write(h)
print('written', len(h))
