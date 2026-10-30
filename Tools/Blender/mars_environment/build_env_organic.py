"""Mars environment dressing, family "organic" (ENV_KIT.md): dead-leaf piles and a leaf drift, moss pads, a moss drape
over a 90 degree ledge edge and a red mushroom cluster, rebuilt from fixed seeds in headless Blender 5.2.
Revised 2026-10-20 (flat readable leaves, clumped drape, crusty pads, hand-cut caps) and 2026-10-24 after the second
art-direction review (heart-shaped five-lobed ivy, curled leaves, a coherent rust-umber heap, wispy drape strands with
yellow-olive tips, scalloped moss cushions, nested mushroom caps, caps on EnvCanvas).

  DeadLeaves_Pile_A_Mars_SM
    EnvLeafDry      wall-base drift ~105 x 55 x 22: a crumpled duff core (painted as deep litter, its floor ring at
    0.9 of the heap outline) under ~250 dry ivy leaves dropped one by one onto the exact geometry below (each rests
    >= 3 mm above it): a low skirt, coverage-guided fill, a toe band, leaves leaning on the wall, top and fine litter,
    spill, then patches wherever the core still shows from 25 deg (five azimuths) or from the top. No leaf reaches more
    than 5 cm past the heap outline or hangs over the floor. Back at y = 0.
  DeadLeaves_Pile_B_Mars_SM
    EnvLeafDry      smaller lopsided drift ~80 x 43 x 18
  DeadLeaves_Scatter_A_Mars_SM
    EnvLeafDry      floor drift ~105 x 70 x 3: three uneven sub-drifts along one long side (8-15 cm gaps), a trail
    thinning out across the -x half, single leaves through the centre
  MossPad_A_Mars_SM
    EnvMoss         moss cushion ~60 x 44 x 4.6: 7-10 rounded scallops, a 1.3 cm rounded bevel ring inside the
    0.3-0.5 cm rim, five flat-topped hummocks (two facet rings each, 3.7-4.6 cm)
  MossPad_B_Mars_SM
    EnvMoss         step / ledge-edge strip ~48 x 17: lies on the tread and droops down the riser unevenly (3 cm at
    one end, 10 cm at the other) with three blunt 4-6 cm tongues; edge pivot like MossDrape_A (tread z 0 for y > 0,
    riser y 0 for z < 0)
  MossDrape_A_Mars_SM
    EnvMoss         a mat over a 90 degree ledge edge along X (edge at y = 0, z = 0) ending in a continuous face lip;
    45-60 thin triangular strands (1.0-1.5 cm at the root, 0.2-0.3 cm points) in 5-6 clumps of 2-3 tufts, each tuft
    one 35-60 cm leader and 8-20 cm followers, rooted flush inside the lip; dark at the root, moss green, yellow-olive
    over the last quarter
  Mushroom_Cluster_A
    EnvCanvas / EnvMoss / EnvBark   seven red caps (open, convex, chipped, egg, button) with flat wart plates, bulbed
    S-curved stems (cream to grey-ochre), a soft drooping skirt annulus on the tallest, cream gills, on a moss mound
    crossed by a faceted twisted root. Caps, gills, stems and warts share EnvCanvas: the red lives in Col.

Leaves: 4 / 6 / 10 triangle fans (5-7 cm kite filler <= 5 % and buried, three-lobed, five-lobed heart-based ivy) with a
shallow V-fold along the midrib, or (20 %) both side lobes curled up 15-25 deg, a slight tip lift, the fan centre on the
midrib. Every leaf face winds toward its visible side. UV1 "EnvData" on the leaf meshes: u = per-leaf random id, v = 0
(the core shares one id); on the drape u = strand id, v = flex 0 at the ledge -> 1 at the strand tip; on the pads u =
hummock id, v = 0; on the mushroom cluster u = per-mushroom id, v = 0.

Run (always absolute paths):
  "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup --python
      D:\\Repo\\Mars\\Tools\\Blender\\mars_environment\\build_env_organic.py -- [--export] [--sheets] [--save] [--only <part>]
Prints ENV_ORGANIC_OK when every check passed (ENV_ORGANIC_FAIL + the reasons otherwise; ENV_ORGANIC_PARTIAL with --only).

Frames: centimetres, Blender axes (Z up); sidecars give Unreal local cm (Y mirrored).
"""
import json
import math
import os
import sys
import time

import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import env_common as ec          # noqa: E402
import candle_gen as cg          # noqa: E402  (importable helper: surface nets, decimate, smooth min)

spec, fc, sc = ec.spec, ec.fc, ec.sc
FAMILY = "organic"
FAMILY_SLOTS = ("EnvLeafDry", "EnvMoss", "EnvBark", "EnvCanvas")      # ENV_KIT.md's organic slot list
CAP_SLOT = "EnvCanvas"             # the mushroom caps: red is painted into Col on the EnvPaint master (a dedicated
                                   # EnvFungus slot would need an env_spec change; see the builder report)
REVIEW_BG = (0.21, 0.215, 0.23)
TAU = math.tau

# name -> category (env_spec.TRIS), pivot kind, intended size (x, y, z cm), slots, data uv, closed solid; edge pieces
# carry `pen`, how far they sink into the stone (cm)
MESHES = {
    "DeadLeaves_Pile_A": dict(cat="cluster", pivot="wall", size=(125, 62, 23), slots=("EnvLeafDry",), data_uv=True,
                              closed=False),
    "DeadLeaves_Pile_B": dict(cat="cluster", pivot="wall", size=(98, 52, 17), slots=("EnvLeafDry",), data_uv=True,
                              closed=False),
    "DeadLeaves_Scatter_A": dict(cat="scatter", pivot="floor", size=(112, 84, 3), slots=("EnvLeafDry",), data_uv=True,
                                 closed=False),
    "MossPad_A": dict(cat="scatter", pivot="floor", size=(64, 46, 5), slots=("EnvMoss",), data_uv=True, closed=True),
    "MossPad_B": dict(cat="scatter", pivot="edge", pen=0.0, size=(48, 16, 16.5), slots=("EnvMoss",), data_uv=True,
                      closed=True),
    "MossDrape_A": dict(cat="cluster", pivot="edge", pen=0.3, size=(104, 19, 66), slots=("EnvMoss",), data_uv=True,
                        closed=True),
    "Mushroom_Cluster_A": dict(cat="cluster", pivot="floor", size=(52, 36, 27),
                               slots=("EnvCanvas", "EnvMoss", "EnvBark"), data_uv=True, closed=True),
}
ORDER = tuple(MESHES)
SIZE_TOL = 0.22

# ---------------------------------------------------------------- leaves
# outline points (x along the midrib 0 notch side .. 1 tip, y lateral; half width 0.5), counter-clockwise from the tip.
# 8: five-lobed ivy (terminal lobe, two lateral lobes, two basal lobes; the notches pulled in toward the midrib so the
# lobes read), 6: three-lobed, 4: a small kite used only as 5-7 cm filler.
LEAF_TEMPLATES = {
    # 10: five-lobed ivy as a 10-point fan: a dominant terminal lobe, the notch beside it, the lateral lobe, a second
    # notch between the lateral and basal lobes, a small basal lobe swept back and a stem notch (a heart). The arms are
    # deliberately unequal (terminal 0.58, lateral 0.42, basal 0.44 from the fan centre, notches 0.27 / 0.33): with the
    # review's equal-arm points (0.62/0.12, 0.50/0.50, 0.30/0.22, 0.04/0.36) every leaf rendered as a five-point star.
    10: np.array([[1.00, 0.00], [0.60, 0.20], [0.48, 0.42], [0.28, 0.30], [0.08, 0.28], [0.20, 0.00],
                  [0.08, -0.28], [0.28, -0.30], [0.48, -0.42], [0.60, -0.20]]),
    # 6: three-lobed: the side notch at ~0.36 of the half width, broad lateral lobes, a blunt base
    6: np.array([[1.00, 0.00], [0.62, 0.18], [0.40, 0.46], [0.12, 0.00], [0.40, -0.46], [0.62, -0.18]]),
    4: np.array([[1.00, 0.00], [0.42, 0.42], [0.10, 0.00], [0.42, -0.42]]),
}
LEAF5 = 10                         # the five-lobed kind (its triangle count)
KITE_MAX_FRAC = 0.05               # 4-tri kites: at most this share of a pile, only in the buried fill layer
CURL_P = 0.2                       # this share of the leaves curl both side lobes up instead of V-folding
CURL_DEG = (15.0, 25.0)            # lobe-tip lift of a curled leaf
CURL_CENTRE_TOL = 0.12             # a curled leaf's centre may sit this far (x length) under its rim plane
CORE_SCALE = 0.9                   # the duff core's floor ring sits at this fraction of the heap outline, so the
                                   # skirt and toe leaves hide its toe without reaching far past the outline
SPILL_OUT_CM = 5.0                 # spill / loose / skirt leaves reach at most this far past the heap outline
LEAF_CENTRE = 0.42                 # the fan centre on the midrib
LEAF_C = 0.3                       # a leaf rests this far (vertically) above whatever is under it (>= 2 mm normal)
SAMPLE_CM = 0.3                    # triangle sampling for rest / splat
CELL_CM = 0.6                      # height field cell
LEAF_FOLD = (6.0, 15.0)            # V-fold along the midrib: each half tilted this many degrees
LEAF_CENTRE_TOL = 0.06             # the fan centre stays within this x length of the rim's least-squares plane
LEAF_PROJ_MIN = 0.85               # projected (seen from the leaf normal) area >= this x the true area
KITE_LEN = (5.0, 7.0)              # 4-tri kites are small filler only
COVER_VIEWS = tuple((az, 25.0) for az in (-160.0, -128.0, -90.0, -52.0, -20.0)) + ((-90.0, 89.0),)

# view_uncovered: the share of core facets a 25 deg ray escapes from. 0.14 with the old convex kite / diamond leaves; the
# heart-based star outline's notches and the curled leaves' lifted lobes let more grazing rays out between leaves, so
# the cap is 0.18 (2026-10-24): what escapes reads as the dark duff between leaves, not as a bare core.
PILES = {
    "DeadLeaves_Pile_A": dict(seed=4101, a=54.0, d=48.0, hmax=16.0, skew=0.16, lobes=(0.10, 0.06, 0.05),
                              mounds=((20.0, -16.0, 14.0, 3.0), (-29.0, -22.0, 12.0, 2.2)), size=(9.0, 14.0),
                              uncovered=0.004, fill_max=150, toe=36, skirt=26, wallrow=18, top=20, fine=30, spill=10,
                              loose=6,
                              leaves=300, view_uncovered=0.18, budget=2470),
    "DeadLeaves_Pile_B": dict(seed=4202, a=38.0, d=38.0, hmax=12.5, skew=-0.34, lobes=(0.13, 0.07, 0.05),
                              mounds=((-14.0, -14.0, 10.0, 3.0),), size=(8.5, 13.0),
                              uncovered=0.005, fill_max=100, toe=26, skirt=20, wallrow=13, top=12, fine=20, spill=8,
                              loose=5,
                              leaves=240, view_uncovered=0.18, budget=2300),
}


def P(name):
    return ec.palette(name)


def mix(a, b, t):
    return np.asarray(a, float) * (1.0 - t) + np.asarray(b, float) * t


def _n(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-12)


def smooth(a, b, x):
    return fc.smoothstep(a, b, x)


def wave(x, y, z, seed, freq, octaves=6):
    """Smooth pseudo-noise -1..1 from fixed sinusoids, broadcasting over x, y, z (deterministic per seed)."""
    rng = np.random.default_rng(seed)
    total, amp_sum = 0.0, 0.0
    for k in range(octaves):
        w = rng.normal(size=3)
        w = w / np.linalg.norm(w) * freq * (1.0 + 0.55 * k)
        amp = 1.0 / (1.0 + 0.7 * k)
        total = total + amp * np.sin(x * w[0] + y * w[1] + z * w[2] + rng.uniform(0.0, TAU))
        amp_sum += amp
    return total / amp_sum


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


def rotate_about(v, axis, deg):
    a = _n(axis)
    t = math.radians(deg)
    k = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    r = np.eye(3) + math.sin(t) * k + (1 - math.cos(t)) * (k @ k)
    return np.asarray(v, float) @ r.T


class Parts:
    """Accumulates (verts, faces) with a slot, a tag and a part id per face, then builds one flat object."""

    def __init__(self, slots):
        self.slots = tuple(slots)
        self.v, self.f, self.slot, self.tag, self.part = [], [], [], [], []
        self.base = 0
        self.count = 0

    def add(self, verts, faces, slot, tag, part=None):
        verts = np.asarray(verts, float)
        if part is None:
            part = self.count
        self.count = max(self.count, part + 1)
        slots = list(slot) if isinstance(slot, (list, tuple, np.ndarray)) else [slot] * len(faces)
        tags = list(tag) if isinstance(tag, (list, tuple)) else [tag] * len(faces)
        assert len(slots) == len(faces) and len(tags) == len(faces)
        self.v.append(verts)
        self.f.extend([[self.base + int(i) for i in face] for face in faces])
        self.slot.extend([self.slots.index(s) for s in slots])
        self.tag.extend(tags)
        self.part.extend([part] * len(faces))
        self.base += len(verts)
        return part

    def tris(self):
        return sum(len(f) - 2 for f in self.f)

    def verts(self):
        return np.concatenate(self.v)

    def build(self, name, recalc):
        obj = ec.new_object(name, self.verts(), self.f, slots=self.slots, face_slots=self.slot, recalc_normals=recalc)
        if len(obj.data.polygons) != len(self.f):
            raise RuntimeError("%s: mesh.validate dropped faces (%d -> %d)" % (name, len(self.f), len(obj.data.polygons)))
        obj["_parts"] = json.dumps(self.part)
        return obj


# ================================================================ leaf machinery
_BARY = {}


def bary(n):
    if n not in _BARY:
        pts = [(i / n, j / n) for i in range(n + 1) for j in range(n + 1 - i)]
        _BARY[n] = np.array([(1.0 - u - v, u, v) for u, v in pts])
    return _BARY[n]


def tri_samples(v, faces, spacing=SAMPLE_CM):
    """Vertices + a barycentric lattice on every triangle (edges included), spaced about `spacing` cm."""
    out = [np.asarray(v, float)]
    for f in faces:
        t = v[list(f)]
        L = max(np.linalg.norm(t[1] - t[0]), np.linalg.norm(t[2] - t[1]), np.linalg.norm(t[0] - t[2]))
        n = int(min(max(math.ceil(L / spacing), 1), 90))
        out.append(bary(n) @ t)
    return np.concatenate(out)


class HField:
    """Top-of-pile height field (max z per cell, dilated one cell so it never under-reports a neighbour), an occupancy
    mask (unoccupied = bare floor at z 0), a per-cell leaf cover count and the core height for coverage stats."""

    def __init__(self, x0, x1, y0, y1, cell=CELL_CM):
        self.x0, self.y0, self.cell = x0, y0, cell
        self.nx = int(math.ceil((x1 - x0) / cell)) + 1
        self.ny = int(math.ceil((y1 - y0) / cell)) + 1
        self.h = np.zeros((self.nx, self.ny))
        self.occ = np.zeros((self.nx, self.ny), bool)
        self.cover = np.zeros((self.nx, self.ny), np.int32)
        self.core = np.zeros((self.nx, self.ny))
        self.coremask = np.zeros((self.nx, self.ny), bool)

    def ij(self, pts):
        pts = np.asarray(pts, float)
        i = np.floor((pts[:, 0] - self.x0) / self.cell).astype(np.int64)
        j = np.floor((pts[:, 1] - self.y0) / self.cell).astype(np.int64)
        inside = (i >= 0) & (i < self.nx) & (j >= 0) & (j < self.ny)
        return np.clip(i, 0, self.nx - 1), np.clip(j, 0, self.ny - 1), inside

    def support(self, pts, c, cf=0.0):
        i, j, inside = self.ij(pts)
        occ = self.occ[i, j] & inside
        return np.where(occ, self.h[i, j] + c, cf)

    def top(self, pts):
        i, j, inside = self.ij(pts)
        return np.where(self.occ[i, j] & inside, self.h[i, j], 0.0)

    def splat(self, pts, cover=True, core=False):
        i, j, inside = self.ij(pts)
        i, j, z = i[inside], j[inside], np.asarray(pts, float)[inside, 2]
        for di in (-1, 0, 1):
            for dj in (-1, 0, 1):
                ii = np.clip(i + di, 0, self.nx - 1)
                jj = np.clip(j + dj, 0, self.ny - 1)
                np.maximum.at(self.h, (ii, jj), z)
                self.occ[ii, jj] = True
        if core:
            np.maximum.at(self.core, (i, j), z)
            self.coremask[i, j] = True
        if cover:
            cells = np.unique(i * self.ny + j)
            np.add.at(self.cover.reshape(-1), cells, 1)

    def disk(self, xy, r):
        k = int(math.ceil(r / self.cell))
        ci, cj, _ = self.ij(np.array([[xy[0], xy[1]]]))
        ii, jj = np.meshgrid(np.arange(-k, k + 1), np.arange(-k, k + 1), indexing="ij")
        m = (ii ** 2 + jj ** 2) * self.cell ** 2 <= r * r
        ii = np.clip(ci[0] + ii[m], 0, self.nx - 1)
        jj = np.clip(cj[0] + jj[m], 0, self.ny - 1)
        return ii, jj

    def cover_mean(self, xy, r):
        ii, jj = self.disk(xy, r)
        return float(self.cover[ii, jj].mean())

    def occupied_frac(self, xy, r):
        ii, jj = self.disk(xy, r)
        return float(self.occ[ii, jj].mean())


def z_on_tris(xy, T):
    """Heights where vertical lines through xy (m, 2) cross triangles T (k, 3, 3): (m, k), -inf where they miss."""
    a, b, c = T[:, 0], T[:, 1], T[:, 2]
    v0, v1 = b[:, :2] - a[:, :2], c[:, :2] - a[:, :2]
    det = v0[:, 0] * v1[:, 1] - v0[:, 1] * v1[:, 0]
    ok = np.abs(det) > 1e-6
    det = np.where(ok, det, 1.0)
    p = xy[:, None, :] - a[None, :, :2]
    u = (p[..., 0] * v1[:, 1] - p[..., 1] * v1[:, 0]) / det
    v = (v0[:, 0] * p[..., 1] - v0[:, 1] * p[..., 0]) / det
    inside = (u >= -1e-6) & (v >= -1e-6) & (u + v <= 1.0 + 1e-6) & ok[None, :]
    z = a[:, 2] + u * (b[:, 2] - a[:, 2]) + v * (c[:, 2] - a[:, 2])
    return np.where(inside, z, -np.inf)


class Placed:
    """Every triangle already in the mesh (core + leaves) with its xy bounds, plus vertex / edge-midpoint probes: the
    exact geometry a new leaf must clear."""

    def __init__(self):
        self.T = np.zeros((0, 3, 3))
        self.lo = np.zeros((0, 2))
        self.hi = np.zeros((0, 2))
        self.pts = np.zeros((0, 3))

    def add(self, verts, faces):
        T = np.asarray(verts, float)[np.asarray(faces)]
        self.T = np.concatenate([self.T, T])
        self.lo = np.concatenate([self.lo, T[:, :, :2].min(axis=1)])
        self.hi = np.concatenate([self.hi, T[:, :, :2].max(axis=1)])
        self.pts = np.concatenate([self.pts, tri_samples(np.asarray(verts, float), faces, 0.45)])

    def near(self, lo, hi):
        m = (self.lo[:, 0] <= hi[0]) & (self.hi[:, 0] >= lo[0]) & (self.lo[:, 1] <= hi[1]) & (self.hi[:, 1] >= lo[1])
        q = self.pts
        pm = (q[:, 0] >= lo[0]) & (q[:, 0] <= hi[0]) & (q[:, 1] >= lo[1]) & (q[:, 1] <= hi[1])
        return self.T[m], q[pm]


def rest_exact(w, faces, placed, c, cf=0.0):
    """Lift (or lower) a leaf so every point of it is >= c above whatever was placed under it (vertically) and >= cf
    above the floor, touching at its closest point. Exact for the triangles placed so far."""
    s = tri_samples(w, faces)
    lo, hi = s[:, :2].min(axis=0) - 0.01, s[:, :2].max(axis=0) + 0.01
    T, probes = placed.near(lo, hi)
    floor = cf - s[:, 2]
    need = float(floor.max())
    if len(T):
        top = z_on_tris(s[:, :2], T).max(axis=1)
        need = float(np.where(np.isfinite(top), np.maximum(top + c - s[:, 2], floor), floor).max())
    if len(probes):
        zn = z_on_tris(probes[:, :2], w[np.asarray(faces)])
        zn = np.where(np.isfinite(zn), zn, np.inf).min(axis=1)
        ok = np.isfinite(zn)
        if ok.any():
            need = max(need, float((probes[ok, 2] + c - zn[ok]).max()))
    return need, s


def leaf_metrics(verts, faces, length):
    """(centre offset from the rim's least-squares plane / length, projected area along the mean normal / true area)."""
    rim = verts[1:]
    A = np.column_stack([rim[:, 0], rim[:, 1], np.ones(len(rim))])
    (a, b, c), *_ = np.linalg.lstsq(A, rim[:, 2], rcond=None)
    off = abs(c) / math.sqrt(1.0 + a * a + b * b) / length            # the centre is the origin
    T = verts[np.asarray(faces)]
    cr = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
    n = _n(cr.sum(axis=0))
    proj = float(np.abs(cr @ n).sum() / np.linalg.norm(cr, axis=1).sum())
    return float(off), proj


