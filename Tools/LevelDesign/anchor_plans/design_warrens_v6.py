"""Warrens v6, "Kitchen first": the LIVE layout, data/warrens.json (run: python design_warrens_v6.py).

v5 ("The Well", design_warrens_v5.py) is unchanged and this file applies one reviewed delta to its tables: the r02
expansion, proposal-i (docs/design/warrens-expansion-r02/proposal.json; its geometry is copied into
design_warrens_v6_geometry.json because docs/ is not in git). Execution plan: docs/design/warrens-expansion-r02/G2_EXECUTION_PLAN.md.

- The Lamp Chapel keeps its four public doors; the hearth K now sits inside a sealed kitchen (x 35..45, y 40.5..50.5,
  walls 2.7, a continuous roof at 2.9). An aisle ring (aW west, aS south, aE east, aN north; not kS/kN, which FName would merge with the door sills ks/kn) carries the old crossings
  round it, and K is reached only through the east cargo port (a latched Gate), opened once by a hand crank on the
  kitchen's west wall (P K). The packless west service port shares the release; like every crawl it is not a plan link.
- The Root Grotto (-2.5) west of the Cistern: a required tunnel from the Cistern (CI-gE), a north port (gN) reached
  from the Charnel Court by a corridor at 0 (c1-sp1), an 18-tread service spiral down to -2.5 (sp1-sp0, kind 'spiral',
  built from explicit treads, never a ramp) and a low tunnel (sp0-gN). The Court corridor and the overlook approach
  cross over the low tunnel (links marked over: the builder caps the tunnel instead of overwriting it).
- An overlook deck over the Grotto with a real 1.4 m drop hole, a roof break above it, a triangulated rise in the
  Grotto's south, the Root Listener's Recess behind a packless crawl.
- The PumpTrap and CellarVents pockets keep their recesses as shells and lose their anchors.

Decisions (maintainer, 2026-10-20): D1 the Grotto is in the plan graph; D2 the cargo port is Mars_Gate's 2.0 x 2.2 m
opening; D3 decks are railed where they drop to open air; D4 K behind the east door; D5 retired pockets as shells.
Plan-graph changes vs v5: 51 nodes, 59 links (v5: 43, 49); the solver tests' expected distances were recomputed.
The Bellkeeper (P4) and the mission content are unchanged here (G4 / G6).
"""
import json
import math
from pathlib import Path

import design_warrens_v5 as v5

HERE = Path(__file__).resolve().parent
OUT = HERE / 'data' / 'warrens.json'
GEOMETRY = json.loads((HERE / 'design_warrens_v6_geometry.json').read_text(encoding='utf-8'))
CORRIDOR, TUNNEL, UP, DOWN = v5.CORRIDOR, v5.TUNNEL, v5.UP, v5.DOWN
SPIRAL_RUN = 3.5 * math.radians(270)  # the spiral's centreline length (radius 3.5 m, 270 degrees)

NODES = dict(v5.NODES)
NODES.update({
    'aW': (33, 45.6, 0), 'aS': (42, 39.5, 0), 'aE': (47, 44, 0), 'aN': (40, 51.5, 0),  # the public aisle round the kitchen
    'gE': (0, 15, DOWN), 'gN': (-6, 24, DOWN),                                       # the Grotto's east and north ports
    'sp0': (-4.5, 43, DOWN), 'sp1': (-8, 39.5, 0),                                  # the service spiral's foot and head
})

_KITCHEN_CUT = {('K', 'h0'), ('K', 'wW'), ('K', 'kn'), ('K', 'ks')}
# (a, b, via, width, kind, closedBy)
LINKS = [l for l in v5.LINKS if (l[0], l[1]) not in _KITCHEN_CUT] + [
    # the chapel aisle: R1 stays on the Nave throat; K only through the cargo port
    ('aW', 'h0', [(32, 45.6), (31, 44)], CORRIDOR, 'walk', 'R1'),
    ('aW', 'aS', [(33, 39.5)], CORRIDOR, 'walk', None), ('aS', 'aE', [(47, 39.5)], CORRIDOR, 'walk', None),
    ('aS', 'ks', [], CORRIDOR, 'walk', None),
    ('aW', 'aN', [(33, 51.5)], CORRIDOR, 'walk', None), ('aN', 'aE', [(47, 51.5)], CORRIDOR, 'walk', None),
    ('aN', 'kn', [], CORRIDOR, 'walk', None),
    ('aE', 'wW', [(49, 44)], CORRIDOR, 'walk', None),
    ('aE', 'K', [(45, 44)], CORRIDOR, 'walk', None),
    # the Grotto
    ('CI', 'gE', [(23, 19), (16, 19), (10, 15)], CORRIDOR, 'walk', None),
    ('gE', 'gN', [(-4, 17), (-4.75, 21)], CORRIDOR, 'walk', None),
    ('c1', 'sp1', [(8, 32), (1, 31.5), (-1, 35), (-8, 38.75)], CORRIDOR, 'walk', None),
    ('sp1', 'sp0', [], 2.5, 'spiral', None),
    ('sp0', 'gN', [(-1, 39), (-1, 34), (-5, 31)], CORRIDOR, 'walk', None),
]
# Per-link builder flags: over = cross above a lower walkable cell without overwriting it (cap it); connector = the
# explicit 3D connector a 'spiral' link is built from.
LINK_FLAGS = {('c1', 'sp1'): dict(over=True, clearHeight=2.4), ('sp1', 'sp0'): dict(connector='service-spiral')}

