"""One checkpointed source profile reference. Import is inert; save requires review gate."""
import copy
import hashlib
import importlib.util
import json
import shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-forage-props-r04'
PACKAGE='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Catacomb'
MAP='Content/Mars/Maps/Variants/v8c/LI_Warrens_Catacomb.umap'
PROFILE='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02/Forage_R04/DA_CP_ForagePresentation_R01'
TAG='(TagName="Anchor.Mars.Warrens.CatacombHusk")'
STATE=None

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
LOADED_TOOL_SHA256=sha(__file__)

def _u():import unreal;return unreal

def module(name,expected):
    p=ROOT/'Tools/WarrensVariantCKit'/(name+'.py');assert sha(p)==expected
    spec=importlib.util.spec_from_file_location('_r11_'+name,p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def dependencies():
    return (module('cardinal_wall_family_persistent','6efebdb2b3fcb5cdea9aeded6cc0253a6ab40fc2cc4e0ebe965df11ce7233273'),
            module('bank_identity_unreal','4859e7ab71dc9e0a5d93b61511eb759ef741598af4821ba62df69cd8ee014619'))

def write(name,data):
    p=RUN/(name+'.json');assert not p.exists();p.write_text(json.dumps(data,indent=2)+'\n');return dict(file=p.relative_to(ROOT).as_posix(),sha256=sha(p))

def dirty():
    u=_u();return dict(maps=[p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()],content=[p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()])

def guard(map_sha=None):
    g=read(RUN/'baseline_guard_after_forage_tests_r01.json')
    assert sha(RUN/'baseline_guard_after_forage_tests_r01.json')=='0176f1915c85ccca43348c2349639491182c2dedb3cc9d9258ebff97bea12eee'
    guards=g['immutable_guards']|g['collision_hashes'];assert len(guards)==651 and MAP in guards and MAP not in g['collision_hashes']
    if map_sha:guards[MAP]=map_sha
    assert all(sha(ROOT/p)==h for p,h in guards.items()),'Protected file drift'
    assert all(sha(ROOT/p)==h for p,h in g['post_test_provenance']['source_sha256'].items())
    a=read(RUN/'candidate_assets_forage_r04.json');assert sha(RUN/'candidate_assets_forage_r04.json')=='699e915da5fe47493088df1af785b42d6572358a4697c2bd6ac67c03d8a2b0a4'
    assert len(a['assets'])==36 and all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==r['package_sha256'] for p,r in a['assets'].items())
    return guards

def world():
    u=_u();assert Path(u.Paths.project_dir()).resolve()==ROOT.resolve()
    ed=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert ed.get_game_world() is None
    w=ed.get_editor_world();assert w.get_path_name()==PACKAGE+'.LI_Warrens_Catacomb';return w

def target(w):
    u=_u();typ=u.get_type_from_class(u.load_class(None,'/Script/Angelscript.Mars_Anchor_Forage_EntityScript'))
    found=[o for o in u.ObjectIterator(typ) if not o.get_name().startswith('Default__') and isinstance(o.get_outer(),u.Actor) and o.get_outer().get_world()==w]
    assert len(found)==1 and found[0].get_editor_property('AnchorId').export_text()==TAG
    o=found[0];assert o.get_outer().get_class().get_path_name()=='/Script/CkEntitySpawner.Ck_EntitySpawner_UE'
    assert o.get_path_name().startswith(PACKAGE+'.LI_Warrens_Catacomb:PersistentLevel.')
    return o

def snapshot(label):
    u=_u();w=world();o=target(w);base,core=dependencies();folder=RUN/'source_profile_r11'/label;assert not folder.exists()
    roster,hisms=base._roster(u,core,w,folder)
    script=base._export(u,o,folder/'forage_script.t3d');profile=o.get_editor_property('ForagePresentation')
    return dict(world=w.get_path_name(),target=o.get_path_name(),actor=o.get_outer().get_name(),anchor_id=TAG,
                profile=profile.get_path_name() if profile else None,script=script,roster=roster,hisms=hisms)

