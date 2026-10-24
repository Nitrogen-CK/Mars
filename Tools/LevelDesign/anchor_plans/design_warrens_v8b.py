"""Warrens v8b, "The Cascade": the district is a helix round one deep shaft. Eight wings at eight heights (+10 arrival
down to -7.5 Pit), each opening onto the shaft at its own level, so your depth tells you where you are and the hoist
at the top and the Pit glow at the bottom are the two ends of one compass needle. The vertical variant.

Shape: the Well is an 18 x 18 shaft from +10 to -7.5. The Great Stair, a 5 m wide ramp, winds one and three-quarter
turns... no: seven octants, 2.5 m per octant, from the north landing (+10) clockwise to the north-west (-7.5) where it
walks out onto the Pit floor. Each octant corner is a landing with a wing behind it:
  N  +10  Arrival Hall (the camp lift lands here; K)      NE +7.5 Charnel Court (H1)
  E  +5   Ossuary                                         SE +2.5 Reliquary
  S   0   Chime Hall (H3)                                 SW -2.5 Salt Cellar and Sluice
  W  -5   Pump Room                                       NW -7.5 the Pit floor (H2), the Cistern beyond
A second, outer helix (the Service Stair) links neighbouring wings on their far sides, so no wing is a dead end and the
Great Stair is never a mandatory commute. Shortcuts: the counterweight lift in the shaft (the Pit's home run for the
pack, once its lever is pulled at the bottom), three one-way drops between neighbouring wings, the closet ladder.
Rooms at eight heights render on the viewer's three grids because no two wings share XY.
"""
import design_warrens_v8_common as common

FILE, REVISION = 'v8b', 'v8b'
SOURCE = 'Tools/LevelDesign/anchor_plans/design_warrens_v8b.py (Warrens v8b "The Cascade", 2026-10-23)'
TUNNEL, CORRIDOR = common.TUNNEL, common.CORRIDOR
FOOTPRINT = (0, 10, 134, 110)
DEEP = (0, 16, 100, 102)  # build deviation: x0 4 -> 0, room for the S5 foyer west of the Cistern
RAMP_ROOF_Z = -2.4
RAMP_OVERRIDES = [dict(link=['sl1', 'pw1'], roofZ=-5.0, note='P5b: the Service Stair Cellar -> Pump starts at -2.5, below the default rampRoofZ: open its whole length (an open stairwell), else the rock over its head sits on the treads')]
MAX_CLOSED = 3
C = (70, 60)  # the shaft centre
# the Great Stair's octant corners (centreline radius 11.5) and heights
RING = {'rN': (70, 71.5, 10), 'rNE': (78.1, 68.1, 7.5), 'rE': (81.5, 60, 5), 'rSE': (78.1, 51.9, 2.5),
        'rS': (70, 48.5, 0), 'rSW': (61.9, 51.9, -2.5), 'rW': (58.5, 60, -5), 'rNW': (61.9, 68.1, -7.5)}
RING_ORDER = ['rN', 'rNE', 'rE', 'rSE', 'rS', 'rSW', 'rW', 'rNW']

NODES = dict(RING)
NODES.update({
    'K': (70, 83, 10), 'kn': (70, 76, 10), 'S1': (70, 98, 10), 'lt': (66, 71, 10),          # the Arrival Hall; lt = the lift head
    'c0': (86, 76, 7.5), 'H1': (94, 84, 7.5), 'c1': (96, 74, 7.5), 'S2': (108, 101, 7.5),       # the Court (NE, +7.5)
    'o0': (88, 60, 5), 'O': (96, 60, 5), 'o1': (100, 68, 5), 'o2': (100, 52, 5),             # the Ossuary (E, +5)
    'rq0': (90, 44, 2.5), 'RQ': (96, 36, 2.5), 'rq1': (100, 44, 2.5), 'rq2': (88, 34, 2.5), 'S3': (112, 36, 2.5),  # the Reliquary (SE, +2.5)
    'ch0': (70, 44, 0), 'CH': (70, 35, 0), 'ch1': (80, 32, 0), 'ch3': (60, 40, 0), 'ch2': (60, 28, 0),           # the Chime Hall (S, 0)
    'sw0': (52, 44, -2.5), 'CE': (44, 36, -2.5), 'sl0': (52, 40, -2.5), 'sl1': (40, 44, -2.5), 'S4': (19, 36, -2.5),  # Cellar + Sluice (SW, -2.5)
    'pw': (50, 60, -5), 'PU': (42, 60, -5), 'pw1': (40, 55, -5), 'pw2': (34, 64, -5),                                # the Pump Room (W, -5)
    'ci0': (28, 70, -7.5), 'CI': (21, 67, -7.5), 'ci1': (26, 62, -7.5), 'dg': (36, 42, -6.5), 'gx': (45.13, 40.17, -7.5), 'S5': (6, 73, -7.5),                       # the Cistern (-7.5)
    'H2': (70, 60, -7.5), 'lw': (54, 48, -7.5), 'lsw': (54, 46, -7.5), 'lb': (66, 71, -7.5),                         # the Pit floor; lb = the lift foot
    'rq3': (104, 40, 2.5), 'sm0': (110, 52, 0), 'SM': (116, 50, 0),                                                # the Smokehouse (0): the Curing Room, east of the Reliquary
    'ci2': (20, 75, -7.5), 'BL': (16, 88, -7.5), 'bl1': (24, 90, -7.5), 'pw3': (38, 68, -5),                        # the Brine Larder: the far low bead
})


def ring_links():
    out = []
    for a, b in zip(RING_ORDER, RING_ORDER[1:]):
        gate = {'rNE': 'R1', 'rSE': 'R2', 'rSW': 'R3', 'rW': 'R4'}.get(a)   # the gate sits at the top of the octant it closes
        out.append((a, b, [], 5.0, 'ramp', gate))
    return out


