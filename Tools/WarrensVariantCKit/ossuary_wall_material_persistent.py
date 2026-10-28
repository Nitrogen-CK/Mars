"""Checkpointed, wall-only Ossuary material adoption.

Import is inert. In the Unreal Editor, call preflight() for a read-only receipt,
then apply(reviewed_file, reviewed_sha256) only after reviewing that receipt.
This tool partitions only the authored wall rows from the mixed BACKING_TX01
HISM. It never changes ceilings, geometry, UVs, lights, collision, or libraries.

If mutation fails while the source map is dirty, automatic save remains disabled.
Restore the original map checkpoint manually, verify the editor is clean, then
call restore_settings_after_manual_recovery(). There is no automatic rollback.
"""
from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import shutil
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/OSSUARY_MATERIAL_RUNTIME_REVIEW.md'
REVIEW_SHA256 = 'd7e456856a2027513028eb04774cd0c1cd4f9d786755cf589c2c82422fce9ec9'
TRIAL = HERE / 'ossuary_material_trial.py'
TRIAL_SHA256 = 'd8cefe481603643276f013c9149298dbaa7d2d7abb170bc183383bd92ddfbc68'
CORE = HERE / 'bank_identity_unreal.py'
CORE_SHA256 = '4859e7ab71dc9e0a5d93b61511eb759ef741598af4821ba62df69cd8ee014619'
PERSISTENT = HERE / 'belfry_palette_persistent.py'
PERSISTENT_SHA256 = 'fbfd6108d9db35fba8830ece6700f9394ca4eef7005594e371b7cc58a37a4a7a'
FIT = HERE / 'Output/fitted_instances.json'
FIT_SHA256 = '67f8e8d87ab166ab7fd0cd5e285a08e02b8643c856de3bf028130271021b9d34'
BASELINE = ROOT / 'Saved/WarrensCGameplay-20261024/MechanismLayoutCheckpoint/source_layout_20261025T090434_092884Z_1e6e87b9.json'
BASELINE_SHA256 = 'a23c2d371433c647061446bbcd822d138094bf2774f739d364622a8ea8ab260f'
ASSET_RECEIPT = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryMaterialTrial/assets_created_20261026T002324_985770Z_b8823bc5.json'
ASSET_RECEIPT_SHA256 = 'a0745bdea6852636b7fe376cf605c2ebb3be58c1d7ac2e0577cedaa7777f4ea9'
MAP = '/Game/Mars/Maps/Variants/v8c/LI_Warrens_Ossuary'
MAP_FILE = ROOT / 'Content/Mars/Maps/Variants/v8c/LI_Warrens_Ossuary.umap'
MAP_SHA256 = '495032dae4ea3b592934dbbe0a0aa7b1b7a75474ad7c749f0ba624bb2476e641'
MATERIAL = '/Game/Mars/ArtReview/Lookdev/OssuaryPainterly_20261025/Materials/M_Ossuary_TX01_R02_C_PainterlyAlbedo_Mix060'
MATERIAL_SHA256 = '11376944ff6bd25178376d6fee7ac754c4ace383a12323c8f51bf6d6fd485859'
MATERIAL_FILE = ROOT / 'Content/Mars/ArtReview/Lookdev/OssuaryPainterly_20261025/Materials/M_Ossuary_TX01_R02_C_PainterlyAlbedo_Mix060.uasset'
OWNER = 'Mars.WarrensC.OssuaryPainterly.R02.20261025'
ASSET_TAG = 'MarsWarrensCOssuaryPainterlyOwner'
TARGET_LABEL = 'WVC_OssuaryWallSeamBacking_C'
TARGET_TAG = 'Mars.WarrensC.OssuaryWallMaterial.R02'
CHECKPOINT = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryWallMaterialCheckpoint'
COLLISION = ROOT / 'Saved/WarrensCGameplay-20261024/StartupCheckpoint/collision_hashes.json'
STATE = None


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, allow_nan=False).encode()).hexdigest()


