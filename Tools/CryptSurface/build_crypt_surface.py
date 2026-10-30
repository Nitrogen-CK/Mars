"""Tileable hand-painted stylized stone (WoW / Overwatch style) for the crypt.

Simple shapes, stylized tones:
  * A handful of big plates, flat-topped with painted planes (a constant normal tilt per plane),
    cut by a hard planar chamfer down to a crevice. A few chunky faceted chips knock out edges and
    corners, a few faceted pits, a few tapered cracks running in from the edges. No noise texture.
  * Colour is painted from a value map (plate tone + per-facet tone + soft top-down light + AO +
    edge highlight - crevice) pushed through a gradient map that runs cool in the darks and warm in
    the lights.

Everything is evaluated with wrap-around, so the tile is seamless.

    python build_crypt_surface.py [--size 2048] [--seed 3] [--out DIR] [--opengl]
"""
import argparse
import math
import os

import numpy as np
from PIL import Image, ImageDraw

# ---------------------------------------------------------------------------------------------
# Shape (lengths and heights in pixels at 2048; scaled with --size)

TILE_ROWS = 6                # staggered courses
TILE_COLS = 4                # tiles per course
TILE_WARP = 5.0              # hand-cut wobble on every joint
CRACK_WARP = 8.0             # extra wobble where the grid gives way to cracks
JOINT_SEGMENT = 600          # course lines crack or fade in segments this long
SPLIT_GRID = (4, 5)          # irregular cracks that split tiles, inside the cracked regions
SPLIT_SHARE = 0.7
REGION_THRESHOLD = 0.6       # higher = fewer, smaller patches where the grid gives way to cracks
PLATE_LIFT = 4.0
GAP = (2.5, 6.0)             # crevice half-width, varies along each border
BEVEL = (10, 22)             # bevel width per plate
CHAMFER_SLOPE = (0.5, 0.9)   # per plate
CREVICE_DEPTH = 30.0
CRACK_SHARE = 0.9            # share of tile joints that are cracks; the rest blend into a soft seam
SEAM_SOFTNESS = 30.0         # blur radius of an uncracked seam

# Painted planes on the plate tops, split again by plate borders:
# (cell grid, normal tilt, flat tone, stroke gradient across the plane)
FACET_LAYERS = (((5, 6), 0.08, 0.030, 0.07),
                ((10, 12), 0.025, 0.010, 0.015))
PLANE_LIGHT = 0.45           # planes tilted toward the painted light (upper left) read lighter
PAINT_LIGHT_DIR = (-0.45, 0.89)

CHIPS = 16                   # broken-off stretches of plate edge
CHIP_RADIUS = (25, 55)
CHIP_WIDTH = (30, 55)
CHIP_SLOPE = (0.3, 0.5)
CHIP_WALL = 1.2
PITS = 10
PIT_RADIUS = (6, 12)
CRACKS = 10
CRACK_LEN = (50, 170)
CRACK_WIDTH = (2.0, 3.6)
CRACK_DEPTH = 7.0

NORMAL_STRENGTH = 1.3

# ---------------------------------------------------------------------------------------------
# Tone

# value -> colour, cool darks to warm lights (palette from the reference sheet)
GRADIENT = [
    (0.00, (34, 33, 42)),
    (0.22, (58, 55, 62)),
    (0.42, (90, 80, 74)),
    (0.60, (118, 103, 88)),
    (0.78, (142, 122, 100)),
    (0.92, (170, 142, 108)),
    (1.00, (198, 160, 112)),
]
BASE_VALUE = 0.58
PLATE_TONE = 0.045           # per-plate value spread
PLATE_HUE = 0.025            # per-plate warm/cool spread
TOP_LIGHT = 0.13             # up-facing planes painted lighter
EDGE_LIGHT = 0.42            # crisp highlight on convex breaks
EDGE_BAND = 0.35             # warm band along the top break of each bevel
CREVICE_DARK = 0.55


# ---------------------------------------------------------------------------------------------
# Periodic helpers

def _freq(n):
    f = np.fft.fftfreq(n)
    return np.meshgrid(f, f, indexing="xy")


