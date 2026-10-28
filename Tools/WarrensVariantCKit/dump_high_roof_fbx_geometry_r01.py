"""Read actual FBX corner geometry into Unreal axis convention; no export/save."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/roof-completion-export-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy
    e=json.loads((DOC/'export.json').read_text());p=ROOT/e['file'];assert sha(p)==e['fbx_sha256'];out=DOC/'actual_fbx_expected_geometry.json';assert not out.exists();bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.unit_settings.scale_length=.01;bpy.ops.import_scene.fbx(filepath=str(p),use_custom_normals=True,colors_type='LINEAR');o,=[o for o in bpy.context.scene.objects if o.type=='MESH'];m=o.data;assert len(m.polygons)==7356 and all(len(p.vertices)==3 for p in m.polygons)
    assert all(abs(o.matrix_world[i][j]-(i==j))<1e-7 for i in range(4) for j in range(4));rows=[]
    for p in m.polygons:
        rows.append(dict(positions=[[m.vertices[m.loops[i].vertex_index].co.x,-m.vertices[m.loops[i].vertex_index].co.y,m.vertices[m.loops[i].vertex_index].co.z] for i in p.loop_indices],uv=[[m.uv_layers[0].data[i].uv.x,1-m.uv_layers[0].data[i].uv.y] for i in p.loop_indices],material=p.material_index))
    out.write_text(json.dumps(dict(status='ACTUAL_FBX_GEOMETRY_UNREAL_AXIS_V_FLIP_EXPECTATION_FOR_NATIVE_COMPARISON',fbx_sha256=sha(ROOT/e['file']),tool_sha256=sha(__file__),matrix=[list(v) for v in o.matrix_world],triangles=rows),separators=(',',':'))+'\n');print('EXPECTED_FBX_GEOMETRY',sha(out),flush=True)
if __name__=='__main__':main()