LINKS = ring_links() + [
    ('S1', 'K', [(70, 90)], CORRIDOR, 'walk', None), ('K', 'kn', [], CORRIDOR, 'walk', None), ('kn', 'rN', [], CORRIDOR, 'walk', None),
    ('rN', 'lt', [], CORRIDOR, 'walk', None), ('lt', 'lb', [], 3.0, 'lift', None, dict(shortcut='the counterweight lift: called from the Pit floor (P5), then two-way')),
    # the Court (NE)
    ('rNE', 'c0', [(82, 72)], CORRIDOR, 'walk', None), ('c0', 'H1', [], CORRIDOR, 'walk', None), ('H1', 'c1', [], CORRIDOR, 'walk', None), ('S2', 'H1', [(100, 86)], CORRIDOR, 'walk', None),
    ('c1', 'o1', [(100, 72)], CORRIDOR, 'stair', None),                                 # the Service Stair: Court -> Ossuary
    # the Ossuary (E)
    ('rE', 'o0', [], CORRIDOR, 'walk', None), ('o0', 'O', [], CORRIDOR, 'walk', None), ('O', 'o1', [], CORRIDOR, 'walk', None), ('O', 'o2', [], CORRIDOR, 'walk', None),
    ('o2', 'rq1', [], CORRIDOR, 'ramp', 'R5'),                                           # Service Stair: Ossuary -> Reliquary (R5)
    # the Reliquary (SE)
    ('rSE', 'rq0', [(84, 48)], CORRIDOR, 'walk', None), ('rq0', 'RQ', [], CORRIDOR, 'walk', None), ('rq1', 'RQ', [], CORRIDOR, 'walk', None), ('RQ', 'rq2', [], CORRIDOR, 'walk', None),
    ('S3', 'RQ', [], CORRIDOR, 'walk', None),
    ('RQ', 'rq3', [], CORRIDOR, 'walk', None), ('rq3', 'sm0', [(108, 44), (110, 48)], CORRIDOR, 'stair', None), ('sm0', 'SM', [], CORRIDOR, 'walk', None),  # the smoke stair winds down
    ('CI', 'ci2', [], CORRIDOR, 'walk', None), ('ci2', 'BL', [(16, 80), (14, 84)], TUNNEL, 'walk', None), ('BL', 'bl1', [], CORRIDOR, 'walk', None),
    ('bl1', 'pw3', [(30, 86), (34, 78)], TUNNEL, 'stair', None),                                                       # the Brine Stair: Larder up to the Pump; the low loop closes
    ('rq2', 'ch1', [], CORRIDOR, 'ramp', None),                                          # Service Stair: Reliquary -> Chime
    # the Chime Hall (S)
    ('rS', 'ch0', [], CORRIDOR, 'walk', None), ('ch0', 'CH', [], CORRIDOR, 'walk', None), ('CH', 'ch1', [], CORRIDOR, 'walk', None), ('CH', 'ch3', [], CORRIDOR, 'walk', None), ('CH', 'ch2', [], CORRIDOR, 'walk', None),
    ('ch3', 'sl0', [(56, 42)], CORRIDOR, 'stair', 'R6'),                                 # Service Stair: Chime -> Cellar (R6)
    ('ch2', 'lsw', [(44, 26), (42, 36), (48, 44)], TUNNEL, 'ramp', 'R7'),                # the dive: Chime -> under the Cellar -> the Pit's south-west (R7)
    # the Cellar and Sluice (SW)
    ('rSW', 'sw0', [(56, 48)], CORRIDOR, 'walk', None), ('sw0', 'CE', [(48, 40)], CORRIDOR, 'walk', None), ('sl0', 'CE', [], CORRIDOR, 'walk', None), ('CE', 'sl1', [], CORRIDOR, 'walk', None),
    ('S4', 'CE', [], CORRIDOR, 'walk', None),
    ('sl1', 'pw1', [], CORRIDOR, 'stair', None),                                 # Service Stair: Cellar -> Pump
    # the Pump Room (W); rW-pw: build deviation, a railed deck over the Pit floor's west edge (the Pit polygon reaches under it)
    ('rW', 'pw', [], CORRIDOR, 'walk', None, dict(over=True, ownDeck=True)), ('pw', 'PU', [], CORRIDOR, 'walk', None), ('pw1', 'PU', [], CORRIDOR, 'walk', None), ('PU', 'pw2', [], CORRIDOR, 'walk', None),
    ('pw2', 'ci0', [(31, 68)], CORRIDOR, 'ramp', None),                                  # Service Stair: Pump -> Cistern
    # the Cistern and the Pit
    ('ci0', 'CI', [], CORRIDOR, 'walk', None), ('CI', 'ci1', [], CORRIDOR, 'walk', None), ('S5', 'CI', [], CORRIDOR, 'walk', None),
    ('ci1', 'dg', [(24, 52), (26, 44)], TUNNEL, 'stair', None), ('dg', 'gx', [], TUNNEL, 'stair', None), ('gx', 'lw', [(46, 40), (52, 44)], TUNNEL, 'walk', None),   # the Drowned Gallery: knee-deep, swings south under the Cellar, climbs a hump
    ('lw', 'H2', [(64, 47)], TUNNEL, 'walk', None), ('lsw', 'H2', [(64, 47)], TUNNEL, 'walk', None),  # build deviation: vias round the Great Stair's SW flight
    ('rNW', 'H2', [], CORRIDOR, 'walk', None), ('lb', 'H2', [], CORRIDOR, 'walk', None),
]

