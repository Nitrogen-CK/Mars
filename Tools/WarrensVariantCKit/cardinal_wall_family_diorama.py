"""Guarded Hall material partition for the separate Variant C Diorama map.

This file is intentionally inert on import. The read-only preflight requires a
fresh root-supplied RELOAD_AUDITED guard receipt. apply() only stages an
unsaved map; save_staged() revalidates that stage in a later callback and uses
LevelEditorSubsystem.save_current_level(). Two explicit unload/reopen audits
follow. First-reopen actor text ordering may vary for the four new actors only;
their native and HISM component exports stay exact. The second reopen must
match the first reopen's canonical exports.
"""
from __future__ import annotations

import copy
import difflib
import hashlib
import importlib.util
import json
import re
import shutil
import sys
import uuid
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOL = Path(__file__).resolve()
CONFIG_DEFAULT = ROOT / 'Saved/WarrensCGameplay-20261024/HallWallDiorama/config.json'


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _write(folder, phase, payload):
    path = Path(folder) / (phase + '_' + uuid.uuid4().hex[:16] + '.json')
    path.parent.mkdir(parents=True, exist_ok=True)
    value = dict(schema='cardinal-wall-family-diorama-v1', created_utc=datetime.now(timezone.utc).isoformat(),
                 tool_path=TOOL.relative_to(ROOT).as_posix(), tool_sha256=_sha(TOOL), **payload)
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n', encoding='utf-8')
    return path


def _rooted(path):
    value = (ROOT / path).resolve()
    assert value.is_relative_to(ROOT.resolve()), ('Path escapes repo', str(path))
    return value


def _load(name, path, expected_sha):
    path = _rooted(path)
    assert path.is_file() and _sha(path) == expected_sha, ('Pinned helper changed', str(path))
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _config(path=CONFIG_DEFAULT):
    path = Path(path).resolve()
    assert path.is_relative_to(ROOT.resolve()) and path.is_file()
    config = _read(path)
    assert config['schema'] == 'cardinal-wall-family-diorama-v1'
    assert _sha(TOOL) == config['tool_sha256'], 'Tool/config hash mismatch'
    for item in config.get('previous_attempt', {}).get('pinned_files', []):
        assert _sha(_rooted(item['path'])) == item['sha256']
    config['_path'] = path
    config['_sha'] = _sha(path)
    return config


def _deps(config):
    h = config['helpers']
    sync = _load('_cardinal_diorama_sync', h['sync']['path'], h['sync']['sha256'])
    core = _load('_cardinal_diorama_core', h['core']['path'], h['core']['sha256'])
    # Only _full_exports is reused. The Ossuary helper's map, material,
    # selection, authorization and promotion contracts are deliberately unused.
    old = _load('_cardinal_diorama_readonly_exports', h['readonly_exports']['path'],
                h['readonly_exports']['sha256'])
    wall_material = _load('_cardinal_diorama_export_dependency', h['export_dependency']['path'],
                          h['export_dependency']['sha256'])
    assert callable(old._full_exports)
    return sync, core, old, wall_material


def _guards(config, receipt_file, receipt_sha, check_map=True):
    path = _rooted(receipt_file)
    assert path.is_file() and _sha(path) == receipt_sha
    receipt = _read(path)
    assert receipt.get('status') == config['source_guard']['required_status'] == 'RELOAD_AUDITED'
    table = receipt.get('immutable_guards') or receipt.get('protected_files') or receipt.get('immutable_file_guards')
    assert isinstance(table, dict) and table, 'Fresh source guard has no immutable file table'
    expected = {}
    for rel, digest in table.items():
        target = _rooted(rel)
        assert target.is_file(), ('Guarded file missing', rel)
        if check_map or rel != config['family']['map_file']:
            assert _sha(target) == digest, ('Immutable guard mismatch', rel)
        expected[rel] = digest
    for rel in config['source_guard']['required_files']:
        assert rel in table, ('Fresh guard receipt omits required file', rel)
        target = _rooted(rel)
        assert target.is_file() and (not check_map and rel == config['family']['map_file'] or
                                     _sha(target) == table[rel]), ('Guard mismatch', rel)
        expected[rel] = table[rel]
    for item in config['asset_guards']:
        target = _rooted(item['file'])
        assert target.is_file() and _sha(target) == item['sha256'], ('Protected asset changed', item['file'])
        assert table.get(item['file']) == item['sha256'], ('Fresh receipt does not pin protected asset', item['file'])
        expected[item['file']] = item['sha256']
    collision_item = config['collision_hashes']
    collision_path = _rooted(collision_item['path'])
    assert collision_path.is_file() and _sha(collision_path) == collision_item['sha256']
    collision = _read(collision_path)
    assert isinstance(collision, dict) and len(collision) == collision_item['expected_count'] == 54
    for rel, digest in collision.items():
        target = _rooted(rel)
        assert target.is_file() and _sha(target) == digest, ('Collision guard mismatch', rel)
    return dict(path=path.relative_to(ROOT).as_posix(), sha256=receipt_sha,
                status=receipt['status'], table=table, required=expected,
                collision_path=collision_path.relative_to(ROOT).as_posix(),
                collision_sha256=collision_item['sha256'], collision_hashes=collision)


def _selection(config, sync):
    f = config['family']
    for item in (f['selection'], f['fitted_instances'], f['runtime_approval'], f['hall_asset_receipt'], f['cellar_asset_receipt']):
        path = _rooted(item['path'])
        assert path.is_file() and _sha(path) == item['sha256'], ('Family input changed', item['path'])
    selection = _read(_rooted(f['selection']['path']))
    fitted = _read(_rooted(f['fitted_instances']['path']))
    keys = selection['selected_source_keys']
    assert len(keys) == len(set(keys)) == f['expected_instance_count'] == 144
    axis = {}
    for pair in selection['pairs']:
        value = int(pair['axis'])
        assert value in (0, 1)
        for key in pair['source_keys']:
            assert key not in axis
            axis[key] = value
    assert set(axis) == set(keys)
    placements = fitted['placements']
    assert max(keys) < len(placements)
    allowed = set(f['source_ids'])
    for key in keys:
        row = placements[key]
        assert row['id'] in allowed and row.get('tile') == 'Hub'
        assert row.get('role') in f['source_roles']
    return selection, fitted, axis


