"""Warrens v8a, "The Well, widened": v7's topology kept, every wing pushed one beat away from the hub and given a window
onto the Well; the kitchen goes back to camp. The conservative variant: it tests the two playtest complaints with the
smallest rebuild (same rooms, gates, courts, puzzles and pockets; only positions, thresholds and openings change).

What changes against v7r1 (Tools/LevelDesign/anchor_plans/data/warrens.json):
- The Lamp Chapel becomes the Arrival Hall: the camp stair lands at its west door (S1 = the front door); the sealed kitchen,
  its aisle ring and the shutter puzzle PK are gone. K is the Camp Door, the solver's home.
- Every wing is one transition beat from the hub (10-20 m with a turn, a stair or a squeeze; never a straight throat), so a
  room is approached, not stumbled into. v7 walls between wings were 2-4 m.
- The Well is asymmetric: hoist on the north rim (lit by the shaft light), roots down the west wall, the glyph wall south,
  the cascade stair (R7) on the east. Each face is a different silhouette, so seeing the Well tells you which side you are on.
- Each wing gets a Well window: the hall's east door; the Bridge over the north rim; the Chime Bridge over the Pit's east arm
  (R2 now stands at the end of a bridge, not in a throat); the Sump Balcony at -2.5 inside the shaft for the waterworks; the
  gallery walkway at +5. The Court and the Cistern are the two far places and see the Well only through their stair lights.
- The sump stair becomes a cascade down the shaft's east wall; the waterworks' own way into the Pit is a barred stair from the
  Sump Balcony (P2's grate moves there; the Drowned Gallery is gone).
- Level Instance tiles: Hub, Court, Ossuary (with Bridge and Reliquary), Chime, Waterworks, Cistern, Pit. The assembly owns
  every transition between tiles.
"""
import design_warrens_v8_common as common

FILE, REVISION = 'v8a', 'v8a'
SOURCE = 'Tools/LevelDesign/anchor_plans/design_warrens_v8a.py (Warrens v8a "The Well, widened", 2026-10-23)'
TUNNEL, CORRIDOR = common.TUNNEL, common.CORRIDOR
UP, DOWN, DEEPZ, GAL = 2.5, -2.5, -5.0, 5.0
FOOTPRINT = (-26, 0, 136, 126)
DEEP = (40, 36, 112, 84)
RAMP_ROOF_Z = -2.4
MAX_CLOSED = 3

NODES = {
    'K': (44, 60, 0), 'kw': (34, 60, 0), 'kn': (44, 67, 0), 'ks': (44, 53, 0),        # the Arrival Hall and its doors
    'S1': (24, 60, 0),                                                                 # the camp stair lands here: the front door
    'wW': (60, 60, 0), 'wN': (70, 70, 0), 'wE': (80, 60, 0), 'wS': (70, 50, 0),         # the Well rim
    # the Court: a 0 rim round a -1.5 arena
    'h0': (24, 66, 0), 'c2': (20, 74, 0), 'c1': (8, 46, 0), 's0': (16, 46, 0), 'c3': (6, 72, 0),
    'H1': (11, 58, -1.5), 'p0': (20, 62, -1.5), 'p3': (8, 66, -1.5), 'ps': (14, 50, -1.5),
    # north: Ossuary, Bridge, Reliquary at +2.5
    'o0': (48, 80, UP), 'O': (44, 87, UP), 'o1': (36, 86, UP), 'BR': (70, 76, UP), 'RQ': (90, 85, UP), 'rq1': (98, 80, UP), 'S2': (112, 86, UP),
    'rq2': (92, 92, UP), 'sm0': (98, 104, GAL), 'SM': (98, 111, GAL),                                                       # the Smokehouse (+5): the Curing Room
    'ct0': (-8, 70, 0), 'CT': (-14, 62, 0), 'ct1': (-12, 52, 0),                                        # the Catacomb: the far west bead
    # east: the Chime Bridge, the porch and the Chime Hall
    'cb': (94, 60, 0), 'CH': (106, 62, 0), 'ch0': (110, 74, 0), 'ch1': (98, 52, 0), 'ch2': (104, 50, 0), 'S3': (126, 62, 0),
    # south: Pump Room, Salt Cellar, Sluice at -2.5; the Sump Balcony inside the shaft
    'p1': (52, 36, DOWN), 'PU': (59, 29, DOWN), 'pb': (62, 36, DOWN), 'SB': (70, 42, DOWN), 'CE': (76, 22, DOWN), 'SL': (98, 23, DOWN), 'sl1': (100, 30, DOWN), 'S4': (59, 10, DOWN),
    # south-west: Cistern and Grotto at -2.5
    'ci2': (18, 34, DOWN), 'CI': (22, 27, DOWN), 'ci1': (30, 27, DOWN), 'tm': (40, 29, -1.0), 'p0w': (52, 31, DOWN), 'GR': (6, 28, DOWN), 'S5': (22, 8, DOWN),
    # the Pit (-5)
    'H2': (70, 60, DEEPZ), 'd2': (84, 44, DEEPZ), 'd4': (88, 40, DEEPZ),
}

