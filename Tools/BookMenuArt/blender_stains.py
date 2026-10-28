"""Stage 3: stain / wear textures on UV2 + Blender preview materials, written into Blender/BookMenu_Worn.blend.

    blender -b Tools/BookMenuArt/Blender/BookMenu_Worn.blend --python Tools/BookMenuArt/blender_stains.py

Stains are designed in 3D, not in UV space: every UV2 texel is rasterized with the position it has in a posed book
(pages: lying open; cover: lying closed) and with its rest-pose position (for distances to page / board edges), then
each stain is a function of that position. A spill on the right page therefore also soaks the turning sheet and the page
under it and runs over the fore-edge without seams, whatever the UV islands look like.

Stains live on their own UV channel, StainUV (Unreal UV3), built here: UV2 is not unique across the pages (see
blender_common.UV_STAIN), and the plugin's materials keep sampling UV0-UV2 exactly as before.

Outputs (Textures/), one set for the page group (every slot but Cover) and one for the cover, both on StainUV:
    T_BookWorn_<Part>_Stain_BC.png    sRGB  RGB = stain colour, A = stain opacity. Overlay: lerp(base, RGB, A).
    T_BookWorn_<Part>_StainMask.png   linear R = liquid (coffee/sauce/water), G = grease, B = grime, A = total.
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import kdtree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_common as bc  # noqa: E402

RES = 2048
SEED = 23
DILATE_PX = 8

PAGE_POSE = ("Book_Lying_Open_01", 1)
COVER_POSE = ("Book_Lying_R_01", 1)
SHEET_PARTNERS = (("PageB", "PageD"), ("PageC", "PageA"))

# --------------------------------------------------------------------------------------------------------------- noise


def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761 & 0xFFFFFFFF)
    h &= 0xFFFFFFFF
    h = ((h ^ (h >> 16)) * 0x45D9F3B) & 0xFFFFFFFF
    h = ((h ^ (h >> 16)) * 0x45D9F3B) & 0xFFFFFFFF
    h ^= h >> 16
    return (h & 0xFFFFFF).astype(np.float64) / float(0xFFFFFF)


def value_noise(p, seed):
    """Smooth 3D value noise in [-1, 1]; p is N x 3 in feature-size units."""
    i = np.floor(p).astype(np.int64)
    f = p - i
    u = f * f * (3 - 2 * f)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (u[:, 0] if dx else 1 - u[:, 0]) * (u[:, 1] if dy else 1 - u[:, 1]) * (u[:, 2] if dz else 1 - u[:, 2])
                out = out + w * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out * 2 - 1


def fbm(p, scale, seed, octaves=4):
    total, amp, norm = 0.0, 1.0, 0.0
    q = p / scale
    for o in range(octaves):
        total = total + amp * value_noise(q, seed + o * 101)
        norm += amp
        amp *= 0.5
        q = q * 2.03 + 17.17
    return total / norm


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# --------------------------------------------------------------------------------------------------------- rasterizing


def set_pose(arm, action_name, frame):
    action = bpy.data.actions[action_name]
    arm.animation_data.action = action
    arm.animation_data.action_slot = action.slots[0]
    bpy.context.scene.frame_set(frame)


def build_stain_uv(mesh):
    """StainUV = UV2, except each turning-sheet corner copies the UV2 of the partner page's vertex at the same rest-pose
    (y, z) -- in rest pose all four page grids coincide, and the sheet lies on its partner when it is face up."""
    me = mesh.data
    layer = me.uv_layers.get(bc.UV_STAIN) or me.uv_layers.new(name=bc.UV_STAIN, do_init=False)
    n = len(me.loops)
    uv = np.empty(n * 2)
    me.uv_layers[bc.UV_UNIQUE].data.foreach_get("uv", uv)
    uv = uv.reshape(n, 2)
    corner_vert = np.empty(n, int)
    me.loops.foreach_get("vertex_index", corner_vert)
    corner_slot = np.repeat([p.material_index for p in me.polygons], [p.loop_total for p in me.polygons])
    co = np.array([v.co[:] for v in me.vertices])
    for sheet, partner in SHEET_PARTNERS:
        part = np.flatnonzero(corner_slot == bc.SLOT_NAMES.index(partner))
        tree = kdtree.KDTree(len(part))
        for c in part:
            tree.insert((0.0, co[corner_vert[c], 1], co[corner_vert[c], 2]), int(c))
        tree.balance()
        worst = 0.0
        for c in np.flatnonzero(corner_slot == bc.SLOT_NAMES.index(sheet)):
            _, src, dist = tree.find((0.0, co[corner_vert[c], 1], co[corner_vert[c], 2]))
            uv[c] = uv[src]
            worst = max(worst, dist)
        print(f"STAINS StainUV: {sheet} -> {partner} UV2, worst vertex mismatch {worst:.3f} local units")
    layer.data.foreach_set("uv", uv.ravel())


def rasterize(mesh, slots, rest_co):
    """StainUV raster of the evaluated (posed) mesh, restricted to faces in `slots`. Returns per-texel posed position
    (m), posed normal, rest position (local units) and material index, plus the coverage mask."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(dg)
    me = ev.data
    mw = np.array(ev.matrix_world)
    co = np.array([v.co[:] for v in me.vertices]) @ mw[:3, :3].T + mw[:3, 3]
    nrm = np.array([v.normal[:] for v in me.vertices]) @ mw[:3, :3].T
    nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12)
    uv_layer = me.uv_layers[bc.UV_STAIN].data
    me.calc_loop_triangles()
    writes = np.zeros((RES, RES), np.int16)

    pos = np.zeros((RES, RES, 3))
    nor = np.zeros((RES, RES, 3))
    rest = np.zeros((RES, RES, 3))
    mat = np.full((RES, RES), -1, np.int16)
    for tri in me.loop_triangles:
        if tri.material_index not in slots:
            continue
        uv = np.array([uv_layer[l].uv[:] for l in tri.loops]) * RES - 0.5
        vi = list(tri.vertices)
        x0, y0 = np.floor(uv.min(0)).astype(int)
        x1, y1 = np.ceil(uv.max(0)).astype(int)
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, RES - 1), min(y1, RES - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        (ax, ay), (bx, by), (cx, cy) = uv
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        w0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
        w1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
        w2 = 1 - w0 - w1
        inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)   # island borders are filled by dilate()
        if not inside.any():
            continue
        W = np.stack([w0[inside], w1[inside], w2[inside]], 1)
        rr, cc = ys[inside], xs[inside]
        pos[rr, cc] = W @ co[vi]
        nor[rr, cc] = W @ nrm[vi]
        rest[rr, cc] = W @ rest_co[vi]
        mat[rr, cc] = tri.material_index
        writes[rr, cc] += 1
    covered = mat >= 0
    print(f"STAINS raster: {int(covered.sum())} texels, {int((writes > 1).sum())} written by more than one island "
          f"(shared edges only expected)")
    nor[covered] /= np.maximum(np.linalg.norm(nor[covered], axis=1, keepdims=True), 1e-12)
    return pos, nor, rest, mat, covered


