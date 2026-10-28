"""Build-only downward colour/course parity; old normal/roughness stay connected."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build(material):
    import unreal as u
    assert isinstance(material, u.Material) and material.get_outer().get_path_name() == '/Engine/Transient'
    path = Path(__file__).with_name('world_coursed_painterly_r01.py')
    assert sha(path) == 'ac3138fc273ac84297544d050a0efb8da5749d0ff8a2a9c00386d9315b48e9a3'
    spec = importlib.util.spec_from_file_location('_ceiling_underlay_old', path)
    previous = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(previous)
    previous.build(material)
    palette_path = DOC/'ceiling-underlay-family-r01/native_ceiling_tint_palette.json'
    palette = json.loads(palette_path.read_text())
    assert palette['status'] == 'AREA_WEIGHTED_VERIFIED_NATIVE_CEILING_VERTEX_TINT_PALETTE_NOT_APPEARANCE_ACCEPTED'
    proof = DOC/'roof-completion-export-r01/native_asset.json'
    assert sha(proof) == palette['native_asset_receipt_sha256']
    native = json.loads(proof.read_text())
    assert sha(ROOT/('Content/'+native['target'].removeprefix('/Game/')+'.uasset')) == palette['native_package_sha256']
    entries = palette['palette']
    assert len(entries) == 354 and palette['vertex_gain'] == 1.2
    mel = u.MaterialEditingLibrary
    nodes = [n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer() == material]
    position, = [n for n in nodes if isinstance(n, u.MaterialExpressionWorldPosition)]
    geometric_normal, = [n for n in nodes if isinstance(n, u.MaterialExpressionVertexInterpolator)]
    old_colour = mel.get_material_property_input_node(material, u.MaterialProperty.MP_BASE_COLOR)
    old_normal = mel.get_material_property_input_node(material, u.MaterialProperty.MP_NORMAL)
    old_roughness = mel.get_material_property_input_node(material, u.MaterialProperty.MP_ROUGHNESS)
    mortar, = [n for n in nodes if isinstance(n, u.MaterialExpressionVectorParameter) and str(n.get_editor_property('parameter_name')) == 'MortarColour']

    def custom(code, kind, inputs, description):
        node = mel.create_material_expression(material, u.MaterialExpressionCustom, 0, 0)
        node.set_editor_property('code', code)
        node.set_editor_property('output_type', kind)
        node.set_editor_property('description', description)
        pins = []
        for name in inputs:
            pin = u.CustomInput()
            pin.set_editor_property('input_name', name)
            pins.append(pin)
        node.set_editor_property('inputs', pins)
        for name, (source, output) in inputs.items():
            assert mel.connect_material_expressions(source, output, node, name)
        return node

    coords = '''float2 Q=float2(P.x+7000,P.y+5500);
float2 cell=floor(Q/float2(120,90));
float h=frac(sin(dot(cell,float2(17.17,23.71)))*43758.5453);
float2 phase=float2(frac(h*17.37),frac(h*31.13))*8;
float2 UV=Q/100; int turn=(int)floor(frac(h*7.31)*4);
for(int i=0;i<turn;i++) UV=float2(-UV.y,UV.x);
return UV+phase;'''
    uv = custom(coords, u.CustomMaterialOutputType.CMOT_FLOAT2, dict(P=(position, 'XYZ')), 'Ceiling 1m pigment UV with per-120x90cm-cell phase; source-plan coordinates')
    sample = mel.create_material_expression(material, u.MaterialExpressionTextureSample, 0, 0)
    texture = u.load_asset('/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02/Textures/T_CP_AngularPigment_R02')
    sample.set_editor_property('texture', texture)
    sample.set_editor_property('sampler_type', u.MaterialSamplerType.SAMPLERTYPE_COLOR)
    assert mel.connect_material_expressions(uv, '', sample, 'UVs')
    cdf = ','.join(format(e['cumulative_probability'], '.12g') for e in entries)
    colours = ','.join('float3('+','.join(format(v, '.12g') for v in e['shader_vertex_UNorm'])+')' for e in entries)
    code = '''if(N.z>=-.99) return Old;
float2 Q=float2(P.x+7000,P.y+5500);
float2 cell=floor(Q/float2(120,90));
float h=frac(sin(dot(cell,float2(17.17,23.71)))*43758.5453);
'''+f'static const float CDF[354]={{{cdf}}};\nstatic const float3 Palette[354]={{{colours}}};\n'+'''
int lo=0,hi=353;
[unroll] for(int i=0;i<9;i++){int mid=(lo+hi)/2;if(h<=CDF[mid])hi=mid;else lo=mid+1;}
float3 C=lerp(float3(.14,.125,.10),Pigment,.25)*Palette[lo]*1.2;
float2 f=frac(Q/float2(120,90));
float d=min(min(f.x*120,(1-f.x)*120),min(f.y*90,(1-f.y)*90));
float joint=1-smoothstep(1.2*.35,1.2*.65,d);
return lerp(C,Mortar.rgb,joint);'''
    output = custom(code, u.CustomMaterialOutputType.CMOT_FLOAT3, dict(N=(geometric_normal, ''), P=(position, 'XYZ'), Pigment=(sample, 'RGB'), Old=(old_colour, ''), Mortar=(mortar, 'RGB')), 'Downward-only measured native tint CDF and accepted ceiling base/pigment/course response')
    assert mel.connect_material_property(output, '', u.MaterialProperty.MP_BASE_COLOR)
    assert mel.get_material_property_input_node(material, u.MaterialProperty.MP_NORMAL) == old_normal
    assert mel.get_material_property_input_node(material, u.MaterialProperty.MP_ROUGHNESS) == old_roughness
    assert mel.get_material_property_input_node(material, u.MaterialProperty.MP_WORLD_POSITION_OFFSET) is None
    mel.recompile_material(material)
    return dict(status='TRANSIENT_DOWNWARD_COLOUR_COURSE_DISCRIMINATOR_BUILT_NOT_BOUND_OR_COMPILE_PROVEN', material=material.get_path_name(), tool_sha256=sha(__file__), old_builder_sha256=sha(path), palette_sha256=sha(palette_path), palette_entries=354, native_mean_vertex_UNorm=palette['weighted_mean_vertex_UNorm'], ceiling_pigment_metres=1, ceiling_courses_cm=[120, 90], ceiling_joint_cm=1.2, geometric_downward_mask='N.z < -.99', normal_output_unchanged=old_normal.get_path_name(), roughness_output_unchanged=old_roughness.get_path_name(), boundary='New transient material only. Old vertical/upward colour and all old normals/roughness retained. Only geometrically downward BaseColor/course response differs. Measured source-native area-weighted tint CDF is sampled per world cell, not exact source cell/UV phase. Native compilation/readback and matched BaseColor/Lit validation required. No existing S3 master, asset, source or library mutation. Fitted CCS13/CCS15 geometry is not authorized for this drawn-grid version.')
