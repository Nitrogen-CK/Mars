"""Cellar Bat R01 - FBX export (recipe proven in Phase 2 and unchanged; Phase 3 adds LODs and the baked clip).

Opens source/CellarBat_R01.blend (1 BU = 1 cm, scale_length 0.01) and writes:
  export/CellarBat_R01_Mars_SK.fbx          LOD0 bind mesh + 42-bone armature, rest pose, no animation
  export/CellarBat_R01_LOD1_Mars_SK.fbx     LOD1 mesh + the same armature (same bone names, same slot order)
  export/CellarBat_R01_LOD2_Mars_SK.fbx     LOD2 mesh + the same armature
  export/validation/Cube10_Mars_SM.fbx      10 cm cube (static recipe check)
  export/validation/CellarBat_R01_FlapTest_Mars_ANIM.fbx
                                            the control-rig flap test (CellarBat_R01_FlapTest_Ctl) baked onto the
                                            export bones by bake_cellar_bat.py, frames 0..15 at 30 fps, one action
  export/validation/export_settings.json    every exporter argument verbatim, Blender/FBX versions, file headers
  export/validation/expected.json           what the round trip / Unreal must read back (UE cm: (x, -y, z))
The armature object is renamed `Armature` for each export (Unreal drops that root node) and renamed back. Only the
export armature and one mesh are ever selected: the control armature, cameras, rulers and the other LODs are not
exported. The .blend is not saved.

Run:
  blender -b --factory-startup <root>/source/CellarBat_R01.blend --python export_cellar_bat.py
Prints CELLAR_BAT_OK or CELLAR_BAT_FAIL <reason>.
"""
import json
import os
import struct
import sys
import traceback

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "export")
VAL = os.path.join(OUT, "validation")
ARM_NAME = "CellarBat_R01_Armature"
MESH_NAME = "CellarBat_R01_Body"
LODS = {0: (MESH_NAME, "CellarBat_R01_Mars_SK.fbx"),
        1: (MESH_NAME + "_LOD1", "CellarBat_R01_LOD1_Mars_SK.fbx"),
        2: (MESH_NAME + "_LOD2", "CellarBat_R01_LOD2_Mars_SK.fbx")}
FLAP_CTL_ACTION = "CellarBat_R01_FlapTest_Ctl"
FLAP_FBX = "CellarBat_R01_FlapTest_Mars_ANIM.fbx"
TO_UE = np.array([1.0, -1.0, 1.0])
LANDMARK_BONES = ("finger_01b_l", "finger_01b_r", "finger_03b_l", "wrist_l", "wrist_r", "thumb_b_l")

COMMON = dict(use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE", global_scale=1.0,
              axis_forward="-Z", axis_up="Y", use_mesh_modifiers=False, mesh_smooth_type="FACE", use_triangles=True,
              use_tspace=False, add_leaf_bones=False, path_mode="STRIP", colors_type="SRGB",
              use_custom_props=False, bake_space_transform=False)
STATIC = dict(COMMON, object_types={"MESH"}, bake_anim=False)
SKELETAL = dict(COMMON, object_types={"ARMATURE", "MESH"}, primary_bone_axis="Y", secondary_bone_axis="X",
                use_armature_deform_only=True, armature_nodetype="NULL")
BIND = dict(SKELETAL, bake_anim=False)
CLIP = dict(SKELETAL, bake_anim=True, bake_anim_use_all_bones=True, bake_anim_use_nla_strips=False,
            bake_anim_use_all_actions=False, bake_anim_force_startend_keying=True, bake_anim_step=1.0,
            bake_anim_simplify_factor=0.0)


def fbx_header(path):
    with open(path, "rb") as fh:
        data = fh.read()
    out = {"magic": data[:20].decode("ascii", "replace").rstrip("\x00 ")}
    if data.startswith(b"Kaydara FBX Binary"):
        out["file_version"] = struct.unpack("<I", data[23:27])[0]
    for key in (b"FBXHeaderVersion", b"FBXVersion"):
        i = data.find(key)
        if i >= 0:
            j = i + len(key)
            if data[j:j + 1] == b"I":
                out[key.decode()] = struct.unpack("<i", data[j + 1:j + 5])[0]
    i = data.find(b"Creator")
    if i >= 0 and data[i + 7:i + 8] == b"S":
        n = struct.unpack("<I", data[i + 8:i + 12])[0]
        out["Creator"] = data[i + 12:i + 12 + n].decode("utf-8", "replace")
    return out


