"""Pantry Rat R01 - Phase 1 builder: faceted spoon-backed rat skinned to the 26-bone rig, Stone Arch den, Monk's Rind
cheese, court blockout, pose proofs, clearance measurements and review renders (headless, reproducible, cm).

Builds source/PantryRat_R01.blend from nothing:
  Authoring  editable per-part solids (AUTH_*; left-side parts only, the right is mirrored into the export mesh)
  Rig        empty (no animator controls in Phase 1; poses rotate the export bones directly)
  Export     PantryRat_R01_Body skinned to PantryRat_R01_Armature (26 bones of ../RIG.json)
  Props      den shell / recess / back plane / eye plate / markers, cheese, mushroom + bulky proxies, backpack envelope
             + pocket Empties, crates, chef capsule, floor, Carry_Mouth / Carry_Drag Empties (jaw children)
  Review     camera, lights, 10 cm rulers, labels, flee-route ribbons
Pose actions (fake user): PantryRat_R01_Pose_<name>, one frame each, on the armature.

Frame: 1 BU = 1 cm, 30 fps. The rat faces +X, up +Z; Blender (x, y, z) reads as Unreal (x, -y, z); rat LEFT = +Y.
The root bone is at the origin (floor centre beneath the neutral body), rest matrix identity, and never moves.

Run (from this folder's parent):
  blender -b --factory-startup --python scripts/build_pantry_rat.py -- [--no-save] [--no-renders] [--views-only]
                                                                       [--tag rNN]
Prints PANTRY_RAT_OK or PANTRY_RAT_FAIL <reason>; exits non-zero on failure.
"""
import json
import math
import os
import sys
import time
import traceback

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import rat_common as rc  # noqa: E402
from rat_common import MB, PAL, PART, X, Y, Z, V, nrm, smooth, lerp  # noqa: E402

ROOT = os.path.dirname(HERE)
RIG_JSON = os.path.join(ROOT, "RIG.json")
BLEND_FILE = os.path.join(ROOT, "source", "PantryRat_R01.blend")
REVIEW = os.path.join(ROOT, "review", "phase1")
if "--review-dir" in sys.argv:   # Phase 2: rebuild without touching the Phase 1 record
    REVIEW = os.path.abspath(sys.argv[sys.argv.index("--review-dir") + 1])
MEASURE_JSON = os.path.join(REVIEW, "measurements.json")
LOG_FILE = os.path.join(REVIEW, "build_log.txt")

ARM_NAME = "PantryRat_R01_Armature"
MESH_NAME = "PantryRat_R01_Body"
POSE_PREFIX = "PantryRat_R01_Pose_"

LOG = []


def log(*a):
    s = " ".join(str(x) for x in a)
    print(s)
    LOG.append(s)


# ---------------------------------------------------------------- parameters (cm, degrees)
P = {
    # torso lathe along X: (x, half width y, half height z, centre z); belly flattening factor for the lower half
    "TORSO": [(-16.6, 4.6, 4.8, 19.4), (-15.1, 9.4, 9.6, 20.2), (-12.6, 12.8, 12.9, 21.2), (-9.2, 14.6, 14.3, 21.9),
              (-4.6, 15.0, 14.4, 22.0), (0.0, 14.5, 13.9, 21.9), (4.2, 13.4, 13.5, 21.6), (7.8, 11.8, 13.2, 22.2),
              (10.8, 9.0, 11.2, 22.6)],
    "TORSO_CAPS": ((-17.6, 19.2), (12.2, 24.4)),
    "BELLY_FLAT": 1.26,
    "TORSO_SIDES": 18,
    # head lathe along X
    "HEAD": [(7.6, 8.4, 8.6, 25.0), (10.0, 10.3, 10.0, 25.5), (12.8, 10.1, 9.5, 25.2), (15.6, 8.4, 7.8, 24.2),
             (17.7, 5.9, 5.5, 23.0), (19.4, 3.9, 3.6, 22.0), (20.4, 2.4, 2.4, 21.5)],
    "HEAD_CAPS": (6.6, 21.0),
    "HEAD_SIDES": 14,
    "NOSE": ((21.1, 0.0, 21.5), (2.0, 2.4, 2.1)),
    "EAR_C": (10.6, 11.2, 36.6), "EAR_RW": 7.6, "EAR_RH": 8.2, "EAR_N": (0.64, 0.72, 0.12), "EAR_UP": (-0.18, 0.40, 0.90),
    "EYE_DIR": (0.50, 0.74, 0.45), "EYE_AXIS": (15.8, 0.0, 24.9), "EYE_RS": 2.9, "EYE_RU": 2.5, "EYE_OFF": 0.25,
    # legs (left side): shoulder/hip, elbow/knee, wrist/heel, toe tip
    "FORE": ((3.4, 7.2, 14.5), (2.0, 9.2, 7.4), (4.6, 9.4, 2.3), (8.8, 9.8, 0.9)),
    "HIND": ((-10.2, 8.0, 16.0), (-5.0, 10.6, 8.2), (-11.0, 10.8, 2.6), (-3.2, 10.8, 0.9)),
    # tail control points (neutral: droops to the floor, tip curls up)
    "TAIL": [(-15.6, 0.0, 15.4), (-19.8, 0.0, 11.6), (-24.4, 0.0, 7.8), (-29.0, 0.0, 4.8), (-33.4, 0.0, 3.4),
             (-37.2, 0.0, 3.3), (-39.9, 0.0, 4.8), (-41.4, 0.0, 7.4)],
    "TAIL_BONE_IDX": (0, 2, 4, 6, 7),
    "TAIL_R": (2.4, 0.55),
    # spoon (local: handle end at 0 along +X, bowl concave side +Z)
    "SPOON_HANDLE": 17.5, "SPOON_NECK": 2.0, "SPOON_BOWL_HL": 5.6, "SPOON_BOWL_HW": 4.4,
    "SPOON_H_XY": (-13.4, 7.2), "SPOON_B_XY": (2.4, -5.2), "SPOON_GAP": 0.45,
    # Phase 2 (chest band hugs the torso): inner face at the widest of the three strap-width hits minus BAND_EMBED
    # (<= 0.2 cm into the faceted torso), radial from the band axis; Phase 1 sat 0.55 cm off the facet normal and
    # 0.6 thick (a floating ring 1.15 cm proud from the front/rear)
    "BAND_X": -7.0, "BAND_W": 3.0, "BAND_T": 0.5, "BAND_OFF": 0.55, "BAND_EMBED": 0.15,
}

BONE_PARENTS = [
    ("root", None), ("body", "root"), ("pelvis", "body"), ("chest", "body"), ("neck", "chest"), ("head", "neck"),
    ("jaw", "head"), ("ear_l", "head"), ("ear_r", "head"),
    ("fore_upper_l", "chest"), ("fore_lower_l", "fore_upper_l"), ("fore_foot_l", "fore_lower_l"),
    ("fore_upper_r", "chest"), ("fore_lower_r", "fore_upper_r"), ("fore_foot_r", "fore_lower_r"),
    ("hind_upper_l", "pelvis"), ("hind_lower_l", "hind_upper_l"), ("hind_foot_l", "hind_lower_l"),
    ("hind_upper_r", "pelvis"), ("hind_lower_r", "hind_upper_r"), ("hind_foot_r", "hind_lower_r"),
    ("tail_01", "pelvis"), ("tail_02", "tail_01"), ("tail_03", "tail_02"), ("tail_04", "tail_03"),
    ("spoon_prop", "chest"),
]


def mir(p):
    return Vector((p[0], -p[1], p[2]))


# ---------------------------------------------------------------- ring surfaces
def ring_pts(x, hw, hh, zc, sides, k, belly=1.0, jit=0.015, seed=0.0):
    out = []
    off = (math.pi / sides) * (k % 2)
    for j in range(sides):
        ph = 2 * math.pi * j / sides + off
        c = math.cos(ph)
        r = 1.0 + (rc.hrand(seed + k * 7.1 + j * 1.3) - 0.5) * 2 * jit
        z = zc + hh * c * (belly if c < 0 else 1.0) * r
        out.append(Vector((x, hw * math.sin(ph) * r, z)))
    return out


def lathe(mb, rings, caps, sides, wfn, colfn, part, belly=1.0, seed=0.0):
    loops = []
    for k, (x, hw, hh, zc) in enumerate(rings):
        loops.append([mb.vert(p, wfn(p)) for p in ring_pts(x, hw, hh, zc, sides, k, belly, seed=seed)])
    faces = []
    for k, (a, b) in enumerate(zip(loops, loops[1:])):
        for j in range(sides):
            j1 = (j + 1) % sides
            if k % 2 == 0:
                faces += [(a[j], a[j1], b[j]), (b[j], a[j1], b[j1])]
            else:
                faces += [(a[j], b[j1], b[j]), (a[j], a[j1], b[j1])]
    (xb, zb), (xf, zf) = caps
    cb = mb.vert((xb, 0, zb), wfn(Vector((xb, 0, zb))))
    cf = mb.vert((xf, 0, zf), wfn(Vector((xf, 0, zf))))
    for j in range(sides):
        faces.append((loops[0][(j + 1) % sides], loops[0][j], cb))
        faces.append((loops[-1][j], loops[-1][(j + 1) % sides], cf))
    for f in faces:
        ps = [mb.v[i] for i in f]
        n = (ps[1] - ps[0]).cross(ps[2] - ps[0])
        c = (ps[0] + ps[1] + ps[2]) / 3
        ax = axis_point(rings, c.x)
        if n.dot(c - ax) < 0:
            n = -n
        mat, col = colfn(n.normalized() if n.length > 1e-9 else Z, c)
        mb.face(f, mat, col, part, 0.07)


def axis_point(rings, x):
    if x <= rings[0][0]:
        return Vector((x, 0, rings[0][3]))
    for a, b in zip(rings, rings[1:]):
        if a[0] <= x <= b[0]:
            return Vector((x, 0, lerp(a[3], b[3], (x - a[0]) / (b[0] - a[0]))))
    return Vector((x, 0, rings[-1][3]))


def head_axis_z(x):
    H = P["HEAD"]
    if x <= H[0][0]:
        return H[0][3]
    for a, b in zip(H, H[1:]):
        if a[0] <= x <= b[0]:
            return lerp(a[3], b[3], (x - a[0]) / (b[0] - a[0]))
    return H[-1][3]


# ---------------------------------------------------------------- weights
def torso_w(p):
    x = p.x
    wp = smooth((-1.5 - x) / 9.0)
    wc = smooth((x + 0.5) / 8.0)
    wn = smooth((x - 9.0) / 3.5) * 0.55
    wc = wc * (1 - wn)
    wb = max(0.0, 1.0 - wp - wc - wn)
    return {"pelvis": wp, "chest": wc, "body": wb, "neck": wn}


def head_w(p):
    x = p.x
    wn = smooth((11.8 - x) / 4.2)
    wch = smooth((9.0 - x) / 2.4) * 0.5
    wj = smooth((x - 13.5) / 4.0) * smooth((head_axis_z(x) - 0.8 - p.z) / 2.2)
    wh = max(0.0, 1.0 - wn - wj)
    return {"neck": wn * (1 - wch), "chest": wn * wch, "jaw": wj, "head": wh}


# ---------------------------------------------------------------- part builders
def body_colfn(n, c):
    if n.z < -0.5 and -15.5 < c.x < 11.0:
        return "Belly", PAL["Belly"]
    return "Body", PAL["Body"]


def head_colfn(n, c):
    if n.z < -0.45 and c.x > 9.0 and abs(n.y) < 0.75:
        return "Belly", PAL["Belly"]
    return "Body", PAL["Body"]


def build_torso():
    mb = MB("Torso")
    lathe(mb, P["TORSO"], P["TORSO_CAPS"], P["TORSO_SIDES"], torso_w, body_colfn, PART["torso"], P["BELLY_FLAT"], 1.0)
    return mb


def build_head():
    mb = MB("Head")
    H = P["HEAD"]
    lathe(mb, H, (( P["HEAD_CAPS"][0], H[0][3]), (P["HEAD_CAPS"][1], H[-1][3])), P["HEAD_SIDES"], head_w, head_colfn,
          PART["head"], 0.95, 5.0)
    c, r = P["NOSE"]
    pts = []
    for i in range(10):
        a = 2 * math.pi * i / 10
        pts.append(Vector((c[0] - r[0] * 0.25, r[1] * math.cos(a), r[2] * math.sin(a))) + Vector((0, 0, c[2])))
    for i in range(6):
        a = 2 * math.pi * (i + 0.5) / 6
        pts.append(Vector((c[0] + r[0] * 0.7, r[1] * 0.62 * math.cos(a), c[2] + r[2] * 0.62 * math.sin(a))))
    pts.append(Vector((c[0] + r[0], 0, c[2] + 0.2)))
    pts.append(Vector((c[0] - r[0] * 1.2, 0, c[2])))
    rc.hull(mb, pts, {"head": 1.0}, "Pink", PAL["Pink"], PART["nose"], 0.05)
    return mb


def ear_frame(side=1):
    n = nrm(Vector(P["EAR_N"]) * Vector((1, side, 1)))
    up = Vector(P["EAR_UP"]) * Vector((1, side, 1))
    up = nrm(up - n * up.dot(n))
    sd = n.cross(up)
    c = Vector(P["EAR_C"]) * Vector((1, side, 1))
    return c, n, up, sd


def build_ear(side=1):
    mb = MB("Ear")
    c, n, up, sd = ear_frame(side)
    rw, rh = P["EAR_RW"], P["EAR_RH"]
    w = {"ear_l" if side > 0 else "ear_r": 1.0}
    K = 10

    def ring(scale, depth, jit_seed):
        out = []
        for i in range(K):
            a = 2 * math.pi * i / K + 0.2
            j = 1.0 + (rc.hrand(jit_seed + i) - 0.5) * 0.12
            out.append(c + (sd * rw * math.cos(a) + up * rh * math.sin(a)) * scale * j + n * depth)
        return out

    outer = [mb.vert(p, w) for p in ring(1.0, 0.0, 3.0)]
    inner = [mb.vert(p, w) for p in ring(0.6, -0.55, 9.0)]
    back = [mb.vert(p, w) for p in ring(0.72, -1.5, 13.0)]
    cf = mb.vert(c + n * -0.85, w)
    cb = mb.vert(c + n * -2.1, w)
    pin = tuple(x * 0.86 for x in PAL["Pink"])
    for i in range(K):
        i1 = (i + 1) % K
        mb.face((outer[i], outer[i1], inner[i1]), "Pink", PAL["Pink"], PART["ear"], 0.05)
        mb.face((outer[i], inner[i1], inner[i]), "Pink", PAL["Pink"], PART["ear"], 0.05)
        mb.face((inner[i], inner[i1], cf), "Pink", pin, PART["ear"], 0.05)
        mb.face((outer[i1], outer[i], back[i]), "Pink", PAL["Pink"], PART["ear"], 0.05)
        mb.face((outer[i1], back[i], back[i1]), "Pink", PAL["Pink"], PART["ear"], 0.05)
        mb.face((back[i1], back[i], cb), "Pink", PAL["Pink"], PART["ear"], 0.05)
    return mb


def leg_w_fn(chain, side, parent):
    sfx = "_l" if side > 0 else "_r"
    a, b, c, d = [Vector(p) * Vector((1, side, 1)) for p in chain]

    def t_on(p, s0, s1):
        dv = s1 - s0
        return max(0.0, min(1.0, (p - s0).dot(dv) / dv.length_squared))
    return a, b, c, d, sfx, t_on


