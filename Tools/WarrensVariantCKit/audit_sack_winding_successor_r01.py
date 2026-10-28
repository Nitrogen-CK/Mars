"""Independent fresh-FBX exact corner correspondence, winding and normal audit."""
import collections,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/sack-winding-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy
    from mathutils import Vector
    r=json.loads((OUT/'successor.json').read_text());source=ROOT/r['source'];candidate=ROOT/r['fbx'];out=OUT/'fresh_fbx_audit.json';assert not out.exists()
    assert sha(source)==r['source_sha256'] and sha(candidate)==r['fbx_sha256']
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.unit_settings.scale_length=.01
    def read(path):
        before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(path),use_custom_normals=True);o,=[x for x in bpy.data.objects if x not in before and x.type=='MESH'];m=o.data
        assert len(m.polygons)==320 and len(m.materials)==2 and len(m.uv_layers)==1
        return m
    old=read(source);new=read(candidate)
    def bounds(m):return [[min(v.co[k] for v in m.vertices) for k in range(3)],[max(v.co[k] for v in m.vertices) for k in range(3)]]
    assert bounds(old)==bounds(new)
    def canonical(c):return min(tuple(c[i:]+c[:i]) for i in range(3))
    expected={}
    for p in old.polygons:
        ids=list(p.loop_indices)
        if p.material_index==0:ids.reverse()
        cs=[(tuple(old.vertices[old.loops[i].vertex_index].co),tuple(old.uv_layers[0].data[i].uv)) for i in ids]
        key=(p.material_index,canonical(cs));assert key not in expected
        expected[key]={c:(-old.corner_normals[i].vector if p.material_index==0 else old.corner_normals[i].vector) for c,i in zip(cs,ids)}
    maximum_normal_delta=0.;cloth=ties=0
    for p in new.polygons:
        cs=[(tuple(new.vertices[new.loops[i].vertex_index].co),tuple(new.uv_layers[0].data[i].uv)) for i in p.loop_indices];key=(p.material_index,canonical(cs));assert key in expected
        ns=expected.pop(key)
        for c,i in zip(cs,p.loop_indices):maximum_normal_delta=max(maximum_normal_delta,(new.corner_normals[i].vector-ns[c]).length)
        if p.material_index==0:
            cloth+=1;center=sum((new.vertices[i].co for i in p.vertices),Vector())/3
            if max(new.vertices[i].co.z for i in p.vertices)==0:assert p.normal.z<-.9999
            else:assert p.normal.dot(Vector((center.x,center.y,0)).normalized())>.63
        else:ties+=1
    assert not expected and cloth==128 and ties==192 and maximum_normal_delta<1e-5
    out.write_text(json.dumps(dict(status='FRESH_FBX_EXACT_REVERSED_CLOTH_UNCHANGED_TIES_COORDS_UV_MATERIALS_BOUNDS_PASS',source_sha256=sha(source),candidate_sha256=sha(candidate),receipt_sha256=sha(OUT/'successor.json'),tool_sha256=sha(__file__),triangles=320,reversed_cloth=cloth,unchanged_ties=ties,bounds_cm=bounds(new),maximum_normal_delta=maximum_normal_delta,boundary='All actual FBX triangle position/UV/material associations match exactly with only cloth reversal. Cloth side winding outward and cap downward; authored normals reversed. Native one-sided appearance not yet proved.'),indent=2)+'\n');print('WINDING_FRESH_AUDIT_PASS',sha(out),flush=True)
if __name__=='__main__':main()
