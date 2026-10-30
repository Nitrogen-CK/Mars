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


# ---------------------------------------------------------------- runtime-mesh contract (CkRuntimeMesh import)
# What the game's runtime slicer (CkFoundation CkRuntimeMesh, FCk_RuntimeMesh_ImportLimits / PreflightLOD /
# ValidateMesh) accepts from a static mesh's LOD0, mirrored here so a builder FAILS instead of shipping a mesh the game
# rejects at import:
#   * RAW render vertices (PositionVertexBuffer: after Unreal splits corners on normal / UV / colour) <= 2048; a
#     flat-shaded, per-facet-painted mesh has 3 per triangle, so ~680 tris is its practical ceiling;
#   * triangles <= 4096;
#   * after re-welding the split seams (SeamToleranceCm 1e-4): every edge shared by exactly two triangles walking it in
#     opposite directions (closed, no ambiguous seam), no bowtie vertex, ONE connected component, no self-intersection,
#     positive volume (outward winding), no degenerate triangle (area / edge floors stricter than the importer's
#     1e-8 cm2, so Unreal's own degenerate-triangle removal at build time can never open the shell);
#   * vertex colours present; the asset needs CPU access (food_spec "cpu_access" / the sidecar, set by mars_food_ue).
RUNTIME_MAX_RENDER_VERTS = 2048
RUNTIME_MAX_TRIS = 4096
RUNTIME_WELD_CM = 1e-4
RUNTIME_MIN_AREA_CM2 = 1e-5            # 1000x the importer's floor
RUNTIME_MIN_EDGE_CM = 1e-3             # 50x Unreal's THRESH_POINTS_ARE_SAME (2e-5 cm)


class RuntimeMeshError(RuntimeError):
    pass


def _uf_find(parent, a):
    root = a
    while parent[root] != root:
        root = parent[root]
    while parent[a] != root:
        parent[a], a = root, parent[a]
    return root


def render_vertex_count(mesh, positions_cm, tri_loops):
    """Unique (position, normal, every UV layer, colour bytes) triangle corners: what Unreal's static mesh build keeps
    as render vertices (it merges corners only when all of them match). Exact keys, so never an under-count."""
    loops = np.asarray(tri_loops, np.int64).ravel()
    lv = np.empty(len(mesh.loops), np.int64)
    mesh.loops.foreach_get("vertex_index", lv)
    cols = [np.round(positions_cm[lv[loops]] / RUNTIME_WELD_CM).astype(np.int64)]
    try:
        cn = np.array([c.vector[:] for c in mesh.corner_normals])
    except AttributeError:
        cn = np.zeros((len(mesh.loops), 3))
        mesh.loops.foreach_get("normal", cn.reshape(-1))
    cols.append(np.round(cn[loops] * 1e4).astype(np.int64))
    for uv in mesh.uv_layers:
        u = np.empty(len(mesh.loops) * 2)
        uv.data.foreach_get("uv", u)
        cols.append(np.round(u.reshape(-1, 2)[loops] * 1e6).astype(np.int64))
    attr = mesh.color_attributes.get(spec.COLOR_ATTR) or (mesh.color_attributes[0] if len(mesh.color_attributes) else None)
    if attr is not None:
        c = np.empty(len(attr.data) * 4, np.float32)
        attr.data.foreach_get("color", c)
        c = c.reshape(-1, 4)
        c = c[loops] if attr.domain == "CORNER" else c[lv[loops]]
        cols.append(np.round(np.clip(c, 0.0, 1.0) * 255.0).astype(np.int64))      # FColor bytes
    keys = np.concatenate(cols, axis=1)
    return int(len(np.unique(keys, axis=0)))


