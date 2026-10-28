"""Read-only cached combat observation; no actions or world state requests."""
import json
from pathlib import Path
import unreal as u

HANDLE = None
REPORT = None


def start(name, seconds=45):
    global HANDLE, REPORT
    assert HANDLE is None
    output = Path(__file__).resolve().parents[2] / 'Saved/WarrensCGameplay-20261024' / (name + '.json')
    assert not output.exists()
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    pawn = u.GameplayStatics.get_player_pawn(world, 0)
    helper = u.new_object(u.load_class(None, '/Script/Angelscript.Mars_ExpeditionAcceptance'))
    begin = u.GameplayStatics.get_time_seconds(world)
    REPORT = dict(initial_world_t=begin, samples=[],
                  boundary='Read-only cached combat/target/ward observations. '
                           'No action evaluation, attack, health, pose or inventory mutation.')

    def tick(delta):
        global HANDLE
        try:
            assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() == world
            now = u.GameplayStatics.get_time_seconds(world)
            if not REPORT['samples'] or now-begin-REPORT['samples'][-1]['t'] >= .5:
                REPORT['samples'].append(dict(t=now-begin,
                    delta=u.GameplayStatics.get_world_delta_seconds(world),
                    at=list(pawn.get_actor_location().to_tuple()),
                    state=helper.inspect(pawn), combat=helper.inspect_crawler_combat(pawn)))
            if now-begin >= seconds:
                u.unregister_slate_pre_tick_callback(HANDLE)
                HANDLE = None
                output.write_text(json.dumps(REPORT, indent=2))
                print('COMBAT_PROBE_DONE', str(output))
        except Exception as error:
            REPORT['error'] = str(error)
            u.unregister_slate_pre_tick_callback(HANDLE)
            HANDLE = None
            output.write_text(json.dumps(REPORT, indent=2))
            raise
    HANDLE = u.register_slate_pre_tick_callback(tick)
    return dict(started=True, output=str(output))
