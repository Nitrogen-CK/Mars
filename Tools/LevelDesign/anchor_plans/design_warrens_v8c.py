"""Warrens v8c, "Two Towers and the Canal": a bigger, flatter map with two landmarks and one edge. The Drowned Canal
(a flooded fault, impassable) runs north-south across the whole district and splits it into the dry west bank (the
Well, the Pit under it, the Court, the Ossuary, the waterworks) and the wet east bank (the Belfry, the Reliquary, the
brine stores). It is crossed at exactly three places, each a different beat: the Bone Bridge (north, +2.5, R5), the
Ford (centre, knee-deep, always open: the one place both landmarks are seen at once), and the Undercroft (south, -5,
a low winding tunnel under the water, R7). The Chain Crossing (south, -2.2) is a sliding cargo shortcut extended from the east.

Landmarks: the Well (west: hoist, shaft light, the Pit glow below) and the Bell Tower (east: 22 m tall, cold-lit bell,
heard across the map). Lynch's rule: from anywhere you are between the two or beyond one, and the canal tells you
which bank. The horizontal variant: 178 x 130 m, three main floor levels (+2.5 / 0 / -2.5), the Mill at +5 and Pit at -5; the
connectors between them wind up and down (the cave-and-dungeon mix): built rooms are orthogonal, grown spaces are not.
"""
import design_warrens_v8_common as common

FILE, REVISION = 'v8c', 'v8c'
SOURCE = 'Tools/LevelDesign/anchor_plans/design_warrens_v8c.py (Warrens v8c "Two Towers and the Canal", 2026-10-23)'
TUNNEL, CORRIDOR = common.TUNNEL, common.CORRIDOR
UP, DOWN, DEEPZ = 2.5, -2.5, -5.0
FOOTPRINT = (-28, -4, 150, 126)
DEEP = (-16, 16, 114, 70)
RAMP_ROOF_Z = -2.4
MAX_CLOSED = 3

NODES = {
    'S1': (-2, 50, 0), 'K': (16, 50, 0), 'kn': (16, 56, 0), 'ke': (25, 50, 0),                          # the Arrival Hall at the west edge
    'wW': (31, 50, 0), 'wN': (40, 57, 0), 'wE': (48.5, 50, 0), 'wS': (40, 43, 0), 'wSE': (48.5, 43, 0),                   # the Well rim
    'h0': (24, 66, 0), 'c2': (24, 86, 0), 'c1': (6, 64, 0), 'H1': (15, 76, -1.5), 'p0': (20, 70, -1.5), 'p3': (20, 82, -1.5), 'ps': (10, 70, -1.5),  # the Court
    'o0': (44, 64, UP), 'O': (48, 72, UP), 'o1': (40, 78, UP), 'bh': (59, 74, UP),                      # the Ossuary and the bridgehead
    'rh': (85, 80, UP), 'RQ': (92, 80, UP), 'rq1': (92, 72, UP), 'S2': (110, 80, UP),                  # the Reliquary (east bank)
    'rq2': (98, 94, UP), 'ml0': (98, 106, 5), 'ML': (92, 103, 5),                                      # the Salt Mill (+5): the Curing Room
    'ct0': (-6, 68, 0), 'CT': (-14, 76, 0), 'ct1': (-10, 64, 0), 'lw': (21, 47, DEEPZ),                 # the Catacomb and its dive into the Pit
    'bn': (96, 64, 0), 'BF': (98, 54, 0), 'bs': (96, 44, 0), 'be': (108, 54, 0), 'fe': (84, 49, 0),     # the Belfry; fe = the Ford's east step
    'fw': (57, 49, -2.5), 'fm': (74, 49, -2.5),                                                        # the Ford: west step, mid-stream
    'ce0': (96, 26, DOWN), 'CE': (104, 19, DOWN), 'SL': (122, 15, DOWN), 'S4': (122, 0, DOWN),           # the Salt Cellar and the Sluice
    'bl0': (112, 46, DOWN), 'BL': (120, 40, DOWN), 'bl1': (112, 34, DOWN), 'S3': (140, 40, DOWN),        # the Brine Larder (wade)
    'ut1': (104, 28, DEEPZ), 'ut2': (56, 30, DEEPZ), 'ls': (50, 36, DEEPZ),                             # the Undercroft under the canal
    'p1': (52, 32, DOWN), 'PU': (58, 25, DOWN), 'p0w': (50, 24, DOWN), 'pe': (66, 26, DOWN),             # the Pump Room
    'tm': (38, 21, -1.0),                                                                              # the hump in the Cistern tunnel
    'ci1': (24, 36, DOWN), 'CI': (16, 37, DOWN), 'ci2': (14, 43, DOWN), 'S5': (16, 22, DOWN), 'cw': (4.5, 55, DOWN),            # the Cistern
    'H2': (40, 50, DEEPZ), 'd2': (32, 27, DEEPZ), 'sp': (50, 26, DOWN), 'sf': (42, 34, DEEPZ),             # the Pit; the Sump Stair's head and foot
}