def topology_report(positions_cm, tris):
    """Closed / single-solid / bowtie / self-intersection / volume / degenerate checks over triangles (n, 3) of
    vertex ids, after welding positions within RUNTIME_WELD_CM (the importer's seam reconstruction)."""
    from mathutils.bvhtree import BVHTree
    positions_cm = np.asarray(positions_cm, float)
    keys = np.round(positions_cm / RUNTIME_WELD_CM).astype(np.int64)
    _, weld = np.unique(keys, axis=0, return_inverse=True)
    weld = np.asarray(weld).ravel()
    n = int(weld.max()) + 1 if len(weld) else 0
    wpos = np.zeros((n, 3))
    wpos[weld] = positions_cm
    t = weld[np.asarray(tris, np.int64)]
    rep = {"welded_verts": n}
    degenerate = (t[:, 0] == t[:, 1]) | (t[:, 1] == t[:, 2]) | (t[:, 0] == t[:, 2])
    a, b, c = wpos[t[:, 0]], wpos[t[:, 1]], wpos[t[:, 2]]
    area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    edge = np.minimum(np.minimum(np.linalg.norm(b - a, axis=1), np.linalg.norm(c - b, axis=1)),
                      np.linalg.norm(a - c, axis=1))
    rep["degenerate_tris"] = int((degenerate | (area < RUNTIME_MIN_AREA_CM2) | (edge < RUNTIME_MIN_EDGE_CM)).sum())
    rep["min_area_cm2"] = round(float(area.min()), 6) if len(area) else 0.0
    rep["min_edge_cm"] = round(float(edge.min()), 5) if len(edge) else 0.0
    # edges: undirected use count, and directed duplicates (two triangles walking an edge the same way = flipped)
    d = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
    _, ucount = np.unique(np.sort(d, axis=1), axis=0, return_counts=True)
    _, dcount = np.unique(d, axis=0, return_counts=True)
    rep["boundary_edges"] = int((ucount == 1).sum())
    rep["nonmanifold_edges"] = int((ucount > 2).sum())
    rep["flipped_edges"] = int((dcount > 1).sum())
    # bowtie: the link of every vertex (the opposite edges of its triangles) must be one connected cycle
    links = {}
    for tri in t.tolist():
        for k in range(3):
            links.setdefault(tri[k], []).append((tri[(k + 1) % 3], tri[(k + 2) % 3]))
    bowtie = 0
    for pairs in links.values():
        parent = {}
        for p, q in pairs:
            parent.setdefault(p, p)
            parent.setdefault(q, q)
            rp, rq = _uf_find(parent, p), _uf_find(parent, q)
            if rp != rq:
                parent[rp] = rq
        if len({_uf_find(parent, x) for x in list(parent)}) > 1:
            bowtie += 1
    rep["bowtie_verts"] = bowtie
    # connected components over the triangles
    parent = list(range(n))
    for tri in t.tolist():
        r0 = _uf_find(parent, tri[0])
        for v in tri[1:]:
            r = _uf_find(parent, v)
            if r != r0:
                parent[r] = r0
    rep["components"] = len({_uf_find(parent, int(v)) for v in np.unique(t)})
    rep["volume_cm3"] = round(float(np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6.0), 4)
    # self-intersections: overlapping triangle pairs that share no vertex
    bvh = BVHTree.FromPolygons(wpos.tolist(), t.tolist(), all_triangles=True)
    tset = [set(x) for x in t.tolist()]
    rep["self_intersections"] = sum(1 for i, j in bvh.overlap(bvh) if i < j and not (tset[i] & tset[j]))
    rep["closed"] = (rep["boundary_edges"] == 0 and rep["nonmanifold_edges"] == 0 and rep["flipped_edges"] == 0
                     and rep["bowtie_verts"] == 0)
    rep["single_solid"] = (rep["closed"] and rep["components"] == 1 and rep["self_intersections"] == 0
                           and rep["volume_cm3"] > 0.0)
    return rep


