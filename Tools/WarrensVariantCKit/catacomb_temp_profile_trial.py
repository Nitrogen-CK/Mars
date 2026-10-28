"""One TEMP editor-instance archetype override, with explicit restoration and no map save."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-forage-props-r04'
DEST='/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02/Forage_R04'
PROFILE=DEST+'/DA_CP_ForagePresentation_R01';STATE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
LOADED_TOOL_SHA256=sha(__file__)
def _u():import unreal;return unreal
def _write(name,data):
    path=RUN/(name+'.json');assert not path.exists();path.write_text(json.dumps(data,indent=2)+'\n');return sha(path)
def guard():
    g=read(RUN/'baseline_guard_after_forage_tests_r01.json');assert sha(RUN/'baseline_guard_r02.json')==g['post_test_provenance']['predecessor_sha256']
    assert all(sha(ROOT/p)==h for p,h in g['post_test_provenance']['source_sha256'].items())
    guards=g['immutable_guards']|g['collision_hashes'];assert len(guards)==651 and all(sha(ROOT/p)==h for p,h in guards.items())
    assets=read(RUN/'candidate_assets_forage_r04.json');assert len(assets['assets'])==36
    assert all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==r['package_sha256'] for p,r in assets['assets'].items())
    return guards
def settings():
    u=_u();editor=u.get_default_object(u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings'));jolt=u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'))
    return dict(editor=editor,jolt=jolt,autosave=editor.get_editor_property('bAutoSaveEnable'),cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave'))
def placements():
    u=_u();world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world();kind=u.get_type_from_class(u.load_class(None,'/Script/Angelscript.Mars_Anchor_Forage_EntityScript'));rows={};objects={}
    for o in u.ObjectIterator(kind):
        if o.get_name().startswith('Default__'):continue
        actor=o.get_outer()
        if not isinstance(actor,u.Actor) or actor.get_world()!=world:continue
        profile=o.get_editor_property('ForagePresentation');path=o.get_path_name();assert path not in rows
        rows[path]=dict(path=path,outer=actor.get_path_name(),actor_class=actor.get_class().get_path_name(),label=actor.get_actor_label(),world=world.get_path_name(),level=actor.get_level().get_path_name(),pose=actor.get_actor_transform().export_text(),anchor_id=o.get_editor_property('AnchorId').export_text(),profile=profile.get_path_name() if profile else None);objects[path]=o
    return rows,objects
def export_scripts(label):
    u=_u();rows,objects=placements();folder=RUN/'forage_temp_profile_r10'/label;assert not folder.exists();folder.mkdir(parents=True)
    exports={}
    for index,path in enumerate(sorted(rows)):
        out=folder/(str(index)+'.t3d');task=u.AssetExportTask()
        for k,v in dict(object=objects[path],exporter=u.ObjectExporterT3D(),filename=str(out),automated=True,prompt=False,selected=False,replace_identical=False,use_file_archive=False,write_empty_files=False).items():task.set_editor_property(k,v)
        assert u.Exporter.run_asset_export_task(task) and not list(task.get_editor_property('errors')) and out.is_file()
        exports[path]=dict(file=out.relative_to(ROOT).as_posix(),sha256=sha(out))
    return rows,exports
def assert_dirty_scope():
    u=_u();s=STATE;assert s
    dirty=[p.get_path_name() for p in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
    assert not dirty or dirty==[s['temp_package']],dirty
    assert u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    return dirty
def preflight():
    global STATE
    u=_u();assert STATE is None and Path(u.Paths.project_dir()).resolve()==ROOT.resolve()
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world();assert world.get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    expected={r['path']:r for r in read(RUN/'forage_editor_placement_identity_r01.json')};rows,exports=export_scripts('before');assert rows==expected and len(rows)==7 and all(r['profile'] is None for r in rows.values())
    key,=[p for p in rows if 'LI_Warrens_Catacomb_LevelInstance_' in p];row=rows[key];assert key.startswith('/Temp/Game/Mars/Maps/Variants/v8c/LI_Warrens_Catacomb_LevelInstance_')
    assert row['anchor_id']=='(TagName="Anchor.Mars.Warrens.CatacombHusk")'
    assert row['actor_class']=='/Script/CkEntitySpawner.Ck_EntitySpawner_UE'
    assert (placements()[1][key].get_outer().get_actor_location()-u.Vector(-9600,1900,0)).length()<.001
    prefs=settings();STATE=dict(key=key,before=rows,exports=exports,prefs=prefs,temp_package=row['level'].split('.',1)[0],assigned=False,protected=False,runtime_verified=False)
    guard();record=dict(status='READ_ONLY_TEMP_PROFILE_PREFLIGHT',target=row,placements=rows,exports=exports,autosave=prefs['autosave'],cook=str(prefs['cook']),aa=u.SystemLibrary.get_console_variable_int_value('r.AntiAliasingMethod'),assets_sha256=sha(RUN/'candidate_assets_forage_r04.json'),source_identity_sha256=sha(RUN/'forage_editor_placement_identity_r01.json'))
    print('TEMP_PROFILE_PREFLIGHT',_write('forage_temp_profile_preflight_r10',record));return record
def stage():
    u=_u();s=STATE;assert s and not s['assigned'] and not s['protected']
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    gate=read(DOC/'NATIVE_ROOM_TRIAL_GATE_R10.json');assert gate['status']=='APPROVED_FOR_REVERSIBLE_COMPLETE_ROOM_TRIAL' and gate['temp_helper_sha256']==LOADED_TOOL_SHA256==sha(__file__)
    assert gate['temp_preflight_sha256']==sha(RUN/'forage_temp_profile_preflight_r10.json') and gate['asset_inventory_sha256']==sha(RUN/'candidate_assets_forage_r04.json')
    rows,objects=placements();assert rows==s['before'];guard();assert_dirty_scope();prefs=s['prefs']
    try:
        s['protected']=True;prefs['editor'].set_editor_property('bAutoSaveEnable',False);prefs['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave',type(prefs['cook']).DISABLE)
        now=settings();assert now['autosave'] is False and now['cook']==type(prefs['cook']).DISABLE
        s['assigned']=True;objects[s['key']].set_editor_property('ForagePresentation',u.load_asset(PROFILE))
        after,exports=export_scripts('staged');expected=json.loads(json.dumps(s['before']));expected[s['key']]['profile']=PROFILE+'.DA_CP_ForagePresentation_R01';assert after==expected
        for path,before in s['exports'].items():
            old=(ROOT/before['file']).read_text();new=(ROOT/exports[path]['file']).read_text()
            if path==s['key']:
                strip=lambda text:[line for line in text.splitlines() if not line.lstrip().startswith('ForagePresentation=')]
                assert strip(old)==strip(new),'Other serialized script fields changed'
            else:assert old==new,'Unrelated forage script export changed'
        guard();print('TEMP_PROFILE_STAGED',_write('forage_temp_profile_staged_r10',dict(status='ONE_TEMP_ARCHETYPE_PROFILE_ASSIGNED',target=after[s['key']],exports=exports,dirty_maps=assert_dirty_scope(),boundary='Temporary streamed editor clone only; no source map save, seed/table changes or runtime patch.')))
    except Exception:
        # The caller's unconditional cleanup must also stop PIE and finalize/reload the TEMP clone.
        # Keep protections on until that cleanup has proved the editor clean.
        s['failed']=True;restore_value();raise
def verify_runtime():
    u=_u();s=STATE;assert s and s['assigned'];world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world();assert world and 'UEDPIE_0_Warrens_VariantC_Mars_MAP' in world.get_path_name()
    source_type=u.get_type_from_class(u.load_class(None,'/Script/Angelscript.Mars_ForageSource_EntityScript'));matches=[]
    for o in u.ObjectIterator(source_type):
        if o.get_name().startswith('Default__') or o.get_world()!=world:continue
        context=o.get_editor_property('Anchor')
        if context.get_editor_property('anchor_id').export_text()!=s['before'][s['key']]['anchor_id']:continue
        profile=context.get_editor_property('forage_presentation');assert profile and profile.get_path_name().split('.')[0]==PROFILE,'PIE lost the TEMP profile; do not patch runtime or force a different row'
        matches.append(dict(script=o.get_path_name(),world=o.get_world().get_path_name(),selected_class=o.get_class().get_path_name(),context=context.export_text(),run_seed=context.get_editor_property('run_seed')))
    assert len(matches)==1,('Actual authored candidate must be observable',matches)
    assert matches[0]['selected_class']=='/Script/Angelscript.Mars_ForageCenser_EntityScript','A different authored result needs its own actual evidence; do not pin or replace it'
    expected={DEST+'/Meshes/WVC_Forage_CenserBob_R01_SM':'bob',DEST+'/Meshes/WVC_Forage_Chain_R01_SM':'chain',DEST+'/Meshes/WVC_Forage_PepperContents_R01_SM':'contents'};parts=[]
    for a in u.GameplayStatics.get_all_actors_of_class(world,u.Actor):
        for c in a.get_components_by_class(u.StaticMeshComponent):
            if not c.static_mesh:continue
            at=c.get_world_location()
            if abs(at.x+9600)>100 or abs(at.y-1900)>100 or not -1<=at.z<=461:continue
            path=c.static_mesh.get_path_name().split('.')[0];material=c.get_material(0);parts.append(dict(path=c.get_path_name(),mesh=path,material=material.get_path_name() if material else None,pose=c.get_world_transform().export_text(),collision=str(c.get_collision_profile_name()),collision_enabled=str(c.get_collision_enabled()),visible=c.is_visible(),role=expected.get(path)))
    for path in expected:
        row,=[r for r in parts if r['mesh']==path];assert row['collision']=='NoCollision'
    stone=[r for r in parts if r['collision']=='BlockAll'];assert len(stone)==5 and all(r['mesh']=='/Engine/BasicShapes/Cube' and '/PBR_R09/Materials/M_CP_Prop_PBR_R09' in r['material'] for r in stone)
    support,=[r for r in parts if r['mesh']=='/Engine/BasicShapes/Cube' and r['collision']=='NoCollision'];assert '/Materials/M_CP_ForageTimberPost_R01' in support['material'];assert len(parts)==9
    guard();assert_dirty_scope();s['runtime_verified']=True
    result=dict(status='AUTHORED_CENSER_CONTEXT_AND_NINE_PARTS_CONFIRMED',candidate=matches[0],parts=parts,boundary='Actual authored row and inherited profile; no forced seed/table, runtime mesh patch or interaction proof.')
    print('TEMP_PROFILE_RUNTIME',_write('forage_temp_profile_runtime_r10',result));return result
def restore_value():
    s=STATE
    if not s:return
    rows,objects=placements();assert set(rows)==set(s['before'])
    if s['assigned']:
        current=objects[s['key']].get_editor_property('ForagePresentation');assert current is None or current.get_path_name().split('.')[0]==PROFILE
        objects[s['key']].set_editor_property('ForagePresentation',None);s['assigned']=False
    assert placements()[0]==s['before'];guard();return assert_dirty_scope()
def restore_preferences():
    s=STATE
    if not s:return
    before=s['prefs'];before['editor'].set_editor_property('bAutoSaveEnable',before['autosave']);before['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave',before['cook'])
    now=settings();assert now['autosave']==before['autosave'] and now['cook']==before['cook'];s['protected']=False
def finish():
    u=_u();s=STATE;assert s and u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    restore_value();after,exports=export_scripts('restored');assert after==s['before']
    assert all(exports[p]['sha256']==r['sha256'] for p,r in s['exports'].items())
    guard();dirty=assert_dirty_scope()
    if dirty:
        s['waiting_reload']=True
        print('TEMP_PROFILE_NEEDS_RELOAD',_write('forage_temp_profile_restore_before_reload_r10',dict(status='VALUES_AND_SEVEN_EXPORTS_EXACT_TEMP_DIRTY_FLAG_REQUIRES_DISCARD',placements=after,exports=exports,dirty_maps=dirty,protection='Autosave/cook remain disabled until explicit TEMP-clone discard and finish_after_reload. No original dirty package is allowed.')))
        return 'NEEDS_TEMP_RELOAD'
    restore_preferences()
    print('TEMP_PROFILE_RESTORED',_write('forage_temp_profile_restored_r10',dict(status='EXACT_SEVEN_SCRIPT_EXPORTS_AND_PREFERENCES_RESTORED',placements=after,exports=exports,guards=651,owned_assets=36,aa=u.SystemLibrary.get_console_variable_int_value('r.AntiAliasingMethod'),dirty_maps=dirty,boundary='No original map/library save. All original files and owned asset packages remain exact.')))
    return 'RESTORED'
def finish_after_reload():
    u=_u();s=STATE;assert s and s.get('waiting_reload') and u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    after,_=placements()
    # TEMP instance package suffixes may change during unload/reload; compare authored identities and values.
    def semantic(rows):return sorted([{k:r[k] for k in ('actor_class','label','world','pose','anchor_id','profile')} for r in rows.values()],key=lambda r:r['anchor_id'])
    assert semantic(after)==semantic(s['before']);guard();restore_preferences();s['waiting_reload']=False
    print('TEMP_PROFILE_RESTORED_AFTER_RELOAD',_write('forage_temp_profile_restored_r10',dict(status='EXACT_SCRIPT_EXPORTS_BEFORE_RELOAD_AND_PLACEMENTS_PREFERENCES_AFTER_RELOAD',placements=after,guards=651,owned_assets=36,aa=u.SystemLibrary.get_console_variable_int_value('r.AntiAliasingMethod'),dirty_maps=[],boundary='Only the owned temporary clone discarded after exact field/export restoration. No original source map/library saved.')))
    return 'RESTORED'
