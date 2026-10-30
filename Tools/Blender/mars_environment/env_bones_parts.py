"""Private helpers for build_env_bones.py (Blender 5.2, headless). Build-free: importing it never builds anything.

  * SDF primitives (numpy) + field_mesh(): sample a signed distance field on a grid, surface nets (candle_gen), Blender's
    collapse decimator -> a closed faceted triangle shell at a target triangle count;
  * the bone part library: skulls (cranium, maxilla, brow, cheekbones, deep sockets, nasal cavity, blocky teeth, a
    separate jaw), long bones with knobby epiphyses, ribs, broken shards, at three levels of detail (full / mid / lite);
  * Asm: an assembly of shells (slot, tag, group, part per face), with hidden-face culling (ray visibility), per-vertex
    ambient occlusion for the cavity channel, contact / grounding, coplanar overlap (z-fight) and seal checks;
  * HeightField: drop-and-settle placement for piles, scatters and packed ossuary fills;
  * chiselled stone: hull blocks with hand-cut chamfers and chips, carved fronts (pointed gothic niche, cross) from
    convex pieces (polygon helpers copied from build_station_kitchen.py, which must never be imported);
  * render_view: a workbench render helper for the close-up review sheets.

All geometry is in CENTIMETRES, Blender axes, Z up.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import env_common as ec  # noqa: E402

fc, sc, spec = ec.fc, ec.sc, ec.spec
import candle_gen as cg  # noqa: E402  (importable generator module: surface_nets, fill_pinches, _decimate, _smin)

X = np.array([1.0, 0.0, 0.0])
Y = np.array([0.0, 1.0, 0.0])
Z = np.array([0.0, 0.0, 1.0])


def _n(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-12)


def rot_x(deg):
    a = math.radians(deg)
    return np.array([[1.0, 0.0, 0.0], [0.0, math.cos(a), -math.sin(a)], [0.0, math.sin(a), math.cos(a)]])


def rot_y(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), 0.0, math.sin(a)], [0.0, 1.0, 0.0], [-math.sin(a), 0.0, math.cos(a)]])


def rot_z(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0.0], [math.sin(a), math.cos(a), 0.0], [0.0, 0.0, 1.0]])


def rot_between(a, b):
    """Rotation matrix turning unit vector a onto unit vector b."""
    a, b = _n(a), _n(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if c < -0.999999:
        axis = _n(np.cross(a, X if abs(a[0]) < 0.9 else Y))
        return 2.0 * np.outer(axis, axis) - np.eye(3)
    vx = np.array([[0.0, -v[2], v[1]], [v[2], 0.0, -v[0]], [-v[1], v[0], 0.0]])
    return np.eye(3) + vx + vx @ vx / (1.0 + c)


# ================================================================ SDF primitives (numpy, broadcasting)
def to_local(P, c, R=None):
    x, y, z = P[0] - c[0], P[1] - c[1], P[2] - c[2]
    if R is None:
        return x, y, z
    return (R[0, 0] * x + R[1, 0] * y + R[2, 0] * z, R[0, 1] * x + R[1, 1] * y + R[2, 1] * z,
            R[0, 2] * x + R[1, 2] * y + R[2, 2] * z)


def sd_ellipsoid(P, c, r, R=None):
    x, y, z = to_local(P, c, R)
    k0 = np.sqrt((x / r[0]) ** 2 + (y / r[1]) ** 2 + (z / r[2]) ** 2)
    k1 = np.sqrt((x / r[0] ** 2) ** 2 + (y / r[1] ** 2) ** 2 + (z / r[2] ** 2) ** 2)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def sd_sphere(P, c, r):
    return np.sqrt((P[0] - c[0]) ** 2 + (P[1] - c[1]) ** 2 + (P[2] - c[2]) ** 2) - r


def sd_capsule(P, a, b, ra, rb=None, squash=None):
    """Capsule a -> b with the radius going ra -> rb. squash = (sx, sy, sz) divides the offset from the axis before
    measuring (an elliptic section; not an exact distance, fine for the zero set)."""
    rb = ra if rb is None else rb
    ax, ay, az = P[0] - a[0], P[1] - a[1], P[2] - a[2]
    bx, by, bz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    h = np.clip((ax * bx + ay * by + az * bz) / max(bx * bx + by * by + bz * bz, 1e-12), 0.0, 1.0)
    dx, dy, dz = ax - bx * h, ay - by * h, az - bz * h
    if squash is not None:
        dx, dy, dz = dx / squash[0], dy / squash[1], dz / squash[2]
    return np.sqrt(dx * dx + dy * dy + dz * dz) - (ra + (rb - ra) * h)


def sd_round_box(P, c, half, r, R=None):
    x, y, z = to_local(P, c, R)
    qx, qy, qz = np.abs(x) - half[0] + r, np.abs(y) - half[1] + r, np.abs(z) - half[2] + r
    out = np.sqrt(np.maximum(qx, 0.0) ** 2 + np.maximum(qy, 0.0) ** 2 + np.maximum(qz, 0.0) ** 2)
    return out + np.minimum(np.maximum(qx, np.maximum(qy, qz)), 0.0) - r


def sd_plane(P, point, normal):
    n = _n(normal)
    return (P[0] - point[0]) * n[0] + (P[1] - point[1]) * n[1] + (P[2] - point[2]) * n[2]


def smin(a, b, k):
    return cg._smin(a, b, k)


def smax(a, b, k):
    return -cg._smin(-a, -b, k)


def chain(P, pts, radii, squash=None):
    """Union of capsules along a polyline (radii per point)."""
    d = None
    for i in range(len(pts) - 1):
        s = sd_capsule(P, pts[i], pts[i + 1], radii[i], radii[i + 1], squash)
        d = s if d is None else np.minimum(d, s)
    return d


def wave(P, seed, freq=1.0, terms=4):
    """Smooth deterministic noise -1..1 from a few sinusoids (for broken edges)."""
    rng = np.random.default_rng(seed)
    total = 0.0
    norm = 0.0
    for k in range(terms):
        w = _n(rng.normal(size=3)) * freq * (1.0 + 0.7 * k)
        amp = 1.0 / (1.0 + 0.8 * k)
        total = total + amp * np.sin(P[0] * w[0] + P[1] * w[1] + P[2] * w[2] + rng.uniform(0.0, math.tau))
        norm += amp
    return total / norm


# ================================================================ field -> faceted shell
def clean_tris(v, t):
    a, b, c = v[t[:, 0]], v[t[:, 1]], v[t[:, 2]]
    area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    t = t[area > 1e-5]
    key = np.sort(t, axis=1)
    _, inverse, counts = np.unique(key, axis=0, return_inverse=True, return_counts=True)
    t = t[counts[inverse.ravel()] == 1]
    used = np.unique(t)
    remap = np.full(len(v), -1, np.int64)
    remap[used] = np.arange(len(used))
    return v[used], remap[t]


def field_mesh(fn, lo, hi, voxel, target_tris):
    """Sample fn((X, Y, Z)) (negative inside) on a grid over lo..hi (cm), surface nets, decimate to target_tris.
    Returns (verts (n, 3) cm, tris (m, 3)) of a closed shell."""
    lo = np.asarray(lo, float) - 2.5 * voxel
    hi = np.asarray(hi, float) + 2.5 * voxel
    n = (np.ceil((hi - lo) / voxel) + 1).astype(int)
    axes = [lo[a] + np.arange(n[a]) * voxel for a in range(3)]
    G = np.meshgrid(*axes, indexing="ij")
    vals = np.asarray(fn(G), float)
    for sl in ((0,), (-1,)):
        vals[sl[0], :, :] = np.maximum(vals[sl[0], :, :], voxel)
        vals[:, sl[0], :] = np.maximum(vals[:, sl[0], :], voxel)
        vals[:, :, sl[0]] = np.maximum(vals[:, :, sl[0]], voxel)
    cg.fill_pinches(vals, voxel)
    hv, quads = cg.surface_nets(vals, lo, voxel)
    if len(quads) == 0:
        raise RuntimeError("field_mesh: empty field")
    v, t, _full = cg._decimate(hv, quads, target_tris)
    return clean_tris(v, t)


def open_edges(faces):
    """Number of edges used by exactly one face (0 for a closed manifold shell)."""
    from collections import Counter
    cnt = Counter()
    for f in faces:
        for i in range(len(f)):
            a, b = f[i], f[(i + 1) % len(f)]
            cnt[(min(a, b), max(a, b))] += 1
    return sum(1 for c in cnt.values() if c == 1)


def signed_volume(v, faces):
    vol = 0.0
    for f in faces:
        a = v[f[0]]
        for i in range(1, len(f) - 1):
            vol += float(np.dot(a, np.cross(v[f[i]], v[f[i + 1]])))
    return vol / 6.0


def orient_closed(v, faces):
    """Wind a closed shell outward: bmesh recalc (consistent winding), then the signed volume decides."""
    mesh = bpy.data.meshes.new("_orient")
    mesh.from_pydata(np.asarray(v, float).tolist(), [], [list(map(int, f)) for f in faces])
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.faces.ensure_lookup_table()
    out = [[x.index for x in face.verts] for face in bm.faces]
    bm.free()
    bpy.data.meshes.remove(mesh)
    if len(out) != len(faces):
        raise RuntimeError("orient_closed: face count changed (%d -> %d)" % (len(faces), len(out)))
    if signed_volume(np.asarray(v, float), out) < 0.0:
        out = [f[::-1] for f in out]
    return out


def newell(pts):
    n = np.zeros(3)
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n += np.array([(a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]), (a[0] - b[0]) * (a[1] + b[1])])
    ln = np.linalg.norm(n)
    return n / ln if ln > 1e-12 else n


def orient_convex(v, faces, centre=None):
    """Every face of a convex piece faces away from the piece's centre (works for open pieces too)."""
    v = np.asarray(v, float)
    c = v.mean(axis=0) if centre is None else np.asarray(centre, float)
    out = []
    for f in faces:
        f = list(map(int, f))
        if np.dot(newell(v[f]), v[f].mean(axis=0) - c) < 0.0:
            f = f[::-1]
        out.append(f)
    return out


def hull(points, dissolve_deg=0.3):
    """Convex hull (bmesh) of cm points -> (verts, faces) outward, exactly coplanar triangles merged into facets."""
    bm = bmesh.new()
    for p in np.asarray(points, float):
        bm.verts.new(p.tolist())
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    junk = [g for g in res.get("geom_interior", []) + res.get("geom_unused", []) if isinstance(g, bmesh.types.BMVert)]
    junk = list(dict.fromkeys(g for g in junk if g.is_valid))
    if junk:
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    if dissolve_deg:
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(dissolve_deg), verts=bm.verts[:], edges=bm.edges[:])
    bm.verts.index_update()
    v = np.array([x.co[:] for x in bm.verts], float)
    f = [[x.index for x in face.verts] for face in bm.faces]
    bm.free()
    return v, orient_convex(v, f)


def box_vf(center, size):
    c = np.asarray(center, float)
    hx, hy, hz = np.asarray(size, float) * 0.5
    v = np.array([[-hx, -hy, -hz], [hx, -hy, -hz], [hx, hy, -hz], [-hx, hy, -hz],
                  [-hx, -hy, hz], [hx, -hy, hz], [hx, hy, hz], [-hx, hy, hz]]) + c
    f = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    return v, f


# ================================================================ a "piece": shells in a local frame
class Shell:
    """One closed (or deliberately open, convex) shell: verts (n, 3) cm, faces, a tag per face, a slot name."""

    def __init__(self, v, f, tags, slot, kind="part"):
        self.v = np.asarray(v, float)
        self.f = [list(map(int, x)) for x in f]
        self.tags = [tags] * len(self.f) if isinstance(tags, str) else list(tags)
        assert len(self.tags) == len(self.f), (len(self.tags), len(self.f))
        self.slot = slot
        self.kind = kind

    def transformed(self, R=None, t=None, s=1.0):
        v = self.v * s
        if R is not None:
            v = v @ np.asarray(R, float).T
        if t is not None:
            v = v + np.asarray(t, float)
        f = self.f
        if R is not None and np.linalg.det(R) < 0.0:
            f = [x[::-1] for x in f]
        return Shell(v, f, self.tags, self.slot, self.kind)

    @property
    def tris(self):
        return sum(len(x) - 2 for x in self.f)


class Piece:
    """A bone part: a list of shells in its own frame (skull = cranium + teeth + jaw ...) plus metadata."""

    def __init__(self, name, shells, meta=None):
        self.name = name
        self.shells = shells
        self.meta = dict(meta or {})

    def transformed(self, R=None, t=None, s=1.0):
        return Piece(self.name, [x.transformed(R, t, s) for x in self.shells], self.meta)

    def verts(self):
        return np.concatenate([x.v for x in self.shells])

    def bounds(self):
        v = self.verts()
        return v.min(axis=0), v.max(axis=0)

    @property
    def tris(self):
        return sum(x.tris for x in self.shells)

    def rest(self, centre_xy=True):
        """Shift so the XY bbox centre is 0 (optional) and the lowest point is z = 0."""
        lo, hi = self.bounds()
        t = np.array([-(lo[0] + hi[0]) * 0.5 if centre_xy else 0.0, -(lo[1] + hi[1]) * 0.5 if centre_xy else 0.0,
                      -lo[2]])
        return self.transformed(t=t)


def tri_shell(v, t, tag_fn, slot="EnvBone", kind="part"):
    """A closed triangle shell from field_mesh, wound outward; tag_fn(centres, normals) -> tags."""
    f = orient_closed(v, t)
    fv = np.asarray(v, float)
    tri = np.array(f)
    a, b, c = fv[tri[:, 0]], fv[tri[:, 1]], fv[tri[:, 2]]
    cen = (a + b + c) / 3.0
    nrm = np.cross(b - a, c - a)
    nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12)
    return Shell(fv, f, tag_fn(cen, nrm), slot, kind)


