"""Export a posed static proxy with the same pivot and materials as the rig."""
import bpy, json
from pathlib import Path
from mathutils import Vector

root = Path(__file__).resolve().parent
arm = bpy.data.objects['Cookbook_Slim_Armature']
source = bpy.data.objects['SK_Cookbook_StylizedR02']
action = bpy.data.actions['Book_Lying_R_01']
arm.animation_data.action = action
arm.animation_data.action_slot = action.slots[0]
bpy.context.scene.frame_set(int(action.frame_range[0]))
bpy.context.view_layer.update()
evaluated = source.evaluated_get(bpy.context.evaluated_depsgraph_get())
mesh = bpy.data.meshes.new_from_object(evaluated)
proxy = bpy.data.objects.new('SM_Cookbook_Closed', mesh)
bpy.context.collection.objects.link(proxy)
proxy.matrix_world = source.matrix_world
bounds = [proxy.matrix_world @ v.co for v in mesh.vertices]
lo = [min(v[i] for v in bounds)*100 for i in range(3)]
hi = [max(v[i] for v in bounds)*100 for i in range(3)]
# UE legacy FBX import mirrors Blender Y, retaining the book's X/Z axes.
report = {'blender_min_cm': lo, 'blender_max_cm': hi,
          'unreal_min_cm': [lo[0], -hi[1], lo[2]],
          'unreal_max_cm': [hi[0], -lo[1], hi[2]],
          'pivot': 'spine centre, pages +X, page normal +Z, spine along Y'}
bpy.ops.object.select_all(action='DESELECT')
proxy.select_set(True)
bpy.context.view_layer.objects.active = proxy
for vertex in mesh.vertices:
    vertex.co *= 100
bpy.context.scene.unit_settings.scale_length = .01
bpy.ops.export_scene.fbx(filepath=str(root/'FBX'/'SM_Cookbook_Closed.fbx'),
    use_selection=True, object_types={'MESH'}, bake_anim=False, add_leaf_bones=False,
    axis_forward='-Z', axis_up='Y', apply_unit_scale=True,
    apply_scale_options='FBX_SCALE_NONE', use_triangles=True, path_mode='STRIP')
(root/'closed_proxy_report.json').write_text(json.dumps(report, indent=2))
print('CLOSED_PROXY '+json.dumps(report))
