"""New transient fitted-stone family graph; geometric joints remain source-authored."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/fitted-context-family-r01'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build(material):
    import unreal as u
    assert isinstance(material, u.Material) and material.get_outer().get_path_name() == '/Engine/Transient'
    assert not [n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer() == material]
    profile_path = DOC/'fitted_family_profiles_r01.json'
    profiles = json.loads(profile_path.read_text())
    assert profiles['status'] == 'MEASURED_NATIVE_FAMILY_VALUES_AND_64_AREA_QUANTILES_NOT_ART_ACCEPTED'
    assert sha(DOC/'native_family_sources_r01.json') == profiles['source_receipt_sha256']
    families = [profiles['families'][name] for name in ('Walls', 'Floor', 'Ceiling')]
    for family in families:
        row = family['source']
        assert family['verified_clamp_then_truncate_native_RGB_set'] and len(family['quantile_swatches_UNorm']) == 64
        assert sha(ROOT/row['source_file']) == row['source_sha256']
        assert sha(ROOT/('Content/'+row['mesh'].removeprefix('/Game/')+'.uasset')) == row['package_sha256']
        assert row['textures'] == families[0]['source']['textures']
    texture_paths = families[0]['source']['textures']
    textures = {role: u.load_asset(next(p for p in texture_paths if token in p)) for role, token in [('albedo', 'AngularPigment'), ('normal', 'NormalDX'), ('rough', 'Roughness')]}
    assert textures['normal'].get_editor_property('srgb') is False and textures['rough'].get_editor_property('srgb') is False
    assert textures['albedo'].get_editor_property('srgb') is True
    assert textures['normal'].get_editor_property('compression_settings') == u.TextureCompressionSettings.TC_NORMALMAP
    assert textures['normal'].get_editor_property('flip_green_channel') is False
    for texture in textures.values():
        assert texture.get_editor_property('address_x') == texture.get_editor_property('address_y') == u.TextureAddress.TA_WRAP
    mel = u.MaterialEditingLibrary
    for key, value in dict(blend_mode=u.BlendMode.BLEND_OPAQUE, shading_model=u.MaterialShadingModel.MSM_DEFAULT_LIT, two_sided=False, tangent_space_normal=False, used_with_instanced_static_meshes=True).items():
        material.set_editor_property(key, value)

    def expression(kind, **values):
        node = mel.create_material_expression(material, kind, 0, 0)
        for key, value in values.items():
            node.set_editor_property(key, value)
        return node

    def custom(code, kind, inputs, description):
        node = expression(u.MaterialExpressionCustom, code=code, output_type=kind, description=description)
        pins = []
        for name in inputs:
            pin = u.CustomInput()
            pin.set_editor_property('input_name', name)
            pins.append(pin)
        node.set_editor_property('inputs', pins)
        for name, (source, output) in inputs.items():
            assert mel.connect_material_expressions(source, output, node, name)
        return node

    position = expression(u.MaterialExpressionWorldPosition, world_position_shader_offset=u.WorldPositionIncludedOffsets.WPT_EXCLUDE_ALL_SHADER_OFFSETS)
    vertex_normal = expression(u.MaterialExpressionVertexNormalWS)
    normal = expression(u.MaterialExpressionVertexInterpolator)
    pin, = mel.get_material_expression_input_names(normal)
    assert mel.connect_material_expressions(vertex_normal, '', normal, str(pin))
    random = expression(u.MaterialExpressionPerInstanceRandom)
    room_tint = expression(u.MaterialExpressionVectorParameter, parameter_name='RoomTint', default_value=u.LinearColor(1, 1, 1, 1))
    uv = []
    wall_period = families[0]['source']['pigment_period_metres']*100
    for axis, projection in enumerate(('float2(P.y,P.z*S.x)', 'float2(P.x,-P.z*S.y)', 'float2(P.x,P.y*S.z)')):
        code = f'''float3 n=normalize(N);float3 S=float3(n.x>=0?1:-1,n.y>=0?1:-1,n.z>=0?1:-1);
float period=abs(n.z)<.99?{wall_period:.12g}:100;
float h=frac(H*17.371);float2 phase=float2(frac(h*17.37),frac(h*31.13))*8;
return {projection}/period+phase;'''
        uv.append(custom(code, u.CustomMaterialOutputType.CMOT_FLOAT2, dict(P=(position, 'XYZ'), N=(normal, ''), H=(random, '')), 'Fitted source geometry: signed physical UV axis'+str(axis)+' without drawn courses'))
    samples = {role: [] for role in textures}
    for role, texture in textures.items():
        sampler = dict(albedo=u.MaterialSamplerType.SAMPLERTYPE_COLOR, normal=u.MaterialSamplerType.SAMPLERTYPE_NORMAL, rough=u.MaterialSamplerType.SAMPLERTYPE_MASKS)[role]
        for coord in uv:
            node = expression(u.MaterialExpressionTextureSample, texture=texture, sampler_type=sampler)
            assert mel.connect_material_expressions(coord, '', node, 'UVs')
            samples[role].append(node)
    family_code = 'float3 n=normalize(N);int F=abs(n.z)<.99?0:(n.z>0?1:2);float3 W=pow(abs(n),8);W/=max(dot(W,float3(1,1,1)),.0001);\n'
    bases = ','.join('float3('+','.join(format(v, '.12g') for v in f['source']['base_colour'])+')' for f in families)
    mixes = ','.join(format(f['source']['pigment_mix'], '.12g') for f in families)
    palette = ','.join('float3('+','.join(format(v, '.12g') for v in swatch)+')' for f in families for swatch in f['quantile_swatches_UNorm'])
    colour_code = family_code+f'static const float3 Base[3]={{{bases}}};\nstatic const float Mix[3]={{{mixes}}};\nstatic const float3 Palette[192]={{{palette}}};\n'+'''int i=min(63,max(0,(int)floor(saturate(H)*64)));
float3 pigment=X*W.x+Y*W.y+Z*W.z;
return lerp(Base[F],pigment,Mix[F])*Palette[F*64+i]*1.2*Tint.rgb;'''
    colour = custom(colour_code, u.CustomMaterialOutputType.CMOT_FLOAT3, dict(N=(normal, ''), H=(random, ''), X=(samples['albedo'][0], 'RGB'), Y=(samples['albedo'][1], 'RGB'), Z=(samples['albedo'][2], 'RGB'), Tint=(room_tint, 'RGB')), 'Measured accepted native family colour, per-instance area quantile, no extra grid')
    rough_base = ','.join(format(f['source']['roughness_base'], '.12g') for f in families)
    rough_blend = ','.join(format(f['source']['roughness_blend'], '.12g') for f in families)
    rough = custom(family_code+f'static const float Base[3]={{{rough_base}}};static const float Blend[3]={{{rough_blend}}};\nreturn lerp(Base[F],X*W.x+Y*W.y+Z*W.z,Blend[F]);', u.CustomMaterialOutputType.CMOT_FLOAT1, dict(N=(normal, ''), X=(samples['rough'][0], 'R'), Y=(samples['rough'][1], 'R'), Z=(samples['rough'][2], 'R')), 'Independent source-family roughness with measured native strength')
    strengths = ','.join(format(f['source']['normal_strength'], '.12g') for f in families)
    normal_code = family_code+f'static const float Strength[3]={{{strengths}}};\n'+'''float3 S=float3(n.x>=0?1:-1,n.y>=0?1:-1,n.z>=0?1:-1);
float2 A=X.xy/max(X.z,.1),B=Y.xy/max(Y.z,.1),C=Z.xy/max(Z.z,.1);
float3 D=float3(0,A.x,A.y*S.x)*W.x+float3(B.x,0,-B.y*S.y)*W.y+float3(C.x,C.y*S.z,0)*W.z;
return normalize(n+(D-n*dot(n,D))*Strength[F]);'''
    normal_output = custom(normal_code, u.CustomMaterialOutputType.CMOT_FLOAT3, dict(N=(normal, ''), X=(samples['normal'][0], 'RGB'), Y=(samples['normal'][1], 'RGB'), Z=(samples['normal'][2], 'RGB')), 'Independent DX normal in signed world bases; unperturbed geometry selects family')
    metal = expression(u.MaterialExpressionConstant, r=0.)
    for node, prop in [(colour, u.MaterialProperty.MP_BASE_COLOR), (rough, u.MaterialProperty.MP_ROUGHNESS), (normal_output, u.MaterialProperty.MP_NORMAL), (metal, u.MaterialProperty.MP_METALLIC)]:
        assert mel.connect_material_property(node, '', prop)
    assert mel.get_material_property_input_node(material, u.MaterialProperty.MP_WORLD_POSITION_OFFSET) is None
    assert mel.get_material_property_input_node(material, u.MaterialProperty.MP_EMISSIVE_COLOR) is None
    mel.recompile_material(material)
    return dict(status='TRANSIENT_FITTED_NATIVE_FAMILY_GRAPH_BUILT_NOT_BOUND_OR_COMPILE_PROVEN', material=material.get_path_name(), tool_sha256=sha(__file__), profile_sha256=sha(profile_path), textures={k: v.get_path_name() for k, v in textures.items()}, family_selection='Unperturbed normalized geometric N: vertical/oblique Walls, upward>=.99 Floor, downward<=-.99 Ceiling', swatches_per_family=64, normal_source='Existing independent baked DX map; no albedo-derived relief', drawn_courses=False, boundary='New transient only. Fitted geometry supplies its existing joints; no second shader grid, new geometry, WPO, collision, texture/shared-parent edits or source/library writes. Palette approximates measured native area distribution at64quantiles and records source clipping/mean error. PerInstanceRandom is intended only for enumerated static HISM parts. Compilation, exact graph/value readback and scoped native appearance review remain required. Existing raw-shell/S3/owned surface materials are untouched.')
