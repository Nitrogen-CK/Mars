"""Mars environment dressing, family "vines" (ENV_KIT.md, Tools/Environment/VINES_PLAN.md section 4.3): the meshes the
vine and root generator (Script/WorldObjects/Dressing/Vines) lays, rebuilt from fixed seeds in headless Blender 5.2.

  VineBark_A_Mars_SM      EnvBark    spline-mesh root segment: open tube along +X, x 0 .. 100, radius 50, 9 sides x 6
                                     rings, bark ridges (amplitude 0.08); its end rings are one shared profile, so any
                                     segment meets any other (A or B) seamlessly. One UCX hull (8 x 2) for Collision On.
  VineBark_B_Mars_SM      EnvBark    the same with 8 rings and a knot bulge mid-way.
  VineStemIvy_Mars_SM     EnvBark    ivy stem chord: 6 sides x 4 rings, x 0 .. 100, radius 50.
  VineTip_Mars_SM         EnvBark    root tip: the shared ring at x 0 (radius 50) to a point at x 100.
  VineKnot_A/B_Mars_SM    EnvBark    burls, radius ~50 about the origin, the flat side toward -Z (onto the root).
  VineLeaves_A/B/C_Mars_SM EnvLeaf   3 / 5 / 7 folded ivy leaves fanning to +X (9 / 14 / 20 cm), faces +Z, petiole base at
                                     the origin. UV1 EnvData: u = leaf id, v = distance from the pivot / max.
  VineMossStrand_A/B/C    EnvStrand  two crossed jagged ribbons hanging from the origin to z -100 (3 - 6 cm wide).
  VineRootlet_A/B         EnvStrand  a 3-sided hair root (r 0.5) to z -100 with 2 - 3 side hairs.
  VineCobweb_A            EnvStrand  a sagging fan of threads below the origin, 100 x 100, pale.
                                     Cards: UV1 EnvData u = strand / thread id, v = 0 at the top .. 1 at the bottom (cobweb:
                                     sag weight). The generator stretches a card to its traced length (scale z = L / 100).
  HeroRoot_Top_A          EnvBark    atrium hero root, ceiling module: 180 tall from the ceiling contact (z 0) down, two
                                     fused strands (~74 cm thick) that fork into 3 ceiling fingers.
  HeroRoot_Mid_A/B/C      EnvBark    350 tall, one full twist; canonical joint loops at z 0 and z -350 (horizontal rings,
                                     noise faded to zero within 15 cm), so any variant stacks under any other, yaw 0 or 180.
  HeroRoot_Flare_A/B      EnvBark    160 tall to the floor (z -160) with 4 - 6 floor fingers spreading to ~260 cm.
                                     Hero modules carry 2 - 3 UCX hulls (AMars_HeroRoot collides by default).

Run (always absolute paths):
  "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup --python
      D:\\Repo\\Mars\\Tools\\Blender\\mars_environment\\build_env_vines.py -- [--export] [--sheets] [--save] [--only <part>]
Prints ENV_VINES_OK when every check passed (ENV_VINES_FAIL + the reasons otherwise; ENV_VINES_PARTIAL with --only).

Frames: centimetres, Blender axes (Z up); sidecars give Unreal local cm (Y mirrored).
"""
import json
import math
import os
import sys
import time

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import env_common as ec          # noqa: E402
import env_vines_parts as vp     # noqa: E402

spec, fc, sc = ec.spec, ec.fc, ec.sc
FAMILY = "vines"
REVIEW_BG = (0.2, 0.205, 0.215)
TAU = math.tau

# name -> category (env_spec.TRIS budget), tri cap, slot, data uv, kind
MESHES = {
    "VineBark_A": dict(cat="scatter", cap=160, slot="EnvBark", data_uv=False, kind="segment"),
    "VineBark_B": dict(cat="scatter", cap=160, slot="EnvBark", data_uv=False, kind="segment"),
    "VineStemIvy": dict(cat="scatter", cap=60, slot="EnvBark", data_uv=False, kind="segment"),
    "VineTip": dict(cat="scatter", cap=40, slot="EnvBark", data_uv=False, kind="tip"),
    "VineKnot_A": dict(cat="scatter", cap=80, slot="EnvBark", data_uv=False, kind="knot"),
    "VineKnot_B": dict(cat="scatter", cap=80, slot="EnvBark", data_uv=False, kind="knot"),
    "VineLeaves_A": dict(cat="scatter", cap=30, slot="EnvLeaf", data_uv=True, kind="leaf"),
    "VineLeaves_B": dict(cat="scatter", cap=50, slot="EnvLeaf", data_uv=True, kind="leaf"),
    "VineLeaves_C": dict(cat="scatter", cap=70, slot="EnvLeaf", data_uv=True, kind="leaf"),
    "VineMossStrand_A": dict(cat="scatter", cap=60, slot="EnvStrand", data_uv=True, kind="card"),
    "VineMossStrand_B": dict(cat="scatter", cap=60, slot="EnvStrand", data_uv=True, kind="card"),
    "VineMossStrand_C": dict(cat="scatter", cap=60, slot="EnvStrand", data_uv=True, kind="card"),
    "VineRootlet_A": dict(cat="scatter", cap=60, slot="EnvStrand", data_uv=True, kind="card"),
    "VineRootlet_B": dict(cat="scatter", cap=60, slot="EnvStrand", data_uv=True, kind="card"),
    "VineCobweb_A": dict(cat="scatter", cap=120, slot="EnvStrand", data_uv=True, kind="card"),
    "HeroRoot_Top_A": dict(cat="furniture", cap=9000, slot="EnvBark", data_uv=False, kind="hero"),
    "HeroRoot_Mid_A": dict(cat="furniture", cap=9000, slot="EnvBark", data_uv=False, kind="hero"),
    "HeroRoot_Mid_B": dict(cat="furniture", cap=9000, slot="EnvBark", data_uv=False, kind="hero"),
    "HeroRoot_Mid_C": dict(cat="furniture", cap=9000, slot="EnvBark", data_uv=False, kind="hero"),
    "HeroRoot_Flare_A": dict(cat="furniture", cap=9000, slot="EnvBark", data_uv=False, kind="hero"),
    "HeroRoot_Flare_B": dict(cat="furniture", cap=9000, slot="EnvBark", data_uv=False, kind="hero"),
}
ORDER = tuple(MESHES)

