"""Pale Crawler R01: a reproducible, parametric low-poly spider (eight walking legs) built headless in Blender 5.2 from the
saved concepts in docs/art/pale-crawler-model-r01/, saved as an editable .blend, rendered for review and exported as the
segmented static-mesh pieces the project's rigid-piece crawler presentation consumes (Mars_Crawler_EntityScript: a body,
upper/lower leg segments, a foot, a chelicera), with JSON sidecars and an eight-leg assembly manifest
(SCHEMA.md beside this file).

Everything is authored in the UNREAL frame and unit: +X forward, +Y right, +Z up, centimetres, the spider standing on
z = 0 in its neutral stance. Blender geometry is derived from it in exactly one place (`ue_to_blender`: (x, -y, z) * 0.01
with the face winding reversed, since that map is a mirror) and the FBX export uses the project's exporter convention
(axis_forward -Z, axis_up Y, FBX_SCALE_NONE), under which Unreal reads the geometry back as (x, -y, z) * 100 = the
authored numbers. Nothing is scaled in Unreal.

Anatomy (four forms per leg, three body regions, kept as separate source objects in the .blend):
  cephalothorax shell (ivory, warm underside), sternum (dark hip block), pedicel (dark), abdomen (ivory, warm underside),
  two eye sockets (dark) with two eyes (amber), two chelicerae (ivory shaft, dark tip);
  per leg: coxa (dark root knuckle + short dark root), femur (one straight ascending bar), tibia (one straight descending
  bar), tarsus (short tapered tip, dark point) with a dark knee knuckle and a dark ankle collar.

Render assemblies (what is exported; the two-segment runtime convention):
  Body        = shell + sternum + pedicel + abdomen + sockets + eyes, origin at its bounds centre, +X forward
  LegUpper<P> = coxa + femur + knee knuckle:  pivot at the hip-knee midpoint, +X hip -> knee, +Y toward the pole
  LegLower<P> = tibia + ankle collar + tarsus: pivot at the knee-foot midpoint, +X knee -> foot tip, +Y toward the pole
  Foot        = the claw tip cap, pointing -Z, centred on its bounds (placed at the foot point by the consumer)
  Chelicera   = the right chelicera, pivot at its root, +X root -> tip, +Z its front face
  for P in Front, MidFront, MidBack, Back: 11 unique meshes, 27 instances. A left leg wears the right pair's pieces under a
  proper rotation (the cross sections are mirror-symmetric about the leg's own plane); nothing is mirrored by scale.
  The coxa is part of the upper assembly and the tarsus part of the lower one: they are NOT independently articulated.

Run (Blender 5.2, numpy):
  blender -b --factory-startup --python build_pale_crawler.py -- [--no-save] [--no-sheets] [--no-export]
Prints PALE_CRAWLER_OK when every internal check passed, PALE_CRAWLER_FAIL + reasons otherwise. The round trip through a
clean Blender scene is validate_roundtrip.py; the Unreal side is pale_crawler_ue.py.
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

# ---------------------------------------------------------------- locations
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
ART = os.path.join(REPO, "docs", "art", "pale-crawler-model-r01", "production")
BLEND_FILE = os.path.join(ART, "source", "PaleCrawler_R01.blend")
EXPORT_DIR = os.path.join(ART, "export")
REVIEW_DIR = os.path.join(ART, "review")
UE_MESH_FOLDER = "/Game/ArtCandidates/PaleCrawler/R01/Meshes"
PREFIX, SUFFIX = "PaleCrawler_R01_", "_Mars_SM"
PAIRS = ("Front", "MidFront", "MidBack", "Back")
SLOTS = ("Ivory", "Underside", "Joint", "Eye")
MATERIALS = {  # sRGB 0-1 and roughness, the four swatches of the concept sheets
    "Ivory": ((0.86, 0.80, 0.70), 0.80), "Underside": ((0.66, 0.56, 0.44), 0.85),
    "Joint": ((0.22, 0.21, 0.20), 0.70), "Eye": ((0.95, 0.55, 0.12), 0.35)}
CHEF_GREY = (0.45, 0.45, 0.47)

# ---------------------------------------------------------------- build parameters (Unreal cm, neutral stance, ground z = 0)
P = {
    "BODY_LENGTH_CM": 50.0,            # nose to abdomen tip (cephalothorax + pedicel + abdomen), legs/chelicerae excluded
    "STANCE_WIDTH_CM": 180.0,          # outer foot tip to outer foot tip (sets the MidFront pair's reach)
    "KNEE_HEIGHT_CM": 60.0,            # the highest knee (MidBack pair) above the ground
    "CHEF_HEIGHT_CM": 140.0,           # the scale figure
    "BODY_REF_Z_CM": 24.0,             # the shell's mid-plane above the ground; the body rides low under the knees
    "CEPHALOTHORAX_LENGTH_CM": 28.0,
    "PEDICEL_LENGTH_CM": 4.0,          # abdomen length = BODY_LENGTH - cephalothorax - pedicel
    "CEPHALOTHORAX_HALF_WIDTH_CM": 14.0,
    "SHELL_TOP_CM": 12.0,              # shell top over BODY_REF_Z
    "SHELL_BOTTOM_CM": -7.0,           # shell bottom under BODY_REF_Z (the sternum hangs below it)
    "STERNUM_BOTTOM_CM": -11.0,        # sternum bottom under BODY_REF_Z -> 14 cm of ground clearance
    "ABDOMEN_HALF_WIDTH_CM": 11.0,
    "ABDOMEN_HALF_HEIGHT_CM": 10.0,
    "HIP_HALF_WIDTH_CM": 11.5,         # hips sit this far off the centreline, on the sternum's flanks
    "HIP_DROP_CM": 6.0,                # hips this far under BODY_REF_Z
    "HIP_X_CM": (17.0, 10.0, 2.0, -5.0),             # four socket pairs along the cephalothorax (body x, nose at +25)
    "LEG_YAW_DEG": (38.0, 72.0, 108.0, 142.0),       # horizontal direction of each right leg from +X
    "LEG_REACH_CM": (86.0, None, 82.0, 84.0),        # hip -> foot tip, horizontal; None = from STANCE_WIDTH_CM
    "KNEE_Z_OFFSET_CM": (-5.0, -1.0, 0.0, 0.0),      # each pair's knee height relative to KNEE_HEIGHT_CM. The back pair
                                                     # shares the ridge and rests 6 cm closer in (R01.1, 2026-10-30): its feet
                                                     # rest along the travel and were dragged to the full chain while walking;
                                                     # the longer chain and shorter rest give the gait slack (0.72 -> 0.65).
    "KNEE_FRACTION": 0.40,             # where along the horizontal hip->foot run the knee stands
    "ANKLE_FRACTION": 0.84,            # where along knee->foot the ankle sits
    "ANKLE_KINK_CM": 1.5,              # the ankle's offset off the knee->foot line, toward the pole side
    "CROUCH_DROP_CM": 10.0,            # low crouch: the body this much lower ...
    "CROUCH_SPREAD": 1.08,             # ... and the feet this much further out from the body centre
    "EYE_RAY_DIR": (1.0, 0.24, 0.42),  # from the cephalothorax centre to the brow: the eye socket is where this hits the shell
    "EYE_SOCKET_R_CM": 2.9, "EYE_R_CM": 1.8,
    "CHELICERA_ROOT_CM": (21.0, 4.0, -9.0),          # right chelicera root (body x, y, over BODY_REF_Z)
    "CHELICERA_RUN_CM": (5.5, 1.6, -8.5),            # root -> tip
    "TRIS_BUDGET_ASSEMBLED": 12000,
}
SEED = 7                                 # deterministic facet irregularity

# ---------------------------------------------------------------- small math
def _n(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-12)


def perp(v, axis):
    """v with its component along axis removed, normalised."""
    return _n(np.asarray(v, float) - np.dot(v, axis) * np.asarray(axis, float))


def frame_from_xy(x, y_hint):
    """Right-handed orthonormal (X, Y, Z) with X along x and Y the part of y_hint perpendicular to it."""
    x = _n(x)
    y = perp(y_hint, x)
    return x, y, np.cross(x, y)


def two_bone_knee(hip, foot, pole, upper, lower):
    d = foot - hip
    dl = float(np.linalg.norm(d))
    e = d / dl
    along = (upper ** 2 - lower ** 2 + dl ** 2) / (2.0 * dl)
    h = math.sqrt(max(0.0, upper ** 2 - along ** 2))
    return hip + e * along + perp(pole - hip, e) * h


def rl(v):
    return [round(float(x), 3) for x in v]


def rr(v):
    """Rotation columns keep full precision (the validator checks orthonormality to 1e-6)."""
    return [round(float(x), 10) for x in v]


# ---------------------------------------------------------------- bmesh primitives (Unreal cm, world or local frame)
def set_slot(bm, slot):
    i = SLOTS.index(slot)
    for f in bm.faces:
        f.material_index = i


def finish(bm, slot):
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    set_slot(bm, slot)
    return bm


def hull(points, slot):
    """The convex hull of the points: one closed, flat-faceted solid."""
    bm = bmesh.new()
    for p in points:
        bm.verts.new(tuple(float(x) for x in p))
    bmesh.ops.convex_hull(bm, input=bm.verts[:])
    # interior and unused points carry no face after the hull; drop them (and any dangling edge)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.delete(bm, geom=[e for e in bm.edges if not e.link_faces], context="EDGES")
    return finish(bm, slot)


def ring_points(centre, ey, ez, radius, angles_deg, mults):
    """Points around centre in the (ey, ez) plane; angles measured from ey toward ez."""
    out = []
    for a, m in zip(angles_deg, mults):
        t = math.radians(a)
        out.append(np.asarray(centre, float) + radius * m * (math.cos(t) * np.asarray(ey) + math.sin(t) * np.asarray(ez)))
    return out


def tube(rings, slot, cap_start=True, cap_end=True):
    """Rings of equal size joined by quads (a one-point last ring is a tip fan), capped: a closed solid."""
    bm = bmesh.new()
    vr = [[bm.verts.new(tuple(float(x) for x in p)) for p in r] for r in rings]
    for a, b in zip(vr[:-1], vr[1:]):
        n = len(a)
        if len(b) == 1:
            for i in range(n):
                bm.faces.new((a[i], a[(i + 1) % n], b[0]))
        else:
            for i in range(n):
                bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    if cap_start:
        bm.faces.new(vr[0])
    if cap_end and len(vr[-1]) > 1:
        bm.faces.new(vr[-1])
    return finish(bm, slot)


# cross sections: irregular hexagon, mirror-symmetric about the leg's plane (angle 0 = +Y of the segment frame)
HEX_ANGLES = (0.0, 55.0, 125.0, 180.0, 235.0, 305.0)
HEX_MULTS = (1.05, 0.95, 0.95, 1.05, 0.95, 0.95)
OCT_ANGLES = tuple(22.5 + 45.0 * i for i in range(8))
OCT_MULTS = (1.0,) * 8


def bar(stations, ey, ez, slot, tip=False):
    """A tapered faceted bar along stations [(centre, radius), ...]; tip=True ends in a point at the last station."""
    rings = []
    for i, (c, r) in enumerate(stations):
        if tip and i == len(stations) - 1:
            rings.append([np.asarray(c, float)])
        else:
            rings.append(ring_points(c, ey, ez, r, HEX_ANGLES, HEX_MULTS))
    return tube(rings, slot)


_PHI = (1.0 + 5.0 ** 0.5) / 2.0
_ICO = [v for s1 in (-1, 1) for s2 in (-1, 1) for v in ((0.0, s1 * 1.0, s2 * _PHI), (s1 * 1.0, s2 * _PHI, 0.0), (s1 * _PHI, 0.0, s2 * 1.0))]


def ball(centre, radius, ex, ey, ez, slot, jitter=0.10):
    """A 20-facet knuckle: an icosahedron with a deterministic radial irregularity that is even in every axis (so a part
    stays mirror-symmetric about its own plane)."""
    pts = []
    for v in _ICO:
        d = _n(v)
        m = 1.0 + jitter * math.sin(3.1 * abs(d[0]) + 5.3 * abs(d[1]) + 7.7 * abs(d[2]) + SEED)
        pts.append(np.asarray(centre, float) + radius * m * (d[0] * np.asarray(ex) + d[1] * np.asarray(ey) + d[2] * np.asarray(ez)))
    return hull(pts, slot)


def warm_underside(bm, threshold=-0.30):
    """Faces looking down become the warm underside material."""
    i = SLOTS.index("Underside")
    for f in bm.faces:
        if f.normal.z < threshold:
            f.material_index = i
    return bm


def join(bms):
    """One bmesh holding every input (material indices kept); the inputs are freed."""
    out = bmesh.new()
    for bm in bms:
        tmp = bpy.data.meshes.new("_join")
        bm.to_mesh(tmp)
        bm.free()
        out.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    return out


def tris_of(bm):
    return len(bm.faces)


# ---------------------------------------------------------------- body forms (world, neutral)
X, Y, Z = np.eye(3)


def body_x_layout():
    half = P["BODY_LENGTH_CM"] * 0.5
    nose = half
    ceph_back = nose - P["CEPHALOTHORAX_LENGTH_CM"]
    abd_front = ceph_back - P["PEDICEL_LENGTH_CM"]
    tail = -half
    return nose, ceph_back, abd_front, tail


def build_shell(ref_z):
    """The cephalothorax: a low wedge, nose narrow and sloping, widest behind the eyes; convex hull of ring stations."""
    nose, back, _, _ = body_x_layout()
    L = nose - back
    hw = P["CEPHALOTHORAX_HALF_WIDTH_CM"]
    top, bottom = P["SHELL_TOP_CM"], P["SHELL_BOTTOM_CM"]
    # (fraction of length from the back, half width, top, bottom, rim height) relative to ref_z
    stations = ((0.00, 0.60, 0.50, 0.65, 0.05), (0.18, 0.88, 0.85, 1.00, 0.10), (0.42, 1.00, 1.00, 1.00, 0.15),
                (0.66, 0.92, 0.85, 1.00, 0.20), (0.84, 0.62, 0.52, 0.80, 0.25), (0.95, 0.33, 0.22, 0.45, 0.30),
                (1.00, 0.12, 0.08, 0.20, 0.35))
    pts = []
    angles = (0.0, 28.0, 60.0, 90.0, 120.0, 152.0, 180.0)
    for frac, w, t, b, rim in stations:
        x = back + frac * L
        hwx, zt, zb = hw * w, ref_z + top * t, ref_z + bottom * b
        z_rim = zb + rim * (zt - zb)
        for k, a in enumerate(angles):
            ta = math.radians(a)
            facet = 1.0 + 0.05 * math.cos(2.0 * ta) * math.cos(1.7 * frac + SEED)
            pts.append((x, hwx * facet * math.cos(ta), z_rim + (zt - z_rim) * math.sin(ta)))
        for s in (-1.0, 1.0):
            pts.append((x, s * hwx * 0.82, zb))
    return warm_underside(hull(pts, "Ivory"), -0.25)


def build_sternum(ref_z):
    """The dark hip block under the shell: flat bottom, flanks carrying the eight sockets."""
    hips_x = P["HIP_X_CM"]
    x0, x1 = min(hips_x) - 3.5, max(hips_x) + 4.5
    hw = P["HIP_HALF_WIDTH_CM"]
    zb, zt = ref_z + P["STERNUM_BOTTOM_CM"], ref_z + P["SHELL_BOTTOM_CM"] + 1.5
    pts = []
    for frac in (0.0, 0.25, 0.5, 0.75, 1.0):
        x = x0 + frac * (x1 - x0)
        w = hw * (0.75 + 0.25 * math.sin(math.pi * frac))
        for s in (-1.0, 1.0):
            pts += [(x, s * w * 0.78, zb), (x, s * w * 1.02, 0.5 * (zb + zt)), (x, s * w * 0.9, zt)]
        pts.append((x, 0.0, zb - 0.6))
    return hull(pts, "Joint")


def build_pedicel(ref_z):
    _, back, abd_front, _ = body_x_layout()
    c0, c1 = np.array([back + 0.8, 0.0, ref_z + 1.0]), np.array([abd_front - 1.2, 0.0, ref_z + 1.0])
    return bar([(c0, 4.2), (c1, 4.0)], Y, Z, "Joint")


def build_abdomen(ref_z):
    """Small faceted pear: narrow neck at the pedicel, widest a third back, tapering to a blunt point."""
    _, _, front, tail = body_x_layout()
    L = front - tail
    hw, hh = P["ABDOMEN_HALF_WIDTH_CM"], P["ABDOMEN_HALF_HEIGHT_CM"]
    cz = ref_z + 1.0
    stations = ((0.0, 0.42), (0.17, 0.82), (0.36, 1.0), (0.58, 0.88), (0.80, 0.52), (0.95, 0.18))
    pts = []
    for i, (frac, s) in enumerate(stations):
        x = front - frac * L
        angles = OCT_ANGLES if i % 2 else tuple(45.0 * k for k in range(8))
        for a in angles:
            ta = math.radians(a)
            facet = 1.0 + 0.06 * math.cos(2.0 * ta) * math.sin(2.3 * frac + SEED)
            pts.append((x, hw * s * facet * math.cos(ta), cz + hh * s * facet * math.sin(ta)))
    pts.append((tail, 0.0, cz - 1.5))
    return warm_underside(hull(pts, "Ivory"), -0.25)


def eye_frames(ref_z, shell_bm):
    """(brow surface point, outward brow normal) of the right eye: a ray from the cephalothorax centre along EYE_RAY_DIR
    cast onto the actual shell; the left mirrors y."""
    from mathutils.bvhtree import BVHTree
    nose, back, _, _ = body_x_layout()
    origin = Vector((0.5 * (nose + back), 0.0, ref_z + 1.0))
    tree = BVHTree.FromBMesh(shell_bm)
    hit, normal, _, _ = tree.ray_cast(origin, Vector(_n(P["EYE_RAY_DIR"]).tolist()), 200.0)
    if hit is None:
        raise RuntimeError("the eye ray misses the shell")
    return np.array(hit[:]), _n(normal[:])


def ring_cup(centre, ex, ey, ez, r_out, r_in, depth, slot, sides=8):
    """A closed annular prism (the dark socket rim): outer and inner octagons, `depth` deep along ex from centre."""
    bm = bmesh.new()
    rings = []
    for along in (0.0, depth):
        c = np.asarray(centre, float) + ex * along
        rings.append(([bm.verts.new(tuple(x)) for x in ring_points(c, ey, ez, r_out, OCT_ANGLES, OCT_MULTS)],
                      [bm.verts.new(tuple(x)) for x in ring_points(c, ey, ez, r_in, OCT_ANGLES, OCT_MULTS)]))
    (o0, i0), (o1, i1) = rings
    n = sides
    for k in range(n):
        a, b = k, (k + 1) % n
        bm.faces.new((o0[a], o0[b], o1[b], o1[a]))      # outer wall
        bm.faces.new((i1[a], i1[b], i0[b], i0[a]))      # inner wall
        bm.faces.new((o1[a], o1[b], i1[b], i1[a]))      # front annulus
        bm.faces.new((i0[a], i0[b], o0[b], o0[a]))      # back annulus
    return finish(bm, slot)


def build_eyes(ref_z, shell_bm):
    """Dark socket rims sunk into the brow face, amber eyes recessed inside them (no aura, legible from the front)."""
    forms = []
    c, n = eye_frames(ref_z, shell_bm)
    rs, re = P["EYE_SOCKET_R_CM"], P["EYE_R_CM"]
    rim_front, rim_depth = 0.7, 2.2                  # the rim stands 0.7 cm proud of the brow and reaches 1.5 cm into it
    for s in (1.0, -1.0):
        m = np.array([1.0, s, 1.0])
        cc, nn = c * m, n * m
        ex, ey, ez = frame_from_xy(nn, Z)
        forms.append(("eye_socket_" + ("R" if s > 0 else "L"),
                      ring_cup(cc + nn * (rim_front - rim_depth), ex, ey, ez, rs, re + 0.25, rim_depth, "Joint")))
        # the eye: its front 0.3 cm behind the rim's face, so the amber sits recessed in a dark cup
        forms.append(("eye_" + ("R" if s > 0 else "L"), ball(cc + nn * (rim_front - 0.3 - re), re, ex, ey, ez, "Eye", 0.03)))
    return forms


def chelicera_points(ref_z, side):
    root = np.array(P["CHELICERA_ROOT_CM"], float) * np.array([1.0, side, 1.0]) + np.array([0.0, 0.0, ref_z])
    tip = root + np.array(P["CHELICERA_RUN_CM"], float) * np.array([1.0, side, 1.0])
    return root, tip


def chelicera_frame(root, tip):
    """+X root -> tip, +Z the front face (the part of world +X perpendicular to the shaft), +Y = Z x X."""
    x = _n(tip - root)
    z = perp(X, x)
    return x, np.cross(z, x), z


def build_chelicera(root, tip):
    x, y, z = chelicera_frame(root, tip)
    L = float(np.linalg.norm(tip - root))
    shaft = bar([(root, 2.3), (root + x * L * 0.40, 2.0), (root + x * L * 0.68, 1.5)], y, z, "Ivory")
    point = bar([(root + x * L * 0.66, 1.5), (tip, 0.0)], y, z, "Joint", tip=True)
    return [("chelicera_shaft", shaft), ("chelicera_tip", point)]


# ---------------------------------------------------------------- legs
def leg_targets():
    """Per pair: yaw (deg), horizontal reach (cm), knee height (cm) for a right leg in the neutral stance."""
    out = []
    for i, pair in enumerate(PAIRS):
        yaw = P["LEG_YAW_DEG"][i]
        reach = P["LEG_REACH_CM"][i]
        if reach is None:   # the pair that sets the stance width: outer foot tip at half the width
            reach = (P["STANCE_WIDTH_CM"] * 0.5 - P["HIP_HALF_WIDTH_CM"]) / math.sin(math.radians(yaw))
        out.append((pair, yaw, reach, P["KNEE_HEIGHT_CM"] + P["KNEE_Z_OFFSET_CM"][i]))
    return out


def leg_joints(ref_z, i, side):
    """hip, knee, ankle, foot, pole of leg i on side (+1 right, -1 left), world, neutral stance."""
    pair, yaw, reach, knee_z = leg_targets()[i]
    hip = np.array([P["HIP_X_CM"][i], side * P["HIP_HALF_WIDTH_CM"], ref_z - P["HIP_DROP_CM"]])
    d = np.array([math.cos(math.radians(yaw)), side * math.sin(math.radians(yaw)), 0.0])
    foot = hip + d * reach
    foot[2] = 0.0
    knee = hip + d * reach * P["KNEE_FRACTION"]
    knee[2] = knee_z
    pole = knee + (knee - 0.5 * (hip + foot))
    lx = _n(foot - knee)
    ankle = knee + (foot - knee) * P["ANKLE_FRACTION"] + perp(pole - knee, lx) * P["ANKLE_KINK_CM"]
    return {"pair": pair, "hip": hip, "knee": knee, "ankle": ankle, "foot": foot, "pole": pole}


def segment_frames(j):
    """(upper frame (X, Y, Z), upper pivot), (lower frame, lower pivot) from the joints."""
    ux = frame_from_xy(j["knee"] - j["hip"], j["pole"] - j["hip"])
    lx = frame_from_xy(j["foot"] - j["knee"], j["pole"] - j["knee"])
    return (ux, 0.5 * (j["hip"] + j["knee"])), (lx, 0.5 * (j["knee"] + j["foot"]))


def build_leg_forms(j):
    """The leg's forms as (name, bmesh in world cm, assembly) for one leg's joints."""
    (ux, uy, uz), _ = segment_frames(j)[0]
    (lx, ly, lz), _ = segment_frames(j)[1]
    hip, knee, ankle, foot = j["hip"], j["knee"], j["ankle"], j["foot"]
    tx = _n(foot - ankle)
    ty = perp(ly, tx)
    tz = np.cross(tx, ty)
    upper_len = float(np.linalg.norm(knee - hip))
    forms = [
        ("coxa_knuckle", ball(hip, 5.6, ux, uy, uz, "Joint"), "upper"),
        ("coxa", bar([(hip + ux * 3.0, 5.3), (hip + ux * 9.5, 4.9)], uy, uz, "Joint"), "upper"),
        ("femur", warm_underside(bar([(hip + ux * 9.0, 4.8), (hip + ux * (9.0 + 0.45 * (upper_len - 12.0)), 5.0),
                                      (knee - ux * 3.0, 3.9)], uy, uz, "Ivory"), -0.35), "upper"),
        ("knee_knuckle", ball(knee, 4.2, ux, uy, uz, "Joint"), "upper"),
        ("tibia", warm_underside(bar([(knee + lx * 2.5, 3.7), (knee + lx * (0.5 * float(np.linalg.norm(ankle - knee))), 3.3),
                                      (ankle - lx * 2.0, 2.6)], ly, lz, "Ivory"), -0.35), "lower"),
        ("ankle_collar", ball(ankle, 2.9, lx, ly, lz, "Joint", 0.06), "lower"),
        ("tarsus", bar([(ankle + tx * 1.2, 2.4), (foot - tx * 4.5, 1.3)], ty, tz, "Ivory"), "lower"),
        ("tarsus_tip", bar([(foot - tx * 4.7, 1.3), (foot, 0.0)], ty, tz, "Joint", tip=True), "lower"),
    ]
    return forms


def build_foot():
    """The claw tip cap, pointing -Z, built about the origin and then centred on its bounds."""
    bm = bar([(np.array([0.0, 0.0, 2.2]), 1.4), (np.array([0.0, 0.0, -2.2]), 0.0)], X, Y, "Joint", tip=True)
    return bm


# ---------------------------------------------------------------- frames and re-expression
def localize(bm, origin, axes):
    """Re-express bm (world cm) in the frame with the given origin and (X, Y, Z) axes."""
    rot = np.array(axes)       # rows: local axes in world -> world->local
    for v in bm.verts:
        p = rot @ (np.array(v.co[:]) - np.asarray(origin, float))
        v.co = Vector(p.tolist())
    bm.normal_update()
    return bm


def bounds(bm):
    co = np.array([v.co[:] for v in bm.verts])
    return co.min(axis=0), co.max(axis=0)


def centre_on_bounds(bm):
    lo, hi = bounds(bm)
    c = 0.5 * (lo + hi)
    for v in bm.verts:
        v.co = Vector((np.array(v.co[:]) - c).tolist())
    bm.normal_update()
    return c


# ---------------------------------------------------------------- Blender objects (the one place the frame changes)
UE_TO_BL = np.diag([0.01, -0.01, 0.01])


def ue_to_blender(p):
    return Vector((UE_TO_BL @ np.asarray(p, float)).tolist())


def ue_matrix(cols, loc):
    """A Blender world matrix for a piece Unreal places with local axes `cols` (X, Y, Z) at loc (cm)."""
    M = np.diag([1.0, -1.0, 1.0])
    r = M @ np.column_stack(cols) @ M
    t = M @ np.asarray(loc, float) * 0.01
    m = Matrix.Identity(4)
    for i in range(3):
        for k in range(3):
            m[i][k] = r[i, k]
        m[i][3] = t[i]
    return m


def ensure_materials():
    out = {}
    for name in SLOTS:
        mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        srgb, rough = MATERIALS[name]
        mat.use_nodes = True
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is not None:
            bsdf.inputs["Base Color"].default_value = (*srgb, 1.0)
            bsdf.inputs["Roughness"].default_value = rough
        mat.diffuse_color = (*srgb, 1.0)
        mat.roughness = rough
        out[name] = mat
    chef = bpy.data.materials.get("ChefGrey") or bpy.data.materials.new("ChefGrey")
    chef.diffuse_color = (*CHEF_GREY, 1.0)
    ground = bpy.data.materials.get("GroundGrey") or bpy.data.materials.new("GroundGrey")
    ground.diffuse_color = (0.30, 0.30, 0.31, 1.0)
    return out


def to_object(name, bm, collection, materials=None, slots=None):
    """A flat-shaded Blender mesh object from a bmesh in Unreal cm: (x, -y, z) * 0.01 with the winding reversed (the map
    is a mirror). `slots` lists the material names in slot order; default = every SLOTS entry the faces use."""
    used = sorted({f.material_index for f in bm.faces})
    slots = list(slots) if slots else [SLOTS[i] for i in used]
    remap = {SLOTS.index(s): k for k, s in enumerate(slots)}
    for f in bm.faces:
        f.material_index = remap[f.material_index]
    for v in bm.verts:
        v.co = ue_to_blender(v.co[:])
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.normal_update()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mats = materials or ensure_materials()
    for s in slots:
        mesh.materials.append(mats[s] if s in mats else bpy.data.materials[s])
    mesh.polygons.foreach_set("use_smooth", [False] * len(mesh.polygons))
    mesh.validate(verbose=False)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return obj


def collection(name):
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
    return coll


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.cameras, bpy.data.lights):
        for d in list(coll):
            if d.users == 0:
                coll.remove(d)


# ---------------------------------------------------------------- the model
class Model:
    """Everything derived from P: forms in world (neutral), render assemblies in their local frames, joints, poses."""

    def __init__(self):
        self.ref_z = P["BODY_REF_Z_CM"]
        self.forms = []            # (name, bmesh world cm, group) for the Source collection
        self.assemblies = {}       # mesh name -> {"bm": bmesh local cm, "role", "pair", "forms", "forms_tris", "joints_local"}
        self.legs = {}             # "R1".."L4" -> joints (world, neutral)
        self.build()

    # -- forms and assemblies
    def build(self):
        rz = self.ref_z
        shell = build_shell(rz)
        self.eye_centre, _ = eye_frames(rz, shell)
        body_forms = [("shell", shell), ("sternum", build_sternum(rz)), ("pedicel", build_pedicel(rz)),
                      ("abdomen", build_abdomen(rz))] + build_eyes(rz, shell)
        self.forms += [(n, bm, "body") for n, bm in body_forms]
        body_bm, body_tris = self._combine([bm for _, bm in body_forms])
        self.body_origin = centre_on_bounds(body_bm)
        self.assemblies[PREFIX + "Body" + SUFFIX] = {
            "bm": body_bm, "role": "body", "pair": None, "forms": [n for n, _ in body_forms],
            "forms_tris": dict(zip([n for n, _ in body_forms], body_tris)),
            "local_frame": "body bounds centre; +X forward, +Y right, +Z up (the body's own frame)", "joints_local": {}}

        for side, tag in ((1.0, "R"), (-1.0, "L")):
            for i in range(4):
                j = leg_joints(rz, i, side)
                lid = "%s%d" % (tag, i + 1)
                self.legs[lid] = j
                forms = build_leg_forms(j)
                self.forms += [("%s_%s" % (lid, n), bm, "leg_" + lid) for n, bm, _ in forms]
                if side > 0:
                    self._leg_assemblies(j, forms)

        foot = build_foot()
        centre_on_bounds(foot)
        self.assemblies[PREFIX + "Foot" + SUFFIX] = {
            "bm": foot, "role": "foot", "pair": None, "forms": ["claw_cap"], "forms_tris": {"claw_cap": tris_of(foot)},
            "local_frame": "claw tip cap pointing -Z, centred on its bounds; placed at the foot point", "joints_local": {}}
        self.forms.append(("foot_cap_reference", foot.copy(), "foot"))

        for side, tag in ((1.0, "R"), (-1.0, "L")):
            root, tip = chelicera_points(rz, side)
            forms = build_chelicera(root, tip)
            self.forms += [("%s_%s" % (n, tag), bm, "chelicera_" + tag) for n, bm in forms]
            if side > 0:
                bm, tris = self._combine([b for _, b in forms])
                axes = chelicera_frame(root, tip)
                localize(bm, root, axes)
                self.assemblies[PREFIX + "Chelicera" + SUFFIX] = {
                    "bm": bm, "role": "chelicera", "pair": None, "forms": [n for n, _ in forms],
                    "forms_tris": dict(zip([n for n, _ in forms], tris)),
                    "local_frame": "pivot at the root; +X root -> tip; +Z the front face",
                    "joints_local": {"root": rl([0.0, 0.0, 0.0]), "tip": rl(np.array(axes) @ (tip - root))}}

    def _combine(self, bms):
        """Copies of the forms joined into one bmesh (the sources stay for the Source collection), and their tri counts."""
        tris = [tris_of(b) for b in bms]
        return join([b.copy() for b in bms]), tris

    def _leg_assemblies(self, j, forms):
        (uaxes, upivot), (laxes, lpivot) = segment_frames(j)
        for role, axes, pivot, prox, dist in (("upper", uaxes, upivot, j["hip"], j["knee"]),
                                              ("lower", laxes, lpivot, j["knee"], j["foot"])):
            mine = [(n, bm) for n, bm, a in forms if a == role]
            bm, tris = self._combine([b for _, b in mine])
            localize(bm, pivot, axes)
            rot = np.array(axes)
            entry = {"bm": bm, "role": role, "pair": j["pair"], "forms": [n for n, _ in mine],
                     "forms_tris": dict(zip([n for n, _ in mine], tris)),
                     "local_frame": "pivot at the %s midpoint; +X %s; +Y toward the pole" % (
                         "hip-knee" if role == "upper" else "knee-foot", "hip -> knee" if role == "upper" else "knee -> foot tip"),
                     "joints_local": {"proximal": rl(rot @ (prox - pivot)), "distal": rl(rot @ (dist - pivot))}}
            if role == "lower":
                entry["joints_local"]["ankle"] = rl(rot @ (j["ankle"] - pivot))
            self.assemblies[PREFIX + "Leg%s%s" % ("Upper" if role == "upper" else "Lower", j["pair"]) + SUFFIX] = entry

    # -- poses
    def pose(self, name):
        """Instances and joints of a pose (world cm, ground z = 0)."""
        if name == "neutral":
            origin = self.body_origin.copy()
            legs = {lid: dict(j) for lid, j in self.legs.items()}
        elif name == "crouch":
            origin = self.body_origin - np.array([0.0, 0.0, P["CROUCH_DROP_CM"]])
            legs = {}
            for lid, j in self.legs.items():
                hip = j["hip"] - self.body_origin + origin
                pole = j["pole"] - self.body_origin + origin
                foot = j["foot"].copy()
                foot[:2] = origin[:2] + (foot[:2] - origin[:2]) * P["CROUCH_SPREAD"]
                upper = float(np.linalg.norm(j["knee"] - j["hip"]))
                lower = float(np.linalg.norm(j["foot"] - j["knee"]))
                if np.linalg.norm(foot - hip) > 0.98 * (upper + lower):
                    raise RuntimeError("crouch: %s cannot reach its foot" % lid)
                knee = two_bone_knee(hip, foot, pole, upper, lower)
                nj = {"pair": j["pair"], "hip": hip, "knee": knee, "foot": foot, "pole": pole}
                (_, _), (laxes, lpivot) = segment_frames(nj)
                lower_name = PREFIX + "LegLower" + j["pair"] + SUFFIX
                ankle_local = np.array(self.assemblies[lower_name]["joints_local"]["ankle"])
                nj["ankle"] = lpivot + np.array(laxes).T @ ankle_local
                legs[lid] = nj
        else:
            raise ValueError(name)

        instances = [{"mesh": PREFIX + "Body" + SUFFIX, "id": "Body", "location": rl(origin),
                      "rotation_cols": [rr(X), rr(Y), rr(Z)]}]
        leg_rows = []
        for lid in ("R1", "R2", "R3", "R4", "L1", "L2", "L3", "L4"):
            j = legs[lid]
            (uaxes, upivot), (laxes, lpivot) = segment_frames(j)
            instances.append({"mesh": PREFIX + "LegUpper" + j["pair"] + SUFFIX, "id": lid + ".Upper",
                              "location": rl(upivot), "rotation_cols": [rr(a) for a in uaxes]})
            instances.append({"mesh": PREFIX + "LegLower" + j["pair"] + SUFFIX, "id": lid + ".Lower",
                              "location": rl(lpivot), "rotation_cols": [rr(a) for a in laxes]})
            instances.append({"mesh": PREFIX + "Foot" + SUFFIX, "id": lid + ".Foot", "location": rl(j["foot"]),
                              "rotation_cols": [rr(X), rr(Y), rr(Z)]})
            leg_rows.append({"id": lid, "side": lid[0], "pair": j["pair"], "hip": rl(j["hip"]), "knee": rl(j["knee"]),
                             "ankle": rl(j["ankle"]), "foot": rl(j["foot"]), "pole": rl(j["pole"]),
                             "upper_length": round(float(np.linalg.norm(j["knee"] - j["hip"])), 3),
                             "lower_length": round(float(np.linalg.norm(j["foot"] - j["knee"])), 3),
                             "hip_body": rl(j["hip"] - origin), "knee_body": rl(j["knee"] - origin),
                             "ankle_body": rl(j["ankle"] - origin), "foot_body": rl(j["foot"] - origin),
                             "pole_body": rl(j["pole"] - origin)})
        chel = []
        for side, tag in ((1.0, "R"), (-1.0, "L")):
            root, tip = chelicera_points(self.ref_z, side)
            root = root - self.body_origin + origin
            tip = tip - self.body_origin + origin
            axes = chelicera_frame(root, tip)
            instances.append({"mesh": PREFIX + "Chelicera" + SUFFIX, "id": "Chelicera." + tag, "location": rl(root),
                              "rotation_cols": [rr(a) for a in axes]})
            chel.append({"id": tag, "root": rl(root), "tip": rl(tip), "root_body": rl(root - origin), "tip_body": rl(tip - origin)})
        return {"body_centre_height": round(float(origin[2]), 3), "body_origin": rl(origin), "instances": instances,
                "legs": leg_rows, "chelicerae": chel}

    def measurements(self):
        body = self.assemblies[PREFIX + "Body" + SUFFIX]["bm"]
        lo, hi = bounds(body)
        shell_top = max(v.co.z for n, bm, g in self.forms if n == "shell" for v in bm.verts)
        feet = np.array([j["foot"] for j in self.legs.values()])
        knees = np.array([j["knee"] for j in self.legs.values()])
        sternum_bottom = min(v.co.z for n, bm, g in self.forms if n == "sternum" for v in bm.verts)
        return {"body_length": round(float(hi[0] - lo[0]), 3), "body_width": round(float(hi[1] - lo[1]), 3),
                "body_height": round(float(hi[2] - lo[2]), 3),
                "body_bounds_min_local": rl(lo), "body_bounds_max_local": rl(hi),
                "body_centre_height": round(float(self.body_origin[2]), 3),
                "stance_width": round(float(feet[:, 1].max() - feet[:, 1].min()), 3),
                "stance_length": round(float(feet[:, 0].max() - feet[:, 0].min()), 3),
                "highest_knee": round(float(knees[:, 2].max()), 3), "lowest_knee": round(float(knees[:, 2].min()), 3),
                "head_top": round(float(shell_top), 3), "ground_clearance_sternum": round(float(sternum_bottom), 3),
                "cephalothorax_length": P["CEPHALOTHORAX_LENGTH_CM"], "pedicel_length": P["PEDICEL_LENGTH_CM"],
                "abdomen_length": round(P["BODY_LENGTH_CM"] - P["CEPHALOTHORAX_LENGTH_CM"] - P["PEDICEL_LENGTH_CM"], 3)}


# ---------------------------------------------------------------- checks on the authored geometry
def check_bmesh(name, bm):
    fails = []
    open_edges = sum(1 for e in bm.edges if len(e.link_faces) != 2)
    if open_edges:
        fails.append("%s: %d non-manifold edges" % (name, open_edges))
    loose = sum(1 for v in bm.verts if not v.link_faces)
    if loose:
        fails.append("%s: %d loose vertices" % (name, loose))
    tiny = sum(1 for f in bm.faces if f.calc_area() < 1e-4)
    if tiny:
        fails.append("%s: %d zero-area triangles" % (name, tiny))
    nontri = sum(1 for f in bm.faces if len(f.verts) != 3)
    if nontri:
        fails.append("%s: %d non-triangles" % (name, nontri))
    # every island must be closed and outward: a ray from far away hits an even number of faces per island (parity)
    return fails


def render_vertices(bm):
    """Unique (position, face normal) corners: what a flat-shaded GPU vertex buffer holds."""
    seen = set()
    for f in bm.faces:
        n = tuple(np.round(f.normal[:], 4))
        for v in f.verts:
            seen.add((tuple(np.round(v.co[:], 4)), n))
    return len(seen)


def tris_payload(bm):
    tris, normals, slots = [], [], []
    for f in bm.faces:
        tris.append([rl(v.co[:]) for v in f.verts])
        normals.append(rl(f.normal[:]))
        slots.append(int(f.material_index))
    return {"triangles": tris, "normals": normals, "slot_index": slots}


# ---------------------------------------------------------------- export
def export_assembly(obj, entry, payload, slots):
    os.makedirs(EXPORT_DIR, exist_ok=True)
    path = os.path.join(EXPORT_DIR, obj.name + ".fbx")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, mesh_smooth_type="FACE",
                             use_mesh_modifiers=False, add_leaf_bones=False, bake_anim=False, use_tspace=False,
                             apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y", use_triangles=True,
                             path_mode="STRIP", colors_type="NONE")
    with open(os.path.splitext(path)[0] + ".tris.json", "w") as fh:
        json.dump(payload, fh)
    side = {k: v for k, v in entry.items() if k != "bm"}
    side.update({"name": obj.name, "fbx": os.path.basename(path), "slots": slots, "ue_folder": UE_MESH_FOLDER,
                 "builder": "Tools/Blender/mars_monsters/pale_crawler_r01/build_pale_crawler.py"})
    with open(os.path.splitext(path)[0] + ".json", "w") as fh:
        json.dump(side, fh, indent=1)
    return path, side


# ---------------------------------------------------------------- review renders
def _look_at(cam, eye, target):
    f = np.array(target, float) - np.array(eye, float)
    cam.location = eye
    cam.rotation_euler = (math.atan2(math.hypot(f[0], f[1]), -f[2]), 0.0, -math.atan2(f[0], f[1]))


def render(objs, path, view_ue, target_ue, width_cm, size=(1400, 1000), ortho=True, distance_cm=None, shadow=True):
    """Workbench render of objs: the camera looks along -view_ue (an Unreal-frame direction) at target_ue (Unreal cm);
    ortho frames width_cm, perspective sits distance_cm away."""
    scene = bpy.context.scene
    hidden = [(o, o.hide_render) for o in scene.objects if o.type == "MESH"]
    cam_data = bpy.data.cameras.new("_ReviewCam")
    cam = bpy.data.objects.new("_ReviewCam", cam_data)
    scene.collection.objects.link(cam)
    sh = scene.display.shading
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y, scene.render.filepath)
    try:
        for o, _ in hidden:
            o.hide_render = o not in objs
        d = _n(np.array(view_ue, float))
        target = ue_to_blender(target_ue)
        if ortho:
            cam_data.type = "ORTHO"
            cam_data.ortho_scale = width_cm * 0.01
            eye = ue_to_blender(np.asarray(target_ue, float) + d * 1500.0)
        else:
            cam_data.type = "PERSP"
            cam_data.lens = 45.0
            eye = ue_to_blender(np.asarray(target_ue, float) + d * (distance_cm or 300.0))
        cam_data.clip_start, cam_data.clip_end = 0.01, 100.0
        _look_at(cam, eye, target)
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.render.film_transparent = False
        sh.light = "STUDIO"
        sh.color_type = "MATERIAL"
        sh.show_cavity = False
        sh.show_shadows = shadow
        sh.shadow_intensity = 0.35
        sh.background_type = "VIEWPORT"
        sh.background_color = (0.62, 0.61, 0.58)
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
    finally:
        for o, s in hidden:
            o.hide_render = s
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y, scene.render.filepath) = prev
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return path


def tile_images(paths, out_path, cols=2):
    imgs = [bpy.data.images.load(p) for p in paths]
    w, h = imgs[0].size
    rows = (len(imgs) + cols - 1) // cols
    sheet = np.zeros((rows * h, cols * w, 4), np.float32)
    for i, img in enumerate(imgs):
        px = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(px)
        r, c = divmod(i, cols)
        r = rows - 1 - r
        sheet[r * h:(r + 1) * h, c * w:(c + 1) * w] = px.reshape(h, w, 4)
        bpy.data.images.remove(img)
    out = bpy.data.images.new(os.path.basename(out_path), cols * w, rows * h, alpha=True)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    return out_path


def build_chef(coll, mats, location_ue):
    """A 140 cm faceless chef silhouette (legs, apron body, head, hat) for scale."""
    H = P["CHEF_HEIGHT_CM"]
    x, y, _ = location_ue
    parts = []
    for s in (-1.0, 1.0):
        parts.append(bar([(np.array([x, y + s * 8.0, 0.0]), 7.0), (np.array([x, y + s * 8.0, H * 0.42]), 7.5)], X, Y, "Joint"))
    parts.append(bar([(np.array([x, y, H * 0.40]), 17.0), (np.array([x, y, H * 0.62]), 20.0), (np.array([x, y, H * 0.78]), 17.0)], X, Y, "Joint"))
    parts.append(ball(np.array([x, y, H * 0.86]), 11.5, X, Y, Z, "Joint", 0.0))
    parts.append(bar([(np.array([x, y, H * 0.93]), 10.0), (np.array([x, y, H]), 11.0)], X, Y, "Joint"))
    bm = join(parts)
    for f in bm.faces:
        f.material_index = 0
    obj = to_object("Review_Chef_140cm", bm, coll, mats, slots=["Ivory"])
    obj.data.materials[0] = bpy.data.materials["ChefGrey"]
    return obj


def build_ground(coll):
    bm = bmesh.new()
    s = 300.0
    vs = [bm.verts.new(tuple(ue_to_blender((sx * s, sy * s, -0.05)))) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if bm.faces[0].normal.z < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Review_Ground")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(bpy.data.materials["GroundGrey"])
    obj = bpy.data.objects.new("Review_Ground", mesh)
    coll.objects.link(obj)
    return obj


def place_pose(model, pose, objs, coll, tag):
    """Instances of the export objects' mesh data at the pose's transforms (no negative scale anywhere)."""
    out = []
    for inst in pose["instances"]:
        src = objs[inst["mesh"]]
        o = bpy.data.objects.new("%s_%s" % (tag, inst["id"]), src.data)
        o.matrix_world = ue_matrix([np.array(c) for c in inst["rotation_cols"]], inst["location"])
        coll.objects.link(o)
        out.append(o)
    return out


def render_review(model, objs, neutral_objs, crouch_objs, chef, ground, poses):
    os.makedirs(REVIEW_DIR, exist_ok=True)
    out = {}
    scene_objs = neutral_objs + [chef, ground]
    c = np.array([0.0, 0.0, 30.0])
    full_w = 300.0
    views = {"front": ((1.0, 0.0, 0.05), c, full_w), "right_side": ((0.0, 1.0, 0.05), c, 260.0),
             "rear": ((-1.0, 0.0, 0.05), c, full_w), "top": ((0.0, 0.001, 1.0), (0.0, 0.0, 0.0), 260.0),
             "underside": ((0.0, 0.001, -1.0), (0.0, 0.0, 0.0), 260.0)}
    paths = []
    for k, (v, t, w) in views.items():
        objs_v = scene_objs if k in ("front", "right_side", "rear") else neutral_objs + [ground]
        if k == "underside":
            objs_v = neutral_objs
        paths.append(render(objs_v, os.path.join(REVIEW_DIR, "blender_neutral_%s.png" % k), v, t, w))
    out["neutral_sheet"] = tile_images(paths[:4], os.path.join(REVIEW_DIR, "blender_neutral_sheet.png"))
    out["underside"] = paths[4]
    out["three_quarter"] = render(scene_objs, os.path.join(REVIEW_DIR, "blender_neutral_three_quarter.png"), (1.0, 0.9, 0.55), c,
                                  0.0, size=(1600, 1100), ortho=False, distance_cm=420.0)
    eye_c = model.eye_centre
    face = np.array([eye_c[0] + 2.0, 0.0, eye_c[2] - 4.0])
    out["face"] = render(neutral_objs, os.path.join(REVIEW_DIR, "blender_neutral_face_closeup.png"), (1.0, 0.55, -0.1), face,
                         0.0, size=(1400, 1000), ortho=False, distance_cm=85.0)
    knee = np.array(poses["neutral"]["legs"][2]["knee"])
    out["knee"] = render(neutral_objs, os.path.join(REVIEW_DIR, "blender_neutral_knee_closeup.png"), (0.9, 0.5, 0.35), knee,
                         0.0, size=(1400, 1000), ortho=False, distance_cm=70.0)
    ankle = np.array(poses["neutral"]["legs"][2]["ankle"])
    out["ankle"] = render(neutral_objs, os.path.join(REVIEW_DIR, "blender_neutral_ankle_closeup.png"), (0.9, 0.5, 0.25), ankle,
                          0.0, size=(1400, 1000), ortho=False, distance_cm=60.0)
    # crouch
    cc = np.array([0.0, 0.0, 22.0])
    cpaths = [render(crouch_objs + [ground], os.path.join(REVIEW_DIR, "blender_crouch_front.png"), (1.0, 0.0, 0.05), cc, full_w),
              render(crouch_objs + [ground], os.path.join(REVIEW_DIR, "blender_crouch_three_quarter.png"), (1.0, 0.9, 0.5), cc, 0.0,
                     size=(1400, 1000), ortho=False, distance_cm=400.0)]
    ck = np.array(poses["crouch"]["legs"][2]["knee"])
    ch = np.array(poses["crouch"]["legs"][2]["hip"])
    cpaths.append(render(crouch_objs, os.path.join(REVIEW_DIR, "blender_crouch_knee_closeup.png"), (0.9, 0.5, 0.35), ck, 0.0,
                         size=(1400, 1000), ortho=False, distance_cm=70.0))
    cpaths.append(render(crouch_objs, os.path.join(REVIEW_DIR, "blender_crouch_hip_closeup.png"), (0.8, 0.9, -0.2), ch, 0.0,
                         size=(1400, 1000), ortho=False, distance_cm=70.0))
    out["crouch_sheet"] = tile_images(cpaths, os.path.join(REVIEW_DIR, "blender_crouch_sheet.png"))
    # every export piece on its own, in its local frame
    piece_paths = []
    for name, o in objs.items():
        lo, hi = bounds_obj_cm(o)
        w = float((hi - lo).max()) * 1.4
        piece_paths.append(render([o], os.path.join(REVIEW_DIR, "piece_%s.png" % name.replace(PREFIX, "").replace(SUFFIX, "")),
                                  (1.0, 0.9, 0.6), 0.5 * (lo + hi), w, size=(700, 600)))
    out["pieces_sheet"] = tile_images(piece_paths, os.path.join(REVIEW_DIR, "blender_pieces_sheet.png"), cols=4)
    return out


def bounds_obj_cm(obj):
    n = len(obj.data.vertices)
    co = np.empty(n * 3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(n, 3) @ np.diag([100.0, -100.0, 100.0])
    return co.min(axis=0), co.max(axis=0)


# ---------------------------------------------------------------- main
def cli_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return {"save": "--no-save" not in argv, "sheets": "--no-sheets" not in argv, "export": "--no-export" not in argv}


def main():
    args = cli_args()
    clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    fails = []
    mats = ensure_materials()
    model = Model()
    poses = {name: model.pose(name) for name in ("neutral", "crouch")}
    meas = model.measurements()

    # the neutral pose must reproduce the authored knees through the IK the consumer uses
    for lid, j in model.legs.items():
        upper = float(np.linalg.norm(j["knee"] - j["hip"]))
        lower = float(np.linalg.norm(j["foot"] - j["knee"]))
        k = two_bone_knee(j["hip"], j["foot"], j["pole"], upper, lower)
        if np.linalg.norm(k - j["knee"]) > 1e-6:
            fails.append("%s: IK knee %s != authored %s" % (lid, np.round(k, 3), np.round(j["knee"], 3)))

    src_coll, exp_coll, rev_coll = collection("Source"), collection("Export"), collection("Review")
    for name, bm, group in model.forms:
        to_object("Src_%s" % name, bm, src_coll, mats)

    objs, sidecars, payloads = {}, {}, {}
    for name, entry in model.assemblies.items():
        bm = entry["bm"]
        fails += check_bmesh(name, bm)
        used = sorted({f.material_index for f in bm.faces})
        slots = [SLOTS[i] for i in used]
        lo, hi = bounds(bm)
        entry.update({"tris": tris_of(bm), "render_vertices": render_vertices(bm), "bounds_min": rl(lo), "bounds_max": rl(hi)})
        payloads[name] = tris_payload(bm)
        payloads[name]["slot_index"] = [used.index(i) for i in payloads[name]["slot_index"]]
        entry["slots"] = slots
        objs[name] = to_object(name, bm, exp_coll, mats, slots)
        entry.pop("bm")
        print("%-40s tris %5d  verts %5d  bounds %s .. %s  slots %s" % (name, entry["tris"], entry["render_vertices"],
                                                                      np.round(lo, 1), np.round(hi, 1), slots))

    ground = build_ground(rev_coll)
    chef_loc = (0.0, -(P["STANCE_WIDTH_CM"] * 0.5 + 40.0), 0.0)
    chef = build_chef(rev_coll, mats, chef_loc)
    neutral_objs = place_pose(model, poses["neutral"], objs, rev_coll, "Pose_Neutral")
    crouch_coll = collection("Review_Crouch")
    crouch_objs = place_pose(model, poses["crouch"], objs, crouch_coll, "Pose_Crouch")
    for o in crouch_objs:
        o.hide_viewport = True

    unique = sum(e["tris"] for e in model.assemblies.values())
    assembled = sum(model.assemblies[i["mesh"]]["tris"] for i in poses["neutral"]["instances"])
    if assembled > P["TRIS_BUDGET_ASSEMBLED"]:
        fails.append("assembled %d tris > budget %d" % (assembled, P["TRIS_BUDGET_ASSEMBLED"]))
    if abs(meas["body_length"] - P["BODY_LENGTH_CM"]) > 0.5:
        fails.append("body length %.2f != %.2f" % (meas["body_length"], P["BODY_LENGTH_CM"]))
    if abs(meas["stance_width"] - P["STANCE_WIDTH_CM"]) > 0.5:
        fails.append("stance width %.2f != %.2f" % (meas["stance_width"], P["STANCE_WIDTH_CM"]))
    if abs(meas["highest_knee"] - P["KNEE_HEIGHT_CM"]) > 0.5:
        fails.append("highest knee %.2f != %.2f" % (meas["highest_knee"], P["KNEE_HEIGHT_CM"]))
    if meas["head_top"] >= meas["highest_knee"]:
        fails.append("head top %.1f is not below the knee ridge %.1f" % (meas["head_top"], meas["highest_knee"]))
    legs_total = sum(1 for i in poses["neutral"]["instances"] if i["id"].endswith(".Upper"))
    if legs_total != 8:
        fails.append("%d legs" % legs_total)

    manifest = {"version": 1, "units": "cm",
                "frame": "Unreal +X forward, +Y right, +Z up; body origin = Body bounds centre; pose ground z = 0",
                "builder": "Tools/Blender/mars_monsters/pale_crawler_r01/build_pale_crawler.py", "blend": BLEND_FILE.replace("\\", "/"),
                "parameters": {k: (list(v) if isinstance(v, tuple) else v) for k, v in P.items()},
                "measurements": meas,
                "materials": {"slots": list(SLOTS), "srgb": {k: list(v[0]) for k, v in MATERIALS.items()},
                              "roughness": {k: v[1] for k, v in MATERIALS.items()}},
                "meshes": {}, "totals": {"unique_tris": unique, "assembled_tris": assembled,
                                         "assembled_instances": len(poses["neutral"]["instances"]),
                                         "anatomical_forms_source": len(model.forms)},
                "chef_marker": {"height": P["CHEF_HEIGHT_CM"], "location": list(chef_loc)},
                "runtime_mapping": {"Upper": "coxa + femur + knee knuckle (hip -> knee)",
                                    "Lower": "tibia + ankle collar + tarsus (knee -> foot tip)",
                                    "Foot": "claw tip cap at the foot point", "note":
                                    "coxa and tarsus are render geometry inside the two chain segments; they are not independently articulated"},
                "poses": poses}
    print("MEASUREMENTS " + json.dumps(meas))
    print("TOTALS " + json.dumps(manifest["totals"]))

    if args["export"]:
        os.makedirs(EXPORT_DIR, exist_ok=True)
        for name, entry in model.assemblies.items():
            path, side = export_assembly(objs[name], entry, payloads[name], entry["slots"])
            manifest["meshes"][name] = side
            print("exported", os.path.basename(path))
        with open(os.path.join(EXPORT_DIR, "PaleCrawler_R01_Assembly.json"), "w") as fh:
            json.dump(manifest, fh, indent=1)
    else:
        for name, entry in model.assemblies.items():
            manifest["meshes"][name] = {k: v for k, v in entry.items()}
    with open(os.path.join(REVIEW_DIR if os.path.isdir(REVIEW_DIR) else EXPORT_DIR, "measurements.json"), "w") as fh:
        json.dump({"measurements": meas, "totals": manifest["totals"], "parameters": manifest["parameters"]}, fh, indent=1)

    if args["sheets"]:
        sheets = render_review(model, objs, neutral_objs, crouch_objs, chef, ground, poses)
        print("sheets:", *sheets.values(), sep="\n  ")

    if args["save"]:
        os.makedirs(os.path.dirname(BLEND_FILE), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=BLEND_FILE, copy=False)
        print("saved", BLEND_FILE)

    if fails:
        print("PALE_CRAWLER_FAIL", *fails, sep="\n  ")
    else:
        print("PALE_CRAWLER_OK")


if __name__ == "__main__":
    main()
