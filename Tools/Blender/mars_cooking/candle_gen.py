"""Procedural candle generator for Mars (Blender 5.2, numpy only): a cluster of melted pillar candles as ONE signed
distance field, meshed, reduced to a faceted low-poly prop and dressed with a wick and a flame per candle.

    import candle_gen as cg
    params = cg.CandleParams(seed=7, count=5, height_variation=1.0, blend_cm=2.0, melt=0.6, palette="mixed")
    obj, info = cg.generate(params, name="CandleCluster_X_Mars_SM")     # mesh object + its SOCKET_Flame_NN empties
    cg.export_candle(obj, cg.EXPORT_DIR)                                # FBX + JSON sidecar

Used by build_candles.py (the fixed variant set) and candle_tool_addon.py (the "Mars Candles" sidebar panel).

The field. Every candle is a capped cylinder (hand-made wobble in its girth, a slumped foot and softened lip with
`melt`) whose top is a height field: a rim that sags to one side where the wax spilled, and a burnt bowl round the
wick. Drips are tapered capsules hanging from the rim (thin neck, fat bead), the pool is a low rounded disc with a
lobed outline plus a mound round the foot. A candle's own parts are unioned with min(blend_cm, cap) and the candles
with each other with a polynomial smooth minimum of radius blend_cm (0 = hard union), so neighbours fuse; that radius
is full at the floor and eases to blend_top of itself higher up (wax runs down). The floor cuts everything at z = 0. The field is sampled on a numpy grid (voxel_cm), the surface extracted by naive SURFACE
NETS written in numpy (one vertex per sign-changing cell, one quad per sign-changing grid edge), then Blender's
collapse decimator takes it to target_tris and the mesh is flat shaded.

Mesh contract (the Unreal flicker material reads this):
  slots     Wax, Wick, Flame (in that order; Flame is absent when lit = False)
  "Col"     corner colours, linear. Wax: RGB = the facet's wax colour (owner candle's colour, blended where candles
            fuse, darker in the bowl and toward the foot), A = cavity / AO 0..1 (1 open). Wick: near black, A = 1.
            Flame: white, A = 1.
  UV0       "UVMap", a Smart UV atlas.
  UV1       "CandleData". u = the candle's random id in 0..1, constant over a triangle: the same value on that
            candle's wax, wick and flame; a wax triangle belongs to the candle whose own field is smallest at its
            centre (= the nearest candle axis once girth and height are taken into account). v as UNREAL reads it:
            Flame = height along the flame (0 at its base, 1 at the tip); Wax = glow (1 from the candle's lowest rim
            point / bowl floor upward, falling smoothly to 0 GLOW_FALLOFF_CM below it, and faded out sideways
            between GLOW_RADIAL_CM beyond the candle's girth, so pool wax far from a flame is 0); Wick = 0.
            Blender stores v as 1 - value because the FBX -> Unreal import flips V (the MeatCube ShapeXY convention):
            Unreal's TexCoord[1] is (id, value).
  sockets   one empty per flame, SOCKET_Flame_00 .. parented to the mesh, at the middle of the flame.
  sidecar   "candles": id, base / flame centre in Unreal local cm, radius, height, flame socket name, flame size.

Geometry is in CENTIMETRES, Blender axes, Z up; Unreal local = (x, -y, z). Origin = the floor under the cluster
centre (the centre of the candles' footprint); the underside is flat on z = 0.
"""
import json
import math
import os
import sys
import time
from dataclasses import asdict, dataclass, fields

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import cooking_spec as _base   # noqa: E402
import food_common as fc        # noqa: E402

EXPORT_DIR = os.path.join(_base.EXPORT_DIR, "candles")           # D:\Repo\Content\Cooking\export\candles
REVIEW_DIR = os.path.join(EXPORT_DIR, "review")
BLEND_DIR = os.path.join(_base.SOURCE_DIR, "candles")

SLOTS = ("Wax", "Wick", "Flame")
WAX, WICK, FLAME = 0, 1, 2
DATA_UV = "CandleData"
COLOR_ATTR = "Col"
SUFFIX = "_Mars_SM"

GLOW_FALLOFF_CM = 7.0            # glow 1 at the rim -> 0 this far below it
GLOW_RADIAL_CM = (1.5, 6.0)      # glow fades between these distances beyond the candle's girth
FLAME_SIDES = 6
FLAME_RINGS = (0.10, 0.30, 0.56, 0.82)                  # heights of the flame's rings (0 base .. 1 tip)
FLAME_PROFILE = (0.62, 1.00, 0.74, 0.36)                # their radius as a fraction of the half width
WICK_SIDES = 4
FLAME_SINK_CM = 0.2              # the flame's base sits this far below the wick tip so no gap shows
EXTRA_TRIS_LIT = FLAME_SIDES * 2 * len(FLAME_RINGS) + (WICK_SIDES * 4 + 4)      # flame + wick triangles per candle
EXTRA_TRIS_UNLIT = WICK_SIDES * 4 + 4
BLEND_FALLOFF_CM = 6.0           # height over which the candle-to-candle blend eases to blend_top
DRIP_DECK = 10                   # drip candidates per candle; melt switches them on one by one
MAX_GRID_CELLS = 7_000_000

PALETTES = {
    # name: [(weight, sRGB 8-bit), ...]; "mixed" adds the accents by accent_chance
    "cream": [(1.0, (238, 228, 203)), (1.0, (230, 216, 186)), (0.8, (242, 235, 216)), (0.6, (223, 207, 172))],
    "tallow": [(1.0, (228, 200, 138)), (1.0, (216, 184, 118)), (0.8, (235, 212, 156)), (0.6, (203, 168, 100))],
    "mixed": [(1.0, (238, 228, 203)), (0.9, (230, 216, 186)), (0.7, (228, 200, 138)), (0.5, (216, 184, 118)),
              (0.5, (242, 235, 216))],
    "red": [(1.0, (150, 30, 32)), (0.8, (128, 22, 30)), (0.5, (172, 44, 40))],
    "purple": [(1.0, (92, 54, 122)), (0.8, (76, 44, 108)), (0.5, (112, 70, 140))],
}
ACCENTS = ((150, 30, 32), (128, 22, 30), (92, 54, 122), (78, 46, 110))      # red, red, purple, purple
PALETTE_NAMES = tuple(PALETTES)


