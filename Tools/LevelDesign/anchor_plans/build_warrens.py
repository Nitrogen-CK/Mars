"""Warrens greybox (r2), built from data/warrens.json (authored by design_warrens_r2.py).

    python Tools/LevelDesign/anchor_plans/build_warrens.py      -> manifest(): plain Python, writes the manifest, prints a summary
    (Unreal Python, on the open /Game/Mars/Maps/Warrens_Mars_MAP)
    import build_warrens; build_warrens.apply()                  -> places the greybox, anchors, packs, lights, game mode; saves
    build_warrens.audit()                                        -> floor traces, start capsules, crawl fit, Jolt bake

Each level is rasterized at CELL metres: links (by width), rooms and foyer pads are carved walkable and everything else
inside the footprint stays solid, then each class is greedy-merged into boxes. Bent and diagonal passages come out as
they are drawn. Ramps into the Deep start 2 m past their upper node; crawl gaps keep a floor under a 1.3 m lintel;
galleries sit 3 m up inside their room and are reached only by ladder. A UE location is ((x - 70), (y - 55), z) * 100.
Never creates, loads or saves another level. Rebuilding destroys only actors tagged OWN.
"""
import json
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
CUBE = '/Engine/BasicShapes/Cube'
MATERIALS = {
    'floor': '/Game/Mars/Materials/ProtoGrid/ProtoGrid_Floor_Mars_MI',
    'wall': '/Game/Mars/Materials/ProtoGrid/ProtoGrid_Wall_Mars_MI',
    'ramp': '/Game/Mars/Materials/ProtoGrid/ProtoGrid_Platform_Mars_MI',
    'gallery': '/Game/Mars/Materials/ProtoGrid/ProtoGrid_Platform_Mars_MI',
    'hearth': '/Game/Mars/Materials/ProtoGrid/ProtoGrid_Interactable_Mars_MI',
    'grate': '/Game/Mars/Materials/ProtoGrid/ProtoGrid_Wall_Mars_MI',
}
CELL = 0.5
SLAB = 0.4
WALL_TOP = 4.0
DEEP_Z = -5.0
RAMP_START = 2.0
FOYER = 8.0
CRAWL_WIDTH = 1.5
CRAWL_HEIGHT = 1.3  # the sandbox crouch tunnel: 150 standing is blocked, 105 crouched fits
GALLERY_RAIL = 1.0
GRATE_PITCH = 0.25  # bar spacing: a capsule (39 cm radius) walks across, nothing falls through
LIGHT_KINDS = {  # intensity, radius m, colour
    'hearth': (5200, 13.0, (1.0, 0.52, 0.22, 1.0)),
    'foyer': (900, 7.0, (1.0, 0.6, 0.3, 1.0)),
    'dim': (700, 6.5, (1.0, 0.62, 0.32, 1.0)),
    'cold': (1600, 16.0, (0.55, 0.7, 1.0, 1.0)),
    'shaft': (5200, 20.0, (0.7, 0.85, 1.0, 1.0)),
}
DEVIATIONS = [
    'stairs are straight ramps starting 2 m past the upper node',
    'crawl gaps and galleries are optional geometry outside the plan graph (the solve never relies on them)',
    'the Deep is roofed by the main floor; with an upper level the main floor is roofed too, except its tall rooms',
]


def load():
    return json.loads(DATA.read_text(encoding='utf-8'))


def anchor_tag(aid):
    return dict(tag=ANCHOR_TAG_ROOT + '.' + aid)


def shortcut_tag(sid):
    return dict(tag=SHORTCUT_TAG_ROOT + '.' + sid)


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