# ================================================================ skulls
# cranium coordinates (cm): face toward -Y, Z up, origin near the middle of the braincase
SK = dict(
    cran_c=(0.0, 1.5, 2.0), cran_r=(7.0, 9.1, 7.3),
    base_c=(0.0, 2.6, -2.9), base_h=(5.0, 5.0, 2.7), base_r=2.0,
    face_c=(0.0, -5.0, -1.3), face_h=(5.1, 3.4, 2.9), face_r=1.8,
    max_c=(0.0, -5.3, -4.75), max_h=(3.75, 2.95, 1.65), max_r=0.6,
    # zygomas pulled in (they stay inside the cranium's front silhouette) and 20 % thinner (review 2026-10-20)
    cheek=((4.6, -6.4, -2.3), (5.6, 0.2, -1.7), 1.08, 0.88),
    # brow: a rounded ridge (half the old forward offset, blended softer), not a visor slab
    brow=[(0.3, -7.3, 0.35), (2.9, -7.4, 1.3), (5.3, -6.5, 0.85)], brow_r=(1.0, 1.1, 0.95), brow_k=2.1,
    eye_c=(3.1, -8.95, -0.65), eye_r=(2.13, 3.0, 2.07), eye_roll=-13.0,
    # nose lowered 0.8 cm and narrowed: a 1.5 cm bone bridge stays between it and both orbits
    nasal=((0.0, -9.1, -4.8), (1.0, 2.6, 1.25)), nasal_top=((0.0, -8.9, -4.0), (0.48, 2.4, 0.8)),
    fossa=((5.4, -2.4, -3.9), (1.4, 2.6, 1.7)),
    # alveolar band: the arc of bone the upper teeth root into (z centre, half height, radial half thickness)
    alveolar=(-6.8, 0.6, 0.85),
)
TEETH_UP = dict(arc_c=(0.0, -4.55), arc_r=3.0, a=58.0, w=1.38, d=1.1, h=1.95, top=-5.95, edge=-7.8)
JAW = dict(
    body=[(-4.75, 1.3), (-4.5, -2.3), (-3.35, -5.25), (-1.55, -6.85), (0.0, -7.25)],
    body_z=(-9.35, -10.6), body_r=(1.1, 1.25),
    chin=((0.0, -7.35, -10.6), (1.8, 1.2, 1.35)),
    # rami thicker (~2.5 cm front to back) and leaning back ~20 deg; condyles back and up into the ear notch
    ramus=((4.65, 0.9, -10.0), (4.6, 3.0, -4.6), 1.35, 1.2),
    condyle=((4.55, 3.3, -4.15), (1.1, 1.2, 1.0)),
    coronoid=((4.55, -0.1, -9.0), (4.45, -0.6, -7.5), 0.95, 0.8),
    gonion=((4.65, 1.2, -10.45), (0.9, 1.45, 1.15)),
    hinge=(0.0, 3.3, -4.15),
)
TEETH_LO = dict(arc_c=(0.0, -4.4), arc_r=2.8, a=46.0, w=1.3, d=1.05, h=1.55, bottom=-8.95, edge=-7.95)


def _eye_R(s):
    return rot_y(s * SK["eye_roll"])


def skull_sockets(P):
    d = None
    for s in (-1.0, 1.0):
        c = (s * SK["eye_c"][0], SK["eye_c"][1], SK["eye_c"][2])
        e = sd_ellipsoid(P, c, SK["eye_r"], _eye_R(s))
        d = e if d is None else np.minimum(d, e)
    return d


def skull_nasal(P):
    a = sd_ellipsoid(P, SK["nasal"][0], SK["nasal"][1])
    b = sd_ellipsoid(P, SK["nasal_top"][0], SK["nasal_top"][1])
    return smin(a, b, 0.5)


def skull_brow(P):
    d = None
    for s in (-1.0, 1.0):
        pts = [(s * x, y, z) for x, y, z in SK["brow"]]
        e = chain(P, pts, SK["brow_r"])
        d = e if d is None else np.minimum(d, e)
    return d


def skull_alveolar(P):
    """The 1.2 cm tall arc of bone under the face that holds the upper teeth (follows the tooth arc, a little wider)."""
    cx, cy = TEETH_UP["arc_c"]
    r = TEETH_UP["arc_r"]
    zc, hz, rt = SK["alveolar"]
    angs = np.radians(np.linspace(-TEETH_UP["a"] - 14.0, TEETH_UP["a"] + 14.0, 6))
    pts = [(cx + math.sin(a) * r, cy - math.cos(a) * r, zc) for a in angs]
    return chain(P, pts, [rt] * len(pts), squash=(1.0, 1.0, hz / rt))


def crack_hole(P):
    """Skull_C: the broken hole high on the left of the dome (a jagged bite) and the cavity behind it."""
    c = np.array([-3.6, 2.8, 7.4])
    d = sd_ellipsoid(P, c, (3.0, 3.6, 2.6), rot_y(-28.0) @ rot_x(8.0))
    d = d + 0.55 * wave(P, 909, freq=1.3)
    return d


def crack_lines(P):
    """Thin grooves running from the hole across the dome."""
    lines = [[(-3.0, 0.0, 9.0), (-0.6, -2.4, 9.2), (1.2, -4.2, 7.6), (2.1, -5.6, 5.4)],
             [(-1.4, 4.8, 8.6), (1.4, 6.6, 7.0), (2.4, 8.6, 4.4)],
             [(-6.2, 3.4, 5.0), (-7.0, 5.4, 2.4)]]
    d = None
    for pts in lines:
        e = chain(P, pts, [0.42] * len(pts))
        d = e if d is None else np.minimum(d, e)
    return d


def cranium_field(kind="A", fuse_jaw=False):
    """kind A / B (intact) or C (cracked). fuse_jaw adds the closed jaw into the same field (lite skulls)."""
    def fn(P):
        d = sd_ellipsoid(P, SK["cran_c"], SK["cran_r"])
        d = smin(d, sd_round_box(P, SK["base_c"], SK["base_h"], SK["base_r"]), 2.0)
        d = smin(d, sd_round_box(P, SK["face_c"], SK["face_h"], SK["face_r"]), 2.4)
        d = smin(d, sd_round_box(P, SK["max_c"], SK["max_h"], SK["max_r"]), 1.0)
        for s in (-1.0, 1.0):
            a, b, ra, rb = SK["cheek"]
            d = smin(d, sd_capsule(P, (s * a[0], a[1], a[2]), (s * b[0], b[1], b[2]), ra, rb), 0.8)
        d = smin(d, skull_brow(P), SK["brow_k"])
        d = smin(d, skull_alveolar(P), 0.7)
        for s in (-1.0, 1.0):
            c, r = SK["fossa"]
            d = smax(d, -sd_ellipsoid(P, (s * c[0], c[1], c[2]), r), 0.8)
        if fuse_jaw:
            d = smin(d, jaw_field(open_deg=0.0)(P), 0.35)
            # the mouth line: a shallow slot between the tooth rows
            d = smax(d, -sd_round_box(P, (0.0, -7.6, -7.85), (3.3, 1.6, 0.32), 0.25), 0.2)
        d = smax(d, -skull_sockets(P), 0.55)
        d = smax(d, -skull_nasal(P), 0.4)
        if kind == "C":
            d = smax(d, -crack_hole(P), 0.3)
            inner = sd_ellipsoid(P, SK["cran_c"], np.array(SK["cran_r"]) - 1.1)
            d = np.maximum(d, -np.maximum(inner, crack_hole(P) - 1.6))       # hollow only behind the hole
            d = smax(d, -crack_lines(P) + 0.0, 0.15)
        return d
    return fn


def jaw_field(open_deg=0.0):
    """The mandible in cranium coordinates (closed bite at open_deg 0; positive opens about the condyle hinge)."""
    R = rot_x(-open_deg)
    hinge = np.array(JAW["hinge"])

    def fn(P):
        if open_deg:
            Q = to_local(P, hinge, R)
            P = (Q[0] + hinge[0], Q[1] + hinge[1], Q[2] + hinge[2])
        pts2 = JAW["body"] + [(-x, y) for x, y in JAW["body"][::-1][1:]]
        d = None
        for z, r in zip(JAW["body_z"], JAW["body_r"]):
            pts = [(x, y, z) for x, y in pts2]
            e = chain(P, pts, [r] * len(pts))
            d = e if d is None else smin(d, e, 0.6)
        d = smin(d, sd_ellipsoid(P, JAW["chin"][0], JAW["chin"][1]), 0.7)
        for s in (-1.0, 1.0):
            for key in ("ramus", "coronoid"):
                a, b, ra, rb = JAW[key]
                d = smin(d, sd_capsule(P, (s * a[0], a[1], a[2]), (s * b[0], b[1], b[2]), ra, rb,
                                       squash=(0.5, 1.0, 1.0)), 0.6)
            c, r = JAW["condyle"]
            d = smin(d, sd_ellipsoid(P, (s * c[0], c[1], c[2]), r), 0.4)
            c, r = JAW["gonion"]
            d = smin(d, sd_ellipsoid(P, (s * c[0], c[1], c[2]), r), 0.6)
        return d
    return fn


def jaw_transform(open_deg):
    """(R, t) taking closed-jaw cranium coordinates to the opened jaw."""
    R = rot_x(-open_deg)
    hinge = np.array(JAW["hinge"])
    return R, hinge - R @ hinge


def tooth_box(c, tangent, w, d, h, top_z, rng, taper=0.82, bottom=False):
    """A blocky tooth: a box w (along tangent) x d (radial) x h hanging down from top_z (or rising from top_z when
    bottom=True), tapered toward its free edge, a little crooked."""
    t = _n(np.array([tangent[0], tangent[1], 0.0]))
    r = np.cross(Z, t)
    lean = rng.uniform(-6.0, 6.0)
    pts = []
    for zf, k in ((0.0, 1.0), (1.0, taper)):
        z = top_z + (h * zf if bottom else -h * zf)
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            p = np.array([c[0], c[1], z]) + t * sx * w * 0.5 * k + r * sy * d * 0.5 * (k if sy < 0 else 1.0)
            pts.append(p)
    pts = np.array(pts)
    root = np.array([c[0], c[1], top_z])
    pts = (pts - root) @ rot_z(lean * 0.3).T @ _axis_rot(t, lean).T + root
    pts += rng.uniform(-0.06, 0.06, pts.shape)
    v, f = hull(pts, dissolve_deg=0.0)
    return v, f


def _axis_rot(axis, deg):
    a = _n(axis)
    th = math.radians(deg)
    k = np.array([[0.0, -a[2], a[1]], [a[2], 0.0, -a[0]], [-a[1], a[0], 0.0]])
    return np.eye(3) + math.sin(th) * k + (1.0 - math.cos(th)) * (k @ k)


def teeth_row(spec_, count, rng, field_fn, lower=False, missing=()):
    """Teeth on an arc with an even bite line (spec_ edge): each root is pushed into the bone until all of its root
    corners are inside field_fn (at most ~1 cm), the free edge stays on the bite line."""
    cx, cy = spec_["arc_c"]
    out = []
    for i in range(count):
        if i in missing:
            continue
        a = math.radians(-spec_["a"] + 2.0 * spec_["a"] * i / max(count - 1, 1)) + rng.uniform(-0.03, 0.03)
        x = cx + math.sin(a) * spec_["arc_r"]
        y = cy - math.cos(a) * spec_["arc_r"]
        tangent = (math.cos(a), math.sin(a))
        w = spec_["w"] * rng.uniform(0.9, 1.08)
        edge = spec_["edge"] + rng.uniform(-0.12, 0.12)
        root = spec_["bottom"] if lower else spec_["top"]
        for _ in range(9):
            h = abs(edge - root)
            v, f = tooth_box((x, y), tangent, w, spec_["d"], h, root, rng, bottom=lower)
            rz = v[:, 2].min() if lower else v[:, 2].max()
            near = v[np.abs(v[:, 2] - rz) < 0.25]
            vals = field_fn((near[:, 0], near[:, 1], near[:, 2]))
            if np.all(vals < -0.12):
                break
            root += -0.12 if lower else 0.12
        out.append((v, f))
    return out


def _skull_tags(kind):
    def fn(cen, nrm):
        P = (cen[:, 0], cen[:, 1], cen[:, 2])
        sock = skull_sockets(P)
        nas = skull_nasal(P)
        brow = skull_brow(P)
        tags = []
        hole = crack_hole(P) if kind in ("C", "lowC") else None
        lines = crack_lines(P) if kind in ("C", "lowC") else None
        for i in range(len(cen)):
            if hole is not None and hole[i] < 0.5:
                tags.append("hole")
            elif lines is not None and lines[i] < 0.55:
                tags.append("crack")
            elif sock[i] < 0.45:
                tags.append("socket")
            elif nas[i] < 0.4:
                tags.append("nasal")
            elif brow[i] < 0.3 and nrm[i, 1] < 0.3:
                tags.append("brow")
            elif cen[i, 2] < -7.0 and cen[i, 1] < -5.0 and nrm[i, 1] < 0.0 and kind == "lite":
                tags.append("teethband")
            else:
                tags.append("bone")
        return tags
    return fn


def _jaw_tags(cen, nrm):
    return ["jaw"] * len(cen)


SKULL_LO = (-8.6, -10.6, -12.4)
SKULL_HI = (8.6, 11.4, 10.2)
CRANIUM_LO = (-8.6, -10.6, -7.0)
LOD = {
    # cranium tris, jaw tris, upper teeth, lower teeth, voxel
    "full": (232, 88, 5, 4, 0.26),
    "mid": (136, 50, 4, 3, 0.3),
    "lite": (100, 0, 0, 0, 0.32),
    "micro": (72, 0, 0, 0, 0.36),
    "nano": (52, 0, 0, 0, 0.4),          # packed hero fills: only the face and the dome show
}


def make_skull(kind="A", lod="full", seed=1, open_deg=6.0):
    """kind A: intact with jaw, B: jawless, C: cracked cranium (jawless), J: the jaw alone.
    Returns a Piece in cranium coordinates (face -Y), not yet rested."""
    rng = np.random.default_rng(seed)
    n_cran, n_jaw, n_up, n_lo, vox = LOD[lod]
    shells = []
    if kind == "J":
        jf = jaw_field(0.0)
        jaw_tris = {"full": 236, "mid": 110, "lite": 54, "micro": 40}[lod]
        v, t = field_mesh(jf, (-6.4, -9.0, -12.4), (6.4, 5.2, -2.6), min(vox, 0.24), jaw_tris)
        shells.append(tri_shell(v, t, _jaw_tags))
        if lod != "lite":
            for tv, tf in teeth_row(TEETH_LO, max(n_lo, 4), rng, jf, lower=True):
                shells.append(Shell(tv, tf, "tooth", "EnvBone", "tooth"))
        return Piece("Jaw", shells, {"kind": "J", "lod": lod})
    low = lod in ("lite", "micro", "nano")
    fuse = low and kind == "A"
    # a cracked cranium is hollow behind its hole: below ~150 tris the decimated shell folds through itself, so the
    # low LODs keep the dome closed and PAINT the hole and the cracks (tags) instead
    carve_c = kind == "C" and not low
    cf = cranium_field("C" if carve_c else "A", fuse_jaw=fuse)
    lo = SKULL_LO if fuse else CRANIUM_LO
    v, t = field_mesh(cf, lo, SKULL_HI, vox, n_cran + ((30 if lod == "lite" else 56) if fuse else 0))
    shells.append(tri_shell(v, t, _skull_tags(kind if not low else ("lowC" if kind == "C" else "lite"))))
    if n_up:
        missing = (1,) if kind == "C" else ()
        for tv, tf in teeth_row(TEETH_UP, n_up, rng, cf, missing=missing):
            shells.append(Shell(tv, tf, "tooth", "EnvBone", "tooth"))
    if kind == "A" and not fuse:
        jf = jaw_field(0.0)
        jv, jt = field_mesh(jf, (-6.4, -9.0, -12.4), (6.4, 5.2, -2.6), min(vox, 0.26), n_jaw)
        R, tt = jaw_transform(open_deg)
        shells.append(tri_shell(jv, jt, _jaw_tags).transformed(R, tt))
        for tv, tf in teeth_row(TEETH_LO, n_lo, rng, jf, lower=True):
            shells.append(Shell(tv, tf, "tooth", "EnvBone", "tooth").transformed(R, tt))
    return Piece("Skull_" + kind, shells, {"kind": kind, "lod": lod})


