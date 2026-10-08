"""Mars cooking station "hearth" (station_spec.STATIONS["hearth"]): the stove under FryPan_Mars_SM on the searing table.

Builds from fixed seeds, in Blender 5.2 headless:
  Hearth_Mars_SM     slots Stone / Iron / Ember   chiselled basalt slab (56 x 56 x 6, eight chipped blocks round an
                                                  octagonal hole, draught vents with glowing coals at +X / +Y / -X),
                                                  the recessed iron fire bowl (lathe, rolled lip, riveted band, iron
                                                  collar on the slab, three stub feet on the table), the iron trivet
                                                  (four bars from the band to a 4-sided ring, radius 22, top z 20) and
                                                  an iron tuyere on -Y whose funnel mouth takes the bellows nozzle
  EmberBed_Mars_SM   slots Ember / Iron           coal pile inside the bowl, same frame as the hearth: dished bed
                                                  (low on the axis, banked to ~9 cm at the wall), faceted coals and a
                                                  few iron clinkers. No collision.
  Bellows_Mars_SM    slots Wood / Iron / Rope     wood boards, pleated leather (Rope darkened), iron nozzle, studs,
                                                  hinge strap; pivot = the nozzle tip, nozzle along +Y, rests on the
                                                  table when placed at the hearth's SOCKET_Bellows (lowest z = -6)

Run (the scene is rebuilt from nothing every time; always absolute paths):
  blender -b --factory-startup --python D:\\Repo\\Mars\\Tools\\Blender\\mars_cooking\\build_station_hearth.py -- [--export] [--save] [--sheets]
    --export   FBX + JSON sidecar per prop into station_spec.EXPORT_DIR, HearthStation_Layout.json, then every FBX is
               re-imported (food_common.reimport_check) and checked (UVMap, Col, flat, UCX pieces)
    --sheets   review sheets into station_spec.REVIEW_DIR: Hearth / EmberBed / Bellows (iso, front, top) and
               HearthAssembly (iso, front, top, low) with FryPan_Mars_SM at scale 2.5 on SOCKET_Pan (imported for the
               render only, removed after), plus HearthAssembly_lowclose.png, a close low shot of the air gap
    --save     station_spec.BLEND_DIR/Station_Hearth.blend
Prints STATION_HEARTH_OK when every check passed (STATION_HEARTH_FAIL + the reasons otherwise).

Frames: centimetres, Blender axes (Z up); the sidecars and the layout JSON give Unreal local cm (Y mirrored). The hearth
and the ember bed pivot at the centre of the hearth's underside (the table top). The flame column: nothing of the
hearth or the ember bed sits inside r < 15 cm between z 8 (SOCKET_Flame) and the pan underside (z 20, SOCKET_Pan).
"""
import json
import math
import os
import sys
import time

import bpy
import numpy as np
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import station_common as sc   # noqa: E402

spec = sc.spec
fc = sc.fc

H = spec.PROPS["Hearth"]
E = spec.PROPS["EmberBed"]
B = spec.PROPS["Bellows"]

PAN_FBX = os.path.join(spec.base.EXPORT_DIR, "FryPan_Mars_SM.fbx")
PAN_SCALE = 2.5
TABLE_TOP = 70.0                       # constants_station::k_CounterHeight; PrepTable SOCKET_Stove (0, 0, 70)
STOVE_SOCKET = np.array([0.0, 0.0, TABLE_TOP])

# ---------------------------------------------------------------- dimensions (cm, hearth frame)
HALF = H["footprint_cm"] * 0.5         # 28
SLAB_TOP = H["slab_height_cm"]         # 6
RIM_Z = H["firebowl_rim_cm"]           # 14
RING_R = H["trivet_ring_radius_cm"]    # 22
RING_TOP = H["trivet_top_cm"]          # 20 = SOCKET_Pan
RING_HALF = 0.6                        # 4-sided ring tube 1.2 cm, flat top
FLAME = np.array(H["sockets"]["Flame"], float)
PAN_SOCKET = np.array(H["sockets"]["Pan"], float)
BELLOWS_SOCKET = np.array(H["sockets"]["Bellows"], float)
CLEAR_R = 15.0                         # the flame column radius (30 cm across) that must stay empty above SOCKET_Flame
OCT_R = 18.8                           # slab hole: octagon inradius (clears the bowl's buried belly, r 17.4 at z 6)
VENT = 3.0                             # draught vent width between the split side blocks
VENT_SIDES = (0, 1, 2)                 # +X, +Y, -X (the -Y side carries the tuyere)
SEG = 16                               # bowl / band / collar / ring segments (bars at 45 + 90 k sit on vertices)

# fire bowl profile (r, z): inner floor -> inner wall -> rolled lip -> outer wall -> bottom. Rim top at z 14.
BOWL = [(0.0, 3.0), (8.0, 3.0), (12.0, 4.0), (14.8, 6.0), (16.4, 8.5), (17.8, 11.5), (18.6, 13.3), (19.0, RIM_Z),
        (21.2, RIM_Z), (21.6, 13.3), (21.0, 12.6), (20.2, 12.4), (19.4, 9.5), (17.8, 6.5), (15.2, 3.6), (12.0, 1.6),
        (9.0, 1.0), (0.0, 1.0)]
BOWL_TAGS = ["bowl_in"] * 6 + ["rim"] * 2 + ["iron"] * 7 + ["bowl_under"] * 2
BOWL_INNER_R_RIM = 19.0
BOWL_OUTER_R = 21.6
COLLAR = [(17.4, 5.5), (22.6, 5.5), (22.6, 6.5), (21.8, 7.2), (17.9, 7.2)]
BAND = [(18.9, 9.0), (19.7, 9.0), (20.6, 11.8), (19.8, 11.8)]
RING = [(RING_R - RING_HALF, RING_TOP - 2 * RING_HALF), (RING_R + RING_HALF, RING_TOP - 2 * RING_HALF),
        (RING_R + RING_HALF, RING_TOP), (RING_R - RING_HALF, RING_TOP)]
BAR_PATH = [(20.55, 9.3), (21.05, 11.9), (22.4, 13.05), (22.5, 15.0), (RING_R, RING_TOP - RING_HALF)]
BAR_HALF = 0.6
BAR_ANGLES = (45.0, 135.0, 225.0, 315.0)
# tuyere along -Y from inside the bowl wall to a funnel mouth round SOCKET_Bellows (r, s) with s along -Y
TUYERE_START_Y = -17.3
TUYERE = [(0.0, 0.0), (1.5, 0.0), (1.5, 14.6), (2.8, 17.6), (2.35, 17.6), (1.0, 15.4), (0.0, 15.4)]

# ember bed profile (r, z): low on the axis (under SOCKET_Flame), banked against the wall, bottom buried in the bowl
EMBER = [(0.0, 5.2), (6.0, 5.4), (11.0, 6.0), (14.8, 7.5), (17.1, 9.1), (15.6, 6.4), (12.5, 3.6), (0.0, 3.4)]
EMBER_TOP = 5                          # the first five profile points are the visible top
EMBER_SEG = 10