class Grid:
    def __init__(self, rect, fill):
        self.x0, self.y0, x1, y1 = rect
        self.nx, self.ny = int(round((x1 - self.x0) / CELL)), int(round((y1 - self.y0) / CELL))
        self.c = [[fill] * self.nx for _ in range(self.ny)]

    def centre(self, i, j):
        return (self.x0 + (i + 0.5) * CELL, self.y0 + (j + 0.5) * CELL)

    def stamp_segment(self, a, b, half, value, only=None, square=False):
        """Cells within half of segment ab; square ends drop the round caps (a ramp's mouth must not bite a neighbour)."""
        xa, xb = min(a[0], b[0]) - half, max(a[0], b[0]) + half
        ya, yb = min(a[1], b[1]) - half, max(a[1], b[1]) + half
        for j in range(max(0, int((ya - self.y0) / CELL)), min(self.ny, int((yb - self.y0) / CELL) + 1)):
            for i in range(max(0, int((xa - self.x0) / CELL)), min(self.nx, int((xb - self.x0) / CELL) + 1)):
                p = self.centre(i, j)
                if square and not 0.0 <= seg_param(p, a, b) <= 1.0:
                    continue
                if seg_dist(p, a, b) <= half and (only is None or self.c[j][i] in only):
                    self.c[j][i] = value

    def stamp_rect(self, rect, value):
        x0, y0, x1, y1 = rect
        for j in range(self.ny):
            for i in range(self.nx):
                cx, cy = self.centre(i, j)
                if x0 <= cx <= x1 and y0 <= cy <= y1:
                    self.c[j][i] = value

    def rects(self, value):
        """Greedy merge of every cell holding value into axis-aligned rectangles (metres)."""
        used = [[False] * self.nx for _ in range(self.ny)]
        out = []
        for j in range(self.ny):
            for i in range(self.nx):
                if used[j][i] or self.c[j][i] != value:
                    continue
                w = 1
                while i + w < self.nx and not used[j][i + w] and self.c[j][i + w] == value:
                    w += 1
                h = 1
                while j + h < self.ny and all(not used[j + h][i + k] and self.c[j + h][i + k] == value for k in range(w)):
                    h += 1
                for jj in range(j, j + h):
                    for ii in range(i, i + w):
                        used[jj][ii] = True
                out.append((self.x0 + i * CELL, self.y0 + j * CELL, self.x0 + (i + w) * CELL, self.y0 + (j + h) * CELL))
        return out


def box(kind, centre, size, yaw=0.0, pitch=0.0):
    return dict(kind=kind, centre=[round(v, 4) for v in centre], size=[round(v, 4) for v in size],
                yaw=round(yaw, 4), pitch=round(pitch, 4))


def slabs(out, kind, rects, z_bottom, z_top):
    for x0, y0, x1, y1 in rects:
        out.append(box(kind, ((x0 + x1) / 2, (y0 + y1) / 2, (z_bottom + z_top) / 2), (x1 - x0, y1 - y0, z_top - z_bottom)))


def ramps_of(d):
    nodes, out = d['nodes'], []
    for link in d['links']:
        if link['kind'] != 'stair':
            continue
        a, b = nodes[link['a']], nodes[link['b']]
        upper, lower = (a, b) if a[2] > b[2] else (b, a)
        dx, dy = lower[0] - upper[0], lower[1] - upper[1]
        run = math.hypot(dx, dy)
        ux, uy = dx / run, dy / run
        start = (upper[0] + ux * RAMP_START, upper[1] + uy * RAMP_START)
        # Open above rampRoofZ (when the data sets it), roofed below: a corridor may cross over the deep half.
        roof = d.get('rampRoofZ')
        frac = 1.0 if roof is None else min(1.0, (upper[2] - roof) / (upper[2] - lower[2]) + 0.5 / (run - RAMP_START))
        open_end = (start[0] + (lower[0] - start[0]) * frac, start[1] + (lower[1] - start[1]) * frac)
        out.append(dict(link=link, upper=(upper[0], upper[1]), start=start, open_end=open_end, end=(lower[0], lower[1]), top=upper[2],
                        bottom=lower[2], width=link['width'], yaw=math.degrees(math.atan2(dy, dx)),
                        degrees=math.degrees(math.atan2(upper[2] - lower[2], run - RAMP_START))))
    return out


def cell_at(grid, pt):
    i, j = int((pt[0] - grid.x0) / CELL), int((pt[1] - grid.y0) / CELL)
    if not (0 <= i < grid.nx and 0 <= j < grid.ny):
        return 'outside'
    return grid.c[j][i]


def rail_edges(grid, heads, gaps):
    """Edges between a floor cell and an open (void) cell, merged into runs, minus ladder heads and drop gaps."""
    def skip(mx, my):
        return any(math.hypot(mx - hx, my - hy) < 0.9 for hx, hy in heads) or any(seg_dist((mx, my), a, b) < 0.3 for a, b in gaps)

    pieces = {}
    for j in range(grid.ny):
        for i in range(grid.nx):
            if grid.c[j][i] != 'floor':
                continue
            x0, y0 = grid.x0 + i * CELL, grid.y0 + j * CELL
            for di, dj, kind, line, start in ((0, -1, 'h', y0, x0), (0, 1, 'h', y0 + CELL, x0), (-1, 0, 'v', x0, y0), (1, 0, 'v', x0 + CELL, y0)):
                ni, nj = i + di, j + dj
                if 0 <= ni < grid.nx and 0 <= nj < grid.ny and grid.c[nj][ni] == 'void':
                    mid = (start + CELL / 2, line) if kind == 'h' else (line, start + CELL / 2)
                    if not skip(*mid):
                        pieces.setdefault((kind, round(line, 3)), []).append(start)
    out = []
    for (kind, line), starts in pieces.items():
        starts.sort()
        run0 = prev = starts[0]
        for st in starts[1:] + [None]:
            if st is not None and abs(st - prev - CELL) < 1e-6:
                prev = st
                continue
            a, b = run0, prev + CELL
            out.append((a, line, b, line) if kind == 'h' else (line, a, line, b))
            if st is not None:
                run0 = prev = st
    return out