def leaf_shape(rng, kind, length, flipped, floor=False, fold=LEAF_FOLD, curl=0.0):
    """One dry ivy leaf in its own frame: the fan centre at the origin, midrib along +x (tip at +x), the visible side
    toward +z (every triangle wound that way). The blade stays flat and readable: a shallow V-fold along the midrib
    (each half tilted fold degrees, the two halves a little different), a slight lift at the tip, a small twist. The fan
    centre is never lifted off the midrib, and the fold is eased until the centre lies within LEAF_CENTRE_TOL x length
    of the rim plane. Returns (verts (n + 1, 3), faces, side per face, metrics)."""
    tpl = LEAF_TEMPLATES[kind]
    p = tpl + rng.uniform(-0.028, 0.028, tpl.shape)
    p[0] = tpl[0] + np.array([rng.uniform(-0.04, 0.02), rng.uniform(-0.05, 0.05)])       # the tip wanders
    width = rng.uniform(0.88, 1.06)
    along = p[:, 0]
    x = (along - LEAF_CENTRE) * length
    y = p[:, 1] * length * width
    lo_f = max(fold[0], 9.0) if floor else fold[0]
    fl, fr = (math.tan(math.radians(rng.uniform(lo_f, fold[1]))) for _ in range(2))
    tipw = np.clip((along - LEAF_CENTRE) / (1.0 - LEAF_CENTRE), 0.0, 1.0)
    basew = np.clip((LEAF_CENTRE - along) / LEAF_CENTRE, 0.0, 1.0)
    vz = np.where(y > 0.0, fl * y, -fr * y)
    tol = LEAF_CENTRE_TOL
    if curl > 0.0:
        # curled: both side lobes lift (the lift grows with the distance from the midrib, so the notches stay low and
        # the lobe tips rise curl degrees), the two sides a little different
        ymax = max(float(np.abs(y).max()), 1e-6)
        cl, cr = (math.tan(math.radians(curl * rng.uniform(0.85, 1.1))) for _ in range(2))
        vz = np.where(y > 0.0, cl, cr) * np.abs(y) * (np.abs(y) / ymax) ** 0.8
        tol = CURL_CENTRE_TOL
    lift = rng.uniform(0.02, 0.07) * length * tipw ** 2 + rng.uniform(0.0, 0.03) * length * basew ** 2
    twist = rng.uniform(-0.05, 0.05) * y * tipw
    faces = [[0, 1 + i, 1 + (i + 1) % len(tpl)] for i in range(len(tpl))]
    for _ in range(8):
        z = vz + lift + twist
        if flipped:
            z = -z                                # upside down: the pale underside is up, the fold a low ridge
        verts = np.vstack([[0.0, 0.0, 0.0], np.column_stack([x, y, z])])
        off, proj = leaf_metrics(verts, faces, length)
        if off <= tol * 0.92 and proj >= LEAF_PROJ_MIN:
            break
        vz, lift, twist = vz * 0.8, lift * 0.8, twist * 0.8
    n = len(tpl)
    side = []
    for i in range(n):
        ym = tpl[i, 1] + tpl[(i + 1) % n, 1]
        side.append(0 if (i == 0 or i == n - 1) else (1 if ym > 0 else -1))
    return verts, faces, side, (off, proj)


def fit_normal(hf, xy, r, wall=None, max_tilt=55.0):
    """Normal of the least-squares plane through the support heights round xy (samples behind the wall are skipped)."""
    pts = [np.array(xy, float)]
    for k in (0.5, 1.0):
        for a in np.linspace(0.0, TAU, 10, endpoint=False):
            pts.append(np.array(xy, float) + r * k * np.array([math.cos(a), math.sin(a)]))
    pts = np.array(pts)
    if wall is not None:
        pts = pts[pts[:, 1] <= wall]
    if len(pts) < 4:
        return np.array([0.0, 0.0, 1.0])
    z = hf.top(np.column_stack([pts, np.zeros(len(pts))]))
    A = np.column_stack([pts, np.ones(len(pts))])
    (a, b, _), *_ = np.linalg.lstsq(A, z, rcond=None)
    n = _n([-a, -b, 1.0])
    tilt = math.degrees(math.acos(min(1.0, n[2])))
    if tilt > max_tilt:
        h = _n([n[0], n[1], 0.0])
        t = math.radians(max_tilt)
        n = np.array([h[0] * math.sin(t), h[1] * math.sin(t), math.cos(t)])
    return n


def frame(n, yaw):
    d = np.array([math.cos(yaw), math.sin(yaw), 0.0])
    t1 = d - n * float(d @ n)
    if np.linalg.norm(t1) < 1e-6:
        t1 = np.array([1.0, 0.0, 0.0]) - n * n[0]
    t1 = _n(t1)
    return t1, np.cross(n, t1)


def clamp_tilt(n, max_tilt):
    n = _n(n)
    if math.degrees(math.acos(min(1.0, max(-1.0, float(n[2]))))) <= max_tilt:
        return n
    h = _n([n[0], n[1], 0.0]) if math.hypot(n[0], n[1]) > 1e-9 else np.array([1.0, 0.0, 0.0])
    t = math.radians(max_tilt)
    return np.array([h[0] * math.sin(t), h[1] * math.sin(t), math.cos(t)])


def drop_leaf(hf, placed, rng, xy, kind, length, flipped, wall=None, wedge=0.12, max_tilt=55.0, force_floor=False,
              normal=None, fold=LEAF_FOLD, curl=0.0):
    """Shape a leaf, lay it on the local slope of the height field with a random yaw (sometimes wedged a little steeper),
    clamp its tilt to max_tilt, keep it in front of the wall, then lower / raise it until it rests LEAF_C above what is
    under it. `normal` overrides the orientation (leaves leaning on the wall)."""
    floor = force_floor or hf.occupied_frac(xy, 0.45 * length) < 0.25
    v, f, side, met = leaf_shape(rng, kind, length, flipped, floor=floor, fold=fold, curl=curl)
    if normal is not None:
        n = _n(normal)
    else:
        n = fit_normal(hf, xy, 0.42 * length, wall=wall, max_tilt=max_tilt)
        ang = rng.uniform(0.0, TAU)
        axis = _n(np.cross(n, [math.cos(ang), math.sin(ang), 0.0]) + 1e-9)
        tilt = (rng.uniform(12.0, 25.0) if (rng.uniform() < wedge and not floor)
                else rng.uniform(0.0, 4.0 if floor else 10.0))
        n = clamp_tilt(rotate_about(n[None, :], axis, tilt)[0], max_tilt)
    t1, t2 = frame(n, rng.uniform(0.0, TAU))
    z0 = float(hf.top(np.array([[xy[0], xy[1], 0.0]]))[0])
    w = np.array([xy[0], xy[1], z0]) + v[:, 0:1] * t1 + v[:, 1:2] * t2 + v[:, 2:3] * n
    if wall is not None and w[:, 1].max() > wall:
        w[:, 1] -= w[:, 1].max() - wall
    lift, s = rest_exact(w, f, placed, LEAF_C)
    w[:, 2] += lift
    s[:, 2] += lift
    return w, f, side, n, s, floor, met


def clear_overlap(w, faces, placed, step=0.2, tries=40):
    """Raise a rested leaf in `step` cm steps until no triangle of it intersects (BVH overlap) or comes within 2 mm of
    the triangles already placed (catches thin steep contacts the vertical sampling of rest_exact can miss)."""
    lo, hi = w[:, :2].min(axis=0) - 0.5, w[:, :2].max(axis=0) + 0.5
    T, _ = placed.near(lo, hi)
    if not len(T):
        return 0.0
    tv = T.reshape(-1, 3)
    other = BVHTree.FromPolygons(tv.tolist(), np.arange(len(tv)).reshape(-1, 3).tolist(), all_triangles=True)
    lattice = tri_samples(w, faces, 0.5)
    lift = 0.0
    for _ in range(tries):
        q = w + np.array([0.0, 0.0, lift])
        mine = BVHTree.FromPolygons(q.tolist(), [list(x) for x in faces], all_triangles=True)
        near = any(other.find_nearest_range(tuple(p + np.array([0.0, 0.0, lift])), 0.2) for p in lattice[::3])
        if not other.overlap(mine) and not near:
            break
        lift += step
    return lift


def choose(rng, table):
    keys = [k for k, _ in table]
    w = np.array([p for _, p in table], float)
    return keys[int(rng.choice(len(keys), p=w / w.sum()))]


LEAF_TONES = (("dry", 3.0), ("orange", 2.2), ("brown", 2.0), ("dark", 0.6), ("red", 0.7), ("pale", 0.35),
              ("olive", 0.25))
UNDERSIDE_MAX = 1.25               # an upside-down leaf is at most this much lighter (luminance) than its top side


def lum(c):
    c = np.asarray(c, float)
    return float(0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2])


def tone_table():
    """One dark rust-umber mass (concept 6): dry and orange pulled down 0.8, the pale tone rare and warm (ochre-tan)."""
    dry = P("EnvLeafDry")
    return {"dry": dry * 0.8, "orange": P("EnvRustOrange") * 0.8, "brown": P("EnvBark"), "dark": P("EnvBarkDark"),
            "red": mix(P("EnvClothDark"), dry, 0.45), "pale": mix(dry, P("EnvCanvas"), 0.3) * 0.8,
            "olive": mix(P("EnvMossDark"), dry, 0.45)}


def pick_kind(rng, length_range, p8=0.6, p4=0.0):
    """(kind, length): five-lobed (LEAF5) for p8 of the leaves, kites only as 5-7 cm filler of the buried layer."""
    u = rng.uniform()
    if u < p4:
        return 4, rng.uniform(*KITE_LEN)
    if u < p4 + p8:
        return LEAF5, rng.uniform(*length_range)
    return 6, rng.uniform(*length_range)


def pile_outside(prm, seed):
    """(m, 2) xy -> how far (cm) each point lies past the heap's lobed outline (the core's floor ring), 0 inside."""
    a, d = prm["a"], prm["d"]

    def fn(xy):
        xy = np.asarray(xy, float)
        x, y = xy[:, 0], np.minimum(xy[:, 1], -1e-3)
        _, R = heap_height(x, y, prm, seed)
        rho = np.sqrt((x / a) ** 2 + (y / d) ** 2) / R
        r = np.hypot(x, y)
        return np.where(rho > 1.0, r * (1.0 - 1.0 / np.maximum(rho, 1e-9)), 0.0)
    return fn


class LeafSet:
    """The leaves of one mesh as they are dropped: parts, per-leaf records, the triangle count."""

    def __init__(self, parts, hf, rng, wall=None, fold=LEAF_FOLD, outside=None):
        self.parts, self.hf, self.rng, self.wall, self.fold = parts, hf, rng, wall, fold
        self.outside = outside         # (m, 2) xy -> cm past the heap outline (0 inside); None: no outline
        self.leaves = []
        self.placed = Placed()
        self.rejected = 0
        self.max_lift = 1.2            # a leaf that only clears its neighbours by floating higher is refused
        self.kite_cap = 10 ** 6        # 4-tri kites allowed in this mesh (a pile sets KITE_MAX_FRAC of its target)
        self.kites = 0
        self.why = {}

    def drop(self, xy, kind, length, wedge=0.12, flip_p=0.25, max_tilt=30.0, role="pile", max_z=None, max_top=None,
             normal=None, max_out=None, curl_p=CURL_P):
        """Drop one leaf; with max_z (cm) a leaf whose centre would rest higher is refused (returns None), with max_top
        one whose highest point would; with max_out one that reaches further than max_out cm past the heap outline, or
        that hangs (> 1.5 cm up) anywhere more than 1 cm past it (no leaf cantilevers over the toe)."""
        if kind == 4 and self.kites >= self.kite_cap:
            kind, length = 6, max(length, 7.0)
        flipped = bool(self.rng.uniform() < flip_p)
        curl = float(self.rng.uniform(*CURL_DEG)) if (kind != 4 and self.rng.uniform() < curl_p) else 0.0
        for attempt in range(6):
            w, f, side, n, s, floor, met = drop_leaf(self.hf, self.placed, self.rng, xy, kind, length, flipped,
                                                     wall=self.wall, wedge=wedge, max_tilt=max_tilt,
                                                     force_floor=attempt > 0, normal=normal, fold=self.fold,
                                                     curl=curl)
            tn = tri_normals(w, np.asarray(f))
            low = w[np.asarray(f)][:, :, 2].max(axis=1) < 0.3
            if not (low & (tn[:, 2] > 0.88)).any():          # no facet lying flat on the floor (z-fighting it)
                break
        lift = clear_overlap(w, f, self.placed)
        w[:, 2] += lift
        s[:, 2] += lift
        past = False
        if max_out is not None and self.outside is not None:
            out = self.outside(s[:, :2])
            past = bool(out.max() > max_out or ((out > 1.5) & (s[:, 2] > 2.5)).any())
        why = ("lift" if lift > self.max_lift else "max_z" if (max_z is not None and w[0, 2] > max_z) else
               "past" if past else "max_top" if (max_top is not None and w[:, 2].max() > max_top) else None)
        if why:
            self.why[why] = self.why.get(why, 0) + 1
            ii, jj = self.hf.disk(xy, 0.4 * length)
            self.hf.cover[ii, jj] += 2
            self.rejected += 1
            return None
        part = self.parts.add(w, f, "EnvLeafDry", ["leaf_%+d" % sd for sd in side])
        self.kites += kind == 4
        self.placed.add(w, f)
        self.hf.splat(s)
        tilt = math.degrees(math.acos(min(1.0, float(n[2]))))
        out_cm = float(self.outside(w[:, :2]).max()) if self.outside is not None else 0.0
        self.leaves.append(dict(part=part, kind=kind, length=round(float(length), 2), flipped=flipped, curl=curl,
                                out_cm=round(out_cm, 2), zc=float(w[0, 2]),
                                normal=n.tolist(), tone=choose(self.rng, LEAF_TONES),
                                value=float(self.rng.uniform(0.86, 1.1)), id=float(self.rng.uniform(0.02, 0.98)),
                                floor=bool(floor), role=role, tilt=round(tilt, 2), centre_off=round(met[0], 4),
                                proj=round(met[1], 4), max_tilt=max_tilt if normal is None else None))
        return part


# ---------------------------------------------------------------- the wall-base piles
def heap_height(x, y, prm, seed):
    """Target height of the heap (cm) at x, y (broadcasting): a lobed half dome against the wall (y <= 0)."""
    a, d = prm["a"], prm["d"]
    u, w = x / a, -y / d
    th = np.arctan2(w, u)
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0.0, TAU, 3)
    l1, l2, l3 = prm["lobes"]
    R = 1.0 + l1 * np.sin(3.0 * th + ph[0]) + l2 * np.sin(5.0 * th + ph[1]) + l3 * np.sin(8.0 * th + ph[2])
    rho = np.sqrt(u * u + w * w) / R
    base = np.maximum(1.0 - rho * rho, 0.0) ** prm.get("power", 1.4)       # a drift, <= ~28 deg so leaves can lie on it
    base = base * np.clip(1.0 + prm["skew"] * u, 0.4, 1.6)
    h = prm["hmax"] * base
    for mx, my, mr, mh in prm["mounds"]:
        h = h + mh * np.exp(-((x - mx) ** 2 + (y - my) ** 2) / (mr * mr)) * smooth(0.0, 0.25, base)
    h = h * (1.0 + 0.10 * wave(x, y, 0.0, seed + 1, 0.09, 4))
    return np.where(w >= 0.0, np.maximum(h, 0.0), 0.0), R


def pile_core(prm, seed, depth=1.0, segs=22, rings=(0.3, 0.5, 0.66, 0.8, 0.9, 0.96, 1.0)):
    """The duff core under the leaves: a fan of rings round the wall point (0, 0) out to the lobed outline, z = target
    height - depth, crumpled (+/- 0.5 cm per vertex) and eased into a low toe over its outer fifth so the flat skirt
    leaves can lap over it, the outer ring on the floor. An open shell (the wall and floor hide its back and
    underside); every face winds up."""
    a, d = prm["a"], prm["d"]
    jr = np.random.default_rng(seed + 17)
    th = np.linspace(0.0, math.pi, segs + 1)
    _, R = heap_height(np.cos(th) * a, -np.sin(th) * d, prm, seed)
    verts = [[0.0, 0.0, max(float(heap_height(np.array(0.0), np.array(-1e-3), prm, seed)[0]) - depth, 0.5)]]
    ring_ids = []
    for t in rings:
        ids = []
        for j in range(segs + 1):
            x = a * t * CORE_SCALE * R[j] * math.cos(th[j])
            y = -d * t * CORE_SCALE * R[j] * math.sin(th[j])
            if j in (0, segs):
                y = 0.0
            z = 0.0 if t >= 1.0 else max((float(heap_height(np.array(x), np.array(min(y, -1e-3)), prm, seed)[0])
                                          - depth) * float(smooth(1.0, 0.78, t)) + jr.uniform(-0.5, 0.5), 0.4)
            ids.append(len(verts))
            verts.append([x, y, z])
        ring_ids.append(ids)
    verts = np.array(verts)
    faces = []
    r0 = ring_ids[0]
    for j in range(segs):
        faces.append([0, r0[j], r0[j + 1]])
    for ra, rb in zip(ring_ids[:-1], ring_ids[1:]):
        for j in range(segs):
            faces.append([ra[j], rb[j], rb[j + 1], ra[j + 1]])
    out = []
    for face in faces:
        p = verts[face]
        nz = sum((p[i][0] - p[(i + 1) % len(p)][0]) * (p[i][1] + p[(i + 1) % len(p)][1]) for i in range(len(p)))
        out.append(face if nz > 0 else face[::-1])     # shoelace: counter-clockwise from above = normal up
    return verts, out


def sample_in_pile(rng, prm, seed, k, inner=0.0, outer=1.0):
    """k points (x, y) on the floor plan whose heap fraction rho lies in [inner, outer] (rejection sampling)."""
    a, d = prm["a"], prm["d"]
    out = []
    while len(out) < k:
        x = rng.uniform(-a * outer * 1.25, a * outer * 1.25)
        y = rng.uniform(-d * outer * 1.25, -0.8)
        h, R = heap_height(np.array(x), np.array(y), prm, seed)
        rho = math.hypot(x / a, y / d) / float(R)
        if inner <= rho <= outer and (outer > 1.0 or float(h) > 0.8):
            out.append((x, y))
    return out


def view_dir(az, el):
    a, e = math.radians(az), math.radians(el)
    return np.array([math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e)])


def tris_of(faces):
    return [f for q in faces for f in ([q] if len(q) == 3 else [[q[0], q[i], q[i + 1]] for i in range(1, len(q) - 1)])]


def core_samples(core_v, core_t, spacing=1.0):
    """Points (with their face normal) spread over the core's triangles, for the view coverage test."""
    pts, nrm = [], []
    for f in core_t:
        t = core_v[list(f)]
        n = _n(np.cross(t[1] - t[0], t[2] - t[0]))
        L = max(np.linalg.norm(t[1] - t[0]), np.linalg.norm(t[2] - t[1]), np.linalg.norm(t[0] - t[2]))
        k = int(min(max(math.ceil(L / spacing), 2), 60))
        b = bary(k)
        b = b[(b > 0.02).all(axis=1)] if len(b) > 3 else b
        pts.append(b @ t)
        nrm.append(np.repeat(n[None, :], len(b), axis=0))
    return np.concatenate(pts), np.concatenate(nrm)


def view_coverage(parts, samples, normals, views=COVER_VIEWS):
    """For each view (azimuth, elevation; the viewer stands in front of the wall): the fraction of core sample points
    facing the viewer that a ray toward the viewer reaches without hitting a leaf (or the core). Returns (fractions,
    the visible points)."""
    V = parts.verts()
    T = tris_of(parts.f)
    bvh = BVHTree.FromPolygons(V.tolist(), T, all_triangles=True)
    fr, vis = [], []
    for az, el in views:
        d = view_dir(az, el)
        facing = normals @ d > 0.08
        seen = 0
        for p, n in zip(samples[facing], normals[facing]):
            hit = bvh.ray_cast(tuple(p + n * 0.02 + d * 0.02), tuple(d), 500.0)
            if hit[0] is None:
                seen += 1
                vis.append((p, d))
        fr.append(seen / max(int(facing.sum()), 1))
    return fr, vis


