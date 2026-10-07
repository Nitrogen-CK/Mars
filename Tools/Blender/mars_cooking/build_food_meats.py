"""Builds the MEATS of the Mars food library (food_spec category "meats"): RoastHorned, Drumstick, Tentacle.

    blender -b --factory-startup --python build_food_meats.py -- [--export] [--save] [--sheets] [--only A,B]
                                                                  [--review_dir <dir>] [--nobake]

  --export      <Name>_Mars_SM.fbx + .json sidecar + <Name>_Mask_Mars_T.png (1024 RGBA) in food_spec.EXPORT_DIR, then
                a fresh --factory-startup Blender re-imports every FBX (food_common.reimport_check) and prints it.
  --save        writes food_spec.BLEND_DIR/Food_Meats.blend (the only .blend this builder writes; refused with --only).
  --sheets      RAW | COOKED review sheets (iso / front / top, vertex colours) in food_spec.REVIEW_DIR
                (or --review_dir <dir> for iteration renders).
  --only        comma list of asset names to build.
  --nobake      skip the mask bake on --export (fast iteration only).

Style (food_spec ruling): faceted low-poly, every face flat, 600..2500 tris, hand-cut irregular facets, horns and bone
as real geometry. Geometry is procedural numpy / bmesh with fixed seeds, so a re-run reproduces every mesh exactly:

  RoastHorned  blue-noise points on the unit sphere -> convex hull (irregular triangles) -> mapped onto a plump oval
               joint (+X front, flatter underneath) with crust lumps; a few "pulled skin" patches are flattened and
               dissolved into big facets. Six banded horns (7-sided swept tubes, slot Horn) with deep roots.
  Drumstick    the same hull technique for the teardrop of meat (+X) with a pale cut cap at the neck; an 8-sided bone
               shaft and a two-lobed knuckle (slot Bone) toward -X; tilted so meat and knuckle both rest on the counter.
  Tentacle     every vertex is (q along the spine, angle, radial offset): a turtle-integrated spine (lazy S on the
               counter, the thin tip curling up at +X), a 10-sided tapering tube, an oblique cut face at -X and
               lathed sucker cups wrapped onto the oral side. The cooked shape re-evaluates the same parameters on
               a tighter, 8 % shorter spine.

Morph (UV1 / UV2 via food_common.write_morph_uvs): cooked = shrink + sag + crust bulge on the cooking slot; Horn and
Bone vertices have offset 0 (the meat shrinks away from them). Prints FOOD_MEATS_OK when every mechanical check passes.
"""
import json
import math
import os
import subprocess
import sys
import time

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import food_common as fc  # noqa: E402

spec = fc.spec
NAMES = ("RoastHorned", "Drumstick", "Tentacle")
BLEND_PATH = os.path.join(spec.BLEND_DIR, spec.CATEGORIES["meats"][0])
UP = np.array([0.0, 0.0, 1.0])
TRI_RANGE = (600, 2500)
MORPH_RANGE_CM = (1.0, 4.0)

# extra camera directions for iteration sheets (local to this process)
fc.VIEWS.setdefault("iso_back", (-1.0, 1.0, 0.75))
fc.VIEWS.setdefault("low", (1.0, -0.55, 0.28))
fc.VIEWS.setdefault("back", (-1.0, 0.3, 0.45))


# ================================================================ small maths
def unit(v):
    v = np.asarray(v, float)
    return v / (np.linalg.norm(v, axis=-1, keepdims=True) + 1e-12)


def col(r, g, b):
    return fc.srgb(r, g, b)


def lerp(a, b, t):
    t = np.asarray(t, float)
    if t.ndim:
        t = t[..., None]
    return a * (1.0 - t) + b * t


def slerp(a, b, t):
    a, b = unit(a), unit(b)
    om = math.acos(float(np.clip(a @ b, -1.0, 1.0)))
    t = np.asarray(t, float)[:, None]
    if om < 1e-5:
        return np.repeat(a[None], len(t), 0)
    return (np.sin((1.0 - t) * om) * a + np.sin(t * om) * b) / math.sin(om)


def rotate(v, axis, ang):
    """Rodrigues rotation of points v (n, 3) about a unit axis through the origin."""
    k = unit(axis)
    c, s = math.cos(ang), math.sin(ang)
    v = np.atleast_2d(v)
    return v * c + np.cross(k, v) * s + np.outer(v @ k, k) * (1.0 - c)


def tangent_basis(d):
    a = np.where(np.abs(d[:, :1]) < 0.9, np.array([[1.0, 0.0, 0.0]]), np.array([[0.0, 1.0, 0.0]]))
    t1 = unit(np.cross(d, a))
    return t1, np.cross(d, t1)


def transport_frames(P, n0):
    """Rotation-minimising frames along a polyline P (n, 3): T, N, B. N starts as n0 made perpendicular."""
    P = np.asarray(P, float)
    T = unit(np.gradient(P, axis=0))
    N = np.zeros_like(P)
    n = np.asarray(n0, float)
    N[0] = unit(n - (n @ T[0]) * T[0])
    for i in range(1, len(P)):
        axis = np.cross(T[i - 1], T[i])
        s = np.linalg.norm(axis)
        nn = N[i - 1]
        if s > 1e-10:
            nn = rotate(nn, axis / s, math.atan2(s, float(T[i - 1] @ T[i])))[0]
        N[i] = unit(nn - (nn @ T[i]) * T[i])
    return T, N, np.cross(T, N)


def surface_normal(map_fn, d, eps=2e-3):
    """Outward normal of the surface map_fn(unit sphere) at directions d (orientation-preserving maps)."""
    d = unit(np.atleast_2d(d))
    t1, t2 = tangent_basis(d)
    du = map_fn(unit(d + eps * t1)) - map_fn(unit(d - eps * t1))
    dv = map_fn(unit(d + eps * t2)) - map_fn(unit(d - eps * t2))
    return unit(np.cross(du, dv))


def sph(theta_deg, phi_deg):
    """Unit direction from the polar angle off +X and the azimuth around X (0 = +Y, 90 = +Z)."""
    th, ph = math.radians(theta_deg), math.radians(phi_deg)
    return np.array([math.cos(th), math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph)])


def polar_x(d):
    """(cos theta, sin theta, cos phi, sin phi) of unit directions d about the X axis."""
    cx = np.clip(d[:, 0], -1.0, 1.0)
    s = np.sqrt(np.maximum(1.0 - cx * cx, 0.0))
    r = np.hypot(d[:, 1], d[:, 2])
    safe = np.maximum(r, 1e-12)
    cphi = np.where(r > 1e-12, d[:, 1] / safe, 1.0)
    sphi = np.where(r > 1e-12, d[:, 2] / safe, 0.0)
    return cx, s, cphi, sphi


# ================================================================ point sets and topology
def _dart(pos, sp, fpos, fsp):
    """Greedy dart throwing: keep a candidate when it is >= mean spacing from every kept point."""
    cell = float(max(sp.max(), fsp.max() if len(fsp) else 0.0))
    grid = {}
    keys = np.floor(pos / cell).astype(np.int64)

    def add(key, p, s):
        grid.setdefault(key, []).append((p, s))

    for p, s in zip(fpos, fsp):
        k = np.floor(p / cell).astype(np.int64)
        add((int(k[0]), int(k[1]), int(k[2])), p, s)
    chosen = []
    offs = [(a, b, c) for a in (-1, 0, 1) for b in (-1, 0, 1) for c in (-1, 0, 1)]
    for i in range(len(pos)):
        p, s = pos[i], sp[i]
        kx, ky, kz = int(keys[i, 0]), int(keys[i, 1]), int(keys[i, 2])
        ok = True
        for a, b, c in offs:
            for q, t in grid.get((kx + a, ky + b, kz + c), ()):
                d = q - p
                lim = 0.5 * (s + t)
                if d @ d < lim * lim:
                    ok = False
                    break
            if not ok:
                break
        if ok:
            add((kx, ky, kz), p, s)
            chosen.append(i)
    return np.array(chosen, dtype=np.int64)


def blue_noise_dirs(map_fn, spacing_fn, n_target, seed, fixed=None, n_cand=36000, fixed_spacing=None, reject=None):
    """Unit-sphere directions whose images under map_fn are spread like blue noise with the local spacing
    spacing_fn(pos) (cm), about n_target of them (plus the fixed directions, kept first; they keep candidates
    fixed_spacing cm away when given). reject(pos) -> bool mask drops candidates outright."""
    rng = np.random.default_rng(seed)
    cand = unit(rng.normal(size=(n_cand, 3)))
    if reject is not None:
        cand = cand[~reject(map_fn(cand))]
    pos = map_fn(cand)
    t1, t2 = tangent_basis(cand)
    eps = 1e-3
    area = np.linalg.norm(np.cross(map_fn(unit(cand + eps * t1)) - pos,
                                   map_fn(unit(cand + eps * t2)) - pos), axis=1) / eps ** 2
    sp = spacing_fn(pos)
    w = area / sp ** 2
    keep = rng.random(len(cand)) < w / w.max()
    cand, pos, sp = cand[keep], pos[keep], sp[keep]
    fixed = np.zeros((0, 3)) if fixed is None else unit(np.asarray(fixed, float))
    fpos = map_fn(fixed) if len(fixed) else np.zeros((0, 3))
    if not len(fixed):
        fsp = np.zeros(0)
    elif fixed_spacing is not None:
        fsp = np.full(len(fixed), float(fixed_spacing))
    else:
        fsp = spacing_fn(fpos)
    scale, best = 1.0, None
    for _ in range(12):
        idx = _dart(pos, sp * scale, fpos, fsp * scale)
        if best is None or abs(len(idx) - n_target) < abs(len(best) - n_target):
            best = idx
        if abs(len(idx) - n_target) <= 0.015 * n_target:
            break
        scale *= (len(idx) / n_target) ** 0.5
    return np.concatenate([fixed, cand[best]])


