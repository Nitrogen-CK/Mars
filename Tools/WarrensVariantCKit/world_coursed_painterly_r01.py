"""Build-only static masonry presentation for permanently closed solid parts.

World centimetres preserve block scale across nonuniform gate/filler cubes.
Drawn joints do not change geometry, WPO, collision or any mechanism contract.
"""
import importlib.util
from pathlib import Path

def build(mat):
    import unreal as u
    assert isinstance(mat,u.Material) and mat.get_outer().get_path_name()=='/Engine/Transient'
    spec=importlib.util.spec_from_file_location('_coursed_world_base',Path(__file__).with_name('world_painterly_pbr_r01.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base);record=base.build(mat)
    mel=u.MaterialEditingLibrary;nodes=[n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==mat]
    position,=[n for n in nodes if isinstance(n,u.MaterialExpressionWorldPosition)];normal,=[n for n in nodes if isinstance(n,u.MaterialExpressionVertexInterpolator)]
    colour=mel.get_material_property_input_node(mat,u.MaterialProperty.MP_BASE_COLOR);rough=mel.get_material_property_input_node(mat,u.MaterialProperty.MP_ROUGHNESS);independent_normal=mel.get_material_property_input_node(mat,u.MaterialProperty.MP_NORMAL)
    mortar_source=u.load_asset('/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02/Materials/M_CP_Mortar_R02');mortar_colour=mel.get_material_property_input_node(mortar_source,u.MaterialProperty.MP_BASE_COLOR);mortar_rough=mel.get_material_property_input_node(mortar_source,u.MaterialProperty.MP_ROUGHNESS)
    assert isinstance(mortar_colour,u.MaterialExpressionConstant3Vector) and isinstance(mortar_rough,u.MaterialExpressionConstant)
    def expr(cls,**props):
        node=mel.create_material_expression(mat,cls,0,0);assert node
        for key,value in props.items():node.set_editor_property(key,value)
        return node
    def custom(code,kind,inputs,label):
        node=expr(u.MaterialExpressionCustom,code=code,output_type=kind,description=label);pins=[]
        for name in inputs:
            pin=u.CustomInput();pin.set_editor_property('input_name',name);pins.append(pin)
        node.set_editor_property('inputs',pins)
        for name,(source,out) in inputs.items():assert mel.connect_material_expressions(source,out,node,name)
        return node
    width=expr(u.MaterialExpressionScalarParameter,parameter_name='BlockWidthCm',default_value=90.)
    height=expr(u.MaterialExpressionScalarParameter,parameter_name='CourseHeightCm',default_value=50.)
    joint=expr(u.MaterialExpressionScalarParameter,parameter_name='JointWidthCm',default_value=1.2)
    mortar=expr(u.MaterialExpressionVectorParameter,parameter_name='MortarColour',default_value=mortar_colour.get_editor_property('constant'))
    finish=expr(u.MaterialExpressionScalarParameter,parameter_name='MortarRoughness',default_value=mortar_rough.get_editor_property('r'))
    pattern=custom('''float3 A=abs(normalize(N));
float2 Q=A.z>=max(A.x,A.y)?float2(P.x+7000,P.y+5500):float2(A.x>=A.y?P.y+5500:P.x+7000,P.z);
float row=floor(Q.y/Height); Q.x+=fmod(row,2)*Width*.5;
float2 cell=float2(Q.x/Width,Q.y/Height); float2 f=frac(cell);
float d=min(min(f.x*Width,(1-f.x)*Width),min(f.y*Height,(1-f.y)*Height));
float mortar=1-smoothstep(Joint*.35,Joint*.65,d);
float tone=.90+.16*frac(sin(dot(floor(cell),float2(17.17,23.71)))*43758.5453);
return float2(mortar,tone);''',u.CustomMaterialOutputType.CMOT_FLOAT2,dict(P=(position,'XYZ'),N=(normal,''),Width=(width,''),Height=(height,''),Joint=(joint,'')),'Physical90x50cm staggered courses; source-plan offsets align existing masonry')
    painted=custom('return lerp(C*Pattern.y,Mortar.rgb,Pattern.x);',u.CustomMaterialOutputType.CMOT_FLOAT3,dict(C=(colour,''),Pattern=(pattern,''),Mortar=(mortar,'RGB')),'Quiet course tint and existing approved mortar colour, no baked light')
    finished=custom('return lerp(R,Mortar,Pattern.x);',u.CustomMaterialOutputType.CMOT_FLOAT1,dict(R=(rough,''),Mortar=(finish,''),Pattern=(pattern,'')),'Independent stone finish and existing mortar roughness')
    assert mel.connect_material_property(painted,'',u.MaterialProperty.MP_BASE_COLOR) and mel.connect_material_property(finished,'',u.MaterialProperty.MP_ROUGHNESS)
    assert mel.get_material_property_input_node(mat,u.MaterialProperty.MP_NORMAL)==independent_normal and mel.get_material_property_input_node(mat,u.MaterialProperty.MP_WORLD_POSITION_OFFSET) is None and mel.get_material_property_input_node(mat,u.MaterialProperty.MP_EMISSIVE_COLOR) is None
    mel.recompile_material(mat)
    record.update(status='TRANSIENT_COURSED_WORLD_MASONRY_BUILT_NOT_BOUND_OR_COMPILE_PROVEN',block_width_cm=90.,course_height_cm=50.,joint_width_cm=1.2,mortar_colour=list(mortar_colour.get_editor_property('constant').to_tuple()),mortar_roughness=mortar_rough.get_editor_property('r'),boundary='One new transient graph only; existing accepted independent normal/roughness retained, quiet world-scale coursing and per-block pigment hierarchy. Drawn joints have no displacement or new normal relief. Intended only for fixed permanently closed masonry parts. No source/shared materials, geometry/collision, gate/anchor role or library changes; native appearance and compile/readback still required.')
    return record