def blur(img, sigma):
    if sigma <= 0:
        return img
    fx, fy = _freq(img.shape[0])
    k = np.exp(-2.0 * (math.pi ** 2) * (sigma ** 2) * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(img) * k))


def smooth_noise(rng, n, cycles):
    """Low-frequency periodic noise, unit std. Used only to bend shapes, never as texture."""
    fx, fy = _freq(n)
    r = np.sqrt(fx * fx + fy * fy) * n
    k = np.exp(-0.5 * ((np.log(np.maximum(r, 1e-6)) - math.log(cycles)) / 0.4) ** 2)
    k[0, 0] = 0
    out = np.real(np.fft.ifft2(np.fft.fft2(rng.standard_normal((n, n))) * k))
    return out / (out.std() + 1e-9)


def gradient(img):
    return ((np.roll(img, -1, 1) - np.roll(img, 1, 1)) * 0.5,
            (np.roll(img, -1, 0) - np.roll(img, 1, 0)) * 0.5)


def ramp(x):
    return np.clip(x, 0.0, 1.0)


class Plates:
    """Toroidal jittered-grid Voronoi fused into plates. Per pixel: plate id, and the exact distance
    to the nearest border with another plate (planar, so chamfers stay flat)."""

    def __init__(self, rng, n, grid, merge, warp):
        gx, gy = grid
        csx, csy = n / gx, n / gy
        count = gx * gy
        jit = rng.random((gy, gx, 2)) * 0.7 + 0.15
        parent = list(range(count))

        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a

        for j in range(gy):
            for i in range(gx):
                for oi, oj in ((1, 0), (0, 1)):
                    if rng.random() < merge:
                        parent[find(j * gx + i)] = find(((j + oj) % gy) * gx + (i + oi) % gx)
        group = np.array([find(c) for c in range(count)])
        _, group = np.unique(group, return_inverse=True)

        yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
        xx += warp[0]
        yy += warp[1]
        ci = np.floor(xx / csx).astype(np.int64)
        cj = np.floor(yy / csy).astype(np.int64)

        def site(di, dj):
            i, j = ci + di, cj + dj
            iw, jw = i % gx, j % gy
            return xx - (i + jit[jw, iw, 0]) * csx, yy - (j + jit[jw, iw, 1]) * csy, jw * gx + iw

        offs = [(di, dj) for dj in (-2, -1, 0, 1, 2) for di in (-2, -1, 0, 1, 2)]
        d1 = np.full((n, n), np.inf)
        id1 = np.zeros((n, n), np.int64)
        v1x, v1y = np.zeros((n, n)), np.zeros((n, n))
        for di, dj in offs:
            vx, vy, cid = site(di, dj)
            d = vx * vx + vy * vy
            c = d < d1
            d1, id1 = np.where(c, d, d1), np.where(c, cid, id1)
            v1x, v1y = np.where(c, vx, v1x), np.where(c, vy, v1y)

        g1 = group[id1]
        edge = np.full((n, n), 1e9)
        other = g1.copy()
        for di, dj in offs:
            vx, vy, cid = site(di, dj)
            sep = np.hypot(v1x - vx, v1y - vy)
            bis = (vx * vx + vy * vy - d1) / (2 * np.maximum(sep, 1e-6))
            c = (group[cid] != g1) & (bis < edge)
            edge = np.where(c, bis, edge)
            other = np.where(c, group[cid], other)

        self.count = int(group.max()) + 1
        self.id = g1
        self.other = other
        self.edge = edge
        self.to_site = (-v1x, -v1y)

    def per_border(self, rng):
        """A random value per pair of neighbouring plates."""
        table = rng.random(self.count * self.count)
        a, b = np.minimum(self.id, self.other), np.maximum(self.id, self.other)
        return table[a * self.count + b]


