"""Warrens v5, "The Well": the LIVE layout, data/warrens.json (run: python design_warrens_v5.py).

Inspirations as rules: Dark Souls (a hub every route bends back to; loops that close on themselves once a shortcut is
found from the far side: kicked ladders, levers behind gates, drops), Legend of Grimrock (what opens a door is found
somewhere else on the map; pits and ladders join levels; a clue is read in one place and used in another). Crawl
spaces and ladders exist only where they do a job: a crawl reaches the lever on the far side of a route gate so the
carrier can bring the pack through; a ladder is a scout's shortcut or a loop that opens from above.

Shape, in metres (+X east, +Y north, z = floor height):
- The Lamp Chapel (hearth K, z 0) at the centre-west, four doors: Nave west to the Charnel Court (H1, z 0); east onto
  the rim of THE WELL; a stair north up to the Ossuary (+2.5); a stair south down to the Pump Room (-2.5).
- The Well: a 12 x 12 open shaft from the galleries (+9 roof) down to the Pit (H2, -5): the lair is under the hub,
  the whole map looks into it. A 4 m railed rim at z 0 rings it; the south rim is the sump stair down into the lair.
- The ring spirals: Ossuary and Reliquary north at +2.5 joined by a bridge over the well's north rim; the Chime Hall
  (H3) east at 0; the Sluice, Salt Cellar and Pump Room south at -2.5; the Cistern south-west at -2.5; the Court west
  at 0. Rooms touch through throats; route gates R1..R7 stand only in throats or stair heads.
- The Galleries (+5) ride the roof of the z-0 rooms: a loft over the hearth, a west gallery, a north gallery and an
  east gallery round the well. Up: the Ossuary's gallery stair. Down: three drops (loft -> hearth, west -> chapel,
  east -> chime throat) and the Chime ladder, which hangs raised until someone kicks it from the gallery.
- The Undercroft (-5): the lair round the Pit, the Vault off its north-east (Red key door; the key lies on the east
  gallery, seen from the chapel's east door across the well), the closet ladder up into the hub (barred from the
  chapel side: the lair's one-way home), and the Drowned Gallery to the Cistern's foot, flooded until the Sluice
  hand-wheel is turned.
Plan-graph changes vs v3: nodes and links are new (the emitted plan and the solver tests' distances must be
recomputed); the anchor ids S1..S5, H1..H3, R1..R7 and the closure group are kept, so the registered tags stay.

Round 2 (after the topology / puzzles / metrics reviews, docs/design/expedition-maps-r02/warrens-v5/reviews/):
- the Drowned Gallery left the plan graph (the solver counted it open: {R3,R4,R5} was an unwinnable run); P2 is now a
  hand-wheel opening a latched grate at the gallery's Pit mouth, with knee-deep water as dressing (no water tech);
- R4 moved from the hearth's east door to the rim's south-west segment: no closure set islands the rim, the well is
  always seen from the hearth; 64/64 sets stay legal;
- every stair starts and ends at a room edge (door nodes kn/ks/o0/rq1/ch0/p1), so no tread strip crosses a room; the
  court is a 0-level rim round a -1.5 arena with three 4 m stairs, H1 at arena height;
- the Bridge touches the north rim and is open above; the key sits on a lit plinth at the gallery rail; the glyph
  hangs on the well wall; the Chime ladder stands in the hall with a barred foot (lever on the gallery) instead of a
  kick; its drop lands in the hall; the loft drop is cut; crawls carry their height; R6 sits by its stair foot;
- spawns moved out of the hunt radii (S1 north, S3 south, S5 east of the basin); pack plinths at every court;
  the Pit's sump tunnel no longer runs under its own stair; the Mourner plate is in the Ossuary, 35 m from its gate.
Round 3 (the build, 2026-10-19; each item is a thing the builder could not realise as drawn, listed in
docs/plans/warrens-v5-build/PROGRESS.md as a deviation):
- the closet, its well, its ladder, the SC2 door and P6 moved 1 m east: the ks-p1 stair treads clipped the closet's west
  column, so SC2 was bypassable up the stair;
- the Mourner niche moved 2 m east (76..82) and P3's gate with it: the S2 corridor (x 71.5..74.5) ran into its west edge;
- crawl-r6 now runs from the court's south-east corner (25, 30.5) down to the Cistern's north wall (27, 21.5): the old line
  lay inside the c1-ci2 stair's treads, two floors in one cell;
- two pillars stood on walk lines (CH-ch1 in the Chime Hall, d4-H2 in the Pit) and moved off them;
- the east gallery drop moved 2 m north (y 52..54): the barred ladder's foot needs a 2.5 m cage, and the drop landed on it;
- the Sluice door sill node is sl1, not s1: node ids are FNames, which compare case-insensitively, so s1 was the entrance S1;
- the d4-H2 tunnel runs on in the stair's direction, then east round its foot (via (69.4, 21), (74.5, 21), (74.5, 33)): it ran under the ramp's last 6 m with
  under a metre of headroom (the audit's standing capsule hit the ramp); the reliquary tomb moved off the RQ node to (76, 68); the third well root off the d4-H2 line to (63.5, 38.5).
Ruling (maintainer, 2026-10-19): a worn pack rides a ladder. So the closet ladder and the Chime ladder are the two
pack-rewarding home runs (Dark Souls shortcuts): once opened from their far side they let the pack skip R7/R4 and
R2/R4 for the rest of the run. That is intended; the route gates shape the way OUT, the shortcuts shape the way HOME.
"""
import json
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent / 'data' / 'warrens.json'
TUNNEL, CORRIDOR = 2.5, 3.0
UP, DOWN = 2.5, -2.5

