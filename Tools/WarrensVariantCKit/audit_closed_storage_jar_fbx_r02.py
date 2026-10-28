"""Independent actual-FBX closure/body/normal/UV audit; no scene saves."""
import collections,hashlib,json,importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/closed-storage-jar-r03'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    r=json.loads((FOLDER/'receipt.json').read_text());assert r['body_geometry_exact'];old=ROOT/r['source'];new=ROOT/r['fbx'];assert sha(old)==r['source_sha256'] and sha(new)==r['fbx_sha256']
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=.01;meshes=[]
    for file,count in ((old,292),(new,328)):
        before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(file),use_custom_normals=True);o,=[o for o in bpy.data.objects if o not in before and o.type=='MESH'];m=o.data;m.calc_loop_triangles();assert len(m.loop_triangles)==count and len(m.materials)==1 and len(m.uv_layers)==1
        assert all(abs(o.matrix_world[i][j]-(i==j))<1e-7 for i in range(4) for j in range(4));meshes.append(m)
    def triangle_records(m):
        out=collections.defaultdict(list)
        for t in m.loop_triangles:
            corners=[(tuple(m.vertices[m.loops[i].vertex_index].co),tuple(m.corner_normals[i].vector),tuple(m.uv_layers[0].data[i].uv)) for i in t.loops]
            rotations=[corners[i:]+corners[:i] for i in range(3)];corners=min(rotations,key=lambda v:tuple(c[0] for c in v));key=tuple(c[0] for c in corners);out[key].append(corners)
        return out
    a,b=map(triangle_records,meshes);max_normal=0.;max_uv=0.;matched=0
    for key,triangles in a.items():
        assert len(b.get(key,[]))==len(triangles),('Original triangle geometry or winding changed',key)
        for x,y in zip(triangles,b[key]):
            for xc,yc in zip(x,y):
                max_normal=max(max_normal,(Vector(xc[1])-Vector(yc[1])).length);max_uv=max(max_uv,(Vector(xc[2])-Vector(yc[2])).length)
            matched+=1
    assert matched==292 and max_normal<1e-5 and max_uv<1e-6,(matched,max_normal,max_uv)
    bounds=[[[min(v.co[i] for v in m.vertices) for i in range(3)],[max(v.co[i] for v in m.vertices) for i in range(3)]] for m in meshes];assert bounds[0]==bounds[1]
    rays=[]
    for m in meshes:
        tree=BVHTree.FromPolygons([v.co for v in m.vertices],[t.vertices for t in m.loop_triangles],all_triangles=True);hit,normal,index,distance=tree.ray_cast(Vector((0,0,80)),Vector((0,0,-1)),100);assert hit is not None;rays.append(dict(hit_cm=list(hit),normal=list(normal),triangle=index,distance_cm=distance))
    assert rays[0]['hit_cm'][2]<50 and abs(rays[1]['hit_cm'][2]-59.4)<.001,rays
    def module(name):
        p=Path(__file__).with_name(name+'.py');sp=importlib.util.spec_from_file_location('_closed_audit_'+name,p);m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m);return m
    aperture=module('mesh_aperture_section_r01');g=module('catacomb_pilot_manifest');section_proofs=[];oldmesh,newmesh=meshes
    oldpoints=[list(v.co) for v in oldmesh.vertices];oldtriangles=[list(t.vertices) for t in oldmesh.loop_triangles]
    for z in (58.2,59.4):
        loops=aperture.section_loops(oldpoints,oldtriangles,z);assert len(loops)==2;inner,outer=loops
        triangles=[]
        for t in newmesh.loop_triangles:
            points=[newmesh.vertices[i].co for i in t.vertices]
            if all(abs(v.z-z)<.0001 for v in points):
                poly=[(v.x,v.y) for v in points]
                if aperture.area(poly)<0:poly.reverse()
                triangles.append(poly)
        assert len(triangles)==8
        hull=aperture.convex_hull([v for tri in triangles for v in tri]);hullarea=aperture.area(hull);aperturearea=aperture.area(inner)
        covered=sum(abs(aperture.area(g.clip(inner,tri))) for tri in triangles)
        overlap=sum(abs(aperture.area(g.clip(a,b))) for i,a in enumerate(triangles) for b in triangles[i+1:])
        filled=sum(aperture.area(t) for t in triangles)
        assert abs(covered-aperturearea)<1e-6 and overlap<1e-6 and abs(filled-hullarea)<1e-6
        margin=aperture.minimum_inside_margin(inner,hull);assert margin>.2
        assert abs(abs(aperture.area(g.clip(hull,aperture.convex_hull(outer))))-hullarea)<1e-6
        section_proofs.append(dict(z_cm=z,source_inner_loop=inner,actual_cap_top_or_bottom_triangles=triangles,aperture_area_cm2=aperturearea,covered_aperture_area_cm2=covered,cap_triangle_overlap_cm2=overlap,cap_area_equals_convex_hull_error_cm2=filled-hullarea,minimum_full_aperture_overlap_cm=margin,cap_inside_outer_jar_wall=True))
    result=dict(status='ACTUAL_FBX_ORIGINAL_BODY_EXACT_AND_FULL_APERTURE_TRIANGLE_COVERAGE_POSITIVE_WALL_OVERLAP_PASS',source_sha256=sha(old),closed_fbx_sha256=sha(new),model_receipt_sha256=sha(FOLDER/'receipt.json'),matched_original_triangles=matched,new_plug_triangles=36,total_triangles=328,maximum_original_corner_normal_delta=max_normal,maximum_original_uv_delta=max_uv,exact_original_bounds_cm=bounds[0],top_rays=dict(original_open=rays[0],closed_successor=rays[1]),full_aperture_section_proofs=section_proofs,aperture_helper_sha256=sha(Path(aperture.__file__)),polygon_helper_sha256=sha(Path(g.__file__)),tool_sha256=sha(__file__),boundary='Actual separately imported original and successor FBX, not builder assertions alone. Every original triangle position and winding exactly matched; normals/UV independently compared, bounds exact; full original aperture polygons at58.2/59.4cm are covered by actual nonoverlapping cap triangles with over2mm positive perimeter overlap and remain within the outer ceramic wall; centre ray also hits59.4cm. No native asset/map/library edits; native import/material/painterly appearance still pending.')
    p=FOLDER/'fbx_roundtrip_r02.json';assert not p.exists();p.write_text(json.dumps(result,indent=2)+'\n');print('CLOSED_JAR_ACTUAL_FBX_AUDIT_PASS',sha(p),flush=True)
if __name__=='__main__':main()