ROOMS = [
    dict(id='hall', label='Arrival Hall', rect=(62, 76, 78, 90), z=10, light='hearth'),
    dict(id='landingN', label='', rect=(64, 67, 76, 76), z=10),
    dict(id='landingNE', label='', rect=(78, 68, 83, 72), z=7.5), dict(id='landingE', label='', rect=(82, 57, 86, 63), z=5),
    dict(id='landingSE', label='', rect=(78, 48, 83, 53), z=2.5), dict(id='landingS', label='', rect=(66, 45, 74, 49), z=0),
    dict(id='landingSW', label='', rect=(57, 48, 62, 53), z=-2.5),
    dict(id='court', label='Charnel Court', poly=[(84, 76), (96, 72), (106, 78), (106, 92), (100, 96), (86, 94), (82, 86)], z=7.5, light='cold', top=9),
    dict(id='ossuary', label='Ossuary', rect=(88, 52, 104, 68), z=5),
    dict(id='reliquary', label='Reliquary', rect=(88, 28, 104, 44), z=2.5, light='dim'),
    dict(id='chime', label='Chime Hall', rect=(60, 26, 80, 44), z=0, light='cold'),
    dict(id='cellar', label='Salt Cellar', poly=[(36, 28), (50, 26), (54, 34), (52, 44), (38, 45), (34, 36)], z=-2.5, top=3.5),
    dict(id='sluice', label='Sluice', rect=(24, 30, 36, 42), z=-2.5, light='dim'),
    dict(id='pump', label='Pump Room', poly=[(34, 51), (50, 52), (51, 62), (48, 68), (36, 69), (32, 60)], z=-5, light='dim', top=8),
    dict(id='cistern', label='Cistern', poly=[(14, 60), (22, 58), (29, 63), (28, 72), (20, 75), (13, 70)], z=-7.5, top=4),
    dict(id='lair', label='The Pit', poly=[(54, 46), (70, 42), (86, 46), (90, 62), (84, 76), (66, 78), (54, 74), (52, 60)], z=-7.5, light='cold'),  # build deviation (sanctioned closet): west vertex (50,60) -> (52,60)
    dict(id='landingW', label='', rect=(54, 57, 58, 63), z=-5),  # build deviation: stamped after the Pit (it was sunk to -7.5 under the Pit's polygon)
    dict(id='closet', label='', rect=(50, 66, 53, 69), z=-5, top=3),  # sanctioned addition (coordinator, P3): the Pump closet the closet ladder climbs into; SC2 is its door
    dict(id='vault', label='Vault', rect=(88, 68, 96, 76), z=-7.5),
    dict(id='smokehouse', label='Smokehouse', poly=[(108, 42), (122, 40), (126, 48), (122, 58), (110, 58), (106, 50)], z=0, light='dim', top=6),
    dict(id='larder', label='Brine Larder', poly=[(8, 82), (18, 80), (26, 86), (24, 96), (14, 98), (6, 92)], z=-7.5, top=4),
]
ENTRANCES = ['S1', 'S2', 'S3', 'S4', 'S5']
COURTS = {'H1': 'H1', 'H2': 'H2', 'H3': 'CH'}

CRAWLS = [
    dict(id='crawl-r1', a=(80, 72), b=(84, 78), z=7.5, packFits=False, note='beside R1 at the Court landing', purpose='reach the R1 lever on the Ossuary side of the octant; the pack waits in the Court'),
    dict(id='crawl-r5', a=(102.75, 53), via=[(102.75, 47)], b=(101.5, 47), z=5, packFits=False, note='beside the Ossuary-Reliquary stair', purpose='reach the R5 lever in the Reliquary; the pack waits in the Ossuary'),
    dict(id='crawl-r6', a=(60.5, 43), b=(54, 46), z=0, packFits=False, note='beside the Chime-Cellar stair', purpose='reach the R6 lever in the Cellar; the pack waits in the Chime Hall'),
    dict(id='crawl-sealed', a=(104, 36), b=(109, 30), z=2.5, packFits=False, note='a gap behind the Reliquary\'s east wall', purpose='the one squeeze that leads somewhere new: the Sealed Burial'),
]
UPPER = dict(
    z=10, top=15.0, mainTop=4.6, tallRooms=[],
    platforms=[], walkways=[],
    railGaps=[dict(id='court-drop', a=(88, 74), b=(90, 74), landing=dict(rect=(87.5, 68, 90.5, 74), z=5.0), note='one-way drop from the Court\'s south rail onto the Ossuary\'s north bay, 2.5 m')],
)
LADDERS = [
    dict(id='closet-ladder', at=(53.0, 67.5), baseZ=-7.5, height=2.5, yaw=0.0, oneWay=True, note='from the Pit\'s west mouth up into the Pump Room\'s closet',
         purpose='the Pit\'s one-way scout exit; the pack takes the lift'),
    dict(id='smoke-ladder', at=(104.0, 52.5), baseZ=0.0, height=5.0, yaw=0.0, kind='barred', oneWay=False, note='Smokehouse up to the Ossuary\'s east bay; foot barred until the lever above is pulled',
         purpose='the Curing Room\'s way home: once opened from the Ossuary, cured cargo rides straight up to the E landing'),
]
# The shaft is the octagon inside the Great Stair (its centreline octagon inset 2.4 m): an 18 x 18 square cut the stair's
# octant corners away (build deviation, PROGRESS.md P3).
SHAFT = [(70.0, 68.9), (76.27, 66.27), (78.9, 60.0), (76.27, 53.73), (70.0, 51.1), (63.73, 53.73), (61.1, 60.0), (63.73, 66.27)]
LEDGE_RAIL = 0.6  # P6: the ledge and deep-water rails are a 0.6 m parapet (the v5 ruling: the Pit is seen from the rim over it)
HOLES = [
    dict(id='shaft-main', level='main', poly=SHAFT, kind='open', rail=0.6, note='the shaft, +10 to -7.5'),
    dict(id='shaft-upper', level='upper', poly=SHAFT, kind='open', rail=0.6),
    dict(id='smoke-hatch', level='upper', rect=(104, 51.5, 105, 53.0), kind='open', note="the smoke-ladder's opening at the Ossuary's south-east corner (build deviation)"),
    dict(id='band-upper', level='upper', rect=(50, 42, 88, 57), kind='open', note='open air over the Great Stair\'s southern octants'),
]
EXTRA_WALKS = [dict(id='sc2-door', level='deep', pts=[(47.5, 67.5), (50.5, 67.5)], width=2.5, note='closet to the Pump Room, barred from the Pump side'),
               dict(id='vault-passage', level='deep', z=-7.5, pts=[(84.5, 72), (88.5, 72)], width=2.5, note='Pit to the vault door')]


