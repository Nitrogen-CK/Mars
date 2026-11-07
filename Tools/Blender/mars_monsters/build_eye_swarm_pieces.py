"""Mars eye swarm pieces: the meshes the "many eyes" system draws (eyes scattered over a creature or a wall, each its own
instanced mesh; the shader does everything else), as a re-runnable headless Blender 5.2 build, the way
build_root_maw_pieces.py builds the Root Maw.

The meshes are a CONTRACT with the eye shader (CkUsf generated looks), so every number below is load-bearing. All three
pieces share one pivot (the eye's centre) and one frame, Unreal local cm: +X forward (the gaze), +Y right, +Z up.

  EyeSwarm_Eyeball_Mars_SM  a faceted icosphere (the icosahedron subdivided twice: 320 tris, 162 vertices), radius
                            EYE_RADIUS 5.0 cm round the pivot, a vertex on +X (the gaze: the pupil's facets fan round it),
                            flat shaded, one slot `Eyeball`.
  EyeSwarm_Eyelid_Mars_SM   the same icosphere at LID_RADIUS 5.5 cm (its facets line up with the eyeball's), the FULL
                            sphere (the shader cuts the opening with an opacity mask: there is no hole), normals outward,
                            flat shaded, one slot `Eyelid`. Its faces' inradius stays above EYE_RADIUS, so the lid never
                            dips into the eyeball.
  EyeSwarm_Socket_Mars_SM   optional: a shallow faceted rim (SOCKET_SIDES sides) round the lid, to blend an eye into a flat
                            host surface. Its back face lies on the plane x 0 (the host surface through the eye's centre: the
                            eye is half sunk) and it rises SOCKET_DEPTH 1.5 cm toward +X, from SOCKET_INNER (clear of the
                            lid) out to SOCKET_OUTER 7 cm. Slot `Socket`, vertex colour white.

Vertex colours (attribute "Col", FLOAT_COLOR per face corner, exported with colors_type LINEAR so the FBX carries the
stored floats unchanged): on the eyeball and the lid RGB = d * 0.5 + 0.5, A = 1, where d is the corner's VERTEX's unit
direction from the pivot in the UNREAL frame (Blender's y is negated on the way: Unreal Y = -Blender Y). That is the
vertex's own smooth normal (a sphere about the origin), the same at every corner of a vertex, NOT the flat face normal: the
shader interpolates it across a facet and normalises it to get a smooth direction in the eye's frame. Quantisation: the
legacy Unreal FBX importer (FbxStaticMeshImport.cpp) stores uint8(255 * value), TRUNCATING, so each channel is written as
(k + 0.5) / 255 with k = round(255 * target): Unreal stores exactly the nearest byte k and the shader reads k / 255, within
0.5/255 of the target. The re-import check decodes the FBX's own colour doubles that way and compares to the re-imported
vertex positions.

UV0 "UVMap": an azimuthal projection about +X, written for Unreal (the importer flips V, so Blender holds 1 - V): Unreal
U = 0.5 + 0.5 * rho * y^, V = 0.5 - 0.5 * rho * z^, rho = angle from +X / pi, (y^, z^) the direction's unit bearing in the
YZ plane; the gaze is the UV centre, +Z up toward V 0, the back pole the disc's rim (the vertex there takes each face's own
bearing). The shader does not depend on UVs. The socket's UV0 is (bearing, profile position), informational only.

Run:
  "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup --python build_eye_swarm_pieces.py -- [--export] [--sheets] [--save]
    --export   one FBX and a .json sidecar per piece into EXPORT_DIR, the layout JSON, then a re-import check of every FBX
               (tris, bounds, slots, closedness, and the vertex-colour round trip)
    --sheets   review renders into REVIEW_DIR: every piece alone in its vertex colours (front / side / top / iso) and the
               assembly (eyeball, a cut-away lid, the socket on a host plane)
    --save     BLEND_FILE (the pieces at the origin + the assembly preview)
Prints EYE_SWARM_PIECES_OK when every check passed (EYE_SWARM_PIECES_FAIL + the reasons otherwise).
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
SOURCE_DIR = r"D:\Repo\Content\Monsters\EyeSwarm"           # off-repo art, like D:\Repo\Content\Monsters\RootMaw
EXPORT_DIR = SOURCE_DIR + r"\export"
REVIEW_DIR = EXPORT_DIR + r"\review"
BLEND_FILE = SOURCE_DIR + r"\EyeSwarm_Pieces.blend"
UE_MESH_FOLDER = "/Game/Mars/Gameplay/Monsters/EyeSwarm/Meshes"
BUILDER = "Tools/Blender/mars_monsters/build_eye_swarm_pieces.py"

# ---------------------------------------------------------------- the contract (Unreal cm)
EYE_RADIUS = 5.0
LID_RADIUS = 5.5
ICO_SUBDIVISIONS = 3            # Blender counts the bare icosahedron as 1: 3 = the icosahedron subdivided twice, 320 tris
ICO_TRIS = 320
SOCKET_SIDES = 16
SOCKET_OUTER = 7.0
SOCKET_DEPTH = 1.5
SOCKET_INNER = 5.75
# the socket's closed profile, (radius, x) cm, walked so the ring's faces face outward: back face on x 0, inner wall,
# crest, outer slope
SOCKET_PROFILE = ((SOCKET_INNER, 0.0), (SOCKET_OUTER, 0.0), (6.65, 0.9), (6.2, SOCKET_DEPTH), (5.85, 1.3))
PIECES = ("Eyeball", "Eyelid", "Socket")
SLOTS = {"Eyeball": "Eyeball", "Eyelid": "Eyelid", "Socket": "Socket"}
ENCODED = ("Eyeball", "Eyelid")                     # the pieces whose "Col" carries the direction
TRIS_MAX = {"Eyeball": ICO_TRIS, "Eyelid": ICO_TRIS, "Socket": 400}
PREVIEW = {"Eyeball": (0.9, 0.88, 0.8), "Eyelid": (0.55, 0.3, 0.3), "Socket": (0.35, 0.3, 0.28)}
MIRROR = np.array([1.0, -1.0, 1.0])                 # Unreal <-> Blender (y negated); cm <-> m is a further 100


def piece_name(part):
    return "EyeSwarm_%s_Mars_SM" % part


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
    return np.asarray(v, float) * MIRROR


def encode(dirs_ue):
    """Unit directions (Unreal frame) -> the FBX floats: (round(255 * (d * 0.5 + 0.5)) + 0.5) / 255, clamped to 1."""
    k = np.round(255.0 * (np.asarray(dirs_ue, float) * 0.5 + 0.5))
    return np.minimum((k + 0.5) / 255.0, 1.0)


def unreal_bytes(values):
    """What the legacy Unreal FBX importer stores for FBX colour floats: uint8(255 * clamp(v, 0, 1)) (truncation)."""
    return np.floor(255.0 * np.clip(np.asarray(values, float), 0.0, 1.0) * (1.0 + 1e-7)).astype(np.int64)


# ---------------------------------------------------------------- materials
def preview_material(slot):
    mat = bpy.data.materials.get(slot) or bpy.data.materials.new(slot)
    rgb = PREVIEW.get(slot, (0.5, 0.5, 0.5))
    mat.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None) if nt else None
    if bsdf is not None:
        attr = nt.nodes.get("Col") or nt.nodes.new("ShaderNodeVertexColor")
        attr.name = "Col"
        attr.layer_name = "Col"
        nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.5
    return mat


# ---------------------------------------------------------------- the pieces (Blender metres)
def _finish(name, bm, slot):
    """bmesh -> a flat-shaded triangulated mesh object at the origin with one slot."""
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(preview_material(slot))
    mesh.polygons.foreach_set("material_index", [0] * len(mesh.polygons))
    mesh.polygons.foreach_set("use_smooth", [False] * len(mesh.polygons))
    mesh.validate(verbose=False)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_sphere(name, radius_cm, slot):
    """The icosphere with a vertex on +X (Blender's pole turned from +Z to +X: the 90 deg turn about Y)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=ICO_SUBDIVISIONS, radius=radius_cm * 0.01)
    bmesh.ops.transform(bm, matrix=Matrix.Rotation(math.radians(90.0), 4, "Y"), verts=bm.verts[:])
    for v in bm.verts:                       # exactly on the sphere (the subdivision projects; this removes float drift)
        v.co = v.co.normalized() * radius_cm * 0.01
    return _finish(name, bm, slot)


def build_socket(name):
    """The rim: SOCKET_PROFILE revolved about X in SOCKET_SIDES steps (half a step turned, so a facet, not an edge,
    faces +Z)."""
    bm = bmesh.new()
    n, m = SOCKET_SIDES, len(SOCKET_PROFILE)
    rings = []
    for i in range(n):
        a = 2.0 * math.pi * (i + 0.5) / n
        rings.append([bm.verts.new((x * 0.01, r * math.cos(a) * 0.01, r * math.sin(a) * 0.01)) for r, x in SOCKET_PROFILE])
    for i in range(n):
        a, b = rings[i], rings[(i + 1) % n]
        for j in range(m):
            bm.faces.new((a[j], a[(j + 1) % m], b[(j + 1) % m], b[j]))
    return _finish(name, bm, slot=SLOTS["Socket"])


def _corner_index(me):
    n = len(me.loops)
    vi = np.empty(n, np.int64)
    me.loops.foreach_get("vertex_index", vi)
    return vi


def paint(obj, rgba_corner):
    me = obj.data
    for a in list(me.color_attributes):
        me.color_attributes.remove(a)
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    attr.data.foreach_set("color", np.asarray(rgba_corner, np.float32).ravel())
    me.color_attributes.active_color = attr
    try:
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
    except Exception:
        pass


def paint_direction(obj):
    """RGB = encode(the corner's vertex's unit direction, Unreal frame), A = 1."""
    d = ue_dirs(obj)[_corner_index(obj.data)]
    paint(obj, np.hstack([encode(d), np.ones((len(d), 1))]))


def paint_white(obj):
    paint(obj, np.ones((len(obj.data.loops), 4)))


def uv_azimuthal(obj):
    """UV0: the azimuthal projection about +X (module docstring), per corner; Blender holds 1 - V."""
    me = obj.data
    d = ue_dirs(obj)
    vi = _corner_index(me)
    pl = np.empty(len(me.loops), np.int64)
    for p in me.polygons:
        pl[p.loop_start:p.loop_start + p.loop_total] = p.index
    fc = np.array([sum((d[i] for i in p.vertices), np.zeros(3)) / p.loop_total for p in me.polygons])
    dc = d[vi]
    bearing = dc[:, 1:3].copy()
    flat = np.linalg.norm(bearing, axis=1) < 1e-6                    # the back pole (and the gaze): use the face's bearing
    bearing[flat] = fc[pl[flat]][:, 1:3]
    bearing /= np.maximum(np.linalg.norm(bearing, axis=1, keepdims=True), 1e-12)
    rho = np.arccos(np.clip(dc[:, 0], -1.0, 1.0)) / math.pi
    u = 0.5 + 0.5 * rho * bearing[:, 0]
    v = 0.5 - 0.5 * rho * bearing[:, 1]
    layer = me.uv_layers.new(name="UVMap")
    layer.data.foreach_set("uv", np.stack([u, 1.0 - v], axis=1).ravel())


def uv_socket(obj):
    me = obj.data
    co = ue_verts(obj)
    vi = _corner_index(me)
    ang = (np.arctan2(co[:, 2], co[:, 1]) / (2.0 * math.pi)) % 1.0
    rad = np.linalg.norm(co[:, 1:3], axis=1)
    t = (rad - SOCKET_INNER) / (SOCKET_OUTER - SOCKET_INNER)
    layer = me.uv_layers.new(name="UVMap")
    layer.data.foreach_set("uv", np.stack([ang[vi], 1.0 - t[vi]], axis=1).ravel())


# ---------------------------------------------------------------- measures
def ue_verts(obj):
    n = len(obj.data.vertices)
    co = np.empty(n * 3)
    obj.data.vertices.foreach_get("co", co)
    return co.reshape(n, 3) * 100.0 * MIRROR


def ue_dirs(obj):
    co = ue_verts(obj)
    return co / np.linalg.norm(co, axis=1, keepdims=True)


def ue_bounds(obj):
    v = ue_verts(obj)
    return v.min(axis=0), v.max(axis=0)


def tri_count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def signed_volume_cm3(obj):
    """Blender frame, cm^3: positive when the faces wind outward."""
    me = obj.data
    me.calc_loop_triangles()
    co = np.array([v.co[:] for v in me.vertices]) * 100.0
    t = np.array([lt.vertices[:] for lt in me.loop_triangles])
    a, b, c = co[t[:, 0]], co[t[:, 1]], co[t[:, 2]]
    return float(np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6.0)


def closed_manifold(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bad = sum(1 for e in bm.edges if not e.is_manifold or e.is_boundary)
    loose = sum(1 for v in bm.verts if not v.link_faces)
    bm.free()
    return bad, loose


def piece_checks(objs):
    fails, report = [], {}
    for part, o in objs.items():
        me = o.data
        tris = tri_count(o)
        lo, hi = ue_bounds(o)
        bad, loose = closed_manifold(o)
        vol = signed_volume_cm3(o)
        smooth = sum(1 for p in me.polygons if p.use_smooth)
        slots = [m.name for m in me.materials]
        r = {"tris": tris, "verts": len(me.vertices), "min": np.round(lo, 3).tolist(), "max": np.round(hi, 3).tolist(),
             "volume_cm3": round(vol, 2), "slots": slots}
        if part in ("Eyeball", "Eyelid"):
            want = EYE_RADIUS if part == "Eyeball" else LID_RADIUS
            rad = np.linalg.norm(ue_verts(o), axis=1)
            centre = ue_verts(o).mean(axis=0)
            fc = np.array([p.center[:] for p in me.polygons]) * 100.0
            fn = np.array([p.normal[:] for p in me.polygons])
            inr = float(np.einsum("ij,ij->i", fc, fn).min())             # the faces' planes' nearest approach to the pivot
            outward = int((np.einsum("ij,ij->i", fc, fn) <= 0.0).sum())
            r.update({"radius": [round(float(rad.min()), 4), round(float(rad.max()), 4)], "inradius": round(inr, 4),
                      "centre": np.round(centre, 5).tolist()})
            if tris != ICO_TRIS:
                fails.append("%s has %d tris, the contract says %d" % (o.name, tris, ICO_TRIS))
            if abs(rad.min() - want) > 1e-3 or abs(rad.max() - want) > 1e-3:
                fails.append("%s radius %.4f..%.4f != %.1f" % (o.name, rad.min(), rad.max(), want))
            if np.abs(centre).max() > 1e-3:
                fails.append("%s is not centred on its pivot (%s)" % (o.name, centre.round(4)))
            if outward:
                fails.append("%s has %d faces facing inward" % (o.name, outward))
            fwd = ue_verts(o)[np.argmax(ue_verts(o)[:, 0])]
            if np.abs(fwd - np.array([want, 0.0, 0.0])).max() > 1e-3:
                fails.append("%s has no vertex on +X (front-most %s)" % (o.name, fwd.round(3)))
            if part == "Eyelid" and inr <= EYE_RADIUS:
                fails.append("the lid's facets dip to %.3f cm, inside the eyeball (%.1f)" % (inr, EYE_RADIUS))
        else:
            rad = np.linalg.norm(ue_verts(o)[:, 1:3], axis=1)
            r.update({"ring_radius": [round(float(rad.min()), 3), round(float(rad.max()), 3)]})
            if abs(hi[0] - SOCKET_DEPTH) > 1e-3 or abs(lo[0]) > 1e-3:
                fails.append("%s depth %.3f..%.3f != 0..%.1f" % (o.name, lo[0], hi[0], SOCKET_DEPTH))
            if abs(rad.max() - SOCKET_OUTER) > 1e-3:
                fails.append("%s outer radius %.3f != %.1f" % (o.name, rad.max(), SOCKET_OUTER))
            # the rim's inner wall clears the lid at every height it spans
            for (r0, x0), (r1, x1) in ((SOCKET_PROFILE[-1], SOCKET_PROFILE[0]), (SOCKET_PROFILE[-2], SOCKET_PROFILE[-1])):
                for t in np.linspace(0.0, 1.0, 9):
                    rr, xx = r0 + (r1 - r0) * t, x0 + (x1 - x0) * t
                    apothem = rr * math.cos(math.pi / SOCKET_SIDES)
                    lid = math.sqrt(max(LID_RADIUS ** 2 - xx ** 2, 0.0))
                    if apothem <= lid:
                        fails.append("%s inner wall (r %.2f at x %.2f) cuts the lid (r %.2f)" % (o.name, apothem, xx, lid))
        if tris > TRIS_MAX[part]:
            fails.append("%s has %d tris > %d" % (o.name, tris, TRIS_MAX[part]))
        if bad or loose:
            fails.append("%s is not closed: %d open/non-manifold edges, %d loose verts" % (o.name, bad, loose))
        if vol <= 0.0:
            fails.append("%s winds inward (volume %.2f)" % (o.name, vol))
        if smooth:
            fails.append("%s has %d smooth faces" % (o.name, smooth))
        if slots != [SLOTS[part]]:
            fails.append("%s slots %s != [%s]" % (o.name, slots, SLOTS[part]))
        if [a.name for a in me.color_attributes] != ["Col"]:
            fails.append("%s colour attributes %s" % (o.name, [a.name for a in me.color_attributes]))
        report[part] = r
        print("%-26s tris %4d  verts %4d  min %s  max %s  vol %.1f  %s" % (
            o.name, tris, len(me.vertices), r["min"], r["max"], vol,
            {k: r[k] for k in ("radius", "inradius", "ring_radius") if k in r}))
    return fails, report


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
            "frame": "Unreal local cm: pivot = the eye's centre, +X forward (the gaze), +Y right, +Z up"}
    meta.update(extra or {})
    with open(os.path.splitext(path)[0] + ".json", "w") as fh:
        json.dump(meta, fh, indent=1)
    print("exported %-28s tris %4d  bounds %s .. %s" % (obj.name, meta["tris"], meta["bounds_cm"]["min"],
                                                       meta["bounds_cm"]["max"]))
    return path


def _fbx_parser():
    try:
        from io_scene_fbx import parse_fbx
        return parse_fbx
    except ImportError:
        import importlib
        for name in ("bl_ext.system.io_scene_fbx.parse_fbx", "bl_ext.blender_org.io_scene_fbx.parse_fbx"):
            try:
                return importlib.import_module(name)
            except ImportError:
                continue
    raise RuntimeError("cannot import the FBX add-on's parse_fbx")


def _child(elem, eid):
    return next((e for e in elem.elems if e.id == eid), None)


def fbx_corner_colours(path):
    """The FBX's own LayerElementColor as per-polygon-vertex RGBA doubles (in the file's polygon-vertex order)."""
    root, _ver = _fbx_parser().parse(path)
    objects = _child(root, b"Objects")
    geos = [e for e in objects.elems if e.id == b"Geometry"]
    if len(geos) != 1:
        raise RuntimeError("%s: %d Geometry nodes" % (path, len(geos)))
    lec = _child(geos[0], b"LayerElementColor")
    if lec is None:
        return None, None
    colours = np.asarray(_child(lec, b"Colors").props[0], float).reshape(-1, 4)
    mapping = _child(lec, b"MappingInformationType").props[0]
    ref = _child(lec, b"ReferenceInformationType").props[0]
    pvi = np.asarray(_child(geos[0], b"PolygonVertexIndex").props[0], np.int64)
    pvi = np.where(pvi < 0, -1 - pvi, pvi)
    if mapping == b"ByPolygonVertex":
        idx = np.arange(len(pvi))
    elif mapping in (b"ByVertice", b"ByVertex"):
        idx = pvi
    else:
        raise RuntimeError("%s: colour mapping %s" % (path, mapping))
    if ref == b"IndexToDirect":
        idx = np.asarray(_child(lec, b"ColorIndex").props[0], np.int64)[idx]
    return colours[idx], mapping.decode()


def reimport_check(path, obj, part):
    fails, info = [], {}
    before = set(bpy.data.objects)
    mats_before = set(bpy.data.materials)
    bpy.ops.import_scene.fbx(filepath=path, colors_type="LINEAR")
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    if len(meshes) != 1:
        fails.append("%s reimport: %d meshes" % (obj.name, len(meshes)))
    else:
        m = meshes[0]
        me = m.data
        co_bl = np.array([(m.matrix_world @ vv.co)[:] for vv in me.vertices]) * 100.0     # Blender cm
        src = ue_verts(obj) * MIRROR
        err = float(np.abs(np.concatenate([co_bl.min(axis=0) - src.min(axis=0), co_bl.max(axis=0) - src.max(axis=0)])).max())
        me.calc_loop_triangles()
        if len(me.loop_triangles) != tri_count(obj):
            fails.append("%s reimport tris %d != %d" % (obj.name, len(me.loop_triangles), tri_count(obj)))
        if err > 0.01:
            fails.append("%s reimport bounds off by %.4f cm" % (obj.name, err))
        slots = [mm.name.split(".")[0] if mm else None for mm in me.materials]
        if slots != [mm.name for mm in obj.data.materials]:
            fails.append("%s reimport slots %s" % (obj.name, slots))
        bad, loose = closed_manifold(m)
        if bad or loose:
            fails.append("%s reimport is not closed (%d, %d)" % (obj.name, bad, loose))
        info["bounds_err_cm"] = round(err, 5)
        if not me.color_attributes:
            fails.append("%s reimport lost its vertex colours" % obj.name)
        cols, mapping = fbx_corner_colours(path)
        if cols is None:
            fails.append("%s: the FBX has no LayerElementColor" % obj.name)
        elif len(cols) != len(me.loops):
            fails.append("%s: FBX colours %d != reimported corners %d" % (obj.name, len(cols), len(me.loops)))
        else:
            info["fbx_colour_mapping"] = mapping
            vi = _corner_index(me)
            pos_ue = co_bl[vi] * MIRROR
            stored = unreal_bytes(cols)                                   # what Unreal stores, per channel
            info["alpha_bytes"] = sorted(set(stored[:, 3].tolist()))
            if part in ENCODED:
                target = (pos_ue / np.linalg.norm(pos_ue, axis=1, keepdims=True)) * 0.5 + 0.5
                chan_err = np.abs(stored[:, :3] / 255.0 - target)
                dec = stored[:, :3] / 255.0 * 2.0 - 1.0
                dec /= np.linalg.norm(dec, axis=1, keepdims=True)
                true = pos_ue / np.linalg.norm(pos_ue, axis=1, keepdims=True)
                ang = np.degrees(np.arccos(np.clip(np.einsum("ij,ij->i", dec, true), -1.0, 1.0)))
                # the Blender importer's own attribute, for the record (independent of the Unreal decode)
                attr = me.color_attributes[0]
                bl = np.empty(len(me.loops) * 4, np.float32)
                attr.data.foreach_get("color", bl)
                bl_err = np.abs(bl.reshape(-1, 4)[:, :3] - target)
                info.update({"corners": int(len(cols)), "max_channel_err_255": round(float(chan_err.max()) * 255.0, 4),
                             "max_angle_err_deg": round(float(ang.max()), 4),
                             "blender_attr_type": attr.data_type, "blender_attr_max_err_255": round(float(bl_err.max()) * 255.0, 4)})
                if chan_err.max() > 1.0 / 255.0 + 1e-9:
                    fails.append("%s colour decodes %.3f/255 off the direction" % (obj.name, chan_err.max() * 255.0))
                # the samples the report quotes: the gaze, up, right, back and two in between
                picks = {}
                for label, want in (("+X", (1, 0, 0)), ("+Y", (0, 1, 0)), ("+Z", (0, 0, 1)), ("-X", (-1, 0, 0)),
                                    ("diag", (0.6, -0.5, 0.62)), ("low", (-0.3, 0.4, -0.86))):
                    w = np.asarray(want, float) / np.linalg.norm(want)
                    k = int(np.argmax(true @ w))
                    picks[label] = {"dir": np.round(true[k], 4).tolist(), "bytes": stored[k].tolist(),
                                    "decoded": np.round(stored[k, :3] / 255.0 * 2.0 - 1.0, 4).tolist()}
                info["samples"] = picks
            elif (stored != 255).any():
                fails.append("%s is not white (%d channels below 255)" % (obj.name, int((stored != 255).sum())))
    for o in new:
        data = o.data if o.type == "MESH" else None
        bpy.data.objects.remove(o, do_unlink=True)
        if data is not None and data.users == 0:
            bpy.data.meshes.remove(data)
    for mm in list(bpy.data.materials):
        if mm not in mats_before and mm.users == 0:
            bpy.data.materials.remove(mm)
    return fails, info


# ---------------------------------------------------------------- renders
def _look_at(cam, eye, target):
    f = np.array(target, float) - np.array(eye, float)
    cam.location = eye
    cam.rotation_euler = (math.atan2(math.hypot(f[0], f[1]), -f[2]), 0.0, -math.atan2(f[0], f[1]))


def _n(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-12)


def render_workbench(objs, path, view_ue, target_ue_cm, half_width_cm, size=(560, 480), color_type="VERTEX"):
    scene = bpy.context.scene
    others = [o for o in scene.objects if o.type == "MESH" and o not in objs]
    state = [o.hide_render for o in others]
    cam_data = bpy.data.cameras.new("_ReviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = half_width_cm * 0.02
    cam_data.clip_start, cam_data.clip_end = 0.001, 20.0
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
        scene.display.shading.color_type = color_type
        scene.display.shading.show_cavity = False
        scene.display.shading.show_object_outline = False
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        scene.render.film_transparent = False
        d = _n(_ue_to_bl(view_ue))
        t = _ue_to_bl(target_ue_cm) * 0.01
        _look_at(cam, tuple(t + d * 2.0), tuple(t))
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
        paths = [render_workbench([o], os.path.join(REVIEW_DIR, "_%s_%s.png" % (part, k)), v, (0.0, 0.0, 0.0), 8.5)
                 for k, v in PIECE_VIEWS]
        out.append(tile_images(paths, os.path.join(REVIEW_DIR, "EyeSwarm_%s_sheet.png" % part)))
    return out


def assembly(objs):
    """Preview only: the eyeball, a copy of the lid with its front cut away (the opening the shader's mask makes), the
    socket, and a host plane on x 0 - placed as two eyes side by side, one bare."""
    made = []
    bm = bmesh.new()
    bm.from_mesh(objs["Eyelid"].data)
    cut = [f for f in bm.faces if f.calc_center_median().x > LID_RADIUS * 0.01 * math.cos(math.radians(55.0))]
    bmesh.ops.delete(bm, geom=cut, context="FACES")
    me = bpy.data.meshes.new("_LidCut")
    bm.to_mesh(me)
    bm.free()
    lid = bpy.data.objects.new("_LidCut", me)
    bpy.context.scene.collection.objects.link(lid)
    made.append(lid)
    for part, o in (("Eyeball", objs["Eyeball"]), ("Socket", objs["Socket"])):
        c = bpy.data.objects.new("_Asm" + part, o.data)
        bpy.context.scene.collection.objects.link(c)
        made.append(c)
    for part in ("Eyeball", "Eyelid", "Socket"):
        c = bpy.data.objects.new("_Asm2" + part, objs[part].data)
        c.location = _ue_to_bl((0.0, 16.0, 0.0)) * 0.01
        bpy.context.scene.collection.objects.link(c)
        made.append(c)
    bpy.ops.mesh.primitive_plane_add(size=0.4, location=(0.0, 0.0, 0.0), rotation=(0.0, math.radians(90.0), 0.0))
    plane = bpy.context.active_object
    plane.name = "_HostPlane"
    plane.location = _ue_to_bl((-0.02, 8.0, 0.0)) * 0.01
    made.append(plane)
    return made


def render_assembly_sheet(made):
    paths = [render_workbench(made, os.path.join(REVIEW_DIR, "_asm_%s.png" % k), v, (0.0, 8.0, 0.0), 16.0,
                              size=(700, 480), color_type=ct)
             for k, v, ct in (("front", (1.0, 0.0, 0.0), "VERTEX"), ("iso", (0.9, -0.7, 0.5), "VERTEX"),
                              ("side", (0.0, -1.0, 0.25), "MATERIAL"), ("iso_mat", (0.9, 0.7, 0.45), "MATERIAL"))]
    return tile_images(paths, os.path.join(REVIEW_DIR, "EyeSwarm_assembly_sheet.png"))


def main():
    args = cli_args({"export": False, "sheets": False, "save": False})
    clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    objs = {"Eyeball": build_sphere(piece_name("Eyeball"), EYE_RADIUS, SLOTS["Eyeball"]),
            "Eyelid": build_sphere(piece_name("Eyelid"), LID_RADIUS, SLOTS["Eyelid"]),
            "Socket": build_socket(piece_name("Socket"))}
    for part in ENCODED:
        uv_azimuthal(objs[part])
        paint_direction(objs[part])
    uv_socket(objs["Socket"])
    paint_white(objs["Socket"])
    fails, report = piece_checks(objs)

    exported = []
    if args["export"]:
        contract = {"vertex_colour": "Col: RGB = (round(255*(d*0.5+0.5))+0.5)/255, d = the vertex's unit direction from "
                                     "the pivot in the Unreal frame (smooth, same at every corner); A = 1. Unreal stores "
                                     "the nearest byte; decode d = normalize(VertexColor.rgb * 2 - 1).",
                    "uv0": "azimuthal about +X: U = 0.5 + 0.5*rho*y^, V = 0.5 - 0.5*rho*z^, rho = angle from +X / pi"}
        for part in PIECES:
            extra = {"contract": contract} if part in ENCODED else {"vertex_colour": "white"}
            if part == "Socket":
                extra.update({"profile_r_x_cm": [list(p) for p in SOCKET_PROFILE], "sides": SOCKET_SIDES,
                              "host_plane_x_cm": 0.0})
            exported.append((export_fbx(objs[part], extra), part))
        lay = {"builder": BUILDER, "frame": "Unreal local cm: pivot = the eye's centre, +X the gaze, +Y right, +Z up",
               "eye_radius": EYE_RADIUS, "lid_radius": LID_RADIUS, "socket": {"inner": SOCKET_INNER, "outer": SOCKET_OUTER,
                                                                             "depth": SOCKET_DEPTH, "host_plane_x": 0.0},
               "pieces": report}
        with open(os.path.join(EXPORT_DIR, "EyeSwarm_Layout.json"), "w") as fh:
            json.dump(lay, fh, indent=1)

    sheets = []
    if args["sheets"] or args["save"]:
        made = assembly(objs)
        if args["sheets"]:
            sheets = render_piece_sheets(objs)
            sheets.append(render_assembly_sheet(made))
    if args["save"]:
        os.makedirs(SOURCE_DIR, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=BLEND_FILE, copy=False)
        print("saved", BLEND_FILE)
    roundtrip = {}
    for path, part in exported:
        f, info = reimport_check(path, objs[part], part)
        fails += f
        roundtrip[part] = info
        print("reimport %-8s %s" % (part, json.dumps(info)))
    print("EYE_SWARM_REPORT " + json.dumps({"pieces": report, "roundtrip": roundtrip}))
    if exported:
        print("fbx:", *[p for p, _ in exported], sep="\n  ")
    if sheets:
        print("sheets:", *sheets, sep="\n  ")
    if fails:
        print("EYE_SWARM_PIECES_FAIL", *fails, sep="\n  ")
    else:
        print("EYE_SWARM_PIECES_OK")


if __name__ == "__main__":
    main()