LINKS = [
    ('S1', 'kw', [], CORRIDOR, 'walk', None), ('kw', 'K', [], CORRIDOR, 'walk', None),
    ('K', 'wW', [(54, 60)], CORRIDOR, 'walk', None),
    ('K', 'kn', [], CORRIDOR, 'walk', None), ('kn', 'o0', [(44, 73), (48, 76)], CORRIDOR, 'stair', None), ('o0', 'O', [], CORRIDOR, 'walk', None),
    ('K', 'ks', [], CORRIDOR, 'walk', None), ('ks', 'p1', [(44, 46), (48, 40)], CORRIDOR, 'stair', None), ('p1', 'PU', [], CORRIDOR, 'walk', None),
    # hall -> court: a bent passage, R1 at its court end
    ('kw', 'h0', [(30, 60), (30, 66)], CORRIDOR, 'walk', 'R1'),
    # the rim
    ('wW', 'wN', [(60, 70)], CORRIDOR, 'walk', None), ('wN', 'wE', [(80, 70)], CORRIDOR, 'walk', None),
    ('wE', 'wS', [(80, 50)], CORRIDOR, 'walk', None), ('wS', 'wW', [(60, 50)], CORRIDOR, 'walk', 'R4'),
    # the Chime Bridge over the Pit's east arm; R2 at its east end
    ('wE', 'cb', [], CORRIDOR, 'walk', 'R2'), ('cb', 'CH', [(98, 60)], CORRIDOR, 'walk', None),
    # the cascade: the east face of the Well, down into the Pit
    ('wS', 'd2', [], 4.0, 'stair', 'R7'),
    # the court
    ('h0', 'p0', [], 4.0, 'stair', None), ('c3', 'p3', [], 3.0, 'stair', None), ('s0', 'ps', [], 3.0, 'stair', None),
    ('p0', 'H1', [], CORRIDOR, 'walk', None), ('p3', 'H1', [], CORRIDOR, 'walk', None), ('ps', 'H1', [], CORRIDOR, 'walk', None),
    ('h0', 'c2', [(24, 74)], CORRIDOR, 'walk', None), ('c2', 'c3', [], CORRIDOR, 'walk', None), ('c3', 'c1', [(3, 60)], CORRIDOR, 'walk', None), ('c1', 's0', [], CORRIDOR, 'walk', None),
    ('c1', 'ci2', [], CORRIDOR, 'stair', 'R6'),
    ('c2', 'o1', [(24, 80), (30, 86)], CORRIDOR, 'stair', None), ('o1', 'O', [], CORRIDOR, 'walk', None),
    # north
    ('O', 'BR', [(56, 88), (60, 82)], CORRIDOR, 'walk', 'R5'),
    ('BR', 'RQ', [(80, 80), (84, 84)], TUNNEL, 'walk', None),
    ('RQ', 'rq1', [], CORRIDOR, 'walk', None), ('rq1', 'ch0', [(104, 78)], CORRIDOR, 'stair', None), ('ch0', 'CH', [], CORRIDOR, 'walk', None),
    ('S2', 'RQ', [(100, 86)], CORRIDOR, 'walk', None),
    ('RQ', 'rq2', [], CORRIDOR, 'walk', None), ('rq2', 'sm0', [(92, 98), (96, 102)], CORRIDOR, 'ramp', None), ('sm0', 'SM', [], CORRIDOR, 'walk', None),  # the smoke stair winds up
    ('c3', 'ct0', [(0, 76), (-6, 74)], TUNNEL, 'walk', None), ('ct0', 'CT', [], CORRIDOR, 'walk', None), ('CT', 'ct1', [], CORRIDOR, 'walk', None),
    ('ct1', 'GR', [(-10, 42), (-4, 34)], TUNNEL, 'stair', None),                                                          # Catacomb down to the Grotto: the west loop closes
    # east
    ('S3', 'CH', [(120, 62)], CORRIDOR, 'walk', None),
    ('CH', 'ch1', [], CORRIDOR, 'walk', None), ('ch1', 'd4', [], 4.0, 'stair', None),
    ('CH', 'ch2', [], CORRIDOR, 'walk', None), ('ch2', 'sl1', [(104, 42)], CORRIDOR, 'stair', None), ('sl1', 'SL', [], CORRIDOR, 'walk', None),
    # south
    ('SL', 'CE', [(90, 22), (84, 24)], CORRIDOR, 'walk', None),
    ('CE', 'PU', [(70, 24), (66, 27)], CORRIDOR, 'walk', 'R3'),
    ('PU', 'pb', [], CORRIDOR, 'walk', None), ('pb', 'SB', [(62, 42)], TUNNEL, 'walk', None),   # the sump tunnel to the balcony inside the shaft
    ('S4', 'PU', [], CORRIDOR, 'walk', None),
    ('PU', 'p0w', [], CORRIDOR, 'walk', None), ('p0w', 'tm', [(44, 31)], TUNNEL, 'stair', None), ('tm', 'ci1', [(36, 27)], TUNNEL, 'stair', None), ('ci1', 'CI', [], CORRIDOR, 'walk', None),   # the tunnel climbs a hump and drops
    ('CI', 'ci2', [], CORRIDOR, 'walk', None), ('CI', 'GR', [(14, 24)], TUNNEL, 'walk', None), ('S5', 'CI', [], CORRIDOR, 'walk', None),
    # the Pit
    ('d2', 'H2', [], TUNNEL, 'walk', None), ('d4', 'H2', [(88, 48), (80, 52)], TUNNEL, 'walk', None),
]

