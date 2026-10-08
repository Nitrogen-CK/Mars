"""Mars cooking STATION "tools" (station_spec.STATIONS["tools"]): the two-handed kitchen weapons the chef swings, as a
re-runnable headless Blender 5.2 build.

Builds from fixed seeds (the scene is rebuilt from nothing every run):
  MeatTenderizer_Mars_SM  Iron/Wood/Rope  two-hand mallet: squat iron head (12 x 12 x 16, 4 x 4 pyramid teeth on the
                                          -Z face, flat chamfered +Z face, two riveted bands, a collar and langets
                                          where the haft enters), a faceted wooden haft with leather wraps at both
                                          grips and an iron butt ferrule.
  MeatCleaver_Mars_SM     Iron/Wood/Rope  oversized two-hand cleaver: wood scales on a full tang (3 rivets a side),
                                          leather wrap bands at both grips, iron pommel + bolster, a 34 cm blade with a
                                          thick dark spine, a ground bevel band, a hexagonal through-hole near the toe,
                                          nicks and a hand-ground wobble in the edge; the heel drops well below the
                                          handle line.
Pivot rule (both): the REAR grip centre (the primary hand) is the origin, the tool runs along +X toward its business
end, the striking / cutting side faces -Z when held level. Sockets are unrotated (X along the handle toward the head,
Z up, away from the striking side): Grip_R (the right glove, rear grip at the origin) and Grip_L (the left glove, the
front grip) as the FPHands gloves read them (Script/ECS/FPHands/Mars_FPHands_Grips.as), Strike (the impact point) and, on the
cleaver, EdgeHeel / EdgeToe (the ends of the cutting edge, for a slicing sweep).

Run:
  blender -b --factory-startup --python build_station_tools.py -- [--export] [--save] [--sheets]
    --export   FBX + JSON sidecar per prop into station_spec.EXPORT_DIR, then a re-import check of each
    --sheets   review sheets (iso / front / side / top per prop, both tools with a 30 cm bar, both with fist proxies)
    --save     station_spec.BLEND_DIR/Station_Tools.blend (props at their pivots with sockets + UCX children)
Prints STATION_TOOLS_OK when every check passed (STATION_TOOLS_FAIL + the reasons otherwise).

All builder geometry is in CENTIMETRES, Blender axes (Z up). Sidecars carry Unreal local cm (Y mirrored).
"""
import json
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import station_common as sc  # noqa: E402

fc = sc.fc
spec = sc.spec
TEN = spec.PROPS["MeatTenderizer"]
CLV = spec.PROPS["MeatCleaver"]
SLOTS = ("Iron", "Wood", "Rope")
IRON, WOOD, ROPE = 0, 1, 2

# ---------------------------------------------------------------- tenderizer dimensions (cm)
T_GRIP = TEN["grip_spacing_cm"]               # 16: front hand centre along +X
T_HEAD = np.array(TEN["head_cm"], float)      # 12 (X) x 12 (Y) x 16 (Z): the strike axis is the long one
T_HEAD_CX = 44.5                              # head centre along X (head spans 38.5 .. 50.5)
T_CHAMFER_TOP = 1.6                           # the flat +Z face's chamfer
T_CHAMFER_BOT = 0.9                           # round the toothed -Z face
T_TEETH = 4                                   # 4 x 4 pyramids
T_TOOTH_H = 1.5
T_HAFT_PROFILE = ((-5.6, 2.05), (-1.0, 2.12), (8.0, 2.03), (16.0, 2.12), (26.0, 2.15), (34.0, 2.2), (41.0, 2.25))
T_WRAPS = ((-4.3, 4.3, 4), (T_GRIP - 4.3, T_GRIP + 4.3, 4))   # x0, x1, turns (rear / front grip)
T_BANDS = ((3.5, 5.3), (-5.3, -3.6))         # head band z ranges
T_LANGET = (30.0, 38.8)

# ---------------------------------------------------------------- cleaver dimensions (cm)
C_GRIP = CLV["grip_spacing_cm"]               # 14
C_BLADE_X0, C_BLADE_X1 = 21.5, 55.5           # heel / toe (34 long)
C_SPINE_Z = 3.4                               # spine top above the handle axis (the blade hangs below the handle line)
C_HOLE_C, C_HOLE_H, C_HOLE_R = 50.3, -0.6, 1.6   # hexagonal through-hole near the toe
C_NICKS = ((29.5, 1.0), (42.0, 1.4), (46.3, 0.8))    # clear of the Strike point (edge centre ~38.5)  # (x, depth) bites out of the edge
C_ROW_W = (0.40, 0.52, 0.52, 0.42, 0.40, 0.38, 0.35, 0.25, 0.0)   # half thickness per row, spine -> edge
C_HANDLE_X0, C_HANDLE_X1 = -5.2, 20.6
C_SCALE_SECTION = ((0.28, 1.55), (0.9, 1.45), (1.35, 0.9), (1.5, 0.0), (1.35, -0.9), (0.9, -1.45), (0.28, -1.55))
C_SWELL = ((-5.2, 0.93), (-2.0, 1.0), (3.0, 1.0), (7.0, 0.92), (11.0, 0.99), (17.0, 1.0), (20.6, 0.96))
C_TANG_Z = 1.62
C_RIVETS_X = (0.0, 7.0, 14.0)
C_WRAPS = ((-4.3, -1.6, 2), (1.6, 4.3, 2), (C_GRIP - 4.3, C_GRIP - 1.6, 2), (C_GRIP + 1.6, C_GRIP + 4.3, 2))

