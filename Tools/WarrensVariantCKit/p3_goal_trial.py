"""Reversible P3 paired-seal comparison in the current Variant C PIE world.

Import is inert. Run preflight_trial(), apply_trial(receipt, sha),
toggle_trial(False/True), then restore_trial(). The only world edits are moving
the two existing Ossuary HISM instances and temporarily appending/removing their
matching cache copies. This tool never saves a map or content package.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
CHECKPOINT = ROOT / 'Saved/WarrensCGameplay-20261024/P3GoalTrial'
CORE_PATH = HERE / 'bank_identity_unreal.py'
CORE_SHA256 = '4859e7ab71dc9e0a5d93b61511eb759ef741598af4821ba62df69cd8ee014619'
FIT = HERE / 'Output/fitted_instances.json'
SURVEY = ROOT / 'Saved/WarrensCGameplay-20261024/P3GoalWallSurvey/receipt.outer2.json'
SURVEY_SHA256 = '878aea3cebe41061f80d1e5b8615fe103226d9c320e6b2e2cc8c9e30fe675da9'
PREVIEW = REVIEW / 'p3-goal-preview/r01/receipt.json'
PREVIEW_SHA256 = '619f468e5fa52ec74d84a58e4a6e4c1cafda3f61377d7663805b84f9dfefe92c'
APPROVAL = REVIEW / 'p3-goal-preview/r01/ASTRA_REVIEW.md'
APPROVAL_SHA256 = 'b4eb203d59bbc986409aa2547a9ca14a493ff002b2d22ddd2de9899883885d35'
LIBRARY_VERIFY = ROOT / 'Saved/WarrensCGameplay-20261024/art_verify_belfry_libraries_root_20261025.json'
LIBRARY_VERIFY_SHA256 = '81ffb1e9ce424ef229342e2f9477f2fd815114667b9b3395f4c2e53f26b97157'
STATE_MODULE = '_mars_warrensc_p3_goal_trial_state'
SOURCE_MESHES = {
    'board': '/Game/Mars/Environment/ChainCrossingKit/Meshes/WarrensC_CCS78_MaintenanceNoticeBoard_Mars_SM',
    'card': '/Game/Mars/Environment/WarrensVariantCKit/Meshes/WarrensC_WVC083_EmblemSurfaceCarrier_Mars_SM',
}
ART04_MATERIAL_NAME = 'WarrensC_MournerServiceSeal_Mars_MI'
SOURCE_ROWS = {
    'board': dict(tile='Ossuary', ident='CCS78', index=37274),
    'card': dict(tile='Ossuary', ident='WVC083_ART04', index=37275),
}
LEVEL_TILES = ('Ossuary', 'Reliquary')


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _write_unique(kind, record):
    CHECKPOINT.mkdir(parents=True, exist_ok=True)
    token = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '_' + uuid.uuid4().hex[:8]
    path = CHECKPOINT / (kind + '_' + token + '.json')
    assert not path.exists(), 'Refuse to overwrite a P3 trial receipt'
    record.update(schema=1, created_utc=datetime.now(timezone.utc).isoformat(), tool_sha256=_sha(__file__))
    path.write_text(json.dumps(record, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    return path


def _u():
    import unreal
    return unreal


def _core():
    assert _sha(CORE_PATH) == CORE_SHA256, 'Frozen HISM/guard helper changed'
    name = '_mars_warrensc_p3_goal_trial_core'
    module = sys.modules.get(name)
    if module is None:
        spec = importlib.util.spec_from_file_location(name, CORE_PATH)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules[name] = module
    return module


def _approval_inputs():
    assert _sha(SURVEY) == SURVEY_SHA256, 'Approved outer P3 source survey changed'
    assert _sha(PREVIEW) == PREVIEW_SHA256, 'Approved P3 static preview receipt changed'
    assert _sha(APPROVAL) == APPROVAL_SHA256, 'Astra P3 trial approval changed'
    assert _sha(LIBRARY_VERIFY) == LIBRARY_VERIFY_SHA256, 'Current 30-pass library verifier receipt changed'
    review = APPROVAL.read_text(encoding='utf-8')
    assert 'APPROVED for a disposable, unsaved PIE comparison only' in review
    assert 'persistent map and library adoption remain unapproved' in review
    survey = _json(SURVEY)
    preview = _json(PREVIEW)
    verifier = _json(LIBRARY_VERIFY)
    assert survey['candidate']['board']['at'] == [40.027000919612355, 66.0, 3.0]
    assert survey['candidate']['card']['at'] == [40.048000919612356, 66.0, 3.0]
    assert survey['cache_candidate']['board']['at'] == [99.9729995727539, 74.39999961853027, 3.0]
    assert survey['cache_candidate']['card']['at'] == [99.9519995727539, 74.39999961853027, 3.0]
    assert preview['old_pair']['source_keys'] == ['37274', '37275']
    assert preview['material']['name'] == ART04_MATERIAL_NAME
    assert verifier.get('status') == 'PASS' and verifier.get('counts', {}).get('pass') == 30
    assert verifier.get('counts', {}).get('fail') == 0 and verifier.get('counts', {}).get('pending') == 0
    assert len(verifier.get('checks', [])) == 30 and all(row.get('status') == 'PASS' for row in verifier['checks'])
    return dict(
        survey=dict(path=SURVEY.relative_to(ROOT).as_posix(), sha256=SURVEY_SHA256),
        preview=dict(path=PREVIEW.relative_to(ROOT).as_posix(), sha256=PREVIEW_SHA256),
        approval=dict(path=APPROVAL.relative_to(ROOT).as_posix(), sha256=APPROVAL_SHA256),
        current_library_verifier=dict(path=LIBRARY_VERIFY.relative_to(ROOT).as_posix(), sha256=LIBRARY_VERIFY_SHA256,
                                      passing_checks=30))


def _fit_source_rows(core):
    fit = core._json(FIT)
    result = {}
    for key, spec in SOURCE_ROWS.items():
        row = fit['placements'][spec['index']]
        assert row.get('tile') == spec['tile'] and row.get('id') == spec['ident'], (key, row)
        assert row.get('collision') == 'NoCollision'
        result[key] = row
    assert fit['pivots']['Ossuary'] == [36, 60, 2.5]
    assert fit['pivots']['Reliquary'] == [80, 66, 2.5]
    return fit, result


def _levels(core, actors):
    levels = {}
    for actor in actors:
        level = actor.get_level()
        path = level.get_path_name()
        for tile in LEVEL_TILES:
            if 'LI_Warrens_' + tile in path:
                levels.setdefault(tile, (level, actor))
    assert set(levels) == set(LEVEL_TILES), ('Need loaded Ossuary and Reliquary Level Instances', sorted(levels))
    for tile, (level, _) in levels.items():
        matches = {a.get_level().get_path_name() for a in actors if a.get_level() == level}
        assert len(matches) == 1 and 'LI_Warrens_' + tile in next(iter(matches))
    return levels


def _target_transforms(core, fit, rows, levels, survey):
    u = _u()
    targets = {}
    for key in ('board', 'card'):
        target_row = survey['candidate'][key]
        cache_row = survey['cache_candidate'][key]
        for label, row, tile in (('plate', target_row, 'Ossuary'), ('cache', cache_row, 'Reliquary')):
            fake = dict(at=row['at'], yaw=row['yaw'], scale=row['scale'])
            transform = core._row_transform(u, fake, fit['pivots'][tile], levels[tile][1].get_level_transform())
            targets[label + '_' + key] = transform
    return targets


def _resolve_sources(core, u, actors, levels, fit, rows):
    result = {}
    ossuary = levels['Ossuary'][0]
    for key, row in rows.items():
        expected_mesh = SOURCE_MESHES[key]
        expected = core._row_transform(u, row, fit['pivots']['Ossuary'], levels['Ossuary'][1].get_level_transform())
        matches = []
        for actor in actors:
            if actor.get_level() != ossuary:
                continue
            for component in actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent):
                if core._package(component.static_mesh) != expected_mesh:
                    continue
                assert component.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
                for index in range(component.get_instance_count()):
                    actual = component.get_instance_transform(index, world_space=True)
                    if core._near(actual, expected):
                        matches.append((actor, component, index, actual))
        assert len(matches) == 1, (key, 'source HISM instance did not resolve uniquely', len(matches))
        actor, component, index, original_transform = matches[0]
        if key == 'card':
            material_names = [m.get_name() for m in component.get_materials() if m]
            material_paths = [m.get_path_name() for m in component.get_materials() if m]
            assert any(ART04_MATERIAL_NAME in value or 'ART04' in value for value in material_names + material_paths), (
                'Source card is not visibly bound to the approved ART04 material', material_names, material_paths)
        result[key] = dict(actor=actor.get_path_name(), actor_label=actor.get_actor_label(),
            component=component.get_path_name(), index=index, source_pose=core._pose(original_transform),
            component_snapshot=core._component(component), original_transform=original_transform,
            component_object=component)
    return result


def _state_holder():
    if STATE_MODULE not in sys.modules:
        import types
        sys.modules[STATE_MODULE] = types.ModuleType(STATE_MODULE)
        sys.modules[STATE_MODULE].active = None
    return sys.modules[STATE_MODULE]


def _receipt(path, digest, phase):
    path = Path(path)
    if not path.is_absolute():
        path = ROOT / path
    path = path.resolve()
    checkpoint = CHECKPOINT.resolve()
    try:
        path.relative_to(checkpoint)
    except ValueError:
        raise AssertionError('Refuse a P3 trial receipt outside the owned checkpoint')
    assert path.is_file() and _sha(path) == digest, phase + ' receipt hash mismatch'
    value = _json(path)
    assert value.get('phase') == phase and value.get('schema') == 1
    assert value.get('status') == 'PIE_P3_SOURCE_AND_TARGETS_RESOLVED'
    return path, value


def _pie_world(u):
    world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert world and 'Warrens_VariantC_Mars_MAP' in world.get_name(), 'Requires active Variant C PIE'
    return world


def _target_pose(state, name):
    return state['targets'][name]


def _update_instance(component, index, transform):
    assert callable(getattr(component, 'update_instance_transform', None)), \
        'This Unreal Python binding lacks UInstancedStaticMeshComponent.update_instance_transform'
    assert component.update_instance_transform(index, transform, True, True, True)


def _append_cache(state, key):
    component = state['sources'][key]['component_object']
    before = component.get_instance_count()
    target = _target_pose(state, 'cache_' + key)
    returned = list(component.add_instances([target], True, True, False))
    assert returned == [before] and component.get_instance_count() == before + 1
    state['cache_indices'][key] = before
    core = state['core']
    u = _u()
    assert core._near(component.get_instance_transform(before, world_space=True), target)
    assert component.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION


def _remove_cache(state, key):
    component = state['sources'][key]['component_object']
    baseline_count = len(state['baseline'][component.get_path_name()]['instances'])
    candidates = []
    expected = _target_pose(state, 'cache_' + key)
    for index in range(baseline_count, component.get_instance_count()):
        if state['core']._near(component.get_instance_transform(index, world_space=True), expected):
            candidates.append(index)
    assert len(candidates) == 1, (key, 'expected exactly one temporary cache instance', candidates)
    assert candidates[0] == component.get_instance_count() - 1, 'Refuse to remove across unrelated appended HISM instances'
    assert component.remove_instance(candidates[0])
    state['cache_indices'].pop(key, None)


def _verify_world(state, mode):
    _, current = state['core']._hism_snapshot(state['world'])
    assert current.keys() == state['baseline'].keys(), 'HISM component roster changed during disposable trial'
    targeted = {state['sources'][key]['component']: key for key in ('board', 'card')}
    for path, before in state['baseline'].items():
        now = current[path]
        key = targeted.get(path)
        if not key:
            assert now == before, (path, 'untouched HISM component changed')
            continue
        assert {k: v for k, v in now.items() if k != 'instances'} == \
               {k: v for k, v in before.items() if k != 'instances'}
        source = state['sources'][key]
        index = source['index']
        wanted = state['targets']['plate_' + key] if mode == 'after' else source['original_transform']
        component = source['component_object']
        actual = component.get_instance_transform(index, world_space=True)
        assert state['core']._near(actual, wanted), (key, mode, 'original instance pose mismatch')
        assert len(now['instances']) == len(before['instances']) + (1 if mode == 'after' else 0)
        for idx, pose in enumerate(before['instances']):
            if idx != index:
                assert now['instances'][idx] == pose, (path, idx, 'unrelated instance changed')
        if mode == 'after':
            appended = component.get_instance_transform(len(before['instances']), world_space=True)
            assert state['core']._near(appended, state['targets']['cache_' + key])
    return current


def _transform_from_pose(u, value):
    return u.Transform(location=u.Vector(*value['at']),
        rotation=u.Quat(value['q'][0], value['q'][1], value['q'][2], value['q'][3]).rotator(),
        scale=u.Vector(*value['scale']))


def _record_transition(state, phase, status, **extra):
    previous = dict(path=state.get('last_receipt'), sha256=state.get('last_receipt_sha256'))
    report = dict(phase=phase, status=status, world_path=state['world'].get_path_name(),
        mode=state.get('mode'), previous_receipt=previous, **extra)
    path = _write_unique(phase, report)
    state['last_receipt'] = path.relative_to(ROOT).as_posix()
    state['last_receipt_sha256'] = _sha(path)
    return dict(receipt=state['last_receipt'], sha256=state['last_receipt_sha256'], status=status)


def preflight_trial():
    """Read-only inventory of exact Ossuary sources, live levels, and approved targets."""
    core = _core()
    u = _u()
    holder = _state_holder()
    assert holder.active is None, 'Restore any active P3 trial before preflight'
    approvals = _approval_inputs()
    assert core._dirty() == dict(maps=[], content=[]), 'PIE trial requires clean map/content packages'
    chain = core._promotion_chain()
    guards = core._content_guards()
    world = _pie_world(u)
    actors, snapshot = core._hism_snapshot(world)
    levels = _levels(core, actors)
    fit, rows = _fit_source_rows(core)
    sources = _resolve_sources(core, u, actors, levels, fit, rows)
    assert all(callable(getattr(source['component_object'], 'update_instance_transform', None))
               for source in sources.values()), 'Required update_instance_transform binding is unavailable'
    targets = _target_transforms(core, fit, rows, levels, _json(SURVEY))
    for key in ('board', 'card'):
        for label in ('plate_', 'cache_'):
            wanted = targets[label + key]
            assert not any(core._near(c.get_instance_transform(i, world_space=True), wanted)
                for actor in actors for c in actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
                for i in range(c.get_instance_count())), ('Target already occupied by a HISM instance', label + key)
    path = _write_unique('pie_preflight', dict(phase='pie_preflight', status='PIE_P3_SOURCE_AND_TARGETS_RESOLVED',
        world_path=world.get_path_name(), levels={tile: level.get_path_name() for tile, (level, _) in levels.items()},
        source_rows={key: rows[key] for key in rows}, sources={key: {k: v for k, v in source.items()
            if k not in ('component_object', 'original_transform')} for key, source in sources.items()},
        target_poses={key: core._pose(value) for key, value in targets.items()},
        original_hism_roster=snapshot, approval_inputs=approvals, library_chain=chain,
        file_guards=guards, dirty_before=core._dirty(),
        boundary='Read-only source-instance admission in active Variant C PIE; no HISM or asset/map state changed.'))
    return dict(receipt=path.relative_to(ROOT).as_posix(), sha256=_sha(path), status='PIE_P3_SOURCE_AND_TARGETS_RESOLVED')


def apply_trial(preflight_file, preflight_sha256):
    """Move the old pair to the plate and append one matching pair at the cache."""
    core = _core()
    u = _u()
    path, prior = _receipt(preflight_file, preflight_sha256, 'pie_preflight')
    holder = _state_holder()
    assert holder.active is None, 'Restore an active P3 trial first'
    assert core._dirty() == dict(maps=[], content=[])
    assert core._content_guards() == prior['file_guards']
    assert core._promotion_chain() == prior['library_chain']
    world = _pie_world(u)
    assert world.get_path_name() == prior['world_path']
    actors, snapshot = core._hism_snapshot(world)
    assert snapshot == prior['original_hism_roster'], 'PIE HISM roster changed after preflight'
    levels = _levels(core, actors)
    fit, rows = _fit_source_rows(core)
    sources = _resolve_sources(core, u, actors, levels, fit, rows)
    targets = _target_transforms(core, fit, rows, levels, _json(SURVEY))
    for name, actual in targets.items():
        assert core._near(actual, _transform_from_pose(u, prior['target_poses'][name])), (name, 'target drift')
    for key in ('board', 'card'):
        binding = prior['sources'][key]
        assert sources[key]['actor'] == binding['actor'] and sources[key]['component'] == binding['component']
        assert sources[key]['index'] == binding['index']
    state = dict(core=core, world=world, world_path=world.get_path_name(), sources=sources,
        targets=targets, baseline=snapshot, file_guards=prior['file_guards'], library_chain=prior['library_chain'],
        dirty=core._dirty(), cache_indices={}, mode='partial', prior_path=path.relative_to(ROOT).as_posix(),
        prior_sha256=preflight_sha256, last_receipt=None, last_receipt_sha256=None)
    holder.active = state
    try:
        for key in ('board', 'card'):
            _update_instance(sources[key]['component_object'], sources[key]['index'], targets['plate_' + key])
        for key in ('board', 'card'):
            _append_cache(state, key)
        _verify_world(state, 'after')
        state['mode'] = 'after'
        return _record_transition(state, 'pie_trial_applied', 'AFTER_ASSEMBLY_ACTIVE',
            preflight=dict(path=state['prior_path'], sha256=preflight_sha256),
            source_indices={key: sources[key]['index'] for key in sources},
            target_poses={key: core._pose(value) for key, value in targets.items()},
            boundary='Unsaved PIE only. Original pair is beside the plate; one temporary cache copy is appended per HISM.')
    except Exception as exc:
        _write_unique('pie_trial_apply_failure', dict(phase='pie_trial_apply_failure', status='PARTIAL_TRIAL_REQUIRES_RESTORE',
            error=repr(exc), world_path=world.get_path_name(), last_receipt=state.get('last_receipt'),
            boundary='Trial state retained for explicit restore; no map or content save was issued.'))
        raise


def toggle_trial(show_after):
    """Toggle the complete paired assembly: old far pair or plate plus cache pair."""
    holder = _state_holder()
    state = holder.active
    assert state and state['mode'] in ('after', 'before')
    u = _u()
    current = _pie_world(u)
    assert current.get_path_name() == state['world_path'] and current == state['world']
    target_mode = 'after' if bool(show_after) else 'before'
    if target_mode == state['mode']:
        raise AssertionError('Requested P3 view is already active')
    try:
        if target_mode == 'before':
            for key in ('card', 'board'):
                _remove_cache(state, key)
            for key in ('board', 'card'):
                _update_instance(state['sources'][key]['component_object'], state['sources'][key]['index'],
                                 state['sources'][key]['original_transform'])
        else:
            for key in ('board', 'card'):
                _update_instance(state['sources'][key]['component_object'], state['sources'][key]['index'],
                                 state['targets']['plate_' + key])
            for key in ('board', 'card'):
                _append_cache(state, key)
        _verify_world(state, target_mode)
        state['mode'] = target_mode
        return _record_transition(state, 'pie_trial_toggle', 'TOGGLED', assembly=target_mode,
            both_board_and_card_changed_together=True,
            boundary='Unsaved PIE comparison; only the two approved NoCollision HISM components changed.')
    except Exception as exc:
        state['mode'] = 'partial'
        _write_unique('pie_trial_toggle_failure', dict(phase='pie_trial_toggle_failure', status='PARTIAL_TRIAL_REQUIRES_RESTORE',
            error=repr(exc), world_path=state['world_path'], previous_mode=target_mode,
            last_receipt=state.get('last_receipt'),
            boundary='Trial state retained for explicit restore; no map or content save was issued.'))
        raise


def restore_trial():
    """Restore exact original HISM instance transforms/roster and release PIE references."""
    holder = _state_holder()
    state = holder.active
    assert state, 'No active P3 PIE trial to restore'
    u = _u()
    world = _pie_world(u)
    assert world.get_path_name() == state['world_path'] and world == state['world']
    try:
        for key in ('card', 'board'):
            component = state['sources'][key]['component_object']
            baseline_count = len(state['baseline'][component.get_path_name()]['instances'])
            if component.get_instance_count() > baseline_count:
                _remove_cache(state, key)
        for key in ('board', 'card'):
            source = state['sources'][key]
            _update_instance(source['component_object'], source['index'], source['original_transform'])
        actors, after = state['core']._hism_snapshot(world)
        assert after == state['baseline'], 'Original full HISM snapshot did not restore exactly'
        assert state['core']._content_guards() == state['file_guards']
        assert state['core']._promotion_chain() == state['library_chain']
        assert state['core']._dirty() == state['dirty'] == dict(maps=[], content=[])
        path = _write_unique('pie_trial_restored', dict(phase='pie_trial_restored', status='RESTORED_AND_VERIFIED',
            world_path=world.get_path_name(), original_hism_count=len(after), original_hism_roster_exact=True,
            maps_unchanged=True, content_unchanged=True, file_guards_unchanged=True,
            library_chain_unchanged=True, dirty_after=state['core']._dirty(),
            preceding_receipt=dict(path=state.get('last_receipt'), sha256=state.get('last_receipt_sha256')),
            boundary='Exact original P3 HISM state restored; no map or content package was saved.'))
        result = dict(receipt=path.relative_to(ROOT).as_posix(), sha256=_sha(path), status='RESTORED_AND_VERIFIED')
        state.clear()
        holder.active = None
        return result
    except Exception as exc:
        _write_unique('pie_trial_restore_failure', dict(phase='pie_trial_restore_failure', status='RESTORE_NOT_VERIFIED',
            error=repr(exc), world_path=world.get_path_name(), last_receipt=state.get('last_receipt'),
            boundary='Retained references and trial state remain available for diagnosis; do not stop PIE yet.'))
        raise
