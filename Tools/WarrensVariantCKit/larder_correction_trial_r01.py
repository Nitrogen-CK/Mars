"""Finite disposable sack mesh, water UV/normal and closed-S3 slot comparisons."""
import copy,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
DEST='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01'
OLD_NORMAL='/Game/Mars/Environment/ChainCrossingKit/Textures/T_CCK_Water_NormalDX'
NEW_NORMAL=DEST+'/PBR_R02/Textures/T_Larder_BrineWave_NormalDX_R01'
NEW_SACK=DEST+'/Meshes/WVC_Larder_StableFootSack_R01_SM'
OLD_STONE='/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX09'
STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def read_s3(controller):
    import unreal as u
    s=controller.STATE;w=s['world'];kind=u.load_class(None,'/Script/Angelscript.Mars_Anchor_Rubble_EntityScript');roots=[o for o in u.ObjectIterator(kind) if o.get_world()==w and (o.get_editor_property('SpawnTransform').translation-u.Vector(6175,-1500,-250)).length()<.01]
    typ=u.load_class(None,'/Script/Angelscript.Mars_Gate_EntityScript');gates=[o for o in u.ObjectIterator(typ) if o.get_world()==w and (o.get_editor_property('SpawnTransform').translation-u.Vector(6175,-1500,-250)).length()<.01]
    if not roots:
        assert not gates;return dict(role='S3_RUBBLE_AND_GATE_ABSENT_AXIS_SKIPPED',root=None,gate=None,contract=None,targets=[],records=[],materials=[])
    root,=roots;gate,=gates;anchor=root.get_editor_property('Anchor').export_text();assert 'Anchor.Mars.Warrens.S3' in anchor and 'SpanCm=300.000000' in anchor and 'CrawlOffsetCm=()' in anchor
    contract=dict(anchor=anchor,spawn=root.get_editor_property('SpawnTransform').export_text(),leaf=str(gate.get_editor_property('Leaf')),**{p:gate.get_editor_property(p).export_text() for p in ['Gate','Sink','Source']});assert 'SOLID' in contract['leaf'] and 'StartOpen=False' in contract['Gate'] and 'InputChannels=,' in contract['Sink'] and 'TagName=""' in contract['Source']
    expected=[([6175,-1500,-140],[.1,2,2.2]),([6175,-1390,-130],[.4,.2,2.4]),([6175,-1610,-130],[.4,.2,2.4]),([6175,-1500,-20],[.4,2.4,.2]),([6175,-1365,-120],[.4,.3,2.6]),([6175,-1635,-120],[.4,.3,2.6])];targets=[]
    for at,scale in expected:
        c,=[c for a in u.GameplayStatics.get_all_actors_of_class(w,u.Actor) for c in a.get_components_by_class(u.StaticMeshComponent) if not isinstance(c,u.InstancedStaticMeshComponent) and c.static_mesh and c.static_mesh.get_path_name()=='/Engine/BasicShapes/Cube.Cube' and (c.get_world_location()-u.Vector(*at)).length()<.01 and (c.get_world_scale()-u.Vector(*scale)).length()<.00001]
        assert len(c.get_materials())==1 and c.get_material(0).get_path_name().split('.')[0]==OLD_STONE and c.get_world_transform().rotation.angular_distance(u.Rotator(pitch=0,yaw=180,roll=0).quaternion())<.00001;targets.append(c)
    return dict(role='NATURAL_CLOSED_SOLID_UNCHANNELLED_S3',root=root,gate=gate,contract=contract,targets=targets,records=[s['light_reader'].component(c,s['core']) for c in targets],materials=[c.get_material(0) for c in targets])

def check():
    import unreal as u
    t=STATE;assert t and sha(__file__)==t['gate']['tool_sha256'];controller=t['controller'];controller.check();s=controller.STATE
    for path,digest in t['gate']['helper_sha256'].items():assert sha(ROOT/path)==digest
    if t['successor_on']:
        assert s['water_mid']==t['new_mid'] and s['water_parent_active']==t['uv_parent'] and t['new_mid'].get_editor_property('parent')==t['uv_parent']
    else:assert s['water_mid']==t['old_mid'] and s['water_parent_active']==t['old_parent']
    assert s['water_rough']==.45 and s['water_colour']==(.025,.075,.055,1.)
    for mid in [t['old_mid']]+([t['new_mid']] if t['new_mid'] else []):
        assert abs(mid.get_scalar_parameter_value('BrineRoughness')-.45)<1e-6 and max(abs(a-b) for a,b in zip(mid.get_vector_parameter_value('BrineColour').to_tuple(),(.025,.075,.055,1.)))<1e-6
    if t['new_mid']:
        assert abs(t['new_mid'].get_scalar_parameter_value('NormalURepeat')-t['repeat'][0])<1e-6 and abs(t['new_mid'].get_scalar_parameter_value('NormalVRepeat')-t['repeat'][1])<1e-6
        assert t['new_mid'].get_texture_parameter_value('WaterNormal').get_path_name().split('.')[0]==(NEW_NORMAL if t['new_normal'] else OLD_NORMAL)
    sack=s['props']['sack']['actor'];assert sack.static_mesh_component.static_mesh==(t['stable_mesh'] if t['stable'] else t['old_sack'])
    source=t['s3']
    if source['root']:
        gate=source['gate'];contract=dict(anchor=source['root'].get_editor_property('Anchor').export_text(),spawn=source['root'].get_editor_property('SpawnTransform').export_text(),leaf=str(gate.get_editor_property('Leaf')),**{p:gate.get_editor_property(p).export_text() for p in ['Gate','Sink','Source']});assert contract==source['contract']
        expected=[dict(r,materials=[t['s3_parent'].get_path_name()]) if t['s3_on'] else r for r in source['records']]
        assert [s['light_reader'].component(c,s['core']) for c in source['targets']]==expected
    else:assert not t['s3_on']