# Grip_R (right glove, rear grip at the pivot) / Grip_L (left glove, front grip): the FPHands grip sockets
# (Script/ECS/FPHands/Mars_FPHands_Grips.as). The socket frame is the glove's grip bone: X along the handle across the
# palm toward the index finger (+X, toward the head), Z up (+Z, away from the striking side) - the identity rotation.
GRIP_ROT = (0.0, 0.0, 0.0)
SOCKET_FRAME = ("all sockets unrotated (identity): X along the handle toward the head, Z up, away from the striking side "
                "(strike / cut = -Z). Grip_R = right glove at the rear grip (the pivot), Grip_L = left glove at the front "
                "grip; X runs across the palm toward the index finger (grip_r / grip_l bone axes of SK_FPHands)")
FIST_CM = (10.0, 8.0, 9.0)                    # review proxy: a gloved fist round the handle (four-finger width along X)


def P(name):
    return sc.palette(name)


def ue(p):
    p = np.asarray(p, float)
    return [round(float(p[0]), 3), round(float(-p[1]), 3), round(float(p[2]), 3)]


def _n(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-12)


def axis_frame(axis):
    a = _n(axis)
    helper = np.array([0.0, 0.0, 1.0]) if abs(a[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = _n(np.cross(helper, a))
    w = np.cross(a, u)
    return u, w, a


def place_on_axis(v_local, origin, axis, phase_deg=0.0):
    """Local (x, y, z) with z along axis -> world; phase spins the local XY about the axis first."""
    v = np.asarray(v_local, float)
    a = math.radians(phase_deg)
    r = np.array([[math.cos(a), -math.sin(a), 0.0], [math.sin(a), math.cos(a), 0.0], [0.0, 0.0, 1.0]])
    v = v @ r.T
    u, w, ax = axis_frame(axis)
    return np.asarray(origin, float) + v[:, 0:1] * u + v[:, 1:2] * w + v[:, 2:3] * ax


def x_lathe(profile_xr, sides=8, phase_deg=22.5, jitter=0.0, seed=0):
    """Faceted solid of revolution about +X from (x, r) rows (r = 0 rows are poles). With 8 sides and a 22.5 deg
    phase the flats face +-Y / +-Z."""
    v, f = fc.lathe([(r, x) for x, r in profile_xr], sides, twist_seed=seed, jitter=jitter)
    return place_on_axis(v, (0.0, 0.0, 0.0), (1.0, 0.0, 0.0), phase_deg), f


def rivet(center, normal, rng, r=0.55, h=0.38, segments=6):
    """A faceted dome rivet head; its base sinks 0.25 cm into the surface."""
    v, f = fc.lathe([(0.0, h), (0.65 * r, 0.75 * h), (r, 0.05), (0.0, -0.25)], segments)
    return place_on_axis(v, center, normal, rng.uniform(0, 60)), f


def newell(pts):
    n = np.zeros(3)
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n += np.array([(a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]), (a[0] - b[0]) * (a[1] + b[1])])
    ln = np.linalg.norm(n)
    return n / ln if ln > 1e-12 else n


def hull(points, dissolve_deg=0.3):
    """Convex hull (bmesh) of cm points -> (verts, faces) with exactly coplanar triangles merged into facets."""
    bm = bmesh.new()
    for p in np.asarray(points, float):
        bm.verts.new(p.tolist())
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    junk = [g for g in res.get("geom_interior", []) + res.get("geom_unused", []) if isinstance(g, bmesh.types.BMVert)]
    if junk:
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    if dissolve_deg:
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(dissolve_deg), verts=bm.verts[:], edges=bm.edges[:])
    bm.verts.index_update()
    v = np.array([x.co[:] for x in bm.verts], float)
    f = [[x.index for x in face.verts] for face in bm.faces]
    bm.free()
    centre = v.mean(axis=0)
    out = []
    for face in f:
        if np.dot(newell(v[face]), v[face].mean(axis=0) - centre) < 0:
            face = face[::-1]
        out.append(face)
    return v, out


def offset_convex(poly, d):
    """Miter-offset a CCW convex 2D polygon outward by d (negative = inward)."""
    poly = np.asarray(poly, float)
    k = len(poly)
    out = []
    for i in range(k):
        a, b, c = poly[i - 1], poly[i], poly[(i + 1) % k]
        e1, e2 = _n(b - a), _n(c - b)
        n1, n2 = np.array([e1[1], -e1[0]]), np.array([e2[1], -e2[0]])
        out.append(b + d * (n1 + n2) / (1.0 + float(np.dot(n1, n2))))
    return np.array(out)


def band_loop(poly_in, poly_out, z0, z1):
    """A closed rectangular-section band round a vertical prism: inner / outer 2D loops (k, 2) between z0 and z1."""
    rings = [np.column_stack([poly_in, np.full(len(poly_in), z0)]), np.column_stack([poly_out, np.full(len(poly_out), z0)]),
             np.column_stack([poly_out, np.full(len(poly_out), z1)]), np.column_stack([poly_in, np.full(len(poly_in), z1)])]
    k = len(poly_in)
    v = np.concatenate(rings)
    f = []
    for i in range(4):
        i2 = (i + 1) % 4
        for s in range(k):
            s2 = (s + 1) % k
            f.append([i * k + s, i2 * k + s, i2 * k + s2, i * k + s2])
    return v, f


