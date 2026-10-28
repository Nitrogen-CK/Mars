"""Checkpointed creation of fresh, finite Catacomb review assets; no map writes."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DEST='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02'
OWNER='Mars.WarrensVariantC.CatacombPilot.R02'
SETTINGS={'walls':(.85,(.18,.16,.12),.88),'floor':(.70,(.20,.17,.12),.88),'ceiling':(.25,(.14,.125,.10),.92),'prop':(.45,(.20,.18,.14),.88),'mortar':(0,(.12,.105,.08),.90)}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def path(kind,name):return DEST+'/'+kind+'/'+name
TEXTURE=path('Textures','T_CP_AngularPigment_R02')
MATERIALS={k:path('Materials','M_CP_'+k.capitalize()+'_R02') for k in SETTINGS}
LID=path('Materials','MI_CP_PropLid_R02')
ACTIVE_PREFLIGHT=RUN/'assets_preflight_resume_r04.json'
def _u():import unreal;return unreal
def _gate():
    gate=read(DOC/'NATIVE_TRIAL_GATE.json');export=read(DOC/'export-r03/audit_export.json');tri=read(DOC/'export-r03/fbx_triangle_support.json')
    assert gate['status']=='APPROVED_FOR_SINGLE_ROOM_NATIVE_TRIAL' and gate['owned_destination']==DEST
    assert gate['export_receipt_sha256']==sha(DOC/'export-r03/audit_export.json')
    assert gate['triangle_support_sha256']==sha(DOC/'export-r03/fbx_triangle_support.json') and tri['status']=='ACTUAL_FBX_TRIANGLE_SUPPORT_PASS'
    assert {r['name']:r['sha256'] for r in gate['allowed_meshes']}=={r['name']:r['sha256'] for r in export['exports']}
    assert all(sha(ROOT/r['file'])==r['sha256'] for r in export['exports'])
    assert sha(DOC/'Stone_AngularPigment_Albedo_r02.png')==gate['image_sha256']
    return gate,export,tri
def _clean_maps():
    u=_u();assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==[]
def _guard():
    r=read(RUN/'baseline_guard_r02.json');g=r['immutable_guards']|r['collision_hashes'];assert all(sha(ROOT/k)==v for k,v in g.items());return g
def _record(asset,details):
    u=_u();assert asset.get_path_name().split('.')[0].startswith(DEST+'/')
    u.EditorAssetLibrary.set_metadata_tag(asset,'Owner',OWNER);u.EditorAssetLibrary.set_metadata_tag(asset,'State','Complete')
    u.EditorAssetLibrary.set_metadata_tag(asset,'PilotGateSHA256',sha(DOC/'NATIVE_TRIAL_GATE.json'))
    assert u.EditorAssetLibrary.save_loaded_asset(asset,False)
    package=asset.get_path_name().split('.')[0];disk=ROOT/('Content/'+package.removeprefix('/Game/')+'.uasset')
    f=RUN/'assets_created_r02.json';r=read(f) if f.exists() else dict(status='CREATING_OWNED_PILOT_ASSETS',assets={})
    r['assets'][package]=dict(package_sha256=sha(disk),details=details);f.write_text(json.dumps(r,indent=2)+'\n')
    print('PILOT_ASSET_SAVED',package,flush=True)
def preflight():
    u=_u();_clean_maps();gate,exp,tri=_gate();g=_guard()
    names=[TEXTURE,*MATERIALS.values(),LID]+[path('Meshes',r['name']) for r in exp['exports']]
    assert len(names)==10 and all(not u.EditorAssetLibrary.does_asset_exist(p) for p in names)
    assert u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    r=dict(status='READ_ONLY_FRESH_PILOT_ASSETS_PREFLIGHT',targets=names,guards=g,gate_sha256=sha(DOC/'NATIVE_TRIAL_GATE.json'),tool_sha256=sha(__file__))
    out=RUN/'assets_preflight_r02.json';assert not out.exists();out.write_text(json.dumps(r,indent=2)+'\n');print('PILOT_ASSET_PREFLIGHT',sha(out));return r['status']
def _ready():
    _clean_maps();_gate();r=read(ACTIVE_PREFLIGHT);assert r['tool_sha256']==sha(__file__)
    assert r['gate_sha256']==sha(DOC/'NATIVE_TRIAL_GATE.json');_guard()
def resume_preflight():
    u=_u();_clean_maps();_gate();g=_guard();prior=read(RUN/'assets_preflight_r02.json')
    assert sha(RUN/'catacomb_pilot_assets_preflight_r02.py')==prior['tool_sha256']
    saved=read(RUN/'assets_created_r02.json');assert set(saved['assets'])=={TEXTURE}
    tex=u.load_asset(TEXTURE);mat=u.load_asset(MATERIALS['walls']);assert tex and mat
    assert u.EditorAssetLibrary.get_metadata_tag(tex,'State')=='Complete'
    assert u.EditorAssetLibrary.get_metadata_tag(mat,'Owner')==OWNER and u.EditorAssetLibrary.get_metadata_tag(mat,'State')==''
    assert not (ROOT/('Content/'+MATERIALS['walls'].removeprefix('/Game/')+'.uasset')).exists()
    assert [p.get_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()]==[MATERIALS['walls']]
    assert not ACTIVE_PREFLIGHT.exists()
    ACTIVE_PREFLIGHT.write_text(json.dumps(dict(status='OWNED_PARTIAL_MATERIAL_RESUME_ADMITTED',tool_sha256=sha(__file__),gate_sha256=sha(DOC/'NATIVE_TRIAL_GATE.json'),
        prior_preflight_sha256=sha(RUN/'assets_preflight_r02.json'),guards=g,
        correction='Live graph pin readback: TextureSample UVs; ComponentMask None; Multiply A/B; Lerp A/B/Alpha. Two rejected named links are diagnosed; rebuild only the unsaved owned incomplete wall graph. Saved texture stays exact.'),indent=2)+'\n')
    return 'OWNED_PARTIAL_MATERIAL_RESUME_ADMITTED'
def create_texture():
    u=_u();_ready();assert not u.EditorAssetLibrary.does_asset_exist(TEXTURE)
    task=u.AssetImportTask();task.filename=str(DOC/'Stone_AngularPigment_Albedo_r02.png');task.destination_path=DEST+'/Textures';task.destination_name=TEXTURE.rsplit('/',1)[1]
    task.automated=True;task.replace_existing=False;task.save=False;task.async_=False
    u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task]);tex=u.load_asset(TEXTURE);assert isinstance(tex,u.Texture2D)
    for k,v in dict(srgb=True,compression_settings=u.TextureCompressionSettings.TC_DEFAULT,address_x=u.TextureAddress.TA_WRAP,address_y=u.TextureAddress.TA_WRAP,
        power_of_two_mode=u.TexturePowerOfTwoSetting.RESIZE_TO_SPECIFIC_RESOLUTION,resize_during_build_x=1024,resize_during_build_y=1024,mip_gen_settings=u.TextureMipGenSettings.TMGS_FROM_TEXTURE_GROUP).items():tex.set_editor_property(k,v)
    _record(tex,dict(source_sha256=sha(DOC/'Stone_AngularPigment_Albedo_r02.png'),srgb=tex.get_editor_property('srgb'),wrap_x=str(tex.get_editor_property('address_x')),wrap_y=str(tex.get_editor_property('address_y')),resize=[1024,1024],physical_maps='None generated from color'))
    _guard();return TEXTURE
def create_materials():
    u=_u();_ready();tex=u.load_asset(TEXTURE);assert tex;tools=u.AssetToolsHelpers.get_asset_tools();mel=u.MaterialEditingLibrary
    def expr(mat,cls,**props):
        e=mel.create_material_expression(mat,cls,0,0);assert e
        for k,v in props.items():e.set_editor_property(k,v)
        return e
    def link(a,out,b,pin):assert mel.connect_material_expressions(a,out,b,pin),(a.get_class().get_name(),out,b.get_class().get_name(),pin)
    def scalar(mat,value):return expr(mat,u.MaterialExpressionConstant,r=value)
    for kind,target in MATERIALS.items():
        if u.EditorAssetLibrary.does_asset_exist(target):
            mat=u.load_asset(target);assert kind=='walls' and u.EditorAssetLibrary.get_metadata_tag(mat,'Owner')==OWNER and u.EditorAssetLibrary.get_metadata_tag(mat,'State')==''
            mel.delete_all_material_expressions(mat)
        else:mat=tools.create_asset(target.rsplit('/',1)[1],DEST+'/Materials',u.Material,u.MaterialFactoryNew())
        assert mat
        u.EditorAssetLibrary.set_metadata_tag(mat,'Owner',OWNER)
        mix,base,roughness=SETTINGS[kind];base_node=expr(mat,u.MaterialExpressionConstant3Vector,constant=u.LinearColor(*base,1))
        if kind=='mortar':output=base_node
        else:
            if kind=='prop':
                texobj=expr(mat,u.MaterialExpressionTextureObject,texture=tex)
                pos=expr(mat,u.MaterialExpressionPreSkinnedPosition);normal=expr(mat,u.MaterialExpressionPreSkinnedNormal)
                origin=expr(mat,u.MaterialExpressionVectorParameter,parameter_name='PropOriginB',default_value=u.LinearColor(-76,-25,0,1))
                cu=expr(mat,u.MaterialExpressionCustom,output_type=u.CustomMaterialOutputType.CMOT_FLOAT3,
                    description='Stable authored prop triplanar pigment, physical65cm scale',
                    code='float3 P=(float3(Pos.x,-Pos.y,Pos.z)*0.01+Origin.xyz)/0.65; float3 N=pow(abs(float3(Normal.x,-Normal.y,Normal.z)),8); N/=max(dot(N,float3(1,1,1)),0.0001); return Texture2DSample(PigmentTex,PigmentTexSampler,P.yz).rgb*N.x+Texture2DSample(PigmentTex,PigmentTexSampler,P.xz).rgb*N.y+Texture2DSample(PigmentTex,PigmentTexSampler,P.xy).rgb*N.z;')
                pins=[]
                for name in ('Pos','Normal','Origin','PigmentTex'):
                    ci=u.CustomInput();ci.set_editor_property('input_name',name);pins.append(ci)
                cu.set_editor_property('inputs',pins)
                for n,src in [('Pos',pos),('Normal',normal),('Origin',origin),('PigmentTex',texobj)]:link(src,'',cu,n)
                pigment=cu
            else:
                pigment=expr(mat,u.MaterialExpressionTextureSample,texture=tex,sampler_type=u.MaterialSamplerType.SAMPLERTYPE_COLOR)
                uv=expr(mat,u.MaterialExpressionTextureCoordinate,coordinate_index=0);link(uv,'',pigment,'UVs')
            blend=expr(mat,u.MaterialExpressionLinearInterpolate);link(base_node,'',blend,'A');link(pigment,'RGB' if kind!='prop' else '',blend,'B');link(scalar(mat,mix),'',blend,'Alpha')
            mul=expr(mat,u.MaterialExpressionMultiply);link(blend,'',mul,'A')
            if kind=='prop':vc=expr(mat,u.MaterialExpressionConstant3Vector,constant=u.LinearColor(.95,.92,.86,1));link(vc,'',mul,'B');output=mul
            else:
                vc=expr(mat,u.MaterialExpressionVertexColor);mask=expr(mat,u.MaterialExpressionComponentMask,r=True,g=True,b=True,a=False);link(vc,'',mask,'None');link(mask,'',mul,'B')
                output=expr(mat,u.MaterialExpressionMultiply);link(mul,'',output,'A');link(scalar(mat,1.2),'',output,'B')
        assert mel.connect_material_property(output,'',u.MaterialProperty.MP_BASE_COLOR)
        assert mel.connect_material_property(scalar(mat,roughness),'',u.MaterialProperty.MP_ROUGHNESS)
        assert mel.connect_material_property(scalar(mat,0),'',u.MaterialProperty.MP_METALLIC)
        mel.set_material_usage(mat,u.MaterialUsage.MATUSAGE_INSTANCED_STATIC_MESHES)
        mel.recompile_material(mat)
        stats=mel.get_statistics(mat)
        assert stats.num_pixel_shader_instructions>0,(kind,'No compiled pixel shader statistics')
        _record(mat,dict(kind=kind,mix=mix,base=list(base),roughness=roughness,normal='geometry only; disconnected',vertex_color_gain=1.2 if kind not in ('prop','mortar') else None,
            pigment_projection='UV0 with physical family scale and per-stone phase' if kind not in ('prop','mortar') else 'source-local triplanar65cm' if kind=='prop' else 'constant mortar',
            compiled_shader_stats=dict(pixel_instructions=stats.num_pixel_shader_instructions,vertex_instructions=stats.num_vertex_shader_instructions)))
    assert not u.EditorAssetLibrary.does_asset_exist(LID)
    mi=tools.create_asset(LID.rsplit('/',1)[1],DEST+'/Materials',u.MaterialInstanceConstant,u.MaterialInstanceConstantFactoryNew());assert mi
    mel.set_material_instance_parent(mi,u.load_asset(MATERIALS['prop']));mel.set_material_instance_vector_parameter_value(mi,'PropOriginB',u.LinearColor(-72.65,-25,0,1))
    _record(mi,dict(parent=MATERIALS['prop'],PropOriginB=[-72.65,-25,0,1]));_guard();return MATERIALS
def import_mesh(kind):
    u=_u();_ready();gate,export,tri=_gate();row=next(r for r in export['exports'] if r['kind']==kind);target=path('Meshes',row['name']);assert not u.EditorAssetLibrary.does_asset_exist(target)
    task=u.AssetImportTask();task.filename=str(ROOT/row['file']);task.destination_path=DEST+'/Meshes';task.destination_name=row['name'];task.automated=True;task.replace_existing=False;task.save=False;task.async_=False;task.factory=u.FbxFactory()
    opts=u.FbxImportUI();opts.automated_import_should_detect_type=False;opts.import_as_skeletal=False;opts.import_mesh=True;opts.import_animations=False;opts.import_materials=False;opts.import_textures=False;opts.mesh_type_to_import=u.FBXImportType.FBXIT_STATIC_MESH
    for k,v in dict(combine_meshes=True,auto_generate_collision=False,generate_lightmap_u_vs=False,build_nanite=False,transform_vertex_to_absolute=True,reorder_material_to_fbx_order=True,import_uniform_scale=1.0,
        normal_import_method=u.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS,vertex_color_import_option=u.VertexColorImportOption.REPLACE).items():opts.static_mesh_import_data.set_editor_property(k,v)
    task.options=opts;w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world();flag=u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')
    try:
        u.SystemLibrary.execute_console_command(w,'Interchange.FeatureFlags.Import.FBX 0');u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    finally:u.SystemLibrary.execute_console_command(w,'Interchange.FeatureFlags.Import.FBX '+('1' if flag else '0'))
    mesh=u.load_asset(target);assert isinstance(mesh,u.StaticMesh)
    slots=list(mesh.get_editor_property('static_materials'));assigned=[]
    for slot in slots:
        name=str(slot.get_editor_property('imported_material_slot_name'));assert name in row['source_material'],(name,row['source_material'])
        role=row['source_material'][name];slot.set_editor_property('material_interface',u.load_asset(MATERIALS[role]));assigned.append(dict(imported=name,role=role,material=MATERIALS[role]))
    assert len(slots)==2;mesh.set_editor_property('static_materials',slots)
    subsystem=u.get_editor_subsystem(u.StaticMeshEditorSubsystem);subsystem.remove_collisions(mesh)
    assert subsystem.get_simple_collision_count(mesh)==subsystem.get_convex_collision_count(mesh)==0
    bounds=mesh.get_bounds();actual_min=[v-e for v,e in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())];actual_max=[v+e for v,e in zip(bounds.origin.to_tuple(),bounds.box_extent.to_tuple())]
    assert max(abs(a-b) for aa,bb in ((actual_min,row['unreal_bounds_min_cm']),(actual_max,row['unreal_bounds_max_cm'])) for a,b in zip(aa,bb))<.2,(kind,actual_min,actual_max)
    assert subsystem.get_num_uv_channels(mesh,0)>=1
    dm=u.DynamicMesh();lod=u.GeometryScriptMeshReadLOD();lod.set_editor_property('lod_type',u.GeometryScriptLODType.RENDER_DATA);lod.set_editor_property('lod_index',0)
    copied=u.GeometryScript_AssetUtils.copy_mesh_from_static_mesh(mesh,dm,u.GeometryScriptCopyMeshFromAssetOptions(),lod)
    assert copied[1]==u.GeometryScriptOutcomePins.SUCCESS,copied[1]
    result=u.GeometryScript_VertexColors.get_mesh_per_vertex_colors(dm,False);assert result[2] is True and result[3] is False
    colors=u.GeometryScript_List.convert_color_list_to_array(result[1]);assert len(colors)>100
    channels=[[c.r,c.g,c.b] for c in colors];maximum=max(max(c) for c in channels);nonzero=[c for c in channels if max(c)>.001]
    assert nonzero and maximum<1 and maximum>.65,(kind,maximum)
    expected_color=next(r for r in tri['results'] if r['kind']==kind)['color_attribute']
    assert abs(maximum-expected_color['maximum'])<.012,(kind,maximum,expected_color)
    _record(mesh,dict(source_sha256=row['sha256'],bounds_min_cm=actual_min,bounds_max_cm=actual_max,uv_channels=subsystem.get_num_uv_channels(mesh,0),slots=assigned,
        simple_collision=0,convex_collision=0,vertex_color_import=str(mesh.get_editor_property('asset_import_data').get_editor_property('vertex_color_import_option')),
        actual_render_vertex_colors=dict(count=len(colors),min=min(min(c) for c in channels),max=maximum,source_expected_max=expected_color['maximum'],gain=1.2,proof='Actual StaticMesh RENDER_DATA copied read-only to transient DynamicMesh; extracted native vertex colors.')))
    _guard();return target
def finish():
    u=_u();_ready();r=read(RUN/'assets_created_r02.json');assert len(r['assets'])==10
    assert u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    for p,v in r['assets'].items():assert sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==v['package_sha256']
    r.update(status='TEN_OWNED_NATIVE_PILOT_ASSETS_CREATED_AND_READ_BACK',gate_sha256=sha(DOC/'NATIVE_TRIAL_GATE.json'),tool_sha256=sha(__file__),guard_count=len(_guard()),boundary='New owned review assets only; no map, original mesh/material or source collision file changed. Actual native view still required.')
    (RUN/'assets_created_r02.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'],sha(RUN/'assets_created_r02.json'));return r['status']
