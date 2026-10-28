"""Stage 1: assemble the Unreal export into one Blender file (Blender/BookMenu_Source.blend), unmodified.

    blender -b --factory-startup --python Tools/BookMenuArt/blender_assemble.py

- SK_Book_01.fbx imported with bone orientation untouched (the FBX rest pose must round-trip onto Anim_Book_Skeleton).
- Material slots renamed back to their Unreal slot names (the FBX carries material-instance names).
- Each Anims/*.fbx is imported, its action moved onto the one armature (rest poses are identical) and the throw-away
  armature deleted. Every action gets a muted NLA track of the same name so it can be soloed.
- The PageBend_* morph curves (dropped by Blender's FBX importer) are rebuilt from export_report.json as keyed custom
  properties on the armature, with drivers feeding the matching shape keys.
"""

import glob
import json
import os
import sys

import bpy
from bpy_extras import anim_utils

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_common as bc  # noqa: E402

FBX_IMPORT = dict(automatic_bone_orientation=False, ignore_leaf_bones=False, use_custom_normals=True,
                  use_custom_props=False, anim_offset=1.0)
DEFAULT_ACTION = "Book_Lying_R_to_Open_01"


def import_mesh():
    bpy.ops.import_scene.fbx(filepath=os.path.join(bc.UE_EXPORT_DIR, "SK_Book_01.fbx"), **FBX_IMPORT)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    mesh = next(o for o in bpy.data.objects if o.type == "MESH")
    root = arm.parent
    if root is None or root.type != "EMPTY" or abs(root.scale[0] - bc.UE_ROOT_SCALE) > 1e-6 or mesh.parent != arm:
        raise RuntimeError(f"Unexpected FBX hierarchy: root={root and (root.name, root.type, tuple(root.scale))} mesh.parent={mesh.parent}")
    root.name = bc.ROOT_NAME
    arm.name = arm.data.name = bc.ARMATURE_NAME
    mesh.name = mesh.data.name = bc.MESH_NAME
    if len(mesh.material_slots) != len(bc.SLOT_NAMES):
        raise RuntimeError(f"Expected {len(bc.SLOT_NAMES)} material slots, got {len(mesh.material_slots)}")
    for slot, name in zip(mesh.material_slots, bc.SLOT_NAMES):
        slot.material.name = name
    if [uv.name for uv in mesh.data.uv_layers] != [bc.UV_BASE, bc.UV_LIGHTMAP, bc.UV_UNIQUE]:
        raise RuntimeError(f"Unexpected UV layers {[uv.name for uv in mesh.data.uv_layers]}")
    return arm, mesh


def strip_object_transform_curves(action, slot, rest_world):
    """The anim FBX keys the armature *object* too (constant root transform, in world space since that armature has no
    parent). Left in, it would override the armature's local transform under the root Empty and shrink the book, so it
    is removed after checking it really is the armature's rest world transform."""
    cb = anim_utils.action_get_channelbag_for_slot(action, slot)
    loc, rot, scale = rest_world.decompose()
    rest = {"location": tuple(loc), "rotation_euler": tuple(rot.to_euler()), "scale": tuple(scale)}
    for fc in [fc for fc in cb.fcurves if fc.data_path in rest]:
        values = [k.co[1] for k in fc.keyframe_points]
        expected = rest[fc.data_path][fc.array_index]
        if max(abs(v - values[0]) for v in values) > 1e-4:
            raise RuntimeError(f"{action.name}: object {fc.data_path}[{fc.array_index}] is animated; refusing to drop it")
        if fc.data_path != "rotation_euler" and abs(values[0] - expected) > 1e-3:
            raise RuntimeError(f"{action.name}: object {fc.data_path}[{fc.array_index}]={values[0]:.4f} != rest {expected:.4f}")
        cb.fcurves.remove(fc)


def import_actions(arm, report):
    arm.animation_data_create()
    names = []
    for path in sorted(glob.glob(os.path.join(bc.UE_EXPORT_DIR, "Anims", "*.fbx"))):
        name = os.path.splitext(os.path.basename(path))[0]
        objects_before, actions_before = set(bpy.data.objects), set(bpy.data.actions)
        bpy.ops.import_scene.fbx(filepath=path, **FBX_IMPORT)
        new_objects = [o for o in bpy.data.objects if o not in objects_before]
        new_actions = [a for a in bpy.data.actions if a not in actions_before]
        if len(new_actions) != 1:
            raise RuntimeError(f"{name}: expected 1 imported action, got {[a.name for a in new_actions]}")
        action = new_actions[0]
        action.name = name
        action.use_fake_user = True
        strip_object_transform_curves(action, action.slots[0], arm.matrix_world)
        add_morph_curves(action, action.slots[0], report["anims"].get(name, {}).get("curves", {}))
        for o in new_objects:
            data = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if data is not None and data.users == 0:
                (bpy.data.armatures if isinstance(data, bpy.types.Armature) else bpy.data.meshes).remove(data)
        names.append(name)

    for name in names:
        action = bpy.data.actions[name]
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, int(action.frame_range[0]), action)
        strip.action_slot = action.slots[0]
        track.mute = True
    return names


def add_morph_curves(action, slot, curves):
    cb = anim_utils.action_get_channelbag_for_slot(action, slot)
    for curve_name, data in curves.items():
        prop = next((m for m in bc.MORPH_CURVES if m.lower() == curve_name.lower()), None)
        if prop is None:
            print(f"WARN {action.name}: curve {curve_name} has no matching shape key; skipped")
            continue
        fc = cb.fcurves.new(data_path=f'["{prop}"]', index=0)
        fc.keyframe_points.add(len(data["times"]))
        for kp, t, v in zip(fc.keyframe_points, data["times"], data["values"]):
            kp.co = (1.0 + t * bc.FPS, v)
            kp.interpolation = "BEZIER"
            kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
        fc.update()


def add_morph_drivers(arm, mesh):
    for prop in bc.MORPH_CURVES:
        arm[prop] = 0.0
        arm.id_properties_ui(prop).update(min=0.0, max=1.0, soft_min=0.0, soft_max=1.0)
        key = mesh.data.shape_keys.key_blocks[prop]
        fc = key.driver_add("value")
        fc.driver.type = "AVERAGE"
        var = fc.driver.variables.new()
        var.type = "SINGLE_PROP"
        var.targets[0].id_type = "OBJECT"
        var.targets[0].id = arm
        var.targets[0].data_path = f'["{prop}"]'


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps, scene.render.fps_base = bc.FPS, 1.0

    with open(os.path.join(bc.UE_EXPORT_DIR, "export_report.json")) as f:
        report = json.load(f)

    arm, mesh = import_mesh()
    bpy.context.view_layer.update()
    names = import_actions(arm, report)
    add_morph_drivers(arm, mesh)

    default = bpy.data.actions[DEFAULT_ACTION]
    arm.animation_data.action = default
    arm.animation_data.action_slot = default.slots[0]
    scene.frame_start, scene.frame_end = (int(x) for x in default.frame_range)
    scene.frame_set(scene.frame_start)

    bc.ensure_dir(bc.BLEND_DIR)
    bpy.ops.wm.save_as_mainfile(filepath=bc.SOURCE_BLEND)
    print(f"ASSEMBLE ok: {bc.SOURCE_BLEND} actions={names}")


main()