# ---------------------------------------------------------------- cook-look standard (cuttable meat, 2026-10-10)
# Stephen's ruling: a piece cut at the bench must sear in the pan like MeatCube_Mars_SM (one cube, Meat_Mars_M, six
# sear slots in CPD 0-5, one per local axis face). The six-face sear model only reads right on a piece whose surface
# IS six faces, so an ingredient flagged food_spec "cook_standard" (cuttable meat) must also pass, on its exported FBX:
#   1. box-likeness: >= COOK_BOX_MIN of the surface area has a face normal within COOK_AXIS_DEG of one of the six
#      local axes (the sear slots), so the sear lands on whole faces, not on a rounded blend between two slots;
#   2. six real faces: each of +X -X +Y -Y +Z -Z owns >= COOK_FACE_MIN of the area (within COOK_AXIS_DEG of it), so
#      every ledger slot is a face the piece can rest on;
#   3. vertex colours: A = cavity in 0..1, RGB albedo present (not all white); UV0 inside 0..1 and the
#      <Name>_Mask_Mars_T.png exported beside the FBX; morph UV1 / UV2 either absent or finite and <= the sidecar's
#      morph_max_cm (the morph rides with the piece; a broken one tears it);
#   4. the runtime-mesh contract above (closed single solid, <= 2048 render verts / <= 4096 tris, no degenerates).
# Axes are Unreal local (x, -y, z of Blender), the frame the CPD sear slots use.
COOK_AXIS_DEG = 25.0
COOK_BOX_MIN = 0.85
COOK_FACE_MIN = 0.05
COOK_AXES = ("+X", "-X", "+Y", "-Y", "+Z", "-Z")
COOK_WHITE = 0.98                      # every RGB channel at or above this on every corner = "all white"


def cook_look_report(positions_cm, tris):
    """Box-likeness of a closed triangle mesh (Blender-frame cm, outward winding) for the six-face sear model.
    Returns box_fraction (area within COOK_AXIS_DEG of any axis), face_split (that area per axis, Unreal local
    names), dominant_split (all area by nearest axis) and total_area_cm2."""
    p = np.asarray(positions_cm, float)
    t = np.asarray(tris, np.int64)
    a, b, c = p[t[:, 0]], p[t[:, 1]], p[t[:, 2]]
    cr = np.cross(b - a, c - a)
    area = 0.5 * np.linalg.norm(cr, axis=1)
    nrm = cr / np.maximum(2.0 * area, 1e-12)[:, None]
    nrm = nrm * UE_MIRROR            # Unreal local axes (the mirror of a normal is the normal of the mirrored face)
    total = float(area.sum()) or 1.0
    ax = np.argmax(np.abs(nrm), axis=1)
    neg = np.take_along_axis(nrm, ax[:, None], axis=1)[:, 0] < 0.0
    slot = ax * 2 + neg.astype(np.int64)                    # 0 +X, 1 -X, 2 +Y, 3 -Y, 4 +Z, 5 -Z
    within = np.abs(nrm).max(axis=1) >= math.cos(math.radians(COOK_AXIS_DEG))
    face = {k: round(float(area[within & (slot == i)].sum() / total), 4) for i, k in enumerate(COOK_AXES)}
    dom = {k: round(float(area[slot == i].sum() / total), 4) for i, k in enumerate(COOK_AXES)}
    return {"box_fraction": round(float(area[within].sum() / total), 4), "face_split": face, "dominant_split": dom,
            "total_area_cm2": round(total, 2), "axis_deg": COOK_AXIS_DEG}


