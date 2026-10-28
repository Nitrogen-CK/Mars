"""Stage and reopen-audit the approved Ossuary wall material in Blender copies.

This tool never overwrites either original Blender library. Stage creates a new
derived Diorama Blend; audit is intended for a separate Blender process opened
on that staged file. Import is inert.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import re
import struct
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
CHECKPOINT = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryWallLibraryStage'
LIBRARIES = {
    'KitLibrary': (HERE / 'Output/WarrensVariantC_KitLibrary.blend',
                   '28ae1af77e09a3dbb5377462861f171c56472f239b00eb4a2a913951fa038fa7'),
    'Diorama': (HERE / 'Output/WarrensVariantC_Diorama.blend',
                '2fb8dfdfbf1a3ad1a5e019204fc679d827eda137381f4b86934fd7b71dbcc7dc'),
}
FIT = HERE / 'Output/fitted_instances.json'
FIT_SHA256 = '67f8e8d87ab166ab7fd0cd5e285a08e02b8643c856de3bf028130271021b9d34'
SYNC = HERE / 'sync_art_libraries.py'
SYNC_SHA256 = '5de7683ebf5829952c0b31b39d3d28ff34b070019ab61fc2da01462ca3bbbad6'
MATERIAL_BUILDER = HERE / 'build_ossuary_material_candidate.py'
MATERIAL_BUILDER_SHA256 = 'f8840b9e13f060c9c01ac83dc403e3fc30c8f574f2d1c9ce4d196f64d82f7948'
GEOMETRY_HELPER = HERE / 'build_belfry_palette.py'
GEOMETRY_HELPER_SHA256 = 'eec406bdc6c887a9f2a11e0c29f78bba0abac819cade82926524a8691523b7dd'
RUNTIME_REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/OSSUARY_MATERIAL_RUNTIME_REVIEW.md'
RUNTIME_REVIEW_SHA256 = 'd7e456856a2027513028eb04774cd0c1cd4f9d786755cf589c2c82422fce9ec9'
ASSET_RECEIPT = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryMaterialTrial/assets_created_20261026T002324_985770Z_b8823bc5.json'
ASSET_RECEIPT_SHA256 = 'a0745bdea6852636b7fe376cf605c2ebb3be58c1d7ac2e0577cedaa7777f4ea9'
PAINTERLY = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/lookdev/ossuary-painterly-r01/Ossuary_PainterlyStone_Albedo_Quiet_r02.png'
PAINTERLY_SHA256 = '3ddb6bd818cb98422fd6594a0c6539455222e3b876f1a67cf3a91a540a4d127f'
MATERIAL = ROOT / 'Content/Mars/ArtReview/Lookdev/OssuaryPainterly_20261025/Materials/M_Ossuary_TX01_R02_C_PainterlyAlbedo_Mix060.uasset'
MATERIAL_SHA256 = '11376944ff6bd25178376d6fee7ac754c4ace383a12323c8f51bf6d6fd485859'
SCENES = ('02_VariantC_Cutaway', 'Zone_Ossuary')
PREFIX_BASE = 'WVC_OssuaryWall_R02_C_'
WALL_ROLES = {'source exposed wall veneer', 'source wall seam backing'}
WALL_COUNTS = {'CCS15': 597, 'BACKING_TX01': 597}
STATE_STAGE = 'SAVED_DERIVED_BLEND_REOPEN_AUDIT_PENDING'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _module(name, path, expected_sha):
    assert sha(path) == expected_sha, 'Pinned helper changed: ' + path.name
    if name not in sys.modules:
        spec = importlib.util.spec_from_file_location(name, path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules[name] = module
    return sys.modules[name]


def _helpers():
    sync = _module('_ossuary_wall_sync_contract', SYNC, SYNC_SHA256)
    materials = _module('_ossuary_wall_material_copy', MATERIAL_BUILDER, MATERIAL_BUILDER_SHA256)
    geometry = _module('_ossuary_wall_geometry_contract', GEOMETRY_HELPER, GEOMETRY_HELPER_SHA256)
    return sync, materials, geometry


def _input_guards(sync):
    guards = sync.immutable_files()
    extra = {path: expected for path, expected in LIBRARIES.values()}
    extra.update({
        FIT: FIT_SHA256,
        SYNC: SYNC_SHA256,
        MATERIAL_BUILDER: MATERIAL_BUILDER_SHA256,
        GEOMETRY_HELPER: GEOMETRY_HELPER_SHA256,
        RUNTIME_REVIEW: RUNTIME_REVIEW_SHA256,
        ASSET_RECEIPT: ASSET_RECEIPT_SHA256,
        PAINTERLY: PAINTERLY_SHA256,
        MATERIAL: MATERIAL_SHA256,
    })
    for path, expected in extra.items():
        assert path.is_file() and sha(path) == expected, ('Pinned input changed', str(path), expected)
        guards[path.relative_to(ROOT).as_posix()] = expected
    return dict(sorted(guards.items()))


def _attempt_dir(library, attempt_id):
    assert library in LIBRARIES
    assert len(attempt_id) == 32 and all(ch in '0123456789abcdef' for ch in attempt_id.lower())
    path = (CHECKPOINT / library / attempt_id).resolve()
    assert path.is_relative_to(CHECKPOINT.resolve())
    return path


def _write(path, value):
    path = Path(path).resolve()
    assert path.is_relative_to(CHECKPOINT.resolve()) and not path.exists(), ('Refuse receipt overwrite', str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    value = dict(value, schema=1, created_utc=datetime.now(timezone.utc).isoformat(), tool_sha256=sha(__file__))
    path.write_text(json.dumps(value, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    return dict(file=path.relative_to(ROOT).as_posix(), sha256=sha(path))


def _context(expected_blend, expected_sha):
    import bpy
    current = Path(bpy.data.filepath).resolve()
    assert current == expected_blend.resolve(), ('Open the exact requested source/candidate Blend', str(current), str(expected_blend))
    assert sha(current) == expected_sha, ('Unexpected Blender file hash', str(current), sha(current))
    return bpy


def _expected_rows(data):
    rows = []
    for index, row in enumerate(data['base']['placements']):
        if row.get('tile') != 'Ossuary' or row.get('context_proxy'):
            continue
        role = row.get('role', '')
        if row.get('id') == 'CCS15' and role == 'source exposed wall veneer':
            rows.append(dict(index=index, id=row['id'], role=role))
        elif row.get('id') == 'BACKING_TX01' and role == 'source wall seam backing':
            rows.append(dict(index=index, id=row['id'], role=role))
    assert len(rows) == 1194
    counts = {ident: sum(r['id'] == ident for r in rows) for ident in WALL_COUNTS}
    assert counts == WALL_COUNTS
    return rows


def _effective_scene_rows(data, scene_name):
    tile = None if scene_name == '02_VariantC_Cutaway' else scene_name.removeprefix('Zone_')
    return [(key, row) for key, row in data['effective'] if tile is None or row['tile'] == tile]


def _scan(sync, materials, data, placements):
    import bpy
    assert set(SCENES).issubset(bpy.data.scenes.keys())
    expected = _expected_rows(data)
    records, usage_by_scene = {}, {}
    for scene_name in SCENES:
        scene = bpy.data.scenes[scene_name]
        selected, usages = materials.selected_rows(scene, placements, sync)
        expected_set = {(str(r['index']), r['id'], r['role']) for r in expected}
        actual_set = {(str(r['index']), r['row']['id'], r['row'].get('role', '')) for r in selected}
        assert actual_set == expected_set, ('Material selector differs from exact approved row set', scene_name)
        assert len(usages) == 1194 and all(u['material_slot'] == 0 for u in usages)
        assert len({r['instance'].name for r in selected}) == 1194
        counts = {ident: sum(r['row']['id'] == ident for r in selected) for ident in WALL_COUNTS}
        assert counts == WALL_COUNTS
        records[scene_name] = selected
        usage_by_scene[scene_name] = usages
        scene_source_rows = _effective_scene_rows(data, scene_name)
        assert len(scene.objects) > 0
        assert not any('ceiling' in row.get('role', '').lower()
                       for _, row in scene_source_rows if row.get('tile') == 'Ossuary'), (
                           'Unexpected Ossuary ceiling row in this static scene', scene_name)
        assert sum(1 for obj in scene.objects if obj.instance_type == 'COLLECTION') == len(scene_source_rows), (
            'Current scene does not match effective placement projection', scene_name,
            sum(1 for obj in scene.objects if obj.instance_type == 'COLLECTION'), len(scene_source_rows))
    original_bindings = {name: materials.scene_bindings(bpy.data.scenes[name]) for name in SCENES}
    source_materials = {name:sync.stable(snapshot)
                        for name,snapshot in materials.source_material_snapshots(sync).items()}
    before_inventory = sync.stable(sync.inventory())
    geometry = _geometry_by_scene(sync, materials, SCENES)
    assert all(g['count'] > 0 for g in geometry.values())
    return dict(rows=data['effective'], expected=expected, selected=records, usages=usage_by_scene,
        original_bindings=original_bindings, source_materials=source_materials,
        inventory=before_inventory, geometry=geometry)


def _geometry_by_scene(sync, materials, scene_names):
    import bpy
    geometry = _module('_ossuary_wall_geometry_contract', GEOMETRY_HELPER, GEOMETRY_HELPER_SHA256)
    window = bpy.context.window
    assert window
    previous = window.scene.name
    result = {}
    try:
        for name in scene_names:
            window.scene = bpy.data.scenes[name]
            bpy.context.view_layer.update()
            result[name] = geometry.geometry_multiset()
    finally:
        window.scene = bpy.data.scenes[previous]
    return result


def _scene_rows_preserved(sync, data, original, wrappers_by_source, selected_by_scene):
    import bpy
    for scene_name in SCENES:
        scene = bpy.data.scenes[scene_name]
        lookup = {}
        for obj in scene.objects:
            if obj.instance_type == 'COLLECTION':
                lookup.setdefault(re.sub(r'\.\d{3}$', '', obj.name), []).append(obj)
        selected_names = {r['instance'].name if hasattr(r['instance'], 'name') else r['instance']
                          for r in selected_by_scene[scene_name]}
        expected_rows = _effective_scene_rows(data, scene_name)
        actual_instances = sum(len(values) for values in lookup.values())
        assert actual_instances == len(expected_rows), (
            'Effective placement count mismatch', scene_name, actual_instances, len(expected_rows))
        for key, row in expected_rows:
            name = row['id'] + '_Assembly_' + str(key) if str(key).isdigit() else 'Sync_' + scene_name + '_' + str(key)
            matches = lookup.get(name, [])
            assert len(matches) == 1, ('Lost/duplicated effective source instance', scene_name, key, name)
            obj = matches[0]
            sync.check_pose(obj, row)
            before_instance = original['source_inventory']['objects'][obj.name]['instance']
            if obj.name in selected_names:
                assert obj.instance_collection and obj.instance_collection.name in set(wrappers_by_source.values())
            else:
                assert obj.instance_collection and obj.instance_collection.name == before_instance
            if not str(key).isdigit():
                assert obj.get('sync_owner') == sync.OWNER and obj.get('sync_key') == key
                assert obj.get('source_row_sha256') == sync.digest(row) and not obj.rigid_body
        assert len(scene.objects) == len(original['source_inventory']['scenes'][scene_name]['objects'])


def _assert_original_materials_unchanged(sync, materials, snapshots):
    import bpy
    for name, expected in snapshots.items():
        material = bpy.data.materials.get(name)
        assert material is not None and material.get('catalog_key') == expected['catalog_key'], name
        actual = sync.stable(materials.material_graph(sync, material))
        assert actual == expected['graph'], ('Original material graph changed', name)


def preflight(library):
    """Read-only inventory of one exact original Blend library."""
    sync, materials, geometry = _helpers()
    source_blend, source_sha = LIBRARIES[library]
    bpy = _context(source_blend, source_sha)
    guards = _input_guards(sync)
    data = sync.projection()
    placements = read(FIT)['placements']
    scanned = _scan(sync, materials, data, placements)
    attempt_id = uuid.uuid4().hex
    folder = _attempt_dir(library, attempt_id)
    assert not folder.exists()
    folder.mkdir(parents=True)
    receipt = dict(status='PREFLIGHT_REVIEW_REQUIRED', attempt_id=attempt_id,
        library=library, source_blend=source_blend.relative_to(ROOT).as_posix(), source_blend_sha256=source_sha,
        source_scenes=list(SCENES), source_effective_placement_count=len(data['effective']),
        source_scene_instance_counts={name:len(bindings) for name,bindings in scanned['original_bindings'].items()},
        target_wall_rows_per_scene=1194, wall_veneers=597, wall_backings=597,
        emitted_ossuary_ceiling_rows_per_scene=0,
        source_bindings=scanned['original_bindings'], selected_source_rows={name:[
            dict(index=r['index'], id=r['row']['id'], role=r['row']['role'], instance=r['instance'].name,
                 source_collection=r['collection'].name, affected_parts=r['affected_parts']) for r in records]
            for name,records in scanned['selected'].items()},
        tx01_slot_usages={name:records for name,records in scanned['usages'].items()},
        source_inventory=scanned['inventory'], source_material_graphs=scanned['source_materials'],
        source_geometry=scanned['geometry'], immutable_file_guards=guards,
        source_contract=dict(sync_sha256=SYNC_SHA256, material_builder_sha256=MATERIAL_BUILDER_SHA256,
            geometry_helper_sha256=GEOMETRY_HELPER_SHA256, fitted_instances_sha256=FIT_SHA256,
            runtime_review_sha256=RUNTIME_REVIEW_SHA256, asset_receipt_sha256=ASSET_RECEIPT_SHA256,
            material_asset_sha256=MATERIAL_SHA256, albedo_sha256=PAINTERLY_SHA256),
        boundary='Read-only preflight of the selected original Blend. No Blender file or original asset was written.')
    receipt_path = folder / 'preflight.json'
    written = _write(receipt_path, receipt)
    return dict(status=receipt['status'], **written)


def _preflight_receipt(file, expected_sha, library):
    path = (ROOT / file).resolve()
    assert path.is_relative_to(CHECKPOINT.resolve()) and path.name == 'preflight.json'
    assert path.parent == _attempt_dir(library, path.parent.name)
    assert sha(path) == expected_sha
    value = read(path)
    assert value['status'] == 'PREFLIGHT_REVIEW_REQUIRED'
    source_blend, source_sha = LIBRARIES[library]
    assert value['library'] == library and value['source_blend'] == source_blend.relative_to(ROOT).as_posix()
    assert value['source_blend_sha256'] == source_sha
    assert value['source_scenes'] == list(SCENES)
    assert value['wall_veneers'] == value['wall_backings'] == 597
    assert value['emitted_ossuary_ceiling_rows_per_scene'] == 0
    return path, value


def _build_changes(sync, materials, preflight, data, placements):
    import bpy
    selected = {}
    scene_bindings = {}
    for name in SCENES:
        scene = bpy.data.scenes[name]
        selected[name], usages = materials.selected_rows(scene, placements, sync)
        assert len(selected[name]) == 1194 and len(usages) == 1194
        scene_bindings[name] = materials.scene_bindings(scene)
        assert scene_bindings[name] == preflight['source_bindings'][name]
    attempt_token = preflight['attempt_id'].split('-')[-1]
    materials.PREFIX = PREFIX_BASE + attempt_token + '_'
    image = bpy.data.images.load(str(PAINTERLY), check_existing=False)
    image.name = materials.PREFIX + 'AlbedoR02'
    image.colorspace_settings.name = 'sRGB'
    image.pack()
    assert image.packed_file and sha(PAINTERLY) == PAINTERLY_SHA256
    # Both scenes refer to the same source collection prototypes. Build each
    # wrapper once, then bind the matching placement rows in both scenes.
    materials.PREFIX = PREFIX_BASE + attempt_token + '_'
    combined = selected[SCENES[0]] + selected[SCENES[1]]
    wrapper_by_source, copies, deltas, combined_bindings = materials.make_wrappers(
        combined, 'C_r02_mix60', image, sync)
    # Blender ID.copy clears the retention flag. Persistent library variants
    # preserve the original IDs' fake-user policy as well as their render data.
    for wrapper in wrapper_by_source.values():
        wrapper['target'].use_fake_user = wrapper['source'].use_fake_user
        for part in wrapper['parts']:
            bpy.data.objects[part['target']].use_fake_user = bpy.data.objects[part['source']].use_fake_user
    for source_name, candidate in copies.items():
        candidate.use_fake_user = bpy.data.materials[source_name].use_fake_user
    material_records = {name: deltas for name in SCENES}
    binding_records = {}
    combined_by_name = {record['instance'].name: binding for record, binding in zip(combined, combined_bindings)}
    assert len(combined_by_name) == len(combined_bindings) == 2388
    for scene_name in SCENES:
        scene = bpy.data.scenes[scene_name]
        scene_records = selected[scene_name]
        binding_records[scene_name] = [combined_by_name[record['instance'].name] for record in scene_records]
        materials.verify_bindings(scene, scene_bindings[scene_name], scene_records,
                                  wrapper_by_source, 'C_wall_mix060')
    _assert_original_materials_unchanged(sync, materials, preflight['source_material_graphs'])
    wrapper_rows = []
    for source_name, wrapper in wrapper_by_source.items():
        source_contract = _collection_contract(wrapper['source'], sync)
        target_contract = _collection_contract(wrapper['target'], sync)
        _assert_collection_copy(source_contract, target_contract, wrapper['parts'], sync)
        wrapper_rows.append(dict(source=source_name, target=wrapper['target'].name,
            parts=copy.deepcopy(wrapper['parts']), source_contract=source_contract, target_contract=target_contract))
    all_material_deltas = {}
    for scene_name, deltas in material_records.items():
        for delta in deltas:
            previous = all_material_deltas.get(delta['candidate'])
            assert previous is None or previous == delta
            all_material_deltas[delta['candidate']] = delta
    return dict(selected=selected, bindings=binding_records, wrappers=wrapper_rows,
        materials=list(all_material_deltas.values()), image=image, wrapper_by_source=wrapper_by_source,
        original_bindings=scene_bindings, scene_bindings=scene_bindings)


def _collection_contract(collection, sync):
    return dict(identity=collection.name, values=sync.rna(collection), props=sync.props(collection),
        objects=sorted(o.name for o in collection.objects), children=sorted(c.name for c in collection.children))


def _assert_collection_copy(source, target, parts, sync):
    source_values, target_values = sync.stable(source['values']), sync.stable(target['values'])
    assert source_values['name'] == source_values['name_full'] == source['identity']
    assert target_values['name'] == target_values['name_full'] == target['identity']
    target_values['name'] = source_values['name']
    target_values['name_full'] = source_values['name_full']
    assert source_values == target_values and source['props'] == target['props']
    assert source['children'] == [] and target['children'] == []
    assert target['objects'] == sorted(p['target'] for p in parts)


def _capture_change_records(sync, materials, changes, image, before, after):
    wrappers = []
    for wrapper in changes['wrappers']:
        wrappers.append(dict(source=wrapper['source'], target=wrapper['target'], parts=wrapper['parts'],
            source_contract=wrapper['source_contract'], target_contract=wrapper['target_contract']))
    candidate_materials = []
    for delta in changes['materials']:
        candidate_materials.append(dict(delta=delta,
            inventory_record=copy.deepcopy(after['materials'][delta['candidate']])))
    image_record = dict(name=image.name, png_sha256=PAINTERLY_SHA256,
        inventory_record=copy.deepcopy(after['images'][image.name]))
    bindings = []
    for scene_name, rows in changes['selected'].items():
        mapping = {w['source']:w['target'] for w in wrappers}
        for record in rows:
            bindings.append(dict(scene=scene_name, placement_index=record['index'], placement_id=record['row']['id'],
                role=record['row']['role'], instance=record['instance'].name,
                source_collection=record['collection'].name, target_collection=mapping[record['collection'].name]))
    return dict(wrappers=wrappers, materials=candidate_materials, image=image_record, bindings=bindings)


def _validate_inventory(before, after, changes):
    before, after = copy.deepcopy(before), copy.deepcopy(after)
    wrappers = changes['wrappers']
    wrapper_targets = {w['target'] for w in wrappers}
    part_targets = {p['target'] for w in wrappers for p in w['parts']}
    material_targets = {m['delta']['candidate'] for m in changes['materials']}
    image_target = {changes['image']['name']}
    for table, targets in (('objects', part_targets), ('collections', wrapper_targets),
                           ('materials', material_targets), ('images', image_target)):
        assert set(after[table]) - set(before[table]) == targets, ('Unexpected new IDs in canonical inventory', table)
        assert set(before[table]) - set(after[table]) == set(), ('Original IDs missing after stage', table)
    expected = copy.deepcopy(before)
    for binding in changes['bindings']:
        old = expected['objects'][binding['instance']]['instance']
        assert old == binding['source_collection']
        expected['objects'][binding['instance']]['instance'] = binding['target_collection']
    for wrapper in wrappers:
        expected['collections'][wrapper['target']] = dict(objects=sorted(p['target'] for p in wrapper['parts']), children=[])
        for part in wrapper['parts']:
            assert part['source'] in before['objects']
            obj = copy.deepcopy(before['objects'][part['source']])
            obj['collections'] = ['collection:' + wrapper['target']]
            obj['materials'] = [[slot['target_link'], slot['target_material']] for slot in part['slots']]
            expected['objects'][part['target']] = obj
    for material in changes['materials']:
        source_name, target_name = material['delta']['source'], material['delta']['candidate']
        original = before['materials'][source_name]
        target = copy.deepcopy(material['inventory_record'])
        assert target['props'] == original['props']
        values_before, values_after = copy.deepcopy(original['values']), copy.deepcopy(target['values'])
        assert values_before['name'] == source_name and values_after['name'] == target_name
        assert values_before['name_full'] == source_name and values_after['name_full'] == target_name
        values_after['name'] = values_before['name']
        values_after['name_full'] = values_before['name_full']
        for field in ('users', 'is_dirty', 'tag', 'has_data'):
            values_before.pop(field, None)
            values_after.pop(field, None)
        assert values_before == values_after, ('Copied material scalar property changed', target_name)
        assert target['nodes'] == _expected_material_nodes(original['nodes'], target['nodes'], material['delta'], changes['image']['name'])
        expected['materials'][target_name] = target
    image = changes['image']
    image_record = copy.deepcopy(image['inventory_record'])
    assert image_record['colorspace'] == 'sRGB'
    assert image_record['packed_sha256'] == [image['png_sha256']], 'Candidate packed pixels differ from pinned PNG bytes'
    expected['images'][image['name']] = image_record
    assert expected == after, 'Canonical inventory changed beyond selected collection bindings and exact copied IDs'
    return dict(source_objects=len(before['objects']), wrapper_objects=len(part_targets),
        wrapper_collections=len(wrapper_targets), copied_materials=len(material_targets), images=len(image_target),
        scenes=len(before['scenes']), meshes=len(before['meshes']))


def _expected_material_nodes(original_nodes, target_nodes, delta, candidate_image_name):
    expected = copy.deepcopy(original_nodes)
    mix_node, factor = delta['mix_node'], delta['factor_socket']
    expected['nodes'][mix_node]['inputs'][factor] = struct.unpack('f', struct.pack('f', 0.60))[0]
    image_nodes = [name for name, row in expected['nodes'].items()
        if row.get('image') == delta['source_albedo_image'] and row.get('type') == 'ShaderNodeTexImage']
    assert len(image_nodes) == 1
    expected['nodes'][image_nodes[0]]['image'] = candidate_image_name
    assert target_nodes == expected, 'Candidate material graph differs beyond factor and albedo image'
    return expected


def _recheck_room_geometry(sync, materials, preflight, changes):
    import bpy
    geom = _geometry_by_scene(sync, materials, SCENES)
    assert geom == preflight['source_geometry'], 'Evaluated scene geometry/UV/placement multiset changed'
    data = sync.projection()
    placements = read(FIT)['placements']
    _scene_rows_preserved(sync, data, preflight, {w['source']:w['target'] for w in changes['wrappers']}, changes['selected'])
    for scene_name in SCENES:
        selected_names = {r['instance'].name for r in changes['selected'][scene_name]}
        records = changes['selected'][scene_name]
        usage = [u for r in records for p in r['affected_parts'] for u in [p]]
        assert len(records) == 1194 and len(usage) >= 1194
        assert all(r['collection'].name in {w['source'] for w in changes['wrappers']} for r in records)
    return geom


def stage(preflight_file, preflight_sha256, library):
    """Save a new derived Diorama file; never overwrite the original Blend."""
    import bpy
    sync, materials, geometry = _helpers()
    path = (ROOT / preflight_file).resolve()
    assert path.is_relative_to(CHECKPOINT.resolve())
    attempt_id = path.parent.name
    folder = _attempt_dir(library, attempt_id)
    assert path.name == 'preflight.json' and sha(path) == preflight_sha256
    _, preflight_data = _preflight_receipt(preflight_file, preflight_sha256, library)
    source_blend, source_sha = LIBRARIES[library]
    bpy = _context(source_blend, source_sha)
    guards = _input_guards(sync)
    assert guards == preflight_data['immutable_file_guards']
    data = sync.projection()
    placements = read(FIT)['placements']
    scanned = _scan(sync, materials, data, placements)
    assert scanned['inventory'] == preflight_data['source_inventory']
    assert scanned['source_materials'] == preflight_data['source_material_graphs']
    assert scanned['geometry'] == preflight_data['source_geometry']
    assert scanned['original_bindings'] == preflight_data['source_bindings']
    changes = _build_changes(sync, materials, preflight_data, data, placements)
    _recheck_room_geometry(sync, materials, preflight_data, changes)
    after = sync.stable(sync.inventory())
    details = _capture_change_records(sync, materials, changes, changes['image'], scanned['inventory'], after)
    inventory_counts = _validate_inventory(scanned['inventory'], after, details)
    _assert_original_materials_unchanged(sync, materials, scanned['source_materials'])
    after_guards = _input_guards(sync)
    assert after_guards == guards, 'Original source Blend/kit/assets/collision/input changed during staging'
    staged_blend = folder / f'WarrensVariantC_{library}_OssuaryWall_R02_Candidate.blend'
    assert not staged_blend.exists()
    bpy.ops.wm.save_as_mainfile(filepath=str(staged_blend), compress=True, relative_remap=False)
    assert staged_blend.is_file() and sha(source_blend) == source_sha
    assert _input_guards(sync) == guards
    report = dict(status=STATE_STAGE, attempt_id=attempt_id, library=library,
        source_blend=source_blend.relative_to(ROOT).as_posix(), source_blend_sha256=source_sha,
        staged_blend=staged_blend.relative_to(ROOT).as_posix(), staged_blend_sha256=sha(staged_blend),
        preflight_file=path.relative_to(ROOT).as_posix(), preflight_sha256=preflight_sha256,
        source_contract=preflight_data['source_contract'], immutable_file_guards=guards,
        scenes=list(SCENES), wall_instances_per_scene=1194, wall_veneers=597, wall_backings=597,
        emitted_ossuary_ceiling_instances_per_scene=0,
        candidate_material=details['materials'], candidate_image=details['image'],
        wrappers=details['wrappers'], bindings=details['bindings'], inventory_counts=inventory_counts,
        inventory_before=scanned['inventory'], inventory_after=after,
        geometry_before=scanned['geometry'], geometry_after=_geometry_by_scene(sync, materials, SCENES),
        boundary=f'New derived {library} Blend only. Both original Blend libraries remain byte-identical. Separate-process reopen audit required before any promotion or persistent library replacement.')
    receipt = _write(folder / 'stage.json', report)
    return dict(status=report['status'], staged_blend=report['staged_blend'], staged_sha256=report['staged_blend_sha256'], **receipt)


def _stage_receipt(file, expected_sha, library):
    path = (ROOT / file).resolve()
    assert path.is_relative_to(CHECKPOINT.resolve()) and path.name == 'stage.json'
    assert path.parent == _attempt_dir(library, path.parent.name)
    assert sha(path) == expected_sha
    data = read(path)
    assert data['status'] == STATE_STAGE and data['library'] == library
    source_blend, source_sha = LIBRARIES[library]
    staged_blend = (ROOT / data['staged_blend']).resolve()
    assert staged_blend.parent == path.parent
    assert staged_blend.name == f'WarrensVariantC_{library}_OssuaryWall_R02_Candidate.blend'
    assert data['source_blend'] == source_blend.relative_to(ROOT).as_posix()
    assert data['source_blend_sha256'] == source_sha and data['staged_blend_sha256'] == sha(staged_blend)
    assert data['source_contract']['runtime_review_sha256'] == RUNTIME_REVIEW_SHA256
    return path, data


def audit(stage_file, stage_sha256, library):
    """Audit a staged candidate after opening it in a fresh Blender process."""
    sync, materials, geometry = _helpers()
    path, record = _stage_receipt(stage_file, stage_sha256, library)
    bpy = _context(ROOT / record['staged_blend'], record['staged_blend_sha256'])
    assert _input_guards(sync) == record['immutable_file_guards']
    current = sync.stable(sync.inventory())
    assert current == record['inventory_after'], 'Reopened candidate canonical inventory differs from staged receipt'
    _validate_inventory(record['inventory_before'], current, dict(wrappers=record['wrappers'], materials=record['candidate_material'],
        image=record['candidate_image'], bindings=record['bindings']))
    data = sync.projection()
    for binding in record['bindings']:
        obj = bpy.data.objects.get(binding['instance'])
        assert obj and obj.instance_collection and obj.instance_collection.name == binding['target_collection']
        row = data['base']['placements'][binding['placement_index']]
        assert row['id'] == binding['placement_id'] and row['role'] == binding['role']
        sync.check_pose(obj, row)
    selected_by_scene = {name:[{'instance':binding['instance']} for binding in record['bindings'] if binding['scene'] == name]
                         for name in SCENES}
    wrappers_by_source = {wrapper['source']:wrapper['target'] for wrapper in record['wrappers']}
    _scene_rows_preserved(sync, data, {'source_inventory':record['inventory_before']},
                          wrappers_by_source, selected_by_scene)
    geom = _geometry_by_scene(sync, materials, SCENES)
    assert geom == record['geometry_before'] == record['geometry_after']
    _assert_original_materials_unchanged(sync, materials, {
        name:dict(graph=sync.stable(row['nodes']),
                  catalog_key=record['inventory_before']['materials'][name]['props'].get('catalog_key'))
        for name,row in record['inventory_before']['materials'].items()
        if 'catalog_key' in record['inventory_before']['materials'][name]['props']})
    assert _input_guards(sync) == record['immutable_file_guards']
    report = dict(status='REOPEN_AUDIT_PASS', stage_file=path.relative_to(ROOT).as_posix(),
        stage_sha256=stage_sha256, staged_blend=record['staged_blend'], staged_blend_sha256=record['staged_blend_sha256'],
        library=library, source_blend_sha256=record['source_blend_sha256'],
        per_scene_wall_rows=1194, emitted_ossuary_ceiling_rows_per_scene=0,
        inventory_counts=record['inventory_counts'], geometry=geom,
        original_blends_unchanged=True, no_imports_or_original_promotions=True,
        boundary='Separate-process Blender reopen audit only; not Unreal import, game render, or production promotion.')
    audit_receipt = path.parent / 'reopen_audit.json'
    written = _write(audit_receipt, report)
    return dict(status=report['status'], **written)


def _parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--action', choices=('preflight', 'stage', 'audit'), required=True)
    parser.add_argument('--library', choices=tuple(LIBRARIES), required=True)
    parser.add_argument('--receipt')
    parser.add_argument('--sha256')
    return parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])


if __name__ == '__main__':
    args = _parse_args()
    if args.action == 'preflight':
        print('OSSUARY_WALL_LIBRARY_PREFLIGHT', json.dumps(preflight(args.library), sort_keys=True), flush=True)
    elif args.action == 'stage':
        assert args.receipt and args.sha256
        print('OSSUARY_WALL_LIBRARY_STAGE', json.dumps(stage(args.receipt, args.sha256, args.library), sort_keys=True), flush=True)
    else:
        assert args.receipt and args.sha256
        print('OSSUARY_WALL_LIBRARY_AUDIT', json.dumps(audit(args.receipt, args.sha256, args.library), sort_keys=True), flush=True)
