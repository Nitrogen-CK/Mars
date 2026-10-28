"""Finite source-room adoption. Import/checkpoint are inert/read-only; stage/save gated."""
import copy
import hashlib
import json
import re
import shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
MANIFEST=DOC/'SOURCE_RETENTION_MANIFEST_R17.json'
MANIFEST_SHA='31ded4ed94c56395979a807cc0e17ae107e93886d73a7e562b66b711cb150975'
STATE=None
OVERRIDE_CLASSES={'WVC_WVC026':'Material','WVC_WVC081':'MaterialInstanceConstant','WVC_WVC052':'MaterialInstanceConstant','WVC_WVC053':'MaterialInstanceConstant'}

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
LOADED_TOOL_SHA256=sha(__file__)
def _u():import unreal;return unreal
def package(o):return o.get_path_name().split('.')[0] if o else None
def full(p):return p+'.'+p.rsplit('/',1)[1]
def write(name,r):
    p=RUN/(name+'_r18.json');assert not p.exists();p.write_text(json.dumps(r,indent=2)+'\n')
    return dict(file=p.relative_to(ROOT).as_posix(),sha256=sha(p))
def transform(p):
    u=_u();q=u.Quat()
    for axis,value in zip(('x','y','z','w'),p['q']):q.set_editor_property(axis,value)
    t=u.Transform(location=u.Vector(*p['at']),scale=u.Vector(*p['scale']));t.set_editor_property('rotation',q);return t
def rgba(c):return [c.r,c.g,c.b,c.a]
def color(values):
    c=_u().Color()
    for key,value in zip(('r','g','b','a'),values):c.set_editor_property(key,value)
    assert rgba(c)==values;return c
def manifest():
    assert sha(MANIFEST)==MANIFEST_SHA
    m=read(MANIFEST);assert len(m['new_actors'])==7 and len(m['append_hism_instances'])==len(m['material_bindings'])==4
    assert len(m['source_light_intensities'])==3 and m['source_main_offset_cm']==[-9800,-1500,0]
    return m
def world():return STATE['source'].world()
def guard():
    s=STATE;g=s['source'].guard(s['current_hash']);a=read(RUN/'candidate_assets_timber_r13.json')
    assert sha(RUN/'candidate_assets_timber_r13.json')=='ce24d0065ccd17de8dfe2be98a03cd31d64b7405eddd3f5eb1523da0ec0f7675'
    assert len(a['assets'])==39 and all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==r['package_sha256'] for p,r in a['assets'].items())
    return g
def snapshot(label):
    s=STATE;u=_u();w=world();base,core=s['source'].dependencies();folder=RUN/'source_room_r18'/label
    assert not folder.exists();roster,hisms=base._roster(u,core,w,folder)
    target=s['source'].target(w);script=base._export(u,target,folder/'forage_script.t3d')
    lights={}
    for a in u.GameplayStatics.get_all_actors_of_class(w,u.Actor):
        for c in a.get_components_by_class(u.PointLightComponent):
            lights[a.get_actor_label()]=dict(path=c.get_path_name(),pose=core._pose(c.get_world_transform()),intensity=c.intensity,units=str(c.get_editor_property('intensity_units')),radius=c.attenuation_radius,color=list((c.light_color.r,c.light_color.g,c.light_color.b,c.light_color.a)),source_radius=c.source_radius,source_length=c.source_length,soft_source_radius=c.soft_source_radius,inverse_squared=c.use_inverse_squared_falloff,cast_shadows=c.cast_shadows,visible=c.is_visible(),inner=c.inner_cone_angle if isinstance(c,u.SpotLightComponent) else None,outer=c.outer_cone_angle if isinstance(c,u.SpotLightComponent) else None)
    return dict(roster=roster,hisms=hisms,script=script,target=target.get_path_name(),profile=package(target.get_editor_property('ForagePresentation')),lights=lights)