def _source_components(sync, world):
    u = sync.u
    found = {}
    for actor in u.GameplayStatics.get_all_actors_of_class(world, u.Actor):
        for ident, label in (('CCS15', 'WVC_CCS15'), ('BACKING_TX01', 'WVC_BACKING_TX01')):
            if actor.get_actor_label() == label:
                assert ident not in found
                components = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
                assert len(components) == 1
                component, = components
                assert str(component.get_collision_profile_name()) == 'NoCollision'
                assert component.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
                assert not component.get_editor_property('generate_overlap_events')
                found[ident] = (actor, component)
    assert set(found) == {'CCS15', 'BACKING_TX01'}
    return found


def _selected_indices(sync, core, config, world, fitted, axis):
    u = sync.u
    f = config['family']
    components = _source_components(sync, world)
    by_id = {ident: [] for ident in f['source_ids']}
    for key in sorted(axis):
        row = fitted['placements'][key]
        ident = row['id']
        actor, component = components[ident]
        mesh_path = f['expected_meshes'][ident]
        mesh = u.load_asset(mesh_path)
        assert mesh and sync.asset(component.static_mesh) == sync.asset(mesh)
        expected_materials = sync.materials(row, mesh)
        assert [sync.asset(m) for m in component.get_materials()] == expected_materials
        snapshot = core._component(component)
        at, rotation, scale = sync.expected_pose(row, tuple(f['pivot']))
        matches = []
        for i in range(component.get_instance_count()):
            t = component.get_instance_transform(i, world_space=True)
            if ((t.translation - at).length() < .1 and (t.scale3d - scale).length() < .001
                    and t.rotation.angular_distance(rotation) < .001):
                matches.append(i)
        assert len(matches) == 1, ('source instance missing or ambiguous', key, matches)
        by_id[ident].append(dict(key=key, axis=axis[key], index=matches[0], row=row,
                                 world_pose=copy.deepcopy(snapshot['instances'][matches[0]])))
    assert {k: len(v) for k, v in by_id.items()} == {'CCS15': 72, 'BACKING_TX01': 72}
    assert {ident: {str(ax): sum(x['axis'] == ax for x in rows) for ax in (0, 1)}
            for ident, rows in by_id.items()} == f['group_counts']
    assert len({(ident, x['index']) for ident, rows in by_id.items() for x in rows}) == 144
    return components, by_id


def _settings(u):
    cls = u.load_class(None, '/Script/UnrealEd.EditorLoadingSavingSettings')
    assert cls
    editor = u.get_default_object(cls)
    autosave = editor.get_editor_property('bAutoSaveEnable')
    jolt_cls = u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    assert jolt_cls
    jolt = u.get_default_object(jolt_cls)
    cook = jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    assert isinstance(autosave, bool) and hasattr(type(cook), 'DISABLE')
    return editor, autosave, jolt, cook


def _enum_name(value):
    name = getattr(value, 'name', None)
    if name:
        return name
    for candidate in dir(type(value)):
        if candidate.startswith('_'):
            continue
        try:
            if getattr(type(value), candidate) == value:
                return candidate
        except Exception:
            continue
    return None


def _full(sync, core, old, wall_material, world, folder):
    result = old._full_exports(wall_material, core, sync.u, world, folder)
    actors = {actor.get_name(): actor for actor in sync.u.GameplayStatics.get_all_actors_of_class(world, sync.u.Actor)}
    assert set(actors) == set(result)
    for name, actor in actors.items():
        result[name]['folder'] = str(actor.get_folder_path())
    return result


def _export_projection(old, exports):
    return old._export_projection(exports)


def _global_geometry(roster):
    values = []
    for actor in roster.values():
        for component in actor['components'].values():
            hism = component.get('hism')
            if hism:
                values.extend(dict(mesh=hism['mesh'], pose=pose) for pose in hism['instances'])
    return sorted(values, key=lambda row: json.dumps(row, sort_keys=True, separators=(',', ':')))


def _canonical_hism(row):
    value = copy.deepcopy(row)
    for field in ('path', 'owner', 'level'):
        value.pop(field, None)
    value['instances'] = sorted(value['instances'],
        key=lambda pose: json.dumps(pose, sort_keys=True, separators=(',', ':')))
    return value


def _hism_count(roster):
    return sum(len(c['hism']['instances']) for a in roster.values()
               for c in a['components'].values() if 'hism' in c)


def _hism_count_for_labels(roster, labels):
    return sum(_hism_counts_by_labels(roster, labels).values())


def _hism_counts_by_labels(roster, labels):
    result = {}
    for label in labels:
        rows = [actor for actor in roster.values() if actor['label'] == label]
        assert len(rows) == 1, ('Expected unique retained actor', label, len(rows))
        hisms = [c['hism'] for c in rows[0]['components'].values() if 'hism' in c]
        assert len(hisms) == 1, ('Expected one retained HISM', label, len(hisms))
        result[label] = len(hisms[0]['instances'])
    return result


