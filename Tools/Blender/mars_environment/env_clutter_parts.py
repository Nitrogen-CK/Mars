"""Private helpers of build_env_clutter.py (the environment dressing "clutter" family). Safe to import: no main.

  geometry   bars with any section frame, closed hoops, lathes with a phase, lumps, rivets, convex hulls, ear clipping
  Parts      accumulates (verts, faces) per slot / tag / group with DELIBERATE winding: a closed part is turned outward
             per island by its signed volume, an open part (a decal) faces a given direction. Builds with
             recalc_normals=False so nothing re-guesses an open patch.
  flame      the candle_gen Flame shape (FLAME_RINGS / FLAME_PROFILE teardrop, base pole, tip pole) at any size, with
             the height 0..1 per vertex the "CandleData" UV1 carries
  SDF        candle_gen's surface nets + collapse decimation for soft forms (sacks, wax over a ledge edge)
  decals     emblem polygons clipped onto a triangulated cloth sheet and lifted along its normals
  checks     budget, slots, flat shading, colours, UV layers, pivot, closed outward shells, floating parts, coplanar
             overlaps (z-fighting), flame data, sockets
  renders    workbench views (orthographic or perspective) for close-ups and the scale line-up

Everything is CENTIMETRES, Blender axes (Z up). Unreal local = (x, -y, z).
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import env_common as ec          # noqa: E402
import candle_gen as cg          # noqa: E402  (a module, not a build script: importing it runs nothing)

fc, sc, spec = ec.fc, ec.sc, ec.spec
X = np.array([1.0, 0.0, 0.0])
Y = np.array([0.0, 1.0, 0.0])
Z = np.array([0.0, 0.0, 1.0])
TAU = math.tau
CANDLE_UV = cg.DATA_UV            # "CandleData": the flame contract's UV1 name


# ================================================================ small maths
def _n(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-12)


def lerp(a, b, t):
    return np.asarray(a, float) * (1.0 - t) + np.asarray(b, float) * t


def smoothstep(a, b, x):
    t = np.clip((np.asarray(x, float) - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def rot_z(v, deg):
    a = math.radians(deg)
    r = np.array([[math.cos(a), -math.sin(a), 0.0], [math.sin(a), math.cos(a), 0.0], [0.0, 0.0, 1.0]])
    return np.asarray(v, float) @ r.T


def rot_matrix(axis, deg):
    a = _n(axis)
    t = math.radians(deg)
    k = np.array([[0.0, -a[2], a[1]], [a[2], 0.0, -a[0]], [-a[1], a[0], 0.0]])
    return np.eye(3) + math.sin(t) * k + (1.0 - math.cos(t)) * (k @ k)


def rot_about(v, axis, deg, origin=(0.0, 0.0, 0.0)):
    o = np.asarray(origin, float)
    return (np.asarray(v, float) - o) @ rot_matrix(axis, deg).T + o


def axis_frame(axis):
    a = _n(axis)
    helper = Z if abs(a[2]) < 0.9 else X
    u = _n(np.cross(helper, a))
    w = np.cross(a, u)
    return u, w, a


def place_on_axis(v_local, origin, axis, phase_deg=0.0):
    """Local (x, y, z) with z along axis -> world; phase spins the local XY about the axis first."""
    v = rot_z(v_local, phase_deg)
    u, w, a = axis_frame(axis)
    return np.asarray(origin, float) + v[:, 0:1] * u + v[:, 1:2] * w + v[:, 2:3] * a


def bezier(p0, p1, p2, p3, n):
    p0, p1, p2, p3 = (np.asarray(p, float) for p in (p0, p1, p2, p3))
    t = np.linspace(0.0, 1.0, n + 1)[:, None]
    return ((1 - t) ** 3) * p0 + 3 * ((1 - t) ** 2) * t * p1 + 3 * (1 - t) * (t ** 2) * p2 + (t ** 3) * p3


def newell(pts):
    pts = np.asarray(pts, float)
    n = np.zeros(3)
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n += np.array([(a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]), (a[0] - b[0]) * (a[1] + b[1])])
    return n


# ================================================================ primitives (cm) -> (verts, faces)
def loft_closed(rings):
    """Skin rings (each (k, 3), same k and winding) into a CLOSED hoop: the last ring joins the first (welded)."""
    rings = [np.asarray(r, float) for r in rings]
    k, m = len(rings[0]), len(rings)
    verts = np.concatenate(rings)
    faces = []
    for i in range(m):
        a, b = i * k, ((i + 1) % m) * k
        for s in range(k):
            s2 = (s + 1) % k
            faces.append([a + s, a + s2, b + s2, b + s])
    return verts, faces


def bar(pts, normals, hn, hb, closed=False, cap=True):
    """A rectangular-section bar through 3D pts. Ring i spans +-hn along normals[i] (made perpendicular to the path)
    and +-hb along tangent x normal. hn / hb scalars or one per point. closed = a welded hoop."""
    pts = np.asarray(pts, float)
    n = len(pts)
    hn = np.broadcast_to(np.asarray(hn, float), (n,))
    hb = np.broadcast_to(np.asarray(hb, float), (n,))
    normals = np.broadcast_to(np.asarray(normals, float), (n, 3))
    rings = []
    for i in range(n):
        if closed:
            t = _n(pts[(i + 1) % n] - pts[i - 1])
        else:
            t = _n(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
        nr = _n(normals[i] - np.dot(normals[i], t) * t)
        b = np.cross(t, nr)
        p = pts[i]
        rings.append(np.array([p + nr * hn[i] + b * hb[i], p - nr * hn[i] + b * hb[i], p - nr * hn[i] - b * hb[i],
                               p + nr * hn[i] - b * hb[i]]))
    if closed:
        return loft_closed(rings)
    return fc.loft(rings, close_start=cap, close_end=cap)


def twisted_normals(pts, base_normal, turns_deg):
    """Section normals that spin turns_deg along a path (the forged twist of a square bar)."""
    pts = np.asarray(pts, float)
    n = len(pts)
    out = []
    for i in range(n):
        t = _n(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
        nr = _n(base_normal - np.dot(base_normal, t) * t)
        out.append(rot_matrix(t, turns_deg * i / max(n - 1, 1)) @ nr)
    return np.array(out)


def hoop(center, axis, radius, hn, hb, segments=12, phase_deg=0.0):
    """A closed ring of rectangular section round axis: hn radial half size, hb half size along the axis."""
    u, w, a = axis_frame(axis)
    c = np.asarray(center, float)
    pts, nrm = [], []
    for k in range(segments):
        ang = math.radians(phase_deg) + TAU * k / segments
        d = u * math.cos(ang) + w * math.sin(ang)
        pts.append(c + d * radius)
        nrm.append(d)
    return bar(pts, nrm, hn, hb, closed=True)


def lathe(profile, segments, phase_deg=0.0, jitter=0.0, rng=None):
    """fc.lathe (r == 0 rows are poles: start and end the profile on the axis for a closed shell) with the ring
    turned by phase_deg and optional radial hand-cut jitter."""
    v, f = fc.lathe(profile, segments)
    if jitter and rng is not None:
        rr = np.hypot(v[:, 0], v[:, 1])
        m = rr > 1e-6
        k = 1.0 + rng.uniform(-jitter, jitter, int(m.sum())) / rr[m]
        v[m, 0] *= k
        v[m, 1] *= k
    return rot_z(v, phase_deg), f


def lathe_on_axis(profile, segments, origin, axis, phase_deg=0.0, jitter=0.0, rng=None):
    v, f = lathe(profile, segments, 0.0, jitter, rng)
    return place_on_axis(v, origin, axis, phase_deg), f


def lathe_closed(profile, segments, phase_deg=0.0):
    """Revolve a CLOSED (r, z) polygon (a hoop / band / collar), welded all round."""
    m = len(profile)
    verts = []
    for r, z in profile:
        for s in range(segments):
            a = math.radians(phase_deg) + TAU * s / segments
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
    """A faceted coal: a jittered icosahedron (20 tris) or lopsided octahedron (8 tris), size = full extents."""
    if coarse:
        v, f = octahedron()
        v = v + rng.uniform(-0.28, 0.28, size=v.shape)
    else:
        v, f = icosahedron()
    v = v * (1.0 + rng.uniform(-jitter, jitter, size=(len(v), 1)))
    v = v * (np.asarray(size, float) * 0.5)
    return rot_z(v, rng.uniform(0, 360)) + np.asarray(center, float), f


def rivet(center, normal, rng, r=0.55, h=0.42, segments=6, sink=0.3):
    """A faceted dome rivet head; its base sinks `sink` into the surface."""
    v, f = fc.lathe([(0.0, h), (0.68 * r, 0.74 * h), (r, 0.06), (0.0, -sink)], segments)
    return place_on_axis(v, center, normal, rng.uniform(0, 60)), f


def hull(points, dissolve_deg=0.5):
    """Convex hull (bmesh) of cm points -> (verts, faces) with coplanar triangles merged into facets."""
    bm = bmesh.new()
    for p in np.asarray(points, float):
        bm.verts.new(p.tolist())
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    junk = [g for g in res.get("geom_interior", []) + res.get("geom_unused", []) if isinstance(g, bmesh.types.BMVert)]
    junk = list({id(g): g for g in junk if g.is_valid}.values())
    if junk:
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    if dissolve_deg:
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(dissolve_deg), verts=bm.verts[:], edges=bm.edges[:])
    bm.verts.index_update()
    v = np.array([x.co[:] for x in bm.verts], float)
    f = [[x.index for x in face.verts] for face in bm.faces]
    bm.free()
    return v, f


def chamfer_box(center, size, ch, rng=None, jitter=0.0, yaw_deg=0.0):
    """A box with every edge chamfered by ch (hull of 24 corner points), optionally jittered and yawed."""
    c = np.asarray(center, float)
    h = np.asarray(size, float) * 0.5
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                corner = np.array([sx * h[0], sy * h[1], sz * h[2]])
                for ax in range(3):
                    p = corner.copy()
                    p[ax] -= np.sign(corner[ax]) * ch
                    pts.append(p)
    pts = np.array(pts)
    if rng is not None and jitter:
        pts = pts + rng.uniform(-jitter, jitter, pts.shape)
    if yaw_deg:
        pts = rot_z(pts, yaw_deg)
    return hull(pts + c)


def extrude_outline(outline_xz, y0, y1, bevel=0.0, y_bevel=None):
    """A plate from an (x, z) outline: back face at y0, front at y1 (y1 < y0 for a wall plate), with an optional bevel
    (the front face inset by `bevel`, reached at y_bevel)."""
    o = np.asarray(outline_xz, float)
    cen = o.mean(axis=0)
    rings = [np.column_stack([o[:, 0], np.full(len(o), y0), o[:, 1]])]
    if bevel:
        rings.append(np.column_stack([o[:, 0], np.full(len(o), y_bevel), o[:, 1]]))
        ins = cen + (o - cen) * (1.0 - bevel / max(float(np.linalg.norm(o - cen, axis=1).min()), 1e-6))
        rings.append(np.column_stack([ins[:, 0], np.full(len(o), y1), ins[:, 1]]))
    else:
        rings.append(np.column_stack([o[:, 0], np.full(len(o), y1), o[:, 1]]))
    return fc.loft(rings)


# ================================================================ winding
def _islands(faces, nverts):
    parent = list(range(nverts))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for f in faces:
        r0 = find(f[0])
        for v in f[1:]:
            r = find(v)
            if r != r0:
                parent[r] = r0
    return [find(f[0]) for f in faces]


def signed_volume(verts, faces):
    vol = 0.0
    for f in faces:
        a = verts[f[0]]
        for k in range(1, len(f) - 1):
            vol += float(np.dot(a, np.cross(verts[f[k]], verts[f[k + 1]])))
    return vol / 6.0


def orient_closed(verts, faces):
    """Flip every island whose signed volume is negative, so each closed shell winds outward."""
    labels = _islands(faces, len(verts))
    out = [list(f) for f in faces]
    for lab in set(labels):
        idx = [i for i, l in enumerate(labels) if l == lab]
        if signed_volume(verts, [faces[i] for i in idx]) < 0.0:
            for i in idx:
                out[i] = out[i][::-1]
    return out


def orient_to(verts, faces, direction):
    d = np.asarray(direction, float)
    return [list(f) if np.dot(newell(verts[f]), d) >= 0.0 else list(f)[::-1] for f in faces]


# ================================================================ Parts
class Parts:
    """Accumulates (verts, faces) with a slot, a tag and a group per face, per-vertex flame height / flex and a
    per-face data id, then builds one flat-shaded object whose winding is exactly what was added."""

    def __init__(self, slots):
        self.slots = tuple(slots)
        self.v, self.f = [], []
        self.slot, self.tag, self.group, self.open_dir, self.fid = [], [], [], [], []
        self.fh, self.flex = [], []
        self.base = 0
        self.next_group = 0

    def add(self, vf, slot, tag, group=None, closed=True, face_dir=None, fid=0.0, fh=None, flex=None):
        verts = np.asarray(vf[0], float)
        faces = [[int(i) for i in face] for face in vf[1]]
        if closed:
            faces = orient_closed(verts, faces)
        elif face_dir is not None:
            faces = orient_to(verts, faces, face_dir)
        nf = len(faces)
        tags = [tag] * nf if isinstance(tag, str) else list(tag)
        slots = [slot] * nf if isinstance(slot, str) else list(slot)
        fids = [float(fid)] * nf if np.isscalar(fid) else [float(x) for x in fid]
        assert len(tags) == nf and len(slots) == nf and len(fids) == nf
        if group is None:
            group = self.next_group
            self.next_group += 1
        self.v.append(verts)
        self.f.extend([[self.base + i for i in face] for face in faces])
        self.slot.extend([self.slots.index(s) for s in slots])
        self.tag.extend(tags)
        self.group.extend([group] * nf)
        self.open_dir.extend([None if closed else (tuple(face_dir) if face_dir is not None else "open")] * nf)
        self.fid.extend(fids)
        self.fh.append(np.zeros(len(verts)) if fh is None else np.asarray(fh, float))
        self.flex.append(np.zeros(len(verts)) if flex is None else np.asarray(flex, float))
        self.base += len(verts)
        return group

    def new_group(self):
        g = self.next_group
        self.next_group += 1
        return g

    def verts(self):
        return np.concatenate(self.v)

    def build(self, name):
        obj = ec.new_object(name, self.verts(), self.f, slots=self.slots, face_slots=self.slot, recalc_normals=False)
        if len(obj.data.polygons) != len(self.f):
            raise RuntimeError("%s: mesh.validate dropped faces (%d -> %d)" % (name, len(self.f), len(obj.data.polygons)))
        if len(obj.data.vertices) != self.base:
            raise RuntimeError("%s: mesh.validate changed the vertices (%d -> %d)" % (name, self.base,
                                                                                 len(obj.data.vertices)))
        obj["env_family"] = "clutter"
        return obj


# ================================================================ flames (candle_gen Flame contract)
def flame(base, h, w, rng, lean=(0.0, 0.0), sides=None):
    """candle_gen's faceted teardrop at any size: base pole, FLAME_RINGS at FLAME_PROFILE x half width, tip pole.
    lean = tip offset as a fraction of h (x, y). Returns (verts, tris, height 0..1 per vertex)."""
    n = sides or cg.FLAME_SIDES
    base = np.asarray(base, float)
    half = 0.5 * w
    bend = np.array([lean[0], lean[1]], float) * h + rng.uniform(-1.0, 1.0, size=2) * 0.04 * h
    spin = rng.uniform(0.0, TAU)
    verts = [base.copy()]
    for t, f in zip(cg.FLAME_RINGS, cg.FLAME_PROFILE):
        t = t + rng.uniform(-0.025, 0.025)
        centre = base + np.array([bend[0] * t * t, bend[1] * t * t, h * t])
        spin += rng.uniform(0.25, 0.6)
        for s in range(n):
            a = spin + TAU * s / n
            rr = half * f * rng.uniform(0.9, 1.08)
            verts.append(centre + np.array([rr * math.cos(a), rr * math.sin(a), rng.uniform(-0.03, 0.03) * h]))
    tip = base + np.array([bend[0], bend[1], h])
    verts.append(tip)
    verts = np.array(verts)
    hv = np.clip((verts[:, 2] - base[2]) / (tip[2] - base[2]), 0.0, 1.0)
    tris = []
    rings = len(cg.FLAME_RINGS)
    for s in range(n):
        s2 = (s + 1) % n
        tris.append((0, 1 + s2, 1 + s))
        for k in range(rings - 1):
            a, b = 1 + k * n, 1 + (k + 1) * n
            tris.append((a + s, a + s2, b + s2))
            tris.append((a + s, b + s2, b + s))
        last = 1 + (rings - 1) * n
        tris.append((last + s, last + s2, len(verts) - 1))
    return verts, [list(t) for t in tris], hv


def tongue(base, h, w, rng, lean=(0.0, 0.0), bend_deg=0.0, curl=0.7, sides=6, flat=0.82,
           rings=((0.13, 0.74), (0.30, 1.0), (0.62, 0.56)), twist=0.25):
    """A soft stylised fire tongue (round-2 review): a 6-sided teardrop, widest (w) at 30 % of its height h, with
    BIG facets (base pole + 3 rings + tip pole = 12 x len(rings) triangles, 36 by default). The spine leans bend_deg
    toward the horizontal direction `lean` and the tip curls back toward the base axis (curl 0..1), an S-ish lick.
    The section is slightly flattened (flat) across the lean. Returns (verts, tris, height 0..1 per vertex) with the
    base pole at 0 and the tip at 1 exactly (the candle_gen Flame contract's v)."""
    base = np.asarray(base, float)
    d = np.array([lean[0], lean[1], 0.0], float)
    d = d / np.linalg.norm(d) if np.linalg.norm(d) > 1e-9 else np.array([1.0, 0.0, 0.0])
    side = np.cross(Z, d)
    k = math.tan(math.radians(bend_deg)) * h

    def spine(t):
        return base + Z * (h * t) + d * (k * (t - curl * t ** 3))

    half = 0.5 * w
    spin = rng.uniform(0.0, TAU)
    verts = [base.copy()]
    hv = [0.0]
    for t, f in rings:
        t = t + rng.uniform(-0.02, 0.02)
        c = spine(t)
        spin += rng.uniform(-twist, twist)
        for s in range(sides):
            a = spin + TAU * s / sides
            rr = half * f * rng.uniform(0.93, 1.07)
            verts.append(c + d * (rr * flat * math.cos(a)) + side * (rr * math.sin(a)))
            hv.append(t)
    verts.append(spine(1.0))
    hv.append(1.0)
    verts = np.array(verts)
    tris = []
    n = sides
    nr = len(rings)
    for s in range(n):
        s2 = (s + 1) % n
        tris.append([0, 1 + s2, 1 + s])
        for q in range(nr - 1):
            a, b = 1 + q * n, 1 + (q + 1) * n
            tris.append([a + s, a + s2, b + s2])
            tris.append([a + s, b + s2, b + s])
        last = 1 + (nr - 1) * n
        tris.append([last + s, last + s2, len(verts) - 1])
    return verts, tris, np.array(hv)


def iron_col(nrm, rng, lift_dir=(0.0, -0.45, 0.6)):
    """Round-2 review: wrought iron a dark WARM grey (~0.06 linear) with +-15 % per facet and up to +25 % on facets
    turned up / toward the room (a worn edge lift), so the silhouettes do not go dead in a dark crypt."""
    base = np.array([0.062, 0.056, 0.052])
    ld = _n(lift_dir)
    lift = 1.0 + 0.25 * float(np.clip(np.dot(nrm, ld), 0.0, 1.0))
    return base * rng.uniform(0.85, 1.15) * lift


# ================================================================ SDF helpers (broadcastable numpy)
def sd_ellipsoid(lx, ly, lz, rx, ry, rz):
    k0 = np.sqrt((lx / rx) ** 2 + (ly / ry) ** 2 + (lz / rz) ** 2)
    k1 = np.sqrt((lx / rx ** 2) ** 2 + (ly / ry ** 2) ** 2 + (lz / rz ** 2) ** 2)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def sd_capsule(x, y, z, a, b, ra, rb, power=1.0, squash_y=1.0):
    a = np.asarray(a, float)
    e = np.asarray(b, float) - a
    l2 = float(np.dot(e, e))
    t = np.clip(((x - a[0]) * e[0] + (y - a[1]) * e[1] + (z - a[2]) * e[2]) / l2, 0.0, 1.0)
    qx = x - a[0] - t * e[0]
    qy = (y - a[1] - t * e[1]) * squash_y
    qz = z - a[2] - t * e[2]
    return np.sqrt(qx * qx + qy * qy + qz * qz) - (ra + (rb - ra) * t ** power)


def sd_round_box(x, y, z, center, half, r):
    c = np.asarray(center, float)
    h = np.asarray(half, float) - r
    qx = np.abs(x - c[0]) - h[0]
    qy = np.abs(y - c[1]) - h[1]
    qz = np.abs(z - c[2]) - h[2]
    out = np.sqrt(np.maximum(qx, 0.0) ** 2 + np.maximum(qy, 0.0) ** 2 + np.maximum(qz, 0.0) ** 2)
    return out + np.minimum(np.maximum(np.maximum(qx, qy), qz), 0.0) - r


def sd_sphere(x, y, z, c, r):
    return np.sqrt((x - c[0]) ** 2 + (y - c[1]) ** 2 + (z - c[2]) ** 2) - r


def sd_torus(x, y, z, center, axis, R, r):
    c = np.asarray(center, float)
    a = _n(axis)
    px, py, pz = x - c[0], y - c[1], z - c[2]
    w = px * a[0] + py * a[1] + pz * a[2]
    rx, ry, rz = px - w * a[0], py - w * a[1], pz - w * a[2]
    rad = np.sqrt(rx * rx + ry * ry + rz * rz)
    return np.sqrt((rad - R) ** 2 + w * w) - r


def sine_lumps(x, y, z, seed, freq, count=6):
    """Smooth pseudo-noise -1..1 from fixed sinusoids, broadcastable over x, y, z."""
    rng = np.random.default_rng(seed)
    total = 0.0
    amp_sum = 0.0
    for k in range(count):
        w = rng.normal(size=3)
        w = w / np.linalg.norm(w) * freq * (1.0 + 0.5 * k)
        amp = 1.0 / (1.0 + 0.7 * k)
        total = total + amp * np.sin(x * w[0] + y * w[1] + z * w[2] + rng.uniform(0.0, TAU))
        amp_sum += amp
    return total / amp_sum


def grid_axes(lo, hi, voxel):
    lo, hi = np.asarray(lo, float), np.asarray(hi, float)
    n = (np.ceil((hi - lo) / voxel) + 1).astype(int)
    return [lo[a] + np.arange(n[a]) * voxel for a in range(3)]


def sample_grid(fn, lo, hi, voxel):
    """fn(x (nx,1,1), y (1,ny,1), z (1,1,nz)) -> full (nx, ny, nz) values, plus the grid origin."""
    ax = grid_axes(lo, hi, voxel)
    vals = fn(ax[0][:, None, None], ax[1][None, :, None], ax[2][None, None, :])
    vals = np.broadcast_to(vals, (len(ax[0]), len(ax[1]), len(ax[2]))).astype(float).copy()
    return vals, np.array([ax[0][0], ax[1][0], ax[2][0]])


def sdf_to_mesh(values, origin, voxel, target_tris):
    """candle_gen's pinch fill + surface nets + collapse decimation: (verts cm, tris, surface-nets tris)."""
    cg.fill_pinches(values, voxel)
    hv, quads = cg.surface_nets(values, origin, voxel)
    if len(quads) == 0:
        raise RuntimeError("the field has no surface")
    v, t, full = cg._decimate(hv, quads, target_tris)
    return v, t, full


def clean_tris(verts, tris):
    """Drop degenerate and doubled triangles, compact (candle_gen._clean without its floor snap)."""
    return cg._clean(verts, tris, True, floor_eps=-1e9)


def vertex_normals(verts, tris):
    v = np.asarray(verts, float)
    t = np.asarray(tris, np.int64)
    fn = np.cross(v[t[:, 1]] - v[t[:, 0]], v[t[:, 2]] - v[t[:, 0]])
    vn = np.zeros_like(v)
    for k in range(3):
        np.add.at(vn, t[:, k], fn)
    return vn / np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-12)


