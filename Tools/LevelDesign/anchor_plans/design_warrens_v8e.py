"""Warrens v8e, "The Pit is home": the inverted variant. The camp lift lands on the floor of a 30 m cavern at -5 (the
Pit itself, lit from above and below) and everything goes UP from there. Three straight flights climb the cavern's
walls under a cornice (south: -5 to -2.5; east: -2.5 to 0; north: 0 to +2.5) and a wing hangs off each landing: the
waterworks at the south-east landing, the Chime Hall at the north-east, the Ossuary and the Court at the north-west.
The west wall at the floor holds the Camp Door and the Cistern, where the hunt lair now lives (the Drowned Lair, H2).

The compass is the cavern itself: clockwise is up, and every landing looks back down at the lit floor you started on.
Home runs are vertical and earned from above: two barred ladders drop to the floor once their levers are found at the
landings (the Chime ladder on the east wall, the Ossuary ladder on the north wall), and the Chime dive is a winding
stair outside the east wall. Built rooms (Pump, Cellar, Chime, Ossuary, Reliquary) are orthogonal; the cavern, the
Cistern and the Court are not. Tunnels between the wings wind and change height along their length.
"""
import design_warrens_v8_common as common

FILE, REVISION = 'v8e', 'v8e'
SOURCE = 'Tools/LevelDesign/anchor_plans/design_warrens_v8e.py (Warrens v8e "The Pit is home", 2026-10-23)'
TUNNEL, CORRIDOR = common.TUNNEL, common.CORRIDOR
UP, DOWN, DEEPZ, GAL = 2.5, -2.5, -5.0, 5.0
FOOTPRINT = (10, 6, 134, 128)
DEEP = (10, 6, 110, 84)
RAMP_ROOF_Z = -2.4
MAX_CLOSED = 3
CAVERN = [(70, 77), (82, 72), (87, 61), (80, 48), (69, 43), (58, 50), (53, 61), (60, 72)]          # the Pit cavern floor, -5
INNER = [(70, 72), (78, 68.5), (82, 61), (77, 51), (69, 48), (61, 53), (58, 61), (63, 68.5)]           # the open shaft above it (the cornice ring is roofed)

NODES = {
    'K': (46, 60, DEEPZ), 'S1': (34, 60, DEEPZ), 'cw': (54, 61, DEEPZ), 'cf': (70, 60, DEEPZ),             # the Camp Door and the cavern floor
    'ci': (40, 50, DEEPZ), 'CI': (38, 42, DEEPZ), 'H2': (32, 36, DEEPZ), 'S5': (24, 48, DEEPZ),              # the Cistern and the Drowned Lair (H2)
    'fs0': (60, 47, DEEPZ), 'fs1': (80, 47, DOWN),                                                        # flight S: -5 -> -2.5 along the south wall
    'fe1': (83, 70, 0),                                                                                   # flight E: -2.5 -> 0 along the east wall (fs1 -> fe1)
    'fn1': (58, 73, UP),                                                                                  # flight N: 0 -> +2.5 along the north wall (fe1 -> fn1)
    'pe': (88, 44, DOWN), 'PU': (96, 38, DOWN), 'pc': (96, 30, DOWN), 'bm': (104, 24, -1.0), 'CE': (114, 26, DOWN), 'S4': (114, 14, DOWN), 'ps': (104, 44, DOWN),  # the waterworks (SE)
    'chs': (104, 72, 0), 'cn': (88, 74, 0), 'CH': (98, 80, 0), 'chd': (92, 72, 0), 'chn': (100, 88, 0), 'S3': (120, 80, 0),  # the Chime Hall (NE, 0)
    'on': (54, 76, UP), 'O': (45, 81, UP), 'o1': (54, 86, UP),                                              # the Ossuary (NW, +2.5)
    'cd': (62, 90, UP), 'H1': (70, 97, 1.0), 'ce': (82, 98, UP), 'cs': (70, 90, UP), 'S2': (70, 116, UP),    # the Court (N, +2.5; arena at +1)
    'rq': (90, 98, UP), 'RQ': (96, 100, UP), 'rq1': (94, 92, UP), 'rq3': (104, 104, UP), 'sm0': (104, 116, GAL), 'SM': (94, 116, GAL),   # the Reliquary; the Smokehouse (+5) above it
    'ls': (28, 28, DEEPZ), 'BS': (22, 18, DEEPZ), 'bs2': (32, 14, DEEPZ),                                   # the Brine Stores off the lair; the Brine Run back to the dive's foot
    'dv': (72, 45, DEEPZ), 'vt': (84, 70, DEEPZ),                                                         # the dive's foot; the Vault passage
    'rc1': (28, 52, -4.0), 'rc2': (26, 64, -2.0), 'rc3': (30, 72, 0), 'ow': (36, 80, UP),                   # the Root Climb: Cistern up to the Ossuary, 7.5 m in 45 m
}

