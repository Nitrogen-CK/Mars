"""Cellar Bat R01 - Phase 3 builder: finished faceted mesh + LODs, vertex-colour materials, animator control rig
(headless, reproducible, parametric in cm).

Builds source/CellarBat_R01.blend from nothing:
  Authoring  the LOD0 parts as separate editable objects (left side only; the right is mirrored in the build)
  Rig        `CellarBat_R01_Controls` (bat_rig.py) driving the export bones through constraints; never exported
  Export     `CellarBat_R01_Body` (LOD0), `CellarBat_R01_Body_LOD1`, `CellarBat_R01_Body_LOD2`, all skinned to ONE
             armature `CellarBat_R01_Armature` with the 42 bones of docs/art/flying-units-r01/RIG.json
  Review     camera, 10 cm rulers, label, perch bar (never exported)
Actions on the controls (fake user): `CellarBat_R01_FlapTest_Ctl` (16 frames 0..15, 30 fps, 15 == 0) and one-frame
pose actions `CellarBat_R01_Pose_<Name>` (Spread, Up, Down, Recover, HalfFold, Wrap, BankLeft, BankRight, Hang).

Frame (unchanged from Phase 2). 1 BU = 1 cm (scale_length 0.01). The bat faces +X, up +Z; Blender (x, y, z) reads as
Unreal (x, -y, z); bat LEFT (`*_l`) = Blender +Y. Root bone at the origin = body centre of the spread bind pose,
rest matrix identity, never moves.

How poses are made. A pose is first DEFINED directly on the export bones (rotations in the bone's rest frame, or
aim targets in the body frame for the folds; `apply_pose`), CAPTURED as local rotations, and then reproduced through
the control rig: FK poses copy the captured rotations onto the CTL bones; the fold is the solved wrap stored in the
rig's fold constraints and reached with the single fold slider. The builder checks rig == direct for every pose.

Run:
  blender -b --factory-startup --python build_cellar_bat.py -- [--no-save]
Prints CELLAR_BAT_OK or CELLAR_BAT_FAIL <reason>; exits non-zero on failure. Renders: render_cellar_bat.py.
"""
import json
import math
import os
import sys
import traceback

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import bat_audit  # noqa: E402
import bat_rig  # noqa: E402

ROOT = os.path.dirname(HERE)
REPO = os.path.abspath(os.path.join(ROOT, "..", "..", "..", ".."))
RIG_JSON = os.path.join(REPO, "docs", "art", "flying-units-r01", "RIG.json")
BLEND_FILE = os.path.join(ROOT, "source", "CellarBat_R01.blend")
REVIEW = os.path.join(ROOT, "review", "phase3b")
MEASURE_JSON = os.path.join(REVIEW, "measurements.json")

ARM_NAME = "CellarBat_R01_Armature"
MESH_NAME = "CellarBat_R01_Body"
LOD_NAMES = (MESH_NAME, MESH_NAME + "_LOD1", MESH_NAME + "_LOD2")
FLAP_CTL_ACTION = "CellarBat_R01_FlapTest_Ctl"
POSE_PREFIX = "CellarBat_R01_Pose_"
SLOTS = ("Body", "Membrane", "Eyes")


def hexcol(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


PAL = {
    "fur": hexcol("#433831"), "fur_lo": hexcol("#3B312B"), "hood": hexcol("#544439"), "lip": hexcol("#5C4B3F"),
    "tuft_a": hexcol("#4C3E35"), "tuft_b": hexcol("#44372F"), "ruff": hexcol("#4F4138"),
    "face": hexcol("#171415"), "mouth": hexcol("#0E0A0A"), "muzzle": hexcol("#211B1A"), "nose": hexcol("#120E0E"),
    "membrane": hexcol("#803E40"), "ear_in": hexcol("#7A4842"),
    "rib": hexcol("#B7A18A"), "claw": hexcol("#8E7A66"), "fang": hexcol("#E6DAC2"), "eye": hexcol("#FFC570"),
}

PART = {"torso": 0, "head": 1, "face": 2, "ear": 3, "tuft": 4, "leg": 5, "rib_l": 6, "rib_r": 7,
        "mem_l": 8, "mem_r": 9, "memroot_l": 10, "memroot_r": 11, "eye": 12, "ruff": 13,
        "ribroot_l": 14, "ribroot_r": 15}

# ---------------------------------------------------------------- parameters (cm, degrees)
P = {
    "LEAN_DEG": 30.0,
    "RUMP_U": -10.2,
    # plump pear: (u, half width, half depth, forward offset); widest (6.0) at index 4
    "TORSO_RINGS": [(-9.8, 1.8, 1.7, 0.4), (-8.9, 4.0, 3.9, 0.8), (-7.5, 5.4, 5.2, 1.1), (-5.7, 5.95, 5.8, 1.35),
                    (-3.7, 6.0, 5.95, 1.4), (-1.5, 5.75, 5.7, 1.25), (0.7, 5.15, 5.15, 0.95), (2.7, 4.35, 4.45, 0.65),
                    (4.4, 3.6, 3.7, 0.45), (5.7, 3.1, 3.1, 0.3)],
    "TORSO_TOP": (6.4, 0.3),
    "HEAD_U": 6.7, "HEAD_FO": 0.5, "HEAD_SCALE": 1.12,   # head-local offsets scale about the head centre
    # head lathe around +X: (x, half width y, half height z, z offset)
    "HEAD_RINGS": [(-4.3, 1.5, 1.4, 0.2), (-3.3, 3.6, 3.3, 0.1), (-1.5, 4.8, 4.2, 0.0), (0.9, 5.0, 4.2, -0.1),
                   (2.7, 4.7, 3.9, -0.2), (3.55, 4.3, 3.55, -0.3), (3.45, 3.5, 2.85, -0.4), (2.3, 3.2, 2.6, -0.45)],
    "HEAD_BANDS": ["hood", "hood", "hood", "hood", "hood", "lip", "face"],
    "FACE_PLANE_X": 1.7,
    "EAR_LEN": 10.0, "EAR_HALF_W": 4.4, "EAR_SPLAY_DEG": 33.0, "EAR_BACK_DEG": 10.0,
    "EAR_BASE": (-0.6, 2.9, 2.9),
    "EAR_SHELL": 1.8, "EAR_RIM": 1.05, "EAR_CUP": 1.1, "EAR_LIP": 0.9,   # Phase 3b: thick rim, cupped inner face
    "EAR_FACE_OUT_DEG": 35.0,
    "SHOULDER": (2.6, 0.5, 5.0),
    "WING_DIHEDRAL": 0.42,         # arms rise from the shoulder to the wrist (sheet 02 front: an M silhouette)
    "WING_T_PITCH_DEG": 46.0,
    "WING_T_SCALE": 1.45,
    "SPAN": 75.0,
    "WING2D": {
        "elbow": (10.5, -0.8), "wrist": (21.5, -1.0),
        "thumb_m": (23.1, -2.6), "thumb_t": (24.4, -2.9),
        "f1": ((29.5, 0.0), (34.5, 2.0)), "f2": ((27.5, 3.4), (31.5, 8.6)),
        "f3": ((23.6, 5.6), (25.0, 12.6)), "f4": ((18.2, 5.0), (15.5, 10.8))},
    "FINGER_BOW": 0.045,      # rib curvature: bow toward the leading edge, fraction of the segment length
    "SCALLOP": 0.40,          # trailing-edge scallop depth between fingertips (pull toward the wrist)
    "SAG": 0.07,              # membrane catenary sag between ribs, fraction of the local rib gap
    "INNER_SCALLOP": 0.20,
    "INNER_BODY_FALLOFF": 1.7,
    "FLANK_LIFT": 1.8,          # cm: outward fillet of the inner panel where it leaves the flank  # inner-panel skin: body/flank weight ~ v^k (v = 0 at finger 4, 1 at the flank)    # inner-panel trailing edge (finger-4 tip -> ankle) scallop, fraction of the chord
    "HIP": (-6.6, 0.9, 3.3), "THIGH": 4.2, "SHIN": 4.6, "FOOT": 2.4,
}

DETAIL = {
    0: dict(torso_rings=list(range(10)), torso_sides=24, head_sides=18, ear_rings=(0.0, 0.2, 0.4, 0.6, 0.8),
            shingle_rows=[(2.2, 5, 70.0), (-0.5, 6, 74.0), (-3.2, 5, 66.0), (-5.6, 4, 56.0), (-7.4, 3, 44.0)],
            shingle_len=3.9, shingle_full=True, ruff=7, chin=5, arm_sides=6, fin_sides=6, fin_samples=5,
            K=9, R=(0.0, 0.13, 0.26, 0.39, 0.52, 0.65, 0.77, 0.89, 1.0, 1.12, 1.25, 1.38, 1.51, 1.64, 1.77, 1.89, 2.0),
            inner_rows=17,
            leg_sides=6, shin_sides=5, claws=3, claw_seg=3, knuckle=True, elbow=True, leg_rings=3, arm_root=True),
    1: dict(torso_rings=[0, 1, 2, 3, 4, 6, 8, 9], torso_sides=16, head_sides=12, ear_rings=(0.0, 0.3, 0.6),
            shingle_rows=[(1.8, 4, 70.0), (-1.4, 5, 70.0), (-4.4, 4, 60.0), (-7.0, 3, 46.0)],
            shingle_len=4.0, shingle_full=False, ruff=7, chin=3, arm_sides=5, fin_sides=4, fin_samples=3,
            K=4, R=(0.0, 0.3, 0.6, 0.82, 1.0, 1.3, 1.6, 1.82, 2.0), inner_rows=8,
            leg_sides=5, shin_sides=4, claws=3, claw_seg=2, knuckle=True, elbow=True, leg_rings=3, arm_root=True),
    2: dict(torso_rings=[0, 2, 4, 7, 9], torso_sides=12, head_sides=10, ear_rings=(0.0, 0.5),
            shingle_rows=[(0.6, 4, 70.0), (-3.4, 4, 62.0), (-6.4, 3, 50.0)],
            shingle_len=4.0, shingle_full=False, ruff=5, chin=0, arm_sides=4, fin_sides=3, fin_samples=1,
            K=1, R=(0.0, 0.5, 1.0, 1.5, 2.0), inner_rows=4,
            leg_sides=4, shin_sides=3, claws=2, claw_seg=1, knuckle=False, elbow=False, leg_rings=2, arm_root=True),
}
D = dict(DETAIL[0])


# ---------------------------------------------------------------- small helpers
def V(*a):
    return Vector(a[0]) if len(a) == 1 else Vector(a)


def nrm(v):
    v = Vector(v)
    return v.normalized() if v.length > 1e-12 else v


LEAN = math.radians(P["LEAN_DEG"])
U = Vector((math.sin(LEAN), 0.0, math.cos(LEAN)))     # rump -> head
F = Vector((math.cos(LEAN), 0.0, -math.sin(LEAN)))    # belly / forward-down
Y = Vector((0.0, 1.0, 0.0))
X = Vector((1.0, 0.0, 0.0))
Z = Vector((0.0, 0.0, 1.0))


def B(u, fo=0.0, y=0.0):
    return U * u + F * fo + Y * y


def HS():
    return P["HEAD_SCALE"]


def head_centre():
    return B(P["HEAD_U"], P["HEAD_FO"])


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def norm_w(w, maxinf=4):
    items = sorted(((k, v) for k, v in w.items() if v > 1e-6), key=lambda kv: -kv[1])[:maxinf]
    s = sum(v for _, v in items)
    return {k: v / s for k, v in items} if s > 0 else {"root": 1.0}


def blend_w(*pairs):
    out = {}
    for f, w in pairs:
        for k, v in w.items():
            out[k] = out.get(k, 0.0) + f * v
    return out


def facet_jitter(col, seed, amt=0.06):
    r = (math.sin(seed * 12.9898) * 43758.5453) % 1.0
    k = 1.0 + (r - 0.5) * 2 * amt
    return tuple(min(1.0, c * k) for c in col)


def torso_dims(u, clamp_lo=None):
    rings = P["TORSO_RINGS"]
    if clamp_lo is not None:
        u = max(u, clamp_lo)
    if u <= rings[0][0]:
        return rings[0][1], rings[0][2], rings[0][3]
    for a, b in zip(rings, rings[1:]):
        if a[0] <= u <= b[0]:
            t = (u - a[0]) / (b[0] - a[0])
            return lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t)
    r = rings[-1]
    return r[1], r[2], r[3]


def torso_surface(u, phi, out=0.0):
    """Point on the torso ellipse ring at u, angle phi (0 = front, +90 = the bat's left), pushed `out` cm."""
    hw, hd, fo = torso_dims(u)
    c, s = math.cos(phi), math.sin(phi)
    p = B(u, fo + (hd + out) * c, (hw + out) * s)
    n = nrm(F * (c / hd) + Y * (s / hw))
    return p, n