def field_ao(fn, pts, nrm, steps=((0.7, 0.4), (1.6, 0.35), (3.2, 0.25)), scale=1.0):
    """0..1 openness of points from a distance field sampled along their normals (candle_gen's wax AO)."""
    acc = np.zeros(len(pts))
    for step, weight in steps:
        s = step * scale
        q = pts + nrm * s
        acc += weight * np.clip(fn(q[:, 0], q[:, 1], q[:, 2]) / s, 0.0, 1.0)
    return acc


# ================================================================ 2D polygons + decals
def area2(p):
    p = np.asarray(p, float)
    return 0.5 * float(np.sum(p[:, 0] * np.roll(p[:, 1], -1) - np.roll(p[:, 0], -1) * p[:, 1]))


def ccw(p):
    p = np.asarray(p, float)
    return p if area2(p) > 0 else p[::-1].copy()


def _cross2(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def ear_clip(poly):
    """Triangulate a simple polygon (any winding) -> (CCW points, list of index triples)."""
    p = ccw(poly)
    idx = list(range(len(p)))
    tris = []
    guard = 0
    while len(idx) > 3 and guard < 10000:
        guard += 1
        found = False
        for k in range(len(idx)):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % len(idx)]
            a, b, c = p[i0], p[i1], p[i2]
            if _cross2(a, b, c) <= 1e-9:
                continue
            ok = True
            for j in idx:
                if j in (i0, i1, i2):
                    continue
                q = p[j]
                if _cross2(a, b, q) >= -1e-12 and _cross2(b, c, q) >= -1e-12 and _cross2(c, a, q) >= -1e-12:
                    ok = False
                    break
            if ok:
                tris.append((i0, i1, i2))
                idx.pop(k)
                found = True
                break
        if not found:
            raise RuntimeError("ear_clip: no ear (self-intersecting outline?)")
    tris.append(tuple(idx))
    return p, tris