LINKS = [
    ('S1', 'K', [], CORRIDOR, 'walk', None), ('K', 'cw', [], CORRIDOR, 'walk', None), ('cw', 'cf', [], CORRIDOR, 'walk', None),
    ('K', 'ci', [(42, 56)], TUNNEL, 'walk', None), ('ci', 'CI', [], CORRIDOR, 'walk', None), ('CI', 'H2', [], TUNNEL, 'walk', None), ('S5', 'CI', [(30, 44)], CORRIDOR, 'walk', None),
    ('cf', 'fs0', [], CORRIDOR, 'walk', None), ('cf', 'vt', [], CORRIDOR, 'walk', None), ('cf', 'dv', [], CORRIDOR, 'walk', None),
    # the three flights (geometry in EXTRA_RAMPS)
    ('fs0', 'fs1', [], 4.0, 'ramp', None), ('fs1', 'fe1', [(84, 50)], 4.0, 'ramp', 'R2'), ('fe1', 'fn1', [(70, 74)], 4.0, 'ramp', 'R3'),
    # the waterworks off the SE landing
    ('fs1', 'pe', [(85, 44)], CORRIDOR, 'walk', None), ('pe', 'PU', [], CORRIDOR, 'walk', None), ('PU', 'pc', [], CORRIDOR, 'walk', None), ('PU', 'ps', [], CORRIDOR, 'walk', None),
    ('pc', 'bm', [(100, 26)], TUNNEL, 'stair', 'R1'), ('bm', 'CE', [(109, 25)], TUNNEL, 'stair', None),        # the brine passage: up a hump and down (R1)
    ('CE', 'chs', [(118, 40), (116, 56), (110, 66)], CORRIDOR, 'stair', None),                                 # the Salt Stair: Cellar up to the Chime, winding 43 m
    ('S4', 'CE', [], CORRIDOR, 'walk', None),
    ('ps', 'chs', [(110, 52), (108, 64)], CORRIDOR, 'stair', 'R4'),                                             # the service stair: Pump -> Chime, winding up outside the east wall
    # the Chime Hall off the NE landing
    ('fe1', 'cn', [], CORRIDOR, 'walk', None), ('cn', 'CH', [(92, 78)], CORRIDOR, 'walk', None), ('CH', 'chs', [], CORRIDOR, 'walk', None), ('CH', 'chd', [], CORRIDOR, 'walk', None), ('CH', 'chn', [], CORRIDOR, 'walk', None),
    ('S3', 'CH', [(112, 80)], CORRIDOR, 'walk', None),
    ('chd', 'dv', [(98, 62), (96, 50), (84, 42)], TUNNEL, 'ramp', 'R7'),                                      # the Chime dive: winding down outside the east wall to the floor
    ('chn', 'rq1', [(98, 91)], CORRIDOR, 'stair', None),                                                      # Chime -> Reliquary, stair up with a turn
    # the Ossuary and the Court off the NW landing
    ('fn1', 'on', [], CORRIDOR, 'walk', None), ('on', 'O', [], CORRIDOR, 'walk', None), ('O', 'o1', [], CORRIDOR, 'walk', None), ('ow', 'O', [], CORRIDOR, 'walk', None),
    ('CI', 'rc1', [(32, 46)], TUNNEL, 'ramp', 'R6'), ('rc1', 'rc2', [], TUNNEL, 'ramp', None), ('rc2', 'rc3', [], TUNNEL, 'ramp', None), ('rc3', 'ow', [], TUNNEL, 'ramp', None),  # the Root Climb (R6 at its foot)
    ('fn1', 'cd', [(58, 80), (60, 86)], CORRIDOR, 'walk', None),                                               # NW landing -> Court: the cloister passage
    ('o1', 'cd', [(58, 88)], CORRIDOR, 'walk', 'R5'), ('cd', 'cs', [], CORRIDOR, 'walk', None), ('cs', 'H1', [], CORRIDOR, 'stair', None), ('H1', 'ce', [(78, 97)], CORRIDOR, 'stair', None),
    ('S2', 'cs', [(70, 104)], CORRIDOR, 'walk', None),
    ('ce', 'rq', [], CORRIDOR, 'walk', None), ('rq', 'RQ', [], CORRIDOR, 'walk', None), ('RQ', 'rq1', [], CORRIDOR, 'walk', None),
    ('RQ', 'rq3', [], CORRIDOR, 'walk', None), ('rq3', 'sm0', [(110, 106), (110, 114)], CORRIDOR, 'ramp', None), ('sm0', 'SM', [], CORRIDOR, 'walk', None),  # the smoke stair winds up
    ('H2', 'ls', [], TUNNEL, 'walk', None), ('ls', 'BS', [(24, 22)], TUNNEL, 'walk', None), ('BS', 'bs2', [], CORRIDOR, 'walk', None),
    ('bs2', 'dv', [(44, 12), (58, 14), (68, 24), (72, 34)], TUNNEL, 'walk', None),                               # the Brine Run: a low tunnel under the waterworks back to the dive's foot
]