def hull_faces(dirs):
    """Triangles of the convex hull of unit directions (outward winding); every direction becomes a vertex.
    The connectivity is then re-made Delaunay in the final shape by delaunay_flips."""
    bm = bmesh.new()
    for d in dirs:
        bm.verts.new(d)
    bm.verts.index_update()
    bmesh.ops.convex_hull(bm, input=list(bm.verts), use_existing_faces=False)
    bm.verts.index_update()
    faces = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()
    used = {i for f in faces for i in f}
    if len(used) != len(dirs):
        raise RuntimeError("hull dropped %d points" % (len(dirs) - len(used)))
    return faces


def _angle(u, v):
    return math.atan2(np.linalg.norm(np.cross(u, v)), float(u @ v))


def delaunay_flips(P, faces, locked=(), max_pass=80, fold_cos=0.6):
    """Lawson flips on a closed triangle mesh in its FINAL 3D positions: flip an edge when the two angles opposite it
    sum past pi (Delaunay criterion) unless the flip would fold the surface or the edge is locked. A convex hull is
    only Delaunay for points on a sphere; on a near-cylindrical body it leaves slivers along the long axis."""
    P = np.asarray(P, float)
    faces = [list(f) for f in faces]
    locked = {(min(a, b), max(a, b)) for a, b in locked}
    total = 0
    for _ in range(max_pass):
        edge_map = {}
        for fi, f in enumerate(faces):
            for k in range(3):
                a, b = f[k], f[(k + 1) % 3]
                edge_map.setdefault((min(a, b), max(a, b)), []).append(fi)
        touched, flips = set(), 0
        for (a, b), fl in edge_map.items():
            if len(fl) != 2 or (a, b) in locked or fl[0] in touched or fl[1] in touched:
                continue
            f1, f2 = fl
            c = next(v for v in faces[f1] if v != a and v != b)
            d = next(v for v in faces[f2] if v != a and v != b)
            if (min(c, d), max(c, d)) in edge_map:
                continue
            if _angle(P[a] - P[c], P[b] - P[c]) + _angle(P[a] - P[d], P[b] - P[d]) <= math.pi + 1e-9:
                continue
            i = faces[f1].index(a)
            if faces[f1][(i + 1) % 3] != b:                    # make f1 run a -> b
                a, b = b, a
            n1, n2 = np.cross(P[d] - P[a], P[c] - P[a]), np.cross(P[b] - P[d], P[c] - P[d])
            o1, o2 = np.cross(P[b] - P[a], P[c] - P[a]), np.cross(P[a] - P[b], P[d] - P[b])
            nn = unit(o1) + unit(o2)
            if min(unit(n1) @ unit(nn), unit(n2) @ unit(nn)) < fold_cos:
                continue
            faces[f1], faces[f2] = [a, d, c], [d, b, c]
            touched.update((f1, f2))
            flips += 1
        total += flips
        if not flips:
            break
    return faces, total


def bm_build(verts, faces, slots=None, vattrs=None):
    bm = bmesh.new()
    layers = {name: bm.verts.layers.float.new(name) for name in (vattrs or {})}   # layers first: adding one
    vs = [bm.verts.new(p) for p in np.asarray(verts, float)]                     # later invalidates BMVerts
    for name, arr in (vattrs or {}).items():
        lay = layers[name]
        for v, a in zip(vs, arr):
            v[lay] = float(a)
    for i, f in enumerate(faces):
        face = bm.faces.new([vs[j] for j in f])
        face.material_index = int(slots[i]) if slots is not None else 0
    return bm, layers


def bm_extract(bm, layers):
    bm.verts.index_update()
    bm.faces.index_update()
    verts = np.array([v.co[:] for v in bm.verts], float)
    faces = [[v.index for v in f.verts] for f in bm.faces]
    slots = [f.material_index for f in bm.faces]
    vattrs = {n: np.array([v[l] for v in bm.verts], float) for n, l in layers.items()}
    return verts, faces, slots, vattrs


def tidy(verts, faces, slots, vattrs=None, dissolve_deg=0.0, dissolve_slot=0):
    """bmesh pass: consistent outward normals, then (optionally) dissolve near-coplanar faces of one slot into
    big hand-cut facets. Vertex attributes ride along in float layers."""
    bm, layers = bm_build(verts, faces, slots, vattrs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if dissolve_deg > 0.0:
        edges = [e for e in bm.edges if len(e.link_faces) == 2
                 and all(f.material_index == dissolve_slot for f in e.link_faces)]
        vs = [v for v in bm.verts if v.link_faces and all(f.material_index == dissolve_slot for f in v.link_faces)]
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(dissolve_deg), use_dissolve_boundaries=False,
                                 verts=vs, edges=edges, delimit={"MATERIAL"})
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
    out = bm_extract(bm, layers)
    bm.free()
    return out


def face_geo(verts, faces):
    """Face centres (cm), unit normals (Newell) and areas (cm^2) for n-gons."""
    c = np.array([verts[f].mean(axis=0) for f in faces])
    n = np.zeros((len(faces), 3))
    for i, f in enumerate(faces):
        p = verts[f]
        q = np.roll(p, -1, axis=0)
        n[i] = (np.sum((p[:, 1] - q[:, 1]) * (p[:, 2] + q[:, 2])),
                np.sum((p[:, 2] - q[:, 2]) * (p[:, 0] + q[:, 0])),
                np.sum((p[:, 0] - q[:, 0]) * (p[:, 1] + q[:, 1])))
    area = np.linalg.norm(n, axis=1) * 0.5
    return c, unit(n), area


def face_mean(faces, values):
    return np.array([np.asarray(values)[f].mean(axis=0) for f in faces])


def sweep(centres, ra, rb, sides, n0, twist=0.0, jitter=0.0, seed=0, cap_start=True, tip=None, cap_end=False,
          phase=0.0):
    """Capped tube through ring centres with elliptical sections (ra along N, rb along B of a transported frame).
    tip = a point closing the far end as a cone. Returns verts, faces, ring index per vertex."""
    rng = np.random.default_rng(seed)
    P = np.asarray(centres, float)
    T, N, B = transport_frames(P, n0)
    verts, faces, ring_of = [], [], []
    for i in range(len(P)):
        a = phase + twist * i + np.arange(sides) * math.tau / sides
        if jitter > 0.0:
            a = a + rng.uniform(-0.09, 0.09, sides)
        j = 1.0 + (rng.uniform(-jitter, jitter, sides) if jitter > 0.0 else 0.0)
        ring = P[i] + np.outer(np.cos(a) * ra[i] * j, N[i]) + np.outer(np.sin(a) * rb[i] * j, B[i])
        verts.extend(ring)
        ring_of.extend([i] * sides)
    for i in range(len(P) - 1):
        a0, b0 = i * sides, (i + 1) * sides
        for s in range(sides):
            s2 = (s + 1) % sides
            faces.append([a0 + s, a0 + s2, b0 + s2, b0 + s])
    if cap_start:
        faces.append(list(range(sides - 1, -1, -1)))
    last = (len(P) - 1) * sides
    if tip is not None:
        t = len(verts)
        verts.append(np.asarray(tip, float))
        ring_of.append(len(P))
        for s in range(sides):
            faces.append([last + s, last + (s + 1) % sides, t])
    elif cap_end:
        faces.append(list(range(last, last + sides)))
    return np.array(verts), faces, np.array(ring_of, float)


def paint_object(obj, face_rgb, seed, value=0.07, hue=0.035, cavity_darken=0.32):
    """Per-facet jitter of my own (one value per n-gon facet, so a dissolved facet stays one colour), then
    food_common.paint without its own variation; triangulating afterwards keeps the corner colours."""
    rng = np.random.default_rng(seed)
    v = 1.0 + rng.uniform(-value, value, len(face_rgb))
    h = rng.uniform(-hue, hue, len(face_rgb))
    rgb = np.asarray(face_rgb, float) * v[:, None] * np.stack([1.0 + h, np.ones_like(h), 1.0 - h], axis=1)
    fc.paint(obj, rgb, variation=0.0, cavity_darken=cavity_darken)


def finish_object(obj):
    """Triangulate (what the FBX carries anyway, so the review shows the exported facets) and keep Col active."""
    fc.triangulate_object(obj)
    mesh = obj.data
    attr = mesh.color_attributes.get(spec.COLOR_ATTR)
    idx = list(mesh.color_attributes).index(attr)
    mesh.color_attributes.active_color_index = idx
    mesh.color_attributes.render_color_index = idx
    mesh.update()


def floor_fix(raw, cooked, mask, band_cm=3.0):
    """Cooked verts in mask: move the bottom band so the cooked lowest point lands on the raw floor (a sag)."""
    lo_raw = raw[:, 2].min()
    lo_ck = cooked[mask, 2].min()
    w = 1.0 - fc.smoothstep(0.0, band_cm, raw[:, 2] - lo_raw)
    out = cooked.copy()
    out[mask, 2] -= (lo_ck - lo_raw) * w[mask]
    return out