class Tiles:
    """Staggered courses: rows of uneven height, joints offset from row to row and slightly slanted.
    Per pixel: tile id, distance to the nearest joint, a key for that joint (horizontal joints are
    keyed in segments so a long course line can crack in places and fade in others), and the vector
    to the tile centre."""

    def __init__(self, rng, n, rows, cols, warp, seg):
        hts = rng.uniform(0.75, 1.25, rows)
        y_e = np.concatenate([[0.0], np.cumsum(hts / hts.sum() * n)])
        wid = rng.uniform(0.65, 1.35, (rows, cols))
        x_e = np.concatenate([np.zeros((rows, 1)), np.cumsum(wid / wid.sum(1, keepdims=True) * n, 1)], 1)
        x_off = rng.random(rows) * n
        slant = rng.normal(0, 0.08, (rows, cols))

        yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
        X = (xx + warp[0]) % n
        Y = (yy + warp[1]) % n
        r = np.clip(np.searchsorted(y_e, Y, side="right") - 1, 0, rows - 1)
        mid = 0.5 * (y_e[r] + y_e[r + 1])
        dy_top = Y - y_e[r]
        dy_bot = y_e[r + 1] - Y

        col = np.zeros((n, n), np.int64)
        d_l = np.zeros((n, n))
        d_r = np.zeros((n, n))
        cx = np.zeros((n, n))
        for ri in range(rows):
            m = r == ri
            xs = (X[m] - x_off[ri]) % n
            dyc = Y[m] - mid[m]
            c = np.clip(np.searchsorted(x_e[ri], xs, side="right") - 1, 0, cols - 1)
            for _ in range(2):  # step across a slanted joint
                jl = x_e[ri, c] + slant[ri, c] * dyc
                jr = x_e[ri, c + 1] + slant[ri, (c + 1) % cols] * dyc
                c = np.where(xs < jl, c - 1, np.where(xs > jr, c + 1, c))
                xs = np.where(c < 0, xs + n, np.where(c >= cols, xs - n, xs))
                c %= cols
            jl = x_e[ri, c] + slant[ri, c] * dyc
            jr = x_e[ri, c + 1] + slant[ri, (c + 1) % cols] * dyc
            col[m] = c
            d_l[m] = (xs - jl) / np.sqrt(1 + slant[ri, c] ** 2)
            d_r[m] = (jr - xs) / np.sqrt(1 + slant[ri, (c + 1) % cols] ** 2)
            cx[m] = 0.5 * (jl + jr) - xs

        dists = np.stack([dy_top, dy_bot, d_l, d_r])
        which = np.argmin(dists, 0)
        segs = int(math.ceil(n / seg))
        xseg = np.floor(X / seg).astype(np.int64) % segs
        h_key = np.where(which == 0, r, (r + 1) % rows) * segs + xseg
        v_key = rows * segs + r * cols + np.where(which == 2, col, (col + 1) % cols)

        self.count = rows * cols
        self.id = r * cols + col
        self.edge = np.min(dists, 0)
        self.key = np.where(which < 2, h_key, v_key)
        self.keys = rows * segs + rows * cols
        self.to_site = (cx, mid - Y)

    def per_border(self, rng):
        return rng.random(self.keys)[self.key]


def _poly_window(n, cx, cy, r, rng, sides):
    """Window around (cx, cy) and the convex-polygon distance (== r on an irregular polygon) inside it."""
    a0 = rng.random() * math.tau
    angs = a0 + np.arange(sides) * math.tau / sides + rng.normal(0, 0.35 / sides, sides)
    norms = np.stack([np.cos(angs), np.sin(angs)], 1) * rng.uniform(0.8, 1.2, (sides, 1))
    R = int(r * 2.2) + 2
    xs = np.arange(int(cx) - R, int(cx) + R + 1)
    ys = np.arange(int(cy) - R, int(cy) + R + 1)
    X, Y = np.meshgrid(xs - cx, ys - cy)
    poly = np.max(X[..., None] * norms[:, 0] + Y[..., None] * norms[:, 1], axis=-1)
    return np.ix_(ys % n, xs % n), poly


def pit(h, cx, cy, r, rng):
    """Faceted pyramid pit."""
    w, poly = _poly_window(h.shape[0], cx, cy, r, rng, int(rng.integers(5, 7)))
    h[w] = np.minimum(h[w], h[int(cy) % h.shape[0], int(cx) % h.shape[0]] - r + np.maximum(poly, 0))