NODES = {
    'K': (40, 44, 0), 'kn': (40, 52.5, 0), 'ks': (42, 35.5, 0),               # the hearth and its north/south door sills
    # The court: a 0-level rim (h0 east, c3 north, s0 south, c2 north-east) round a -1.5 arena (H1, p0, p3, ps)
    'H1': (16, 42, -1.5), 'p0': (24, 43, -1.5), 'p3': (12, 49.5, -1.5), 'ps': (18, 34, -1.5),
    'h0': (28, 43, 0), 'c3': (12, 55, 0), 's0': (18, 30.5, 0), 'c1': (13, 30, 0), 'c2': (24, 55, 0),
    'O': (41, 67, UP), 'o0': (40, 61, UP), 'o1': (34, 63, UP), 'BR': (60, 60, UP), 'RQ': (73, 68, UP), 'rq1': (78, 62, UP),
    'wW': (52, 44, 0), 'wN': (60, 51.5, 0), 'wE': (68, 44, 0), 'wS': (60, 36.5, 0),
    'CH': (84, 48, 0), 'ch0': (84, 56, 0), 'ch1': (73, 39, 0), 'ch2': (84, 38, 0),
    'PU': (51, 17, DOWN), 'p1': (46, 24, DOWN), 'CE': (65, 14, DOWN), 'SL': (79, 16, DOWN), 'sl1': (84, 23, DOWN),
    'CI': (34, 19, DOWN), 'ci1': (38, 16, DOWN), 'ci2': (18, 22.5, DOWN),
    'H2': (60, 44, -5), 'd2': (60, 19, -5), 'd4': (70, 24, -5), 'dg': (48, 22, -5),
    'S1': (4, 62, 0), 'S2': (73, 82, UP), 'S3': (100, 34, 0), 'S4': (51, 3, DOWN), 'S5': (34, 3, DOWN),
}

