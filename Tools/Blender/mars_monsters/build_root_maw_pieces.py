"""Mars Root Maw pieces: the rigid static meshes the Root Maw (a turnip plant monster) is drawn with, cut from Stephen's
supplied model (a Tripo low-poly FBX, 28 textured parts, 2026-11-01), plus the procedural root shapes its Niagara trail
grows, as a re-runnable headless Blender 5.2 build, the way build_pickle_mimic_pieces.py builds the pickle mimic.

The look is Stephen's concept (2026-11-02): a faceted turnip bulb, pink/purple on top and cream below, a crown of big green
leaves, a wide green-lipped maw with big bone teeth, a black cavity with glowing yellow eyes, a skirt of leaves at the base
and a tangle of wooden roots it stands on. Stephen: "you might need to remove the roots portion of the mesh and replace it
entirely with particles". So the roots are cut off the body and dropped; the Niagara root trail (RootMawRoots_Mars_NS) grows
and shrinks four procedural root shapes round the Maw as it moves. (A first cut reused the model's own roots as the particle
meshes; Stephen 2026-11-02: they "look bad - I would think they are individual curves/root shapes that arent related to the
mesh I provided".)

The source is untrusted data: the FBX is imported (geometry, UVs, image paths) and nothing in its folder is run. Each part's
basecolor JPG is sampled into per-face vertex colours for the body (one master, flat faceted colour like the concept). The
roots carry their colour in UV0.x instead (0 at the base, 1 at the tip): a Niagara mesh particle's material reads the
particle's colour, not the mesh's vertex colours, so RootMawRoot_Mars_M grades base -> tip from UV0.x.

Every piece is in UNREAL cm in its own frame (+X the maw's direction, +Y right, +Z up); the source is turned to face +X,
scaled by SIZE and moved so the bulb's axis stands on the origin, the ground (where the roots met it) at z 0. Pieces:

  RootMaw_Lower_Mars_SM    the body below the mouth's corners (CUT_Z): the bulb's cream underside, the lower lip and its
                           teeth, the skirt of leaves. Origin: the ground under the bulb's axis.
  RootMaw_Upper_Mars_SM    the body above CUT_Z: the bulb's pink top, the upper lip and its teeth, the crown of leaves. Pivot
                           at the HINGE on the back of the bulb (+X toward the maw): the jaw turns about its +Y axis (a
                           positive pitch in Unreal lifts it), JAW_SHUT_DEG (teeth meeting) .. JAW_WIDE_DEG (gaping); 0 is
                           the model's own mouth (JawOpen JAW_REST).
  RootMaw_Throat_Mars_SM   the black cavity behind the teeth with the eyes on it (slot RootMawEye: the glow), body frame;
                           it stays with the lower body, so the eyes hold still in the gaping maw.
  RootMaw_Root0..3_Mars_SM four procedural roots (ROOT_SPECS): a faceted six-sided tube tapering along a curve that
                           comes up out of the ground at the pivot (the origin, on the ground), arches outward along +X
                           and dips back into the ground at its tip, some forked. Grown from scale 0 about the pivot it
                           pushes out of the ground and reaches outward.

Material slots (Unreal binds <Slot>_Mars_MI): RootMawSkin (vertex colour, two-sided: the cut bulb shows its dark inside),
RootMawEye (vertex colour x Emissive x Glow, custom primitive data 0), RootMawRoot (the roots: base -> tip colour from UV0.x,
for Niagara mesh particles).

Run:
  blender -b --factory-startup --python build_root_maw_pieces.py -- [--export] [--sheets] [--save]
    --export   one FBX and a .json sidecar per piece into EXPORT_DIR, the rest layout JSON,
               then a re-import check of every FBX
    --sheets   review renders into REVIEW_DIR: every piece alone (front / side / top / iso), the assembled Maw at rest, gaping,
               shut and buried, and the root trail as the particles would grow it
    --save     BLEND_FILE (the pieces at the origin + the posed previews)
Prints ROOT_MAW_PIECES_OK when every check passed (ROOT_MAW_PIECES_FAIL + the reasons otherwise).
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix

# ---------------------------------------------------------------- locations
SOURCE_DIR = r"D:\Repo\Content\Monsters\RootMaw"           # off-repo art, like D:\Repo\Content\Monsters\PickleMimic
SOURCE_FBX = SOURCE_DIR + r"\source\low-poly_plant_monster_3d_model_Clone1.fbx"
EXPORT_DIR = SOURCE_DIR + r"\export"
REVIEW_DIR = EXPORT_DIR + r"\review"
BLEND_FILE = SOURCE_DIR + r"\RootMaw_Pieces.blend"
UE_MESH_FOLDER = "/Game/Mars/Gameplay/Monsters/RootMaw/Meshes"
BUILDER = "Tools/Blender/mars_monsters/build_root_maw_pieces.py"

# ---------------------------------------------------------------- the source's parts (tripo_part_<n>)
LIPS, BULB, CAVITY = 0, 1, 21
CROWN = (2, 3, 4, 5, 6, 14, 18, 20)                 # the leaves on top and the stem knob: they lift with the jaw
SKIRT = (8, 13, 15, 16)                             # the leaves round the base
ROOTS = (7, 9, 10, 11, 12, 17, 19, 22, 23, 24, 25, 26, 27)   # dropped; 7 is the knot under the bulb (with a few leaf scraps)

# ---------------------------------------------------------------- the body (Unreal cm; origin = the ground under the bulb)
SIZE = 1.3                                          # the source stands 1 m (roots to leaf tip): the Maw stands 130 cm
CUT_Z = 57.5                                        # the mouth's corners: above is the jaw, below the body
HINGE = np.array([-27.0, 0.0, CUT_Z])               # on the back of the bulb (its back is x -29.5)
JAW_SHUT_DEG = -10.0                                # the teeth meet (the jaw turns down about the hinge)
JAW_WIDE_DEG = 32.0                                 # gaping
JAW_REST = -JAW_SHUT_DEG / (JAW_WIDE_DEG - JAW_SHUT_DEG)     # JawOpen at the model's own mouth (0 deg)
BURY_DROP = 78.0                                    # buried: only the bulb's pink shoulder and the crown show
BITE_MOUTH = np.array([40.0, 0.0, CUT_Z])           # the maw's front edge: the bite's blow centre
EYE_LUMA = 0.45                                     # a throat face this bright (sRGB luma) is an eye

TRIS_MAX = {"Lower": 6000, "Upper": 9600, "Throat": 800}
ROOT_TRIS_MAX = 600
# The particle roots (Unreal cm, pivot on the ground, +X outward): length along X, the arch's height, where the tip ends
# (below 0: back into the ground), the base and tip radii, the sideways wander, and forks (where along the root, the yaw off
# it in degrees, the fork's share of the root's length).
ROOT_SPECS = (
    dict(length=46.0, rise=13.0, dip=-3.0, r0=6.0, r1=1.1, wander=4.0, phase=0.3, forks=((0.42, 38.0, 0.45),)),
    dict(length=33.0, rise=17.0, dip=-2.5, r0=5.6, r1=1.1, wander=2.5, phase=2.1, forks=()),
    dict(length=55.0, rise=8.0, dip=-2.0, r0=5.0, r1=1.0, wander=6.0, phase=4.0, forks=((0.33, -42.0, 0.4), (0.6, 30.0, 0.28))),
    dict(length=27.0, rise=10.0, dip=-3.0, r0=4.6, r1=1.0, wander=5.0, phase=5.2, forks=((0.5, -35.0, 0.35),)),
)
ROOT_SIDES = 6
ROOT_SEGMENTS = 12
ROOT_BASE_DEPTH = 2.5                               # the base starts this far under the ground
# base -> tip colours (sRGB), the concept's wooden roots; RootMawRoot_Mars_M carries the same numbers (linear)
ROOT_BASE_SRGB = (74, 46, 28)
ROOT_TIP_SRGB = (198, 140, 82)
PIECES = ("Lower", "Upper", "Throat")
ROOT_NAMES = tuple("Root%d" % k for k in range(len(ROOT_SPECS)))
SLOTS = ("RootMawSkin", "RootMawEye", "RootMawRoot")
PREVIEW = {"RootMawSkin": ((0.6, 0.5, 0.4), 0.7, 0.0), "RootMawEye": ((1.0, 0.8, 0.35), 0.4, 6.0)}
MIRROR = np.diag([1.0, -1.0, 1.0])


def piece_name(part):
    return "RootMaw_%s_Mars_SM" % part


# ---------------------------------------------------------------- CLI / scene
def cli_args(defaults):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = dict(defaults)
    for a in argv:
        out[a.lstrip("-")] = True
    return out


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.cameras, bpy.data.lights):
        for d in list(coll):
            if d.users == 0:
                coll.remove(d)


def _ue_to_bl(v):
    return MIRROR @ np.asarray(v, float)


# ---------------------------------------------------------------- the source
def _basecolor(obj):
    """The part's basecolor image (its material's image texture named *_basecolor*)."""
    for mat in obj.data.materials:
        if mat is None or mat.node_tree is None:
            continue
        for node in mat.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image is not None and "basecolor" in node.image.name.lower():
                return node.image
    return None


def import_source():
    """The source's parts, by index, turned to face +X, scaled by SIZE and stood on the bulb's axis (Blender metres)."""
    if not os.path.isfile(SOURCE_FBX):
        raise RuntimeError("no source FBX at %s (extract Stephen's zip there)" % SOURCE_FBX)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=SOURCE_FBX)
    parts = {}
    for o in bpy.data.objects:
        if o in before or o.type != "MESH" or not o.name.startswith("tripo_part_"):
            continue
        parts[int(o.name.rsplit("_", 1)[1])] = o
    turn = Matrix.Diagonal((SIZE, SIZE, SIZE, 1.0)) @ Matrix.Rotation(math.radians(90.0), 4, "Z")
    for o in parts.values():
        o.data.transform(turn @ o.matrix_world)
        o.matrix_world = Matrix.Identity(4)
    bulb = np.array([v.co[:] for v in parts[BULB].data.vertices])
    axis = 0.5 * (bulb.min(axis=0) + bulb.max(axis=0))
    shift = Matrix.Translation((-axis[0], -axis[1], 0.0))
    for o in parts.values():
        o.data.transform(shift)
    for o in list(bpy.data.objects):
        if o not in before and o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    return parts


def _srgb_to_linear(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def face_colours(obj):
    """Each face's colour (sRGB, as painted): its basecolor sampled at the face's centroid and halfway to each corner."""
    img = _basecolor(obj)
    me = obj.data
    nf = len(me.polygons)
    if img is None:
        return np.full((nf, 3), 0.5)
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)[:, :, :3]
    uv = np.empty(len(me.loops) * 2)
    me.uv_layers[0].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    out = np.empty((nf, 3))
    for p in me.polygons:
        corners = uv[p.loop_start:p.loop_start + p.loop_total]
        c = corners.mean(axis=0)
        pts = np.vstack([c[None, :], 0.5 * (corners + c)])
        x = np.clip((pts[:, 0] % 1.0) * w, 0, w - 1).astype(int)
        y = np.clip((pts[:, 1] % 1.0) * h, 0, h - 1).astype(int)
        out[p.index] = px[y, x].mean(axis=0)
    return out


def paint(obj, srgb):
    """Per-face colours as a corner colour attribute "Col" in LINEAR values (exported with colors_type LINEAR; the
    masters read VertexColor as linear albedo, the Mars painted-mesh convention)."""
    me = obj.data
    for a in list(me.color_attributes):
        me.color_attributes.remove(a)
    attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    lin = _srgb_to_linear(np.asarray(srgb, float))
    lt = np.empty(len(me.polygons), np.int64)
    me.polygons.foreach_get("loop_total", lt)
    rgba = np.hstack([np.repeat(lin, lt, axis=0), np.ones((int(lt.sum()), 1))])
    attr.data.foreach_set("color", rgba.ravel())
    me.color_attributes.active_color = attr


# ---------------------------------------------------------------- mesh assembly
class Geo:
    """Faces gathered from source parts: Blender-metre vertices, per-face slot and sRGB colour, per-corner UVs."""

    def __init__(self):
        self.v, self.f, self.s, self.c, self.uv = [], [], [], [], []

    def add(self, obj, faces, slots, colours, offset=(0.0, 0.0, 0.0), matrix=None):
        me = obj.data
        co = np.array([v.co[:] for v in me.vertices]) - np.asarray(offset, float)
        if matrix is not None:
            co = co @ np.asarray(matrix, float).T
        uvl = me.uv_layers[0].data if me.uv_layers else None
        remap = {}
        for k, fi in enumerate(faces):
            p = me.polygons[fi]
            idx = []
            for vi in p.vertices:
                if vi not in remap:
                    remap[vi] = len(self.v)
                    self.v.append(co[vi])
                idx.append(remap[vi])
            self.f.append(idx)
            self.s.append(slots[k] if isinstance(slots, (list, tuple)) else slots)
            self.c.append(colours[fi])
            self.uv.append([tuple(uvl[li].uv) if uvl else (0.0, 0.0) for li in p.loop_indices])


def to_object(name, geo, slot_order):
    """A flat-shaded triangulated mesh object at the origin: the used slots in slot_order, UVMap from the source, "Col"."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(np.asarray(geo.v, float).tolist(), [], geo.f)
    used = [s for s in slot_order if s in set(geo.s)]
    for s in used:
        mesh.materials.append(preview_material(s))
    mesh.polygons.foreach_set("material_index", [used.index(s) for s in geo.s])
    uv = mesh.uv_layers.new(name="UVMap")
    uv.data.foreach_set("uv", np.array([c for face in geo.uv for c in face], float).ravel())
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    paint(obj, np.asarray(geo.c, float))
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
    bm.to_mesh(mesh)
    bm.free()
    mesh.polygons.foreach_set("use_smooth", [False] * len(mesh.polygons))
    mesh.validate(verbose=False)
    mesh.update()
    return obj