# ---------------------------------------------------------------- mesh builder
class MB:
    def __init__(self, name):
        self.name = name
        self.v, self.w, self.f, self.fm, self.fc, self.fp = [], [], [], [], [], []

    def vert(self, p, w):
        self.v.append(Vector(p))
        self.w.append(norm_w(w))
        return len(self.v) - 1

    def face(self, idx, mat, col, part, jitter=0.0):
        self.f.append(list(idx))
        self.fm.append(SLOTS.index(mat))
        c = facet_jitter(col, len(self.f) * 1.37 + len(self.v) * 0.11, jitter) if jitter else col
        self.fc.append(c)
        self.fp.append(PART[part])

    def extend(self, other, mirror=False):
        off = len(self.v)
        for p, w in zip(other.v, other.w):
            if mirror:
                p = Vector((p.x, -p.y, p.z))
                w = {mirror_name(k): x for k, x in w.items()}
            self.v.append(Vector(p))
            self.w.append(dict(w))
        for f, m, c, pt in zip(other.f, other.fm, other.fc, other.fp):
            idx = [i + off for i in f]
            if mirror:
                idx = idx[::-1]
                pt = MIRROR_PART.get(pt, pt)
            self.f.append(idx)
            self.fm.append(m)
            self.fc.append(c)
            self.fp.append(pt)

    def to_object(self, name, coll, groups=True):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(p) for p in self.v], [], self.f)
        me.update()
        for s in SLOTS:
            me.materials.append(MATS[s])
        me.polygons.foreach_set("material_index", self.fm)
        attr = me.attributes.new("part", "INT", "FACE")
        attr.data.foreach_set("value", self.fp)
        col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        cols = []
        for poly in me.polygons:
            c = self.fc[poly.index]
            cols.extend([c[0], c[1], c[2], 1.0] * poly.loop_total)
        col.data.foreach_set("color_srgb", cols)
        me.color_attributes.active_color = col
        me.color_attributes.render_color_index = 0
        me.shade_flat()
        ob = bpy.data.objects.new(name, me)
        coll.objects.link(ob)
        if groups:
            names = sorted({k for w in self.w for k in w})
            vg = {n: ob.vertex_groups.new(name=n) for n in names}
            for i, w in enumerate(self.w):
                for k, x in w.items():
                    vg[k].add([i], x, "REPLACE")
        return ob


def mirror_name(n):
    return n[:-2] + "_r" if n.endswith("_l") else n


MIRROR_PART = {PART["rib_l"]: PART["rib_r"], PART["mem_l"]: PART["mem_r"], PART["memroot_l"]: PART["memroot_r"],
               PART["ribroot_l"]: PART["ribroot_r"]}


def ring_frame(axis, ref=None):
    a = nrm(axis)
    ref = Vector(ref) if ref is not None else (Z if abs(a.dot(Z)) < 0.9 else X)
    e1 = nrm(ref - a * ref.dot(a))
    e2 = a.cross(e1)
    return e1, e2


