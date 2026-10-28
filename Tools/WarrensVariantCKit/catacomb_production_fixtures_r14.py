"""Finite synthetic production forage fixtures; no source/map/asset saves."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-forage-props-r04'
PROFILE='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02/Forage_R04/Timber_R02/DA_CP_ForagePresentation_R02'
ROLES={'Fig':'Mars_Forage_FigVine_EntityScript','Censer':'Mars_ForageCenser_EntityScript','Bellnut':'Mars_Forage_BellnutVine_EntityScript'}
ENGINE='/Engine/Transient.UnrealEdEngine_0'
REPLAY='?seed=320153121'
STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
LOADED_TOOL_SHA256=sha(__file__)
def read(p):return json.loads(Path(p).read_text())
def _u():import unreal;return unreal
def write(name,data):
    p=RUN/(name+'.json');assert not p.exists();p.write_text(json.dumps(data,indent=2)+'\n');return dict(file=p.relative_to(ROOT).as_posix(),sha256=sha(p))
def api(name):
    u=_u();c=u.load_class(None,'/Script/CkEcs.Ck_Utils_'+name+'_UE');assert c;return u.get_type_from_class(c)
def guard():
    s=STATE;assert s;s['source'].guard(s['source'].STATE['map_after'])
    inv=read(RUN/'candidate_assets_timber_r13.json');assert sha(RUN/'candidate_assets_timber_r13.json')=='ce24d0065ccd17de8dfe2be98a03cd31d64b7405eddd3f5eb1523da0ec0f7675'
    assert len(inv['assets'])==39 and all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==r['package_sha256'] for p,r in inv['assets'].items())
    return s['source'].guard(s['source'].STATE['map_after'])
def assert_dirty_scope():
    d=STATE['source'].dirty();assert d==dict(maps=[],content=[]),d;return d['maps']

def defaults(o,role):
    keys=('SwingAmplitudeDegrees','SwingPeriodSeconds','SwingSettleSeconds','SwingSeconds','ArmLength','Charges','RefillSeconds','KnockMinSpeed','WithVisuals') if role=='Censer' else ('HangHeight','FruitRadius','HitPoints','RegrowSeconds','KnockMinSpeed','WithVisuals')
    return {k:o.get_editor_property(k) for k in keys}|{'replication':str(o.get_editor_property('_Replication'))}

def prepare(source):
    global STATE
    u=_u();assert STATE is None and u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert source.dirty()==dict(maps=[],content=[]);source.guard(source.STATE['map_after'])
    engine=u.find_object(None,ENGINE);assert engine and u.Object.get_class(engine).get_path_name()=='/Script/UnrealEd.UnrealEdEngine' and engine.get_editor_property('InEditorGameURLOptions')==''
    profile=u.load_asset(PROFILE);assert profile
    STATE=dict(source=source,engine=engine,url_before='',url_staged=False,profile=profile,archetypes={},records={},params=u.InstancedStruct(),delegate=u.Ck_Delegate_Request_OnCompleted(),active=None,started=[],completed=[])
    assert STATE['params'].export_text()=='None';guard();base=source.dependencies()[0]
    for role,name in ROLES.items():
        cls=u.load_class(None,'/Script/Angelscript.'+name);assert cls
        cdo=u.get_default_object(cls);o=u.new_object(u.get_type_from_class(cls),name='WVC_ReviewSynthetic_'+role+'_Archetype_R14')
        STATE['archetypes'][role]=o;assert o.get_outer().get_path_name()=='/Engine/Transient' and not o.get_name().startswith('Default__')
        before=base._export(u,o,RUN/'production_fixtures_r14'/('archetype_'+role+'_before.t3d'))
        original_context=o.get_editor_property('Anchor').export_text();assert original_context==cdo.get_editor_property('Anchor').export_text() and 'AnchorId=(TagName="")' in original_context and 'ForagePresentation=None' in original_context
        original_defaults=defaults(cdo,role);assert defaults(o,role)==original_defaults and 'DOES_NOT_REPLICATE' in original_defaults['replication']
        context=o.get_editor_property('Anchor');context.set_editor_property('forage_presentation',profile);o.set_editor_property('Anchor',context)
        o.set_editor_property('SpawnTransform',u.Transform(location=u.Vector(-9600,1900,0)))
        assert defaults(o,role)==original_defaults and o.get_editor_property('Anchor').get_editor_property('forage_presentation')==profile
        after=base._export(u,o,RUN/'production_fixtures_r14'/('archetype_'+role+'_configured.t3d'))
        strip=lambda p:[line for line in (ROOT/p['file']).read_text().splitlines() if not line.lstrip().startswith(('Anchor=','SpawnTransform='))]
        assert strip(before)==strip(after),'Synthetic archetype changed beyond two allowed fields'
        assert defaults(cdo,role)==original_defaults and cdo.get_editor_property('Anchor').export_text()==original_context
        STATE['records'][role]=dict(class_path=cls.get_path_name(),archetype=o.get_path_name(),context=o.get_editor_property('Anchor').export_text(),transform=o.get_editor_property('SpawnTransform').export_text(),defaults=original_defaults,before=before,configured=after)
    guard();assert_dirty_scope()
    STATE['preflight']=write('production_fixtures_preflight_r14',dict(status='THREE_TRANSIENT_PRODUCTION_ARCHETYPES_PREPARED_NO_OWNER_OR_SPAWN',tool_sha256=LOADED_TOOL_SHA256,archetypes=STATE['records'],profile=profile.get_path_name(),params=STATE['params'].export_text(),delegate='Native empty unbound Ck_Delegate_Request_OnCompleted',replay=REPLAY,source_map_sha256=source.STATE['map_after'],asset_inventory_sha256=sha(RUN/'candidate_assets_timber_r13.json'),boundary='Only transient archetype Anchor.ForagePresentation and SpawnTransform changed. Production CDOs/gameplay defaults remain exact. No owner, pending entity, PIE, URL or persistent asset mutation.'))
    print('FIXTURE_PREFLIGHT',STATE['preflight'])

def verify_after_gc():
    u=_u();s=STATE;assert s and s['active'] is None
    assert u.SystemLibrary.is_valid(s['profile']) and u.find_object(None,s['profile'].get_path_name())==s['profile']
    for role,o in s['archetypes'].items():
        r=s['records'][role];assert u.SystemLibrary.is_valid(o) and u.find_object(None,r['archetype'])==o
        assert o.get_editor_property('Anchor').export_text()==r['context'] and o.get_editor_property('SpawnTransform').export_text()==r['transform'] and defaults(o,role)==r['defaults']
        assert o.get_editor_property('Anchor').get_editor_property('forage_presentation')==s['profile']
    guard();assert_dirty_scope()
    s['after_gc']=write('production_fixtures_after_gc_r14',dict(status='PROFILE_AND_THREE_ARCHETYPES_RETAINED_AFTER_SEPARATE_GC_TURN',preflight=s['preflight'],profile=s['profile'].get_path_name(),archetypes={k:o.get_path_name() for k,o in s['archetypes'].items()},boundary='Actual separate native turn after queued collection. Python wrapper collector source traces ObjectInstance; STATE retains all wrappers for the entire future pending/live fixture. No fixture spawn.'))
    print('FIXTURE_AFTER_GC',s['after_gc'])

def launch_gate(role):
    assert role in ROLES and LOADED_TOOL_SHA256==sha(__file__);s=STATE
    g=read(DOC/('PRODUCTION_FIXTURE_LAUNCH_GATE_R14_'+role+'.json'))
    assert g['status']=='APPROVED_ONE_DEDICATED_PRODUCTION_FIXTURE_PIE' and g['tool_sha256']==LOADED_TOOL_SHA256 and g['preflight']==s['preflight'] and g['after_gc']==s['after_gc'] and g['role']==role and g['replay']==REPLAY
    return g

def stage_replay(role):
    u=_u();s=STATE;launch_gate(role);assert s['active'] is None and role not in s['started']
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    guard();assert_dirty_scope();assert s['engine'].get_editor_property('InEditorGameURLOptions')==''
    s['started'].append(role);s['active']=dict(role=role,owner=None,pending=None,script=None,components=[],runtime_verified=False,spawn_attempted=False)
    s['url_staged']=True;s['engine'].set_editor_property('InEditorGameURLOptions',REPLAY);assert s['engine'].get_editor_property('InEditorGameURLOptions')==REPLAY
    print('FIXTURE_REPLAY_STAGED',role)

def restore_url():
    s=STATE;assert s['engine'].get_editor_property('InEditorGameURLOptions') in ('',REPLAY)
    s['engine'].set_editor_property('InEditorGameURLOptions','');assert s['engine'].get_editor_property('InEditorGameURLOptions')=='';s['url_staged']=False

def verify_empty_niche():
    u=_u();s=STATE;a=s['active'];assert a and not a['spawn_attempted'] and not s['url_staged'];launch_gate(a['role'])
    w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world();assert w and w.get_path_name()=='/Game/Mars/Maps/UEDPIE_0_Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    typ=u.get_type_from_class(u.load_class(None,'/Script/Angelscript.Mars_ForageSource_EntityScript'))
    sources=[o for o in u.ObjectIterator(typ) if o.get_path_name().startswith(w.get_path_name()+':') and o.get_world()==w]
    assert sources and not any('Anchor.Mars.Warrens.CatacombHusk' in o.get_editor_property('Anchor').export_text() for o in sources),'Authored candidate occupies niche; no hiding or seed retry'
    h=sources[0].do_get_script_entity();handles=api('Handle');life=api('EntityLifetime');assert handles.get_is_valid(h) and life.get_world_for_entity(h)==w
    tags=u.get_type_from_class(u.load_class(None,'/Script/CkEntityTag.Ck_Utils_EntityTag_UE'));dyn=u.get_type_from_class(u.load_class(None,'/Script/CkDynamic.Ck_Utils_DynamicFragment_UE'))
    data={}
    for tag in ('TAG_MarsAnchorResolver','TAG_MarsAnchor'):
        data[tag]=[]
        for entity in tags.for_each_entity(h,u.Name(tag)):
            texts=[f.export_text() for f in dyn.get_all_fragments(entity)]
            if tag=='TAG_MarsAnchorResolver' or any('Anchor.Mars.Warrens.CatacombHusk' in t for t in texts):data[tag].append(texts)
    resolver,=data['TAG_MarsAnchorResolver'];params,=[t for t in resolver if '.Mars_Fragment_AnchorResolver_Params(' in t];ledger,=[t for t in resolver if '.Mars_Fragment_AnchorResolver(' in t]
    assert 'Seed=320153121,' in params
    assert '(AnchorId=(TagName="Anchor.Mars.Warrens.CatacombHusk"),RowIndex=4,ScriptName="Nothing",Anchor=())' in ledger
    anchor,=data['TAG_MarsAnchor'];ap,=[t for t in anchor if '.Mars_Fragment_Anchor_Params(' in t]
    assert 'PinnedRow=()' in ap and 'ForagePresentation=' in ap
    parts=[c for actor in u.GameplayStatics.get_all_actors_of_class(w,u.Actor) for c in actor.get_components_by_class(u.StaticMeshComponent) if c.static_mesh and abs(c.get_world_location().x+9600)<150 and abs(c.get_world_location().y-1900)<100 and 0<=c.get_world_location().z<=461]
    assert not parts,'Niche already has an unexpected visual component'
    a['world']=w;a['empty_receipt']=write('fixture_'+a['role']+'_empty_niche_r14',dict(status='ACTUAL_AUTHORED_NOTHING_ROW4_AND_CLEAR_NICHE',world=w.get_path_name(),role=a['role'],fragments=data,source_contexts=[dict(path=o.get_path_name(),type=o.get_class().get_path_name(),context=o.get_editor_property('Anchor').export_text()) for o in sources],boundary='Controlled replay of previously observed seed; no authored selection changes. Synthetic fixture not yet spawned.'))
    guard();assert_dirty_scope();print('EMPTY_NICHE',a['empty_receipt'])

def spawn():
    u=_u();s=STATE;a=s['active'];assert a and a.get('empty_receipt') and not a['spawn_attempted'];role=a['role'];launch_gate(role)
    g=read(DOC/('PRODUCTION_FIXTURE_SPAWN_GATE_R14_'+role+'.json'));assert g['status']=='APPROVED_ONE_SYNTHETIC_PRODUCTION_SPAWN' and g['tool_sha256']==LOADED_TOOL_SHA256 and g['empty_niche']==a['empty_receipt'] and g['role']==role
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()==a['world'];guard();assert_dirty_scope()
    handles=api('Handle');life=api('EntityLifetime');entity=api('EntityScript');pending_api=api('PendingEntityScript')
    a['spawn_attempted']=True;a['owner']=life.request_create_entity_transient_owner(a['world'])
    owner=a['owner'];assert handles.get_is_valid(owner) and life.get_world_for_entity(owner)==a['world'] and life.get_can_create_entity(owner) and not life.get_is_transient_entity(owner)
    assert len(life.get_lifetime_dependents(owner))==0
    result=entity.request_spawn_entity_archetype(owner,s['archetypes'][role],s['params'],s['delegate'])
    assert isinstance(result,tuple) and len(result)==2;pending,out_owner=result;a['pending']=pending
    assert handles.is_equal(owner,out_owner) and pending_api.get_is_valid(pending)
    print('SYNTHETIC_SPAWN_ENQUEUED',write('fixture_'+role+'_spawn_enqueued_r14',dict(status='ONE_PUBLIC_ARCHETYPE_SPAWN_ENQUEUED_UNDER_DEDICATED_OWNER',role=role,owner=handles.conv_handle_to_string(owner),world=a['world'].get_path_name(),archetype=s['records'][role],pending_valid=True,boundary='Request validity is not construction completion. Later-turn script/entity/owner/default/state/part proof is required.')))

def destroy_owner():
    s=STATE;a=s['active'];assert a
    if a['owner'] is not None and api('Handle').get_is_valid(a['owner']):api('EntityLifetime').request_destroy_entity(a['owner'])
    print('DEDICATED_OWNER_DESTROY_REQUESTED',a['role'])