# ================================================================ parameters
@dataclass
class CandleParams:
    seed: int = 1
    count: int = 5                    # 1..12 candles
    radius_min_cm: float = 1.6        # girth range (about 1.2 .. 4.5)
    radius_max_cm: float = 3.6
    height_min_cm: float = 5.0        # height range (about 4 .. 30)
    height_max_cm: float = 26.0
    height_variation: float = 0.8     # 0 = every candle at the mean height, 1 = the full min..max spread
    spread_cm: float = 0.4            # gap between neighbouring candles' sides; 0 touches, negative overlaps
    blend_cm: float = 1.5             # SDF smooth-union radius: 0 = hard union, larger = more melted together
    blend_top: float = 0.5            # share of blend_cm kept high up (1 = uniform; lower = fused at the foot, distinct tops)
    melt: float = 0.5                 # 0..1 slumped rims, burnt bowl, drips, pool size
    palette: str = "mixed"            # cream / tallow / mixed / red / purple
    accent_chance: float = 0.2        # "mixed" only: chance of a red or purple candle
    lean: float = 0.5                 # 0..1 how far the candles tilt off vertical (hand-made irregularity)
    lit: bool = True                  # False = wicks only, no flame geometry (sockets stay)
    closed_base: bool = True          # keep the flat underside (a closed shell); False drops those hidden faces
    voxel_cm: float = 0.4             # SDF sampling resolution
    target_tris: int = 2400           # whole mesh: wax + wicks + flames

    def clamped(self):
        p = CandleParams(**asdict(self))
        p.seed = int(p.seed)
        p.count = int(np.clip(p.count, 1, 12))
        p.radius_min_cm = float(np.clip(p.radius_min_cm, 0.8, 8.0))
        p.radius_max_cm = float(np.clip(max(p.radius_max_cm, p.radius_min_cm), 0.8, 8.0))
        p.height_min_cm = float(np.clip(p.height_min_cm, 2.0, 60.0))
        p.height_max_cm = float(np.clip(max(p.height_max_cm, p.height_min_cm), 2.0, 60.0))
        p.height_variation = float(np.clip(p.height_variation, 0.0, 1.0))
        p.spread_cm = float(np.clip(p.spread_cm, -2.0, 20.0))
        p.blend_cm = float(np.clip(p.blend_cm, 0.0, 8.0))
        p.blend_top = float(np.clip(p.blend_top, 0.0, 1.0))
        p.melt = float(np.clip(p.melt, 0.0, 1.0))
        p.accent_chance = float(np.clip(p.accent_chance, 0.0, 1.0))
        p.lean = float(np.clip(p.lean, 0.0, 1.0))
        p.voxel_cm = float(np.clip(p.voxel_cm, 0.15, 1.5))
        p.target_tris = int(np.clip(p.target_tris, 120, 60000))
        if p.palette not in PALETTES:
            p.palette = "mixed"
        return p


PARAM_NAMES = tuple(f.name for f in fields(CandleParams))


def _rng(seed, stream, index=0):
    """Independent random streams, so changing one control (heights, melt, blend) leaves the others' dice alone."""
    return np.random.default_rng([int(seed) & 0x7FFFFFFF, int(stream), int(index)])


def _smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _smin(a, b, k):
    """Polynomial smooth minimum of radius k (k may be an array); k = 0 is the hard minimum."""
    if np.isscalar(k) and k <= 1e-6:
        return np.minimum(a, b)
    kk = np.maximum(k, 1e-6)
    h = np.maximum(kk - np.abs(a - b), 0.0) / kk
    return np.minimum(a, b) - h * h * kk * 0.25


# ================================================================ the candles (layout + per-candle dice)
class Candle:
    """One candle's numbers (cm, Blender axes). Built by layout(); read by the field, the dressing and the sidecar."""
    __slots__ = ("index", "id", "x", "y", "radius", "height", "lean", "color", "ph", "spill", "drop", "rim_noise",
                 "lumps",
                 "bowl_depth", "bowl_radius", "round", "foot", "lip", "drips", "pool_r", "pool_h", "pool_off",
                 "pool_ph", "mound_r", "mound_h", "extent", "wick_base", "wick_tip", "flame_base", "flame_w",
                 "flame_h", "flame_tip", "glow_z", "surface_z", "socket")


def layout(params):
    """The candles of a cluster, placed and diced. Heights come from a stratified 0..1 rank per candle scaled by
    height_variation round the mean, so variation 1 always reaches both ends of the range."""
    p = params
    n = p.count
    r_radius, r_height, r_place, r_id = (_rng(p.seed, s) for s in (11, 12, 13, 14))

    def strata(rng, count):
        if count == 1:
            return np.array([rng.uniform(0.0, 1.0)])
        u = np.linspace(0.0, 1.0, count)
        u[1:-1] += rng.uniform(-0.3, 0.3, size=count - 2) / (count - 1)
        return rng.permutation(u)

    u_h = strata(r_height, n)
    u_r = strata(r_radius, n)
    mean_h = 0.5 * (p.height_min_cm + p.height_max_cm)
    heights = mean_h + (u_h - 0.5) * (p.height_max_cm - p.height_min_cm) * p.height_variation
    radii = p.radius_min_cm + u_r * (p.radius_max_cm - p.radius_min_cm)
    ids = r_id.permutation((np.arange(n) + r_id.uniform(0.2, 0.8, size=n)) / n)      # distinct, well apart, never 0 / 1

    # placement: the tall ones first (they end up in the middle), each next candle against a random placed one at the
    # asked gap, keeping the cluster compact. Uses the height RANK, not the height, so the layout survives the
    # height_variation control.
    order = np.argsort(-(u_h + r_place.uniform(-0.25, 0.25, size=n)))
    pos = np.zeros((n, 2))
    placed = []
    for i in order:
        if not placed:
            placed.append(i)
            continue
        best, best_cost = None, 1e9
        centroid = pos[placed].mean(axis=0)
        for _ in range(60):
            a = placed[r_place.integers(len(placed))]
            ang = r_place.uniform(0.0, math.tau)
            gap = p.spread_cm * r_place.uniform(0.7, 1.3) if p.spread_cm >= 0.0 else p.spread_cm
            dist = max(radii[a] + radii[i] + gap, 0.55 * (radii[a] + radii[i]))
            cand = pos[a] + dist * np.array([math.cos(ang), math.sin(ang)])
            ok = True
            for j in placed:
                need = max(radii[j] + radii[i] + min(p.spread_cm, gap) * 0.85, 0.55 * (radii[j] + radii[i]))
                if np.linalg.norm(cand - pos[j]) < need - 1e-6:
                    ok = False
                    break
            if not ok:
                continue
            cost = np.linalg.norm(cand - centroid) + r_place.uniform(0.0, 1.5 + 0.3 * p.spread_cm)
            if cost < best_cost:
                best, best_cost = cand, cost
        if best is None:                                   # crowded: push it out along a random ray until it fits
            ang = r_place.uniform(0.0, math.tau)
            d = 0.0
            while True:
                d += 0.5
                cand = pos[placed].mean(axis=0) + d * np.array([math.cos(ang), math.sin(ang)])
                if all(np.linalg.norm(cand - pos[j]) >= radii[j] + radii[i] + max(p.spread_cm, 0.0) for j in placed):
                    best = cand
                    break
        pos[i] = best
        placed.append(i)
    lo = (pos - radii[:, None]).min(axis=0)
    hi = (pos + radii[:, None]).max(axis=0)
    pos -= 0.5 * (lo + hi)                                 # origin under the centre of the footprint

    colours = _colours(p)
    out = []
    for i in range(n):
        c = Candle()
        rng = _rng(p.seed, 21, i)
        R, H, m = float(radii[i]), float(heights[i]), p.melt
        c.index, c.id, c.x, c.y, c.radius, c.height = i, float(ids[i]), float(pos[i, 0]), float(pos[i, 1]), R, H
        ang = rng.uniform(0.0, math.tau)
        tilt = p.lean * rng.uniform(0.0, 0.035) * min(1.0, 14.0 / H)       # tall candles lean less per cm
        c.lean = (tilt * math.cos(ang), tilt * math.sin(ang))
        c.color = colours[i]
        c.ph = rng.uniform(0.0, math.tau, size=6)
        spill = rng.uniform(0.0, math.tau)
        c.spill = (math.cos(spill), math.sin(spill))                       # the side the rim sagged / wax ran out
        c.drop = m * rng.uniform(0.45, 1.0) * min(0.9 + 0.6 * R, 0.34 * H)
        c.rim_noise = m * rng.uniform(0.2, 0.45)
        c.lumps = 0.07 + 0.22 * m
        c.bowl_radius = max(R - (0.45 + 0.1 * R), 0.45 * R)
        c.bowl_depth = 0.15 + m * (0.3 + 0.42 * R * rng.uniform(0.6, 1.0))
        c.bowl_depth = min(c.bowl_depth, 0.45 * H)
        c.round = min(0.18 + 0.3 * m, 0.3 * R)
        c.foot = m * rng.uniform(0.08, 0.2)
        c.lip = m * rng.uniform(0.04, 0.11)
        # drips: a fixed deck of candidates per candle, each switched on once melt passes its threshold
        drips = []
        rd = _rng(p.seed, 22, i)
        for k in range(DRIP_DECK):
            thresh = (k + rd.uniform(0.1, 0.9)) / DRIP_DECK * 0.92
            theta = spill + rd.normal(0.0, 1.1) if k % 3 else rd.uniform(0.0, math.tau)
            frac = rd.uniform(0.2, 0.9)
            r0 = rd.uniform(0.3, 0.46) * (0.8 + 0.13 * R)
            r1 = r0 * rd.uniform(1.6, 2.3)
            sway = rd.uniform(-0.3, 0.3)
            if m <= thresh:
                continue
            grow = min(1.0, (m - thresh) / 0.35 + 0.35)
            length = min(frac * grow * (2.5 + 0.6 * H), H * 0.97)
            drips.append((theta, length, r0, r1, sway))
        c.drips = drips
        rp = _rng(p.seed, 23, i)
        u1, u2, u3 = rp.uniform(0.0, 1.0, size=3)
        c.pool_h = max((m ** 0.6) * (0.4 + 0.5 * u1 + 0.06 * R), 0.6) if m > 0.08 else 0.0
        c.pool_r = R + (m ** 0.8) * (1.2 + 3.2 * u2) * (0.7 + 0.2 * R)
        off = m * u3 * 0.45 * R
        c.pool_off = (c.spill[0] * off, c.spill[1] * off)
        c.pool_ph = rp.uniform(0.0, math.tau, size=3)
        c.mound_r = R + 0.38 * (c.pool_r - R)
        c.mound_h = c.pool_h * 1.9
        c.extent = max(R * 1.3 + 2.0, c.pool_r * 1.4 + off + c.pool_h) + abs(tilt) * H
        rf = _rng(p.seed, 24, i)
        girth = np.clip((R - 1.2) / 3.3, 0.0, 1.0)
        c.flame_w = float(np.clip(1.6 + 0.7 * girth + rf.uniform(-0.08, 0.1), 1.6, 2.4))
        c.flame_h = float(np.clip(4.0 + 2.2 * girth + rf.uniform(-0.3, 0.4), 4.0, 6.5))
        c.socket = "Flame_%02d" % i
        out.append(c)
    return out