ROOMS = [
    dict(id='cavern', label='The Pit', poly=CAVERN, z=DEEPZ, light='cold'),
    dict(id='camp', label='Camp Door', poly=[(36, 56), (50, 55), (52, 60), (50, 65), (36, 64), (34, 60)], z=DEEPZ, light='hearth', top=5),
    dict(id='cistern', label='Cistern', poly=[(30, 38), (40, 36), (46, 42), (44, 52), (36, 54), (28, 48)], z=DEEPZ, top=4),
    dict(id='lair', label='Drowned Lair', poly=[(22, 30), (34, 28), (40, 34), (36, 40), (26, 40), (20, 36)], z=DEEPZ, light='cold', top=6),
    dict(id='vault', label='Vault', rect=(88, 66, 96, 74), z=DEEPZ),
    dict(id='landingSE', label='', rect=(80, 44, 86, 50), z=DOWN), dict(id='landingNE', label='', rect=(82, 68, 88, 76), z=0), dict(id='landingNW', label='', rect=(54, 70, 60, 78), z=UP),
    dict(id='pump', label='Pump Room', rect=(88, 30, 104, 46), z=DOWN, light='dim', top=8),
    dict(id='cellar', label='Salt Cellar', rect=(108, 18, 122, 32), z=DOWN, top=3.2),
    dict(id='chime', label='Chime Hall', rect=(88, 72, 108, 88), z=0, light='cold', top=4),
    dict(id='ossuary', label='Ossuary', rect=(36, 74, 54, 88), z=UP, top=5),
    dict(id='court', label='Charnel Court', poly=[(58, 88), (82, 88), (86, 94), (84, 106), (72, 110), (58, 106), (54, 96)], z=UP, light='cold', top=9),
    dict(id='court-pit', label='', poly=[(62, 91), (80, 91), (82, 100), (72, 106), (60, 102)], z=1.0),
    dict(id='reliquary', label='Reliquary', rect=(88, 92, 104, 108), z=UP, light='dim', top=8),
    dict(id='smokehouse', label='Smokehouse', rect=(84, 110, 106, 124), z=GAL, light='dim', top=6),
    dict(id='stores', label='Brine Stores', poly=[(14, 12), (24, 10), (34, 12), (36, 20), (30, 26), (18, 26), (12, 20)], z=DEEPZ, top=4),
]
ENTRANCES = ['S1', 'S2', 'S3', 'S4', 'S5']
COURTS = {'H1': 'H1', 'H2': 'H2', 'H3': 'CH'}

