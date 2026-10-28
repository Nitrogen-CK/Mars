"""Read native corner attributes and prove their triangle index association."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def run(room,assets):
    import unreal as u
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assets.guard();assert assets.load('room_tint_owned_assets_r01').dirty()==dict(maps=[],content=[])
    for family in ('walls','floor','ceiling'):
        receipt=json.loads(assets.ledger_path('mesh',room,family).read_text());config=receipt['config']
        mesh=u.load_asset(config['mesh_target']);assert sha(assets.disk(config['mesh_target']))==receipt['package_sha256']
        geometry_path=ROOT/receipt['details']['render_geometry_file'];assert sha(geometry_path)==receipt['details']['render_geometry_sha256']
        geometry=json.loads(geometry_path.read_text());output=DOC/('native_corner_attributes_'+room+'_'+family+'_r01.json');assert not output.exists()
        lod=u.GeometryScriptMeshReadLOD();lod.lod_type=u.GeometryScriptLODType.RENDER_DATA;lod.lod_index=0
        dm=u.DynamicMesh();copied=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh,dm,u.GeometryScriptCopyMeshFromAssetOptions(),lod)
        assert copied[1]==u.GeometryScriptOutcomePins.SUCCESS and dm.get_triangle_count()==len(geometry['triangles'])
        rows=[]
        for i,expected in enumerate(geometry['triangles']):
            p=u.GeometryScript_MeshQueries.get_triangle_positions(dm,i);uv=u.GeometryScript_MeshQueries.get_triangle_u_vs(dm,0,i);mat=u.GeometryScript_Materials.get_triangle_material_id(dm,i)
            assert p[0] and uv[3] and mat[1]
            assert dict(positions=[list(v.to_tuple()) for v in p[1:]],uv=[list(v.to_tuple()) for v in uv[:3]],material=mat[0])==expected
            normals=u.GeometryScript_MeshQueries.get_triangle_normals(dm,i);colours=u.GeometryScript_MeshQueries.get_triangle_vertex_colors(dm,i)
            assert normals[4] and colours[4]
            rows.append(dict(RGB_bytes=[[round(c.to_tuple()[k]*255) for k in range(3)] for c in colours[1:4]],normals=[list(n.to_tuple()) for n in normals[1:4]]))
        actual_slots=[s.get_editor_property('material_interface').get_path_name().split('.')[0] for s in mesh.static_materials]
        assert actual_slots==receipt['details']['materials']
        output.write_text(json.dumps(dict(room=room,family=family,target=config['mesh_target'],package_sha256=receipt['package_sha256'],geometry_sha256=sha(geometry_path),actual_saved_slots=actual_slots,tool_sha256=sha(__file__),triangles=rows),separators=(',',':'))+'\n')
        print('NATIVE_CORNER_ATTRIBUTES',room,family,len(rows),sha(output))
    assets.guard();assert assets.load('room_tint_owned_assets_r01').dirty()==dict(maps=[],content=[])