def _colours(p):
    rng = _rng(p.seed, 31)
    table = PALETTES[p.palette]
    w = np.array([t[0] for t in table])
    out = []
    for _ in range(p.count):
        if p.palette == "mixed" and rng.uniform() < p.accent_chance:
            rgb = fc.srgb(*ACCENTS[rng.integers(len(ACCENTS))])
        else:
            rgb = fc.srgb(*table[rng.choice(len(table), p=w / w.sum())][1])
        out.append(np.clip(rgb * rng.uniform(0.94, 1.05) * (1.0 + rng.uniform(-0.03, 0.03, size=3)), 0.0, 1.0))
    return out


# ================================================================ the field
def _girth(c, theta, z):
    """The candle's radius at angle theta and height z (wobble, slumped foot, softened lip)."""
    R, H = c.radius, c.height
    wob = 1.0 + 0.035 * np.sin(3.0 * theta + c.ph[0] + 0.21 * z) + 0.022 * np.sin(5.0 * theta + c.ph[1] - 0.13 * z)
    foot = c.foot * np.exp(-np.maximum(z, 0.0) / (0.16 * H + 0.8))
    lip = c.lip * np.exp(-((z - (H - 1.0)) / 0.9) ** 2)
    return R * (wob + foot + lip)


def _top(c, x, y, r, theta):
    """Height of the candle's top surface over the point (x, y) local to its axis: sagging rim + burnt bowl."""
    s = (x * c.spill[0] + y * c.spill[1]) / c.radius
    drop = c.drop * _smoothstep(-0.5, 1.0, s) ** 1.4
    drop = drop + c.rim_noise * (0.5 + 0.5 * np.sin(4.0 * theta + c.ph[2])) * _smoothstep(0.35 * c.radius, c.radius, r)
    bowl = c.bowl_depth * (1.0 - _smoothstep(0.2 * c.bowl_radius, c.bowl_radius, r))
    return c.height - drop - bowl


def candle_sdf(c, x, y, z, k_part, k_pool):
    """One candle's own field (body, drips, pool) at broadcastable x, y, z (cm). Approximate distance, negative inside."""
    lx = x - c.x - c.lean[0] * z
    ly = y - c.y - c.lean[1] * z
    r = np.hypot(lx, ly)
    theta = np.arctan2(ly, lx)
    rho = c.round
    dx = r - (_girth(c, theta, z) - rho)
    dz = z - (_top(c, lx, ly, r, theta) - rho)
    d = np.minimum(np.maximum(dx, dz), 0.0) + np.hypot(np.maximum(dx, 0.0), np.maximum(dz, 0.0)) - rho
    # a lumpy, hand-poured skin (stronger the more it has melted)
    d = d - c.lumps * (np.sin(1.37 * x + c.ph[3]) * np.sin(1.21 * y + c.ph[4]) * np.sin(0.71 * z + c.ph[5])
                       + 0.45 * np.sin(4.0 * theta + c.ph[2]) * np.sin(0.47 * z + c.ph[3]) * (r > 0.5 * c.radius))
    for theta_d, length, r0, r1, sway in c.drips:
        za = float(_top(c, c.radius * math.cos(theta_d), c.radius * math.sin(theta_d), c.radius, theta_d)) - 0.15
        zb = max(za - length, 0.05)
        tb = theta_d + sway * 0.25
        ra = float(_girth(c, theta_d, za)) - 0.1 * r0
        rb = float(_girth(c, tb, zb)) + 0.12 * r1
        ax, ay = c.x + c.lean[0] * za + ra * math.cos(theta_d), c.y + c.lean[1] * za + ra * math.sin(theta_d)
        bx, by = c.x + c.lean[0] * zb + rb * math.cos(tb), c.y + c.lean[1] * zb + rb * math.sin(tb)
        ex, ey, ez = bx - ax, by - ay, zb - za
        t = np.clip(((x - ax) * ex + (y - ay) * ey + (z - za) * ez) / (ex * ex + ey * ey + ez * ez), 0.0, 1.0)
        dist = np.sqrt((x - ax - t * ex) ** 2 + (y - ay - t * ey) ** 2 + (z - za - t * ez) ** 2)
        d = _smin(d, dist - (r0 + (r1 - r0) * t ** 2.2), k_part)
    if c.pool_h > 0.1:
        px = x - c.x - c.pool_off[0]
        py = y - c.y - c.pool_off[1]
        pr = np.hypot(px, py)
        pt = np.arctan2(py, px)
        lobes = 1.0 + 0.16 * np.sin(2.0 * pt + c.pool_ph[0]) + 0.11 * np.sin(3.0 * pt + c.pool_ph[1]) \
            + 0.07 * np.sin(5.0 * pt + c.pool_ph[2])
        edge = c.pool_r * lobes
        thick = c.pool_h * (0.5 + 0.5 * (1.0 - np.clip(pr / edge, 0.0, 1.0) ** 2))        # domed: thinner at the edge
        pool = np.hypot(np.maximum(pr - (edge - thick), 0.0), z) - thick
        mound = np.hypot(np.maximum(r - (c.mound_r - c.mound_h), 0.0), z) - c.mound_h
        d = _smin(d, _smin(pool, mound, k_pool), k_pool)
    return d


