"""Disposable transform experiment; record actual values before choosing a fix."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'
STATE=None


def run(core):
    import unreal as u
    global STATE
    assert STATE is None
    world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert world.get_path_name()=='/Game/Mars/Maps/UEDPIE_0_Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    u.GameplayStatics.set_game_paused(world,True)
    before={a.get_path_name() for a in u.GameplayStatics.get_all_actors_of_class(world,u.StaticMeshActor)}
    u.SystemLibrary.execute_console_command(world,'Summon /Script/Engine.StaticMeshActor',u.GameplayStatics.get_player_controller(world,0))
    actor,=[a for a in u.GameplayStatics.get_all_actors_of_class(world,u.StaticMeshActor) if a.get_path_name() not in before]
    STATE=dict(world=world,actor=actor,path=actor.get_path_name())
    c=actor.static_mesh_component;c.set_mobility(u.ComponentMobility.MOVABLE);c.set_collision_enabled(u.CollisionEnabled.NO_COLLISION);c.set_visibility(False,False);c.set_hidden_in_game(True,False);c.set_editor_property('cast_hidden_shadow',False)
    mesh=u.load_asset('/Game/Mars/ArtReview/Lookdev/RoomRollout_20261027R01/Meshes/WVC_Cellar_Walls_R01_SM');assert c.set_static_mesh(mesh)
    wanted=u.Transform(location=u.Vector(3300,-3600,-250));record=[]
    old=json.loads((DOC/'native-four-room-surfaces-r17/ossuary_upper_B.json').read_text())['rotation']
    for initial in [dict(pitch=0,yaw=0,roll=0),old,dict(pitch=0,yaw=90,roll=0),dict(pitch=27,yaw=51,roll=0)]:
        actor.set_actor_rotation(u.Rotator(**initial),True)
        before_set=core._pose(actor.get_actor_transform())
        actor.set_actor_transform(wanted,False,True)
        actual=core._pose(actor.get_actor_transform());expected=core._pose(wanted)
        record.append(dict(initial_rotation=initial,before_set=before_set,requested=expected,actual=actual,exact=actual==expected,deltas={k:[a-b for a,b in zip(actual[k],expected[k])] for k in ('at','scale','q')}))
    path=DOC/'surface_pose_precision_experiment_r02.json';assert not path.exists();path.write_text(json.dumps(record,indent=2)+'\n')
    print('POSE_PRECISION_EXPERIMENT',record)
    actor.destroy_actor()


def release():
    import unreal as u
    global STATE
    assert STATE
    actual={a.get_path_name() for a in u.GameplayStatics.get_all_actors_of_class(STATE['world'],u.Actor)}
    assert STATE['path'] not in actual
    STATE=None