def select_only(objs):
    for o in bpy.context.view_layer.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = objs[0]


def jsonable(d):
    return {k: (sorted(v) if isinstance(v, set) else v) for k, v in d.items()}


def mesh_extremes(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    ev.to_mesh_clear()
    co = co.reshape(-1, 3) @ np.array(obj.matrix_world)[:3, :3].T + np.array(obj.matrix_world)[:3, 3]
    ue = co * TO_UE
    return {"max_y_point": ue[np.argmax(ue[:, 1])].round(3).tolist(),
            "min_y_point": ue[np.argmin(ue[:, 1])].round(3).tolist(),
            "max_z": round(float(ue[:, 2].max()), 3), "min_z": round(float(ue[:, 2].min()), 3)}


def mesh_facts(ob):
    me = ob.data
    me.calc_loop_triangles()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    ue = co.reshape(-1, 3) * TO_UE
    ca = me.color_attributes.get("Col")
    return {"object": ob.name, "tris": len(me.loop_triangles), "verts": len(me.vertices),
            "slots": [m.name for m in me.materials],
            "bounds_ue_cm": {"min": ue.min(0).round(3).tolist(), "max": ue.max(0).round(3).tolist()},
            "span_cm": round(float(ue[:, 1].max() - ue[:, 1].min()), 3),
            "uv_layers": [u.name for u in me.uv_layers],
            "color_attribute": None if ca is None else {"name": ca.name, "type": ca.data_type, "domain": ca.domain},
            "shape_keys": 0 if me.shape_keys is None else len(me.shape_keys.key_blocks)}


def export_skeletal(arm, mesh, path):
    old = arm.name
    try:
        arm.name = "Armature"
        select_only([arm, mesh])
        bpy.ops.export_scene.fbx(filepath=path, **BIND)
    finally:
        arm.name = old


def export_clip(arm, mesh, baked, path):
    """The baked action alone drives the export bones (rig constraints muted by the bake)."""
    sc = bpy.context.scene
    arm.data.pose_position = "POSE"
    arm.animation_data.action = baked
    fr = baked.frame_range
    sc.frame_start, sc.frame_end = int(round(fr[0])), int(round(fr[1]))
    sc.render.fps, sc.render.fps_base = 30, 1.0
    old = arm.name
    try:
        arm.name = "Armature"
        select_only([arm, mesh])
        bpy.ops.export_scene.fbx(filepath=path, **CLIP)
    finally:
        arm.name = old


def main():
    import bake_cellar_bat
    fails = []
    os.makedirs(VAL, exist_ok=True)
    sc = bpy.context.scene
    if abs(sc.unit_settings.scale_length - 0.01) > 1e-9:
        fails.append("scale_length %s" % sc.unit_settings.scale_length)
    arm = bpy.data.objects[ARM_NAME]
    for n, _f in LODS.values():
        bpy.data.objects[n].hide_set(False)
    files = {}

    # 1. cube
    bpy.ops.mesh.primitive_cube_add(size=10.0, location=(0, 0, 0))
    cube = bpy.context.active_object
    cube.name = cube.data.name = "Cube10_Mars_SM"
    p = os.path.join(VAL, "Cube10_Mars_SM.fbx")
    select_only([cube])
    bpy.ops.export_scene.fbx(filepath=p, **STATIC)
    files["cube"] = p
    bpy.data.objects.remove(cube, do_unlink=True)

    # 2. bind mesh + LODs at rest
    if arm.animation_data:
        arm.animation_data.action = None
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    expected = {"bones": [], "lods": {}, "cube_bounds_ue_cm": {"min": [-5.0, -5.0, -5.0], "max": [5.0, 5.0, 5.0]}}
    for b in arm.data.bones:
        expected["bones"].append({"name": b.name, "parent": b.parent.name if b.parent else None,
                                  "head_ue_cm": (np.array(b.head_local) * TO_UE).round(4).tolist(),
                                  "tail_ue_cm": (np.array(b.tail_local) * TO_UE).round(4).tolist()})
    for lod, (mname, fname) in LODS.items():
        mesh = bpy.data.objects[mname]
        p = os.path.join(OUT, fname)
        export_skeletal(arm, mesh, p)
        files["lod%d" % lod] = p
        expected["lods"][str(lod)] = dict(mesh_facts(mesh), file=fname)
    expected["slots"] = expected["lods"]["0"]["slots"]

    # 3. flap clip: control action -> bake -> export the baked action
    arm.data.pose_position = "POSE"
    baked, bake_rep, ok = bake_cellar_bat.bake(FLAP_CTL_ACTION, "CellarBat_R01_FlapTest", 0, 15)
    print("BAKE", json.dumps(bake_rep))
    if not ok:
        fails.append("bake %s" % json.dumps(bake_rep))
    body = bpy.data.objects[MESH_NAME]
    arm.animation_data.action = baked
    expected["flap"] = {"frames": 16, "fps": 30, "first": 0, "last": 15, "file": FLAP_FBX, "bake": bake_rep,
                        "keys": {}}
    for f in (0, 4, 8, 12, 15):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        k = {n: (np.array(arm.matrix_world @ arm.pose.bones[n].head) * TO_UE).round(4).tolist() for n in LANDMARK_BONES}
        k["mesh"] = mesh_extremes(body)
        expected["flap"]["keys"][str(f)] = k
    sc.frame_set(0)
    p = os.path.join(VAL, FLAP_FBX)
    export_clip(arm, body, baked, p)
    files["clip"] = p
    other_actions = sorted(a.name for a in bpy.data.actions if a != baked)

    settings = {
        "blender_version": bpy.app.version_string,
        "fbx_addon_version": None,
        "scene_unit_settings": {"system": sc.unit_settings.system, "scale_length": sc.unit_settings.scale_length,
                                "length_unit": sc.unit_settings.length_unit},
        "frame_map": "Blender (x, y, z) BU=cm  ->  Unreal (x, -y, z) cm",
        "armature_export_name": "Armature (renamed during export only; Unreal drops this root node)",
        "static_mesh_args": jsonable(STATIC), "bind_args": jsonable(BIND), "clip_args": jsonable(CLIP),
        "clip_action": baked.name, "clip_source_control_action": FLAP_CTL_ACTION,
        "actions_in_file_not_exported": other_actions,
        "vertex_colour": "corner attribute `Col` (BYTE_COLOR) exported with colors_type=SRGB: RGB = albedo palette "
                         "as sRGB bytes, A = cavity/occlusion (linear 0..1)",
        "uv0": "UV layer `UV0` (lightmap-packed, non-overlapping)",
        "morph_targets": "none (no corrective shape keys were needed)",
        "files": {k: {"path": v, "bytes": os.path.getsize(v), "header": fbx_header(v)} for k, v in files.items()},
    }
    try:
        import addon_utils
        for m in addon_utils.modules():
            if m.__name__ in ("io_scene_fbx", "bl_ext.system.io_scene_fbx"):
                settings["fbx_addon_version"] = ".".join(str(x) for x in m.bl_info.get("version", ()))
    except Exception as e:
        settings["fbx_addon_version"] = "unknown (%s)" % e
    with open(os.path.join(VAL, "export_settings.json"), "w") as fh:
        json.dump(settings, fh, indent=1)
    with open(os.path.join(VAL, "expected.json"), "w") as fh:
        json.dump(expected, fh, indent=1)
    for k, v in settings["files"].items():
        print("EXPORTED %-6s %8d bytes  header %s" % (k, v["bytes"], json.dumps(v["header"])))
    if len(expected["bones"]) != 42:
        fails.append("bones %d" % len(expected["bones"]))
    if fails:
        print("CELLAR_BAT_FAIL " + "; ".join(fails))
        sys.exit(1)
    print("CELLAR_BAT_OK")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        print("CELLAR_BAT_FAIL exception")
        sys.exit(1)
