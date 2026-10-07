"""Shared Blender helpers for the food builders (Blender 5.2, headless). Every builder does:

    import food_common as fc; spec = fc.spec
    obj = fc.new_object("Puffer_Mars_SM", verts_cm, faces, slots=("Skin", "Horn"), face_slots=slot_ids)
    fc.paint(obj, per_face_rgb, cavity=True)            # vertex colours "Col" (linear RGB + cavity in A)
    fc.smart_uv(obj)                                     # UV0 atlas
    fc.write_morph_uvs(obj, raw_cm, cooked_cm)           # only morphing meshes (UV1 / UV2)
    fc.bake_masks(obj, masks_fn)                         # <Name>_Mask_Mars_T.png from baked position / normal / AO
    fc.export_fbx(obj)                                   # FBX + JSON sidecar in spec.EXPORT_DIR
    fc.review_sheet([obj], "Puffer")                     # workbench contact sheet in spec.REVIEW_DIR

All geometry is handed in as CENTIMETRES (numpy (n, 3)); objects are created in metres at the origin with identity
transforms and stay there (bakes and exports assume it). Flat shading everywhere (spec style ruling).
"""
import json
import math
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import food_spec as spec  # noqa: E402

UE_MIRROR = np.array([1.0, -1.0, 1.0])     # Blender -> Unreal local axes (cm)


# ---------------------------------------------------------------- CLI / scene
def cli_args(defaults):
    """`blender -b --python x.py -- --key value ...` -> dict over defaults (flags without a value become True)."""
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = dict(defaults)
    i = 0
    while i < len(argv):
        key = argv[i].lstrip("-")
        if i + 1 < len(argv) and not argv[i + 1].startswith("--"):
            out[key] = argv[i + 1]
            i += 2
        else:
            out[key] = True
            i += 1
    return out


def ensure_dirs():
    for d in (spec.BLEND_DIR, spec.EXPORT_DIR, spec.REVIEW_DIR):
        os.makedirs(d, exist_ok=True)


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.images, bpy.data.cameras):
        for d in list(coll):
            if d.users == 0:
                coll.remove(d)


def save_blend(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=path, copy=False)


# ---------------------------------------------------------------- noise (numpy only)
def lumps(p, seed, freq):
    """Smooth pseudo-noise in -1..1 from a few fixed sinusoids over points p (n, 3). Deterministic per seed."""
    p = np.asarray(p, float)
    rng = np.random.default_rng(seed)
    total = np.zeros(len(p))
    amp_sum = 0.0
    for k in range(7):
        w = rng.normal(size=3)
        w = w / np.linalg.norm(w) * freq * (1.0 + 0.45 * k)
        amp = 1.0 / (1.0 + 0.6 * k)
        total += amp * np.sin(p @ w + rng.uniform(0.0, math.tau))
        amp_sum += amp
    return total / amp_sum


def _hash(ix, iy, iz, seed):
    h = (ix * np.uint32(374761393) + iy * np.uint32(668265263) + iz * np.uint32(2147483647)
         + np.uint32((seed * 974634777) & 0xFFFFFFFF))
    h = (h ^ (h >> np.uint32(13))) * np.uint32(1274126177)
    h = h ^ (h >> np.uint32(16))
    return h.astype(np.float32) / np.float32(4294967295.0)


def noise3(p, seed):
    """Value noise 0..1 at points p (..., 3)."""
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
                c = [((i[..., k] + d) & 0xFFFFFFFF).astype(np.uint32) for k, d in enumerate((dx, dy, dz))]
                out = out + _hash(c[0], c[1], c[2], seed) * wx * wy * wz
    return out


def fbm(p, seed, octaves=4, gain=0.5):
    total, amp, norm, freq = 0.0, 1.0, 0.0, 1.0
    for o in range(octaves):
        total = total + amp * noise3(np.asarray(p) * freq + o * 17.31, seed + o * 101)
        norm += amp
        amp *= gain
        freq *= 2.0
    return total / norm


