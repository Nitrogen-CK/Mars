"""Disposable three-mesh surface-only trial; source actors never edited/saved."""
import hashlib,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
RUN=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout'
DEST='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01'
OWNER='Mars.WarrensVariantC.Larder.SurfaceReview.R01.PIE'
STATE=None


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def project():
    import unreal as u
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve(), 'Native project is not this workspace'


def clean():
    import unreal as u
    assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==[] and u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]


def guard():
    p=Path(__file__).with_name('room_art_capture_r33.py');sp=importlib.util.spec_from_file_location('_larder_trial_guard',p);m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m);m.guard()
    ledger=json.loads((RUN/'surface_mesh_assets_r01.json').read_text());assert len(ledger['assets'])==3
    for path,r in ledger['assets'].items():assert sha(ROOT/('Content/'+path.removeprefix('/Game/')+'.uasset'))==r['package_sha256']


def begin(core,capture_controller):
    import unreal as u
    global STATE
    assert STATE is None;project();guard();w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world();assert w and w.get_path_name()=='/Game/Mars/Maps/UEDPIE_0_Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    assert capture_controller.STATE and capture_controller.STATE['world']==w
    assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==[] and u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    gate=json.loads((DOC/'NATIVE_FINISH_DIAGNOSTIC_GATE_R06.json').read_text());assert gate['status']=='APPROVED_DISPOSABLE_FINISH_DIAGNOSTICS_ONLY' and gate['trial_tool_sha256']==sha(__file__)
    _,before=core._hism_snapshot(w);assert before
    STATE=dict(world=w,core=core,before=before,created=[],stage='source',tool_sha256=sha(__file__),capture=capture_controller)
    print('LARDER_SURFACE_TRIAL_BASELINE',len(before),sum(len(v['instances']) for v in before.values()))


def abort():
    """Any stage/cleanup failure ends this PIE and drops controller references.

    EndPlay is asynchronous; root must next confirm no PIE, clean packages and
    guards. Root acquisition aliases must be cleared before begin(), leaving
    this controller and its capture controller as the only PIE reference owners.
    """
    import unreal as u
    global STATE
    s=STATE
    try:
        project();w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
        if w:
            assert w.get_path_name()=='/Game/Mars/Maps/UEDPIE_0_Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
            u.get_editor_subsystem(u.LevelEditorSubsystem).editor_request_end_play()
    finally:
        if s:s['capture'].STATE=None;s['created']=[]
        STATE=None
    print('LARDER_TRIAL_ABORT_ENDPLAY_REQUESTED_REFERENCES_CLEARED')


def restore():
    import unreal as u
    global STATE
    s=STATE
    try:
        project();assert s and s['stage']=='surface_only' and s['world']==u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
        s['destroy_requested_paths']=[a.get_path_name() for a in s['created']]
        for actor in reversed(s['created']):
            assert actor.get_world()==s['world'] and OWNER in [str(v) for v in actor.tags];actor.destroy_actor()
            # Python destroy_actor returnsNone, not a success boolean. Check
            # the actual destruction state immediately, then absence next turn.
            assert not u.SystemLibrary.is_valid(actor) or actor.is_actor_being_destroyed()
        s['created']=[];s['stage']='await_destroy_absence';guard();clean();print('LARDER_DESTROY_REQUESTS_CONFIRMED_CHECK_ABSENCE_NEXT_TOOL_TURN',s['destroy_requested_paths'])
    except Exception:
        abort();raise


def confirm_restored():
    import unreal as u
    global STATE
    s=STATE
    try:
        project();assert s and s['stage']=='await_destroy_absence' and s['world']==u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
        actual={a.get_path_name() for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor)}
        assert all(p not in actual and not u.SystemLibrary.is_valid(u.find_object(None,p)) for p in s['destroy_requested_paths'])
        _,after=s['core']._hism_snapshot(s['world']);assert after==s['before'];guard();clean()
        p=RUN/'surface_trial_restored_r02.json';assert not p.exists();p.write_text(json.dumps(dict(status='LATER_TURN_DISPOSABLE_ACTOR_ABSENCE_AND_ORIGINAL_HISMS_EXACT',removed_paths=s['destroy_requested_paths'],hism_components=len(after),hism_instances=sum(len(v['instances']) for v in after.values()),tool_sha256=sha(__file__),dirty_maps=[],dirty_content=[]),indent=2)+'\n');STATE=None;print('LARDER_SURFACE_TRIAL_RESTORED_AND_REFERENCES_CLEARED')
    except Exception:
        abort();raise


def stage():
    import unreal as u
    s=STATE;assert s and s['stage']=='source' and sha(__file__)==s['tool_sha256'];project();guard();assert s['world']==u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert u.GameplayStatics.is_game_paused(s['world']);_,before=s['core']._hism_snapshot(s['world']);assert before==s['before']
    export=json.loads((DOC/'export-r03/export.json').read_text());gate=json.loads((DOC/'NATIVE_FINISH_DIAGNOSTIC_GATE_R06.json').read_text());assert gate['export_sha256']==sha(DOC/'export-r03/export.json') and gate['trial_tool_sha256']==sha(__file__)
    try:
        for row in export['exports']:
            mesh=u.load_asset(DEST+'/Meshes/'+row['name']);assert isinstance(mesh,u.StaticMesh)
            original={a.get_path_name() for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.StaticMeshActor)}
            u.SystemLibrary.execute_console_command(s['world'],'Summon /Script/Engine.StaticMeshActor',u.GameplayStatics.get_player_controller(s['world'],0))
            actor,=[a for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.StaticMeshActor) if a.get_path_name() not in original];s['created'].append(actor);actor.tags=[u.Name(OWNER)]
            c=actor.static_mesh_component;c.set_collision_profile_name('NoCollision');c.set_collision_enabled(u.CollisionEnabled.NO_COLLISION);c.set_editor_property('generate_overlap_events',False);c.set_mobility(u.ComponentMobility.MOVABLE)
            for i,slot in enumerate(mesh.static_materials):c.set_material(i,slot.material_interface)
            assert c.set_static_mesh(mesh);actor.set_actor_transform(u.Transform(location=u.Vector(*row['placement_main_cm'])),False,True);assert (actor.get_actor_location()-u.Vector(*row['placement_main_cm'])).length()<.001;actor.set_actor_label('WVC_Larder_SurfaceTrial_'+row['family']);c.set_visibility(True,False);c.set_hidden_in_game(False,False)
            assert actor.get_world()==s['world'] and c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION
        _,after=s['core']._hism_snapshot(s['world']);assert after==s['before'] and len(s['created'])==3;s['stage']='surface_only';guard()
        p=RUN/'surface_trial_staged_r02.json';assert not p.exists();p.write_text(json.dumps(dict(status='THREE_DISPOSABLE_PIE_SURFACE_MESH_ACTORS_ONLY',actors=[a.get_path_name() for a in s['created']],existing_hisms_exact=True,no_original_material_light_water_prop_or_collision_edits=True,tool_sha256=sha(__file__),export_sha256=sha(DOC/'export-r03/export.json')),indent=2)+'\n');print('LARDER_DISPOSABLE_SURFACE_ONLY_STAGED')
    except Exception:
        abort();raise


def visible(on):
    import unreal as u
    s=STATE;project();assert s and s['stage']=='surface_only' and u.GameplayStatics.is_game_paused(s['world'])
    for actor in s['created']:actor.static_mesh_component.set_visibility(on,False);actor.static_mesh_component.set_hidden_in_game(not on,False)