CRAWLS = [
    dict(id='crawl-r4', a=(106, 46), b=(110, 54), z=DOWN, packFits=False, note='beside the service stair\'s foot', purpose='reach the R4 lever on the Chime side; the pack waits in the Pump Room'),
    dict(id='crawl-r5', a=(56, 86), b=(60, 92), z=UP, packFits=False, note='beside R5', purpose='reach the R5 lever in the Court'),
    dict(id='crawl-cistern', a=(46, 46), b=(60, 50), z=DEEPZ, packFits=False, note='from the Cistern\'s east wall into the cavern\'s south-west under the first flight', purpose='the scout\'s short way between the Cistern and the Pit floor'),
    dict(id='crawl-sealed', a=(108, 84), b=(114, 88), z=0, packFits=False, note='a gap behind the Chime Hall\'s east wall', purpose='the Sealed Burial'),
]
UPPER = dict(
    z=GAL, top=12.0, mainTop=4.6,
    tallRooms=['landingNE', 'landingSE', 'landingNW', 'court', 'chime', 'reliquary'],
    platforms=[], walkways=[],
    railGaps=[dict(id='court-window', a=(66, 88), b=(74, 88), note='the Court\'s south rail: a railed opening down 7.5 m into the Pit; the Red key sits on its sill'),
              dict(id='smoke-drop', a=(92, 110), b=(96, 110), note='one-way drop: Smokehouse rail -> the Reliquary floor (2.5 m): the Curing Room\'s short way down')],
)
LADDERS = [
    dict(id='chime-ladder', at=(84, 66), baseZ=DEEPZ, height=5.0, yaw=0.0, kind='barred', oneWay=False, note='east wall: Pit floor up to the NE landing; foot barred until the lever on the landing is pulled (P5)',
         purpose='the Chime wing\'s home run, pack included: found from above'),
    dict(id='ossuary-ladder', at=(62, 70), baseZ=DEEPZ, height=7.5, yaw=0.0, kind='barred', oneWay=False, note='north wall: Pit floor up to the NW landing; foot barred until the lever on the landing is pulled (P6)',
         purpose='the Ossuary wing\'s home run, pack included: found from above'),
]
HOLES = [
    dict(id='shaft-main', level='main', poly=INNER, kind='open', rail=0.6, note='the open shaft over the cavern: the cornice ring round it carries the flights'),
    dict(id='shaft-upper', level='upper', poly=INNER, kind='open'),
    dict(id='court-window', level='main', rect=(66, 86, 74, 88), kind='open', rail=0.9, note='the Court\'s south window: the Pit seen 7.5 m below'),
]
EXTRA_WALKS = [dict(id='vault-passage', level='deep', pts=[(84, 70), (88, 70)], width=2.5)]
EXTRA_RAMPS = [
    dict(id='flight-S', a=(60, 47, DEEPZ), b=(80, 47, DOWN), width=4.0, note='flight S along the south wall: -5 to -2.5 under the cornice (R1 at its foot)'),
    dict(id='flight-E', a=(84, 50, DOWN), b=(84, 68, 0), width=4.0, note='flight E along the east wall: -2.5 to 0 (R2 at its foot)'),
    dict(id='flight-N', a=(80, 74, 0), b=(60, 74, UP), width=4.0, note='flight N along the north wall: 0 to +2.5 (R3 at its foot)'),
    dict(id='dive-a', a=(92, 72, 0), b=(98, 62, -1.5), width=2.5, note='the Chime dive winds down outside the east wall'),
    dict(id='dive-b', a=(98, 62, -1.5), b=(96, 50, -3.0), width=2.5), dict(id='dive-c', a=(96, 50, -3.0), b=(84, 42, -4.5), width=2.5), dict(id='dive-d', a=(84, 42, -4.5), b=(72, 45, DEEPZ), width=2.5),
    dict(id='court-steps', a=(70, 90, UP), b=(70, 94, 1.0), width=4.0, note='the Court\'s steps down into its arena'),
    dict(id='smoke-stair-a', a=(104, 104, UP), b=(110, 106, 3.3), width=3.0, note='the smoke stair: Reliquary up to the Smokehouse'), dict(id='smoke-stair-b', a=(110, 106, 3.3), b=(110, 114, 4.3), width=3.0), dict(id='smoke-stair-c', a=(110, 114, 4.3), b=(104, 116, GAL), width=3.0),
    dict(id='rootclimb-a', a=(32, 46, DEEPZ), b=(28, 52, -4.0), width=2.0, note='the Root Climb: a crawl-sized winding tunnel from the Cistern up to the Ossuary (R6)'),
    dict(id='rootclimb-b', a=(28, 52, -4.0), b=(26, 64, -2.0), width=2.0), dict(id='rootclimb-c', a=(26, 64, -2.0), b=(30, 72, 0), width=2.0), dict(id='rootclimb-d', a=(30, 72, 0), b=(36, 80, UP), width=2.0),
]
SHORTCUTS = []
LIGHTS = [
    dict(at=(70, 60, 9.0), kind='shaft'), dict(at=(70, 60, -3.0), kind='cold'), dict(at=(44, 60, -2.0), kind='hearth'),
    dict(at=(32, 36, -2.0), kind='cold'), dict(at=(70, 97, 6.0), kind='cold'), dict(at=(98, 80, 3.5), kind='cold'), dict(at=(96, 100, 5.1), kind='dim'),
    dict(at=(96, 38, 0.1), kind='dim'), dict(at=(38, 42, -2.4), kind='dim'), dict(at=(45, 81, 5.1), kind='dim'), dict(at=(115, 25, 0.1), kind='dim'),
    dict(at=(94, 116, 7.6), kind='dim'), dict(at=(22, 18, -2.4), kind='dim'),
]
PILLARS = [dict(level='deep', rect=(64, 56, 67, 59)), dict(level='deep', rect=(74, 64, 77, 67)), dict(level='main', rect=(93, 76, 95, 78)), dict(level='main', rect=(101, 82, 103, 84))]
LOW_LINKS = [('K', 'ci'), ('CI', 'H2'), ('pc', 'bm'), ('bm', 'CE'), ('chd', 'dv'), ('CI', 'rc1'), ('rc1', 'rc2'), ('rc2', 'rc3'), ('rc3', 'ow'), ('H2', 'ls'), ('ls', 'BS'), ('bs2', 'dv')]
LOW_ROOF = 2.2
LOCKS = [
    dict(id='vault', door=dict(at=(87, 70), yaw=0.0, spanCm=250.0, level='deep'), lock=dict(at=(86, 68.3), yaw=90.0, level='deep'),
         key='Red', keyAt=(70, 87, 2.8), channel='Mechanism.Channel.Keys.Red', note='the key on the sill of the Court\'s south window, seen from the Pit floor 7.5 m below'),
]
PUZZLES = [
    dict(id='P1', kind='Red key door', at=(87, 70, DEEPZ), needsAt=(70, 87, UP), needsNote='the key on the sill of the Court\'s south window, seen from the floor at arrival'),
    dict(id='P2', kind='latched grate on the Cistern crawl', at=(46, 46, DEEPZ), needsAt=(116, 22, DOWN), needsNote='the Cellar hand-wheel opens the grate so the scout can squeeze from the Cistern straight to the floor', existing='hand-wheel + latched Bars gate'),
    dict(id='P3', kind='Mourner cache gate (latched)', at=(104, 104, UP), needsAt=(40, 86, UP), needsNote='the pack plate at the Ossuary\'s north end, across the Court', latch=True),
    dict(id='P4', kind='Bellkeeper dial lock', at=(106, 86, 0), needsAt=(84, 72, 0), needsNote='the three glyphs on the cavern\'s west wall, read from the NE landing across the shaft'),
    dict(id='P5', kind='barred ladder foot (east wall)', at=(84, 66, DEEPZ), needsAt=(84, 70, 0), needsNote='the lever on the NE landing opens the bars below'),
    dict(id='P6', kind='barred ladder foot (north wall)', at=(62, 70, DEEPZ), needsAt=(58, 74, UP), needsNote='the lever on the NW landing opens the bars below'),
    dict(id='P7', kind='Curing Room (support objective)', at=(90, 118, GAL), needsAt=(32, 36, DEEPZ), needsNote='the Curing Room: the hunted part is brined here before it travels (the run\'s second required stop); the vat, the drying racks, a plinth for the pack'),
]
NICHES = [
    dict(id='camp-pack', rect=(36, 64, 40, 67), z=DEEPZ, family='P', note='pack plinth by the Camp Door'),
    dict(id='cavern-rest', rect=(56, 64, 60, 67), z=DEEPZ, family='N', note='lantern rest at the cavern\'s west wall'),
    dict(id='cavern-omen', rect=(70, 42, 72, 44), z=DEEPZ, family='O', note='eyes in the south wall niche under the first flight'),
    dict(id='cavern-forage', rect=(86, 58, 90, 62), z=DEEPZ, family='F', note='deep mushrooms under the east wall'),
    dict(id='cavern-shelf', rect=(60, 76, 66, 79), z=-3.0, family='O', note='a root shelf 2 m up the north wall: a ledge hop off the ladder foot'),
    dict(id='cistern-forage', rect=(26, 48, 30, 52), z=DEEPZ, family='F', note='mushroom bed by the basin'),
    dict(id='lair-threat', rect=(20, 40, 24, 43), z=DEEPZ, family='T', note='sentry niche at the lair mouth'),
    dict(id='lair-pack', rect=(40, 30, 44, 33), z=DEEPZ, family='P', note='pack plinth outside the lair, out of the home radius'),
    dict(id='pump-omen', rect=(88, 46, 92, 49), z=DOWN, family='O', note='swaying chains in the north niche'),
    dict(id='pump-shelf', rect=(100, 46, 104, 49), z=-0.5, family='N', note='a maintenance shelf 2 m up: a ledge hop off the pump'),
    dict(id='cellar-salt', rect=(122, 22, 126, 26), z=DOWN, family='F', note='salt crystals'),
    dict(id='porter', rect=(112, 32, 118, 38), z=DOWN, family='C', note='Porter\'s Wager: the freight niche'),
    dict(id='bellkeeper', rect=(108, 88, 114, 92), z=0, family='C', note='Bellkeeper\'s Confession behind the dial lock (P4)'),
    dict(id='chime-threat', rect=(104, 68, 108, 72), z=0, family='T', note='sentry niche at the service stair head'),
    dict(id='chime-pack', rect=(108, 76, 112, 80), z=0, family='P', note='pack plinth by the S3 way in'),
    dict(id='sealed-burial', rect=(114, 86, 119, 92), z=0, family='C', note='the Sealed Burial behind crawl-sealed'),
    dict(id='ossuary-husk', rect=(32, 78, 36, 82), z=UP, family='F', note='husk spill in the west niche'),
    dict(id='ossuary-rest', rect=(50, 88, 54, 91), z=UP, family='N', note='lantern rest by the Court passage'),
    dict(id='court-omen', rect=(54, 98, 56, 100), z=UP, family='O', note='eyes in the west wall niche'),
    dict(id='court-threat', rect=(84, 102, 88, 106), z=UP, family='T', note='sentry alcove east of the arena'),
    dict(id='court-pack', rect=(66, 110, 70, 113), z=UP, family='P', note='pack plinth by the S2 mouth'),
    dict(id='mourner', rect=(104, 102, 110, 106), z=UP, family='C', note='Mourner cache behind the pack-plate gate (P3)'),
    dict(id='reliquary-rest', rect=(104, 94, 108, 97), z=UP, family='N', note='lantern rest'),
    dict(id='smoke-pack', rect=(106, 118, 110, 121), z=GAL, family='P', note='pack plinth by the vat'), dict(id='smoke-threat', rect=(84, 124, 88, 128), z=GAL, family='T', note='something in the rack row'),
    dict(id='smoke-rest', rect=(80, 112, 84, 115), z=GAL, family='N', note='lantern rest at the west wall'),
    dict(id='stores-forage', rect=(10, 14, 14, 18), z=DEEPZ, family='F', note='brined stores: a wade to reach them'), dict(id='stores-cache', rect=(26, 6, 32, 10), z=DEEPZ, family='C', note='the Stores cache: a sealed cask'),
    dict(id='stores-omen', rect=(36, 14, 38, 16), z=DEEPZ, family='O', note='chains over the brine'), dict(id='run-threat', rect=(58, 10, 62, 14), z=DEEPZ, family='T', note='something in the Brine Run'),
]
WATER = [
    dict(id='cistern-basin', poly=[(32, 40), (40, 38), (44, 44), (40, 50), (32, 50)], z=DEEPZ, depth=0.5, note='the Cistern pool'),
    dict(id='lair-water', poly=[(24, 32), (34, 30), (38, 36), (30, 38)], z=DEEPZ, depth=0.5, note='the Drowned Lair: knee-deep'),
    dict(id='stores-water', poly=[(16, 14), (26, 12), (32, 16), (28, 24), (18, 24)], z=DEEPZ, depth=0.5, note='the Brine Stores: knee-deep'),
]
PROPS = [
    dict(kind='station', at=(70, 60, DEEPZ), size=(2.4, 2.4, 2.0), note='the camp lift\'s landing cage in the cavern\'s centre: home'),
    dict(kind='station', at=(70, 73, UP), size=(1.6, 1.6, 7.0), note='THE HOIST over the north flight: seen from the floor and every landing'),
    dict(kind='plinth', at=(70, 87, UP), size=(0.8, 0.8, 0.3), note='the key plinth on the Court window sill (P1)'),
    dict(kind='stack', at=(56, 60, -3.0), size=(0.3, 6.0, 2.0), note='the three glyphs on the cavern\'s west wall (P4), read from the NE landing'),
    dict(kind='root', at=(60, 66, DEEPZ), size=(1.4, 1.4, 12.0), note='roots down the north-west wall'), dict(kind='root', at=(78, 52, DEEPZ), size=(1.0, 1.0, 10.0)),
    dict(kind='statue', at=(70, 108, UP), size=(2.0, 1.2, 4.5), yaw=-90, note='split mourner at the Court\'s north'),
    dict(kind='stack', at=(42, 78, UP), size=(6.0, 1.0, 2.6), note='bone stacks'), dict(kind='stack', at=(48, 84, UP), size=(6.0, 1.0, 2.6)),
    dict(kind='plinth', at=(40, 86, UP), size=(2.0, 2.0, 0.3), note='the pack plate (P3)'),
    dict(kind='sarcophagus', at=(96, 100, UP), size=(3.0, 1.5, 1.2), note='the reliquary tomb'),
    dict(kind='chimes', at=(98, 80, 0), size=(6.0, 0.2, 3.0), yaw=0, note='bone chimes across the low hall'),
    dict(kind='station', at=(106, 86, 0), size=(1.0, 0.4, 1.4), note='the dial lock (P4)'),
    dict(kind='pillar', at=(92, 34, DOWN), size=(2.5, 2.5, 6.0), note='the pump: the south-east\'s audio landmark'),
    dict(kind='pillar', at=(116, 22, DOWN), size=(1.0, 1.0, 1.6), note='the hand-wheel (P2)'),
    dict(kind='stack', at=(118, 28, DOWN), size=(2.0, 2.0, 1.4), note='salt crystals'),
    dict(kind='station', at=(46, 46, DEEPZ), size=(0.3, 2.0, 1.3), note='the latched grate on the Cistern crawl (P2)'),
    dict(kind='candles', at=(38, 58, DEEPZ), size=(0.9, 0.9, 0.5), note='tallow'), dict(kind='candles', at=(90, 46, DOWN), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(90, 74, 0), size=(0.9, 0.9, 0.5), note='tallow'), dict(kind='candles', at=(38, 76, UP), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='station', at=(90, 118, GAL), size=(2.4, 1.6, 1.4), note='the brine vat (P7): the Curing Room'), dict(kind='stack', at=(98, 114, GAL), size=(8.0, 0.6, 2.2), note='drying racks'),
]
ANCHOR_AT = {'R1': (99, 27), 'R2': (84, 52), 'R3': (78, 74), 'R4': (106, 48), 'R5': (56, 88), 'R6': (33, 46), 'R7': (94, 70)}
LEVER_NODE = {'R4': 'chs', 'R5': 'cd'}
MAX_ACTIVE_CACHES = 2

