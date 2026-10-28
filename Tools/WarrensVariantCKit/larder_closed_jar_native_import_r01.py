"""One absent-only private closed decorative jar; no existing asset is reimported."""
import hashlib,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
RUN=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout'
MODEL=DOC/'closed-storage-jar-r03'
TARGET='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/Meshes/WVC_Larder_ClosedStorageJar_R01_SM'
MATERIAL='/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX15'
OWNER='Mars.WarrensVariantC.Larder.ClosedDecorativeJar.R01'

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def guard(require_clean=True):
    path=Path(__file__).with_name('larder_surface_pie_trial_r04.py')
    assert sha(path)=='c4f40842a3ab4ed93ce93e51b6c6b3b6c1c426c08b0aa3ebb2a0376b35f1da9e'
    spec=importlib.util.spec_from_file_location('_closed_jar_source_guard',path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);module.guard()
    if require_clean:module.clean()

def preflight():
    import unreal as u
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    guard();editor=u.get_editor_subsystem(u.UnrealEditorSubsystem)
    assert editor.get_game_world() is None and editor.get_editor_world().get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    assert sha(MODEL/'receipt.json')=='1e39ca111dc2376688a279d9e1528167c739d282ad2cbb8446e7b796ba8028ea'
    assert sha(MODEL/'fbx_roundtrip_r02.json')=='e65d6076ff07d5004af19fa3e291fb7279ba9d7c59f009830ea3ab1e16d24be0'
    row=json.loads((MODEL/'receipt.json').read_text());assert sha(ROOT/row['fbx'])==row['fbx_sha256']=='b1f8e38a68a864d9c1ecaf915d77820a234a01bb5930abfb1c2825054fea8828'
    assert not u.EditorAssetLibrary.does_asset_exist(TARGET) and not (ROOT/('Content/'+TARGET.removeprefix('/Game/')+'.uasset')).exists()
    assert isinstance(u.load_asset(MATERIAL),u.MaterialInterface)
    assert not (RUN/'closed_jar_native_import_attempt_r01.json').exists() and not (RUN/'closed_jar_mesh_asset_r01.json').exists()
    return row