def preview_material(slot):
    mat = bpy.data.materials.get(slot) or bpy.data.materials.new(slot)
    rgb, rough, emis = PREVIEW.get(slot, ((0.45, 0.3, 0.18), 0.8, 0.0))
    mat.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    mat.roughness = rough
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is not None:
        attr = nt.nodes.get("Col") or nt.nodes.new("ShaderNodeVertexColor")
        attr.name = "Col"
        attr.layer_name = "Col"
        nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = rough
        if emis > 0.0:
            nt.links.new(attr.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = emis
    return mat


# ---------------------------------------------------------------- the pieces
def face_centres(obj):
    me = obj.data
    c = np.empty(len(me.polygons) * 3)
    me.polygons.foreach_get("center", c)
    return c.reshape(-1, 3) * 100.0


def build_body(parts, colours):
    """Lower, Upper (in the hinge's frame) and Throat Geos, and what went where."""
    lower, upper, throat = Geo(), Geo(), Geo()
    hinge_bl = _ue_to_bl(HINGE) * 0.01
    split = {}
    for idx in (LIPS, BULB):
        o = parts[idx]
        z = face_centres(o)[:, 2]
        up = [i for i in range(len(z)) if z[i] >= CUT_Z]
        down = [i for i in range(len(z)) if z[i] < CUT_Z]
        upper.add(o, up, "RootMawSkin", colours[idx], offset=hinge_bl)
        lower.add(o, down, "RootMawSkin", colours[idx])
        split[idx] = {"upper": len(up), "lower": len(down)}
    for idx in CROWN:
        o = parts[idx]
        upper.add(o, range(len(o.data.polygons)), "RootMawSkin", colours[idx], offset=hinge_bl)
    for idx in SKIRT:
        o = parts[idx]
        lower.add(o, range(len(o.data.polygons)), "RootMawSkin", colours[idx])
    o = parts[CAVITY]
    col = colours[CAVITY]
    luma = col @ np.array([0.2126, 0.7152, 0.0722])
    eyes = [bool(l >= EYE_LUMA) for l in luma]
    throat.add(o, range(len(o.data.polygons)), ["RootMawEye" if e else "RootMawSkin" for e in eyes], col)
    split["eyes"] = int(sum(eyes))
    return {"Lower": lower, "Upper": upper, "Throat": throat}, split


def _root_curve(spec, n):
    """The root's centre line (Unreal cm) at n + 1 samples s in [0, 1]: up out of the ground, an arch outward, the tip
    back into the ground, wandering sideways."""
    t = np.linspace(0.0, 1.0, n + 1)
    x = spec["length"] * t
    y = spec["wander"] * np.sin(2.0 * np.pi * (0.8 * t) + spec["phase"]) * t
    z = -ROOT_BASE_DEPTH * (1.0 - t) ** 3 + spec["rise"] * np.sin(np.pi * t) ** 1.2 * (1.0 - 0.3 * t) + spec["dip"] * t ** 3
    return t, np.stack([x, y, z], axis=1)


def _tube(geo, pts, radii, u, rng, base_cap):
    """A faceted tube (ROOT_SIDES) along pts (Unreal cm), radius radii, collapsing to a point at the end; UV0.x = u, the
    preview colour graded base -> tip on u. Faces wound outward."""
    n = len(pts)
    tang = np.gradient(pts, axis=0)
    tang /= np.linalg.norm(tang, axis=1, keepdims=True)
    normal = np.cross(tang[0], [0.0, 0.0, 1.0])
    if np.linalg.norm(normal) < 1e-6:
        normal = np.array([0.0, 1.0, 0.0])
    normal /= np.linalg.norm(normal)
    rings = []
    for i in range(n):
        if i > 0:
            normal = normal - tang[i] * normal.dot(tang[i])
            normal /= np.linalg.norm(normal)
        binormal = np.cross(tang[i], normal)
        if i == n - 1:
            rings.append([len(geo.v)])
            geo.v.append(_ue_to_bl(pts[i]) * 0.01)
            continue
        ring = []
        for k in range(ROOT_SIDES):
            a = 2.0 * np.pi * k / ROOT_SIDES
            r = radii[i] * (1.0 + rng.normal(0.0, 0.08))
            ring.append(len(geo.v))
            geo.v.append(_ue_to_bl(pts[i] + r * (np.cos(a) * normal + np.sin(a) * binormal)) * 0.01)
        rings.append(ring)
    base = np.array(ROOT_BASE_SRGB, float) / 255.0
    tip = np.array(ROOT_TIP_SRGB, float) / 255.0

    def face(idx, centre, uu):
        vs = [np.asarray(geo.v[j]) for j in idx]
        nrm = np.cross(vs[1] - vs[0], vs[2] - vs[0])
        if nrm.dot(np.mean(vs, axis=0) - _ue_to_bl(centre) * 0.01) < 0.0:
            idx = list(reversed(idx))
        geo.f.append(idx)
        geo.s.append("RootMawRoot")
        geo.c.append(np.clip((base + (tip - base) * uu ** 0.8) * rng.uniform(0.93, 1.06), 0.0, 1.0))
        geo.uv.append([(uu, 0.5)] * len(idx))

    for i in range(n - 1):
        r0, r1 = rings[i], rings[i + 1]
        uu = 0.5 * (u[i] + u[i + 1])
        c = 0.5 * (pts[i] + pts[i + 1])
        for k in range(ROOT_SIDES):
            k1 = (k + 1) % ROOT_SIDES
            if len(r1) == 1:
                face([r0[k], r0[k1], r1[0]], c, uu)
            else:
                face([r0[k], r0[k1], r1[k1], r1[k]], c, uu)
    if base_cap:
        face(list(rings[0]), pts[0] + tang[0] * 2.0, u[0])


def build_roots():
    """ROOT_SPECS as Geos (Blender metres): a main tube and its forks per root, seeded per root."""
    geos, frames = {}, {}
    for k, spec in enumerate(ROOT_SPECS):
        rng = np.random.default_rng(7700 + k)
        g = Geo()
        t, pts = _root_curve(spec, ROOT_SEGMENTS)
        radii = spec["r0"] * (1.0 - t) ** 0.85 + spec["r1"] * t
        radii *= 1.0 + 0.1 * np.sin(t * 17.0 + k)
        _tube(g, pts, radii, t, rng, base_cap=True)
        for at, yaw, share in spec["forks"]:
            i0 = int(round(at * ROOT_SEGMENTS))
            heading = pts[min(i0 + 1, ROOT_SEGMENTS)] - pts[i0]
            ang = math.atan2(heading[1], heading[0]) + math.radians(yaw)
            fs = np.linspace(0.0, 1.0, 7)
            flen = spec["length"] * share
            fp = pts[i0] + np.stack([np.cos(ang) * flen * fs, np.sin(ang) * flen * fs,
                                     spec["rise"] * 0.35 * np.sin(np.pi * fs) - (pts[i0][2] + 1.5) * fs ** 2], axis=1)
            fr = radii[i0] * 0.62 * (1.0 - fs) ** 0.85 + spec["r1"] * fs
            _tube(g, fp, fr, at + (1.0 - at) * fs, rng, base_cap=False)
        geos[ROOT_NAMES[k]] = g
        frames[ROOT_NAMES[k]] = {k2: (list(v) if isinstance(v, tuple) else v) for k2, v in spec.items()}
    return geos, frames


# ---------------------------------------------------------------- measures
def ue_verts(obj):
    n = len(obj.data.vertices)
    co = np.empty(n * 3)
    obj.data.vertices.foreach_get("co", co)
    return co.reshape(n, 3) * 100.0 * np.array([1.0, -1.0, 1.0])


def ue_bounds(obj):
    v = ue_verts(obj)
    return v.min(axis=0), v.max(axis=0)


def tri_count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


# ---------------------------------------------------------------- export
def export_fbx(obj, extra=None):
    os.makedirs(EXPORT_DIR, exist_ok=True)
    path = os.path.join(EXPORT_DIR, obj.name + ".fbx")
    for o in bpy.context.scene.objects:
        o.select_set(o is obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, mesh_smooth_type="FACE",
                             use_mesh_modifiers=True, add_leaf_bones=False, bake_anim=False, use_tspace=False,
                             apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y",
                             use_triangles=True, path_mode="STRIP", colors_type="LINEAR")
    lo, hi = ue_bounds(obj)
    meta = {"name": obj.name, "builder": BUILDER, "ue_folder": UE_MESH_FOLDER,
            "slots": [m.name for m in obj.data.materials], "tris": tri_count(obj),
            "bounds_cm": {"min": [round(float(x), 3) for x in lo], "max": [round(float(x), 3) for x in hi]},
            "frame": "Unreal local cm: +X the maw's direction, +Y right, +Z up"}
    meta.update(extra or {})
    with open(os.path.splitext(path)[0] + ".json", "w") as fh:
        json.dump(meta, fh, indent=1)
    print("exported %-28s tris %5d  bounds %s .. %s" % (obj.name, meta["tris"], meta["bounds_cm"]["min"],
                                                        meta["bounds_cm"]["max"]))
    return path


def reimport_check(path, obj):
    fails = []
    before = set(bpy.data.objects)
    mats_before = set(bpy.data.materials)
    bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    if len(meshes) != 1:
        fails.append("%s reimport: %d meshes" % (obj.name, len(meshes)))
    else:
        m = meshes[0]
        co = np.array([(m.matrix_world @ vv.co)[:] for vv in m.data.vertices]) * 100.0
        src = ue_verts(obj) * np.array([1.0, -1.0, 1.0])
        err = float(np.abs(np.concatenate([co.min(axis=0) - src.min(axis=0), co.max(axis=0) - src.max(axis=0)])).max())
        m.data.calc_loop_triangles()
        if len(m.data.loop_triangles) != tri_count(obj):
            fails.append("%s reimport tris %d != %d" % (obj.name, len(m.data.loop_triangles), tri_count(obj)))
        if err > 0.05:
            fails.append("%s reimport bounds off by %.3f cm" % (obj.name, err))
        if not m.data.color_attributes:
            fails.append("%s reimport lost its vertex colours" % obj.name)
        slots = [mm.name.split(".")[0] if mm else None for mm in m.data.materials]
        if slots != [mm.name for mm in obj.data.materials]:
            fails.append("%s reimport slots %s" % (obj.name, slots))
    for o in new:
        data = o.data if o.type == "MESH" else None
        bpy.data.objects.remove(o, do_unlink=True)
        if data is not None and data.users == 0:
            bpy.data.meshes.remove(data)
    for mm in list(bpy.data.materials):
        if mm not in mats_before and mm.users == 0:
            bpy.data.materials.remove(mm)
    return fails


# ---------------------------------------------------------------- posed previews
def jaw_degrees(jaw_open):
    return JAW_SHUT_DEG + (JAW_WIDE_DEG - JAW_SHUT_DEG) * jaw_open


def ue_matrix(yaw_deg=0.0, pitch_up_deg=0.0, loc_cm=(0.0, 0.0, 0.0), scale=1.0):
    """A Blender world matrix for an Unreal placement: yaw about Z (Unreal: +Y right), then the jaw's lift (a turn about
    the frame's Y that raises +X), at loc (Unreal cm)."""
    loc = _ue_to_bl(loc_cm) * 0.01
    # Unreal yaw +a turns +X toward +Y (right); Unreal +Y is Blender -Y, so that is a Blender turn of -a about Z
    m = Matrix.Translation(loc) @ Matrix.Rotation(math.radians(-yaw_deg), 4, "Z") @ \
        Matrix.Rotation(math.radians(-pitch_up_deg), 4, "Y") @ Matrix.Diagonal((scale, scale, scale, 1.0))
    return m


def pose(objs, name, jaw_open=JAW_REST, drop=0.0, offset=(0.0, 0.0, 0.0)):
    out = []
    base = np.asarray(offset, float) + np.array([0.0, 0.0, -drop])
    for part in PIECES:
        o = objs[part].copy()
        o.name = "%s_%s" % (name, part)
        bpy.context.scene.collection.objects.link(o)
        if part == "Upper":
            o.matrix_world = ue_matrix(loc_cm=base + HINGE) @ ue_matrix(pitch_up_deg=jaw_degrees(jaw_open))
        else:
            o.matrix_world = ue_matrix(loc_cm=base)
        out.append(o)
    return out


def ground(name, centre_cm, half_cm, z_cm=0.0):
    me = bpy.data.meshes.new(name)
    c, h = np.asarray(centre_cm, float), float(half_cm)
    v = [(c[0] - h, -(c[1] - h), z_cm), (c[0] + h, -(c[1] - h), z_cm), (c[0] + h, -(c[1] + h), z_cm), (c[0] - h, -(c[1] + h), z_cm)]
    me.from_pydata([tuple(np.asarray(p) * 0.01) for p in v], [], [(0, 1, 2, 3)])
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    paint(o, np.array([[0.36, 0.33, 0.30]]))
    return o


def root_scale(age):
    """The particle's life curve as RootMawRoots_Mars_NS has it by default: in over the first 15 % (ease out), holds,
    out after 55 % (ease in)."""
    if age < 0.15:
        a = age / 0.15
        return 1.0 - (1.0 - a) ** 2
    if age < 0.55:
        return 1.0
    a = (age - 0.55) / 0.45
    return max(0.0, 1.0 - a * a)


def head_scale(away_cm):
    """The particle's size by its distance from the head (NearScale 1.5 within BedRadius 24, FarScale 0.45 by FarRadius 110,
    smoothstep between), as RootMawRoots_Mars_NS has it by default."""
    t = min(max((away_cm - 24.0) / (110.0 - 24.0), 0.0), 1.0)
    t = t * t * (3.0 - 2.0 * t)
    return 1.5 + (0.45 - 1.5) * t


def root_bed(objs, name, head_cm, count, rng, spawn_cm=None, ages=None):
    """count particle roots as the trail would hold them: each spawned in the bed (a filled 24 cm disc) round spawn_cm (the
    head's place when it grew; default the head), +X outward from there (jittered), sized by its life curve and its
    distance from the head now, twisted away as it goes."""
    out = []
    centre = np.asarray(spawn_cm if spawn_cm is not None else head_cm, float)
    for k in range(count):
        ang = rng.uniform(0.0, 360.0)
        rad = 24.0 * math.sqrt(rng.uniform())
        age = ages[k] if ages is not None else rng.uniform(0.2, 0.55)
        loc = centre + rad * np.array([math.cos(math.radians(ang)), math.sin(math.radians(ang)), 0.0])
        away = float(np.hypot(*(loc - np.asarray(head_cm, float))[:2]))
        s = rng.uniform(0.75, 1.25) * root_scale(age) * head_scale(away)
        if s < 0.03:
            continue
        twist = 0.0 if age < 0.55 else 80.0 * ((age - 0.55) / 0.45) ** 2
        o = objs[ROOT_NAMES[int(rng.integers(len(ROOT_NAMES)))]].copy()
        o.name = "%s_%02d" % (name, k)
        bpy.context.scene.collection.objects.link(o)
        o.matrix_world = ue_matrix(yaw_deg=ang + rng.uniform(-30.0, 30.0) + twist, loc_cm=loc, scale=s)
        out.append(o)
    return out


# ---------------------------------------------------------------- renders
def _look_at(cam, eye, target):
    f = np.array(target, float) - np.array(eye, float)
    cam.location = eye
    cam.rotation_euler = (math.atan2(math.hypot(f[0], f[1]), -f[2]), 0.0, -math.atan2(f[0], f[1]))


def _n(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-12)


def render_workbench(objs, path, view_ue, target_ue_cm, half_width_cm, size=(700, 600), ortho=True):
    scene = bpy.context.scene
    others = [o for o in scene.objects if o.type == "MESH" and o not in objs]
    state = [o.hide_render for o in others]
    cam_data = bpy.data.cameras.new("_ReviewCam")
    cam_data.type = "ORTHO" if ortho else "PERSP"
    cam_data.ortho_scale = half_width_cm * 0.02
    cam_data.lens = 50.0
    cam_data.clip_start, cam_data.clip_end = 0.01, 200.0
    cam = bpy.data.objects.new("_ReviewCam", cam_data)
    scene.collection.objects.link(cam)
    try:
        for o in others:
            o.hide_render = True
        for o in objs:
            o.hide_render = False
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "VERTEX"
        scene.display.shading.show_cavity = False
        scene.display.shading.show_object_outline = False
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        scene.render.film_transparent = False
        d = _n(_ue_to_bl(view_ue))
        t = _ue_to_bl(target_ue_cm) * 0.01
        dist = 30.0 if ortho else half_width_cm * 0.02 / (36.0 / 50.0) * 1.2
        _look_at(cam, tuple(t + d * dist), tuple(t))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
    finally:
        for o, s in zip(others, state):
            o.hide_render = s
        bpy.data.objects.remove(cam)
        bpy.data.cameras.remove(cam_data)
    return path


def tile_images(paths, out_path, cols=2):
    imgs = [bpy.data.images.load(p) for p in paths]
    w, h = imgs[0].size
    rows = (len(imgs) + cols - 1) // cols
    sheet = np.zeros((rows * h, cols * w, 4), np.float32)
    for i, img in enumerate(imgs):
        px = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(px)
        r, c = divmod(i, cols)
        r = rows - 1 - r
        sheet[r * h:(r + 1) * h, c * w:(c + 1) * w] = px.reshape(h, w, 4)
        bpy.data.images.remove(img)
    out = bpy.data.images.new(os.path.basename(out_path), cols * w, rows * h, alpha=True)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    for p in paths:
        try:
            os.remove(p)
        except OSError:
            pass
    return out_path


PIECE_VIEWS = (("front", (1.0, 0.0, 0.0)), ("side", (0.0, 1.0, 0.0)), ("top", (0.0, 0.001, 1.0)),
               ("iso", (0.9, 0.8, 0.6)))


def render_piece_sheets(objs):
    os.makedirs(REVIEW_DIR, exist_ok=True)
    out = []
    for part in PIECES:
        o = objs[part]
        lo, hi = ue_bounds(o)
        c = 0.5 * (lo + hi)
        half = float((hi - lo).max()) * 0.62
        paths = [render_workbench([o], os.path.join(REVIEW_DIR, "_%s_%s.png" % (part, k)), v, c, half)
                 for k, v in PIECE_VIEWS]
        out.append(tile_images(paths, os.path.join(REVIEW_DIR, "RootMaw_%s_sheet.png" % part)))
    paths = []
    for name in ROOT_NAMES:
        o = objs[name]
        lo, hi = ue_bounds(o)
        c = 0.5 * (lo + hi)
        half = float((hi - lo).max()) * 0.7
        paths += [render_workbench([o], os.path.join(REVIEW_DIR, "_%s_%s.png" % (name, k)), v, c, half, size=(420, 360))
                  for k, v in (("side", (0.0, 1.0, 0.0)), ("top", (0.0, 0.001, 1.0)), ("iso", (0.9, 0.8, 0.6)))]
    out.append(tile_images(paths, os.path.join(REVIEW_DIR, "RootMaw_Roots_sheet.png"), cols=3))
    return out


def render_layout_sheet(groups):
    paths = []
    for name, objs, view, target, half in groups:
        paths.append(render_workbench(objs, os.path.join(REVIEW_DIR, "_layout_%s.png" % name), view, target, half,
                                      size=(800, 700), ortho=False))
    return tile_images(paths, os.path.join(REVIEW_DIR, "RootMaw_layout_sheet.png"), cols=3)


# ---------------------------------------------------------------- checks
def contract_checks(objs, split):
    fails = []
    lo, hi = ue_bounds(objs["Lower"])
    if hi[2] > CUT_Z + 25.0:
        fails.append("Lower reaches z %.1f: something above the cut stayed on the body" % hi[2])
    if lo[2] < 0.0:
        fails.append("Lower dips below the ground (z %.1f)" % lo[2])
    ulo, uhi = ue_bounds(objs["Upper"])
    if ulo[2] < -12.0:
        fails.append("Upper hangs %.1f below its hinge: something under the cut went with the jaw" % ulo[2])
    if split.get("eyes", 0) < 4:
        fails.append("the throat has %d eye faces (EYE_LUMA %.2f)" % (split.get("eyes", 0), EYE_LUMA))
    for name in ROOT_NAMES:
        rlo, rhi = ue_bounds(objs[name])
        if rlo[2] < -ROOT_BASE_DEPTH - 6.0 or rlo[0] < -8.0 or rhi[0] < 15.0:
            fails.append("%s is not pivoted at its inner end on the ground (min %s max %s)" % (name, rlo.round(1), rhi.round(1)))
    return fails


def main():
    args = cli_args({"export": False, "sheets": False, "save": False})
    clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    fails = []
    parts = import_source()
    missing = [i for i in (LIPS, BULB, CAVITY) + CROWN + SKIRT + ROOTS if i not in parts]
    if missing:
        raise RuntimeError("the source has no tripo_part %s" % missing)
    unused = sorted(set(parts) - set((LIPS, BULB, CAVITY) + CROWN + SKIRT + ROOTS))
    if unused:
        fails.append("source parts not assigned to anything: %s" % unused)
    colours = {i: face_colours(o) for i, o in parts.items()}

    body, split = build_body(parts, colours)
    root_geos, root_frames = build_roots()
    for o in parts.values():
        bpy.data.objects.remove(o, do_unlink=True)

    objs, report = {}, {}
    for part in PIECES:
        objs[part] = to_object(piece_name(part), body[part], SLOTS)
    for name in ROOT_NAMES:
        objs[name] = to_object(piece_name(name), root_geos[name], SLOTS)
    for name, o in objs.items():
        lo, hi = ue_bounds(o)
        tris = tri_count(o)
        report[name] = {"tris": tris, "min": np.round(lo, 2).tolist(), "max": np.round(hi, 2).tolist(),
                        "slots": [m.name for m in o.data.materials]}
        print("%-26s tris %5d  min %s  max %s  slots %s" % (o.name, tris, np.round(lo, 1).tolist(), np.round(hi, 1).tolist(),
                                                           report[name]["slots"]))
        cap = TRIS_MAX.get(name, ROOT_TRIS_MAX)
        if tris > cap:
            fails.append("%s has %d tris > %d" % (o.name, tris, cap))
    print("split", split)
    fails += contract_checks(objs, split)

    exported = []
    if args["export"]:
        for part in PIECES:
            exported.append((export_fbx(objs[part]), part))
        for name in ROOT_NAMES:
            exported.append((export_fbx(objs[name], {"spec": root_frames[name]}), name))
        lay = {"builder": BUILDER, "source": SOURCE_FBX, "size": SIZE,
               "frame": "Unreal cm; the ground under the bulb's axis at the origin; the Upper piece pivots at hinge",
               "cut_z": CUT_Z, "hinge": HINGE.tolist(), "jaw_shut_deg": JAW_SHUT_DEG, "jaw_wide_deg": JAW_WIDE_DEG,
               "jaw_rest": JAW_REST, "bury_drop": BURY_DROP, "bite_mouth": BITE_MOUTH.tolist(), "split": split,
               "roots": root_frames, "pieces": report}
        with open(os.path.join(EXPORT_DIR, "RootMaw_RestLayout.json"), "w") as fh:
            json.dump(lay, fh, indent=1)

    sheets = []
    if args["sheets"] or args["save"]:
        rng = np.random.default_rng(4242)
        rest = pose(objs, "Rest") + root_bed(objs, "RestRoots", (0.0, 0.0, 0.0), 18, rng)
        gape = pose(objs, "Gape", jaw_open=1.0) + root_bed(objs, "GapeRoots", (0.0, 0.0, 0.0), 18, rng)
        shut = pose(objs, "Shut", jaw_open=0.0) + root_bed(objs, "ShutRoots", (0.0, 0.0, 0.0), 18, rng)
        buried = pose(objs, "Buried", jaw_open=0.0, drop=BURY_DROP) + [ground("BuriedGround", (0.0, 0.0, 0.0), 120.0)]
        # the trail: the Maw has glided +X; roots spawned along its path are older the further behind they lie
        trail = pose(objs, "Trail", offset=(0.0, 0.0, 0.0))
        trail += root_bed(objs, "TrailHead", (0.0, 0.0, 0.0), 10, rng)
        for k, back in enumerate(np.linspace(8.0, 260.0, 30)):
            # one root per 8 cm of travel; at 190 cm/s the root at `back` grew back / 190 s ago (life 3 s)
            age = min(0.05 + back / 190.0 / 3.0, 0.99)
            trail += root_bed(objs, "Trail%02d" % k, (0.0, 0.0, 0.0), 1, rng, spawn_cm=(-back, 0.0, 0.0), ages=[age])
        trail.append(ground("TrailGround", (-110.0, 0.0, 0.0), 190.0, z_cm=-0.3))
        if args["sheets"]:
            sheets = render_piece_sheets(objs)
            sheets.append(render_layout_sheet((
                ("rest", rest, (1.0, -0.75, 0.45), (0.0, 0.0, 60.0), 85.0),
                ("gape", gape, (1.0, 0.6, 0.3), (0.0, 0.0, 65.0), 85.0),
                ("shut", shut, (0.15, -1.0, 0.2), (0.0, 0.0, 60.0), 85.0),
                ("buried", buried, (1.0, -0.8, 0.45), (0.0, 0.0, 15.0), 85.0),
                ("trail", trail, (0.45, -1.0, 0.75), (-90.0, 0.0, 20.0), 140.0),
                ("back", rest, (-1.0, 0.5, 0.35), (0.0, 0.0, 60.0), 85.0))))
    if args["save"]:
        os.makedirs(SOURCE_DIR, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=BLEND_FILE, copy=False)
        print("saved", BLEND_FILE)
    for path, part in exported:
        fails += reimport_check(path, objs[part])
    print("ROOT_MAW_REPORT " + json.dumps(report))
    if sheets:
        print("sheets:", *sheets, sep="\n  ")
    if fails:
        print("ROOT_MAW_PIECES_FAIL", *fails, sep="\n  ")
    else:
        print("ROOT_MAW_PIECES_OK")


if __name__ == "__main__":
    main()