# ================================================================ hand-cut packed skull (fills, crown, stacks)
def _zipper(A, B, angA, angB):
    """Triangles bridging two closed vertex loops (index lists) both ordered by increasing angle about one axis."""
    angA = np.unwrap(np.asarray(angA, float))
    angB = np.unwrap(np.asarray(angB, float))
    j0 = int(np.argmin(np.abs(((angB - angA[0]) + math.pi) % (2 * math.pi) - math.pi)))
    B = list(B[j0:]) + list(B[:j0])
    angB = np.unwrap(np.concatenate([angB[j0:], angB[:j0]]))
    angB = angB + 2 * math.pi * np.round((angA[0] - angB[0]) / (2 * math.pi))
    nA, nB = len(A), len(B)
    aA = list(angA) + [angA[0] + 2 * math.pi]
    aB = list(angB) + [angB[0] + 2 * math.pi]
    i = j = 0
    tris = []
    while i < nA or j < nB:
        if j >= nB or (i < nA and aA[i + 1] <= aB[j + 1]):
            tris.append((A[i % nA], A[(i + 1) % nA], B[j % nB]))
            i += 1
        else:
            tris.append((A[i % nA], B[(j + 1) % nB], B[j % nB]))
            j += 1
    return tris


def make_packed_skull(variant=0, front=False):
    """A hand-cut low skull for packed ossuary fills (~80 tris, ~45 seen in a packed row): a flat chiselled face plane
    with two inset pentagonal orbits (~4.5 cm, 1.6 cm deep, a ~2 cm bone bridge between them), a separate triangular
    nasal notch, a bevelled maxilla band cut into three teeth with dark gaps, and a capped six-sided prism dome.
    Face toward -Y, cranium coordinates in cm (rest() before use). variant 0..2 changes proportions and orbit cut."""
    from mathutils.geometry import tessellate_polygon
    rng = np.random.default_rng(1009 + 37 * variant)

    def J(a):
        return float(rng.uniform(-a, a))
    wide = (0.0, 0.25, -0.2)[variant % 3]
    tall = (0.0, -0.2, 0.3)[variant % 3]
    V, F, T = [], [], []

    def vid(x, y, z):
        V.append((float(x), float(y), float(z)))
        return len(V) - 1

    # ---- front outline (x, z) on the face plane y = 0; band top row on it, bite row arched behind it
    t0 = vid(-6.0 - wide + J(0.2), 0.0, 10.0 + tall + J(0.25))
    t1 = vid(6.0 + wide + J(0.2), 0.0, 10.0 + tall + J(0.25))
    c0 = vid(-6.3 - wide + J(0.15), 0.0, 3.6 + J(0.25))
    c1 = vid(6.3 + wide + J(0.15), 0.0, 3.6 + J(0.25))
    k0 = vid(-3.2, 0.0, 2.4)
    k1 = vid(3.2, 0.0, 2.4)
    g1 = vid(-1.07 + J(0.1), 0.0, 2.4)
    g2 = vid(1.07 + J(0.1), 0.0, 2.4)
    bite = []
    for x in (-3.0, -1.45 + J(0.08), -0.72 + J(0.08), 0.72 + J(0.08), 1.45 + J(0.08), 3.0):
        bite.append(vid(x, 0.62 + 0.065 * x * x, -0.5))
    b0, a1l, a1r, a2l, a2r, b1 = bite
    # ---- holes: orbits (pentagons, mirrored with their own jitter) and the nasal notch
    orb_shape = [(1.0, 9.2), (5.0, 9.3), (5.45, 6.4), (3.55, 4.85), (1.05, 6.0)]
    if variant % 3 == 1:
        orb_shape = [(1.0, 9.25), (4.95, 9.05), (5.5, 6.1), (3.35, 4.8), (0.95, 6.2)]
    elif variant % 3 == 2:
        orb_shape = [(0.95, 9.1 + tall), (5.1, 9.4 + tall), (5.35, 6.6), (3.7, 5.0), (1.05, 5.85)]
    orbits = []
    for sg in (-1.0, 1.0):
        loop = []
        for x, z in orb_shape:
            loop.append(vid(sg * (x + J(0.12)), 0.0, z + J(0.12)))
        orbits.append(loop if sg > 0 else loop[::-1])
    nas = [vid(J(0.1), 0.0, 5.45 + J(0.1)), vid(-1.0 + J(0.08), 0.0, 3.05), vid(1.0 + J(0.08), 0.0, 3.05)]
    # ---- upper face plane with three holes (scanfill)
    outer = [k0, g1, g2, k1, c1, t1, t0, c0]
    loops = [outer] + orbits + [nas]
    flat = [i for lp in loops for i in lp]
    tris = tessellate_polygon([[(V[i][0], V[i][2], 0.0) for i in lp] for lp in loops])
    for a, b, c in tris:
        ia, ib, ic = flat[a], flat[b], flat[c]
        cz = (V[ia][2] + V[ib][2] + V[ic][2]) / 3.0
        cx = (V[ia][0] + V[ib][0] + V[ic][0]) / 3.0
        F.append([ia, ib, ic])
        T.append("brow" if cz > 8.7 else ("cheek" if abs(cx) > 4.9 else "face"))
    # ---- inset cones: orbits 1.6 cm deep, nasal 1.5 cm
    for loop, tag, depth in ((orbits[0], "socket", 1.6), (orbits[1], "socket", 1.6), (nas, "nasal", 1.5)):
        pts = np.array([V[i] for i in loop])
        c = pts.mean(axis=0)
        apex = vid(c[0], depth, c[2] - 0.15)
        for i in range(len(loop)):
            F.append([loop[i], loop[(i + 1) % len(loop)], apex])
            T.append(tag)
    # ---- maxilla band: three teeth, two dark gaps (V, wide at the bite)
    for f, tg in (([k0, b0, a1l], "tooth"), ([k0, a1l, g1], "tooth"), ([g1, a1l, a1r], "toothgap"),
                  ([g1, a1r, a2l], "tooth"), ([g1, a2l, g2], "tooth"), ([g2, a2l, a2r], "toothgap"),
                  ([g2, a2r, b1], "tooth"), ([g2, b1, k1], "tooth")):
        F.append(f)
        T.append(tg)
    # ---- dome: front boundary loop -> hexagon ring (widest) -> smaller hexagon -> flat occiput cap
    B = [t1, t0, c0, k0, b0, a1l, a1r, a2l, a2r, b1, k1, c1]
    hx = 7.3 + wide
    R1 = [vid(3.3 + J(0.2), 5.0 + J(0.3), 14.5 + tall + J(0.2)), vid(-3.3 + J(0.2), 5.0 + J(0.3), 14.5 + tall + J(0.2)),
          vid(-hx + J(0.15), 5.2 + J(0.3), 8.4 + J(0.3)), vid(-4.6 + J(0.2), 5.6, 0.4 + J(0.15)),
          vid(4.6 + J(0.2), 5.6, 0.4 + J(0.15)), vid(hx + J(0.15), 5.2 + J(0.3), 8.4 + J(0.3))]
    R2 = [vid(2.5 + J(0.2), 14.6 + J(0.3), 12.6 + tall + J(0.2)), vid(-2.5 + J(0.2), 14.6 + J(0.3), 12.6 + tall + J(0.2)),
          vid(-5.9 - wide + J(0.15), 14.0 + J(0.3), 7.6 + J(0.3)), vid(-3.6 + J(0.2), 13.2, 2.0 + J(0.2)),
          vid(3.6 + J(0.2), 13.2, 2.0 + J(0.2)), vid(5.9 + wide + J(0.15), 14.0 + J(0.3), 7.6 + J(0.3))]
    zc = 5.0

    def ang(i):
        return math.atan2(V[i][2] - zc, V[i][0])
    if front:
        # front-only LOD: the face zipped to a 4-sided ring 5 cm back and capped (the rest is never seen in a row)
        Rf = [vid(4.3, 5.2, 13.4 + tall), vid(-4.3, 5.2, 13.4 + tall), vid(-5.3, 5.5, 0.8), vid(5.3, 5.5, 0.8)]
        for f in _zipper(B, Rf, [ang(i) for i in B], [ang(i) for i in Rf]):
            F.append(list(f))
            T.append("bone")
        F.append(list(Rf))
        T.append("bone")
        used = sorted({i for f in F for i in f})
        remap = {o: k for k, o in enumerate(used)}
        v = np.array(V)[used]
        F = [[remap[i] for i in f] for f in F]
        return Piece("PackedFront", [Shell(v, orient_closed(v, F), T, "EnvBone", "skull")],
                     {"kind": "PF", "variant": variant})
    for f in _zipper(B, R1, [ang(i) for i in B], [ang(i) for i in R1]):
        F.append(list(f))
        T.append("bone")
    for i in range(6):
        F.append([R1[i], R1[(i + 1) % 6], R2[(i + 1) % 6], R2[i]])
        T.append("bone")
    # occiput: a low hexagonal pyramid (reads round from the side, costs the same as a flat cap + 2)
    occ = vid(0.0, 16.2, 7.4 + tall)
    for i in range(6):
        F.append([R2[i], R2[(i + 1) % 6], occ])
        T.append("bone")
    v = np.array(V)
    f = orient_closed(v, F)
    return Piece("PackedSkull", [Shell(v, f, T, "EnvBone", "skull")], {"kind": "P", "lod": "packed",
                                                                         "variant": variant})


def make_bone_end(rng, r=2.6, length=9.0):
    """A long bone seen end-on (the knob rows of concept 1): a six-sided prism with a faceted knob front, ~22 tris.
    Front toward -Y at y ~ 0, axis +Y, centred on x / z."""
    rx, rz = r * rng.uniform(1.0, 1.15), r * rng.uniform(0.85, 1.0)
    rot = rng.uniform(0.0, math.pi / 3.0)
    # front: a flat hexagon end (4 tris), 6 side quads, a hexagon back - 20 tris, ~8 seen in a packed row
    V = []
    for k in range(6):
        a = rot + k * math.pi / 3.0 + rng.uniform(-0.12, 0.12)
        V.append((rx * math.cos(a), 0.0, rz * math.sin(a)))
    for k in range(6):
        a = rot + k * math.pi / 3.0
        V.append((rx * math.cos(a), length, rz * math.sin(a)))          # constant width: no taper from above
    F, T = [], []
    F.append([0, 1, 2, 3, 4, 5])
    T.append("knob")
    for k in range(6):
        F.append([k, 6 + k, 6 + (k + 1) % 6, (k + 1) % 6])
        T.append("shaft")
    F.append([6 + k for k in range(6)])
    T.append("shaft")
    v = np.array(V)
    return Piece("BoneEnd", [Shell(v, orient_closed(v, F), T, "EnvBone", "end")], {"kind": "E"})


def clip_shell(sh, p0, n, cap_tag="chip"):
    """Cut a convex shell (closed or a flush 'seam' piece) by the plane through p0 with outward normal n: keeps the
    side (v - p0) . n <= 0 and closes the cut with one cap face tagged cap_tag. Returns the new Shell, the original
    when the plane misses it, or None when nothing is left."""
    n = _n(n)
    p0 = np.asarray(p0, float)
    d = (sh.v - p0) @ n
    if d.max() <= 1e-6:
        return sh
    if d.min() >= -1e-6:
        return None
    V, key = [], {}

    def vid(p):
        k = tuple(np.round(p, 5))
        if k not in key:
            key[k] = len(V)
            V.append(np.asarray(p, float))
        return key[k]
    F, T, cut = [], [], []
    for f, tg in zip(sh.f, sh.tags):
        out = []
        m = len(f)
        for i in range(m):
            a, b = sh.v[f[i]], sh.v[f[(i + 1) % m]]
            da, db = float((a - p0) @ n), float((b - p0) @ n)
            if da <= 0.0:
                out.append(vid(a))
            if (da < 0.0 < db) or (db < 0.0 < da):
                qi = vid(a + (b - a) * (da / (da - db)))
                out.append(qi)
                cut.append(qi)
            elif da == 0.0:
                cut.append(vid(a))
        clean = []
        for x in out:
            if not clean or clean[-1] != x:
                clean.append(x)
        if len(clean) > 1 and clean[0] == clean[-1]:
            clean.pop()
        if len(clean) >= 3 and polygon_area(np.array([V[i] for i in clean])) > 1e-5:
            F.append(clean)
            T.append(tg)
    cut = sorted(set(cut))
    if len(cut) >= 3:
        P = np.array([V[i] for i in cut])
        c = P.mean(axis=0)
        u = _n(np.cross(n, X if abs(n[0]) < 0.9 else Y))
        w = np.cross(n, u)
        order = sorted(range(len(cut)), key=lambda k: math.atan2(float((P[k] - c) @ w), float((P[k] - c) @ u)))
        cap = [cut[k] for k in order]
        if polygon_area(np.array([V[i] for i in cap])) > 1e-5:
            F.append(cap)
            T.append(cap_tag)
    v = np.array(V)
    used = sorted({i for f in F for i in f})
    remap = {o: k for k, o in enumerate(used)}
    v = v[used]
    F = [[remap[i] for i in f] for f in F]
    return Shell(v, orient_convex(v, F), T, sh.slot, sh.kind)


