"""Checkpointed Ossuary wall partition for the static Unreal Diorama.

Import is inert. In the clean Diorama editor map call preflight(), review its
immutable receipt, then call apply(file, sha256). After saving, unload Diorama,
call note_unloaded(), reopen it, and call audit(). Only two new NoCollision
HISMs and the exact 1,194 Ossuary wall instances are involved.

This does not change gameplay LIs, source meshes, UVs, collision, lights, or
materials. A dirty failure leaves auto-save and Jolt auto-cook disabled until
the Diorama map is manually restored from the checkpoint and settings are
explicitly restored.
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
CHECKPOINT = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryWallDioramaCheckpoint'
MAP = '/Game/Mars/Environment/WarrensVariantCKit/Maps/WarrensVariantC_Diorama_Mars_MAP'
MAP_FILE = ROOT / 'Content/Mars/Environment/WarrensVariantCKit/Maps/WarrensVariantC_Diorama_Mars_MAP.umap'
MAP_SHA256 = '1d6db2767b1922dbe27b335b8acdf596ff17c8c599effdc49016496ef3bd4293'
EXPOSURE_BRUSH_SHA256 = 'fb7fa0e728dbb279412db66d9afbc90d59a0a8c29907ab5d07a7eb835c44bf5e'
OSSUARY_MAP = '/Game/Mars/Maps/Variants/v8c/LI_Warrens_Ossuary'
OSSUARY_MAP_FILE = ROOT / 'Content/Mars/Maps/Variants/v8c/LI_Warrens_Ossuary.umap'
OSSUARY_MAP_SHA256 = '338f811c487450c070332d2848cc9992e8cdbccd960f40c984e3ada84ef6e7a6'
MATERIAL = '/Game/Mars/ArtReview/Lookdev/OssuaryPainterly_20261025/Materials/M_Ossuary_TX01_R02_C_PainterlyAlbedo_Mix060'
MATERIAL_FILE = ROOT / ('Content/' + MATERIAL.removeprefix('/Game/') + '.uasset')
MATERIAL_SHA256 = '11376944ff6bd25178376d6fee7ac754c4ace383a12323c8f51bf6d6fd485859'
MATERIAL_TAG = 'MarsWarrensCOssuaryPainterlyOwner'
MATERIAL_OWNER = 'Mars.WarrensC.OssuaryPainterly.R02.20261025'
BASELINE = ROOT / 'Saved/WarrensCGameplay-20261024/MechanismLayoutCheckpoint/source_layout_20261025T090434_092884Z_1e6e87b9.json'
BASELINE_SHA256 = 'a23c2d371433c647061446bbcd822d138094bf2774f739d364622a8ea8ab260f'
COLLISION = ROOT / 'Saved/WarrensCGameplay-20261024/StartupCheckpoint/collision_hashes.json'
COLLISION_SHA256 = '7b575d72d793d87a377045b70c32898b36c567a4b6d7707b8d3291bc251e4a36'
FIT = HERE / 'Output/fitted_instances.json'
FIT_SHA256 = '67f8e8d87ab166ab7fd0cd5e285a08e02b8643c856de3bf028130271021b9d34'
DATA_TOOL = HERE / 'sync_art_libraries.py'
DATA_TOOL_SHA256 = '5de7683ebf5829952c0b31b39d3d28ff34b070019ab61fc2da01462ca3bbbad6'
UE_TOOL = HERE / 'sync_art_libraries_unreal.py'
UE_TOOL_SHA256 = '80c1f85ed4cd1078e8b8223a448a333f871a3c4be3e0c77c84386dc5b3b1c2ac'
WALL_LIBRARY_TOOL = HERE / 'ossuary_wall_libraries.py'
WALL_LIBRARY_TOOL_SHA256 = 'cacb3130ff754298eb54d91333d552478ab7a98f75af3d3122d4964d84097967'
WALL_MATERIAL_TOOL = HERE / 'ossuary_wall_material_persistent.py'
WALL_MATERIAL_TOOL_SHA256 = 'd0764069551d264fe8553849c64a1c6b49f453d57c93e41b0c2d78fa2cb0ead4'
CORE_TOOL = HERE / 'bank_identity_unreal.py'
CORE_TOOL_SHA256 = '4859e7ab71dc9e0a5d93b61511eb759ef741598af4821ba62df69cd8ee014619'
LIBRARY_VERIFY = ROOT / 'Saved/WarrensCGameplay-20261024/art_verify_belfry_libraries_root_20261025.json'
LIBRARY_VERIFY_SHA256 = '81ffb1e9ce424ef229342e2f9477f2fd815114667b9b3395f4c2e53f26b97157'
PERSISTENT_RECEIPT = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryWallMaterialCheckpoint/audit_reloaded_20261026T005527_886384Z/receipt.json'
PERSISTENT_RECEIPT_SHA256 = '64dc4d3062fc64427a9bac19c1c5e1a6ceb90183dab8f0e922e503ac69e8674a'
LIBRARY_PROMOTION = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryWallLibraryStage/promotion.json'
LIBRARY_CHILDREN = {
    'KitLibrary': dict(sha256='84e24d4133ea31f7377881475409dc86d14503c94f947b1257b04afaeacf653d',
        stage='Saved/WarrensCGameplay-20261024/OssuaryWallLibraryStage/KitLibrary/61dddb145f064c8bb39fc0cbbf506fc3/stage.json',
        stage_sha256='b137dda90d90c2cddeb89ea52ca59860a40773aee0bee3d77547a2395bdb5b6b',
        audit='Saved/WarrensCGameplay-20261024/OssuaryWallLibraryStage/KitLibrary/61dddb145f064c8bb39fc0cbbf506fc3/reopen_audit.json',
        audit_sha256='b13bf377587c7bc979588d5b4fc8982804b06fd65b08dc32bfe719155f5ec3dd',
        source_views='docs/art/warrens-c-gameplay-review-20261024/lookdev/ossuary-painterly-r01/library-preview-r01/KitLibrary/SOURCE_VIEWS_VERIFIED.json',
        source_views_sha256='357d0f4cd37b82fca90bef79f0bf3ff56b2624d04edc1f7dad5fdc55737ca3ec'),
    'Diorama': dict(sha256='9e4f1f4e20ed64e6f228e635ac781d6bcb01daea44c9781eb5be96702b2b497a',
        stage='Saved/WarrensCGameplay-20261024/OssuaryWallLibraryStage/Diorama/6728d2322f7042caa1d7c437178d09e0/stage.json',
        stage_sha256='44708eb4a39b6ecea287870e71790aa41cd4213f125d3ee7cc9dd53a7a8da00d',
        audit='Saved/WarrensCGameplay-20261024/OssuaryWallLibraryStage/Diorama/6728d2322f7042caa1d7c437178d09e0/reopen_audit.json',
        audit_sha256='7e641ba351f3811c59b76f9a6f8708ed88fef641783c00441f0d5a4092ca96f2',
        source_views='docs/art/warrens-c-gameplay-review-20261024/lookdev/ossuary-painterly-r01/library-preview-r01/Diorama/SOURCE_VIEWS_VERIFIED.json',
        source_views_sha256='a94afa2fe457c0702c65cfa84b45536aca5b13367e3b7a69dcbb98fbb6d72450'),
}
PIVOT = (58.0, 55.0, 0.0)
SELECTED = {'CCS15': 597, 'BACKING_TX01': 597}
TARGET_LABELS = {ident: 'WVC_' + ident for ident in SELECTED}
NEW_LABELS = {'CCS15': 'WVC_OssuaryWall_Painterly_CCS15',
              'BACKING_TX01': 'WVC_OssuaryWall_Painterly_BackTx01'}
OWNER = 'Mars.WarrensC.OssuaryWallDiorama.R02'
TAG = 'MarsWarrensCOssuaryWallDioramaOwner'
FOLDER = 'Warrens/Art/OssuaryWallDiorama'
STATE = None


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _write(kind, token, value):
    folder = (CHECKPOINT / token).resolve()
    assert folder.is_relative_to(CHECKPOINT.resolve())
    path = folder / (kind + '.json')
    assert not path.exists(), 'Receipts are immutable; inspect an existing attempt before retrying'
    folder.mkdir(parents=True, exist_ok=True)
    record = dict(value, schema=1, token=token, created_utc=datetime.now(timezone.utc).isoformat(),
                  tool_sha256=_sha(__file__))
    path.write_text(json.dumps(record, indent=2, sort_keys=True, allow_nan=False) + '\n', encoding='utf-8')
    return dict(file=path.relative_to(ROOT).as_posix(), sha256=_sha(path))


def _load(name, path, expected_sha):
    assert _sha(path) == expected_sha, 'Frozen input changed: ' + str(path)
    if name in sys.modules:
        return sys.modules[name]
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    sys.modules[name] = module
    return module


def _deps():
    data = _load('_ossuary_diorama_data', DATA_TOOL, DATA_TOOL_SHA256)
    sync = _load('_ossuary_diorama_unreal', UE_TOOL, UE_TOOL_SHA256)
    wall_libraries = _load('_ossuary_diorama_wall_library_contract', WALL_LIBRARY_TOOL,
                           WALL_LIBRARY_TOOL_SHA256)
    wall_material = _load('_ossuary_diorama_wall_material_contract', WALL_MATERIAL_TOOL,
                          WALL_MATERIAL_TOOL_SHA256)
    core = _load('_ossuary_diorama_core', CORE_TOOL, CORE_TOOL_SHA256)
    assert _sha(FIT) == FIT_SHA256 and _sha(BASELINE) == BASELINE_SHA256
    assert _sha(MATERIAL_FILE) == MATERIAL_SHA256
    return data, sync, wall_libraries, wall_material, core


def _promotion_contract(file, expected_sha, libraries):
    if file is None and expected_sha is None:
        for name, (source, expected) in libraries.LIBRARIES.items():
            assert _sha(source) == expected, ('Original Blend changed; explicit promotion receipt required', name)
        return None
    assert file is not None and expected_sha is not None
    path = (ROOT / file).resolve()
    assert path == LIBRARY_PROMOTION.resolve() and _sha(path) == expected_sha
    receipt = _json(path)
    assert receipt['status'] == 'BOTH_ORIGINAL_BLENDS_PROMOTED'
    assert receipt['schema'] == 1
    expected_rows = {}
    for name, (source, before_sha) in libraries.LIBRARIES.items():
        expected_rows[source.relative_to(ROOT).as_posix()] = dict(name=name, source=source,
            before=before_sha, after=LIBRARY_CHILDREN[name]['sha256'])
    rows = receipt['files']
    assert len(rows) == 2
    seen, backups = set(), {}
    for row in rows:
        target = row['target']
        assert target in expected_rows and target not in seen
        expected = expected_rows[target]
        assert row['library'] == expected['name']
        assert row['before_sha256'] == expected['before'] and row['after_sha256'] == expected['after']
        backup = (ROOT / row['backup']).resolve()
        assert backup.is_relative_to(LIBRARY_PROMOTION.parent.resolve()) and _sha(backup) == expected['before']
        seen.add(target)
        backups[target] = dict(file=backup.relative_to(ROOT).as_posix(), sha256=_sha(backup))
        child = LIBRARY_CHILDREN[expected['name']]
        for field in ('stage', 'audit', 'source_views'):
            artifact = ROOT / child[field]
            assert _sha(artifact) == child[field + '_sha256']
        stage = _json(ROOT / child['stage'])
        audit = _json(ROOT / child['audit'])
        assert stage['status'] == 'SAVED_DERIVED_BLEND_REOPEN_AUDIT_PENDING'
        assert stage['source_blend'] == target and stage['source_blend_sha256'] == expected['before']
        assert stage['staged_blend_sha256'] == expected['after']
        assert audit['status'] == 'REOPEN_AUDIT_PASS' and audit['staged_blend_sha256'] == expected['after']
        assert row.get('stage_receipt') == child['stage'] and row.get('stage_receipt_sha256') == child['stage_sha256']
        assert row.get('reopen_audit') == child['audit'] and row.get('reopen_audit_sha256') == child['audit_sha256']
        assert row.get('source_views') == child['source_views']
        assert row.get('source_views_sha256') == child['source_views_sha256']
    assert seen == set(expected_rows)
    for expected in expected_rows.values():
        assert _sha(expected['source']) == expected['after']
    return dict(file=path.relative_to(ROOT).as_posix(), sha256=expected_sha,
        status=receipt['status'], backups=backups,
        promoted={target: data['after'] for target, data in expected_rows.items()})


def _library_guards(data, libraries, promotion):
    guards = data.immutable_files()
    for name, (source, old_sha) in libraries.LIBRARIES.items():
        expected = old_sha if promotion is None else LIBRARY_CHILDREN[name]['sha256']
        assert _sha(source) == expected, ('Unexpected retained Blend version', name)
        guards[source.relative_to(ROOT).as_posix()] = expected
    extras = {
        libraries.FIT: libraries.FIT_SHA256,
        libraries.SYNC: libraries.SYNC_SHA256,
        libraries.MATERIAL_BUILDER: libraries.MATERIAL_BUILDER_SHA256,
        libraries.GEOMETRY_HELPER: libraries.GEOMETRY_HELPER_SHA256,
        libraries.RUNTIME_REVIEW: libraries.RUNTIME_REVIEW_SHA256,
        libraries.ASSET_RECEIPT: libraries.ASSET_RECEIPT_SHA256,
        libraries.PAINTERLY: libraries.PAINTERLY_SHA256,
        libraries.MATERIAL: libraries.MATERIAL_SHA256,
    }
    for path, expected in extras.items():
        assert path.is_file() and _sha(path) == expected, ('Pinned library input changed', str(path))
        guards[path.relative_to(ROOT).as_posix()] = expected
    if promotion is not None:
        for backup in promotion['backups'].values():
            guards[backup['file']] = backup['sha256']
        guards[promotion['file']] = promotion['sha256']
        for child in LIBRARY_CHILDREN.values():
            for field in ('stage', 'audit', 'source_views'):
                artifact = child[field]
                guards[artifact] = child[field + '_sha256']
            staged_blend = _json(ROOT / child['stage'])['staged_blend']
            guards[staged_blend] = child['sha256']
    return dict(sorted(guards.items()))


def _baseline_guards(promotion_file=None, promotion_sha256=None):
    baseline = _json(BASELINE)
    guards = baseline['initial_614_guards']
    assert len(guards) == 614
    exceptions = {
        MAP_FILE.relative_to(ROOT).as_posix(): MAP_SHA256,
        OSSUARY_MAP_FILE.relative_to(ROOT).as_posix(): OSSUARY_MAP_SHA256,
    }
    expected = dict(guards)
    for path, digest in exceptions.items():
        assert path in expected, path
        expected[path] = digest
    # Guard the approved source libraries through their exact parent or the
    # receipt-bound child; all other files remain byte-pinned by this checkpoint.
    data = _load('_ossuary_diorama_data', DATA_TOOL, DATA_TOOL_SHA256)
    libraries = _load('_ossuary_diorama_wall_library_contract', WALL_LIBRARY_TOOL,
                      WALL_LIBRARY_TOOL_SHA256)
    promotion = _promotion_contract(promotion_file, promotion_sha256, libraries)
    if promotion is not None:
        for name, (source, _) in libraries.LIBRARIES.items():
            expected[source.relative_to(ROOT).as_posix()] = LIBRARY_CHILDREN[name]['sha256']
    for relative, digest in expected.items():
        assert _sha(ROOT / relative) == digest, ('Protected or approved-successor input changed', relative)
    collision = _json(COLLISION)
    assert _sha(COLLISION) == COLLISION_SHA256 and len(collision) == 54
    assert all(_sha(ROOT / name) == digest for name, digest in collision.items())
    verify = _json(LIBRARY_VERIFY)
    assert _sha(LIBRARY_VERIFY) == LIBRARY_VERIFY_SHA256
    assert len(verify['checks']) == 30
    assert all(check['status'] == 'PASS' for check in verify['checks'])
    extra = _library_guards(data, libraries, promotion)
    for relative, digest in extra.items():
        if relative in expected:
            assert expected[relative] == digest, ('Guard sources disagree', relative)
        expected[relative] = digest
    expected[LIBRARY_VERIFY.relative_to(ROOT).as_posix()] = LIBRARY_VERIFY_SHA256
    expected[COLLISION.relative_to(ROOT).as_posix()] = COLLISION_SHA256
    return dict(sorted(expected.items())), collision, promotion


def _guards(expected, map_sha=None):
    result = dict(expected)
    map_key = MAP_FILE.relative_to(ROOT).as_posix()
    if map_sha is not None:
        result[map_key] = map_sha
    for path, digest in result.items():
        assert _sha(ROOT / path) == digest, ('Guard changed', path)
    assert _sha(OSSUARY_MAP_FILE) == OSSUARY_MAP_SHA256
    assert _sha(MATERIAL_FILE) == MATERIAL_SHA256
    assert _sha(BASELINE) == BASELINE_SHA256
    return result


def _collision_exact(expected):
    assert _sha(COLLISION) == COLLISION_SHA256 and _json(COLLISION) == expected
    assert len(expected) == 54
    assert all(_sha(ROOT / path) == digest for path, digest in expected.items())


def _contract(data, sync, libraries):
    projection = data.projection()
    assert len(projection['effective']) == 32646
    placements = data.read(FIT)['placements']
    expected = libraries._expected_rows(projection)
    selected_rows = [(str(record['index']), placements[record['index']]) for record in expected]
    assert {ident: sum(row['id'] == ident for _, row in selected_rows) for ident in SELECTED} == SELECTED
    effective = {str(key): row for key, row in projection['effective']}
    assert all(effective.get(key) == row for key, row in selected_rows), 'Effective projection omitted or changed target row'
    assert all(not row.get('context_proxy') and 'ceiling' not in row.get('role', '').lower()
               for _, row in selected_rows)
    material_receipt = _json(PERSISTENT_RECEIPT)
    assert _sha(PERSISTENT_RECEIPT) == PERSISTENT_RECEIPT_SHA256
    assert material_receipt['status'] == 'RECOVERED_AFTER_SERIALIZATION_FAILURE_RELOADED'
    assert material_receipt['map_sha256'] == OSSUARY_MAP_SHA256
    assert material_receipt['wall_instances'] == 1194 and material_receipt['geometry_multiset_exact']
    verify = _json(LIBRARY_VERIFY)
    assert _sha(LIBRARY_VERIFY) == LIBRARY_VERIFY_SHA256 and len(verify['checks']) == 30
    return projection, selected_rows, material_receipt


def _context(sync, clean=True):
    sync.context('Diorama')
    u = sync.u
    world = sync.ED.get_editor_world()
    assert world and world.get_path_name().split('.')[0] == MAP
    if clean:
        assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
        assert not u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
    return world


def _target_components(sync, world, projection):
    u = sync.u
    by_label = {}
    for actor in u.GameplayStatics.get_all_actors_of_class(world, u.Actor):
        label = actor.get_actor_label()
        if label in TARGET_LABELS.values():
            assert label not in by_label, ('Duplicate source actor label', label)
            by_label[label] = actor
        assert TAG not in sync.tags(actor)
    assert set(by_label) == set(TARGET_LABELS.values())
    result = {}
    for label, actor in by_label.items():
        components = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        assert len(components) == 1
        component = components[0]
        assert component.get_world() == world
        assert component.get_collision_profile_name() == 'NoCollision'
        assert not component.get_editor_property('generate_overlap_events')
        result[label] = (actor, component)
    assert sum(c.get_instance_count() for actor in u.GameplayStatics.get_all_actors_of_class(world, u.Actor)
               for c in actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)) == 32646
    return result


def _match_rows(sync, projection, components, rows):
    u = sync.u
    registry = sync.registry(projection)
    poses_by_label, bins = {}, {}
    for label, (_, component) in components.items():
        poses = [component.get_instance_transform(i, world_space=True) for i in range(component.get_instance_count())]
        buckets = {}
        for index, pose in enumerate(poses):
            cell = tuple(round(value) for value in pose.translation.to_tuple())
            buckets.setdefault(cell, []).append(index)
        poses_by_label[label], bins[label] = poses, buckets
    matched, used = [], {label: set() for label in components}
    for key, row in rows:
        label = 'WVC_' + row['id']
        assert label in components, (key, label)
        actor, component = components[label]
        mesh_path = registry.get(row.get('mesh_id', row['id']))
        if row['id'] == 'BACKING_TX01':
            mesh_path = '/Engine/BasicShapes/Cube'
        mesh = u.load_asset(mesh_path)
        assert mesh and sync.asset(component.static_mesh) == sync.asset(mesh), (key, mesh_path)
        expected_materials = sync.materials(row, mesh)
        assert [sync.asset(m) for m in component.get_materials()] == expected_materials, (key, expected_materials)
        at, rotation, scale = sync.expected_pose(row, PIVOT)
        center = tuple(round(value) for value in at.to_tuple())
        buckets = bins[label]
        candidates = [i for dx in (-1, 0, 1) for dy in (-1, 0, 1) for dz in (-1, 0, 1)
                      for i in buckets.get((center[0] + dx, center[1] + dy, center[2] + dz), ())]
        matches = [i for i in candidates if (poses_by_label[label][i].translation - at).length() < .1
                   and (poses_by_label[label][i].scale3d - scale).length() < .001
                   and poses_by_label[label][i].rotation.angular_distance(rotation) < .001]
        assert len(matches) == 1 and matches[0] not in used[label], ('Source pose unmatched/ambiguous', key, matches)
        index = matches[0]
        used[label].add(index)
        matched.append(dict(source_key=key, label=label, index=index,
                            world_pose=sync.transform(component.get_instance_transform(index, world_space=True))))
    counts = {ident: len(used[TARGET_LABELS[ident]]) for ident in SELECTED}
    assert counts == SELECTED
    return matched, {label: sorted(indices) for label, indices in used.items()}


def _settings(u):
    editor_cls = u.load_class(None, '/Script/UnrealEd.EditorLoadingSavingSettings')
    assert editor_cls
    editor_settings = u.get_default_object(editor_cls)
    autosave = editor_settings.get_editor_property('bAutoSaveEnable')
    assert isinstance(autosave, bool)
    jolt_cls = u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    assert jolt_cls
    jolt_settings = u.get_default_object(jolt_cls)
    cook = jolt_settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    assert hasattr(type(cook), 'DISABLE')
    return editor_settings, autosave, jolt_settings, cook


def _full_exports(wall_material, core, u, world, folder):
    folder = Path(folder)
    _, _, exporter = wall_material._dependencies()
    exposure, = [a for a in u.GameplayStatics.get_all_actors_of_class(world, u.Actor)
                 if a.get_name() == 'PostProcessVolume_0' and a.get_actor_label() == 'WVC_ReviewExposure']
    # ObjectExporterT3D retains native visitation marks on nested UModel objects.
    # Prime this one known actor consistently, and preserve its geometry through
    # an independent ModelExporterT3D export rather than dropping brush text.
    exporter._export(u, exposure, folder / 'exposure_prime.t3d')
    model = u.find_object(exposure, 'Model_1')
    assert model and model.get_outer() == exposure and model.get_class().get_name() == 'Model'
    model_path = folder / 'exposure_brush_geometry.t3d'
    assert not model_path.exists()
    task = u.AssetExportTask()
    for key, value in dict(object=model, exporter=u.ModelExporterT3D(), filename=str(model_path),
            automated=True, prompt=False, selected=False, replace_identical=False,
            use_file_archive=False, write_empty_files=False).items():
        task.set_editor_property(key, value)
    assert u.Exporter.run_asset_export_task(task) and not list(task.errors)
    assert model_path.read_text().count('Begin Polygon') == 6
    assert _sha(model_path) == EXPOSURE_BRUSH_SHA256
    brush_geometry = dict(path=model.get_path_name(), type=model.get_class().get_path_name(),
                          export_sha256=_sha(model_path), polygon_count=6)
    result = {}
    for actor in u.GameplayStatics.get_all_actors_of_class(world, u.Actor):
        assert actor.get_world() == world and actor.get_level().get_outer() == world
        actor_name = actor.get_name()
        assert actor_name not in result
        components = {}
        for component in actor.get_components_by_class(u.ActorComponent):
            component_name = component.get_name()
            assert component_name not in components
            components[component_name] = dict(type=component.get_class().get_path_name(),
                export=exporter._export(u, component,
                    folder / (actor_name + '__' + component_name + '.t3d')))
            if isinstance(component, u.HierarchicalInstancedStaticMeshComponent):
                components[component_name]['hism'] = core._component(component)
        result[actor_name] = dict(label=actor.get_actor_label(), type=actor.get_class().get_path_name(),
            tags=sorted(str(tag) for tag in actor.tags), pose=core._pose(actor.get_actor_transform()),
            hidden=bool(actor.get_editor_property('hidden')),
            export=exporter._export(u, actor, folder / (actor_name + '.t3d')),
            components=components)
        if actor == exposure:
            result[actor_name]['brush_geometry'] = brush_geometry
    return result


def _exporter(wall_material):
    _, _, persistent = wall_material._dependencies()
    assert callable(persistent._export)
    return persistent


def _export_projection(roster):
    result = {}
    for actor_name, actor in roster.items():
        result[actor_name] = {key: copy.deepcopy(value) for key, value in actor.items()
                              if key not in ('export', 'components')}
        result[actor_name]['export_sha256'] = actor['export']['sha256']
        result[actor_name]['components'] = {}
        for name, component in actor['components'].items():
            projected = {key: copy.deepcopy(value) for key, value in component.items() if key != 'export'}
            projected['export_sha256'] = component['export']['sha256']
            result[actor_name]['components'][name] = projected
    return result


def _pose_multiset(poses):
    result = {}
    for pose in poses:
        key = json.dumps(pose, sort_keys=True, separators=(',', ':'), allow_nan=False)
        result[key] = result.get(key, 0) + 1
    return result


def _file_guard_rows(expected):
    return dict(sorted(expected.items()))


def preflight(library_promotion_file=None, library_promotion_sha256=None):
    """Read-only exact-pose preflight; writes one immutable receipt."""
    data, sync, libraries, wall_material, core = _deps()
    projection, selected_rows, source_material_receipt = _contract(data, sync, libraries)
    expected_guards, collision, promotion = _baseline_guards(library_promotion_file, library_promotion_sha256)
    world = _context(sync)
    components = _target_components(sync, world, projection)
    matched, used = _match_rows(sync, projection, components, selected_rows)
    roster = sync.roster(False)
    assert sum(len(c.get('instances', [])) for a in roster.values() for c in a['components'].values()) == 32646
    source_contracts = {label: core._component(component) for label, (_, component) in components.items()}
    material = sync.u.load_asset(MATERIAL)
    assert material and sync.asset(material) == MATERIAL
    assert sync.u.EditorAssetLibrary.get_metadata_tag(material, MATERIAL_TAG) == MATERIAL_OWNER
    assert _context(sync) == world and sync.roster(False) == roster
    _guards(expected_guards)
    _collision_exact(collision)
    token = uuid.uuid4().hex
    full_exports = _full_exports(wall_material, core, sync.u, world,
                                 CHECKPOINT / token / 'preflight_t3d')
    report = dict(status='PREFLIGHT_REVIEW_REQUIRED', map=MAP, map_sha256=MAP_SHA256,
        source_ossuary_map=OSSUARY_MAP, source_ossuary_map_sha256=OSSUARY_MAP_SHA256,
        candidate_material=MATERIAL, candidate_material_sha256=MATERIAL_SHA256, candidate_owner=MATERIAL_OWNER,
        source_material_receipt=str(PERSISTENT_RECEIPT.relative_to(ROOT)),
        source_material_receipt_sha256=_sha(PERSISTENT_RECEIPT),
        source_material_receipt_status=source_material_receipt['status'],
        source_effective_placements=len(projection['effective']), selected_wall_rows=1194,
        selected_counts=SELECTED, original_actor_roster=roster, source_component_contracts=source_contracts,
        full_actor_component_exports_projection=_export_projection(full_exports),
        selected_rows=matched, selected_indices=used, total_instances_before=32646,
        library_promotion=promotion,
        library_promotion_file=None if promotion is None else promotion['file'],
        library_promotion_sha256=None if promotion is None else promotion['sha256'],
        immutable_guards=_file_guard_rows(expected_guards), collision_hashes=collision,
        input_hashes={str(path.relative_to(ROOT).as_posix()): _sha(path) for path in
            (Path(__file__), DATA_TOOL, UE_TOOL, WALL_LIBRARY_TOOL, WALL_MATERIAL_TOOL, CORE_TOOL, FIT,
             BASELINE, COLLISION, MATERIAL_FILE, PERSISTENT_RECEIPT, LIBRARY_VERIFY)},
        boundary='Read-only preflight. No actors or packages were changed; apply requires review of this exact receipt SHA.')
    written = _write('preflight', token, report)
    return dict(status=report['status'], **written, selected=1194, total_instances=32646)


def _load_preflight(file, expected_sha):
    path = (ROOT / file).resolve()
    assert path.is_relative_to(CHECKPOINT.resolve()) and path.name == 'preflight.json'
    assert _sha(path) == expected_sha
    report = _json(path)
    assert report['status'] == 'PREFLIGHT_REVIEW_REQUIRED' and report['map_sha256'] == MAP_SHA256
    assert report['tool_sha256'] == _sha(__file__)
    return path, report


def _new_group(sync, wall_material, world, source, indices, material, label, export_folder):
    u = sync.u
    exporter = _exporter(wall_material)
    actor = sync.EA.spawn_actor_from_class(u.Actor, u.Vector(), u.Rotator())
    assert actor and actor.get_world() == world and actor.get_level().get_outer() == world
    actor.set_actor_label(label)
    actor.tags = [u.Name(TAG)]
    actor.set_folder_path(FOLDER)
    assert actor.root_component
    actor.root_component.set_mobility(source.get_editor_property('mobility'))
    native_components = {}
    for native in actor.get_components_by_class(u.ActorComponent):
        name = native.get_name()
        assert name not in native_components
        native_components[name] = dict(type=native.get_class().get_path_name(),
            export=exporter._export(u, native,
                Path(export_folder) / ('native_before_' + label + '__' + name + '.t3d')))
    assert actor.root_component.get_name() in native_components
    assert sum('BillboardComponent' in record['type'] for record in native_components.values()) == 1, \
        ('Unexpected spawned-actor billboard inventory', native_components)
    assert not actor.get_components_by_class(u.StaticMeshComponent)
    ss = u.get_engine_subsystem(u.SubobjectDataSubsystem)
    root_handle = ss.k2_gather_subobject_data_for_instance(actor)[0]
    handle, reason = ss.add_new_subobject(u.AddNewSubobjectParams(parent_handle=root_handle,
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
    for slot, existing in enumerate(source.get_materials()):
        component.set_material(slot, material if slot == 0 else existing)
    component.set_visibility(source.is_visible(), False)
    transforms = [source.get_instance_transform(index, world_space=False) for index in indices]
    assert len(transforms) == SELECTED[source.get_owner().get_actor_label().removeprefix('WVC_')]
    assert list(component.add_instances(transforms, True, False, False)) == list(range(len(indices)))
    return actor, component, native_components


def _expected_after(before, selection):
    expected = copy.deepcopy(before)
    for label in TARGET_LABELS.values():
        _, actor = next((name, row) for name, row in expected.items() if row['label'] == label)
        component_name, component = next((name, row) for name, row in actor['components'].items()
                                         if 'instances' in row)
        selected_poses = [r['world_pose'] for r in selection if r['label'] == label]
        remaining = list(component['instances'])
        for pose in selected_poses:
            assert pose in remaining, ('Selected source pose missing from original roster', label, pose)
            remaining.remove(pose)
        component['instances'] = remaining
    return expected


def _verify_after(sync, core, before, after, selection, source_contracts, world):
    existing_names = set(before)
    added_names = set(after) - existing_names
    assert len(added_names) == 2
    expected = _expected_after(before, selection)
    by_label = {row['label']: (name, row) for name, row in after.items()}
    for name, old in expected.items():
        new = after[name]
        assert {k: v for k, v in old.items() if k != 'components'} == {
            k: v for k, v in new.items() if k != 'components'}, ('Actor changed', old['label'])
        assert set(old['components']) == set(new['components']), old['label']
        for component_name, old_component in old['components'].items():
            current = new['components'][component_name]
            assert current == old_component, ('Source/unselected component differs from expected post-partition roster',
                                               old['label'], component_name)
    selected = {TARGET_LABELS[ident]: [r for r in selection if r['label'] == TARGET_LABELS[ident]]
                for ident in SELECTED}
    for ident, new_label in NEW_LABELS.items():
        label = TARGET_LABELS[ident]
        _, row = by_label[new_label]
        assert row['type'] == '/Script/Engine.Actor' and row['tags'] == [TAG] and row['hidden'] is False
        assert row['pose'] == core._pose(sync.u.Transform())
        component_names = [k for k, v in row['components'].items() if v.get('instances') is not None]
        assert len(component_names) == 1
        component_name = component_names[0]
        component = row['components'][component_name]
        source_actor_row = next(actor for actor in before.values() if actor['label'] == label)
        expected_component = copy.deepcopy(next(value for value in source_actor_row['components'].values()
                                                if 'instances' in value))
        expected_component['materials'] = [MATERIAL] + expected_component['materials'][1:]
        expected_component['instances'] = sync.ordered([r['world_pose'] for r in selected[label]])
        assert component == expected_component, ('New group roster differs from source settings/approved selection', new_label)
        assert row['components'][component_name]['collision'] == 'NoCollision'
        new_actor = next(a for a in sync.u.GameplayStatics.get_all_actors_of_class(world, sync.u.Actor)
                         if a.get_actor_label() == new_label)
        actual_component = new_actor.get_components_by_class(sync.u.HierarchicalInstancedStaticMeshComponent)
        assert len(actual_component) == 1
        expected_core = copy.deepcopy(source_contracts[label])
        expected_core.update(path=actual_component[0].get_path_name(),
            owner=new_actor.get_path_name(), owner_label=new_label,
            level=new_actor.get_level().get_path_name(),
            materials=[MATERIAL] + expected_core['materials'][1:],
            instances=[source_contracts[label]['instances'][r['index']]
                       for r in sorted(selected[label], key=lambda x: x['index'])])
        assert core._component(actual_component[0]) == expected_core
        source_actor = next(a for a in sync.u.GameplayStatics.get_all_actors_of_class(world, sync.u.Actor)
                            if a.get_actor_label() == label)
        original_hism, = source_actor.get_components_by_class(sync.u.HierarchicalInstancedStaticMeshComponent)
        expected_source = copy.deepcopy(source_contracts[label])
        selected_indices = {record['index'] for record in selected[label]}
        expected_source['instances'] = [pose for i, pose in enumerate(expected_source['instances'])
                                        if i not in selected_indices]
        actual_source = core._component(original_hism)
        expected_pose_set = _pose_multiset(expected_source.pop('instances'))
        actual_pose_set = _pose_multiset(actual_source.pop('instances'))
        assert actual_pose_set == expected_pose_set
        assert actual_source == expected_source
    assert sum(len(c.get('instances', [])) for a in after.values() for c in a['components'].values()) == 32646
    assert sum(row['label'] in NEW_LABELS.values() for row in after.values()) == 2
    for name in added_names:
        assert after[name]['label'] in NEW_LABELS.values()
        expected[name] = copy.deepcopy(after[name])
    assert expected == after
    return expected


def apply(preflight_file, preflight_sha256):
    """Partition the approved 1,194 rows and save only the open Diorama map."""
    global STATE
    assert STATE is None, 'A dirty failure awaits manual checkpoint recovery'
    path, old = _load_preflight(preflight_file, preflight_sha256)
    data, sync, libraries, wall_material, core = _deps()
    projection, selected_rows, _ = _contract(data, sync, libraries)
    expected_guards, collision, promotion = _baseline_guards(
        old.get('library_promotion_file'), old.get('library_promotion_sha256'))
    assert old.get('library_promotion') == promotion
    assert old['immutable_guards'] == expected_guards and old['collision_hashes'] == collision
    world = _context(sync)
    assert sync.roster(False) == old['original_actor_roster']
    components = _target_components(sync, world, projection)
    selection, indices_by_label = _match_rows(sync, projection, components, selected_rows)
    assert selection == old['selected_rows'] and indices_by_label == old['selected_indices']
    before = sync.roster(False)
    before_exports = _full_exports(wall_material, core, sync.u, world, path.parent / 'apply_before_t3d')
    assert _export_projection(before_exports) == old['full_actor_component_exports_projection']
    source_contracts = {label: core._component(component) for label, (_, component) in components.items()}
    assert source_contracts == old['source_component_contracts']
    material = sync.u.load_asset(MATERIAL)
    assert material and sync.asset(material) == MATERIAL
    assert sync.u.EditorAssetLibrary.get_metadata_tag(material, MATERIAL_TAG) == MATERIAL_OWNER
    assert _guards(expected_guards) and _sha(MAP_FILE) == MAP_SHA256
    assert not sync.u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
    assert not sync.u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
    token = old['token']
    folder = path.parent
    backup = folder / 'Diorama.before.umap'
    assert not backup.exists()
    shutil.copy2(MAP_FILE, backup)
    assert _sha(backup) == MAP_SHA256
    checkpoint = _write('checkpoint', token, dict(status='CHECKPOINTED_BEFORE_MUTATION',
        preflight_file=str(path.relative_to(ROOT).as_posix()), preflight_sha256=preflight_sha256,
        map_before=MAP_SHA256, map_backup=str(backup.relative_to(ROOT).as_posix()), map_backup_sha256=_sha(backup),
        guards=expected_guards, collision_hashes=collision, library_promotion=promotion,
        rollback='If the map becomes dirty and save verification fails, do not save again. Keep both settings disabled; close/reload the exact Diorama backup manually, verify clean state and guards, then explicitly restore the prior settings.'))
    editor_settings, autosave_before, jolt_settings, cook_before = _settings(sync.u)
    changed = False
    save_verified = False
    actors_created = {}
    native_components = {}
    try:
        editor_settings.set_editor_property('bAutoSaveEnable', False)
        jolt_settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(cook_before).DISABLE)
        assert editor_settings.get_editor_property('bAutoSaveEnable') is False
        assert jolt_settings.get_editor_property('_AutoCookStaticWorldOnLevelSave') == type(cook_before).DISABLE
        for label, indices in old['selected_indices'].items():
            actor, component = components[label]
            changed = True
            new_label = NEW_LABELS[label.removeprefix('WVC_')]
            new_actor, _, native_components[label] = _new_group(sync, wall_material, world, component,
                indices, material, new_label, path.parent / 'created_native_t3d')
            actors_created[label] = new_actor
            assert new_actor.get_actor_label() == new_label
            component.modify()
            for index in sorted(indices, reverse=True):
                assert component.remove_instance(index)
        after = sync.roster(False)
        expected_after = _verify_after(sync, core, before, after, old['selected_rows'], source_contracts, world)
        after_exports = _full_exports(wall_material, core, sync.u, world, path.parent / 'apply_after_t3d')
        assert set(after_exports) == set(before_exports) | {actor.get_name() for actor in actors_created.values()}
        for actor_name, old_export in before_exports.items():
            new_export = after_exports[actor_name]
            assert new_export.get('brush_geometry') == old_export.get('brush_geometry')
            assert (old_export['label'], old_export['type'], old_export['tags'], old_export['pose'], old_export['hidden']) == (
                new_export['label'], new_export['type'], new_export['tags'], new_export['pose'], new_export['hidden'])
            assert set(new_export['components']) == set(old_export['components'])
            if old_export['label'] not in TARGET_LABELS.values():
                assert new_export['export']['sha256'] == old_export['export']['sha256'], (
                    'Unrelated actor T3D changed', old_export['label'])
            for component_name, old_component in old_export['components'].items():
                new_component = new_export['components'][component_name]
                if old_export['label'] in TARGET_LABELS.values() and old_component.get('hism') is not None:
                    continue
                assert new_component['export']['sha256'] == old_component['export']['sha256'], (
                    'Unchanged component T3D changed', old_export['label'], component_name)
        for label, actor in actors_created.items():
            exported = after_exports[actor.get_name()]
            assert exported['label'] == NEW_LABELS[label.removeprefix('WVC_')]
            native = native_components[label]
            assert actor.root_component.get_name() in native
            assert sum('BillboardComponent' in record['type'] for record in native.values()) == 1
            hism_names = [name for name, record in exported['components'].items() if record.get('hism') is not None]
            assert len(hism_names) == 1 and set(exported['components']) == set(native) | set(hism_names)
            for name, before_native in native.items():
                current = exported['components'][name]
                assert current['type'] == before_native['type']
                assert current['export']['sha256'] == before_native['export']['sha256']
        _collision_exact(collision)
        assert _guards(expected_guards) and _sha(MAP_FILE) == MAP_SHA256
        dirty_maps = sorted(sync.asset(x) for x in sync.u.EditorLoadingAndSavingUtils.get_dirty_map_packages())
        dirty_content = sorted(sync.asset(x) for x in sync.u.EditorLoadingAndSavingUtils.get_dirty_content_packages())
        assert dirty_maps == [MAP] and dirty_content == [], (dirty_maps, dirty_content)
        assert sync.u.get_editor_subsystem(sync.u.LevelEditorSubsystem).save_current_level()
        assert not sync.u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
        assert not sync.u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
        assert _guards(expected_guards, map_sha=_sha(MAP_FILE))
        assert _sha(MAP_FILE) != MAP_SHA256
        _collision_exact(collision)
        editor_settings.set_editor_property('bAutoSaveEnable', autosave_before)
        jolt_settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', cook_before)
        assert editor_settings.get_editor_property('bAutoSaveEnable') == autosave_before
        assert jolt_settings.get_editor_property('_AutoCookStaticWorldOnLevelSave') == cook_before
        save_verified = True
        out = _write('applied', token, dict(status='SAVED_RELOAD_AUDIT_REQUIRED',
            map=MAP, map_before=MAP_SHA256, map_after=_sha(MAP_FILE), map_backup=str(backup.relative_to(ROOT).as_posix()),
            map_backup_sha256=_sha(backup), checkpoint_file=checkpoint['file'], checkpoint_sha256=checkpoint['sha256'],
            preflight_file=str(path.relative_to(ROOT).as_posix()), preflight_sha256=preflight_sha256,
            library_promotion=promotion,
            selected_wall_rows=1194, selected_counts=SELECTED, total_instances_before=32646,
            total_instances_after=32646, source_roster_before=before, expected_roster_after=expected_after,
            observed_roster_after=after, full_actor_component_exports_after=_export_projection(after_exports),
            native_components_before_hism=native_components, new_actor_names=[a.get_name() for a in actors_created.values()],
            new_actor_labels=sorted(NEW_LABELS.values()), immutable_guards_after=_guards(expected_guards, map_sha=_sha(MAP_FILE)),
            collision_hashes_before=collision, collision_hashes_after=_json(COLLISION),
            prior_settings=dict(auto_save=autosave_before, auto_cook=str(cook_before)),
            settings_restored=True, only_diorama_map_saved=True,
            boundary='Saved source Diorama only. Unload/reload audit and runtime/gameplay behavior remain separate.'))
        return dict(status='SAVED_RELOAD_AUDIT_REQUIRED', **out, map_after=_sha(MAP_FILE))
    except Exception as exc:
        if changed:
            STATE = dict(editor_settings=editor_settings, autosave=autosave_before,
                         jolt_settings=jolt_settings, cook=cook_before, map_before=MAP_SHA256,
                         backup=str(backup.relative_to(ROOT).as_posix()), token=token,
                         library_promotion_file=old.get('library_promotion_file'),
                         library_promotion_sha256=old.get('library_promotion_sha256'))
        else:
            editor_settings.set_editor_property('bAutoSaveEnable', autosave_before)
            jolt_settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', cook_before)
        _write('failure', token, dict(status='FAILED_REVIEW_REQUIRED', error=type(exc).__name__ + ': ' + str(exc),
            map_sha256_now=_sha(MAP_FILE), dirty='inspect in editor',
            created_actor_names=[a.get_name() for a in actors_created.values()], settings_restored=not changed,
            checkpoint_file=checkpoint['file'], checkpoint_sha256=checkpoint['sha256'],
            action='Do not save again. If the map is dirty, keep autosave/autocook disabled; manually restore the exact checkpoint, verify clean state and all guards, then call restore_settings_after_manual_recovery().'))
        raise
    finally:
        if not changed or save_verified:
            editor_settings.set_editor_property('bAutoSaveEnable', autosave_before)
            jolt_settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', cook_before)
            if save_verified:
                STATE = None


def restore_settings_after_manual_recovery():
    """Restore temporary CDO settings only after the map backup is restored and clean."""
    global STATE
    assert STATE is not None, 'No dirty failure is awaiting recovery'
    data, sync, libraries, wall_material, core = _deps()
    world = _context(sync)
    assert _sha(MAP_FILE) == STATE['map_before']
    expected, collision, _ = _baseline_guards(STATE.get('library_promotion_file'),
                                                STATE.get('library_promotion_sha256'))
    _guards(expected)
    _collision_exact(collision)
    STATE['editor_settings'].set_editor_property('bAutoSaveEnable', STATE['autosave'])
    STATE['jolt_settings'].set_editor_property('_AutoCookStaticWorldOnLevelSave', STATE['cook'])
    STATE = None
    return dict(status='SETTINGS_RESTORED_AFTER_MANUAL_MAP_RECOVERY', world=world.get_path_name())


def note_unloaded(applied_file, applied_sha256):
    path = (ROOT / applied_file).resolve()
    assert path.is_relative_to(CHECKPOINT.resolve()) and path.name == 'applied.json' and _sha(path) == applied_sha256
    applied = _json(path)
    assert applied['status'] == 'SAVED_RELOAD_AUDIT_REQUIRED'
    data, sync, libraries, wall_material, core = _deps()
    sync.context('KitLibrary')
    world = sync.ED.get_editor_world()
    assert world.get_path_name().split('.')[0] != MAP and sync.u.find_object(None, MAP) is None
    assert _guards(applied['immutable_guards_after'], map_sha=applied['map_after'])
    _collision_exact(applied['collision_hashes_after'])
    out = _write('unloaded', path.parent.name, dict(status='UNLOADED_OBSERVED',
        applied_file=str(path.relative_to(ROOT).as_posix()), applied_sha256=applied_sha256,
        map_after=applied['map_after'], opened_world=world.get_path_name(), target_world_absent=True,
        immutable_guards=applied['immutable_guards_after']))
    return dict(status='UNLOADED_OBSERVED', **out)


def audit(applied_file, applied_sha256, unloaded_file, unloaded_sha256):
    path = (ROOT / applied_file).resolve()
    assert path.is_relative_to(CHECKPOINT.resolve()) and path.name == 'applied.json' and _sha(path) == applied_sha256
    applied = _json(path)
    unload_path = (ROOT / unloaded_file).resolve()
    assert unload_path.is_relative_to(CHECKPOINT.resolve()) and unload_path.name == 'unloaded.json'
    assert _sha(unload_path) == unloaded_sha256
    unloaded = _json(unload_path)
    assert applied['status'] == 'SAVED_RELOAD_AUDIT_REQUIRED'
    assert unloaded['status'] == 'UNLOADED_OBSERVED' and unloaded['applied_sha256'] == applied_sha256
    assert unloaded['map_after'] == applied['map_after'] and unloaded['target_world_absent'] is True
    data, sync, libraries, wall_material, core = _deps()
    world = _context(sync)
    assert sync.u.find_object(None, MAP) is not None and _sha(MAP_FILE) == applied['map_after']
    assert _guards(applied['immutable_guards_after'], map_sha=applied['map_after'])
    observed = sync.roster(False)
    assert observed == applied['expected_roster_after'] == applied['observed_roster_after']
    assert sum(len(c.get('instances', [])) for a in observed.values() for c in a['components'].values()) == 32646
    exports = _full_exports(wall_material, core, sync.u, world, path.parent / 'audit_t3d')
    assert _export_projection(exports) == applied['full_actor_component_exports_after']
    _collision_exact(applied['collision_hashes_after'])
    new_labels = [row['label'] for row in observed.values() if row['label'] in NEW_LABELS.values()]
    assert sorted(new_labels) == sorted(NEW_LABELS.values())
    out = _write('audit', path.parent.name, dict(status='RELOAD_AUDITED', applied_file=str(path.relative_to(ROOT).as_posix()),
        applied_sha256=applied_sha256, unloaded_file=str(unload_path.relative_to(ROOT).as_posix()),
        unloaded_sha256=unloaded_sha256, map_sha256=_sha(MAP_FILE), actor_component_roster=observed,
        full_actor_component_exports=_export_projection(exports),
        total_instances=32646, new_actor_labels=sorted(new_labels), immutable_guards=applied['immutable_guards_after'],
        boundary='Source Diorama roster and saved-map reload verified; runtime lighting and gameplay are not exercised.'))
    return dict(status='RELOAD_AUDITED', **out, world=world.get_path_name())
