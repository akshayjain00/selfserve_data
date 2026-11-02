"""Old vs new session_cards.py: every card must return identical rows on the same filters."""
import importlib.util, re, sys
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/Users/devansh.sharma/.claude/skills/metabase-chart-builder')
from metabase_client import MetabaseClient

def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
old, new = load('pre-aliases-2026-10-26/session_cards.py', 'old'), load('session_cards.py', 'new')
VALUES = {'experiment_id': "'ptl_rolling_slot'", 'start_date': "'2026-10-22'",
          'end_date': "'2026-10-24'", 'granularity': "'day'"}

def bind(q):
    # keep optional clauses whose tag has a value, drop the rest, then fill the tags
    q = re.sub(r'\[\[(.*?)\]\]', lambda m: m.group(1) if all(t in VALUES for t in re.findall(r'\{\{(\w+)\}\}', m.group(1))) else '', q, flags=re.S)
    return re.sub(r'\{\{(\w+)\}\}', lambda m: VALUES[m.group(1)], q)

mb = MetabaseClient()
run = lambda q: mb.run_native(bind(q))['data']['rows']
keys = list(old.CARDS)
with ThreadPoolExecutor(6) as pool:
    res = {k: (pool.submit(run, old.sql(k)), pool.submit(run, new.sql(k))) for k in keys}
    ok = True
    for k, (a, b) in res.items():
        a, b = a.result(), b.result()
        ok &= a == b
        print(f'{k:20s} rows {len(a):3d} / {len(b):3d}  identical={a == b}')
print('ALL IDENTICAL' if ok else 'MISMATCH')
