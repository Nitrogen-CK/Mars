"""Mars cooking STATION "fryer" (station_spec.STATIONS["fryer"]): the deep-fryer vat, the swing-arm post + arm, the
wire basket and the round skimmer, as a re-runnable headless Blender 5.2 build.

Builds from fixed seeds (the scene is rebuilt from nothing every run):
  FryerVat_Mars_SM       Stone/Iron/Ember  stone-ring vat: plinth with ember slots, 3 courses of chipped basalt blocks,
                                           iron hoop band, smooth-faceted liner + cavity floor, skimmer notch on the
                                           near-left rim. Pivot = floor contact centre.
  FryerArmPost_Mars_SM   Iron              post standing on SOCKET_ArmPost (pivot at its foot), fork bracket + pin.
  FryerArm_Mars_SM       Iron/Wood         the swinging arm, pivot = the bracket pin, arm along local -X; rotating it
                                           about local Y lifts / lowers the basket hung from SOCKET_Hang.
  FryerBasket_Mars_SM    Wire/Iron         rectangular wire basket, long axis local X, pivot = centre of the inner
                                           floor, bail over the top (SOCKET_Bail meets the arm's SOCKET_Hang).
  FryerSkimmer_Mars_SM   Wire/Iron/Wood    spherical-cap wire bowl + iron rim, shaft along +X with a wooden grip,
                                           pivot = the lowest point of the bowl's inner surface.
plus FryerStation_Layout.json: every prop in the station frame (operator at -X), arm / basket lowered + raised, the
skimmer rest pose and the OilSurface disc transform.

Run:
  blender -b --factory-startup --python build_station_fryer.py -- [--export] [--save] [--sheets]
    --export   FBX + JSON sidecar per prop and the layout JSON into station_spec.EXPORT_DIR, then a re-import check
    --sheets   review sheets (one per prop + assembled lowered / raised shots) into station_spec.REVIEW_DIR
    --save     station_spec.BLEND_DIR/Station_Fryer.blend (props at their pivots + a linked layout collection)
Prints STATION_FRYER_OK when every check passed (STATION_FRYER_FAIL + the reasons otherwise).

All builder geometry is in CENTIMETRES, Blender axes (Z up). Sidecars / layout carry Unreal local cm (Y mirrored).
"""
import json
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import station_common as sc  # noqa: E402

fc = sc.fc
spec = sc.spec
PROPS = spec.PROPS
VAT = PROPS["FryerVat"]
ARM = PROPS["FryerArm"]
BASKET = PROPS["FryerBasket"]
SKIM = PROPS["FryerSkimmer"]

# ---------------------------------------------------------------- vat dimensions (spec)
R_IN = VAT["inner_radius_cm"]            # 48
R_OUT = VAT["outer_radius_cm"]           # 62
RIM_TOP = VAT["rim_top_cm"]              # 76
CAVITY_FLOOR = VAT["cavity_floor_cm"]    # 40
OIL_LEVEL = VAT["oil_level_cm"]          # 66
SOCK_OIL = np.array(VAT["sockets"]["Oil"], float)
SOCK_POST = np.array(VAT["sockets"]["ArmPost"], float)
SOCK_SKIM = np.array(VAT["sockets"]["SkimmerRest"], float)

PLINTH_TOP = 17.0
PLINTH_R_IN, PLINTH_R_OUT = 50.0, 64.0
COURSES = ((PLINTH_TOP, 39.0, 16, 0.5), (39.0, 61.0, 16, 0.0), (61.0, RIM_TOP, 24, 0.0))  # z0, z1, blocks, phase
LINER_R = 49.2            # liner inner wall: behind the block inner faces, seen only through the seams
LINER_R2 = 50.6
LINER_TOP = 75.0
EMBER_R = 60.0
HOOP_Z, HOOP_R, HOOP_TUBE = 69.0, 62.5, 1.4
SEAM = 0.8                # constant seam width between neighbouring blocks (cm)

# ---------------------------------------------------------------- post / arm
POST_PIN_Z = 27.0                         # pin height above the post foot
HINGE = SOCK_POST + np.array([0.0, 0.0, POST_PIN_Z])          # station frame, (54, 0, 103)
HUB_HALF_W = 1.5
CHEEK_IN, CHEEK_T = 1.7, 1.2

# ---------------------------------------------------------------- basket
B_IN = np.array(BASKET["inner_cm"], float)                    # 44 x 26 x 16 (long axis local X)
B_W, B_F = 0.35, 0.8                                           # wire / frame rod radius
B_PITCH = BASKET["wire_pitch_cm"]
BAIL_TOP = 26.0                                                # bail wire centre above the inner floor
BASKET_LOW_FLOOR = 53.0                                        # lowered inner floor height in the station frame

# ---------------------------------------------------------------- skimmer (spherical cap measured on the inner surface)
S_A = SKIM["bowl_inner_radius_cm"]        # 10 rim radius
S_H = SKIM["bowl_depth_cm"]               # 7 depth
S_R = (S_A ** 2 + S_H ** 2) / (2.0 * S_H)  # cap sphere radius of the inner surface (10.643)
S_C = np.array([0.0, 0.0, S_R])           # sphere centre (inner floor centre = origin)
S_PHI_RIM = math.asin(S_A / S_R)
S_W = 0.35                                # wire radius
S_RIM_TUBE = 0.8
S_RIM_SPH = S_R + S_RIM_TUBE              # rim ring centre lies on this sphere at S_PHI_RIM
S_RIM_RHO = S_RIM_SPH * math.sin(S_PHI_RIM)
S_RIM_Z = S_R - S_RIM_SPH * math.cos(S_PHI_RIM)
S_RAKE = math.radians(12.0)
S_D = np.array([math.cos(S_RAKE), 0.0, math.sin(S_RAKE)])     # shaft direction (local)
S_J = np.array([S_RIM_RHO + 4.0, 0.0, S_RIM_Z + 0.6])          # fork junction / shaft start
S_HANDLE = SKIM["handle_length_cm"]       # 48 = rim -> J (4) + J -> end (44)
S_SHAFT_LEN = S_HANDLE - 4.0
S_IRON_LEN = 26.0
S_SHAFT_R = 0.75
S_GRIP_R = 1.4
S_REST_ELEV = math.radians(8.0)           # world elevation of the shaft in the rest pose
S_REST_BOWL_RADIUS = 34.0                 # bowl centre distance from the vat axis in the rest pose

COL_CHIP = fc.srgb(84, 62, 50)


def P(name):
    return sc.palette(name)


def lerp(a, b, t):
    return np.asarray(a, float) * (1.0 - t) + np.asarray(b, float) * t


def ue(p):
    """Blender-axes cm -> Unreal local cm list."""
    p = np.asarray(p, float)
    return [round(float(p[0]), 3), round(float(-p[1]), 3), round(float(p[2]), 3)]


def rot_z(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0.0], [math.sin(a), math.cos(a), 0.0], [0.0, 0.0, 1.0]])


def rot_y(rad):
    c, s = math.cos(rad), math.sin(rad)
    return np.array([[c, 0.0, s], [0.0, 1.0, 0.0], [-s, 0.0, c]])


# ================================================================ geometry helpers (cm)
class Parts:
    """Accumulates (verts, faces, slot, per-face rgb) parts and builds one flat-shaded object."""

    def __init__(self, slots):
        self.slots = tuple(slots)
        self.items = []

    def add(self, vf, slot, rgb):
        v, f = vf
        rgb = np.asarray(rgb, float)
        if rgb.ndim == 1:
            rgb = np.repeat(rgb[None, :], len(f), axis=0)
        assert len(rgb) == len(f)
        self.items.append((np.asarray(v, float), [list(map(int, x)) for x in f], self.slots.index(slot), rgb))

    def build(self, name):
        verts, faces, fslots, cols = [], [], [], []
        base = 0
        for v, f, s, c in self.items:
            verts.append(v)
            faces.extend([[base + i for i in face] for face in f])
            fslots.extend([s] * len(f))
            cols.append(c)
            base += len(v)
        obj = sc.new_object(name, np.concatenate(verts), faces, slots=self.slots, face_slots=fslots)
        if len(obj.data.polygons) != len(faces):
            raise RuntimeError("%s: mesh.validate dropped faces (%d -> %d)" % (name, len(faces), len(obj.data.polygons)))
        return obj, np.concatenate(cols)


def hull(points, dissolve_deg=1.0):
    """Convex hull (bmesh) of cm points -> (verts, faces) with near-coplanar triangles merged into facets."""
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
        pts = v[face]
        n = newell(pts)
        if np.dot(n, pts.mean(axis=0) - centre) < 0:
            face = face[::-1]
        out.append(face)
    return v, out


