"""Independently reimport saved FBXs and compare skeleton/rest-space scale."""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parents[1]/'Output/Art'
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_service as spec
def skin(path):
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=str(path),use_anim=False)
    o=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    return [(o.matrix_world @ v.co,{o.vertex_groups[g.group].name:g.weight for g in v.groups}) for v in o.data.vertices]
source_skin=skin(OUT/'Steward_Source.fbx');service_skin=skin(OUT/'Steward_Service_Mars_SK.fbx')
def key(p):return tuple(round(v,4) for v in p)
service_lookup={}
for p,weights in service_skin:service_lookup.setdefault(key(p),[]).append(weights)
hand_checked=0
for p,weights in source_skin:
    if abs(p.x)>.47 and .99<p.z<1.39:
        candidates=service_lookup.get(key(p),[])
        if not candidates:
            # FBX float serialization can cross a decimal rounding boundary
            # (observed 0.000000178m delta). Compare spatial tolerance directly.
            candidates=[w for q,w in service_skin if (q-p).length<1e-5]
        assert candidates,'Missing hand vertex within 0.001cm'
        assert min(max(abs(weights.get(n,0)-w.get(n,0)) for n in set(weights)|set(w)) for w in candidates)<2e-5
        hand_checked+=1
assert hand_checked>500,hand_checked
def rig(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(path),use_anim=False)
    arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    return {b.name:dict(parent=b.parent.name if b.parent else None,
                       head=list(arm.matrix_world @ b.head_local)) for b in arm.data.bones}
source=rig(OUT/'Steward_Source.fbx');present=rig(OUT/'Steward_Present_Mars_AS.fbx')
service=rig(OUT/'Steward_Service_Mars_SK.fbx')
assert set(source)==set(service)
assert all(source[k]['parent']==service[k]['parent'] for k in source)
service_rest_error=max((Vector(source[k]['head'])-Vector(service[k]['head'])).length*100 for k in source)
assert service_rest_error<.001,service_rest_error
assert set(source)==set(present),(set(source)^set(present))
assert all(source[k]['parent']==present[k]['parent'] for k in source)
rest_error=max((Vector(source[k]['head'])-Vector(present[k]['head'])).length*100 for k in source)
(OUT/'roundtrip_inspection.json').write_text(json.dumps(dict(source=source,present=present),indent=2))
# An animation-only FBX stores the exported current pose as its default node pose.
# It is imported against the existing skeleton, never as a replacement skeleton.
# Verify unmodified scale/lengths and exported hand contacts instead of mistaking
# its holding default pose for the original A-pose reference skeleton.
length_errors=[]
for upper,child in [('upperarm_l','lowerarm_l'),('lowerarm_l','hand_l'),('upperarm_r','lowerarm_r'),('lowerarm_r','hand_r')]:
    a=(Vector(source[upper]['head'])-Vector(source[child]['head'])).length
    b=(Vector(present[upper]['head'])-Vector(present[child]['head'])).length
    length_errors.append(abs(a-b)*100)
