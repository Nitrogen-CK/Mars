"""Two absent-only private assets for reviewed sack/water comparison; no bindings."""
import hashlib,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
RUN=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout'
DEST='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01'
TARGETS={'sack':DEST+'/Meshes/WVC_Larder_StableFootSack_R01_SM','normal':DEST+'/PBR_R02/Textures/T_Larder_BrineWave_NormalDX_R01'}
STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def disk(asset):return ROOT/('Content/'+asset.removeprefix('/Game/')+'.uasset')
def dirty():
    import unreal as u
    return dict(maps=[p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()],content=[p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()])
def guard():
    p=Path(__file__).with_name('larder_surface_pie_trial_r04.py');assert sha(p)=='c4f40842a3ab4ed93ce93e51b6c6b3b6c1c426c08b0aa3ebb2a0376b35f1da9e';spec=importlib.util.spec_from_file_location('_corrective_guard',p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.guard()
    ledger=json.loads((RUN/'closed_jar_mesh_asset_r01.json').read_text());assert len(ledger['assets'])==1
    for p,r in ledger['assets'].items():assert sha(disk(p))==r['package_sha256']
    if STATE:
        for p,r in STATE['assets'].items():assert sha(disk(p))==r['package_sha256']
def preflight():
    import unreal as u
    global STATE
    assert STATE is None and Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve();guard();assert dirty()==dict(maps=[],content=[])
    ed=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert ed.get_game_world() is None and ed.get_editor_world().get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    gate=json.loads((DOC/'NATIVE_CORRECTIVE_ASSETS_GATE_R01.json').read_text());assert gate['status']=='APPROVED_TWO_ABSENT_PRIVATE_CORRECTIVE_ASSETS_NO_BINDING' and gate['tool_sha256']==sha(__file__)
    for p,h in gate['input_sha256'].items():assert sha(ROOT/p)==h
    for p in TARGETS.values():assert not u.EditorAssetLibrary.does_asset_exist(p) and not disk(p).exists()
    assert not (RUN/'corrective_assets_r01.json').exists()
    STATE=dict(gate=gate,assets={},tool_sha256=sha(__file__));print('CORRECTIVE_ASSET_PREFLIGHT_BOTH_ABSENT')

def import_one(role):
    import unreal as u
    s=STATE;assert s and role in TARGETS and s['tool_sha256']==sha(__file__) and u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None;guard();assert dirty()==dict(maps=[],content=[])
    for p,h in s['gate']['input_sha256'].items():assert sha(ROOT/p)==h
    target=TARGETS[role];assert target not in s['assets'] and not disk(target).exists() and not u.EditorAssetLibrary.does_asset_exist(target)
    attempt=RUN/(role+'_corrective_import_attempt_r01.json');assert not attempt.exists()
    sack=json.loads((DOC/'stable-sack-foot-r01/receipt.json').read_text());wave=json.loads((DOC/'brine-wave-normal-r01/receipt.json').read_text());source=ROOT/(sack['fbx'] if role=='sack' else wave['maps']['DX']['file']);source_hash=sha(source);assert source_hash==(sack['fbx_sha256'] if role=='sack' else wave['maps']['DX']['sha256'])
    settings=u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'));autosave=settings.get_editor_property('bAutoSaveEnable');jolt=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'));cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave');flag=u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX');world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
    attempt.write_text(json.dumps(dict(status='ONE_NEW_PRIVATE_ASSET_ATTEMPT_NO_AUTOMATIC_RETRY',role=role,target=target,source_sha256=source_hash,tool_sha256=sha(__file__),original_autosave=autosave,original_cook=str(cook),original_interchange=flag),indent=2)+'\n')
    try:
        settings.set_editor_property('bAutoSaveEnable',False);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',u.Ck_EnableDisable.DISABLE);assert settings.get_editor_property('bAutoSaveEnable') is False and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==u.Ck_EnableDisable.DISABLE
        task=u.AssetImportTask();task.filename=str(source);task.destination_path=target.rsplit('/',1)[0];task.destination_name=target.rsplit('/',1)[1];task.automated=True;task.replace_existing=False;task.replace_existing_settings=False;task.save=False;task.async_=False
        if role=='sack':
            task.factory=u.FbxFactory();options=u.FbxImportUI();options.automated_import_should_detect_type=False;options.import_as_skeletal=False;options.import_mesh=True;options.import_animations=False;options.import_materials=False;options.import_textures=False;options.mesh_type_to_import=u.FBXImportType.FBXIT_STATIC_MESH
            for k,v in dict(combine_meshes=True,remove_degenerates=False,auto_generate_collision=False,generate_lightmap_u_vs=False,build_nanite=False,transform_vertex_to_absolute=True,reorder_material_to_fbx_order=True,import_uniform_scale=1.,normal_import_method=u.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS,vertex_color_import_option=u.VertexColorImportOption.REPLACE).items():options.static_mesh_import_data.set_editor_property(k,v)
            task.options=options;u.SystemLibrary.execute_console_command(world,'Interchange.FeatureFlags.Import.FBX 0');assert u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX') is False
        else:task.factory=u.TextureFactory()
        u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task]);asset=u.load_asset(target);assert asset
        filenames=asset.get_editor_property('asset_import_data').extract_filenames();assert len(filenames)==1 and Path(filenames[0]).resolve()==source.resolve()
        proof=dict(source_sha256=source_hash,source_file=source.relative_to(ROOT).as_posix())
        if role=='sack':
            assert isinstance(asset,u.StaticMesh);slots=list(asset.get_editor_property('static_materials'));assert [str(v.get_editor_property('imported_material_slot_name')) for v in slots]==['WarrensC_LinenCanvas_Mars_MI','WarrensC_RopeFibre_Mars_MI']
            materials=['/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'+v for v in ['TX12','TX14']]
            for slot,material in zip(slots,materials):slot.set_editor_property('material_interface',u.load_asset(material))
            asset.set_editor_property('static_materials',slots);assert [v.get_editor_property('material_interface').get_path_name().split('.')[0] for v in asset.static_materials]==materials
            sub=u.get_editor_subsystem(u.StaticMeshEditorSubsystem);assert asset.get_editor_property('asset_import_data').get_editor_property('remove_degenerates') is False and sub.get_lod_build_settings(asset,0).get_editor_property('remove_degenerates') is False
            sub.remove_collisions(asset);assert sub.get_simple_collision_count(asset)==sub.get_convex_collision_count(asset)==0 and sub.get_num_uv_channels(asset,0)==1
            bounds=asset.get_bounds();lo=[a-b for a,b in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())];hi=[a+b for a,b in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())];error=max(abs(a-b) for actual,expected in zip([lo,hi],sack['final_bounds_cm']) for a,b in zip(actual,expected));assert error<.001
            counts={};render=None
            for name,kind in [('source',u.GeometryScriptLODType.SOURCE_MODEL),('render',u.GeometryScriptLODType.RENDER_DATA)]:
                dm=u.DynamicMesh();lod=u.GeometryScriptMeshReadLOD();lod.lod_type=kind;lod.lod_index=0;result=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(asset,dm,u.GeometryScriptCopyMeshFromAssetOptions(),lod);assert result[1]==u.GeometryScriptOutcomePins.SUCCESS;counts[name]=dm.get_triangle_count();assert counts[name]==320
                if name=='render':render=dm
            normal=u.GeometryScript_Normals.get_mesh_per_vertex_normals(render,False);assert normal[2] is True and normal[3] is False;vectors=u.GeometryScript_List.convert_vector_list_to_array(normal[1]);lengths=[v.length() for v in vectors];assert .99<min(lengths)<=max(lengths)<1.01
            triangles=[]
            for i in range(render.get_triangle_count()):
                positions=u.GeometryScript_MeshQueries.get_triangle_positions(render,i);assert positions[0];triangles.append([list(v.to_tuple()) for v in positions[1:]])
            geometry=RUN/'stable_sack_native_render_r01.json';assert not geometry.exists();geometry.write_text(json.dumps(dict(asset=target,triangles=triangles),indent=2)+'\n')
            proof.update(triangles=counts,uv_channels=1,materials=materials,bounds_cm=[lo,hi],bounds_error_cm=error,normal_length_range=[min(lengths),max(lengths)],simple_collision=0,convex_collision=0,native_geometry_sha256=sha(geometry))
        else:
            assert isinstance(asset,u.Texture2D)
            for k,v in dict(srgb=False,compression_settings=u.TextureCompressionSettings.TC_NORMALMAP,address_x=u.TextureAddress.TA_WRAP,address_y=u.TextureAddress.TA_WRAP,flip_green_channel=False).items():asset.set_editor_property(k,v);assert asset.get_editor_property(k)==v
            assert asset.blueprint_get_size_x()==asset.blueprint_get_size_y()==1024
            proof.update(size=[1024,1024],srgb=asset.get_editor_property('srgb'),compression=str(asset.get_editor_property('compression_settings')),wrap=[str(asset.get_editor_property('address_x')),str(asset.get_editor_property('address_y'))],flip_green=asset.get_editor_property('flip_green_channel'),convention='DirectX from independent actual geometry bake; no additional green flip')
        guard();assert dirty()==dict(maps=[],content=[target]);u.EditorAssetLibrary.set_metadata_tag(asset,'Owner','Mars.WarrensVariantC.Larder.CorrectiveAssets.R01');assert u.EditorAssetLibrary.save_loaded_asset(asset,False)
        proof['package_sha256']=sha(disk(target));s['assets'][target]=proof;(RUN/'corrective_assets_r01.json').write_text(json.dumps(dict(status='PRIVATE_CORRECTIVE_ASSETS_SAVED_NOT_BOUND_OR_ROOM_ACCEPTED',tool_sha256=sha(__file__),gate_sha256=sha(DOC/'NATIVE_CORRECTIVE_ASSETS_GATE_R01.json'),assets=s['assets']),indent=2)+'\n');guard();assert dirty()==dict(maps=[],content=[]);print('PRIVATE_CORRECTIVE_ASSET_SAVED',role,proof['package_sha256'])
    finally:
        u.SystemLibrary.execute_console_command(world,'Interchange.FeatureFlags.Import.FBX '+('1' if flag else '0'));settings.set_editor_property('bAutoSaveEnable',autosave);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',cook)
        assert u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')==flag and settings.get_editor_property('bAutoSaveEnable')==autosave and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==cook
