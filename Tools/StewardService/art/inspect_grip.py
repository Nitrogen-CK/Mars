"""Read the saved rendered pose and record actual wrist bend/palm frames."""
import bpy,json,math,sys
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parents[1]/'Output/Art'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'StewardService_Review.blend'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
def p(n):return arm.matrix_world @ arm.pose.bones[n].head
rows={}
for s in ['l','r']:
    wrist=p('hand_'+s);long=p('middle_01_'+s)-wrist
    forearm=wrist-p('lowerarm_'+s)
    rows[s]=dict(wrist_cm=list(wrist*100),finger_direction=list(long.normalized()),
                 wrist_bend_deg=math.degrees(forearm.angle(long)),
                 knuckles_cm={f:list(p(f+'_01_'+s)*100) for f in ['index','middle','ring','pinky','thumb']})
print('GRIP_INSPECTION',json.dumps(rows))
report_name=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'grip_before_correction.json'
(OUT/report_name).write_text(json.dumps(rows,indent=2))
