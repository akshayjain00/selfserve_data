"""Split dashboard 6361 into 5 tabs. Existing dashcards keep their ids/mappings; text headers are dropped."""
import copy, json, sys
sys.path.insert(0, '/Users/devansh.sharma/.claude/skills/metabase-chart-builder')
from metabase_client import MetabaseClient

DASH = 6361
mb = MetabaseClient()
new = json.load(open('build-log.json'))['new_cards']
dash = mb.get_dashboard(DASH)
by_card = {dc['card_id']: dc for dc in dash['dashcards'] if dc['card_id']}
GRAN = '4c4aa8ce'

TABS = [(-1, 'Overview'), (-2, 'Session Conversion'), (-3, 'CBDF'),
        (-4, 'Allocation & CADF'), (-5, 'Fulfillment')]

# (tab, card, row, col, w, h) ; same card may appear on two tabs (gets a fresh dashcard)
LAYOUT = [
    (-1, new['conv_booknow'],    0,  0, 12, 6), (-1, new['conv_completed'], 0, 12, 12, 6),
    (-1, 54215,                  6,  0, 12, 6), (-1, 56215,                 6, 12, 12, 6),
    (-1, new['significance'],   12,  0, 24, 6),

    (-2, 59439,                  0,  0, 24, 8),
    (-2, new['trend_booknow'],   8,  0, 12, 7), (-2, new['trend_completed'], 8, 12, 12, 7),
    (-2, new['segments'],       15,  0, 24, 10),
    (-2, new['time_to_book'],   25,  0, 12, 6),

    (-3, 54216,                  0,  0, 12, 5), (-3, 54215,                 0, 12, 12, 5),
    (-3, 54224,                  5,  0,  8, 5), (-3, 54226,                 5,  8,  8, 5),
    (-3, 54225,                  5, 16,  8, 5),
    (-3, 54218,                 10,  0, 12, 7), (-3, 54219,                10, 12, 12, 7),
    (-3, 54221,                 17,  0, 24, 6),

    (-4, 54220,                  0,  0, 24, 6), (-4, 54223,                 6,  0, 24, 6),

    (-5, 56215,                  0,  0, 12, 6), (-5, 54217,                 0, 12, 12, 6),
    (-5, 54222,                  6,  0, 24, 7),
]

funnel_maps = by_card[59439]['parameter_mappings']
def maps_for(card_id, granularity=False):
    m = [{**x, 'card_id': card_id} for x in funnel_maps]
    if granularity:
        m.append({'parameter_id': GRAN, 'card_id': card_id,
                  'target': ['variable', ['template-tag', 'granularity']]})
    return m

used, out, neg = set(), [], -100
for tab, cid, row, col, w, h in LAYOUT:
    if cid in by_card and cid not in used:      # reuse the existing dashcard (keeps id + mappings)
        dc = by_card[cid]; used.add(cid)
        out.append({'id': dc['id'], 'card_id': cid, 'dashboard_tab_id': tab, 'row': row, 'col': col,
                    'size_x': w, 'size_y': h, 'series': dc.get('series') or [],
                    'parameter_mappings': dc['parameter_mappings'],
                    'visualization_settings': dc.get('visualization_settings') or {}})
    else:
        neg -= 1
        src = by_card.get(cid)
        pm = ([{**x} for x in src['parameter_mappings']] if src
              else maps_for(cid, granularity=cid in (new['trend_booknow'], new['trend_completed'])))
        out.append({'id': neg, 'card_id': cid, 'dashboard_tab_id': tab, 'row': row, 'col': col,
                    'size_x': w, 'size_y': h, 'series': [], 'parameter_mappings': pm,
                    'visualization_settings': {}})

# overlap check per tab
for tab, _ in TABS:
    cells = set()
    for d in out:
        if d['dashboard_tab_id'] != tab: continue
        assert d['col'] + d['size_x'] <= 24
        for r in range(d['row'], d['row'] + d['size_y']):
            for c in range(d['col'], d['col'] + d['size_x']):
                assert (r, c) not in cells, (tab, d['card_id']); cells.add((r, c))

dropped = [dc['id'] for dc in dash['dashcards'] if dc['card_id'] is None]
missing = set(by_card) - {d['card_id'] for d in out}
assert not missing, missing
res = mb._request('PUT', f'/api/dashboard/{DASH}',
                  json={'tabs': [{'id': i, 'name': n} for i, n in TABS], 'dashcards': out})
print('tabs:', [(t['id'], t['name']) for t in res['tabs']])
print('dashcards:', len(res['dashcards']), '| dropped text headers:', dropped)
