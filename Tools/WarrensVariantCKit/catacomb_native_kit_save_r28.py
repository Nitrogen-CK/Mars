"""Save exactly the reviewed original native Kit map; no staging/import function."""
import copy
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
OUT=RUN/'native_kit_retention_r28'
MAP='/Game/Mars/Environment/WarrensVariantCKit/Maps/WarrensVariantC_KitLibrary_Mars_MAP'
FILE='Content/Mars/Environment/WarrensVariantCKit/Maps/WarrensVariantC_KitLibrary_Mars_MAP.umap'
STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
LOADED=sha(__file__)
def write(name,data):
    p=OUT/(name+'.json');assert not p.exists();p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,indent=2)+'\n');return dict(file=p.relative_to(ROOT).as_posix(),sha256=sha(p))
def guard():
    import unreal as u
    assert Path(u.Paths.project_dir()).resolve()==ROOT.resolve();p=RUN/'baseline_guard_after_blender_libraries_r26.json';assert sha(p)=='a840218a0cbacf93fe36e594f75d76c2d78cfe3e15fe77f00ccf9a36417b86f5';g=read(p);files=g['immutable_guards']|g['collision_hashes'];assert len(files)==651
    if STATE:files[FILE]=STATE['map_sha256']
    assert all(sha(ROOT/p)==h for p,h in files.items());assert all(sha(ROOT/p)==h for p,h in g['post_test_provenance']['source_sha256'].items());a=read(RUN/'candidate_assets_timber_r13.json');assert len(a['assets'])==39 and all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==r['package_sha256'] for p,r in a['assets'].items());return 651
def save(lib,gate_path,gate_sha):
    global STATE
    import unreal as u
    assert STATE is None and LOADED==sha(__file__);assert sha(ROOT/gate_path)==gate_sha;g=read(ROOT/gate_path);s=lib.STATE
    assert g['status']=='APPROVED_NATIVE_KIT_ONLY_SAVE' and g['save_tool_sha256']==LOADED and g['stage_tool_sha256']==lib.LOADED==sha(lib.__file__)=='733c673f671fb4e0a97c6e83075d8d5ac2d18da01b38cc59a7261b1f19421ccc' and g['checkpoint']==s['checkpoint'] and g['export_settle']==s['export_settle']
    assert sha(ROOT/g['review']['file'])==g['review']['sha256'];assert g['post_preview']==s['post_preview_receipt'];assert sha(ROOT/g['post_preview']['file'])==g['post_preview']['sha256'];assert s['stage']=='staged' and s['target']=='KitLibrary' and s['source'].dirty()==dict(maps=[MAP],content=[])
    guard();assert sha(ROOT/s['backup'])==sha(ROOT/FILE)==s['original_sha'];settings=s['source'].settings();assert settings['autosave'] is False and settings['cook']==type(settings['cook']).DISABLE
    before=lib.snapshot('reviewed_pre_save');lib.verify(before);assert set(before['roster'])==set(s['staged']['roster']) and before['hisms']==s['staged']['hisms'];STATE=dict(lib=lib,map_sha256=s['original_sha'],stage='saving',gate=dict(file=gate_path,sha256=gate_sha),reopens=[],backup=s['backup'],before_original=copy.deepcopy(s['first_export_before']))
    try:
        assert u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level();STATE['map_sha256']=sha(ROOT/FILE);STATE['stage']='saved_pending_readback';guard();assert s['source'].dirty()==dict(maps=[],content=[]);after=lib.snapshot('saved');lib.verify(after);STATE['saved']=after;STATE['stage']='saved';s['stage']='saved_native_pending_reopens';STATE['receipt']=write('save',dict(status='NATIVE_KIT_ONLY_SAVED_TWO_REOPENS_PENDING',map_sha256=STATE['map_sha256'],backup=STATE['backup'],gate=STATE['gate'],snapshot=after,first_original_baseline=STATE['before_original'],new_groups=s['expected'],new_other_actors=s['extras'],new_actor_count=len(s['created'])));print('NATIVE_KIT_SAVED',STATE['map_sha256'],STATE['receipt'])
    finally:lib.restore_preferences()
    s['created'].clear()