def ring_wrap(x0, x1, turns, section_fn, grow_valley, grow_peak, tilt=0.3):
    """Leather wrap: lofted rings round a handle section, alternating valley / peak (one turn = valley + peak), each
    ring tilted about Y so the turns read as a binding. section_fn(x, grow) -> (k, 2) (y, z) loop, CCW seen from +X."""
    n = 2 * turns
    xs = [x0] + [x0 + (x1 - x0) * (t + 0.5) / n for t in range(n)] + [x1]
    grows = [grow_valley * 0.6] + [grow_peak if t % 2 else grow_valley for t in range(n)] + [grow_valley * 0.6]
    rings = []
    for x, g in zip(xs, grows):
        yz = section_fn(x, g)
        zmax = max(float(np.abs(yz[:, 1]).max()), 1e-6)
        rings.append(np.column_stack([x + tilt * yz[:, 1] / zmax, yz[:, 0], yz[:, 1]]))
    v, f = fc.loft(rings)
    k = len(rings[0])
    tags = []
    for i in range(len(rings) - 1):
        tags += ["wrap_peak" if grows[i] == grow_peak or grows[i + 1] == grow_peak else "wrap"] * k
    tags += ["wrap_end", "wrap_end"]
    return v, f, tags


class Parts:
    """Accumulates (verts, faces) with a slot index and a tag per face, then builds one flat-shaded object."""

    def __init__(self):
        self.items = []
        self.tags = []

    def add(self, vf, slot, tag):
        v, f = vf[0], vf[1]
        tags = [tag] * len(f) if isinstance(tag, str) else list(tag)
        assert len(tags) == len(f)
        self.items.append((np.asarray(v, float), [list(map(int, x)) for x in f], slot))
        self.tags += tags

    def build(self, name):
        verts, faces, fslots = [], [], []
        base = 0
        for v, f, s in self.items:
            verts.append(v)
            faces.extend([[base + i for i in face] for face in f])
            fslots.extend([s] * len(f))
            base += len(v)
        obj = sc.new_object(name, np.concatenate(verts), faces, slots=SLOTS, face_slots=fslots)
        if len(obj.data.polygons) != len(faces):
            raise RuntimeError("%s: mesh.validate dropped faces (%d -> %d)" % (name, len(faces), len(obj.data.polygons)))
        return obj


# ================================================================ tenderizer
def tenderizer_head_points(rng):
    """Chamfered block: each corner contributes three points; chamfers stay planar (one cv per vertical edge)."""
    hx, hy, hz = T_HEAD * 0.5
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            cv = rng.uniform(0.8, 1.25)
            for sz in (-1, 1):
                ch = T_CHAMFER_TOP if sz > 0 else T_CHAMFER_BOT
                pts += [(sx * hx, sy * (hy - cv), sz * (hz - ch)), (sx * (hx - cv), sy * hy, sz * (hz - ch)),
                        (sx * (hx - ch), sy * (hy - ch), sz * hz)]
    return np.array(pts) + np.array([T_HEAD_CX, 0.0, 0.0])


def head_outline(pts):
    """The head's side outline (CCW, XY) at mid height, read off the hull points' middle ring."""
    mid = pts[np.abs(pts[:, 2]) < T_HEAD[2] * 0.5 - 0.1]
    mid = np.unique(np.round(mid[:, :2], 5), axis=0)
    c = mid.mean(axis=0)
    ang = np.arctan2(mid[:, 1] - c[1], mid[:, 0] - c[0])
    return mid[np.argsort(ang)]


def build_tenderizer():
    rng = np.random.default_rng(5101)
    parts = Parts()
    hx, hy, hz = T_HEAD * 0.5
    # ---- head
    pts = tenderizer_head_points(rng)
    hv, hf = hull(pts)
    tags = []
    for face in hf:
        n = newell(hv[face])
        tags.append("head_flat" if np.abs(n).max() > 0.995 else "head_bevel")
    parts.add((hv, hf), IRON, tags)
    # ---- teeth: 4 x 4 faceted pyramids over the flat of the -Z face
    flat = T_HEAD[0] - 2.0 * T_CHAMFER_BOT
    pitch = flat / T_TEETH
    for i in range(T_TEETH):
        for j in range(T_TEETH):
            cx = T_HEAD_CX - flat * 0.5 + pitch * (i + 0.5)
            cy = -flat * 0.5 + pitch * (j + 0.5)
            b = pitch * 0.48
            z0 = -hz + 0.3                                   # base sunk into the head
            apex = (cx + rng.uniform(-0.15, 0.15), cy + rng.uniform(-0.15, 0.15), -hz - T_TOOTH_H + rng.uniform(-0.08, 0.05))
            v = np.array([(cx - b, cy - b, z0), (cx + b, cy - b, z0), (cx + b, cy + b, z0), (cx - b, cy + b, z0), apex])
            parts.add((v, [[0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4], [3, 2, 1, 0]]), IRON, "teeth")
    # ---- two iron bands round the head's sides, riveted
    outline = head_outline(pts) - np.array([T_HEAD_CX, 0.0])
    for z0, z1 in T_BANDS:
        bv, bf = band_loop(offset_convex(outline, -0.4), offset_convex(outline, 0.35), z0, z1)
        parts.add((bv + np.array([T_HEAD_CX, 0.0, 0.0]), bf), IRON, "band")
        zm = 0.5 * (z0 + z1)
        for sy in (-1, 1):
            for dx in (-3.4, 3.4):
                parts.add(rivet((T_HEAD_CX + dx, sy * (hy + 0.35), zm), (0.0, sy, 0.0), rng), IRON, "rivet")
        parts.add(rivet((T_HEAD_CX + hx + 0.35, rng.uniform(-0.5, 0.5), zm), (1.0, 0.0, 0.0), rng), IRON, "rivet")
    # ---- haft (faceted, hand-cut jitter) running into the head
    prof = [(T_HAFT_PROFILE[0][0], 0.0)] + list(T_HAFT_PROFILE) + [(T_HAFT_PROFILE[-1][0], 0.0)]
    parts.add(x_lathe(prof, 8, 22.5, jitter=0.06, seed=33), WOOD, "haft")
    # ---- collar where the haft enters the head, two langets down the haft
    parts.add(x_lathe([(T_HEAD_CX - hx - 1.6, 0.0), (T_HEAD_CX - hx - 1.6, 2.35), (T_HEAD_CX - hx - 1.15, 2.8),
                       (T_HEAD_CX - hx + 0.3, 2.8), (T_HEAD_CX - hx + 0.3, 0.0)], 8, 22.5), IRON, "collar")
    la, lb = T_LANGET
    for sz in (1, -1):
        outline2 = [(lb, -0.7), (lb, 0.7), (la + 1.6, 0.7), (la, 0.0), (la + 1.6, -0.7)]
        z_in, z_out = sz * 1.82, sz * 2.3
        v = np.array([(x, y, z_in) for x, y in outline2] + [(x, y, z_out) for x, y in outline2])
        k = len(outline2)
        f = [[i, (i + 1) % k, k + (i + 1) % k, k + i] for i in range(k)] + [list(range(k - 1, -1, -1)), list(range(k, 2 * k))]
        parts.add((v, f), IRON, "langet")
        for x in (la + 3.0, la + 6.4):
            parts.add(rivet((x, 0.0, z_out), (0.0, 0.0, sz), rng, r=0.45, h=0.3), IRON, "rivet")
    # ---- butt ferrule
    parts.add(x_lathe([(-8.2, 0.0), (-8.2, 1.3), (-7.8, 2.2), (-7.1, 2.6), (-5.6, 2.6), (-5.2, 2.35), (-5.2, 0.0)],
                      8, 22.5), IRON, "ferrule")
    # ---- leather wraps at both grips (octagonal, same phase as the haft)
    def haft_r(x):
        return float(np.interp(x, [p[0] for p in T_HAFT_PROFILE], [p[1] for p in T_HAFT_PROFILE]))

    def octo(x, grow):
        r = haft_r(x) + 0.12 + grow
        a = np.radians(22.5) + np.arange(8) * math.tau / 8
        return np.column_stack([r * np.cos(a), r * np.sin(a)])

    for x0, x1, turns in T_WRAPS:
        v, f, tags = ring_wrap(x0, x1, turns, octo, 0.08, 0.28, tilt=0.35)
        parts.add((v, f), ROPE, tags)
    obj = parts.build("MeatTenderizer_Mars_SM")
    info = dict(head_lo=np.array([T_HEAD_CX - hx, -hy, -hz]), head_hi=np.array([T_HEAD_CX + hx, hy, hz]),
                strike=np.array([T_HEAD_CX, 0.0, -hz - T_TOOTH_H]), tooth_pitch=pitch)
    return obj, parts.tags, info


