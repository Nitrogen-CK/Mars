"""Reopen a saved .blend and audit actual mesh surfaces, holes and instancing."""
import sys,json,math,hashlib
from pathlib import Path
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parent;OUT=HERE/'Output';REPO=HERE.parents[1]
sys.path.insert(0,str(HERE))
from geometry import record
data=json.loads((OUT/'asset_manifest.json').read_text());spec=json.loads((REPO/'Docs/design/spire-blender-handoff-20261026/spire_spec.json').read_text(encoding='utf-8'))
assert data['spec_sha256']==hashlib.sha256((REPO/'Docs/design/spire-blender-handoff-20261026/spire_spec.json').read_bytes()).hexdigest()
objects={r['id']:bpy.data.objects[r['name']] for r in data['assets']};errors=[];ray_tests=0
marked=sum(o.asset_data is not None for o in bpy.data.objects)
if marked!=len(data['assets']):errors.append(['asset browser marked count',marked,len(data['assets'])])
trees={}
def cast(o,origin,direction,distance):
    if o.name not in trees:trees[o.name]=BVHTree.FromPolygons([v.co for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons],all_triangles=False)
    pos,normal,index,dist=trees[o.name].ray_cast(origin,direction,distance)
    return pos is not None,pos,normal,index
for row in data['assets']:
    o=objects[row['id']];actual=record(o)
    if any(abs(actual['bounds_min_cm'][k]-row['bounds_min_cm'][k])>.05 or abs(actual['bounds_max_cm'][k]-row['bounds_max_cm'][k])>.05 for k in range(3)):errors.append([row['id'],'bounds differ from final export'])
    if any(not math.isfinite(v) for p in o.data.vertices for v in p.co):errors.append([row['id'],'nonfinite'])
    if not o.data.uv_layers:errors.append([row['id'],'UV0 missing'])
    if any(m is None for m in o.data.materials):errors.append([row['id'],'unassigned material'])
    if row['category']=='Collision' and row['collision_hulls']==0:errors.append([row['id'],'convex collision not exported'])
    if row['category']=='Collision':
        bm=bmesh.new();bm.from_mesh(o.data)
        if any(not e.is_manifold for e in bm.edges):errors.append([row['id'],'nonmanifold proxy surface'])
        bm.free()
for c in spec['concepts']:
    cid=c['id'];g=c['geometry'];r=(g['route_inner_radius_cm']+g['route_outer_radius_cm'])/2;placements=data['assemblies'][cid]
    for f in c['flights']:
        row=next(p for p in placements if p.get('source_id')==f['id']);o=objects[row['asset']]
        for k in range(g['risers_per_flight']):
            a=math.radians((k+.5)*g['flight_angle_deg']/g['risers_per_flight']);x,y=r*math.cos(a),r*math.sin(a)
            hit,pos,normal,index=cast(o,Vector((x/100,-y/100,1)),Vector((0,0,-1)),distance=10);ray_tests+=1
            if not hit or abs(pos.z*100+(k+1)*g['riser_cm'])>.1:errors.append([f['id'],k,'tread top',pos.z*100 if hit else None])
    for a in c['areas']:
        row=next(p for p in placements if p.get('source_id')==a['id']);o=objects[row['asset']]
        hit,pos,_,_=cast(o,Vector((r/100,0,.1)),Vector((0,0,-1)),distance=.7);ray_tests+=1
        if not hit or abs(pos.z)>.001:errors.append([a['id'],'flat landing missing'])
    if cid=='HL':
        for b in c['supports']['floor_bore_placements']:
            a=next(a for a in c['areas'] if a['id']==b['landing']);row=next(p for p in placements if p.get('source_id')==a['id']);o=objects[row['asset']]
            angle=math.radians(b['angle_unwrapped_deg']-a['angle_center_unwrapped_deg']);x,y=530*math.cos(angle),530*math.sin(angle)
            hit,*_=cast(o,Vector((x/100,-y/100,.1)),Vector((0,0,-1)),distance=.7);ray_tests+=1
            if hit:errors.append([b['id'],'chain bore not open'])
scene_counts={}
for c in spec['concepts']:
    s=bpy.data.scenes['Spire_'+c['id']];inst=[o for o in s.objects if o.type=='MESH'];expected=len(data['assemblies'][c['id']])
    if len(inst)!=expected:errors.append([s.name,len(inst),expected])
    scene_counts[c['id']]={'mesh_instances':len(inst),'unique_meshes':len({o.data for o in inst})}
report={'status':'failed' if errors else 'passed','assets':len(data['assets']),'marked_asset_browser_objects':marked,'surface_rays':ray_tests,'errors':errors,'scenes':scene_counts,'scope':'fresh reopened Blender meshes, not Unreal physics or packaged collision'}
(OUT/'Reports/blender_validation.json').write_text(json.dumps(report,indent=2));print('SPIRE_FRESH_BLENDER_AUDIT',json.dumps(report),flush=True)
if errors:raise RuntimeError('Blender audit failed')