def _verify_full_delta(sync, core, config, before, after, selected, groups, source_labels):
    """Check complete raw exports plus every source and spawned HISM contract."""
    labels = {label for label in source_labels.values()}
    new_names = {entry['actor_name'] for entry in groups}
    assert len(new_names) == 4
    assert set(after) == set(before) | new_names
    selected_by_label = {source_labels[ident]: rows for ident, rows in selected.items()}
    source_component_names = {}
    for actor_name, old_actor in before.items():
        now = after[actor_name]
        assert (old_actor['label'], old_actor['type'], old_actor['tags'], old_actor['pose'], old_actor['hidden'], old_actor.get('folder')) == \
               (now['label'], now['type'], now['tags'], now['pose'], now['hidden'], now.get('folder')), \
               ('Existing actor metadata changed', actor_name)
        affected = old_actor['label'] in selected_by_label
        if not affected:
            assert old_actor['export_sha256'] == now['export_sha256'], ('Unselected actor raw export changed', actor_name)
        assert set(old_actor['components']) == set(now['components']), ('Existing component set changed', actor_name)
        for name, old_component in old_actor['components'].items():
            actual = now['components'][name]
            assert actual['type'] == old_component['type']
            if old_actor['label'] in selected_by_label and 'hism' in old_component:
                source_component_names[old_actor['label']] = name
                expected_hism = copy.deepcopy(old_component['hism'])
                removals = {item['index'] for item in selected_by_label[old_actor['label']]}
                for index in sorted(removals, reverse=True):
                    expected_hism['instances'].pop(index)
                assert _canonical_hism(actual['hism']) == _canonical_hism(expected_hism), \
                    ('Source HISM changed beyond selected row removal', actor_name)
            else:
                assert actual['export_sha256'] == old_component['export_sha256'], \
                    ('Unselected component raw export changed', actor_name, name)

    by_label = {actor['label']: (name, actor) for name, actor in after.items()}
    assert len(by_label) == len(after), 'Duplicate actor label in staged map'
    for entry in groups:
        label = entry['label']
        assert label in by_label
        actor_name, actor = by_label[label]
        assert actor_name == entry['actor_name']
        assert actor['type'] == '/Script/Engine.Actor' and actor['tags'] == [config['family']['owner_tag']]
        assert actor['pose'] == core._pose(sync.u.Transform()) and actor['hidden'] is False
        if 'folder' in actor:
            assert actor['folder'] == 'Warrens/Art/HallWallDiorama'
        expected_components = set(entry['native_components']) | {entry['component_name']}
        assert set(actor['components']) == expected_components, ('New actor component set differs from native baseline', label)
        for name, baseline in entry['native_components'].items():
            current = actor['components'][name]
            assert current['type'] == baseline['type'] and current['export_sha256'] == baseline['export_sha256'], \
                ('Native component changed after HISM creation', label, name)
        current_hisms = [c for c in actor['components'].values() if 'hism' in c]
        assert len(current_hisms) == 1
        actual = current_hisms[0]['hism']
        source_hism = copy.deepcopy(before[entry['source_actor_name']]['components'][source_component_names[entry['source_label']]]['hism'])
        source_indices = [item['index'] for item in entry['selected']]
        expected = copy.deepcopy(source_hism)
        expected['path'] = actual['path']
        expected['owner'] = actual['owner']
        expected['owner_label'] = label
        expected['level'] = actual['level']
        expected['materials'][0] = config['family']['materials'][str(entry['axis'])]
        expected['instances'] = [source_hism['instances'][index] for index in source_indices]
        assert _canonical_hism(actual) == _canonical_hism(expected), \
            ('New HISM differs from source contract except identity/material/selected instances', label)

    assert _hism_count(before) == config['family']['expected_total_hism_poses']
    assert _hism_count(after) == config['family']['expected_total_hism_poses']
    assert _hism_count_for_labels(before, config['family']['retained_ossuary_actor_labels']) == \
           _hism_count_for_labels(after, config['family']['retained_ossuary_actor_labels']) == \
           config['family']['retained_ossuary_instance_count'] == 1194
    assert _global_geometry(before) == _global_geometry(after), 'Global HISM mesh/pose multiset changed'


def offline_contract_selfcheck():
    """Pure Python regression check for actor-name/label separation and copied HISM flags."""
    class Transform:
        pass

    class U:
        pass

    U.Transform = Transform

    class Sync:
        u = U()

    class Core:
        @staticmethod
        def _pose(_):
            return dict(at=[0.0, 0.0, 0.0], q=[0.0, 0.0, 0.0, 1.0], scale=[1.0, 1.0, 1.0])

    config = dict(family=dict(expected_total_hism_poses=32646, retained_ossuary_instance_count=1194,
        retained_ossuary_actor_labels=['WVC_OssuaryWall_Painterly_CCS15', 'WVC_OssuaryWall_Painterly_BackTx01'],
        owner_tag='MarsWarrensCHallWallDioramaOwner', materials={'0': '/Hall/Axis0', '1': '/Hall/Axis1'}))
    identity = Core._pose(None)
    flags = dict(mesh='/Mesh/Wall', materials=['/Source/TX01', '/Source/TX02'], pose=identity,
        visible=True, hidden_in_game=False, cast_shadow=True, collision_profile='NoCollision',
        collision_enabled='NoCollision', collision_type='WorldStatic', body_instance='body',
        generate_overlap_events=False, custom_data_floats=2, random_seed=17, cull_start=0, cull_end=0)
    before, selected, groups = {}, {}, []
    next_actor_number = 27
    for ident, label, actor_name in (('CCS15', 'WVC_CCS15', 'WVC_CCS15'),
                                     ('BACKING_TX01', 'WVC_BACKING_TX01', 'WVC_BACKING_TX01')):
        instances = [dict(at=[float(i), float(ident == 'BACKING_TX01'), 0.0],
                          q=[0.0, 0.0, 0.0, 1.0], scale=[1.0, 1.0, 1.0]) for i in range(15726)]
        source = dict(path='/' + actor_name + '/HISM', owner='/' + actor_name, owner_label=label,
            level='/Diorama', instances=instances, **copy.deepcopy(flags))
        before[actor_name] = dict(label=label, type='/Script/Engine.Actor', tags=[], pose=identity,
            hidden=False, export_sha256='actor-before-' + ident,
            components={'HISM':dict(type='/Script/Engine.HierarchicalInstancedStaticMeshComponent',
                export_sha256='hism-before-' + ident, hism=source)})
        for axis, count in ((0, 31), (1, 41)):
            rows = []
            for index in range(sum(c for a, c in ((0, 31), (1, 41)) if a < axis),
                               sum(c for a, c in ((0, 31), (1, 41)) if a <= axis)):
                rows.append(dict(index=index, axis=axis))
            label_new = 'WVC_HallWallDiorama_' + ident + '_Axis' + str(axis)
            new_name = 'Actor_' + str(next_actor_number)
            next_actor_number += 1
            picked = [dict(index=row['index'], world_pose=copy.deepcopy(instances[row['index']])) for row in rows]
            groups.append(dict(label=label_new, ident=ident, axis=axis, actor_name=new_name,
                source_actor_name=actor_name, source_label=label, component_name='HISM_0',
                native_components={'DefaultSceneRoot':dict(type='/Script/Engine.SceneComponent',
                    export_sha256='native-root')}, selected=picked))
        selected[ident] = [dict(index=i, axis=0 if i < 31 else 1) for i in range(72)]
    for label in config['family']['retained_ossuary_actor_labels']:
        actor_name = label.replace('WVC_', '')
        hism = dict(path='/' + actor_name + '/HISM', owner='/' + actor_name, owner_label=label,
            level='/Diorama', instances=[dict(at=[float(i), 2.0, 0.0], q=[0.0, 0.0, 0.0, 1.0],
                scale=[1.0, 1.0, 1.0]) for i in range(597)], **copy.deepcopy(flags))
        before[actor_name] = dict(label=label, type='/Script/Engine.Actor', tags=[], pose=identity,
            hidden=False, export_sha256='actor-before-' + label,
            components={'HISM':dict(type='/Script/Engine.HierarchicalInstancedStaticMeshComponent',
                export_sha256='hism-before-' + label, hism=hism)})
    after = copy.deepcopy(before)
    for ident in ('CCS15', 'BACKING_TX01'):
        name = 'WVC_' + ident
        source_hism = after[name]['components']['HISM']['hism']
        for index in range(71, -1, -1):
            source_hism['instances'].pop(index)
    for group in groups:
        source_hism = before[group['source_actor_name']]['components']['HISM']['hism']
        hism = copy.deepcopy(source_hism)
        hism.update(path='/' + group['actor_name'] + '/HISM_0', owner='/' + group['actor_name'],
                    owner_label=group['label'], level='/Diorama',
                    materials=[config['family']['materials'][str(group['axis'])], '/Source/TX02'],
                    instances=[copy.deepcopy(source_hism['instances'][row['index']]) for row in group['selected']])
        after[group['actor_name']] = dict(label=group['label'], type='/Script/Engine.Actor',
            tags=[config['family']['owner_tag']], pose=identity, hidden=False, export_sha256='native-actor-new',
            components={'DefaultSceneRoot':dict(type='/Script/Engine.SceneComponent', export_sha256='native-root'),
                'HISM_0':dict(type='/Script/Engine.HierarchicalInstancedStaticMeshComponent',
                    export_sha256='new-hism-raw', hism=hism)})
    sources = {'CCS15':'WVC_CCS15', 'BACKING_TX01':'WVC_BACKING_TX01'}
    _verify_full_delta(Sync(), Core(), config, before, after, selected, groups, sources)
    assert all(group['actor_name'] != group['label'] for group in groups)
    altered = copy.deepcopy(after)
    altered[groups[0]['actor_name']]['components']['HISM_0']['hism']['cast_shadow'] = False
    try:
        _verify_full_delta(Sync(), Core(), config, before, altered, selected, groups, sources)
    except AssertionError:
        return dict(actor_name_label_separation='PASS', copied_component_flag_mutation_rejected='PASS')
    raise AssertionError('Offline selfcheck failed to reject a changed HISM flag')