def smoothstep(a, b, x):
    t = np.clip((np.asarray(x, float) - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------- primitives (cm)
def lathe(profile, segments, twist_seed=None, jitter=0.0):
    """Revolve an (r, z) profile. r == 0 rows become poles. jitter > 0 moves ring vertices radially (cm) per
    vertex for a hand-cut look. Returns (verts (n,3) cm, faces)."""
    rng = np.random.default_rng(twist_seed or 0)
    verts, faces, rings = [], [], []
    for r, z in profile:
        if r < 1e-6:
            rings.append([len(verts)])
            verts.append((0.0, 0.0, z))
        else:
            start = len(verts)
            for s in range(segments):
                a = math.tau * s / segments
                rr = r + (rng.uniform(-jitter, jitter) if jitter else 0.0)
                verts.append((rr * math.cos(a), rr * math.sin(a), z))
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
    return np.array(verts, float), faces


def loft(rings, close_start=True, close_end=True):
    """Skin a list of rings (each (k, 3) cm, same k, same winding) into a tube; caps are fans."""
    rings = [np.asarray(r, float) for r in rings]
    k = len(rings[0])
    verts = np.concatenate(rings)
    faces = []
    for i in range(len(rings) - 1):
        a, b = i * k, (i + 1) * k
        for s in range(k):
            s2 = (s + 1) % k
            faces.append([a + s, a + s2, b + s2, b + s])      # outward for rings wound CCW about the travel direction
    if close_start:
        faces.append(list(range(k - 1, -1, -1)))
    if close_end:
        last = (len(rings) - 1) * k
        faces.append(list(range(last, last + k)))
    return verts, faces


def ring(center, radius_a, radius_b, k, axis_u, axis_v, phase=0.0):
    """k points of an ellipse (radius_a along axis_u, radius_b along axis_v) around center."""
    c, u, v = (np.asarray(x, float) for x in (center, axis_u, axis_v))
    t = np.arange(k) * math.tau / k + phase
    return c[None, :] + np.outer(np.cos(t) * radius_a, u) + np.outer(np.sin(t) * radius_b, v)


def icosphere(radius_cm, subdivisions=2):
    """Icosphere (verts cm, tri faces) via bmesh."""
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius_cm)
    verts = np.array([v.co[:] for v in bm.verts], float)
    faces = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()
    return verts, faces


def merge(parts):
    """[(verts, faces, slot_index), ...] -> (verts, faces, face_slots) with offset indices."""
    verts, faces, slots = [], [], []
    base = 0
    for v, f, slot in parts:
        v = np.asarray(v, float)
        verts.append(v)
        faces.extend([[base + i for i in face] for face in f])
        slots.extend([slot] * len(f))
        base += len(v)
    return np.concatenate(verts), faces, slots


# ---------------------------------------------------------------- objects
def new_object(name, verts_cm, faces, slots=("Flesh",), face_slots=None, triangulate=False, recalc_normals=True):
    """Flat-shaded mesh object at the origin from cm vertices. Material slots are named per spec.SLOTS_*.
    recalc_normals makes every closed shell wind outward (bmesh recalc), so a builder's cap / side winding cannot
    leak into the export; pass False for geometry whose winding is deliberate."""
    for s in slots:
        if s not in spec.SLOTS_COOKING + spec.SLOTS_STATIC:
            raise ValueError("%s: slot %r is not in food_spec.SLOTS_*" % (name, s))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata((np.asarray(verts_cm, float) * 0.01).tolist(), [], [[int(i) for i in f] for f in faces])
    for s in slots:
        mat = bpy.data.materials.get(s) or bpy.data.materials.new(s)
        mesh.materials.append(mat)
    if face_slots is not None:
        mesh.polygons.foreach_set("material_index", [int(s) for s in face_slots])
    mesh.validate(verbose=False)
    if recalc_normals:
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bm.to_mesh(mesh)
        bm.free()
    mesh.polygons.foreach_set("use_smooth", [False] * len(mesh.polygons))
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if triangulate:
        triangulate_object(obj)
    return obj


def triangulate_object(obj):
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.polygons.foreach_set("use_smooth", [False] * len(obj.data.polygons))
    obj.data.update()


def verts_cm(obj):
    n = len(obj.data.vertices)
    co = np.empty(n * 3)
    obj.data.vertices.foreach_get("co", co)
    return co.reshape(n, 3) * 100.0


def set_verts_cm(obj, verts_cm_arr):
    obj.data.vertices.foreach_set("co", (np.asarray(verts_cm_arr, float) * 0.01).ravel())
    obj.data.update()


def face_centers_cm(obj):
    mesh = obj.data
    v = verts_cm(obj)
    return np.array([v[list(p.vertices)].mean(axis=0) for p in mesh.polygons])


def face_normals(obj):
    mesh = obj.data
    n = np.empty(len(mesh.polygons) * 3)
    mesh.polygons.foreach_get("normal", n)
    return n.reshape(-1, 3)


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def bounds_cm(obj):
    v = verts_cm(obj)
    return v.min(axis=0), v.max(axis=0)


def rest_on_floor(obj, verts=None):
    """Translate vertices so the XY centre is at 0 and the lowest point at z = 0 (spec pivot rule). Returns verts."""
    v = verts_cm(obj) if verts is None else np.asarray(verts, float)
    lo, hi = v.min(axis=0), v.max(axis=0)
    v = v - np.array([(lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, lo[2]])
    set_verts_cm(obj, v)
    return v


def cavity(obj, verts=None):
    """Per-vertex cavity 0..1 (1 open / convex, 0 deep concave) from edge curvature sign."""
    mesh = obj.data
    v = verts_cm(obj) if verts is None else np.asarray(verts, float)
    n = np.zeros((len(v), 3))
    mesh.vertices.foreach_get("normal", n.reshape(-1))
    e = np.empty(len(mesh.edges) * 2, dtype=np.int64)
    mesh.edges.foreach_get("vertices", e)
    e = e.reshape(-1, 2)
    d = v[e[:, 1]] - v[e[:, 0]]
    d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
    curv = np.einsum("ij,ij->i", n[e[:, 1]] - n[e[:, 0]], d)      # > 0 convex along the edge
    acc = np.zeros(len(v))
    cnt = np.zeros(len(v))
    np.add.at(acc, e[:, 0], curv)
    np.add.at(acc, e[:, 1], curv)
    np.add.at(cnt, e[:, 0], 1)
    np.add.at(cnt, e[:, 1], 1)
    mean = acc / np.maximum(cnt, 1)
    return np.clip(0.5 + mean * 1.5, 0.0, 1.0)


def paint(obj, rgb, alpha=None, domain="FACE", variation=0.06, seed=7, cavity_darken=0.35):
    """Write the "Col" attribute (corner domain, float, linear). rgb is (n_faces, 3) for domain FACE, (n_verts, 3)
    for POINT or (n_loops, 3) for CORNER. alpha defaults to the vertex cavity (spec: A = cavity). variation adds the
    per-facet value / hue jitter of the style; cavity_darken pulls crevice colour down and warm."""
    mesh = obj.data
    loops_v = np.empty(len(mesh.loops), dtype=np.int64)
    mesh.loops.foreach_get("vertex_index", loops_v)
    rgb = np.asarray(rgb, float)
    if domain == "FACE":
        counts = [len(p.vertices) for p in mesh.polygons]
        rgb = np.repeat(rgb, counts, axis=0)
    elif domain == "POINT":
        rgb = rgb[loops_v]
    if variation:
        rng = np.random.default_rng(seed)
        faces_of_loop = np.repeat(np.arange(len(mesh.polygons)), [len(p.vertices) for p in mesh.polygons])
        jitter = rng.uniform(-variation, variation, size=len(mesh.polygons))[faces_of_loop]
        hue = rng.uniform(-variation * 0.5, variation * 0.5, size=len(mesh.polygons))[faces_of_loop]
        rgb = rgb * (1.0 + jitter)[:, None]
        rgb = rgb * np.stack([1.0 + hue, np.ones_like(hue), 1.0 - hue], axis=1)
    cav = cavity(obj) if alpha is None else np.asarray(alpha, float)
    cav_l = cav[loops_v] if len(cav) == len(mesh.vertices) else cav
    if cavity_darken:
        dark = 1.0 - cavity_darken * (1.0 - cav_l)
        rgb = rgb * np.stack([dark ** 0.8, dark, dark ** 1.2], axis=1)      # darker and warmer in crevices
    rgb = np.clip(rgb, 0.0, 1.0)
    attr = mesh.color_attributes.get(spec.COLOR_ATTR)
    if attr is None:
        attr = mesh.color_attributes.new(spec.COLOR_ATTR, "FLOAT_COLOR", "CORNER")
    colors = np.ones((len(mesh.loops), 4))
    colors[:, :3] = rgb
    colors[:, 3] = cav_l
    attr.data.foreach_set("color", colors.ravel())
    idx = list(mesh.color_attributes).index(attr)
    mesh.color_attributes.active_color_index = idx
    mesh.color_attributes.render_color_index = idx
    mesh.update()


def srgb(r, g, b):
    """8-bit sRGB -> linear rgb tuple (for paint colours picked off the references)."""
    def lin(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return np.array([lin(r), lin(g), lin(b)])


# ---------------------------------------------------------------- UVs
def _only(obj):
    for o in bpy.context.scene.objects:
        o.select_set(o is obj)
    bpy.context.view_layer.objects.active = obj


def smart_uv(obj, angle_deg=66.0, margin=0.012):
    """UV0 atlas by Smart UV Project (non-overlapping islands with padding). Keeps the object at the origin."""
    mesh = obj.data
    if "UVMap" not in mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    mesh.uv_layers.active = mesh.uv_layers["UVMap"]
    _only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    try:
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(angle_deg), island_margin=margin,
                                 correct_aspect=True, scale_to_bounds=False)
    finally:
        bpy.ops.object.mode_set(mode="OBJECT")
    mesh.uv_layers.active = mesh.uv_layers["UVMap"]


def write_morph_uvs(obj, raw_cm, cooked_cm):
    """UV1 / UV2 = raw -> cooked offset in Unreal local cm (spec MORPH encoding). The mesh keeps the RAW shape."""
    mesh = obj.data
    offset = (np.asarray(cooked_cm, float) - np.asarray(raw_cm, float)) * UE_MIRROR
    loops_v = np.empty(len(mesh.loops), dtype=np.int64)
    mesh.loops.foreach_get("vertex_index", loops_v)
    o = offset[loops_v]
    uv1 = mesh.uv_layers.get(spec.MORPH_UV[0]) or mesh.uv_layers.new(name=spec.MORPH_UV[0])
    uv2 = mesh.uv_layers.get(spec.MORPH_UV[1]) or mesh.uv_layers.new(name=spec.MORPH_UV[1])
    uv1.data.foreach_set("uv", np.stack([o[:, 0], 1.0 - o[:, 1]], axis=1).ravel())
    uv2.data.foreach_set("uv", np.stack([o[:, 2], np.ones(len(o))], axis=1).ravel())
    mesh.uv_layers.active = mesh.uv_layers["UVMap"]
    obj["morph_max_cm"] = float(np.abs(offset).max())
    mesh.update()


def write_vat_uvs(obj):
    """UV1.x = (vertex index + 0.5) / vertex count (spec VAT column), UV1.y = 0."""
    mesh = obj.data
    n = len(mesh.vertices)
    loops_v = np.empty(len(mesh.loops), dtype=np.int64)
    mesh.loops.foreach_get("vertex_index", loops_v)
    uv1 = mesh.uv_layers.get("VATColumn") or mesh.uv_layers.new(name="VATColumn")
    uv1.data.foreach_set("uv", np.stack([(loops_v + 0.5) / n, np.zeros(len(loops_v))], axis=1).ravel())
    if "UVMap" in mesh.uv_layers:
        mesh.uv_layers.active = mesh.uv_layers["UVMap"]


# ---------------------------------------------------------------- baking (Cycles, headless)
def _bake_image(obj, name, size, bake_type, samples=1, margin=4, float_buffer=True):
    """Cycles-bake one pass of obj into a new image (bottom-up pixel order as Blender stores it)."""
    scene = bpy.context.scene
    prev_engine, prev_samples = scene.render.engine, scene.cycles.samples
    img = bpy.data.images.new(name, size, size, alpha=True, float_buffer=float_buffer)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.zeros(size * size * 4, np.float32))     # alpha 0 outside the islands = coverage
    nodes_added = []
    for mat in obj.data.materials:
        mat.use_nodes = True
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = img
        mat.node_tree.nodes.active = node
        nodes_added.append((mat, node))
    _only(obj)
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.render.bake.margin = margin
    scene.render.bake.use_clear = False            # a cleared image is opaque black; the zero pre-fill keeps alpha 0
    scene.render.bake.use_selected_to_active = False
    try:
        bpy.ops.object.bake(type=bake_type, margin=margin, use_clear=False)
    finally:
        for mat, node in nodes_added:
            mat.node_tree.nodes.remove(node)
        scene.render.engine, scene.cycles.samples = prev_engine, prev_samples
    px = np.empty(size * size * 4, np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(size, size, 4)       # row 0 = bottom


def bake_fields(obj, size=None, ao_samples=24):
    """Baked per-texel fields of UV0 as bottom-up (size, size, k) arrays:
    position (m, world == object space here), normal (object space, -1..1), ao (0..1), coverage (1 inside islands)."""
    size = size or spec.MASK_SIZE
    scene = bpy.context.scene
    scene.render.bake.normal_space = "OBJECT"          # before the NORMAL bake, or the first bake is tangent space
    pos = _bake_image(obj, "_bake_pos", size, "POSITION")
    nrm = _bake_image(obj, "_bake_nrm", size, "NORMAL")
    ao = _bake_image(obj, "_bake_ao", size, "AO", samples=ao_samples)
    return {"position": pos[..., :3], "normal": nrm[..., :3] * 2.0 - 1.0, "ao": ao[..., 0],
            "coverage": pos[..., 3]}


def save_png(path, rgba_bottom_up):
    """Write an 8-bit RGBA PNG from a (h, w, 4) float array in Blender's bottom-up row order, linear values."""
    h, w = rgba_bottom_up.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.clip(np.asarray(rgba_bottom_up, np.float32), 0.0, 1.0).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def save_exr(path, rgba_bottom_up):
    """Write a float16 EXR (linear, no compression tricks) from a (h, w, 4) float array, bottom-up rows."""
    h, w = rgba_bottom_up.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.asarray(rgba_bottom_up, np.float32).ravel())
    scene = bpy.context.scene
    settings = scene.render.image_settings
    prev = (settings.file_format, settings.color_depth, settings.color_mode, settings.exr_codec)
    settings.file_format, settings.color_depth, settings.color_mode, settings.exr_codec = "OPEN_EXR", "16", "RGBA", "NONE"
    try:
        img.save_render(path, scene=scene)
    finally:
        settings.file_format, settings.color_depth, settings.color_mode, settings.exr_codec = prev
    bpy.data.images.remove(img)


def bake_masks(obj, masks_fn, size=None, name=None):
    """<Name>_Mask_Mars_T.png in spec.EXPORT_DIR. masks_fn(fields) -> (h, w, 4) RGBA per spec mask channels, given
    the bake_fields dict (position in cm, Blender axes). Texels outside the islands are filled with neutral values."""
    size = size or spec.MASK_SIZE
    fields = bake_fields(obj, size)
    fields["position_cm"] = fields["position"] * 100.0
    rgba = np.asarray(masks_fn(fields), np.float32)
    cover = fields["coverage"][..., None] > 0.5
    neutral = np.array([0.0, 0.5, 0.5, 0.0], np.float32)
    rgba = np.where(cover, rgba, neutral)
    stem = (name or obj.name).replace("_Mars_SM", "")
    path = os.path.join(spec.EXPORT_DIR, "%s_Mask_Mars_T.png" % stem)
    save_png(path, rgba)
    return path, fields


# ---------------------------------------------------------------- export
def write_meta(obj, path, extra=None):
    lo, hi = bounds_cm(obj)
    ue_lo, ue_hi = np.minimum(lo * UE_MIRROR, hi * UE_MIRROR), np.maximum(lo * UE_MIRROR, hi * UE_MIRROR)
    meta = {
        "name": obj.name,
        "tris": tri_count(obj),
        "verts": len(obj.data.vertices),
        "bounds_min_cm": ue_lo.tolist(), "bounds_max_cm": ue_hi.tolist(),
        "size_cm": float((hi - lo).max()),
        "slots": [m.name for m in obj.data.materials],
        "uv_layers": [u.name for u in obj.data.uv_layers],
        "color_attr": spec.COLOR_ATTR in obj.data.color_attributes,
        "morph_max_cm": obj.get("morph_max_cm", 0.0),
    }
    for k in obj.keys():
        if not k.startswith("_") and k not in meta:
            try:
                json.dumps(obj[k])
                meta[k] = obj[k]
            except TypeError:
                meta[k] = str(obj[k])
    if extra:
        meta.update(extra)
    with open(os.path.splitext(path)[0] + ".json", "w") as fh:
        json.dump(meta, fh, indent=2)
    return meta


def export_fbx(obj, name=None, extra=None):
    """One FBX per object in spec.EXPORT_DIR with the cooking_spec exporter settings + triangles + linear colours."""
    ensure_dirs()
    name = name or obj.name
    path = os.path.join(spec.EXPORT_DIR, name + ".fbx")
    obj.data.uv_layers.active = obj.data.uv_layers["UVMap"] if "UVMap" in obj.data.uv_layers else obj.data.uv_layers[0]
    _only(obj)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, mesh_smooth_type="EDGE",
                             use_mesh_modifiers=True, add_leaf_bones=False, bake_anim=False, use_tspace=False,
                             apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y",
                             use_triangles=True, colors_type="LINEAR")
    meta = write_meta(obj, path, extra)
    print("exported %s  tris %d  size %.1f cm  slots %s  uv %s" % (
        name, meta["tris"], meta["size_cm"], meta["slots"], meta["uv_layers"]))
    return path