LINKS = [
    ('S1', 'K', [(7, 50)], CORRIDOR, 'walk', None, dict(over=True)), ('K', 'ke', [], CORRIDOR, 'walk', None), ('ke', 'wW', [], CORRIDOR, 'walk', None),
    ('K', 'kn', [], CORRIDOR, 'walk', None), ('kn', 'h0', [(16, 60), (22, 62)], CORRIDOR, 'walk', 'R1'),
    # the rim
    ('wW', 'wN', [(31, 57)], CORRIDOR, 'walk', None), ('wN', 'wE', [(48.5, 57)], CORRIDOR, 'walk', None),
    ('wE', 'wSE', [], CORRIDOR, 'walk', None), ('wSE', 'wS', [], CORRIDOR, 'walk', None), ('wS', 'wW', [(31, 43)], CORRIDOR, 'walk', None),
    ('wS', 'd2', [], 4.0, 'stair', 'R2'),                                                                  # the cascade into the Pit
    ('wN', 'o0', [], CORRIDOR, 'stair', None),                                                             # rim -> Ossuary, straight up
    ('wSE', 'p1', [(52, 38)], CORRIDOR, 'stair', 'R4'),                                           # rim -> Pump, dog-leg down
    ('wE', 'fw', [(52, 50), (55, 50)], CORRIDOR, 'stair', None),                                                     # rim -> the Ford's west step
    # the court
    ('h0', 'p0', [], 4.0, 'stair', None), ('c2', 'p3', [], 3.0, 'stair', None), ('c1', 'ps', [], 3.0, 'stair', None),
    ('p0', 'H1', [], CORRIDOR, 'walk', None), ('p3', 'H1', [], CORRIDOR, 'walk', None), ('ps', 'H1', [], CORRIDOR, 'walk', None),
    ('h0', 'c2', [(26.5, 69), (26.5, 83)], CORRIDOR, 'walk', None), ('c2', 'c1', [(4, 86), (4, 70)], CORRIDOR, 'walk', None),
    ('c2', 'o1', [(32, 86)], CORRIDOR, 'stair', None),                                                     # court -> Ossuary
    ('c1', 'cw', [], CORRIDOR, 'stair', 'R6'), ('cw', 'ci2', [(4.5, 43.5)], TUNNEL, 'walk', None),                                             # court -> Cistern, the long wet stair
    # the Ossuary and the Bone Bridge
    ('o0', 'O', [], CORRIDOR, 'walk', None), ('o1', 'O', [], CORRIDOR, 'walk', None), ('O', 'bh', [], CORRIDOR, 'walk', None),
    ('bh', 'rh', [], 3.0, 'ramp', 'R5'),                                                                   # the Bone Bridge over the canal
    ('rh', 'RQ', [], CORRIDOR, 'walk', None), ('S2', 'RQ', [(100, 80)], CORRIDOR, 'walk', None), ('RQ', 'rq1', [], CORRIDOR, 'walk', None),
    ('RQ', 'rq2', [], CORRIDOR, 'walk', None), ('rq2', 'ml0', [(104, 98), (104, 104)], CORRIDOR, 'ramp', None), ('ml0', 'ML', [], CORRIDOR, 'walk', None),  # the mill stair winds up
    ('c1', 'ct0', [(0, 62)], TUNNEL, 'walk', None), ('ct0', 'CT', [], CORRIDOR, 'walk', None), ('CT', 'ct1', [], CORRIDOR, 'walk', None),
    ('ct1', 'lw', [(-12, 54), (-4, 46), (8, 48)], TUNNEL, 'ramp', None), ('lw', 'H2', [], TUNNEL, 'walk', None),           # the Catacomb Dive: a fourth way into the Pit
    ('rq1', 'bn', [(92, 68)], CORRIDOR, 'stair', None),                                                    # Reliquary -> Belfry
    # the Belfry and the Ford
    ('bn', 'BF', [], CORRIDOR, 'walk', None), ('BF', 'bs', [], CORRIDOR, 'walk', None), ('BF', 'be', [], CORRIDOR, 'walk', None),
    ('BF', 'fe', [(90, 54)], CORRIDOR, 'walk', None), ('fe', 'fm', [], 4.0, 'stair', None), ('fm', 'fw', [], 4.0, 'walk', None),   # the Ford: always open
    ('bs', 'ce0', [(96, 36)], CORRIDOR, 'stair', 'R3'),                                                    # Belfry -> Cellar
    ('be', 'bl0', [(112, 52)], CORRIDOR, 'stair', None),                                                   # Belfry -> Brine Larder
    # the east bank's stores
    ('ce0', 'CE', [], CORRIDOR, 'walk', None), ('CE', 'SL', [(112, 16)], CORRIDOR, 'walk', None), ('S4', 'SL', [], CORRIDOR, 'walk', None),
    ('bl0', 'BL', [], CORRIDOR, 'walk', None), ('BL', 'bl1', [], CORRIDOR, 'walk', None), ('S3', 'BL', [(130, 40)], CORRIDOR, 'walk', None),
    ('SL', 'bl1', [(118, 22), (116, 28)], CORRIDOR, 'walk', None),                                             # Sluice -> Larder: the brine stores join
    ('bl1', 'ut1', [], TUNNEL, 'ramp', None), ('ut1', 'ut2', [(92, 22), (80, 25.0667), (66, 26)], TUNNEL, 'walk', 'R7'), ('ut2', 'ls', [], TUNNEL, 'walk', None),  # the Undercroft winds under the canal
    # the west bank's waterworks: the Cistern tunnel climbs over a hump and drops again
    ('p1', 'PU', [], CORRIDOR, 'walk', None), ('PU', 'p0w', [], CORRIDOR, 'walk', None), ('PU', 'pe', [], CORRIDOR, 'walk', None),
    ('PU', 'sp', [], CORRIDOR, 'walk', None), ('sp', 'sf', [], TUNNEL, 'ramp', None), ('sf', 'H2', [], TUNNEL, 'walk', None),   # the Sump Stair: the waterworks' own way into the Pit
    ('p0w', 'tm', [(44, 22)], TUNNEL, 'stair', None), ('tm', 'ci1', [(32, 25)], TUNNEL, 'stair', None),
    ('ci1', 'CI', [], CORRIDOR, 'walk', None), ('CI', 'ci2', [], CORRIDOR, 'walk', None), ('S5', 'CI', [], CORRIDOR, 'walk', None),
    # the Pit
    ('d2', 'H2', [(29, 28.5), (30, 33), (33, 40)], TUNNEL, 'walk', None), ('ls', 'H2', [], TUNNEL, 'walk', None),
]

ROOMS = [
    dict(id='hall', label='Arrival Hall', poly=[(10, 44), (22, 44), (25, 47), (25, 53), (22, 56), (10, 56), (7, 53), (7, 47)], z=0, light='hearth'),
    dict(id='closet', label='', rect=(16, 38, 22, 42), z=0),
    dict(id='court', label='Charnel Court', poly=[(2, 66), (8, 63), (24, 64), (29, 70), (28, 86), (23, 91), (8, 90), (1, 84)], z=0, light='cold', top=9),
    dict(id='court-pit', label='', poly=[(6, 68), (24, 68), (23.5, 84), (20, 84.5), (7, 84), (5, 76)], z=-1.5),
    dict(id='rimW', label='', rect=(29, 42, 34, 58), z=0), dict(id='rimE', label='', rect=(46, 42, 51, 58), z=0),
    dict(id='rimN', label='The Well', rect=(29, 53, 51, 58), z=0), dict(id='rimS', label='', rect=(29, 42, 51, 47), z=0),
    dict(id='ossuary', label='Ossuary', rect=(40, 64, 56, 80), z=UP, top=9),
    dict(id='bridgehead', label='Bridgehead', rect=(56, 70, 62, 78), z=UP, top=9),
    dict(id='ford-w', label='The Ford', poly=[(52, 45), (57, 44), (58, 52), (52.5, 54)], z=DOWN, top=9), dict(id='ford-e', label='', poly=[(80, 45), (87, 46), (86, 53), (80, 52)], z=0, top=12),
    dict(id='reliquary', label='Reliquary', rect=(84, 72, 100, 96), z=UP, light='dim', top=8),
    dict(id='mill', label='Salt Mill', rect=(84, 96, 100, 110), z=5, light='dim', top=6),
    dict(id='catacomb', label='Catacomb', poly=[(-24, 68), (-18, 64), (-8, 66), (-4, 74), (-6, 84), (-14, 88), (-24, 82)], z=0, top=3.5),
    dict(id='belfry', label='The Belfry', poly=[(88, 44), (108, 44), (110, 48), (110, 60), (108, 64), (88, 64), (86, 60), (86, 48)], z=0, light='cold', top=9),
    dict(id='bell-loft', label='Bell Loft', rect=(100, 56, 108, 64), z=UP, top=9, note='a +2.5 mezzanine in the Belfry\'s north-east: the Red key under the bell; the canal and the Well seen from its west rail'),
    dict(id='cellar', label='Salt Cellar', rect=(96, 12, 110, 26), z=DOWN, top=3.2),
    dict(id='sluice', label='Sluice', rect=(114, 8, 130, 22), z=DOWN, light='dim'),
    dict(id='larder', label='Brine Larder', poly=[(110, 34), (116, 30), (128, 32), (132, 40), (128, 49), (116, 50), (109, 44)], z=DOWN, top=12),
    dict(id='pump', label='Pump Room', rect=(50, 18, 66, 32), z=DOWN, light='dim', top=8),
    dict(id='cistern', label='Cistern', poly=[(8, 32), (14, 28), (22, 30), (26, 37), (22.5, 37.5), (15.5, 37.5), (15.5, 43.5), (12, 43.5), (6, 40)], z=DOWN),
    dict(id='lair', label='The Pit', poly=[(22, 30), (36, 24), (50, 28), (57, 38), (56, 56), (48, 64), (30, 62), (20, 52), (18, 40)], z=DEEPZ, light='cold'),
    dict(id='vault', label='Vault', rect=(58, 56, 66, 64), z=DEEPZ),
]
ENTRANCES = ['S1', 'S2', 'S3', 'S4', 'S5']
COURTS = {'H1': 'H1', 'H2': 'H2', 'H3': 'BF'}

