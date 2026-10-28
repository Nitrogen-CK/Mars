"""Bounded real-frame P4 input diagnostic. No source/map edits or forced state.

Requires the lead's isolated P4 pawn position, picked-up lantern in slot one,
empty slot two, and one observed wrong commit. Not a played expedition.
"""
import json
import time
from pathlib import Path
import unreal as u

ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT/'Saved/WarrensCGameplay-20261024'
REVIEW = ROOT/'docs/art/warrens-c-gameplay-review-20261024'
_state = None


def start(failures_observed=1, suffix=''):
    global _state
    assert _state is None, 'Probe already started'
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert world and 'UEDPIE' in world.get_path_name()
    pawn = u.GameplayStatics.get_player_pawn(world, 0)
    assert (pawn.get_actor_location()-u.Vector(3800,-730,77.2)).length()<2
    helper = u.new_object(u.load_class(None,'/Script/Angelscript.Mars_ExpeditionAcceptance'))
    assert 'pack=true' in helper.inspect(pawn)

    def aim(at):
        camera = u.GameplayStatics.get_player_camera_manager(world,0)
        helper.aim(pawn,u.MathLibrary.find_look_at_rotation(camera.get_camera_location(),u.Vector(*at)))

    def key(name,down): helper.key(pawn,u.Name(name),down)
    def use(down): helper.use(pawn,down)
    def look(x,y): helper.look(pawn,u.Vector(x,y,0))
    def capture(name):
        u.AutomationLibrary.take_high_res_screenshot(1600,1000,str(REVIEW/(name+suffix+'.png')),delay=.1)

    steps = [('empty hands',lambda:key('Two',True)),
             ('release slot key and aim chain',lambda:(key('Two',False),aim((3650,-860,90))))]
    for number in range(failures_observed+1,4):
        steps += [(f'wrong{number} grip',lambda:use(True)),
                  (f'wrong{number} pull',lambda:look(0,40)),
                  (f'wrong{number} release',lambda:use(False))]
    steps += [('light for final-candle view',lambda:key('One',True)),
              ('panel view',lambda:(key('One',False),aim((3800,-872,120)))),
              ('capture final retained candle',lambda:capture('P4_three_failures')),
              ('empty hands for dials',lambda:key('Two',True)),
              ('dial0 aim',lambda:(key('Two',False),aim((3755,-866,120))))]
    for index,(x,degrees) in enumerate(((3755,90),(3800,60),(3845,120))):
        if index:
            steps.append((f'dial{index} aim',lambda x=x:aim((x,-866,120))))
        steps += [(f'dial{index} grip',lambda:use(True)),
                  (f'dial{index} drag',lambda degrees=degrees:look(degrees,0)),
                  (f'dial{index} release',lambda:use(False))]
    steps += [('correct commit aim',lambda:aim((3650,-860,90))),
              ('correct commit grip',lambda:use(True)),
              ('correct commit pull',lambda:look(0,40)),
              ('correct commit release',lambda:use(False)),
              ('light after solve',lambda:key('One',True)),
              ('solved panel view',lambda:(key('One',False),aim((3800,-872,120)))),
              ('capture solve candidate',lambda:capture('P4_solve_candidate'))]
    _state = dict(world=world,pawn=pawn,helper=helper,steps=steps,index=0,ticks=0,
                  after=time.monotonic(),events=[],callback=None,busy=False)

    def stop(error=None):
        use(False)
        for name in ('One','Two'): key(name,False)
        u.unregister_slate_post_tick_callback(_state['callback'])
        report=dict(events=_state['events'],error=error,
                    inspection=helper.inspect(pawn),world_items=helper.world_items(pawn),
                    boundary='Scripted raw Use/look input on an isolated teleported pawn. No forced dial/gate/reward state. Not route, physical-input, timing, novice, co-op or packaged proof.')
        (RUN/('P4_sequence'+suffix+'.json')).write_text(json.dumps(report,indent=2))
        print('WVC_P4_PROBE_FINISHED',json.dumps(report))

    def tick(delta):
        if _state['busy']:
            return  # Screenshot rendering may pump Slate while this callback is on stack.
        try:
            if u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()!=world:
                raise RuntimeError('PIE world changed during probe')
            _state['ticks']+=1
            if _state['ticks']<8 or time.monotonic()<_state['after']:
                return
            if _state['index']==len(steps):
                stop()
                return
            name,action=steps[_state['index']]
            camera=u.GameplayStatics.get_player_camera_manager(world,0)
            _state['events'].append(dict(step=name,camera_before=str(camera.get_camera_rotation()),
                                        world_time=u.GameplayStatics.get_time_seconds(world)))
            _state['index']+=1
            _state['ticks']=0
            _state['after']=time.monotonic()+.6
            _state['busy']=True
            try:
                action()
            finally:
                _state['busy']=False
        except Exception as exc:
            stop(repr(exc))

    _state['callback']=u.register_slate_post_tick_callback(tick)
    print('WVC_P4_PROBE_STARTED',len(steps))