def preflight(guard_file, guard_sha256, config_file=CONFIG_DEFAULT):
    """Read-only gate; creates a complete actor/component/model export baseline."""
    config = _config(config_file)
    sync, core, old, wall_material = _deps(config)
    guard = _guards(config, guard_file, guard_sha256)
    f = config['family']
    sync.context('Diorama')
    assert sync.ED.get_editor_world().get_path_name().split('.')[0] == f['map_package']
    assert sync.asset(sync.ED.get_editor_world()) == f['map_package']
    assert not sync.u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
    assert not sync.u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
    selection, fitted, axis = _selection(config, sync)
    world = sync.ED.get_editor_world()
    components, selected = _selected_indices(sync, core, config, world, fitted, axis)
    folder = ROOT / config['output_root'] / ('preflight_' + uuid.uuid4().hex[:12])
    folder.mkdir(parents=True, exist_ok=False)
    t3d = folder / 't3d'
    t3d.mkdir(parents=True, exist_ok=False)
    projection = _export_projection(old, _full(sync, core, old, wall_material, world, t3d))
    total = _hism_count(projection)
    assert total == f['expected_total_hism_poses'] == 32646
    ossuary_counts = _hism_counts_by_labels(projection, f['retained_ossuary_actor_labels'])
    assert ossuary_counts == {label:597 for label in f['retained_ossuary_actor_labels']}
    assert sum(ossuary_counts.values()) == f['retained_ossuary_instance_count'] == 1194
    labels = [row['label'] for row in projection.values()]
    assert len(labels) == len(set(labels)), 'Source map has duplicate actor labels'
    target_labels = {f['generated_label_prefix'] + ident + '_Axis' + str(ax)
                     for ident in f['source_ids'] for ax in (0, 1)}
    assert not target_labels.intersection(labels), ('Target labels already exist', target_labels.intersection(labels))
    source_labels = {ident: 'WVC_' + ident for ident in f['source_ids']}
    for label in source_labels.values():
        assert labels.count(label) == 1, ('Source actor label missing or ambiguous', label)
    required_map = f['map_file']
    assert guard['table'][required_map] == _sha(_rooted(required_map))
    geom_hash = hashlib.sha256(json.dumps(_global_geometry(projection), sort_keys=True,
        separators=(',', ':'), allow_nan=False).encode('utf-8')).hexdigest()
    out = _write(folder, 'preflight', dict(status='PREFLIGHT_REVIEW_REQUIRED',
        config_path=config['_path'].relative_to(ROOT).as_posix(), config_sha256=config['_sha'],
        guard_receipt=guard, map_package=f['map_package'], map_file=required_map,
        map_sha256=_sha(_rooted(required_map)), total_hism_poses=total,
        ossuary_wall_instance_count=f['retained_ossuary_instance_count'],
        selected_count=144, selected_source_indices={k: [x['index'] for x in v] for k, v in selected.items()},
        selected_source_poses={k: v for k, v in selected.items()},
        source_actor_labels=source_labels, full_actor_component_exports_projection=projection,
        global_mesh_pose_sha256=geom_hash, collision_hashes=guard['collision_hashes'],
        safety='Read-only. No save, autosave setting change, or Jolt setting change occurred.'))
    return dict(path=out.relative_to(ROOT).as_posix(), sha256=_sha(out), status='PREFLIGHT_REVIEW_REQUIRED')


def _load_receipt(file, digest, expected_status, root_dir):
    path = _rooted(file)
    assert path.is_relative_to(_rooted(root_dir)) and path.is_file() and _sha(path) == digest
    receipt = _read(path)
    assert receipt.get('status') == expected_status
    assert receipt['tool_sha256'] == _sha(TOOL)
    assert _sha(_rooted(receipt['config_path'])) == receipt['config_sha256']
    return path, receipt