def clip_convex(subject, clip):
    """Sutherland-Hodgman: a convex subject polygon clipped by a convex CCW clip polygon (2D lists)."""
    out = [np.asarray(q, float) for q in subject]
    for i in range(len(clip)):
        a, b = np.asarray(clip[i], float), np.asarray(clip[(i + 1) % len(clip)], float)
        inp, out = out, []
        if not inp:
            break
        for j in range(len(inp)):
            p, q = inp[j - 1], inp[j]
            pin = _cross2(a, b, p) >= -1e-12
            qin = _cross2(a, b, q) >= -1e-12
            if qin:
                if not pin:
                    out.append(_isect(p, q, a, b))
                out.append(q)
            elif pin:
                out.append(_isect(p, q, a, b))
    return out


def _isect(p, q, a, b):
    d1 = _cross2(a, b, p)
    d2 = _cross2(a, b, q)
    t = d1 / (d1 - d2)
    return p + (q - p) * t


def barycentric(p, a, b, c):
    v0, v1, v2 = b - a, c - a, p - a
    d = v0[0] * v1[1] - v1[0] * v0[1]
    w1 = (v2[0] * v1[1] - v1[0] * v2[1]) / d
    w2 = (v0[0] * v2[1] - v2[0] * v0[1]) / d
    return np.array([1.0 - w1 - w2, w1, w2])