def begin(controller,uv_parent,s3_parent):
    import unreal as u
    global STATE
    assert STATE is None;controller.check();s=controller.STATE
    gate=json.loads((DOC/'NATIVE_LARDER_CORRECTION_GATE_R01.json').read_text());assert gate['status']=='APPROVED_FINITE_DISPOSABLE_LARDER_CORRECTIONS_ONLY' and gate['tool_sha256']==sha(__file__) and gate['controller_sha256']==sha(controller.__file__)
    for p,h in gate['helper_sha256'].items():assert sha(ROOT/p)==h
    for p,h in gate['input_sha256'].items():assert sha(ROOT/p)==h
    assert s['props']['jar']['closed'] and set(s['paint_mids'])=={'barrel','sack','jar'} and s['water_mid'] and s['water_parent_active']==s['brine']
    identity=json.loads((ROOT/gate['material_identity_file']).read_text());reader=controller.load('catacomb_plane_normal_materials');mel=u.MaterialEditingLibrary
    for role,mat in [('uv_parent',uv_parent),('s3_parent',s3_parent)]:
        r=identity[role];assert isinstance(mat,u.Material) and mat.get_outer().get_path_name()=='/Engine/Transient' and mat.get_path_name()==r['material'] and reader.snapshot(mat)==r['snapshot']
        for key,value in r['scalars'].items():assert abs(mel.get_material_default_scalar_parameter_value(mat,key)-value)<1e-6
        for key,value in r['vectors'].items():assert max(abs(a-b) for a,b in zip(mel.get_material_default_vector_parameter_value(mat,key).to_tuple(),value))<1e-6
        for key,value in r['textures'].items():assert mel.get_material_default_texture_parameter_value(mat,key).get_path_name()==value
        assert mel.get_statistics(mat).num_pixel_shader_instructions>0
    stable=u.load_asset(NEW_SACK);assert isinstance(stable,u.StaticMesh)
    old_sack=s['props']['sack']['actor'].static_mesh_component.static_mesh;assert old_sack==s['props']['sack']['original']
    STATE=dict(controller=controller,gate=gate,uv_parent=uv_parent,s3_parent=s3_parent,old_parent=s['brine'],old_mid=s['water_mid'],new_mid=None,successor_on=False,repeat=(1.,1.),new_normal=False,stable=False,stable_mesh=stable,old_sack=old_sack,s3=read_s3(controller),s3_on=False)
    check();print('CORRECTION_TRIAL_READY',STATE['s3']['role'])

def sack_stable(on):
    import unreal as u
    check();assert isinstance(on,bool);t=STATE;s=t['controller'].STATE;a=s['props']['sack']['actor'];before=t['controller'].owned(a);mesh=t['stable_mesh'] if on else t['old_sack'];assert a.static_mesh_component.set_static_mesh(mesh);assert t['controller'].owned(a)==dict(before,mesh=mesh.get_path_name())
    index=s['created'].index(a);s['owned_expected'][index]=dict(s['owned_expected'][index],mesh=mesh.get_path_name());t['stable']=on;check()

