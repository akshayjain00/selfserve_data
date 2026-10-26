"""python3 tools/query_result.py <snowflake query_id>  -> prints the first result row (JSON list).
Finds the Snowflake sql-exec tool result in this Claude session's transcript files, so long LISTAGG strings
never have to be retyped by hand. Set TRANSCRIPT_GLOB if the session keeps transcripts elsewhere."""
import sys, json, glob, os
qid = sys.argv[1]
pattern = os.environ.get('TRANSCRIPT_GLOB', os.path.expanduser('~/.claude/projects/*/*.jsonl'))
def walk(o):
    if isinstance(o, str) and qid in o and 'result_set' in o:
        try: return json.loads(o)
        except Exception: return None
    it = o.values() if isinstance(o, dict) else o if isinstance(o, list) else []
    for v in it:
        r = walk(v)
        if r: return r
for f in glob.glob(pattern):
    for line in open(f):
        if qid in line:
            r = walk(json.loads(line))
            if r:
                print(json.dumps(r['result_set']['data'][0])); sys.exit()
print('NOTFOUND', file=sys.stderr); sys.exit(1)
