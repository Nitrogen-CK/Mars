"""Mars food library, category "mortar" (food_spec.CATEGORIES): the mortar & pestle minigame set.

Builds from fixed seeds, in Blender 5.2 headless:
  Mortar_Mars_SM, Pestle_Mars_SM                   slot Stone   the props (mortar axis at the origin, base z = 0)
  SaltCrystal_{A,B,C}_Mars_SM                      slot Salt    loose 2.5 cm crystals (centred XY, lowest z = 0)
  SaltPile_{Crystals,Grit,Dust}_Mars_SM            slot Salt    crush stages, pivot = the mortar bowl floor centre
  Peppercorn_{A,B}_Mars_SM                         slot Pepper  loose 1 cm corns
  PepperPile_{Whole,Cracked,Ground}_Mars_SM        slot Pepper  crush stages, pivot = the mortar bowl floor centre

Run (the scene is rebuilt from nothing every time):
  blender -b --factory-startup --python build_food_mortar.py -- [--export] [--save] [--sheets] [--only Mortar,SaltPile]
    --export     FBX + JSON sidecar + <Name>_Mask_Mars_T.png per mesh into food_spec.EXPORT_DIR, then every FBX is
                 re-imported in its own fresh factory-startup Blender (food_common.reimport_check) and verified.
                 Also renders the review sheets unless --no-sheets.
    --sheets     review sheets into food_spec.REVIEW_DIR (Mortar_{Props,Salt,Pepper,Loose,Fit}_sheet.png)
    --save       food_spec.BLEND_DIR/Food_Mortar.blend (nothing else is written by --save)
    --only       comma list of roster keys: Mortar, Pestle, SaltCrystal, SaltPile, Peppercorn, PepperPile
                 (the Mortar is always built for the bowl radius check and the fit sheet; exported only if listed)
Prints FOOD_MORTAR_OK when every check passed (FOOD_MORTAR_FAIL + the reasons otherwise).

Geometry notes
  Mortar   faceted lathe, 28 columns, hewn surface (low-frequency lumps displacement + small per-vertex breaks),
           convex belly, rim bead, foot ring, rim / foot chips, pouring lip on +X. The bowl floor is flat at
           z = FLOOR_Z out to ~6.3 cm with a fillet into the wall. The sidecar carries bowl_floor_cm and
           bowl_inner_radius_cm (inner wall radius 1 cm above the floor = the clearance a pile may use).
  Pestle   club lathe standing on its rounded head; the head's contact point is the pole at the origin.
  Piles    built around their pivot (never re-centred): ring-stitched mounds plus items settled onto a height field
           (they land on what is there and roll downhill past the angle of repose, so heaps are heaps, not towers).
           Footprints stay inside PILE_TARGET_R (12 cm across), on the flat part of the bowl floor.
Colour     "Col": per-facet base colour (salt white with blue-grey occlusion, stone greys with cooler facets and
           warm crevices, pepper near-black with brown facets and pale cut faces); A = ray-traced occlusion x cavity.
Masks      R 0 (nothing here cooks), G grain / sparkle / wrinkle noise, B 0.5-centred break-up, A sharp convex edge
           mask (texel distance to its triangle's sharp edges, via a baked face id) plus the mortar rim band.
"""
import itertools
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import food_common as fc  # noqa: E402

spec = fc.spec
CATEGORY = "mortar"
BLEND_PATH = os.path.join(spec.BLEND_DIR, spec.CATEGORIES[CATEGORY][0])
SHEET_PREFIX = "Mortar"

# ---------------------------------------------------------------- layout (cm)
FLOOR_Z = 3.0                  # bowl floor above the mortar base (food_spec "Mortar" ref)
PILE_LIMIT_R = 7.5             # brief: the most a pile footprint may use on the bowl floor
PILE_TARGET_R = 6.15           # piles are built inside this radius (12 cm across, on the flat part of the floor)
CRYSTAL_SIZES = {"A": 2.5, "B": 2.4, "C": 2.6}
CORN_SIZES = {"A": 1.0, "B": 0.95}

TRI_BUDGET = {
    ("Mortar", None): (1200, 2500), ("Pestle", None): (400, 900),
    ("SaltCrystal", "A"): (30, 250), ("SaltCrystal", "B"): (30, 250), ("SaltCrystal", "C"): (30, 250),
    ("Peppercorn", "A"): (60, 400), ("Peppercorn", "B"): (60, 400),
    ("SaltPile", "Crystals"): (600, 2500), ("SaltPile", "Grit"): (600, 2500), ("SaltPile", "Dust"): (100, 600),
    ("PepperPile", "Whole"): (600, 3000), ("PepperPile", "Cracked"): (600, 2500), ("PepperPile", "Ground"): (100, 600),
}

# ---------------------------------------------------------------- colours (picked as sRGB, stored linear)
STONE_BASE = fc.srgb(121, 118, 113)
STONE_COOL = fc.srgb(101, 108, 118)
STONE_WARM = fc.srgb(130, 121, 108)
STONE_WORN = fc.srgb(152, 149, 142)
STONE_SECTION = fc.srgb(196, 184, 160)          # review sheets only: the cut face of the section copies
SALT_WHITE = fc.srgb(240, 242, 245)
SALT_CREVICE = fc.srgb(146, 162, 186)
PEPPER_BLACK = fc.srgb(36, 30, 27)
PEPPER_BROWN = fc.srgb(84, 59, 40)
PEPPER_INNER = fc.srgb(122, 108, 88)
PEPPER_POWDER = fc.srgb(70, 60, 52)
PEPPER_CRACK_DUST = fc.srgb(98, 86, 74)        # paler powder so the dark fragments read on it

# face tags carried through the builders into the painters
T_OUTER, T_RIM, T_INNER, T_FLOOR = 0, 1, 2, 3          # mortar bands
T_SHAFT, T_HEAD, T_TOP = 0, 1, 2                       # pestle bands
T_ITEM, T_MOUND = 0, 1                                 # salt / pepper pieces vs the mound under them
T_HUSK, T_CORE = 0, 2                                  # pepper outer skin vs pale inner face


# ---------------------------------------------------------------- small geometry helpers (cm, numpy)
def _unit(v):
    v = np.asarray(v, float)
    return v / (np.linalg.norm(v, axis=-1, keepdims=True) + 1e-12)


def _rand_rot(rng):
    w, x, y, z = _unit(rng.normal(size=4))
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def _rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0.0], [s, c, 0.0], [0.0, 0.0, 1.0]])


def _rot_align(a, b):
    """Rotation matrix taking direction a onto direction b."""
    a, b = _unit(a), _unit(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if c < -0.999999:
        axis = _unit(np.cross(a, [1.0, 0.0, 0.0]) if abs(a[0]) < 0.9 else np.cross(a, [0.0, 1.0, 0.0]))
        return 2.0 * np.outer(axis, axis) - np.eye(3)
    vx = np.array([[0.0, -v[2], v[1]], [v[2], 0.0, -v[0]], [-v[1], v[0], 0.0]])
    return np.eye(3) + vx + vx @ vx / (1.0 + c)


def _poly_normal(pts):
    """Newell normal (length = 2 x area)."""
    n = np.zeros(3)
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n += np.array([(a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]), (a[0] - b[0]) * (a[1] + b[1])])
    return n


def _triangulate(v, faces, tags=None):
    """Tris stay; quads split on the shorter diagonal (the facet break of a jittered lathe); convex ngons fan from
    their first corner; other ngons fan from an added centroid. Returns (verts, tris, tags per tri)."""
    verts = [tuple(x) for x in np.asarray(v, float)]
    tags = np.zeros(len(faces), int) if tags is None else np.broadcast_to(np.asarray(tags), (len(faces),))
    out, out_tags = [], []
    for f, t in zip(faces, tags):
        f = [int(i) for i in f]
        k = len(f)
        if k == 3:
            out.append(f)
            out_tags.append(t)
            continue
        if k == 4:
            a, b, c, d = (np.array(verts[i]) for i in f)
            if np.linalg.norm(a - c) <= np.linalg.norm(b - d):
                out += [[f[0], f[1], f[2]], [f[0], f[2], f[3]]]
            else:
                out += [[f[0], f[1], f[3]], [f[1], f[2], f[3]]]
            out_tags += [t, t]
            continue
        pts = np.array([verts[i] for i in f])
        n = _poly_normal(pts)
        convex = all(np.dot(np.cross(pts[(i + 1) % k] - pts[i], pts[(i + 2) % k] - pts[(i + 1) % k]), n) > 1e-10
                     for i in range(k))
        if convex:
            for i in range(1, k - 1):
                out.append([f[0], f[i], f[i + 1]])
                out_tags.append(t)
        else:
            c = len(verts)
            verts.append(tuple(pts.mean(axis=0)))
            for i in range(k):
                out.append([f[i], f[(i + 1) % k], c])
                out_tags.append(t)
    return np.array(verts), out, np.array(out_tags, int)


def _signed_volume(v, tris):
    t = np.asarray(tris)
    return float(np.einsum("ij,ij->i", v[t[:, 0]], np.cross(v[t[:, 1]], v[t[:, 2]])).sum() / 6.0)


def _outward(v, tris):
    """Flip a closed, consistently wound piece so its normals face out."""
    return [list(reversed(t)) for t in tris] if _signed_volume(v, tris) < 0.0 else [list(t) for t in tris]


def _merge(parts):
    """[(verts, tris, tags (scalar or per tri)), ...] -> (verts, tris, tags)."""
    verts, tris, tags, base = [], [], [], 0
    for v, f, t in parts:
        v = np.asarray(v, float)
        verts.append(v)
        tris.extend([[base + i for i in face] for face in f])
        tags.extend(np.broadcast_to(np.asarray(t), (len(f),)).tolist())
        base += len(v)
    return np.concatenate(verts), tris, np.array(tags, int)