def project_decals(sheet2d, sheet3d, sheet_nrm, sheet_val, polys, offset):
    """Decal faces on a triangulated sheet. sheet2d (m, 3, 2) pattern-space triangles, sheet3d (m, 3, 3) their 3D
    corners, sheet_nrm (m, 3, 3) the corners' smooth normals, sheet_val (m, 3) a per-corner value carried over
    (cloth flex). polys: simple 2D outlines in pattern space. Each outline is ear-clipped, every piece is clipped to
    every sheet triangle (so each decal facet lies parallel to the cloth facet under it) and lifted `offset` cm
    along the interpolated normal. Returns (verts, tris, value per vertex), coincident corners welded."""
    pieces_v, pieces_t, pieces_val = [], [], []
    lo2 = sheet2d.min(axis=1)
    hi2 = sheet2d.max(axis=1)
    keymap = {}

    def vid(p3, val):
        key = tuple(np.round(p3, 4))
        if key not in keymap:
            keymap[key] = len(pieces_v)
            pieces_v.append(p3)
            pieces_val.append(val)
        return keymap[key]

    for poly in polys:
        pts, tris = ear_clip(poly)
        for tri in tris:
            e = pts[list(tri)]
            elo, ehi = e.min(axis=0), e.max(axis=0)
            cand = np.nonzero((hi2[:, 0] >= elo[0]) & (lo2[:, 0] <= ehi[0]) & (hi2[:, 1] >= elo[1]) &
                              (lo2[:, 1] <= ehi[1]))[0]
            for m in cand:
                t2 = sheet2d[m]
                if area2(t2) < 0:
                    order = [0, 2, 1]
                else:
                    order = [0, 1, 2]
                t2c = t2[order]
                piece = clip_convex(list(e), list(t2c))
                if len(piece) < 3 or abs(area2(np.array(piece))) < 1e-4:
                    continue
                ids = []
                for q in piece:
                    w = barycentric(q, t2[0], t2[1], t2[2])
                    p3 = w @ sheet3d[m]
                    nn = _n(w @ sheet_nrm[m])
                    ids.append(vid(p3 + nn * offset, float(w @ sheet_val[m])))
                for k in range(1, len(ids) - 1):
                    if len({ids[0], ids[k], ids[k + 1]}) == 3:
                        p0, p1, p2 = (np.asarray(pieces_v[x]) for x in (ids[0], ids[k], ids[k + 1]))
                        if np.linalg.norm(np.cross(p1 - p0, p2 - p0)) < 2e-3:        # a sliver: no normal to shade
                            continue
                        pieces_t.append([ids[0], ids[k], ids[k + 1]])
    return np.array(pieces_v), pieces_t, np.array(pieces_val)