class Field:
    """The whole cluster's wax field."""

    def __init__(self, params, candles):
        self.p = params
        self.candles = candles
        self.k = params.blend_cm
        self.k_part = min(params.blend_cm, 0.9)            # a candle's drips against its own body
        self.k_pool = min(params.blend_cm, 2.2)            # its pool against its own foot

    def k_at(self, z):
        """The candle-to-candle blend radius at height z: all of blend_cm at the floor, easing to blend_top of it
        (wax runs down, so candles fuse most at the foot)."""
        top = self.p.blend_top
        return self.k * (top + (1.0 - top) * np.exp(-np.maximum(z, 0.0) / BLEND_FALLOFF_CM))

    def per_candle(self, pts):
        """(n_candles, n) own-field value of every candle at points (n, 3)."""
        x, y, z = pts[:, 0], pts[:, 1], pts[:, 2]
        return np.stack([candle_sdf(c, x, y, z, self.k_part, self.k_pool) for c in self.candles])

    def at(self, pts, floor=True):
        d_all = self.per_candle(np.asarray(pts, float))
        d = d_all[0]
        kz = self.k_at(np.asarray(pts, float)[:, 2])
        for k in range(1, len(d_all)):
            d = _smin(d, d_all[k], kz)
        if floor:
            d = np.maximum(d, -np.asarray(pts, float)[:, 2])
        return d

    def grid(self, voxel):
        """Sample on a grid: (values (nx, ny, nz), origin, voxel). Each candle is evaluated only in the block it can
        reach; outside it the candle is farther than the blend radius, so it cannot move the surface there."""
        cs = self.candles
        pad = self.k + 2.5 * voxel
        lo = np.array([min(c.x - c.extent for c in cs) - pad, min(c.y - c.extent for c in cs) - pad, -1.5 * voxel])
        hi = np.array([max(c.x + c.extent for c in cs) + pad, max(c.y + c.extent for c in cs) + pad,
                       max(c.height for c in cs) + 0.25 * self.k + 3.0 * voxel + 1.0])
        while np.prod(np.ceil((hi - lo) / voxel) + 1) > MAX_GRID_CELLS:
            voxel *= 1.15
            lo[2] = -1.5 * voxel
        n = (np.ceil((hi - lo) / voxel) + 1).astype(int)
        axes = [lo[a] + np.arange(n[a]) * voxel for a in range(3)]
        total = np.full(tuple(n), 1e3)
        for c in cs:
            b_lo = np.array([c.x - c.extent - pad, c.y - c.extent - pad, lo[2]])
            b_hi = np.array([c.x + c.extent + pad, c.y + c.extent + pad, c.height + 0.25 * self.k + pad + 1.0])
            i0 = [max(int(np.searchsorted(axes[a], b_lo[a])) - 1, 0) for a in range(3)]
            i1 = [min(int(np.searchsorted(axes[a], b_hi[a])) + 1, n[a]) for a in range(3)]
            sl = tuple(slice(i0[a], i1[a]) for a in range(3))
            d = candle_sdf(c, axes[0][sl[0], None, None], axes[1][None, sl[1], None], axes[2][None, None, sl[2]],
                           self.k_part, self.k_pool)
            total[sl] = _smin(total[sl], d, self.k_at(axes[2])[None, None, sl[2]])
        total = np.maximum(total, -axes[2][None, None, :])                 # the floor
        return total, lo, voxel


# ================================================================ surface nets (numpy)
_CORNERS = [(dx, dy, dz) for dx in (0, 1) for dy in (0, 1) for dz in (0, 1)]
_EDGES = [(a, b) for a in _CORNERS for b in _CORNERS if a < b and sum(abs(a[k] - b[k]) for k in range(3)) == 1]


def fill_pinches(values, voxel):
    """Surface nets makes a non-manifold edge wherever a grid face has a checkerboard of signs (two sheets of the
    surface touching through one cell face). Fill those: the two outside corners of such a face go just inside.
    Repeats until none is left (filling can expose another). Works on values in place; returns the number filled."""
    eps = -0.02 * voxel
    total = 0
    for _ in range(12):
        inside = values < 0.0
        found = 0
        for axis in range(3):
            def view(arr, da, db):
                sl = [slice(None)] * 3
                o = [k for k in range(3) if k != axis]
                sl[o[0]] = slice(da, arr.shape[o[0]] - 1 + da)
                sl[o[1]] = slice(db, arr.shape[o[1]] - 1 + db)
                return arr[tuple(sl)]
            a, b, c, d = (view(inside, 0, 0), view(inside, 1, 0), view(inside, 1, 1), view(inside, 0, 1))
            one = a & c & ~b & ~d
            two = b & d & ~a & ~c
            n = int(one.sum() + two.sum())
            if n:
                view(values, 1, 0)[one] = eps
                view(values, 0, 1)[one] = eps
                view(values, 0, 0)[two] = eps
                view(values, 1, 1)[two] = eps
                found += n
                inside = values < 0.0
        total += found
        if not found:
            break
    return total


