import bpy,sys,json,collections
from pathlib import Path
from mathutils import Vector
from mathutils.geometry import barycentric_transform,intersect_point_tri_2d
root=Path(__file__).resolve().parent
sys.path.insert(0,str(root.parents[2]))
import build_kit
from generators import architecture
part=next(p for p in build_kit.parts if p['id']=='CCS18')
col=bpy.data.collections.new('VaultDebugVerification');bpy.context.scene.collection.children.link(col)
b=build_kit.Builder(part,build_kit.load_materials(),col);architecture.build(b,part);o,row=build_kit.finish(b)
m=o.data;m.calc_loop_triangles()
below=[t for t in m.loop_triangles if all(i<25 for i in t.vertices)]
above=[t for t in m.loop_triangles if all(25<=i<50 for i in t.vertices)]
def sample(tris,x,y):
 for t in tris:
  v=[m.vertices[i].co for i in t.vertices]
  if intersect_point_tri_2d(Vector((x,y)),*[Vector((c.x,c.y))for c in v]):
   return barycentric_transform(Vector((x,y,0)),*[Vector((c.x,c.y,0))for c in v],*v).z
thickness=[]
for ix in range(1,60):
 for iy in range(1,60):
  x=-1+ix/30;y=-1+iy/30;a,z=sample(below,x,y),sample(above,x,y)
  if a is not None and z is not None:thickness.append(z-a)
edges=collections.Counter(tuple(sorted((p.vertices[j],p.vertices[(j+1)%len(p.vertices)])))for p in m.polygons for j in range(len(p.vertices)))
report={'asset':'CCS18','triangles':sum(len(p.vertices)-2 for p in m.polygons),'vertices':len(m.vertices),'polygons':len(m.polygons),'shell_bottom_triangles':len(below),'shell_top_triangles':len(above),'sample_count':len(thickness),'minimum_thickness_m':min(thickness),'maximum_thickness_m':max(thickness),'nonmanifold_edges':sum(v!=2 for v in edges.values()),'shell_xy_envelope_m':[[min(m.vertices[i].co[k] for i in range(50)),max(m.vertices[i].co[k]for i in range(50))]for k in (0,1)]}
assert min(thickness)>.05
assert report['nonmanifold_edges']==0
assert all(abs(bounds[0]+1)<1e-6 and abs(bounds[1]-1)<1e-6 for bounds in report['shell_xy_envelope_m'])
(root/'current_verification.json').write_text(json.dumps(report,indent=2));print('VAULT_CURRENT_VERIFIED',json.dumps(report),flush=True)