def tube(mb, pts, radii, ws, col, part, sides=5, ref=None, jitter=0.03, flat=1.0):
    """Closed faceted tube along a polyline; per-point radius and weight dict; radius 0 at an end = an apex.
    flat < 1 squashes the cross-section along e2 (ribs are a little flatter across the membrane)."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    loops = []
    e1p = None
    for k in range(n):
        if k == 0:
            d = pts[1] - pts[0]
        elif k == n - 1:
            d = pts[-1] - pts[-2]
        else:
            d = nrm(pts[k + 1] - pts[k]) + nrm(pts[k] - pts[k - 1])
        a = nrm(d)
        if e1p is None:
            e1, e2 = ring_frame(a, ref)
        else:
            e1 = nrm(e1p - a * e1p.dot(a))
            e2 = a.cross(e1)
        e1p = e1
        r = radii[k]
        if r <= 1e-6:
            loops.append(mb.vert(pts[k], ws[k]))
        else:
            loops.append([mb.vert(pts[k] + (e1 * math.cos(2 * math.pi * j / sides) +
                                             e2 * flat * math.sin(2 * math.pi * j / sides)) * r, ws[k])
                          for j in range(sides)])
    for a, b in zip(loops, loops[1:]):
        for j in range(sides):
            j1 = (j + 1) % sides
            if isinstance(a, int):
                mb.face((a, b[j1], b[j]), "Body", col, part, jitter)
            elif isinstance(b, int):
                mb.face((a[j], a[j1], b), "Body", col, part, jitter)
            else:
                mb.face((a[j], a[j1], b[j1], b[j]), "Body", col, part, jitter)
    if not isinstance(loops[0], int):
        c = mb.vert(pts[0] - nrm(pts[1] - pts[0]) * radii[0] * 0.5, ws[0])
        for j in range(sides):
            mb.face((loops[0][(j + 1) % sides], loops[0][j], c), "Body", col, part, jitter)
    if not isinstance(loops[-1], int):
        c = mb.vert(pts[-1] + nrm(pts[-1] - pts[-2]) * radii[-1] * 0.5, ws[-1])
        for j in range(sides):
            mb.face((loops[-1][j], loops[-1][(j + 1) % sides], c), "Body", col, part, jitter)
    return loops


def hull(mb, pts, w, col, part, jitter=0.05, colfn=None):
    """Closed convex solid of the points (outward normals). w: dict or callable(point) -> dict."""
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p)) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs, use_existing_faces=False)
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="BEAUTY")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.verts.index_update()
    ids = {}
    for v in bm.verts:
        ids[v.index] = mb.vert(v.co, w(v.co) if callable(w) else w)
    for f in bm.faces:
        c = colfn(f.normal) if colfn else col
        mb.face([ids[v.index] for v in f.verts], "Body", c, part, jitter)
    bm.free()


def shingle(mb, top, down, out, half_w, length, lift, w, col, part, full=True):
    """One broad low scallop-shaped fur shingle: top edge sunk into the surface, a soft ridge, a rounded lower edge."""
    side = nrm(down.cross(out))
    pts = [top - out * 0.45 - side * half_w * 0.8, top - out * 0.45 + side * half_w * 0.8,
           top + down * length * 0.55 - out * 0.7]
    if full:
        pts += [top - out * 0.3 - down * 0.15,
                top + down * length * 0.42 + side * half_w + out * lift * 0.45,
                top + down * length * 0.42 - side * half_w + out * lift * 0.45,
                top + down * length * 0.38 + out * lift]
        for s, f in ((-0.86, 0.6), (-0.46, 0.84), (0.0, 1.0), (0.46, 0.84), (0.86, 0.6)):
            pts.append(top + down * length * f + side * half_w * s + out * lift * (0.38 + 0.12 * (1 - abs(s))))
    else:
        pts += [top + down * length * 0.45 + side * half_w + out * lift * 0.4,
                top + down * length * 0.45 - side * half_w + out * lift * 0.4,
                top + down * length + out * lift * 0.45]
    hull(mb, pts, w, col, part, 0.05)


# ---------------------------------------------------------------- skeleton layout (Blender cm)
def wing_frame(side):
    A = nrm(Vector((0.0, side, P["WING_DIHEDRAL"])))
    tp = math.radians(P["WING_T_PITCH_DEG"])
    T = Vector((-math.sin(tp), 0.0, -math.cos(tp)))
    T = nrm(T - A * T.dot(A))
    N = A.cross(T)
    return A, T, N


def shoulder(side):
    u, fo, y = P["SHOULDER"]
    return B(u, fo, side * y)


def leg_points(side):
    u, fo, y = P["HIP"]
    hip = B(u, fo, side * y)
    d1 = nrm(-U * 0.75 + F * 0.45 + Y * side * 0.35)
    knee = hip + d1 * P["THIGH"]
    d2 = nrm(-U * 1.0 - F * 0.25 + Y * side * 0.12)
    ankle = knee + d2 * P["SHIN"]
    toe = ankle + nrm(F * 1.0 - U * 0.55) * P["FOOT"]
    return hip, knee, ankle, toe


SPAN_K = [1.0]


def wing_points(side):
    A, T, N = wing_frame(side)
    S = shoulder(side)
    k = SPAN_K[0]
    ts = P["WING_T_SCALE"]

    def W2(st):
        return S + A * (st[0] * k) + T * (st[1] * k * ts)

    L = P["WING2D"]
    pts = {"shoulder": S, "elbow": W2(L["elbow"]), "wrist": W2(L["wrist"]),
           "thumb_m": W2(L["thumb_m"]) - N * 0.6, "thumb_t": W2(L["thumb_t"]) - N * 1.1}
    for i in range(1, 5):
        kn, tp = L["f%d" % i]
        pts["kn%d" % i] = W2(kn)
        pts["tip%d" % i] = W2(tp)
    return pts, (A, T, N)


def ear_points(side):
    H = head_centre()
    bx, by, bz = P["EAR_BASE"]
    base = H + HS() * Vector((bx, side * by, bz))
    sp, bk = math.radians(P["EAR_SPLAY_DEG"]), math.radians(P["EAR_BACK_DEG"])
    l = nrm(Vector((-math.sin(bk), side * math.sin(sp), math.cos(sp) * math.cos(bk))))
    tip = base + l * P["EAR_LEN"]
    return base, l, tip


def bone_layout():
    H = head_centre()
    lay = {
        "root": (V(0, 0, 0), V(0, 3.0, 0), Z),
        "pelvis": (V(0, 0, 0), B(-7.5), Y),
        "spine": (V(0, 0, 0), B(4.6), Y),
        "neck": (B(4.6), B(6.2, 0.3), Y),
        "head": (B(6.2, 0.3), H + HS() * V(0, 0, 4.0), Y),
        "jaw": (H + HS() * V(1.7, 0, -1.6), H + HS() * V(3.5, 0, -2.4), Y),
    }
    for side, sfx in ((1, "_l"), (-1, "_r")):
        w, (A, T, N) = wing_points(side)
        lay["upperarm" + sfx] = (w["shoulder"], w["elbow"], N)
        lay["forearm" + sfx] = (w["elbow"], w["wrist"], N)
        lay["wrist" + sfx] = (w["wrist"], w["wrist"] + nrm(w["kn2"] - w["wrist"]) * 2.0, N)
        for i in range(1, 5):
            lay["finger_0%da%s" % (i, sfx)] = (w["wrist"], w["kn%d" % i], N)
            lay["finger_0%db%s" % (i, sfx)] = (w["kn%d" % i], w["tip%d" % i], N)
        lay["thumb_a" + sfx] = (w["wrist"], w["thumb_m"], N)
        lay["thumb_b" + sfx] = (w["thumb_m"], w["thumb_t"], N)
        hip, knee, ankle, toe = leg_points(side)
        lay["thigh" + sfx] = (hip, knee, X)
        lay["shin" + sfx] = (knee, ankle, X)
        lay["foot" + sfx] = (ankle, toe, Y * side)
        base, l, tip = ear_points(side)
        mid = base + l * (P["EAR_LEN"] * 0.45)
        lay["ear_base" + sfx] = (base, mid, X)
        lay["ear_tip" + sfx] = (mid, tip, X)
    return lay


# ---------------------------------------------------------------- weights
def body_w(u):
    if u < -3.0:
        return {"pelvis": 1.0}
    if u < 1.0:
        t = (u + 3.0) / 4.0
        return {"pelvis": 1 - t, "spine": t}
    if u < 4.6:
        return {"spine": 1.0}
    return {"spine": 0.5, "neck": 0.5}


def shoulder_blend(p, w):
    """Torso skin near a shoulder follows the upper arm a little (smooth shoulder)."""
    for side, sfx in ((1, "_l"), (-1, "_r")):
        d = (p - shoulder(side)).length
        if d < 3.4:
            k = 0.35 * smooth(1.0 - d / 3.4)
            w = blend_w((1.0 - k, w), (k, {"upperarm" + sfx: 1.0}))
    return w


def u_of(p):
    return p.dot(U)


# ---------------------------------------------------------------- body parts
def build_torso():
    mb = MB("Torso")
    n = D["torso_sides"]
    rings = [P["TORSO_RINGS"][i] for i in D["torso_rings"]]
    loops = []
    for j, (u, hw, hd, fo) in enumerate(rings):
        c = B(u, fo)
        off = (math.pi / n) * (j % 2)
        row = []
        for k in range(n):
            a = 2 * math.pi * k / n + off
            p = c + F * (hd * math.cos(a)) + Y * (hw * math.sin(a))
            row.append(mb.vert(p, shoulder_blend(p, body_w(u))))
        loops.append(row)
    for j, (a, b) in enumerate(zip(loops, loops[1:])):
        for k in range(n):
            k1 = (k + 1) % n
            if j % 2 == 0:
                mb.face((a[k], a[k1], b[k]), "Body", PAL["fur"], "torso", 0.07)
                mb.face((a[k1], b[k1], b[k]), "Body", PAL["fur"], "torso", 0.07)
            else:
                mb.face((a[k], b[k1], b[k]), "Body", PAL["fur"], "torso", 0.07)
                mb.face((a[k], a[k1], b[k1]), "Body", PAL["fur"], "torso", 0.07)
    bot = mb.vert(B(P["RUMP_U"], 0.4), {"pelvis": 1.0})
    top = mb.vert(B(*P["TORSO_TOP"]), {"neck": 1.0})
    for k in range(n):
        mb.face((loops[0][(k + 1) % n], loops[0][k], bot), "Body", PAL["fur_lo"], "torso", 0.05)
        mb.face((loops[-1][k], loops[-1][(k + 1) % n], top), "Body", PAL["fur"], "torso", 0.05)
    return mb


def build_shingles():
    """Overlapping scallop rows on the lower two thirds (front and sides) like roof shingles + the neck ruff."""
    mb = MB("Shingles")
    L = D["shingle_len"]
    for r, (u0, cnt, span) in enumerate(D["shingle_rows"]):
        sp = math.radians(span)
        hw, hd, fo = torso_dims(u0 - L * 0.4)
        arc = 2 * sp * (hw + hd) * 0.5
        half_w = arc / cnt * 0.7
        col = PAL["tuft_a"] if r % 2 == 0 else PAL["tuft_b"]
        for k in range(cnt):
            phi = -sp + (k + 0.5) * 2 * sp / cnt
            top, n = torso_surface(u0, phi)
            low, _n = torso_surface(u0 - 1.0, phi)
            down = nrm(low - top)
            out = nrm(n - down * n.dot(down))
            w = body_w(u0 - L * 0.4)
            shingle(mb, top, down, out, half_w, L, 0.6, w, col, "tuft", D["shingle_full"])
    # neck ruff: a thick ring of broad wedges where the head meets the chest
    n_r = D["ruff"]
    uc = 5.3
    for k in range(n_r):
        phi = math.radians(-80 + (k + 0.5) * 160.0 / n_r)
        c, s = math.cos(phi), math.sin(phi)
        rw, rd = 3.9, 4.1
        top = B(uc + 1.2, 0.5 + rd * c * 0.92, rw * s * 0.92)
        out = nrm(F * c + Y * s + U * 0.15)
        down = nrm(-U * 0.85 + out * 0.5)
        shingle(mb, top, down, out, 2.0 if D["shingle_full"] else 2.3, 3.8, 0.9, {"spine": 0.45, "neck": 0.55},
                PAL["ruff"], "ruff", D["shingle_full"])
    return mb


def build_head():
    mb = MB("Head")
    H = head_centre()
    n = D["head_sides"]
    loops = []
    hw = {"head": 1.0}
    for j, (x, ry, rz, zo) in enumerate(P["HEAD_RINGS"]):
        w = hw if x > -2.0 else {"head": 0.8, "neck": 0.2}
        off = (math.pi / n) * (j % 2)
        pts = []
        for k in range(n):
            a = 2 * math.pi * k / n + off
            y, z = math.sin(a) * ry, math.cos(a) * rz
            if j >= 5 and z > 0:
                z *= 0.86          # hood brow hangs over the mask
            pts.append(mb.vert(H + HS() * Vector((x, y, z + zo)), w))
        loops.append(pts)
    back = mb.vert(H + HS() * Vector((-4.7, 0, 0.2)), {"head": 0.8, "neck": 0.2})
    face_c = mb.vert(H + HS() * Vector((P["FACE_PLANE_X"], 0, -0.4)), hw)
    for k in range(n):
        mb.face((loops[0][k], loops[0][(k + 1) % n], back), "Body", PAL["hood"], "head", 0.06)
    for j, (a, b) in enumerate(zip(loops, loops[1:])):
        band = P["HEAD_BANDS"][j]
        col = PAL[band]
        part = "face" if band == "face" else "head"
        for k in range(n):
            k1 = (k + 1) % n
            if j % 2 == 0:
                mb.face((a[k1], a[k], b[k]), "Body", col, part, 0.06)
                mb.face((a[k1], b[k], b[k1]), "Body", col, part, 0.06)
            else:
                mb.face((a[k1], a[k], b[k1]), "Body", col, part, 0.06)
                mb.face((a[k], b[k], b[k1]), "Body", col, part, 0.06)
    for k in range(n):
        mb.face((loops[-1][(k + 1) % n], loops[-1][k], face_c), "Body", PAL["face"], "face", 0.03)
    # chin / cheek shingles under the mask (the hood's lower fringe)
    nc = D["chin"]
    for k in range(nc):
        a = math.radians(-60 + (k + 0.5) * 120.0 / max(nc, 1))
        top = H + HS() * Vector((2.2, 3.4 * math.sin(a), -2.9 * math.cos(a) - 0.2))
        out = nrm(Vector((0.55, math.sin(a), -math.cos(a))))
        down = nrm(Vector((0.25, 0.25 * math.sin(a), -1.0)))
        shingle(mb, top, down, out, 1.25, 2.4, 0.6, hw, PAL["hood"], "head", D["shingle_full"])
    return mb


def build_face():
    """Blunt muzzle with a nose wedge, a dark mouth slit, two short ivory fangs, the jaw, and two amber eyes."""
    mb, eyes = MB("Face"), MB("Eyes")
    H = head_centre()
    hw, jw = {"head": 1.0}, {"jaw": 1.0}

    def box(pts, w, cols):
        ids = [mb.vert(H + HS() * Vector(p), w) for p in pts]
        quads = ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (3, 2, 6, 7), (0, 3, 7, 4), (1, 5, 6, 2))
        for q, col in zip(quads, cols):
            mb.face([ids[i] for i in q], "Body", col, "face", 0.04)

    M, Mo = PAL["muzzle"], PAL["mouth"]
    # upper muzzle: back (in the mask), front (blunt), top, bottom (mouth roof), sides
    box(((1.4, -1.55, -0.1), (1.4, 1.55, -0.1), (1.4, 1.6, -1.55), (1.4, -1.6, -1.55),
         (3.75, -1.05, -0.45), (3.75, 1.05, -0.45), (3.65, 1.15, -1.5), (3.65, -1.15, -1.5)), hw,
        (M, M, M, Mo, M, M))
    # jaw (lower muzzle): top face = mouth floor (dark) so the closed mouth reads as a slit
    box(((1.5, -1.35, -1.72), (1.5, 1.35, -1.72), (1.5, 1.15, -2.6), (1.5, -1.15, -2.6),
         (3.3, -0.95, -1.72), (3.3, 0.95, -1.72), (3.1, 0.75, -2.45), (3.1, -0.75, -2.45)), jw,
        (M, M, Mo, M, M, M))
    # nose wedge
    hull(mb, [H + HS() * Vector(p) for p in ((3.72, -0.48, -0.42), (3.72, 0.48, -0.42), (4.08, 0.0, -0.68),
                                       (3.7, 0.0, -1.0), (3.5, 0.0, -0.55))], hw, PAL["nose"], "face", 0.0)
    # fangs: two short upper fangs in front of the jaw
    for y in (0.72, -0.72):
        tube(mb, [H + HS() * Vector((3.55, y, -1.35)), H + HS() * Vector((3.62, y * 0.95, -2.0)), H + HS() * Vector((3.7, y * 0.88, -2.6))],
             [0.3, 0.22, 0.0], [hw] * 3, PAL["fang"], "face", sides=4, ref=X, jitter=0.0)
    # eyes: two small bright amber solids set wide in the mask
    for y in (1.85, -1.85):
        c = H + HS() * Vector((P["FACE_PLANE_X"] + 0.4, y, 0.75))
        ids = [eyes.vert(c + d, hw) for d in (X * 0.48, -X * 0.25, Y * 0.56, -Y * 0.56, Z * 0.48, -Z * 0.48)]
        px, nx, py, ny, pz, nz = ids
        for a, b in ((px, py), (py, nx), (nx, ny), (ny, px)):
            eyes.face((a, b, pz), "Eyes", PAL["eye"], "eye")
            eyes.face((b, a, nz), "Eyes", PAL["eye"], "eye")
    return mb, eyes


def build_ear(side=1):
    """Broad triangle: thick brown rim, a slightly lighter recessed inner face, back shell; base inside the hood."""
    mb = MB("Ear_L")
    base, l, tip = ear_points(side)
    fo_ = math.radians(P["EAR_FACE_OUT_DEG"])
    dd = X * math.cos(fo_) + Y * (side * math.sin(fo_))
    d = nrm(dd - l * dd.dot(l))       # the opening faces forward, turned out to the side (the cup reads in profile)
    e = nrm(l.cross(d))
    sfx = "_l" if side > 0 else "_r"
    rings = []
    for f in D["ear_rings"]:
        c = base + l * (P["EAR_LEN"] * f)
        hwid = P["EAR_HALF_W"] * (1 - f)
        th = P["EAR_SHELL"] * (1 - f) + 0.2           # back shell bulge (the ear's thickness seen from the side)
        rim = P["EAR_RIM"] * (1 - f) + 0.22             # brown rim band width on the front face
        cav = P["EAR_CUP"] * (1 - f)                    # cup depth behind the rim lip
        lip = P["EAR_LIP"] * (1 - f) + 0.05             # the rim stands forward of the cup
        if f <= 0.3:
            w = {"ear_base" + sfx: 1.0}
        elif f < 0.6:
            t = (f - 0.3) / 0.3
            w = {"ear_base" + sfx: 1 - t, "ear_tip" + sfx: t}
        else:
            w = {"ear_tip" + sfx: 1.0}
        if f == 0.0:
            w = {"ear_base" + sfx: 0.7, "head": 0.3}
        rings.append([mb.vert(c + e * hwid, w), mb.vert(c - d * th * 0.7 + e * hwid * 0.5, w), mb.vert(c - d * th, w),
                      mb.vert(c - d * th * 0.7 - e * hwid * 0.5, w), mb.vert(c - e * hwid, w),
                      mb.vert(c - e * (hwid - rim) + d * lip, w), mb.vert(c - d * cav, w),
                      mb.vert(c + e * (hwid - rim) + d * lip, w)])
    t = mb.vert(tip, {"ear_tip" + sfx: 1.0})
    cols = [PAL["fur"], PAL["fur"], PAL["fur"], PAL["fur"], PAL["hood"], PAL["ear_in"], PAL["ear_in"], PAL["hood"]]
    n = 8
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            k1 = (k + 1) % n
            mb.face((a[k], b[k], b[k1], a[k1]), "Body", cols[k], "ear", 0.05)
    r = rings[-1]
    for k in range(n):
        mb.face((r[k], t, r[(k + 1) % n]), "Body", cols[k], "ear", 0.05)
    mb.face(tuple(rings[0]), "Body", PAL["fur"], "ear")
    return mb


def build_leg(side=1):
    mb = MB("Leg_L")
    sfx = "_l" if side > 0 else "_r"
    hip, knee, ankle, toe = leg_points(side)
    tw, sw, fw = {"thigh" + sfx: 1.0}, {"shin" + sfx: 1.0}, {"foot" + sfx: 1.0}
    if D["leg_rings"] >= 3:
        tube(mb, [hip, lerp(hip, knee, 0.5), knee], [1.75, 1.5, 1.05], [tw] * 3, PAL["fur"], "leg",
             sides=D["leg_sides"], jitter=0.05)
    else:
        tube(mb, [hip, knee], [1.7, 1.05], [tw] * 2, PAL["fur"], "leg", sides=D["leg_sides"], jitter=0.05)
    tube(mb, [knee, ankle], [0.72, 0.5], [sw, sw], PAL["rib"], "leg", sides=D["shin_sides"], jitter=0.03)
    fdir = nrm(toe - ankle)
    lat = nrm(fdir.cross(-U)) if fdir.cross(-U).length > 1e-6 else Y
    tube(mb, [ankle, ankle + fdir * 1.0], [0.62, 0.72], [fw, fw], PAL["rib"], "leg", sides=D["shin_sides"],
         jitter=0.03)
    for k in ((-1, 0, 1) if D["claws"] == 3 else (-0.6, 0.6)):
        b0 = ankle + fdir * 0.85 + lat * (k * 0.55)
        b1 = b0 + fdir * 1.15 + lat * (k * 0.25) - U * 0.1
        cd = nrm(-U * 0.9 + fdir * 0.2)
        if D["claw_seg"] == 1:      # LOD2: toe and claw in one tapered hook
            tube(mb, [b0, b1, b1 + fdir * 0.4 + cd * 0.7], [0.26, 0.2, 0.0], [fw] * 3, PAL["claw"], "leg", sides=3,
                 jitter=0.0)
            continue
        tube(mb, [b0, b1], [0.26, 0.21], [fw, fw], PAL["rib"], "leg", sides=4, jitter=0.0)
        if D["claw_seg"] >= 3:
            pts = [b1, b1 + fdir * 0.45 + cd * 0.15, b1 + fdir * 0.55 + cd * 0.6, b1 + fdir * 0.35 + cd * 0.95]
            rad = [0.2, 0.16, 0.1, 0.0]
        else:
            pts = [b1, b1 + fdir * 0.5 + cd * 0.3, b1 + fdir * 0.4 + cd * 0.9]
            rad = [0.2, 0.13, 0.0]
        tube(mb, pts, rad, [fw] * len(pts), PAL["claw"], "leg", sides=4, jitter=0.0)
    return mb


def finger_path(w, i, r, frame):
    """Point on finger i's centreline, r in [0, 2] (0 wrist, 1 knuckle, 2 tip). Each segment bows gently toward the
    leading edge so the bone sweeps back toward the trailing edge; the knuckle is the bend."""
    A, T, N = frame
    W, K, Tp = w["wrist"], w["kn%d" % i], w["tip%d" % i]
    a, b, t = (W, K, r) if r <= 1.0 else (K, Tp, r - 1.0)
    d = b - a
    perp = nrm(N.cross(d))
    if perp.dot(-T) < 0:
        perp = -perp
    return lerp(a, b, t) + perp * (P["FINGER_BOW"] * d.length * 4.0 * t * (1.0 - t))


def build_wing_ribs(side=1):
    mb = MB("WingRibs_L")
    sfx = "_l" if side > 0 else "_r"
    w, fr = wing_points(side)
    A, T, N = fr
    part = "rib_l" if side > 0 else "rib_r"
    rpart = "ribroot_l" if side > 0 else "ribroot_r"
    ua, fa, wr = {"upperarm" + sfx: 1.0}, {"forearm" + sfx: 1.0}, {"wrist" + sfx: 1.0}
    S, E, Wr = w["shoulder"], w["elbow"], w["wrist"]
    sa, sf = D["arm_sides"], D["fin_sides"]
    ua_dir = nrm(E - S)
    # shoulder root (inside the flank by design, tagged separately), then the upper arm and forearm
    if D["arm_root"]:
        tube(mb, [S - ua_dir * 0.6, S + ua_dir * 2.4], [1.2, 1.15], [{"upperarm" + sfx: 0.75, "spine": 0.25}, ua],
             PAL["rib"], rpart, sides=sa, ref=N)
        tube(mb, [S + ua_dir * 2.2, lerp(S, E, 0.55), E], [0.95, 0.85, 0.8], [ua] * 3, PAL["rib"], part, sides=sa,
             ref=N)
    else:
        tube(mb, [S - ua_dir * 0.6, E], [1.15, 0.8], [{"upperarm" + sfx: 0.75, "spine": 0.25}, ua], PAL["rib"],
             rpart, sides=sa, ref=N)
    tube(mb, [E, lerp(E, Wr, 0.5), Wr], [0.78, 0.6, 0.62], [fa] * 3, PAL["rib"], part, sides=sa, ref=N)
    # elbow and the chunky wrist knuckle (faceted hulls)
    fa_dir = nrm(Wr - E)
    side_v = nrm(N.cross(fa_dir))
    if D["elbow"]:
        hull(mb, [E + d for d in (ua_dir * -1.1, fa_dir * 0.9, side_v * 0.95, -side_v * 0.8, N * 0.75, -N * 0.8,
                                  side_v * 0.6 + N * 0.6)], ua, PAL["rib"], part, 0.04)
    kn_pts = [Wr - fa_dir * 1.3, Wr + fa_dir * 0.9, Wr + side_v * 1.05, Wr - side_v * 0.95, Wr + N * 0.85,
              Wr - N * 0.95, Wr + side_v * 0.7 - N * 0.7, Wr - fa_dir * 0.6 + side_v * 0.8 + N * 0.5,
              Wr + fa_dir * 0.5 - side_v * 0.7 + N * 0.6]
    hull(mb, kn_pts, wr, PAL["rib"], part, 0.04)
    ns = D["fin_samples"]
    for i in range(1, 5):
        a_w, b_w = {"finger_0%da%s" % (i, sfx): 1.0}, {"finger_0%db%s" % (i, sfx): 1.0}
        ra = [0.48 - 0.12 * (k / ns) for k in range(ns + 1)]
        ra[-1] = 0.42
        pa = [finger_path(w, i, k / ns, fr) for k in range(ns + 1)]
        tube(mb, pa, ra, [a_w] * len(pa), PAL["rib"], part, sides=sf, ref=N, flat=0.8)
        pb_ = [finger_path(w, i, 1.0 + k / ns, fr) for k in range(ns + 1)]
        rb = [0.38 * (1.0 - k / ns) ** 0.8 + 0.06 * (1.0 - k / ns) for k in range(ns + 1)]
        rb[-1] = 0.0
        tube(mb, pb_, rb, [b_w] * len(pb_), PAL["rib"], part, sides=sf, ref=N, flat=0.8)
        if D["knuckle"]:
            K = w["kn%d" % i]
            dk = nrm(finger_path(w, i, 1.05, fr) - finger_path(w, i, 0.95, fr))
            sk = nrm(N.cross(dk))
            hull(mb, [K + d for d in (dk * 0.55, -dk * 0.5, sk * 0.5, -sk * 0.5, N * 0.42, -N * 0.42)], a_w,
                 PAL["rib"], part, 0.03)
    ta, tb = {"thumb_a" + sfx: 1.0}, {"thumb_b" + sfx: 1.0}
    tm, tt = w["thumb_m"], w["thumb_t"]
    tube(mb, [Wr, tm], [0.55, 0.45], [ta, ta], PAL["rib"], part, sides=sf, ref=N)
    tube(mb, [tm, tt], [0.42, 0.32], [tb, tb], PAL["rib"], part, sides=sf, ref=N)
    td = nrm(tt - tm)
    hook = [tt, tt + td * 0.45 - T * 0.25, tt + td * 0.75 - T * 0.05 - N * 0.15, tt + td * 0.7 + T * 0.4 - N * 0.3]
    tube(mb, hook, [0.3, 0.22, 0.13, 0.0], [tb] * 4, PAL["claw"], part, sides=4, ref=N, jitter=0.0)
    return mb


def finger_ray_w(i, r, sfx):
    tw = max(0.0, 1.0 - r / 0.45)
    tb = smooth((r - 0.85) / 0.3)
    return norm_w({"wrist" + sfx: tw, "finger_0%da%s" % (i, sfx): (1 - tw) * (1 - tb),
                   "finger_0%db%s" % (i, sfx): (1 - tw) * tb})


def coons(c0, c1, d0, d1, u, v):
    P00, P10, P01, P11 = c0(0.0), c0(1.0), c1(0.0), c1(1.0)
    return ((1 - v) * c0(u) + v * c1(u) + (1 - u) * d0(v) + u * d1(v)
            - ((1 - u) * (1 - v) * P00 + u * (1 - v) * P10 + (1 - u) * v * P01 + u * v * P11))


def poly_eval(pts, params, t):
    for (a, ta), (b, tb) in zip(zip(pts, params), zip(pts[1:], params[1:])):
        if t <= tb + 1e-9:
            return lerp(a, b, (t - ta) / (tb - ta) if tb > ta else 0.0)
    return pts[-1]


def wdict_lin(a, b, t):
    return {k: (1 - t) * a.get(k, 0.0) + t * b.get(k, 0.0) for k in set(a) | set(b)}


def build_membrane(side=1):
    """Three interdigital panels (fingers 1-2, 2-3, 3-4) as one fan from the wrist, with deep rounded scallops and a
    shallow catenary sag, plus the broad inner panel (plagiopatagium) bounded by finger 4, the arm, the flank and a
    continuous scalloped trailing edge from the finger-4 tip to the ankle. Shared finger-4 vertices keep it one sheet."""
    mb = MB("Membrane_L")
    sfx = "_l" if side > 0 else "_r"
    part = "mem_l" if side > 0 else "mem_r"
    rpart = "memroot_l" if side > 0 else "memroot_r"
    w, fr = wing_points(side)
    A, T, N = fr
    R = D["R"]
    K = D["K"]
    center = mb.vert(w["wrist"], {"wrist" + sfx: 1.0})
    rays = []
    ray_f4 = None
    for i in range(1, 5):
        steps = [0.0] if i == 4 else [k / (K + 1) for k in range(K + 1)]
        for wfrac in steps:
            ids = []
            for r in R[1:]:
                if wfrac == 0.0:
                    p = finger_path(w, i, r, fr)
                    wt = finger_ray_w(i, r, sfx)
                else:
                    pa, pb = finger_path(w, i, r, fr), finger_path(w, i + 1, r, fr)
                    gap = (pb - pa).length
                    p = lerp(pa, pb, wfrac)
                    pull = P["SCALLOP"] * math.sin(math.pi * wfrac) * (r / 2.0) ** 2.2
                    p = w["wrist"] + (p - w["wrist"]) * (1.0 - pull)
                    p = p - N * (P["SAG"] * gap * math.sin(math.pi * wfrac))
                    wt = norm_w(wdict_lin(finger_ray_w(i, r, sfx), finger_ray_w(i + 1, r, sfx), wfrac))
                ids.append(mb.vert(p, wt))
            rays.append(ids)
            if i == 4:
                ray_f4 = ids
    for a, b in zip(rays, rays[1:]):
        mb.face((center, a[0], b[0]), "Membrane", PAL["membrane"], part, 0.04)
        for j in range(len(a) - 1):
            mb.face((a[j], a[j + 1], b[j + 1]), "Membrane", PAL["membrane"], part, 0.04)
            mb.face((a[j], b[j + 1], b[j]), "Membrane", PAL["membrane"], part, 0.04)
    # ---- inner panel (Coons patch): u along finger 4 (wrist -> tip), v from the arm side to the body side
    hip, knee, ankle, toe = leg_points(side)
    ank = lerp(knee, ankle, 0.88)
    S = w["shoulder"]

    def flank_pt(u):
        hw, hd, fo = torso_dims(u)
        return B(u, fo + 0.3, side * (hw - 0.45))

    flank = [S] + [flank_pt(u) for u in (0.8, -1.6, -4.0, -6.4, -8.2)] + [ank]
    fl_par = [0.0]
    for a, b in zip(flank, flank[1:]):
        fl_par.append(fl_par[-1] + (b - a).length)
    fl_par = [p / fl_par[-1] for p in fl_par]
    E, W, T4 = w["elbow"], w["wrist"], w["tip4"]
    chord = ank - T4
    toward = lerp(E, S, 0.5) - lerp(T4, ank, 0.5)
    toward = nrm(toward - chord * (toward.dot(chord) / chord.length_squared))

    def c0(u):
        return finger_path(w, 4, u * 2.0, fr)

    def c1(u):
        return poly_eval(flank, fl_par, u)

    def d0(v):
        return poly_eval([W, E, S], [0.0, 0.5, 1.0], v)

    def d1(v):
        # continuous rounded scallop from the finger-4 tip to the ankle
        return lerp(T4, ank, v) + toward * (P["INNER_SCALLOP"] * chord.length * math.sin(math.pi * v))

    def c1w(u):
        t = u
        return norm_w({"spine": max(0.0, 1 - 2 * t),
                       "upperarm" + sfx: 0.5 * max(0.0, 1 - 4 * t),
                       "pelvis": max(0.0, 1 - abs(t - 0.55) / 0.35),
                       "shin" + sfx: smooth((t - 0.72) / 0.28)})

    def c0w(u):
        return finger_ray_w(4, u * 2.0, sfx)

    def d0w(v):
        if v <= 0.5:
            t = v / 0.5
            return norm_w({"wrist" + sfx: max(0.0, 1 - t * 4),
                           "forearm" + sfx: min(1.0, t * 4) * (1 - smooth((t - 0.8) / 0.2)),
                           "upperarm" + sfx: smooth((t - 0.8) / 0.2) * 0.5})
        t = (v - 0.5) / 0.5
        return norm_w({"upperarm" + sfx: 1.0 - 0.5 * smooth((t - 0.6) / 0.4), "spine": 0.5 * smooth((t - 0.6) / 0.4)})

    def d1w(v):
        return norm_w({"finger_04b" + sfx: 1 - v, "shin" + sfx: v})

    def coons_w(u, v):
        acc = {}
        bv = v ** P["INNER_BODY_FALLOFF"]
        bv = 1.0 - (1.0 - bv) * (1.0 - smooth((v - 0.8) / 0.2))   # rows at the flank ride the body
        terms = [((1 - bv), c0w(u)), (bv, c1w(u)), ((1 - u), d0w(v)), (u, d1w(v)),
                 (-(1 - u) * (1 - bv), c0w(0.0)), (-u * (1 - bv), c0w(1.0)), (-(1 - u) * bv, c1w(0.0)),
                 (-u * bv, c1w(1.0))]
        for f, wd in terms:
            for k, x in wd.items():
                acc[k] = acc.get(k, 0.0) + f * x
        return norm_w({k: max(0.0, x) for k, x in acc.items()})

    us = [r / 2.0 for r in R]
    nv = D["inner_rows"]
    vs = [j / (nv - 1) for j in range(nv)]
    grid = []
    for j, v in enumerate(vs):
        row = []
        for i, u in enumerate(us):
            if j == 0:
                row.append(center if i == 0 else ray_f4[i - 1])
                continue
            p = coons(c0, c1, d0, d1, u, v)
            gap = (c0(u) - c1(u)).length
            p = p - N * (P["SAG"] * 0.5 * gap * math.sin(math.pi * u) * math.sin(math.pi * v))
            if v > 0.6:   # fillet: the panel leaves the flank outward instead of tangent to the fur
                p = p + Y * side * (P["FLANK_LIFT"] * math.sin(math.pi * (v - 0.6) / 0.4) * math.sin(math.pi * min(1.0, u * 1.6)))
            row.append(mb.vert(p, coons_w(u, v)))
        grid.append(row)
    for j in range(nv - 1):
        for i in range(len(us) - 1):
            a, b, c, d = grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]
            band = 2 if nv >= 12 else 1           # attachment band: the panel rows that sit on the flank line
            pt = rpart if (j >= nv - 1 - band or (i == 0 and j >= nv - 2 - band)) else part
            mb.face((a, c, d), "Membrane", PAL["membrane"], pt, 0.04)
            mb.face((a, b, c), "Membrane", PAL["membrane"], pt, 0.04)
    return mb


# ---------------------------------------------------------------- scene, materials, armature
MATS = {}


def make_material(name, rough, emissive=0.0, two_sided=False, spec=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    ca = nt.nodes.new("ShaderNodeVertexColor")
    ca.layer_name = "Col"
    # base colour = RGB * lerp(0.45, 1, A)  (A = cavity/occlusion); Unreal: same graph on VertexColor
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["To Min"].default_value = 0.45
    mr.inputs["To Max"].default_value = 1.0
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(ca.outputs["Alpha"], mr.inputs["Value"])
    nt.links.new(ca.outputs["Color"], mul.inputs["A"])
    nt.links.new(mr.outputs["Result"], mul.inputs["B"])
    nt.links.new(mul.outputs["Result"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Specular IOR Level"].default_value = spec
    if emissive > 0:
        nt.links.new(ca.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emissive
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    m.use_backface_culling = not two_sided
    m.roughness = rough
    m.metallic = 0.0
    m["mars_two_sided"] = bool(two_sided)
    m["mars_roughness"] = rough
    m["mars_specular"] = spec
    m["mars_emissive"] = emissive
    return m


def reset_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.cameras, bpy.data.lights,
                 bpy.data.actions, bpy.data.curves):
        for d in list(coll):
            coll.remove(d)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 0.01
    sc.unit_settings.length_unit = "CENTIMETERS"
    sc.render.fps = 30
    sc.render.fps_base = 1.0
    sc.frame_start, sc.frame_end = 0, 15
    colls = {}
    for n in ("Authoring", "Rig", "Export", "Review"):
        c = bpy.data.collections.new(n)
        sc.collection.children.link(c)
        colls[n] = c
    MATS["Body"] = make_material("Body", 0.85, spec=0.25)
    MATS["Membrane"] = make_material("Membrane", 0.8, two_sided=True, spec=0.25)
    MATS["Eyes"] = make_material("Eyes", 0.4, emissive=2.0)
    return colls


def build_armature(coll, lay, rig):
    arm_data = bpy.data.armatures.new(ARM_NAME)
    arm = bpy.data.objects.new(ARM_NAME, arm_data)
    coll.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.view_layer.objects:
        o.select_set(o is arm)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    for b in rig["bones"]:
        h, t, roll_axis = lay[b["name"]]
        e = eb.new(b["name"])
        e.head, e.tail = Vector(h), Vector(t)
        e.use_deform = True
        if b["name"] == "root":
            e.roll = 0.0
        else:
            e.align_roll(Vector(roll_axis))
    for b in rig["bones"]:
        if b["parent"]:
            eb[b["name"]].parent = eb[b["parent"]]
            eb[b["name"]].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    arm_data.display_type = "STICK"
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


# ---------------------------------------------------------------- direct posing (definitions)
def qaxis(axis, deg):
    return Quaternion(nrm(axis), math.radians(deg))


def wing_rotations(side, p):
    sfx = "_l" if side > 0 else "_r"
    w, (A, T, N) = wing_points(side)
    rots = {}
    q = Quaternion()
    if p.get("twist"):
        q = qaxis(A, p["twist"] * side) @ q
    if p.get("sweep"):
        q = qaxis(-Z * side, p["sweep"]) @ q
    if p.get("adduct"):
        q = qaxis(X * side, -p["adduct"]) @ q
    if p.get("elev"):
        q = qaxis(X * side, p["elev"]) @ q
    if p.get("roll"):
        q = qaxis(U, p["roll"] * side) @ q
    rots["upperarm" + sfx] = q
    rots["forearm" + sfx] = qaxis(N, p.get("flex", 0.0))
    rots["wrist" + sfx] = qaxis(N, p.get("wflex", 0.0))
    fan = p.get("fan", 0.0)
    tilt = p.get("tilt", 0.0)
    for i in range(1, 5):
        rots["finger_0%da%s" % (i, sfx)] = fan_rotation(w, i, N, fan, p.get("fan_gap", 6.0), tilt)
        rots["finger_0%db%s" % (i, sfx)] = qaxis(N, p.get("curl", 0.0) * (0.6 + 0.2 * i))
    rots["thumb_a" + sfx] = qaxis(N, p.get("thumb", 0.0))
    return rots


def fan_close_angle(w, i, N, gap=6.0):
    d = nrm(w["kn%d" % i] - w["wrist"])
    tgt = nrm(w["elbow"] - w["wrist"])
    ang = math.degrees(math.atan2(d.cross(tgt).dot(N), d.dot(tgt)))
    if ang < 0:
        ang += 360.0
    return max(0.0, ang - (4 - i) * gap)


def fan_rotation(w, i, N, fan, gap=6.0, tilt=0.0):
    d = nrm(w["kn%d" % i] - w["wrist"])
    qf = qaxis(N, fan * fan_close_angle(w, i, N, gap))
    if tilt:
        qf = qaxis(nrm(N.cross(d)), tilt * (i - 2.5) * fan) @ qf
    return qf


def pose_rotations(pose):
    rots = {}
    body = pose.get("body", {})
    qp = Quaternion()
    if body.get("hang"):
        qp = qaxis(Y, 30.0 * body["hang"]) @ qaxis(X, 180.0 * body["hang"])
    if body.get("pitch"):
        qp = qaxis(Y, body["pitch"]) @ qp
    if body.get("roll"):
        qp = qaxis(U, body["roll"]) @ qp
    if body.get("bank"):
        qp = qaxis(X, body["bank"]) @ qp
    rots["pelvis"] = qp
    for k in ("spine", "neck", "head", "jaw"):
        if body.get(k):
            rots[k] = qaxis(Y, body[k])
    wl = pose.get("wing", {})
    wr = pose.get("wing_r", wl)
    rots.update(wing_rotations(1, wl))
    rots.update(wing_rotations(-1, wr))
    leg = pose.get("leg", {})
    for side, sfx in ((1, "_l"), (-1, "_r")):
        if leg.get("thigh"):
            rots["thigh" + sfx] = qaxis(Y, leg["thigh"])
        if leg.get("spread"):
            rots["thigh" + sfx] = qaxis(X * side, -leg["spread"]) @ rots.get("thigh" + sfx, Quaternion())
        if leg.get("knee"):
            rots["shin" + sfx] = qaxis(Y, leg["knee"])
        if leg.get("foot"):
            rots["foot" + sfx] = qaxis(Y, leg["foot"])
    ear = pose.get("ear", {})
    for side, sfx in ((1, "_l"), (-1, "_r")):
        if ear.get("base"):
            rots["ear_base" + sfx] = qaxis(Y, ear["base"])
        if ear.get("splay"):
            rots["ear_base" + sfx] = qaxis(X * side, -ear["splay"]) @ rots.get("ear_base" + sfx, Quaternion())
        if ear.get("tip"):
            rots["ear_tip" + sfx] = qaxis(Y, ear["tip"])
    return rots


AIM_KEYS = ("aim_wing", "aim_wing_r", "aim_leg")


def aim_targets(pose):
    out = {}
    wl = pose.get("aim_wing")
    wr = pose.get("aim_wing_r", wl)
    for side, sfx, spec in ((1, "_l", wl), (-1, "_r", wr)):
        for bn, t in (spec or {}).items():
            flat = None
            if len(t) > 4 and t[4] is not None:      # lie-flat twist: rest in-plane direction -> body-frame direction
                x = t[4]
                flat = (rest_xdir(bn, side), B(x[0], x[1], side * x[2]))
            out[bn + sfx] = ((t[0], t[1], side * t[2]), "spine", side * (t[3] if len(t) > 3 else 0.0), flat)
    for side, sfx in ((1, "_l"), (-1, "_r")):
        for bn, t in (pose.get("aim_leg") or {}).items():
            out[bn + sfx] = ((t[0], t[1], side * t[2]), "pelvis", 0.0, None)
    return out


def rest_xdir(bn, side):
    """Rest-pose in-plane direction of a wing bone toward the membrane it carries (armature space): for finger i the
    direction to finger i+1 (finger 4: away from finger 3), for the wrist and forearm toward the finger-4 knuckle."""
    w, (A, T, N) = wing_points(side)
    W = w["wrist"]

    def mid(i, seg):
        return (W + w["kn%d" % i]) * 0.5 if seg == "a" else (w["kn%d" % i] + w["tip%d" % i]) * 0.5

    if bn.startswith("finger_0"):
        i, seg = int(bn[8]), bn[9]
        return mid(i + 1, seg) - mid(i, seg) if i < 4 else mid(4, seg) - mid(3, seg)
    if bn == "wrist":
        return w["kn4"] - w["kn1"]
    if bn == "forearm":
        return w["kn4"] - (w["elbow"] + W) * 0.5
    return -T


def apply_pose(arm, pose):
    """Direct definition on the export bones (rig constraints must be absent or muted)."""
    rots = pose_rotations(pose)
    aims = aim_targets(pose)
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
        q = rots.get(pb.name)
        if q is None or pb.name in aims:
            pb.rotation_quaternion = Quaternion()
            continue
        r = pb.bone.matrix_local.to_quaternion()
        pb.rotation_quaternion = r.inverted() @ q @ r
    bpy.context.view_layer.update()
    for pb in arm.pose.bones:
        if pb.name not in aims:
            continue
        tgt_body, frame, twist, flat = aims[pb.name]
        fb = arm.pose.bones[frame]
        Dm = fb.matrix @ fb.bone.matrix_local.inverted()
        tgt = Dm @ B(*tgt_body)
        par = pb.parent
        m_inh = par.matrix @ (par.bone.matrix_local.inverted() @ pb.bone.matrix_local)
        head = m_inh.translation
        d_cur = (m_inh.to_3x3() @ Vector((0, 1, 0))).normalized()
        d_new = (tgt - head).normalized()
        rw = d_cur.rotation_difference(d_new)
        if flat is not None:   # turn the bone about its new axis so its membrane side faces the body-frame direction
            x_loc = pb.bone.matrix_local.to_3x3().inverted() @ flat[0]
            xa = rw @ (m_inh.to_3x3() @ x_loc)
            xt = Dm.to_3x3() @ flat[1]
            xa = (xa - d_new * xa.dot(d_new)).normalized()
            xt = (xt - d_new * xt.dot(d_new)).normalized()
            ang = math.atan2(xa.cross(xt).dot(d_new), xa.dot(xt))
            rw = Quaternion(d_new, ang) @ rw
        if twist:
            rw = Quaternion(d_new, math.radians(twist)) @ rw
        qi = m_inh.to_quaternion()
        pb.rotation_quaternion = qi.inverted() @ rw @ qi
        bpy.context.view_layer.update()


def capture(arm):
    return {pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones}


def world_rot_to_local(arm, bone, q):
    r = arm.data.bones[bone].matrix_local.to_quaternion()
    return r.inverted() @ q @ r


# ---------------------------------------------------------------- pose definitions
WRAP_SKIRT_U = -8.0   # below this u the shell keeps the girth of the torso ring there (the cloak's skirt)


def shell(u, phi_deg, c):
    """Body-frame aim target (u, fo, y) on an offset shell around the torso; clamped below the belly so targets under
    the rump keep the belly's girth instead of collapsing under the body."""
    hw, hd, fo = torso_dims(u, clamp_lo=WRAP_SKIRT_U)
    ph = math.radians(phi_deg)
    return (u, fo + (hd + c) * math.cos(ph), (hw + c) * math.sin(ph))