def _cook_attr_report(mesh, tri_loops, fbx_path):
    """Vertex colour / UV0 / mask / morph facts for the cook-look standard, read from the re-imported FBX mesh."""
    loops = np.asarray(tri_loops, np.int64).ravel()
    rep = {}
    attr = mesh.color_attributes.get(spec.COLOR_ATTR) or (mesh.color_attributes[0] if len(mesh.color_attributes) else None)
    if attr is not None:
        c = np.empty(len(attr.data) * 4, np.float32)
        attr.data.foreach_get("color", c)
        c = c.reshape(-1, 4)
        if attr.domain != "CORNER":
            lv = np.empty(len(mesh.loops), np.int64)
            mesh.loops.foreach_get("vertex_index", lv)
            c = c[lv]
        c = c[loops]
        rep["alpha_min"], rep["alpha_max"] = round(float(c[:, 3].min()), 4), round(float(c[:, 3].max()), 4)
        rep["rgb_mean"] = [round(float(x), 4) for x in c[:, :3].mean(axis=0)]
        rep["rgb_all_white"] = bool(np.all(c[:, :3] >= COOK_WHITE))
        rep["rgb_finite"] = bool(np.all(np.isfinite(c)))
    uvs = {u.name: u for u in mesh.uv_layers}
    if len(mesh.uv_layers):
        u = np.empty(len(mesh.loops) * 2)
        mesh.uv_layers[0].data.foreach_get("uv", u)
        u = u.reshape(-1, 2)[loops]
        rep["uv0_min"] = [round(float(x), 5) for x in u.min(axis=0)]
        rep["uv0_max"] = [round(float(x), 5) for x in u.max(axis=0)]
    morph = [n for n in spec.MORPH_UV if n in uvs]
    rep["morph_layers"] = morph
    if morph:
        off = np.zeros((len(loops), 3))
        if spec.MORPH_UV[0] in uvs:
            u = np.empty(len(mesh.loops) * 2)
            uvs[spec.MORPH_UV[0]].data.foreach_get("uv", u)
            u = u.reshape(-1, 2)[loops]
            off[:, 0], off[:, 1] = u[:, 0], 1.0 - u[:, 1]
        if spec.MORPH_UV[1] in uvs:
            u = np.empty(len(mesh.loops) * 2)
            uvs[spec.MORPH_UV[1]].data.foreach_get("uv", u)
            off[:, 2] = u.reshape(-1, 2)[loops][:, 0]
        rep["morph_finite"] = bool(np.all(np.isfinite(off)))
        rep["morph_seen_cm"] = round(float(np.abs(off).max()), 4) if rep["morph_finite"] else None
    stem = os.path.splitext(os.path.basename(fbx_path))[0].replace("_Mars_SM", "")
    mask = os.path.join(os.path.dirname(fbx_path), "%s_Mask_Mars_T.png" % stem)
    rep["mask"] = mask if os.path.exists(mask) else None
    try:
        with open(os.path.splitext(fbx_path)[0] + ".json") as fh:
            rep["morph_max_cm"] = float(json.load(fh).get("morph_max_cm", 0.0))
    except (OSError, ValueError):
        rep["morph_max_cm"] = 0.0
    return rep


def cook_standard_of(name):
    """True for a hero mesh whose ingredient carries food_spec INGREDIENTS[...]['cook_standard'], or is cuttable meat
    (category meats with cpu_access: the standard applies whether or not the flag was remembered). An explicit
    cook_standard=False opts a meat out (Stephen 2026-10-29, the Fish: a rounded fish over a per-face sear)."""
    ing = spec.INGREDIENTS.get(name.replace("_Mars_SM", ""))
    if ing and "cook_standard" in ing:
        return bool(ing["cook_standard"])
    return bool(ing and ing.get("category") == "meats" and ing.get("cpu_access"))