def build_leg(kind, side=1):
    mb = MB("Leg")
    chain = P["FORE"] if kind == "fore" else P["HIND"]
    parent = "chest" if kind == "fore" else "pelvis"
    a, b, c, d, sfx, t_on = leg_w_fn(chain, side, parent)
    up_n, lo_n, ft_n = kind + "_upper" + sfx, kind + "_lower" + sfx, kind + "_foot" + sfx
    r0, r1, r2 = (3.8, 3.0, 2.3) if kind == "fore" else (6.0, 4.6, 2.9)
    pts = []
    for t, r in ((0.0, r0), (0.5, r1), (1.0, r2)):
        p = a.lerp(b, t) + Vector((0, 0, r0 * 0.25 if t == 0 else 0))
        e1, e2 = rc.ring_frame(b - a)
        for j in range(7):
            ang = 2 * math.pi * j / 7 + t
            pts.append(p + (e1 * math.cos(ang) + e2 * math.sin(ang)) * r)

    def wu(p):
        t = t_on(p, a, b)
        return rc.norm_w({up_n: 1.0 - 0.3 * smooth((0.3 - t) / 0.3) - 0.3 * smooth((t - 0.85) / 0.15),
                          parent: 0.3 * smooth((0.3 - t) / 0.3), lo_n: 0.3 * smooth((t - 0.85) / 0.15)})
    rc.hull(mb, pts, wu, "Body", PAL["Body"], PART["leg_upper"], 0.06)
    rl0, rl1 = (2.3, 1.6) if kind == "fore" else (2.5, 1.7)

    def wl(p):
        t = t_on(p, b, c)
        return rc.norm_w({lo_n: 1.0, up_n: 0.35 * smooth((0.2 - t) / 0.2), ft_n: 0.35 * smooth((t - 0.8) / 0.2)})
    seg = [b.lerp(c, t) for t in (0.0, 0.33, 0.66, 1.0)]
    rc.tube(mb, seg, [lerp(rl0, rl1, t) for t in (0.0, 0.33, 0.66, 1.0)], [wl(p) for p in seg], "Body", PAL["Body"],
            PART["leg_lower"], sides=6, ref=X, jitter=0.05)
    # paw: flattened hull along the floor + four toe bumps
    fw = 2.0 if kind == "fore" else 2.2
    x0 = c.x - (1.2 if kind == "fore" else 1.4)
    x1 = d.x + 0.3
    y0 = c.y
    paw = []
    for (fx, wf, h) in ((x0, 0.65, 2.4), (lerp(x0, x1, 0.4), 1.0, 2.6), (x1, 0.95, 1.6)):
        for sy in (-1, 1):
            for z in (0.0, h):
                paw.append(Vector((fx, y0 + sy * fw * wf, z)))
    paw.append(Vector((lerp(x0, x1, 0.35), y0, 3.0)))
    rc.hull(mb, paw, rc.norm_w({ft_n: 1.0}), "Pink", PAL["Pink"], PART["foot"], 0.05)
    for i, oy in enumerate((-1.45, -0.5, 0.5, 1.45)):
        tc = Vector((x1 + 0.35 - 0.25 * abs(oy), y0 + oy * fw * 0.62, 0.72))
        tp = [tc + Vector((math.cos(k * 2.1) * 0.72, math.sin(k * 2.1) * 0.62, 0)) for k in range(3)]
        tp += [tc + Vector((0, 0, 0.7)), tc + Vector((0.55, 0, 0.1)), Vector((tc.x, tc.y, 0.0)),
               tc + Vector((-0.8, 0, 0.4))]
        rc.hull(mb, tp, {ft_n: 1.0}, "Pink", PAL["Pink"], PART["foot"], 0.05)
    return mb


def catmull(pts, n_per):
    pts = [Vector(p) for p in pts]
    out = []
    for i in range(len(pts) - 1):
        p0 = pts[max(0, i - 1)]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[min(len(pts) - 1, i + 2)]
        for k in range(n_per):
            t = k / n_per
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
                              (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


def tail_bone_points():
    T = [Vector(p) for p in P["TAIL"]]
    return [T[i] for i in P["TAIL_BONE_IDX"]]


def build_tail():
    mb = MB("Tail")
    pts = catmull(P["TAIL"], 2)
    bp = tail_bone_points()
    names = ["tail_01", "tail_02", "tail_03", "tail_04"]
    # arc length
    L = [0.0]
    for a, b in zip(pts, pts[1:]):
        L.append(L[-1] + (b - a).length)
    tot = L[-1]
    # bone joint arc positions
    jl = []
    for q in bp:
        k = min(range(len(pts)), key=lambda i: (pts[i] - q).length)
        jl.append(L[k])
    radii, ws = [], []
    for s in L:
        t = s / tot
        r = lerp(P["TAIL_R"][0], P["TAIL_R"][1], t ** 0.85)
        seg = 0
        for i in range(4):
            if s >= jl[i] - 1e-6:
                seg = i
        w = {names[seg]: 1.0}
        dj = min(abs(s - jl[i]) for i in range(1, 4))
        if dj < 1.0:
            r *= 0.86   # segment constriction reads as the four tail segments
        for i in range(1, 4):
            if abs(s - jl[i]) < 1.6:
                f = 0.5 * (1 - abs(s - jl[i]) / 1.6)
                w = rc.blend_w((1 - f, w), (f, {names[i - 1] if s >= jl[i] else names[i]: 1.0}))
        if s < 1.5:
            w = rc.blend_w((0.6, w), (0.4, {"pelvis": 1.0}))
        radii.append(r)
        ws.append(w)
    rc.tube(mb, pts, radii, ws, "Pink", PAL["Pink"], PART["tail"], sides=6, ref=Z, jitter=0.05)
    return mb


def spoon_local_mb():
    """Spoon + two cuffs in spoon-local coords (handle end at origin, +X to the bowl, +Z bowl concave side)."""
    mb = MB("Spoon")
    w = {"spoon_prop": 1.0}
    LH, LN, BL, BW = P["SPOON_HANDLE"], P["SPOON_NECK"], P["SPOON_BOWL_HL"], P["SPOON_BOWL_HW"]
    xs = [0.0, 0.9, LH * 0.35, LH * 0.7, LH, LH + LN]
    hw = [1.45, 1.8, 1.75, 1.55, 1.3, 1.85]
    th = [0.62, 0.68, 0.66, 0.62, 0.58, 0.55]
    # handle: hexagonal faceted beam, flattened
    rc.tube(mb, [Vector((x, 0, 0)) for x in xs], hw, [w] * len(xs), "Wood", PAL["Wood"], PART["spoon"], sides=6,
            ref=Y, jitter=0.07, flat=0.55, stagger=False)
    for i in range(len(mb.v)):
        pass
    # bowl: concave dish, closed solid
    cx = LH + LN + BL - 0.6
    K = 12
    rim, inn, und = [], [], []
    for i in range(K):
        a = 2 * math.pi * i / K
        ca, sa = math.cos(a), math.sin(a)
        ex = BL * ca * (1.0 if ca > 0 else 0.92)
        rim.append(mb.vert((cx + ex, BW * sa, 0.9), w))
        inn.append(mb.vert((cx + ex * 0.78, BW * 0.78 * sa, 0.5), w))
        und.append(mb.vert((cx + ex * 0.86, BW * 0.86 * sa, -1.6), w))
    cin = mb.vert((cx, 0, -1.5), w)
    cun = mb.vert((cx, 0, -2.6), w)
    wood = PAL["Wood"]
    wood_in = tuple(x * 0.86 for x in wood)
    for i in range(K):
        i1 = (i + 1) % K
        mb.face((rim[i], rim[i1], inn[i1]), "Wood", wood, PART["spoon"], 0.07)
        mb.face((rim[i], inn[i1], inn[i]), "Wood", wood, PART["spoon"], 0.07)
        mb.face((inn[i], inn[i1], cin), "Wood", wood_in, PART["spoon"], 0.07)
        mb.face((rim[i1], rim[i], und[i]), "Wood", wood, PART["spoon"], 0.07)
        mb.face((rim[i1], und[i], und[i1]), "Wood", wood, PART["spoon"], 0.07)
        mb.face((und[i1], und[i], cun), "Wood", wood, PART["spoon"], 0.07)
    # cuffs (the spoon strap): leather sleeves round the handle at the band crossing and at the neck
    return mb


def add_cuff(mb, s_along, w):
    LH = P["SPOON_HANDLE"]
    xs = [s_along - 1.3, s_along - 0.4, s_along + 0.4, s_along + 1.3]
    # handle half width/thickness at s
    hwid = 1.75 if s_along < LH * 0.7 else 1.5
    rc.tube(mb, [Vector((x, 0, 0)) for x in xs], [hwid + 0.35] * 4, [w] * 4, "Harness", PAL["Harness"],
            PART["cuff"], sides=8, ref=Y, jitter=0.04, flat=0.66, stagger=False)


# ---------------------------------------------------------------- BVH helpers on MB data
def mb_tree(mbs, parts=None):
    vs, fs = [], []
    for mb in mbs:
        off = len(vs)
        vs.extend(mb.v)
        for f, pt in zip(mb.f, mb.fp):
            if parts is None or pt in parts:
                fs.append(tuple(i + off for i in f))
    return BVHTree.FromPolygons(vs, fs, all_triangles=False, epsilon=0.0)


def cast_to(tree, origin, direction):
    loc, n, idx, dist = tree.ray_cast(Vector(origin), nrm(direction), 500.0)
    return loc, n


def spoon_place(torso_tree, head_tree, spoon_mb_local, log_fn):
    """Rest placement: the handle end lies on the left hip, the spoon rests on the dorsal crest with SPOON_GAP
    clearance; the bowl rises over the right shoulder behind the head. Returns the 4x4 spoon matrix."""
    hx, hy = P["SPOON_H_XY"]
    bx, by = P["SPOON_B_XY"]
    gap = P["SPOON_GAP"]

    def surf(x, y):
        loc, n = cast_to(torso_tree, (x, y, 120.0), (0, 0, -1))
        return loc, n

    Hs, Hn = surf(hx, hy)
    Bs, Bn = surf(bx, by)
    mid_s, mid_n = surf((hx + bx) / 2, (hy + by) / 2)

    def frame(hz, bz):
        H = Vector((hx, hy, hz))
        Bc = Vector((bx, by, bz))
        d = nrm(Bc - H)
        up = nrm(mid_n - d * mid_n.dot(d))
        side = up.cross(d)
        R = Matrix((d, side, up)).transposed()
        M = R.to_4x4()
        M.translation = H
        return M

    def clearance(M):
        worst = 1e9
        for p in spoon_mb_local.v:
            q = M @ p
            loc, n, _, dist = torso_tree.find_nearest(q)
            s = dist if (q - loc).dot(n) >= 0 else -dist
            worst = min(worst, s)
        hd = 1e9   # unsigned: the ears are thin, a nearest-face sign test misreads them
        for p in spoon_mb_local.v:
            loc, n, _, dist = head_tree.find_nearest(M @ p)
            hd = min(hd, dist)
        return worst, hd

    ok = lambda r: r[0] >= gap and r[1] >= 1.0
    top = Bs.z + 16.0
    cands = []
    hz = Hs.z + 0.3
    while hz <= Hs.z + 8.0:   # joint search: every handle-end height, the lowest clearing bowl height for it
        if ok(clearance(frame(hz, top))):
            lo, hi = Bs.z, top
            for _ in range(22):
                mid = 0.5 * (lo + hi)
                if ok(clearance(frame(hz, mid))):
                    hi = mid
                else:
                    lo = mid
            cands.append(((hi - Bs.z) + 1.5 * (hz - Hs.z), hz, hi))
        hz += 0.25
    cost, hz, bz = min(cands)
    c, hd = clearance(frame(hz, bz))
    M = frame(hz, bz)
    log_fn("SPOON_PLACE handle_end_z %.2f (surface %.2f) bowl_axis_z %.2f (surface %.2f) torso_clear %.3f head_clear %.3f"
           % (hz, Hs.z, bz, Bs.z, c, hd))
    return M, {"handle_end_z": hz, "handle_surface_z": Hs.z, "bowl_axis_z": bz, "bowl_surface_z": Bs.z,
               "rest_torso_clearance": c, "rest_head_clearance": hd}


def build_band(torso_tree, spoon_M, spoon_assembly_world, log_fn):
    """Chest band round the torso at BAND_X, lifted over the spoon handle where they cross."""
    mb = MB("Band")
    bxp = P["BAND_X"]
    W, T, off = P["BAND_W"], P["BAND_T"], P["BAND_OFF"]
    # where the handle crosses the band plane
    H = spoon_M.translation
    d = spoon_M.to_3x3().col[0]
    t = (bxp - H.x) / d.x
    S = H + d * t
    upv = spoon_M.to_3x3().col[2]
    spoon_tree = BVHTree.FromPolygons(spoon_assembly_world.v, spoon_assembly_world.f, all_triangles=False)
    N = 48
    rings = []
    meta = []
    for i in range(N):
        ph = 2 * math.pi * i / N
        dirv = Vector((0, math.sin(ph), math.cos(ph)))
        # radius = the largest of the three hits across the strap width, so neither edge sinks into a facet
        best = None
        for dx in (-W / 2, 0.0, W / 2):
            ax = Vector((bxp + dx, 0, 22.0))
            l_, n_ = cast_to(torso_tree, ax + dirv * 60.0, -dirv)
            r_ = (Vector((0, l_.y, l_.z)) - Vector((0, 0, 22.0))).length
            if dx == 0.0:
                loc, n = l_, n_
            best = r_ if best is None else max(best, r_)
        n = nrm(Vector((0, n.y, n.z))) if Vector((0, n.y, n.z)).length > 1e-6 else dirv
        # radial placement (Phase 2): the inner face sits BAND_EMBED inside the widest hit across the strap width
        base = Vector((bxp, 0.0, 22.0)) + dirv * (best - P["BAND_EMBED"])
        n = dirv
        # lift over the spoon: if the band's outer face would touch the spoon assembly, push it out radially
        lift = 0.0
        for k in range(40):
            q_out = base + n * (T + lift)
            q_in = base + n * lift
            hit = False
            for q in (q_in, q_out, (q_in + q_out) * 0.5):
                l2, n2, _, d2 = spoon_tree.find_nearest(q)
                if l2 is not None and (d2 < 0.3 or (q - l2).dot(n2) < 0):
                    hit = True
            if not hit:
                break
            lift += 0.25
        meta.append((base, n, lift, loc))
    # smooth the lift so the band climbs over the handle instead of stepping
    lifts = [m[2] for m in meta]
    sm = []
    for i in range(N):
        sm.append(max(lifts[(i + k) % N] * (1 - abs(k) / 4.0) for k in range(-3, 4)))
    vrings = []
    for i, (base, n, _, loc) in enumerate(meta):
        lift = sm[i]
        fw = smooth(lift / 1.0)
        w = rc.blend_w((1 - fw, torso_w(loc)), (fw, {"spoon_prop": 1.0}))
        p_in = base + n * lift
        p_out = p_in + n * T
        ring = [mb.vert(p_in + X * (-W / 2), w), mb.vert(p_out + X * (-W / 2), w),
                mb.vert(p_out + X * (W / 2), w), mb.vert(p_in + X * (W / 2), w)]
        vrings.append(ring)
    hcol = PAL["Harness"]
    for i in range(N):
        a, b = vrings[i], vrings[(i + 1) % N]
        for j in range(4):
            j1 = (j + 1) % 4
            mb.face((a[j], a[j1], b[j1]), "Harness", hcol, PART["band"], 0.05)
            mb.face((a[j], b[j1], b[j]), "Harness", hcol, PART["band"], 0.05)
    log_fn("BAND x %.1f max_lift %.2f cross_point %s" % (bxp, max(sm), tuple(round(c, 2) for c in S)))
    return mb, S, t


def build_eye_patch(head_tree, side):
    mb = MB("EyePatch")
    ax = Vector(P["EYE_AXIS"])
    dirv = nrm(Vector(P["EYE_DIR"]) * Vector((1, side, 1)))
    Pc, N = cast_to(head_tree, ax + dirv * 40.0, -dirv)
    eu = nrm(Z - N * N.dot(Z))
    ef = nrm(X - N * N.dot(X) - eu * eu.dot(X))
    rs, ru, off = P["EYE_RS"], P["EYE_RU"], P["EYE_OFF"]
    w = {"head": 1.0}

    def proj(s, t):
        q = Pc + ef * s + eu * t
        loc, n = cast_to(head_tree, q + N * 6.0, -N)
        if loc is None:
            loc, n = q, N
        return loc + n * off

    def uv(s, t):
        f = s / rs   # +1 front, -1 back
        u = 0.25 + 0.25 * f if side > 0 else 0.75 - 0.25 * f
        return (u, 0.5 + 0.5 * t / ru)

    K = 9
    st = []
    for k in range(K):
        a = 2 * math.pi * k / K + 0.3
        blob = 1.0 + 0.1 * math.sin(2 * a + 1.0) - 0.05 * math.cos(3 * a)
        # blob shape of sheet 03 "head patches": a rounded pentagon leaning back
        s, t = rs * 0.96 * math.cos(a) * blob, ru * 0.96 * math.sin(a) * blob
        st.append((s, t))
    smax = max(abs(s) for s, _ in st)
    tmax = max(abs(t) for _, t in st)

    def uv(s, t):
        f = s / smax   # +1 front edge, -1 back edge
        u = 0.25 + 0.25 * f if side > 0 else 0.75 - 0.25 * f
        return (u, 0.5 + 0.5 * t / tmax)
    ids = [mb.vert(proj(s, t), w) for s, t in st]
    cen = mb.vert(proj(0, 0), w)
    uvs = [uv(s, t) for s, t in st]
    uvc = uv(0, 0)
    for k in range(K):
        k1 = (k + 1) % K
        tri = [ids[k], ids[k1], cen]
        tuv = [uvs[k], uvs[k1], uvc]
        a, b, c = (mb.v[i] for i in tri)
        if (b - a).cross(c - a).dot(N) < 0:
            tri, tuv = tri[::-1], tuv[::-1]
        mb.face(tri, "EyePatch", PAL["EyePatch"], PART["eyepatch"], 0.0, uv=tuv)
    return mb, Pc, N


# ---------------------------------------------------------------- scene
def reset_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.cameras, bpy.data.lights,
                 bpy.data.actions, bpy.data.curves, bpy.data.texts):
        for d in list(coll):
            coll.remove(d)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 0.01
    sc.unit_settings.length_unit = "CENTIMETERS"
    sc.render.fps = 30
    sc.render.fps_base = 1.0
    sc.frame_start, sc.frame_end = 0, 0
    colls = {}
    for n in ("Authoring", "Rig", "Export", "Props", "Review"):
        c = bpy.data.collections.new(n)
        sc.collection.children.link(c)
        colls[n] = c
    rc.MATS.clear()
    for s in rc.SLOTS:
        rc.MATS[s] = rc.make_material(s, PAL[s], 0.85 if s not in ("Wood", "Harness") else 0.7,
                                      eye_preview=(s == "EyePatch"))
    rc.MATS["Prop"] = rc.make_material("Prop", (0.5, 0.5, 0.5), 0.85)
    return colls


