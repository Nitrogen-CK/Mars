"""Fryer category of the Mars food library (Blender 5.2, headless): the batter-shell generator and the oil VAT.

    blender -b --factory-startup --python build_food_fryer.py -- --oil --batter --save --sheets
    blender -b --factory-startup --python build_food_fryer.py -- --batter --batter-input <any.fbx> --sheets

--oil     OilSurface_Mars_SM + OilBubbles_Mars_SM (rest meshes, FBX) and their four VAT EXRs + OilVAT_Mars.json, with
          a numeric verification (decode error, loop seam, NaN, row order straight from the EXR file).
--batter  <Name>_Battered_Mars_SM for every fryable ingredient whose <Name>_Mars_SM.fbx exists in spec.EXPORT_DIR
          (missing ones are skipped with a message), plus --batter-input <fbx> for any other mesh.
--save    writes spec.BLEND_DIR/Food_Fryer.blend: the MarsBatterShell node group, the rest oil meshes, the shell-only
          and battered meshes of this run, and a live BatterDemo object (GN + Decimate modifiers) to tweak.
--sheets  workbench contact sheets in spec.REVIEW_DIR (OilVAT_sheet.png, <Name>_Battered_sheet.png).
--bubble-mesh  OilBubble_Mars_SM, one bubble dome for Niagara mesh particles (also exported by --oil; no VAT bake).

Batter pipeline (food_spec "batter"): the geometry-node group MarsBatterShell (Mesh to SDF Grid at Voxel -> SDF Grid
Offset by Thickness -> Grid to Mesh -> Set Position with lump / crumb noise along the normal and a drip term under
overhangs -> flat shading) is evaluated headless on the ingredient, then a Decimate (collapse) modifier brings the
fine voxel shell down to the tri budget, which gives the irregular hand-cut facets of the style ruling (a coarse voxel
mesh reads as a regular quad grid). The shell is merged with the ingredient's own faces (slots and vertex colours
kept) on slot "Batter".

Oil VAT (food_spec "oil VAT"): deterministic numpy functions of the loop phase t in [0, 1) built only from integer
cycle counts, so frame OIL_FRAMES == frame 0 exactly. Frame f sits in the TOP-DOWN image row f (Blender's bottom-up
pixel row OIL_FRAMES - 1 - f), so the spec decode v = (f + 0.5) / frames reads it with no flip in Unreal.
Version 2 (OilVAT_Mars.json "version"): bubbles no longer collapse; over the last POP_START..1 of each event they keep
the dome, widen radially and sink the apex while OilBubbles_VATPos alpha carries pop (0 intact, 0..1 across the
window, 1 while hidden); the material masks BubbleLocal.x (UV2, rest height in the bubble) > 1 - pop, so the dome
opens from the apex and leaves a widening ring. Nothing colour-specific is baked (the stew reuses the meshes).
Prints FOOD_FRYER_OK.
"""
import json
import math
import os
import re
import struct
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import food_common as fc  # noqa: E402

spec = fc.spec

# ================================================================ batter settings
BATTER_GROUP = "MarsBatterShell"
BATTER_SLOT = "Batter"
BATTER_RGB = fc.srgb(236, 214, 170)              # pale raw batter; the material browns it with Fry (CPD Finish.z)
BATTER_DEFAULTS = dict(Thickness=1.0, Lumpiness=0.4, Drip=0.8, Voxel=0.4, Seed=0)
BATTER_TRI_TARGET = 1.42                         # shell tris aimed at this x the ingredient's (spec cap 1.5x)
BATTER_TRI_CAP = 1.5
BATTER_MIN_TARGET_TRIS = 600                     # floor for arbitrary --batter-input meshes far below the roster's 600
# Per ingredient: GN input overrides and slots left out of the shell (a drumstick is held by its bare bone).
BATTER_PER_INGREDIENT = {
    "Drumstick": dict(Seed=2, exclude_slots=("Bone",)),
    "Tentacle": dict(Seed=3),
    "Puffer": dict(Seed=1, expose_eyes=True),        # reference 2: the battered puffers keep their bead eyes
    "SpikedBerry": dict(Seed=4),                     # eyes are iris + pupil and the mouth is near-black: no beads
}

# ================================================================ oil settings
OIL_RGB = fc.srgb(230, 160, 40)
BUBBLE_RGB = fc.srgb(250, 222, 140)
OIL_SEED = 20261006
SHEET_FRAMES = 6
OIL_VAT_VERSION = 2              # v2: bubble pop in OilBubbles_VATPos alpha + BubbleLocal UV2
# Bubble event phases, as fractions u of each bubble's active event (its schedule n / dur / phase is unchanged):
# rise [0, 0.55) -> ride the surface and swell [0.55, POP_START) -> pop window [POP_START, 1) -> hidden rest (pop 1)
POP_START = 0.85                 # pop window = the last 15 % of every event
POP_RING = 0.35                  # radial scale about the bubble's vertical axis: 1 + POP_RING * pop
POP_SINK = 0.3                   # apex drops POP_SINK * radius * pop (vertical squash about the bubble's lowest point)
RIPPLE_AT = 0.9                  # surface pop-ripple start within each event (as in v1)
SPREAD_POPS = True               # re-spread bubble phases so pop windows do not bunch (False = v1 phases: the surface
                                 # bake is then byte-identical to v1, but 9..12 bubbles pop at once twice a loop)

T0 = time.time()


def log(msg):
    print("[fryer %6.1fs] %s" % (time.time() - T0, msg))
    sys.stdout.flush()


# ================================================================ small mesh helpers
def mesh_arrays(mesh):
    """(verts cm (n,3), faces list, face material index (f,), loop colours in face order (l,4) or None)."""
    n = len(mesh.vertices)
    co = np.empty(n * 3)
    mesh.vertices.foreach_get("co", co)
    starts = np.empty(len(mesh.polygons), np.int64)
    totals = np.empty(len(mesh.polygons), np.int64)
    mesh.polygons.foreach_get("loop_start", starts)
    mesh.polygons.foreach_get("loop_total", totals)
    lv = np.empty(len(mesh.loops), np.int64)
    mesh.loops.foreach_get("vertex_index", lv)
    order = np.concatenate([np.arange(s, s + t) for s, t in zip(starts, totals)]) if len(starts) else np.zeros(0, int)
    faces = np.split(lv[order], np.cumsum(totals)[:-1]) if len(starts) else []
    mat = np.empty(len(mesh.polygons), np.int64)
    mesh.polygons.foreach_get("material_index", mat)
    cols = None
    attr = mesh.color_attributes.get(spec.COLOR_ATTR) or (mesh.color_attributes[0] if len(mesh.color_attributes) else None)
    if attr is not None:
        if attr.domain == "CORNER":
            c = np.empty(len(mesh.loops) * 4, np.float32)
            attr.data.foreach_get("color", c)
            cols = c.reshape(-1, 4)[order]
        elif attr.domain == "POINT":
            c = np.empty(n * 4, np.float32)
            attr.data.foreach_get("color", c)
            cols = c.reshape(-1, 4)[lv[order]]
    return co.reshape(n, 3) * 100.0, [list(map(int, f)) for f in faces], mat, cols


def make_object(name, verts_cm, faces, slots, face_slots, loop_colors=None, smooth=False):
    """fc.new_object plus loop colours in face order; refuses silently-changed topology (validate dropping faces)."""
    obj = fc.new_object(name, verts_cm, faces, slots=slots, face_slots=face_slots)
    if len(obj.data.polygons) != len(faces) or len(obj.data.vertices) != len(verts_cm):
        raise RuntimeError("%s: mesh.validate changed topology (%d/%d faces)" % (name, len(obj.data.polygons), len(faces)))
    if loop_colors is not None:
        attr = obj.data.color_attributes.new(spec.COLOR_ATTR, "FLOAT_COLOR", "CORNER")
        attr.data.foreach_set("color", np.asarray(loop_colors, np.float32).ravel())
        idx = list(obj.data.color_attributes).index(attr)
        obj.data.color_attributes.active_color_index = idx
        obj.data.color_attributes.render_color_index = idx
    if smooth:
        obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    obj.data.update()
    return obj


def loop_colors_of(obj):
    return mesh_arrays(obj.data)[3]


def remove_object(obj):
    mesh = obj.data if obj.type == "MESH" else None
    bpy.data.objects.remove(obj, do_unlink=True)
    if mesh is not None and mesh.users == 0:
        bpy.data.meshes.remove(mesh)


def boundary_and_nonmanifold(mesh):
    bm = bmesh.new()
    bm.from_mesh(mesh)
    boundary = sum(1 for e in bm.edges if e.is_boundary)
    nonman = sum(1 for e in bm.edges if not e.is_manifold)
    bm.free()
    return boundary, nonman


def components(faces, n_verts):
    """Connected components over shared vertices -> component id per vertex."""
    parent = np.arange(n_verts)

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for f in faces:
        r0 = find(f[0])
        for v in f[1:]:
            r = find(v)
            if r != r0:
                parent[r] = r0
    return np.array([find(i) for i in range(n_verts)])


def inside_parity(bvh, points, dirs=((0.0123, 0.0311, 1.0), (0.577, -0.61, -0.54), (-0.83, 0.41, 0.37))):
    """Majority vote of ray-crossing parity over three directions: True where a point is inside the closed mesh."""
    dirs = [Vector(d).normalized() for d in dirs]
    out = np.zeros(len(points), bool)
    for i, p in enumerate(points):
        votes = 0
        for d in dirs:
            o = Vector(p)
            hits = 0
            for _ in range(256):
                loc, _n, _idx, _dist = bvh.ray_cast(o, d)
                if loc is None:
                    break
                hits += 1
                o = loc + d * 1e-4
            votes += hits % 2
        out[i] = votes >= 2
    return out