ROOMS = [
    dict(id='hall', label='Arrival Hall', poly=[(37, 53), (51, 53), (54, 56), (54, 64), (51, 67), (37, 67), (34, 64), (34, 56)], z=0, light='hearth'),
    dict(id='closet', label='', rect=(44, 44, 50, 48), z=0),
    dict(id='court', label='Charnel Court', poly=[(0, 48), (6, 43), (20, 44), (25, 50), (26, 66), (22, 78), (8, 79), (0, 72)], z=0, light='cold', top=9),
    dict(id='court-pit', label='', poly=[(4, 50), (20, 48), (22, 66), (16, 72), (5, 70)], z=-1.5),
    dict(id='ossuary', label='Ossuary', rect=(36, 80, 52, 94), z=UP),
    dict(id='bridge', label='Bridge', rect=(62, 70, 78, 82), z=UP),
    dict(id='reliquary', label='Reliquary', rect=(82, 78, 98, 92), z=UP, light='dim'),
    dict(id='rimW', label='', rect=(58, 48, 63, 72), z=0), dict(id='rimE', label='', rect=(77, 48, 82, 72), z=0),
    dict(id='rimN', label='The Well', rect=(58, 67, 82, 72), z=0), dict(id='rimS', label='', rect=(58, 48, 82, 53), z=0),
    dict(id='chime-porch', label='', rect=(93, 57, 96, 63), z=0),
    dict(id='chime', label='Chime Hall', poly=[(96, 50), (118, 50), (118, 74), (108, 74), (96, 68)], z=0, light='cold', top=4),
    dict(id='pump', label='Pump Room', rect=(52, 22, 66, 36), z=DOWN, light='dim', top=8),
    dict(id='sump-balcony', label='Sump Balcony', rect=(58, 40, 78, 44), z=DOWN),
    dict(id='cellar', label='Salt Cellar', rect=(70, 16, 82, 28), z=DOWN, top=3.2),
    dict(id='sluice', label='Sluice', rect=(90, 16, 106, 30), z=DOWN, light='dim'),
    dict(id='cistern', label='Cistern', poly=[(14, 22), (20, 19), (30, 21), (32, 28), (28, 35), (16, 35), (13, 29)], z=DOWN, top=4),
    dict(id='grotto', label='Root Grotto', poly=[(0, 22), (4, 20), (10, 20), (12, 24), (12, 32), (8, 34), (2, 34), (0, 30)], z=DOWN),
    dict(id='smokehouse', label='Smokehouse', rect=(88, 104, 108, 118), z=GAL, light='dim', top=6),
    dict(id='catacomb', label='Catacomb', poly=[(-22, 54), (-16, 50), (-8, 52), (-4, 60), (-6, 72), (-14, 76), (-22, 70)], z=0, top=3.5),
    dict(id='lair', label='The Pit', poly=[(46, 48), (60, 42), (86, 38), (96, 46), (96, 62), (92, 76), (72, 78), (50, 74), (45, 60)], z=DEEPZ, light='cold'),
    dict(id='vault', label='Vault', rect=(96, 70, 104, 76), z=DEEPZ),
]
ENTRANCES = ['S1', 'S2', 'S3', 'S4', 'S5']
COURTS = {'H1': 'H1', 'H2': 'H2', 'H3': 'CH'}

