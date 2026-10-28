"""Reusable owned/transient timber graph; use reflected pin names on engine-specific nodes."""
def build(mat,role,resume_prefix=False):
    import unreal as u
    mel=u.MaterialEditingLibrary
    assert role in ('TimberPost','TimberArm')
    def expr(cls,**props):
        n=mel.create_material_expression(mat,cls,0,0);assert n
        for k,v in props.items():n.set_editor_property(k,v)
        return n
    def link(a,b,pin):assert mel.connect_material_expressions(a,'',b,str(pin)),(a.get_name(),b.get_name(),pin)
    def inputs(n):return list(mel.get_inputs_for_material_expression(mat,n))
    axis=(8,8,.35) if role=='TimberPost' else (.35,8,8)
    if resume_prefix:
        assert role=='TimberPost'
        nodes={n.get_name():n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==mat}
        expected={'MaterialExpressionPreSkinnedPosition_0':u.MaterialExpressionPreSkinnedPosition,'MaterialExpressionVertexInterpolator_0':u.MaterialExpressionVertexInterpolator,'MaterialExpressionConstant_0':u.MaterialExpressionConstant,'MaterialExpressionMultiply_0':u.MaterialExpressionMultiply,'MaterialExpressionConstant3Vector_0':u.MaterialExpressionConstant3Vector,'MaterialExpressionAdd_0':u.MaterialExpressionAdd,'MaterialExpressionConstant3Vector_1':u.MaterialExpressionConstant3Vector,'MaterialExpressionMultiply_1':u.MaterialExpressionMultiply,'MaterialExpressionNoise_0':u.MaterialExpressionNoise}
        assert set(nodes)==set(expected) and all(isinstance(nodes[k],v) for k,v in expected.items())
        p=nodes['MaterialExpressionPreSkinnedPosition_0'];vi=nodes['MaterialExpressionVertexInterpolator_0'];factor=nodes['MaterialExpressionConstant_0'];mul=nodes['MaterialExpressionMultiply_0'];half=nodes['MaterialExpressionConstant3Vector_0'];add=nodes['MaterialExpressionAdd_0'];axes=nodes['MaterialExpressionConstant3Vector_1'];stretch=nodes['MaterialExpressionMultiply_1'];noise=nodes['MaterialExpressionNoise_0']
        assert inputs(vi)==[p] and inputs(mul)==[vi,factor] and inputs(add)==[mul,half] and inputs(stretch)==[add,axes]
        assert all(n is None for n in inputs(noise))
        assert abs(factor.get_editor_property('r')-.01)<1e-6
        for node,values in ((half,(.5,.5,.5)),(axes,axis)):
            color=node.get_editor_property('constant');assert max(abs(a-b) for a,b in zip((color.r,color.g,color.b),values))<1e-6
        assert noise.get_editor_property('levels')==1 and abs(noise.get_editor_property('scale')-2)<1e-6 and noise.get_editor_property('turbulence') is False
        assert noise.get_editor_property('output_min')==0 and noise.get_editor_property('output_max')==1
    else:
        p=expr(u.MaterialExpressionPreSkinnedPosition);vi=expr(u.MaterialExpressionVertexInterpolator);pin,=mel.get_material_expression_input_names(vi);link(p,vi,pin)
        factor=expr(u.MaterialExpressionConstant,r=.01);mul=expr(u.MaterialExpressionMultiply);link(vi,mul,'A');link(factor,mul,'B')
        half=expr(u.MaterialExpressionConstant3Vector,constant=u.LinearColor(.5,.5,.5,1));add=expr(u.MaterialExpressionAdd);link(mul,add,'A');link(half,add,'B')
        axes=expr(u.MaterialExpressionConstant3Vector,constant=u.LinearColor(*axis,1));stretch=expr(u.MaterialExpressionMultiply);link(add,stretch,'A');link(axes,stretch,'B')
        noise=expr(u.MaterialExpressionNoise,scale=2.0,levels=1,turbulence=False,output_min=0.0,output_max=1.0)
    # UMaterialExpressionNoise calls its first input "World Position" in this engine, not its C++ member "Position".
    noise_pins=list(map(str,mel.get_material_expression_input_names(noise)));assert len(noise_pins)==2 and noise_pins[1]=='FilterWidth'
    link(stretch,noise,noise_pins[0])
    base=expr(u.MaterialExpressionCustom,output_type=u.CustomMaterialOutputType.CMOT_FLOAT3,description='Four dry timber tones; broad lengthwise bands, no normal from paint',code='return V<0.38?float3(0.035,0.018,0.008):V<0.53?float3(0.075,0.036,0.014):V<0.67?float3(0.12,0.058,0.021):float3(0.17,0.085,0.029);')
    inp=u.CustomInput();inp.set_editor_property('input_name','V');base.set_editor_property('inputs',[inp]);link(noise,base,'V')
    assert mel.connect_material_property(base,'',u.MaterialProperty.MP_BASE_COLOR)
    for value,prop in ((0,u.MaterialProperty.MP_METALLIC),(.86,u.MaterialProperty.MP_ROUGHNESS)):
        n=expr(u.MaterialExpressionConstant,r=value);assert mel.connect_material_property(n,'',prop)
    assert all(mel.get_material_property_input_node(mat,p) for p in (u.MaterialProperty.MP_BASE_COLOR,u.MaterialProperty.MP_ROUGHNESS,u.MaterialProperty.MP_METALLIC))
    return dict(role=role,axis=axis,noise_inputs=noise_pins,nodes=len([n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==mat]),resumed_prefix=resume_prefix)

def probe():
    import unreal as u,json,hashlib
    from pathlib import Path
    before=[p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()];rows=[]
    for role in ('TimberPost','TimberArm'):
        mat=u.new_object(u.Material,name='CP_Forage_'+role+'_CompleteGraphProbe_R01');assert mat.get_outer().get_path_name()=='/Engine/Transient'
        rows.append(build(mat,role))
    assert [p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()]==before
    # Validate the script-defined nested dataasset properties separately without creating a persistent asset.
    cls=u.load_class(None,'/Script/Angelscript.Mars_ForagePresentation_Def');profile=u.new_object(u.get_type_from_class(cls),name='CP_Forage_ProfilePropertyProbe_R01')
    censer=profile.get_editor_property('censer');vine=profile.get_editor_property('vine')
    censer.set_editor_property('ceiling_height_cm',460.0);vine.set_editor_property('connector_length_cm',12.0);vine.set_editor_property('connector_width_cm',2.5)
    profile.set_editor_property('censer',censer);profile.set_editor_property('vine',vine)
    assert profile.get_editor_property('censer').get_editor_property('ceiling_height_cm')==460
    assert profile.get_editor_property('vine').get_editor_property('connector_length_cm')==12
    result=dict(status='REMAINING_MATERIAL_GRAPHS_AND_NESTED_PROFILE_API_PROBED',graphs=rows,profile=dict(censer=censer.export_text(),vine=vine.export_text()),dirty_content_unchanged=before,boundary='Transient API/wire construction only, no source asset changes and no shader or native appearance acceptance.')
    p=Path(__file__).resolve().parents[2]/'Saved/WarrensCGameplay-20261024/CatacombPilot/forage_remaining_api_probe_r01.json';assert not p.exists();p.write_text(json.dumps(result,indent=2)+'\n');print(result['status'],hashlib.sha256(p.read_bytes()).hexdigest())