def build_leaf_pile(name, prm):
    seed = prm["seed"]
    rng = np.random.default_rng(seed)
    a, d = prm["a"], prm["d"]
    parts = Parts(("EnvLeafDry",))
    hf = HField(-a * 2.4, a * 2.4, -d * 2.6, 0.0)
    core_v, core_f = pile_core(prm, seed)
    parts.add(core_v, core_f, "EnvLeafDry", "core")
    core_t = tris_of(core_f)
    hf.splat(tri_samples(core_v, core_t, 0.4), cover=False, core=True)
    leaves = LeafSet(parts, hf, rng, wall=-0.3, outside=pile_outside(prm, seed))
    leaves.kite_cap = int(KITE_MAX_FRAC * 0.85 * prm["leaves"])
    leaves.placed.add(core_v, core_t)
    MO = SPILL_OUT_CM
    lo, hi = prm["size"]
    hmax = prm["hmax"]
    ys = hf.y0 + (np.arange(hf.ny) + 0.5) * hf.cell
    core_mask = hf.coremask & (ys[None, :] < -2.5)

    def room():
        return parts.tris() + LEAF5 <= prm["budget"] and len(leaves.leaves) < prm["leaves"]

    # 1. skirt, the bottom layer: leaves seated low (<= 8 deg) across the core's floor contour, lapping over its toe and
    # reaching at most SPILL_OUT_CM past it, never hanging over the floor
    th0 = np.linspace(0.06 * math.pi, 0.94 * math.pi, prm["skirt"])
    for th in th0 + rng.uniform(-0.03, 0.03, len(th0)):
        if not room():
            break
        _, R = heap_height(np.array(a * math.cos(th)), np.array(-d * math.sin(th)), prm, seed)
        rim = np.array([a * float(R) * math.cos(th), -d * float(R) * math.sin(th)]) * (0.5 + 0.5 * CORE_SCALE)
        out = _n(np.array([math.cos(th) / a, -math.sin(th) / d, 0.0]))[:2]
        kind, length = pick_kind(rng, (lo, hi), p8=0.65, p4=0.0)
        for back in (0.0, 2.5):
            xy = rim + out * (rng.uniform(1.0, 3.5) - 0.45 * length - back)
            xy[1] = min(xy[1], -0.5 * length)
            if leaves.drop(tuple(xy), kind, length, wedge=0.0, max_tilt=8.0, role="skirt", flip_p=0.12, max_top=4.5,
                           max_out=MO) is not None:
                break
    # 2. coverage-guided fill, top-down (the cheap pass that hides most of the core)
    uncovered = 1.0
    while room() and len(leaves.leaves) < prm["fill_max"]:
        if len(leaves.leaves) % 6 == 0:
            uncovered = float((core_mask & (hf.cover == 0)).sum()) / max(int(core_mask.sum()), 1)
            if uncovered < prm["uncovered"]:
                break
        kind, length = pick_kind(rng, (lo, hi), p8=0.62, p4=0.06)
        cands = sample_in_pile(rng, prm, seed, 14)
        score = [hf.cover_mean(c, 0.38 * length) + rng.uniform(0.0, 0.12) for c in cands]
        xy = cands[int(np.argmin(score))]
        target = float(heap_height(np.array(xy[0]), np.array(xy[1]), prm, seed)[0])
        leaves.drop(xy, kind, length, wedge=0.06, max_tilt=30.0, max_z=target + 3.0, max_out=MO)
        if leaves.rejected > 400:
            break
    uncovered = float((core_mask & (hf.cover == 0)).sum()) / max(int(core_mask.sum()), 1)
    n_fill = len(leaves.leaves)
    # 3. toe band: the low outer fifth of the heap, which the fill (heap height > 0.8 cm) never reaches
    for _ in range(prm["toe"]):
        if not room():
            break
        kind, length = pick_kind(rng, (lo, hi), p8=0.6, p4=0.0)
        cands = sample_in_pile(rng, prm, seed, 10, 0.72, 0.97)
        score = [hf.cover_mean(c, 0.38 * length) + rng.uniform(0.0, 0.12) for c in cands]
        xy = cands[int(np.argmin(score))]
        tz = float(heap_height(np.array(xy[0]), np.array(xy[1]), prm, seed)[0])
        leaves.drop(xy, kind, length, wedge=0.0, max_tilt=22.0, role="toe", flip_p=0.15, max_z=tz + 4.0, max_out=MO)
    # 4. a row of leaves leaning on the wall along y = 0, so the back edge of the heap breaks up
    xs = np.linspace(-0.82 * a, 0.82 * a, prm["wallrow"])
    for x in xs + rng.uniform(-3.0, 3.0, len(xs)):
        if not room():
            break
        kind, length = pick_kind(rng, (lo, hi), p8=0.7, p4=0.0)
        lean = math.radians(rng.uniform(35.0, 58.0))
        n = rotate_about(np.array([[0.0, -math.sin(lean), math.cos(lean)]]), [0, 0, 1], rng.uniform(-20.0, 20.0))[0]
        leaves.drop((float(x), -0.3 * length), kind, length, role="wall", normal=n, max_top=hmax + 6.0, flip_p=0.15)
    # 5. top litter (the leaves you see first: mostly five-lobed), lying with the slope (<= 30 deg)
    for xy in sample_in_pile(rng, prm, seed, prm["top"], 0.0, 0.85):
        if not room():
            break
        tz = float(heap_height(np.array(xy[0]), np.array(xy[1]), prm, seed)[0])
        kind, length = pick_kind(rng, (lo, hi), p8=0.75, p4=0.0)
        leaves.drop(xy, kind, length, wedge=0.04, role="top", max_tilt=30.0, max_z=tz + 3.0)
    # 6. fine litter: 5-7 cm leaves filling the gaps of the top layer and the crest (up to hmax + 2)
    for xy in sample_in_pile(rng, prm, seed, prm["fine"], 0.0, 0.92):
        if not room():
            break
        kind, length = pick_kind(rng, (5.5, 8.0), p8=0.6, p4=0.0)
        leaves.drop(xy, kind, length, wedge=0.0, role="fine", max_tilt=30.0, max_top=hmax + 2.0, max_out=MO)
    # 7. spill at the rim and a few loose floor leaves (<= 15 deg)
    for xy in sample_in_pile(rng, prm, seed, prm["spill"], 0.86, 1.02):
        if not room():
            break
        tz = float(heap_height(np.array(xy[0]), np.array(min(xy[1], -1e-3)), prm, seed)[0])
        kind, length = pick_kind(rng, (lo, hi), p8=0.6, p4=0.0)
        leaves.drop(xy, kind, length, wedge=0.0, role="spill", max_tilt=12.0, max_z=tz + 3.0, max_out=MO)
    for xy in sample_in_pile(rng, prm, seed, prm["loose"], 1.0, 1.06):
        if not room():
            break
        kind, length = pick_kind(rng, (0.75 * lo, 0.9 * hi), p8=0.6, p4=0.0)
        leaves.drop(xy, kind, length, wedge=0.0, role="loose", max_tilt=8.0, max_out=MO)
    # 8. patch: what the player still sees of the core from 25 deg (five azimuths) and from the top gets a leaf, until
    # the leaf target / budget is spent
    samples, normals = core_samples(core_v, core_t)
    cov, vis = view_coverage(parts, samples, normals)
    leaves.why = {}
    if os.environ.get("ORG_DEBUG"):
        zz = np.array([q[0][2] for q in vis])
        rr = np.array([math.hypot(q[0][0] / a, q[0][1] / d) for q in vis])
        print("  DEBUG before patch: visible %d, z pct %s, rho pct %s" % (
            len(vis), np.percentile(zz, [10, 50, 90]).round(1) if len(zz) else [],
            np.percentile(rr, [10, 50, 90]).round(2) if len(rr) else []))
    patches, rounds = 0, 0
    while room() and rounds < 450:
        rounds += 1
        if not vis:
            xy = sample_in_pile(rng, prm, seed, 1, 0.0, 0.95)[0]
            kind, length = pick_kind(rng, (5.5, 8.0), p8=0.6, p4=0.0)
            leaves.drop(xy, kind, length, wedge=0.0, role="fine", max_tilt=30.0, max_top=hmax + 2.0, max_out=MO)
            continue
        for _ in range(4):
            if not room() or not vis:
                break
            p, dv = vis.pop(int(rng.integers(len(vis))))
            kind, length = pick_kind(rng, (0.8 * lo, hi), p8=0.66, p4=0.0)
            # the leaf goes where the escaping ray crosses the litter: shifted from the gap toward the viewer
            hd = _n(np.array([dv[0], dv[1], 0.0])) if abs(dv[2]) < 0.99 else np.zeros(3)
            off = rng.uniform(0.15, 0.35) * length
            if p[2] < 3.0:                               # on the toe: lay it over the gap, reaching in toward the heap
                hd = -_n(np.array([p[0] / a ** 2, p[1] / d ** 2, 0.0]))
                off = rng.uniform(0.05, 0.2) * length
            xy = (float(p[0] + hd[0] * off) + rng.uniform(-1.0, 1.0),
                  min(float(p[1] + hd[1] * off) + rng.uniform(-1.0, 1.0), -0.6))
            tz = float(heap_height(np.array(xy[0]), np.array(min(xy[1], -1e-3)), prm, seed)[0])
            if leaves.drop(xy, kind, length, wedge=0.0, role="patch", max_tilt=30.0, max_top=hmax + 3.5,
                           max_z=max(tz + 6.5, float(hf.top(np.array([[xy[0], xy[1], 0.0]]))[0]) + 2.0),
                           max_out=MO) is not None:
                patches += 1
            vis = [q for q in vis if math.hypot(q[0][0] - p[0], q[0][1] - p[1]) > 0.35 * length]
        cov, vis = view_coverage(parts, samples, normals)
    cov, vis = view_coverage(parts, samples, normals)
    if os.environ.get("ORG_DEBUG"):
        zz = np.array([q[0][2] for q in vis])
        rr = np.array([math.hypot(q[0][0] / a, q[0][1] / d) for q in vis])
        print("  DEBUG after patch: visible %d, z pct %s, rho pct %s, patch refusals %s" % (
            len(vis), np.percentile(zz, [10, 50, 90]).round(1) if len(zz) else [],
            np.percentile(rr, [10, 50, 90]).round(2) if len(rr) else [], leaves.why))
    zmax = {}
    for lf in leaves.leaves:
        zmax[lf["role"]] = max(zmax.get(lf["role"], 0.0), float(parts.v[lf["part"]][:, 2].max()))
    print("  refused by reason", leaves.why)
    print("  %s: leaves %d (fill %d, patch %d), refused %d, top-down core uncovered %.3f, view uncovered %s, "
          "top z by role %s" % (name, len(leaves.leaves), n_fill, patches, leaves.rejected, uncovered,
                                [round(c, 3) for c in cov], {k: round(v_, 1) for k, v_ in zmax.items()}))
    v = parts.verts()
    lo_b, hi_b = v.min(axis=0), v.max(axis=0)
    shift = np.array([-(lo_b[0] + hi_b[0]) * 0.5, 0.0, 0.0])
    parts.v = [x + shift for x in parts.v]
    hf.x0 += shift[0]
    obj = parts.build(name + "_Mars_SM", recalc=False)
    info = dict(parts=parts, leaves=leaves.leaves, hf=hf, wall=-0.3, n_fill=n_fill, core_uncovered=round(uncovered, 4),
                rejected=leaves.rejected, view_uncovered=[round(c, 4) for c in cov],
                view_uncovered_max=prm["view_uncovered"],
                core_tris=len(core_f) + sum(1 for q in core_f if len(q) == 4))
    paint_leaves(obj, info)
    return obj, info


def build_leaf_scatter(name):
    """One drift blown against one long side, broken into three uneven sub-drifts along the arc (different densities,
    8-15 cm gaps between them, each pushed in or out a few cm so the arc never reads as one designed curve), a trail
    thinning out from the west end across the -x half, and single leaves scattered through the centre. Leaves lie flat
    (<= 12 deg, V-fold <= 10 deg), the whole drift under 3 cm."""
    rng = np.random.default_rng(4303)
    parts = Parts(("EnvLeafDry",))
    hf = HField(-80.0, 80.0, -65.0, 65.0)
    leaves = LeafSet(parts, hf, rng, fold=(5.0, 10.0))
    leaves.kite_cap = 2
    budget = spec.TRIS["scatter"] - 2
    # sub-drifts: (s0, s1) along the arc (arc length ~95 cm), leaf count, radial push (cm), depth (cm)
    drifts = ((0.0, 0.27, 13, 3.0, 4.5), (0.39, 0.67, 15, -4.0, 6.0), (0.80, 1.0, 7, 1.5, 3.5))
    crescent = []
    for s0, s1, k, push, depth in drifts:
        for _ in range(k + 4):                                # a few spare candidates per drift
            u = rng.uniform(0.0, 1.0)
            sa = s0 + (s1 - s0) * u
            ph = math.pi * (0.29 + 0.42 * sa)
            c = np.array([72.0 * math.cos(ph), -50.0 + 72.0 * math.sin(ph)])
            out = _n(np.array([math.cos(ph), math.sin(ph), 0.0]))[:2]
            dd = depth * (0.5 + 0.5 * math.sin(math.pi * u))
            crescent.append((tuple(c + out * (push + rng.normal(0.0, dd)) + rng.normal(0.0, 1.5, 2)), k))
    path = np.array([[-30.0, 8.0], [-36.0, -4.0], [-41.0, -16.0], [-44.0, -28.0], [-45.0, -38.0]])
    trail = []
    for k in range(14):
        t = (k / 13.0) ** 0.9
        seg = min(int(t * (len(path) - 1)), len(path) - 2)
        u = t * (len(path) - 1) - seg
        p = path[seg] * (1.0 - u) + path[seg + 1] * u
        trail.append((tuple(p + rng.normal(0.0, 2.0 + 3.0 * t, 2)), t))
    centre = [(rng.uniform(-24.0, 26.0), rng.uniform(-22.0, 10.0)) for _ in range(9)]
    n_cres = 0
    di = 0
    want = {}
    for xy, k in crescent:
        if parts.tris() + LEAF5 > budget - 70:                 # keep room for the centre singles and the trail
            break
        if want.get(k, 0) >= k:
            continue
        kind, length = pick_kind(rng, (8.5, 12.5), p8=0.3, p4=0.04)
        if leaves.drop(xy, kind, length, wedge=0.0, flip_p=0.2, role="crescent", max_tilt=12.0,
                       max_top=3.0) is not None:
            n_cres += 1
            want[k] = want.get(k, 0) + 1
    n_centre = 0
    for xy in centre:
        if n_centre >= 7:
            break
        kind, length = pick_kind(rng, (8.5, 11.5), p8=0.4, p4=0.0)
        if parts.tris() + kind > budget:
            break
        if leaves.drop(xy, kind, length, wedge=0.0, flip_p=0.2, role="single", max_tilt=12.0,
                       max_top=3.0) is not None:
            n_centre += 1
    for xy, t in trail:
        if rng.uniform() < 0.4 * t:                         # thinning out along the trail
            continue
        kind, length = pick_kind(rng, (8.5, 12.0), p8=0.3, p4=0.0)
        if parts.tris() + kind > budget:
            break
        leaves.drop(xy, kind, length, wedge=0.0, flip_p=0.2, role="trail", max_tilt=12.0, max_top=3.0)
    print("  %s: leaves %d (drifts %d %s, centre %d), refused %d, tris %d" % (
        name, len(leaves.leaves), n_cres, sorted(want.values()), n_centre, leaves.rejected, parts.tris()))
    v = parts.verts()
    lo_b, hi_b = v.min(axis=0), v.max(axis=0)
    shift = np.array([-(lo_b[0] + hi_b[0]) * 0.5, -(lo_b[1] + hi_b[1]) * 0.5, -lo_b[2]])
    parts.v = [x + shift for x in parts.v]
    hf.x0 += shift[0]
    hf.y0 += shift[1]
    hf.h += shift[2]
    obj = parts.build(name + "_Mars_SM", recalc=False)
    info = dict(parts=parts, leaves=leaves.leaves, hf=hf, wall=None, n_fill=len(leaves.leaves), core_uncovered=None,
                core_tris=0)
    paint_leaves(obj, info)
    return obj, info


def paint_leaves(obj, info):
    """Per facet: the leaf's tone and value; on a pile the top 30 % of the leaves lean rust and the low ones (bottom,
    toe, skirt, spill) dark umber, so the heap reads as one coherent rust-umber mass; an upside-down leaf shows a warm
    ochre-tan underside no more than UNDERSIDE_MAX lighter than its top; the two halves of the fold lit differently;
    the core is dark duff. A = burial under later leaves, darker toward the core and at the floor / wall."""
    parts, hf = info["parts"], info["hf"]
    tones = tone_table()
    pile = info["wall"] is not None
    if not pile:                                   # the drift: no near-black leaves (no clump reads as a dropped object)
        tones["dark"] = mix(tones["brown"], tones["dry"], 0.3)
    by_part = {lf["part"]: lf for lf in info["leaves"]}
    zmax = max([lf["zc"] for lf in info["leaves"]] + [1.0])
    rust = mix(P("EnvRustOrange"), P("EnvLeafDry"), 0.35) * 0.82
    umber = mix(P("EnvBark"), P("EnvBarkDark"), 0.45)
    ochre = mix(P("EnvLeafDry"), P("EnvRustOrange"), 0.2) * 0.92
    duff = mix(P("EnvBarkDark"), P("EnvLeafDry"), 0.35) * 0.8
    crng = np.random.default_rng(29)
    rgb = []
    for tag, part in zip(parts.tag, parts.part):
        if tag == "core":                          # deep litter: a dark mosaic of leaf tones, never one smooth brown
            rgb.append(mix(duff, tones[choose(crng, LEAF_TONES)] * 0.55, 0.6) * crng.uniform(0.85, 1.1))
            continue
        lf = by_part[part]
        c = tones[lf["tone"]] * lf["value"]
        if pile:
            hn = lf["zc"] / zmax
            c = mix(c, rust, 0.4 * float(smooth(0.68, 0.95, hn)))
            low = lf["role"] in ("toe", "skirt", "spill", "loose")
            c = mix(c, umber, max(0.4 if low else 0.0, 0.4 * float(smooth(0.32, 0.08, hn))))
        if lf["flipped"]:
            top = lum(c)
            c = mix(c, ochre, 0.3) * 1.1
            if lum(c) > UNDERSIDE_MAX * top:
                c = c * (UNDERSIDE_MAX * top / lum(c))
        side = int(tag.split("_")[1])
        c = c * {1: 1.09, -1: 0.88, 0: 0.96}[side]
        rgb.append(c)
    v = fc.verts_cm(obj)
    depth = np.maximum(hf.top(v) - v[:, 2] - 0.6, 0.0)
    cav = np.clip(1.0 - depth / 5.0, 0.45, 1.0)
    cav *= np.where(v[:, 2] < 1.5, 0.78 + 0.22 * v[:, 2] / 1.5, 1.0)
    if pile:
        cav *= np.where(v[:, 1] > -4.0, 0.74 + 0.26 * np.clip(-v[:, 1] / 4.0, 0.0, 1.0), 1.0)
        i, j, inside = hf.ij(v)
        core_z = np.where(hf.coremask[i, j] & inside, hf.core[i, j], 0.0)
        cav *= 0.7 + 0.3 * smooth(0.3, 3.5, v[:, 2] - core_z)         # darker toward the core
    vert_part = np.zeros(len(v), np.int64)
    for f, pt in zip(parts.f, parts.part):
        vert_part[f] = pt
    core_parts = {pt for tag, pt in zip(parts.tag, parts.part) if tag == "core"}
    cav[np.isin(vert_part, list(core_parts))] = 0.4
    fc.paint(obj, np.array(rgb), alpha=np.clip(cav, 0.0, 1.0), variation=0.05, seed=11, cavity_darken=0.25)
    # UV0 then UV1 EnvData: u = per-leaf id (core = 0.5), v = 0
    fc.smart_uv(obj)
    ids = np.array([by_part[p]["id"] if p in by_part else 0.5 for p in parts.part])
    ec.write_data_uv(obj, ids, np.zeros(len(ids)), domain="FACE")


# ================================================================ SDF meshes (moss, mushroom base)
def sd_ellipsoid(x, y, z, c, r):
    px, py, pz = (x - c[0]) / r[0], (y - c[1]) / r[1], (z - c[2]) / r[2]
    k0 = np.sqrt(px * px + py * py + pz * pz)
    k1 = np.sqrt((px / r[0]) ** 2 + (py / r[1]) ** 2 + (pz / r[2]) ** 2)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def sd_capsule(x, y, z, a, b, ra, rb):
    a, b = np.asarray(a, float), np.asarray(b, float)
    e = b - a
    t = np.clip(((x - a[0]) * e[0] + (y - a[1]) * e[1] + (z - a[2]) * e[2]) / float(e @ e), 0.0, 1.0)
    dist = np.sqrt((x - a[0] - t * e[0]) ** 2 + (y - a[1] - t * e[1]) ** 2 + (z - a[2] - t * e[2]) ** 2)
    return dist - (ra + (rb - ra) * t)


def sd_quarter(y, z):
    """Signed distance to the stone quarter space {y >= 0, z <= 0} (the ledge), negative inside."""
    dy, dz = -y, z
    return np.sqrt(np.maximum(dy, 0.0) ** 2 + np.maximum(dz, 0.0) ** 2) + np.minimum(np.maximum(dy, dz), 0.0)


def sample_grid(fn, lo, hi, voxel):
    lo, hi = np.asarray(lo, float), np.asarray(hi, float)
    n = (np.ceil((hi - lo) / voxel) + 1).astype(int)
    axes = [lo[k] + np.arange(n[k]) * voxel for k in range(3)]
    vals = fn(axes[0][:, None, None], axes[1][None, :, None], axes[2][None, None, :])
    return np.array(np.broadcast_to(vals, tuple(n)), float), lo, voxel


def keep_main(verts, tris, min_frac=0.03):
    """Drop connected components smaller than min_frac of the largest (noise specks)."""
    parent = list(range(len(verts)))
    for t in tris.tolist():
        r0 = fc._uf_find(parent, t[0])
        for q in t[1:]:
            r = fc._uf_find(parent, q)
            if r != r0:
                parent[r] = r0
    roots = np.array([fc._uf_find(parent, int(t[0])) for t in tris])
    labels, counts = np.unique(roots, return_counts=True)
    keep_labels = labels[counts >= counts.max() * min_frac]
    keep = np.isin(roots, keep_labels)
    tris = tris[keep]
    used = np.unique(tris)
    remap = np.full(len(verts), -1, np.int64)
    remap[used] = np.arange(len(used))
    return verts[used], remap[tris], int(len(labels) - len(keep_labels))


def mesh_from_field(fn, lo, hi, voxel, target_tris, floor):
    vals, origin, vox = sample_grid(fn, lo, hi, voxel)
    if (vals[[0, -1], :, :] < 0).any() or (vals[:, [0, -1], :] < 0).any() or (vals[:, :, -1] < 0).any():
        raise RuntimeError("field reaches the grid boundary")
    cg.fill_pinches(vals, vox)
    hv, quads = cg.surface_nets(vals, origin, vox)
    verts, tris, full = cg._decimate(hv, quads, target_tris)
    verts, tris = cg._clean(verts, tris, True, 0.3 * vox if floor else -1e9)
    verts, tris, dropped = keep_main(verts, tris)
    return verts, tris, dict(grid=list(vals.shape), voxel=vox, nets_tris=int(full), specks_dropped=dropped)


def field_ao(fn, verts, normals, extra=None):
    acc = np.zeros(len(verts))
    for step, w in ((0.8, 0.4), (1.8, 0.35), (3.6, 0.25)):
        q = verts + normals * step
        dd = fn(q[:, 0], q[:, 1], q[:, 2])
        if extra is not None:
            dd = np.minimum(dd, extra(q))
        acc += w * np.clip(dd / step, 0.0, 1.0)
    return acc