CRAWLS = [
    dict(id='crawl-r2', a=(83, 54), b=(96, 54), z=0, packFits=False, note='beside the Chime Bridge, in the rock south of the east arm', purpose='reach the R2 lever on the porch side; the pack waits on the rim'),
    dict(id='crawl-r3', a=(66, 22), b=(72, 19), z=DOWN, packFits=False, note='beside R3', purpose='reach the R3 lever in the Salt Cellar; the pack waits in the Pump Room'),
    dict(id='crawl-r5', a=(52, 86), b=(61, 83), z=UP, packFits=False, note='beside R5', purpose='reach the R5 lever on the Bridge; the pack waits in the Ossuary'),
    dict(id='crawl-r6', a=(12, 46), b=(20, 35), z=0, packFits=False, note='beside R6; ends 2.5 m above the Cistern floor: a one-way drop', purpose='reach the R6 lever by the stair foot; the scout drops, the pack takes the stair'),
    dict(id='crawl-sealed', a=(117, 70), b=(122, 72), z=0, packFits=False, note='a gap behind the Chime Hall\'s east wall', purpose='the one squeeze that leads somewhere new: the Sealed Burial'),
]
UPPER = dict(
    z=GAL, top=9.0, mainTop=4.6,
    tallRooms=['hall', 'court', 'chime', 'chime-porch', 'rimW', 'rimE', 'rimN', 'rimS', 'ossuary', 'bridge', 'reliquary'],
    platforms=[
        dict(id='gNW', rect=(30, 64, 36, 72), note='landing of the Ossuary gallery stair, west of the hall'),
        dict(id='gW', rect=(58, 48, 63, 72), note='west gallery over the rim'),
        dict(id='gN', rect=(58, 67, 82, 72), note='north gallery over the north rim; the hoist hangs from its beam'),
        dict(id='gE', rect=(77, 48, 84, 72), note='east gallery: the Red key on a lit plinth at its west rail'),
        dict(id='smoke-walk', rect=(84, 100, 88, 108), note='the Smoke Walk landing'),
    ],
    walkways=[
        dict(id='gNW-gW', pts=[(33, 68), (50, 68), (58, 68)], width=2.0, note='landing to the west gallery, over the hall\'s north wall'),
        dict(id='gE-ladder', pts=[(84, 66), (96, 66)], width=2.5, note='catwalk over the east arm to the Chime ladder head'),
        dict(id='smoke-walk', pts=[(86, 104), (82, 92), (80, 74)], width=2.0, note='the Smoke Walk: a +5 catwalk over the Reliquary from the Smokehouse to the east gallery; the Curing Room\'s way home round the galleries'),
    ],
    railGaps=[
        dict(id='gW-drop', a=(58, 58), b=(58, 62), note='drop from the west gallery into the hall\'s east passage'),
        dict(id='gE-drop', a=(96, 64), b=(96, 68), note='drop from the catwalk into the Chime Hall, beside the barred ladder'),
    ],
)
LADDERS = [
    dict(id='closet-ladder', at=(48, 46), baseZ=DEEPZ, height=5.0, yaw=0.0, oneWay=True, note='from the Pit\'s west wall up into the hall closet',
         purpose='the Pit\'s one-way way home, pack included: 14 m to the Camp Door against 60+ m by the gates; whoever climbs out opens SC2'),
    dict(id='chime-ladder', at=(96, 66), baseZ=0.0, height=5.0, yaw=0.0, kind='barred', oneWay=False, note='Chime Hall up to the catwalk; foot barred until the lever on the gallery is pulled',
         purpose='once opened from above, the east loop closes: chime -> ladder -> galleries -> west drop -> hall'),
]
HOLES = [
    dict(id='well', level='main', rect=(63, 53, 77, 67), kind='open', rail=0.6, note='the Well: rim at 0, Pit at -5, galleries at +5; hoist N, roots W, glyphs S, cascade E'),
    dict(id='east-arm-s', level='main', rect=(82, 54, 93, 58.5), kind='open', rail=0.9, note='the Pit\'s east arm, south of the Chime Bridge'),
    dict(id='east-arm-n', level='main', rect=(82, 61.5, 93, 66), kind='open', rail=0.9, note='the Pit\'s east arm, north of the Chime Bridge'),
    dict(id='closet-well', level='main', rect=(47.25, 45.25, 48.75, 46.75), kind='open', note='the closet ladder comes up here'),
]
EXTRA_WALKS = [
    dict(id='sc2-door', pts=[(47, 48), (47, 53)], width=2.5, note='closet to hall, barred from the hall side'),
    dict(id='vault-passage', level='deep', pts=[(93, 73), (96, 73)], width=2.5, note='Pit to the vault door'),
]
EXTRA_RAMPS = [
    dict(id='gallery-stair', a=(38, 82, UP), b=(33, 70, GAL), width=3.0, note='Ossuary up to the galleries'),
    dict(id='smoke-stair-a', a=(92, 92, UP), b=(92, 98, 3.4), width=3.0, note='the smoke stair: Reliquary up to the Smokehouse'), dict(id='smoke-stair-b', a=(92, 98, 3.4), b=(96, 102, 4.3), width=3.0), dict(id='smoke-stair-c', a=(96, 102, 4.3), b=(98, 104, GAL), width=3.0),
    dict(id='sump-stair', a=(76, 42, DOWN), b=(86, 48, DEEPZ), width=2.5, note='the barred sump stair (P2) from the balcony down into the Pit: the waterworks\' own way in, off the plan graph'),
]
SHORTCUTS = [
    dict(id='SC2', at=(47, 48), yaw=90.0, spanCm=250.0, leverSide=-1, oneWay=True, channel='Mechanism.Channel.Warrens.Shortcut.SC2',
         note='closet -> hall; lever in the closet: the Pit connects to the Camp Door once someone has climbed out'),
]
LIGHTS = [
    dict(at=(44, 60, 3.0), kind='hearth'), dict(at=(70, 60, 8.0), kind='shaft'), dict(at=(70, 60, -3.0), kind='cold'),
    dict(at=(11, 58, 5.0), kind='cold'), dict(at=(90, 85, 5.1), kind='dim'), dict(at=(59, 29, 0.1), kind='dim'), dict(at=(98, 23, 0.1), kind='dim'),
    dict(at=(79, 60, 5.6), kind='dim'), dict(at=(106, 62, 6.0), kind='cold'), dict(at=(22, 27, -0.5), kind='dim'), dict(at=(44, 87, 5.1), kind='dim'),
    dict(at=(70, 42, -0.5), kind='dim'), dict(at=(98, 111, 7.6), kind='dim'), dict(at=(-14, 62, 3.0), kind='cold'),
]
PILLARS = [
    dict(level='main', rect=(4, 50, 7, 53)), dict(level='main', rect=(18, 64, 21, 67)),
    dict(level='main', rect=(100, 66, 103, 69)), dict(level='main', rect=(112, 54, 115, 57)),
    dict(level='deep', rect=(56, 48, 59, 51)), dict(level='deep', rect=(84, 70, 87, 73)), dict(level='deep', rect=(52, 70, 55, 73)),
]
LOW_LINKS = [('BR', 'RQ'), ('d4', 'H2'), ('p0w', 'tm'), ('tm', 'ci1'), ('CI', 'GR'), ('pb', 'SB'), ('c3', 'ct0'), ('ct1', 'GR')]
LOW_ROOF = 2.2
LOCKS = [
    dict(id='vault', door=dict(at=(95, 73), yaw=0.0, spanCm=250.0, level='deep'), lock=dict(at=(94, 71.3), yaw=90.0, level='deep'),
         key='Red', keyAt=(78.3, 60, 5.3), channel='Mechanism.Channel.Keys.Red',
         note='the key on a lit plinth at the east gallery rail, seen across the Well from the hall\'s east door'),
]
PUZZLES = [
    dict(id='P1', kind='Red key door', at=(95, 73, DEEPZ), needsAt=(78.3, 60, GAL), needsNote='the key on a lit plinth at the east gallery rail, seen across the Well from the hall door'),
    dict(id='P2', kind='barred sump stair (latched bars) at the Sump Balcony', at=(76, 42, DOWN), needsAt=(102, 18, DOWN), needsNote='the Sluice hand-wheel opens it; the dry channel in the Pump Room floor runs from the wheel to the balcony as the tell', existing='hand-wheel + latched Bars gate'),
    dict(id='P3', kind='Mourner cache gate (latched)', at=(96, 92, UP), needsAt=(40, 92, UP), needsNote='the pack plate at the far end of the Ossuary, 56 m away', latch=True),
    dict(id='P4', kind='Bellkeeper dial lock', at=(114, 72, 0), needsAt=(70, 72, UP), needsNote='the three dial glyphs on the Well\'s south wall, read from the Bridge\'s edge'),
    dict(id='P5', kind='barred ladder foot (Chime Hall)', at=(96, 66, 0), needsAt=(92, 66, GAL), needsNote='a lever on the catwalk opens the bars at its foot'),
    dict(id='P6', kind='SC2 barred closet door', at=(47, 48, 0), needsAt=(48, 46, DEEPZ), needsNote='climb the closet ladder out of the Pit; the lever is on the closet side'),
    dict(id='P7', kind='Curing Room (support objective)', at=(94, 114, GAL), needsAt=(70, 60, DEEPZ), needsNote='the Curing Room: the hunted part is brined here before it travels (the run\'s second required stop); the vat, the drying racks, a plinth for the pack'),
]
NICHES = [
    dict(id='court-pack', rect=(2, 78, 6, 81), z=0, family='P', note='pack plinth at the court\'s north-west'),
    dict(id='court-forage', rect=(-4, 54, 0, 58), z=0, family='F', note='mushrooms in the west burial niche'),
    dict(id='court-omen', rect=(24, 52, 26, 54), z=0, family='O', note='eyes in the east wall niche'),
    dict(id='court-threat', rect=(16, 40, 20, 44), z=0, family='T', note='sentry alcove south of the arena'),
    dict(id='ossuary-husk', rect=(40, 94, 44, 97), z=UP, family='F', note='husk spill in the north niche'),
    dict(id='ossuary-rest', rect=(32, 88, 36, 91), z=UP, family='N', note='lantern rest by the gallery stair'),
    dict(id='bridge-omen', rect=(69, 82, 71, 84), z=UP, family='O', note='swaying chains over the bridge'),
    dict(id='mourner', rect=(92, 92, 98, 96), z=UP, family='C', note='Mourner cache behind the pack-plate gate (P3)'),
    dict(id='reliquary-rest', rect=(82, 92, 86, 95), z=UP, family='N', note='lantern rest by the S2 mouth'),
    dict(id='bellkeeper', rect=(110, 74, 116, 78), z=0, family='C', note='Bellkeeper\'s Confession behind the dial lock (P4)'),
    dict(id='chime-threat', rect=(110, 46, 114, 50), z=0, family='T', note='sentry niche south of the hall'),
    dict(id='chime-pack', rect=(114, 46, 118, 50), z=0, family='P', note='pack plinth by the S3 way in'),
    dict(id='sealed-burial', rect=(122, 70, 127, 76), z=0, family='C', note='the Sealed Burial: reached only through crawl-sealed'),
    dict(id='cellar-salt', rect=(72, 28, 76, 31), z=DOWN, family='F', note='salt crystals: the cellar is the forage room'),
    dict(id='porter', rect=(100, 10, 108, 16), z=DOWN, family='C', note='Porter\'s Wager: the dead-end freight niche'),
    dict(id='sluice-rest', rect=(92, 30, 96, 33), z=DOWN, family='N', note='lantern rest at the Sluice north wall'),
    dict(id='pump-omen', rect=(48, 24, 52, 27), z=DOWN, family='O', note='swaying chains in the west niche'),
    dict(id='balcony-threat', rect=(58, 36, 61, 40), z=DOWN, family='T', note='something waits at the balcony\'s west end'),
    dict(id='cistern-forage', rect=(14, 16, 18, 20), z=DOWN, family='F', note='mushroom bed across the basin'),
    dict(id='grotto-forage', rect=(-4, 26, 0, 30), z=DOWN, family='F', note='root mushrooms: the far place pays'),
    dict(id='pit-pack', rect=(46, 76, 50, 80), z=DEEPZ, family='P', note='pack plinth at the Pit\'s north-west, outside the home radius'),
    dict(id='pit-rest', rect=(46, 56, 50, 60), z=DEEPZ, family='N', note='lantern rest at the lair\'s west wall'),
    dict(id='pit-forage', rect=(94, 50, 98, 54), z=DEEPZ, family='F', note='deep mushrooms in the east arm'),
    dict(id='pit-omen', rect=(68, 76, 70, 78), z=DEEPZ, family='O', note='the inner wall niche'),
    dict(id='smoke-pack', rect=(104, 118, 108, 121), z=GAL, family='P', note='pack plinth by the vat'), dict(id='smoke-threat', rect=(108, 108, 112, 112), z=GAL, family='T', note='something in the rack row'),
    dict(id='smoke-rest', rect=(84, 108, 88, 111), z=GAL, family='N', note='lantern rest at the Smoke Walk'),
    dict(id='catacomb-husk', rect=(-26, 60, -22, 64), z=0, family='F', note='husk spill in the deepest niche'), dict(id='catacomb-cache', rect=(-12, 76, -6, 80), z=0, family='C', note='the Catacomb cache: a sealed ossuary drawer'),
    dict(id='catacomb-omen', rect=(-4, 54, -2, 56), z=0, family='O', note='eyes in the east niche'),
]
WATER = [
    dict(id='cistern-basin', rect=(16, 22, 26, 30), z=DOWN, depth=0.5, note='the Cistern pool'),
]
PROPS = [
    dict(kind='statue', at=(11, 76, 0), size=(2.0, 1.2, 4.5), yaw=-90, note='split mourner: the Court landmark, seen on entering from the north-east'),
    dict(kind='plinth', at=(36, 60, 0), size=(1.2, 1.2, 0.3), note='pack plinth by the Camp Door'),
    dict(kind='station', at=(70, 71, 0), size=(1.6, 1.6, 7.5), note='THE HOIST: a timber crane over the north rim, lit by the shaft light: the Well\'s north face'),
    dict(kind='root', at=(64, 56, DEEPZ), size=(1.4, 1.4, 14.0), note='roots down the west wall: the Well\'s west face'),
    dict(kind='root', at=(64, 64, DEEPZ), size=(1.0, 1.0, 14.0)),
    dict(kind='stack', at=(70, 52.5, -2.2), size=(5.0, 0.3, 2.0), note='the three dial glyphs on the south wall (P4): the Well\'s south face, read from the Bridge'),
    dict(kind='stack', at=(46, 85, UP), size=(6.0, 1.0, 2.6), note='bone stacks: the aisle maze'), dict(kind='stack', at=(42, 89, UP), size=(6.0, 1.0, 2.6)),
    dict(kind='sarcophagus', at=(92, 82, UP), size=(3.0, 1.5, 1.2), note='the reliquary tomb'),
    dict(kind='plinth', at=(40, 92, UP), size=(2.0, 2.0, 0.3), note='the pack plate (P3), at the far end of the Ossuary'),
    dict(kind='plinth', at=(78.3, 60, GAL), size=(0.8, 0.8, 0.3), note='the key plinth at the gallery rail (P1)'),
    dict(kind='station', at=(76, 42, DOWN), size=(0.3, 2.6, 2.5), note='the sump bars (P2): latched across the balcony stair'),
    dict(kind='stack', at=(84, 30, DOWN), size=(30.0, 0.8, 0.2), note='the dry sluice channel in the floor, from the wheel to the balcony (P2 tell)'),
    dict(kind='chimes', at=(106, 62, 0), size=(6.0, 0.2, 3.5), yaw=0, note='bone chimes across the hall: the native trap'),
    dict(kind='station', at=(113, 73, 0), size=(1.0, 0.4, 1.4), note='the dial lock (P4)'),
    dict(kind='pillar', at=(55, 25, DOWN), size=(2.0, 2.0, 3.2), note='the pump: the south\'s audio landmark'),
    dict(kind='pillar', at=(102, 18, DOWN), size=(1.0, 1.0, 1.6), note='the hand-wheel: opens the sump bars (P2)'),
    dict(kind='stack', at=(74, 20, DOWN), size=(2.0, 2.0, 1.4), note='salt crystals'),
    dict(kind='candles', at=(38, 55, 0), size=(0.9, 0.9, 0.5), note='tallow'), dict(kind='candles', at=(50, 92, UP), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(28, 32, DOWN), size=(0.9, 0.9, 0.5), note='tallow'), dict(kind='candles', at=(98, 52, 0), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(48, 74, DEEPZ), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='station', at=(94, 114, GAL), size=(2.4, 1.6, 1.4), note='the brine vat (P7): the Curing Room'), dict(kind='stack', at=(100, 110, GAL), size=(8.0, 0.6, 2.2), note='drying racks'),
    dict(kind='sarcophagus', at=(-14, 62, 0), size=(3.0, 1.5, 1.2), note='the Catacomb\'s one open tomb'),
]
ANCHOR_AT = {'R1': (26, 66), 'R2': (92, 60), 'R3': (68, 26), 'R4': (60, 52), 'R5': (58, 86), 'R6': (10, 44), 'R7': None}
LEVER_NODE = {'R2': 'cb', 'R3': 'CE', 'R5': 'BR', 'R6': 'ci2'}
MAX_ACTIVE_CACHES = 2

