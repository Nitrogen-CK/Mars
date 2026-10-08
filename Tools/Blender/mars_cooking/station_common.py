"""Shared helpers for the station prop builders (Blender 5.2, headless). Thin layer over food_common that redirects
the output folders to the station contract, allows the station slots, and exports SOCKET_ empties + UCX_ collision
children with each prop. Every builder does:

    import station_common as sc; spec = sc.spec; fc = sc.fc
    obj = sc.new_object("FryerVat_Mars_SM", verts_cm, faces, slots=("Stone", "Iron", "Ember"), face_slots=ids)
    fc.paint(obj, per_face_rgb)                          # vertex colours "Col" (linear RGB + cavity in A)
    fc.smart_uv(obj)                                     # UV0 atlas
    sc.add_socket(obj, "Oil", (0, 0, 66))                # cm, Blender axes (the sidecar mirrors Y for Unreal)
    sc.add_ucx(obj, hull_verts_cm)                       # one CONVEX piece per call (UCX_<Name>_NN)
    sc.export_fbx(obj, extra={...})                      # FBX + JSON sidecar in spec.EXPORT_DIR
    fc.review_sheet([obj], "FryerVat")                   # contact sheet in spec.REVIEW_DIR (UCX pieces hidden)

All geometry is handed in as CENTIMETRES (numpy (n, 3)); objects are created in metres at the origin.
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
import food_common as fc          # noqa: E402
import food_spec                  # noqa: E402
import station_spec as spec       # noqa: E402

# redirect the food helpers' folders and slot whitelist to the station contract (module attributes are read at call time)
food_spec.BLEND_DIR = spec.BLEND_DIR
food_spec.EXPORT_DIR = spec.EXPORT_DIR
food_spec.REVIEW_DIR = spec.REVIEW_DIR
food_spec.SLOTS_STATIC = tuple(dict.fromkeys(food_spec.SLOTS_STATIC + spec.SLOTS))

UE_MIRROR = fc.UE_MIRROR


def palette(slot):
    """Linear rgb of a PALETTE_SRGB entry."""
    return fc.srgb(*spec.PALETTE_SRGB[slot])


def new_object(name, verts_cm, faces, slots, face_slots=None, **kw):
    for s in slots:
        if s not in spec.SLOTS:
            raise ValueError("%s: slot %r is not in station_spec.SLOTS" % (name, s))
    return fc.new_object(name, verts_cm, faces, slots=slots, face_slots=face_slots, **kw)


# ---------------------------------------------------------------- primitives (cm)
def box(center, size, rot_z_deg=0.0):
    """Axis-aligned box (optionally yawed) -> (verts (8,3), 6 quads) outward wound."""
    c = np.asarray(center, float)
    hx, hy, hz = np.asarray(size, float) * 0.5
    v = np.array([[-hx, -hy, -hz], [hx, -hy, -hz], [hx, hy, -hz], [-hx, hy, -hz],
                  [-hx, -hy, hz], [hx, -hy, hz], [hx, hy, hz], [-hx, hy, hz]])
    if rot_z_deg:
        a = math.radians(rot_z_deg)
        r = np.array([[math.cos(a), -math.sin(a), 0.0], [math.sin(a), math.cos(a), 0.0], [0.0, 0.0, 1.0]])
        v = v @ r.T
    faces = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    return v + c, faces


def chipped_block(center, size, rng, chip=0.08, wobble_deg=2.0, jitter_cm=0.4):
    """A stone block: a box with its corners pushed in at random (chipped), a slight yaw and vertex jitter."""
    v, f = box(center, size, rot_z_deg=rng.uniform(-wobble_deg, wobble_deg))
    c = np.asarray(center, float)
    s = np.asarray(size, float)
    for i in range(8):
        if rng.uniform() < 0.5:
            v[i] = c + (v[i] - c) * (1.0 - chip * rng.uniform(0.3, 1.0))
    v += rng.uniform(-jitter_cm, jitter_cm, size=v.shape)
    return v, f


def rod(p0, p1, radius_cm, sides=4, phase=0.0):
    """A straight faceted rod between two points -> (verts, faces) with caps."""
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    axis = p1 - p0
    length = np.linalg.norm(axis)
    axis = axis / max(length, 1e-9)
    helper = np.array([0.0, 0.0, 1.0]) if abs(axis[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = np.cross(axis, helper)
    u /= np.linalg.norm(u)
    w = np.cross(axis, u)
    r0 = fc.ring(p0, radius_cm, radius_cm, sides, u, w, phase)
    r1 = fc.ring(p1, radius_cm, radius_cm, sides, u, w, phase)
    return fc.loft([r0, r1])


def torus_ring(center, radius_cm, tube_cm, segments=16, sides=4, axis="z"):
    """A faceted hoop in the plane normal to axis."""
    c = np.asarray(center, float)
    rings = []
    for k in range(segments):
        a = math.tau * k / segments
        if axis == "z":
            rc = c + np.array([math.cos(a), math.sin(a), 0.0]) * radius_cm
            u = np.array([math.cos(a), math.sin(a), 0.0])
            wv = np.array([0.0, 0.0, 1.0])
        else:                                  # axis "y": hoop in the XZ plane
            rc = c + np.array([math.cos(a), 0.0, math.sin(a)]) * radius_cm
            u = np.array([math.cos(a), 0.0, math.sin(a)])
            wv = np.array([0.0, 1.0, 0.0])
        rings.append(fc.ring(rc, tube_cm, tube_cm, sides, u, wv))
    rings.append(rings[0])
    return fc.loft(rings, close_start=False, close_end=False)


def wedge_prism(r_in, r_out, z0, z1, a0, a1, pad_deg=0.6):
    """A convex prism covering the sector a0..a1 (radians) between radii and heights: one UCX piece of a ring wall."""
    a0 -= math.radians(pad_deg)
    a1 += math.radians(pad_deg)
    pts = []
    for z in (z0, z1):
        for a in (a0, a1):
            pts.append((r_in * math.cos(a), r_in * math.sin(a), z))
            pts.append((r_out * math.cos(a), r_out * math.sin(a), z))
        am = 0.5 * (a0 + a1)
        pts.append((r_out * math.cos(am) / math.cos(0.5 * (a1 - a0)), r_out * math.sin(am) / math.cos(0.5 * (a1 - a0)), z))
    return np.array(pts, float)


def ring_ucx(obj, r_in, r_out, z0, z1, pieces=12):
    """Add pieces wedge prisms round a vessel wall as UCX children."""
    for k in range(pieces):
        add_ucx(obj, wedge_prism(r_in, r_out, z0, z1, math.tau * k / pieces, math.tau * (k + 1) / pieces))


def box_ucx(obj, center, size):
    add_ucx(obj, box(center, size)[0])


# ---------------------------------------------------------------- sockets + collision children
def add_socket(obj, name, location_cm, rotation_deg=(0.0, 0.0, 0.0)):
    """An empty SOCKET_<name> parented to obj (Blender axes, cm). The FBX importer makes a static mesh socket of it."""
    empty = bpy.data.objects.new("SOCKET_%s" % name, None)
    empty.empty_display_type = "ARROWS"
    empty.empty_display_size = 0.05
    empty.location = tuple(np.asarray(location_cm, float) * 0.01)
    empty.rotation_euler = tuple(math.radians(a) for a in rotation_deg)
    empty.parent = obj
    bpy.context.scene.collection.objects.link(empty)
    return empty


def add_ucx(obj, hull_verts_cm):
    """One convex collision piece: UCX_<MeshName>_<NN> built as the convex hull of the points (bmesh)."""
    import bmesh
    pts = np.asarray(hull_verts_cm, float)
    n = sum(1 for o in bpy.data.objects if o.parent is obj and o.name.startswith("UCX_"))
    mesh = bpy.data.meshes.new("UCX_%s_%02d" % (obj.name, n))
    bm = bmesh.new()
    for p in pts:
        bm.verts.new((p * 0.01).tolist())
    bm.verts.ensure_lookup_table()
    res = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    loose = {g for key in ("geom_interior", "geom_unused") for g in res.get(key, []) if isinstance(g, bmesh.types.BMVert)}
    bmesh.ops.delete(bm, geom=[v for v in loose if v.is_valid], context="VERTS")
    bm.to_mesh(mesh)
    bm.free()
    piece = bpy.data.objects.new(mesh.name, mesh)
    piece.parent = obj
    piece.display_type = "WIRE"
    piece.hide_render = True
    bpy.context.scene.collection.objects.link(piece)
    return piece


def children(obj, prefix):
    return [o for o in bpy.data.objects if o.parent is obj and o.name.startswith(prefix)]


def socket_table(obj):
    """{name: {"location_cm": Unreal local cm, "rotation_deg": (roll, pitch, yaw) Blender-ish}} for the sidecar."""
    out = {}
    for e in children(obj, "SOCKET_"):
        loc = np.asarray(e.location, float) * 100.0 * UE_MIRROR
        rot = [math.degrees(a) for a in e.rotation_euler]
        out[e.name[len("SOCKET_"):]] = {"location_cm": [round(float(x), 3) for x in loc],
                                       "rotation_deg": [round(r, 3) for r in rot]}
    return out


def check_ucx(obj):
    """Every UCX child must be a closed convex shell; returns a list of problems (empty = fine)."""
    problems = []
    for piece in children(obj, "UCX_"):
        m = piece.data
        if len(m.polygons) < 4:
            problems.append("%s has %d faces" % (piece.name, len(m.polygons)))
        v = np.array([x.co[:] for x in m.vertices])
        c = v.mean(axis=0)
        for p in m.polygons:
            n = np.array(p.normal[:])
            d = float(np.dot(n, np.array(p.center[:]) - c))
            if d < -1e-6:
                problems.append("%s: a face points inward" % piece.name)
                break
    return problems


# ---------------------------------------------------------------- export
def export_fbx(obj, name=None, extra=None):
    """FBX of obj + its SOCKET_ empties + UCX_ children (cooking_spec exporter settings, triangles, linear colours) and
    the JSON sidecar with sockets, ucx count and extras."""
    fc.ensure_dirs()
    name = name or obj.name
    path = os.path.join(spec.EXPORT_DIR, name + ".fbx")
    mesh = obj.data
    mesh.uv_layers.active = mesh.uv_layers["UVMap"] if "UVMap" in mesh.uv_layers else mesh.uv_layers[0]
    group = [obj] + children(obj, "SOCKET_") + children(obj, "UCX_")
    for o in bpy.context.scene.objects:
        o.select_set(o in group)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH", "EMPTY"}, mesh_smooth_type="EDGE",
                             use_mesh_modifiers=True, add_leaf_bones=False, bake_anim=False, use_tspace=False,
                             apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y",
                             use_triangles=True, colors_type="LINEAR")
    problems = check_ucx(obj)
    meta_extra = {"sockets": socket_table(obj), "ucx_pieces": len(children(obj, "UCX_")), "ucx_problems": problems,
                  "station_prop": True}
    if extra:
        meta_extra.update(extra)
    meta = fc.write_meta(obj, path, meta_extra)
    print("exported %s  tris %d  size %.1f cm  slots %s  sockets %s  ucx %d%s" % (
        name, meta["tris"], meta["size_cm"], meta["slots"], sorted(meta_extra["sockets"]), meta_extra["ucx_pieces"],
        ("  UCX PROBLEMS %s" % problems) if problems else ""))
    return path


def hide_helpers_for_render():
    """UCX pieces never render; review_sheet hides every mesh that is not in its list, but keep this for ad-hoc renders."""
    for o in bpy.data.objects:
        if o.name.startswith("UCX_"):
            o.hide_render = True


def save_blend(station):
    fc.save_blend(os.path.join(spec.BLEND_DIR, spec.STATIONS[station][0]))


def layout_json(name, data):
    """Write a small layout / contract JSON next to the exports (e.g. where the props sit in the station frame)."""
    fc.ensure_dirs()
    path = os.path.join(spec.EXPORT_DIR, name + ".json")
    with open(path, "w") as fh:
        json.dump(data, fh, indent=2)
    return path
