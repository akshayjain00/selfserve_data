"""python3 tools/daily_prep.py [YYYY-MM-DD]
Step 1 of a scheduled run. REPORT_DATE defaults to yesterday in IST.
- renders the 18 queries into rendered/combined/ (combine_sql.py)
- renders the independent QC query into rendered/qc_daily_sums.sql
- prints REPORT_DATE, DATA_DIR and the period windows so the run can sanity-check them."""
import sys, os, subprocess, datetime as dt
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT); sys.path.insert(0, ROOT)
from periods import periods, render
R = sys.argv[1] if len(sys.argv) > 1 else (dt.datetime.utcnow() + dt.timedelta(hours=5, minutes=30) - dt.timedelta(days=1)).date().isoformat()
P = periods(R)
subprocess.check_call([sys.executable, 'combine_sql.py', R])
qc = render(open('tools/qc_daily_sums.sql.tmpl').read(), P)
assert '__' not in qc
open('rendered/qc_daily_sums.sql', 'w').write(qc)
d = dt.date.fromisoformat(R)
print(f"REPORT_DATE={R}  DATA_DIR=data{d:%m%d}")
print(f"MTD {P['MTD_S']}..{R} vs {P['ML_S']}..{P['ML_E']} | WTD {P['WT_S']}..{R} vs {P['WL_S']}..{P['WL_E']} | last week {P['LW_S']}..{P['LW_E']} | city weeks {P['CW_S']}..{P['CW_E']}")
