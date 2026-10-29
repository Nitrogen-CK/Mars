"""Observe production host RPC travel/return/reset in PIE; retain no world objects across travel.

Menu input and physical traversal are covered separately by runtime_review.py.
This probe commits and requests travel through the real controller RPCs.
"""
import json
from pathlib import Path
import unreal as u

OUT = Path(__file__).resolve().parent / 'Output/Runtime'
STATE = None
HANDLE = None


def finish(status, error=None):
    global HANDLE
    if HANDLE is not None:
        u.unregister_slate_post_tick_callback(HANDLE)
        HANDLE = None
    STATE['status'] = status
    if error:
        STATE['error'] = str(error)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'travel_review.json').write_text(json.dumps(STATE, indent=2))
    print('STEWARD_TRAVEL_REVIEW', json.dumps(STATE))


def tick(delta):
    try:
        s = STATE
        s['elapsed'] += float(delta)
        assert s['elapsed'] < 120, 'Travel review timed out'
        world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
        if not world:
            return
        pc = u.GameplayStatics.get_player_controller(world, 0)
        if not pc or not pc.get_controlled_pawn():
            return
        gi = u.GameplayStatics.get_game_instance(world)
        flow = u.find_object(None, gi.get_path_name() + '.Mars_LanFlow_Subsystem_0')
        if not flow:
            return
        path = world.get_path_name()
        state = str(flow.get_state())
        stage = s['stage']
        if stage == 0 and 'Camp_Mars_MAP' in path and 'CONNECTED' in state.upper():
            pc.call_method('Server_CommitService', (u.Name('DillBroth'),))
            s['stage'] = 1
        elif stage == 1:
            party = u.GameplayStatics.get_game_state(world).get_editor_property('_PartyState')
            if str(party.get_editor_property('ServiceId')) != 'DillBroth':
                return
            s['events'].append(dict(event='host_committed', world=path, flow=state))
            pc.call_method('Server_RequestDepart')
            s['stage'] = 2
        elif stage == 2 and 'Warrens_Mars_MAP' in path and 'CONNECTED' in state.upper():
            assert pc.get_controlled_pawn().get_class().get_name() == 'Mars_PlayerCharacter'
            assert str(flow.call_method('GetCommittedServiceId')) == 'DillBroth'
            s['events'].append(dict(event='arrived_warrens_with_service', world=path, flow=state))
            u.SystemLibrary.execute_console_command(world, 'Shot filename="' + str(OUT / '06_Warrens_Arrival.png').replace('\\', '/') + '" -nosuffix', pc)
            s['ready_at'] = s['elapsed'] + 1
            s['stage'] = 3
        elif stage == 3 and s['elapsed'] >= s['ready_at']:
            pc.call_method('Server_ReturnToCamp')
            s['stage'] = 4
        elif stage == 4 and 'Camp_Mars_MAP' in path and 'CONNECTED' in state.upper():
            party = u.GameplayStatics.get_game_state(world).get_editor_property('_PartyState')
            if str(party.get_editor_property('ServiceId')) != 'DillBroth':
                return
            probe = u.new_object(u.load_class(None, '/Script/Angelscript.Mars_StewardService_ReviewProbe'), outer=pc)
            if probe.call_method('GetGateAlpha', (pc,)) < .999:
                return
            assert probe.call_method('GetGateOpen', (pc,))
            s['events'].append(dict(event='hosted_return_retained_service_and_open_gate', world=path, flow=state))
            flow.call_method('ReturnToMenu')
            s['stage'] = 5
        elif stage == 5 and 'Camp_Mars_MAP' in path and 'IDLE' in state.upper():
            party = u.GameplayStatics.get_game_state(world).get_editor_property('_PartyState')
            assert str(party.get_editor_property('ServiceId')) == 'None'
            probe = u.new_object(u.load_class(None, '/Script/Angelscript.Mars_StewardService_ReviewProbe'), outer=pc)
            assert not probe.call_method('GetGateOpen', (pc,))
            assert probe.call_method('GetGateAlpha', (pc,)) == 0
            s['events'].append(dict(event='return_to_menu_cleared_service_and_closed_gate', world=path, flow=state,
                                    pawn=pc.get_controlled_pawn().get_class().get_name()))
            finish('passed')
    except Exception as error:
        finish('failed', error)


def begin():
    global STATE, HANDLE
    assert HANDLE is None
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    STATE = dict(status='running', stage=0, elapsed=0., events=[],
                 scope='PIE production host controller RPC commit/depart/return/reset; no menu input or traversal claim.')
    HANDLE = u.register_slate_post_tick_callback(tick)
