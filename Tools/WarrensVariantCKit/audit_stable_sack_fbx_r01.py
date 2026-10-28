"""Independent actual FBX comparison of the finite contact-profile successor."""
import collections,hashlib,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/stable-sack-foot-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    import bpy
    receipt=OUT/'receipt.json';r=json.loads(receipt.read_text());source=ROOT/r['source'];candidate=ROOT/r['fbx'];target=OUT/'fbx_roundtrip_r01.json';assert not target.exists()
    assert sha(source)==r['source_sha256'] and sha(candidate)==r['fbx_sha256'] and sha(Path(__file__).with_name('stabilize_larder_sack_base_r01.py'))==r['tool_sha256'] and sha(Path(__file__).with_name('mesh_profile_contact_r01.py'))==r['profile_tool_sha256']
    bpy.ops.wm.read_factory_settings(use_empty=True)
    def read(path):
        before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(path),use_custom_normals=True);o,=[v for v in bpy.data.objects if v not in before and v.type=='MESH'];m=o.data
        assert len(m.polygons)==320 and all(len(p.vertices)==3 for p in m.polygons) and len(m.materials)==2 and len(m.uv_layers)==1
        return o,m
    old,om=read(source);new,nm=read(candidate);points=[tuple(v.co) for v in om.vertices];mapping={c['vertex']:tuple(c['after_cm']) for c in r['changes']};assert len(mapping)==10
    for c in r['changes']:
        assert points[c['vertex']]==tuple(c['before_cm'])
        assert tuple(c['after_cm'][:2])==points[c['adjacent_vertex']][:2] and c['after_cm'][2]==c['before_cm'][2]==0
    def bounds(m):return [[min(v.co[k] for v in m.vertices) for k in range(3)],[max(v.co[k] for v in m.vertices) for k in range(3)]]
    assert bounds(om)==bounds(nm)==r['bounds_cm']
    def canonical(corners):return min(tuple(corners[i:]+corners[:i]) for i in range(3))
    expected={}
    for p in om.polygons:
        corners=[(mapping.get(om.loops[i].vertex_index,points[om.loops[i].vertex_index]),tuple(om.uv_layers[0].data[i].uv)) for i in p.loop_indices]
        key=(p.material_index,canonical(corners));assert key not in expected
        expected[key]=dict(changed=any(om.loops[i].vertex_index in mapping for i in p.loop_indices),normal=p.normal.copy(),loop_normals={corner:om.corner_normals[i].vector.copy() for corner,i in zip(corners,p.loop_indices)},source_polygon=p.index)
    assert len(expected)==320
    changed=0;unchanged=0;maximum_unchanged_normal_delta=0.;minimum_face_dot=1.;minimum_area=float('inf');matched=[]
    for p in nm.polygons:
        corners=[(tuple(nm.vertices[nm.loops[i].vertex_index].co),tuple(nm.uv_layers[0].data[i].uv)) for i in p.loop_indices];key=(p.material_index,canonical(corners));assert key in expected,('Unexpected actual FBX triangle/UV/material/winding',p.index,corners)
        old_row=expected.pop(key);minimum_area=min(minimum_area,p.area);assert p.area>1e-6
        alignment=p.normal.dot(old_row['normal']);minimum_face_dot=min(minimum_face_dot,alignment);assert alignment>0
        if old_row['changed']:
            changed+=1
            for i in p.loop_indices:assert nm.corner_normals[i].vector.dot(p.normal)>.9999
        else:
            unchanged+=1
            for corner,i in zip(corners,p.loop_indices):maximum_unchanged_normal_delta=max(maximum_unchanged_normal_delta,(nm.corner_normals[i].vector-old_row['loop_normals'][corner]).length)
        matched.append(dict(source_polygon=old_row['source_polygon'],candidate_polygon=p.index,changed=old_row['changed']))
    assert not expected and changed==28 and unchanged==292 and maximum_unchanged_normal_delta<1e-5
    def boundary(m):
        edges=collections.Counter(tuple(sorted((tuple(m.vertices[p.vertices[i]].co),tuple(m.vertices[p.vertices[(i+1)%3]].co)))) for p in m.polygons for i in range(3));open_edges=[e for e,n in edges.items() if n==1]
        assert not [n for n in edges.values() if n>2]
        return open_edges
    ob,nb=boundary(om),boundary(nm);assert set(ob)==set(nb) and len(ob)==10 and min(v[2] for e in nb for v in e)>98
    record=dict(status='ACTUAL_FBX_FINITE_CONTACT_PROFILE_DELTA_AND_UPPER_UV_TOPOLOGY_NORMALS_PASS',receipt_sha256=sha(receipt),source_sha256=sha(source),candidate_sha256=sha(candidate),triangles=320,changed_triangles=changed,unchanged_triangles=unchanged,changed_vertices=10,uv_and_material_and_oriented_topology_exact=True,bounds_cm=bounds(nm),maximum_unaffected_corner_normal_delta=maximum_unchanged_normal_delta,minimum_old_new_face_normal_dot=minimum_face_dot,minimum_triangle_area_cm2=minimum_area,open_boundary_edges=10,open_boundary_minimum_z_cm=min(v[2] for e in nb for v in e),lower_boundary_edges=0,matched_triangle_ids=matched,tool_sha256=sha(__file__),boundary='Fresh independent import of actual source/successor FBX. Exactly ten bottom XY vertices map to actual adjacent profile; allZ/UV/orientedtriangletopology/materials/bounds and292unaffected triangles are exact.28changed adjacent faces have outward aligned normals/noinversions/zeroarea; upper/tie normals within recorded floating tolerance. Native appearance, actual arch-pixel attribution and source/library adoption remain unverified.')
    target.write_text(json.dumps(record,indent=2)+'\n');print('STABLE_SACK_ACTUAL_FBX_AUDIT_PASS',sha(target),flush=True)

if __name__=='__main__':main()
