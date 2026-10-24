"""python3 render_sql.py YYYY-MM-DD [seg ...]  -> writes rendered/<seg>/NN_*.sql with every date and the Nano segment substituted.
Segments (user decision 12 Oct, 3-way toggle on the page): all = Nano included, nn = Nano excluded, nano = Nano only.
Each template marks its Nano condition as {{NANO:<is-nano expression>}}. Test users stay excluded wherever they were.
Run each rendered file in Snowflake and save the single-string result into <DATA_DIR>/<seg>/<file>.txt as noted in each header.
Leads and conversion are OVERALL in every segment (Nano not applicable to leads), so their values repeat across segments."""
import sys, os, glob, re
from periods import periods, render
SEGS = {'all': lambda e: 'TRUE', 'nn': lambda e: f'NOT ({e})', 'nano': lambda e: f'({e})'}
def render_seg(sql, seg):
    return re.sub(r'\{\{NANO:(.*?)\}\}', lambda m: SEGS[seg](m.group(1)), sql)
if __name__ == '__main__':
    P = periods(sys.argv[1]); segs = sys.argv[2:] or list(SEGS)
    PER = open('sql/_periods.sql').read().strip(); FIN = open('sql/_final.sql').read().strip()
    for seg in segs:
        os.makedirs(f'rendered/{seg}', exist_ok=True)
        for f in sorted(glob.glob('sql/[0-9]*.sql')):
            s = render_seg(render(open(f).read().replace('{{PERIODS}}', PER).replace('{{FINAL}}', FIN), P), seg)
            assert '{{' not in s, f
            open(f'rendered/{seg}/' + os.path.basename(f), 'w').write(s)
    print('rendered', len(glob.glob('sql/[0-9]*.sql')), 'files x', segs, 'for', P['R'])
