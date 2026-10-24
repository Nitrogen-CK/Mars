"""Warrens v8d, "The Long Loop": two rings of beads pinched at the Well. Every room is a bead with its own silhouette
(a round arena, a flooded basin, a root cave, a long aisle, a tall cross, a low pillared hall, a machine hall, a
cavern) and every join between beads is a transition of one of three kinds (a stair with a turn, a squeeze that dips
or climbs, a bridge) sized so that no two beads see each other. Four one-way drops let a scout skip a bead on the way
home; two two-way shortcuts (the Chime ladder, the closet) close the rings once found. The Hollow Knight variant.

The arrival is from the SOUTH: the camp stair lands in the Arrival Hall whose nave runs north straight at the Well, so
the first thing seen is the hoist over the shaft at the end of a leading line (the Firelink rule). The west ring runs
Hall -> Cistern -> Grotto -> Court -> (terrace) -> Well; the Court also climbs to the Ossuary -> Bridge -> Well. The
east ring runs Hall -> Pump -> Cellar -> Chime -> (bridge) -> Well; the Chime also climbs to the Reliquary -> Bridge.
The Pit under the Well is the floor of both rings: cascade, Chime dive, sump stair, closet ladder. Built rooms are
orthogonal (Ossuary, Chime, Pump, Cellar, Reliquary); the grown ones are not (Cistern, Grotto, Court, Pit).
"""
import design_warrens_v8_common as common

FILE, REVISION = 'v8d', 'v8d'
SOURCE = 'Tools/LevelDesign/anchor_plans/design_warrens_v8d.py (Warrens v8d "The Long Loop", 2026-10-23)'
TUNNEL, CORRIDOR = common.TUNNEL, common.CORRIDOR
UP, DOWN, DEEPZ, GAL = 2.5, -2.5, -5.0, 5.0
FOOTPRINT = (-4, 0, 140, 118)
DEEP = (40, 4, 136, 84)
RAMP_ROOF_Z = -2.4
MAX_CLOSED = 3

NODES = {
    'S1': (70, 12, 0), 'K': (70, 32, 0), 'kn': (70, 40, 0), 'kw': (62, 32, 0), 'ke': (78, 32, 0),         # the Arrival Hall (south) and its nave
    'wW': (60, 60, 0), 'wN': (70, 67.5, 0), 'wE': (80, 60, 0), 'wS': (70, 50, 0), 'tw': (50, 60, 0),         # the rim and the West Terrace
    'c1': (50, 28, DOWN), 'CI': (42, 22, DOWN), 'c2': (34, 24, DOWN), 'gm': (27, 29, -1.0),                 # bead W1: the Cistern; gm = the hump in the root squeeze
    'g1': (22, 34, DOWN), 'GR': (16, 44, DOWN), 'g2': (14, 52, DOWN),                                     # bead W2: the Root Grotto (low cave)
    'rc': (10, 58, -1.0), 'rc2': (12, 72, 1.0), 'rc3': (24, 84, 2.0), 'ow': (36, 90, UP),                   # the Root Climb: Grotto up to the Ossuary, 5 m in 50 m
    'h0': (20, 60, 0), 'H1': (30, 64, -1.5), 'p0': (28, 58, -1.5), 'p3': (34, 70, -1.5), 'ps': (24, 68, -1.5), 'hn': (34, 76, 0), 'he': (44, 60, 0),  # bead W3: the Charnel Court (round arena)
    'o0': (40, 86, UP), 'O': (40, 96, UP), 'o1': (46, 100, UP), 'o2': (36, 100, UP), 'sm0': (28, 100, GAL), 'SM': (20, 94, GAL),   # bead W4: the Ossuary; W5: the Smokehouse (+5)
    'ce2': (122, 34, DOWN), 'bl0': (124, 20, DEEPZ), 'BL': (120, 14, DEEPZ),                                 # bead E5: the Brine Larder (-5)
    'BR': (70, 80, UP), 'b0': (64, 84, UP), 'b1': (76, 84, UP),                                           # the Bridge (over the north rim)
    'ch0': (92, 60, 0), 'CH': (102, 60, 0), 'ch1': (99, 51, 0), 'ch2': (108, 50, 0), 'chn': (102, 72, 0),  # bead E1: the Chime Hall (low pillared hall)
    'rq0': (100, 86, UP), 'RQ': (100, 96, UP), 'rq1': (92, 100, UP), 'S2': (100, 114, UP),               # bead E2: the Reliquary (tall cross)
    'p1': (88, 32, DOWN), 'PU': (96, 26, DOWN), 'p2': (104, 26, DOWN), 'pb': (84, 36, DOWN), 'SB': (74, 42, DOWN),  # bead E3: the Pump Room (machine hall); the Sump Balcony
    'bm': (110, 24, -1.5), 'CE': (116, 30, DOWN), 'ce1': (116, 40, DOWN), 'S4': (116, 10, DOWN), 'S3': (126, 60, 0), 'S5': (22, 10, DOWN),  # bead E4: the Salt Cellar; bm = the brine passage hump
    'H2': (70, 60, DEEPZ), 'd2': (87, 43, DEEPZ), 'd4': (89.5, 38, DEEPZ),                                 # the Pit
}

