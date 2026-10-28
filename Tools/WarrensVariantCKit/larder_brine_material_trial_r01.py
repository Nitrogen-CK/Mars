"""Build-only parameterized copy of the observed opaque brine surface contract.

The caller owns a NEW transient Material; this function binds no components,
saves nothing, and preserves the original normal/UV0 and material flags.
"""
SOURCE='/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_FX_Water'

def build(mat):
    import unreal as u
    assert isinstance(mat,u.Material) and mat.get_outer().get_path_name()=='/Engine/Transient'
    mel=u.MaterialEditingLibrary;assert not [n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==mat]
    source=u.load_asset(SOURCE);assert isinstance(source,u.Material)
    colour=mel.get_material_property_input_node(source,u.MaterialProperty.MP_BASE_COLOR);rough=mel.get_material_property_input_node(source,u.MaterialProperty.MP_ROUGHNESS);normal=mel.get_material_property_input_node(source,u.MaterialProperty.MP_NORMAL);metal=mel.get_material_property_input_node(source,u.MaterialProperty.MP_METALLIC)
    assert isinstance(colour,u.MaterialExpressionConstant3Vector) and isinstance(rough,u.MaterialExpressionConstant) and isinstance(normal,u.MaterialExpressionTextureSample) and isinstance(metal,u.MaterialExpressionConstant)
    assert mel.get_material_property_input_node(source,u.MaterialProperty.MP_WORLD_POSITION_OFFSET) is None and mel.get_material_property_input_node(source,u.MaterialProperty.MP_EMISSIVE_COLOR) is None
    normal_inputs=dict(zip(map(str,mel.get_material_expression_input_names(normal)),mel.get_inputs_for_material_expression(source,normal)));assert normal_inputs.get('UVs') is None
    texture=normal.get_editor_property('texture');assert texture.get_path_name()=='/Game/Mars/Environment/ChainCrossingKit/Textures/T_CCK_Water_NormalDX.T_CCK_Water_NormalDX' and normal.get_editor_property('sampler_type')==u.MaterialSamplerType.SAMPLERTYPE_NORMAL
    assert texture.get_editor_property('srgb') is False and texture.get_editor_property('compression_settings')==u.TextureCompressionSettings.TC_NORMALMAP
    flags={k:source.get_editor_property(k) for k in ('blend_mode','shading_model','two_sided','tangent_space_normal','used_with_instanced_static_meshes')}
    assert flags['blend_mode']==u.BlendMode.BLEND_OPAQUE and flags['shading_model']==u.MaterialShadingModel.MSM_DEFAULT_LIT and flags['two_sided'] is True and flags['tangent_space_normal'] is True and flags['used_with_instanced_static_meshes'] is True
    for k,v in flags.items():mat.set_editor_property(k,v)
    values=dict(colour=colour.get_editor_property('constant'),roughness=rough.get_editor_property('r'),metallic=metal.get_editor_property('r'));assert abs(values['roughness']-.24)<1e-6 and values['metallic']==0
    def expr(cls,**props):
        n=mel.create_material_expression(mat,cls,0,0);assert n
        for k,v in props.items():n.set_editor_property(k,v)
        return n
    nodes=[(expr(u.MaterialExpressionVectorParameter,parameter_name='BrineColour',default_value=values['colour']),'RGB',u.MaterialProperty.MP_BASE_COLOR),(expr(u.MaterialExpressionScalarParameter,parameter_name='BrineRoughness',default_value=values['roughness']),'',u.MaterialProperty.MP_ROUGHNESS),(expr(u.MaterialExpressionTextureSample,texture=texture,sampler_type=u.MaterialSamplerType.SAMPLERTYPE_NORMAL),'RGB',u.MaterialProperty.MP_NORMAL),(expr(u.MaterialExpressionConstant,r=values['metallic']),'',u.MaterialProperty.MP_METALLIC)]
    for node,out,prop in nodes:assert mel.connect_material_property(node,out,prop)
    assert mel.get_material_property_input_node(mat,u.MaterialProperty.MP_WORLD_POSITION_OFFSET) is None and mel.get_material_property_input_node(mat,u.MaterialProperty.MP_EMISSIVE_COLOR) is None
    mel.recompile_material(mat)
    return dict(status='TRANSIENT_BRINE_GRAPH_BUILT_NOT_BOUND_OR_COMPILE_PROVEN',source=SOURCE,material=mat.get_path_name(),flags={k:str(v) for k,v in flags.items()},base_colour=list(values['colour'].to_tuple()),roughness=values['roughness'],metallic=values['metallic'],normal=texture.get_path_name(),normal_uv='Original implicit UV0, unchanged',source_scalar_parameters=['BrineRoughness'],source_vector_parameters=['BrineColour'],boundary='Only a new transient four-node graph. Source opaque/two-sided/default-lit/ISM/tangent-normal contract and exact current colour/roughness/metallic/normal UV0 retained. No new normal from albedo, texture flag, component binding, water transform/top/depth/collision/source/library save or tuning performed. Actual shader completion and original-versus-baseline native pixel comparison required before roughness/colour tuning.')
