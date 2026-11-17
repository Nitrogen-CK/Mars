"""Check the user's open-spine concern and individual turning-sheet thickness."""
import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parent
mesh=bpy.data.objects['SK_Cookbook_StylizedR03']
arm=bpy.data.objects['Cookbook_Slim_Armature']
scene=bpy.context.scene
group=mesh.vertex_groups['Spine'].index
ids=[v.index for v in mesh.data.vertices if any(g.group==group and g.weight>.5 for g in v.groups)]
report={'poses':{},'checks':{}}
for label,name in [('closed','Book_Lying_R_01'),('open','Book_Lying_Open_01')]:
    act=bpy.data.actions[name];arm.animation_data.action=act
    arm.animation_data.action_slot=act.slots[0];scene.frame_set(1);bpy.context.view_layer.update()
    ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    coords=[ev.data.vertices[i].co for i in ids]
    zmin=min(p.z for p in coords);zmax=max(p.z for p in coords)
    report['poses'][label]={'spineMinCm':zmin*100,'spineMaxCm':zmax*100,'depthCm':(zmax-zmin)*100,
                            'spineScale':list(arm.pose.bones['Spine'].scale),
                            'spineLocationMetres':list(arm.pose.bones['Spine'].location)}
    if label=='open':
        slot=mesh.data.materials.find('PageD')
        pageids={i for p in mesh.data.polygons if p.material_index==slot for i in p.vertices}
        pagez=max(ev.data.vertices[i].co.z for i in pageids)
        report['openSpineCrownAboveReadingPlaneMm']=(zmax-pagez)*1000
# Measured rest-mesh sheet faces; local bone bend poses are irrelevant to rim width.
slots={mesh.data.materials.find(n) for n in ['PageB','PageC']}
zs=[mesh.data.vertices[i].co.z for p in mesh.data.polygons if p.material_index in slots for i in p.vertices]
report['turningSheetAuthorThicknessMm']=(max(zs)-min(zs))*1000
report['turningSheetRuntimeThicknessMm']=report['turningSheetAuthorThicknessMm']*1.2
report['checks']['openBindingDepthIs32Percent']=abs(report['poses']['open']['depthCm']/report['poses']['closed']['depthCm']-.32)<1e-5
report['checks']['openBindingCrownLessThan4mmAbovePage']=report['openSpineCrownAboveReadingPlaneMm']<4
report['checks']['turningSheetRuntimeThicknessAbovePoint7mm']=report['turningSheetRuntimeThicknessMm']>.7
report['checks']['referenceOpenScaleOne']=all(abs(x-1)<1e-6 for x in report['poses']['open']['spineScale'])
(root/'spine_page_validation.json').write_text(json.dumps(report,indent=2))
print('SPINE_PAGE_VALIDATION '+json.dumps(report))
assert all(report['checks'].values())