def vertex_normals(obj):
    n = np.zeros(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("normal", n)
    return n.reshape(-1, 3)


def moss_colour(c, nrm, seed, hmax, soil_z=1.0, dry_ok=True):
    """Facet colour of moss at centre c (cm) with normal nrm: dark / mid / light patches, fresh tips on high top facets,
    a few dried brown patches, soil-dark at the floor line."""
    t = 0.5 + 0.5 * wave(c[0], c[1], c[2], seed, 0.11, 4)
    col = mix(P("EnvMossDark"), P("EnvMoss"), float(smooth(0.25, 0.8, t)))
    if nrm[2] > 0.55 and c[2] > 0.45 * hmax:
        col = mix(col, P("EnvLeafLight"), 0.3 + 0.25 * float(smooth(0.5, 0.9, t)))
    dry = 0.5 + 0.5 * wave(c[0], c[1], c[2], seed + 5, 0.07, 3)
    if dry > 0.78 and dry_ok:
        col = mix(col, P("EnvLeafDry") * 0.8, 0.45)
    if c[2] < soil_z:
        col = mix(col, P("EnvBarkDark"), 0.45)
    # stay inside the moss / soil range: never lighter than the fresh tips, never bluer than moss (no stone-chip facets)
    col = np.minimum(col, mix(P("EnvLeafLight"), P("EnvMoss"), 0.3) * 1.05)
    col[2] = min(col[2], 0.7 * col[1])
    return col


# ---------------------------------------------------------------- moss pads
PADS = {
    # a moss cushion for floors and ledge tops: 7-10 rounded scallops (3-4 segment arcs, notches <= 15 % of the radius),
    # a 1.3 cm rounded bevel before the rim, five flat-topped hummocks (two facet rings each, peaks 3.5-5 cm)
    "MossPad_A": dict(seed=5101, fold=False, centre=(0.0, 0.0), r=(31.0, 22.0), lobes=(7, 10), lobe_segs=(3, 4),
                      notch=(0.08, 0.15), n_in=12, hummocks=5, peak=(3.5, 5.0), base=1.1, rings=(5, 7),
                      size=(64, 46, 5)),
    # a step / ledge-edge strip: lies on the tread (y > 0) and its lip droops unevenly down the riser (3 cm at one end,
    # 10 cm at the other) with three short 4-6 cm tongues; two of its four hummocks 3.6-3.9 cm high. Edge pivot like
    # MossDrape_A (the edge along X at y 0, z 0)
    "MossPad_B": dict(seed=5202, fold=True, half_u=24.0, back=(11.5, 14.0), lip=(3.0, 10.0), tongues=3,
                      tongue_len=(4.0, 6.0), n_in=3, hummocks=4, peaks=(3.9, 3.6, 2.6, 2.2), peak=(2.2, 4.0),
                      base=0.9, row_step=5.0, rings=(4, 5), size=(48, 16, 16.5)),
}
PAD_RIM = (0.3, 0.48)              # rim thickness at the outline
PAD_BEVEL = 1.3                    # cm: the rounded edge ring inside the rim; the cushion is at full height past it
FOLD_R = 1.5                       # the fold rows at v = -1.5, 0, +1.5 (MossPad_B)


def poly_dist(pts, poly):
    """Distance from points (m, 2) to the edges of the closed polygon (k, 2)."""
    a = poly
    ab = np.roll(poly, -1, axis=0) - a
    rel = pts[:, None, :] - a[None]
    t = np.clip((rel * ab[None]).sum(-1) / (ab * ab).sum(-1)[None], 0.0, 1.0)
    return np.linalg.norm(rel - t[..., None] * ab[None], axis=2).min(axis=1)


def in_poly(pts, poly):
    x, y = pts[:, 0:1], pts[:, 1:2]
    x0, y0 = poly[None, :, 0], poly[None, :, 1]
    x1, y1 = np.roll(poly, -1, axis=0)[None, :, 0], np.roll(poly, -1, axis=0)[None, :, 1]
    cross = ((y0 > y) != (y1 > y)) & (x < (x1 - x0) * (y - y0) / np.where(y1 == y0, 1e-12, y1 - y0) + x0)
    return cross.sum(axis=1) % 2 == 1


def scallop_outline(rng, prm):
    """Counter-clockwise outline: an ellipse made of 7-10 rounded scallops, each lobe a 3-4 segment arc, the notches
    between them no deeper than 15 % of the radius."""
    rx, ry = prm["r"]
    cx, cy = prm["centre"]
    k = int(rng.integers(prm["lobes"][0], prm["lobes"][1] + 1))
    w = rng.uniform(0.7, 1.3, k)
    edges = np.concatenate([[0.0], np.cumsum(w / w.sum() * TAU)]) + rng.uniform(0.0, TAU)
    ang, rr = [], []
    for i in range(k):
        segs = int(rng.integers(prm["lobe_segs"][0], prm["lobe_segs"][1] + 1))
        notch = rng.uniform(*prm["notch"])
        bulge = rng.uniform(0.96, 1.06)
        for j in range(segs):
            t = j / segs
            a = edges[i] + (edges[i + 1] - edges[i]) * t
            ang.append(a)
            rr.append(bulge * (1.0 - notch * (1.0 - math.sin(math.pi * t) ** 0.55)))
    ang = np.asarray(ang)
    base = 1.0 / np.sqrt((np.cos(ang) / rx) ** 2 + (np.sin(ang) / ry) ** 2)
    r = base * np.asarray(rr) * (1.0 + rng.uniform(-0.02, 0.02, len(ang)))
    return np.column_stack([cx + r * np.cos(ang), cy + r * np.sin(ang)])


def strip_outline(rng, prm):
    """Counter-clockwise (u, v) outline of the step strip: the lip edge on the riser (v < 0) droops from lip[0] at -u to
    lip[1] at +u with short tongues, rounded ends, a scalloped back edge on the tread."""
    hu = prm["half_u"]
    lo, hi = prm["lip"]
    tongues = []
    while len(tongues) < prm["tongues"]:
        uc = rng.uniform(-hu + 6.0, 0.4 * hu)
        if all(abs(uc - t[0]) > 8.0 for t in tongues):
            tongues.append((uc, rng.uniform(*prm["tongue_len"]), rng.uniform(3.2, 4.0)))

    def depth(u):
        d = lo + (hi - lo) * ((u + hu) / (2.0 * hu)) ** 1.2
        for uc, L, hw in tongues:
            d = d + L * max(0.0, 1.0 - (abs(u - uc) / hw) ** 2) ** 0.5     # a blunt, rounded tongue
        return d
    us = list(np.arange(-hu + 2.5, hu - 2.5 + 1e-6, 3.6))
    us = [u + (rng.uniform(-0.4, 0.4) if 0 < i < len(us) - 1 else 0.0) for i, u in enumerate(us)]
    for uc, L, hw in tongues:
        us = [u for u in us if abs(u - uc) > hw + 0.8]
        us += [uc - hw, uc - 0.55 * hw, uc, uc + 0.55 * hw, uc + hw]
    us = sorted(us)
    bottom = [(u, -(depth(u) + rng.uniform(-0.25, 0.25))) for u in us]
    # back edge (scalloped), from +u to -u
    back = []
    n_l = int(rng.integers(5, 7))
    edges = np.linspace(hu - 2.5, -hu + 2.5, n_l + 1) + np.concatenate([[0.0], rng.uniform(-1.0, 1.0, n_l - 1), [0.0]])
    for i in range(n_l):
        notch = rng.uniform(0.08, 0.13)
        vb = rng.uniform(*prm["back"])
        for j in range(3):
            t = j / 3.0
            u = edges[i] + (edges[i + 1] - edges[i]) * t
            back.append((u, vb * (1.0 - notch * (1.0 - math.sin(math.pi * t) ** 0.55))))
    back.append((edges[-1], rng.uniform(*prm["back"]) * 0.9))
    dr, dl = bottom[-1][1], bottom[0][1]
    right = [(hu - 0.9, 0.55 * dr), (hu, 1.6), (hu - 1.0, 0.55 * back[0][1])]
    left = [(-hu + 1.0, 0.55 * back[-1][1]), (-hu, 1.4), (-hu + 0.9, 0.55 * dl)]
    return np.array(bottom + right + back + left, float)


def split_at_v0(poly):
    """Insert a vertex wherever an outline edge crosses v = 0 (the fold line)."""
    out = []
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        out.append(a)
        if (a[1] > 1e-6 and b[1] < -1e-6) or (a[1] < -1e-6 and b[1] > 1e-6):
            t = a[1] / (a[1] - b[1])
            out.append(np.array([a[0] + t * (b[0] - a[0]), 0.0]))
    return np.array(out)


def pad_hummocks(rng, prm, poly):
    """Distinct raised hummocks (cx, cy, rx, ry, angle, peak) inside the outline, kept off the rim."""
    hums = []
    lo, hi = poly.min(axis=0), poly.max(axis=0)
    tries = 0
    while len(hums) < prm["hummocks"] and tries < 4000:
        tries += 1
        c = rng.uniform(lo, hi)
        if prm["fold"] and c[1] < 1.0 and len(hums) < prm["hummocks"] - 1:
            continue                                          # the crest hummocks sit on the tread, one may ride the lip
        if not in_poly(c[None], poly)[0] or poly_dist(c[None], poly)[0] < 4.0:
            continue
        if any(math.hypot(c[0] - h[0], c[1] - h[1]) < 0.7 * h[2] + 4.0 for h in hums):
            continue
        if prm.get("peaks"):
            peak = prm["peaks"][len(hums)] * rng.uniform(0.97, 1.0)
        else:
            peak = rng.uniform(*prm["peak"]) if not hums else rng.uniform(0.7, 1.0) * prm["peak"][1]
        hums.append((c[0], c[1], rng.uniform(6.0, 11.0), rng.uniform(4.5, 8.0), rng.uniform(0.0, math.pi), peak))
    return hums


def pad_height(pts, poly, hums, prm, rim):
    """Height above the stone: the max of flat-topped hummock domes (pk (1 - q^3): a broad top, a ridge, crisp creases
    where two meet) over the base, eased from the rim thickness at the outline over the PAD_BEVEL ring."""
    d = poly_dist(pts, poly)
    core = np.full(len(pts), prm["base"])
    for cx, cy, rx, ry, a, pk in hums:
        lx = (pts[:, 0] - cx) * math.cos(a) + (pts[:, 1] - cy) * math.sin(a)
        ly = -(pts[:, 0] - cx) * math.sin(a) + (pts[:, 1] - cy) * math.cos(a)
        q = np.sqrt((lx / rx) ** 2 + (ly / ry) ** 2)
        core = np.maximum(core, pk * np.clip(1.0 - q ** 3, 0.0, 1.0))
    return rim + (core - rim) * smooth(0.0, PAD_BEVEL + 0.4, d) ** 0.6


def hummock_of(pts, hums):
    """Index of the hummock each point belongs to (the smallest normalised radius)."""
    qs = []
    for cx, cy, rx, ry, a, pk in hums:
        lx = (pts[:, 0] - cx) * math.cos(a) + (pts[:, 1] - cy) * math.sin(a)
        ly = -(pts[:, 0] - cx) * math.sin(a) + (pts[:, 1] - cy) * math.cos(a)
        qs.append(np.sqrt((lx / rx) ** 2 + (ly / ry) ** 2))
    return np.argmin(np.array(qs), axis=0)


def fold_map(u, v, h):
    """Unfolded pad coordinates -> Blender cm: v >= 0 lies on the tread (y = v, z = 0), v < 0 runs down the riser
    (y = 0, z = v); the height is laid along a normal that turns from +z to -y across |v| < FOLD_R, so the moss rounds
    over the edge while its underside follows the stone exactly."""
    phi = 0.5 * math.pi * smooth(FOLD_R, -FOLD_R, v)
    by = np.where(v >= 0.0, v, 0.0)
    bz = np.where(v >= 0.0, 0.0, v)
    return np.column_stack([u, by - h * np.sin(phi), bz + h * np.cos(phi)])


def build_moss_pad(name, prm):
    from mathutils import Vector
    from mathutils.geometry import delaunay_2d_cdt
    rng = np.random.default_rng(prm["seed"])
    poly = strip_outline(rng, prm) if prm["fold"] else scallop_outline(rng, prm)
    if prm["fold"]:
        poly = split_at_v0(poly)
    n_out = len(poly)
    hums = pad_hummocks(rng, prm, poly)
    # interior points: the hummock crowns, the fold rows (B), then darts at a falling spacing until n_in free points
    interior = [np.array(h[:2]) for h in hums]
    row0 = []
    if prm["fold"]:
        lo, hi = poly[:, 0].min(), poly[:, 0].max()
        us = np.arange(lo + 1.0, hi, prm["row_step"])
        for vrow in (-FOLD_R, 0.0, FOLD_R):
            for u in us + rng.uniform(-0.6, 0.6, len(us)):
                p = np.array([u, vrow])
                if in_poly(p[None], poly)[0] and poly_dist(p[None], poly)[0] > 1.2:
                    interior.append(p)
                    if vrow == 0.0:
                        row0.append(len(interior) - 1)
    def free_spot(p_, gap):
        if not in_poly(p_[None], poly)[0] or poly_dist(p_[None], poly)[0] < gap:
            return False
        if prm["fold"] and abs(p_[1]) < FOLD_R * 1.3:
            return False
        return min(np.linalg.norm(q - p_) for q in interior) >= 1.0
    # two facet rings per hummock: a broad top (q 0.45) and its ridge (q 0.85)
    for cx, cy, rx, ry, a, pk in hums:
        for nk, qr in zip(prm["rings"], (0.45, 0.85)):
            ph = rng.uniform(0.0, TAU)
            for kk in range(nk):
                t = ph + TAU * kk / nk
                lx, ly = qr * rx * math.cos(t), qr * ry * math.sin(t)
                p_ = np.array([cx + lx * math.cos(a) - ly * math.sin(a), cy + lx * math.sin(a) + ly * math.cos(a)])
                if free_spot(p_, 1.6):
                    interior.append(p_)
    # the rounded bevel ring PAD_BEVEL inside the outline
    for i in range(n_out):
        t = poly[(i + 1) % n_out] - poly[i - 1]
        nin = _n(np.array([-t[1], t[0], 0.0]))[:2]
        p_ = poly[i] + nin * PAD_BEVEL
        if free_spot(p_, 0.8 * PAD_BEVEL):
            interior.append(p_)
    free = 0
    spacing = 6.5
    lo, hi = poly.min(axis=0), poly.max(axis=0)
    for it in range(20000):
        if free >= prm["n_in"]:
            break
        if it % 2000 == 1999:
            spacing *= 0.88
        p = rng.uniform(lo, hi)
        if not in_poly(p[None], poly)[0] or poly_dist(p[None], poly)[0] < 0.5 * spacing:
            continue
        if prm["fold"] and abs(p[1]) < FOLD_R * 1.3:
            continue
        if min(np.linalg.norm(q - p) for q in interior) < spacing:
            continue
        interior.append(p)
        free += 1
    interior = np.array(interior)
    pts2 = np.vstack([poly, interior])
    out_edges = [(i, (i + 1) % n_out) for i in range(n_out)]
    row_edges = []
    if prm["fold"]:
        ids = [i for i in range(n_out) if abs(poly[i, 1]) < 1e-9] + [n_out + j for j in row0]
        ids = sorted(ids, key=lambda i: pts2[i, 0])
        for i, j in zip(ids[:-1], ids[1:]):
            mid = 0.5 * (pts2[i] + pts2[j])
            if in_poly(mid[None], poly)[0] and poly_dist(mid[None], poly)[0] > 0.05:
                row_edges.append((i, j))
    top = delaunay_2d_cdt([Vector(p) for p in pts2], out_edges + row_edges, [list(range(n_out))], 1, 1e-5, True)
    tv2 = np.array([tuple(c) for c in top[0]])
    t_orig = [o[0] if o else -1 for o in top[3]]
    if any(o >= n_out + len(interior) or o < 0 for o in t_orig):
        raise RuntimeError("%s: the CDT added vertices" % name)
    # bottom: the outline (plus the fold row on B, so no underside triangle bridges the step corner)
    if prm["fold"]:
        bsel = list(range(n_out)) + [n_out + j for j in row0]
    else:
        bsel = list(range(n_out))
    bmap = {o: k for k, o in enumerate(bsel)}
    bedges = [(bmap[i], bmap[j]) for i, j in out_edges] + [(bmap[i], bmap[j]) for i, j in row_edges]
    bot = delaunay_2d_cdt([Vector(pts2[i]) for i in bsel], bedges, [list(range(n_out))], 1, 1e-5, True)
    bv2 = np.array([tuple(c) for c in bot[0]])
    if len(bv2) != len(bsel):
        raise RuntimeError("%s: the bottom CDT added vertices" % name)
    rim = rng.uniform(*PAD_RIM, n_out)
    h = pad_height(tv2, poly, hums, prm, 0.4)
    is_rim = np.array([0 <= o < n_out for o in t_orig])
    h[is_rim] = rim[np.array(t_orig)[is_rim]]
    h[~is_rim] += rng.uniform(-0.15, 0.15, int((~is_rim).sum())) * smooth(1.5, 4.0, h[~is_rim])
    if prm["fold"]:
        top3 = fold_map(tv2[:, 0], tv2[:, 1], h)
        bot3 = fold_map(bv2[:, 0], bv2[:, 1], np.zeros(len(bv2)))
    else:
        top3 = np.column_stack([tv2, h])
        bot3 = np.column_stack([bv2, np.zeros(len(bv2))])
    nt = len(top3)
    verts = np.vstack([top3, bot3])
    faces = [list(f) for f in top[2]]
    faces += [[nt + i for i in f[::-1]] for f in bot[2]]
    t_of = {o: k for k, o in enumerate(t_orig)}
    for i in range(n_out):
        j = (i + 1) % n_out
        faces.append([t_of[j], t_of[i], nt + bmap[i], nt + bmap[j]])
    shift = np.array([-(verts[:, 0].min() + verts[:, 0].max()) * 0.5,
                      0.0 if prm["fold"] else -(verts[:, 1].min() + verts[:, 1].max()) * 0.5, 0.0])
    verts = verts + shift
    obj = ec.new_object(name + "_Mars_SM", verts, faces, slots=("EnvMoss",), recalc_normals=True)
    if len(obj.data.polygons) != len(faces):
        raise RuntimeError("%s: mesh.validate dropped faces" % name)
    obj["_parts"] = json.dumps([0] * len(faces))
    hv = np.concatenate([h, np.zeros(len(bot3))])
    cav = fc.cavity(obj)
    pk = max(hh[5] for hh in hums)
    # creases between hummocks and round the cushion's foot dark, open crests
    alpha = np.clip((0.4 + 0.6 * smooth(0.3, 0.6 * pk, hv)) * (0.6 + 0.4 * np.clip(cav * 2.0, 0.0, 1.0)), 0.0, 1.0)
    cen, nrm = fc.face_centers_cm(obj), fc.face_normals(obj)
    hf_face = np.array([hv[list(p_.vertices)].mean() for p_ in obj.data.polygons])
    uv_face = np.vstack([tv2, bv2])
    uv_c = np.array([uv_face[[vi if vi < nt else vi for vi in p_.vertices]].mean(axis=0) for p_ in obj.data.polygons])
    hid = hummock_of(uv_c, hums)
    hpk = np.array([hums[i][5] for i in hid])
    up = np.array([0.0, 0.0, 1.0])
    crest = mix(P("EnvLeafLight"), P("EnvLeafDry"), 0.25) * 1.15
    prng = np.random.default_rng(prm["seed"] + 3)
    rgb = []
    for c, n, hh, hp in zip(cen, nrm, hf_face, hpk):
        col = moss_colour(np.array([c[0], c[1], hh]), n if not prm["fold"] else up, prm["seed"], pk, soil_z=0.45)
        col = mix(col, crest, 0.5 * float(smooth(0.55, 0.9, hh / max(hp, 1e-3))) * float(hh > 1.6))
        rgb.append(col * prng.uniform(0.93, 1.07))
    fc.paint(obj, np.array(rgb), alpha=alpha, variation=0.06, seed=prm["seed"], cavity_darken=0.35)
    fc.smart_uv(obj)
    hum_ids = (np.arange(len(hums)) + rng.uniform(0.2, 0.8, len(hums))) / len(hums)
    hum_ids = hum_ids[rng.permutation(len(hums))]
    ec.write_data_uv(obj, hum_ids[hid], np.zeros(len(hid)), domain="FACE")
    return obj, dict(parts=None, hummocks=len(hums), outline_verts=n_out, interior_verts=len(interior),
                     peak_cm=round(float(h.max()), 2), rim_cm=[round(float(rim.min()), 2), round(float(rim.max()), 2)],
                     hummock_peaks_cm=[round(float(hh[5]), 2) for hh in hums],
                     lip_depth_cm=round(float(-poly[:, 1].min()), 2) if prm["fold"] else None)


# ---------------------------------------------------------------- moss drape over a ledge edge
DRAPE = dict(seed=5303, width=120.0, top=(7.0, 20.0), hang=(5.0, 11.0), thick=2.2, pen=0.3, round=2.5,
             clumps=(5, 6), tufts=(2, 3), tuft_n=(3, 4), strands=(45, 60), leader_len=(35.0, 60.0),
             follower_len=(8.0, 20.0), root_w=(1.0, 1.5), tip_w=(0.2, 0.3), flat=3.0, layer_cm=1.0,
             end_taper=20.0, end_wobble=6.0, mat_wave=(25.0, 35.0), bites=(3.0, 5.0), cushions=12, voxel=0.6,
             target=760, seg_lead=9.5, seg_follow=7.0, span=88.0)
STRAND_SIDES = 3                   # a thin triangular blade: visible width 1.5 x the ring radius


def drape_mat_profile(prm):
    """The cushion's thickness factor along X (0.7 .. 1.3 on a 25-35 cm wavelength: thicker mats joined by a lip that
    never pinches off) and the ragged ledge-top outline ltop(x) (a slow wave cut by 3-5 cm deep bites with straight
    sides), and the hang hg(x) of the face lip."""
    rng = np.random.default_rng(prm["seed"] + 77)
    half = prm["width"] * 0.5
    lam1 = rng.uniform(*prm["mat_wave"])
    ph1, ph2 = rng.uniform(0.0, TAU, 2)
    seed = prm["seed"]

    def mats(x):
        s_ = 0.72 * np.sin(TAU * x / lam1 + ph1) + 0.28 * np.sin(TAU * x / (1.9 * lam1) + ph2)
        return 1.0 + 0.3 * s_

    bites = []
    x = -half + rng.uniform(4.0, 9.0)
    while x < half - 4.0:
        w = rng.uniform(2.0, 5.0)
        bites.append((x + w, w, rng.uniform(*prm["bites"])))
        x += 2.0 * w + rng.uniform(5.0, 13.0)

    def ltop(x):
        t = 0.5 + 0.5 * (0.6 * wave(x, 0.0, 0.0, seed + 1, 0.05, 3) + 0.4 * wave(x, 0.0, 0.0, seed + 11, 0.17, 2))
        out = prm["top"][0] + (prm["top"][1] - prm["top"][0]) * t
        for c, w, dp in bites:
            out = out - dp * smooth(w + 0.8, w - 0.6, np.abs(x - c))
        return np.maximum(out, 3.0)

    def hang(x):
        t = 0.5 + 0.5 * (0.55 * wave(x, 0.0, 0.0, seed + 2, 0.08, 3) + 0.45 * wave(x, 0.0, 0.0, seed + 12, 0.3, 2))
        return (prm["hang"][0] + (prm["hang"][1] - prm["hang"][0]) * t) * np.clip(0.6 + 0.4 * mats(x), 0.7, 1.15)
    return mats, ltop, hang, bites


def strand_layout(prm, mats, hang):
    """45-60 thin strands in 5-6 clumps; each clump holds 2-3 tufts of 3-4 strands: one leader (35-60 cm) and short
    followers (8-20 cm). Strands alternate between a back layer on the face and a front layer layer_cm out, so
    neighbours never touch; a few carry a 2-3 mm sideways kink. Root width 1.0-1.5 cm, tip 0.2-0.3 cm."""
    rng = np.random.default_rng(prm["seed"])
    for _ in range(500):
        k = int(rng.integers(prm["clumps"][0], prm["clumps"][1] + 1))
        tufts = [[int(rng.integers(prm["tuft_n"][0], prm["tuft_n"][1] + 1))
                  for _ in range(int(rng.integers(prm["tufts"][0], prm["tufts"][1] + 1)))] for _ in range(k)]
        n = sum(sum(t) for t in tufts)
        if prm["strands"][0] <= n <= prm["strands"][1]:
            break
    clumps, widths = [], []
    for tl in tufts:
        x, offs = 0.0, []
        for ti, tn in enumerate(tl):
            if ti:
                x += rng.uniform(2.2, 3.4)
            so = []
            for si in range(tn):
                if si:
                    x += rng.uniform(1.05, 1.4)
                so.append(x)
            offs.append(so)
        clumps.append(offs)
        widths.append(x)
    between = rng.uniform(7.0, 14.0, k - 1)
    reach = rng.permutation(np.linspace(0.0, 1.0, k))    # each clump its own leader reach: short to long
    total = sum(widths) + between.sum()
    squeeze = min(1.0, prm["span"] / total)
    x0 = -0.5 * total * squeeze + rng.uniform(-2.0, 2.0)
    strands = []
    layer_flip = 0
    for ci, offs in enumerate(clumps):
        peel = rng.uniform(0.3, 1.2)
        llo, lhi = prm["leader_len"]
        span_c = (llo + (lhi - llo) * 0.55 * reach[ci], llo + (lhi - llo) * (0.45 + 0.55 * reach[ci]))
        for ti, so in enumerate(offs):
            sway = rng.uniform(-2.0, 2.0)
            lead = int(rng.integers(len(so)))
            lead_len = rng.uniform(*span_c)
            for si, off in enumerate(so):
                leader = si == lead
                length = lead_len if leader else rng.uniform(*prm["follower_len"]) * (0.8 + 0.2 * rng.uniform())
                length = max(length, prm["follower_len"][0]) if not leader else length
                rw = rng.uniform(*prm["root_w"]) * (1.0 if leader else 0.85 + 0.15 * rng.uniform())
                kink = None
                if rng.uniform() < 0.3:
                    kink = (float(rng.uniform(0.35, 0.8)), float(rng.choice([-1.0, 1.0]) * rng.uniform(0.2, 0.3)))
                strands.append(dict(x=float(x0 + off * squeeze), clump=ci, tuft=ti, leader=leader,
                                    root_w=float(max(rw, prm["root_w"][0])), tip_w=float(rng.uniform(*prm["tip_w"])),
                                    length=float(length), sway=float(sway * (1.0 if leader else 0.6)),
                                    drift=float(rng.uniform(-0.4, 0.4)), peel=float(peel * rng.uniform(0.9, 1.1)),
                                    twist=float(rng.uniform(-20.0, 20.0)), kink=kink, dry=False, id=0.0,
                                    layer=(si + layer_flip) % 2))
            layer_flip += len(so)
        x0 += (widths[ci] + (between[ci] if ci < k - 1 else 0.0)) * squeeze
    half = prm["width"] * 0.5
    if max(abs(s_["x"]) for s_ in strands) > half - 12.0:
        raise RuntimeError("drape strands overrun the cushion (%.1f)" % max(abs(s_["x"]) for s_ in strands))
    for i in rng.choice(len(strands), 3, replace=False):
        strands[int(i)]["dry"] = True                     # three strands carry a stronger ochre over their tips
    ids = rng.permutation((np.arange(len(strands)) + rng.uniform(0.2, 0.8, len(strands))) / len(strands))
    for s_, i in zip(strands, ids):
        s_["id"] = float(i)
    return strands


def ribbon_tube(path, half_w, half_t, twist_deg, rng, nsides=4, fork=None):
    """A closed flat ribbon along a downward path: a diamond (nsides 4) or triangle (3) cross-section, wide along the
    face (x), thin off it (y), twisted a little along its length; pointed caps at both ends. Every vertex is kept
    >= 0.25 cm in front of the ledge face (y <= -0.25). fork = (length, spread) splits the tip into two prongs (a
    frayed end) inside the same closed surface."""
    rings = []
    m = len(path)
    for i, (c, w, t) in enumerate(zip(path, half_w, half_t)):
        a = math.radians(twist_deg) * i / max(m - 1, 1)
        pts = []
        for k in range(nsides):
            th = TAU * k / nsides
            lx, ly = w * math.cos(th) * rng.uniform(0.9, 1.1), t * math.sin(th)
            pts.append([c[0] + lx * math.cos(a) - ly * math.sin(a) * 0.35, c[1] + ly * math.cos(a) + lx * math.sin(a) * 0.25,
                        c[2]])
        pts = np.array(pts)
        over = pts[:, 1].max() + 0.25
        if over > 0.0:
            pts[:, 1] -= over
        rings.append(pts)
    top = path[0] + np.array([0.0, 0.0, 0.6 * half_w[0]])
    top[1] = min(top[1], -0.25 - half_t[0])
    down = _n(path[-1] - path[-2])
    if fork is None:
        tip = path[-1] + (path[-1] - path[-2]) * 0.25
        tip[1] = min(tip[1], -0.3)
        tips = [tip]
    else:
        flen, spread = fork
        side = np.array([1.0, 0.0, 0.0])
        tips = [path[-1] + down * flen + side * spread + np.array([0.0, -rng.uniform(0.1, 0.5), 0.0]),
                path[-1] - down * 0.0 + down * flen * rng.uniform(0.75, 1.0) - side * spread,
                path[-1] + down * 0.9]                    # the notch between the prongs
        for t_ in tips:
            t_[1] = min(t_[1], -0.3)
    verts = np.vstack([top[None]] + rings + [t_[None] for t_ in tips])
    faces = []
    for k in range(nsides):
        faces.append([0, 1 + (k + 1) % nsides, 1 + k])
    for i in range(m - 1):
        a0, b0 = 1 + i * nsides, 1 + (i + 1) * nsides
        for k in range(nsides):
            k2 = (k + 1) % nsides
            faces.append([a0 + k, a0 + k2, b0 + k2, b0 + k])
    last = 1 + (m - 1) * nsides
    if fork is None:
        tipi = len(verts) - 1
        for k in range(nsides):
            faces.append([last + k, last + (k + 1) % nsides, tipi])
    else:                                                 # diamond ring R B L F -> prongs TR / TL, notch N
        R, Bk, Lf, F = last, last + 1, last + 2, last + 3
        TR, TL, N = len(verts) - 3, len(verts) - 2, len(verts) - 1
        faces += [[R, Bk, TR], [Bk, N, TR], [Bk, TL, N], [Bk, Lf, TL],
                  [F, TR, R], [F, N, TR], [F, TL, N], [F, Lf, TL]]
    return verts, faces


def near_parallel(bvh, verts, faces, gap=0.22, dot=0.88):
    """True when a face of (verts, faces) lies within `gap` cm of, and nearly parallel to, a face in bvh (a quad is
    tested split along both diagonals, since the export may triangulate it either way)."""
    both = []
    for q in faces:
        both += tris_of([q]) + ([[q[1], q[2], q[3]], [q[1], q[3], q[0]]] if len(q) == 4 else [])
    for f in both:
        p = verts[f]
        n = np.cross(p[1] - p[0], p[2] - p[0])
        if np.linalg.norm(n) < 1e-9:
            continue
        n = _n(n)
        c = p.mean(axis=0)
        for q in (c, 0.5 * (c + p[0]), 0.5 * (c + p[1]), 0.5 * (c + p[2])):
            for sgn in (1.0, -1.0):
                hit = bvh.ray_cast(tuple(q + n * sgn * 1e-4), tuple(n * sgn), gap)
                if hit[0] is not None and abs(float(n @ np.array(hit[1]))) > dot:
                    return True
    return False


def conflict(va, fa, vb, fb):
    """Either piece has a face within 2.2 mm of, and nearly parallel to, a face of the other."""
    ba = BVHTree.FromPolygons(np.asarray(va).tolist(), tris_of(fa), all_triangles=True)
    bb = BVHTree.FromPolygons(np.asarray(vb).tolist(), tris_of(fb), all_triangles=True)
    return near_parallel(bb, np.asarray(va), fa) or near_parallel(ba, np.asarray(vb), fb)


def strand_geometry(st, prm, rng, exit_drop=0.0):
    """(verts, faces, tag) pieces of one strand: a thin triangular blade from a root ring buried in the mat's lip, down
    to a single point (no forks); an optional 2-3 mm sideways kink."""
    flat = prm["flat"]
    L = st["length"]
    nseg = max(2, int(math.ceil(L / (prm["seg_lead"] if st["leader"] else prm["seg_follow"]))))
    s_ = np.linspace(0.0, 1.0, nseg + 1)
    x = st["x"] + st["sway"] * s_ ** 1.5 + st["drift"] * np.sin(math.pi * s_) + rng.uniform(-0.12, 0.12, len(s_)) * s_
    if st["kink"] is not None:
        at, dx = st["kink"]
        x = x + dx * (s_ >= at)
    z = st["anchor_z"] - 1.6 - exit_drop - L * s_
    # ring radius from the visible width (a triangle shows 1.5 x its radius)
    r0, r1 = st["root_w"] / 1.5, st["tip_w"] / 1.5
    hw = (r0 + (r1 - r0) * s_ ** 0.75) * rng.uniform(0.92, 1.08, len(s_))
    hw[-1] = r1
    ht = np.maximum(hw / flat, 0.1)
    lay = prm["layer_cm"] * st["layer"]
    y = -(ht + 0.3) - st["peel"] * s_ ** 2 - lay
    hw0 = 0.45 * r0
    ht0 = max(hw0 / flat, 0.1)
    path = np.vstack([[st["x"], -(ht0 + 0.3), st["anchor_z"] + 0.6], np.column_stack([x, y, z])])
    hw, ht = np.concatenate([[hw0], hw]), np.concatenate([[ht0], ht])
    return [(ribbon_tube(path, hw, ht, st["twist"], rng, nsides=STRAND_SIDES), "strand")]


def drape_setup(prm):
    half = prm["width"] * 0.5
    seed = prm["seed"]
    rng = np.random.default_rng(seed + 3)
    mats, ltop, hang, bites = drape_mat_profile(prm)
    strands = strand_layout(prm, mats, hang)
    # every strand starts flush inside the mat's continuous face lip (no per-strand knob): its root ring is buried in
    # the lip, its first ring just below the lip's lower edge
    for st in strands:
        st["anchor_z"] = float(-hang(np.array(st["x"])) + 1.0)
    # chunky cushions sitting on the mat (top and just over the edge), kept on the thick mats
    cushions = []
    while len(cushions) < prm["cushions"]:
        x = rng.uniform(-half + 14.0, half - 14.0)
        if float(mats(np.array(x))) < 0.98:
            continue
        lt = float(ltop(np.array(x)))
        if rng.uniform() < 0.75:
            c = np.array([x, rng.uniform(2.0, max(lt - 4.0, 2.5)), rng.uniform(-0.6, 0.2)])
        else:
            c = np.array([x, -rng.uniform(0.0, 0.6), -rng.uniform(2.0, 4.0)])     # a lump on the face, under the edge
        cushions.append((c, rng.uniform(1.6, 2.8)))

    def sheet(x, y, z):
        wob = prm["end_wobble"] * wave(0.2 * x, y, z, seed + 3, 0.16, 3)
        ex = smooth(half, half - prm["end_taper"], np.abs(x) + wob) ** 1.6     # each end thins to nothing
        lt, hg = ltop(x), hang(x)
        top_t = np.where(y > 0.0, smooth(lt, lt - 4.0, y), 1.0)
        face_t = np.where(z < 0.0, smooth(-hg - 0.8, -hg + 1.4, z), 1.0)      # a lip that keeps its thickness
        T = (prm["thick"] * mats(x) * (0.55 + 0.45 * ex) * (1.0 + 0.25 * wave(x, y, z, seed + 4, 0.12, 4))
             + 0.4 * wave(x, y, z, seed + 5, 0.38, 3)) * ex * top_t * face_t
        T = np.maximum(T, 0.0)
        sdq = sd_quarter(y, z)
        sdr = sd_quarter(y - prm["round"], z + prm["round"]) - prm["round"]
        return np.maximum(np.maximum(sdq - T, -sdr - prm["pen"]), 0.8 - T)     # the back always sinks pen

    def cushions_fn(x, y, z):
        d = None
        for c, r in cushions:
            e = np.sqrt((x - c[0]) ** 2 + (y - c[1]) ** 2 + ((z - c[2]) * 1.6) ** 2) - r
            d = e if d is None else cg._smin(d, e, 1.5)
        return d

    def fn(x, y, z):
        d = cg._smin(sheet(x, y, z), cushions_fn(x, y, z), 1.8)
        d = d - 0.3 * wave(x, y, z, seed + 6, 0.55, 3)
        sdr = sd_quarter(y - prm["round"], z + prm["round"]) - prm["round"]
        return np.maximum(d, -sdr - prm["pen"])
    return fn, mats, ltop, hang, bites, strands


def build_moss_drape(name, prm=DRAPE):
    """The cushion over the edge (SDF -> surface nets -> collapse) with the hanging moss built as explicit thin blades:
    wispy, clumped in tufts (one long leader, short followers), each its own closed piece rooted in the mat's lip
    (concept 5)."""
    fn, mats, ltop, hang, bites, strands = drape_setup(prm)
    half = prm["width"] * 0.5
    lo = (-half - 6.0, -10.0, -prm["hang"][1] * 1.3 - 8.0)
    hi = (half + 6.0, prm["top"][1] + 4.0, prm["thick"] * 1.6 + 6.0)
    verts, tris, meta = mesh_from_field(fn, lo, hi, prm["voxel"], prm["target"], floor=False)
    pen = prm["pen"]
    verts[(np.abs(verts[:, 2] + pen) < 0.05) & (verts[:, 1] > pen), 2] = -pen        # tidy the inner contact planes
    verts[(np.abs(verts[:, 1] - pen) < 0.05) & (verts[:, 2] < -pen), 1] = pen
    parts = Parts(("EnvMoss",))
    parts.add(verts, tris.tolist(), "EnvMoss", "mat", part=0)
    rng = np.random.default_rng(prm["seed"] + 9)
    owner = {0: -1}
    mat_bvh = BVHTree.FromPolygons(verts.tolist(), tris.tolist(), all_triangles=True)
    for si, st in enumerate(strands):
        state = rng.bit_generator.state
        for drop in (0.0, 0.8, 1.6, 2.4):                 # leave the anchor lower until no face runs along the mat
            rng.bit_generator.state = state
            pieces = strand_geometry(st, prm, rng, exit_drop=drop)
            if any(near_parallel(mat_bvh, sv, sf) for (sv, sf), _ in pieces):
                continue
            sv, sf = pieces[0][0]
            lo_s, hi_s = sv.min(axis=0) - 0.5, sv.max(axis=0) + 0.5
            tc = verts[tris].mean(axis=1)
            near = tris[((tc >= lo_s) & (tc <= hi_s)).all(axis=1)]
            st_bvh = BVHTree.FromPolygons(sv.tolist(), tris_of(sf), all_triangles=True)
            if not len(near) or not near_parallel(st_bvh, verts, near.tolist()):
                break
        st["exit_drop"] = drop
        for (sv, sf), tag in pieces:
            p = parts.add(sv, sf, "EnvMoss", tag, part=parts.count)
            owner[p] = si
        st["tip_z"] = float(min(v_[:, 2].min() for v_, pt in zip(parts.v, range(len(parts.v)))
                                if owner.get(pt) == si))
    shift_x = -(parts.verts()[:, 0].min() + parts.verts()[:, 0].max()) * 0.5
    parts.v = [x + np.array([shift_x, 0.0, 0.0]) for x in parts.v]
    obj = parts.build(name + "_Mars_SM", recalc=True)
    fs = lambda x, y, z: fn(x - shift_x, y, z)            # noqa: E731
    vv = fc.verts_cm(obj)
    vert_part = np.zeros(len(vv), np.int64)
    for f, pt in zip(parts.f, parts.part):
        vert_part[f] = pt
    mat_v = vert_part == 0
    ao = np.ones(len(vv))
    ao[mat_v] = field_ao(fs, vv[mat_v], vertex_normals(obj)[mat_v], extra=lambda q: sd_quarter(q[:, 1], q[:, 2]) + 0.4)
    cav = fc.cavity(obj)
    # creases dark, crests open
    alpha = np.clip(ao * (0.5 + 0.5 * np.clip(cav * 2.0, 0.0, 1.0)), 0.0, 1.0)
    st_v = ~mat_v
    cen, nrm = fc.face_centers_cm(obj), fc.face_normals(obj)
    root_c, mid_c = mix(P("EnvMossDark"), P("EnvMoss"), 0.3), mix(P("EnvMoss"), P("EnvLeafLight"), 0.5) * 1.45
    olive = mix(P("EnvLeafLight"), P("EnvLeafDry"), 0.5) * 1.65             # the yellow-olive tips of concept 5
    ochre = mix(P("EnvLeafDry"), P("EnvMoss"), 0.3)
    crest = mix(P("EnvLeafLight"), P("EnvLeafDry"), 0.2) * 1.1
    prng = np.random.default_rng(prm["seed"] + 21)
    tone = {i: prng.uniform(0.9, 1.1) for i in range(len(strands))}
    face_cav = np.array([cav[list(p_.vertices)].mean() for p_ in obj.data.polygons])
    rgb, ids, flex = [], [], []
    sx = np.array([s_["x"] + shift_x for s_ in strands])
    for c, n, pt, fcv in zip(cen, nrm, parts.part, face_cav):
        own = owner[pt]
        if own < 0:
            col = moss_colour(c + np.array([0.0, 0.0, 6.0]), n, prm["seed"], 6.0, soil_z=-999.0,
                              dry_ok=abs(c[0]) <= half - 18.0)
            if c[2] < -3.0:
                col = mix(col, P("EnvMossDark") * 0.9, 0.3 * float(np.clip((-3.0 - c[2]) / 10.0, 0.0, 1.0)))
            up = max(float(n[2]), float(-n[1]) * 0.6)                       # the lit crests: up or out of the face
            if up > 0.45 and fcv > 0.52:
                col = mix(col, crest, 0.5 * float(smooth(0.45, 0.9, up)))
            col = col * prng.uniform(0.92, 1.08)                           # +/- 8 % value per facet
            k = int(np.argmin(np.abs(sx - c[0])))
            ids.append(strands[k]["id"])
            flex.append(float(np.clip((-2.0 - c[2]) / 40.0, 0.0, 0.2)))
        else:
            st = strands[own]
            t = float(np.clip((st["anchor_z"] - 1.6 - c[2]) / max(st["anchor_z"] - 1.6 - st["tip_z"], 1.0), 0.0, 1.0))
            col = mix(root_c, mid_c, float(smooth(0.0, 0.45, t))) * tone[own]
            col = mix(col, olive, 0.85 * float(smooth(0.66, 0.9, t)))      # the last quarter of every strand
            if st["dry"]:
                col = mix(col, ochre, 0.5 * float(smooth(0.55, 0.95, t)))
            ids.append(st["id"])
            flex.append(t)
        rgb.append(col)
    # strand alpha: shaded at the root under the lip, open below
    fl = np.zeros(len(vv))
    cnt = np.zeros(len(vv))
    for p_, fv in zip(obj.data.polygons, flex):
        for vi in p_.vertices:
            fl[vi] += fv
            cnt[vi] += 1
    fl /= np.maximum(cnt, 1)
    alpha[st_v] = np.clip(0.55 + 0.45 * smooth(0.0, 0.3, fl[st_v]), 0.0, 1.0)
    fc.paint(obj, np.array(rgb), alpha=alpha, variation=0.04, seed=prm["seed"], cavity_darken=0.35)
    fc.smart_uv(obj)
    ec.write_data_uv(obj, np.array(ids), np.array(flex), domain="FACE")
    meta.update(parts=parts, owner=owner, strands=len(strands),
                strand_lengths_cm=sorted(round(s_["length"], 1) for s_ in strands),
                leaders=sum(s_["leader"] for s_ in strands),
                leader_lengths_cm=sorted(round(s_["length"], 1) for s_ in strands if s_["leader"]),
                follower_lengths_cm=[round(min(s_["length"] for s_ in strands if not s_["leader"]), 1),
                                     round(max(s_["length"] for s_ in strands if not s_["leader"]), 1)],
                root_w_cm=[round(min(s_["root_w"] for s_ in strands), 2), round(max(s_["root_w"] for s_ in strands), 2)],
                tip_w_cm=[round(min(s_["tip_w"] for s_ in strands), 2), round(max(s_["tip_w"] for s_ in strands), 2)],
                kinked=sum(1 for s_ in strands if s_["kink"] is not None),
                clumps=len({s_["clump"] for s_ in strands}),
                tufts=len({(s_["clump"], s_["tuft"]) for s_ in strands}),
                dry_strands=sum(s_["dry"] for s_ in strands), mat_tris=int(len(tris)),
                ltop_bites=len(bites), strand_tips_cm=[round(s_["tip_z"], 2) for s_ in strands])
    return obj, meta


# ================================================================ mushroom cluster
# the gnarled root: x, y, z, radius (cm). Two kinks (at x -6 and x 9), two knots (x 4.5 and x 16.5), radius +/- 30 %,
# the +X end dives into the floor, the -X end splits into two rootlets that dive into the floor.
ROOT_MAIN = ((-15.5, 7.4, 3.3, 2.0), (-11.5, 6.8, 4.0, 2.6), (-6.0, 3.0, 4.6, 2.9),
             (-0.5, 3.8, 4.9, 2.1), (4.5, 1.4, 4.8, 3.3), (9.0, -0.2, 4.3, 2.1), (13.5, -4.6, 3.1, 2.4),
             (16.5, -5.8, 2.4, 2.9), (20.0, -7.2, 1.3, 1.6), (23.2, -8.7, 0.3, 0.9))
ROOTLETS = (((-12.4, 7.2, 3.8, 0.7), (-19.4, 12.6, 1.9, 1.05), (-23.6, 15.0, 0.6, 0.72), (-26.0, 16.0, 0.15, 0.45)),
            ((-12.6, 6.9, 3.7, 0.7), (-20.0, 3.4, 1.7, 0.95), (-24.6, 2.1, 0.5, 0.62), (-27.2, 1.6, 0.1, 0.42)))
ROOT_CLEAR = 0.35                          # the moss is carved back this far round the root (a crease, no z-fight)
MOUND = dict(c=(0.0, -2.5, -3.6), r=(21.0, 17.0, 8.6), lumps=((-10.0, -9.0, 0.8, 6.0), (9.0, -7.0, 0.4, 5.0),
                                                              (-4.0, 8.0, 0.4, 5.5), (14.0, 6.0, 0.0, 4.5)))
# x, y, stem height, cap radius, cap height, stem radius, lean deg, cap segments, kind
# open: the big flattened cap with a slightly upturned rim; convex: a dome; notch: a dome with one chipped rim segment;
# egg: a small closed egg-shaped cap; button: a just-emerged button
# (2026-10-24: no cap tucks under another in the front, 3/4 or close views: the second-tallest convex moved from behind
# the open cap's stem out to +x / -y and lowered 3.5 cm, the notch cap lowered 3 cm and pulled 1.5 cm out to -x so it
# nests beside the open cap instead of stacking under its rim, the egg moved forward next to the button; the small
# convex took the old spot in the open cap's shadow)
MUSHROOMS = ((-3.0, -7.5, 20.0, 8.2, 4.4, 1.65, 7.0, 10, "open"),
             (15.5, 0.5, 10.5, 5.6, 4.0, 1.2, 12.0, 8, "convex"),
             (-17.0, -4.0, 8.0, 4.6, 3.4, 1.0, 15.0, 8, "notch"),
             (6.5, -13.5, 7.0, 2.9, 3.9, 0.78, 17.0, 7, "egg"),
             (-8.0, -15.0, 5.5, 2.6, 2.0, 0.62, 20.0, 7, "convex"),
             (7.0, 7.0, 4.6, 2.2, 1.8, 0.52, 22.0, 6, "convex"),
             (3.0, -16.0, 2.6, 1.9, 2.5, 0.5, 10.0, 6, "button"))
CLUSTER_CENTRE = np.array([0.0, -3.0])
WARTS = {"open": (9, 0.8, 1.2), "convex": (6, 0.6, 0.9), "notch": (5, 0.6, 0.85), "egg": (3, 0.5, 0.62),
         "button": (1, 0.5, 0.5)}
WART_SMALL = (2, 0.5, 0.6)                 # a convex cap under 3 cm radius


def base_primitives():
    def mound(x, y, z):
        d = sd_ellipsoid(x, y, z, MOUND["c"], MOUND["r"])
        for cx, cy, cz, r in MOUND["lumps"]:
            d = cg._smin(d, np.sqrt((x - cx) ** 2 + (y - cy) ** 2 + (z - cz) ** 2) - r, 2.5)
        return d - 0.55 * wave(x, y, z, 6101, 0.22, 4)
    return mound


def root_sdf(x, y, z, grow=0.0):
    """Round capsules over the root paths, inflated to enclose the jittered hex tube (+12 %) plus `grow` cm."""
    d = None
    for path in (ROOT_MAIN,) + ROOTLETS:
        for (ax, ay, az, ar), (bx, by, bz, br) in zip(path[:-1], path[1:]):
            e = sd_capsule(x, y, z, (ax, ay, az), (bx, by, bz), 1.12 * ar + grow, 1.12 * br + grow)
            d = e if d is None else np.minimum(d, e)
    return d


def build_base():
    mound = base_primitives()

    def fn(x, y, z):
        return np.maximum(np.maximum(mound(x, y, z), -root_sdf(x, y, z, ROOT_CLEAR)), -z)
    verts, tris, meta = mesh_from_field(fn, (-26.0, -24.0, -0.75), (26.0, 20.0, 9.0), 0.5, 380, floor=True)
    for _ in range(3):                                    # no up-facing sliver lying within 2 mm of the floor
        p = verts[tris]
        nz = tri_normals(verts, tris)[:, 2]
        flat = (p[:, :, 2].max(axis=1) < 0.25) & (nz > 0.85)
        if not flat.any():
            break
        ids = np.unique(tris[flat])
        lift = ids[verts[ids, 2] > 1e-3]
        verts[lift, 2] = np.maximum(verts[lift, 2], 0.35)
    return fn, mound, verts, tris, meta


def surface_z(fn, x, y, top=20.0):
    zs = np.arange(top, -0.05, -0.05)
    d = fn(np.full(len(zs), x), np.full(len(zs), y), zs)
    inside = np.nonzero(d < 0.0)[0]
    return float(zs[inside[0]]) if len(inside) else 0.0


def lathe_closed(profile, segments, phase_deg=0.0):
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


def lathe_rings(profile, segments, rng):
    """fc.lathe with the profile index of every vertex (poles included), each ring at its own random phase offset."""
    verts, faces, rings, ring_of = [], [], [], []
    for ri, (r, z) in enumerate(profile):
        if r < 1e-6:
            rings.append([len(verts)])
            verts.append((0.0, 0.0, z))
            ring_of.append(ri)
        else:
            start = len(verts)
            ph = rng.uniform(-0.12, 0.12) * TAU / segments
            for s in range(segments):
                a = TAU * s / segments + ph
                verts.append((r * math.cos(a), r * math.sin(a), z))
                ring_of.append(ri)
            rings.append(list(range(start, start + segments)))
    for a, b in zip(rings[:-1], rings[1:]):
        for s in range(segments):
            s2 = (s + 1) % segments
            if len(a) == 1:
                faces.append([a[0], b[s], b[s2]])
            elif len(b) == 1:
                faces.append([a[s], b[0], a[s2]])
            else:
                faces.append([a[s], b[s], b[s2], a[s2]])
    return np.array(verts, float), faces, np.array(ring_of)


def cap_profile(R, hc, kind):
    """(profile, band tags) for each cap kind; every cap gets its own shape."""
    if kind == "button":
        return [(0.0, hc), (0.55 * R, 0.9 * hc), (0.92 * R, 0.55 * hc), (0.98 * R, 0.22 * hc), (0.7 * R, 0.02 * hc),
                (0.0, 0.0)], ["cap", "cap", "cap", "rim", "gill"]
    if kind == "open":                                   # flattened, a low umbo, the rim turned slightly up
        return ([(0.0, 0.86 * hc), (0.3 * R, 0.8 * hc), (0.62 * R, 0.64 * hc), (0.86 * R, 0.42 * hc),
                 (1.0 * R, 0.48 * hc), (0.97 * R, 0.22 * hc), (0.66 * R, 0.13 * hc), (0.32 * R, 0.2 * hc),
                 (0.0, 0.24 * hc)], ["cap", "cap", "cap", "cap", "rim", "gill", "gill", "gill"])
    if kind == "egg":                                    # closed: the rim curls in toward the stem
        return ([(0.0, hc), (0.5 * R, 0.93 * hc), (0.86 * R, 0.68 * hc), (1.0 * R, 0.36 * hc), (0.88 * R, 0.1 * hc),
                 (0.58 * R, 0.0), (0.0, 0.05 * hc)], ["cap", "cap", "cap", "rim", "rim", "gill"])
    return ([(0.0, hc), (0.42 * R, 0.95 * hc), (0.74 * R, 0.76 * hc), (0.93 * R, 0.46 * hc), (1.0 * R, 0.17 * hc),
             (0.96 * R, 0.0), (0.62 * R, 0.07 * hc), (0.3 * R, 0.15 * hc), (0.0, 0.17 * hc)],
            ["cap", "cap", "cap", "cap", "rim", "gill", "gill", "gill"])


def wart_plate(centre, normal, rw, rng):
    """A flat five-sided wart plate: the base ring sunk 0.45 cm under the cap facet, an inset top face 2.5-3 mm above
    it (clear of the 2 mm rule), closed (16 tris)."""
    u, w, a = axis_frame(normal)
    ph = rng.uniform(0.0, TAU)
    top_h = rng.uniform(0.26, 0.3)
    base_c = np.asarray(centre, float) - a * 0.45
    top_c = np.asarray(centre, float) + a * top_h
    base, top = [], []
    for k in range(5):
        ang = ph + TAU * k / 5 + rng.uniform(-0.2, 0.2)
        d = math.cos(ang) * u + math.sin(ang) * w
        rr = rw * rng.uniform(0.82, 1.12)
        base.append(base_c + d * rr)
        top.append(top_c + d * rr * rng.uniform(0.62, 0.74))
    v = np.array(base + top)
    f = [[0, 2, 1], [0, 3, 2], [0, 4, 3], [5, 6, 7], [5, 7, 8], [5, 8, 9]]
    for k in range(5):
        k2 = (k + 1) % 5
        f += [[k, k2, 5 + k2], [k, 5 + k2, 5 + k]]
    return v, f, top_h


def root_tube(path, rng, twist_deg=22.0, sides=6):
    """A faceted bark root along a polyline (x, y, z, r): a 6-sided cross-section whose ridges twist along the length,
    radius jittered per vertex, pointed at both ends, never below the floor."""
    pts = np.array([p[:3] for p in path], float)
    rad = np.array([p[3] for p in path], float)
    rings = []
    prev_u = None
    for i in range(len(pts)):
        t = _n(pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)])
        if prev_u is None:
            u = _n(np.cross(t, [0.0, 0.0, 1.0]))
        else:
            u = _n(prev_u - t * float(prev_u @ t))
        prev_u = u
        w = np.cross(t, u)
        ph = math.radians(twist_deg) * i + rng.uniform(-0.1, 0.1)
        ring = []
        for k in range(sides):
            a = ph + TAU * k / sides
            rr = rad[i] * rng.uniform(0.88, 1.12)
            ring.append(pts[i] + rr * (math.cos(a) * u + math.sin(a) * w))
        rings.append(np.array(ring))
    for ring in rings:                                    # a ring never dips through the floor (no flattened facets)
        if ring[:, 2].min() < 0.05:
            ring[:, 2] += 0.05 - ring[:, 2].min()
    start = pts[0] - _n(pts[1] - pts[0]) * rad[0] * 0.7
    end = pts[-1] + _n(pts[-1] - pts[-2]) * rad[-1] * 0.7
    start[2], end[2] = max(start[2], 0.0), max(end[2], 0.0)   # the pointed ends dive to the floor
    verts = np.vstack([start[None]] + rings + [end[None]])
    faces = [[0, 1 + (k + 1) % sides, 1 + k] for k in range(sides)]
    for i in range(len(rings) - 1):
        a0, b0 = 1 + i * sides, 1 + (i + 1) * sides
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append([a0 + k, a0 + k2, b0 + k2, b0 + k])
    last, tip = 1 + (len(rings) - 1) * sides, len(verts) - 1
    faces += [[last + k, last + (k + 1) % sides, tip] for k in range(sides)]
    return verts, faces


