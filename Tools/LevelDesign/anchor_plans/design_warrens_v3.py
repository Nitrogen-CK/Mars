"""Warrens v3: the previous live layout, kept as data/warrens_v3.json (run: python design_warrens_v3.py).

r2 spread 140 x 110 m of mostly corridor around a hearth on the west edge. v3 folds the same anchors, node names and
closure group into 96 x 80 m on two stacked levels, Dark Souls style:
- the hearth chapel is the centre and every region bends back to it (four doors on the main floor);
- the Undercroft court (H2) lies directly under the hearth, reached by four stairs from four regions;
- rooms touch through short throats (no corridor run over 12 m); a gate only ever stands in a throat;
- each route gate has a crawl gap beside it, so a chef without a pack can scout past a closed route, but the pack
  goes the long way;
- the Root Shaft is the landmark: the one tall, lit space, with a gallery and a stair diving into the Undercroft.
Ramps dive under the main floor: past rampRoofZ they are roofed, so a corridor can cross over a stair.
Metres; +X east, +Y north; z = floor height.
"""
import json
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent / 'data' / 'warrens_v3.json'
TUNNEL, CORRIDOR = 2.5, 3.0

NODES = {
    # The hearth chapel, centre of the map.
    'K': (48, 40, 0),
    # West: the Charnel Court (hunt court H1) and its stair down.
    'H1': (17, 38, 0), 'c1': (16, 28, 0),
    # North: ossuary and reliquary.
    'O': (37, 62, 0), 'RQ': (56, 62, 0),
    # East: the Root Shaft (hunt court RS) and its stair down; the chime room below it.
    'RS': (79, 51, 0), 'r1': (72, 43, 0), 'CH': (78, 27, 0),
    # South: cistern, pump room (with the gated stair down), sluice (with its own stair down).
    'CI': (21, 12, 0), 'PU': (40, 14, 0), 'p1': (36, 21, 0), 'SL': (61, 16, 0), 'sx': (65, 22, 0),
    # The Undercroft (-5): its court under the hearth and the four stair feet.
    'H2': (58, 40, -5), 'd1': (40, 38, -5), 'd2': (54, 43, -5), 'd3': (34, 28, -5), 'd4': (70, 39, -5),
    # Foyers.
    'S1': (8, 61, 0), 'S2': (56, 76, 0), 'S3': (92, 27, 0), 'S4': (61, 4, 0), 'S5': (4, 8, 0),
}

# (a, b, via, width, kind, closedBy)
LINKS = [
    # Foyer mouths.
    ('S1', 'H1', [], CORRIDOR, 'walk', None),
    ('S2', 'RQ', [], CORRIDOR, 'walk', None),
    ('S3', 'CH', [], CORRIDOR, 'walk', None),
    ('S4', 'SL', [], CORRIDOR, 'walk', None),
    ('S5', 'CI', [], CORRIDOR, 'walk', None),
    # The hearth's four doors.
    ('K', 'H1', [(36, 40), (30, 39)], CORRIDOR, 'walk', 'R1'),
    ('K', 'RS', [(60, 48), (68, 50)], CORRIDOR, 'walk', 'R4'),
    ('K', 'O', [(46, 50), (42, 54)], TUNNEL, 'walk', None),
    ('K', 'PU', [(46, 30), (43, 22)], TUNNEL, 'walk', None),
    # The ring of regions.
    ('H1', 'O', [(24, 50), (28, 55)], TUNNEL, 'walk', None),
    ('O', 'RQ', [(44, 62), (50, 62)], CORRIDOR, 'walk', 'R5'),
    ('RQ', 'RS', [(62, 60), (68, 57)], TUNNEL, 'walk', None),
    ('H1', 'CI', [(12, 30), (10, 26), (16, 18)], TUNNEL, 'walk', 'R6'),
    ('CI', 'PU', [(28, 13), (34, 13)], TUNNEL, 'walk', None),
    ('PU', 'SL', [(46, 15), (54, 15)], CORRIDOR, 'walk', 'R3'),
    ('SL', 'CH', [(68, 19), (72, 24)], TUNNEL, 'walk', None),
    ('CH', 'RS', [(78, 33), (78, 40)], CORRIDOR, 'walk', 'R2'),
    # Room-internal walks to the stair heads.
    ('H1', 'c1', [], CORRIDOR, 'walk', None),
    ('PU', 'p1', [], CORRIDOR, 'walk', None),
    ('SL', 'sx', [], CORRIDOR, 'walk', None),
    ('RS', 'r1', [], CORRIDOR, 'walk', None),
    # Four stairs down into the Undercroft.
    ('c1', 'd3', [], 3.0, 'stair', None),
    ('p1', 'd1', [], 3.0, 'stair', 'R7'),
    ('sx', 'd4', [], 3.0, 'stair', None),
    ('r1', 'd2', [], 3.0, 'stair', None),
    # The Undercroft: four short tunnels into its court.
    ('d3', 'H2', [(40, 29)], TUNNEL, 'walk', None),
    ('d1', 'H2', [], TUNNEL, 'walk', None),
    ('d4', 'H2', [(62, 40)], TUNNEL, 'walk', None),
    ('d2', 'H2', [], CORRIDOR, 'walk', None),
]

