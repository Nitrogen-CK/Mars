"""Record isolated real-pawn mechanism observations without assigning game state."""
import hashlib
import json
from pathlib import Path
import unreal as u

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/mechanism-observations'


def capture(name):
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert world and 'UEDPIE_0_Warrens_VariantC_Mars_MAP' in world.get_path_name()
    pawn = u.GameplayStatics.get_player_pawn(world, 0)
    camera = u.GameplayStatics.get_player_camera_manager(world, 0)
    helper = u.new_object(u.load_class(None, '/Script/Angelscript.Mars_ExpeditionAcceptance'))
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / (name + '.png')
    assert not path.exists() and not path.with_suffix('.json').exists(), 'Preserve prior evidence'
    record = dict(world=world.get_path_name(), pawn=list(pawn.get_actor_location().to_tuple()),
        camera=list(camera.get_camera_location().to_tuple()),
        rotation_roll_pitch_yaw=list(camera.get_camera_rotation().to_tuple()),
        fov=camera.get_fov_angle(), world_time=u.GameplayStatics.get_time_seconds(world),
        player=helper.inspect(pawn).splitlines()[0],
        boundary='Isolated real pawn, existing saved lighting and ordinary input-driven state. '
                 'No forced inventory, mechanism, fuel or lighting state. Teleported observation '
                 'positions are not continuous route, first-access, duration or comprehension proof.')
    path.with_suffix('.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    u.AutomationLibrary.take_high_res_screenshot(1600, 1000, str(path), delay=.2)
    print('MECHANISM_CAPTURE_QUEUED', path)


def verify(name):
    path = OUT / (name + '.png')
    assert path.exists() and path.stat().st_size > 1000
    record = json.loads(path.with_suffix('.json').read_text(encoding='utf-8'))
    assert 'image_sha256' not in record, 'Do not rewrite an accepted observation'
    record['image_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    path.with_suffix('.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print('MECHANISM_CAPTURE_VERIFIED', path.name, record['image_sha256'])
