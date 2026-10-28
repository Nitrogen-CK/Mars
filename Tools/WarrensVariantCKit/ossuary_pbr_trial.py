"""PIE-only material comparison on the saved wall partition. No save or state cheats."""
import copy
import hashlib
import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SOURCE = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryWallMaterialCheckpoint/audit_reloaded_20261026T005527_886384Z/receipt.json'
SOURCE_SHA = '64dc4d3062fc64427a9bac19c1c5e1a6ceb90183dab8f0e922e503ac69e8674a'
ASSETS = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryPbrTrial/created_20261026T005238_464255Z.json'
ASSETS_SHA = '63f8611292a52126dd8973d8ce1398e59f6e9b6ce580d36745c03fdcc1347354'
OWNERS = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryPbrTrial/owners_editor_verified_20261026T005834_766133Z.json'
OWNERS_SHA = '1f58c8e8023a10e9356cb9c35aae0f828761f3a928f1cc1be0b20f6baf1693ba'
CORE = HERE / 'bank_identity_unreal.py'
CORE_SHA = '4859e7ab71dc9e0a5d93b61511eb759ef741598af4821ba62df69cd8ee014619'
OUT = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryPbrTrial'
STATE = None


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def core():
    assert sha(CORE) == CORE_SHA
    spec = importlib.util.spec_from_file_location('_ossuary_pbr_frozen_core', CORE)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def write(phase, record):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / ('pie_' + phase + '_' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '.json')
    assert not path.exists()
    path.write_text(json.dumps(dict(record, tool_sha256=sha(__file__)), indent=2) + '\n')
    return dict(receipt=path.relative_to(ROOT).as_posix(), sha256=sha(path))


def begin():
    import unreal as u
    global STATE
    assert STATE is None and sha(SOURCE) == SOURCE_SHA and sha(ASSETS) == ASSETS_SHA
    assert sha(OWNERS) == OWNERS_SHA
    source = json.loads(SOURCE.read_text())
    assets = json.loads(ASSETS.read_text())
    helper = core()
    assert helper._dirty() == dict(maps=[], content=[])
    guards = source['protected_files']
    assert len(guards) == 614 and all(sha(ROOT / p) == value for p, value in guards.items())
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert world and 'UEDPIE_0_Warrens_VariantC_Mars_MAP' in world.get_path_name()
    actors, baseline = helper._hism_snapshot(world)
    room = [a for a in actors if 'LI_Warrens_Ossuary' in a.get_level().get_path_name()]
    assert len({a.get_level().get_path_name() for a in room}) == 1
    assert sum(len(a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)) for a in room) == 22
    by_label = {}
    for actor in room:
        by_label.setdefault(actor.get_actor_label(), []).append(actor)
    source_hisms = [(a['label'], c['hism']) for a in source['source_roster_after'].values()
                    for c in a['components'].values() if 'hism' in c]
    source_actors = {a['label']: a for a in source['source_roster_after'].values()}
    assert len(source_hisms) == 22
    targets = []
    matched = 0
    for label, expected in source_hisms:
        actor, = by_label[label]
        assert sorted(str(t) for t in actor.tags) == source_actors[label]['tags']
        assert bool(actor.hidden) == source_actors[label]['hidden']
        component, = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        assert helper._package(component.static_mesh) == expected['mesh']
        assert [helper._package(m) for m in component.get_materials()] == expected['materials']
        assert component.get_instance_count() == len(expected['instances'])
        actual = helper._component(component)
        for field in ('mesh', 'materials', 'visible', 'hidden_in_game', 'cast_shadow', 'collision_profile',
                      'collision_enabled', 'collision_type', 'body_instance', 'generate_overlap_events',
                      'custom_data_floats', 'random_seed', 'cull_start', 'cull_end'):
            assert actual[field] == expected[field], (label, field)
        for index, pose in enumerate(expected['instances']):
            local = u.Transform(location=u.Vector(*pose['at']), rotation=u.Quat(*pose['q']).rotator(),
                scale=u.Vector(*pose['scale']))
            wanted = u.MathLibrary.compose_transforms(local, actor.get_level_transform())
            assert helper._near(component.get_instance_transform(index, world_space=True), wanted), (label, index)
            matched += 1
        if label in ('WVC_CCS15', 'WVC_OssuaryWallSeamBacking_C'):
            assert component.get_instance_count() == 597 and component.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
            targets.append((component, component.get_material(0)))
    assert matched == 2710 and len(targets) == 2
    variants = {}
    source_material_file = ROOT / ('Content/' + assets['source'].removeprefix('/Game/') + '.uasset')
    assert sha(source_material_file) == '11376944ff6bd25178376d6fee7ac754c4ace383a12323c8f51bf6d6fd485859'
    asset_files = {source_material_file.relative_to(ROOT).as_posix(): sha(source_material_file)}
    owners = {r['path']: r for r in json.loads(OWNERS.read_text())['assets']}
    for record in assets['assets']:
        file = ROOT / ('Content/' + record['path'].removeprefix('/Game/') + '.uasset')
        assert sha(file) == record['package_sha256']
        value = u.load_asset(record['path'])
        assert isinstance(value, u.Material)
        assert owners[record['path']]['owner'] == 'Mars.WarrensC.OssuaryPbrTrial.R01'
        assert owners[record['path']]['package_sha256'] == record['package_sha256']
        variants[record['stage']] = value
        asset_files[file.relative_to(ROOT).as_posix()] = record['package_sha256']
    assert set(variants) == {'NormalOnly', 'RoughnessOnly'}
    STATE = dict(world=world, baseline=baseline, guards={**guards, **asset_files}, targets=targets,
        variants=variants, stage='Base')
    return dict(status='READY_SAVED_WALL_PARTITION', **write('ready', dict(matched_source_instances=matched,
        source_hisms=22, target_instances=1194, full_world_hisms=len(baseline), source_receipt_sha256=SOURCE_SHA,
        baseline=baseline, dirty=helper._dirty())))


def verify():
    import unreal as u
    assert STATE and u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() == STATE['world']
    helper = core()
    _, current = helper._hism_snapshot(STATE['world'])
    expected = copy.deepcopy(STATE['baseline'])
    for component, original in STATE['targets']:
        value = original if STATE['stage'] == 'Base' else STATE['variants'][STATE['stage']]
        expected[component.get_path_name()]['materials'][0] = helper._package(value)
    assert current == expected
    assert all(sha(ROOT / p) == value for p, value in STATE['guards'].items())
    assert helper._dirty() == dict(maps=[], content=[])
    return dict(stage=STATE['stage'], full_hism_roster_exact=True, guards_exact=True, dirty=helper._dirty())


def switch(stage):
    assert STATE and stage in ('Base', 'NormalOnly', 'RoughnessOnly')
    verify()
    for component, original in STATE['targets']:
        component.set_material(0, original if stage == 'Base' else STATE['variants'][stage])
    STATE['stage'] = stage
    return dict(**verify(), **write(stage, dict(stage=stage, target_instances=1194)))


def finish():
    global STATE
    result = switch('Base')
    result.update(status='RESTORED_SAVED_WALL_MATERIALS', **write('restored', result))
    STATE = None
    return result
