"""Warrens greybox, built from data/warrens.json (authored by design_warrens_v6.py, which layers the r02 expansion on v5).

    python Tools/LevelDesign/anchor_plans/build_warrens.py      -> manifest(): plain Python, writes the manifest, prints a summary
    (Unreal Python, on the open /Game/Mars/Maps/Warrens_Mars_MAP)
    import build_warrens; build_warrens.apply()                  -> places the greybox, anchors, packs, puzzles, lights, game mode; saves
    build_warrens.audit()                                        -> floor traces, start capsules, crawl fit, Jolt bake

Three levels (main, deep, upper) are rasterized at CELL metres the way viewer/viewer.js rasterize() does: every cell carries
its own floor height, so a room, pocket or basin may sit at any z (-2.5 / -1.5 / +2.5 are main-grid cells; below -2.5 is the
deep, above +2.5 the upper). Stamp order: walk links, then rooms / pockets / water / foyer pads (a room stamped later wins, so
a link ending inside a room never cuts a causeway), then in-level stair treads (lerped heights), dive ramps, extra ramps,
crawls, extra walks, cracks, holes, upper platforms and walkways, pillars. Each class is greedy-merged into boxes per (floor
height, slab bottom): a floor slab reaches down to its lowest walkable neighbour so a step or a sunken room shows a ledge face;
a solid cell's box reaches down to the lowest floor beside it. In-level stairs are tilted ramp boxes between their end nodes
over stepped filler; dive ramps start 2 m past their upper node (open above rampRoofZ, roofed below). Crawls keep a floor under
a 1.3 m lintel at their own height; water is a floor sunk by its depth under a collision-free plane; holes carry their own rail
height. A UE location is ((x - 70), (y - 55), z) * 100. Never creates, loads or saves another level. Rebuilding destroys only
actors tagged OWN.
"""
import json
import hashlib
import math
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DATA = Path(os.environ.get('WARRENS_DATA', HERE / 'data' / 'warrens.json'))  # WARRENS_DATA previews another layout
OUT = ROOT / 'Saved' / 'AnchorPlans'
MAP = '/Game/Mars/Maps/Warrens_Mars_MAP'
OWN = 'Mars.Anchor.Authoring.Warrens'
ANCHOR_TAG_ROOT = 'Anchor.Mars.Warrens'  # an anchor id in the data is the leaf of its tag (emit_plan.py emits the same tags)
SHORTCUT_TAG_ROOT = 'Shortcut.Mars.Warrens'
POCKET_CLASSES = {  # the flavour-anchor placeable per pocket family letter (Mars_Anchor_Presets.as)
    'F': 'Mars_Anchor_Forage_EntityScript', 'C': 'Mars_Anchor_Cache_EntityScript', 'O': 'Mars_Anchor_Omen_EntityScript',
    'T': 'Mars_Anchor_Threat_EntityScript', 'X': 'Mars_Anchor_Trap_EntityScript', 'N': 'Mars_Anchor_Rest_EntityScript',
    'P': 'Mars_Anchor_Pack_EntityScript',
}
PUZZLE_CHANNEL_ROOT = 'Mechanism.Channel.Warrens.Puzzle'  # registered by hand in Config/DefaultGameplayTags.ini
CUBE = '/Engine/BasicShapes/Cube'
CYLINDER = '/Engine/BasicShapes/Cylinder'
PROTO = '/Game/Mars/Materials/ProtoGrid/ProtoGrid_'
MATERIALS = {  # box kind -> default material; optional v7 presentation groups split a kind
    'floor': PROTO + 'Floor_Mars_MI',
    'wall': PROTO + 'Wall_Mars_MI',
    'roof': PROTO + 'Wall_Mars_MI',
    'ramp': PROTO + 'Platform_Mars_MI',
    'gallery': PROTO + 'Platform_Mars_MI',
    'hearth': PROTO + 'Interactable_Mars_MI',
    'grate': PROTO + 'Wall_Mars_MI',
    'water': PROTO + 'Platform_Mars_MI',  # dressing: no translucent ProtoGrid instance exists, so a thin collision-free sheet
    'prop': PROTO + 'Platform_Mars_MI',
    'root': PROTO + 'Item_Mars_MI',
    'candle': PROTO + 'Interactable_Mars_MI',  # the brightest instance stands in for emissive tallow
    'inlay': PROTO + 'Item_Mars_MI',  # a floor groove drawn as a thin collision-free strip
    'pier': PROTO + 'Wall_Mars_MI',  # the service spiral's central pier
    'dressing': PROTO + 'Platform_Mars_MI',  # opt-in non-colliding authored silhouette pieces
}
MESHES = {'root': CYLINDER, 'candle': CYLINDER, 'pier': CYLINDER}
COLLISION = {'water': 'NoCollision', 'inlay': 'NoCollision', 'dressing': 'NoCollision'}
STRICT_TAGS = True  # False: an unregistered gameplay tag is logged and left unset instead of stopping apply() (an editor booted before the ini edit)
CELL = 0.5
SLAB = 0.4
WALL_TOP = 4.0
DEEP_Z = -5.0
RAMP_START = 2.0
FOYER = 8.0
CRAWL_WIDTH = 1.5
CRAWL_HEIGHT = 1.3  # the sandbox crouch tunnel: 150 standing is blocked, 105 crouched fits
GALLERY_RAIL = 1.0
HOLE_RAIL = 1.0  # a main-floor hole without its own rail height
RAIL_MOUTH = 0.6  # a dive ramp's cut is railed along its sides from this far past its start line
GRATE_PITCH = 0.25  # bar spacing: a capsule (39 cm radius) walks across, nothing falls through
TREAD_DROP = 0.2  # stepped filler under an in-level ramp sits this far under the lerped surface (never pokes through a 0.4 slab)
CAGE_DEPTH = 1.5  # a barred ladder foot: two wall stubs from the wall to the gate posts, the gate across their ends
CAGE_HALF = 1.25
LIGHT_KINDS = {  # intensity, radius m, colour
    'hearth': (5200, 13.0, (1.0, 0.52, 0.22, 1.0)),
    'foyer': (900, 7.0, (1.0, 0.6, 0.3, 1.0)),
    'dim': (700, 6.5, (1.0, 0.62, 0.32, 1.0)),
    'cold': (1600, 16.0, (0.55, 0.7, 1.0, 1.0)),
    'shaft': (5200, 20.0, (0.7, 0.85, 1.0, 1.0)),
    'task': (500, 4.5, (1.0, 0.7, 0.45, 1.0)),  # a small warm work light (the kitchen crank, the Grotto crown)
    'sky': (2400, 18.0, (0.62, 0.72, 0.8, 1.0)),  # cold light down a roof break
}
# The ambient floor: the post-process ambient cubemap's intensity and tint (the renderer is SSGI, not Lumen, so it reaches
# every enclosed room unoccluded). Calibrated in game, not in editor scene captures (which render far darker): 0.12 is pitch
# black, 0.5 leaves only wall silhouettes, 1.0 shows a whole room, 2.0 needs no lantern at all; the maintainer found 0.6
# and 0.4 still too bright in play (in-game sweep: Saved/AnchorPlans/lighting-r1/ingame_sweep.png, 2026-10-20).
AMBIENT_FILL = (0.2, (0.35, 0.45, 0.85))
# District fills: one unshadowed, room-sized point light per room the data's `fills` names, tinted from the concept board.
# FILL_SCALE multiplies every fill (the calibration knob); kind -> (intensity, colour).
FILL_SCALE = 1.0
FILL_KINDS = {
    'amber': (150, (1.0, 0.62, 0.32)), 'funeral': (150, (0.5, 0.6, 0.95)), 'indigo': (150, (0.45, 0.45, 0.95)),
    'ivory': (150, (1.0, 0.9, 0.75)), 'candle': (110, (1.0, 0.7, 0.45)), 'teal': (150, (0.4, 0.85, 0.8)),
    'copper': (150, (1.0, 0.55, 0.3)), 'navy': (150, (0.35, 0.45, 0.9)), 'limestone': (150, (0.6, 0.8, 0.75)),
    'chalk': (130, (0.9, 0.88, 0.8)),
}
WALKABLE = ('floor', 'low', 'crawl', 'grate', 'tread')
BLOCKING = ('solid', 'crack', 'outside')
DEVIATIONS = [
    'dive stairs are straight ramps starting 2 m past the upper node; in-level stairs are straight ramps between their end nodes',
    'crawl gaps are optional geometry outside the plan graph (the solve never relies on them)',
    'the Deep is roofed by the main floor; with an upper level the main floor is roofed too, except its tall rooms',
    'a main-floor hole is open through the upper level too (the viewer caps it above the galleries)',
    'the lair runs on under the well rim (no shaft walls below the rim; the viewer draws them)',
    'water is a sunk floor under a collision-free sheet; nothing slows or drains',
    'the glyph clue is a plain box; the seal order lives only in the sequence node',
]
V6_DEVIATIONS = [  # the explicit 3D layer (data with structures)
    'terrain patches are stepped at 0.1 m per 0.5 m cell, not sloped triangles',
    'a spiral tread is three radial band boxes on its outer chord (they overlap inward), not an annular sector',
    'a kitchen wall blocks the leak search on grid cell edges; its exact 0.25 m box is collision only',
]


def load():
    return json.loads(DATA.read_text(encoding='utf-8'))


def anchor_tag(aid):
    return dict(tag=ANCHOR_TAG_ROOT + '.' + aid)


def shortcut_tag(sid):
    return dict(tag=SHORTCUT_TAG_ROOT + '.' + sid)


def puzzle_channel(leaf):
    return dict(tag=PUZZLE_CHANNEL_ROOT + '.' + leaf)


def seg_param(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    l2 = dx * dx + dy * dy
    return 0.0 if l2 == 0 else ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2


def seg_dist(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    l2 = dx * dx + dy * dy
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2))
    return math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy))


def polyline(d, link):
    n = d['nodes']
    return [tuple(n[link['a']][:2])] + [tuple(p) for p in link['via']] + [tuple(n[link['b']][:2])]


def triangle_height(p, a, b, c):
    """The height at p of triangle abc (each (x, y, z)), or None when p is outside it."""
    den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    if abs(den) < 1e-9:
        return None
    u = ((b[1] - c[1]) * (p[0] - c[0]) + (c[0] - b[0]) * (p[1] - c[1])) / den
    v = ((c[1] - a[1]) * (p[0] - c[0]) + (a[0] - c[0]) * (p[1] - c[1])) / den
    if u < -1e-6 or v < -1e-6 or u + v > 1 + 1e-6:
        return None
    return u * a[2] + v * b[2] + (1 - u - v) * c[2]