def newell(pts):
    n = np.zeros(3)
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n += np.array([(a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]), (a[0] - b[0]) * (a[1] + b[1])])
    ln = np.linalg.norm(n)
    return n / ln if ln > 1e-12 else n


def face_normals(v, faces):
    return np.array([newell(np.asarray(v)[f]) for f in faces])


def tube(points, radius, sides=4, caps=False, phase=0.0, radii=None):
    """A faceted tube along a polyline (parallel-transported frames). caps=False for ends buried in other parts."""
    pts = np.asarray(points, float)
    n = len(pts)
    tang = []
    for i in range(n):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == n - 1:
            t = pts[-1] - pts[-2]
        else:
            a, b = pts[i] - pts[i - 1], pts[i + 1] - pts[i]
            t = a / np.linalg.norm(a) + b / np.linalg.norm(b)
        tang.append(t / np.linalg.norm(t))
    helper = np.array([0.0, 0.0, 1.0]) if abs(tang[0][2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = np.cross(tang[0], helper)
    u /= np.linalg.norm(u)
    rings = []
    for i, t in enumerate(tang):
        u = u - np.dot(u, t) * t
        u /= np.linalg.norm(u)
        w = np.cross(t, u)
        r = radius if radii is None else radii[i]
        rings.append(fc.ring(pts[i], r, r, sides, u, w, phase))
    return fc.loft(rings, close_start=caps, close_end=caps)


def prism(section_a, section_b):
    """Loft two corresponding planar polygons (k, 3) into a closed prism (caps are ngons)."""
    a, b = np.asarray(section_a, float), np.asarray(section_b, float)
    k = len(a)
    v = np.concatenate([a, b])
    f = [[i, (i + 1) % k, k + (i + 1) % k, k + i] for i in range(k)]
    f.append(list(range(k - 1, -1, -1)))
    f.append(list(range(k, 2 * k)))
    return v, f


def polar(r, a, z):
    return np.array([r * math.cos(a), r * math.sin(a), z])


# ================================================================ skimmer rest pose (needed by the vat's notch)
def skimmer_rest():
    """Rest pose of the skimmer in the vat frame: the shaft lies radially in the notch at SOCKET_SkimmerRest (its
    centre line passes through the socket), rising outward at S_REST_ELEV, bowl inside the vat over the oil."""
    yaw = math.degrees(math.atan2(SOCK_SKIM[1], SOCK_SKIM[0]))        # outward through the notch (135 deg)
    beta = S_RAKE - S_REST_ELEV                                        # about local Y: shaft rake -> world elevation
    rot = rot_z(yaw) @ rot_y(beta)
    notch_r = math.hypot(SOCK_SKIM[0], SOCK_SKIM[1])
    jx = (rot_y(beta) @ S_J)[0]
    s_star = (notch_r - S_REST_BOWL_RADIUS - jx) / math.cos(S_REST_ELEV)
    contact_local = S_J + s_star * S_D
    loc = SOCK_SKIM - rot @ contact_local
    return dict(yaw_deg=yaw, beta=beta, rot=rot, loc=loc, s_star=s_star, contact_local=contact_local,
                elev=S_REST_ELEV, notch_r=notch_r)


def shaft_centre_z_at_radius(rest, r):
    """Height of the resting shaft's centre line where it crosses vat radius r (radial plane of the notch)."""
    return SOCK_SKIM[2] + (r - rest["notch_r"]) * math.tan(rest["elev"])


# ================================================================ FryerVat
def stone_block(rng, a0, a1, r_in, r_out, z0, z1, chips=(2, 5), keep_top=False, jitter=0.2, wobble_deg=1.4,
                ground=False, chamfer=0.45):
    """A chiselled basalt block between two radial seam planes: corners chipped off (extra facets), sometimes a
    chiselled chamfer along the top outer edge, tiny vertex jitter, outward protrusion and yaw wobble. keep_top
    leaves the top face exactly at z1 (post foot / notch / spec rim height)."""
    r_out = r_out + rng.uniform(-0.5, 1.3)
    di, do = 0.5 * SEAM / r_in, 0.5 * SEAM / r_out
    corners = np.array([polar(r_in, a0 + di, z0), polar(r_out, a0 + do, z0), polar(r_out, a1 - do, z0),
                        polar(r_in, a1 - di, z0), polar(r_in, a0 + di, z1), polar(r_out, a0 + do, z1),
                        polar(r_out, a1 - do, z1), polar(r_in, a1 - di, z1)])
    nb = {0: (1, 3, 4), 1: (0, 2, 5), 2: (1, 3, 6), 3: (2, 0, 7), 4: (5, 7, 0), 5: (4, 6, 1), 6: (5, 7, 2), 7: (6, 4, 3)}
    bevel = (not keep_top) and rng.uniform() < chamfer
    cand = [0, 1, 2, 3] if keep_top else list(range(8))
    if ground:
        cand = [c for c in cand if c >= 4]
    if bevel:
        cand = [c for c in cand if c not in (5, 6)]
    n_chip = int(rng.integers(chips[0], chips[1] + 1))
    chipped = set(rng.choice(cand, size=min(n_chip, len(cand)), replace=False).tolist()) if cand else set()
    pts = []
    bev = rng.uniform(1.6, 3.2)
    for i in range(8):
        if bevel and i in (5, 6):                      # chamfer: the outer top edge cut back at ~45 deg
            down = corners[i] + np.array([0.0, 0.0, -bev * rng.uniform(0.8, 1.2)])
            radial = corners[i] - np.array([corners[i][0], corners[i][1], 0.0]) * (bev / np.hypot(*corners[i][:2]))
            pts.extend([down, radial])
            continue
        if i in chipped:
            depth = rng.uniform(1.4, 3.6)
            for j in nb[i]:
                d = corners[j] - corners[i]
                pts.append(corners[i] + d / np.linalg.norm(d) * depth * rng.uniform(0.7, 1.3))
        else:
            pts.append(corners[i].copy())
    pts = np.array(pts)
    jit = rng.uniform(-jitter, jitter, pts.shape)
    top = np.abs(pts[:, 2] - z1) < 1e-6
    bot = np.abs(pts[:, 2] - z0) < 1e-6
    if keep_top:
        jit[top, 2] = 0.0
    if ground:
        jit[bot, 2] = 0.0
    pts += jit
    c = np.array([0.5 * (r_in + r_out) * math.cos(0.5 * (a0 + a1)), 0.5 * (r_in + r_out) * math.sin(0.5 * (a0 + a1)), 0.0])
    w = rng.uniform(-wobble_deg, wobble_deg)
    pts = (pts - c) @ rot_z(w).T + c
    return hull(pts)


def block_colours(v, f, a_mid, rng, top_lift=0.35):
    """Per-face colour of a block: chiselled outer / top faces toward StoneLight, seams dark, chips warm."""
    e_r = np.array([math.cos(a_mid), math.sin(a_mid), 0.0])
    e_t = np.array([-math.sin(a_mid), math.cos(a_mid), 0.0])
    shade = rng.uniform(0.05, 0.55)
    stone, light = P("Stone"), P("StoneLight")
    out = []
    for n in face_normals(v, f):
        nr, nt, nz = float(n @ e_r), float(n @ e_t), float(n[2])
        if nz > 0.93:
            c = lerp(stone, light, min(shade + top_lift, 0.95))
        elif nz < -0.93:
            c = stone * 0.6
        elif nz > 0.4 and nr > 0.4:
            c = lerp(stone, light, min(shade + 0.55, 1.0)) * rng.uniform(0.95, 1.1)    # chiselled chamfer
        elif nr > 0.93:
            c = lerp(stone, light, shade)
        elif nr < -0.93:
            c = lerp(stone, light, shade * 0.5) * 0.9
        elif abs(nt) > 0.85:
            c = stone * 0.7
        else:
            c = COL_CHIP * rng.uniform(0.85, 1.15)
        out.append(c)
    return np.array(out)


def notch_block(rng, a_mid, half_angle, r_in, r_out, z0, z1, rest):
    """The top-course block under the skimmer: a radial V groove (45 deg walls) whose bottom follows the resting
    shaft, so the shaft's centre line passes through SOCKET_SkimmerRest. One closed non-convex prism."""
    e_r = np.array([math.cos(a_mid), math.sin(a_mid), 0.0])
    e_t = np.array([-math.sin(a_mid), math.cos(a_mid), 0.0])
    secs = []
    for r in (r_in, r_out):
        t_side = r * math.tan(half_angle) - 0.5 * SEAM
        zc = shaft_centre_z_at_radius(rest, r)
        b = min(zc - S_SHAFT_R * math.sqrt(2.0), z1 - 0.25)
        g = z1 - b
        sec = [(-t_side, z0), (t_side, z0), (t_side, z1), (g, z1), (0.0, b), (-g, z1), (-t_side, z1)]
        secs.append(np.array([r * e_r + t * e_t + np.array([0.0, 0.0, z]) for t, z in sec]))
    v, f = prism(secs[0], secs[1])
    v = v + np.where(np.abs(v[:, 2:3] - z0) < 1e-6, rng.uniform(-0.15, 0.15, v.shape) * np.array([1, 1, 0]), 0.0)
    stone, light = P("Stone"), P("StoneLight")
    cols = []
    for n in face_normals(v, f):
        nr, nz = float(n @ e_r), float(n[2])
        if nz > 0.93:
            cols.append(lerp(stone, light, 0.62))
        elif nz > 0.4:
            cols.append(lerp(COL_CHIP, light, 0.35))          # worn groove walls
        elif nz < -0.93:
            cols.append(stone * 0.6)
        elif abs(nr) > 0.93:
            cols.append(lerp(stone, light, 0.3))
        else:
            cols.append(stone * 0.7)
    return (v, f), np.array(cols)


def build_vat(rest):
    rng = np.random.default_rng(61021)
    parts = Parts(("Stone", "Iron", "Ember"))
    stone = P("Stone")

    # liner first: smooth-faceted cavity wall + floor, a solid of revolution down to the base so no seam shows through
    seg = 48
    prof = [(0.0, CAVITY_FLOOR), (28.0, CAVITY_FLOOR), (LINER_R, CAVITY_FLOOR), (LINER_R, LINER_TOP),
            (LINER_R2, LINER_TOP), (LINER_R2, 0.6), (0.0, 0.6)]
    lv, lf = fc.lathe(prof, seg)
    # dip the liner top under the skimmer notch (the groove cuts below LINER_TOP there)
    notch_a = math.atan2(SOCK_SKIM[1], SOCK_SKIM[0])
    k_notch = int(round((notch_a % math.tau) / math.tau * seg)) % seg
    shaft_bottom = min(shaft_centre_z_at_radius(rest, r) for r in (LINER_R, LINER_R2)) - S_SHAFT_R
    dip_z = shaft_bottom - 1.6
    for ring_start in (1 + 2 * seg, 1 + 3 * seg):            # rings: pole, r28, wall-bottom, wall-top, lip, base, pole
        lv[ring_start + k_notch, 2] = dip_z
    lcols = []
    for n, face in zip(face_normals(lv, lf), lf):
        zc = lv[face, 2].mean()
        if n[2] > 0.9 and zc < CAVITY_FLOOR + 0.1:
            lcols.append(stone * 0.42)                       # sooted cavity floor
        else:
            lcols.append(stone * 0.62)
    parts.add((lv, lf), "Stone", np.array(lcols))

    # ember core inside the plinth ring: only its faces between the plinth stones show
    ev, ef = fc.lathe([(0.0, 0.5), (EMBER_R, 0.5), (EMBER_R, PLINTH_TOP - 1.2), (0.0, PLINTH_TOP - 1.2)], 24)
    parts.add((ev, ef), "Ember", P("Ember"))

    # plinth: 12 stones with wide gaps, ember lumps in each gap
    n_pl = 12
    gap = 6.0 / PLINTH_R_OUT
    for k in range(n_pl):
        a0 = math.tau * k / n_pl + 0.5 * gap + math.radians(7.0)
        a1 = math.tau * (k + 1) / n_pl - 0.5 * gap + math.radians(7.0)
        z1 = PLINTH_TOP - rng.uniform(0.0, 0.8)
        v, f = stone_block(rng, a0, a1, PLINTH_R_IN, PLINTH_R_OUT, 0.0, z1, chips=(2, 4), ground=True, wobble_deg=1.0,
                           chamfer=0.6)
        v[:, 2] = np.maximum(v[:, 2], 0.0)
        parts.add((v, f), "Stone", block_colours(v, f, 0.5 * (a0 + a1), rng, top_lift=0.2) * 0.92)
        ag = math.tau * (k + 1) / n_pl + math.radians(7.0)          # the gap after this stone
        for j in range(2):
            rad = rng.uniform(1.9, 2.7)
            iv, iff = fc.icosphere(rad, 1)
            iv = iv * rng.uniform(0.8, 1.15, size=3) + rng.uniform(-0.25, 0.25, iv.shape)
            rr = rng.uniform(EMBER_R + 0.5, PLINTH_R_OUT + 0.8)
            aa = ag + rng.uniform(-0.25, 0.25) * gap
            iv = iv + np.array([rr * math.cos(aa), rr * math.sin(aa), 0.0])
            iv[:, 2] -= iv[:, 2].min()
            iv[:, 2] += 0.4 * j * rad
            ec = P("Ember") * np.array([1.0, rng.uniform(0.7, 1.4), 1.0])
            parts.add((iv, iff), "Ember", np.clip(ec, 0, 1))

    # three courses of chipped basalt blocks
    post_a = math.atan2(SOCK_POST[1], SOCK_POST[0])
    for ci, (z0, z1n, n, phase) in enumerate(COURSES):
        top_course = ci == len(COURSES) - 1
        if top_course:
            edges = [math.tau * (k + phase - 0.5) / n for k in range(n + 1)]
        else:
            wts = np.cumsum(np.concatenate([[0.0], rng.uniform(0.7, 1.3, n)]))
            edges = [math.tau * (w / wts[-1] + (phase - 0.5) / n) for w in wts]
        for k in range(n):
            a0, a1 = edges[k], edges[k + 1]
            a_mid = 0.5 * (a0 + a1)
            if top_course and abs(math.remainder(a_mid - notch_a, math.tau)) < 1e-6:
                vf, cols = notch_block(rng, a_mid, math.pi / n, R_IN, R_OUT, z0 + 0.3, RIM_TOP, rest)
                parts.add(vf, "Stone", cols)
                continue
            keep = top_course and abs(math.remainder(a_mid - post_a, math.tau)) < 1e-6
            z1 = z1n if keep else z1n - rng.uniform(0.0, 0.7)
            zb = z0 + (0.3 if ci else 0.0)
            v, f = stone_block(rng, a0, a1, R_IN, R_OUT, zb, z1, keep_top=keep)
            parts.add((v, f), "Stone", block_colours(v, f, a_mid, rng))

    # iron hoop band round the top course + rivets
    hv, hf = sc.torus_ring((0.0, 0.0, HOOP_Z), HOOP_R, HOOP_TUBE, segments=32, sides=4)
    parts.add((hv, hf), "Iron", P("Iron"))
    for k in range(16):
        a = math.tau * (k + 0.5) / 16
        rv, rf = sc.box(polar(HOOP_R + HOOP_TUBE - 0.2, a, HOOP_Z), (1.5, 1.7, 1.7), rot_z_deg=math.degrees(a) + 45.0)
        parts.add((rv, rf), "Iron", P("Iron") * 1.35)

    for i, (v, f, sl, c) in enumerate(parts.items):
        np.minimum(v[:, 2], RIM_TOP, out=v[:, 2])
    obj, cols = parts.build("FryerVat_Mars_SM")
    fc.paint(obj, cols, variation=0.1, seed=11, cavity_darken=0.3)
    fc.smart_uv(obj)
    for name, loc in VAT["sockets"].items():
        sc.add_socket(obj, name, loc)
    # collision: 12 wedges for the ring wall (cavity floor -> rim top), the floor slab under the cavity, the plinth
    sc.ring_ucx(obj, R_IN, R_OUT, CAVITY_FLOOR, RIM_TOP, pieces=12)
    sc.add_ucx(obj, polygon_prism(R_OUT, 12, PLINTH_TOP, CAVITY_FLOOR))
    sc.add_ucx(obj, polygon_prism(PLINTH_R_OUT, 16, 0.0, PLINTH_TOP))
    extra = dict(inner_radius_cm=R_IN, outer_radius_cm=R_OUT, rim_top_cm=RIM_TOP, cavity_floor_cm=CAVITY_FLOOR,
                 oil_level_cm=OIL_LEVEL, plinth_outer_radius_cm=PLINTH_R_OUT, plinth_top_cm=PLINTH_TOP,
                 oil_disc_scale=R_IN / 50.0, liner_radius_cm=LINER_R,
                 skimmer_notch=dict(socket="SkimmerRest", note="radial V groove; the resting skimmer shaft's centre "
                                    "line passes through the socket, rising outward at %.0f deg" % math.degrees(S_REST_ELEV)),
                 ember_note="Ember slot faces: the core ring between the 12 plinth stones + coal lumps in the gaps",
                 ucx_layout="12 ring-wall wedges (z %.0f..%.0f) + floor slab (z %.0f..%.0f) + plinth (z 0..%.0f)" % (
                     CAVITY_FLOOR, RIM_TOP, PLINTH_TOP, CAVITY_FLOOR, PLINTH_TOP))
    return obj, extra, dict(dip_z=dip_z, k_notch=k_notch)


def polygon_prism(radius, n, z0, z1):
    """Hull points of an n-gon prism circumscribing radius (a convex UCX slab)."""
    rr = radius / math.cos(math.pi / n)
    pts = []
    for z in (z0, z1):
        for k in range(n):
            a = math.tau * (k + 0.5) / n
            pts.append((rr * math.cos(a), rr * math.sin(a), z))
    return np.array(pts)


# ================================================================ FryerArmPost
def build_post():
    rng = np.random.default_rng(61041)
    parts = Parts(("Iron",))
    iron = P("Iron")
    parts.add(sc.box((0.0, 0.0, 0.7), (12.0, 10.0, 1.4)), "Iron", iron * 0.95)
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.add(sc.box((sx * 4.4, sy * 3.5, 1.65), (1.3, 1.3, 0.6), rot_z_deg=45.0), "Iron", iron * 1.4)
    # tapered square post
    pts = []
    for z, h in ((1.4, 2.3), (21.0, 1.8)):
        for sx in (-1, 1):
            for sy in (-1, 1):
                pts.append((sx * h, sy * h, z))
    parts.add(hull(np.array(pts) + rng.uniform(-0.05, 0.05, (8, 3))), "Iron", iron)
    parts.add(sc.box((0.0, 0.0, 21.6), (5.0, 7.6, 1.6)), "Iron", iron * 1.1)        # crosshead
    # fork cheeks with chamfered tops
    for sy in (-1, 1):
        y0, y1 = sy * CHEEK_IN, sy * (CHEEK_IN + CHEEK_T)
        cp = []
        for y in (y0, y1):
            for x, z in ((-2.2, 21.0), (2.2, 21.0), (2.2, 29.2), (1.1, 30.6), (-1.1, 30.6), (-2.2, 29.2)):
                cp.append((x, y, z))
        parts.add(hull(cp), "Iron", iron * 1.05)
    # pin + heads
    parts.add(sc.rod((0.0, -3.4, POST_PIN_Z), (0.0, 3.4, POST_PIN_Z), 0.6, sides=6), "Iron", iron * 1.3)
    for sy in (-1, 1):
        parts.add(sc.rod((0.0, sy * 2.9, POST_PIN_Z), (0.0, sy * 3.6, POST_PIN_Z), 1.1, sides=6), "Iron", iron * 1.3)
    # two braces from the foot plate to the post
    for sx in (-1, 1):
        parts.add(tube([(sx * 5.0, 0.0, 1.2), (sx * 2.0, 0.0, 9.0)], 0.6, sides=4, phase=math.pi / 4), "Iron", iron)
    obj, cols = parts.build("FryerArmPost_Mars_SM")
    fc.paint(obj, cols, variation=0.06, seed=12, cavity_darken=0.3)
    fc.smart_uv(obj)
    sc.add_socket(obj, "Hinge", (0.0, 0.0, POST_PIN_Z))
    sc.add_ucx(obj, sc.box((0.0, 0.0, 0.7), (12.0, 10.0, 1.4))[0])
    sc.add_ucx(obj, sc.box((0.0, 0.0, 16.0), (5.0, 7.6, 29.2))[0])
    extra = dict(height_cm=30.6, hinge_height_cm=POST_PIN_Z, hinge_station_cm=ue(HINGE),
                 note="stands at FryerVat SOCKET_ArmPost; the arm pivots at SOCKET_Hinge (pin along Y)")
    return obj, extra


# ================================================================ FryerArm
def arm_geometry():
    """Arm length L so the hang point reaches the lowered basket's bail from the hinge."""
    low_hang = np.array([0.0, 0.0, BASKET_LOW_FLOOR + BAIL_TOP])
    reach = float(np.linalg.norm((low_hang - HINGE)[[0, 2]]))
    hz = -5.2
    hx = -math.sqrt(reach ** 2 - hz ** 2)
    L = -hx + 1.6
    return dict(L=L, hang_local=np.array([hx, 0.0, hz]), reach=reach, low_hang=low_hang)


def build_arm(geo):
    parts = Parts(("Iron", "Wood"))
    iron, wood, wood_dark = P("Iron"), P("Wood"), P("WoodDark")
    L = geo["L"]
    parts.add(sc.rod((0.0, -HUB_HALF_W, 0.0), (0.0, HUB_HALF_W, 0.0), 2.2, sides=8, phase=math.pi / 8), "Iron", iron * 1.1)
    # counter tail behind the pin
    parts.add(hull([(x, y, z) for x in (0.5, 5.5) for y in (-0.8, 0.8) for z in ((-1.1, 1.1) if x < 1 else (-0.7, 0.9))]),
              "Iron", iron)
    # tapered bar to the tip
    bar = [(x, y * w, z * h) for x, w, h in ((-1.0, 1.0, 1.6), (-L, 0.8, 1.15)) for y in (-1, 1) for z in (-1, 1)]
    parts.add(hull(bar), "Iron", iron)
    for xc in (-0.36 * L, -0.68 * L):                               # two forged collars
        parts.add(sc.box((xc, 0.0, 0.0), (1.4, 2.4, 3.0)), "Iron", iron * 1.3)
    parts.add(hull([(x, y, z) for x in (-L + 1.3, -L - 1.3) for y in (-1.1, 1.1) for z in (-1.5, 1.3)]), "Iron", iron * 1.15)
    # hook: down, a U round the bail wire, tip up
    hook = [(-L, 0.0, -0.8), (-L, 0.0, -5.0)]
    for k in range(1, 9):
        t = math.pi + math.pi * k / 8
        hook.append((-L + 1.6 + 1.6 * math.cos(t), 0.0, -5.0 + 1.6 * math.sin(t)))
    hook.append((-L + 3.2, 0.0, -3.6))
    parts.add(tube(hook, 0.6, sides=6, caps=True), "Iron", iron * 1.2)
    # ferrule + wooden handle toward the operator
    parts.add(sc.rod((-L - 1.0, 0, 0), (-L - 2.6, 0, 0), 1.75, sides=8, phase=math.pi / 8), "Iron", iron * 1.25)
    hx = [-L - 2.4, -L - 6.0, -L - 12.0, -L - 15.2, -L - 16.0]
    hr = [1.45, 1.55, 1.7, 1.75, 1.3]
    hv, hf = tube([(x, 0.0, 0.0) for x in hx], 1.0, sides=8, caps=True, radii=hr, phase=math.pi / 8)
    hn = face_normals(hv, hf)
    parts.add((hv, hf), "Wood", np.array([wood_dark if abs(n[0]) > 0.9 else wood for n in hn]))
    obj, cols = parts.build("FryerArm_Mars_SM")
    fc.paint(obj, cols, variation=0.06, seed=13, cavity_darken=0.3)
    fc.smart_uv(obj)
    sc.add_socket(obj, "Hang", geo["hang_local"])
    sc.add_ucx(obj, np.array([(x, y, z) for x in (2.2, -L - 1.3) for y in (-1.6, 1.6) for z in (-2.2, 2.2)]))
    sc.add_ucx(obj, np.array([(x, y, z) for x in (-L - 1.0, -L - 16.0) for y in (-1.8, 1.8) for z in (-1.8, 1.8)]))
    return obj


# ================================================================ FryerBasket
def grid_positions(half, pitch):
    n = max(1, int(round(2.0 * half / pitch)))
    step = 2.0 * half / n
    return [-half + step * i for i in range(1, n)], step


def build_basket():
    parts = Parts(("Wire", "Iron"))
    wire, iron = P("Wire"), P("Iron")
    hx, hy, hz = B_IN[0] * 0.5, B_IN[1] * 0.5, B_IN[2]
    xs, px = grid_positions(hx, B_PITCH)
    ys, py = grid_positions(hy, B_PITCH)
    zs, pz = grid_positions(hz * 0.5, B_PITCH)
    zs = [z + hz * 0.5 for z in zs]
    sq = math.pi / 4
    fx, fy = hx + B_F, hy + B_F                                     # frame centre lines
    # floor: upper layer along X (top at z = 0), lower layer along Y
    for y in ys:
        parts.add(tube([(-fx, y, -B_W), (fx, y, -B_W)], B_W, phase=sq), "Wire", wire)
    for x in xs:
        parts.add(tube([(x, -fy, -3 * B_W), (x, fy, -3 * B_W)], B_W, phase=sq), "Wire", wire)
    # long walls (y = +-): verticals inside, horizontals outside
    for sy in (-1, 1):
        for x in xs:
            parts.add(tube([(x, sy * (hy + B_W), -B_F), (x, sy * (hy + B_W), hz + B_F)], B_W, phase=sq), "Wire", wire)
        for z in zs:
            parts.add(tube([(-fx, sy * (hy + 3 * B_W), z), (fx, sy * (hy + 3 * B_W), z)], B_W, phase=sq), "Wire", wire)
    for sx in (-1, 1):
        for y in ys:
            parts.add(tube([(sx * (hx + B_W), y, -B_F), (sx * (hx + B_W), y, hz + B_F)], B_W, phase=sq), "Wire", wire)
        for z in zs:
            parts.add(tube([(sx * (hx + 3 * B_W), -fy, z), (sx * (hx + 3 * B_W), fy, z)], B_W, phase=sq), "Wire", wire)
    # iron frame: bottom + top rectangles, corner posts
    for z in (-B_F, hz + B_F):
        for sy in (-1, 1):
            parts.add(sc.rod((-fx - B_F, sy * fy, z), (fx + B_F, sy * fy, z), B_F, sides=6), "Iron", iron)
        for sx in (-1, 1):
            parts.add(sc.rod((sx * fx, -fy - B_F, z), (sx * fx, fy + B_F, z), B_F, sides=6), "Iron", iron)
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.add(tube([(sx * fx, sy * fy, -B_F), (sx * fx, sy * fy, hz + B_F)], B_F, sides=6), "Iron", iron)
    # bail lugs on the short ends + the bail arch over the long axis
    lug_x = fx + B_F + 0.5
    bail_z0 = hz - 3.0
    for sx in (-1, 1):
        parts.add(sc.box((sx * (fx + 0.9), 0.0, bail_z0), (1.4, 3.0, 3.4)), "Iron", iron * 1.2)
    bail = []
    for k in range(17):
        t = math.pi * k / 16
        bail.append((lug_x * math.cos(t), 0.0, bail_z0 + (BAIL_TOP - bail_z0) * math.sin(t)))
    parts.add(tube(bail, B_F, sides=6, caps=True), "Iron", iron * 1.15)
    # two hooks on the local -Y long side (hang the basket on a rim)
    for x in (-0.55 * hx, 0.55 * hx):
        y0 = -fy
        hook = [(x, y0, hz + B_F), (x, y0, hz + 3.6), (x, y0 - 1.6, hz + 4.6), (x, y0 - 3.2, hz + 3.6), (x, y0 - 3.4, hz + 1.2)]
        parts.add(tube(hook, 0.55, sides=6, caps=True), "Iron", iron * 1.1)
    obj, cols = parts.build("FryerBasket_Mars_SM")
    fc.paint(obj, cols, variation=0.05, seed=14, cavity_darken=0.2)
    fc.smart_uv(obj)
    sc.add_socket(obj, "Bail", (0.0, 0.0, BAIL_TOP))
    t = 1.6
    sc.box_ucx(obj, (0.0, 0.0, -t * 0.5), (2 * (hx + t), 2 * (hy + t), t))                       # floor slab
    for sy in (-1, 1):
        sc.box_ucx(obj, (0.0, sy * (hy + t * 0.5), (hz + B_F * 2 - t) * 0.5), (2 * (hx + t), t, hz + B_F * 2 + t))
    for sx in (-1, 1):
        sc.box_ucx(obj, (sx * (hx + t * 0.5), 0.0, (hz + B_F * 2 - t) * 0.5), (t, 2 * (hy + t), hz + B_F * 2 + t))
    extra = dict(inner_size_cm=B_IN.tolist(), long_axis="local X", wire_pitch_cm=[round(px, 3), round(py, 3), round(pz, 3)],
                 wire_radius_cm=B_W, frame_radius_cm=B_F, bail_top_cm=BAIL_TOP, rim_top_cm=hz + 2 * B_F,
                 bottom_cm=-4 * B_W, outer_size_cm=[2 * (fx + B_F), 2 * (fy + B_F), hz + 2 * B_F + 4 * B_W])
    return obj, extra


# ================================================================ FryerSkimmer
def sph(rad, phi, theta):
    return S_C + rad * np.array([math.sin(phi) * math.cos(theta), math.sin(phi) * math.sin(theta), -math.cos(phi)])


def build_skimmer():
    parts = Parts(("Wire", "Iron", "Wood"))
    wire, iron, wood, wood_dark = P("Wire"), P("Iron"), P("Wood"), P("WoodDark")
    rw = S_R + S_W                                              # meridians: inner surface = the cap sphere
    ring_phis = [math.radians(a) for a in (22.0, 40.0, 56.0)]
    n_mer = 16
    sq = math.pi / 4
    for k in range(n_mer):
        th = math.tau * k / n_mer
        if k % 4 == 0 and k < 8:                                # two full diameters through the pole
            phis = np.linspace(-S_PHI_RIM, S_PHI_RIM, 17)
            pts = [sph(rw, abs(p), th if p >= 0 else th + math.pi) for p in phis]
            parts.add(tube(pts, S_W, phase=sq), "Wire", wire)
        elif k % 4 == 0:
            continue
        else:
            phis = np.linspace(ring_phis[0], S_PHI_RIM, 7)
            parts.add(tube([sph(rw, p, th) for p in phis], S_W, phase=sq), "Wire", wire)
    for p in ring_phis:
        rr = S_R + 3 * S_W
        rv, rf = sc.torus_ring((0.0, 0.0, S_R - rr * math.cos(p)), rr * math.sin(p), S_W, segments=24, sides=4)
        parts.add((rv, rf), "Wire", wire * 1.05)
    rv, rf = sc.torus_ring((0.0, 0.0, S_RIM_Z), S_RIM_RHO, S_RIM_TUBE, segments=24, sides=4)
    parts.add((rv, rf), "Iron", iron * 1.1)
    # fork from the rim to the shaft
    for s in (-1, 1):
        a = math.radians(30.0) * s
        p0 = np.array([S_RIM_RHO * math.cos(a), S_RIM_RHO * math.sin(a), S_RIM_Z])
        parts.add(tube([p0, S_J], 0.55, sides=6), "Iron", iron)
    parts.add(sc.rod(S_J - 1.2 * S_D, S_J + 1.4 * S_D, 1.05, sides=6), "Iron", iron * 1.2)     # knuckle
    s1 = S_J + S_IRON_LEN * S_D
    parts.add(tube([S_J + 1.0 * S_D, s1 + 0.6 * S_D], S_SHAFT_R, sides=6), "Iron", iron)
    parts.add(sc.rod(s1 - 0.4 * S_D, s1 + 1.6 * S_D, 1.6, sides=8, phase=math.pi / 8), "Iron", iron * 1.25)   # ferrule
    gs = [S_IRON_LEN + 1.4, S_IRON_LEN + 5.0, S_SHAFT_LEN - 3.5, S_SHAFT_LEN - 0.7, S_SHAFT_LEN]
    gr = [1.25, 1.35, 1.5, 1.55, 1.15]
    gv, gf = tube([S_J + s * S_D for s in gs], 1.0, sides=8, caps=True, radii=gr, phase=math.pi / 8)
    gn = face_normals(gv, gf)
    parts.add((gv, gf), "Wood", np.array([wood_dark if abs(n @ S_D) > 0.9 else wood for n in gn]))
    obj, cols = parts.build("FryerSkimmer_Mars_SM")
    fc.paint(obj, cols, variation=0.05, seed=15, cavity_darken=0.2)
    fc.smart_uv(obj)
    grip = S_J + (S_SHAFT_LEN - 0.5 * (S_SHAFT_LEN - S_IRON_LEN - 1.4)) * S_D
    item_r = 6.0
    sc.add_socket(obj, "Grip", grip)
    sc.add_socket(obj, "Item", (0.0, 0.0, rest_height(item_r)))
    wedges = skimmer_wedges()
    for w in wedges:
        sc.add_ucx(obj, w)
    rr = 4.6 / math.cos(math.pi / 12)
    sc.add_ucx(obj, np.array([(rr * math.cos(a), rr * math.sin(a), z) for z in (-1.4, 0.0)
                              for a in np.linspace(0, math.tau, 12, endpoint=False) + math.pi / 12]))
    a0 = np.array([S_RIM_RHO - 0.5, 0.0, S_RIM_Z])
    end = S_J + S_SHAFT_LEN * S_D
    ax = (end - a0) / np.linalg.norm(end - a0)
    up = np.cross(np.cross(ax, [0, 0, 1.0]), ax)
    up /= np.linalg.norm(up)
    side = np.cross(up, ax)
    sc.add_ucx(obj, np.array([p + su * 1.7 * side + uu * 1.7 * up for p in (a0, end) for su in (-1, 1) for uu in (-1, 1)]))
    extra = dict(bowl_inner_radius_cm=S_A, bowl_depth_cm=S_H, cap_sphere_radius_cm=round(S_R, 4),
                 rim_ring=dict(radius_cm=round(S_RIM_RHO, 3), z_cm=round(S_RIM_Z, 3), tube_cm=S_RIM_TUBE),
                 grip_cm=ue(grip), handle_length_cm=S_HANDLE, handle_end_cm=ue(end), shaft_rake_deg=math.degrees(S_RAKE),
                 item_rest_z_cm={"d10": rest_height(5.0), "d12": rest_height(6.0), "d16": rest_height(8.0)},
                 wire_radius_cm=S_W, meridians=n_mer, rings=len(ring_phis))
    return obj, extra


def rest_height(r):
    """Centre height of a resting sphere of radius r in the cap bowl (inner surface sphere S_R, floor at z = 0)."""
    if r <= S_R:
        return round(r, 4)                                       # touches only the lowest point
    return round(S_H + math.sqrt(max(r * r - S_A * S_A, 0.0)), 4)  # sits on the rim circle


WEDGE_PHI = (math.radians(15.0), math.radians(74.0))
WEDGE_T = 1.6
WEDGE_PAD = math.radians(1.2)


def skimmer_wedges():
    """12 convex slabs: each lies beyond the plane tangent to the cap sphere at its sector centre, so its inner face
    never enters the bowl; neighbours overlap by the angular pad."""
    out = []
    for k in range(12):
        t0 = math.tau * k / 12 - WEDGE_PAD
        t1 = math.tau * (k + 1) / 12 + WEDGE_PAD
        tm = 0.5 * (t0 + t1)
        pm = 0.5 * (WEDGE_PHI[0] + WEDGE_PHI[1])
        n = (sph(1.0, pm, tm) - S_C)
        pts = []
        for th in (t0, t1):
            for ph in (WEDGE_PHI[0] - math.radians(1.0), WEDGE_PHI[1]):
                u = sph(1.0, ph, th) - S_C
                cu = float(n @ u)
                for d in (S_R, S_R + WEDGE_T):
                    pts.append(S_C + u * d / cu)
        out.append(np.array(pts))
    return out


# ================================================================ verification helpers
def piece_planes(piece):
    m = piece.data
    v = np.array([x.co[:] for x in m.vertices]) * 100.0
    planes = []
    for p in m.polygons:
        n = np.array(p.normal[:])
        planes.append((n, float(n @ (v[list(p.vertices)].mean(axis=0)))))
    return planes, v, [list(p.vertices) for p in m.polygons]


def ray_enter(o, d, planes):
    tn, tf = -1e9, 1e9
    for n, dd in planes:
        den = float(n @ d)
        num = dd - float(n @ o)
        if abs(den) < 1e-12:
            if num < 0:
                return None
            continue
        t = num / den
        if den < 0:
            tn = max(tn, t)
        else:
            tf = min(tf, t)
    if tn <= tf and tf >= 0:
        return max(tn, 0.0)
    return None


def inside(p, planes, eps=1e-4):
    return all(float(n @ p) <= dd + eps for n, dd in planes)


def surface_samples(v, faces, n=12):
    out = []
    for f in faces:
        for i in range(1, len(f) - 1):
            a, b, c = v[f[0]], v[f[i]], v[f[i + 1]]
            for x in range(n + 1):
                for y in range(n + 1 - x):
                    u, w = x / n, y / n
                    out.append(a + (b - a) * u + (c - a) * w)
    return np.array(out)


def check_skimmer(obj):
    fails, info = [], {}
    pieces = sorted(sc.children(obj, "UCX_"), key=lambda o: o.name)
    data = [piece_planes(p) for p in pieces]
    wedges, floor = data[:12], data[12]
    # 1. every wedge surface at or outside the wire bowl's inner surface (the cap sphere)
    worst = 1e9
    for planes, v, faces in wedges:
        s = surface_samples(v, faces)
        worst = min(worst, float(np.linalg.norm(s - S_C, axis=1).min() - S_R))
    info["wedge_min_outside_cm"] = round(worst, 4)
    if worst < -1e-3:
        fails.append("skimmer wedge enters the bowl by %.3f cm" % -worst)
    # 2. rays from the sphere centre over the whole cap hit collision, clearance <= 2 cm (no hole, no wide gap)
    clear_max, holes = 0.0, 0
    for ph in np.linspace(0.0, S_PHI_RIM, 48):
        for th in np.linspace(0.0, math.tau, 144, endpoint=False):
            d = sph(1.0, ph, th) - S_C
            ts = [ray_enter(S_C, d, pl) for pl, _, _ in wedges + [floor]]
            ts = [t for t in ts if t is not None]
            if not ts:
                holes += 1
                continue
            clear_max = max(clear_max, min(ts) - S_R)
    info["ray_holes"] = holes
    info["max_clearance_cm"] = round(clear_max, 3)
    if holes or clear_max > 2.0:
        fails.append("skimmer collision: %d holes, max clearance %.2f cm" % (holes, clear_max))
    # 3. neighbours overlap along their shared meridian (mid-depth of both slabs)
    bad = 0
    for k in range(12):
        a, b = wedges[k][0], wedges[(k + 1) % 12][0]
        th = math.tau * (k + 1) / 12
        for ph in np.linspace(WEDGE_PHI[0] + 0.02, WEDGE_PHI[1] - 0.02, 9):
            u = sph(1.0, ph, th) - S_C
            tm = math.tau * k / 12 + math.pi / 12
            n = sph(1.0, 0.5 * sum(WEDGE_PHI), tm) - S_C
            p = S_C + u * (S_R + 0.5 * WEDGE_T) / float(n @ u)
            if not (inside(p, a) and inside(p, b)):
                bad += 1
    info["neighbour_overlap_misses"] = bad
    if bad:
        fails.append("skimmer wedges: %d boundary samples not covered by both neighbours" % bad)
    # 4. a 10 cm and a 16 cm sphere rest on the floor disc, untouched by the wedges
    allpts = [surface_samples(v, f, 10) for _, v, f in data]
    for r in (5.0, 8.0):
        c = np.array([0.0, 0.0, rest_height(r)])
        dmin = min(float(np.linalg.norm(s - c, axis=1).min()) for s in allpts[:12])
        dfloor = float(np.linalg.norm(allpts[12] - c, axis=1).min())
        info["ball_d%d" % int(2 * r)] = dict(rest_z=round(c[2], 3), wedge_clearance_cm=round(dmin - r, 3),
                                             floor_gap_cm=round(dfloor - r, 3))
        if dmin < r - 0.02 or abs(dfloor - r) > 0.05:
            fails.append("skimmer ball d%d: wedge %.3f / floor %.3f" % (2 * r, dmin - r, dfloor - r))
    return fails, info


# ================================================================ layout
def mat_world(loc_cm, rot3=None, scale=(1.0, 1.0, 1.0)):
    m = np.eye(4)
    r = np.eye(3) if rot3 is None else np.asarray(rot3, float)
    m[:3, :3] = r @ np.diag(scale)
    m[:3, 3] = np.asarray(loc_cm, float) * 0.01
    return Matrix(m.tolist())


def ue_rotator(rot3):
    """Blender rotation matrix -> Unreal FRotator (pitch, yaw, roll) degrees in the mirrored-Y frame."""
    M = np.diag([1.0, -1.0, 1.0])
    r = M @ np.asarray(rot3, float) @ M
    x, y, z = r[:, 0], r[:, 1], r[:, 2]
    pitch = math.atan2(x[2], math.hypot(x[0], x[1]))
    yaw = math.atan2(x[1], x[0])
    sy = np.array([-math.sin(yaw), math.cos(yaw), 0.0])
    roll = math.atan2(float(z @ sy), float(y @ sy))
    return {"pitch": round(math.degrees(pitch), 3), "yaw": round(math.degrees(yaw), 3), "roll": round(math.degrees(roll), 3)}


def placement(mesh, loc, rot3=None, scale=(1.0, 1.0, 1.0), **notes):
    r = np.eye(3) if rot3 is None else rot3
    eul = Matrix(np.asarray(r).tolist()).to_euler("XYZ")
    d = {"mesh": mesh, "location_cm": ue(loc), "rotation": ue_rotator(r), "scale": [round(s, 4) for s in scale],
         "blender": {"location_cm": [round(float(x), 3) for x in loc],
                     "rotation_euler_xyz_deg": [round(math.degrees(a), 3) for a in eul]}}
    d.update(notes)
    return d


def solve_arm(geo, objs):
    """Arm pitch (rotation about +Y, Blender) for the lowered and raised poses."""
    h = geo["hang_local"]
    tgt = geo["low_hang"] - HINGE
    beta_low = math.atan2(h[2], h[0]) - math.atan2(tgt[2], tgt[0])
    beta_low = math.remainder(beta_low, math.tau)
    beta_raised = math.radians(34.0)
    return beta_low, beta_raised


def build_layout(geo, rest, objs):
    beta_low, beta_raised = solve_arm(geo, objs)
    yaw_b = rot_z(90.0)
    poses = {}
    for key, beta in (("lowered", beta_low), ("raised", beta_raised)):
        r = rot_y(beta)
        hang = HINGE + r @ geo["hang_local"]
        bloc = hang - yaw_b @ np.array([0.0, 0.0, BAIL_TOP])
        poses[key] = dict(beta=beta, arm_rot=r, hang=hang, basket_loc=bloc)
    low, rai = poses["lowered"], poses["raised"]
    oil_scale = R_IN / 50.0
    layout = {
        "station": "fryer",
        "frame": "station frame in Unreal local cm (Blender Y mirrored): operator stands at -X looking +X, the vat "
                 "axis at the origin, floor z = 0. Rotations are FRotator degrees; 'blender' repeats Blender values.",
        "props": {
            "FryerVat": placement("FryerVat_Mars_SM", (0, 0, 0)),
            "FryerArmPost": placement("FryerArmPost_Mars_SM", SOCK_POST, attach="FryerVat SOCKET_ArmPost"),
            "FryerArm_Lowered": placement("FryerArm_Mars_SM", HINGE, low["arm_rot"],
                                          attach="FryerArmPost SOCKET_Hinge; rotate about local Y only",
                                          hang_cm=ue(low["hang"])),
            "FryerArm_Raised": placement("FryerArm_Mars_SM", HINGE, rai["arm_rot"], hang_cm=ue(rai["hang"])),
            "FryerBasket_Lowered": placement("FryerBasket_Mars_SM", low["basket_loc"], yaw_b,
                                             attach="SOCKET_Bail on FryerArm SOCKET_Hang, hangs level (yaw only)",
                                             floor_z_cm=round(float(low["basket_loc"][2]), 3),
                                             rim_z_cm=round(float(low["basket_loc"][2] + B_IN[2] + 2 * B_F), 3)),
            "FryerBasket_Raised": placement("FryerBasket_Mars_SM", rai["basket_loc"], yaw_b,
                                            floor_z_cm=round(float(rai["basket_loc"][2]), 3),
                                            bottom_z_cm=round(float(rai["basket_loc"][2] - 4 * B_W), 3)),
            "FryerSkimmer_Rest": placement("FryerSkimmer_Mars_SM", rest["loc"], rest["rot"],
                                           note="shaft centre line passes through FryerVat SOCKET_SkimmerRest "
                                                "(radial notch), rising outward %.0f deg; bowl over the oil" % math.degrees(rest["elev"])),
            "OilSurface": placement("OilSurface_Mars_SM", SOCK_OIL, None, (oil_scale, oil_scale, 1.0),
                                    attach="FryerVat SOCKET_Oil", note="1 m disc scaled to inner_radius / 50"),
        },
        "arm": {"hinge_cm": ue(HINGE), "reach_cm": round(geo["reach"], 3), "length_cm": round(geo["L"], 3),
                "pitch_lowered_deg": round(-math.degrees(beta_low), 3), "pitch_raised_deg": round(-math.degrees(beta_raised), 3),
                "note": "FRotator pitch of the arm (rotation about its local Y at the hinge); the basket stays level "
                        "and hangs from SOCKET_Hang"},
        "levels_cm": {"floor": 0.0, "cavity_floor": CAVITY_FLOOR, "oil": OIL_LEVEL, "rim_top": RIM_TOP},
    }
    return layout, poses


def arm_hang_local(arm):
    return np.asarray(sc.children(arm, "SOCKET_Hang")[0].location, float) * 100.0


def layout_checks(objs, poses, rest):
    fails, info = [], {}
    low, rai = poses["lowered"], poses["raised"]
    floor_low = low["basket_loc"][2]
    rim_low = floor_low + B_IN[2] + 2 * B_F
    info["lowered_basket_floor_z"] = round(float(floor_low), 3)
    info["lowered_basket_rim_z"] = round(float(rim_low), 3)
    if not (floor_low < OIL_LEVEL < rim_low):
        fails.append("lowered basket floor %.1f / rim %.1f vs oil %.1f" % (floor_low, rim_low, OIL_LEVEL))
    if floor_low - 4 * B_W < CAVITY_FLOOR + 2:
        fails.append("lowered basket touches the cavity floor")
    bottom_raised = rai["basket_loc"][2] - 4 * B_W
    info["raised_basket_bottom_z"] = round(float(bottom_raised), 3)
    if bottom_raised < RIM_TOP + 5:
        fails.append("raised basket bottom %.1f not clear of the rim" % bottom_raised)

    def world_verts(obj, M):
        v = fc.verts_cm(obj)
        m = np.array(M)
        return v @ m[:3, :3].T + m[:3, 3] * 100.0

    from mathutils.kdtree import KDTree

    def min_dist(a, b):
        kd = KDTree(len(b))
        for i, p in enumerate(b):
            kd.insert(p, i)
        kd.balance()
        return min(kd.find(p)[2] for p in a)

    skim_w = world_verts(objs["skim"], mat_world(rest["loc"], rest["rot"]))
    bas_low = world_verts(objs["basket"], mat_world(low["basket_loc"], rot_z(90)))
    bas_rai = world_verts(objs["basket"], mat_world(rai["basket_loc"], rot_z(90)))
    arm_low = world_verts(objs["arm"], mat_world(HINGE, low["arm_rot"]))
    arm_rai = world_verts(objs["arm"], mat_world(HINGE, rai["arm_rot"]))
    post_w = world_verts(objs["post"], mat_world(SOCK_POST))
    info["clear_skimmer_basket_lowered_cm"] = round(min_dist(skim_w, bas_low), 2)
    av = fc.verts_cm(objs["arm"])
    away = np.linalg.norm(av - arm_hang_local(objs["arm"]), axis=1) > 5.0       # the hook itself holds the bail
    info["clear_arm_basket_raised_cm"] = round(min_dist(arm_rai[away], bas_rai), 2)
    info["clear_arm_basket_lowered_cm"] = round(min_dist(arm_low[away], bas_low), 2)
    info["clear_post_basket_raised_cm"] = round(min_dist(post_w, bas_rai), 2)
    for k in ("clear_skimmer_basket_lowered_cm", "clear_arm_basket_raised_cm", "clear_arm_basket_lowered_cm",
              "clear_post_basket_raised_cm"):
        if info[k] < 1.0:
            fails.append("%s = %.2f" % (k, info[k]))
    # the skimmer bowl stays inside the liner and above the oil
    sv = fc.verts_cm(objs["skim"])
    bowl = skim_w[sv[:, 0] < S_RIM_RHO + 1.0]
    rmax = float(np.hypot(bowl[:, 0], bowl[:, 1]).max())
    zmin = float(bowl[:, 2].min())
    info["skimmer_bowl_max_radius_cm"] = round(rmax, 2)
    info["skimmer_bowl_min_z_cm"] = round(zmin, 2)
    if rmax > R_IN - 0.3 or zmin < OIL_LEVEL:
        fails.append("skimmer rest bowl radius %.1f / low z %.1f" % (rmax, zmin))
    # arm lowered: bar over the rim
    lo_arm_vs_rim = float(arm_low[np.hypot(arm_low[:, 0], arm_low[:, 1]) > R_IN - 1.0][:, 2].min())
    info["arm_lowered_min_z_over_rim_cm"] = round(lo_arm_vs_rim, 2)
    if lo_arm_vs_rim < RIM_TOP + 2:
        fails.append("lowered arm dips to %.1f over the rim" % lo_arm_vs_rim)
    return fails, info


# ================================================================ review renders
def assembly(name, placements, extras=()):
    """One joined mesh of copies of the props placed per the layout (for the assembled review shots)."""
    made = []
    for obj, M in placements:
        me = obj.data.copy()
        me.transform(M)
        o = bpy.data.objects.new(name + "_part", me)
        bpy.context.scene.collection.objects.link(o)
        made.append(o)
    made.extend(extras)
    for o in bpy.context.scene.objects:
        o.select_set(o in made)
    bpy.context.view_layer.objects.active = made[0]
    with bpy.context.temp_override(active_object=made[0], selected_objects=made, selected_editable_objects=made):
        bpy.ops.object.join()
    asm = made[0]
    asm.name = name
    return asm


def proxies():
    """Review-only proxies: the oil disc (OilSurface stand-in) and a 1.5 m chef at the operator spot."""
    out = []
    ov, of = fc.lathe([(0.0, -0.3), (50.0, -0.3), (50.0, 0.0), (0.0, 0.0)], 32)
    s = R_IN / 50.0
    ov = ov * np.array([s, s, 1.0]) + SOCK_OIL
    oil = fc.new_object("_OilProxy", ov, of, slots=("Oil",))
    fc.paint(oil, np.repeat(fc.srgb(214, 132, 34)[None, :], len(of), axis=0), variation=0.04, cavity_darken=0.0)
    out.append(oil)
    bv, bf = fc.lathe([(0.0, 0.0), (19.0, 0.0), (23.0, 40.0), (20.0, 92.0), (13.0, 114.0), (0.0, 118.0)], 10)
    hv, hf = fc.icosphere(16.0, 2)
    hv = hv + np.array([0.0, 0.0, 134.0])
    v, f, sl = fc.merge([(bv, bf, 0), (hv, hf, 0)])
    v = v + np.array([-96.0, 0.0, 0.0])
    chef = fc.new_object("_ChefProxy", v, f, slots=("Stone",))
    cols = np.array([fc.srgb(150, 36, 36)] * len(bf) + [fc.srgb(225, 225, 225)] * len(hf))
    fc.paint(chef, cols, variation=0.03, cavity_darken=0.0)
    out.append(chef)
    return out


# review_sheet aims at 0.45 x the largest extent with a 1800-wide, horizontally fitted lens: a taller image widens
# the vertical field so the low, wide props are not cropped; the gap pulls the camera back for off-centre props
# (the skimmer's origin is at the bowl, the arm's at the pin)
REVIEW_FRAME = {"vat": (1.25, (1800, 1300)), "post": (1.6, (1800, 1000)), "arm": (1.6, (1800, 900)),
                "basket": (1.4, (1800, 1000)), "skim": (1.6, (1800, 900))}


def render_sheets(objs, poses, rest):
    paths = []
    for key, stem in (("vat", "FryerVat"), ("post", "FryerArmPost"), ("arm", "FryerArm"), ("basket", "FryerBasket"),
                      ("skim", "FryerSkimmer")):
        paths.append(fc.review_sheet([objs[key]], stem, views=spec.REVIEW_VIEWS, color="VERTEX",
                                       gap=REVIEW_FRAME[key][0], size=REVIEW_FRAME[key][1]))
    fc.VIEWS["operator"] = (-1.0, -0.75, 0.8)
    for key in ("lowered", "raised"):
        pose = poses[key]
        pl = [(objs["vat"], mat_world((0, 0, 0))), (objs["post"], mat_world(SOCK_POST)),
              (objs["arm"], mat_world(HINGE, pose["arm_rot"])),
              (objs["basket"], mat_world(pose["basket_loc"], rot_z(90.0))),
              (objs["skim"], mat_world(rest["loc"], rest["rot"]))]
        asm = assembly("_FryerStation_" + key, pl, proxies())
        stem = "FryerStation_" + key.capitalize()
        paths.append(fc.review_sheet([asm], stem, views=spec.REVIEW_VIEWS + ("operator",), color="VERTEX", gap=1.3,
                                       size=(1800, 1300)))
        me = asm.data
        bpy.data.objects.remove(asm)
        bpy.data.meshes.remove(me)
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)
    return paths


def layout_collection(objs, poses, rest):
    """Linked duplicates placed per the layout (lowered pose) in their own collection, for the saved .blend."""
    coll = bpy.data.collections.new("FryerStation_Layout")
    bpy.context.scene.collection.children.link(coll)
    pose = poses["lowered"]
    for key, M in (("vat", mat_world((0, 0, 0))), ("post", mat_world(SOCK_POST)),
                   ("arm", mat_world(HINGE, pose["arm_rot"])), ("basket", mat_world(pose["basket_loc"], rot_z(90.0))),
                   ("skim", mat_world(rest["loc"], rest["rot"]))):
        o = bpy.data.objects.new("Layout_" + objs[key].name.replace("_Mars_SM", ""), objs[key].data)
        o.matrix_world = M
        coll.objects.link(o)
    lc = bpy.context.view_layer.layer_collection.children.get(coll.name)
    if lc:
        lc.hide_viewport = True


# ================================================================ main
def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False})
    t0 = time.time()
    fc.ensure_dirs()
    fc.clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    fails = []

    rest = skimmer_rest()
    geo = arm_geometry()
    vat, vat_extra, vat_info = build_vat(rest)
    post, post_extra = build_post()
    arm = build_arm(geo)
    basket, basket_extra = build_basket()
    skim, skim_extra = build_skimmer()
    objs = dict(vat=vat, post=post, arm=arm, basket=basket, skim=skim)

    layout, poses = build_layout(geo, rest, objs)
    arm_extra = dict(reach_cm=round(geo["reach"], 3), arm_length_cm=round(geo["L"], 3),
                     hang_local_cm=ue(geo["hang_local"]), hinge_height_station_cm=float(HINGE[2]),
                     hinge_station_cm=ue(HINGE),
                     pitch_lowered_deg=layout["arm"]["pitch_lowered_deg"], pitch_raised_deg=layout["arm"]["pitch_raised_deg"],
                     note="pivot = the bracket pin (Unreal local Y axis); unrotated the arm points along -X")
    post_extra["shares_tri_budget_with"] = "FryerArm (spec FryerArm tris_max covers post + arm)"

    # ---- checks
    budgets = {"vat": VAT["tris_max"], "basket": BASKET["tris_max"], "skim": SKIM["tris_max"]}
    for key, cap in budgets.items():
        if fc.tri_count(objs[key]) > cap:
            fails.append("%s tris %d > %d" % (objs[key].name, fc.tri_count(objs[key]), cap))
    arm_total = fc.tri_count(arm) + fc.tri_count(post)
    if arm_total > ARM["tris_max"]:
        fails.append("arm + post tris %d > %d" % (arm_total, ARM["tris_max"]))
    lo, hi = fc.bounds_cm(vat)
    if abs(lo[2]) > 1e-3 or abs(hi[2] - RIM_TOP) > 0.05:
        fails.append("vat z range %.3f..%.3f" % (lo[2], hi[2]))
    lo, hi = fc.bounds_cm(post)
    if abs(lo[2]) > 1e-3:
        fails.append("post foot at %.3f" % lo[2])
    sk_fails, sk_info = check_skimmer(skim)
    fails += sk_fails
    skim_extra["collision_check"] = sk_info
    lay_fails, lay_info = layout_checks(objs, poses, rest)
    fails += lay_fails
    layout["checks"] = lay_info
    vat_extra["liner_notch_dip_z_cm"] = round(vat_info["dip_z"], 3)
    print("skimmer collision:", json.dumps(sk_info))
    print("layout checks:", json.dumps(lay_info))
    for o in objs.values():
        lo, hi = fc.bounds_cm(o)
        print("%-24s tris %5d  bounds %s .. %s" % (o.name, fc.tri_count(o), np.round(lo, 2), np.round(hi, 2)))

    exported = []
    if args["export"]:
        for key, extra in (("vat", vat_extra), ("post", post_extra), ("arm", arm_extra), ("basket", basket_extra),
                           ("skim", skim_extra)):
            extra = dict(extra, station="fryer", builder="build_station_fryer.py")
            exported.append(sc.export_fbx(objs[key], extra=extra))
        print("layout:", sc.layout_json("FryerStation_Layout", layout))
    sheets = []
    if args["sheets"]:
        sheets = render_sheets(objs, poses, rest)
    if args["save"]:
        layout_collection(objs, poses, rest)
        for m in list(bpy.data.materials):
            if m.users == 0:
                bpy.data.materials.remove(m)
        sc.save_blend("fryer")
        print("saved", os.path.join(spec.BLEND_DIR, spec.STATIONS["fryer"][0]))

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
            print("reimport %-24s tris %5d uv %s colors %s flat %s slots %s ucx %d" % (
                r["name"], r["tris"], r["uv_layers"], r["colors"], r["flat"], r["slots"], len(ucx)))
            if not ok:
                fails.append("reimport %s: uv %s colors %s flat %s" % (stem, r["uv_layers"], r["colors"], r["flat"]))
        if len(ucx) != meta["ucx_pieces"] or meta["ucx_problems"]:
            fails.append("%s: ucx reimported %d / sidecar %d problems %s" % (stem, len(ucx), meta["ucx_pieces"],
                                                                             meta["ucx_problems"]))
        print("  sidecar %s tris %d sockets %s" % (stem, meta["tris"], json.dumps(meta["sockets"])))
    print("\nsheets:", *sheets, sep="\n  ")
    print("total %.1fs" % (time.time() - t0))
    if fails:
        print("STATION_FRYER_FAIL", *fails, sep="\n  ")
    else:
        print("STATION_FRYER_OK")


main()
