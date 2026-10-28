"""Stage 4: export the worn book for Unreal (ToUnreal/SK_Book_Worn.fbx). The .blend is not modified.

    blender -b Tools/BookMenuArt/Blender/BookMenu_Worn.blend --python Tools/BookMenuArt/blender_export.py

The root Empty goes back to its Unreal scale for the export, so the FBX skeleton is the original Anim_Book_Skeleton
(same bones, same rest pose) and the mesh reimports onto SK_Book_01 / that skeleton with the existing animations and
AnimBP untouched. The 25 cm size is applied in Unreal as a uniform 0.669 scale on the book's mesh component (the value
is printed below and stored on the root as page_width_cm / ue_root_scale).

Mesh only: no animation (the sequences are unchanged), no materials beyond slot names, no textures. Exported UV
channels: UV0 DiffuseUV, UV1 LightMapUV, UV2 DiffuseUV.001, UV3 StainUV. Shape keys export as the PageBend_* morphs.
"""

import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_common as bc  # noqa: E402

OUT = os.path.join(bc.TO_UNREAL_DIR, "SK_Book_Worn.fbx")


def main():
    root, arm, mesh = bc.get_rig()
    k = root.scale[0] / root["ue_root_scale"]
    page_width = root["page_width_cm"]

    # Rest geometry only: no pose, no morph mix baked into the base mesh.
    arm.data.pose_position = "REST"
    for prop in bc.MORPH_CURVES:
        arm[prop] = 0.0
    if mesh.data.shape_keys.animation_data:
        for fc in mesh.data.shape_keys.animation_data.drivers:
            fc.mute = True
    for key in mesh.data.shape_keys.key_blocks:
        key.value = 0.0
    root.scale = (root["ue_root_scale"],) * 3
    # Blender writes the Empty as an FBX Null, and Unreal's skeleton import walks up through Nulls into the bone tree
    # (88 bones instead of Anim_Book_Skeleton's 87 -> "FAILED TO MERGE BONES"). Its one exception is a top-level Null
    # named "Armature", which it skips as Blender's armature dummy. The file is not saved, so the rename is export-only.
    root.name = "Armature"
    bpy.context.view_layer.update()

    bpy.ops.object.select_all(action="DESELECT")
    for obj in (root, arm, mesh):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bc.ensure_dir(bc.TO_UNREAL_DIR)
    bpy.ops.export_scene.fbx(
        filepath=OUT, use_selection=True, object_types={"EMPTY", "ARMATURE", "MESH"},
        global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE", bake_space_transform=False,
        axis_forward="-Z", axis_up="Y",
        use_mesh_modifiers=True, mesh_smooth_type="FACE", use_triangles=True, use_tspace=False, colors_type="SRGB",
        add_leaf_bones=False, primary_bone_axis="Y", secondary_bone_axis="X", use_armature_deform_only=False,
        armature_nodetype="NULL", bake_anim=False, use_custom_props=False, path_mode="STRIP", embed_textures=False)
    print(f"EXPORT ok: {OUT}")
    print(f"EXPORT Unreal component scale for a {page_width} cm page: {k:.4f}")


main()