LINKS = [
    ('S1', 'K', [(70, 20)], CORRIDOR, 'walk', None), ('K', 'kn', [], CORRIDOR, 'walk', None), ('kn', 'wS', [], CORRIDOR, 'walk', None, dict(over=True, ownDeck=True)),   # the nave: the Well at its end
    ('K', 'kw', [], CORRIDOR, 'walk', None), ('K', 'ke', [], CORRIDOR, 'walk', None),
    # the rim and the terrace
    ('wW', 'wN', [(60, 67.5)], CORRIDOR, 'walk', None), ('wN', 'wE', [(80, 67.5)], CORRIDOR, 'walk', None),
    ('wE', 'wS', [(80, 52.2), (72.5, 52.2)], CORRIDOR, 'walk', None), ('wS', 'wW', [(66, 50.5), (60, 50.5)], CORRIDOR, 'walk', 'R4'),
    ('wW', 'tw', [], 6.0, 'walk', None), ('tw', 'he', [], CORRIDOR, 'walk', None),                             # the West Terrace: the Court's east door looks at the Well, always open
    ('wS', 'd2', [], 4.0, 'stair', 'R7'),                                                                      # the cascade
    ('wE', 'ch0', [(86, 60)], CORRIDOR, 'walk', 'R2'),                                                         # the Chime Bridge over the east arm
    ('wN', 'BR', [], CORRIDOR, 'ramp', None),                                                                  # rim N up onto the Bridge (short flight)
    # west ring
    ('kw', 'c1', [(56, 32), (54, 30)], CORRIDOR, 'stair', 'R1'),                                               # hall -> Cistern: a bent stair down
    ('c1', 'CI', [], CORRIDOR, 'walk', None), ('CI', 'c2', [], CORRIDOR, 'walk', None), ('S5', 'CI', [(30, 14)], CORRIDOR, 'walk', None),
    ('c2', 'gm', [(30, 27)], TUNNEL, 'stair', None), ('gm', 'g1', [(24, 31)], TUNNEL, 'stair', None),          # Cistern -> Grotto: the root squeeze climbs 1.5 m and drops again
    ('g1', 'GR', [], CORRIDOR, 'walk', None), ('GR', 'g2', [], CORRIDOR, 'walk', None),
    ('GR', 'rc', [(12, 50)], 2.0, 'ramp', None), ('rc', 'rc2', [], 2.0, 'ramp', None), ('rc2', 'rc3', [(16, 78)], 2.0, 'ramp', None), ('rc3', 'ow', [], 2.0, 'ramp', None), ('ow', 'O', [], CORRIDOR, 'walk', None),  # the Root Climb
    ('g2', 'h0', [(12, 58), (16, 60)], CORRIDOR, 'stair', 'R6'),                                               # Grotto -> Court: stair up with a turn
    ('h0', 'ps', [], 3.0, 'stair', None), ('he', 'p0', [(40, 60)], 4.0, 'stair', None), ('hn', 'p3', [], 3.0, 'stair', None),
    ('ps', 'H1', [], CORRIDOR, 'walk', None), ('p0', 'H1', [], CORRIDOR, 'walk', None), ('p3', 'H1', [], CORRIDOR, 'walk', None),
    ('h0', 'hn', [(16, 70), (24, 78)], CORRIDOR, 'walk', None), ('hn', 'he', [(44, 76)], CORRIDOR, 'walk', None),
    ('hn', 'o0', [(34, 80), (36, 84)], CORRIDOR, 'stair', None),                                               # Court -> Ossuary: dog-leg up
    ('o0', 'O', [], CORRIDOR, 'walk', None), ('O', 'o1', [], CORRIDOR, 'walk', None),
    ('O', 'o2', [], CORRIDOR, 'walk', None), ('o2', 'sm0', [(32, 104), (28, 106)], CORRIDOR, 'ramp', None), ('sm0', 'SM', [], CORRIDOR, 'walk', None),  # the smoke stair winds up to W5
    ('o1', 'b0', [(56, 100), (60, 92)], CORRIDOR, 'walk', 'R5'),                                               # Ossuary -> Bridge: the bone aisle turns twice
    ('b0', 'BR', [], CORRIDOR, 'walk', None), ('BR', 'b1', [], CORRIDOR, 'walk', None),
    # east ring
    ('ke', 'p1', [(84, 32), (86, 34)], CORRIDOR, 'stair', None),                                               # hall -> Pump: a bent stair down
    ('p1', 'PU', [], CORRIDOR, 'walk', None), ('PU', 'p2', [], CORRIDOR, 'walk', None), ('PU', 'pb', [(89, 35.5)], CORRIDOR, 'walk', None),
    ('pb', 'SB', [(80, 38), (77, 40.5)], TUNNEL, 'walk', None),                                                            # the sump tunnel to the balcony inside the shaft
    ('p2', 'bm', [(108, 24)], CORRIDOR, 'stair', 'R3'), ('bm', 'CE', [(113, 27)], CORRIDOR, 'stair', None),     # Pump -> Cellar: the brine passage climbs over a hump
    ('S4', 'CE', [], CORRIDOR, 'walk', None), ('CE', 'ce1', [], CORRIDOR, 'walk', None),
    ('CE', 'ce2', [], CORRIDOR, 'walk', None), ('ce2', 'bl0', [], TUNNEL, 'stair', None), ('bl0', 'BL', [], CORRIDOR, 'walk', None),  # the brine stair winds down to E5
    ('ce1', 'ch2', [(112, 46)], CORRIDOR, 'stair', None),                                                      # Cellar -> Chime: stair up with a turn
    ('ch0', 'CH', [], CORRIDOR, 'walk', None), ('CH', 'ch1', [], CORRIDOR, 'walk', None), ('CH', 'ch2', [], CORRIDOR, 'walk', None), ('CH', 'chn', [], CORRIDOR, 'walk', None),
    ('S3', 'CH', [(118, 60)], CORRIDOR, 'walk', None),
    ('ch1', 'd4', [], 4.0, 'stair', None),                                                                     # the Chime dive
    ('chn', 'rq0', [(102, 78), (100, 82)], CORRIDOR, 'stair', None),                                           # Chime -> Reliquary: stair up with a turn
    ('rq0', 'RQ', [], CORRIDOR, 'walk', None), ('RQ', 'rq1', [], CORRIDOR, 'walk', None), ('S2', 'RQ', [], CORRIDOR, 'walk', None),
    ('rq1', 'b1', [(84, 100), (80, 92)], TUNNEL, 'walk', None),                                                # Reliquary -> Bridge: the low gallery
    # the Pit
    ('d2', 'H2', [(90, 46), (90, 52), (80, 58)], TUNNEL, 'walk', None), ('d4', 'H2', [(86.5, 40.2), (89.5, 45), (90, 52), (80, 58)], TUNNEL, 'walk', None),
]

