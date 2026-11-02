"""Card 63201: swap the SQL for the readable-alias rewrite. Same logic, same output columns.
Backs up the live card, refuses if the live SQL has drifted from session_cards.py, then checks
the card returns identical rows before and after (default filters)."""
import json, sys
sys.path.insert(0, '/Users/devansh.sharma/.claude/skills/metabase-chart-builder')
sys.path.insert(0, '.')
from metabase_client import MetabaseClient
from session_cards import sql

CARD = 63201
mb = MetabaseClient()

card = mb.get_card(CARD)
json.dump(card, open(f'card-{CARD}.pre-aliases-2026-10-26.json', 'w'), indent=1)
live = card['dataset_query']['stages'][0]['native']   # MBQL5 shape
if live.strip() != sql('significance').strip():
    sys.exit('Live SQL differs from session_cards.py - backed up, not overwriting. Diff it first.')

# Same filters as the URL you shared, so the comparison runs on real rows.
PARAMS = [{'type': t, 'target': ['variable', ['template-tag', k]], 'value': v} for k, t, v in [
    ('experiment_id', 'category', 'ptl_rolling_slot'),
    ('start_date', 'date/single', '2026-10-22'), ('end_date', 'date/single', '2026-10-24')]]
run = lambda: mb._request('POST', f'/api/card/{CARD}/query', json={'parameters': PARAMS})['data']['rows']
before = run()
print('before sample:', before[:2])

new_sql = open(f'card-{CARD}-readable.sql').read()
dq = card['dataset_query']
dq['stages'][0]['native'] = new_sql            # template-tags unchanged: same {{...}} names
mb.update_card(CARD, dataset_query=dq)

after = run()
print('rows before/after:', len(before), len(after), '| identical:', before == after)
if before != after:
    dq['stages'][0]['native'] = live
    mb.update_card(CARD, dataset_query=dq)
    sys.exit('Output changed - reverted to the backed-up SQL.')
