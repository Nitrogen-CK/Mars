"""Warrens r2: the authored layout behind data/warrens.json (run: python design_warrens_r2.py).

r1 was the atlas concept dressed as-is: a 40 m lattice of 4 m streets, every turn a right angle. r2 keeps the anchor
ids, the node names the tests use (K, S1-S5, H1, H2, RS) and the closure group, and redraws the space: about 140 x 110 m,
2.5 m bent tunnels around one 4 m spine, offset junctions, small irregular rooms between the three 30 x 24 m hunt
courts, a smaller Deep, optional crawl gaps and ladder galleries (never on a required route), and lighting that leaves
most of it dark. Metres; +X east, +Y north; z = floor height.
"""
import json
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent / 'data' / 'warrens_r2.json'  # superseded by design_warrens_v3.py
TUNNEL, CORRIDOR, SPINE = 2.5, 3.0, 4.0

NODES = {
    # Hearth chapel (west) and the spine running east from it.
    'K': (16, 58, 0), 'a1': (27, 60, 0), 'a2': (40, 56, 0), 'a3': (53, 59, 0),
    # North-west: the ossuary and its approach.
    'w1': (18, 79, 0), 'O': (36, 91, 0), 'n2': (51, 97, 0), 'n1': (66, 98, 0),
    # North-east: the shaft court and the east approach.
    'n3': (88, 101, 0), 'RS': (115, 87, 0), 'e2': (121, 68, 0), 'e1': (128, 58, 0),
    # Centre: the charnel court and the chime room.
    'H1': (68, 76, 0), 'CH': (94, 60, 0), 'm1': (84, 70, 0),
    # South: cistern, sluice, the south approach.
    'CI': (27, 24, 0), 'so1': (21, 12, 0), 'q1': (41, 36, 0), 'SL': (62, 31, 0), 'so3': (93, 12, 0),
    # The Deep (-5): its court and the loop around it.
    'd0': (84, 30, -5), 'H2': (106, 28, -5), 'd2': (126, 40, -5), 'd3': (116, 8, -5), 'd4': (90, 10, -5),
    # Foyers.
    'S1': (4, 80, 0), 'S2': (66, 106, 0), 'S3': (136, 58, 0), 'S4': (93, 3, 0), 'S5': (12, 4, 0),
}