# ================================================================ paint / data
def paint_parts(obj, parts, fn, variation=0.06, seed=5, cavity_darken=0.35, alpha=None):
    """fn(face index, tag, group, centre cm, normal) -> linear rgb per face; fc.paint does the per-facet jitter and
    the cavity in A (alpha per vertex overrides the curvature cavity)."""
    centres = fc.face_centers_cm(obj)
    normals = fc.face_normals(obj)
    rgb = np.array([fn(i, parts.tag[i], parts.group[i], centres[i], normals[i]) for i in range(len(parts.tag))])
    fc.paint(obj, rgb, alpha=alpha, variation=variation, seed=seed, cavity_darken=cavity_darken)


def set_face_colours(obj, face_mask, rgba):
    """Exact corner colours on the masked faces (flames white, wicks near black)."""
    mesh = obj.data
    attr = mesh.color_attributes["Col"]
    col = np.empty(len(mesh.loops) * 4)
    attr.data.foreach_get("color", col)
    col = col.reshape(-1, 4)
    loop_face = np.repeat(np.arange(len(mesh.polygons)), [len(p.vertices) for p in mesh.polygons])
    m = np.asarray(face_mask, bool)[loop_face]
    col[m] = rgba
    attr.data.foreach_set("color", col.ravel())
    mesh.update()


def vertex_alpha(obj, parts, open_tags=(), floor_dark=None):
    """Per-vertex cavity: fc.cavity, but 1 on the given tags' vertices (glow, flames: no crevice darkening)."""
    cav = fc.cavity(obj)
    if open_tags:
        mesh = obj.data
        for i, poly in enumerate(mesh.polygons):
            if parts.tag[i] in open_tags:
                cav[list(poly.vertices)] = 1.0
    return cav


def write_uv1(obj, name, u_face, v_vert):
    """UV1 `name`: u per face, v per vertex as UNREAL reads it (stored 1 - v for the FBX V flip). UVMap stays first
    and active."""
    mesh = obj.data
    if "UVMap" not in mesh.uv_layers:
        raise RuntimeError("%s: UV0 UVMap must exist before the data layer" % obj.name)
    lv = np.empty(len(mesh.loops), np.int64)
    mesh.loops.foreach_get("vertex_index", lv)
    lf = np.repeat(np.arange(len(mesh.polygons)), [len(p.vertices) for p in mesh.polygons])
    u = np.asarray(u_face, float)[lf]
    v = np.asarray(v_vert, float)[lv]
    layer = mesh.uv_layers.get(name) or mesh.uv_layers.new(name=name)
    layer.data.foreach_set("uv", np.stack([u, 1.0 - v], axis=1).ravel())
    mesh.uv_layers.active = mesh.uv_layers["UVMap"]
    mesh.update()


def add_socket(obj, name, loc_cm, rot_deg=(0.0, 0.0, 0.0)):
    e = sc.add_socket(obj, name, loc_cm, rot_deg)
    e["env_socket"] = name
    return e


def claim_sockets(obj):
    """Blender object names are unique per file: give obj's SOCKET_ empties their bare names (another prop's
    SOCKET_Light becomes SOCKET_Light__<owner> while this one exports)."""
    mine = [o for o in bpy.data.objects if o.parent is obj and o.get("env_socket")]
    want = {"SOCKET_" + e["env_socket"] for e in mine}
    for o in bpy.data.objects:
        if o.name in want and o not in mine:
            o.name = "%s__%s" % (o.name, o.parent.name if o.parent else "parked")
    for e in mine:
        e.name = "SOCKET_" + e["env_socket"]
    bad = [e.name for e in mine if e.name != "SOCKET_" + e["env_socket"]]
    if bad:
        raise RuntimeError("socket names not claimed: %s" % bad)
    return mine


# ================================================================ checks
def mesh_arrays(obj):
    mesh = obj.data
    v = fc.verts_cm(obj)
    faces = [list(p.vertices) for p in mesh.polygons]
    return v, faces


def triangulate_faces(faces):
    tris, owner = [], []
    for i, f in enumerate(faces):
        for k in range(1, len(f) - 1):
            tris.append([f[0], f[k], f[k + 1]])
            owner.append(i)
    return np.array(tris, np.int64), np.array(owner, np.int64)


def face_components(faces, nverts):
    labels = _islands(faces, nverts)
    uniq = {l: i for i, l in enumerate(dict.fromkeys(labels))}
    return np.array([uniq[l] for l in labels], np.int64)


def shell_report(obj, parts):
    """Per connected component: closed (every edge used by exactly two of its faces, opposite directions) and its
    signed volume; open components must be decals (Parts open_dir) facing their direction. Returns problems."""
    v, faces = mesh_arrays(obj)
    comp = face_components(faces, len(v))
    problems = []
    normals = fc.face_normals(obj)
    for c in range(comp.max() + 1):
        idx = np.nonzero(comp == c)[0]
        fl = [faces[i] for i in idx]
        dirs = {parts.open_dir[i] for i in idx}
        und, dire = {}, {}
        for f in fl:
            for k in range(len(f)):
                a, b = f[k], f[(k + 1) % len(f)]
                key = (min(a, b), max(a, b))
                und[key] = und.get(key, 0) + 1
                dire[(a, b)] = dire.get((a, b), 0) + 1
        boundary = sum(1 for n in und.values() if n == 1)
        nonman = sum(1 for n in und.values() if n > 2)
        flipped = sum(1 for n in dire.values() if n > 1)
        tags = sorted({parts.tag[i] for i in idx})
        if dirs == {None}:
            if boundary or nonman or flipped:
                problems.append("component %d (%s) is not a closed shell: boundary %d non-manifold %d flipped %d"
                                % (c, ",".join(tags[:3]), boundary, nonman, flipped))
            vol = signed_volume(v, fl)
            if vol <= 0.0:
                problems.append("component %d (%s) winds inward (volume %.3f cm3)" % (c, ",".join(tags[:3]), vol))
        else:
            if None in dirs:
                problems.append("component %d mixes closed and open parts" % c)
                continue
            for i in idx:
                d = parts.open_dir[i]
                if d == "open":
                    continue
                if float(np.dot(normals[i], d)) <= 0.0:
                    problems.append("decal component %d face %d faces away from %s" % (c, i, d))
                    break
            if flipped or nonman:
                problems.append("decal component %d: flipped %d non-manifold %d" % (c, flipped, nonman))
    return problems, int(comp.max() + 1)


