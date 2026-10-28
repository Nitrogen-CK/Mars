"""Finite disposable original-Sack body-slot diagnostic. Saves no asset."""
import copy,json
STATE=None

def build(outer):
    import unreal as u
    assert outer.get_path_name()=='/Engine/Transient'
    mats=[];records=[];mel=u.MaterialEditingLibrary
    for two in (False,True):
        m=u.new_object(u.Material,outer=outer,name='Larder_Sack_FlatMask_'+str(two)+'_R03')
        m.set_editor_property('blend_mode',u.BlendMode.BLEND_OPAQUE)
        m.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT)
        m.set_editor_property('two_sided',two)
        n=mel.create_material_expression(m,u.MaterialExpressionConstant3Vector,0,0)
        n.set_editor_property('constant',u.LinearColor(1,0,1,1))
        assert mel.connect_material_property(n,'',u.MaterialProperty.MP_EMISSIVE_COLOR)
        mel.recompile_material(m);stats=mel.get_statistics(m)
        assert stats.num_pixel_shader_instructions>0
        assert m.get_editor_property('blend_mode')==u.BlendMode.BLEND_OPAQUE and m.get_editor_property('shading_model')==u.MaterialShadingModel.MSM_UNLIT and m.get_editor_property('two_sided')==two
        # PDO is not exposed by this build's Python MaterialProperty enum.
        # One constant node connected only to Emissive also excludes a PDO graph.
        for p in ['MP_NORMAL','MP_OPACITY','MP_OPACITY_MASK','MP_WORLD_POSITION_OFFSET']:
            assert mel.get_material_property_input_node(m,getattr(u.MaterialProperty,p)) is None
        assert [x for x in u.ObjectIterator(u.MaterialExpression) if x.get_outer()==m]==[n]
        mats.append(m);records.append(dict(path=m.get_path_name(),blend='OPAQUE',shading='UNLIT',two_sided=two,emissive=[1,0,1],nodes=1,ps_instructions=stats.num_pixel_shader_instructions))
    return mats,records

def begin(controller,correction,built):
    import unreal as u
    global STATE
    assert STATE is None
    correction.check();s=controller.STATE
    assert not correction.STATE['stable'] and not correction.STATE['successor_on']
    a=s['props']['sack']['actor'];c=a.static_mesh_component
    assert c.static_mesh==s['props']['sack']['original'] and c.get_material(0)==s['paint_mids']['sack']
    mats,records=built;assert len(mats)==len(records)==2
    for m,r in zip(mats,records):
        assert m.get_path_name()==r['path'] and m.get_editor_property('blend_mode')==u.BlendMode.BLEND_OPAQUE and m.get_editor_property('shading_model')==u.MaterialShadingModel.MSM_UNLIT and m.get_editor_property('two_sided')==r['two_sided']
        assert u.MaterialEditingLibrary.get_statistics(m).num_pixel_shader_instructions==r['ps_instructions']
    STATE=dict(controller=controller,correction=correction,actor=a,component=c,original=c.get_material(0),before=copy.deepcopy(controller.owned(a)),index=s['created'].index(a),mats=mats,records=records,axis='original')
    check();print('SACK_FLAT_DIAGNOSTIC_READY',records)

def check():
    t=STATE;assert t;t['correction'].check();s=t['controller'].STATE
    assert not t['correction'].STATE['stable'] and not t['correction'].STATE['successor_on']
    expected=copy.deepcopy(t['before']);expected['materials'][0]=(t['original'] if t['axis']=='original' else t['mats'][0 if t['axis']=='one_sided' else 1]).get_path_name()
    assert t['controller'].owned(t['actor'])==expected
    assert s['owned_expected'][t['index']]==expected
    assert t['component'].get_material(0).get_path_name()==expected['materials'][0]

def bind(axis):
    assert axis in ('original','one_sided','two_sided');check();t=STATE;s=t['controller'].STATE
    m=t['original'] if axis=='original' else t['mats'][0 if axis=='one_sided' else 1]
    before=t['controller'].owned(t['actor']);t['component'].set_material(0,m)
    expected=copy.deepcopy(before);expected['materials'][0]=m.get_path_name()
    assert t['controller'].owned(t['actor'])==expected
    s['owned_expected'][t['index']]=expected;t['axis']=axis;check()

def capture(label):
    check();t=STATE;t['correction'].capture(label)
    p=t['controller'].STATE['capture'].STATE['out']/(label+'.json');r=json.loads(p.read_text())
    r['sack_flat_diagnostic']=dict(axis=t['axis'],material=t['component'].get_material(0).get_path_name(),original=t['original'].get_path_name(),graphs=t['records'],boundary='Diagnostic only. Unlit emissive may change indirect illumination; unchanged light metadata is not proof of pixel-identical scene lighting. No production two-sided workaround authorized.')
    p.write_text(json.dumps(r,indent=2)+'\n')

def restore():
    global STATE
    bind('original');t=STATE
    assert t['component'].get_material(0)==t['original'] and t['controller'].owned(t['actor'])==t['before']
    controller=t['controller'];STATE=None;controller.check();print('SACK_FLAT_DIAGNOSTIC_RESTORED_RELEASED')

def abort():
    global STATE
    t=STATE
    try:
        if t:t['correction'].abort(t['controller'])
    finally:STATE=None
