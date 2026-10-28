"""Later-turn production fixture ownership, geometry/state and cleanup observations."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-forage-props-r04'
OLD='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02/Forage_R04'
LOADED_TOOL_SHA256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def check_launch(fixture,role):
    assert sha(__file__)==LOADED_TOOL_SHA256
    g=fixture.launch_gate(role);assert g['execution_helper_sha256']==LOADED_TOOL_SHA256
    assert fixture.LOADED_TOOL_SHA256==sha(fixture.__file__)=='639ff71dc6936af695f94f2680f26e6164185a86dbfe66cb9dc8948c94cf060d'
    return g

def part_row(c):
    return dict(path=c.get_path_name(),mesh=c.static_mesh.get_path_name().split('.')[0],material=c.get_material(0).get_path_name().split('.')[0] if c.get_material(0) else None,at=list(c.get_world_location().to_tuple()),scale=list(c.get_world_scale().to_tuple()),pose=c.get_world_transform().export_text(),collision=str(c.get_collision_profile_name()),collision_enabled=str(c.get_collision_enabled()),visible=c.is_visible())

def expected_parts(role):
    stone='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02/PBR_R09/Materials/M_CP_Prop_PBR_R09'
    post=OLD+'/Timber_R02/Materials/M_CP_ForageTimberPost_R02';arm=OLD+'/Timber_R02/Materials/M_CP_ForageTimberArm_R02'
    cube='/Engine/BasicShapes/Cube';fruitmat=OLD+'/Materials/M_CP_ForageFruit_R01';bronze=OLD+'/Materials/M_CP_ForageBronze_R01'
    half=70 if role=='Censer' else 80;length=(2*half+12)/100
    rows=[dict(at=[-9600,1900+half,20],scale=[length,.12,.4],collision='BlockAll',mesh=cube,material=stone),dict(at=[-9600,1900-half,20],scale=[length,.12,.4],collision='BlockAll',mesh=cube,material=stone),dict(at=[-9600+half,1900,20],scale=[.12,length,.4],collision='BlockAll',mesh=cube,material=stone),dict(at=[-9600-half,1900,20],scale=[.12,length,.4],collision='BlockAll',mesh=cube,material=stone)]
    if role=='Censer':
        rows += [dict(at=[-9600,1900,250],scale=[.4,.4,.3],collision='BlockAll',mesh=cube,material=stone),dict(at=[-9600,1900,362.5],scale=[.08,.08,1.95],collision='NoCollision',mesh=cube,material=post),dict(at=[-9600,1900,185],scale=[.06,.06,1.30],collision='NoCollision',mesh=OLD+'/Meshes/WVC_Forage_Chain_R01_SM',material=bronze),dict(at=[-9600,1900,90],scale=[.6,.6,.6],collision='NoCollision',mesh=OLD+'/Meshes/WVC_Forage_CenserBob_R01_SM',material=bronze),dict(at=[-9600,1900,128],scale=[.16,.16,.16],collision='NoCollision',mesh=OLD+'/Meshes/WVC_Forage_PepperContents_R01_SM',material=fruitmat)]
    else:
        rows += [dict(at=[-9720,1900,130],scale=[.24,.24,2.6],collision='BlockAll',mesh=cube,material=post),dict(at=[-9660,1900,260],scale=[1.2,.12,.12],collision='NoCollision',mesh=cube,material=arm),dict(at=[-9600,1900,248],scale=[.025,.025,.12],collision='NoCollision',mesh=cube,material=post),dict(at=[-9600,1900,220],scale=[.44,.44,.44],collision='NoCollision',mesh=OLD+'/Meshes/WVC_Forage_'+role+'_R01_SM',material=fruitmat)]
    return rows

def verify_constructed(fixture):
    import unreal as u
    s=fixture.STATE;a=s['active'];role=a['role'];check_launch(fixture,role)
    assert a['spawn_attempted'] and a['owner'] is not None and a['script'] is None
    w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world();assert w==a['world']
    handles=fixture.api('Handle');life=fixture.api('EntityLifetime')
    assert handles.get_is_valid(a['owner']) and life.get_world_for_entity(a['owner'])==w
    typ=u.get_type_from_class(u.load_class(None,'/Script/Angelscript.'+fixture.ROLES[role]))
    objects=[o for o in u.ObjectIterator(typ) if o.get_path_name().startswith(w.get_path_name()+':') and o.get_world()==w and o.get_editor_property('Anchor').export_text()==s['records'][role]['context'] and o.get_editor_property('SpawnTransform').export_text()==s['records'][role]['transform']]
    obj,=objects;h=obj.do_get_script_entity();assert handles.get_is_valid(h) and life.get_world_for_entity(h)==w
    assert handles.is_equal(life.get_lifetime_owner(h),a['owner'])
    dependents=life.get_lifetime_dependents(a['owner']);assert len(dependents)==1 and handles.is_equal(dependents[0],h)
    assert fixture.defaults(obj,role)==s['records'][role]['defaults']
    components=[c for actor in u.GameplayStatics.get_all_actors_of_class(w,u.Actor) for c in actor.get_components_by_class(u.StaticMeshComponent) if c.static_mesh and abs(c.get_world_location().x+9600)<150 and abs(c.get_world_location().y-1900)<100 and 0<=c.get_world_location().z<=461]
    rows=[part_row(c) for c in components];expected=expected_parts(role);assert len(rows)==len(expected) and len({r['path'] for r in rows})==len(expected)
    for e in expected:
        r,=[r for r in rows if max(abs(x-y) for x,y in zip(e['at'],r['at']))<.001]
        assert max(abs(x-y) for x,y in zip(e['scale'],r['scale']))<.00001
        assert all(r[k]==e[k] for k in ('collision','mesh','material')) and r['visible']
        c,=[c for c in components if c.get_path_name()==r['path']]
        q=c.get_world_transform().rotation
        assert max(abs(q.x),abs(q.y),abs(q.z),abs(abs(q.w)-1))<.000001,'Source-default part rotation changed'
        target=u.CollisionEnabled.QUERY_AND_PHYSICS if e['collision']=='BlockAll' else u.CollisionEnabled.NO_COLLISION
        assert c.get_collision_enabled()==target
    dyn=u.get_type_from_class(u.load_class(None,'/Script/CkDynamic.Ck_Utils_DynamicFragment_UE'))
    fragments=[f.export_text() for f in dyn.get_all_fragments(h)]
    forage_params,=[f for f in fragments if '.Mars_Fragment_Forage_Params(' in f]
    forage,=[f for f in fragments if '.Mars_Fragment_Forage(' in f]
    health,=[f for f in fragments if '.Mars_Fragment_Health_Params(' in f]
    zone,=[f for f in fragments if '.Mars_Fragment_HitZone(' in f]
    assert ('Charges=3' if role=='Censer' else 'Charges=1') in forage_params and ('RegrowSeconds=20.' if role=='Censer' else 'RegrowSeconds=30.') in forage_params
    assert ('ChargesLeft=3' if role=='Censer' else 'ChargesLeft=1') in forage and 'ReleasedCount=0' in forage
    assert ('Invulnerability=Enable' if role=='Censer' else 'Invulnerability=Disable') in health and 'IsEnabled=True' in zone
    fixture.guard();fixture.assert_dirty_scope()
    a.update(script=obj,entity=h,components=components,parts=rows,runtime_verified=True)
    a['constructed_receipt']=fixture.write('fixture_'+role+'_constructed_r14',dict(status='SYNTHETIC_PRODUCTION_ENTITY_OWNERSHIP_DEFAULTS_FEATURES_AND_PARTS_CONFIRMED',role=role,world=w.get_path_name(),script=obj.get_path_name(),entity=handles.conv_handle_to_string(h),owner=handles.conv_handle_to_string(a['owner']),native_owner_equality=True,direct_dependents=1,defaults=fixture.defaults(obj,role),context=obj.get_editor_property('Anchor').export_text(),transform=obj.get_editor_property('SpawnTransform').export_text(),parts=rows,fragments=fragments,empty_niche=a['empty_receipt'],boundary='Later-turn actual production state and complete expected8/9visual parts, using original Finished constructors. Synthetic with emptyAnchorId; not an authored selection or packaged/physical-contact proof.'))
    print('FIXTURE_CONSTRUCTED',a['constructed_receipt'])

def observe(fixture,label):
    import unreal as u
    s=fixture.STATE;a=s['active'];assert a and a['runtime_verified'] and a['script'] is not None
    h=a['script'].do_get_script_entity();assert fixture.api('Handle').get_is_valid(h)
    dyn=u.get_type_from_class(u.load_class(None,'/Script/CkDynamic.Ck_Utils_DynamicFragment_UE'))
    fragments=[f.export_text() for f in dyn.get_all_fragments(h)]
    fragments=[f for f in fragments if any(t in f for t in ('Mars_Fragment_Forage','Mars_Fragment_Health','Mars_Fragment_HitZone'))]
    data=dict(role=a['role'],world=a['world'].get_path_name(),time=u.GameplayStatics.get_time_seconds(a['world']),paused=u.GameplayStatics.is_game_paused(a['world']),entity=fixture.api('Handle').conv_handle_to_string(h),parts=[part_row(c) for c in a['components'] if u.SystemLibrary.is_valid(c)],fragments=fragments,boundary='Read-only synthetic production state. Actual player input/timing must be evidenced separately; no release/refill/health/visibility forcing.')
    r=fixture.write('fixture_'+a['role']+'_'+label+'_r14',data);print('FIXTURE_OBSERVED',r);return data

def verify_destroyed(fixture):
    import unreal as u
    s=fixture.STATE;a=s['active'];assert a and a['owner'] is not None
    handles=fixture.api('Handle');assert not handles.get_is_valid(a['owner'])
    if a.get('entity') is not None:assert not handles.get_is_valid(a['entity'])
    assert all(not u.SystemLibrary.is_valid(c) or not c.is_registered() for c in a['components']),'Recorded fixture components still registered; wait for lifecycle teardown'
    fixture.guard();fixture.assert_dirty_scope();a['destruction_verified']=True
    print('FIXTURE_DESTROYED',fixture.write('fixture_'+a['role']+'_destroyed_r14',dict(status='EXACT_DEDICATED_OWNER_PAYLOAD_INVALID_AND_COMPONENTS_UNREGISTERED',role=a['role'],components=[c.get_path_name() for c in a['components'] if u.SystemLibrary.is_valid(c)],boundary='Only the dedicated fixture owner was requested destroyed. Global transient-owned released items, if any, remain for dedicated PIE teardown.')))

def release_runtime_refs(fixture):
    a=fixture.STATE['active'];assert a
    a['released_role']=a['role'];a['components'].clear()
    for k in ('world','owner','pending','script','entity'):a[k]=None

def finish_session(fixture):
    import unreal as u
    s=fixture.STATE;a=s['active'];assert a and a.get('destruction_verified') and a.get('released_role')==a['role']
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert all(a.get(k) is None for k in ('world','owner','pending','script','entity')) and not a['components']
    fixture.restore_url();fixture.guard();fixture.assert_dirty_scope()
    prefs=s['source'].settings();original=s['source'].STATE['prefs'];assert prefs['autosave']==original['autosave'] and prefs['cook']==original['cook']
    assert u.SystemLibrary.get_console_variable_int_value('r.AntiAliasingMethod')==0
    result=fixture.write('fixture_'+a['role']+'_session_clean_r14',dict(status='DEDICATED_FIXTURE_PIE_ENDED_AND_GUARDS_PREFERENCES_CLEAN',role=a['role'],source_map_sha256=s['source'].STATE['map_after'],protected=651,assets=39,tested_source=10,editor_url='',aa=u.SystemLibrary.get_console_variable_int_value('r.AntiAliasingMethod'),dirty=s['source'].dirty(),boundary='No source/profile/map/library save or cook. Fixture and any globally-owned test drops cleared by dedicated PIE teardown.'))
    s['completed'].append(a['role']);s['active']=None;print('FIXTURE_SESSION_CLEAN',result)