CRAWLS = [
    dict(id='crawl-r3', a=(100, 44.5), b=(102, 25.5), z=0, packFits=False, note='beside the Belfry-Cellar stair; ends 2.5 m above the Cellar floor', purpose='reach the R3 lever in the Cellar; the scout drops, the pack takes the stair'),
    dict(id='crawl-r6', a=(8, 64), b=(10, 48), z=0, packFits=False, note='beside the Court-Cistern stair; a drop at its end', purpose='reach the R6 lever by the Cistern stair foot'),
    dict(id='crawl-r7', a=(104.5, 29.8), via=[(100, 31)], b=(96, 25.5), z=DEEPZ, packFits=False, note='beside the Undercroft mouth', purpose='reach the R7 lever on the tunnel side'),
    dict(id='crawl-sealed', a=(110, 56), b=(116, 60.5), z=0, packFits=False, note='a gap behind the Belfry\'s east wall', purpose='the one squeeze that leads somewhere new: the Sealed Burial'),
]
UPPER = dict(
    z=5.0, top=24.0, mainTop=4.6,
    tallRooms=['belfry', 'court', 'rimW', 'rimE', 'rimN', 'rimS', 'bridgehead', 'reliquary'],
    platforms=[],
    walkways=[],
    railGaps=[
              dict(id='mill-drop', a=(88, 96), b=(92, 96), note='one-way drop: Salt Mill rail -> the Reliquary floor, 2.5 m: the Curing Room\'s short way home')],
)
LADDERS = [
    dict(id='closet-ladder', at=(19, 40), baseZ=DEEPZ, height=5.0, yaw=0.0, oneWay=True, note='from the Pit\'s west end up into the hall closet', purpose='the Pit\'s one-way way home, pack included'),
    dict(id='belfry-ladder', at=(100, 57), baseZ=0.0, height=2.5, yaw=180.0, kind='barred', oneWay=False, note='Belfry floor up to the loft; its foot is barred (P5) until the lever on the loft is pulled, reached by the Reliquary\'s rail drop', purpose='the loft holds the Red key and the best view in the district'),
]
LEDGE_RAIL = 0.6  # P6: the ledge rails are a 0.6 m parapet (the v5 ruling: the Pit is seen from the rim over it; a hop lands on the Pit floor)
DEEP_WATER_RAIL = 1.0  # P6: the canal banks stay jump-proof (its 2 m bed has no way out)
HOLES = [
    dict(id='well', level='main', rect=(34, 44, 46, 56), kind='open', rail=0.6, note='the Well: rim at 0, Pit at -5, open to the sky-light at +24'),
    dict(id='well-upper', level='upper', rect=(34, 44, 46, 56), kind='open'),
    dict(id='closet-well', level='main', rect=(19.0, 39.25, 20.5, 40.75), kind='open'),
]
EXTRA_WALKS = [
    dict(id='sc2-door', pts=[(19, 42), (19, 44)], width=2.5, note='closet to hall, barred from the hall side'),
    dict(id='vault-passage', level='deep', pts=[(56, 60), (58, 60)], width=2.5, note='Pit to the vault door'),
]
EXTRA_RAMPS = [
    dict(id='bone-bridge', a=(62, 74, UP), b=(84, 74, UP), width=3.0, note='the Bone Bridge: 22 m over the canal at +2.5; R5 at its west head'),
    dict(id='chain-crossing', a=(66, 26, DOWN), b=(96, 24, DOWN), width=2.5, note='the Chain Crossing: a causeway lowered from the Cellar side (shortcut ChainCrossing), the pack\'s short way between the two banks\' waterworks'),
    dict(id='sump-stair', a=(50, 26, DOWN), b=(42, 34, DEEPZ), width=2.5, note='the Sump Stair: Pump Room down into the Pit (open), from the Pump\'s west wall'),
    dict(id='larder-undercroft', a=(112, 34, DOWN), b=(104, 28, DEEPZ), width=2.5, note='Brine Larder down into the Undercroft'),
    dict(id='mill-stair-a', a=(98, 94, UP), b=(104, 98, 3.3), width=3.0, note='the mill stair: Reliquary up to the Salt Mill, round its east side'), dict(id='mill-stair-b', a=(104, 98, 3.3), b=(104, 104, 4.2), width=3.0), dict(id='mill-stair-c', a=(104, 104, 4.2), b=(98, 106, 5), width=3.0),
    dict(id='catacomb-dive-a', a=(-10, 64, 0), b=(-12, 54, -2.5), width=2.5, note='the Catacomb Dive winds down into the Pit\'s west end'), dict(id='catacomb-dive-b', a=(-12, 54, -2.5), b=(-4, 46, DEEPZ), width=2.5), dict(id='catacomb-dive-c', a=(-4, 46, DEEPZ), b=(8, 48, DEEPZ), width=2.5), dict(id='catacomb-dive-d', a=(8, 48, DEEPZ), b=(21, 47, DEEPZ), width=2.5),
]
SHORTCUTS = [
    dict(id='SC2', at=(19, 42), yaw=90.0, spanCm=250.0, leverSide=-1, oneWay=True, channel='Mechanism.Channel.Warrens.Shortcut.SC2', note='closet -> hall; lever in the closet'),
    dict(id='ChainCrossing', at=(67, 26), yaw=90.0, spanCm=250.0, leverSide=1, oneWay=True, channel='Mechanism.Channel.Warrens.Shortcut.Chain', note='the Chain Crossing: barred at the Pump end, lowered by the Sluice hand-wheel (P2); from then on both ways'),
]
LIGHTS = [
    dict(at=(16, 50, 3.0), kind='hearth'), dict(at=(40, 50, 8.0), kind='shaft'), dict(at=(40, 50, -3.0), kind='cold'),
    dict(at=(15, 76, 5.0), kind='cold'), dict(at=(104, 50, 16.0), kind='cold'), dict(at=(98, 54, 6.0), kind='cold'), dict(at=(92, 80, 5.1), kind='dim'),
    dict(at=(58, 25, 0.1), kind='dim'), dict(at=(122, 15, 0.1), kind='dim'), dict(at=(120, 40, 0.1), kind='dim'), dict(at=(16, 37, -0.5), kind='dim'), dict(at=(48, 72, 5.1), kind='dim'),
    dict(at=(69, 49, 1.0), kind='foyer'), dict(at=(92, 103, 7.6), kind='dim'), dict(at=(-14, 76, 3.0), kind='cold'),
]
PILLARS = [
    dict(level='main', rect=(8, 72, 11, 75)), dict(level='main', rect=(21, 77, 24, 80)),
    dict(level='main', rect=(90, 47, 92, 49)), dict(level='main', rect=(90, 59, 92, 61)),
    dict(level='deep', rect=(26, 32, 29, 35)), dict(level='deep', rect=(50, 56, 53, 59)),
]
LOW_LINKS = [('ut1', 'ut2'), ('ut2', 'ls'), ('p0w', 'tm'), ('tm', 'ci1'), ('d2', 'H2'), ('c1', 'ct0'), ('ct1', 'lw'), ('lw', 'H2'), ('cw', 'ci2')]
LOW_ROOF = 2.2
LOCKS = [
    dict(id='vault', door=dict(at=(57, 60), yaw=0.0, spanCm=250.0, level='deep'), lock=dict(at=(56, 58.3), yaw=90.0, level='deep'),
         key='Red', keyAt=(104, 60, 2.85), channel='Mechanism.Channel.Keys.Red', note='the key atop the 30cm plinth under the bell on the Belfry loft, across the canal from the Vault'),
]
PUZZLES = [
    dict(id='P1', kind='Red key door', at=(57, 60, DEEPZ), needsAt=(104, 60, UP), needsNote='the key under the bell on the Belfry loft: other bank, other landmark'),
    dict(id='P2', kind='sliding cage span section', at=(68.15, 20, DOWN), needsAt=(122, 12, DOWN), needsNote='the Sluice windlass extends the stored east-bank cage across the gap; both end screens remain closed until the span is seated, then latch open for cargo return', existing='FreeTurn windlass + translating cage + terminal end guards'),
    dict(id='P3', kind='Mourner cache gate (latched)', at=(100, 76, UP), needsAt=(42, 66, UP), needsNote='the pack plate at the Ossuary\'s west end: set the pack down west, the gate latches east, cross the Bone Bridge', latch=True),
    dict(id='P4', kind='Bellkeeper dial lock', at=(106, 44, 0), needsAt=(48.5, 50, 0), needsNote='the three glyphs painted on the Bell Tower\'s west face, read from the Well\'s east rim across the canal'),
    dict(id='P5', kind='barred ladder foot (Belfry)', at=(104, 56, 0), needsAt=(102, 60, UP), needsNote='the lever on the loft; the loft is first reached by the Reliquary stair\'s rail drop'),
    dict(id='P6', kind='SC2 barred closet door', at=(19, 42, 0), needsAt=(19, 40, DEEPZ), needsNote='climb the closet ladder out of the Pit'),
    dict(id='P7', kind='Curing Room (support objective)', at=(88, 106, 5), needsAt=(98, 54, 0), needsNote='the Curing Room: the hunted part is brined here before it travels (the run\'s second required stop); the vat, the drying racks, a plinth for the pack'),
]
NICHES = [
    dict(id='court-pack', rect=(3, 88, 7, 91), z=0, family='P', note='pack plinth at the court\'s north-west'),
    dict(id='court-forage', rect=(-3, 74, 1, 78), z=0, family='F', note='mushrooms in the west burial niche'),
    dict(id='court-omen', rect=(29, 72, 31, 74), z=0, family='O', note='eyes in the east wall niche'),
    dict(id='court-threat', rect=(10, 59, 14, 63), z=0, family='T', note='sentry alcove south of the arena'),
    dict(id='ossuary-husk', rect=(44, 80, 48, 83), z=UP, family='F', note='husk spill in the north niche'),
    dict(id='ossuary-rest', rect=(36, 72, 40, 75), z=UP, family='N', note='lantern rest by the court stair'),
    dict(id='bridge-omen', rect=(72, 77, 74, 79), z=UP, family='O', note='chains swaying under the Bone Bridge'),
    dict(id='mourner', rect=(100, 74, 106, 78), z=UP, family='C', authoredReward=True, note='Mourner: guaranteed authored Tallow behind the occupancy-plate gate (P3)'),
    dict(id='reliquary-rest', rect=(80, 90, 84, 93), z=UP, family='N', note='lantern rest by the S2 mouth'),
    dict(id='bellkeeper', rect=(103, 40, 109, 44), z=0, family='C', note='Bellkeeper\'s Confession behind the dial lock (P4)'),
    dict(id='belfry-threat', rect=(86, 40, 90, 44), z=0, family='T', note='sentry niche south of the tower'),
    dict(id='belfry-pack', rect=(110, 59, 114, 63), z=0, family='P', note='pack plinth by the larder stair'),
    dict(id='sealed-burial', rect=(116, 60, 121, 66), z=0, family='C', note='the Sealed Burial behind crawl-sealed'),
    dict(id='cellar-salt', rect=(96, 8, 100, 12), z=DOWN, family='F', note='salt crystals'),
    dict(id='porter', rect=(130, 12, 138, 18), z=DOWN, family='C', note='Porter\'s Wager off the Sluice'),
    dict(id='larder-forage', rect=(132, 36, 136, 40), z=DOWN, family='F', note='brined stores: a wade to reach them'),
    dict(id='larder-ledge', rect=(118, 50, 122, 53), z=-1.0, family='N', note='a dry ledge 1.5 m above the brine: a ledge hop from the stair'),
    dict(id='larder-threat', rect=(112, 28, 116, 31), z=DOWN, family='T', note='something under the water'),
    dict(id='pump-omen', rect=(46, 20, 50, 23), z=DOWN, family='O', note='swaying chains in the west niche'),
    dict(id='pump-rest', rect=(66, 28, 70, 31), z=DOWN, family='N', note='lantern rest at the chain crossing'),
    dict(id='cistern-forage', rect=(4, 34, 8, 38), z=DOWN, family='F', note='mushroom bed across the basin'),
    dict(id='pit-pack', rect=(20, 54, 24, 58), z=DEEPZ, family='P', note='pack plinth at the Pit\'s north-west'),
    dict(id='pit-rest', rect=(18, 44, 22, 48), z=DEEPZ, family='N', note='lantern rest at the lair\'s west wall'),
    dict(id='pit-forage', rect=(52, 40, 56, 44), z=DEEPZ, family='F', note='deep mushrooms by the Undercroft mouth'),
    dict(id='pit-shelf', rect=(30, 62, 36, 65), z=-3.0, family='O', note='a root shelf 2 m up the Pit\'s north wall: eyes; a ledge hop from the cascade'),
    dict(id='mill-pack', rect=(80, 100, 84, 103), z=5, family='P', note='pack plinth by the vat'), dict(id='mill-threat', rect=(80, 105, 84, 109), z=5, family='T', note='something among the millstones'),
    dict(id='mill-rest', rect=(96, 110, 100, 113), z=5, family='N', note='lantern rest at the mill\'s north'),
    dict(id='catacomb-husk', rect=(-28, 72, -24, 76), z=0, family='F', note='husk spill in the deepest niche'), dict(id='catacomb-cache', rect=(-12, 86.5, -6, 90.5), z=0, family='C', note='the Catacomb cache: a sealed drawer'),
    dict(id='catacomb-omen', rect=(-4, 78, -2, 80), z=0, family='O', note='eyes in the east niche'),
]
WATER = [
    dict(id='canal', poly=[(70, -4), (78, -4), (77, 20), (79, 40), (77, 60), (79, 84), (77, 104), (69, 104), (71, 80), (69, 60), (71, 36), (69, 16)], z=DOWN, depth=2.0, top=20, note='the Drowned Canal: 2 m deep, impassable; the district\'s edge'),
    dict(id='ford', rect=(68, 46, 80, 52), z=DOWN, depth=0.4, top=20, note='the Ford: knee-deep, slow, always open'),
    dict(id='cistern-basin', poly=[(10, 32), (20, 32), (21.5, 36.5), (15, 37), (15, 43), (10, 42)], z=DOWN, depth=0.4, note='the Cistern pool'),
    dict(id='larder-water', poly=[(112, 34), (126, 34), (128, 46), (116, 48)], z=DOWN, depth=0.4, note='the Brine Larder: knee-deep stores'),
]
PROPS = [
    dict(kind='station', at=(40, 55.5, 0), size=(1.6, 1.6, 7.5), note='THE HOIST over the north rim of the Well'),
    dict(kind='pillar', at=(104, 50, 0), size=(4.0, 4.0, 22.0), note='THE BELL TOWER: 22 m, the bell cold-lit at +16, heard across the canal'),
    dict(kind='stack', at=(102, 50, 2.0), size=(0.3, 4.0, 2.0), yaw=0, note='the three glyphs on the tower\'s west face (P4), read from the Well\'s east rim'),
    dict(kind='statue', at=(15, 88, 0), size=(2.0, 1.2, 4.5), yaw=-90, note='split mourner: the Court landmark'),
    dict(kind='plinth', at=(10, 47.5, 0), size=(1.2, 1.2, 0.3), note='pack plinth by the Camp Door'),
    dict(kind='root', at=(35, 46, DEEPZ), size=(1.4, 1.4, 14.0), note='roots down the west wall of the Well'),
    dict(kind='stack', at=(52, 68, UP), size=(6.0, 1.0, 2.6), note='bone stacks'), dict(kind='stack', at=(50, 76, UP), size=(6.0, 1.0, 2.6)),
    dict(kind='plinth', at=(42, 66, UP), size=(2.0, 2.0, 0.3), note='the pack plate (P3)'),
    dict(kind='sarcophagus', at=(88, 84, UP), size=(3.0, 1.5, 1.2), note='the reliquary tomb'),
    dict(kind='plinth', at=(104, 60, UP), size=(0.8, 0.8, 0.3), note='the key plinth under the bell (P1)'),
    dict(kind='station', at=(108, 46, 0), size=(1.0, 0.4, 1.4), note='the dial lock (P4)'),
        dict(kind='pillar', at=(54, 22, DOWN), size=(2.0, 2.0, 6.0), note='the pump: the west bank\'s audio landmark'),
    dict(kind='pillar', at=(122, 12, DOWN), size=(1.0, 1.0, 1.6), note='the hand-wheel (P2)'),
    dict(kind='stack', at=(110, 20, DOWN), size=(24.0, 0.4, 0.2), note='the chain along the Cellar floor, from the crossing to the wheel (P2 tell)'),
    dict(kind='stack', at=(100, 16, DOWN), size=(2.0, 2.0, 1.4), note='salt crystals'),
    dict(kind='chimes', at=(98, 54, 0), size=(6.0, 0.2, 3.5), yaw=0, note='bone chimes under the tower'),
    dict(kind='root', at=(24, 34, DOWN), size=(1.2, 1.2, 5.0), note='roots through the Cistern roof'),
    dict(kind='candles', at=(12, 46, 0), size=(0.9, 0.9, 0.5), note='tallow'), dict(kind='candles', at=(54, 66, UP), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(90, 46, 0), size=(0.9, 0.9, 0.5), note='tallow'), dict(kind='candles', at=(22, 58, DEEPZ), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(82, 50, 0), size=(0.9, 0.9, 0.5), note='tallow: the Ford\'s east step'),
    dict(kind='station', at=(88, 106, 5), size=(2.4, 1.6, 1.4), note='the brine vat (P7): the Curing Room'), dict(kind='pillar', at=(95, 100.5, 5), size=(2.5, 2.5, 2.0), note='the millstone'),
    dict(kind='sarcophagus', at=(-18, 80, 0), size=(3.0, 1.5, 1.2), note='the Catacomb\'s one open tomb'),
]
ANCHOR_AT = {'R1': (22, 63), 'R2': (39, 41), 'R3': (96, 34), 'R4': (49.5, 41.5), 'R5': (63, 74), 'R6': (5, 60), 'R7': (100, 26)}
LEVER_NODE = {'R3': 'ce0', 'R6': 'cw', 'R7': 'ut1'}
MAX_ACTIVE_CACHES = 2
DROP_GAPS = [dict(id='loft-drop', a=(100, 58.5), b=(100, 62), z=UP, note='the loft mezzanine\'s west edge: open, the one-way drop to the Belfry floor')]
WINDOWS = [  # P5b: framed openings where a view crosses rock (sill >= 1.2 m over the higher floor beside the cut)
    dict(id='ford-north', a=(60, 50.5), b=(60, 55.5), sill=1.2, head=8.0, note='the Ford corridor\'s north wall and the rock to the rim, opened above a parapet: the Well and its hoist seen from the Ford, the shaft light from the loft'),
    dict(id='ford-rim', a=(52, 50.5), b=(52, 53.75), sill=1.2, head=8.0, note='the rim\'s east wall over the Ford\'s west step'),
    dict(id='belfry-west', a=(82, 52.5), b=(82, 58.5), sill=1.2, head=8.0, note='the Belfry\'s west wall above the canal: the loft rail looks across to the Well'),
    dict(id='bridge-bank', a=(62.37, 69.76), b=(63.25, 68.19), sill=3.7, head=9.0, note='the canal\'s west bank under the Bone Bridge: the hoist seen from the bridge'),
    dict(id='ossuary-rim', a=(49.07, 62.3), b=(49.95, 60.73), sill=3.7, head=9.0, note='the Ossuary\'s south-east corner to the Well'),
    dict(id='bridge-east', a=(81.72, 65.35), b=(83.56, 67.73), sill=4.0, head=11.0, note='the canal\'s east bank to the Belfry: the bell seen from the bridge'),
    dict(id='larder-belfry', a=(110.92, 47.44), b=(109.34, 44.9), sill=6.0, head=12.0, note='a roof break between the Brine Larder and the Belfry: the bell overhead'),
]

