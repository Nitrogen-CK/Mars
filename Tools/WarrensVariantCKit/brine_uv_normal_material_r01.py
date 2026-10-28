"""Build-only brine successor with separately adjustable UV scale/normal texture."""
import importlib.util
from pathlib import Path

def build(mat):
    import unreal as u
    assert isinstance(mat,u.Material) and mat.get_outer().get_path_name()=='/Engine/Transient'
    spec=importlib.util.spec_from_file_location('_brine_parameter_base',Path(__file__).with_name('larder_brine_material_trial_r01.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base);record=base.build(mat)
    mel=u.MaterialEditingLibrary;original=mel.get_material_property_input_node(mat,u.MaterialProperty.MP_NORMAL);assert isinstance(original,u.MaterialExpressionTextureSample) and original.get_editor_property('const_coordinate')==0
    def expr(cls,**props):
        node=mel.create_material_expression(mat,cls,0,0);assert node
        for key,value in props.items():node.set_editor_property(key,value)
        return node
    u_repeat=expr(u.MaterialExpressionScalarParameter,parameter_name='NormalURepeat',default_value=1.)
    v_repeat=expr(u.MaterialExpressionScalarParameter,parameter_name='NormalVRepeat',default_value=1.)
    repeat=expr(u.MaterialExpressionAppendVector);assert mel.connect_material_expressions(u_repeat,'',repeat,'A') and mel.connect_material_expressions(v_repeat,'',repeat,'B')
    coord=expr(u.MaterialExpressionTextureCoordinate,coordinate_index=0,u_tiling=1.,v_tiling=1.,un_mirror_u=False,un_mirror_v=False)
    scaled=expr(u.MaterialExpressionMultiply);assert mel.connect_material_expressions(coord,'',scaled,'A') and mel.connect_material_expressions(repeat,'',scaled,'B')
    normal=expr(u.MaterialExpressionTextureSampleParameter2D,parameter_name='WaterNormal',texture=original.get_editor_property('texture'),sampler_type=u.MaterialSamplerType.SAMPLERTYPE_NORMAL)
    fields=['const_coordinate','sampler_source','mip_value_mode','automatic_view_mip_bias']
    for key in fields:normal.set_editor_property(key,original.get_editor_property(key));assert normal.get_editor_property(key)==original.get_editor_property(key)
    assert mel.connect_material_expressions(scaled,'',normal,'UVs') and mel.connect_material_property(normal,'RGB',u.MaterialProperty.MP_NORMAL)
    assert mel.get_material_property_input_node(mat,u.MaterialProperty.MP_WORLD_POSITION_OFFSET) is None and mel.get_material_property_input_node(mat,u.MaterialProperty.MP_EMISSIVE_COLOR) is None
    mel.recompile_material(mat)
    record.update(status='NEW_TRANSIENT_BRINE_UV_NORMAL_GRAPH_BUILT_NOT_BOUND_OR_COMPILE_PROVEN',material=mat.get_path_name(),normal_texture_parameter='WaterNormal',normal_uv_scalar_parameters={'NormalURepeat':1.,'NormalVRepeat':1.},normal_sampler_equal_fields=fields,boundary='New transient successor only, original brine flags/colour/.24roughness/metal0 preserved. Explicit UV0 multiplied by two independent scalar parameters, default1/1, and original NormalDX as default texture parameter. Baseline native parity required before original texture at(4,3.5), then candidate texture at identical scale. Darkteal/.45 working values set/read on trial MID; no source texture/material, water geometry/collision/flow/WPO or library writes.')
    return record