# Phase 3b cloak (sheet 03 WRAPPED): elbow tucked at the flank, forearm up the side of the chest to the wrist at the
# shoulder, the partly open finger fan laid flat across the front and down the own side; left over right.
# Targets are (u, phi) on a shell around the torso: phi 0 = front, +90 = the wing's own side.
WRAP_C = 3.0          # clearance of the under (right) fan above the fur (straight 8-10 cm bones sag ~1.5 cm)
WRAP_LAYER = 1.6      # the left fan rides this much higher over the whole front (left over right)
WRAP_ARM_C = 2.8      # clearance of the arm bones (their own radius ~0.8)
WRAP_ELBOW = (-7.0, 115.0)     # (u, phi) the elbow tucked at the flank
WRAP_WRIST = (3.5, 55.0)       # the forearm runs up the side of the chest to the wrist at the shoulder
# the fan: each finger segment walks its own bone length over the shell from where the previous one ended, along a
# heading in the unrolled shell (0 = straight down the body axis, +90 = across the front toward the other side)
WRAP_FAN = {1: (85.0, 80.0), 2: (62.0, 58.0), 3: (45.0, 40.0), 4: (5.0, 30.0)}           # left (over)
WRAP_FAN_UNDER = {1: (60.0, 45.0), 2: (40.0, 30.0), 3: (22.0, 12.0), 4: (0.0, 25.0)}     # right (under)
WRAP_FLANK_PHI = 95.0
WRAP_THUMB = (1.0, -25.0, 0.6)  # (du, dphi, extra clearance) from the wrist: the thumb lies along the top edge
WRAP_TWIST = {}       # per-bone twist about the aimed direction (deg), solved by --solve-wrap
WRAP_SOLUTION = os.path.join(HERE, "wrap_solution.json")
WRAP_BONES = ("upperarm", "forearm", "wrist", "finger_04a", "finger_04b", "finger_03a", "finger_03b",
              "finger_02a", "finger_02b", "finger_01a", "finger_01b", "thumb_a")