def _new_group(sync, core, wall_material, config, world, source, rows, material, label, folder):
    u = sync.u
    _, _, exporter = wall_material._dependencies()
    actor = sync.EA.spawn_actor_from_class(u.Actor, u.Vector(), u.Rotator())
    assert actor and actor.get_world() == world and actor.get_level().get_outer() == world
    actor.set_actor_label(label)
    actor.tags = [u.Name(config['family']['owner_tag'])]
    actor.set_folder_path('Warrens/Art/HallWallDiorama')
    root = actor.root_component
    assert root
    root.set_mobility(source.get_editor_property('mobility'))
    native = {}
    for c in actor.get_components_by_class(u.ActorComponent):
        name = c.get_name()
        export = exporter._export(u, c, Path(folder) / (label + '__native_' + name + '.t3d'))
        native[name] = dict(type=c.get_class().get_path_name(), export_sha256=export['sha256'])
    assert root.get_name() in native and not actor.get_components_by_class(u.StaticMeshComponent)
    subsystem = u.get_engine_subsystem(u.SubobjectDataSubsystem)
    parent = subsystem.k2_gather_subobject_data_for_instance(actor)[0]
    handle, reason = subsystem.add_new_subobject(u.AddNewSubobjectParams(parent_handle=parent,
        new_class=u.HierarchicalInstancedStaticMeshComponent))
    component = u.SubobjectDataBlueprintFunctionLibrary.get_associated_object(
        u.SubobjectDataBlueprintFunctionLibrary.get_data(handle))
    assert isinstance(component, u.HierarchicalInstancedStaticMeshComponent), str(reason)
    component.set_mobility(source.get_editor_property('mobility'))
    assert component.set_static_mesh(source.static_mesh)
    component.set_world_transform(source.get_world_transform(), False, True)
    component.set_collision_profile_name(source.get_collision_profile_name())
    for field in ('generate_overlap_events', 'hidden_in_game', 'instancing_random_seed',
                  'instance_start_cull_distance', 'instance_end_cull_distance',
                  'num_custom_data_floats', 'body_instance'):
        component.set_editor_property(field, source.get_editor_property(field))
    component.set_cast_shadow(source.cast_shadow)
    for slot, existing in enumerate(source.get_materials()):
        component.set_material(slot, material if slot == 0 else existing)
    component.set_visibility(source.is_visible(), False)
    transforms = [source.get_instance_transform(x['index'], world_space=False) for x in rows]
    assert list(component.add_instances(transforms, True, False, False)) == list(range(len(rows)))
    assert component.get_instance_count() == len(rows)
    assert str(component.get_collision_profile_name()) == 'NoCollision'
    assert component.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
    return actor, component, actor.get_name(), native


def _partition(sync, core, wall_material, config, world, selected, materials, folder):
    u = sync.u
    components = _source_components(sync, world)
    groups = []
    for ident in config['family']['source_ids']:
        source_actor, component = components[ident]
        for ax in (0, 1):
            rows = [x for x in selected[ident] if x['axis'] == ax]
            assert len(rows) == config['family']['group_counts'][ident][str(ax)]
            label = 'WVC_HallWallDiorama_' + ident + '_Axis' + str(ax)
            made, new_component, actor_name, native = _new_group(sync, core, wall_material, config, world,
                component, rows, materials[ax], label, folder)
            groups.append(dict(label=label, ident=ident, axis=ax, actor_name=actor_name,
                source_actor_name=source_actor.get_name(), source_label=source_actor.get_actor_label(),
                component_name=new_component.get_name(), component=new_component,
                native_components=native, selected=rows, actor=made))
    for ident in config['family']['source_ids']:
        _, component = components[ident]
        component.modify()
        for idx in sorted((x['index'] for x in selected[ident]), reverse=True):
            assert component.remove_instance(idx)
    return groups