ROOMS = [
    dict(id='chapel', label='Lamp Chapel', rect=(40, 32, 56, 48), z=0, light='hearth'),
    dict(id='court', label='Charnel Court', rect=(6, 26, 28, 50), z=0, light='cold'),
    dict(id='ossuary', label='Ossuary', rect=(30, 56, 44, 68), z=0, light=None),
    dict(id='reliquary', label='Reliquary', rect=(50, 56, 62, 68), z=0, light='dim'),
    dict(id='shaft', label='Root Shaft', rect=(68, 40, 90, 62), z=0, light='shaft'),
    dict(id='chimes', label='Chime Room', rect=(72, 22, 84, 32), z=0, light=None),
    dict(id='cistern', label='Cistern', rect=(14, 6, 28, 18), z=0, light=None),
    dict(id='pump', label='Pump Room', rect=(34, 8, 46, 20), z=0, light='dim'),
    dict(id='sluice', label='Sluice', rect=(54, 10, 68, 22), z=0, light=None),
    dict(id='undercroft', label='Undercroft', rect=(44, 28, 68, 52), z=-5, light='cold'),
    dict(id='vault', label='Vault', rect=(74, 45, 82, 51), z=-5, light=None),
]
FOYERS = {f'S{i}': f'Expedition.Entrance.S{i}' for i in range(1, 6)}
DEEP = (8, 18, 84, 56)  # covers every ramp, so solid rock lines each stair's sides
FOOTPRINT = (0, 0, 96, 80)
RAMP_ROOF_Z = -2.4  # a ramp is open to the main floor above this height and roofed below it

# One crawl gap beside each main-floor route gate (R1/R4 leave the hearth, so they get none: the hearth is reached
# with the pack, never squeezed into).
# packFits False: a worn backpack does not pass the 1.3 m lintel (a rule the build must add; without it a crawl is a
# free bypass of a closed gate).
CRAWLS = [
    dict(id='crawl-cistern-court', a=(22, 17), b=(16.5, 27), packFits=False, note='beside R6'),
    dict(id='crawl-ossuary-reliquary', a=(42, 66), b=(52, 66), packFits=False, note='beside R5'),
    dict(id='crawl-pump-sluice', a=(44, 11), b=(56, 12), packFits=False, note='beside R3'),
    dict(id='crawl-chimes-shaft', a=(82, 31), b=(84, 41), packFits=False, note='beside R2'),
]
GALLERIES = []  # v3 builds its galleries on the Rafters level (UPPER), not as free-standing ledges