# ================================================================ long bones, ribs, shards
def femur_field(length=45.0, bend=0.0):
    k = length / 45.0

    def fn(P):
        Q = (P[0] / k, P[1] / k, P[2] / k)
        mid_y = bend
        # chunky cartoon proportions (review 2026-10-20): shaft ~5 cm on 45 cm, epiphyses ~15 % bigger
        d = chain(Q, [(-15.0, 0.0, 0.0), (-7.0, mid_y * 0.7, 0.2), (2.0, mid_y, 0.25), (14.6, 0.0, 0.0)],
                  [2.95, 2.55, 2.5, 2.95])
        # proximal: neck + head + greater trochanter
        d = smin(d, sd_capsule(Q, (-15.4, 0.2, 0.0), (-18.0, 1.9, 0.35), 2.55, 2.2), 1.0)
        d = smin(d, sd_sphere(Q, (-18.9, 2.4, 0.4), 3.8), 0.8)
        d = smin(d, sd_ellipsoid(Q, (-17.0, -2.5, 0.15), (3.1, 2.3, 2.9)), 1.1)
        # distal: flare + two condyles + the notch between them
        d = smin(d, sd_capsule(Q, (13.2, 0.0, 0.0), (17.2, 0.0, -0.2), 2.9, 3.6), 1.2)
        for s in (-1.0, 1.0):
            d = smin(d, sd_ellipsoid(Q, (19.1, s * 2.35, -0.25), (3.3, 2.65, 3.2)), 0.9)
        d = smax(d, -sd_ellipsoid(Q, (22.0, 0.0, -0.4), (1.5, 0.9, 2.5)), 0.4)
        return d * k
    lo = np.array([-23.6, -6.6 + min(bend, 0.0), -4.6]) * k
    hi = np.array([23.4, 7.4 + max(bend, 0.0), 5.0]) * k
    return fn, lo, hi


def humerus_field(length=32.0):
    k = length / 32.0

    def fn(P):
        Q = (P[0] / k, P[1] / k, P[2] / k)
        d = chain(Q, [(-10.6, 0.0, 0.0), (-2.0, 0.25, 0.15), (10.0, 0.0, 0.0)], [2.35, 2.0, 2.25])
        d = smin(d, sd_sphere(Q, (-12.4, 0.7, 0.25), 3.3), 1.0)
        d = smin(d, sd_ellipsoid(Q, (-11.3, -2.2, 0.1), (2.1, 1.55, 1.9)), 0.8)
        d = smin(d, sd_ellipsoid(Q, (11.6, 0.0, -0.1), (2.3, 3.7, 1.85)), 1.0)
        for s in (-1.0, 1.0):
            d = smin(d, sd_ellipsoid(Q, (13.2, s * 1.85, -0.15), (1.9, 1.65, 1.9)), 0.6)
        return d * k
    lo = np.array([-16.4, -4.8, -4.0]) * k
    hi = np.array([16.0, 4.8, 4.0]) * k
    return fn, lo, hi


def tibia_field(length=36.0):
    """A generic straight long bone (tibia-like): broad knobby top, smaller ankle end. For fills and piles."""
    k = length / 36.0

    def fn(P):
        Q = (P[0] / k, P[1] / k, P[2] / k)
        d = chain(Q, [(-12.2, 0.0, 0.0), (0.0, 0.0, 0.2), (12.6, 0.0, 0.0)], [2.9, 2.15, 2.2])
        for s in (-1.0, 1.0):
            d = smin(d, sd_ellipsoid(Q, (-14.4, s * 2.2, 0.0), (2.8, 2.75, 2.75)), 1.0)
        d = smin(d, sd_ellipsoid(Q, (14.6, 0.35, 0.0), (2.5, 2.75, 2.35)), 0.9)
        d = smin(d, sd_ellipsoid(Q, (15.0, -1.95, -0.1), (1.45, 1.3, 1.4)), 0.5)
        return d * k
    lo = np.array([-17.9, -5.8, -3.8]) * k
    hi = np.array([17.8, 4.2, 3.8]) * k
    return fn, lo, hi


def rib_field(chord=24.0):
    """A rib lying flat: a flattened curved bar (arc in XY), head knob at -X, flatter sternal end at +X."""
    R0 = chord / (2.0 * math.sin(math.radians(68.0)))
    angs = np.radians(np.linspace(158.0, 22.0, 9))
    pts = [(R0 * math.cos(a), R0 * math.sin(a) - R0 * math.cos(math.radians(68.0)) - 3.0, 0.0) for a in angs]
    pts = [(x, y, 0.5 * (1.0 - i / 8.0) ** 2) for i, (x, y, _) in enumerate(pts)]
    # a flat bar ~2 cm wide x 1.2 cm thick (review 2026-10-20: it read as a crescent blade)
    radii = [0.8, 0.92, 1.0, 1.05, 1.05, 1.05, 1.02, 0.98, 0.95]

    def fn(P):
        d = chain(P, pts, radii, squash=(1.0, 1.0, 0.62))
        d = smin(d, sd_ellipsoid(P, (pts[0][0] - 0.7, pts[0][1] - 0.5, 0.5), (1.4, 1.2, 0.95)), 0.5)
        d = smin(d, sd_ellipsoid(P, (pts[1][0] + 0.2, pts[1][1] + 1.0, 0.4), (1.0, 0.85, 0.7)), 0.4)
        return d
    p = np.array(pts)
    lo = p.min(axis=0) - 1.8
    hi = p.max(axis=0) + 1.8
    return fn, lo, hi


def shard_field(kind, seed):
    """Broken bone fragments: 'shaft' (a hollow shaft piece, jagged both ends), 'end' (a knob end snapped off)."""
    def jag(P, x0, sgn, s):
        return sgn * (P[0] - x0) + 0.85 * wave(P, s, freq=1.3) + 0.4 * wave(P, s + 7, freq=2.7)

    if kind == "shaft":
        def fn(P):
            d = chain(P, [(-7.5, 0.0, 0.0), (0.0, 0.25, 0.0), (7.5, 0.0, 0.0)], [2.3, 2.1, 2.2])
            d = np.maximum(d, jag(P, 6.0, 1.0, seed))
            d = np.maximum(d, jag(P, -5.8, -1.0, seed + 3))
            d = np.maximum(d, -sd_capsule(P, (-10.0, 0.1, 0.0), (10.0, 0.1, 0.0), 1.05))
            return d
        return fn, (-8.6, -3.0, -3.0), (8.6, 3.2, 3.0)

    def fn(P):
        d = sd_capsule(P, (-6.0, 0.0, 0.0), (2.6, 0.0, -0.1), 2.2, 2.8)
        for s in (-1.0, 1.0):
            d = smin(d, sd_ellipsoid(P, (4.2, s * 1.9, -0.2), (2.6, 2.1, 2.5)), 0.8)
        d = np.maximum(d, jag(P, -3.4, -1.0, seed))
        d = np.maximum(d, -sd_capsule(P, (-9.0, 0.0, 0.0), (-1.5, 0.0, 0.0), 1.05))
        return d
    return fn, (-5.8, -4.8, -3.2), (7.6, 4.8, 3.0)


def splinter(rng, length):
    """A chunky bone splinter, 8-12 cm: hull of a jittered spindle whose two ends are cut obliquely (a long slanted
    break face and a jagged point) - ~20 tris."""
    pts = []
    prof = (0.85, 1.35, 1.25, 0.8)
    ts = (0.0, 0.32, 0.68, 1.0)
    cut = (rng.uniform(0.35, 0.6) * rng.choice([-1.0, 1.0]), rng.uniform(0.35, 0.6) * rng.choice([-1.0, 1.0]))
    for i, (t, r) in enumerate(zip(ts, prof)):
        for a in (0.0, 1.57, 3.14, 4.71):
            aa = a + rng.uniform(-0.3, 0.3) + 0.6 * i
            y, z = r * math.cos(aa) * rng.uniform(0.85, 1.12), 0.8 * r * math.sin(aa) * rng.uniform(0.85, 1.12)
            x = length * (t - 0.5)
            if i == 0:
                x += cut[0] * (y * 2.2) + rng.uniform(-0.3, 0.3)
            elif i == 3:
                x += cut[1] * (y * 2.2) + rng.uniform(-0.3, 0.3)
            pts.append((x, y, z))
    # a jagged point on each end, off-axis
    pts.append((-length * 0.5 - rng.uniform(0.8, 1.6), rng.uniform(-0.6, 0.6), rng.uniform(-0.3, 0.3)))
    pts.append((length * 0.5 + rng.uniform(0.8, 1.6), rng.uniform(-0.6, 0.6), rng.uniform(-0.3, 0.3)))
    return hull(np.array(pts), dissolve_deg=0.0)


def _bone_tags(knob_x):
    """Shaft vs knob ends by |x| (the field frame of a bone along X)."""
    def fn(cen, nrm):
        return ["knob" if abs(c[0]) > knob_x else "shaft" for c in cen]
    return fn


BONE_LOD = {"full": 1.0, "mid": 0.42, "lite": 0.22, "micro": 0.15, "nano": 0.11}
BONE_TRIS = {"Femur": 260, "FemurB": 240, "Humerus": 216, "Tibia": 220, "Rib": 150}


def make_long_bone(name, lod="full", length=None):
    if name == "Femur":
        fn, lo, hi = femur_field(length or 45.0)
        knob = 15.0 * (length or 45.0) / 45.0
    elif name == "FemurB":
        fn, lo, hi = femur_field(length or 38.0, bend=1.6)
        knob = 15.0 * (length or 38.0) / 45.0
    elif name == "Humerus":
        fn, lo, hi = humerus_field(length or 32.0)
        knob = 10.5 * (length or 32.0) / 32.0
    elif name == "Tibia":
        fn, lo, hi = tibia_field(length or 36.0)
        knob = 12.5 * (length or 36.0) / 36.0
    elif name == "Rib":
        fn, lo, hi = rib_field(length or 24.0)
        knob = 99.0
    else:
        raise ValueError(name)
    target = max(int(BONE_TRIS[name] * BONE_LOD[lod]), 26 if lod == "nano" else 36)
    vox = {"full": 0.24, "mid": 0.3, "lite": 0.36, "micro": 0.4, "nano": 0.4}[lod]
    v, t = field_mesh(fn, lo, hi, vox, target)
    sh = tri_shell(v, t, _bone_tags(knob))
    return Piece(name, [sh], {"kind": name, "lod": lod, "long": True})


def make_shards(seed=5, lod="full"):
    """BoneShards: a hollow shaft fragment, a snapped-off knob end and two 8-12 cm splinters (separate pieces). Break
    faces are tagged 'break', the marrow inside them 'marrow' (painted dark, A ~0.2)."""
    rng = np.random.default_rng(seed)
    pieces = []
    for kind, tris in (("shaft", 104), ("end", 110)):
        fn, lo, hi = shard_field(kind, seed + len(pieces) * 11)
        v, t = field_mesh(fn, lo, hi, 0.22 if lod == "full" else 0.3, tris if lod == "full" else int(tris * 0.6))

        def tag_fn(cen, nrm, kind=kind):
            out = []
            for c, n in zip(cen, nrm):
                r_ax = math.hypot(c[1] - (0.1 if kind == "shaft" else 0.0), c[2])
                inside = (kind == "shaft" or c[0] < -1.0)
                if inside and r_ax < 1.45:
                    out.append("marrow")
                elif abs(n[0]) > 0.5 and (abs(c[0]) > 3.0 if kind == "shaft" else c[0] < -1.5):
                    out.append("break")
                else:
                    out.append("shaft")
            return out
        pieces.append(Piece("Shard_" + kind, [tri_shell(v, t, tag_fn)], {"kind": "shard"}))
    for L in (rng.uniform(9.0, 10.5), rng.uniform(10.5, 12.0)):
        v, f = splinter(rng, L)
        vv = np.asarray(v)
        tags = []
        for face in f:
            n = newell(vv[face])
            c = vv[face].mean(axis=0)
            tags.append("break" if abs(n[0]) > 0.45 and abs(c[0]) > L * 0.3 else "splinter")
        pieces.append(Piece("Splinter", [Shell(v, f, tags, "EnvBone")], {"kind": "shard"}))
    return pieces