def wrap_standoff(body):
    """Mean distance (cm) by which the posed membrane stands off a shell WRAP_HUG cm outside the torso (0 = hugs)."""
    co, tris, tp = bat_audit.evaluated_tris(body)
    idx = np.unique(tris[np.isin(tp, [PART["mem_l"], PART["mem_r"]])].ravel())
    ex = []
    for p in co[idx]:
        p = Vector(p)
        u = p.dot(U)
        hw, hd, fo = torso_dims(u, clamp_lo=-6.0)
        a = (p.dot(F) - fo) / (hd + WRAP_HUG)
        b = p.dot(Y) / (hw + WRAP_HUG)
        r = math.sqrt(a * a + b * b)
        ex.append(max(0.0, r - 1.0) * 0.5 * (hw + hd + 2 * WRAP_HUG))
    return float(np.mean(ex)) if ex else 0.0


WRAP_HUG = 3.0


def wrap_layering(body):
    """Left-over-right layering in the posed wrap: from each left membrane vertex on the front (|phi| < 70) cast a ray
    toward the body axis and measure the distance to the right membrane (cm). Returns stats over the hits."""
    from mathutils.bvhtree import BVHTree
    co, tris, tp = bat_audit.evaluated_tris(body)
    verts = [Vector(c) for c in co]
    rmask = np.isin(tp, [PART["mem_r"], PART["memroot_r"]])
    tree = BVHTree.FromPolygons(verts, [tuple(t) for t in tris[rmask]], all_triangles=True)
    lidx = np.unique(tris[np.isin(tp, [PART["mem_l"]])].ravel())
    gaps, n = [], 0
    for i in lidx:
        p = verts[i]
        u = p.dot(U)
        hw, hd, fo = torso_dims(u, clamp_lo=WRAP_SKIRT_U)
        a, y = p.dot(F) - fo, p.dot(Y)
        if a <= 0 or abs(math.degrees(math.atan2(y / hw, a / hd))) > 70:
            continue
        n += 1
        inward = -(F * a + Y * y).normalized()
        hit = tree.ray_cast(p + inward * 0.01, inward, 6.0)
        if hit[0] is not None:
            gaps.append(hit[3] + 0.01)
    g = np.array(gaps)
    if not len(g):
        return {"front_left_verts": n, "over_right": 0}
    return {"front_left_verts": n, "over_right": int(len(g)), "gap_min_cm": round(float(g.min()), 3),
            "gap_p10_cm": round(float(np.percentile(g, 10)), 3), "gap_median_cm": round(float(np.median(g)), 3),
            "gap_p90_cm": round(float(np.percentile(g, 90)), 3)}
