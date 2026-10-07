"""Builds the PRODUCE ingredients of the Mars food library (food_spec category "produce") in Blender 5.2, headless and
re-runnable:

    blender -b --factory-startup --python build_food_produce.py -- [--export] [--save] [--sheets] [--only A,B]

    --export   FBX + JSON sidecar + <Name>_Mask_Mars_T.png (1024) per asset into food_spec.EXPORT_DIR, then a fresh
               --factory-startup Blender per FBX runs food_common.reimport_check on it
    --save     writes food_spec.BLEND_DIR/Food_Produce.blend (the only .blend this builder writes)
    --sheets   workbench review sheets into food_spec.REVIEW_DIR/<Name>_sheet.png: rows iso / face-on (+X toward the
               camera) / front / top; raw left, cooked right for the morphing ones
    --only     comma separated subset of the roster (default: all seven)
               (--sheets also writes Mushroom_Cuts_sheet.png: whole | half | slice, rows iso / top / under / front;
               "under" flips the meshes so the cut faces face the camera)

Puffer       14 cm  Skin + Horn  squat ball, jittered golden-spiral conical spikes, bead eyes and a pout on +X;
                                  cooked = fried: the skin puffs 15 % from its centre (base kept on the floor), the
                                  spikes ride out only 60 % of it so the swollen skin closes round their bases
                                  (PUFFER_SPIKE_FOLLOW; 0 buried the top spikes almost completely)
Turnip       16 cm  Skin + Leaf  white-to-magenta root standing on three root legs, screaming mouth with wedge teeth
                                  and bead eyes on +X, crown of six lobed leaves on stems; cooked = wilted (body sags
                                  10 % / spreads 5 %, leaves droop about their base and shrink 20 %)
SpikedBerry  10 cm  Skin + Horn  squat purple sphere, blunt rounded spikes, small mouth with two teeth on +X
TomatoBulb   12 cm  Skin + Leaf  seven-lobed tomato, mouth notch with two fangs on +X, five-point leaf cap and stub
                                  stem; cooked = slumped (z 0.82, xy 1.08, lobes soften, the cap rides the top unchanged)
ScaledPine   20 cm  Skin + Leaf  barrel of 9 x 11 overlapping shingle scales, crown of nine sword leaves (stands upright)
HerbPile     16 cm  Leaf + Stem  five flat-leaf herb sprigs lying along +X (cut stem ends toward -X). ONE mesh of closed
                                  manifold components - every leaf a slab, every stem a capped tube - for the chopping
                                  station's runtime slicer; verified with bmesh on every build
Mushroom     12 cm  Skin + Flesh cremini standing on its stem: domed cap with a rolled rim, pleated radial gills, short thick
                                  stem; ONE closed manifold volume (runtime slicing); cooked = shrinks 12 %, cap sags and
                                  the rim droops. Authored cuts from the same lathe (identical cut-plane vertices):
                                  Mushroom_Half_Mars_SM  split through the axis, lying on its flat Flesh cut face (z = 0),
                                                         stem toward +X: pale flesh, a recessed gill crescent under the
                                                         cap arc, a paler stem core
                                  Mushroom_Slice_Mars_SM a 1 cm lengthwise slice through the axis lying flat (z 0..1), both
                                                         faces Flesh with the gill band, rim Skin

Bodies are convex-hull triangulations of jittered, area-even surface points mapped conformally onto a revolved profile
(irregular hand-cut facets rather than an icosphere's pattern); mouths are inset + extruded + flattened cavities; eyes
are domed facet clusters. Every face is a flat triangle. "Col": per-facet paint (linear) and, in A, ray-traced vertex
AO x curvature cavity. Masks: R cook-first (up / outward / high, low in crevices), G skin speckle, B break-up, A rim
(baked convex-edge strength x AO).
"""
import json
import math
import os
import subprocess
import sys
import time
import zlib

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Vector
from mathutils.geometry import delaunay_2d_cdt
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import food_common as fc  # noqa: E402

spec = fc.spec
CATEGORY = "produce"
ROSTER = [k for k, v in spec.INGREDIENTS.items() if v["category"] == CATEGORY]
BLEND_PATH = os.path.join(spec.BLEND_DIR, spec.CATEGORIES[CATEGORY][0])
TRI_BUDGET = {k: (600, 3000 if k == "HerbPile" else 2500) for k in ROSTER}
TRI_BUDGET.update({"Mushroom": (600, 1800), "Mushroom_Half": (300, 1800), "Mushroom_Slice": (300, 1800)})
MANIFOLD_KEYS = ("HerbPile", "Mushroom")       # runtime-sliced: every mesh (and cut) must be closed manifold
TAU = 2.0 * math.pi
GOLDEN = math.pi * (3.0 - math.sqrt(5.0))
UP = np.array([0.0, 0.0, 1.0])

# cook morph tuning (the brief's numbers)
PUFFER_PUFF = 1.15            # fried skin scale about the body centre
PUFFER_SPIKE_FOLLOW = 0.6     # fraction of the skin's offset the spikes take (0 = stay put: buried them)
TURNIP_SAG = (1.05, 0.90)     # xy spread, z sag
TURNIP_LEAF_SHRINK = 0.8
TOMATO_SLUMP = (1.08, 0.82)   # xy, z
TOMATO_LOBE_COOKED = 0.4      # fraction of the lobe amplitude left when stewed


# ---------------------------------------------------------------- small vector helpers
def unit(v):
    v = np.asarray(v, float)
    return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-12)


def wrap(a):
    return (np.asarray(a, float) + math.pi) % TAU - math.pi


def rotate(v, axis, ang):
    """Rodrigues rotation of v (..., 3) about axis (3,) by ang (scalar or per row)."""
    v = np.asarray(v, float)
    k = unit(axis)
    ang = np.asarray(ang, float)
    if ang.ndim:
        ang = ang[..., None]
    c, s = np.cos(ang), np.sin(ang)
    return v * c + np.cross(k, v) * s + k * np.sum(k * v, axis=-1, keepdims=True) * (1.0 - c)


def frame(axis):
    a = unit(axis)
    h = UP if abs(a[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = unit(np.cross(a, h))
    return u, np.cross(a, u)


def mix(a, b, t):
    t = np.asarray(t, float)
    if t.ndim:
        t = t[..., None]
    return np.asarray(a, float) * (1.0 - t) + np.asarray(b, float) * t


def C(r, g, b):
    return fc.srgb(r, g, b)


def seed_of(name):
    return zlib.crc32(name.encode()) & 0xFFFFFFFF


# ---------------------------------------------------------------- geometry accumulator
class Geo:
    """Parts in cm: faces carry a slot, a tag (paint / mask class) and optionally a fixed colour; vertices carry a part
    id (0 = the main body) so the cook morph can treat parts rigidly or with their own pivots."""

    def __init__(self, slots):
        self.slots = tuple(slots)
        self.v, self.f, self.fslot, self.ftag, self.fcol, self.vpart = [], [], [], [], [], []
        self.n = 0
        self.parts = {}

    def part(self, kind, **meta):
        pid = len(self.parts) + 1
        self.parts[pid] = dict(kind=kind, **meta)
        return pid

    def add(self, verts, faces, slot, tag=None, part=0, color=None, tags=None):
        verts = np.asarray(verts, float)
        base = self.n
        si = self.slots.index(slot)
        col = None if color is None else np.asarray(color, float)
        for i, face in enumerate(faces):
            self.f.append([base + int(k) for k in face])
            self.fslot.append(si)
            self.ftag.append(tags[i] if tags is not None else tag)
            self.fcol.append(None if col is None else (col[i] if col.ndim == 2 else col))
        self.v.append(verts)
        self.vpart.extend([part] * len(verts))
        self.n += len(verts)
        return base


def triangulate(verts, faces):
    """Quads split on the shorter diagonal, n-gons (convex caps) fanned. Returns tris and the source face per tri."""
    tris, src = [], []
    for i, f in enumerate(faces):
        if len(f) == 3:
            tris.append(list(f))
            src.append(i)
        elif len(f) == 4:
            a, b, c, d = f
            if np.linalg.norm(verts[a] - verts[c]) <= np.linalg.norm(verts[b] - verts[d]):
                tris += [[a, b, c], [a, c, d]]
            else:
                tris += [[a, b, d], [b, c, d]]
            src += [i, i]
        else:
            for k in range(1, len(f) - 1):
                tris.append([f[0], f[k], f[k + 1]])
                src.append(i)
    return np.array(tris, np.int64), np.array(src, np.int64)


def face_geo(verts, tris):
    p = verts[tris]
    n = np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0])
    area = 0.5 * np.linalg.norm(n, axis=1)
    return p.mean(axis=1), unit(n), area


def signed_volume(verts, faces):
    v = np.asarray(verts, float)
    vol = 0.0
    for f in faces:
        a = v[f[0]]
        for k in range(1, len(f) - 1):
            vol += float(np.dot(a, np.cross(v[f[k]], v[f[k + 1]])))
    return vol / 6.0


def orient_outward(verts, faces):
    faces = [list(f) for f in faces]
    if signed_volume(verts, faces) < 0.0:
        faces = [f[::-1] for f in faces]
    return faces


def close_slab(top_v, top_f, offsets):
    """Disc-topology top surface -> closed slab: bottom = top + offsets (reversed), rim quads on the boundary.
    Face order: top, bottom, rim (the caller tags by counts)."""
    top_v = np.asarray(top_v, float)
    n = len(top_v)
    verts = np.concatenate([top_v, top_v + np.asarray(offsets, float)])
    faces = [list(f) for f in top_f] + [[i + n for i in reversed(f)] for f in top_f]
    directed = set()
    for f in top_f:
        for k in range(len(f)):
            directed.add((f[k], f[(k + 1) % len(f)]))
    rim = [[b, a, a + n, b + n] for (a, b) in directed if (b, a) not in directed]
    rim.sort()
    return verts, faces + rim, (len(top_f), len(top_f), len(rim))


def slab_tags(counts, names=("leaf_top", "leaf_bot", "leaf_rim")):
    return [names[0]] * counts[0] + [names[1]] * counts[1] + [names[2]] * counts[2]


def tube(path, radii, sides, phase=0.0, cap=True, jitter=0.0, rng=None):
    """Closed tube along a polyline (parallel-transport frames, n-gon caps)."""
    path = np.asarray(path, float)
    T = unit(np.gradient(path, axis=0))
    N = unit(np.cross(T[0], UP if abs(T[0][2]) < 0.9 else np.array([1.0, 0.0, 0.0])))
    ang = phase + TAU * np.arange(sides) / sides
    rings = []
    for i in range(len(path)):
        N = unit(N - np.dot(N, T[i]) * T[i])
        B = np.cross(T[i], N)
        rr = radii[i] * (1.0 + (rng.uniform(-jitter, jitter, sides) if jitter else 0.0))
        rings.append(path[i] + np.outer(np.cos(ang) * rr, N) + np.outer(np.sin(ang) * rr, B))
    v, f = fc.loft(rings, cap, cap)
    return v, orient_outward(v, f)


def spike(base, axis, r0, length, sides, profile, phase=0.0, bend=None, jitter=0.0, rng=None):
    """Closed cone from base along axis. profile = [(fraction of length, radius multiplier)], multiplier 0 = tip vertex.
    Returns verts, faces, band per face (-1 = base cap, k = band above ring k)."""
    axis = unit(axis)
    u, w = frame(axis)
    ang = phase + TAU * np.arange(sides) / sides
    verts, rings = [], []
    for f, m in profile:
        c = np.asarray(base, float) + axis * length * f
        if bend is not None:
            c = c + np.asarray(bend, float) * f * max(f, 0.0)
        if m <= 0.0:
            rings.append([len(verts)])
            verts.append(c)
        else:
            rr = r0 * m * (1.0 + (rng.uniform(-jitter, jitter, sides) if jitter else 0.0))
            rings.append(list(range(len(verts), len(verts) + sides)))
            verts.extend(c + np.outer(np.cos(ang) * rr, u) + np.outer(np.sin(ang) * rr, w))
    faces, bands = [rings[0][::-1]], [-1]
    for k, (a, b) in enumerate(zip(rings[:-1], rings[1:])):
        for s in range(sides):
            s2 = (s + 1) % sides
            faces.append([a[s], a[s2], b[0]] if len(b) == 1 else [a[s], a[s2], b[s2], b[s]])
            bands.append(k)
    verts = np.array(verts)
    return verts, orient_outward(verts, faces), bands


def bent_spine(p0, d0, length, K, toward, bend, power=1.6):
    """K+1 points from p0: the direction turns from d0 toward `toward` by `bend` radians, more toward the end."""
    d0 = unit(d0)
    axis = np.cross(d0, unit(toward))
    axis = unit(axis) if np.linalg.norm(axis) > 1e-6 else frame(d0)[0]
    pts = [np.asarray(p0, float)]
    for k in range(K):
        pts.append(pts[-1] + rotate(d0, axis, bend * ((k + 0.5) / K) ** power) * (length / K))
    return np.array(pts)


def spine_frames(spine, lateral):
    T = unit(np.gradient(spine, axis=0))
    lat = np.broadcast_to(np.asarray(lateral, float), T.shape)
    B = unit(lat - np.sum(lat * T, axis=1, keepdims=True) * T)
    N = np.cross(T, B)
    return T, B, N


def spine_leaf(spine, lateral, wl, wr, fold=0.15, thickness=0.1):
    """Closed thin leaf along a spine: midrib vertices on the spine (lowered by `fold` x relative width for a V
    fold), edge vertices at half widths wl / wr along B (ends must be 0). Top faces +N (= T x B)."""
    K = len(spine) - 1
    T, B, N = spine_frames(spine, lateral)
    wmax = max(float(np.max(wl)), float(np.max(wr)), 1e-6)
    verts, vn = [], []

    def add(p, n):
        verts.append(p)
        vn.append(n)
        return len(verts) - 1

    iM = [add(spine[k] - N[k] * fold * (wl[k] + wr[k]) * 0.5 / wmax, N[k]) for k in range(K + 1)]
    iL, iR = [None] * (K + 1), [None] * (K + 1)
    for k in range(1, K):
        iL[k] = add(spine[k] + B[k] * wl[k], N[k])
        iR[k] = add(spine[k] - B[k] * wr[k], N[k])
    faces = [[iM[0], iM[1], iL[1]], [iM[0], iR[1], iM[1]]]
    for k in range(1, K - 1):
        faces.append([iM[k], iM[k + 1], iL[k + 1], iL[k]])
        faces.append([iM[k], iR[k], iR[k + 1], iM[k + 1]])
    faces += [[iM[K - 1], iM[K], iL[K - 1]], [iM[K - 1], iR[K - 1], iM[K]]]
    v, f, counts = close_slab(np.array(verts), faces, -np.array(vn) * thickness)
    return v, f, counts