def _samples(v, tris, n, rng):
    """The vertices plus n area-weighted random points on the surface (used to rasterise items into a height field)."""
    t = np.asarray(tris)
    a, b, c = v[t[:, 0]], v[t[:, 1]], v[t[:, 2]]
    area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    idx = rng.choice(len(t), size=n, p=area / area.sum())
    r1 = np.sqrt(rng.random(n))
    r2 = rng.random(n)
    p = (1 - r1)[:, None] * a[idx] + (r1 * (1 - r2))[:, None] * b[idx] + (r1 * r2)[:, None] * c[idx]
    return np.concatenate([v, p])


def _bm_from(v, faces):
    bm = bmesh.new()
    vs = [bm.verts.new(tuple(p)) for p in np.asarray(v, float)]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    return bm


def _bm_arrays(bm):
    bm.verts.index_update()
    bm.faces.index_update()
    return np.array([x.co[:] for x in bm.verts]), [[x.index for x in f.verts] for f in bm.faces]


def _hull(points):
    """Convex hull of points -> (verts, tris) outward."""
    bm = bmesh.new()
    for p in points:
        bm.verts.new(tuple(p))
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    junk = [g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)]
    if junk:
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    v, f = _bm_arrays(bm)
    bm.free()
    v, tris, _ = _triangulate(v, f)
    return v, _outward(v, tris)


def _clean(v, tris, tags=None, min_area=1e-6):
    """Drop zero-area triangles (flat shading needs a real normal on every face) and unused vertices."""
    t = np.asarray(tris)
    tags = np.zeros(len(t), int) if tags is None else np.asarray(tags)
    area = 0.5 * np.linalg.norm(np.cross(v[t[:, 1]] - v[t[:, 0]], v[t[:, 2]] - v[t[:, 0]]), axis=1)
    keep = area > min_area
    t, tags = t[keep], tags[keep]
    used = np.unique(t)
    remap = -np.ones(len(v), int)
    remap[used] = np.arange(len(used))
    return v[used], remap[t].tolist(), tags


def _new(name, v, tris, slot, tags=None):
    v, tris, tags = _clean(np.asarray(v, float), tris, tags)
    return fc.new_object(name, v, tris, slots=(slot,)), tags


def _place(v, rot, scale):
    """Rotate / scale a piece and centre it in XY on its own bounds (z untouched). Returns (verts, xy shift)."""
    out = (np.asarray(v, float) @ rot.T) * scale
    c = (out.min(axis=0) + out.max(axis=0)) * 0.5
    c[2] = 0.0
    return out - c, c


def _faceted_lathe(profile, segments, seed, rough, band_tags, col_shift=0.22, vert_shift=0.05, freq=0.5):
    """Lathe with a hewn surface: rough[i] = (smooth amplitude, radial jitter, height jitter) in cm per profile row.
    The smooth term is low-frequency lumps noise (neighbouring facets lean together like chisel planes); the
    jitter terms are small per-vertex breaks. Columns shift coherently in angle (column 0 stays on +X).
    Returns (verts, faces, row id, column id, face tags)."""
    rng = np.random.default_rng(seed)
    seg = math.tau / segments
    col_off = rng.uniform(-col_shift, col_shift, segments) * seg
    col_off[0] = 0.0
    base, rows, cols, rings = [], [], [], []
    for i, (r, z) in enumerate(profile):
        amp, jr, jz = rough[i]
        if r < 1e-6:
            rings.append([len(base)])
            base.append((0.0, 0.0, z, 0.0, 0.0, 0.0))
            rows.append(i)
            cols.append(-1)
            continue
        start = len(base)
        for s in range(segments):
            a = s * seg + col_off[s] + (rng.uniform(-vert_shift, vert_shift) * seg if s else 0.0)
            base.append((r, a, z, amp, rng.uniform(-jr, jr), rng.uniform(-jz, jz)))
            rows.append(i)
            cols.append(s)
        rings.append(list(range(start, start + segments)))
    b = np.array(base)
    p0 = np.stack([b[:, 0] * np.cos(b[:, 1]), b[:, 0] * np.sin(b[:, 1]), b[:, 2]], axis=1)
    rr = np.where(b[:, 0] > 0, b[:, 0] + b[:, 3] * fc.lumps(p0, seed + 5, freq) + b[:, 4], 0.0)
    verts = np.stack([rr * np.cos(b[:, 1]), rr * np.sin(b[:, 1]), b[:, 2] + b[:, 5]], axis=1)
    faces, tags = [], []
    for i, (ra, rb) in enumerate(zip(rings[:-1], rings[1:])):
        for s in range(segments):
            s2 = (s + 1) % segments
            if len(ra) == 1:
                faces.append([ra[0], rb[s], rb[s2]])
            elif len(rb) == 1:
                faces.append([ra[s], rb[0], ra[s2]])
            else:
                faces.append([ra[s], rb[s], rb[s2], ra[s2]])
            tags.append(band_tags(i))
    return verts, faces, np.array(rows), np.array(cols), np.array(tags)


class _Heap:
    """Height field (cm) that items settle onto. An item lands where its underside first touches what is already
    there (minus a small sink so contacts read as resting), then rolls downhill while a neighbouring spot lands
    lower by more than the angle of repose allows. The floor z = 0 is solid."""

    def __init__(self, base=None, ext=8.5, res=0.15):
        self.ext, self.res = ext, res
        self.n = int(round(2 * ext / res)) + 1
        xs = np.linspace(-ext, ext, self.n)
        x, y = np.meshgrid(xs, xs, indexing="ij")
        self.h = (base(x, y) if base else np.zeros_like(x)).astype(float).ravel()

    def land(self, pts, x, y, sink):
        p = np.asarray(pts, float) + np.array([x, y, 0.0])
        ix = np.clip(np.rint((p[:, 0] + self.ext) / self.res).astype(int), 0, self.n - 1)
        iy = np.clip(np.rint((p[:, 1] + self.ext) / self.res).astype(int), 0, self.n - 1)
        uniq, inv = np.unique(ix * self.n + iy, return_inverse=True)
        bot = np.full(len(uniq), np.inf)
        np.minimum.at(bot, inv, p[:, 2])
        z = max(float(np.max(self.h[uniq] - bot)) - sink, -float(p[:, 2].min()))
        return z, (uniq, inv, p[:, 2])

    def commit(self, cache, z):
        uniq, inv, pz = cache
        top = np.full(len(uniq), -np.inf)
        np.maximum.at(top, inv, pz)
        self.h[uniq] = np.maximum(self.h[uniq], top + z)

    def settle(self, pts, x, y, sink, fits, rng, slope=0.75, iters=16):
        """Roll the item from (x, y): probe 8 directions at 0.5 - 2.2 item radii and move to the spot with the
        steepest drop while that drop beats `slope` (tan of the angle of repose). Then commit it to the field."""
        rad = 0.5 * float(np.ptp(pts[:, :2], axis=0).max())
        z, cache = self.land(pts, x, y, sink)
        for _ in range(iters):
            best, best_s = None, slope
            phase = rng.uniform(0.0, math.tau)
            for dist in (0.5 * rad, rad, 1.5 * rad, 2.2 * rad):
                for k in range(8):
                    a = phase + k * math.tau / 8
                    nx, ny = x + dist * math.cos(a), y + dist * math.sin(a)
                    if not fits(nx, ny):
                        continue
                    nz, nc = self.land(pts, nx, ny, sink)
                    if (z - nz) / dist > best_s:
                        best, best_s = (nx, ny, nz, nc), (z - nz) / dist
            if best is None:
                break
            x, y, z, cache = best
        self.commit(cache, z)
        return x, y, z


def _stitch(ra, rb):
    """Triangles between two concentric rings of (vertex id, angle in [0, tau)) sorted by angle (ra inner, may be a
    single apex), walking both by angle so the ring counts may differ."""
    na, nb = len(ra), len(rb)
    if na == 1:
        return [[ra[0][0], rb[j][0], rb[(j + 1) % nb][0]] for j in range(nb)]
    ia, ib = [i for i, _ in ra], [i for i, _ in rb]
    aa = [a for _, a in ra] + [ra[0][1] + math.tau]
    ab = [a for _, a in rb] + [rb[0][1] + math.tau]
    tris = []
    i = j = 0
    while i < na or j < nb:
        if j >= nb or (i < na and aa[i + 1] <= ab[j + 1]):
            tris.append([ia[i % na], ib[j % nb], ia[(i + 1) % na]])
            i += 1
        else:
            tris.append([ia[i % na], ib[j % nb], ib[(j + 1) % nb]])
            j += 1
    return tris


def _mound(radius, height, rings, segs, seed, power=2.0, edge_noise=0.07, height_noise=0.08, freq=0.6,
           z_jitter=0.0, xy_jitter=0.3, peak=0.0):
    """Closed faceted mound on z = 0: concentric rings whose vertex count grows with the radius (even facets, no
    star at the top), jittered, over a slumped bell profile (1 - t^2)^power with a lumpy outline. The bottom is a
    centre fan. Returns (verts, tris, height_fn(x, y))."""
    rng = np.random.default_rng(seed)

    def r_edge(theta):
        theta = np.asarray(theta, float)
        pts = np.stack([np.cos(theta), np.sin(theta), np.zeros_like(theta)], axis=-1).reshape(-1, 3) * 2.0
        return radius * (1.0 + edge_noise * fc.lumps(pts, seed, 1.0).reshape(theta.shape))

    def height_fn(x, y):
        x, y = np.asarray(x, float), np.asarray(y, float)
        t = np.clip(np.hypot(x, y) / r_edge(np.arctan2(y, x)), 0.0, 1.0)
        prof = (1.0 - t * t) ** power * (1.0 - peak + peak * (1.0 - t) ** 1.5)
        n = fc.lumps(np.stack([x, y, np.zeros_like(x)], axis=-1).reshape(-1, 3), seed + 1, freq).reshape(x.shape)
        return height * prof * (1.0 + height_noise * n)

    verts = [(0.0, 0.0, float(height_fn(0.0, 0.0)) + rng.uniform(-0.5, 0.5) * z_jitter)]
    ring_list = [[(0, 0.0)]]
    for i in range(1, rings + 1):
        t = i / rings
        k = max(5, int(round(segs * t)))
        step = math.tau / k
        th = (np.arange(k) * step + rng.uniform(0, step) + rng.uniform(-xy_jitter, xy_jitter, k) * 0.5 * step)
        th = np.sort(th % math.tau)
        tt = np.ones(k) if i == rings else t + rng.uniform(-xy_jitter, xy_jitter, k) * 0.5 / rings
        re = r_edge(th)
        x, y = tt * re * np.cos(th), tt * re * np.sin(th)
        z = np.zeros(k) if i == rings else np.maximum(height_fn(x, y) + rng.uniform(-z_jitter, z_jitter, k), 0.01)
        start = len(verts)
        verts.extend(zip(x, y, z))
        ring_list.append([(start + j, float(th[j])) for j in range(k)])
    tris = []
    for ra, rb in zip(ring_list[:-1], ring_list[1:]):
        tris.extend(_stitch(ra, rb))
    centre = len(verts)
    verts.append((0.0, 0.0, 0.0))
    last = [i for i, _ in ring_list[-1]]
    for j in range(len(last)):
        tris.append([last[(j + 1) % len(last)], last[j], centre])
    v = np.array(verts)
    return v, _outward(v, tris), height_fn


