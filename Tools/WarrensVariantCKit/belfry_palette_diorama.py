"""Checkpointed Belfry palette partition for the static Unreal Diorama only.

Importing this module is inert. Run preflight() in the open, clean Diorama map;
review its immutable receipt before calling apply(). After apply(), switch to a
clean KitLibrary map and call note_unloaded(), then reopen Diorama and call
audit(). The KitLibrary, gameplay Level Instances, source ledgers, meshes,
collision and materials are read-only inputs.
"""
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import runpy
import shutil
import uuid

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RUN = ROOT / 'Saved/WarrensCGameplay-20261024/BelfryDioramaPaletteCheckpoint'
MAP_NAME = 'Diorama'
MAP = '/Game/Mars/Environment/WarrensVariantCKit/Maps/WarrensVariantC_Diorama_Mars_MAP'
MAP_FILE = ROOT / ('Content/' + MAP.removeprefix('/Game/') + '.umap')
INITIAL_MAP_SHA = '54893400ca58615414ac54e7a518aa889b8322b4a83f502d25cfdfb6a32f5ea3'
SYNC_RECEIPT = ROOT / 'Saved/WarrensCGameplay-20261024/ArtLibrarySyncCheckpoint/unreal-v2/Diorama.json'
ART_RECEIPT = ROOT / 'Saved/WarrensCGameplay-20261024/ArtCheckpoint/applied_Diorama.json'
MATERIAL_RECOVERY = ROOT / 'Saved/WarrensCGameplay-20261024/BelfryPaletteCheckpoint/20261025_061823_dd1577b8/recovery.json'
MATERIAL_RECOVERY_SHA = 'ed1afe693e86e73e8cb925bdcb01432757b5f2b6dc6ddbb287e2a760c6c0dda2'
OWNER = 'Mars.WarrensC.BelfryDioramaPalette.v1'
DELTA = HERE / 'belfry_palette_delta.json'
DELTA_SHA = '8fa05e25ded0ac2092d8b625d1ade54f466bf5ac66a8aa96b9ef58593ef32d4a'
PIVOT = (58, 55, 0)
EXPECTED_COUNTS = {
    'WVC_BACKING_TX01': (9006, 590),
    'WVC_BACKING_TX02': (6286, 464),
    'WVC_CCS06': (20, 20),
    'WVC_CCS09': (114, 14),
    'WVC_CCS13': (6286, 464),
    'WVC_CCS15': (9006, 590),
    'WVC_WVC018': (2, 2),
}
PARTITION_LABELS = {
    'WVC_BACKING_TX01': 'WVC_BelfryPaletteDiorama_Back_Tx01',
    'WVC_BACKING_TX02': 'WVC_BelfryPaletteDiorama_Back_Tx02',
    'WVC_CCS09': 'WVC_BelfryPaletteDiorama_CCS09',
    'WVC_CCS13': 'WVC_BelfryPaletteDiorama_CCS13',
    'WVC_CCS15': 'WVC_BelfryPaletteDiorama_CCS15',
}
WHOLE_GROUPS = {'WVC_CCS06', 'WVC_WVC018'}


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def _read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _package(value):
    return value.get_path_name().split('.')[0]


def _write_new(path, value):
    path = Path(path).resolve()
    assert path.is_relative_to(RUN.resolve()) and not path.exists(), 'Receipts are immutable; choose a fresh token'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n', encoding='utf-8')
    return path


