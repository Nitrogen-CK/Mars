"""Transient veneer-normal discriminator; same UV/pigment/PBR as owned parents."""
STATE=None

def apply(trial,assets):
    global STATE
    import unreal as u
    assert STATE is None and u.GameplayStatics.is_game_paused(trial.STATE['world'])
    mel=u.MaterialEditingLibrary;rows=[];materials=[]
    def expr(mat,cls,**props):
        e=mel.create_material_expression(mat,cls,0,0);assert e
        for k,v in props.items():e.set_editor_property(k,v)
        return e
    def link(a,out,b,pin):assert mel.connect_material_expressions(a,out,b,pin)
    def scalar(mat,value):return expr(mat,u.MaterialExpressionConstant,r=value)
    for family,normal in [('floor',(0,0,1)),('ceiling',(0,0,-1))]:
        actor,=[a for a in trial.STATE['created'] if a.get_actor_label()=='CP_TRIAL_'+family]
        c=actor.static_mesh_component;old=c.get_material(0)
        assert old==u.load_asset(assets.MATERIALS[family])
        m=u.new_object(u.Material,name='CP_TransientFlatNormal_'+family)
        assert m.get_path_name().startswith('/Engine/Transient.')
        mix,base,roughness=assets.SETTINGS[family]
        base_node=expr(m,u.MaterialExpressionConstant3Vector,constant=u.LinearColor(*base,1))
        pigment=expr(m,u.MaterialExpressionTextureSample,texture=u.load_asset(assets.TEXTURE),sampler_type=u.MaterialSamplerType.SAMPLERTYPE_COLOR)
        uv=expr(m,u.MaterialExpressionTextureCoordinate,coordinate_index=0);link(uv,'',pigment,'UVs')
        blend=expr(m,u.MaterialExpressionLinearInterpolate);link(base_node,'',blend,'A');link(pigment,'RGB',blend,'B');link(scalar(m,mix),'',blend,'Alpha')
        mul=expr(m,u.MaterialExpressionMultiply);link(blend,'',mul,'A')
        vc=expr(m,u.MaterialExpressionVertexColor);mask=expr(m,u.MaterialExpressionComponentMask,r=True,g=True,b=True,a=False);link(vc,'',mask,'None');link(mask,'',mul,'B')
        output=expr(m,u.MaterialExpressionMultiply);link(mul,'',output,'A');link(scalar(m,1.2),'',output,'B')
        assert mel.connect_material_property(output,'',u.MaterialProperty.MP_BASE_COLOR)
        assert mel.connect_material_property(scalar(m,roughness),'',u.MaterialProperty.MP_ROUGHNESS)
        assert mel.connect_material_property(scalar(m,0),'',u.MaterialProperty.MP_METALLIC)
        m.set_editor_property('tangent_space_normal',False)
        n=expr(m,u.MaterialExpressionConstant3Vector,constant=u.LinearColor(*normal,1))
        assert mel.connect_material_property(n,'',u.MaterialProperty.MP_NORMAL)
        mel.recompile_material(m);materials.append(m);rows.append((c,0,old))
    STATE=dict(rows=rows,materials=materials);trial.STATE['scratch_normals']=STATE
    for (c,i,old),m in zip(rows,materials):c.set_material(i,m);assert c.get_material(i)==m
    trial.STATE['stage']='U_flat_veneer_normal_diagnostic'
    print('ONLY_VENEER_NORMALS_OVERRIDDEN',[(c.get_path_name(),m.get_path_name()) for (c,i,o),m in zip(rows,materials)])

def restore():
    global STATE
    assert STATE is not None
    for c,i,m in STATE['rows']:c.set_material(i,m);assert c.get_material(i)==m
    print('EXACT_OWNED_PIGMENT_PARENT_BINDINGS_RESTORED')
    STATE=None