INSTANCES = [
    dict(id='Hub', label='LI_Warrens_Hub', asset='LI_Warrens_Hub', z=0, rect=(4, 36, 54, 60),
         ports=[dict(id='camp', at=(4, 50, 0), width=3, kind='door'), dict(id='court', at=(16, 58, 0), width=3, kind='door'), dict(id='ossuary', at=(40, 58, 0), width=3, kind='stair'),
                dict(id='pump', at=(44, 38, 0), width=3, kind='stair'), dict(id='ford', at=(52, 50, 0), width=3, kind='stair'), dict(id='cascade', at=(44, 40, 0), width=4, kind='stair'), dict(id='closet', at=(19, 40, -5), width=1, kind='ladder')],
         note='the Arrival Hall, closet, the Well, its rims and the hoist'),
    dict(id='Court', label='LI_Warrens_Court', asset='LI_Warrens_Court', z=0, rect=(-4, 60, 30, 94),
         ports=[dict(id='hall', at=(22, 62, 0), width=3, kind='door'), dict(id='ossuary', at=(30, 86, 0), width=3, kind='stair'), dict(id='cistern', at=(6, 60, 0), width=3, kind='stair')]),
    dict(id='Ossuary', label='LI_Warrens_Ossuary', asset='LI_Warrens_Ossuary', z=2.5, rect=(36, 60, 64, 84),
         ports=[dict(id='rim', at=(42, 60, 2.5), width=3, kind='stair'), dict(id='court', at=(36, 80, 2.5), width=3, kind='stair'), dict(id='bridge', at=(62, 74, 2.5), width=3, kind='bridge')]),
    dict(id='Waterworks-W', label='LI_Warrens_WaterworksW', asset='LI_Warrens_WaterworksW', z=-2.5, rect=(4, 14, 70, 36),
         ports=[dict(id='rim', at=(48, 36, -2.5), width=3, kind='stair'), dict(id='court', at=(12, 36, -2.5), width=3, kind='stair'), dict(id='chain', at=(66, 26, -2.5), width=2.5, kind='bridge'),
                dict(id='sump', at=(48, 34, -2.5), width=2.5, kind='stair'), dict(id='S5', at=(16, 26, -2.5), width=3, kind='door')],
         note='Pump Room, Cistern, the humped tunnel between them'),
    dict(id='Pit', label='LI_Warrens_Pit', asset='LI_Warrens_Pit', z=-5, rect=(16, 22, 68, 66),
         ports=[dict(id='cascade', at=(46, 30, -5), width=4, kind='stair'), dict(id='sump', at=(44, 38, -5), width=2.5, kind='stair'), dict(id='undercroft', at=(56, 30, -5), width=2.5, kind='crawl'), dict(id='closet', at=(19, 40, -5), width=1, kind='ladder')]),
    dict(id='Canal', label='LI_Warrens_Canal', asset='LI_Warrens_Canal', z=-2.5, rect=(66, -4, 88, 104),
         ports=[dict(id='bridge-w', at=(66, 74, 2.5), width=3, kind='bridge'), dict(id='bridge-e', at=(88, 74, 2.5), width=3, kind='bridge'), dict(id='ford-w', at=(66, 49, -2.5), width=4, kind='door'),
                dict(id='ford-e', at=(88, 49, 0), width=4, kind='stair'), dict(id='chain-w', at=(66, 26, -2.5), width=2.5, kind='bridge'), dict(id='chain-e', at=(88, 24, -2.5), width=2.5, kind='bridge')],
         note='the canal, the Ford, both bridges: the edge is one tile; the Undercroft passes under it on the Brineworks tile'),
    dict(id='Belfry', label='LI_Warrens_Belfry', asset='LI_Warrens_Belfry', z=0, rect=(84, 38, 124, 68),
         ports=[dict(id='ford', at=(88, 49, 0), width=4, kind='stair'), dict(id='reliquary', at=(92, 68, 0), width=3, kind='stair'), dict(id='cellar', at=(96, 38, 0), width=3, kind='stair'), dict(id='larder', at=(112, 50, 0), width=3, kind='stair')],
         note='the Bell Tower, its loft, the dial lock, the Sealed Burial'),
    dict(id='Reliquary', label='LI_Warrens_Reliquary', asset='LI_Warrens_Reliquary', z=2.5, rect=(80, 66, 108, 102),
         ports=[dict(id='bridge', at=(84, 74, 2.5), width=3, kind='bridge'), dict(id='belfry', at=(92, 66, 2.5), width=3, kind='stair'), dict(id='S2', at=(110, 80, 2.5), width=3, kind='door'), dict(id='mill', at=(100, 94, 2.5), width=3, kind='stair')]),
    dict(id='Mill', label='LI_Warrens_Mill', asset='LI_Warrens_Mill', z=5, rect=(78, 92, 110, 116),
         ports=[dict(id='reliquary', at=(100, 94, 2.5), width=3, kind='stair'), dict(id='drop', at=(90, 96, 5), width=2, kind='drop')], note='the Salt Mill: the Curing Room wing (P7) above the Reliquary'),
    dict(id='Catacomb', label='LI_Warrens_Catacomb', asset='LI_Warrens_Catacomb', z=0, rect=(-28, 40, -2, 92),
         ports=[dict(id='court', at=(-2, 64, 0), width=2.5, kind='crawl'), dict(id='pit', at=(-2, 46, -4), width=2.5, kind='stair')], note='the far west bead; its dive is a fourth way into the Pit'),
    dict(id='Brineworks', label='LI_Warrens_Brineworks', asset='LI_Warrens_Brineworks', z=-2.5, rect=(88, 4, 144, 54),
         ports=[dict(id='belfry-cellar', at=(96, 30, -2.5), width=3, kind='stair'), dict(id='belfry-larder', at=(112, 50, -2.5), width=3, kind='stair'), dict(id='chain', at=(96, 24, -2.5), width=2.5, kind='bridge'),
                dict(id='undercroft', at=(88, 26, -5), width=2.5, kind='crawl'), dict(id='S3', at=(140, 40, -2.5), width=3, kind='door'), dict(id='S4', at=(122, 0, -2.5), width=3, kind='door')],
         note='Salt Cellar, Sluice, Brine Larder, the Undercroft under the canal'),
]
VIEWS = [
    dict(id='ford-hoist', **{'from': (74, 48.5, -2.5), 'to': (40, 55.5, 7)}, label='The Ford -> the hoist (and, turning, the bell): both landmarks from one spot'),
    dict(id='ford-bell', **{'from': (74, 48.5, -2.5), 'to': (104, 50, 16)}, label='The Ford -> the bell'),
    dict(id='bridge-hoist', **{'from': (73, 74, 2.5), 'to': (40, 55.5, 7)}, label='Bone Bridge -> the hoist over the Well'),
    dict(id='bridge-bell', **{'from': (73, 74, 2.5), 'to': (104, 50, 16)}, label='Bone Bridge -> the bell'),
    dict(id='rim-glyphs', **{'from': (48, 50, 0), 'to': (102, 50, 2)}, label='Well east rim -> the glyphs on the tower\'s west face (P4), across the canal'),
    dict(id='hall-hoist', **{'from': (24.5, 49, 0), 'to': (40, 55.5, 7)}, label='Camp Door -> the hoist'),
    dict(id='loft-well', **{'from': (100.5, 60, UP), 'to': (40, 50, 8)}, label='Belfry loft -> the Well\'s shaft light across the canal'),
    dict(id='belfry-pit', **{'from': (90, 54, 0), 'to': (40, 50, 8)}, label='Belfry west arch -> the Well\'s shaft light over the Ford'),
    dict(id='pit-hoist', **{'from': (40, 46, -5), 'to': (40, 55.5, 7)}, label='Pit -> up the shaft'),
    dict(id='larder-bell', **{'from': (120, 40, -2.5), 'to': (104, 50, 16)}, label='Brine Larder -> the bell overhead through the roof break'),
]
TRANSITIONS = [
    dict(id='t-camp', at=(5, 50, 0), kind='reveal', label='camp stair -> the hall; the Well framed by the east door'),
    dict(id='t-court', at=(19, 61, 0), kind='turn', label='hall -> Court: bent passage, R1'),
    dict(id='t-ossuary', at=(42, 60, 1.2), kind='stair', label='rim N -> Ossuary: straight stair up, the hoist behind you'),
    dict(id='t-cascade', at=(36, 35, -2.5), kind='stair', label='rim S -> Pit: the cascade (R2)'),
    dict(id='t-pump', at=(50, 40, -1.2), kind='stair', label='rim S -> Pump: dog-leg down (R4)'),
    dict(id='t-ford-w', at=(53, 50, -1.2), kind='stair', label='rim E -> down to the Ford'),
    dict(id='t-ford', at=(74, 49, -2.5), kind='reveal', label='the Ford: open air, both landmarks'),
    dict(id='t-ford-e', at=(85, 49, -1.2), kind='stair', label='Ford -> Belfry: up the east step'),
    dict(id='t-bridge', at=(73, 74, 2.5), kind='bridge', label='the Bone Bridge, 22 m over the canal (R5)'),
    dict(id='t-chain', at=(74, 20, -2.2), kind='bridge', label='the Chain Crossing: sliding cage spans the gap after the Sluice windlass is hauled (P2)'),
    dict(id='t-sump', at=(46, 30, -3.8), kind='stair', label='Pump -> Pit: the Sump Stair, the waterworks\' own way down'),
    dict(id='t-undercroft', at=(80, 26, -5), kind='squeeze', label='the Undercroft: low winding tunnel under the canal (R7)'),
    dict(id='t-wetstair', at=(5, 56, -1.2), kind='stair', label='Court -> Cistern: the long wet stair (R6)'),
    dict(id='t-hump', at=(38, 21, -1.0), kind='squeeze', label='Cistern -> Pump: low tunnel that climbs a hump and drops again'),
    dict(id='t-relbelfry', at=(92, 68, 1.2), kind='stair', label='Reliquary -> Belfry: stair down under the tower'),
    dict(id='t-cellar', at=(96, 36, -1.2), kind='stair', label='Belfry -> Cellar (R3)'),
    dict(id='t-larder', at=(112, 52, -1.2), kind='stair', label='Belfry -> Brine Larder: down into the water'),
    dict(id='t-ledge', at=(119, 50, -1.0), kind='jump', label='ledge hop: larder stair -> the dry shelf above the brine'),
    dict(id='t-pitshelf', at=(33, 62, -3.0), kind='jump', label='ledge hop: cascade foot -> the root shelf on the Pit\'s north wall'),
    dict(id='t-loftdrop', at=(100, 60, UP), kind='drop', label='one-way drop: loft mezzanine -> Belfry floor (2.5 m)'),
    dict(id='t-millstair', at=(104, 101, 3.8), kind='stair', label='Reliquary -> Salt Mill: the mill stair winds up to +5'),
    dict(id='t-milldrop', at=(90, 96, 5), kind='drop', label='one-way drop: Salt Mill -> Reliquary (2.5 m)'),
    dict(id='t-catacomb', at=(-2, 63, 0), kind='squeeze', label='Court -> Catacomb: low tunnel round the back'),
    dict(id='t-catacombdive', at=(-8, 50, -3), kind='stair', label='the Catacomb Dive: winding down into the Pit\'s west end'),
]
LANDMARK = dict(id='well', label='THE WELL (west) and THE BELL TOWER (east)', at=(72, 50, 0),
                faces=[dict(dir='W', label='the Well: hoist, shaft light, the Pit glow'), dict(dir='E', label='the Bell Tower: 22 m, cold bell light, heard everywhere'),
                       dict(dir='N', label='the Bone Bridge'), dict(dir='S', label='the Chain Crossing and the Undercroft')])
