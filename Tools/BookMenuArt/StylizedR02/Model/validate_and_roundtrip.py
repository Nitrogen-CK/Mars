"""Run on the final demo blend; save independent geometry and FBX evidence."""
import bpy, os, json, math
from mathutils.bvhtree import BVHTree
OUT=os.path.dirname(os.path.abspath(__file__))
mesh=bpy.data.objects['SK_Cookbook_StylizedR02']; arm=bpy.data.objects['Cookbook_Slim_Armature']; scene=bpy.context.scene
report={'source_blend':bpy.data.filepath,'scales':{'mesh':list(mesh.scale),'armature':list(arm.scale)},'turn_surface_intersections':{},'animation_samples':0,'checks':{}}
# The cover must travel through the space ABOVE the book, not beneath its support.
# Bounds magnitudes and endpoint-only checks cannot distinguish those two arcs.
cover_group=mesh.vertex_groups['Cover_L'].index
cover_ids=[v.index for v in mesh.data.vertices if any(g.group==cover_group and g.weight>.5 for g in v.groups)]
cover_samples={}
for name in ['Book_Lying_R_to_Open_01','Book_Lying_Open_to_R_01']:
 act=bpy.data.actions[name]; arm.animation_data.action=act; arm.animation_data.action_slot=act.slots[0]
 frames=[]
 for f in range(1,49):
  scene.frame_set(f); ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
  frames.append([ev.matrix_world@ev.data.vertices[i].co for i in cover_ids])
 cover_samples[name]=frames
opening=cover_samples['Book_Lying_R_to_Open_01']; closing=cover_samples['Book_Lying_Open_to_R_01']
endpoint_floor=min(p.z for frame in [opening[0],opening[-1]] for p in frame)
report['cover_arc']={}
for name,frames in cover_samples.items():
 midpoint=frames[23]
 minimum=min(p.z for frame in frames for p in frame)
 mean=sum(p.z for p in midpoint)/len(midpoint)
 report['cover_arc'][name]={'sampled_frames':48,'minimum_z_cm':minimum*100,'midpoint_mean_z_cm':mean*100}
 report['checks'][name+'_travels_above_book']=minimum>=endpoint_floor-.00001 and mean>.07
mirror_error=max((p-q).length for a,b in zip(opening,reversed(closing)) for p,q in zip(a,b))
report['cover_arc']['opening_closing_reverse_pose_error_metres']=mirror_error
report['checks']['opening_and_closing_are_exact_reverse_poses']=mirror_error<.00001
page_ids={mesh.data.materials.find(s) for s in ['PageA','PageD']}
turn_ids={mesh.data.materials.find(s) for s in ['PageB','PageC']}
static_faces=[tuple(p.vertices) for p in mesh.data.polygons if p.material_index in page_ids]
turn_faces=[tuple(p.vertices) for p in mesh.data.polygons if p.material_index in turn_ids]
for act in bpy.data.actions:
 if 'Page_Turn' not in act.name: continue
 arm.animation_data.action=act; arm.animation_data.action_slot=act.slots[0]; hits=[]
 for f in range(int(act.frame_range[0]),int(act.frame_range[1])+1):
  scene.frame_set(f); ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()); coords=[v.co for v in ev.data.vertices]
  a=BVHTree.FromPolygons(coords,static_faces,all_triangles=False,epsilon=0.0000001)
  b=BVHTree.FromPolygons(coords,turn_faces,all_triangles=False,epsilon=0.0000001)
  pairs=a.overlap(b); report['animation_samples']+=1
  if pairs: hits.append({'frame':f,'triangle_pairs':len(pairs)})
 report['turn_surface_intersections'][act.name]=hits