# ---------------------------------------------------------------- the mortar
MORTAR_SEGMENTS = 28
MORTAR_PROFILE = (
    (0.0, 0.0), (5.0, 0.0), (8.6, 0.0),                                    # 0-2  flat bottom
    (9.06, 0.3), (9.22, 0.95), (9.1, 1.5),                                 # 3-5  foot
    (9.28, 2.1), (9.82, 3.1), (10.35, 4.5), (10.75, 6.3), (10.92, 8.2),    # 6-10 convex belly
    (10.95, 9.8), (11.0, 10.5), (11.0, 11.3),                              # 11-13 rim band
    (10.68, 11.9), (10.15, 12.08), (9.65, 12.05), (9.25, 11.75),           # 14-17 rim (chamfer, top, chamfer)
    (9.05, 11.1), (8.8, 9.6), (8.5, 7.9), (8.2, 6.2), (7.95, 4.6),         # 18-22 inner wall
    (7.6, 3.75), (7.0, 3.25), (6.3, 3.04),                                 # 23-25 fillet
    (4.3, FLOOR_Z), (2.0, FLOOR_Z), (0.0, FLOOR_Z))                        # 26-28 flat floor, pole = bowl floor point


def _mortar_rough(i):
    """(smooth amplitude, radial jitter, z jitter) per profile row."""
    if i in (0, 28):
        return 0.0, 0.0, 0.0
    if i in (1, 2):
        return 0.08, 0.05, 0.0                     # the base stays on z = 0
    if i <= 5:
        return 0.16, 0.06, 0.04
    if i <= 13:
        return 0.34, 0.06, 0.1
    if i <= 17:
        return 0.14, 0.05, 0.05
    if i <= 23:
        return 0.15, 0.05, 0.08
    if i == 24:
        return 0.06, 0.03, 0.03
    return 0.0, 0.08, 0.0                          # the floor stays flat


def _mortar_band(i):
    return T_OUTER if i <= 13 else T_RIM if i <= 16 else T_INNER if i <= 24 else T_FLOOR


def build_mortar(seed=4101):
    rng = np.random.default_rng(seed + 1)
    v, faces, rows, cols, tags = _faceted_lathe(MORTAR_PROFILE, MORTAR_SEGMENTS, seed,
                                                [_mortar_rough(i) for i in range(len(MORTAR_PROFILE))], _mortar_band)
    r = np.hypot(v[:, 0], v[:, 1])
    th = np.arctan2(v[:, 1], v[:, 0])
    z = v[:, 2].copy()
    # pouring lip on +X: the rim dips into a shallow channel and the wall pushes out over +-28 degrees
    alpha = math.radians(28.0)
    w = np.where(np.abs(th) < alpha, np.cos(0.5 * math.pi * th / alpha) ** 2, 0.0)
    dz = {13: -0.45, 14: -1.05, 15: -1.25, 16: -1.25, 17: -1.0, 18: -0.45}
    dr = {11: 0.12, 12: 0.4, 13: 0.8, 14: 1.1, 15: 1.15, 16: 0.95, 17: 0.72, 18: 0.34, 19: 0.1}
    for row, d in dz.items():
        z[rows == row] += d * w[rows == row]
    for row, d in dr.items():
        r[rows == row] += d * w[rows == row]
    # chips: nicks in the rim and the foot, away from the lip
    far = [s for s in range(MORTAR_SEGMENTS) if abs(math.remainder(s * math.tau / MORTAR_SEGMENTS, math.tau)) > 1.2]
    for s in rng.choice(far, 3, replace=False):
        depth = rng.uniform(0.25, 0.42)
        for row, kz, kr in ((14, 0.7, 0.22), (15, 1.0, 0.1), (16, 0.8, -0.05)):
            m = (rows == row) & (cols == s)
            z[m] -= depth * kz
            r[m] -= kr
    for s in rng.choice(far, 2, replace=False):
        for row, kr in ((3, 0.3), (4, 0.2)):
            r[(rows == row) & (cols == s)] -= kr
    v = np.stack([r * np.cos(th), r * np.sin(th), z], axis=1)
    v, tris, tags = _triangulate(v, faces, tags)
    tris = _outward(v, tris)
    n_before = len(v)
    obj, tags = _new(spec.mesh_name("Mortar"), v, tris, "Stone", tags)
    assert len(obj.data.vertices) == n_before, "mortar lost vertices in cleanup; row ids would shift"

    # usable inner radius: the inner wall radius 1 cm above the floor (rows 22 / 23 bracket that height)
    probe = FLOOR_Z + 1.0
    radii = []
    for s in range(MORTAR_SEGMENTS):
        a = v[np.where((rows == 23) & (cols == s))[0][0]]
        b = v[np.where((rows == 22) & (cols == s))[0][0]]
        t = (probe - a[2]) / (b[2] - a[2])
        radii.append(float(np.hypot(*(a[:2] + t * (b[:2] - a[:2])))))
    flat_r = float(np.hypot(v[rows == 25, 0], v[rows == 25, 1]).min())
    rim_inner = float(np.hypot(v[rows == 16, 0], v[rows == 16, 1]).min())
    extra = {
        "bowl_floor_cm": [0.0, 0.0, FLOOR_Z],
        "bowl_inner_radius_cm": round(min(radii), 2),
        "bowl_floor_flat_radius_cm": round(flat_r, 2),
        "bowl_rim_inner_radius_cm": round(rim_inner, 2),
        "bowl_rim_z_cm": round(float(np.median(v[rows == 15, 2])), 2),
        "spout_dir": [1.0, 0.0, 0.0],
    }
    obj["bowl_floor_cm"] = extra["bowl_floor_cm"]
    obj["bowl_inner_radius_cm"] = extra["bowl_inner_radius_cm"]
    return obj, tags, extra


# ---------------------------------------------------------------- the pestle
PESTLE_SEGMENTS = 16
PESTLE_PROFILE = (
    (0.0, 0.0), (1.1, 0.12), (2.1, 0.52), (2.78, 1.2), (3.18, 2.05), (3.32, 2.95), (3.22, 3.9),   # 0-6  head
    (2.9, 4.95), (2.5, 6.3), (2.2, 7.9), (2.0, 9.6), (1.9, 11.4), (1.86, 13.2), (1.9, 14.8),      # 7-13 neck, grip
    (2.08, 16.0), (2.24, 16.95), (2.22, 17.5), (1.85, 17.9), (0.0, 18.0))                         # 14-18 flared top


def _pestle_rough(i):
    if i in (0, 18):
        return 0.0, 0.0, 0.0
    if i == 1:
        return 0.03, 0.02, 0.015
    if i <= 6:
        return 0.12, 0.04, 0.05
    if i <= 15:
        return 0.12, 0.04, 0.08
    return 0.06, 0.03, 0.03


def build_pestle(seed=4201):
    v, faces, rows, cols, tags = _faceted_lathe(
        PESTLE_PROFILE, PESTLE_SEGMENTS, seed, [_pestle_rough(i) for i in range(len(PESTLE_PROFILE))],
        lambda i: T_HEAD if i <= 5 else T_SHAFT if i <= 13 else T_TOP, col_shift=0.18, vert_shift=0.04, freq=0.9)
    v[:, 1] *= 0.95                                  # slightly oval, not turned
    v, tris, tags = _triangulate(v, faces, tags)
    tris = _outward(v, tris)
    obj, tags = _new(spec.mesh_name("Pestle"), v, tris, "Stone", tags)
    extra = {"contact_point_cm": [0.0, 0.0, 0.0], "head_radius_cm": 3.3, "grip_z_cm": [9.0, 16.0], "up_axis": "+Z"}
    return obj, tags, extra


