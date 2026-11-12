"""Bakes the four textures of the stylized (Godot MiseCryptLab) water as tiling PNGs (STYLIZED_WATER_PLAN.md).

Plain Python 3 + numpy + Pillow (no unreal, no bpy). Godot generates them at load from FastNoiseLite (seed 7,
`materials/water/*.tres`); this bakes periodic stand-ins with the same size, cell counts and octaves, so they tile
exactly and the imported mips give the Godot `textureLod(..., 2.0)` normal blur:

    python Tools/Blender/mars_water/stylized_water_noise.py            # writes water_spec.STYLIZED_EXPORT_DIR/*.png
    python Tools/Blender/mars_water/stylized_water_noise.py --sheet    # also a contact sheet (2 x 2 tiles of each)

| Texture | Godot | Bake |
|---|---|---|
| Displace | simplex-smooth, freq 0.02, 256 px, FBM 5 oct | periodic gradient noise, 5 periods per tile, FBM 5 oct |
| EdgeNoise | cellular distance, freq 0.03, 256 px, FBM 5 oct | periodic F1 cellular, 8 cells per tile, FBM 5 oct |
| Normal | cellular distance, freq 0.02, 512 px, as normal map, bump 6 | periodic F1 cellular, 10 cells, Godot's bump-to-normal |
| EdgeRamp | GradientTexture1D white at 0 -> black at 0.08 | 256 x 4, the same ramp |

Godot's NoiseTexture2D normalizes every texture to 0..1 (the default `normalize = true`); so does this.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import water_spec as spec  # noqa: E402

OCTAVES, LACUNARITY, GAIN = 5, 2, 0.5          # FastNoiseLite's fractal defaults (FBM)
JITTER = 0.43701595                            # FastNoiseLite's cellular jitter scale (jitter 1.0)


def _grid(size, periods):
    u = (np.arange(size) + 0.5) * periods / size
    return np.meshgrid(u, u, indexing="xy")


def gradient_noise(size, periods, rng):
    """Periodic 2D gradient noise (quintic fade), ~-1..1, `periods` lattice cells across the tile."""
    ang = rng.uniform(0.0, 2.0 * np.pi, (periods, periods))
    gx, gy = np.cos(ang), np.sin(ang)
    x, y = _grid(size, periods)
    xi, yi = np.floor(x).astype(int), np.floor(y).astype(int)
    xf, yf = x - xi, y - yi

    def dot(ox, oy):
        ix, iy = (xi + ox) % periods, (yi + oy) % periods
        return gx[iy, ix] * (xf - ox) + gy[iy, ix] * (yf - oy)

    fx = xf * xf * xf * (xf * (xf * 6 - 15) + 10)
    fy = yf * yf * yf * (yf * (yf * 6 - 15) + 10)
    a = dot(0, 0) + fx * (dot(1, 0) - dot(0, 0))
    b = dot(0, 1) + fx * (dot(1, 1) - dot(0, 1))
    return (a + fy * (b - a)) * 1.41421356


def cellular_noise(size, cells, rng):
    """Periodic F1 (Euclidean distance to the nearest feature point) minus 1, as FastNoiseLite's RETURN_DISTANCE."""
    ang = rng.uniform(0.0, 2.0 * np.pi, (cells, cells))
    rad = rng.uniform(0.0, 1.0, (cells, cells))
    px = 0.5 + np.cos(ang) * rad * JITTER
    py = 0.5 + np.sin(ang) * rad * JITTER
    x, y = _grid(size, cells)
    xi, yi = np.floor(x).astype(int), np.floor(y).astype(int)
    best = np.full(x.shape, 1e9)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            cx, cy = xi + ox, yi + oy
            ix, iy = cx % cells, cy % cells
            dx = cx + px[iy, ix] - x
            dy = cy + py[iy, ix] - y
            best = np.minimum(best, dx * dx + dy * dy)
    return np.sqrt(best) - 1.0


def fbm(fn, size, base, seed):
    rng = np.random.default_rng(seed)
    total, amp, norm = np.zeros((size, size)), 1.0, 0.0
    for o in range(OCTAVES):
        total += fn(size, base * LACUNARITY ** o, rng) * amp
        norm += amp
        amp *= GAIN
    return total / norm


