"""Read-only travel-time evidence: dynamic pickup readiness versus floor collision.

Register before travel so the first observed new-world frame is retained. No
sleep, body-state changes, spawning, or item recovery is performed.
"""
import json
import time
from pathlib import Path
import unreal as u

HANDLE = None
REPORT = None


def start(seed=171119713, seconds=12, name='startup_order_probe'):
    global HANDLE, REPORT
    assert HANDLE is None
    ed = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    old_world = ed.get_game_world()
    assert old_world
    output = Path(__file__).resolve().parents[2] / 'Saved/WarrensCGameplay-20261024' / (name+'.json')
    assert not output.exists(), 'Preserve the preceding observation under its own name'
    started = time.monotonic()
    REPORT = dict(seed=seed, samples=[], errors=[], boundary='Read-only observation during seeded travel; no item restoration or body-state mutation.')
    targets = [('S4Pack',4920,-5500,-250),('S4Lantern',4920,-5410,-250),
               ('S4TallowA',4900,-5370,-250),('S4TallowB',4940,-5370,-250),
               ('RedKey',3400,500,250),('S3Pack',7000,-1780,-250),
               ('S3Lantern',7000,-1690,-250),('S3TallowA',6980,-1650,-250),
               ('S3TallowB',7020,-1650,-250),('VaultTallow',-700,600,-500),
               ('VaultRation',-800,400,-500),('MournerTallow',3300,2100,250)]

    def tick(delta):
        global HANDLE
        try:
            world = ed.get_game_world()
            if not world or world == old_world:
                if time.monotonic()-started < 90:
                    return
                raise RuntimeError('No new game world within observation window')
            now = u.GameplayStatics.get_time_seconds(world)
            pawn = u.GameplayStatics.get_player_pawn(world,0)
            sample = dict(t=now,statics=u.Ck_Utils_JoltStaticWorld_UE.get_num_static_bodies(world),pawn_ready=False,items=[],floors={})
            if pawn and u.Ck_Utils_OwningActor_UE.get_is_actor_ecs_ready(pawn):
                sample['pawn_ready'] = True
                ctx = u.Ck_Utils_OwningActor_UE.try_get_actor_entity_handle(pawn)
                for e in u.Ck_Utils_EntityTag_UE.for_each_entity(ctx,u.Name('TAG_MarsWorldItem')):
                    cast = u.Ck_Utils_JoltBody_UE.do_cast(e)
                    if cast[-1] != u.Ck_SucceededFailed.SUCCEEDED:
                        continue
                    t = u.Ck_Utils_Transform_UE.get_entity_current_transform(u.Ck_Utils_Transform_UE.do_cast_checked(e))
                    sample['items'].append(dict(at=list(t.translation.to_tuple()),state=str(u.Ck_Utils_JoltBody_UE.get_setup_state(cast[0])),added=u.Ck_Utils_JoltBody_UE.get_is_body_added(cast[0])))
                for label,x,y,z in targets:
                    hit = u.Ck_Utils_JoltStaticWorld_UE.get_ray_cast_static_world(pawn,u.Vector(x,y,z+100),u.Vector(x,y,z-100))
                    sample['floors'][label] = hit.export_text()
            REPORT['samples'].append(sample)
            # Preserve every early frame, then bound the report frequency.
            if now >= seconds or time.monotonic()-started > 120:
                u.unregister_slate_pre_tick_callback(HANDLE)
                HANDLE = None
                output.write_text(json.dumps(REPORT,indent=2))
                print('STARTUP_ORDER_PROBE_DONE',str(output),len(REPORT['samples']))
        except Exception as error:
            REPORT['errors'].append(str(error))
            u.unregister_slate_pre_tick_callback(HANDLE)
            HANDLE = None
            output.write_text(json.dumps(REPORT,indent=2))
            raise
    HANDLE = u.register_slate_pre_tick_callback(tick)
    u.GameplayStatics.open_level(old_world,u.Name('/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'),True,'seed='+str(seed))
    return dict(started=True,output=str(output))
