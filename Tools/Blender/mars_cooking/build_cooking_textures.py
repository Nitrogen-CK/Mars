"""Generates the cooking textures (system Python: numpy + Pillow). Re-runnable:

    python build_cooking_textures.py [--out <dir>]

MeatCube_Wagyu_Mask_Mars_T.png    R fat marbling, G fibre grain, B crust break-up, A edge mask
MeatCube_Wagyu_Normal_Mars_T.png  tangent-space normal (DirectX, green down) of the grain + crust bumps
CookingStudio_Mars_HDR.hdr        long-lat studio environment for the station's reflection capture
SearRamp_*.csv                    sear colour ramps (time, r, g, b, a; linear colour) for the curve atlas

The meat fields are 3D functions sampled where each UV island sits on the cube, so marbling runs unbroken over
the edges and the grain (stretched along local Z) shows as streaks on the sides and end grain on top and bottom.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cooking_spec as spec  # noqa: E402


# ---------------------------------------------------------------- noise
def _hash(ix, iy, iz, seed):
    h = (ix * np.uint32(374761393) + iy * np.uint32(668265263) + iz * np.uint32(2147483647)
         + np.uint32((seed * 974634777) & 0xFFFFFFFF))
    h = (h ^ (h >> np.uint32(13))) * np.uint32(1274126177)
    h = h ^ (h >> np.uint32(16))
    return h.astype(np.float32) / np.float32(4294967295.0)


def noise3(p, seed):
    """Value noise 0..1 at points p (..., 3)."""
    i = np.floor(p)
    f = (p - i).astype(np.float32)
    f = f * f * (3.0 - 2.0 * f)
    i = i.astype(np.int64)
    out = 0.0
    for dx in (0, 1):
        wx = f[..., 0] if dx else 1.0 - f[..., 0]
        for dy in (0, 1):
            wy = f[..., 1] if dy else 1.0 - f[..., 1]
            for dz in (0, 1):
                wz = f[..., 2] if dz else 1.0 - f[..., 2]
                c = [((i[..., k] + d) & 0xFFFFFFFF).astype(np.uint32) for k, d in enumerate((dx, dy, dz))]
                out = out + _hash(c[0], c[1], c[2], seed) * wx * wy * wz
    return out


def fbm(p, seed, octaves=4, gain=0.5):
    total, amp, norm, freq = 0.0, 1.0, 0.0, 1.0
    for o in range(octaves):
        total = total + amp * noise3(p * freq + o * 17.31, seed + o * 101)
        norm += amp
        amp *= gain
        freq *= 2.0
    return total / norm


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def unit(x, lo=0.02, hi=0.98):
    a, b = np.quantile(x, lo), np.quantile(x, hi)
    return np.clip((x - a) / (b - a), 0.0, 1.0)


def above(x, fraction, soft):
    """Mask of the top `fraction` of x, with a soft edge `soft` wide (in units of x)."""
    t = np.quantile(x, 1.0 - fraction)
    return smoothstep(t - soft * 0.5, t + soft * 0.5, x)


# ---------------------------------------------------------------- meat cube
def cube_points(size):
    """Per-texel 3D position (cm, Blender axes) on the cube, plus the in-plane coords a, b of its island."""
    px = (np.arange(size) + 0.5) / size
    u, v = np.meshgrid(px, px)
    col = np.minimum((u * spec.ATLAS_COLS).astype(int), spec.ATLAS_COLS - 1)
    row = np.minimum((v * spec.ATLAS_ROWS).astype(int), spec.ATLAS_ROWS - 1)
    face = row * spec.ATLAS_COLS + col
    a = (u - (col + 0.5) / spec.ATLAS_COLS) / (spec.ISLAND * 0.5)
    b = (v - (row + 0.5) / spec.ATLAS_ROWS) / (spec.ISLAND * 0.5)
    frames = np.array(spec.FACES, dtype=np.float64)                  # (6, 3 axes, 3)
    nrm, ua, va = frames[face, 0], frames[face, 1], frames[face, 2]
    p = (nrm + a[..., None] * ua + b[..., None] * va) * spec.CUBE_HALF_CM
    return p, a, b


FAT_FREQ = 0.45         # marbling field frequency, cycles per cm (2-3 streaks across a 4 cm face)
FAT_WIDTH_CM = 0.26     # half width of a fat streak, cm


def build_meat(out_dir, size=spec.TEX_SIZE):
    """Stylized (Mario-Party) cut: a clean lean body with a few broad, soft fat streaks, a faint grain and smooth
    bumps. Feature sizes are in cm, tuned on the 4 cm cube (CUBE_HALF_CM 2)."""
    p, a, b = cube_points(size)
    grain = np.array([1.0, 1.0, 1.0 / 2.2])                          # streaks run 2.2x longer along Z
    warp = np.stack([fbm(p * 0.3 + k * 9.7, 300 + k, 2) for k in range(3)], axis=-1) - 0.5

    # marbling: the 0.5 contour of one low-frequency field makes a handful of broad streaks per face. The width
    # comes from the distance to that contour (value / gradient, in cm), so a streak keeps its width instead of
    # pooling into blobs where the field is flat; a second field swells and thins it along its length.
    n1 = fbm(p * grain * FAT_FREQ + warp * 0.7, 1, 2, gain=0.3)
    texel_cm = 2.0 * spec.CUBE_HALF_CM / (spec.ISLAND * size)
    gy, gx = np.gradient(n1.astype(np.float64))
    slope = np.maximum(np.hypot(gx, gy) / texel_cm, 0.02)           # field change per cm along the surface
    dist = np.abs(n1 - 0.5) / slope                                  # cm to the streak's centre line
    swell = fbm(p * 0.7 + 13.0, 2, 2)
    width = FAT_WIDTH_CM * (0.5 + 1.0 * smoothstep(0.25, 0.75, swell))
    core = 1.0 - smoothstep(width * 0.2, width, dist)                # soft-edged, no hard outline
    halo = 1.0 - smoothstep(width, width * 2.6, dist)                # a faint paler margin around each streak
    fat = np.maximum(core, halo * 0.22)
    fat = fat * (0.8 + 0.2 * smoothstep(0.2, 0.7, swell))            # some streaks stay a touch pinker

    fibre = unit(fbm(p * np.array([1.0, 1.0, 1.0 / 7.0]) * 2.6, 4, 2))
    breakup = unit(fbm(p * 1.3 + 31.0, 5, 4, gain=0.55))
    edge = smoothstep(0.80, 1.0, np.maximum(np.abs(a), np.abs(b)) + (fbm(p * 2.2, 6, 3) - 0.5) * 0.18)

    mask = np.stack([fat, fibre, breakup, edge], axis=-1)
    Image.fromarray((mask * 255.0 + 0.5).astype(np.uint8), "RGBA").save(
        os.path.join(out_dir, "MeatCube_Wagyu_Mask_Mars_T.png"))

    # smooth, low bumps: the raw face stays near flat (Normal Raw is low), the crust gets soft blisters
    height = 0.2 * fibre + 0.55 * unit(fbm(p * 1.8 + 5.0, 7, 2)) + 0.25 * breakup - 0.2 * fat
    gy, gx = np.gradient(height.astype(np.float64))
    k = 6.0
    n = np.stack([-gx * k, -gy * k, np.ones_like(gx)], axis=-1)      # image y is down: DirectX green
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    Image.fromarray(((n * 0.5 + 0.5) * 255.0 + 0.5).astype(np.uint8), "RGB").save(
        os.path.join(out_dir, "MeatCube_Wagyu_Normal_Mars_T.png"))
    return {"fat_coverage": float(fat.mean())}


# ---------------------------------------------------------------- studio environment
def _blur_wrap(img, radius):
    """Separable box blur, wrapping in longitude and clamping in latitude."""
    k = 2 * radius + 1
    pad = np.concatenate([img[:, -radius:], img, img[:, :radius]], axis=1)
    c = np.cumsum(np.concatenate([np.zeros_like(pad[:, :1]), pad], axis=1), axis=1)
    img = (c[:, k:] - c[:, :-k]) / k
    pad = np.concatenate([np.repeat(img[:1], radius, 0), img, np.repeat(img[-1:], radius, 0)], axis=0)
    c = np.cumsum(np.concatenate([np.zeros_like(pad[:1]), pad], axis=0), axis=0)
    return (c[k:] - c[:-k]) / k


def write_hdr(path, rgb):
    """Radiance RGBE, flat (uncompressed) scanlines."""
    h, w, _ = rgb.shape
    m = np.maximum(rgb.max(axis=-1), 1e-32)
    e = np.ceil(np.log2(m)).astype(np.int32)
    scale = np.ldexp(1.0, -e)[..., None] * 256.0
    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[..., :3] = np.clip(rgb * scale, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(e + 128, 0, 255).astype(np.uint8)
    out[..., 0] = np.where(out[..., 0] < 3, 3, out[..., 0])           # never look like a run-length marker
    with open(path, "wb") as fh:
        fh.write(b"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y %d +X %d\n" % (h, w))
        fh.write(out.tobytes())


def build_studio(out_dir, width=1024):
    """A warm kitchen for the chrome to mirror: red walls, cream backsplash and ceiling, wood counter below the
    horizon, one bright window with mullions, a lamp and a plant."""
    height = width // 2
    lon = (np.arange(width) + 0.5) / width * math.tau - math.pi          # -pi..pi
    lat = math.pi / 2 - (np.arange(height) + 0.5) / height * math.pi     # +pi/2 (up) .. -pi/2
    lon, lat = np.meshgrid(lon, lat)

    def col(r, g, b):
        return np.array([r, g, b], dtype=np.float64)

    def patch(lon0, lat0, w, h, soft):
        dl = np.abs((lon - math.radians(lon0) + math.pi) % math.tau - math.pi)
        mx = 1.0 - smoothstep(math.radians(w) / 2 - math.radians(soft), math.radians(w) / 2 + math.radians(soft), dl)
        my = 1.0 - smoothstep(math.radians(h) / 2 - math.radians(soft), math.radians(h) / 2 + math.radians(soft),
                              np.abs(lat - math.radians(lat0)))
        return (mx * my)[..., None]

    latd, lond = np.degrees(lat), np.degrees(lon)
    d = np.stack([np.cos(lat) * np.cos(lon), np.cos(lat) * np.sin(lon), np.sin(lat)], axis=-1)
    vary = fbm(d * 2.2, 40, 3)[..., None]
    env = np.broadcast_to(col(0.50, 0.07, 0.05), d.shape) * (0.75 + 0.6 * vary)                   # red walls
    env = env + (col(0.95, 0.80, 0.66) * 0.5 - env) * smoothstep(46, 58, latd)[..., None]   # ceiling
    backsplash = (smoothstep(-2, 2, latd) * (1 - smoothstep(11, 15, latd)))[..., None]
    env = env + (col(0.78, 0.66, 0.52) - env) * backsplash
    floor = (1 - smoothstep(-3, 1, latd))[..., None]
    wood = col(0.60, 0.23, 0.05) * (0.55 + 0.7 * fbm(d * np.array([3.0, 14.0, 3.0]), 41, 3)[..., None])
    wood = wood * (0.35 + 0.65 * smoothstep(-80, -5, latd)[..., None])
    env = env + (wood - env) * floor

    env = env + (col(0.10, 0.26, 0.05) - env) * patch(-70, 24, 20, 26, 6) * (0.5 + 0.4 * vary)       # plant
    window = patch(0, 30, 40, 24, 1.5)
    mullion = np.minimum(smoothstep(0.6, 1.6, np.abs(lond)),
                         smoothstep(0.6, 1.6, np.abs(latd - 30)))[..., None]
    leaves = 0.55 + 0.45 * smoothstep(0.42, 0.58, fbm(d * 6.0, 42, 3))[..., None]
    env = env + (col(1.0, 0.93, 0.80) * 22.0 * leaves * (0.15 + 0.85 * mullion) - env) * window
    env = env + (col(1.0, 0.72, 0.42) * 4.0 - env) * patch(150, 66, 22, 16, 4)                        # lamp
    env = _blur_wrap(env, 3) * 2.5                       # sits against a ~5 lux key light
    write_hdr(os.path.join(out_dir, "CookingStudio_Mars_HDR.hdr"), env)
    preview = np.clip(env / (1.0 + env), 0, 1) ** (1 / 2.2)
    Image.fromarray((preview * 255).astype(np.uint8), "RGB").save(os.path.join(out_dir, "CookingStudio_preview.png"))


# ---------------------------------------------------------------- sear ramps
def _lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


# time 0..1 spans sear 0..2 (the material's Sear Range): 0 raw, 0.5 a full crust, 1 burnt. sRGB 8-bit keys.
# Stylized (Mario-Party) look: a clean saturated pink-red raw cut with pale pink fat, a tan cooked band, a clean
# caramel crust and a burnt end that is dark brown, never black. The burnt keys look light on paper: the lookdev
# exposure puts a linear albedo under ~0.1 into the tonemapper's toe, where it renders pure black.
RAMPS = {
    "SearRamp_WagyuLean_Mars_Curve": (
        (0.00, 222, 60, 90), (0.08, 200, 100, 104), (0.16, 170, 108, 88), (0.24, 160, 100, 72),
        (0.36, 188, 120, 62), (0.50, 160, 96, 48), (0.62, 146, 90, 50), (0.78, 132, 84, 52), (1.00, 112, 74, 52)),
    "SearRamp_WagyuFat_Mars_Curve": (
        (0.00, 248, 208, 206), (0.08, 242, 212, 198), (0.16, 232, 202, 164), (0.24, 220, 178, 120),
        (0.36, 214, 154, 88), (0.50, 190, 122, 62), (0.62, 156, 98, 56), (0.78, 140, 92, 58), (1.00, 120, 82, 58)),
}


def build_ramps(out_dir):
    for name, keys in RAMPS.items():
        with open(os.path.join(out_dir, name + ".csv"), "w") as fh:
            for t, r, g, b in keys:
                fh.write("%g,%.5f,%.5f,%.5f,1\n" % (t, _lin(r), _lin(g), _lin(b)))


def main():
    out_dir = spec.EXPORT_DIR
    if "--out" in sys.argv:
        out_dir = sys.argv[sys.argv.index("--out") + 1]
    os.makedirs(out_dir, exist_ok=True)
    stats = build_meat(out_dir)
    build_studio(out_dir)
    build_ramps(out_dir)
    print("fat coverage %.2f" % stats["fat_coverage"])
    print("COOKING_TEXTURES_OK")


if __name__ == "__main__":
    main()