def unload():
    import unreal as u
    s=STATE;assert s['stage'] in ('saved','reopened');guard();assert s['lib'].STATE['source'].dirty()==dict(maps=[],content=[]);assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None;loaded=u.EditorLoadingAndSavingUtils.load_map(str(ROOT/'Content/Mars/Maps/StationGym_Mars_MAP.umap'));assert loaded and loaded.get_path_name()=='/Game/Mars/Maps/StationGym_Mars_MAP.StationGym_Mars_MAP';u.SystemLibrary.collect_garbage();s['stage']='unload_queued';print('KIT_UNLOAD_QUEUED')
def witness_unloaded():
    import unreal as u
    assert STATE['stage']=='unload_queued';guard();assert u.find_object(None,MAP+'.WarrensVariantC_KitLibrary_Mars_MAP') is None;STATE['stage']='unloaded';print('KIT_WORLD_ABSENT')
def reopen_capture():
    import unreal as u
    s=STATE;assert s['stage']=='unloaded';guard();loaded=u.EditorLoadingAndSavingUtils.load_map(str(ROOT/FILE));assert loaded and loaded.get_path_name()==MAP+'.WarrensVariantC_KitLibrary_Mars_MAP';index=len(s['reopens'])+1;after=s['lib'].snapshot('reopen_'+str(index));before=s['before_original'];assert set(after['roster'])==set(s['saved']['roster']) and set(before['roster'])<set(after['roster'])
    # Every original is compared against its first-export baseline, including the
    # full brush PolyList; no broad export normalization is accepted here.
    for n,r in before['roster'].items():
        a=after['roster'][n];assert all(a[k]==r[k] for k in ('label','type','tags','pose','hidden','folder'));assert a['raw']['sha256']==r['raw']['sha256'],('Original actor changed',n);assert set(a['components'])==set(r['components'])
        for cn,c in r['components'].items():assert a['components'][cn]['raw']['sha256']==c['raw']['sha256'],('Original component changed',n,cn)
    assert after['hisms']==s['saved']['hisms'],'Complete HISM metadata/poses changed'
    raw_pairs=[]
    for n,r in s['saved']['roster'].items():
        if n in before['roster']:continue
        a=after['roster'][n];assert all(a[k]==r[k] for k in ('label','type','tags','pose','hidden','folder'));assert set(a['components'])==set(r['components'])
        for name,prior,current in [('actor',r['raw'],a['raw'])]+[(cn,c['raw'],a['components'][cn]['raw']) for cn,c in r['components'].items()]:
            if prior['sha256']!=current['sha256']:raw_pairs.append(dict(actor=n,component=name,before=prior,after=current))
    if s['reopens']:
        assert len(s['reopens'])==1
        def semantic(v):
            if isinstance(v,dict):return {'sha256':v['sha256']} if set(v)=={'file','sha256'} else {k:semantic(x) for k,x in v.items()}
            if isinstance(v,list):return [semantic(x) for x in v]
            return v
        assert semantic(after)==semantic(s['reopens'][0]['snapshot']),'Second canonical reload differs from first'
    guard();assert s['lib'].STATE['source'].dirty()==dict(maps=[],content=[]);r=write('reopen_'+str(index)+'_unvalidated',dict(status='CANONICAL_NATIVE_KIT_REOPEN_RAW_PAIRS_REVIEW_REQUIRED',map_sha256=s['map_sha256'],all409_original_actor_exports_and_components_exact=True,all211_hism_rows_exact=True,new_only_raw_pairs=raw_pairs,second_exact_first=bool(s['reopens']),snapshot=after));s['reopens'].append(dict(receipt=r,snapshot=after));s['stage']='reopened';print('KIT_REOPEN_CAPTURED',index,len(raw_pairs),r)