def ring_ramps():
    out = []
    for a, b in zip(RING_ORDER, RING_ORDER[1:]):
        out.append(dict(id=f'stair-{a}-{b}', a=RING[a], b=RING[b], width=5.0, note=f'the Great Stair, {a} {RING[a][2]:+} -> {b} {RING[b][2]:+}'))
    return out


EXTRA_RAMPS = ring_ramps() + [
    dict(id='svc-ossuary-reliquary', a=(100, 52, 5), b=(100, 44, 2.5), width=3.0, note='Service Stair: Ossuary down to the Reliquary (R5 at its head)'),
    dict(id='svc-reliquary-chime', a=(88, 34, 2.5), b=(80, 32, 0), width=3.0, note='Service Stair: Reliquary down to the Chime Hall'),
    dict(id='svc-pump-cistern-a', a=(34, 64, -5), b=(31, 68, -6.25), width=3.0, note='Service Stair: Pump down to the Cistern'),
    dict(id='svc-pump-cistern-b', a=(31, 68, -6.25), b=(28, 70, -7.5), width=3.0),
    dict(id='dive-a', a=(60, 28, 0), b=(44, 26, -5.2), width=2.5, note='the dive from the Chime Hall, under the Cellar'),
    dict(id='dive-b', a=(44, 26, -5.2), b=(42, 36, -7.5), width=2.5),
    dict(id='dive-c', a=(42, 36, -7.5), b=(48, 44, -7.5), width=2.5), dict(id='dive-d', a=(48, 44, -7.5), b=(54, 46, -7.5), width=2.5, note='into the Pit\'s south-west corner (R7 at the Chime end)'),
]
SHORTCUTS = [
    dict(id='SC2', at=(49.25, 67.5), z=-5, yaw=180.0, spanCm=250.0, leverSide=-1, oneWay=True, channel='Mechanism.Channel.Warrens.Shortcut.SC2',
         note='the Pump closet door (closet -> Pump Room), barred from the Pump side; lever in the closet: the scout who climbs the closet ladder out of the Pit opens it'),
    dict(id='LIFT', at=(66, 69.5), yaw=0.0, spanCm=300.0, leverSide=1, oneWay=False, channel='Mechanism.Channel.Warrens.Shortcut.Lift',
         note='the counterweight lift: its cage sits locked at the Pit floor; the lever there (P5) sends it up with the pack, and from then on it runs both ways (not built: the builder has no lift geometry; listed under unbuiltLinks)'),
]
LIGHTS = [
    dict(at=(70, 83, 13.0), kind='hearth'), dict(at=(70, 60, 14.0), kind='shaft'), dict(at=(70, 60, -5.5), kind='cold'),
    dict(at=(94, 84, 12.5), kind='cold'), dict(at=(96, 60, 10.0), kind='dim'), dict(at=(96, 36, 7.6), kind='dim'), dict(at=(70, 35, 6.0), kind='cold'),
    dict(at=(44, 36, 0.1), kind='dim'), dict(at=(42, 60, -2.4), kind='dim'), dict(at=(21, 67, -4.9), kind='dim'), dict(at=(30, 36, 0.1), kind='dim'),
    dict(at=(116, 50, 2.6), kind='dim'), dict(at=(16, 88, -4.9), kind='dim'),
]
PILLARS = [dict(level='deep', rect=(54, 50.5, 57, 53.5)), dict(level='deep', rect=(80, 70, 83, 73)), dict(level='main', rect=(61, 33, 64, 36)), dict(level='main', rect=(74, 38, 77, 41))]  # build deviations: the first and third stood on the lsw-H2 / CH-ch2 walks
LOW_LINKS = [('ci1', 'dg'), ('dg', 'gx'), ('gx', 'lw'), ('ch2', 'lsw'), ('ci2', 'BL'), ('bl1', 'pw3')]
LOW_ROOF = 2.2
LOCKS = [
    dict(id='vault', door=dict(at=(87, 72), yaw=0.0, spanCm=250.0, level='deep'), lock=dict(at=(85, 70.3), yaw=90.0, level='deep'),
         key='Red', keyAt=(81, 69.5, 7.8), channel='Mechanism.Channel.Keys.Red',
         note='the key on the Court\'s shaft balcony (+7.5), seen from the arrival landing above and from every landing below'),
]
PUZZLES = [
    dict(id='P1', kind='Red key door', at=(86, 72, -7.5), needsAt=(81, 69.5, 7.5), needsNote='the key on the Court\'s shaft balcony, 15 m above the Vault door and visible from the landing'),
    dict(id='P2', kind='sump grate (latched bars) on the Pump balcony', at=(56, 63, -5), needsAt=(30, 36, -2.5), needsNote='the Sluice hand-wheel opens the grate: the scout can then drop from the Pump balcony onto the Pit floor', existing='hand-wheel + latched Bars gate'),
    dict(id='P3', kind='Mourner cache gate (latched)', at=(104, 32, 2.5), needsAt=(90, 66, 5), needsNote='the pack plate at the Ossuary\'s north end, one Service Stair above', latch=True),
    dict(id='P4', kind='Bellkeeper dial lock', at=(62, 28, 0), needsAt=(70, 48.5, 0), needsNote='the dial glyphs on the shaft\'s north wall under the arrival landing, read from the south landing across the shaft'),
    dict(id='P5', kind='the lift lever (Pit floor)', at=(66, 72, -7.5), needsAt=(66, 72, -7.5), needsNote='reach the Pit floor the hard way once; the lever sends the cage up, pack included, and the lift runs both ways after'),
    dict(id='P6', kind='SC2 barred closet door (Pump Room)', at=(49.25, 67.5, -5), needsAt=(53.75, 67.5, -7.5), needsNote='climb the closet ladder out of the Pit; the lever is on the closet side'),
    dict(id='P7', kind='Curing Room (support objective)', at=(118, 50, 0), needsAt=(70, 60, -7.5), needsNote='the Curing Room: the hunted part is brined here before it travels (the run\'s second required stop); the vat, the drying racks, a plinth for the pack'),
    dict(id='P8', kind='barred ladder foot (Smokehouse)', at=(108, 56, 0), needsAt=(102.5, 54, 5), needsNote='the lever at the smoke-ladder head on the Ossuary side: the bars are opened from above (builder row for the barred smoke-ladder; its channel tag is not registered)'),
]
NICHES = [
    dict(id='court-pack', rect=(104, 80, 108, 84), z=7.5, family='P', note='pack plinth by the S2 mouth'),
    dict(id='court-forage', rect=(86, 94, 90, 97), z=7.5, family='F', note='mushrooms in the north niche'),
    dict(id='court-omen', rect=(84, 80, 86, 82), z=7.5, family='O', note='eyes in the west wall niche'),
    dict(id='court-threat', rect=(98, 94, 102, 98), z=7.5, family='T', note='sentry alcove north of the hall'),
    dict(id='ossuary-husk', rect=(104, 60, 108, 64), z=5, family='F', note='husk spill in the east niche'),
    dict(id='ossuary-rest', rect=(92, 68, 96, 71), z=5, family='N', note='lantern rest by the pack plate'),
    dict(id='mourner', rect=(104, 28, 110, 32), z=2.5, family='C', note='Mourner cache behind the pack-plate gate (P3)'),
    dict(id='reliquary-omen', rect=(96, 24, 100, 28), z=2.5, family='O', note='lamp bank that gutters out'),
    dict(id='sealed-burial', rect=(109, 24, 114, 30), z=2.5, family='C', note='the Sealed Burial behind crawl-sealed'),
    dict(id='bellkeeper', rect=(56, 26, 60, 32), z=0, family='C', note='Bellkeeper\'s Confession behind the dial lock (P4)'),
    dict(id='chime-threat', rect=(80, 26, 84, 30), z=0, family='T', note='sentry niche in the east wall'),
    dict(id='chime-pack', rect=(80, 40, 84, 44), z=0, family='P', note='pack plinth by the Reliquary stair foot'),
    dict(id='chime-rest', rect=(66, 22, 70, 26), z=0, family='N', note='lantern rest in the south wall'),
    dict(id='cellar-salt', rect=(36, 24, 40, 28), z=-2.5, family='F', note='salt crystals'),
    dict(id='porter', rect=(24, 24, 32, 30), z=-2.5, family='C', note='Porter\'s Wager: the dead-end freight niche off the Sluice'),
    dict(id='cellar-vents', rect=(48, 24, 52, 28), z=-2.5, family='X', note='steam vents in the south niche'),
    dict(id='pump-omen', rect=(30, 56, 34, 59), z=-5, family='O', note='swaying chains in the west niche'),
    dict(id='pump-rest', rect=(34, 68, 38, 71), z=-5, family='N', note='lantern rest by the Cistern stair'),
    dict(id='cistern-forage', rect=(14, 56, 18, 60), z=-7.5, family='F', note='mushroom bed across the basin'),
    dict(id='pit-pack', rect=(54, 75, 58, 79), z=-7.5, family='P', note='pack plinth at the Pit\'s north-west, by the lift'),
    dict(id='pit-rest', rect=(86, 48, 90, 52), z=-7.5, family='N', note='lantern rest in the east wall'),
    dict(id='pit-forage', rect=(54, 41, 58, 45), z=-7.5, family='F', note='deep mushrooms by the dive mouth'),
    dict(id='pit-threat', rect=(86, 60, 90, 64), z=-7.5, family='T', note='something in the east niche'),
    dict(id='smoke-pack', rect=(121, 58, 125, 61), z=0, family='P', note='pack plinth by the vat'), dict(id='smoke-threat', rect=(126, 44, 130, 48), z=0, family='T', note='something behind the racks'),
    dict(id='smoke-rest', rect=(104, 50, 107, 53), z=0, family='N', note='lantern rest at the ladder foot'),
    dict(id='larder-forage', rect=(4, 86, 8, 90), z=-7.5, family='F', note='brined stores: a wade to reach them'), dict(id='larder-cache', rect=(23, 96, 27, 100), z=-7.5, family='C', note='the Larder cache: a sealed cask'),
    dict(id='larder-omen', rect=(10, 79.5, 12, 81.5), z=-7.5, family='O', note='chains over the brine'),
]
WATER = [
    dict(id='cistern-basin', rect=(16, 62, 26, 72), z=-7.5, depth=0.4, note='the Cistern pool'),
    dict(id='drowned-gallery', poly=[(22, 46), (26, 40), (46, 38), (54, 44), (50, 47), (44, 42), (28, 46), (28, 54), (22, 54)], z=-7.5, depth=0.4, note='the Drowned Gallery: knee-deep under the Cellar'),
    dict(id='larder-water', poly=[(10, 84), (18, 82), (24, 88), (22, 94), (12, 94)], z=-7.5, depth=0.4, note='the Brine Larder: knee-deep'),
]
PROPS = [
    dict(kind='station', at=(67, 68.5, 10), size=(1.6, 1.6, 7.5), note='THE HOIST on the north landing\'s shaft rail: seen from every landing below, lit by the shaft light'),
    dict(kind='plinth', at=(64, 84, 10), size=(1.2, 1.2, 0.3), note='pack plinth by the Camp Door'),
    dict(kind='station', at=(66, 73.6, 10), size=(3.0, 3.0, 2.4), note='the lift head: an empty cage frame until the cage is sent up'),
    dict(kind='station', at=(66, 73.6, -7.5), size=(3.0, 3.0, 2.4), note='the lift cage, locked at the Pit floor (P5)'),
    dict(kind='statue', at=(94, 90, 7.5), size=(2.0, 1.2, 4.5), yaw=-90, note='split mourner: the Court landmark'),
    dict(kind='plinth', at=(81, 69.5, 7.5), size=(0.8, 0.8, 0.3), note='the key plinth on the Court\'s shaft balcony (P1)'),
    dict(kind='stack', at=(92, 56, 5), size=(6.0, 1.0, 2.6), note='bone stacks'), dict(kind='stack', at=(103, 58.5, 5), size=(6.0, 1.0, 2.6), yaw=90),
    dict(kind='plinth', at=(90, 66, 5), size=(2.0, 2.0, 0.3), note='the pack plate (P3)'),
    dict(kind='sarcophagus', at=(96, 32, 2.5), size=(3.0, 1.5, 1.2), note='the reliquary tomb'),
    dict(kind='stack', at=(70, 70.5, 6.5), size=(5.0, 0.3, 2.0), note='the dial glyphs on the shaft\'s north wall, under the arrival landing (P4), read from the south landing'),
    dict(kind='chimes', at=(70, 35, 0), size=(6.0, 0.2, 3.5), yaw=0, note='bone chimes across the hall'),
    dict(kind='station', at=(61, 31, 0), size=(1.0, 0.4, 1.4), note='the dial lock (P4), at the Bellkeeper niche\'s door'),
    dict(kind='pillar', at=(44, 64, -5), size=(2.0, 2.0, 3.2), note='the pump: the west\'s audio landmark'),
    dict(kind='pillar', at=(30, 36, -2.5), size=(1.0, 1.0, 1.6), note='the hand-wheel (P2)'),
    dict(kind='stack', at=(40, 32, -2.5), size=(2.0, 2.0, 1.4), note='salt crystals'),
    dict(kind='station', at=(56, 63, -5), size=(2.6, 0.3, 2.5), note='the sump grate (P2) beside the Pump balcony over the Pit, off the deck'),
    dict(kind='root', at=(62, 62, -7.5), size=(1.4, 1.4, 17.0), note='roots down the west wall of the shaft, the full height'),
    dict(kind='root', at=(63, 54, -7.5), size=(1.0, 1.0, 17.0)),
    dict(kind='candles', at=(66, 78, 10), size=(0.9, 0.9, 0.5), note='tallow'), dict(kind='candles', at=(102, 56, 5), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(78, 42, 0), size=(0.9, 0.9, 0.5), note='tallow'), dict(kind='candles', at=(36, 54, -5), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(84, 46, -7.5), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='station', at=(118, 50, 0), size=(2.4, 1.6, 1.4), note='the brine vat (P7): the Curing Room'), dict(kind='stack', at=(114, 44, 0), size=(8.0, 0.6, 2.2), note='drying racks'),
]
ANCHOR_AT = {'R1': (79, 69), 'R2': (76.3, 51.1), 'R3': (61, 51), 'R4': (61, 69), 'R5': (100, 50), 'R6': (58, 41), 'R7': (60, 28)}
LEVER_NODE = {'R1': 'rE', 'R5': 'rq1', 'R6': 'sl0'}
MAX_ACTIVE_CACHES = 2