# (a, b, via, width, kind, closedBy)
LINKS = [
    ('S1', 'c3', [(8, 62), (11, 57)], CORRIDOR, 'walk', None),
    ('S2', 'RQ', [], CORRIDOR, 'walk', None),
    ('S3', 'CH', [(100, 39), (95, 42)], CORRIDOR, 'walk', None),
    ('S4', 'PU', [], CORRIDOR, 'walk', None),
    ('S5', 'CI', [], CORRIDOR, 'walk', None),
    # the hearth's four doors
    ('K', 'h0', [(31, 44)], CORRIDOR, 'walk', 'R1'),
    ('K', 'wW', [(49, 44)], CORRIDOR, 'walk', None),
    ('K', 'kn', [], CORRIDOR, 'walk', None), ('kn', 'o0', [], CORRIDOR, 'stair', None), ('o0', 'O', [], CORRIDOR, 'walk', None),
    ('K', 'ks', [], CORRIDOR, 'walk', None), ('ks', 'p1', [], CORRIDOR, 'stair', None),
    # the well rim
    ('wW', 'wN', [(52, 51.5)], CORRIDOR, 'walk', None),
    ('wN', 'wE', [(68, 51.5)], CORRIDOR, 'walk', None),
    ('wE', 'wS', [(68, 36.5)], CORRIDOR, 'walk', None),
    ('wS', 'wW', [(52, 36.5)], CORRIDOR, 'walk', 'R4'),  # R4 on the rim's south-west, not on the hearth's door: the well is always seen from the hearth
    ('wE', 'CH', [(70, 46), (74, 46)], CORRIDOR, 'walk', 'R2'),
    ('wS', 'd2', [(60, 34)], 4.0, 'stair', 'R7'),
    # west: the court: rim nodes, the steps down into the arena, the ways out
    ('h0', 'p0', [], 4.0, 'stair', None), ('c3', 'p3', [], 4.0, 'stair', None), ('s0', 'ps', [], 3.0, 'stair', None),
    ('p0', 'H1', [], CORRIDOR, 'walk', None), ('p3', 'H1', [], CORRIDOR, 'walk', None), ('ps', 'H1', [], CORRIDOR, 'walk', None),
    ('h0', 'c2', [(28, 52)], CORRIDOR, 'walk', None), ('c3', 'c2', [], CORRIDOR, 'walk', None), ('s0', 'c1', [], CORRIDOR, 'walk', None),
    ('c1', 'ci2', [], CORRIDOR, 'stair', 'R6'),
    ('c2', 'o1', [], CORRIDOR, 'stair', None),
    ('o1', 'O', [], CORRIDOR, 'walk', None),
    # north: ossuary, bridge, reliquary
    ('O', 'BR', [(48, 68), (52, 64)], CORRIDOR, 'walk', 'R5'),
    ('BR', 'RQ', [(66, 62), (68, 66)], TUNNEL, 'walk', None),
    ('RQ', 'rq1', [], CORRIDOR, 'walk', None), ('rq1', 'ch0', [], CORRIDOR, 'stair', None), ('ch0', 'CH', [], CORRIDOR, 'walk', None),
    # east: the chime hall
    ('CH', 'ch1', [(76, 41)], CORRIDOR, 'walk', None),
    ('CH', 'ch2', [], CORRIDOR, 'walk', None),
    ('ch1', 'd4', [], 4.0, 'stair', None),
    ('ch2', 'sl1', [], CORRIDOR, 'stair', None),
    # south: sluice, cellar, pump, cistern
    ('sl1', 'SL', [], CORRIDOR, 'walk', None),
    ('SL', 'CE', [(72, 17), (68, 14)], CORRIDOR, 'walk', None),
    ('CE', 'PU', [(62, 17), (58, 17)], CORRIDOR, 'walk', 'R3'),
    ('PU', 'p1', [], CORRIDOR, 'walk', None),
    ('PU', 'CI', [(44, 15), (39, 16)], TUNNEL, 'walk', None),
    ('CI', 'ci2', [(22, 18.5)], TUNNEL, 'walk', None),
    ('CI', 'ci1', [], CORRIDOR, 'walk', None),
    ('ci1', 'dg', [], CORRIDOR, 'stair', None),
    # the undercroft: the sump tunnel swings east so it never runs under its own stair; the chime stair lands at the south-east corner
    ('d2', 'H2', [(63.5, 21), (63.5, 30)], TUNNEL, 'walk', None),
    ('d4', 'H2', [(69.4, 21), (74.5, 21), (74.5, 33)], TUNNEL, 'walk', None),  # r3: on in the stair's direction, then east round its foot; the old line ran under the ramp with no headroom
    # NOT a plan link: the Drowned Gallery (dg -> the Pit) is puzzle-gated (P2), so the solver never counts on it; see EXTRA_WALKS
]

ROOMS = [
    dict(id='chapel', label='Lamp Chapel', poly=[(34, 35), (46, 35), (49, 38), (49, 50), (46, 53), (34, 53), (31, 50), (31, 38)], z=0, light='hearth'),
    dict(id='closet', label='', rect=(45, 31, 51, 35), z=0),  # r3: 1 m east of the ks-p1 stair, which clipped its corner
    dict(id='court', label='Charnel Court', poly=[(6, 32), (10, 30), (26, 30), (28, 34), (28, 54), (24, 56), (8, 56), (6, 52)], z=0, light='cold'),
    dict(id='court-pit', label='', rect=(9, 34, 24, 50), z=-1.5),
    dict(id='ossuary', label='Ossuary', rect=(34, 61, 48, 73), z=UP, light=None),
    dict(id='bridge', label='Bridge', rect=(54, 53, 66, 64), z=UP, light=None),  # touches the north rim: its south edge stands 2.5 m over the rim, the well beyond
    dict(id='reliquary', label='Reliquary', rect=(66, 62, 80, 74), z=UP, light='dim'),
    dict(id='rimW', label='', rect=(50, 35, 54, 53), z=0), dict(id='rimE', label='', rect=(66, 35, 70, 53), z=0),
    dict(id='rimN', label='The Well', rect=(50, 50, 70, 53), z=0), dict(id='rimS', label='', rect=(50, 35, 70, 38), z=0),
    dict(id='chime', label='Chime Hall', poly=[(74, 38), (94, 38), (94, 58), (86, 58), (74, 54)], z=0, light=None),
    dict(id='pump', label='Pump Room', rect=(44, 10, 58, 24), z=DOWN, light='dim'),
    dict(id='cellar', label='Salt Cellar', rect=(60, 8, 70, 20), z=DOWN, light=None),
    dict(id='sluice', label='Sluice', rect=(72, 10, 86, 22), z=DOWN, light='dim'),
    dict(id='cistern', label='Cistern', rect=(22, 8, 38, 22), z=DOWN, light=None),
    dict(id='lair', label='The Pit', rect=(48, 28, 72, 58), z=-5, light='cold'),
    dict(id='vault', label='Vault', rect=(74, 56, 82, 62), z=-5, light=None),
]
FOYERS = {f'S{i}': f'Expedition.Entrance.S{i}' for i in range(1, 6)}
DEEP = (20, 6, 96, 68)
FOOTPRINT = (0, 0, 104, 88)
RAMP_ROOF_Z = -2.4

