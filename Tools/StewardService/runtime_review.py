"""PIE capture choreography through real movement, raw Use and Slate button events.

Position changes are explicitly test setup between shots. No party/gate fragments
are written. All verdicts are observations of the production controller and gate.
"""
import json
import traceback
import time
from pathlib import Path
import unreal as u

OUT = Path(__file__).resolve().parent / 'Output/Runtime'
STATE = None
HANDLE = None


def vec(value):
    return list(value.to_tuple())


def board():
    kind = u.load_class(None, '/Script/Angelscript.Mars_ChalkService_Widget')
    return next((b for b in u.ObjectIterator(kind)
                 if b.get_name().startswith('ServiceParchment_Mars_WBP_C')
                 and b.get_owning_player() == STATE['pc']), None)


def presenter():
    kind = u.load_class(None, '/Script/Angelscript.Mars_CampUiPresenter')
    values = u.GameplayStatics.get_all_actors_of_class(STATE['world'], kind)
    assert len(values) == 1, 'Expected one local presenter'
    return values[0]


def gate():
    return (STATE['probe'].call_method('GetGateOpen', (STATE['pc'],)),
            STATE['probe'].call_method('GetGateAlpha', (STATE['pc'],)))


def snapshot(label):
    s = STATE
    party = u.GameplayStatics.get_game_state(s['world']).get_editor_property('_PartyState')
    row = dict(label=label, seconds=s['elapsed'], pawn=vec(s['pawn'].get_actor_location()),
               camera=vec(s['pawn'].get_editor_property('CameraComponent').get_world_location()),
               service=str(party.get_editor_property('ServiceId')), gate_open=gate()[0], gate_alpha=gate()[1],
               gloves_hidden=s['pawn'].get_editor_property('FPHands').get_editor_property('hidden_in_game'))
    surface = next((c for c in u.ObjectIterator(u.WidgetComponent) if c.get_widget() == board()), None)
    row['parchment_visible'] = bool(surface and surface.is_visible())
    row['parchment_component'] = surface.get_path_name() if surface else None
    s['report']['observations'].append(row)
    print('STEWARD_REVIEW', json.dumps(row))
    return row


def shot(label):
    u.SystemLibrary.execute_console_command(STATE['world'],
        'Shot filename="' + str(OUT / (label + '.png')).replace('\\', '/') + '" -nosuffix', STATE['pc'])


def place(location, rotation):
    STATE['pawn'].get_component_by_class(u.CharacterMovementComponent).stop_movement_immediately()
    STATE['pawn'].set_actor_location(u.Vector(*location), False, True)
    STATE['helper'].aim(STATE['pawn'], u.Rotator(pitch=rotation[0], yaw=rotation[1], roll=0))


def aim(point):
    location = STATE['pawn'].get_editor_property('CameraComponent').get_world_location()
    STATE['helper'].aim(STATE['pawn'], u.MathLibrary.find_look_at_rotation(location, u.Vector(*point)))


def use(pressed):
    assert STATE['helper'].use(STATE['pawn'], pressed), 'Raw Use injection rejected'


def focus(widget):
    presenter().get_editor_property('Interaction').set_focus(widget)


def enter(pressed):
    interaction = presenter().get_editor_property('Interaction')
    key = u.Key()
    key.import_text('Enter')
    (interaction.press_key if pressed else interaction.release_key)(key)


def finish(status):
    global HANDLE
    if HANDLE is not None:
        u.unregister_slate_post_tick_callback(HANDLE)
        HANDLE = None
    if STATE:
        STATE['report']['status'] = status
        STATE['report']['wall_seconds'] = time.monotonic() - STATE['started_wall']
        (OUT / 'review.json').write_text(json.dumps(STATE['report'], indent=2))
        current_world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
        if current_world == STATE['world'] and u.SystemLibrary.is_valid(STATE['pawn']):
            STATE['pawn'].get_component_by_class(u.CharacterMovementComponent).stop_movement_immediately()
    print('STEWARD_REVIEW_FINISHED', status)


def tick(delta):
    try:
        s = STATE
        if u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() != s['world']:
            s['report']['error'] = 'PIE ended before the review completed'
            finish('failed')
            return
        s['elapsed'] += float(delta)
        t = s['elapsed']
        # Continuous movement is used inside each gate test; never teleport across the gate.
        if .35 < t < 1.35 or 14 < t < 16.9:
            s['pawn'].add_movement_input(u.Vector(1, 0, 0), 1, True)
        events = [
            (1.4, lambda: closed_check()),
            (1.8, lambda: place((0, -850, 82), (0, -90))),
            (2.2, lambda: aim((0, -1055, 175))),
            (2.6, lambda: prompt_check()),
            (2.8, lambda: use(True)), (3.0, lambda: use(False)),
            (4.1, lambda: reading_check()),
            (5.0, lambda: focus(board().get_editor_property('ServiceRows').get_child_at(3))),
            (5.4, lambda: enter(True)), (5.6, lambda: enter(False)),
            (6.3, lambda: preview_check()),
            (7.0, lambda: focus(board().get_editor_property('Back'))),
            (7.2, lambda: enter(True)), (7.4, lambda: enter(False)),
            (8.1, lambda: back_check()),
            (8.7, lambda: use(True)), (8.9, lambda: use(False)),
            (9.9, lambda: focus(board().get_editor_property('ServiceRows').get_child_at(0))),
            (10.1, lambda: enter(True)), (10.3, lambda: enter(False)),
            (10.8, lambda: focus(board().get_editor_property('Confirm'))),
            (11.0, lambda: enter(True)), (11.2, lambda: enter(False)),
            (11.65, lambda: committed_check()),
            (11.75, lambda: place((850, 0, 82), (0, 0))),
            (12.05, lambda: aim((1220, 0, 155))),
            (13.0, lambda: open_check()),
            (17.2, lambda: passage_check()),
            (17.8, lambda: finish('passed')),
        ]
        for index, (when, callback) in enumerate(events):
            if t >= when and index not in s['fired']:
                s['fired'].add(index)
                callback()
    except Exception as error:
        STATE['report']['error'] = str(error)
        STATE['report']['traceback'] = traceback.format_exc()
        finish('failed')
        u.log_error('Steward review failed: ' + str(error))


