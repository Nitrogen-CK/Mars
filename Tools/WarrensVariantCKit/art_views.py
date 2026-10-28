"""Matched isolated real-pawn art views; no puzzle, inventory, light or map writes.

Position and capture are separate editor calls so the camera can settle. These
are visual comparison views, never evidence of a walked approach or pacing.
"""
import hashlib
import json
from pathlib import Path
import unreal as u

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
VIEWS = {
    'sluice': ((5000, -4300, -172.8), (5200, -4350, -150)),
    'west': ((-300, -3500, -172.8), (1200, -3500, -150)),
    'east': ((2350, -3500, -172.8), (600, -3500, -150)),
    'west_approach': ((-400, -3200, -172.8), (-180, -3500, -150)),
    # Source SEAM_Reliquary__Mill__mill floor: 5.1522375023 - 1.4 m.
    'mill_stair': ((3400, 4600, 452.42375023), (2500, 4550, 755)),
    'mill_floor': ((1600, 4400, 577.2), (2500, 4550, 735)),
    'bellkeeper': ((3800, -730, 77.2), (3800, -872, 120)),
    'clue': ((-2200, -500, 77.2), (3200, -500, 200)),
    'clue_close': ((1500, -450, 77.2), (3176, -500, 300)),
}
VIEWS['east_partial'] = VIEWS['east']
VIEWS['east_seated'] = VIEWS['east']
VIEWS['west_seated'] = VIEWS['west']


def context():
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert world and 'UEDPIE_0_Warrens_VariantC_Mars_MAP' in world.get_path_name()
    pawn = u.GameplayStatics.get_player_pawn(world, 0)
    camera = u.GameplayStatics.get_player_camera_manager(world, 0)
    helper = u.new_object(u.load_class(None, '/Script/Angelscript.Mars_ExpeditionAcceptance'))
    return world, pawn, camera, helper


def position(name):
    world, pawn, camera, helper = context()
    at, target = VIEWS[name]
    assert pawn.teleport(u.Vector(*at), u.Rotator())
    eye = u.Vector(at[0], at[1], at[2] + 34.8)
    assert helper.aim(pawn, u.MathLibrary.find_look_at_rotation(eye, u.Vector(*target)))
    print('ART_VIEW_POSITIONED', name, at)


def capture(stage, name):
    assert stage in ('stage1', 'stage2', 'mill', 'held', 'observe')
    world, pawn, camera, helper = context()
    assert (pawn.get_actor_location() - u.Vector(*VIEWS[name][0])).length() < 1
    path = capture_path(stage, name)
    assert not path.exists(), 'Preserve prior captures'
    record = dict(world=world.get_path_name(), pawn=list(pawn.get_actor_location().to_tuple()),
                  camera=list(camera.get_camera_location().to_tuple()),
                  rotation_roll_pitch_yaw=list(camera.get_camera_rotation().to_tuple()),
                  fov=camera.get_fov_angle(), world_time=u.GameplayStatics.get_time_seconds(world),
                  inventory=helper.inspect(pawn).splitlines()[0],
                  boundary='Isolated teleported real pawn; existing game lighting, no held lantern or forced puzzle state. Matched art comparison only, not walked approach, comprehension, cargo or final lighting acceptance.')
    if stage == 'held':
        assert 'Item (Mars_ItemDef_Lantern)' in record['inventory']
        lights = [c for a in u.GameplayStatics.get_all_actors_of_class(world, u.Actor)
                  if 'Ck_UnrealComponent_Host' in a.get_name()
                  for c in a.get_components_by_class(u.PointLightComponent)
                  if (c.get_world_location() - pawn.get_actor_location()).length() < 250 and c.is_visible()]
        assert len(lights) == 1 and lights[0].intensity > 0 and lights[0].attenuation_radius == 700
        record['actual_held_light'] = dict(at=list(lights[0].get_world_location().to_tuple()), intensity=lights[0].intensity, radius=lights[0].attenuation_radius)
        record['boundary'] = 'Isolated teleported real pawn with actually picked-up lantern, opened by raw Use. Actual held light, no diagnostic light or inventory/puzzle state assignments. Visual evidence only, not walked route, pacing or novice comprehension.'
    if stage == 'observe':
        assert 'held=TOMBSTONE' in record['inventory']
        record['boundary'] = 'Isolated teleported real pawn, empty hands, existing saved game lighting. No diagnostic lighting, puzzle state or map changes. Visual reading position observation, not walked route or novice comprehension.'
    assert abs(record['fov'] - 90) < .01
    path.with_suffix('.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    u.AutomationLibrary.take_high_res_screenshot(1600, 1000, str(path), delay=.2)
    print('ART_VIEW_CAPTURE_QUEUED', path)


def verify_capture(stage, name):
    path = capture_path(stage, name)
    assert path.exists() and path.stat().st_size > 1000
    record = json.loads(path.with_suffix('.json').read_text(encoding='utf-8'))
    record['image_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    path.with_suffix('.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print('ART_VIEW_CAPTURE_VERIFIED', path.name, record['image_sha256'])


def capture_path(stage, name):
    if stage == 'mill':
        return OUT / ('mill-composition/Unreal_' + name + '.png')
    if stage == 'held':
        return OUT / ('ART_held_' + name + '.png')
    if stage == 'observe':
        return OUT / ('ART_observe_' + name + '.png')
    return OUT / ('P2_' + stage + '_' + name + '.png')