def chip(h, top, out, cx, cy, r, width, slope, rng):
    """A stretch of plate edge broken off: inside an irregular footprint the bevel is wider and
    shallower than the plate's own, with steep walls where the footprint ends."""
    w, poly = _poly_window(h.shape[0], cx, cy, r, rng, int(rng.integers(4, 7)))
    bevel = top[w] + np.minimum(0, out[w] - width) * slope
    walls = top[w] - np.maximum(r - poly, 0) * CHIP_WALL
    h[w] = np.minimum(h[w], np.maximum(bevel, walls))


def crack_layer(rng, n, s, plates, start_mask):
    """A few tapered cracks starting at plate borders and running inward with straight, kinked runs."""
    ss = 2
    N = n * ss
    img = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(img)
    starts = np.argwhere(start_mask)
    picks = starts[rng.choice(len(starts), CRACKS, replace=False)]
    tx, ty = plates.to_site
    for y, x in picks:
        ang = math.atan2(ty[y, x], tx[y, x]) + rng.normal(0, 0.4)
        length = rng.uniform(*CRACK_LEN) * s
        w0 = rng.uniform(*CRACK_WIDTH) * s
        steps = max(4, int(length / (8 * s)))
        px, py, dev = float(x), float(y), 0.0
        for k in range(steps):
            t = k / steps
            dev = 0.7 * dev + rng.normal(0, 0.12)
            if rng.random() < 0.18:
                dev += rng.uniform(-0.6, 0.6)
            a = ang + dev
            nx_, ny_ = px + math.cos(a) * length / steps, py + math.sin(a) * length / steps
            w = max(1, int(round(w0 * (1 - t) * ss)))
            for oy in (-N, 0, N):
                for ox in (-N, 0, N):
                    d.line((px * ss + ox, py * ss + oy, nx_ * ss + ox, ny_ * ss + oy), fill=255, width=w)
            px, py = nx_, ny_
    return np.asarray(img.resize((n, n), Image.BOX), np.float64) / 255.0


# ---------------------------------------------------------------------------------------------

