"""Read-only identity-based observation of the approved placed-pickup repair."""
import json
import time
from pathlib import Path
import unreal as u

HANDLE=None
REPORT=None


def snapshot(world):
    fixtures=[]
    for s in u.ObjectIterator(u.Ck_EntityScript_UE):
        if s.get_class().get_name()!='Mars_PlacedPickup_EntityScript' or s.get_outer()!=world:
            continue
        identity=str(s.get_editor_property('FixtureId'))
        if identity=='None':continue
        child=s.get_spawned_entity()
        row=dict(id=identity,script=s.get_path_name(),state=str(s.get_state()),
            failure=s.get_failure(),dispatch_time=s.get_dispatch_time_seconds(),
            witnesses=[list(p.to_tuple()) for p in s.get_expected_witnesses()],
            support_mask=s.get_last_support_mask(),hit_heights=list(s.get_last_hit_heights()),
            child=u.Ck_Utils_Handle_UE.conv_handle_to_string(child),ready=s.get_is_spawned_item_ready())
        transform=u.Ck_Utils_Transform_UE.do_cast(child)
        if transform[-1]==u.Ck_SucceededFailed.SUCCEEDED:
            t=u.Ck_Utils_Transform_UE.get_entity_current_transform(transform[0])
            row['at']=list(t.translation.to_tuple())
        body=u.Ck_Utils_JoltBody_UE.do_cast(child)
        if body[-1]==u.Ck_SucceededFailed.SUCCEEDED:
            row['body_state']=str(u.Ck_Utils_JoltBody_UE.get_setup_state(body[0]))
            row['body_added']=u.Ck_Utils_JoltBody_UE.get_is_body_added(body[0])
        fixtures.append(row)
    return sorted(fixtures,key=lambda r:r['id'])


def start(name, travel=False, seed=171119713, seconds=12):
    global HANDLE,REPORT
    assert HANDLE is None
    output=Path(__file__).resolve().parents[2]/'Saved/WarrensCGameplay-20261024'/(name+'.json')
    assert not output.exists(),'Keep preceding observations immutable'
    ed=u.get_editor_subsystem(u.UnrealEditorSubsystem)
    old_world=ed.get_game_world() if travel else None
    if travel:assert old_world
    started=time.monotonic()
    REPORT=dict(seed=seed if travel else None,samples=[],errors=[],
        boundary='Read-only identity-based observation. No item position, inventory, body state, timing or readiness is forced.')

    def tick(delta):
        global HANDLE
        try:
            world=ed.get_game_world()
            if not world or world==old_world:
                if time.monotonic()-started<90:return
                raise RuntimeError('Game world did not start')
            now=u.GameplayStatics.get_time_seconds(world)
            REPORT['samples'].append(dict(t=now,fixtures=snapshot(world)))
            if now>=seconds or time.monotonic()-started>120:
                u.unregister_slate_pre_tick_callback(HANDLE);HANDLE=None
                output.write_text(json.dumps(REPORT,indent=2))
                print('STARTUP_ACCEPTANCE_DONE',str(output),len(REPORT['samples']))
        except Exception as error:
            REPORT['errors'].append(str(error))
            u.unregister_slate_pre_tick_callback(HANDLE);HANDLE=None
            output.write_text(json.dumps(REPORT,indent=2))
            raise
    HANDLE=u.register_slate_pre_tick_callback(tick)
    if travel:u.GameplayStatics.open_level(old_world,u.Name('/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'),True,'seed='+str(seed))
    return dict(started=True,output=str(output))
