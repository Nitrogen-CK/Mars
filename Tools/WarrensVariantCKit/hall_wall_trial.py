"""Unsaved, bounded Hall wall material trial for Variant C.

Importing this module does nothing. The caller supplies the approved asset,
selection, and reload-audit receipts. The helper never saves a map or calls a
level-loading API; after PIE it returns the dirty trial to the caller for the
explicit Monolith discard/reload wrapper, then verifies the reloaded baseline.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
import types
import uuid
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RUN = ROOT / 'Saved/WarrensCGameplay-20261024/HallWallTrial'
MAP = '/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'
SELECTION = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/lookdev/hall-painterly-r01/room-west-coverage-r04/receipt.json'
FIT = HERE / 'Output/fitted_instances.json'
PIVOT = (4.0, 36.0, 0.0)
CORE_FILE = HERE / 'bank_identity_unreal.py'
CORE_SHA256 = '4859e7ab71dc9e0a5d93b61511eb759ef741598af4821ba62df69cd8ee014619'
COLLISION = ROOT / 'Saved/WarrensCGameplay-20261024/StartupCheckpoint/collision_hashes.json'
STATE_MODULE = '_mars_wvc_hall_wall_trial_state'
OWNER = 'Mars.WarrensC.HallWallTrial.20261026'
LABELS = {
    ('CCS15', 0): 'WVC_HallWall_CCS15_NormalX_Trial',
    ('CCS15', 1): 'WVC_HallWall_CCS15_NormalY_Trial',
    ('BACKING_TX01', 0): 'WVC_HallWall_BACKING_TX01_NormalX_Trial',
    ('BACKING_TX01', 1): 'WVC_HallWall_BACKING_TX01_NormalY_Trial',
}


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _write(kind, record):
    RUN.mkdir(parents=True, exist_ok=True)
    token = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '_' + uuid.uuid4().hex[:8]
    path = RUN / (kind + '_' + token + '.json')
    assert not path.exists(), 'Refuse to overwrite a trial receipt'
    output = dict(record, schema=1, created_utc=datetime.now(timezone.utc).isoformat(),
                  tool_sha256=_sha(__file__))
    path.write_text(json.dumps(output, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    return dict(file=path.relative_to(ROOT).as_posix(), sha256=_sha(path), phase=output.get('phase'),
                status=output.get('status'))


def _u():
    import unreal
    return unreal


def _package(value):
    return value.get_path_name().split('.')[0] if value else None


def _dirty(u):
    return dict(
        maps=sorted(_package(x) for x in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()),
        content=sorted(_package(x) for x in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()))


def _core():
    assert _sha(CORE_FILE) == CORE_SHA256, 'Pinned live-HISM helper changed'
    if '_wvc_hall_bank_identity_core' not in sys.modules:
        spec = importlib.util.spec_from_file_location('_wvc_hall_bank_identity_core', CORE_FILE)
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules[spec.name] = module
    return sys.modules['_wvc_hall_bank_identity_core']


def _state():
    if STATE_MODULE not in sys.modules:
        sys.modules[STATE_MODULE] = types.ModuleType(STATE_MODULE)
        sys.modules[STATE_MODULE].active = None
    return sys.modules[STATE_MODULE]


def _receipt(path, expected_sha, allowed_root, phase):
    path = Path(path)
    if not path.is_absolute():
        path = ROOT / path
    path = path.resolve()
    assert path.is_relative_to(allowed_root.resolve()) and path.is_file()
    assert _sha(path) == expected_sha, (phase, 'receipt hash changed')
    data = _json(path)
    assert data.get('phase') == phase and data.get('schema') == 1, (phase, data.get('phase'))
    return path, data


def _verify_guards(guards):
    assert isinstance(guards, dict) and len(guards) >= 634
    for relative, digest in guards.items():
        path = (ROOT / relative).resolve()
        assert path.is_relative_to(ROOT.resolve()) and path.is_file()
        assert _sha(path) == digest, ('guard changed', relative)
    return True


def _collision_map(guards):
    rel = COLLISION.relative_to(ROOT).as_posix()
    assert rel in guards and _sha(COLLISION) == guards[rel]
    collision = _json(COLLISION)
    assert isinstance(collision, dict) and len(collision) == 54
    for path, digest in collision.items():
        assert _sha(ROOT / path) == digest, ('collision guard changed', path)
    return collision


def _verify_owned_asset_rows(rows):
    assert isinstance(rows, list) and len(rows) == 4
    assert len({row['path'] for row in rows}) == 4
    for row in rows:
        package = ROOT / ('Content/' + row['path'].removeprefix('/Game/') + '.uasset')
        assert package.is_file() and _sha(package) == row['package_sha256'], ('owned Hall asset changed', row['path'])


def _editor(u, require_clean=True):
    subsystem = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    world = subsystem.get_editor_world()
    assert world and _package(world) == MAP, 'Requires the clean assembled Variant C map'
    assert subsystem.get_game_world() is None, 'Stop PIE before this phase'
    dirty = _dirty(u)
    if require_clean:
        assert dirty == dict(maps=[], content=[]), ('Editor is not clean', dirty)
    return world, dirty


def _load_asset(u, asset_path, digest, package_hashes):
    assert isinstance(asset_path, str) and asset_path.startswith('/Game/')
    package = ROOT / ('Content/' + asset_path.removeprefix('/Game/') + '.uasset')
    assert package.is_file() and _sha(package) == digest, ('Owned asset package changed', asset_path)
    package_hashes[package.relative_to(ROOT).as_posix()] = digest
    asset = u.load_asset(asset_path)
    assert asset and _package(asset) == asset_path
    return asset


def _assets(asset_path, expected_sha):
    path, data = _receipt(asset_path, expected_sha,
        ROOT / 'Saved/WarrensCGameplay-20261024/HallMaterialAssets', 'assets_created')
    assert data.get('status') == 'FOUR_OWNED_HALL_MATERIAL_ASSETS_CREATED'
    graph = data['material']['graph']
    assert graph.get('node_count') == 15
    nodes = graph['graph']['nodes']
    assert nodes['repeat']['properties'] == dict(parameter_name='RepeatCm', default_value=200.0), \
        'Hall world-projection repeat scalar changed'
    assert abs(float(nodes['mix']['properties']['r']) - .60) < 1e-6
    rows = data.get('tangent_instances')
    assert isinstance(rows, list) and len(rows) == 2
    by_axis = {}
    for row in rows:
        tangent = tuple(round(float(v), 6) for v in row['tangent'])
        axis = 0 if tangent == (0.0, -1.0, 0.0) else 1 if tangent == (1.0, 0.0, 0.0) else None
        assert axis is not None and axis not in by_axis
        by_axis[axis] = row
    assert set(by_axis) == {0, 1}
    owned = {'texture': data['texture'], 'material': data['material'],
             'normal_x': by_axis[0], 'normal_y': by_axis[1]}
    assert len({row['path'] for row in owned.values()}) == 4
    return path, data, by_axis, owned


def _guard_audit(path, expected_sha):
    path = Path(path)
    if not path.is_absolute():
        path = ROOT / path
    path = path.resolve()
    assert path.is_relative_to((ROOT / 'Saved/WarrensCGameplay-20261024').resolve())
    assert path.is_file() and _sha(path) == expected_sha
    data = _json(path)
    assert data.get('status') == 'RELOAD_AUDITED'
    guards = data.get('immutable_guards')
    _verify_guards(guards)
    return path, data, guards


def _selection(path, digest):
    path = Path(path).resolve()
    assert path.is_relative_to((ROOT / 'docs/art/warrens-c-gameplay-review-20261024').resolve())
    assert path.is_file() and _sha(path) == digest
    data = _json(path)
    assert data.get('status') in ('DERIVED_STATIC_SURFACE_PREVIEW_RENDERED', 'SOURCE_SELECTION_REVIEW_REQUIRED')
    keys = data.get('selected_source_keys')
    count = data.get('selected_wall_instances')
    assert isinstance(keys, list) and isinstance(count, int) and count > 0 and len(keys) == count
    assert len(set(keys)) == len(keys) and all(isinstance(key, int) and key >= 0 for key in keys)
    if 'inputs' in data:
        fit_rel = FIT.relative_to(ROOT).as_posix()
        assert data['inputs'].get(fit_rel) == _sha(FIT), 'Fit ledger differs from the frozen source-selection input'
    if data['status'] == 'DERIVED_STATIC_SURFACE_PREVIEW_RENDERED':
        proposal = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/lookdev/hall-painterly-r01/wall_selection_r03.json'
        assert proposal.is_file() and _sha(proposal) == data.get('selection_sha256'), (
            'Rendered 144-row selection does not match its source proposal')
    return path, data, sorted(keys)


def _fit(key_list):
    fit = _json(FIT)
    assert tuple(float(v) for v in fit['pivots']['Hub']) == PIVOT
    placements = fit['placements']
    assert all(key < len(placements) for key in key_list)
    rows = {key: placements[key] for key in key_list}
    for key, row in rows.items():
        assert row.get('tile') == 'Hub' and row.get('id') in ('CCS15', 'BACKING_TX01'), (key, row)
        expected_role = 'source exposed wall veneer' if row['id'] == 'CCS15' else 'source wall seam backing'
        assert row.get('role') == expected_role, (key, row)
        pair_key = key + 1 if row['id'] == 'CCS15' else key - 1
        assert pair_key in rows, ('Selected veneer/backing pair incomplete', key)
        pair = rows[pair_key]
        expected_pair_id = 'BACKING_TX01' if row['id'] == 'CCS15' else 'CCS15'
        expected_pair_role = 'source wall seam backing' if row['id'] == 'CCS15' else 'source exposed wall veneer'
        assert pair['id'] == expected_pair_id and pair['tile'] == 'Hub' and pair['role'] == expected_pair_role
        veneer = row if row['id'] == 'CCS15' else pair
        assert veneer.get('yaw') in (0, 90, 180, -90), (key, veneer.get('yaw'))
    counts = {name: sum(row['id'] == name for row in rows.values()) for name in ('CCS15', 'BACKING_TX01')}
    assert counts['CCS15'] == counts['BACKING_TX01'] and sum(counts.values()) == len(key_list)
    return fit, rows, counts


def _pose_key(pose):
    return json.dumps(pose, sort_keys=True, separators=(',', ':'), allow_nan=False)


def _canonical(component):
    value = json.loads(json.dumps(component, sort_keys=True, allow_nan=False))
    for field in ('path', 'owner', 'level'):
        value.pop(field, None)
    value['instances'] = sorted(value['instances'], key=_pose_key)
    return value


def _semantic_rows(snapshot):
    return sorted((_canonical(row) for row in snapshot.values()), key=lambda row: _pose_key(row))


def _digest_rows(rows):
    return hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def _find_sources(u, world, core):
    actors, snapshot = core._hism_snapshot(world)
    hub_actors = [actor for actor in actors if 'LI_Warrens_Hub' in actor.get_level().get_path_name()]
    assert hub_actors, 'No streamed Hub source-level actors in the assembled editor world'
    found = {}
    for ident in ('CCS15', 'BACKING_TX01'):
        label = 'WVC_' + ident
        matches = [(actor, component) for actor in hub_actors if actor.get_actor_label() == label
                   for component in actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)]
        assert len(matches) == 1, ('Expected exact source HISM actor/component', label, len(matches))
        actor, component = matches[0]
        row = core._component(component)
        assert row['mesh'], label
        found[ident] = dict(actor=actor, component=component, snapshot=row)
    return actors, snapshot, found


def _match_selection(u, core, fit, selected_rows, source_components, hub_transform):
    matches = []
    by_component = {ident: [] for ident in source_components}
    for key, row in selected_rows.items():
        ident = row['id']
        component = source_components[ident]['component']
        wanted = core._row_transform(u, row, PIVOT, hub_transform)
        found = []
        for index in range(component.get_instance_count()):
            actual = component.get_instance_transform(index, world_space=True)
            if core._near(actual, wanted):
                found.append(index)
        assert len(found) == 1, ('Fit row missing or ambiguous in live HISM', key, ident, found)
        index = found[0]
        assert index not in {item['index'] for item in by_component[ident]}, ('Duplicate source instance', key)
        actual = component.get_instance_transform(index, world_space=True)
        veneer = row if ident == 'CCS15' else fit['placements'][key - 1]
        assert veneer['id'] == 'CCS15' and veneer['role'] == 'source exposed wall veneer'
        axis = 0 if veneer['yaw'] in (90, -90) else 1
        item = dict(source_key=key, component_path=component.get_path_name(), ident=ident, axis=axis, index=index,
                    world_pose=core._pose(actual), local_pose=core._pose(component.get_instance_transform(index, world_space=False)))
        matches.append(item)
        by_component[ident].append(item)
    assert sum(map(len, by_component.values())) == len(selected_rows)
    return matches, by_component


def _current_snapshot(core, world):
    _, rows = core._hism_snapshot(world)
    return rows


def _global_geometry(snapshot):
    rows = []
    for component in snapshot.values():
        for pose in component['instances']:
            rows.append(dict(mesh=component['mesh'], pose=pose))
    rows.sort(key=lambda row: _pose_key(row))
    return rows


def _expected_removed(before, selections):
    expected = json.loads(json.dumps(before))
    by_path = {}
    for ident, items in selections.items():
        component_paths = {item['component_path'] for item in items}
        assert len(component_paths) == 1
        component_path = next(iter(component_paths))
        entries = [(path, row) for path, row in expected.items() if row['path'] == component_path]
        assert len(entries) == 1
        path, row = entries[0]
        original = list(row['instances'])
        indices = sorted((item['index'] for item in items), reverse=True)
        assert len(indices) == len(set(indices))
        for index in indices:
            assert 0 <= index < len(original)
            original.pop(index)
        row['instances'] = original
        by_path[path] = row
    return expected, by_path


def preflight(asset_receipt_path, asset_receipt_sha256, selection_path, selection_sha256,
              guard_receipt_path, guard_receipt_sha256):
    """Read-only live admission; no mutations, map saves, or package loads."""
    u = _u()
    world, dirty = _editor(u)
    core = _core()
    asset_path, asset_data, material_rows, owned_assets = _assets(asset_receipt_path, asset_receipt_sha256)
    selection_file, selection_data, keys = _selection(selection_path, selection_sha256)
    guard_path, guards_data, guards = _guard_audit(guard_receipt_path, guard_receipt_sha256)
    collision = _collision_map(guards)
    fit, selected_rows, counts = _fit(keys)
    package_hashes = {}
    loaded_assets = {}
    for name, row in owned_assets.items():
        loaded_assets[name] = _load_asset(u, row['path'], row['package_sha256'], package_hashes)
        assert u.EditorAssetLibrary.get_metadata_tag(loaded_assets[name], 'MarsWarrensCStaticPainterlyWallsOwner') == \
            'Mars.WarrensC.StaticPainterlyWalls.R01.20261026'
    actors, before, sources = _find_sources(u, world, core)
    hub_owner = sources['CCS15']['actor']
    hub_transform = hub_owner.get_level_transform()
    matched, selections = _match_selection(u, core, fit, selected_rows, sources, hub_transform)
    assert {item['source_key'] for item in matched} == set(keys)
    partition_counts = {(ident, axis): sum(item['ident'] == ident and item['axis'] == axis for item in matched)
                        for ident in ('CCS15', 'BACKING_TX01') for axis in (0, 1)}
    assert all(partition_counts.values()), ('All four material partitions must have selected rows', partition_counts)
    source_packages = sorted({_package(source['actor'].get_level().get_outermost()) for source in sources.values()})
    assert len(source_packages) == 1
    token = uuid.uuid4().hex
    record = dict(phase='preflight', status='READ_ONLY_PREPARED', token=token, map=MAP,
        editor_dirty=dirty, asset_receipt=dict(path=asset_path.relative_to(ROOT).as_posix(), sha256=asset_receipt_sha256,
            status=asset_data['status'], target_materials={str(axis): row['path'] for axis, row in material_rows.items()},
            package_hashes=package_hashes), selection=dict(path=selection_file.relative_to(ROOT).as_posix(),
            sha256=selection_sha256, selected_source_keys=keys, counts=counts),
        guard_receipt=dict(path=guard_path.relative_to(ROOT).as_posix(), sha256=guard_receipt_sha256,
            guard_count=len(guards)), immutable_guards=guards, collision_hashes=collision,
        fit_sha256=_sha(FIT), pivot=list(PIVOT), hub_source_actor=hub_owner.get_path_name(),
        hub_transform=core._pose(hub_transform), source_packages=source_packages,
        selected_live_instances=matched, selected_by_source={k: [x['index'] for x in v] for k, v in selections.items()},
        selected_by_source_matches=selections,
        partition_counts={f'{ident}:{axis}': count for (ident, axis), count in partition_counts.items()},
        before_hisms=before, before_semantic_sha256=_digest_rows(_semantic_rows(before)),
        before_global_geometry_sha256=_digest_rows(_global_geometry(before)),
        before_global_instance_count=len(_global_geometry(before)),
        source_components={ident: dict(path=value['component'].get_path_name(), owner_label=value['actor'].get_actor_label(),
            mesh=value['snapshot']['mesh'], materials=value['snapshot']['materials']) for ident, value in sources.items()},
        allowed_dirty_maps=sorted({MAP, *source_packages}), allowed_dirty_content=[],
        # LevelInstanceLevelStreaming marks its /Temp package RF_Transient;
        # GetDirtyWorldPackages deliberately excludes it (FileHelpers.cpp5540).
        expected_reported_dirty_maps=[MAP],
        trial_labels=[dict(ident=ident, axis=axis, label=label) for (ident, axis), label in LABELS.items()],
        owned_assets=[dict(name=name, path=row['path'], package_sha256=row['package_sha256'])
                      for name, row in owned_assets.items()],
        trial_boundary='Unsaved editor/PIE-only trial. No map save or level-loading API is called.')
    return _write('preflight', record)


def _load_preflight(path, expected_sha):
    file = Path(path)
    if not file.is_absolute():
        file = ROOT / file
    file = file.resolve()
    assert file.is_relative_to(RUN.resolve()) and file.is_file() and _sha(file) == expected_sha
    data = _json(file)
    assert data.get('phase') == 'preflight' and data.get('status') == 'READ_ONLY_PREPARED'
    assert data.get('tool_sha256') == _sha(__file__)
    _verify_guards(data['immutable_guards'])
    _collision_map(data['immutable_guards'])
    asset = data['asset_receipt']
    asset_path, asset_data, axes, owned_assets = _assets(ROOT / asset['path'], asset['sha256'])
    assert asset_data['status'] == asset['status']
    assert {str(axis): row['path'] for axis, row in axes.items()} == asset['target_materials']
    assert sorted((row['path'], row['package_sha256']) for row in owned_assets.values()) == \
        sorted((row['path'], row['package_sha256']) for row in data['owned_assets'])
    _verify_owned_asset_rows(data['owned_assets'])
    selection = data['selection']
    selection_path, selection_data, keys = _selection(ROOT / selection['path'], selection['sha256'])
    assert keys == selection['selected_source_keys']
    guard = data['guard_receipt']
    guard_path, guard_data, guards = _guard_audit(ROOT / guard['path'], guard['sha256'])
    assert guards == data['immutable_guards']
    assert _sha(FIT) == data['fit_sha256']
    return file, data


def _settings(u):
    editor_cls = u.load_class(None, '/Script/UnrealEd.EditorLoadingSavingSettings')
    jolt_cls = u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    assert editor_cls and jolt_cls
    editor = u.get_default_object(editor_cls)
    jolt = u.get_default_object(jolt_cls)
    return dict(editor=editor, autosave=editor.get_editor_property('bAutoSaveEnable'),
                jolt=jolt, cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave'))


def _group(u, world, source, indices, material, label, folder):
    actor = u.get_editor_subsystem(u.EditorActorSubsystem).spawn_actor_from_class(u.Actor, u.Vector(), u.Rotator())
    assert actor and actor.get_world() == world and actor.get_level().get_outer() == world
    actor.set_actor_label(label)
    actor.tags = [u.Name(OWNER)]
    actor.set_folder_path(folder)
    actor.root_component.set_mobility(source.get_editor_property('mobility'))
    subsystem = u.get_engine_subsystem(u.SubobjectDataSubsystem)
    root = subsystem.k2_gather_subobject_data_for_instance(actor)[0]
    handle, reason = subsystem.add_new_subobject(u.AddNewSubobjectParams(
        parent_handle=root, new_class=u.HierarchicalInstancedStaticMeshComponent))
    component = u.SubobjectDataBlueprintFunctionLibrary.get_associated_object(
        u.SubobjectDataBlueprintFunctionLibrary.get_data(handle))
    assert isinstance(component, u.HierarchicalInstancedStaticMeshComponent), str(reason)
    component.set_mobility(source.get_editor_property('mobility'))
    assert component.set_static_mesh(source.static_mesh)
    component.set_world_transform(source.get_world_transform(), False, True)
    component.set_collision_profile_name(source.get_collision_profile_name())
    for field in ('generate_overlap_events', 'hidden_in_game', 'instancing_random_seed',
                  'instance_start_cull_distance', 'instance_end_cull_distance', 'num_custom_data_floats',
                  'body_instance'):
        component.set_editor_property(field, source.get_editor_property(field))
    component.set_cast_shadow(source.cast_shadow)
    component.set_visibility(source.is_visible(), False)
    for slot, original in enumerate(source.get_materials()):
        component.set_material(slot, material if slot == 0 else original)
    local = [source.get_instance_transform(index, world_space=False) for index in indices]
    assert list(component.add_instances(local, True, False, False)) == list(range(len(local)))
    return actor, component


def _groups(u, world):
    found = {}
    for actor in u.GameplayStatics.get_all_actors_of_class(world, u.Actor):
        label = actor.get_actor_label()
        if label in LABELS.values():
            assert label not in found, ('Duplicate trial group actor label', label)
            assert OWNER in [str(tag) for tag in actor.tags]
            components = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
            assert len(components) == 1
            found[label] = components[0]
    assert set(found) == set(LABELS.values())
    return found


def _expected_stage(before, selections, current):
    expected, _ = _expected_removed(before, selections)
    for path, row in current.items():
        if row['owner_label'] in LABELS.values():
            assert path not in expected
            expected[path] = row
    return expected


def _assert_semantic(actual, expected, label):
    a, e = _semantic_rows(actual), _semantic_rows(expected)
    assert a == e, (label, 'semantic HISM multiset differs', len(a), len(e), _digest_rows(a), _digest_rows(e))


def _pose_equivalent(actual, expected):
    if sum((float(actual['at'][i]) - float(expected['at'][i])) ** 2 for i in range(3)) ** .5 >= .1:
        return False
    if sum((float(actual['scale'][i]) - float(expected['scale'][i])) ** 2 for i in range(3)) ** .5 >= .001:
        return False
    dot = abs(sum(float(actual['q'][i]) * float(expected['q'][i]) for i in range(4)))
    return dot >= 1.0 - 1e-7


def _validate_group_source_contract(current, sources, created):
    for group in created:
        rows = [row for row in current.values() if row['owner_label'] == group['label']]
        assert len(rows) == 1, ('Missing or duplicate partition HISM', group['label'])
        actual = _canonical(rows[0])
        source = _canonical(sources[group['ident']]['snapshot'])
        actual.pop('owner_label', None)
        source.pop('owner_label', None)
        actual_instances = actual.pop('instances')
        source.pop('instances')
        assert actual == source, ('Partition component settings differ from its source', group['label'])
        expected_instances = [item['world_pose'] for item in group['selected']]
        assert len(actual_instances) == len(expected_instances)
        unmatched = list(actual_instances)
        for expected in expected_instances:
            candidates = [i for i, pose in enumerate(unmatched) if _pose_equivalent(pose, expected)]
            assert len(candidates) == 1, ('Partition pose missing or ambiguous', group['label'], expected)
            unmatched.pop(candidates[0])
        assert not unmatched


def stage_trial(preflight_path, preflight_sha256):
    """Create the four temporary HISM partitions, remove selected source rows, and retain state."""
    state = _state()
    assert state.active is None, 'A Hall wall trial is already active'
    path, prior = _load_preflight(preflight_path, preflight_sha256)
    u = _u()
    world, dirty = _editor(u)
    assert dirty == dict(maps=[], content=[])
    assert _dirty(u) == prior['editor_dirty']
    core = _core()
    _, before, sources = _find_sources(u, world, core)
    assert before == prior['before_hisms'] and _digest_rows(_semantic_rows(before)) == prior['before_semantic_sha256']
    state.active = dict(stage='starting', preflight=dict(path=path, sha=preflight_sha256), world=world,
        actors=[], components=[], settings=_settings(u), original_snapshot=before,
        original_guards=prior['immutable_guards'], collision=prior['collision_hashes'],
        selections=prior['selected_live_instances'], selected_by_source=prior['selected_by_source'],
        materials={}, phase_receipts=[dict(path=path, sha=preflight_sha256)])
    active = state.active
    active['candidate_material_paths'] = {int(axis): path
        for axis, path in prior['asset_receipt']['target_materials'].items()}
    active['candidate_package_hashes'] = {int(axis): prior['asset_receipt']['package_hashes'][
        'Content/' + path.removeprefix('/Game/') + '.uasset']
        for axis, path in active['candidate_material_paths'].items()}
    active['owned_assets'] = prior['owned_assets']
    active['preflight_asset_hashes'] = {row['path']: row['package_sha256'] for row in active['owned_assets']}
    _verify_owned_asset_rows(active['owned_assets'])
    try:
        for axis in (0, 1):
            asset = prior['asset_receipt']['target_materials'][str(axis)]
            package_sha = prior['asset_receipt']['package_hashes']['Content/' + asset.removeprefix('/Game/') + '.uasset']
            active['materials'][axis] = _load_asset(u, asset, package_sha, {})
        settings = active['settings']
        settings['editor'].set_editor_property('bAutoSaveEnable', False)
        settings['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave', type(settings['cook']).DISABLE)
        assert settings['editor'].get_editor_property('bAutoSaveEnable') is False
        assert settings['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave') == type(settings['cook']).DISABLE
        created = []
        expected_indices = {k: set(v) for k, v in prior['selected_by_source'].items()}
        for ident, source_data in sources.items():
            source = source_data['component']
            for axis in (0, 1):
                items = [item for item in prior['selected_live_instances'] if item['ident'] == ident and item['axis'] == axis]
                if not items:
                    continue
                label = LABELS[(ident, axis)]
                actor, component = _group(u, world, source, [item['index'] for item in items],
                    source.get_material(0), label, 'Warrens/Art/HallWallTrial')
                active['actors'].append(actor)
                active['components'].append(component)
                created.append(dict(label=label, ident=ident, axis=axis, actor=actor, component=component,
                                    source_component=source, selected=items))
        assert len(created) == 4, ('Expected four nonempty partition groups', [x['label'] for x in created])
        active['created'] = created
        for ident, indices in expected_indices.items():
            component = sources[ident]['component']
            component.modify()
            for index in sorted(indices, reverse=True):
                assert component.remove_instance(index)
        active['stage'] = 'staged_A'
        current = _current_snapshot(core, world)
        assert set(actor.get_actor_label() for actor in active['actors']) == set(LABELS.values())
        _groups(u, world)
        _validate_group_source_contract(current, sources, created)
        expected = _expected_stage(before, prior['selected_by_source_matches'], current)
        _assert_semantic(current, expected, 'editor stage A')
        geometry = _global_geometry(current)
        assert len(geometry) == prior['before_global_instance_count']
        assert _digest_rows(geometry) == prior['before_global_geometry_sha256'], 'Global mesh/pose multiset changed'
        _verify_owned_asset_rows(active['owned_assets'])
        dirty_now = _dirty(u)
        assert dirty_now['maps'] == prior['expected_reported_dirty_maps'] and dirty_now['content'] == [], dirty_now
        _verify_guards(prior['immutable_guards'])
        _collision_map(prior['immutable_guards'])
    except Exception as exc:
        active['stage'] = 'stage_failed'
        try:
            failure = dict(phase='stage_failure', status='STAGE_FAILED_INSPECTION_REQUIRED',
                preflight=dict(path=path.relative_to(ROOT).as_posix(), sha256=preflight_sha256),
                error=repr(exc), dirty=_dirty(u), created_labels=[actor.get_actor_label() for actor in active['actors']],
                guards_exact=all(_sha(ROOT / rel) == digest for rel, digest in prior['immutable_guards'].items()),
                collision_exact=all(_sha(ROOT / rel) == digest for rel, digest in prior['collision_hashes'].items()),
                autosave_current=settings['editor'].get_editor_property('bAutoSaveEnable') if 'settings' in locals() else None,
                jolt_autocook_current=str(settings['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave')) if 'settings' in locals() else None,
                recovery='Do not save or retry. Inspect the editor state; root owns explicit discard/reload and settings restoration.')
            failure_receipt = _write('stage_failure', failure)
            active['phase_receipts'].append(failure_receipt)
            print('HALL_WALL_TRIAL_FAILURE', json.dumps(failure_receipt, sort_keys=True))
        finally:
            raise
    record = dict(phase='staged_A', status='UNSAVED_TRIAL_READY_FOR_PIE',
        preflight=dict(path=path.relative_to(ROOT).as_posix(), sha256=preflight_sha256),
        before_semantic_sha256=prior['before_semantic_sha256'], editor_stage_semantic_sha256=_digest_rows(_semantic_rows(current)),
        editor_hism_count=len(current), selected_count=len(prior['selected_live_instances']),
        global_geometry_sha256=_digest_rows(_global_geometry(current)),
        global_geometry_count=len(_global_geometry(current)), global_geometry_preserved=True,
        created_groups=[dict(label=x['label'], ident=x['ident'], axis=x['axis'], count=len(x['selected'])) for x in created],
        dirty=dirty_now, guards_verified=True, collision_count=len(prior['collision_hashes']),
        autosave_disabled=settings['editor'].get_editor_property('bAutoSaveEnable') is False,
        jolt_autocook_disabled=settings['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave') == type(settings['cook']).DISABLE,
        saved=False, explicit_root_action='Start PIE only after reviewing this receipt.')
    result = _write('staged_A', record)
    active['phase_receipts'].append(result)
    active['editor_expected'] = current
    return result


def _active_receipt(path, expected_sha, phase):
    state = _state()
    assert state.active is not None, 'No live Hall trial state'
    file = Path(path)
    if not file.is_absolute():
        file = ROOT / file
    file = file.resolve()
    assert file.is_relative_to(RUN.resolve()) and file.is_file() and _sha(file) == expected_sha
    receipt = _json(file)
    assert receipt.get('phase') == phase and receipt.get('tool_sha256') == _sha(__file__)
    return state.active, file, receipt


def check_pie_admission(staged_path, staged_sha256):
    active, path, staged = _active_receipt(staged_path, staged_sha256, 'staged_A')
    u = _u()
    game = None
    try:
        game = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
        assert game and 'Warrens_VariantC_Mars_MAP' in game.get_name()
        actual = _current_snapshot(_core(), game)
        _assert_semantic(actual, active['editor_expected'], 'PIE admission')
        assert _digest_rows(_semantic_rows(actual)) == staged['editor_stage_semantic_sha256']
        active['pie_world'] = game
        active['pie_admitted'] = True
        active['stage'] = 'pie_A'
        record = dict(phase='pie_admission', status='PIE_MATCHES_COMPLETE_STAGED_HISM_ROSTER',
            staged_receipt=dict(path=path.relative_to(ROOT).as_posix(), sha256=staged_sha256),
            editor_expected_sha256=staged['editor_stage_semantic_sha256'],
            pie_actual_sha256=_digest_rows(_semantic_rows(actual)), hism_count=len(actual),
            full_semantic_match=True, saved=False)
        result = _write('pie_admission', record)
        active['phase_receipts'].append(result)
        return result
    except Exception as exc:
        active['pie_world'] = game
        active['stage'] = 'pie_admission_failed'
        result = _write('pie_admission_failure', dict(phase='pie_admission_failure',
            status='PIE_ADMISSION_FAILED_INSPECTION_REQUIRED',
            staged_receipt=dict(path=path.relative_to(ROOT).as_posix(), sha256=staged_sha256),
            error=repr(exc), saved=False,
            recovery='Stop PIE. Then call prepare_failed_discard() and let root perform explicit discard/reload.'))
        active['phase_receipts'].append(result)
        print('HALL_WALL_TRIAL_FAILURE', json.dumps(result, sort_keys=True))
        raise


def _toggle_expected(active, enabled):
    expected = json.loads(json.dumps(active['editor_expected']))
    for row in expected.values():
        if row['owner_label'] not in LABELS.values():
            continue
        axis = next(axis for (ident, axis), label in LABELS.items() if label == row['owner_label'])
        material = active['candidate_materials'][axis] if enabled else active['source_materials'][row['owner_label']]
        row['materials'][0] = material
    return expected


def set_pie_candidate(enabled, admission_path, admission_sha256):
    active = _state().active
    try:
        return _set_pie_candidate(enabled, admission_path, admission_sha256)
    except Exception as exc:
        if active is not None:
            active['stage'] = 'pie_candidate_failed'
            result = _write('pie_candidate_failure', dict(phase='pie_candidate_failure',
                status='PIE_CANDIDATE_SWITCH_FAILED_INSPECTION_REQUIRED', enabled=bool(enabled),
                error=repr(exc), saved=False,
                recovery='Stop PIE. Then call prepare_failed_discard() and let root perform explicit discard/reload.'))
            active['phase_receipts'].append(result)
            print('HALL_WALL_TRIAL_FAILURE', json.dumps(result, sort_keys=True))
        raise


def _set_pie_candidate(enabled, admission_path, admission_sha256):
    active, path, admission = _active_receipt(admission_path, admission_sha256, 'pie_admission')
    assert active.get('pie_admitted') and admission['status'] == 'PIE_MATCHES_COMPLETE_STAGED_HISM_ROSTER'
    u = _u()
    game = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert game == active['pie_world']
    groups = _groups(u, game)
    core = _core()
    before = _current_snapshot(core, game)
    if 'source_materials' not in active:
        active['source_materials'] = {row['owner_label']: row['materials'][0]
            for row in active['editor_expected'].values() if row['owner_label'] in LABELS.values()}
        active['candidate_materials'] = active['candidate_material_paths']
    expected_before = _toggle_expected(active, active['stage'] == 'pie_D')
    _assert_semantic(before, expected_before, 'PIE before material switch')
    _verify_owned_asset_rows(active['owned_assets'])
    for (ident, axis), label in LABELS.items():
        component = groups[label]
        desired = active['candidate_materials'][axis] if enabled else active['source_materials'][label]
        if enabled:
            package = ROOT / ('Content/' + desired.removeprefix('/Game/') + '.uasset')
            assert package.is_file() and _sha(package) == active['candidate_package_hashes'][axis]
        material = u.load_asset(desired)
        assert material and _package(material) == desired
        component.set_material(0, material)
    expected = _toggle_expected(active, bool(enabled))
    after = _current_snapshot(core, game)
    _assert_semantic(after, expected, 'PIE candidate switch')
    _verify_owned_asset_rows(active['owned_assets'])
    active['stage'] = 'pie_D' if enabled else 'pie_A'
    result = _write('pie_D' if enabled else 'pie_A_restore', dict(
        phase='pie_candidate' if enabled else 'pie_restore', status='FOUR_OWNED_HISM_SLOTS_UPDATED' if enabled else 'STAGE_A_RESTORED',
        enabled=bool(enabled), changed_components=sorted(LABELS.values()),
        full_semantic_sha256=_digest_rows(_semantic_rows(after)), full_semantic_match=True, saved=False))
    active['phase_receipts'].append(result)
    active['editor_expected'] = active['editor_expected']
    return result


def prepare_exit_pie():
    active = _state().active
    assert active and active.get('pie_admitted')
    assert active['stage'] == 'pie_A', 'Restore Stage A with set_pie_candidate(False, ...) before stopping PIE'
    u = _u()
    game = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert game == active['pie_world']
    _assert_semantic(_current_snapshot(_core(), game), active['editor_expected'], 'PIE Stage A before stop')
    result = _write('pie_exit_ready', dict(phase='pie_exit_ready', status='STAGE_A_RESTORED_READY_TO_STOP_PIE',
        stage_a_restored=True, saved=False, next='Stop PIE in the editor, then call prepare_discard().'))
    active['phase_receipts'].append(result)
    return result


def _restore_settings(active):
    settings = active['settings']
    settings['editor'].set_editor_property('bAutoSaveEnable', settings['autosave'])
    settings['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave', settings['cook'])
    assert settings['editor'].get_editor_property('bAutoSaveEnable') == settings['autosave']
    assert settings['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave') == settings['cook']


def prepare_discard(exit_path, exit_sha256):
    active, path, receipt = _active_receipt(exit_path, exit_sha256, 'pie_exit_ready')
    u = _u()
    editor = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    assert editor.get_game_world() is None, 'PIE must be stopped before discard preparation'
    assert active['settings']['editor'].get_editor_property('bAutoSaveEnable') is False
    assert active['settings']['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave') == \
        type(active['settings']['cook']).DISABLE
    world, dirty = _editor(u, require_clean=False)
    assert world == active['world']
    now = _current_snapshot(_core(), world)
    _assert_semantic(now, active['editor_expected'], 'editor after PIE stop')
    preflight = _active_preflight(active)
    assert dirty['maps'] == preflight['expected_reported_dirty_maps'] and dirty['content'] == []
    _verify_guards(active['original_guards'])
    main_map_rel = 'Content/Mars/Maps/Warrens_VariantC_Mars_MAP.umap'
    assert active['original_guards'].get(main_map_rel) == _sha(ROOT / main_map_rel), 'Main map disk bytes changed; refuse discard handoff'
    collision = active['collision']
    assert len(collision) == 54 and all(_sha(ROOT / p) == d for p, d in collision.items())
    for axis, asset_path in active['candidate_material_paths'].items():
        package = ROOT / ('Content/' + asset_path.removeprefix('/Game/') + '.uasset')
        assert package.is_file() and _sha(package) == active['candidate_package_hashes'][axis]
    _verify_owned_asset_rows(active['owned_assets'])
    # Release every map-owned UObject reference before root invokes its explicit discard wrapper.
    active['discard_expected_original'] = active['original_snapshot']
    active['world'] = active['pie_world'] = active['actors'] = active['components'] = None
    active['created'] = active['materials'] = active['source_materials'] = active['candidate_materials'] = None
    active['editor_expected'] = active['original_snapshot'] = None
    active['stage'] = 'ready_for_root_discard'
    result = _write('discard_ready', dict(phase='discard_ready', status='READY_FOR_EXPLICIT_MONOLITH_DISCARD',
        source_exit_receipt=dict(path=path.relative_to(ROOT).as_posix(), sha256=exit_sha256),
        dirty=dirty, trial_maps=preflight['allowed_dirty_maps'],
        dirty_content=[], guards_verified=True, collision_count=54,
        owned_assets=active['owned_assets'], map_saved=False,
        root_action='Call Monolith load_level for the Variant C map with dirty_policy=discard; this helper does not load or discard levels.'))
    active['phase_receipts'].append(result)
    return result


def prepare_failed_discard(failure_path, failure_sha256):
    """Release a failed staged/admission trial for root-owned explicit discard."""
    active = _state().active
    assert active is not None
    file = Path(failure_path)
    if not file.is_absolute():
        file = ROOT / file
    file = file.resolve()
    assert file.is_relative_to(RUN.resolve()) and file.is_file() and _sha(file) == failure_sha256
    failure = _json(file)
    assert failure.get('phase') in ('stage_failure', 'pie_admission_failure', 'pie_candidate_failure')
    u = _u()
    editor = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    assert editor.get_game_world() is None, 'Stop PIE before releasing failed trial references'
    world, dirty = _editor(u, require_clean=False)
    assert world == active['world']
    preflight = _active_preflight(active)
    assert set(dirty['maps']).issubset(preflight['allowed_dirty_maps']) and dirty['content'] == []
    _verify_guards(active['original_guards'])
    _collision_map(active['original_guards'])
    _verify_owned_asset_rows(active['owned_assets'])
    main_map_rel = 'Content/Mars/Maps/Warrens_VariantC_Mars_MAP.umap'
    assert active['original_guards'].get(main_map_rel) == _sha(ROOT / main_map_rel)
    # Ensure safety settings remain disabled across the root-owned discard operation.
    settings = active['settings']
    settings['editor'].set_editor_property('bAutoSaveEnable', False)
    settings['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave', type(settings['cook']).DISABLE)
    assert settings['editor'].get_editor_property('bAutoSaveEnable') is False
    assert settings['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave') == type(settings['cook']).DISABLE
    active['discard_expected_original'] = active['original_snapshot']
    active['world'] = active['pie_world'] = active['actors'] = active['components'] = None
    active['created'] = active['materials'] = active['source_materials'] = active['candidate_materials'] = None
    active['editor_expected'] = active['original_snapshot'] = None
    active['stage'] = 'ready_for_root_discard'
    result = _write('discard_ready', dict(phase='discard_ready', status='READY_FOR_EXPLICIT_MONOLITH_DISCARD',
        failure_receipt=dict(path=file.relative_to(ROOT).as_posix(), sha256=failure_sha256,
                             phase=failure['phase'], status=failure['status']),
        dirty=dirty, trial_maps=preflight['allowed_dirty_maps'], dirty_content=[],
        guards_verified=True, collision_count=54, owned_asset_count=4,
        owned_assets=active['owned_assets'], map_saved=False,
        root_action='Call Monolith load_level for Variant C with dirty_policy=discard; this helper does not load or discard levels.'))
    active['phase_receipts'].append(result)
    return result


def _active_preflight(active):
    path = active['phase_receipts'][0]['path']
    return _json(path)


def after_reload(discard_path, discard_sha256):
    active, path, receipt = _active_receipt(discard_path, discard_sha256, 'discard_ready')
    u = _u()
    world, dirty = _editor(u)
    assert world and dirty == dict(maps=[], content=[])
    core = _core()
    current = _current_snapshot(core, world)
    _assert_semantic(current, active['discard_expected_original'], 'original map after discard/reload')
    _verify_guards(active['original_guards'])
    assert all(_sha(ROOT / p) == d for p, d in active['collision'].items())
    _verify_owned_asset_rows([dict(path=path, package_sha256=digest)
                              for path, digest in active['preflight_asset_hashes'].items()])
    _restore_settings(active)
    result = _write('after_reload', dict(phase='after_reload', status='ORIGINAL_MAP_RELOADED_AND_VERIFIED',
        discard_receipt=dict(path=path.relative_to(ROOT).as_posix(), sha256=discard_sha256),
        original_semantic_sha256=_digest_rows(_semantic_rows(current)), original_hism_count=len(current),
        guards_verified=True, collision_count=54, dirty=dirty, settings_restored=True, saved=False))
    _state().active = None
    return result