def build(size, seed):
    rng = np.random.default_rng(seed)
    n = size
    s = n / 2048.0

    # Where the tile grid gives way to ordinary cracks
    region = ramp((smooth_noise(rng, n, 3) - REGION_THRESHOLD) * 2.5)
    warp = (smooth_noise(rng, n, 5) * TILE_WARP * s + smooth_noise(rng, n, 6) * CRACK_WARP * s * region,
            smooth_noise(rng, n, 5) * TILE_WARP * s + smooth_noise(rng, n, 6) * CRACK_WARP * s * region)
    plates = Tiles(rng, n, TILE_ROWS, TILE_COLS, warp, JOINT_SEGMENT * s)
    split = Plates(rng, n, SPLIT_GRID, 0.0, (smooth_noise(rng, n, 6) * 6 * s, smooth_noise(rng, n, 6) * 6 * s))
    P = plates.count

    # Joints mostly crack (the rest fade into a soft seam) and give way to angular splits inside the
    # cracked regions. A fading crack gets shallower rather than moving, so it tapers out.
    keep = (plates.per_border(rng) < CRACK_SHARE).astype(np.float64)
    on_t = ramp(blur(keep * ramp((smooth_noise(rng, n, 6) + 1.3) * 1.5), 20 * s) * 1.4) * (1 - region)
    keep_v = (split.per_border(rng) < SPLIT_SHARE) * ramp((smooth_noise(rng, n, 5) + 0.3) * 1.5)
    on_v = ramp(blur(keep_v, 20 * s) * 1.6) * region

    # Tile top: flat, lifted per tile; the lift step survives only where a joint is cracked
    lift = rng.normal(0, PLATE_LIFT * s, P)[plates.id]
    soft = blur(lift, SEAM_SOFTNESS * s)
    top = soft + (lift - soft) * on_t

    # Chunky planar bevel, then a steep-walled crevice, for joints and splits alike
    gap = (GAP[0] + (GAP[1] - GAP[0]) * ramp(0.5 + 0.4 * smooth_noise(rng, n, 9))) * s
    bev_w = rng.uniform(*BEVEL, P)[plates.id] * s
    slope = rng.uniform(*CHAMFER_SLOPE, P)[plates.id]

    def drop(edge_, bev, on):
        o = edge_ - gap
        d = np.minimum(0, o - bev) * slope - np.clip(-o, 0, None) * 3.0
        return np.maximum(d, -CREVICE_DEPTH * s) * on, o

    d_t, out_t = drop(plates.edge, bev_w, on_t)
    d_v, out_v = drop(split.edge, bev_w * 0.6, on_v)
    use_v = d_v < d_t
    out = np.where(use_v, out_v, out_t)
    edge = np.where(use_v, split.edge, plates.edge)
    crack_on = np.where(use_v, on_v, on_t)
    bev_w = np.where(use_v, bev_w * 0.6, bev_w)
    h = top + np.minimum(d_t, d_v)

    # Broken-off edges, then a few pits on the faces
    border = np.argwhere((out > 0) & (out < 4 * s) & (crack_on > 0.9))
    for y, x in border[rng.choice(len(border), CHIPS, replace=False)]:
        chip(h, top, out, x, y, rng.uniform(*CHIP_RADIUS) * s, rng.uniform(*CHIP_WIDTH) * s,
             rng.uniform(*CHIP_SLOPE), rng)
    inner = np.argwhere(edge > 50 * s)
    for y, x in inner[rng.choice(len(inner), PITS, replace=False)]:
        pit(h, x, y, rng.uniform(*PIT_RADIUS) * s, rng)

    cracks = crack_layer(rng, n, s, plates, (out > bev_w * 0.5) & (out < bev_w + 4 * s) & (crack_on > 0.9))
    h -= blur(cracks, 1.2 * s) * CRACK_DEPTH * s

    h = blur(h, 0.7 * s)  # anti-alias creases only

    # Normal
    gx, gy = gradient(h)
    k = NORMAL_STRENGTH / s
    # Painted planes: per (plate x facet cell) a constant normal tilt, a flat tone and a stroke
    # gradient across the plane, kept off the bevels of cracked borders
    on_top = 1 - crack_on * (1 - ramp((out - bev_w - 6 * s) / (10 * s)))
    tx = np.zeros_like(h)
    ty = np.zeros_like(h)
    paint = np.zeros_like(h)
    light = np.array(PAINT_LIGHT_DIR)
    for grid, tilt_amp, tone_amp, stroke_amp in FACET_LAYERS:
        fc = Plates(rng, n, grid, 0.0, (smooth_noise(rng, n, 5) * 10 * s, smooth_noise(rng, n, 5) * 10 * s))
        F = P * fc.count
        fid = plates.id * fc.count + fc.id
        tilt = rng.normal(0, tilt_amp, (F, 2))
        stroke = rng.normal(0, 1, (F, 2))
        cell = n / (0.5 * (grid[0] + grid[1]))
        tx += tilt[fid, 0]
        ty += tilt[fid, 1]
        paint += (rng.normal(0, tone_amp, F)[fid]
                  + stroke_amp * (stroke[fid, 0] * fc.to_site[0] + stroke[fid, 1] * fc.to_site[1]) / cell
                  + PLANE_LIGHT * (tilt @ light)[fid])
    tx = blur(tx * on_top, 3.0 * s)
    ty = blur(ty * on_top, 3.0 * s)
    paint = blur(paint, 3.0 * s)
    nrm = np.dstack([-gx * k + tx, gy * k + ty, np.ones_like(h)])  # OpenGL (+Y up)
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)

    # Painted value map
    occl = np.zeros_like(h)
    for r, w in ((3, 0.3), (10, 0.4), (28, 0.3)):
        occl += w * ramp((blur(h, r * s) - h) / (r * 0.6 * s))
    ao = 1 - ramp(occl)
    curv = h - blur(h, 2.0 * s)
    convex = ramp((curv - 0.25 * s) / (1.2 * s))
    crevice = ramp(1 - out / (3 * s)) * crack_on + ramp(cracks * 1.5)
    band = ramp(1 - np.abs(out - bev_w) / (3 * s)) * crack_on

    value = (BASE_VALUE
             + rng.normal(0, PLATE_TONE, P)[plates.id]
             + paint
             + TOP_LIGHT * nrm[..., 1] / 0.35
             + EDGE_LIGHT * convex
             + EDGE_BAND * band
             - 0.30 * (1 - ao)
             - CREVICE_DARK * ramp(crevice))
    value = ramp(value)

    stops = [p for p, _ in GRADIENT]
    cols = np.array([c for _, c in GRADIENT], np.float64) / 255
    col = np.dstack([np.interp(value, stops, cols[:, c]) for c in range(3)])
    hue = rng.normal(0, PLATE_HUE, P)[plates.id]
    col *= (1 + hue[..., None] * np.array([1.0, 0.2, -1.0]))
    col = np.clip(col, 0, 1)

    rough = np.clip(0.88 - 0.18 * convex + 0.08 * (1 - ao), 0, 1)
    return col, nrm, rough, h, ao