def dilate(img, covered, iterations):
    """Bleed covered texels outward so mips and bilinear taps at island borders do not pick up empty space."""
    img = img.copy()
    have = covered.copy()
    for _ in range(iterations):
        acc = np.zeros_like(img)
        cnt = np.zeros(have.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            src = np.roll(np.roll(have, dy, 0), dx, 1)
            acc += np.roll(np.roll(img, dy, 0), dx, 1) * src[..., None]
            cnt += src
        grow = (~have) & (cnt > 0)
        img[grow] = acc[grow] / cnt[grow][:, None]
        have |= grow
    return img


# ---------------------------------------------------------------------------------------------------------- compositing


class Layers:
    """Premultiplied 'over' compositing of stain layers, with per-kind channel masks."""

    def __init__(self, n):
        self.rgb = np.zeros((n, 3))
        self.alpha = np.zeros(n)
        self.kind = {"liquid": np.zeros(n), "grease": np.zeros(n), "grime": np.zeros(n)}

    def add(self, alpha, color, kind):
        a = np.clip(alpha, 0, 1)
        if a.ndim == 0:
            a = np.full(len(self.alpha), float(a))
        c = np.asarray(color, dtype=np.float64)
        c = np.broadcast_to(c, (len(a), 3)) if c.ndim == 1 else c
        self.rgb = self.rgb * (1 - a[:, None]) + c * a[:, None]
        self.alpha = self.alpha * (1 - a) + a
        if kind:
            k = self.kind[kind]
            self.kind[kind] = k * (1 - a) + a


def ring(P, center, radius, width, seed, gap=None):
    """Coffee-mug tide line: dark rim + faint fill, wobbly radius, optional faded arc."""
    d = P - center
    r = np.linalg.norm(d[:, :2], axis=1)
    ang = np.arctan2(d[:, 1], d[:, 0])
    circ = np.c_[np.cos(ang), np.sin(ang), np.zeros_like(ang)] * 1.6
    wob = radius * (1 + 0.035 * value_noise(circ + seed, seed) + 0.015 * value_noise(circ * 3 + seed, seed + 1))
    near = np.abs(r - wob) < radius * 0.5
    rim = np.exp(-(((r - wob) / width) ** 2)) * near
    fill = (r < wob) * (0.18 + 0.12 * value_noise(np.c_[d[:, :2] / (radius * 0.25), np.full_like(r, seed)], seed + 2))
    a = np.maximum(rim * (0.8 + 0.2 * value_noise(circ * 6 + seed, seed + 3)), fill.clip(0, 1) * 0.5)
    if gap is not None:
        g0, g1 = gap
        da = np.angle(np.exp(1j * (ang - (g0 + g1) / 2)))
        a *= 1 - 0.85 * smoothstep(0.0, 0.35, (g1 - g0) / 2 - np.abs(da))
    return a


def blob(P, center, radius, seed, edge=0.3, rough=0.35):
    """Irregular soft-edged spot (grease, splat cores, water). Distance is measured from above (XY): the open pages arc
    toward the gutter, and a spill soaks every layer under it, so height is ignored."""
    d = P - center
    d[:, 2] = 0.0
    r = np.linalg.norm(d, axis=1)
    n = fbm(d / radius * 1.5 + seed * 3.1, 1.0, seed, 3)
    rr = radius * (1 + rough * n)
    return 1 - smoothstep(rr * (1 - edge), rr, r)


def fingerprint(P, center, size, angle, seed):
    """Oval print with ridge pattern: concentric ellipses broken up by noise."""
    d = (P - center)[:, :2]
    ca, sa = math.cos(angle), math.sin(angle)
    x = (d[:, 0] * ca + d[:, 1] * sa) / size[0]
    y = (-d[:, 0] * sa + d[:, 1] * ca) / size[1]
    r = np.hypot(x, y)
    inside = 1 - smoothstep(0.7, 1.0, r + 0.15 * value_noise(np.c_[x * 3, y * 3, np.full_like(x, seed)], seed))
    ridges = 0.5 + 0.5 * np.sin(r * size[1] / 0.00045 * 2 * math.pi + 2.0 * value_noise(np.c_[x * 4, y * 4, np.full_like(x, seed + 1)], seed + 1))
    return inside * ridges


# ---------------------------------------------------------------------------------------------------------- the pages


def page_frames(mesh, slot_names):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(dg)
    mw = ev.matrix_world
    idx = {}
    for p in ev.data.polygons:
        idx.setdefault(p.material_index, set()).update(p.vertices)
    frames = {}
    for name in slot_names:
        pts = np.array([(mw @ ev.data.vertices[i].co)[:] for i in idx[bc.SLOT_NAMES.index(name)]])
        lo, hi = pts.min(0), pts.max(0)
        spine_is_min_x = abs(lo[0]) < abs(hi[0])
        frames[name] = {"spine": lo[0] if spine_is_min_x else hi[0], "fore": hi[0] if spine_is_min_x else lo[0],
                        "y0": lo[1], "y1": hi[1], "z": hi[2]}
    return frames


def page_point(frame, u, v):
    return np.array([frame["spine"] + u * (frame["fore"] - frame["spine"]), frame["y0"] + v * (frame["y1"] - frame["y0"]), frame["z"]])


def page_stains(P, N, R, M, frames, mm, rest_page):
    rng = np.random.default_rng(SEED)
    L = Layers(len(P))
    is_block = M == bc.SLOT_NAMES.index("PagesBase")
    is_page = ~is_block

    # Paper ageing: mottled yellowing everywhere, browning toward the page outline (rest-pose distance, so every page
    # browns along its own edges), heavier on the exposed block edges.
    L.add(0.10 + 0.08 * fbm(P, 0.06, SEED), (0.78, 0.62, 0.36), "grime")
    y, z = R[:, 1], R[:, 2]
    d_edge = np.minimum(rest_page["ymax"] - np.abs(y), rest_page["zmax"] - z) * rest_page["to_mm"]
    d_gutter = (z - rest_page["zmin"]) * rest_page["to_mm"]
    brown = (1 - smoothstep(0.0, 14.0, d_edge)) * (0.30 + 0.15 * fbm(P, 0.02, SEED + 1))
    brown += (1 - smoothstep(0.0, 9.0, d_gutter)) * 0.12
    L.add(np.where(is_page, brown, 0.32 + 0.12 * fbm(P, 0.015, SEED + 2)), (0.56, 0.38, 0.18), "grime")

    # Foxing: small rust spots, denser near the edges.
    fox = smoothstep(0.62, 0.78, value_noise(P / (2.2 * mm), SEED + 3) * 0.6 + fbm(P, 0.03, SEED + 4, 2) * 0.4)
    fox *= 0.35 + 0.65 * (1 - smoothstep(0.0, 40.0, d_edge))
    L.add(fox * 0.45, (0.52, 0.30, 0.14), "grime")

    # Water damage creeping up the bottom of the left page (and soaking the block's tail edge there).
    left, right = frames["PageA"], frames["PageD"]
    h = left["y0"] + 22 * mm + 9 * mm * fbm(np.c_[P[:, 0], np.zeros(len(P)), np.zeros(len(P))], 0.05, SEED + 5, 3)
    on_left = P[:, 0] * np.sign(left["fore"]) > 0
    wet = on_left * (1 - smoothstep(h - 1.5 * mm, h, P[:, 1]))
    tide = on_left * np.exp(-(((P[:, 1] - h) / (1.2 * mm)) ** 2))
    L.add(wet * 0.14 + tide * 0.38, (0.58, 0.42, 0.22), "liquid")

    # Mug ring set down at the right page's fore-edge: runs over onto the block.
    L.add(ring(P, page_point(right, 0.86, 0.30), 38 * mm, 1.1 * mm, SEED + 6, gap=(2.2, 3.4)), (0.36, 0.20, 0.08), "liquid")
    L.add(ring(P, page_point(right, 0.80, 0.33), 36 * mm, 0.8 * mm, SEED + 7, gap=(-1.2, 1.6)) * 0.45, (0.40, 0.24, 0.10), "liquid")

    # Grease: translucent darkening (also lowers roughness via the G mask).
    for (frame, u, v, r) in ((right, 0.62, 0.12, 17), (left, 0.25, 0.46, 9), (left, 0.82, 0.86, 6)):
        L.add(blob(P, page_point(frame, u, v), r * mm, SEED + int(u * 100)) * 0.42, (0.60, 0.47, 0.25), "grease")

    # Sauce splatter on the left page: a splat, a spray of droplets thrown away from it, darker dried rims.
    c = page_point(left, 0.50, 0.72)
    core = blob(P, c, 12 * mm, SEED + 8, edge=0.15, rough=0.45)
    rim = core * (1 - blob(P, c, 10 * mm, SEED + 8, edge=0.3, rough=0.45))
    L.add(core * 0.62 + rim * 0.25, (0.45, 0.13, 0.05), "liquid")
    throw = rng.normal(0, 1, 2)
    throw /= np.linalg.norm(throw)
    for _ in range(40):
        dist = rng.uniform(13, 75) * mm
        ang = math.atan2(throw[1], throw[0]) + rng.normal(0, 0.45)
        pc = c + np.array([math.cos(ang), math.sin(ang), 0]) * dist
        r = rng.uniform(0.5, 3.2) * mm * (1.25 - dist / (90 * mm))
        L.add(blob(P, pc, max(r, 0.35 * mm), int(rng.integers(1000)), edge=0.25, rough=0.25) * rng.uniform(0.5, 0.85),
              (0.42, 0.12, 0.05), "liquid")

    # Floury / sooty thumbs where pages get turned: lower fore-edge corners, plus the block edge right there.
    for frame, v, ang in ((right, 0.10, 0.5), (right, 0.16, 0.9), (left, 0.12, -0.6)):
        L.add(fingerprint(P, page_point(frame, 0.95, v), (8.5 * mm, 11.5 * mm), ang, SEED + int(v * 100)) * 0.32,
              (0.24, 0.20, 0.17), "grime")
    thumb_zone = is_block * np.exp(-(((P[:, 1] - (left["y0"] + 0.14 * (left["y1"] - left["y0"]))) / (40 * mm)) ** 2))
    L.add(thumb_zone * (0.30 + 0.15 * fbm(P, 0.01, SEED + 9)), (0.26, 0.21, 0.16), "grime")
    return L


# ---------------------------------------------------------------------------------------------------------- the cover


def cover_stains(P, N, R, mm, rest_cover):
    rng = np.random.default_rng(SEED + 100)
    L = Layers(len(P))
    y, z = R[:, 1], R[:, 2]
    d_edge = np.minimum(rest_cover["ymax"] - np.abs(y), rest_cover["zmax"] - z) * rest_cover["to_mm"]
    # The closed book's top board, outer face only (the bottom board's inner face also points up).
    up = N[:, 2] > 0.5
    top = up & (P[:, 2] > P[up, 2].max() - 3 * mm)

    L.add(0.18 + 0.12 * fbm(P, 0.05, SEED + 10), (0.10, 0.07, 0.05), "grime")
    corner = np.exp(-((rest_cover["ymax"] - np.abs(y)) ** 2 + (rest_cover["zmax"] - z) ** 2) * rest_cover["to_mm"] ** 2 / (14.0 ** 2))
    scuff = (1 - smoothstep(0.0, 6.0, d_edge)) * (0.45 + 0.35 * fbm(P, 0.008, SEED + 11)) + corner * 0.4
    L.add(scuff.clip(0, 1) * 0.75, (0.60, 0.44, 0.30), None)        # worn-through leather: lighter, not dirt

    for _ in range(14):                                               # scratches
        a = rng.uniform(-0.12, 0.12, 3) * np.array([1.5, 1.0, 0])
        b = a + rng.normal(0, 1, 3) * np.array([1, 1, 0]) * rng.uniform(8, 35) * mm
        ab = b - a
        t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
        dist = np.linalg.norm(P - (a + t[:, None] * ab), axis=1)
        L.add((1 - smoothstep(0.15 * mm, 0.45 * mm, dist)) * top * 0.5, (0.55, 0.40, 0.28), None)

    lo = P[top].min(0)
    hi = P[top].max(0)
    centre = lo + (hi - lo) * np.array([0.38, 0.62, 1.0])
    L.add(ring(P, centre, 40 * mm, 1.9 * mm, SEED + 12, gap=(0.4, 1.5)) * top * 0.5, (0.17, 0.09, 0.04), "liquid")
    for _ in range(9):
        pc = lo + (hi - lo) * np.array([rng.uniform(0.6, 0.95), rng.uniform(0.1, 0.5), 1.0])
        L.add(blob(P, pc, rng.uniform(1.0, 4.0) * mm, int(rng.integers(1000)), edge=0.3, rough=0.3) * top * 0.6,
              (0.12, 0.05, 0.02), "liquid")
    L.add(blob(P, lo + (hi - lo) * np.array([0.75, 0.3, 1.0]), 22 * mm, SEED + 13) * top * 0.35, (0.05, 0.03, 0.02), "grease")
    return L


# -------------------------------------------------------------------------------------------------------------- output


def save_png(name, rgba, colorspace):
    img = bpy.data.images.get(name) or bpy.data.images.new(name, RES, RES, alpha=True)
    if tuple(img.size) != (RES, RES):
        img.scale(RES, RES)
    img.colorspace_settings.name = colorspace
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    path = os.path.join(bc.TEXTURE_DIR, name + ".png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.filepath = bpy.path.relpath(path)
    return img


def write_part(part, L, covered):
    n_cov = int(covered.sum())
    alpha = np.zeros((RES, RES))
    alpha[covered] = L.alpha
    rgb = np.zeros((RES, RES, 3))
    straight = L.rgb / np.maximum(L.alpha, 1e-6)[:, None]
    rgb[covered] = straight
    mean = (straight * L.alpha[:, None]).sum(0) / max(L.alpha.sum(), 1e-6)
    rgb[~covered] = mean
    rgb = dilate(rgb, covered, DILATE_PX)
    alpha = dilate(alpha[..., None], covered, DILATE_PX)[..., 0]
    bc_img = np.concatenate([rgb, alpha[..., None]], -1)
    save_png(f"T_BookWorn_{part}_Stain_BC", bc_img, "sRGB")

    mask = np.zeros((RES, RES, 4))
    for c, key in enumerate(("liquid", "grease", "grime")):
        mask[covered, c] = L.kind[key]
    mask[covered, 3] = L.alpha
    mask = dilate(mask, covered, DILATE_PX)
    save_png(f"T_BookWorn_{part}_StainMask", mask, "Non-Color")
    print(f"STAINS {part}: {n_cov} texels, mean alpha {L.alpha.mean():.3f}, liquid {L.kind['liquid'].mean():.3f} "
          f"grease {L.kind['grease'].mean():.3f} grime {L.kind['grime'].mean():.3f}")


# ---------------------------------------------------------------------------------------------------------- materials


def image(path, colorspace):
    img = bpy.data.images.load(path, check_existing=True)
    img.colorspace_settings.name = colorspace
    img.filepath = bpy.path.relpath(path)
    return img


def build_material(mat, base_tex, normal_tex, stain_part, tiling=1.0, rotate=0.0):
    """Preview only (Unreal keeps its own materials): UE base textures on UV0 (RGB colour, A roughness), UE DirectX
    normal map with green flipped, stain overlay on UV2: lerp(base, stain RGB, stain A); grease lowers roughness."""
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs[0])

    uv0 = nt.nodes.new("ShaderNodeUVMap")
    uv0.uv_map = bc.UV_BASE
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (tiling, tiling, 1)
    mapping.inputs["Rotation"].default_value = (0, 0, rotate)
    nt.links.new(uv0.outputs[0], mapping.inputs[0])
    base = nt.nodes.new("ShaderNodeTexImage")
    base.image = image(os.path.join(bc.UE_EXPORT_DIR, "Textures", base_tex + ".png"), "sRGB")
    nt.links.new(mapping.outputs[0], base.inputs[0])

    uv2 = nt.nodes.new("ShaderNodeUVMap")
    uv2.uv_map = bc.UV_STAIN
    stain = nt.nodes.new("ShaderNodeTexImage")
    stain.image = image(os.path.join(bc.TEXTURE_DIR, f"T_BookWorn_{stain_part}_Stain_BC.png"), "sRGB")
    stain.image.alpha_mode = "STRAIGHT"
    smask = nt.nodes.new("ShaderNodeTexImage")
    smask.image = image(os.path.join(bc.TEXTURE_DIR, f"T_BookWorn_{stain_part}_StainMask.png"), "Non-Color")
    nt.links.new(uv2.outputs[0], stain.inputs[0])
    nt.links.new(uv2.outputs[0], smask.inputs[0])

    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    nt.links.new(stain.outputs["Alpha"], mix.inputs["Factor"])
    nt.links.new(base.outputs["Color"], mix.inputs[6])
    nt.links.new(stain.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])

    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(smask.outputs["Color"], sep.inputs[0])
    rough = nt.nodes.new("ShaderNodeMath")
    rough.operation = "MULTIPLY_ADD"                     # roughness * (1 - 0.5 * grease)
    neg = nt.nodes.new("ShaderNodeMath")
    neg.operation = "MULTIPLY_ADD"
    neg.inputs[1].default_value = -0.5
    neg.inputs[2].default_value = 1.0
    nt.links.new(sep.outputs[1], neg.inputs[0])
    nt.links.new(base.outputs["Alpha"], rough.inputs[0])
    nt.links.new(neg.outputs[0], rough.inputs[1])
    rough.inputs[2].default_value = 0.0
    nt.links.new(rough.outputs[0], bsdf.inputs["Roughness"])

    if normal_tex:
        ntex = nt.nodes.new("ShaderNodeTexImage")
        ntex.image = image(os.path.join(bc.UE_EXPORT_DIR, "Textures", normal_tex + ".png"), "Non-Color")
        nt.links.new(mapping.outputs[0], ntex.inputs[0])
        sep_n = nt.nodes.new("ShaderNodeSeparateColor")
        flip = nt.nodes.new("ShaderNodeMath")
        flip.operation = "SUBTRACT"
        flip.inputs[0].default_value = 1.0
        comb = nt.nodes.new("ShaderNodeCombineColor")
        nt.links.new(ntex.outputs["Color"], sep_n.inputs[0])
        nt.links.new(sep_n.outputs[0], comb.inputs[0])
        nt.links.new(sep_n.outputs[1], flip.inputs[1])
        nt.links.new(flip.outputs[0], comb.inputs[1])
        nt.links.new(sep_n.outputs[2], comb.inputs[2])
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nmap.uv_map = bc.UV_BASE
        nmap.inputs["Strength"].default_value = 0.6
        nt.links.new(comb.outputs[0], nmap.inputs["Color"])
        nt.links.new(nmap.outputs[0], bsdf.inputs["Normal"])

    for i, node in enumerate(nt.nodes):
        node.location = ((i % 5) * 260 - 900, -(i // 5) * 300)
    mat.diffuse_color = (0.30, 0.15, 0.08, 1) if stain_part == "Cover" else (0.85, 0.75, 0.55, 1)


def build_materials(mesh):
    for slot in mesh.material_slots:
        name = slot.material.name
        if name == "Cover":
            build_material(slot.material, "T_Cover_02_BC_R_2k", "T_Cover_02_N_1k", "Cover", tiling=0.5, rotate=math.pi / 2)
        elif name == "PagesBase":
            build_material(slot.material, "T_Pages_Side_02_BC_R_1k", "T_Pages_Side_02_N_1k", "Pages")
        else:
            build_material(slot.material, "T_Paper_02_BC_R_2k", "T_Paper_02_N_1k", "Pages")


# --------------------------------------------------------------------------------------------------------------- main


def rest_frame(rest_co, slot_verts, to_mm):
    r = rest_co[slot_verts]
    return {"ymax": np.abs(r[:, 1]).max(), "zmin": r[:, 2].min(), "zmax": r[:, 2].max(), "to_mm": to_mm}


def main():
    root, arm, mesh = bc.get_rig()
    bc.ensure_dir(bc.TEXTURE_DIR)
    for t in arm.animation_data.nla_tracks:
        t.mute = True
    saved_action = arm.animation_data.action
    k = root.scale[0] / root["ue_root_scale"]
    mm = 0.001                                  # posed positions are world metres at the final scale
    to_mm = 10.0 * k                            # rest positions are local units (cm at the original scale)

    me = mesh.data
    rest_co = np.array([v.co[:] for v in me.vertices])
    vert_slot = np.full(len(rest_co), -1)
    for p in me.polygons:
        for v in p.vertices:
            vert_slot[v] = p.material_index
    rest_page = rest_frame(rest_co, np.flatnonzero(vert_slot == bc.SLOT_NAMES.index("PageA")), to_mm)
    rest_cover = rest_frame(rest_co, np.flatnonzero(vert_slot == bc.SLOT_NAMES.index("Cover")), to_mm)

    build_stain_uv(mesh)
    # The sheet (PageB/PageC) shares its partners' StainUV texels, so only the partners are rasterized.
    page_slots = {bc.SLOT_NAMES.index(n) for n in ("PagesBase", "PageA", "PageD", "PageFirst", "PageLast")}
    set_pose(arm, *PAGE_POSE)
    frames = page_frames(mesh, ["PageA", "PageD"])
    pos, nor, rest, mat, cov = rasterize(mesh, page_slots, rest_co)
    L = page_stains(pos[cov], nor[cov], rest[cov], mat[cov], frames, mm, rest_page)
    write_part("Pages", L, cov)

    set_pose(arm, *COVER_POSE)
    pos, nor, rest, mat, cov = rasterize(mesh, {bc.SLOT_NAMES.index("Cover")}, rest_co)
    L = cover_stains(pos[cov], nor[cov], rest[cov], mm, rest_cover)
    write_part("Cover", L, cov)

    arm.animation_data.action = saved_action
    arm.animation_data.action_slot = saved_action.slots[0]
    bpy.context.scene.frame_set(bpy.context.scene.frame_start)
    build_materials(mesh)
    bpy.ops.wm.save_as_mainfile(filepath=bc.WORN_BLEND)
    print(f"STAINS ok: {bc.WORN_BLEND}")


main()