def normalize01(a):
    lo, hi = float(a.min()), float(a.max())
    return (a - lo) / max(hi - lo, 1e-9)


def bump_to_normal(h, bump):
    """Godot Image::bump_map_to_normal_map: across x up with (here - below) and (right - here) slopes, wrapped."""
    right = np.roll(h, -1, axis=1)
    below = np.roll(h, -1, axis=0)
    n = np.stack([-(right - h) * bump, -(h - below) * bump, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def _png(a, path, mode):
    Image.fromarray(np.clip(np.round(a * 255.0), 0, 255).astype(np.uint8), mode).save(path)


def bake(out_dir=None):
    out_dir = out_dir or spec.STYLIZED_EXPORT_DIR
    os.makedirs(out_dir, exist_ok=True)
    t = spec.STYLIZED_TEXTURES
    seed = spec.STYLIZED_SEED
    written = {}

    d = t["StylizedWaterDisplace_Mars_T"]
    a = normalize01(fbm(gradient_noise, d["size"], d["periods"], seed))
    written["StylizedWaterDisplace_Mars_T"] = a
    _png(a, os.path.join(out_dir, d["file"]), "L")

    d = t["StylizedWaterEdgeNoise_Mars_T"]
    a = normalize01(fbm(cellular_noise, d["size"], d["periods"], seed + 1))
    written["StylizedWaterEdgeNoise_Mars_T"] = a
    _png(a, os.path.join(out_dir, d["file"]), "L")

    d = t["StylizedWaterNormal_Mars_T"]
    h = normalize01(fbm(cellular_noise, d["size"], d["periods"], seed + 2))
    a = bump_to_normal(h, d["bump"])
    written["StylizedWaterNormal_Mars_T"] = a
    _png(a, os.path.join(out_dir, d["file"]), "RGB")

    d = t["StylizedWaterEdgeRamp_Mars_T"]
    x = (np.arange(d["size"]) + 0.5) / d["size"]
    row = np.clip(1.0 - x / d["end"], 0.0, 1.0)
    a = np.tile(row, (d["rows"], 1))
    written["StylizedWaterEdgeRamp_Mars_T"] = a
    _png(a, os.path.join(out_dir, d["file"]), "L")
    return out_dir, written


def tiles_seamlessly(a):
    """Largest step across the wrap seam vs the largest step inside the image (both directions)."""
    inner = max(np.abs(np.diff(a, axis=0)).max(), np.abs(np.diff(a, axis=1)).max())
    seam = max(np.abs(a[0] - a[-1]).max(), np.abs(a[:, 0] - a[:, -1]).max())
    return seam <= inner + 1e-6, float(seam), float(inner)


def sheet(out_dir, written):
    tiles = []
    for name in ("StylizedWaterDisplace_Mars_T", "StylizedWaterEdgeNoise_Mars_T", "StylizedWaterNormal_Mars_T"):
        a = written[name]
        if a.ndim == 2:
            a = np.repeat(a[..., None], 3, axis=-1)
        a = np.tile(a, (2, 2, 1))
        im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGB").resize((512, 512))
        tiles.append(im)
    out = Image.new("RGB", (512 * len(tiles), 512))
    for i, im in enumerate(tiles):
        out.paste(im, (512 * i, 0))
    path = os.path.join(out_dir, "stylized_water_noise_sheet.png")
    out.save(path)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out")
    ap.add_argument("--sheet", action="store_true")
    a = ap.parse_args()
    out_dir, written = bake(a.out)
    for name, arr in written.items():
        if name == "StylizedWaterEdgeRamp_Mars_T":
            continue
        ok, seam, inner = tiles_seamlessly(arr if arr.ndim == 2 else arr[..., 0])
        print("%-32s %s seam %.3f inner max %.3f" % (name, "TILES" if ok else "SEAM!", seam, inner))
    if a.sheet:
        print("sheet", sheet(out_dir, written))
    print("written to", out_dir)


if __name__ == "__main__":
    main()
