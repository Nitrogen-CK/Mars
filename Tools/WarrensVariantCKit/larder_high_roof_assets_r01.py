"""One absent private roof veneer. No source map, material or library writes."""
import hashlib,importlib.util,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
TARGET='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/Meshes/WVC_Larder_HighRoof_R01_SM'
STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def disk(p):return ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset')
def module(name):
    p=Path(__file__).with_name(name+'.py');s=importlib.util.spec_from_file_location('_roof_asset_'+name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def guard():
    p=Path(__file__).with_name('outward_sack_native_r01.py');assert sha(p)=='3b8057a78f1de0590373fe35538aa8fa75ba6d602846e17951c96321e0d887ed';m=module('outward_sack_native_r01');m.seven_guard(module('larder_room_finish_trial_r02'));r=json.loads((DOC/'sack-winding-r01/native_asset.json').read_text());assert sha(disk(r['target']))==r['package_sha256']=='e4e92ef5f0086ba63f31b56d979d8b21995cd97fb3bd91f623a9442a93862bfd'
def dirty():
    import unreal as u
    return dict(maps=[p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()],content=[p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()])
def gate():
    g=json.loads((DOC/'NATIVE_HIGH_ROOF_GATE_R01.json').read_text());assert g['status']=='APPROVED_ABSENT_PRIVATE_HIGH_ROOF_AND_DISPOSABLE_TRIAL_ONLY' and g['import_tool_sha256']==sha(__file__)
    for required in ['Tools/WarrensVariantCKit/catacomb_pilot_manifest.py','Tools/WarrensVariantCKit/audit_room_study_triangles_r03.py','docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/roof-completion-export-r01/colour_quantization_proof.json']:assert required in g['input_sha256']
    for p,h in g['input_sha256'].items():assert sha(ROOT/p)==h
    return g
def native_coverage(dm,export,audit,manifest):
    import unreal as u
    rect_map={(v['axis'],v['source']):v['world_roundtrip'] for v in audit['source_edge_float32_conversions']};rects=[[rect_map[(i%2,v)] for i,v in enumerate(c['rect'])] for c in manifest['ceiling_faces'][132:]];g=module('catacomb_pilot_manifest');segments=module('audit_room_study_triangles_r03');maximum=0.;degenerate=0
    assert dm.get_triangle_count()==7356
    for i in range(7356):
        result=u.GeometryScript_MeshQueries.get_triangle_positions(dm,i);assert result[0];points=[(v.x/100+120,v.y/100+40,v.z/100-2.5) for v in result[1:]];assert all(11.9819<v[2]<11.9871 for v in points)
        xy=[v[:2] for v in points];lo=[min(v[k] for v in xy) for k in (0,1)];hi=[max(v[k] for v in xy) for k in (0,1)];near=[r for r in rects if r[0]<=hi[0]+3e-5 and r[2]>=lo[0]-3e-5 and r[1]<=hi[1]+3e-5 and r[3]>=lo[1]-3e-5];area=g.area(xy)
        if area<1e-9:assert all(segments.segment_covered(xy[k],xy[(k+1)%3],near) for k in range(3));degenerate+=1
        else:
            covered=sum(g.area(g.clip(xy,g.rectpoly(r))) for r in near);perimeter=sum(math.dist(xy[k],xy[(k+1)%3]) for k in range(3));error=abs(covered-area)/max(perimeter,1e-12);assert abs(covered-area)<=max(1e-10,perimeter*1e-7),(i,error);maximum=max(maximum,error)
    return dict(triangles=7356,degenerate_projected_segments_checked=degenerate,maximum_area_perimeter_error_metres=maximum,limit_metres=1e-7,full_window_aperture_below_mesh=True)
def run():
    import unreal as u
    global STATE
    assert STATE is None and Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve();guard();assert dirty()==dict(maps=[],content=[])
    ed=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert ed.get_game_world() is None and ed.get_editor_world().get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    approved=gate();folder=DOC/'roof-completion-export-r01';e=json.loads((folder/'export.json').read_text());a=json.loads((folder/'fresh_fbx_audit.json').read_text());manifest=json.loads((ROOT/e['manifest']).read_text());assert a['export_sha256']==sha(folder/'export.json') and e['triangles']==a['triangles']==7356
    source=ROOT/e['file'];assert sha(source)==e['fbx_sha256']==a['fbx_sha256'];assert not u.EditorAssetLibrary.does_asset_exist(TARGET) and not disk(TARGET).exists() and not (folder/'native_asset.json').exists()
    colour_proof=json.loads((folder/'colour_quantization_proof.json').read_text());assert colour_proof['accepted_exact_set_equality'] is True and sha(folder/'raw_fbx_linear_colours.json')==colour_proof['new_raw_payload_sha256']
    attempt=folder/'native_import_attempt.json';assert not attempt.exists();settings=u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'));autosave=settings.get_editor_property('bAutoSaveEnable');jolt=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'));cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave');flag=u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX');world=ed.get_editor_world()
    attempt.write_text(json.dumps(dict(status='ONE_ABSENT_PRIVATE_ROOF_IMPORT_NO_AUTOMATIC_RETRY',target=TARGET,tool_sha256=sha(__file__),fbx_sha256=sha(source),autosave=autosave,cook=str(cook),interchange=flag),indent=2)+'\n')
    try:
        settings.set_editor_property('bAutoSaveEnable',False);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',u.Ck_EnableDisable.DISABLE);u.SystemLibrary.execute_console_command(world,'Interchange.FeatureFlags.Import.FBX 0');assert settings.get_editor_property('bAutoSaveEnable') is False and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==u.Ck_EnableDisable.DISABLE and u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX') is False
        task=u.AssetImportTask();task.filename=str(source);task.destination_path=TARGET.rsplit('/',1)[0];task.destination_name=TARGET.rsplit('/',1)[1];task.automated=True;task.replace_existing=False;task.replace_existing_settings=False;task.save=False;task.async_=False;task.factory=u.FbxFactory();opts=u.FbxImportUI();opts.automated_import_should_detect_type=False;opts.import_as_skeletal=False;opts.import_mesh=True;opts.import_animations=False;opts.import_materials=False;opts.import_textures=False;opts.mesh_type_to_import=u.FBXImportType.FBXIT_STATIC_MESH
        for k,v in dict(combine_meshes=True,remove_degenerates=False,auto_generate_collision=False,generate_lightmap_u_vs=False,build_nanite=False,transform_vertex_to_absolute=True,reorder_material_to_fbx_order=True,import_uniform_scale=1.,normal_import_method=u.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS,vertex_color_import_option=u.VertexColorImportOption.REPLACE).items():opts.static_mesh_import_data.set_editor_property(k,v)
        task.options=opts;u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task]);mesh=u.load_asset(TARGET);assert isinstance(mesh,u.StaticMesh);STATE=dict(stage='PENDING_VALIDATION_NO_FACTORY_RETRY',asset=mesh)
        filenames=mesh.get_editor_property('asset_import_data').extract_filenames();assert len(filenames)==1 and Path(filenames[0]).resolve()==source.resolve();slots=list(mesh.static_materials);assert [str(v.get_editor_property('imported_material_slot_name')) for v in slots]==e['materials']
        prototype=u.load_asset('/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/Meshes/WVC_Larder_Ceiling_R01_SM');bindings={str(v.get_editor_property('imported_material_slot_name')):v.get_editor_property('material_interface') for v in prototype.static_materials};assert set(bindings)==set(e['materials'])
        for slot in slots:slot.set_editor_property('material_interface',bindings[str(slot.get_editor_property('imported_material_slot_name'))])
        mesh.set_editor_property('static_materials',slots);assert [v.get_editor_property('material_interface') for v in mesh.static_materials]==[bindings[n] for n in e['materials']]
        sub=u.get_editor_subsystem(u.StaticMeshEditorSubsystem);sub.remove_collisions(mesh);assert sub.get_simple_collision_count(mesh)==sub.get_convex_collision_count(mesh)==0 and sub.get_num_uv_channels(mesh,0)==1 and not mesh.get_editor_property('nanite_settings').get_editor_property('enabled');assert not mesh.get_editor_property('asset_import_data').get_editor_property('remove_degenerates') and not sub.get_lod_build_settings(mesh,0).get_editor_property('remove_degenerates')
        counts={};render=None
        for label,kind in [('source',u.GeometryScriptLODType.SOURCE_MODEL),('render',u.GeometryScriptLODType.RENDER_DATA)]:
            dm=u.DynamicMesh();lod=u.GeometryScriptMeshReadLOD();lod.lod_type=kind;lod.lod_index=0;result=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh,dm,u.GeometryScriptCopyMeshFromAssetOptions(),lod);assert result[1]==u.GeometryScriptOutcomePins.SUCCESS and dm.get_triangle_count()==7356;counts[label]=7356
            if label=='render':render=dm
        normals=u.GeometryScript_Normals.get_mesh_per_vertex_normals(render,False);assert normals[2] is True and normals[3] is False;nv=u.GeometryScript_List.convert_vector_list_to_array(normals[1]);assert all(v.z<-.99 and .99<v.length()<1.01 for v in nv)
        colours=u.GeometryScript_VertexColors.get_mesh_per_vertex_colors(render,False);assert colours[2] is True and colours[3] is False;cv=u.GeometryScript_List.convert_color_list_to_array(colours[1]);colour_max=[max(c.to_tuple()[k] for c in cv) for k in range(3)]
        actual_bytes=sorted(set(tuple(round(c.to_tuple()[k]*255) for k in range(3)) for c in cv));assert actual_bytes==[tuple(v) for v in colour_proof['new_expected_RGB_bytes']]
        assert all(abs(c.to_tuple()[k]*255-round(c.to_tuple()[k]*255))<1e-4 for c in cv for k in range(3))
        bounds=mesh.get_bounds();lo=[x-y for x,y in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())];hi=[x+y for x,y in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())];error=max(abs(x-y) for aa,bb in [(lo,e['unreal_bounds_min_cm']),(hi,e['unreal_bounds_max_cm'])] for x,y in zip(aa,bb));assert error<.001
        coverage=native_coverage(render,e,a,manifest);guard();gate();assert dirty()==dict(maps=[],content=[TARGET]);u.EditorAssetLibrary.set_metadata_tag(mesh,'Owner','Mars.WarrensVariantC.Larder.HighRoof.R01');assert u.EditorAssetLibrary.save_loaded_asset(mesh,False);assert dirty()==dict(maps=[],content=[]);guard()
        receipt=dict(status='ONE_PRIVATE_HIGH_ROOF_SAVED_NOT_BOUND_OR_ART_ACCEPTED',target=TARGET,package_sha256=sha(disk(TARGET)),source_sha256=sha(source),tool_sha256=sha(__file__),gate_sha256=sha(DOC/'NATIVE_HIGH_ROOF_GATE_R01.json'),source_render_counts=counts,UV_channels=1,materials=[bindings[n].get_path_name() for n in e['materials']],bounds_min_cm=lo,bounds_max_cm=hi,bounds_error_cm=error,normal_minimum_down_dot=min(-v.z for v in nv),normal_length_range=[min(v.length() for v in nv),max(v.length() for v in nv)],colour_RGB_max=colour_max,raw_payload_colour_byte_set_exact=True,unique_RGB_bytes=len(actual_bytes),colour_proof_sha256=sha(folder/'colour_quantization_proof.json'),simple_collision=0,convex_collision=0,nanite=False,native_triangle_coverage=coverage)
        (folder/'native_asset.json').write_text(json.dumps(receipt,indent=2)+'\n');STATE=dict(stage='SAVED_NOT_BOUND',asset=mesh,proof=receipt);print('HIGH_ROOF_PRIVATE_SAVED',receipt['package_sha256'])
    finally:
        u.SystemLibrary.execute_console_command(world,'Interchange.FeatureFlags.Import.FBX '+('1' if flag else '0'));settings.set_editor_property('bAutoSaveEnable',autosave);jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',cook);assert settings.get_editor_property('bAutoSaveEnable')==autosave and jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')==cook and u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')==flag
