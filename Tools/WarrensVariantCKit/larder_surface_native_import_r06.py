"""Absent-only repaired Wall successor; all original three private surfaces immutable."""
import hashlib,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
DEST='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01'
BASE='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02'
OWNER='Mars.WarrensVariantC.Larder.SurfaceReview.R01'
STATE=None


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def guard():
    p=Path(__file__).with_name('room_art_capture_r33.py');s=importlib.util.spec_from_file_location('_larder_import_guard',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);m.guard()
    prior=json.loads((RUN/'surface_mesh_assets_r01.json').read_text());assert len(prior['assets'])==3
    assert all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==v['package_sha256'] for p,v in prior['assets'].items())


def dirty():
    import unreal as u
    return dict(maps=[p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()],content=[p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()])


def project():
    import unreal as u
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve(), 'Native project is not this workspace'


def preflight():
    import unreal as u
    global STATE
    assert STATE is None;project();guard();assert dirty()==dict(maps=[],content=[])
    editor=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert editor.get_game_world() is None and editor.get_editor_world().get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    ep=DOC/'export-r04/export.json';ap=DOC/'export-r04/fbx_roundtrip_r02.json';export=json.loads(ep.read_text());audit=json.loads(ap.read_text());assert audit['export_sha256']==sha(ep) and len(audit['meshes'])==3 and audit['authored_bell_ray']['new_mesh_intersection'] is False
    assert sha(ap)=='5e92b750b39d834d7029ea19d40e01153e7e161d06b8f974428c1e203132e712'
    row,=[v for v in export['exports'] if v['family']=='walls'];assert row['name']=='WVC_Larder_Walls_R02_SM' and row['triangles']==207152
    target=DEST+'/Meshes/'+row['name'];assert not u.EditorAssetLibrary.does_asset_exist(target) and not (ROOT/('Content/'+target.removeprefix('/Game/')+'.uasset')).exists()
    assert sha(ROOT/row['file'])==row['sha256']
    STATE=dict(export=export,export_sha256=sha(ep),audit_sha256=sha(ap),assets={},loaded_tool_sha256=sha(__file__),resume_target=None,prior_failure_sha256=None)
    print('ABSENT_ONLY_REPAIRED_WALL_IMPORT_PREFLIGHT')


