# Builds the all-cities map and one page per pickup city from template.html + density-data.json.
import sys, json, os, re, html
S = sys.argv[1]
old = open('coordination/ptl-service-zones-map.pre-density-2026-10-15.html').read()
css = [b.split('</style>')[0] for b in old.split('<style>')[1:] if 'leaflet-pane' in b][0]
js = [b.split('</script>')[0] for b in old.split('<script>')[1:] if 'Leaflet 1.9.4' in b][0]
tpl = open(S + '/template.html').read()
data = json.load(open(S + '/density-data.json'))

def render(d, title, h1, lock):
    return (tpl.replace('__LEAFLET_CSS__', css).replace('__LEAFLET_JS__', js)
               .replace('__TITLE__', title).replace('__H1__', h1)
               .replace('__LOCK__', json.dumps(lock)).replace('__DATA__', json.dumps(d, separators=(',', ':'))))

open('ptl-service-zones-map.html', 'w').write(render(data, 'PTL Pickup Density', 'PTL pickup density', None))

CELL, PAD = 0.002, 0.1  # pickups outside every zone are kept if within ~11 km of the city's bounding box
out_dir = 'ptl-pickup-density-by-city'
os.makedirs(out_dir, exist_ok=True)
outside = next(c for c in data['cells'] if c['CITY'] == '~')
def cells_of(g):
    for s in g['S'].split(';'):
        k, v = s.split(':')
        yield g['A0'] + int(k[:3], 16), g['B0'] + int(k[3:6], 16), v
summary = []
for z in data['zones']:
    pts = [tuple(map(float, p.split())) for r in z['rings'] for p in r.split(',')]
    lo_lng, hi_lng = min(p[0] for p in pts) - PAD, max(p[0] for p in pts) + PAD
    lo_lat, hi_lat = min(p[1] for p in pts) - PAD, max(p[1] for p in pts) + PAD
    near = [(a, b, v) for a, b, v in cells_of(outside) if lo_lat <= a * CELL <= hi_lat and lo_lng <= b * CELL <= hi_lng]
    cells = [c for c in data['cells'] if c['CITY'] == z['name']]
    if near:
        a0, b0 = min(a for a, _, _ in near), min(b for _, b, _ in near)
        cells.append({'CITY': '~', 'A0': a0, 'B0': b0, 'N': 0,
                      'S': ';'.join(f'{a - a0:03X}{b - b0:03X}:{v}' for a, b, v in near)})
    slug = re.sub(r'[^a-z0-9]+', '-', z['name'].lower()).strip('-')
    open(f'{out_dir}/{slug}.html', 'w').write(render({'zones': [z], 'cells': cells},
        f"{z['name']} Pickup Density", f"{html.escape(z['name'])} pickup density", z['name']))
    n = sum(c['N'] for c in data['cells'] if c['CITY'] == z['name'])
    summary.append((n, z['name'], slug, len(near)))
print(sorted(summary, reverse=True))