def bone_layout(spoon_M):
    F, Hd = P["FORE"], P["HIND"]
    tb = tail_bone_points()
    L = {
        "root": ((0, 0, 0), (0, 10, 0), None),
        "body": ((-3.0, 0, 22.0), (3.0, 0, 22.0), Z),
        "pelvis": ((-3.0, 0, 22.0), (-13.0, 0, 20.0), Z),
        "chest": ((3.0, 0, 22.0), (8.8, 0, 24.0), Z),
        "neck": ((8.8, 0, 24.0), (12.0, 0, 25.0), Z),
        "head": ((12.0, 0, 25.0), (20.9, 0, 22.4), Z),
        "jaw": ((13.8, 0, 21.4), (20.6, 0, 19.8), Z),
        "tail_01": (tuple(tb[0]), tuple(tb[1]), Z), "tail_02": (tuple(tb[1]), tuple(tb[2]), Z),
        "tail_03": (tuple(tb[2]), tuple(tb[3]), Z), "tail_04": (tuple(tb[3]), tuple(tb[4]), Z),
    }
    for side, sfx in ((1, "_l"), (-1, "_r")):
        s = Vector((1, side, 1))
        c, n, up, sd = ear_frame(side)
        base = c - up * P["EAR_RH"] * 0.7
        L["ear" + sfx] = (tuple(base), tuple(c + up * P["EAR_RH"] * 0.9), n)
        for kind, ch in (("fore", F), ("hind", Hd)):
            a, b, cc, d = [Vector(p) * s for p in ch]
            L[kind + "_upper" + sfx] = (tuple(a), tuple(b), X)
            L[kind + "_lower" + sfx] = (tuple(b), tuple(cc), X)
            L[kind + "_foot" + sfx] = (tuple(cc), tuple(d), Z)
    h = spoon_M.translation + spoon_M.to_3x3().col[0] * 9.0
    L["spoon_prop"] = (tuple(h), tuple(h + spoon_M.to_3x3().col[0] * 8.0), spoon_M.to_3x3().col[2])
    return L


def build_armature(coll, lay):
    ad = bpy.data.armatures.new(ARM_NAME)
    arm = bpy.data.objects.new(ARM_NAME, ad)
    coll.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.view_layer.objects:
        o.select_set(o is arm)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = ad.edit_bones
    for name, _ in BONE_PARENTS:
        h, t, roll = lay[name]
        e = eb.new(name)
        e.head, e.tail = Vector(h), Vector(t)
        e.use_deform = True
        if roll is None:
            e.roll = 0.0
        else:
            e.align_roll(Vector(roll))
    for name, par in BONE_PARENTS:
        if par:
            eb[name].parent = eb[par]
            eb[name].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    ad.display_type = "STICK"
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


# ---------------------------------------------------------------- props
def prop_object(mb, name, coll, M=None):
    ob = mb.to_object(name, coll, groups=False)
    if M is not None:
        ob.matrix_world = M
    return ob


def build_mushroom(name):
    """12 x 12 x 8 cm (Mushroom_Prep_Mars_SM bounds), stem down, pivot base centre."""
    mb = MB(name, rc.PROP_SLOTS)
    stem = []
    for z, r in ((0.0, 2.3), (2.6, 2.1), (4.2, 2.0)):
        for k in range(7):
            a = 2 * math.pi * k / 7
            stem.append(Vector((r * math.cos(a), r * math.sin(a), z)))
    rc.hull(mb, stem, None, "Prop", PAL["mush_stem"], 0, 0.05)
    cap = []
    for z, r in ((3.6, 6.0), (4.4, 6.0), (6.6, 4.6), (8.0, 1.4)):
        for k in range(10):
            a = 2 * math.pi * k / 10 + z
            cap.append(Vector((r * math.cos(a), r * math.sin(a), z)))
    rc.hull(mb, cap, None, "Prop", PAL["mush_cap"], 0, 0.06)
    # exact bounds: clamp to 12 x 12 x 8
    xs = [v.x for v in mb.v]
    ys = [v.y for v in mb.v]
    sx = 12.0 / (max(xs) - min(xs))
    sy = 12.0 / (max(ys) - min(ys))
    for v in mb.v:
        v.x *= sx
        v.y *= sy
    return mb


def build_cheese():
    """Monk's Rind wedge: ~15 long x 10 wide x 8 tall, orange rind over ivory flesh, pivot base centre."""
    mb = MB("Cheese_MonksRind", rc.PROP_SLOTS)
    tip = 7.5
    arc = []
    K = 7
    for k in range(K):
        a = -0.5 + k / (K - 1)
        y = 5.0 * a * 2
        x = -6.6 - 0.9 * (1 - (2 * a) ** 2)
        arc.append((x, y))
    H = 8.0
    rind_in = 1.0   # rind thickness on the back face
    bottom, top, tip_b, tip_t = [], [], None, None
    ring_b = [mb.vert((x, y, 0.0)) for x, y in arc]
    ring_t = [mb.vert((x, y, H)) for x, y in arc]
    inset_b = [mb.vert((x + rind_in, y * 0.9, 0.0)) for x, y in arc]
    inset_t = [mb.vert((x + rind_in, y * 0.9, H - 0.6)) for x, y in arc]
    tb = mb.vert((tip, 0.0, 0.0))
    tt = mb.vert((tip, 0.0, H - 0.6))
    rind, fl = PAL["rind"], PAL["flesh"]
    for k in range(K - 1):
        k1 = k + 1
        mb.face((ring_b[k], ring_b[k1], ring_t[k1], ring_t[k]), "Prop", rind, 0, 0.05)       # back rind face
        mb.face((ring_t[k], ring_t[k1], inset_t[k1], inset_t[k]), "Prop", rind, 0, 0.05)     # top rind rim
        mb.face((inset_t[k], inset_t[k1], tt), "Prop", fl, 0, 0.04)                           # top flesh
        mb.face((ring_b[k1], ring_b[k], inset_b[k], inset_b[k1]), "Prop", rind, 0, 0.05)     # bottom rind rim
        mb.face((inset_b[k1], inset_b[k], tb), "Prop", fl, 0, 0.04)
    for side in (0, K - 1):
        o, it, ib = ring_t[side], inset_t[side], inset_b[side]
        ob_ = ring_b[side]
        if side == 0:
            mb.face((ob_, ring_t[0], inset_t[0], inset_b[0]), "Prop", rind, 0, 0.05)
            mb.face((inset_b[0], inset_t[0], tt, tb), "Prop", fl, 0, 0.04)
        else:
            mb.face((ring_t[side], ob_, inset_b[side], inset_t[side]), "Prop", rind, 0, 0.05)
            mb.face((inset_t[side], inset_b[side], tb, tt), "Prop", fl, 0, 0.04)
    # pivot base centre
    xs = [v.x for v in mb.v]
    cx = 0.5 * (max(xs) + min(xs))
    for v in mb.v:
        v.x -= cx
    return mb


def build_den(colls, M_den):
    """Stone Arch: 60 x 60 cm opening (semicircular head on 30 cm jambs), 45 cm recess, black back plane, paired-eye
    plate. Den local: opening faces +X, the opening's floor centre at the origin, the recess runs to -X."""
    objs = {}
    R_in, R_out, depth_front, depth_back = 30.0, 50.0, 3.5, -24.0
    stones = MB("Den_StoneArch_Shell", rc.PROP_SLOTS)
    seg = 7
    for i in range(seg):
        a0 = math.pi * i / seg - 0.01
        a1 = math.pi * (i + 1) / seg + 0.01
        pts = []
        for a in (a0, (a0 + a1) / 2, a1):
            for r, xf in ((R_in, depth_front), (R_out + 3.0 * rc.hrand(i + 0.3), depth_front + 0.8 * rc.hrand(i)),
                          (R_in, depth_back), (R_out + 2.0 * rc.hrand(i + 4.1), depth_back)):
                rr = r if r == R_in else r
                pts.append(Vector((xf, rr * math.cos(a), 30.0 + rr * math.sin(a))))
        # chunky bevel: pull the front-outer middle forward
        pts.append(Vector((depth_front + 1.8, (R_in + R_out) / 2 * math.cos((a0 + a1) / 2),
                           30.0 + (R_in + R_out) / 2 * math.sin((a0 + a1) / 2))))
        col = PAL["stone"] if i % 2 == 0 else PAL["stone_d"]
        rc.hull(stones, pts, None, "Prop", col, 0, 0.07)
    for sy in (-1, 1):
        for (z0, z1, ext, fwd) in ((0.0, 15.0, 6.0, 4.5), (15.0, 30.5, 2.0, 1.5)):
            pts = []
            for z in (z0, z1):
                for y in (R_in, R_out + ext):
                    for x in (depth_front + fwd, depth_back):
                        pts.append(Vector((x, sy * y, z)))
            pts.append(Vector((depth_front + fwd + 1.5, sy * (R_in + R_out + ext) / 2, (z0 + z1) / 2)))
            rc.hull(stones, pts, None, "Prop", PAL["stone_d"] if z0 == 0 else PAL["stone"], 0, 0.07)
    objs["shell"] = prop_object(stones, "Den_StoneArch_Shell", colls["Props"])
    # recess tunnel: thick shell of the opening profile from the arch back to the back plane, floor included
    tun = MB("Den_Recess", rc.PROP_SLOTS)
    r1, r2 = 30.6, 34.0
    prof_in, prof_out = [], []
    K = 12
    prof_in.append((-r1, 0.05))
    prof_out.append((-r2, 0.05))
    for k in range(K + 1):
        a = math.pi - math.pi * k / K
        prof_in.append((r1 * math.cos(a), 30.0 + r1 * math.sin(a)))
        prof_out.append((r2 * math.cos(a), 30.0 + r2 * math.sin(a)))
    prof_in.append((r1, 0.05))
    prof_out.append((r2, 0.05))
    x0, x1 = depth_back + 2.0, -47.0
    rings = []
    for x in (x0, x1):
        rings.append(([tun.vert((x, y, z)) for y, z in prof_in], [tun.vert((x, y, z)) for y, z in prof_out]))
    vd = PAL["void"]
    n = len(prof_in)
    for i in range(n - 1):
        a_in, b_in = rings[0][0], rings[1][0]
        a_out, b_out = rings[0][1], rings[1][1]
        tun.face((a_in[i], b_in[i], b_in[i + 1], a_in[i + 1]), "Prop", vd, 0, 0.0)
        tun.face((a_out[i + 1], b_out[i + 1], b_out[i], a_out[i]), "Prop", vd, 0, 0.0)
        for (ri, ro) in ((rings[0][0], rings[0][1]), (rings[1][0], rings[1][1])):
            tun.face((ri[i], ri[i + 1], ro[i + 1], ro[i]), "Prop", vd, 0, 0.0)
    # recess floor slab (closes the profile at the bottom)
    rc.box(tun, ((x0 + x1) / 2, 0, -0.5), (abs(x1 - x0), 2 * r2, 1.0), "Prop", vd, 0)
    rc.box(tun, ((depth_front + depth_back) / 2 - 1.0, 0, -0.5), (depth_front - depth_back + 2.0, 2 * R_in, 1.0),
           "Prop", vd, 0)
    objs["recess"] = prop_object(tun, "Den_Recess", colls["Props"])
    bp = MB("Den_BackPlane", rc.PROP_SLOTS)
    rc.box(bp, (-45.5, 0, 33.0), (1.0, 2 * r2 + 1.0, 66.0), "Prop", PAL["void"], 0)
    objs["back"] = prop_object(bp, "Den_BackPlane", colls["Props"])
    # eye plate: 20 x 8, centred 22 cm above the floor, 2 cm proud of the back plane; one paired UV quad (U 0..1)
    ep = MB("Den_EyePlate", ("EyePatch",))
    xs = -43.0
    q = [ep.vert((xs, 10.0, 18.0)), ep.vert((xs, -10.0, 18.0)), ep.vert((xs, -10.0, 26.0)), ep.vert((xs, 10.0, 26.0))]
    b = [ep.vert((xs - 0.6, 10.0, 18.0)), ep.vert((xs - 0.6, -10.0, 18.0)), ep.vert((xs - 0.6, -10.0, 26.0)),
         ep.vert((xs - 0.6, 10.0, 26.0))]
    # U = 0 at the den's +Y (a resident rat's LEFT), 1 at -Y; V up. Front face normal +X.
    ep.face((q[1], q[0], q[3]), "EyePatch", PAL["plate"], 0, 0.0, uv=[(1, 0), (0, 0), (0, 1)])
    ep.face((q[1], q[3], q[2]), "EyePatch", PAL["plate"], 0, 0.0, uv=[(1, 0), (0, 1), (1, 1)])
    for i in range(4):
        i1 = (i + 1) % 4
        ep.face((q[i1], q[i], b[i]), "EyePatch", PAL["plate"], 0, 0.0, uv=[(0, 0)] * 3)
        ep.face((q[i1], b[i], b[i1]), "EyePatch", PAL["plate"], 0, 0.0, uv=[(0, 0)] * 3)
    ep.face((b[2], b[1], b[0]), "EyePatch", PAL["plate"], 0, 0.0, uv=[(0, 0)] * 3)
    ep.face((b[3], b[2], b[0]), "EyePatch", PAL["plate"], 0, 0.0, uv=[(0, 0)] * 3)
    eob = ep.to_object("Den_EyePlate", colls["Props"], groups=False)
    write_mb_uvs(eob, ep, fill_rest=False)
    objs["plate"] = eob
    # court wall around the den
    wall = MB("Den_Wall", rc.PROP_SLOTS)
    for (cy, wy, z0, z1) in ((150.0, 232.0, 0.0, 150.0), (-150.0, 232.0, 0.0, 150.0)):
        rc.box(wall, (-32.0, cy + (17.0 if cy > 0 else -17.0), (z0 + z1) / 2), (16.0, wy, z1 - z0), "Prop",
               PAL["wall"], 0, jitter=0.03)
    rc.box(wall, (-32.0, 0.0, 107.0), (16.0, 70.0, 86.0), "Prop", PAL["wall"], 0, jitter=0.03)
    objs["wall"] = prop_object(wall, "Den_Wall", colls["Props"])
    root = bpy.data.objects.new("Den_StoneArch", None)
    colls["Props"].objects.link(root)
    root.matrix_world = M_den
    for o in objs.values():
        o.parent = root
    markers = {"EntryPortal": (24.0, -14.0, 0.0), "ExitPortal": (24.0, 14.0, 0.0), "OutsideStand": (75.0, 0.0, 0.0),
               "ReturnAdmission": (48.0, 0.0, 0.0)}
    mk = {}
    for name, loc in markers.items():
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = "ARROWS"
        e.empty_display_size = 10.0
        colls["Props"].objects.link(e)
        e.parent = root
        e.location = loc
        mk[name] = e
    return root, objs, mk, {"opening_half_width": R_in, "spring_z": 30.0, "opening_height": 30.0 + R_in,
                            "recess_depth_from_front": 45.0 + 0.0, "front_plane_x": 0.0, "back_plane_x": -45.0,
                            "eye_plate_x": xs, "eye_plate_size": [20.0, 8.0], "eye_plate_centre_z": 22.0}