# ================================================================ batter: the geometry-node group
def build_batter_group():
    """MarsBatterShell: Geometry + Thickness / Lumpiness / Drip / Voxel (cm) + Seed -> closed lumpy batter shell."""
    old = bpy.data.node_groups.get(BATTER_GROUP)
    if old is not None:
        bpy.data.node_groups.remove(old)
    ng = bpy.data.node_groups.new(BATTER_GROUP, "GeometryNodeTree")
    ng.use_fake_user = True
    ng.description = ("Mars fryer batter shell (build_food_fryer.py): SDF offset of the input by Thickness, meshed at "
                      "Voxel, lump / crumb noise along the normal and drips under overhangs, flat shaded. All lengths cm.")
    it = ng.interface
    it.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    docs = {
        "Thickness": ("Shell offset from the ingredient surface (cm); the lumps vary it about +-35%", 0.1, 5.0),
        "Lumpiness": ("Lump and crumb-nodule displacement amplitude along the normal (cm)", 0.0, 2.0),
        "Drip": ("Longest drip hanging under overhangs (cm), scaled by max(0, -normal.z)^2", 0.0, 4.0),
        "Voxel": ("SDF and meshing voxel size (cm); the builder decimates the result to the tri budget", 0.1, 3.0),
    }
    for name in ("Thickness", "Lumpiness", "Drip", "Voxel"):
        s = it.new_socket(name, in_out="INPUT", socket_type="NodeSocketFloat")
        s.default_value = BATTER_DEFAULTS[name]
        s.description, s.min_value, s.max_value = docs[name]
    s = it.new_socket("Seed", in_out="INPUT", socket_type="NodeSocketInt")
    s.default_value = 0
    s.description = "Noise seed (4D noise W offset), one per ingredient"
    it.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")

    N, L = ng.nodes, ng.links
    layout = {"i": 0}

    def node(kind, **props):
        n = N.new(kind)
        k = layout["i"]
        layout["i"] += 1
        n.location = (220 * (k % 9), -200 * (k // 9))
        for key, val in props.items():
            setattr(n, key, val)
        return n

    def link(src, dst):
        if isinstance(src, (int, float)):
            dst.default_value = src
        elif isinstance(src, (tuple, list)):
            dst.default_value = src
        else:
            L.new(src, dst)

    def fmath(op, a, b=None, c=None):
        m = node("ShaderNodeMath", operation=op)
        for i, x in enumerate((a, b, c)):
            if x is not None:
                link(x, m.inputs[i])
        return m.outputs[0]

    def vmath(op, a, b=None, scale=None):
        m = node("ShaderNodeVectorMath", operation=op)
        for i, x in enumerate((a, b)):
            if x is not None:
                link(x, m.inputs[i])
        if scale is not None:
            link(scale, m.inputs["Scale"])
        return m.outputs[0]

    gi = node("NodeGroupInput")
    go = node("NodeGroupOutput")
    voxel_m = fmath("MULTIPLY", gi.outputs["Voxel"], 0.01)
    thick_m = fmath("MULTIPLY", gi.outputs["Thickness"], 0.01)
    band = fmath("ADD", fmath("CEIL", fmath("DIVIDE", gi.outputs["Thickness"], gi.outputs["Voxel"])), 3.0)
    sdf = node("GeometryNodeMeshToSDFGrid")
    link(gi.outputs["Geometry"], sdf.inputs["Mesh"])
    link(voxel_m, sdf.inputs["Voxel Size"])
    link(band, sdf.inputs["Band Width"])
    off = node("GeometryNodeSDFGridOffset")
    link(sdf.outputs[0], off.inputs["Grid"])
    link(thick_m, off.inputs["Distance"])
    g2m = node("GeometryNodeGridToMesh")
    link(off.outputs[0], g2m.inputs["Grid"])
    g2m.inputs["Threshold"].default_value = 0.0
    g2m.inputs["Adaptivity"].default_value = 0.0

    pos = node("GeometryNodeInputPosition").outputs[0]
    nrm = node("GeometryNodeInputNormal").outputs["Normal"]
    pcm = vmath("SCALE", pos, scale=100.0)
    seed_w = fmath("MULTIPLY", gi.outputs["Seed"], 7.31)

    def noise(vec, scale, w_add, detail):
        n = node("ShaderNodeTexNoise", noise_dimensions="4D")
        link(vec, n.inputs["Vector"])
        link(fmath("ADD", seed_w, w_add), n.inputs["W"])
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = 0.5
        return n.outputs["Factor"]

    # lumps: ~3.5 cm blobs, -1..1 (noise p5..p95 0.35..0.65 at detail 1 -> gain 6.5)
    lump = fmath("MULTIPLY_ADD", noise(pcm, 0.28, 0.0, 1.0), 6.5, -3.25)
    lump = fmath("MINIMUM", fmath("MAXIMUM", lump, -1.0), 1.0)
    # crumb nodules: ~1.6 cm bumps on the top third of a detail-0 noise, 0..1
    crumb = fmath("MINIMUM", fmath("MAXIMUM", fmath("MULTIPLY_ADD", noise(pcm, 0.62, 19.0, 0.0), 7.0, -3.85), 0.0), 1.0)
    disp = fmath("MULTIPLY", fmath("ADD", fmath("MULTIPLY_ADD", lump, 0.7, fmath("MULTIPLY", crumb, 0.5)), -0.1),
                 gi.outputs["Lumpiness"])
    # drips: smooth ~3 cm patches on the undersides, pulled straight down and bulged a little
    sep = node("ShaderNodeSeparateXYZ")
    link(nrm, sep.inputs[0])
    over = fmath("POWER", fmath("MAXIMUM", fmath("MULTIPLY", sep.outputs["Z"], -1.0), 0.0), 2.0)
    mask = node("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
    link(noise(pcm, 0.3, 41.0, 0.0), mask.inputs["Value"])
    mask.inputs["From Min"].default_value = 0.5
    mask.inputs["From Max"].default_value = 0.68
    drip = fmath("MULTIPLY", fmath("MULTIPLY", over, mask.outputs["Result"]), gi.outputs["Drip"])
    disp = fmath("MULTIPLY_ADD", drip, 0.3, disp)
    offset = vmath("ADD", vmath("SCALE", nrm, scale=fmath("MULTIPLY", disp, 0.01)),
                   _combine(node, link, z=fmath("MULTIPLY", drip, -0.01)))
    sp = node("GeometryNodeSetPosition")
    link(g2m.outputs[0], sp.inputs["Geometry"])
    link(offset, sp.inputs["Offset"])
    flat = node("GeometryNodeSetShadeSmooth")
    flat.inputs["Shade Smooth"].default_value = False
    link(sp.outputs[0], flat.inputs["Mesh"])
    link(flat.outputs[0], go.inputs[0])
    return ng


def _combine(node, link, z):
    c = node("ShaderNodeCombineXYZ")
    link(z, c.inputs["Z"])
    return c.outputs[0]


def set_group_inputs(mod, ng, values):
    """Blender 5.x: modifier inputs live at mod.properties.inputs.<identifier>.value."""
    for item in ng.interface.items_tree:
        if item.item_type == "SOCKET" and item.in_out == "INPUT" and item.name in values:
            getattr(mod.properties.inputs, item.identifier).value = values[item.name]


def add_batter_modifiers(obj, ng, values, decimate_ratio=None):
    mod = obj.modifiers.new("MarsBatterShell", "NODES")
    mod.node_group = ng
    set_group_inputs(mod, ng, values)
    if decimate_ratio is not None:
        dec = obj.modifiers.new("BatterFacets", "DECIMATE")
        dec.decimate_type = "COLLAPSE"
        dec.ratio = float(decimate_ratio)
        dec.use_collapse_triangulate = True
    return mod


def evaluate_shell(src_mesh, ng, values, target_tris):
    """GN shell at the fine voxel, then Decimate to target_tris. Returns (mesh, fine_tris, ratio)."""
    tmp = bpy.data.objects.new("_BatterEval", src_mesh)
    bpy.context.scene.collection.objects.link(tmp)
    try:
        add_batter_modifiers(tmp, ng, values)
        dg = bpy.context.evaluated_depsgraph_get()
        dg.update()
        fine = tmp.evaluated_get(dg).data
        fine_tris = sum(len(p.vertices) - 2 for p in fine.polygons)
        if fine_tris == 0:
            raise RuntimeError("MarsBatterShell produced an empty mesh")
        ratio = min(1.0, target_tris / fine_tris)
        dec = tmp.modifiers.new("BatterFacets", "DECIMATE")
        dec.decimate_type = "COLLAPSE"
        dec.ratio = ratio
        dec.use_collapse_triangulate = True
        dg.update()
        me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg), preserve_all_data_layers=False, depsgraph=dg)
    finally:
        bpy.data.objects.remove(tmp)
    return me, fine_tris, ratio


# ================================================================ batter: per ingredient
def import_fbx_mesh(path):
    """Import an FBX, return (verts cm, faces, slot name per face, loop colours, slots) with transforms applied."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, colors_type="LINEAR")
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("%s: no mesh object" % path)
    verts, faces, slot_names, cols, order = [], [], [], [], []
    base = 0
    for o in meshes:
        v, f, mat, c = mesh_arrays(o.data)
        m = np.array(o.matrix_world)
        v = (np.c_[v, np.ones(len(v))] @ m.T)[:, :3]
        names = [re.sub(r"\.\d{3}$", "", m_.name) if m_ else "Flesh" for m_ in o.data.materials] or ["Flesh"]
        order.extend(names)
        verts.append(v)
        faces.extend([[base + i for i in face] for face in f])
        slot_names.extend(names[min(int(i), len(names) - 1)] for i in mat)
        if c is None:
            c = np.tile(np.r_[fc.srgb(200, 150, 110), 1.0], (sum(len(x) for x in f), 1))
        cols.append(c)
        base += len(v)
    for o in new:
        remove_object(o)
    used = set(slot_names)
    slots = []
    for s in order:                       # the source material order, unused slots dropped
        if s in used and s not in slots:
            slots.append(s)
    return np.concatenate(verts), faces, slot_names, np.concatenate(cols), slots


def ingredient_object(name, path):
    v, f, slot_names, cols, slots = import_fbx_mesh(path)
    bad = [s for s in slots if s not in spec.SLOTS_COOKING + spec.SLOTS_STATIC]
    if bad:
        log("%s: unknown slots %s renamed to Flesh" % (name, bad))
        slot_names = [s if s not in bad else "Flesh" for s in slot_names]
        slots = [s for s in slots if s not in bad] or ["Flesh"]
        if "Flesh" not in slots:
            slots.append("Flesh")
    face_slots = [slots.index(s) for s in slot_names]
    obj = make_object(name, v, f, slots, face_slots, loop_colors=cols)
    fc.triangulate_object(obj)        # bmesh keeps the corner colours; FBX export would triangulate anyway
    return obj


def detect_eyes(ing, max_luma=0.01, max_extent_cm=3.0):
    """Eyes = small clusters of near-black faces (the produce builder paints bead eyes srgb(14, 10, 9), luma ~0.003;
    the darkest other paint, the pout interior, is ~0.02). Works for eyes modelled into the body or as separate beads.
    -> [dict(centre, normal, radius, rgba, slot)]"""
    v, f, mat, cols = mesh_arrays(ing.data)
    if cols is None:
        return []
    counts = np.array([len(face) for face in f])
    starts = np.r_[0, np.cumsum(counts)[:-1]]
    face_rgb = np.array([cols[s:s + c, :3].mean(0) for s, c in zip(starts, counts)])
    luma = face_rgb @ np.array([0.2126, 0.7152, 0.0722])
    dark = np.where(luma < max_luma)[0]
    if len(dark) == 0:
        return []
    comp = components([f[i] for i in dark], len(v))
    clusters = {}
    for i in dark:
        clusters.setdefault(comp[f[i][0]], []).append(i)
    centre_all = (v.min(0) + v.max(0)) * 0.5
    eyes = []
    for faces in clusters.values():
        idx = np.unique(np.concatenate([f[i] for i in faces]))
        ext = np.ptp(v[idx], axis=0)
        if np.linalg.norm(ext) > max_extent_cm or len(faces) < 3:
            continue
        nsum, area = np.zeros(3), 0.0
        for i in faces:
            p = v[f[i]]
            cr = np.cross(p[1] - p[0], p[2] - p[0])
            nsum += cr
            area += np.linalg.norm(cr)
        c = v[idx].mean(0)
        if np.linalg.norm(nsum) > 0.3 * area:          # an open dome painted on the body: its own normal
            n = nsum / np.linalg.norm(nsum)
        else:                                          # a closed bead: outward from the ingredient centre
            n = (c - centre_all) / max(np.linalg.norm(c - centre_all), 1e-9)
        slot = int(np.bincount(mat[faces]).argmax())
        eyes.append(dict(centre=c, normal=n, radius=0.42 * float(ext.max()),
                         rgba=np.r_[face_rgb[faces].mean(0), 1.0], slot=slot))
    return eyes


def eye_beads(eyes, shell_bvh):
    """A bead per eye, half-proud of the batter along the eye's normal. -> (verts cm, faces, slot ids, rgba rows)."""
    unit_v, unit_f = unit_sphere()
    verts, faces, slots, rgba = [], [], [], []
    for e in eyes:
        hit = shell_bvh.ray_cast(Vector(e["centre"]), Vector(e["normal"]))
        if hit[0] is None:
            continue
        centre = e["centre"] + e["normal"] * (hit[3] + 0.05 * e["radius"])
        base = sum(len(x) for x in verts)
        verts.append(centre + unit_v * e["radius"])
        faces.extend((unit_f + base).tolist())
        slots.extend([e["slot"]] * len(unit_f))
        rgba.append(np.tile(e["rgba"], (len(unit_f) * 3, 1)))
    if not verts:
        return np.zeros((0, 3)), [], [], np.zeros((0, 4))
    return np.concatenate(verts), faces, slots, np.concatenate(rgba)


def shell_source_mesh(ing, exclude_slots):
    """Mesh of the ingredient faces that the batter wraps (all faces minus exclude_slots)."""
    names = [m.name for m in ing.data.materials]
    v, f, mat, _ = mesh_arrays(ing.data)
    keep = [face for face, m in zip(f, mat) if names[m] not in exclude_slots]
    if not keep:
        raise RuntimeError("%s: every face excluded from the batter" % ing.name)
    me = bpy.data.meshes.new("_BatterSource")
    me.from_pydata((v * 0.01).tolist(), [], keep)
    me.update()
    return me, keep, v


def drop_inner_components(verts_cm, faces):
    """Remove shell components that sit entirely inside another one (inner walls from open input meshes)."""
    comp = components(faces, len(verts_cm))
    ids = np.unique(comp)
    if len(ids) == 1:
        return verts_cm, faces, 0
    face_comp = np.array([comp[f[0]] for f in faces])
    keep_ids = []
    for cid in ids:
        others = [face for face, c in zip(faces, face_comp) if c != cid]
        bvh = BVHTree.FromPolygons(verts_cm.tolist(), others)
        probe = verts_cm[np.where(comp == cid)[0][:5]]
        if not inside_parity(bvh, probe).all():
            keep_ids.append(cid)
    keep_faces = [face for face, c in zip(faces, face_comp) if c in keep_ids]
    used = np.unique(np.concatenate([np.asarray(f) for f in keep_faces]))
    remap = -np.ones(len(verts_cm), np.int64)
    remap[used] = np.arange(len(used))
    return verts_cm[used], [[int(remap[i]) for i in f] for f in keep_faces], len(ids) - len(keep_ids)


def batter_one(name, path, ng, sheets):
    """Build <name>_Battered_Mars_SM from the ingredient FBX at path. Returns a stats dict."""
    params = dict(BATTER_DEFAULTS)
    per = BATTER_PER_INGREDIENT.get(name, {})
    params.update({k: v for k, v in per.items() if k in BATTER_DEFAULTS})
    exclude = tuple(per.get("exclude_slots", ()))
    ing = ingredient_object("%s_Ingredient" % name, path)
    ing_tris = fc.tri_count(ing)
    target = int(max(BATTER_MIN_TARGET_TRIS, ing_tris * BATTER_TRI_TARGET))
    cap = int(max(BATTER_MIN_TARGET_TRIS * BATTER_TRI_CAP / BATTER_TRI_TARGET, ing_tris * BATTER_TRI_CAP))
    eyes = detect_eyes(ing) if per.get("expose_eyes") else []
    src_mesh, src_faces, ing_v = shell_source_mesh(ing, exclude)

    shell_me, fine_tris, ratio = evaluate_shell(src_mesh, ng, params, target)
    sv, sf, _, _ = mesh_arrays(shell_me)
    bpy.data.meshes.remove(shell_me)
    sv, sf, dropped = drop_inner_components(sv, sf)
    shell = make_object("%s_BatterShell" % name, sv, sf, (BATTER_SLOT,), [0] * len(sf))
    fc.triangulate_object(shell)                       # decimate already triangulates; this guards ratio == 1
    sv, sf, _, _ = mesh_arrays(shell.data)
    shell_tris = fc.tri_count(shell)
    fc.paint(shell, np.tile(BATTER_RGB, (len(sf), 1)), variation=0.05, seed=params["Seed"] + 11, cavity_darken=0.4)

    # ---- verification of the shell against the wrapped ingredient faces
    boundary, nonman = boundary_and_nonmanifold(shell.data)
    shell_bvh = BVHTree.FromPolygons(sv.tolist(), sf)
    src_bvh = BVHTree.FromPolygons(ing_v.tolist(), src_faces)
    thick = np.array([src_bvh.find_nearest(p)[3] for p in sv])
    wrapped = np.unique(np.concatenate([np.asarray(f) for f in src_faces]))
    inside = inside_parity(shell_bvh, ing_v[wrapped])
    clearance = np.array([shell_bvh.find_nearest(p)[3] for p in ing_v[wrapped]])
    outside_all = int((~inside_parity(shell_bvh, ing_v)).sum()) if exclude else int((~inside).sum())
    ev, ef, eslot, ecol = eye_beads(eyes, shell_bvh) if eyes else (np.zeros((0, 3)), [], [], np.zeros((0, 4)))

    # ---- merge: ingredient faces (own slots, colours) + eye beads + shell faces on "Batter"
    iv, if_, imat, icol = mesh_arrays(ing.data)
    islots = [m.name for m in ing.data.materials]
    slots = islots + ([BATTER_SLOT] if BATTER_SLOT not in islots else [])
    b_idx = slots.index(BATTER_SLOT)
    scol = loop_colors_of(shell)
    merged_v = np.concatenate([iv, ev, sv])
    merged_f = if_ + [[i + len(iv) for i in f] for f in ef] + [[i + len(iv) + len(ev) for i in f] for f in sf]
    merged_s = list(map(int, imat)) + list(eslot) + [b_idx] * len(sf)
    merged_c = np.concatenate([icol, ecol, scol])
    bat_name = spec.mesh_name(name, "Battered")
    old = bpy.data.objects.get(bat_name)
    if old is not None:
        remove_object(old)
    bat = make_object(bat_name, merged_v, merged_f, slots, merged_s, loop_colors=merged_c)
    shift = fc.rest_on_floor(bat)[0] - merged_v[0]
    for o in (ing, shell):
        fc.set_verts_cm(o, fc.verts_cm(o) + shift)       # keep the review / .blend copies registered with it
    fc.smart_uv(bat)
    bat["batter_generator"] = "GN MarsBatterShell + Decimate collapse"
    bat["batter_params"] = json.dumps(params)
    bat["batter_excluded_slots"] = ",".join(exclude)
    bat["ingredient_tris"] = ing_tris
    bat["shell_tris"] = shell_tris

    stats = dict(name=name, ingredient_tris=ing_tris, shell_tris=shell_tris, battered_tris=fc.tri_count(bat),
                 tri_ratio=round(shell_tris / ing_tris, 3), fine_tris=fine_tris, decimate_ratio=round(ratio, 4),
                 target_tris=target, cap_tris=cap, params=params, excluded_slots=list(exclude),
                 eyes_exposed=len(ef) // 80, eyes_detected=len(eyes),
                 shell_boundary_edges=boundary, shell_nonmanifold_edges=nonman, inner_components_dropped=dropped,
                 wrapped_vertices=int(len(wrapped)), wrapped_outside=int((~inside).sum()), all_outside=outside_all,
                 clearance_min_cm=round(float(clearance.min()), 3),
                 thickness_cm=dict(zip(("min", "p5", "median", "p95", "max"),
                                       np.percentile(thick, [0, 5, 50, 95, 100]).round(3).tolist())))
    if shell_tris > cap:
        log("WARNING %s shell tris %d over the %.1fx cap %d" % (name, shell_tris, BATTER_TRI_CAP, cap))

    # ---- mask texture
    try:
        mask_path = bake_batter_mask(bat, b_idx, name)
        stats["mask"] = mask_path
    except Exception as exc:          # a failed bake must not lose the mesh
        log("%s mask bake failed: %r" % (name, exc))
        stats["mask"] = None
    fc.export_fbx(bat, extra={"batter": {k: v for k, v in stats.items() if k not in ("name",)}})
    stats["fbx"] = os.path.join(spec.EXPORT_DIR, bat_name + ".fbx")
    if sheets:
        stats["sheet"] = batter_sheet(name, ing, bat, b_idx)
    log("%s battered: %s" % (name, json.dumps({k: stats[k] for k in (
        "ingredient_tris", "shell_tris", "tri_ratio", "shell_boundary_edges", "wrapped_outside", "all_outside", "eyes_exposed",
        "clearance_min_cm", "thickness_cm")})))
    return stats, ing, shell, bat, src_mesh


def smooth_vertex_field(mesh, values, iterations):
    """Average a per-vertex field over its one-ring `iterations` times."""
    e = np.empty(len(mesh.edges) * 2, np.int64)
    mesh.edges.foreach_get("vertices", e)
    e = e.reshape(-1, 2)
    out = np.asarray(values, float).copy()
    for _ in range(iterations):
        acc = out.copy()
        cnt = np.ones(len(out))
        np.add.at(acc, e[:, 0], out[e[:, 1]])
        np.add.at(acc, e[:, 1], out[e[:, 0]])
        np.add.at(cnt, e[:, 0], 1)
        np.add.at(cnt, e[:, 1], 1)
        out = acc / cnt
    return out


def vertex_ao(mesh, verts_cm, bvh, rays=40, reach_cm=5.0):
    """Unoccluded fraction of a cosine-weighted hemisphere per vertex (ray casts against the whole mesh), so the
    cook-first mask is smooth instead of carrying Cycles AO noise. Enclosed ingredient vertices come out ~0."""
    n = np.empty(len(mesh.vertices) * 3)
    mesh.vertices.foreach_get("normal", n)
    n = n.reshape(-1, 3)
    k = np.arange(rays) + 0.5
    r = np.sqrt(k / rays)
    phi = k * math.pi * (3 - math.sqrt(5))
    local = np.stack([r * np.cos(phi), r * np.sin(phi), np.sqrt(1 - r * r)], 1)       # cosine-weighted, +Z
    out = np.zeros(len(verts_cm))
    for i, (p, nz) in enumerate(zip(verts_cm, n)):
        t = np.cross(nz, (1.0, 0.0, 0.0) if abs(nz[0]) < 0.9 else (0.0, 1.0, 0.0))
        t /= np.linalg.norm(t)
        b = np.cross(nz, t)
        dirs = local[:, :1] * t + local[:, 1:2] * b + local[:, 2:] * nz
        o = Vector(p + nz * 0.03)
        free = 0
        for d in dirs:
            if bvh.ray_cast(o, Vector(d), reach_cm)[0] is None:
                free += 1
        out[i] = free / rays
    return out


def bake_batter_mask(bat, batter_index, name):
    """<Name>_Batter_Mask_Mars_T.png: R cook-first (outer shell high, inner ingredient 0), G crumb, B breakup, A rim."""
    v, f, mat, _ = mesh_arrays(bat.data)
    tris = np.array(f)
    if tris.ndim != 2 or tris.shape[1] != 3:
        raise RuntimeError("mask bake expects a triangulated mesh")
    bvh = BVHTree.FromPolygons(v.tolist(), tris.tolist())
    convex = smooth_vertex_field(bat.data, fc.cavity(bat), 2)        # 1 convex / open, 0 concave
    ao_v = vertex_ao(bat.data, v, bvh)

    def masks(fields):
        p = fields["position_cm"]
        h, w = p.shape[:2]
        # food_common's "coverage" is the alpha of a bake image created opaque, so it is 1 everywhere; texels the
        # bake never wrote keep the cleared (0, 0, 0) normal, which decodes to (-1, -1, -1)
        cover = np.linalg.norm(fields["normal"] + 1.0, axis=-1) > 1e-3
        idx = np.argwhere(cover)
        pts = p[cover]
        face = np.empty(len(pts), np.int64)
        for i, q in enumerate(pts):
            face[i] = bvh.find_nearest(Vector(q))[2]
        # barycentric weights of each texel on its nearest triangle -> smooth per-vertex convexity
        a, b, c = (v[tris[face, k]] for k in range(3))
        v0, v1, v2 = b - a, c - a, pts - a
        d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
        d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
        den = np.where(np.abs(d00 * d11 - d01 * d01) < 1e-12, 1e-12, d00 * d11 - d01 * d01)
        wb = np.clip((d11 * d20 - d01 * d21) / den, 0, 1)
        wc = np.clip((d00 * d21 - d01 * d20) / den, 0, 1)
        wa = np.clip(1 - wb - wc, 0, 1)
        def interp(field):
            return wa * field[tris[face, 0]] + wb * field[tris[face, 1]] + wc * field[tris[face, 2]]
        cv, ao = interp(convex), interp(ao_v)
        is_shell = mat[face] == batter_index
        out = np.zeros((h, w, 4), np.float32)
        out[..., 1:3] = 0.5                      # spec neutral outside the islands: (0, 0.5, 0.5, 0)
        r = np.where(is_shell, 0.25 + 0.75 * fc.smoothstep(0.3, 0.9, ao) * (0.7 + 0.3 * cv), 0.0)
        g = 0.5 + 0.9 * (fc.fbm(pts * 1.7, 31, octaves=3) - 0.5)          # crumb grain ~0.6 cm
        bb = 0.5 + 1.1 * (fc.fbm(pts * 0.32, 47, octaves=3) - 0.5)        # browning breakup ~3 cm
        a_ = fc.smoothstep(0.55, 0.85, cv) * np.where(is_shell, 1.0, 0.6)
        out[idx[:, 0], idx[:, 1]] = np.stack([r, np.clip(g, 0, 1), np.clip(bb, 0, 1), a_], axis=1)
        return out

    # fc.bake_fields switches normal_space to OBJECT only after its NORMAL bake, so the first bake of a session would
    # be tangent space, whose cleared background is the flat-normal blue, not the black the coverage test relies on
    bpy.context.scene.render.bake.normal_space = "OBJECT"
    path, _fields = fc.bake_masks(bat, masks, size=spec.MASK_SIZE, name=spec.mesh_name(name, "Batter"))
    return path


# ================================================================ review renders (own framing: a bounding sphere)
def render_views(placed, stem, views, size=(1500, 760), lens=50.0, target=None, radius=None):
    """Workbench renders of [(obj, location)] (objects moved for the shot, restored after) -> list of PNG paths.
    Framing fits every vertex inside both fields of view (or a sphere of `radius` m around `target`)."""
    fc.ensure_dirs()
    scene = bpy.context.scene
    objs = [o for o, _ in placed]
    saved = [(o.location.copy(), o.hide_render) for o in objs]
    hidden = [o for o in scene.objects if o not in objs and o.type == "MESH"]
    hidden_state = [o.hide_render for o in hidden]
    cam_data = bpy.data.cameras.new("_FryerCam")
    cam_data.clip_start, cam_data.clip_end = 0.005, 100.0
    cam_data.lens = lens
    cam_data.sensor_fit = "HORIZONTAL"
    cam = bpy.data.objects.new("_FryerCam", cam_data)
    scene.collection.objects.link(cam)
    sh = scene.display.shading
    prev = (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.resolution_percentage, scene.render.filepath, sh.color_type, sh.light, sh.show_cavity,
            sh.show_specular_highlight, scene.render.film_transparent, scene.view_settings.view_transform)
    paths = []
    try:
        for o in hidden:
            o.hide_render = True
        pts = []
        for o, loc in placed:
            o.location = loc
            o.hide_render = False
            pts.append(fc.verts_cm(o) * 0.01 + np.array(loc))
        pts = np.concatenate(pts)
        if radius is not None:          # frame a sphere around target instead of the vertices
            g = np.array([[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]], float)
            pts = np.array(target, float) + np.concatenate([g, (g + np.roll(g, 1, 1)) * 0.7071]) * radius
        centre = (pts.min(0) + pts.max(0)) * 0.5 if target is None else np.array(target, float)
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        sh.light, sh.color_type, sh.show_cavity, sh.show_specular_highlight = "STUDIO", "VERTEX", True, True
        scene.render.film_transparent = False
        scene.view_settings.view_transform = "Standard"
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        tan_h = 18.0 / lens
        tan_v = tan_h * size[1] / size[0]
        for view in views:
            d = np.array(fc.VIEWS[view] if isinstance(view, str) else view, float)
            d /= np.linalg.norm(d)
            right = np.cross(-d, (0.0, 0.0, 1.0))
            right /= np.linalg.norm(right)
            up = np.cross(right, -d)
            rel = pts - centre
            depth = rel @ d                     # toward the camera
            dist = 1.06 * float(max((depth + np.abs(rel @ right) / tan_h).max(),
                                    (depth + np.abs(rel @ up) / tan_v).max()))
            fc._look_at(cam, tuple(centre + d * dist), tuple(centre))
            path = os.path.join(spec.REVIEW_DIR, "%s_%s.png" % (stem, view if isinstance(view, str) else "v"))
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            paths.append(path)
    finally:
        for o, (loc, hr) in zip(objs, saved):
            o.location, o.hide_render = loc, hr
        for o, hr in zip(hidden, hidden_state):
            o.hide_render = hr
        (scene.camera, scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
         scene.render.resolution_percentage, scene.render.filepath, sh.color_type, sh.light, sh.show_cavity,
         sh.show_specular_highlight, scene.render.film_transparent, scene.view_settings.view_transform) = prev
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return paths


def batter_sheet(name, ing, bat, batter_index):
    """Ingredient | battered | battered cut open (shell faces on the -Y half removed): iso, front, side (+X, where
    the produce faces), top."""
    cut = bat.copy()
    cut.data = bat.data.copy()
    cut.name = "_%s_Cutaway" % name
    bpy.context.scene.collection.objects.link(cut)
    bm = bmesh.new()
    bm.from_mesh(cut.data)
    gone = [f for f in bm.faces if f.material_index == batter_index and f.calc_center_median().y < 0.0]
    bmesh.ops.delete(bm, geom=gone, context="FACES_ONLY")
    bm.to_mesh(cut.data)
    bm.free()
    try:
        ext = max(float(np.ptp(fc.verts_cm(o), axis=0).max()) for o in (ing, bat)) * 0.01 * 1.2
        along_x = [(ing, (-ext, 0.0, 0.0)), (bat, (0.0, 0.0, 0.0)), (cut, (ext, 0.0, 0.0))]
        along_y = [(ing, (0.0, -ext, 0.0)), (bat, (0.0, 0.0, 0.0)), (cut, (0.0, ext, 0.0))]     # the +X view's row
        stem = "%s_Battered" % name
        iso, front = render_views(along_x, stem, ("iso", "front"), size=(1500, 620))
        side = render_views(along_y, stem, ("side",), size=(1500, 620))
        top = render_views(along_x, stem, ("top",), size=(1500, 620))
        paths = [iso, front] + side + top
        return fc.tile_images(paths, os.path.join(spec.REVIEW_DIR, "%s_Battered_sheet.png" % name), cols=1)
    finally:
        remove_object(cut)


# ================================================================ oil: rest meshes
def disc_grid(n=spec.OIL_GRID, radius=spec.OIL_DISC_DIAMETER_CM * 0.5):
    """n x n grid mapped square -> disc (Shirley-Chiu concentric map: equal-area, every ring evenly spaced, so the
    rim corners stay well shaped). Vertex index = row * n + column. Returns (verts cm (n*n, 3), tris)."""
    s = -1.0 + 2.0 * np.arange(n) / (n - 1)
    a, b = np.meshgrid(s, s)          # a: column (x), b: row (y)
    a, b = a.ravel(), b.ravel()
    use_a = np.abs(a) > np.abs(b)
    safe_a = np.where(a == 0, 1.0, a)
    safe_b = np.where(b == 0, 1.0, b)
    r = np.where(use_a, a, b)
    phi = np.where(use_a, (math.pi / 4) * (b / safe_a), math.pi / 2 - (math.pi / 4) * (a / safe_b))
    verts = np.stack([r * np.cos(phi) * radius, r * np.sin(phi) * radius, np.zeros_like(r)], axis=1)
    tris = []
    for i in range(n - 1):
        for j in range(n - 1):
            q = (i * n + j, i * n + j + 1, (i + 1) * n + j + 1, (i + 1) * n + j)        # CCW from +Z
            split_a = ((q[0], q[1], q[2]), (q[0], q[2], q[3]))
            split_b = ((q[0], q[1], q[3]), (q[1], q[2], q[3]))
            tris.extend(max((split_a, split_b), key=lambda sp: min(min_angle(verts, t) for t in sp)))
    return verts, np.array(tris, np.int64)


def min_angle(verts, tri):
    p = verts[list(tri)]
    best = math.pi
    for k in range(3):
        u, w = p[(k + 1) % 3] - p[k], p[(k + 2) % 3] - p[k]
        c = float(np.dot(u, w) / (np.linalg.norm(u) * np.linalg.norm(w) + 1e-12))
        best = min(best, math.acos(max(-1.0, min(1.0, c))))
    return best


def tri_quality(verts, tris):
    p = verts[tris]
    area = 0.5 * np.linalg.norm(np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0]), axis=1)
    angles = []
    for k in range(3):
        u, w = p[:, (k + 1) % 3] - p[:, k], p[:, (k + 2) % 3] - p[:, k]
        c = (u * w).sum(1) / (np.linalg.norm(u, axis=1) * np.linalg.norm(w, axis=1))
        angles.append(np.degrees(np.arccos(np.clip(c, -1, 1))))
    return float(area.min()), float(np.min(angles)), float(np.max(angles))