WRAP_EXTRA = {"leg": {"spread": -6}, "ear": {"base": -4}}
WRAP_HUG_WEIGHT = 150.0


def wrap_cost(res):
    """Objective for the wrap twist solve: body/leg penetration, rib penetration, left/right contact, pleat contact,
    plus the cloak term: how far the membrane flares off the body."""
    return (10.0 * (res["memb_l_body"] + res["memb_r_body"] + res["memb_l_legs"] + res["memb_r_legs"])
            + 20.0 * (res["ribs_l_body"] + res["ribs_r_body"] + res["ribs_l_legs"] + res["ribs_r_legs"])
            + 30.0 * (res["memb_l_memb_r"] + res["ribs_l_ribs_r"] + res["memb_opp_ribs"])
            + 0.15 * (res["memb_l_self"] + res["memb_r_self"])
            + WRAP_HUG_WEIGHT * res.get("standoff_cm", 0.0))


def solve_wrap(arm, body):
    """Coordinate descent over per-bone twist offsets (about each aimed bone's own axis) on top of the lie-flat twist:
    the twists turn the membrane around the ribs without moving the ribs. Scores the Wrap and the Hang (same wing
    solve, hang legs). Deterministic grid; writes WRAP_SOLUTION."""
    free = ("upperarm", "thumb_a")       # bones without a lie-flat twist search the full circle first

    bodies = list(body) if isinstance(body, (list, tuple)) else [body]

    def evaluate():   # the exact Wrap pose the rig reproduces (wings + leg spread + ears), plus the hang, every LOD
        apply_pose(arm, {"aim_wing": wrap_spec(True), "aim_wing_r": wrap_spec(False), **WRAP_EXTRA})
        r = bat_audit.intersections(bodies[0], PART)
        r["standoff_cm"] = round(wrap_standoff(bodies[0]), 4)
        extra = 0.0
        for ob in bodies[1:]:
            lr = bat_audit.intersections(ob, PART)
            extra += wrap_cost(lr) - 0.15 * (lr["memb_l_self"] + lr["memb_r_self"])
        apply_pose(arm, {"body": {"hang": 1.0, "head": 30.0}, "aim_wing": wrap_spec(True),
                         "aim_wing_r": wrap_spec(False), "aim_leg": HANG_LEG, "ear": {"base": -10}})
        for k, ob in enumerate(bodies):
            h = bat_audit.intersections(ob, PART)
            if k == 0:
                r["hang"] = h
            extra += wrap_cost(h) - 0.15 * (h["memb_l_self"] + h["memb_r_self"])
        return wrap_cost(r) + extra, r

    start = dict(WRAP_TWIST)          # warm start: the solution loaded from WRAP_SOLUTION, if any
    WRAP_TWIST.clear()
    WRAP_TWIST.update(start)
    best, res = evaluate()
    log = [{"step": "start", "cost": best, "res": res}]
    for step, span_flat, span_free in ((15.0, 45.0, 180.0), (7.5, 15.0, 15.0), (3.75, 7.5, 7.5)):
        for it in range(2):
            improved = False
            for bn in WRAP_BONES:
                span = span_free if bn in free else span_flat
                cur = WRAP_TWIST.get(bn, 0.0)
                a = -span
                while a <= span + 1e-9:
                    if abs(a) > 1e-9:
                        WRAP_TWIST[bn] = cur + a
                        c, r = evaluate()
                        if c < best - 1e-9:
                            best, res, cur, improved = c, r, cur + a, True
                    a += step
                WRAP_TWIST[bn] = cur
            log.append({"step": step, "pass": it, "cost": best, "twist": dict(WRAP_TWIST), "res": res})
            print("WRAPSOLVE step %.2f pass %d cost %.2f %s" % (step, it, best, json.dumps(WRAP_TWIST)))
            if not improved:
                break
    with open(WRAP_SOLUTION, "w") as fh:
        json.dump({"twist_deg": WRAP_TWIST, "cost": best, "result": res, "log": log}, fh, indent=1)
    return res


def shell_walk(u, phi, c, heading, length, steps=12):
    """Walk `length` cm over the shell (clearance c) from (u, phi) along `heading` (deg) in the unrolled surface."""
    h = math.radians(heading)
    dl = length / steps
    for _ in range(steps):
        hw, hd, fo = torso_dims(u, clamp_lo=WRAP_SKIRT_U)
        R = 0.5 * (hw + hd) + c
        u -= math.cos(h) * dl
        phi -= math.degrees(math.sin(h) * dl / R)
    return u, phi


def wrap_spec(over):
    """Left wing (over=True) / right wing aim spec: (u, fo, y, twist offset, lie-flat direction (du, dfo, dy))."""
    lay = WRAP_LAYER if over else 0.0
    cf, ca = WRAP_C + lay, WRAP_ARM_C + 0.5 * lay
    tw = WRAP_TWIST
    w, _ = wing_points(1)
    E = shell(WRAP_ELBOW[0], WRAP_ELBOW[1], ca + 1.6)
    Wp = shell(WRAP_WRIST[0], WRAP_WRIST[1], ca)
    kn, tp, knu = {}, {}, {}
    for i, (ha, hb) in (WRAP_FAN if over else WRAP_FAN_UNDER).items():
        la, lb = (w["kn%d" % i] - w["wrist"]).length, (w["tip%d" % i] - w["kn%d" % i]).length
        ku = shell_walk(WRAP_WRIST[0], WRAP_WRIST[1], cf, ha, la)
        tu = shell_walk(ku[0], ku[1], cf, hb, lb)
        knu[i] = ku
        kn[i], tp[i] = shell(ku[0], ku[1], cf), shell(tu[0], tu[1], cf)

    def sub(p, q):
        return tuple(x - y for x, y in zip(p, q))

    def mid(p, q):
        return tuple(0.5 * (x + y) for x, y in zip(p, q))

    s = {"upperarm": E + (tw.get("upperarm", 0.0), None),
         "forearm": Wp + (tw.get("forearm", 0.0), sub(kn[4], mid(E, Wp))),
         "wrist": kn[2] + (tw.get("wrist", 0.0), sub(kn[4], kn[1]))}
    for i in range(1, 4):
        xa = sub(mid(Wp, kn[i + 1]), mid(Wp, kn[i]))
        xb = sub(mid(kn[i + 1], tp[i + 1]), mid(kn[i], tp[i]))
        s["finger_0%da" % i] = kn[i] + (tw.get("finger_0%da" % i, 0.0), xa)
        s["finger_0%db" % i] = tp[i] + (tw.get("finger_0%db" % i, 0.0), xb)
    s["thumb_a"] = shell(WRAP_WRIST[0] + WRAP_THUMB[0], WRAP_WRIST[1] + WRAP_THUMB[1], ca + WRAP_THUMB[2]) + (tw.get("thumb_a", 0.0), None)
    # finger 4 carries the inner panel: its chord runs to the flank line (phi WRAP_FLANK_PHI on the fur)
    for seg, m in (("a", mid(Wp, kn[4])), ("b", mid(kn[4], tp[4]))):
        fl = shell(m[0], WRAP_FLANK_PHI, 0.3)
        s["finger_04" + seg] = (kn[4] if seg == "a" else tp[4]) + (tw.get("finger_04" + seg, 0.0), sub(fl, m))
    return s


_HALF_P2 = {   # Phase 2 half-fold targets, re-seated for the Phase 3 body (+8 cm up the axis, -2 cm fo, +2 cm out; searched)
    "upperarm": (4.6, -1.2, 12.0), "forearm": (11.5, 0.8, 15.5), "wrist": (8.0, -0.5, 20.0),
    "finger_01a": (6.5, -1.4, 22.5), "finger_01b": (-2.5, -2.4, 26.5),
    "finger_02a": (3.6, -1.8, 21.0), "finger_02b": (-5.5, -3.0, 22.5),
    "finger_03a": (1.4, -2.0, 18.8), "finger_03b": (-8.5, -3.2, 18.5),
    "finger_04a": (0.4, -1.6, 15.2), "finger_04b": (-8.2, -2.4, 13.4),
}
HALF_WING = {k: (v[0] + 8.0, v[1] - 2.0, v[2] + 2.0) for k, v in _HALF_P2.items()}
HANG_LEG = {"thigh": (-11.0, 1.2, 2.6), "shin": (-15.8, 1.0, 2.2), "foot": (-17.0, 3.2, 2.1)}

FLAP_KEYS = {
    0: {"wing": {"elev": 38, "sweep": -6, "flex": 22, "wflex": 18, "fan": 0.12, "curl": 6},
        "body": {"pitch": -3, "head": 3}, "ear": {"base": 6}, "leg": {"thigh": 6}},
    4: {"wing": {"elev": -6, "sweep": 10, "flex": 0, "wflex": 0, "fan": 0.0, "curl": 0, "twist": 6},
        "body": {"pitch": 0, "head": 0}, "ear": {"base": 2}, "leg": {"thigh": 0}},
    8: {"wing": {"elev": -48, "sweep": 26, "flex": 6, "wflex": 4, "fan": 0.04, "curl": -4, "twist": 36, "roll": -10},
        "body": {"pitch": 4, "head": -3}, "ear": {"base": -6}, "leg": {"thigh": -6}},
    12: {"wing": {"elev": 8, "sweep": 4, "flex": 48, "wflex": -28, "fan": 0.16, "curl": 10, "twist": 28, "roll": -6},
         "body": {"pitch": 1, "head": 1}, "ear": {"base": -2}, "leg": {"thigh": 3}},
}