def build_mushroom_cluster(name):
    rng = np.random.default_rng(6001)
    fn, mound, bverts, btris, meta = build_base()
    parts = Parts(("EnvCanvas", "EnvMoss", "EnvBark"))
    parts.add(bverts, btris.tolist(), "EnvMoss", "moss", part=0)
    main_v, main_f = root_tube(ROOT_MAIN, rng)
    parts.add(main_v, main_f, "EnvBark", "root", part=1)
    for pi, path in enumerate(ROOTLETS):
        for attempt in range(12):                         # a new twist / jitter until no facet runs along the main root
            rv, rf = root_tube(path, rng, twist_deg=22.0 + 7.0 * attempt)
            if not conflict(rv, rf, main_v, main_f):
                break
        parts.add(rv, rf, "EnvBark", "root", part=2 + pi)
    mound_bvh = BVHTree.FromPolygons(bverts.tolist(), btris.tolist(), all_triangles=True)
    btc = bverts[btris].mean(axis=1)

    def mound_clash(vv, ff, x, y, reach):
        """A face of the piece runs within 2.2 mm of, and parallel to, the moss (either way round)."""
        if near_parallel(mound_bvh, vv, ff):
            return True
        near = btris[(np.abs(btc[:, :2] - np.array([x, y])) < reach).all(axis=1)]
        pb = BVHTree.FromPolygons(np.asarray(vv).tolist(), tris_of(ff), all_triangles=True)
        return bool(len(near)) and near_parallel(pb, bverts, near.tolist())
    mush = []
    for mi, (x, y, H, R, hc, rs, lean, segs, kind) in enumerate(MUSHROOMS):
        pid = (mi + 1) * 100
        mid = float((mi + rng.uniform(0.2, 0.8)) / len(MUSHROOMS))
        zt = surface_z(fn, x, y)
        rstate = rng.bit_generator.state
        for extra in (0.0, 0.3, -0.3, 0.6, -0.6, 0.9, 1.2, 1.5, 1.8):   # sink / raise until stem and cap clear the moss
            rng.bit_generator.state = rstate
            bz = max(zt - 1.6 - extra, 0.95)              # the stem foot stays >= 3.5 mm off the floor
            surf = zt - bz                                   # the moss surface in stem coordinates
            out = np.array([x, y]) - CLUSTER_CENTRE
            e = _n([out[0], out[1], 0.0]) if np.linalg.norm(out) > 1e-3 else np.array([1.0, 0.0, 0.0])
            e = _n(rotate_about(e[None, :], [0, 0, 1], rng.uniform(-25.0, 25.0))[0])
            pside = np.cross([0.0, 0.0, 1.0], e)
            bend = H * math.tan(math.radians(lean)) * 0.55
            s_amp = rs * rng.uniform(0.25, 0.5) * min(1.0, H / 8.0)
            # stem: a bulb (1.6 x the radius) at the moss line, tapering up; an S-curve on top of the lean
            b = min(1.0, H / 9.0)
            sprof = [(0.0, -0.6), (1.2 * rs, -0.3), (1.6 * rs, surf - 0.25 * b), (1.35 * rs, surf + 0.9 * b),
                     (1.0 * rs, surf + 0.9 * b + 0.22 * (H - surf)), (0.86 * rs, 0.7 * H), (0.78 * rs, H - 0.15),
                     (0.0, H - 0.15)]
            for k in range(1, len(sprof)):
                if sprof[k][1] <= sprof[k - 1][1] + 0.1:
                    sprof[k] = (sprof[k][0], sprof[k - 1][1] + 0.1)
            if not all(z1 < z2 for (_, z1), (_, z2) in zip(sprof[:-1], sprof[1:])) or sprof[-1][1] > H:
                raise RuntimeError("stem profile not monotonic for mushroom %d" % mi)
            ssegs = 7 if kind == "open" else (6 if R > 4.0 else 5)
            sv, sf = fc.lathe(sprof, ssegs, twist_seed=int(rng.integers(1 << 30)), jitter=0.06 * rs)

            def stem_offset(zl):
                tz = np.clip(np.asarray(zl, float) / H, 0.0, 1.0)
                return np.outer(tz ** 2 * bend, e) + np.outer(s_amp * np.sin(TAU * tz), pside)
            base = np.array([x, y, bz])
            sv = sv + stem_offset(sv[:, 2]) + base
            top = base + np.array([0.0, 0.0, H]) + stem_offset([H])[0]
            axis = _n(np.array([0.0, 0.0, H]) + 2.0 * e * bend + rng.uniform(-0.05, 0.05, 3) * H)
            # cap: its own profile, rim / mid rings jittered +/- 10 % per vertex, tilted 6-12 deg off the stem axis
            prof, tags = cap_profile(R, hc, kind)
            cv, cf, ring_of = lathe_rings(prof, segs, rng)
            rad = np.hypot(cv[:, 0], cv[:, 1])
            big = rad >= 0.5 * R
            cv[big, :2] *= rng.uniform(0.9, 1.1, int(big.sum()))[:, None]
            cv[:, 2] += rng.uniform(-0.04, 0.04, len(cv)) * hc
            if kind == "notch":                              # one chipped rim segment
                s0 = int(rng.integers(segs))
                seg_of = np.round(np.arctan2(cv[:, 1], cv[:, 0]) / (TAU / segs)).astype(int) % segs
                for vi in range(len(cv)):
                    if seg_of[vi] == s0 and rad[vi] >= 0.7 * R:
                        cv[vi, :2] *= 0.68 if rad[vi] >= 0.9 * R else 0.88
                        cv[vi, 2] += 0.12 * hc
            gill_z = prof[-1][1]
            sink = 0.8 if kind != "button" else 0.6
            tdir = _n(np.cross(axis, rng.normal(size=3)))
            cap_axis = _n(rotate_about(axis[None, :], tdir, rng.uniform(6.0, 12.0))[0])
            phase = rng.uniform(0.0, 360.0)
            cap_c = top - axis * (gill_z + sink)
            cw = place_on_axis(cv, cap_c, cap_axis, phase)
            ctags = [tags[min(int(min(ring_of[i] for i in f)), len(tags) - 1)] for f in cf]
            cslots = [CAP_SLOT if t in ("cap", "rim") else "EnvCanvas" for t in ctags]
            if not (mound_clash(sv, sf, x, y, 3.5 * rs + 2.0) or mound_clash(cw, cf, x, y, R + 2.0)):
                break
        parts.add(sv, sf, "EnvCanvas", "stem", part=pid + 1)
        cap_part = parts.add(cw, cf, cslots, ctags, part=pid + 2)
        za = None
        if kind == "open":
            # annulus: a soft ring, a thin (0.4 cm) skirt flaring 1.2 cm out from the stem and drooping 1.5 cm, its
            # inner edge buried in the stem; eight segments, each drooping a little differently
            za = 0.75 * H
            nseg = 8
            rv, rf = lathe_closed([(0.55 * rs, za + 0.3), (rs + 0.45, za - 0.15), (rs + 1.2, za - 1.5),
                                   (rs + 1.02, za - 1.78), (rs + 0.2, za - 0.58), (0.55 * rs, za - 0.36)], nseg,
                                  phase_deg=rng.uniform(0.0, 45.0))
            droop = rng.uniform(0.85, 1.15, nseg)
            for k in range(nseg):
                for ring in (1, 2, 3, 4):
                    vi = ring * nseg + k
                    rv[vi, 2] = za - (za - rv[vi, 2]) * (droop[k] if ring in (2, 3) else 0.5 + 0.5 * droop[k])
                    if ring in (2, 3):
                        rv[vi, :2] *= rng.uniform(0.96, 1.04)
            rv = rv + stem_offset(np.full(len(rv), za)) + base
            parts.add(rv, rf, "EnvCanvas", "annulus", part=pid + 3)
        # warts: flat plates on the upper cap facets, denser toward the crown
        n_w, rlo, rhi = WARTS.get(kind, WARTS["convex"]) if not (kind == "convex" and R < 3.0) else WART_SMALL
        cand = []
        for fi, (face, tg) in enumerate(zip(cf, ctags)):
            if tg != "cap":
                continue
            p = cw[face]
            tri = p[[0, 1, 2]] if (len(p) == 3 or rng.uniform() < 0.5) else p[[0, 2, 3]]
            nrm = _n(np.cross(tri[1] - tri[0], tri[2] - tri[0]))
            if float(nrm @ (tri.mean(axis=0) - cap_c)) < 0:
                nrm = -nrm
            up = float(nrm @ cap_axis)
            if up > 0.5:
                cand.append((tri, nrm, up))
        cap_bvh = BVHTree.FromPolygons(cw.tolist(), tris_of(cf), all_triangles=True)
        weights = np.array([c[2] ** 3 for c in cand])
        order = rng.choice(len(cand), len(cand), replace=False, p=weights / weights.sum()) if cand else []
        placed = []
        for k in order:
            if len(placed) >= n_w:
                break
            tri, nrm, _ = cand[k]
            bc = rng.dirichlet((4.0, 4.0, 4.0))
            c = bc @ tri
            rw = rng.uniform(rlo, rhi)
            edge = min(np.linalg.norm(np.cross(tri[(i + 1) % 3] - tri[i], c - tri[i])) /
                       max(np.linalg.norm(tri[(i + 1) % 3] - tri[i]), 1e-9) for i in range(3))
            if edge < 0.35 * rw:
                continue
            if any(np.linalg.norm(c - q) < 1.15 * (rw + r2) for q, r2 in placed):
                continue
            wv, wf, _ = wart_plate(c, nrm, rw, rng)
            if near_parallel(cap_bvh, wv, wf):
                continue
            parts.add(wv, wf, "EnvCanvas", "wart", part=pid + 4 + len(placed))
            placed.append((c, rw))
        mush.append(dict(index=mi, kind=kind, id=mid, base=base.tolist(), top=top.tolist(), axis=cap_axis.tolist(),
                         H=H, annulus_z=za, cap_c=cap_c.tolist(), gill_r=R,
                         cap_radius=R, warts=len(placed), cap_part=cap_part,
                         cap_tilt_deg=round(math.degrees(math.acos(min(1.0, float(axis @ cap_axis)))), 1)))
    # re-number parts compactly: base and roots first (owner -1), then every sub part (owner = mushroom index)
    remap = {p: i for i, p in enumerate(sorted(set(parts.part)))}
    parts.part = [remap[p] for p in parts.part]
    owner = {}
    for m in mush:
        m["cap_part"] = remap[m["cap_part"]]
    for p_old, p_new in remap.items():
        owner[p_new] = -1 if p_old < 100 else (p_old // 100 - 1)
    v = parts.verts()
    lo_b, hi_b = v.min(axis=0), v.max(axis=0)
    shift = np.array([-(lo_b[0] + hi_b[0]) * 0.5, -(lo_b[1] + hi_b[1]) * 0.5, -lo_b[2]])
    parts.v = [x + shift for x in parts.v]
    obj = parts.build(name + "_Mars_SM", recalc=True)
    paint_mushrooms(obj, parts, owner, mush, shift, fn)
    meta.update(parts=parts, owner=owner, mushrooms=mush, shift=shift.tolist())
    return obj, meta


def paint_mushrooms(obj, parts, owner, mush, shift, fn):
    """Caps red (darker toward the rim and underside), cream gills darkening (A) toward the stem joint, stems cream at
    the top fading to a warm grey-ochre at the bulbed foot (+/- 6 % per facet), a cream annulus with a dark line under
    it, a bark root whose facets alternate two shades with lit upward ridges and dark crevices (A), moss base."""
    rng = np.random.default_rng(6002)
    cen, nrm = fc.face_centers_cm(obj), fc.face_normals(obj)
    red, red_d, warm = P("EnvCloth"), P("EnvClothDark"), P("EnvRustOrange")   # palette colours only
    cream = mix(P("EnvCanvas"), P("EnvBoneLight"), 0.6)
    gill = mix(P("EnvCanvas"), P("EnvBoneLight"), 0.35)
    foot = mix(P("EnvBoneDark"), P("EnvCanvas"), 0.35) * 0.8                # warm grey-ochre
    wart_c = mix(P("EnvBoneLight"), P("EnvWax"), 0.5)
    bark, bark_d = P("EnvBark"), P("EnvBarkDark")
    m_axis = {i: np.array(m["axis"]) for i, m in enumerate(mush)}
    tone = {i: rng.uniform(0.88, 1.12) for i in range(len(mush))}
    rgb = []
    for i, (tag, part) in enumerate(zip(parts.tag, parts.part)):
        c, n = cen[i], nrm[i]
        mi = owner[part]
        if tag == "moss":
            col = moss_colour(c, n, 6103, 5.0, soil_z=0.9)
        elif tag == "root":
            col = (bark if rng.uniform() < 0.55 else mix(bark, bark_d, 0.75)) * rng.uniform(0.94, 1.06)
            if n[2] > 0.5:
                col = col * (1.0 + 0.25 * float(smooth(0.5, 0.9, n[2])))   # lit upward ridges
            if c[2] < 1.2:
                col = mix(col, bark_d, 0.4)                     # where it dives into the floor
        elif tag == "cap":
            up = float(n @ m_axis[mi])
            col = mix(red_d, red, float(smooth(0.2, 0.85, up))) * tone[mi]
            col = mix(col, warm, 0.18 * float(smooth(0.6, 1.0, up)))
        elif tag == "rim":
            col = mix(red, P("EnvCanvas"), 0.3) * tone[mi]
        elif tag == "gill":
            col = gill * rng.uniform(0.95, 1.05)
        elif tag == "wart":
            col = wart_c * rng.uniform(0.92, 1.05)
        elif tag == "annulus":
            col = cream * (1.06 if n[2] > 0.0 else 0.9)
        else:                                                   # stem
            m = mush[mi]
            lz = c[2] - (m["base"][2] + shift[2])
            col = mix(foot, cream, float(smooth(0.05, 0.6, lz / m["H"]))) * rng.uniform(0.94, 1.06)
            if m["annulus_z"] is not None and m["annulus_z"] - 2.4 < lz < m["annulus_z"] - 0.3:
                col = col * 0.62                                # the shadow line under the annulus
        rgb.append(col)
    fs = lambda x, y, z: fn(x - shift[0], y - shift[1], z - shift[2])     # noqa: E731
    vv = fc.verts_cm(obj)
    vert_part = np.zeros(len(vv), np.int64)
    vert_tag = np.empty(len(vv), object)
    for f, pt, tg in zip(parts.f, parts.part, parts.tag):
        vert_part[f] = pt
        vert_tag[f] = tg
    ao = np.ones(len(vv))
    b = vert_part == 0
    ao[b] = field_ao(fs, vv[b], vertex_normals(obj)[b], extra=lambda q: q[:, 2] + 0.6)
    cav = fc.cavity(obj)
    alpha = np.clip(ao * (0.62 + 0.38 * np.clip(cav * 2.0, 0.0, 1.0)), 0.0, 1.0)
    alpha[~b] = np.clip(0.55 + 0.45 * np.clip(cav[~b] * 2.0, 0.0, 1.0), 0.0, 1.0)
    rt = vert_tag == "root"
    alpha[rt] = np.clip(0.4 + 0.6 * np.clip(cav[rt] * 2.0, 0.0, 1.0), 0.0, 1.0)        # dark crevices
    for mi_, m in enumerate(mush):                           # gills darken toward the stem joint
        a = np.array(m["axis"])
        cc = np.array(m["cap_c"]) + shift
        sel = (vert_tag == "gill") & np.array([owner[p_] == mi_ for p_ in vert_part])
        if sel.any():
            d = vv[sel] - cc
            r = np.linalg.norm(d - np.outer(d @ a, a), axis=1)
            alpha[sel] = np.minimum(alpha[sel], 0.35 + 0.65 * smooth(0.15 * m["gill_r"], 0.85 * m["gill_r"], r))
    fc.paint(obj, np.array(rgb), alpha=alpha, variation=0.05, seed=17, cavity_darken=0.3)
    fc.smart_uv(obj)
    ids = np.array([0.0 if owner[p] < 0 else mush[owner[p]]["id"] for p in parts.part])
    ec.write_data_uv(obj, ids, np.zeros(len(ids)), domain="FACE")


# ================================================================ checks
def tri_arrays(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    lt = mesh.loop_triangles
    tv = np.empty(len(lt) * 3, np.int64)
    lt.foreach_get("vertices", tv)
    tp = np.empty(len(lt), np.int64)
    lt.foreach_get("polygon_index", tp)
    return fc.verts_cm(obj), tv.reshape(-1, 3), tp


def tri_normals(v, t):
    cr = np.cross(v[t[:, 1]] - v[t[:, 0]], v[t[:, 2]] - v[t[:, 0]])
    return cr / np.maximum(np.linalg.norm(cr, axis=1, keepdims=True), 1e-12)


def components(n_verts, t):
    parent = list(range(n_verts))
    for tri in t.tolist():
        r0 = fc._uf_find(parent, tri[0])
        for q in tri[1:]:
            r = fc._uf_find(parent, q)
            if r != r0:
                parent[r] = r0
    return np.array([fc._uf_find(parent, int(tri[0])) for tri in t])


def coplanar_overlaps(v, t, tri_part, min_sep=0.2):
    """Faces of different parts lying within min_sep of each other, nearly parallel (the z-fighting the rule forbids)."""
    bvh = BVHTree.FromPolygons(v.tolist(), t.tolist(), all_triangles=True)
    nrm = tri_normals(v, t)
    bad = []
    for i, tri in enumerate(t):
        p = v[tri]
        c = p.mean(axis=0)
        n = nrm[i]
        hit_any = False
        for s in (c, 0.5 * (c + p[0]), 0.5 * (c + p[1]), 0.5 * (c + p[2])):
            for sgn in (1.0, -1.0):
                d = n * sgn
                loc, hn, idx, dist = bvh.ray_cast(tuple(s + d * 1e-4), tuple(d), min_sep)
                if idx is not None and tri_part[idx] != tri_part[i] and abs(float(np.dot(n, np.array(hn)))) > 0.9:
                    hit_any = (int(tri_part[i]), int(tri_part[idx]), round(float(dist), 3))
                    break
            if hit_any:
                break
        if hit_any:
            bad.append(hit_any)
    return bad


def part_intersections(v, t, tri_part, allowed=None):
    bvh = BVHTree.FromPolygons(v.tolist(), t.tolist(), all_triangles=True)
    pairs = set()
    for i, j in bvh.overlap(bvh):
        a, b = tri_part[i], tri_part[j]
        if a != b and (allowed is None or not allowed(a, b)):
            pairs.add((min(a, b), max(a, b)))
    return pairs


def floating_parts(v, t, tri_part, grounded_fn, touch=1.0):
    """Parts not connected (by contact within `touch` cm or by interpenetration) to a grounded part."""
    bvh = BVHTree.FromPolygons(v.tolist(), t.tolist(), all_triangles=True)
    n_parts = int(tri_part.max()) + 1
    parent = list(range(n_parts))

    def union(a, b):
        ra, rb = fc._uf_find(parent, a), fc._uf_find(parent, b)
        if ra != rb:
            parent[ra] = rb
    vert_part = np.full(len(v), -1, np.int64)
    for tri, pt in zip(t, tri_part):
        vert_part[tri] = pt
    for tri, pv in zip(t, tri_part):
        for co in tri_samples(v, [tri], 0.5):
            for hit in bvh.find_nearest_range(tuple(co), touch):
                q = tri_part[hit[2]]
                if q != pv:
                    union(int(pv), int(q))
    for i, j in bvh.overlap(bvh):
        if tri_part[i] != tri_part[j]:
            union(int(tri_part[i]), int(tri_part[j]))
    grounded = {fc._uf_find(parent, p) for p in range(n_parts) if grounded_fn(v[vert_part == p])}
    return [p for p in range(n_parts) if (vert_part == p).any() and fc._uf_find(parent, p) not in grounded]


def style_checks(name, info, v, stats):
    """The art-direction rules of the 2026-10-20 review that can be measured: flat readable leaves, the leaf mix, tilt
    caps, pile coverage from the player's view, the scatter height; thin clumped drape strands; feathered pads; cap
    tilt and wart plates."""
    out = []
    if "leaves" in info:
        lv = info["leaves"]
        off = max(x["centre_off"] for x in lv if not x["curl"])
        off_c = max([x["centre_off"] for x in lv if x["curl"]] + [0.0])
        proj = min(x["proj"] for x in lv)
        kites = [x for x in lv if x["kind"] == 4]
        stats.update(leaves=len(lv), leaf_centre_off_max=round(off, 4), curled_centre_off_max=round(off_c, 4),
                     leaf_proj_min=round(proj, 4), five_lobed=round(sum(x["kind"] == LEAF5 for x in lv) / len(lv), 3),
                     curled=round(sum(1 for x in lv if x["curl"]) / len(lv), 3),
                     kites=round(len(kites) / len(lv), 3), out_cm_max=round(max(x["out_cm"] for x in lv), 2))
        if off > LEAF_CENTRE_TOL:
            out.append("a leaf's fan centre sits %.3f x length off its rim plane (> %.2f)" % (off, LEAF_CENTRE_TOL))
        if off_c > CURL_CENTRE_TOL:
            out.append("a curled leaf's centre sits %.3f x length off its rim plane (> %.2f)" % (off_c, CURL_CENTRE_TOL))
        if not 0.12 <= stats["curled"] <= 0.3:
            out.append("curled share %.2f (want ~0.2)" % stats["curled"])
        if len(kites) > KITE_MAX_FRAC * len(lv) or any(x["role"] not in ("pile", "crescent") for x in kites):
            out.append("kites %d (%s) > %.0f %% or outside the buried fill" % (
                len(kites), sorted({x["role"] for x in kites}), 100 * KITE_MAX_FRAC))
        if stats["out_cm_max"] > SPILL_OUT_CM + 0.05:
            out.append("a leaf reaches %.1f cm past the heap outline (> %.0f)" % (stats["out_cm_max"], SPILL_OUT_CM))
        if proj < LEAF_PROJ_MIN:
            out.append("a leaf keeps only %.2f of its area in projection (< %.2f)" % (proj, LEAF_PROJ_MIN))
        kites = [x["length"] for x in lv if x["kind"] == 4]
        if kites and (min(kites) < KITE_LEN[0] - 0.01 or max(kites) > KITE_LEN[1] + 0.01):
            out.append("4-tri kites outside the %s cm filler range" % (KITE_LEN,))
        steep = [(x["role"], x["tilt"]) for x in lv if x["max_tilt"] is not None and x["tilt"] > x["max_tilt"] + 0.5]
        if steep:
            out.append("%d leaves tilt past their cap: %s" % (len(steep), steep[:4]))
        by_role = {}
        for x in lv:
            by_role[x["role"]] = max(by_role.get(x["role"], 0.0), x["tilt"])
        stats["max_tilt_by_role"] = {k: round(t, 1) for k, t in by_role.items()}
        if name.startswith("DeadLeaves_Pile"):
            if stats["five_lobed"] < 0.5:
                out.append("five-lobed leaves %.2f < 0.5" % stats["five_lobed"])
            stats["view_uncovered"] = info["view_uncovered"]
            if max(info["view_uncovered"]) > info["view_uncovered_max"]:
                out.append("the core shows from the player's view: %s (> %.3f)" % (info["view_uncovered"],
                                                                                    info["view_uncovered_max"]))
        else:
            if float(v[:, 2].max()) > 3.0 + 1e-3:
                out.append("scatter height %.2f > 3 cm" % float(v[:, 2].max()))
    if name == "MossDrape_A":
        n = info["strands"]
        stats.update(strands=n, leaders=info["leaders"], clumps=info["clumps"], tufts=info["tufts"],
                     root_w_cm=info["root_w_cm"], tip_w_cm=info["tip_w_cm"], kinked=info["kinked"],
                     leader_lengths_cm=[info["leader_lengths_cm"][0], info["leader_lengths_cm"][-1]],
                     follower_lengths_cm=info["follower_lengths_cm"], mat_tris=info["mat_tris"])
        lo_n, hi_n = DRAPE["strands"]
        if not lo_n <= n <= hi_n:
            out.append("%d strands (want %d-%d)" % (n, lo_n, hi_n))
        if not DRAPE["clumps"][0] <= info["clumps"] <= DRAPE["clumps"][1]:
            out.append("%d clumps" % info["clumps"])
        ll, fl = info["leader_lengths_cm"], info["follower_lengths_cm"]
        if ll[0] < DRAPE["leader_len"][0] - 0.1 or ll[-1] > DRAPE["leader_len"][1] + 0.1:
            out.append("leader lengths %s outside %s" % (ll, DRAPE["leader_len"]))
        if fl[0] < DRAPE["follower_len"][0] - 0.1 or fl[1] > DRAPE["follower_len"][1] + 0.1:
            out.append("follower lengths %s outside %s" % (fl, DRAPE["follower_len"]))
        if info["root_w_cm"][0] < 1.0 - 1e-6 or info["root_w_cm"][1] > 1.5 + 1e-6:
            out.append("strand root width %s outside 1.0-1.5 cm" % info["root_w_cm"])
        if info["tip_w_cm"][0] < 0.2 - 1e-6 or info["tip_w_cm"][1] > 0.3 + 1e-6:
            out.append("strand tip width %s outside 0.2-0.3 cm" % info["tip_w_cm"])
    if name.startswith("MossPad"):
        stats.update(rim_cm=info["rim_cm"], peak_cm=info["peak_cm"], hummocks=info["hummocks"])
        if info["rim_cm"][1] > 0.5:
            out.append("rim %.2f cm thick (max 0.5)" % info["rim_cm"][1])
        if not 4 <= info["hummocks"] <= 6 and name == "MossPad_A":
            out.append("%d hummocks (want 4-6)" % info["hummocks"])
        stats["hummock_peaks_cm"] = info["hummock_peaks_cm"]
        if name == "MossPad_B":
            stats["lip_depth_cm"] = info["lip_depth_cm"]
            if sum(1 for x in info["hummock_peaks_cm"] if x >= 3.5) < 2:
                out.append("fewer than two hummocks >= 3.5 cm")
        peak_max = PADS[name]["peak"][1] + 0.3
        if info["peak_cm"] > peak_max:
            out.append("peak %.2f cm > %.1f" % (info["peak_cm"], peak_max))
    if name == "Mushroom_Cluster_A":
        tilts = [m_["cap_tilt_deg"] for m_ in info["mushrooms"]]
        stats["cap_tilt_deg"] = tilts
        if min(tilts) < 5.5 or max(tilts) > 12.5:
            out.append("cap tilt %s outside 6-12 deg" % tilts)
        if sum(m_["warts"] for m_ in info["mushrooms"]) < 15:
            out.append("too few wart plates")
    return out


def check_mesh(name, obj, info, fails):
    """Every contract rule this builder can measure headless; appends 'name: problem' strings to fails."""
    m = MESHES[name]
    mesh = obj.data
    out = []
    if obj.name != name + "_Mars_SM":
        out.append("object name %s" % obj.name)
    slots = tuple(mt.name for mt in mesh.materials)
    if slots != m["slots"] or any(s not in FAMILY_SLOTS or s not in spec.SLOTS for s in slots):
        out.append("slots %s != %s (family %s)" % (slots, m["slots"], FAMILY_SLOTS))
    used = {p.material_index for p in mesh.polygons}
    if used != set(range(len(slots))):
        out.append("a slot has no faces (%s)" % sorted(used))
    tris = fc.tri_count(obj)
    budget = spec.TRIS[m["cat"]]
    if tris > budget:
        out.append("tris %d > %s budget %d" % (tris, m["cat"], budget))
    if any(p.use_smooth for p in mesh.polygons) or not fc._is_flat(mesh):
        out.append("not flat shaded")
    attr = mesh.color_attributes.get("Col")
    if attr is None or attr.domain != "CORNER":
        out.append("no corner Col attribute")
    else:
        c = np.empty(len(attr.data) * 4, np.float32)
        attr.data.foreach_get("color", c)
        c = c.reshape(-1, 4)
        if not np.all(np.isfinite(c)) or c[:, 3].min() < 0.0 or c[:, 3].max() > 1.0:
            out.append("Col alpha outside 0..1")
        if np.all(c[:, :3] > 0.98):
            out.append("Col all white")
        if c[:, 3].max() - c[:, 3].min() < 0.05:
            out.append("Col alpha carries no cavity")
    uvs = [u.name for u in mesh.uv_layers]
    want = ["UVMap", spec.DATA_UV] if m["data_uv"] else ["UVMap"]
    if uvs != want:
        out.append("uv layers %s != %s" % (uvs, want))
    elif m["data_uv"]:
        u = np.empty(len(mesh.loops) * 2)
        mesh.uv_layers[spec.DATA_UV].data.foreach_get("uv", u)
        u = u.reshape(-1, 2)
        if u[:, 0].min() < 0.0 or u[:, 0].max() > 1.0 or (1.0 - u[:, 1]).min() < -1e-6 or (1.0 - u[:, 1]).max() > 1.0 + 1e-6:
            out.append("EnvData outside 0..1")
        if name.startswith("DeadLeaves") and np.abs(1.0 - u[:, 1]).max() > 1e-6:
            out.append("leaf EnvData v must be 0")
    if sc.children(obj, "UCX_") or sc.children(obj, "SOCKET_"):
        out.append("organic dressing carries no UCX / sockets")
    # pivot + size
    v, t, tp = tri_arrays(obj)
    lo, hi = v.min(axis=0), v.max(axis=0)
    size = hi - lo
    if m["pivot"] == "floor":
        if abs(lo[0] + hi[0]) > 0.1 or abs(lo[1] + hi[1]) > 0.1 or abs(lo[2]) > 1e-3:
            out.append("floor pivot off: bounds %s .. %s" % (lo.round(2), hi.round(2)))
    elif m["pivot"] == "wall":
        if abs(hi[1]) > 1e-3 or abs(lo[0] + hi[0]) > 0.1 or abs(lo[2]) > 1e-3:
            out.append("wall pivot off (back y 0, x centred, z 0): bounds %s .. %s" % (lo.round(2), hi.round(2)))
    elif m["pivot"] == "edge":
        pen = m["pen"]
        if abs(lo[0] + hi[0]) > 0.1:
            out.append("not centred on x")
        smp = tri_samples(v, t, 0.6)
        inside = (smp[:, 1] > 0.0) & (smp[:, 2] < 0.0)
        depth = np.minimum(smp[inside, 1], -smp[inside, 2]) if inside.any() else np.zeros(1)
        allow = (pen + DRAPE["round"] * (1.0 - 1.0 / math.sqrt(2.0)) + 0.1) if pen > 0 else 0.03
        info["stone_depth_cm"] = round(float(depth.max()), 3)
        if depth.max() > allow:
            out.append("sinks %.2f cm into the ledge stone (> %.2f)" % (depth.max(), allow))
        if not ((np.abs(v[:, 2] + pen) < 1e-3) & (v[:, 1] > 2.0)).any():
            out.append("does not rest on the ledge top")
        if not ((np.abs(v[:, 1] - pen) < 1e-3) & (v[:, 2] < -2.0)).any():
            out.append("does not lie on the ledge face")
    want_size = np.array(m["size"], float)
    off = np.abs(size - want_size) / want_size
    if off.max() > SIZE_TOL:
        out.append("size %s vs intended %s" % (size.round(1), want_size))
    # normals
    tri_part = np.array(json.loads(obj["_parts"]))[tp] if "_parts" in obj else np.zeros(len(t), np.int64)
    nrm = tri_normals(v, t)
    if m["closed"]:
        comp = components(len(v), t)
        for cid in np.unique(comp):
            sel = t[comp == cid]
            vol = float(np.einsum("ij,ij->i", v[sel[:, 0]], np.cross(v[sel[:, 1]], v[sel[:, 2]])).sum() / 6.0)
            if vol <= 0.0:
                out.append("component %d inverted (volume %.2f)" % (cid, vol))
                break
        e = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
        _, cnt = np.unique(np.sort(e, axis=1), axis=0, return_counts=True)
        if (cnt != 2).sum():
            out.append("not closed: %d open / non-manifold edges" % int((cnt != 2).sum()))
    else:
        leaf_n = {lf["part"]: np.array(lf["normal"]) for lf in info["leaves"]}
        bad = 0
        for i, pt in enumerate(tri_part):
            if pt in leaf_n:
                if float(nrm[i] @ leaf_n[pt]) <= 0.0 or leaf_n[pt][2] < 0.15:
                    bad += 1
            elif nrm[i][2] <= 0.0:                    # the core winds up
                bad += 1
        if bad:
            out.append("%d faces wound against their visible side" % bad)
    # floor / wall / ledge coplanarity (z-fighting with the kit surfaces the prop sits on)
    cz = v[t].max(axis=1)[:, 2]
    if m["pivot"] in ("floor", "wall"):
        flat_floor = int(((cz < 0.2) & (nrm[:, 2] > 0.9)).sum())
        if flat_floor:
            out.append("%d faces coplanar with the floor (within 2 mm, facing up)" % flat_floor)
    if m["pivot"] == "wall":
        cy = v[t].min(axis=1)[:, 1]
        flat_wall = int(((cy > -0.2) & (nrm[:, 1] < -0.9)).sum())
        if flat_wall:
            out.append("%d faces coplanar with the wall" % flat_wall)
    if m["pivot"] == "edge":
        tz, ty = v[t][:, :, 2], v[t][:, :, 1]
        top_flat = ((np.abs(tz).max(axis=1) < 0.2) & (nrm[:, 2] > 0.9) & (ty.min(axis=1) > 0.2)).sum()
        face_flat = ((np.abs(ty).max(axis=1) < 0.2) & (nrm[:, 1] < -0.9) & (tz.max(axis=1) < -0.2)).sum()
        if top_flat + face_flat:
            out.append("%d faces coplanar with the ledge" % int(top_flat + face_flat))
    # sub-part z-fighting, interpenetration, floating
    n_parts = int(tri_part.max()) + 1
    stats = {}
    if n_parts > 1:
        cop = coplanar_overlaps(v, t, tri_part)
        stats["coplanar_overlaps"] = len(cop)
        if cop:
            tag_of = {}
            if info.get("parts") is not None:
                for tg, pt in zip(info["parts"].tag, info["parts"].part):
                    tag_of.setdefault(pt, tg)
            out.append("%d faces z-fight another part (< 2 mm, parallel): %s" % (
                len(cop), [(tag_of.get(a, a), tag_of.get(b, b), d) for a, b, d in cop[:6]]))
        if name.startswith("DeadLeaves"):
            pairs = part_intersections(v, t, tri_part)
        else:
            own = info["owner"]
            pairs = part_intersections(v, t, tri_part, allowed=lambda a, b: own[a] == own[b] or -1 in (own[a], own[b]))
        stats["intersecting_part_pairs"] = len(pairs)
        if pairs:
            out.append("%d part pairs interpenetrate: %s" % (len(pairs), sorted(pairs)[:6]))
        if m["pivot"] == "edge":
            grounded = lambda pv: len(pv) and (pv[:, 1] > 1.0).any()        # noqa: E731  (lies on the ledge top)
        else:
            grounded = lambda pv: len(pv) and pv[:, 2].min() < 0.05         # noqa: E731
        floating = floating_parts(v, t, tri_part, grounded, touch=0.6 if name.startswith("DeadLeaves") else 0.3)
        stats["floating_parts"] = len(floating)
        if floating:
            out.append("%d floating parts %s" % (len(floating), floating[:8]))
    else:
        comp = components(len(v), t)
        stats["components"] = int(len(np.unique(comp)))
        if stats["components"] != 1:
            out.append("%d components (want 1)" % stats["components"])
    out += style_checks(name, info, v, stats)
    info["checks"] = stats
    info["size_cm"] = size.round(2).tolist()
    info["bounds_cm"] = [lo.round(2).tolist(), hi.round(2).tolist()]
    for o in out:
        fails.append("%s: %s" % (name, o))
    print("CHECK %-22s tris %4d/%d size %s %s -> %s" % (name, tris, budget, size.round(1), json.dumps(stats),
                                                         "ok" if not out else "FAIL " + "; ".join(out)))
    return not out


# ================================================================ review renders
def remove_object(o):
    data = o.data
    bpy.data.objects.remove(o, do_unlink=True)
    if data is not None and data.users == 0:
        if isinstance(data, bpy.types.Mesh):
            bpy.data.meshes.remove(data)


def review_copy(obj, centre_xy=True):
    c = bpy.data.objects.new(obj.name.replace("_Mars_SM", "") + "_Review", obj.data.copy())
    bpy.context.scene.collection.objects.link(c)
    v = fc.verts_cm(c)
    lo, hi = v.min(axis=0), v.max(axis=0)
    ext = float((hi - lo).max())
    shift = np.array([(lo[0] + hi[0]) * 0.5 if centre_xy else 0.0, (lo[1] + hi[1]) * 0.5 if centre_xy else 0.0,
                      (lo[2] + hi[2]) * 0.5 - 0.45 * ext])
    fc.set_verts_cm(c, v - shift)
    return c


def placed_copy(obj, offset=(0.0, 0.0, 0.0), yaw=0.0):
    c = bpy.data.objects.new(obj.name.replace("_Mars_SM", "") + "_Ctx", obj.data.copy())
    bpy.context.scene.collection.objects.link(c)
    v = fc.verts_cm(c)
    if yaw:
        a = math.radians(yaw)
        r = np.array([[math.cos(a), -math.sin(a), 0.0], [math.sin(a), math.cos(a), 0.0], [0.0, 0.0, 1.0]])
        v = v @ r.T
    fc.set_verts_cm(c, v + np.asarray(offset, float))
    return c


def painted_box(name, center, size, rgb):
    v, f = sc.box(center, size)
    o = ec.new_object(name, v, f, slots=("EnvStone",))
    fc.paint(o, np.repeat(np.asarray(rgb, float)[None, :], len(f), axis=0), variation=0.02, cavity_darken=0.0)
    return o


def render_view(objs, path, size=(1600, 1000), target_cm=(0, 0, 0), eye_cm=(0, -300, 100), lens=35.0, shadows=True):
    """One perspective workbench render of objs in place (every other mesh hidden)."""
    scene = bpy.context.scene
    objs = list(objs)
    hidden = [o for o in scene.objects if o not in objs and o.type == "MESH"]
    hidden_state = [o.hide_render for o in hidden]
    cam_data = bpy.data.cameras.new("_OrgCam")
    cam_data.clip_start, cam_data.clip_end = 0.02, 2000.0
    cam = bpy.data.objects.new("_OrgCam", cam_data)
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
        cam_data.lens = lens
        fc._look_at(cam, tuple(np.asarray(eye_cm, float) * 0.01), tuple(np.asarray(target_cm, float) * 0.01))
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


CHEF_FBX = r"D:\Repo\Content\Characters\FPHands\MiniChef\SK_Chef.fbx"
CHEF_HEIGHT = 150.0


def load_chef():
    """The MiniChef (SK_Chef.fbx) frozen in its bind pose as one static review mesh, 1.5 m tall, feet on z 0, facing
    Blender -y; a 1.5 m capsule with a head stands in when the FBX is missing."""
    rgb = fc.srgb(226, 222, 210)
    if os.path.exists(CHEF_FBX):
        before = set(bpy.data.objects)
        before_mesh, before_mat, before_arm = set(bpy.data.meshes), set(bpy.data.materials), set(bpy.data.armatures)
        try:
            bpy.ops.import_scene.fbx(filepath=CHEF_FBX)
            new = [o for o in bpy.data.objects if o not in before]
            dg = bpy.context.evaluated_depsgraph_get()
            vs, fs, base = [], [], 0
            for o in new:
                if o.type != "MESH":
                    continue
                me = o.evaluated_get(dg).to_mesh()
                co = np.empty(len(me.vertices) * 3)
                me.vertices.foreach_get("co", co)
                co = co.reshape(-1, 3)
                M = np.array(o.matrix_world)
                co = co @ M[:3, :3].T + M[:3, 3]
                vs.append(co * 100.0)
                fs.extend([[base + i for i in p.vertices] for p in me.polygons])
                base += len(co)
                o.evaluated_get(dg).to_mesh_clear()
        finally:
            for o in [o for o in bpy.data.objects if o not in before]:
                bpy.data.objects.remove(o, do_unlink=True)
            for m in [m for m in bpy.data.meshes if m not in before_mesh]:
                bpy.data.meshes.remove(m)
            for a in [a for a in bpy.data.armatures if a not in before_arm]:
                bpy.data.armatures.remove(a)
            for m in [m for m in bpy.data.materials if m not in before_mat]:
                bpy.data.materials.remove(m)
        if vs:
            v = np.concatenate(vs)
            lo, hi = v.min(axis=0), v.max(axis=0)
            v = (v - np.array([(lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, lo[2]])) * (CHEF_HEIGHT / (hi[2] - lo[2]))
            o = ec.new_object("_Chef", v, fs, slots=("EnvCanvas",), recalc_normals=False)
            fc.paint(o, np.repeat(np.asarray(rgb)[None, :], len(o.data.polygons), axis=0), alpha=np.ones(len(v)),
                     variation=0.0, cavity_darken=0.0)
            return o
    body_v, body_f = fc.lathe([(0.0, 0.0), (20.0, 4.0), (22.0, 50.0), (18.0, 100.0), (0.0, 108.0)], 10)
    head_v, head_f = fc.icosphere(21.0, 2)
    v, f, _ = fc.merge([(body_v, body_f, 0), (head_v + np.array([0.0, 0.0, 128.0]), head_f, 0)])
    o = ec.new_object("_Chef", v, f, slots=("EnvCanvas",))
    fc.paint(o, np.repeat(np.asarray(rgb)[None, :], len(o.data.polygons), axis=0), variation=0.0, cavity_darken=0.0)
    return o


def chef_at(chef, offset, yaw=0.0):
    return placed_copy(chef, offset, yaw) if chef is not None else None


def _engine_eevee():
    items = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    for name in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        if name in items:
            return name
    return None


def vc_material():
    mt = bpy.data.materials.get("_OrgVC") or bpy.data.materials.new("_OrgVC")
    mt.use_nodes = True
    nt = mt.node_tree
    nt.nodes.clear()
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.85
    outn = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], outn.inputs["Surface"])
    return mt


def render_far(objs, path, eye_cm, target_cm, lights, size=(1600, 1000), lens=35.0):
    """A dim, warm, lit render at gameplay distance (EEVEE, vertex colour through a temporary material, point lights
    like concept 6); workbench if EEVEE is not available headless."""
    scene = bpy.context.scene
    engine = _engine_eevee()
    if engine is None:
        return render_view(objs, path, size=size, target_cm=target_cm, eye_cm=eye_cm, lens=lens)
    mt = vc_material()
    saved_mats = []
    for o in objs:
        saved_mats.append([s for s in o.data.materials])
        for i in range(len(o.data.materials)):
            o.data.materials[i] = mt
    lamps = []
    for k, (loc, rgb, watts, radius) in enumerate(lights):
        ld = bpy.data.lights.new("_OrgLamp%d" % k, "POINT")
        ld.energy, ld.color, ld.shadow_soft_size = watts, rgb, radius
        lo = bpy.data.objects.new("_OrgLamp%d" % k, ld)
        lo.location = tuple(np.asarray(loc, float) * 0.01)
        scene.collection.objects.link(lo)
        lamps.append((lo, ld))
    hidden = [o for o in scene.objects if o not in objs and o.type == "MESH"]
    hidden_state = [o.hide_render for o in hidden]
    cam_data = bpy.data.cameras.new("_OrgFarCam")
    cam_data.clip_start, cam_data.clip_end = 0.05, 200.0
    cam = bpy.data.objects.new("_OrgFarCam", cam_data)
    scene.collection.objects.link(cam)
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.filepath, tuple(scene.world.color), scene.render.film_transparent,
            scene.view_settings.view_transform)
    bg = scene.world.node_tree.nodes.get("Background") if scene.world.node_tree else None
    bg_prev = (tuple(bg.inputs[0].default_value), bg.inputs[1].default_value) if bg else None
    try:
        for o in hidden:
            o.hide_render = True
        for o in objs:
            o.hide_render = False
        scene.world.color = (0.004, 0.0045, 0.006)
        if bg:
            bg.inputs[0].default_value = (0.004, 0.0045, 0.006, 1.0)
            bg.inputs[1].default_value = 1.0
        scene.render.engine = engine
        scene.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in bpy.types.ColorManagedViewSettings.bl_rna.properties["view_transform"].enum_items] else "Standard"
        try:
            scene.eevee.taa_render_samples = 32
        except AttributeError:
            pass
        scene.render.film_transparent = False
        scene.camera = cam
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        cam_data.lens = lens
        fc._look_at(cam, tuple(np.asarray(eye_cm, float) * 0.01), tuple(np.asarray(target_cm, float) * 0.01))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
    except Exception as exc:                                  # no GPU context headless: fall back to workbench
        print("  EEVEE far render failed (%s); workbench instead" % exc)
        scene.render.engine = prev[1]
        return render_view(objs, path, size=size, target_cm=target_cm, eye_cm=eye_cm, lens=lens)
    finally:
        for o, hr in zip(hidden, hidden_state):
            o.hide_render = hr
        for o, mats in zip(objs, saved_mats):
            for i, m in enumerate(mats):
                o.data.materials[i] = m
        for lo, ld in lamps:
            bpy.data.objects.remove(lo)
            bpy.data.lights.remove(ld)
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
         scene.render.filepath) = prev[:5]
        scene.world.color = prev[5]
        scene.render.film_transparent = prev[6]
        scene.view_settings.view_transform = prev[7]
        if bg:
            bg.inputs[0].default_value, bg.inputs[1].default_value = bg_prev
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return path