ROOMS = [
    dict(id='hall', label='Arrival Hall', poly=[(63, 26), (77, 26), (80, 29), (80, 36), (77, 40), (63, 40), (60, 36), (60, 29)], z=0, light='hearth', top=7),
    dict(id='nave', label='', rect=(67.5, 40, 72.5, 48), z=0, top=7),
    dict(id='closet', label='', rect=(56, 40, 62, 44), z=0),
    dict(id='rimW', label='', rect=(58, 48, 63, 72), z=0), dict(id='rimE', label='', rect=(77, 48, 82, 72), z=0),
    dict(id='rimN', label='The Well', rect=(58, 67, 82, 72), z=0), dict(id='rimS', label='', rect=(58, 48, 82, 53), z=0),
    dict(id='terrace', label='West Terrace', rect=(46, 54, 58, 66), z=0),
    dict(id='cistern', label='Cistern', poly=[(34, 16), (50, 16), (54, 22), (50, 30), (34, 30), (30, 24)], z=DOWN, top=4),
    dict(id='grotto', label='Root Grotto', poly=[(8, 36), (14, 32), (24, 34), (26, 42), (22, 52), (12, 56), (6, 48)], z=DOWN, top=3),
    dict(id='court', label='Charnel Court', poly=[(18, 56), (26, 52), (38, 52), (46, 58), (46, 84), (40, 84), (38, 78), (26, 78), (18, 72), (14, 64)], z=0, light='cold', top=9),
    dict(id='court-pit', label='', poly=[(22, 58), (36, 56), (42, 62), (40, 72), (28, 74), (20, 68)], z=-1.5),
    dict(id='ossuary', label='Ossuary', rect=(36, 84, 46, 104), z=UP, top=5),
    dict(id='bridge', label='Bridge', rect=(62, 72, 78, 88), z=UP, top=9),
    dict(id='smokehouse', label='Smokehouse', rect=(12, 86, 30, 100), z=GAL, light='dim', top=6),
    dict(id='larder', label='Brine Larder', poly=[(110, 8), (120, 6), (130, 10), (132, 20), (124, 24), (112, 22), (108, 14)], z=DEEPZ, top=4),
    dict(id='chime', label='Chime Hall', poly=[(90, 48), (116, 48), (116, 72), (99, 72), (99, 84), (92, 84), (92, 72), (90, 72)], z=0, light='cold', top=4),
    dict(id='chime-porch', label='', rect=(84, 57, 90, 63), z=0),
    dict(id='reliquary', label='Reliquary', poly=[(96, 84), (104, 84), (104, 92), (112, 92), (112, 100), (104, 100), (104, 108), (96, 108), (96, 100), (88, 100), (88, 92), (96, 92)], z=UP, light='dim', top=8),
    dict(id='pump', label='Pump Room', rect=(82, 18, 106, 36), z=DOWN, light='dim', top=8),
    dict(id='sump-balcony', label='Sump Balcony', rect=(62, 40, 78, 44), z=DOWN),
    dict(id='cellar', label='Salt Cellar', rect=(112, 24, 122, 42), z=DOWN, top=3.2),
    dict(id='lair', label='The Pit', poly=[(50, 46), (62, 42), (80, 34), (90, 36), (98, 48), (98, 66), (90, 76), (66, 78), (52, 72), (46, 58)], z=DEEPZ, light='cold'),
    dict(id='vault', label='Vault', rect=(98, 70, 106, 76), z=DEEPZ),
]
ENTRANCES = ['S1', 'S2', 'S3', 'S4', 'S5']
COURTS = {'H1': 'H1', 'H2': 'H2', 'H3': 'CH'}