BANK = {  # BankLeft = the bat rolls toward its own left (left wing low); BankRight mirrors it
    "BankLeft": {"body": {"bank": -24, "head": 4}, "wing": {"elev": -16, "sweep": 22, "twist": 24, "flex": 8, "wflex": 10,
                                                            "fan": 0.06},
                 "wing_r": {"elev": 2, "sweep": 4, "flex": 4}, "ear": {"base": 3}},
    "BankRight": {"body": {"bank": 24, "head": 4}, "wing_r": {"elev": -16, "sweep": 22, "twist": 24, "flex": 8, "wflex": 10,
                                                              "fan": 0.06},
                  "wing": {"elev": 2, "sweep": 4, "flex": 4}, "ear": {"base": 3}},
}


def lerp_pose(a, b, t):
    out = {}
    for k in set(a) | set(b):
        if k in AIM_KEYS:
            continue
        da, db = a.get(k, {}), b.get(k, {})
        out[k] = {kk: lerp(da.get(kk, 0.0), db.get(kk, 0.0), t) for kk in set(da) | set(db)}
    return out


def flap_pose(frame):
    keys = sorted(FLAP_KEYS) + [15]
    f = frame % 15.0
    for a, b in zip(keys, keys[1:]):
        if a <= f <= b:
            t = (f - a) / (b - a)
            return lerp_pose(FLAP_KEYS[a], FLAP_KEYS[b if b in FLAP_KEYS else 0], smooth(t))
    return FLAP_KEYS[0]


# ---------------------------------------------------------------- measurement
def measure(obj):
    co, tris, tp = bat_audit.evaluated_tris(obj)
    used = lambda parts: np.unique(tris[np.isin(tp, parts)].ravel())
    span = float(co[:, 1].max() - co[:, 1].min())
    th = co[used([PART["torso"], PART["head"], PART["face"], PART["tuft"], PART["ruff"]])]
    proj = th @ np.array(U)
    torso = co[used([PART["torso"]])]
    ub, ear_tip = np.array(ear_points(1)[0]), np.array(ear_points(1)[2])
    nose_i = np.argmax(th[:, 0])
    rump = np.array(B(P["RUMP_U"], 0.4))
    return {
        "span_y_cm": round(span, 3),
        "bounds_min_ue": [round(float(co[:, 0].min()), 3), round(float(-co[:, 1].max()), 3), round(float(co[:, 2].min()), 3)],
        "bounds_max_ue": [round(float(co[:, 0].max()), 3), round(float(-co[:, 1].min()), 3), round(float(co[:, 2].max()), 3)],
        "nose_to_rump_along_body_axis_cm": round(float(proj.max() - proj.min()), 3),
        "nose_tip_to_rump_point_cm": round(float(np.linalg.norm(th[nose_i] - rump)), 3),
        "torso_width_cm": round(float(torso[:, 1].max() - torso[:, 1].min()), 3),
        "torso_depth_cm": round(float((torso @ np.array(F)).max() - (torso @ np.array(F)).min()), 3),
        "ear_base_to_tip_cm": round(float(np.linalg.norm(ear_tip - ub)), 3),
        "nose_x_cm": round(float(th[nose_i, 0]), 3),
    }


# ---------------------------------------------------------------- build helpers
def orient_closed_islands(mb):
    """Flip any closed non-membrane island with negative signed volume (deterministic). Returns flip count."""
    nv = len(mb.v)
    parent = list(range(nv))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for f in mb.f:
        r0 = find(f[0])
        for i in f[1:]:
            ri = find(i)
            if ri != r0:
                parent[ri] = r0
    vol, isl_faces = {}, {}
    for fi, f in enumerate(mb.f):
        if mb.fm[fi] == SLOTS.index("Membrane"):
            continue
        r = find(f[0])
        p0 = mb.v[f[0]]
        for a, b in zip(f[1:-1], f[2:]):
            vol[r] = vol.get(r, 0.0) + p0.dot(mb.v[a].cross(mb.v[b])) / 6.0
        isl_faces.setdefault(r, []).append(fi)
    flips = 0
    for r, v in vol.items():
        if v < 0:
            flips += 1
            for fi in isl_faces[r]:
                mb.f[fi] = mb.f[fi][::-1]
    return flips


def build_lod(lod, colls, keep_parts=False):
    D.clear()
    D.update(DETAIL[lod])
    parts = {"Torso": build_torso(), "Shingles": build_shingles(), "Head": build_head()}
    face, eyes = build_face()
    parts["Face"], parts["Eyes"] = face, eyes
    parts["Ear_L"] = build_ear(1)
    parts["Leg_L"] = build_leg(1)
    parts["WingRibs_L"] = build_wing_ribs(1)
    parts["Membrane_L"] = build_membrane(1)
    mirrored = ("Ear_L", "Leg_L", "WingRibs_L", "Membrane_L")
    if keep_parts:
        for name, mb in parts.items():
            mb.to_object("AUTH_" + name, colls["Authoring"], groups=True)
    full = MB(LOD_NAMES[lod])
    for name, mb in parts.items():
        full.extend(mb)
        if name in mirrored:
            full.extend(mb, mirror=True)
    flips = orient_closed_islands(full)
    ob = full.to_object(LOD_NAMES[lod], colls["Export"])
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="BEAUTY")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.shade_flat()
    return ob, flips


def uv_unwrap(ob):
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.view_layer.objects:
        o.select_set(o is ob)
    ob.data.uv_layers.new(name="UV0")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    # lightmap pack: one chart per face (pairs where possible), packed without overlap; the mesh is flat shaded, so
    # every face already owns its corners and the extra UV seams cost no render vertices
    bpy.ops.uv.lightmap_pack(PREF_CONTEXT="ALL_FACES", PREF_PACK_IN_ONE=True, PREF_NEW_UVLAYER=False,
                             PREF_BOX_DIV=48, PREF_MARGIN_DIV=0.3)
    bpy.ops.object.mode_set(mode="OBJECT")


def weights_check(ob, bone_names):
    gname = {g.index: g.name for g in ob.vertex_groups}
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