def blade(spine, lateral, width, thick, taper=1.0):
    """Closed sword leaf: diamond cross-section (edge, ridge, edge, keel) tapering to a tip vertex."""
    K = len(spine) - 1
    T, B, N = spine_frames(spine, lateral)
    verts = []
    for k in range(K):
        s = (1.0 - k / K) ** taper
        P = spine[k]
        verts += [P + B[k] * width * 0.5 * s, P + N[k] * thick * 0.5 * s, P - B[k] * width * 0.5 * s,
                  P - N[k] * thick * 0.5 * s]
    tip = len(verts)
    verts.append(spine[K])
    faces = [[3, 2, 1, 0]]
    for k in range(K - 1):
        a, b = 4 * k, 4 * (k + 1)
        faces += [[a + i, a + (i + 1) % 4, b + (i + 1) % 4, b + i] for i in range(4)]
    a = 4 * (K - 1)
    faces += [[a + i, a + (i + 1) % 4, tip] for i in range(4)]
    verts = np.array(verts)
    return verts, orient_outward(verts, faces)


# Half outline (0..180 deg in 20 deg steps, mirrored) of a coriander / flat-parsley leaflet: a rounded terminal lobe,
# two rounded side lobes, deep sinuses, a narrow base with the petiole notch at 180 deg.
LEAFLET_HALF = (1.0, 0.9, 0.52, 0.88, 0.96, 0.74, 0.42, 0.38, 0.28, 0.2)


def polar_leaf(center, xdir, normal, R, n_out, lobes, serr=0.12, cup=0.1, fold=0.12, dome=0.08, thick=0.09,
               rng=None):
    """Closed flat-leaf slab (parsley / coriander leaflet): star-shaped lobed outline fanned from `center`, petiole
    notch toward -xdir, alternating serration, cupped and V-folded. lobes = a half outline sampled every 360/n_out
    degrees from the tip (mirrored), or [(angle, amplitude, power)] lobe terms. Returns verts, faces, counts."""
    Z = unit(normal)
    X = unit(np.asarray(xdir, float) - np.dot(xdir, Z) * Z)
    Y = np.cross(Z, X)
    phi = TAU * np.arange(n_out) / n_out
    if np.ndim(lobes) == 1:
        half = np.asarray(lobes, float)
        idx = np.minimum(np.arange(n_out), n_out - np.arange(n_out))
        r = R * half[np.minimum(idx, len(half) - 1)]
    else:
        L = np.zeros(n_out)
        for pk, ak, pw in lobes:
            L += ak * np.maximum(0.0, np.cos(wrap(phi - pk))) ** pw
        r = R * (0.36 + 0.64 * np.minimum(L, 1.0))
        r *= 1.0 - 0.6 * np.maximum(0.0, np.cos(phi - math.pi)) ** 8
    if rng is not None:
        r *= 1.0 + rng.uniform(-0.07, 0.07, n_out)
    r *= 1.0 + serr * np.where(np.arange(n_out) % 2 == 0, 1.0, -1.0)
    x, y = r * np.cos(phi), r * np.sin(phi)
    z = cup * R * (r / R) ** 2 + fold * np.abs(y)
    local = np.vstack([[0.0, 0.0, dome], np.stack([x, y, z], 1)])
    world = np.asarray(center, float) + local[:, :1] * X + local[:, 1:2] * Y + local[:, 2:3] * Z
    faces = [[0, 1 + i, 1 + (i + 1) % n_out] for i in range(n_out)]
    v, f, counts = close_slab(world, faces, np.tile(-Z * thick, (len(world), 1)))
    return v, f, counts


# ---------------------------------------------------------------- revolved bodies with hand-cut hull facets
class Revolve:
    """A pole-to-pole (r, z) profile (Catmull-Rom through knots), parametrised by arc-length fraction t (0 = bottom
    pole). phi(t) is the conformal latitude, so a spherical Delaunay (convex hull) maps to even facets on the body."""

    def __init__(self, knots, per_seg=48):
        k = np.asarray(knots, float)
        P = np.vstack([2 * k[0] - k[1], k, 2 * k[-1] - k[-2]])
        pts = []
        s = np.linspace(0.0, 1.0, per_seg, endpoint=False)[:, None]
        for i in range(1, len(P) - 2):
            p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
            pts.append(0.5 * (2 * p1 + (p2 - p0) * s + (2 * p0 - 5 * p1 + 4 * p2 - p3) * s ** 2
                              + (3 * p1 - p0 - 3 * p2 + p3) * s ** 3))
        pts.append(k[-1:])
        pts = np.concatenate(pts)
        pts[:, 0] = np.maximum(pts[:, 0], 0.0)
        pts[0, 0] = pts[-1, 0] = 0.0
        seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
        pts = pts[np.concatenate([[True], seg > 1e-9])]
        seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
        s = np.concatenate([[0.0], np.cumsum(seg)])
        self.L = float(s[-1])
        self.t = s / self.L
        self.r, self.z = pts[:, 0], pts[:, 1]
        tr, tz = np.gradient(self.r, s), np.gradient(self.z, s)
        ln = np.maximum(np.hypot(tr, tz), 1e-12)
        self.nr, self.nz = tz / ln, -tr / ln
        rr = np.maximum(self.r, 2e-3 * self.L)
        M = np.concatenate([[0.0], np.cumsum(0.5 * (1.0 / rr[1:] + 1.0 / rr[:-1]) * seg)])
        M -= M[int(np.argmax(self.r))]
        self.phi = 2.0 * np.arctan(np.exp(np.clip(M, -30, 30)))
        self.phi[0], self.phi[-1] = 0.0, math.pi
        dA = 0.5 * (self.r[1:] + self.r[:-1]) * seg * TAU
        A = np.concatenate([[0.0], np.cumsum(dA)])
        self.area = float(A[-1])
        self.A = A / self.area

    def at(self, t, arr):
        return np.interp(t, self.t, arr)

    def r_at(self, t):
        return self.at(t, self.r)

    def t_at_z(self, z):
        return np.interp(z, np.maximum.accumulate(self.z), self.t)

    def z_top(self, rho):
        i0 = int(np.argmax(self.r))
        r = np.maximum.accumulate(self.r[i0:][::-1])
        return np.interp(rho, r, self.z[i0:][::-1])

    def normal3(self, t, th):
        t, th = np.broadcast_arrays(np.asarray(t, float), np.asarray(th, float))
        nr, nz = self.at(t, self.nr), self.at(t, self.nz)
        return np.stack([nr * np.cos(th), nr * np.sin(th), nz], -1)

    def xyz(self, t, th, rmul=1.0, lift=0.0):
        t, th = np.broadcast_arrays(np.asarray(t, float), np.asarray(th, float))
        r = self.r_at(t) * rmul
        z = self.at(t, self.z)
        p = np.stack([r * np.cos(th), r * np.sin(th), z], -1)
        lift = np.asarray(lift, float)
        if np.any(lift):
            p = p + self.normal3(t, th) * (lift[..., None] if lift.ndim else lift)
        return p


def surface_points(shape, n, seed, jitter=0.33):
    """Area-even golden-spiral points (t, theta) on the body with a jitter of `jitter` x the mean spacing."""
    rng = np.random.default_rng(seed)
    f = (np.arange(n) + 0.5) / n
    t = np.interp(f, shape.A, shape.t)
    th = np.arange(n) * GOLDEN + rng.uniform(0.0, TAU)
    h = math.sqrt(shape.area / n)
    r = shape.r_at(t)
    t = np.clip(t + rng.uniform(-1, 1, n) * jitter * h / shape.L, 0.004, 0.996)
    th = th + rng.uniform(-1, 1, n) * jitter * h / np.maximum(r, h)
    return t, wrap(th)


def ring_feature(shape, tc, thc, radius, m, phase=0.0, sx=1.0, sy=1.0):
    """m points on a circle (ellipse with sx / sy) of `radius` cm around (tc, thc) in surface units."""
    a = phase + TAU * np.arange(m) / m
    rc = max(float(shape.r_at(tc)), 1e-3)
    return tc + radius * sy * np.sin(a) / shape.L, thc + radius * sx * np.cos(a) / rc


def in_ellipse(shape, t, th, tc, thc, ah, av, scale=1.0):
    rc = max(float(shape.r_at(tc)), 1e-3)
    return (wrap(np.asarray(th) - thc) * rc / (ah * scale)) ** 2 + ((np.asarray(t) - tc) * shape.L / (av * scale)) ** 2


def near3(shape, t, th, tc, thc, radius):
    return np.linalg.norm(shape.xyz(t, th) - shape.xyz(tc, thc), axis=-1) < radius


def body_surface(shape, t, th, seed, low_amp, low_freq, rmul_fn=None):
    t, th = np.atleast_1d(t).astype(float), np.atleast_1d(th).astype(float)
    rmul = rmul_fn(t, th) if rmul_fn else 1.0
    p0 = shape.xyz(t, th, rmul)
    n = shape.normal3(t, th)
    return p0 + n * (low_amp * fc.lumps(p0, seed, low_freq))[:, None], n


def hull_body(shape, n, seed, features, exclude=None, jitter=0.33, low_amp=0.2, low_freq=0.3, vert_amp=0.06,
              rmul_fn=None, poles=(True, True)):
    """Closed triangulated body. features = [(name, t array, theta array)] inserted verbatim (never excluded);
    exclude(t, th) -> mask of generated points to drop. Returns dict(verts, faces, t, th, normals, groups)."""
    t, th = surface_points(shape, n, seed, jitter)
    if exclude is not None:
        keep = ~exclude(t, th)
        t, th = t[keep], th[keep]
    feats = list(features)
    if poles[0]:
        feats.append(("pole_bottom", [0.0], [0.0]))
    if poles[1]:
        feats.append(("pole_top", [1.0], [0.0]))
    groups, T, TH, idx = {"gen": np.arange(len(t))}, [t], [th], len(t)
    for name, ft, fth in feats:
        ft, fth = np.atleast_1d(np.asarray(ft, float)), np.atleast_1d(np.asarray(fth, float))
        groups[name] = np.arange(idx, idx + len(ft))
        T.append(ft)
        TH.append(fth)
        idx += len(ft)
    t, th = np.concatenate(T), wrap(np.concatenate(TH))
    phi = shape.at(t, shape.phi)
    u = np.stack([np.sin(phi) * np.cos(th), np.sin(phi) * np.sin(th), -np.cos(phi)], -1)
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in u]
    bmesh.ops.convex_hull(bm, input=vs, use_existing_faces=False)
    bm.verts.index_update()
    faces = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()
    used = np.zeros(len(t), bool)
    for f in faces:
        used[f] = True
    if not used.all():
        print("  hull dropped %d coincident points" % int((~used).sum()))
        remap = np.cumsum(used) - 1
        faces = [[int(remap[i]) for i in f] for f in faces]
        groups = {k: remap[g[used[g]]] for k, g in groups.items()}
        t, th = t[used], th[used]
    rng = np.random.default_rng(seed + 1)
    p, nrm = body_surface(shape, t, th, seed, low_amp, low_freq, rmul_fn)
    p = p + nrm * (vert_amp * rng.uniform(-1, 1, len(t)))[:, None]
    return dict(verts=p, faces=faces, t=t, th=th, normals=nrm, groups=groups)


def bead_features(shape, key, tc, thc, rho, rings):
    """Centre + rings [(radius fraction, count)] -> feature list for a domed eye / pout cluster."""
    feats = [(key + "_c", [tc], [thc])]
    for i, (fr, m) in enumerate(rings):
        t, th = ring_feature(shape, tc, thc, rho * fr, m, phase=0.5 * i * TAU / m)
        feats.append(("%s_r%d" % (key, i), t, th))
    return feats