def _sync():
    spec = importlib.util.spec_from_file_location('wvc_diorama_palette_sync', HERE / 'sync_art_libraries_unreal.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _persistent():
    return runpy.run_path(str(HERE / 'belfry_palette_persistent.py'))


def _contract(sync, persistent):
    assert _sha(DELTA) == DELTA_SHA
    delta = persistent['contract']()
    assert delta['selected_count'] == 2144 and len(delta['bindings']) == 2144
    assert _sha(MAP_FILE) == INITIAL_MAP_SHA
    applied = _read(SYNC_RECEIPT)
    assert applied['status'] == 'APPLIED' and applied['after_sha256'] == INITIAL_MAP_SHA
    assert len(applied['sync_roster']) > 0
    assert sync.data.sha(sync.disk(MAP_NAME)) == INITIAL_MAP_SHA
    stage = sync.preflight(MAP_NAME)
    assert stage['already_applied'] and stage['package_sha256'] == INITIAL_MAP_SHA
    return delta, applied


def _guards(sync):
    """Hash all reviewed source maps/assets; only this Diorama .umap is mutable."""
    guards = sync.data.immutable_files()
    guards.pop(MAP_FILE.relative_to(ROOT).as_posix(), None)
    # Every other content map is protected, including the KitLibrary and all
    # gameplay maps. This also catches an unexpected newly-added map.
    for path in (ROOT / 'Content').rglob('*.umap'):
        relative = path.relative_to(ROOT).as_posix()
        if path.resolve() != MAP_FILE.resolve():
            guards[relative] = _sha(path)
    # Protect the complete material sets that feed the fitted Diorama, including
    # the two already-saved, graph-reviewed Belfry materials.
    for kit in ('ChainCrossingKit', 'PumpCisternKit', 'WarrensVariantCKit'):
        folder = ROOT / 'Content/Mars/Environment' / kit / 'Materials'
        for path in folder.rglob('*.uasset'):
            guards[path.relative_to(ROOT).as_posix()] = _sha(path)
    guards[DELTA.relative_to(ROOT).as_posix()] = _sha(DELTA)
    guards[SYNC_RECEIPT.relative_to(ROOT).as_posix()] = _sha(SYNC_RECEIPT)
    guards[ART_RECEIPT.relative_to(ROOT).as_posix()] = _sha(ART_RECEIPT)
    guards[Path(__file__).relative_to(ROOT).as_posix()] = _sha(__file__)
    guards[MATERIAL_RECOVERY.relative_to(ROOT).as_posix()] = _sha(MATERIAL_RECOVERY)
    collision_file = ROOT / 'Saved/WarrensCGameplay-20261024/StartupCheckpoint/collision_hashes.json'
    guards[collision_file.relative_to(ROOT).as_posix()] = _sha(collision_file)
    manifests = [sync.data.read(HERE.parent / kit / 'Output/asset_manifest.json')
                 for kit in ('ChainCrossingKit', 'PumpCisternKit', 'WarrensVariantCKit')]
    assert sum(len(manifest['assets']) for manifest in manifests) == 196
    p2_manifest = sync.data.read(HERE / 'P2SlidingSpan/Output/asset_manifest.json')
    assert len(p2_manifest['assets']) == 3
    assert len(sync.data.read(collision_file)) == 54
    return dict(sorted(guards.items()))


def _selected(sync, delta, world):
    u = sync.u
    actors_by_label = defaultdict(list)
    actors = u.GameplayStatics.get_all_actors_of_class(world, u.Actor)
    assert all(OWNER not in sync.tags(actor) for actor in actors)
    assert not any(actor.get_actor_label() in PARTITION_LABELS.values() for actor in actors)
    for actor in actors:
        actors_by_label[actor.get_actor_label()].append(actor)
    components = {}
    for label, (total, _) in EXPECTED_COUNTS.items():
        actor, = actors_by_label[label]
        assert actor.get_world() == world and actor.get_level().get_outer() == world
        component, = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        assert component.get_instance_count() == total
        assert str(component.get_collision_profile_name()) == 'NoCollision'
        assert not component.get_editor_property('generate_overlap_events')
        components[label] = (actor, component)

    pose_bins = {}
    for label, (_, component) in components.items():
        buckets = defaultdict(list)
        poses = [component.get_instance_transform(i, world_space=True)
                 for i in range(component.get_instance_count())]
        for index, pose in enumerate(poses):
            cell = tuple(round(value) for value in pose.translation.to_tuple())
            buckets[cell].append(index)
        pose_bins[label] = (buckets, poses)

    selected, used = [], defaultdict(set)
    target_for_label = {}
    for binding in delta['bindings']:
        label = binding['original_actor_label']
        assert label in EXPECTED_COUNTS
        actor, component = components[label]
        assert sync.asset(component.static_mesh) == binding['mesh_path']
        key = binding['slots'][0]['source_material_key']
        assert key in ('TX01', 'TX02') and binding['slots'][0]['target_material_path'] == delta['materials'][key]['target_asset']
        assert binding['source_material_keys'][0] == key
        at, rotation, scale = sync.expected_pose(binding['source_row'], PIVOT)
        center = tuple(round(value) for value in at.to_tuple())
        buckets, poses = pose_bins[label]
        candidates = [index for dx in (-1, 0, 1) for dy in (-1, 0, 1) for dz in (-1, 0, 1)
                      for index in buckets.get((center[0] + dx, center[1] + dy, center[2] + dz), ())]
        matches = [index for index in candidates
                   if (poses[index].translation - at).length() < .1
                   and (poses[index].scale3d - scale).length() < .001
                   and poses[index].rotation.angular_distance(rotation) < .001]
        assert len(matches) == 1 and matches[0] not in used[label], (binding['source_key'], label, matches)
        index = matches[0]
        used[label].add(index)
        if label in target_for_label:
            assert target_for_label[label] == key
        target_for_label[label] = key
        selected.append(dict(source_key=binding['source_key'], label=label, index=index, key=key,
            target=delta['materials'][key]['target_asset'], row_sha256=binding['source_row_sha256'],
            world_pose=sync.transform(component.get_instance_transform(index, world_space=True))))

    selected_counts = {label: len(indices) for label, indices in used.items()}
    for label, (expected_total, expected_selected) in EXPECTED_COUNTS.items():
        assert components[label][1].get_instance_count() == expected_total
        assert selected_counts.get(label, 0) == expected_selected, (label, selected_counts.get(label, 0))
    assert len(selected) == len({r['source_key'] for r in selected}) == 2144
    assert set(target_for_label) == set(EXPECTED_COUNTS)
    assert set(target_for_label) == WHOLE_GROUPS | set(PARTITION_LABELS)
    assert len(PARTITION_LABELS) == 5 and len(WHOLE_GROUPS) == 2
    # The two-material source group must preserve its nonzero slot exactly.
    _, multi = components['WVC_WVC018']
    actual_slots = [sync.asset(m) for m in multi.get_materials()]
    assert len(actual_slots) == 2 and actual_slots[1].endswith('/M_CCK_TX10')
    for label, (_, component) in components.items():
        key = target_for_label[label]
        materials = [sync.asset(m) for m in component.get_materials()]
        assert materials and materials[0] == '/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_' + key
    return components, selected, target_for_label, used


def _component_contract(persistent, component):
    record = persistent['_base']()['_component'](component)
    record.pop('path')
    record.pop('instances')
    return record


def _component_contracts(sync, persistent, world, labels):
    actors = defaultdict(list)
    for actor in sync.u.GameplayStatics.get_all_actors_of_class(world, sync.u.Actor):
        actors[actor.get_actor_label()].append(actor)
    result = {}
    for label in labels:
        actor, = actors[label]
        component, = actor.get_components_by_class(sync.u.HierarchicalInstancedStaticMeshComponent)
        result[label] = _component_contract(persistent, component)
    return result


def _total_instances(roster):
    return sum(len(component.get('instances', [])) for actor in roster.values()
               for component in actor['components'].values())


def _material_preflight(persistent, delta, folder):
    u, b = persistent['_u'](), persistent['_base']()
    recovery = persistent['_recovery'](str(MATERIAL_RECOVERY.relative_to(ROOT)), MATERIAL_RECOVERY_SHA)
    observed = {}
    for key, spec in sorted(delta['materials'].items()):
        path = ROOT / ('Content/' + spec['target_asset'].removeprefix('/Game/') + '.uasset')
        assert path.is_file()
        material_record = recovery['materials'][key]
        assert material_record['asset'] == spec['target_asset'] and _sha(path) == material_record['sha256']
        material = u.load_asset(spec['target_asset'])
        assert material and b['package'](material) == spec['target_asset']
        expected_metadata = dict(Owner=persistent['OWNER'], DeltaSHA256=persistent['DELTA_SHA'],
            SourceSHA256=spec['source_asset_sha256'])
        metadata = {name: u.EditorAssetLibrary.get_metadata_tag(material, name) for name in expected_metadata}
        assert metadata == expected_metadata
        graph = persistent['_material_check'](u, b, material, key, folder / 'materials', True)
        observed[key] = dict(asset=spec['target_asset'], asset_sha256=_sha(path),
            metadata=metadata, recovery_record=material_record, graph=graph)
    return observed


def preflight():
    """Read-only live inspection; writes one immutable receipt below RUN."""
    sync, persistent = _sync(), _persistent()
    sync.context(MAP_NAME)
    delta, applied = _contract(sync, persistent)
    assert sync.data.sha(sync.disk(MAP_NAME)) == INITIAL_MAP_SHA
    guard = _guards(sync)
    world = sync.ED.get_editor_world()
    components, selected, targets, used = _selected(sync, delta, world)
    roster = sync.roster(False)
    assert _total_instances(roster) == 32646
    assert set(applied['sync_roster']).issubset(roster)
    details = _component_contracts(sync, persistent, world, EXPECTED_COUNTS)
    token = datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S_%f') + '_' + uuid.uuid4().hex[:8]
    folder = RUN / token
    materials = _material_preflight(persistent, delta, folder)
    assert sync.roster(False) == roster and _guards(sync) == guard
    sync.context(MAP_NAME)
    selection = dict(records=selected, by_label={k: sorted(v) for k, v in sorted(used.items())},
        targets=targets, source_component_paths={k: c.get_path_name() for k, (_, c) in components.items()})
    report = dict(schema=1, status='DIORAMA_PREFLIGHT_REVIEW_REQUIRED', token=token,
        map=MAP, map_sha256=INITIAL_MAP_SHA, sync_receipt=str(SYNC_RECEIPT.relative_to(ROOT)),
        sync_receipt_sha256=_sha(SYNC_RECEIPT), delta=str(DELTA.relative_to(ROOT)), delta_sha256=DELTA_SHA,
        source_ledger_sha256=delta['source_ledger_sha256'], selection_sha256=delta['selection_sha256'],
        script_sha256=_sha(__file__), guards=guard, total_instances_before=32646,
        actors_and_components=roster, selection=selection, materials=materials,
        source_component_contracts=details,
        operation=dict(selected=2144, rebind_whole_groups=sorted(WHOLE_GROUPS),
            split_partial_groups=sorted(PARTITION_LABELS), new_hisms=5, instance_total_after=32646,
            preserved_slot='WVC_WVC018 material slot 1 remains M_CCK_TX10',
            collision='Copy source component settings; no collision or instance-pose edits'),
        review_boundary='Offline/editor-read-only preflight only. Apply requires explicit review of this exact receipt SHA.')
    path = _write_new(folder / 'preflight.json', report)
    return dict(file=str(path.relative_to(ROOT)), sha256=_sha(path), status=report['status'],
        selected=2144, total_instances=32646, partitions=5, whole_group_rebinds=2)


def _new_group(sync, world, source, indices, material, label):
    u = sync.u
    actor = sync.EA.spawn_actor_from_class(u.Actor, u.Vector(), u.Rotator())
    assert actor and actor.get_world() == world and actor.get_level().get_outer() == world
    actor.set_actor_label(label)
    actor.tags = [u.Name(OWNER)]
    actor.set_folder_path('Warrens/Art/BelfryPalette')
    assert actor.root_component
    actor.root_component.set_mobility(source.get_editor_property('mobility'))
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
    component.set_editor_property('generate_overlap_events', source.get_editor_property('generate_overlap_events'))
    component.set_cast_shadow(source.cast_shadow)
    component.set_hidden_in_game(source.get_editor_property('hidden_in_game'), False)
    component.set_editor_property('instancing_random_seed', source.get_editor_property('instancing_random_seed'))
    component.set_cull_distances(source.get_editor_property('instance_start_cull_distance'),
        source.get_editor_property('instance_end_cull_distance'))
    for slot, original in enumerate(source.get_materials()):
        component.set_material(slot, material if slot == 0 else original)
    component.set_visibility(source.is_visible(), False)
    poses = [source.get_instance_transform(i, world_space=False) for i in indices]
    assert list(component.add_instances(poses, True, False, False)) == list(range(len(indices)))
    return actor, component


def _load_preflight(file, expected_sha):
    path = (ROOT / file).resolve()
    assert path.is_relative_to(RUN.resolve()) and path.name == 'preflight.json'
    assert _sha(path) == expected_sha
    report = _read(path)
    assert report['schema'] == 1 and report['status'] == 'DIORAMA_PREFLIGHT_REVIEW_REQUIRED'
    assert report['map_sha256'] == INITIAL_MAP_SHA and report['script_sha256'] == _sha(__file__)
    assert report['delta_sha256'] == DELTA_SHA
    return path, report


def _expected_after(sync, before, selection):
    expected = json.loads(json.dumps(before))
    selected = defaultdict(set)
    for item in selection['records']:
        selected[item['label']].add(json.dumps(item['world_pose'], sort_keys=True, separators=(',', ':')))
    for label, pose_keys in selected.items():
        actor_name, actor = next((name, row) for name, row in expected.items() if row['label'] == label)
        component_name, component = next((name, row) for name, row in actor['components'].items()
                                         if row.get('instances') is not None)
        if label in WHOLE_GROUPS:
            key = selection['targets'][label]
            component['materials'][0] = '/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_Belfry'
            component['materials'][0] += 'Stone' if key == 'TX01' else 'Flagstone'
            continue
        remaining = list(component['instances'])
        for pose_key in pose_keys:
            matches = [i for i, pose in enumerate(remaining)
                       if json.dumps(pose, sort_keys=True, separators=(',', ':')) == pose_key]
            assert len(matches) == 1, ('selected transform absent/ambiguous in roster', label, pose_key)
            remaining.pop(matches[0])
        component['instances'] = remaining
    return expected


def _verify_applied(sync, persistent, before, after, selection, source_contracts, world):
    selected_by_label = defaultdict(list)
    for record in selection['records']:
        selected_by_label[record['label']].append(record)
    expected = _expected_after(sync, before, selection)
    added_labels = set(PARTITION_LABELS.values())
    assert set(after) == set(before) | {next(name for name,row in after.items() if row['label'] == label)
                                        for label in added_labels}
    assert all(sum(row['label'] == label for row in after.values()) == 1 for label in added_labels)
    for name, old in expected.items():
        assert after[name] == old, 'Unexpected change to existing actor/component: ' + old['label']
    label_index = {row['label']: name for name, row in after.items()}
    for source_label, new_label in PARTITION_LABELS.items():
        new_name = label_index[new_label]
        source_name = next(name for name, row in before.items() if row['label'] == source_label)
        source_actor, new_actor = before[source_name], after[new_name]
        assert new_actor['type'] == '/Script/Engine.Actor' and new_actor['label'] == new_label
        assert new_actor['tags'] == [OWNER] and new_actor['hidden'] is False
        assert new_actor['pose'] == dict(at=[0.0, 0.0, 0.0], q=[0.0, 0.0, 0.0, 1.0], scale=[1.0, 1.0, 1.0])
        assert len(new_actor['components']) == len(source_actor['components']) == 1
        source_component = next(iter(source_actor['components'].values()))
        new_component = next(iter(new_actor['components'].values()))
        records = selected_by_label[source_label]
        key = selection['targets'][source_label]
        expected_slots = list(source_component['materials'])
        expected_slots[0] = '/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_Belfry' + ('Stone' if key == 'TX01' else 'Flagstone')
        for field in ('mesh', 'collision', 'overlap', 'shadow', 'visible', 'pose'):
            assert new_component[field] == source_component[field], (new_label, field)
        assert new_component['materials'] == expected_slots
        assert new_component['instances'] == sync.ordered([r['world_pose'] for r in records])
    observed_contracts = _component_contracts(sync, persistent, world,
        set(EXPECTED_COUNTS) | added_labels)
    for label, original in source_contracts.items():
        expected_component = json.loads(json.dumps(original))
        if label in WHOLE_GROUPS:
            key = selection['targets'][label]
            expected_component['materials'][0] = '/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_Belfry' + (
                'Stone' if key == 'TX01' else 'Flagstone')
        assert observed_contracts[label] == expected_component, ('original component settings changed', label)
    for source_label, new_label in PARTITION_LABELS.items():
        expected_component = json.loads(json.dumps(source_contracts[source_label]))
        expected_component['actor'] = new_label
        expected_component['actor_tags'] = [OWNER]
        expected_component['materials'][0] = '/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_Belfry' + (
            'Stone' if selection['targets'][source_label] == 'TX01' else 'Flagstone')
        assert observed_contracts[new_label] == expected_component, ('partition settings differ from source', new_label)
    assert _total_instances(after) == 32646
    return json.loads(json.dumps(after)), observed_contracts


def apply(preflight_file, preflight_sha256):
    """Apply the reviewed split/rebind and save only the Diorama map."""
    path, old = _load_preflight(preflight_file, preflight_sha256)
    sync, persistent = _sync(), _persistent()
    sync.context(MAP_NAME)
    delta, applied = _contract(sync, persistent)
    assert old['guards'] == _guards(sync) and old['sync_receipt_sha256'] == _sha(SYNC_RECEIPT)
    assert sync.roster(False) == old['actors_and_components']
    assert sync.data.sha(MAP_FILE) == old['map_sha256']
    components, selected, targets, used = _selected(sync, delta, sync.ED.get_editor_world())
    assert selected == old['selection']['records'] and targets == old['selection']['targets']
    world = sync.ED.get_editor_world()
    before = sync.roster(False)
    assert before == old['actors_and_components'] and _total_instances(before) == 32646
    token = old['token']
    folder = path.parent
    checkpoint = folder / 'Diorama.before.umap'
    checkpoint_file = folder / 'checkpoint.json'
    journal = folder / 'applied.json'
    assert not checkpoint.exists() and not checkpoint_file.exists() and not journal.exists()
    shutil.copy2(MAP_FILE, checkpoint)
    assert _sha(checkpoint) == old['map_sha256']
    receipt = dict(schema=1, status='DIORAMA_APPLY_IN_PROGRESS', preflight_file=str(path.relative_to(ROOT)),
        preflight_sha256=preflight_sha256, checkpoint_file=str(checkpoint.relative_to(ROOT)),
        checkpoint_sha256=_sha(checkpoint), guards=old['guards'], map_before=old['map_sha256'], token=token)
    _write_new(checkpoint_file, receipt)
    try:
        for label, indices in old['selection']['by_label'].items():
            actor, component = components[label]
            if label in WHOLE_GROUPS:
                component.modify()
                component.set_material(0, sync.u.load_asset(delta['materials'][targets[label]]['target_asset']))
            else:
                new_actor, _ = _new_group(sync, world, component, indices,
                    sync.u.load_asset(delta['materials'][targets[label]]['target_asset']), PARTITION_LABELS[label])
                assert new_actor.get_actor_label() == PARTITION_LABELS[label]
                component.modify()
                for index in sorted(indices, reverse=True):
                    assert component.remove_instance(index)
        after = sync.roster(False)
        expected, details_after = _verify_applied(sync, persistent, before, after, old['selection'],
            old['source_component_contracts'], world)
        assert _guards(sync) == old['guards']
        assert sync.data.sha(MAP_FILE) == old['map_sha256']
        dirty_maps = sorted(_package(p) for p in sync.u.EditorLoadingAndSavingUtils.get_dirty_map_packages())
        dirty_content = sorted(_package(p) for p in sync.u.EditorLoadingAndSavingUtils.get_dirty_content_packages())
        assert dirty_maps == [MAP] and dirty_content == [], (dirty_maps, dirty_content)
        settings = sync.u.get_default_object(sync.u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'))
        prior_cook = settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
        try:
            settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(prior_cook).DISABLE)
            assert sync.u.get_editor_subsystem(sync.u.LevelEditorSubsystem).save_current_level()
        finally:
            settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', prior_cook)
        assert sync.roster(False) == after and _guards(sync) == old['guards']
        assert sync.data.sha(MAP_FILE) != old['map_sha256']
        assert not sync.u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
        assert not sync.u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
        receipt.update(status='DIORAMA_APPLIED_RELOAD_AUDIT_REQUIRED', map_after=_sha(MAP_FILE),
            total_instances_after=_total_instances(after), expected_after_roster=expected,
            component_contracts_after=details_after,
            observed_after_roster=after, new_partition_labels=sorted(PARTITION_LABELS.values()),
            rebind_groups=sorted(WHOLE_GROUPS), collision_guard_count=54,
            cook_setting_restored=True, only_diorama_map_saved=True)
        _write_new(journal, receipt)
        return dict(file=str(journal.relative_to(ROOT)), sha256=_sha(journal), status=receipt['status'],
            map_after=receipt['map_after'], total_instances=receipt['total_instances_after'])
    except Exception as error:
        receipt.update(status='DIORAMA_FAILED_REVIEW_REQUIRED', error=repr(error), map_current_sha256=_sha(MAP_FILE))
        failure = path.parent / 'failed.json'
        if not failure.exists():
            _write_new(failure, receipt)
        raise


def note_unloaded(applied_file, applied_sha256):
    """Record the target map absent while a separate clean review map is open."""
    path = (ROOT / applied_file).resolve()
    assert path.is_relative_to(RUN.resolve()) and path.name == 'applied.json' and _sha(path) == applied_sha256
    receipt = _read(path)
    assert receipt['status'] == 'DIORAMA_APPLIED_RELOAD_AUDIT_REQUIRED'
    sync = _sync()
    sync.context('KitLibrary')
    assert sync.ED.get_editor_world().get_path_name().split('.')[0] != MAP
    assert sync.u.find_object(None, MAP) is None, 'Diorama world/package still loaded; unload it before recording'
    out = path.parent / 'unloaded.json'
    proof = dict(schema=1, status='DIORAMA_UNLOADED_OBSERVED', applied_file=str(path.relative_to(ROOT)),
        applied_sha256=applied_sha256, target_world_path=MAP, target_find_object_result=None,
        open_world=sync.ED.get_editor_world().get_path_name(), other_world_open=True,
        map_after_sha256=receipt['map_after'], guards=_guards(sync))
    _write_new(out, proof)
    return dict(file=str(out.relative_to(ROOT)), sha256=_sha(out), status=proof['status'])


def audit(applied_file, applied_sha256, unloaded_file, unloaded_sha256):
    """Verify exact saved roster after note_unloaded() and reopening Diorama."""
    path = (ROOT / applied_file).resolve()
    assert path.is_relative_to(RUN.resolve()) and path.name == 'applied.json' and _sha(path) == applied_sha256
    receipt = _read(path)
    assert receipt['status'] == 'DIORAMA_APPLIED_RELOAD_AUDIT_REQUIRED'
    unload_path = (ROOT / unloaded_file).resolve()
    assert unload_path.is_relative_to(RUN.resolve()) and unload_path.name == 'unloaded.json'
    assert _sha(unload_path) == unloaded_sha256
    unload = _read(unload_path)
    assert unload['status'] == 'DIORAMA_UNLOADED_OBSERVED' and unload['applied_sha256'] == applied_sha256
    assert unload['map_after_sha256'] == receipt['map_after'] and unload['guards'] == receipt['guards']
    sync = _sync()
    sync.context(MAP_NAME)
    world = sync.ED.get_editor_world()
    assert sync.u.find_object(None, MAP) is not None, 'Reloaded Diorama world/package not found'
    assert _sha(MAP_FILE) == receipt['map_after']
    assert _guards(sync) == receipt['guards']
    observed = sync.roster(False)
    assert observed == receipt['expected_after_roster'] == receipt['observed_after_roster']
    details = _component_contracts(sync, _persistent(), world,
        set(EXPECTED_COUNTS) | set(PARTITION_LABELS.values()))
    assert details == receipt['component_contracts_after']
    assert _total_instances(observed) == receipt['total_instances_after'] == 32646
    assert len([a for a in observed.values() if a['label'] in PARTITION_LABELS.values()]) == 5
    audit_receipt = dict(schema=1, status='DIORAMA_RELOAD_AUDITED', applied_file=str(path.relative_to(ROOT)),
        applied_sha256=applied_sha256, map_sha256=_sha(MAP_FILE), guards=receipt['guards'],
        actor_component_roster=observed, total_instances=_total_instances(observed),
        unload_reload_identity_changed=True)
    out = path.parent / 'audit.json'
    _write_new(out, audit_receipt)
    return dict(file=str(out.relative_to(ROOT)), sha256=_sha(out), status=audit_receipt['status'],
        total_instances=audit_receipt['total_instances'])
