"""Render selected models from an already saved library, without resaving it.

Blender --background <library.blend> --python-exit-code 1 --python this.py -- CCS18
"""
import importlib.util,json,sys
from pathlib import Path
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
OUT=HERE/'Output'
s=importlib.util.spec_from_file_location('selected_render_core',HERE.parent/'ChainCrossingKit/build_kit.py')
core=importlib.util.module_from_spec(s);s.loader.exec_module(core)
m=json.loads((OUT/'asset_manifest.json').read_text())
rows={r['id']:r for r in m['assets']+m['shared_assets']}
ids=sys.argv[sys.argv.index('--')+1:]
assert ids and all(i in rows for i in ids)
cols={c.name.split('_')[0]:c for c in bpy.data.collections if c.name.split('_')[0] in rows}
scene=bpy.data.scenes.new('SelectedModelReview');core.setup_scene(scene,'SelectedReview',.55)
scene.render.resolution_x=512;scene.render.resolution_y=512;scene.cycles.samples=8
core.light(scene,'Key',(-4,-5,7),600,size=5);core.light(scene,'Fill',(4,3,5),400,size=4)
cam=core.camera(scene,(4,-6,4),(0,0,.5),4);bpy.context.window.scene=scene
for ident in ids:
    row=rows[ident];obj=core.instance(scene,cols[ident],ident+'_Review',(0,0,0))
    dims=[v/100 for v in row['actual_dimensions_cm']]
    z=0 if row['pivot']=='center' else -dims[2]/2 if row['pivot']=='top contact' else dims[2]/2
    target=Vector((0,0,z));cam.location=target+Vector((4,-6,4))*max(dims)*.8
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=max(dims)*1.6
    scene.render.filepath=str(OUT/'Previews'/(ident+'.png'))
    bpy.context.view_layer.update();bpy.ops.render.render(write_still=True);bpy.data.objects.remove(obj,do_unlink=True)
print('SELECTED_SAVED_MODELS_RENDERED',ids)