def paint_tenderizer(obj, tags):
    iron, wood, wood_d = P("Iron"), P("Wood"), P("WoodDark")
    leather = P("Rope") * 0.34
    rng = np.random.default_rng(77)
    rgb = []
    for t in tags:
        if t == "haft":
            rgb.append(wood * (1.0 - rng.uniform(0.0, 0.4)) + wood_d * rng.uniform(0.0, 0.4))
        else:
            rgb.append({"head_flat": iron * 1.6, "head_bevel": iron * 3.2, "teeth": iron * 2.6, "band": iron * 0.8,
                        "rivet": iron * 3.0, "collar": iron * 1.0, "langet": iron * 0.9, "ferrule": iron * 1.4,
                        "wrap": leather * 0.8, "wrap_peak": leather, "wrap_end": leather * 0.55}[t])
    fc.paint(obj, np.array(rgb), variation=0.07, seed=21)


# ================================================================ cleaver
def edge_smooth(x):
    u = np.clip((np.asarray(x, float) - C_BLADE_X0) / (C_BLADE_X1 - C_BLADE_X0), 0.0, 1.0)
    return -10.9 - 0.95 * np.sin(math.pi * u ** 0.85) + 1.1 * u ** 4


def spine_z(x):
    u = (x - C_BLADE_X0) / (C_BLADE_X1 - C_BLADE_X0)
    return C_SPINE_Z + 0.25 * math.sin(math.pi * u)


def cleaver_columns():
    a = C_HOLE_R * math.sqrt(3.0) * 0.5
    special = [(C_BLADE_X0, "heel"), (C_BLADE_X0 + 0.7, "heel2"), (C_BLADE_X1 - 0.6, "toe2"), (C_BLADE_X1, "toe")]
    special += [(C_HOLE_C - C_HOLE_R, "hole0"), (C_HOLE_C - C_HOLE_R * 0.5, "hole1"), (C_HOLE_C + C_HOLE_R * 0.5, "hole2"),
                (C_HOLE_C + C_HOLE_R, "hole3")]
    for xn, _ in C_NICKS:
        special += [(xn - 0.7, "nick_side"), (xn, "nick"), (xn + 0.55, "nick_side")]
    xs = [x for x, _ in special]
    cols = list(special)
    for x in np.linspace(C_BLADE_X0, C_BLADE_X1, 19):
        if min(abs(x - s) for s in xs) > 0.6:
            cols.append((float(x), "plain"))
    cols.sort(key=lambda c: c[0])
    return cols, a


