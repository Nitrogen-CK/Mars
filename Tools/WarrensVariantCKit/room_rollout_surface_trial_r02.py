"""Reusable three-surface room diagnostic; source geometry and gameplay fixed."""
import copy
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'
STATE=None


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def owned(actor):
    c=actor.static_mesh_component;t=STATE
    return dict(path=actor.get_path_name(),label=actor.get_actor_label(),pose=t['core']._pose(actor.get_actor_transform()),mesh=c.static_mesh.get_path_name(),materials=[m.get_path_name() for m in c.get_materials()],collision=str(c.get_collision_enabled()),profile=str(c.get_collision_profile_name()),body=c.get_editor_property('body_instance').export_text(),visible=c.is_visible(),hidden=c.get_editor_property('hidden_in_game'),mobility=str(c.mobility),flags=t['base'].flags(c),tags=list(map(str,actor.tags)))


def check():
    import unreal as u
    t=STATE;assert t and t['stage']=='ready'
    assert sha(__file__)==t['gate']['tool_sha256']
    t['capture'].guard();t['assets'].guard()
    assert t['assets'].load('room_tint_owned_assets_r01').dirty()==dict(maps=[],content=[])
    assert t['world']==u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() and u.GameplayStatics.is_game_paused(t['world'])
    _,current=t['core']._hism_snapshot(t['world']);assert current==t['before']
    assert [owned(a) for a in t['created']]==t['expected']
    assert all(a.static_mesh_component.mobility==u.ComponentMobility.MOVABLE and a.static_mesh_component.get_editor_property('cast_hidden_shadow') is False for a in t['created'])


def begin(room,core,capture,assets,base):
    import unreal as u
    global STATE
    assert STATE is None and room in ('hall','ossuary','cellar','sluice')
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    gate=json.loads((DOC/'NATIVE_FOUR_ROOM_SURFACE_TRIAL_GATE_R02.json').read_text())
    assert gate['status']=='APPROVED_FOUR_ROOM_THREE_SURFACE_DISPOSABLE_DIAGNOSTIC' and gate['tool_sha256']==sha(__file__)
    for path,digest in gate['input_sha256'].items():assert sha(ROOT/path)==digest
    capture.guard();assets.guard();world=capture.STATE['world']
    assert assets.load('room_tint_owned_assets_r01').dirty()==dict(maps=[],content=[])
    assert world==u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() and u.GameplayStatics.is_game_paused(world)
    assert world.get_path_name()=='/Game/Mars/Maps/UEDPIE_0_Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    _,before=core._hism_snapshot(world)
    STATE=dict(room=room,core=core,capture=capture,assets=assets,base=base,world=world,before=before,created=[],expected=[],on=False,gate=gate,stage='preparing')
    for family in ('walls','floor','ceiling'):
        receipt=json.loads(assets.ledger_path('mesh',room,family).read_text());config=receipt['config']
        assert sha(assets.disk(config['mesh_target']))==receipt['package_sha256']
        mesh=u.load_asset(config['mesh_target']);assert mesh and mesh.get_num_triangles(0)==receipt['details']['source_render_counts']['render']
        prior={a.get_path_name() for a in u.GameplayStatics.get_all_actors_of_class(world,u.StaticMeshActor)}
        u.SystemLibrary.execute_console_command(world,'Summon /Script/Engine.StaticMeshActor',u.GameplayStatics.get_player_controller(world,0))
        actor,=[a for a in u.GameplayStatics.get_all_actors_of_class(world,u.StaticMeshActor) if a.get_path_name() not in prior]
        STATE['created'].append(actor)
        actor.tags=[u.Name('Mars.WarrensVariantC.RoomRollout.SurfaceTrial.R01')];actor.set_actor_label('WVC_'+room.title()+'_SurfaceTrial_'+family)
        c=actor.static_mesh_component;c.set_mobility(u.ComponentMobility.MOVABLE);c.set_collision_profile_name('NoCollision');c.set_collision_enabled(u.CollisionEnabled.NO_COLLISION);c.set_editor_property('generate_overlap_events',False);c.set_editor_property('cast_hidden_shadow',False)
        assert c.set_static_mesh(mesh)
        for i,slot in enumerate(mesh.static_materials):c.set_material(i,slot.material_interface)
        transform=u.Transform(location=u.Vector(*config['export']['placement_main_cm']))
        pose=base.load('checked_surface_pose_r01').set_pose(actor,transform,core)
        STATE.setdefault('placement_readbacks',[]).append(pose)
        c.set_visibility(False,False);c.set_hidden_in_game(True,False)
    STATE['expected']=[owned(a) for a in STATE['created']];STATE['stage']='ready';check()
    print('ROOM_SURFACE_DIAGNOSTIC_STAGED_HIDDEN',room)


def visible(on):
    assert isinstance(on,bool);check();t=STATE
    expected=copy.deepcopy(t['expected'])
    for a,row in zip(t['created'],expected):
        a.static_mesh_component.set_visibility(on,False);a.static_mesh_component.set_hidden_in_game(not on,False)
        row['visible']=on;row['hidden']=not on;row['flags']['visible']=on;row['flags']['hidden_in_game']=not on
        assert owned(a)==row
    t['on']=on;t['expected']=expected;check()


def capture(label):
    import unreal as u
    t=STATE;u.GameplayStatics.set_game_paused(t['world'],True);check();t['capture'].capture(label)
    path=t['capture'].STATE['out']/(label+'.json');record=json.loads(path.read_text())
    record['room']=t['room'];record['room_surfaces']=dict(on=t['on'],actors=t['expected'],placement_readbacks=t['placement_readbacks'])
    record['boundary']='Actual Main PIE real carried lantern, three private source-supported surface actors only. Source HISM complete roster unchanged, no material/light/prop/water/physics/gameplay overrides. Room palette inherits accepted independent PBR family maps. Teleported paused appearance evidence, not pacing, physical-input, packaged or multiplayer proof.'
    path.write_text(json.dumps(record,indent=2)+'\n')


def restore():
    check();t=STATE
    for actor in t['created']:actor.destroy_actor()
    t['stage']='destroy_requested'


def confirm_restored():
    import unreal as u
    global STATE
    t=STATE;assert t and t['stage']=='destroy_requested'
    t['capture'].guard();t['assets'].guard()
    actual={a.get_path_name() for a in u.GameplayStatics.get_all_actors_of_class(t['world'],u.Actor)}
    paths=[r['path'] for r in t['expected']]
    assert all(path not in actual and not u.SystemLibrary.is_valid(u.find_object(None,path)) for path in paths)
    _,current=t['core']._hism_snapshot(t['world']);assert current==t['before']
    record=dict(status='ROOM_SURFACE_THREE_ACTORS_ABSENT_SOURCE_HISMS_EXACT',room=t['room'],absent=paths,HISM_count=len(current),instances=sum(len(r['instances']) for r in current.values()))
    (t['capture'].STATE['out']/(t['room']+'_restored.json')).write_text(json.dumps(record,indent=2)+'\n')
    STATE=None;print('ROOM_SURFACE_REFERENCES_RELEASED_SOURCE_EXACT')


def abort(capture_controller):
    import unreal as u
    global STATE
    try:
        world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
        if world:
            assert world.get_path_name()=='/Game/Mars/Maps/UEDPIE_0_Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
            u.get_editor_subsystem(u.LevelEditorSubsystem).editor_request_end_play()
    finally:
        if STATE:STATE['capture'].STATE=None
        capture_controller.STATE=None
        STATE=None