# ---------------------------------------------------------------- salt crystals
def _crystal(seed, style, chips):
    """Chunky convex lump: a slightly sheared box cut by corner planes (cube -> chipped corners, oct -> deep,
    uneven octahedral truncation, shard -> tilted breaks) plus random chips. ~2 units across, returns (verts, tris)."""
    rng = np.random.default_rng(seed)
    if style == "cube":
        half = np.array([1.0, rng.uniform(0.8, 0.97), rng.uniform(0.68, 0.88)])
        frac, n_corner = (0.74, 0.92), int(rng.integers(5, 9))
    elif style == "oct":
        half = np.array([1.0, rng.uniform(0.85, 1.0), rng.uniform(0.8, 0.95)])
        frac, n_corner = (0.55, 0.75), 8
    else:
        half = np.array([1.0, rng.uniform(0.6, 0.78), rng.uniform(0.45, 0.62)])
        frac, n_corner = (0.7, 0.9), int(rng.integers(3, 6))
    shear = np.eye(3) + rng.uniform(-0.14, 0.14, (3, 3)) * (1.0 - np.eye(3))
    corners = np.array(list(itertools.product((-1.0, 1.0), repeat=3)))[rng.permutation(8)[:n_corner]]
    planes = [(_unit(shear @ (c / half) + rng.normal(0.0, 0.25, 3)), rng.uniform(*frac)) for c in corners]
    if style == "shard":
        planes += [(_unit(rng.normal(size=3)), rng.uniform(0.6, 0.75)) for _ in range(2)]
    planes += [(_unit(rng.normal(size=3)), rng.uniform(0.8, 0.94)) for _ in range(chips)]
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    for vert in bm.verts:
        vert.co = Vector(shear @ (np.array(vert.co) * half))
    for nrm, f in planes:
        d = f * max(float(np.dot(np.array(vert.co), nrm)) for vert in bm.verts)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-5,
                               plane_co=Vector(nrm * d), plane_no=Vector(nrm), clear_outer=True)
        edges = [e for e in bm.edges if e.is_boundary]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.03)
    bmesh.ops.dissolve_degenerate(bm, dist=0.01, edges=bm.edges[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    v, f = _bm_arrays(bm)
    bm.free()
    v, tris, _ = _triangulate(v, f)
    return v, _outward(v, tris)


def _rest_pose(v, tris, spin):
    """Lay a convex piece on its largest facet, spin it about Z, centre XY, lowest point z = 0."""
    t = np.asarray(tris)
    n = np.cross(v[t[:, 1]] - v[t[:, 0]], v[t[:, 2]] - v[t[:, 0]])
    nu = _unit(n)
    best, best_area = None, -1.0
    for i in range(len(t)):
        area = np.linalg.norm(n[np.einsum("ij,j->i", nu, nu[i]) > 0.999], axis=1).sum()   # whole facet, not one tri
        if area > best_area:
            best, best_area = nu[i], area
    v = v @ (_rot_z(spin) @ _rot_align(best, [0.0, 0.0, -1.0])).T
    lo, hi = v.min(axis=0), v.max(axis=0)
    return v - np.array([(lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, lo[2]])


def build_salt_crystal(letter, seed):
    style = {"A": "cube", "B": "oct", "C": "shard"}[letter]
    v, tris = _crystal(seed, style, chips=6)
    v = v / np.ptp(v, axis=0).max()
    v = _rest_pose(v, tris, spin=np.random.default_rng(seed).uniform(0, math.tau))
    v = v * (CRYSTAL_SIZES[letter] / np.ptp(v, axis=0).max())
    obj, tags = _new(spec.mesh_name("SaltCrystal", letter), v, tris, "Salt")
    return obj, tags, {"variant": letter, "style": style}


# ---------------------------------------------------------------- peppercorns
def _corn(seed, subdiv, radius=0.5):
    """Wrinkled peppercorn: icosphere (food_common subdivisions), slightly ovoid, ridged lumps noise for the
    wrinkle net, a stalk nub on top."""
    rng = np.random.default_rng(seed)
    v, f = fc.icosphere(radius, subdiv)
    d = _unit(v)
    ridge = 1.0 - np.abs(fc.lumps(d * 1.3, seed, 4.2))                       # 0 in the creases, 1 on ridges
    wav = fc.lumps(d * 1.1, seed + 3, 2.6)
    rr = radius * (1.0 + 0.085 * (ridge - 0.6) + 0.035 * wav + rng.uniform(-0.025, 0.025, len(v)))
    v = d * rr[:, None] * np.array([1.0, rng.uniform(0.94, 1.0), rng.uniform(0.9, 0.97)])
    top = int(np.argmax(v[:, 2]))
    v[top] *= 1.09
    return v, _outward(v, [list(t) for t in f])


def build_peppercorn(letter, seed):
    v, tris = _corn(seed, 3)
    v = v @ _rand_rot(np.random.default_rng(seed + 9)).T
    lo, hi = v.min(axis=0), v.max(axis=0)
    v = (v - np.array([(lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, lo[2]])) * (CORN_SIZES[letter] / np.ptp(v, axis=0).max())
    obj, tags = _new(spec.mesh_name("Peppercorn", letter), v, tris, "Pepper")
    return obj, tags, {"variant": letter}


# ---------------------------------------------------------------- salt piles
def _fits(piece, limit):
    return lambda x, y: float(np.hypot(piece[:, 0] + x, piece[:, 1] + y).max()) <= limit


def _start_xy(rng, piece, radius, power, limit, tries=30):
    """Random drop position (r ~ radius * u^power) whose piece stays inside the limit radius."""
    ok = _fits(piece, limit)
    for _ in range(tries):
        rr = radius * rng.random() ** power
        a = rng.uniform(0.0, math.tau)
        x, y = rr * math.cos(a), rr * math.sin(a)
        if ok(x, y):
            return x, y
    return 0.0, 0.0


def build_salt_crystals_pile(seed=5101):
    rng = np.random.default_rng(seed)
    shapes = []
    for i in range(14):
        v, tris = _crystal(seed + 31 * i, ("cube", "oct", "shard")[i % 3], chips=int(rng.integers(1, 4)))
        v = v / np.ptp(v, axis=0).max()
        shapes.append((v, tris, _samples(v, tris, 500, rng)))
    heap = _Heap()
    parts, count = [], 0
    # big crystals first, dropped around the middle; the heap shape comes from settling
    scales = np.sort(rng.uniform(0.5, 1.0, 34))[::-1]
    for s in scales:
        v, tris, smp = shapes[int(rng.integers(len(shapes)))]
        rot = _rand_rot(rng)
        vl, c = _place(v, rot, 2.5 * s)
        sl = (smp @ rot.T) * 2.5 * s - c
        x, y = _start_xy(rng, vl, 3.6, 0.7, PILE_TARGET_R)
        x, y, z = heap.settle(sl, x, y, 0.14, _fits(vl, PILE_TARGET_R), rng, slope=0.32)
        parts.append((vl + np.array([x, y, z]), tris, T_ITEM))
        count += 1
    v, tris, tags = _merge(parts)
    return v, tris, tags, {"item_count": count}


def _grain(rng, size):
    """A coarse salt grain: a small skewed, slightly irregular box (convex). Sunk half into the mound, only its
    top corner and a few faces show, which reads as packed grains rather than shards."""
    pts = np.array(list(itertools.product((-0.5, 0.5), repeat=3))) * np.array([1.0, rng.uniform(0.7, 1.0),
                                                                                rng.uniform(0.55, 0.9)])
    return _hull((pts + rng.normal(0, 0.06, pts.shape)) * size)


def build_salt_grit_pile(seed=5201):
    rng = np.random.default_rng(seed)
    height = 2.15
    mv, mt, hfn = _mound(5.5, height, rings=12, segs=42, seed=seed, power=1.25, edge_noise=0.07, height_noise=0.1,
                         freq=0.8, z_jitter=0.06, peak=0.35)
    parts = [(mv, mt, T_MOUND)]
    count = 0
    while count < 210:
        rr = 6.0 * math.sqrt(rng.random())
        a = rng.uniform(0, math.tau)
        x, y = rr * math.cos(a), rr * math.sin(a)
        h = float(hfn(np.array([x]), np.array([y]))[0])
        if rng.random() > 0.25 + 0.75 * h / height:
            continue
        gv, gt = _grain(rng, rng.uniform(0.36, 0.62))
        vl, _ = _place(gv, _rand_rot(rng), 1.0)
        if not _fits(vl, PILE_TARGET_R)(x, y):
            continue
        z = max(h - vl[:, 2].min() - rng.uniform(0.45, 0.62) * np.ptp(vl[:, 2]), -vl[:, 2].min())
        parts.append((vl + np.array([x, y, z]), gt, T_ITEM))
        count += 1
    v, tris, tags = _merge(parts)
    v, tris, tags = _cull_buried(v, tris, tags, hfn, margin=0.05, down=True)
    return v, tris, tags, {"item_count": count}


def build_salt_dust_pile(seed=5301):
    v, tris, _ = _mound(5.85, 2.0, rings=11, segs=40, seed=seed, power=2.0, edge_noise=0.06, height_noise=0.05,
                        freq=0.5, z_jitter=0.03, peak=0.3)
    return v, tris, np.full(len(tris), T_MOUND), {"item_count": 0}


# ---------------------------------------------------------------- pepper piles
def _corn_shapes(seed, n):
    rng = np.random.default_rng(seed)
    out = []
    for i in range(n):
        v, tris = _corn(seed + 13 * i, 2)
        out.append((v, tris, _samples(v, tris, 160, rng)))
    return out


def _cull_buried(v, tris, tags, hfn, margin, down=False):
    """Drop item triangles nobody can see: entirely under the mound surface (by margin), and with down=True also
    downward-facing ones whose centre is at or below the surface (the underside of a sunk grain)."""
    t = np.asarray(tris)
    item = tags != T_MOUND
    under = v[:, 2] < hfn(v[:, 0], v[:, 1]) - margin
    hide = np.all(under[t], axis=1)
    if down:
        c = v[t].mean(axis=1)
        nz = _unit(np.cross(v[t[:, 1]] - v[t[:, 0]], v[t[:, 2]] - v[t[:, 0]]))[:, 2]
        hide |= (nz < -0.25) & (c[:, 2] < hfn(c[:, 0], c[:, 1]) + 0.02)
    keep = ~(item & hide)
    t = t[keep]
    used = np.unique(t)
    remap = -np.ones(len(v), int)
    remap[used] = np.arange(len(used))
    return v[used], remap[t].tolist(), tags[keep]


def build_pepper_whole_pile(seed=6101):
    rng = np.random.default_rng(seed)
    mv, mt, hfn = _mound(2.9, 1.0, rings=5, segs=16, seed=seed, power=1.3, edge_noise=0.08, height_noise=0.1,
                         freq=0.9, z_jitter=0.05)
    heap = _Heap(base=hfn)
    shapes = _corn_shapes(seed + 1, 8)
    parts, count = [(mv, mt, T_MOUND)], 0
    for i in range(34):
        v, tris, smp = shapes[int(rng.integers(len(shapes)))]
        rot = _rand_rot(rng)
        s = rng.uniform(0.9, 1.1)
        vl, c = _place(v, rot, s)
        sl = (smp @ rot.T) * s - c
        if i < 31:                                      # the heap
            x, y = _start_xy(rng, vl, 2.4, 0.7, PILE_TARGET_R)
            x, y, z = heap.settle(sl, x, y, 0.14, _fits(vl, PILE_TARGET_R), rng, slope=0.62)
        else:                                           # a few strays rolled out onto the floor, all round
            a = (i - 31) * math.tau / 3 + rng.uniform(-0.35, 0.35) + 0.4
            rr = rng.uniform(4.8, 5.4)
            x, y = rr * math.cos(a), rr * math.sin(a)
            z, cache = heap.land(sl, x, y, 0.0)
            heap.commit(cache, z)
        parts.append((vl + np.array([x, y, z]), tris, T_HUSK))
        count += 1
    v, tris, tags = _merge(parts)
    v, tris, tags = _cull_buried(v, tris, tags, hfn, margin=0.16, down=True)
    return v, tris, tags, {"item_count": count}


def _corn_piece(seed, rng, cuts):
    """A cracked peppercorn: a corn cut by one (half) or two (chunk) planes; cut faces tagged as pale core.
    Returns (verts, tris, tags, first cut normal)."""
    v, tris = _corn(seed, 2)
    bm = _bm_from(v, tris)
    planes = []
    for c in range(cuts):
        nrm = _unit(rng.normal(size=3)) if c == 0 else _unit(np.cross(planes[0][0], rng.normal(size=3)))
        d = rng.uniform(-0.08, 0.05) if c == 0 else rng.uniform(-0.05, 0.1)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-5,
                               plane_co=Vector(nrm * d), plane_no=Vector(nrm), clear_outer=True)
        bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
        planes.append((nrm, d))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    tags = []
    for f in bm.faces:
        pts = np.array([x.co[:] for x in f.verts])
        on = any(np.all(np.abs(pts @ n - d) < 1e-4) for n, d in planes)
        tags.append(T_CORE if on else T_HUSK)
    v, f = _bm_arrays(bm)
    bm.free()
    v, tris, tags = _triangulate(v, f, tags)
    return v, _outward(v, tris), tags, planes[0][0]


def _flake(rng):
    """A thin curved husk flake: dark outer face up (+Z), pale inner face down."""
    k = int(rng.integers(3, 5))
    ang = np.sort(np.arange(k) * math.tau / k + rng.uniform(-0.4, 0.4, k) + rng.uniform(0, math.tau)) % math.tau
    ang = np.sort(ang)
    rad = rng.uniform(0.22, 0.4) * rng.uniform(0.7, 1.0, k)
    x, y = rad * np.cos(ang), rad * np.sin(ang)
    curve = rng.uniform(0.6, 1.4)
    top = np.stack([x, y, -curve * (x * x + y * y)], axis=1)
    thick = rng.uniform(0.04, 0.07)
    v = np.concatenate([top, top - np.array([0.0, 0.0, thick])])
    faces = [list(range(k)), list(range(2 * k - 1, k - 1, -1))]
    tags = [T_HUSK, T_CORE]
    for i in range(k):
        j = (i + 1) % k
        faces.append([k + i, k + j, j, i])
        tags.append(T_HUSK)
    v, tris, tags = _triangulate(v, faces, tags)
    return v, _outward(v, tris), tags


def _fragment(rng, size):
    """A coarse cracked-pepper fragment: a lumpy convex chunk, about a quarter of its faces pale core."""
    k = int(rng.integers(6, 8))
    d = _unit(rng.normal(size=(k, 3))) * np.array([1.0, rng.uniform(0.7, 1.0), rng.uniform(0.5, 0.8)])
    v, tris = _hull(d * size * 0.5)
    tags = np.where(rng.random(len(tris)) < 0.25, T_CORE, T_HUSK)
    return v, tris, tags


def build_pepper_cracked_pile(seed=6201):
    """A low mound of coarse fragments (sunk into a dark powder mound, hidden faces culled) with a few
    recognisable halves / chunks and thin husk flakes on top."""
    rng = np.random.default_rng(seed)
    height = 1.3
    mv, mt, hfn = _mound(5.0, height, rings=8, segs=28, seed=seed, power=1.5, edge_noise=0.08, height_noise=0.12,
                         freq=0.9, z_jitter=0.05, peak=0.3)
    heap = _Heap(base=hfn)
    parts, pieces, flakes, frags = [(mv, mt, T_MOUND)], 0, 0, 0
    for i in range(10):
        cuts = 1 if i < 6 else 2
        v, tris, tags, nrm = _corn_piece(seed + 7 * i, rng, cuts)
        up = [0.0, 0.0, 1.0] if (cuts == 1 and rng.random() < 0.35) else _unit(rng.normal(size=3))
        rot = _rot_z(rng.uniform(0, math.tau)) @ _rot_align(nrm, up)
        s = rng.uniform(0.85, 1.0) if cuts == 1 else rng.uniform(0.7, 0.9)
        vl, c = _place(v, rot, s)
        sl = (_samples(v, tris, 120, rng) @ rot.T) * s - c
        x, y = _start_xy(rng, vl, 3.8, 0.6, PILE_TARGET_R)
        x, y, z = heap.settle(sl, x, y, 0.12, _fits(vl, PILE_TARGET_R), rng, slope=0.6)
        parts.append((vl + np.array([x, y, z]), tris, tags))
        pieces += 1
    for i in range(24):
        v, tris, tags = _flake(rng)
        tilt = _rot_align([0.0, 0.0, 1.0], _unit(np.array([rng.normal(0, 0.35), rng.normal(0, 0.35), 1.0])))
        if rng.random() < 0.3:                                  # some show the pale inside
            tilt = tilt @ _rot_align([0.0, 0.0, 1.0], [0.0, 0.0, -1.0])
        rot = _rot_z(rng.uniform(0, math.tau)) @ tilt
        vl, c = _place(v, rot, 1.0)
        sl = (_samples(v, tris, 60, rng) @ rot.T) - c
        x, y = _start_xy(rng, vl, 5.0, 0.55, PILE_TARGET_R)
        x, y, z = heap.settle(sl, x, y, 0.03, _fits(vl, PILE_TARGET_R), rng, slope=0.9)
        parts.append((vl + np.array([x, y, z]), tris, tags))
        flakes += 1
    while frags < 150:
        rr = 5.6 * rng.random() ** 0.7
        a = rng.uniform(0, math.tau)
        x, y = rr * math.cos(a), rr * math.sin(a)
        h = float(hfn(np.array([x]), np.array([y]))[0])
        if rng.random() > 0.3 + 0.7 * h / height:
            continue
        v, tris, tags = _fragment(rng, rng.uniform(0.4, 0.7))
        vl, _ = _place(v, _rand_rot(rng), 1.0)
        if not _fits(vl, PILE_TARGET_R)(x, y):
            continue
        z = max(h - vl[:, 2].min() - rng.uniform(0.33, 0.5) * np.ptp(vl[:, 2]), -vl[:, 2].min())
        parts.append((vl + np.array([x, y, z]), tris, tags))
        frags += 1
    v, tris, tags = _merge(parts)
    v, tris, tags = _cull_buried(v, tris, tags, hfn, margin=0.05, down=True)
    return v, tris, tags, {"item_count": pieces + flakes + frags, "pieces": pieces, "flakes": flakes,
                           "fragments": frags}


def build_pepper_ground_pile(seed=6301):
    v, tris, _ = _mound(5.6, 1.8, rings=11, segs=40, seed=seed, power=1.9, edge_noise=0.07, height_noise=0.07,
                        freq=0.55, z_jitter=0.04, peak=0.25)
    return v, tris, np.full(len(tris), T_MOUND), {"item_count": 0}


# ---------------------------------------------------------------- occlusion + painting
def _vertex_normals(obj):
    n = np.empty(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("normal", n)
    return n.reshape(-1, 3)


def _ao(obj, points, normals, dist, n_dirs=20, floor_z=None, seed=5):
    """Ray-traced ambient occlusion (1 open) at points: cosine-weighted hemisphere rays against the mesh itself and
    optionally a floor plane (piles sit on the bowl floor)."""
    v = fc.verts_cm(obj)
    bvh = BVHTree.FromPolygons([tuple(x) for x in v], [tuple(p.vertices) for p in obj.data.polygons])
    k = np.arange(n_dirs)
    u = (k + 0.5) / n_dirs
    local = np.stack([np.sqrt(u) * np.cos(k * 2.399963), np.sqrt(u) * np.sin(k * 2.399963), np.sqrt(1 - u)], axis=1)
    rng = np.random.default_rng(seed)
    out = np.ones(len(points))
    for i, (p, nrm) in enumerate(zip(points, normals)):
        if np.linalg.norm(nrm) < 1e-6:
            continue
        nrm = _unit(nrm)
        tan = _unit(np.cross(nrm, [0.0, 0.0, 1.0] if abs(nrm[2]) < 0.9 else [1.0, 0.0, 0.0]))
        bit = np.cross(nrm, tan)
        a = rng.uniform(0, math.tau)
        lx = local[:, 0] * math.cos(a) - local[:, 1] * math.sin(a)
        ly = local[:, 0] * math.sin(a) + local[:, 1] * math.cos(a)
        dirs = lx[:, None] * tan + ly[:, None] * bit + local[:, 2:3] * nrm
        o = p + nrm * 0.01
        ov = Vector(o)
        hits = 0
        for d in dirs:
            if bvh.ray_cast(ov, Vector(d), dist)[0] is not None:
                hits += 1
            elif floor_z is not None and d[2] < -1e-4 and (o[2] - floor_z) / -d[2] < dist:
                hits += 1
        out[i] = 1.0 - hits / n_dirs
    return out


def _occlusion(obj, dist, floor_z=None):
    """(per-vertex alpha for Col.A, per-face open-ness) from ray AO and the edge cavity."""
    v = fc.verts_cm(obj)
    ao_v = _ao(obj, v, _vertex_normals(obj), dist, floor_z=floor_z)
    ao_f = _ao(obj, fc.face_centers_cm(obj), fc.face_normals(obj), dist, floor_z=floor_z, seed=6)
    cav = fc.cavity(obj, v)
    alpha = np.clip(ao_v ** 0.8 * (0.75 + 0.25 * np.clip(cav * 2.0, 0.0, 1.0)), 0.0, 1.0)
    return alpha, ao_f


def _lerp(a, b, t):
    t = np.asarray(t, float)[..., None]
    return a * (1.0 - t) + b * t


def paint_stone(obj, tags, seed, ao_dist):
    """Grey stone: cool / neutral facet patches, upward facets cooler, a few warm and dark facets, worn (paler)
    rim, bowl floor and pestle head; fc.paint darkens and warms the crevices."""
    c = fc.face_centers_cm(obj)
    n = fc.face_normals(obj)
    rng = np.random.default_rng(seed)
    t = fc.smoothstep(0.32, 0.68, fc.fbm(c * 0.16, seed))
    rgb = _lerp(STONE_BASE, STONE_COOL, t)
    rgb = _lerp(rgb, STONE_COOL, 0.35 * np.clip(n[:, 2], 0.0, 1.0))
    warm = rng.random(len(c)) < 0.12
    rgb[warm] = _lerp(rgb[warm], STONE_WARM, 0.7)
    dark = rng.random(len(c)) < 0.07
    rgb[dark] *= 0.8
    worn = np.isin(tags, (T_RIM, T_FLOOR, T_HEAD))
    rgb[worn] = _lerp(rgb[worn], STONE_WORN, 0.45)
    alpha, ao_f = _occlusion(obj, ao_dist)
    rgb *= (0.8 + 0.2 * ao_f)[:, None]
    fc.paint(obj, rgb, alpha=alpha, variation=0.06, seed=seed, cavity_darken=0.35)


def paint_salt(obj, tags, seed, ao_dist, on_floor, grainy=False):
    """Clean white, blue-grey where occluded (between crystals / grains), 8 % per-facet value jitter. grainy: the
    mound under the grit gets random grain-shadow facets."""
    rng = np.random.default_rng(seed)
    alpha, ao_f = _occlusion(obj, ao_dist, floor_z=0.0 if on_floor else None)
    rgb = _lerp(SALT_CREVICE, SALT_WHITE, np.clip(ao_f, 0.0, 1.0) ** 0.9)
    mound = tags == T_MOUND
    if grainy and mound.any():
        rgb[mound] = _lerp(rgb[mound], SALT_CREVICE, rng.uniform(0.0, 0.4, int(mound.sum())) ** 1.5)
    fc.paint(obj, rgb, alpha=alpha, variation=0.08, seed=seed, cavity_darken=0.0)


def paint_pepper(obj, tags, seed, ao_dist, on_floor, mound_rgb=PEPPER_POWDER):
    """Near-black corns with brown facets, pale cut faces; the mound under them in mound_rgb with dark / brown
    specks (powder for Cracked / Ground, corn-dark for Whole so the gaps read as shadowed corns)."""
    c = fc.face_centers_cm(obj)
    rng = np.random.default_rng(seed)
    nf = len(c)
    rgb = np.tile(PEPPER_BLACK, (nf, 1))
    brown = (fc.fbm(c * 2.2, seed) > 0.56) | (rng.random(nf) < 0.2)
    rgb[brown] = _lerp(PEPPER_BLACK, PEPPER_BROWN, rng.uniform(0.5, 1.0, int(brown.sum())))
    core = tags == T_CORE
    rgb[core] = PEPPER_INNER * rng.uniform(0.8, 1.08, (int(core.sum()), 1))
    mound = tags == T_MOUND
    if mound.any():
        m = np.tile(mound_rgb, (int(mound.sum()), 1))
        speck = rng.random(len(m))
        m[speck < 0.2] *= 0.55
        m[speck > 0.9] = _lerp(m[speck > 0.9], PEPPER_BROWN * 1.5, 0.6)
        rgb[mound] = m
    alpha, ao_f = _occlusion(obj, ao_dist, floor_z=0.0 if on_floor else None)
    rgb *= (0.7 + 0.3 * ao_f)[:, None]
    fc.paint(obj, rgb, alpha=alpha, variation=0.1, seed=seed, cavity_darken=0.4)


# ---------------------------------------------------------------- masks
def _bake_face_ids(obj, size):
    """Bake the triangle index of every texel (EMIT bake of a temporary float corner attribute)."""
    mesh = obj.data
    counts = [len(p.vertices) for p in mesh.polygons]
    ids = np.repeat(np.arange(len(mesh.polygons), dtype=np.float32), counts)
    attr = mesh.color_attributes.new("_FaceId", "FLOAT_COLOR", "CORNER")
    cols = np.zeros((len(mesh.loops), 4), np.float32)
    cols[:, 0] = ids
    cols[:, 3] = 1.0
    attr.data.foreach_set("color", cols.ravel())
    added = []
    for mat in mesh.materials:
        nt = mat.node_tree
        out = next((nd for nd in nt.nodes if nd.type == "OUTPUT_MATERIAL" and nd.is_active_output), None)
        created = out is None
        if created:
            out = nt.nodes.new("ShaderNodeOutputMaterial")
        prev = [lk.from_socket for lk in out.inputs["Surface"].links]
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "_FaceId"
        em = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(vc.outputs["Color"], em.inputs["Color"])
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
        added.append((nt, out, created, prev, vc, em))
    try:
        img = fc._bake_image(obj, "_bake_faceid", size, "EMIT")
    finally:
        for nt, out, created, prev, vc, em in added:
            nt.nodes.remove(vc)
            nt.nodes.remove(em)
            if created:
                nt.nodes.remove(out)
            elif prev:
                nt.links.new(prev[0], out.inputs["Surface"])
        mesh.color_attributes.remove(mesh.color_attributes["_FaceId"])
        idx = [a.name for a in mesh.color_attributes].index(spec.COLOR_ATTR)
        mesh.color_attributes.active_color_index = idx
        mesh.color_attributes.render_color_index = idx
    return img[..., 0]


def _edge_mask(obj, face_ids, pos_cm, width, min_angle):
    """Per texel: 1 on sharp convex edges of its own triangle, fading to 0 at `width` cm. A triangle edge is sharp
    when the dihedral angle to its neighbour passes min_angle (degrees) and the neighbour falls away (convex)."""
    mesh = obj.data
    v = fc.verts_cm(obj)
    t = np.array([list(p.vertices) for p in mesh.polygons])
    fn = fc.face_normals(obj)
    cen = v[t].mean(axis=1)
    owners = {}
    for fi, tri in enumerate(t):
        for j in range(3):
            a, b = int(tri[j]), int(tri[(j + 1) % 3])
            owners.setdefault((min(a, b), max(a, b)), []).append((fi, j))
    w = np.zeros((len(t), 3))
    for lst in owners.values():
        if len(lst) != 2:
            for fi, j in lst:
                w[fi, j] = 0.6
            continue
        (f1, j1), (f2, j2) = lst
        ang = math.degrees(math.acos(float(np.clip(np.dot(fn[f1], fn[f2]), -1.0, 1.0))))
        convex = float(np.dot(cen[f2] - cen[f1], fn[f1])) < 0.0
        s = float(fc.smoothstep(min_angle, min_angle * 2.0, ang)) if convex else 0.0
        w[f1, j1] = w[f2, j2] = s
    ids = np.clip(np.rint(face_ids).astype(int), 0, len(t) - 1)
    out = np.zeros(len(ids))
    for j in range(3):
        a = v[t[ids, j]]
        b = v[t[ids, (j + 1) % 3]]
        ab = b - a
        u = np.clip(np.einsum("ij,ij->i", pos_cm - a, ab) / np.maximum(np.einsum("ij,ij->i", ab, ab), 1e-12), 0, 1)
        d = np.linalg.norm(pos_cm - (a + u[:, None] * ab), axis=1)
        out = np.maximum(out, w[ids, j] * fc.smoothstep(width, 0.0, d))
    return out


MASK_STYLE = {   # kind -> (edge width cm, sharp angle deg)
    "mortar": (0.35, 14.0), "pestle": (0.25, 14.0), "crystal": (0.12, 20.0), "grit": (0.06, 20.0),
    "dust": (0.25, 8.0), "corn": (0.05, 12.0), "powder": (0.2, 8.0),
}


def _centred(x, sd):
    """Signed detail term per spec: mean 0.5 over the mesh, spread `sd`, clipped to 0..1."""
    x = np.asarray(x, float)
    return np.clip(0.5 + (x - x.mean()) / (x.std() + 1e-6) * sd, 0.0, 1.0)


def bake_item_masks(obj, kind, seed):
    size = spec.MASK_SIZE
    face_ids = _bake_face_ids(obj, size)
    width, angle = MASK_STYLE[kind]

    def masks(f):
        cover = f["coverage"] > 0.5
        out = np.zeros(cover.shape + (4,), np.float32)
        out[..., 1] = 0.5
        out[..., 2] = 0.5
        p = f["position_cm"][cover]
        edge = _edge_mask(obj, face_ids[cover], p, width, angle)
        b = _centred(fc.fbm(p * (0.25 if kind in ("mortar", "pestle") else 0.6), seed + 3), 0.07)
        if kind in ("mortar", "pestle"):
            grain = fc.fbm(p * 0.45, seed) + 0.55 * fc.fbm(p * 2.4, seed + 1)
            grain = grain + 0.35 * (fc.noise3(p * 4.0, seed + 2) > 0.8)                # pale stone flecks
            g = _centred(grain, 0.14)
            rim = (0.8 * fc.smoothstep(11.2, 11.85, p[:, 2]) if kind == "mortar"
                   else 0.6 * fc.smoothstep(16.9, 17.7, p[:, 2]))
            a = np.maximum(edge, rim)
        elif kind in ("crystal", "grit", "dust"):
            g = _centred(fc.fbm(p * 3.5, seed), 0.1)                                   # sparkle / grain
            a = edge
        else:
            ridge = 1.0 - np.abs(2.0 * fc.fbm(p * (6.0 if kind == "corn" else 2.5), seed) - 1.0)
            g = _centred(ridge, 0.12)                                                  # wrinkle / powder grain
            a = edge
        out[cover] = np.stack([np.zeros(len(p)), g, b, np.clip(a, 0, 1)], axis=-1)
        return out

    path, _ = fc.bake_masks(obj, masks, size=size)
    return path


# ---------------------------------------------------------------- review renders
VIEW_DIRS = {"iso": (0.55, -1.0, 0.75), "front": (0.0, -1.0, 0.12), "top": (0.0, 0.0, 1.0),
             "lip": (-0.9, -0.5, 0.75), "high": (0.2, -1.0, 1.25), "section": (0.0, -1.0, 0.0)}


def _label(text, loc_cm, size_cm, rgb):
    """Flat text mesh (+Z facing) with a solid Col so it renders in the VERTEX colour sheets."""
    cu = bpy.data.curves.new("_Label", "FONT")
    cu.body = text
    cu.size = size_cm * 0.01
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    tmp = bpy.data.objects.new("_LabelTmp", cu)
    bpy.context.scene.collection.objects.link(tmp)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(cu)
    attr = me.color_attributes.new(spec.COLOR_ATTR, "FLOAT_COLOR", "CORNER")
    attr.data.foreach_set("color", np.tile(np.append(np.asarray(rgb, float), 1.0), len(me.loops)))
    me.color_attributes.active_color_index = 0
    me.color_attributes.render_color_index = 0
    o = bpy.data.objects.new("_Label_" + text, me)
    bpy.context.scene.collection.objects.link(o)
    o.location = Vector(np.asarray(loc_cm, float) * 0.01)
    return o


def _shoot(placements, view, path, size=(1800, 620), bg=0.05, labels=()):
    """Orthographic workbench render of objects placed at cm offsets (everything else hidden), framed on them."""
    scene = bpy.context.scene
    objs = [o for o in scene.objects if o.type in ("MESH", "FONT")]
    state = [(o, o.location.copy(), o.hide_render) for o in objs]
    cam_data = bpy.data.cameras.new("_SheetCam")
    cam = bpy.data.objects.new("_SheetCam", cam_data)
    scene.collection.objects.link(cam)
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.filepath, scene.display.shading.color_type, scene.display.shading.light,
            scene.display.shading.show_cavity, scene.render.film_transparent, scene.world.color[:],
            scene.view_settings.view_transform, scene.view_settings.look)
    try:
        for o in objs:
            o.hide_render = True
        pts = []
        for o, off in placements:
            o.location = Vector(np.asarray(off, float) * 0.01)
            o.hide_render = False
            pts.append(fc.verts_cm(o) + np.asarray(off, float))
        for lb in labels:
            lb.hide_render = False
            pts.append(fc.verts_cm(lb) + np.array(lb.location) * 100.0)
        pts = np.concatenate(pts)
        d = _unit(VIEW_DIRS[view])
        fwd = -d
        right = np.cross(fwd, [0.0, 0.0, 1.0])
        right = _unit(right) if np.linalg.norm(right) > 1e-6 else np.array([1.0, 0.0, 0.0])
        up = np.cross(right, fwd)
        mid = pts.mean(axis=0)
        pr, pu = (pts - mid) @ right, (pts - mid) @ up
        centre = mid + right * (pr.min() + pr.max()) * 0.5 + up * (pu.min() + pu.max()) * 0.5
        aspect = size[0] / size[1]
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = max(np.ptp(pr), np.ptp(pu) * aspect) * 1.1 * 0.01
        cam_data.clip_start, cam_data.clip_end = 0.01, 20.0
        cam.location = Vector((centre + d * 400.0) * 0.01)
        cam.rotation_euler = Matrix((right, up, d)).transposed().to_euler()
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "VERTEX"
        scene.display.shading.show_cavity = True
        scene.render.film_transparent = False
        scene.world.color = (bg, bg, bg)
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "None"
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
    finally:
        for o, loc, hr in state:
            o.location, o.hide_render = loc, hr
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
         scene.render.filepath, scene.display.shading.color_type, scene.display.shading.light,
         scene.display.shading.show_cavity, scene.render.film_transparent, scene.world.color,
         scene.view_settings.view_transform, scene.view_settings.look) = prev
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return path


def _section_copy(obj, name):
    """Review-only copy of the mortar with the near half (y < 0) cut away and the cut face filled and coloured."""
    me = obj.data.copy()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-5, plane_co=(0.0, 0.0, 0.0),
                           plane_no=(0.0, -1.0, 0.0), clear_outer=True)
    cap = bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)["faces"]
    col = bm.loops.layers.float_color.get(spec.COLOR_ATTR)
    for f in cap:
        for lp in f.loops:
            lp[col] = (*STONE_SECTION, 1.0)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def render_sheets(items):
    """Mortar_{Props,Salt,Pepper,Loose,Fit}_sheet.png in REVIEW_DIR (views stacked top to bottom)."""
    fc.ensure_dirs()
    by = {(it["key"], it["stage"]): it["obj"] for it in items}
    tmp = tempfile.mkdtemp(prefix="mars_mortar_sheets_")
    temp_objs, sheets = [], []

    def sheet(stem, shots):
        paths = []
        for i, (placements, view, kw) in enumerate(shots):
            paths.append(_shoot(placements, view, os.path.join(tmp, "%s_%02d_%s.png" % (stem, i, view)), **kw))
        out = fc.tile_images(paths, os.path.join(spec.REVIEW_DIR, "%s_%s_sheet.png" % (SHEET_PREFIX, stem)), cols=1)
        sheets.append(out)
        print("sheet", out)

    try:
        mortar = by.get(("Mortar", None))
        pestle = by.get(("Pestle", None))
        section = None
        if mortar:
            section = _section_copy(mortar, "_MortarSection")
            temp_objs.append(section)
        if mortar and pestle:
            pl = [(mortar, (-27.0, 0, 0)), (section, (0, 0, 0)), (pestle, (24.0, 0, 0))]
            sheet("Props", [(pl, v, {"bg": 0.18}) for v in ("iso", "front", "top")]
                  + [([(mortar, (0, 0, 0))], "lip", {"bg": 0.18})])

        for key, loose_key, stem, letters, bg, ink in (("SaltPile", "SaltCrystal", "Salt", "ABC", 0.05, (0.8, 0.8, 0.8)),
                                                       ("PepperPile", "Peppercorn", "Pepper", "AB", 0.32, (0.01, 0.01, 0.01))):
            pl, labels = [], []
            for i, letter in enumerate(letters):
                o = by.get((loose_key, letter))
                if o:
                    pl.append((o, (-22.5 + (i - (len(letters) - 1) * 0.5) * 3.6, 0, 0)))
            if pl:
                labels.append(_label("LOOSE", (-22.5, -9.0, 0.0), 1.6, ink))
            for i, st in enumerate(spec.INGREDIENTS[key]["stages"]):
                o = by.get((key, st))
                if o:
                    pl.append((o, (-7.5 + 15.0 * i, 0, 0)))
                    labels.append(_label(st.upper(), (-7.5 + 15.0 * i, -9.0, 0.0), 1.6, ink))
            temp_objs.extend(labels)
            if pl:
                sheet(stem, [(pl, v, {"bg": bg, "labels": labels if v != "front" else ()})
                             for v in ("iso", "front", "top")])

        loose = [by.get(("SaltCrystal", x)) for x in "ABC"] + [by.get(("Peppercorn", x)) for x in "AB"]
        pl = [(o, (x, 0, 0)) for o, x in zip(loose, (-6.4, -3.2, 0.0, 3.0, 5.0)) if o]
        if pl:
            sheet("Loose", [(pl, v, {"bg": 0.2, "size": (1800, 700)}) for v in ("iso", "front", "top")])

        if mortar:
            shots = []
            for key in ("SaltPile", "PepperPile"):
                piles = [o for o in (by.get((key, st)) for st in spec.INGREDIENTS[key]["stages"]) if o]
                if not piles:
                    continue
                xs = [(i - (len(piles) - 1) * 0.5) * 27.0 for i in range(len(piles))]
                full, cut = [], []
                for x in xs:
                    m = mortar.copy()
                    c = section.copy()
                    for o in (m, c):
                        bpy.context.scene.collection.objects.link(o)
                        temp_objs.append(o)
                    full.append((m, (x, 0, 0)))
                    cut.append((c, (x, 0, 0)))
                on_floor = [(o, (x, 0, FLOOR_Z)) for o, x in zip(piles, xs)]     # pile pivot on the bowl floor point
                shots.append((full + on_floor, "high", {"bg": 0.16, "size": (1800, 600)}))
                shots.append((cut + on_floor, "section", {"bg": 0.16, "size": (1800, 600)}))
            if shots:
                sheet("Fit", shots)
    finally:
        for o in temp_objs:
            data = o.data
            bpy.data.objects.remove(o)
            if isinstance(data, bpy.types.Mesh) and data.users == 0:
                bpy.data.meshes.remove(data)
        shutil.rmtree(tmp, ignore_errors=True)
    return sheets