# (a, b, via, width, kind, closedBy)
LINKS = [
    # Foyer mouths.
    ('S1', 'w1', [(10, 80)], CORRIDOR, 'walk', None),
    ('S2', 'n1', [], CORRIDOR, 'walk', None),
    ('S3', 'e1', [], CORRIDOR, 'walk', None),
    ('S4', 'so3', [], CORRIDOR, 'walk', None),
    ('S5', 'so1', [(15, 7)], CORRIDOR, 'walk', None),
    # The spine: chapel east door, bending through the middle to the charnel court's south door.
    ('K', 'a1', [(22, 58)], SPINE, 'walk', 'B-R1'),
    ('a1', 'a2', [(33, 57)], SPINE, 'walk', None),
    ('a2', 'a3', [(46, 60)], SPINE, 'walk', None),
    ('a3', 'H1', [(58, 63), (64, 66)], SPINE, 'walk', None),
    # North-west quarter.
    ('K', 'w1', [(13, 66), (19, 72)], TUNNEL, 'walk', 'B-R6'),
    ('w1', 'O', [(24, 85), (30, 85)], TUNNEL, 'walk', None),
    ('O', 'n2', [(44, 95)], TUNNEL, 'walk', None),
    ('n2', 'n1', [(58, 100)], CORRIDOR, 'walk', None),
    ('a2', 'O', [(38, 66), (34, 74), (37, 82)], TUNNEL, 'walk', None),
    ('n1', 'H1', [(66, 90)], CORRIDOR, 'walk', 'B-R2'),
    # North-east quarter.
    ('n1', 'n3', [(75, 103), (82, 99)], TUNNEL, 'walk', 'B-R5'),
    ('n3', 'RS', [(97, 98), (102, 92)], TUNNEL, 'walk', None),
    ('RS', 'e2', [(118, 75)], CORRIDOR, 'walk', None),
    ('e2', 'e1', [], CORRIDOR, 'walk', None),
    ('H1', 'm1', [(78, 74)], TUNNEL, 'walk', None),
    ('m1', 'CH', [(88, 64)], TUNNEL, 'walk', None),
    ('m1', 'n3', [(85, 82), (90, 90)], TUNNEL, 'walk', None),
    ('CH', 'e2', [(104, 62), (112, 66)], TUNNEL, 'walk', 'B-R4'),
    # South quarter.
    ('K', 'CI', [(14, 46), (20, 36), (24, 30)], TUNNEL, 'walk', None),
    ('so1', 'CI', [(24, 17)], TUNNEL, 'walk', None),
    ('CI', 'q1', [(34, 30)], TUNNEL, 'walk', None),
    ('q1', 'a2', [(42, 46)], TUNNEL, 'walk', None),
    ('q1', 'SL', [(50, 35), (56, 30)], CORRIDOR, 'walk', 'B-R3'),
    ('SL', 'so3', [(72, 22), (84, 14)], TUNNEL, 'walk', None),
    ('SL', 'a3', [(58, 42), (54, 50)], TUNNEL, 'walk', None),
    # Down into the Deep (straight ramps in the greybox).
    ('SL', 'd0', [], 3.0, 'stair', 'B-R7'),
    ('e1', 'd2', [], 3.0, 'stair', None),
    ('so3', 'd3', [], 3.0, 'stair', None),
    # The Deep: a loop around its court.
    ('d0', 'H2', [], 4.0, 'walk', None),
    ('H2', 'd2', [(122, 34)], 4.0, 'walk', None),
    ('d2', 'd3', [(131, 28), (128, 12)], 3.0, 'walk', None),
    ('d3', 'd4', [(104, 5)], 3.0, 'walk', None),
    ('d4', 'd0', [(84, 18)], 3.0, 'walk', None),
]

# Rooms: rect (x0, y0, x1, y1) at z; doors open wherever a link crosses the edge.
ROOMS = [
    dict(id='chapel', label='Lamp Chapel', rect=(9, 51, 23, 65), z=0, light='hearth'),
    dict(id='ossuary', label='Ossuary', rect=(30, 86, 42, 96), z=0, light=None),
    dict(id='court', label='Charnel Court', rect=(53, 64, 83, 88), z=0, light='cold'),
    dict(id='chimes', label='Chime Room', rect=(88, 55, 100, 65), z=0, light=None),
    dict(id='shaft', label='Root Shaft', rect=(100, 75, 130, 99), z=0, light='shaft'),
    dict(id='cistern', label='Cistern', rect=(21, 18, 33, 30), z=0, light=None),
    dict(id='sluice', label='Sluice', rect=(56, 26, 68, 36), z=0, light='dim'),
    dict(id='deepcourt', label='Deep Court', rect=(91, 16, 121, 40), z=-5, light='cold'),
]
FOYERS = {'S1': 'Expedition.Entrance.S1', 'S2': 'Expedition.Entrance.S2', 'S3': 'Expedition.Entrance.S3',
          'S4': 'Expedition.Entrance.S4', 'S5': 'Expedition.Entrance.S5'}
DEEP = (58, 2, 138, 60)
FOOTPRINT = (0, 0, 140, 110)