def render_sheets(built):
    rd = spec.REVIEW_DIR
    sheets = []
    sh = bpy.context.scene.display.shading
    spec_prev = sh.show_specular_highlight
    sh.show_specular_highlight = False                       # studio specular read as grey-blue chips on the moss
    groups = (("organic_leaves", ("DeadLeaves_Pile_A", "DeadLeaves_Pile_B", "DeadLeaves_Scatter_A")),
              ("organic_moss", ("MossPad_A", "MossPad_B", "MossDrape_A")),
              ("organic_mushroom", ("Mushroom_Cluster_A",)))
    try:
        for stem, names in groups:
            objs = [built[n][0] for n in names if n in built]
            if not objs:
                continue
            copies = [review_copy(o) for o in objs]
            sheets.append(ec.review(copies, stem))
            for c in copies:
                remove_object(c)
    finally:
        sh.show_specular_highlight = spec_prev
    stone, stone_d = fc.srgb(118, 112, 106), fc.srgb(92, 88, 84)
    chef = load_chef()
    shots = []
    have = lambda *ns: all(n in built for n in ns)                  # noqa: E731
    if have("DeadLeaves_Pile_A", "DeadLeaves_Pile_B", "DeadLeaves_Scatter_A"):
        tmp = [painted_box("_Wall", (0.0, 30.0, 150.0), (420.0, 60.0, 300.0), stone),
               painted_box("_Floor", (0.0, -120.0, -1.0), (420.0, 300.0, 2.0), stone_d),
               placed_copy(built["DeadLeaves_Pile_A"][0], (-30.0, 0.0, 0.0)),
               placed_copy(built["DeadLeaves_Pile_B"][0], (95.0, 0.0, 0.0)),
               placed_copy(built["DeadLeaves_Scatter_A"][0], (30.0, -115.0, 0.0), yaw=20.0)]
        c = chef_at(chef, (-150.0, -20.0, 0.0), yaw=10.0)
        shots.append(render_view(tmp + ([c] if c else []), os.path.join(rd, "organic_ctx_leaves.png"),
                                 target_cm=(10.0, -50.0, 30.0), eye_cm=(-170.0, -390.0, 150.0), lens=32.0))
        shots.append(render_view(tmp[:3], os.path.join(rd, "organic_close_pileA.png"),
                                 target_cm=(-30.0, -20.0, 8.0), eye_cm=(-95.0, -125.0, 60.0), lens=35.0))
        shots.append(render_view(tmp[:2] + tmp[4:5], os.path.join(rd, "organic_close_scatter.png"),
                                 target_cm=(30.0, -115.0, 0.0), eye_cm=(-40.0, -270.0, 75.0), lens=35.0))
        for o in tmp + ([c] if c else []):
            remove_object(o)
    if "MossDrape_A" in built:
        tmp = [painted_box("_Ledge", (0.0, 50.0, -60.0), (240.0, 100.0, 120.0), stone),
               painted_box("_Floor", (0.0, -100.0, -121.0), (300.0, 200.0, 2.0), stone_d),
               placed_copy(built["MossDrape_A"][0])]
        if "MossPad_B" in built:
            tmp.append(placed_copy(built["MossPad_B"][0], (88.0, 0.0, 0.0)))
        if "MossPad_A" in built:
            tmp.append(placed_copy(built["MossPad_A"][0], (-45.0, -60.0, -120.0), yaw=-15.0))
        if "Mushroom_Cluster_A" in built:
            tmp.append(placed_copy(built["Mushroom_Cluster_A"][0], (55.0, -55.0, -120.0), yaw=30.0))
        c = chef_at(chef, (-95.0, -75.0, -120.0), yaw=20.0)
        shots.append(render_view(tmp + ([c] if c else []), os.path.join(rd, "organic_ctx_ledge.png"),
                                 target_cm=(0.0, -10.0, -45.0), eye_cm=(-150.0, -300.0, 20.0), lens=32.0))
        shots.append(render_view(tmp[:3], os.path.join(rd, "organic_close_drape.png"), target_cm=(-10.0, -5.0, -20.0),
                                 eye_cm=(-75.0, -120.0, 15.0), lens=35.0))
        for o in tmp + ([c] if c else []):
            remove_object(o)
    if have("MossPad_A", "MossPad_B"):
        tmp = [painted_box("_Step", (0.0, 40.0, -20.0), (160.0, 80.0, 40.0), stone),
               painted_box("_Floor", (0.0, -60.0, -41.0), (200.0, 120.0, 2.0), stone_d),
               placed_copy(built["MossPad_B"][0], (-20.0, 0.0, 0.0)),
               placed_copy(built["MossPad_A"][0], (30.0, -45.0, -40.0), yaw=12.0)]
        shots.append(render_view(tmp, os.path.join(rd, "organic_close_pads.png"), target_cm=(5.0, -15.0, -20.0),
                                 eye_cm=(-55.0, -150.0, 45.0), lens=35.0))
        for o in tmp:
            remove_object(o)
    if "Mushroom_Cluster_A" in built:
        tmp = [painted_box("_Floor", (0.0, 0.0, -1.0), (200.0, 200.0, 2.0), stone_d),
               placed_copy(built["Mushroom_Cluster_A"][0])]
        shots.append(render_view(tmp, os.path.join(rd, "organic_close_mushroom.png"), target_cm=(0.0, 0.0, 10.0),
                                 eye_cm=(-45.0, -75.0, 42.0), lens=35.0))
        for o in tmp:
            remove_object(o)
    if len(built) == len(ORDER):
        # gameplay distance: everything on a kit floor, against a 3.5 m wall and on a 1.2 m ledge, ~10 m away, under a
        # dim warm candle light (concept 6)
        tmp = [painted_box("_Wall", (0.0, 30.0, 175.0), (1400.0, 60.0, 350.0), stone),
               painted_box("_Floor", (0.0, -500.0, -1.0), (1400.0, 1000.0, 2.0), stone_d),
               painted_box("_Ledge", (270.0, -50.0, 60.0), (240.0, 100.0, 120.0), stone),
               placed_copy(built["DeadLeaves_Pile_A"][0], (-260.0, 0.0, 0.0)),
               placed_copy(built["DeadLeaves_Pile_B"][0], (-90.0, 0.0, 0.0)),
               placed_copy(built["DeadLeaves_Scatter_A"][0], (-170.0, -190.0, 0.0), yaw=8.0),
               placed_copy(built["MossDrape_A"][0], (300.0, -100.0, 120.0)),
               placed_copy(built["MossPad_B"][0], (184.0, -100.0, 120.0)),
               placed_copy(built["MossPad_A"][0], (300.0, -160.0, 0.0), yaw=20.0),
               placed_copy(built["Mushroom_Cluster_A"][0], (40.0, -55.0, 0.0), yaw=-20.0)]
        c = chef_at(chef, (-120.0, -260.0, 0.0), yaw=15.0)
        objs = tmp + ([c] if c else [])
        lights = (((-60.0, -170.0, 170.0), (1.0, 0.6, 0.3), 260.0, 0.05),
                  ((260.0, -260.0, 230.0), (1.0, 0.66, 0.36), 180.0, 0.05),
                  ((0.0, -900.0, 400.0), (0.45, 0.55, 0.8), 120.0, 1.0))
        shots.append(render_far(objs, os.path.join(rd, "organic_far_10m.png"), eye_cm=(-180.0, -1060.0, 190.0),
                                target_cm=(20.0, -80.0, 50.0), lights=lights, lens=35.0))
        for o in objs:
            remove_object(o)
    if chef is not None:
        remove_object(chef)
    if shots:
        while len(shots) % 2:
            shots.append(shots[-1])
        sheets.append(fc.tile_images(shots, os.path.join(rd, "organic_context_sheet.png"), cols=2))
    for mt in list(bpy.data.materials):
        if mt.users == 0:
            bpy.data.materials.remove(mt)
    return sheets + shots