# ---------------------------------------------------------------- roster
def _pile_extra(obj, stage_list, stage, info):
    v = fc.verts_cm(obj)
    return dict(info, stage=stage, stage_index=list(stage_list).index(stage), pivot="bowl_floor",
                footprint_radius_cm=round(float(np.hypot(v[:, 0], v[:, 1]).max()), 2),
                height_cm=round(float(v[:, 2].max()), 2))


def build_all(only):
    """-> list of item dicts {key, stage, obj, tags, kind, extra, paint, export}."""
    items = []

    def want(key):
        return not only or key in only

    t0 = time.time()
    obj, tags, extra = build_mortar()
    items.append(dict(key="Mortar", stage=None, obj=obj, tags=tags, kind="mortar", extra=extra,
                      paint=lambda o, t: paint_stone(o, t, 11, ao_dist=5.0), export=want("Mortar")))
    if want("Pestle"):
        obj, tags, extra = build_pestle()
        items.append(dict(key="Pestle", stage=None, obj=obj, tags=tags, kind="pestle", extra=extra,
                          paint=lambda o, t: paint_stone(o, t, 12, ao_dist=3.0), export=True))
    if want("SaltCrystal"):
        for i, letter in enumerate("ABC"):
            obj, tags, extra = build_salt_crystal(letter, 7101 + 97 * i)
            items.append(dict(key="SaltCrystal", stage=letter, obj=obj, tags=tags, kind="crystal", extra=extra,
                              paint=lambda o, t: paint_salt(o, t, 21, ao_dist=1.0, on_floor=True), export=True))
    if want("Peppercorn"):
        for i, letter in enumerate("AB"):
            obj, tags, extra = build_peppercorn(letter, 7201 + 97 * i)
            items.append(dict(key="Peppercorn", stage=letter, obj=obj, tags=tags, kind="corn", extra=extra,
                              paint=lambda o, t: paint_pepper(o, t, 22, ao_dist=0.5, on_floor=True), export=True))
    if want("SaltPile"):
        stages = spec.INGREDIENTS["SaltPile"]["stages"]
        for stage, fn, kind, ao, grainy in (("Crystals", build_salt_crystals_pile, "crystal", 2.5, False),
                                            ("Grit", build_salt_grit_pile, "grit", 1.5, True),
                                            ("Dust", build_salt_dust_pile, "dust", 2.0, False)):
            v, tris, tags, info = fn()
            obj, tags = _new(spec.mesh_name("SaltPile", stage), v, tris, "Salt", tags)
            items.append(dict(key="SaltPile", stage=stage, obj=obj, tags=tags, kind=kind,
                              extra=_pile_extra(obj, stages, stage, info),
                              paint=lambda o, t, ao=ao, g=grainy: paint_salt(o, t, 23, ao_dist=ao, on_floor=True,
                                                                             grainy=g), export=True))
    if want("PepperPile"):
        stages = spec.INGREDIENTS["PepperPile"]["stages"]
        for stage, fn, kind, ao, mound in (("Whole", build_pepper_whole_pile, "corn", 1.2, PEPPER_BLACK),
                                           ("Cracked", build_pepper_cracked_pile, "corn", 1.0, PEPPER_CRACK_DUST),
                                           ("Ground", build_pepper_ground_pile, "powder", 2.0, PEPPER_POWDER)):
            v, tris, tags, info = fn()
            obj, tags = _new(spec.mesh_name("PepperPile", stage), v, tris, "Pepper", tags)
            items.append(dict(key="PepperPile", stage=stage, obj=obj, tags=tags, kind=kind,
                              extra=_pile_extra(obj, stages, stage, info),
                              paint=lambda o, t, ao=ao, m=mound: paint_pepper(o, t, 24, ao_dist=ao, on_floor=True,
                                                                              mound_rgb=m), export=True))
    print("built %d meshes in %.1fs" % (len(items), time.time() - t0))
    return items


