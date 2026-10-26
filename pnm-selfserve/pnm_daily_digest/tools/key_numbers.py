"""python3 tools/key_numbers.py <DATA_DIR> <REPORT_DATE>  -> headline numbers (Nano excluded view) for the summary message."""
import os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT); sys.path.insert(0, ROOT)
os.environ['DATA_DIR'] = f'{sys.argv[1]}/nn'; os.environ['REPORT_DATE'] = sys.argv[2]
from build import M
for k in ['o_all', 'l_all', 'c_all', 'aov', 'k_cancel', 'k_dealloc', 'ota', 'nps.Overall']:
    print(k, {p: round(M[k][p], 2) for p in ['mt', 'ml', 'wt', 'wl']})