INSTANCES = [
    dict(id='Shaft', label='LI_Warrens_Shaft', asset='LI_Warrens_Shaft', z=0, rect=(52, 42, 88, 78),
         ports=[dict(id='N', at=(70, 74, 10), width=5, kind='door'), dict(id='NE', at=(80, 70, 7.5), width=3, kind='door'), dict(id='E', at=(84, 60, 5), width=3, kind='door'),
                dict(id='SE', at=(80, 50, 2.5), width=3, kind='door'), dict(id='S', at=(70, 46, 0), width=3, kind='door'), dict(id='SW', at=(60, 50, -2.5), width=3, kind='door'),
                dict(id='W', at=(56, 60, -5), width=3, kind='door'), dict(id='pit', at=(62, 70, -7.5), width=5, kind='stair'), dict(id='lift', at=(66, 71, 10), width=3, kind='lift')],
         note='the shaft, the Great Stair (seven octants), the hoist, the lift, the shaft lights. Persistent-level candidate: everything else plugs into a landing.'),
    dict(id='Arrival', label='LI_Warrens_Arrival', asset='LI_Warrens_Arrival', z=10, rect=(60, 74, 80, 100),
         ports=[dict(id='shaft', at=(70, 74, 10), width=5, kind='door'), dict(id='camp', at=(70, 98, 10), width=3, kind='door')], note='the Arrival Hall and the camp lift landing (K)'),
    dict(id='Court', label='LI_Warrens_Court', asset='LI_Warrens_Court', z=7.5, rect=(80, 72, 110, 100),
         ports=[dict(id='shaft', at=(80, 72, 7.5), width=3, kind='door'), dict(id='ossuary', at=(100, 72, 7.5), width=3, kind='stair'), dict(id='S2', at=(104, 94, 7.5), width=3, kind='door'), dict(id='drop', at=(89, 74, 7.5), width=2, kind='drop')]),
    dict(id='Ossuary', label='LI_Warrens_Ossuary', asset='LI_Warrens_Ossuary', z=5, rect=(84, 48, 110, 72),
         ports=[dict(id='shaft', at=(84, 60, 5), width=3, kind='door'), dict(id='court', at=(100, 72, 5), width=3, kind='stair'), dict(id='reliquary', at=(100, 48, 5), width=3, kind='stair')]),
    dict(id='Reliquary', label='LI_Warrens_Reliquary', asset='LI_Warrens_Reliquary', z=2.5, rect=(80, 22, 116, 48),
         ports=[dict(id='shaft', at=(80, 50, 2.5), width=3, kind='door'), dict(id='ossuary', at=(100, 48, 2.5), width=3, kind='stair'), dict(id='chime', at=(84, 32, 2.5), width=3, kind='stair'), dict(id='S3', at=(112, 36, 2.5), width=3, kind='door'), dict(id='smoke', at=(106, 42, 2.5), width=3, kind='stair')]),
    dict(id='Smokehouse', label='LI_Warrens_Smokehouse', asset='LI_Warrens_Smokehouse', z=0, rect=(104, 38, 132, 62),
         ports=[dict(id='reliquary', at=(106, 42, 2.5), width=3, kind='stair'), dict(id='ossuary', at=(108, 56, 0), width=1, kind='ladder')], note='the Curing Room wing (P7); its barred ladder goes up to the Ossuary'),
    dict(id='Larder', label='LI_Warrens_Larder', asset='LI_Warrens_Larder', z=-7.5, rect=(2, 76, 40, 102),
         ports=[dict(id='cistern', at=(20, 76, -7.5), width=2.5, kind='crawl'), dict(id='pump', at=(36, 72, -5), width=2.5, kind='stair')], note='the far low bead; the Brine Stair closes the loop to the Pump'),
    dict(id='Chime', label='LI_Warrens_Chime', asset='LI_Warrens_Chime', z=0, rect=(54, 20, 86, 46),
         ports=[dict(id='shaft', at=(70, 46, 0), width=3, kind='door'), dict(id='reliquary', at=(84, 32, 0), width=3, kind='stair'), dict(id='cellar', at=(56, 42, 0), width=3, kind='stair'), dict(id='dive', at=(58, 27, 0), width=2.5, kind='stair')]),
    dict(id='Cellar', label='LI_Warrens_Cellar', asset='LI_Warrens_Cellar', z=-2.5, rect=(20, 20, 56, 48),
         ports=[dict(id='shaft', at=(56, 48, -2.5), width=3, kind='door'), dict(id='chime', at=(54, 42, -2.5), width=3, kind='stair'), dict(id='pump', at=(42, 48, -2.5), width=3, kind='stair'), dict(id='S4', at=(30, 36, -2.5), width=3, kind='door')]),
    dict(id='Pump', label='LI_Warrens_Pump', asset='LI_Warrens_Pump', z=-5, rect=(28, 48, 56, 72),
         ports=[dict(id='shaft', at=(56, 60, -5), width=3, kind='door'), dict(id='cellar', at=(42, 48, -5), width=3, kind='stair'), dict(id='cistern', at=(30, 68, -5), width=3, kind='stair'), dict(id='closet', at=(53, 67.5, -5), width=1, kind='ladder')]),
    dict(id='Pit', label='LI_Warrens_Pit', asset='LI_Warrens_Pit', z=-7.5, rect=(10, 40, 96, 84),
         ports=[dict(id='shaft', at=(62, 70, -7.5), width=5, kind='stair'), dict(id='lift', at=(66, 71, -7.5), width=3, kind='lift'), dict(id='dive', at=(54, 46, -7.5), width=2.5, kind='stair'), dict(id='cistern', at=(28, 70, -7.5), width=3, kind='stair'), dict(id='S5', at=(14, 80, -7.5), width=3, kind='door')],
         note='the Pit floor, the Vault, the Drowned Gallery and the Cistern: one undercroft tile'),
]
VIEWS = [
    dict(id='arrival-down', **{'from': (70, 69.1, 10), 'to': (70, 60, -7.5)}, label='Arrival landing -> down the whole shaft to the Pit glow'),
    dict(id='court-key', **{'from': (70, 72, 10), 'to': (81, 69.5, 7.8)}, label='Arrival landing -> the Red key on the Court balcony'),
    dict(id='court-hoist', **{'from': (80.5, 70, 7.5), 'to': (67, 68.5, 14)}, label='Court landing -> the hoist'),
    dict(id='ossuary-shaft', **{'from': (79.1, 60, 5), 'to': (70, 60, -7.5)}, label='Ossuary landing -> the Pit floor'),
    dict(id='south-glyphs', **{'from': (70, 47, 0), 'to': (70, 70.5, 6.5)}, label='South landing -> the dial glyphs under the arrival landing (P4)'),
    dict(id='cellar-hoist', **{'from': (60.5, 50, -2.5), 'to': (67, 68.5, 14)}, label='Cellar landing -> up to the hoist'),
    dict(id='pump-pit', **{'from': (59, 60, -5), 'to': (70, 60, -7.5)}, label='Pump balcony (behind the sump grate) -> the Pit floor'),
    dict(id='pit-up', **{'from': (70, 60, -7.5), 'to': (67, 68.5, 14)}, label='Pit floor -> 17.5 m up to the hoist and the arrival landing'),
]
TRANSITIONS = [
    dict(id='t-arrival', at=(70, 75, 10), kind='reveal', label='hall -> the landing: the whole shaft opens below'),
    dict(id='t-oct1', at=(75, 70, 8.75), kind='stair', label='Great Stair N->NE, Court landing'),
    dict(id='t-oct2', at=(80.5, 64, 6.25), kind='stair', label='Great Stair NE->E, R1 at its head'),
    dict(id='t-oct3', at=(80.5, 56, 3.75), kind='stair', label='Great Stair E->SE'),
    dict(id='t-oct4', at=(75, 50, 1.25), kind='stair', label='Great Stair SE->S, R2 at its head'),
    dict(id='t-oct5', at=(65, 50, -1.25), kind='stair', label='Great Stair S->SW'),
    dict(id='t-oct6', at=(59.5, 56, -3.75), kind='stair', label='Great Stair SW->W, R3 at its head'),
    dict(id='t-oct7', at=(59.5, 64, -6.25), kind='stair', label='Great Stair W->NW: roofed, the sump, R4; walks out onto the Pit floor'),
    dict(id='t-svc1', at=(100, 72, 6.25), kind='stair', label='Service Stair: Court -> Ossuary'),
    dict(id='t-svc2', at=(100, 48, 3.75), kind='stair', label='Service Stair: Ossuary -> Reliquary (R5)'),
    dict(id='t-svc3', at=(84, 33, 1.25), kind='stair', label='Service Stair: Reliquary -> Chime'),
    dict(id='t-svc4', at=(56, 42, -1.25), kind='stair', label='Service Stair: Chime -> Cellar (R6)'),
    dict(id='t-svc5', at=(42, 48, -3.75), kind='stair', label='Service Stair: Cellar -> Pump'),
    dict(id='t-svc6', at=(31, 68, -6.25), kind='stair', label='Service Stair: Pump -> Cistern'),
    dict(id='t-dive', at=(52, 27, -2.5), kind='stair', label='the dive: Chime -> under the Cellar -> the Pit (R7)'),
    dict(id='t-gallery', at=(36, 42, -6.5), kind='squeeze', label='the Drowned Gallery: knee-deep, climbs a hump under the Pump and drops again'),
    dict(id='t-courtdrop', at=(89, 74, 7.5), kind='drop', label='one-way drop: Court rail -> Ossuary (2.5 m)'),
    dict(id='t-lift', at=(66, 71, 1), kind='lift', label='the counterweight lift: Pit -> arrival, two-way once called'),
    dict(id='t-smokestair', at=(109, 46, 1.2), kind='stair', label='Reliquary -> Smokehouse: winding stair down'),
    dict(id='t-smokeladder', at=(108, 56, 2.5), kind='ladder', label='Smokehouse -> Ossuary: barred ladder, opened from above'),
    dict(id='t-larder', at=(15, 82, -7.5), kind='squeeze', label='Cistern -> Brine Larder: low tunnel'),
    dict(id='t-brinestair', at=(32, 82, -6.2), kind='stair', label='Larder -> Pump: the Brine Stair winds up; the low loop closes'),
]
LANDMARK = dict(id='shaft', label='THE SHAFT (+10 to -7.5)', at=(70, 60, 0),
                faces=[dict(dir='N', label='hoist and the arrival landing at the top; glyphs below it'), dict(dir='E', label='Court and Ossuary balconies'),
                       dict(dir='S', label='Chime landing at 0: the middle'), dict(dir='W', label='roots, the Cellar and Pump landings, the sump')])
