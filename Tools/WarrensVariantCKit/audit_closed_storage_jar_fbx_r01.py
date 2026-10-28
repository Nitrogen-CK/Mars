"""Independent actual-FBX closure/body/normal/UV audit; no scene saves."""
import collections,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/closed-storage-jar-r01'
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
    result=dict(status='ACTUAL_FBX_ORIGINAL_292_TRIANGLES_EXACT_POSITION_WINDING_NORMAL_UV_AND_CLOSED_TOP_RAY_PASS',source_sha256=sha(old),closed_fbx_sha256=sha(new),model_receipt_sha256=sha(FOLDER/'receipt.json'),matched_original_triangles=matched,new_plug_triangles=36,total_triangles=328,maximum_original_corner_normal_delta=max_normal,maximum_original_uv_delta=max_uv,exact_original_bounds_cm=bounds[0],top_rays=dict(original_open=rays[0],closed_successor=rays[1]),tool_sha256=sha(__file__),boundary='Actual separately imported original and successor FBX, not builder assertions alone. Every original triangle position and winding exactly matched; normals/UV independently compared, bounds exact; vertical mouth ray now hits recessed plug59.4cm rather than the open vessel floor. No native asset/map/library edits; native import/material/painterly appearance still pending.')
    p=FOLDER/'fbx_roundtrip_r01.json';assert not p.exists();p.write_text(json.dumps(result,indent=2)+'\n');print('CLOSED_JAR_ACTUAL_FBX_AUDIT_PASS',sha(p),flush=True)
if __name__=='__main__':main()