def ladder_checks(d, up, deep, raf):
    """Each ladder: floor in front of its foot, open air in front of it at the top level, a landing behind its head."""
    grids = {DEEP_Z: deep, 0.0: up}
    if raf:
        grids[d['upper']['z']] = raf
    errors = []
    for l in d.get('ladders', []):
        x, y = l['at']
        a = math.radians(l['yaw'])
        fx, fy = math.cos(a), math.sin(a)
        base, top = grids.get(l['baseZ']), grids.get(round(l['baseZ'] + l['height'], 3))
        if base is None or top is None:
            errors.append(l['id'] + ': no level at its foot or head')
            continue
        if cell_at(base, (x + fx * 0.6, y + fy * 0.6)) not in ('floor', 'grate'):
            errors.append(l['id'] + ': no floor in front of the foot')
        if cell_at(top, (x + fx * 0.45, y + fy * 0.45)) != 'void':
            errors.append(l['id'] + ': the climb is roofed (no opening in front of the ladder at the top)')
        if cell_at(top, (x - fx * 0.75, y - fy * 0.75)) not in ('floor', 'grate'):
            errors.append(l['id'] + ': no landing behind the head')
    return errors


SEAL_RADIUS = 30.0
SEAL_WALK = 10.0  # a way round a gate shorter than this is a walk-around; a longer one is a loop through other rooms


def gate_leaks(grid, entities, crawl_ok=False, level_z=0.0):
    """A gate seals when, with its span blocked, the cell 1 m in front cannot reach the cell 1 m behind within SEAL_WALK
    metres of walking (and without leaving a SEAL_RADIUS disc). Cracks are walls. Ramp cells count as walkable: a gate at a ramp mouth is passed by stepping onto the ramp.
    Crawl cells count only with crawl_ok (a crouched chef): a crawl beside a gate is a bypass by design, not a leak."""
    from collections import deque
    leaks = []
    for e in entities:
        if not (e['cls'].endswith('Route_EntityScript') or e['cls'].endswith('Spawn_EntityScript') or e['cls'].endswith('Shortcut_EntityScript')
                or '_KeyDoor_' in e['cls']):
            continue
        x, y, z = e['at']
        if z != level_z:
            continue
        a = math.radians(e['yaw'])
        fx, fy, px, py = math.cos(a), math.sin(a), -math.sin(a), math.cos(a)
        half = e['props'].get('SpanCm', e.get('spanCm', 0.0)) / 200.0
        g0, g1 = (x - px * half, y - py * half), (x + px * half, y + py * half)

        def cell(pt):
            return int((pt[0] - grid.x0) / CELL), int((pt[1] - grid.y0) / CELL)

        def open_cell(i, j):
            if not (0 <= i < grid.nx and 0 <= j < grid.ny) or grid.c[j][i] in ('solid', 'crack') or (grid.c[j][i] == 'crawl' and not crawl_ok):
                return False
            c = grid.centre(i, j)
            return math.hypot(c[0] - x, c[1] - y) <= SEAL_RADIUS and seg_dist(c, g0, g1) > 0.35

        start, goal = cell((x - fx, y - fy)), cell((x + fx, y + fy))
        seen, todo = {start: 0}, deque([start])
        while todo:
            i, j = todo.popleft()
            if (seen[(i, j)] + 1) * CELL > (4 * SEAL_WALK if crawl_ok else SEAL_WALK):  # a crawl detour runs room to room
                continue
            for n in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
                if n not in seen and open_cell(*n):
                    seen[n] = seen[(i, j)] + 1
                    todo.append(n)
        if goal in seen:
            leaks.append(e['note'])
    return leaks


def walk_breaks(d, up, deep, raf=None):
    """Walk lines (plan links, extra walks, Rafters walkways) that cross a hole or a wall in their level's raster."""
    nodes, out = d['nodes'], []
    lines = [(w['id'], w['pts'], deep if w.get('level') == 'deep' else up) for w in d.get('extraWalks', []) if 'pts' in w]
    if raf:
        lines += [(w['id'], w['pts'], raf) for w in d['upper']['walkways']]
    for name, pts, grid in lines:
        for p, q in zip(pts, pts[1:]):
            if any(cell_at(grid, (p[0] + (q[0] - p[0]) * k / 20, p[1] + (q[1] - p[1]) * k / 20)) in ('void', 'solid') for k in range(21)):
                out.append(name)
                break
    for link in d['links']:
        za, zb = nodes[link['a']][2], nodes[link['b']][2]
        if link['kind'] != 'walk' or za != zb:
            continue
        grid = up if za == 0 else deep
        pts = polyline(d, link)
        for p, q in zip(pts, pts[1:]):
            seg = math.dist(p, q)
            n = max(1, int(seg / 0.25))
            hits = [(p[0] + (q[0] - p[0]) * k / n, p[1] + (q[1] - p[1]) * k / n) for k in range(n + 1)]
            bad = [h for h in hits if grid.c[min(grid.ny - 1, int((h[1] - grid.y0) / CELL))][min(grid.nx - 1, int((h[0] - grid.x0) / CELL))] in ('void', 'solid')]
            if bad:
                out.append(link['a'] + '-' + link['b'])
                break
    return out


