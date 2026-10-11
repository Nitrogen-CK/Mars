"""Marbling masks + normals for the bench slab on the meat cube's master (Meat_Mars_M).

    blender -b --factory-startup --python build_meatslab_marbling.py -- [--fbx <MeatSlab_Mars_SM.fbx>] [--out <dir>]
                                    [--size 2048] [--cap_size 1024] [--cap_cm 37] [--preview <dir>]

Why: Food_Mars_M multiplies the crust into the painted vertex colour, so the saturated-red slab stays red at every sear
(review\\parity\\CookParity_*_sheet.png). Meat_Mars_M colours by its sear ramps instead and reads where the fat is from
its Mask texture (R), so cuttable meat goes on Meat_Mars_M (MeatSlab_Wagyu_Mars_MI and, for the runtime cut cap,
MeatSlab_WagyuCap_Mars_MI, both built by unreal/mars_meat_ue.py) with these textures:

  MeatSlab_Marbling_Mars_T.png            the slab's UV0. RGBA, the channel contract of MeatCube_Wagyu_Mask_Mars_T:
                                          R fat (the painted fat cap, the painted marbling lines and sinew, and the cube's
                                            broad pale streaks evaluated in the slab's own 3D space), G fibre grain + lean
                                            mottling, B crust break-up, A convex facet rims (build_food_meats.edge_raster).
  MeatSlab_Marbling_Normal_Mars_T.png     its tangent normal (DirectX, green down), the cube's bump recipe.
  MeatSlab_CapMarbling_Mars_T.png         a TILEABLE lean cross-section, cap_cm (37) centimetres per UV unit: the same
                                          fields on a plane across the grain, A = 0. The runtime cut cap's UV0 is a planar
                                          projection about the knife's contact point (Food def Cap.CmPerUVUnit), so it
                                          lands on arbitrary atlas texels; on the slab's atlas a cap reads the fat cap
                                          island as a pale slab. The cap slot gets this tile instead.
  MeatSlab_CapMarbling_Normal_Mars_T.png  its normal.

Every field is a function of position in centimetres with the cube generator's feature sizes
(build_cooking_textures.build_meat: FAT_FREQ / FAT_WIDTH_CM / VEIN_* / fibre and mottle frequencies), so a cut piece
of any size shows the marbling, grain and relief per centimetre the 4 cm cube shows. The grain runs along the slab's
long axis (X) instead of the cube's Z; a broad presence field breaks the streak network into separate streaks (the
iso-surface of one 3D field is a sponge, which reads as a web over a 37 cm slab). The cap tile snaps each frequency so
cap_cm holds a whole number of periods (a few percent off the cube's) and wraps its noise lattice.

Reads only the exported FBX (UV0, the "Col" corner colours, the Flesh / Skin slots); writes the PNGs into
food_spec.EXPORT_DIR (the slab's exported inputs) and, with --preview, a review strip (mask channels, normal, the raw
ramp colour the mask gives on Meat_Mars_M, then the cap tile 2 x 2). Prints MEATSLAB_MARBLING_OK.
"""
import math
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import food_common as fc  # noqa: E402
import build_food_meats as bfm  # noqa: E402  (edge_raster: the convex-rim channel every food mask carries)

spec = fc.spec
DEFAULTS = {"fbx": os.path.join(spec.EXPORT_DIR, "MeatSlab_Mars_SM.fbx"), "out": spec.EXPORT_DIR, "size": "2048",
            "cap_size": "1024", "cap_cm": "37", "preview": ""}
MASK_NAME = "MeatSlab_Marbling_Mars_T.png"
NORMAL_NAME = "MeatSlab_Marbling_Normal_Mars_T.png"
CAP_MASK_NAME = "MeatSlab_CapMarbling_Mars_T.png"
CAP_NORMAL_NAME = "MeatSlab_CapMarbling_Normal_Mars_T.png"

