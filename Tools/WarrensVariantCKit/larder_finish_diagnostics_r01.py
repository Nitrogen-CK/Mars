"""Two separate, reversible, paused Main PIE appearance diagnostics only.

One light shadow flag OR six material slots on the already-closed S3 candidate.
No saves, new assets, geometry, gameplay properties, collision or source edits.
"""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
RUN=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout'
GATE=DOC/'NATIVE_FINISH_DIAGNOSTIC_GATE_R06.json'
STONE='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02/PBR_R09/Materials/M_CP_Prop_PBR_R09'
OLD='/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX09.M_CCK_TX09'
STATE=None

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def component(c,core):
    return dict(path=c.get_path_name(),mesh=c.static_mesh.get_path_name(),pose=core._pose(c.get_world_transform()),materials=[m.get_path_name() if m else None for m in c.get_materials()],mobility=str(c.mobility),collision=str(c.get_collision_enabled()),profile=str(c.get_collision_profile_name()),body=c.get_editor_property('body_instance').export_text(),overlap=c.get_editor_property('generate_overlap_events'),visible=c.is_visible(),hidden=c.get_editor_property('hidden_in_game'),shadow=c.cast_shadow)

def lights(w):
    import unreal as u
    rows={}
    for a in u.GameplayStatics.get_all_actors_of_class(w,u.Actor):
        if a.get_actor_label() not in ('Warrens_Light_dim_14','WVC_Practical_59','WVC_Practical_60','WVC_Practical_61','WVC_Practical_62'):continue
        c,=a.get_components_by_class(u.PointLightComponent)
        rows[c.get_path_name()]=dict(label=a.get_actor_label(),at=list(c.get_world_location().to_tuple()),intensity=c.intensity,radius=c.attenuation_radius,source_radius=c.source_radius,rgba=[c.light_color.r,c.light_color.g,c.light_color.b,c.light_color.a],shadow=c.cast_shadows,visible=c.is_visible())
    assert len(rows)==5
    return rows

def check():
    import unreal as u
    s=STATE;assert s and s['world']==u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert u.GameplayStatics.is_game_paused(s['world']);s['surface'].guard();s['surface'].clean()
    assert sha(__file__)==s['tool_sha256']
    _,actual=s['core']._hism_snapshot(s['world']);assert actual==s['hisms']
    expected=[dict(r,materials=[s['stone'].get_path_name()]) if s['axis']=='stone' else r for r in s['components']]
    assert [component(c,s['core']) for c in s['targets']]==expected
    expected_lights={k:dict(v,shadow=False) if s['axis']=='shadow' and k==s['light'].get_path_name() else v for k,v in s['lights'].items()}
    assert lights(s['world'])==expected_lights