CRAWLS = [
    dict(id='crawl-r2', a=(69.5, 41), b=(74.5, 41), z=0, packFits=False, note='beside R2', purpose='reach the R2 lever on the Chime side; the pack waits on the rim'),
    dict(id='crawl-r3', a=(56, 21.5), b=(62, 19.5), z=DOWN, packFits=False, note='beside R3', purpose='reach the R3 lever in the Salt Cellar; the pack waits in the Pump Room'),
    dict(id='crawl-r5', a=(47, 63), b=(55, 60), z=UP, packFits=False, note='beside R5', purpose='reach the R5 lever on the Bridge; the pack waits in the Ossuary'),
    dict(id='crawl-r6', a=(25, 30.5), b=(27, 21.5), z=0, packFits=False, note='beside R6; ends 2.5 m above the Cistern floor: a one-way drop', purpose='reach the R6 lever by the stair foot; the scout drops into the Cistern, the pack comes down the stair'),
    dict(id='crawl-sealed', a=(93.5, 56), b=(98.5, 58.5), z=0, packFits=False, note='a gap behind the Chime Hall\'s east wall', purpose='the one squeeze that leads somewhere new: the Sealed Burial, a cache room no gate or stair reaches (Deep Dish Dungeon\'s hidden regions)'),
]
GALLERIES = []