def carve_mouth(verts, faces, tags, region, depth, back_scale, lip):
    """Inset the faces whose vertices are all in `region` (the lip ring), extrude them into the body by `depth`
    along their mean normal, flatten and shrink the back wall. Returns verts, faces, tags and the lip loop info."""
    names = sorted(set(tags) | {"mouth_back", "mouth_wall", "lip"})
    code = {n: i for i, n in enumerate(names)}
    bm = bmesh.new()
    layer = bm.faces.layers.int.new("tag")
    vs = [bm.verts.new(p) for p in verts]
    for f, tg in zip(faces, tags):
        bm.faces.new([vs[i] for i in f])[layer] = code[tg]
    bm.verts.index_update()
    bm.normal_update()
    F = [f for f in bm.faces if all(region[v.index] for v in f.verts)]
    facing = unit(np.sum([np.array(f.normal[:]) * f.calc_area() for f in F], axis=0))
    res = bmesh.ops.inset_region(bm, faces=F, thickness=lip, depth=0.0, use_even_offset=True)
    for f in res["faces"]:
        f[layer] = code["lip"]
    Fs = set(F)
    bedges = [e for f in F for e in f.edges if sum(1 for lf in e.link_faces if lf in Fs) == 1]
    adj = {}
    for e in bedges:
        a, b = e.verts
        adj.setdefault(a, []).append(b)
        adj.setdefault(b, []).append(a)
    start = bedges[0].verts[0]
    loop, prev, cur = [start], None, start
    while True:
        nb = adj[cur]
        nxt = nb[0] if nb[0] is not prev else nb[1]
        if nxt is start:
            break
        loop.append(nxt)
        prev, cur = cur, nxt
    if len(loop) != len(bedges):
        raise RuntimeError("mouth region boundary is not one loop (%d / %d)" % (len(loop), len(bedges)))
    loop_co = np.array([v.co[:] for v in loop], float)
    c = loop_co.mean(axis=0)
    ext = bmesh.ops.extrude_face_region(bm, geom=F)
    newv = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]
    newf = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMFace)]
    bmesh.ops.delete(bm, geom=F, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    cb = c - facing * depth
    for v in newv:
        d = np.array(v.co[:]) - c
        d -= facing * np.dot(d, facing)
        v.co = Vector(cb + d * back_scale)
    for f in newf:
        f[layer] = code["mouth_back"]
    ns = set(newv)
    for f in bm.faces:
        inn = [v in ns for v in f.verts]
        if any(inn) and not all(inn):
            f[layer] = code["mouth_wall"]
    bm.verts.index_update()
    V = np.array([v.co[:] for v in bm.verts], float)
    Fo = [[v.index for v in f.verts] for f in bm.faces]
    To = [names[f[layer]] for f in bm.faces]
    bm.free()
    return V, Fo, To, dict(loop=loop_co, center=c, facing=facing, back=cb)


def lip_teeth(info, top, bottom, forward=0.0, up=UP):
    """Closed wedge teeth on the lip loop. top / bottom = [(fraction along the upper / lower arc, length, width)].
    Returns [(verts, faces, anchor)]."""
    loop, c, n = info["loop"], info["center"], info["facing"]
    lat = unit(np.cross(up, n))
    upv = unit(np.cross(n, lat))
    rel = loop - c
    a, b = rel @ lat, rel @ upv
    out = []
    for sign, specs in ((1.0, top), (-1.0, bottom)):
        if not specs:
            continue
        sel = np.where(b * sign > 0)[0]
        arc = loop[sel[np.argsort(a[sel])]]
        s = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(arc, axis=0), axis=1))])
        s /= s[-1]
        for frac, length, width in specs:
            p = np.array([np.interp(frac, s, arc[:, k]) for k in range(3)])
            G = unit(-sign * upv - 0.18 * np.sign(np.dot(p - c, lat)) * lat + forward * n)
            D = -n
            Tt = unit(np.cross(G, D))
            bc = p + D * 0.25 * width - G * 0.2 * width
            v = np.array([bc + Tt * width * 0.5, bc - Tt * width * 0.5, bc + D * width * 0.9,
                          bc + G * length + D * length * (0.28 - forward)])
            out.append((v, orient_outward(v, [[0, 1, 2], [0, 3, 1], [1, 3, 2], [2, 3, 0]]), p))
    return out


# ---------------------------------------------------------------- shading data
def vertex_normals(verts, tris):
    p = verts[tris]
    fn = np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0])
    vn = np.zeros_like(verts)
    for k in range(3):
        np.add.at(vn, tris[:, k], fn)
    return unit(vn)


def vertex_ao(verts, tris, dist, n_rays=40, seed=5):
    """Ray-traced ambient occlusion per vertex (1 open), BVH over the mesh itself, cosine-weighted hemisphere."""
    bvh = BVHTree.FromPolygons([tuple(v) for v in verts], [tuple(int(i) for i in t) for t in tris], all_triangles=True)
    rng = np.random.default_rng(seed)
    u1, u2 = rng.random(n_rays), rng.random(n_rays)
    local = np.stack([np.sqrt(u1) * np.cos(TAU * u2), np.sqrt(u1) * np.sin(TAU * u2), np.sqrt(1.0 - u1)], 1)
    vn = vertex_normals(verts, tris)
    ao = np.empty(len(verts))
    for i in range(len(verts)):
        n = vn[i]
        u, w = frame(n)
        dirs = local[:, :1] * u + local[:, 1:2] * w + local[:, 2:3] * n
        o = Vector(verts[i] + n * 0.01)
        hits = 0
        for d in dirs:
            if bvh.ray_cast(o, Vector(d), dist)[0] is not None:
                hits += 1
        ao[i] = 1.0 - hits / n_rays
    return ao


def vertex_convexity(verts, tris):
    """0..1 per vertex: the strongest convex dihedral among its edges (pi / 2.2 -> 1)."""
    _, fn, _ = face_geo(verts, tris)
    e = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]])
    fid = np.tile(np.arange(len(tris)), 3)
    opp = np.concatenate([tris[:, 2], tris[:, 0], tris[:, 1]])
    key = np.sort(e, axis=1)
    order = np.lexsort((key[:, 1], key[:, 0]))
    ks = key[order]
    same = np.all(ks[1:] == ks[:-1], axis=1)
    i1, i2 = order[:-1][same], order[1:][same]
    f1, f2 = fid[i1], fid[i2]
    ang = np.arccos(np.clip(np.sum(fn[f1] * fn[f2], axis=1), -1.0, 1.0))
    side = np.sum((verts[opp[i2]] - verts[e[i1, 0]]) * fn[f1], axis=1)
    sang = np.where(side < 0.0, ang, -ang)
    conv = np.zeros(len(verts))
    for col in (0, 1):
        np.maximum.at(conv, key[i1, col], sang)
    return np.clip(conv / (math.pi / 2.2), 0.0, 1.0)