NOTES = dict(
    thesis='Two landmarks and one edge. The canal splits the district into two banks you can always name; the Well and the Bell Tower '
           'stand one on each. Three crossings, each a different beat, and the Ford in the middle shows both towers at once.',
    principles=['Lynch: a real edge (impassable water) plus two landmarks gives triangulation, not just recognition',
                'Dark Souls distant views: Parish and Sen\'s see each other; here the rim reads the tower\'s glyphs and the loft sees the Well',
                'Thresholds: every crossing is a beat (a long bridge, a wade, a low tunnel); bank-internal connectors wind and change height (the hump tunnel, the wet stair)',
                'Cavern and dungeon: built rooms (Ossuary, Reliquary, Cellar, Pump) are orthogonal; grown ones (Court, Cistern, Larder, Pit, the canal) are not',
                'Sound as weenie: the bell and the pump are the two audio landmarks, one per bank',
                'Deep Dish / Tunic: the missing Chain Crossing span and its far-bank socket are seen from the Pump before the Sluice windlass is found (P2)',
                'Lunacid rule: every loop\'s far point is unique (loft with the bell, Brine Larder wade, Sealed Burial)'],
    changes=['Footprint 178 x 130 m: +2.5 / 0 / -2.5, the Pit at -5 and Salt Mill at +5; Belfry loft is +2.5',
             'Chime Hall becomes the Belfry (H3) under a 22 m tower; the Reliquary and the brine stores move to the east bank',
             'P4\'s glyphs move onto the tower, read from the Well rim: the two landmarks exchange information',
             'The Drowned Gallery becomes the Undercroft under the canal (graph link, R7); the Sump Stair is open; P2 is the Chain Crossing',
             'Two ledge hops (Larder shelf, Pit root shelf) as pocket rewards off the main floors',
             'Eleven Level Instance tiles; the canal is its own tile (water, Ford, both bridges)'],
    sizing='Target 15-20 min inside Warrens; not yet established by timed play. Current manual diagnostic is combat quarry + Mill Mushroom/Cellar Bellnut + living chef/cargo return; edible quarry anatomy and extraction enforcement remain absent.',
    risks=['Bigger map, longer walks: the Ford is the always-open crossing; other cargo crossings require R5 or the seated P2 sliding span',
           'Two hunt courts (Court, Pit) on the west bank and one (Belfry) on the east: a Belfry contract means crossing twice with cargo',
           'Water as an edge needs real impassability (depth, no climb-out) that the viewer only labels',
           'The Bell Tower\'s height needs the Belfry tile to be 24 m tall; roof breaks for the Larder view are art'],
)

