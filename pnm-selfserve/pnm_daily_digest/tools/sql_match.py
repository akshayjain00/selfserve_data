"""python3 tools/sql_match.py
Confirms the last 18 Snowflake sql-exec calls in this Claude session's transcript are exactly the 18 files in
rendered/combined/ (whitespace-normalised). Expect '18/18 matched'. Exit code 1 otherwise."""
import json, re, glob, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
n = lambda s: re.sub(r'\s+', ' ', s).strip()
pattern = os.environ.get('TRANSCRIPT_GLOB', os.path.expanduser('~/.claude/projects/*/*.jsonl'))
calls = []
for f in glob.glob(pattern):
    for line in open(f):
        if 'sql-exec' not in line: continue
        try: d = json.loads(line)
        except Exception: continue
        m = d.get('message', {})
        if isinstance(m, dict) and isinstance(m.get('content'), list):
            for c in m['content']:
                if c.get('type') == 'tool_use' and c.get('name', '').endswith('sql-exec'):
                    calls.append((d.get('timestamp', ''), n(c['input'].get('sql', ''))))
calls.sort(); last = {s for _, s in calls[-40:]}
files = sorted(glob.glob(f'{ROOT}/rendered/combined/*.sql'))
miss = [f for f in files if n(open(f).read()) not in last]
for f in miss: print('MISS', os.path.basename(f))
print(f'{len(files)-len(miss)}/{len(files)} matched'); sys.exit(1 if miss else 0)