# ---------------------------------------------------------------- v8 layers
INSTANCES = [
    dict(id='Hub', label='LI_Warrens_Hub', asset='LI_Warrens_Hub', z=0, rect=(34, 44, 84, 76),
         ports=[dict(id='camp', at=(34, 60, 0), width=3, kind='door'), dict(id='court', at=(34, 60, 0), width=3, kind='door'),
                dict(id='ossuary', at=(44, 70, 0), width=3, kind='stair'), dict(id='pump', at=(44, 50, 0), width=3, kind='stair'),
                dict(id='chime', at=(84, 60, 0), width=3, kind='balcony'), dict(id='cascade', at=(76, 50, 0), width=4, kind='stair'),
                dict(id='closet', at=(48, 46, -5), width=1, kind='ladder'), dict(id='catwalk', at=(84, 66, 5), width=2.5, kind='balcony')],
         note='the Arrival Hall, closet, the Well, its rims and the galleries over them; the hoist and the shaft light. Persistent-level candidate.'),
    dict(id='Court', label='LI_Warrens_Court', asset='LI_Warrens_Court', z=0, rect=(-6, 40, 28, 82),
         ports=[dict(id='hall', at=(28, 66, 0), width=3, kind='door'), dict(id='ossuary', at=(22, 78, 0), width=3, kind='stair'), dict(id='cistern', at=(8, 42, 0), width=3, kind='stair')],
         note='rim, arena, statue, three arena stairs, four pockets'),
    dict(id='Ossuary', label='LI_Warrens_Ossuary', asset='LI_Warrens_Ossuary', z=2.5, rect=(30, 76, 100, 106),
         ports=[dict(id='hall', at=(48, 76, 2.5), width=3, kind='stair'), dict(id='court', at=(30, 86, 2.5), width=3, kind='stair'),
                dict(id='chime', at=(100, 79, 2.5), width=3, kind='stair'), dict(id='gallery', at=(33, 76, 5), width=3, kind='stair'), dict(id='S2', at=(112, 86, 2.5), width=3, kind='door'), dict(id='smoke', at=(92, 96, 3), width=3, kind='stair')],
         note='Ossuary, Bridge (touches the north rim: the Hub\'s rim is the shared edge), Reliquary, Mourner gate'),
    dict(id='Chime', label='LI_Warrens_Chime', asset='LI_Warrens_Chime', z=0, rect=(93, 44, 128, 80),
         ports=[dict(id='bridge', at=(93, 60, 0), width=3, kind='balcony'), dict(id='reliquary', at=(104, 78, 0), width=3, kind='stair'),
                dict(id='sluice', at=(104, 44, 0), width=3, kind='stair'), dict(id='pit', at=(98, 50, 0), width=4, kind='stair'), dict(id='S3', at=(126, 62, 0), width=3, kind='door')],
         note='porch, hall, chimes, dial lock, Sealed Burial, the barred ladder'),
    dict(id='Waterworks', label='LI_Warrens_Waterworks', asset='LI_Warrens_Waterworks', z=-2.5, rect=(48, 6, 110, 46),
         ports=[dict(id='hall', at=(50, 38, -2.5), width=3, kind='stair'), dict(id='cistern', at=(48, 31, -2.5), width=2.5, kind='crawl'),
                dict(id='chime', at=(102, 36, -2.5), width=3, kind='stair'), dict(id='balcony', at=(78, 44, -2.5), width=2.5, kind='balcony'), dict(id='S4', at=(59, 8, -2.5), width=3, kind='door')],
         note='Pump Room, Salt Cellar, Sluice, the Sump Balcony inside the shaft and the barred sump stair'),
    dict(id='Cistern', label='LI_Warrens_Cistern', asset='LI_Warrens_Cistern', z=-2.5, rect=(-6, 6, 44, 38),
         ports=[dict(id='court', at=(18, 38, -2.5), width=3, kind='stair'), dict(id='pump', at=(44, 31, -2.5), width=2.5, kind='crawl'), dict(id='S5', at=(22, 8, -2.5), width=3, kind='door')],
         note='Cistern, basin, Root Grotto (the far place)'),
    dict(id='Smokehouse', label='LI_Warrens_Smokehouse', asset='LI_Warrens_Smokehouse', z=5, rect=(82, 98, 112, 124),
         ports=[dict(id='reliquary', at=(92, 98, 3), width=3, kind='stair'), dict(id='smokewalk', at=(82, 100, 5), width=2, kind='balcony')], note='the Curing Room wing (P7) and the Smoke Walk landing'),
    dict(id='Catacomb', label='LI_Warrens_Catacomb', asset='LI_Warrens_Catacomb', z=0, rect=(-26, 48, -2, 80),
         ports=[dict(id='court', at=(-2, 74, 0), width=2.5, kind='crawl'), dict(id='grotto', at=(-8, 48, 0), width=2.5, kind='stair')], note='the far west bead: three pockets and a cache'),
    dict(id='Pit', label='LI_Warrens_Pit', asset='LI_Warrens_Pit', z=-5, rect=(44, 36, 106, 78),
         ports=[dict(id='cascade', at=(84, 44, -5), width=4, kind='stair'), dict(id='chime', at=(88, 40, -5), width=4, kind='stair'),
                dict(id='sump', at=(86, 48, -5), width=2.5, kind='stair'), dict(id='closet', at=(48, 46, -5), width=1, kind='ladder')],
         note='the lair floor, the Vault, roots, pockets; the shaft above belongs to the Hub'),
]
VIEWS = [
    dict(id='hall-hoist', **{'from': (54, 60, 0), 'to': (70, 72, 5)}, label='Camp Door -> the hoist across the Well'),
    dict(id='hall-key', **{'from': (54, 60, 0), 'to': (78.3, 60, 5.3)}, label='Camp Door -> the Red key on the east gallery rail'),
    dict(id='bridge-glyphs', **{'from': (70, 71, 2.5), 'to': (70, 52.5, -1.5)}, label='Bridge -> the dial glyphs on the south wall'),
    dict(id='bridge-pit', **{'from': (70, 71, 2.5), 'to': (70, 60, -5)}, label='Bridge -> the Pit floor, lit from below'),
    dict(id='chimebridge-hoist', **{'from': (88, 60, 0), 'to': (70, 72, 5)}, label='Chime Bridge -> the hoist (looking back west)'),
    dict(id='chimebridge-pit', **{'from': (88, 60, 0), 'to': (88, 52, -5)}, label='Chime Bridge -> the Pit\'s east arm below'),
    dict(id='balcony-shaft', **{'from': (70, 42, -2.5), 'to': (70, 60, -5)}, label='Sump Balcony -> the Pit floor and the shaft light'),
    dict(id='catwalk-well', **{'from': (33, 68, 5), 'to': (70, 72, 7)}, label='Gallery landing -> the hoist along the catwalk'),
    dict(id='pit-hoist', **{'from': (70, 56, -5), 'to': (70, 72, 7)}, label='Pit -> up the shaft to the hoist'),
    dict(id='court-stairlight', **{'from': (20, 62, -1.5), 'to': (30, 86, 2.5)}, label='Court -> the Ossuary stair light (the Court has no Well view: the far place)'),
]
TRANSITIONS = [
    dict(id='t-camp', at=(29, 60, 0), kind='reveal', label='camp stair -> the hall, the Well framed by the east door'),
    dict(id='t-court', at=(30, 63, 0), kind='turn', label='hall -> court: bent passage, R1, statue seen on entry'),
    dict(id='t-ossuary', at=(46, 74, 1.2), kind='stair', label='hall -> Ossuary: dog-leg stair up'),
    dict(id='t-pump', at=(46, 43, -1.2), kind='stair', label='hall -> Pump Room: dog-leg stair down'),
    dict(id='t-chimebridge', at=(88, 60, 0), kind='bridge', label='rim -> Chime: the bridge over the east arm, R2 at its end'),
    dict(id='t-cascade', at=(77, 47, -2.5), kind='stair', label='rim -> Pit: the cascade down the shaft\'s east wall (R7)'),
    dict(id='t-courtossuary', at=(27, 83, 1.2), kind='stair', label='court -> Ossuary: the long outer stair'),
    dict(id='t-r6', at=(13, 40, -1.2), kind='stair', label='court -> Cistern: R6 stair, crawl-r6 drops beside it'),
    dict(id='t-tunnel', at=(40, 29, -1.0), kind='squeeze', label='Cistern -> Pump: low tunnel that climbs a hump and drops again'),
    dict(id='t-grotto', at=(13, 24, -2.5), kind='squeeze', label='Cistern -> Grotto: low root tunnel'),
    dict(id='t-sump', at=(62, 40, -2.5), kind='squeeze', label='Pump -> Sump Balcony: low tunnel, then the shaft opens'),
    dict(id='t-brine', at=(86, 23, -2.5), kind='turn', label='Cellar -> Sluice: the brine channel bends'),
    dict(id='t-relchime', at=(104, 78, 1.2), kind='stair', label='Reliquary -> Chime: stair down with a landing'),
    dict(id='t-chimesluice', at=(104, 42, -1.2), kind='stair', label='Chime -> Sluice: turn, then stair down'),
    dict(id='t-dive', at=(93, 46, -2.5), kind='stair', label='Chime -> Pit: the dive'),
    dict(id='t-lowbridge', at=(82, 82, 2.5), kind='squeeze', label='Bridge -> Reliquary: low tunnel'),
    dict(id='t-smokestair', at=(94, 100, 3.8), kind='stair', label='Reliquary -> Smokehouse: the smoke stair winds up to +5'),
    dict(id='t-smokewalk', at=(82, 90, 5), kind='bridge', label='the Smoke Walk: +5 catwalk over the Reliquary back to the galleries'),
    dict(id='t-catacomb', at=(-3, 75, 0), kind='squeeze', label='Court -> Catacomb: low tunnel round the back'),
    dict(id='t-catacombgrotto', at=(-8, 42, -1.2), kind='stair', label='Catacomb -> Grotto: winding stair down; the west loop closes'),
]
LANDMARK = dict(id='well', label='THE WELL', at=(70, 60, 0),
                faces=[dict(dir='N', label='hoist (crane, shaft-lit)'), dict(dir='W', label='roots down the wall'), dict(dir='S', label='glyph wall'), dict(dir='E', label='cascade stair (R7)')])
