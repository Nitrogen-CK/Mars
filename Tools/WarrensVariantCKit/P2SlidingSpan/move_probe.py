"""Bounded live Enhanced Input movement probe; never teleports or edits state.

Caller positions/aims the pawn separately and labels that positioning. This
feeds the real Move action, samples actual pawn positions, then injects zero.
No screenshot is taken from its callback (capture can re-enter Slate).
"""
import json
from pathlib import Path
import unreal as u

HANDLE = None
REPORT = None
BUSY = False


def start(seconds=6.5,axis=(0,1,0),name='P2_seated_walk',keys=()):
    global HANDLE,REPORT
    assert HANDLE is None,'A probe is already running'
    world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    pawn=u.GameplayStatics.get_player_pawn(world,0)
    systems=[s for s in u.ObjectIterator(u.EnhancedInputLocalPlayerSubsystem)
             if not s.get_path_name().startswith('/Script/')]
    assert pawn and len(systems)==1,(pawn,systems)
    subsystem=systems[0]
    action=u.load_asset('/Script/AngelscriptAssets.Mars_IA_Move')
    assert action
    helper=u.new_object(u.load_class(None,'/Script/Angelscript.Mars_ExpeditionAcceptance'))
    events=list(sorted(keys))
    pressed=set()
    initial=u.GameplayStatics.get_time_seconds(world)
    path=Path(__file__).resolve().parents[3]/'Saved/WarrensCGameplay-20261024'/ (name+'.json')
    REPORT=dict(action=action.get_path_name(),axis=list(axis),seconds=seconds,
                initial=list(pawn.get_actor_location().to_tuple()),samples=[],
                key_events=list(keys),boundary='Real Move action injected through Enhanced Input, not physical keyboard evidence. Positioning before this probe is excluded.')

    def release_keys():
        for key in pressed:helper.key(pawn,u.Name(key),False)
        pressed.clear()

    def tick(delta):
        global HANDLE,BUSY
        if BUSY:return
        BUSY=True
        try:
            assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()==world,'World changed'
            elapsed=u.GameplayStatics.get_time_seconds(world)-initial
            while events and elapsed>=events[0][0]:
                _,key,down=events.pop(0)
                helper.key(pawn,u.Name(key),down)
                if down:pressed.add(key)
                else:pressed.discard(key)
            if not REPORT['samples'] or elapsed-REPORT['samples'][-1]['t']>=.15:
                REPORT['samples'].append(dict(t=elapsed,at=list(pawn.get_actor_location().to_tuple())))
            if elapsed<seconds:
                subsystem.inject_input_vector_for_action(action,u.Vector(*axis),[],[])
                return
            subsystem.inject_input_vector_for_action(action,u.Vector(),[],[])
            release_keys()
            REPORT['final']=list(pawn.get_actor_location().to_tuple())
            u.unregister_slate_pre_tick_callback(HANDLE)
            HANDLE=None
            path.write_text(json.dumps(REPORT,indent=2))
            print('P2_MOVE_PROBE_DONE',str(path),REPORT['initial'],REPORT['final'])
        except Exception as error:
            subsystem.inject_input_vector_for_action(action,u.Vector(),[],[])
            release_keys()
            REPORT['error']=str(error)
            if HANDLE is not None:u.unregister_slate_pre_tick_callback(HANDLE)
            HANDLE=None
            path.write_text(json.dumps(REPORT,indent=2))
            raise
        finally:
            BUSY=False
    HANDLE=u.register_slate_pre_tick_callback(tick)
    return dict(started=True,output=str(path),initial=REPORT['initial'])
