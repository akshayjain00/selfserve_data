"""Build the digest once per Nano segment and stitch the three into ONE page with a toggle at the top (user decision 12 Oct).

  DATA_DIR=data1012 REPORT_DATE=2026-10-11 OUT=pnm-leadership-digest.html python3 compose.py

Expects <DATA_DIR>/all, <DATA_DIR>/nn, <DATA_DIR>/nano, each holding the usual *.txt files + city_weekly/ (see render_sql.py).
Segments: all = Nano included, nn = Nano excluded (default view), nano = Nano only.
Leads and Conversion are never Nano-filtered; they carry an "Overall · Nano filter n/a" tag and repeat across views.
Test users stay excluded in every view, as before.
"""
import os, re, subprocess, sys

SEGS = [('nn', 'Nano excluded'), ('all', 'All orders (Nano included)'), ('nano', 'Nano only')]
DEFAULT = os.environ.get('DEFAULT_SEG', 'nn')
base, out = os.environ.get('DATA_DIR', 'data'), os.environ.get('OUT', 'pnm-leadership-digest.html')
tmp = os.environ.get('TMP_DIR', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build_tmp'))
os.makedirs(tmp, exist_ok=True)

pages = {}
for seg, _ in SEGS:
    env = dict(os.environ, DATA_DIR=f'{base}/{seg}', SEG=seg, OUT=f'{tmp}/{seg}.html')
    r = subprocess.run([sys.executable, 'build_html.py'], env=env, capture_output=True, text=True)
    if r.returncode:
        sys.exit(f'build failed for segment {seg}:\n{r.stderr[-3000:]}')
    v = subprocess.run([sys.executable, 'verify.py', f'{tmp}/{seg}.html'], capture_output=True, text=True)
    if 'OK' not in v.stdout:
        sys.exit(f'verify failed for segment {seg}:\n{v.stdout}{v.stderr}')
    pages[seg] = open(f'{tmp}/{seg}.html').read()

START = '<div class="key-metrics-section">'
def region(h):
    i = h.index(START)
    j = h.rfind('<div', 0, h.index('id="rules"'))   # the collapsed rules register stays shared, outside the views
    return i, j

# ---- Nano only view: hide rows / columns that have no data at all (user 12 Oct) ----
_TAG = re.compile(r'<[^>]+>')
def _empty(cell):
    t = _TAG.sub('', cell).replace('&mdash;', '').replace('\u2014', '').strip()
    return t == ''
def prune_empty(html):
    def fix_table(m):
        open_t, inner, close_t = m.group(1), m.group(2), m.group(3)
        rows = re.findall(r'<tr[^>]*>.*?</tr>', inner, re.S)
        if not rows: return m.group(0)
        def cells(r): return re.findall(r'<t[hd][^>]*>.*?</t[hd]>', r, re.S)
        head = [r for r in rows if '<th' in r]; body = [r for r in rows if '<th' not in r]
        if not body: return m.group(0)
        # data cells = all except first (name) column; trend tables also end with a sparkline cell
        keep_rows = [r for r in body if not all(_empty(c) for c in cells(r)[1:])]
        if not keep_rows: return m.group(0)          # never blank out a whole table
        ncol = max(len(cells(r)) for r in keep_rows)
        drop = {j for j in range(1, ncol) if all(j < len(cells(r)) and _empty(cells(r)[j]) for r in keep_rows)}
        if 'trend-table' in open_t: drop.discard(ncol - 1)   # keep the sparkline column
        def strip(r):
            cs = cells(r)
            if not drop or len(cs) != ncol: return r
            out = r
            for j in sorted(drop, reverse=True):
                c = cs[j]; k = out.rfind(c); out = out[:k] + out[k+len(c):]
            return out
        new = [strip(r) for r in head] + [strip(r) for r in keep_rows]
        return open_t + ''.join(new) + close_t
    return re.sub(r'(<table[^>]*>)(.*?)(</table>)', fix_table, html, flags=re.S)

shell = pages[DEFAULT]
i0, j0 = region(shell)
views = []
for seg, label in SEGS:
    h = pages[seg]; i, j = region(h); body = h[i:j]
    body = re.sub(r'\bid="([^"]+)"', lambda m: f'id="{m.group(1)}--{seg}"', body)
    body = re.sub(r'href="#([^"]+)"', lambda m: f'href="#{m.group(1)}--{seg}"', body)
    body = re.sub(r'aria-controls="([^"]+)"', lambda m: f'aria-controls="{m.group(1)}--{seg}"', body)
    if seg == 'nano': body = prune_empty(body)
    views.append(f'<div class="seg-view" data-seg="{seg}"{"" if seg == DEFAULT else " hidden"}>\n{body}\n</div>\n')

btns = ''.join(f'<button type="button" class="segbtn" data-seg="{s}" aria-pressed="{"true" if s == DEFAULT else "false"}">{l}</button>'
               for s, l in SEGS)
BAR = ('<div class="segbar" role="group" aria-label="Nano filter">'
       '<span class="segbar-label">Nano filter</span>' + btns +
       '<span class="segbar-note">Applies to every metric except Leads and Conversion, which are always overall.</span></div>\n')

CSS = """
  /* ---- Nano filter toggle (user 12 Oct) ---- */
  .segbar{display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin:10px 0 18px;padding:10px 12px;border:1px solid var(--line);background:var(--panel);}
  .segbar-label{font-weight:700;font-size:12px;letter-spacing:.04em;text-transform:uppercase;margin-right:4px;}
  .segbtn{font:inherit;font-size:13px;padding:6px 12px;border:1px solid var(--line);background:transparent;color:var(--ink);cursor:pointer;border-radius:999px;}
  .segbtn[aria-pressed="true"]{background:var(--ink);color:var(--bg, #fff);border-color:var(--ink);}
  .segbtn:focus-visible{outline:2px solid var(--ink);outline-offset:2px;}
  .segbar-note{font-size:12px;color:var(--ink-faint);flex-basis:100%;}
  .segtag{display:inline-block;margin-left:6px;padding:1px 6px;font-size:10.5px;font-weight:600;color:var(--ink-faint);border:1px solid var(--line);border-radius:999px;white-space:nowrap;vertical-align:1px;}
  .seg-view[hidden]{display:none;}
  .thdate{display:block;margin-top:3px;font-weight:400;letter-spacing:0;text-transform:none;color:var(--ink-faint);font-size:11px;white-space:nowrap;}
"""
JS = """
<script>
(function(){
  var btns = document.querySelectorAll('.segbtn'), views = document.querySelectorAll('.seg-view');
  function show(seg){
    views.forEach(function(v){ v.hidden = v.getAttribute('data-seg') !== seg; });
    btns.forEach(function(b){ b.setAttribute('aria-pressed', b.getAttribute('data-seg') === seg ? 'true' : 'false'); });
    try { history.replaceState(null, '', '#seg=' + seg); } catch(e) {}
  }
  btns.forEach(function(b){ b.addEventListener('click', function(){ show(b.getAttribute('data-seg')); }); });
  var m = (location.hash || '').match(/seg=(all|nn|nano)/); if (m) show(m[1]);
})();
</script>
"""
page = shell[:i0] + BAR + ''.join(views) + shell[j0:]
page = page.replace('</style>', CSS + '</style>', 1)
page = page.replace('</body>', JS + '</body>', 1)
# the header meta says which filters apply
page = page.replace('&middot; Intra-city</div>', '&middot; Intra-city &middot; test users excluded</div>', 1)
open(out, 'w').write(page)
print('composed', out, len(page), 'bytes; default view =', DEFAULT)