def surface_nets(values, origin, voxel):
    """Naive surface nets of the zero level set (negative inside): one vertex per cell that the surface crosses, at
    the mean of its edge crossings; one quad per grid edge that changes sign. Returns (verts (n, 3) cm, quads (m, 4))."""
    inside = values < 0.0
    nx, ny, nz = values.shape
    count = np.zeros((nx - 1, ny - 1, nz - 1), np.int8)
    for dx, dy, dz in _CORNERS:
        count += inside[dx:nx - 1 + dx, dy:ny - 1 + dy, dz:nz - 1 + dz]
    active = (count > 0) & (count < 8)
    ci, cj, ck = np.nonzero(active)
    n = len(ci)
    if n == 0:
        return np.zeros((0, 3)), np.zeros((0, 4), np.int64)
    cell_id = np.full(active.shape, -1, np.int64)
    cell_id[ci, cj, ck] = np.arange(n)
    acc = np.zeros((n, 3))
    num = np.zeros(n)
    for a, b in _EDGES:
        fa = values[ci + a[0], cj + a[1], ck + a[2]]
        fb = values[ci + b[0], cj + b[1], ck + b[2]]
        cross = (fa < 0.0) != (fb < 0.0)
        denom = np.where(cross, fa - fb, 1.0)
        t = np.where(cross, fa / denom, 0.0)
        for ax in range(3):
            acc[:, ax] += cross * (a[ax] + t * (b[ax] - a[ax]))
        num += cross
    verts = (np.stack([ci, cj, ck], axis=1) + acc / num[:, None]) * voxel + np.asarray(origin, float)

    quads = []
    # x edges: grid points (i, j + 1, k + 1) -> (i + 1, j + 1, k + 1); the four cells round the edge
    i, j, k = np.nonzero(inside[:-1, 1:-1, 1:-1] != inside[1:, 1:-1, 1:-1])
    q = np.stack([cell_id[i, j, k], cell_id[i, j + 1, k], cell_id[i, j + 1, k + 1], cell_id[i, j, k + 1]], axis=1)
    flip = inside[i, j + 1, k + 1]
    q[flip] = q[flip][:, ::-1]
    quads.append(q)
    # y edges
    i, j, k = np.nonzero(inside[1:-1, :-1, 1:-1] != inside[1:-1, 1:, 1:-1])
    q = np.stack([cell_id[i, j, k], cell_id[i, j, k + 1], cell_id[i + 1, j, k + 1], cell_id[i + 1, j, k]], axis=1)
    flip = inside[i + 1, j, k + 1]
    q[flip] = q[flip][:, ::-1]
    quads.append(q)
    # z edges
    i, j, k = np.nonzero(inside[1:-1, 1:-1, :-1] != inside[1:-1, 1:-1, 1:])
    q = np.stack([cell_id[i, j, k], cell_id[i + 1, j, k], cell_id[i + 1, j + 1, k], cell_id[i, j + 1, k]], axis=1)
    flip = inside[i + 1, j + 1, k]
    q[flip] = q[flip][:, ::-1]
    quads.append(q)
    quads = np.concatenate(quads)
    return verts, quads[(quads >= 0).all(axis=1)]


# ================================================================ mesh helpers
def _mesh_arrays(mesh):
    """(verts cm (n, 3), tris (m, 3)) of a triangle mesh datablock."""
    v = np.empty(len(mesh.vertices) * 3)
    mesh.vertices.foreach_get("co", v)
    if any(len(p.vertices) != 3 for p in mesh.polygons):
        raise RuntimeError("candle_gen: expected triangles")
    t = np.empty(len(mesh.polygons) * 3, np.int64)
    mesh.polygons.foreach_get("vertices", t)
    return v.reshape(-1, 3) * 100.0, t.reshape(-1, 3)


def _decimate(verts_cm, quads, target_tris):
    """Blender's collapse decimator on a throwaway object: surface-nets quads -> about target_tris triangles."""
    import bmesh
    mesh = bpy.data.meshes.new("_CandleWaxHi")
    mesh.from_pydata((verts_cm * 0.01).tolist(), [], quads.tolist())
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("_CandleWaxHi", mesh)
    bpy.context.scene.collection.objects.link(obj)
    full = len(mesh.polygons)
    result = None
    try:
        ratio = min(1.0, target_tris / max(full, 1))
        for _ in range(5):
            mod = obj.modifiers.new("Decimate", "DECIMATE")
            mod.decimate_type = "COLLAPSE"
            mod.ratio = ratio
            mod.use_collapse_triangulate = True
            dg = bpy.context.evaluated_depsgraph_get()
            dg.update()
            low = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
            obj.modifiers.remove(mod)
            got = len(low.polygons)
            if result is not None:
                bpy.data.meshes.remove(result)
            result = low
            if got <= target_tris:
                break
            ratio *= 0.97 * target_tris / got
        out = _mesh_arrays(result)
    finally:
        bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.meshes.remove(mesh)
        if result is not None:
            bpy.data.meshes.remove(result)
    return out[0], out[1], full


def _clean(verts, tris, closed_base, floor_eps):
    """Snap the underside flat onto z = 0, drop degenerate triangles (and the underside when asked), compact."""
    verts = verts.copy()
    verts[verts[:, 2] < floor_eps, 2] = 0.0
    a, b, c = verts[tris[:, 0]], verts[tris[:, 1]], verts[tris[:, 2]]
    area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    keep = area > 1e-6
    if not closed_base:
        keep &= ~((a[:, 2] == 0.0) & (b[:, 2] == 0.0) & (c[:, 2] == 0.0))
    tris = tris[keep]
    # a feature the decimator flattened leaves two triangles on the same three vertices: drop both (a zero-volume flap)
    key = np.sort(tris, axis=1)
    _, inverse, counts = np.unique(key, axis=0, return_inverse=True, return_counts=True)
    tris = tris[counts[inverse.ravel()] == 1]
    used = np.unique(tris)
    remap = np.full(len(verts), -1, np.int64)
    remap[used] = np.arange(len(used))
    return verts[used], remap[tris]


def _flame(c, rng):
    """A closed faceted teardrop: (verts, tris, height 0..1 per vertex). Base pole at c.flame_base."""
    n = FLAME_SIDES
    base = np.array(c.flame_base)
    h, half = c.flame_h, 0.5 * c.flame_w
    bend = rng.uniform(-1.0, 1.0, size=2) * 0.06 * h           # the tip wanders off the axis
    spin = rng.uniform(0.0, math.tau)
    verts, hv = [base.copy()], [0.0]
    for t, f in zip(FLAME_RINGS, FLAME_PROFILE):
        t = t + rng.uniform(-0.025, 0.025)
        centre = base + np.array([bend[0] * t * t, bend[1] * t * t, h * t])
        spin += rng.uniform(0.25, 0.6)
        for s in range(n):
            a = spin + math.tau * s / n
            rr = half * f * rng.uniform(0.9, 1.08)
            verts.append(centre + np.array([rr * math.cos(a), rr * math.sin(a), rng.uniform(-0.03, 0.03) * h]))
            hv.append(t)
    tip = base + np.array([bend[0], bend[1], h])
    verts.append(tip)
    hv.append(1.0)
    verts = np.array(verts)
    hv = np.clip((verts[:, 2] - base[2]) / (tip[2] - base[2]), 0.0, 1.0)     # true normalised height
    tris = []
    rings = len(FLAME_RINGS)
    for s in range(n):
        s2 = (s + 1) % n
        tris.append((0, 1 + s2, 1 + s))
        for k in range(rings - 1):
            a, b = 1 + k * n, 1 + (k + 1) * n
            tris.append((a + s, a + s2, b + s2))
            tris.append((a + s, b + s2, b + s))
        last = 1 + (rings - 1) * n
        tris.append((last + s, last + s2, len(verts) - 1))
    return verts, np.array(tris), hv