def rest_shift(raw):
    """Translation that centres XY and puts the lowest point at z = 0 (spec pivot rule)."""
    lo, hi = raw.min(axis=0), raw.max(axis=0)
    return -np.array([(lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, lo[2]])


def vertex_normals(verts, faces):
    _, n, a = face_geo(verts, faces)
    vn = np.zeros_like(verts)
    for f, nn, aa in zip(faces, n, a):
        vn[f] += nn * aa
    return unit(vn)


def pick_accents(n, seed, dark_p, light_p):
    """Per-facet accent masks (dark crust facets, light highlight facets) for the painterly faceted read."""
    rng = np.random.default_rng(seed)
    r = rng.random(n)
    return r < dark_p, (r >= dark_p) & (r < dark_p + light_p), rng.uniform(0.0, 1.0, n)


# ================================================================ RoastHorned
ROAST_HALF = (12.3, 11.9)      # body half length toward +X (front) and -X (back), cm
ROAST_W, ROAST_H = 7.9, 6.6    # body half width / half height at the middle
# at = (theta deg off +X, phi deg around X from +Y toward +Z) on the body; d0 = how the horn leaves the meat (blended
# with the surface normal), d1 = where the tip points: the tangent slerps d0 -> d1, so each horn is a crescent.
ROAST_HORNS = (
    dict(at=(150, 82), length=10.5, r0=2.7, d0=(-0.62, 0.05, 0.78), d1=(0.55, 0.0, 0.84), seed=1),   # back top
    dict(at=(126, 30), length=9.2, r0=2.45, d0=(-0.35, 0.75, 0.55), d1=(0.55, 0.35, 0.76), seed=2),  # back left
    dict(at=(121, 152), length=9.6, r0=2.5, d0=(-0.30, -0.78, 0.55), d1=(0.5, -0.4, 0.77), seed=3),  # back right
    dict(at=(14, 64), length=7.4, r0=1.9, d0=(0.9, -0.05, 0.42), d1=(0.15, 0.05, 0.99), seed=4),     # front spike
    dict(at=(84, 98), length=5.2, r0=1.35, d0=(0.0, -0.1, 1.0), d1=(-0.65, -0.15, 0.75), seed=5),    # mid back
    dict(at=(57, -4), length=4.4, r0=1.15, d0=(0.15, 0.95, 0.2), d1=(0.7, 0.55, 0.45), seed=6),      # side spike
)
# "pulled skin": (theta, phi, angular radius deg, outline points, seed). Each becomes one big flat polygonal facet
# (outline ring + centre flattened onto a plane, dissolved) bordered by a shallow crease ring.
ROAST_PATCHES = ((62, 60, 21, 7, 1), (80, 145, 18, 7, 2), (40, 130, 17, 6, 3), (102, 72, 14, 6, 4))


def roast_base(d):
    cx, s, cphi, sphi = polar_x(unit(d))
    x = np.where(cx >= 0.0, ROAST_HALF[0] * cx, ROAST_HALF[1] * cx)
    u = x / 12.0
    rho = np.power(s, 0.66)                                   # plump, blunt ends
    waist = 1.0 - 0.08 * np.exp(-((x - 4.5) / 3.2) ** 2)     # a soft waist before the front end
    W = ROAST_W * (1.0 - 0.10 * u) * waist                    # fuller toward the back
    H = ROAST_H * (1.0 - 0.16 * u) * waist
    sz = np.where(sphi < 0.0, sphi * 0.66, sphi)              # flatter underneath
    y = W * rho * cphi + 0.8 * u * u - 0.35 * u               # a slight banana
    z = H * rho * sz + 1.1 * np.exp(-((x + 3.5) / 5.5) ** 2) * np.clip(sphi, 0.0, 1.0) * rho   # rump at the back
    z = z + 0.7 * fc.smoothstep(5.0, 12.0, x) * (0.6 + 0.4 * sphi)                          # front end turns up
    return np.stack([x, y, z], axis=1)


def roast_surface(d):
    p = roast_base(d)
    n = unit(np.stack([p[:, 0] / ROAST_HALF[0] ** 2, p[:, 1] / ROAST_W ** 2, p[:, 2] / ROAST_H ** 2], axis=1))
    bump = 0.5 * fc.lumps(p, 21, 0.2) + 0.22 * fc.lumps(p, 22, 0.55)
    return p + n * bump[:, None]


def patch_rings(th, ph, ang_deg, m, seed):
    """Outline ring (on the facet), crease ring (just outside) and centre directions of one pulled-skin patch."""
    rng = np.random.default_rng(500 + seed)
    dp = sph(th, ph)
    e1 = unit(np.cross(dp, UP if abs(dp[2]) < 0.9 else np.array([1.0, 0.0, 0.0])))
    e2 = np.cross(dp, e1)
    psi = np.arange(m) * math.tau / m + rng.uniform(-0.25, 0.25, m) * math.tau / m
    a = math.radians(ang_deg) * (1.0 + rng.uniform(-0.18, 0.18, m))
    ring_a = np.cos(a)[:, None] * dp + np.sin(a)[:, None] * (np.outer(np.cos(psi), e1) + np.outer(np.sin(psi), e2))
    psi_b = psi + math.pi / m
    b = a * 1.22
    ring_b = np.cos(b)[:, None] * dp + np.sin(b)[:, None] * (np.outer(np.cos(psi_b), e1) + np.outer(np.sin(psi_b), e2))
    return unit(ring_a), unit(ring_b), dp


def patch_index(rings, start):
    """Vertex indices (outline, crease, centre) of each patch whose fixed directions start at `start`, and the
    outline / spoke edges that must survive the Delaunay flips so each patch stays one flat facet."""
    out, locks, k = [], [], start
    for ra, rb, _ in rings:
        ia = np.arange(k, k + len(ra))
        ib = np.arange(k + len(ra), k + len(ra) + len(rb))
        ic = k + len(ra) + len(rb)
        k = ic + 1
        out.append((ia, ib, ic))
        locks += [(int(ia[i]), int(ia[(i + 1) % len(ia)])) for i in range(len(ia))] + [(int(i), ic) for i in ia]
    return out, locks


def horn_tube(base, normal, h, sides=7, depth=4.5):
    """A crescent horn: a swept 7-sided tube whose tangent slerps from d0 to d1, a flared sheath collar where it
    leaves the meat, one or two subtle layer ledges, a pointed tip, and a root sunk `depth` cm into the body."""
    d0 = unit(0.45 * normal + 0.55 * unit(np.asarray(h["d0"], float)))
    d1 = unit(np.asarray(h["d1"], float))
    length, r0 = h["length"], h["r0"]
    ts = np.linspace(0.0, 1.0, 241)
    tang = slerp(d0, d1, ts ** 1.35)
    path = base + np.concatenate([np.zeros((1, 3)), np.cumsum((tang[1:] + tang[:-1]) * 0.5 * (length / 240.0), axis=0)])

    def at(t):
        if t <= 0.0:
            return base + d0 * (t * length)
        return np.array([np.interp(t, ts, path[:, k]) for k in range(3)])

    def rt(t):
        return r0 * (1.0 - t) ** 0.72

    bounds = (0.32, 0.6) if r0 >= 1.6 else (0.45,)
    rings = [(-depth / length, r0 * 0.9), (0.0, r0 * 1.08), (0.07, r0 * 0.97)]
    for b in bounds:
        rings += [(b - 0.03, rt(b) * 0.9), (b, rt(b) * 1.03)]
    rings.append((0.82, rt(0.82)))
    centres = np.array([at(t) for t, _ in rings])
    radii = np.array([r for _, r in rings])
    curl = d1 - (d1 @ d0) * d0
    n0 = curl if np.linalg.norm(curl) > 1e-3 else np.cross(d0, UP)
    v, f, ring_of = sweep(centres, radii, radii * 0.84, sides, n0, twist=0.12, jitter=0.06, seed=100 + h["seed"],
                          cap_start=True, tip=at(1.0))
    t_of = np.array([rings[int(i)][0] if int(i) < len(rings) else 1.0 for i in ring_of])
    return v, f, t_of, bounds


def build_roast():
    name = "RoastHorned"
    hd = np.array([sph(*h["at"]) for h in ROAST_HORNS])
    horn_base = roast_surface(hd)
    horn_nrm = surface_normal(roast_surface, hd)
    rings = [patch_rings(*p) for p in ROAST_PATCHES]
    centres_cm = [roast_surface(dp[None])[0] for _, _, dp in rings]
    radius_cm = [np.linalg.norm(roast_surface(ra) - c, axis=1).mean() for (ra, _, _), c in zip(rings, centres_cm)]
    for i, (dp_c, r_cm) in enumerate(zip(centres_cm, radius_cm)):
        for j, (b, h) in enumerate(zip(horn_base, ROAST_HORNS)):
            gap = np.linalg.norm(dp_c - b) - r_cm * 1.22 - h["r0"] * 1.1
            if gap < 0.0:
                print("roast: patch %d overlaps horn %d by %.1f cm" % (i, j, -gap))

    def spacing(p):
        sp = 2.05 - 0.45 * fc.smoothstep(7.5, 12.0, np.abs(p[:, 0]))
        for b, h in zip(horn_base, ROAST_HORNS):
            dist = np.linalg.norm(p - b, axis=1)
            sp = np.minimum(sp, 1.45 + 0.6 * fc.smoothstep(h["r0"] * 1.1, h["r0"] * 2.6, dist))
        return sp

    def inside_patch(p):                                        # keep the facet interiors empty
        out = np.zeros(len(p), bool)
        for c, r in zip(centres_cm, radius_cm):
            out |= np.linalg.norm(p - c, axis=1) < r * 1.3
        return out

    fixed = np.concatenate([np.concatenate([ra, rb, dp[None]]) for ra, rb, dp in rings])
    dirs = blue_noise_dirs(roast_surface, spacing, 300, seed=11, fixed=fixed, fixed_spacing=1.7, reject=inside_patch)
    body = roast_surface(dirs)
    zlo = body[:, 2].min()
    zf = zlo + 1.0
    body[:, 2] = np.where(body[:, 2] < zf, zf - (zf - body[:, 2]) * 0.3, body[:, 2])     # resting base
    pidx, locks = patch_index(rings, 0)
    hull, _ = delaunay_flips(body, hull_faces(dirs), locks)
    for (ia, ib, ic), (ra, rb, dp) in zip(pidx, rings):
        flat = np.concatenate([ia, [ic]])
        c = body[ia].mean(axis=0)
        n = surface_normal(roast_surface, dp[None])[0]
        body[flat] -= (((body[flat] - c) @ n) - 0.12)[:, None] * n                        # one flat facet
        nb = surface_normal(roast_surface, rb)
        body[ib] -= nb * 0.32                                                              # crease around it

    parts = [(body, hull, 0)]
    horn_t, horn_i = [np.full(len(body), -1.0)], [np.full(len(body), -1.0)]
    band_bounds = []
    for i, (h, b, n) in enumerate(zip(ROAST_HORNS, horn_base, horn_nrm)):
        v, f, t, bounds = horn_tube(b, n, h)
        parts.append((v, f, 1))
        horn_t.append(t)
        horn_i.append(np.full(len(v), float(i)))
        band_bounds.append(bounds)
    verts, faces, slots = fc.merge(parts)
    verts, faces, slots, va = tidy(verts, faces, slots, {"t": np.concatenate(horn_t), "i": np.concatenate(horn_i)},
                                   dissolve_deg=0.5, dissolve_slot=0)
    shift = rest_shift(verts)
    raw = verts + shift
    flesh = va["i"] < 0

    # ---- cooked: shrink ~9 %, sag (z 0.88 about the floor, the bottom band spreads), crust bulge; horns stay
    vn = vertex_normals(raw, faces)
    ck = raw.copy()
    lo, hi = raw[flesh].min(axis=0), raw[flesh].max(axis=0)
    cxy = (lo + hi) * 0.5
    low = 1.0 - fc.smoothstep(0.0, 0.45 * hi[2], raw[:, 2])
    sxy = 0.91 + 0.05 * low
    ck[:, 0] = cxy[0] + (raw[:, 0] - cxy[0]) * sxy
    ck[:, 1] = cxy[1] + (raw[:, 1] - cxy[1]) * sxy
    ck[:, 2] = raw[:, 2] * 0.86
    bulge = (0.24 + 0.26 * fc.lumps(raw, 31, 0.45)) * fc.smoothstep(-0.6, 0.2, vn[:, 2])
    ck += vn * bulge[:, None]
    ck[~flesh] = raw[~flesh]
    ck = floor_fix(raw, ck, flesh, band_cm=2.0)

    obj = fc.new_object(spec.mesh_name(name), raw, faces, slots=spec.INGREDIENTS[name]["slots"], face_slots=slots)

    # ---- paint: amber sides, golden tops, pale underside, crust patches by low-frequency noise (not per facet)
    fcent, fnrm, farea = face_geo(raw, faces)
    slots_a = np.array(slots)
    nz = fnrm[:, 2]
    golden, amber, crust, pale, shine = (col(226, 154, 60), col(178, 96, 34), col(104, 48, 18), col(228, 184, 128),
                                         col(244, 196, 112))
    rgb = lerp(amber, golden, fc.smoothstep(-0.25, 0.85, nz))
    under = np.maximum(fc.smoothstep(-0.25, -0.8, nz), fc.smoothstep(2.2, 0.4, fcent[:, 2]))
    rgb = lerp(rgb, pale, under * 0.85)
    tone = fc.lumps(fcent, 91, 0.3)
    rgb = lerp(rgb, crust, fc.smoothstep(0.1, 0.7, tone) * 0.7 * (1.0 - under))
    rgb = lerp(rgb, shine, fc.smoothstep(-0.2, -0.7, tone) * 0.55)
    spots = fc.smoothstep(0.12, 0.42, fc.lumps(fcent, 95, 0.62)) * (1.0 - under)        # burnt crust spots
    rgb = lerp(rgb, col(92, 40, 14), spots * 0.8)
    dark, _, _ = pick_accents(len(faces), 77, 0.06, 0.0)
    rgb[dark] = lerp(rgb[dark], crust, 0.45)
    big = fc.smoothstep(5.0, 14.0, farea) * (slots_a == 0)             # the pulled-skin facets: taut, deeper amber
    rgb = lerp(rgb, col(150, 76, 28), big * 0.55)
    ft = face_mean(faces, va["t"])
    tmin = np.array([va["t"][f].min() for f in faces])
    tmax = np.array([va["t"][f].max() for f in faces])
    hbase, hmid, htip = col(240, 220, 172), col(224, 190, 128), col(88, 42, 18)
    hcol = lerp(hbase, hmid, fc.smoothstep(0.05, 0.5, ft))
    hcol = lerp(hcol, htip, fc.smoothstep(0.5, 0.93, ft))
    layer = np.zeros(len(faces))                                    # alternate layer shades between ledges
    for i, bounds in enumerate(band_bounds):
        on = va["i"][np.array([f[0] for f in faces])] == i
        layer[on] = np.searchsorted(np.array(bounds), ft[on]) % 2
    hcol = hcol * (1.0 - 0.06 * layer)[:, None]
    ledge = (tmax - tmin) < 0.045
    hcol[ledge] *= 0.8
    horn = slots_a == 1
    rgb[horn] = hcol[horn]
    paint_object(obj, rgb, seed=5, cavity_darken=0.42)
    finish_object(obj)

    roots = horn_base + shift
    radii = np.array([h["r0"] for h in ROAST_HORNS])

    def masks(fields):
        p, nzt, ao = fields["position_cm"], fields["normal"][..., 2], fields["ao"]
        top = fc.smoothstep(-0.35, 0.85, nzt)
        under_t = fc.smoothstep(0.2, 3.0, p[..., 2])
        r = (0.12 + 0.6 * top) * (0.4 + 0.6 * under_t) * fc.smoothstep(0.3, 0.92, ao)
        for b, rr in zip(roots, radii):                                     # meat around the horns cooks first
            r = r + 0.32 * (1.0 - fc.smoothstep(rr * 1.1, rr * 2.4, np.linalg.norm(p - b, axis=-1)))
        edges = edge_raster(obj, ao.shape[0])
        return assemble_masks(fields, r + 0.2 * edges, edges, grain_freq=0.9, seed=300)

    return dict(obj=obj, raw=raw, cooked=ck, masks=masks, static=~flesh)


# ================================================================ Drumstick
DRUM_XB, DRUM_RB, DRUM_BETA1 = 4.9, 5.6, math.radians(118.0)   # ball centre x, ball radius, where the neck starts
DRUM_X_NECK, DRUM_R_NECK = -3.0, 2.4                            # the cut rim the bone leaves through
DRUM_THETA_E = math.radians(150.0)                               # sphere angle of the rim (side | cap)
DRUM_S1 = 0.6                                                    # profile parameter where ball turns into neck
DRUM_PATCHES = ((32, 84, 24, 7, 11), (62, 205, 21, 6, 12), (55, 318, 19, 6, 13))   # pulled-skin facets on the ball


def drum_profile(s):
    """Meat outline (x, r) from the tip (s = 0) over the ball and the concave neck to the cut rim (s = 1)."""
    s = np.asarray(s, float)
    beta = np.minimum(s / DRUM_S1, 1.0) * DRUM_BETA1
    xb, rb = DRUM_XB + DRUM_RB * np.cos(beta), DRUM_RB * np.sin(beta)
    u = np.clip((s - DRUM_S1) / (1.0 - DRUM_S1), 0.0, 1.0)
    p0 = np.array([DRUM_XB + DRUM_RB * math.cos(DRUM_BETA1), DRUM_RB * math.sin(DRUM_BETA1)])
    p1 = np.array([DRUM_X_NECK, DRUM_R_NECK])
    k = np.linalg.norm(p1 - p0)
    t0 = np.array([-math.sin(DRUM_BETA1), math.cos(DRUM_BETA1)]) * k
    t1 = np.array([-1.0, -0.22]) * k                               # keeps narrowing to the cut (no collar)
    h00, h10, h01, h11 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u, -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
    xn = h00 * p0[0] + h10 * t0[0] + h01 * p1[0] + h11 * t1[0]
    rn = h00 * p0[1] + h10 * t0[1] + h01 * p1[1] + h11 * t1[1]
    ball = s <= DRUM_S1
    return np.where(ball, xb, xn), np.where(ball, rb, rn)


def drum_rim_radius(cphi, sphi):
    phi = np.arctan2(sphi, cphi)
    return DRUM_R_NECK * (1.0 + 0.10 * np.sin(3.0 * phi + 1.0) + 0.06 * np.sin(5.0 * phi + 2.0))


def drum_meat(d):
    cx, sn, cphi, sphi = polar_x(unit(d))
    th = np.arccos(cx)
    s = np.clip(th / DRUM_THETA_E, 0.0, 1.0)
    xs, rs = drum_profile(s)
    rag = drum_rim_radius(cphi, sphi) / DRUM_R_NECK
    rs = rs * (1.0 + (rag - 1.0) * fc.smoothstep(0.7, 1.0, s))                # ragged toward the rim
    t = np.clip((th - DRUM_THETA_E) / (math.pi - DRUM_THETA_E), 0.0, 1.0)
    xc = DRUM_X_NECK - 0.45 * np.sin(t * math.pi * 0.5)                          # cut flesh domes round the bone
    rc = drum_rim_radius(cphi, sphi) * (1.0 - t)
    side = th <= DRUM_THETA_E
    x = np.where(side, xs, xc)
    r = np.where(side, rs, rc)
    y = r * cphi * (1.0 + 0.12 * np.clip(cphi, 0.0, 1.0))                        # one side fuller
    z = r * sphi * 0.92
    k = fc.smoothstep(-3.0, 5.0, x)
    p = np.stack([x, y + 0.45 * k, z + 0.3 * k], axis=1)                         # meat sits a little off the bone axis
    radial = unit(np.stack([np.zeros_like(x) + 0.25 * (x - DRUM_XB) / DRUM_RB * side, cphi, sphi], axis=1))
    bump = (0.68 * fc.lumps(p, 41, 0.22) + 0.26 * fc.lumps(p, 42, 0.6)) * side * (1.0 - fc.smoothstep(0.8, 1.0, s))
    return p + radial * bump[:, None]


DRUM_BONE_X = (1.6, -0.8, -3.3, -5.0, -6.6, -7.9, -8.9)
DRUM_BONE_RY = (1.35, 1.28, 1.2, 1.12, 1.22, 1.62, 2.0)
DRUM_BONE_RZ = (1.35, 1.28, 1.2, 1.12, 1.18, 1.28, 1.32)
DRUM_LOBES = (((-9.75, 1.3, 0.08), 1.8, 61), ((-9.6, -1.3, -0.04), 1.72, 62))


def drum_bone():
    centres = np.array([(x, 0.0, 0.12 * math.sin(x * 0.5)) for x in DRUM_BONE_X])
    v, f, _ = sweep(centres, np.array(DRUM_BONE_RZ), np.array(DRUM_BONE_RY), 8, UP, twist=0.05, jitter=0.04,
                    seed=60, cap_start=True, cap_end=True, phase=0.2)
    parts = [(v, f, 1)]
    kinds = [np.full(len(v), 2.0)]
    for c, r, seed in DRUM_LOBES:
        lv, lf = fc.icosphere(r, 1)
        rng = np.random.default_rng(seed)
        lv = rotate(lv, unit(rng.normal(size=3)), rng.uniform(0.0, math.tau))
        lv = lv * (1.0 + rng.uniform(-0.06, 0.06, len(lv)))[:, None] * np.array([1.05, 1.0, 0.9])
        parts.append((lv + np.array(c), lf, 1))
        kinds.append(np.full(len(lv), 3.0))
    verts, faces, slots = fc.merge(parts)
    return verts, faces, np.concatenate(kinds)


def build_drumstick():
    name = "Drumstick"
    rng = np.random.default_rng(40)
    phis = np.arange(16) * math.tau / 16 + rng.uniform(-0.08, 0.08, 16)
    rim_dirs = np.stack([np.full(16, math.cos(DRUM_THETA_E)), math.sin(DRUM_THETA_E) * np.cos(phis),
                         math.sin(DRUM_THETA_E) * np.sin(phis)], axis=1)
    rings = [patch_rings(*p) for p in DRUM_PATCHES]
    centres_cm = [drum_meat(dp[None])[0] for _, _, dp in rings]
    radius_cm = [np.linalg.norm(drum_meat(ra) - c, axis=1).mean() for (ra, _, _), c in zip(rings, centres_cm)]

    def spacing(p):
        return 1.75 - 0.4 * fc.smoothstep(-1.0, -2.8, p[:, 0])

    def inside_patch(p):
        out = np.zeros(len(p), bool)
        for c, r in zip(centres_cm, radius_cm):
            out |= np.linalg.norm(p - c, axis=1) < r * 1.3
        return out

    patch_dirs = np.concatenate([np.concatenate([ra, rb, dp[None]]) for ra, rb, dp in rings])
    fixed = np.concatenate([rim_dirs, patch_dirs])
    dirs = blue_noise_dirs(drum_meat, spacing, 215, seed=41, fixed=fixed, fixed_spacing=1.45, reject=inside_patch)
    meat = drum_meat(dirs)
    pidx, locks = patch_index(rings, 16)
    locks += [(i, (i + 1) % 16) for i in range(16)]                  # the cut rim stays one crisp ring
    hull, _ = delaunay_flips(meat, hull_faces(dirs), locks)
    for (ia, ib, ic), (ra, rb, dp) in zip(pidx, rings):
        flat = np.concatenate([ia, [ic]])
        c = meat[ia].mean(axis=0)
        n = surface_normal(drum_meat, dp[None])[0]
        meat[flat] -= (((meat[flat] - c) @ n) - 0.1)[:, None] * n
        meat[ib] -= surface_normal(drum_meat, rb) * 0.18
    th = np.arccos(np.clip(unit(dirs)[:, 0], -1.0, 1.0))
    kind_meat = np.where(th > DRUM_THETA_E + 1e-4, 1.0, 0.0)          # 0 side, 1 cap
    kind_meat[:16] = 4.0                                              # the rim ring
    bv, bf, bk = drum_bone()
    verts, faces, slots = fc.merge([(meat, hull, 0), (bv, bf, 1)])
    kind = np.concatenate([kind_meat, bk])
    verts, faces, slots, va = tidy(verts, faces, slots, {"k": kind}, dissolve_deg=0.5, dissolve_slot=0)
    kind = va["k"]
    meat_m = (kind < 1.5) | (kind == 4.0)

    # ---- cooked in the local (axis) frame: shrink 10 % about the ball, pull the neck back off the bone, crust
    vn = vertex_normals(verts, faces)
    ck = verts.copy()
    c = np.array([4.2, 0.3, 0.2])
    ck[meat_m] = c + 0.9 * (verts[meat_m] - c)
    ck[meat_m, 0] += 1.0 * fc.smoothstep(3.0, -3.0, verts[meat_m, 0])
    side = (kind == 0.0)
    bulge = (0.2 + 0.22 * fc.lumps(verts, 47, 0.5)) * side
    ck += vn * bulge[:, None]
    ck[~meat_m] = verts[~meat_m]

    # ---- rest pose: tilt about Y until meat and knuckle both touch the counter
    def gap(a):
        rv = rotate(verts, np.array([0.0, 1.0, 0.0]), a)
        return rv[meat_m, 2].min() - rv[~meat_m, 2].min()

    lo_a, hi_a = -0.6, 0.0
    for _ in range(50):
        mid = 0.5 * (lo_a + hi_a)
        if gap(mid) < 0.0:
            hi_a = mid
        else:
            lo_a = mid
    tilt = 0.5 * (lo_a + hi_a)
    raw = rotate(verts, np.array([0.0, 1.0, 0.0]), tilt)
    ck = rotate(ck, np.array([0.0, 1.0, 0.0]), tilt)
    shift = rest_shift(raw)
    raw, ck = raw + shift, ck + shift
    ck = floor_fix(raw, ck, meat_m, band_cm=3.5)

    obj = fc.new_object(spec.mesh_name(name), raw, faces, slots=spec.INGREDIENTS[name]["slots"], face_slots=slots)
    obj["tilt_deg"] = round(math.degrees(tilt), 3)

    # ---- paint: red-brown meat with amber highlights in noise patches, a pale cut face, ivory bone
    fcent, fnrm, farea = face_geo(raw, faces)
    fk = face_mean(faces, kind)
    fkmax = np.array([kind[f].max() for f in faces])
    fkmin = np.array([kind[f].min() for f in faces])
    slots_a = np.array(slots)
    nz = fnrm[:, 2]
    mid_c, amber, dark, hi_c = col(138, 56, 26), col(204, 114, 42), col(88, 34, 16), col(232, 158, 72)
    rgb = lerp(mid_c, amber, fc.smoothstep(-0.3, 0.85, nz))
    rgb = lerp(rgb, dark, fc.smoothstep(0.0, -0.8, nz) * 0.45)
    tone = fc.lumps(fcent, 93, 0.38)
    rgb = lerp(rgb, dark, fc.smoothstep(0.05, 0.6, tone) * 0.75)
    rgb = lerp(rgb, hi_c, fc.smoothstep(-0.15, -0.65, tone) * 0.65)
    dk, lt, _ = pick_accents(len(faces), 48, 0.06, 0.06)
    rgb[dk] = lerp(rgb[dk], dark, 0.5)
    rgb[lt] = lerp(rgb[lt], hi_c, 0.4)
    big = fc.smoothstep(4.0, 10.0, farea) * (slots_a == 0)
    rgb = lerp(rgb, amber * 1.05, big * 0.5)
    cap_face = (slots_a == 0) & (fkmin >= 1.0) & (fkmax <= 4.0) & (fk > 0.5)
    rim_face = (slots_a == 0) & (fkmax == 4.0) & (fkmin == 0.0)
    rgb[cap_face] = col(228, 190, 150)
    obj["cap_faces"] = int(cap_face.sum())
    rgb[rim_face] = col(172, 100, 54)
    shaft = (slots_a == 1) & (fk < 2.5)
    lobe = (slots_a == 1) & (fk >= 2.5)
    xa = fcent[:, 0]
    x_meat = raw[meat_m, 0].min()
    rgb[shaft] = lerp(col(222, 204, 170), col(188, 156, 112), fc.smoothstep(x_meat - 2.5, x_meat + 0.5, xa[shaft]))
    rgb[lobe] = col(240, 230, 206)
    paint_object(obj, rgb, seed=9)
    finish_object(obj)

    rim_pts = raw[kind == 4.0]

    def masks(fields):
        p, nzt, ao = fields["position_cm"], fields["normal"][..., 2], fields["ao"]
        top = fc.smoothstep(-0.35, 0.85, nzt)
        under_t = fc.smoothstep(0.2, 3.0, p[..., 2])
        r = (0.12 + 0.6 * top) * (0.4 + 0.6 * under_t) * fc.smoothstep(0.3, 0.92, ao)
        d = np.full(p.shape[:2], 1e9)
        for q in rim_pts:                                       # the thin meat at the bone cooks first
            d = np.minimum(d, np.linalg.norm(p - q, axis=-1))
        r = r + 0.32 * (1.0 - fc.smoothstep(0.6, 2.8, d))
        edges = edge_raster(obj, ao.shape[0])
        return assemble_masks(fields, r + 0.2 * edges, edges, grain_freq=1.0, seed=310)

    return dict(obj=obj, raw=raw, cooked=ck, masks=masks, static=~meat_m)


# ================================================================ Tentacle
TENT_L = 42.0                  # spine arc length (cm, raw); the curl makes the X extent ~28
TENT_QC = 0.52                 # curl starts here (fraction of the arc)
TENT_R0, TENT_RT = 2.8, 0.3    # tube radius at the cut end / at the tip
TENT_TAPER = 1.15
TENT_SIDES = 10
TENT_CUT_DEG, TENT_CUT_PHASE = 18.0, 0.6
TENT_ALPHA0 = 1.95             # sucker side at the cut end: rad from N (up) toward B (front): the lower front flank
TENT_CURL_TILT = -0.45         # the curl plane leans back (-B, toward +Y) so it faces the front and iso views
TENT_SUCKERS = 16
RAW_SPINE = dict(L=TENT_L, s_amp=0.55, curl=6.3, lean=0.35, rscale=1.0)
COOKED_SPINE = dict(L=TENT_L * 0.92, s_amp=0.58, curl=6.3 * 1.2, lean=0.4, rscale=0.92)
SUCKER_PROFILE = ((1.05, -0.5), (1.0, 0.36), (0.72, 0.46), (0.42, 0.2))    # (radius, height) in sucker radii
SUCKER_POLE_H = 0.06
SUCKER_SIZE = 0.55             # sucker radius / local tube radius


def tent_radius(q, rscale=1.0):
    q = np.clip(np.asarray(q, float), 0.0, 1.0)
    return rscale * (TENT_RT + (TENT_R0 - TENT_RT) * (1.0 - q) ** TENT_TAPER)


def tent_alpha(q):
    return TENT_CURL_TILT + (TENT_ALPHA0 - TENT_CURL_TILT) * (1.0 - fc.smoothstep(0.26, 0.6, q))


def tent_spine(L, s_amp, curl, lean, rscale, n=2161):
    """Turtle-integrated spine over q in [-0.08, 1]: a lazy S in the counter plane, then a tightening curl up."""
    q = np.linspace(-0.08, 1.0, n)
    dq = q[1] - q[0]
    on = (q > 0.0) & (q < TENT_QC)
    om_b = np.where(on, -s_amp * (math.tau / TENT_QC) * np.sin(math.tau * q / TENT_QC), 0.0)
    g = fc.smoothstep(TENT_QC - 0.02, TENT_QC + 0.06, q) * np.exp(1.8 * (q - TENT_QC) / (1.0 - TENT_QC))
    g = g / (g.sum() * dq)
    om_n = curl * g * math.cos(TENT_CURL_TILT)                 # the curl bends up, leaning by TENT_CURL_TILT
    om_b = om_b + (curl * math.sin(TENT_CURL_TILT) + lean) * g
    T, N, B = np.array([1.0, 0.0, 0.0]), UP.copy(), np.array([0.0, -1.0, 0.0])
    pos = np.zeros(3)
    P = np.zeros((n, 3))
    for i in range(n):
        P[i] = pos
        a, b = om_n[i] * dq, om_b[i] * dq
        T, N = T * math.cos(a) + N * math.sin(a), N * math.cos(a) - T * math.sin(a)
        T, B = T * math.cos(b) + B * math.sin(b), B * math.cos(b) - T * math.sin(b)
        pos = pos + T * L * dq
    P[:, 2] += 0.88 * tent_radius(np.clip(q, 0.0, TENT_QC), rscale)       # the lying part rests on the counter
    return q, P


class Spine:
    def __init__(self, q, P):
        self.q, self.P = q, P
        self.T, self.N, self.B = transport_frames(P, UP)

    def eval(self, qv):
        qv = np.asarray(qv, float)
        i = np.clip(np.searchsorted(self.q, qv) - 1, 0, len(self.q) - 2)
        w = ((qv - self.q[i]) / (self.q[i + 1] - self.q[i]))[:, None]
        out = [a[i] * (1.0 - w) + a[i + 1] * w for a in (self.P, self.T, self.N, self.B)]
        return out[0], unit(out[1]), unit(out[2]), unit(out[3])


def tent_surface_rho(q, th, rscale):
    oral = np.maximum(0.0, np.cos(th - tent_alpha(q))) ** 2
    lump = 0.05 * fc.lumps(np.stack([q * TENT_L, 2.2 * np.cos(th), 2.2 * np.sin(th)], axis=1), 51, 0.5)
    return tent_radius(q, rscale) * (1.0 - 0.13 * oral) * (1.0 + lump)


def tent_eval(prm, cfg, sucker_scale):
    """Positions of every tentacle vertex for one spine configuration (raw or cooked)."""
    q, P = tent_spine(**cfg)
    spine = Spine(q, P)
    rs = prm["srk"] * tent_radius(prm["q0"], cfg["rscale"]) * sucker_scale         # sucker radius (0 off suckers)
    qq = prm["q0"] + (prm["dq"] * cfg["rscale"] + prm["a"] * rs) / cfg["L"]
    th = prm["th"] + prm["b"] * rs / tent_radius(prm["q0"], cfg["rscale"])
    rho = prm["rf"] * tent_surface_rho(qq, th, cfg["rscale"]) + prm["c"] * rs + prm["dj"] * tent_radius(qq, cfg["rscale"])
    p, T, N, B = spine.eval(qq)
    p = p + rho[:, None] * (np.cos(th)[:, None] * N + np.sin(th)[:, None] * B) + prm["dt"][:, None] * T
    zf = 0.12
    p[:, 2] = np.where(p[:, 2] < zf, zf - (zf - p[:, 2]) * 0.3, p[:, 2])           # soft contact with the counter
    return p, spine


def tent_params():
    """Vertex parameters, faces and face kinds of the tentacle (tube, cut face, suckers)."""
    rng = np.random.default_rng(71)
    cols = {k: [] for k in ("q0", "th", "rf", "dq", "dj", "a", "b", "c", "srk", "dt")}
    kinds_v = []

    def add(n, kind, **kw):
        start = len(kinds_v)
        for k in cols:
            v = kw.get(k, 0.0)
            cols[k].extend(np.broadcast_to(np.asarray(v, float), (n,)).tolist())
        kinds_v.extend([kind] * n)
        return np.arange(start, start + n)

    faces, fkind = [], []
    # tube rings
    qs = [0.0]
    while True:
        step = max(0.78 * float(tent_radius(qs[-1])), 0.32) / TENT_L
        if qs[-1] + step > 1.0 - 0.28 / TENT_L:
            break
        qs.append(qs[-1] + step)
    rings = []
    cut = math.tan(math.radians(TENT_CUT_DEG))
    for i, qv in enumerate(qs):
        th = np.arange(TENT_SIDES) * math.tau / TENT_SIDES + math.pi * qv + rng.uniform(-0.07, 0.07, TENT_SIDES)
        dj = rng.uniform(-0.035, 0.035, TENT_SIDES)
        dq = cut * np.cos(th - TENT_CUT_PHASE) * TENT_R0 if i == 0 else 0.0
        rings.append(add(TENT_SIDES, 0, q0=qv, th=th, rf=1.0, dq=dq, dj=dj if i else 0.0))
    for r0, r1 in zip(rings[:-1], rings[1:]):
        for s in range(TENT_SIDES):
            s2 = (s + 1) % TENT_SIDES
            faces.append([r0[s], r0[s2], r1[s2], r1[s]])
            fkind.append(0)
    tip = add(1, 0, q0=1.0, rf=0.0)[0]
    last = rings[-1]
    for s in range(TENT_SIDES):
        faces.append([last[s], last[(s + 1) % TENT_SIDES], tip])
        fkind.append(0)
    # oblique cut face at q = 0: skin band (inset ring, recessed) and the pale cut flesh
    th0 = np.array(cols["th"])[rings[0]]
    inset = add(TENT_SIDES, 5, q0=0.0, th=th0, rf=0.8, dq=cut * np.cos(th0 - TENT_CUT_PHASE) * TENT_R0 * 0.8 + 0.14)
    centre = add(1, 6, q0=0.0, rf=0.0, dq=0.2)[0]
    for s in range(TENT_SIDES):
        s2 = (s + 1) % TENT_SIDES
        faces.append([rings[0][s], inset[s], inset[s2], rings[0][s2]])
        fkind.append(5)
        faces.append([inset[s], centre, inset[s2]])
        fkind.append(6)
    # suckers: q spacing ~ local radius so they shrink toward the tip; slight zig-zag around the oral line
    spacing = 2.3
    for _ in range(40):
        q_s = [0.075]
        while True:
            nq = q_s[-1] + spacing * float(tent_radius(q_s[-1])) / TENT_L
            if nq > 0.955:
                break
            q_s.append(nq)
        if len(q_s) == TENT_SUCKERS:
            break
        spacing *= (len(q_s) / TENT_SUCKERS) ** 0.7
    for k, qk in enumerate(q_s):
        rk = float(tent_radius(qk))
        sides = 10 if rk > 1.7 else (8 if rk > 0.85 else 6)
        thk = float(tent_alpha(qk)) + (0.2 if k % 2 else -0.2)
        ph = np.arange(sides) * math.tau / sides + rng.uniform(-0.1, 0.1)
        ids = []
        for j, (rr, hh) in enumerate(SUCKER_PROFILE):
            ids.append(add(sides, 1 + min(j, 3), q0=qk, th=thk, rf=1.0, a=rr * np.cos(ph), b=rr * np.sin(ph),
                           c=hh, srk=SUCKER_SIZE))
        pole = add(1, 4, q0=qk, th=thk, rf=1.0, c=SUCKER_POLE_H, srk=SUCKER_SIZE)[0]
        for j in range(len(ids) - 1):
            for s in range(sides):
                s2 = (s + 1) % sides
                faces.append([ids[j][s], ids[j][s2], ids[j + 1][s2], ids[j + 1][s]])
                fkind.append(j + 1)                                   # 1 wall, 2 rim top, 3 cup wall
        for s in range(sides):
            faces.append([ids[-1][s], ids[-1][(s + 1) % sides], pole])
            fkind.append(4)                                           # cup floor
        faces.append(list(ids[0][::-1]))
        fkind.append(1)                                               # hidden bottom
    prm = {k: np.array(v, float) for k, v in cols.items()}
    return prm, faces, np.array(fkind), np.array(kinds_v), len(q_s)


def build_tentacle():
    name = "Tentacle"
    prm, faces, fkind, vkind, n_suckers = tent_params()
    raw, spine_raw = tent_eval(prm, RAW_SPINE, 1.0)
    ck, spine_ck = tent_eval(prm, COOKED_SPINE, 0.85)
    # cooked shrinks about the middle of the lying part (not about the cut end)
    lie_r = spine_raw.P[(spine_raw.q >= 0.0) & (spine_raw.q <= TENT_QC)]
    lie_c = spine_ck.P[(spine_ck.q >= 0.0) & (spine_ck.q <= TENT_QC)]
    d = lie_r.mean(axis=0) - lie_c.mean(axis=0)
    ck[:, :2] += d[:2]
    # orient: the lying chord along +X
    q0 = np.argmin(np.abs(spine_raw.q))
    qc = np.argmin(np.abs(spine_raw.q - TENT_QC))
    chord = spine_raw.P[qc] - spine_raw.P[q0]
    ang = -math.atan2(chord[1], chord[0])
    raw = rotate(raw, UP, ang)
    ck = rotate(ck, UP, ang)
    shift = rest_shift(raw)
    raw, ck = raw + shift, ck + shift
    # consistent outward winding (tube, cut face and every sucker are closed shells)
    bm, _ = bm_build(raw, faces)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.faces.index_update()
    faces = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()

    obj = fc.new_object(spec.mesh_name(name), raw, faces, slots=spec.INGREDIENTS[name]["slots"])
    obj["suckers"] = n_suckers

    # ---- paint
    fcent, fnrm, _ = face_geo(raw, faces)
    oral = face_mean(faces, np.cos(prm["th"] - tent_alpha(prm["q0"])))
    fq = face_mean(faces, prm["q0"])
    body, deep, belly = col(108, 28, 76), col(72, 16, 54), col(176, 82, 118)
    rgb = lerp(body, deep, fc.smoothstep(0.2, 0.9, fnrm[:, 2]) * 0.55)
    rgb = lerp(rgb, belly, fc.smoothstep(0.1, 0.85, oral))
    tone = fc.lumps(fcent, 97, 0.5)                                                 # mottled skin, in patches
    rgb = lerp(rgb, deep, fc.smoothstep(0.3, 0.8, tone) * 0.4 * (oral < 0.3))
    rgb = lerp(rgb, col(140, 34, 92), fc.smoothstep(0.7, 1.0, fq) * 0.4)          # the tip a touch more magenta
    table = {1: col(214, 136, 140), 2: col(242, 198, 184), 3: col(222, 152, 144), 4: col(172, 98, 106),
             5: col(146, 54, 92), 6: col(238, 198, 192)}
    for k, c in table.items():
        rgb[fkind == k] = c
    paint_object(obj, rgb, seed=13, value=0.06, hue=0.03)
    finish_object(obj)

    def masks(fields):
        p, nzt, ao = fields["position_cm"], fields["normal"][..., 2], fields["ao"]
        top = fc.smoothstep(-0.35, 0.85, nzt)
        under_t = fc.smoothstep(0.15, 1.6, p[..., 2])
        thin = fc.smoothstep(2.0, 11.0, p[..., 0])                                   # the thin curl cooks first
        r = (0.12 + 0.58 * top) * (0.35 + 0.65 * under_t) * fc.smoothstep(0.3, 0.92, ao) + 0.3 * thin
        edges = edge_raster(obj, ao.shape[0], width_cm=0.22)
        return assemble_masks(fields, r + 0.2 * edges, edges, grain_freq=1.2, seed=320)

    return dict(obj=obj, raw=raw, cooked=ck, masks=masks, static=np.zeros(len(raw), bool))


# ================================================================ masks
def _segment(img, a, b, w, val):
    h, wd = img.shape
    x0 = max(0, int(math.floor(min(a[0], b[0]) - w)))
    x1 = min(wd, int(math.ceil(max(a[0], b[0]) + w)) + 1)
    y0 = max(0, int(math.floor(min(a[1], b[1]) - w)))
    y1 = min(h, int(math.ceil(max(a[1], b[1]) + w)) + 1)
    if x1 <= x0 or y1 <= y0:
        return
    X, Y = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
    ab = b - a
    t = np.clip(((X - a[0]) * ab[0] + (Y - a[1]) * ab[1]) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
    d = np.hypot(X - (a[0] + t * ab[0]), Y - (a[1] + t * ab[1]))
    v = val * (1.0 - fc.smoothstep(0.3 * w, w, d))
    img[y0:y1, x0:x1] = np.maximum(img[y0:y1, x0:x1], v)


def edge_raster(obj, size, width_cm=0.35, lo_deg=7.0, hi_deg=40.0):
    """Rim mask: every convex facet edge sharper than lo_deg drawn into UV0 space (bottom-up rows), width in cm
    through each face's texel density, strength by the dihedral angle. Seams draw both sides."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    bm.faces.ensure_lookup_table()
    uvl = bm.loops.layers.uv["UVMap"]
    img = np.zeros((size, size), np.float32)
    dens = {}
    for f in bm.faces:
        uv = np.array([l[uvl].uv[:] for l in f.loops]) * size
        a_uv = 0.5 * abs((uv[1, 0] - uv[0, 0]) * (uv[2, 1] - uv[0, 1]) - (uv[2, 0] - uv[0, 0]) * (uv[1, 1] - uv[0, 1]))
        dens[f.index] = math.sqrt(a_uv / max(f.calc_area() * 1e4, 1e-9))
    for e in bm.edges:
        if len(e.link_faces) != 2:
            continue
        f1, f2 = e.link_faces
        ang = math.degrees(f1.normal.angle(f2.normal, 0.0))
        if ang < lo_deg:
            continue
        if (f2.calc_center_median() - f1.calc_center_median()).dot(f1.normal) > 0.0:
            continue                                                       # concave
        val = float(fc.smoothstep(lo_deg, hi_deg, ang))
        for f in (f1, f2):
            uvs = [np.array(l[uvl].uv[:]) * size for l in f.loops if l.vert in e.verts]
            if len(uvs) == 2:
                _segment(img, uvs[0], uvs[1], max(width_cm * dens[f.index], 1.0), val)
    bm.free()
    return img


def assemble_masks(fields, r, edges, grain_freq, seed):
    """RGBA per food_spec: R cook-first, G grain (fbm stretched 3:1 along X), B crust break-up, A convex rim."""
    cov = fields["coverage"] > 0.5
    pc = fields["position_cm"][cov]
    g = np.full(cov.shape, 0.5, np.float32)
    b = np.full(cov.shape, 0.5, np.float32)
    gr = fc.fbm(pc * np.array([grain_freq / 3.0, grain_freq, grain_freq]), seed + 1)
    br = fc.fbm(pc * 0.33, seed + 2)
    g[cov] = 0.5 + (gr - gr.mean()) / (gr.std() + 1e-6) * 0.15          # 0.5 neutral (signed detail term)
    b[cov] = 0.5 + (br - br.mean()) / (br.std() + 1e-6) * 0.17
    return np.stack([np.clip(r, 0.0, 1.0), np.clip(g, 0.0, 1.0), np.clip(b, 0.0, 1.0), np.clip(edges, 0.0, 1.0)],
                    axis=-1)


# ================================================================ verification / output
BUILDERS = {"RoastHorned": build_roast, "Drumstick": build_drumstick, "Tentacle": build_tentacle}


def mesh_stats(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    nonman = sum(1 for e in bm.edges if len(e.link_faces) != 2)
    degen = sum(1 for f in bm.faces if f.calc_area() * 1e4 < 1e-4)
    loose = sum(1 for v in bm.verts if not v.link_faces)
    bm.free()
    return nonman, degen, loose


def verify(name, res):
    obj = res["obj"]
    mesh = obj.data
    tris = fc.tri_count(obj)
    size_ok = fc.check_against_spec(obj, name)
    lo, hi = fc.bounds_cm(obj)
    uv = [u.name for u in mesh.uv_layers]
    flat = fc._is_flat(mesh)
    morph = float(obj.get("morph_max_cm", 0.0))
    nonman, degen, loose = mesh_stats(obj)
    slots = [m.name for m in mesh.materials]
    centred = abs(lo[0] + hi[0]) < 0.02 and abs(lo[1] + hi[1]) < 0.02 and abs(lo[2]) < 1e-3
    ck_lo = res["cooked"][:, 2].min()
    checks = {
        "tris": TRI_RANGE[0] <= tris <= TRI_RANGE[1],
        "size": size_ok,
        "flat": flat,
        "uv_layers": uv == ["UVMap", spec.MORPH_UV[0], spec.MORPH_UV[1]],
        "col": spec.COLOR_ATTR in mesh.color_attributes,
        "slots": tuple(slots) == tuple(spec.INGREDIENTS[name]["slots"]),
        "morph": MORPH_RANGE_CM[0] <= morph <= MORPH_RANGE_CM[1],
        "static_offset0": bool(np.all(np.abs(res["cooked"][res["static"]] - res["raw"][res["static"]]) < 1e-9)),
        "rest_pose": centred,
        "cooked_on_floor": abs(ck_lo) < 0.05,
        "no_degenerate": degen == 0 and loose == 0,
    }
    size = hi - lo
    print("CHECK %-12s tris %4d  size %.1f x %.1f x %.1f cm  slots %s  morph_max %.2f cm  non-manifold edges %d  %s" % (
        name, tris, size[0], size[1], size[2], slots, morph, nonman,
        " ".join("%s=%s" % (k, "ok" if v else "FAIL") for k, v in checks.items())))
    return checks, dict(tris=tris, size_cm=[round(float(s), 2) for s in size], slots=slots, morph_max_cm=round(morph, 3),
                        nonmanifold_edges=nonman, cooked_min_z_cm=round(float(ck_lo), 4))


def isolate(obj):
    coll = bpy.context.scene.collection
    others = [o for o in coll.objects if o is not obj]
    for o in others:
        coll.objects.unlink(o)
    return others


def unisolate(others):
    for o in others:
        bpy.context.scene.collection.objects.link(o)


def meats_sheet(objs, stem, views=("iso", "front", "top"), tile=(900, 640)):
    """RAW | COOKED review sheet. Each object is rendered alone (workbench, vertex colours, cavity) from one
    orthographic camera per view framed on the FIRST object's bounds, so the cooked shrink reads against the raw.
    Rows = views, left = raw, right = cooked. Tiles + <stem>_sheet.png in spec.REVIEW_DIR. (food_common.review_sheet
    spaces objects along X, which the iso view crops for long items.)"""
    fc.ensure_dirs()
    scene = bpy.context.scene
    corners = fc.verts_cm(objs[0]) * 0.01                     # frame on the raw object's own vertices
    centre = (corners.min(axis=0) + corners.max(axis=0)) * 0.5
    cam_data = bpy.data.cameras.new("_MeatsCam")
    cam_data.type = "ORTHO"
    cam_data.clip_start, cam_data.clip_end = 0.001, 100.0
    cam = bpy.data.objects.new("_MeatsCam", cam_data)
    scene.collection.objects.link(cam)
    meshes = [o for o in scene.objects if o.type == "MESH"]
    hidden = [o.hide_render for o in meshes]
    sh = scene.display.shading
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.resolution_percentage, scene.render.filepath, sh.color_type, sh.light, sh.show_cavity,
            scene.render.film_transparent)
    paths = []
    try:
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        sh.light, sh.color_type, sh.show_cavity = "STUDIO", "VERTEX", True
        scene.render.film_transparent = False
        scene.render.resolution_x, scene.render.resolution_y = tile
        scene.render.resolution_percentage = 100
        aspect = tile[0] / tile[1]
        tags = ("raw", "cooked") if len(objs) == 2 else tuple(str(i) for i in range(len(objs)))
        for view in views:
            d = unit(np.array(fc.VIEWS[view], float))
            fc._look_at(cam, tuple(centre + d * 5.0), tuple(centre))
            bpy.context.view_layer.update()
            mw = np.array(cam.matrix_world)
            px, py = (corners - centre) @ mw[:3, 0], (corners - centre) @ mw[:3, 1]
            ex, ey = 2.0 * np.abs(px).max(), 2.0 * np.abs(py).max()
            cam_data.ortho_scale = max(ex * 1.1, ey * 1.1 * aspect)
            for o, tag in zip(objs, tags):
                for m in meshes:
                    m.hide_render = m is not o
                path = os.path.join(spec.REVIEW_DIR, "%s_%s_%s.png" % (stem, view, tag))
                scene.render.filepath = path
                bpy.ops.render.render(write_still=True)
                paths.append(path)
    finally:
        for m, h in zip(meshes, hidden):
            m.hide_render = h
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
         scene.render.resolution_percentage, scene.render.filepath, sh.color_type, sh.light, sh.show_cavity,
         scene.render.film_transparent) = prev
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return fc.tile_images(paths, os.path.join(spec.REVIEW_DIR, "%s_sheet.png" % stem), cols=len(objs))


def cooked_copy(res):
    obj = res["obj"]
    ghost = obj.copy()
    ghost.data = obj.data.copy()
    ghost.name = obj.name + "_CookedPreview"
    bpy.context.scene.collection.objects.link(ghost)
    fc.set_verts_cm(ghost, res["cooked"])
    return ghost


def reimport_child(paths):
    fc.clear_scene()
    for p in paths.split("|"):
        print("REIMPORT_JSON " + json.dumps({"fbx": p, "report": fc.reimport_check(p)}))
    print("REIMPORT_DONE")


def run_reimport(fbx_paths, expected):
    """One fresh `--factory-startup` Blender per FBX (as Unreal imports each file on its own: no material-name
    collisions between files), each running food_common.reimport_check; prints and checks what came back."""
    ok = True
    reports = []
    for fbx in fbx_paths:
        cmd = [bpy.app.binary_path, "-b", "--factory-startup", "--python", os.path.abspath(__file__), "--",
               "--reimport", fbx]
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
        if "REIMPORT_DONE" not in out.stdout:
            ok = False
            print("REIMPORT child failed for %s: %s %s" % (fbx, out.stdout[-3000:], out.stderr[-3000:]))
            continue
        for line in out.stdout.splitlines():
            if not line.startswith("REIMPORT_JSON "):
                continue
            rec = json.loads(line[len("REIMPORT_JSON "):])
            reports.append(rec)
            for r in rec["report"]:
                key = r["name"].replace("_Mars_SM", "").split(".")[0]
                exp = expected.get(key, {})
                good = (r["uv_layers"] == ["UVMap", spec.MORPH_UV[0], spec.MORPH_UV[1]]
                        and spec.COLOR_ATTR in r["colors"] and r["flat"] and r["tris"] == exp.get("tris")
                        and r["slots"] == exp.get("slots"))
                ok &= good
                print("REIMPORT %-12s %s  %s" % (key, "ok" if good else "FAIL", json.dumps(r)))
    return ok, reports


def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False, "only": "", "review_dir": "",
                        "nobake": False, "reimport": "", "views": "iso,front,top"})
    if args["reimport"]:
        reimport_child(str(args["reimport"]))
        return
    t_start = time.time()
    names = [n.strip() for n in str(args["only"]).split(",") if n.strip()] if args["only"] else list(NAMES)
    for n in names:
        if n not in BUILDERS:
            raise SystemExit("unknown asset %r (have %s)" % (n, ", ".join(NAMES)))
    if args["save"] and len(names) != len(NAMES):
        print("--save refused with --only: Food_Meats.blend must hold every meat")
        args["save"] = False
    if args["review_dir"]:
        spec.REVIEW_DIR = str(args["review_dir"])
    fc.ensure_dirs()
    fc.clear_scene()

    results, all_ok, summary = {}, True, {}
    for name in names:
        t0 = time.time()
        res = BUILDERS[name]()
        obj = res["obj"]
        fc.smart_uv(obj)
        fc.write_morph_uvs(obj, res["raw"], res["cooked"])
        results[name] = res
        print("built %s in %.1fs" % (name, time.time() - t0))

    fbx_paths = []
    for name, res in results.items():
        obj = res["obj"]
        checks, info = verify(name, res)
        all_ok &= all(checks.values())
        if args["export"]:
            others = isolate(obj)
            try:
                if not args["nobake"]:
                    t0 = time.time()
                    mask_path, _ = fc.bake_masks(obj, res["masks"])
                    info["mask"] = mask_path
                    print("mask %s (%.1fs)" % (mask_path, time.time() - t0))
                fbx = fc.export_fbx(obj, extra={"category": "meats", "builder": os.path.basename(__file__),
                                                "cooked_min_z_cm": info["cooked_min_z_cm"]})
                fbx_paths.append(fbx)
                info["fbx"] = fbx
            finally:
                unisolate(others)
        if args["sheets"]:
            ghost = cooked_copy(res)
            try:
                views = tuple(v.strip() for v in str(args["views"]).split(",") if v.strip())
                info["sheet"] = meats_sheet([obj, ghost], name + "_RawCooked", views=views)
                print("sheet %s" % info["sheet"])
            finally:
                gm = ghost.data
                bpy.data.objects.remove(ghost)
                bpy.data.meshes.remove(gm)
        summary[name] = info

    if fbx_paths:
        ok, _ = run_reimport(fbx_paths, {n: summary[n] for n in summary})
        all_ok &= ok
    if args["save"]:
        fc.save_blend(BLEND_PATH)
        print("saved %s" % BLEND_PATH)
    print("SUMMARY " + json.dumps(summary))
    print("total %.1fs" % (time.time() - t_start))
    print("FOOD_MEATS_OK" if all_ok else "FOOD_MEATS_FAIL")


if __name__ == "__main__":
    main()