NOTES = dict(
    thesis='One deep shaft, eight wings at eight heights on a helix. Your depth is your position: the hoist is always up, the Pit glow '
           'always down, and every wing has a landing that looks into the same void. The Great Stair reads clockwise = down.',
    principles=['Lynch: one landmark with two ends (hoist up, Pit glow down) makes a vertical compass; the Great Stair is the edge you can always follow',
                'Dark Souls stacking you can see: the Ossuary balcony is over the Cellar landing is over the Pump balcony; all three see each other',
                'Firelink: the Pit\'s home run is an elevator earned at the bottom; the drops are the scout\'s one-way shortcuts (Court -> Ossuary)',
                'Loops of two sizes: the Great Stair (inner) and the Service Stair (outer helix) make every wing a ring; no mandatory commute through one landing',
                'Deep Dish: the first-hour route (arrival landing -> Court -> Ossuary) passes no false block; the first gate is R1 on the second octant',
                'Thresholds: every wing is entered off a landing through a doorway that turns away from the shaft, so the room is dark and distinct after the lit void'],
    changes=['The whole map re-laid as a helix; no v7 coordinates survive, but every room, gate, court, puzzle and pocket family returns',
             'Floor heights: +10, +7.5, +5, +2.5, 0, -2.5, -5, -7.5 (v7: +5 to -5)',
             'The lift replaces the closet ladder as the pack\'s home run; the closet ladder becomes a scout exit into the Pump Room',
             'P4 reads across the shaft (south landing -> north wall); P1\'s key sits on the Court balcony seen from the arrival',
             'Nine Level Instance tiles: the shaft is one; each wing plugs into a landing',
             'Grown rooms (Court, Cellar, Pump, Cistern, Pit) are irregular; the Ossuary, Reliquary, Chime and hall stay orthogonal'],
    sizing='15-20 min: hunt court + Curing Room (east, 0) + forage + return; the Smokehouse and the Larder add a bead at each end of the helix',
    risks=['Ramp budget: 14 flights of 8.8 m at 15.8 degrees on the Great Stair alone; the kit\'s stair target is 26.6 degrees, so treads not ramps',
           'A helix is a strong compass but a weak surprise: once learned, the map has no "where does this go" except the Service Stair and the dive',
           'Fall risk and pack handling on 5 m wide open ramps over a 17.5 m void: rails everywhere; the viewer cannot test this',
           'The Chime dive and the Drowned Gallery pass under other wings: two stacked-geometry seams for the builder'],
)

if __name__ == '__main__':
    import sys
    common.write(sys.modules[__name__])