# paint (sRGB) per family of faces
BARK = fc.srgb(*spec.PALETTE_SRGB["EnvBark"])
BARK_DARK = fc.srgb(*spec.PALETTE_SRGB["EnvBarkDark"])
BARK_LIGHT = fc.srgb(112, 84, 58)
LEAF = [fc.srgb(*spec.PALETTE_SRGB[k]) for k in ("EnvLeaf", "EnvLeafLight", "EnvLeafDark")]
PETIOLE = fc.srgb(58, 60, 30)
MOSS_TOP, MOSS_TIP = fc.srgb(54, 66, 34), fc.srgb(104, 110, 56)
ROOTLET_TOP, ROOTLET_TIP = fc.srgb(70, 52, 36), fc.srgb(112, 90, 64)
COBWEB = fc.srgb(196, 194, 188)

# hero root numbers (VINES_PLAN 3.6 / 3.11): root radius R, strand radius 0.62 R, strand offset 0.42 R, one turn per mid
HERO_R = 36.0
HERO_STRAND = 0.62 * HERO_R
HERO_OFFSET = 0.42 * HERO_R
HERO_PITCH = 350.0
HERO_SIDES = 10
HERO_RING_STEP = 7.5
HERO_FADE = 15.0


# ================================================================ small meshes
def make(name, part, slot):
    obj = ec.new_object(name + "_Mars_SM", part.verts, part.faces, slots=(slot,), recalc_normals=False)
    return obj


def lerp3(a, b, t):
    return a + (b - a) * t


def build_segment(name):
    if name == "VineBark_A":
        part = vp.bark_tube(sides=9, rings=6, ridge=0.08, bulge=0.0, seed=21)
    elif name == "VineBark_B":
        part = vp.bark_tube(sides=9, rings=8, ridge=0.08, bulge=0.22, seed=34)
    else:
        part = vp.bark_tube(sides=6, rings=4, ridge=0.05, bulge=0.0, seed=7, interior_jitter=0.04, twist_deg=20.0)
    obj = make(name, part, "EnvBark")
    _wind_outward(obj, axis="x")
    sides = 9 if name.startswith("VineBark") else 6
    fc.paint(obj, side_bark(len(part.faces), sides, part.face_tone), alpha=open_end_cavity(obj, axis=0, ends=(0.0, 100.0)),
             variation=0.015, seed=len(name), cavity_darken=0.3)
    if name.startswith("VineBark"):
        # one convex 8 x 2 hull for the optional collision path (the spline mesh deforms it)
        hull = []
        for x in (0.0, 100.0):
            for k in range(8):
                a = TAU * k / 8
                hull.append((x, 50.0 * math.cos(a), 50.0 * math.sin(a)))
        sc.add_ucx(obj, hull)
    return obj, dict(end_profile=vp.ring_profile(9 if name.startswith("VineBark") else 6,
                                                 0.08 if name.startswith("VineBark") else 0.05, vp.END_SEED).tolist())


# one tone per tube side, constant along the length (fibres running with the root; the joint rolls twist them), so the
# bark reads as long grooves rather than a checkerboard of facets
SIDE_TONES = [1.0, 0.86, 1.08, 0.94, 0.8, 1.04, 0.9, 1.12, 0.84, 0.97, 1.06, 0.88]


def side_bark(n_faces, sides, face_tone=None):
    out = []
    for i in range(n_faces):
        k = i % sides
        base = BARK_DARK if (face_tone is not None and face_tone[i] == 1) else BARK
        out.append(base * SIDE_TONES[k % len(SIDE_TONES)])
    return out


def open_end_cavity(obj, axis, ends, tol=0.01):
    """The vertex cavity with the open end rings set to the mean of the mesh: an open boundary skews the vertex normals
    there, which fc.cavity reads as a deep crevice and would paint as a dark band at every joint."""
    cav = fc.cavity(obj)
    v = fc.verts_cm(obj)
    on_end = np.zeros(len(v), bool)
    for e in ends:
        on_end |= np.abs(v[:, axis] - e) < tol
    if on_end.any() and (~on_end).any():
        cav[on_end] = float(np.median(cav[~on_end]))
    return cav


def build_tip(name):
    part = vp.tip(sides=9, rings=2, ridge=0.08, seed=5)
    obj = make(name, part, "EnvBark")
    _wind_outward(obj, axis="x")
    fc.paint(obj, [BARK_DARK if t else BARK for t in part.face_tone], variation=0.05, seed=5, cavity_darken=0.3)
    return obj, {}


def build_knot(name):
    part = vp.knot(seed=77 if name.endswith("A") else 93, lumps=3 if name.endswith("A") else 4)
    obj = make(name, part, "EnvBark")
    _wind_outward(obj, axis=None)
    fc.paint(obj, [BARK_LIGHT if t == 0 else BARK for t in part.face_tone], variation=0.07, seed=9, cavity_darken=0.4)
    return obj, {}


def build_leaves(name):
    count, span, seed = {"VineLeaves_A": (3, 9.0, 501), "VineLeaves_B": (5, 14.0, 502), "VineLeaves_C": (7, 20.0, 503)}[name]
    part = vp.leaf_cluster(seed, count, span)
    obj = make(name, part, "EnvLeaf")
    _wind_up(obj)
    rng = np.random.default_rng(seed)
    rgb = []
    for t, ident in zip(part.face_tone, part.face_ids):
        base = PETIOLE if t == 3 else LEAF[int(ident * 97) % 3]
        rgb.append(base * rng.uniform(0.92, 1.08))
    fc.paint(obj, rgb, alpha=0.75 + 0.25 * part.vflex, variation=0.05, seed=seed, cavity_darken=0.2)
    fc.smart_uv(obj)
    write_env_data(obj, part)
    return obj, {}


def build_card(name):
    if name.startswith("VineMoss"):
        seed = {"A": 611, "B": 612, "C": 613}[name[-1]]
        part = vp.moss_strand(seed, rows=12, width=(3.0, 6.0) if name[-1] != "C" else (2.5, 4.5))
        top, tip_c = MOSS_TOP, MOSS_TIP
    elif name.startswith("VineRootlet"):
        seed = {"A": 621, "B": 622}[name[-1]]
        part = vp.rootlet(seed, segs=8, radius=0.8, hairs=3 if name[-1] == "A" else 2)
        top, tip_c = ROOTLET_TOP, ROOTLET_TIP
    else:
        seed = 631
        part = vp.cobweb_strand(seed)
        top, tip_c = COBWEB, COBWEB * 0.92
    obj = make(name, part, "EnvStrand")
    rng = np.random.default_rng(seed)
    rgb = []
    for f, t in zip(part.faces, part.face_tone):
        depth = float(np.clip(-part.verts[f, 2].mean() / 100.0, 0.0, 1.0))
        c = lerp3(top, tip_c, depth ** 0.8) * rng.uniform(0.9, 1.1)
        if t == 1 and name.startswith("VineMoss"):
            c = c * 0.82
        rgb.append(c)
    fc.paint(obj, rgb, alpha=0.7 + 0.3 * part.vflex, variation=0.04, seed=seed, cavity_darken=0.15)
    fc.smart_uv(obj)
    write_env_data(obj, part)
    return obj, {}


