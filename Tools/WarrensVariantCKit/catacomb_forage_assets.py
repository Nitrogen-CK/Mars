"""Fresh owned forage art imports; no source-level assignment or shared material edits."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-forage-props-r04'
OLD='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02'
DEST=OLD+'/Forage_R04';OWNER='Mars.WarrensVariantC.Catacomb.Forage.R04'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def guard():
    g=read(RUN/'baseline_guard_r02.json');g=g['immutable_guards']|g['collision_hashes'];assert all(sha(ROOT/p)==h for p,h in g.items())
    prior=read(RUN/'candidate_assets_r09.json');assert len(prior['assets'])==26
    assert all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==r['package_sha256'] for p,r in prior['assets'].items())
    return g
def create():
    import unreal as u
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    gate=read(DOC/'NATIVE_ASSET_GATE_R01.json');assert gate['status']=='APPROVED_FOR_OWNED_FORAGE_ASSETS' and gate['tool_sha256']==sha(__file__)
    source=read(DOC/'PROP_PREVIEW_RECEIPT.json');assert gate['preview_receipt_sha256']==sha(DOC/'PROP_PREVIEW_RECEIPT.json')
    assert all(sha(DOC/r['file'])==r['sha256'] for r in source['exports']+source['frames']);guard()
    eal=u.EditorAssetLibrary;mel=u.MaterialEditingLibrary;tools=u.AssetToolsHelpers.get_asset_tools()
    names=['Materials/M_CP_ForageBronze_R01','Materials/M_CP_ForageFruit_R01','Materials/M_CP_ForageTimberPost_R01','Materials/M_CP_ForageTimberArm_R01']+['Meshes/'+r['name'] for r in source['exports']]+['DA_CP_ForagePresentation_R01']
    assert len(names)==10 and all(not eal.does_asset_exist(DEST+'/'+n) for n in names)
    receipt=dict(status='CREATING_TEN_OWNED_FORAGE_ASSETS',assets={},preview_sha256=sha(DOC/'PROP_PREVIEW_RECEIPT.json'),gate_sha256=sha(DOC/'NATIVE_ASSET_GATE_R01.json'))
    def save(asset,details):
        eal.set_metadata_tag(asset,'Owner',OWNER);assert eal.save_loaded_asset(asset,False)
        p=asset.get_path_name().split('.')[0];receipt['assets'][p]=dict(package_sha256=sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset')),details=details)
        (RUN/'forage_assets_r04.json').write_text(json.dumps(receipt,indent=2)+'\n')
    def expr(mat,cls,**props):
        n=mel.create_material_expression(mat,cls,0,0);assert n
        for k,v in props.items():n.set_editor_property(k,v)
        return n
    def link(a,out,b,pin):assert mel.connect_material_expressions(a,out,b,pin),(a.get_name(),out,b.get_name(),pin)
    mats={}
    for role,metal,rough in [('Bronze',.75,.72),('Fruit',0,.86),('TimberPost',0,.86),('TimberArm',0,.86)]:
        mat=tools.create_asset('M_CP_Forage'+role+'_R01',DEST+'/Materials',u.Material,u.MaterialFactoryNew());assert mat
        if role=='Fruit':mat.set_editor_property('two_sided',True);assert mat.get_editor_property('two_sided') is True
        if role in ('Bronze','Fruit'):
            base=expr(mat,u.MaterialExpressionVertexColor);base_pin='RGB'
        else:
            # Engine cube local coordinates [-50,50]cm -> Blender Generated [0,1].
            p=expr(mat,u.MaterialExpressionPreSkinnedPosition);vi=expr(mat,u.MaterialExpressionVertexInterpolator)
            pin,=list(mel.get_material_expression_input_names(vi));link(p,'',vi,str(pin))
            factor=expr(mat,u.MaterialExpressionConstant,r=.01);mul=expr(mat,u.MaterialExpressionMultiply);link(vi,'',mul,'A');link(factor,'',mul,'B')
            half=expr(mat,u.MaterialExpressionConstant3Vector,constant=u.LinearColor(.5,.5,.5,1));add=expr(mat,u.MaterialExpressionAdd);link(mul,'',add,'A');link(half,'',add,'B')
            axis=(8,8,.35) if role=='TimberPost' else (.35,8,8)
            axes=expr(mat,u.MaterialExpressionConstant3Vector,constant=u.LinearColor(*axis,1));stretch=expr(mat,u.MaterialExpressionMultiply);link(add,'',stretch,'A');link(axes,'',stretch,'B')
            noise=expr(mat,u.MaterialExpressionNoise,scale=2.0,levels=1,turbulence=False,output_min=0.0,output_max=1.0);link(stretch,'',noise,'Position')
            base=expr(mat,u.MaterialExpressionCustom,output_type=u.CustomMaterialOutputType.CMOT_FLOAT3,description='Four dry timber tones; broad lengthwise bands, no normal from paint',code='return V<0.38?float3(0.035,0.018,0.008):V<0.53?float3(0.075,0.036,0.014):V<0.67?float3(0.12,0.058,0.021):float3(0.17,0.085,0.029);')
            inp=u.CustomInput();inp.set_editor_property('input_name','V');base.set_editor_property('inputs',[inp]);link(noise,'',base,'V');base_pin=''
        assert mel.connect_material_property(base,base_pin,u.MaterialProperty.MP_BASE_COLOR)
        for value,prop in ((metal,u.MaterialProperty.MP_METALLIC),(rough,u.MaterialProperty.MP_ROUGHNESS)):
            n=expr(mat,u.MaterialExpressionConstant,r=value);assert mel.connect_material_property(n,'',prop)
        mel.recompile_material(mat);mats[role]=mat
        save(mat,dict(role=role,metallic=metal,roughness=rough,two_sided=mat.get_editor_property('two_sided'),roughness_boundary='Trial simplification: shared.86 replaces Blender Fig.83/Bellnut.88/Pepper.90' if role=='Fruit' else None,grain_normalization='Engine cube local [-50,50]cm to [0,1]; postZ/armX; UE noise differs from Blender' if role.startswith('Timber') else None))
    meshes={};sub=u.get_editor_subsystem(u.StaticMeshEditorSubsystem);w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
    for row in source['exports']:
        path=DEST+'/Meshes/'+row['name'];task=u.AssetImportTask();task.filename=str(DOC/row['file']);task.destination_path=DEST+'/Meshes';task.destination_name=row['name'];task.automated=True;task.replace_existing=False;task.save=False;task.async_=False;task.factory=u.FbxFactory()
        opts=u.FbxImportUI();opts.automated_import_should_detect_type=False;opts.import_as_skeletal=False;opts.import_mesh=True;opts.import_animations=False;opts.import_materials=False;opts.import_textures=False;opts.mesh_type_to_import=u.FBXImportType.FBXIT_STATIC_MESH
        for k,v in dict(combine_meshes=True,auto_generate_collision=False,generate_lightmap_u_vs=False,build_nanite=False,transform_vertex_to_absolute=True,reorder_material_to_fbx_order=True,import_uniform_scale=1.0,normal_import_method=u.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS,vertex_color_import_option=u.VertexColorImportOption.REPLACE).items():opts.static_mesh_import_data.set_editor_property(k,v)
        task.options=opts;flag=u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')
        try:u.SystemLibrary.execute_console_command(w,'Interchange.FeatureFlags.Import.FBX 0');tools.import_asset_tasks([task])
        finally:u.SystemLibrary.execute_console_command(w,'Interchange.FeatureFlags.Import.FBX '+('1' if flag else '0'))
        mesh=u.load_asset(path);assert isinstance(mesh,u.StaticMesh);slots=list(mesh.get_editor_property('static_materials'));assert len(slots)==1
        slots[0].set_editor_property('material_interface',mats['Bronze' if row['material_role']=='bronze' else 'Fruit']);mesh.set_editor_property('static_materials',slots);sub.remove_collisions(mesh)
        assert sub.get_simple_collision_count(mesh)==sub.get_convex_collision_count(mesh)==0
        b=mesh.get_bounds();lo=[v-e for v,e in zip(b.origin.to_tuple(),b.box_extent.to_tuple())];hi=[v+e for v,e in zip(b.origin.to_tuple(),b.box_extent.to_tuple())]
        expected_lo=[row['blender_min_metres'][0]*100,-row['blender_max_metres'][1]*100,row['blender_min_metres'][2]*100];expected_hi=[row['blender_max_metres'][0]*100,-row['blender_min_metres'][1]*100,row['blender_max_metres'][2]*100]
        assert max(abs(a-b) for aa,bb in ((lo,expected_lo),(hi,expected_hi)) for a,b in zip(aa,bb))<.2,(path,lo,hi,expected_lo,expected_hi)
        assert sub.get_num_uv_channels(mesh,0)==1
        dm=u.DynamicMesh();lod=u.GeometryScriptMeshReadLOD();lod.set_editor_property('lod_type',u.GeometryScriptLODType.RENDER_DATA);lod.set_editor_property('lod_index',0)
        copied=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh,dm,u.GeometryScriptCopyMeshFromAssetOptions(),lod);assert copied[1]==u.GeometryScriptOutcomePins.SUCCESS
        triangles=dm.get_triangle_count();assert triangles==row['triangles'],(path,triangles,row['triangles'])
        result=u.GeometryScript_VertexColors.get_mesh_per_vertex_colors(dm,False);assert result[2] is True and result[3] is False
        colors=u.GeometryScript_List.convert_color_list_to_array(result[1]);values=[c for color in colors for c in (color.r,color.g,color.b)];assert values and .001<max(values)<.99
        meshes[row['material_role'] if row['material_role']!='bronze' else 'chain' if 'Chain' in row['name'] else 'bob']=mesh
        save(mesh,dict(source_sha256=row['sha256'],render_triangles=triangles,bounds_min_cm=lo,bounds_max_cm=hi,uv_channels=1,simple_collision=0,convex_collision=0,render_vertex_colors=dict(count=len(colors),min=min(values),max=max(values))))
    cls=u.load_class(None,'/Script/Angelscript.Mars_ForagePresentation_Def');assert cls
    factory=u.DataAssetFactory();factory.set_editor_property('data_asset_class',cls);profile=tools.create_asset('DA_CP_ForagePresentation_R01',DEST,cls,factory);assert profile
    censer=profile.get_editor_property('censer');vine=profile.get_editor_property('vine')
    for k,v in dict(bob_mesh=meshes['bob'],chain_mesh=meshes['chain'],contents_mesh=meshes['pepper'],ceiling_height_cm=460.0).items():censer.set_editor_property(k,v)
    for k,v in dict(fig_mesh=meshes['fig'],bellnut_mesh=meshes['bellnut'],connector_length_cm=12.0,connector_width_cm=2.5).items():vine.set_editor_property(k,v)
    profile.set_editor_property('censer',censer);profile.set_editor_property('vine',vine);profile.set_editor_property('stone_material',u.load_asset(OLD+'/PBR_R09/Materials/M_CP_Prop_PBR_R09'))
    profile.set_editor_property('timber_post_material',mats['TimberPost']);profile.set_editor_property('timber_arm_material',mats['TimberArm'])
    save(profile,dict(censer=censer.export_text(),vine=vine.export_text(),stone_material=profile.get_editor_property('stone_material').get_path_name()))
    guard();assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    receipt.update(status='TEN_OWNED_FORAGE_ASSETS_IMPORTED_PENDING_SHADER_QUERY',guard_count=651,boundary='Owned assets only; no source/map assignments. Actual material_query compilation verdicts, native appearance and lifecycle review still required.')
    (RUN/'forage_assets_r04.json').write_text(json.dumps(receipt,indent=2)+'\n');print(receipt['status'],sha(RUN/'forage_assets_r04.json'))
