"""Render low-cost motion evidence from the saved final blend; no source writes."""
import bpy,os
from mathutils import Vector
OUT=os.path.dirname(os.path.abspath(__file__)); scene=bpy.context.scene; arm=bpy.data.objects['Cookbook_Slim_Armature']
scene.render.resolution_x=700; scene.render.resolution_y=550; scene.render.resolution_percentage=100; scene.eevee.taa_render_samples=32
cam=scene.camera; center=Vector((.015,0,.043)); cam.location=center+Vector((.12,-.65,1.25)); cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.ortho_scale=.48
os.makedirs(os.path.join(OUT,'MotionFrames'),exist_ok=True)
shots=[('Book_Lying_R_01',1)]*3
shots += [('Book_Lying_R_to_Open_01',f) for f in range(1,49,4)]
shots += [('Book_Lying_Open_Page_Turn_R_to_L_02',f) for f in range(1,109,6)]
shots += [('Book_Lying_Open_Page_Turn_L_to_R_02',f) for f in range(1,109,6)]
shots += [('Book_Lying_Open_to_R_01',f) for f in range(1,49,4)]
shots += [('Book_Lying_R_01',1)]*3
for i,(name,f) in enumerate(shots):
 act=bpy.data.actions[name]; arm.animation_data.action=act; arm.animation_data.action_slot=act.slots[0]; scene.frame_set(f)
 scene.render.filepath=os.path.join(OUT,'MotionFrames','%03d.png'%i); bpy.ops.render.render(write_still=True)
print('MOTION_RENDER_COMPLETE frames=%d'%len(shots))