CRAWLS = [
    dict(id='crawl-r1', a=(60, 30), b=(52.5, 24), z=0, packFits=False, note='beside the hall-Cistern stair; ends 2.5 m above the basin', purpose='reach the R1 lever at the Cistern stair foot; the scout drops'),
    dict(id='crawl-r2', a=(82, 52.5), b=(90, 52.5), z=0, packFits=False, note='in the rock south of the Chime Bridge', purpose='reach the R2 lever on the porch side'),
    dict(id='crawl-r3', a=(106, 30), b=(112, 34), z=DOWN, packFits=False, note='beside R3', purpose='reach the R3 lever in the Cellar'),
    dict(id='crawl-r5', a=(46, 102), via=[(60, 102.5), (62, 99)], b=(61, 93.5), z=UP, packFits=False, note='beside the bone aisle', purpose='reach the R5 lever at the Bridge end'),
    dict(id='crawl-sealed', a=(116, 66), b=(122, 70), z=0, packFits=False, note='a gap behind the Chime Hall\'s east wall', purpose='the one squeeze that leads somewhere new: the Sealed Burial'),
]
UPPER = dict(
    z=GAL, top=9.0, mainTop=4.6,
    tallRooms=['hall', 'nave', 'court', 'chime-porch', 'rimW', 'rimE', 'rimN', 'rimS', 'terrace', 'bridge', 'reliquary'],
    platforms=[dict(id='gE', rect=(77, 48, 84, 72), rail=0.6, note='east gallery over the east rim: the Red key on a lit plinth at its west rail')],
    walkways=[dict(id='gE-ladder', pts=[(84, 66), (90, 66)], width=2.5, note='catwalk to the Chime ladder head')],
    railGaps=[
        dict(id='ossuary-drop', a=(42, 84), b=(46, 84), note='one-way drop: Ossuary south rail -> the Court\'s north bay (2.5 m), the scout\'s bead-skip'),
        dict(id='reliquary-drop', a=(96, 84), b=(99, 84), landing=dict(rect=(96, 82, 99, 84), z=0.0), note='one-way drop: Reliquary south rail -> the Chime Hall\'s north bay (2.5 m)'),
        dict(id='bridge-drop', a=(74, 72), b=(78, 72), note='one-way drop: Bridge -> north rim (2.5 m), east of the flight'),
        dict(id='smoke-drop', a=(26, 86), b=(30, 86), landing=dict(rect=(26, 84.5, 30, 86), z=2.2), note='one-way drop: Smokehouse south rail -> the Root Climb below (about 2.8 m): the Curing Room\'s short way down'),
    ],
)
LADDERS = [
    dict(id='closet-ladder', at=(59, 43.25), baseZ=DEEPZ, height=5.0, yaw=0.0, oneWay=True, note='from the Pit\'s south-west up into the hall closet', purpose='the Pit\'s one-way way home, pack included'),
    dict(id='chime-ladder', at=(90.5, 66), baseZ=0.0, height=5.0, yaw=0.0, kind='barred', oneWay=False, note='Chime Hall up to the east gallery; foot barred until the lever above is pulled', purpose='once opened, the east ring closes at height: Chime -> gallery -> rim'),
    dict(id='larder-ladder', at=(117.5, 21), baseZ=DEEPZ, height=2.5, yaw=0.0, oneWay=True, note='Brine Larder up into the Cellar: the scout\'s short way back', purpose='E5 closes on the Cellar without the stair'),
]
LEDGE_RAIL = 0.6  # P6: the ledge and deep-water rails are a 0.6 m parapet (the v5 ruling: the Pit is seen from the rim over it)
HOLES = [
    dict(id='well', level='main', rect=(63, 53, 77, 67), kind='open', rail=0.6, note='the Well'),
    dict(id='shaft-slot-w', level='main', rect=(62, 44, 67.5, 48), kind='open', rail=0.6, note='the Sump Balcony\'s west shaft slot beside the nave deck: the balcony looks over a railed drop into the Pit (P5b)'),
    dict(id='shaft-slot-e', level='main', rect=(72.5, 44, 78, 48), kind='open', rail=0.6, note='the Sump Balcony\'s east shaft slot beside the nave deck (P5b)'),
    dict(id='east-arm-s', level='main', rect=(82, 54, 90, 57.5), kind='open', rail=0.6), dict(id='east-arm-n', level='main', rect=(82, 62.5, 90, 66), kind='open', rail=0.6),
    dict(id='closet-well', level='main', rect=(59.0, 42.5, 60.5, 44.0), kind='open'),
    dict(id='larder-shaft', level='main', rect=(117.5, 20.25, 119.0, 21.75), kind='open', note='the larder ladder opening beside the S4 passage'),
    dict(id='chime-hatch', level='upper', rect=(90.5, 65.25, 91.5, 66.75), kind='open', note='the Chime ladder roof hatch up to the catwalk'),
]
EXTRA_WALKS = [
    dict(id='sc2-door', pts=[(59, 40), (59, 38)], width=2.5, note='closet to hall, barred from the hall side'),
    dict(id='vault-passage', level='deep', pts=[(95, 73), (98, 73)], width=2.5),
]
EXTRA_RAMPS = [
    dict(id='bridge-flight', a=(70, 68, 0), b=(70, 74, UP), width=3.0, note='rim N up onto the Bridge: a 6 m flight at 22.6 degrees'),
    dict(id='sump-stair', a=(78, 42, DOWN), b=(88, 38, DEEPZ), width=2.5, note='the barred sump stair (P2): balcony down into the Pit'),
    dict(id='smoke-stair-a', a=(36, 100, UP), b=(32, 104, 3.7), width=3.0, note='the smoke stair: Ossuary up to the Smokehouse'), dict(id='smoke-stair-b', a=(32, 104, 3.7), b=(28, 106, 4.3), width=3.0), dict(id='smoke-stair-c', a=(28, 106, 4.3), b=(28, 100, GAL), width=3.0),
    dict(id='rootclimb-a', a=(16, 44, DOWN), b=(12, 50, -2.0), width=2.0, note='the Root Climb: a crawl-sized winding tunnel from the Grotto up to the Ossuary'),
    dict(id='rootclimb-b', a=(12, 50, -2.0), b=(10, 58, -1.0), width=2.0), dict(id='rootclimb-c', a=(10, 58, -1.0), b=(12, 72, 1.0), width=2.0),
    dict(id='rootclimb-d', a=(12, 72, 1.0), b=(16, 78, 1.5), width=2.0), dict(id='rootclimb-e', a=(16, 78, 1.5), b=(24, 84, 2.0), width=2.0), dict(id='rootclimb-f', a=(24, 84, 2.0), b=(36, 90, UP), width=2.0),
]
SHORTCUTS = [
    dict(id='SC2', at=(59, 40), yaw=90.0, spanCm=250.0, leverSide=-1, oneWay=True, channel='Mechanism.Channel.Warrens.Shortcut.SC2', note='closet -> hall; lever in the closet'),
]
LIGHTS = [
    dict(at=(70, 32, 3.0), kind='hearth'), dict(at=(70, 60, 8.0), kind='shaft'), dict(at=(70, 60, -3.0), kind='cold'),
    dict(at=(30, 64, 5.0), kind='cold'), dict(at=(100, 96, 5.1), kind='dim'), dict(at=(96, 26, 0.1), kind='dim'), dict(at=(42, 22, -0.5), kind='dim'),
    dict(at=(79, 60, 5.6), kind='dim'), dict(at=(102, 60, 3.5), kind='cold'), dict(at=(40, 96, 5.1), kind='dim'), dict(at=(70, 42, -0.5), kind='dim'), dict(at=(16, 44, -1.0), kind='dim'),
    dict(at=(20, 94, 7.6), kind='dim'), dict(at=(120, 14, -2.4), kind='dim'),
]
PILLARS = [
    dict(level='main', rect=(94, 52, 96, 54)), dict(level='main', rect=(94, 66, 96, 68)), dict(level='main', rect=(108, 52, 110, 54)), dict(level='main', rect=(108, 66, 110, 68)),
    dict(level='deep', rect=(54, 50, 57, 53)), dict(level='deep', rect=(86, 70, 89, 73)), dict(level='deep', rect=(54, 68, 57, 71)),
]
LOW_LINKS = [('c2', 'gm'), ('gm', 'g1'), ('pb', 'SB'), ('rq1', 'b1'), ('d4', 'H2'), ('GR', 'rc'), ('rc', 'rc2'), ('rc2', 'rc3'), ('rc3', 'ow'), ('ce2', 'bl0')]
LOW_ROOF = 2.2
RAMP_OVERRIDES = [dict(link=['ch1', 'd4'], start=(98.705, 50.596), note='P5b: the Chime dive starts 0.5 m past ch1 (not 2 m) so its foot clears the Pump\'s north wall at 17.8 degrees'),
                  dict(link=['ce2', 'bl0'], roofZ=-5.0, note='the brine stair starts at -2.5, below the default rampRoofZ: open its whole length (an open stairwell beside the Cellar), else the Cellar slab roofs it 0.2 m above the treads')]
