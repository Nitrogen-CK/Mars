"""Apply a small reviewed static-art delta to an original LI and review maps.

Exact source/hash guards; new tagged HISM actors only. Collision data, source
geometry and existing actors remain untouched. Never saves a dirty foreign map.
"""
import hashlib
import importlib.util
import json
import shutil
from pathlib import Path

import unreal as u

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RUN = ROOT / 'Saved/WarrensCGameplay-20261024/ArtCheckpoint'
OWNER = 'Mars.WarrensC.LayoutArt.20261024'
MAPS = {
    'Mill': '/Game/Mars/Maps/Variants/v8c/LI_Warrens_Mill',
    'Diorama': '/Game/Mars/Environment/WarrensVariantCKit/Maps/WarrensVariantC_Diorama_Mars_MAP',
    'KitLibrary': '/Game/Mars/Environment/WarrensVariantCKit/Maps/WarrensVariantC_KitLibrary_Mars_MAP',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def collision_guard():
    hashes = json.loads((ROOT / 'Saved/WarrensCGameplay-20261024/StartupCheckpoint/collision_hashes.json').read_text())
    for path, expected in hashes.items():
        assert sha(ROOT / path) == expected, 'Collision bytes changed ' + path
    return len(hashes)


def checkpoint(path):
    manifest_path = RUN / 'manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    relative = path.relative_to(ROOT).as_posix()
    if relative not in manifest:
        destination = RUN / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        assert not destination.exists()
        shutil.copy2(path, destination)
        manifest[relative] = dict(sha256=sha(path), backup=destination.relative_to(ROOT).as_posix())
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    assert sha(ROOT / manifest[relative]['backup']) == manifest[relative]['sha256']
    return manifest[relative]


def main(target):
    assert target in MAPS
    ed = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    ea = u.get_editor_subsystem(u.EditorActorSubsystem)
    assert ed.get_game_world() is None
    assert ed.get_editor_world().get_path_name().split('.')[0] == MAPS[target]
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
    assert not u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
    delta_path = HERE / 'mill_art_delta.json'
    delta = json.loads(delta_path.read_text())
    ledger = HERE / 'Output/fitted_instances.json'
    assert sha(ledger) == delta['source_ledger_sha256']
    assert delta['remove'] == [] and delta.get('move', []) == [] and delta['lights'] == []
    assert len(delta['add']) == 1 and delta['add'][0]['id'] == 'WVC062'
    disk = ROOT / ('Content/' + MAPS[target].removeprefix('/Game/') + '.umap')
    before = sha(disk)
    if target == 'Mill' and not (RUN / 'applied_Mill.json').exists():
        assert before == 'd4fb10066f55db8517d8cd807c69d95b611c938486ce11b2f77eac301233cd81', 'Mill differs from reviewed gameplay state'
    receipt_path = RUN / ('applied_' + target + '.json')
    if receipt_path.exists():
        receipt = json.loads(receipt_path.read_text())
        assert before == receipt['after_sha256'] and sha(delta_path) == receipt['delta_sha256']
        print('LAYOUT_ART_ALREADY_APPLIED', target)
        return receipt
    assert not any(OWNER in [str(t) for t in actor.tags] for actor in ea.get_all_level_actors()), 'Unrecorded art actors'
    if target != 'Mill':
        assert all('Mars.WarrensVariantCKit.Authoring.v1' in [str(t) for t in actor.tags] for actor in ea.get_all_level_actors()), 'Foreign library/diorama actor'
    backup = checkpoint(disk)
    assert before == backup['sha256'], 'Unreviewed map change after checkpoint'
    count = collision_guard()
    spec = importlib.util.spec_from_file_location('layout_art_core', HERE.parent / 'ChainCrossingKit/unreal_scenes.py')
    core = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(core)
    core.OWNER = OWNER
    core.PREFIX = 'WVC_LayoutArt_'
    core.FOLDER = 'Warrens/LayoutArt/Mill'
    registry = {}
    for kit in ('ChainCrossingKit', 'PumpCisternKit', 'WarrensVariantCKit'):
        data = json.loads((HERE.parent / kit / 'Output/asset_manifest.json').read_text())
        registry.update({r['id']: '/Game/Mars/Environment/' + kit + '/Meshes/' + r['name'] for r in data['assets']})
    if target == 'KitLibrary':
        rows = [dict(id='WVC023', at=[60, 0, 0], role='Mill assembly example'), dict(id='WVC062', at=[60, 0, delta['add'][0]['at'][2] - 5], role='Mill assembly example')]
        pivot, plan_frame = (0, 0, 0), False
    else:
        rows = delta['add']
        pivot, plan_frame = ([78, 92, 5], True) if target == 'Mill' else ([58, 55, 0], True)
    for row in rows:
        assert u.load_asset(registry[row['id']]), row['id']
        asset = u.load_asset(registry[row['id']])
        source = Path(asset.get_editor_property('asset_import_data').get_first_filename())
        assert source.is_file() and u.EditorAssetLibrary.get_metadata_tag(asset, 'SourceSHA256') == sha(source), 'Mesh differs from import provenance'
    counts = core.add_instances(rows, pivot, plan_frame, registry, '/Game/Mars/Environment/ChainCrossingKit')
    settings = u.get_default_object(u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'))
    old = settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    try:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(old).DISABLE)
        assert u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
    finally:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', old)
    assert collision_guard() == count
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
    receipt = dict(target=target, map=MAPS[target], before_sha256=before, after_sha256=sha(disk), delta_sha256=sha(delta_path),
                   added_instances=sum(counts.values()), groups=counts, collision_files_preserved=count, checkpoint=backup,
                   scope='Static visual-only HISM addition, original materials/lights/geometry/controls unchanged.')
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    print('LAYOUT_ART_APPLIED', json.dumps(receipt))
    return receipt