# ---------------------------------------------------------------- verification
def verify(items, bowl_r):
    fails = []
    print("\n%-28s %5s %6s %-15s %5s %4s %-6s %s" % ("mesh", "tris", "size", "budget", "flat", "Col", "uv", "notes"))
    for it in items:
        obj, key = it["obj"], it["key"]
        tris = fc.tri_count(obj)
        lo, hi = TRI_BUDGET[(key, it["stage"])]
        size_ok = fc.check_against_spec(obj, key, tolerance=0.25)
        flat = fc._is_flat(obj.data)
        col = spec.COLOR_ATTR in obj.data.color_attributes
        uvs = [u.name for u in obj.data.uv_layers]
        v = fc.verts_cm(obj)
        b_lo, b_hi = v.min(axis=0), v.max(axis=0)
        if key.endswith("Pile"):
            fr = float(np.hypot(v[:, 0], v[:, 1]).max())
            note = "footprint r %.2f (bowl %.2f, limit %.1f) h %.2f min z %.3f" % (fr, bowl_r, PILE_LIMIT_R,
                                                                                  b_hi[2], b_lo[2])
            if fr > min(bowl_r, PILE_LIMIT_R) or abs(b_lo[2]) > 1e-4:
                fails.append("%s footprint / pivot" % obj.name)
        elif key == "Mortar":
            note = "bowl floor %s inner r %.2f flat r %.2f rim z %.2f" % (
                it["extra"]["bowl_floor_cm"], bowl_r, it["extra"]["bowl_floor_flat_radius_cm"], it["extra"]["bowl_rim_z_cm"])
        else:
            note = "bbox centre xy (%.3f, %.3f) min z %.3f" % ((b_lo[0] + b_hi[0]) / 2, (b_lo[1] + b_hi[1]) / 2, b_lo[2])
        print("%-28s %5d %6.2f %-15s %5s %4s %-6s %s" % (obj.name.replace("_Mars_SM", ""), tris, float((b_hi - b_lo).max()),
                                                        "%d-%d %s" % (lo, hi, "ok" if lo <= tris <= hi else "OUT"),
                                                        flat, col, ",".join(uvs), note))
        if not (lo <= tris <= hi):
            fails.append("%s tris %d outside %d-%d" % (obj.name, tris, lo, hi))
        if not size_ok:
            fails.append("%s off spec size" % obj.name)
        if not flat:
            fails.append("%s not flat" % obj.name)
        if not col:
            fails.append("%s missing Col" % obj.name)
        if uvs != ["UVMap"]:
            fails.append("%s uv layers %s" % (obj.name, uvs))
    return fails