def stripped(record):
    text=(ROOT/record['file']).read_text();return [s for s in text.splitlines() if not s.lstrip().startswith('ForagePresentation=')]

def compare(before,after,profile_changed=False):
    assert all(before[k]==after[k] for k in ('world','target','actor','anchor_id'))
    if profile_changed:
        assert before['profile'] is None and after['profile']==PROFILE+'.DA_CP_ForagePresentation_R01'
        assert stripped(before['script'])==stripped(after['script'])
    else:assert before['profile']==after['profile'] and before['script']['sha256']==after['script']['sha256']
    assert before['hisms']==after['hisms'],'HISM semantic drift'
    assert set(before['roster'])==set(after['roster'])
    for name,old in before['roster'].items():
        new=after['roster'][name]
        for k in ('label','type','tags','pose','hidden','folder'):assert old[k]==new[k],(name,k)
        if profile_changed and name==before['actor']:assert stripped(old['raw'])==stripped(new['raw'])
        else:assert old['raw']['sha256']==new['raw']['sha256'],('actor raw drift',name)
        assert set(old['components'])==set(new['components'])
        for cname,c in old['components'].items():
            d=new['components'][cname];assert c['type']==d['type'] and c['raw']['sha256']==d['raw']['sha256'],('component raw drift',name,cname)

def settings():
    u=_u();ed=u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'));j=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'))
    return dict(editor=ed,jolt=j,autosave=ed.get_editor_property('bAutoSaveEnable'),cook=j.get_editor_property('_AutoCookStaticWorldOnLevelSave'))

def restore_preferences():
    s=STATE;assert s and dirty()==dict(maps=[],content=[])
    p=s['prefs'];p['editor'].set_editor_property('bAutoSaveEnable',p['autosave']);p['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave',p['cook'])
    n=settings();assert n['autosave']==p['autosave'] and n['cook']==p['cook'];s['protected']=False

def checkpoint():
    global STATE
    assert STATE is None and dirty()==dict(maps=[],content=[]);world();guards=guard()
    folder=RUN/'source_profile_r11';folder.mkdir(exist_ok=False)
    backup=folder/'LI_Warrens_Catacomb_before.umap';assert not backup.exists();shutil.copy2(ROOT/MAP,backup)
    assert sha(backup)==guards[MAP]=='397008aab08985aa0870ccccdc292068f6b064dc0360b7f095b57ef1a05a7aae'
    before=snapshot('before');assert before['profile'] is None;guard();assert dirty()==dict(maps=[],content=[])
    prefs=settings();STATE=dict(before=before,backup=backup.relative_to(ROOT).as_posix(),map_before=guards[MAP],prefs=prefs,protected=False,stage='checkpointed',unloads=[],reopens=[])
    result=dict(status='READ_ONLY_SOURCE_CHECKPOINTED',backup=STATE['backup'],map_sha256=guards[MAP],before=before,tool_sha256=LOADED_TOOL_SHA256,guard_count=len(guards),asset_count=36,source_count=10,autosave=prefs['autosave'],cook=str(prefs['cook']),dirty=dirty())
    receipt=write('source_profile_checkpoint_r11',result);STATE['checkpoint']=receipt;print('SOURCE_CHECKPOINT',receipt);return receipt

def gate():
    s=STATE;assert s and LOADED_TOOL_SHA256==sha(__file__)
    p=DOC/'SOURCE_PROFILE_SAVE_GATE_R11.json';g=read(p)
    assert g['status']=='APPROVED_ONE_FIELD_SOURCE_PROFILE_VALIDATION' and g['tool_sha256']==LOADED_TOOL_SHA256 and g['checkpoint']==s['checkpoint']
    assert sha(ROOT/s['backup'])==s['map_before'];return g