ENTRY_KIT_TOOLS = True
ENTRY_KIT_LIGHT = True

# Persistent, one-shot fixture proxies wait for their actual Jolt support. All
# subsequent item pickup/drop/forage behavior stays in the original compositions.
PLACED_PICKUP_STARTUP = dict(
    boundsFile='data/warrens_v8c_pickup_bounds.json', expectedCount=34,
    # Existing editor supply authoring puts tallow 130cm beside the pack
    # (lantern90cm +40cm); preserve those saved fixtures exactly.
    entryTallowSideOffsetM=1.3,
    # At S1, +130cm lies inside the north foyer wall. The intended +100cm
    # positions retain clear body envelopes; no source wall is changed.
    entryTallowSideOffsetByEntryM=dict(S1=1.0),
    existingAtById=dict(vault_key=[104,60,2.5],
        S1_entry_Tallow_0=[-1.8,54.1,0.6],S1_entry_Tallow_1=[-2.2,54.1,0.6]),
    supportById=dict(vault_key=2.8,C_Vault_Ration=-5,C_Vault_Tallow=-5,C_Mourner_Tallow=2.5),
    entrySupportZ=dict(S1=0,S2=2.5,S3=-2.5,S4=-2.5,S5=-2.5),
)

# Local prototype fixtures. Crawler quarry has no edible-part output; the
# Mushroom/Bellnut cargo-return contract is an explicitly manual diagnostic.
LOCAL_FIXTURES = [
    dict(id='C_Vault_Ration', cls='Mars_WorldItem_Ration_EntityScript', at=[62, 59, -4.6]),
    dict(id='C_Vault_Tallow', cls='Mars_WorldItem_Tallow_EntityScript', at=[63, 61, -4.6]),
    dict(id='C_Mourner_Tallow', cls='Mars_WorldItem_Tallow_EntityScript', at=[103, 76, 2.9]),
    dict(id='C_Mill_Mushroom', cls='Mars_Expedition_MushroomBed_EntityScript', at=[92, 102, 5]),
    dict(id='C_Cellar_Bellnut', cls='Mars_Forage_BellnutVine_EntityScript', at=[99, 18, -2.5]),
]