def unit_sphere():
    v, f = fc.icosphere(1.0, 2)           # bmesh subdivisions=2 -> the 42-vertex icosphere ("subdiv 1" in the UI sense)
    v = v / np.linalg.norm(v, axis=1, keepdims=True)
    return v, np.array(f, np.int64)


# ================================================================ oil: the animation (pure functions of t in [0, 1))
class OilAnim:
    """Every term depends on t only through sin / cos / frac of (integer * t + phase), so f(t + 1) == f(t)."""

    def __init__(self, seed=OIL_SEED):
        rng = np.random.default_rng(seed)
        self.R = spec.OIL_DISC_DIAMETER_CM * 0.5
        T = spec.OIL_SECONDS
        # travelling waves (Gerstner-lite: z sine + a little horizontal sway toward the crests)
        self.waves = []
        for lam in (34.0, 26.0, 21.0, 16.0, 13.0, 10.5, 8.5, 7.0, 6.0):
            ang = rng.uniform(0, math.tau)
            speed = rng.uniform(7.0, 13.0)                                   # cm/s phase speed
            n = max(1, int(round(speed * T / lam)))                         # integer cycles per loop
            amp = (0.09 + lam / 110.0) * rng.uniform(0.8, 1.15)                 # short waves stay lively
            k = math.tau / lam * np.array([math.cos(ang), math.sin(ang)])
            self.waves.append(dict(k=k, n=n, amp=amp, phase=rng.uniform(0, math.tau), q=0.55))
        # slow swirl: three spiral arms rotating once per three loops' worth of arm spacing (30 deg/s)
        self.swirl = dict(m=3, k=math.tau / 30.0, n=1, amp=0.32, phase=rng.uniform(0, math.tau))
        # rolling-boil domes: slots with an integer number of events per loop, each event at its own spot
        self.domes = []
        for j in range(16):
            n = int(rng.choice([2, 3]))
            life = rng.uniform(0.85, 1.15)                                   # seconds per event
            spots = []
            for _ in range(n):
                rr = 36.0 * math.sqrt(rng.uniform(0.0, 1.0))
                aa = rng.uniform(0, math.tau)
                spots.append((rr * math.cos(aa), rr * math.sin(aa)))
            across = rng.uniform(5.0, 8.0)          # FWHM cm; below ~5 cm the 1.4 cm grid turns a dome into a cone
            self.domes.append(dict(n=n, dur=min(0.95, life * n / T), phase=rng.uniform(0, 1), spots=np.array(spots),
                                   sigma=across / 2.3548, height=across * rng.uniform(0.22, 0.32)))
        # bubbles
        self.unit_v, self.unit_f = unit_sphere()
        self.bubbles = self._place_bubbles(rng)
        if SPREAD_POPS:
            self._spread_pops()

    def _spread_pops(self, candidates=96):
        """Re-choose each bubble's phase (cycles, event length, position and size stay) so the pop windows spread
        over the loop: the drawn phases put 9..12 bubbles in their pop window at once twice a loop. Greedy and
        deterministic: bubbles with more cycles first, each takes the candidate phase that keeps the per-frame
        count of popping bubbles lowest (ties: the smallest summed count, then the closest to its drawn phase)."""
        F = spec.OIL_FRAMES
        t = np.arange(F) / F
        counts = np.zeros(F, np.int64)
        order = sorted(range(len(self.bubbles)), key=lambda i: (-self.bubbles[i]["n"], i))
        for i in order:
            b = self.bubbles[i]
            best = None
            for k in range(candidates):
                ph = (k + 0.5) / candidates
                x = b["n"] * t + ph
                u = (x - np.floor(x)) / b["dur"]
                w = (u >= POP_START) & (u < 1.0)
                d = abs(((ph - b["phase"]) + 0.5) % 1.0 - 0.5)
                key = (int((counts[w] + 1).max()) if w.any() else 0, int(counts[w].sum()), d)
                if best is None or key < best[0]:
                    best = (key, ph, w)
            b["phase"] = best[1]
            counts[best[2]] += 1

    def _place_bubbles(self, rng):
        out = []
        tries = 0
        while len(out) < spec.BUBBLE_COUNT:
            tries += 1
            if tries > 100000:
                raise RuntimeError("bubble placement failed")
            rr = 40.0 * math.sqrt(rng.uniform(0.0, 1.0))
            aa = rng.uniform(0, math.tau)
            p = np.array([rr * math.cos(aa), rr * math.sin(aa)])
            radius = rng.uniform(1.5, 3.0)
            if any(np.linalg.norm(p - b["xy"]) < radius + b["radius"] + 2.0 for b in out):
                continue
            n = int(rng.choice([1, 2]))
            life = rng.uniform(1.5, 2.1)
            out.append(dict(xy=p, radius=radius, n=n, dur=min(0.97, life * n / spec.OIL_SECONDS),
                            phase=rng.uniform(0, 1), wob=rng.uniform(0, math.tau), depth=4.0))
        return out

    # ---- surface
    def edge_weight(self, xy):
        r = np.linalg.norm(xy, axis=1)
        return fc.smoothstep(self.R, self.R - 8.0, r)

    def dome_terms(self, xy, t):
        """(height (n,), live count) of the rolling-boil domes at phase t."""
        z = np.zeros(len(xy))
        live = 0
        for d in self.domes:
            x = d["n"] * t + d["phase"]
            cyc = int(math.floor(x)) % d["n"]
            u = (x - math.floor(x)) / d["dur"]
            if u >= 1.0:
                continue
            c = d["spots"][cyc]
            dist2 = ((xy - c) ** 2).sum(1)
            dist = np.sqrt(dist2)
            s = d["sigma"]
            if u < 0.62:                                                   # swell up
                e = math.sin(0.5 * math.pi * u / 0.62) ** 2
                sig = s * (0.75 + 0.25 * u / 0.62)
                z += d["height"] * e * np.exp(-dist2 / (2 * sig * sig))
                live += 1
            else:                                                          # burst -> crater -> outgoing ring
                q = float(fc.smoothstep(0.62, 0.74, u))
                rec = 1.0 - float(fc.smoothstep(0.74, 1.0, u))
                e = (1.0 - q) - 0.3 * q * rec
                z += d["height"] * e * np.exp(-dist2 / (2 * (1.15 * s) ** 2))
                age = (u - 0.62) * d["dur"] * spec.OIL_SECONDS / d["n"]     # seconds since the burst
                ring_r = 1.2 * s + 22.0 * age
                ring = 0.32 * float(fc.smoothstep(0.62, 0.7, u)) * rec * np.exp(-((dist - ring_r) / 1.8) ** 2)
                z += ring * min(1.0, d["height"] / 1.5)
                if u < 0.74:
                    live += 1
        return z, live

    def surface_offsets(self, xy, t):
        """(n, 3) cm offsets (Blender axes) of rest points xy (n, 2) at loop phase t."""
        off = np.zeros((len(xy), 3))
        for w in self.waves:
            th = xy @ w["k"] - math.tau * w["n"] * t + w["phase"]
            off[:, 2] += w["amp"] * np.sin(th)
            khat = w["k"] / np.linalg.norm(w["k"])
            off[:, :2] += (w["q"] * w["amp"] * np.cos(th))[:, None] * khat[None, :]
        r = np.linalg.norm(xy, axis=1)
        theta = np.arctan2(xy[:, 1], xy[:, 0])
        sw = self.swirl
        off[:, 2] += sw["amp"] * fc.smoothstep(2.0, 14.0, r) * np.cos(
            sw["m"] * theta + sw["k"] * r - math.tau * sw["n"] * t + sw["phase"])
        dz, _live = self.dome_terms(xy, t)
        off[:, 2] += dz
        off[:, 2] += self.pop_ripples(xy, t)
        return off * self.edge_weight(xy)[:, None]

    def pop_ripples(self, xy, t):
        """A small ring wave leaving each bubble's pop (the bubble schedule is analytic, so this stays periodic)."""
        z = np.zeros(len(xy))
        for b in self.bubbles:
            x = b["n"] * t + b["phase"]
            period = spec.OIL_SECONDS / b["n"]
            age = (((x - math.floor(x)) - RIPPLE_AT * b["dur"]) % 1.0) * period    # seconds since the ripple began
            if age > 0.9:
                continue
            dist = np.sqrt(((xy - b["xy"]) ** 2).sum(1))
            ring_r = b["radius"] * 0.8 + 20.0 * age
            amp = 0.2 * (b["radius"] / 2.25) * math.exp(-age / 0.3) * float(fc.smoothstep(0.0, 0.05, age))
            z += amp * (np.exp(-((dist - ring_r) / 1.5) ** 2) - 0.6 * np.exp(-((dist - ring_r + 2.2) / 1.5) ** 2))
        return z

    # ---- bubbles
    def bubble_rest(self):
        verts = []
        for b in self.bubbles:
            c = np.array([b["xy"][0], b["xy"][1], -(b["radius"] + 0.5)])
            verts.append(c + self.unit_v * b["radius"])
        return np.concatenate(verts)

    def bubble_state(self, t):
        """Per bubble a dict: centre (3,), s (uniform scale, 0 = a point), radial (xy scale about the vertical
        axis), vertical (z scale about the bubble's lowest point), pop (0 intact .. 1 gone), stage
        ('live' | 'pop' | 'rest'). 'rest' = back at the hidden rest pose below the surface (offset 0, pop 1)."""
        states = []
        surf_all = self.surface_offsets(np.array([b["xy"] for b in self.bubbles]), t)[:, 2]
        for b, surf in zip(self.bubbles, surf_all):
            x = b["n"] * t + b["phase"]
            u = (x - math.floor(x)) / b["dur"]
            xy = b["xy"].copy()
            surf = float(surf)
            r = b["radius"]
            z0 = -b["depth"]
            st = dict(s=1.0, radial=1.0, vertical=1.0, pop=0.0, stage="live")
            if u >= 1.0:                                                   # hidden at the rest pose
                st.update(centre=np.array([xy[0], xy[1], -(r + 0.5)]), pop=1.0, stage="rest")
            elif u < 0.55:                                                 # rise from 4 cm down, growing
                k = u / 0.55
                s = float(fc.smoothstep(0.0, 0.12, u)) * (0.45 + 0.3 * k)
                top = surf - 0.15 * r * s
                z = z0 + (top - z0) * float(fc.smoothstep(0.0, 1.0, k))
                xy = xy + 0.6 * (1.0 - k) * np.array([math.sin(math.tau * 1.5 * k + b["wob"]),
                                                       math.cos(math.tau * 1.1 * k + b["wob"])])
                st.update(centre=np.array([xy[0], xy[1], z]), s=s)
            elif u < POP_START:                                            # a dome riding the surface, swelling
                k = float(fc.smoothstep(0.55, POP_START, u))
                s = 0.75 + 0.25 * k
                wob = 1.0 + 0.07 * math.sin(math.tau * 2.0 * (u - 0.55) / (POP_START - 0.55))   # 0 at both ends
                st.update(centre=np.array([xy[0], xy[1], surf + r * s * (-0.15 + 0.3 * k)]), s=s, vertical=wob)
            else:                                                          # pop: keep the dome, widen, sink apex
                p = (u - POP_START) / (1.0 - POP_START)
                st.update(centre=np.array([xy[0], xy[1], surf + 0.15 * r]), radial=1.0 + POP_RING * p,
                          vertical=1.0 - 0.5 * POP_SINK * p, pop=p, stage="pop")
            states.append(st)
        return states

    def bubble_frame(self, t):
        """(verts cm (B*42, 3), normals (B*42, 3), scale per bubble, pop per bubble, stage per bubble) at phase t.
        A vertex is centre + r * s * (ux * radial, uy * radial, (uz + 1) * vertical - 1): the vertical scale pivots
        on the bubble's lowest point, so vertical = 1 - POP_SINK / 2 * pop drops the apex by POP_SINK * r * pop."""
        verts, nrms, scales, pops, stages = [], [], [], [], []
        u = self.unit_v
        for b, st in zip(self.bubbles, self.bubble_state(t)):
            rs = b["radius"] * st["s"]
            a, c = st["radial"], st["vertical"]
            verts.append(st["centre"] + rs * np.stack([u[:, 0] * a, u[:, 1] * a, (u[:, 2] + 1.0) * c - 1.0], 1))
            n = u / np.array([a, a, c])
            nrms.append(n / np.linalg.norm(n, axis=1, keepdims=True))
            scales.append(st["s"])
            pops.append(st["pop"])
            stages.append(st["stage"])
        return np.concatenate(verts), np.concatenate(nrms), np.array(scales), np.array(pops), stages

    def bubble_local(self):
        """Static per-vertex (x, y) of the BubbleLocal UV: x = rest height within its bubble (0 lowest, 1 apex),
        y = (bubble index + 0.5) / bubble count."""
        z = self.unit_v[:, 2]
        h = (z - z.min()) / (z.max() - z.min())
        nb, B = len(self.unit_v), len(self.bubbles)
        return np.stack([np.tile(h, B), np.repeat((np.arange(B) + 0.5) / B, nb)], 1)


