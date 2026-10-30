"""Shared helpers for the environment dressing builders (Blender 5.2, headless). A thin layer over the cooking set's
station_common / food_common that redirects their output folders and slot whitelist to env_spec, so every family
builder gets the same mesh creation, painting, sockets, UCX, export, sidecar and review-sheet helpers:

    import env_common as ec; spec = ec.spec; fc = ec.fc; sc = ec.sc
    obj = ec.new_object("Skull_A_Mars_SM", verts_cm, faces, slots=("EnvBone",), face_slots=ids)
    fc.paint(obj, per_face_rgb)                          # "Col": linear RGB + cavity in A
    fc.smart_uv(obj)                                     # UV0 "UVMap"
    ec.write_data_uv(obj, ids_0_1, flex_0_1)             # optional UV1 "EnvData" (per-face or per-loop arrays)
    sc.add_socket(obj, "Flame", (0, 0, 40))              # cm, Blender axes (the sidecar mirrors Y for Unreal)
    sc.add_ucx(obj, hull_verts_cm)                       # one CONVEX piece per call (UCX_<Name>_NN)
    ec.export(obj, family="bones", extra={...})          # FBX + JSON sidecar into env_spec.EXPORT_DIR
    ec.review(objs, "Bones_Skulls")                      # contact sheet into env_spec.REVIEW_DIR

All geometry is handed in as CENTIMETRES (numpy (n, 3)); objects are created in metres at the origin.
Never import a build_*.py module (they run main() at import); copy what you need from them instead.
"""
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
COOKING = os.path.join(os.path.dirname(HERE), "mars_cooking")
for p in (HERE, COOKING):
    if p not in sys.path:
        sys.path.insert(0, p)

import station_common as sc       # noqa: E402  (imports food_common and points it at the station folders)
import food_common as fc          # noqa: E402
import food_spec                  # noqa: E402
import station_spec               # noqa: E402
import env_spec as spec           # noqa: E402

# redirect the shared helpers to the environment contract (module attributes are read at call time)
food_spec.BLEND_DIR = spec.BLEND_DIR
food_spec.EXPORT_DIR = spec.EXPORT_DIR
food_spec.REVIEW_DIR = spec.REVIEW_DIR
food_spec.SLOTS_STATIC = tuple(dict.fromkeys(food_spec.SLOTS_STATIC + spec.SLOTS))
station_spec.BLEND_DIR = spec.BLEND_DIR
station_spec.EXPORT_DIR = spec.EXPORT_DIR
station_spec.REVIEW_DIR = spec.REVIEW_DIR
station_spec.SLOTS = tuple(dict.fromkeys(station_spec.SLOTS + spec.SLOTS))

UE_MIRROR = fc.UE_MIRROR


def palette(name):
    """Linear rgb of an env_spec.PALETTE_SRGB entry (slot names and the *Dark / *Light variants)."""
    return np.array(fc.srgb(*spec.PALETTE_SRGB[name]))


def new_object(name, verts_cm, faces, slots, face_slots=None, **kw):
    """fc.new_object after checking every slot is an env_spec slot (flat shaded, outward normals, one material per slot
    named exactly like the slot)."""
    for s in slots:
        if s not in spec.SLOTS:
            raise ValueError("%s: slot %r is not in env_spec.SLOTS" % (name, s))
    return fc.new_object(name, verts_cm, faces, slots=slots, face_slots=face_slots, **kw)


def write_data_uv(obj, ids, flex, domain="FACE"):
    """UV1 "EnvData" (see env_spec): u = id 0..1, v (as Unreal reads it) = flex 0 at the attachment .. 1 at the tip.
    ids / flex are per face (domain FACE) or per loop (domain CORNER). Stored v = 1 - flex for the FBX V flip."""
    mesh = obj.data
    layer = mesh.uv_layers.get(spec.DATA_UV) or mesh.uv_layers.new(name=spec.DATA_UV)
    ids = np.asarray(ids, float)
    flex = np.asarray(flex, float)
    n_loops = len(mesh.loops)
    if domain == "FACE":
        loop_face = np.empty(n_loops, int)
        for poly in mesh.polygons:
            loop_face[poly.loop_start:poly.loop_start + poly.loop_total] = poly.index
        u = ids[loop_face]
        v = flex[loop_face]
    else:
        u, v = ids, flex
    uv = np.empty(n_loops * 2, np.float32)
    uv[0::2] = u
    uv[1::2] = 1.0 - v
    layer.data.foreach_set("uv", uv)
    mesh.uv_layers.active = mesh.uv_layers["UVMap"] if "UVMap" in mesh.uv_layers else mesh.uv_layers[0]
    return layer


def export(obj, family, extra=None):
    """FBX + sidecar (station exporter: SOCKET_ / UCX_ children, triangles, linear colours, FBX_SCALE_NONE, -Z fwd / Y up)
    with the Unreal folder and family recorded so unreal/mars_env_ue.py can import it without guessing."""
    meta = {"env_family": family, "ue_folder": spec.ue_mesh_folder(family)}
    if extra:
        meta.update(extra)
    return sc.export_fbx(obj, extra=meta)


def review(objs, stem, views=("iso", "front", "top"), size=(1800, 700), gap=1.25):
    """Workbench contact sheet (vertex colours, cavity) into env_spec.REVIEW_DIR/<stem>_sheet.png."""
    return fc.review_sheet(objs, stem, views=views, color="VERTEX", size=size, gap=gap)


def save_family_blend(family):
    fc.save_blend(os.path.join(spec.BLEND_DIR, spec.FAMILIES[family][1]))
