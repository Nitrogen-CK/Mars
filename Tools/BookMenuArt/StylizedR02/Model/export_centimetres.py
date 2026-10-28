"""Export the saved metre-based cookbook as true centimetre FBXs.

Blender's FBX_SCALE_NONE normally puts the m->cm factor on the armature dummy.
Unreal strips that dummy but can retain rest scale100 and animation scale1.
Instead author a temporary cm-coordinate representation in memory, export with
scene unit .01 (FBX global matrix scale1), then restore the original data.
The source .blend is never saved by this script.
"""
import bpy, os, json, hashlib

OUT=os.path.dirname(os.path.abspath(__file__))

def location_curves():
 for action in bpy.data.actions:
  if not action.name.startswith('Book_'): continue
  for layer in action.layers:
   for strip in layer.strips:
    for bag in strip.channelbags:
     for curve in bag.fcurves:
      if curve.data_path.endswith('.location'): yield curve

def export_centimetres(mesh,arm):
 scene=bpy.context.scene
 saved={
  'unit':scene.unit_settings.scale_length,'name':arm.name,'pose_position':arm.data.pose_position,
  'vertices':[v.co.copy() for v in mesh.data.vertices],
  'keys':{k.name:[v.co.copy() for v in k.data] for k in mesh.data.shape_keys.key_blocks},
  'bones':{b.name:(b.head_local.copy(),b.tail_local.copy()) for b in arm.data.bones},
  'action':arm.animation_data.action,'frame':scene.frame_current,'start':scene.frame_start,'end':scene.frame_end,
 }
 report={'source_blend':bpy.data.filepath,'export_coordinate_unit':'centimetres','export_scene_scale_length':.01,'mesh_object_scale':list(mesh.scale),'armature_object_scale':list(arm.scale),'source_scene_scale_length':saved['unit'],'files':{}}
 saved['location_keys']=[(p,p.co.copy(),p.handle_left.copy(),p.handle_right.copy()) for curve in location_curves() for p in curve.keyframe_points]
 bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); mesh.select_set(True); bpy.context.view_layer.objects.active=arm
 try:
  for point,co,left,right in saved['location_keys']:
   point.co.y=co.y*100; point.handle_left.y=left.y*100; point.handle_right.y=right.y*100
  # Set both KeyBlock Basis and independent Mesh vertices to the cm coordinates.
  for key in mesh.data.shape_keys.key_blocks:
   for v,co in zip(key.data,saved['keys'][key.name]): v.co=co*100
  for v,co in zip(mesh.data.vertices,saved['vertices']): v.co=co*100
  mesh.data.update()
  bpy.ops.object.mode_set(mode='EDIT')
  saved['rolls']={b.name:b.roll for b in arm.data.edit_bones}
  for b in arm.data.edit_bones:
   head,tail=saved['bones'][b.name]; b.head=head*100; b.tail=tail*100
  bpy.ops.object.mode_set(mode='OBJECT')
  scene.unit_settings.scale_length=.01; arm.name='Armature'
  bpy.context.view_layer.update()
  report['root_rest_local_scale']=list(arm.data.bones['Master'].matrix_local.to_scale())
  report['cover_hinge_local_cm']=list(arm.data.bones['Cover_L'].head_local)
  report['page_turn_hinge_local_cm']=list(arm.data.bones['PageTurn_01'].head_local)
  settings=dict(use_selection=True,object_types={'ARMATURE','MESH'},global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_NONE',axis_forward='-Z',axis_up='Y',use_mesh_modifiers=False,mesh_smooth_type='FACE',use_triangles=True,add_leaf_bones=False,primary_bone_axis='Y',secondary_bone_axis='X',use_armature_deform_only=False,bake_anim_use_all_bones=True,bake_anim_use_nla_strips=False,bake_anim_use_all_actions=False,bake_anim_simplify_factor=0,path_mode='STRIP',use_custom_props=True)
  os.makedirs(os.path.join(OUT,'FBX'),exist_ok=True)
  arm.data.pose_position='REST'
  path=os.path.join(OUT,'FBX','SK_Cookbook_StylizedR02.fbx')
  bpy.ops.export_scene.fbx(filepath=path,bake_anim=False,**settings)
  report['files'][os.path.basename(path)]={'bytes':os.path.getsize(path),'kind':'skeletal mesh'}
  arm.data.pose_position='POSE'
  for act in sorted(bpy.data.actions,key=lambda a:a.name):
   if not act.name.startswith('Book_'): continue
   arm.animation_data.action=act; arm.animation_data.action_slot=act.slots[0]
   scene.frame_start=int(act.frame_range[0]); scene.frame_end=int(act.frame_range[1]); scene.frame_set(scene.frame_start)
   bpy.context.view_layer.update()
   root=arm.pose.bones['Master']
   assert all(abs(v-1)<1e-6 for v in root.scale), 'Animated Master scale must remain1'
   path=os.path.join(OUT,'FBX',act.name+'.fbx')
   bpy.ops.export_scene.fbx(filepath=path,bake_anim=True,**settings)
   report['files'][os.path.basename(path)]={'bytes':os.path.getsize(path),'frames':[scene.frame_start,scene.frame_end],'root_pose_scale':list(root.scale)}
 finally:
  for point,co,left,right in saved['location_keys']:
   point.co=co; point.handle_left=left; point.handle_right=right
  arm.name=saved['name']; scene.unit_settings.scale_length=saved['unit']
  for key in mesh.data.shape_keys.key_blocks:
   for v,co in zip(key.data,saved['keys'][key.name]): v.co=co
  for v,co in zip(mesh.data.vertices,saved['vertices']): v.co=co
  mesh.data.update()
  bpy.context.view_layer.objects.active=arm; bpy.ops.object.mode_set(mode='EDIT')
  for b in arm.data.edit_bones:
   b.head,b.tail=saved['bones'][b.name]; b.roll=saved['rolls'][b.name]
  bpy.ops.object.mode_set(mode='OBJECT'); arm.data.pose_position=saved['pose_position']
  arm.animation_data.action=saved['action']; arm.animation_data.action_slot=saved['action'].slots[0]
  scene.frame_start=saved['start']; scene.frame_end=saved['end']; scene.frame_set(saved['frame']); bpy.context.view_layer.update()
 report['source_data_restored']=all((v.co-co).length<1e-10 for v,co in zip(mesh.data.vertices,saved['vertices']))
 report['location_keys_restored']=all((p.co-co).length<1e-10 and (p.handle_left-left).length<1e-10 and (p.handle_right-right).length<1e-10 for p,co,left,right in saved['location_keys'])
 return report

if __name__=='__main__':
 source=bpy.data.filepath
 before=hashlib.sha256(open(source,'rb').read()).hexdigest()
 report=export_centimetres(bpy.data.objects['SK_Cookbook_StylizedR02'],bpy.data.objects['Cookbook_Slim_Armature'])
 after=hashlib.sha256(open(source,'rb').read()).hexdigest()
 report['source_blend_sha256_before']=before; report['source_blend_sha256_after']=after; report['source_file_unchanged']=before==after
 json.dump(report,open(os.path.join(OUT,'cm_export_report.json'),'w'),indent=2)
 print('CENTIMETRE_EXPORT_COMPLETE '+json.dumps({'source_file_unchanged':report['source_file_unchanged'],'root_rest_local_scale':report['root_rest_local_scale'],'cover_hinge_local_cm':report['cover_hinge_local_cm'],'exports':len(report['files'])}))
 assert report['source_file_unchanged'] and report['source_data_restored'] and report['location_keys_restored']