def vertex_normals(verts, tris):
    p = verts[tris]
    fn = np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0])          # area weighted
    vn = np.zeros_like(verts)
    for k in range(3):
        np.add.at(vn, tris[:, k], fn)
    return vn / np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-12)


# ================================================================ oil: build, bake, verify
def build_oil_meshes(anim):
    verts, tris = disc_grid()
    for name in ("OilSurface_Mars_SM", "OilBubbles_Mars_SM"):
        old = bpy.data.objects.get(name)
        if old is not None:
            remove_object(old)
    surf = make_object("OilSurface_Mars_SM", verts, tris.tolist(), ("Oil",), [0] * len(tris), smooth=True)
    bverts = anim.bubble_rest()
    nb = len(anim.unit_v)
    btris = np.concatenate([anim.unit_f + i * nb for i in range(len(anim.bubbles))])
    bub = make_object("OilBubbles_Mars_SM", bverts, btris.tolist(), ("Oil",), [0] * len(btris), smooth=True)
    D = spec.OIL_DISC_DIAMETER_CM
    for obj, rgb in ((surf, OIL_RGB), (bub, BUBBLE_RGB)):
        mesh = obj.data
        mesh.uv_layers.new(name="UVMap")
        lv = np.empty(len(mesh.loops), np.int64)
        mesh.loops.foreach_get("vertex_index", lv)
        v = fc.verts_cm(obj)
        mesh.uv_layers["UVMap"].data.foreach_set("uv", np.stack([v[lv, 0] / D + 0.5, v[lv, 1] / D + 0.5], 1).ravel())
        fc.write_vat_uvs(obj)
        if obj is bub:                    # UV2 "BubbleLocal": static rest height in the bubble + bubble id
            bl = mesh.uv_layers.new(name="BubbleLocal")
            bl.data.foreach_set("uv", anim.bubble_local()[lv].ravel())
        fc.paint(obj, np.tile(rgb, (len(mesh.vertices), 1)), alpha=np.ones(len(mesh.vertices)), domain="POINT",
                 variation=0.0, cavity_darken=0.0)
        mesh.uv_layers.active = mesh.uv_layers["UVMap"]
    return surf, bub, tris, btris


