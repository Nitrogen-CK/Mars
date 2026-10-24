"""Delayed real-PIE capture/probes; no asset or map saves."""
import json
from pathlib import Path
import unreal as u
HERE=Path(__file__).resolve().parent
OUT=HERE/'Output'
OWNER='Mars.WarrensVariantCKit.Authoring.v1'
def world():
    w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world();assert w and 'UEDPIE' in w.get_path_name();return w
def position(name):
    w=world();v=next(v for v in json.loads((OUT/'review_views.json').read_text()) if v['id']==name)
    at=[(v['plan_eye'][0]-70)*100,(v['plan_eye'][1]-55)*100,v['plan_eye'][2]*100];t=v['target'];target=[(t[0]-70)*100,(t[1]-55)*100,t[2]*100]
    camera=next(c for c in u.GameplayStatics.get_all_actors_of_class(w,u.CameraActor) if c.get_name()=='CameraActor_0')
    camera.set_actor_location(u.Vector(*at),False,False);camera.set_actor_rotation(u.MathLibrary.find_look_at_rotation(u.Vector(*at),u.Vector(*target)),False);camera.camera_component.set_field_of_view(80)
    u.GameplayStatics.get_player_controller(w,0).set_view_target_with_blend(camera,0);print('VARIANT_C_CAMERA',name,at)
def capture(name):
    world();p=OUT/'Runtime'/(name+'.png');p.parent.mkdir(parents=True,exist_ok=True);u.AutomationLibrary.take_high_res_screenshot(1600,1000,str(p),delay=.2);print('VARIANT_C_CAPTURE_QUEUED',name)
def audit():
    w=world();actors=u.GameplayStatics.get_all_actors_of_class(w,u.Actor);owned=[a for a in actors if OWNER in [str(t) for t in a.tags]]
    cs=[c for a in owned for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)];n=sum(c.get_instance_count() for c in cs);expected=len(json.loads((OUT/'fitted_instances.json').read_text())['placements']);assert n==expected,(n,expected)
    assert all(str(c.get_collision_profile_name())=='NoCollision' for c in cs)
    glass=[c for a in owned if a.get_actor_label()=='WVC_CCS61' for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)]
    assert glass and all(not c.get_editor_property('cast_shadow') and c.get_material(0).get_path_name().endswith('M_CCK_Glass.M_CCK_Glass') for c in glass)
    assert not any(any(str(t) in ['Mars.ChainCrossingKit.Authoring.v1','Mars.PumpCisternKit.Authoring.v1'] for t in a.tags) for a in actors)
    r=dict(world=w.get_path_name(),instances=n,hism_groups=len(cs),all_visuals_no_collision=True,old_passes_absent=True,translucent_non_shadowing_lantern_inserts=sum(c.get_instance_count() for c in glass))
    (OUT/'Reports/runtime_instances.json').write_text(json.dumps(r,indent=2));print('VARIANT_C_RUNTIME_AUDIT_PASSED',n,len(cs))
def grid_audit():
    w=world();rows=[];lights=[]
    for a in u.GameplayStatics.get_all_actors_of_class(w,u.Actor):
        if isinstance(a,u.PointLight) and 'cold_9' in a.get_actor_label():lights.append(dict(actor=a.get_path_name(),intensity=a.point_light_component.intensity))
        for c in a.get_components_by_class(u.StaticMeshComponent):
            mats=[m.get_path_name() if m else None for m in c.get_materials()]
            if any('Grid' in (p or '') for p in mats):rows.append(dict(actor=a.get_path_name(),class_name=a.get_class().get_name(),component=c.get_name(),materials=mats,visible=c.is_visible(),hidden=bool(a.hidden),at=list(c.get_world_location().to_tuple())))
    (OUT/'Reports/runtime_grid_audit.json').write_text(json.dumps(dict(grids=rows,bell_lights=lights),indent=2));print('LIVE_GRID_AUDIT',len(rows),lights)
