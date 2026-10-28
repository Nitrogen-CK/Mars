"""Finite, receipt-bound persistent adoption for cardinal static-wall families.

This configured instance targets only the reviewed Hall rows in original Hub.
Import is inert. preflight() is read-only; apply() requires the exact approved
review receipt. The helper checkpoints and saves only the open source Level
Instance and requires two reload observations before declaring serialization
stable. It does not touch Main, PIE, or other Level Instances.
"""
from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import shutil
import sys
import types
import uuid
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
CONFIG = ROOT / 'Saved/WarrensCGameplay-20261024/HallWallAdoption/config.json'
CONFIG_SHA256 = 'a166618113696af9fcd51bbdcdad9ebc110d27ae4cdbd53d31f4ba21bd600be4'
RUN = ROOT / 'Saved/WarrensCGameplay-20261024/HallWallAdoption'
FIT = ROOT / 'Tools/WarrensVariantCKit/Output/fitted_instances.json'
CORE_FILE = HERE / 'bank_identity_unreal.py'
CORE_SHA256 = '4859e7ab71dc9e0a5d93b61511eb759ef741598af4821ba62df69cd8ee014619'
BASE_FILE = HERE / 'hall_wall_trial.py'
BASE_SHA256 = '7cedf430c2aa09f6848d09d5e4e0b95f2b9fd6ffdb266b548ea9b21f5b38219c'
STATE_MODULE = '_mars_wvc_cardinal_wall_persistent_state'


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def _write(kind, payload):
    folder = RUN / 'receipts'
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / f'{kind}_{datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S_%fZ")}_{uuid.uuid4().hex[:8]}.json'
    assert not path.exists()
    value = dict(payload, schema=1, created_utc=datetime.now(timezone.utc).isoformat(),
                 tool_sha256=_sha(__file__), config_sha256=_sha(CONFIG))
    path.write_text(json.dumps(value, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    return dict(file=path.relative_to(ROOT).as_posix(), sha256=_sha(path), phase=value.get('phase'), status=value.get('status'))


def _state():
    if STATE_MODULE not in sys.modules:
        sys.modules[STATE_MODULE] = types.ModuleType(STATE_MODULE)
        sys.modules[STATE_MODULE].data = None
    return sys.modules[STATE_MODULE]


def _core():
    assert _sha(CORE_FILE) == CORE_SHA256, 'Pinned generic HISM/transform helper changed'
    name = '_mars_wvc_cardinal_wall_core'
    if name not in sys.modules:
        spec = importlib.util.spec_from_file_location(name, CORE_FILE)
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules[name] = module
    return sys.modules[name]


def _contract():
    assert _sha(CONFIG) == CONFIG_SHA256, 'Hall adoption config changed; review again'
    c = _json(CONFIG)
    assert c['schema'] == 1 and c['source_tile'] == 'Hub'
    assert _sha(ROOT / c['fit_ledger']) == c['fit_ledger_sha256']
    assert _sha(ROOT / c['review']['path']) == c['review']['sha256']
    assert _sha(ROOT / c['selection']['path']) == c['selection']['sha256']
    assert _sha(ROOT / c['asset_receipt']['path']) == c['asset_receipt']['sha256']
    assert _sha(ROOT / c['guard_receipt']['path']) == c['guard_receipt']['sha256']
    protected = c['additional_protected_assets']
    receipt_path = ROOT / protected['receipt']['path']
    assert _sha(receipt_path) == protected['receipt']['sha256']
    receipt = _json(receipt_path)
    assert receipt['status'] == protected['receipt']['status']
    observed = {row['path']: row['package_sha256'] for row in receipt['owned_assets']}
    expected = {row['path']: row['sha256'] for row in protected['assets']}
    assert observed == expected and len(expected) == 3
    for row in protected['assets']:
        package = ROOT / ('Content/' + row['path'].removeprefix('/Game/') + '.uasset')
        assert package.is_file() and _sha(package) == row['sha256'], ('additional protected asset changed', row['path'])
    return c


def _u():
    import unreal
    return unreal


def _package(obj):
    return obj.get_path_name().split('.')[0] if obj else None


def _dirty(u):
    return dict(maps=sorted(_package(x) for x in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()),
                content=sorted(_package(x) for x in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()))


def _guard_data(c):
    p = ROOT / c['guard_receipt']['path']
    data = _json(p)
    assert data['status'] == c['guard_receipt']['status'] == 'RELOAD_AUDITED'
    guards = data['immutable_guards']
    assert len(guards) == c['guard_receipt']['guard_count'] == 634
    for relative, digest in guards.items():
        path = (ROOT / relative).resolve()
        assert path.is_relative_to(ROOT.resolve()) and path.is_file() and _sha(path) == digest, ('guard drift', relative)
    collision_path = ROOT / 'Saved/WarrensCGameplay-20261024/StartupCheckpoint/collision_hashes.json'
    assert collision_path.relative_to(ROOT).as_posix() in guards
    collision = _json(collision_path)
    assert len(collision) == 54
    assert all(_sha(ROOT / p) == d for p, d in collision.items())
    map_rel = c['map_file']
    assert guards.get(map_rel) == c['map_sha256_before']
    return guards, collision


def _collision_check():
    path = ROOT / 'Saved/WarrensCGameplay-20261024/StartupCheckpoint/collision_hashes.json'
    collision = _json(path)
    assert isinstance(collision, dict) and len(collision) == 54
    assert all(_sha(ROOT / p) == d for p, d in collision.items())
    return collision


def _asset_rows(c):
    receipt = _json(ROOT / c['asset_receipt']['path'])
    assert receipt['status'] == c['asset_receipt']['status'] == 'FOUR_OWNED_HALL_MATERIAL_ASSETS_CREATED'
    owned = receipt['owned_assets']
    assert len(owned) == 4 and len({row['path'] for row in owned}) == 4
    by_path = {row['path']: row for row in owned}
    targets = {int(axis): spec for axis, spec in c['candidate_materials'].items()}
    for axis, spec in targets.items():
        assert by_path[spec['path']]['package_sha256'] == spec['sha256']
        tangent = next(row for row in receipt['tangent_instances'] if row['path'] == spec['path'])
        expected_tangent = (0.0, -1.0, 0.0) if axis == 0 else (1.0, 0.0, 0.0)
        assert tuple(tangent['tangent']) == expected_tangent
    for row in owned:
        path = ROOT / ('Content/' + row['path'].removeprefix('/Game/') + '.uasset')
        assert path.is_file() and _sha(path) == row['package_sha256'], ('candidate asset drift', row['path'])
    return receipt, owned, targets


def _selection(c):
    selection = _json(ROOT / c['selection']['path'])
    assert selection['selected_wall_instances'] == c['selection']['selected_count'] == 144
    keys = selection['selected_source_keys']
    assert len(keys) == 144 and len(set(keys)) == 144
    fit = _json(ROOT / c['fit_ledger'])
    assert tuple(float(v) for v in fit['pivots']['Hub']) == tuple(c['pivot'])
    placements = fit['placements']
    rows = {int(key): placements[int(key)] for key in keys}
    for key, row in rows.items():
        assert row['tile'] == c['source_tile']
        assert row['id'] in ('CCS15', 'BACKING_TX01')
        pair_key = key + 1 if row['id'] == 'CCS15' else key - 1
        assert pair_key in rows, ('unpaired selected veneer/backing row', key)
        pair = rows[pair_key]
        assert pair['id'] == ('BACKING_TX01' if row['id'] == 'CCS15' else 'CCS15')
        veneer = row if row['id'] == 'CCS15' else pair
        assert veneer['role'] == 'source exposed wall veneer'
        assert row['role'] == ('source exposed wall veneer' if row['id'] == 'CCS15' else 'source wall seam backing')
    counts = Counter((row['id'], _axis(rows, key)) for key, row in rows.items())
    assert counts == Counter({('CCS15', 0): 31, ('CCS15', 1): 41,
                              ('BACKING_TX01', 0): 31, ('BACKING_TX01', 1): 41}), counts
    return fit, rows, counts


def _axis(rows, key):
    row = rows[key]
    veneer = row if row['id'] == 'CCS15' else rows[key - 1]
    assert veneer['id'] == 'CCS15'
    return 0 if veneer['yaw'] in (90, -90) else 1 if veneer['yaw'] in (0, 180) else None


def _editor(u):
    subsystem = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    world = subsystem.get_editor_world()
    assert subsystem.get_game_world() is None, 'Stop PIE before source-map operation'
    assert world and _package(world) == _contract()['map_package']
    assert world.get_path_name() == _contract()['map_package'] + '.LI_Warrens_Hub'
    dirty = _dirty(u)
    assert dirty == dict(maps=[], content=[]), ('Editor must be clean before source-LI operation', dirty)
    return world


def _source_world(u, allowed_dirty_maps):
    subsystem = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    world = subsystem.get_editor_world()
    c = _contract()
    assert subsystem.get_game_world() is None
    assert world and _package(world) == c['map_package']
    assert world.get_path_name() == c['map_package'] + '.LI_Warrens_Hub'
    dirty = _dirty(u)
    assert set(dirty['maps']).issubset(set(allowed_dirty_maps)) and dirty['content'] == [], dirty
    return world, dirty


def _export(u, obj, path):
    assert not path.exists()
    path.parent.mkdir(parents=True, exist_ok=True)
    task = u.AssetExportTask()
    fields = dict(object=obj, exporter=u.ObjectExporterT3D(), filename=str(path), automated=True,
        prompt=False, selected=False, replace_identical=False, use_file_archive=False, write_empty_files=False)
    for key, value in fields.items():
        task.set_editor_property(key, value)
    assert u.Exporter.run_asset_export_task(task) and not list(task.get_editor_property('errors'))
    assert path.is_file() and path.stat().st_size > 0
    return dict(file=path.relative_to(ROOT).as_posix(), sha256=_sha(path))


def _roster(u, core, world, folder):
    actors = list(u.GameplayStatics.get_all_actors_of_class(world, u.Actor))
    result, hisms = {}, {}
    for actor in actors:
        assert actor.get_world() == world and actor.get_level().get_outer() == world
        name = actor.get_name()
        assert name not in result
        components = {}
        for component in actor.get_components_by_class(u.ActorComponent):
            cname = component.get_name()
            assert cname not in components, (name, cname)
            entry = dict(type=component.get_class().get_path_name(),
                         raw=_export(u, component, folder / f'{name}__{cname}.t3d'))
            if isinstance(component, u.HierarchicalInstancedStaticMeshComponent):
                entry['hism'] = core._component(component)
                hisms[component.get_path_name()] = entry['hism']
            components[cname] = entry
        result[name] = dict(label=actor.get_actor_label(), type=actor.get_class().get_path_name(),
            tags=sorted(str(tag) for tag in actor.tags), pose=core._pose(actor.get_actor_transform()),
            hidden=bool(actor.hidden), folder=str(actor.get_folder_path()),
            raw=_export(u, actor, folder / f'{name}.t3d'), components=components)
    return result, hisms


def _global_geometry(hisms):
    result = []
    for row in hisms.values():
        for pose in row['instances']:
            result.append(dict(mesh=row['mesh'], pose=pose))
    return sorted(result, key=lambda row: json.dumps(row, sort_keys=True, separators=(',', ':')))


def _semantic(core, hisms):
    return sorted((_canonical_component(row) for row in hisms.values()),
                  key=lambda row: json.dumps(row, sort_keys=True, separators=(',', ':')))


def _canonical_component(row):
    value = copy.deepcopy(row)
    for field in ('path', 'owner', 'level'):
        value.pop(field, None)
    value['instances'] = sorted(value['instances'],
        key=lambda pose: json.dumps(pose, sort_keys=True, separators=(',', ':')))
    return value


def _source_components(u, core, world, c):
    actors = list(u.GameplayStatics.get_all_actors_of_class(world, u.Actor))
    found = {}
    for ident, label in c['source_actors'].items():
        matches = [actor for actor in actors if actor.get_actor_label() == label]
        assert len(matches) == 1, ('source actor missing/ambiguous', ident, len(matches))
        actor = matches[0]
        components = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        assert len(components) == 1, ('source HISM missing/ambiguous', ident)
        component, = components
        row = core._component(component)
        assert row['collision_profile'] == 'NoCollision'
        assert component.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
        found[ident] = dict(actor=actor, component=component, snapshot=row)
    return found


def _match(u, core, c, fit, rows, sources):
    hub_transform = sources['CCS15']['actor'].get_level_transform()
    matched = []
    for key, row in rows.items():
        ident = row['id']
        component = sources[ident]['component']
        wanted = core._row_transform(u, row, c['pivot'], hub_transform)
        indices = [i for i in range(component.get_instance_count())
                   if core._near(component.get_instance_transform(i, world_space=True), wanted)]
        assert len(indices) == 1, ('source selection match missing/ambiguous', key, ident, indices)
        veneer = row if ident == 'CCS15' else rows[key - 1]
        matched.append(dict(source_key=key, ident=ident, axis=0 if veneer['yaw'] in (90, -90) else 1,
            index=indices[0], world_pose=core._pose(component.get_instance_transform(indices[0], world_space=True)),
            local_pose=core._pose(component.get_instance_transform(indices[0], world_space=False))))
    assert len({(item['ident'], item['index']) for item in matched}) == len(matched)
    assert len({item['source_key'] for item in matched}) == len(rows)
    return matched


def _guards_except_map(c, expected, current_map_sha=None):
    map_file = c['map_file']
    for relative, digest in expected.items():
        path = ROOT / relative
        actual = current_map_sha if relative == map_file and current_map_sha is not None else _sha(path)
        assert actual == digest, ('protected file changed', relative)
    return True


def preflight():
    """Read-only source-map and selected-row admission; writes evidence only."""
    c = _contract()
    u, core = _u(), _core()
    world = _editor(u)
    assert _sha(ROOT / c['map_file']) == c['map_sha256_before']
    guards, collision = _guard_data(c)
    assets, owned, targets = _asset_rows(c)
    fit, rows, counts = _selection(c)
    sources = _source_components(u, core, world, c)
    matched = _match(u, core, c, fit, rows, sources)
    token = uuid.uuid4().hex
    folder = RUN / 'preflight' / token
    roster, hisms = _roster(u, core, world, folder / 'roster')
    assert len([row for row in hisms.values()]) == len(hisms)
    assert all(source['snapshot']['path'] in hisms for source in sources.values())
    report = dict(phase='preflight', status='SOURCE_MAP_REVIEW_REQUIRED', token=token,
        map_package=c['map_package'], map_object=world.get_path_name(), map_file=c['map_file'],
        map_sha256=c['map_sha256_before'], source_tile=c['source_tile'], pivot=c['pivot'],
        config_sha256=_sha(CONFIG), review=dict(path=c['review']['path'], sha256=c['review']['sha256']),
        selection=dict(path=c['selection']['path'], sha256=c['selection']['sha256'],
            selected_count=len(matched), keys=sorted(row['source_key'] for row in matched),
            axis_counts={f'{ident}:{axis}': sum(x['ident'] == ident and x['axis'] == axis for x in matched)
                         for ident in c['source_actors'] for axis in (0, 1)}),
        asset_receipt=dict(path=c['asset_receipt']['path'], sha256=c['asset_receipt']['sha256'],
            status=assets['status'], owned_assets=owned,
            target_materials={str(axis): dict(path=spec['path'], sha256=spec['sha256']) for axis, spec in targets.items()}),
        guard_receipt=dict(path=c['guard_receipt']['path'], sha256=c['guard_receipt']['sha256'], count=len(guards)),
        immutable_guards=guards, collision_hashes=collision, fit_sha256=_sha(FIT),
        selected_live_instances=matched, source_components={ident: source['snapshot'] for ident, source in sources.items()},
        hism_count=len(hisms), global_instance_count=len(_global_geometry(hisms)),
        global_geometry_sha256=_digest(_global_geometry(hisms)), semantic_hism_sha256=_digest(_semantic(core, hisms)),
        actor_component_roster=roster, hism_snapshot=hisms, dirty=dict(maps=[], content=[]),
        boundary='Read-only source LI inventory. No actor, component, map, asset or settings mutation.')
    return _write('preflight', report)


def _load_preflight(path, digest):
    file = Path(path)
    if not file.is_absolute():
        file = ROOT / file
    file = file.resolve()
    assert file.is_relative_to((RUN / 'receipts').resolve()) and file.is_file() and _sha(file) == digest
    data = _json(file)
    assert data['phase'] == 'preflight' and data['status'] == 'SOURCE_MAP_REVIEW_REQUIRED'
    assert data['tool_sha256'] == _sha(__file__) and data['config_sha256'] == _sha(CONFIG)
    assert data['map_sha256'] == _sha(ROOT / data['map_file'])
    _guards, _collision = _guard_data(_contract())
    _asset_rows(_contract())
    return file, data


def _exporter_roster_matches(old, new, changed_target_labels, new_actor_name):
    assert set(new) == set(old) | {new_actor_name}, ('source actor roster changed', len(old), len(new))
    for name, before in old.items():
        after = new[name]
        assert {k: v for k, v in before.items() if k in ('label', 'type', 'tags', 'pose', 'hidden')} == \
               {k: v for k, v in after.items() if k in ('label', 'type', 'tags', 'pose', 'hidden')}, name
        assert set(before['components']) == set(after['components']), ('existing actor component roster changed', name)
        changed_actor = before['label'] in changed_target_labels
        if not changed_actor:
            assert before['raw']['sha256'] == after['raw']['sha256'], ('unrelated actor export changed', name)
        for cname, old_component in before['components'].items():
            current = after['components'][cname]
            assert old_component['type'] == current['type']
            is_target_hism = changed_actor and 'hism' in old_component
            if not is_target_hism:
                assert old_component['raw']['sha256'] == current['raw']['sha256'], \
                    ('unrelated component export changed', name, cname)
    added = new[new_actor_name]
    assert added['label'] in {f'WVC_HallWall_{ident}_Normal{axis}' for ident in ('CCS15', 'BACKING_TX01')
                              for axis in ('X', 'Y')}
    assert added['type'] == '/Script/Engine.Actor' and added['hidden'] is False
    assert len(added['components']) >= 3


def _new_group(u, world, source, indices, material, label, owner, folder, folder_out):
    actor = u.get_editor_subsystem(u.EditorActorSubsystem).spawn_actor_from_class(u.Actor, u.Vector(), u.Rotator())
    assert actor and actor.get_world() == world and actor.get_level().get_outer() == world
    actor.set_actor_label(label)
    actor.tags = [u.Name(owner)]
    actor.set_folder_path(folder)
    assert actor.root_component
    actor.root_component.set_mobility(source.get_editor_property('mobility'))
    native = {component.get_name(): dict(type=component.get_class().get_path_name(),
        raw=_export(u, component, folder_out / ('native_' + component.get_name() + '.t3d')))
        for component in actor.get_components_by_class(u.ActorComponent)}
    assert actor.root_component.get_name() in native
    subsystem = u.get_engine_subsystem(u.SubobjectDataSubsystem)
    root_handle = subsystem.k2_gather_subobject_data_for_instance(actor)[0]
    handle, reason = subsystem.add_new_subobject(u.AddNewSubobjectParams(
        parent_handle=root_handle, new_class=u.HierarchicalInstancedStaticMeshComponent))
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
    added = component.add_instances(local, True, False, False)
    assert len(added) == len(local) and list(added) == list(range(len(local)))
    return actor, component, native


def _verify_hisms(core, before, after, matches, created, targets, labels, source_labels):
    assert len(after) == len(before) + 4
    selected_by_ident = {ident: [item for item in matches if item['ident'] == ident]
                         for ident in ('CCS15', 'BACKING_TX01')}
    expected = copy.deepcopy(before)
    for ident, items in selected_by_ident.items():
        entries = [(path, row) for path, row in expected.items() if row['owner_label'] == source_labels[ident]]
        assert len(entries) == 1
        _, row = entries[0]
        remaining = list(row['instances'])
        indices = [item['index'] for item in items]
        assert len(indices) == len(set(indices))
        for index in sorted(indices, reverse=True):
            remaining.pop(index)
        row['instances'] = remaining
    actual_new = [row for row in after.values() if row['owner_label'] in set(labels.values())]
    assert len(actual_new) == 4
    assert {row['owner_label'] for row in actual_new} == set(labels.values())
    created_by_label = {entry['label']: entry for entry in created}
    for row in actual_new:
        entry = created_by_label[row['owner_label']]
        source = before[entry['source_path']]
        expected_row = copy.deepcopy(source)
        expected_row['owner_label'] = entry['label']
        expected_row['materials'][0] = targets[entry['axis']]['path']
        expected_row['instances'] = sorted([item['world_pose'] for item in entry['selected']],
            key=lambda pose: json.dumps(pose, sort_keys=True, separators=(',', ':')))
        got = _canonical_component(row)
        want = _canonical_component(expected_row)
        assert got == want, ('new partition differs from source component contract', entry['label'])
        expected[row['path']] = row
    assert _digest(_semantic(core, after)) == _digest(_semantic(core, expected)), 'Full HISM roster changed beyond exact partition'
    return expected


def _map_save(u):
    subsystem = u.get_editor_subsystem(u.LevelEditorSubsystem)
    assert subsystem.save_current_level(), 'Saving the open source LI failed'


def _preflight_receipt(path, digest):
    file = Path(path)
    if not file.is_absolute():
        file = ROOT / file
    file = file.resolve()
    assert file.is_relative_to((RUN / 'receipts').resolve()) and file.is_file() and _sha(file) == digest
    data = _json(file)
    assert data['phase'] == 'preflight' and data['status'] == 'SOURCE_MAP_REVIEW_REQUIRED'
    assert data['tool_sha256'] == _sha(__file__) and data['config_sha256'] == _sha(CONFIG)
    return file, data


def apply(preflight_path, preflight_sha256, review_path, review_sha256):
    """Mutate and checkpoint only Hub; a later save_staged() performs its save."""
    state = _state()
    assert state.data is None, 'A persistent Hall adoption is already active'
    c = _contract()
    assert Path(review_path).resolve() == (ROOT / c['review']['path']).resolve()
    assert review_sha256 == c['review']['sha256'] and _sha(review_path) == review_sha256
    pf_file, pf = _preflight_receipt(preflight_path, preflight_sha256)
    u, core = _u(), _core()
    world = _editor(u)
    assert world.get_path_name() == c['map_package'] + '.LI_Warrens_Hub'
    assert _sha(ROOT / c['map_file']) == c['map_sha256_before']
    guards, collision = _guard_data(c)
    assets, owned, targets = _asset_rows(c)
    fit, rows, _ = _selection(c)
    current_folder = RUN / ('apply_before_' + uuid.uuid4().hex)
    current_roster, before = _roster(u, core, world, current_folder)
    assert _digest(_semantic(core, before)) == pf['semantic_hism_sha256']
    assert _digest(_global_geometry(before)) == pf['global_geometry_sha256']
    assert len(current_roster) == len(pf['actor_component_roster'])
    for name, row in pf['actor_component_roster'].items():
        assert name in current_roster and row['raw']['sha256'] == current_roster[name]['raw']['sha256'], \
            ('preflight actor changed', name)
    _assert_raw_roster(pf['actor_component_roster'], current_roster)
    sources = _source_components(u, core, world, c)
    matches = _match(u, core, c, fit, rows, sources)
    assert matches == pf['selected_live_instances'], 'Source selection no longer matches the reviewed preflight'
    for ident in c['source_actors']:
        assert sources[ident]['snapshot'] == pf['source_components'][ident]
    folder = RUN / ('checkpoint_' + uuid.uuid4().hex)
    folder.mkdir(parents=True, exist_ok=False)
    backup = folder / 'LI_Warrens_Hub.before.umap'
    shutil.copy2(ROOT / c['map_file'], backup)
    assert _sha(backup) == c['map_sha256_before']
    editor_settings_class = u.load_class(None, '/Script/UnrealEd.EditorLoadingSavingSettings')
    jolt_settings_class = u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    assert editor_settings_class and jolt_settings_class
    settings = u.get_default_object(editor_settings_class)
    jolt = u.get_default_object(jolt_settings_class)
    autosave_before = settings.get_editor_property('bAutoSaveEnable')
    cook_before = jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    assert isinstance(autosave_before, bool)
    checkpoint = _write('checkpoint', dict(phase='checkpoint', status='HUB_SOURCE_CHECKPOINTED',
        map=c['map_package'], before_sha256=c['map_sha256_before'], backup=backup.relative_to(ROOT).as_posix(),
        backup_sha256=_sha(backup), preflight=dict(path=pf_file.relative_to(ROOT).as_posix(), sha256=preflight_sha256),
        guard_count=len(guards), collision_count=len(collision), settings_before=dict(
            auto_save=autosave_before, jolt_auto_cook=str(cook_before))))
    state.data = dict(stage='mutating', world=world, settings_before=dict(autosave=autosave_before, cook=cook_before),
        backup=backup.relative_to(ROOT).as_posix(), guards=guards, collision=collision, before=before,
        roster=current_roster, matches=matches, owned=owned, target_materials=targets,
        labels=c['trial_labels'], original_map_sha=c['map_sha256_before'], checkpoint=checkpoint,
        preflight=dict(path=pf_file.relative_to(ROOT).as_posix(), sha256=preflight_sha256), source_names=c['source_actors'])
    try:
        settings.set_editor_property('bAutoSaveEnable', False)
        jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(cook_before).DISABLE)
        assert settings.get_editor_property('bAutoSaveEnable') is False
        assert jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave') == type(cook_before).DISABLE
        by_group = {}
        for item in matches:
            key = (item['ident'], item['axis'])
            by_group.setdefault(key, []).append(item)
        created, native_components = [], {}
        material_objs = {}
        for axis, spec in targets.items():
            package = ROOT / ('Content/' + spec['path'].removeprefix('/Game/') + '.uasset')
            assert _sha(package) == spec['sha256']
            material_objs[axis] = u.load_asset(spec['path'])
            assert material_objs[axis] and _package(material_objs[axis]) == spec['path']
        for ident, source_data in sources.items():
            source = source_data['component']
            source_path = source.get_path_name()
            for axis in (0, 1):
                selected = by_group[(ident, axis)]
                label = c['trial_labels'][f'{ident}:{axis}']
                actor, component, native = _new_group(u, world, source, [item['index'] for item in selected],
                    material_objs[axis], label, c['owner'], c['target_folder'], folder / ('native_' + label))
                native_components[label] = native
                created.append(dict(label=label, ident=ident, axis=axis, actor=actor, component=component,
                    selected=selected, source_path=source_path))
        for ident, source_data in sources.items():
            indices = [item['index'] for item in matches if item['ident'] == ident]
            assert len(indices) == len(set(indices))
        for ident, source_data in sources.items():
            comp = source_data['component']
            comp.modify()
            for index in sorted((m['index'] for m in matches if m['ident'] == ident), reverse=True):
                assert comp.remove_instance(index)
        current_roster2, after = _roster(u, core, world, folder / 'staged_roster')
        new_actor_names = [name for name in current_roster2 if name not in current_roster]
        assert len(new_actor_names) == 4
        added_by_label = {entry['label']: entry for entry in created}
        after_actor_by_label = {row['label']: (name, row) for name, row in current_roster2.items()}
        for label, entry in added_by_label.items():
            assert label in after_actor_by_label
            actor_name, actor_row = after_actor_by_label[label]
            assert actor_row['tags'] == [c['owner']] and actor_row['type'] == '/Script/Engine.Actor'
            assert actor_row['pose'] == core._pose(u.Transform()), ('partition actor must remain identity', label)
            assert actor_row['folder'] == c['target_folder']
            expected_names = set(native_components[label]) | {entry['component'].get_name()}
            assert set(actor_row['components']) == expected_names
            for comp_name, baseline in native_components[label].items():
                actual = actor_row['components'][comp_name]
                assert actual['type'] == baseline['type'] and actual['raw']['sha256'] == baseline['raw']['sha256']
            entry['actor_name'] = actor_name
        _verify_existing_roster(current_roster, current_roster2,
                                set(c['source_actors'].values()), set(new_actor_names))
        expected_hisms = _verify_hisms(core, before, after, matches, created, targets,
                                       c['trial_labels'], c['source_actors'])
        expected_geometry = _global_geometry(before)
        actual_geometry = _global_geometry(after)
        assert _digest(actual_geometry) == _digest(expected_geometry), 'Global mesh/pose multiset changed'
        _guard_data(c)
        assert _dirty(u)['content'] == []
        assert len(_dirty(u)['maps']) == 1 and _package(u.EditorLoadingAndSavingUtils.get_dirty_map_packages()[0]) == c['map_package']
        state.data.update(stage='staged', created=None, world=None, settings=None, jolt=None,
            post_stage_hisms=after, post_stage_roster=current_roster2, expected_hisms=expected_hisms,
            expected_geometry_sha256=_digest(expected_geometry), new_actor_names=new_actor_names,
            native_component_baselines=native_components)
        receipt = _write('staged', dict(phase='staged', status='HUB_WALL_PARTITION_STAGED_UNSAVED',
            checkpoint=checkpoint, preflight=state.data['preflight'], source_map=c['map_package'],
            original_actor_count=len(current_roster), staged_actor_count=len(current_roster2),
            original_hism_count=len(before), staged_hism_count=len(after), selected_count=len(matches),
            group_counts={entry['label']: len(entry['selected']) for entry in created},
            global_mesh_pose_sha256=_digest(actual_geometry), geometry_unchanged=True,
            collision_count=54, guards_count=634, map_saved=False,
            next='On a later editor callback call save_staged with this receipt.'))
        state.data['staged_receipt'] = receipt
        # Release all world-bound UObject refs while preserving JSON evidence and CDO values.
        for k in ('world', 'settings', 'jolt'):
            state.data.pop(k, None)
        return receipt
    except Exception as exc:
        dirty = _dirty(u)
        if dirty == dict(maps=[], content=[]):
            settings.set_editor_property('bAutoSaveEnable', autosave_before)
            jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave', cook_before)
            state.data = None
        else:
            state.data.update(stage='failed_dirty', world=None,
                settings_before=dict(autosave=autosave_before, cook=cook_before))
        return _write('failure', dict(phase='failure', status='FAILED_NO_AUTOMATIC_ROLLBACK',
            checkpoint=checkpoint, error=type(exc).__name__ + ': ' + str(exc), dirty=dirty,
            map_sha256_now=_sha(ROOT / c['map_file']), settings_restored=(dirty == dict(maps=[], content=[])),
            created_labels=[entry.get('label') for entry in created] if 'created' in locals() else [],
            map_saved=False, recovery='Do not save or retry. Keep autosave/Jolt disabled while dirty; root owns explicit checkpoint restore.'))


def _verify_existing_roster(before, after, changed_labels, new_names):
    assert set(after) == set(before) | set(new_names)
    for name, old in before.items():
        new = after[name]
        assert {k: v for k, v in old.items() if k in ('label', 'type', 'tags', 'pose', 'hidden', 'folder')} == \
               {k: v for k, v in new.items() if k in ('label', 'type', 'tags', 'pose', 'hidden', 'folder')}
        changed = old['label'] in changed_labels
        if not changed:
            assert old['raw']['sha256'] == new['raw']['sha256'], ('unrelated actor changed', name)
        assert set(old['components']) == set(new['components'])
        for cname, old_component in old['components'].items():
            if changed and 'hism' in old_component:
                continue
            assert old_component['raw']['sha256'] == new['components'][cname]['raw']['sha256'], \
                ('unrelated component changed', name, cname)


def _save_staged_impl(staged_path, staged_sha256):
    state = _state().data
    assert state and state['stage'] == 'staged'
    file, receipt = _phase_receipt(staged_path, staged_sha256, 'staged')
    assert receipt['status'] == 'HUB_WALL_PARTITION_STAGED_UNSAVED'
    c = _contract()
    u, core = _u(), _core()
    world, dirty = _source_world(u, [c['map_package']])
    # Re-inventory only after staging has settled on a later editor callback.
    folder = RUN / ('save_check_' + uuid.uuid4().hex)
    roster, hisms = _roster(u, core, world, folder)
    _verify_existing_roster(state['roster'], roster, set(c['source_actors'].values()), set(state['new_actor_names']))
    assert _digest(_semantic(core, hisms)) == _digest(_semantic(core, state['post_stage_hisms']))
    assert _digest(_global_geometry(hisms)) == state['expected_geometry_sha256']
    assert dirty['maps'] == [c['map_package']] and dirty['content'] == []
    guards, collision = _guard_data(c)
    assert all(_sha(ROOT / p) == d for p, d in collision.items())
    # Save exactly the already-open Hub source map; no other package is admitted.
    _map_save(u)
    map_after = _sha(ROOT / c['map_file'])
    assert map_after != c['map_sha256_before']
    dirty = _dirty(u)
    assert dirty == dict(maps=[], content=[])
    after_guards = dict(guards)
    after_guards[c['map_file']] = map_after
    _guards_except_map(c, after_guards, current_map_sha=map_after)
    assets, owned, _targets = _asset_rows(c)
    collision_after = _collision_check()
    assert collision_after == collision
    post_folder = RUN / ('post_save_' + uuid.uuid4().hex)
    post_roster, post_hisms = _roster(u, core, world, post_folder)
    _verify_existing_roster(state['roster'], post_roster, set(c['source_actors'].values()), set(state['new_actor_names']))
    assert _digest(_semantic(core, post_hisms)) == _digest(_semantic(core, state['post_stage_hisms']))
    assert _digest(_global_geometry(post_hisms)) == state['expected_geometry_sha256']
    _restore_settings(u, state['settings_before'])
    result = _write('saved', dict(phase='saved', status='HUB_SOURCE_SAVED_RELOAD_VERIFICATION_REQUIRED',
        staged_receipt=dict(path=file.relative_to(ROOT).as_posix(), sha256=staged_sha256),
        map=c['map_package'], map_before=c['map_sha256_before'], map_after=map_after,
        checkpoint=state['checkpoint'], guard_count=634, collision_count=54,
        owned_asset_hashes={row['path']: row['package_sha256'] for row in owned},
        original_actor_count=len(state['roster']), saved_actor_count=len(post_roster),
        original_hism_count=len(state['before']), saved_hism_count=len(post_hisms),
        selected_count=144, source_roster=post_roster, hism_snapshot=post_hisms,
        semantic_hism_sha256=_digest(_semantic(core, post_hisms)),
        global_geometry_sha256=_digest(_global_geometry(post_hisms)),
        immutable_guards_after=after_guards, dirty=dirty, settings_restored=True, map_saved=True,
        boundary='Only original Hub source map was saved. Require two unload/reopen audits before acceptance.'))
    state.update(stage='saved', map_after=map_after, guards_after=after_guards, saved_receipt=result,
                 post_save_roster=post_roster, post_save_hisms=post_hisms)
    return result


def save_staged(staged_path, staged_sha256):
    try:
        return _save_staged_impl(staged_path, staged_sha256)
    except Exception as exc:
        state = _state().data
        if state is not None:
            u = _u()
            dirty = _dirty(u)
            state['stage'] = 'failed_dirty'
            state['world'] = None
            settings = state.get('settings_before', {})
            disabled = False
            settings_evidence = {}
            try:
                editor_class = u.load_class(None, '/Script/UnrealEd.EditorLoadingSavingSettings')
                jolt_class = u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
                editor, jolt = u.get_default_object(editor_class), u.get_default_object(jolt_class)
                editor.set_editor_property('bAutoSaveEnable', False)
                jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(
                    jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')).DISABLE)
                auto_save = editor.get_editor_property('bAutoSaveEnable')
                cook = jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
                disabled = auto_save is False and cook == type(cook).DISABLE
                settings_evidence = dict(auto_save=auto_save, jolt_auto_cook=str(cook))
            except Exception as settings_error:
                settings_evidence = dict(error=repr(settings_error))
            return _write('save_failure', dict(phase='save_failure', status='SAVE_FAILED_RECOVERY_REQUIRED',
                error=type(exc).__name__ + ': ' + str(exc), map_sha256_now=_sha(ROOT / _contract()['map_file']),
                dirty=dirty, checkpoint=state.get('checkpoint'), settings_left_disabled=disabled,
                settings_readbacks=settings_evidence,
                original_settings=dict(auto_save=settings.get('autosave'), jolt_auto_cook=str(settings.get('cook'))),
                map_saved='inspect source bytes; no second save is allowed'))
        raise


def _phase_receipt(path, digest, phase):
    file = Path(path)
    if not file.is_absolute():
        file = ROOT / file
    file = file.resolve()
    assert file.is_relative_to((RUN / 'receipts').resolve()) and file.is_file() and _sha(file) == digest
    data = _json(file)
    assert data['phase'] == phase and data['tool_sha256'] == _sha(__file__)
    assert data['config_sha256'] == _sha(CONFIG)
    return file, data


def _restore_settings(u, prior):
    editor_class = u.load_class(None, '/Script/UnrealEd.EditorLoadingSavingSettings')
    jolt_class = u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    editor = u.get_default_object(editor_class)
    jolt = u.get_default_object(jolt_class)
    editor.set_editor_property('bAutoSaveEnable', prior['autosave'])
    jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave', prior['cook'])
    assert editor.get_editor_property('bAutoSaveEnable') == prior['autosave']
    assert jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave') == prior['cook']


def _assert_settings(u, prior):
    editor_class = u.load_class(None, '/Script/UnrealEd.EditorLoadingSavingSettings')
    jolt_class = u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    editor = u.get_default_object(editor_class)
    jolt = u.get_default_object(jolt_class)
    assert editor.get_editor_property('bAutoSaveEnable') == prior['autosave']
    assert jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave') == prior['cook']


def verify_reload(saved_path, saved_sha256, prior_reload_path=None, prior_reload_sha256=None):
    """Call once after each actual unload/reopen; second call requires first receipt."""
    state = _state().data
    assert state and state['stage'] == 'saved'
    saved_file, saved = _phase_receipt(saved_path, saved_sha256, 'saved')
    u, core = _u(), _core()
    world = _editor(u)
    c = _contract()
    assert _package(world) == c['map_package']
    assert world.get_path_name() == c['map_package'] + '.LI_Warrens_Hub'
    assert _sha(ROOT / c['map_file']) == state['map_after'] == saved['map_after']
    _guards_except_map(c, state['guards_after'], current_map_sha=state['map_after'])
    roster, hisms = _roster(u, core, world, RUN / ('reload_' + uuid.uuid4().hex))
    assert _digest(_semantic(core, hisms)) == saved['semantic_hism_sha256']
    assert _digest(_global_geometry(hisms)) == saved['global_geometry_sha256']
    _assert_reopen_shape(saved['source_roster'], roster)
    _verify_reopen_transition(state['roster'], roster, set(c['source_actors'].values()),
                              set(c['trial_labels'].values()))
    _verify_reopen_against_saved(saved['source_roster'], roster, set(c['source_actors'].values()))
    assert _collision_check() == state['collision']
    _assert_settings(u, state['settings_before'])
    if prior_reload_path is None:
        result = _write('reload_first', dict(phase='reload_first', status='FIRST_REOPEN_CAPTURED_SECOND_REQUIRED',
            saved_receipt=dict(path=saved_file.relative_to(ROOT).as_posix(), sha256=saved_sha256),
            map_sha256=state['map_after'], actor_roster=roster, hism_snapshot=hisms,
            semantic_hism_sha256=_digest(_semantic(core, hisms)), global_geometry_sha256=_digest(_global_geometry(hisms)),
            guards_verified=True, collision_count=54, dirty=dict(maps=[], content=[]),
            instruction='Unload and reopen this source LI again before verify_reload with this receipt.'))
        state['reload_first'] = result
        return result
    first_file, first = _phase_receipt(prior_reload_path, prior_reload_sha256, 'reload_first')
    assert state.get('reload_first') == dict(file=first_file.relative_to(ROOT).as_posix(), sha256=prior_reload_sha256,
                                               phase=first['phase'], status=first['status'])
    assert _digest(_semantic(core, hisms)) == _digest(_semantic(core, first['hism_snapshot']))
    assert _digest(_global_geometry(hisms)) == first['global_geometry_sha256']
    _assert_raw_roster(first['actor_roster'], roster)
    assert len(_json(ROOT / c['guard_receipt']['path'])['immutable_guards']) == 634
    result = _write('reload_second', dict(phase='reload_second', status='TWO_REOPEN_SERIALIZATION_STABLE',
        saved_receipt=dict(path=saved_file.relative_to(ROOT).as_posix(), sha256=saved_sha256),
        first_reload=dict(path=first_file.relative_to(ROOT).as_posix(), sha256=prior_reload_sha256),
        map_sha256=state['map_after'], actor_roster=roster, hism_snapshot=hisms,
        semantic_hism_sha256=_digest(_semantic(core, hisms)), global_geometry_sha256=_digest(_global_geometry(hisms)),
        raw_roster_matches_first_reload=True, guards_verified=True, collision_count=54,
        dirty=dict(maps=[], content=[]), settings_restored=True,
        boundary='Source-map serialization only; assembled Main/PIE membership remains a separate check.'))
    state['stage'] = 'verified'
    _state().data = None
    return result


def _assert_raw_roster(expected, actual):
    assert set(expected) == set(actual)
    for actor, old in expected.items():
        new = actual[actor]
        assert old['raw']['sha256'] == new['raw']['sha256'], ('actor export changed after second reopen', actor)
        assert old['label'] == new['label'] and old['type'] == new['type'] and old['tags'] == new['tags']
        assert old['folder'] == new['folder']
        assert set(old['components']) == set(new['components'])
        for component, before in old['components'].items():
            after = new['components'][component]
            assert before['raw']['sha256'] == after['raw']['sha256'], ('component export changed after second reopen', actor, component)


def _assert_reopen_shape(saved_roster, reopened):
    assert len(saved_roster) == len(reopened)
    saved_by_label = {}
    reopened_by_label = {}
    for roster, dest in ((saved_roster, saved_by_label), (reopened, reopened_by_label)):
        for name, row in roster.items():
            assert row['label'] not in dest, ('actor label not unique in source LI', row['label'])
            dest[row['label']] = row
    assert set(saved_by_label) == set(reopened_by_label)
    for label, before in saved_by_label.items():
        after = reopened_by_label[label]
        for field in ('type', 'tags', 'pose', 'hidden', 'folder'):
            assert before[field] == after[field], ('actor metadata changed after reopen', label, field)
        assert Counter(c['type'] for c in before['components'].values()) == \
               Counter(c['type'] for c in after['components'].values()), ('actor component classes changed', label)


def _by_label(roster):
    result = {}
    for name, row in roster.items():
        assert row['label'] not in result, ('actor label is ambiguous', row['label'])
        result[row['label']] = (name, row)
    return result


def _verify_reopen_transition(before, after, changed_actor_labels, added_labels):
    old, new = _by_label(before), _by_label(after)
    assert set(new) == set(old) | set(added_labels)
    for label, (_name, prior) in old.items():
        _new_name, current = new[label]
        for field in ('label', 'type', 'tags', 'pose', 'hidden', 'folder'):
            assert prior[field] == current[field], ('actor changed across source reload', label, field)
        if label not in changed_actor_labels:
            assert prior['raw']['sha256'] == current['raw']['sha256'], ('unrelated actor raw changed', label)
        assert set(prior['components']) == set(current['components']), ('actor component roster changed', label)
        for cname, old_component in prior['components'].items():
            actual = current['components'][cname]
            assert old_component['type'] == actual['type']
            if 'hism' in old_component and label in changed_actor_labels:
                continue
            assert old_component['raw']['sha256'] == actual['raw']['sha256'], \
                ('unrelated component raw changed', label, cname)


def _verify_reopen_against_saved(saved, reopened, mutable_actor_raw_labels):
    old, new = _by_label(saved), _by_label(reopened)
    assert set(old) == set(new)
    for label, (_oldname, prior) in old.items():
        _newname, current = new[label]
        for field in ('type', 'tags', 'pose', 'hidden', 'folder'):
            assert prior[field] == current[field], ('saved actor metadata changed on reopen', label, field)
        if label not in mutable_actor_raw_labels:
            assert prior['raw']['sha256'] == current['raw']['sha256'], ('saved actor raw changed on reopen', label)
        assert set(prior['components']) == set(current['components']), ('saved component roster changed on reopen', label)
        for cname, old_component in prior['components'].items():
            actual = current['components'][cname]
            assert old_component['type'] == actual['type']
            if 'hism' in old_component:
                continue
            assert old_component['raw']['sha256'] == actual['raw']['sha256'], \
                ('saved non-HISM component raw changed on reopen', label, cname)


def restore_settings_after_manual_recovery():
    """Restore temporary CDO settings only after manually restoring the exact checkpoint."""
    state = _state().data
    assert state and state['stage'] == 'failed_dirty'
    c = _contract()
    u = _u()
    world = _editor(u)
    assert _sha(ROOT / c['map_file']) == state['original_map_sha'], 'Restore the exact Hub backup first'
    backup = ROOT / state['backup']
    assert backup.is_file() and _sha(backup) == state['original_map_sha']
    _guard_data(c)
    _restore_settings(u, state['settings_before'])
    _state().data = None
    return dict(status='SETTINGS_RESTORED_AFTER_MANUAL_HUB_RECOVERY')