def oil_frames(anim, rest_surface, surf_tris):
    F = spec.OIL_FRAMES
    xy = rest_surface[:, :2]
    s_off = np.zeros((F + 1, len(xy), 3))
    s_nrm = np.zeros((F + 1, len(xy), 3))
    b_rest = anim.bubble_rest()
    B = len(anim.bubbles)
    b_off = np.zeros((F + 1, len(b_rest), 3))
    b_nrm = np.zeros((F + 1, len(b_rest), 3))
    b = dict(scale=np.zeros((F + 1, B)), pop=np.zeros((F + 1, B)), stage=np.empty((F + 1, B), object),
             surf=np.zeros((F + 1, B)))
    bxy = np.array([bb["xy"] for bb in anim.bubbles])
    live = []
    for f in range(F + 1):                       # frame F (t = 1) only for the loop check
        t = f / F
        s_off[f] = anim.surface_offsets(xy, t)
        s_nrm[f] = vertex_normals(rest_surface + s_off[f], surf_tris)
        bv, bn, bs, bp, bst = anim.bubble_frame(t)
        b_off[f], b_nrm[f] = bv - b_rest, bn
        b["scale"][f], b["pop"][f], b["stage"][f] = bs, bp, bst
        b["surf"][f] = anim.surface_offsets(bxy, t)[:, 2]
        live.append(anim.dome_terms(xy[:1], t)[1])
    return s_off, s_nrm, b_off, b_nrm, b, live[:F]