assert max(length_errors)<.01,length_errors
for side,sgn in [('l',1),('r',-1)]:
    assert (Vector(present['hand_'+side]['head'])-spec.wrist_target(sgn)).length<.0001
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(OUT/'ServiceParchment_Mars_SM.fbx'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH')
dimensions=list(o.dimensions)
assert abs(dimensions[1]-spec.ROLL_WIDTH)<.001,dimensions
assert 2.08<dimensions[2]<2.12,dimensions
assert .69<dimensions[0]<.73,dimensions
world_vertices=[o.matrix_world @ v.co for v in o.data.vertices]
floor_height=min(v.z for v in world_vertices)+spec.PAPER_HEIGHT
assert 0<=floor_height<=.04,floor_height
floor_vertices=[v for v in world_vertices if 0<=v.z+spec.PAPER_HEIGHT<=.04]
assert len(floor_vertices)>100,len(floor_vertices)
flat=[v for v in world_vertices if abs(v.x)<1e-6 and abs(v.y)<=spec.READ_WIDTH/2+.0001 and spec.READ_BOTTOM-.0001<=v.z<=spec.READ_TOP+.0001]
assert len(flat)>=4,'Missing planar reading panel'
report=dict(status='passed',bones=len(source),limb_length_error_cm=max(length_errors),prop_dimensions_metres=dimensions,
            new_service_mesh_rest_head_error_cm=service_rest_error,
            independently_reimported_hand_vertices_unchanged=hand_checked,
            floor_min_height_cm=floor_height*100,floor_region_vertices=len(floor_vertices),
            hierarchy_preserved=True,hold_positions_preserved=True,static_identity_import_scale=True,
            animation_default_pose='holding pose; import animation only on existing skeleton')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(OUT/'Steward_Present_Mars_AS.fbx'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
action=arm.animation_data.action
start,end=map(round,action.frame_range)
assert end-start==180,(start,end)
maximum=0
wrist_bend_max=0
samples=[]
for f in range(start,end+1):
    bpy.context.scene.frame_set(f)
    for side,sgn in [('l',1),('r',-1)]:
        p=arm.matrix_world @ arm.pose.bones['hand_'+side].head
        maximum=max(maximum,(p-spec.wrist_target(sgn)).length*100)
        elbow=arm.matrix_world @ arm.pose.bones['lowerarm_'+side].head
        knuckle=arm.matrix_world @ arm.pose.bones['middle_01_'+side].head
        bend=math.degrees((p-elbow).angle(knuckle-p));wrist_bend_max=max(wrist_bend_max,bend)
        assert (knuckle-p).z>0,'Downward dangling palm returned'
    if f in [start,end]:samples.append({b.name:list(b.matrix) for b in arm.pose.bones})
loop_error=max(abs(samples[0][k][r][c]-samples[1][k][r][c]) for k in samples[0] for r in range(4) for c in range(4))
assert maximum<.1,maximum
assert loop_error<1e-4,loop_error
assert wrist_bend_max<65,wrist_bend_max
report.update(animation_frames=[start,end],sampled_frames=end-start+1,max_roundtrip_contact_error_cm=maximum,loop_matrix_error=loop_error)
report['max_wrist_bend_deg']=wrist_bend_max
# Inspect the saved source geometry as well: this tagged region survives in the
# editable blend and proves that the curl's entire return arc clears the UI.
bpy.ops.wm.open_mainfile(filepath=str(OUT/'StewardService_Review.blend'))
paper=bpy.data.objects['ServiceParchment_Mars_SM'];group=paper.vertex_groups['TopCurl']
curl=[v for v in paper.data.vertices if any(g.group==group.index for g in v.groups)]
assert curl,'Missing tagged top-curl geometry'
curl_min=min(v.co.z for v in curl)
assert curl_min>=spec.READ_TOP-1e-7,curl_min
reading_group=paper.vertex_groups['ReadingPanel']
reading=[v for v in paper.data.vertices if any(g.group==reading_group.index for g in v.groups)]
assert len(reading)==8
assert all(abs(v.co.x)<1e-6 or abs(v.co.x+spec.SHEET_THICKNESS)<1e-6 for v in reading)
assert abs(min(v.co.z for v in reading)-spec.READ_BOTTOM)<1e-6 and abs(max(v.co.z for v in reading)-spec.READ_TOP)<1e-6
profile=json.loads((OUT/'drape_profile.json').read_text())['profile_xz_m']
def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
for i in range(len(profile)-1):
    for j in range(i+2,len(profile)-1):
        a,b,c,d=profile[i],profile[i+1],profile[j],profile[j+1]
        assert not (cross(a,b,c)*cross(a,b,d)<0 and cross(c,d,a)*cross(c,d,b)<0),'Self-crossing drape profile'
report.update(top_curl_min_local_z_cm=curl_min*100,reading_top_local_z_cm=spec.READ_TOP*100,top_curl_reading_overlap=False,
              flat_reading_bounds_cm=[spec.READ_BOTTOM*100,spec.READ_TOP*100],drape_profile_non_crossing=True)
(OUT/'export_validation.json').write_text(json.dumps(report,indent=2))
print('STEWARD_EXPORT_VALIDATION_OK',json.dumps(report))