def manifest(write=True):
    d = load()
    nodes, links = d['nodes'], d['links']
    boxes, starts, entities, lights = [], [], [], []
    ramps = ramps_of(d)
    fx0, fy0, fx1, fy1 = d['footprint']

    # Upper level: solid everywhere, then carve.
    up = Grid(d['footprint'], 'solid')
    for room in d['rooms']:
        if room['z'] == 0:
            up.stamp_rect(room['rect'], 'floor')
    for sid in [e['node'] for e in d['entrances']]:
        sx, sy, _ = nodes[sid]
        up.stamp_rect((max(fx0, sx - FOYER / 2), max(fy0, sy - FOYER / 2), min(fx1, sx + FOYER / 2), min(fy1, sy + FOYER / 2)), 'floor')
    low = {tuple(sorted(pair)) for pair in d.get('lowLinks', [])}
    for link in links:
        za, zb = nodes[link['a']][2], nodes[link['b']][2]
        if link['kind'] == 'walk' and za == zb == 0:
            pts = polyline(d, link)
            is_low = tuple(sorted((link['a'], link['b']))) in low
            for p, q in zip(pts, pts[1:]):
                up.stamp_segment(p, q, link['width'] / 2, 'low' if is_low else 'floor', only=('solid', 'low') if is_low else None)
    for r in ramps:
        up.stamp_segment(r['upper'], r['start'], r['width'] / 2, 'floor')
        up.stamp_segment(r['start'], r['open_end'], r['width'] / 2, 'void', square=True)
    for crawl in d['crawls']:
        up.stamp_segment(tuple(crawl['a']), tuple(crawl['b']), CRAWL_WIDTH / 2, 'crawl', only=('solid',))
    for w in d.get('extraWalks', []):
        if w.get('level', 'main') != 'main':
            continue
        if 'rect' in w:
            up.stamp_rect(w['rect'], 'floor')
        else:
            for p, q in zip(w['pts'], w['pts'][1:]):
                up.stamp_segment(tuple(p), tuple(q), w['width'] / 2, 'floor')
    for c in d.get('cracks', []):
        up.stamp_segment(tuple(c['a']), tuple(c['b']), c['width'] / 2, 'crack', only=('solid',))
    for h in d.get('holes', []):
        if h['level'] == 'main':
            up.stamp_rect(h['rect'], 'grate' if h['kind'] == 'grate' else 'void')

    # The Rafters (+5): solid over the roofed main floor, open over the tall rooms, carved by ledges and walkways.
    U = d.get('upper')
    main_top = U['mainTop'] if U else WALL_TOP
    raf = None
    if U:
        raf = Grid(d['footprint'], 'solid')
        for room in d['rooms']:
            if room['id'] in U['tallRooms']:
                raf.stamp_rect(room['rect'], 'void')
        for plat in U['platforms']:
            raf.stamp_rect(plat['rect'], 'floor')
        for w in U['walkways']:
            for p, q in zip(w['pts'], w['pts'][1:]):
                raf.stamp_segment(tuple(p), tuple(q), w['width'] / 2, 'floor')
        for h in d.get('holes', []):
            if h['level'] == 'upper':
                raf.stamp_rect(h['rect'], 'void')
    for pl in d.get('pillars', []):
        if pl['level'] == 'main':
            up.stamp_rect(pl['rect'], 'solid')

    # The Deep: solid inside its rect, carved by its links, rooms and the ramps' feet.
    deep = Grid(d['deep'], 'solid')
    for room in d['rooms']:
        if room['z'] == DEEP_Z:
            deep.stamp_rect(room['rect'], 'floor')
    for link in links:
        za, zb = nodes[link['a']][2], nodes[link['b']][2]
        if link['kind'] == 'walk' and za == zb == DEEP_Z:
            pts = polyline(d, link)
            for p, q in zip(pts, pts[1:]):
                deep.stamp_segment(p, q, link['width'] / 2, 'floor')
    for r in ramps:
        deep.stamp_segment(r['upper'], r['end'], r['width'] / 2, 'floor')
    for w in d.get('extraWalks', []):
        if w.get('level') == 'deep':
            for p, q in zip(w['pts'], w['pts'][1:]):
                deep.stamp_segment(tuple(p), tuple(q), w['width'] / 2, 'floor')
    for pl in d.get('pillars', []):
        if pl['level'] == 'deep':
            deep.stamp_rect(pl['rect'], 'solid')

    # Boxes. Upper-level cells over a carved Deep cell keep only their walls; floors and solid there sit on the Deep's.
    slabs(boxes, 'wall', up.rects('solid'), -SLAB, main_top)
    slabs(boxes, 'floor', up.rects('floor'), -SLAB, 0.0)
    low_rects = up.rects('low')
    slabs(boxes, 'floor', low_rects, -SLAB, 0.0)
    slabs(boxes, 'wall', low_rects, d.get('lowRoof', main_top), main_top)
    crawl_rects = up.rects('crawl')
    slabs(boxes, 'floor', crawl_rects, -SLAB, 0.0)
    slabs(boxes, 'wall', crawl_rects, CRAWL_HEIGHT, main_top)
    for c in d.get('cracks', [])[:1]:  # all cracks share one sill and head
        crack_rects = up.rects('crack')
        slabs(boxes, 'wall', crack_rects, -SLAB, c['sill'])
        slabs(boxes, 'wall', crack_rects, c['head'], main_top)
    for h in d.get('holes', []):
        if h['kind'] == 'grate':
            x0, y0, x1, y1 = h['rect']
            n = int((x1 - x0) / GRATE_PITCH)
            for k in range(n + 1):
                x = x0 + k * (x1 - x0) / n
                boxes.append(box('grate', (x, (y0 + y1) / 2, -0.05), (0.06, y1 - y0, 0.1)))
            for y in (y0, y1):
                boxes.append(box('grate', ((x0 + x1) / 2, y, -0.05), (x1 - x0, 0.06, 0.1)))
    rails = []
    if raf:
        slabs(boxes, 'wall', raf.rects('solid'), main_top, U['top'])
        slabs(boxes, 'gallery', raf.rects('floor'), main_top, U['z'])
        heads = [tuple(l['at']) for l in d.get('ladders', []) if abs(l['baseZ'] + l['height'] - U['z']) < 0.01]
        gaps = [(tuple(g['a']), tuple(g['b'])) for g in U.get('railGaps', [])]
        rails = rail_edges(raf, heads, gaps)
        for (x0, y0, x1, y1) in rails:
            if x0 == x1:
                slabs(boxes, 'gallery', [(x0 - 0.05, y0, x0 + 0.05, y1)], U['z'], U['z'] + GALLERY_RAIL)
            else:
                slabs(boxes, 'gallery', [(x0, y0 - 0.05, x1, y0 + 0.05)], U['z'], U['z'] + GALLERY_RAIL)
    slabs(boxes, 'wall', deep.rects('solid'), DEEP_Z, -SLAB)
    slabs(boxes, 'floor', deep.rects('floor'), DEEP_Z - SLAB, DEEP_Z)
    # A rim so a foyer pad on the footprint edge never opens onto nothing.
    for rim in [(fx0 - 0.5, fy0 - 0.5, fx1 + 0.5, fy0), (fx0 - 0.5, fy1, fx1 + 0.5, fy1 + 0.5),
                (fx0 - 0.5, fy0, fx0, fy1), (fx1, fy0, fx1 + 0.5, fy1)]:
        slabs(boxes, 'wall', [rim], -SLAB, U['top'] if U else WALL_TOP)
    for r in ramps:
        length = math.dist(r['start'], r['end'])
        drop = r['top'] - r['bottom']
        mid = ((r['start'][0] + r['end'][0]) / 2, (r['start'][1] + r['end'][1]) / 2, (r['top'] + r['bottom']) / 2 - SLAB / 2)
        boxes.append(box('ramp', mid, (math.hypot(length, drop), r['width'], SLAB), r['yaw'], -r['degrees']))

    # Galleries: a 3 m ledge with a rail along its open edge, a gap at the ladder.
    for g in d['galleries']:
        x0, y0, x1, y1 = g['rect']
        z = g['z']
        slabs(boxes, 'gallery', [(x0, y0, x1, y1)], z - SLAB, z)
        lx, ly = g['ladder']['at']
        ladder_yaw = g['ladder']['yaw']
        if abs(math.sin(math.radians(ladder_yaw))) > 0.5:  # the ladder faces north/south: the rail runs along x
            for a, b in [(x0, lx - 0.7), (lx + 0.7, x1)]:
                if b - a > 0.1:
                    slabs(boxes, 'gallery', [(a, ly - 0.1, b, ly + 0.1)], z, z + GALLERY_RAIL)
        else:
            for a, b in [(y0, ly - 0.7), (ly + 0.7, y1)]:
                if b - a > 0.1:
                    slabs(boxes, 'gallery', [(lx - 0.1, a, lx + 0.1, b)], z, z + GALLERY_RAIL)
        entities.append(dict(cls='Mars_Ladder_EntityScript', at=[lx, ly, 0.0], yaw=ladder_yaw, props={}, note=g['id']))
    for l in d.get('ladders', []):
        entities.append(dict(cls='Mars_Ladder_EntityScript', at=[l['at'][0], l['at'][1], l['baseZ']], yaw=l['yaw'],
                             props=dict(Ladder=dict(fields=dict(Height=l['height'] * 100.0))), note=l['id']))
    for lk in d.get('locks', []):
        colour = lk['key']
        dz = DEEP_Z if lk['door']['level'] == 'deep' else 0.0
        entities.append(dict(cls='Mars_Sandbox_KeyDoor_' + colour + '_EntityScript', at=[*lk['door']['at'], dz], yaw=lk['door']['yaw'],
                             props={}, spanCm=lk['door']['spanCm'], note=lk['id'] + ' door'))
        lz = DEEP_Z if lk['lock']['level'] == 'deep' else 0.0
        entities.append(dict(cls='Mars_Sandbox_KeyLock_' + colour + '_EntityScript', at=[*lk['lock']['at'], lz], yaw=lk['lock']['yaw'],
                             props={}, note=lk['id'] + ' lock'))
        entities.append(dict(cls='Mars_WorldItem_Key_' + colour + '_EntityScript', at=list(lk['keyAt']), yaw=0.0, props={},
                             note=lk['id'] + ' key'))
    for sc in d.get('shortcuts', []):
        entities.append(dict(cls='Mars_Shortcut_EntityScript', at=[sc['at'][0], sc['at'][1], 0.0], yaw=sc['yaw'],
                             props=dict(ShortcutId=shortcut_tag(sc['id']), Channel=dict(tag=sc['channel']), SpanCm=sc['spanCm'],
                                        LeverSide=dict(enum='EMars_Shortcut_LeverSide', value='Ahead' if sc['leverSide'] > 0 else 'Behind')),
                             note=sc['id']))

    # The hearth.
    k = nodes[d['hearth']]
    boxes.append(box('hearth', (k[0], k[1], 0.5), (1.5, 1.5, 1.0)))

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
        entities.append(dict(cls='Mars_WorldItem_Backpack_EntityScript', at=[cx - uy * 2.8, cy + ux * 2.8, sz + 0.3], yaw=0.0,
                             props={}, note=f'{group} pack'))
        lights.append(dict(at=[cx, cy, 2.6], kind='foyer'))
        dist = 0.0
        for p, q in zip(pts, pts[1:]):
            seg = math.dist(p, q)
            if dist + seg >= FOYER / 2 + 0.5:
                t = (FOYER / 2 + 0.5 - dist) / seg
                mouths[e['anchorId']] = dict(at=(p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t),
                                             yaw=math.degrees(math.atan2(q[1] - p[1], q[0] - p[0])), width=link['width'])
                break
            dist += seg
    for light in d['lights']:
        lights.append(dict(at=light['at'], kind=light['kind']))

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
                at, z = tuple(anchor['at']), nodes[link['a']][2]
                yaw = math.degrees(math.atan2(best[1][1] - best[0][1], best[1][0] - best[0][0]))
            entities.append(dict(cls='Mars_Anchor_Route_EntityScript', at=[at[0], at[1], z], yaw=round(yaw, 3), props=props, note=aid))
        elif fam == 'H':
            n = nodes[anchor['node']]
            entities.append(dict(cls='Mars_Anchor_Hunt_EntityScript', at=list(n), yaw=0.0, props=dict(AnchorId=anchor_tag(aid), HomeRadiusCm=1000.0), note=aid))
            entities.append(dict(cls='Mars_Anchor_CourtNavField_EntityScript', at=list(n), yaw=0.0, props={}, note=aid))
        elif fam == 'S':
            m = mouths[aid]
            entities.append(dict(cls='Mars_Anchor_Spawn_EntityScript', at=[m['at'][0], m['at'][1], 0.0], yaw=round(m['yaw'], 3),
                                 props=dict(AnchorId=anchor_tag(aid), SpanCm=m['width'] * 100.0), note=aid))

    leaks = gate_leaks(up, entities) + gate_leaks(deep, entities, level_z=DEEP_Z)
    breaks = walk_breaks(d, up, deep, raf)
    ladder_errors = ladder_checks(d, up, deep, raf)
    level_grids = {DEEP_Z: deep, 0.0: up}
    if raf:
        level_grids[d['upper']['z']] = raf
    for lk in d.get('locks', []):
        kx, ky, kz = lk['keyAt']
        if cell_at(level_grids.get(kz, up), (kx, ky)) != 'floor':
            ladder_errors.append(lk['id'] + ': the key is not on a floor')
        lz = DEEP_Z if lk['lock']['level'] == 'deep' else 0.0
        if cell_at(level_grids[lz], tuple(lk['lock']['at'])) not in ('floor', 'low'):
            ladder_errors.append(lk['id'] + ': the lock is not on a floor')
    dx0, dy0, dx1, dy1 = d['deep']
    for r in ramps:  # a ramp outside the Deep's rect has nothing lining its sides below the floor slab
        for x, y in (r['start'], r['end']):
            if not (dx0 + r['width'] / 2 <= x <= dx1 - r['width'] / 2 and dy0 + r['width'] / 2 <= y <= dy1 - r['width'] / 2):
                breaks.append('ramp ' + r['link']['a'] + '-' + r['link']['b'] + ' leaves the Deep rect')
                break
    bypasses = [a for a in gate_leaks(up, entities, crawl_ok=True) if a not in leaks]
    result = dict(map=MAP, owner=OWN, boxes=boxes, starts=starts, entities=entities, lights=lights,
                  crawls=d['crawls'], rampDegrees=[round(r['degrees'], 1) for r in ramps], deviations=DEVIATIONS)
    summary = dict(boxes=len(boxes), starts=len(starts),
                   anchors=sum(1 for e in entities if e['cls'].startswith('Mars_Anchor_') and 'NavField' not in e['cls']),
                   navfields=sum(1 for e in entities if 'NavField' in e['cls']),
                   packs=sum(1 for e in entities if 'Backpack' in e['cls']),
                   ladders=sum(1 for e in entities if 'Ladder' in e['cls']), crawls=len(d['crawls']), lights=len(lights), gateLeaks=leaks, crawlBypasses=bypasses, walkBreaks=breaks, ladderErrors=ladder_errors,
                   rails=len(rails),
                   rampDegrees=result['rampDegrees'])
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
    for a in ea.get_all_level_actors():
        if OWN in [str(t) for t in a.tags]:
            ea.destroy_actor(a)
    ss = u.get_engine_subsystem(u.SubobjectDataSubsystem)

    def actor(cls, label, at=(0, 0, 0), yaw=0.0):
        a = ea.spawn_actor_from_class(cls, at if isinstance(at, u.Vector) else u.Vector(*at), u.Rotator(pitch=0, yaw=yaw, roll=0))
        a.set_actor_label('Warrens_' + label)
        a.tags = [u.Name(OWN)]
        a.set_folder_path('Warrens/' + label.split('_')[0])
        return a

    cube = u.load_asset(CUBE)
    assert cube, CUBE
    for kind, path in MATERIALS.items():
        values = [b for b in man['boxes'] if b['kind'] == kind]
        if not values:
            continue
        material = u.load_asset(path)
        assert material, path
        a = actor(u.Actor, 'Greybox_' + kind)
        a.root_component.set_mobility(u.ComponentMobility.STATIC)  # a static HISM cannot attach under a movable root
        h = ss.k2_gather_subobject_data_for_instance(a)[0]
        ch, reason = ss.add_new_subobject(u.AddNewSubobjectParams(parent_handle=h, new_class=u.HierarchicalInstancedStaticMeshComponent))
        c = u.SubobjectDataBlueprintFunctionLibrary.get_associated_object(u.SubobjectDataBlueprintFunctionLibrary.get_data(ch))
        assert c, str(reason)
        c.set_mobility(u.ComponentMobility.STATIC)
        c.set_static_mesh(cube)
        c.set_collision_profile_name('BlockAll')
        c.set_material(0, material)
        for b in values:
            c.add_instance(u.Transform(location=worldpos(u, b['centre']), rotation=u.Rotator(pitch=b['pitch'], yaw=b['yaw'], roll=0),
                                       scale=u.Vector(*b['size'])), world_space=True)
    for i, v in enumerate(man['lights']):
        intensity, radius, colour = LIGHT_KINDS[v['kind']]
        a = actor(u.PointLight, 'Light_' + v['kind'] + '_' + str(i), worldpos(u, v['at']))
        c = a.point_light_component
        c.set_mobility(u.ComponentMobility.STATIONARY)
        c.set_intensity(intensity)
        c.set_attenuation_radius(radius * 100.0)
        c.set_light_color(u.LinearColor(*colour))
    for v in man['starts']:
        a = actor(u.PlayerStart, 'Entrance_' + v['group'] + '_' + str(v['slot']), worldpos(u, v['at']), v['yaw'])
        a.set_editor_property('player_start_tag', u.Name(v['tag']))
    for i, v in enumerate(man['entities']):
        cls = u.load_class(None, '/Script/Angelscript.' + v['cls'])
        if not cls:
            raise RuntimeError('Missing gameplay class ' + v['cls'] + ' (has the script compiled?)')
        a = ea.spawn_actor_from_object(cls, worldpos(u, v['at']), u.Rotator(pitch=0, yaw=v['yaw'], roll=0))
        assert a, v['cls']
        a.tags = [u.Name(OWN)]
        a.set_actor_label('Warrens_' + v['cls'] + '_' + str(i))
        a.set_folder_path('Warrens/Gameplay')
        script = a.get_editor_property('_EntityScript')
        for key, value in v['props'].items():
            if isinstance(value, dict) and 'fields' in value:
                struct = script.get_editor_property(key)
                for field, field_value in value['fields'].items():
                    struct.set_editor_property(field, field_value)
                value = struct
            elif isinstance(value, dict) and 'enum' in value:
                enum_type = getattr(u, value['enum'][1:], None) or getattr(u, value['enum'])
                value = getattr(enum_type, value['value'].upper())
            elif isinstance(value, dict) and 'tag' in value:
                tag = u.GameplayTag()
                tag.import_text('(TagName="' + value['tag'] + '")')
                assert value['tag'] in tag.export_text(), 'gameplay tag ' + value['tag'] + ' is not registered'
                value = tag
            elif isinstance(value, str):
                value = u.Name(value)
            script.set_editor_property(key, value)
    mode = u.load_class(None, '/Script/Angelscript.Mars_Warrens_GameMode')
    assert mode, 'Mars_Warrens_GameMode has not compiled'
    world.get_world_settings().set_editor_property('default_game_mode', mode)
    # Lighting: no daylight. A faint cold ambient so unlit tunnels read as dark, not black, and fixed exposure so the
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
                       ('ambient_cubemap_intensity', .12), ('ambient_cubemap_tint', u.LinearColor(.55, .62, .8, 1)),
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
    record = dict(map=MAP, strandedItemsRemoved=stranded,
                  **{k: summary[k] for k in ('boxes', 'starts', 'anchors', 'navfields', 'packs', 'ladders', 'crawls', 'lights')})
    (OUT / 'warrens-built.json').write_text(json.dumps(record, indent=1), encoding='utf-8')
    print(json.dumps(record))


