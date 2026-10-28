"""Read actual original FBX corner RGB and normals; never export or edit sources."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    import bpy
    p=argparse.ArgumentParser();p.add_argument('--room',required=True);args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
    manifest=json.loads((DOC/'four_room_exports_r01.json').read_text());room,=[v for v in manifest['rooms'] if v['room']==args.room]
    folder=DOC/room['folder'];export=json.loads((folder/'export.json').read_text())
    for row in export['exports']:
        source=ROOT/row['file'];assert sha(source)==row['sha256']
        output=folder/('actual_fbx_'+row['family']+'_corner_attributes_r01.json');assert not output.exists()
        expected_path=folder/('actual_fbx_'+row['family']+'_geometry_r01.json');expected=json.loads(expected_path.read_text())
        bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.unit_settings.scale_length=.01
        bpy.ops.import_scene.fbx(filepath=str(source),use_custom_normals=True,colors_type='LINEAR')
        obj,=[o for o in bpy.context.scene.objects if o.type=='MESH'];mesh=obj.data
        colour=mesh.color_attributes.get('StoneTint') or mesh.color_attributes.active_color
        assert colour and colour.domain=='CORNER' and len(mesh.polygons)==len(expected['triangles'])
        normal_matrix=obj.matrix_world.to_3x3().inverted().transposed();triangles=[]
        for polygon,geometry in zip(mesh.polygons,expected['triangles']):
            points=[obj.matrix_world@mesh.vertices[mesh.loops[i].vertex_index].co for i in polygon.loop_indices]
            assert [[v.x,-v.y,v.z] for v in points]==geometry['positions'] and polygon.material_index==geometry['material']
            normals=[(normal_matrix@mesh.corner_normals[i].vector).normalized() for i in polygon.loop_indices]
            triangles.append(dict(RGB_bytes=[[int(255*max(0,min(1,v))) for v in colour.data[i].color[:3]] for i in polygon.loop_indices],normals=[[n.x,-n.y,n.z] for n in normals]))
        output.write_text(json.dumps(dict(room=args.room,family=row['family'],fbx_sha256=row['sha256'],geometry_sha256=sha(expected_path),tool_sha256=sha(__file__),triangles=triangles),separators=(',',':'))+'\n')
        print('FBX_CORNER_ATTRIBUTES',args.room,row['family'],len(triangles),sha(output),flush=True)


if __name__=='__main__':main()