def _wick(c, rng):
    """A thin bent 4-sided wick from inside the wax to c.wick_tip: (verts, tris)."""
    n = WICK_SIDES
    base, tip = np.array(c.wick_base), np.array(c.wick_tip)
    mid = base + (tip - base) * 0.6 + np.array([rng.uniform(-0.08, 0.08), rng.uniform(-0.08, 0.08), 0.0])
    spin = rng.uniform(0.0, math.tau)
    verts = []
    for centre, rad in ((base, 0.17), (mid, 0.16), (tip, 0.11)):
        for s in range(n):
            a = spin + math.tau * s / n
            verts.append(centre + np.array([rad * math.cos(a), rad * math.sin(a), 0.0]))
        spin += 0.4
    tris = []
    for k in range(2):
        a, b = k * n, (k + 1) * n
        for s in range(n):
            s2 = (s + 1) % n
            tris.append((a + s, a + s2, b + s2))
            tris.append((a + s, b + s2, b + s))
    tris += [(0, 2, 1), (0, 3, 2), (2 * n, 2 * n + 1, 2 * n + 2), (2 * n, 2 * n + 2, 2 * n + 3)]
    return np.array(verts), np.array(tris)


def _material(name):
    """Slot material by name; a new one gets a small preview node set-up (vertex colour wax, glowing flame)."""
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = next((nd for nd in nt.nodes if nd.type == "BSDF_PRINCIPLED"), None)
        if bsdf is not None:
            if name == "Wax":
                attr = nt.nodes.new("ShaderNodeVertexColor")
                attr.layer_name = COLOR_ATTR
                nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
                bsdf.inputs["Roughness"].default_value = 0.45
            elif name == "Wick":
                bsdf.inputs["Base Color"].default_value = (0.012, 0.01, 0.009, 1.0)
            elif name == "Flame":
                bsdf.inputs["Base Color"].default_value = (1.0, 0.75, 0.3, 1.0)
                bsdf.inputs["Emission Color"].default_value = (1.0, 0.62, 0.2, 1.0)
                bsdf.inputs["Emission Strength"].default_value = 6.0
        mat.diffuse_color = {"Wax": (0.85, 0.78, 0.62, 1.0), "Wick": (0.02, 0.02, 0.02, 1.0),
                             "Flame": (1.0, 0.7, 0.25, 1.0)}.get(name, (0.8, 0.8, 0.8, 1.0))
    except Exception as exc:                                   # preview only; never fail a build over it
        print("candle_gen: preview material %s skipped (%s)" % (name, exc))
    return mat


def sockets_of(obj):
    return sorted((o for o in bpy.data.objects if o.parent is obj and o.get("candle_socket")),
                  key=lambda o: o["candle_socket"])


def remove_candle(obj):
    """Delete a generated candle object with its socket empties and mesh."""
    for e in [o for o in bpy.data.objects if o.parent is obj]:
        bpy.data.objects.remove(e, do_unlink=True)
    mesh = obj.data
    bpy.data.objects.remove(obj, do_unlink=True)
    if mesh is not None and mesh.users == 0:
        bpy.data.meshes.remove(mesh)