def floating_report(obj, anchor_fn, tol=0.4):
    """Components connected by intersection (BVH overlap) or nearness (< tol cm); every component must reach one that
    anchor_fn(verts of the component) accepts (the floor, the wall plane, the ledge)."""
    v, faces = mesh_arrays(obj)
    comp = face_components(faces, len(v))
    n = int(comp.max() + 1)
    trees, vsets, boxes = [], [], []
    for c in range(n):
        fl = [faces[i] for i in np.nonzero(comp == c)[0]]
        ids = sorted({i for f in fl for i in f})
        remap = {g: k for k, g in enumerate(ids)}
        pv = v[ids]
        trees.append(BVHTree.FromPolygons(pv.tolist(), [[remap[i] for i in f] for f in fl]))
        vsets.append(pv)
        boxes.append((pv.min(axis=0) - tol, pv.max(axis=0) + tol))
    adj = [set() for _ in range(n)]
    for a in range(n):
        for b in range(a + 1, n):
            if np.any(boxes[a][1] < boxes[b][0]) or np.any(boxes[b][1] < boxes[a][0]):
                continue
            touch = bool(trees[a].overlap(trees[b]))
            if not touch:
                small, big = (a, b) if len(vsets[a]) <= len(vsets[b]) else (b, a)
                for p in vsets[small]:
                    hit = trees[big].find_nearest(p.tolist(), tol)
                    if hit[0] is not None:
                        touch = True
                        break
                if not touch:
                    for p in vsets[big]:
                        hit = trees[small].find_nearest(p.tolist(), tol)
                        if hit[0] is not None:
                            touch = True
                            break
            if touch:
                adj[a].add(b)
                adj[b].add(a)
    seen = [c for c in range(n) if anchor_fn(vsets[c])]
    reach = set(seen)
    stack = list(seen)
    while stack:
        c = stack.pop()
        for d in adj[c]:
            if d not in reach:
                reach.add(d)
                stack.append(d)
    floating = [c for c in range(n) if c not in reach]
    return floating, n


def zfight_report(obj, tol=0.19, cos_par=0.985, tags=None):
    """Faces of DIFFERENT components that lie within tol cm of each other with parallel, same-facing normals (the
    coplanar overlaps that z-fight). Returns (number of such triangles, the tag pairs seen)."""
    v, faces = mesh_arrays(obj)
    comp = face_components(faces, len(v))
    tris, owner = triangulate_faces(faces)
    tcomp = comp[owner]
    a, b, c = v[tris[:, 0]], v[tris[:, 1]], v[tris[:, 2]]
    nrm = np.cross(b - a, c - a)
    area = np.linalg.norm(nrm, axis=1)
    nrm = nrm / np.maximum(area, 1e-12)[:, None]
    bvh = BVHTree.FromPolygons(v.tolist(), tris.tolist(), all_triangles=True)
    centres = (a + b + c) / 3.0
    bad = 0
    pairs = {}
    for i in range(len(tris)):
        if area[i] < 1e-6:
            continue
        for hit in bvh.find_nearest_range(centres[i].tolist(), tol):
            j = hit[2]
            if j is None or tcomp[j] == tcomp[i]:
                continue
            if float(np.dot(nrm[i], nrm[j])) > cos_par:
                bad += 1
                if tags is not None:
                    key = tuple(sorted((tags[owner[i]], tags[owner[j]])))
                    pairs[key] = pairs.get(key, 0) + 1
                break
    return bad, pairs


def clean_closed(verts, tris, weld=1e-4, degenerate=2e-3):
    """Weld, dissolve zero-area slivers (bmesh keeps the shell closed where dropping them would open a crack), fill
    any hole left, triangulate. -> (verts, tris)."""
    mesh = bpy.data.meshes.new("_clean")
    mesh.from_pydata((np.asarray(verts, float) * 0.01).tolist(), [], np.asarray(tris).tolist())
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=weld * 0.01)
    bmesh.ops.dissolve_degenerate(bm, dist=degenerate * 0.01, edges=bm.edges[:])
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    boundary = [e for e in bm.edges if e.is_boundary]
    if boundary:
        bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.verts.index_update()
    v = np.array([x.co[:] for x in bm.verts], float) * 100.0
    t = np.array([[x.index for x in f.verts] for f in bm.faces], np.int64)
    bm.free()
    bpy.data.meshes.remove(mesh)
    return v, t


def flame_report(obj, uv_name):
    """Flame contract on EnvFlame faces: UV1 u constant per flame, v (Unreal) 0 at the base .. 1 at the tip, the ids
    distinct between flames, Col exactly white."""
    mesh = obj.data
    problems = []
    slots = [m.name for m in mesh.materials]
    if "EnvFlame" not in slots:
        return ["no EnvFlame slot"], 0
    k = slots.index("EnvFlame")
    mat = np.empty(len(mesh.polygons), np.int32)
    mesh.polygons.foreach_get("material_index", mat)
    if uv_name not in mesh.uv_layers or mesh.uv_layers[1].name != uv_name:
        return ["UV1 is not %s" % uv_name], 0
    uv = np.empty(len(mesh.loops) * 2)
    mesh.uv_layers[1].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    v, faces = mesh_arrays(obj)
    comp = face_components(faces, len(v))
    loop_face = np.repeat(np.arange(len(mesh.polygons)), [len(p.vertices) for p in mesh.polygons])
    col = np.empty(len(mesh.loops) * 4)
    mesh.color_attributes["Col"].data.foreach_get("color", col)
    col = col.reshape(-1, 4)
    ids = []
    flames = sorted(set(comp[mat == k]))
    for c in flames:
        lm = (comp[loop_face] == c) & (mat[loop_face] == k)
        u, val = uv[lm, 0], 1.0 - uv[lm, 1]
        if np.ptp(u) > 1e-6:
            problems.append("flame %d: u not constant (%.4f..%.4f)" % (c, u.min(), u.max()))
        if abs(val.min()) > 1e-4 or abs(val.max() - 1.0) > 1e-4:
            problems.append("flame %d: height %.4f..%.4f, not 0..1" % (c, val.min(), val.max()))
        if np.abs(col[lm] - 1.0).max() > 1e-6:
            problems.append("flame %d: Col is not white" % c)
        ids.append(round(float(u.mean()), 5))
    if len(set(ids)) != len(ids):
        problems.append("flame ids repeat: %s" % ids)
    return problems, len(flames)