def import_family(family):
    import unreal as u
    s=STATE;assert s and family=='walls' and sha(__file__)==s['loaded_tool_sha256'];project();guard()
    gate=json.loads((DOC/'NATIVE_WALL_REPAIR_GATE_R07.json').read_text());assert gate['status']=='APPROVED_ABSENT_WALL_SUCCESSOR_AND_DISPOSABLE_TRIAL_ONLY' and gate['import_tool_sha256']==sha(__file__) and gate['fbx_audit_sha256']==s['audit_sha256'] and gate['export_sha256']==s['export_sha256']
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    for path,row in s['assets'].items():assert sha(ROOT/('Content/'+path.removeprefix('/Game/')+'.uasset'))==row['package_sha256']
    row,=[v for v in s['export']['exports'] if v['family']==family];target=DEST+'/Meshes/'+row['name'];resume=False;assert not u.EditorAssetLibrary.does_asset_exist(target) and not (ROOT/('Content/'+target.removeprefix('/Game/')+'.uasset')).exists();assert dirty()==dict(maps=[],content=[target] if resume else [])
    assert sha(ROOT/row['file'])==row['sha256']
    settings=u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'));autosave=settings.get_editor_property('bAutoSaveEnable')
    jolt=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'));cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world();flag=u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')
    attempt=RUN/(family+'_native_import_attempt_r05.json');assert not attempt.exists();attempt.write_text(json.dumps(dict(status='ATTEMPTING_ONE_NEW_PRIVATE_MESH_NO_AUTOMATIC_RETRY',target=target,source_sha256=row['sha256'],tool_sha256=sha(__file__),original_autosave=autosave,original_cook=str(cook),original_interchange_flag=flag,resume_existing_unsaved_floor=resume,prior_failure_sha256=s['prior_failure_sha256']),indent=2)+'\n')
    try:
        settings.set_editor_property('bAutoSaveEnable',False);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',u.Ck_EnableDisable.DISABLE)
        assert settings.get_editor_property('bAutoSaveEnable') is False and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==u.Ck_EnableDisable.DISABLE
        task=u.AssetImportTask();task.filename=str(ROOT/row['file']);task.destination_path=DEST+'/Meshes';task.destination_name=row['name'];task.automated=True;task.replace_existing=False;task.replace_existing_settings=False;task.save=False;task.async_=False;task.factory=u.FbxFactory()
        opts=u.FbxImportUI();opts.automated_import_should_detect_type=False;opts.import_as_skeletal=False;opts.import_mesh=True;opts.import_animations=False;opts.import_materials=False;opts.import_textures=False;opts.mesh_type_to_import=u.FBXImportType.FBXIT_STATIC_MESH
        for k,v in dict(combine_meshes=True,remove_degenerates=False,auto_generate_collision=False,generate_lightmap_u_vs=False,build_nanite=False,transform_vertex_to_absolute=True,reorder_material_to_fbx_order=True,import_uniform_scale=1.,normal_import_method=u.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS,vertex_color_import_option=u.VertexColorImportOption.REPLACE).items():opts.static_mesh_import_data.set_editor_property(k,v)
        task.options=opts;u.SystemLibrary.execute_console_command(w,'Interchange.FeatureFlags.Import.FBX 0');assert u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX') is False;project();u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task]);mesh=u.load_asset(target);assert isinstance(mesh,u.StaticMesh)
        slots=list(mesh.get_editor_property('static_materials'));assert len(slots)==2
        assignments=[]
        for slot in slots:
            name=str(slot.get_editor_property('imported_material_slot_name'));assert name in row['materials'];role='mortar' if 'QuietMortar' in name else family;mp=BASE+'/Materials/M_CP_Mortar_R02' if role=='mortar' else BASE+'/PBR_R09/Materials/M_CP_'+family.title()+'_PBR_R09'
            slot.set_editor_property('material_interface',u.load_asset(mp));assignments.append(dict(slot=name,role=role,material=mp))
        assert sorted(v['role'] for v in assignments)==sorted([family,'mortar']);mesh.set_editor_property('static_materials',slots)
        sub=u.get_editor_subsystem(u.StaticMeshEditorSubsystem);assert mesh.get_editor_property('asset_import_data').get_editor_property('remove_degenerates') is False and sub.get_lod_build_settings(mesh,0).get_editor_property('remove_degenerates') is False;sub.remove_collisions(mesh);assert sub.get_simple_collision_count(mesh)==sub.get_convex_collision_count(mesh)==0
        b=mesh.get_bounds();lo=[v-e for v,e in zip(b.origin.to_tuple(),b.box_extent.to_tuple())];hi=[v+e for v,e in zip(b.origin.to_tuple(),b.box_extent.to_tuple())];error=max(abs(x-y) for aa,bb in ((lo,row['unreal_bounds_min_cm']),(hi,row['unreal_bounds_max_cm'])) for x,y in zip(aa,bb));assert error<.01,(family,lo,hi,error)
        assert sub.get_num_uv_channels(mesh,0)==1
        dm=u.DynamicMesh();lod=u.GeometryScriptMeshReadLOD();lod.set_editor_property('lod_type',u.GeometryScriptLODType.RENDER_DATA);lod.set_editor_property('lod_index',0);copied=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh,dm,u.GeometryScriptCopyMeshFromAssetOptions(),lod);assert copied[1]==u.GeometryScriptOutcomePins.SUCCESS;assert dm.get_triangle_count()==row['triangles'],(family,dm.get_triangle_count(),row['triangles'])
        source_dm=u.DynamicMesh();source_lod=u.GeometryScriptMeshReadLOD();source_lod.set_editor_property('lod_type',u.GeometryScriptLODType.SOURCE_MODEL);source_lod.set_editor_property('lod_index',0);source_copy=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh,source_dm,u.GeometryScriptCopyMeshFromAssetOptions(),source_lod);assert source_copy[1]==u.GeometryScriptOutcomePins.SUCCESS and source_dm.get_triangle_count()==row['triangles']
        colours=u.GeometryScript_VertexColors.get_mesh_per_vertex_colors(dm,False);assert colours[2] is True and colours[3] is False;values=u.GeometryScript_List.convert_color_list_to_array(colours[1]);maximum=max(max(c.r,c.g,c.b) for c in values);assert .5<maximum<1
        normals=u.GeometryScript_Normals.get_mesh_per_vertex_normals(dm,False);assert normals[2] is True and normals[3] is False;normal_values=u.GeometryScript_List.convert_vector_list_to_array(normals[1]);assert normal_values
        normal_proof=dict(count=len(normal_values),minimum_length=min(v.length() for v in normal_values),maximum_length=max(v.length() for v in normal_values))
        assert .99<normal_proof['minimum_length']<=normal_proof['maximum_length']<1.01
        positions=u.GeometryScript_MeshQueries.get_all_vertex_positions(dm,False);assert positions[2] is False;points=u.GeometryScript_List.convert_vector_list_to_array(positions[1]);assert len(points)==len(normal_values)
        native_readback=RUN/(family+'_native_render_geometry_repair_r02.json');assert not native_readback.exists();native_readback.write_text(json.dumps(dict(asset=target,source_sha256=row['sha256'],positions=[list(v.to_tuple()) for v in points],normals=[list(v.to_tuple()) for v in normal_values],colour_maximum=maximum,triangle_count=dm.get_triangle_count()),separators=(',',':'))+'\n')
        assert dirty()['maps']==[] and set(dirty()['content'])=={target},dirty()
        u.EditorAssetLibrary.set_metadata_tag(mesh,'Owner',OWNER);assert u.EditorAssetLibrary.save_loaded_asset(mesh,False)
        s['assets'][target]=dict(family=family,package_sha256=sha(ROOT/('Content/'+target.removeprefix('/Game/')+'.uasset')),source_sha256=row['sha256'],triangles=dm.get_triangle_count(),source_model_triangles=source_dm.get_triangle_count(),asset_import_remove_degenerates=mesh.get_editor_property('asset_import_data').get_editor_property('remove_degenerates'),build_remove_degenerates=sub.get_lod_build_settings(mesh,0).get_editor_property('remove_degenerates'),bounds_min_cm=lo,bounds_max_cm=hi,bounds_error_cm=error,uv_channels=1,slots=assignments,simple_collision=0,convex_collision=0,actual_render_vertex_colour_maximum=maximum,actual_render_normals=normal_proof,native_geometry_readback_sha256=sha(native_readback))
        (RUN/'surface_wall_repair_assets_r02.json').write_text(json.dumps(dict(status='ONE_PRIVATE_REPAIRED_WALL_SAVED_NOT_ROOM_ACCEPTANCE',tool_sha256=sha(__file__),gate_sha256=sha(DOC/'NATIVE_WALL_REPAIR_GATE_R07.json'),export_sha256=s['export_sha256'],assets=s['assets']),indent=2)+'\n')
        guard();assert dirty()==dict(maps=[],content=[]);print('LARDER_PRIVATE_MESH_SAVED',family,dm.get_triangle_count(),error)
    finally:
        u.SystemLibrary.execute_console_command(w,'Interchange.FeatureFlags.Import.FBX '+('1' if flag else '0'));settings.set_editor_property('bAutoSaveEnable',autosave);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',cook)
        assert u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')==flag and settings.get_editor_property('bAutoSaveEnable')==autosave and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==cook
