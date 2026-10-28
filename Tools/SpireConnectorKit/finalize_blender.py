"""Refresh library framing/catalog metadata in saved scenes without re-exporting geometry."""
import bpy,uuid,math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;OUT=HERE/'Output';s=bpy.data.scenes['Spire_KitLibrary']
cam=next(o for o in s.objects if o.type=='CAMERA');height=math.ceil(sum(o.type=='MESH' for o in s.objects)/10)*9
cam.location=(40,-(height-9)*.5,100);cam.rotation_euler=(Vector((40,-(height-9)*.5,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=max(110,(height+10)*1.2)
cats=['Architecture','Props','Hero','Supports','Collision','Presentation']
(OUT/'Blender/blender_assets.cats.txt').write_text('VERSION 1\n\n'+'\n'.join(f'{uuid.uuid5(uuid.NAMESPACE_URL,"SpireConnectorKit/"+x)}:Spire/{x}:{x}' for x in cats)+'\n')
o=bpy.data.objects['Spire_AxisGauge_Mars_SM'];o.asset_data.catalog_id=str(uuid.uuid5(uuid.NAMESPACE_URL,'SpireConnectorKit/Presentation'))
for key in ['HS','BW','RW','HL','KitLibrary','Diorama']:
 bpy.context.window.scene=bpy.data.scenes['Spire_'+key];bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Blender'/('Spire_'+key+'.blend')),copy=True)
print('SPIRE_LIBRARY_METADATA_REFRESHED',flush=True)
library_dir=OUT/'AssetLibrary';library_dir.mkdir(exist_ok=True)
(library_dir/'blender_assets.cats.txt').write_text((OUT/'Blender/blender_assets.cats.txt').read_text())
bpy.context.window.scene=s;bpy.ops.wm.save_as_mainfile(filepath=str(library_dir/'Spire_Assets.blend'),copy=True)