def bake_vertex_scalar(obj, values, size, domain="POINT"):
    """Cycles EMIT bake of a per-vertex (POINT) or per-corner (CORNER) scalar through UV0 -> (size, size) array."""
    mesh = obj.data
    attr = mesh.color_attributes.new("_BakeScalar", "FLOAT_COLOR", domain)
    cols = np.ones((len(values), 4))
    cols[:, :3] = np.asarray(values, float)[:, None]
    attr.data.foreach_set("color", cols.ravel())
    mat = bpy.data.materials.new("_BakeEmit")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    a = nt.nodes.new("ShaderNodeAttribute")
    a.attribute_name = "_BakeScalar"
    em = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(a.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    img = bpy.data.images.new("_bake_scalar", size, size, alpha=True, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.nodes.active = tex
    saved = [m for m in mesh.materials]
    for i in range(len(mesh.materials)):
        mesh.materials[i] = mat
    scene = bpy.context.scene
    prev = (scene.render.engine, scene.cycles.samples)
    fc._only(obj)
    try:
        scene.render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        scene.cycles.samples = 1
        scene.render.bake.margin = 4
        scene.render.bake.use_clear = True
        scene.render.bake.use_selected_to_active = False
        bpy.ops.object.bake(type="EMIT", margin=4, use_clear=True)
        px = np.empty(size * size * 4, np.float32)
        img.pixels.foreach_get(px)
    finally:
        for i, m in enumerate(saved):
            mesh.materials[i] = m
        scene.render.engine, scene.cycles.samples = prev
        mesh.color_attributes.remove(mesh.color_attributes["_BakeScalar"])
        bpy.data.images.remove(img)
        bpy.data.materials.remove(mat)
        col = mesh.color_attributes.get(spec.COLOR_ATTR)
        if col is not None:
            idx = list(mesh.color_attributes).index(col)
            mesh.color_attributes.active_color_index = idx
            mesh.color_attributes.render_color_index = idx
    return px.reshape(size, size, 4)[..., 0]


def make_masks(conv_img, center, height, seed, neutral=False, cut_img=None):
    """Spec mask channels from the baked fields: R cook-first, G speckle, B break-up, A rim (convex edges x AO).
    cut_img (authored cut sections): the cut Flesh faces brown first, R = 0.92 x the baked cut value."""
    def fn(f):
        p, n, ao = f["position_cm"], f["normal"], np.clip(f["ao"], 0.0, 1.0)
        rim = fc.smoothstep(0.15, 0.55, conv_img) * np.sqrt(ao)
        if neutral:
            R = np.full(ao.shape, 0.3)
            G = np.clip(0.5 + 0.35 * (fc.fbm(p * 1.2, seed) - 0.5), 0.0, 1.0)
            B = np.full(ao.shape, 0.5)
        else:
            rad = unit(p - np.asarray(center, float))
            outward = np.sum(n * rad, axis=-1)
            hz = np.clip(p[..., 2] / height, 0.0, 1.0)
            R = np.clip(0.2 + 0.3 * n[..., 2] + 0.3 * outward + 0.2 * hz + 0.3 * rim, 0.0, 1.0)                 * fc.smoothstep(0.08, 0.75, ao)
            G = np.clip(0.5 + 1.1 * (fc.fbm(p * 1.9, seed) - 0.5), 0.0, 1.0)
            B = np.clip(0.5 + 1.2 * (fc.fbm(p * 0.42 + 5.3, seed + 11) - 0.5), 0.0, 1.0)
            if cut_img is not None:
                R = np.maximum(R, 0.92 * np.clip(cut_img, 0.0, 1.0))
        return np.stack([R, G, B, rim], axis=-1)
    return fn


# ---------------------------------------------------------------- finalise: triangles, size, colours, morph
def finalize(g, name, colorize, morph=None):
    verts = np.concatenate(g.v)
    tris, src = triangulate(verts, g.f)
    tags = [g.ftag[i] for i in src]
    fslot = [g.fslot[i] for i in src]
    vpart = np.array(g.vpart)
    used = np.zeros(len(verts), bool)
    used[tris.ravel()] = True
    if not used.all():
        raise RuntimeError("%s: %d unreferenced vertices" % (name, int((~used).sum())))
    size = spec.INGREDIENTS[name]["size_cm"]
    lo, hi = verts.min(axis=0), verts.max(axis=0)
    s = size / float((hi - lo).max())
    off = -np.array([(lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, lo[2]]) * s
    verts = verts * s + off

    def xf(p):
        return np.asarray(p, float) * s + off

    c, n, area = face_geo(verts, tris)
    if area.min() < 1e-7:
        print("  WARN %s: %d near-degenerate triangles" % (name, int((area < 1e-7).sum())))
    noise = np.random.default_rng(seed_of(name)).uniform(-1.0, 1.0, len(tris))
    rgb = np.asarray(colorize(tags, c, n, noise, verts), float)
    for k, i in enumerate(src):
        if g.fcol[i] is not None:
            rgb[k] = g.fcol[i]
    cooked = morph(verts, vpart, g.parts, xf) if morph else None
    return dict(verts=verts, tris=tris, fslot=fslot, rgb=rgb, tags=tags, cooked=cooked, slots=g.slots, scale=s)


def tag_rgb(tags, table, default=None):
    out = np.zeros((len(tags), 3))
    for i, t in enumerate(tags):
        out[i] = table.get(t, default if default is not None else (1.0, 0.0, 1.0))
    return out


# ================================================================ PUFFER
def build_puffer():
    name = "Puffer"
    rng = np.random.default_rng(1401)
    g = Geo(("Skin", "Horn"))
    R, RZ = 5.1, 4.4
    a = np.linspace(0.0, math.pi, 17)
    zc = -np.cos(a)
    zc = np.where(zc < 0.0, -np.abs(zc) ** 0.8, zc)               # a slightly flatter seat
    shape = Revolve(np.stack([R * np.sin(a), RZ * zc], 1))
    eyes = [(0.603, 0.36), (0.596, -0.385)]
    pout = (0.468, 0.015)
    EYE, POUT = 0.8, 0.62
    feats = []
    for i, (te, the) in enumerate(eyes):
        feats += bead_features(shape, "eye%d" % i, te, the, EYE, ((0.48, 6), (1.0, 8)))
    feats += bead_features(shape, "pout", pout[0], pout[1], POUT, ((0.55, 6), (1.0, 8)))

    def exclude(t, th):
        m = np.zeros(len(t), bool)
        for te, the in eyes:
            m |= near3(shape, t, th, te, the, EYE * 1.42)
        return m | near3(shape, t, th, pout[0], pout[1], POUT * 1.4)

    LOW = dict(seed=1402, low_amp=0.2, low_freq=0.28)
    body = hull_body(shape, 560, LOW["seed"], feats, exclude, jitter=0.34, low_amp=LOW["low_amp"],
                     low_freq=LOW["low_freq"], vert_amp=0.07)
    V, F, N, G = body["verts"], body["faces"], body["normals"], body["groups"]
    for i in range(2):
        for key, d in (("_c", 0.46), ("_r0", 0.34), ("_r1", 0.1)):
            V[G["eye%d%s" % (i, key)]] += N[G["eye%d%s" % (i, key)]] * d
    for key, d in (("_c", -0.3), ("_r0", 0.26), ("_r1", 0.05)):
        V[G["pout" + key]] += N[G["pout" + key]] * d
    eye_sets = [set(np.concatenate([G["eye%d%s" % (i, k)] for k in ("_c", "_r0", "_r1")]).tolist()) for i in range(2)]
    pc = int(G["pout_c"][0])
    pset = set(np.concatenate([G["pout_c"], G["pout_r0"], G["pout_r1"]]).tolist())
    tags = []
    for f in F:
        fs = set(f)
        if any(fs <= es for es in eye_sets):
            tags.append("eye")
        elif pc in fs:
            tags.append("pout_in")
        elif fs <= pset:
            tags.append("pout_lip")
        else:
            tags.append("skin")
    g.add(V, F, "Skin", tags=tags)

    # spikes: jittered golden spiral, none on the seat, none on the face
    ts, ths = surface_points(shape, 27, 1403, jitter=0.3)
    ok = ts > 0.31
    for te, the in eyes:
        ok &= ~near3(shape, ts, ths, te, the, 2.25)
    ok &= ~near3(shape, ts, ths, pout[0], pout[1], 1.8)
    ts, ths = ts[ok], ths[ok]
    roots, nrm = body_surface(shape, ts, ths, LOW["seed"], LOW["low_amp"], LOW["low_freq"])
    for k in range(len(ts)):
        axis = unit(nrm[k] + rng.normal(size=3) * 0.13)
        length, r0 = rng.uniform(1.55, 2.05), rng.uniform(0.7, 0.9)
        bend = unit(np.cross(axis, rng.normal(size=3))) * rng.uniform(0.08, 0.3)
        sv, sf, bands = spike(roots[k], axis, r0, length, int(rng.choice([5, 6])),
                              [(-0.22, 1.0), (0.4, 0.56), (1.0, 0.0)], phase=rng.uniform(0, TAU), bend=bend,
                              jitter=0.08, rng=rng)
        pid = g.part("spike", root=roots[k])
        g.add(sv, sf, "Horn", part=pid,
              tags=["horn_cap" if b < 0 else ("horn_base" if b == 0 else "horn_tip") for b in bands])
    print("  Puffer: %d spikes" % len(ts))

    O, Y, BELLY, TOP = C(236, 124, 30), C(247, 170, 60), C(249, 205, 138), C(220, 92, 22)

    def colorize(tags, c, n, noise, verts):
        rgb = tag_rgb(tags, {"eye": C(14, 10, 9), "pout_in": C(72, 22, 14), "pout_lip": C(234, 112, 66),
                             "horn_base": C(226, 116, 32), "horn_cap": C(226, 116, 32), "horn_tip": C(176, 80, 24)})
        skin = np.array([t == "skin" for t in tags])
        base = mix(O, Y, np.clip(0.22 + 0.25 * noise, 0.0, 0.5))
        base = mix(base, BELLY, 0.85 * fc.smoothstep(-0.12, -0.75, n[:, 2]))
        base = mix(base, TOP, 0.45 * fc.smoothstep(0.45, 0.95, n[:, 2]))
        rgb[skin] = base[skin]
        tip = np.array([t == "horn_tip" for t in tags])
        rgb[tip] = mix(rgb[tip], C(196, 92, 26), 0.5 + 0.5 * noise[tip])
        return rgb

    def morph(verts, vpart, parts, xf):
        ck = verts.copy()
        body = vpart == 0
        lo, hi = verts[body].min(axis=0), verts[body].max(axis=0)
        c = 0.5 * (lo + hi)
        ck[body] = c + PUFFER_PUFF * (verts[body] - c)
        dz = lo[2] - ck[body][:, 2].min()
        ck[body, 2] += dz
        for pid, meta in parts.items():
            m = vpart == pid
            root = xf(meta["root"])
            root_ck = c + PUFFER_PUFF * (root - c) + np.array([0.0, 0.0, dz])
            ck[m] = verts[m] + PUFFER_SPIKE_FOLLOW * (root_ck - root)
        return ck

    return finalize(g, name, colorize, morph)


# ================================================================ TURNIP
def build_turnip():
    name = "Turnip"
    rng = np.random.default_rng(1601)
    g = Geo(("Skin", "Leaf"))
    shape = Revolve([(0.0, 0.55), (0.34, 0.88), (0.8, 1.3), (1.78, 1.82), (3.05, 2.5), (4.2, 3.45), (4.8, 4.65),
                     (4.78, 5.85), (4.28, 6.9), (3.35, 7.7), (2.2, 8.25), (1.1, 8.55), (0.0, 8.66)])
    tm, thm, AH, AV = float(shape.t_at_z(4.55)), 0.0, 2.75, 1.8
    eyes = [(float(shape.t_at_z(7.05)), 0.405), (float(shape.t_at_z(7.0)), -0.42)]
    EYE = 0.5
    feats = [("mouth_c", [tm], [thm])]
    for key, sc, m, ph in (("mouth_ring", 1.0, 18, 0.0), ("mouth_out", 1.24, 18, 0.5), ("mouth_in", 0.5, 8, 0.25)):
        t, th = ring_feature(shape, tm, thm, 1.0, m, phase=ph * TAU / m, sx=AH * sc, sy=AV * sc)
        feats.append((key, t, th))
    for i, (te, the) in enumerate(eyes):
        feats += bead_features(shape, "eye%d" % i, te, the, EYE, ((1.0, 6),))

    def exclude(t, th):
        m = in_ellipse(shape, t, th, tm, thm, AH, AV, 1.42) <= 1.0
        for te, the in eyes:
            m |= near3(shape, t, th, te, the, EYE * 1.5)
        return m

    body = hull_body(shape, 470, 1602, feats, exclude, jitter=0.34, low_amp=0.2, low_freq=0.3, vert_amp=0.07)
    V, F, N, G = body["verts"], body["faces"], body["normals"], body["groups"]
    V[:, 0] += 0.12 * (np.clip(V[:, 2], 0, None) / 8.66) ** 2            # a slight lean, no two turnips alike
    for i in range(2):
        V[G["eye%d_c" % i]] += N[G["eye%d_c" % i]] * 0.32
        V[G["eye%d_r0" % i]] += N[G["eye%d_r0" % i]] * 0.08
    eye_sets = [set(np.concatenate([G["eye%d_c" % i], G["eye%d_r0" % i]]).tolist()) for i in range(2)]
    tags = ["eye" if any(set(f) <= es for es in eye_sets) else "skin" for f in F]
    region = in_ellipse(shape, body["t"], body["th"], tm, thm, AH, AV, 1.0) <= 1.002
    V, F, tags, mouth = carve_mouth(V, F, tags, region, depth=2.5, back_scale=0.7, lip=0.26)
    g.add(V, F, "Skin", tags=tags)
    jit = rng.uniform(-0.03, 0.03, 9)
    top = [(f + jit[i], rng.uniform(0.72, 0.98), rng.uniform(0.56, 0.72))
           for i, f in enumerate((0.11, 0.3, 0.5, 0.7, 0.89))]
    bot = [(f + jit[5 + i], rng.uniform(0.6, 0.82), rng.uniform(0.52, 0.66))
           for i, f in enumerate((0.17, 0.39, 0.61, 0.83))]
    for tv, tf, _ in lip_teeth(mouth, top, bot):
        g.add(tv, tf, "Skin", "tooth")

    # three root legs (the turnip of reference 3 stands on them); the taproot hangs between them
    for th in (0.62 + rng.uniform(-0.1, 0.1), 2.6 + rng.uniform(-0.1, 0.1), -2.0 + rng.uniform(-0.1, 0.1)):
        t0 = float(shape.t_at_z(1.95))
        root, _ = body_surface(shape, [t0], [th], 1602, 0.2, 0.3)
        radial = np.array([math.cos(th), math.sin(th), 0.0])
        d = unit(radial * 0.8 - UP * 0.62)
        lv, lf, bands = spike(root[0] - d * 0.55, d, rng.uniform(0.66, 0.76), rng.uniform(2.1, 2.4), 6,
                              [(0.0, 1.0), (0.42, 0.74), (0.76, 0.44), (1.0, 0.0)], phase=rng.uniform(0, TAU),
                              bend=-UP * 0.55 + radial * 0.1, jitter=0.08, rng=rng)
        g.add(lv, lf, "Skin", tags=["leg_tip" if b >= 2 else "leg" for b in bands])

    # leaf crown: six lobed, serrated leaves on stems
    crown_z = 8.3
    n_leaves = 6
    for i in range(n_leaves):
        psi = i * TAU / n_leaves + 0.3 + rng.uniform(-0.25, 0.25)
        o = np.array([math.cos(psi), math.sin(psi), 0.0])
        lean = rng.uniform(0.22, 0.6)
        P0 = np.array([0.3 * o[0], 0.3 * o[1], crown_z])
        stem = bent_spine(P0, o * math.sin(lean) + UP * math.cos(lean), rng.uniform(2.0, 2.8), 4, o, 0.18)
        pid = g.part("leaf", pivot=P0, out=o)
        sv, sf = tube(stem, np.linspace(0.24, 0.15, len(stem)), 5, phase=rng.uniform(0, TAU))
        g.add(sv, sf, "Leaf", "stem", part=pid)
        d_end = unit(stem[-1] - stem[-2])
        spine = bent_spine(stem[-1] - d_end * 0.3, d_end, rng.uniform(4.4, 5.4), 9, unit(o - 0.55 * UP),
                           rng.uniform(0.5, 0.85))
        W = rng.uniform(1.5, 1.85)
        prof = np.array([0.0, 0.34, 0.2, 0.58, 0.44, 0.86, 1.0, 0.88, 0.5, 0.0])
        serr = 1.0 + 0.1 * np.where(np.arange(10) % 2 == 0, 1.0, -1.0)
        wl = W * prof * serr * rng.uniform(0.9, 1.1, 10)
        wr = W * prof * serr[::-1] * rng.uniform(0.9, 1.1, 10)
        wl[0] = wl[-1] = wr[0] = wr[-1] = 0.0
        lateral = rotate(unit(np.cross(UP, o)), o, rng.uniform(-0.3, 0.3))
        lv, lf, counts = spine_leaf(spine, lateral, wl, wr, fold=0.16, thickness=0.1)
        shade = rng.uniform(-0.08, 0.08)
        g.add(lv, lf, "Leaf", part=pid, tags=slab_tags(counts),
              color=np.array([C(62, 134, 44)] * counts[0] + [C(100, 162, 72)] * counts[1]
                             + [C(80, 148, 56)] * counts[2]) * (1.0 + shade))

    WHITE, MAG, DEEP, TAN = C(240, 234, 222), C(198, 36, 100), C(148, 22, 78), C(214, 200, 170)

    def colorize(tags, c, n, noise, verts):
        rgb = tag_rgb(tags, {"eye": C(16, 10, 12), "mouth_wall": C(98, 16, 30), "mouth_back": C(58, 8, 18),
                             "tooth": C(246, 240, 226), "leg": C(236, 228, 214), "leg_tip": C(190, 34, 72),
                             "stem": C(104, 150, 58)})
        h = verts[:, 2].max()
        zb = c[:, 2] / max(h, 1e-6) * 16.0                                     # in the design's cm (16 cm tall)
        skin = mix(WHITE, MAG, fc.smoothstep(5.8, 7.6, zb + 0.6 * noise))
        skin = mix(skin, DEEP, fc.smoothstep(8.0, 8.8, zb))
        skin = mix(skin, TAN, 0.6 * fc.smoothstep(1.6, 0.6, zb))
        for i, t in enumerate(tags):
            if t in ("skin", "lip"):
                rgb[i] = skin[i] * (0.93 if t == "lip" else 1.0)
            elif t in ("mouth_wall", "mouth_back") and zb[i] < 4.1:
                rgb[i] = C(196, 66, 92) * (0.8 if t == "mouth_back" else 1.0)  # tongue
            elif t == "leg":
                rgb[i] = mix(C(236, 228, 214), MAG, 0.25 * fc.smoothstep(0.0, 1.0, noise[i]))
        return rgb

    def morph(verts, vpart, parts, xf):
        body = vpart == 0
        lo, hi = verts[body].min(axis=0), verts[body].max(axis=0)
        cxy = 0.5 * (lo + hi)

        def bxf(p):
            q = np.array(p, float)
            q[..., :2] = cxy[:2] + TURNIP_SAG[0] * (q[..., :2] - cxy[:2])
            q[..., 2] = lo[2] + TURNIP_SAG[1] * (q[..., 2] - lo[2])
            return q

        ck = verts.copy()
        ck[body] = bxf(verts[body])
        for pid, meta in parts.items():
            m = vpart == pid
            P = xf(meta["pivot"])
            d = verts[m] - P
            dist = np.linalg.norm(d, axis=1)
            frac = np.clip(dist / dist.max(), 0.0, 1.0)
            ck[m] = bxf(P) + rotate(TURNIP_LEAF_SHRINK * d, np.cross(UP, meta["out"]), 0.35 + 0.55 * frac ** 1.3)
        return ck

    return finalize(g, name, colorize, morph)


# ================================================================ SPIKED BERRY
def build_spiked_berry():
    name = "SpikedBerry"
    rng = np.random.default_rng(1001)
    g = Geo(("Skin", "Horn"))
    R, RZ = 4.2, 3.55
    a = np.linspace(0.0, math.pi, 17)
    zc = -np.cos(a)
    zc = np.where(zc < 0.0, -np.abs(zc) ** 0.82, zc)
    shape = Revolve(np.stack([R * np.sin(a), RZ * zc], 1))
    tm, thm, AH, AV = float(shape.t_at_z(-0.7)), 0.0, 1.95, 0.8
    eyes = [(float(shape.t_at_z(1.15)), 0.43), (float(shape.t_at_z(1.1)), -0.45)]
    EYE = 0.62
    feats = [("mouth_c", [tm], [thm])]
    for key, sc, m, ph in (("mouth_ring", 1.0, 16, 0.0), ("mouth_out", 1.24, 16, 0.5), ("mouth_in", 0.5, 7, 0.25)):
        t, th = ring_feature(shape, tm, thm, 1.0, m, phase=ph * TAU / m, sx=AH * sc, sy=AV * sc)
        feats.append((key, t, th))
    for i, (te, the) in enumerate(eyes):
        feats += bead_features(shape, "eye%d" % i, te, the, EYE, ((0.5, 6), (1.0, 8)))

    def exclude(t, th):
        m = in_ellipse(shape, t, th, tm, thm, AH, AV, 1.4) <= 1.0
        for te, the in eyes:
            m |= near3(shape, t, th, te, the, EYE * 1.42)
        return m

    body = hull_body(shape, 500, 1002, feats, exclude, jitter=0.34, low_amp=0.16, low_freq=0.34, vert_amp=0.06)
    V, F, N, G = body["verts"], body["faces"], body["normals"], body["groups"]
    for i in range(2):
        for key, d in (("_c", 0.3), ("_r0", 0.26), ("_r1", 0.07)):
            V[G["eye%d%s" % (i, key)]] += N[G["eye%d%s" % (i, key)]] * d
    eye_sets = [set(np.concatenate([G["eye%d%s" % (i, k)] for k in ("_c", "_r0", "_r1")]).tolist()) for i in range(2)]
    centres = [int(G["eye%d_c" % i][0]) for i in range(2)]
    tags = []
    for f in F:
        fs = set(f)
        tag = "skin"
        for i in range(2):
            if fs <= eye_sets[i]:
                tag = "pupil" if centres[i] in fs else "iris"
        tags.append(tag)
    region = in_ellipse(shape, body["t"], body["th"], tm, thm, AH, AV, 1.0) <= 1.002
    V, F, tags, mouth = carve_mouth(V, F, tags, region, depth=1.45, back_scale=0.68, lip=0.18)
    g.add(V, F, "Skin", tags=tags)
    for tv, tf, _ in lip_teeth(mouth, [(0.3, 0.82, 0.58), (0.7, 0.78, 0.56)], [], forward=0.12):
        g.add(tv, tf, "Skin", "tooth")
    ts, ths = surface_points(shape, 22, 1003, jitter=0.3)
    ok = (ts > 0.28) & ~near3(shape, ts, ths, tm, thm, 2.5)
    for te, the in eyes:
        ok &= ~near3(shape, ts, ths, te, the, 1.45)
    ts, ths = ts[ok], ths[ok]
    roots, nrm = body_surface(shape, ts, ths, 1002, 0.16, 0.34)
    for k in range(len(ts)):
        axis = unit(nrm[k] + rng.normal(size=3) * 0.1)
        sv, sf, bands = spike(roots[k], axis, rng.uniform(0.5, 0.62), rng.uniform(0.95, 1.3), 5,
                              [(-0.25, 1.0), (0.35, 0.72), (0.68, 0.46), (0.9, 0.22), (1.0, 0.0)],
                              phase=rng.uniform(0, TAU), jitter=0.08, rng=rng)
        g.add(sv, sf, "Horn", tags=["horn_cap" if b < 0 else ("horn_base" if b <= 1 else "horn_tip") for b in bands])
    print("  SpikedBerry: %d spikes" % len(ts))

    BASE, LIGHT, DARK = C(142, 38, 120), C(182, 62, 152), C(92, 22, 84)

    def colorize(tags, c, n, noise, verts):
        rgb = tag_rgb(tags, {"mouth_wall": C(62, 10, 30), "mouth_back": C(36, 5, 18), "tooth": C(246, 241, 226),
                             "iris": C(206, 208, 84), "pupil": C(18, 12, 10),
                             "horn_base": C(198, 142, 186), "horn_cap": C(198, 142, 186), "horn_tip": C(240, 230, 204)})
        body = mix(BASE, LIGHT, np.clip(noise, 0.0, 1.0) * 0.7)
        body = mix(body, DARK, np.clip(-noise, 0.0, 1.0) * 0.5 + 0.4 * fc.smoothstep(-0.2, -0.8, n[:, 2]))
        for i, t in enumerate(tags):
            if t in ("skin", "lip"):
                rgb[i] = body[i] * (0.9 if t == "lip" else 1.0)
        return rgb

    return finalize(g, name, colorize)


# ================================================================ TOMATO BULB
def build_tomato_bulb():
    name = "TomatoBulb"
    rng = np.random.default_rng(1201)
    g = Geo(("Skin", "Leaf"))
    shape = Revolve([(0.0, 0.35), (1.3, 0.12), (2.9, 0.4), (4.4, 1.4), (5.5, 3.0), (5.85, 4.5), (5.55, 6.0),
                     (4.6, 7.25), (3.1, 8.05), (1.6, 8.15), (0.6, 7.85), (0.0, 7.6)])
    LOBES, AMP = 7, 0.2

    def lobe(th):
        return np.abs(np.cos(0.5 * LOBES * np.asarray(th))) ** 0.4 - 0.82

    def weight(t):
        t = np.asarray(t, float)
        return np.sin(math.pi * t) ** 0.5 * (0.5 + 0.5 * fc.smoothstep(0.3, 0.85, t))

    def rmul(t, th):
        return 1.0 + AMP * lobe(th) * weight(t)

    tm, thm, AH, AV = float(shape.t_at_z(3.8)), 0.0, 2.6, 1.0
    feats = [("mouth_c", [tm], [thm])]
    for key, sc, m, ph in (("mouth_ring", 1.0, 14, 0.0), ("mouth_out", 1.26, 14, 0.5), ("mouth_in", 0.5, 6, 0.25)):
        t, th = ring_feature(shape, tm, thm, 1.0, m, phase=ph * TAU / m, sx=AH * sc, sy=AV * sc)
        feats.append((key, t, th))
    body = hull_body(shape, 590, 1202, feats, lambda t, th: in_ellipse(shape, t, th, tm, thm, AH, AV, 1.45) <= 1.0,
                     jitter=0.34, low_amp=0.08, low_freq=0.3, vert_amp=0.04, rmul_fn=rmul)
    V, F = body["verts"], body["faces"]
    region = in_ellipse(shape, body["t"], body["th"], tm, thm, AH, AV, 1.0) <= 1.002
    V, F, tags, mouth = carve_mouth(V, F, ["skin"] * len(F), region, depth=1.7, back_scale=0.7, lip=0.22)
    g.add(V, F, "Skin", tags=tags)
    for tv, tf, anchor in lip_teeth(mouth, [(0.28, 1.6, 0.68), (0.73, 1.5, 0.64)], [], forward=0.25):
        g.add(tv, tf, "Skin", "fang", part=g.part("fang", anchor=anchor))

    # leaf cap: five sepals lying on the top, tips curling up, and a stub stem
    cap = g.part("cap")
    z_pole = float(shape.at(1.0, shape.z))
    psi0 = rng.uniform(0, TAU)
    for i in range(5):
        psi = psi0 + i * TAU / 5 + rng.uniform(-0.18, 0.18)
        o = np.array([math.cos(psi), math.sin(psi), 0.0])
        K = 6
        length = rng.uniform(3.3, 3.9)
        rho = 0.2 + np.linspace(0.0, 1.0, K + 1) * length
        curl = rng.uniform(0.35, 0.7) * np.linspace(0.0, 1.0, K + 1) ** 2.2
        spine = np.stack([rho * o[0], rho * o[1], shape.z_top(rho) + 0.16 + curl], 1)
        W = rng.uniform(0.55, 0.68)
        prof = np.array([0.0, 0.8, 1.0, 0.82, 0.56, 0.28, 0.0])
        wl = W * prof * rng.uniform(0.9, 1.1, K + 1)
        wr = W * prof * rng.uniform(0.9, 1.1, K + 1)
        wl[0] = wl[-1] = wr[0] = wr[-1] = 0.0
        sv, sf, counts = spine_leaf(spine, unit(np.cross(UP, o)), wl, wr, fold=0.1, thickness=0.12)
        g.add(sv, sf, "Leaf", part=cap, tags=slab_tags(counts, ("sepal_top", "sepal_bot", "sepal_rim")))
    lean = unit(np.array([0.22, 0.1, 1.0]))
    stem = bent_spine(np.array([0.0, 0.0, z_pole - 0.2]), lean, 2.0, 3, np.array([1.0, 0.3, 0.0]), 0.35)
    sv, sf = tube(stem, [0.5, 0.34, 0.3, 0.27], 6, phase=0.3)
    g.add(sv, sf, "Leaf", "stem", part=cap)

    RED, ORANGE, DARKRED = C(204, 34, 24), C(230, 92, 34), C(158, 22, 20)

    def colorize(tags, c, n, noise, verts):
        rgb = tag_rgb(tags, {"mouth_wall": C(88, 12, 16), "mouth_back": C(52, 6, 10), "fang": C(246, 240, 224),
                             "sepal_top": C(64, 132, 40), "sepal_bot": C(96, 152, 62), "sepal_rim": C(76, 140, 50),
                             "stem": C(98, 116, 46)})
        h = verts[:, 2].max()
        zb = c[:, 2] / max(h, 1e-6)
        body = mix(RED, ORANGE, np.where(noise > 0.55, (noise - 0.55) * 1.3, 0.0))
        body = mix(body, DARKRED, 0.4 * fc.smoothstep(0.8, 0.96, zb) + 0.2 * np.clip(-noise - 0.6, 0, 1))
        body = mix(body, ORANGE, 0.3 * fc.smoothstep(0.2, 0.0, zb))
        lo2, hi2 = verts.min(axis=0), verts.max(axis=0)
        ctr = 0.5 * (lo2 + hi2)
        crest = np.abs(np.cos(0.5 * LOBES * np.arctan2(c[:, 1] - ctr[1], c[:, 0] - ctr[0])))
        body = mix(body, DARKRED, 0.75 * (1.0 - crest) ** 1.3 * fc.smoothstep(0.12, 0.5, zb))
        for i, t in enumerate(tags):
            if t in ("skin", "lip"):
                rgb[i] = body[i] * (0.9 if t == "lip" else 1.0)
            elif t == "stem" and n[i, 2] > 0.8 and zb[i] > 0.97:
                rgb[i] = C(150, 160, 92)                                       # cut end of the stub
        return rgb

    def morph(verts, vpart, parts, xf):
        body = vpart == 0
        lo, hi = verts[body].min(axis=0), verts[body].max(axis=0)
        cxy = 0.5 * (lo + hi)
        zc = lo[2] + 0.5 * (hi[2] - lo[2])

        def bxf(p):
            p = np.atleast_2d(np.asarray(p, float))
            q = p.copy()
            dx, dy = p[:, 0] - cxy[0], p[:, 1] - cxy[1]
            th = np.arctan2(dy, dx)
            rho = np.linalg.norm(p - np.array([cxy[0], cxy[1], zc]), axis=1)
            tpol = np.arccos(np.clip(-(p[:, 2] - zc) / np.maximum(rho, 1e-6), -1, 1)) / math.pi
            lw = lobe(th) * weight(tpol)
            soft = (1.0 + TOMATO_LOBE_COOKED * AMP * lw) / (1.0 + AMP * lw)        # lobes soften in the stew
            q[:, 0] = cxy[0] + dx * soft * TOMATO_SLUMP[0]
            q[:, 1] = cxy[1] + dy * soft * TOMATO_SLUMP[0]
            q[:, 2] = lo[2] + (p[:, 2] - lo[2]) * TOMATO_SLUMP[1]
            return q

        ck = verts.copy()
        ck[body] = bxf(verts[body])
        top = np.array([cxy[0], cxy[1], verts[body][:, 2].max()])
        for pid, meta in parts.items():
            m = vpart == pid
            pivot = xf(meta["anchor"]) if meta["kind"] == "fang" else top
            ck[m] = verts[m] + (bxf(pivot)[0] - pivot)
        return ck

    return finalize(g, name, colorize, morph)


# ================================================================ SCALED PINE
def build_scaled_pine():
    name = "ScaledPine"
    rng = np.random.default_rng(2001)
    g = Geo(("Skin", "Leaf"))
    shape = Revolve([(0.0, 0.0), (3.4, 0.0), (4.6, 0.8), (5.5, 2.4), (5.85, 4.6), (5.75, 7.0), (5.2, 9.2),
                     (4.2, 10.9), (3.0, 11.9), (1.6, 12.6), (0.0, 12.9)])
    barrel = hull_body(shape, 170, 2002, [], jitter=0.3, low_amp=0.08, low_freq=0.3, vert_amp=0.04)
    g.add(barrel["verts"], barrel["faces"], "Skin", "barrel")

    def S(th, z, lift):
        z = float(np.clip(z, 0.3, 12.15))
        return shape.xyz(shape.t_at_z(z), th, lift=lift)

    ROWS, COLS = 9, 11
    z0, z1 = 1.55, 11.55
    dz = (z1 - z0) / (ROWS - 1)
    hth, hz = math.pi / COLS * 1.2, dz * 1.32
    for j in range(ROWS):
        for i in range(COLS):
            thc = (i + 0.5 * (j % 2)) * TAU / COLS + 0.05 * j + rng.uniform(-0.04, 0.04)
            zc = z0 + j * dz + rng.uniform(-0.08, 0.08) * dz
            k = rng.uniform(0.85, 1.15)
            T = S(thc, zc + hz, -0.3)
            L = S(thc - hth, zc + 0.08 * hz, 0.04)
            R = S(thc + hth, zc + 0.08 * hz, 0.04)
            Cc = S(thc + rng.uniform(-0.03, 0.03), zc + 0.2 * hz, 0.38 * k)
            M = S(thc + rng.uniform(-0.03, 0.03), zc - 0.45 * hz, 0.6 * k)
            B = S(thc, zc - hz, 0.5 * k)
            v = np.array([T, L, R, Cc, M, B])
            faces = [[0, 1, 3], [0, 3, 2], [1, 4, 3], [3, 4, 2], [1, 5, 4], [4, 5, 2], [0, 2, 5, 1]]
            if signed_volume(v, faces) < 0:
                faces = [f[::-1] for f in faces]
            ripe = rng.uniform(0.0, 1.0)
            top = mix(C(84, 110, 34), C(118, 132, 40), ripe)
            midc = mix(C(116, 142, 44), C(150, 160, 50), ripe)
            tipc = mix(C(168, 182, 60), C(196, 192, 70), ripe)
            under = mix(C(44, 52, 18), top, 0.75 if j >= ROWS - 2 else 0.0)   # top rows tilt their undersides up
            g.add(v, faces, "Skin", color=np.array([top, top, midc, midc, tipc, tipc, under]),
                  tags=["scale_top", "scale_top", "scale_mid", "scale_mid", "scale_tip", "scale_tip", "scale_under"])

    # crown: three tall inner swords and six splayed outer ones
    psi0 = rng.uniform(0, TAU)
    specs = [(psi0 + i * TAU / 3 + rng.uniform(-0.3, 0.3), rng.uniform(0.08, 0.25), rng.uniform(6.2, 7.0),
              rng.uniform(2.2, 2.5), 0.3, 12.4) for i in range(3)]
    specs += [(psi0 + 0.5 + i * TAU / 6 + rng.uniform(-0.2, 0.2), rng.uniform(0.45, 0.7), rng.uniform(5.0, 6.0),
               rng.uniform(2.4, 2.8), 1.5, 11.8) for i in range(6)]
    for psi, lean, length, width, rad, z in specs:
        o = np.array([math.cos(psi), math.sin(psi), 0.0])
        P0 = np.array([rad * o[0], rad * o[1], z])
        spine = bent_spine(P0, o * math.sin(lean) + UP * math.cos(lean), length, 5, unit(o - 0.3 * UP),
                           rng.uniform(0.25, 0.45))
        bv, bf = blade(spine, unit(np.cross(UP, o)), width, 0.42)
        cen = np.array([bv[f].mean(axis=0) for f in bf])
        u = np.clip(np.linalg.norm(cen - P0, axis=1) / length, 0.0, 1.0)
        col = mix(C(64, 106, 34), C(166, 188, 60), u ** 0.8)
        g.add(bv, bf, "Leaf", "crown", color=col)

    def colorize(tags, c, n, noise, verts):
        rgb = tag_rgb(tags, {"barrel": C(50, 56, 22)}, default=C(90, 110, 36))
        crown_base = np.array([t == "barrel" for t in tags]) & (c[:, 2] > 0.56 * verts[:, 2].max())
        rgb[crown_base] = C(118, 146, 48)
        return rgb

    return finalize(g, name, colorize)


# ================================================================ HERB PILE
def build_herb_pile():
    name = "HerbPile"
    rng = np.random.default_rng(1701)
    g = Geo(("Leaf", "Stem"))

    def pile_h(x, y):
        return 2.5 * math.exp(-((x - 1.2) ** 2 / 15.0 + y ** 2 / 7.0))

    lobes = LEAFLET_HALF
    stem_col, cap_col = C(128, 172, 78), C(172, 196, 122)
    count = {"leaves": 0}

    def leaf_at(tip, xdir, R, z_floor):
        nrm = unit(UP + rng.normal(size=3) * np.array([0.32, 0.32, 0.0]))
        centre = tip + unit(xdir) * R * 0.72
        centre[2] = max(centre[2], z_floor) + rng.uniform(0.05, 0.5)
        lv, lf, counts = polar_leaf(centre, xdir, nrm, R, 18, lobes, serr=0.04, cup=0.12, fold=0.12, dome=0.12,
                                    thick=0.07, rng=rng)
        low = lv[:, 2].min()
        if low < 0.03:
            lv[:, 2] += 0.03 - low
        top = mix(C(48, 118, 32), C(86, 150, 46), rng.uniform(0, 1))
        g.add(lv, lf, "Leaf", tags=slab_tags(counts),
              color=np.array([top] * counts[0] + [mix(top, C(130, 175, 96), 0.5)] * counts[1]
                             + [top * 0.8] * counts[2]))
        count["leaves"] += 1

    for s in range(5):
        y0 = (s - 2) * 0.8 + rng.uniform(-0.25, 0.25)
        x0 = -8.2 + rng.uniform(-0.5, 0.5)
        ang = (s - 2) * 0.12 + rng.uniform(-0.08, 0.08)
        dxy = np.array([math.cos(ang), math.sin(ang), 0.0])
        perp = np.array([-dxy[1], dxy[0], 0.0])
        Ls = rng.uniform(10.5, 12.0)
        stack = rng.uniform(0.35, 1.0)
        u = np.linspace(0.0, 1.0, 7)
        radii = 0.2 * (1.0 - 0.35 * u)
        path = []
        for k in range(len(u)):
            p = np.array([x0, y0, 0.0]) + dxy * Ls * u[k] + perp * 0.35 * math.sin(u[k] * 4.0 + s)
            p[2] = radii[k] + 0.85 * stack * pile_h(p[0], p[1]) * fc.smoothstep(0.15, 0.6, u[k])
            path.append(p)
        path = np.array(path)
        sv, sf = tube(path, radii, 5, phase=rng.uniform(0, TAU))
        g.add(sv, sf, "Stem", "stem", color=np.array([cap_col if len(f) == 5 else stem_col for f in sf]))
        side = 1.0 if rng.uniform() < 0.5 else -1.0
        for ub in (0.52, 0.7, 0.86):
            side = -side
            base = np.array([np.interp(ub, u, path[:, a]) for a in range(3)])
            bdir = unit(rotate(dxy, UP, side * rng.uniform(0.4, 0.7)) + UP * 0.12)
            bl = rng.uniform(1.8, 2.8)
            bpath = np.array([base + bdir * bl * f + UP * 0.25 * f * f for f in np.linspace(0.0, 1.0, 4)])
            bv, bf = tube(bpath, np.linspace(0.12, 0.08, 4), 4, phase=rng.uniform(0, TAU))
            g.add(bv, bf, "Stem", "stem", color=stem_col)
            zf = 0.85 * stack * pile_h(bpath[-1][0], bpath[-1][1])
            leaf_at(bpath[-1], bdir, rng.uniform(1.45, 1.85), zf)
            if rng.uniform() < 0.3:
                leaf_at(bpath[2], rotate(bdir, UP, side * rng.uniform(0.7, 1.1)), rng.uniform(1.15, 1.5), zf)
        leaf_at(path[-1], unit(path[-1] - path[-2]), rng.uniform(1.8, 2.2), 0.85 * stack * pile_h(*path[-1][:2]))
    # a few leaflets that fell off onto the counter round the leafy end (the loose read of a chopped-from bunch)
    for k in range(5):
        a = -1.3 + k * 0.65 + rng.uniform(-0.2, 0.2)
        spot = np.array([3.6 + 4.2 * math.cos(a), 2.8 * math.sin(a), 0.0])
        lv, lf, counts = polar_leaf(spot, rotate(np.array([1.0, 0.0, 0.0]), UP, rng.uniform(0, TAU)),
                                    unit(UP + rng.normal(size=3) * np.array([0.12, 0.12, 0.0])), rng.uniform(1.1, 1.4),
                                    18, lobes, serr=0.04, cup=0.12, fold=0.12, dome=0.12, thick=0.07, rng=rng)
        lv[:, 2] += 0.03 - lv[:, 2].min()
        top = mix(C(48, 118, 32), C(86, 150, 46), rng.uniform(0, 1))
        g.add(lv, lf, "Leaf", tags=slab_tags(counts),
              color=np.array([top] * counts[0] + [mix(top, C(130, 175, 96), 0.5)] * counts[1]
                             + [top * 0.8] * counts[2]))
        count["leaves"] += 1
    print("  HerbPile: 5 sprigs, %d leaves" % count["leaves"])

    def colorize(tags, c, n, noise, verts):
        return tag_rgb(tags, {}, default=C(70, 140, 50))

    return finalize(g, name, colorize)


# ================================================================ MUSHROOM (whole + authored cut sections)
# One jittered lathe shared by the whole mushroom and both cuts, so the cut sections are exactly the whole one's halves:
# profile rings (r, z) in design cm, poles (0, 0) and (0, MUSH_TOP) excluded. Ring roles: 0-1 stem base, 2-6 stem,
# 7 stem / gill junction, 8-11 the pleated gill underside, 12 rim lip, 13-15 rolled rim, 16-21 the cap dome.
MUSH_RINGS = np.array([(1.15, 0.0), (1.85, 0.12), (2.1, 0.55), (2.05, 1.25), (1.95, 2.05), (1.85, 2.85), (1.82, 3.5),
                       (2.15, 3.82), (3.0, 3.98), (3.85, 4.0), (4.6, 3.92), (5.15, 3.72), (5.38, 3.42), (5.8, 3.38),
                       (6.08, 3.72), (6.12, 4.3), (5.95, 5.1), (5.5, 5.95), (4.8, 6.75), (3.85, 7.45), (2.7, 7.95),
                       (1.4, 8.25)])
MUSH_TOP = 8.35
MUSH_S = 30                    # segments round the whole ring; the cut meridians are s = 0 and s = MUSH_S / 2
MUSH_CROWN_N = 10              # the crown ring under the top pole: 30 -> 10 -> pole (no 30-spoke star on the cap)
MUSH_CROWN_RZ = (0.75, 8.32)
MUSH_JUNCTION, MUSH_RIM_LIP = 7, 12
MUSH_GILLS = range(8, 12)
MUSH_SLICE_HALF = 0.5          # the slice is |y| <= 0.5 cm about the axis plane (1 cm thick)
MUSH_SEED = 1901
MUSH_COOK = dict(shrink=0.88, sag=0.25, droop=0.55)


def mush_tilt(p):
    """The cap leans ~3 deg about Y (keeps the y = 0 cut plane in plane), weighted from the junction up."""
    p = np.array(p, float)
    a = 0.055 * fc.smoothstep(3.5, 4.8, p[..., 2])
    x, z = p[..., 0], p[..., 2] - 3.9
    p[..., 0] = x * np.cos(a) + z * np.sin(a)
    p[..., 2] = 3.9 - x * np.sin(a) + z * np.cos(a)
    return p


def mushroom_grid():
    """(rings, MUSH_S, 3) lathe vertices (design cm) + the two poles. Angular jitter is zero on the cut meridians and
    on the gill / rim rings (the gills stay radial); radial noise moves meridian points only within their plane."""
    R, n, S = MUSH_RINGS, len(MUSH_RINGS), MUSH_S
    full = np.vstack([[0.0, 0.0], R, [0.0, MUSH_TOP]])
    tg = unit(np.gradient(full, axis=0))[1:-1]
    nr, nz = tg[:, 1], -tg[:, 0]
    rng = np.random.default_rng(MUSH_SEED)
    jang = rng.uniform(-0.25, 0.25, (n, S))
    jang[MUSH_JUNCTION:MUSH_RIM_LIP + 1] = 0.0
    jang[:, [0, S // 2]] = 0.0
    jrad = rng.uniform(-0.07, 0.07, (n, S))
    th = (np.arange(S)[None, :] + jang) * TAU / S
    r = R[:, :1] + jrad
    z = np.repeat(R[:, 1:2], S, axis=1)
    for i in MUSH_GILLS:
        z[i, 1::2] += 0.16                       # radial pleats: every other gill spoke recessed up into the cap
    p0 = np.stack([r * np.cos(th), r * np.sin(th), z], -1)
    ring = np.arange(n)
    amp = np.where(ring >= 15, 0.16, np.where(ring >= 12, 0.08, np.where(ring >= MUSH_JUNCTION, 0.0, 0.08)))
    d = amp[:, None] * fc.lumps(p0.reshape(-1, 3), MUSH_SEED + 1, 0.35).reshape(n, S)
    n3 = np.stack([nr[:, None] * np.cos(th), nr[:, None] * np.sin(th), np.repeat(nz[:, None], S, 1)], -1)
    # crown ring: MUSH_CROWN_N vertices, jitter-free at j = 0 and N / 2 (the cut meridians)
    m = MUSH_CROWN_N
    cj = rng.uniform(-0.3, 0.3, m)
    cj[[0, m // 2]] = 0.0
    cth = (np.arange(m) + cj) * TAU / m
    cr = MUSH_CROWN_RZ[0] + rng.uniform(-0.08, 0.08, m)
    crown = np.stack([cr * np.cos(cth), cr * np.sin(cth), np.full(m, MUSH_CROWN_RZ[1])], -1)
    crown[:, 2] += 0.1 * fc.lumps(crown, MUSH_SEED + 1, 0.35)
    P = mush_tilt(p0 + n3 * d[..., None])
    return P, mush_tilt(np.array([[0.0, 0.0, 0.0], [0.0, 0.0, MUSH_TOP]])), mush_tilt(crown)


def mush_band_tag(b, s):
    """Paint class of the lathe band above ring b (-1 = the bottom fan, last ring = the top fan)."""
    if b <= 1:
        return "stem_base"
    if b <= 6:
        return "stem"
    if b <= 10:
        return "gill_a" if s % 2 == 0 else "gill_b"
    if b <= 14:
        return "rim"
    return "cap"


def mush_lathe(P, poles, crown, closed):
    """Lathe faces over the grid: the full ring (closed) or the half s = 0..S/2 (open at the cut plane). The last ring
    steps down to the crown ring (3 segments per crown edge) and the crown fans to the top pole.
    Returns verts, faces, tags and the cut-plane outline loop (bottom pole, right meridian up, crown 0, top pole,
    crown N/2, left meridian down)."""
    n, S, m = P.shape[0], MUSH_S, MUSH_CROWN_N
    step = S // m
    cols, ccols = (S, m) if closed else (S // 2 + 1, m // 2 + 1)
    verts = np.vstack([poles[:1], P[:, :cols].reshape(-1, 3), crown[:ccols], poles[1:]])
    c0 = 1 + n * cols
    top = c0 + ccols

    def vid(i, s):
        return 1 + i * cols + (s % cols if closed else s)

    def cid(j):
        return c0 + (j % ccols if closed else j)

    faces, tags = [], []
    for s in range(S if closed else S // 2):
        faces.append([0, vid(0, s + 1), vid(0, s)])
        tags.append(mush_band_tag(-1, s))
        for i in range(n - 1):
            faces.append([vid(i, s), vid(i, s + 1), vid(i + 1, s + 1), vid(i + 1, s)])
            tags.append(mush_band_tag(i, s))
    last = n - 1
    for j in range(m if closed else m // 2):
        r0, r1, r2, r3 = (vid(last, step * j + q) for q in range(4))
        a0, a1 = cid(j), cid(j + 1)
        faces += [[r0, r1, a0], [r1, a1, a0], [r1, r2, a1], [r2, r3, a1], [a0, a1, top]]
        tags += ["cap"] * 5
    loop = [0] + [vid(i, 0) for i in range(n)] + [cid(0), top, cid(m // 2)] \
        + [vid(i, S // 2) for i in range(n - 1, -1, -1)]
    return verts, faces, tags, loop


def point_in_poly(pts, poly):
    pts, poly = np.atleast_2d(pts), np.asarray(poly, float)
    x, y = pts[:, :1], pts[:, 1:2]
    x1, y1 = poly[None, :, 0], poly[None, :, 1]
    x2, y2 = np.roll(poly[:, 0], -1)[None], np.roll(poly[:, 1], -1)[None]
    cross = (y1 > y) != (y2 > y)
    dy = np.where(np.abs(y2 - y1) < 1e-12, 1e-12, y2 - y1)
    xi = x1 + (y - y1) * (x2 - x1) / dy
    return (np.sum(cross & (x < xi), axis=1) % 2) == 1


def seg_dist(pts, a, b):
    """Distance from points (m, 2) to the nearest of the segments a[k] -> b[k]."""
    pts = np.atleast_2d(pts)
    ab = b - a
    t = np.clip(np.einsum("mkj,kj->mk", pts[:, None, :] - a[None], ab) / np.maximum(np.sum(ab * ab, axis=1), 1e-12),
                0.0, 1.0)
    q = a[None] + t[..., None] * ab[None]
    return np.linalg.norm(pts[:, None, :] - q, axis=2).min(axis=1)


def mush_cut_face(outline, runs, stem_ids, recess, seed, spacing=0.85, band=0.62):
    """Constrained-Delaunay fill of one planar cross-section (outline (k, 2) in the (x, z) plane, wound CCW, its
    vertices kept as they are so the cap welds to the shell). Gill crescents ride the `runs` (outline indices from the
    stem junction to the rim lip): an upper constraint curve `band` cm inside, a groove of Steiner points between at
    depth `recess`; a stem-core loop inside the stem; jittered Steiner points elsewhere.
    Returns verts2d (outline first), CCW triangles, tags ("flesh" / "core" / "cutgill"), depth per vertex."""
    outline = np.asarray(outline, float)
    k = len(outline)
    extra, depth, edges, bands = [], [], [], []
    tang = unit(np.roll(outline, -1, axis=0) - np.roll(outline, 1, axis=0))
    inward = np.stack([-tang[:, 1], tang[:, 0]], 1)

    def add(pt, dep=0.0):
        extra.append(np.asarray(pt, float))
        depth.append(dep)
        return k + len(extra) - 1

    def at(i):
        return extra[i - k] if i >= k else outline[i]

    for run in runs:
        m, upper = len(run), []
        for j, oi in enumerate(run):
            if j in (0, m - 1):
                upper.append(oi)
                continue
            t = band * math.sin(math.pi * j / (m - 1)) ** 0.6
            upper.append(add(outline[oi] + inward[oi] * t))
            add(outline[oi] + inward[oi] * t * 0.5, recess)
        edges += [(upper[j], upper[j + 1]) for j in range(m - 1)]
        bands.append(np.array([outline[i] for i in run] + [at(i) for i in upper[-2:0:-1]]))
    # stem core: up the inner stem, arching into the cap centre
    sx = np.abs(outline[stem_ids, 0])
    sz = outline[stem_ids, 1]
    order = np.argsort(sz)
    zs = np.array([0.5, 1.3, 2.1, 2.9, 3.5])
    w = 0.55 * np.interp(zs, sz[order], sx[order])
    core = [(c, zz) for c, zz in zip(w, zs)] + [(0.42, 4.1), (0.0, 4.35), (-0.42, 4.1)] \
        + [(-c, zz) for c, zz in zip(w[::-1], zs[::-1])] + [(0.0, 0.42)]
    core_ids = [add(pt) for pt in core]
    edges += [(core_ids[j], core_ids[(j + 1) % len(core_ids)]) for j in range(len(core_ids))]
    core = np.array(core)
    # Steiner points away from every boundary and constraint
    rng = np.random.default_rng(seed)
    lo, hi = outline.min(axis=0), outline.max(axis=0)
    gx, gz = np.meshgrid(np.arange(lo[0] + spacing * 0.5, hi[0], spacing), np.arange(lo[1] + spacing * 0.5, hi[1], spacing))
    G = np.stack([gx.ravel(), gz.ravel()], 1) + rng.uniform(-0.28, 0.28, (gx.size, 2)) * spacing
    keep = point_in_poly(G, outline) & (seg_dist(G, outline, np.roll(outline, -1, axis=0)) > 0.42)
    for bp in bands:
        keep &= ~point_in_poly(G, bp) & (seg_dist(G, bp, np.roll(bp, -1, axis=0)) > 0.32)
    keep &= seg_dist(G, core, np.roll(core, -1, axis=0)) > 0.32
    for pt in G[keep]:
        add(pt)
    pts = np.vstack([outline, np.array(extra)])
    out_v, _, out_f, orig_v, _, _ = delaunay_2d_cdt([Vector(q) for q in pts], edges, [list(range(k))], 1, 1e-7, True)
    remap, new = [], []
    for j, ov in enumerate(orig_v):
        if ov:
            remap.append(ov[0])
        else:
            remap.append(len(pts) + len(new))
            new.append(np.array(out_v[j][:]))
    if new:
        pts = np.vstack([pts, np.array(new)])
        depth += [0.0] * len(new)
        print("  cut face: %d vertices added by constraint crossings" % len(new))
    tris = [[remap[i] for i in f] for f in out_f]
    cen = pts[np.array(tris)].mean(axis=1)
    tags = np.full(len(tris), "flesh", dtype=object)
    tags[point_in_poly(cen, core)] = "core"
    for bp in bands:
        tags[point_in_poly(cen, bp)] = "cutgill"
    return pts, tris, list(tags), np.concatenate([np.zeros(k), np.array(depth)])


MUSH_COLORS = {"stem_base": C(198, 184, 158), "stem": C(225, 215, 195), "gill_a": C(150, 105, 95),
               "gill_b": C(126, 86, 78), "rim": C(204, 170, 126), "flesh": C(235, 222, 200), "core": C(244, 236, 220),
               "cutgill": C(142, 98, 88)}
MUSH_CAP, MUSH_CROWN = C(190, 150, 105), C(120, 85, 55)
MUSH_CUT_VALUE = {"flesh": 1.0, "core": 1.0, "cutgill": 0.7}


def mush_colors(tags, verts_build, tris, seed):
    """Per-face paint in the standing build frame (shared by the whole mushroom and its cuts)."""
    c, n, _ = face_geo(verts_build, np.asarray(tris))
    noise = np.random.default_rng(seed).uniform(-1.0, 1.0, len(tris))
    rgb = tag_rgb(tags, MUSH_COLORS, default=MUSH_CAP)
    top = verts_build[:, 2].max()
    for i, t in enumerate(tags):
        if t == "cap":
            crown = fc.smoothstep(0.7, 0.97, c[i, 2] / top)
            col = mix(MUSH_CAP, MUSH_CROWN, crown)
            rgb[i] = mix(col, C(204, 166, 116), 0.35 * max(noise[i], 0.0)) * (1.0 - 0.06 * max(-noise[i], 0.0))
        elif t == "rim":
            rgb[i] = MUSH_COLORS["rim"] * (1.0 + 0.04 * noise[i])
        elif t == "stem":
            rgb[i] = mix(MUSH_COLORS["stem"], MUSH_COLORS["stem_base"], 0.25 * max(noise[i], 0.0))
    return rgb


def build_mushroom():
    name = "Mushroom"
    P, poles, crown = mushroom_grid()
    n, S = len(MUSH_RINGS), MUSH_S
    slots = ("Skin", "Flesh")
    stem_rows = list(range(1, MUSH_JUNCTION + 2))                  # outline rows of the stem on the right meridian

    def runs_for(loop_len):
        right = [1 + i for i in range(MUSH_JUNCTION, MUSH_RIM_LIP + 1)]
        left = [n + 4 + (n - 1 - i) for i in range(MUSH_JUNCTION, MUSH_RIM_LIP + 1)]
        return [right, left]

    # whole: the closed lathe; its scale fixes the size of all three meshes
    wv, wf, wtags, _ = mush_lathe(P, poles, crown, closed=True)
    wv, wf = wv, orient_outward(wv, wf)
    lo, hi = wv.min(axis=0), wv.max(axis=0)
    scale = spec.INGREDIENTS[name]["size_cm"] / float((hi - lo).max())

    def pack(stage, verts_build, faces, tags, cut_tags=None, rest=None, cooked_fn=None, rest_pose=None):
        tris, src = triangulate(verts_build, faces)
        ftags = [tags[i] for i in src]
        rgb = mush_colors(ftags, verts_build * scale, tris, seed_of(name + str(stage)))
        v = verts_build * scale
        if rest is not None:
            v = rest(v)
        lo2, hi2 = v.min(axis=0), v.max(axis=0)
        v = v - np.array([(lo2[0] + hi2[0]) * 0.5, (lo2[1] + hi2[1]) * 0.5, lo2[2]])
        fslot = [1 if t in MUSH_CUT_VALUE else 0 for t in ftags]
        cut = [MUSH_CUT_VALUE.get(t, 0.0) for t in ftags] if cut_tags else None
        return dict(stage=stage, verts=v, tris=tris, fslot=fslot, rgb=rgb, tags=ftags, slots=slots,
                    cooked=cooked_fn(v) if cooked_fn else None, cut=cut, scale=scale,
                    rest_pose=rest_pose or "standing on its stem, centred XY, base z = 0")

    def cooked(v):
        lo3, hi3 = v.min(axis=0), v.max(axis=0)
        cxy = 0.5 * (lo3 + hi3)
        q = v.copy()
        q[:, :2] = cxy[:2] + MUSH_COOK["shrink"] * (q[:, :2] - cxy[:2])
        q[:, 2] = lo3[2] + MUSH_COOK["shrink"] * (q[:, 2] - lo3[2])
        zj = lo3[2] + MUSH_COOK["shrink"] * MUSH_RINGS[MUSH_JUNCTION, 1] * scale
        w = fc.smoothstep(zj - 0.35, zj + 0.6, q[:, 2])
        rr = np.hypot(q[:, 0] - cxy[0], q[:, 1] - cxy[1])
        q[:, 2] -= w * (MUSH_COOK["sag"] + MUSH_COOK["droop"] * (rr / rr.max()) ** 2)
        return q

    whole = pack(None, wv, wf, wtags, cooked_fn=cooked)

    # half: the open half lathe (y >= 0) + the planar cut face in y = 0, lying on the cut face, stem toward +X
    hv, hf, htags, loop = mush_lathe(P, poles, crown, closed=False)
    outline = hv[loop][:, [0, 2]]
    pts, tris, ctags, dep = mush_cut_face(outline, runs_for(len(loop)), stem_rows, recess=0.15, seed=1902)
    ids = list(loop) + list(range(len(hv), len(hv) + len(pts) - len(loop)))
    extra3 = np.stack([pts[len(loop):, 0], dep[len(loop):], pts[len(loop):, 1]], 1)
    hv2 = np.vstack([hv, extra3])
    hfaces = list(hf) + [[ids[a], ids[b], ids[c]] for a, b, c in tris]      # CCW in (x, z) = normal -y: outward
    hfaces = orient_outward(hv2, hfaces)

    def lie(v):                                    # (x, y, z)build -> lying on the y = 0 cut face, stem toward +X
        return np.stack([-v[:, 2], -v[:, 0], v[:, 1]], 1)

    half = pack("Half", hv2, hfaces, list(htags) + ctags, cut_tags=True, rest=lie,
                rest_pose="lying on its flat cut face (z = 0), cap dome up, stem toward +X, centred XY")

    # slice: |y| <= 0.5 about the axis plane; rim = three layers of the cross-section outline, faces = two cut caps
    L0 = hv[loop]
    xs = np.sign(L0[:, 0]) * np.sqrt(np.maximum(L0[:, 0] ** 2 - MUSH_SLICE_HALF ** 2, 0.0))
    K = len(loop)
    layers = []
    for y in (-MUSH_SLICE_HALF, 0.0, MUSH_SLICE_HALF):
        Lk = L0.copy()
        if y:
            Lk[:, 0], Lk[:, 1] = xs, y
        layers.append(Lk)
    sv = np.vstack(layers)
    sfaces, stags = [], []
    ring_of = [-1] + list(range(n)) + [n, n + 1, n] + list(range(n - 1, -1, -1))
    for band_i in range(2):
        a0, b0 = band_i * K, (band_i + 1) * K
        for kk in range(K):
            k2 = (kk + 1) % K
            sfaces.append([a0 + k2, a0 + kk, b0 + kk, b0 + k2])      # opposite to the caps' boundary run
            rb = min(ring_of[kk], ring_of[k2])
            stags.append(mush_band_tag(min(rb, n - 1), S // 2 if kk > n + 3 else 0))
    for li, y, sign in ((0, -MUSH_SLICE_HALF, 1.0), (2, MUSH_SLICE_HALF, -1.0)):
        base = li * K
        o2 = layers[li][:, [0, 2]]
        pts, tris, ctags, dep = mush_cut_face(o2, runs_for(K), stem_rows, recess=0.12, seed=1903 + li)
        start = len(sv)
        sv = np.vstack([sv, np.stack([pts[K:, 0], y + sign * dep[K:], pts[K:, 1]], 1)])
        ids = [base + j for j in range(K)] + list(range(start, start + len(pts) - K))
        for a, b, c in tris:
            sfaces.append([ids[a], ids[b], ids[c]] if sign > 0 else [ids[a], ids[c], ids[b]])
        stags += ctags
    sfaces = orient_outward(sv, sfaces)

    def lie_slice(v):
        return np.stack([-v[:, 2], -v[:, 0], v[:, 1] + MUSH_SLICE_HALF * scale], 1)

    slc = pack("Slice", sv, sfaces, stags, cut_tags=True, rest=lie_slice,
               rest_pose="lying flat on one cut face (z 0..1 cm), stem toward +X, centred XY")
    return [whole, half, slc]


BUILDERS = {"Puffer": build_puffer, "Turnip": build_turnip, "SpikedBerry": build_spiked_berry,
            "TomatoBulb": build_tomato_bulb, "ScaledPine": build_scaled_pine, "HerbPile": build_herb_pile,
            "Mushroom": build_mushroom}


# ---------------------------------------------------------------- verification helpers
def manifold_report(obj):
    """Closed-manifold check for the runtime slicer: every edge has exactly two faces, consistent winding, no loose
    geometry, and every connected component encloses a positive volume."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    boundary = sum(1 for e in bm.edges if e.is_boundary)
    nonman = sum(1 for e in bm.edges if not e.is_manifold)
    noncontig = sum(1 for e in bm.edges if not e.is_contiguous)
    loose_v = sum(1 for v in bm.verts if not v.link_faces)
    bm.verts.index_update()
    parent = list(range(len(bm.verts)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for e in bm.edges:
        a, b = find(e.verts[0].index), find(e.verts[1].index)
        if a != b:
            parent[a] = b
    comp_faces = {}
    for f in bm.faces:
        comp_faces.setdefault(find(f.verts[0].index), []).append([v.index for v in f.verts])
    co = np.array([v.co[:] for v in bm.verts]) * 100.0
    vols = [signed_volume(co, fs) for fs in comp_faces.values()]
    bm.free()
    rep = dict(components=len(comp_faces), boundary_edges=boundary, nonmanifold_edges=nonman,
               inconsistent_winding_edges=noncontig, loose_verts=loose_v,
               negative_volume_components=int(sum(1 for v in vols if v <= 0.0)), min_volume_cm3=round(float(min(vols)), 4))
    rep["ok"] = (boundary == 0 and nonman == 0 and noncontig == 0 and loose_v == 0
                 and rep["negative_volume_components"] == 0)
    return rep


# view name -> (camera direction from the target, layout axis for side-by-side objects)
REVIEW_VIEWS = {"iso": ((1.0, -1.0, 0.75), (1.0, 0.0, 0.0)), "face": ((1.0, 0.0, 0.15), (0.0, 1.0, 0.0)),
                "front": ((0.0, -1.0, 0.12), (1.0, 0.0, 0.0)), "top": ((0.0, -0.001, 1.0), (1.0, 0.0, 0.0)),
                "under": ((0.0, -0.001, 1.0), (1.0, 0.0, 0.0), (math.pi, 0.0, 0.0))}   # meshes flipped: undersides up


def render_review(objs, stem, views=("iso", "face", "front", "top"), size=(1800, 700)):
    """Workbench (vertex colour, studio light, cavity) orthographic renders framed on the objects' real bounds; objs
    laid out side by side across the view (raw left). Tiled to REVIEW_DIR/<stem>_sheet.png, one row per view."""
    fc.ensure_dirs()
    scene = bpy.context.scene
    others = [o for o in scene.objects if o not in objs and o.type == "MESH"]
    saved = [(o.location.copy(), o.hide_render) for o in objs]
    other_state = [o.hide_render for o in others]
    cam_data = bpy.data.cameras.new("_ProduceReviewCam")
    cam_data.type = "ORTHO"
    cam_data.clip_start, cam_data.clip_end = 0.001, 100.0
    cam = bpy.data.objects.new("_ProduceReviewCam", cam_data)
    scene.collection.objects.link(cam)
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.resolution_percentage, scene.render.filepath, scene.display.shading.color_type,
            scene.display.shading.light, scene.display.shading.show_cavity, scene.render.film_transparent)
    local = [fc.verts_cm(o) * 0.01 for o in objs]
    extent = max(float(np.ptp(v, axis=0).max()) for v in local)
    paths = []
    try:
        for o in others:
            o.hide_render = True
        for o in objs:
            o.hide_render = False
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "VERTEX"
        scene.display.shading.show_cavity = True
        scene.render.film_transparent = False
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        aspect = size[0] / size[1]
        for view in views:
            entry = REVIEW_VIEWS[view]
            d, lay = unit(np.array(entry[0], float)), np.array(entry[1], float)
            rot = entry[2] if len(entry) > 2 else (0.0, 0.0, 0.0)
            rmat = np.array(Euler(rot).to_matrix())
            world = []
            for i, (o, v) in enumerate(zip(objs, local)):
                off = lay * (i - (len(objs) - 1) * 0.5) * extent * 1.3
                o.location = tuple(off)
                o.rotation_euler = rot
                world.append(v @ rmat.T + off)
            world = np.concatenate(world)
            fwd = -d
            right = unit(np.cross(fwd, UP)) if abs(fwd[2]) < 0.99 else np.array([1.0, 0.0, 0.0])
            up = np.cross(right, fwd)
            pr, pu = world @ right, world @ up
            w, h = np.ptp(pr), np.ptp(pu)
            centre = right * (pr.min() + pr.max()) * 0.5 + up * (pu.min() + pu.max()) * 0.5 \
                + fwd * float(np.mean(world @ fwd))
            cam_data.ortho_scale = max(w, h * aspect) * 1.12
            eye = centre - fwd * 2.0
            cam.location = tuple(eye)
            cam.rotation_euler = (math.atan2(math.hypot(fwd[0], fwd[1]), -fwd[2]), 0.0, -math.atan2(fwd[0], fwd[1]))
            path = os.path.join(spec.REVIEW_DIR, "%s_%s.png" % (stem, view))
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            paths.append(path)
    finally:
        for o, (loc, hr) in zip(objs, saved):
            o.location, o.hide_render = loc, hr
            o.rotation_euler = (0.0, 0.0, 0.0)
        for o, hr in zip(others, other_state):
            o.hide_render = hr
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
         scene.render.resolution_percentage, scene.render.filepath, scene.display.shading.color_type,
         scene.display.shading.light, scene.display.shading.show_cavity, scene.render.film_transparent) = prev
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    sheet = fc.tile_images(paths, os.path.join(spec.REVIEW_DIR, "%s_sheet.png" % stem), cols=1)
    for p in paths:
        os.remove(p)
    return sheet


def make_sheet(obj, name, cooked=None):
    """<Name>_sheet.png: iso, face-on (+X to the camera), front, top; raw left, cooked right."""
    objs, ghost = [obj], None
    if cooked is not None:
        ghost = obj.copy()
        ghost.data = obj.data.copy()
        ghost.name = name + "_CookedPreview"
        bpy.context.scene.collection.objects.link(ghost)
        fc.set_verts_cm(ghost, cooked)
        objs.append(ghost)
    try:
        return render_review(objs, name)
    finally:
        if ghost is not None:
            mesh = ghost.data
            bpy.data.objects.remove(ghost)
            bpy.data.meshes.remove(mesh)


def realize(name, d, args):
    t0 = time.time()
    stage = d.get("stage")
    label = name + ("_" + stage if stage else "")
    obj = fc.new_object(spec.mesh_name(name, stage), d["verts"], d["tris"], slots=d["slots"], face_slots=d["fslot"])
    if len(obj.data.polygons) != len(d["tris"]):
        raise RuntimeError("%s: mesh.validate changed the face count %d -> %d" % (
            label, len(d["tris"]), len(obj.data.polygons)))
    tris = np.array([pl.vertices[:] for pl in obj.data.polygons], np.int64)   # new_object may re-wind shells outward
    before = d["verts"]
    raw = fc.rest_on_floor(obj)
    shift = (raw - before).mean(axis=0)
    cooked = None if d["cooked"] is None else d["cooked"] + shift
    size = spec.INGREDIENTS[name]["size_cm"]
    ao = vertex_ao(raw, tris, dist=0.3 * size)
    cav = fc.cavity(obj)
    alpha = np.clip(ao * (1.0 - 0.5 * np.clip((0.5 - cav) * 2.0, 0.0, 1.0)), 0.0, 1.0)
    fc.paint(obj, d["rgb"], alpha=alpha, variation=0.05, seed=seed_of(name) % 10007, cavity_darken=0.35)
    fc.smart_uv(obj)
    if cooked is not None:
        fc.write_morph_uvs(obj, raw, cooked)
    obj["builder"] = "build_food_produce.py"
    obj["category"] = CATEGORY
    obj["size_spec_cm"] = size
    if stage:
        obj["stage"] = stage
    rep = dict(name=label, obj=obj.name, tris=fc.tri_count(obj), slots=[m.name for m in obj.data.materials],
               uv_layers=[u.name for u in obj.data.uv_layers], col=spec.COLOR_ATTR in obj.data.color_attributes,
               flat=fc._is_flat(obj.data), morph_max_cm=float(obj.get("morph_max_cm", 0.0)),
               size_cm=float(np.ptp(raw, axis=0).max()), size_ok=fc.check_against_spec(obj, name),
               cooked_min_z=None if cooked is None else float(cooked[:, 2].min()))
    lo, hi = TRI_BUDGET.get(label, TRI_BUDGET[name])
    rep["tris_ok"] = lo <= rep["tris"] <= hi
    want_uv = ["UVMap"] + (list(spec.MORPH_UV) if spec.INGREDIENTS[name]["morph"] and not stage else [])
    rep["uv_ok"] = rep["uv_layers"] == want_uv
    if name == "HerbPile":
        ext = np.ptp(raw, axis=0)
        rep["along_x_ok"] = bool(ext[0] >= ext[1])           # spec: long items lie along +X
        print("HerbPile extents x %.2f y %.2f z %.2f cm" % tuple(ext))
    if name in MANIFOLD_KEYS:
        rep["manifold"] = manifold_report(obj)
        print("MANIFOLD %s %s" % (label, json.dumps(rep["manifold"])))
    if args["export"]:
        # every asset sits at the origin (spec), so the others must leave the bake scene or they occlude the AO
        others = [o for o in bpy.context.scene.objects if o is not obj and o.type == "MESH"]
        hidden = [o.hide_render for o in others]
        scene = bpy.context.scene
        if scene.world is None:
            scene.world = bpy.data.worlds.new("World")
        ao_dist = scene.world.light_settings.distance
        try:
            for o in others:
                o.hide_render = True
            scene.world.light_settings.distance = 0.3 * size * 0.01       # local AO: crevices, not the far side
            conv = vertex_convexity(raw, tris)
            conv_img = bake_vertex_scalar(obj, conv, spec.MASK_SIZE)
            cut_img = None
            if d.get("cut") is not None:
                cut_img = bake_vertex_scalar(obj, np.repeat(np.asarray(d["cut"], float), 3), spec.MASK_SIZE, "CORNER")
            lo3, hi3 = raw.min(axis=0), raw.max(axis=0)
            center = 0.5 * (lo3 + hi3)
            mask_path, _ = fc.bake_masks(obj, make_masks(conv_img, center, hi3[2], seed_of(label) % 997,
                                                         neutral=(name == "HerbPile"), cut_img=cut_img))
        finally:
            scene.world.light_settings.distance = ao_dist
            for o, h in zip(others, hidden):
                o.hide_render = h
        rep["mask"] = mask_path
        extra = {"ref": spec.INGREDIENTS[name]["ref"],
                 "rest_pose": d.get("rest_pose", "centred XY, lowest point z = 0, face / business end toward +X")}
        if "manifold" in rep:
            extra["manifold"] = rep["manifold"]
        rep["fbx"] = fc.export_fbx(obj, extra=extra)
    if args["sheets"] and not stage:
        rep["sheet"] = make_sheet(obj, name, cooked)
    rep["seconds"] = round(time.time() - t0, 1)
    return rep


def reimport_all(paths):
    out = {}
    for p in paths:
        r = subprocess.run([bpy.app.binary_path, "-b", "--factory-startup", "--python", os.path.abspath(__file__),
                            "--", "--reimport", p], capture_output=True, text=True, timeout=600)
        line = [ln for ln in r.stdout.splitlines() if ln.startswith("REIMPORT_JSON ")]
        out[p] = json.loads(line[-1][len("REIMPORT_JSON "):]) if line else [{"error": (r.stdout + r.stderr)[-1500:]}]
    return out


def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False, "only": "", "reimport": ""})
    if args["reimport"]:
        fc.clear_scene()
        print("REIMPORT_JSON " + json.dumps(fc.reimport_check(args["reimport"])))
        return
    names = ROSTER if not args["only"] else [n.strip() for n in str(args["only"]).split(",") if n.strip()]
    for n in names:
        if n not in BUILDERS:
            raise SystemExit("unknown produce ingredient %r (roster %s)" % (n, ROSTER))
    fc.ensure_dirs()
    fc.clear_scene()
    reports = []
    extra_sheets = []
    for n in names:
        print("== %s" % n)
        res = BUILDERS[n]()
        for d in (res if isinstance(res, list) else [res]):
            reports.append(realize(n, d, args))
        if n == "Mushroom" and args["sheets"]:
            objs = [bpy.data.objects[spec.mesh_name("Mushroom", st)] for st in (None,) + tuple(spec.INGREDIENTS[n]["cuts"])]
            extra_sheets.append(render_review(objs, "Mushroom_Cuts", views=("iso", "top", "under", "front")))
    problems = []
    if args["export"]:
        rr = reimport_all([r["fbx"] for r in reports])
        for r in reports:
            rep = rr[r["fbx"]]
            r["reimport"] = rep
            print("REIMPORT %s %s" % (os.path.basename(r["fbx"]), json.dumps(rep)))
            ok = (len(rep) == 1 and "error" not in rep[0] and rep[0]["tris"] == r["tris"]
                  and rep[0]["uv_layers"] == r["uv_layers"] and spec.COLOR_ATTR in rep[0]["colors"]
                  and rep[0]["flat"] and abs(rep[0]["size_cm"] - r["size_cm"]) < 0.05)
            if not ok:
                problems.append("%s reimport mismatch" % r["name"])
    print("\n%-12s %5s %6s %-10s %-24s %-5s %-5s %6s %s" % ("asset", "tris", "size", "slots", "uv", "col", "flat",
                                                           "morph", "checks"))
    for r in reports:
        checks = [k for k in ("size_ok", "tris_ok", "uv_ok", "col", "flat") if not r[k]]
        if "manifold" in r and not r["manifold"]["ok"]:
            checks.append("manifold")
        if r["name"] == "HerbPile" and not r["along_x_ok"]:
            checks.append("not_along_x")
        if r["cooked_min_z"] is not None and abs(r["cooked_min_z"]) > 0.05:
            checks.append("cooked_off_floor(%.2f)" % r["cooked_min_z"])
        problems += ["%s %s" % (r["name"], c) for c in checks]
        print("%-12s %5d %6.2f %-10s %-24s %-5s %-5s %6.2f %s  (%.1fs)" % (
            r["name"], r["tris"], r["size_cm"], "+".join(r["slots"]), ",".join(r["uv_layers"]), r["col"], r["flat"],
            r["morph_max_cm"], "ok" if not checks else "FAIL " + ",".join(checks), r["seconds"]))
        for k in ("mask", "sheet"):
            if k in r:
                print("    %s %s" % (k, r[k]))
    for sh in extra_sheets:
        print("    sheet %s" % sh)
    if args["save"]:
        bpy.context.preferences.filepaths.save_version = 0          # no Food_Produce.blend1 next to it
        fc.save_blend(BLEND_PATH)
        print("saved %s" % BLEND_PATH)
    print("FOOD_PRODUCE_FAIL " + "; ".join(problems) if problems else "FOOD_PRODUCE_OK")


if __name__ == "__main__":
    main()