def build_blade(rng):
    cols, a = cleaver_columns()
    nick_depth = {xn: d for xn, d in C_NICKS}
    rows_z = []
    for x, kind in cols:
        zs = spine_z(x) - (0.5 if kind == "toe" else 0.0)
        ze_s = float(edge_smooth(x))
        ze = ze_s + 0.22 * math.sin(1.3 * x + 0.4) + 0.14 * math.sin(0.55 * x + 1.9) + rng.uniform(-0.08, 0.08)
        if kind == "nick":
            ze += nick_depth[x]
        if kind == "heel":
            ze += 0.6
        if kind == "toe":
            ze += 0.35
        zb = ze_s + 2.3 + 0.12 * math.sin(0.9 * x + 0.7)
        rows_z.append([zs, zs - 0.35, zs - 1.5, zs - 1.85, C_HOLE_H + a, C_HOLE_H, C_HOLE_H - a, zb, ze])
    n, nr = len(cols), 9
    hole_i = [i for i, (_, k) in enumerate(cols) if k == "hole0"][0]
    skip = {(hole_i + 1, 5), (hole_i + 2, 5)}
    verts = []
    P_, M_, E_ = {}, {}, {}
    for i, (x, kind) in enumerate(cols):
        for j in range(nr):
            z = rows_z[i][j]
            if j == nr - 1:
                E_[i] = len(verts)
                verts.append((x, 0.0, z))
                continue
            if (i, j) in skip:
                continue
            for side, d in ((1, P_), (-1, M_)):
                w = C_ROW_W[j] + (rng.uniform(-0.008, 0.008) if 3 <= j <= 7 else 0.0)
                d[(i, j)] = len(verts)
                verts.append((x, side * w, z))
    faces, tags = [], []

    def row_tag(j):
        return "spine" if j <= 2 else ("bevel" if j == 7 else "body")

    for i in range(n - 1):
        faces.append([P_[(i, 0)], P_[(i + 1, 0)], M_[(i + 1, 0)], M_[(i, 0)]])
        tags.append("spine_top")
        for j in range(nr - 1):
            for d in (P_, M_):
                if j + 1 == nr - 1:
                    faces.append([d[(i, j)], d[(i + 1, j)], E_[i + 1], E_[i]])
                    tags.append("bevel")
                    continue
                k = i - hole_i
                if 0 <= k <= 2 and j in (4, 5):
                    if k == 1:
                        continue                              # the hole's middle cells
                    if k == 0 and j == 4:
                        faces.append([d[(i, 4)], d[(i + 1, 4)], d[(i, 5)]])
                    elif k == 0 and j == 5:
                        faces.append([d[(i, 5)], d[(i + 1, 6)], d[(i, 6)]])
                    elif k == 2 and j == 4:
                        faces.append([d[(i, 4)], d[(i + 1, 4)], d[(i + 1, 5)]])
                    else:
                        faces.append([d[(i + 1, 5)], d[(i + 1, 6)], d[(i, 6)]])
                    tags.append("body")
                    continue
                faces.append([d[(i, j)], d[(i + 1, j)], d[(i + 1, j + 1)], d[(i, j + 1)]])
                tags.append(row_tag(j))
    for i in (0, n - 1):
        faces.append([P_[(i, j)] for j in range(nr - 1)] + [E_[i]] + [M_[(i, j)] for j in range(nr - 2, -1, -1)])
        tags.append("cap")
    hexa = [(hole_i, 5), (hole_i + 1, 4), (hole_i + 2, 4), (hole_i + 3, 5), (hole_i + 2, 6), (hole_i + 1, 6)]
    for h in range(6):
        p, q = hexa[h], hexa[(h + 1) % 6]
        faces.append([P_[p], P_[q], M_[q], M_[p]])
        tags.append("hole")
    edge = np.array([verts[E_[i]] for i in range(n)])
    info = dict(edge=edge, spine_max=max(r[0] for r in rows_z), edge_min=float(edge[:, 2].min()),
                hole=np.array([C_HOLE_C, 0.0, C_HOLE_H]), cols=n)
    return (np.array(verts, float), faces), tags, info


def scale_section(x, mirror=False):
    s = float(np.interp(x, [p[0] for p in C_SWELL], [p[1] for p in C_SWELL]))
    zs = 0.5 * (1.0 + s)
    sec = np.array([(y * s if y > 0.3 else y, z * zs) for y, z in C_SCALE_SECTION])
    if mirror:
        sec[:, 0] *= -1.0
    return sec, s


def handle_outline(x, grow):
    """Full handle section (both scales + the tang edges), grown outward by grow cm, CCW seen from +X (y, z)."""
    sec, _ = scale_section(x)
    side = [(float(y), float(z)) for y, z in sec[1:-1]]                    # +Y scale, top -> bottom
    pts = np.array([(0.0, C_TANG_Z)] + side + [(0.0, -C_TANG_Z)] + [(-y, z) for y, z in side[::-1]], float)
    ext = np.array([max(np.abs(pts[:, 0]).max(), 1e-6), max(np.abs(pts[:, 1]).max(), 1e-6)])
    pts = pts * ((ext + grow) / ext)
    return pts


def build_cleaver():
    rng = np.random.default_rng(6203)
    parts = Parts()
    bvf, btags, binfo = build_blade(rng)
    parts.add(bvf, IRON, btags)
    # ---- tang (iron edge showing between the scales)
    parts.add(sc.box(((C_HANDLE_X0 - 0.2 + 21.0) * 0.5, 0.0, 0.0), (21.0 - C_HANDLE_X0 + 0.2, 0.6, 2.0 * C_TANG_Z)),
              IRON, "tang")
    # ---- wooden scales, swelling at the grips
    xs = [p[0] for p in C_SWELL]
    for mirror in (False, True):
        rings = []
        for x in xs:
            sec, _ = scale_section(x, mirror)
            sec = sec + rng.uniform(-0.04, 0.04, size=sec.shape) * np.array([1.0, 1.0])
            rings.append(np.column_stack([np.full(len(sec), x), sec]))
        parts.add(fc.loft(rings), WOOD, "scale")
    # ---- three rivets a side
    for x in C_RIVETS_X:
        _, s = scale_section(x)
        for sy in (1, -1):
            parts.add(rivet((x, sy * 1.5 * s, 0.0), (0.0, sy, 0.0), rng, r=0.55, h=0.32, segments=6), IRON, "rivet")
    # ---- leather wrap bands, two at each grip either side of the rivet
    for x0, x1, turns in C_WRAPS:
        v, f, tags = ring_wrap(x0, x1, turns, handle_outline, 0.16, 0.34, tilt=0.25)
        parts.add((v, f), ROPE, tags)
    # ---- pommel and bolster (octagonal iron)
    parts.add(x_lathe([(-7.4, 0.0), (-7.4, 1.2), (-7.0, 2.0), (-6.2, 2.25), (-5.5, 2.05), (-5.0, 1.8), (-5.0, 0.0)],
                      8, 22.5), IRON, "pommel")
    parts.add(x_lathe([(19.6, 0.0), (19.6, 1.9), (20.0, 2.2), (21.8, 2.2), (22.3, 1.95), (22.3, 0.0)], 8, 22.5),
              IRON, "bolster")
    obj = parts.build("MeatCleaver_Mars_SM")
    return obj, parts.tags, binfo