def write_mb_uvs(ob, mb, fill_rest=True):
    me = ob.data
    if "UV0" not in me.uv_layers:
        me.uv_layers.new(name="UV0")
    uvl = me.uv_layers["UV0"]
    for poly in me.polygons:
        uv = mb.fuv[poly.index]
        if uv is None:
            continue
        for k, li in enumerate(poly.loop_indices):
            uvl.data[li].uv = uv[k]


# ---------------------------------------------------------------- poses
FOOT_KEYS = ("fore_l", "fore_r", "hind_l", "hind_r")


def leg_rest(kind, side):
    ch = P["FORE"] if kind == "fore" else P["HIND"]
    s = Vector((1, side, 1))
    return [Vector(p) * s for p in ch]


def apply_pose(arm, pose):
    """pose: {"rot": {bone: [(axis, deg), ...]}, "loc": {bone: (x,y,z) armature-space delta},
              "orbit": {bone: (axis, deg, pivot)}, "feet": {key: (frame, ankle, toe, up)}}
    Rotations are armature-space, applied about the bone head after its parent, children follow. Feet: 2-bone IK to
    an ankle target and an aim of the foot at a toe target; targets are rest-space points carried by `frame`
    ("world" = armature space, or a bone name: the point moves with that bone's posed delta)."""
    pbs = arm.pose.bones
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    rots = pose.get("rot", {})
    locs = pose.get("loc", {})
    orbits = pose.get("orbit", {})
    feet = pose.get("feet", {})
    leg_bones = set()
    for key in feet:
        kind, sfx = key.split("_")
        leg_bones |= {kind + "_upper_" + sfx, kind + "_lower_" + sfx, kind + "_foot_" + sfx}
    for name, _ in BONE_PARENTS:
        if name in leg_bones or name == "root":
            continue
        pb = pbs[name]
        if name in pose.get("aim_dir", {}):
            m = rc.inherited(pb)
            rc.aim(pb, m.translation + nrm(Vector(pose["aim_dir"][name])) * pb.bone.length)
            bpy.context.view_layer.update()
            continue
        q = Quaternion()
        for ax, deg in rots.get(name, []):
            axv = {"X": X, "Y": Y, "Z": Z}[ax] if isinstance(ax, str) else Vector(ax)
            q = Quaternion(nrm(axv), math.radians(deg)) @ q
        loc = locs.get(name)
        if name in orbits:
            ax, deg, piv = orbits[name]
            axv = {"X": X, "Y": Y, "Z": Z}[ax] if isinstance(ax, str) else Vector(ax)
            qo = Quaternion(nrm(axv), math.radians(deg))
            m = rc.inherited(pb)
            head = m.translation
            piv = Vector(piv)
            if isinstance(pose.get("orbit_frame", {}).get(name), str):
                fd = rc.bone_delta(arm, pose["orbit_frame"][name])
                piv = fd @ piv
            newh = piv + qo @ (head - piv)
            q = qo @ q
            loc = Vector(loc or (0, 0, 0)) + (newh - head)
        rc.set_world_rot(pb, q, loc)
        bpy.context.view_layer.update()
    for key, spec in feet.items():
        kind, sfx = key.split("_")
        side = 1 if sfx == "l" else -1
        frame, ankle, toe, upv = spec
        a, b, c, d = leg_rest(kind, side)
        ankle = c if ankle is None else Vector(ankle)
        toe = d if toe is None else Vector(toe)
        if frame != "world":
            Dm = rc.bone_delta(arm, frame)
            ankle, toe = Dm @ ankle, Dm @ toe
            upw = (Dm.to_3x3() @ Vector(upv)) if upv is not None else None
        else:
            upw = Vector(upv) if upv is not None else None
        up_b, lo_b, ft_b = (pbs[kind + p + "_" + sfx] for p in ("_upper", "_lower", "_foot"))
        par = rc.bone_delta(arm, "chest" if kind == "fore" else "pelvis")
        hip = (par @ a)
        pole_local = Vector((-1, 0.25 * side, 0)) if kind == "fore" else Vector((1, 0.25 * side, 0))
        pole = par.to_3x3() @ pole_local
        knee, ank = rc.ik2(hip, ankle, (b - a).length, (c - b).length, pole)
        rc.aim(up_b, knee)
        bpy.context.view_layer.update()
        rc.aim(lo_b, ank)
        bpy.context.view_layer.update()
        rc.aim(ft_b, toe, upw if upw is not None else Z)
        bpy.context.view_layer.update()
    if pose.get("tail_floor", True):
        tail_floor_guard(arm)
    bpy.context.view_layer.update()


TAIL_JOINT_R = {"tail_01": 1.95, "tail_02": 1.45, "tail_03": 1.0, "tail_04": 0.6}


def tail_floor_guard(arm, margin=0.8):
    """Keep every tail joint at least its radius + margin above the floor (z = 0) by pitching that segment up,
    heading kept; the following segments inherit the lift."""
    for name in ("tail_01", "tail_02", "tail_03", "tail_04"):
        pb = arm.pose.bones[name]
        head, tail = pb.head.copy(), pb.tail.copy()
        zmin = TAIL_JOINT_R[name] + margin
        if tail.z >= zmin:
            continue
        L = (tail - head).length
        dz = max(-1.0, min(1.0, (zmin - head.z) / L))
        hor = Vector((tail.x - head.x, tail.y - head.y, 0.0))
        hor = hor.normalized() if hor.length > 1e-6 else Vector((-1, 0, 0))
        d = hor * math.sqrt(max(0.0, 1 - dz * dz)) + Z * dz
        q_cur = (tail - head).normalized().rotation_difference(d)
        m = rc.inherited(pb)
        world_now = m.to_quaternion() @ pb.matrix_basis.to_quaternion()
        pb.rotation_quaternion = m.to_quaternion().inverted() @ (q_cur @ world_now)
        bpy.context.view_layer.update()


def planted():
    return {k: ("world", None, None, Z) for k in FOOT_KEYS}


def pose_library():
    L = {}
    L["neutral"] = {}
    L["crouch"] = {
        "loc": {"body": (-0.6, 0, -2.9)},
        "rot": {"pelvis": [("Y", 4.0)], "chest": [("Y", 5.0)], "neck": [("Y", 9.0)], "head": [("Y", 4.0)],
                "ear_l": [("Y", -34.0), ("X", 12.0)], "ear_r": [("Y", -34.0), ("X", -12.0)],
                "tail_01": [("Y", 8.0)], "tail_02": [("Y", -6.0)]},
        "feet": planted()}
    L["stretch"] = {
        "loc": {"body": (2.4, 0, -3.0), "chest": (5.6, 0, 0.6), "neck": (2.4, 0, 0.0)},
        "rot": {"pelvis": [("Y", 3.0)], "chest": [("Y", -3.0)], "neck": [("Y", -4.0)], "head": [("Y", -8.0)],
                "ear_l": [("Y", -18.0)], "ear_r": [("Y", -18.0)],
                },
        "aim_dir": {"tail_01": (-1, 0, -0.32), "tail_02": (-1, 0, -0.12), "tail_03": (-1, 0, -0.02),
                    "tail_04": (-1, 0, 0.08)},
        "feet": {"hind_l": ("world", None, None, Z), "hind_r": ("world", None, None, Z),
                 "fore_l": ("world", leg_rest("fore", 1)[2] + Vector((9.0, 0, 0)),
                            leg_rest("fore", 1)[3] + Vector((9.0, 0, 0)), Z),
                 "fore_r": ("world", leg_rest("fore", -1)[2] + Vector((9.0, 0, 0)),
                            leg_rest("fore", -1)[3] + Vector((9.0, 0, 0)), Z)}}
    L["bound_apex"] = {
        "loc": {"body": (0, 0, 8.0)},
        "rot": {"body": [("Y", -3.0)], "head": [("Y", -4.0)], "ear_l": [("Y", -14.0)], "ear_r": [("Y", -14.0)]},
        "aim_dir": {"tail_01": (-1, 0, -0.15), "tail_02": (-1, 0, 0.0), "tail_03": (-1, 0, 0.12),
                    "tail_04": (-1, 0, 0.3)},
        "feet": {"fore_l": ("body", leg_rest("fore", 1)[2] + Vector((5.0, 0, 6.5)),
                            leg_rest("fore", 1)[3] + Vector((5.0, 0, 5.0)), Z),
                 "fore_r": ("body", leg_rest("fore", -1)[2] + Vector((5.0, 0, 6.5)),
                            leg_rest("fore", -1)[3] + Vector((5.0, 0, 5.0)), Z),
                 "hind_l": ("body", leg_rest("hind", 1)[2] + Vector((-5.0, 0, 4.0)),
                            leg_rest("hind", 1)[3] + Vector((-3.0, 0, 2.0)), Z),
                 "hind_r": ("body", leg_rest("hind", -1)[2] + Vector((-5.0, 0, 4.0)),
                            leg_rest("hind", -1)[3] + Vector((-3.0, 0, 2.0)), Z)}}
    hip_piv = (P["HIND"][0][0], 0.0, P["HIND"][0][2])
    L["rear_up"] = rear_pose(62.0, 20.0, tuck=True)
    L["jaw_carry"] = {
        "rot": {"neck": [("Y", -5.0)], "head": [("Y", -9.0)], "tail_01": [("Y", -6.0)]},
        "feet": planted()}
    L["look_back"] = None   # solved (yaw search)
    L["topple_left"] = topple_pose(1)
    L["topple_right"] = topple_pose(-1)
    L["dead_back"] = None   # solved (roll + spoon slide search)
    L["den_crouch"] = {
        "loc": {"body": (-0.4, 0, -3.1)},
        "rot": {"pelvis": [("Y", 5.0)], "chest": [("Y", 6.0)], "neck": [("Y", 8.0)], "head": [("Y", 2.0)],
                "ear_l": [("Y", -46.0), ("X", 18.0)], "ear_r": [("Y", -46.0), ("X", -18.0)],
                "tail_01": [("Y", 4.0)], "tail_02": [("Y", -4.0)]},
        "feet": planted()}
    return L


def rear_pose(pitch, neck_up, tuck=True, fore_targets=None, head_up=0.0):
    hip_piv = (P["HIND"][0][0], 0.0, P["HIND"][0][2])
    pose = {"orbit": {"body": ("Y", -pitch, hip_piv)},
            "rot": {"neck": [("Y", pitch * 0.55 - neck_up)], "head": [("Y", pitch * 0.3 - head_up)],
                    "ear_l": [("Y", -8.0)], "ear_r": [("Y", -8.0)]},
            "aim_dir": {"tail_01": (-0.55, 0, -1.0), "tail_02": (-1, 0, -0.35), "tail_03": (-1, 0, 0.0),
                        "tail_04": (-1, 0, 0.3)},
            "feet": {"hind_l": ("world", None, None, Z), "hind_r": ("world", None, None, Z)}}
    if tuck:
        for side, sfx in ((1, "l"), (-1, "r")):
            a, b, c, d = leg_rest("fore", side)
            pose["feet"]["fore_" + sfx] = ("chest", c + Vector((8.0, -side * 0.5, 7.5)),
                                           d + Vector((5.0, -side * 0.5, 10.0)), X)
    elif fore_targets:
        pose["feet"].update(fore_targets)
    return pose


def topple_pose(side):
    """side +1: lying on the LEFT side (+Y down); -1: on the right side."""
    pose = {"rot": {"body": [("X", -88.0 * side)], "neck": [("Z", 6.0 * side), ("X", -8.0 * side)],
                    "head": [("Y", -6.0)], "tail_01": [("Z", 18.0 * side)], "tail_02": [("Z", 12.0 * side)],
                    "jaw": [("Y", -8.0)], "ear_l": [("Y", -10.0)], "ear_r": [("Y", -10.0)]},
            "loc": {"body": (0, 0, 0)},
            "feet": {}}
    for kind in ("fore", "hind"):
        for s, sfx in ((1, "l"), (-1, "r")):
            a, b, c, d = leg_rest(kind, s)
            fx = 3.0 if kind == "fore" else -2.0
            pose["feet"][kind + "_" + sfx] = ("body", c + Vector((fx, s * 2.5, 3.5)), d + Vector((fx + 1.5, s * 3.0, 3.0)),
                                              Z)
    return pose