def checkpoint(source):
    global STATE
    u=_u();assert STATE is None and source.dirty()==dict(maps=[],content=[])
    m=manifest();source.world();core=source.dependencies()[1]
    all_poses=[r['pose'] for r in m['new_actors']]+[p for r in m['append_hism_instances'] for p in r['add_local_poses']]
    assert len(all_poses)==19 and all(core._pose(transform(p))==p for p in all_poses),'Native transform construction must preserve all19 exact inputs before any mutation'
    assert sha(ROOT/m['source_map_file'])==m['source_map_sha256_before']
    STATE=dict(source=source,m=m,current_hash=m['source_map_sha256_before'],stage='checkpointing',prefs=source.settings(),created=[],reopens=[],unloads=[])
    guard();folder=RUN/'source_room_r18';folder.mkdir(exist_ok=False)
    backup=folder/'LI_Warrens_Catacomb_before.umap';shutil.copy2(ROOT/m['source_map_file'],backup);assert sha(backup)==STATE['current_hash']
    admit()
    before=snapshot('before');assert len(before['roster'])==34 and len(before['hisms'])==20 and sum(len(r['instances']) for r in before['hisms'].values())==4357
    assert before['profile']==m['forage_profile']['before']
    assert source.target(world()).get_outer().get_editor_property('actor_guid').export_text()==m['forage_profile']['source_actor_guid']
    source.compare(source.STATE['saved'],dict(world=source.PACKAGE+'.LI_Warrens_Catacomb',target=before['target'],actor=source.STATE['saved']['actor'],anchor_id=source.TAG,profile=full(before['profile']),script=before['script'],roster=before['roster'],hisms=before['hisms']))
    assert not any(m['owner'] in row['tags'] for row in before['roster'].values())
    guard();assert source.dirty()==dict(maps=[],content=[])
    STATE.update(before=before,backup=backup.relative_to(ROOT).as_posix(),stage='checkpointed')
    STATE['checkpoint']=write('source_room_checkpoint',dict(status='READ_ONLY_COMPLETE_ROOM_CHECKPOINT',manifest_sha256=MANIFEST_SHA,tool_sha256=LOADED_TOOL_SHA256,backup=STATE['backup'],map_hash=STATE['current_hash'],snapshot=before,protected=651,assets=39,tested_source=10))
    print('SOURCE_ROOM_CHECKPOINT',STATE['checkpoint'])
def gate():
    s=STATE;assert s and LOADED_TOOL_SHA256==sha(__file__)
    g=read(DOC/'SOURCE_ROOM_SAVE_GATE_R18.json')
    assert g['status']=='APPROVED_EXACT_COMPLETE_ROOM_SOURCE_ADOPTION' and g['tool_sha256']==LOADED_TOOL_SHA256 and g['manifest_sha256']==MANIFEST_SHA and g['checkpoint']==s['checkpoint']
    assert sha(ROOT/g['full_room_review']['file'])==g['full_room_review']['sha256']
    assert sha(ROOT/s['backup'])==s['m']['source_map_sha256_before'];return g
def component(label,mesh=None):
    u=_u();actors=[a for a in u.GameplayStatics.get_all_actors_of_class(world(),u.Actor) if a.get_actor_label()==label];a,=actors
    if mesh:
        c,=[c for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent) if package(c.static_mesh)==mesh];return c
    c,=a.get_components_by_class(u.PointLightComponent);return c
def _text(r):return (ROOT/r['file']).read_text()
def semantic_snapshot(value):
    if isinstance(value,dict):
        if set(value)=={'file','sha256'}:return {'sha256':value['sha256']}
        return {k:semantic_snapshot(v) for k,v in value.items()}
    if isinstance(value,list):return [semantic_snapshot(v) for v in value]
    return value
def _allowed_raw(text,label,m,actor_name,component_name=None):
    # Only known derived HISM build caches and NEW instance records are removed.
    append=next((r for r in m['append_hism_instances'] if r['actor_label']==label),None)
    lines=[]
    for line in text.splitlines():
        key=line.strip().split('=',1)[0]
        if append and re.fullmatch(r'(SortedInstances\(\d+\)|NumBuiltInstances|BuiltInstanceBounds|UnbuiltInstanceBounds|UnbuiltInstanceBoundsList\([012]\)|CacheMeshExtendedBounds|InstanceCountToRender|InstanceReorderTable\(\d+\)|CachedBounds\(\d+\))',key):continue
        binding=next((r for r in m['material_bindings'] if r['actor_label']==label and key=='OverrideMaterials('+str(r['slot'])+')'),None)
        if binding:
            wanted='OverrideMaterials('+str(binding['slot'])+')="/Script/Engine.'+OVERRIDE_CLASSES[label]+"'"+full(binding['after'])+"'\""
            assert line.strip()==wanted,('Unexpected tracked material override record',label,line)
            continue
        if append and re.fullmatch(r'PerInstanceSMData\([234]\)',key):continue
        lines.append(line)
    return '\n'.join(lines)