# ================================================================ export / re-import
def sidecar_extra(name, info):
    m = MESHES[name]
    pivot = {"floor": "floor prop: XY centre of the footprint, z 0 on the floor",
             "wall": "wall-base prop: back plane at Blender y 0 (the heap leans on the wall), protrudes toward -y "
                     "(Unreal +Y), x centred, z 0 on the floor",
             "edge": ("the ledge edge: edge along X at y 0, z 0; ledge top = z 0 for y > 0, ledge face = y 0 for z < 0; "
                      "moss sinks 3 mm into the stone (rounded inner corner r 2.5 for chamfered kit edges)"
                      if m.get("pen", 0.0) > 0 else
                      "the step edge: edge along X at y 0, z 0; the pad lies on the tread (z 0 for y > 0) and its lip "
                      "folds 5-8 cm down the riser (y 0 for z < 0); the underside follows the stone exactly, x centred")
             }[m["pivot"]]
    extra = dict(category=m["cat"], tris_budget=spec.TRIS[m["cat"]], pivot=pivot, builder="build_env_organic.py",
                 ucx="none (organic dressing: no collision)", size_intended_cm=list(m["size"]))
    if m["data_uv"]:
        extra["data_uv"] = {
            "DeadLeaves_Pile_A": "EnvData u = per-leaf random id (core 0.5), v = 0",
            "DeadLeaves_Pile_B": "EnvData u = per-leaf random id (core 0.5), v = 0",
            "DeadLeaves_Scatter_A": "EnvData u = per-leaf random id, v = 0",
            "MossPad_A": "EnvData u = hummock id (per-clump tint), v = 0",
            "MossPad_B": "EnvData u = hummock id (per-clump tint), v = 0",
            "MossDrape_A": "EnvData u = strand id (each column of moss follows its strand), v = flex 0 at the ledge -> "
                           "1 at the strand tip",
            "Mushroom_Cluster_A": "EnvData u = per-mushroom id (base 0), v = 0",
        }[name]
    if "leaves" in info:
        lv = info["leaves"]
        extra.update(leaves=len(lv), leaves_by_kind={k: sum(1 for x in lv if x["kind"] == k) for k in (4, 6, LEAF5)},
                     leaves_curled=sum(1 for x in lv if x["curl"]),
                     leaves_upside_down=sum(1 for x in lv if x["flipped"]),
                     core_uncovered_fraction=info["core_uncovered"], core_tris=info["core_tris"])
    if "mushrooms" in info:
        extra.update(mushrooms=[{k: (round(v, 3) if isinstance(v, float) else v) for k, v in mm.items()
                                 if k in ("kind", "id", "cap_radius", "warts")} for mm in info["mushrooms"]])
    if "strands" in info:
        extra.update(strands=info["strands"])
    extra["checks"] = info.get("checks", {})
    return extra


