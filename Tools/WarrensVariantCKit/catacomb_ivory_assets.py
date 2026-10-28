"""Create one owned painterly-ivory parent and two prop instances; never edits source maps."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
DEST='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02'
OWNER='Mars.WarrensVariantC.CatacombPilot.R02'
PARENT=DEST+'/Materials/M_CP_Ivory_R01'
INSTANCES={'bone':DEST+'/Materials/MI_CP_Bone_R01','urn':DEST+'/Materials/MI_CP_Urn_R01'}
SETTINGS={'bone':dict(base=[.36,.32,.24],roughness=.93,repeat=.65,strength=.55),
          'urn':dict(base=[.30,.265,.20],roughness=.84,repeat=.65,strength=.55)}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def guard():
    g=read(RUN/'baseline_guard_r02.json');g=g['immutable_guards']|g['collision_hashes']
    assert all(sha(ROOT/k)==v for k,v in g.items())
    old=read(RUN/'candidate_assets_r03.json')
    assert all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==r['package_sha256'] for p,r in old['assets'].items())
    return g,old
def create():
    import unreal as u
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    gate=read(DOC/'IVORY_PROP_TRIAL_GATE_R01.json')
    assert gate['status']=='APPROVED_FOR_TWO_PROP_OWNED_IVORY_TRIAL'
    assert gate['tool_sha256']==sha(__file__)
    guards,old=guard();eal=u.EditorAssetLibrary;mel=u.MaterialEditingLibrary;tools=u.AssetToolsHelpers.get_asset_tools()
    targets=[PARENT,*INSTANCES.values()];assert all(not eal.does_asset_exist(p) for p in targets)
    pre=dict(status='THREE_FRESH_OWNED_IVORY_ASSETS_PREFLIGHT',targets=targets,guards=guards,tool_sha256=sha(__file__),gate_sha256=sha(DOC/'IVORY_PROP_TRIAL_GATE_R01.json'))
    out=RUN/'ivory_assets_preflight_r01.json';assert not out.exists();out.write_text(json.dumps(pre,indent=2)+'\n')
    def expr(mat,cls,**props):
        n=mel.create_material_expression(mat,cls,0,0);assert n
        for k,v in props.items():n.set_editor_property(k,v)
        return n
    def link(a,out,b,pin):assert mel.connect_material_expressions(a,out,b,pin),(a.get_name(),out,b.get_name(),pin)
    mat=tools.create_asset(PARENT.rsplit('/',1)[1],DEST+'/Materials',u.Material,u.MaterialFactoryNew());assert mat
    eal.set_metadata_tag(mat,'Owner',OWNER)
    tex=expr(mat,u.MaterialExpressionTextureObject,texture=u.load_asset(DEST+'/Textures/T_CP_AngularPigment_R02'))
    bases=expr(mat,u.MaterialExpressionVectorParameter,parameter_name='IvoryBase',default_value=u.LinearColor(*SETTINGS['bone']['base'],1))
    strength=expr(mat,u.MaterialExpressionScalarParameter,parameter_name='PigmentStrength',default_value=.55)
    repeat=expr(mat,u.MaterialExpressionScalarParameter,parameter_name='RepeatMetres',default_value=.65)
    rough=expr(mat,u.MaterialExpressionScalarParameter,parameter_name='Roughness',default_value=.93)
    custom=expr(mat,u.MaterialExpressionCustom,output_type=u.CustomMaterialOutputType.CMOT_FLOAT3,
        description='Ivory hue with bounded angular pigment value; no color-derived normals or roughness',
        code='float3 P=Pos*0.01/max(RepeatMetres,0.01); float3 N=pow(abs(Normal),8); N/=max(dot(N,float3(1,1,1)),0.0001); float3 c=Texture2DSample(PigmentTex,PigmentTexSampler,P.yz).rgb*N.x+Texture2DSample(PigmentTex,PigmentTexSampler,P.xz).rgb*N.y+Texture2DSample(PigmentTex,PigmentTexSampler,P.xy).rgb*N.z; float value=clamp(dot(c,float3(0.2126,0.7152,0.0722))/0.18,0.5,1.5); return Base.xyz*lerp(1.0,value,Strength);')
    pins=[]
    for name in ('Pos','Normal','PigmentTex','Base','RepeatMetres','Strength'):
        i=u.CustomInput();i.set_editor_property('input_name',name);pins.append(i)
    custom.set_editor_property('inputs',pins)
    for cls,pin in ((u.MaterialExpressionPreSkinnedPosition,'Pos'),(u.MaterialExpressionPreSkinnedNormal,'Normal')):
        n=expr(mat,cls);v=expr(mat,u.MaterialExpressionVertexInterpolator)
        names=list(mel.get_material_expression_input_names(v));assert len(names)==1
        link(n,'',v,names[0]);link(v,'',custom,pin)
    for source,pin in ((tex,'PigmentTex'),(bases,'Base'),(repeat,'RepeatMetres'),(strength,'Strength')):link(source,'',custom,pin)
    normal=expr(mat,u.MaterialExpressionTextureSample,texture=u.load_asset('/Game/Mars/Environment/ChainCrossingKit/Textures/T_CCK_TX06_BoneIvory_NormalDX'),sampler_type=u.MaterialSamplerType.SAMPLERTYPE_NORMAL)
    for n,p in ((custom,u.MaterialProperty.MP_BASE_COLOR),(rough,u.MaterialProperty.MP_ROUGHNESS),(normal,u.MaterialProperty.MP_NORMAL)):
        assert mel.connect_material_property(n,'',p)
    zero=expr(mat,u.MaterialExpressionConstant,r=0)
    assert mel.connect_material_property(zero,'',u.MaterialProperty.MP_METALLIC)
    mel.set_material_usage(mat,u.MaterialUsage.MATUSAGE_INSTANCED_STATIC_MESHES);mel.recompile_material(mat)
    stats=mel.get_statistics(mat);assert stats.num_pixel_shader_instructions>0
    receipt=dict(status='CREATING_THREE_OWNED_IVORY_ASSETS',assets={},settings=SETTINGS,gate_sha256=sha(DOC/'IVORY_PROP_TRIAL_GATE_R01.json'))
    def save(asset,details):
        eal.set_metadata_tag(asset,'Owner',OWNER);eal.set_metadata_tag(asset,'State','Complete')
        eal.set_metadata_tag(asset,'IvoryGateSHA256',sha(DOC/'IVORY_PROP_TRIAL_GATE_R01.json'))
        assert eal.save_loaded_asset(asset,False)
        p=asset.get_path_name().split('.')[0];receipt['assets'][p]=dict(package_sha256=sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset')),details=details)
        (RUN/'ivory_assets_created_r01.json').write_text(json.dumps(receipt,indent=2)+'\n')
    save(mat,dict(pixel_instructions=stats.num_pixel_shader_instructions,vertex_instructions=stats.num_vertex_shader_instructions,
        normal='Existing TX06 NormalDX, original UV0 and geometric tangent basis',roughness='Independent scalar; no color-derived physical maps',pigment='Existing angular pigment, luminance only, local triplanar; bounded gain .725..1.275 at strength .55'))
    for kind,p in INSTANCES.items():
        mi=tools.create_asset(p.rsplit('/',1)[1],DEST+'/Materials',u.MaterialInstanceConstant,u.MaterialInstanceConstantFactoryNew());assert mi
        mel.set_material_instance_parent(mi,mat);s=SETTINGS[kind]
        mel.set_material_instance_vector_parameter_value(mi,'IvoryBase',u.LinearColor(*s['base'],1))
        for n,k in (('Roughness','roughness'),('RepeatMetres','repeat'),('PigmentStrength','strength')):
            mel.set_material_instance_scalar_parameter_value(mi,n,s[k]);assert abs(mel.get_material_instance_scalar_parameter_value(mi,n)-s[k])<.00001
        assert max(abs(a-b) for a,b in zip(mel.get_material_instance_vector_parameter_value(mi,'IvoryBase').to_tuple()[:3],s['base']))<.00001
        save(mi,dict(parent=PARENT,**s))
    guard();assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    receipt['status']='THREE_OWNED_IVORY_ASSETS_CREATED_AND_READ_BACK';receipt['guard_count']=len(guards)
    (RUN/'ivory_assets_created_r01.json').write_text(json.dumps(receipt,indent=2)+'\n')
    candidate=dict(old);candidate['assets']=dict(old['assets'])|receipt['assets']
    candidate.update(status='THIRTEEN_OWNED_NATIVE_PILOT_ASSETS_CREATED_AND_READ_BACK',ivory_gate_sha256=sha(DOC/'IVORY_PROP_TRIAL_GATE_R01.json'),ivory_assets_receipt_sha256=sha(RUN/'ivory_assets_created_r01.json'))
    out=RUN/'candidate_assets_r04.json';assert not out.exists();out.write_text(json.dumps(candidate,indent=2)+'\n')
    print('OWNED_IVORY_CREATED',sha(RUN/'ivory_assets_created_r01.json'),'CANDIDATE',sha(out))