BELLKEEPER = dict(
    phrase=['Diamond', 'Triangle', 'Cross'], startGlyphs=['Square', 'Square', 'Square'],
    panel=dict(at=[108, 46.22, 1.2], pitch=-90, yaw=90, materials=dict(
        BodyMaterialOverride='/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX10',
        FaceMaterialOverride='/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_BellkeeperPrimaryColor',
        ControlMaterialOverride='/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX10',
        GlyphMaterialOverride='/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_BellkeeperPrimaryColor',
        IndicatorMaterialOverride='/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_BellkeeperPrimaryColor')),
    chain=dict(at=[106.5, 46.22, 2.3], yaw=90), bellAt=[106.5, 46.45, 2.45],
    vent=dict(at=[108.8, 45.8, -0.35], yaw=90, pushImpulseLocalCmS=[400, 0, 120]),
    clue=dict(at=[101.82, 50, 3], pitch=-90, yaw=180, glyphSizeCm=65, materials=dict(
        BodyMaterialOverride='/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX01',
        FaceMaterialOverride='/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_BellkeeperPrimaryColor',
        GlyphMaterialOverride='/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_BellkeeperPrimaryColor')),
    rewards=[dict(definition='Mars_ItemDef_Tallow', at=[x, 42, 0.5]) for x in (104.8, 106, 107.2)],
)