def write_env_data(obj, part):
    """UV1 EnvData per corner from the mesh's own loops (face winding may have been flipped): u = the face's id, v =
    the corner vertex's flex."""
    mesh = obj.data
    loops_v = np.empty(len(mesh.loops), dtype=np.int64)
    mesh.loops.foreach_get("vertex_index", loops_v)
    loop_face = np.empty(len(mesh.loops), dtype=np.int64)
    for poly in mesh.polygons:
        loop_face[poly.loop_start:poly.loop_start + poly.loop_total] = poly.index
    ids = np.asarray(part.face_ids, float)[loop_face]
    flex = np.clip(np.asarray(part.vflex, float)[loops_v], 0.0, 1.0)
    ec.write_data_uv(obj, ids, flex, domain="CORNER")


def _wind_outward(obj, axis="x"):
    """Make every face wind away from the part's axis (tubes: the X axis; knots: the origin)."""
    mesh = obj.data
    v = fc.verts_cm(obj)
    flips = []
    for p in mesh.polygons:
        c = v[list(p.vertices)].mean(axis=0)
        out = c.copy()
        if axis == "x":
            out[0] = 0.0
        n = np.array(p.normal[:])
        flips.append(float(n @ out) < 0.0)
    _flip(obj, flips)


def _wind_up(obj):
    mesh = obj.data
    _flip(obj, [p.normal[2] < 0.0 for p in mesh.polygons])


def _flip(obj, flips):
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    sel = [bm.faces[i] for i, f in enumerate(flips) if f]
    if sel:
        bmesh.ops.reverse_faces(bm, faces=sel)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


# ================================================================ hero roots
def hero_phase(z_mid_local):
    """Strand phase at a mid-module height (z 0 at its top, -350 at its bottom): one full turn per module."""
    return TAU * (-z_mid_local) / HERO_PITCH


def hero_centre(strand, phase, z, wander=(0.0, 0.0)):
    a = phase + math.pi * strand
    return np.array([HERO_OFFSET * math.cos(a) + wander[0], HERO_OFFSET * math.sin(a) + wander[1], z])


def hero_ring(centre, ref, normal, radius, prof, noise):
    """A ring of HERO_SIDES points about centre in the plane of ref (and normal x ref)."""
    ref = vp._n(ref)
    w = vp._n(np.cross(normal, ref))
    pts = []
    for k in range(HERO_SIDES):
        a = TAU * k / HERO_SIDES
        r = radius * (prof[k] + noise[k])
        pts.append(centre + r * (math.cos(a) * ref + math.sin(a) * w))
    return pts


HERO_PROFILE = vp.ring_profile(HERO_SIDES, 0.07, 9417)


def hero_tube(path, radii, joint_flags, ref0, seed, radial=True):
    """A tube along path (n, 3) with radii (n,) and the shared ridge profile. Rings flagged as joints are horizontal
    (normal +Z) with the radial reference ref0-style (from the strand axis) and no noise; the others use a rotation-
    minimising frame propagated from the first ring, with noise faded near any joint. Returns (verts, quads)."""
    rng = np.random.default_rng(seed)
    n = len(path)
    t = np.zeros((n, 3))
    for i in range(n):
        t[i] = vp._n(path[min(i + 1, n - 1)] - path[max(i - 1, 0)])
    ref = vp._n(ref0 - t[0] * (ref0 @ t[0]))
    verts, quads = [], []
    # low-frequency bark swell per side (no per-vertex white noise: on flat-shaded facets it reads as a checkerboard)
    phases = rng.uniform(0.0, TAU, HERO_SIDES)
    s_along = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))])
    for i in range(n):
        if radial:
            # strand ropes: the reference is the direction from the root axis (z) to the strand centre, so it never
            # drifts against the joint rings the way a rotation-minimising frame does along a helix
            rr = np.array([path[i][0], path[i][1], 0.0])
            ref = vp._n(rr - t[i] * (rr @ t[i])) if np.linalg.norm(rr) > 1e-3 else ref
        elif i > 0:
            ref = ref - t[i] * (ref @ t[i])
            ref = vp._n(ref)
        fade = joint_flags[i]
        if fade >= 1.0:
            # joint ring: the tube's exact horizontal slice at the joint height, from the canonical helix tangent (not
            # the path's one-sided difference, which differs between the modules meeting there), so both modules share
            # it and it does not pinch the tube
            c = path[i]
            a = math.atan2(c[1], c[0])
            k = -TAU / HERO_PITCH
            tj = vp._n(np.array([-HERO_OFFSET * math.sin(a) * k, HERO_OFFSET * math.cos(a) * k, 1.0]))
            rr = np.array([c[0], c[1], 0.0])
            r_ref = vp._n(rr - tj * (rr @ tj))
            ring = hero_ring(c, r_ref, tj, radii[i], HERO_PROFILE, np.zeros(HERO_SIDES))
            ring = [p - tj * ((p[2] - c[2]) / tj[2]) for p in ring]
        else:
            noise = 0.05 * np.sin(s_along[i] / 37.0 + phases) * (1.0 - fade)
            # rope rings take the up-pointing tangent as their normal, like the joint rings, so side k keeps its angle
            # whichever way the tube was built (Top builds upward from its joint, Mid and Flare downward)
            normal = t[i] * (1.0 if (not radial or t[i][2] >= 0.0) else -1.0)
            ring = hero_ring(path[i], ref, normal, radii[i], HERO_PROFILE, noise)
        verts += ring
    verts = np.array(verts)
    # wind every quad away from its ring centre (the frame's handedness decides the ring direction)
    probe = [verts[0], verts[1], verts[1 + HERO_SIDES], verts[HERO_SIDES]]
    normal = np.cross(probe[1] - probe[0], probe[3] - probe[0])
    outward = (np.mean(probe, axis=0) - (path[0] + path[1]) * 0.5) @ normal > 0.0
    for i in range(n - 1):
        for k in range(HERO_SIDES):
            a, b = i * HERO_SIDES + k, i * HERO_SIDES + (k + 1) % HERO_SIDES
            quads.append([a, b, b + HERO_SIDES, a + HERO_SIDES] if outward else [a, a + HERO_SIDES, b + HERO_SIDES, b])
    return verts, quads


def joint_weight(z, joints):
    """1 on a joint height, fading to 0 at HERO_FADE cm from the nearest joint."""
    d = min(abs(z - j) for j in joints) if joints else 1e9
    return 1.0 if d < 1e-6 else max(0.0, 1.0 - d / HERO_FADE)