def dead_pose(dev, slide):
    """Belly up (roll 180 + dev about X), spoon slid round the torso axis by `slide` deg (strap slack)."""
    pose = {"rot": {"body": [("X", 180.0 + dev)], "neck": [("Y", 10.0)], "head": [("Y", 12.0), ("X", 25.0)],
                    "jaw": [("Y", -10.0)], "tail_01": [("Z", 25.0)], "tail_02": [("Z", 18.0)],
                    "ear_l": [("Y", 20.0)], "ear_r": [("Y", 20.0)]},
            "orbit": {"spoon_prop": ("X", slide, (0.0, 0.0, 22.0))},
            "orbit_frame": {"spoon_prop": "chest"},
            "loc": {"body": (0, 0, 0)},
            "feet": {}}
    for kind in ("fore", "hind"):
        for s, sfx in ((1, "l"), (-1, "r")):
            a, b, c, d = leg_rest(kind, s)
            fx = 2.5 if kind == "fore" else -1.5
            pose["feet"][kind + "_" + sfx] = ("body", c + Vector((fx, s * 2.0, 4.5)), d + Vector((fx + 1.0, s * 2.5, 6.5)),
                                              Z)
    return pose


# ---------------------------------------------------------------- audits / measurements
GROUPS = {
    "torso": (PART["torso"], PART["leg_upper"]),
    "torso_only": (PART["torso"],),
    "head": (PART["head"], PART["nose"], PART["ear"], PART["eyepatch"]),
    "head_solid": (PART["head"], PART["nose"], PART["ear"]),
    "headonly": (PART["head"],),
    "spoon": (PART["spoon"], PART["cuff"]),
    "harness": (PART["band"], PART["cuff"]),
    "band": (PART["band"],),
    "legs": (PART["leg_lower"], PART["foot"]),
    "feet": (PART["foot"],),
    "patch": (PART["eyepatch"],),
    "nonspoon": tuple(v for k, v in PART.items() if k not in ("spoon", "cuff", "band")),
}


def rat_soup(body):
    co, tris, tp = rc.evaluated_tris(body)
    return rc.Soup(co, tris, tp)


def audit_pose(body, proxy_objs=()):
    s = rat_soup(body)
    t = {k: s.tree(k, v) for k, v in GROUPS.items()}
    sp_ids = s.vert_ids(GROUPS["spoon"])
    band_ids = s.vert_ids(GROUPS["band"])
    patch_ids = s.vert_ids(GROUPS["patch"])
    co = s.co
    res = {}
    res["spoon_vs_torso_tris"] = rc.overlap_count(t["spoon"][0], t["torso"][0])
    res["spoon_vs_torso_clear_cm"] = round(rc.signed_clearance(co[sp_ids], t["torso"][0]), 3)
    res["spoon_min_z_cm"] = round(float(co[sp_ids][:, 2].min()), 3)
    res["spoon_below_floor_verts"] = int((co[sp_ids][:, 2] < -0.2).sum())
    res["harness_vs_torso_tris"] = rc.overlap_count(t["band"][0], t["torso_only"][0])
    res["harness_vs_torso_clear_cm"] = round(rc.signed_clearance(co[band_ids], t["torso_only"][0]), 3)
    # inner-face float: the band's inner verts (every other ring vertex is inner) farthest from the torso surface
    res["band_float_max_cm"] = round(rc.max_distance_to(co[band_ids], t["torso_only"][0]), 3)
    res["head_vs_spoon_tris"] = rc.overlap_count(t["head"][0], t["spoon"][0])
    res["head_vs_spoon_dist_cm"] = round(rc.min_distance_to(co[sp_ids], t["head_solid"][0]), 3)
    res["legs_vs_torso_tris"] = rc.overlap_count(t["legs"][0], t["torso_only"][0])
    res["feet_vs_torso_tris"] = rc.overlap_count(t["feet"][0], t["torso_only"][0])
    res["below_floor_verts"] = int((co[:, 2] < -0.2).sum())
    low = {}
    for pn, pid in PART.items():
        ids = s.vert_ids((pid,))
        if len(ids):
            mz = float(co[ids][:, 2].min())
            if mz < -0.2:
                low[pn] = round(mz, 3)
    res["below_floor_parts"] = low
    res["min_z_cm"] = round(float(co[:, 2].min()), 3)
    ns = s.vert_ids(GROUPS["nonspoon"])
    res["body_min_z_cm"] = round(float(co[ns][:, 2].min()), 3)
    res["body_lift_by_spoon_cm"] = round(max(0.0, float(co[ns][:, 2].min()) - float(co[:, 2].min())), 3)
    res["eye_patch_detach_cm"] = round(rc.max_distance_to(co[patch_ids], t["headonly"][0]), 3)
    res["height_cm"] = round(float(co[:, 2].max()), 3)
    res["height_no_spoon_cm"] = round(float(co[ns][:, 2].max()), 3)
    res["x_extent_cm"] = round(float(co[:, 0].max() - co[:, 0].min()), 3)
    res["y_extent_cm"] = round(float(co[:, 1].max() - co[:, 1].min()), 3)
    if proxy_objs:
        ptree, pverts = rc.tree_from_world(proxy_objs)
        pv = np.array([tuple(v) for v in pverts])
        res["carry_proxy_vs_chest_tris"] = len(ptree.overlap(t["torso"][0]))
        res["carry_proxy_vs_chest_clear_cm"] = round(rc.min_distance_to(pv, t["torso"][0]), 3)
        res["carry_proxy_vs_legs_tris"] = len(ptree.overlap(t["legs"][0]))
        res["carry_proxy_vs_spoon_tris"] = len(ptree.overlap(t["spoon"][0]))
        res["carry_proxy_vs_spoon_clear_cm"] = round(rc.min_distance_to(pv, t["spoon"][0]), 3)
        res["carry_proxy_min_z_cm"] = round(float(pv[:, 2].min()), 3)
    else:
        for k in ("carry_proxy_vs_chest_tris", "carry_proxy_vs_chest_clear_cm", "carry_proxy_vs_spoon_tris",
                  "carry_proxy_vs_spoon_clear_cm"):
            res[k] = "n/a"
    return res


def pose_ok(a, carry=False):
    bad = []
    if a["spoon_vs_torso_tris"] or a["spoon_vs_torso_clear_cm"] < 0:
        bad.append("spoon-torso")
    if a["spoon_below_floor_verts"]:
        bad.append("spoon-floor")
    if a["harness_vs_torso_clear_cm"] < -0.2 - 1e-3:   # Phase 2: the band hugs the torso, <= 0.2 cm embed allowed
        bad.append("harness-torso")
    if a["head_vs_spoon_tris"]:
        bad.append("head-spoon")
    if a["below_floor_verts"]:
        bad.append("below-floor")
    if a["eye_patch_detach_cm"] > 0.6:
        bad.append("patch-detach")
    if a["body_lift_by_spoon_cm"] > 0.3:
        bad.append("spoon-lifts-body")
    if carry and (a["carry_proxy_vs_chest_tris"] or a["carry_proxy_vs_spoon_tris"]):
        bad.append("carry-proxy")
    return bad


def settle(arm, body, pose, tol=0.0):
    """Translate `body` so the lowest rat vertex rests on the floor (z = 0)."""
    for _ in range(3):
        apply_pose(arm, pose)
        co, _, _ = rc.evaluated_tris(body)
        mz = float(co[:, 2].min())
        if abs(mz - tol) < 0.02:
            break
        l = Vector(pose.setdefault("loc", {}).get("body", (0, 0, 0)))
        pose["loc"]["body"] = tuple(l + Vector((0, 0, tol - mz)))
    apply_pose(arm, pose)
    return pose


def jaw_tip(arm):
    pb = arm.pose.bones["jaw"]
    return pb.tail.copy()


def nose_tip(arm, body):
    """Most forward point of the nose part along the head axis (armature space)."""
    co, tris, tp = rc.evaluated_tris(body)
    s = rc.Soup(co, tris, tp)
    ids = s.vert_ids((PART["nose"],))
    pts = co[ids]
    hb = arm.pose.bones["head"]
    d = np.array(hb.y_axis.normalized())
    k = int(np.argmax(pts @ d))
    return Vector(pts[k]), pts


def capture(arm):
    return {pb.name: (tuple(pb.rotation_quaternion), tuple(pb.location)) for pb in arm.pose.bones}


def store_action(arm, name, cap):
    act = bpy.data.actions.new(POSE_PREFIX + name)
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    for pb in arm.pose.bones:
        q, l = cap[pb.name]
        pb.rotation_quaternion = q
        pb.location = l
        pb.keyframe_insert("rotation_quaternion", frame=0, group=pb.name)
        pb.keyframe_insert("location", frame=0, group=pb.name)
    arm.animation_data.action = None
    return act


def weights_check(ob, bone_names):
    maxinf, badsum, unweighted = 0, 0, 0
    for v in ob.data.vertices:
        ws = [g.weight for g in v.groups if g.weight > 0]
        maxinf = max(maxinf, len(ws))
        if not ws:
            unweighted += 1
        elif abs(sum(ws) - 1.0) > 1e-3:
            badsum += 1
    stray = [g.name for g in ob.vertex_groups if g.name not in bone_names]
    return {"max_influences": maxinf, "unnormalized": badsum, "unweighted": unweighted, "non_bone_groups": stray}


def rigid_check(ob, part_ids, bone, tol=1e-4):
    """Every vertex of the given parts weighted 100% to `bone` (or to one of the bones of a tuple)."""
    bones = (bone,) if isinstance(bone, str) else tuple(bone)
    me = ob.data
    parts = np.empty(len(me.polygons), dtype=np.int64)
    me.attributes["part"].data.foreach_get("value", parts)
    vids = set()
    for poly in me.polygons:
        if parts[poly.index] in part_ids:
            vids |= set(poly.vertices)
    gname = {g.index: g.name for g in ob.vertex_groups}
    bad = 0
    for i in vids:
        ws = {gname[g.group]: g.weight for g in me.vertices[i].groups if g.weight > 0}
        if not any(abs(ws.get(b, 0.0) - 1.0) <= tol for b in bones):
            bad += 1
    return {"verts": len(vids), "not_rigid": bad}


def uv_unwrap(ob, mb):
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.view_layer.objects:
        o.select_set(o is ob)
    me = ob.data
    if "UV0" not in me.uv_layers:
        me.uv_layers.new(name="UV0")
    for poly in me.polygons:
        poly.select = mb.fuv[poly.index] is None
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="FACE")
    bpy.ops.uv.lightmap_pack(PREF_CONTEXT="SEL_FACES", PREF_PACK_IN_ONE=True, PREF_NEW_UVLAYER=False,
                             PREF_BOX_DIV=40, PREF_MARGIN_DIV=0.3)
    bpy.ops.object.mode_set(mode="OBJECT")
    write_mb_uvs(ob, mb)


def jsonable(o):
    if isinstance(o, dict):
        return {str(k): jsonable(v) for k, v in o.items()}
    if isinstance(o, (list, tuple)):
        return [jsonable(v) for v in o]
    if isinstance(o, (Vector,)):
        return [round(float(c), 4) for c in o]
    if isinstance(o, (np.floating, float)):
        return round(float(o), 4)
    if isinstance(o, (np.integer,)):
        return int(o)
    return o


