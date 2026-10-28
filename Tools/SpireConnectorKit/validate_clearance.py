"""Sample 220cm standing headroom on the actual saved complete assemblies."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parent;OUT=HERE/'Output';spec=json.loads((HERE.parents[1]/'Docs/design/spire-blender-handoff-20261026/spire_spec.json').read_text(encoding='utf-8'));errors=[];rays=0
for c in spec['concepts']:
 s=bpy.data.scenes['Spire_'+c['id']];bpy.context.window.scene=s;bpy.context.view_layer.update();vs=[];fs=[]
 for o in s.objects:
  if o.type!='MESH':continue
  base=len(vs);vs.extend(o.matrix_world@v.co for v in o.data.vertices);fs.extend([base+i for i in p.vertices] for p in o.data.polygons)
 tree=BVHTree.FromPolygons(vs,fs,all_triangles=False);g=c['geometry'];R=g['shaft_outer_radius_cm'];ri,ro=g['route_inner_radius_cm'],g['route_outer_radius_cm'];samples=[]
 for f in c['flights']:
  for k in range(g['risers_per_flight']):samples.append((f['id']+'/'+str(k),f['start_angle_deg']+(k+.5)*g['flight_angle_deg']/g['risers_per_flight'],f['start_z_cm']-(k+1)*g['riser_cm']))
 for a in c['areas']:samples.append((a['id'],a['angle_center_unwrapped_deg'],a['floor_z_cm']))
 for ident,angle,z in samples:
  for r in [ri+55,(ri+ro)/2,ro-55]:
   a=math.radians(angle);p=Vector(((R+r*math.cos(a))/100,-r*math.sin(a)/100,(z+.5)/100));hit,n,index,distance=tree.ray_cast(p,Vector((0,0,1)),2.195);rays+=1
   if hit is not None:errors.append(dict(concept=c['id'],sample=ident,radius_cm=r,height_cm=distance*100+.5))
result=dict(status='failed' if errors else 'passed',headroom_rays=rays,height_cm=220,errors=errors,scope='Upward rays at three radial stations per tread/landing on complete saved visual meshes. Does not establish capsule sweeps, continuous traversal or PIE.')
(OUT/'Reports/blender_clearance.json').write_text(json.dumps(result,indent=2));print('SPIRE_HEADROOM_AUDIT',json.dumps(result),flush=True)
if errors:raise RuntimeError('Sampled headroom blocked')