# the cube's recipe (build_cooking_textures.build_meat), feature sizes in cm
FAT_FREQ = 0.45
FAT_WIDTH_CM = 0.30
VEIN_FREQ = 1.3
VEIN_WIDTH_CM = 0.09
VEIN_REACH_CM = 1.5
VEIN_STRENGTH = 0.34
MOTTLE = 0.55
GRAIN = np.array([1.0 / 2.2, 1.0, 1.0])          # streaks run 2.2x longer along the slab's long axis (cube: along Z)
FIBRE = np.array([1.0 / 7.0, 1.0, 1.0])          # fibre grain stretched 7:1 along it
# the slab only: the presence field (patches about 7 cm across) that keeps about half of the streak network
PRESENCE_FREQ = 0.15
PRESENCE = (0.36, 0.56)
# the cube's normal: k = 6 at 0.30 UV over 4 cm of a 1024 texture (76.8 texels / cm); k keeps that slope per cm
CUBE_TEXELS_PER_CM = 0.30 * 1024 / 4.0
CUBE_NORMAL_K = 6.0
# the slab's paint (build_food_meats.build_meatslab): the lean is near-zero green, the marbling core / sinew / fat are pale
PAINT_PALE_G = (0.06, 0.40)                       # linear green from "lean" to "pale paint"
PAINTED_LINES = 0.7                               # how much of the painted marbling line carries into R
FAT_CAP = (0.82, 0.97)                            # R range over the fat cap (a little lumpy, never quite the streak core)
DILATE_PX = 8


# ---------------------------------------------------------------- noise (food_common's value noise, optionally periodic)
class Noise:
    """fbm over cm positions. With period_cm the y / z lattice wraps so the field tiles every period_cm (each frequency
    snapped to a whole number of periods); x never wraps (the cap tile is the x = 0 plane)."""

    def __init__(self, period_cm=None):
        self.period_cm = period_cm

    def _freq(self, freq):
        fv = np.broadcast_to(np.asarray(freq, float), (3,)).copy()
        if self.period_cm:
            for k in (1, 2):
                fv[k] = max(1.0, round(fv[k] * self.period_cm)) / self.period_cm
        return fv

    def _noise3(self, p, seed, period):
        p = np.asarray(p, np.float32)
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
                    c = []
                    for k, d in enumerate((dx, dy, dz)):
                        ck = i[..., k] + d
                        if period is not None and period[k] > 0:
                            ck = np.mod(ck, period[k])
                        c.append((ck & 0xFFFFFFFF).astype(np.uint32))
                    out = out + fc._hash(c[0], c[1], c[2], seed) * wx * wy * wz
        return out

    def fbm(self, p, freq, seed, octaves=4, gain=0.5, offset=0.0):
        """= food_common.fbm(p * freq + offset, seed, octaves, gain), periodic when period_cm is set."""
        fv = self._freq(freq)
        lattice = np.asarray(p) * fv + offset
        period = None
        if self.period_cm:
            period = np.array([0, int(round(fv[1] * self.period_cm)), int(round(fv[2] * self.period_cm))])
        total, amp, norm, scale = 0.0, 1.0, 0.0, 1.0
        for o in range(octaves):
            per = None if period is None else period * int(scale)     # a constant shift never breaks the wrap
            total = total + amp * self._noise3(lattice * scale + o * 17.31, seed + o * 101, per)
            norm += amp
            amp *= gain
            scale *= 2.0
        return total / norm


def unit(x, lo=0.02, hi=0.98):
    a, b = np.quantile(x, lo), np.quantile(x, hi)
    return np.clip((x - a) / max(b - a, 1e-6), 0.0, 1.0)


def iso_distance(field, p, eps=0.01):
    """Distance (cm) to the field's 0.5 iso-surface from the 3D gradient (build_cooking_textures.iso_distance)."""
    f0 = field(p)
    g2 = 0.0
    for k in range(3):
        step = np.zeros(3)
        step[k] = eps
        g2 = g2 + ((field(p + step) - f0) / eps) ** 2
    return np.abs(f0 - 0.5) / np.maximum(np.sqrt(g2), 0.02)


