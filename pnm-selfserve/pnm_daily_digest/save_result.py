"""python3 save_result.py <NN_file.sql> <query_id> <DATA_DIR>  -> splits a 3-segment result into <DATA_DIR>/{all,nn,nano}/<file>.txt
The query must return its columns in segment order all, nn, nano (same number per segment). 07/09/10/13 return 2-3 columns per segment."""
import sys, os, subprocess, json
name, qid, base = sys.argv[1], sys.argv[2], sys.argv[3]
ONLY = sys.argv[5] if len(sys.argv) > 5 and sys.argv[4] == '--seg' else None   # single-segment result (rendered/<seg>/ file)
QX = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tools', 'query_result.py')
cells = json.loads(subprocess.check_output([sys.executable, QX, qid]))
cells = ['' if c is None else c for c in cells]
SEGS = [ONLY] if ONLY else ['all', 'nn', 'nano']
k = len(cells) // len(SEGS); assert k * len(SEGS) == len(cells), len(cells)
OUT = {'01_alloc': 'alloc.txt', '02_leads': 'leads.txt', '03_pricing': 'pricing.txt', '04_trip_edits': 'trip_edits.txt', '05_cx': 'cx.txt',
       '06_ota': 'ota.txt', '07_tpo': 'tpo.txt', '08_escalations': 'esc.txt', '09_city_orders': 'city_orders.txt', '10_city_aov_surge': 'city_aov_surge.txt',
       '11_city_comp_dealloc': 'city_comp_dealloc.txt', '12_city_ota': 'city_ota.txt', '13_city_tpo_nps': 'city_tpo_nps.txt',
       '14a_cw_leads_orders': 'city_weekly/leads_orders.txt', '14b_cw_aov_surge': 'city_weekly/aov_surge.txt', '14c_cw_canc_dealloc': 'city_weekly/canc_dealloc.txt',
       '14d_cw_ota': 'city_weekly/ota.txt', '14e_cw_tpo_nps': 'city_weekly/tpo_nps.txt'}
stem = name.replace('.sql', '')
for i, seg in enumerate(SEGS):
    c = cells[i*k:(i+1)*k]
    if stem == '07_tpo':
        b = dict(x.split('=') for x in c[1].split(',') if '=' in x)
        txt = c[0] + f";k_tpo|{b.get('mtd_this','')}|{b.get('mtd_last','')}||||||"
    elif stem == '09_city_orders':
        txt = f"CITY_LO={c[0]};(No city yet)|{c[1]}|0\nORDERS={c[2]}"
    elif stem == '10_city_aov_surge':
        txt = f"AOV={c[0]}\nSURGE={c[1]}"
    elif stem == '13_city_tpo_nps':
        txt = f"TPO={c[0]}\nNPS={c[1]}"
    else:
        assert k == 1, (stem, k); txt = c[0]
    p = f'{base}/{seg}/{OUT[stem]}'; os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'w').write(txt)
    print(seg, OUT[stem], len(txt), 'chars', '(EMPTY)' if not txt.strip() else '')
