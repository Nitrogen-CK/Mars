"""Two authored reflection environments for the crypt dressing (plain python 3 + numpy, no Blender):

    CryptWarm_Mars_HDR   torch-lit hall: dark vault, warm-lit ashlar walls with a ring of bright torch / lantern spots
                         round the horizon, a dark flagstone floor
    CryptCold_Mars_HDR   moonlit cistern: the same room cold - blue-grey walls, a few pale-blue openings and spirit lamps,
                         one far warm candle

Why authored and not captured: Mars has no SSR or Lumen reflections (r.ReflectionMethod=0), so wet floors, puddles,
water and chrome only shine through reflection captures. A SPECIFIED-cubemap capture reflects identically in the editor,
PIE and cooked builds, in any room and with no "Build Reflection Captures" step; captured-scene captures were found to
stay black in the hidden -RenderOffscreen editor (2026-10-24). Use them as the cubemap of a Sphere/Box reflection capture
per room (mars_env_ue.place_reflection), warm or cold to match the room's key light.

Radiance is in the scale the Mars lamp look renders at (manual exposure bias ~8.7, lamps ~60 cd): lit wall ~0.5,
torch spots ~40, vault ~0.03. Lat-long, 1024 x 512, Radiance RGBE (.hdr), imported by Unreal as a TextureCube.

    python build_env_hdr.py [--out D:\\Repo\\Content\\Environment\\Dressing\\export\\textures] [--preview]
"""
import argparse
import math
import os

import numpy as np

OUT = r"D:\Repo\Content\Environment\Dressing\export\textures"


def write_hdr(path, rgb):
    """Radiance RGBE, flat (uncompressed) scanlines (same writer as mars_cooking/build_cooking_textures.py)."""
    h, w, _ = rgb.shape
    m = np.maximum(rgb.max(axis=-1), 1e-32)
    e = np.ceil(np.log2(m)).astype(np.int32)
    scale = np.ldexp(1.0, -e)[..., None] * 256.0
    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[..., :3] = np.clip(rgb * scale, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(e + 128, 0, 255).astype(np.uint8)
    out[..., 0] = np.where(out[..., 0] < 3, 3, out[..., 0])
    with open(path, "wb") as fh:
        fh.write(b"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y %d +X %d\n" % (h, w))
        fh.write(out.tobytes())


def _grid(width):
    height = width // 2
    lon = (np.arange(width) + 0.5) / width * math.tau - math.pi
    lat = math.pi / 2 - (np.arange(height) + 0.5) / height * math.pi
    return np.meshgrid(lon, lat)


def _ashlar(lon, lat, seed):
    """Masonry courses on the walls: a value per block (lighter / darker stones) and dark mortar lines."""
    rng = np.random.default_rng(seed)
    rows = np.floor((lat + 0.6) / 0.11)
    offs = (rows % 2) * 0.5
    cols = np.floor(lon / 0.22 + offs)
    key = (rows * 131 + cols * 17).astype(np.int64) % 997
    table = rng.uniform(0.75, 1.2, 997)
    block = table[key]
    fr = ((lat + 0.6) / 0.11) % 1.0
    fc = (lon / 0.22 + offs) % 1.0
    mortar = (np.minimum(fr, 1 - fr) < 0.06) | (np.minimum(fc, 1 - fc) < 0.035)
    return np.where(mortar, 0.35, block)


def _spot(lon, lat, lon0, lat0, size):
    d = np.arccos(np.clip(np.sin(lat) * math.sin(lat0) + np.cos(lat) * math.cos(lat0) * np.cos(lon - lon0), -1, 1))
    return np.exp(-(d / size) ** 2)


def build(kind, width=1024):
    lon, lat = _grid(width)
    up = np.sin(lat)
    wall_band = np.clip(1.0 - np.abs(lat) / 0.75, 0.0, 1.0) ** 0.6
    stones = _ashlar(lon, lat, 7 if kind == "warm" else 11)
    if kind == "warm":
        wall = np.array([0.55, 0.36, 0.22])
        vault = np.array([0.025, 0.018, 0.014])
        floor = np.array([0.10, 0.065, 0.045])
        spots = [(a, 0.18, 0.07, np.array([60.0, 34.0, 13.0])) for a in np.linspace(-math.pi, math.pi, 7)[:-1] + 0.3]
        spots += [(1.2, -0.05, 0.05, np.array([30.0, 16.0, 6.0])), (-2.4, 0.4, 0.06, np.array([25.0, 15.0, 7.0]))]
        glow = np.array([0.9, 0.48, 0.2])
    else:
        wall = np.array([0.20, 0.27, 0.36])
        vault = np.array([0.012, 0.018, 0.03])
        floor = np.array([0.03, 0.045, 0.06])
        spots = [(0.0, 0.25, 0.16, np.array([3.0, 6.5, 12.0])), (2.1, 0.3, 0.12, np.array([2.4, 5.0, 10.0])),
                 (-1.9, 0.12, 0.05, np.array([6.0, 14.0, 30.0])), (-0.9, 0.12, 0.05, np.array([6.0, 14.0, 30.0])),
                 (2.9, 0.05, 0.035, np.array([30.0, 15.0, 5.0]))]
        glow = np.array([0.25, 0.45, 0.8])
    rgb = (np.where(up[..., None] > 0, vault, floor) * (1 - wall_band[..., None])
           + wall * stones[..., None] * wall_band[..., None])
    for lon0, lat0, size, col in spots:
        s = _spot(lon, lat, lon0, lat0, size)
        halo = _spot(lon, lat, lon0, lat0, size * 5.0)
        rgb = rgb + s[..., None] * col + halo[..., None] * glow * wall_band[..., None] * 0.9
    return rgb


def preview(rgb, path):
    from PIL import Image
    t = rgb * 2.0
    t = t / (1.0 + t)
    img = (np.clip(t, 0, 1) ** (1 / 2.2) * 255).astype(np.uint8)
    Image.fromarray(img).save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--preview", action="store_true")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for kind, name in (("warm", "CryptWarm_Mars_HDR"), ("cold", "CryptCold_Mars_HDR")):
        rgb = build(kind)
        write_hdr(os.path.join(a.out, name + ".hdr"), rgb.astype(np.float64))
        if a.preview:
            preview(rgb, os.path.join(a.out, name + "_preview.png"))
        print("%s  mean %.3f  max %.1f" % (name, rgb.mean(), rgb.max()))
    print("ENV_HDR_OK")


if __name__ == "__main__":
    main()
