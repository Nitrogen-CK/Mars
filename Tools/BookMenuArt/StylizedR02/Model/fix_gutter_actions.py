"""Patch existing source actions without rebuilding geometry, materials or studio."""
import bpy, math
from mathutils import Vector

arm = bpy.data.objects['Cookbook_Slim_Armature']
root = arm.pose.bones['PageTurn_01']
radius = root.bone.head_local.x
inverse = root.bone.matrix_local.to_3x3().inverted()
scene = bpy.context.scene
original_action, original_slot, original_frame = arm.animation_data.action, arm.animation_data.action_slot, scene.frame_current
for action in bpy.data.actions:
    if not action.name.startswith('Book_'):
        continue
    arm.animation_data.action = action
    arm.animation_data.action_slot = action.slots[0]
    for frame in range(int(action.frame_range[0]), int(action.frame_range[1])+1):
        scene.frame_set(frame)
        angle = root.rotation_euler.y
        root.location = inverse @ Vector((radius*(math.cos(angle)-1), 0, -radius*math.sin(angle)))
        root.keyframe_insert('location', frame=frame, group='PageTurn_01')
arm.animation_data.action, arm.animation_data.action_slot = original_action, original_slot
scene.frame_set(original_frame)
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print('SPINE_HINGE_ACTIONS_SAVED '+bpy.data.filepath)