def check_mesh(obj, parts, rule, anchor_fn):
    """Every contract check for one built mesh. rule: cat, slots, pivot, uv1, sockets, open_tags. Returns problems."""
    name = obj.name
    mesh = obj.data
    out = []
    if not name.endswith("_Mars_SM"):
        out.append("name %s lacks _Mars_SM" % name)
    tris = fc.tri_count(obj)
    budget = spec.TRIS[rule["cat"]]
    if tris > budget:
        out.append("tris %d > %s budget %d" % (tris, rule["cat"], budget))
    slots = tuple(m.name for m in mesh.materials)
    if slots != tuple(rule["slots"]):
        out.append("slots %s != %s" % (slots, tuple(rule["slots"])))
    bad = [s for s in slots if s not in spec.SLOTS]
    if bad:
        out.append("slots outside env_spec: %s" % bad)
    used = {p.material_index for p in mesh.polygons}
    if used != set(range(len(slots))):
        out.append("a slot has no faces (%s used)" % sorted(used))
    if not fc._is_flat(mesh):
        out.append("not flat shaded")
    if "Col" not in mesh.color_attributes:
        out.append("no Col")
    else:
        col = np.empty(len(mesh.loops) * 4)
        mesh.color_attributes["Col"].data.foreach_get("color", col)
        col = col.reshape(-1, 4)
        if not np.all(np.isfinite(col)) or col[:, 3].min() < 0.0 or col[:, 3].max() > 1.0:
            out.append("Col alpha outside 0..1")
        if np.all(col[:, :3] >= 0.98):
            out.append("Col RGB all white")
    uvs = [u.name for u in mesh.uv_layers]
    want_uv = ["UVMap"] + ([rule["uv1"]] if rule.get("uv1") else [])
    if uvs != want_uv:
        out.append("uv layers %s != %s" % (uvs, want_uv))
    # pivot
    v = fc.verts_cm(obj)
    lo, hi = v.min(axis=0), v.max(axis=0)
    size = hi - lo
    piv = rule["pivot"]
    if piv == "floor":
        if abs(lo[2]) > 1e-3:
            out.append("floor prop: lowest z %.4f != 0" % lo[2])
        cx, cy = 0.5 * (lo[0] + hi[0]), 0.5 * (lo[1] + hi[1])
        tol = max(1.0, 0.03 * float(size[:2].max()))
        flat = v[v[:, 2] < 1e-3]
        foot = flat[:, :2].mean(axis=0) if len(flat) else np.array([99.0, 99.0])
        if max(abs(cx), abs(cy)) > tol and float(np.abs(foot).max()) > tol:
            out.append("floor prop: footprint centre (bbox %.2f, %.2f / contacts %.2f, %.2f) off the origin"
                       % (cx, cy, foot[0], foot[1]))
        if len(flat) < 3:
            out.append("floor prop: no flat underside on z = 0")
    elif piv == "post":
        if abs(lo[2]) > 1e-3:
            out.append("post prop: lowest z %.4f != 0" % lo[2])
        foot = v[v[:, 2] < 1e-3]
        if len(foot) < 3:
            out.append("post prop: no flat underside on z = 0")
        elif float(np.abs(0.5 * (foot[:, :2].min(axis=0) + foot[:, :2].max(axis=0))).max()) > 1.0:
            out.append("post prop: the first post's footprint is not centred on the origin")
        if hi[0] < 100.0:
            out.append("post prop: the rails do not run along +X")
    elif piv in ("sconce", "banner"):
        if abs(hi[1]) > 1e-3:
            out.append("wall prop: back at y %.4f != 0" % hi[1])
        cx = 0.5 * (lo[0] + hi[0])
        if abs(cx) > 1.0:
            out.append("wall prop: x centre %.2f" % cx)
        back = v[v[:, 1] > -1e-3]
        if piv == "sconce":
            if not (back[:, 0].min() < 0.0 < back[:, 0].max() and back[:, 2].min() < 0.0 < back[:, 2].max()):
                out.append("sconce: the wall mount does not cover the origin")
        else:
            if not (0.0 < hi[2] < 8.0):
                out.append("banner: top z %.2f (the rod axis is the pivot height)" % hi[2])
    elif piv == "ledge":
        inside = (v[:, 1] > 1e-3) & (v[:, 2] < -1e-3)
        if inside.any():
            out.append("ledge piece: %d vertices inside the ledge (y > 0, z < 0)" % int(inside.sum()))
        on_top = v[v[:, 1] > 0.5]
        if len(on_top) == 0 or abs(on_top[:, 2].min()) > 1e-3:
            out.append("ledge piece: the wax does not stand on the ledge top z = 0")
        if lo[2] > -5.0:
            out.append("ledge piece: nothing runs down the face (lowest z %.2f)" % lo[2])
        if abs(0.5 * (lo[0] + hi[0])) > 1.5:
            out.append("ledge piece: x centre %.2f" % (0.5 * (lo[0] + hi[0])))
    # shells, floating parts, coplanar overlaps
    probs, ncomp = shell_report(obj, parts)
    out += probs
    floating, _ = floating_report(obj, anchor_fn)
    if floating:
        out.append("%d floating component(s): %s" % (len(floating), floating[:8]))
    zf, pairs = zfight_report(obj, tags=parts.tag)
    if zf:
        out.append("%d triangles coplanar with another part (z-fighting): %s" % (zf, pairs))
    if "EnvFlame" in slots:
        fp, nfl = flame_report(obj, CANDLE_UV)
        out += fp
    # sockets
    socks = sorted(o["env_socket"] for o in bpy.data.objects if o.parent is obj and o.get("env_socket"))
    if socks != sorted(rule.get("sockets", ())):
        out.append("sockets %s != %s" % (socks, sorted(rule.get("sockets", ()))))
    ucx = [o for o in bpy.data.objects if o.parent is obj and o.name.startswith("UCX_")]
    if len(ucx) != rule.get("ucx", 0):
        out.append("ucx %d != %d" % (len(ucx), rule.get("ucx", 0)))
    return out, {"tris": tris, "size": size, "components": ncomp, "zfight": zf}


# ================================================================ review renders
REVIEW_BG = (0.21, 0.215, 0.23)


def remove_object(o):
    data = o.data
    bpy.data.objects.remove(o, do_unlink=True)
    if data is not None and data.users == 0:
        if isinstance(data, bpy.types.Mesh):
            bpy.data.meshes.remove(data)
        elif isinstance(data, bpy.types.Curve):
            bpy.data.curves.remove(data)


def copy_mesh(obj, offset=(0.0, 0.0, 0.0), rot_z_deg=0.0, name=None):
    c = bpy.data.objects.new(name or (obj.name + "_Copy"), obj.data.copy())
    bpy.context.scene.collection.objects.link(c)
    v = fc.verts_cm(c)
    if rot_z_deg:
        v = rot_z(v, rot_z_deg)
    fc.set_verts_cm(c, v + np.asarray(offset, float))
    return c