INSTANCES = [
    dict(id='Cavern', label='LI_Warrens_Cavern', asset='LI_Warrens_Cavern', z=-5, rect=(50, 40, 90, 80),
         ports=[dict(id='camp', at=(52, 60, -5), width=3, kind='door'), dict(id='SE', at=(86, 47, -2.5), width=4, kind='door'), dict(id='NE', at=(88, 72, 0), width=3, kind='door'),
                dict(id='NW', at=(54, 74, 2.5), width=3, kind='door'), dict(id='dive', at=(72, 44, -5), width=2.5, kind='stair'), dict(id='vault', at=(88, 70, -5), width=2.5, kind='door'),
                dict(id='cistern-crawl', at=(50, 48, -5), width=1.5, kind='crawl'), dict(id='window', at=(70, 86, 2.5), width=8, kind='balcony')],
         note='the cavern floor, the cornice ring, three flights, two barred ladders, the hoist, the lift cage: the persistent landmark'),
    dict(id='Camp', label='LI_Warrens_Camp', asset='LI_Warrens_Camp', z=-5, rect=(18, 26, 52, 68),
         ports=[dict(id='cavern', at=(52, 60, -5), width=3, kind='door'), dict(id='crawl', at=(50, 48, -5), width=1.5, kind='crawl'), dict(id='S1', at=(34, 60, -5), width=3, kind='door'), dict(id='S5', at=(24, 48, -5), width=3, kind='door'), dict(id='rootclimb', at=(30, 68, -1), width=2, kind='crawl')],
         note='Camp Door, Cistern, the Drowned Lair (H2), the foot of the Root Climb'),
    dict(id='Waterworks', label='LI_Warrens_Waterworks', asset='LI_Warrens_Waterworks', z=-2.5, rect=(86, 12, 126, 50),
         ports=[dict(id='landing', at=(86, 46, -2.5), width=3, kind='door'), dict(id='service', at=(108, 50, -2.5), width=3, kind='stair'), dict(id='salt', at=(118, 44, -2.5), width=3, kind='stair'), dict(id='S4', at=(114, 14, -2.5), width=3, kind='door')],
         note='Pump Room, the brine passage over its hump, Salt Cellar'),
    dict(id='Chime', label='LI_Warrens_Chime', asset='LI_Warrens_Chime', z=0, rect=(86, 60, 124, 92),
         ports=[dict(id='landing', at=(88, 74, 0), width=3, kind='door'), dict(id='service', at=(108, 64, 0), width=3, kind='stair'), dict(id='salt', at=(112, 68, 0), width=3, kind='stair'), dict(id='dive', at=(94, 70, 0), width=2.5, kind='stair'),
                dict(id='reliquary', at=(100, 92, 0), width=3, kind='stair'), dict(id='S3', at=(120, 80, 0), width=3, kind='door')]),
    dict(id='Ossuary', label='LI_Warrens_Ossuary', asset='LI_Warrens_Ossuary', z=2.5, rect=(30, 70, 60, 92),
         ports=[dict(id='landing', at=(54, 76, 2.5), width=3, kind='door'), dict(id='court', at=(60, 90, 2.5), width=3, kind='door'), dict(id='rootclimb', at=(34, 80, 2.5), width=2, kind='crawl')]),
    dict(id='Court', label='LI_Warrens_Court', asset='LI_Warrens_Court', z=2.5, rect=(52, 86, 88, 118),
         ports=[dict(id='ossuary', at=(60, 90, 2.5), width=3, kind='door'), dict(id='landing', at=(60, 86, 2.5), width=3, kind='door'), dict(id='reliquary', at=(88, 98, 2.5), width=3, kind='door'), dict(id='window', at=(70, 88, 2.5), width=8, kind='balcony'), dict(id='S2', at=(70, 116, 2.5), width=3, kind='door')],
         note='the Court at +2.5 with its +1 arena (H1); its south window looks down into the Pit'),
    dict(id='Reliquary', label='LI_Warrens_Reliquary', asset='LI_Warrens_Reliquary', z=2.5, rect=(86, 88, 112, 112),
         ports=[dict(id='court', at=(88, 98, 2.5), width=3, kind='door'), dict(id='chime', at=(100, 90, 2.5), width=3, kind='stair'), dict(id='smoke', at=(106, 104, 2.5), width=3, kind='stair')]),
    dict(id='Smokehouse', label='LI_Warrens_Smokehouse', asset='LI_Warrens_Smokehouse', z=5, rect=(78, 108, 114, 130),
         ports=[dict(id='reliquary', at=(106, 104, 2.5), width=3, kind='stair'), dict(id='drop', at=(94, 110, 5), width=2, kind='drop')], note='the Curing Room (P7) above the Reliquary'),
    dict(id='Stores', label='LI_Warrens_Stores', asset='LI_Warrens_Stores', z=-5, rect=(8, 4, 78, 30),
         ports=[dict(id='lair', at=(28, 28, -5), width=2.5, kind='crawl'), dict(id='dive', at=(72, 36, -5), width=2.5, kind='crawl')], note='the Brine Stores and the Brine Run: the deep loop under the waterworks'),
]
VIEWS = [
    dict(id='floor-up', **{'from': (70, 58, -5), 'to': (70, 73, 9)}, label='the floor (arrival) -> up the shaft to the hoist and the Court window'),
    dict(id='floor-key', **{'from': (70, 58, -5), 'to': (70, 87, 2.8)}, label='the floor -> the Red key on the Court window sill'),
    dict(id='landingSE-floor', **{'from': (83, 47, -2.5), 'to': (70, 60, -5)}, label='SE landing -> the lit floor'),
    dict(id='landingNE-glyphs', **{'from': (84, 72, 0), 'to': (56, 60, -3)}, label='NE landing -> the glyphs on the west wall (P4)'),
    dict(id='landingNE-floor', **{'from': (84, 72, 0), 'to': (70, 60, -5)}, label='NE landing -> the floor, 5 m down'),
    dict(id='landingNW-floor', **{'from': (57, 74, 2.5), 'to': (70, 60, -5)}, label='NW landing -> the floor, 7.5 m down'),
    dict(id='window-floor', **{'from': (70, 90, 2.5), 'to': (70, 60, -5)}, label='Court window -> the Pit floor'),
    dict(id='camp-cavern', **{'from': (48, 60, -5), 'to': (70, 73, 9)}, label='Camp Door -> across the cavern floor to the hoist'),
]
TRANSITIONS = [
    dict(id='t-arrive', at=(53, 60, -5), kind='reveal', label='Camp Door -> the cavern: the whole shaft above you'),
    dict(id='t-flightS', at=(70, 47, -3.75), kind='stair', label='flight S under the cornice (R1)'),
    dict(id='t-flightE', at=(84, 59, -1.25), kind='stair', label='flight E (R2)'),
    dict(id='t-flightN', at=(70, 74, 1.25), kind='stair', label='flight N (R3), the hoist overhead'),
    dict(id='t-pump', at=(87, 45, -2.5), kind='turn', label='SE landing -> Pump Room: a turn away from the shaft'),
    dict(id='t-brine', at=(104, 24, -1.0), kind='squeeze', label='Pump -> Cellar: the brine passage over a hump'),
    dict(id='t-service', at=(109, 58, -1.2), kind='stair', label='Pump -> Chime: the winding service stair (R4)'),
    dict(id='t-chime', at=(90, 76, 0), kind='turn', label='NE landing -> Chime Hall'),
    dict(id='t-dive', at=(97, 56, -2.2), kind='stair', label='Chime -> floor: the winding dive outside the east wall (R7)'),
    dict(id='t-reliquary', at=(98, 90, 1.2), kind='stair', label='Chime -> Reliquary: stair up with a turn (R6)'),
    dict(id='t-ossuary', at=(54, 76, 2.5), kind='turn', label='NW landing -> Ossuary'),
    dict(id='t-court', at=(58, 88, 2.5), kind='reveal', label='Ossuary -> Court (R5): the arena and the window'),
    dict(id='t-cistern', at=(42, 56, -5), kind='squeeze', label='Camp Door -> Cistern: low tunnel'),
    dict(id='t-rootclimb', at=(27, 62, -2), kind='squeeze', label='the Root Climb: Cistern -> Ossuary, 7.5 m up in a winding crawl-tunnel (R6)'),
    dict(id='t-saltstair', at=(116, 54, -1.2), kind='stair', label='the Salt Stair: Cellar -> Chime, winding 43 m up'),
    dict(id='t-cloister', at=(59, 83, 2.5), kind='turn', label='NW landing -> Court: the cloister passage'),
    dict(id='t-lairmouth', at=(36, 40, -5), kind='squeeze', label='Cistern -> Drowned Lair (H2): the lair mouth'),
    dict(id='t-cisterncrawl', at=(53, 48, -5), kind='squeeze', label='Cistern -> floor: the crawl under flight S (P2)'),
    dict(id='t-shelf', at=(63, 76, -3), kind='jump', label='ledge hop: ladder foot -> the root shelf'),
    dict(id='t-pumpshelf', at=(102, 46, -1.0), kind='jump', label='ledge hop: off the pump onto the maintenance shelf'),
    dict(id='t-ladderE', at=(84, 66, -2), kind='ladder', label='Chime ladder home run (P5): NE landing -> floor, two-way once opened'),
    dict(id='t-ladderN', at=(62, 70, -1), kind='ladder', label='Ossuary ladder home run (P6): NW landing -> floor, two-way once opened'),
    dict(id='t-smokestair', at=(110, 110, 3.8), kind='stair', label='Reliquary -> Smokehouse: the smoke stair winds up to +5'),
    dict(id='t-smokedrop', at=(94, 110, 5), kind='drop', label='one-way drop: Smokehouse -> Reliquary (2.5 m)'),
    dict(id='t-stores', at=(25, 24, -5), kind='squeeze', label='Drowned Lair -> Brine Stores: low tunnel'),
    dict(id='t-brinerun', at=(58, 14, -5), kind='squeeze', label='the Brine Run: a 50 m low tunnel under the waterworks back to the dive\'s foot; the deep loop closes'),
]
LANDMARK = dict(id='cavern', label='THE PIT (home, -5) under the open shaft', at=(70, 60, -5),
                faces=[dict(dir='N', label='the north flight, the hoist, the Court window and key above'), dict(dir='E', label='the east flight and the Chime ladder'),
                       dict(dir='S', label='the south flight under the cornice; the dive\'s foot'), dict(dir='W', label='the Camp Door, the glyph wall')])