def to_unreal(v):
    return v * fc.UE_MIRROR


def vat_image(off_blender, nrm_blender, pos_alpha=None):
    """(F, V, 3) offsets / normals in Blender cm -> bottom-up RGBA pos and nrm arrays + (min, max). Frame f goes to
    the top-down row f, i.e. Blender's bottom-up row F - 1 - f. pos_alpha (F, V) goes into the position alpha
    (the bubbles' pop); without it the alpha is 1."""
    off = to_unreal(off_blender)
    lo, hi = float(off.min()), float(off.max())
    if hi - lo < 1e-6:
        hi = lo + 1e-6
    F, V = off.shape[:2]
    pos = np.ones((F, V, 4), np.float32)
    pos[..., :3] = (off - lo) / (hi - lo)
    if pos_alpha is not None:
        pos[..., 3] = pos_alpha
    nrm = np.ones((F, V, 4), np.float32)
    nrm[..., :3] = to_unreal(nrm_blender) * 0.5 + 0.5
    return pos[::-1].copy(), nrm[::-1].copy(), lo, hi


def read_exr_top_row(path):
    """Minimal reader for an uncompressed scanline EXR: returns (header dict, first stored scanline as {chan: (w,)})
    so the frame order is checked straight from the file, independent of Blender's loader."""
    with open(path, "rb") as fh:
        data = fh.read()
    if struct.unpack_from("<I", data, 0)[0] != 20000630:
        raise RuntimeError("not an EXR")
    pos = 8
    header = {}
    while data[pos] != 0:
        end = data.index(b"\0", pos)
        name = data[pos:end].decode()
        pos = end + 1
        end = data.index(b"\0", pos)
        typ = data[pos:end].decode()
        pos = end + 1
        size = struct.unpack_from("<i", data, pos)[0]
        pos += 4
        header[name] = (typ, data[pos:pos + size])
        pos += size
    pos += 1
    chans = []
    raw = header["channels"][1]
    p = 0
    while raw[p] != 0:
        end = raw.index(b"\0", p)
        cname = raw[p:end].decode()
        ptype = struct.unpack_from("<i", raw, end + 1)[0]
        chans.append((cname, ptype))
        p = end + 1 + 16
    xmin, ymin, xmax, ymax = struct.unpack("<iiii", header["dataWindow"][1])
    compression = header["compression"][1][0]
    line_order = header["lineOrder"][1][0]
    w, h = xmax - xmin + 1, ymax - ymin + 1
    offsets = struct.unpack_from("<%dQ" % h, data, pos)
    first = min(range(h), key=lambda i: struct.unpack_from("<i", data, offsets[i])[0])
    y = struct.unpack_from("<i", data, offsets[first])[0]
    q = offsets[first] + 8
    row = {}
    for cname, ptype in chans:
        dt, nbytes = (np.float16, 2) if ptype == 1 else (np.float32, 4)
        row[cname] = np.frombuffer(data, dt, w, q).astype(np.float64)
        q += w * nbytes
    return dict(width=w, height=h, compression=compression, line_order=line_order, channels=[c for c, _ in chans],
                y_of_row=y, ymin=ymin), row


def pop_windows(stage_col):
    """Cyclic runs of 'pop' frames in one bubble's (F,) stage column -> [[frame, ...], ...]."""
    F = len(stage_col)
    inw = np.array([s == "pop" for s in stage_col])
    runs = []
    for f in range(F):
        if inw[f] and not inw[f - 1]:
            run = [f]
            g = (f + 1) % F
            while inw[g] and g != f:
                run.append(g)
                g = (g + 1) % F
            runs.append(run)
    return runs


def pop_checks(alpha_frames, bs, anim, rest_b, b_off):
    """Checks on the pop alpha as re-read from the EXR (F, B * nb): uniform per bubble, 0 / 1 outside the windows,
    non-decreasing inside, exactly 1 on the frame after every window; plus how many pop at once and how long the
    opening ring stays above the oil (unmasked vertices: BubbleLocal.x <= 1 - pop, above the local surface)."""
    F, B, nb = spec.OIL_FRAMES, len(anim.bubbles), len(anim.unit_v)
    A = alpha_frames.reshape(F, B, nb).astype(np.float64)
    stage = bs["stage"][:F]
    Ab = A[:, :, 0]
    inw = np.vectorize(lambda s: s == "pop")(stage)
    out = ~inw
    h = anim.bubble_local()[:, 0].reshape(B, nb)
    res = dict(per_bubble_uniform_max_dev=float(np.abs(A - A[:, :, :1]).max()),
               outside_window_nonbinary=int(((Ab[out] != 0.0) & (Ab[out] != 1.0)).sum()),
               rest_frames_all_one=bool(np.all(Ab[stage == "rest"] == 1.0)),
               live_frames_all_zero=bool(np.all(Ab[stage == "live"] == 0.0)))
    windows, lengths, last, after_one, mono, ring_frames, ring_gone_pop = 0, [], [], True, True, [], []
    for b in range(B):
        for run in pop_windows(stage[:, b]):
            windows += 1
            lengths.append(len(run))
            vals = Ab[run, b]
            mono &= bool(np.all(np.diff(vals) >= 0.0))
            last.append(float(vals[-1]))
            after_one &= bool(Ab[(run[-1] + 1) % F, b] == 1.0)
            seen = 0
            gone = None
            for f in run:
                z = (rest_b + b_off[f])[b * nb:(b + 1) * nb, 2]
                if np.any((h[b] <= 1.0 - Ab[f, b]) & (z > bs["surf"][f, b] + 0.02)):
                    seen += 1
                elif gone is None:
                    gone = float(Ab[f, b])
            ring_frames.append(seen)
            if gone is not None:
                ring_gone_pop.append(gone)
    popping = inw.sum(1)
    res.update(windows_per_loop=windows, window_frames=dict(min=min(lengths), max=max(lengths)),
               window_monotonic=mono, frame_after_window_is_one=after_one,
               last_in_window_alpha=dict(min=round(min(last), 4), mean=round(float(np.mean(last)), 4)),
               popping_at_once=dict(min=int(popping.min()), mean=round(float(popping.mean()), 2),
                                    max=int(popping.max())),
               ring_above_oil_frames=dict(min=int(min(ring_frames)), mean=round(float(np.mean(ring_frames)), 2),
                                          max=int(max(ring_frames))),
               ring_sinks_below_oil_at_pop=dict(min=round(min(ring_gone_pop), 3) if ring_gone_pop else None,
                                                mean=round(float(np.mean(ring_gone_pop)), 3) if ring_gone_pop else None))
    return res