def apply(preflight_file, preflight_sha256, guard_file, guard_sha256, config_file=CONFIG_DEFAULT):
    """Stage exactly 144 source instances in memory without saving the map."""
    config = _config(config_file)
    sync, core, old, wall_material = _deps(config)
    prepath, pre = _load_receipt(preflight_file, preflight_sha256, 'PREFLIGHT_REVIEW_REQUIRED', config['output_root'])
    guard = _guards(config, guard_file, guard_sha256)
    f = config['family']
    sync.context('Diorama')
    assert _sha(_rooted(f['map_file'])) == pre['map_sha256'] == guard['table'][f['map_file']]
    assert pre['config_sha256'] == config['_sha'] and pre['guard_receipt']['sha256'] == guard_sha256
    assert guard['collision_hashes'] == pre['collision_hashes']
    _, fitted, axis = _selection(config, sync)
    world = sync.ED.get_editor_world()
    _, selected = _selected_indices(sync, core, config, world, fitted, axis)
    run = ROOT / config['output_root'] / ('stage_' + uuid.uuid4().hex[:16])
    run.mkdir(parents=True, exist_ok=False)
    before_folder = run / 'before_t3d'
    before_folder.mkdir(parents=True, exist_ok=False)
    before = _export_projection(old, _full(sync, core, old, wall_material, world, before_folder))
    assert before == pre['full_actor_component_exports_projection'], 'Full actor/component baseline changed after preflight'
    assert _hism_count(before) == f['expected_total_hism_poses']
    geom_hash = hashlib.sha256(json.dumps(_global_geometry(before), sort_keys=True,
        separators=(',', ':'), allow_nan=False).encode('utf-8')).hexdigest()
    assert geom_hash == pre['global_mesh_pose_sha256']
    backup = run / 'Diorama.before.umap'
    shutil.copy2(_rooted(f['map_file']), backup)
    before_hash = _sha(backup)
    editor, autosave, jolt, cook = _settings(sync.u)
    cook_name = _enum_name(cook)
    assert cook_name, 'Cannot record Jolt autocook enum for exact restoration'
    mutated = False
    groups = []
    try:
        editor.set_editor_property('bAutoSaveEnable', False)
        jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(cook).DISABLE)
        assert editor.get_editor_property('bAutoSaveEnable') is False
        assert jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave') == type(cook).DISABLE
        materials = {int(k): sync.u.load_asset(v) for k, v in f['materials'].items()}
        assert all(materials.values())
        for ax, path in f['materials'].items():
            assert sync.asset(materials[int(ax)]) == path
        mutated = True
        native_folder = run / 'native_t3d'
        native_folder.mkdir(parents=True, exist_ok=False)
        groups = _partition(sync, core, wall_material, config, world, selected, materials, native_folder)
        assert len(groups) == f['partition_count'] == 4
        after_folder = run / 'staged_t3d'
        after_folder.mkdir(parents=True, exist_ok=False)
        after = _export_projection(old, _full(sync, core, old, wall_material, world, after_folder))
        source_labels = {ident: 'WVC_' + ident for ident in f['source_ids']}
        _verify_full_delta(sync, core, config, before, after, selected, groups, source_labels)
        total = _hism_count(after)
        assert total == f['expected_total_hism_poses'] == 32646
        assert _guards(config, guard_file, guard_sha256)['required'] == guard['required']
        assert _guards(config, guard_file, guard_sha256)['collision_hashes'] == guard['collision_hashes']
        dirty_maps = [sync.asset(x) for x in sync.u.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
        dirty_content = [sync.asset(x) for x in sync.u.EditorLoadingAndSavingUtils.get_dirty_content_packages()]
        assert dirty_maps == [f['map_package']] and dirty_content == []
        assert _sha(_rooted(f['map_file'])) == before_hash, 'Staging unexpectedly saved the map'
        group_receipts = [{k: v for k, v in row.items() if k not in ('actor', 'component')} for row in groups]
        staged = _write(run, 'staged', dict(status='STAGED_UNSAVED',
            config_path=config['_path'].relative_to(ROOT).as_posix(), config_sha256=config['_sha'],
            preflight_file=prepath.relative_to(ROOT).as_posix(), preflight_sha256=preflight_sha256,
            guard_receipt=guard, map_package=f['map_package'], map_before=before_hash, map_saved=False,
            backup=backup.relative_to(ROOT).as_posix(), backup_sha256=_sha(backup),
            source_indices={k: [x['index'] for x in v] for k, v in selected.items()},
            groups=group_receipts, new_actor_names=[row['actor_name'] for row in groups],
            full_actor_component_exports_projection_before=before,
            full_actor_component_exports_projection_staged=after,
            global_mesh_pose_sha256=geom_hash, collision_hashes=guard['collision_hashes'],
            total_hism_poses=total, settings_before=dict(autosave=autosave, jolt_autocook=str(cook),
                jolt_autocook_enum_name=cook_name), settings_after=dict(autosave=False, jolt_autocook='DISABLE'),
            next='On a later callback call observe_staged(), then require exact raw stability in save_staged() on another callback.'))
        return dict(path=staged.relative_to(ROOT).as_posix(), sha256=_sha(staged), status='STAGED_UNSAVED')
    except Exception as exc:
        if mutated:
            _write(run, 'failure', dict(status='DIRTY_FAILURE_REQUIRES_MANUAL_RECOVERY',
                error_type=type(exc).__name__, error=str(exc), backup=backup.relative_to(ROOT).as_posix(),
                backup_sha256=_sha(backup), autosave_readback=bool(editor.get_editor_property('bAutoSaveEnable')),
                jolt_readback=str(jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')),
                instruction='Do not save. Manually restore backup, verify clean map and guards, then restore settings explicitly.'))
        else:
            editor.set_editor_property('bAutoSaveEnable', autosave)
            jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave', cook)
            assert editor.get_editor_property('bAutoSaveEnable') is autosave
            assert jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave') == cook
        raise


def _finite_lifecycle_delta(staged, observed, early_folder, late_folder):
    """Preserve raw files; admit only measured native cache fields on six owned HISMs."""
    allowed = {}
    source_fields = {'SortedInstances', 'InstanceReorderTable', 'NumBuiltInstances',
                     'InstanceCountToRender', 'CachedBounds'}
    early = staged['full_actor_component_exports_projection_staged']
    for group in staged['groups']:
        source_name = group['source_actor_name']
        source_hism, = [name for name, value in early[source_name]['components'].items() if 'hism' in value]
        for filename in (source_name + '.t3d', source_name + '__' + source_hism + '.t3d'):
            allowed[filename] = source_fields
        for filename in (group['actor_name'] + '.t3d',
                         group['actor_name'] + '__' + group['component_name'] + '.t3d'):
            allowed[filename] = {'CachedBounds'}
    for roster, folder in ((early, early_folder), (observed, late_folder)):
        for actor_name, actor in roster.items():
            assert _sha(folder / (actor_name + '.t3d')) == actor['export_sha256']
            for component_name, component in actor['components'].items():
                assert _sha(folder / (actor_name + '__' + component_name + '.t3d')) == component['export_sha256']
    names = {file.name for file in early_folder.glob('*.t3d')}
    assert names == {file.name for file in late_folder.glob('*.t3d')}
    differences = []
    for name in sorted(names):
        before, after = early_folder / name, late_folder / name
        if _sha(before) == _sha(after):
            continue
        assert name in allowed, ('Unrelated raw export changed during native lifecycle', name)
        a, b = before.read_bytes().splitlines(keepends=True), after.read_bytes().splitlines(keepends=True)
        families = Counter()
        for operation, a0, a1, b0, b1 in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
            if operation == 'equal':
                continue
            for line in a[a0:a1] + b[b0:b1]:
                match = re.match(rb'([A-Za-z_][A-Za-z_0-9]*)(?:\(\d+\))?=', line.lstrip(b' \t'))
                assert match and match.group(1).decode('ascii') in allowed[name], \
                    ('Raw change outside finite native field families', name, line[:160])
                families[match.group(1).decode('ascii')] += 1
        differences.append(dict(file=name, before_sha256=_sha(before), after_sha256=_sha(after),
            changed_line_families=dict(families), allowed_families=sorted(allowed[name])))
    return dict(raw_file_count=len(names), unchanged_raw_count=len(names)-len(differences), differences=differences,
        boundary='No raw file is rewritten or normalized. Only exact measured tree/bounds field families on the two modified source and four newly owned HISMs may change before the late baseline.')


def observe_staged(staged_file, staged_sha256, guard_file, guard_sha256, config_file=CONFIG_DEFAULT):
    """Observe native lifecycle on a later callback; save still requires another exact raw observation."""
    config = _config(config_file)
    sync, core, old, wall_material = _deps(config)
    path, staged = _load_receipt(staged_file, staged_sha256, 'STAGED_UNSAVED', config['output_root'])
    guard = _guards(config, guard_file, guard_sha256)
    f = config['family']
    assert sync.ED.get_game_world() is None and sync.asset(sync.ED.get_editor_world()) == f['map_package']
    assert [sync.asset(x) for x in sync.u.EditorLoadingAndSavingUtils.get_dirty_map_packages()] == [f['map_package']]
    assert not sync.u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
    assert _sha(_rooted(f['map_file'])) == staged['map_before']
    editor, _, jolt, cook = _settings(sync.u)
    assert editor.get_editor_property('bAutoSaveEnable') is False
    assert jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave') == type(cook).DISABLE
    folder = path.parent / 'observed_staged_t3d'
    folder.mkdir(parents=True, exist_ok=False)
    current = _export_projection(old, _full(sync, core, old, wall_material, sync.ED.get_editor_world(), folder))
    _, preflight = _load_receipt(staged['preflight_file'], staged['preflight_sha256'],
                                 'PREFLIGHT_REVIEW_REQUIRED', config['output_root'])
    _verify_full_delta(sync, core, config, staged['full_actor_component_exports_projection_before'],
        current, preflight['selected_source_poses'], staged['groups'], preflight['source_actor_labels'])
    lifecycle = _finite_lifecycle_delta(staged, current, path.parent/'staged_t3d', folder)
    assert _guards(config, guard_file, guard_sha256)['required'] == staged['guard_receipt']['required']
    observed = _write(path.parent, 'observed', dict(status='OBSERVED_STAGE_RAW_STABILITY_REQUIRED',
        config_path=config['_path'].relative_to(ROOT).as_posix(), config_sha256=config['_sha'],
        staged_file=path.relative_to(ROOT).as_posix(), staged_sha256=staged_sha256,
        guard_receipt=guard, map_before=staged['map_before'], lifecycle_delta=lifecycle,
        full_actor_component_exports_projection=current, map_saved=False,
        next='On another callback save_staged must match every observed raw export exactly before saving.'))
    return dict(path=observed.relative_to(ROOT).as_posix(), sha256=_sha(observed), status='OBSERVED_STAGE_RAW_STABILITY_REQUIRED')


def save_staged(observed_file, observed_sha256, guard_file, guard_sha256, config_file=CONFIG_DEFAULT):
    """Later-callback revalidation; only then save the current Diorama level."""
    config = _config(config_file)
    sync, core, old, wall_material = _deps(config)
    observed_path, observed = _load_receipt(observed_file, observed_sha256,
        'OBSERVED_STAGE_RAW_STABILITY_REQUIRED', config['output_root'])
    staged_file, staged_sha256 = observed['staged_file'], observed['staged_sha256']
    path, staged = _load_receipt(staged_file, staged_sha256, 'STAGED_UNSAVED', config['output_root'])
    f = config['family']
    guard = _guards(config, guard_file, guard_sha256)
    assert staged['map_saved'] is False and staged['guard_receipt']['sha256'] == guard_sha256
    assert sync.ED.get_game_world() is None
    assert sync.ED.get_editor_world().get_path_name().split('.')[0] == f['map_package']
    assert _sha(_rooted(f['map_file'])) == staged['map_before'] == guard['table'][f['map_file']]
    assert guard['collision_hashes'] == staged['collision_hashes']
    dirty_maps = [sync.asset(x) for x in sync.u.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
    dirty_content = [sync.asset(x) for x in sync.u.EditorLoadingAndSavingUtils.get_dirty_content_packages()]
    assert dirty_maps == [f['map_package']] and dirty_content == []
    folder = path.parent / 'save_revalidation_t3d'
    folder.mkdir(parents=True, exist_ok=False)
    current = _export_projection(old, _full(sync, core, old, wall_material, sync.ED.get_editor_world(), folder))
    assert current == observed['full_actor_component_exports_projection'], 'Observed stage raw roster changed before save callback'
    assert _hism_count(current) == f['expected_total_hism_poses']
    geom_hash = hashlib.sha256(json.dumps(_global_geometry(current), sort_keys=True,
        separators=(',', ':'), allow_nan=False).encode('utf-8')).hexdigest()
    assert geom_hash == staged['global_mesh_pose_sha256']
    assert _guards(config, guard_file, guard_sha256)['required'] == staged['guard_receipt']['required']
    assert _guards(config, guard_file, guard_sha256)['collision_hashes'] == staged['collision_hashes']
    editor_settings, _, jolt_settings, current_cook = _settings(sync.u)
    assert editor_settings.get_editor_property('bAutoSaveEnable') is False
    assert jolt_settings.get_editor_property('_AutoCookStaticWorldOnLevelSave') == type(current_cook).DISABLE
    subsystem = sync.u.get_editor_subsystem(sync.u.LevelEditorSubsystem)
    assert subsystem and subsystem.save_current_level(), 'LevelEditorSubsystem.save_current_level failed'
    map_after = _sha(_rooted(f['map_file']))
    assert map_after != staged['map_before']
    assert not sync.u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
    assert not sync.u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
    guard_after = _guards(config, guard_file, guard_sha256, check_map=False)
    assert guard_after['collision_hashes'] == staged['collision_hashes']
    post_folder = path.parent / 'post_save_t3d'
    post_folder.mkdir(parents=True, exist_ok=False)
    post = _export_projection(old, _full(sync, core, old, wall_material, sync.ED.get_editor_world(), post_folder))
    source_labels = {ident: 'WVC_' + ident for ident in f['source_ids']}
    _, preflight = _load_receipt(staged['preflight_file'], staged['preflight_sha256'],
                                 'PREFLIGHT_REVIEW_REQUIRED', config['output_root'])
    _verify_full_delta(sync, core, config, staged['full_actor_component_exports_projection_before'],
                       post, preflight['selected_source_poses'], staged['groups'], source_labels)
    saved = _write(path.parent, 'saved', dict(status='SAVED_RELOAD_AUDIT_REQUIRED',
        config_path=config['_path'].relative_to(ROOT).as_posix(), config_sha256=config['_sha'],
        staged_file=path.relative_to(ROOT).as_posix(), staged_sha256=staged_sha256,
        observed_file=observed_path.relative_to(ROOT).as_posix(), observed_sha256=observed_sha256,
        map_package=f['map_package'], map_before=staged['map_before'], map_after=map_after,
        backup=staged['backup'], backup_sha256=staged['backup_sha256'],
        groups=staged['groups'], new_actor_names=staged['new_actor_names'],
        settings_before=staged['settings_before'],
        guard_receipt=guard_after, collision_hashes=guard_after['collision_hashes'],
        full_actor_component_exports_projection=post,
        total_hism_poses=staged['total_hism_poses'], map_saved_via='LevelEditorSubsystem.save_current_level',
        next='Unload the Diorama, call note_unloaded(), reload it, then call audit(first_reopen=True).'))
    return dict(path=saved.relative_to(ROOT).as_posix(), sha256=_sha(saved), status='SAVED_RELOAD_AUDIT_REQUIRED')

def note_unloaded(saved_file, saved_sha256, guard_file, guard_sha256, config_file=CONFIG_DEFAULT):
    config = _config(config_file)
    sync, _, _, _ = _deps(config)
    path, saved = _load_receipt(saved_file, saved_sha256, 'SAVED_RELOAD_AUDIT_REQUIRED', config['output_root'])
    guard = _guards(config, guard_file, guard_sha256, check_map=False)
    assert sync.ED.get_editor_world().get_path_name().split('.')[0] != config['family']['map_package']
    assert sync.u.find_object(None, config['family']['map_package']) is None
    assert _sha(_rooted(config['family']['map_file'])) == saved['map_after']
    assert _guards(config, guard_file, guard_sha256, check_map=False)['required'] == guard['required']
    transition = 1 + len(list(path.parent.glob('unloaded_*.json')))
    assert transition in (1, 2)
    if transition == 2:
        assert sorted(path.parent.glob('audit_first_*.json')), 'Second unload requires first reopen audit'
    out = _write(path.parent, 'unloaded', dict(status='UNLOADED_OBSERVED', saved_file=path.relative_to(ROOT).as_posix(),
        config_path=config['_path'].relative_to(ROOT).as_posix(), config_sha256=config['_sha'],
        saved_sha256=saved_sha256, map_after=saved['map_after'], guard_receipt=guard,
        target_world_absent=True, transition=transition))
    return dict(path=out.relative_to(ROOT).as_posix(), sha256=_sha(out), status='UNLOADED_OBSERVED')


def audit(saved_file, saved_sha256, unloaded_file, unloaded_sha256,
          guard_file, guard_sha256, first_reopen, config_file=CONFIG_DEFAULT):
    """Audit one explicit unload/reopen; actor raw ordering is tolerated only on first transition."""
    config = _config(config_file)
    sync, core, old, wall_material = _deps(config)
    path, saved = _load_receipt(saved_file, saved_sha256, 'SAVED_RELOAD_AUDIT_REQUIRED', config['output_root'])
    _, unloaded = _load_receipt(unloaded_file, unloaded_sha256, 'UNLOADED_OBSERVED', config['output_root'])
    assert unloaded['saved_sha256'] == saved_sha256 and unloaded['target_world_absent']
    assert unloaded['transition'] == (1 if first_reopen else 2), 'Reopen audit does not match unload sequence'
    if first_reopen:
        assert not sorted(path.parent.glob('audit_first_*.json')), 'First reopen already recorded'
    else:
        assert sorted(path.parent.glob('audit_first_*.json')), 'Second reopen requires first audit'
    guard = _guards(config, guard_file, guard_sha256, check_map=False)
    f = config['family']
    sync.context('Diorama')
    assert _sha(_rooted(f['map_file'])) == saved['map_after']
    assert guard['collision_hashes'] == saved['collision_hashes']
    assert _guards(config, guard_file, guard_sha256, check_map=False)['required'] == guard['required']
    world = sync.ED.get_editor_world()
    folder = path.parent / ('audit_' + ('first' if first_reopen else 'second') + '_t3d')
    folder.mkdir(parents=True, exist_ok=False)
    projection = _export_projection(old, _full(sync, core, old, wall_material, world, folder))
    expected = saved['full_actor_component_exports_projection']
    if not first_reopen:
        first_path = sorted(path.parent.glob('audit_first_*.json'))[-1]
        first = _read(first_path)
        assert first.get('status') == 'FIRST_REOPEN_AUDITED'
        expected = first['full_actor_component_exports_projection']
    labels = {group['label'] for group in saved['groups']}
    assert set(projection) == set(expected)
    for actor_name, row in expected.items():
        actual = projection[actor_name]
        if first_reopen and actual['label'] in labels:
            assert actual['components'] == row['components'], ('New actor native/HISM component raw contract mismatch', row['label'])
            for field in ('label', 'type', 'tags', 'pose', 'hidden', 'folder'):
                assert actual[field] == row[field], ('New actor metadata changed', row['label'], field)
            before_raw = path.parent / 'post_save_t3d' / (actor_name + '.t3d')
            after_raw = folder / (actor_name + '.t3d')
            assert _sha(before_raw) == row['export_sha256']
            assert _sha(after_raw) == actual['export_sha256']
            # Restrict the first-transition exception to unchanged raw byte-line
            # content in these four actors. Component exports remain byte exact;
            # neither export is rewritten or globally normalized.
            assert Counter(before_raw.read_bytes().splitlines(keepends=True)) == \
                   Counter(after_raw.read_bytes().splitlines(keepends=True)), \
                   ('New actor raw line content changed on first reopen', row['label'])
        else:
            assert actual == row, ('Actor/component/model raw export mismatch', actor_name)
    if not first_reopen:
        assert projection == expected, 'Second reopen must match canonical first-reopen exports'
    total = _hism_count(projection)
    assert total == f['expected_total_hism_poses'] == 32646
    restored_settings = None
    if not first_reopen:
        editor, _, jolt, current_cook = _settings(sync.u)
        prior = saved['settings_before']
        desired = prior['jolt_autocook_enum_name']
        enum_type = type(current_cook)
        assert desired and hasattr(enum_type, desired), ('Cannot restore recorded Jolt setting', desired)
        target_cook = getattr(enum_type, desired)
        editor.set_editor_property('bAutoSaveEnable', prior['autosave'])
        jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave', target_cook)
        assert editor.get_editor_property('bAutoSaveEnable') is prior['autosave']
        assert jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave') == target_cook
        restored_settings = dict(autosave=prior['autosave'], jolt_autocook=desired)
    status = 'FIRST_REOPEN_AUDITED' if first_reopen else 'RELOAD_AUDITED'
    out = _write(path.parent, 'audit_first' if first_reopen else 'audit_second', dict(status=status,
        config_path=config['_path'].relative_to(ROOT).as_posix(), config_sha256=config['_sha'],
        saved_file=path.relative_to(ROOT).as_posix(), saved_sha256=saved_sha256,
        unloaded_file=_rooted(unloaded_file).relative_to(ROOT).as_posix(), unloaded_sha256=unloaded_sha256,
        guard_receipt=guard, collision_hashes=guard['collision_hashes'], map_sha256=_sha(_rooted(f['map_file'])),
        total_hism_poses=total, full_actor_component_exports_projection=projection,
        first_reopen_actor_raw_order_exception=sorted(labels) if first_reopen else [],
        first_reopen_raw_byte_line_content_verified=bool(first_reopen),
        restored_settings=restored_settings,
        boundary='Source Diorama map persistence only; runtime visual/gameplay acceptance remains separate.'))
    return dict(path=out.relative_to(ROOT).as_posix(), sha256=_sha(out), status=status)

