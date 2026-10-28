"""Measure the moving sheet against both fixed page rectangles in evaluated poses."""
import bpy, json, os, sys

mesh = bpy.data.objects['SK_Cookbook_StylizedR02']
arm = bpy.data.objects['Cookbook_Slim_Armature']
scene = bpy.context.scene
indices = {}
for name in ['PageA', 'PageB', 'PageC', 'PageD']:
    slot = mesh.data.materials.find(name)
    indices[name] = sorted({i for p in mesh.data.polygons if p.material_index == slot for i in p.vertices})

report = {'source': bpy.data.filepath, 'endpoints': [], 'checks': {}}
for name in ['Book_Lying_Open_Page_Turn_R_to_L_02', 'Book_Lying_Open_Page_Turn_L_to_R_02']:
    action = bpy.data.actions[name]
    arm.animation_data.action = action
    arm.animation_data.action_slot = action.slots[0]
    for frame in [1, 108]:
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        ev = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        left = ('R_to_L' in name) == (frame == 108)
        moving, fixed = ('PageC', 'PageA') if left else ('PageB', 'PageD')
        def bounds(slot):
            pts = [ev.data.vertices[i].co for i in indices[slot]]
            return [[min(p[k] for p in pts)*100, max(p[k] for p in pts)*100] for k in range(3)]
        a, b = bounds(moving), bounds(fixed)
        error = max(abs(a[k][j]-b[k][j]) for k in [0, 1] for j in [0, 1])
        report['endpoints'].append({'action': name, 'frame': frame, 'moving': moving,
            'fixed': fixed, 'moving_bounds_cm': a, 'fixed_bounds_cm': b, 'xy_error_cm': error})
        report['checks'][name+'_'+str(frame)+'_aligned'] = error < .001

path = sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else os.path.join(os.path.dirname(__file__), 'gutter_validation.json')
with open(path, 'w') as stream:
    json.dump(report, stream, indent=2)
print('GUTTER_VALIDATION '+json.dumps(report))
if not all(report['checks'].values()):
    raise RuntimeError('Moving sheet does not land on the fixed page rectangle')