def bake_oil(sheets):
    anim = OilAnim()
    surf, bub, surf_tris, bub_tris = build_oil_meshes(anim)
    rest_s = fc.verts_cm(surf)
    rest_b = fc.verts_cm(bub)
    s_off, s_nrm, b_off, b_nrm, bs, live = oil_frames(anim, rest_s, surf_tris)
    F = spec.OIL_FRAMES
    nb, B = len(anim.unit_v), len(anim.bubbles)
    pop_v = np.repeat(bs["pop"], nb, axis=1)                         # (F + 1, B * nb) pop per vertex per frame
    area_min, ang_min, ang_max = tri_quality(rest_s, surf_tris)
    log("oil disc: %d verts %d tris, min tri area %.3f cm2, angles %.1f..%.1f deg" % (
        len(rest_s), len(surf_tris), area_min, ang_min, ang_max))

    textures = {}
    sets = (("OilSurface", surf, s_off, s_nrm, None), ("OilBubbles", bub, b_off, b_nrm, pop_v[:F]))
    decoded_err = {}
    file_checks = {}
    bubble_alpha = None
    for stem, obj, off, nrm, alpha in sets:
        pos_img, nrm_img, lo, hi = vat_image(off[:F], nrm[:F], alpha)
        V = off.shape[1]
        ppath = os.path.join(spec.EXPORT_DIR, "%s_VATPos_Mars_T.exr" % stem)
        npath = os.path.join(spec.EXPORT_DIR, "%s_VATNrm_Mars_T.exr" % stem)
        fc.save_exr(ppath, pos_img)
        fc.save_exr(npath, nrm_img)
        ue = to_unreal(off[:F])
        textures["%s_VATPos_Mars_T" % stem] = dict(
            mesh=obj.name, kind="position", file=os.path.basename(ppath), width=V, height=F, vertex_count=V,
            pos_min=lo, pos_max=hi, pos_min_xyz=ue.reshape(-1, 3).min(0).round(4).tolist(),
            pos_max_xyz=ue.reshape(-1, 3).max(0).round(4).tolist(),
            max_offset_cm=float(np.linalg.norm(ue, axis=2).max()),
            alpha="unused, always 1" if alpha is None else "pop (see the pop block)")
        textures["%s_VATNrm_Mars_T" % stem] = dict(mesh=obj.name, kind="normal", file=os.path.basename(npath),
                                                    width=V, height=F, vertex_count=V)
        # ---- reload through Blender and decode frames 0, 37, 119
        errs = {}
        for path, kind in ((ppath, "pos"), (npath, "nrm")):
            img = bpy.data.images.load(path, check_existing=False)
            img.colorspace_settings.name = "Non-Color"
            img.alpha_mode = "STRAIGHT"
            w, h = img.size
            px = np.empty(w * h * 4, np.float32)
            img.pixels.foreach_get(px)
            px = px.reshape(h, w, 4)
            bpy.data.images.remove(img)
            if (w, h) != (V, F):
                raise RuntimeError("%s size %s" % (path, (w, h)))
            errs[kind + "_nan"] = int(np.isnan(px).sum())
            errs[kind + "_alpha_min"] = float(px[..., 3].min())
            for f in (0, 37, F - 1):
                row = px[F - 1 - f, :, :3].astype(np.float64)          # bottom-up row F-1-f holds frame f
                if kind == "pos":
                    dec = to_unreal(lo + row * (hi - lo))                  # Unreal -> Blender (mirror is its own inverse)
                    errs["pos_err_cm_f%d" % f] = float(np.abs(dec - off[f]).max())
                    if alpha is not None:
                        errs["pop_err_f%d" % f] = float(np.abs(px[F - 1 - f, :, 3] - alpha[f]).max())
                else:
                    dec = to_unreal(row * 2.0 - 1.0)
                    errs["nrm_err_f%d" % f] = float(np.abs(dec - nrm[f]).max())
            if kind == "pos" and alpha is not None:
                bubble_alpha = px[::-1, :, 3].copy()                       # frame order, straight from the file
        decoded_err[stem] = errs
        # ---- the stored top scanline in the file must be frame 0
        hdr, top = read_exr_top_row(ppath)
        top_rgb = np.stack([top["R"], top["G"], top["B"]], 1)
        f0 = (to_unreal(off[0]) - lo) / (hi - lo)
        fl = (to_unreal(off[F - 1]) - lo) / (hi - lo)
        file_checks[stem] = dict(hdr, top_row_vs_frame0=float(np.abs(top_rgb - f0).max()),
                                 top_row_vs_frame_last=float(np.abs(top_rgb - fl).max()))
        if alpha is not None:
            file_checks[stem]["top_row_alpha_vs_frame0_pop"] = float(np.abs(top["A"] - alpha[0]).max())

    # ---- loop seam and continuity
    def jumps(off, rest, mask=None):
        P = rest[None] + off
        step = np.linalg.norm(P[1:F] - P[:F - 1], axis=2)                 # f -> f+1 inside the loop
        seam = np.linalg.norm(P[0] - P[F - 1], axis=1)                    # 119 -> 0
        if mask is not None:
            step = np.where(mask[1:F] & mask[:F - 1], step, 0.0)
            seam = np.where(mask[0] & mask[F - 1], seam, 0.0)
        per_frame_max = step.max(1)
        return dict(seam_max_cm=float(seam.max()), step_max_cm_median=float(np.median(per_frame_max)),
                    step_max_cm_max=float(per_frame_max.max()), step_mean_cm=float(step.mean()),
                    seam_mean_cm=float(seam.mean()),
                    seam_over_median_step=float(seam.max() / max(np.median(per_frame_max), 1e-9)))
    shown = (bs["scale"] > 1e-6) & (bs["pop"] < 1.0)                 # not a point and not fully masked
    loop_check = dict(
        frame_N_equals_frame_0=dict(surface_max_cm=float(np.abs(s_off[F] - s_off[0]).max()),
                                    bubbles_max_cm=float(np.abs(b_off[F] - b_off[0]).max()),
                                    surface_normal_max=float(np.abs(s_nrm[F] - s_nrm[0]).max()),
                                    bubbles_pop_max=float(np.abs(bs["pop"][F] - bs["pop"][0]).max())),
        surface=jumps(s_off, rest_s),
        bubbles_visible=jumps(b_off, rest_b, np.repeat(shown, nb, axis=1)),
        domes_live=dict(min=int(min(live)), mean=round(float(np.mean(live)), 2), max=int(max(live))),
        bubbles_live=dict(min=int(shown[:F].sum(1).min()), mean=round(float(shown[:F].sum(1).mean()), 2),
                          max=int(shown[:F].sum(1).max())),
        pop=pop_checks(bubble_alpha, bs, anim, rest_b, b_off),
        decode=decoded_err, exr_file=file_checks,
        disc_triangles=dict(count=int(len(surf_tris)), min_area_cm2=round(area_min, 4),
                            min_angle_deg=round(ang_min, 2), max_angle_deg=round(ang_max, 2)))
    win_s = [(1.0 - POP_START) * b["dur"] * spec.OIL_SECONDS / b["n"] for b in anim.bubbles]

    meta = {
        "version": OIL_VAT_VERSION,
        "frames": F, "fps": spec.OIL_FPS, "seconds": spec.OIL_SECONDS,
        "loop": "exactly periodic: frame %d == frame 0; play frames 0..%d and wrap" % (F, F - 1),
        "space": "offsets and normals in Unreal local axes (cm); Blender (x, y, z) -> Unreal (x, -y, z)",
        "textures": textures,
        "meshes": {
            "OilSurface_Mars_SM": dict(vertex_count=len(rest_s), tris=int(len(surf_tris)),
                                       diameter_cm=spec.OIL_DISC_DIAMETER_CM, rest="flat disc at z = 0, pivot centre",
                                       uv0="UVMap planar: u = x / D + 0.5, v = y / D + 0.5 (Blender axes)",
                                       uv1="VATColumn: (vertex index + 0.5) / vertex_count, 0"),
            "OilBubbles_Mars_SM": dict(vertex_count=len(rest_b), tris=int(len(bub_tris)), bubbles=B,
                                       verts_per_bubble=nb,
                                       rest="each bubble at full size just under z = 0 (hidden without the VAT)",
                                       uv0="UVMap planar like the surface", uv1="VATColumn like the surface",
                                       uv2="BubbleLocal (see the bubble_local block)"),
        },
        "decode": {
            "u": "UV1.x (Unreal UV channel 1, Blender layer 'VATColumn') = (vertex_index + 0.5) / vertex_count",
            "frame_index": "floor(frac(Time * Speed / seconds) * frames), an integer 0..frames-1 (no blending)",
            "v": "(frame_index + 0.5) / frames",
            "frame0_at": "v = 0 (top row). Frame f is stored in top-down image row f (Blender bottom-up pixel row "
                         "frames-1-f); Unreal imports EXR rows top-down with v = 0 at the top, so no flip",
            "position": "offset_cm = pos_min + rgb * (pos_max - pos_min) (scalars, same for x, y, z; Unreal local "
                        "cm); World Position Offset = TransformVector(Local -> World, offset_cm)",
            "normal": "normal_local = rgb * 2 - 1 (Unreal local axes); TransformVector(Local -> World) and use it as "
                      "the world-space normal (material Tangent Space Normal off), or transform to tangent space",
            "sampler": "Nearest (point) filter, Clamp, no mip maps; texture: HDR (RGBA16F) compression or "
                       "uncompressed, sRGB off, NoMipmaps, Power Of Two Mode none, Never Stream",
            "mesh_import": "Use Full Precision UVs ON for both VAT meshes (half-float UVs cannot address 4096 or "
                           "2016 columns: above u = 0.5 their step is 1/2048), keep UV channel 1, no lightmap UV "
                           "generation into channel 1; extend the bounds by max_offset_cm",
            "hlsl": "float fi = floor(frac(Time * Speed / %.1f) * %d.0); float2 uv = float2(UV1.x, (fi + 0.5) / %d.0); "
                    "float3 off = PosMin + Pos.SampleLevel(PointClamp, uv, 0).rgb * (PosMax - PosMin); "
                    "float3 n = Nrm.SampleLevel(PointClamp, uv, 0).rgb * 2 - 1;  // both Unreal local"
                    % (spec.OIL_SECONDS, F, F),
        },
        "pop": {
            "texture": "OilBubbles_VATPos_Mars_T", "channel": "A",
            "alpha": "pop per vertex per frame (same value on all %d vertices of a bubble): 0 = intact (rising, then "
                     "riding the surface), rises linearly 0..1 across the pop window, exactly 1 on every frame the "
                     "bubble is inactive (back at its hidden rest pose below the surface)" % nb,
            "mask": "opacity mask: hide where BubbleLocal.x > 1 - pop, so the dome opens from the apex downward and "
                    "leaves a widening base ring; pop = 1 hides the whole bubble",
            "window_fraction": round(1.0 - POP_START, 4),
            "window_of": "the last fraction of each bubble's active event (rise, ride the surface, pop); cycles per "
                         "loop, event length, position and radius are unchanged from version 1, the phases are "
                         "re-spread so the pop windows do not bunch",
            "window_seconds": dict(min=round(min(win_s), 3), max=round(max(win_s), 3)),
            "window_frames": loop_check["pop"]["window_frames"],
            "ring_scale": "radial scale about the bubble's vertical axis = 1 + %.2f * pop" % POP_RING,
            "apex_sink": "apex drops %.2f * radius * pop (vertical squash about the bubble's lowest point)" % POP_SINK,
            "lookup": "same texel as the position: Pos.SampleLevel(PointClamp, uv, 0).a; float16 stores 0 and 1 "
                      "exactly",
            "surface_alpha": "OilSurface_VATPos_Mars_T alpha is unused, always 1",
        },
        "bubble_local": {
            "mesh": "OilBubbles_Mars_SM", "uv_layer": "BubbleLocal", "unreal_uv_channel": 2,
            "x": "static normalised rest height of the vertex within its bubble: 0 at the bubble's lowest vertex, "
                 "1 at its apex",
            "y": "(bubble index + 0.5) / %d, a per-bubble id for variation" % B,
            "bubble_count": B, "verts_per_bubble": nb,
        },
        "loop_check": loop_check,
    }
    jpath = os.path.join(spec.EXPORT_DIR, "OilVAT_Mars.json")
    with open(jpath, "w") as fh:
        json.dump(meta, fh, indent=2)
    log("wrote %s (version %d)" % (jpath, OIL_VAT_VERSION))
    log("pop check: %s" % json.dumps(loop_check["pop"]))

    for obj, off in ((surf, s_off), (bub, b_off)):
        obj["vat_frames"] = F
        obj["vat_fps"] = spec.OIL_FPS
        fc.export_fbx(obj, extra={"vat": {"json": "OilVAT_Mars.json", "frames": F, "version": OIL_VAT_VERSION,
                                          "max_offset_cm": float(np.linalg.norm(off, axis=2).max())}})
    sheet = pop_sheet = None
    if sheets:
        sheet = oil_sheet(anim, surf, rest_s, rest_b, s_off, b_off, bs["pop"])
        pop_sheet = oil_pop_sheet(anim, surf, rest_s, rest_b, s_off, b_off, bs)
    return dict(meta=meta, sheet=sheet, pop_sheet=pop_sheet, surf=surf, bub=bub)


def masked_bubbles(anim, verts_cm, pop_b, only=None, name="_BubblesMasked"):
    """Temporary object of what the material shows: each bubble clipped where BubbleLocal.x > 1 - pop. Within a
    bubble the deformed z is affine in the rest height (the pop's radial scale leaves z alone, the squash is
    linear), and the material interpolates x linearly per triangle, so its per-pixel mask edge is exactly the
    horizontal plane through height 1 - pop: bisect there. only = keep just that bubble. None when nothing is left."""
    nb = len(anim.unit_v)
    h = anim.bubble_local()[:nb, 0]
    i_lo, i_hi = int(np.argmin(h)), int(np.argmax(h))
    out_v, out_f = [], []
    for b in range(len(anim.bubbles)):
        p = float(pop_b[b])
        if (only is not None and b != only) or p >= 1.0:
            continue
        v = verts_cm[b * nb:(b + 1) * nb]
        span = v[i_hi, 2] - v[i_lo, 2]
        if span < 1e-4:                                   # a bubble shrunk to a point
            continue
        bm = bmesh.new()
        bv = [bm.verts.new(co) for co in v]
        for f in anim.unit_f:
            bm.faces.new([bv[i] for i in f])
        if p > 0.0:
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-6,
                                   plane_co=(0.0, 0.0, v[i_lo, 2] + span * (1.0 - p)), plane_no=(0.0, 0.0, 1.0),
                                   clear_outer=True)
        bm.verts.index_update()
        base = sum(len(x) for x in out_v)
        out_v.append(np.array([vv.co[:] for vv in bm.verts]).reshape(-1, 3))
        out_f.extend([[base + vv.index for vv in f.verts] for f in bm.faces])
        bm.free()
    if not out_f:
        return None
    verts = np.concatenate(out_v)
    obj = make_object(name, verts, out_f, ("Oil",), [0] * len(out_f), smooth=True)
    fc.paint(obj, np.tile(BUBBLE_RGB, (len(verts), 1)), alpha=np.ones(len(verts)), domain="POINT", variation=0.0,
             cavity_darken=0.0)
    return obj


def render_oil_frame(anim, surf, rest_s, rest_b, s_off, b_off, pop_b, f, stem, view, size, with_surface=True,
                     only=None, target=None, radius=None):
    fc.set_verts_cm(surf, rest_s + s_off[f])
    mb = masked_bubbles(anim, rest_b + b_off[f], pop_b[f], only=only)
    placed = ([(surf, (0, 0, 0))] if with_surface else []) + ([(mb, (0, 0, 0))] if mb is not None else [])
    try:
        p = render_views(placed, stem, [view], size=size, target=target, radius=radius)[0]
    finally:
        if mb is not None:
            remove_object(mb)
        fc.set_verts_cm(surf, rest_s)
    stamped = p.replace("_v.png", ".png")
    os.replace(p, stamped)
    return stamped


