"""Dashboard 6361: re-key order cards, rebuild the funnel, add session cards, split into tabs."""
import copy, json, sys
sys.path.insert(0, '/Users/devansh.sharma/.claude/skills/metabase-chart-builder')
sys.path.insert(0, '.')
from metabase_client import MetabaseClient
from session_cards import sql
from rekey import rekey

DASH = 6361
PRE = '../pre/'
mb = MetabaseClient()
log = {}

ORDER_CARDS = [54215, 54216, 54217, 54218, 54219, 54220, 54221, 54222, 54223, 54224, 54225, 54226, 56215]

# ---- 1. re-key order-level cards ------------------------------------------------------------
for cid in ORDER_CARDS:
    c = mb.get_card(cid)
    q = copy.deepcopy(c['dataset_query'])
    q['stages'][0]['native'] = rekey(q['stages'][0]['native'])
    mb.update_card(cid, dataset_query=q)
log['rekeyed'] = ORDER_CARDS

# ---- 2. rebuild funnel card 59439 -----------------------------------------------------------
funnel = mb.get_card(59439)
fq = copy.deepcopy(funnel['dataset_query'])
fq['stages'][0]['native'] = sql('funnel')
mb.update_card(
    59439,
    name='PTL Session Funnel - Confirm > Quote > Book Now > Order > Completed',
    dataset_query=fq,
    description=(
        'Session-level PTL funnel by experiment arm (unit = app_session_id). Steps, strictly ordered '
        'within a session: PTL Confirm (vehicle 1159) > Quote viewed > Book now > Order placed '
        '(Book-now order_id = ORDERS.external_id) > Completed (state 3). Cohort = Statsig first '
        'exposure per customer, events on/after exposure; internal users excluded by customer_uuid. '
        'Randomisation is per customer - use the Lift & Significance card for a clustered test.'),
)

# ---- 3. new session cards -------------------------------------------------------------------
base_tags = fq['stages'][0]['template-tags']
gran_tag = copy.deepcopy(mb.get_card(54218)['dataset_query']['stages'][0]['template-tags']['granularity'])
pct = {'suffix': '%', 'decimals': 1}

def q_for(key, granularity=False):
    q = copy.deepcopy(fq)
    q['stages'][0]['native'] = sql(key)
    tags = copy.deepcopy(base_tags)
    if granularity:
        tags['granularity'] = gran_tag
    q['stages'][0]['template-tags'] = tags
    return q

delta_fmt = lambda cols: [
    {'columns': cols, 'type': 'single', 'operator': '>', 'value': 0, 'color': '#84BB4C', 'highlight_row': False},
    {'columns': cols, 'type': 'single', 'operator': '<', 'value': 0, 'color': '#ED6E6E', 'highlight_row': False},
]

NEW = {
    'conv_booknow': dict(
        name='Session Conversion % - Confirm → Book Now', display='bar',
        viz={'graph.dimensions': ['Variant'], 'graph.metrics': ['Session Conv % (Confirm → Book Now)'],
             'graph.x_axis.scale': 'ordinal', 'graph.show_values': True,
             'column_settings': {'["name","Session Conv % (Confirm → Book Now)"]': pct}},
        desc='Share of PTL-Confirm sessions that reach Book now (ordered steps, same session).'),
    'conv_completed': dict(
        name='Session Conversion % - Confirm → Completed', display='bar',
        viz={'graph.dimensions': ['Variant'], 'graph.metrics': ['Session Conv % (Confirm → Completed)'],
             'graph.x_axis.scale': 'ordinal', 'graph.show_values': True,
             'column_settings': {'["name","Session Conv % (Confirm → Completed)"]': pct}},
        desc='Share of PTL-Confirm sessions whose Book-now order reached state 3 (completed).'),
    'significance': dict(
        name='Session Conversion - Lift & Significance (customer-clustered)', display='table',
        viz={'table.column_formatting': delta_fmt(['Δ (pp)', 'Lift %']),
             'column_settings': {'["name","p-value"]': {'decimals': 4}}},
        desc=('Session conversion per arm with a delta-method z-test clustered by customer (Statsig '
              'randomises customers, not sessions). Fixed-sample test: Statsig console CIs use '
              'sequential testing and are ~1.85x wider. Control = arm named Control/fail.')),
    'trend_booknow': dict(
        name='Session Conversion % - Confirm → Book Now - Trend', display='line', gran=True,
        viz={'graph.dimensions': ['Period', 'Variant'], 'graph.metrics': ['Confirm → Book Now %'],
             'graph.x_axis.scale': 'timeseries'},
        desc='Confirm → Book now session conversion by period (Granularity filter) and arm.'),
    'trend_completed': dict(
        name='Session Conversion % - Confirm → Completed - Trend', display='line', gran=True,
        viz={'graph.dimensions': ['Period', 'Variant'], 'graph.metrics': ['Confirm → Completed %'],
             'graph.x_axis.scale': 'timeseries'},
        desc='Confirm → Completed session conversion by period (Granularity filter) and arm.'),
    'segments': dict(
        name='Session Conversion by Segment - Control vs Test', display='table',
        viz={'table.column_formatting': delta_fmt(['Book Now Δ (pp)', 'Completed Δ (pp)'])},
        desc=('Session conversion by customer category, new/repeat, pickup city and platform. '
              'Descriptive only - small segments are noisy; no significance test here.')),
    'time_to_book': dict(
        name='Time from Confirm to Book Now (min)', display='bar',
        viz={'graph.dimensions': ['Variant'],
             'graph.metrics': ['P50 Confirm → Book Now (min)', 'P75 Confirm → Book Now (min)'],
             'graph.x_axis.scale': 'ordinal', 'graph.show_values': True},
        desc='P50/P75 minutes from first PTL Confirm to last Book now, converting sessions only.'),
}
new_ids = {}
for key, spec in NEW.items():
    card = mb.create_card(name=spec['name'], display=spec['display'],
                          dataset_query=q_for(key, spec.get('gran', False)),
                          visualization_settings=spec['viz'], collection_id=funnel['collection_id'],
                          description=spec['desc'])
    new_ids[key] = card['id']
log['new_cards'] = new_ids
json.dump(log, open('build-log.json', 'w'), indent=1)
print(log)