ROOMS = list(v5.ROOMS) + [dict(r, light=None) for r in GEOMETRY['newRooms']]
NICHES = [n for n in v5.NICHES if n['id'] not in GEOMETRY['retireNiches']]
ROOMS += [dict(id=n['id'] + '-shell', label='', rect=n['rect'], z=n['z'], note='retired pocket: the recess stays, no anchor')
          for n in v5.NICHES if n['id'] in GEOMETRY['retireNiches']]
CRAWLS = list(v5.CRAWLS) + [
    dict(id='grotto-recess-crawl', a=(-19, 22), b=(-22, 31), via=[(-22, 25)], z=DOWN, packFits=False, note='to the Root Listener\'s Recess',
         purpose='an optional packless squeeze to a small standing discovery pocket; no required ingredient'),
]
EXTRA_WALKS = list(v5.EXTRA_WALKS) + [
    dict(id='overlook-approach', pts=[(-1, 35), (-1, 28), (-1, 23)], width=2.0, over=True, low=True,
         note='the scout spur from the Court corridor onto the overlook deck; a one-way drop, so not a plan link'),
]
HOLES = list(v5.HOLES) + [dict(id=r['id'], level='upper', rect=r['rect'], kind='open', note=r['note']) for r in GEOMETRY['roofBreaks']]
LOW_LINKS = list(v5.LOW_LINKS) + [('sp0', 'gN')]

PUZZLES = list(v5.PUZZLES) + [
    dict(id='PK', kind='kitchen shutters (latched)', at=(45, 44, 0), needsAt=tuple(GEOMETRY['kitchen']['exteriorCrank']['at']),
         needsNote='the exterior hand crank on the kitchen\'s west wall: one turn latches both shutters open for the run'),
]


def _moved_props():
    props = [dict(p) for p in v5.PROPS]
    for change in GEOMETRY['existingPropChanges']:
        hits = [p for p in props if p['kind'] == change['sourceKind'] and math.dist(p['at'], change['sourceAt']) < 0.01]
        assert len(hits) == 1, change
        hits[0]['at'] = tuple(change['to'])
        if 'size' in change:
            hits[0]['size'] = tuple(change['size'])
    return props + [dict(p, at=tuple(p['at']), size=tuple(p['size'])) for p in GEOMETRY['newProps']]


PROPS = _moved_props()
FIXTURE_KIND = {'find-drive': 'task', 'spiral-depth': 'dim', 'grotto-roof-light': 'sky', 'crown-focus': 'task'}
LIGHTS = [dict(l) for l in v5.LIGHTS]
for change in GEOMETRY['existingLightChanges']:
    hits = [l for l in LIGHTS if math.dist(l['at'], change['sourceAt']) < 0.01]
    assert len(hits) == 1, change
    hits[0]['at'] = tuple(change['to'])
LIGHTS += [dict(at=tuple(f['at']), kind=FIXTURE_KIND[f['id']], note=f['id'] + ': ' + f['mount']) for f in GEOMETRY['fixtures']]
# Per-lamp tuning (calibrated in game, 2026-10-20): the Pit's shaft and cold lamps at 0.1 so the Pit floor reads near-black
# under the lantern; the Pump lamp at 0.25 so it reads as a lamp, not a flood. The cold lamp also lights the Bellkeeper clue:
# the clue needs its own light when G4 lands.
LAMP_SCALES = {(60, 46, 8.0): 0.1, (60, 40, -1.0): 0.1, (51, 17, 0.1): 0.25}
for l in LIGHTS:
    for at, scale in LAMP_SCALES.items():
        if math.dist(l['at'], at) < 0.01:
            l['scale'] = scale
assert sum(1 for l in LIGHTS if 'scale' in l) == len(LAMP_SCALES), 'a LAMP_SCALES position matches no light'

FOOTPRINT = (-29, -3, 104, 88)

# District fills (r1 lighting, 2026-10-20): one unshadowed room-sized light per room, tinted from the concept board
# (docs/art/warrens-v5-lighting-r01). The Pit, the Vault, the closet, the recess and the Well rims stay unfilled: the rims
# sit over the Pit and the Well has its shaft light. The builder places, sizes and scales them (FILL_KINDS, FILL_SCALE).
FILLS = [
    ('chapel', 'amber'), ('court', 'funeral'), ('bridge', 'indigo'), ('ossuary', 'ivory'), ('reliquary', 'candle'),
    ('chime', 'teal'), ('pump', 'copper'), ('cellar', 'copper'), ('sluice', 'teal'), ('cistern', 'navy'),
    ('root-grotto', 'limestone'), ('spiral-well', 'chalk'),
]


