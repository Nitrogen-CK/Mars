"""Unsaved Hall wall PIE trial with an explicit streamed-source partition step.

Import is inert. This adapter leaves source Level Instances intact in the editor,
then removes only the selected Hub art instances in PIE before any material toggle.
It never saves or loads a map; root owns the explicit discard/reload wrapper.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
import types
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RUN = ROOT / 'Saved/WarrensCGameplay-20261024/HallWallTrial'
BASE_FILE = HERE / 'hall_wall_trial.py'
BASE_SHA256 = '7cedf430c2aa09f6848d09d5e4e0b95f2b9fd6ffdb266b548ea9b21f5b38219c'
ADAPTER_STATE = '_mars_wvc_hall_wall_runtime_trial_state'


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _base():
    assert _sha(BASE_FILE) == BASE_SHA256, 'Frozen Hall trial base changed'
    name = '_wvc_hall_wall_frozen_base'
    if name not in sys.modules:
        spec = importlib.util.spec_from_file_location(name, BASE_FILE)
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules[name] = module
    return sys.modules[name]


def _state():
    if ADAPTER_STATE not in sys.modules:
        sys.modules[ADAPTER_STATE] = types.ModuleType(ADAPTER_STATE)
        sys.modules[ADAPTER_STATE].active = None
    return sys.modules[ADAPTER_STATE]


def _write(kind, record):
    RUN.mkdir(parents=True, exist_ok=True)
    path = RUN / f'{kind}_{datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S_%fZ")}_{uuid.uuid4().hex[:8]}.json'
    assert not path.exists()
    payload = dict(record, schema=1, created_utc=datetime.now(timezone.utc).isoformat(),
                   runtime_adapter_sha256=_sha(__file__), base_tool_sha256=_sha(BASE_FILE))
    path.write_text(json.dumps(payload, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    return dict(file=path.relative_to(ROOT).as_posix(), sha256=_sha(path), phase=payload.get('phase'),
                status=payload.get('status'))


def _receipt(path, digest, phase):
    path = Path(path)
    if not path.is_absolute():
        path = ROOT / path
    path = path.resolve()
    assert path.is_relative_to(RUN.resolve()) and path.is_file() and _sha(path) == digest
    data = _json(path)
    assert data.get('phase') == phase and data.get('schema') == 1
    return path, data


def _load_preflight(path, digest):
    base = _base()
    file, data = base._load_preflight(path, digest)
    assert data.get('tool_sha256') == BASE_SHA256
    assert data.get('expected_reported_dirty_maps') == [base.MAP]
    return file, data


def _u():
    import unreal
    return unreal


def _level_name(actor):
    return actor.get_level().get_path_name()


def _source_components(u, core, world):
    actors, snapshot = core._hism_snapshot(world)
    hub = [actor for actor in actors if 'LI_Warrens_Hub' in _level_name(actor)]
    out = {}
    for ident in ('CCS15', 'BACKING_TX01'):
        label = 'WVC_' + ident
        found = [(actor, component) for actor in hub if actor.get_actor_label() == label
                 for component in actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)]
        assert len(found) == 1, ('Hub PIE source HISM must resolve uniquely', label, len(found))
        actor, component = found[0]
        row = core._component(component)
        assert row['owner_label'] == label and row['collision_profile'] == 'NoCollision'
        assert component.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION, \
            ('Hub source HISM must remain NoCollision', label, component.get_collision_enabled())
        out[ident] = dict(actor=actor, component=component, row=row)
    return snapshot, out


def _expected_editor_duplicate(base, prior, current, created):
    # Original components must remain byte-for-byte semantically the same; only
    # four owned component rows may be added.
    expected = json.loads(json.dumps(prior['before_hisms']))
    new_rows = [row for row in current.values() if row['owner_label'].endswith('_Trial')]
    assert len(new_rows) == 4
    for row in new_rows:
        assert row['path'] not in expected
        expected[row['path']] = row
    base._assert_semantic(current, expected, 'editor duplicate stage')
    base._validate_group_source_contract(current, created[0]['sources'], created)
    geometry = base._global_geometry(current)
    original = base._global_geometry(prior['before_hisms'])
    added = [dict(mesh=row['mesh'], pose=pose) for row in new_rows for pose in row['instances']]
    expected_geometry = original + added
    expected_geometry.sort(key=base._pose_key)
    assert base._digest_rows(geometry) == base._digest_rows(expected_geometry)
    assert len(geometry) == prior['before_global_instance_count'] + len(prior['selected_live_instances'])
    return expected


def _assert_original_plus_trial(base, actual, original, label):
    trial_labels = {row['label'] for row in _json(ROOT / _state().active['preflight']['path'])['trial_labels']}
    retained = {path: row for path, row in actual.items() if row['owner_label'] not in trial_labels}
    base._assert_semantic(retained, original, label)
    assert all(row['owner_label'] in trial_labels for row in actual.values() if row not in retained.values())


def stage_trial(preflight_path, preflight_sha256):
    """Stage four copies in Main; source Hub instances remain untouched."""
    state = _state()
    assert state.active is None, 'A runtime Hall trial is already active'
    base = _base()
    path, prior = _load_preflight(preflight_path, preflight_sha256)
    u = _u()
    world, dirty = base._editor(u)
    assert dirty == dict(maps=[], content=[])
    core = base._core()
    _, before, sources = base._find_sources(u, world, core)
    assert before == prior['before_hisms']
    settings = base._settings(u)
    active = dict(stage='starting', preflight=dict(path=path.relative_to(ROOT).as_posix(), sha=preflight_sha256),
        world=world, actors=[], components=[], settings=settings, original_snapshot=before,
        original_guards=prior['immutable_guards'], collision=prior['collision_hashes'],
        selections=prior['selected_live_instances'], selected_by_source=prior['selected_by_source_matches'],
        phase_receipts=[dict(path=path.relative_to(ROOT).as_posix(), sha=preflight_sha256)],
        owned_assets=prior['owned_assets'], candidate_material_paths={int(axis): value
            for axis, value in prior['asset_receipt']['target_materials'].items()},
        candidate_package_hashes={int(axis): prior['asset_receipt']['package_hashes'][
            'Content/' + value.removeprefix('/Game/') + '.uasset']
            for axis, value in prior['asset_receipt']['target_materials'].items()},
        source_material_paths={label: base._package(source['component'].get_material(0))
            for ident, source in sources.items() for label in
            (f'WVC_HallWall_{ident}_NormalX_Trial', f'WVC_HallWall_{ident}_NormalY_Trial')},
        source_components=sources, created=[], pie_admitted=False)
    state.active = active
    try:
        base._verify_owned_asset_rows(active['owned_assets'])
        active['source_materials'] = {label: source['component'].get_material(0)
            for ident, source in sources.items() for label in (f'WVC_HallWall_{ident}_NormalX_Trial',
                f'WVC_HallWall_{ident}_NormalY_Trial')}
        active['materials'] = {axis: base._load_asset(u, asset, active['candidate_package_hashes'][axis], {})
            for axis, asset in active['candidate_material_paths'].items()}
        settings['editor'].set_editor_property('bAutoSaveEnable', False)
        settings['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave', type(settings['cook']).DISABLE)
        assert settings['editor'].get_editor_property('bAutoSaveEnable') is False
        assert settings['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave') == type(settings['cook']).DISABLE
        created = []
        labels = {(ident, axis): label for ident, axis, label in
                  ((row['ident'], row['axis'], row['label']) for row in prior['trial_labels'])}
        for ident, source_data in sources.items():
            for axis in (0, 1):
                items = [row for row in prior['selected_live_instances']
                         if row['ident'] == ident and row['axis'] == axis]
                assert items, ('Expected nonempty partition', ident, axis)
                label = labels[(ident, axis)]
                actor, component = base._group(u, world, source_data['component'],
                    [item['index'] for item in items], source_data['component'].get_material(0), label,
                    'Warrens/Art/HallWallRuntimeTrial')
                active['actors'].append(actor)
                active['components'].append(component)
                created.append(dict(label=label, ident=ident, axis=axis, actor=actor, component=component,
                                    source_component=source_data['component'], selected=items))
        active['created'] = created
        active['stage'] = 'staged_duplicate'
        current = base._current_snapshot(core, world)
        expected = _expected_editor_duplicate(base, prior, current,
            [dict(**row, sources=sources) for row in created])
        active['editor_duplicate_expected'] = expected
        dirty_now = base._dirty(u)
        assert dirty_now['maps'] == prior['expected_reported_dirty_maps'] and dirty_now['content'] == [], dirty_now
        base._verify_guards(prior['immutable_guards'])
        base._collision_map(prior['immutable_guards'])
        base._verify_owned_asset_rows(active['owned_assets'])
    except Exception as exc:
        active['stage'] = 'stage_failed'
        result = _write('runtime_stage_failure', dict(phase='runtime_stage_failure',
            status='EDITOR_DUPLICATE_STAGE_FAILED_INSPECTION_REQUIRED', preflight=dict(path=path.relative_to(ROOT).as_posix(),
            sha256=preflight_sha256), error=repr(exc), dirty=base._dirty(u),
            created_labels=[a.get_actor_label() for a in active['actors']], map_saved=False,
            recovery='Do not save or retry. Stop PIE if needed, then prepare_failed_discard and root-owned discard/reload.'))
        active['phase_receipts'].append(result)
        raise
    record = dict(phase='runtime_staged_duplicate', status='EDITOR_DUPLICATE_READY_FOR_PIE',
        preflight=dict(path=path.relative_to(ROOT).as_posix(), sha256=preflight_sha256),
        original_hism_count=len(before), editor_hism_count=len(current),
        original_global_instance_count=prior['before_global_instance_count'],
        editor_duplicate_global_instance_count=len(base._global_geometry(current)),
        selected_source_count=len(active['selections']), added_copy_count=len(active['selections']),
        semantic_sha256=base._digest_rows(base._semantic_rows(current)),
        global_mesh_pose_sha256=base._digest_rows(base._global_geometry(current)),
        dirty=dirty_now, expected_reported_dirty_maps=prior['expected_reported_dirty_maps'],
        saved=False, next='Start PIE; call check_pie_duplicate_admission, then partition_hub_in_pie.')
    receipt = _write('runtime_staged_duplicate', record)
    active['phase_receipts'].append(receipt)
    return receipt


def _active_receipt(path, digest, phase):
    active = _state().active
    assert active is not None
    file, data = _receipt(path, digest, phase)
    assert data.get('runtime_adapter_sha256') == _sha(__file__)
    assert data.get('base_tool_sha256') == BASE_SHA256
    return active, file, data


def _pie():
    u = _u()
    game = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert game and 'Warrens_VariantC_Mars_MAP' in game.get_name()
    return game


def check_pie_duplicate_admission(staged_path, staged_sha256):
    active, file, staged = _active_receipt(staged_path, staged_sha256, 'runtime_staged_duplicate')
    base = _base()
    game = None
    try:
        game = _pie()
        actual = base._current_snapshot(base._core(), game)
        base._assert_semantic(actual, active['editor_duplicate_expected'], 'PIE duplicate admission')
        count = len(base._global_geometry(actual))
        prior = base._json(ROOT / active['preflight']['path'])
        expected_count = prior['before_global_instance_count'] + len(prior['selected_live_instances'])
        assert count == expected_count, (count, expected_count)
        active['pie_world'] = game
        active['pie_admitted'] = True
        active['stage'] = 'pie_duplicate_admitted'
        result = _write('runtime_pie_duplicate_admitted', dict(phase='runtime_pie_duplicate_admitted',
            status='PIE_MATCHES_EDITOR_DUPLICATE_ROSTER', staged_receipt=dict(
                path=file.relative_to(ROOT).as_posix(), sha256=staged_sha256),
            hism_count=len(actual), global_instance_count=count, semantic_sha256=base._digest_rows(
                base._semantic_rows(actual)), source_instances_still_present=True, saved=False,
            next='Call partition_hub_in_pie; do not toggle materials before its admission succeeds.'))
        active['phase_receipts'].append(result)
        return result
    except Exception as exc:
        active['pie_world'] = game
        active['stage'] = 'pie_duplicate_admission_failed'
        result = _write('runtime_pie_duplicate_failure', dict(phase='runtime_pie_duplicate_failure',
            status='PIE_DUPLICATE_ADMISSION_FAILED_INSPECTION_REQUIRED', staged_receipt=dict(
                path=file.relative_to(ROOT).as_posix(), sha256=staged_sha256), error=repr(exc), saved=False,
            recovery='Stop PIE; prepare_failed_discard; root owns explicit discard/reload.'))
        active['phase_receipts'].append(result)
        raise


def _partition_expected(base, original, selected_poses):
    expected = json.loads(json.dumps(original))
    for path, poses in selected_poses.items():
        matches = [(key, row) for key, row in expected.items() if row['path'] == path]
        assert len(matches) == 1, ('Expected unique source row for removal', path)
        key, row = matches[0]
        remaining = list(row['instances'])
        for pose in poses:
            found = [index for index, item in enumerate(remaining) if base._pose_equivalent(item, pose)]
            assert len(found) == 1, ('Selected source pose missing/ambiguous', path, pose)
            remaining.pop(found[0])
        row['instances'] = remaining
    return expected


def _partition_hub_in_pie_impl(admission_path, admission_sha256):
    active, file, admission = _active_receipt(admission_path, admission_sha256, 'runtime_pie_duplicate_admitted')
    assert active['pie_admitted'] and active['stage'] == 'pie_duplicate_admitted'
    base, core, u = _base(), _base()._core(), _u()
    game = _pie()
    assert game == active['pie_world']
    pre = base._current_snapshot(core, game)
    base._assert_semantic(pre, active['editor_duplicate_expected'], 'pre-partition PIE roster')
    _, sources = _source_components(u, core, game)
    prior = base._json(ROOT / active['preflight']['path'])
    fit, selected_rows, _ = base._fit(prior['selection']['selected_source_keys'])
    hub_transform = sources['CCS15']['actor'].get_level_transform()
    grouped = {ident: [] for ident in sources}
    grouped_poses = {ident: [] for ident in sources}
    for item in prior['selected_live_instances']:
        row = selected_rows[item['source_key']]
        wanted = core._row_transform(u, row, base.PIVOT, hub_transform)
        component = sources[item['ident']]['component']
        found = [index for index in range(component.get_instance_count())
                 if core._near(component.get_instance_transform(index, world_space=True), wanted)]
        assert len(found) == 1, ('PIE source-pose rematch must be unique', item['source_key'], item['ident'], found)
        index = found[0]
        pose = core._pose(component.get_instance_transform(index, world_space=True))
        grouped[item['ident']].append(index)
        grouped_poses[item['ident']].append(pose)
    assert sum(map(len, grouped.values())) == len(prior['selected_live_instances'])
    assert all(len(indices) == len(set(indices)) for indices in grouped.values()), \
        'Selected source rematches collide within a Hub source component'
    active['stage'] = 'pie_partition_started'
    try:
        for ident, indices in grouped.items():
            assert len(indices) == len(set(indices))
            component = sources[ident]['component']
            component.modify()
            for index in sorted(indices, reverse=True):
                assert component.remove_instance(index), ('PIE source removal failed', ident, index)
        post = base._current_snapshot(core, game)
        expected = json.loads(json.dumps(active['editor_duplicate_expected']))
        selected_pose_by_editor_path = {prior['source_components'][ident]['path']: grouped_poses[ident]
                                        for ident in sources}
        expected = _partition_expected(base, expected, selected_pose_by_editor_path)
        base._assert_semantic(post, expected, 'partitioned PIE semantic roster')
        geometry = base._global_geometry(post)
        assert len(geometry) == prior['before_global_instance_count']
        assert base._digest_rows(geometry) == prior['before_global_geometry_sha256'], \
            'Partitioned PIE mesh/pose multiset differs from pre-trial world'
        base._groups(u, game)
        active['pie_partition_expected'] = expected
        active['stage'] = 'pie_partitioned_A'
        result = _write('runtime_pie_partitioned', dict(phase='runtime_pie_partitioned',
            status='PIE_SOURCE_PARTITION_ADMITTED', admission_receipt=dict(
                path=file.relative_to(ROOT).as_posix(), sha256=admission_sha256),
            selected_source_count=len(prior['selected_live_instances']), removed_per_source={k: len(v) for k, v in grouped.items()},
            hism_count=len(post), global_instance_count=len(geometry),
            semantic_sha256=base._digest_rows(base._semantic_rows(post)),
            global_mesh_pose_sha256=base._digest_rows(geometry), global_geometry_matches_pretrial=True,
            saved=False, next='Only after this receipt may set_pie_candidate toggle the four owned groups.'))
        active['phase_receipts'].append(result)
        return result
    except Exception as exc:
        active['stage'] = 'pie_partition_failed'
        result = _write('runtime_pie_partition_failure', dict(phase='runtime_pie_partition_failure',
            status='PIE_PARTITION_FAILED_INSPECTION_REQUIRED', admission_receipt=dict(
                path=file.relative_to(ROOT).as_posix(), sha256=admission_sha256), error=repr(exc), saved=False,
            recovery='Stop PIE immediately. No material capture or retry. Then prepare_failed_discard and root discard/reload.'))
        active['phase_receipts'].append(result)
        raise


def partition_hub_in_pie(admission_path, admission_sha256):
    active = _state().active
    try:
        return _partition_hub_in_pie_impl(admission_path, admission_sha256)
    except Exception as exc:
        if active is not None and active.get('stage') != 'pie_partition_failed':
            active['stage'] = 'pie_partition_failed'
            result = _write('runtime_pie_partition_failure', dict(phase='runtime_pie_partition_failure',
                status='PIE_PARTITION_FAILED_INSPECTION_REQUIRED',
                admission_receipt=dict(path=str(admission_path), sha256=admission_sha256),
                error=repr(exc), saved=False,
                recovery='Stop PIE immediately. No material capture or retry. Then prepare_failed_discard and root discard/reload.'))
            active['phase_receipts'].append(result)
        raise


def _set_pie_candidate_impl(enabled, partition_path, partition_sha256):
    active, file, partition = _active_receipt(partition_path, partition_sha256, 'runtime_pie_partitioned')
    assert active['stage'] in ('pie_partitioned_A', 'pie_partitioned_D')
    assert partition['status'] == 'PIE_SOURCE_PARTITION_ADMITTED'
    base, u = _base(), _u()
    game = _pie()
    assert game == active['pie_world']
    before = base._current_snapshot(base._core(), game)
    expected_before = _toggle_expected(active, active['stage'] == 'pie_partitioned_D')
    base._assert_semantic(before, expected_before, 'before candidate switch')
    base._verify_owned_asset_rows(active['owned_assets'])
    try:
        groups = base._groups(u, game)
        labels = {row['label']: row for row in _json(ROOT / active['preflight']['path'])['trial_labels']}
        source_materials = active['source_material_paths']
        for label, row in labels.items():
            axis = row['axis']
            desired = active['candidate_material_paths'][axis] if enabled else source_materials[label]
            if enabled:
                package = ROOT / ('Content/' + desired.removeprefix('/Game/') + '.uasset')
                assert package.is_file() and _sha(package) == active['candidate_package_hashes'][axis]
            material = u.load_asset(desired)
            assert material and base._package(material) == desired
            groups[label].set_material(0, material)
        after = base._current_snapshot(base._core(), game)
        expected = _toggle_expected(active, bool(enabled))
        base._assert_semantic(after, expected, 'after candidate switch')
        base._verify_owned_asset_rows(active['owned_assets'])
        active['stage'] = 'pie_partitioned_D' if enabled else 'pie_partitioned_A'
        result = _write('runtime_pie_D' if enabled else 'runtime_pie_A_restore', dict(
            phase='runtime_candidate' if enabled else 'runtime_restore',
            status='FOUR_OWNED_PARTITIONS_UPDATED' if enabled else 'STAGE_A_RESTORED',
            enabled=bool(enabled), full_semantic_sha256=base._digest_rows(base._semantic_rows(after)),
            global_mesh_pose_sha256=base._digest_rows(base._global_geometry(after)), saved=False))
        active['phase_receipts'].append(result)
        return result
    except Exception as exc:
        active['stage'] = 'pie_candidate_failed'
        result = _write('runtime_candidate_failure', dict(phase='runtime_candidate_failure',
            status='PIE_CANDIDATE_SWITCH_FAILED_INSPECTION_REQUIRED', enabled=bool(enabled), error=repr(exc),
            saved=False, recovery='Stop PIE and use prepare_failed_discard; no retry.'))
        active['phase_receipts'].append(result)
        raise


def set_pie_candidate(enabled, partition_path, partition_sha256):
    active = _state().active
    try:
        return _set_pie_candidate_impl(enabled, partition_path, partition_sha256)
    except Exception as exc:
        if active is not None and active.get('stage') != 'pie_candidate_failed':
            active['stage'] = 'pie_candidate_failed'
            result = _write('runtime_candidate_failure', dict(phase='runtime_candidate_failure',
                status='PIE_CANDIDATE_SWITCH_FAILED_INSPECTION_REQUIRED', enabled=bool(enabled),
                partition_receipt=dict(path=str(partition_path), sha256=partition_sha256), error=repr(exc),
                saved=False, recovery='Stop PIE and use prepare_failed_discard; no retry.'))
            active['phase_receipts'].append(result)
        raise


def _toggle_expected(active, enabled):
    base = _base()
    expected = json.loads(json.dumps(active['pie_partition_expected']))
    for row in expected.values():
        label = row['owner_label']
        if label not in {entry['label'] for entry in _json(ROOT / active['preflight']['path'])['trial_labels']}:
            continue
        trial = next(item for item in _json(ROOT / active['preflight']['path'])['trial_labels'] if item['label'] == label)
        row['materials'][0] = (active['candidate_material_paths'][trial['axis']] if enabled
                               else active['source_material_paths'][label])
    return expected


def prepare_exit_pie():
    active = _state().active
    assert active and active['stage'] == 'pie_partitioned_A', 'Restore Stage A and verify PIE partition before stop'
    base, u = _base(), _u()
    game = _pie()
    assert game == active['pie_world']
    now = base._current_snapshot(base._core(), game)
    base._assert_semantic(now, active['pie_partition_expected'], 'partitioned Stage A before stop')
    geom = base._global_geometry(now)
    prior = _json(ROOT / active['preflight']['path'])
    assert len(geom) == prior['before_global_instance_count']
    assert base._digest_rows(geom) == prior['before_global_geometry_sha256']
    result = _write('runtime_pie_exit_ready', dict(phase='runtime_pie_exit_ready',
        status='PARTITIONED_STAGE_A_READY_TO_STOP_PIE', hism_count=len(now),
        global_instance_count=len(geom), saved=False))
    active['phase_receipts'].append(result)
    active['stage'] = 'pie_exit_ready'
    return result


def _release_for_discard(active, base, u, evidence, phase):
    editor = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    assert editor.get_game_world() is None, 'Stop PIE before discard preparation'
    world, dirty = base._editor(u, require_clean=False)
    assert world == active['world']
    current = base._current_snapshot(base._core(), world)
    if active.get('editor_duplicate_expected') is not None:
        base._assert_semantic(current, active['editor_duplicate_expected'], 'editor duplicate after PIE stop')
    else:
        _assert_original_plus_trial(base, current, active['original_snapshot'], 'original editor rows after failed stage')
    prior = _json(ROOT / active['preflight']['path'])
    allowed_dirty = prior['expected_reported_dirty_maps']
    if phase == 'runtime_stage_failure':
        assert set(dirty['maps']).issubset(allowed_dirty) and dirty['content'] == [], dirty
    else:
        assert dirty['maps'] == allowed_dirty and dirty['content'] == [], dirty
    base._verify_guards(active['original_guards'])
    base._collision_map(active['original_guards'])
    base._verify_owned_asset_rows(active['owned_assets'])
    main_rel = 'Content/Mars/Maps/Warrens_VariantC_Mars_MAP.umap'
    assert active['original_guards'][main_rel] == _sha(ROOT / main_rel)
    assert active['settings']['editor'].get_editor_property('bAutoSaveEnable') is False
    assert active['settings']['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave') == \
        type(active['settings']['cook']).DISABLE
    original = active['original_snapshot']
    active['discard_expected_original'] = original
    active['world'] = active['pie_world'] = None
    active['actors'] = active['components'] = active['created'] = active['source_components'] = None
    active['materials'] = active['source_materials'] = active['source_material_paths'] = None
    active['editor_duplicate_expected'] = active['pie_partition_expected'] = active['original_snapshot'] = None
    active['stage'] = 'ready_for_root_discard'
    result = _write('runtime_discard_ready', dict(phase='runtime_discard_ready',
        status='READY_FOR_EXPLICIT_MONOLITH_DISCARD', evidence=evidence, dirty=dirty,
        trial_maps=prior['allowed_dirty_maps'], guards_verified=True, collision_count=54,
        owned_assets=active['owned_assets'], map_saved=False,
        root_action='Use the approved Monolith load_level discard wrapper. This helper never loads or saves a map.'))
    active['phase_receipts'].append(result)
    return result


def prepare_discard(exit_path, exit_sha256):
    active, file, receipt = _active_receipt(exit_path, exit_sha256, 'runtime_pie_exit_ready')
    return _release_for_discard(active, _base(), _u(), dict(path=file.relative_to(ROOT).as_posix(),
        sha256=exit_sha256, phase=receipt['phase']), receipt['phase'])


def prepare_failed_discard(failure_path, failure_sha256):
    active = _state().active
    assert active is not None
    candidate = Path(failure_path)
    if not candidate.is_absolute():
        candidate = ROOT / candidate
    candidate = candidate.resolve()
    assert candidate.is_relative_to(RUN.resolve()) and candidate.is_file() and _sha(candidate) == failure_sha256
    failure_phase = _json(candidate).get('phase')
    file, failure = _receipt(candidate, failure_sha256, failure_phase)
    assert failure_phase in ('runtime_stage_failure', 'runtime_pie_duplicate_failure',
        'runtime_pie_partition_failure', 'runtime_candidate_failure')
    active = _state().active
    active['settings']['editor'].set_editor_property('bAutoSaveEnable', False)
    active['settings']['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave',
        type(active['settings']['cook']).DISABLE)
    assert active['settings']['editor'].get_editor_property('bAutoSaveEnable') is False
    assert active['settings']['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave') == \
        type(active['settings']['cook']).DISABLE
    return _release_for_discard(active, _base(), _u(), dict(path=file.relative_to(ROOT).as_posix(),
        sha256=failure_sha256, phase=failure_phase), failure_phase)


def after_reload(discard_path, discard_sha256):
    active, file, discard = _active_receipt(discard_path, discard_sha256, 'runtime_discard_ready')
    base, u = _base(), _u()
    world, dirty = base._editor(u)
    assert dirty == dict(maps=[], content=[])
    current = base._current_snapshot(base._core(), world)
    base._assert_semantic(current, active['discard_expected_original'], 'original after explicit discard/reload')
    base._verify_guards(active['original_guards'])
    assert all(_sha(ROOT / path) == digest for path, digest in active['collision'].items())
    base._verify_owned_asset_rows(active['owned_assets'])
    settings = active['settings']
    settings['editor'].set_editor_property('bAutoSaveEnable', settings['autosave'])
    settings['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave', settings['cook'])
    assert settings['editor'].get_editor_property('bAutoSaveEnable') == settings['autosave']
    assert settings['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave') == settings['cook']
    result = _write('runtime_after_reload', dict(phase='runtime_after_reload',
        status='ORIGINAL_MAP_RELOADED_AND_VERIFIED', discard_receipt=dict(
            path=file.relative_to(ROOT).as_posix(), sha256=discard_sha256),
        original_semantic_sha256=base._digest_rows(base._semantic_rows(current)),
        original_global_geometry_sha256=base._digest_rows(base._global_geometry(current)),
        original_hism_count=len(current), global_instance_count=len(base._global_geometry(current)),
        guards_verified=True, collision_count=54, dirty=dirty, settings_restored=True, saved=False))
    _state().active = None
    return result