def point_in_poly(p, poly):
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > p[1]) != (yj > p[1]) and p[0] < (xj - xi) * (p[1] - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def shape_contains(shape, p):
    if 'poly' in shape:
        return point_in_poly(p, shape['poly'])
    x0, y0, x1, y1 = shape['rect']
    return x0 <= p[0] <= x1 and y0 <= p[1] <= y1


def shape_bounds(shape):
    if 'rect' in shape:
        return tuple(shape['rect'])
    xs, ys = [p[0] for p in shape['poly']], [p[1] for p in shape['poly']]
    return (min(xs), min(ys), max(xs), max(ys))


def shape_centre(shape):
    b = shape_bounds(shape)
    return ((b[0] + b[2]) / 2, (b[1] + b[3]) / 2)


def level_of_z(z, U):
    """The grid a floor height lives on: half-levels (-2.5, -1.5, +2.5) are main-grid cells with their own height."""
    return 'deep' if z < -2.5 else ('upper' if U and z > 2.5 else 'main')


class Grid:
    def __init__(self, rect, fill, z):
        self.x0, self.y0, x1, y1 = rect
        self.nx, self.ny = int(round((x1 - self.x0) / CELL)), int(round((y1 - self.y0) / CELL))
        self.z = z
        self.c = [[fill] * self.nx for _ in range(self.ny)]
        self.zf = [[float(z)] * self.nx for _ in range(self.ny)]
        self.top = [[0.0] * self.nx for _ in range(self.ny)]
        self.caps = {}  # (i, j) -> (deck top, air top): an over-crossing above this cell (stamp_over)

    def centre(self, i, j):
        return (self.x0 + (i + 0.5) * CELL, self.y0 + (j + 0.5) * CELL)

    def inside(self, i, j):
        return 0 <= i < self.nx and 0 <= j < self.ny

    def get(self, i, j):
        return self.c[j][i] if self.inside(i, j) else 'outside'

    def z_at(self, i, j):
        return self.zf[j][i] if self.inside(i, j) else self.z

    def cell_of(self, p):
        return int(math.floor((p[0] - self.x0) / CELL)), int(math.floor((p[1] - self.y0) / CELL))

    def at(self, p):
        return self.get(*self.cell_of(p))

    def z_of(self, p):
        return self.z_at(*self.cell_of(p))

    def set(self, i, j, value, z=None):
        self.c[j][i] = value
        if z is not None:
            self.zf[j][i] = float(z)

    def stamp_segment(self, a, b, half, value, only=None, square=False, zfn=None):
        """Cells within half of segment ab; square ends drop the round caps (a ramp's mouth must not bite a neighbour).
        zfn(t) gives the floor height at parameter t along ab; None keeps each cell's height."""
        xa, xb = min(a[0], b[0]) - half, max(a[0], b[0]) + half
        ya, yb = min(a[1], b[1]) - half, max(a[1], b[1]) + half
        for j in range(max(0, int(math.floor((ya - self.y0) / CELL))), min(self.ny, int(math.floor((yb - self.y0) / CELL)) + 1)):
            for i in range(max(0, int(math.floor((xa - self.x0) / CELL))), min(self.nx, int(math.floor((xb - self.x0) / CELL)) + 1)):
                p = self.centre(i, j)
                t = seg_param(p, a, b)
                if square and not 0.0 <= t <= 1.0:
                    continue
                if seg_dist(p, a, b) <= half and (only is None or self.c[j][i] in only):
                    self.set(i, j, value, None if zfn is None else zfn(max(0.0, min(1.0, t))))

    def stamp_shape(self, shape, value, only=None, z=None):
        b = shape_bounds(shape)
        for j in range(max(0, int(math.floor((b[1] - self.y0) / CELL))), min(self.ny, int(math.floor((b[3] - self.y0) / CELL)) + 1)):
            for i in range(max(0, int(math.floor((b[0] - self.x0) / CELL))), min(self.nx, int(math.floor((b[2] - self.x0) / CELL)) + 1)):
                if shape_contains(shape, self.centre(i, j)) and (only is None or self.c[j][i] in only):
                    self.set(i, j, value, z)

    def stamp_rect(self, rect, value, z=None):
        self.stamp_shape(dict(rect=rect), value, None, z)

    def groups(self, key_fn):
        """Greedy merge of cells sharing key_fn(i, j) (None = skip) into axis-aligned rectangles (metres), per key."""
        keys = [[key_fn(i, j) for i in range(self.nx)] for j in range(self.ny)]
        used = [[False] * self.nx for _ in range(self.ny)]
        out = {}
        for j in range(self.ny):
            for i in range(self.nx):
                k = keys[j][i]
                if used[j][i] or k is None:
                    continue
                w = 1
                while i + w < self.nx and not used[j][i + w] and keys[j][i + w] == k:
                    w += 1
                h = 1
                while j + h < self.ny and all(not used[j + h][i + q] and keys[j + h][i + q] == k for q in range(w)):
                    h += 1
                for jj in range(j, j + h):
                    for ii in range(i, i + w):
                        used[jj][ii] = True
                out.setdefault(k, []).append((self.x0 + i * CELL, self.y0 + j * CELL, self.x0 + (i + w) * CELL, self.y0 + (j + h) * CELL))
        return out

    def rects(self, value):
        return self.groups(lambda i, j: True if self.c[j][i] == value else None).get(True, [])

    def walkable_neighbour_floor(self, i, j):
        """The lowest floor height among this cell's walkable 4-neighbours and itself (a slab or a wall reaches down to it)."""
        z = self.zf[j][i] if self.c[j][i] in WALKABLE else self.z
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if self.get(i + di, j + dj) in WALKABLE:
                z = min(z, self.zf[j + dj][i + di])
        return z


def box(kind, centre, size, yaw=0.0, pitch=0.0):
    return dict(kind=kind, centre=[round(v, 4) for v in centre], size=[round(v, 4) for v in size],
                yaw=round(yaw, 4), pitch=round(pitch, 4))


def slabs(out, kind, rects, z_bottom, z_top):
    if z_top - z_bottom <= 0.001:
        return
    for x0, y0, x1, y1 in rects:
        out.append(box(kind, ((x0 + x1) / 2, (y0 + y1) / 2, (z_bottom + z_top) / 2), (x1 - x0, y1 - y0, z_top - z_bottom)))


def key_rects(grid, pred):
    """{(bottom, top): rects} for cells where pred(i, j) returns (bottom, top) or None."""
    return grid.groups(lambda i, j: (lambda r: None if r is None else (round(r[0], 3), round(r[1], 3)))(pred(i, j)))


def same_level(a, b, U):
    return level_of_z(a[2], U) == level_of_z(b[2], U)


def ramps_of(d):
    """Dive ramps: stair links whose ends are on different grids. Open above rampRoofZ, roofed below."""
    U = d.get('upper')
    nodes, out = d['nodes'], []
    for link in d['links']:
        if link['kind'] != 'stair':
            continue
        a, b = nodes[link['a']], nodes[link['b']]
        if same_level(a, b, U):
            continue
        upper, lower = (a, b) if a[2] > b[2] else (b, a)
        dx, dy = lower[0] - upper[0], lower[1] - upper[1]
        run = math.hypot(dx, dy)
        ux, uy = dx / run, dy / run
        override = next((r for r in d.get('rampOverrides', []) if r['link'] == [link['a'], link['b']]), {})
        start = tuple(override.get('start', (upper[0] + ux * RAMP_START, upper[1] + uy * RAMP_START)))
        assert seg_dist(start, upper[:2], lower[:2]) < .001, 'dive start must stay on its existing link'
        descent_end = tuple(override.get('descentEnd', lower[:2]))
        assert seg_dist(descent_end, start, lower[:2]) < .001, 'dive descent must stay on its existing link'
        slope_run = math.dist(start, descent_end)
        assert slope_run > 1.0, 'dive descent is too short'
        roof = override.get('roofZ', d.get('rampRoofZ'))
        frac = 1.0 if roof is None else min(1.0, (upper[2] - roof) / (upper[2] - lower[2]) + 0.5 / (run - RAMP_START))
        open_end = (start[0] + (lower[0] - start[0]) * frac, start[1] + (lower[1] - start[1]) * frac)
        out.append(dict(link=link, upper=(upper[0], upper[1]), start=start, open_end=open_end, end=(lower[0], lower[1]), descent_end=descent_end, top=upper[2],
                        bottom=lower[2], width=link['width'], yaw=math.degrees(math.atan2(dy, dx)),
                        degrees=math.degrees(math.atan2(upper[2] - lower[2], slope_run)),
                        upper_level=level_of_z(upper[2], U), lower_level=level_of_z(lower[2], U)))
    return out


def treads_of(d):
    """In-level stairs (both ends on one grid) and extra ramps: one tilted box per segment, heights lerped by run length."""
    U = d.get('upper')
    nodes, out = d['nodes'], []
    for link in d['links']:
        if link['kind'] != 'stair':
            continue
        a, b = nodes[link['a']], nodes[link['b']]
        if not same_level(a, b, U):
            continue
        pts = polyline(d, link)
        total = sum(math.dist(p, q) for p, q in zip(pts, pts[1:]))
        done, segs = 0.0, []
        for p, q in zip(pts, pts[1:]):
            seg = math.dist(p, q)
            z0 = a[2] + (b[2] - a[2]) * done / total
            z1 = a[2] + (b[2] - a[2]) * (done + seg) / total
            segs.append(((p[0], p[1], z0), (q[0], q[1], z1)))
            done += seg
        out.append(dict(id=link['a'] + '-' + link['b'], segments=segs, width=link['width'], level=level_of_z(a[2], U),
                        other_level=None, closedBy=link['closedBy'], degrees=math.degrees(math.atan2(abs(a[2] - b[2]), total))))
    for r in d.get('extraRamps', []):
        hi, lo = (r['a'], r['b']) if r['a'][2] > r['b'][2] else (r['b'], r['a'])
        run = math.dist(hi[:2], lo[:2])
        out.append(dict(id=r['id'], segments=[(tuple(hi), tuple(lo))], width=r['width'], level=level_of_z(lo[2], U),
                        other_level=level_of_z(hi[2], U) if level_of_z(hi[2], U) != level_of_z(lo[2], U) else None, closedBy=None,
                        degrees=math.degrees(math.atan2(hi[2] - lo[2], run))))
    return out


def tread_z(tread, pt):
    """Floor height of a tread at a point (projected onto its nearest segment)."""
    best, bz = None, None
    for p, q in tread['segments']:
        dd = seg_dist(pt, p, q)
        if best is None or dd < best:
            t = max(0.0, min(1.0, seg_param(pt, p, q)))
            best, bz = dd, p[2] + (q[2] - p[2]) * t
    return bz


def barred_ladders(d):
    """A ladder with kind 'barred': a gate CAGE_DEPTH in front of its foot, with a wall stub either side back to the wall."""
    out = []
    for l in d.get('ladders', []):
        if l.get('kind') != 'barred':
            continue
        x, y = l['at']
        a = math.radians(l['yaw'])
        fx, fy, sx, sy = math.cos(a), math.sin(a), -math.sin(a), math.cos(a)
        stubs = []
        for side in (-1, 1):
            p = (x + sx * side * CAGE_HALF, y + sy * side * CAGE_HALF)
            stubs.append((p, (p[0] + fx * CAGE_DEPTH, p[1] + fy * CAGE_DEPTH)))
        out.append(dict(ladder=l, gate_at=(x + fx * (CAGE_DEPTH - 0.25), y + fy * (CAGE_DEPTH - 0.25)), yaw=l['yaw'], stubs=stubs,
                        z=l['baseZ']))
    return out


GATE_OPENING = 2.0  # Mars_Gate's fixed opening (k_OpeningWidth); the rest of a wider mouth is walled


def gated_mouths(d):
    """Puzzle gates on a mouth wider than the gate: the mouth row is walled except the gate's opening. P2 sits where the
    Drowned Gallery crosses the lair's wall; P3 and P4 sit on their niche's edge nearest the puzzle position."""
    U = d.get('upper')
    out = []
    for pz in d.get('puzzles', []):
        kind = pz['kind']
        if kind.startswith('sluice grate'):
            walk = next(w for w in d.get('extraWalks', []) if w['id'] == 'drowned-gallery')
            water = next(w for w in d.get('water', []) if w['id'] == 'drowned-gallery')
            p, q = walk['pts'][-2], walk['pts'][-1]
            room = next(r for r in d['rooms'] if 'rect' in r and shape_contains(r, q) and level_of_z(r['z'], U) == 'deep')
            x0, y0, x1, y1 = room['rect']
            wx0, wy0, wx1, wy1 = water['rect']
            if p[1] < y0 <= q[1]:  # crossing the room's south edge from below
                cx = p[0] + (q[0] - p[0]) * (y0 - p[1]) / (q[1] - p[1])
                out.append(dict(id=pz['id'], wall=(wx0, y0 - CELL, wx1, y0), at=(cx, y0 - CELL / 2), yaw=90.0, axis='x', z=room['z'], level='deep'))
            else:
                raise AssertionError('the Drowned Gallery must enter the lair across its south edge')
        elif kind.startswith('Mourner cache gate') or kind.startswith('Bellkeeper'):
            key = 'Mourner' if kind.startswith('Mourner') else 'Bellkeeper'
            niche = next(n for n in d.get('niches', []) if key in n.get('note', ''))
            x0, y0, x1, y1 = niche['rect']
            ax, ay, az = pz['at']
            edges = [(abs(ay - y0), (x0, y0, x1, y0 + CELL), ((x0 + x1) / 2, y0 + CELL / 2), 90.0, 'x'),
                     (abs(ay - y1), (x0, y1 - CELL, x1, y1), ((x0 + x1) / 2, y1 - CELL / 2), 90.0, 'x'),
                     (abs(ax - x0), (x0, y0, x0 + CELL, y1), (x0 + CELL / 2, (y0 + y1) / 2), 0.0, 'y'),
                     (abs(ax - x1), (x1 - CELL, y0, x1, y1), (x1 - CELL / 2, (y0 + y1) / 2), 0.0, 'y')]
            _, wall, at, yaw, axis = min(edges, key=lambda e: e[0])
            out.append(dict(id=pz['id'], wall=wall, at=at, yaw=yaw, axis=axis, z=niche.get('z', 0), level=level_of_z(niche.get('z', 0), U)))
    return out


def crawl_pts(c):
    """A crawl's centreline: a, its optional bends, b."""
    return [tuple(c['a'])] + [tuple(p) for p in c.get('via', [])] + [tuple(c['b'])]


# --- The explicit 3D layer (v6): structures, their opening cuts, the spiral's treads ------------------------------------
# Structures use the proposal's convention: at is the box's bottom centre, size is full XYZ, yaw in degrees.

def in_box2d(p, s, pad=0.0):
    """p (x, y) inside structure s's footprint, grown by pad."""
    a = -math.radians(s.get('yaw', 0.0))
    dx, dy = p[0] - s['at'][0], p[1] - s['at'][1]
    x, y = dx * math.cos(a) - dy * math.sin(a), dx * math.sin(a) + dy * math.cos(a)
    return abs(x) <= s['size'][0] / 2 + pad and abs(y) <= s['size'][1] / 2 + pad


def structure_pieces(s, openings):
    """s minus the openings that name it (axis-aligned subtraction, as the review's geometry.js does): a list of
    (lo, hi) corner pairs. A rotated structure may not be cut."""
    lo = [s['at'][0] - s['size'][0] / 2, s['at'][1] - s['size'][1] / 2, s['at'][2]]
    hi = [lo[0] + s['size'][0], lo[1] + s['size'][1], lo[2] + s['size'][2]]
    boxes = [(lo, hi)]
    for o in openings:
        if s['id'] not in o.get('sourceIds', []):
            continue
        assert not s.get('yaw'), 'a rotated structure cannot take an opening cut: ' + s['id']
        if o['kind'] == 'wall':
            a, w, t = o['at'], o['width'] / 2, o.get('throughDepth', 0.5) / 2
            cut = ([a[0] - t, a[1] - w, a[2], a[0] + t, a[1] + w, a[2] + o['height']] if o['axis'] == 'x'
                   else [a[0] - w, a[1] - t, a[2], a[0] + w, a[1] + t, a[2] + o['height']])
        else:
            r, z, t = o['rect'], o.get('z', 0.0), o.get('throughDepth', 0.5)
            cut = [r[0], r[1], z - t, r[2], r[3], z + t]
        out = []
        for b0, b1 in boxes:
            c0 = [max(b0[k], cut[k]) for k in range(3)]
            c1 = [min(b1[k], cut[k + 3]) for k in range(3)]
            if any(c0[k] >= c1[k] for k in range(3)):
                out.append((b0, b1))
                continue
            for p0, p1 in (((b0[0], b0[1], b0[2]), (c0[0], b1[1], b1[2])), ((c1[0], b0[1], b0[2]), (b1[0], b1[1], b1[2])),
                           ((c0[0], b0[1], b0[2]), (c1[0], c0[1], b1[2])), ((c0[0], c1[1], b0[2]), (c1[0], b1[1], b1[2])),
                           ((c0[0], c0[1], b0[2]), (c1[0], c1[1], c0[2])), ((c0[0], c0[1], c1[2]), (c1[0], c1[1], b1[2]))):
                if all(p1[k] - p0[k] > 1e-6 for k in range(3)):
                    out.append((list(p0), list(p1)))
        boxes = out
    return boxes


def tread_span(c, tread):
    """(inner radius, outer radius, start angle, end angle) of an annular tread polygon [inner0, outer0, outer1, inner1]."""
    cx, cy = c['core']['at'][:2]
    p0, p1, p3 = tread['poly'][0], tread['poly'][1], tread['poly'][3]
    a0 = math.atan2(p0[1] - cy, p0[0] - cx)
    a1 = math.atan2(p3[1] - cy, p3[0] - cx)
    while a1 < a0:
        a1 += 2 * math.pi
    return math.dist(p0, (cx, cy)), math.dist(p1, (cx, cy)), a0, a1


def tread_top_at(d, p):
    """The top of the connector tread over p, or None."""
    for c in d.get('connectors', []):
        cx, cy = c['core']['at'][:2]
        r = math.dist(p, (cx, cy))
        ang = math.atan2(p[1] - cy, p[0] - cx)
        for t in c['treads']:
            r0, r1, a0, a1 = tread_span(c, t)
            rel = (ang - a0) % (2 * math.pi)
            if r0 - 1e-6 <= r <= r1 + 1e-6 and rel <= a1 - a0 + 1e-6:
                return t['top']
    return None


def deck_over(d, p, z):
    """An authored platform or a connector tread with its top within 0.3 m of z over p."""
    for s in d.get('structures', []):
        if s['kind'] == 'platform' and in_box2d(p, s) and abs(s['at'][2] + s['size'][2] - z) <= 0.3:
            return True
    top = tread_top_at(d, p)
    return top is not None and abs(top - z) <= 0.3


def stamp_over(grid, pts, half, z, value, cap, deck_fn):
    """An over-crossing: square-ended segments plus a disc at each bend. Rock becomes floor at z; a cell already walkable
    well below z keeps its class and height and gets a cap (deck top z, clear air above), so a corridor can pass over a
    tunnel or a room without overwriting it. A tunnel ('low') is capped by the rock between; an open room only where an
    authored deck or tread carries the walk (deck_fn(p, z)), the rest of the room stays open air beside a railed deck.
    Returns the capped cells."""
    capped = set()
    bends = pts[1:-1]
    for j in range(grid.ny):
        for i in range(grid.nx):
            p = grid.centre(i, j)
            near = any(seg_dist(p, a, b) <= half and 0.0 <= seg_param(p, a, b) <= 1.0 for a, b in zip(pts, pts[1:])) \
                or any(math.dist(p, v) <= half for v in bends)
            if not near:
                continue
            c = grid.c[j][i]
            if c == 'solid':
                grid.set(i, j, value, z)
            elif c in WALKABLE and grid.zf[j][i] < z - 1.0 and (c == 'low' or deck_fn(p, z)):
                grid.caps[(i, j)] = (z, z + cap)
                capped.add((i, j))
    return capped


def rasterize(d):
    """Every level as a Grid with per-cell floor heights and ceilings, plus the dive ramps and the in-level treads."""
    U = d.get('upper')
    nodes = d['nodes']
    fp = d['footprint']
    main_top = U['mainTop'] if U else WALL_TOP
    grids = dict(main=Grid(fp, 'solid', 0.0), deep=Grid(d['deep'], 'solid', DEEP_Z), upper=Grid(fp, 'solid', U['z']) if U else None)
    main, deep, upper = grids['main'], grids['deep'], grids['upper']

    def G(z):
        return grids[level_of_z(z, U)]

    if U:
        for r in d['rooms']:
            if r['id'] in U['tallRooms']:
                upper.stamp_shape(r, 'void')
    low = {tuple(sorted(pair)) for pair in d.get('lowLinks', [])}
    # 1. plan walk links
    for link in d['links']:
        za, zb = nodes[link['a']][2], nodes[link['b']][2]
        if link['kind'] != 'walk' or abs(za - zb) > 0.01 or link.get('over'):
            continue
        g = G(za)
        pts = polyline(d, link)
        is_low = tuple(sorted((link['a'], link['b']))) in low
        for p, q in zip(pts, pts[1:]):
            g.stamp_segment(p, q, link['width'] / 2, 'low' if is_low else 'floor', only=('solid', 'low') if is_low else None, zfn=lambda t, z=za: z)
    # 2. rooms, pockets, water, foyer pads
    for r in d['rooms']:
        G(r['z']).stamp_shape(r, 'floor', None, r['z'])
    for n in d.get('niches', []):
        G(n.get('z', 0)).stamp_shape(n, 'floor', None, n.get('z', 0))
    for w in d.get('water', []):
        G(w.get('z', 0)).stamp_shape(w, 'floor', None, w.get('z', 0) - w.get('depth', 0.5))
    for e in d['entrances']:
        sx, sy, sz = nodes[e['node']]
        G(sz).stamp_rect((max(fp[0], sx - FOYER / 2), max(fp[1], sy - FOYER / 2), min(fp[2], sx + FOYER / 2), min(fp[3], sy + FOYER / 2)), 'floor', sz)
    # 3. in-level stair treads and extra ramps: lerped heights, square ends; the other grid of an extra ramp opens above it
    treads = treads_of(d)
    for tr in treads:
        g = grids[tr['level']]
        for p, q in tr['segments']:
            g.stamp_segment(p[:2], q[:2], tr['width'] / 2, 'tread', None, True, zfn=lambda t, p=p, q=q: p[2] + (q[2] - p[2]) * t)
            if tr['other_level'] and grids[tr['other_level']]:
                grids[tr['other_level']].stamp_segment(p[:2], q[:2], tr['width'] / 2, 'void', None, True)
    # 4. dive ramps
    ramps = ramps_of(d)
    for r in ramps:
        gu, gl = grids[r['upper_level']], grids[r['lower_level']]
        gu.stamp_segment(r['upper'], r['start'], r['width'] / 2, 'floor', zfn=lambda t, z=r['top']: z)
        gu.stamp_segment(r['start'], r['open_end'], r['width'] / 2, 'ramp', None, True)
        gl.stamp_segment(r['upper'], r['end'], r['width'] / 2, 'floor', zfn=lambda t, z=r['bottom']: z)
    # 5. crawls at their height, only through rock
    for c in d['crawls']:
        pts = crawl_pts(c)
        for a, b in zip(pts, pts[1:]):
            G(c.get('z', 0)).stamp_segment(a, b, CRAWL_WIDTH / 2, 'crawl', only=('solid',), zfn=lambda t, z=c.get('z', 0): z)
    # 6. extra walks at their grid's base height
    for w in d.get('extraWalks', []):
        g = grids.get(w.get('level', 'main'))
        if not g or w.get('over'):
            continue
        if 'rect' in w:
            g.stamp_rect(w['rect'], 'floor', g.z)
        else:
            for p, q in zip(w['pts'], w['pts'][1:]):
                g.stamp_segment(tuple(p), tuple(q), w['width'] / 2, 'floor', zfn=lambda t, z=g.z: z)
    for c in d.get('cracks', []):
        main.stamp_segment(tuple(c['a']), tuple(c['b']), c['width'] / 2, 'crack', only=('solid',))
    # 7. holes: a grate or an open void on their level; an open main hole is open through the upper level too
    for h in d.get('holes', []):
        g = grids.get(h['level'])
        if g:
            g.stamp_shape(h, 'grate' if h['kind'] == 'grate' else 'void')
        if h['level'] == 'main' and h['kind'] != 'grate' and upper:
            upper.stamp_shape(h, 'void')
    # 8. upper platforms and walkways, then the upper holes
    if U:
        for plat in U['platforms']:
            upper.stamp_shape(plat, 'floor', None, U['z'])
        for w in U['walkways']:
            for p, q in zip(w['pts'], w['pts'][1:]):
                upper.stamp_segment(tuple(p), tuple(q), w['width'] / 2, 'floor', zfn=lambda t, z=U['z']: z)
        for h in d.get('holes', []):
            if h['level'] == 'upper':
                upper.stamp_shape(h, 'void')
    # 9. pillars, and the stubs of a barred ladder foot
    for pl in d.get('pillars', []):
        g = grids.get(pl['level'])
        if g:
            g.stamp_shape(pl, 'solid')
    for cage in barred_ladders(d):
        g = G(cage['z'])
        for a, b in cage['stubs']:
            g.stamp_segment(a, b, CELL / 2 - 0.01, 'solid', None, True)
    for m in gated_mouths(d):  # the mouth row walled, except the gate's opening
        g = grids[m['level']]
        x0, y0, x1, y1 = m['wall']
        cx, cy = m['at']
        for j in range(max(0, int(math.floor((y0 - g.y0) / CELL))), min(g.ny, int(math.floor((y1 - g.y0) / CELL)) + 1)):
            for i in range(max(0, int(math.floor((x0 - g.x0) / CELL))), min(g.nx, int(math.floor((x1 - g.x0) / CELL)) + 1)):
                px, py = g.centre(i, j)
                if not (x0 <= px <= x1 and y0 <= py <= y1):
                    continue
                along = px - cx if m['axis'] == 'x' else py - cy
                if abs(along) > GATE_OPENING / 2:
                    g.set(i, j, 'solid')
    # 10. over-crossings: a link or extra walk flagged over is stamped last, capping the lower floor it passes above
    for link in d['links']:
        if link.get('over'):
            za = nodes[link['a']][2]
            is_low = tuple(sorted((link['a'], link['b']))) in low
            stamp_over(G(za), polyline(d, link), link['width'] / 2, za, 'low' if is_low else 'floor',
                       d.get('lowRoof', 2.2) if is_low else link.get('clearHeight', main_top), lambda p, z: deck_over(d, p, z))
    for w in d.get('extraWalks', []):
        if w.get('over'):
            g = grids[w.get('level', 'main')]
            stamp_over(g, [tuple(p) for p in w['pts']], w['width'] / 2, g.z, 'low' if w.get('low') else 'floor',
                       d.get('lowRoof', 2.2) if w.get('low') else w.get('clearHeight', main_top), lambda p, z: deck_over(d, p, z))
    # 11. terrain patches replace their cells' floor heights with the triangle mesh, quantised to 0.1 m (stepped)
    for patch in d.get('terrain', []):
        vs = patch['vertices']
        g = G(vs[0][2])
        for j in range(g.ny):
            for i in range(g.nx):
                p = g.centre(i, j)
                if g.c[j][i] not in WALKABLE or not point_in_poly(p, patch['poly']):
                    continue
                for tri in patch['triangles']:
                    h = triangle_height(p, *[vs[k] for k in tri])
                    if h is not None:
                        g.zf[j][i] = round(h, 1)
                        break
    # 12. structure walls block the cell edges they cross (minus their traversable openings): the leak search's walls.
    # The grid keeps its floor under them; the walls themselves are boxes (manifest).
    struct_blocked = {'main': set(), 'deep': set(), 'upper': set()}
    for s in d.get('structures', []):
        if s['kind'] != 'wall':
            continue
        assert not s.get('yaw'), 'a rotated wall cannot block grid edges: ' + s['id']
        level = level_of_z(s['at'][2], U)
        g = grids[level]
        x0, y0 = s['at'][0] - s['size'][0] / 2, s['at'][1] - s['size'][1] / 2
        x1, y1 = x0 + s['size'][0], y0 + s['size'][1]
        along_y = s['size'][1] > s['size'][0]
        spans = []
        for o in d.get('openings', []):
            if s['id'] in o.get('sourceIds', []) and o['kind'] == 'wall' and o.get('traversable'):
                c = o['at'][1] if along_y else o['at'][0]
                spans.append((c - o['width'] / 2, c + o['width'] / 2))
        for j in range(g.ny):
            for i in range(g.nx):
                a = g.centre(i, j)
                n = (i + 1, j) if along_y else (i, j + 1)
                b = g.centre(*n)
                crosses = (a[0] <= x1 and b[0] >= x0) if along_y else (a[1] <= y1 and b[1] >= y0)  # the centre-to-centre step meets the wall
                if not crosses:
                    continue
                run, lo, hi = (a[1], y0, y1) if along_y else (a[0], x0, x1)  # where along the wall the step crosses
                if not lo <= run <= hi or any(s0 <= run <= s1 for s0, s1 in spans):
                    continue
                struct_blocked[level].add(frozenset(((i, j), n)))
    # 13. sky: main cells under an upper-level open hole (a roof break) carry no lintel, so the break reaches the roof
    sky = set()
    for h in d.get('holes', []):
        if h['level'] == 'upper' and h['kind'] != 'grate':
            for j in range(main.ny):
                for i in range(main.nx):
                    if shape_contains(h, main.centre(i, j)):
                        sky.add((i, j))

    # Ceilings. Main: the cell's height plus mainTop, a room's own top, the upper roof over a tall room, the low/crawl lintels.
    tall = [r for r in d['rooms'] if U and r['id'] in U['tallRooms']]
    topped = [r for r in d['rooms'] if r.get('top') is not None and level_of_z(r['z'], U) == 'main']
    for j in range(main.ny):
        for i in range(main.nx):
            c, p = main.c[j][i], main.centre(i, j)
            t = main.zf[j][i] + main_top
            for r in topped:
                if shape_contains(r, p):
                    t = r['top']
            for r in tall:
                if shape_contains(r, p):
                    t = U['top']
            if c == 'low':
                t = main.zf[j][i] + d.get('lowRoof', 2.2)
            elif c == 'crawl':
                t = main.zf[j][i] + CRAWL_HEIGHT
            if (i, j) in main.caps:  # an over-crossing above: the ceiling is its clear air
                t = max(t, main.caps[(i, j)][1])
            main.top[j][i] = t
    if upper:
        for j in range(upper.ny):
            for i in range(upper.nx):
                upper.top[j][i] = U['top']
    # Deep: under a main void the main ceiling; under a main floor that floor's slab; else the main slab line.
    for j in range(deep.ny):
        for i in range(deep.nx):
            p = deep.centre(i, j)
            above = main.at(p)
            if above in ('void', 'ramp'):
                mi, mj = main.cell_of(p)
                t = main.top[mj][mi] if main.inside(mi, mj) else main_top
            elif above in WALKABLE:
                t = min(-SLAB, main.z_of(p) - SLAB)
            elif above == 'solid':
                mi, mj = main.cell_of(p)
                t = min(-SLAB, main.walkable_neighbour_floor(mi, mj) - SLAB)
            else:
                t = -SLAB
            deep.top[j][i] = t
    return dict(main=main, deep=deep, upper=upper, ramps=ramps, treads=treads, U=U, main_top=main_top, struct_blocked=struct_blocked, sky=sky)


def cell_at(grid, pt):
    return grid.at(pt)


def rail_edges(grid, heads, gaps, want_class='floor', hole_of=None, open_class='void', skip_fn=None, blocked=None):
    """Edges between a floor cell and an open cell, merged into runs, minus ladder heads and drop gaps. hole_of(mid)
    returns the hole a main-floor edge belongs to (its rail height); None skips edges that belong to no hole. skip_fn(mid)
    drops further edges (a ramp's mouth). blocked, when given, collects the (cell, cell) pairs a rail separates."""
    def skip(mx, my):
        return any(math.hypot(mx - hx, my - hy) < 0.9 for hx, hy in heads) or any(seg_dist((mx, my), a, b) < 0.3 for a, b in gaps) \
            or (skip_fn is not None and skip_fn((mx, my)))

    pieces = {}
    for j in range(grid.ny):
        for i in range(grid.nx):
            if grid.c[j][i] != want_class:
                continue
            x0, y0 = grid.x0 + i * CELL, grid.y0 + j * CELL
            for di, dj, kind, line, start in ((0, -1, 'h', y0, x0), (0, 1, 'h', y0 + CELL, x0), (-1, 0, 'v', x0, y0), (1, 0, 'v', x0 + CELL, y0)):
                if grid.get(i + di, j + dj) != open_class:
                    continue
                mid = (start + CELL / 2, line) if kind == 'h' else (line, start + CELL / 2)
                if skip(*mid):
                    continue
                rail = GALLERY_RAIL
                if hole_of is not None:
                    hole = hole_of((mid[0] + di * 0.25, mid[1] + dj * 0.25))
                    if hole is None:
                        continue
                    rail = hole.get('rail', HOLE_RAIL)
                if blocked is not None:
                    blocked.add(frozenset(((i, j), (i + di, j + dj))))
                pieces.setdefault((kind, round(line, 3), round(grid.zf[j][i], 3), rail), []).append(start)
    out = []
    for (kind, line, z, rail), starts in pieces.items():
        starts.sort()
        run0 = prev = starts[0]
        for st in starts[1:] + [None]:
            if st is not None and abs(st - prev - CELL) < 1e-6:
                prev = st
                continue
            a, b = run0, prev + CELL
            out.append(((a, line, b, line) if kind == 'h' else (line, a, line, b), z, rail))
            if st is not None:
                run0 = prev = st
    return out


def ladder_checks(d, R):
    """Each ladder: floor in front of its foot, open air in front of it at the top level, a landing behind its head."""
    U = d.get('upper')
    errors = []
    for l in d.get('ladders', []):
        x, y = l['at']
        a = math.radians(l['yaw'])
        fx, fy = math.cos(a), math.sin(a)
        base, top = R[level_of_z(l['baseZ'], U)], R[level_of_z(l['baseZ'] + l['height'], U)]
        if base is None or top is None:
            errors.append(l['id'] + ': no level at its foot or head')
            continue
        if cell_at(base, (x + fx * 0.6, y + fy * 0.6)) not in ('floor', 'grate'):
            errors.append(l['id'] + ': no floor in front of the foot')
        elif abs(base.z_of((x + fx * 0.6, y + fy * 0.6)) - l['baseZ']) > 0.05:
            errors.append(l['id'] + ': the floor in front of the foot is not at its base height')
        if cell_at(top, (x + fx * 0.45, y + fy * 0.45)) != 'void':
            errors.append(l['id'] + ': the climb is roofed (no opening in front of the ladder at the top)')
        if cell_at(top, (x - fx * 0.75, y - fy * 0.75)) not in ('floor', 'grate'):
            errors.append(l['id'] + ': no landing behind the head')
        elif abs(top.z_of((x - fx * 0.75, y - fy * 0.75)) - (l['baseZ'] + l['height'])) > 0.05:
            errors.append(l['id'] + ': the landing behind the head is not at its top height')
    return errors


SEAL_RADIUS = 30.0
STEP_UP = 0.6  # the chef's step height: the leak search climbs no more than this between cells
SEAL_WALK = 10.0  # a way round a gate shorter than this is a walk-around; a longer one is a loop through other rooms
GATE_CLASSES = ('Route_EntityScript', 'Spawn_EntityScript', 'Shortcut_EntityScript', 'Mars_Gate_EntityScript')


def gate_leaks(grid, level, entities, crawl_ok=False, budget=None, blocked=frozenset()):
    """A gate seals when, with its span blocked, the cell 1 m in front cannot reach the cell 1 m behind within SEAL_WALK
    metres of walking (and without leaving a SEAL_RADIUS disc). Cracks and holes are walls; a dive ramp's cut counts as
    walkable (a gate at a ramp mouth is passed by stepping onto the ramp). Crawl cells count only with crawl_ok (a crouched
    chef): a crawl beside a gate is a bypass by design, not a leak."""
    from collections import deque
    U = None
    leaks = []
    for e in entities:
        if not (any(e['cls'].endswith(c) for c in GATE_CLASSES) or '_KeyDoor_' in e['cls']):
            continue
        x, y, z = e['at']
        if e.get('level') != level:
            continue
        a = math.radians(e['yaw'])
        fx, fy, px, py = math.cos(a), math.sin(a), -math.sin(a), math.cos(a)
        half = e['props'].get('SpanCm', e.get('spanCm', 0.0)) / 200.0
        g0, g1 = (x - px * half, y - py * half), (x + px * half, y + py * half)

        def open_cell(i, j, z_from):
            c = grid.get(i, j)
            if c in BLOCKING or c == 'void' or (c == 'crawl' and not crawl_ok):
                return False
            if grid.z_at(i, j) - z_from > STEP_UP:  # a ledge is dropped, never climbed
                return False
            p = grid.centre(i, j)
            return math.hypot(p[0] - x, p[1] - y) <= SEAL_RADIUS and seg_dist(p, g0, g1) > 0.35

        start, goal = grid.cell_of((x - fx, y - fy)), grid.cell_of((x + fx, y + fy))
        seen, todo = {start: 0}, deque([start])
        while todo:
            i, j = todo.popleft()
            if (seen[(i, j)] + 1) * CELL > (budget or SEAL_WALK):
                continue
            for n in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
                if n not in seen and frozenset(((i, j), n)) not in blocked and open_cell(n[0], n[1], grid.z_at(i, j)):
                    seen[n] = seen[(i, j)] + 1
                    todo.append(n)
        if goal in seen:
            leaks.append(e['note'])
    return leaks


def walk_breaks(d, R):
    """Walk lines (plan links, extra walks, upper walkways, treads) that cross a hole or a wall in their level's raster."""
    U = d.get('upper')
    nodes, out = d['nodes'], []
    lines = [(w['id'], w['pts'], R[w.get('level', 'main')]) for w in d.get('extraWalks', []) if 'pts' in w]
    if R['upper']:
        lines += [(w['id'], w['pts'], R['upper']) for w in U['walkways']]
    for link in d['links']:
        za, zb = nodes[link['a']][2], nodes[link['b']][2]
        if link['kind'] == 'walk' and za == zb:
            lines.append((link['a'] + '-' + link['b'], polyline(d, link), R[level_of_z(za, U)]))
    for tr in R['treads']:
        lines.append((tr['id'], [p[:2] for p, q in tr['segments']] + [tr['segments'][-1][1][:2]], R[tr['level']]))
    for name, pts, grid in lines:
        if grid is None:
            out.append(name + ' (no grid)')
            continue
        for p, q in zip(pts, pts[1:]):
            seg = math.dist(p, q)
            n = max(1, int(seg / 0.25))
            hits = [(p[0] + (q[0] - p[0]) * k / n, p[1] + (q[1] - p[1]) * k / n) for k in range(n + 1)]
            if any(grid.at(h) not in WALKABLE and grid.at(h) != 'ramp' for h in hits):
                out.append(name)
                break
    return out


def z_on_link(d, link, pt):
    """Floor height at a point of a link: lerped by run length along its polyline (a stair) or the ends' height (a walk)."""
    nodes = d['nodes']
    za, zb = nodes[link['a']][2], nodes[link['b']][2]
    pts = polyline(d, link)
    total = sum(math.dist(p, q) for p, q in zip(pts, pts[1:]))
    done, best = 0.0, None
    for p, q in zip(pts, pts[1:]):
        seg = math.dist(p, q)
        dd = seg_dist(pt, p, q)
        if best is None or dd < best[0]:
            best = (dd, done + max(0.0, min(1.0, seg_param(pt, p, q))) * seg)
        done += seg
    return za + (zb - za) * (best[1] / total if total else 0.0)


def floor_span(grid, at, yaw, width, slack=1.0):
    """Walkable run across a gate line, each side capped at width/2 + slack: (centre, span). A passage no wider than the
    link keeps the authored centre and width; a wider one (a rim, a flared mouth) gets a leaf that reaches both walls, so
    nothing runs round its ends. Past the cap the floor is open room, which no leaf seals: the leak check reports that."""
    a = math.radians(yaw)
    px, py = -math.sin(a), math.cos(a)
    cap = width / 2 + slack
    ext = []
    for sign in (1, -1):
        e = 0.0
        while e < cap:
            c = grid.at((at[0] + px * sign * (e + 0.1), at[1] + py * sign * (e + 0.1)))
            if c not in WALKABLE and c != 'ramp':
                break
            e += 0.1
        ext.append(min(e, cap))
    if ext[0] + ext[1] <= width + 0.1:
        return at, width
    shift = (ext[0] - ext[1]) / 2
    return (at[0] + px * shift, at[1] + py * shift), ext[0] + ext[1]


def prop_boxes(boxes, p):
    """Landmark dressing as basic shapes, kinds mapped as the viewer does."""
    first = len(boxes)
    kind, (sx, sy, sz), z, yaw = p['kind'], p['size'], p['at'][2], p.get('yaw', 0.0)
    x, y = p['at'][0], p['at'][1]
    if kind == 'root':
        boxes.append(box('root', (x, y, z + sz / 2), (sx, sy, sz), yaw))
    elif kind == 'candles':
        boxes.append(box('candle', (x, y, z + sz / 2), (sx, sy, sz), yaw))
    elif kind == 'statue':
        boxes.append(box('prop', (x, y, z + sz * 0.25), (sx, sy, sz * 0.5), yaw))
        boxes.append(box('prop', (x, y, z + sz * 0.75), (sx * 0.6, sy * 0.6, sz * 0.5), yaw + 45.0))
    elif kind == 'chimes':  # strands hang from the bar and stop above head height, so the hall stays walkable
        a = math.radians(yaw)
        hang = max(0.3, sz - 2.1)
        for k in (-1, 0, 1):
            boxes.append(box('prop', (x + math.cos(a) * k * sx / 3, y + math.sin(a) * k * sx / 3, z + sz - hang / 2), (0.15, 0.15, hang), yaw))
        boxes.append(box('prop', (x, y, z + sz), (sx, 0.1, 0.1), yaw))
    elif sz <= 0.25:  # a floor inlay (the dry sluice channel): dressing a chef walks over, no collision
        boxes.append(box('inlay', (x, y, z + sz / 2), (sx, sy, sz), yaw))
    else:
        boxes.append(box('prop', (x, y, z + sz / 2), (sx, sy, sz), yaw))
    if 'id' in p:
        for emitted in boxes[first:]:
            emitted['sourceId'] = p['id']
            if p.get('collision') is False:
                emitted['kind'] = 'dressing'


def is_puzzle_standin(p):
    """A prop the viewer draws for a mechanism the builder places as an entity (the wheel, the grate, the plate, the seals)."""
    note = p.get('note', '')
    return any(key in note for key in ('hand-wheel', 'sluice grate', 'pack plate', 'seal pair')) or p['kind'] == 'kitchen-drive'


def box_corners(value):
    """Plan-space corners with the same pitch/yaw convention as emitted UE transforms."""
    yaw, pitch = math.radians(value['yaw']), math.radians(value['pitch'])
    for i in (-0.5, 0.5):
        for j in (-0.5, 0.5):
            for k in (-0.5, 0.5):
                x, y, z = (value['size'][n] * v for n, v in enumerate((i, j, k)))
                px, pz = x * math.cos(pitch) - z * math.sin(pitch), x * math.sin(pitch) + z * math.cos(pitch)
                yield (value['centre'][0] + px * math.cos(yaw) - y * math.sin(yaw),
                       value['centre'][1] + px * math.sin(yaw) + y * math.cos(yaw), value['centre'][2] + pz)


def apply_presentation(man, presentation):
    """Emission-only overrides; crossing merged pieces keep their existing neutral defaults."""
    materials = {m['path'] for m in presentation['materials']}
    regions = presentation.get('regions', [])
    overrides = presentation.get('sourceOverrides', [])
    assert len({r['id'] for r in regions}) == len(regions), 'duplicate presentation region'
    assert len({o['sourceId'] for o in overrides}) == len(overrides), 'duplicate presentation source override'
    sources = {b.get('sourceId') for b in man['boxes']}
    assert all(o['sourceId'] in sources for o in overrides), 'unknown presentation sourceId'
    for region in regions:
        bounds = region['bounds']
        assert len(bounds) == 6 and all(math.isfinite(v) for v in bounds), region['id']
        assert all(bounds[k] < bounds[k + 3] for k in range(3)), region['id']
        assert all(kind in MATERIALS for kind in region['kinds']), region['id']
        assert region['material'] in materials, region['material']
    for index, a in enumerate(regions):
        for b in regions[index + 1:]:
            assert not all(min(a['bounds'][k + 3], b['bounds'][k + 3]) > max(a['bounds'][k], b['bounds'][k])
                           for k in range(3)), 'overlapping presentation regions: ' + a['id'] + '/' + b['id']
    default_materials = presentation.get('defaultMaterials', {})
    assert all(kind in MATERIALS and path in materials for kind, path in default_materials.items()), 'unknown presentation default material'
    by_source = {o['sourceId']: o for o in overrides}
    accent = presentation.get('traversalAccent', {})
    assert not accent or (accent['material'] in materials and
                          all(kind in MATERIALS for kind in accent.get('kinds', []))), 'unknown traversal accent'
    for value in man['boxes']:
        if value['kind'] in default_materials:
            value.setdefault('material', default_materials[value['kind']])
        points = tuple(box_corners(value))
        matches = [r for r in regions if value['kind'] in r['kinds'] and
                   all(all(r['bounds'][k] - 1e-7 <= p[k] <= r['bounds'][k + 3] + 1e-7 for k in range(3)) for p in points)]
        assert len(matches) <= 1, 'ambiguous presentation box'
        if matches:
            value['material'] = matches[0]['material']
        override = by_source.get(value.get('sourceId'))
        if override:
            assert override['material'] in materials, override['material']
            value['material'] = override['material']
        if value['kind'] in accent.get('kinds', []):
            value['material'] = accent['material']
    dressing = presentation.get('dressing', [])
    assert len({v['id'] for v in dressing}) == len(dressing), 'duplicate presentation dressing'
    for value in dressing:
        assert value['collision'] == 'NoCollision', 'presentation dressing must be NoCollision: ' + value['id']
        assert len(value['at']) == len(value['scale']) == 3 and all(math.isfinite(v) for v in value['at'] + value['scale']), value['id']
        assert all(v > 0 for v in value['scale']) and math.isfinite(value.get('yaw', 0)), value['id']
        assert value.get('material', next(iter(materials))) in materials, value['id']
    man['dressing'] = dressing
    light_overrides = presentation.get('lightOverrides', [])
    task_lights = presentation.get('taskLights', [])
    assert len({v['id'] for v in light_overrides + task_lights}) == len(light_overrides + task_lights), 'duplicate presentation light id'
    for value in light_overrides:
        matches = [v for v in man['lights'] if v['kind'] == value['kind'] and v['at'] == value['matchAt']]
        assert len(matches) == 1, 'presentation light override must match exactly once: ' + value['id']
        assert math.isfinite(value['scale']) and value['scale'] > 0, value['id']
        matches[0]['scale'] = value['scale']
    for value in task_lights:
        assert len(value['at']) == 3 and all(math.isfinite(v) for v in value['at']), value['id']
        if value.get('fill'):
            assert all(math.isfinite(value[k]) and value[k] > 0 for k in ('intensity', 'radius')), value['id']
            assert len(value['colour']) == 4 and all(math.isfinite(v) for v in value['colour']), value['id']
        else:
            assert value['kind'] in LIGHT_KINDS and math.isfinite(value['scale']) and value['scale'] > 0, value['id']
    man['lights'].extend(task_lights)


def render_groups(boxes):
    """Kind retains its mesh; full effective paths/profile identify deterministic HISM groups."""
    groups = {}
    for kind in MATERIALS:
        for value in boxes:
            if value['kind'] == kind:
                key = (kind, value.get('material', MATERIALS[kind]), value.get('collision', COLLISION.get(kind, 'BlockAll')))
                groups.setdefault(key, []).append(value)
    assert sum(map(len, groups.values())) == len(boxes), 'unknown box kind'
    return groups


def manifest(write=True, data=None):
    """Build from live data, or explicitly supplied data for a write-free authoring preview."""
    d = load() if data is None else data
    U = d.get('upper')
    nodes, links = d['nodes'], d['links']
    boxes, starts, entities, lights, pockets = [], [], [], [], []
    fx0, fy0, fx1, fy1 = d['footprint']
    R = rasterize(d)
    main, deep, upper, ramps, treads, main_top = R['main'], R['deep'], R['upper'], R['ramps'], R['treads'], R['main_top']
    assert not d.get('galleries'), 'legacy galleries are not built any more'

    # --- Main level boxes ---------------------------------------------------------------------------------------------
    def main_floor(i, j):
        c = main.c[j][i]
        if c not in ('floor', 'low', 'crawl', 'grate'):
            return None
        return (main.walkable_neighbour_floor(i, j) - SLAB, main.zf[j][i])

    def main_tread(i, j):
        if main.c[j][i] != 'tread':
            return None
        return (main.walkable_neighbour_floor(i, j) - SLAB, main.zf[j][i] - TREAD_DROP)

    def main_solid(i, j):
        if main.c[j][i] != 'solid':
            return None
        return (min(0.0, main.walkable_neighbour_floor(i, j)) - SLAB, main_top)

    def lintel(cls, height):
        def f(i, j):
            if main.c[j][i] != cls or (i, j) in R['sky']:
                return None
            if (i, j) in main.caps:  # capped_lintel() builds it
                return None
            return (main.zf[j][i] + height, main.zf[j][i] + main_top)
        return f

    def capped_lintel(height):
        def f(i, j):  # a tunnel under an over-crossing: rock from its roof up to the crossing's floor, nothing above
            cap = main.caps.get((i, j))
            if main.c[j][i] != 'low' or cap is None or cap[0] <= main.zf[j][i] + height + 0.001:
                return None
            return (main.zf[j][i] + height, cap[0])
        return f

    for (b, t), rects in key_rects(main, main_floor).items():
        slabs(boxes, 'floor', rects, b, t)
    for (b, t), rects in key_rects(main, main_tread).items():
        slabs(boxes, 'floor', rects, b, t)
    for (b, t), rects in key_rects(main, main_solid).items():
        slabs(boxes, 'wall', rects, b, t)
    for (b, t), rects in key_rects(main, lintel('low', d.get('lowRoof', main_top))).items():
        slabs(boxes, 'wall', rects, b, t)
    for (b, t), rects in key_rects(main, capped_lintel(d.get('lowRoof', main_top))).items():
        slabs(boxes, 'floor', rects, b, t)  # the rock over a capped tunnel is the over-crossing's floor
    for (b, t), rects in key_rects(main, lintel('crawl', CRAWL_HEIGHT)).items():
        slabs(boxes, 'wall', rects, b, t)
    for c in d.get('cracks', [])[:1]:  # all cracks share one sill and head
        crack_rects = main.rects('crack')
        slabs(boxes, 'wall', crack_rects, -SLAB, c['sill'])
        slabs(boxes, 'wall', crack_rects, c['head'], main_top)
    for h in d.get('holes', []):
        if h['kind'] == 'grate':
            x0, y0, x1, y1 = h['rect']
            hz = {'main': 0.0, 'deep': DEEP_Z, 'upper': U['z'] if U else 0.0}[h['level']]
            n = int((x1 - x0) / GRATE_PITCH)
            for k in range(n + 1):
                x = x0 + k * (x1 - x0) / n
                boxes.append(box('grate', (x, (y0 + y1) / 2, hz - 0.05), (0.06, y1 - y0, 0.1)))
            for y in (y0, y1):
                boxes.append(box('grate', ((x0 + x1) / 2, y, hz - 0.05), (x1 - x0, 0.06, 0.1)))

    # Rails round a main-floor hole (per-hole height), minus ladder heads that arrive at the main level.
    main_holes = [h for h in d.get('holes', []) if h['level'] == 'main' and h['kind'] != 'grate']

    def hole_of(pt):
        return next((h for h in main_holes if shape_contains(h, pt)), None)

    main_heads = [tuple(l['at']) for l in d.get('ladders', []) if level_of_z(l['baseZ'] + l['height'], U) == 'main']
    rails = []
    rail_blocked = {'main': set(), 'deep': set(), 'upper': set()}

    def ramp_mouth(mid):  # an edge across a dive ramp's mouth (within RAIL_MOUTH of the cut's start line) carries no rail
        for r in ramps:
            a = math.radians(r['yaw'])
            along = (mid[0] - r['start'][0]) * math.cos(a) + (mid[1] - r['start'][1]) * math.sin(a)
            if abs(along) < RAIL_MOUTH and seg_dist(mid, r['start'], r['end']) <= r['width'] / 2 + 0.3:
                return True
        return False

    for grid_name, grid in (('main', main), ('deep', deep)):
        crossing_ids = {o['bridgeId'] for o in d.get('rampOverrides', []) if 'bridgeId' in o and
                        any(o['link'] == [r['link']['a'], r['link']['b']] and r['upper_level'] == grid_name for r in ramps)}
        crossing_decks = [s for s in d.get('structures', []) if s['id'] in crossing_ids]
        def crossing_or_mouth(mid):
            return ramp_mouth(mid) or any(in_box2d(mid, s, .05) for s in crossing_decks)
        pieces = rail_edges(grid, main_heads if grid_name == 'main' else [], [], 'floor', hole_of if grid_name == 'main' else None, blocked=rail_blocked[grid_name])
        pieces += rail_edges(grid, [], [], 'floor', None, open_class='ramp', skip_fn=crossing_or_mouth, blocked=rail_blocked[grid_name])
        for (x0, y0, x1, y1), z, rail in pieces:
            rails.append((x0, y0, x1, y1))
            if x0 == x1:
                slabs(boxes, 'gallery', [(x0 - 0.05, y0, x0 + 0.05, y1)], z, z + rail)
            else:
                slabs(boxes, 'gallery', [(x0, y0 - 0.05, x1, y0 + 0.05)], z, z + rail)

    # --- Upper level boxes --------------------------------------------------------------------------------------------
    if upper:
        def upper_solid(i, j):
            if upper.c[j][i] != 'solid':
                return None
            p = upper.centre(i, j)
            mi, mj = main.cell_of(p)
            bottom = main_top
            if main.inside(mi, mj) and main.c[mj][mi] in WALKABLE:
                bottom = main.top[mj][mi]
            if bottom >= U['top'] - 0.01:
                return None
            return (bottom, U['top'])

        for (b, t), rects in key_rects(upper, upper_solid).items():
            slabs(boxes, 'wall', rects, b, t)
        slabs(boxes, 'gallery', upper.rects('floor'), U['z'] - SLAB, U['z'])
        slabs(boxes, 'roof', upper.groups(lambda i, j: True if upper.c[j][i] != 'solid' else None).get(True, []), U['top'], U['top'] + 0.3)
        heads = [tuple(l['at']) for l in d.get('ladders', []) if abs(l['baseZ'] + l['height'] - U['z']) < 0.01]
        gaps = [(tuple(g['a']), tuple(g['b'])) for g in U.get('railGaps', [])]
        for (x0, y0, x1, y1), z, rail in rail_edges(upper, heads, gaps):
            rails.append((x0, y0, x1, y1))
            if x0 == x1:
                slabs(boxes, 'gallery', [(x0 - 0.05, y0, x0 + 0.05, y1)], U['z'], U['z'] + GALLERY_RAIL)
            else:
                slabs(boxes, 'gallery', [(x0, y0 - 0.05, x1, y0 + 0.05)], U['z'], U['z'] + GALLERY_RAIL)

    # --- Deep boxes ---------------------------------------------------------------------------------------------------
    def deep_floor(i, j):
        if deep.c[j][i] not in ('floor', 'grate', 'low'):
            return None
        return (deep.walkable_neighbour_floor(i, j) - SLAB, deep.zf[j][i])

    def deep_solid(i, j):
        if deep.c[j][i] != 'solid':
            return None
        return (min(DEEP_Z, deep.walkable_neighbour_floor(i, j)) - SLAB, deep.top[j][i])

    for (b, t), rects in key_rects(deep, deep_floor).items():
        slabs(boxes, 'floor', rects, b, t)
    for (b, t), rects in key_rects(deep, deep_solid).items():
        slabs(boxes, 'wall', rects, b, t)
    for (b, t), rects in key_rects(deep, lambda i, j: (deep.zf[j][i] + d.get('lowRoof', 2.2), -SLAB) if deep.c[j][i] == 'low' else None).items():
        slabs(boxes, 'wall', rects, b, t)  # a low tunnel's lintel in the Deep
    # A rim so a foyer pad on the footprint edge never opens onto nothing.
    rim_top = U['top'] if U else WALL_TOP
    for rim in [(fx0 - 0.5, fy0 - 0.5, fx1 + 0.5, fy0), (fx0 - 0.5, fy1, fx1 + 0.5, fy1 + 0.5),
                (fx0 - 0.5, fy0, fx0, fy1), (fx1, fy0, fx1 + 0.5, fy1)]:
        slabs(boxes, 'wall', [rim], DEEP_Z - SLAB, rim_top)
    # Ramps: dives and in-level stairs.
    for r in ramps:
        length = math.dist(r['start'], r['descent_end'])
        drop = r['top'] - r['bottom']
        mid = ((r['start'][0] + r['descent_end'][0]) / 2, (r['start'][1] + r['descent_end'][1]) / 2, (r['top'] + r['bottom']) / 2 - SLAB / 2)
        boxes.append(box('ramp', mid, (math.hypot(length, drop), r['width'], SLAB), r['yaw'], -r['degrees']))
    for tr in treads:
        for p, q in tr['segments']:
            run = math.dist(p[:2], q[:2])
            rise = q[2] - p[2]
            mid = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, (p[2] + q[2]) / 2 - SLAB / 2)
            boxes.append(box('ramp', mid, (math.hypot(run, rise), tr['width'], SLAB), math.degrees(math.atan2(q[1] - p[1], q[0] - p[0])),
                             math.degrees(math.atan2(rise, run))))
    # Water sheets.
    for w in d.get('water', []):
        x0, y0, x1, y1 = shape_bounds(w)
        boxes.append(box('water', ((x0 + x1) / 2, (y0 + y1) / 2, w.get('z', 0) - 0.1), (x1 - x0, y1 - y0, 0.02)))
    # Props.
    for p in d.get('props', []):
        if not is_puzzle_standin(p):
            prop_boxes(boxes, p)
    # The explicit 3D layer: structures minus their opening cuts (a shutter is a Gate entity, not a box), rails on deck
    # edges that drop to open air, the spiral's treads, rails and pier.
    struct_kind = {'wall': 'wall', 'roof': 'wall', 'platform': 'gallery', 'beam': 'prop'}
    openings = d.get('openings', [])
    for s in d.get('structures', []):
        if s['kind'] == 'door':
            continue
        first = len(boxes)
        kind = 'dressing' if s.get('collision') is False else struct_kind[s['kind']]
        if s.get('yaw'):
            assert not any(s['id'] in o.get('sourceIds', []) for o in openings), 'a rotated structure cannot take an opening cut: ' + s['id']
            boxes.append(box(kind, (s['at'][0], s['at'][1], s['at'][2] + s['size'][2] / 2), s['size'], s['yaw']))
        else:
            for lo, hi in structure_pieces(s, openings):
                boxes.append(box(kind, [(lo[k] + hi[k]) / 2 for k in range(3)], [hi[k] - lo[k] for k in range(3)]))
        if d.get('twoPlayer'):
            for emitted in boxes[first:]:
                emitted['sourceId'] = s['id']
                if 'areaId' in s:
                    emitted['areaId'] = s['areaId']

    def open_air(p, top):
        """Beside a deck edge: walkable floor at least 1 m down, with no deck, tread or over-crossing near the deck's height."""
        if main.at(p) not in WALKABLE or main.z_of(p) > top - 1.0:
            return False
        mi, mj = main.cell_of(p)
        if main.top[mj][mi] < top + 1.0:  # roofed below the deck (a tunnel's lintel): rock, not a drop
            return False
        cap = main.caps.get(main.cell_of(p))
        return not (cap is not None and abs(cap[0] - top) <= 0.3) and not deck_over(d, p, top)

    deck_rails = 0
    for s in d.get('structures', []):
        if s['kind'] != 'platform' or s.get('rails') is False:
            continue
        top = s['at'][2] + s['size'][2]
        a = math.radians(s.get('yaw', 0.0))
        u, v = (math.cos(a), math.sin(a)), (-math.sin(a), math.cos(a))
        hx, hy = s['size'][0] / 2, s['size'][1] / 2
        for n, t, h_n, h_t in ((u, v, hx, hy), ((-u[0], -u[1]), v, hx, hy), (v, u, hy, hx), ((-v[0], -v[1]), u, hy, hx)):
            steps = max(1, int(round(2 * h_t / 0.25)))
            flags = []
            for k in range(steps):
                along = -h_t + (k + 0.5) * 2 * h_t / steps
                edge = (s['at'][0] + n[0] * h_n + t[0] * along, s['at'][1] + n[1] * h_n + t[1] * along)
                flags.append((along, open_air((edge[0] + n[0] * 0.25, edge[1] + n[1] * 0.25), top)))
            runs, start = [], None
            for k, (along, air) in enumerate(flags + [(None, False)]):
                if air and start is None:
                    start = k
                elif not air and start is not None:
                    runs.append((flags[start][0] - h_t / steps, flags[k - 1][0] + h_t / steps))
                    start = None
            for r0, r1 in runs:
                mid = (r0 + r1) / 2
                c = (s['at'][0] + n[0] * h_n + t[0] * mid, s['at'][1] + n[1] * h_n + t[1] * mid)
                boxes.append(box('gallery', (c[0], c[1], top + GALLERY_RAIL / 2), (r1 - r0, 0.1, GALLERY_RAIL), math.degrees(math.atan2(t[1], t[0]))))
                deck_rails += 1
    for c in d.get('connectors', []):
        cx, cy, cz = c['core']['at']
        r_core, h_core = c['core']['radius'], c['core']['height']
        boxes.append(box('pier', (cx, cy, cz + h_core / 2), (2 * r_core, 2 * r_core, h_core)))
        rails_spec = c['rails']
        for t in c['treads']:  # three radial bands per annular tread; each band takes its outer chord, so bands overlap inward
            r0, r1, a0, a1 = tread_span(c, t)
            am, da = (a0 + a1) / 2, a1 - a0
            for k in range(3):
                ri, ro = r0 + (r1 - r0) * k / 3, r0 + (r1 - r0) * (k + 1) / 3
                rc = (ri + ro) / 2
                boxes.append(box('floor', (cx + rc * math.cos(am), cy + rc * math.sin(am), t['top'] - t['thickness'] / 2),
                                 (ro - ri, 2 * ro * math.sin(da / 2), t['thickness']), math.degrees(am)))
                accent = d.get('presentation', {}).get('traversalAccent', {})
                if c['id'] in accent.get('connectors', []):
                    boxes[-1]['material'] = accent['material']
            for r in (rails_spec['innerRadius'], rails_spec['outerRadius']):
                boxes.append(box('gallery', (cx + r * math.cos(am), cy + r * math.sin(am), t['top'] + rails_spec['height'] / 2),
                                 (rails_spec['thickness'], 2 * r * math.sin(da / 2), rails_spec['height']), math.degrees(am)))

    # Recesses default to rock. An explicit floorTopZ selects only that floor
    # elevation; the Cistern underside recess preserves its upper walking face.
    for cut in d.get('clearanceCuts', []):
        pieces = []
        for index, emitted in enumerate(boxes):
            selected_kind = 'floor' if 'floorTopZ' in cut else 'wall'
            if emitted['kind'] != selected_kind or emitted['yaw'] or emitted['pitch']:
                pieces.append(emitted)
                continue
            centre, size = emitted['centre'], emitted['size']
            if 'floorTopZ' in cut and abs(centre[2]+size[2]/2-cut['floorTopZ']) > .005:
                pieces.append(emitted)
                continue
            source = dict(id='raster', at=[centre[0], centre[1], centre[2] - size[2] / 2], size=size)
            opening = dict(kind='floor', rect=cut['rect'], z=(cut['zMin'] + cut['zMax']) / 2,
                           throughDepth=(cut['zMax'] - cut['zMin']) / 2, sourceIds=['raster'])
            bounds = structure_pieces(source, [opening])
            if len(bounds) == 1 and all(abs(bounds[0][0][k] - (centre[k] - size[k] / 2)) < 1e-6 for k in range(3)) \
                    and all(abs(bounds[0][1][k] - (centre[k] + size[k] / 2)) < 1e-6 for k in range(3)):
                pieces.append(emitted)
                continue
            for lo, hi in bounds:
                piece = box(selected_kind, [(lo[k] + hi[k]) / 2 for k in range(3)], [hi[k] - lo[k] for k in range(3)])
                piece['sourceId'] = 'cut:' + cut['id'] + ':' + str(index)
                pieces.append(piece)
        boxes = pieces

    # --- Entities -------------------------------------------------------------------------------------------------------
    def entity(cls, at, yaw, props, note, pitch=0.0, **extra):
        e = dict(cls=cls, at=[round(v, 4) for v in at], yaw=round(yaw, 3), pitch=round(pitch, 3), props=props, note=note,
                 level=level_of_z(at[2], U))
        e.update(extra)
        entities.append(e)
        return e

    for l in d.get('ladders', []):
        entity('Mars_Ladder_EntityScript', [l['at'][0], l['at'][1], l['baseZ']], l['yaw'],
               dict(Ladder=dict(fields=dict(Height=l['height'] * 100.0))), l['id'])
    puzzle_by_id = {p['id']: p for p in d.get('puzzles', [])}
    for cage in barred_ladders(d):  # P5: a latched Bars gate across the foot, opened by a lever elsewhere
        l = cage['ladder']
        pz = next((p for p in d.get('puzzles', []) if p.get('kind', '').startswith('barred ladder')), None)
        assert pz, 'a barred ladder needs its puzzle row (the lever position)'
        entity('Mars_Gate_EntityScript', [cage['gate_at'][0], cage['gate_at'][1], cage['z']], cage['yaw'],
               dict(Leaf=dict(enum='EMars_Gate_Leaf', value='Bars'), Sink=dict(fields=dict(InputChannels=dict(array=[puzzle_channel(pz['id'])]), Latch=True))),
               pz['id'] + ' barred foot of ' + l['id'], spanCm=200.0)
        nx, ny, nz = pz['needsAt']
        entity('Mars_Lever_EntityScript', [nx, ny, nz], 0.0, dict(Source=dict(fields=dict(OutputChannel=puzzle_channel(pz['id'])))), pz['id'] + ' lever')
    for lk in d.get('locks', []):  # P1
        colour = lk['key']
        dz = DEEP_Z if lk['door']['level'] == 'deep' else 0.0
        entity('Mars_Sandbox_KeyDoor_' + colour + '_EntityScript', [*lk['door']['at'], dz], lk['door']['yaw'], {}, lk['id'] + ' door',
               spanCm=lk['door']['spanCm'])
        lz = DEEP_Z if lk['lock']['level'] == 'deep' else 0.0
        entity('Mars_Sandbox_KeyLock_' + colour + '_EntityScript', [*lk['lock']['at'], lz], lk['lock']['yaw'], {}, lk['id'] + ' lock')
        entity('Mars_WorldItem_Key_' + colour + '_EntityScript', list(lk['keyAt']), 0.0, {}, lk['id'] + ' key')
    for sc in d.get('shortcuts', []):  # P6
        entity('Mars_Shortcut_EntityScript', [sc['at'][0], sc['at'][1], 0.0], sc['yaw'],
               dict(ShortcutId=shortcut_tag(sc['id']), Channel=dict(tag=sc['channel']), SpanCm=sc['spanCm'],
                    LeverSide=dict(enum='EMars_Shortcut_LeverSide', value='Ahead' if sc['leverSide'] > 0 else 'Behind')), sc['id'])
    mouths_by_id = {m['id']: m for m in gated_mouths(d)}

    def latched_bars(pz):
        return dict(Leaf=dict(enum='EMars_Gate_Leaf', value='Bars'), Sink=dict(fields=dict(InputChannels=dict(array=[puzzle_channel(pz['id'])]), Latch=True)))

    def wall_mount(grid, at, up):
        """The nearest blocking cell along the four axes from a point: (mount position just off that wall, yaw with +X into the room)."""
        best = None
        for dx, dy, yaw in ((1, 0, 180.0), (-1, 0, 0.0), (0, 1, -90.0), (0, -1, 90.0)):
            e = 0.0
            while e < 20.0 and grid.at((at[0] + dx * (e + 0.1), at[1] + dy * (e + 0.1))) in WALKABLE:
                e += 0.1
            if best is None or e < best[0]:
                best = (e, (at[0] + dx * e, at[1] + dy * e, up), yaw)
        return best[1], best[2]

    for pz in d.get('puzzles', []):
        kind = pz['kind']
        if kind.startswith('sluice grate'):  # P2: a hand-wheel elsewhere opens a latched Bars gate across the gallery's mouth
            m = mouths_by_id[pz['id']]
            entity('Mars_Gate_EntityScript', [m['at'][0], m['at'][1], m['z']], m['yaw'], latched_bars(pz), pz['id'] + ' sluice grate', spanCm=GATE_OPENING * 100.0)
            wx, wy, wz = pz['needsAt']
            (mx, my, mz), yaw = wall_mount(R[level_of_z(wz, U)], (wx, wy), R[level_of_z(wz, U)].z_of((wx, wy)) + 1.1)
            entity('Mars_HandWheel_EntityScript', [mx, my, mz], yaw, dict(Source=dict(fields=dict(OutputChannel=puzzle_channel(pz['id'])))),
                   pz['id'] + ' hand-wheel')
        elif kind.startswith('Mourner cache gate'):  # P3: the pack (or a chef) on a plate elsewhere latches the cache gate open
            m = mouths_by_id[pz['id']]
            entity('Mars_Gate_EntityScript', [m['at'][0], m['at'][1], m['z']], m['yaw'], latched_bars(pz), pz['id'] + ' cache gate', spanCm=GATE_OPENING * 100.0)
            px, py, pzz = pz['needsAt']
            entity('Mars_PressurePlate_EntityScript', [px, py, pzz], 0.0,
                   dict(Trigger=dict(fields=dict(DetectionFilter=dict(tags=['Probe.Mars.Player', 'Probe.Mars.Backpack']))),
                        Occupancy=dict(fields=dict(RequiredCount=1, ReleaseDelaySeconds=0.5)),
                        Source=dict(fields=dict(OutputChannel=puzzle_channel(pz['id'])))), pz['id'] + ' pack plate')
        elif kind.startswith('Bellkeeper') and 'bellkeeper' in d:
            encounter = d['bellkeeper']
            phrase, start_glyphs = encounter['phrase'], encounter['startGlyphs']
            glyphs = ('Square', 'Circle', 'Triangle', 'Diamond', 'Cross', 'Bars')
            assert len(phrase) == len(start_glyphs) == 3
            assert all(g in glyphs for g in phrase + start_glyphs)
            assert all(a != b for a, b in zip(phrase, start_glyphs)), 'a dial starts on its answer'
            panel, vent, clue, chain = (encounter[k] for k in ('panel', 'vent', 'clue', 'chain'))
            offset = lambda at: [round((at[i] - panel['at'][i]) * 100.0, 4) for i in range(3)]
            glyph_array = lambda values: dict(array=[dict(enum='EMars_Bellkeeper_Glyph', value=g) for g in values])
            m = mouths_by_id[pz['id']]
            entity('Mars_Gate_EntityScript', [m['at'][0], m['at'][1], m['z']], m['yaw'], latched_bars(pz),
                   'P4 dial gate', spanCm=GATE_OPENING * 100.0)
            rewards = [dict(struct='Mars_Bellkeeper_Reward', fields=dict(
                Definition=dict(asset='/Script/AngelscriptAssets.' + reward['definition']),
                Transform=dict(transform=dict(location=offset(reward['at']))))) for reward in encounter['rewards']]
            entity('Mars_Bellkeeper_EntityScript', panel['at'], panel['yaw'],
                   dict(Phrase=glyph_array(phrase), StartGlyphs=glyph_array(start_glyphs), Rewards=dict(array=rewards),
                        CommitChannel=puzzle_channel('P4.Commit'), VentChannel=puzzle_channel('P4.Vent'),
                        Source=dict(fields=dict(OutputChannel=puzzle_channel('P4'))),
                        BellOffsetWorld=dict(vector=offset(encounter['bellAt'])),
                        OwnedVent=dict(fields=dict(Enabled=True, OffsetWorld=dict(vector=offset(vent['at'])),
                            Rotation=dict(rotator=[0, vent['yaw'], 0]), PushImpulse=dict(vector=vent['pushImpulseLocalCmS'])))),
                   'P4 dial lock', pitch=panel['pitch'])
            entity('Mars_PullChain_EntityScript', chain['at'], chain['yaw'],
                   dict(Source=dict(fields=dict(OutputChannel=puzzle_channel('P4.Commit')))), 'P4 commit chain')
            entity('Mars_BellkeeperClue_EntityScript', clue['at'], clue['yaw'],
                   dict(Phrase=glyph_array(phrase), GlyphSize=clue['glyphSizeCm']), 'P4 Bridge clue', pitch=clue['pitch'])
        elif kind.startswith('Bellkeeper seal pair'):  # Frozen v5/v6 composition remains available.
            m = mouths_by_id[pz['id']]
            sz = m['z']
            niche = next(n for n in d.get('niches', []) if 'Bellkeeper' in n.get('note', ''))
            x0, y0, x1, y1 = niche['rect']
            entity('Mars_Gate_EntityScript', [m['at'][0], m['at'][1], sz], m['yaw'], latched_bars(pz), pz['id'] + ' seal gate', spanCm=GATE_OPENING * 100.0)
            assert m['axis'] == 'x', 'the Bellkeeper mouth is expected on a north/south edge'
            wall_y = m['wall'][1] if abs(m['wall'][1] - y0) < 0.01 else m['wall'][3]
            face = -1.0 if wall_y == y0 else 1.0  # the room lies on this side of the mouth wall
            glyphs = [('SealA', 'Square'), ('SealB', 'Triangle')]
            for k, (leaf, glyph) in enumerate(glyphs):
                # On the walled part of the mouth, 1.2 m up, the button facing into the room (pitch -90 puts it on +X, the yaw turns it).
                entity('Mars_Seal_EntityScript', [m['at'][0] + (-2.0 if k == 0 else 2.0), wall_y + face * 0.02, sz + 1.2], -90.0 if face < 0 else 90.0,
                       dict(Glyph=dict(enum='EMars_Seal_Glyph', value=glyph), Source=dict(fields=dict(OutputChannel=puzzle_channel(pz['id'] + '.' + leaf)))),
                       pz['id'] + ' seal ' + glyph, pitch=-90.0)
            entity('Mars_SequenceNode_EntityScript', [(x0 + x1) / 2, (y0 + y1) / 2, sz], 0.0,
                   dict(Sequence=dict(fields=dict(Steps=dict(array=[puzzle_channel(pz['id'] + '.' + leaf) for leaf, _ in glyphs]))),
                        Source=dict(fields=dict(OutputChannel=puzzle_channel(pz['id'])))), pz['id'] + ' sequence')
        elif kind.startswith('kitchen shutters'):  # PK: one crank (and an inside release) latches both kitchen shutters open
            kc = d['kitchen']
            leaves = {s['id']: s for s in d.get('structures', []) if s['kind'] == 'door'}
            for port in kc['ports']:
                leaf = leaves[port['leaf']]
                at = list(leaf['at'])
                if not port['pack']:  # the packless port is smaller than the Gate's opening: its leaf stands on the aisle face
                    at[0] -= 0.2
                entity('Mars_Gate_EntityScript', at, 0.0,
                       dict(Leaf=dict(enum='EMars_Gate_Leaf', value='Solid'),
                            Sink=dict(fields=dict(InputChannels=dict(array=[puzzle_channel(pz['id'])]), Latch=True))),
                       pz['id'] + ' ' + port['id'] + ' shutter', spanCm=GATE_OPENING * 100.0)
            for key in ('exteriorCrank', 'interiorRelease'):
                w = kc[key]
                entity('Mars_HandWheel_EntityScript', list(w['at']), w['yaw'],
                       dict(Source=dict(fields=dict(OutputChannel=puzzle_channel(pz['id'])))), pz['id'] + ' ' + key)

    # Explicit local fixtures opt in per layout; the existing class owns all gameplay behavior.
    for fixture in d.get('localFixtures', []):
        entity(fixture['cls'], fixture['at'], fixture.get('yaw', 0.0), fixture.get('props', {}), fixture['id'])

    # The hearth.
    k = nodes[d['hearth']]
    boxes.append(box('hearth', (k[0], k[1], k[2] + 0.5), (1.5, 1.5, 1.0)))

    # Foyers: four starts, a pack on the floor beside them, a dim warm light.
    mouths = {}
    for e in d['entrances']:
        sx, sy, sz = nodes[e['node']]
        link = next(l for l in links if e['node'] in (l['a'], l['b']))
        pts = polyline(d, link)
        if pts[0] != (sx, sy):
            pts = pts[::-1]
        to = pts[1]
        yaw = math.degrees(math.atan2(to[1] - sy, to[0] - sx))
        ux, uy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        cx, cy = min(max(sx, fx0 + FOYER / 2), fx1 - FOYER / 2), min(max(sy, fy0 + FOYER / 2), fy1 - FOYER / 2)
        group = e['playerStartTag'].split('.')[-1]
        for slot, (ox, oy) in enumerate([(-1.2, -1.2), (1.2, -1.2), (-1.2, 1.2), (1.2, 1.2)]):
            starts.append(dict(group=group, tag=e['playerStartTag'], slot=slot, at=[cx + ox, cy + oy, sz + 0.92], yaw=round(yaw, 3)))
        entity('Mars_WorldItem_Backpack_EntityScript', [cx - uy * 2.8, cy + ux * 2.8, sz + 0.3], 0.0, {}, f'{group} pack')
        if d.get('entryKitPan'):
            entity('Mars_WorldItem_Pan_EntityScript', [cx - uy * 2.8 + 0.8, cy + ux * 2.8, sz + 0.3], 0.0, {}, f'{group} entry Pan')
        lights.append(dict(at=[cx, cy, sz + 2.6], kind='foyer'))
        # The mouth gate stands on the corridor past the pad: the first point along the link, from FOYER/2 + 0.5 on, where
        # the walkable run across the link is no wider than the link itself (walls close both ends of the leaf), so the
        # pad's open floor never runs round the leaf. The leaf takes that measured run.
        grid = R[level_of_z(sz, U)]
        total = sum(math.dist(p, q) for p, q in zip(pts, pts[1:]))
        s_along = FOYER / 2 + 0.5
        while True:
            dist = 0.0
            for p, q in zip(pts, pts[1:]):
                seg = math.dist(p, q)
                if dist + seg >= s_along:
                    t = (s_along - dist) / seg
                    at = (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)
                    yaw = math.degrees(math.atan2(q[1] - p[1], q[0] - p[0]))
                    break
                dist += seg
            centred, span = floor_span(grid, at, yaw, link['width'], slack=1.5)
            if span <= link['width'] + 0.75 or s_along >= total - 1.0:
                break
            s_along += 0.25
        mouths[e['anchorId']] = dict(at=centred, z=sz, yaw=yaw, width=span)
    for light in d['lights']:  # a light's optional scale (the data's per-lamp tuning) multiplies its kind's intensity
        lights.append(dict(at=light['at'], kind=light['kind'], **({'scale': light['scale']} if 'scale' in light else {})))
    rooms_by_id = {r['id']: r for r in d['rooms']}
    for f in d.get('fills', []):  # at the room's centre, under its ceiling, reaching about its half-diagonal
        r = rooms_by_id[f['room']]
        cx, cy = shape_centre(r)
        x0, y0, x1, y1 = shape_bounds(r)
        if U and r['id'] in U['tallRooms']:
            fz = r['z'] + 3.5
        elif r.get('top') is not None:
            fz = r['top'] - 0.6
        else:
            fz = r['z'] + 3.0
        intensity, colour = FILL_KINDS[f['kind']]
        lights.append(dict(at=[round(cx, 3), round(cy, 3), round(fz, 3)], kind='fill_' + f['kind'], fill=True,
                           radius=round(min(14.0, max(5.0, math.hypot(x1 - x0, y1 - y0) / 2)), 2),
                           intensity=intensity * FILL_SCALE, colour=list(colour) + [1.0], room=r['id']))

    # Anchors.
    closers = {l['closedBy']: l for l in links if l['closedBy']}
    ramp_of = {r['link']['closedBy']: r for r in ramps if r['link']['closedBy']}
    for anchor in d['anchors']:
        aid, fam = anchor['id'], anchor['family']
        if fam == 'R':
            link = closers[aid]
            props = dict(AnchorId=anchor_tag(aid), Channel=dict(tag=d['channels'][aid]), SpanCm=link['width'] * 100.0)
            if aid in ramp_of:
                r = ramp_of[aid]
                at, yaw, z = r['start'], r['yaw'], r['top']
            else:
                pts = polyline(d, link)
                best = min(zip(pts, pts[1:]), key=lambda pq: seg_dist(tuple(anchor['at']), pq[0], pq[1]))
                yaw = math.degrees(math.atan2(best[1][1] - best[0][1], best[1][0] - best[0][0]))
                t = max(0.0, min(1.0, seg_param(tuple(anchor['at']), best[0], best[1])))
                on_link = (best[0][0] + (best[1][0] - best[0][0]) * t, best[0][1] + (best[1][1] - best[0][1]) * t)  # the authored point, dropped onto the link's line
                z = z_on_link(d, link, on_link)
                at, span = floor_span(R[level_of_z(z, U)], on_link, yaw, link['width'])  # the leaf seals the whole passage, not just the link's width
                props['SpanCm'] = span * 100.0
            # The crawl beside this gate (its note says 'beside RN') as a lateral offset in the gate's local frame, and the
            # one lever's side: Ahead when the plan's lever node is the link's far end (the gate faces a -> b).
            crawl = next((c for c in d['crawls'] if ('beside ' + aid) in c.get('note', '')), None)
            if crawl is not None:  # the crawl's centreline point nearest the gate, in the gate's frame: the plug goes there
                ca, cb = tuple(crawl['a']), tuple(crawl['b'])
                t = max(0.0, min(1.0, seg_param(at, ca, cb)))
                near = (ca[0] + (cb[0] - ca[0]) * t, ca[1] + (cb[1] - ca[1]) * t)
                rad = math.radians(yaw)
                along = math.cos(rad) * (near[0] - at[0]) + math.sin(rad) * (near[1] - at[1])
                lateral = -math.sin(rad) * (near[0] - at[0]) + math.cos(rad) * (near[1] - at[1])
                props['HasCrawl'] = True
                props['CrawlAlongCm'] = round(along * 100.0, 1)
                props['CrawlOffsetCm'] = round(lateral * 100.0, 1)
            lever_node = link.get('leverNode')
            if lever_node:
                side = 'Ahead' if lever_node == link['b'] else 'Behind'
                if aid in ramp_of and ramp_of[aid]['link']['a'] != link['a']:
                    side = 'Behind' if side == 'Ahead' else 'Ahead'
                props['LeverSide'] = dict(enum='EMars_Anchor_LeverSide', value=side)
            entity(d.get('routeAnchorClass', 'Mars_Anchor_Route_EntityScript'), [at[0], at[1], z], yaw, props, aid)
        elif fam == 'H':
            n = nodes[anchor['node']]
            entity('Mars_Anchor_Hunt_EntityScript', list(n), 0.0, dict(AnchorId=anchor_tag(aid), HomeRadiusCm=1000.0), aid)
            entity('Mars_Anchor_CourtNavField_EntityScript', list(n), 0.0, {}, aid)
        elif fam == 'S':
            m = mouths[aid]
            entity('Mars_Anchor_Spawn_EntityScript', [m['at'][0], m['at'][1], m['z']], m['yaw'],
                   dict(AnchorId=anchor_tag(aid), SpanCm=m['width'] * 100.0), aid)

    # Pockets: one flavour anchor per niche, at its centre, facing its mouth (the edge that opens onto walkable floor), with
    # SpanCm = the pocket's depth along that axis (wall-mounted candidates stand on the back wall). A threat pocket also
    # gets its own small nav field.
    for n in d.get('niches', []):
        if n.get('authoredReward'):
            continue  # its geometry remains; Bellkeeper pays the authored physical pickups
        cx, cy = shape_centre(n)
        nz = n.get('z', 0)
        x0, y0, x1, y1 = shape_bounds(n)
        grid = R[level_of_z(nz, U)]
        mouth = None
        for (edge, yaw_deg, depth) in (('e', 0.0, x1 - x0), ('w', 180.0, x1 - x0), ('n', 90.0, y1 - y0), ('s', -90.0, y1 - y0)):
            along = [y0 + (y1 - y0) * k / 8 for k in range(1, 8)] if edge in 'ew' else [x0 + (x1 - x0) * k / 8 for k in range(1, 8)]
            probes = [((x1 + 0.4) if edge == 'e' else (x0 - 0.4), t) for t in along] if edge in 'ew' else [(t, (y1 + 0.4) if edge == 'n' else (y0 - 0.4)) for t in along]
            if any(grid.at(p) in WALKABLE for p in probes):  # the mouth may be off-centre (a crawl enters the Sealed Burial at its corner)
                mouth = (yaw_deg, depth)
                break
        if mouth is None:
            raise AssertionError('pocket ' + n['id'] + ' opens onto no walkable floor')
        cls = POCKET_CLASSES[n['family']]
        props = dict(AnchorId=anchor_tag(n['anchorId']), SpanCm=mouth[1] * 100.0)
        if n['family'] == 'T':
            props['HomeRadiusCm'] = 600.0
            entity('Mars_Anchor_PocketNavField_EntityScript', [cx, cy, nz], 0.0, {}, n['id'] + ' nav')
        entity(cls, [cx, cy, nz], mouth[0], props, n['id'] + ': ' + n.get('note', ''))
        pockets.append(dict(id=n['id'], family=n['family'], anchorId=n['anchorId'], note=n.get('note', ''), at=[cx, cy, nz], yaw=mouth[0]))

    # --- Checks -----------------------------------------------------------------------------------------------------------
    leaks = []
    for level, grid in (('main', main), ('deep', deep), ('upper', upper)):
        if grid:
            leaks += gate_leaks(grid, level, entities, blocked=rail_blocked[level] | R['struct_blocked'][level])
    breaks = walk_breaks(d, R)
    ladder_errors = ladder_checks(d, R)
    for lk in d.get('locks', []):
        kx, ky, kz = lk['keyAt']
        if R[level_of_z(kz, U)].at((kx, ky)) not in WALKABLE:
            ladder_errors.append(lk['id'] + ': the key is not on a floor')
    for e in entities:  # every placed mechanism stands on a walkable cell of its level, or within half a metre of one (wall-mounted)
        if e['cls'].startswith(('Mars_Anchor_', 'Mars_WorldItem_')):
            continue
        g = R[e['level']]
        x, y, z = e['at']
        probes = [(x, y), (x + 0.5, y), (x - 0.5, y), (x, y + 0.5), (x, y - 0.5)]
        if not any(g.at(p) in WALKABLE or g.at(p) == 'ramp' for p in probes):
            ladder_errors.append(e['note'] + ': not on a floor of its level')
    for c in d['crawls']:  # a crawl has crawl cells and opens onto walkable floor at both ends
        g = R[level_of_z(c.get('z', 0), U)]
        cells = []
        for (ax, ay), (bx, by) in zip(crawl_pts(c), crawl_pts(c)[1:]):
            n = max(2, int(math.dist((ax, ay), (bx, by)) / 0.25))
            cells += [g.at((ax + (bx - ax) * k / n, ay + (by - ay) * k / n)) for k in range(n + 1)]
        if 'crawl' not in cells:
            ladder_errors.append(c['id'] + ': no crawl cell (the line lies inside other floor)')
        elif cells.count('crawl') < 4:
            ladder_errors.append(c['id'] + ': under 1 m of crawl')
        ends_ok = all(any(g.at(q) in WALKABLE and g.at(q) != 'crawl' for q in [(px + dx, py + dy) for dx in (-0.5, 0, 0.5) for dy in (-0.5, 0, 0.5)])
                      for px, py in (c['a'], c['b']))
        if not ends_ok:
            ladder_errors.append(c['id'] + ': an end does not open onto floor')
    dx0, dy0, dx1, dy1 = d['deep']
    for r in ramps:  # a ramp into the Deep outside its rect has nothing lining its sides below the floor slab
        if r['lower_level'] != 'deep':
            continue
        for x, y in (r['start'], r['end']):
            if not (dx0 + r['width'] / 2 <= x <= dx1 - r['width'] / 2 and dy0 + r['width'] / 2 <= y <= dy1 - r['width'] / 2):
                breaks.append('ramp ' + r['link']['a'] + '-' + r['link']['b'] + ' leaves the Deep rect')
                break
    bypasses = []  # a gate passed within the crawl budget only when crawl cells may be used: the crawl is the bypass, not a room loop
    for level, grid in (('main', main), ('deep', deep), ('upper', upper)):
        if grid:
            walls = rail_blocked[level] | R['struct_blocked'][level]
            loops = gate_leaks(grid, level, entities, crawl_ok=False, budget=6 * SEAL_WALK, blocked=walls)
            bypasses += [a for a in gate_leaks(grid, level, entities, crawl_ok=True, budget=6 * SEAL_WALK, blocked=walls) if a not in loops]
    cap_errors = []  # an over-crossing's walk line, wherever it passes above open room floor, runs on an authored deck or tread
    over_lines = [(l['a'] + '-' + l['b'], polyline(d, l), nodes[l['a']][2]) for l in d['links'] if l.get('over')]
    over_lines += [(w['id'], [tuple(p) for p in w['pts']], R[w.get('level', 'main')].z) for w in d.get('extraWalks', []) if w.get('over')]
    for name, pts, z in over_lines:
        for a, b in zip(pts, pts[1:]):
            n = max(1, int(math.dist(a, b) / 0.25))
            for k in range(n + 1):
                q = (a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n)
                if main.at(q) == 'floor' and main.z_of(q) < z - 1.0 and not deck_over(d, q, z):
                    cap_errors.append(f'{name}: its walk line at ({q[0]:.2f}, {q[1]:.2f}) is above open floor with no deck')
    connector_errors = []
    for c in d.get('connectors', []):  # real treads: every riser low enough to walk, ends meeting the floor and the head deck
        tops = [c['points'][0][2]] + [t['top'] for t in c['treads']]
        risers = [b - a for a, b in zip(tops, tops[1:])]
        if max(abs(r) for r in risers) > 0.2:
            connector_errors.append(c['id'] + f': a riser of {max(abs(r) for r in risers):.2f} m')
        foot, head = c['points'][0], c['points'][-1]
        if main.at(foot[:2]) not in WALKABLE or abs(main.z_of(foot[:2]) - foot[2]) > 0.05:
            connector_errors.append(c['id'] + ': the foot is not on floor at its height')
        if abs(c['treads'][-1]['top'] - head[2]) > 0.01 or not deck_over(d, (head[0], head[1] - 0.2), head[2]):
            connector_errors.append(c['id'] + ': the last tread does not meet a deck at the head')
        if not any(l.get('connector') == c['id'] for l in d['links']):
            connector_errors.append(c['id'] + ': no plan link is built from it')
    heights = sorted({round(z, 2) for g in (main, deep, upper) if g for row, crow in zip(g.zf, g.c) for z, c in zip(row, crow) if c in WALKABLE and c != 'tread'})
    result = dict(map=MAP, owner=OWN, boxes=boxes, starts=starts, entities=entities, lights=lights, pockets=pockets,
                  crawls=d['crawls'], rampDegrees=[round(r['degrees'], 1) for r in ramps],
                  stairDegrees={tr['id']: round(tr['degrees'], 1) for tr in treads}, deviations=DEVIATIONS + (V6_DEVIATIONS + d.get('geometryDeviations', []) if d.get('structures') else []))
    if d.get('wayfindingLabels'):
        result['labels'] = d['wayfindingLabels']
    if d.get('presentation'):
        apply_presentation(result, d['presentation'])
    summary = dict(boxes=len(boxes), starts=len(starts),
                   anchors=sum(1 for e in entities if (e['cls'].startswith('Mars_Anchor_') or e['cls'] == 'Mars_Warrens_Anchor_Route_EntityScript') and 'NavField' not in e['cls']),
                   navfields=sum(1 for e in entities if 'NavField' in e['cls']),
                   packs=sum(1 for e in entities if 'Backpack' in e['cls']),
                   ladders=sum(1 for e in entities if 'Ladder' in e['cls']),
                   gates=sum(1 for e in entities if e['cls'].endswith('Gate_EntityScript') or '_KeyDoor_' in e['cls']),
                   mechanisms=sum(1 for e in entities if any(k in e['cls'] for k in ('Lever', 'HandWheel', 'PressurePlate', 'Seal', 'Sequence', 'KeyLock'))),
                   pockets=len(pockets), props=sum(1 for b in boxes if b['kind'] in ('prop', 'root', 'candle', 'inlay')), water=len(d.get('water', [])),
                   crawls=len(d['crawls']), lights=len(lights), gateLeaks=leaks, crawlBypasses=bypasses, walkBreaks=breaks, ladderErrors=ladder_errors,
                   rails=len(rails), rampDegrees=result['rampDegrees'], stairDegrees=result['stairDegrees'], floorHeights=heights)
    if d.get('structures') or d.get('connectors'):
        summary.update(structures=len(d.get('structures', [])), caps=len(main.caps), deckRails=deck_rails, capErrors=cap_errors,
                       connectorErrors=connector_errors)
    if write:
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT / 'warrens-manifest.json').write_text(json.dumps(result, indent=1), encoding='utf-8')
        print(json.dumps(summary))
    return result, summary


