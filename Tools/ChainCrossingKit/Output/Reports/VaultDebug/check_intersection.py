import bpy,json
from pathlib import Path
from mathutils import Vector
from mathutils.geometry import barycentric_transform,intersect_point_tri_2d
o=next(o for o in bpy.data.objects if o.type=='MESH' and o.get('catalog_id')=='CCS18');m=o.data;m.calc_loop_triangles()
results=[]
for cell in range(16):
 down=2*cell;up=down+1
 dt=[t for t in m.loop_triangles if t.polygon_index==down];ut=[t for t in m.loop_triangles if t.polygon_index==up]
 if not dt or not ut:continue
 verts=[m.vertices[i].co for i in m.polygons[down].vertices]
 x0,x1=min(v.x for v in verts),max(v.x for v in verts);y0,y1=min(v.y for v in verts),max(v.y for v in verts)
 def sample(tris,x,y):
  p=Vector((x,y))
  for t in tris:
   v=[m.vertices[i].co for i in t.vertices];q=[Vector((c.x,c.y))for c in v]
   if intersect_point_tri_2d(p,*q):
    return barycentric_transform(Vector((x,y,0)),*[Vector((c.x,c.y,0))for c in v],*v).z
 minimum=1e9;point=None
 for ix in range(1,20):
  for iy in range(1,20):
   x=x0+(x1-x0)*ix/20;y=y0+(y1-y0)*iy/20;za,zb=sample(dt,x,y),sample(ut,x,y)
   if za is not None and zb is not None and zb-za<minimum:minimum=zb-za;point=(x,y,za,zb)
 results.append({'cell':cell,'minimum_roof_thickness_m':minimum,'worst_sample_xy_bottom_top':point,'bottom_tris':[list(t.vertices)for t in dt],'top_tris':[list(t.vertices)for t in ut]})
root=Path(__file__).resolve().parent;(root/'shell_intersections.json').write_text(json.dumps(results,indent=2));print('SHELL_CROSSING_CELLS',sum(r['minimum_roof_thickness_m']<0 for r in results),'MINIMUM_THICKNESS',min(r['minimum_roof_thickness_m']for r in results),flush=True)
