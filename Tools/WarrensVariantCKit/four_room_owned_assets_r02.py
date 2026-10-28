"""Absent private room palette instances and range-safe surface imports only."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'
DEST = '/Game/Mars/ArtReview/Lookdev/RoomRollout_20261027R01'
STATE = {}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(name):
    path = Path(__file__).with_name(name+'.py')
    spec = importlib.util.spec_from_file_location('_four_room_'+name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def disk(path):
    return ROOT/('Content/'+path.removeprefix('/Game/')+'.uasset')


def ledger_path(kind, room, family):
    return DOC/('native_'+kind+'_'+room+'_'+family+'_r01.json')


def guard():
    master = load('room_tint_owned_assets_r01')
    master.guard()
    assert (DOC/'owned_masters_reload_r01.json').is_file()
    for kind in ('palette','mesh'):
        for path in DOC.glob('native_'+kind+'_*_r01.json'):
            row = json.loads(path.read_text())
            assert sha(disk(row['target'])) == row['package_sha256']


def preflight(room, family, kind):
    import unreal as u
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve() == ROOT.resolve()
    g = json.loads((DOC/'NATIVE_FOUR_ROOM_ASSETS_GATE_R02.json').read_text())
    assert g['status'] == 'APPROVED_TWELVE_PRIVATE_PALETTES_AND_TWELVE_RANGE_SAFE_MESHES_ONLY'
    assert g['tool_sha256'] == sha(__file__)
    for path, digest in g['input_sha256'].items():
        assert sha(ROOT/path) == digest
    config, = [r for r in g['surfaces'] if r['room'] == room and r['family'] == family]
    target = config[kind+'_target']
    assert (kind,room,family) not in STATE
    assert not ledger_path(kind,room,family).exists()
    assert not u.EditorAssetLibrary.does_asset_exist(target) and not disk(target).exists()
    assert load('room_tint_owned_assets_r01').dirty() == dict(maps=[],content=[])
    ed = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    assert ed.get_game_world() is None and ed.get_editor_world().get_path_name() == '/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    guard()
    return g, config, target


def transaction(room, family, kind, build):
    import unreal as u
    gate, config, target = preflight(room,family,kind)
    settings = u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'))
    autosave = settings.get_editor_property('bAutoSaveEnable')
    jolt = u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'))
    cook = jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
    interchange = u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')
    attempt = DOC/('attempt_'+kind+'_'+room+'_'+family+'_r01.json')
    assert not attempt.exists()
    attempt.write_text(json.dumps(dict(status='ONE_ABSENT_PRIVATE_TARGET_NO_FACTORY_RETRY',target=target,tool_sha256=sha(__file__),config=config),indent=2)+'\n')
    try:
        settings.set_editor_property('bAutoSaveEnable',False)
        jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',u.Ck_EnableDisable.DISABLE)
        assert settings.get_editor_property('bAutoSaveEnable') is False and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave') == u.Ck_EnableDisable.DISABLE
        if kind == 'mesh':
            u.SystemLibrary.execute_console_command(world,'Interchange.FeatureFlags.Import.FBX 0')
            assert u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX') is False
        asset, details = build(config,target)
        assert STATE[(kind,room,family)]['asset'] == asset
        guard()
        assert load('room_tint_owned_assets_r01').dirty() == dict(maps=[],content=[target])
        u.EditorAssetLibrary.set_metadata_tag(asset,'Owner','Mars.WarrensVariantC.RoomRollout.R01')
        assert u.EditorAssetLibrary.save_loaded_asset(asset,False)
        assert load('room_tint_owned_assets_r01').dirty() == dict(maps=[],content=[])
        guard()
        receipt = dict(status='PRIVATE_ROOM_'+kind.upper()+'_SAVED_NOT_BOUND_OR_NATIVE_ART_ACCEPTED',room=room,family=family,target=target,package_sha256=sha(disk(target)),tool_sha256=sha(__file__),gate_sha256=sha(DOC/'NATIVE_FOUR_ROOM_ASSETS_GATE_R02.json'),config=config,details=details,boundary='New private unbound candidate only. Source-supported geometry and original in-range StoneTint from audited FBX, room colour through floating MI parameter. No geometry expansion, source texture/material/map/library/physics/gameplay edits. Counts, bounds and colour-set checks are import diagnostics; actual native appearance and complete corner correspondence remain separate adoption checks.')
        ledger_path(kind,room,family).write_text(json.dumps(receipt,indent=2)+'\n')
        STATE[(kind,room,family)]['stage'] = 'SAVED_NOT_BOUND'
        guard()
        print('PRIVATE_ROOM_CANDIDATE_SAVED',kind,room,family,receipt['package_sha256'])
    finally:
        u.SystemLibrary.execute_console_command(world,'Interchange.FeatureFlags.Import.FBX '+('1' if interchange else '0'))
        settings.set_editor_property('bAutoSaveEnable',autosave)
        jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',cook)
        assert settings.get_editor_property('bAutoSaveEnable') == autosave and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave') == cook
        assert u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX') == interchange


def create_palette(room,family):
    import unreal as u
    def build(config,target):
        parent = u.load_asset(config['master'])
        assert isinstance(parent,u.Material)
        asset = u.AssetToolsHelpers.get_asset_tools().create_asset(target.rsplit('/',1)[1],target.rsplit('/',1)[0],u.MaterialInstanceConstant,u.MaterialInstanceConstantFactoryNew())
        assert asset and asset.get_path_name().split('.')[0] == target
        STATE[('palette',room,family)] = dict(stage='PENDING_NO_FACTORY_RETRY',asset=asset)
        u.MaterialEditingLibrary.set_material_instance_parent(asset,parent)
        u.MaterialEditingLibrary.set_material_instance_vector_parameter_value(asset,'RoomTint',u.LinearColor(*config['tint'],1))
        assert asset.get_editor_property('parent') == parent
        actual = u.MaterialEditingLibrary.get_material_instance_vector_parameter_value(asset,'RoomTint').to_tuple()
        assert max(abs(a-b) for a,b in zip(actual,config['tint']+[1.])) < 1e-6
        assert len(asset.get_editor_property('vector_parameter_values')) == 1
        assert not asset.get_editor_property('scalar_parameter_values') and not asset.get_editor_property('texture_parameter_values')
        stats = u.MaterialEditingLibrary.get_statistics(parent)
        assert stats.num_pixel_shader_instructions>0 and stats.num_vertex_shader_instructions>0
        return asset,dict(parent=parent.get_path_name(),RoomTint=actual,scalar_overrides=0,texture_overrides=0,vector_overrides=1)
    transaction(room,family,'palette',build)


def import_surface(room,family):
    import unreal as u
    def build(config,target):
        row = config['export']
        assert sha(ROOT/row['file']) == row['sha256']
        palette_receipt = json.loads(ledger_path('palette',room,family).read_text())
        assert palette_receipt['target'] == config['palette_target']
        task = u.AssetImportTask()
        task.filename=str(ROOT/row['file']);task.destination_path=target.rsplit('/',1)[0];task.destination_name=target.rsplit('/',1)[1]
        task.automated=True;task.replace_existing=False;task.replace_existing_settings=False;task.save=False;task.async_=False;task.factory=u.FbxFactory()
        opts=u.FbxImportUI();opts.automated_import_should_detect_type=False;opts.import_as_skeletal=False;opts.import_mesh=True;opts.import_animations=False;opts.import_materials=False;opts.import_textures=False;opts.mesh_type_to_import=u.FBXImportType.FBXIT_STATIC_MESH
        for key,value in dict(combine_meshes=True,remove_degenerates=False,auto_generate_collision=False,generate_lightmap_u_vs=False,build_nanite=False,transform_vertex_to_absolute=True,reorder_material_to_fbx_order=True,import_uniform_scale=1.,normal_import_method=u.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS,vertex_color_import_option=u.VertexColorImportOption.REPLACE).items():
            opts.static_mesh_import_data.set_editor_property(key,value)
        task.options=opts
        u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
        mesh=u.load_asset(target)
        assert isinstance(mesh,u.StaticMesh)
        STATE[('mesh',room,family)] = dict(stage='PENDING_NO_FACTORY_RETRY',asset=mesh)
        filenames = list(map(str,mesh.get_editor_property('asset_import_data').extract_filenames()))
        assert len(filenames) == 1 and Path(filenames[0]).resolve() == (ROOT/row['file']).resolve()
        slots=list(mesh.static_materials)
        assert [str(slot.get_editor_property('imported_material_slot_name')) for slot in slots] == row['materials']
        bindings=[]
        for index,slot in enumerate(slots):
            material=config['palette_target'] if index==0 else '/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02/Materials/M_CP_Mortar_R02'
            loaded=u.load_asset(material);assert loaded
            slot.set_editor_property('material_interface',loaded);bindings.append(material)
        assert len(slots)==2 and 'QuietMortar' in row['materials'][1]
        mesh.set_editor_property('static_materials',slots)
        sub=u.get_editor_subsystem(u.StaticMeshEditorSubsystem);sub.remove_collisions(mesh)
        assert sub.get_simple_collision_count(mesh)==sub.get_convex_collision_count(mesh)==0 and sub.get_num_uv_channels(mesh,0)==1
        assert not mesh.get_editor_property('nanite_settings').get_editor_property('enabled')
        assert not mesh.get_editor_property('asset_import_data').get_editor_property('remove_degenerates') and not sub.get_lod_build_settings(mesh,0).get_editor_property('remove_degenerates')
        counts={};dm=None
        for label,lodtype in [('source',u.GeometryScriptLODType.SOURCE_MODEL),('render',u.GeometryScriptLODType.RENDER_DATA)]:
            lod=u.GeometryScriptMeshReadLOD();lod.lod_type=lodtype;lod.lod_index=0
            candidate=u.DynamicMesh();copied=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh,candidate,u.GeometryScriptCopyMeshFromAssetOptions(),lod)
            assert copied[1]==u.GeometryScriptOutcomePins.SUCCESS and candidate.get_triangle_count()==row['triangles']
            counts[label]=candidate.get_triangle_count()
            if label=='render':dm=candidate
        colours=u.GeometryScript_VertexColors.get_mesh_per_vertex_colors(dm,False)
        assert colours[2] is True and colours[3] is False
        values=u.GeometryScript_List.convert_color_list_to_array(colours[1])
        actual=sorted(set(tuple(round(c.to_tuple()[k]*255) for k in range(3)) for c in values))
        ranges=json.loads((DOC/'four_room_vertex_range_contract_r01.json').read_text())
        expected,=[r for r in ranges['meshes'] if r['room']==room and r['family']==family and r['kind']=='range_safe_original']
        assert expected['sha256']==row['sha256'] and expected['referenced_corners_outside_native_UNorm_range']==0
        assert actual==[tuple(v) for v in expected['expected_native_RGB_bytes']]
        normals=u.GeometryScript_Normals.get_mesh_per_vertex_normals(dm,False)
        assert normals[2] is True and normals[3] is False
        normal_values=u.GeometryScript_List.convert_vector_list_to_array(normals[1])
        nrange=[min(v.length() for v in normal_values),max(v.length() for v in normal_values)]
        assert .99<nrange[0]<=nrange[1]<1.01
        bounds=mesh.get_bounds();low=[v-e for v,e in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())];high=[v+e for v,e in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())]
        error=max(abs(a-b) for aa,bb in [(low,row['unreal_bounds_min_cm']),(high,row['unreal_bounds_max_cm'])] for a,b in zip(aa,bb))
        assert error < .001
        triangles=[]
        for index in range(row['triangles']):
            p=u.GeometryScript_MeshQueries.get_triangle_positions(dm,index);assert p[0]
            uv=u.GeometryScript_MeshQueries.get_triangle_u_vs(dm,0,index);assert uv[3]
            mat=u.GeometryScript_Materials.get_triangle_material_id(dm,index);assert mat[1]
            triangles.append(dict(positions=[list(v.to_tuple()) for v in p[1:]],uv=[list(v.to_tuple()) for v in uv[:3]],material=mat[0]))
        geom=DOC/('native_geometry_'+room+'_'+family+'_r01.json')
        assert not geom.exists()
        geom.write_text(json.dumps(dict(target=target,fbx_sha256=row['sha256'],triangles=triangles),separators=(',',':'))+'\n')
        return mesh,dict(source_render_counts=counts,materials=bindings,colour_byte_set_exact=True,colour_count=len(actual),normal_length_range=nrange,bounds_min_cm=low,bounds_max_cm=high,bounds_error_cm=error,UV_channels=1,simple_collision=0,convex_collision=0,nanite=False,render_geometry_file=geom.relative_to(ROOT).as_posix(),render_geometry_sha256=sha(geom))
    transaction(room,family,'mesh',build)