NOTES = dict(
    thesis='Keep v7\'s topology; fix the two complaints with spacing and openings only. Every wing is one authored beat from the hub '
           '(a turn, a stair or a squeeze, never a straight throat) and every level has a window onto the Well, whose four faces differ.',
    principles=['Lynch: the Well is the landmark and the rim is the edge you can always follow; wings are districts; the hall and the rim corners are nodes',
                'Thresholds over distance (Tunic, uxdesign): each transition is a posture or height change with a turn; corridor share may rise, filler may not',
                'View matrix (Dark Souls distant views): hall, Bridge, Chime Bridge, Sump Balcony, catwalk and Pit all see the hoist or the Pit floor',
                'Directional landmark (Disney weenie): hoist N, roots W, glyphs S, cascade E; the Well tells you which side you are on',
                'Fixed front door: S1 is the camp stair into the Arrival Hall; S2..S5 remain as the resolver\'s other entrances',
                'Animal Well: the Pit is reached from four wings (cascade, Chime dive, sump stair, closet ladder), not only from the hub'],
    changes=['Kitchen removed from the hall; cooking is at camp; PK and the aisle ring are gone',
             'Wings pushed 8-16 m out; transitions authored as beats (16 listed)',
             'R2 moved from a throat to the end of a bridge over the Pit\'s east arm',
             'Sump Balcony at -2.5 inside the shaft; P2 moves to the balcony stair; the Drowned Gallery is cut',
             'Grotto kept as the Cistern\'s far room (forage), no spiral',
             'Seven Level Instance tiles; the assembly owns the 16 transitions',
             'Grown rooms (Court, Cistern, Grotto, Pit) are irregular; built rooms stay orthogonal; the Cistern tunnel climbs and drops'],
    changes_extra=None,
    sizing='15-20 min: hunt court + Curing Room (NE, +5) + forage + return; the Catacomb and the Smokehouse add two beads and a loop per side; ~1000 m of plan',
    risks=['Footprint grows to 162 x 126 m: more walk for the pack under adversarial closures (check the per-entrance metrics)',
           'The Court and Cistern still have no Well view; they rely on stair light and the statue',
           'Same room shapes as v7: if the complaint is silhouette rather than spacing, v8b/v8c answer it better'],
)

if __name__ == '__main__':
    import sys
    common.write(sys.modules[__name__])