def compare_delta(after):
    s=STATE;m=s['m'];b=s['before'];u=_u();base,core=s['source'].dependencies()
    added={a['label'] for a in m['new_actors']};old_by={a['label']:n for n,a in b['roster'].items()};new_by={a['label']:n for n,a in after['roster'].items()}
    assert len(new_by)==len(after['roster'])==41 and set(new_by)==set(old_by)|added
    expected=copy.deepcopy(b['hisms'])
    for r in m['append_hism_instances']:
        c=component(r['actor_label'],r['mesh']);p=c.get_path_name();assert len(expected[p]['instances'])==r['before_count']==2
        assert c.get_instance_count()==5
        for i,pose in enumerate(r['add_local_poses'],2):assert core._near(c.get_instance_transform(i,world_space=False),transform(pose))
        expected[p]['instances']+=after['hisms'][p]['instances'][2:]
    for r in m['material_bindings']:
        c=component(r['actor_label'],r['mesh']);p=c.get_path_name();assert expected[p]['materials'][r['slot']]==r['before']
        expected[p]['materials'][r['slot']]=r['after'];assert len(expected[p]['instances'])==r['instance_count']==1
    assert expected==after['hisms'] and sum(len(r['instances']) for r in expected.values())==4369
    source_actor=s['source'].target(world()).get_outer();source_name=source_actor.get_name()
    for label,name in old_by.items():
        old=b['roster'][name];new=after['roster'][new_by[label]];assert name==new_by[label]
        assert all(old[k]==new[k] for k in ('label','type','tags','pose','hidden','folder'))
        assert set(old['components'])==set(new['components'])
        pairs=[(old['raw'],new['raw'],None)]+[(c['raw'],new['components'][cn]['raw'],cn) for cn,c in old['components'].items()]
        for prior,current,cn in pairs:
            t=_text(prior);actual=_text(current)
            if name==source_name:t=t.replace(full(m['forage_profile']['before']),full(m['forage_profile']['after']))
            for r in m['material_bindings']:
                if r['actor_label']==label:t=t.replace(full(r['before']),full(r['after']))
            for r in m['source_light_intensities']:
                if r['actor_label']==label:t=t.replace('Intensity='+format(r['before'],'.6f'),'Intensity='+format(r['after'],'.6f'))
            assert _allowed_raw(t,label,m,name,cn)==_allowed_raw(actual,label,m,name,cn),('Unexpected original raw change',label,cn)
    assert after['profile']==m['forage_profile']['after'] and _text(b['script']).replace(full(m['forage_profile']['before']),full(m['forage_profile']['after']))==_text(after['script'])
    for label,row in b['lights'].items():
        expected=copy.deepcopy(row)
        for r in m['source_light_intensities']:
            if r['actor_label']==label:assert row['intensity']==r['before'];expected['intensity']=r['after']
        assert after['lights'][label]==expected
    assert source_actor.get_editor_property('actor_guid').export_text()==m['forage_profile']['source_actor_guid']
    for r in m['new_actors']:
        a,=[a for a in u.GameplayStatics.get_all_actors_of_class(world(),u.Actor) if a.get_actor_label()==r['label']]
        assert a.get_class().get_path_name()==r['actor_class'] and core._near(a.get_actor_transform(),transform(r['pose']))
        assert [str(t) for t in a.tags]==[m['owner']] and str(a.get_folder_path())==m['folder']
        assert r['mobility']=='MOVABLE' and a.root_component.get_editor_property('mobility')==u.ComponentMobility.MOVABLE
        if 'mesh' in r:
            c=a.static_mesh_component;assert package(c.static_mesh)==r['mesh'] and [package(v) for v in c.get_materials()]==r['materials']
            assert c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION and str(c.get_collision_profile_name())=='NoCollision' and c.cast_shadow==r['cast_shadow']
        else:
            c=component(r['label']);v=r['light'];assert str(c.get_editor_property('intensity_units'))==v['units']
            assert c.intensity==v['intensity'] and c.attenuation_radius==v['radius'] and rgba(c.light_color)==v['color_rgba']
            assert all(c.get_editor_property(k)==v[k] for k in ('source_radius','source_length','soft_source_radius'))
            assert c.use_inverse_squared_falloff==v['inverse_squared'] and c.cast_shadows==v['cast_shadows']
            if 'inner_cone' in v:assert c.inner_cone_angle==v['inner_cone'] and c.outer_cone_angle==v['outer_cone']