def oil_sheet(anim, surf, rest_s, rest_b, s_off, b_off, pop_b):
    """6 evenly spaced frames, bubbles with the pop mask applied as the material will."""
    F = spec.OIL_FRAMES
    frames = [int(round(i * F / SHEET_FRAMES)) for i in range(SHEET_FRAMES)]
    paths = [render_oil_frame(anim, surf, rest_s, rest_b, s_off, b_off, pop_b, f, "OilVAT_f%03d" % f,
                              (0.0, -1.0, 0.62), (960, 600)) for f in frames]
    sheet = fc.tile_images(paths, os.path.join(spec.REVIEW_DIR, "OilVAT_sheet.png"), cols=3)
    close = [render_oil_frame(anim, surf, rest_s, rest_b, s_off, b_off, pop_b, f, "OilVAT_close_f%03d" % f,
                              (0.0, -1.0, 0.33), (960, 600), target=(0.0, 0.08, 0.0), radius=0.2) for f in frames]
    fc.tile_images(close, os.path.join(spec.REVIEW_DIR, "OilVAT_close_sheet.png"), cols=3)
    return sheet


def oil_pop_sheet(anim, surf, rest_s, rest_b, s_off, b_off, bs):
    """The largest bubble followed through its pop window at 6 frames: top row with the oil, bottom row the masked
    bubble alone (same camera), so the ring left after the apex opens is visible on both sides of the surface."""
    F = spec.OIL_FRAMES
    b = int(np.argmax([bb["radius"] for bb in anim.bubbles]))
    run = pop_windows(bs["stage"][:F, b])[0]
    picks = [run[int(round(i * (len(run) - 1) / (SHEET_FRAMES - 1)))] for i in range(SHEET_FRAMES)]
    r = anim.bubbles[b]["radius"]
    xy = anim.bubbles[b]["xy"]
    target = (xy[0] * 0.01, xy[1] * 0.01, float(bs["surf"][picks[0], b]) * 0.01)
    view = (0.0, -1.0, 0.55)
    top = [render_oil_frame(anim, surf, rest_s, rest_b, s_off, b_off, bs["pop"], f, "OilVAT_pop_f%03d" % f, view,
                            (640, 420), target=target, radius=r * 0.024) for f in picks]
    bottom = [render_oil_frame(anim, surf, rest_s, rest_b, s_off, b_off, bs["pop"], f, "OilVAT_popalone_f%03d" % f,
                               view, (640, 420), with_surface=False, only=b, target=target, radius=r * 0.024)
              for f in picks]
    log("pop sheet: bubble %d (radius %.2f cm), frames %s, pop %s" % (
        b, r, picks, [round(float(bs["pop"][f, b]), 3) for f in picks]))
    return fc.tile_images(top + bottom, os.path.join(spec.REVIEW_DIR, "OilVAT_pop_sheet.png"), cols=SHEET_FRAMES)


# ================================================================ save
def export_bubble_particle_mesh():
    """OilBubble_Mars_SM: one bubble dome for Niagara mesh particles (the VAT set is separate). Icosphere radius 1 cm
    (the particle scales it), 320 tris, smooth, pivot at the LOWEST point (base centre z = 0, apex z = 2), slot Oil,
    Col white / alpha 1. UVs: UVMap planar over its own footprint (u = x / 2 + 0.5, v = y / 2 + 0.5), VATColumn all
    zero (channel layout only), BubbleLocal x = height 0 base .. 1 apex, y = 0.5."""
    radius = 1.0
    v, f = fc.icosphere(radius, 3)                     # bmesh subdivisions 3 = 162 verts / 320 tris
    v = v / np.linalg.norm(v, axis=1, keepdims=True) * radius
    v[:, 2] -= v[:, 2].min()                           # lowest point (the bottom pole) -> z = 0, apex z = 2
    old = bpy.data.objects.get("OilBubble_Mars_SM")
    if old is not None:
        remove_object(old)
    obj = make_object("OilBubble_Mars_SM", v, f, ("Oil",), [0] * len(f), smooth=True)
    mesh = obj.data
    lv = np.empty(len(mesh.loops), np.int64)
    mesh.loops.foreach_get("vertex_index", lv)
    vl = v[lv]
    zero = np.zeros(len(lv))
    for name, uv in (("UVMap", np.stack([vl[:, 0] / (2 * radius) + 0.5, vl[:, 1] / (2 * radius) + 0.5], 1)),
                     ("VATColumn", np.stack([zero, zero], 1)),
                     ("BubbleLocal", np.stack([vl[:, 2] / (2 * radius), zero + 0.5], 1))):
        mesh.uv_layers.new(name=name).data.foreach_set("uv", uv.ravel())
    mesh.uv_layers.active = mesh.uv_layers["UVMap"]
    fc.paint(obj, np.ones((len(v), 3)), alpha=np.ones(len(v)), domain="POINT", variation=0.0, cavity_darken=0.0)
    fc.export_fbx(obj, extra={"particle_mesh": True, "radius_cm": radius})
    lo, hi = fc.bounds_cm(obj)
    log("OilBubble_Mars_SM: %d verts %d tris, z %.4f..%.4f cm, xy centre %s" % (
        len(v), fc.tri_count(obj), lo[2], hi[2], ((lo[:2] + hi[:2]) * 0.5).round(6).tolist()))
    return obj


def carry_batter_objects(path, ng):
    """--save without --batter: bring the battered / shell / demo objects over from the existing Food_Fryer.blend so
    an --oil run does not drop them. Their GN modifiers are pointed at this run's MarsBatterShell."""
    want = lambda n: n.endswith("_BatterShell") or n.endswith("_Battered_Mars_SM") or n.startswith("BatterDemo_")
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if want(n)]
    out = []
    for o in dst.objects:
        if o is None:
            continue
        bpy.context.scene.collection.objects.link(o)
        for m in o.modifiers:
            if m.type == "NODES" and m.node_group is not None and m.node_group is not ng:
                values = {item.name: getattr(m.properties.inputs, item.identifier).value
                          for item in m.node_group.interface.items_tree
                          if item.item_type == "SOCKET" and item.in_out == "INPUT" and item.socket_type != "NodeSocketGeometry"}
                m.node_group = ng
                set_group_inputs(m, ng, values)
        out.append(o)
    for g in list(bpy.data.node_groups):
        if g is not ng and g.name.startswith(BATTER_GROUP + ".") and g.users <= 1:
            bpy.data.node_groups.remove(g)
    for lib in list(bpy.data.libraries):        # the appended data is local; the leftover entry blocks the save
        if os.path.normcase(bpy.path.abspath(lib.filepath)) == os.path.normcase(path):
            bpy.data.libraries.remove(lib)
    log("carried %d batter objects over from %s" % (len(out), path))
    return out


def save_blend(keep):
    """Food_Fryer.blend: the node group, the rest oil meshes, shells / battered meshes, a live BatterDemo."""
    for o in list(bpy.data.objects):
        if o not in keep:
            remove_object(o)
    bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
    # lay the inspection copies out (object transforms only; exported mesh data stays at the spec pivot)
    rows = {"_Battered_Mars_SM": -0.8, "_BatterShell": -1.1}
    names = sorted({o.name.split("_")[0] for o in keep if any(o.name.endswith(k) for k in rows)})
    for o in keep:
        for suffix, y in rows.items():
            if o.name.endswith(suffix):
                o.location = (0.4 * (names.index(o.name.split("_")[0]) - (len(names) - 1) * 0.5), y, 0.0)
        if o.name.startswith("BatterDemo_"):
            o.location = (0.4 * (len(names) + 1) * 0.5 + 0.2, -0.95, 0.0)
    path = os.path.join(spec.BLEND_DIR, spec.CATEGORIES["fryer"][0])
    fc.save_blend(path)
    log("saved %s (%d objects, node group %s)" % (path, len(bpy.data.objects), BATTER_GROUP in bpy.data.node_groups))
    return path


# ================================================================ main
def main():
    args = fc.cli_args({"oil": False, "batter": False, "save": False, "sheets": False, "batter-input": None,
                        "out": None, "bubble-mesh": False})
    if args["out"]:                       # test runs: keep exports and sheets out of the shared export folder
        spec.EXPORT_DIR = os.path.abspath(args["out"])
        spec.REVIEW_DIR = os.path.join(spec.EXPORT_DIR, "review")
        log("exports redirected to %s" % spec.EXPORT_DIR)
    fc.ensure_dirs()
    fc.clear_scene()
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    ng = build_batter_group()
    keep = []
    summary = {}

    if args["oil"]:
        res = bake_oil(args["sheets"])
        keep += [res["surf"], res["bub"]]
        summary["oil"] = dict(sheet=res["sheet"], pop_sheet=res["pop_sheet"], loop_check=res["meta"]["loop_check"])
    elif args["save"]:
        anim = OilAnim()
        surf, bub, _t, _bt = build_oil_meshes(anim)       # the .blend always carries the rest oil meshes
        keep += [surf, bub]
    if args["oil"] or args["bubble-mesh"]:                # the Niagara bubble dome (no VAT bake involved)
        particle = export_bubble_particle_mesh()
        particle.location = (0.0, 0.6, 0.0)               # beside the disc in the .blend (mesh keeps its pivot)
        keep.append(particle)
        summary["bubble_mesh"] = os.path.join(spec.EXPORT_DIR, "OilBubble_Mars_SM.fbx")

    if args["batter"]:
        jobs = []
        for name, info in spec.INGREDIENTS.items():
            if not info.get("fryable"):
                continue
            path = os.path.join(spec.EXPORT_DIR, spec.mesh_name(name) + ".fbx")
            if os.path.exists(path):
                jobs.append((name, path))
            else:
                log("SKIP %s: %s not found (its builder has not exported it yet)" % (name, path))
        if args["batter-input"]:
            path = os.path.abspath(args["batter-input"])
            stem = os.path.splitext(os.path.basename(path))[0].replace("_Mars_SM", "")
            jobs.append((stem, path))
        for name, path in jobs:
            stats, ing, shell, bat, src_mesh = batter_one(name, path, ng, args["sheets"])
            summary.setdefault("batter", []).append(stats)
            keep += [shell, bat]
            if not any(o.name.startswith("BatterDemo_") for o in keep):
                demo = bpy.data.objects.new("BatterDemo_%s" % name, src_mesh)     # live generator to tweak
                bpy.context.scene.collection.objects.link(demo)
                demo.location = (0.0, -0.5, 0.0)
                add_batter_modifiers(demo, ng, stats["params"], decimate_ratio=stats["decimate_ratio"])
                keep.append(demo)
            remove_object(ing)
            if src_mesh.users == 0:
                bpy.data.meshes.remove(src_mesh)
        if not jobs:
            log("no fryable ingredient FBX found; nothing battered")

    if args["save"]:
        existing = os.path.join(spec.BLEND_DIR, spec.CATEGORIES["fryer"][0])
        if not args["batter"] and os.path.exists(existing):
            keep += carry_batter_objects(existing, ng)
        if not any(o.name.startswith("BatterDemo_") for o in keep):     # the .blend always shows the generator live
            v, f = fc.icosphere(5.0, 3)
            v = v * (1.0 + 0.1 * fc.lumps(v, 5, 0.3))[:, None]
            me = bpy.data.meshes.new("BatterDemo_Sphere")
            me.from_pydata((v * 0.01).tolist(), [], f)
            demo = bpy.data.objects.new("BatterDemo_Sphere", me)
            bpy.context.scene.collection.objects.link(demo)
            demo.location = (0.0, -0.5, 0.05)
            add_batter_modifiers(demo, ng, BATTER_DEFAULTS, decimate_ratio=0.2)
            keep.append(demo)
        summary["blend"] = save_blend(keep)
    print("FRYER_SUMMARY " + json.dumps(summary, default=str))
    print("FOOD_FRYER_OK")


if __name__ == "__main__":
    main()