def build():
    links = []
    for a, b, via, w, kind, closed in LINKS:
        run = SPIRAL_RUN if kind == 'spiral' else v5.length([NODES[a][:2]] + list(via) + [NODES[b][:2]])
        if kind in ('stair', 'spiral'):
            run = math.hypot(run, abs(NODES[a][2] - NODES[b][2]))
        link = dict(a=a, b=b, via=[list(p) for p in via], width=w, kind=kind, closedBy=closed, costCm=int(round(run * 100)),
                    leverNode=v5.LEVER_NODE.get(closed) if closed else None)
        link.update(LINK_FLAGS.get((a, b), {}))
        links.append(link)
    for l in LINKS:
        if l[5] and v5.LEVER_NODE.get(l[5]) and v5.LEVER_NODE[l[5]] not in (l[0], l[1]):
            raise SystemExit(f'lever node of {l[5]} is not an end of its link')
    anchors = [dict(id=f'S{i}', family='S', at=list(NODES[f'S{i}'][:2]), node=f'S{i}', note='foyer') for i in range(1, 6)]
    anchors += [dict(id=aid, family='H', at=list(NODES[node][:2]), node=node, note='hunt court') for aid, node in (('H1', 'H1'), ('H2', 'H2'), ('H3', 'CH'))]
    anchors += [dict(id=l[5], family='R', at=list(v5.ANCHOR_AT[l[5]] or NODES[l[0]][:2]), node=l[0], note='route gate') for l in LINKS if l[5]]
    niches = [dict(n, rect=list(n['rect']), anchorId=v5.pocket_anchor_id(n['id'])) for n in NICHES]
    return dict(
        map='Warrens', revision='v6r1',
        source='Tools/LevelDesign/anchor_plans/design_warrens_v6.py (Warrens v6 Kitchen first: v5 The Well + the r02 proposal-i expansion, 2026-10-20)',
        units='metres; costCm is the walk cost in centimetres', hearth='K',
        footprint=list(FOOTPRINT), deep=list(v5.DEEP), rampRoofZ=v5.RAMP_ROOF_Z,
        nodes={k: list(v) for k, v in NODES.items()}, links=links,
        rooms=[dict(r, rect=list(r['rect'])) if 'rect' in r else dict(r, poly=[list(p) for p in r['poly']]) for r in ROOMS],
        crawls=[dict(c, a=list(c['a']), b=list(c['b'])) for c in CRAWLS],
        galleries=v5.GALLERIES, upper=v5.UPPER, ladders=v5.LADDERS, holes=HOLES, extraWalks=EXTRA_WALKS, shortcuts=v5.SHORTCUTS,
        cracks=v5.CRACKS, pillars=[dict(p, rect=list(p['rect'])) for p in v5.PILLARS], lowLinks=[list(l) for l in LOW_LINKS],
        lowRoof=v5.LOW_ROOF, locks=v5.LOCKS, puzzles=PUZZLES,
        extraRamps=[dict(r, a=list(r['a']), b=list(r['b'])) for r in v5.EXTRA_RAMPS],
        niches=niches, caches=[n['anchorId'] for n in niches if n['family'] == 'C'], maxActiveCaches=v5.MAX_ACTIVE_CACHES,
        water=[dict(w, rect=list(w['rect'])) for w in v5.WATER],
        props=[dict(p, at=list(p['at']), size=list(p['size'])) for p in PROPS],
        lights=[dict(l, at=list(l['at'])) for l in LIGHTS],
        groups=[dict(name='Warren', anchorIds=['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7'], maxClosed=3)],
        entrances=[dict(anchorId=f'S{i}', playerStartTag=v5.FOYERS[f'S{i}'], node=f'S{i}') for i in range(1, 6)],
        courts=[dict(anchorId='H1', node='H1'), dict(anchorId='H2', node='H2'), dict(anchorId='H3', node='CH')],
        anchors=anchors, channels={f'R{i}': f'Mechanism.Channel.Anchor.Warrens.R{i}' for i in range(1, 8)},
        quarryMinWalkCm=5000,
        # The explicit 3D layer (built as boxes beside the rasterized grid): structures with their opening cuts, the
        # spiral's treads, the terrain patch, and the kitchen contract the puzzle row wires.
        structures=GEOMETRY['structures'], openings=GEOMETRY['openings'], connectors=GEOMETRY['connectors'],
        terrain=GEOMETRY['terrain'], kitchen=GEOMETRY['kitchen'], geometryDeviations=GEOMETRY['deviations'],
        fills=[dict(room=r, kind=k) for r, k in FILLS],
    )


if __name__ == '__main__':
    data = build()
    OUT.write_text(json.dumps(data, indent=1), encoding='utf-8')
    print(f'wrote {OUT.name}: {len(data["nodes"])} nodes, {len(data["links"])} links, {len(data["rooms"])} rooms, '
          f'{len(data["niches"])} pockets, {len(data["puzzles"])} puzzles, {len(data["props"])} props, '
          f'{len(data["structures"])} structures')