# bellows (cm, pivot = nozzle tip, nozzle along +Y, handles toward -Y, lowest z = -6 = the table under SOCKET_Bellows)
BELLOWS_LEN = B["length_cm"]           # 45
BOARD_YS = [-10.5, -12.5, -15.5, -19.0, -23.0, -27.5, -31.5, -34.5, -35.5]
BOARD_WS = [3.2, 4.8, 6.6, 8.0, 8.8, 8.6, 7.0, 4.2, 2.2]
BOARD_T = 1.2
BOTTOM_Z = -6.0
NOZZLE_BASE_Y = -9.6

LOW_VIEW = (0.35, 1.0, 0.47)           # review: low side view under the pan edge, over the rim, onto the coals
CHIP_SRGB = (84, 62, 50)               # the warm chips on the dark basalt (station_spec PALETTE note)


# ---------------------------------------------------------------- small geometry helpers (cm)
def _n(v):
    v = np.asarray(v, float)
    return v / max(np.linalg.norm(v), 1e-12)


def ccw(poly):
    p = np.asarray(poly, float)
    area = 0.5 * np.sum(p[:, 0] * np.roll(p[:, 1], -1) - np.roll(p[:, 0], -1) * p[:, 1])
    return p if area > 0 else p[::-1].copy()


def inset_convex(poly, d):
    """Offset every edge of a convex polygon inward by d; None if an edge flips (the inset collapsed it)."""
    p = ccw(poly)
    n = len(p)
    lines = []
    for i in range(n):
        e = _n(p[(i + 1) % n] - p[i])
        lines.append((p[i] + np.array([-e[1], e[0]]) * d, e))
    out = []
    for i in range(n):
        (p1, d1), (p2, d2) = lines[i - 1], lines[i]
        m = np.array([d1, -d2]).T
        if abs(np.linalg.det(m)) < 1e-9:
            out.append(p2)
        else:
            t = np.linalg.solve(m, p2 - p1)[0]
            out.append(p1 + d1 * t)
    out = np.array(out)
    for i in range(n):
        if np.dot(out[(i + 1) % n] - out[i], p[(i + 1) % n] - p[i]) <= 0.0:
            return None
    return out


def offset_vertices(p, d):
    """Move each vertex of a CCW polygon inward along its bisector normal by d (keeps the vertex count)."""
    n = len(p)
    out = []
    for i in range(n):
        e0 = _n(p[i] - p[i - 1])
        e1 = _n(p[(i + 1) % n] - p[i])
        nv = _n(np.array([-e0[1], e0[0]]) + np.array([-e1[1], e1[0]]))
        out.append(p[i] + nv * d)
    return np.array(out)


def rot_z(v, deg):
    a = math.radians(deg)
    r = np.array([[math.cos(a), -math.sin(a), 0.0], [math.sin(a), math.cos(a), 0.0], [0.0, 0.0, 1.0]])
    return np.asarray(v, float) @ r.T


def rot2(p, deg):
    a = math.radians(deg)
    r = np.array([[math.cos(a), -math.sin(a)], [math.sin(a), math.cos(a)]])
    return np.asarray(p, float) @ r.T


def axis_frame(axis):
    a = _n(axis)
    helper = np.array([0.0, 0.0, 1.0]) if abs(a[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = _n(np.cross(helper, a))
    w = np.cross(a, u)
    return u, w, a


def place_on_axis(v_local, origin, axis, phase_deg=0.0):
    """Local (x, y, z) with z along axis -> world; phase spins the local XY about the axis first."""
    v = rot_z(v_local, phase_deg)
    u, w, a = axis_frame(axis)
    return np.asarray(origin, float) + v[:, 0:1] * u + v[:, 1:2] * w + v[:, 2:3] * a


def lathe_closed(profile, segments, phase_deg=0.0):
    """Revolve a CLOSED (r, z) polygon (a hoop / band / collar). Face order: profile edge i, then segment."""
    m = len(profile)
    verts = []
    for r, z in profile:
        for s in range(segments):
            a = math.radians(phase_deg) + math.tau * s / segments
            verts.append((r * math.cos(a), r * math.sin(a), z))
    faces = []
    for i in range(m):
        i2 = (i + 1) % m
        for s in range(segments):
            s2 = (s + 1) % segments
            faces.append([i * segments + s, i2 * segments + s, i2 * segments + s2, i * segments + s2])
    return np.array(verts, float), faces


def icosahedron():
    t = (1.0 + 5 ** 0.5) / 2.0
    v = np.array([[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t],
                  [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]], float)
    v /= np.linalg.norm(v, axis=1, keepdims=True)
    f = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6],
         [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10],
         [8, 6, 7], [9, 8, 1]]
    return v, f


def octahedron():
    v = np.array([[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]], float)
    f = [[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]]
    return v, f


def lump(center, size, rng, jitter=0.22, coarse=False):
    """A faceted coal / clinker: a jittered icosahedron (20 tris) or a lopsided octahedron (coarse, 8 tris) scaled
    to size (x, y, z full extents) and yawed."""
    if coarse:
        v, f = octahedron()
        v = v + rng.uniform(-0.28, 0.28, size=v.shape)
    else:
        v, f = icosahedron()
    v = v * (1.0 + rng.uniform(-jitter, jitter, size=(len(v), 1)))
    v = v * (np.asarray(size, float) * 0.5)
    v = rot_z(v, rng.uniform(0, 360)) + np.asarray(center, float)
    return v, f


def rivet(center, normal, rng, r=0.55, h=0.5, segments=6):
    """A faceted dome rivet head (36 tris) on a surface; its base sinks 0.3 cm into the surface."""
    v, f = fc.lathe([(0.0, h), (0.7 * r, 0.72 * h), (r, 0.08), (0.0, -0.3)], segments)
    return place_on_axis(v, center, normal, rng.uniform(0, 60)), f


def bar_along(points, half, radial):
    """A square-section bar (half size) through 3D points; the section keeps one face toward `radial`."""
    pts = [np.asarray(p, float) for p in points]
    rings = []
    for i, p in enumerate(pts):
        if i == 0:
            t = _n(pts[1] - pts[0])
        elif i == len(pts) - 1:
            t = _n(pts[-1] - pts[-2])
        else:
            t = _n(_n(pts[i] - pts[i - 1]) + _n(pts[i + 1] - pts[i]))
        w = _n(np.cross(t, radial))
        u = np.cross(w, t)
        rings.append(np.array([p + u * half + w * half, p - u * half + w * half, p - u * half - w * half,
                               p + u * half - w * half]))
    return fc.loft(rings)


class Parts:
    """Accumulates (verts, faces) with a slot index, a tag and a group id per face."""

    def __init__(self):
        self.v, self.f, self.slot, self.tag, self.group = [], [], [], [], []
        self.base = 0
        self.next_group = 0

    def add(self, verts, faces, slot, tag, group=None):
        verts = np.asarray(verts, float)
        tags = tag if isinstance(tag, (list, tuple)) else [tag] * len(faces)
        assert len(tags) == len(faces)
        if group is None:
            group = self.next_group
            self.next_group += 1
        self.v.append(verts)
        self.f.extend([[self.base + int(i) for i in face] for face in faces])
        self.slot.extend([slot] * len(faces))
        self.tag.extend(tags)
        self.group.extend([group] * len(faces))
        self.base += len(verts)
        return group

    def build(self, name, slots):
        verts = np.concatenate(self.v)
        obj = sc.new_object(name, verts, self.f, slots=slots, face_slots=self.slot)
        if len(obj.data.polygons) != len(self.f):
            raise RuntimeError("%s: mesh.validate dropped faces (%d -> %d)" % (name, len(self.f), len(obj.data.polygons)))
        return obj


