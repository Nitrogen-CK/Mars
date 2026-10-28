import bpy, json, os
from mathutils import Vector
out=os.path.dirname(__file__)
arm=bpy.data.objects['Book_Armature']; mesh=bpy.data.objects['SK_Book_01']; root=bpy.data.objects['SK_Book_01_Root']
info={'root_scale':list(root.scale),'root_props':dict(root.items()),'mesh_matrix':[list(r) for r in mesh.matrix_world], 'bones':[], 'materials':[x.name for x in mesh.data.materials], 'shapes':[], 'states':{}}
for b in arm.data.bones:
 info['bones'].append({'name':b.name,'parent':b.parent.name if b.parent else None,'head':list(b.head_local),'tail':list(b.tail_local)})
if mesh.data.shape_keys: info['shapes']=[k.name for k in mesh.data.shape_keys.key_blocks]
for tr in arm.animation_data.nla_tracks: tr.mute=True
for act in bpy.data.actions:
 arm.animation_data.action=act; arm.animation_data.action_slot=act.slots[0]
 for f in [int(act.frame_range[0]),int(sum(act.frame_range)/2),int(act.frame_range[1])]:
  bpy.context.scene.frame_set(f); ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()); pts=[ev.matrix_world@v.co for v in ev.data.vertices]
  mn=[min(p[i] for p in pts) for i in range(3)]; mx=[max(p[i] for p in pts) for i in range(3)]
  info['states'][act.name+':'+str(f)]={'min':mn,'max':mx,'dims':[mx[i]-mn[i] for i in range(3)]}
arm.data.pose_position='REST'; bpy.context.view_layer.update()
info['material_bounds']={}
for i,m in enumerate(mesh.data.materials):
 ids=set(v for p in mesh.data.polygons if p.material_index==i for v in p.vertices); pts=[mesh.data.vertices[v].co for v in ids]
 groups={}
 for vi in ids:
  for g in mesh.data.vertices[vi].groups:
   n=mesh.vertex_groups[g.group].name; groups[n]=groups.get(n,0)+g.weight
 info['material_bounds'][m.name]={'vertices':len(ids),'min':[min(p[j] for p in pts) for j in range(3)],'max':[max(p[j] for p in pts) for j in range(3)],'groups':groups}
json.dump(info,open(os.path.join(out,'source_inspection.json'),'w'),indent=2)
print(json.dumps(info,indent=2))
