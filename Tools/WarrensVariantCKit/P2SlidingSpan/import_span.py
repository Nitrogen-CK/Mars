"""Import only the owned P2 moving meshes, retaining authored UCX collision."""
import hashlib
import json
import re
from pathlib import Path

import unreal as u

HERE = Path(__file__).resolve().parent
OUT = HERE / 'Output'
DEST = '/Game/Mars/Environment/WarrensVariantCKit/P2SlidingSpan'
OWNER = 'WarrensC.P2SlidingSpan.20261024'
EAL = u.EditorAssetLibrary


def main():
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    rows = json.loads((OUT/'asset_manifest.json').read_text())['assets']
    report = []
    # Validate every source/destination before importing the first mesh.
    for row in rows:
        source = OUT/row['fbx']
        assert hashlib.sha256(source.read_bytes()).hexdigest() == row['source_sha256']
        path = DEST+'/'+row['name']
        if EAL.does_asset_exist(path):
            asset = u.load_asset(path)
            assert isinstance(asset,u.StaticMesh) and EAL.get_metadata_tag(asset,'P2Owner') == OWNER, path
            assert Path(asset.get_editor_property('asset_import_data').get_first_filename()).resolve() == source.resolve()
    for row in rows:
        path = DEST+'/'+row['name']
        existing = u.load_asset(path) if EAL.does_asset_exist(path) else None
        if not existing or EAL.get_metadata_tag(existing,'SourceSHA256') != row['source_sha256']:
            task = u.AssetImportTask()
            task.filename = str(OUT/row['fbx'])
            task.destination_path = DEST
            task.destination_name = row['name']
            task.automated = True
            task.replace_existing = existing is not None
            task.replace_existing_settings = existing is not None
            task.save = False
            task.async_ = False
            task.factory = u.FbxFactory()
            opts = u.FbxImportUI()
            opts.automated_import_should_detect_type = False
            opts.import_as_skeletal = False
            opts.import_mesh = True
            opts.import_animations = False
            opts.import_materials = False
            opts.import_textures = False
            opts.mesh_type_to_import = u.FBXImportType.FBXIT_STATIC_MESH
            for key,value in dict(combine_meshes=True,auto_generate_collision=False,
                one_convex_hull_per_ucx=True,generate_lightmap_u_vs=False,build_nanite=False,
                transform_vertex_to_absolute=True,reorder_material_to_fbx_order=True,import_uniform_scale=1.0,
                normal_import_method=u.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS).items():
                opts.static_mesh_import_data.set_editor_property(key,value)
            task.options = opts
            world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
            old = u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')
            try:
                u.SystemLibrary.execute_console_command(world,'Interchange.FeatureFlags.Import.FBX 0')
                u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
            finally:
                u.SystemLibrary.execute_console_command(world,'Interchange.FeatureFlags.Import.FBX '+('1' if old else '0'))
            assert any(p.split('.')[0] == path for p in task.imported_object_paths),task.imported_object_paths
        mesh = u.load_asset(path)
        assert isinstance(mesh,u.StaticMesh),path
        EAL.set_metadata_tag(mesh,'P2Owner',OWNER)
        names = dict(zip(row['materials'],row['material_keys']))
        slots = list(mesh.get_editor_property('static_materials'))
        assert len(slots) == len(names)
        for slot in slots:
            name = str(slot.get_editor_property('imported_material_slot_name'))
            assert name in names,(path,name,names)
            material = u.load_asset('/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'+names[name])
            assert material
            slot.set_editor_property('material_interface',material)
        mesh.set_editor_property('static_materials',slots)
        subsystem = u.get_editor_subsystem(u.StaticMeshEditorSubsystem)
        convex = subsystem.get_convex_collision_count(mesh)
        primitives = subsystem.get_simple_collision_count(mesh)
        # This engine API counts box/sphere/sphyl primitives separately from
        # ConvexElems; authored UCX hulls are returned by the convex query.
        assert convex == row['expected_convex_count'] and primitives == 0,(path,convex,primitives)
        geometry = mesh.get_editor_property('body_setup').get_editor_property('agg_geom').export_text()
        # Read the imported serialized hull vertices, not just aggregate counts.
        # Import order is not assumed; match the complete set of hull bounds.
        actual_hulls = []
        for text in re.findall(r'VertexData=\(\((.*?)\)\),IndexData=',geometry):
            vertices = [tuple(float(v) for v in p) for p in re.findall(r'X=([^,]+),Y=([^,]+),Z=([^\)]+)',text)]
            assert len(vertices)==8,(path,vertices)
            actual_hulls.append([[min(v[k] for v in vertices) for k in range(3)],
                                 [max(v[k] for v in vertices) for k in range(3)]])
        assert len(actual_hulls)==convex
        pending = list(actual_hulls)
        for hull in row['collision_boxes_blender']:
            centre = [v*100 for v in hull['centre_m']]
            centre[1]*=-1
            size = [v*100 for v in hull['size_m']]
            wanted = [[centre[k]+sign*size[k]/2 for k in range(3)] for sign in (-1,1)]
            candidates = [h for h in pending if max(abs(h[e][k]-wanted[e][k]) for e in range(2) for k in range(3))<.02]
            assert len(candidates)==1,(path,wanted,pending)
            pending.remove(candidates[0])
        bounds = mesh.get_bounds()
        actual = list(bounds.box_extent.to_tuple())
        origin = list(bounds.origin.to_tuple())
        expected_origin = [(row['bounds_min_cm'][k]+row['bounds_max_cm'][k])/2 for k in range(3)]
        expected_origin[1] *= -1
        assert max(abs(actual[k]*2-row['actual_dimensions_cm'][k]) for k in range(3)) < .15
        assert max(abs(origin[k]-expected_origin[k]) for k in range(3)) < .15,(origin,expected_origin)
        EAL.set_metadata_tag(mesh,'SourceSHA256',row['source_sha256'])
        EAL.set_metadata_tag(mesh,'CollisionContract','Authored UCX; deck1/cage3/guard1; no generated hulls')
        assert EAL.save_loaded_asset(mesh,False),path
        report.append(dict(path=path,convex_hulls=convex,imported_hull_bounds_cm=actual_hulls,bounds_origin_cm=origin,
                           bounds_extent_cm=actual,source_sha256=row['source_sha256']))
    (OUT/'Reports/import.json').write_text(json.dumps(report,indent=2))
    print('P2_IMPORTED',json.dumps(report))
    return report