# ================================================================ generate
def generate(params=None, name="Candle_Preview" + SUFFIX, collection=None, verbose=True):
    """Build the candle mesh object for params (a CandleParams) in the current scene. Returns (object, info) where
    info carries the per-candle table, the timings and the counts. The object keeps its params and candle table in
    the custom properties "_candle_params" / "_candle_info" (JSON) for export_candle."""
    p = (params or CandleParams()).clamped()
    t0 = time.time()
    candles = layout(p)
    field = Field(p, candles)
    extra = EXTRA_TRIS_LIT if p.lit else EXTRA_TRIS_UNLIT
    wax_target = max(p.target_tris - extra * p.count, 80)

    values, origin, voxel = field.grid(p.voxel_cm)
    t1 = time.time()
    fill_pinches(values, voxel)
    hi_verts, quads = surface_nets(values, origin, voxel)
    if len(quads) == 0:
        raise RuntimeError("candle_gen: the field has no surface")
    t2 = time.time()
    verts, tris, full_tris = _decimate(hi_verts, quads, wax_target)
    verts, tris = _clean(verts, tris, p.closed_base, floor_eps=0.3 * voxel)
    t3 = time.time()

    # ---- the wick and flame of every candle, standing on the wax surface at its axis
    wax_v, wax_t = len(verts), len(tris)
    parts_v, parts_t, slot = [verts], [tris], [np.full(len(tris), WAX)]
    part_candle = [np.full(len(tris), -1)]
    flame_h = [np.zeros(len(verts))]
    base = len(verts)
    for c in candles:
        zs = np.arange(c.height + 0.25 * p.blend_cm + 2.5, 0.0, -0.05)
        line = np.stack([c.x + c.lean[0] * zs, c.y + c.lean[1] * zs, zs], axis=1)
        inside = np.nonzero(field.at(line) < 0.0)[0]
        c.surface_z = float(zs[inside[0]]) if len(inside) else float(c.height - c.bowl_depth)
        ax, ay = c.x + c.lean[0] * c.surface_z, c.y + c.lean[1] * c.surface_z
        rw = _rng(p.seed, 41, c.index)
        length = rw.uniform(0.9, 1.35) + 0.08 * c.radius
        c.wick_base = (ax, ay, max(c.surface_z - 0.45, 0.0))
        c.wick_tip = (ax + rw.uniform(-0.12, 0.12), ay + rw.uniform(-0.12, 0.12), c.surface_z + length)
        c.flame_base = (c.wick_tip[0], c.wick_tip[1], c.wick_tip[2] - FLAME_SINK_CM)
        c.glow_z = min(c.surface_z, c.height - c.drop)          # the lowest point of rim / bowl
        wv, wt = _wick(c, rw)
        parts_v.append(wv)
        parts_t.append(wt + base)
        slot.append(np.full(len(wt), WICK))
        part_candle.append(np.full(len(wt), c.index))
        flame_h.append(np.zeros(len(wv)))
        base += len(wv)
        fv, ft, fh = _flame(c, _rng(p.seed, 42, c.index))
        c.flame_tip = tuple(fv[-1])
        if p.lit:
            parts_v.append(fv)
            parts_t.append(ft + base)
            slot.append(np.full(len(ft), FLAME))
            part_candle.append(np.full(len(ft), c.index))
            flame_h.append(fh)
            base += len(fv)
    all_v = np.concatenate(parts_v)
    all_t = np.concatenate(parts_t)
    slot = np.concatenate(slot)
    owner = np.concatenate(part_candle)
    flame_h = np.concatenate(flame_h)

    # ---- the mesh object
    old = bpy.data.objects.get(name)
    if old is not None:
        remove_candle(old)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata((all_v * 0.01).tolist(), [], all_t.tolist())
    slots = SLOTS if p.lit else SLOTS[:2]
    for s in slots:
        mesh.materials.append(_material(s))
    mesh.polygons.foreach_set("material_index", slot.astype(np.int32))
    mesh.validate(verbose=False)
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    mesh.polygons.foreach_set("use_smooth", [False] * len(mesh.polygons))
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    (collection or bpy.context.scene.collection).objects.link(obj)
    if len(mesh.polygons) != len(all_t):
        raise RuntimeError("candle_gen: mesh.validate dropped faces (%d -> %d)" % (len(all_t), len(mesh.polygons)))

    # ---- who owns each wax triangle, its colour and its glow
    v_now = fc.verts_cm(obj)
    tri = np.empty(len(mesh.polygons) * 3, np.int64)
    mesh.polygons.foreach_get("vertices", tri)
    tri = tri.reshape(-1, 3)
    centres = v_now[tri].mean(axis=1)
    normals = fc.face_normals(obj)
    is_wax = slot == WAX
    d_all = field.per_candle(centres[is_wax])                               # (n_candles, n_wax)
    wax_owner = np.argmin(d_all, axis=0)
    owner[is_wax] = wax_owner
    soft = 0.2 + 0.14 * p.blend_cm
    w = np.exp(-(d_all - d_all.min(axis=0)) / soft)
    w /= w.sum(axis=0)
    colours = np.array([c.color for c in candles])
    wax_rgb = (w.T @ colours)                                               # colours bleed where candles fuse
    cw = centres[is_wax]
    cz, cr, own_h, bowl_r, glow_z = (np.array([getattr(c, a) for c in candles])[wax_owner]
                                     for a in ("x", "radius", "height", "bowl_radius", "glow_z"))
    ox = np.array([c.x for c in candles])[wax_owner] + np.array([c.lean[0] for c in candles])[wax_owner] * cw[:, 2]
    oy = np.array([c.y for c in candles])[wax_owner] + np.array([c.lean[1] for c in candles])[wax_owner] * cw[:, 2]
    rad = np.hypot(cw[:, 0] - ox, cw[:, 1] - oy)
    shade = 0.86 + 0.14 * _smoothstep(0.0, 9.0, cw[:, 2])                    # grubbier toward the foot
    in_bowl = (1.0 - _smoothstep(0.4 * bowl_r, bowl_r, rad)) * (cw[:, 2] > glow_z - 0.3) * (normals[is_wax][:, 2] > 0.3)
    shade = shade * (1.0 - 0.2 * in_bowl)                                    # the molten bowl is darker
    on_drip = _smoothstep(0.25, 0.7, rad - cr * 1.06) * (cw[:, 2] > 1.2)
    shade = shade * (1.0 + 0.05 * on_drip)
    tint = np.stack([np.ones(len(cw)), 1.0 - 0.05 * in_bowl, 1.0 - 0.16 * in_bowl], axis=1)
    rgb = np.ones((len(tri), 3))
    rgb[is_wax] = wax_rgb * shade[:, None] * tint

    # cavity / AO in alpha: the field itself says how enclosed a vertex is (sample it along the normal)
    vn = np.zeros((len(v_now), 3))
    mesh.vertices.foreach_get("normal", vn.reshape(-1))
    ao = np.zeros(len(v_now))
    wax_vert = np.zeros(len(v_now), bool)
    wax_vert[np.unique(tri[is_wax])] = True
    pv, pn = v_now[wax_vert], vn[wax_vert]
    acc = np.zeros(len(pv))
    for step, weight in ((0.7, 0.4), (1.6, 0.35), (3.2, 0.25)):
        q = pv + pn * step
        dist = np.minimum(field.at(q, floor=False), q[:, 2] + 0.6)
        acc += weight * np.clip(dist / step, 0.0, 1.0)
    ao[wax_vert] = acc
    ao[~wax_vert] = 1.0
    cav = fc.cavity(obj)
    alpha = np.where(wax_vert, np.clip(ao * (0.65 + 0.35 * np.clip(cav * 2.0, 0.0, 1.0)), 0.0, 1.0), 1.0)
    fc.paint(obj, rgb, alpha=alpha, variation=0.05, seed=p.seed + 7, cavity_darken=0.38)

    # wick and flame colours are exact (no per-facet jitter)
    attr = mesh.color_attributes[COLOR_ATTR]
    col = np.empty(len(mesh.loops) * 4)
    attr.data.foreach_get("color", col)
    col = col.reshape(-1, 4)
    loop_face = np.repeat(np.arange(len(tri)), 3)
    col[slot[loop_face] == WICK] = (0.012, 0.010, 0.009, 1.0)
    col[slot[loop_face] == FLAME] = (1.0, 1.0, 1.0, 1.0)
    attr.data.foreach_set("color", col.ravel())

    # ---- UV0 atlas, UV1 data
    fc.smart_uv(obj)
    loops_v = np.empty(len(mesh.loops), np.int64)
    mesh.loops.foreach_get("vertex_index", loops_v)
    lp = v_now[loops_v]
    lo_owner = owner[loop_face]
    ids = np.array([c.id for c in candles])[lo_owner]
    value = np.zeros(len(loops_v))
    lw = slot[loop_face] == WAX
    c_glow = np.array([c.glow_z for c in candles])[lo_owner]
    c_rad = np.array([c.radius for c in candles])[lo_owner]
    c_x = np.array([c.x for c in candles])[lo_owner] + np.array([c.lean[0] for c in candles])[lo_owner] * lp[:, 2]
    c_y = np.array([c.y for c in candles])[lo_owner] + np.array([c.lean[1] for c in candles])[lo_owner] * lp[:, 2]
    below = c_glow - lp[:, 2]
    side = np.hypot(lp[:, 0] - c_x, lp[:, 1] - c_y) - c_rad
    glow = (1.0 - _smoothstep(0.0, GLOW_FALLOFF_CM, below)) * (1.0 - _smoothstep(GLOW_RADIAL_CM[0], GLOW_RADIAL_CM[1], side))
    value[lw] = glow[lw]
    lf = slot[loop_face] == FLAME
    value[lf] = flame_h[loops_v][lf]
    data = mesh.uv_layers.get(DATA_UV) or mesh.uv_layers.new(name=DATA_UV)
    data.data.foreach_set("uv", np.stack([ids, 1.0 - value], axis=1).ravel())     # V flipped for the FBX -> Unreal import
    mesh.uv_layers.active = mesh.uv_layers["UVMap"]
    if [u.name for u in mesh.uv_layers][:2] != ["UVMap", DATA_UV]:
        raise RuntimeError("candle_gen: uv layer order %s" % [u.name for u in mesh.uv_layers])
    mesh.update()

    # ---- sockets + the per-candle table
    table = []
    for c in candles:
        mid = np.array(c.flame_base) + 0.5 * (np.array(c.flame_tip) - np.array(c.flame_base))
        e = bpy.data.objects.new("SOCKET_" + c.socket, None)
        e.empty_display_type = "ARROWS"
        e.empty_display_size = 0.03
        e.location = tuple(mid * 0.01)
        e.parent = obj
        e["candle_socket"] = c.socket
        (collection or bpy.context.scene.collection).objects.link(e)
        table.append({
            "index": c.index, "id": round(c.id, 6),
            "base_cm": [round(float(v), 3) for v in np.array([c.x, c.y, 0.0]) * fc.UE_MIRROR],
            "radius_cm": round(c.radius, 3), "height_cm": round(c.height, 3),
            "wax_top_cm": round(c.surface_z, 3), "glow_from_cm": round(c.glow_z, 3),
            "color_linear": [round(float(v), 4) for v in c.color],
            "flame_socket": c.socket, "flame_socket_object": "SOCKET_" + c.socket,
            "flame_center_cm": [round(float(v), 3) for v in mid * fc.UE_MIRROR],
            "flame_base_cm": [round(float(v), 3) for v in np.array(c.flame_base) * fc.UE_MIRROR],
            "flame_tip_cm": [round(float(v), 3) for v in np.array(c.flame_tip) * fc.UE_MIRROR],
            "flame_width_cm": round(c.flame_w, 3), "flame_height_cm": round(c.flame_h, 3),
        })
    t4 = time.time()
    lo, hi = fc.bounds_cm(obj)
    info = {
        "candles": table,
        "params": asdict(p),
        "tris": int(len(tri)), "wax_tris": int(wax_t), "wax_verts": int(wax_v), "surface_nets_tris": int(full_tris),
        "grid": [int(n) for n in values.shape], "voxel_cm": round(float(voxel), 4),
        "size_cm": [round(float(v), 2) for v in hi - lo],
        "seconds": {"field": round(t1 - t0, 2), "surface_nets": round(t2 - t1, 2), "decimate": round(t3 - t2, 2),
                    "dress": round(t4 - t3, 2), "total": round(t4 - t0, 2)},
    }
    obj["_candle_params"] = json.dumps(info["params"])
    obj["_candle_info"] = json.dumps(info)
    obj["candle_count"] = p.count
    if verbose:
        print("candle_gen %-28s candles %2d  tris %5d (wax %5d from %6d)  grid %s @ %.2f cm  size %s  %.2fs "
              "(field %.2f nets %.2f decimate %.2f dress %.2f)" % (
                  name, p.count, info["tris"], wax_t, full_tris, "x".join(str(n) for n in values.shape), voxel,
                  info["size_cm"], t4 - t0, t1 - t0, t2 - t1, t3 - t2, t4 - t3))
    return obj, info