def review_copy(obj, suffix="_Review"):
    """Unparented copy re-centred for fc.review_sheet's framing: XY centre 0, bbox middle at 0.45 x the largest
    extent (the sheet aims there)."""
    c = copy_mesh(obj, name=obj.name.replace("_Mars_SM", "") + suffix)
    v = fc.verts_cm(c)
    lo, hi = v.min(axis=0), v.max(axis=0)
    ext = float((hi - lo).max())
    shift = np.array([(lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, (lo[2] + hi[2]) * 0.5 - 0.45 * ext])
    fc.set_verts_cm(c, v - shift)
    return c


def painted_box(name, center, size, rgb):
    v, f = sc.box(center, size)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata((np.asarray(v) * 0.01).tolist(), [], f)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(o)
    fc.paint(o, np.repeat(np.asarray(rgb, float)[None, :], len(f), axis=0), variation=0.0, cavity_darken=0.0)
    return o


def render_view(objs, path, view, size=(1200, 1200), margin=1.08, ortho=True, target_cm=None, half_cm=None, lens=50.0,
                eye_cm=None, shadows=False):
    """One workbench render of objs in place (vertex colours + cavity). The frame fits their bounds seen from `view`
    unless half_cm (half the longer image side, cm) is given; eye_cm places a perspective camera explicitly."""
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
    cam_data = bpy.data.cameras.new("_ClutterCam")
    cam_data.clip_start, cam_data.clip_end = 0.02, 2000.0
    cam = bpy.data.objects.new("_ClutterCam", cam_data)
    scene.collection.objects.link(cam)
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    shading = scene.display.shading
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.filepath, shading.color_type, shading.light, shading.show_cavity, scene.render.film_transparent,
            tuple(scene.world.color), shading.show_shadows, shading.show_specular_highlight)
    saved = [o.hide_render for o in objs]
    try:
        for o in hidden:
            o.hide_render = True
        for o in objs:
            o.hide_render = False
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        shading.light = "STUDIO"
        shading.color_type = "VERTEX"
        shading.show_cavity = True
        scene.render.film_transparent = False
        scene.world.color = REVIEW_BG
        shading.show_shadows = bool(shadows)
        shading.show_specular_highlight = False
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
    finally:
        for o, hr in zip(objs, saved):
            o.hide_render = hr
        for o, hr in zip(hidden, hidden_state):
            o.hide_render = hr
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
         scene.render.filepath, shading.color_type, shading.light, shading.show_cavity,
         scene.render.film_transparent) = prev[:9]
        scene.world.color = prev[9]
        shading.show_shadows = prev[10]
        shading.show_specular_highlight = prev[11]
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return path


# ================================================================ chunky facets for SDF cloth (sacks)
def facet_regions(v, t, face_mask, K, seed, iters=7, density=None):
    """Variational shape approximation (L2,1): partition the masked faces into K connected regions of near-equal
    normal by flood fill from seeds, re-fitting each region's normal and seed. density (per face, >= 1) packs the
    seeds closer where it is high (smaller facets there). -> labels per face (-1 unmasked)."""
    import heapq
    v = np.asarray(v, float)
    t = np.asarray(t, np.int64)
    m = len(t)
    a, b, c = v[t[:, 0]], v[t[:, 1]], v[t[:, 2]]
    cr = np.cross(b - a, c - a)
    area = 0.5 * np.linalg.norm(cr, axis=1)
    n = cr / np.maximum(2.0 * area, 1e-12)[:, None]
    cen = (a + b + c) / 3.0
    mask = np.asarray(face_mask, bool)
    edges = {}
    for f in range(m):
        for k in range(3):
            p, q = int(t[f, k]), int(t[f, (k + 1) % 3])
            edges.setdefault((min(p, q), max(p, q)), []).append(f)
    nbr = [[] for _ in range(m)]
    for fs in edges.values():
        if len(fs) == 2:
            nbr[fs[0]].append(fs[1])
            nbr[fs[1]].append(fs[0])
    idx = np.nonzero(mask)[0]
    label = np.full(m, -1)
    if len(idx) == 0:
        return label
    K = int(min(K, len(idx)))
    rng = np.random.default_rng(seed)
    seeds = [int(idx[rng.integers(len(idx))])]
    dmin = np.linalg.norm(cen[idx] - cen[seeds[0]], axis=1)
    dens = np.ones(len(idx)) if density is None else np.asarray(density, float)[idx]
    while len(seeds) < K:
        j = int(idx[int(np.argmax(dmin * dens))])
        seeds.append(j)
        dmin = np.minimum(dmin, np.linalg.norm(cen[idx] - cen[j], axis=1))
    N = n[seeds].copy()
    for it in range(iters):
        label[:] = -1
        heap = []
        for k, sf in enumerate(seeds):
            label[sf] = k
        for k, sf in enumerate(seeds):
            for g in nbr[sf]:
                if mask[g] and label[g] == -1:
                    heapq.heappush(heap, (float(area[g] * np.sum((n[g] - N[k]) ** 2)), g, k))
        while heap:
            _, g, k = heapq.heappop(heap)
            if label[g] != -1:
                continue
            label[g] = k
            for h in nbr[g]:
                if mask[h] and label[h] == -1:
                    heapq.heappush(heap, (float(area[h] * np.sum((n[h] - N[k]) ** 2)), h, k))
        for k in range(K):
            sel = np.nonzero(label == k)[0]
            if len(sel) == 0:
                continue
            N[k] = _n((area[sel, None] * n[sel]).sum(axis=0))
            seeds[k] = int(sel[int(np.argmin(np.sum((n[sel] - N[k]) ** 2, axis=1)))])
    return label


def planarize(v, t, label, fixed, iters=30, step=0.7):
    """Pull every vertex whose faces all belong to regions onto its regions' planes (averaging the projections; a
    vertex shared by two regions converges onto their crease) so each region becomes one flat, chiselled facet.
    Faces that would flip or collapse are reverted to the input. -> new verts."""
    v0 = np.asarray(v, float)
    t = np.asarray(t, np.int64)
    V = v0.copy()
    nv = len(V)
    lab = np.asarray(label)
    movable = np.ones(nv, bool)
    movable[np.asarray(fixed, bool)] = False
    for k in range(3):
        movable[t[lab < 0, k]] = False
    pairs = np.unique(np.concatenate([np.stack([t[lab >= 0, k], lab[lab >= 0]], axis=1) for k in range(3)]), axis=0)
    pairs = pairs[movable[pairs[:, 0]]]
    pv, pr = pairs[:, 0], pairs[:, 1]
    K = int(lab.max()) + 1
    cnt = np.bincount(pv, minlength=nv).astype(float)

    def normals_of(X):
        a, b, c = X[t[:, 0]], X[t[:, 1]], X[t[:, 2]]
        cr = np.cross(b - a, c - a)
        return cr, (a + b + c) / 3.0

    n0, _ = normals_of(v0)
    a0 = np.linalg.norm(n0, axis=1)
    n0u = n0 / np.maximum(a0, 1e-12)[:, None]
    for _ in range(iters):
        cr, cen = normals_of(V)
        Nk = np.zeros((K, 3))
        Pk = np.zeros((K, 3))
        Ak = np.zeros(K)
        sel = lab >= 0
        ar = np.linalg.norm(cr[sel], axis=1)
        np.add.at(Nk, lab[sel], cr[sel])
        np.add.at(Pk, lab[sel], cen[sel] * ar[:, None])
        np.add.at(Ak, lab[sel], ar)
        Nk = Nk / np.maximum(np.linalg.norm(Nk, axis=1), 1e-12)[:, None]
        Pk = Pk / np.maximum(Ak, 1e-12)[:, None]
        d = np.sum((V[pv] - Pk[pr]) * Nk[pr], axis=1)
        tgt = np.zeros((nv, 3))
        np.add.at(tgt, pv, V[pv] - d[:, None] * Nk[pr])
        m = cnt > 0
        V[m] += step * (tgt[m] / cnt[m, None] - V[m])
    for rev in range(12):
        cr, _c = normals_of(V)
        ar = np.linalg.norm(cr, axis=1)
        bad = (np.sum(cr / np.maximum(ar, 1e-12)[:, None] * n0u, axis=1) < 0.25) | (ar < 0.08 * a0)
        if not bad.any():
            break
        bv = np.unique(t[bad].ravel())
        V[bv] = 0.5 * (V[bv] + v0[bv]) if rev < 6 else v0[bv]
    return V