def reimport(path, name, fails):
    before = set(bpy.data.objects)
    rep = fc.reimport_check(path)
    for o in [o for o in bpy.data.objects if o not in before]:
        bpy.data.objects.remove(o, do_unlink=True)
    for mesh in [m for m in bpy.data.meshes if m.users == 0]:
        bpy.data.meshes.remove(mesh)
    with open(os.path.splitext(path)[0] + ".json") as fh:
        meta = json.load(fh)
    m = MESHES[name]
    want_uv = ["UVMap", spec.DATA_UV] if m["data_uv"] else ["UVMap"]
    problems = []
    meshes = [r for r in rep if not r["name"].startswith("UCX_")]
    if len(meshes) != 1 or len(rep) != 1:
        problems.append("objects %s" % [r["name"] for r in rep])
    for r in meshes:
        if r["uv_layers"] != want_uv:
            problems.append("uv %s" % r["uv_layers"])
        if "Col" not in r["colors"]:
            problems.append("colors %s" % r["colors"])
        if not r["flat"]:
            problems.append("not flat")
        if r["tris"] != meta["tris"]:
            problems.append("tris %d != sidecar %d" % (r["tris"], meta["tris"]))
        if sorted(s.split(".")[0] for s in r["slots"] if s) != sorted(meta["slots"]):
            problems.append("slots %s" % r["slots"])
    if meta.get("ucx_pieces") or meta.get("sockets"):
        problems.append("sidecar ucx %s sockets %s" % (meta.get("ucx_pieces"), meta.get("sockets")))
    print("REIMPORT %-22s %s -> %s" % (name, json.dumps([{k: r[k] for k in ("tris", "uv_layers", "colors", "flat")}
                                                          for r in meshes]),
                                       "ok" if not problems else "FAIL " + "; ".join(problems)))
    for p in problems:
        fails.append("%s reimport: %s" % (name, p))
    return meta


# ================================================================ main
BUILDERS = {
    "DeadLeaves_Pile_A": lambda: build_leaf_pile("DeadLeaves_Pile_A", PILES["DeadLeaves_Pile_A"]),
    "DeadLeaves_Pile_B": lambda: build_leaf_pile("DeadLeaves_Pile_B", PILES["DeadLeaves_Pile_B"]),
    "DeadLeaves_Scatter_A": lambda: build_leaf_scatter("DeadLeaves_Scatter_A"),
    "MossPad_A": lambda: build_moss_pad("MossPad_A", PADS["MossPad_A"]),
    "MossPad_B": lambda: build_moss_pad("MossPad_B", PADS["MossPad_B"]),
    "MossDrape_A": lambda: build_moss_drape("MossDrape_A"),
    "Mushroom_Cluster_A": lambda: build_mushroom_cluster("Mushroom_Cluster_A"),
}


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
        obj, info = BUILDERS[name]()
        built[name] = (obj, info)
        ok = check_mesh(name, obj, info, fails)
        print("  built %s in %.1fs" % (name, time.time() - t1))
        if args["export"] and ok:
            exported[name] = ec.export(obj, FAMILY, extra=sidecar_extra(name, info))
        elif args["export"]:
            print("  NOT exported (checks failed): %s" % name)
    sheets = render_sheets(built) if args["sheets"] else []
    for o in list(bpy.data.objects):
        if o.name.endswith(("_Review", "_Ctx")) or o.name.startswith("_"):
            remove_object(o)
    if args["save"]:
        ec.save_family_blend(FAMILY)
        print("saved", os.path.join(spec.BLEND_DIR, spec.FAMILIES[FAMILY][1]))
    for name, path in exported.items():
        meta = reimport(path, name, fails)
        info = built[name][1]
        table.append((name + "_Mars_SM", meta["tris"], [round(x, 1) for x in info["size_cm"]], meta["slots"],
                      sorted(meta.get("sockets", {})), meta.get("ucx_pieces", 0)))
    print("\nTABLE name | tris | size cm (x y z) | slots | sockets | ucx")
    for row in table:
        print("TABLE %s | %d | %s | %s | %s | %d" % row)
    print("\nsheets:", *sheets, sep="\n  ")
    print("exported:", *exported.values(), sep="\n  ")
    print("total %.1fs" % (time.time() - t0))
    if fails:
        print("ENV_ORGANIC_FAIL", *fails, sep="\n  ")
    elif len(only) != len(ORDER):
        print("ENV_ORGANIC_PARTIAL (only %s)" % ",".join(only))
    else:
        print("ENV_ORGANIC_OK")


if __name__ == "__main__":
    main()