# Elevation. The main floor is roofed at 4.6 m except the three tall rooms, which stay open to 9 m. The Rafters (+5)
# walk on that roof: a ledge in each tall room, and a loft hung over the hearth, joined by walkways that pass through
# ceiling holes into the Ossuary and the Reliquary. Like the crawls, none of it is in the plan graph: the solve never
# relies on it, so it only ever adds routes.
UPPER = dict(
    z=5.0, top=9.0, mainTop=4.6,
    tallRooms=['chapel', 'court', 'shaft'],
    platforms=[
        dict(id='court-gallery', rect=(6, 46, 28, 50), note='Charnel Court north ledge: watch the court before crossing it'),
        dict(id='shaft-gallery-n', rect=(68, 58, 90, 62), note='Root Shaft north ledge, end of the east Rafters'),
        dict(id='shaft-gallery-e', rect=(86, 40, 90, 58), note='Root Shaft east ledge, under its light'),
        dict(id='lamp-loft', rect=(44, 41, 52, 47), note='a loft hung over the hearth: the upper hub above the main hub above the lair'),
    ],
    walkways=[
        dict(id='rafters-w', pts=[(27, 49), (32, 53), (38, 55)], width=2.0, note='court ledge to the Ossuary ceiling hole'),
        dict(id='rafters-w2', pts=[(38, 55), (44, 51), (46, 47)], width=2.0, note='Ossuary hole to the loft'),
        dict(id='rafters-e', pts=[(50, 47), (54, 51), (57, 55)], width=2.0, note='loft to the Reliquary ceiling hole'),
        dict(id='rafters-e2', pts=[(57, 55), (64, 55), (68, 59)], width=2.0, note='Reliquary hole to the Root Shaft ledge'),
    ],
    railGaps=[
        dict(id='loft-drop', a=(50, 41), b=(52, 41), note='one-way drop from the loft to the hearth floor'),
        dict(id='court-drop', a=(20, 46), b=(22, 46), note='one-way drop from the ledge into the Charnel Court'),
        dict(id='shaft-drop', a=(80, 58), b=(82, 58), note='one-way drop from the north ledge into the Root Shaft'),
    ],
)
# Every ladder: foot (x, y, baseZ), +X (yaw) faces the climber, the landing is behind it. Height in metres.
LADDERS = [
    dict(id='ossuary-ladder', at=(38, 56), baseZ=0.0, height=5.0, yaw=90.0, note='up through the Ossuary ceiling'),
    dict(id='reliquary-ladder', at=(57, 56), baseZ=0.0, height=5.0, yaw=90.0, note='up through the Reliquary ceiling'),
    dict(id='undercroft-ladder', at=(36, 45), baseZ=-5.0, height=5.0, yaw=0.0, note='up from a niche off the d1 tunnel into the Chapel closet'),
]
# Openings in a floor. grate: bars you walk on and see through; open: a ladder well.
HOLES = [
    dict(id='chapel-grate', level='main', rect=(50, 34, 54, 37), kind='grate', note='the hearth floor looks down onto the rim of the lair'),
    dict(id='closet-well', level='main', rect=(36, 44.25, 37.5, 45.75), kind='open', note='the Undercroft ladder comes up here'),
    dict(id='ossuary-well', level='upper', rect=(37, 56, 39, 57.2), kind='open', note='ladder hole in the Ossuary ceiling'),
    dict(id='reliquary-well', level='upper', rect=(56, 56, 58, 57.2), kind='open', note='ladder hole in the Reliquary ceiling'),
]
# Walkable main-floor space outside the plan graph: the shortcut passages and the closet.
EXTRA_WALKS = [
    dict(id='closet', rect=(34, 43, 39, 47), note='a dark closet off the Chapel, over the Undercroft'),
    dict(id='sc2-door', pts=[(38.5, 45), (41, 45)], width=2.5, note='closet to Chapel, barred from the Chapel side'),
    dict(id='sc1-door', pts=[(55, 37), (66, 37), (73, 31)], width=2.5, note='Chime Room to Chapel, barred from the Chapel side'),
    dict(id='undercroft-niche', level='deep', pts=[(40, 38), (38, 43), (37.5, 45)], width=2.5, note='the d1 tunnel to the foot of the closet ladder'),
    dict(id='vault-passage', level='deep', pts=[(67, 48), (75, 48)], width=2.5, note='Undercroft to the Vault'),
]
# One-way shortcuts: a barred gate whose only lever is on leverSide (+1 = ahead along yaw, -1 = behind).
SHORTCUTS = [
    dict(id='SC1', at=(61, 37), yaw=180.0, spanCm=250.0, leverSide=-1, channel='Mechanism.Channel.Warrens.Shortcut.SC1',
         note='Chime Room → Chapel east door; seen through the bars from the hearth'),
    dict(id='SC2', at=(39.5, 45), yaw=0.0, spanCm=250.0, leverSide=-1, channel='Mechanism.Channel.Warrens.Shortcut.SC2',
         note='Undercroft ladder → closet → Chapel; the lair connects to the hearth once someone has climbed out'),
]
# Cracks: a slit through a thin wall, sill to head, too low and narrow to pass; you see, you cannot go.
CRACKS = [
    dict(id='nave-closet', a=(36, 41.25), b=(36, 43.25), width=0.5, sill=1.2, head=2.0,
         note='from the Nave, a glimpse of the closet and the cold light coming up its well'),
]
LIGHTS = [
    dict(at=(48, 40, 3.0), kind='hearth'), dict(at=(17, 38, 5.0), kind='cold'), dict(at=(79, 51, 9.0), kind='shaft'),
    dict(at=(58, 40, -1.5), kind='cold'), dict(at=(40, 14, 2.6), kind='dim'), dict(at=(56, 62, 2.6), kind='dim'),
]
# Cover: solid rects stamped after every walk, so a pillar that blocks a route shows up as a walk break.
PILLARS = [
    dict(level='main', rect=(10, 40, 13, 43)), dict(level='main', rect=(21, 32, 24, 35)),       # Charnel Court
    dict(level='main', rect=(82, 43, 85, 46)), dict(level='main', rect=(84, 55, 87, 58)),       # Root Shaft
    dict(level='deep', rect=(48, 44, 51, 47)), dict(level='deep', rect=(62, 44, 65, 47)),       # Undercroft
    dict(level='deep', rect=(52, 30, 55, 33)), dict(level='deep', rect=(62, 31, 65, 34)),
]
# Ring tunnels with a 2.2 m roof: the squeeze between rooms (rooms keep their 4.6 m).
LOW_LINKS = [('H1', 'O'), ('RQ', 'RS'), ('CI', 'PU'), ('SL', 'CH')]
LOW_ROOF = 2.2
# The vault: a barred door under the Root Shaft, opened by a red key that lies on the shaft's east ledge, reachable only
# over the Rafters. Off the plan graph.
LOCKS = [
    dict(id='vault', door=dict(at=(71, 48), yaw=0.0, spanCm=250.0, level='deep'), lock=dict(at=(69.5, 46.6), yaw=90.0, level='deep'),
         key='Red', keyAt=(88, 50, 5.0), channel='Mechanism.Channel.Keys.Red',  # the Sandbox red presets' channel
         note='bring the key down from the Rafters, through the lair, to the door'),
]
ANCHOR_AT = {
    'R1': (34, 40), 'R2': (78, 36), 'R3': (50, 15), 'R4': (63, 48.75), 'R5': (47, 62), 'R6': (13, 22),
    'R7': None,
}


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
        anchors.append(dict(id=f'S{i}', family='S', at=list(NODES[f'S{i}'][:2]), node=f'S{i}', note='foyer'))
    for aid, node in (('H1', 'H1'), ('H2', 'H2'), ('H3', 'RS')):
        anchors.append(dict(id=aid, family='H', at=list(NODES[node][:2]), node=node, note='hunt court'))
    for l in LINKS:
        if l[5]:
            at = ANCHOR_AT[l[5]] or NODES[l[0]][:2]
            anchors.append(dict(id=l[5], family='R', at=list(at), node=l[0], note='route gate'))
    return dict(
        map='Warrens', revision='v3',
        source='Tools/LevelDesign/anchor_plans/design_warrens_v3.py (Warrens v3 proposal, 2026-10-17)',
        units='metres; costCm is the walk cost in centimetres', hearth='K',
        footprint=list(FOOTPRINT), deep=list(DEEP), rampRoofZ=RAMP_ROOF_Z,
        nodes={k: list(v) for k, v in NODES.items()}, links=links,
        rooms=[dict(r, rect=list(r['rect'])) for r in ROOMS],
        crawls=[dict(c, a=list(c['a']), b=list(c['b'])) for c in CRAWLS],
        galleries=[dict(g, rect=list(g['rect'])) for g in GALLERIES],
        upper=UPPER, ladders=LADDERS, holes=HOLES, extraWalks=EXTRA_WALKS, shortcuts=SHORTCUTS, cracks=CRACKS,
        pillars=[dict(p, rect=list(p['rect'])) for p in PILLARS], lowLinks=[list(l) for l in LOW_LINKS], lowRoof=LOW_ROOF,
        locks=LOCKS,
        lights=[dict(l, at=list(l['at'])) for l in LIGHTS],
        groups=[dict(name='Warren', anchorIds=['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7'], maxClosed=3)],
        entrances=[dict(anchorId=f'S{i}', playerStartTag=FOYERS[f'S{i}'], node=f'S{i}') for i in range(1, 6)],
        courts=[dict(anchorId='H1', node='H1'), dict(anchorId='H2', node='H2'), dict(anchorId='H3', node='RS')],
        anchors=anchors,
        channels={f'R{i}': f'Mechanism.Channel.Anchor.Warrens.R{i}' for i in range(1, 8)},
        quarryMinWalkCm=5000,
    )


if __name__ == '__main__':
    data = build()
    OUT.write_text(json.dumps(data, indent=1), encoding='utf-8')
    print(f'wrote {OUT.name}: {len(data["nodes"])} nodes, {len(data["links"])} links, {len(data["rooms"])} rooms, '
          f'{len(data["crawls"])} crawls, {len(data["galleries"])} galleries')
