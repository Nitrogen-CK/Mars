"""Fresh native mesh, saved-map placement and simple-collision checks."""
import sys,json,math,re,gc,hashlib
from pathlib import Path
import unreal as u
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
from import_unreal import manifest,DEST,OWNER,TAG,OUT
from unreal_scenes import EA,LES,ED,clean,map_path,OFFSETS,NAMES

def meshes():
    data=manifest();sm=u.get_editor_subsystem(u.StaticMeshEditorSubsystem);errors=[];hulls=0
    for r in data['assets']:
        path=DEST+'/Meshes/'+r['name'];m=u.load_asset(path)
        if not isinstance(m,u.StaticMesh):errors.append([r['id'],'not imported']);continue
        assert u.EditorAssetLibrary.get_metadata_tag(m,TAG)==OWNER,path
        assert u.EditorAssetLibrary.get_metadata_tag(m,'SpireSourceSHA256')==r['sha256'],path
        b=m.get_bounds();lo=[b.origin.x-b.box_extent.x,b.origin.y-b.box_extent.y,b.origin.z-b.box_extent.z];hi=[b.origin.x+b.box_extent.x,b.origin.y+b.box_extent.y,b.origin.z+b.box_extent.z]
        if any(abs(lo[k]-r['bounds_min_cm'][k])>.2 or abs(hi[k]-r['bounds_max_cm'][k])>.2 for k in range(3)):errors.append([r['id'],'bounds'])
        actual=sm.get_convex_collision_count(m);hulls+=actual
        if actual!=r['collision_hulls']:errors.append([r['id'],'hulls',actual,r['collision_hulls']])
        if any(s.material_interface is None for s in m.static_materials):errors.append([r['id'],'unassigned material'])
    result=dict(status='failed' if errors else 'passed',assets=len(data['assets']),convex_hulls=hulls,errors=errors)
    (OUT/'Reports/unreal_mesh_validation.json').write_text(json.dumps(result,indent=2));print('SPIRE_NATIVE_MESH_AUDIT',json.dumps(result));assert not errors;return result

def saved_map(kind):
    clean();gc.collect();assert LES.load_level(map_path(kind));data=manifest();expected=json.loads((OUT/'Reports'/('unreal_'+kind+'.json')).read_text())['counts'];actual={};by_key={};errors=[]
    for a in EA.get_all_level_actors():
        if not a.get_actor_label().startswith('SP_Visual_'):continue
        assert OWNER in [str(t) for t in a.tags]
        comps=a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent);assert len(comps)==1
        c=comps[0];key=next(r['id'] for r in data['assets'] if r['name']==c.static_mesh.get_name());layer=a.get_actor_label()[len('SP_Visual_'):].removesuffix('_'+key)
        ident=key+'|'+layer;assert ident not in actual;actual[ident]=c.get_instance_count();by_key[ident]=c
        if str(c.get_collision_profile_name())!='NoCollision':errors.append([ident,'visual collision enabled'])
    if actual!=expected:errors.append(['instance counts',actual,expected])
    checked=0
    if kind in NAMES:
        groups={}
        for p in data['assemblies'][kind]:groups.setdefault(p['asset']+'|'+p['layer'],[]).append(p)
        for key,rows in groups.items():
            c=by_key[key]
            for i,p in enumerate(rows):
                t=c.get_instance_transform(i,world_space=True);loc=t.translation;rot=t.rotation.rotator();scale=t.scale3d
                if max(abs(v-p['at_cm'][j]) for j,v in enumerate([loc.x,loc.y,loc.z]))>.1:errors.append([key,i,'translation'])
                if abs((rot.yaw-p['yaw_deg']+180)%360-180)>.01:errors.append([key,i,'yaw'])
                if max(abs(v-p['scale'][j]) for j,v in enumerate([scale.x,scale.y,scale.z]))>.001:errors.append([key,i,'scale'])
                checked+=1
    result=dict(status='failed' if errors else 'passed',map=map_path(kind),instances=sum(actual.values()),groups=len(actual),transforms_checked=checked,errors=errors)
    (OUT/'Reports'/('saved_map_'+kind+'.json')).write_text(json.dumps(result,indent=2));print('SPIRE_SAVED_MAP_AUDIT',json.dumps(result));assert not errors;return result

def collision_surfaces():
    assert ED.get_editor_world().get_path_name().startswith(map_path('Diorama')+'.')
    spec=json.loads((HERE.parents[1]/'Docs/design/spire-blender-handoff-20261026/spire_spec.json').read_text(encoding='utf-8'));world=ED.get_editor_world();errors=[];count=0
    def check(cid,x,y,z,label):
        nonlocal count
        ox,oy,oz=OFFSETS[cid];h=u.SystemLibrary.line_trace_single(world,u.Vector(x+ox,y+oy,z+oz+5),u.Vector(x+ox,y+oy,z+oz-8),u.TraceTypeQuery.TRACE_TYPE_QUERY1,False,[],u.DrawDebugTrace.NONE);count+=1
        raw=h.export_text() if h else '';m=re.search(r'ImpactPoint=\(X=([^,]+),Y=([^,]+),Z=([^\)]+)\)',raw)
        if not m or 'bBlockingHit=True' not in raw or abs(float(m.group(3))-(z+oz))>.15:errors.append([label,'missing/wrong simple collision',raw])
    for c in spec['concepts']:
        g=c['geometry'];R=g['shaft_outer_radius_cm'];r=(g['route_inner_radius_cm']+g['route_outer_radius_cm'])/2
        for f in c['flights']:
            for k in range(g['risers_per_flight']):
                a=math.radians(f['start_angle_deg']+(k+.5)*g['flight_angle_deg']/g['risers_per_flight']);z=f['start_z_cm']-(k+1)*g['riser_cm'];check(c['id'],R+r*math.cos(a),r*math.sin(a),z,f['id']+'/'+str(k))
        for area in c['areas']:
            a=math.radians(area['angle_center_unwrapped_deg']);check(c['id'],R+r*math.cos(a),r*math.sin(a),area['floor_z_cm'],area['id'])
    result=dict(status='failed' if errors else 'passed',simple_collision_rays=count,errors=errors,scope='Native editor Chaos simple-collision queries against stable Diorama HISM proxies. Not CkJolt packaged lookup or pawn traversal.')
    (OUT/'Reports/unreal_collision_validation.json').write_text(json.dumps(result,indent=2));print('SPIRE_NATIVE_COLLISION_AUDIT',json.dumps(result));assert not errors;return result