LOCKS = [
    dict(id='vault', door=dict(at=(97, 73), yaw=0.0, spanCm=250.0, level='deep'), lock=dict(at=(96, 71.3), yaw=90.0, level='deep'),
         key='Red', keyAt=(77.4, 60, 5.3), channel='Mechanism.Channel.Keys.Red', note='the key on the east gallery rail, seen from the nave across the Well'),
]
PUZZLES = [
    dict(id='P1', kind='Red key door', at=(97, 73, DEEPZ), needsAt=(77.4, 60, GAL), needsNote='the key on the east gallery rail, seen from the nave across the Well'),
    dict(id='P2', kind='barred sump stair (latched bars) at the Sump Balcony', at=(76, 42, DOWN), needsAt=(118, 28, DOWN), needsNote='the Cellar hand-wheel opens it; the dry channel in the Pump floor is the tell', existing='hand-wheel + latched Bars gate'),
    dict(id='P3', kind='Mourner cache gate (latched)', at=(110, 96, UP), needsAt=(40, 102, UP), needsNote='the pack plate at the Ossuary\'s north end, across the Bridge', latch=True),
    dict(id='P4', kind='Bellkeeper dial lock', at=(114, 70, 0), needsAt=(70, 76, UP), needsNote='the glyphs on the Well\'s south wall, read from the Bridge'),
    dict(id='P5', kind='barred ladder foot (Chime Hall)', at=(90, 66, 0), needsAt=(86, 66, GAL), needsNote='the lever on the catwalk, reached by the gallery from the Bridge'),
    dict(id='P6', kind='SC2 barred closet door', at=(59, 40, 0), needsAt=(59, 42, DEEPZ), needsNote='climb the closet ladder out of the Pit'),
    dict(id='P7', kind='Curing Room (support objective)', at=(16, 94, GAL), needsAt=(70, 60, DEEPZ), needsNote='the Curing Room: the hunted part is brined here before it travels (the run\'s second required stop); the vat, the drying racks, a plinth for the pack'),
]
NICHES = [
    dict(id='court-pack', rect=(46, 78, 49, 81), z=0, family='P', note='pack plinth at the Ossuary stair foot'),
    dict(id='court-forage', rect=(12.5, 62.5, 14.5, 66.5), z=0, family='F', note='mushrooms in the west burial niche'),
    dict(id='court-omen', rect=(44, 66, 46, 68), z=0, family='O', note='eyes in the east wall niche'),
    dict(id='court-threat', rect=(26, 48, 30, 52), z=0, family='T', note='sentry alcove south of the arena'),
    dict(id='ossuary-husk', rect=(36, 104, 40, 107), z=UP, family='F', note='husk spill at the aisle\'s far end'),
    dict(id='ossuary-rest', rect=(32, 86, 36, 89), z=UP, family='N', note='lantern rest by the Court stair'),
    dict(id='bridge-omen', rect=(69, 88, 71, 90), z=UP, family='O', note='swaying chains over the Bridge'),
    dict(id='mourner', rect=(112, 94, 118, 98), z=UP, family='C', note='Mourner cache behind the pack-plate gate (P3)'),
    dict(id='reliquary-rest', rect=(84, 94, 88, 97), z=UP, family='N', note='lantern rest at the low gallery mouth'),
    dict(id='bellkeeper', rect=(116, 72, 122, 76), z=0, family='C', note='Bellkeeper\'s Confession behind the dial lock (P4)'),
    dict(id='chime-threat', rect=(96, 44, 100, 48), z=0, family='T', note='sentry niche south of the hall'),
    dict(id='chime-pack', rect=(116, 56, 120, 60), z=0, family='P', note='pack plinth by the S3 way in'),
    dict(id='sealed-burial', rect=(122, 68, 127, 74), z=0, family='C', note='the Sealed Burial behind crawl-sealed'),
    dict(id='cellar-salt', rect=(122, 30, 126, 34), z=DOWN, family='F', note='salt crystals'),
    dict(id='porter', rect=(106, 14, 114, 20), z=DOWN, family='C', note='Porter\'s Wager: the freight niche off the Pump'),
    dict(id='pump-omen', rect=(78, 22, 82, 25), z=DOWN, family='O', note='swaying chains in the west niche'),
    dict(id='pump-shelf', rect=(100, 36, 104, 39), z=-0.5, family='N', note='a maintenance shelf 2 m up the pump hall\'s north wall: a ledge hop off the machine'),
    dict(id='balcony-threat', rect=(62, 36, 65, 40), z=DOWN, family='T', note='something waits at the balcony\'s west end'),
    dict(id='cistern-forage', rect=(34, 12, 38, 16), z=DOWN, family='F', note='mushroom bed across the basin'),
    dict(id='grotto-forage', rect=(4, 40, 8, 44), z=DOWN, family='F', note='root mushrooms'),
    dict(id='grotto-rest', rect=(20, 52, 24, 55), z=DOWN, family='N', note='lantern rest at the stair foot'),
    dict(id='pit-pack', rect=(50, 72, 54, 76), z=DEEPZ, family='P', note='pack plinth at the Pit\'s north-west'),
    dict(id='pit-rest', rect=(48, 56, 52, 60), z=DEEPZ, family='N', note='lantern rest at the lair\'s west wall'),
    dict(id='pit-forage', rect=(94, 52, 98, 56), z=DEEPZ, family='F', note='deep mushrooms in the east arm'),
    dict(id='pit-omen', rect=(68, 78, 70, 80), z=DEEPZ, family='O', note='the inner wall niche'),
    dict(id='smoke-pack', rect=(12, 100, 16, 103), z=GAL, family='P', note='pack plinth by the vat'), dict(id='smoke-threat', rect=(30, 94, 34, 98), z=GAL, family='T', note='something in the rack row'),
    dict(id='smoke-rest', rect=(8, 92, 12, 95), z=GAL, family='N', note='lantern rest at the west wall'),
    dict(id='larder-forage', rect=(131, 12, 135, 16), z=DEEPZ, family='F', note='brined stores: a wade to reach them'), dict(id='larder-cache', rect=(108, 4, 114, 8), z=DEEPZ, family='C', note='the Larder cache: a sealed cask'),
    dict(id='larder-omen', rect=(120, 24, 122, 26), z=DEEPZ, family='O', note='chains over the brine'),
]
WATER = [
    dict(id='cistern-basin', poly=[(36, 18), (48, 18), (51, 22), (48, 28), (36, 28), (33, 24)], z=DOWN, depth=0.4, note='the Cistern basin fills the bead: a wade round its rim'),
    dict(id='larder-water', poly=[(112, 10), (122, 8), (128, 12), (128, 20), (116, 20)], z=DEEPZ, depth=0.5, note='the Brine Larder: knee-deep'),
]
PROPS = [
    dict(kind='station', at=(66, 71, 0), size=(1.6, 1.6, 7.5), note='THE HOIST over the north rim, west of the bridge flight: the end of the nave\'s leading line'),
    dict(kind='plinth', at=(64, 34, 0), size=(1.2, 1.2, 0.3), note='pack plinth by the Camp Door'),
    dict(kind='statue', at=(30, 74.9, 0), size=(2.0, 1.2, 4.5), yaw=-90, note='split mourner: the Court landmark at the arena\'s north'),
    dict(kind='root', at=(64, 56, DEEPZ), size=(1.4, 1.4, 14.0), note='roots down the west wall'), dict(kind='root', at=(64, 64, DEEPZ), size=(1.0, 1.0, 14.0)),
    dict(kind='stack', at=(70, 52.5, -2.2), size=(5.0, 0.3, 2.0), note='the dial glyphs on the south wall (P4), read from the Bridge'),
    dict(kind='stack', at=(41, 90, UP), size=(1.0, 8.0, 2.6), note='bone stacks: the aisle'), dict(kind='stack', at=(45, 92, UP), size=(1.0, 6.0, 2.6)),
    dict(kind='plinth', at=(40, 102, UP), size=(2.0, 2.0, 0.3), note='the pack plate (P3), at the aisle\'s far end'),
    dict(kind='sarcophagus', at=(106, 96, UP), size=(3.0, 1.5, 1.2), note='the reliquary tomb in the crossing\'s east arm'),
    dict(kind='plinth', at=(77.4, 60, GAL), size=(0.8, 0.8, 0.3), note='the key plinth on the gallery\'s west rail (P1)'),
    dict(kind='station', at=(77.5, 43.6, DOWN), size=(0.3, 2.6, 2.5), yaw=90.0, note='the sump bars (P2), beside the stair head'),
    dict(kind='stack', at=(102, 30, DOWN), size=(28.0, 0.8, 0.2), note='the dry channel in the Pump floor (P2 tell)'),
    dict(kind='chimes', at=(102, 60, 0), size=(8.0, 0.2, 3.0), yaw=0, note='bone chimes across the low hall'),
    dict(kind='station', at=(113, 71, 0), size=(1.0, 0.4, 1.4), note='the dial lock (P4)'),
    dict(kind='pillar', at=(100, 22, DOWN), size=(2.5, 2.5, 6.0), note='the pump: a machine the height of the hall'),
    dict(kind='pillar', at=(118, 28, DOWN), size=(1.0, 1.0, 1.6), note='the hand-wheel (P2)'),
    dict(kind='stack', at=(120, 38, DOWN), size=(2.0, 2.0, 1.4), note='salt crystals'),
    dict(kind='root', at=(20, 40, DOWN), size=(1.2, 1.2, 3.0), note='roots through the Grotto roof'),
    dict(kind='candles', at=(62, 28, 0), size=(0.9, 0.9, 0.5), note='tallow'), dict(kind='candles', at=(44, 86, UP), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(36, 26, DOWN), size=(0.9, 0.9, 0.5), note='tallow'), dict(kind='candles', at=(92, 50, 0), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(52, 70, DEEPZ), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='station', at=(16, 94, GAL), size=(2.4, 1.6, 1.4), note='the brine vat (P7): the Curing Room'), dict(kind='stack', at=(24, 92, GAL), size=(0.6, 8.0, 2.2), note='drying racks'),
]
ANCHOR_AT = {'R1': (58, 32), 'R2': (88, 60), 'R3': (107, 25), 'R4': (64, 50.5), 'R5': (58, 96), 'R6': (14, 58), 'R7': None}
LEVER_NODE = {'R1': 'c1', 'R2': 'ch0', 'R3': 'bm', 'R5': 'b0'}
MAX_ACTIVE_CACHES = 2
WINDOWS = [  # P5b: framed openings where a view crosses rock (sill >= 1.2 m over the higher floor beside the cut)
    dict(id='court-east', a=(52, 67), b=(52, 71), sill=1.2, head=6.0, note='a high opening in the Court\'s east wall north of the door: the hoist seen from the arena over the rim'),
]

