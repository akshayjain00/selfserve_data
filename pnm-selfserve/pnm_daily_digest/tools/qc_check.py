"""python3 tools/qc_check.py <DATA_DIR> <REPORT_DATE> <qc_query_id>
Independent QC: recomputes the headline Key Metrics (orders, AOV, surge, cancel, dealloc, NPS, detractor %)
from daily sums (rendered/qc_daily_sums.sql) and compares them with what the page shows, for all three views.
Expect 49 checks and 0 mismatches per view. Exit code 1 on any mismatch."""
import os, sys, json, subprocess, importlib
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT); sys.path.insert(0, ROOT)
base, rdate, qid = sys.argv[1], sys.argv[2], sys.argv[3]
raw = json.loads(subprocess.check_output([sys.executable, 'tools/query_result.py', qid]))
from collections import defaultdict
total_bad = 0
for seg in ['all', 'nn', 'nano']:
    os.environ['DATA_DIR'] = f'{base}/{seg}'; os.environ['REPORT_DATE'] = rdate
    sys.modules.pop('build', None); M = importlib.import_module('build').M
    R = defaultdict(lambda: [0.0]*4)
    for rec in raw[0].split(';'):
        src, p, nz, a, b, c, x = rec.split('|'); nz = int(nz)
        if (seg == 'nn' and nz) or (seg == 'nano' and not nz): continue
        v = R[(src, p)]
        for i, val in enumerate((a, b, c, x)): v[i] += float(val)
    def val(k, p):
        if k == 'o_all': return R[('od', p)][0]
        if k == 'aov': a, b, _, _ = R[('av', p)]; return a/b
        if k == 'surge': a, b, _, _ = R[('sg', p)]; return 100*a/b
        if k == 'k_cancel': a, b, c, _ = R[('al', p)]; return 100*b/a
        if k == 'k_dealloc': a, b, c, _ = R[('al', p)]; return 100*c/a
        if k == 'nps.Overall': a, b, c, _ = R[('np', p)]; return 100*(a-b)/c
        if k == 'detr.Overall': a, b, c, x = R[('np', p)]; return 100*b/x
    n = bad = 0
    for k in ['o_all', 'aov', 'surge', 'k_cancel', 'k_dealloc', 'nps.Overall', 'detr.Overall']:
        for p in ['mt', 'ml', 'wt', 'wl', 'lw']:
            x = val(k, p); y = M[k][p]; n += 1
            if abs(y-x) > max(abs(x)*0.0005, 0.0006): bad += 1; print('MISMATCH', seg, k, p, 'page', y, 'qc', x)
        for lab, ms in [('fb3', ['f1', 'f2', 'f3']), ('fb6', ['f1', 'f2', 'f3', 'f4', 'f5', 'f6'])]:
            x = sum(val(k, m) for m in ms)/len(ms); y = M[k][lab]; n += 1
            if abs(y-x) > max(abs(x)*0.0005, 0.0006): bad += 1; print('MISMATCH', seg, k, lab, 'page', y, 'qc', x)
    print(seg, 'checked', n, 'mismatches', bad); total_bad += bad
sys.exit(1 if total_bad else 0)