# ---------------------------------------------------------------------------------------------

def to_u8(a):
    return (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)


def srgb_to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def lit_preview(col, nrm_gl, ao, key=(0.45, 0.55, 0.70), key_col=(1.7, 1.35, 1.0), fill_col=(0.20, 0.23, 0.30)):
    L = np.array(key, np.float64); L /= np.linalg.norm(L)
    ndl = np.clip(nrm_gl @ L, 0, 1)[..., None]
    sky = (0.6 + 0.4 * nrm_gl[..., 1:2]) * ao[..., None]
    lin = srgb_to_lin(col)
    out = lin * (ndl * np.array(key_col) + sky * np.array(fill_col))
    out = out / (1 + out)
    return lin_to_srgb(out * 1.7)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=2048)
    ap.add_argument("--seed", type=int, default=3)
    ap.add_argument("--out", default=r"D:\Repo\Content\Environment\CryptSurface")
    ap.add_argument("--opengl", action="store_true", help="write +Y (OpenGL) normals instead of UE's DirectX")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)

    col, nrm_gl, rough, h, ao = build(a.size, a.seed)
    nrm_out = nrm_gl.copy()
    if not a.opengl:
        nrm_out[..., 1] *= -1

    stem = "T_CryptSurface_Mars"
    Image.fromarray(to_u8(col)).save(os.path.join(a.out, f"{stem}_D.png"))
    Image.fromarray(to_u8(nrm_out * 0.5 + 0.5)).save(os.path.join(a.out, f"{stem}_N.png"))
    Image.fromarray(to_u8(rough)).save(os.path.join(a.out, f"{stem}_R.png"))
    Image.fromarray(to_u8(ao)).save(os.path.join(a.out, f"{stem}_AO.png"))
    hn = (h - h.min()) / (h.max() - h.min())
    Image.fromarray((hn * 65535 + 0.5).astype(np.uint16)).save(os.path.join(a.out, f"{stem}_H.png"))

    # Preview sheet: albedo | normal | warm torch key | cool moonlight key, each tiled 2x2
    half = a.size // 2
    def tile2(img):
        im = Image.fromarray(img).resize((half, half), Image.LANCZOS)
        sheet = Image.new("RGB", (half * 2, half * 2))
        for oy in (0, half):
            for ox in (0, half):
                sheet.paste(im, (ox, oy))
        return sheet
    warm = lit_preview(col, nrm_gl, ao)
    cool = lit_preview(col, nrm_gl, ao, key=(-0.4, 0.5, 0.75), key_col=(0.9, 1.05, 1.35), fill_col=(0.25, 0.22, 0.2))
    tiles = [tile2(to_u8(col)), tile2(to_u8(nrm_out * 0.5 + 0.5)), tile2(to_u8(warm)), tile2(to_u8(cool))]
    sheet = Image.new("RGB", (a.size * 4, a.size))
    for i, t in enumerate(tiles):
        sheet.paste(t, (i * a.size, 0))
    sheet.resize((a.size * 2, a.size // 2), Image.LANCZOS).save(os.path.join(a.out, f"{stem}_preview.png"))
    Image.fromarray(to_u8(warm)).save(os.path.join(a.out, f"{stem}_lit.png"))
    print("wrote", a.out)


if __name__ == "__main__":
    main()
