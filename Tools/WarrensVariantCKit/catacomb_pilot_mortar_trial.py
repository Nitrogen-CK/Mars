"""Unsaved, transient room-local mortar contrast diagnostic only."""
STATE=None

def apply(trial):
    global STATE
    import unreal as u
    assert STATE is None and u.GameplayStatics.is_game_paused(trial.STATE['world'])
    mel=u.MaterialEditingLibrary;rows=[];materials=[]
    for family,color in [('floor',(.24,.21,.16)),('ceiling',(.14,.125,.10))]:
        actor,=[a for a in trial.STATE['created'] if a.get_actor_label()=='CP_TRIAL_'+family]
        c=actor.static_mesh_component;old=c.get_material(1)
        assert old.get_path_name().endswith('/Materials/M_CP_Mortar_R02.M_CP_Mortar_R02')
        m=u.new_object(u.Material,name='CP_TransientMortar_'+family)
        assert m.get_path_name().startswith('/Engine/Transient.')
        rgb=mel.create_material_expression(m,u.MaterialExpressionConstant3Vector,0,0)
        rgb.set_editor_property('constant',u.LinearColor(*color,1))
        rough=mel.create_material_expression(m,u.MaterialExpressionConstant,0,200);rough.set_editor_property('r',.9)
        assert mel.connect_material_property(rgb,'',u.MaterialProperty.MP_BASE_COLOR)
        assert mel.connect_material_property(rough,'',u.MaterialProperty.MP_ROUGHNESS)
        mel.recompile_material(m)
        rows.append((c,1,old));materials.append(m)
    STATE=dict(rows=rows,materials=materials)
    trial.STATE['scratch_mortar']=STATE
    for (c,i,old),m in zip(rows,materials):c.set_material(i,m);assert c.get_material(i)==m
    trial.STATE['stage']='T_lower_joint_contrast'
    print('TRANSIENT_MORTAR_ONLY',[(c.get_path_name(),m.get_path_name()) for (c,i,o),m in zip(rows,materials)])

def restore():
    global STATE
    assert STATE is not None
    for c,i,m in STATE['rows']:c.set_material(i,m);assert c.get_material(i)==m
    print('EXACT_OWNED_MORTAR_BINDINGS_RESTORED')
    STATE=None