INSTANCES = [
    dict(id='Hub', label='LI_Warrens_Hub', asset='LI_Warrens_Hub', z=0, rect=(56, 24, 84, 90),
         ports=[dict(id='camp', at=(70, 24, 0), width=3, kind='door'), dict(id='cistern', at=(58, 32, 0), width=3, kind='stair'), dict(id='pump', at=(82, 32, 0), width=3, kind='stair'),
                dict(id='terrace', at=(56, 60, 0), width=6, kind='door'), dict(id='chime', at=(84, 60, 0), width=3, kind='balcony'), dict(id='ossuary', at=(62, 88, 2.5), width=3, kind='door'),
                dict(id='reliquary', at=(78, 88, 2.5), width=2.5, kind='crawl'), dict(id='cascade', at=(76, 50, 0), width=4, kind='stair'), dict(id='closet', at=(59, 42, -5), width=1, kind='ladder')],
         note='the Arrival Hall, the nave, the Well, rims, the Bridge, the east gallery; persistent-level candidate'),
    dict(id='Cistern', label='LI_Warrens_Cistern', asset='LI_Warrens_Cistern', z=-2.5, rect=(26, 10, 58, 34),
         ports=[dict(id='hall', at=(54, 30, -2.5), width=3, kind='stair'), dict(id='grotto', at=(28, 28, -2.5), width=2.5, kind='crawl'), dict(id='S5', at=(22, 10, -2.5), width=3, kind='door')]),
    dict(id='Grotto', label='LI_Warrens_Grotto', asset='LI_Warrens_Grotto', z=-2.5, rect=(2, 28, 28, 60),
         ports=[dict(id='cistern', at=(26, 30, -2.5), width=2.5, kind='crawl'), dict(id='court', at=(14, 58, -2.5), width=3, kind='stair'), dict(id='rootclimb', at=(12, 56, -1.0), width=2, kind='crawl')]),
    dict(id='Court', label='LI_Warrens_Court', asset='LI_Warrens_Court', z=0, rect=(10, 48, 50, 82),
         ports=[dict(id='grotto', at=(16, 58, 0), width=3, kind='stair'), dict(id='terrace', at=(46, 60, 0), width=3, kind='door'), dict(id='ossuary', at=(36, 82, 0), width=3, kind='stair')]),
    dict(id='Ossuary', label='LI_Warrens_Ossuary', asset='LI_Warrens_Ossuary', z=2.5, rect=(30, 82, 62, 108),
         ports=[dict(id='court', at=(36, 82, 2.5), width=3, kind='stair'), dict(id='bridge', at=(62, 92, 2.5), width=3, kind='door'), dict(id='drop', at=(46, 90, 2.5), width=2, kind='drop'), dict(id='rootclimb', at=(34, 90, 2.5), width=2, kind='crawl'), dict(id='smoke', at=(34, 104, 3), width=3, kind='stair')]),
    dict(id='Smokehouse', label='LI_Warrens_Smokehouse', asset='LI_Warrens_Smokehouse', z=5, rect=(6, 84, 36, 110),
         ports=[dict(id='ossuary', at=(34, 104, 3), width=3, kind='stair'), dict(id='drop', at=(24, 88, 5), width=2, kind='drop')], note='W5: the Curing Room (P7) above the Root Climb'),
    dict(id='Larder', label='LI_Warrens_Larder', asset='LI_Warrens_Larder', z=-5, rect=(104, 2, 138, 30),
         ports=[dict(id='cellar', at=(126, 30, -2.5), width=2.5, kind='stair'), dict(id='ladder', at=(116, 23, -5), width=1, kind='ladder')], note='E5: the Brine Larder, a wade bead below the Cellar'),
    dict(id='Chime', label='LI_Warrens_Chime', asset='LI_Warrens_Chime', z=0, rect=(84, 42, 128, 78),
         ports=[dict(id='bridge', at=(84, 60, 0), width=3, kind='balcony'), dict(id='cellar', at=(112, 44, 0), width=3, kind='stair'), dict(id='reliquary', at=(102, 78, 0), width=3, kind='stair'),
                dict(id='dive', at=(98, 48, 0), width=4, kind='stair'), dict(id='S3', at=(126, 60, 0), width=3, kind='door'), dict(id='ladder', at=(90, 66, 0), width=1, kind='ladder')]),
    dict(id='Reliquary', label='LI_Warrens_Reliquary', asset='LI_Warrens_Reliquary', z=2.5, rect=(84, 80, 122, 110),
         ports=[dict(id='chime', at=(102, 80, 2.5), width=3, kind='stair'), dict(id='bridge', at=(84, 100, 2.5), width=2.5, kind='crawl'), dict(id='S2', at=(100, 108, 2.5), width=3, kind='door'), dict(id='drop', at=(102, 84, 2.5), width=2, kind='drop')]),
    dict(id='Waterworks', label='LI_Warrens_Waterworks', asset='LI_Warrens_Waterworks', z=-2.5, rect=(60, 8, 128, 46),
         ports=[dict(id='hall', at=(86, 34, -2.5), width=3, kind='stair'), dict(id='chime', at=(112, 46, -2.5), width=3, kind='stair'), dict(id='balcony', at=(78, 44, -2.5), width=2.5, kind='balcony'), dict(id='S4', at=(116, 10, -2.5), width=3, kind='door')],
         note='Pump Room, Salt Cellar, the Sump Balcony and its barred stair'),
    dict(id='Pit', label='LI_Warrens_Pit', asset='LI_Warrens_Pit', z=-5, rect=(44, 38, 108, 82),
         ports=[dict(id='cascade', at=(84, 46, -5), width=4, kind='stair'), dict(id='dive', at=(90, 42, -5), width=4, kind='stair'), dict(id='sump', at=(86, 48, -5), width=2.5, kind='stair'), dict(id='closet', at=(59, 42, -5), width=1, kind='ladder')]),
]
VIEWS = [
    dict(id='nave-hoist', **{'from': (70, 44, 0), 'to': (66, 72, 5)}, label='the nave -> the hoist: the leading line from the Camp Door'),
    dict(id='nave-key', **{'from': (70, 44, 0), 'to': (77.4, 60, 5.3)}, label='the nave -> the Red key on the gallery rail'),
    dict(id='terrace-well', **{'from': (50, 60, 0), 'to': (70, 60, 8)}, label='West Terrace -> the shaft light over the Well'),
    dict(id='court-terrace', **{'from': (30, 64, -1.5), 'to': (66, 72, 5)}, label='Court arena -> through the east door and the terrace to the hoist'),
    dict(id='bridge-glyphs', **{'from': (70, 76, 2.5), 'to': (70, 52.5, -1.5)}, label='Bridge -> the glyphs on the south wall (P4)'),
    dict(id='chimebridge-hoist', **{'from': (84, 59.5, 0), 'to': (66, 72, 5)}, label='Chime Bridge -> the hoist'),
    dict(id='balcony-shaft', **{'from': (66.5, 42, -2.5), 'to': (70, 60, -5)}, label='Sump Balcony -> the Pit floor and the shaft light'),
    dict(id='gallery-well', **{'from': (77.3, 66, 5), 'to': (70, 60, 8)}, label='east gallery -> the shaft light over the Well'),
    dict(id='pit-hoist', **{'from': (70, 56, -5), 'to': (66, 72, 7)}, label='Pit -> up the shaft'),
]
TRANSITIONS = [
    dict(id='t-nave', at=(70, 44, 0), kind='reveal', label='the nave: Camp Door -> the Well, straight ahead'),
    dict(id='t-cistern', at=(56, 31, -1.2), kind='stair', label='hall -> Cistern: bent stair down (R1)'),
    dict(id='t-roots', at=(27, 29, -1.0), kind='squeeze', label='Cistern -> Grotto: the root squeeze climbs 1.5 m and drops again'),
    dict(id='t-grottocourt', at=(13, 59, -1.2), kind='stair', label='Grotto -> Court: stair up with a turn (R6)'),
    dict(id='t-terrace', at=(48, 60, 0), kind='reveal', label='Court east door -> West Terrace: the Well opens'),
    dict(id='t-rootclimb', at=(11, 64, 0), kind='squeeze', label='the Root Climb: Grotto -> Ossuary, 5 m up in a winding crawl-tunnel round the Court\'s back'),
    dict(id='t-courtossuary', at=(35, 82, 1.2), kind='stair', label='Court -> Ossuary: dog-leg up'),
    dict(id='t-aisle', at=(58, 98, 2.5), kind='turn', label='Ossuary -> Bridge: the bone aisle turns twice (R5)'),
    dict(id='t-bridgeflight', at=(70, 72, 1.2), kind='stair', label='rim N -> Bridge: short flight'),
    dict(id='t-pump', at=(85, 33, -1.2), kind='stair', label='hall -> Pump: bent stair down'),
    dict(id='t-brine', at=(110, 24, -1.5), kind='squeeze', label='Pump -> Cellar: the brine passage climbs over a hump (R3)'),
    dict(id='t-cellarchime', at=(112, 45, -1.2), kind='stair', label='Cellar -> Chime: stair up with a turn'),
    dict(id='t-chimebridge', at=(86, 60, 0), kind='bridge', label='rim E -> Chime: bridge over the east arm (R2)'),
    dict(id='t-chimereliquary', at=(101, 80, 1.2), kind='stair', label='Chime -> Reliquary: stair up with a turn'),
    dict(id='t-lowgallery', at=(82, 96, 2.5), kind='squeeze', label='Reliquary -> Bridge: the low gallery'),
    dict(id='t-sump', at=(86, 42, -2.5), kind='squeeze', label='Pump -> Sump Balcony: low tunnel, then the shaft'),
    dict(id='t-cascade', at=(77, 48, -2.5), kind='stair', label='rim S -> Pit: the cascade (R7)'),
    dict(id='t-dive', at=(94, 46, -2.5), kind='stair', label='Chime -> Pit: the dive'),
    dict(id='t-pumpshelf', at=(102, 36, -1.0), kind='jump', label='ledge hop: off the pump onto the maintenance shelf'),
    dict(id='t-drop1', at=(44, 84, 2.5), kind='drop', label='one-way drop: Ossuary -> Court north bay'),
    dict(id='t-drop2', at=(97.5, 84, 2.5), kind='drop', label='one-way drop: Reliquary -> Chime north bay'),
    dict(id='t-drop3', at=(76, 72, 2.5), kind='drop', label='one-way drop: Bridge -> north rim'),
    dict(id='t-smokestair', at=(30, 105, 3.8), kind='stair', label='Ossuary -> Smokehouse: the smoke stair winds up to +5'),
    dict(id='t-smokedrop', at=(28, 86, 5), kind='drop', label='one-way drop: Smokehouse -> the Root Climb (2.8 m)'),
    dict(id='t-brinestair', at=(127, 27, -3.8), kind='stair', label='Cellar -> Brine Larder: winding stair down to -5'),
    dict(id='t-larderladder', at=(116, 23, -3.8), kind='ladder', label='Larder -> Cellar: the scout\'s ladder up'),
]
LANDMARK = dict(id='well', label='THE WELL', at=(70, 60, 0),
                faces=[dict(dir='N', label='hoist; the Bridge above'), dict(dir='W', label='roots; the terrace and the Court beyond'), dict(dir='S', label='glyph wall; the nave and the Camp Door'), dict(dir='E', label='the Chime Bridge and the east arm')])
