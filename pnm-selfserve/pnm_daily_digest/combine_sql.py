"""python3 combine_sql.py YYYY-MM-DD  -> rendered/combined/NN_*.sql : ONE query per file returning all three Nano segments
side by side (columns for all, then nn, then nano). Split the result with save_result.py.
- Files with a hand-written 3-segment template in sql3/ (heavy ones: 01, 06-13) use it: shared CTEs are computed once.
- Other files: the three rendered/<seg>/ queries are cross-joined (cheap queries only)."""
import glob, os, sys
from periods import periods, render
from render_sql import render_seg
P = periods(sys.argv[1])
PER = open('sql/_periods.sql').read().strip(); FIN3 = open('sql3/_final3.sql').read().strip()
os.makedirs('rendered/combined', exist_ok=True)
strip = lambda q: '\n'.join(l for l in q.splitlines() if not l.lstrip().startswith('--')).strip().rstrip(';')
for f in sorted(glob.glob('sql/[0-9]*.sql')):
    n = os.path.basename(f)
    if os.path.exists(f'sql3/{n}'):
        sql = strip(render(open(f'sql3/{n}').read().replace('{{PERIODS}}', PER).replace('{{FINAL3}}', FIN3), P))
    else:
        FIN = open('sql/_final.sql').read().strip()
        base = open(f).read().replace('{{PERIODS}}', PER).replace('{{FINAL}}', FIN)
        parts = [f'({strip(render_seg(render(base, P), seg))}) {seg}_q' for seg in ['all', 'nn', 'nano']]
        sql = 'SELECT all_q.*, nn_q.*, nano_q.* FROM ' + '\nCROSS JOIN '.join(parts)
    assert '__' not in sql.replace('__N/A', '') and '{{' not in sql, n
    open(f'rendered/combined/{n}', 'w').write(sql)
print('combined', len(glob.glob('rendered/combined/*.sql')), 'files for', P['R'])