def hero_rope_path(strand, z0, z1, phase_of, bulges=()):
    """Centre line of one strand from z0 down to z1 (rings every HERO_RING_STEP), phase_of(z) the helix phase, radii with
    optional bulges (z, amount, width) away from the joints."""
    zs = np.arange(z0, z1 - 1e-6, -HERO_RING_STEP)
    if abs(zs[-1] - z1) > 1e-6:
        zs = np.append(zs, z1)
    path = np.array([hero_centre(strand, phase_of(z), z) for z in zs])
    radii = np.full(len(zs), HERO_STRAND)
    for (bz, amt, width) in bulges:
        radii += HERO_STRAND * amt * np.exp(-((zs - bz) / width) ** 2)
    return path, radii, zs


def hero_finger(start, direction, length, r0, r1, seed, droop=(0.0, 0.0, 0.0), steps=10):
    """A tapered finger tube from start along direction (bending by droop over its length)."""
    rng = np.random.default_rng(seed)
    d = vp._n(direction)
    pts = []
    for s in range(steps + 1):
        u = s / steps
        p = start + d * length * u + np.asarray(droop, float) * (u * u) + rng.uniform(-1.5, 1.5, 3) * (u > 0)
        pts.append(p)
    pts = np.array(pts)
    radii = np.array([r0 + (r1 - r0) * (s / steps) ** 0.8 for s in range(steps + 1)])
    ref = vp._n(np.cross(d, [0.0, 0.0, 1.0])) if abs(d[2]) < 0.95 else np.array([1.0, 0.0, 0.0])
    v, q = hero_tube(pts, radii, np.zeros(len(pts)), ref, seed, radial=False)
    # close the tip, wound like the side quads
    tip = len(v)
    v = np.vstack([v, pts[-1] + d * r1])
    base = (len(pts) - 1) * HERO_SIDES
    same = q[0][1] == 1
    tris = [[base + k, base + (k + 1) % HERO_SIDES, tip] if same else [base + (k + 1) % HERO_SIDES, base + k, tip]
            for k in range(HERO_SIDES)]
    return v, q + tris


class Assembly:
    def __init__(self):
        self.verts = np.zeros((0, 3))
        self.faces = []
        self.tone = []

    def add(self, v, faces, tone=0):
        base = len(self.verts)
        self.verts = np.vstack([self.verts, v]) if len(self.verts) else np.asarray(v, float)
        self.faces += [[base + i for i in f] for f in faces]
        self.tone += [tone] * len(faces)


def build_hero(name):
    asm = Assembly()
    rng = np.random.default_rng(hash(name) % 9973)
    ucx = []
    if name.startswith("HeroRoot_Mid"):
        seed = {"A": 41, "B": 42, "C": 43}[name[-1]]
        r = np.random.default_rng(seed)
        bulges = [(-r.uniform(90, 260), r.uniform(0.08, 0.2), r.uniform(25, 45)) for _ in range(2)]
        for strand in range(2):
            path, radii, zs = hero_rope_path(strand, 0.0, -HERO_PITCH, hero_phase, bulges if strand == seed % 2 else bulges[:1])
            flags = [joint_weight(z, (0.0, -HERO_PITCH)) for z in zs]
            ref0 = hero_centre(strand, 0.0, 0.0) * np.array([1, 1, 0])
            v, q = hero_tube(path, radii, flags, ref0, seed * 10 + strand)
            asm.add(v, q)
        for z0, z1 in ((0.0, -175.0), (-175.0, -HERO_PITCH)):
            ucx.append(_cyl_hull(HERO_OFFSET + HERO_STRAND * 1.1, z0, z1))
        height = HERO_PITCH
    elif name.startswith("HeroRoot_Top"):
        top_h = 180.0
        # the rope part continues the mid helix: its bottom (z -180) is a mid top (phase 0)
        phase_of = lambda z: hero_phase(z + top_h)  # noqa: E731
        for strand in range(2):
            path, radii, zs = hero_rope_path(strand, -90.0, -top_h, phase_of)
            # above -90 the strand leans out and bends onto the ceiling as a finger
            a = phase_of(-90.0) + math.pi * strand
            out = np.array([math.cos(a), math.sin(a), 0.0])
            extra = []
            for s in range(1, 19):
                u = s / 18.0
                z = -90.0 + 90.0 * math.sin(u * math.pi * 0.5) - HERO_STRAND * 0.6 * u + 12.0 * u ** 4
                extra.append(path[0] + out * (55.0 * u * u + 18.0 * u) + np.array([0, 0, z + 90.0]))
            full = np.vstack([np.array(extra[::-1]), path])
            fr = np.concatenate([np.linspace(HERO_STRAND * 0.55, HERO_STRAND * 1.05, len(extra)), radii])
            flags = [0.0] * len(extra) + [joint_weight(z, (-top_h,)) for z in zs]
            full, fr, flags = full[::-1], fr[::-1], flags[::-1]          # tube from the joint upward
            ref0 = hero_centre(strand, 0.0, 0.0) * np.array([1, 1, 0])
            v, q = hero_tube(full, fr, flags, ref0, 300 + strand)
            asm.add(v, q)
        # the third finger, from the fused middle up onto the ceiling
        v, q = hero_finger(np.array([0.0, 0.0, -100.0]), (0.55, -0.75, 0.45), 120.0, HERO_STRAND * 0.75, 4.0, 311,
                           droop=(0.0, 0.0, 35.0))
        asm.add(v, q)
        ucx.append(_cyl_hull(HERO_OFFSET + HERO_STRAND * 1.1, -60.0, -top_h))
        ucx.append(_box_hull((-80, -80, -35), (80, 80, 0)))
        height = top_h
    else:
        flare_h = 160.0
        seed = {"A": 51, "B": 52}[name[-1]]
        r = np.random.default_rng(seed)
        for strand in range(2):
            path, radii, zs = hero_rope_path(strand, 0.0, -70.0, hero_phase)
            a = hero_phase(-70.0) + math.pi * strand
            out = np.array([math.cos(a), math.sin(a), 0.0])
            extra = []
            for s in range(1, 21):
                u = s / 20.0
                z = -70.0 - (flare_h - 70.0 - HERO_STRAND * 0.5) * math.sin(u * math.pi * 0.5)
                extra.append(np.array([path[-1][0], path[-1][1], 0.0]) + out * (r.uniform(70, 95) * u ** 1.6 + 10 * u) +
                             np.array([0, 0, z]))
            full = np.vstack([path, np.array(extra)])
            fr = np.concatenate([radii, np.linspace(HERO_STRAND * 1.08, HERO_STRAND * 0.35, len(extra))])
            flags = [joint_weight(z, (0.0,)) for z in zs] + [0.0] * len(extra)
            ref0 = hero_centre(strand, 0.0, 0.0) * np.array([1, 1, 0])
            v, q = hero_tube(full, fr, flags, ref0, 500 + seed + strand)
            asm.add(v, q)
        fingers = 3 if name[-1] == "A" else 4
        phi0 = r.uniform(0, TAU)
        for f in range(fingers):
            a = phi0 + TAU * f / fingers + r.uniform(-0.3, 0.3)
            d = np.array([math.cos(a), math.sin(a), -0.55])
            start = np.array([0.0, 0.0, -95.0])
            length = r.uniform(90.0, 130.0)
            v, q = hero_finger(start, d, length, HERO_STRAND * 0.62, 3.5, 520 + f,
                               droop=(0.0, 0.0, -(flare_h - 95.0 - length * 0.55 - 6.0)), steps=12)
            v[:, 2] = np.maximum(v[:, 2], -flare_h + 2.0)
            asm.add(v, q)
        ucx.append(_cyl_hull(HERO_OFFSET + HERO_STRAND * 1.15, 0.0, -110.0))
        ucx.append(_box_hull((-110, -110, -flare_h), (110, 110, -flare_h + 30.0)))
        height = flare_h
    obj = ec.new_object(name + "_Mars_SM", asm.verts, asm.faces, slots=("EnvBark",), recalc_normals=False)
    joints = {"Mid": (0.0, -HERO_PITCH), "Top": (-180.0,), "Fla": (0.0,)}[name.split("_")[1][:3]]
    fc.paint(obj, _hero_rgb(obj, rng), alpha=open_end_cavity(obj, axis=2, ends=joints), variation=0.02, seed=len(name),
             cavity_darken=0.45)
    for hull in ucx:
        sc.add_ucx(obj, hull)
    return obj, dict(height_cm=height, joint_sides=HERO_SIDES)


