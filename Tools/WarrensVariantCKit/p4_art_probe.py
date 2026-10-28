"""Bounded actual-input P4 presentation observation; never forces puzzle state.

Requires the isolated current pawn and first dial already turned one detent.
No screenshots from Slate callbacks. Temporary render-light context is explicit.
"""
import json
import time
from pathlib import Path

import unreal as u

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/P4_ART_RUNTIME.json'
STATE = None
FLASH = None


def watch_wrong_flash():
    """Read-only frame observer; caller performs the real commit input."""
    global FLASH
    output = OUT.with_name('P4_ART_SAVED_FLASH.json')
    assert FLASH is None and not output.exists()
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    lamp = None
    candles = []
    for actor in u.GameplayStatics.get_all_actors_of_class(world, u.Actor):
        if 'Ck_UnrealComponent_Host' not in actor.get_name():
            continue
        for c in actor.get_components_by_class(u.StaticMeshComponent):
            name = str(u.Ck_Utils_Handle_UE.get_debug_name(u.Ck_Utils_UnrealComponent_UE.try_get_owning_handle_from_component(c)))
            if name.endswith('Bellkeeper_Lamp'):
                lamp = c
            elif name.endswith('Bellkeeper_Candle'):
                candles.append(c)
    assert lamp and len(candles) == 3
    FLASH = dict(start=time.monotonic(), changes=[], saw_red=False, callback=None)

    def rgb(component):
        v = component.get_material(0).get_vector_parameter_value('PrimaryColor')
        return [v.r, v.g, v.b]

    def tick(delta):
        color = rgb(lamp)
        state = dict(lamp=color, candles=[rgb(c) for c in candles])
        if not FLASH['changes'] or FLASH['changes'][-1]['state'] != state:
            FLASH['changes'].append(dict(t=u.GameplayStatics.get_time_seconds(world), state=state))
        FLASH['saw_red'] |= color[0] > .8 and color[1] < .15
        reset = FLASH['saw_red'] and max(color) < .1
        if reset or time.monotonic() - FLASH['start'] > 30:
            u.unregister_slate_pre_tick_callback(FLASH['callback'])
            output.write_text(json.dumps(dict(changes=FLASH['changes'], saw_red=FLASH['saw_red'], reset_observed=reset,
                boundary='Read-only per-frame material-parameter observation on the fresh saved opted-in P4 panel. Caller uses raw grip/look; no state or material values forced.'), indent=2) + '\n')
            print('P4_SAVED_FLASH_OBSERVER_DONE', FLASH['saw_red'], reset)
    FLASH['callback'] = u.register_slate_pre_tick_callback(tick)
    print('P4_SAVED_FLASH_OBSERVER_STARTED')


def start(output_name='P4_ART_RUNTIME.json', first_dial_look=60, include_wrong=True):
    global STATE
    output = OUT.with_name(output_name)
    assert Path(output_name).name == output_name and output.suffix == '.json'
    assert STATE is None and not output.exists()
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    pawn = u.GameplayStatics.get_player_pawn(world, 0)
    assert (pawn.get_actor_location() - u.Vector(3800, -730, 77.2)).length() < 1
    helper = u.new_object(u.load_class(None, '/Script/Angelscript.Mars_ExpeditionAcceptance'))
    components = []
    for actor in u.GameplayStatics.get_all_actors_of_class(world, u.Actor):
        if 'Ck_UnrealComponent_Host' not in actor.get_name():
            continue
        for component in actor.get_components_by_class(u.StaticMeshComponent):
            name = str(u.Ck_Utils_Handle_UE.get_debug_name(u.Ck_Utils_UnrealComponent_UE.try_get_owning_handle_from_component(component)))
            if name.endswith(('Bellkeeper_Lamp', 'Bellkeeper_Candle', 'Bellkeeper_Pointer')):
                components.append((name, component))
    assert len(components) == 7
    events = []

    def sample(label):
        rows = []
        for name, c in components:
            color = c.get_material(0).get_vector_parameter_value('PrimaryColor')
            rows.append(dict(part=name, at=list(c.get_world_location().to_tuple()), rotation=list(c.get_world_rotation().to_tuple()), color=[color.r, color.g, color.b, color.a]))
        events.append(dict(label=label, t=u.GameplayStatics.get_time_seconds(world), parts=rows))

    def aim(at):
        camera = u.GameplayStatics.get_player_camera_manager(world, 0)
        assert helper.aim(pawn, u.MathLibrary.find_look_at_rotation(camera.get_camera_location(), u.Vector(*at)))

    steps = [('initial', lambda: sample('initial'), .25), ('aim wrong commit', lambda: aim((3650, -860, 110)), .4),
             ('grip wrong commit', lambda: helper.use(pawn, True), .4), ('pull wrong commit', lambda: helper.look(pawn, u.Vector(0, 40, 0)), .18),
             ('wrong flash sample', lambda: sample('wrong_flash'), .15), ('release wrong commit', lambda: helper.use(pawn, False), 1.2),
             ('wrong reset sample', lambda: sample('wrong_reset'), .25)]
    if not include_wrong:
        steps = [('initial', lambda: sample('initial'), .25)]
    # First dial was observed at Circle after the separate real-input one-detent trial.
    for index, (x, delta) in enumerate([(3755, first_dial_look), (3800, 60), (3845, 120)]):
        steps += [(f'aim dial {index}', lambda x=x: aim((x, -866, 120)), .4),
                  (f'grip dial {index}', lambda: helper.use(pawn, True), .4),
                  (f'turn dial {index}', lambda delta=delta: helper.look(pawn, u.Vector(delta, 0, 0)), .4),
                  (f'release dial {index}', lambda: helper.use(pawn, False), .4)]
    steps += [('aim correct commit', lambda: aim((3650, -860, 110)), .4), ('grip correct commit', lambda: helper.use(pawn, True), .4),
              ('pull correct commit', lambda: helper.look(pawn, u.Vector(0, 40, 0)), .4), ('release correct commit', lambda: helper.use(pawn, False), .5),
              ('solved sample', lambda: sample('after_solve_attempt'), .4), ('center view', lambda: aim((3800, -872, 120)), .4)]
    STATE = dict(index=0, next=time.monotonic(), ticks=0, callback=None, helper=helper, events=events, steps=[], error=None)

    def finish(error=None):
        helper.use(pawn, False)
        u.unregister_slate_pre_tick_callback(STATE['callback'])
        report = dict(events=events, steps=STATE['steps'], error=error,
                      boundary='Actual raw Use/look on an isolated teleported pawn. First dial began at one observed detent. No dial/lock/reward state forced. Presentation is PIE-only material trial plus a temporarily repositioned lantern-light component for rendering, not a picked-up/held lantern or final game-lighting proof.')
        output.write_text(json.dumps(report, indent=2) + '\n')
        print('P4_ART_INPUT_PROBE_FINISHED', error)

    def tick(delta):
        try:
            assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() == world
            STATE['ticks'] += 1
            if STATE['ticks'] < 3 or time.monotonic() < STATE['next']:
                return
            if STATE['index'] == len(steps):
                finish()
                return
            label, action, delay = steps[STATE['index']]
            STATE['index'] += 1
            STATE['ticks'] = 0
            action()
            STATE['steps'].append(label)
            STATE['next'] = time.monotonic() + delay
        except Exception as error:
            finish(str(error))
    STATE['callback'] = u.register_slate_pre_tick_callback(tick)
    print('P4_ART_INPUT_PROBE_STARTED', len(steps))
