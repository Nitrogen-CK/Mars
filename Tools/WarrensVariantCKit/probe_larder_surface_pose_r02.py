"""One disposable PIE actor probe. Records actual delta before any assertion."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/native-pose-probe-r02'
STATE=None
def run(core,controller):
    import unreal as u
    global STATE
    assert STATE is None and not OUT.exists();controller.guard()
    w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world();assert w and w.get_path_name()=='/Game/Mars/Maps/UEDPIE_0_Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP';u.GameplayStatics.set_game_paused(w,True)
    _,before=core._hism_snapshot(w);old={a.get_path_name() for a in u.GameplayStatics.get_all_actors_of_class(w,u.StaticMeshActor)};OUT.mkdir();STATE=dict(world=w,core=core,controller=controller,before=before,actor=None)
    try:
        u.SystemLibrary.execute_console_command(w,'Summon /Script/Engine.StaticMeshActor',u.GameplayStatics.get_player_controller(w,0));a,=[a for a in u.GameplayStatics.get_all_actors_of_class(w,u.StaticMeshActor) if a.get_path_name() not in old];STATE['actor']=a;a.tags=[u.Name('Mars.WarrensVariantC.PoseProbe.R01')];c=a.static_mesh_component
        spawned=core._pose(a.get_actor_transform());c.set_mobility(u.ComponentMobility.MOVABLE);c.set_collision_profile_name('NoCollision');c.set_collision_enabled(u.CollisionEnabled.NO_COLLISION);c.set_editor_property('generate_overlap_events',False)
        mesh=u.load_asset('/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/Meshes/WVC_Larder_Walls_R02_SM');assert c.set_static_mesh(mesh)
        for i,v in enumerate(mesh.static_materials):c.set_material(i,v.material_interface)
        control=json.loads((OUT.parent/'native-pose-probe-r01/actual_pose.json').read_text())['initial'];init=dict(control,at=[-5534.372108349094,*control['at'][1:]])
        init_tf=u.Transform(location=u.Vector(*init['at']),rotation=u.Quat(*init['q']),scale=u.Vector(*init['scale']));a.set_actor_transform(init_tf,False,True);initial=core._pose(a.get_actor_transform())
        wanted=u.Transform(location=u.Vector(5000,-1500,-250));result=a.set_actor_transform(wanted,False,True);a.set_actor_label('WVC_Larder_PoseProbe_R01');c.set_visibility(True,False);c.set_hidden_in_game(False,False);actual=a.get_actor_transform()
        r=dict(status='ACTUAL_SINGLE_SURFACE_TRANSFORM_PROBE_NOT_ART_ACCEPTANCE',actor=a.get_path_name(),world=w.get_path_name(),initial=initial,wanted=core._pose(wanted),actual=core._pose(actual),exact_equal=core._pose(actual)==core._pose(wanted),translation_delta=list((actual.translation-wanted.translation).to_tuple()),scale_delta=list((actual.scale3d-wanted.scale3d).to_tuple()),angular_distance=actual.rotation.angular_distance(wanted.rotation),return_value=str(result),component_world=core._pose(c.get_world_transform()),component_relative=c.get_relative_transform().export_text(),component_mobility=str(c.mobility),root_mobility=str(a.root_component.mobility),root=a.root_component.get_path_name(),attach_parent=str(c.get_attach_parent()),mesh=mesh.get_path_name(),boundary='One new NoCollision owned actor in paused disposable Main PIE, no playerkit/art/lighting/source edits; records evidence before cleanup, no tolerance change or fix selected.')
        r.update(integer_control=control,initial_requested=init,spawned=spawned,predicted_translation=[x+(y-x) for x,y in zip(initial['at'],r['wanted']['at'])],boundary='One controlled fractional-X initialization, same recorded control Y/Z/rotation/scale, one target setter. Probe mechanism only; unrecorded failed R08 values are not reconstructed. No tolerance/production fix selected.')
        (OUT/'actual_pose.json').write_text(json.dumps(r,indent=2)+'\n');print('ACTUAL_POSE_PROBE',r)
    finally:
        a=STATE['actor']
        if a:STATE['path']=a.get_path_name();a.destroy_actor();assert a.is_actor_being_destroyed() or not u.SystemLibrary.is_valid(a)
def confirm():
    import unreal as u
    global STATE
    s=STATE;assert s;s['controller'].guard();assert s['path'] not in {a.get_path_name() for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor)} and not u.SystemLibrary.is_valid(u.find_object(None,s['path']))
    _,after=s['core']._hism_snapshot(s['world']);assert after==s['before'];STATE=None;print('POSE_PROBE_ABSENT_ORIGINAL_HISMS_EXACT_REFERENCES_RELEASED')
def abort():
    import unreal as u
    global STATE
    try:u.get_editor_subsystem(u.LevelEditorSubsystem).editor_request_end_play()
    finally:STATE=None