# ---------------------------------------------------------------- the hearth
def stone_block(parts, poly, z0, z1, rng, group):
    """One chiselled basalt block: a convex prism with chipped vertical corners, a hand-cut top chamfer with dropped
    chips and a fan-faceted top (the centre vertex sits a touch off the plane so the top reads chiselled)."""
    p = inset_convex(poly, 0.18)                          # mortar joint
    n0 = len(p)
    pts, pair = [], []
    for i in range(n0):
        prv, cur, nxt = p[i - 1], p[i], p[(i + 1) % n0]
        l0, l1 = np.linalg.norm(prv - cur), np.linalg.norm(nxt - cur)
        if rng.uniform() < 0.6:
            c = min(rng.uniform(0.7, 2.3), 0.3 * l0, 0.3 * l1)
            pts.append(cur + (prv - cur) / l0 * c)
            pts.append(cur + (nxt - cur) / l1 * c)
            pair += [i, i]
        else:
            pts.append(cur)
            pair.append(-1)
    pts = np.array(pts)
    n = len(pts)
    centroid = pts.mean(axis=0)
    ch = rng.uniform(0.45, 0.85)
    top = inset_convex(pts, ch)
    if top is None:
        top = centroid + (pts - centroid) * 0.93
    top = top + rng.uniform(-0.1, 0.1, size=top.shape)
    zt = z1 + rng.uniform(-0.12, 0.0, n)
    dropped = rng.uniform(size=n) < 0.4
    zt[dropped] -= rng.uniform(0.35, 1.1, int(dropped.sum()))
    top[dropped] += (centroid - top[dropped]) * 0.07
    mid = pts + rng.uniform(-0.12, 0.12, size=pts.shape)
    zm = z1 - ch + rng.uniform(-0.1, 0.1, n)
    verts = np.concatenate([np.column_stack([pts, np.full(n, z0)]), np.column_stack([mid, zm]),
                            np.column_stack([top, zt]),
                            [[centroid[0] + rng.uniform(-2, 2), centroid[1] + rng.uniform(-2, 2),
                              z1 - rng.uniform(0.05, 0.4)]]])
    faces, tags = [list(range(n))[::-1]], ["bottom"]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
        tags.append("chip" if pair[i] >= 0 and pair[i] == pair[j] else "side")
        faces.append([n + i, n + j, 2 * n + j, 2 * n + i])
        tags.append("chip" if dropped[i] or dropped[j] else "chamfer")
        faces.append([2 * n + i, 2 * n + j, 3 * n])
        tags.append("top")
    parts.add(verts, faces, 0, tags, group)


def slab_blocks(parts, rng):
    h, a = OCT_R, OCT_R * math.tan(math.pi / 8.0)
    corner = [(h, a), (HALF, a), (HALF, HALF), (a, HALF), (a, h)]
    for k in range(4):
        polys = [corner]
        if k in VENT_SIDES:
            v = VENT * 0.5
            polys += [[(h, v), (HALF, v), (HALF, a), (h, a)], [(h, -a), (HALF, -a), (HALF, -v), (h, -v)]]
        else:
            polys += [[(h, -a), (HALF, -a), (HALF, a), (h, a)]]
        for poly in polys:
            stone_block(parts, rot2(poly, 90.0 * k), 0.0, SLAB_TOP - rng.uniform(0.0, 0.12), rng, parts.next_group)
            parts.next_group += 1


