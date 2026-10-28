"""One absent private winding successor; exact native geometry/UV delta before save."""
import collections,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/sack-winding-r01'
TARGET='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/Meshes/WVC_Larder_OutwardClothSack_R01_SM'
ORIGINAL='/Game/Mars/Environment/ChainCrossingKit/Meshes/WarrensC_CCS68_ClothSack_Mars_SM'
STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def disk(p):return ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset')
def run(controller):
    import unreal as u
    global STATE
    assert STATE is None and Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    assert sha(controller.__file__)=='575b8b7e11305c89549b96c54148e6d3bc879b4c4b13921252f2c4e2b151cfff';controller.guard()
    assert not u.EditorAssetLibrary.does_asset_exist(TARGET) and not disk(TARGET).exists()
    ed=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert ed.get_game_world() is None and ed.get_editor_world().get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages() and not u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
    r=json.loads((DOC/'successor.json').read_text());audit=json.loads((DOC/'fresh_fbx_audit.json').read_text());source=ROOT/r['fbx']
    assert sha(DOC/'successor.json')=='6ca06877f8682ccb96a5b9c4847e7b4ef7ec9ec860bb8d2f506703b1751cb0ca' and sha(DOC/'fresh_fbx_audit.json')=='1d02478648768948d134dd742c0dab9f34cf5e7f45969febf1b173de331803a9'
    assert sha(source)==r['fbx_sha256']==audit['candidate_sha256']=='2dd7480f4616fdeb86cec034c2d5f322d00edfb9ad0892f0c9530a1742985905' and audit['status']=='FRESH_FBX_EXACT_REVERSED_CLOTH_UNCHANGED_TIES_COORDS_UV_MATERIALS_BOUNDS_PASS'
    assert sha(ROOT/r['source'])=='94d0ad5788475715a4c6aba5d32825da72a699082e36e9e1e128ae2817ed50a3' and not (DOC/'native_asset.json').exists()
    attempt=DOC/'native_import_attempt.json';assert not attempt.exists();attempt.write_text(json.dumps(dict(target=TARGET,fbx_sha256=sha(source),tool_sha256=sha(__file__),status='ONE_ABSENT_PRIVATE_IMPORT_NO_AUTOMATIC_RETRY'),indent=2)+'\n')
    settings=u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'));autosave=settings.get_editor_property('bAutoSaveEnable');jolt=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'));cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave');flag=u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX');world=ed.get_editor_world()
    try:
        settings.set_editor_property('bAutoSaveEnable',False);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',u.Ck_EnableDisable.DISABLE);u.SystemLibrary.execute_console_command(world,'Interchange.FeatureFlags.Import.FBX 0')
        assert settings.get_editor_property('bAutoSaveEnable') is False and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==u.Ck_EnableDisable.DISABLE and u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX') is False
        task=u.AssetImportTask();task.filename=str(source);task.destination_path=TARGET.rsplit('/',1)[0];task.destination_name=TARGET.rsplit('/',1)[1];task.automated=True;task.replace_existing=False;task.replace_existing_settings=False;task.save=False;task.async_=False;task.factory=u.FbxFactory()
        options=u.FbxImportUI();options.automated_import_should_detect_type=False;options.import_as_skeletal=False;options.import_mesh=True;options.import_animations=False;options.import_materials=False;options.import_textures=False;options.mesh_type_to_import=u.FBXImportType.FBXIT_STATIC_MESH
        for k,v in dict(combine_meshes=True,remove_degenerates=False,auto_generate_collision=False,generate_lightmap_u_vs=False,build_nanite=False,transform_vertex_to_absolute=True,reorder_material_to_fbx_order=True,import_uniform_scale=1.,normal_import_method=u.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS,vertex_color_import_option=u.VertexColorImportOption.REPLACE).items():options.static_mesh_import_data.set_editor_property(k,v)
        task.options=options;u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task]);asset=u.load_asset(TARGET);assert isinstance(asset,u.StaticMesh);STATE=dict(asset=asset,status='PENDING_VALIDATION_NO_FACTORY_RETRY')
        filenames=asset.get_editor_property('asset_import_data').extract_filenames();assert len(filenames)==1 and Path(filenames[0]).resolve()==source.resolve()
        assert asset.get_editor_property('asset_import_data').get_editor_property('remove_degenerates') is False
        slots=list(asset.static_materials);assert [str(v.get_editor_property('imported_material_slot_name')) for v in slots]==['WarrensC_LinenCanvas_Mars_MI','WarrensC_RopeFibre_Mars_MI']
        for slot,n in zip(slots,['TX12','TX14']):slot.set_editor_property('material_interface',u.load_asset('/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'+n))
        asset.set_editor_property('static_materials',slots)
        assert [v.get_editor_property('material_interface').get_path_name().split('.')[0] for v in asset.static_materials]==['/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'+n for n in ['TX12','TX14']]
        sub=u.get_editor_subsystem(u.StaticMeshEditorSubsystem);sub.remove_collisions(asset)
        assert sub.get_simple_collision_count(asset)==sub.get_convex_collision_count(asset)==0 and sub.get_num_uv_channels(asset,0)==1
        assert not asset.get_editor_property('nanite_settings').get_editor_property('enabled') and not sub.get_lod_build_settings(asset,0).get_editor_property('remove_degenerates')
        original=u.load_asset(ORIGINAL)
        def canonical(c):return min(tuple(c[i:]+c[:i]) for i in range(3))
        def signatures(mesh,kind,reverse):
            dm=u.DynamicMesh();lod=u.GeometryScriptMeshReadLOD();lod.lod_type=kind;lod.lod_index=0;res=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh,dm,u.GeometryScriptCopyMeshFromAssetOptions(),lod);assert res[1]==u.GeometryScriptOutcomePins.SUCCESS and dm.get_triangle_count()==320
            result=collections.Counter();counts=collections.Counter();normal_map={}
            for i in range(320):
                ps=u.GeometryScript_MeshQueries.get_triangle_positions(dm,i);vs=u.GeometryScript_MeshQueries.get_triangle_u_vs(dm,0,i);mat,valid=u.GeometryScript_Materials.get_triangle_material_id(dm,i);assert ps[0] and vs[3] and valid
                corners=[(tuple(v.to_tuple()),tuple(uv.to_tuple())) for v,uv in zip(ps[1:],vs[:3])]
                ns=u.GeometryScript_MeshQueries.get_triangle_normals(dm,i);assert ns[4]
                normal_map[(mat,tuple(sorted(corners)))]=[tuple((n*(-1 if reverse and mat==0 else 1)).to_tuple()) for n in ns[1:4]]
                if reverse and mat==0:corners.reverse();normal_map[(mat,tuple(sorted(corners)))].reverse()
                # Store normals by corner so render-buffer vertex permutations cannot hide a bad normal.
                normal_map[(mat,tuple(sorted(corners)))]=dict(zip(corners,normal_map[(mat,tuple(sorted(corners)))]))
                result[(mat,canonical(corners))]+=1;counts[mat]+=1
            assert counts=={0:128,1:192};return result,normal_map
        normal_errors={}
        for label,kind in [('source',u.GeometryScriptLODType.SOURCE_MODEL),('render',u.GeometryScriptLODType.RENDER_DATA)]:
            old_sig,old_normals=signatures(original,kind,True);new_sig,new_normals=signatures(asset,kind,False);assert old_sig==new_sig and old_normals.keys()==new_normals.keys()
            delta=max((u.Vector(*n)-u.Vector(*new_normals[k][corner])).length() for k,vs in old_normals.items() for corner,n in vs.items());assert delta<(1e-5 if label=='source' else .014)
            normal_errors[label]=delta
        bounds=asset.get_bounds();b=[[a-v for a,v in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())],[a+v for a,v in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())]];assert max(abs(x-y) for xs,ys in zip(b,audit['bounds_cm']) for x,y in zip(xs,ys))<.001
        controller.guard();assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages() and [p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()]==[TARGET]
        u.EditorAssetLibrary.set_metadata_tag(asset,'Owner','Mars.WarrensVariantC.Larder.WindingOnly.R01');assert u.EditorAssetLibrary.save_loaded_asset(asset,False)
        assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages() and not u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
        proof=dict(status='PRIVATE_SAVED_NATIVE_SOURCE_RENDER_EXACT_CLOTH_REVERSAL_UV_MATERIALS_TIES_PASS_NOT_APPEARANCE_ACCEPTED',target=TARGET,package_sha256=sha(disk(TARGET)),fbx_sha256=sha(source),audit_sha256=sha(DOC/'fresh_fbx_audit.json'),tool_sha256=sha(__file__),source_render_triangle_counts=320,reversed_cloth=128,unchanged_ties=192,native_all_positions_UV_materials_exact=True,maximum_corner_normal_delta=normal_errors,normal_tolerance=dict(source=1e-5,render=.014),bounds_cm=b,simple_collision=0,convex_collision=0)
        (DOC/'native_asset.json').write_text(json.dumps(proof,indent=2)+'\n');STATE=dict(asset=asset,status='SAVED_NOT_BOUND',proof=proof);controller.guard();print('OUTWARD_SACK_PRIVATE_SAVED',proof['package_sha256'])
    finally:
        u.SystemLibrary.execute_console_command(world,'Interchange.FeatureFlags.Import.FBX '+('1' if flag else '0'));settings.set_editor_property('bAutoSaveEnable',autosave);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',cook)
        assert u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')==flag and settings.get_editor_property('bAutoSaveEnable')==autosave and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==cook