NOTES = dict(
    thesis='Beads on two rings. Each room is one adjective (round, flooded, low, long, tall, wide, machine, cavern) and each join is one '
           'beat; the Well is the pinch both rings pass through, and four one-way drops let a scout skip a bead on the way home.',
    principles=['Hollow Knight: every wing previews itself at the hub (the terrace is the Court\'s porch, the porch is the Chime\'s) and loops back by a different door',
                'Silhouette over decoration: ceiling heights 3 to 9 m and plan shapes differ between neighbours, so a lantern pool reads the room; built rooms square, grown rooms not',
                'Cavern and dungeon: the squeezes climb and drop along their length (root squeeze, brine passage); two ledge hops sit off the main floors',
                'Firelink leading line: the nave aims the arrival at the hoist; the key is seen before the galleries are found',
                'Souls shortcuts open onto a known place from a new height: every drop lands on a bead already walked',
                'Grimrock: what opens a thing is elsewhere, but never more than one bead away from the thing it opens, except the two long puzzles (P2, P3)'],
    changes=['Arrival from the south through a nave; the camp stair is the front door (S1)',
             'The Sump Balcony\'s shaft slots: two main-level openings beside the nave deck, (62, 44, 67.5, 48) and (72.5, 44, 78, 48), railed 0.9 m, so the balcony looks down into the Pit (P5b)',
             'West Terrace: the Court\'s east door opens onto the Well, always open (R4 stays on the rim)',
             'The Root Climb: a 50 m crawl-sized tunnel winding 5 m up from the Grotto to the Ossuary behind the Court',
             'The Cistern is a flooded bead with a wade rim; the Grotto a 3 m cave; the Reliquary a cross; the Chime a 4 m pillared hall; the Pit an irregular cavern',
             'Four rail drops (Ossuary -> Court, Reliquary -> Chime, Bridge -> rim, Smokehouse -> Root Climb), each onto a floor the rooms share an edge over',
             'Nine Level Instance tiles; the Bridge and gallery belong to the Hub'],
    sizing='15-20 min: hunt court + Curing Room (W5, +5 behind the Court) + forage + return; W5 and E5 add a bead to each ring, both closing on a drop or a ladder',
    risks=['Two long outer rings mean the far beads (Grotto, Reliquary) are 60+ m from home; the drops are the scout\'s answer, not the pack\'s',
           'Four drops need fall-damage-free 2.5 m ledges and clear "no way back up" reads',
           'The Cistern bead is mostly water: cargo handling in a wade needs a check',
           'The Bridge flight from the rim is 26.6 degrees (the kit\'s stair), steeper than every other flight'],
)

if __name__ == '__main__':
    import sys
    common.write(sys.modules[__name__])
