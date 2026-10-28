"""PIE acceptance helpers. Inject raw input through the same inbox as the Slate writer.

These are tooling inputs, not evidence of physical keyboard/focus behavior.
Run this file with editor Python file_scope=public, then use cookbook_tap/snapshot.
"""
import json
from pathlib import Path
import unreal

COOKBOOK_CAPTURE_ROOT = Path('D:/Repositories/CkRepos/Orion/Tools/BookMenuArt/StylizedR02/UnrealGameplay')
COOKBOOK_CAPTURE_ROOT.mkdir(exist_ok=True)
COOKBOOK_PROBE_EVENTS = []
COOKBOOK_PENDING_RELEASES = []

def cookbook_world():
    return unreal.EditorLevelLibrary.get_game_world()

def cookbook_key(key_name, pressed):
    world = cookbook_world()
    source = next(s for s in unreal.ObjectIterator(unreal.Ck_InputSource_Subsystem)
                  if s.get_world() == world).get_input_source()
    key = unreal.Key()
    key.set_editor_property('key_name', key_name)
    event = unreal.Ck_InputSource_RawEvent()
    event.set_editor_properties({
        'device_class': (unreal.Ck_InputSource_DeviceClass.MOUSE if 'Mouse' in key_name
                         else unreal.Ck_InputSource_DeviceClass.KEYBOARD),
        'key': key,
        'event_type': (unreal.Ck_InputSource_EventType.PRESSED if pressed
                       else unreal.Ck_InputSource_EventType.RELEASED)})
    request = unreal.Ck_Request_InputSource_InjectRawEvent()
    request.set_editor_property('event', event)
    unreal.Ck_Utils_InputSource_UE.request_inject_raw_event(
        source, request, unreal.Ck_Delegate_Request_OnCompleted())
    COOKBOOK_PROBE_EVENTS.append({'key': key_name, 'pressed': pressed,
                                  'game_time': unreal.GameplayStatics.get_time_seconds(world)})

def cookbook_tap(key_name):
    cookbook_key(key_name, True)
    world = cookbook_world()
    pending = {'world_path': world.get_path_name(),
               'release_time': unreal.GameplayStatics.get_time_seconds(world) + 0.15,
               'handle': None}
    def release(delta):
        current_world = cookbook_world()
        same_world = (current_world is not None and
                      current_world.get_path_name() == pending['world_path'])
        if not same_world or unreal.GameplayStatics.get_time_seconds(current_world) >= pending['release_time']:
            unreal.unregister_slate_post_tick_callback(pending['handle'])
            if same_world:
                cookbook_key(key_name, False)
            COOKBOOK_PENDING_RELEASES.remove(pending)
    pending['handle'] = unreal.register_slate_post_tick_callback(release)
    COOKBOOK_PENDING_RELEASES.append(pending)

def cookbook_snapshot(label):
    world = cookbook_world()
    pc = unreal.GameplayStatics.get_player_controller(world, 0)
    camera = unreal.GameplayStatics.get_player_camera_manager(world, 0)
    books = [c for c in unreal.ObjectIterator(unreal.SkeletalMeshComponent)
             if c.get_world() == world and 'CookbookPresentation' in c.get_class().get_name()]
    result = {'label': label, 'world': world.get_path_name(),
              'game_time': unreal.GameplayStatics.get_time_seconds(world),
              'rotation_tuple_order': ['roll', 'pitch', 'yaw'],
              'camera_location': camera.get_camera_location().to_tuple(),
              'camera_rotation': camera.get_camera_rotation().to_tuple(),
              'control_rotation': pc.get_control_rotation().to_tuple(),
              'events': list(COOKBOOK_PROBE_EVENTS), 'books': []}
    for book in books:
        result['books'].append({
            'name': book.get_name(), 'location': book.get_world_location().to_tuple(),
            'rotation': book.get_world_rotation().to_tuple(),
            'scale': book.get_world_transform().scale3d.to_tuple(),
            'reading_hand_offset': book.get_editor_property('ReadingHandOffset').to_tuple(),
            'reading_grip_below_centre': book.get_editor_property('ReadingGripBelowCentre'),
            'animation_speed': book.get_editor_property('global_anim_rate_scale'),
            'visible': book.is_visible(), 'engine_tick_enabled': book.is_component_tick_enabled(),
            'state': str(book.get_editor_property('_State')),
            'section': book.get_editor_property('_PageSectionIndex'),
            'sections': min(len(book.get_editor_property('LeftPages')), len(book.get_editor_property('RightPages'))),
            'position': book.get_position(),
            'page_materials': [book.get_material(slot).get_path_name() for slot in range(2, 6)],
            'page_targets': [str(book.get_material(slot).get_texture_parameter_value('BC'))
                             if isinstance(book.get_material(slot), unreal.MaterialInstanceDynamic) else None
                             for slot in range(2, 6)]})
    (COOKBOOK_CAPTURE_ROOT/(label+'.json')).write_text(json.dumps(result, indent=2))
    unreal.AutomationLibrary.take_high_res_screenshot(
        1280, 720, str(COOKBOOK_CAPTURE_ROOT/(label+'.png')))
    print('COOKBOOK_SNAPSHOT '+json.dumps(result))
    return result


def cookbook_capture_after(delay_seconds, label):
    world = cookbook_world()
    pending = {'world_path': world.get_path_name(),
               'capture_time': unreal.GameplayStatics.get_time_seconds(world) + delay_seconds,
               'handle': None}
    def capture(delta):
        current_world = cookbook_world()
        same_world = (current_world is not None and
                      current_world.get_path_name() == pending['world_path'])
        if not same_world or unreal.GameplayStatics.get_time_seconds(current_world) >= pending['capture_time']:
            unreal.unregister_slate_post_tick_callback(pending['handle'])
            if same_world:
                cookbook_snapshot(label)
    pending['handle'] = unreal.register_slate_post_tick_callback(capture)


def cookbook_trace_turn(label, key_name='E', seconds=2.2):
    world = cookbook_world()
    pending = {'world_path': world.get_path_name(),
               'start': unreal.GameplayStatics.get_time_seconds(world),
               'last': -1.0, 'frames': [], 'handle': None}
    def sample(delta):
        current_world = cookbook_world()
        if current_world is None or current_world.get_path_name() != pending['world_path']:
            unreal.unregister_slate_post_tick_callback(pending['handle'])
            return
        now = unreal.GameplayStatics.get_time_seconds(current_world)
        if now == pending['last']:
            return
        pending['last'] = now
        book = next(c for c in unreal.ObjectIterator(unreal.SkeletalMeshComponent)
                    if c.get_world() == current_world and 'CookbookPresentation' in c.get_class().get_name())
        pose = book.get_socket_transform('PageTurn_01', unreal.RelativeTransformSpace.RTS_COMPONENT)
        q = pose.rotation
        pending['frames'].append({'time': now-pending['start'], 'position': book.get_position(),
                                  'state': str(book.get_editor_property('_State')),
                                  'section': book.get_editor_property('_PageSectionIndex'),
                                  'leaf_translation_cm': pose.translation.to_tuple(),
                                  'leaf_quaternion': [q.x,q.y,q.z,q.w]})
        if now-pending['start'] >= seconds:
            unreal.unregister_slate_post_tick_callback(pending['handle'])
            (COOKBOOK_CAPTURE_ROOT/(label+'.json')).write_text(json.dumps(pending['frames'],indent=2))
            print('COOKBOOK_TRACE_SAVED '+label)
    pending['handle'] = unreal.register_slate_post_tick_callback(sample)
    cookbook_tap(key_name)

print('COOKBOOK_PROBE_READY')