def reimport_fresh(fbx_paths, expected):
    """Each FBX into its own fresh factory-startup Blender (this script in --reimport mode)."""
    fails = []
    for path in fbx_paths:
        cmd = [bpy.app.binary_path, "-b", "--factory-startup", "--python", os.path.abspath(__file__), "--",
               "--reimport", path]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        line = next((ln for ln in res.stdout.splitlines() if ln.startswith("REIMPORT_JSON ")), None)
        if line is None:
            fails.append("reimport failed for %s" % path)
            print(res.stdout[-2000:], res.stderr[-2000:])
            continue
        rep = json.loads(line[len("REIMPORT_JSON "):])
        want = expected[os.path.splitext(os.path.basename(path))[0]]
        if len(rep) != 1:
            fails.append("%s: %d meshes on reimport" % (path, len(rep)))
            continue
        r = rep[0]
        problems = []
        if r["tris"] != want["tris"]:
            problems.append("tris %d != %d" % (r["tris"], want["tris"]))
        if r["uv_layers"] != ["UVMap"]:
            problems.append("uv %s" % r["uv_layers"])
        if spec.COLOR_ATTR not in r["colors"]:
            problems.append("colors %s" % r["colors"])
        if not r["flat"]:
            problems.append("not flat")
        if [s.split(".")[0] for s in r["slots"] if s] != want["slots"]:
            problems.append("slots %s" % r["slots"])
        if abs(r["size_cm"] - want["size"]) > 0.05:
            problems.append("size %.2f != %.2f" % (r["size_cm"], want["size"]))
        print("REIMPORT %s %s" % (json.dumps(r), "ok" if not problems else "FAIL " + "; ".join(problems)))
        if problems:
            fails.append("%s reimport: %s" % (os.path.basename(path), "; ".join(problems)))
    return fails