def closed_check():
    row = snapshot('closed_gate_blocks_movement')
    assert not row['gate_open'] and 1120 < row['pawn'][0] < 1220, row
    shot('01_Gate_Closed')


def reading_check():
    assert board(), 'Use did not create the service board'
    row = snapshot('raw_use_opened_reading_view')
    assert row['gloves_hidden'] and not row['gate_open']
    assert abs(row['camera'][1] + 865) < 1, row
    assert STATE['probe'].call_method('GetPromptCount', (STATE['pawn'],)) == 0, 'World prompt remained during menu'
    for box in u.ObjectIterator(u.load_class(None, '/Script/Angelscript.Mars_InteractPromptBox_Widget')):
        if box.get_owning_player() == STATE['pc']:
            assert box.get_editor_property('PromptContainer').get_children_count() == 0, 'HUD prompt remained during menu'
    for mesh in u.ObjectIterator(u.SkeletalMeshComponent):
        if (mesh.get_path_name().startswith(STATE['world'].get_path_name() + ':') and mesh.get_skeletal_mesh_asset()
                and mesh.get_skeletal_mesh_asset().get_name() == 'Steward_Service_Mars_SK'):
            assert not mesh.get_editor_property('render_custom_depth'), 'Steward outline remained during menu'
    shot('02_Steward_Reading')


def prompt_check():
    s = STATE
    assert s['probe'].call_method('GetPromptCount', (s['pawn'],)) > 0
    kind = u.load_class(None, '/Script/Angelscript.Mars_InteractPrompt_Widget')
    prompts = [x for x in u.ObjectIterator(kind) if x.get_owning_player() == s['pc']
               and str(x.get_editor_property('PromptText').get_text()) == 'Speak to the Steward']
    assert len(prompts) == 1 and prompts[0].is_visible(), 'Steward prompt not rendered by HUD'
    meshes = [x for x in u.ObjectIterator(u.SkeletalMeshComponent)
              if x.get_path_name().startswith(s['world'].get_path_name() + ':')
              and x.get_skeletal_mesh_asset() and x.get_skeletal_mesh_asset().get_name() == 'Steward_Service_Mars_SK']
    assert len(meshes) == 1 and meshes[0].get_editor_property('render_custom_depth'), 'Steward outline missing'
    row = snapshot('idle_parchment_prompt_and_outline')
    assert row['parchment_visible']
    s['surface_identity'] = row['parchment_component']


def preview_check():
    title = str(board().get_editor_property('PreviewTitle').get_text())
    assert title.lower() == 'proper dinner', title
    assert not gate()[0], 'Preview opened the gate'
    snapshot('fourth_dish_preview_only')
    shot('03_Scrolled_Dish')


def back_check():
    row = snapshot('back_restored_chef_without_commit')
    assert not row['gloves_hidden'] and not row['gate_open'] and row['service'] == 'None', row
    assert row['parchment_visible'] and row['parchment_component'] == STATE['surface_identity'], row
    assert STATE['probe'].call_method('GetPromptCount', (STATE['pawn'],)) > 0, 'Back did not restore world prompt'


def committed_check():
    row = snapshot('slate_confirm_committed_dill_broth')
    assert row['service'] == 'DillBroth' and row['gate_open'], row
    assert row['parchment_visible'] and row['parchment_component'] == STATE['surface_identity'], row


def open_check():
    row = snapshot('gate_fully_open')
    assert row['gate_open'] and row['gate_alpha'] > .999, row
    shot('04_Gate_Open')


def passage_check():
    row = snapshot('physical_walk_through_open_gate')
    assert row['pawn'][0] > 1740 and row['gate_open'], row
    shot('05_Open_Gate_Passage')


def begin():
    global STATE, HANDLE
    assert HANDLE is None, 'A review is already active'
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert world, 'Start PIE'
    pc = u.GameplayStatics.get_player_controller(world, 0)
    pawn = pc.get_controlled_pawn()
    assert pawn and pawn.get_class().get_name() == 'Mars_PlayerCharacter', 'Chef not ready'
    helper_class = u.load_class(None, '/Script/Angelscript.Mars_ExpeditionAcceptance')
    probe_class = u.load_class(None, '/Script/Angelscript.Mars_StewardService_ReviewProbe')
    assert helper_class and probe_class
    OUT.mkdir(parents=True, exist_ok=True)
    STATE = dict(world=world, pc=pc, pawn=pawn, helper=u.new_object(helper_class, outer=pc),
                 probe=u.new_object(probe_class, outer=pc), elapsed=0., fired=set(), started_wall=time.monotonic(),
                 report=dict(status='running', setup='Teleports only between review shots; actual gate crossings use CharacterMovement.',
                             input='Gameplay Use through InputSource raw events; menu selection/Back/Confirm through WidgetInteraction Slate keys.',
                             observations=[]))
    (OUT / 'review.json').write_text(json.dumps(STATE['report'], indent=2))
    place((850, 0, 82), (0, 0))
    HANDLE = u.register_slate_post_tick_callback(tick)
    snapshot('initial')
    print('STEWARD_REVIEW_STARTED')