# ---------------------------------------------------------------- the fields (p: (n, 3) cm)
def streak_fat(nz, p):
    """The cube's marbling: broad, soft pale streaks with faint branching veins, thinned by the presence field (0..1)."""
    def warp_at(q):
        return np.stack([nz.fbm(q, 0.3, 300 + k, 2, offset=k * 9.7) for k in range(3)], axis=-1) - 0.5

    def streak_field(q):
        return nz.fbm(q, GRAIN * FAT_FREQ, 1, 2, gain=0.3, offset=warp_at(q) * 0.7)

    def vein_field(q):
        return nz.fbm(q, GRAIN * VEIN_FREQ, 8, 2, gain=0.35, offset=warp_at(q) * 0.9 + 7.0)

    dist = iso_distance(streak_field, p)
    swell = nz.fbm(p, 0.7, 2, 2, offset=13.0)
    width = FAT_WIDTH_CM * (0.5 + 1.0 * fc.smoothstep(0.25, 0.75, swell))
    core = 1.0 - fc.smoothstep(width * 0.2, width, dist)
    halo = 1.0 - fc.smoothstep(width, width * 2.6, dist)
    fat = np.maximum(core, halo * 0.22) * (0.8 + 0.2 * fc.smoothstep(0.2, 0.7, swell))
    near = 1.0 - fc.smoothstep(VEIN_REACH_CM * 0.35, VEIN_REACH_CM, dist)
    broken = fc.smoothstep(0.3, 0.55, nz.fbm(p, 1.2, 9, 2, offset=21.0))
    dist2 = iso_distance(vein_field, p)
    vein = (1.0 - fc.smoothstep(VEIN_WIDTH_CM * 0.25, VEIN_WIDTH_CM, dist2)) * near * broken
    presence = fc.smoothstep(PRESENCE[0], PRESENCE[1], nz.fbm(p, PRESENCE_FREQ, 14, 2, offset=51.0))
    return np.maximum(fat, vein * VEIN_STRENGTH) * presence


def detail(nz, p):
    """(fibre, mottle, breakup, bump) raw fields; they are normalised over the whole texture afterwards."""
    fibre = nz.fbm(p, FIBRE * 2.6, 4, 2)
    mottle = nz.fbm(p, 0.8, 10, 2, offset=41.0)
    breakup = nz.fbm(p, 1.3, 5, 4, gain=0.55, offset=31.0)
    bump = nz.fbm(p, 1.8, 7, 2, offset=5.0)
    return fibre, mottle, breakup, bump