# ================================================================ assembly
class Asm:
    """Accumulates shells (each with a group = the bone / block it belongs to) and builds one flat-shaded object."""

    def __init__(self, slots):
        self.slots = tuple(slots)
        self.shells = []          # (Shell, group)
        self.n_groups = 0
        self.keep = None          # per face mask after culling

    def new_group(self):
        self.n_groups += 1
        return self.n_groups - 1

    def add_shell(self, shell, group=None):
        if shell.slot not in self.slots:
            raise ValueError("slot %s not in %s" % (shell.slot, self.slots))
        g = self.new_group() if group is None else group
        self.shells.append((shell, g))
        return g

    def add_piece(self, piece, R=None, t=None, s=1.0, group=None):
        g = self.new_group() if group is None else group
        for sh in piece.transformed(R, t, s).shells:
            self.add_shell(sh, g)
        return g

    def add_vf(self, v, f, slot, tags, group=None, orient="convex", kind="block"):
        if orient == "convex":
            f = orient_convex(v, f)
        elif orient == "closed":
            f = orient_closed(v, f)
        return self.add_shell(Shell(v, f, tags, slot, kind), group)

    # ---- merged arrays
    def merged(self):
        V, F, slot, tags, group, shell = [], [], [], [], [], []
        base = 0
        for k, (sh, g) in enumerate(self.shells):
            V.append(sh.v)
            F.extend([[base + i for i in f] for f in sh.f])
            slot.extend([self.slots.index(sh.slot)] * len(sh.f))
            tags.extend(sh.tags)
            group.extend([g] * len(sh.f))
            shell.extend([k] * len(sh.f))
            base += len(sh.v)
        return (np.concatenate(V), F, np.array(slot), np.array(tags, dtype=object), np.array(group),
                np.array(shell))

    def bvh(self):
        V, F = self.merged()[:2]
        return BVHTree.FromPolygons([Vector(p) for p in V], [tuple(f) for f in F], epsilon=0.0), V, F

    # ---- hidden-face culling
    def cull(self, env=None, n_dirs=40, samples=3, report=None):
        """Keep a face when some ray from it (front hemisphere, from its centre and points toward its corners)
        leaves the assembly without hitting anything and env(origin, dir) does not block it. env blocks the
        directions the surroundings hide (the floor, a back wall). Removes the rest; returns (kept, total)."""
        bvh, V, F = self.bvh()
        dirs = fibonacci_dirs(n_dirs)
        keep = np.zeros(len(F), bool)
        for i, f in enumerate(F):
            pts = V[f]
            c = pts.mean(axis=0)
            n = newell(pts)
            if not np.any(n):
                continue
            origins = [c] + [c + (pts[j] - c) * 0.62 for j in range(0, len(f), max(len(f) // samples, 1))][:samples]
            cand = [n] + [d for d in dirs if np.dot(d, n) > 0.08]
            found = False
            for o in origins:
                ov = Vector(o + n * 0.015)
                for d in cand:
                    hit = bvh.ray_cast(ov, Vector(d), 1e5)
                    if hit[0] is not None:
                        continue
                    if env is not None and env.blocks(o, d):
                        continue
                    found = True
                    break
                if found:
                    break
            keep[i] = found
        self.apply_keep(keep)
        if report is not None:
            report.append((int(keep.sum()), len(keep)))
        return int(keep.sum()), len(keep)

    def apply_keep(self, keep):
        k = 0
        new = []
        for sh, g in self.shells:
            m = keep[k:k + len(sh.f)]
            k += len(sh.f)
            if not m.any():
                continue
            f = [x for x, ok in zip(sh.f, m) if ok]
            tags = [x for x, ok in zip(sh.tags, m) if ok]
            used = sorted({i for x in f for i in x})
            remap = {o: n for n, o in enumerate(used)}
            new.append((Shell(sh.v[used], [[remap[i] for i in x] for x in f], tags, sh.slot, sh.kind), g))
        self.shells = new

    @property
    def tris(self):
        return sum(sh.tris for sh, _ in self.shells)

    def build(self, name):
        V, F, slot, tags, group, shell = self.merged()
        present = [s for s in self.slots if self.slots.index(s) in set(slot.tolist())]
        remap = {self.slots.index(s): i for i, s in enumerate(present)}
        obj = ec.new_object(name, V, F, slots=present, face_slots=[remap[int(s)] for s in slot],
                            recalc_normals=False)
        if len(obj.data.polygons) != len(F):
            raise RuntimeError("%s: mesh.validate dropped faces (%d -> %d)" % (name, len(F), len(obj.data.polygons)))
        return obj, tags, group, shell


def fibonacci_dirs(n):
    i = np.arange(n) + 0.5
    phi = np.arccos(1.0 - 2.0 * i / n)
    th = math.pi * (1.0 + 5 ** 0.5) * i
    return np.stack([np.cos(th) * np.sin(phi), np.sin(th) * np.sin(phi), np.cos(phi)], axis=1)


# ---- surroundings: what hides directions from a mesh (culling), occludes it (AO) and where a viewer can stand (seal)
class Env:
    def __init__(self, name, floor=False, wall=False):
        self.name, self.floor, self.wall = name, floor, wall

    def blocks(self, o, d):
        """A ray leaving the surface along d is hidden by the surroundings (floor below, wall behind at +Y)."""
        return (self.floor and d[2] < -1e-4) or (self.wall and d[1] > 0.15)

    def hit_t(self, o, d):
        t = float("inf")
        if self.floor and d[2] < -1e-6:
            t = min(t, max(o[2], 0.0) / -d[2])
        if self.wall and d[1] > 1e-6:
            t = min(t, max(-o[1], 0.0) / d[1])
        return t

    def origin_ok(self, o):
        return not ((self.floor and o[2] < 0.0) or (self.wall and o[1] > 0.0))


ENV_NONE = Env("none")
ENV_FLOOR = Env("floor", floor=True)
ENV_WALL = Env("wall", floor=True, wall=True)


# ================================================================ painting
def vertex_ao(obj, env=None, n_dirs=28, radius=12.0):
    """Per-vertex ambient openness 0..1: cosine-weighted share of hemisphere rays travelling `radius` cm without
    hitting the mesh or the surroundings (a ray that hits at distance t still counts (t / radius)^2)."""
    mesh = obj.data
    V = fc.verts_cm(obj)
    F = [tuple(p.vertices) for p in mesh.polygons]
    bvh = BVHTree.FromPolygons([Vector(p) for p in V], F, epsilon=0.0)
    vn = np.zeros((len(V), 3))
    mesh.vertices.foreach_get("normal", vn.reshape(-1))
    dirs = fibonacci_dirs(n_dirs * 2)
    out = np.ones(len(V))
    for i, (p, n) in enumerate(zip(V, vn)):
        if not np.any(n):
            continue
        ds = dirs[dirs @ n > 0.05]
        w = ds @ n
        o = p + n * 0.03
        ov = Vector(o)
        opn = 0.0
        for d, wt in zip(ds, w):
            t = env.hit_t(o, d) if env is not None else float("inf")
            hit = bvh.ray_cast(ov, Vector(d), radius)
            if hit[0] is not None:
                t = min(t, hit[3])
            opn += wt * (1.0 if t >= radius else (t / radius) ** 2)
        out[i] = opn / max(w.sum(), 1e-9)
    return out


def paint_asm(obj, colours, ao=None, variation=0.06, seed=5, cavity_darken=0.32):
    """colours: (n_faces, 3) linear. Alpha = cavity: curvature cavity x ambient openness."""
    cav = fc.cavity(obj)
    if ao is not None:
        cav = np.clip(np.minimum(cav, 0.35 + 0.65 * ao) * (0.55 + 0.45 * ao), 0.0, 1.0)
    fc.paint(obj, colours, alpha=cav, variation=variation, seed=seed, cavity_darken=cavity_darken)
    return cav


def mix(a, b, t):
    return np.asarray(a, float) * (1.0 - t) + np.asarray(b, float) * t


# ================================================================ review renders
REVIEW_BG = (0.21, 0.215, 0.23)


def remove_object(o):
    data = o.data if o.type == "MESH" else None
    bpy.data.objects.remove(o, do_unlink=True)
    if data is not None and data.users == 0:
        bpy.data.meshes.remove(data)


def copy_object(obj, offset=(0.0, 0.0, 0.0), R=None, name=None):
    """An unparented copy (mesh data copied) moved by offset cm (rotated by R first)."""
    c = bpy.data.objects.new(name or (obj.name + "_Copy"), obj.data.copy())
    bpy.context.scene.collection.objects.link(c)
    v = fc.verts_cm(c)
    if R is not None:
        v = v @ np.asarray(R, float).T
    fc.set_verts_cm(c, v + np.asarray(offset, float))
    return c


def painted_box(name, center, size, rgb):
    v, f = box_vf(center, size)
    o = fc.new_object(name, v, f, slots=("EnvStone",))
    fc.paint(o, np.repeat(np.asarray(rgb, float)[None, :], len(f), axis=0), variation=0.02, cavity_darken=0.0)
    return o


def render_view(objs, path, view, size=(1200, 900), margin=1.08, target_cm=None, half_cm=None, ortho=True,
                eye_cm=None, lens=50.0, shadows=False):
    """One workbench render of objs where they stand (vertex colour, cavity). The orthographic frame fits their
    bounds seen from direction `view` unless half_cm (half the longer image side) is given; eye_cm makes a
    perspective camera at that point looking at target_cm."""
    scene = bpy.context.scene
    objs = list(objs)
    hidden = [o for o in scene.objects if o not in objs and o.type == "MESH"]
    hidden_state = [o.hide_render for o in hidden]
    pts = np.concatenate([fc.verts_cm(o) + np.asarray(o.location, float) * 100.0 for o in objs])
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    target = 0.5 * (lo + hi) if target_cm is None else np.asarray(target_cm, float)
    if eye_cm is not None:
        view = np.asarray(eye_cm, float) - target
    d = _n(view)
    right = _n(np.cross(Z, d)) if abs(d[2]) < 0.999 else X
    up = np.cross(d, right)
    w, h = size
    long_side = float(max(w, h))
    if half_cm is None:
        rel = pts - target
        hw, hh = np.abs(rel @ right).max(), np.abs(rel @ up).max()
        half_cm = max(hw * long_side / w, hh * long_side / h) * margin
    cam_data = bpy.data.cameras.new("_BonesCam")
    cam_data.clip_start, cam_data.clip_end = 0.02, 2000.0
    cam = bpy.data.objects.new("_BonesCam", cam_data)
    scene.collection.objects.link(cam)
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    sh = scene.display.shading
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.filepath, sh.color_type, sh.light, sh.show_cavity, scene.render.film_transparent,
            tuple(scene.world.color), sh.show_shadows, sh.show_specular_highlight)
    try:
        for o in hidden:
            o.hide_render = True
        saved = [o.hide_render for o in objs]
        for o in objs:
            o.hide_render = False
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        sh.light = "STUDIO"
        sh.color_type = "VERTEX"
        sh.show_cavity = True
        scene.render.film_transparent = False
        scene.world.color = REVIEW_BG
        sh.show_shadows = bool(shadows)
        sh.show_specular_highlight = False
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        if ortho and eye_cm is None:
            cam_data.type = "ORTHO"
            cam_data.ortho_scale = 2.0 * half_cm * 0.01
            dist = float(np.linalg.norm(hi - lo)) * 0.02 + 5.0
            eye = target * 0.01 + d * dist
        elif eye_cm is not None:
            cam_data.lens = lens
            eye = np.asarray(eye_cm, float) * 0.01
        else:
            cam_data.lens = lens
            eye = target * 0.01 + d * (half_cm * 0.01 / (18.0 / lens))
        fc._look_at(cam, tuple(eye), tuple(target * 0.01))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        for o, hr in zip(objs, saved):
            o.hide_render = hr
    finally:
        for o, hr in zip(hidden, hidden_state):
            o.hide_render = hr
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
         scene.render.filepath, sh.color_type, sh.light, sh.show_cavity, scene.render.film_transparent) = prev[:9]
        scene.world.color = prev[9]
        sh.show_shadows, sh.show_specular_highlight = prev[10], prev[11]
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return path


def lineup(objs, gap_cm=None, axis=0):
    """Unparented copies of objs laid side by side along X (bbox to bbox, gap_cm apart). Returns the copies."""
    out = []
    x = 0.0
    sizes = [fc.bounds_cm(o) for o in objs]
    gap = gap_cm if gap_cm is not None else 0.25 * max(float((hi - lo)[0]) for lo, hi in sizes)
    for o, (lo, hi) in zip(objs, sizes):
        c = copy_object(o, offset=(x - lo[0], 0.0, 0.0), name="_L_" + o.name)
        out.append(c)
        x += float(hi[0] - lo[0]) + gap
    shift = -0.5 * (x - gap)
    for c in out:
        fc.set_verts_cm(c, fc.verts_cm(c) + np.array([shift, 0.0, 0.0]))
    return out


def sheet(paths, out_path, cols):
    return fc.tile_images(paths, out_path, cols=cols)


# ================================================================ drop-and-settle placement
class HeightField:
    """Top surface of everything placed so far over an XY grid (cm). Parts are dropped onto it from above."""

    def __init__(self, lo_xy, hi_xy, cell=0.7, floor=0.0):
        self.lo = np.asarray(lo_xy, float)[:2]
        self.cell = float(cell)
        self.floor = float(floor)
        self.n = (np.ceil((np.asarray(hi_xy, float)[:2] - self.lo) / cell) + 1).astype(int)
        self.h = np.full(tuple(self.n), self.floor)
        self._bary = {}

    def _ij(self, xy):
        ij = np.round((np.asarray(xy, float)[:, :2] - self.lo) / self.cell).astype(int)
        inside = np.all((ij >= 0) & (ij < self.n), axis=1)
        return np.clip(ij, 0, self.n - 1), inside

    def at(self, xy):
        ij, inside = self._ij(xy)
        out = self.h[ij[:, 0], ij[:, 1]].copy()
        out[~inside] = self.floor
        return out

    def max_disc(self, c, r):
        a = np.linspace(0.0, math.tau, 9)[:-1]
        pts = np.array([[c[0], c[1]]] + [[c[0] + r * math.cos(t), c[1] + r * math.sin(t)] for t in a] +
                       [[c[0] + 0.5 * r * math.cos(t), c[1] + 0.5 * r * math.sin(t)] for t in a])
        return float(self.at(pts).max())

    def bary(self, k):
        if k not in self._bary:
            w = [(i / k, j / k, 1.0 - (i + j) / k) for i in range(k + 1) for j in range(k + 1 - i)]
            self._bary[k] = np.array(w)
        return self._bary[k]

    def add_tris(self, V, T):
        for t in T:
            p = V[list(t)]
            e = max(np.linalg.norm(p[0, :2] - p[1, :2]), np.linalg.norm(p[1, :2] - p[2, :2]),
                    np.linalg.norm(p[2, :2] - p[0, :2]))
            k = int(min(max(math.ceil(e / (0.7 * self.cell)), 1), 60))
            q = self.bary(k) @ p
            ij, inside = self._ij(q)
            if inside.any():
                np.maximum.at(self.h, (ij[inside, 0], ij[inside, 1]), q[inside, 2])

    def add_piece(self, piece):
        for sh in piece.shells:
            tris = [(f[0], f[i], f[i + 1]) for f in sh.f for i in range(1, len(f) - 1)]
            self.add_tris(sh.v, tris)


def sample_points(piece):
    """Vertices + face centres of a piece (the points tested against the height field when dropping it)."""
    pts = [piece.verts()]
    for sh in piece.shells:
        pts.append(np.array([sh.v[f].mean(axis=0) for f in sh.f]))
    return np.concatenate(pts)


def drop(hf, piece, R, xy, sink=0.4, z_floor=0.0):
    """Rotate a rested piece (centred, lowest z 0) by R, move it to xy and lower it until it rests on the height
    field, then sink it a little (nestled, never below z_floor). Returns the placed Piece."""
    p = piece.transformed(R)
    lo, hi = p.bounds()
    p = p.transformed(t=(xy[0] - 0.5 * (lo[0] + hi[0]), xy[1] - 0.5 * (lo[1] + hi[1]), 0.0))
    pts = sample_points(p)
    gap = pts[:, 2] - hf.at(pts)
    dz = -float(gap.min()) - sink
    p = p.transformed(t=(0.0, 0.0, dz))
    low = p.bounds()[0][2]
    if low < z_floor:
        p = p.transformed(t=(0.0, 0.0, z_floor - low))
    return p


def tilt_to(hf, xy, r, gain=0.7):
    """Rotation tipping +Z toward the local slope normal of the height field around xy (radius r)."""
    hx = hf.at(np.array([[xy[0] + r, xy[1]], [xy[0] - r, xy[1]]]))
    hy = hf.at(np.array([[xy[0], xy[1] + r], [xy[0], xy[1] - r]]))
    gx, gy = (hx[0] - hx[1]) / (2.0 * r), (hy[0] - hy[1]) / (2.0 * r)
    nrm = _n(np.array([-gx * gain, -gy * gain, 1.0]))
    return rot_between(Z, nrm)


def bone_pose(hf, xy, yaw_deg, length, roll_deg, max_pitch=38.0):
    """Rotation for a long bone (built along X) lying at xy with the given yaw: pitched to the height field under
    its two ends, rolled about its own axis."""
    a = math.radians(yaw_deg)
    d = np.array([math.cos(a), math.sin(a)]) * length * 0.42
    h1 = hf.max_disc(np.asarray(xy) - d, 2.5)
    h2 = hf.max_disc(np.asarray(xy) + d, 2.5)
    pitch = math.degrees(math.atan2(h2 - h1, length * 0.84))
    pitch = float(np.clip(pitch, -max_pitch, max_pitch))
    return rot_z(yaw_deg) @ rot_y(-pitch) @ rot_x(roll_deg)


# ================================================================ chiselled stone
def chisel_box(center, size, rng, ch=(0.8, 2.0), chip_p=0.3, chip=(2.0, 5.0), bulge=(0.15, 0.55), jitter=0.22,
               flat=("-z",), no_bulge=()):
    """A hand-cut stone block: a box with every edge chamfered by a random amount (corner points pulled in along
    each axis), some corners chipped deep, and each large face bulged into a shallow fan of facets. Faces named in
    flat (-z, +z, -y ...) stay exactly on their plane (resting / stacked faces). Returns (verts, faces)."""
    c = np.asarray(center, float)
    h = np.asarray(size, float) * 0.5
    keys = {(-1, 0): "-x", (1, 0): "+x", (-1, 1): "-y", (1, 1): "+y", (-1, 2): "-z", (1, 2): "+z"}
    pts = []
    plane_of = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                s = np.array([sx, sy, sz], float)
                corner = c + h * s
                a = np.array([rng.uniform(*ch) for _ in range(3)])
                if rng.uniform() < chip_p:
                    k = int(rng.integers(0, 3))
                    a[k] = rng.uniform(*chip)
                a = np.minimum(a, 0.3 * 2 * h)
                for ax in range(3):
                    p = corner.copy()
                    p[ax] -= s[ax] * a[ax]
                    pts.append(p)
                    plane_of.append([keys[(int(s[b]), b)] for b in range(3) if b != ax])
    pts = np.array(pts)
    jit = rng.uniform(-jitter, jitter, pts.shape)
    for i, planes in enumerate(plane_of):
        for key in planes:
            if key in flat:
                jit[i, "xyz".index(key[1])] = 0.0
    pts = pts + jit
    extra = []
    for ax in range(3):
        for sg in (-1, 1):
            key = keys[(sg, ax)]
            other = [b for b in range(3) if b != ax]
            if key in flat or key in no_bulge or min(2 * h[other[0]], 2 * h[other[1]]) < 7.0:
                continue
            p = c.copy()
            p[ax] += sg * (h[ax] + rng.uniform(*bulge))
            for b in other:
                p[b] += rng.uniform(-0.2, 0.2) * h[b]
            extra.append(p)
    if extra:
        pts = np.concatenate([pts, np.array(extra)])
    return hull(pts, dissolve_deg=0.5)


def pyramid_cap(center_xy, z0, z1, half, rng, ch=1.0):
    """A low pointed cap (finial) on a rectangle: hull of a chamfered base band and an apex."""
    cx, cy = center_xy
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for dx, dy in ((ch, 0.0), (0.0, ch)):
                pts.append((cx + sx * (half[0] - dx), cy + sy * (half[1] - dy), z0))
                pts.append((cx + sx * (half[0] - dx) * 0.97, cy + sy * (half[1] - dy) * 0.97, z0 + 2.0))
    pts.append((cx + rng.uniform(-0.6, 0.6), cy + rng.uniform(-0.6, 0.6), z1))
    return hull(np.array(pts), dissolve_deg=0.5)


# ---- 2D polygon helpers (copied from build_station_kitchen.py; that builder must never be imported)
def _n2(v):
    v = np.asarray(v, float)
    return v / max(float(np.hypot(v[0], v[1])), 1e-12)


def area2(p):
    p = np.asarray(p, float)
    return 0.5 * float(np.sum(p[:, 0] * np.roll(p[:, 1], -1) - np.roll(p[:, 0], -1) * p[:, 1]))


def ccw2(p):
    p = np.asarray(p, float)
    return p if area2(p) > 0 else p[::-1].copy()


def inset_edges(p, d):
    """Offset each edge i (p[i] -> p[i + 1]) of a CCW polygon inward by d[i]; returns the new vertices."""
    p = np.asarray(p, float)
    n = len(p)
    d = np.broadcast_to(np.asarray(d, float), (n,))
    lines = []
    for i in range(n):
        e = _n2(p[(i + 1) % n] - p[i])
        lines.append((p[i] + np.array([-e[1], e[0]]) * d[i], e))
    out = []
    for i in range(n):
        (p1, d1), (p2, d2) = lines[i - 1], lines[i]
        m = np.array([d1, -d2]).T
        if abs(np.linalg.det(m)) < 1e-7:
            out.append(p2)
        else:
            out.append(p1 + d1 * np.linalg.solve(m, p2 - p1)[0])
    return np.array(out)


def clip_half(poly, a, b, keep_left, new_tag):
    """Sutherland-Hodgman against the line a -> b. poly = [(point, tag of the edge leaving it)]."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    e = b - a

    def side(q):
        s = e[0] * (q[1] - a[1]) - e[1] * (q[0] - a[0])
        return s if keep_left else -s

    out = []
    n = len(poly)
    for i in range(n):
        cur, tag = poly[i]
        nxt = poly[(i + 1) % n][0]
        sc_, sn = side(cur), side(nxt)
        cin, nin = sc_ >= -1e-9, sn >= -1e-9
        if cin:
            out.append((cur, tag))
        if cin != nin:
            t = sc_ / (sc_ - sn)
            out.append((cur + (nxt - cur) * t, new_tag if cin else tag))
    clean = []
    for i in range(len(out)):
        if np.linalg.norm(out[i][0] - out[(i + 1) % len(out)][0]) > 1e-6:
            clean.append(out[i])
    return clean


def tagged_area(poly):
    return area2(np.array([q for q, _ in poly])) if len(poly) >= 3 else 0.0


def subtract_convex(poly, hole, hole_tag):
    hole = ccw2(hole)
    pieces, rem = [], poly
    for i in range(len(hole)):
        a, b = hole[i], hole[(i + 1) % len(hole)]
        outside = clip_half(rem, a, b, False, hole_tag)
        if tagged_area(outside) > 1.0:
            pieces.append(outside)
        rem = clip_half(rem, a, b, True, "seam")
        if tagged_area(rem) < 1e-6:
            break
    return pieces


def subtract_all(poly_pts, holes):
    """[(pts, tags)] convex pieces of a CCW polygon minus every (convex hole, tag)."""
    pieces = [[(np.asarray(q, float), "outer") for q in ccw2(poly_pts)]]
    for hole, tag in holes:
        hole = ccw2(hole)
        nxt = []
        for pc in pieces:
            inter = pc
            for i in range(len(hole)):
                inter = clip_half(inter, hole[i], hole[(i + 1) % len(hole)], True, "seam")
                if len(inter) < 3:
                    break
            if tagged_area(inter) < 1e-6:
                nxt.append(pc)
            else:
                nxt += subtract_convex(pc, hole, tag)
        pieces = nxt
    return [(np.array([q for q, _ in pc]), [t for _, t in pc]) for pc in pieces]


def gothic_arch(cx, z_base, width, jamb, segs=4):
    """Pointed (equilateral) arch opening, CCW in (x, z): base line, right jamb, right arc, apex, left arc."""
    hw = width * 0.5
    zs = z_base + jamb
    pts = [(cx - hw, z_base), (cx + hw, z_base), (cx + hw, zs)]
    for k in range(1, segs):
        a = math.radians(60.0 * k / segs)
        pts.append((cx - hw + width * math.cos(a), zs + width * math.sin(a)))
    pts.append((cx, zs + width * math.sin(math.radians(60.0))))
    for k in range(segs - 1, 0, -1):
        a = math.radians(60.0 * k / segs)
        pts.append((cx + hw - width * math.cos(a), zs + width * math.sin(a)))
    pts.append((cx - hw, zs))
    return np.array(pts)


def cross_holes(cx, z0, height, span, bar, arm_z):
    """A Latin cross as three disjoint convex rectangles (shaft, left arm, right arm) in (x, z)."""
    hb = bar * 0.5
    shaft = [(cx - hb, z0), (cx + hb, z0), (cx + hb, z0 + height), (cx - hb, z0 + height)]
    left = [(cx - span * 0.5, arm_z), (cx - hb, arm_z), (cx - hb, arm_z + bar), (cx - span * 0.5, arm_z + bar)]
    right = [(cx + hb, arm_z), (cx + span * 0.5, arm_z), (cx + span * 0.5, arm_z + bar), (cx + hb, arm_z + bar)]
    return [np.array(shaft), np.array(left), np.array(right)]


def to3(p2, y):
    p2 = np.asarray(p2, float)
    y = np.broadcast_to(np.asarray(y, float), (len(p2),))
    return np.column_stack([p2[:, 0], y, p2[:, 1]])


def polygon_area(pts):
    pts = np.asarray(pts, float)
    s = np.zeros(3)
    for i in range(len(pts)):
        s += np.cross(pts[i], pts[(i + 1) % len(pts)])
    return 0.5 * float(np.linalg.norm(s))


def prism_piece(poly, tags, y_front, y_back, ch, bump=0.0, face_tag="face"):
    """A convex (x, z) polygon extruded from y_back to y_front (front toward -Y). Edges tagged outer get a front
    chamfer of ch; hole edges run straight to the front; seam edges get no side faces (a coplanar neighbour piece
    continues the solid). The front is a fan round a centre pushed bump toward -Y. Returns (verts, faces, tags)."""
    tags = list(tags)
    p = np.asarray(poly, float)
    if area2(p) < 0:
        p = p[::-1].copy()
        tags = tags[::-1]
        tags = tags[1:] + tags[:1]
    n = len(p)
    d = [ch if t == "outer" else 0.0 for t in tags]
    top = inset_edges(p, d)
    y_mid = y_front + ch
    cen = top.mean(axis=0)
    flat = abs(bump) < 1e-6
    verts = [to3(p, y_back), to3(p, y_mid), to3(top, y_front)]
    if not flat:
        verts.append([[cen[0], y_front - bump, cen[1]]])
    verts = np.concatenate(verts)
    faces, ftags = [], []
    for i in range(n):
        j = (i + 1) % n
        t = tags[i]
        if t == "outer":
            faces.append([i, j, n + j, n + i])
            ftags.append("side")
            faces.append([n + i, n + j, 2 * n + j, 2 * n + i])
            ftags.append("chamfer")
        elif t != "seam":
            faces.append([i, j, 2 * n + j, 2 * n + i])          # a recess wall: one quad, front to back
            ftags.append("holewall")
        if not flat:
            faces.append([2 * n + i, 2 * n + j, 3 * n])
            ftags.append(face_tag)
    if flat:
        faces.append([2 * n + i for i in range(n)])        # a flat front: n - 2 tris, not a fan of n
        ftags.append(face_tag)
    faces.append(list(range(n)))
    ftags.append("back")
    keep_f, keep_t = [], []
    for f, t in zip(faces, ftags):
        if polygon_area(verts[f]) > 1e-4:
            keep_f.append(f)
            keep_t.append(t)
    return verts, keep_f, keep_t


def carved_block(asm, x0, x1, z0, z1, y_front, y_back, holes, rng, slot="EnvStone", ch=1.6, kind="post",
                 R=None, t=None, group=None):
    """A stone course whose front (toward -Y in its own frame) carries recesses: holes = [(convex (x, z) polygon,
    depth cm, tag)]. Built from flush convex pieces + a floor piece per recess; R / t place the whole block.
    Returns the group id."""
    g = asm.new_group() if group is None else group
    rect = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    pieces = subtract_all(rect, [(h[0], "hole") for h in holes])
    bump = rng.uniform(0.3, 0.8)

    def place(v):
        if R is not None:
            v = v @ np.asarray(R, float).T
        if t is not None:
            v = v + np.asarray(t, float)
        return v

    for pp, tt in pieces:
        v, f, tags = prism_piece(pp, tt, y_front, y_back, ch, bump=bump if len(pieces) == 1 else 0.0)
        tags = ["%s/%s" % (kind, x) for x in tags]
        vv = place(v)
        asm.add_shell(Shell(vv, orient_convex(vv, f), tags, slot, "block"), g)
    for poly, depth, tag in holes:
        v, f, tags = prism_piece(poly, ["seam"] * len(poly), y_front + depth, y_back, 0.0)
        tags = ["%s/%s" % (kind, tag) if x == "face" else "%s/%s" % (kind, x) for x in tags]
        vv = place(v)
        asm.add_shell(Shell(vv, orient_convex(vv, f), tags, slot, "block"), g)
    return g


# ================================================================ checks
def shell_bvhs(asm):
    out = []
    for sh, g in asm.shells:
        tris = [(f[0], f[i], f[i + 1]) for f in sh.f for i in range(1, len(f) - 1)]
        out.append(BVHTree.FromPolygons([Vector(p) for p in sh.v], tris, epsilon=0.0))
    return out


def contact_report(asm, roots_fn, tol=0.12):
    """Every shell must touch (intersect, or come within tol cm of) another shell or a root support; returns the
    list of shells (index, group, tag) not connected to a root through touching shells."""
    shells = [sh for sh, _ in asm.shells]
    groups = [g for _, g in asm.shells]
    bvhs = shell_bvhs(asm)
    lo = [sh.v.min(axis=0) - tol for sh in shells]
    hi = [sh.v.max(axis=0) + tol for sh in shells]
    n = len(shells)
    adj = [set() for _ in range(n)]
    for i in range(n):
        for j in range(i + 1, n):
            if np.any(lo[i] > hi[j]) or np.any(lo[j] > hi[i]):
                continue
            touch = bool(bvhs[i].overlap(bvhs[j]))
            if not touch:
                a, b = (i, j) if len(shells[i].v) <= len(shells[j].v) else (j, i)
                for p in shells[a].v:
                    hit = bvhs[b].find_nearest(Vector(p), tol)
                    if hit[0] is not None:
                        touch = True
                        break
            if touch:
                adj[i].add(j)
                adj[j].add(i)
    seen = set(i for i in range(n) if roots_fn(shells[i]))
    stack = list(seen)
    while stack:
        i = stack.pop()
        for j in adj[i]:
            if j not in seen:
                seen.add(j)
                stack.append(j)
    return [(i, groups[i], shells[i].tags[0]) for i in range(n) if i not in seen]


def root_floor(sh, tol=0.12):
    return sh.v[:, 2].min() <= tol


def root_floor_or_wall(sh, tol=0.12):
    return sh.v[:, 2].min() <= tol or sh.v[:, 1].max() >= -tol


def zfight_report(obj, shell_of_face, min_area=0.4, dist=0.2):
    """Faces of different shells facing the same way within dist cm of each other where they overlap (coplanar
    overlap = z-fighting). Returns a list of (face, other face, distance)."""
    mesh = obj.data
    V = fc.verts_cm(obj)
    F = [tuple(p.vertices) for p in mesh.polygons]
    bvh = BVHTree.FromPolygons([Vector(p) for p in V], F, epsilon=0.0)
    N = fc.face_normals(obj)
    bad = []
    for i, f in enumerate(F):
        pts = V[list(f)]
        if polygon_area(pts) < min_area:
            continue
        c = pts.mean(axis=0)
        probes = [c] + [c + (p - c) * 0.6 for p in pts]
        hit_i = False
        for q in probes:
            for loc, nrm, idx, dd in bvh.find_nearest_range(Vector(q), dist):
                if idx == i or shell_of_face[idx] == shell_of_face[i]:
                    continue
                if float(np.dot(N[idx], N[i])) > 0.995 and abs(float(np.dot(N[i], np.array(loc) - q))) < dist:
                    bad.append((i, idx, round(float(dd), 3)))
                    hit_i = True
                    break
            if hit_i:
                break
    return bad


def seal_report(obj, env=None, n=3000, seed=11):
    """Rays from all round the object (outside its bounds) toward random points inside them; the first hit must be a
    FRONT face. Returns (rays that hit, back-face hits, examples). env names the surroundings: env_floor drops rays
    starting under the floor, env_wall also those starting behind the wall (y > 0)."""
    rng = np.random.default_rng(seed)
    V = fc.verts_cm(obj)
    F = [tuple(p.vertices) for p in obj.data.polygons]
    bvh = BVHTree.FromPolygons([Vector(p) for p in V], F, epsilon=0.0)
    N = fc.face_normals(obj)
    lo, hi = V.min(axis=0), V.max(axis=0)
    c = 0.5 * (lo + hi)
    R = float(np.linalg.norm(hi - lo)) * 0.75 + 5.0
    hits = back = 0
    ex = []
    tries = 0
    while hits < n and tries < n * 8:
        tries += 1
        o = c + _n(rng.normal(size=3)) * R
        tgt = lo + rng.uniform(size=3) * (hi - lo)
        d = _n(tgt - o)
        if env is not None and not env.origin_ok(o):
            continue
        hit = bvh.ray_cast(Vector(o), Vector(d), 4 * R)
        if hit[0] is None:
            continue
        hits += 1
        if float(np.dot(N[hit[2]], d)) > 1e-3:
            back += 1
            if len(ex) < 6:
                ex.append([round(float(x), 1) for x in hit[0]])
    return hits, back, ex


# ================================================================ hand-cut parts (art review 2026-10-23)
# The loose skulls, jaws, long bones and ribs are built like the packed skull (flat chiselled planes, prisms, hull
# knobs) so every bone in the family comes from one kit: no field-meshed eggs next to hand-cut fills.
def _ico_pts(c, r, rng, jit=0.12):
    """12 jittered icosahedron points (a faceted knob), random but seeded orientation, radii r = (rx, ry, rz)."""
    t = (1.0 + 5 ** 0.5) / 2.0
    base = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
            (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    P = np.array(base, float) / math.sqrt(1.0 + t * t)
    P = P @ rot_z(rng.uniform(0.0, 360.0)).T @ rot_x(rng.uniform(0.0, 360.0)).T
    P = P * (1.0 + rng.uniform(-jit, jit, (len(P), 1)))
    return np.asarray(c, float) + P * np.asarray(r, float)


def _cube_pts(c, r, rng, jit=0.12):
    """6 jittered octahedron points, randomly turned (a chiselled diamond knob, the cheap LOD: ~12 tris a knob; the
    random turn keeps neighbouring knobs from sharing face planes)."""
    P = np.array([(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)], float) * 1.05
    P = P @ rot_z(rng.uniform(0.0, 360.0)).T @ rot_x(rng.uniform(0.0, 360.0)).T
    P = P * (1.0 + rng.uniform(-jit, jit, P.shape))
    return np.asarray(c, float) + P * np.asarray(r, float)


def _section_x(x, cy, cz, ry, rz, n, rot, rng, jit=0.05):
    """An n-sided section in the YZ plane at x (a bone shaft station)."""
    pts = []
    for k in range(n):
        a = rot + k * math.tau / n
        f = 1.0 + rng.uniform(-jit, jit)
        pts.append((x, cy + ry * f * math.cos(a), cz + rz * f * math.sin(a)))
    return np.array(pts)


def loft(sections, caps=(True, True)):
    """A closed tube through same-sized sections (lists of points): quads between neighbours, n-gon end caps.
    Returns (verts, faces) wound outward."""
    V, idx = [], []
    for s in sections:
        row = []
        for p in s:
            V.append(np.asarray(p, float))
            row.append(len(V) - 1)
        idx.append(row)
    k = len(sections[0])
    F = []
    for a, b in zip(idx[:-1], idx[1:]):
        for i in range(k):
            F.append([a[i], a[(i + 1) % k], b[(i + 1) % k], b[i]])
    if caps[0]:
        F.append(idx[0][::-1])
    if caps[1]:
        F.append(list(idx[-1]))
    v = np.array(V)
    return v, orient_closed(v, F)


# ---- long bones: a faceted 6-sided shaft (3 segments, each station twisted 6-12 deg so the facets break along the
# length) and convex hull knobs (head / trochanter, two condyles ...) that swallow the shaft ends: the dog-bone
# silhouette reads at 10 m.
CUT_BONE = {
    # name: (shaft station x, shaft radius (y; z = 0.93 y), bend in y per station, lumps (end, centre, radii))
    "Femur": ((-13.6, -4.6, 4.6, 13.4), (2.75, 2.5, 2.5, 2.8), (0.0, 0.25, 0.3, 0.0),
              [("p", (-19.2, 2.1, 0.4), (3.75, 3.75, 3.65)), ("p", (-17.0, -2.6, 0.15), (2.9, 2.5, 2.95)),
               ("d", (19.3, 2.6, -0.3), (3.6, 3.0, 3.6)), ("d", (19.3, -2.6, -0.3), (3.6, 3.0, 3.6))]),
    "Humerus": ((-9.8, -3.2, 3.2, 9.8), (2.45, 2.3, 2.3, 2.5), (0.0, 0.2, 0.2, 0.0),
                [("p", (-12.9, 0.9, 0.3), (3.45, 3.35, 3.3)), ("p", (-11.9, -2.3, 0.2), (2.2, 1.8, 2.1)),
                 ("d", (12.7, 1.95, -0.1), (2.4, 2.1, 2.1)), ("d", (12.7, -1.95, -0.1), (2.3, 2.0, 2.0))]),
    "Tibia": ((-11.4, -4.0, 4.0, 11.6), (2.8, 2.35, 2.3, 2.45), (0.0, 0.0, 0.15, 0.0),
              [("p", (-14.6, 2.3, 0.0), (3.1, 2.95, 2.9)), ("p", (-14.6, -2.3, 0.0), (3.1, 2.95, 2.9)),
               ("d", (15.0, 0.4, 0.0), (2.75, 2.85, 2.45)), ("d", (15.5, -2.1, -0.1), (1.7, 1.5, 1.6))]),
}


def make_cut_long_bone(name, lod="full", seed=0):
    """Femur (45), FemurB (38, bent), Humerus (32), Tibia (36) along X, centred. lod full / mid: icosahedron knobs and
    a 3-segment shaft (~150 tris); lite: block knobs and a 2-segment shaft (~80 tris) for packed lanes."""
    key = "Femur" if name == "FemurB" else name
    xs, rs, ys, lumps = CUT_BONE[key]
    rng = np.random.default_rng(4001 + 97 * seed + ("Femur", "FemurB", "Humerus", "Tibia").index(name))
    k, kr, bend = 1.0, 1.0, 0.0
    if name == "FemurB":
        k = 38.0 / 45.0
        kr = 2.25 / (2.5 * k)                 # the shorter bone keeps a ~4.5 cm shaft
        bend = 1.6
    xs = [x * k for x in xs]
    rs = [r * k * kr for r in rs]
    ys = [y * k + bend * w for y, w in zip(ys, (0.0, 0.75, 0.8, 0.0))]
    if lod == "lite":
        xs = [xs[0], 0.5 * (xs[1] + xs[2]), xs[3]]
        rs = [rs[0], 0.5 * (rs[1] + rs[2]), rs[3]]
        ys = [ys[0], 0.5 * (ys[1] + ys[2]), ys[3]]
    rot = rng.uniform(0.0, math.pi / 3.0)
    secs = []
    for x, r, y in zip(xs, rs, ys):
        secs.append(_section_x(x, y, 0.0, r, r * 0.93, 6, rot, rng))
        rot += math.radians(rng.uniform(6.0, 12.0))
    v, f = loft(secs)
    shells = [Shell(v, f, "shaft", "EnvBone", "shaft")]
    pts_fn = _cube_pts if lod == "lite" else _ico_pts
    for i, (end, c, r) in enumerate(lumps):
        c = np.array(c, float) * k
        r = np.array(r, float) * k
        j = 0 if end == "p" else -1
        sgn = 1.0 if end == "p" else -1.0
        # the hull's inner ring sits 1.2-1.5 cm toward the middle and 4 % wider than the shaft there, so the shaft
        # end is buried inside the knob
        ring = _section_x(xs[j] + sgn * (1.2 + 0.25 * i), ys[j], 0.0, rs[j] * 1.04, rs[j] * 0.97,
                          4 if lod == "lite" else 6, rng.uniform(0.0, 1.0), rng, jit=0.02)
        hv, hf = hull(np.concatenate([ring, pts_fn(c, r, rng)]), dissolve_deg=0.5)
        shells.append(Shell(hv, hf, "knob", "EnvBone", "knob"))
    return Piece(name, shells, {"kind": name, "lod": lod, "long": True})


def make_cut_rib(lod="full", seed=0, chord=24.0):
    """A rib lying flat (arc in XY, flat side down at z = 0): a band ~3.2 wide x 1.6 thick of 5-sided sections and a
    head knob at -X. ~100 tris."""
    rng = np.random.default_rng(5003 + seed)
    R0 = chord / (2.0 * math.sin(math.radians(68.0)))
    n = 9 if lod == "full" else 7
    angs = np.radians(np.linspace(158.0, 22.0, n))
    prof = [(-1.5, -0.8), (1.5, -0.8), (1.62, 0.1), (0.0, 0.8), (-1.62, 0.1)]
    secs = []
    for i, a in enumerate(angs):
        c = np.array([R0 * math.cos(a), R0 * math.sin(a) - R0 * math.cos(math.radians(68.0)) - 3.0, 0.8])
        u = np.array([math.cos(a), math.sin(a), 0.0])
        t = i / (n - 1)
        w = (0.8 + 0.5 * t) if t < 0.4 else (1.0 - 0.15 * (t - 0.4) / 0.6)
        th = 1.0 - 0.15 * t
        sec = [c + u * (px * w + rng.uniform(-0.08, 0.08)) + Z * (pz * th + (0.0 if pz < 0 else rng.uniform(-0.04, 0.04)))
               for px, pz in prof]
        secs.append(np.array(sec))
    v, f = loft(secs)
    shells = [Shell(v, f, "shaft", "EnvBone", "shaft")]
    c0 = secs[0].mean(axis=0)
    tan = _n(secs[0].mean(axis=0) - secs[1].mean(axis=0))
    knob_c = c0 + tan * 0.9 + np.array([0.0, 0.0, 0.1])
    ring = 0.5 * (secs[1] + secs[0])
    ring = ring.mean(axis=0) + (ring - ring.mean(axis=0)) * 1.04
    pts = (_ico_pts if lod == "full" else _cube_pts)(knob_c, (1.5, 1.45, 0.85), rng, jit=0.08)
    pts[:, 2] = np.maximum(pts[:, 2], 0.0)
    hv, hf = hull(np.concatenate([ring, pts]), dissolve_deg=0.5)
    shells.append(Shell(hv, hf, "knob", "EnvBone", "knob"))
    return Piece("Rib", shells, {"kind": "Rib", "lod": lod, "long": True})


# ---- the hand-cut loose skull: the packed skull's face (flat chiselled plane, inset pentagon orbits, a deep
# triangular nasal notch, a 2.5 cm tooth band cut by three slits) on an 8-sided prism dome, with zygomatic wedges
# out to the sides under the orbits and a brow bar. Cranium coordinates: face plane y = 0 toward -Y, bite z = 0.
def make_cut_skull(kind="A", variant=0, lod="full", crack_seed=0):
    """kind A / B (intact cranium; A gets the cut jaw from make_cut_jaw in the builder), C (a big chiselled break in
    the crown with a recessed dark floor). lod full: 4 dome rings + brow bar (~200 tris cranium); mid: 3 rings."""
    from mathutils.geometry import tessellate_polygon
    rng = np.random.default_rng(2003 + 41 * variant + {"A": 0, "B": 7, "C": 13}[kind])

    def J(a):
        return float(rng.uniform(-a, a))
    v3 = variant % 3
    wide = (0.0, 0.3, -0.2)[v3]
    tall = (0.0, -0.3, 0.35)[v3]
    long_ = (0.0, 0.6, -0.4)[v3]
    V, F, T = [], [], []

    def vid(x, y, z):
        V.append((float(x), float(y), float(z)))
        return len(V) - 1
    # ---- face plane outline (y = 0)
    t0 = vid(-6.0 - wide + J(0.15), 0.0, 10.7 + tall + J(0.2))
    t1 = vid(6.0 + wide + J(0.15), 0.0, 10.7 + tall + J(0.2))
    c0 = vid(-6.4 - wide + J(0.15), 0.0, 4.3 + J(0.2))
    c1 = vid(6.4 + wide + J(0.15), 0.0, 4.3 + J(0.2))
    k0 = vid(-3.25, 0.0, 2.5)
    k1 = vid(3.25, 0.0, 2.5)
    slit_x = [-1.6 + J(0.1), J(0.1), 1.6 + J(0.1)]
    gs = [vid(x, 0.0, 2.44 - (0.02 if i == 1 else 0.0)) for i, x in enumerate(slit_x)]
    # ---- orbits (pentagons, ~4.6 x 4.4 cm, 2 cm deep) and the nasal notch (2.4 cm deep)
    orb = [(1.05, 9.55 + tall), (5.15, 9.65 + tall), (5.65, 6.7), (3.65, 5.15), (1.1, 6.35)]
    if v3 == 1:
        orb = [(1.05, 9.5 + tall), (5.05, 9.4 + tall), (5.7, 6.4), (3.4, 5.1), (1.0, 6.5)]
    elif v3 == 2:
        orb = [(1.0, 9.45 + tall), (5.2, 9.75 + tall), (5.5, 6.9), (3.8, 5.25), (1.1, 6.2)]
    orbits = []
    for sg in (-1.0, 1.0):
        loop = [vid(sg * (x + J(0.12)), 0.0, z + J(0.12)) for x, z in orb]
        orbits.append(loop if sg > 0 else loop[::-1])
    nas = [vid(J(0.1), 0.0, 5.75 + J(0.1)), vid(-1.2 + J(0.08), 0.0, 3.1), vid(1.2 + J(0.08), 0.0, 3.1)]
    outer = [k0] + gs + [k1, c1, t1, t0, c0]
    loops = [outer] + orbits + [nas]
    flat = [i for lp in loops for i in lp]
    for a, b, c in tessellate_polygon([[(V[i][0], V[i][2], 0.0) for i in lp] for lp in loops]):
        ia, ib, ic = flat[a], flat[b], flat[c]
        cz = (V[ia][2] + V[ib][2] + V[ic][2]) / 3.0
        cx = (V[ia][0] + V[ib][0] + V[ic][0]) / 3.0
        F.append([ia, ib, ic])
        T.append("brow" if cz > 9.4 + tall else ("cheek" if abs(cx) > 5.2 else "face"))
    for loop, tag, depth in ((orbits[0], "socket", 2.0), (orbits[1], "socket", 2.0), (nas, "nasal", 2.4)):
        pts = np.array([V[i] for i in loop])
        c = pts.mean(axis=0)
        apex = vid(c[0], depth, c[2] - 0.25)
        for i in range(len(loop)):
            F.append([loop[i], loop[(i + 1) % len(loop)], apex])
            T.append(tag)

    # ---- tooth band: 2.5 cm, four teeth, three slits cut 0.9 cm into the bite
    def yb(x):
        return 0.55 + 0.07 * x * x
    b0 = vid(-3.1, yb(-3.1), 0.0)
    b1 = vid(3.1, yb(3.1), 0.0)
    Ls, Qs, Rs, Ms = [], [], [], []
    for x in slit_x:
        hw = 0.27 + J(0.04)
        Ls.append(vid(x - hw, yb(x - hw), 0.0))
        Qs.append(vid(x, yb(x) + 0.9, 0.3))
        Rs.append(vid(x + hw, yb(x + hw), 0.0))
        Ms.append(vid(x, 0.56 * yb(x), 1.1 + J(0.1)))
    tops = [k0] + gs + [k1]
    lefts = [b0] + Rs
    rights = Ls + [b1]
    for j in range(4):
        poly = ([tops[j]] + ([Ms[j - 1]] if j > 0 else []) + [lefts[j], rights[j]] + ([Ms[j]] if j < 3 else []) +
                [tops[j + 1]])
        for i in range(1, len(poly) - 1):
            F.append([poly[0], poly[i], poly[i + 1]])
            T.append("tooth")
    for i in range(3):
        F.append([Ms[i], Ls[i], Qs[i]])
        T.append("toothgap")
        F.append([Ms[i], Qs[i], Rs[i]])
        T.append("toothgap")
    # ---- dome: the front boundary loop zipped to 8-sided rings, a flat occiput cap
    B = [t1, t0, c0, k0, b0]
    for i in range(3):
        B += [Ls[i], Qs[i], Rs[i]]
    B += [b1, k1, c1]

    def ring(y, top, up, mid, bot, jy=0.25, j=0.15):
        (ht, zt), (hu, zu), (hm, zm), (hb, zb) = top, up, mid, bot
        pts = [(ht, zt + tall), (-ht, zt + tall), (-(hu + wide), zu + tall), (-(hm + wide), zm), (-hb, zb), (hb, zb),
               (hm + wide, zm), (hu + wide, zu + tall)]
        return [vid(x + J(j), y + J(jy), z + (J(j) if z > 1.0 else J(0.04))) for x, z in pts]
    rings = [ring(4.3, (3.0, 14.7), (6.4, 12.1), (7.0, 7.0), (4.8, 0.15)),
             ring(10.6 + 0.5 * long_, (3.3, 16.3), (6.9, 13.5), (7.3, 7.6), (4.6, 0.1))]
    if lod == "full":
        rings.append(ring(16.3 + long_, (2.8, 15.0), (5.9, 12.5), (6.3, 7.4), (3.9, 1.3)))
        rings.append(ring(19.7 + long_, (1.5, 12.3), (3.3, 10.7), (3.7, 7.1), (2.2, 3.6), jy=0.0))
    else:
        rings.append(ring(18.6 + long_, (2.0, 13.4), (4.4, 11.5), (4.9, 7.2), (2.9, 2.4), jy=0.0))
    zc = 5.3

    def ang(i):
        return math.atan2(V[i][2] - zc, V[i][0])
    for f in _zipper(B, rings[0], [ang(i) for i in B], [ang(i) for i in rings[0]]):
        F.append(list(f))
        T.append("bone")
    pocket_quad = (rings[0][1], rings[0][2], rings[1][2], rings[1][1]) if kind == "C" else None
    for ra, rb in zip(rings[:-1], rings[1:]):
        for i in range(8):
            q = [ra[i], ra[(i + 1) % 8], rb[(i + 1) % 8], rb[i]]
            if pocket_quad is not None and tuple(q) == pocket_quad:
                continue
            F.append(q)
            T.append("bone")
    # occiput: a low 8-sided pyramid (reads round from behind, not a flat plate)
    last = np.array([V[i] for i in rings[-1]])
    apex = vid(*(last.mean(axis=0) + np.array([J(0.2), 1.1, J(0.2)])))
    for i in range(8):
        F.append([rings[-1][i], rings[-1][(i + 1) % 8], apex])
        T.append("bone")
    if pocket_quad is not None:
        _pocket(V, F, T, vid, pocket_quad, np.random.default_rng(77 + crack_seed), depth=1.8)
    v = np.array(V)
    shells = [Shell(v, orient_closed(v, F), T, "EnvBone", "skull")]
    # ---- zygomatic wedges (2-2.5 cm tall, proud of the face plane, running back as the arch) and the brow bar
    for s in (-1.0, 1.0):
        w = s * wide
        # a wedge: high and proud under the orbit, sloping down and back toward the arch (no flat side tab)
        pts = np.array([(s * 3.9 + w, -0.5, 4.8), (s * 6.2 + w, -0.25, 4.25), (s * 6.55 + w, 0.3, 2.9),
                        (s * 4.2 + w, -0.25, 2.6), (s * 6.85 + w, 3.4, 3.8), (s * 6.85 + w, 3.6, 2.8),
                        (s * 6.6 + w, 7.4, 3.4), (s * 6.6 + w, 7.4, 2.75), (s * 4.6 + w, 2.5, 4.9),
                        (s * 4.6 + w, 2.5, 2.5)]) + rng.uniform(-0.1, 0.1, (10, 3))
        hv, hf = hull(pts, dissolve_deg=0.5)
        shells.append(Shell(hv, hf, "cheek", "EnvBone", "cheek"))
    if lod == "full":
        zb = 9.85 + tall
        pts = []
        for s in (-1.0, 1.0):
            pts += [(s * (5.9 + wide), -0.32, zb), (s * (5.8 + wide), -0.2, zb + 0.8),
                    (s * (5.5 + wide), 1.3, zb + 1.6), (s * (5.6 + wide), 1.2, zb)]
        pts += [(0.0, -0.28, zb - 0.15), (0.0, -0.18, zb + 0.7)]
        hv, hf = hull(np.array(pts) + rng.uniform(-0.06, 0.06, (len(pts), 3)), dissolve_deg=0.5)
        shells.append(Shell(hv, hf, "brow", "EnvBone", "brow"))
    return Piece("Skull_" + kind, shells, {"kind": kind, "lod": lod, "variant": variant})


def _pocket(V, F, T, vid, quad, rng, depth=1.8, m=7):
    """Replace one dome quad by a chiselled break: a jagged rim inside the quad, walls and a floor recessed `depth` cm
    (all tagged 'hole', painted dark A = 0), the rest of the quad re-triangulated around the rim."""
    from mathutils.geometry import tessellate_polygon
    A, Bq, C, D = [np.array(V[i]) for i in quad]

    def bil(u, v):
        return A * (1 - u) * (1 - v) + Bq * u * (1 - v) + C * u * v + D * (1 - u) * v
    n = newell(np.array([A, Bq, C, D]))
    cen = bil(0.5, 0.5)
    if np.dot(n, cen - np.array([0.0, 9.0, 7.0])) < 0.0:
        n = -n
    rim_uv = []
    for i in range(m):
        a = i * math.tau / m + rng.uniform(-0.2, 0.2)
        r = (0.43 if i % 2 == 0 else 0.25) * rng.uniform(0.9, 1.08)
        rim_uv.append((float(np.clip(0.5 + r * math.cos(a), 0.07, 0.93)),
                       float(np.clip(0.5 + r * math.sin(a), 0.07, 0.93))))
    rim = [vid(*bil(u, v)) for u, v in rim_uv]
    outer_uv = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    flat = list(quad) + rim
    for a, b, c in tessellate_polygon([[(u, v, 0.0) for u, v in outer_uv], [(u, v, 0.0) for u, v in rim_uv]]):
        F.append([flat[a], flat[b], flat[c]])
        T.append("bone")
    fl_uv = [(0.5 + (u - 0.5) * 0.6, 0.5 + (v - 0.5) * 0.6) for u, v in rim_uv]
    floor = [vid(*(bil(u, v) - n * depth)) for u, v in fl_uv]
    for i in range(m):
        F.append([rim[i], rim[(i + 1) % m], floor[(i + 1) % m], floor[i]])
        T.append("hole")
    for a, b, c in tessellate_polygon([[(u, v, 0.0) for u, v in fl_uv]]):
        F.append([floor[a], floor[b], floor[c]])
        T.append("hole")


def make_cut_jaw(variant=0, open_deg=2.0):
    """The hand-cut mandible in cut-skull coordinates (bite at z = 0): a 5-sided section lofted round the dental
    arch (chin ~0.7 cm behind the maxilla front), a lower tooth band cut by three slits, and two rami ~2.5 x 1.5 cm
    rising back to condyles that sink 0.5 cm into the cranium base. Opened open_deg about the hinge, then lifted so
    the tooth rows touch."""
    rng = np.random.default_rng(3301 + 13 * variant)

    def J(a):
        return float(rng.uniform(-a, a))

    def yl(x):
        return 0.95 + 0.075 * x * x
    V = []

    def vid(p):
        V.append(np.asarray(p, float))
        return len(V) - 1
    side = [(4.95, 7.7), (4.8, 5.3), (4.15, 3.1)]
    slit_x = [-1.55 + J(0.1), J(0.1), 1.55 + J(0.1)]
    st = [(-x, y, "side") for x, y in side] + [(-3.0, yl(-3.0), "front")]
    for x in slit_x:
        hw = 0.28 + J(0.03)
        st += [(x - hw, yl(x - hw), "l"), (x + hw, yl(x + hw), "r")]
    st += [(3.0, yl(3.0), "front")] + [(x, y, "side") for x, y in side[::-1]]
    xy = np.array([(x, y) for x, y, _ in st])
    sections, tagsec = [], []
    m_shared = {}
    for i, (x, y, kind) in enumerate(st):
        a = xy[max(i - 1, 0)]
        b = xy[min(i + 1, len(st) - 1)]
        tng = _n(np.array([b[0] - a[0], b[1] - a[1], 0.0]))
        out = np.array([tng[1], -tng[0], 0.0])        # the arch runs -x -> +x round the front: outward = (ty, -tx)
        front = kind != "side"
        thick = 1.6 if front else 1.4
        zt = -0.03 if front else -0.28
        zb = (-3.75 if abs(x) < 1.6 else -3.55) if front else -3.3 + 0.1 * (abs(x) - 4.0)
        o = np.array([x, y, 0.0])
        ot = o + np.array([0.0, 0.0, zt])
        ob = o + out * (0.25 if abs(x) < 2.0 else 0.1) + np.array([0.0, 0.0, zb])
        ib = o - out * thick + np.array([0.0, 0.0, zb + 0.55])
        it = o - out * thick + np.array([0.0, 0.0, zt - 0.75])
        if kind in ("l", "r"):
            si = int(np.argmin([abs(x - s) for s in slit_x]))
            if si not in m_shared:
                xs_ = slit_x[si]
                m_shared[si] = vid(np.array([xs_, yl(xs_) + 0.08, -0.9 + J(0.08)]))
            om = m_shared[si]
        else:
            om = vid(o + np.array([0.0, 0.1 if front else 0.0, -1.25 if front else -1.5]))
        sections.append([vid(ot), om, vid(ob), vid(ib), vid(it)])
        tagsec.append(kind)
    F, T = [], []
    for s in range(len(sections) - 1):
        A, Bs = sections[s], sections[s + 1]
        ka, kb = tagsec[s], tagsec[s + 1]
        for e in range(5):
            q = [A[e], A[(e + 1) % 5], Bs[(e + 1) % 5], Bs[e]]
            clean = []
            for x in q:
                if x not in clean:
                    clean.append(x)
            if len(clean) < 3:
                continue
            if e == 0 and ka != "side" and kb != "side":
                tg = "toothgap" if (ka, kb) == ("l", "r") else "tooth"
            else:
                tg = "jaw"
            F.append(clean)
            T.append(tg)
    F.append(sections[0][::-1])
    T.append("jaw")
    F.append(list(sections[-1]))
    T.append("jaw")
    v = np.array(V)
    shells = [Shell(v, orient_closed(v, F), T, "EnvBone", "jaw")]
    for s in (-1.0, 1.0):
        pts = np.array([(s * 4.2, 6.2, -3.55), (s * 5.55, 6.3, -3.45), (s * 4.25, 9.2, -3.1), (s * 5.55, 9.2, -3.0),
                        (s * 4.1, 8.1, -0.1), (s * 5.45, 8.1, -0.2), (s * 4.1, 10.5, 0.05), (s * 5.45, 10.5, -0.05),
                        (s * 4.0, 8.9, 0.55), (s * 5.5, 8.9, 0.5), (s * 4.0, 9.95, 0.6), (s * 5.5, 9.95, 0.5),
                        (s * 4.7, 6.7, -0.55)]) + rng.uniform(-0.07, 0.07, (13, 3))
        hv, hf = hull(pts, dissolve_deg=0.5)
        shells.append(Shell(hv, hf, "jaw", "EnvBone", "jaw"))
    p = Piece("Jaw", shells, {"kind": "J", "variant": variant})
    if open_deg:
        hinge = np.array([0.0, 9.4, 0.3])
        R = rot_x(open_deg)
        p = p.transformed(R, hinge - R @ hinge)
        body = p.shells[0].v
        front = body[np.abs(body[:, 0]) < 3.2]
        p = p.transformed(t=(0.0, 0.0, -0.03 - float(front[:, 2].max())))
    return p


def make_packed_front(variant=0):
    """The packed skull for rows nobody sees from behind (fills and pier bays under a slab): the same face, orbits,
    nose and tooth band, the dome cut to a 4-sided ring 5 cm back and capped (~60 tris, ~45 seen)."""
    return make_packed_skull(variant, front=True)
