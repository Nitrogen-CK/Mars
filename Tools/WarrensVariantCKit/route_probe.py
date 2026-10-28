"""Observed waypoint walking through real Enhanced Input; never repositions."""
import json
import math
from pathlib import Path
import unreal as u

HANDLE = None
REPORT = None


def start(name, points, seconds=120, tolerance=32):
    global HANDLE, REPORT
    assert HANDLE is None
    output = Path(__file__).resolve().parents[2] / 'Saved/WarrensCGameplay-20261024' / (name + '.json')
    assert not output.exists()
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    pawn = u.GameplayStatics.get_player_pawn(world, 0)
    systems = [s for s in u.ObjectIterator(u.EnhancedInputLocalPlayerSubsystem)
               if not s.get_path_name().startswith('/Script/')]
    assert pawn and len(systems) == 1
    subsystem = systems[0]
    action = u.load_asset('/Script/AngelscriptAssets.Mars_IA_Move')
    helper = u.new_object(u.load_class(None, '/Script/Angelscript.Mars_ExpeditionAcceptance'))
    begin = u.GameplayStatics.get_time_seconds(world)
    REPORT = dict(name=name, initial=list(pawn.get_actor_location().to_tuple()),
                  points=points, samples=[], reached=[],
                  boundary='Actual Enhanced Input movement and public camera aim requests. '
                           'No teleport, collision bypass, enemy/health or inventory mutation. '
                           'Automated path knowledge excludes novice and human pacing claims.')
    index = 0
    last_progress = begin
    previous = pawn.get_actor_location()

    def finish(reason):
        global HANDLE
        subsystem.inject_input_vector_for_action(action, u.Vector(), [], [])
        REPORT.update(result=reason, final=list(pawn.get_actor_location().to_tuple()),
                      elapsed=u.GameplayStatics.get_time_seconds(world)-begin,
                      inspection=helper.inspect(pawn))
        u.unregister_slate_pre_tick_callback(HANDLE)
        HANDLE = None
        output.write_text(json.dumps(REPORT, indent=2))
        print('ROUTE_PROBE_DONE', reason, str(output))

    def tick(delta):
        nonlocal index, last_progress, previous
        try:
            assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() == world
            now = u.GameplayStatics.get_time_seconds(world)
            at = pawn.get_actor_location()
            if not REPORT['samples'] or now-begin-REPORT['samples'][-1]['t'] >= .2:
                REPORT['samples'].append(dict(t=now-begin, at=list(at.to_tuple()), target=index))
            if (at-previous).length() > 5:
                previous, last_progress = at, now
            if now-begin > seconds:
                finish('timeout'); return
            if now-last_progress > 3:
                finish('stalled'); return
            target = points[index]
            dx, dy = target[0]-at.x, target[1]-at.y
            distance = math.hypot(dx, dy)
            if distance <= tolerance:
                REPORT['reached'].append(dict(index=index, t=now-begin, at=list(at.to_tuple())))
                index += 1
                if index == len(points):
                    finish('reached'); return
                target = points[index]
                dx, dy = target[0]-at.x, target[1]-at.y
                distance = math.hypot(dx, dy)
            # Keep the view fixed for this walking leg. Camera snap requests are deferred;
            # steering and moving against the previous camera basis made the initial
            # diagnostic orbit its target at low editor frame rates.
            camera = u.GameplayStatics.get_player_camera_manager(world, 0)
            angle = math.atan2(dy, dx)-math.radians(camera.get_camera_rotation().yaw)
            strength = min(1., distance/400.)
            subsystem.inject_input_vector_for_action(action,
                u.Vector(math.cos(angle)*strength, math.sin(angle)*strength, 0), [], [])
        except Exception as error:
            REPORT['error'] = str(error)
            finish('error')
            raise
    HANDLE = u.register_slate_pre_tick_callback(tick)
    return dict(started=True, output=str(output))