def paint_cleaver(obj, tags):
    iron, wood, wood_d = P("Iron"), P("Wood"), P("WoodDark")
    leather = P("Rope") * 0.34
    rng = np.random.default_rng(91)
    rgb = []
    for t in tags:
        if t == "scale":
            rgb.append(wood * (1.0 - rng.uniform(0.0, 0.45)) + wood_d * rng.uniform(0.0, 0.45))
        elif t == "body":
            rgb.append(iron * 1.7)
        else:
            rgb.append({"spine_top": iron * 0.6, "spine": iron * 0.55, "bevel": iron * 4.2, "cap": iron * 1.0,
                        "hole": iron * 0.5, "tang": iron * 0.8, "rivet": iron * 2.4, "pommel": iron * 1.1,
                        "bolster": iron * 1.0, "wrap": leather * 0.8, "wrap_peak": leather, "wrap_end": leather * 0.55}[t])
    fc.paint(obj, np.array(rgb), variation=0.06, seed=23)


# ================================================================ sockets, collision, extras
def finish_tenderizer(obj, info):
    lo, hi = fc.bounds_cm(obj)
    sc.add_socket(obj, "Grip_R", (0.0, 0.0, 0.0), GRIP_ROT)
    sc.add_socket(obj, "Grip_L", (T_GRIP, 0.0, 0.0), GRIP_ROT)
    sc.add_socket(obj, "Strike", info["strike"])
    hl, hh = info["head_lo"], info["head_hi"]
    sc.add_ucx(obj, sc.box(0.5 * (hl + hh + np.array([0, 0, 0])) - np.array([0, 0, T_TOOTH_H * 0.5]),
                           (hh - hl) + np.array([0.7, 0.8, T_TOOTH_H]))[0])
    haft_x0, haft_x1 = lo[0], hl[0]
    sc.box_ucx(obj, (0.5 * (haft_x0 + haft_x1), 0.0, 0.0), (haft_x1 - haft_x0, 5.6, 5.6))
    return dict(station="tools", builder="build_station_tools.py",
                pivot="rear grip centre (primary hand); haft along +X, head at +X, toothed striking face -Z",
                socket_frame=SOCKET_FRAME, grip_spacing_cm=T_GRIP, grip_r_cm=ue((0, 0, 0)), grip_l_cm=ue((T_GRIP, 0, 0)),
                strike_cm=ue(info["strike"]), overall_length_cm=round(float(hi[0] - lo[0]), 2),
                head_cm=[float(x) for x in T_HEAD], head_centre_cm=ue((T_HEAD_CX, 0, 0)),
                teeth=dict(grid=[T_TEETH, T_TEETH], height_cm=T_TOOTH_H, pitch_cm=round(info["tooth_pitch"], 3)),
                haft_diameter_cm=round(2.0 * 2.15 * math.cos(math.radians(22.5)), 2),
                mass_hint_kg=3.5, centre_of_mass_hint_cm=ue((T_HEAD_CX - 4.0, 0, -0.5)))


def finish_cleaver(obj, info):
    lo, hi = fc.bounds_cm(obj)
    edge = info["edge"]
    heel, toe = edge[1], edge[-2]                       # the heel2 / toe2 columns: ends of the sharp edge
    xm = 0.5 * (heel[0] + toe[0])
    strike = np.array([xm, 0.0, float(np.interp(xm, edge[:, 0], edge[:, 2]))])
    sc.add_socket(obj, "Grip_R", (0.0, 0.0, 0.0), GRIP_ROT)
    sc.add_socket(obj, "Grip_L", (C_GRIP, 0.0, 0.0), GRIP_ROT)
    sc.add_socket(obj, "Strike", strike)
    sc.add_socket(obj, "EdgeHeel", heel)
    sc.add_socket(obj, "EdgeToe", toe)
    z0, z1 = info["edge_min"] - 0.05, info["spine_max"] + 0.05
    sc.box_ucx(obj, (0.5 * (C_BLADE_X0 + C_BLADE_X1), 0.0, 0.5 * (z0 + z1)), (C_BLADE_X1 - C_BLADE_X0, 1.3, z1 - z0))
    sc.box_ucx(obj, (0.5 * (lo[0] + 22.3), 0.0, 0.0), (22.3 - lo[0], 4.6, 4.6))
    return dict(station="tools", builder="build_station_tools.py",
                pivot="rear grip centre (primary hand); handle along +X, blade at +X, cutting edge -Z",
                socket_frame=SOCKET_FRAME, grip_spacing_cm=C_GRIP, grip_r_cm=ue((0, 0, 0)), grip_l_cm=ue((C_GRIP, 0, 0)),
                strike_cm=ue(strike), edge_heel_cm=ue(heel), edge_toe_cm=ue(toe),
                edge_length_cm=round(float(np.linalg.norm(toe - heel)), 2),
                overall_length_cm=round(float(hi[0] - lo[0]), 2),
                blade_cm=[round(C_BLADE_X1 - C_BLADE_X0, 2), round(info["spine_max"] - info["edge_min"], 2),
                          round(2.0 * max(C_ROW_W), 2)],
                blade_x_range_cm=[C_BLADE_X0, C_BLADE_X1], handle_x_range_cm=[round(float(lo[0]), 2), C_HANDLE_X1],
                heel_drop_below_handle_cm=round(float(-C_TANG_Z - edge[0][2]), 2),
                hole_centre_cm=ue(info["hole"]), hole_radius_cm=C_HOLE_R,
                mass_hint_kg=2.4, centre_of_mass_hint_cm=ue((30.0, 0, -3.0)))