def run():
    import unreal as u
    row=preflight();gate=json.loads((DOC/'NATIVE_CLOSED_JAR_IMPORT_GATE_R01.json').read_text())
    assert gate['status']=='APPROVED_ONE_ABSENT_PRIVATE_CLOSED_DECORATIVE_JAR_ONLY' and gate['tool_sha256']==sha(__file__)
    settings=u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'));autosave=settings.get_editor_property('bAutoSaveEnable')
    jolt=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'));cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world();flag=u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')
    attempt=RUN/'closed_jar_native_import_attempt_r01.json'
    attempt.write_text(json.dumps(dict(status='ONE_ABSENT_PRIVATE_ASSET_ATTEMPT_NO_AUTOMATIC_RETRY',target=TARGET,fbx_sha256=row['fbx_sha256'],tool_sha256=sha(__file__),original_autosave=autosave,original_cook=str(cook),original_interchange=flag),indent=2)+'\n')
    try:
        settings.set_editor_property('bAutoSaveEnable',False);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',u.Ck_EnableDisable.DISABLE)
        assert settings.get_editor_property('bAutoSaveEnable') is False and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==u.Ck_EnableDisable.DISABLE
        task=u.AssetImportTask();task.filename=str(ROOT/row['fbx']);task.destination_path=TARGET.rsplit('/',1)[0];task.destination_name=TARGET.rsplit('/',1)[1];task.automated=True;task.replace_existing=False;task.replace_existing_settings=False;task.save=False;task.async_=False;task.factory=u.FbxFactory()
        opts=u.FbxImportUI();opts.automated_import_should_detect_type=False;opts.import_as_skeletal=False;opts.import_mesh=True;opts.import_animations=False;opts.import_materials=False;opts.import_textures=False;opts.mesh_type_to_import=u.FBXImportType.FBXIT_STATIC_MESH
        for key,value in dict(combine_meshes=True,remove_degenerates=False,auto_generate_collision=False,generate_lightmap_u_vs=False,build_nanite=False,transform_vertex_to_absolute=True,reorder_material_to_fbx_order=True,import_uniform_scale=1.,normal_import_method=u.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS,vertex_color_import_option=u.VertexColorImportOption.REPLACE).items():opts.static_mesh_import_data.set_editor_property(key,value)
        task.options=opts;u.SystemLibrary.execute_console_command(world,'Interchange.FeatureFlags.Import.FBX 0')
        assert u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX') is False
        u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task]);mesh=u.load_asset(TARGET);assert isinstance(mesh,u.StaticMesh)
        slots=list(mesh.get_editor_property('static_materials'));assert len(slots)==1 and str(slots[0].get_editor_property('imported_material_slot_name'))==row['source_material_slot']
        slots[0].set_editor_property('material_interface',u.load_asset(MATERIAL));mesh.set_editor_property('static_materials',slots)
        actual_slots=list(mesh.get_editor_property('static_materials'))
        assert len(actual_slots)==1 and actual_slots[0].get_editor_property('material_interface').get_path_name()==MATERIAL+'.'+MATERIAL.rsplit('/',1)[1]
        filenames=mesh.get_editor_property('asset_import_data').extract_filenames()
        assert len(filenames)==1 and Path(filenames[0]).resolve()==(ROOT/row['fbx']).resolve()
        sub=u.get_editor_subsystem(u.StaticMeshEditorSubsystem)
        assert mesh.get_editor_property('asset_import_data').get_editor_property('remove_degenerates') is False and sub.get_lod_build_settings(mesh,0).get_editor_property('remove_degenerates') is False
        sub.remove_collisions(mesh);assert sub.get_simple_collision_count(mesh)==sub.get_convex_collision_count(mesh)==0
        assert sub.get_num_uv_channels(mesh,0)==1
        bounds=mesh.get_bounds();lo=[v-e for v,e in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())];hi=[v+e for v,e in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())]
        error=max(abs(a-b) for actual,expected in zip([lo,hi],row['final_bounds_cm']) for a,b in zip(actual,expected));assert error<.001
        counts={};render=None
        for name,kind in [('source',u.GeometryScriptLODType.SOURCE_MODEL),('render',u.GeometryScriptLODType.RENDER_DATA)]:
            dm=u.DynamicMesh();lod=u.GeometryScriptMeshReadLOD();lod.lod_type=kind;lod.lod_index=0
            result=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh,dm,u.GeometryScriptCopyMeshFromAssetOptions(),lod)
            assert result[1]==u.GeometryScriptOutcomePins.SUCCESS;counts[name]=dm.get_triangle_count();assert counts[name]==328
            if name=='render':render=dm
        normals=u.GeometryScript_Normals.get_mesh_per_vertex_normals(render,False);assert normals[2] is True and normals[3] is False
        values=u.GeometryScript_List.convert_vector_list_to_array(normals[1]);minimum=min(v.length() for v in values);maximum=max(v.length() for v in values);assert .99<minimum<=maximum<1.01
        bvh=u.GeometryScript_MeshSpatial.build_bvh_for_mesh(render)[1];assert u.GeometryScript_MeshSpatial.is_bvh_valid_for_mesh(render,bvh)[1]
        query=u.GeometryScriptSpatialQueryOptions();query.max_distance=100.;query.allow_unsafe_modified_queries=False
        hit=u.GeometryScript_MeshSpatial.find_nearest_ray_intersection_with_mesh(render,bvh,u.Vector(0,0,80),u.Vector(0,0,-1),query)[1]
        assert hit.hit and abs(hit.hit_position.z-59.4)<.001
        assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==[] and [p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()]==[TARGET]
        guard(require_clean=False)
        u.EditorAssetLibrary.set_metadata_tag(mesh,'Owner',OWNER);assert u.EditorAssetLibrary.save_loaded_asset(mesh,False)
        record=dict(status='ONE_PRIVATE_CLOSED_DECORATIVE_JAR_SAVED_NOT_NATIVE_ROOM_ACCEPTANCE',tool_sha256=sha(__file__),gate_sha256=sha(DOC/'NATIVE_CLOSED_JAR_IMPORT_GATE_R01.json'),assets={TARGET:dict(package_sha256=sha(ROOT/('Content/'+TARGET.removeprefix('/Game/')+'.uasset')),fbx_sha256=row['fbx_sha256'],triangles=counts,uv_channels=1,material=MATERIAL,bounds_min_cm=lo,bounds_max_cm=hi,bounds_error_cm=error,normal_length_range=[minimum,maximum],top_centre_hit_cm=list(hit.hit_position.to_tuple()),simple_collision=0,convex_collision=0)})
        (RUN/'closed_jar_mesh_asset_r01.json').write_text(json.dumps(record,indent=2)+'\n');guard();print('PRIVATE_CLOSED_JAR_SAVED',json.dumps(record))
    finally:
        u.SystemLibrary.execute_console_command(world,'Interchange.FeatureFlags.Import.FBX '+('1' if flag else '0'));settings.set_editor_property('bAutoSaveEnable',autosave);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',cook)
        assert u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')==flag and settings.get_editor_property('bAutoSaveEnable')==autosave and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==cook