def water_successor(on):
    import unreal as u
    check();assert isinstance(on,bool);t=STATE;s=t['controller'].STATE;c=s['water_component']
    if on:
        assert not t['successor_on']
        if not t['new_mid']:
            mid=c.create_dynamic_material_instance(0,t['uv_parent'],'Larder_Brine_UVNormal_Trial_R01');assert isinstance(mid,u.MaterialInstanceDynamic) and mid.get_editor_property('parent')==t['uv_parent'];mid.set_scalar_parameter_value('BrineRoughness',.45);mid.set_vector_parameter_value('BrineColour',u.LinearColor(.025,.075,.055,1));t['new_mid']=mid
        else:c.set_material(0,t['new_mid'])
        mid=t['new_mid'];parent=t['uv_parent']
    else:
        assert t['successor_on'];mid=t['old_mid'];parent=t['old_parent'];c.set_material(0,mid)
    assert c.get_material(0)==mid and mid.get_editor_property('parent')==parent
    s['water_mid']=mid;s['water_parent_active']=parent;s['expected_hisms'][c.get_path_name()]['materials']=[mid.get_path_name().split('.')[0]];t['successor_on']=on;check()

def water_repeat(corrected):
    check();assert isinstance(corrected,bool);t=STATE;parity=json.loads((DOC/'NATIVE_BRINE_UV_PARITY_GATE_R01.json').read_text());assert parity['status']=='APPROVED_UV_NORMAL_AXES_AFTER_NATIVE_DEFAULT_PARITY' and parity['tool_sha256']==sha(__file__) and sha(ROOT/parity['baseline_receipt'])==parity['baseline_receipt_sha256']
    assert t['successor_on'] and not t['new_normal'];value=(4.,3.5) if corrected else (1.,1.);t['new_mid'].set_scalar_parameter_value('NormalURepeat',value[0]);t['new_mid'].set_scalar_parameter_value('NormalVRepeat',value[1]);t['repeat']=value;check()

def water_normal(candidate):
    import unreal as u
    check();assert isinstance(candidate,bool);t=STATE;parity=json.loads((DOC/'NATIVE_BRINE_UV_PARITY_GATE_R01.json').read_text());assert parity['status']=='APPROVED_UV_NORMAL_AXES_AFTER_NATIVE_DEFAULT_PARITY' and parity['tool_sha256']==sha(__file__) and sha(ROOT/parity['baseline_receipt'])==parity['baseline_receipt_sha256']
    assert t['successor_on'] and t['repeat']==(4.,3.5)
    texture=u.load_asset(NEW_NORMAL if candidate else OLD_NORMAL);assert isinstance(texture,u.Texture2D) and texture.get_editor_property('srgb') is False and texture.get_editor_property('compression_settings')==u.TextureCompressionSettings.TC_NORMALMAP and texture.get_editor_property('flip_green_channel') is False and texture.get_editor_property('address_x')==texture.get_editor_property('address_y')==u.TextureAddress.TA_WRAP
    t['new_mid'].set_texture_parameter_value('WaterNormal',texture);t['new_normal']=candidate;check()

def s3_stone(on):
    check();assert isinstance(on,bool);t=STATE;assert len(t['s3']['targets'])==6
    for c,original in zip(t['s3']['targets'],t['s3']['materials']):c.set_material(0,t['s3_parent'] if on else original)
    t['s3_on']=on;check()

def capture(label):
    import unreal as u
    t=STATE;s=t['controller'].STATE;u.GameplayStatics.set_game_paused(s['world'],True);check();t['controller'].capture(label);path=s['capture'].STATE['out']/(label+'.json');r=json.loads(path.read_text());mid=s['water_mid']
    r['correction_state']=dict(stable_sack=t['stable'],water_successor=t['successor_on'],water_mid=mid.get_path_name(),water_parent=mid.get_editor_property('parent').get_path_name(),roughness=mid.get_scalar_parameter_value('BrineRoughness'),colour=list(mid.get_vector_parameter_value('BrineColour').to_tuple()),normal_repeat=[t['new_mid'].get_scalar_parameter_value(v) for v in ['NormalURepeat','NormalVRepeat']] if t['successor_on'] else [1.,1.],normal_texture=t['new_mid'].get_texture_parameter_value('WaterNormal').get_path_name() if t['successor_on'] else OLD_NORMAL+'.'+OLD_NORMAL.rsplit('/',1)[1],s3_role=t['s3']['role'],s3_stone=t['s3_on'],s3_contract=t['s3']['contract'],s3_parts=[s['light_reader'].component(c,s['core']) for c in t['s3']['targets']])
    r['boundary']+=' Additional finite trial: one owned sack mesh, water MID parent/UV/texture, and only naturally CLOSED S3 six runtime material-slot0 bindings may differ as explicitly recorded; physical transforms/collision and closed/no-channel role remain exact. No original package or library saved.';path.write_text(json.dumps(r,indent=2)+'\n')

def restore():
    global STATE
    check();t=STATE
    if t['s3_on']:s3_stone(False)
    if t['successor_on']:water_successor(False)
    if t['stable']:sack_stable(False)
    check();controller=t['controller'];STATE=None;controller.check();print('CORRECTION_BINDINGS_RESTORED_REFERENCES_RELEASED')

def abort(controller):
    global STATE
    try:controller.abort()
    finally:STATE=None