report['checks']['turning_page_does_not_cross_fixed_page_surfaces']=not any(report['turn_surface_intersections'].values())
report['checks']['unit_object_scales']=all(abs(v-1)<1e-6 for s in report['scales'].values() for v in s)
report['checks']['zero_unweighted_vertices']=all(sum(g.weight for g in v.groups)>.999 for v in mesh.data.vertices)
expected={}
for act in bpy.data.actions:
 arm.animation_data.action=act; arm.animation_data.action_slot=act.slots[0]
 samples=[]
 for f in [int(act.frame_range[0]),int(sum(act.frame_range)/2),int(act.frame_range[1])]:
  scene.frame_set(f); ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()); coords=[ev.matrix_world@v.co for v in ev.data.vertices]
  dim=[max(v[i] for v in coords)-min(v[i] for v in coords) for i in range(3)]
  samples.append({'source_frame':f,'dimensions_metres':dim})
 expected[act.name+'.fbx']=samples
# Do not re-save source. Import exported FBX in a fresh scene and inspect what exists.
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=os.path.join(OUT,'FBX','SK_Cookbook_StylizedR02.fbx'),use_anim=True)
arms=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']; meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
report['fbx_mesh_roundtrip']={'armatures':len(arms),'meshes':len(meshes),'bones':len(arms[0].data.bones),'bone_names':[b.name for b in arms[0].data.bones], 'materials':[m.name for m in meshes[0].data.materials], 'morphs':[k.name for k in meshes[0].data.shape_keys.key_blocks], 'bounds_metres':list(meshes[0].dimensions),'armature_object_scale':list(arms[0].scale),'mesh_object_scale':list(meshes[0].scale)}
report['checks']['fbx_12_bones']=len(arms[0].data.bones)==12
report['checks']['fbx_4_morphs']=len(meshes[0].data.shape_keys.key_blocks)==5
report['checks']['fbx_actual_dimensions_match_portable_mesh']=abs(meshes[0].dimensions.x-.36312)<.0001 and abs(meshes[0].dimensions.y-.26696)<.0001
report['checks']['fbx_first_8_slots']=[m.name.split('.')[0] for m in meshes[0].data.materials][:8]==['Cover','PagesBase','PageA','PageB','PageC','PageD','PageFirst','PageLast']
report['fbx_clip_roundtrip']={}
report['fbx_clip_motion_bounds']={}
for file in sorted(os.listdir(os.path.join(OUT,'FBX'))):
 if not file.startswith('Book_'): continue
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
 before=set(bpy.data.actions)
 bpy.ops.import_scene.fbx(filepath=os.path.join(OUT,'FBX',file),use_anim=True)
 added=[a for a in bpy.data.actions if a not in before]
 report['fbx_clip_roundtrip'][file]=[{'action':a.name,'range':list(a.frame_range)} for a in added]
 imported_mesh=next(o for o in scene.objects if o.type=='MESH'); samples=[]
 for src in expected[file]:
  scene.frame_set(src['source_frame']+1); ev=imported_mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()); coords=[ev.matrix_world@v.co for v in ev.data.vertices]
  dim=[max(v[i] for v in coords)-min(v[i] for v in coords) for i in range(3)]
  samples.append({'source_frame':src['source_frame'],'fbx_frame':src['source_frame']+1,'dimensions_metres':dim,'max_source_error_metres':max(abs(dim[i]-src['dimensions_metres'][i]) for i in range(3))})
 report['fbx_clip_motion_bounds'][file]=samples
report['checks']['six_clip_files_with_importable_animation']=len(report['fbx_clip_roundtrip'])==6 and all(report['fbx_clip_roundtrip'].values())
report['checks']['all_clip_motion_bounds_match_source']=all(s['max_source_error_metres']<.0001 for samples in report['fbx_clip_motion_bounds'].values() for s in samples)
json.dump(report,open(os.path.join(OUT,'roundtrip_validation.json'),'w'),indent=2)
print('ROUNDTRIP_VALIDATION '+json.dumps(report['checks']))
if not all(report['checks'].values()): raise RuntimeError('Validation failed; inspect roundtrip_validation.json')
