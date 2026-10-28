"""Reversible PIE-only Mill material trial, with exact per-slot restoration."""
import hashlib
import json
from pathlib import Path

import unreal as u

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/lookdev/mill-material'
SOURCE = '/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'
CANDIDATE = '/Game/Mars/Environment/WarrensVariantCKit/Lookdev/BrushR03/Materials/M_CCK_'
SLOTS = []
RECEIPT = {}


def begin():
    assert not SLOTS
    w = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert w and 'UEDPIE' in w.get_path_name()
    p = u.GameplayStatics.get_player_pawn(w, 0)
    camera = u.GameplayStatics.get_player_camera_manager(w, 0)
    for actor in u.GameplayStatics.get_all_actors_of_class(w, u.Actor):
        if 'LI_Warrens_Mill' not in actor.get_path_name():
            continue
        for component in actor.get_components_by_class(u.StaticMeshComponent):
            for slot, material in enumerate(component.get_materials()):
                if not material:
                    continue
                key = next((key for key in ('TX01', 'TX02') if material.get_path_name() == SOURCE + key + '.M_CCK_' + key), None)
                if key:
                    candidate = u.load_asset(CANDIDATE + key)
                    assert candidate
                    SLOTS.append((component, slot, material, candidate))
    assert SLOTS, 'No exact original Mill material slots found'
    RECEIPT.update(world=w.get_path_name(), pawn=list(p.get_actor_location().to_tuple()),
                   camera=list(camera.get_camera_location().to_tuple()), rotation=list(camera.get_camera_rotation().to_tuple()), fov=camera.get_fov_angle(),
                   slots=[dict(component=c.get_path_name(), slot=i, original=m.get_path_name(), candidate=n.get_path_name(), collision=str(c.get_collision_profile_name())) for c, i, m, n in SLOTS],
                   boundary='Isolated teleported real pawn, empty hands, existing game lighting. No held-lantern acceptance claimed. PIE material overrides only; no map, collision, light or exposure edits. Not a played approach or final art acceptance.')
    print('MILL_MATERIAL_TRIAL_READY', len(SLOTS))


def switch(candidate):
    assert SLOTS
    for component, slot, original, replacement in SLOTS:
        component.set_material(slot, replacement if candidate else original)
    print('MILL_MATERIAL_TRIAL_SWITCH', candidate, len(SLOTS))


def capture(label):
    w = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    camera = u.GameplayStatics.get_player_camera_manager(w, 0)
    record = dict(camera=list(camera.get_camera_location().to_tuple()), rotation=list(camera.get_camera_rotation().to_tuple()), fov=camera.get_fov_angle(), world_time=u.GameplayStatics.get_time_seconds(w))
    RECEIPT.setdefault('captures', {})[label] = record
    u.AutomationLibrary.take_high_res_screenshot(1600, 1000, str(OUT / (label + '.png')), delay=.2)
    (OUT / 'pie_trial.json').write_text(json.dumps(RECEIPT, indent=2) + '\n')
    print('MILL_MATERIAL_CAPTURE_QUEUED', label)


def finish():
    switch(False)
    assert all(c.get_material(i) == m for c, i, m, _ in SLOTS)
    RECEIPT['restored_all_slots'] = True
    for label, row in RECEIPT.get('captures', {}).items():
        file = OUT / (label + '.png')
        assert file.exists()
        row['sha256'] = hashlib.sha256(file.read_bytes()).hexdigest()
    (OUT / 'pie_trial.json').write_text(json.dumps(RECEIPT, indent=2) + '\n')
    print('MILL_MATERIAL_TRIAL_RESTORED', len(SLOTS))