# Optional traversal, never in the plan graph: crouch gaps through a mass (1.3 m high, 1.5 m wide) and ladders up to
# +3 m galleries. The solve never relies on them, so they only ever add routes.
CRAWLS = [
    dict(id='crawl-ossuary-court', a=(42, 90), b=(53, 84), note='ossuary into the charnel court, behind its north wall'),
    dict(id='crawl-cistern-sluice', a=(33, 22), b=(56, 28), note='a long low drain beside the south tunnel'),
    dict(id='crawl-chimes-shaft', a=(100, 64), b=(108, 75), note='chime room up into the shaft court'),
]
GALLERIES = [
    dict(id='court-gallery', rect=(53, 84, 83, 88), z=3.0, ladder=dict(at=(58, 84.0), yaw=-90.0),
         note='a 4 m ledge along the charnel court north wall: see the whole floor before dropping in'),
    dict(id='shaft-gallery', rect=(126, 75, 130, 99), z=3.0, ladder=dict(at=(126.0, 84), yaw=180.0),
         note='east ledge of the shaft court, under the daylight'),
]
LIGHTS = [
    dict(at=(16, 58, 3.0), kind='hearth'),
    dict(at=(68, 76, 5.0), kind='cold'), dict(at=(115, 87, 6.0), kind='shaft'), dict(at=(106, 28, -1.5), kind='cold'),
    dict(at=(62, 31, 2.6), kind='dim'), dict(at=(40, 56, 2.6), kind='dim'),
]
ANCHOR_AT = {  # route anchors sit on their link; spawn anchors at the foyer mouth (the builder finds those)
    'B-R1': (21, 58), 'B-R2': (66, 92), 'B-R3': (50, 35), 'B-R4': (108, 64), 'B-R5': (78, 102), 'B-R6': (15, 68),
    'B-R7': None,
}
WALK, CLIMB = 4.2, 2.2


def polyline(a, b, via):
    return [NODES[a][:2]] + list(via) + [NODES[b][:2]]


def length(pts):
    return sum(math.dist(p, q) for p, q in zip(pts, pts[1:]))


def build():
    links = []
    for a, b, via, w, kind, closed in LINKS:
        cost = length(polyline(a, b, via))
        links.append(dict(a=a, b=b, via=[list(p) for p in via], width=w, kind=kind, closedBy=closed, costCm=int(round(cost * 100))))
    anchors = []
    for i in range(1, 6):
        anchors.append(dict(id=f'B-S{i}', family='S', at=list(NODES[f'S{i}'][:2]), node=f'S{i}', note='foyer'))
    for aid, node in (('B-H1', 'H1'), ('B-H2', 'H2'), ('B-H3', 'RS')):
        anchors.append(dict(id=aid, family='H', at=list(NODES[node][:2]), node=node, note='hunt court'))
    for l in LINKS:
        if l[5]:
            at = ANCHOR_AT[l[5]] or NODES[l[0]][:2]
            anchors.append(dict(id=l[5], family='R', at=list(at), node=l[0], note='route gate'))
    return dict(
        map='Warrens', revision='r2',
        source='Tools/LevelDesign/anchor_plans/design_warrens_r2.py (Warrens r2, 2026-10-16)',
        units='metres; costCm is the walk cost in centimetres', hearth='K',
        footprint=list(FOOTPRINT), deep=list(DEEP),
        nodes={k: list(v) for k, v in NODES.items()}, links=links,
        rooms=[dict(r, rect=list(r['rect'])) for r in ROOMS],
        crawls=[dict(c, a=list(c['a']), b=list(c['b'])) for c in CRAWLS],
        galleries=[dict(g, rect=list(g['rect'])) for g in GALLERIES],
        lights=[dict(l, at=list(l['at'])) for l in LIGHTS],
        groups=[dict(name='Warren', anchorIds=['B-R1', 'B-R2', 'B-R3', 'B-R4', 'B-R5', 'B-R6', 'B-R7'], maxClosed=3)],
        entrances=[dict(anchorId=f'B-S{i}', playerStartTag=FOYERS[f'S{i}'], node=f'S{i}') for i in range(1, 6)],
        courts=[dict(anchorId='B-H1', node='H1'), dict(anchorId='B-H2', node='H2'), dict(anchorId='B-H3', node='RS')],
        anchors=anchors,
        channels={f'B-R{i}': f'Mechanism.Channel.Anchor.Warrens.R{i}' for i in range(1, 8)},
        quarryMinWalkCm=5000,
    )


if __name__ == '__main__':
    data = build()
    OUT.write_text(json.dumps(data, indent=1), encoding='utf-8')
    print(f'wrote {OUT.name}: {len(data["nodes"])} nodes, {len(data["links"])} links, {len(data["rooms"])} rooms, '
          f'{len(data["crawls"])} crawls, {len(data["galleries"])} galleries')
