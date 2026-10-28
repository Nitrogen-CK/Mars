"""Headless read-only FBX triangle expectations for private native diagnostics."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    import bpy
    parser=argparse.ArgumentParser()
    parser.add_argument('--room',required=True,choices=['hall','ossuary','cellar','sluice'])
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    manifest=json.loads((DOC/'four_room_exports_r01.json').read_text())
    room,=[r for r in manifest['rooms'] if r['room']==args.room]
    folder=DOC/room['folder']
    export=json.loads((folder/'export.json').read_text())
    assert sha(folder/'export.json')==room['export_sha256']
    for row in export['exports']:
        source=ROOT/row['file'];assert sha(source)==row['sha256']
        output=folder/('actual_fbx_'+row['family']+'_geometry_r01.json')
        assert not output.exists()
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.scene.unit_settings.scale_length=.01
        bpy.ops.import_scene.fbx(filepath=str(source),use_custom_normals=True,colors_type='LINEAR')
        obj,=[o for o in bpy.context.scene.objects if o.type=='MESH']
        mesh=obj.data
        assert len(mesh.polygons)==row['triangles'] and all(len(p.vertices)==3 for p in mesh.polygons)
        assert len(mesh.uv_layers)==1
        assert [m.name for m in mesh.materials]==row['materials']
        matrix=obj.matrix_world
        assert all(abs(matrix[i][j]-(i==j))<1e-7 for i in range(4) for j in range(4))
        triangles=[]
        for polygon in mesh.polygons:
            points=[matrix@mesh.vertices[mesh.loops[i].vertex_index].co for i in polygon.loop_indices]
            triangles.append(dict(positions=[[v.x,-v.y,v.z] for v in points],uv=[[mesh.uv_layers[0].data[i].uv.x,1-mesh.uv_layers[0].data[i].uv.y] for i in polygon.loop_indices],material=polygon.material_index))
        output.write_text(json.dumps(dict(status='ACTUAL_ORIGINAL_RANGE_SAFE_FBX_TRIANGLE_EXPECTATIONS_NOT_NATIVE_PROOF',room=args.room,family=row['family'],fbx_sha256=row['sha256'],tool_sha256=sha(__file__),matrix=[list(r) for r in matrix],triangles=triangles,boundary='Actual imported FBX matrix applied; centimetre Unreal axis convention and V flip. Native half-packed UV and position deltas require independent correspondence. No geometry export, source edits or native calls.'),separators=(',',':'))+'\n')
        print('ACTUAL_FBX_EXPECTATION',args.room,row['family'],row['triangles'],sha(output),flush=True)


if __name__=='__main__':
    main()