def restore_preferences():
    p=STATE['prefs'];p['editor'].set_editor_property('bAutoSaveEnable',p['autosave']);p['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave',p['cook'])
    now=STATE['source'].settings();assert now['autosave']==p['autosave'] and now['cook']==p['cook']
def admit():
    s=STATE;m=s['m'];core=s['source'].dependencies()[1]
    poses=[r['pose'] for r in m['new_actors']]+[p for r in m['append_hism_instances'] for p in r['add_local_poses']]
    assert len(poses)==19 and all(core._pose(transform(p))==p for p in poses)
    for r in m['new_actors']:
        assert r['mobility']=='MOVABLE'
        if 'light' in r:assert rgba(color(r['light']['color_rgba']))==r['light']['color_rgba']
    for r in m['append_hism_instances']:
        c=component(r['actor_label'],r['mesh']);assert c.get_instance_count()==r['before_count']==2 and str(c.get_collision_profile_name())=='NoCollision'
    for r in m['material_bindings']:
        c=component(r['actor_label'],r['mesh']);assert c.get_instance_count()==r['instance_count']==1 and package(c.get_material(r['slot']))==r['before']
        assert _u().load_asset(r['after']).get_class().get_path_name()=='/Script/Engine.'+OVERRIDE_CLASSES[r['actor_label']]
    for r in m['source_light_intensities']:
        c=component(r['actor_label']);assert c.intensity==r['before'] and rgba(c.light_color)==r['color_before_rgba']==r['color_after_rgba']
    target=s['source'].target(world());assert package(target.get_editor_property('ForagePresentation'))==m['forage_profile']['before']
    assert target.get_outer().get_editor_property('actor_guid').export_text()==m['forage_profile']['source_actor_guid']
def stage():
    u=_u();s=STATE;assert s['stage']=='checkpointed';gate();guard();assert s['source'].dirty()==dict(maps=[],content=[])
    admit()
    current=snapshot('pre_stage');assert semantic_snapshot(current)==semantic_snapshot(s['before']),'Checkpoint serialization changed'
    all_poses=[r['pose'] for r in s['m']['new_actors']]+[p for r in s['m']['append_hism_instances'] for p in r['add_local_poses']]
    core=s['source'].dependencies()[1];assert len(all_poses)==19 and all(core._pose(transform(p))==p for p in all_poses)
    p=s['prefs'];p['editor'].set_editor_property('bAutoSaveEnable',False);p['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave',type(p['cook']).DISABLE)
    protected=s['source'].settings();assert protected['autosave'] is False and protected['cook']==type(p['cook']).DISABLE
    s['stage']='staging';m=s['m'];ea=u.get_editor_subsystem(u.EditorActorSubsystem)
    for r in m['append_hism_instances']:
        c=component(r['actor_label'],r['mesh']);assert c.get_instance_count()==r['before_count'];c.get_owner().modify();c.modify()
        for pose in r['add_local_poses']:c.add_instance(transform(pose),world_space=False)
    for r in m['material_bindings']:
        c=component(r['actor_label'],r['mesh']);assert package(c.get_material(r['slot']))==r['before'];c.get_owner().modify();c.modify();c.set_material(r['slot'],u.load_asset(r['after']))
    for r in m['source_light_intensities']:
        c=component(r['actor_label']);assert c.intensity==r['before'] and rgba(c.light_color)==r['color_before_rgba'];c.get_owner().modify();c.modify();c.set_intensity(r['after'])
    target=s['source'].target(world());target.modify();target.get_outer().modify();target.set_editor_property('ForagePresentation',u.load_asset(m['forage_profile']['after']))
    for r in m['new_actors']:
        t=transform(r['pose']);a=ea.spawn_actor_from_class(u.load_class(None,r['actor_class']),t.translation,t.rotation.rotator());s['created'].append(a)
        assert a.get_world()==world();a.set_actor_transform(t,False,True);a.set_actor_label(r['label']);a.tags=[u.Name(m['owner'])];a.set_folder_path(u.Name(m['folder']))
        assert r['mobility']=='MOVABLE';a.root_component.set_mobility(u.ComponentMobility.MOVABLE)
        if 'mesh' in r:
            c=a.static_mesh_component;c.set_static_mesh(u.load_asset(r['mesh']));c.set_collision_profile_name('NoCollision');c.set_collision_enabled(u.CollisionEnabled.NO_COLLISION);c.set_cast_shadow(r['cast_shadow'])
            for i,path in enumerate(r['materials']):c.set_material(i,u.load_asset(path))
        else:
            c,=a.get_components_by_class(u.PointLightComponent);v=r['light'];c.set_mobility(u.ComponentMobility.MOVABLE);c.set_editor_property('intensity_units',u.LightUnits.CANDELAS);c.set_intensity(v['intensity']);c.set_attenuation_radius(v['radius']);c.set_editor_property('light_color',color(v['color_rgba']))
            for k in ('source_radius','source_length','soft_source_radius'):c.set_editor_property(k,v[k])
            c.set_editor_property('use_inverse_squared_falloff',v['inverse_squared']);c.set_cast_shadows(v['cast_shadows'])
            if 'inner_cone' in v:c.set_inner_cone_angle(v['inner_cone']);c.set_outer_cone_angle(v['outer_cone'])
    after=snapshot('staged');write('source_room_attempted_delta',dict(status='UNVALIDATED_STAGED_DELTA_READBACK',snapshot=after));compare_delta(after);guard();assert s['source'].dirty()==dict(maps=[s['source'].PACKAGE],content=[])
    s.update(stage='staged',staged=after);print('SOURCE_ROOM_STAGED',write('source_room_staged',dict(status='EXACT_COMPLETE_ROOM_STAGED_UNSAVED',snapshot=after,checkpoint=s['checkpoint'])))