def claim_socket_names(obj):
    """Both tools carry the same socket names, but Blender object names are unique per file (the second prop's empties
    become SOCKET_Grip_R.001, which the FBX importer and the sidecar would take literally). Before exporting obj, give
    every other prop's sockets a suffixed name and obj's sockets the bare SOCKET_<Name>."""
    mine = sc.children(obj, "SOCKET_")
    for o in bpy.data.objects:
        if o.name.startswith("SOCKET_") and o.parent is not obj and o.parent is not None:
            o.name = "%s__%s" % (o.name.split(".")[0].split("__")[0], o.parent.name.replace("_Mars_SM", ""))
    for e in mine:
        e.name = e.name.split(".")[0].split("__")[0]
    bad = [e.name for e in mine if "." in e.name or "__" in e.name]
    if bad:
        raise RuntimeError("socket names not claimed: %s" % bad)


# ================================================================ review renders
def remove_object(o):
    mesh = o.data if o.type == "MESH" else None
    bpy.data.objects.remove(o, do_unlink=True)
    if mesh is not None and mesh.users == 0:
        bpy.data.meshes.remove(mesh)


def copy_mesh(obj, offset=(0.0, 0.0, 0.0), name=None):
    c = bpy.data.objects.new(name or (obj.name + "_Copy"), obj.data.copy())
    bpy.context.scene.collection.objects.link(c)
    fc.set_verts_cm(c, fc.verts_cm(c) + np.asarray(offset, float))
    return c


def frame_for_review(obj):
    """fc.review_sheet aims at z = 0.45 x the largest extent above the origin; move the copy's mesh so its bbox
    middle sits there (review copies only)."""
    v = fc.verts_cm(obj)
    lo, hi = v.min(axis=0), v.max(axis=0)
    ext = float((hi - lo).max())
    shift = np.array([(lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, (lo[2] + hi[2]) * 0.5 - 0.45 * ext])
    fc.set_verts_cm(obj, v - shift)


def join(objs, name):
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = objs[0]
    with bpy.context.temp_override(active_object=objs[0], selected_objects=objs, selected_editable_objects=objs):
        bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


def painted_box(name, center, size, rgb):
    v, f = sc.box(center, size)
    o = fc.new_object(name, v, f, slots=("Stone",))
    fc.paint(o, np.repeat(np.asarray(rgb, float)[None, :], len(f), axis=0), variation=0.02, cavity_darken=0.0)
    return o


def ref_bar(origin):
    """30 cm reference bar in three alternating 10 cm segments."""
    out = []
    for k in range(3):
        rgb = fc.srgb(230, 230, 230) if k % 2 == 0 else fc.srgb(200, 40, 40)
        out.append(painted_box("_Bar%d" % k, (origin[0] + 5.0 + 10.0 * k, origin[1], origin[2]), (10.0, 1.0, 1.0), rgb))
    return out


def fists(offset, grips):
    v, f = fc.icosphere(1.0, 1)
    out = []
    for g in grips:
        vv = v * (np.array(FIST_CM) * 0.5) + np.asarray(offset, float) + np.array([g, 0.0, 0.0])
        o = fc.new_object("_Fist", vv, f, slots=("Stone",))
        fc.paint(o, np.repeat(fc.srgb(232, 226, 214)[None, :], len(f), axis=0), variation=0.03, cavity_darken=0.0)
        out.append(o)
    return out


def render_closeup(obj, path, view, target_cm, half_width_cm, size=(1800, 900)):
    """One tight workbench render of obj in place (fc.review_sheet frames by the largest extent, which leaves a long
    thin tool small in its frame)."""
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


CLOSE_VIEWS = {"front": (0.0, -1.0, 0.05), "iso": (0.8, -1.0, 0.6), "under": (0.35, -0.6, -1.0),
               "back": (-0.5, 1.0, 0.35)}


def render_sheets(ten, clv):
    sheets = []
    for obj, stem in ((ten, "MeatTenderizer"), (clv, "MeatCleaver")):
        lo, hi = fc.bounds_cm(obj)
        c = 0.5 * (lo + hi)
        paths = [render_closeup(obj, os.path.join(spec.REVIEW_DIR, "%s_close_%s.png" % (stem, k)), v, c,
                                (0.5 * (hi[0] - lo[0]) + 3.0) * (1.0 if k == "front" else 1.3))
                 for k, v in CLOSE_VIEWS.items()]
        sheets.append(fc.tile_images(paths, os.path.join(spec.REVIEW_DIR, "%s_close_sheet.png" % stem), cols=2))
    views = ("iso", "front", "side", "top")
    for obj, stem in ((ten, "MeatTenderizer"), (clv, "MeatCleaver")):
        c = copy_mesh(obj, name=stem + "_Review")
        frame_for_review(c)
        sheets.append(fc.review_sheet([c], stem, views=views, color="VERTEX", size=(1800, 800), gap=1.15))
        remove_object(c)
    # both tools, pivots aligned at x = 0, one above the other in the XZ plane, with a 30 cm bar under them
    parts = [copy_mesh(ten, (0.0, 0.0, 16.0)), copy_mesh(clv, (0.0, 0.0, -10.0))] + ref_bar((0.0, 0.0, -30.0))
    asm = join(parts, "MeatTools_Scale_Review")
    frame_for_review(asm)
    sheets.append(fc.review_sheet([asm], "MeatTools_Scale", views=("front", "iso", "top"), color="VERTEX",
                                  size=(1800, 1100), gap=1.1))
    remove_object(asm)
    # the same with 10 cm gloved-fist proxies on both grips of each tool (do two hands fit between pivot and head?)
    parts = [copy_mesh(ten, (0.0, 0.0, 16.0)), copy_mesh(clv, (0.0, 0.0, -10.0))]
    parts += fists((0.0, 0.0, 16.0), (0.0, T_GRIP)) + fists((0.0, 0.0, -10.0), (0.0, C_GRIP)) + ref_bar((0.0, 0.0, -30.0))
    asm = join(parts, "MeatTools_Grips_Review")
    frame_for_review(asm)
    sheets.append(fc.review_sheet([asm], "MeatTools_Grips", views=("front", "iso"), color="VERTEX",
                                  size=(1800, 1100), gap=1.1))
    remove_object(asm)
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)
    return sheets