NOTES = dict(
    thesis='Home is the bottom of the landmark. Arrive on the Pit floor, climb clockwise, and every landing looks back down at the lit floor you '
           'started on; the ways home are vertical and earned from above. The hunt lair leaves the Pit for the Drowned Lair.',
    principles=['Animal Well: the hub is the shaft itself and every wing touches it (three landings, two ladders, a crawl, a window)',
                'Deep Dish: the connectors are winding tunnels that change height (service stair, dive, brine passage) and crawls and ledge hops, not flat corridors',
                'Firelink: the home spot faces the landmark; the key (P1) is visible from the arrival, 7.5 m up on the Court sill',
                'Souls shortcuts from above: both ladders are opened at their landing and give the pack a straight drop home',
                'Cavern and dungeon: the cavern, Cistern, lair and Court are grown; the Pump, Cellar, Chime, Ossuary and Reliquary are built',
                'Deep barrier: the cornice ring keeps the flights off the open shaft, so the view is always down into the centre'],
    changes=['The camp lift lands on the Pit floor (K at -5); the Pit stops being a hunt court; H2 moves to the Drowned Lair off the Cistern',
             'The Root Climb (Cistern -> Ossuary) and the Salt Stair (Cellar -> Chime) are the two long winding climbs that keep every wing on a loop without the cavern',
             'Three straight flights replace the cascade and the rim; the rim\'s functions move to the three landings',
             'Two barred ladders (P5, P6) replace the closet; the Chime dive winds outside the east wall',
             'Floor heights -5 / -2.5 / 0 / +1 / +2.5; the open shaft rises to +12',
             'Seven Level Instance tiles; the cavern tile holds every vertical connection'],
    sizing='15-20 min: hunt (Drowned Lair) + Curing Room (NE, +5) + forage + return; the Stores and the Brine Run add a deep loop, the Smokehouse a top bead',
    risks=['A map that only goes up means every outbound trip is a climb with the pack on the return; the ladders are the fix, and they are gated',
           'The lair leaving the Pit loses the "the monster is under everything" reading the v5 reviews praised',
           'Three flights on one cavern wall need real headroom under the cornice (4.6 m assumed) and rails on the open side',
           'The Court window as a key reveal depends on the floor\'s light reaching +2.5'],
)

if __name__ == '__main__':
    import sys
    common.write(sys.modules[__name__])
