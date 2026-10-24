"""python3 verify.py page.html  -> structural checks run before every send."""
import re, sys
h = open(sys.argv[1]).read(); ok = True
for t in ['div','table','details','span','p','tr','td','th','summary','dl','dt','dd']:
    o = len(re.findall(rf'<{t}[\s>]', h)); c = h.count(f'</{t}>')
    if o != c: print('TAG MISMATCH', t, o, c); ok = False
tabs = re.findall(r'<table[^>]*>(.*?)</table>', h, re.S)
key = tabs[0]; assert 'Last week (full)' in key and 'Last week (WTD)' in key
for t in tabs:
    if '<th>This week (WTD)' not in t: continue
    hdr = [re.sub(r'<span class="thdate">.*?</span>', '', x) for x in re.findall(r'<th>(.*?)</th>', t)[1:]]
    assert hdr[-2:] == ['3m avg', '6m avg'], hdr
    for r in re.findall(r'<tr[^>]*>(?!<th>).*?</tr>', t, re.S):
        n = len(re.findall(r'<td[\s>]', r))
        if n != 8: print('BAD COLS', n, r[:90]); ok = False
print('Key rows:', len(re.findall(r'<tr class=', key)), '| stale "6mo":', h.count('6mo'), '| median:', h.lower().count('median of the 26'))
print('OK' if ok else 'FAILED'); sys.exit(0 if ok else 1)