def begin(surface,capture,core):
    import unreal as u
    global STATE
    assert STATE is None and surface.STATE and surface.STATE['stage']=='surface_only'
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    gate=json.loads(GATE.read_text());assert gate['status']=='APPROVED_DISPOSABLE_FINISH_DIAGNOSTICS_ONLY' and gate['diagnostic_tool_sha256']==sha(__file__)
    w=surface.STATE['world'];assert capture.STATE and capture.STATE['world']==w and u.GameplayStatics.is_game_paused(w)
    kind=u.load_class(None,'/Script/Angelscript.Mars_Anchor_Rubble_EntityScript')
    rubble,=[o for o in u.ObjectIterator(kind) if o.get_world()==w and (o.get_editor_property('SpawnTransform').translation-u.Vector(6175,-1500,-250)).length()<.01]
    anchor=rubble.get_editor_property('Anchor').export_text();assert 'Anchor.Mars.Warrens.S3' in anchor and 'SpanCm=300.000000' in anchor and 'CrawlOffsetCm=()' in anchor
    typ=u.load_class(None,'/Script/Angelscript.Mars_Gate_EntityScript')
    mechanism,=[o for o in u.ObjectIterator(typ) if o.get_world()==w and (o.get_editor_property('SpawnTransform').translation-u.Vector(6175,-1500,-250)).length()<.01]
    contract={p:mechanism.get_editor_property(p).export_text() for p in ('Gate','Sink','Source')};assert 'StartOpen=False' in contract['Gate'] and 'InputChannels=,' in contract['Sink'] and 'TagName=""' in contract['Source'] and 'SOLID' in str(mechanism.get_editor_property('Leaf'))
    expected=[([6175,-1500,-140],[.1,2,2.2]),([6175,-1390,-130],[.4,.2,2.4]),([6175,-1610,-130],[.4,.2,2.4]),([6175,-1500,-20],[.4,2.4,.2]),([6175,-1365,-120],[.4,.3,2.6]),([6175,-1635,-120],[.4,.3,2.6])]
    candidates=[c for a in u.GameplayStatics.get_all_actors_of_class(w,u.Actor) for c in a.get_components_by_class(u.StaticMeshComponent) if not isinstance(c,u.InstancedStaticMeshComponent) and c.static_mesh and c.static_mesh.get_path_name()=='/Engine/BasicShapes/Cube.Cube']
    targets=[]
    for at,scale in expected:
        c,=[c for c in candidates if (c.get_world_location()-u.Vector(*at)).length()<.01 and (c.get_world_scale()-u.Vector(*scale)).length()<.00001]
        assert [m.get_path_name() if m else None for m in c.get_materials()]==[OLD]
        assert c.get_world_transform().rotation.angular_distance(u.Rotator(pitch=0,yaw=180,roll=0).quaternion())<.00001
        targets.append(c)
    point,=[a for a in u.GameplayStatics.get_all_actors_of_class(w,u.Actor) if a.get_actor_label()=='WVC_Practical_59'];light,=point.get_components_by_class(u.PointLightComponent)
    assert light.cast_shadows and list(light.get_world_location().to_tuple())==[3922.,-1250.,-80.]
    stone=u.load_asset(STONE);assert stone
    _,hisms=core._hism_snapshot(w)
    STATE=dict(world=w,surface=surface,capture=capture,core=core,targets=targets,components=[component(c,core) for c in targets],original_materials=[c.get_material(0) for c in targets],stone=stone,light=light,lights=lights(w),hisms=hisms,axis='baseline',tool_sha256=sha(__file__),contract=dict(anchor=anchor,gate=contract))
    check();p=RUN/'finish_diagnostics_baseline_r01.json';assert not p.exists();p.write_text(json.dumps(dict(status='CLOSED_S3_AND_FIVE_LIGHT_BASELINE',components=STATE['components'],lights=STATE['lights'],contract=STATE['contract'],tool_sha256=sha(__file__),gate_sha256=sha(GATE)),indent=2)+'\n');print('FINISH_DIAGNOSTICS_READY_6_SLOTS_1_SHADOW_FLAG')

def axis(name):
    assert name in ('baseline','stone','shadow');check();s=STATE
    assert s['axis']=='baseline' or name=='baseline','Restore one axis before testing another'
    for c,m in zip(s['targets'],s['original_materials']):c.set_material(0,s['stone'] if name=='stone' else m)
    s['light'].set_cast_shadows(name!='shadow');s['axis']=name;check();print('FINISH_AXIS',name)

def capture(label):
    check();s=STATE;s['capture'].capture(label);p=s['capture'].STATE['out']/(label+'_finish.json');assert not p.exists();p.write_text(json.dumps(dict(axis=s['axis'],components=[component(c,s['core']) for c in s['targets']],lights=lights(s['world']),tool_sha256=sha(__file__),boundary='Only six S3 runtime material slots OR Practical59 shadow flag changes, separately. Three reviewed temporary room meshes remain visible. No source/library saves or role/collision/geometry edits.'),indent=2)+'\n')

def restore():
    global STATE
    axis('baseline');check();p=RUN/'finish_diagnostics_restored_r01.json';assert not p.exists();p.write_text(json.dumps(dict(status='SIX_ORIGINAL_MATERIALS_FIVE_ORIGINAL_LIGHTS_AND_ALL_HISMS_EXACT',tool_sha256=sha(__file__)),indent=2)+'\n');STATE=None;print('FINISH_DIAGNOSTICS_RESTORED_REFERENCES_CLEARED')

def abort():
    global STATE
    s=STATE
    try:
        if s:
            for c,m in zip(s['targets'],s['original_materials']):c.set_material(0,m)
            s['light'].set_cast_shadows(True)
    finally:
        STATE=None
        if s:s['surface'].abort()