def check_against_spec(obj, key, tolerance=0.2):
    """Warn when the longest axis strays from food_spec.INGREDIENTS[key]['size_cm'] by more than tolerance."""
    want = spec.INGREDIENTS[key]["size_cm"]
    lo, hi = bounds_cm(obj)
    got = float((hi - lo).max())
    ok = abs(got - want) <= want * tolerance
    print("%s size %.1f cm (spec %.1f) %s" % (obj.name, got, want, "ok" if ok else "OFF SPEC"))
    return ok


# ---------------------------------------------------------------- review renders (workbench)
def _look_at(cam, eye, target):
    fwd = np.array(target, float) - np.array(eye, float)
    cam.location = eye
    cam.rotation_euler = (math.atan2(math.hypot(fwd[0], fwd[1]), -fwd[2]), 0.0, -math.atan2(fwd[0], fwd[1]))


VIEWS = {"iso": (1.0, -1.0, 0.75), "front": (0.0, -1.0, 0.12), "side": (1.0, 0.0, 0.12), "top": (0.0, -0.001, 1.0)}


def review_sheet(objs, stem, views=("iso", "front", "top"), color="VERTEX", size=(1800, 700), gap=1.25):
    """Workbench renders of objs in a row (spaced by their largest extent * gap) to spec.REVIEW_DIR/<stem>_<view>.png,
    then tiled into <stem>_sheet.png. Objects are moved for the render and put back. Returns the sheet path."""
    ensure_dirs()
    scene = bpy.context.scene
    sizes = [max(b[1] - b[0]) for b in (bounds_cm(o) for o in objs)]
    pitch = max(sizes) * gap * 0.01
    saved = [(o.location.copy(), o.hide_render) for o in objs]
    hidden = [o for o in scene.objects if o not in objs and o.type == "MESH"]
    hidden_state = [o.hide_render for o in hidden]
    cam_data = bpy.data.cameras.new("_ReviewCam")
    cam_data.clip_start, cam_data.clip_end = 0.01, 100.0
    cam = bpy.data.objects.new("_ReviewCam", cam_data)
    scene.collection.objects.link(cam)
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.filepath, scene.display.shading.color_type, scene.display.shading.light,
            scene.display.shading.show_cavity, scene.render.film_transparent)
    paths = []
    try:
        for o in hidden:
            o.hide_render = True
        for i, o in enumerate(objs):
            o.location = ((i - (len(objs) - 1) * 0.5) * pitch, 0.0, 0.0)
            o.hide_render = False
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = color
        scene.display.shading.show_cavity = True
        scene.render.film_transparent = False
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        width = pitch * len(objs)
        height = max(sizes) * 0.01
        for view in views:
            d = np.array(VIEWS[view], float)
            d /= np.linalg.norm(d)
            dist = max(width * 0.62, height * 1.3) / math.tan(math.radians(20))
            cam_data.lens = 50
            target = (0.0, 0.0, height * 0.45)
            _look_at(cam, tuple(np.array(target) + d * dist), target)
            path = os.path.join(spec.REVIEW_DIR, "%s_%s.png" % (stem, view))
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            paths.append(path)
    finally:
        for o, (loc, hr) in zip(objs, saved):
            o.location, o.hide_render = loc, hr
        for o, hr in zip(hidden, hidden_state):
            o.hide_render = hr
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
         scene.render.filepath, scene.display.shading.color_type, scene.display.shading.light,
         scene.display.shading.show_cavity, scene.render.film_transparent) = prev
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return tile_images(paths, os.path.join(spec.REVIEW_DIR, "%s_sheet.png" % stem), cols=1)


