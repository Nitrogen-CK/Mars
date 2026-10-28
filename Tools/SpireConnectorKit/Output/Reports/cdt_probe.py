import bpy
from mathutils import Vector
from mathutils.geometry import delaunay_2d_cdt
from mathutils.bvhtree import BVHTree
v=[Vector(p) for p in [(-2,-2),(2,-2),(2,2),(-2,2),(-.5,-.5),(.5,-.5),(.5,.5),(-.5,.5)]]
e=[(i,(i+1)%4) for i in range(4)]+[(4+i,4+(i+1)%4) for i in range(4)]
for mode in [1,3,5]:
 for faces in [[],[[0,1,2,3]],[[0,1,2,3],[4,5,6,7]]]:
  vs,es,fs,*_=delaunay_2d_cdt(v,e,faces,mode,1e-6)
  tree=BVHTree.FromPolygons([Vector((p.x,p.y,0)) for p in vs],fs,all_triangles=False)
  hole=tree.ray_cast(Vector((0,0,1)),Vector((0,0,-1)))[0]
  solid=tree.ray_cast(Vector((1.5,0,1)),Vector((0,0,-1)))[0]
  print('CDT',mode,len(faces),'facecount',len(fs),'hole',hole is None,'solid',solid is not None,flush=True)