def build_hearth(rng):
    parts = Parts()
    slab_blocks(parts, rng)
    # the fire bowl (Iron), its faces tagged per profile band
    v, f = fc.lathe(BOWL, SEG, twist_seed=11, jitter=0.12)
    parts.add(v, f, 1, [BOWL_TAGS[i // SEG] for i in range(len(f))])
    # three stub feet on the table under the bowl (its contact through the slab hole)
    for k in range(3):
        ang = math.radians(90.0 + 120.0 * k)
        fv, ff = sc.chipped_block((10.5 * math.cos(ang), 10.5 * math.sin(ang), 1.1), (3.2, 3.2, 2.2), rng,
                                  chip=0.08, jitter_cm=0.1)
        fv[:, 2] = np.where(fv[:, 2] < 0.6, 0.0, fv[:, 2])
        parts.add(fv, ff, 1, "iron")
    # iron collar on the slab round the bowl, the riveted band, the trivet ring and its four bars
    parts.add(*lathe_closed(COLLAR, SEG), 1, "iron")
    parts.add(*lathe_closed(BAND, SEG), 1, "band")
    parts.add(*lathe_closed(RING, SEG), 1, "trivet")
    for ang in BAR_ANGLES:
        a = math.radians(ang)
        d = np.array([math.cos(a), math.sin(a), 0.0])
        pts = [d * r + np.array([0.0, 0.0, z]) for r, z in BAR_PATH]
        parts.add(*bar_along(pts, BAR_HALF, d), 1, "trivet")
        # the rivet that fixes the bar to the band
        rr, rz = 20.72 + BAR_HALF, 10.6
        parts.add(*rivet(d * rr + np.array([0, 0, rz]), d * 0.977 + np.array([0, 0, -0.213]), rng), 1, "rivet")
    # band rivets (12) and collar rivets (7, none where the tuyere crosses the collar)
    band_n = _n(np.array([2.8, -0.9]))
    for k in range(12):
        a = math.radians(30.0 * k)
        d = np.array([math.cos(a), math.sin(a), 0.0])
        parts.add(*rivet(d * 20.15 + np.array([0, 0, 10.4]), d * band_n[0] + np.array([0, 0, band_n[1]]), rng),
                  1, "rivet")
    for k in range(8):
        ang = 45.0 * k
        if abs(ang - 270.0) < 1.0:
            continue
        a = math.radians(ang)
        d = np.array([math.cos(a), math.sin(a), 0.0])
        parts.add(*rivet(d * 20.0 + np.array([0, 0, COLLAR[-1][1]]), (0, 0, 1), rng, r=0.5, h=0.42), 1, "rivet")
    # the tuyere: an iron pipe from inside the bowl wall out over the -Y block, funnel mouth round SOCKET_Bellows
    origin = np.array([0.0, TUYERE_START_Y, BELLOWS_SOCKET[2]])
    axis = np.array([0.0, -1.0, 0.0])
    tv, tf = fc.lathe(TUYERE, 8)
    parts.add(place_on_axis(tv, origin, axis, 22.5), tf, 1, "iron")
    flv, flf = lathe_closed([(1.4, 6.0), (2.1, 6.0), (2.1, 6.7), (1.4, 6.7)], 8)
    parts.add(place_on_axis(flv, origin, axis, 22.5), flf, 1, "iron")
    leg_y = TUYERE_START_Y - 14.2
    parts.add(*sc.rod((0.0, leg_y, 0.0), (0.0, leg_y, BELLOWS_SOCKET[2] - 1.2), 0.55, sides=4, phase=math.pi / 4),
              1, "iron")
    # glowing coals deep in the three draught vents (the glow under the bowl on board 2)
    for k in VENT_SIDES:
        a = math.radians(90.0 * k)
        d = np.array([math.cos(a), math.sin(a), 0.0])
        s = np.array([-math.sin(a), math.cos(a), 0.0])
        for rr, lat, size in ((19.6, 0.4, (2.2, 1.6, 1.5)), (21.7, -0.35, (1.8, 1.4, 1.2)), (23.4, 0.2, (1.4, 1.2, 0.9))):
            lv, lf = lump(d * rr + s * lat + np.array([0, 0, size[2] * 0.45]), size, rng, jitter=0.15)
            lv[:, 2] = np.maximum(lv[:, 2], 0.0)
            parts.add(lv, lf, 2, "ember")
    obj = parts.build("Hearth_Mars_SM", ("Stone", "Iron", "Ember"))
    return obj, parts


def paint_hearth(obj, parts, rng):
    stone, stone_l, chip = sc.palette("Stone"), sc.palette("StoneLight"), fc.srgb(*CHIP_SRGB)
    iron, ember = sc.palette("Iron"), sc.palette("Ember")
    tone = {g: rng.uniform(0.82, 1.18) for g in set(parts.group)}
    warm = {g: rng.uniform(0.0, 0.35) for g in set(parts.group)}
    centres = fc.face_centers_cm(obj)
    rgb = []
    for i, (tag, g) in enumerate(zip(parts.tag, parts.group)):
        t = tone[g]
        if tag == "top":
            c = (stone * 0.3 + stone_l * 0.7) * t
            c = c * (1.0 - warm[g] * 0.3) + chip * warm[g] * 0.3
        elif tag == "side":
            c = stone * t
        elif tag == "chamfer":
            c = (stone_l * 0.5 + chip * 0.5) * t
        elif tag == "chip":
            c = chip * t * 1.05
        elif tag == "bottom":
            c = stone * 0.5
        elif tag == "bowl_in":
            z = centres[i][2]
            heat = float(np.clip((11.0 - z) / 6.0, 0.0, 1.0))
            c = iron * 0.75 * (1.0 - 0.25 * heat) + ember * 0.07 * heat
        elif tag == "rim":
            c = iron * 1.45
        elif tag == "bowl_under":
            c = iron * 0.6
        elif tag == "band":
            c = iron * 1.2
        elif tag == "rivet":
            c = iron * 1.8
        elif tag == "trivet":
            c = iron * 1.15
        elif tag == "ember":
            c = ember * rng.uniform(0.8, 1.1)
        else:
            c = iron
        rgb.append(c)
    fc.paint(obj, np.array(rgb), variation=0.07, seed=5)


# ---------------------------------------------------------------- the ember bed
def bed_height(r):
    top = EMBER[:EMBER_TOP]
    return float(np.interp(r, [p[0] for p in top], [p[1] for p in top]))


def build_ember_bed(rng):
    parts = Parts()
    v, f = fc.lathe(EMBER, EMBER_SEG)
    # lumpy top: jitter the inner top rings (not the wall-embedded edge ring, not the buried underside)
    ring_of = np.repeat(np.arange(len(EMBER)), [1 if p[0] < 1e-6 else EMBER_SEG for p in EMBER])
    for k in range(1, EMBER_TOP - 1):
        m = ring_of == k
        v[m, 0:2] *= (1.0 + rng.uniform(-0.05, 0.05, size=(int(m.sum()), 1)))
        v[m, 2] += rng.uniform(-0.15, 0.15, size=int(m.sum()))
    parts.add(v, f, 0, ["bed_wall" if i // EMBER_SEG >= EMBER_TOP - 1 else "bed" for i in range(len(f))])
    # coals: low on the axis (tops <= 7.9 inside r 15, the flame column), banked bigger against the wall
    placed = []
    tries = 0
    while len(placed) < 54 and tries < 40000:
        tries += 1
        r = math.sqrt(rng.uniform(0.0, 1.0)) * 16.2
        a = rng.uniform(0.0, math.tau)
        sx = rng.uniform(3.0, 5.0)
        size = np.array([sx, sx * rng.uniform(0.7, 1.0), rng.uniform(1.5, 2.5)])
        if r > 14.6:
            size *= 1.1
        c = np.array([r * math.cos(a), r * math.sin(a), bed_height(r) + size[2] * 0.12])
        if any(np.linalg.norm(c[:2] - q[:2]) < 0.33 * (sx + s) for q, s in placed):
            continue
        lv, lf = lump(c, size, rng, coarse=True)
        rr = np.hypot(lv[:, 0], lv[:, 1])
        if np.any((rr < CLEAR_R) & (lv[:, 2] > 7.9)) or rr.max() > 17.0:
            continue
        placed.append((c, sx))
        parts.add(lv, lf, 0, "coal")
    # a few iron clinkers among the coals
    n_cl = 0
    while n_cl < 5 and tries < 30000:
        tries += 1
        r = rng.uniform(4.0, 14.5)
        a = rng.uniform(0.0, math.tau)
        size = np.array([rng.uniform(1.6, 2.4), rng.uniform(1.3, 2.0), rng.uniform(0.8, 1.2)])
        c = np.array([r * math.cos(a), r * math.sin(a), bed_height(r) + size[2] * 0.1])
        lv, lf = lump(c, size, rng, coarse=True)
        rr = np.hypot(lv[:, 0], lv[:, 1])
        if np.any((rr < CLEAR_R) & (lv[:, 2] > 7.9)):
            continue
        parts.add(lv, lf, 1, "clinker")
        n_cl += 1
    obj = parts.build("EmberBed_Mars_SM", ("Ember", "Iron"))
    return obj, parts, len(placed), n_cl


def paint_ember_bed(obj, parts, rng):
    ember, iron = sc.palette("Ember"), sc.palette("Iron")
    hot = fc.srgb(255, 176, 64)
    deep = fc.srgb(196, 52, 14)
    centres = fc.face_centers_cm(obj)
    tone = {g: rng.uniform(0.0, 1.0) for g in set(parts.group)}
    rgb = []
    for i, (tag, g) in enumerate(zip(parts.tag, parts.group)):
        if tag == "coal":
            k = tone[g]
            c = deep * (1.0 - k) + ember * k if k < 0.6 else ember * (1.6 - k) + hot * (k - 0.6) * 1.0
            c = c * rng.uniform(0.85, 1.1)
        elif tag == "bed":
            r = float(np.hypot(*centres[i][:2]))
            k = float(np.clip(1.0 - r / 17.0, 0.0, 1.0))
            c = (deep * (1.0 - k) + ember * k) * rng.uniform(0.2, 0.32)
        elif tag == "bed_wall":
            c = deep * 0.3
        else:                       # clinker
            c = iron * rng.uniform(0.7, 1.2)
        rgb.append(c)
    fc.paint(obj, np.array(rgb), variation=0.05, seed=9, cavity_darken=0.25)


# ---------------------------------------------------------------- the bellows
def top_board_z(y):
    """Underside of the top board: hinged low at the nose, opening toward the handles."""
    return 2.2 + (BOARD_YS[0] - y) * (3.6 / (BOARD_YS[0] - BOARD_YS[-1]))


def board_outline():
    right = [(w, y) for w, y in zip(BOARD_WS, BOARD_YS)]
    left = [(-w, y) for w, y in reversed(list(zip(BOARD_WS, BOARD_YS)))]
    return ccw(right + left)


def build_bellows(rng):
    parts = Parts()
    out = board_outline()
    inset = inset_convex(out, 0.5)
    # boards: bottom ring, edge ring below the bevel, inset top ring
    for which in ("bottom", "top"):
        if which == "bottom":
            z0 = np.full(len(out), BOTTOM_Z)
        else:
            z0 = np.array([top_board_z(y) for y in out[:, 1]])
        zi = np.array([top_board_z(y) for y in inset[:, 1]]) if which == "top" else np.full(len(inset), BOTTOM_Z)
        rings = [np.column_stack([out, z0]), np.column_stack([out, z0 + BOARD_T - 0.35]),
                 np.column_stack([inset, zi + BOARD_T])]
        v, f = fc.loft(rings)
        k = len(out)
        tags = ["board_edge"] * (2 * k) + ["board_under", "board_top"]
        tags[k:2 * k] = ["board_bevel"] * k
        v = v + np.column_stack([rng.uniform(-0.06, 0.06, size=(len(v), 2)), np.zeros(len(v))])
        if which == "bottom":
            v[:len(out), 2] = BOTTOM_Z
        parts.add(v, f, 0, tags)
    # pleated leather between the boards
    bot_z, rings = BOTTOM_Z + BOARD_T, []
    for t, d in ((0.0, 0.6), (0.25, 1.9), (0.5, 0.35), (0.75, 1.9), (1.0, 0.6)):
        p = offset_vertices(out, d)
        p[:, 0] = np.sign(p[:, 0]) * np.maximum(np.abs(p[:, 0]), 0.4)
        z = bot_z * (1.0 - t) + np.array([top_board_z(y) for y in p[:, 1]]) * t
        rings.append(np.column_stack([p, z]))
    v, f = fc.loft(rings)
    k = len(out)
    tags = []
    for band in range(4):
        tags += ["leather_fold" if band in (0, 3) else "leather"] * k
    tags += ["leather_fold", "leather_fold"]
    parts.add(v, f, 2, tags)
    # nose block between the boards, holding the nozzle
    nv, nf = sc.chipped_block((0.0, -11.6, -1.2), (7.6, 5.0, 7.6), rng, chip=0.05, jitter_cm=0.08)
    parts.add(nv, nf, 0, "board_edge")
    # iron nozzle: collar at the block, cone to the tip at the origin (+Y)
    prof = [(0.0, 0.0), (2.4, 0.0), (2.4, 1.2), (1.75, 1.4), (1.2, 6.0), (0.85, 9.0), (0.95, 9.3), (0.55, 9.6),
            (0.0, 9.6)]
    v, f = fc.lathe(prof, 8)
    parts.add(place_on_axis(v, (0.0, NOZZLE_BASE_Y, 0.0), (0.0, 1.0, 0.0), 22.5), f, 1, "nozzle")
    # handles: each board runs on into a hand-cut grip with a knob
    for which in ("top", "bottom"):
        rings = []
        for y, hw, hh in ((-33.5, 1.6, 0.6), (-40.0, 1.2, 0.6), (-42.5, 1.9, 0.6), (-BELLOWS_LEN, 1.3, 0.55)):
            if which == "top":
                z = top_board_z(-33.5) + BOARD_T * 0.5 + (-33.5 - y) * 0.2
                hh2 = hh + (0.15 if y < -41 else 0.0)
            else:
                z = BOTTOM_Z + 0.6
                hh2 = 0.6
            rings.append(fc.ring((0.0, y, z), hw, hh2, 6, (1.0, 0.0, 0.0), (0.0, 0.0, 1.0), math.pi / 6))
        v, f = fc.loft([r[::-1] for r in rings])
        if which == "bottom":
            v[:, 2] = np.maximum(v[:, 2], BOTTOM_Z)
        parts.add(v, f, 0, "handle")
    # iron hinge strap over the top board's nose, studs round the top board
    slope = math.atan(3.6 / (BOARD_YS[0] - BOARD_YS[-1]))
    strap_w = 2.0 * (float(np.interp(-14.0, BOARD_YS[::-1], BOARD_WS[::-1])) + 0.15)
    sv, sf = sc.box((0.0, 0.0, 0.0), (strap_w, 1.4, 0.45))
    rx = np.array([[1, 0, 0], [0, math.cos(slope), -math.sin(slope)], [0, math.sin(slope), math.cos(slope)]])
    ys = -14.0
    sv = sv @ rx.T + np.array([0.0, ys, top_board_z(ys) + BOARD_T + 0.12])
    parts.add(sv, sf, 1, "iron")
    nrm = _n(np.array([0.0, math.sin(slope), math.cos(slope)]))
    for x, y in ((5.4, -19.0), (-5.4, -19.0), (6.6, -26.0), (-6.6, -26.0), (5.0, -31.5), (-5.0, -31.5)):
        parts.add(*rivet((x, y, top_board_z(y) + BOARD_T), nrm, rng, r=0.5, h=0.4), 1, "rivet")
    obj = parts.build("Bellows_Mars_SM", ("Wood", "Iron", "Rope"))
    return obj, parts


def paint_bellows(obj, parts, rng):
    wood, wood_d, iron = sc.palette("Wood"), sc.palette("WoodDark"), sc.palette("Iron")
    leather = sc.palette("Rope") * 0.32
    rgb = []
    for tag in parts.tag:
        c = {"board_top": wood, "board_bevel": wood * 0.8 + wood_d * 0.2, "board_edge": wood_d,
             "board_under": wood_d * 0.6, "handle": wood * 0.85 + wood_d * 0.15, "leather": leather,
             "leather_fold": leather * 0.55, "nozzle": iron * 1.1, "iron": iron, "rivet": iron * 1.8}[tag]
        rgb.append(c)
    fc.paint(obj, np.array(rgb), variation=0.07, seed=13)


# ---------------------------------------------------------------- measurements + checks
def measure(hearth, ember, bellows):
    hv, ev, bv = fc.verts_cm(hearth), fc.verts_cm(ember), fc.verts_cm(bellows)
    m = {}
    hr = np.hypot(hv[:, 0], hv[:, 1])
    er = np.hypot(ev[:, 0], ev[:, 1])
    col_h = (hv[:, 2] > FLAME[2]) & (hv[:, 2] < RING_TOP + 0.5)
    col_e = ev[:, 2] > FLAME[2]
    m["clear_column_min_r_cm"] = float(min(hr[col_h].min(), er[col_e].min() if col_e.any() else 99.0))
    m["ember_top_max_cm"] = float(ev[:, 2].max())
    m["ember_top_in_column_cm"] = float(ev[er < CLEAR_R, 2].max())
    m["ember_top_on_axis_cm"] = float(ev[er < 4.0, 2].max())
    m["hearth_top_cm"] = float(hv[:, 2].max())
    m["hearth_min_z_cm"] = float(hv[:, 2].min())
    m["hearth_bounds_cm"] = [hv.min(axis=0).round(2).tolist(), hv.max(axis=0).round(2).tolist()]
    m["bellows_bounds_cm"] = [bv.min(axis=0).round(2).tolist(), bv.max(axis=0).round(2).tolist()]
    m["bellows_length_cm"] = float(bv[:, 1].max() - bv[:, 1].min())
    return m


def slab_extent(parts):
    v = np.concatenate(parts.v)
    stone_faces = [f for f, s in zip(parts.f, parts.slot) if s == 0]
    idx = sorted({i for f in stone_faces for i in f})
    sv = v[idx]
    return sv.min(axis=0), sv.max(axis=0)


# ---------------------------------------------------------------- review renders
def review_copy(obj, suffix="_Review"):
    """Unparented copy re-centred (XY centre 0, lowest z 0) so the shared review framing fits any pivot."""
    c = obj.copy()
    c.data = obj.data.copy()
    c.name = obj.name.replace("_Mars_SM", "") + suffix
    c.parent = None
    bpy.context.scene.collection.objects.link(c)
    frame_for_review(c, centre_xy=True)
    return c


def frame_for_review(obj, centre_xy):
    """fc.review_sheet aims at z = 0.45 x the largest extent above the origin, which suits standing props; move the
    mesh (review copies only) so its bounding-box middle sits there."""
    v = fc.verts_cm(obj)
    lo, hi = v.min(axis=0), v.max(axis=0)
    ext = float((hi - lo).max())
    shift = np.array([(lo[0] + hi[0]) * 0.5 if centre_xy else 0.0, (lo[1] + hi[1]) * 0.5 if centre_xy else 0.0,
                      (lo[2] + hi[2]) * 0.5 - 0.45 * ext])
    fc.set_verts_cm(obj, v - shift)


def remove_object(o):
    mesh = o.data if o.type == "MESH" else None
    bpy.data.objects.remove(o, do_unlink=True)
    if mesh is not None and mesh.users == 0:
        bpy.data.meshes.remove(mesh)


def import_pan():
    """FryPan_Mars_SM at scale 2.5, yawed 180 (handle toward the operator at -X), its underside on SOCKET_Pan."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=PAN_FBX)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    pan = meshes[0]
    for o in meshes[1:]:
        remove_object(o)
    pan.parent = None
    pan.data.transform(pan.matrix_world)
    pan.matrix_world = Matrix.Identity(4)
    v = fc.verts_cm(pan)
    raw = {"rim_r_cm": float(np.hypot(v[:, 0], v[:, 1])[v[:, 0] < 15.5].max()), "under_z_cm": float(v[:, 2].min())}
    underside = -raw["under_z_cm"] * PAN_SCALE
    v = rot_z(v * PAN_SCALE, 180.0) + np.array([0.0, 0.0, PAN_SOCKET[2] + underside])
    fc.set_verts_cm(pan, v)
    slots = np.empty(len(pan.data.polygons), dtype=np.int64)
    pan.data.polygons.foreach_get("material_index", slots)
    steel, grip = fc.srgb(118, 116, 112), fc.srgb(64, 46, 34)
    fc.paint(pan, np.array([steel if s == 0 else grip for s in slots]), variation=0.02)
    return pan, raw, underside


def join(objs, name):
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


def render_closeup(obj, path, view, target_cm, half_width_cm, size=(1800, 900)):
    """One workbench render of obj in place (no re-centring), for the low air-gap close-up."""
    scene = bpy.context.scene
    hidden = [o for o in scene.objects if o is not obj and o.type == "MESH"]
    hidden_state = [o.hide_render for o in hidden]
    cam_data = bpy.data.cameras.new("_CloseCam")
    cam_data.clip_start, cam_data.clip_end = 0.01, 100.0
    cam = bpy.data.objects.new("_CloseCam", cam_data)
    scene.collection.objects.link(cam)
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.filepath, scene.display.shading.color_type, scene.display.shading.light,
            scene.display.shading.show_cavity)
    try:
        for o in hidden:
            o.hide_render = True
        obj.hide_render = False
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "VERTEX"
        scene.display.shading.show_cavity = True
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        cam_data.lens = 50
        d = _n(view)
        dist = half_width_cm * 0.01 / math.tan(math.radians(19.8))
        target = np.asarray(target_cm, float) * 0.01
        fc._look_at(cam, tuple(target + d * dist), tuple(target))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
    finally:
        for o, hr in zip(hidden, hidden_state):
            o.hide_render = hr
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
         scene.render.filepath, scene.display.shading.color_type, scene.display.shading.light,
         scene.display.shading.show_cavity) = prev
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return path


def render_sheets(hearth, ember, bellows, fails):
    sheets = []
    for obj, stem in ((hearth, "Hearth"), (ember, "EmberBed"), (bellows, "Bellows")):
        c = review_copy(obj)
        sheets.append(fc.review_sheet([c], stem, views=spec.REVIEW_VIEWS, color="VERTEX"))
        remove_object(c)
    # the assembled station stove: hearth + ember bed + bellows at SOCKET_Bellows + the pan at scale 2.5 on SOCKET_Pan
    copies = []
    for obj, offset in ((hearth, (0, 0, 0)), (ember, (0, 0, 0)), (bellows, BELLOWS_SOCKET)):
        c = obj.copy()
        c.data = obj.data.copy()
        c.parent = None
        bpy.context.scene.collection.objects.link(c)
        c.data.transform(Matrix.Translation(tuple(np.asarray(offset, float) * 0.01)))
        copies.append(c)
    pan, raw, underside = import_pan()
    pv = fc.verts_cm(pan)
    pr = np.hypot(pv[:, 0], pv[:, 1])
    on_ring = (pr > RING_R - RING_HALF) & (pr < RING_R + RING_HALF)
    print("pan: raw rim r %.2f, raw underside z %.3f -> scaled underside depth %.3f; min z %.3f; min z over the ring "
          "%.3f (ring top %.1f)" % (raw["rim_r_cm"], raw["under_z_cm"], underside, pv[:, 2].min(),
                                     pv[on_ring, 2].min(), RING_TOP))
    if abs(pv[:, 2].min() - RING_TOP) > 0.01:
        fails.append("pan underside %.3f != ring top %.1f" % (pv[:, 2].min(), RING_TOP))
    bvv = fc.verts_cm(copies[2])
    print("assembled: bellows lowest z %.3f (table 0), pan rim max r %.1f, pan top z %.1f" % (
        bvv[:, 2].min(), pr[pv[:, 0] > -40].max(), pv[:, 2].max()))
    asm = join(copies + [pan], "HearthAssembly_Review")
    sheets.append(render_closeup(asm, os.path.join(spec.REVIEW_DIR, "HearthAssembly_lowclose.png"),
                                 LOW_VIEW, (0.0, 0.0, 12.0), 40.0))
    sheets.append(render_closeup(asm, os.path.join(spec.REVIEW_DIR, "HearthAssembly_operator.png"),
                                 (-1.0, -0.15, 0.85), (0.0, -10.0, 12.0), 70.0))
    # the low view looks under the pan edge and over the bowl rim onto the coals: a ray from under the pan's base edge
    # (r 23.75, z 20) over the rim (r 21.6, z 14) to the coals (z ~7) climbs 0.33..0.55 per unit, so the view is ~24 deg
    fc.VIEWS["low"] = LOW_VIEW
    frame_for_review(asm, centre_xy=False)
    sheets.append(fc.review_sheet([asm], "HearthAssembly", views=("iso", "front", "top", "low"), color="VERTEX"))
    remove_object(asm)
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)
    return sheets


# ---------------------------------------------------------------- layout
def ue(v):
    return [round(float(x), 3) for x in np.asarray(v, float) * fc.UE_MIRROR]


def write_layout(m, pan_underside_depth):
    pan_pivot = STOVE_SOCKET + PAN_SOCKET + np.array([0.0, 0.0, pan_underside_depth])
    burner_top_now = TABLE_TOP + 4.0 + 2.0          # Get_BurnerTop(): StoveHeight 4 + burner cylinder 0.02 * 100
    data = {
        "station": "hearth",
        "frame": "station frame of Mars_SearingStation_EntityScript, Unreal cm: operator at -X looking +X, table "
                 "centre at the origin, table top z = 70 (PrepTable SOCKET_Stove). Blender builder axes = Unreal with "
                 "Y mirrored.",
        "props": {
            "Hearth_Mars_SM": {"location_cm": ue(STOVE_SOCKET), "rotation_deg": [0, 0, 0], "scale": 1.0,
                               "note": "pivot = centre of the underside, rests on the table top"},
            "EmberBed_Mars_SM": {"location_cm": ue(STOVE_SOCKET), "rotation_deg": [0, 0, 0], "scale": 1.0,
                                 "note": "same frame as the hearth (no collision)"},
            "Bellows_Mars_SM": {"location_cm": ue(STOVE_SOCKET + BELLOWS_SOCKET), "rotation_deg": [0, 0, 0],
                                "scale": 1.0,
                                "note": "pivot = nozzle tip at the hearth's SOCKET_Bellows; unrotated its nozzle "
                                        "already points at the bowl (Unreal local -Y) and its underside rests on the "
                                        "table (lowest z = socket z - 6)"},
            "FryPan_Mars_SM": {"location_cm": ue(pan_pivot), "scale": PAN_SCALE,
                               "rotation_deg": [0, 0, 180],
                               "note": "pivot = cooking surface centre; its underside (%.2f cm below the pivot at "
                                       "scale 2.5) rests on the trivet ring top = hearth SOCKET_Pan. The yaw is the "
                                       "station's own (handle toward the operator); the trivet is symmetric."
                                       % pan_underside_depth},
        },
        "sockets_station_cm": {
            "Flame": ue(STOVE_SOCKET + FLAME),
            "Pan": ue(STOVE_SOCKET + PAN_SOCKET),
            "Bellows": ue(STOVE_SOCKET + BELLOWS_SOCKET),
        },
        "flame": {"socket_station_cm": ue(STOVE_SOCKET + FLAME), "up": "+Z",
                  "clear_column_diameter_cm": round(2.0 * m["clear_column_min_r_cm"], 2),
                  "clear_height_flame_to_pan_cm": round(RING_TOP - FLAME[2], 2),
                  "clear_height_ember_axis_to_pan_cm": round(RING_TOP - m["ember_top_on_axis_cm"], 2),
                  "trivet_ring_radius_cm": RING_R, "pan_base_radius_cm": round(spec.base.PAN_BASE_R * PAN_SCALE, 2),
                  "pan_rim_radius_cm": round(spec.base.PAN_RIM_R * PAN_SCALE, 2)},
        "entity_script": {
            "pan_underside_z_cm": TABLE_TOP + RING_TOP,
            "pan_pivot_z_cm": round(float(pan_pivot[2]), 3),
            "pan_underside_depth_scaled_cm": round(pan_underside_depth, 3),
            "current_formula": "Get_BurnerTop() + PanHoverAboveBurner + PanUndersideDepth * PanScale "
                               "= %.1f + 7.0 + 0.75 = %.2f" % (burner_top_now, burner_top_now + 7.0 + 0.75),
            "keep_blockout_burner_top": {"Get_BurnerTop": burner_top_now,
                                         "PanHoverAboveBurner": round(TABLE_TOP + RING_TOP - burner_top_now, 3)},
            "recommended": {"Get_BurnerTop": "TableHeight + 20.0 (the hearth's SOCKET_Pan z; replaces StoveHeight 4 + "
                                              "the 2 cm burner cylinder)",
                            "PanHoverAboveBurner": 0.0,
                            "result_pan_pivot_z": round(float(pan_pivot[2]), 3)},
            "tilt_note": "the ring sits under the pan's flat base (ring r 22 +- 0.6 < base r 23.75): a tilt about the "
                         "pan pivot drops the base edge by 23.75 * sin(tilt) (about 4.1 cm at 10 deg), so lift while "
                         "tilting or keep a small hover if the tilt must not cut into the ring visually; the trivet "
                         "has no collision (Hearth UCX = slab box + fire bowl box up to z 14)",
            "stove_blockout": "the hearth replaces the 50 x 50 x 4 stove slab and the burner cylinder blockout",
        },
    }
    return sc.layout_json("HearthStation_Layout", data), data


# ---------------------------------------------------------------- re-import check
def reimport(paths, want_ucx):
    fails = []
    for path in paths:
        before = set(bpy.data.objects)
        rep = fc.reimport_check(path)
        for o in [o for o in bpy.data.objects if o not in before]:
            bpy.data.objects.remove(o, do_unlink=True)
        name = os.path.splitext(os.path.basename(path))[0]
        main = [r for r in rep if not r["name"].startswith("UCX_")]
        ucx = [r for r in rep if r["name"].startswith("UCX_")]
        problems = []
        if len(main) != 1:
            problems.append("meshes %s" % [r["name"] for r in main])
        else:
            r = main[0]
            if r["uv_layers"] != ["UVMap"]:
                problems.append("uv %s" % r["uv_layers"])
            if "Col" not in r["colors"]:
                problems.append("colors %s" % r["colors"])
            if not r["flat"]:
                problems.append("not flat")
        if len(ucx) != want_ucx[name]:
            problems.append("ucx %d != %d" % (len(ucx), want_ucx[name]))
        print("REIMPORT %s %s ucx %s %s" % (name, json.dumps(main), [u["name"] for u in ucx],
                                           "ok" if not problems else "FAIL " + "; ".join(problems)))
        if problems:
            fails.append("%s reimport: %s" % (name, "; ".join(problems)))
    return fails


# ---------------------------------------------------------------- main
def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False})
    t0 = time.time()
    fc.ensure_dirs()
    fc.clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    fails = []

    hearth, hparts = build_hearth(np.random.default_rng(31))
    ember, eparts, n_coals, n_clinkers = build_ember_bed(np.random.default_rng(47))
    bellows, bparts = build_bellows(np.random.default_rng(53))
    paint_hearth(hearth, hparts, np.random.default_rng(7))
    paint_ember_bed(ember, eparts, np.random.default_rng(8))
    paint_bellows(bellows, bparts, np.random.default_rng(9))
    for o in (hearth, ember, bellows):
        fc.smart_uv(o)

    # sockets (Blender axes, cm) and collision
    for name, loc in H["sockets"].items():
        sc.add_socket(hearth, name, loc)
    sc.box_ucx(hearth, (0.0, 0.0, SLAB_TOP * 0.5), (2 * HALF, 2 * HALF, SLAB_TOP))
    sc.box_ucx(hearth, (0.0, 0.0, (SLAB_TOP + RIM_Z) * 0.5), (2 * BOWL_OUTER_R, 2 * BOWL_OUTER_R, RIM_Z - SLAB_TOP))
    bv = fc.verts_cm(bellows)
    body_lo = np.array([bv[:, 0].min(), bv[:, 1].min(), BOTTOM_Z])
    body_hi = np.array([bv[:, 0].max(), NOZZLE_BASE_Y, bv[:, 2].max()])
    sc.box_ucx(bellows, (body_lo + body_hi) * 0.5, body_hi - body_lo)
    sc.box_ucx(bellows, (0.0, NOZZLE_BASE_Y * 0.5, 0.0), (5.0, -NOZZLE_BASE_Y, 5.0))

    # measurements + checks
    m = measure(hearth, ember, bellows)
    slo, shi = slab_extent(hparts)
    m["slab_bounds_cm"] = [slo.round(2).tolist(), shi.round(2).tolist()]
    m["slab_top_cm"] = float(shi[2])
    print("measure", json.dumps(m))
    for obj, key in ((hearth, "Hearth"), (ember, "EmberBed"), (bellows, "Bellows")):
        tris = fc.tri_count(obj)
        print("%-18s tris %5d / %d" % (obj.name, tris, spec.PROPS[key]["tris_max"]))
        if tris > spec.PROPS[key]["tris_max"]:
            fails.append("%s tris %d > %d" % (obj.name, tris, spec.PROPS[key]["tris_max"]))
    if m["clear_column_min_r_cm"] < CLEAR_R:
        fails.append("flame column: something at r %.2f < %.1f above z 8" % (m["clear_column_min_r_cm"], CLEAR_R))
    if m["ember_top_in_column_cm"] > FLAME[2]:
        fails.append("ember above SOCKET_Flame inside the column: %.2f" % m["ember_top_in_column_cm"])
    if abs(m["hearth_top_cm"] - RING_TOP) > 1e-3:
        fails.append("hearth top %.3f != trivet top %.1f" % (m["hearth_top_cm"], RING_TOP))
    if abs(m["hearth_min_z_cm"]) > 1e-3:
        fails.append("hearth min z %.3f != 0" % m["hearth_min_z_cm"])
    if np.abs(slo[:2]).max() > HALF + 0.05 or np.abs(shi[:2]).max() > HALF + 0.05:
        fails.append("slab outside the 56 cm footprint %s %s" % (slo, shi))
    if abs(m["bellows_length_cm"] - BELLOWS_LEN) > 0.3:
        fails.append("bellows length %.2f != %.1f" % (m["bellows_length_cm"], BELLOWS_LEN))
    if abs(bv[:, 2].min() + BELLOWS_SOCKET[2]) > 1e-3 or abs(bv[:, 1].max()) > 1e-3:
        fails.append("bellows rest / tip off: min z %.3f max y %.3f" % (bv[:, 2].min(), bv[:, 1].max()))
    print("ember bed: %d coals, %d clinkers" % (n_coals, n_clinkers))

    paths, layout = [], None
    pan_underside_depth = spec.base.PAN_THICK * PAN_SCALE
    if args["export"]:
        common = {"station": "hearth", "frame": "hearth frame: centre of the hearth underside = the table top"}
        hx = dict(common, slab_height_cm=round(m["slab_top_cm"], 3), slab_footprint_cm=2 * HALF,
                  firebowl_rim_cm=RIM_Z, firebowl_inner_radius_cm=BOWL_INNER_R_RIM,
                  firebowl_outer_radius_cm=BOWL_OUTER_R, firebowl_floor_cm=BOWL[0][1],
                  trivet_ring_radius_cm=RING_R, trivet_ring_tube_cm=2 * RING_HALF, trivet_top_cm=RING_TOP,
                  trivet_bars=len(BAR_ANGLES), trivet_bar_angles_deg=list(BAR_ANGLES),
                  flame_socket_cm=float(FLAME[2]),
                  clear_column_diameter_cm=round(2.0 * m["clear_column_min_r_cm"], 2),
                  clear_height_flame_to_pan_cm=round(RING_TOP - FLAME[2], 2),
                  clear_height_ember_to_pan_cm=round(RING_TOP - m["ember_top_on_axis_cm"], 2),
                  clear_height_ember_bank_to_pan_cm=round(RING_TOP - m["ember_top_max_cm"], 2),
                  pan_scale=PAN_SCALE, pan_pivot_above_socket_pan_cm=pan_underside_depth,
                  tuyere="iron pipe on -Y from the bowl wall to a funnel mouth at y -34.9 (Unreal +34.9) round "
                         "SOCKET_Bellows; the mesh bounds run past the 56 cm slab on that side only",
                  ucx="1 slab box (56 x 56 x 6) + 1 fire bowl box (43.2 x 43.2, z 6..14); the trivet has none")
        ex = dict(common, ember_top_on_axis_cm=round(m["ember_top_on_axis_cm"], 3),
                  ember_top_in_flame_column_cm=round(m["ember_top_in_column_cm"], 3),
                  ember_top_max_cm=round(m["ember_top_max_cm"], 3), coals=n_coals, clinkers=n_clinkers,
                  ucx="none (dressing inside the bowl; the hearth's fire bowl box covers it)")
        bx = dict(station="hearth", frame="pivot = nozzle tip, nozzle along Blender +Y (Unreal local -Y)",
                  length_cm=round(m["bellows_length_cm"], 3), nozzle_tip_cm=[0.0, 0.0, 0.0],
                  nozzle_dir_unreal=[0.0, -1.0, 0.0], nozzle_base_cm=ue((0.0, NOZZLE_BASE_Y, 0.0)),
                  rest_z_cm=BOTTOM_Z, width_cm=round(float(bv[:, 0].max() - bv[:, 0].min()), 3),
                  height_cm=round(float(bv[:, 2].max() - bv[:, 2].min()), 3),
                  placement="at Hearth SOCKET_Bellows, unrotated: the nozzle sits in the tuyere funnel and the "
                            "bellows rests on the table")
        for obj, extra in ((hearth, hx), (ember, ex), (bellows, bx)):
            paths.append(sc.export_fbx(obj, extra=extra))
        lpath, layout = write_layout(m, pan_underside_depth)
        print("layout", lpath)
    sheets = []
    if args["sheets"]:
        sheets = render_sheets(hearth, ember, bellows, fails)
    if args["save"]:
        sc.save_blend("hearth")
        print("saved", os.path.join(spec.BLEND_DIR, spec.STATIONS["hearth"][0]))
    if paths:
        fails += reimport(paths, {"Hearth_Mars_SM": 2, "EmberBed_Mars_SM": 0, "Bellows_Mars_SM": 2})
        for p in paths:
            with open(os.path.splitext(p)[0] + ".json") as fh:
                meta = json.load(fh)
            if meta["ucx_problems"]:
                fails.append("%s ucx problems %s" % (meta["name"], meta["ucx_problems"]))
            print("SIDECAR %s tris %d bounds %s..%s ucx %d sockets %s" % (
                meta["name"], meta["tris"], [round(x, 2) for x in meta["bounds_min_cm"]],
                [round(x, 2) for x in meta["bounds_max_cm"]], meta["ucx_pieces"],
                json.dumps({k: v["location_cm"] for k, v in meta["sockets"].items()})))
        if layout:
            print("LAYOUT", json.dumps(layout["props"]), json.dumps(layout["sockets_station_cm"]))
            print("LAYOUT entity_script", json.dumps(layout["entity_script"]))
    print("\nsheets:", *sheets, sep="\n  ")
    print("total %.1fs" % (time.time() - t0))
    if fails:
        print("STATION_HEARTH_FAIL", *fails, sep="\n  ")
    else:
        print("STATION_HEARTH_OK")


main()