def audit():
    """Trace the saved collision along every walked link and ramp, check every start's capsule, check each crawl gap
    stops a standing chef and lets a crouched one through, validate the Jolt bake."""
    import unreal as u
    man, _ = manifest(write=False)
    d = load()
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
        paths.append((r['start'], r['end'], r['top'], r['bottom']))
    for walk in d.get('extraWalks', []):
        if 'pts' in walk:
            wz = DEEP_Z if walk.get('level') == 'deep' else 0.0
            paths += [(tuple(p), tuple(q), wz, wz) for p, q in zip(walk['pts'], walk['pts'][1:])]
    if d.get('upper'):
        uz = d['upper']['z']
        for walk in d['upper']['walkways']:
            paths += [(tuple(p), tuple(q), uz, uz) for p, q in zip(walk['pts'], walk['pts'][1:])]
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
        mx, my = (c['a'][0] + c['b'][0]) / 2, (c['a'][1] + c['b'][1]) / 2
        stands = capsule_blocked((mx, my, 0.77), 75)
        pack = capsule_blocked((mx, my, 0.72), 70)
        crouches = not capsule_blocked((mx, my, 0.55), 52.5)
        crawls_ok += 1 if stands and pack and crouches else 0
    # A low tunnel passes a standing chef along its whole length.
    low_blocked = []
    low = {tuple(sorted(pair)) for pair in d.get('lowLinks', [])}
    for link in d['links']:
        if tuple(sorted((link['a'], link['b']))) not in low:
            continue
        pts = polyline(d, link)
        for p, q in zip(pts, pts[1:]):
            seg = math.dist(p, q)
            for k in range(int(seg) + 1):
                t = 0.0 if seg == 0 else min(k / seg, 1.0)
                pt = (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t, 0.77)
                if capsule_blocked(pt, 75):
                    low_blocked.append([round(pt[0], 2), round(pt[1], 2)])
    jolt = u.get_editor_subsystem(u.Ck_JoltCook_EditorSubsystem_UE).validate_current_world()
    result = dict(samples=count, missing=len(missing), startsClear=clear, crawlsOk=crawls_ok, crawls=len(d['crawls']),
                  lowTunnelBlocked=len(low_blocked), jolt=bool(jolt), deviations=DEVIATIONS)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'warrens-audit.json').write_text(json.dumps(dict(result, missingSamples=missing[:200]), indent=1), encoding='utf-8')
    print(json.dumps(result))


if __name__ == '__main__':
    manifest()