def _reimport_child(path):
    print("REIMPORT_JSON " + json.dumps(fc.reimport_check(path)))


# ---------------------------------------------------------------- main
def _organise_for_save(items):
    scene = bpy.context.scene
    groups = {"Mortar_Props": ("Mortar", "Pestle"), "Mortar_Salt": ("SaltCrystal", "SaltPile"),
              "Mortar_Pepper": ("Peppercorn", "PepperPile")}
    for cname, keys in groups.items():
        coll = bpy.data.collections.get(cname) or bpy.data.collections.new(cname)
        if coll.name not in scene.collection.children:
            scene.collection.children.link(coll)
        for it in items:
            if it["key"] in keys:
                o = it["obj"]
                for c in list(o.users_collection):
                    c.objects.unlink(o)
                coll.objects.link(o)
    # every mesh keeps its export pivot at the origin, so only the props show when the file opens
    for cname in ("Mortar_Salt", "Mortar_Pepper"):
        lc = bpy.context.view_layer.layer_collection.children.get(cname)
        if lc:
            lc.hide_viewport = True
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)


def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False, "only": "", "no-sheets": False,
                        "reimport": ""})
    if args["reimport"]:
        _reimport_child(args["reimport"])
        return
    only = set(s.strip() for s in str(args["only"]).split(",") if s.strip()) if isinstance(args["only"], str) else set()
    unknown = only - {k for k, v in spec.INGREDIENTS.items() if v["category"] == CATEGORY}
    if unknown:
        raise SystemExit("unknown --only keys %s" % sorted(unknown))
    t0 = time.time()
    fc.ensure_dirs()
    fc.clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"

    items = build_all(only)
    for it in items:
        t1 = time.time()
        it["paint"](it["obj"], it["tags"])
        fc.smart_uv(it["obj"])
        print("painted + uv %-34s %.1fs" % (it["obj"].name, time.time() - t1))
    mortar = next(it for it in items if it["key"] == "Mortar")
    bowl_r = mortar["extra"]["bowl_inner_radius_cm"]
    fails = verify(items, bowl_r)

    exported = []
    if args["export"]:
        for it in items:
            if not it["export"]:
                continue
            t1 = time.time()
            mask = bake_item_masks(it["obj"], it["kind"], 31)
            extra = dict(it["extra"], category=CATEGORY, spec_key=it["key"], mask=os.path.basename(mask),
                         mask_channels="R cook-first (0: does not cook), G grain, B break-up, A sharp edges / rim")
            path = fc.export_fbx(it["obj"], extra=extra)
            exported.append((path, it))
            print("  mask %s (%.1fs)" % (mask, time.time() - t1))
    sheets = []
    if args["sheets"] or (args["export"] and not args["no-sheets"]):
        sheets = render_sheets(items)
    if args["save"]:
        _organise_for_save(items)
        fc.save_blend(BLEND_PATH)
        print("saved", BLEND_PATH)
    if exported:
        expected = {it["obj"].name: {"tris": fc.tri_count(it["obj"]), "slots": [m.name for m in it["obj"].data.materials],
                                     "size": float((fc.bounds_cm(it["obj"])[1] - fc.bounds_cm(it["obj"])[0]).max())}
                    for _, it in exported}
        fails += reimport_fresh([p for p, _ in exported], expected)
    print("\nsheets:", *sheets, sep="\n  ")
    print("total %.1fs" % (time.time() - t0))
    if fails:
        print("FOOD_MORTAR_FAIL", *fails, sep="\n  ")
    else:
        print("FOOD_MORTAR_OK")


main()