def normal_from_height(height_bu, k):
    """Tangent normal exactly as the cube's (image rows top-down, DirectX green) from bottom-up height rows."""
    h_td = height_bu[::-1].astype(np.float64)
    gy, gx = np.gradient(h_td)
    n = np.stack([-gx * k, -gy * k, np.ones_like(gx)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n[::-1]


def save_normal(path, n_bu):
    fc.save_png(path, np.concatenate([n_bu * 0.5 + 0.5, np.ones(n_bu.shape[:2] + (1,))], axis=-1))


# ---------------------------------------------------------------- geometry
def load_slab(fbx):
    fc.clear_scene()
    bpy.ops.import_scene.fbx(filepath=fbx)
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    if len(objs) != 1:
        raise RuntimeError("%s: expected one mesh, found %d" % (fbx, len(objs)))
    obj = objs[0]
    if "UVMap" not in obj.data.uv_layers or not len(obj.data.color_attributes):
        raise RuntimeError("%s: needs the UVMap layer and the Col colours" % fbx)
    return obj


def raster(obj, size):
    """Per texel of UV0 (bottom-up rows, as Blender stores images): position cm, linear corner colour, slot (-1 outside
    the islands), and the area-weighted median cm per UV unit."""
    me = obj.data
    mw = np.array(obj.matrix_world)
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = (np.c_[co.reshape(-1, 3), np.ones(len(me.vertices))] @ mw.T)[:, :3] * 100.0
    me.calc_loop_triangles()
    tris = np.empty(len(me.loop_triangles) * 3, int)
    me.loop_triangles.foreach_get("loops", tris)
    tris = tris.reshape(-1, 3)
    slot = np.empty(len(me.loop_triangles), int)
    me.loop_triangles.foreach_get("material_index", slot)
    lv = np.empty(len(me.loops), int)
    me.loops.foreach_get("vertex_index", lv)
    uv = np.empty(len(me.loops) * 2)
    me.uv_layers["UVMap"].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    attr = me.color_attributes.get(spec.COLOR_ATTR) or me.color_attributes[0]
    if attr.domain != "CORNER":
        raise RuntimeError("expected corner colours, found %s" % attr.domain)
    col = np.empty(len(attr.data) * 4)
    attr.data.foreach_get("color", col)
    col = col.reshape(-1, 4)

    pos = np.zeros((size, size, 3), np.float32)
    rgb = np.zeros((size, size, 3), np.float32)
    sl = np.full((size, size), -1, np.int8)
    cm_per_uv = []
    for t, s in zip(tris, slot):
        u = uv[t] * size - 0.5                                         # texel-centre frame
        p = co[lv[t]]
        e1, e2 = uv[t][1] - uv[t][0], uv[t][2] - uv[t][0]
        area_uv = abs(e1[0] * e2[1] - e1[1] * e2[0]) * 0.5
        area_cm = np.linalg.norm(np.cross(p[1] - p[0], p[2] - p[0])) * 0.5
        if area_uv > 1e-12:
            cm_per_uv.append((math.sqrt(area_cm / area_uv), area_cm))
        x0, x1 = int(max(0, math.floor(u[:, 0].min()))), int(min(size - 1, math.ceil(u[:, 0].max())))
        y0, y1 = int(max(0, math.floor(u[:, 1].min()))), int(min(size - 1, math.ceil(u[:, 1].max())))
        if x1 < x0 or y1 < y0:
            continue
        X, Y = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        d = (u[1, 1] - u[2, 1]) * (u[0, 0] - u[2, 0]) + (u[2, 0] - u[1, 0]) * (u[0, 1] - u[2, 1])
        if abs(d) < 1e-12:
            continue
        w0 = ((u[1, 1] - u[2, 1]) * (X - u[2, 0]) + (u[2, 0] - u[1, 0]) * (Y - u[2, 1])) / d
        w1 = ((u[2, 1] - u[0, 1]) * (X - u[2, 0]) + (u[0, 0] - u[2, 0]) * (Y - u[2, 1])) / d
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        if not inside.any():
            continue
        W = np.stack([w0[inside], w1[inside], w2[inside]], axis=-1)
        ys, xs = Y[inside], X[inside]
        pos[ys, xs] = W @ p
        rgb[ys, xs] = W @ col[t][:, :3]
        sl[ys, xs] = s
    cpu = np.array(cm_per_uv)
    order = np.argsort(cpu[:, 0])
    cum = np.cumsum(cpu[order, 1])
    median_cm_per_uv = float(cpu[order, 0][np.searchsorted(cum, cum[-1] * 0.5)])
    return pos, rgb, sl, median_cm_per_uv


def dilate(values, covered, passes):
    """Grow covered texels outward `passes` texels (mean of covered 4-neighbours); returns values, grown coverage."""
    v = values.copy()
    c = covered.copy()
    for _ in range(passes):
        acc = np.zeros_like(v)
        n = np.zeros(c.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            cs = np.roll(c, (dy, dx), axis=(0, 1))
            acc += np.roll(v, (dy, dx), axis=(0, 1)) * cs[..., None]
            n += cs
        grow = (~c) & (n > 0)
        v[grow] = acc[grow] / n[grow][:, None]
        c = c | grow
    return v, c


def plane_points(size, cm_per_uv):
    """Texel centres of a plane across the grain (x = 0), y / z = UV * cm_per_uv; bottom-up rows."""
    px = (np.arange(size) + 0.5) / size
    gu, gv = np.meshgrid(px, px)
    return np.stack([np.zeros_like(gu), gu * cm_per_uv, gv * cm_per_uv], axis=-1).astype(np.float32)


# ---------------------------------------------------------------- build
def build_slab(obj, out_dir, size):
    nz = Noise()
    pos, rgb, slot, cm_per_uv = raster(obj, size)
    cover = slot >= 0
    print("meatslab marbling: %d x %d, coverage %.3f, %.1f cm per UV unit (area-weighted median)"
          % (size, size, cover.mean(), cm_per_uv))
    # gutter: the lean cross-section at the slab's own UV scale, under the dilated island borders
    p = np.where(cover[..., None], pos, plane_points(size, cm_per_uv)).reshape(-1, 3)

    lean_fat = streak_fat(nz, p).reshape(size, size)
    fibre, mottle, breakup, bump = (f.reshape(size, size) for f in detail(nz, p))
    painted = fc.smoothstep(PAINT_PALE_G[0], PAINT_PALE_G[1], rgb[..., 1])
    skin = slot == 1
    cap_lumps = fc.smoothstep(0.25, 0.75, nz.fbm(p, 0.35, 12, 2, offset=61.0)).reshape(size, size)
    fat = np.where(skin, FAT_CAP[0] + (FAT_CAP[1] - FAT_CAP[0]) * cap_lumps,
                   np.maximum(lean_fat, PAINTED_LINES * painted * cover))
    g = (1.0 - MOTTLE) * unit(fibre) + MOTTLE * unit(mottle)
    b = unit(breakup)
    a = bfm.edge_raster(obj, size)                                     # convex rims, already in UV0 (bottom-up)
    height = 0.2 * unit(fibre) + 0.55 * unit(bump) + 0.25 * b - 0.2 * fat

    # island edges grow over the gutter so bilinear fetches and the first mips at a border see the island
    stack = np.stack([fat, g, b, a, height], axis=-1).astype(np.float32)
    grown, near = dilate(np.where(cover[..., None], stack, 0.0), cover, DILATE_PX)
    stack = np.where(near[..., None], grown, stack)
    stack[..., 3] = np.where(near, stack[..., 3], 0.0)                 # no rims in the gutter
    fat, g, b, a, height = (stack[..., k] for k in range(5))

    k = CUBE_NORMAL_K * CUBE_TEXELS_PER_CM / (size / cm_per_uv)
    n_bu = normal_from_height(height, k)
    mask = np.stack([fat, g, b, a], axis=-1)
    fc.save_png(os.path.join(out_dir, MASK_NAME), mask)
    save_normal(os.path.join(out_dir, NORMAL_NAME), n_bu)
    lean_px = cover & ~skin
    stats = {"cm_per_uv": cm_per_uv, "coverage": float(cover.mean()), "normal_k": k,
             "fat_on_lean": float(fat[lean_px].mean()), "fat_on_cap": float(fat[skin].mean()),
             "lean_streak_share": float((fat[lean_px] > 0.5).mean())}
    print("meatslab marbling: R mean on lean %.3f (texels > 0.5: %.3f), on the fat cap %.3f, normal k %.2f"
          % (stats["fat_on_lean"], stats["lean_streak_share"], stats["fat_on_cap"], k))
    return stats, mask, n_bu


def build_cap(out_dir, size, cap_cm):
    """The tileable lean cross-section for the runtime cut cap: cap_cm per UV unit, wraps in u and v."""
    nz = Noise(period_cm=cap_cm)
    p = plane_points(size, cap_cm).reshape(-1, 3)
    fat = streak_fat(nz, p).reshape(size, size)
    fibre, mottle, breakup, bump = (f.reshape(size, size) for f in detail(nz, p))
    g = (1.0 - MOTTLE) * unit(fibre) + MOTTLE * unit(mottle)
    b = unit(breakup)
    height = 0.2 * unit(fibre) + 0.55 * unit(bump) + 0.25 * b - 0.2 * fat
    mask = np.stack([fat, g, b, np.zeros_like(fat)], axis=-1)
    k = CUBE_NORMAL_K * CUBE_TEXELS_PER_CM / (size / cap_cm)
    # wrap the height before the gradient so the normal tiles too
    hp = np.pad(height, 1, mode="wrap")
    n_bu = normal_from_height(hp, k)[1:-1, 1:-1]
    fc.save_png(os.path.join(out_dir, CAP_MASK_NAME), mask)
    save_normal(os.path.join(out_dir, CAP_NORMAL_NAME), n_bu)
    seam = max(float(np.abs(mask[0] - mask[-1]).max()), float(np.abs(mask[:, 0] - mask[:, -1]).max()))
    stats = {"cap_fat": float(fat.mean()), "cap_seam": seam, "cap_k": k}
    print("meatslab cap tile: %d x %d over %.1f cm, R mean %.3f, worst edge-to-edge step %.3f, normal k %.2f"
          % (size, size, cap_cm, stats["cap_fat"], seam, k))
    return stats, mask, n_bu


def _lin(c):
    c = np.asarray(c, float) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def write_preview(preview_dir, mask, n_bu, cap_mask):
    """One strip, half resolution: R, G, B, A, the normal, the raw colour Meat_Mars_M gives (lean -> fat ramp keys at
    time 0, Fibre Contrast 0.2 at crust 0), then the cap tile's raw colour 2 x 2 (seams would show as lines)."""
    os.makedirs(preview_dir, exist_ok=True)
    lean, fatc = _lin((186, 56, 64)), _lin((232, 184, 170))

    def raw(m):
        c = lean + (fatc - lean) * m[..., :1]
        return np.clip(c * (1.0 + (m[..., 1:2] - 0.5) * 2.0 * 0.2 * 0.4), 0.0, 1.0) ** (1.0 / 2.2)

    size = mask.shape[0]
    tiles = [np.repeat(mask[..., k:k + 1], 3, axis=-1) for k in range(4)] + [n_bu * 0.5 + 0.5, raw(mask)]
    cap = np.tile(raw(cap_mask), (2, 2, 1))
    cap = cap[:: max(1, cap.shape[0] // size), :: max(1, cap.shape[1] // size)][:size, :size]
    tiles.append(cap)
    row = np.concatenate([t[::2, ::2] for t in tiles], axis=1)
    path = os.path.join(preview_dir, "MeatSlab_Marbling_preview.png")
    fc.save_png(path, np.concatenate([row, np.ones(row.shape[:2] + (1,))], axis=-1))
    print("preview %s" % path)


def main():
    args = fc.cli_args(DEFAULTS)
    out_dir = args["out"]
    os.makedirs(out_dir, exist_ok=True)
    obj = load_slab(args["fbx"])
    stats, mask, n_bu = build_slab(obj, out_dir, int(args["size"]))
    cap_stats, cap_mask, _ = build_cap(out_dir, int(args["cap_size"]), float(args["cap_cm"]))
    if args["preview"] and args["preview"] is not True:
        write_preview(args["preview"], mask, n_bu, cap_mask)
    problems = []
    if not 0.05 < stats["fat_on_lean"] < 0.35:
        problems.append("lean marbling share %.3f outside 0.05..0.35" % stats["fat_on_lean"])
    if stats["fat_on_cap"] < 0.8:
        problems.append("fat cap R %.3f below 0.8" % stats["fat_on_cap"])
    if not 0.03 < cap_stats["cap_fat"] < 0.35:
        problems.append("cap tile marbling share %.3f outside 0.03..0.35" % cap_stats["cap_fat"])
    if problems:
        raise SystemExit("MEATSLAB_MARBLING_FAILED: " + "; ".join(problems))
    print("MEATSLAB_MARBLING_OK")


if __name__ == "__main__":
    main()