def tile_images(paths, out_path, cols=2):
    """Stack PNGs (same size) into one sheet using Blender's image API (no PIL in Blender)."""
    imgs = [bpy.data.images.load(p) for p in paths]
    w, h = imgs[0].size
    rows = (len(imgs) + cols - 1) // cols
    sheet = np.zeros((rows * h, cols * w, 4), np.float32)
    for i, img in enumerate(imgs):
        px = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(px)
        r, c = divmod(i, cols)
        r = rows - 1 - r                     # bottom-up rows: first image on top
        sheet[r * h:(r + 1) * h, c * w:(c + 1) * w] = px.reshape(h, w, 4)
        bpy.data.images.remove(img)
    out = bpy.data.images.new(os.path.basename(out_path), cols * w, rows * h, alpha=True)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    return out_path


# ---------------------------------------------------------------- verification
def _is_flat(mesh):
    """True when every corner normal equals its face normal (the split normals the FBX carries into Unreal)."""
    mesh.update()
    try:
        cn = np.array([c.vector[:] for c in mesh.corner_normals])
    except AttributeError:
        return not any(p.use_smooth for p in mesh.polygons)
    fn = np.empty(len(mesh.polygons) * 3)
    mesh.polygons.foreach_get("normal", fn)
    fn = np.repeat(fn.reshape(-1, 3), [len(p.vertices) for p in mesh.polygons], axis=0)
    return bool(np.all(np.einsum("ij,ij->i", cn, fn) > 0.9998))


def reimport_check(fbx_path):
    """Import an exported FBX into the current scene and report what Unreal will see (uv layers, colours, tris)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=fbx_path)
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    report = []
    for o in new:
        report.append({"name": o.name, "tris": tri_count(o), "uv_layers": [u.name for u in o.data.uv_layers],
                       "colors": [c.name for c in o.data.color_attributes],
                       "flat": _is_flat(o.data),
                       "size_cm": float(np.ptp(verts_cm(o), axis=0).max()),
                       "slots": [m.name if m else None for m in o.data.materials]})
        bpy.data.objects.remove(o)
    return report