UPPER = dict(
    z=5.0, top=9.0, mainTop=4.6,
    tallRooms=['chapel', 'court', 'chime', 'rimW', 'rimE', 'rimN', 'rimS', 'ossuary', 'bridge', 'reliquary'],  # the +2.5 wing is open above too: nothing at +5 sits over it
    platforms=[
        dict(id='loft', rect=(36, 40, 44, 48), note='the loft over the hearth'),
        dict(id='gNW', rect=(30, 50, 36, 54), note='landing of the Ossuary gallery stair, over the chapel\'s north-west'),
        dict(id='gW', rect=(48, 34, 52, 54), note='west gallery over the rim'),
        dict(id='gN', rect=(48, 50, 72, 53), note='north gallery over the north rim; the bridge looks under it into the well'),
        dict(id='gE', rect=(68, 34, 74, 54), note='east gallery: the Red key on a lit plinth at its west rail, seen from the chapel door across the well'),
    ],
    walkways=[
        dict(id='gNW-loft', pts=[(33, 50), (36, 47), (38, 46)], width=2.0, note='landing to the loft'),
        dict(id='loft-gW', pts=[(44, 44), (48, 44)], width=2.0, note='loft to the west gallery'),
    ],
    railGaps=[
        dict(id='gW-drop', a=(48, 46), b=(48, 48), note='drop from the west gallery into the chapel: the gallery ring ends at the hearth'),
        dict(id='gE-drop', a=(74, 52), b=(74, 54), note='drop from the east gallery into the Chime Hall, beside the barred ladder cage'),
    ],
)
LADDERS = [
    dict(id='closet-ladder', at=(50, 33), baseZ=-5.0, height=5.0, yaw=0.0, note='from the lair\'s west wall up into the chapel closet',
         purpose='the lair\'s one-way way home, pack included (ruling 2026-10-19: a worn pack rides a ladder): 17 m to the hearth against 71+ m by the gates; whoever climbs out opens SC2 for everyone'),
    dict(id='chime-ladder', at=(74.0, 50), baseZ=0.0, height=5.0, yaw=0.0, kind='barred', note='Chime Hall up to the east gallery; its foot is barred (latched gate) until the lever on the gallery is pulled',
         purpose='once opened from above, the east loop closes on itself for chefs and pack alike: chime -> ladder -> galleries -> west drop -> hearth, ~41 m against 60-94 m by the gates'),
]
HOLES = [
    dict(id='well', level='main', rect=(54, 38, 66, 50), kind='open', rail=0.6, note='the Well: rim at 0, Pit at -5, galleries at +5; a 0.6 m parapet so the Pit is seen from the rim'),
    dict(id='closet-well', level='main', rect=(49.5, 32.25, 51, 33.75), kind='open', note='the closet ladder comes up here'),
]
EXTRA_WALKS = [
    dict(id='sc2-door', pts=[(46, 34), (46, 36)], width=2.5, note='closet to chapel, barred from the chapel side'),
    dict(id='vault-passage', level='deep', pts=[(71, 59), (74, 59)], width=2.5, note='lair to the vault door'),
    dict(id='drowned-gallery', level='deep', pts=[(48, 22), (50, 24), (52, 30)], width=2.5, note='the Drowned Gallery: a knee-deep tunnel from the Cistern stair to the Pit, barred at the Pit mouth by the sluice grate (P2); off the plan graph'),
]
EXTRA_RAMPS = [
    dict(id='gallery-stair', a=(36, 62, UP), b=(33, 53.5, 5.0), width=3.0, note='Ossuary up to the galleries'),  # lands on gNW
]
SHORTCUTS = [
    dict(id='SC2', at=(46, 35), yaw=90.0, spanCm=250.0, leverSide=-1, channel='Mechanism.Channel.Warrens.Shortcut.SC2',
         note='closet -> chapel; lever in the closet: the lair connects to the hearth once someone has climbed out'),
]
CRACKS = []
LIGHTS = [
    dict(at=(40, 44, 3.0), kind='hearth'), dict(at=(60, 46, 8.0), kind='shaft'), dict(at=(16, 43, 5.0), kind='cold'),
    dict(at=(60, 40, -1.0), kind='cold'), dict(at=(73, 68, 5.1), kind='dim'), dict(at=(51, 17, 0.1), kind='dim'), dict(at=(79, 16, 0.1), kind='dim'),
    dict(at=(70, 41, 5.6), kind='dim'),   # the key plinth
    dict(at=(84, 48, 6.0), kind='cold'),  # the Chime Hall is 20 m: unlit it is a void
    dict(at=(28, 13, -0.5), kind='dim'),  # the Cistern
]
PILLARS = [
    dict(level='main', rect=(10, 36, 13, 39)), dict(level='main', rect=(22, 46, 25, 49)),      # court
    dict(level='main', rect=(77, 50, 80, 53)), dict(level='main', rect=(88, 52, 91, 55)),      # chime hall (r3: the first was on the CH-ch1 walk line)
    dict(level='deep', rect=(52, 32, 55, 35)), dict(level='deep', rect=(65, 33, 68, 36)),      # the pit's rim (r3: the second sat on the d4-H2 tunnel line, twice)
    dict(level='deep', rect=(50, 52, 53, 55)), dict(level='deep', rect=(68, 52, 71, 55)),
]
LOW_LINKS = [('BR', 'RQ'), ('d4', 'H2'), ('dg', 'H2'), ('PU', 'CI')]
LOW_ROOF = 2.2
LOCKS = [
    dict(id='vault', door=dict(at=(73, 59), yaw=0.0, spanCm=250.0, level='deep'), lock=dict(at=(72, 57.3), yaw=90.0, level='deep'),
         key='Red', keyAt=(68.3, 42, 5.3), channel='Mechanism.Channel.Keys.Red',
         note='the key on a lit plinth at the east gallery rail, 10 m above the pit; up the Ossuary stair, round the galleries, down a drop, down to the lair'),
]
# The fixed puzzle layer: the thing, and what it needs, elsewhere.
PUZZLES = [
    dict(id='P1', kind='Red key door', at=(73, 59, -5), needsAt=(68.3, 42, 5), needsNote='the key on a lit plinth at the east gallery rail, seen across the well from the chapel door'),
    dict(id='P2', kind='sluice grate (latched bars) at the Drowned Gallery mouth', at=(52, 29, -5), needsAt=(84, 13, DOWN), needsNote='the Sluice hand-wheel opens it; a dry channel in the Pump Room floor runs from the wheel toward the Cistern as the tell', existing='hand-wheel + latched Bars gate (no water simulation)'),
    dict(id='P3', kind='Mourner cache gate (latched)', at=(78, 74, UP), needsAt=(44, 72, UP), needsNote='the pack plate in the Ossuary, 35 m away: the carrier sets the pack down once and the gate latches open', latch=True),
    dict(id='P4', kind='Bellkeeper seal pair', at=(89, 58, 0), needsAt=(60, 54, UP), needsNote='the glyph order is painted on the well south wall, read from the Bridge edge'),
    dict(id='P5', kind='barred ladder foot (Chime Hall)', at=(74, 50, 0), needsAt=(71, 50, 5), needsNote='a lever on the east gallery opens the bars at its foot', existing='fixed ladder + latched Bars gate + lever (no kick-ladder tech)'),
    dict(id='P6', kind='SC2 barred closet door', at=(46, 35, 0), needsAt=(49, 33, -5), needsNote='climb the closet ladder out of the lair; the lever is on the closet side'),
]
NICHES = [
    dict(id='court-pack', rect=(8, 56, 12, 59), z=0, family='P', note='pack plinth at the S1 mouth'),
    dict(id='court-forage', rect=(2, 36, 6, 40), z=0, family='F', note='mushrooms in the west burial niche'),
    dict(id='court-omen', rect=(28, 50, 30, 52), z=0, family='O', note='eyes in the east wall niche'),
    dict(id='court-threat', rect=(20, 26, 24, 30), z=0, family='T', note='sentry alcove south of the arena'),
    dict(id='ossuary-husk', rect=(36, 73, 40, 76), z=UP, family='F', note='husk spill in the north niche'),
    dict(id='ossuary-rest', rect=(30, 64, 34, 67), z=UP, family='N', note='lantern rest by the gallery stair'),
    dict(id='bridge-omen', rect=(59, 64, 61, 66), z=UP, family='O', note='swaying chains over the bridge'),
    dict(id='mourner', rect=(76, 74, 82, 78), z=UP, family='C', note='Mourner cache behind the pack-plate gate (P3)'),
    dict(id='reliquary-omen', rect=(80, 66, 82, 70), z=UP, family='O', note='lamp bank that gutters out'),
    dict(id='reliquary-rest', rect=(66, 74, 70, 77), z=UP, family='N', note='lantern rest by the S2 mouth'),
    dict(id='bellkeeper', rect=(86, 58, 92, 62), z=0, family='C', note='Bellkeeper\'s Confession behind the seal pair (P4)'),
    dict(id='chime-threat', rect=(86, 34, 90, 38), z=0, family='T', note='sentry niche south of the hall'),
    dict(id='chime-pack', rect=(90, 34, 94, 38), z=0, family='P', note='pack plinth 14 m from the court centre, by the S3 way in'),
    dict(id='chime-rest', rect=(94, 50, 97, 53), z=0, family='N', note='lantern rest in the east wall'),
    dict(id='sealed-burial', rect=(98, 56, 103, 62), z=0, family='C', note='the Sealed Burial: reached only through crawl-sealed; a tool cache or a Bellkeeper reliquary'),
    dict(id='cellar-salt', rect=(62, 20, 66, 23), z=DOWN, family='F', note='salt crystals: the cellar is the forage room'),
    dict(id='cellar-vents', rect=(66, 5, 70, 8), z=DOWN, family='X', note='steam vent pair in the south niche'),
    dict(id='porter', rect=(86, 10, 94, 16), z=DOWN, family='C', note='Porter\'s Wager: the dead-end freight niche'),
    dict(id='sluice-rest', rect=(72, 22, 76, 25), z=DOWN, family='N', note='lantern rest at the Sluice north wall'),
    dict(id='sluice-threat', rect=(76, 6, 80, 10), z=DOWN, family='T', note='sentry niche south of the sluice'),
    dict(id='pump-omen', rect=(40, 12, 44, 15), z=DOWN, family='O', note='swaying chains in the west niche'),
    dict(id='pit-pack', rect=(44, 28, 48, 32), z=-5, family='P', note='pack plinth at the Pit south-west, outside the home radius'),
    dict(id='pump-trap', rect=(54, 24, 58, 27), z=DOWN, family='X', note='spike tiles on the north niche'),
    dict(id='cistern-forage', rect=(18, 10, 22, 14), z=DOWN, family='F', note='mushroom bed across the basin'),
    dict(id='pit-rest', rect=(44, 40, 48, 44), z=-5, family='N', note='lantern rest at the lair\'s west wall'),
    dict(id='pit-forage', rect=(72, 34, 76, 38), z=-5, family='F', note='deep mushrooms'),
    dict(id='pit-omen', rect=(56, 58, 58, 60), z=-5, family='O', note='the inner wall niche'),
]
WATER = [
    dict(id='cistern-basin', rect=(22, 9, 32, 17), z=DOWN, depth=0.5, note='the Cistern pool'),
    dict(id='drowned-gallery', rect=(46, 18, 53, 28), z=-5, depth=0.5, note='the Drowned Gallery: knee-deep, slow; the sluice grate (P2) is what closes it'),
]
PROPS = [
    dict(kind='statue', at=(16, 55, 0), size=(2.0, 1.2, 4.5), yaw=-90, note='split mourner: the court landmark, seen from the Nave door'),
    dict(kind='bench', at=(36, 51, 0), size=(2.0, 0.8, 0.9), note='cutting bench'),
    dict(kind='station', at=(41, 51.5, 0), size=(1.6, 1.0, 1.0), note='searing station'),
    dict(kind='station', at=(45, 51, 0), size=(1.4, 0.8, 0.9), note='platter rack'),
    dict(kind='plinth', at=(33, 44, 0), size=(1.2, 1.2, 0.3), note='pack plinth by the Nave door'),
    dict(kind='stack', at=(39, 64, UP), size=(6.0, 1.0, 2.6), note='bone stacks: the aisle maze'),
    dict(kind='stack', at=(43, 67.5, UP), size=(6.0, 1.0, 2.6)),
    dict(kind='stack', at=(39, 71, UP), size=(6.0, 1.0, 2.6)),
    dict(kind='sarcophagus', at=(76, 68, UP), size=(3.0, 1.5, 1.2), note='the reliquary tomb'),  # r3: off the RQ node, which every reliquary walk crosses
    dict(kind='plinth', at=(44, 72, UP), size=(2.0, 2.0, 0.3), note='the pack plate (P3), at the far end of the Ossuary'),
    dict(kind='plinth', at=(68.3, 42, 5.0), size=(0.8, 0.8, 0.3), note='the key plinth at the gallery rail (P1)'),
    dict(kind='station', at=(52, 29, -5), size=(2.6, 0.3, 2.5), note='the sluice grate (P2): latched bars across the gallery mouth'),
    dict(kind='stack', at=(58, 15.5, DOWN), size=(24.0, 0.8, 0.2), note='the dry sluice channel in the floor, from the wheel toward the Cistern (P2 tell)'),
    dict(kind='root', at=(55, 39, -5), size=(1.4, 1.4, 14.0), note='roots down the well'),
    dict(kind='root', at=(65, 49, -5), size=(1.0, 1.0, 14.0)),
    dict(kind='root', at=(63.5, 38.5, -5), size=(1.2, 1.2, 14.0)),  # r3: off the d4-H2 tunnel line
    dict(kind='stack', at=(60, 38.25, -2.2), size=(4.0, 0.3, 2.0), note='the glyph clue painted on the well south wall (P4), read from the Bridge'),
    dict(kind='chimes', at=(84, 48, 0), size=(6.0, 0.2, 3.5), yaw=0, note='bone chimes across the hall: the native trap'),
    dict(kind='station', at=(89, 57, 0), size=(1.0, 0.4, 1.4), note='the seal pair (P4)'),
    dict(kind='pillar', at=(47, 12, DOWN), size=(2.0, 2.0, 3.2), note='the pump: the south\'s audio landmark'),
    dict(kind='pillar', at=(84, 13, DOWN), size=(1.0, 1.0, 1.6), note='the hand-wheel: drains the Drowned Gallery (P2)'),
    dict(kind='stack', at=(64, 12, DOWN), size=(2.0, 2.0, 1.4), note='salt crystals'),
    dict(kind='candles', at=(37, 38, 0), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(46, 72, UP), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(36, 20, DOWN), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(76, 56, 0), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(50, 56, -5), size=(0.9, 0.9, 0.5), note='tallow'),
]
ANCHOR_AT = {'R1': (30, 44), 'R2': (72, 46), 'R3': (59, 17), 'R4': (52, 38), 'R5': (50, 66), 'R6': (17, 26), 'R7': None}
# The node on whose side a one-sided lever gate puts its lever: the far side of the crawl beside it (a chef crawls through,
# pulls, the pack follows). Gates without a crawl have none and never draw the one-sided row.
LEVER_NODE = {'R2': 'CH', 'R3': 'CE', 'R5': 'BR', 'R6': 'ci2'}
MAX_ACTIVE_CACHES = 2