# ---------------------------------------------------------------- main
def main():
    t0 = time.time()
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    do_save = "--no-save" not in argv
    do_render = "--no-renders" not in argv
    views_only = "--views-only" in argv
    tag = argv[argv.index("--tag") + 1] if "--tag" in argv else None
    os.makedirs(REVIEW, exist_ok=True)
    fails = []
    M = {"units": "cm (scale_length 0.01), 30 fps; Blender (x,y,z) == Unreal (x,-y,z); rat faces +X; rat LEFT = +Y"}
    with open(RIG_JSON) as fh:
        rig = json.load(fh)
    colls = reset_scene()

    # ---- parts
    torso = build_torso()
    head = build_head()
    ear_l = build_ear(1)
    legs = {k: build_leg(k, 1) for k in ("fore", "hind")}
    tail = build_tail()
    part_flips = {n: rc.orient_closed_islands(mb) for n, mb in
                  (("torso", torso), ("head", head), ("ear", ear_l), ("fore", legs["fore"]), ("hind", legs["hind"]),
                   ("tail", tail))}
    M["part_orientation_flips"] = part_flips
    body_tree = mb_tree([torso] + list(legs.values()), parts={PART["torso"], PART["leg_upper"]})
    torso_tree = mb_tree([torso], parts={PART["torso"]})
    ear_r = MB("EarR")
    ear_r.extend(ear_l, mirror=True)
    head_tree = mb_tree([head, ear_l, ear_r])
    spoon_local = spoon_local_mb()
    rc.orient_closed_islands(spoon_local)
    spoon_M, spoon_info = spoon_place(body_tree, head_tree, spoon_local, log)
    M["spoon_placement"] = spoon_info
    # the spoon strap: cuffs at the band crossing and at the neck, then the band passes over the cuffed handle
    sd = spoon_M.to_3x3().col[0]
    cross_t = (P["BAND_X"] - spoon_M.translation.x) / sd.x
    add_cuff(spoon_local, cross_t, {"spoon_prop": 1.0})
    add_cuff(spoon_local, P["SPOON_HANDLE"] * 0.93, {"spoon_prop": 1.0})
    rc.orient_closed_islands(spoon_local)
    spoon_world = MB("Spoon")
    spoon_world.extend(spoon_local)
    spoon_world.transform(spoon_M)
    band, cross_pt, _ = build_band(torso_tree, spoon_M, spoon_world, log)
    rc.orient_closed_islands(band)
    M["spoon_placement"]["band_cross_along_spoon_cm"] = cross_t
    head_only_tree = mb_tree([head], parts={PART["head"]})
    patch_l, pc_l, pn_l = build_eye_patch(head_only_tree, 1)
    patch_r, pc_r, pn_r = build_eye_patch(head_only_tree, -1)

    parts = {"Torso": torso, "Head": head, "Ear_L": ear_l, "Leg_Fore_L": legs["fore"], "Leg_Hind_L": legs["hind"],
             "Tail": tail, "Spoon": spoon_world, "Band": band, "EyePatch_L": patch_l, "EyePatch_R": patch_r}
    mirrored = ("Ear_L", "Leg_Fore_L", "Leg_Hind_L")
    for name, mb in parts.items():
        ob = mb.to_object("AUTH_" + name, colls["Authoring"], groups=False)
        write_mb_uvs(ob, mb)
    colls["Authoring"].hide_render = True
    colls["Authoring"].hide_viewport = True
    full = MB(MESH_NAME)
    tri_part = {}
    for name, mb in parts.items():
        n0 = len(full.f)
        full.extend(mb)
        if name in mirrored:
            full.extend(mb, mirror=True)
        tri_part[name + (" (x2 mirrored)" if name in mirrored else "")] = sum(
            len(f) - 2 for f in full.f[n0:])
    flips = rc.orient_closed_islands(full, skip_parts=(PART["eyepatch"],))
    body = full.to_object(MESH_NAME, colls["Export"])
    uv_unwrap(body, full)

    # ---- armature
    lay = bone_layout(spoon_M)
    arm = build_armature(colls["Export"], lay)
    body.parent = arm
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    bpy.context.view_layer.update()

    # ---- rig check vs RIG.json
    got = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
    want = {b["name"]: b["parent"] for b in rig["bones"]}
    rig_fail = []
    if len(got) != 26 or set(got) != set(want):
        rig_fail.append("names %d" % len(got))
    for n, p in want.items():
        if got.get(n, "MISSING") != p:
            rig_fail.append("parent %s=%s want %s" % (n, got.get(n), p))
    rootm = arm.data.bones["root"].matrix_local
    root_identity = (rootm - Matrix.Identity(4)).to_3x3().to_quaternion().angle < 1e-6 and rootm.translation.length < 1e-6
    if not root_identity:
        rig_fail.append("root rest not identity")
    fails += rig_fail
    M["rig"] = {"bones": len(got), "matches_RIG_json": not rig_fail, "issues": rig_fail, "root_rest_identity": root_identity,
                "bone_heads_tails_rest": {b.name: [jsonable(b.head_local), jsonable(b.tail_local)] for b in arm.data.bones}}
    log("RIG", json.dumps({"bones": len(got), "issues": rig_fail, "root_identity": root_identity}))

    # ---- mesh facts
    me = body.data
    me.calc_loop_triangles()
    wc = weights_check(body, set(got))
    rig_sp = rigid_check(body, (PART["spoon"], PART["cuff"]), "spoon_prop")
    rig_ep = rigid_check(body, (PART["eyepatch"],), "head")
    rig_el = rigid_check(body, (PART["ear"],), ("ear_l", "ear_r"))
    parts_arr = np.empty(len(me.polygons), dtype=np.int64)
    me.attributes["part"].data.foreach_get("value", parts_arr)
    tris_by_tag = {rc.PART_NAMES[k]: int((parts_arr == k).sum()) for k in rc.PART_NAMES}
    slots = [m.name for m in me.materials]
    tris_per_slot = {s: int(sum(1 for p in me.polygons if p.material_index == i)) for i, s in enumerate(slots)}
    # UV ranges of the eye patches
    uvl = me.uv_layers["UV0"]
    patch_uv = {"left_+Y": [], "right_-Y": []}
    for poly in me.polygons:
        if parts_arr[poly.index] != PART["eyepatch"]:
            continue
        c = sum((me.vertices[i].co for i in poly.vertices), Vector()) / len(poly.vertices)
        key = "left_+Y" if c.y > 0 else "right_-Y"
        for li in poly.loop_indices:
            patch_uv[key].append(tuple(uvl.data[li].uv))
    uvr = {}
    for k, l in patch_uv.items():
        a = np.array(l)
        uvr[k] = {"u": [round(float(a[:, 0].min()), 4), round(float(a[:, 0].max()), 4)],
                  "v": [round(float(a[:, 1].min()), 4), round(float(a[:, 1].max()), 4)], "loops": len(l)}
    uv_ok = (uvr["left_+Y"]["u"][0] >= -1e-4 and uvr["left_+Y"]["u"][1] <= 0.5 + 1e-4 and
             uvr["right_-Y"]["u"][0] >= 0.5 - 1e-4 and uvr["right_-Y"]["u"][1] <= 1.0 + 1e-4)
    if not uv_ok:
        fails.append("eye patch UV halves")
    if slots != list(rc.SLOTS):
        fails.append("slot order %s" % slots)
    if wc["max_influences"] > 4 or wc["unnormalized"] or wc["unweighted"] or wc["non_bone_groups"]:
        fails.append("weights %s" % wc)
    if rig_sp["not_rigid"] or rig_ep["not_rigid"] or rig_el["not_rigid"]:
        fails.append("rigid parts spoon %s patch %s ear %s" % (rig_sp, rig_ep, rig_el))
    tri_total = len(me.loop_triangles)
    if tri_total > 2500:
        fails.append("tris %d > 2500" % tri_total)
    ears = len({poly.index for poly in me.polygons if parts_arr[poly.index] == PART["ear"]})
    M["mesh"] = {"object": body.name, "tris_total": tri_total, "verts": len(me.vertices), "loops": len(me.loops),
                 "budget_tris": 2500, "tris_per_part_source": tri_part, "tris_per_part_tag": tris_by_tag,
                 "slots": slots, "tris_per_slot": tris_per_slot, "weights": wc, "rigid_spoon_and_strap": rig_sp,
                 "rigid_eye_patches_head": rig_ep, "rigid_ears": rig_el, "orientation_fixes": flips,
                 "eye_patch_uv": uvr, "eye_patch_uv_halves_ok": uv_ok,
                 "eye_patch_uv_convention": "U decreases toward rat-left (+Y): LEFT patch U in [0,0.5] (back edge 0, "
                                            "front edge 0.5), RIGHT patch U in [0.5,1] (front 0.5, back 1); V up. "
                                            "EyePlate.ush: U<0.5 = LeftCell, mirrored, so frac(2U) runs front->back "
                                            "on both eyes."}
    log("MESH", json.dumps(jsonable(M["mesh"])))

    # anatomy counts (connected islands per tag)
    def islands(tag):
        from collections import defaultdict
        polys = [p for p in me.polygons if parts_arr[p.index] == PART[tag]]
        parent = {}

        def find(a):
            while parent.setdefault(a, a) != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a
        for p in polys:
            vs = list(p.vertices)
            for v in vs[1:]:
                ra, rb = find(vs[0]), find(v)
                if ra != rb:
                    parent[ra] = rb
        return len({find(p.vertices[0]) for p in polys})
    anat = {"ears": islands("ear"), "eye_patches": islands("eyepatch"), "upper_limbs": islands("leg_upper"),
            "lower_limbs": islands("leg_lower"), "tail": islands("tail"), "nose": islands("nose"),
            "paw_and_toe_solids": islands("foot"), "spoon_and_cuffs": islands("spoon") + islands("cuff"),
            "band": islands("band")}
    M["anatomy_islands"] = anat
    if anat["ears"] != 2 or anat["eye_patches"] != 2 or anat["upper_limbs"] != 4 or anat["lower_limbs"] != 4 \
            or anat["tail"] != 1 or anat["band"] != 1:
        fails.append("anatomy %s" % anat)

    # ---- Carry frames (jaw children)
    apply_pose(arm, {})
    jaw_pb = arm.pose.bones["jaw"]
    jt = jaw_pb.tail.copy()
    carry_mouth = bpy.data.objects.new("Carry_Mouth", None)
    carry_mouth.empty_display_type = "ARROWS"
    carry_mouth.empty_display_size = 4.0
    colls["Props"].objects.link(carry_mouth)
    carry_mouth.parent = arm
    carry_mouth.parent_type = "BONE"
    carry_mouth.parent_bone = "jaw"
    # stem base in the mouth just behind the jaw tip; mushroom +Z (cap) points forward and 38 deg down
    Rm = Quaternion(Y, math.radians(90.0 + 38.0)).to_matrix().to_4x4()
    Mm = Matrix.Translation(jt + Vector((-0.8, 0, 0.8))) @ Rm
    bpy.context.view_layer.update()
    carry_mouth.matrix_world = Mm
    bpy.context.view_layer.update()

    # ---- props
    mush_mb = build_mushroom("Mushroom_Proxy")
    mush_carry = prop_object(mush_mb, "Mushroom_Carry", colls["Props"])
    mush_carry.parent = carry_mouth
    mush_carry.matrix_parent_inverse = Matrix.Identity(4)
    mush_carry.matrix_basis = Matrix.Identity(4)
    cheese_mb = build_cheese()
    cheese = prop_object(cheese_mb, "Cheese_MonksRind", colls["Props"], Matrix.Translation((-180.0, 150.0, 0.0)))
    bulky_mb = MB("Bulky_Proxy", rc.PROP_SLOTS)
    rc.box(bulky_mb, (0, 0, 12.5), (30.0, 30.0, 25.0), "Prop", PAL["bulky"], 0, jitter=0.05)
    # court
    floor = MB("Court_Floor", rc.PROP_SLOTS)
    for ix in range(8):
        for iy in range(6):
            c = PAL["floor"] if (ix + iy) % 2 == 0 else PAL["floor2"]
            x0, y0 = -400.0 + ix * 100.0, -300.0 + iy * 100.0
            a = floor.vert((x0, y0, 0))
            b = floor.vert((x0 + 100, y0, 0))
            cc = floor.vert((x0 + 100, y0 + 100, 0))
            d = floor.vert((x0, y0 + 100, 0))
            floor.face((a, b, cc), "Prop", c, 0)
            floor.face((a, cc, d), "Prop", c, 0)
    floor_ob = prop_object(floor, "Court_Floor", colls["Props"])
    PACK_POS = Vector((-300.0, 0.0, 0.0))
    pack_M = Matrix.Translation(PACK_POS) @ Matrix.Rotation(math.pi, 4, "Z")
    pack = MB("Backpack_Proxy", rc.PROP_SLOTS)
    rc.box(pack, (0, 0, 60.5), (86.0, 116.0, 121.0), "Prop", PAL["pack"], 0, jitter=0.04)
    pockets_local = {"Pocket1": (-31.0, 1.25, 75.0), "Pocket2": (-31.0, 22.5, 37.5), "Pocket3": (-31.0, -17.5, 37.5)}
    for nm, pl in pockets_local.items():   # pocket-mouth tabs on the -X face for readability (not geometry truth)
        rc.box(pack, (-43.4, pl[1], pl[2]), (0.8, 12.0, 10.0), "Prop", PAL["marker"], 0)
    pack_ob = prop_object(pack, "Backpack_Proxy", colls["Props"], pack_M)
    pocket_obs = {}
    for nm, pl in pockets_local.items():
        e = bpy.data.objects.new(nm, None)
        e.empty_display_type = "ARROWS"
        e.empty_display_size = 8.0
        colls["Props"].objects.link(e)
        e.parent = pack_ob
        e.location = pl
        pocket_obs[nm] = e
    bpy.context.view_layer.update()
    mush_pocket = prop_object(mush_mb, "Mushroom_AtPocket2", colls["Props"])
    mush_pocket.parent = pocket_obs["Pocket2"]
    mush_pocket.matrix_basis = Matrix.Identity(4)
    crates = []
    CRATES = [Vector((-60.0, 0.0, 0.0)), Vector((90.0, 0.0, 0.0))]
    for i, cpos in enumerate(CRATES):
        cm = MB("Crate_%d" % (i + 1), rc.PROP_SLOTS)
        rc.box(cm, (0, 0, 30.0), (60.0, 60.0, 60.0), "Prop", PAL["crate"], 0, jitter=0.05)
        crates.append(prop_object(cm, "Crate_%d" % (i + 1), colls["Props"], Matrix.Translation(cpos)))
    chef = MB("Chef_Capsule", rc.PROP_SLOTS)
    zs = [0.0, 6.0, 16.0, 30.0, 39.0, 111.0, 120.0, 134.0, 144.0, 150.0]
    rs = [0.0, 22.0, 33.0, 38.0, 39.0, 39.0, 38.0, 33.0, 22.0, 0.0]
    rings = []
    for z, r in zip(zs[1:-1], rs[1:-1]):
        rings.append([chef.vert((r * math.cos(2 * math.pi * k / 12), r * math.sin(2 * math.pi * k / 12), z))
                      for k in range(12)])
    b0, t0v = chef.vert((0, 0, 0)), chef.vert((0, 0, 150))
    for a, bb in zip(rings, rings[1:]):
        for k in range(12):
            k1 = (k + 1) % 12
            chef.face((a[k], a[k1], bb[k1]), "Prop", PAL["chef"], 0, 0.04)
            chef.face((a[k], bb[k1], bb[k]), "Prop", PAL["chef"], 0, 0.04)
    for k in range(12):
        k1 = (k + 1) % 12
        chef.face((rings[0][k1], rings[0][k], b0), "Prop", PAL["chef"], 0)
        chef.face((rings[-1][k], rings[-1][k1], t0v), "Prop", PAL["chef"], 0)
    CHEF_POS = PACK_POS + Vector((0.0, -120.0, 0.0))
    chef_ob = prop_object(chef, "Chef_Capsule_r39_hh75", colls["Props"], Matrix.Translation(CHEF_POS))
    DEN_POS = Vector((392.0, 0.0, 0.0))
    den_M = Matrix.Translation(DEN_POS) @ Matrix.Rotation(math.pi, 4, "Z")
    den_root, den_objs, den_markers, den_info = build_den(colls, den_M)
    bpy.context.view_layer.update()

    # ---- neutral measurements
    apply_pose(arm, {})
    co, tris, tp = rc.evaluated_tris(body)
    s = rc.Soup(co, tris, tp)
    ns = s.vert_ids(GROUPS["nonspoon"])
    tor = co[s.vert_ids((PART["torso"],))]
    nose_pt, _ = nose_tip(arm, body)
    shoulder_x = P["FORE"][0][0]
    wmask = np.abs(tor[:, 0] - shoulder_x) < 2.0
    withers = float(tor[wmask][:, 2].max())
    tail_ids = s.vert_ids((PART["tail"],))
    body_ids = np.setdiff1d(ns, tail_ids)
    body_x = co[body_ids][:, 0]
    neutral = {
        "nose_to_tail_x_extent_cm": round(float(co[:, 0].max() - co[:, 0].min()), 3),
        "nose_to_tail_rat_only_no_spoon_cm": round(float(co[ns][:, 0].max() - co[ns][:, 0].min()), 3),
        "body_length_tail_excluded_cm": round(float(body_x.max() - body_x.min()), 3),
        "torso_length_cm": round(float(tor[:, 0].max() - tor[:, 0].min()), 3),
        "body_width_torso_y_cm": round(float(tor[:, 1].max() - tor[:, 1].min()), 3),
        "width_incl_ears_cm": round(float(co[ns][:, 1].max() - co[ns][:, 1].min()), 3),
        "withers_top_z_cm": round(withers, 3), "withers_x_window": [shoulder_x - 2, shoulder_x + 2],
        "torso_top_max_z_cm": round(float(tor[:, 2].max()), 3),
        "height_incl_spoon_cm": round(float(co[:, 2].max()), 3),
        "height_no_spoon_cm": round(float(co[ns][:, 2].max()), 3),
        "nose_tip": jsonable(nose_pt), "tail_tip_x_cm": round(float(co[tail_ids][:, 0].min()), 3),
        "belly_min_z_cm": round(float(tor[:, 2].min()), 3),
        "bounds_min_blender": jsonable(Vector(co.min(axis=0))), "bounds_max_blender": jsonable(Vector(co.max(axis=0))),
    }
    targets = {"withers_top_z_cm": 35.0, "nose_to_tail_x_extent_cm": 65.0, "body_length_tail_excluded_cm": 40.0,
               "body_width_torso_y_cm": 30.0}
    dev = {k: round(neutral[k] - v, 3) for k, v in targets.items()}
    neutral["targets"] = targets
    neutral["deviation"] = dev
    neutral["deviations_over_1cm"] = [k for k, v in dev.items() if abs(v) > 1.0]
    neutral["height_incl_spoon_le_65"] = neutral["height_incl_spoon_cm"] <= 65.0
    M["neutral"] = neutral
    log("NEUTRAL", json.dumps(jsonable(neutral)))
    if neutral["height_incl_spoon_cm"] > 65.0:
        fails.append("neutral height %.2f" % neutral["height_incl_spoon_cm"])
    if abs(dev["withers_top_z_cm"]) > 1.0 or abs(dev["nose_to_tail_x_extent_cm"]) > 1.0:
        log("WARN target deviation > 1 cm", dev)
    M["carry_mouth"] = {}
    jb = arm.data.bones["jaw"].matrix_local
    cm_local = jb.inverted() @ carry_mouth.matrix_world
    M["carry_mouth"] = {"parent_bone": "jaw", "jaw_head_local_translation_cm": jsonable(cm_local.translation),
                        "jaw_head_local_rotation_quat_wxyz": jsonable(list(cm_local.to_quaternion())),
                        "jaw_head_local_euler_deg_xyz": [round(math.degrees(a), 3) for a in cm_local.to_euler()],
                        "world_rest_translation_cm": jsonable(carry_mouth.matrix_world.translation),
                        "frame_note": "Blender bone space (Y along the bone); the item pivot (base centre) sits here, "
                                      "item +Z = cap direction. Phase 2 must restate it in the exported UE socket frame."}

    # ---- poses
    lib = pose_library()
    poses = {}
    audits = {}
    fixes = {}

    def run(name, pose, proxies=(), carry=False, settle_floor=False):
        if settle_floor:
            pose = settle(arm, body, pose)
        apply_pose(arm, pose)
        a = audit_pose(body, proxies)
        bad = pose_ok(a, carry)
        if bad and any(b in ("spoon-torso", "head-spoon", "harness-torso") for b in bad):
            before = dict(a)
            pose2, a2 = fix_spoon(arm, body, pose, proxies, carry)
            fixes[name] = {"before": before, "after": a2, "issues_before": bad, "correction": pose2.get("_fix")}
            log("FIX %s %s -> %s %s" % (name, bad, pose_ok(a2, carry), pose2.get("_fix")))
            pose, a = pose2, a2
            if settle_floor:
                pose = settle(arm, body, pose)
                a = audit_pose(body, proxies)
        poses[name] = pose
        audits[name] = a
        log("POSE %-12s %s" % (name, json.dumps(a)))
        return pose, a

    def fix_spoon(arm_, body_, pose, proxies, carry):
        """Source fix for a spoon/harness clip: slide the strapped spoon on its torso (orbit about the chest's long
        axis), lift it off the back along its up axis, or roll it; smallest correction that clears wins."""
        best = None
        base_orbit = pose.get("orbit", {}).get("spoon_prop")
        sp_up = arm_.data.bones["spoon_prop"].matrix_local.to_3x3().col[2]
        cands = []
        for lift in (0.0, 0.3, 0.6, 1.0, 1.5, 2.0, 2.5, 3.0):
            for ang in (0.0, -3.0, 3.0, -6.0, 6.0, -10.0, 10.0):
                for pit in (0.0, -3.0, 3.0, -6.0, 6.0):
                    cands.append((abs(lift) * 2 + abs(ang) * 0.3 + abs(pit) * 0.3, lift, ang, pit))
        cands.sort()
        for cost, lift, ang, pit in cands:
            p2 = json.loads(json.dumps(pose, default=lambda o: list(o)))
            p2.setdefault("orbit", {})
            p2.setdefault("orbit_frame", {})
            p2.setdefault("loc", {})
            p2.setdefault("rot", {})
            sl = base_orbit[1] if base_orbit else 0.0
            p2["orbit"]["spoon_prop"] = ("X", sl + ang, (0.0, 0.0, 22.0))
            p2["orbit_frame"]["spoon_prop"] = "chest"
            p2["rot"]["spoon_prop"] = [(tuple(arm_.data.bones["spoon_prop"].matrix_local.to_3x3().col[1].cross(Z).normalized()), pit)] if pit else []
            p2["loc"]["spoon_prop"] = tuple(sp_up * lift)
            apply_pose(arm_, p2)
            # the lift is expressed in the rest frame; rotate it with the chest
            a2 = audit_pose(body_, proxies)
            if not [b for b in pose_ok(a2, carry) if b in ("spoon-torso", "head-spoon", "harness-torso")]:
                p2["_fix"] = {"spoon_lift_cm": lift, "spoon_slide_deg": ang, "spoon_pitch_deg": pit}
                return p2, a2
            if best is None or (a2["spoon_vs_torso_tris"] + a2["head_vs_spoon_tris"]) < best[0]:
                best = (a2["spoon_vs_torso_tris"] + a2["head_vs_spoon_tris"], p2, a2)
        best[1]["_fix"] = {"unresolved": True}
        return best[1], best[2]

    run("neutral", {})
    run("crouch", lib["crouch"])
    run("stretch", lib["stretch"])
    run("bound_apex", lib["bound_apex"])
    run("rear_up", lib["rear_up"])
    run("jaw_carry", lib["jaw_carry"], (mush_carry,), carry=True)
    # look-back: largest left yaw (<= 70) that keeps the carried proxy >= 2 cm off spoon and chest
    yaw_tab = []
    chosen = None
    for yaw in range(0, 75, 5):
        pose = json.loads(json.dumps(lib["jaw_carry"], default=lambda o: list(o)))
        pose["rot"]["neck"] = pose["rot"].get("neck", []) + [("Z", yaw * 0.45)]
        pose["rot"]["head"] = pose["rot"].get("head", []) + [("Z", yaw * 0.55)]
        apply_pose(arm, pose)
        a = audit_pose(body, (mush_carry,))
        ok = (a["carry_proxy_vs_spoon_tris"] == 0 and a["carry_proxy_vs_chest_tris"] == 0 and
              a["carry_proxy_vs_spoon_clear_cm"] >= 2.0 and a["carry_proxy_vs_chest_clear_cm"] >= 2.0 and
              a["head_vs_spoon_tris"] == 0)
        yaw_tab.append({"yaw_deg": yaw, "ok": ok, "proxy_spoon_clear": a["carry_proxy_vs_spoon_clear_cm"],
                        "proxy_chest_clear": a["carry_proxy_vs_chest_clear_cm"], "head_spoon_tris": a["head_vs_spoon_tris"]})
        if ok:
            chosen = (yaw, pose)
    M["look_back_yaw_search"] = yaw_tab
    look_yaw = chosen[0] if chosen else 0
    M["look_back_yaw_deg"] = {"total": look_yaw, "neck": look_yaw * 0.45, "head": look_yaw * 0.55,
                              "direction": "toward rat LEFT (+Y), away from the bowl on the right shoulder",
                              "rule": "largest yaw <= 70 with proxy >= 2 cm off spoon and chest"}
    run("look_back", chosen[1] if chosen else lib["jaw_carry"], (mush_carry,), carry=True)
    run("topple_left", lib["topple_left"], settle_floor=True)
    run("topple_right", lib["topple_right"], settle_floor=True)
    # dead_back: most belly-up roll with the least spoon slide where the body (not the spoon) rests on the floor
    dead_tab = []
    chosen = None
    for slide in (0.0, 10.0, -10.0, 20.0, -20.0, 30.0, -30.0, 40.0, -40.0, 50.0, -50.0, 60.0, -60.0):
        for dv in (0.0, 10.0, -10.0, 20.0, -20.0, 30.0, -30.0, 40.0, -40.0):
            pose = settle(arm, body, dead_pose(dv, slide))
            a = audit_pose(body)
            ok = not pose_ok(a)
            dead_tab.append({"dev": dv, "slide": slide, "ok": ok, "body_lift": a["body_lift_by_spoon_cm"],
                             "spoon_torso_tris": a["spoon_vs_torso_tris"], "spoon_min_z": a["spoon_min_z_cm"]})
            if ok:
                chosen = (dv, slide, pose)
                break
        if chosen:
            break
    M["dead_back_search"] = dead_tab
    if chosen:
        M["dead_back_solution"] = {"roll_deg": 180.0 + chosen[0], "spoon_slide_deg": chosen[1]}
        run("dead_back", chosen[2], settle_floor=True)
    else:
        M["dead_back_solution"] = {"unresolved": True}
        run("dead_back", settle(arm, body, dead_pose(0.0, 0.0)), settle_floor=True)
    run("den_crouch", lib["den_crouch"])

    # crouch ratio / stretch ratio
    n_h = audits["neutral"]["height_no_spoon_cm"]
    n_l = audits["neutral"]["x_extent_cm"]
    M["pose_ratios"] = {"crouch_height_ratio_no_spoon": round(audits["crouch"]["height_no_spoon_cm"] / n_h, 4),
                        "crouch_height_ratio_incl_spoon": round(audits["crouch"]["height_cm"] / audits["neutral"]["height_cm"], 4),
                        "stretch_length_ratio": round(audits["stretch"]["x_extent_cm"] / n_l, 4),
                        "bound_apex_body_lift_cm": 8.0,
                        "bound_apex_min_z_cm": audits["bound_apex"]["min_z_cm"]}
    apply_pose(arm, poses["rear_up"])
    nt, _ = nose_tip(arm, body)
    M["rear_up_nose_height_cm"] = round(nt.z, 3)
    log("RATIOS", json.dumps(M["pose_ratios"]), "rear_up nose z", round(nt.z, 2))

    # ---- den portal clearance (den_crouch WITH the spoon), measured in the den frame: the opening is symmetric
    apply_pose(arm, poses["den_crouch"])
    co, tris, tp = rc.evaluated_tris(body)
    hw_o, spring = den_info["opening_half_width"], den_info["spring_z"]
    worst = 1e9
    worst_pt = None
    for p in co:
        y, z = float(p[1]), float(p[2])
        if z <= spring:
            c = hw_o - abs(y)
        else:
            c = hw_o - math.hypot(y, z - spring)
        if c < worst:
            worst, worst_pt = c, (round(y, 2), round(z, 2))
    portal = {"pose": "den_crouch", "includes_spoon": True,
              "posed_y_extent_cm": round(float(co[:, 1].max() - co[:, 1].min()), 3),
              "posed_y_min_max": [round(float(co[:, 1].min()), 3), round(float(co[:, 1].max()), 3)],
              "posed_z_extent_cm": round(float(co[:, 2].max() - max(0.0, float(co[:, 2].min()))), 3),
              "posed_z_max_cm": round(float(co[:, 2].max()), 3),
              "opening_cm": [60.0, 60.0], "opening_profile": "30 cm jambs + 30 cm radius semicircle (60 x 60)",
              "box_clearance_width_total_cm": round(60.0 - float(co[:, 1].max() - co[:, 1].min()), 3),
              "box_clearance_height_cm": round(60.0 - float(co[:, 2].max()), 3),
              "arch_profile_min_clearance_cm": round(worst, 3), "arch_tightest_point_yz": worst_pt,
              "fits": worst > 0, "opening_widened": False}
    M["den"] = {"info": den_info, "portal_clearance": portal,
                "markers_den_local": {k: jsonable(v.location) for k, v in den_markers.items()},
                "den_world": jsonable(DEN_POS), "den_facing": "-X (opening looks into the court)"}
    log("PORTAL", json.dumps(portal))
    if worst <= 0:
        fails.append("den_crouch does not fit the opening (%.2f)" % worst)

    # ---- rummage / rear rummage vs the pack pockets
    def solve_reach(target_z, pitch_lo, pitch_hi, neck_up, head_up):
        """Bisection on the rear pitch about the hind hips for a nose height; fore paws on the pack face."""
        best = None
        for _ in range(26):
            pitch = 0.5 * (pitch_lo + pitch_hi)
            pose = rear_pose(pitch, neck_up, tuck=False, head_up=head_up)
            apply_pose(arm, pose)
            nt, _ = nose_tip(arm, body)
            if nt.z < target_z:
                pitch_lo = pitch
            else:
                pitch_hi = pitch
            best = (pitch, pose, nt)
        return best

    def fore_on_face(pose, face_x_local):
        """Fore paws pressed on the pack face (rat-local x = face_x_local), at the chest's height minus 8 cm."""
        apply_pose(arm, pose)
        ch = arm.pose.bones["chest"]
        for side, sfx in ((1, "l"), (-1, "r")):
            zt = max(4.0, ch.head.z - 6.0)
            ank = Vector((face_x_local - 2.4, side * 7.0, zt))
            toe = Vector((face_x_local - 0.6, side * 7.5, zt + 3.5))
            pose["feet"]["fore_" + sfx] = ("world", ank, toe, Vector((-1, 0, 0)))
        apply_pose(arm, pose)
        return pose

    reach = {}
    pack_inv = pack_ob.matrix_world.inverted()
    face_world_x = (pack_ob.matrix_world @ Vector((-43.0, 0, 0))).x   # pack -X face, world (+X facing after 180)
    # rat stands at world x > face, facing -X (rat object rotated 180 about Z)
    for label, pocket, neck_up, head_up, plo, phi in (("rummage", "Pocket2", 6.0, 10.0, 0.0, 45.0),
                                                      ("rummage_p3", "Pocket3", 6.0, 10.0, 0.0, 45.0),
                                                      ("rear_rummage", "Pocket1", 26.0, 30.0, 0.0, 82.0)):
        pw = pocket_obs[pocket].matrix_world.translation
        target_z = pw.z
        pitch, pose, nt = solve_reach(target_z, plo, phi, neck_up, head_up)
        reached = abs(nt.z - target_z) < 0.5
        if not reached:   # maximal rear: full pitch
            pose = rear_pose(phi, neck_up, tuck=False, head_up=head_up)
            pitch = phi
            apply_pose(arm, pose)
            nt, _ = nose_tip(arm, body)
        # place the rat: nose 0.5 cm off the pack face at the pocket's lateral position
        rat_yaw = math.pi
        nose_local = nt.copy()
        world_nose = Vector((face_world_x + 0.5, pw.y, nose_local.z))
        Rz = Matrix.Rotation(rat_yaw, 4, "Z")
        tr = world_nose - (Rz @ nose_local)
        place = Matrix.Translation(Vector((tr.x, tr.y, 0.0))) @ Rz
        face_x_local = (place.inverted() @ Vector((face_world_x, 0, 0))).x
        pose = fore_on_face(pose, face_x_local)
        nt2, _ = nose_tip(arm, body)
        hind_min = hind_feet_min_z(body)
        arm.matrix_world = place
        bpy.context.view_layer.update()
        a = audit_pose(body)
        nose_w = place @ nt2
        d_socket = (nose_w - pw).length
        pack_local_nose = pack_inv @ nose_w
        reach[label] = {"pocket": pocket, "pocket_world": jsonable(pw), "pocket_height_cm": round(pw.z, 3),
                        "rear_pitch_deg": round(pitch, 2), "nose_world": jsonable(nose_w),
                        "nose_height_cm": round(nose_w.z, 3), "height_shortfall_cm": round(max(0.0, pw.z - nose_w.z), 3),
                        "nose_reaches_pocket_height": nose_w.z >= pw.z - 0.5,
                        "nose_to_socket_3d_cm": round(d_socket, 3),
                        "nose_pack_local": jsonable(pack_local_nose),
                        "socket_depth_behind_envelope_face_cm": 12.0,
                        "hind_feet_min_z_cm": hind_min, "hind_feet_planted_rest_targets": True, "below_floor_verts": a["below_floor_verts"],
                        "audit": a, "rat_placement_world": jsonable(place.translation), "rat_yaw_deg": 180.0}
        poses[label] = pose
        audits[label] = a
        log("REACH %s %s" % (label, json.dumps({k: v for k, v in reach[label].items() if k != "audit"})))
        arm.matrix_world = Matrix.Identity(4)
        bpy.context.view_layer.update()
    M["pocket_reach"] = reach
    M["pack"] = {"world": jsonable(PACK_POS), "yaw_deg": 180.0, "envelope_cm": [86.0, 116.0, 121.0],
                 "pockets_pack_local": pockets_local, "pocket_face": "-X (faces world +X, toward the court)",
                 "chef_capsule": {"world": jsonable(CHEF_POS), "radius": 39.0, "half_height": 75.0,
                                  "pack_pivot_to_axis_cm": 120.0}}

    # ---- drag carry: bulky 30 x 30 x 25 proxy on the floor ahead, jaw on its near top edge
    drag = {"loc": {"body": (0.4, 0, -1.0)},
            "rot": {"neck": [("Y", -10.0)], "head": [("Y", -14.0)], "jaw": [("Y", 4.0)], "tail_01": [("Y", -8.0)]},
            "feet": planted()}
    apply_pose(arm, drag)
    jtip = jaw_tip(arm)
    bite = 2.5
    box_c = Vector((jtip.x + 15.0 - bite, 0.0, 0.0))
    carry_drag = bpy.data.objects.new("Carry_Drag", None)
    carry_drag.empty_display_type = "ARROWS"
    carry_drag.empty_display_size = 6.0
    colls["Props"].objects.link(carry_drag)
    carry_drag.parent = arm
    carry_drag.parent_type = "BONE"
    carry_drag.parent_bone = "jaw"
    bpy.context.view_layer.update()
    carry_drag.matrix_world = Matrix.Translation(box_c)
    bpy.context.view_layer.update()
    bulky = prop_object(bulky_mb, "Bulky_Proxy_30x30x25", colls["Props"])
    bulky.parent = carry_drag
    bulky.matrix_parent_inverse = Matrix.Identity(4)
    bulky.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    drag, a = run("drag_carry", drag, (bulky,), carry=True)
    jaw_rest = arm.data.bones["jaw"].matrix_local
    jaw_posed = arm.pose.bones["jaw"].matrix
    cd_local = jaw_posed.inverted() @ carry_drag.matrix_world
    M["carry_drag"] = {"parent_bone": "jaw", "jaw_head_local_translation_cm": jsonable(cd_local.translation),
                       "jaw_head_local_rotation_quat_wxyz": jsonable(list(cd_local.to_quaternion())),
                       "bulky_proxy_cm": [30.0, 30.0, 25.0], "proxy_pivot": "base centre",
                       "jaw_tip_world_in_drag_pose": jsonable(jtip), "bite_over_top_edge_cm": bite,
                       "proxy_top_z_cm": 25.0, "jaw_tip_z_vs_top_edge_cm": round(jtip.z - 25.0, 3),
                       "audit": a}
    M["carry_mouth"]["offset_note"] = "mouth carry: item pivot at Carry_Mouth; drag carry: bulky pivot at Carry_Drag"
    log("DRAG", json.dumps(jsonable(M["carry_drag"])))
    # mouth carry offsets relative to the jaw tip
    apply_pose(arm, poses["jaw_carry"])
    M["carry_mouth"]["jaw_carry_proxy_world_bounds"] = proxy_bounds(mush_carry)
    M["carry_mouth"]["jaw_carry_proxy_min_z_cm"] = audits["jaw_carry"].get("carry_proxy_min_z_cm")

    # ---- death drop: dead_back corpse + the mushroom released at the carry point, on the floor
    apply_pose(arm, poses["jaw_carry"])
    rel = mush_carry.matrix_world.translation.copy()
    drop = {}
    apply_pose(arm, poses["dead_back"])
    co, tris, tp = rc.evaluated_tris(body)
    corpse = rc.hull2d(co[:, :2])
    mush_floor = prop_object(mush_mb, "Mushroom_Dropped", colls["Props"])
    for label, fwd in (("vertical_drop", 0.0), ("released_forward_12cm", 12.0)):
        # lying on its side, cap toward +X, resting on the floor (radius 6 -> centre z 6 after rotation)
        Mdrop = Matrix.Translation(Vector((rel.x + fwd, rel.y, 6.0))) @ Matrix.Rotation(math.radians(90.0), 4, "Y") \
            @ Matrix.Translation(Vector((0, 0, -4.0)))
        mush_floor.matrix_world = Mdrop
        bpy.context.view_layer.update()
        mco, _, _ = rc.evaluated_tris(mush_floor)
        mh = rc.hull2d(mco[:, :2])
        gap = rc.poly_gap(mh, corpse)
        drop[label] = {"mushroom_centre_world": jsonable(Mdrop @ Vector((0, 0, 4.0))), "horizontal_gap_cm": round(gap, 3),
                       "mushroom_min_z_cm": round(float(mco[:, 2].min()), 3), "outside_corpse": gap > 0}
    M["death_drop"] = {"corpse_pose": "dead_back", "release_point_world": jsonable(rel), **drop,
                       "shown": "released_forward_12cm"}
    log("DROP", json.dumps(jsonable(M["death_drop"])))

    # ---- flee routes (top-down court)
    portals = [den_markers[k].matrix_world.translation.copy() for k in ("EntryPortal", "ExitPortal")]
    routes = flee_routes(CRATES)
    rinfo = {}
    rmbs = []
    for rname, pts in routes.items():
        dmin_portal = min(min((Vector((p.x, p.y, 0)) - Vector((q.x, q.y, 0))).length for q in portals) for p in pts)
        dmin_crate = min(min(box_gap(p, c, 30.0) for c in CRATES) for p in pts)
        dmin_pack = min(box_gap(p, PACK_POS, 43.0, 58.0) for p in pts)
        dmin_chef = min((Vector((p.x, p.y, 0)) - Vector((CHEF_POS.x, CHEF_POS.y, 0))).length - 39.0 for p in pts)
        in_floor = min(min(400 - abs(p.x), 300 - abs(p.y)) for p in pts)
        rinfo[rname] = {"min_dist_to_portal_markers_cm": round(dmin_portal, 2), "portal_rule_ge_150": dmin_portal >= 150,
                        "min_gap_to_crate_faces_cm": round(dmin_crate, 2),
                        "min_gap_to_pack_envelope_cm": round(dmin_pack, 2),
                        "min_gap_to_chef_capsule_cm": round(dmin_chef, 2),
                        "min_margin_to_floor_edge_cm": round(in_floor, 2),
                        "rat_half_width_cm": 15.0, "clear_of_crates_with_rat_half_width": dmin_crate > 15.0,
                        "length_cm": round(sum((b - a).length for a, b in zip(pts, pts[1:] + pts[:1])), 1)}
        if dmin_portal < 150 or dmin_crate <= 15.0:
            fails.append("route %s portal %.1f crate %.1f" % (rname, dmin_portal, dmin_crate))
        rm = MB("Route_" + rname, rc.PROP_SLOTS)
        col = PAL["route_a"] if rname.endswith("A") else PAL["route_b"]
        for a_, b_ in zip(pts, pts[1:] + pts[:1]):
            d = b_ - a_
            nrm2 = Vector((-d.y, d.x, 0)).normalized() * 2.5
            q = [rm.vert(a_ - nrm2 + Vector((0, 0, 0.6))), rm.vert(b_ - nrm2 + Vector((0, 0, 0.6))),
                 rm.vert(b_ + nrm2 + Vector((0, 0, 0.6))), rm.vert(a_ + nrm2 + Vector((0, 0, 0.6)))]
            rm.face((q[0], q[1], q[2]), "Prop", col, 0)
            rm.face((q[0], q[2], q[3]), "Prop", col, 0)
        rmbs.append(prop_object(rm, "Route_" + rname, colls["Review"]))
    M["flee_routes"] = rinfo
    M["crates_world"] = [jsonable(c) for c in CRATES]
    log("ROUTES", json.dumps(rinfo))

    # ---- cheese facts
    cco, ctris, _ = rc.evaluated_tris(cheese)
    cmin, cmax = cco.min(axis=0), cco.max(axis=0)
    M["cheese"] = {"object": cheese.name, "dims_cm": [round(float(cmax[i] - cmin[i]), 3) for i in range(3)],
                   "target_cm": [15.0, 10.0, 8.0], "tris": int(len(ctris)), "pivot": "base centre",
                   "pivot_check_min_z": round(float(cmin[2]) - cheese.matrix_world.translation.z, 4)}
    mco, mtris, _ = rc.evaluated_tris(mush_pocket)
    M["mushroom_proxy"] = {"dims_cm": [round(float(mco[:, i].max() - mco[:, i].min()), 3) for i in range(3)],
                           "target_cm": [12.0, 12.0, 8.0], "tris": int(len(mtris)),
                           "at_pocket2_world": jsonable(mush_pocket.matrix_world.translation)}
    pco, _, _ = rc.evaluated_tris(pack_ob)
    M["pack"]["proxy_dims_cm"] = [round(float(pco[:, i].max() - pco[:, i].min()), 3) for i in range(3)]
    log("CHEESE", json.dumps(M["cheese"]), "MUSH", json.dumps(M["mushroom_proxy"]))

    # ---- pose actions
    apply_pose(arm, {})
    for name, pose in poses.items():
        apply_pose(arm, pose)
        store_action(arm, name, capture(arm))
    apply_pose(arm, {})
    M["pose_actions"] = sorted(a.name for a in bpy.data.actions)
    tx = bpy.data.texts.new("PantryRat_R01_PoseDefs.json")
    tx.write(json.dumps(jsonable(poses), indent=1, default=lambda o: list(o)))

    M["pose_audit"] = audits
    M["pose_fixes"] = fixes
    M["fails"] = fails

    # ---- review objects (cameras, rulers, labels)
    make_review(colls)

    # ---- renders
    if do_render:
        import rat_render
        rat_render.render_all(globals(), arm, body, poses, M, views_only=views_only, tag=tag,
                              objs={"mush_carry": mush_carry, "bulky": bulky, "mush_floor": mush_floor,
                                    "pack": pack_ob, "den_root": den_root, "den_objs": den_objs, "cheese": cheese,
                                    "routes": rmbs, "chef": chef_ob, "crates": crates, "floor": floor_ob,
                                    "mush_pocket": mush_pocket, "markers": den_markers, "pockets": pocket_obs},
                              reach=reach)
    apply_pose(arm, {})
    arm.matrix_world = Matrix.Identity(4)

    M["elapsed_s"] = round(time.time() - t0, 1)
    with open(MEASURE_JSON, "w") as fh:
        json.dump(jsonable(M), fh, indent=1, default=lambda o: list(o))
    if do_save:
        os.makedirs(os.path.dirname(BLEND_FILE), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=BLEND_FILE, compress=False)
        log("SAVED", BLEND_FILE)
    bad_poses = {k: pose_ok(v, k in ("jaw_carry", "look_back", "drag_carry")) for k, v in audits.items()}
    bad_poses = {k: v for k, v in bad_poses.items() if v}
    paw_clips = {k: v["feet_vs_torso_tris"] for k, v in audits.items() if v["feet_vs_torso_tris"]}
    if paw_clips:
        fails.append("paws inside torso %s" % paw_clips)
    if bad_poses:
        fails.append("pose audits %s" % bad_poses)
    M["fails"] = fails
    with open(MEASURE_JSON, "w") as fh:
        json.dump(jsonable(M), fh, indent=1, default=lambda o: list(o))
    log("ELAPSED %.1fs" % (time.time() - t0))
    return fails