# Preserve the raster's source basis, then replace its obsolete static causeway
# by exact transform-matched section fragments. This prevents a rebuild from
# restoring either the old ramp or its upper-roof bypass.
SECTION_OVERRIDES = [dict(
    file='data/warrens_v8c_p2_section.json', puzzleId='P2', replacedWalkLines=['chain-crossing'],
    entity=dict(cls='Mars_SlidingBridge_EntityScript', at=[79, 20, -2.2], yaw=90, pitch=0,
                level='main', tile='Canal', note='P2 sliding cargo crossing',
                props=dict(Bridge=dict(fields=dict(
                    WheelOffset=dict(transform=dict(location=[-800, -4300, -30], rotation=[0, -180, 0])),
                    DrivePath=dict(array=[dict(vector=[(y-20)*100, (79-x)*100, -22])
                                          for x,y in [(122,12),(122,15),(112,16),(104,19),(96,20),(90,20)]]))),
                    Source=dict(fields=dict(OutputChannel=dict(tag='Mechanism.Channel.Warrens.Shortcut.Chain'))),
                    DeckMeshOverride=dict(asset='/Game/Mars/Environment/WarrensVariantCKit/P2SlidingSpan/WarrensC_P2S01_Deck_Mars_SM'),
                    CageMeshOverride=dict(asset='/Game/Mars/Environment/WarrensVariantCKit/P2SlidingSpan/WarrensC_P2S02_Cage_Mars_SM'),
                    GuardMeshOverride=dict(asset='/Game/Mars/Environment/WarrensVariantCKit/P2SlidingSpan/WarrensC_P2S03_Guard_Mars_SM'),
                    MaterialOverride=dict(asset='/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX09'),
                    WheelMeshOverride=dict(asset='/Game/Mars/Environment/ChainCrossingKit/Meshes/WarrensC_CCS21_HandwheelBody_Mars_SM'),
                    WheelMeshLocalTransform=dict(transform=dict(location=[2.5, 0, 0], rotation=[0, 90, 0])),
                    WheelMaterialOverride=dict(asset='/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX09')))),
]

if __name__ == '__main__':
    import sys
    common.write(sys.modules[__name__])