def worldpos(u, at):
    return u.Vector((at[0] - 70.0) * 100.0, (at[1] - 55.0) * 100.0, at[2] * 100.0)


def apply():
    import unreal as u
    man, summary = manifest(write=True)
    ea = u.get_editor_subsystem(u.EditorActorSubsystem)
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
    assert world.get_path_name().split('.')[0] == MAP, 'open ' + MAP + ' first (found ' + world.get_path_name() + ')'
    label_materials = {}
    for label in man.get('labels', []):
        if label.get('textMaterial'):
            material = u.load_asset(label['textMaterial'])
            assert material, 'missing text material: ' + label['textMaterial']
            label_materials[label['id']] = material
    groups = render_groups(man['boxes'])
    dressing = man.get('dressing', [])
    meshes = {path: u.load_asset(path) for path in {CUBE, *MESHES.values(), *(v['mesh'] for v in dressing)}}
    assert all(isinstance(mesh, u.StaticMesh) for mesh in meshes.values()), 'missing/non-mesh presentation asset: ' + str(meshes)
    paths = {key[1] for key in groups} | {v['material'] for v in dressing if v.get('material')}
    materials = {path: u.load_asset(path) for path in paths}
    assert all(isinstance(material, u.MaterialInterface) for material in materials.values()), 'missing/non-material presentation asset: ' + str(materials)
    missing_tags = []
    for a in ea.get_all_level_actors():
        if OWN in [str(t) for t in a.tags]:
            ea.destroy_actor(a)
    ss = u.get_engine_subsystem(u.SubobjectDataSubsystem)

    def actor(cls, label, at=(0, 0, 0), yaw=0.0, folder=None, tags=()):
        a = ea.spawn_actor_from_class(cls, at if isinstance(at, u.Vector) else u.Vector(*at), u.Rotator(pitch=0, yaw=yaw, roll=0))
        a.set_actor_label('Warrens_' + label)
        a.tags = [u.Name(OWN)] + [u.Name(t) for t in tags]
        a.set_folder_path(folder or ('Warrens/' + label.split('_')[0]))
        return a

    for (kind, path, collision), values in groups.items():
        original = path == MATERIALS[kind] and collision == COLLISION.get(kind, 'BlockAll')
        suffix = '' if original else '_' + hashlib.sha256((path + '\0' + collision).encode()).hexdigest()[:12]
        a = actor(u.Actor, 'Greybox_' + kind + suffix)
        a.root_component.set_mobility(u.ComponentMobility.STATIC)  # a static HISM cannot attach under a movable root
        h = ss.k2_gather_subobject_data_for_instance(a)[0]
        ch, reason = ss.add_new_subobject(u.AddNewSubobjectParams(parent_handle=h, new_class=u.HierarchicalInstancedStaticMeshComponent))
        c = u.SubobjectDataBlueprintFunctionLibrary.get_associated_object(u.SubobjectDataBlueprintFunctionLibrary.get_data(ch))
        assert c, str(reason)
        c.set_mobility(u.ComponentMobility.STATIC)
        c.set_static_mesh(meshes[MESHES.get(kind, CUBE)])
        c.set_collision_profile_name(collision)
        c.set_material(0, materials[path])
        for b in values:
            c.add_instance(u.Transform(location=worldpos(u, b['centre']), rotation=u.Rotator(pitch=b['pitch'], yaw=b['yaw'], roll=0),
                                       scale=u.Vector(*b['size'])), world_space=True)
    for value in dressing:
        a = actor(u.StaticMeshActor, 'Dressing_' + value['id'], worldpos(u, value['at']), value.get('yaw', 0), 'Warrens/Dressing')
        c = a.static_mesh_component
        c.set_mobility(u.ComponentMobility.STATIC)
        c.set_static_mesh(meshes[value['mesh']])
        c.set_collision_profile_name(value['collision'])
        a.set_actor_scale3d(u.Vector(*value['scale']))
        if value.get('material'):
            for slot in range(len(meshes[value['mesh']].static_materials)):
                c.set_material(slot, materials[value['material']])
    for i, v in enumerate(man['lights']):
        if v.get('fill'):
            intensity, radius, colour = v['intensity'], v['radius'], v['colour']
        else:
            intensity, radius, colour = LIGHT_KINDS[v['kind']]
            intensity *= v.get('scale', 1.0)
        a = actor(u.PointLight, 'Light_' + v['kind'] + '_' + str(i), worldpos(u, v['at']))
        c = a.point_light_component
        c.set_mobility(u.ComponentMobility.STATIONARY)
        if v.get('fill'):  # a fill only lifts the room's darkness; no shadow (and no stationary-shadow overlap budget)
            c.set_cast_shadows(False)
        c.set_intensity(intensity)
        c.set_attenuation_radius(radius * 100.0)
        c.set_light_color(u.LinearColor(*colour))
    for v in man['starts']:
        a = actor(u.PlayerStart, 'Entrance_' + v['group'] + '_' + str(v['slot']), worldpos(u, v['at']), v['yaw'])
        a.set_editor_property('player_start_tag', u.Name(v['tag']))
    for v in man.get('labels', []):
        a = actor(u.TextRenderActor, 'Sign_' + v['id'], worldpos(u, v['at']), v['yaw'], 'Warrens/Wayfinding')
        c = a.get_component_by_class(u.TextRenderComponent)
        assert c, 'TextRenderActor has no text component: ' + v['id']
        c.set_text(v['text'])
        c.set_world_size(v.get('sizeCm', 14.0))
        c.set_horizontal_alignment(u.HorizTextAligment.EHTA_CENTER)
        c.set_text_render_color(u.Color(*v.get('color', (232, 218, 178, 255))))
        if v['id'] in label_materials:
            c.set_text_material(label_materials[v['id']])
        c.set_collision_profile_name('NoCollision')

    def tag_of(name):
        tag = u.GameplayTag()
        tag.import_text('(TagName="' + name + '")')
        if name not in tag.export_text():
            if STRICT_TAGS:
                raise AssertionError('gameplay tag ' + name + ' is not registered')
            u.log_warning('Warrens: gameplay tag ' + name + ' is not registered in this editor (restart it after editing the ini); left unset')
            missing_tags.append(name)
        return tag

    def coerce(value):
        if isinstance(value, dict) and 'vector' in value:
            return u.Vector(*value['vector'])
        if isinstance(value, dict) and 'rotator' in value:
            pitch, yaw, roll = value['rotator']
            return u.Rotator(pitch=pitch, yaw=yaw, roll=roll)
        if isinstance(value, dict) and 'transform' in value:
            return u.Transform(location=coerce(dict(vector=value['transform']['location'])))
        if isinstance(value, dict) and 'asset' in value:
            asset = u.load_asset(value['asset'])
            assert asset, value['asset']
            return asset
        if isinstance(value, dict) and 'struct' in value:
            struct = getattr(u, value['struct'])()
            for field, field_value in value['fields'].items():
                struct.set_editor_property(field, coerce(field_value))
            return struct
        if isinstance(value, dict) and 'enum' in value:
            enum_type = getattr(u, value['enum'][1:], None) or getattr(u, value['enum'])
            return getattr(enum_type, value['value'].upper())
        if isinstance(value, dict) and 'tag' in value:
            return tag_of(value['tag'])
        if isinstance(value, dict) and 'tags' in value:
            container = u.GameplayTagContainer()
            container.import_text('(GameplayTags=(' + ','.join('(TagName="' + t + '")' for t in value['tags']) + '))')
            assert all(t in container.export_text() for t in value['tags']), 'a gameplay tag in ' + str(value['tags']) + ' is not registered'
            return container
        if isinstance(value, dict) and 'array' in value:
            return [coerce(x) for x in value['array']]
        if isinstance(value, str):
            return u.Name(value)
        return value

    for i, v in enumerate(man['entities']):
        cls = u.load_class(None, '/Script/Angelscript.' + v['cls'])
        if not cls:
            raise RuntimeError('Missing gameplay class ' + v['cls'] + ' (has the script compiled?)')
        a = ea.spawn_actor_from_object(cls, worldpos(u, v['at']), u.Rotator(pitch=v.get('pitch', 0.0), yaw=v['yaw'], roll=0))
        assert a, v['cls']
        a.tags = [u.Name(OWN)]
        a.set_actor_label('Warrens_' + v['cls'] + '_' + str(i))
        a.set_folder_path('Warrens/Gameplay')
        script = a.get_editor_property('_EntityScript')
        for key, value in v['props'].items():
            before = len(missing_tags)
            if isinstance(value, dict) and 'fields' in value:
                struct = script.get_editor_property(key)
                for field, field_value in value['fields'].items():
                    struct.set_editor_property(field, coerce(field_value))
                value = struct
            else:
                value = coerce(value)
            if len(missing_tags) > before:  # an unset channel would make the script's construction ensure: leave the whole spec at its default
                u.log_warning('Warrens: ' + v['note'] + ': ' + key + ' left at its default (its channel tag is not loaded)')
                continue
            script.set_editor_property(key, value)
    mode = u.load_class(None, '/Script/Angelscript.Mars_Warrens_GameMode')
    assert mode, 'Mars_Warrens_GameMode has not compiled'
    world.get_world_settings().set_editor_property('default_game_mode', mode)
    # Lighting: no daylight. A navy ambient floor (AMBIENT_FILL) so unlit rooms read as dark, not black, and fixed exposure so the
    # eye never adapts the dark away.
    for a in ea.get_all_level_actors():
        if isinstance(a, (u.SkyLight, u.DirectionalLight)) and OWN not in [str(t) for t in a.tags]:
            u.log_warning('Warrens: a sky or directional light not owned by the builder is left in place: ' + a.get_actor_label())
    a = actor(u.ExponentialHeightFog, 'Mist', (0, 0, -400))
    a.component.set_editor_property('fog_density', .02)
    a.component.set_editor_property('fog_height_falloff', .25)
    a.component.set_editor_property('fog_inscattering_luminance', u.LinearColor(.01, .012, .015, 1))
    a = actor(u.PostProcessVolume, 'Darkness')
    a.set_editor_property('unbound', True)
    a.set_editor_property('priority', 10)
    settings = a.get_editor_property('settings')
    for key, value in [('ambient_cubemap', u.load_asset('/Engine/EngineResources/GrayDarkTextureCube')),
                       ('ambient_cubemap_intensity', AMBIENT_FILL[0]), ('ambient_cubemap_tint', u.LinearColor(*AMBIENT_FILL[1], 1)),
                       ('auto_exposure_min_brightness', 1.0), ('auto_exposure_max_brightness', 1.0), ('auto_exposure_bias', 0.0)]:
        settings.set_editor_property(key, value)
        if key != 'ambient_cubemap':
            settings.set_editor_property('override_' + key, True)
    a.set_editor_property('settings', settings)
    assert u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
    # The lantern and tallow beside each pack (Mars.Warrens.PlaceLantern, Script/Editor/Mars_WarrensMapBuilder.as) are
    # not the builder's, but they follow the packs: a set left more than 4 m from every pack was stranded by a foyer
    # move and goes; the command then places a set beside every pack that has none, and saves.
    packs = [a.get_actor_location() for a in ea.get_all_level_actors()
             if OWN in [str(t) for t in a.tags] and 'Backpack' in a.get_actor_label()]
    stranded = 0
    for a in ea.get_all_level_actors():
        if a.get_actor_label().startswith('Item_Warrens_'):
            loc = a.get_actor_location()
            if all((loc - p).length() > 400.0 for p in packs):
                ea.destroy_actor(a)
                stranded += 1
    u.SystemLibrary.execute_console_command(world, 'Mars.Warrens.PlaceLantern')
    record = dict(map=MAP, strandedItemsRemoved=stranded, missingTags=sorted(set(missing_tags)),
                  **{k: summary[k] for k in ('boxes', 'starts', 'anchors', 'navfields', 'packs', 'ladders', 'gates', 'mechanisms', 'pockets', 'props', 'crawls', 'lights')})
    (OUT / 'warrens-built.json').write_text(json.dumps(record, indent=1), encoding='utf-8')
    print(json.dumps(record))


