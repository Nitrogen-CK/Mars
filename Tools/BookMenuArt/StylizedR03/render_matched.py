"""Matched studio cameras: compare actual R02/R03 meshes without reframing."""
import bpy,json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parent
out=root/'Evidence/MatchedModel';out.mkdir(exist_ok=True)
report={}
for revision in ['StylizedR02','StylizedR03']:
    source=root.parent/revision/'Model'/('Cookbook_'+revision+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene=bpy.context.scene
    arm=bpy.data.objects['Cookbook_Slim_Armature']
    cam=scene.camera
    for label,kind,direction,scale,center in [
        ('closed','Book_Lying_R_01',(.32,-.64,1.25),.36,(.0862,0,.01424)),
        ('side','Book_Lying_R_01',(1,-.3,.16),.32,(.0862,0,.01424)),
        ('open','Book_Lying_Open_01',(.1,-.48,1.5),.46,(0,0,.01424))]:
        act=bpy.data.actions[kind];arm.animation_data.action=act
        arm.animation_data.action_slot=act.slots[0];scene.frame_set(1)
        target=Vector(center);cam.location=target+Vector(direction).normalized()*1.4
        cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.ortho_scale=scale;scene.render.resolution_x=1400;scene.render.resolution_y=1100
        scene.render.resolution_percentage=100
        scene.render.filepath=str(out/(revision+'_'+label+'.png'))
        bpy.ops.render.render(write_still=True)
        report[revision+'_'+label]={'location':list(cam.location),'rotation':list(cam.rotation_euler),'ortho_scale':scale,'source':str(source)}
(out/'cameras.json').write_text(json.dumps(report,indent=2))
print('MATCHED_MODEL_CAMERAS_COMPLETE')

