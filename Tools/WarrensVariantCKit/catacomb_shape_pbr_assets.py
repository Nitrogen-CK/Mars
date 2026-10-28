"""Fresh owned full-room material copies with new base colour, normal and roughness."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-shape-pbr-r03'
OLD='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02'
DEST=OLD+'/PBR_R08';OWNER='Mars.WarrensVariantC.Catacomb.ShapePBR.R08'
SETTINGS={'Walls':dict(normal=.8,rough=.8,mix=.55),'Floor':dict(normal=.3,rough=.75,mix=.5),
          'Ceiling':dict(normal=.18,rough=.35,mix=.15),'Prop':dict(normal=.6,rough=.65,mix=.35)}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def guard():
    g=read(RUN/'baseline_guard_r02.json');g=g['immutable_guards']|g['collision_hashes'];assert all(sha(ROOT/k)==v for k,v in g.items())
    old=read(RUN/'candidate_assets_r04.json');assert len(old['assets'])==13
    assert all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==v['package_sha256'] for p,v in old['assets'].items())
    return g,old
def create():
    import unreal as u
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    gate=read(DOC/'NATIVE_PBR_TRIAL_GATE_R08.json');assert gate['status']=='APPROVED_FOR_SINGLE_ROOM_PBR_TRIAL' and gate['tool_sha256']==sha(__file__)
    g,old=guard();mel=u.MaterialEditingLibrary;eal=u.EditorAssetLibrary;tools=u.AssetToolsHelpers.get_asset_tools()
    target_names=['Textures/T_CP_GroupedPigment_BaseColor_R08','Textures/T_CP_BroadPlanes_NormalDX_R03','Textures/T_CP_BroadPlanes_Roughness_R03']+[f'Materials/M_CP_{k}_PBR_R08' for k in SETTINGS]+['Materials/MI_CP_PropLid_PBR_R08']
    assert len(target_names)==8 and all(not eal.does_asset_exist(DEST+'/'+p) for p in target_names)
    receipt=dict(status='CREATING_EIGHT_OWNED_PBR_ASSETS',assets={},gate_sha256=sha(DOC/'NATIVE_PBR_TRIAL_GATE_R08.json'),settings=SETTINGS)
    def save(asset,details):
        eal.set_metadata_tag(asset,'Owner',OWNER);eal.set_metadata_tag(asset,'State','Complete');eal.set_metadata_tag(asset,'GateSHA256',receipt['gate_sha256'])
        assert eal.save_loaded_asset(asset,False)
        path=asset.get_path_name().split('.')[0];receipt['assets'][path]=dict(package_sha256=sha(ROOT/('Content/'+path.removeprefix('/Game/')+'.uasset')),details=details)
        (RUN/'shape_pbr_assets_r08.json').write_text(json.dumps(receipt,indent=2)+'\n')
    textures={}
    for role,filename,target in [('albedo','grouped-pigment-r08b/Stone_GroupedPigment_BaseColor_R08.png',target_names[0]),('normal','Stone_BroadPlanes_NormalDX_R03.png',target_names[1]),('rough','Stone_BroadPlanes_Roughness_R03.png',target_names[2])]:
        assert gate['texture_sha256'][filename]==sha(DOC/filename)
        task=u.AssetImportTask();task.filename=str(DOC/filename);task.destination_path=DEST+'/Textures';task.destination_name=target.rsplit('/',1)[1];task.automated=True;task.replace_existing=False;task.save=False;task.async_=False
        tools.import_asset_tasks([task]);tex=u.load_asset(DEST+'/'+target);assert isinstance(tex,u.Texture2D)
        for k,v in dict(srgb=role=='albedo',compression_settings=u.TextureCompressionSettings.TC_DEFAULT if role=='albedo' else u.TextureCompressionSettings.TC_NORMALMAP if role=='normal' else u.TextureCompressionSettings.TC_MASKS,
            address_x=u.TextureAddress.TA_WRAP,address_y=u.TextureAddress.TA_WRAP,mip_gen_settings=u.TextureMipGenSettings.TMGS_FROM_TEXTURE_GROUP).items():tex.set_editor_property(k,v)
        if role=='albedo':
            tex.set_editor_property('power_of_two_mode',u.TexturePowerOfTwoSetting.RESIZE_TO_SPECIFIC_RESOLUTION);tex.set_editor_property('resize_during_build_x',1024);tex.set_editor_property('resize_during_build_y',1024)
        if role=='normal':tex.set_editor_property('flip_green_channel',False)
        textures[role]=tex;save(tex,dict(role=role,source_file=filename,source_sha256=sha(DOC/filename),srgb=tex.get_editor_property('srgb'),compression=str(tex.get_editor_property('compression_settings')),normal_convention='DirectX -Y already baked; no second green flip' if role=='normal' else None))
    def expr(mat,cls,**props):
        n=mel.create_material_expression(mat,cls,0,0);assert n
        for k,v in props.items():n.set_editor_property(k,v)
        return n
    def link(a,out,b,pin):
        if pin in ('VectorInput','Input'):
            actual=list(mel.get_material_expression_input_names(b));assert len(actual)==1;pin=str(actual[0])
        assert mel.connect_material_expressions(a,out,b,pin),(a.get_name(),out,b.get_name(),pin)
    def scalar(mat,value):return expr(mat,u.MaterialExpressionConstant,r=value)
    for family,s in SETTINGS.items():
        source=OLD+'/Materials/M_CP_'+family+'_R02';target=DEST+'/Materials/M_CP_'+family+'_PBR_R08'
        mat=eal.duplicate_asset(source,target);assert isinstance(mat,u.Material)
        nodes=[n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==mat]
        pigment,=[n for n in nodes if isinstance(n,(u.MaterialExpressionTextureObject,u.MaterialExpressionTextureSample)) and n.get_editor_property('texture') and n.get_editor_property('texture').get_path_name().split('.')[0]==OLD+'/Textures/T_CP_AngularPigment_R02']
        pigment.set_editor_property('texture',textures['albedo'])
        original_blend,=[n for n in nodes if isinstance(n,u.MaterialExpressionLinearInterpolate)]
        # Only pigment-mix constant is replaced; source base colours, vertex tones and projection remain.
        mix=scalar(mat,s['mix']);link(mix,'',original_blend,'Alpha')
        uv=next((n for n in nodes if isinstance(n,u.MaterialExpressionTextureCoordinate)),None)
        normal=expr(mat,u.MaterialExpressionTextureSample,texture=textures['normal'],sampler_type=u.MaterialSamplerType.SAMPLERTYPE_NORMAL)
        if uv:link(uv,'',normal,'UVs')
        flat=expr(mat,u.MaterialExpressionConstant3Vector,constant=u.LinearColor(0,0,1,1))
        amount=expr(mat,u.MaterialExpressionScalarParameter,parameter_name='NormalStrength',default_value=s['normal'])
        lerp=expr(mat,u.MaterialExpressionLinearInterpolate);link(flat,'',lerp,'A');link(normal,'RGB',lerp,'B');link(amount,'',lerp,'Alpha')
        norm=expr(mat,u.MaterialExpressionNormalize);link(lerp,'',norm,'VectorInput')
        if mat.get_editor_property('tangent_space_normal'):
            normal_output=norm
        else:
            base=mel.get_material_property_input_node(mat,u.MaterialProperty.MP_NORMAL);assert base is not None and family in ('Floor','Ceiling')
            xy=expr(mat,u.MaterialExpressionMultiply);link(norm,'',xy,'A');link(expr(mat,u.MaterialExpressionConstant3Vector,constant=u.LinearColor(1,1,0,1)),'',xy,'B')
            transform=expr(mat,u.MaterialExpressionTransform,transform_source_type=u.MaterialVectorCoordTransformSource.TRANSFORMSOURCE_TANGENT,transform_type=u.MaterialVectorCoordTransform.TRANSFORM_WORLD);link(xy,'',transform,'Input')
            z=expr(mat,u.MaterialExpressionComponentMask,r=False,g=False,b=True,a=False);link(norm,'',z,'None')
            nz=expr(mat,u.MaterialExpressionMultiply);link(base,'',nz,'A');link(z,'',nz,'B')
            add=expr(mat,u.MaterialExpressionAdd);link(nz,'',add,'A');link(transform,'',add,'B')
            normal_output=expr(mat,u.MaterialExpressionNormalize);link(add,'',normal_output,'VectorInput')
        assert mel.connect_material_property(normal_output,'',u.MaterialProperty.MP_NORMAL)
        oldrough=mel.get_material_property_input_node(mat,u.MaterialProperty.MP_ROUGHNESS);assert oldrough is not None
        if family=='Prop':
            custom,=[n for n in nodes if isinstance(n,u.MaterialExpressionCustom)]
            inputs=dict(zip(map(str,mel.get_material_expression_input_names(custom)),mel.get_inputs_for_material_expression(mat,custom)))
            roughtex=expr(mat,u.MaterialExpressionTextureObject,texture=textures['rough'],sampler_type=u.MaterialSamplerType.SAMPLERTYPE_MASKS)
            rough=expr(mat,u.MaterialExpressionCustom,code=custom.get_editor_property('code'),output_type=u.CustomMaterialOutputType.CMOT_FLOAT3,description='Independent roughness, same source-local65cm triplanar projection')
            pins=[]
            for name in ('Pos','Normal','Origin','PigmentTex'):
                p=u.CustomInput();p.set_editor_property('input_name',name);pins.append(p)
            rough.set_editor_property('inputs',pins)
            for name in inputs:link(roughtex if name=='PigmentTex' else inputs[name],'',rough,name)
            rough_output=''
        else:
            rough=expr(mat,u.MaterialExpressionTextureSample,texture=textures['rough'],sampler_type=u.MaterialSamplerType.SAMPLERTYPE_MASKS)
            if uv:link(uv,'',rough,'UVs')
            rough_output='R'
        roughmix=expr(mat,u.MaterialExpressionScalarParameter,parameter_name='RoughnessBlend',default_value=s['rough'])
        rb=expr(mat,u.MaterialExpressionLinearInterpolate);link(oldrough,'',rb,'A');link(rough,rough_output,rb,'B');link(roughmix,'',rb,'Alpha')
        assert mel.connect_material_property(rb,'',u.MaterialProperty.MP_ROUGHNESS)
        mel.recompile_material(mat);stats=mel.get_statistics(mat);assert stats.num_pixel_shader_instructions>0
        save(mat,dict(family=family,source=source,source_package_sha256=old['assets'][source]['package_sha256'],pixel_instructions=stats.num_pixel_shader_instructions,vertex_instructions=stats.num_vertex_shader_instructions,
            tangent_space_normal=mat.get_editor_property('tangent_space_normal'),normal_strength=s['normal'],roughness_blend=s['rough'],pigment_mix=s['mix'],
            normal_output=normal_output.get_name(),roughness_output=rb.get_name(),policy='NormalDX on original UV0 for tomb; physical PigmentUV for envelope. Planar floor/ceiling baseline retained plus tangent-XY perturbation, then normalized.'))
    lid=tools.create_asset('MI_CP_PropLid_PBR_R08',DEST+'/Materials',u.MaterialInstanceConstant,u.MaterialInstanceConstantFactoryNew());assert lid
    mel.set_material_instance_parent(lid,u.load_asset(DEST+'/Materials/M_CP_Prop_PBR_R08'));mel.set_material_instance_vector_parameter_value(lid,'PropOriginB',u.LinearColor(-72.65,-25,0,1))
    save(lid,dict(parent=DEST+'/Materials/M_CP_Prop_PBR_R08',PropOriginB=[-72.65,-25,0,1]))
    guard();assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    assert len(receipt['assets'])==8;receipt['status']='EIGHT_OWNED_SHAPE_PBR_ASSETS_CREATED_AND_READ_BACK';receipt['guard_count']=len(g)
    (RUN/'shape_pbr_assets_r08.json').write_text(json.dumps(receipt,indent=2)+'\n')
    candidate=dict(old);candidate['assets']=dict(old['assets'])|receipt['assets'];candidate.update(status='TWENTYONE_OWNED_NATIVE_PILOT_ASSETS_CREATED_AND_READ_BACK',pbr_gate_sha256=sha(DOC/'NATIVE_PBR_TRIAL_GATE_R08.json'))
    out=RUN/'candidate_assets_r08.json';assert not out.exists();out.write_text(json.dumps(candidate,indent=2)+'\n')
    print('EIGHT_SHAPE_PBR_ASSETS_READY',sha(RUN/'shape_pbr_assets_r08.json'),'ALL21',sha(out))
