import bpy, json, math, sys
from pathlib import Path
from mathutils import Vector

root=Path(__file__).resolve().parent
o=next(o for o in bpy.data.objects if o.type=='MESH' and o.get('catalog_id')=='CCS18')
label='saved'
if '--current' in sys.argv:
 sys.path.insert(0,str(Path(__file__).resolve().parents[3]))
 import build_kit
 from generators import architecture
 part=next(p for p in build_kit.parts if p['id']=='CCS18')
 col=bpy.data.collections.new('VaultDebug_Current')
 bpy.context.scene.collection.children.link(col)
 mats=build_kit.load_materials()
 builder=build_kit.Builder(part,mats,col)
 architecture.build(builder,part)
 o,row=build_kit.finish(builder)
 label='current'
mesh=o.data
mesh.calc_loop_triangles()
adj={v.index:set() for v in mesh.vertices}
for e in mesh.edges:
 a,c=e.vertices;adj[a].add(c);adj[c].add(a)
seen=set();islands=[]
for i in adj:
 if i in seen:continue
 todo=[i];inds=[]
 while todo:
  k=todo.pop()
  if k in seen:continue
  seen.add(k);inds.append(k);todo.extend(adj[k]-seen)
 islands.append(inds)
report={'name':o.name,'verts':len(mesh.vertices),'polygons':len(mesh.polygons),'islands':[],'nonplanar':[],'bounds':[[min(v.co[k] for v in mesh.vertices),max(v.co[k] for v in mesh.vertices)] for k in range(3)]}
for inds in islands:
 report['islands'].append({'vertices':len(inds),'bounds':[[min(mesh.vertices[i].co[k] for i in inds),max(mesh.vertices[i].co[k] for i in inds)]for k in range(3)]})
for p in mesh.polygons:
 if len(p.vertices)>3:
  a,b,c=(mesh.vertices[i].co for i in p.vertices[:3]);n=(b-a).cross(c-a).normalized()
  deviation=max(abs((mesh.vertices[i].co-a).dot(n)) for i in p.vertices)
  if deviation>1e-5:report['nonplanar'].append({'polygon':p.index,'deviation_m':deviation,'normal':list(p.normal),'vertices':[list(mesh.vertices[i].co) for i in p.vertices]})
(root/(label+'_inspection.json')).write_text(json.dumps(report,indent=2))
print('VAULT_INSPECTION',json.dumps({k:v for k,v in report.items()if k not in ('nonplanar','islands')}),'nonplanar',len(report['nonplanar']),'islands',len(islands),flush=True)
scene=bpy.data.scenes.new('VaultDebug_Saved');bpy.context.window.scene=scene
mat=bpy.data.materials.new('VaultDebug_Clay');mat.diffuse_color=(.58,.55,.46,1);mat.use_nodes=True;mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.58,.55,.46,1);mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8
for ix in range(-1,2):
 for iy in range(-1,2):
  cp=o.copy();cp.data=o.data.copy();scene.collection.objects.link(cp);cp.location=(ix*2,iy*2,0);cp.data.materials.clear();cp.data.materials.append(mat)
  for p in cp.data.polygons:p.material_index=0
world=bpy.data.worlds.new('VaultDebugWorld');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.16,.16,1);world.node_tree.nodes['Background'].inputs[1].default_value=.3;scene.world=world
def look(obj,target):obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
cd=bpy.data.cameras.new('VaultDebugCamera');cam=bpy.data.objects.new(cd.name,cd);scene.collection.objects.link(cam);cam.location=(4,-5,-4);look(cam,(0,0,.05));cd.type='ORTHO';cd.ortho_scale=9;scene.camera=cam
for name,at,energy,size in [('key',(-2,-2,-4),650,4),('fill',(3,1,-2),300,3)]:
 ld=bpy.data.lights.new(name,'AREA');ld.energy=energy;ld.shape='DISK';ld.size=size;lo=bpy.data.objects.new(name,ld);scene.collection.objects.link(lo);lo.location=at;look(lo,(0,0,0))
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.resolution_x=1200;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.filepath=str(root/(label+'_underside.png'));bpy.ops.render.render(write_still=True)
