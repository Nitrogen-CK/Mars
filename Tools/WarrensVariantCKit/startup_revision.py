"""Exact-roster C placed-pickup replacement. Never reapplies map geometry."""
import hashlib
import json
import sys
from pathlib import Path
import unreal as u

ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024'
CP=RUN/'StartupCheckpoint'
sys.path.insert(0,str(ROOT/'Tools/LevelDesign/anchor_plans'))
import placed_pickups
import gameplay_revision as helper
EA=u.get_editor_subsystem(u.EditorActorSubsystem)
ED=u.get_editor_subsystem(u.UnrealEditorSubsystem)
LES=u.get_editor_subsystem(u.LevelEditorSubsystem)
OWNER='Mars.WarrensC.StartupPickup.20261024'


def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def validate_preflight():
    report=read(RUN/'startup-summary.json')
    assert report['errors']==[] and report['fixture_count']==34
    assert len(report['checks'])==34
    assert sha(RUN/'startup-manifest.json')==report['generated_manifest_sha256']
    for rel,expected in report['inputs_sha256'].items():assert sha(ROOT/rel)==expected,'Preflight source changed: '+rel
    assert len(report['non_c_output_comparison'])==2
    assert all(row['equal'] and not row['placed_pickup_proxy_present'] for row in report['non_c_output_comparison'])
    return report


def context(tile):
    validate_preflight()
    m=read(RUN/'startup-manifest.json')
    assert m['map']=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'
    assert len(m['placedPickupStartup']['fixtures'])==34 and len(m['tiles'])==11
    spec=next((t for t in m['tiles'] if t['id']==tile),None)
    path='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP' if tile is None else '/Game/Mars/Maps/Variants/v8c/'+spec['asset']
    assert ED.get_editor_world().get_path_name().split('.')[0]==path,'Guarded load '+path
    assert ED.get_game_world() is None
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
    assert not u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
    disk=ROOT/('Content/'+path.removeprefix('/Game/')+'.umap')
    rel=disk.relative_to(ROOT).as_posix()
    receipt=RUN/('startup_applied_'+str(tile)+'.json')
    expected=read(receipt)['after_sha256'] if receipt.exists() else read(CP/'manifest.json')[rel]['sha256']
    assert sha(disk)==expected,'Unexpected package delta '+rel
    return m,path,disk,receipt,([70,55,0] if tile is None else spec['pivot'])


def scalar(value):
    return value.export_text() if hasattr(value,'export_text') else value


def inspect(tile):
    m,path,disk,receipt,pivot=context(tile)
    assert not receipt.exists(),'Do not replace the already-owned proxies'
    wanted=[r for r in m['entities'] if 'placedPickupOriginal' in r and r['placedPickupOriginal']['tile']==tile]
    originals=[]
    for a in EA.get_all_level_actors():
        if not a.get_path_name().startswith(path+'.'):continue
        try:s=a.get_editor_property('_EntityScript')
        except Exception:continue
        if s and placed_pickups.item_kind(s.get_class().get_name()):originals.append((a,s))
    assert len(originals)==len(wanted),(tile,len(originals),len(wanted))
    rows=[]
    for row in wanted:
        old=row['placedPickupOriginal']
        # Three explicitly reviewed placement corrections: key atop plinth and
        # two S1 tallow moved out of the wall. Other original poses stay exact.
        at=list(row['placedPickupExistingAt'])
        loc=helper.location(at,pivot)
        found=[(a,s) for a,s in originals if s.get_class().get_name()==old['cls'] and (a.get_actor_location()-loc).length()<.05]
        assert len(found)==1,(old,found)
        a,s=found[0]
        assert (a.get_actor_scale3d()-u.Vector(1,1,1)).length()<1e-5
        assert max(abs(v) for v in a.get_actor_rotation().to_tuple())<1e-5
        assert (s.get_editor_property('SpawnTransform').translation-loc).length()<.05
        definition=s.get_editor_property('Definition')
        assert definition and definition.get_path_name()==row['props']['Definition']['asset']
        cdo=u.get_default_object(s.get_class())
        checked={}
        for key in ('Mode','AttachTo','AttachOffset','SourceItem','SourceInventory','LaunchVelocity','AngularVelocityDeg','ArriveFrom'):
            v,d=scalar(s.get_editor_property(key)),scalar(cdo.get_editor_property(key))
            assert v==d,('Custom spawner state must not be discarded',a.get_actor_label(),key,v,d)
            checked[key]=str(v)
        rows.append(dict(id=placed_pickups.fixture_id(row),label=a.get_actor_label(),object=a.get_path_name(),
            cls=old['cls'],tile=tile,local_at=list(a.get_actor_location().to_tuple()),
            tags=[str(t) for t in a.tags],folder=str(a.get_folder_path()),definition=definition.get_path_name(),checked_defaults=checked))
    assert len({r['label'] for r in rows})==len(rows)
    result=dict(map=path,sha256=sha(disk),fixtures=rows)
    (RUN/('startup_roster_'+str(tile)+'.json')).write_text(json.dumps(result,indent=2))
    print('STARTUP_ROSTER',tile,len(rows))
    return result