def _hero_rgb(obj, rng):
    """Bark grooves along each strand: a tone per tube side (low ridge sides dark), constant along the length, so the
    grooves follow the twist."""
    out = []
    for p in obj.data.polygons:
        k = p.index % HERO_SIDES
        low = HERO_PROFILE[k] + HERO_PROFILE[(k + 1) % HERO_SIDES] < 2.0
        out.append((BARK_DARK if low else BARK) * SIDE_TONES[k])
    return out


def _wind_outward_hero(obj):
    """Tube faces wind away from their own ring centre: the quad's normal against the ring centre of its strand is
    approximated by the face's offset from the mesh's local axis line (nearest point along the tube is unknown), so
    use bmesh recalc per connected shell instead (each tube is closed enough)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def _cyl_hull(radius, z0, z1, sides=8):
    pts = []
    for z in (z0, z1):
        for k in range(sides):
            a = TAU * k / sides
            pts.append((radius * math.cos(a), radius * math.sin(a), z))
    return pts


def _box_hull(lo, hi):
    return [(x, y, z) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]


BUILDERS = {}
for _n in ORDER:
    k = MESHES[_n]["kind"]
    BUILDERS[_n] = {"segment": build_segment, "tip": build_tip, "knot": build_knot, "leaf": build_leaves,
                    "card": build_card, "hero": build_hero}[k]


# ================================================================ checks
def ring_at_x(v, x, tol=0.01):
    return v[np.abs(v[:, 0] - x) < tol]


def sort_ring(ring):
    a = np.arctan2(ring[:, 2], ring[:, 1])
    return ring[np.argsort(a)]


def check_mesh(name, obj, info, fails):
    m = MESHES[name]
    mesh = obj.data
    out = []
    if obj.name != name + "_Mars_SM":
        out.append("object name %s" % obj.name)
    slots = tuple(mt.name for mt in mesh.materials)
    if slots != (m["slot"],) or m["slot"] not in spec.SLOTS:
        out.append("slots %s != (%s,)" % (slots, m["slot"]))
    tris = fc.tri_count(obj)
    if tris > m["cap"] or tris > spec.TRIS[m["cat"]]:
        out.append("tris %d > cap %d" % (tris, m["cap"]))
    attr = mesh.color_attributes.get("Col")
    if attr is None or attr.domain != "CORNER":
        out.append("no corner Col attribute")
    else:
        c = np.empty(len(attr.data) * 4, np.float32)
        attr.data.foreach_get("color", c)
        c = c.reshape(-1, 4)
        if not np.all(np.isfinite(c)) or c[:, 3].min() < 0.0 or c[:, 3].max() > 1.0:
            out.append("Col alpha outside 0..1")
    uvs = [u.name for u in mesh.uv_layers]
    if m["data_uv"]:
        if spec.DATA_UV not in uvs:
            out.append("no UV1 %s (%s)" % (spec.DATA_UV, uvs))
        else:
            u = np.empty(len(mesh.loops) * 2)
            mesh.uv_layers[spec.DATA_UV].data.foreach_get("uv", u)
            u = u.reshape(-1, 2)
            if u.min() < -1e-6 or u.max() > 1.0 + 1e-6:
                out.append("EnvData outside 0..1")
    v = fc.verts_cm(obj)
    lo, hi = v.min(axis=0), v.max(axis=0)
    if m["kind"] == "segment":
        if abs(lo[0]) > 0.5 or abs(hi[0] - 100.0) > 0.5:
            out.append("long axis %.2f .. %.2f, not 0 .. 100" % (lo[0], hi[0]))
        r0, r1 = sort_ring(ring_at_x(v, 0.0)), sort_ring(ring_at_x(v, 100.0))
        if len(r0) != len(r1) or len(r0) == 0 or np.abs(r0[:, 1:] - r1[:, 1:]).max() > 0.01:
            out.append("end rings differ")
        if name.startswith("VineBark") and not sc.children(obj, "UCX_"):
            out.append("bark carries no UCX hull")
    elif m["kind"] == "tip":
        if abs(lo[0]) > 0.5 or abs(hi[0] - 100.0) > 0.5:
            out.append("tip axis %.2f .. %.2f" % (lo[0], hi[0]))
    elif m["kind"] == "card":
        if abs(hi[2]) > 0.6 or abs(lo[2] + 100.0) > 3.0:
            out.append("card z %.2f .. %.2f, not 0 .. -100" % (lo[2], hi[2]))
    elif m["kind"] == "leaf":
        span = {"VineLeaves_A": 9.0, "VineLeaves_B": 14.0, "VineLeaves_C": 20.0}[name]
        if hi[0] < span * 0.7 or hi[0] > span * 1.35 or lo[0] < -span * 0.4:
            out.append("leaf span x %.1f .. %.1f for %.0f cm" % (lo[0], hi[0], span))
    elif m["kind"] == "hero":
        if abs(hi[2]) > 1.0 and not name.startswith("HeroRoot_Top"):
            out.append("hero top z %.2f, not 0" % hi[2])
        if len(sc.children(obj, "UCX_")) < 2:
            out.append("hero carries fewer than 2 UCX hulls")
    if m["kind"] in ("leaf", "card", "knot", "tip") and sc.children(obj, "UCX_"):
        out.append("scatter carries UCX")
    for o in out:
        fails.append("%s: %s" % (name, o))
    return not out


def joint_loop(obj, z, tol=0.002):
    v = fc.verts_cm(obj)
    ring = v[np.abs(v[:, 2] - z) < tol]
    return ring[np.lexsort((np.round(ring[:, 1], 2), np.round(ring[:, 0], 2)))]


def check_hero_joints(built, fails):
    """Top bottom (z -180) = Mid top (z 0) = Mid bottom (z -350, shifted) = Flare top (z 0); also under a 180 degree
    yaw flip. Max vertex delta < 0.2 cm."""
    loops = {}
    for name, (obj, info) in built.items():
        if name.startswith("HeroRoot_Mid"):
            loops[name + "@top"] = joint_loop(obj, 0.0)
            loops[name + "@bottom"] = joint_loop(obj, -HERO_PITCH) + np.array([0, 0, HERO_PITCH])
        elif name.startswith("HeroRoot_Top"):
            loops[name + "@bottom"] = joint_loop(obj, -180.0) + np.array([0, 0, 180.0])
        elif name.startswith("HeroRoot_Flare"):
            loops[name + "@top"] = joint_loop(obj, 0.0)
    if not loops:
        return {}
    ref_key = sorted(loops)[0]
    ref = loops[ref_key]
    report = {}
    flip = np.array([-1.0, -1.0, 1.0])
    for k, ring in loops.items():
        if len(ring) != len(ref) or len(ring) != 2 * HERO_SIDES:
            fails.append("hero joint %s has %d loop verts (want %d)" % (k, len(ring), 2 * HERO_SIDES))
            continue
        d = float(np.abs(ring - ref).max())
        fl = ring * flip
        fl = fl[np.lexsort((np.round(fl[:, 1], 2), np.round(fl[:, 0], 2)))]
        df = float(np.abs(fl - ref).max())
        report[k] = (round(d, 4), round(df, 4))
        if d > 0.2 or df > 0.2:
            fails.append("hero joint %s differs from %s by %.3f cm (flipped %.3f)" % (k, ref_key, d, df))
    return report


# ================================================================ review
def remove_object(o):
    data = o.data
    for ch in [c for c in bpy.data.objects if c.parent is o]:
        bpy.data.objects.remove(ch, do_unlink=True)
    bpy.data.objects.remove(o, do_unlink=True)
    if data is not None and data.users == 0 and isinstance(data, bpy.types.Mesh):
        bpy.data.meshes.remove(data)


def copy_object(obj, name, verts=None):
    c = bpy.data.objects.new(name, obj.data.copy())
    bpy.context.scene.collection.objects.link(c)
    if verts is not None:
        fc.set_verts_cm(c, verts)
    return c


def painted_box(name, center, size, rgb):
    v, f = sc.box(center, size)
    o = ec.new_object(name, v, f, slots=("EnvStone",))
    fc.paint(o, np.repeat(np.asarray(rgb, float)[None, :], len(f), axis=0), variation=0.02, cavity_darken=0.0)
    return o


def render_view(objs, path, size=(1600, 1000), target_cm=(0, 0, 0), eye_cm=(0, -300, 100), lens=35.0):
    scene = bpy.context.scene
    objs = list(objs)
    hidden = [o for o in scene.objects if o not in objs and o.type == "MESH"]
    hidden_state = [o.hide_render for o in hidden]
    cam_data = bpy.data.cameras.new("_VineCam")
    cam_data.clip_start, cam_data.clip_end = 0.02, 5000.0
    cam = bpy.data.objects.new("_VineCam", cam_data)
    scene.collection.objects.link(cam)
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    sh = scene.display.shading
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.filepath, sh.color_type, sh.light, sh.show_cavity, scene.render.film_transparent)
    try:
        for o in hidden:
            o.hide_render = True
        for o in objs:
            o.hide_render = False
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        sh.light = "STUDIO"
        sh.color_type = "VERTEX"
        sh.show_cavity = True
        sh.show_shadows = True
        scene.render.film_transparent = False
        scene.world.color = REVIEW_BG
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        cam_data.lens = lens
        fc._look_at(cam, tuple(np.asarray(eye_cm, float) * 0.01), tuple(np.asarray(target_cm, float) * 0.01))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
    finally:
        for o, hr in zip(hidden, hidden_state):
            o.hide_render = hr
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
         scene.render.filepath, sh.color_type, sh.light, sh.show_cavity, scene.render.film_transparent) = prev
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return path


def rmf(points):
    n = len(points)
    t = np.array([vp._n(points[min(i + 1, n - 1)] - points[max(i - 1, 0)]) for i in range(n)])
    r = [vp._n(np.cross(t[0], [0, 0, 1])) if abs(t[0][2]) < 0.95 else np.array([1.0, 0, 0])]
    for i in range(n - 1):
        v1 = points[i + 1] - points[i]
        c1 = v1 @ v1
        rl = r[i] - 2.0 / c1 * (v1 @ r[i]) * v1
        tl = t[i] - 2.0 / c1 * (v1 @ t[i]) * v1
        v2 = t[i + 1] - tl
        c2 = v2 @ v2
        nx = rl if c2 < 1e-9 else rl - 2.0 / c2 * (v2 @ rl) * v2
        r.append(vp._n(nx - t[i + 1] * (nx @ t[i + 1])))
    return t, np.array(r)


def deform_chain(obj, points, radii, axis_len=100.0, mesh_r=50.0, roll_step=37.0):
    """Emulate the generator's spline-mesh chain: copies of obj (x 0 .. 100) deformed onto each Hermite segment of the
    polyline, scaled by the radius (linear between the points), up = RMF right, rolls random-walking per joint."""
    t, r = rmf(points)
    v0 = fc.verts_cm(obj)
    tans = [(points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]) * (1.0 if i in (0, len(points) - 1) else 0.5)
            for i in range(len(points))]
    copies = []
    roll = [0.0]
    for i in range(len(points) - 1):
        roll.append(roll[-1] + roll_step * (1 if i % 2 else -1))
    for i in range(len(points) - 1):
        u = v0[:, 0] / axis_len
        p0, p1, m0, m1 = points[i], points[i + 1], tans[i], tans[i + 1]
        h00, h10, h01, h11 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u, -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
        c = np.outer(h00, p0) + np.outer(h10, m0) + np.outer(h01, p1) + np.outer(h11, m1)
        dc = np.outer(6 * u ** 2 - 6 * u, p0) + np.outer(3 * u ** 2 - 4 * u + 1, m0) + np.outer(-6 * u ** 2 + 6 * u, p1) + \
            np.outer(3 * u ** 2 - 2 * u, m1)
        tt = vp._n(dc)
        up = np.outer(1 - u, r[i]) + np.outer(u, r[i + 1])
        up = vp._n(up - tt * np.sum(up * tt, axis=1, keepdims=True))
        side = np.cross(tt, up)
        sc_ = (radii[i] * (1 - u) + radii[i + 1] * u) / mesh_r
        rl = np.radians(roll[i] * (1 - u) + roll[i + 1] * u)
        y, z = v0[:, 1], v0[:, 2]
        yr, zr = y * np.cos(rl) - z * np.sin(rl), y * np.sin(rl) + z * np.cos(rl)
        pos = c + side * (yr * sc_)[:, None] + up * (zr * sc_)[:, None]
        copies.append(copy_object(obj, "_Sweep_%s_%d" % (obj.name, i), pos))
    return copies


def place_copy(obj, name, offset=(0, 0, 0), yaw=0.0, scale=(1, 1, 1), rot=None):
    v = fc.verts_cm(obj) * np.asarray(scale, float)
    if rot is not None:
        v = v @ np.asarray(rot, float).T
    a = math.radians(yaw)
    rz = np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])
    return copy_object(obj, name, v @ rz.T + np.asarray(offset, float))


def render_sheets(built):
    rd = spec.REVIEW_DIR
    sheets = []
    groups = (("vines_bark", ("VineBark_A", "VineBark_B", "VineStemIvy", "VineTip", "VineKnot_A", "VineKnot_B")),
              ("vines_leaves", ("VineLeaves_A", "VineLeaves_B", "VineLeaves_C")),
              ("vines_cards", ("VineMossStrand_A", "VineMossStrand_B", "VineMossStrand_C", "VineRootlet_A",
                               "VineRootlet_B", "VineCobweb_A")),
              ("vines_hero", ("HeroRoot_Top_A", "HeroRoot_Mid_A", "HeroRoot_Mid_B", "HeroRoot_Mid_C",
                              "HeroRoot_Flare_A", "HeroRoot_Flare_B")))
    for stem, names in groups:
        objs = [built[n][0] for n in names if n in built]
        if not objs:
            continue
        copies = [copy_object(o, o.name.replace("_Mars_SM", "") + "_Review") for o in objs]
        sheets.append(ec.review(copies, stem, views=("iso", "front")))
        for c in copies:
            remove_object(c)
    # the line-up with a 1 m bar
    small = [n for n in ORDER if n in built and MESHES[n]["kind"] != "hero"]
    if small:
        tmp, x = [], 0.0
        for n in small:
            o = built[n][0]
            v = fc.verts_cm(o)
            lo, hi = v.min(axis=0), v.max(axis=0)
            tmp.append(place_copy(o, "_Line_" + n, offset=(x - lo[0], 0.0, -lo[2] if MESHES[n]["kind"] != "card" else 110.0)))
            x += (hi[0] - lo[0]) + 25.0
        bar = painted_box("_Bar", (50.0, 30.0, -2.0), (100.0, 4.0, 4.0), fc.srgb(230, 230, 230))
        tmp.append(bar)
        sheets.append(render_view(tmp, os.path.join(rd, "vines_lineup.png"), size=(2400, 900),
                                  target_cm=(x * 0.5, 0.0, 55.0), eye_cm=(x * 0.5, -x * 0.9, 120.0), lens=50.0))
        for o in tmp:
            remove_object(o)
    sheets += render_sweep(built)
    return sheets


def render_sweep(built):
    """A mock room: a root dropped and laid in segments (A/B alternating, tapering 35 -> 8 cm), an ivy curtain stem with
    leaf clusters, moss strands stretched to 40 - 260 cm, and a stacked hero root (Top + 2 Mid + Flare)."""
    rd = spec.REVIEW_DIR
    out = []
    tmp = [painted_box("_Floor", (0.0, 0.0, -2.0), (1400.0, 900.0, 4.0), fc.srgb(92, 88, 84)),
           painted_box("_Ceiling", (0.0, 0.0, 1062.0), (1400.0, 900.0, 24.0), fc.srgb(110, 104, 98)),
           painted_box("_Wall", (0.0, 300.0, 525.0), (1400.0, 40.0, 1050.0), fc.srgb(118, 112, 106)),
           painted_box("_Ledge", (300.0, 230.0, 690.0), (420.0, 120.0, 40.0), fc.srgb(128, 122, 114))]
    if "VineBark_A" in built and "VineBark_B" in built:
        pts, radii = [], []
        for i in range(15):
            z = 1050.0 - i * 75.0
            if z < 60.0:
                break
            pts.append(np.array([-380.0 + 30.0 * math.sin(i * 0.7), 40.0 * math.cos(i * 0.5), z]))
        pts += [np.array([-330.0, 40.0, 30.0]), np.array([-260.0, 60.0, 14.0]), np.array([-180.0, 70.0, 8.0])]
        pts = np.array(pts)
        radii = np.linspace(36.0, 7.0, len(pts)) ** 1.0
        for i in range(len(pts) - 1):
            src = built["VineBark_A" if i % 2 == 0 else "VineBark_B"][0]
            tmp += deform_chain(src, pts[i:i + 2], radii[i:i + 2])
        if "VineKnot_A" in built:
            tmp.append(place_copy(built["VineKnot_A"][0], "_KnotA", offset=pts[4] + np.array([22, 0, 0]), scale=(0.3, 0.3, 0.3),
                                  rot=[[0, 0, 1], [0, 1, 0], [-1, 0, 0]]))
    if "VineStemIvy" in built:
        pts = [np.array([300.0 + 20.0 * k, 170.0, 712.0]) for k in range(2)]
        pts += [np.array([340.0, 168.0, 712.0 - 40.0 * k + 0.0]) for k in range(1, 2)]
        pts = [np.array([280.0, 210.0, 712.0]), np.array([300.0, 172.0, 712.0]), np.array([304.0, 168.0, 690.0]),
               np.array([306.0, 166.0, 668.0])]
        for k in range(1, 40):
            pts.append(np.array([306.0 + 6.0 * math.sin(k * 0.3), 166.0 - k * 0.6, 668.0 - k * 12.0]))
        pts = np.array(pts)
        tmp += deform_chain(built["VineStemIvy"][0], pts, np.full(len(pts), 1.2), roll_step=10.0)
        rng = np.random.default_rng(3)
        names = [n for n in ("VineLeaves_A", "VineLeaves_B", "VineLeaves_C") if n in built]
        for k in range(3, len(pts), 1):
            if names:
                n = names[rng.integers(0, len(names))]
                yaw = rng.uniform(-110, -70)
                tilt = [[1, 0, 0], [0, 0, -1], [0, 1, 0]]
                tmp.append(place_copy(built[n][0], "_Leaf_%d" % k, offset=pts[k] + np.array([rng.uniform(-3, 3), -2, 0]),
                                      yaw=yaw, rot=tilt))
    for i, n in enumerate([n for n in ("VineMossStrand_A", "VineMossStrand_B", "VineMossStrand_C") if n in built] * 4):
        L = 40.0 + 220.0 * ((i * 37) % 11) / 10.0
        tmp.append(place_copy(built[n][0], "_Moss_%d" % i, offset=(120.0 + i * 14.0, -100.0 + (i % 3) * 18.0, 1050.0),
                              yaw=i * 47.0, scale=(1.0, 1.0, L / 100.0)))
    stack = [n for n in ("HeroRoot_Top_A", "HeroRoot_Mid_A", "HeroRoot_Mid_B", "HeroRoot_Flare_A") if n in built]
    if len(stack) == 4:
        # 1050 = 180 + 2 x 350 x zscale + 160 -> zscale 1.0143
        zs = (1050.0 - 180.0 - 160.0) / (2 * HERO_PITCH)
        z = 1050.0
        tmp.append(place_copy(built[stack[0]][0], "_HeroTop", offset=(560.0, 0.0, z)))
        z -= 180.0
        for j, n in enumerate(stack[1:3]):
            tmp.append(place_copy(built[n][0], "_HeroMid%d" % j, offset=(560.0, 0.0, z), yaw=180.0 * j, scale=(1, 1, zs)))
            z -= HERO_PITCH * zs
        tmp.append(place_copy(built[stack[3]][0], "_HeroFlare", offset=(560.0, 0.0, z)))
    out.append(render_view(tmp, os.path.join(rd, "vines_sweep_room.png"), size=(1800, 1400), target_cm=(80.0, 100.0, 520.0),
                           eye_cm=(60.0, -1500.0, 600.0), lens=24.0))
    out.append(render_view(tmp, os.path.join(rd, "vines_sweep_root.png"), size=(1400, 1400), target_cm=(-340.0, 40.0, 300.0),
                           eye_cm=(-150.0, -380.0, 220.0), lens=24.0))
    out.append(render_view(tmp, os.path.join(rd, "vines_sweep_hero.png"), size=(1200, 1600), target_cm=(560.0, 0.0, 520.0),
                           eye_cm=(700.0, -900.0, 420.0), lens=28.0))
    out.append(render_view(tmp, os.path.join(rd, "vines_sweep_joint.png"), size=(1200, 1200), target_cm=(560.0, 0.0, 870.0),
                           eye_cm=(640.0, -220.0, 900.0), lens=35.0))
    out.append(render_view(tmp, os.path.join(rd, "vines_sweep_ivy.png"), size=(1200, 1400), target_cm=(305.0, 166.0, 560.0),
                           eye_cm=(420.0, -60.0, 600.0), lens=35.0))
    for o in tmp:
        remove_object(o)
    return out


# ================================================================ main
def sidecar_extra(name, info):
    m = MESHES[name]
    pivots = {"segment": "x 0 start, +X along the vine (100 cm), radius 50; open ends, shared end ring",
              "tip": "base ring at x 0 (radius 50), +X to the point",
              "knot": "centre; flat side toward -Z (onto the root)",
              "leaf": "petiole base at the origin; leaves fan to +X, faces +Z",
              "card": "top at the origin; hangs to z -100 (the generator scales z to the traced length)",
              "hero": "top centre (ceiling contact / joint), hangs -Z"}
    extra = dict(category=m["cat"], tris_budget=m["cap"], pivot=pivots[m["kind"]], builder="build_env_vines.py",
                 ucx="UCX hulls" if m["kind"] in ("hero",) or name.startswith("VineBark") else "none")
    if m["data_uv"]:
        extra["data_uv"] = "EnvData: u = id, v = 0 at the attachment .. 1 at the free end"
    extra.update(info)
    return extra


def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False, "only": ""})
    t0 = time.time()
    fc.ensure_dirs()
    fc.clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    only = [n for n in ORDER if not args["only"] or any(p.strip() and p.strip() in n for p in str(args["only"]).split(","))]
    if not only:
        raise SystemExit("--only matched nothing in %s" % (ORDER,))
    fails, built, exported, table = [], {}, {}, []
    for name in only:
        t1 = time.time()
        obj, info = BUILDERS[name](name)
        if not obj.data.uv_layers.get("UVMap"):
            fc.smart_uv(obj)
        built[name] = (obj, info)
        ok = check_mesh(name, obj, info, fails)
        print("  built %s: %d tris in %.1fs" % (name, fc.tri_count(obj), time.time() - t1))
        if args["export"] and ok:
            exported[name] = ec.export(obj, FAMILY, extra=sidecar_extra(name, info))
        elif args["export"]:
            print("  NOT exported (checks failed): %s" % name)
    joints = check_hero_joints(built, fails)
    if joints:
        print("hero joints (max delta, flipped):", joints)
    sheets = render_sheets(built) if args["sheets"] else []
    if args["save"]:
        ec.save_family_blend(FAMILY)
        print("saved", os.path.join(spec.BLEND_DIR, spec.FAMILIES[FAMILY][1]))
    for name, path in exported.items():
        with open(os.path.splitext(path)[0] + ".json") as fh:
            meta = json.load(fh)
        table.append((name + "_Mars_SM", meta["tris"], [round(x, 1) for x in np.subtract(meta["bounds_max_cm"], meta["bounds_min_cm"])],
                      meta["slots"], meta.get("ucx_pieces", 0)))
    print("\nTABLE name | tris | size cm (x y z) | slots | ucx")
    for row in table:
        print("TABLE %s | %d | %s | %s | %d" % row)
    print("\nsheets:", *sheets, sep="\n  ")
    print("total %.1fs" % (time.time() - t0))
    if fails:
        print("ENV_VINES_FAIL", *fails, sep="\n  ")
    elif len(only) != len(ORDER):
        print("ENV_VINES_PARTIAL (only %s)" % ",".join(only))
    else:
        print("ENV_VINES_OK")


if __name__ == "__main__":
    main()