def proxy_bounds(ob):
    co, _, _ = rc.evaluated_tris(ob)
    return {"min": jsonable(Vector(co.min(axis=0))), "max": jsonable(Vector(co.max(axis=0)))}


def hind_feet_min_z(body):
    """Min z of the hind paws (foot-tagged verts behind the body centre), rat at the armature origin."""
    co, tris, tp = rc.evaluated_tris(body)
    s = rc.Soup(co, tris, tp)
    ids = s.vert_ids((PART["foot"],))
    pts = co[ids]
    pts = pts[pts[:, 0] < -2.0]
    return round(float(pts[:, 2].min()), 3)


def box_gap(p, c, hx, hy=None):
    hy = hx if hy is None else hy
    dx = max(0.0, abs(p.x - c.x) - hx)
    dy = max(0.0, abs(p.y - c.y) - hy)
    return math.hypot(dx, dy)


def flee_routes(crates):
    c0, c1 = crates
    cx = 0.5 * (c0.x + c1.x)
    A = []
    for k in range(64):
        a = 2 * math.pi * k / 64
        A.append(Vector((cx + 165.0 * math.cos(a), 105.0 * math.sin(a), 0.0)))
    B = []
    for k in range(96):   # figure eight weaving between the crates
        t = 2 * math.pi * k / 96
        B.append(Vector((cx + 178.0 * math.sin(t), 118.0 * math.sin(2 * t), 0.0)))
    return {"Loop_A": A, "FigureEight_B": B}