def collision_guard():
    baseline=read(CP/'collision_hashes.json')
    assert len(baseline)>=54
    directories=(ROOT/'Content/CkJoltData/Mars/Maps/Warrens_VariantC_Mars_MAP',
                 ROOT/'Content/CkJoltData/Mars/Maps/Variants/v8c')
    current={p.relative_to(ROOT).as_posix() for directory in directories for p in directory.rglob('*') if p.is_file()}
    assert current==set(baseline),'Collision file roster changed'
    for rel,expected in baseline.items():assert sha(ROOT/rel)==expected,'Collision data changed '+rel
    return len(baseline)


def verify_definition_bounds():
    bounds=read(ROOT/'Tools/LevelDesign/anchor_plans/data/warrens_v8c_pickup_bounds.json')
    for name,record in bounds.items():
        definition=u.load_asset(record['definition'])
        assert definition,name
        presentation=[t for t in definition.get_editor_property('_ItemTraits') if 'Presentation' in t.get_class().get_name()]
        assert len(presentation)==1,name
        visual=presentation[0].get_editor_property('Visual')
        mesh=visual.get_editor_property('Mesh')
        assert mesh and mesh.get_path_name()==record['mesh']
        box=mesh.get_bounding_box()
        for value,expected in ((visual.get_editor_property('MeshScale').to_tuple(),record['scale']),
                               (box.min.to_tuple(),record['min']),(box.max.to_tuple(),record['max'])):
            assert all(abs(a-b)<1e-5 for a,b in zip(value,expected)),('Measured asset bounds changed',name)


def save_entity_only():
    collision_guard()
    cls=u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    settings=u.get_default_object(cls)
    previous=settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    try:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave',type(previous).DISABLE)
        assert LES.save_current_level()
    finally:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave',previous)
    assert settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')==previous
    collision_guard()