def audit():
    """Trace the saved collision along every walked link, tread and ramp, check every start's capsule, check each crawl gap
    stops a standing chef and lets a crouched one through, validate the Jolt bake."""
    import unreal as u
    man, _ = manifest(write=False)
    d = load()
    U = d.get('upper')
    w = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()

    def trace(x, y, z):
        return u.SystemLibrary.line_trace_single(w, worldpos(u, (x, y, z + .6)), worldpos(u, (x, y, z - .6)),
                                                 u.TraceTypeQuery.TRACE_TYPE_QUERY1, False, [], u.DrawDebugTrace.NONE)

    def capsule_blocked(at, half_height):
        loc = worldpos(u, at)
        return bool(u.SystemLibrary.capsule_trace_single(w, loc, u.Vector(loc.x, loc.y, loc.z + .1), 39, half_height,
                                                         u.TraceTypeQuery.TRACE_TYPE_QUERY1, False, [], u.DrawDebugTrace.NONE))

    nodes = d['nodes']
    paths = []
    for link in d['links']:
        za, zb = nodes[link['a']][2], nodes[link['b']][2]
        if link['kind'] == 'walk' and za == zb:
            pts = polyline(d, link)
            for p, q in zip(pts, pts[1:]):
                paths.append((p, q, za, za))
    for r in ramps_of(d):
        paths.append((r['start'], r['descent_end'], r['top'], r['bottom']))
        if r['descent_end'] != r['end']:
            paths.append((r['descent_end'], r['end'], r['bottom'], r['bottom']))
    for tr in treads_of(d):
        for p, q in tr['segments']:
            paths.append((p[:2], q[:2], p[2], q[2]))
    for walk in d.get('extraWalks', []):
        if 'pts' in walk:
            wz = {'deep': DEEP_Z, 'upper': U['z'] if U else 0.0}.get(walk.get('level'), 0.0)
            paths += [(tuple(p), tuple(q), wz, wz) for p, q in zip(walk['pts'], walk['pts'][1:])]
    if U:
        uz = U['z']
        for walk in U['walkways']:
            paths += [(tuple(p), tuple(q), uz, uz) for p, q in zip(walk['pts'], walk['pts'][1:])]
    for c in d.get('connectors', []):  # each spiral tread's centre, at its top
        cx, cy = c['core']['at'][:2]
        for t in c['treads']:
            r0, r1, a0, a1 = tread_span(c, t)
            at = (cx + (r0 + r1) / 2 * math.cos((a0 + a1) / 2), cy + (r0 + r1) / 2 * math.sin((a0 + a1) / 2))
            paths.append((at, at, t['top'], t['top']))
    missing, count = [], 0
    for p, q, z0, z1 in paths:
        seg = math.dist(p, q)
        for k in range(int(seg) + 1):
            t = 0.0 if seg == 0 else min(k / seg, 1.0)
            x, y, z = p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t, z0 + (z1 - z0) * t
            count += 1
            if not trace(x, y, z):
                missing.append([round(x, 2), round(y, 2), round(z, 2)])
    clear = sum(0 if capsule_blocked(s['at'], 75) else 1 for s in man['starts'])
    # A crawl gap stops a standing chef and a crouched chef wearing a pack (140 cm), and passes a crouched one without.
    crawls_ok = 0
    for c in d['crawls']:
        pa, pb = crawl_pts(c)[0], crawl_pts(c)[1]
        mx, my, cz = (pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2, c.get('z', 0)
        stands = capsule_blocked((mx, my, cz + 0.77), 75)
        pack = capsule_blocked((mx, my, cz + 0.72), 70)
        crouches = not capsule_blocked((mx, my, cz + 0.55), 52.5)
        crawls_ok += 1 if stands and pack and crouches else 0
    # A low tunnel passes a standing chef along its whole length (except on the foot of a dive ramp or a spiral, where the sample stands on its first slab or tread).
    low_blocked = []
    low = {tuple(sorted(pair)) for pair in d.get('lowLinks', [])}
    ramp_feet = [r['end'] for r in ramps_of(d)]
    ramp_feet += [tuple(c['points'][0][:2]) for c in d.get('connectors', [])]  # a spiral's foot: the sample stands on its first tread
    for link in d['links']:
        if tuple(sorted((link['a'], link['b']))) not in low:
            continue
        lz = nodes[link['a']][2]
        pts = polyline(d, link)
        for p, q in zip(pts, pts[1:]):
            seg = math.dist(p, q)
            for k in range(int(seg) + 1):
                t = 0.0 if seg == 0 else min(k / seg, 1.0)
                pt = (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t, lz + 0.77)
                if any(math.dist(pt[:2], f) < 0.5 for f in ramp_feet):
                    continue
                if capsule_blocked(pt, 75):
                    low_blocked.append([link['a'] + '-' + link['b'], round(pt[0], 2), round(pt[1], 2)])
    # v6: the kitchen ports are shut as built (both shutters closed), and a standing chef fits on every deck's centre.
    extra = {}
    if d.get('kitchen'):
        leaves = {s['id']: s for s in d.get('structures', []) if s['kind'] == 'door'}
        extra['kitchenPortsShut'] = {p['id']: capsule_blocked((leaves[p['leaf']]['at'][0], leaves[p['leaf']]['at'][1], 0.55), 52.5) for p in d['kitchen']['ports']}
    decks = [s for s in d.get('structures', []) if s['kind'] == 'platform' and s.get('rails') is not False]
    if decks:
        extra['decksClear'] = {s['id']: not capsule_blocked((s['at'][0], s['at'][1], s['at'][2] + s['size'][2] + 0.77), 75) for s in decks}
    jolt = u.get_editor_subsystem(u.Ck_JoltCook_EditorSubsystem_UE).validate_current_world()
    result = dict(samples=count, missing=len(missing), startsClear=clear, crawlsOk=crawls_ok, crawls=len(d['crawls']),
                  lowTunnelBlocked=len(low_blocked), jolt=bool(jolt), deviations=DEVIATIONS, **extra)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'warrens-audit.json').write_text(json.dumps(dict(result, missingSamples=missing[:200], lowBlockedSamples=low_blocked[:50]), indent=1), encoding='utf-8')
    print(json.dumps(result))


if __name__ == '__main__':
    manifest()