def label_mesh(text, coll, loc, size=4.0, rot=None, col=(0.9, 0.9, 0.9)):
    cu = bpy.data.curves.new("lbl_" + text[:12], "FONT")
    cu.body = text
    cu.size = size
    tmp = bpy.data.objects.new("tmp_lbl", cu)
    coll.objects.link(tmp)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp, do_unlink=True)
    bpy.data.curves.remove(cu)
    me.materials.append(rc.MATS["Prop"])
    ca = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    ca.data.foreach_set("color_srgb", [*col, 1.0] * len(me.loops))
    ob = bpy.data.objects.new("Label_" + text[:20], me)
    coll.objects.link(ob)
    ob.location = loc
    if rot:
        ob.rotation_euler = rot
    return ob


def make_review(colls):
    rv = colls["Review"]
    cam = bpy.data.cameras.new("ReviewCam")
    co = bpy.data.objects.new("ReviewCam", cam)
    rv.objects.link(co)
    bpy.context.scene.camera = co
    # rulers: 10 cm segments, alternating
    for name, axis, n, origin in (("Ruler_X_80", X, 8, Vector((-45.0, -26.0, 0.05))),
                                  ("Ruler_Z_70", Z, 7, Vector((-45.0, -26.0, 0.0))),
                                  ("Ruler_Y_40", Y, 4, Vector((30.0, -20.0, 0.05)))):
        mb = MB(name, rc.PROP_SLOTS)
        for i in range(n):
            c = PAL["ruler_a"] if i % 2 == 0 else PAL["ruler_b"]
            ctr = origin + axis * (10.0 * i + 5.0)
            size = [1.2, 1.2, 1.2]
            size["XYZ".index("XYZ"[[X, Y, Z].index(axis)])] = 10.0
            rc.box(mb, ctr, size, "Prop", c, 0)
        mb.to_object(name, rv, groups=False)
    label_mesh("PANTRY RAT R01  10 cm ruler", rv, (-45.0, -27.0, 72.0), 3.0, (math.radians(90), 0, 0))


if __name__ == "__main__":
    code = 0
    try:
        fails = main()
    except Exception as exc:  # noqa: BLE001
        traceback.print_exc()
        fails = ["exception %s" % exc]
    try:
        os.makedirs(REVIEW, exist_ok=True)
        with open(LOG_FILE, "w") as fh:
            fh.write("\n".join(LOG) + "\n")
            fh.write(("PANTRY_RAT_FAIL " + "; ".join(fails)) if fails else "PANTRY_RAT_OK")
            fh.write("\n")
    except Exception:  # noqa: BLE001
        pass
    if fails:
        print("PANTRY_RAT_FAIL " + "; ".join(fails))
        sys.exit(1)
    print("PANTRY_RAT_OK")
    sys.exit(0)
