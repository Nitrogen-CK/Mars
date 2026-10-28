"""Resume the exact owned prop shader after verified UE5.7 frequency rejection."""
import json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def resume(base):
    import unreal as u
    base._ready();mel=u.MaterialEditingLibrary;eal=u.EditorAssetLibrary
    current=json.loads((RUN/'assets_created_r02.json').read_text());expected={base.TEXTURE,*[base.MATERIALS[k] for k in ('walls','floor','ceiling')]}
    assert set(current['assets'])==expected
    for p,r in current['assets'].items():assert sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==r['package_sha256']
    material=u.load_asset(base.MATERIALS['prop']);assert material and eal.get_metadata_tag(material,'Owner')==base.OWNER and eal.get_metadata_tag(material,'State')==''
    assert [p.get_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()]==[base.MATERIALS['prop']]
    nodes=[n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==material]
    custom,=[n for n in nodes if isinstance(n,u.MaterialExpressionCustom)]
    pairs=[]
    for cls,pin in ((u.MaterialExpressionPreSkinnedPosition,'Pos'),(u.MaterialExpressionPreSkinnedNormal,'Normal')):
        source,=[n for n in nodes if isinstance(n,cls)]
        interp=mel.create_material_expression(material,u.MaterialExpressionVertexInterpolator,0,0)
        inputs=list(mel.get_material_expression_input_names(interp));assert len(inputs)==1,inputs
        assert mel.connect_material_expressions(source,'',interp,inputs[0])
        assert mel.connect_material_expressions(interp,'',custom,pin)
        pairs.append(dict(source=source.get_class().get_name(),interpolator=interp.get_name(),actual_input_name=inputs[0],custom_pin=pin))
    mel.recompile_material(material);stats=mel.get_statistics(material);assert stats.num_pixel_shader_instructions>0
    actual=dict(zip(map(str,mel.get_material_expression_input_names(custom)),mel.get_inputs_for_material_expression(material,custom)))
    assert all(isinstance(actual[p],u.MaterialExpressionVertexInterpolator) for p in ('Pos','Normal'))
    base._record(material,dict(kind='prop',mix=.45,base=[.20,.18,.14],roughness=.88,normal='geometry only; disconnected',
        pigment_projection='Stable source-local triplanar65cm; vertex-stage pre-skinned position/normal passed through explicit interpolators',
        repaired_error="PreSkinnedPosition is not available in Pixel shader; explicit VertexInterpolator supplies its vertex result",
        actual_interpolators=pairs,compiled_shader_stats=dict(pixel_instructions=stats.num_pixel_shader_instructions,vertex_instructions=stats.num_vertex_shader_instructions)))
    assert not eal.does_asset_exist(base.MATERIALS['mortar']) and not eal.does_asset_exist(base.LID)
    tools=u.AssetToolsHelpers.get_asset_tools();target=base.MATERIALS['mortar']
    mat=tools.create_asset(target.rsplit('/',1)[1],base.DEST+'/Materials',u.Material,u.MaterialFactoryNew());assert mat
    color=mel.create_material_expression(mat,u.MaterialExpressionConstant3Vector,0,0);color.set_editor_property('constant',u.LinearColor(.12,.105,.08,1))
    rough=mel.create_material_expression(mat,u.MaterialExpressionConstant,0,0);rough.set_editor_property('r',.90)
    assert mel.connect_material_property(color,'',u.MaterialProperty.MP_BASE_COLOR);assert mel.connect_material_property(rough,'',u.MaterialProperty.MP_ROUGHNESS)
    mel.set_material_usage(mat,u.MaterialUsage.MATUSAGE_INSTANCED_STATIC_MESHES);mel.recompile_material(mat);s=mel.get_statistics(mat);assert s.num_pixel_shader_instructions>0
    base._record(mat,dict(kind='mortar',base=[.12,.105,.08],roughness=.9,compiled_pixel_instructions=s.num_pixel_shader_instructions))
    mi=tools.create_asset(base.LID.rsplit('/',1)[1],base.DEST+'/Materials',u.MaterialInstanceConstant,u.MaterialInstanceConstantFactoryNew());assert mi
    mel.set_material_instance_parent(mi,material);mel.set_material_instance_vector_parameter_value(mi,'PropOriginB',u.LinearColor(-72.65,-25,0,1))
    value=mel.get_material_instance_vector_parameter_value(mi,'PropOriginB');assert abs(value.r+72.65)<1e-4 and value.g==-25
    base._record(mi,dict(parent=base.MATERIALS['prop'],PropOriginB=[value.r,value.g,value.b,value.a]))
    base._guard();assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    result=dict(status='OWNED_PROP_VERTEX_STAGE_CORRECTION_COMPLETE',corrective_tool_sha256=sha(__file__),base_tool_sha256=sha(base.__file__),
        interpolators=pairs,pixel_instructions=stats.num_pixel_shader_instructions,guard_count=len(base._guard()),boundary='Seven owned review assets total; no maps/shared original assets modified. Three mesh imports pending.')
    out=RUN/'materials_correction_r05.json';assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(result['status'],sha(out));return result['status']