def cook_standard_problems(rep):
    """The cook-look rules 1-3 a runtime_mesh_report misses, as strings (rule 4 is the runtime contract itself)."""
    look, attr = rep["cook_look"], rep["cook_attrs"]
    out = []
    if look["box_fraction"] < COOK_BOX_MIN:
        out.append("box_fraction %.3f < %.2f" % (look["box_fraction"], COOK_BOX_MIN))
    thin = [k for k in COOK_AXES if look["face_split"][k] < COOK_FACE_MIN]
    if thin:
        out.append("faces under %d%%: %s" % (round(COOK_FACE_MIN * 100), ", ".join(
            "%s %.3f" % (k, look["face_split"][k]) for k in thin)))
    if "alpha_min" not in attr:
        out.append("no vertex colours")
    else:
        if not attr["rgb_finite"] or attr["alpha_min"] < 0.0 or attr["alpha_max"] > 1.0:
            out.append("vertex colour alpha outside 0..1 (%.3f..%.3f)" % (attr["alpha_min"], attr["alpha_max"]))
        if attr["rgb_all_white"]:
            out.append("vertex colour RGB all white (no albedo painted)")
    if "uv0_min" not in attr:
        out.append("no UV0")
    elif min(attr["uv0_min"]) < -1e-4 or max(attr["uv0_max"]) > 1.0 + 1e-4:
        out.append("UV0 outside 0..1 (%s..%s)" % (attr["uv0_min"], attr["uv0_max"]))
    if not attr["mask"]:
        out.append("mask PNG missing")
    if attr["morph_layers"]:
        if not attr.get("morph_finite"):
            out.append("morph UV1/UV2 not finite")
        elif attr["morph_seen_cm"] > attr["morph_max_cm"] + 1e-3:
            out.append("morph %.3f cm > morph_max_cm %.3f" % (attr["morph_seen_cm"], attr["morph_max_cm"]))
    return out