def pocket_anchor_id(niche_id):
    """'court-forage' -> 'CourtForage': the tag leaf Anchor.Mars.Warrens.<leaf> and its GameplayTags accessor."""
    return ''.join(part[:1].upper() + part[1:] for part in niche_id.split('-'))  # R6 by the stair foot so its lever is on the Cistern side


def polyline(a, b, via):
    return [NODES[a][:2]] + list(via) + [NODES[b][:2]]


def length(pts):
    return sum(math.dist(p, q) for p, q in zip(pts, pts[1:]))


def build():
    links = []
    for a, b, via, w, kind, closed in LINKS:
        cost = length(polyline(a, b, via))
        if kind == 'stair':
            cost = math.hypot(cost, abs(NODES[a][2] - NODES[b][2]))
        links.append(dict(a=a, b=b, via=[list(p) for p in via], width=w, kind=kind, closedBy=closed, costCm=int(round(cost * 100)),
                          leverNode=LEVER_NODE.get(closed) if closed else None))
    anchors = []
    for i in range(1, 6):
        anchors.append(dict(id=f'S{i}', family='S', at=list(NODES[f'S{i}'][:2]), node=f'S{i}', note='foyer'))
    for aid, node in (('H1', 'H1'), ('H2', 'H2'), ('H3', 'CH')):
        anchors.append(dict(id=aid, family='H', at=list(NODES[node][:2]), node=node, note='hunt court'))
    for l in LINKS:
        if l[5]:
            at = ANCHOR_AT[l[5]] or NODES[l[0]][:2]
            anchors.append(dict(id=l[5], family='R', at=list(at), node=l[0], note='route gate'))
    for l in LINKS:
        if l[5] and LEVER_NODE.get(l[5]) and LEVER_NODE[l[5]] not in (l[0], l[1]):
            raise SystemExit(f'lever node of {l[5]} is not an end of its link')
    niches = [dict(n, rect=list(n['rect']), anchorId=pocket_anchor_id(n['id'])) for n in NICHES]
    return dict(
        map='Warrens', revision='v5r4',
        source='Tools/LevelDesign/anchor_plans/design_warrens_v5.py (Warrens v5 The Well, round 4: lever sides, pocket anchors and the cache budget, 2026-10-19)',
        units='metres; costCm is the walk cost in centimetres', hearth='K',
        footprint=list(FOOTPRINT), deep=list(DEEP), rampRoofZ=RAMP_ROOF_Z,
        nodes={k: list(v) for k, v in NODES.items()}, links=links,
        rooms=[dict(r, rect=list(r['rect'])) if 'rect' in r else dict(r, poly=[list(p) for p in r['poly']]) for r in ROOMS],
        crawls=[dict(c, a=list(c['a']), b=list(c['b'])) for c in CRAWLS],
        galleries=GALLERIES, upper=UPPER, ladders=LADDERS, holes=HOLES, extraWalks=EXTRA_WALKS, shortcuts=SHORTCUTS, cracks=CRACKS,
        pillars=[dict(p, rect=list(p['rect'])) for p in PILLARS], lowLinks=[list(l) for l in LOW_LINKS], lowRoof=LOW_ROOF,
        locks=LOCKS, puzzles=PUZZLES,
        extraRamps=[dict(r, a=list(r['a']), b=list(r['b'])) for r in EXTRA_RAMPS],
        niches=niches,
        caches=[n['anchorId'] for n in niches if n['family'] == 'C'], maxActiveCaches=MAX_ACTIVE_CACHES,
        water=[dict(w, rect=list(w['rect'])) for w in WATER],
        props=[dict(p, at=list(p['at']), size=list(p['size'])) for p in PROPS],
        lights=[dict(l, at=list(l['at'])) for l in LIGHTS],
        groups=[dict(name='Warren', anchorIds=['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7'], maxClosed=3)],
        entrances=[dict(anchorId=f'S{i}', playerStartTag=FOYERS[f'S{i}'], node=f'S{i}') for i in range(1, 6)],
        courts=[dict(anchorId='H1', node='H1'), dict(anchorId='H2', node='H2'), dict(anchorId='H3', node='CH')],
        anchors=anchors,
        channels={f'R{i}': f'Mechanism.Channel.Anchor.Warrens.R{i}' for i in range(1, 8)},
        quarryMinWalkCm=5000,
    )


if __name__ == '__main__':
    data = build()
    OUT.write_text(json.dumps(data, indent=1), encoding='utf-8')
    print(f'wrote {OUT.name}: {len(data["nodes"])} nodes, {len(data["links"])} links, {len(data["rooms"])} rooms, '
          f'{len(data["niches"])} pockets, {len(data["puzzles"])} puzzles, {len(data["props"])} props')
