"""python3 tools/struct_check.py <DATA_DIR>
Structural checks across the three views. Expect 'cells 45 city-weeks 130 BAD 0' (counts can grow if a city/BHK appears).
- City x BHK orders: all = nn + nano
- City weekly orders: all = nn + nano; leads and conversion identical across views; cities sum <= Network
- leads.txt: l_*/c_* rows identical across views; o_all all = nn + nano
Also prints the Kolkata last-two-weeks row (open data note). Exit code 1 if BAD > 0."""
import sys, os
base = sys.argv[1]
def rd(seg, f): return open(f'{base}/{seg}/{f}').read().strip()
bad = 0
def orders(seg):
    for line in rd(seg, 'city_orders.txt').splitlines():
        if line.startswith('ORDERS='): return {r.split('|')[0]: float(r.split('|')[1]) for r in line[7:].split(';') if r}
A, N, Z = orders('all'), orders('nn'), orders('nano'); keys = set(A) | set(N) | set(Z)
for k in keys:
    if abs(A.get(k, 0)-N.get(k, 0)-Z.get(k, 0)) > 0.5: bad += 1; print('BHK', k)
def cw(seg): return {(r.split('|')[0], r.split('|')[1]): r.split('|')[2:] for r in rd(seg, 'city_weekly/leads_orders.txt').split(';')}
A, N, Z = cw('all'), cw('nn'), cw('nano')
for k in A:
    a, n, z = A[k], N[k], Z[k]
    if int(a[1]) != int(n[1])+int(z[1]): bad += 1; print('ORD', k)
    if not (a[0] == n[0] == z[0] and a[2] == n[2] == z[2]): bad += 1; print('LEADCONV', k)
for seg, D in [('all', A), ('nn', N), ('nano', Z)]:
    for w in {k[1] for k in D}:
        if sum(int(v[1]) for (c, ww), v in D.items() if ww == w and c != 'Network') > int(D[('Network', w)][1]): bad += 1; print('NETSUM', seg, w)
def lead(seg): return {r.split('|')[0]: r for r in rd(seg, 'leads.txt').split(';') if r.split('|')[0][:2] in ('l_', 'c_')}
L = [lead(s) for s in ('all', 'nn', 'nano')]
for k in L[0]:
    if not (L[0][k] == L[1].get(k) == L[2].get(k)): bad += 1; print('LEADS', k)
def oall(seg):
    for r in rd(seg, 'leads.txt').split(';'):
        if r.startswith('o_all|'): return [float(x) if x else 0 for x in r.split('|')[1:8]]
a, n, z = oall('all'), oall('nn'), oall('nano')
for i in range(7):
    if abs(a[i]-n[i]-z[i]) > 0.6: bad += 1; print('OALL', i)
print('cells', len(keys), 'city-weeks', len(A), 'BAD', bad)
wk = sorted({w for (c, w) in A if c == 'Kolkata'})[-2:]
print('Kolkata (leads|orders|conv):', {w: A[('Kolkata', w)] for w in wk})
sys.exit(1 if bad else 0)