def info_of(obj):
    raw = obj.get("_candle_info")
    return json.loads(raw) if raw else None


# ================================================================ export
def clean_name(name):
    """A file / asset name with the _Mars_SM suffix enforced."""
    stem = os.path.splitext(os.path.basename(str(name).strip()))[0]
    stem = "".join(ch if (ch.isalnum() or ch == "_") else "_" for ch in stem).strip("_") or "Candle"
    for tail in (SUFFIX, "_Mars", "_SM"):
        if stem.endswith(tail):
            stem = stem[:-len(tail)]
    return stem.rstrip("_") + SUFFIX


def _claim_sockets(obj):
    """Blender object names are unique per file, so a second candle's empties become SOCKET_Flame_00.001 and the FBX
    would carry that. Give obj's empties the bare names and park any other object that holds one."""
    mine = sockets_of(obj)
    want = {"SOCKET_" + e["candle_socket"] for e in mine}
    for o in bpy.data.objects:
        if o.name in want and o not in mine:
            o.name = "%s__%s" % (o.name, o.parent.name if o.parent else "parked")
    for e in mine:
        e.name = "SOCKET_" + e["candle_socket"]
    bad = [e.name for e in mine if e.name != "SOCKET_" + e["candle_socket"]]
    if bad:
        raise RuntimeError("candle_gen: socket names not claimed: %s" % bad)
    return mine


def data_ranges(mesh):
    """{slot: {"id": (min, max), "value": (min, max), "tris": n}} of the data UV channel as Unreal reads it
    (value = 1 - v). Works on a generated mesh and on a re-imported FBX."""
    if len(mesh.uv_layers) < 2:
        return {}
    uv = np.empty(len(mesh.loops) * 2)
    mesh.uv_layers[1].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    mat = np.empty(len(mesh.polygons), np.int32)
    mesh.polygons.foreach_get("material_index", mat)
    loop_mat = np.repeat(mat, [len(pl.vertices) for pl in mesh.polygons])
    out = {}
    for k, m in enumerate(mesh.materials):
        sel = loop_mat == k
        if not sel.any():
            continue
        name = m.name.split(".")[0] if m else "slot%d" % k
        out[name] = {"id": (float(uv[sel, 0].min()), float(uv[sel, 0].max())),
                     "value": (float(1.0 - uv[sel, 1].max()), float(1.0 - uv[sel, 1].min())),
                     "tris": int((mat == k).sum())}
    return out


def export_candle(obj, export_dir=None, name=None):
    """FBX (mesh + SOCKET_ empties; the cooking exporter settings, triangles, linear colours) and the JSON sidecar
    <name>.json next to it. name gets the _Mars_SM suffix enforced; the object is renamed for the export and put
    back. Returns the FBX path."""
    export_dir = export_dir or EXPORT_DIR
    os.makedirs(export_dir, exist_ok=True)
    name = clean_name(name or obj.name)
    path = os.path.join(export_dir, name + ".fbx")
    mesh = obj.data
    prev = (obj.name, mesh.name)
    other = bpy.data.objects.get(name)
    if other is not None and other is not obj:
        other.name = name + "__parked"
    obj.name = name
    mesh.name = name
    try:
        group = [obj] + _claim_sockets(obj)
        mesh.uv_layers.active = mesh.uv_layers["UVMap"]
        prev_sel = [(o, o.select_get()) for o in bpy.context.view_layer.objects]
        prev_active = bpy.context.view_layer.objects.active
        for o in bpy.context.view_layer.objects:
            o.select_set(o in group)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH", "EMPTY"},
                                 mesh_smooth_type="EDGE", use_mesh_modifiers=True, add_leaf_bones=False,
                                 bake_anim=False, use_tspace=False, apply_scale_options="FBX_SCALE_NONE",
                                 axis_forward="-Z", axis_up="Y", use_triangles=True, colors_type="LINEAR")
        for o, s in prev_sel:
            o.select_set(s)
        bpy.context.view_layer.objects.active = prev_active
        info = info_of(obj) or {}
        sockets = {}
        for e in group[1:]:
            loc = np.asarray(e.location, float) * 100.0 * fc.UE_MIRROR
            sockets[e["candle_socket"]] = {"location_cm": [round(float(v), 3) for v in loc],
                                           "rotation_deg": [0.0, 0.0, 0.0]}
        ranges = data_ranges(mesh)
        extra = {
            "candle_prop": True,
            "candle_count": len(info.get("candles", [])),
            "candles": info.get("candles", []),
            "sockets": sockets,
            "params": info.get("params", {}),
            "wax_tris": info.get("wax_tris"),
            "data_uv": {
                "layer": DATA_UV, "channel": 1,
                "u": "candle id 0..1, constant per triangle (same on that candle's wax, wick and flame)",
                "v_unreal": "Flame: height along the flame 0 base .. 1 tip. Wax: glow 1 at rim / bowl -> 0 "
                            "%.0f cm below, faded %.1f..%.1f cm beyond the girth. Wick: 0." % (
                                GLOW_FALLOFF_CM, GLOW_RADIAL_CM[0], GLOW_RADIAL_CM[1]),
                "v_blender": "1 - value (the FBX -> Unreal import flips V)",
                "ranges": ranges,
            },
            "vertex_color": "Col linear: wax RGB = facet wax colour, A = cavity/AO; wick near black; flame white",
            "ucx_pieces": 0,
        }
        meta = fc.write_meta(obj, path, extra)
    finally:
        obj.name, mesh.name = prev
    print("exported %s  tris %d  size %.1f cm  slots %s  uv %s  sockets %s" % (
        name, meta["tris"], meta["size_cm"], meta["slots"], meta["uv_layers"], sorted(sockets)))
    return path