def runtime_mesh_report(fbx_path, cook_standard=None):
    """Re-import an exported FBX (what Unreal reads) and measure it against the runtime-mesh contract. Returns a dict:
    tris, render_verts, the topology_report fields, the cook-look numbers ('cook_look', 'cook_attrs',
    'cook_standard'), 'ok' and 'problems'. Prints one RUNTIME_MESH and one COOK_STANDARD line. cook_standard None =
    the ingredient's food_spec flag (cook_standard_of): when on, a missed cook-look rule makes the mesh not ok; when
    off the numbers are information only."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=fbx_path, colors_type="LINEAR")
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    try:
        if len(meshes) != 1:
            raise RuntimeMeshError("%s: %d mesh objects in the FBX (want 1)" % (fbx_path, len(meshes)))
        o = meshes[0]
        mesh = o.data
        mesh.update()
        m = np.array(o.matrix_world)
        n = len(mesh.vertices)
        co = np.empty(n * 3)
        mesh.vertices.foreach_get("co", co)
        pos_cm = (np.c_[co.reshape(n, 3), np.ones(n)] @ m.T)[:, :3] * 100.0
        mesh.calc_loop_triangles()
        lt = mesh.loop_triangles
        tris = np.empty(len(lt) * 3, np.int64)
        lt.foreach_get("vertices", tris)
        tl = np.empty(len(lt) * 3, np.int64)
        lt.foreach_get("loops", tl)
        tris, tl = tris.reshape(-1, 3), tl.reshape(-1, 3)
        if np.linalg.det(m[:3, :3]) < 0:            # a mirroring import transform flips the winding
            tris = tris[:, ::-1]
        rep = {"name": os.path.splitext(os.path.basename(fbx_path))[0], "tris": int(len(tris)),
               "render_verts": render_vertex_count(mesh, pos_cm, tl),
               "uv_layers": [u.name for u in mesh.uv_layers],
               "color_attr": len(mesh.color_attributes) > 0}
        rep.update(topology_report(pos_cm, tris))
        rep["cook_look"] = cook_look_report(pos_cm, tris)
        rep["cook_attrs"] = _cook_attr_report(mesh, tl, fbx_path)
    finally:
        for o in new:
            me = o.data if o.type == "MESH" else None
            bpy.data.objects.remove(o, do_unlink=True)
            if me is not None and me.users == 0:
                bpy.data.meshes.remove(me)
    problems = []
    if rep["render_verts"] > RUNTIME_MAX_RENDER_VERTS:
        problems.append("render verts %d > %d" % (rep["render_verts"], RUNTIME_MAX_RENDER_VERTS))
    if rep["tris"] > RUNTIME_MAX_TRIS:
        problems.append("tris %d > %d" % (rep["tris"], RUNTIME_MAX_TRIS))
    for k in ("boundary_edges", "nonmanifold_edges", "flipped_edges", "bowtie_verts", "self_intersections",
              "degenerate_tris"):
        if rep[k]:
            problems.append("%s %d" % (k, rep[k]))
    if rep["components"] != 1:
        problems.append("components %d" % rep["components"])
    if rep["volume_cm3"] <= 0.0:
        problems.append("volume %.3f cm3" % rep["volume_cm3"])
    if not rep["color_attr"]:
        problems.append("no vertex colours")
    runtime_ok = not problems
    if cook_standard is None:
        cook_standard = cook_standard_of(rep["name"])
    cook_problems = cook_standard_problems(rep)
    rep["cook_standard"] = {"enforced": bool(cook_standard), "ok": runtime_ok and not cook_problems,
                            "problems": cook_problems, "box_min": COOK_BOX_MIN, "face_min": COOK_FACE_MIN,
                            "axis_deg": COOK_AXIS_DEG}
    if cook_standard:
        problems += ["cook standard: " + p for p in cook_problems]
    rep["ok"] = not problems
    rep["problems"] = problems
    look, attr = rep["cook_look"], rep["cook_attrs"]
    print("COOK_STANDARD %s  %s  box %.3f (>= %.2f within %d deg)  faces %s (each >= %.2f)  dominant %s  "
          "alpha %s..%s  rgb_mean %s  uv0 %s..%s  mask %s  morph %s  runtime %s  -> %s" % (
              rep["name"], "enforced" if cook_standard else "info", look["box_fraction"], COOK_BOX_MIN,
              round(COOK_AXIS_DEG), " ".join("%s %.3f" % (k, look["face_split"][k]) for k in COOK_AXES),
              COOK_FACE_MIN, " ".join("%s %.3f" % (k, look["dominant_split"][k]) for k in COOK_AXES),
              attr.get("alpha_min"), attr.get("alpha_max"), attr.get("rgb_mean"), attr.get("uv0_min"),
              attr.get("uv0_max"), "yes" if attr["mask"] else "MISSING",
              ("%s %.3f / %.3f cm" % (attr["morph_layers"], attr.get("morph_seen_cm") or 0.0, attr["morph_max_cm"]))
              if attr["morph_layers"] else "none", "ok" if runtime_ok else "FAIL",
              "PASS" if rep["cook_standard"]["ok"] else "FAIL (%s)" % "; ".join(
                  cook_problems + ([] if runtime_ok else ["runtime-mesh contract"]))))
    print("RUNTIME_MESH %s  tris %d  render_verts %d / %d  closed %s  single_solid %s  components %d  self_isect %d  "
          "volume %.1f cm3  min_edge %.4f cm  -> %s" % (
              rep["name"], rep["tris"], rep["render_verts"], RUNTIME_MAX_RENDER_VERTS, rep["closed"],
              rep["single_solid"], rep["components"], rep["self_intersections"], rep["volume_cm3"], rep["min_edge_cm"],
              "OK" if rep["ok"] else "FAIL (%s)" % "; ".join(problems)))
    return rep


def check_runtime_mesh(fbx_path, cook_standard=None):
    """runtime_mesh_report that raises RuntimeMeshError when the export breaks the contract or, for a cook_standard
    ingredient (food_spec flag, or cook_standard=True), the cook-look standard (a build FAILS on it)."""
    rep = runtime_mesh_report(fbx_path, cook_standard)
    if not rep["ok"]:
        raise RuntimeMeshError("%s breaks the runtime-mesh contract: %s" % (rep["name"], "; ".join(rep["problems"])))
    return rep
