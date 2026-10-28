"""Reusable unsaved world-scale painterly graph for nonuniform static parts.

Pure builder: the caller owns a NEW transient Material and its lifecycle/gate.
Uses existing independently baked normal/roughness; never derives relief from
albedo. TextureSample normal samplers perform the engine's normal decoding.
"""
ROOT_ASSET='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02'
TEXTURES=dict(albedo=ROOT_ASSET+'/Textures/T_CP_AngularPigment_R02',normal=ROOT_ASSET+'/PBR_R08/Textures/T_CP_BroadPlanes_NormalDX_R03',rough=ROOT_ASSET+'/PBR_R08/Textures/T_CP_BroadPlanes_Roughness_R03')

def build(mat):
    import unreal as u
    assert isinstance(mat,u.Material) and mat.get_outer().get_path_name()=='/Engine/Transient'
    mel=u.MaterialEditingLibrary;assert not [n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==mat]
    mat.set_editor_property('blend_mode',u.BlendMode.BLEND_OPAQUE);mat.set_editor_property('shading_model',u.MaterialShadingModel.MSM_DEFAULT_LIT);mat.set_editor_property('two_sided',False);mat.set_editor_property('tangent_space_normal',False);mat.set_editor_property('used_with_instanced_static_meshes',True)
    def expr(cls,**props):
        n=mel.create_material_expression(mat,cls,0,0);assert n
        for k,v in props.items():n.set_editor_property(k,v)
        return n
    def link(a,out,b,pin):assert mel.connect_material_expressions(a,out,b,pin)
    def custom(code,kind,inputs,label):
        n=expr(u.MaterialExpressionCustom,code=code,output_type=kind,description=label);pins=[]
        for name in inputs:
            p=u.CustomInput();p.set_editor_property('input_name',name);pins.append(p)
        n.set_editor_property('inputs',pins)
        for name,(src,out) in inputs.items():link(src,out,n,name)
        return n
    def scalar(name,value):return expr(u.MaterialExpressionScalarParameter,parameter_name=name,default_value=value)
    textures={k:u.load_asset(v) for k,v in TEXTURES.items()};assert all(isinstance(v,u.Texture2D) for v in textures.values())
    for k,t in textures.items():
        assert t.get_editor_property('srgb')==(k=='albedo') and t.get_editor_property('address_x')==u.TextureAddress.TA_WRAP and t.get_editor_property('address_y')==u.TextureAddress.TA_WRAP
    assert textures['normal'].get_editor_property('compression_settings')==u.TextureCompressionSettings.TC_NORMALMAP
    pos=expr(u.MaterialExpressionWorldPosition,world_position_shader_offset=u.WorldPositionIncludedOffsets.WPT_EXCLUDE_ALL_SHADER_OFFSETS)
    normal=expr(u.MaterialExpressionVertexNormalWS);ni=expr(u.MaterialExpressionVertexInterpolator);pin,=mel.get_material_expression_input_names(ni);link(normal,'',ni,str(pin))
    tile=scalar('WorldTileCm',180);amount=scalar('NormalStrength',.6);roughmix=scalar('RoughnessBlend',.65);pigmentmix=scalar('PigmentMix',.45)
    base=expr(u.MaterialExpressionVectorParameter,parameter_name='BaseColour',default_value=u.LinearColor(.20,.18,.14,1));tint=expr(u.MaterialExpressionVectorParameter,parameter_name='PigmentTint',default_value=u.LinearColor(.95,.92,.86,1))
    uv=[]
    for axis,code in enumerate(('float s=N.x>=0?1:-1; return float2(P.y,P.z*s)/Tile;','float s=N.y>=0?1:-1; return float2(P.x,-P.z*s)/Tile;','float s=N.z>=0?1:-1; return float2(P.x,P.y*s)/Tile;')):
        uv.append(custom(code,u.CustomMaterialOutputType.CMOT_FLOAT2,dict(P=(pos,'XYZ'),N=(ni,''),Tile=(tile,'')),f'Physical signed world projection axis{axis}'))
    samples={k:[] for k in textures}
    for kind,texture in textures.items():
        sampler={'albedo':u.MaterialSamplerType.SAMPLERTYPE_COLOR,'normal':u.MaterialSamplerType.SAMPLERTYPE_NORMAL,'rough':u.MaterialSamplerType.SAMPLERTYPE_MASKS}[kind]
        for coord in uv:
            n=expr(u.MaterialExpressionTextureSample,texture=texture,sampler_type=sampler);link(coord,'',n,'UVs');samples[kind].append(n)
    blend='float3 W=pow(abs(normalize(N)),8); W/=max(dot(W,float3(1,1,1)),.0001); '
    colour=custom(blend+'float3 C=X*W.x+Y*W.y+Z*W.z; return lerp(Base.rgb,C,Mix)*Tint.rgb;',u.CustomMaterialOutputType.CMOT_FLOAT3,dict(N=(ni,''),X=(samples['albedo'][0],'RGB'),Y=(samples['albedo'][1],'RGB'),Z=(samples['albedo'][2],'RGB'),Base=(base,'RGB'),Tint=(tint,'RGB'),Mix=(pigmentmix,'')),'Broad accepted angular pigment at physical world scale')
    rough=custom(blend+'return lerp(.88,X*W.x+Y*W.y+Z*W.z,Blend);',u.CustomMaterialOutputType.CMOT_FLOAT1,dict(N=(ni,''),X=(samples['rough'][0],'R'),Y=(samples['rough'][1],'R'),Z=(samples['rough'][2],'R'),Blend=(roughmix,'')),'Independent periodic roughness at identical physical scale')
    normalcode=blend+'''N=normalize(N);
float3 S=float3(N.x>=0?1:-1,N.y>=0?1:-1,N.z>=0?1:-1);
float2 A=X.xy/max(X.z,.1), B=Y.xy/max(Y.z,.1), C=Z.xy/max(Z.z,.1);
float3 D=float3(0,A.x,A.y*S.x)*W.x+float3(B.x,0,-B.y*S.y)*W.y+float3(C.x,C.y*S.z,0)*W.z;
return normalize(N+(D-N*dot(N,D))*Strength);'''
    outputnormal=custom(normalcode,u.CustomMaterialOutputType.CMOT_FLOAT3,dict(N=(ni,''),X=(samples['normal'][0],'RGB'),Y=(samples['normal'][1],'RGB'),Z=(samples['normal'][2],'RGB'),Strength=(amount,'')),'Decoded independent normal slopes in signed world tangent bases; original geometry normal retained')
    metal=expr(u.MaterialExpressionConstant,r=0)
    for node,prop in ((colour,u.MaterialProperty.MP_BASE_COLOR),(rough,u.MaterialProperty.MP_ROUGHNESS),(outputnormal,u.MaterialProperty.MP_NORMAL),(metal,u.MaterialProperty.MP_METALLIC)):assert mel.connect_material_property(node,'',prop)
    assert mel.get_material_property_input_node(mat,u.MaterialProperty.MP_WORLD_POSITION_OFFSET) is None
    mel.recompile_material(mat)
    return dict(material=mat.get_path_name(),textures=TEXTURES,world_tile_cm=180,normal_strength=.6,roughness_blend=.65,pigment_mix=.45,tangent_space_normal=False,boundary='New transient graph only. Nine explicit sampler nodes, signed physical world projections and independent baked DX normal/roughness. No source materials or texture flags changed. Compilation/readback and actual native diagnostic still required. World-space paint is intended only for fixed architecture and fixed closed entrance; moving props need a separate object-anchored contract.')