def save():
    u=_u();s=STATE;assert s['stage']=='staged';gate();guard();world();pre=snapshot('pre_save');compare_delta(pre)
    assert s['source'].dirty()==dict(maps=[s['source'].PACKAGE],content=[])
    p=s['source'].settings();assert p['autosave'] is False and p['cook']==type(p['cook']).DISABLE
    assert u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
    s['current_hash']=sha(ROOT/s['m']['source_map_file']);s['stage']='saved_pending_readback';guard()
    assert s['source'].dirty()==dict(maps=[],content=[])
    after=snapshot('saved');compare_delta(after);s.update(saved=after,stage='saved');restore_preferences();s['created'].clear()
    print('SOURCE_ROOM_SAVED',write('source_room_saved',dict(status='COMPLETE_ROOM_SAVED_TWO_UNLOADED_REOPENS_REQUIRED',map_hash=s['current_hash'],checkpoint=s['checkpoint'],snapshot=after,dirty=s['source'].dirty())))
def abort_unsaved():
    """Discard only this owned, unsaved source-room trial; never discard other dirt."""
    u=_u();s=STATE;assert s['stage'] in ('staging','staged')
    assert sha(ROOT/s['m']['source_map_file'])==s['m']['source_map_sha256_before']==s['current_hash']
    guard();assert s['source'].dirty()==dict(maps=[s['source'].PACKAGE],content=[])
    s['created'].clear()
    # Documented native load_map explicitly does not prompt to save the old map.
    other=ROOT/'Content/Mars/Maps/Warrens_VariantC_Mars_MAP.umap';assert other.is_file()
    loaded=u.EditorLoadingAndSavingUtils.load_map(str(other));assert loaded and loaded.get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    guard();assert s['source'].dirty()==dict(maps=[],content=[]);restore_preferences();s['stage']='aborted_unsaved'
    print('SOURCE_ROOM_UNSAVED_TRIAL_DISCARDED',write('source_room_aborted',dict(status='OWNED_UNSAVED_SOURCE_TRIAL_DISCARDED',map_hash=s['current_hash'],dirty=s['source'].dirty())))
def witness_unloaded():
    u=_u();s=STATE;assert s['stage']=='saved' and u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert not u.find_object(None,s['source'].PACKAGE+'.LI_Warrens_Catacomb');guard();assert s['source'].dirty()==dict(maps=[],content=[])
    s['unloads'].append(write('source_room_unloaded_'+str(len(s['unloads'])+1),dict(status='SOURCE_WORLD_ABSENT',map_hash=s['current_hash'])))
def verify_reopen():
    s=STATE;assert len(s['unloads'])==len(s['reopens'])+1;after=snapshot('reopen_'+str(len(s['reopens'])+1));compare_delta(after)
    assert semantic_snapshot(after)==semantic_snapshot(s['saved']),'Saved source serialization changed across unloaded reopen'
    guard();assert s['source'].dirty()==dict(maps=[],content=[])
    s['reopens'].append(write('source_room_reopen_'+str(len(s['reopens'])+1),dict(status='EXACT_COMPLETE_ROOM_UNLOADED_REOPEN',map_hash=s['current_hash'],snapshot=after)))
    print('SOURCE_ROOM_REOPEN',s['reopens'][-1])