def stage():
    u=_u();s=STATE;assert s and s['stage']=='checkpointed';gate();guard();assert dirty()==dict(maps=[],content=[])
    current=snapshot('pre_stage');compare(s['before'],current);p=s['prefs'];s['protected']=True
    p['editor'].set_editor_property('bAutoSaveEnable',False);p['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave',type(p['cook']).DISABLE)
    assert settings()['autosave'] is False and settings()['cook']==type(p['cook']).DISABLE
    o=target(world());o.modify();o.get_outer().modify();o.set_editor_property('ForagePresentation',_u().load_asset(PROFILE))
    after=snapshot('staged');compare(s['before'],after,True);guard();assert dirty()==dict(maps=[PACKAGE],content=[])
    s.update(stage='staged',staged=after);print('SOURCE_STAGED',write('source_profile_staged_r11',dict(status='ONLY_PROFILE_REFERENCE_CHANGED_UNSAVED',snapshot=after,checkpoint=s['checkpoint'],dirty=dirty())))

def save():
    u=_u();s=STATE;assert s and s['stage']=='staged';gate();world();guard()
    pre=snapshot('pre_save');compare(s['staged'],pre);assert dirty()==dict(maps=[PACKAGE],content=[])
    p=settings();assert p['autosave'] is False and p['cook']==type(p['cook']).DISABLE
    # Sole dirty source LI; no SaveAll, Main save, cook, mesh or geometry mutation.
    assert u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
    s['map_after']=sha(ROOT/MAP);s['stage']='saved_pending_verification'
    assert s['map_after']!=s['map_before'];guard(s['map_after']);assert dirty()==dict(maps=[],content=[])
    saved=snapshot('saved');compare(s['before'],saved,True);compare(s['staged'],saved)
    s['saved']=saved;s['stage']='saved';restore_preferences()
    prior=read(RUN/'baseline_guard_after_forage_tests_r01.json');prior['immutable_guards'][MAP]=s['map_after']
    prior['source_profile_validation_r11']=dict(predecessor='baseline_guard_after_forage_tests_r01.json',predecessor_sha256='0176f1915c85ccca43348c2349639491182c2dedb3cc9d9258ebff97bea12eee',checkpoint=s['checkpoint'],map_before=s['map_before'],map_after=s['map_after'],provisional=True)
    successor=write('baseline_guard_after_source_profile_r11',prior)
    print('SOURCE_SAVED',write('source_profile_saved_r11',dict(status='PROVISIONAL_ONE_FIELD_SOURCE_PROFILE_SAVED_REOPENS_REQUIRED',snapshot=saved,checkpoint=s['checkpoint'],map_before=s['map_before'],map_after=s['map_after'],successor_guard=successor,other_protected=650,collision_files=54,assets=36,tested_source=10,dirty=dirty(),preferences_restored=True)))

def witness_unloaded():
    u=_u();s=STATE;assert s and s['stage']=='saved';assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert not u.find_object(None,PACKAGE+'.LI_Warrens_Catacomb'),'Source world still resident'
    typ=u.get_type_from_class(u.load_class(None,'/Script/Angelscript.Mars_Anchor_Forage_EntityScript'))
    assert not [o.get_path_name() for o in u.ObjectIterator(typ) if o.get_path_name().startswith(PACKAGE+'.')]
    guard(s['map_after']);assert dirty()==dict(maps=[],content=[])
    record=dict(status='ORIGINAL_SOURCE_WORLD_AND_ARCHETYPE_ABSENT',world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world().get_path_name(),map_sha256=s['map_after'])
    s['unloads'].append(write('source_profile_unloaded_'+str(len(s['unloads'])+1)+'_r11',record));print('UNLOADED',s['unloads'][-1])

def verify_reopen():
    s=STATE;assert s and len(s['unloads'])==len(s['reopens'])+1
    index=len(s['reopens'])+1;after=snapshot('reopen_'+str(index));compare(s['saved'],after);compare(s['before'],after,True)
    guard(s['map_after']);assert dirty()==dict(maps=[],content=[])
    r=write('source_profile_reopen_'+str(index)+'_r11',dict(status='ONE_FIELD_SOURCE_SAVE_EXACT_REOPEN',snapshot=after,unloaded=s['unloads'][-1],map_sha256=s['map_after'],dirty=dirty()))
    s['reopens'].append(r);print('REOPEN',r)
