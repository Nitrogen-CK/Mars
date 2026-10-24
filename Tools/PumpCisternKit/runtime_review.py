"""Delayed PIE-only cameras and manifest count probe; never saves a level."""
import json
from pathlib import Path
import unreal as u
HERE=Path(__file__).resolve().parent
OUT=HERE/'Output'
VIEWS={
    'PUMP':((-900,-2600,-90),(-1600,-3300,0)),
    'CISTERN':((-6170,-1800,-90),(-5400,-1900,-160)),
    'SLUICE':((5200,-4400,-90),None),
    'CROSSING':((200,-2940,-90),(1500,-3000,-95)),
    'HUMP':((-3380,-3450,30.5),(-2600,-3300,-20)),
    'COURT_LINK':((-6400,-2000,-90),(-5800,-2000,-90))}

def world():
    w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert w and 'UEDPIE' in w.get_path_name(), 'Live PIE world required'
    return w
def view(name):
    w=world();cameras=u.GameplayStatics.get_all_actors_of_class(w,u.CameraActor)
    camera=next(a for a in cameras if a.get_name()=='CameraActor_0')
    at,target=VIEWS[name];camera.set_actor_location(u.Vector(*at),False,False)
    rotation=u.MathLibrary.find_look_at_rotation(u.Vector(*at),u.Vector(*target)) if target else u.Rotator(pitch=-3,yaw=90,roll=0)
    camera.set_actor_rotation(rotation,False);camera.camera_component.set_field_of_view(80)
    u.GameplayStatics.get_player_controller(w,0).set_view_target_with_blend(camera,0)
    print('WATERWORKS_VIEW',name,list(at),[rotation.pitch,rotation.yaw,rotation.roll])
def capture(name,folder='After'):
    w=world();path=OUT/folder/(name+'.png');path.parent.mkdir(parents=True,exist_ok=True)
    u.AutomationLibrary.take_high_res_screenshot(1600,1000,str(path),delay=.2)
    print('WATERWORKS_QUEUED_CAPTURE',name,str(path))
def audit():
    w=world();counts={};groups={}
    for owner,folder in [('Mars.ChainCrossingKit.Authoring.v1',HERE.parent/'ChainCrossingKit'),('Mars.PumpCisternKit.Authoring.v1',HERE)]:
        cs=[c for a in u.GameplayStatics.get_all_actors_of_class(w,u.Actor) if owner in [str(t) for t in a.tags] for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)]
        count=sum(c.get_instance_count() for c in cs)
        assert all(str(c.get_collision_profile_name())=='NoCollision' for c in cs)
        expected=len(json.loads((folder/'Output/fitted_instances.json').read_text())['placements'])
        assert count==expected,(owner,count,expected)
        counts[owner]=count;groups[owner]=len(cs)
    result=dict(world=w.get_path_name(),counts=counts,hism_groups=groups,all_owned_hisms_no_collision=True)
    (OUT/'Reports/runtime_instances.json').write_text(json.dumps(result,indent=2))
    print('WATERWORKS_RUNTIME_AUDIT_PASSED',sum(counts.values()))
