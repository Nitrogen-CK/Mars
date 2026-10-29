"""Walk the saved Camp Hearthscrew with the production capsule, no route teleports.

Uses the source kit's audited tread waypoints. The initial placement is test setup.
"""
import importlib.util
import json
import math
from pathlib import Path
import unreal as u

HERE = Path(__file__).resolve().parent
STATE = None
HANDLE = None


def finish(status, error=None):
    global STATE, HANDLE
    u.unregister_slate_post_tick_callback(HANDLE)
    HANDLE = None
    STATE['pawn'].get_component_by_class(u.CharacterMovementComponent).stop_movement_immediately()
    report = {k: v for k, v in STATE.items() if k not in ('world', 'pawn', 'helper')}
    report['status'] = status
    if error:
        report['error'] = str(error)
    (HERE / 'Output/Runtime/route_review.json').write_text(json.dumps(report, indent=2))
    STATE = report  # Do not retain any world objects across the following travel test.
    print('STEWARD_ROUTE_REVIEW', status, report.get('error', ''), 'waypoints', report['index'], len(report['points']))


def tick(delta):
    try:
        s = STATE
        s['elapsed'] += float(delta)
        assert s['elapsed'] < 180, 'Route timed out'
        pawn = s['pawn']
        at = pawn.get_actor_location()
        target = s['points'][s['index']]
        x, y, z = target['at']
        dx, dy = x - at.x, y - at.y
        distance = math.hypot(dx, dy)
        feet = at.z - s['capsule_half_height']
        assert feet >= z - 100, f'Fell below route at {at}, target {target}'
        if s['elapsed'] < 2:
            return  # Let selection open the real gate and initial floor contact settle.
        if distance < 12 and abs(feet - z) < 48:
            s['index'] += 1
            s['stalled'] = 0
            if s['index'] == len(s['points']):
                pc = u.GameplayStatics.get_player_controller(s['world'], 0)
                u.SystemLibrary.execute_console_command(s['world'], 'Shot filename="' + str(HERE / 'Output/Runtime/06_Spire_Exit.png').replace('\\', '/') + '" -nosuffix', pc)
                finish('passed')
                return
        else:
            moved = math.dist(at.to_tuple(), s['last_at'])
            s['stalled'] = s['stalled'] + float(delta) if moved < .1 else 0
            assert s['stalled'] < 3, f'Blocked at {at}, target {target}'
            s['helper'].aim(pawn, u.Rotator(yaw=math.degrees(math.atan2(dy, dx))))
            pawn.add_movement_input(u.Vector(dx / distance, dy / distance, 0), min(1, max(.18, distance / 55)), False)
        s['last_at'] = list(at.to_tuple())
    except Exception as error:
        finish('failed', error)


def begin():
    global STATE, HANDLE
    assert HANDLE is None
    source = HERE.parent / 'SpireConnectorKit/pie_acceptance.py'
    spec = importlib.util.spec_from_file_location('spire_source_route', str(source))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.OFFSETS['HS'] = (1640, 0, 0)
    points = module.route_points('HS')
    # Include the original camp arch and its retained step; earlier kit-only runs started beyond this barrier.
    points = [dict(at=[x, 0, 0], label='camp interior and original arch')
              for x in (850, 1000, 1100, 1160, 1220, 1300)] + points
    # The source harness continues beyond the kit for a hypothetical receiving map.
    # Camp's actual receiving endpoint is the departure post, before that outer edge.
    points = [p for p in points if p['label'] != 'lower threshold' or p['at'][0] <= 3020]
    points.append(dict(at=[3020, 0, -1200], label='Camp departure post'))
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert world
    pc = u.GameplayStatics.get_player_controller(world, 0)
    pawn = pc.get_controlled_pawn()
    assert pawn.get_class().get_name() == 'Mars_PlayerCharacter'
    radius, half = pawn.get_component_by_class(u.CapsuleComponent).get_scaled_capsule_size()
    pc.call_method('Server_CommitService', (u.Name('DillBroth'),))
    x, y, z = points[0]['at']
    pawn.set_actor_location(u.Vector(x, y, z + half + 3), False, True)
    STATE = dict(world=world, pawn=pawn,
                 helper=u.new_object(u.load_class(None, '/Script/Angelscript.Mars_ExpeditionAcceptance'), outer=pc),
                 elapsed=0., points=points, index=1, stalled=0., last_at=list(pawn.get_actor_location().to_tuple()),
                 capsule_radius=radius, capsule_half_height=half, teleports_during_route=0,
                 scope='Production capsule, continuous CharacterMovement across every source tread waypoint after initial setup.')
    HANDLE = u.register_slate_post_tick_callback(tick)