def _write(kind, value):
    CHECKPOINT.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '_' + uuid.uuid4().hex[:8]
    path = CHECKPOINT / (kind + '_' + stamp + '.json')
    assert not path.exists(), 'Receipts are immutable and unique'
    value = dict(value, schema=1, created_utc=datetime.now(timezone.utc).isoformat(), tool_sha256=_sha(__file__))
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n', encoding='utf-8')
    return dict(file=path.relative_to(ROOT).as_posix(), sha256=_sha(path))


def _load_module(name, path, expected_sha):
    assert _sha(path) == expected_sha, 'Frozen dependency changed: ' + path.name
    if name not in sys.modules:
        spec = importlib.util.spec_from_file_location(name, path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules[name] = module
    return sys.modules[name]


def _dependencies():
    trial = _load_module('_ossuary_material_trial_frozen_for_persistent', TRIAL, TRIAL_SHA256)
    core = _load_module('_bank_identity_frozen_for_ossuary_persistent', CORE, CORE_SHA256)
    persistent = _load_module('_belfry_persistent_frozen_for_ossuary', PERSISTENT, PERSISTENT_SHA256)
    assert _sha(FIT) == FIT_SHA256 and _sha(BASELINE) == BASELINE_SHA256
    assert _sha(REVIEW) == REVIEW_SHA256 and _sha(ASSET_RECEIPT) == ASSET_RECEIPT_SHA256
    return trial, core, persistent


def _source_contract():
    trial, core, persistent = _dependencies()
    baseline = _json(BASELINE)
    guards = baseline['initial_614_guards']
    assert len(guards) == 614
    collision = _json(COLLISION)
    assert isinstance(collision, dict) and len(collision) == 54
    assert all(_sha(ROOT / path) == digest for path, digest in guards.items())
    assert _sha(MAP_FILE) == MAP_SHA256 and guards[MAP_FILE.relative_to(ROOT).as_posix()] == MAP_SHA256
    assert _sha(MATERIAL_FILE) == MATERIAL_SHA256
    assets = _json(ASSET_RECEIPT)
    assert assets['phase'] == 'assets_created' and assets['schema'] == 1
    assert assets['material_c']['path'] == MATERIAL and assets['material_c']['package_sha256'] == MATERIAL_SHA256
    assert assets['material_c']['only_graph_deltas'] == [
        'Constant_0.R 0.12 -> 0.60',
        'MaterialExpressionTextureSample_0.Texture -> /Game/Mars/ArtReview/Lookdev/OssuaryPainterly_20261025/Textures/T_Ossuary_TX01_R02_Albedo']
    pivot, rows = trial.source_rows()
    assert len(rows) == 2218
    selected = [r for r in rows if r['row']['id'] == 'CCS15' and r['row'].get('role') == 'source exposed wall veneer'
                or r['row']['id'] == 'BACKING_TX01' and r['row'].get('role') == 'source wall seam backing']
    protected = [r for r in rows if r['row']['id'] == 'CCS13_TX01' and r['row'].get('role') == 'source ceiling underside'
                  or r['row']['id'] == 'BACKING_TX01' and r['row'].get('role') == 'source ceiling seam backing']
    assert len(selected) == 1194 and len(protected) == 462
    assert sum(r['row']['id'] == 'BACKING_TX01' for r in selected) == 597
    assert sum(r['row']['id'] == 'BACKING_TX01' for r in protected) == 231
    assert all(r['target_slots'] == [0] for r in selected + protected)
    return dict(trial=trial, core=core, persistent=persistent, pivot=pivot, rows=rows,
        selected=selected, protected=protected, guards=guards, collision=collision, assets=assets)


def _u():
    import unreal
    return unreal


def _context(clean=True):
    u = _u()
    editor = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    assert editor.get_game_world() is None, 'Stop PIE before source-map work'
    world = editor.get_editor_world()
    assert world and world.get_path_name().split('.')[0] == MAP, 'Open the exact Ossuary source LI as the editor map'
    if clean:
        assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages() == []
        assert u.EditorLoadingAndSavingUtils.get_dirty_content_packages() == []
    return u, world


def _actors(u, world):
    return list(u.GameplayStatics.get_all_actors_of_class(world, u.Actor))


def _target_sources(u, core, world, contract):
    labels = {}
    for actor in _actors(u, world):
        label = actor.get_actor_label()
        if label in ('WVC_CCS15', 'WVC_BACKING_TX01'):
            assert label not in labels, 'Duplicate authored target actor: ' + label
            labels[label] = actor
    assert set(labels) == {'WVC_CCS15', 'WVC_BACKING_TX01'}
    comps = {}
    for label, actor in labels.items():
        found = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        assert len(found) == 1
        comps[label] = found[0]
    backing = comps['WVC_BACKING_TX01']
    assert backing.get_instance_count() == 828
    backing_mesh = next(r['mesh'] for r in contract['rows'] if r['label'] == 'WVC_BACKING_TX01')
    assert core._package(backing.static_mesh) == backing_mesh
    for label in comps:
        assert comps[label].get_collision_profile_name() == 'NoCollision'
        assert comps[label].get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
    assert labels['WVC_BACKING_TX01'].hidden is False
    return labels, comps


def _owned_material(u, core):
    assert u.EditorAssetLibrary.does_asset_exist(MATERIAL)
    value = u.load_asset(MATERIAL)
    assert value and isinstance(value, u.Material) and core._package(value) == MATERIAL
    assert u.EditorAssetLibrary.get_metadata_tag(value, ASSET_TAG) == OWNER
    return value


def _row_index_map(u, core, component, records, pivot):
    poses = [component.get_instance_transform(i, world_space=True) for i in range(component.get_instance_count())]
    used, result = set(), {}
    for record in records:
        row = record['row']
        pitch, yaw, roll = row.get('rotation', [0, row.get('yaw', 0), 0])
        local = u.Transform(location=u.Vector(*[(row['at'][i] - pivot[i]) * 100 for i in range(3)]),
            rotation=u.Rotator(pitch=pitch, yaw=yaw, roll=roll), scale=u.Vector(*row['scale']))
        wanted = u.MathLibrary.compose_transforms(local, component.get_owner().get_level_transform())
        indices = [i for i, actual in enumerate(poses) if core._near(actual, wanted)]
        assert len(indices) == 1 and indices[0] not in used, ('Source row pose did not match uniquely', record['key'], indices)
        used.add(indices[0])
        result[record['key']] = indices[0]
    assert len(used) == component.get_instance_count(), 'A source instance is not represented by the fitted ledger'
    return result


def _roster(world, folder):
    trial, core, persistent = _dependencies()
    u = _u()
    adapter = dict(_pose=core._pose, _component=core._component, _package=core._package)
    return persistent._roster(u, adapter, world, folder)


def _file_guards(contract, map_hash=None):
    current = {p: _sha(ROOT / p) for p in contract['guards']}
    for path, expected in contract['guards'].items():
        if path == MAP_FILE.relative_to(ROOT).as_posix() and map_hash is not None:
            assert current[path] == map_hash
        else:
            assert current[path] == expected, 'Protected file changed: ' + path
    collision = _json(COLLISION)
    assert len(collision) == 54
    assert all(_sha(ROOT / path) == digest for path, digest in collision.items()), 'Collision artifact changed'
    return current


def preflight():
    """Read-only exact membership/roster receipt. No actor or package changes."""
    contract = _source_contract()
    u, world = _context()
    material = _owned_material(u, contract['core'])
    settings_obj, autosave_before, jolt_obj, cook_before = _settings(u)
    labels, comps = _target_sources(u, contract['core'], world, contract)
    backing_rows = [r for r in contract['rows'] if r['label'] == 'WVC_BACKING_TX01']
    wall = [r for r in backing_rows if r in contract['selected']]
    ceiling = [r for r in backing_rows if r in contract['protected']]
    assert len(backing_rows) == 828 and len(wall) == 597 and len(ceiling) == 231
    by_label = {}
    for row in contract['rows']:
        by_label.setdefault(row['label'], []).append(row)
    matched = {}
    for label, actor in labels.items():
        records = by_label[label]
        assert len(records) == comps[label].get_instance_count()
        assert contract['core']._package(comps[label].static_mesh) == records[0]['mesh']
        assert [contract['core']._package(x) for x in comps[label].get_materials()] == records[0]['materials']
        matched[label] = _row_index_map(u, contract['core'], comps[label], records, contract['pivot'])
    assert len(matched['WVC_CCS15']) == 597 and len(matched['WVC_BACKING_TX01']) == 828
    component_snapshot = {label: contract['core']._component(component) for label, component in comps.items()}
    assert component_snapshot['WVC_BACKING_TX01']['collision_profile'] == 'NoCollision'
    assert component_snapshot['WVC_BACKING_TX01']['collision_enabled'] == str(u.CollisionEnabled.NO_COLLISION)
    folder = CHECKPOINT / ('preflight_' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '_' + uuid.uuid4().hex[:8])
    roster = _roster(world, folder / 'roster')
    assert set(roster) == {a.get_name() for a in _actors(u, world)}
    all_hisms = [component['hism'] for actor in roster.values() for component in actor['components'].values()
                 if 'hism' in component]
    assert len(all_hisms) == 21 and sum(len(record['instances']) for record in all_hisms) == 2710
    guards = _file_guards(contract)
    report = dict(status='PREFLIGHT_REVIEW_REQUIRED', map=MAP, map_object=world.get_path_name(), map_sha256=_sha(MAP_FILE),
        source_plan_rows=len(contract['rows']), actor_rows={k:v for k,v in matched.items()},
        source_actors={k:a.get_path_name() for k,a in labels.items()},
        source_hism={k:component_snapshot[k] for k in comps}, full_actor_component_roster=roster,
        selected_wall_veneers=597, selected_wall_backings=597, protected_ceiling=462,
        protected_ceiling_backings=231, total_source_hisms=21, total_source_instances=2710,
        collision_file_count=54, protected_files=guards, candidate_material=MATERIAL,
        candidate_material_sha256=MATERIAL_SHA256, candidate_owner=OWNER,
        settings_readback=dict(editor_auto_save_enable=autosave_before, jolt_auto_cook=str(cook_before),
            editor_settings_class=settings_obj.get_class().get_path_name(), jolt_settings_class=jolt_obj.get_class().get_path_name()),
        source_contract=dict(review_sha256=REVIEW_SHA256, trial_sha256=TRIAL_SHA256, core_sha256=CORE_SHA256,
            fit_sha256=FIT_SHA256, baseline_sha256=BASELINE_SHA256, asset_receipt_sha256=ASSET_RECEIPT_SHA256),
        all_hism_snapshot_count=len(all_hisms), all_hism_instance_count=sum(len(r['instances']) for r in all_hisms),
        dirty=dict(maps=[], content=[]),
        boundary='Offline/source-LI preflight only. This does not approve or perform the persistent save; confirm exact target roster and membership before apply.')
    receipt = _write('preflight', report)
    return dict(status=report['status'], **receipt)


def _reviewed_receipt(file, expected_sha):
    path = (ROOT / file).resolve()
    assert path.is_relative_to(CHECKPOINT.resolve()) and path.name.startswith('preflight_') and path.suffix == '.json'
    assert _sha(path) == expected_sha
    data = _json(path)
    assert data['tool_sha256'] == _sha(__file__), 'Regenerate preflight after helper edits'
    assert data['status'] == 'PREFLIGHT_REVIEW_REQUIRED' and data['map'] == MAP
    assert data['map_object'] == MAP + '.LI_Warrens_Ossuary'
    assert data['map_sha256'] == MAP_SHA256 and data['selected_wall_veneers'] == 597
    assert data['selected_wall_backings'] == 597 and data['protected_ceiling'] == 462
    assert data['total_source_hisms'] == 21 and data['total_source_instances'] == 2710
    assert data['all_hism_snapshot_count'] == 21 and data['all_hism_instance_count'] == 2710
    assert data['collision_file_count'] == 54
    assert data['candidate_material'] == MATERIAL and data['candidate_material_sha256'] == MATERIAL_SHA256
    assert isinstance(data.get('settings_readback', {}).get('editor_auto_save_enable'), bool)
    assert data['source_contract']['review_sha256'] == REVIEW_SHA256
    return path, data


def _verify_roster(before, after, changed_components, new_actor_name):
    assert set(after) == set(before) | {new_actor_name}
    for name, old in before.items():
        new = after[name]
        assert {k:v for k,v in old.items() if k not in ('raw', 'components')} == {
            k:v for k,v in new.items() if k not in ('raw', 'components')}
        changed = changed_components.get(name, set())
        if not changed:
            assert old['raw']['sha256'] == new['raw']['sha256'], 'Unrelated actor changed: ' + old['label']
        assert set(old['components']) == set(new['components'])
        for comp, record in old['components'].items():
            current = new['components'][comp]
            if comp not in changed:
                assert record['raw']['sha256'] == current['raw']['sha256'], 'Unrelated component changed: ' + comp


def _new_backing_group(u, source, world, selected_indices, material, folder):
    actor = u.get_editor_subsystem(u.EditorActorSubsystem).spawn_actor_from_class(u.Actor, u.Vector(), u.Rotator())
    assert actor and actor.get_world() == world and actor.get_level().get_outer() == world
    actor.set_actor_label(TARGET_LABEL)
    actor.tags = [u.Name(TARGET_TAG)]
    actor.set_folder_path('Warrens/OssuaryWallMaterial')
    assert actor.root_component
    actor.root_component.set_mobility(source.get_editor_property('mobility'))
    _, _, persistent = _dependencies()
    native_components = {c.get_name(): dict(type=c.get_class().get_path_name(),
        raw=persistent._export(u, c, folder / ('native_' + c.get_name() + '.t3d')))
        for c in actor.get_components_by_class(u.ActorComponent)}
    assert actor.root_component.get_name() in native_components
    assert not actor.get_components_by_class(u.StaticMeshComponent)
    ss = u.get_engine_subsystem(u.SubobjectDataSubsystem)
    root = ss.k2_gather_subobject_data_for_instance(actor)[0]
    handle, reason = ss.add_new_subobject(u.AddNewSubobjectParams(parent_handle=root,
        new_class=u.HierarchicalInstancedStaticMeshComponent))
    component = u.SubobjectDataBlueprintFunctionLibrary.get_associated_object(
        u.SubobjectDataBlueprintFunctionLibrary.get_data(handle))
    assert isinstance(component, u.HierarchicalInstancedStaticMeshComponent), str(reason)
    component.set_mobility(source.get_editor_property('mobility'))
    assert component.set_static_mesh(source.static_mesh)
    component.set_world_transform(source.get_world_transform(), False, True)
    component.set_collision_profile_name(source.get_collision_profile_name())
    component.set_editor_property('generate_overlap_events', source.get_editor_property('generate_overlap_events'))
    component.set_cast_shadow(source.cast_shadow)
    component.set_hidden_in_game(source.get_editor_property('hidden_in_game'), False)
    component.set_editor_property('instancing_random_seed', source.get_editor_property('instancing_random_seed'))
    component.set_cull_distances(source.get_editor_property('instance_start_cull_distance'),
                                 source.get_editor_property('instance_end_cull_distance'))
    for slot, original in enumerate(source.get_materials()):
        component.set_material(slot, material if slot == 0 else original)
    component.set_visibility(source.is_visible(), False)
    # `add_instances(..., True, False, False)` interprets poses as local-space.
    poses = [source.get_instance_transform(i, world_space=False) for i in selected_indices]
    assert len(poses) == 597
    assert list(component.add_instances(poses, True, False, False)) == list(range(597))
    return actor, component, native_components


def _expected_component(source_snapshot, new_path, actor_name, material_path, poses):
    expected = copy.deepcopy(source_snapshot)
    expected.update(path=new_path, owner=actor_name, owner_label=TARGET_LABEL,
        materials=[material_path] + expected['materials'][1:], instances=poses)
    return expected


def _settings(u):
    cls = u.load_class(None, '/Script/UnrealEd.EditorLoadingSavingSettings')
    assert cls
    obj = u.get_default_object(cls)
    autosave = obj.get_editor_property('bAutoSaveEnable')
    assert isinstance(autosave, bool), 'Expected reflected EditorLoadingSavingSettings.bAutoSaveEnable; no mutation made'
    jolt_cls = u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    assert jolt_cls
    jolt = u.get_default_object(jolt_cls)
    cook = jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    assert hasattr(type(cook), 'DISABLE'), 'Expected CkJolt cook-disable enum; no mutation made'
    return obj, autosave, jolt, cook


def apply(reviewed_preflight_file, reviewed_preflight_sha256):
    """Apply the reviewed row partition and save only the current Ossuary map."""
    global STATE
    assert STATE is None, 'An earlier attempt is active; inspect/recover it before retrying'
    path, old = _reviewed_receipt(reviewed_preflight_file, reviewed_preflight_sha256)
    contract = _source_contract()
    u, world = _context()
    assert _sha(MAP_FILE) == old['map_sha256'] == MAP_SHA256
    guards = _file_guards(contract)
    labels, comps = _target_sources(u, contract['core'], world, contract)
    folder = path.parent
    current = _roster(world, folder / ('apply_before_' + uuid.uuid4().hex[:8]))
    contract['persistent']._exact_roster(old['full_actor_component_roster'], current)
    before_snapshot = {k:contract['core']._component(v) for k,v in comps.items()}
    assert before_snapshot == old['source_hism']
    material = _owned_material(u, contract['core'])
    rows_by_label = {}
    for row in contract['rows']:
        rows_by_label.setdefault(row['label'], []).append(row)
    backing_records = rows_by_label['WVC_BACKING_TX01']
    selected_keys = {r['key'] for r in contract['selected'] if r['label'] == 'WVC_BACKING_TX01'}
    selected = [r for r in backing_records if r['key'] in selected_keys]
    protected = [r for r in backing_records if r['key'] not in selected_keys]
    assert len(selected) == 597 and len(protected) == 231
    backing_indices = _row_index_map(u, contract['core'], comps['WVC_BACKING_TX01'], backing_records, contract['pivot'])
    selected_indices = sorted(backing_indices[r['key']] for r in selected)
    protected_indices = sorted(backing_indices[r['key']] for r in protected)
    before_map_backup = folder / ('LI_Warrens_Ossuary.before_' + uuid.uuid4().hex[:8] + '.umap')
    assert not before_map_backup.exists()
    shutil.copy2(MAP_FILE, before_map_backup)
    assert _sha(before_map_backup) == MAP_SHA256
    collision_before = _json(COLLISION)
    assert len(collision_before) == 54
    settings_obj, autosave_before, jolt_obj, cook_before = _settings(u)
    checkpoint = _write('checkpoint', dict(status='CHECKPOINTED_BEFORE_MUTATION', preflight_file=str(path.relative_to(ROOT)),
        preflight_sha256=reviewed_preflight_sha256, map_before=MAP_SHA256,
        map_backup=str(before_map_backup.relative_to(ROOT)), guards=guards, collision_hashes=collision_before,
        roster_sha256=_digest(current), candidate_material=MATERIAL, candidate_material_sha256=MATERIAL_SHA256,
        settings_before=dict(auto_save=autosave_before, auto_cook=str(cook_before)),
        rollback='If apply/save fails, do not save again. Keep auto-save and auto-cook disabled; manually reload/restore only the checkpointed Ossuary source map, verify no dirty packages and all guards, then restore settings explicitly.'))
    changed = {}
    actor = component = None
    dirty_started = False
    settings_restored = False
    save_verified = False
    try:
        settings_obj.set_editor_property('bAutoSaveEnable', False)
        jolt_obj.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(cook_before).DISABLE)
        assert settings_obj.get_editor_property('bAutoSaveEnable') is False
        assert jolt_obj.get_editor_property('_AutoCookStaticWorldOnLevelSave') == type(cook_before).DISABLE
        source = comps['WVC_BACKING_TX01']
        source.modify()
        dirty_started = True
        actor, component, native_components = _new_backing_group(u, source, world, selected_indices, material, folder)
        # Preserve only the 231 exact non-wall source poses in the mixed component.
        poses = [source.get_instance_transform(i, world_space=False) for i in protected_indices]
        source.clear_instances()
        assert list(source.add_instances(poses, True, False, False)) == list(range(231))
        ccs = comps['WVC_CCS15']
        ccs.modify()
        ccs.set_material(0, material)
        changed = {
            labels['WVC_BACKING_TX01'].get_name(): {source.get_name()},
            labels['WVC_CCS15'].get_name(): {ccs.get_name()},
        }
        after_hisms = {k:contract['core']._component(v) for k,v in comps.items()}
        expected_backing = copy.deepcopy(before_snapshot['WVC_BACKING_TX01'])
        expected_backing['instances'] = [expected_backing['instances'][i] for i in protected_indices]
        expected_ccs = copy.deepcopy(before_snapshot['WVC_CCS15'])
        expected_ccs['materials'][0] = MATERIAL
        assert after_hisms['WVC_BACKING_TX01'] == expected_backing
        assert after_hisms['WVC_CCS15'] == expected_ccs
        new_snapshot = contract['core']._component(component)
        expected_new = _expected_component(before_snapshot['WVC_BACKING_TX01'], component.get_path_name(),
            actor.get_path_name(), MATERIAL, [before_snapshot['WVC_BACKING_TX01']['instances'][i] for i in selected_indices])
        assert new_snapshot == expected_new, 'New wall backing did not preserve component settings/source poses'
        after_roster = _roster(world, folder / ('apply_after_' + uuid.uuid4().hex[:8]))
        _verify_roster(current, after_roster, changed, actor.get_name())
        new_actor_row = after_roster[actor.get_name()]
        assert new_actor_row['label'] == TARGET_LABEL and new_actor_row['tags'] == [TARGET_TAG]
        assert new_actor_row['type'] == '/Script/Engine.Actor'
        assert new_actor_row['hidden'] is False
        assert new_actor_row['pose'] == contract['core']._pose(u.Transform())
        assert set(new_actor_row['components']) == set(native_components) | {component.get_name()}
        for name, before in native_components.items():
            after = new_actor_row['components'][name]
            assert before['type'] == after['type'] and before['raw']['sha256'] == after['raw']['sha256']
        _file_guards(contract)
        assert u.EditorLoadingAndSavingUtils.get_dirty_content_packages() == []
        # Save only the explicitly open Ossuary source level; never SaveConfig on settings CDOs.
        assert u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
        assert _sha(MAP_FILE) != ''
        assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages() == []
        assert u.EditorLoadingAndSavingUtils.get_dirty_content_packages() == []
        after_guards = _file_guards(contract, map_hash=_sha(MAP_FILE))
        assert _json(COLLISION) == collision_before
        save_verified = True
        result = dict(status='SAVED_RELOAD_AND_ASSEMBLED_PIE_PENDING', map=MAP, map_before=MAP_SHA256,
            map_after=_sha(MAP_FILE), map_backup=str(before_map_backup.relative_to(ROOT)),
            map_backup_sha256=_sha(before_map_backup), checkpoint_receipt=checkpoint['file'],
            selected_wall_veneers=597, selected_wall_backings=597, protected_ceiling=462,
            original_hisms=21, added_hisms=1, source_instances_before=2710, source_instances_after=2710,
            candidate_material=MATERIAL, candidate_material_sha256=MATERIAL_SHA256, target_actor=actor.get_name(),
            target_component=component.get_name(), original_hism_after=after_hisms,
            new_hism_after=new_snapshot, source_roster_after=after_roster, changed_components=changed,
            guards_after=after_guards, collision_hashes_before=collision_before,
            collision_hashes_after=_json(COLLISION), dirty=dict(maps=[], content=[]),
            prior_settings=dict(auto_save=autosave_before, auto_cook=str(cook_before)),
            boundary='Source-map save only. Fresh unload/reload and assembled PIE membership/material/ceiling checks remain required.')
        assert result['collision_hashes_before'] == result['collision_hashes_after']
        applied = _write('applied', result)
        STATE = None
        return dict(status=result['status'], **applied)
    except Exception as exc:
        # Avoid delayed autosaving a partially-mutated map. Root must recover it manually.
        if dirty_started:
            STATE = dict(settings=settings_obj, autosave=autosave_before, jolt=jolt_obj, cook=cook_before,
                map_backup=str(before_map_backup.relative_to(ROOT)), map_before=MAP_SHA256)
        else:
            settings_obj.set_editor_property('bAutoSaveEnable', autosave_before)
            jolt_obj.set_editor_property('_AutoCookStaticWorldOnLevelSave', cook_before)
            settings_restored = True
        failure = dict(status='FAILED_NO_AUTOMATIC_ROLLBACK', error=type(exc).__name__ + ': ' + str(exc),
            checkpoint=checkpoint, map_sha256_now=_sha(MAP_FILE), dirty='inspect in editor',
            settings_restored=settings_restored, created_actor=None if actor is None else actor.get_path_name(),
            action='Do not save again. Keep auto-save/auto-cook disabled while map is dirty. Close or manually reload the checkpointed source map, verify clean state and exact guards, then explicitly restore settings.')
        receipt = _write('failure', failure)
        return dict(status=failure['status'], **receipt)
    finally:
        # CDO values are temporary only: restore after a proven clean save, or
        # after a failure that occurred before any map mutation. On dirty failure
        # leave both protections disabled until explicit manual map recovery.
        if not dirty_started or save_verified:
            try:
                settings_obj.set_editor_property('bAutoSaveEnable', autosave_before)
                jolt_obj.set_editor_property('_AutoCookStaticWorldOnLevelSave', cook_before)
                settings_restored = True
                if save_verified:
                    STATE = None
            except Exception:
                if dirty_started:
                    STATE = dict(settings=settings_obj, autosave=autosave_before, jolt=jolt_obj,
                        cook=cook_before, map_backup=str(before_map_backup.relative_to(ROOT)), map_before=MAP_SHA256)
                raise


def restore_settings_after_manual_recovery():
    """Restore temporary CDO settings only after manual map recovery is clean."""
    global STATE
    assert STATE is not None, 'No failed dirty attempt is awaiting recovery'
    contract = _source_contract()
    u, world = _context()
    assert world.get_path_name().split('.')[0] == MAP
    assert _sha(MAP_FILE) == STATE['map_before'], 'First manually restore the exact map checkpoint on disk'
    _file_guards(contract)
    assert _json(COLLISION) == contract['collision']
    STATE['settings'].set_editor_property('bAutoSaveEnable', STATE['autosave'])
    STATE['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave', STATE['cook'])
    STATE = None
    return dict(status='SETTINGS_RESTORED_AFTER_MANUAL_MAP_RECOVERY')