def apply(tile):
    m,path,disk,receipt,pivot=context(tile)
    if receipt.exists():return read(receipt)
    rosters=[read(RUN/('startup_roster_'+str(t)+'.json')) for t in (None,'Catacomb','Brineworks','Waterworks-W')]
    for target,roster in zip((None,'Catacomb','Brineworks','Waterworks-W'),rosters):
        package=ROOT/('Content/'+roster['map'].removeprefix('/Game/')+'.umap')
        prior=RUN/('startup_applied_'+str(target)+'.json')
        expected=read(prior)['after_sha256'] if prior.exists() else roster['sha256']
        assert sha(package)==expected,'An enumerated package changed after roster inspection'
    all_rows=[r for roster in rosters for r in roster['fixtures']]
    assert len(all_rows)==34 and len({r['id'] for r in all_rows})==34
    assert len({r['label'] for r in all_rows})==34,'Preserved fixture labels must be globally unique'
    local=next(r for r in rosters if r['map']==path)
    assert local['sha256']==sha(disk)
    # Revalidate the complete local roster immediately before the first mutation.
    fresh=inspect(tile)
    assert fresh==local
    new_class=u.load_class(None,'/Script/Angelscript.Mars_PlacedPickup_EntityScript')
    assert new_class
    verify_definition_bounds()
    actors={a.get_path_name():a for a in EA.get_all_level_actors()}
    for record in local['fixtures']:assert record['object'] in actors
    for row in m['entities']:
        if 'placedPickupOriginal' in row:assert u.load_asset(row['props']['Definition']['asset'])
    prepared={placed_pickups.fixture_id(row):{key:helper.coerce(value) for key,value in row['props'].items()}
              for row in m['entities'] if 'placedPickupOriginal' in row}
    if tile is None:
        preserved_labels={r['label'] for r in all_rows}
        local_objects={r['object'] for r in local['fixtures']}
        assert not any(a.get_actor_label() in preserved_labels and a.get_path_name() not in local_objects
                       for a in actors.values() if a.get_path_name().startswith(path+'.')),'Destination label collision'
    collision_guard()
    for record in local['fixtures']:assert EA.destroy_actor(actors[record['object']])
    added=[]
    if tile is None:
        records={r['id']:r for r in all_rows}
        for row in m['entities']:
            if 'placedPickupOriginal' not in row:continue
            record=records[placed_pickups.fixture_id(row)]
            a=EA.spawn_actor_from_object(new_class,helper.location(row['at'],pivot),u.Rotator())
            assert a
            a.set_actor_label(record['label'])
            a.tags=[u.Name(t) for t in record['tags']+[OWNER]]
            a.set_folder_path(record['folder'])
            s=a.get_editor_property('_EntityScript')
            for key,value in prepared[record['id']].items():s.set_editor_property(key,value)
            assert s.get_editor_property('FixtureId')==u.Name(row['props']['FixtureId'])
            added.append(record['id'])
    save_entity_only()
    result=dict(map=path,removed=len(local['fixtures']),added=added,after_sha256=sha(disk),
        collision_data_hashes_preserved=collision_guard(),auto_cook_setting_restored=True,
        boundary='Entity-only saved replacement; runtime retention/pickup and packaged collision are separate gates.')
    receipt.write_text(json.dumps(result,indent=2));print('STARTUP_APPLIED',json.dumps(result))
    return result


def verify_saved(tile):
    m,path,disk,receipt,pivot=context(tile)
    assert receipt.exists()
    proxies=[]
    originals=[]
    for a in EA.get_all_level_actors():
        if not a.get_path_name().startswith(path+'.'):continue
        try:s=a.get_editor_property('_EntityScript')
        except Exception:continue
        if not s:continue
        name=s.get_class().get_name()
        if placed_pickups.item_kind(name):originals.append(a.get_actor_label())
        if name=='Mars_PlacedPickup_EntityScript':proxies.append((a,s))
    assert originals==[],('Legacy pickups remain',tile,originals)
    assert len(proxies)==(34 if tile is None else 0),(tile,len(proxies))
    if tile is None:
        rows={r['props']['FixtureId']:r for r in m['entities'] if 'placedPickupOriginal' in r}
        assert {str(s.get_editor_property('FixtureId')) for a,s in proxies}==set(rows)
        for a,s in proxies:
            row=rows[str(s.get_editor_property('FixtureId'))]
            assert (a.get_actor_location()-helper.location(row['at'],pivot)).length()<.05
            assert s.get_editor_property('Definition').get_path_name()==row['props']['Definition']['asset']
            assert OWNER in [str(t) for t in a.tags]
    result=dict(map=path,proxies=len(proxies),legacy_pickups=originals,
                sha256=sha(disk),collision_data_hashes_preserved=collision_guard())
    (RUN/('startup_verified_'+str(tile)+'.json')).write_text(json.dumps(result,indent=2))
    print('STARTUP_SAVED_ROSTER_VERIFIED',json.dumps(result))
    return result