# ================================================================ main
def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False})
    t0 = time.time()
    fc.ensure_dirs()
    fc.clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    fails = []

    ten, ten_tags, ten_info = build_tenderizer()
    paint_tenderizer(ten, ten_tags)
    fc.smart_uv(ten)
    clv, clv_tags, clv_info = build_cleaver()
    paint_cleaver(clv, clv_tags)
    fc.smart_uv(clv)
    ten_extra = finish_tenderizer(ten, ten_info)
    clv_extra = finish_cleaver(clv, clv_info)

    # ---- checks
    for obj, prop, extra in ((ten, TEN, ten_extra), (clv, CLV, clv_extra)):
        tris = fc.tri_count(obj)
        lo, hi = fc.bounds_cm(obj)
        print("%-24s tris %5d / %d  bounds %s .. %s  overall %.1f cm" % (
            obj.name, tris, prop["tris_max"], np.round(lo, 2), np.round(hi, 2), hi[0] - lo[0]))
        if tris > prop["tris_max"]:
            fails.append("%s tris %d > %d" % (obj.name, tris, prop["tris_max"]))
        if abs((hi[0] - lo[0]) - prop["overall_length_cm"]) > 0.1 * prop["overall_length_cm"]:
            fails.append("%s overall %.1f vs spec %.1f" % (obj.name, hi[0] - lo[0], prop["overall_length_cm"]))
        if lo[0] > -4.0:
            fails.append("%s: nothing behind the rear grip (min x %.2f)" % (obj.name, lo[0]))
        probs = sc.check_ucx(obj)
        if probs or len(sc.children(obj, "UCX_")) != 2:
            fails.append("%s ucx %d problems %s" % (obj.name, len(sc.children(obj, "UCX_")), probs))
        print("  extra:", json.dumps(extra))

    exported = []
    if args["export"]:
        claim_socket_names(ten)
        exported.append(sc.export_fbx(ten, extra=ten_extra))
        claim_socket_names(clv)
        exported.append(sc.export_fbx(clv, extra=clv_extra))
    sheets = []
    if args["sheets"]:
        sheets = render_sheets(ten, clv)
    if args["save"]:
        for m in list(bpy.data.materials):
            if m.users == 0:
                bpy.data.materials.remove(m)
        sc.save_blend("tools")
        print("saved", os.path.join(spec.BLEND_DIR, spec.STATIONS["tools"][0]))

    # ---- re-import every FBX (after the save, so the blend stays clean) + read back the sidecars
    for path in exported:
        before = set(bpy.data.objects)
        rep = fc.reimport_check(path)
        for o in [o for o in bpy.data.objects if o not in before]:
            bpy.data.objects.remove(o)
        stem = os.path.splitext(os.path.basename(path))[0]
        meshes = [r for r in rep if not r["name"].startswith("UCX_")]
        ucx = [r for r in rep if r["name"].startswith("UCX_")]
        with open(os.path.splitext(path)[0] + ".json") as fh:
            meta = json.load(fh)
        for r in meshes:
            ok = r["uv_layers"][:1] == ["UVMap"] and "Col" in r["colors"] and r["flat"]
            print("reimport %-24s tris %5d uv %s colors %s flat %s slots %s size %.1f ucx %d" % (
                r["name"], r["tris"], r["uv_layers"], r["colors"], r["flat"], r["slots"], r["size_cm"], len(ucx)))
            if not ok:
                fails.append("reimport %s: uv %s colors %s flat %s" % (stem, r["uv_layers"], r["colors"], r["flat"]))
        if len(ucx) != meta["ucx_pieces"] or meta["ucx_problems"] or len(ucx) != 2:
            fails.append("%s: ucx reimported %d / sidecar %d problems %s" % (stem, len(ucx), meta["ucx_pieces"],
                                                                             meta["ucx_problems"]))
        want = {"Grip_R", "Grip_L", "Strike"} | ({"EdgeHeel", "EdgeToe"} if "Cleaver" in stem else set())
        if set(meta["sockets"]) != want:
            fails.append("%s: sidecar sockets %s != %s" % (stem, sorted(meta["sockets"]), sorted(want)))
        print("  sidecar %s tris %d ucx_problems %s sockets %s" % (stem, meta["tris"], meta["ucx_problems"],
                                                                  json.dumps(meta["sockets"])))
    print("\nsheets:", *sheets, sep="\n  ")
    print("total %.1fs" % (time.time() - t0))
    if fails:
        print("STATION_TOOLS_FAIL", *fails, sep="\n  ")
    else:
        print("STATION_TOOLS_OK")


main()