# ---------------------------------------------------------------- main
def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    do_save = "--no-save" not in argv
    fails = []
    with open(RIG_JSON) as fh:
        rig = json.load(fh)
    colls = reset_scene()

    for _ in range(4):           # span fit: tip-1 apex lands at SPAN/2
        w, fr = wing_points(1)
        tip_y = finger_path(w, 1, 2.0, fr).y
        S = w["shoulder"]
        SPAN_K[0] *= (P["SPAN"] / 2.0 - S.y) / (tip_y - S.y)

    lods, flips = [], []
    for lod in range(3):
        ob, fl = build_lod(lod, colls, keep_parts=(lod == 0))
        lods.append(ob)
        flips.append(fl)
    colls["Authoring"].hide_render = True
    colls["Authoring"].hide_viewport = True

    lay = bone_layout()
    arm = build_armature(colls["Export"], lay, rig)
    for ob in lods:
        ob.parent = arm
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    if os.path.exists(WRAP_SOLUTION):
        with open(WRAP_SOLUTION) as fh:
            WRAP_TWIST.update(json.load(fh)["twist_deg"])
    if "--solve-wrap" in argv:
        report_solve = solve_wrap(arm, lods)
        print("WRAPSOLVE_RESULT", json.dumps(report_solve))


    # ---- hierarchy
    names = [b.name for b in arm.data.bones]
    want = [(b["name"], b["parent"]) for b in rig["bones"]]
    got = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
    if len(names) != 42 or sorted(names) != sorted(n for n, _ in want):
        fails.append("bone names %d" % len(names))
    for n, p in want:
        if got.get(n, "MISSING") != p:
            fails.append("parent %s=%s want %s" % (n, got.get(n), p))
    rootm = arm.data.bones["root"].matrix_local
    if (rootm - Matrix.Identity(4)).to_3x3().to_quaternion().angle > 1e-5 or rootm.translation.length > 1e-6:
        fails.append("root rest not identity")

    # ---- per-LOD mesh facts: weights, UV0, cavity alpha, defects, render verts
    report = {"lods": {}, "orientation_fixes": flips}
    for lod, ob in enumerate(lods):
        uv_unwrap(ob)
        amin, amean = bat_audit.bake_cavity(ob)
        wc = weights_check(ob, got)
        au = bat_audit.defect_audit(ob)
        uvr = bat_audit.uv_overlap(ob)
        rv = bat_audit.render_verts(ob)
        me = ob.data
        me.calc_loop_triangles()
        per_slot = {s: int(sum(1 for p in me.polygons if p.material_index == i)) for i, s in enumerate(SLOTS)}
        info = {"object": ob.name, "tris": len(me.loop_triangles), "verts": len(me.vertices), "render_verts": rv,
                "slots": [m.name for m in me.materials], "tris_per_slot": per_slot, "weights": wc, "audit": au,
                "uv": uvr, "cavity_alpha_min_mean": [amin, amean]}
        report["lods"][lod] = info
        print("LOD%d %s" % (lod, json.dumps(info)))
        if wc["max_influences"] > 4 or wc["unnormalized"] or wc["unweighted"] or wc["non_bone_groups"]:
            fails.append("LOD%d weights %s" % (lod, wc))
        if bat_audit.defects_total(au):
            fails.append("LOD%d defects %d" % (lod, bat_audit.defects_total(au)))
        if uvr["overlap_px"] or uvr["out_of_range_loops"]:
            fails.append("LOD%d uv overlap %d oob %d" % (lod, uvr["overlap_px"], uvr["out_of_range_loops"]))
        if [m.name for m in me.materials] != list(SLOTS):
            fails.append("LOD%d slots" % lod)
        if me.shape_keys is not None:
            fails.append("LOD%d has shape keys" % lod)
    for ob in lods[1:]:
        ob.hide_render = True
        ob.hide_set(True)

    # ---- bind measurements
    apply_pose(arm, {})
    meas = measure(lods[0])
    print("MEASURE", json.dumps(meas))
    report["measure"] = meas
    if abs(meas["span_y_cm"] - P["SPAN"]) > 0.3:
        fails.append("span %.2f" % meas["span_y_cm"])
    if abs(meas["torso_width_cm"] - 12.0) > 0.05:
        fails.append("torso width %.3f" % meas["torso_width_cm"])
    if abs(meas["nose_to_rump_along_body_axis_cm"] - 22.0) > 0.3:
        fails.append("nose-to-rump %.3f" % meas["nose_to_rump_along_body_axis_cm"])

    # ---- 1. DEFINE + CAPTURE poses directly on the export bones
    direct = {}

    def cap(name, pose):
        apply_pose(arm, pose)
        direct[name] = {"local": capture(arm), "mats": bat_rig.pose_matrices(arm)}

    cap("Spread", {})
    for f in range(16):
        cap("flap_%02d" % f, flap_pose(f))
    cap("HalfFold", {"aim_wing": HALF_WING})
    cap("Wrap", {"aim_wing": wrap_spec(True), "aim_wing_r": wrap_spec(False)})
    report["wrap_standoff_cm"] = round(wrap_standoff(lods[0]), 3)
    report["wrap_layering"] = wrap_layering(lods[0])
    print("WRAPLAYER", json.dumps(report["wrap_layering"]))
    report["wrap_rib_body_by_bone"] = bat_audit.overlap_detail(lods[0], PART, ("rib_l", "rib_r"),
                                                               ("torso", "head", "face", "tuft", "ear", "ruff"))
    print("WRAPDETAIL standoff %.3f ribs-body %s" % (report["wrap_standoff_cm"], report["wrap_rib_body_by_bone"]))
    cap("WrapFull", {"aim_wing": wrap_spec(True), "aim_wing_r": wrap_spec(False), **WRAP_EXTRA})
    cap("HangFK", {"body": {"hang": 1.0, "head": 30.0}, "aim_wing": wrap_spec(True), "aim_wing_r": wrap_spec(False),
                   "aim_leg": HANG_LEG, "ear": {"base": -10}})
    for n, pz in BANK.items():
        cap(n, pz)
    # control-table rotations (local) for the rig
    fold_half = {k: v for k, v in direct["HalfFold"]["local"].items() if k in bat_rig.wing_bones("_l") + bat_rig.wing_bones("_r")}
    fold_wrap = {k: v for k, v in direct["Wrap"]["local"].items() if k in fold_half}
    fan = {}
    for side, sfx in ((1, "_l"), (-1, "_r")):
        w, (A, T, N) = wing_points(side)
        for i in range(1, 5):
            bn = "finger_0%da%s" % (i, sfx)
            fan[bn] = world_rot_to_local(arm, bn, fan_rotation(w, i, N, 1.0))
    ear_alert, ear_flat, ear_twitch = {}, {}, {}
    for side, sfx in ((1, "_l"), (-1, "_r")):
        ear_alert["ear_base" + sfx] = world_rot_to_local(arm, "ear_base" + sfx, qaxis(X * side, 8) @ qaxis(Y, 12))
        ear_alert["ear_tip" + sfx] = world_rot_to_local(arm, "ear_tip" + sfx, qaxis(Y, 6))
        ear_flat["ear_base" + sfx] = world_rot_to_local(arm, "ear_base" + sfx, qaxis(X * side, -38) @ qaxis(Y, -42))
        ear_flat["ear_tip" + sfx] = world_rot_to_local(arm, "ear_tip" + sfx, qaxis(Y, -14))
        ear_twitch["ear_tip" + sfx] = world_rot_to_local(arm, "ear_tip" + sfx, qaxis(Y, -26) @ qaxis(X * side, -10))
        ear_twitch["ear_base" + sfx] = world_rot_to_local(arm, "ear_base" + sfx, qaxis(Y, -6))
    jaw_open = world_rot_to_local(arm, "jaw", qaxis(Y, 30))
    apply_pose(arm, {})

    # ---- 2. RIG
    ctrl = bat_rig.build(arm, colls["Rig"], {"fold_half": fold_half, "fold_wrap": fold_wrap, "fan": fan,
                                              "ear_alert": ear_alert, "ear_flat": ear_flat, "ear_twitch": ear_twitch,
                                              "jaw_open": jaw_open})
    bpy.context.view_layer.objects.active = arm
    rig_check = {}

    def fk_values(local, skip=()):
        return {"CTL_" + k: q for k, q in local.items() if k != "root" and k not in skip}

    def check(name, values, ref):
        bat_rig.set_controls(ctrl, values)
        dp, da = bat_rig.compare(bat_rig.pose_matrices(arm), direct[ref]["mats"])
        rig_check[name] = {"max_head_cm": round(dp, 6), "max_rot_deg": round(da, 5)}
        if dp > 1e-3 or da > 0.01:
            fails.append("rig %s differs from direct (%.4f cm %.4f deg)" % (name, dp, da))

    wingset = set(fold_half)
    check("Spread", {}, "Spread")
    for f in (0, 4, 8, 12):
        check("flap_%02d" % f, fk_values(direct["flap_%02d" % f]["local"]), "flap_%02d" % f)
    check("HalfFold (fold 0.5)", {"fold_l": 0.5, "fold_r": 0.5}, "HalfFold")
    check("Wrap (fold 1)", {"fold_l": 1.0, "fold_r": 1.0}, "Wrap")
    for n in BANK:
        check(n, fk_values(direct[n]["local"]), n)
    print("RIGCHECK", json.dumps(rig_check))
    report["rig_vs_direct"] = rig_check

    # ---- 3. CONTROL ACTIONS: flap test + pose library
    ctrl.animation_data_create()
    act = bpy.data.actions.new(FLAP_CTL_ACTION)
    act.use_fake_user = True
    ctrl.animation_data.action = act
    for f in range(16):
        bat_rig.set_controls(ctrl, fk_values(direct["flap_%02d" % f]["local"]))
        bat_rig.key_all(ctrl, f)
    ctrl.animation_data.action = None
    bat_rig.reset(ctrl)

    wrapv = fk_values(direct["WrapFull"]["local"], skip=wingset)
    wrapv.update({"fold_l": 1.0, "fold_r": 1.0})
    # hang: body/head/ears/legs FK from the definition, wings by the fold slider, feet planted by the foot targets
    hangv = fk_values(direct["HangFK"]["local"], skip=wingset)
    hangv.update({"fold_l": 1.0, "fold_r": 1.0})
    bat_rig.set_controls(ctrl, hangv)
    feet = {s: arm.pose.bones["foot_" + s].matrix.copy() for s in "lr"}
    toes = [arm.pose.bones["foot_" + s].tail.copy() for s in "lr"]
    raw = (toes[0] + toes[1]) / 2.0
    BAR_R = 1.0
    # the perch bar: a fixture along Y whose height is solved against the FK feet so the deepest claw vertex grips
    # 0.12 cm into it, then rounded to 0.25 cm; the foot targets move by the (rounded - solved) offset and the IK
    # chain solves the legs onto the bar (perch slider = 1)
    fco, ftris, ftp = bat_audit.evaluated_tris(lods[0])
    fidx = set()
    for vgn in ("foot_l", "foot_r"):
        gi = lods[0].vertex_groups[vgn].index
        fidx |= {v.index for v in lods[0].data.vertices if any(g.group == gi and g.weight > 0.5 for g in v.groups)}
    fv0 = fco[sorted(fidx)]
    bx = round(raw.x * 4.0) / 4.0

    def grip(z):
        return float((np.sqrt((fv0[:, 0] - bx) ** 2 + (fv0[:, 2] - z) ** 2) - BAR_R).min())

    lo, hi = raw.z - 3.0, raw.z + 6.0
    for _ in range(60):
        mid = 0.5 * (lo + hi)
        if grip(mid) < -0.12:
            lo = mid
        else:
            hi = mid
    z_exact = 0.5 * (lo + hi)
    bar_c = Vector((bx, 0.0, round(z_exact * 4.0) / 4.0))
    off = Vector((0.0, 0.0, bar_c.z - z_exact))
    for s in "lr":
        M = feet[s].copy()
        M.translation = M.translation + off
        hangv["foot_ik_" + s] = M
    hangv["perch"] = 1.0
    poses = {
        "Spread": {},
        "Up": fk_values(direct["flap_00"]["local"]),
        "Down": fk_values(direct["flap_08"]["local"]),
        "Recover": fk_values(direct["flap_12"]["local"]),
        "HalfFold": {"fold_l": 0.5, "fold_r": 0.5},
        "Wrap": wrapv,
        "BankLeft": fk_values(direct["BankLeft"]["local"]),
        "BankRight": fk_values(direct["BankRight"]["local"]),
        "Hang": hangv,
        "Screech": {"jaw_open": 1.0, "ear_alert": 1.0},
        "EarsFlat": {"ear_alert": -1.0, "ear_twitch": 0.0},
    }
    for n, v in poses.items():
        bat_rig.pose_action(ctrl, POSE_PREFIX + n, v)

    # ---- 4. EXTREME POSES through the rig, every LOD: intersections; hang contact
    report["poses"] = {}
    extreme = ("Spread", "Up", "Down", "Recover", "HalfFold", "Wrap", "BankLeft", "BankRight", "Hang")
    for n in extreme:
        bat_rig.use_action(ctrl, bpy.data.actions[POSE_PREFIX + n])
        report["poses"][n] = {}
        for lod, ob in enumerate(lods):
            report["poses"][n]["LOD%d" % lod] = bat_audit.intersections(ob, PART)
        print("ISECT %-10s %s" % (n, json.dumps(report["poses"][n]["LOD0"])))
        if n == "Hang":
            co, tris, tp = bat_audit.evaluated_tris(lods[0])
            feet_v = set()
            for vg in ("foot_l", "foot_r"):
                gi = lods[0].vertex_groups[vg].index
                feet_v |= {v.index for v in lods[0].data.vertices
                           if any(g.group == gi and g.weight > 0.5 for g in v.groups)}
            fv = co[sorted(feet_v)]
            dist = np.sqrt((fv[:, 0] - bar_c.x) ** 2 + (fv[:, 2] - bar_c.z) ** 2) - BAR_R
            per_side = {}
            for s, sgn in (("l", 1), ("r", -1)):
                m = (fv[:, 1] * sgn) > 0
                per_side[s] = {"min_surface_dist_cm": round(float(dist[m].min()), 3),
                               "verts_within_0.25cm": int((np.abs(dist[m]) < 0.25).sum()),
                               "verts_inside_bar": int((dist[m] < -0.05).sum())}
            ik_err = max((arm.pose.bones["shin_" + s].tail - hangv["foot_ik_" + s].translation).length for s in "lr")
            report["hang"] = {"bar_centre_blender": list(bar_c), "bar_radius_cm": BAR_R, "fk_to_bar_offset_cm":
                              [round(x, 3) for x in off], "ik_ankle_error_cm": round(ik_err, 4), "feet": per_side,
                              "root_world": list(arm.pose.bones["root"].head)}
            print("HANG", json.dumps(report["hang"]))
            if ik_err > 0.05:
                fails.append("hang IK ankle error %.3f" % ik_err)
    report["fold_slider_inbetweens_LOD0"] = {}
    for fv in (0.25, 0.75):
        bat_rig.set_controls(ctrl, {"fold_l": fv, "fold_r": fv})
        report["fold_slider_inbetweens_LOD0"][str(fv)] = bat_audit.intersections(lods[0], PART)
        print("FOLDSLIDER %.2f %s" % (fv, json.dumps(report["fold_slider_inbetweens_LOD0"][str(fv)])))
    flap_frames = {}
    bat_rig.use_action(ctrl, bpy.data.actions[FLAP_CTL_ACTION], 0)
    for f in range(16):
        bpy.context.scene.frame_set(f)
        flap_frames[f] = bat_audit.intersections(lods[0], PART)
    keys_cross = ("memb_l_body", "memb_r_body", "memb_l_legs", "memb_r_legs", "ribs_l_body", "ribs_r_body",
                  "memb_l_memb_r", "ribs_l_ribs_r", "memb_opp_ribs")
    report["flap_all_frames_LOD0"] = {f: {k: v for k, v in r.items() if k in keys_cross or k.endswith("self")}
                                      for f, r in flap_frames.items()}
    worst = {k: max(r[k] for r in flap_frames.values()) for k in keys_cross}
    print("FLAPFRAMES worst over 16 frames %s" % json.dumps(worst))
    bpy.context.scene.frame_set(0)
    bat_rig.use_action(ctrl, None)
    bat_rig.reset(ctrl)
    bpy.context.view_layer.update()

    # ---- review objects (rulers, perch bar) for render_cellar_bat.py
    rv = colls["Review"]
    cam = bpy.data.objects.new("ReviewCam", bpy.data.cameras.new("ReviewCam"))
    rv.objects.link(cam)
    bpy.context.scene.camera = cam

    def ruler(name, origin, axis, length, seg=10.0, thick=0.6):
        mb = MB(name)
        axis = nrm(axis)
        e1, e2 = ring_frame(axis)
        for k in range(int(round(length / seg))):
            p0 = Vector(origin) + axis * (k * seg)
            colr = (0.92, 0.9, 0.85) if k % 2 == 0 else (0.75, 0.25, 0.2)
            tube(mb, [p0, p0 + axis * seg], [thick, thick], [{"root": 1}] * 2, colr, "torso", sides=4, ref=e1,
                 jitter=0.0)
        ob = mb.to_object(name, rv, groups=False)
        ob["review"] = "ruler"
        return ob

    ruler("Ruler_Y_80cm", (-25.0, -40.0, -26.0), Y, 80.0)
    ruler("Ruler_Z_40cm", (0.0, 43.0, -26.0), Z, 40.0)
    ruler("Ruler_X_30cm", (-15.0, -42.0, -26.0), X, 30.0)
    mbb = MB("PerchBar")
    tube(mbb, [bar_c + Vector((0, -16, 0)), bar_c + Vector((0, 16, 0))], [BAR_R, BAR_R], [{"root": 1}] * 2,
         hexcol("#5A4030"), "torso", sides=10, ref=Z, jitter=0.03)
    bar = mbb.to_object("PerchBar", rv, groups=False)
    bar.hide_render = True
    cu = bpy.data.curves.new("Label", "FONT")
    cu.body = "rulers: 10 cm segments | span %.1f cm" % meas["span_y_cm"]
    cu.size = 2.6
    txt = bpy.data.objects.new("Label", cu)
    rv.objects.link(txt)
    txt.location = (0.0, -40.0, -33.0)
    txt.rotation_euler = (math.pi / 2, 0, math.pi / 2)

    report["params"] = {k: v for k, v in P.items() if k != "WING2D"}
    report["span_k"] = SPAN_K[0]
    report["detail"] = {k: {kk: vv for kk, vv in v.items() if kk not in ("R",)} for k, v in DETAIL.items()}
    report["wrap"] = {"clearance_cm": WRAP_C, "layer_cm": WRAP_LAYER, "twist_deg": dict(WRAP_TWIST),
                      "left_spec": wrap_spec(True), "right_spec": wrap_spec(False)}
    report["controls"] = sorted(pb.name for pb in ctrl.pose.bones)
    os.makedirs(REVIEW, exist_ok=True)
    with open(MEASURE_JSON, "w") as fh:
        json.dump(report, fh, indent=1, default=lambda o: list(o))
    scene = bpy.context.scene
    scene.frame_set(0)
    if do_save:
        os.makedirs(os.path.dirname(BLEND_FILE), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=BLEND_FILE)
    if fails:
        print("CELLAR_BAT_FAIL " + "; ".join(fails))
        sys.exit(1)
    print("CELLAR_BAT_OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("CELLAR_BAT_FAIL exception")
        sys.exit(1)
