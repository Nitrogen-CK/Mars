"""Stage and reopen-audit config-selected cardinal-wall material families.

Blender invocation examples (run only after an accepted guard receipt is added
to the config):

  blender --background <source.blend> --python cardinal_wall_family_libraries.py -- \
      --action stage --config <config.json> --config-sha256 <sha256> --library Diorama
  blender --background <staged.blend> --python cardinal_wall_family_libraries.py -- \
      --action audit --config <config.json> --config-sha256 <sha256> --library Diorama \
      --stage-receipt <stage.json> --stage-receipt-sha256 <sha256>

This tool only writes unique derived Blend files and receipts below the
config's checkpoint directory. It never saves a source library or promotes a
candidate. All family choices and scopes come from config; the current Hall
configuration is intentionally blocked until a fresh accepted source-guard
receipt is supplied.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import math
import re
import os
import struct
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
TOOL_PATH = Path(__file__).resolve()


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'),
        allow_nan=False).encode('utf-8')).hexdigest()


def stable(value):
    if isinstance(value, dict):
        return {k: stable(v) for k, v in value.items()
                if k not in {'session_uid', 'users', 'tag', 'has_data', 'is_dirty'}}
    if isinstance(value, (list, tuple)):
        return [stable(v) for v in value]
    return value


def rooted(path):
    result = (ROOT / path).resolve()
    assert result.is_relative_to(ROOT.resolve()), ('Path escapes repository', str(path))
    return result


def load_module(name, path, expected_sha):
    path = Path(path)
    assert path.is_file() and sha(path) == expected_sha, ('Pinned helper changed', str(path), expected_sha)
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _config(path, expected_sha=None):
    path = Path(path).resolve()
    assert path.is_relative_to(ROOT.resolve()) and path.is_file()
    if expected_sha:
        assert sha(path) == expected_sha, ('Config changed', str(path))
    config = read(path)
    assert config['schema'] == 'cardinal-wall-family-library-stage-v1'
    assert config['family_id'] and config['libraries'] and config['family']
    assert sha(TOOL_PATH) == config['tool_sha256'], ('Tool hash differs from config', str(TOOL_PATH))
    config['_source_path'] = path
    config['_source_sha256'] = sha(path)
    return path, config


def _family_inputs(config):
    family = config['family']
    required = ('fitted_instances', 'selection', 'albedo', 'runtime_approval')
    assert all(name in family for name in required)
    paths = {}
    for name in required:
        item = family[name]
        path = rooted(item['path'])
        assert path.is_file() and sha(path) == item['sha256'], ('Family input changed', name, str(path))
        paths[name] = path
    return paths


def _helpers(config):
    tools = config['helpers']
    directory = ROOT / config['tool_directory']
    sync = load_module('_cardinal_library_sync', directory / tools['sync']['path'], tools['sync']['sha256'])
    materials = load_module('_cardinal_library_materials', directory / tools['materials']['path'],
                             tools['materials']['sha256'])
    geometry = load_module('_cardinal_library_geometry', directory / tools['geometry']['path'],
                           tools['geometry']['sha256'])
    projection = load_module('_cardinal_library_projection', directory / tools['projection']['path'],
                              tools['projection']['sha256'])
    return sync, materials, geometry, projection


def _authorization(config, library):
    """Require the root-supplied fresh accepted guard receipt before any stage."""
    authorization = config.get('stage_authorization')
    assert authorization and authorization.get('accepted_guard_receipt'), (
        'Stage blocked: root must supply an accepted source-guard receipt in stage_authorization')
    item = authorization['accepted_guard_receipt']
    path = rooted(item['path'])
    assert path.is_file() and sha(path) == item['sha256'], ('Accepted guard receipt changed', str(path))
    receipt = read(path)
    assert authorization.get('accepted') is True, 'Stage blocked: config authorization has not been approved'
    allowed_statuses = set(authorization.get('accepted_statuses', []))
    assert receipt.get('status') in allowed_statuses, ('Unaccepted guard receipt status', receipt.get('status'))
    guard_table = receipt.get('protected_files') or receipt.get('immutable_file_guards')
    assert isinstance(guard_table, dict) and guard_table, 'Guard receipt has no protected file table'
    for source_name, library_row in config['libraries'].items():
        source_rel = Path(library_row['blend']).as_posix()
        assert source_rel in guard_table, ('Guard receipt does not pin source Blend', source_name, source_rel)
        source_path = rooted(source_rel)
        assert sha(source_path) == guard_table[source_rel], ('Source Blend differs from accepted guard', source_name, source_rel)
    library_row = config['libraries'][library]
    source_rel = Path(library_row['blend']).as_posix()
    return dict(path=path.relative_to(ROOT).as_posix(), sha256=sha(path),
                status=receipt['status'], source_blend=source_rel,
                source_blend_sha256=guard_table[source_rel], guard_table=guard_table)


def _guard_inputs(config, sync, authorization):
    guards = dict(authorization['guard_table'])
    explicit = {}
    for section in ('helpers',):
        for item in config[section].values():
            rel = (Path(config['tool_directory']) / item['path']).as_posix()
            explicit[rel] = item['sha256']
    for section in ('fitted_instances', 'selection', 'albedo', 'runtime_approval'):
        item = config['family'][section]
        explicit[Path(item['path']).as_posix()] = item['sha256']
    explicit[Path(config['tool_path']).as_posix()] = sha(TOOL_PATH)
    explicit[Path(config['config_path']).as_posix()] = config['_source_sha256']
    for rel, expected in explicit.items():
        path = rooted(rel)
        assert path.is_file() and sha(path) == expected, ('Explicit input changed', rel, expected)
        if rel in guards:
            assert guards[rel] == expected, ('Guard receipt disagrees with input pin', rel)
        guards[rel] = expected
    # The shared projection helper also verifies its current fitted/asset inputs.
    shared = sync.immutable_files()
    for rel, expected in shared.items():
        path = rooted(rel)
        assert path.is_file() and sha(path) == expected, ('Shared source guard failed', rel)
        if rel in guards:
            assert guards[rel] == expected, ('Accepted guard disagrees with shared source', rel)
        guards[rel] = expected
    return dict(sorted(guards.items()))


def _load_contract(config, paths, sync):
    family = config['family']
    fitted = read(paths['fitted_instances'])
    selection = read(paths['selection'])
    assert selection.get('selected_wall_instances') == family['expected_selected_instance_count']
    keys = selection['selected_source_keys']
    assert len(keys) == len(set(keys)) == family['expected_selected_instance_count']
    placements = fitted['placements']
    assert max(keys) < len(placements)
    axis_by_key = {}
    for pair in selection['pairs']:
        axis = int(pair['axis'])
        assert axis in (0, 1)
        for key in pair['source_keys']:
            assert key not in axis_by_key
            axis_by_key[key] = axis
    assert set(axis_by_key) == set(keys), 'Selection pairs do not cover exact selected keys'
    selectors = family['placement_selector']
    allowed_ids = set(selectors['ids'])
    allowed_roles = set(selectors['roles'])
    for key in keys:
        row = placements[key]
        assert row['id'] in allowed_ids and row.get('role') in allowed_roles, ('Unexpected selected fit row', key, row)
        assert row.get('tile') in selectors['tiles'], ('Selected row outside configured tiles', key, row.get('tile'))
    data = sync.projection()
    return fitted, selection, placements, axis_by_key, data


def _geometry_by_scene(bpy, geometry, names):
    window = bpy.context.window
    assert window
    previous = window.scene.name
    result = {}
    try:
        for name in names:
            assert name in bpy.data.scenes
            window.scene = bpy.data.scenes[name]
            bpy.context.view_layer.update()
            result[name] = geometry.geometry_multiset()
    finally:
        window.scene = bpy.data.scenes[previous]
        bpy.context.view_layer.update()
    return result


def _resolve_scene(scene, keys, placements, axis_by_key, sync, config):
    family = config['family']
    naming = family['instance_name']
    lookup = {}
    for obj in scene.objects:
        if obj.instance_type == 'COLLECTION':
            lookup.setdefault(re.sub(r'\.\d{3}$', '', obj.name), []).append(obj)
    selected = []
    bindings = []
    mesh_groups = {}
    for key in keys:
        row = placements[key]
        name = naming.format(id=row['id'], key=key)
        matches = lookup.get(name, [])
        assert len(matches) == 1, ('Missing/duplicate selected source instance', scene.name, key, name, len(matches))
        instance = matches[0]
        sync.check_pose(instance, row)
        collection = instance.instance_collection
        assert collection and not collection.children, ('Nested/absent prototype needs explicit support', name)
        affected = []
        for part in collection.objects:
            if part.type != 'MESH':
                continue
            for index, slot in enumerate(part.material_slots):
                if slot.material and slot.material.get('catalog_key') == family['material_catalog_key']:
                    assert index == family['material_slot'], ('Material slot mismatch', part.name, index)
                    affected.append(dict(part=part.name, mesh=part.data.name, slot=index,
                                         material=slot.material.name, catalog_key=family['material_catalog_key']))
        assert affected, ('No configured source material in selected instance', name)
        selected.append(dict(index=key, row=row, instance=instance, collection=collection,
                             affected_parts=affected, axis=axis_by_key[key]))
        mesh_groups.setdefault((axis_by_key[key], collection.name), []).append(selected[-1])
        bindings.append(dict(scene=scene.name, index=key, instance=instance.name,
            source_collection=collection.name))
    assert len(selected) == len(keys)
    return selected, bindings, mesh_groups


def _snapshot(config, bpy, sync, geometry, keys, placements, axis_by_key):
    scene_names = config['family']['target_scenes']
    before_inventory = stable(sync.inventory())
    selected = {}
    all_bindings = []
    groups = {}
    for name in scene_names:
        scene = bpy.data.scenes.get(name)
        assert scene, ('Missing configured target scene', name)
        records, bindings, scene_groups = _resolve_scene(scene, keys, placements, axis_by_key, sync, config)
        selected[name] = records
        all_bindings.extend(bindings)
        for group_key, rows in scene_groups.items():
            groups.setdefault(group_key, []).extend(rows)
    # Capture bindings through the already-loaded material helper in caller.
    geometry_before = _geometry_by_scene(bpy, geometry, scene_names)
    return before_inventory, selected, all_bindings, groups, geometry_before


def _expected_source_graph(source_nodes, delta, image_name, source_factor, candidate_factor):
    expected = copy.deepcopy(source_nodes)
    assert abs(float(delta['source_factor']) - source_factor) < 1e-5
    assert abs(float(delta['candidate_factor']) - candidate_factor) < 1e-5
    expected['nodes'][delta['mix_node']]['inputs'][delta['factor_socket']] = struct.unpack(
        'f', struct.pack('f', float(candidate_factor)))[0]
    nodes = [name for name, row in expected['nodes'].items()
             if row.get('type') == 'ShaderNodeTexImage' and row.get('image') == delta['source_albedo_image']]
    assert len(nodes) == 1
    expected['nodes'][nodes[0]]['image'] = image_name
    return expected


def _check_pbr(material, contract):
    bsdf = next((node for node in material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED'), None)
    assert bsdf, ('No Principled BSDF on candidate', material.name)
    roughness = float(bsdf.inputs['Roughness'].default_value)
    metallic = float(bsdf.inputs['Metallic'].default_value)
    assert not bsdf.inputs['Roughness'].is_linked and not bsdf.inputs['Metallic'].is_linked
    assert math.isclose(roughness, contract['roughness'], abs_tol=1e-6)
    assert math.isclose(metallic, contract['metallic'], abs_tol=1e-6)
    assert not bsdf.inputs['Normal'].is_linked, ('Candidate normal input must remain disconnected', material.name)
    return dict(roughness=roughness, metallic=metallic, normal_linked=False,
                ao_channel='not provided by the Blender Principled graph contract')


def _collection_contract(collection, sync):
    return dict(identity=collection.name, values=stable(sync.rna(collection)),
                props=stable(sync.props(collection)), objects=sorted(obj.name for obj in collection.objects),
                children=sorted(child.name for child in collection.children))


def _verify_collection_copy(source, target, parts, sync):
    source_contract = _collection_contract(source, sync)
    target_contract = _collection_contract(target, sync)
    source_values = copy.deepcopy(source_contract['values'])
    target_values = copy.deepcopy(target_contract['values'])
    for key in ('name', 'name_full'):
        if key in source_values and key in target_values:
            target_values[key] = source_values[key]
    assert source_values == target_values and source_contract['props'] == target_contract['props']
    assert source_contract['children'] == target_contract['children'] == []
    assert target_contract['objects'] == sorted(part['target'] for part in parts)
    return dict(source=source_contract, target=target_contract)


def _validate_inventory_delta(before, after, bindings, wrappers, material_deltas, image_name, image_sha,
                              source_factor, candidate_factor, projection_tile_metres, pbr_contract):
    """Prove no unrelated Blender ID, source graph, or source binding changed."""
    before, after = copy.deepcopy(before), copy.deepcopy(after)
    binding_by_instance = {row['instance']: row for row in bindings}
    assert len(binding_by_instance) == len(bindings)
    new_object_names = {part['target'] for wrapper in wrappers for part in wrapper['parts']}
    new_collection_names = {wrapper['target'] for wrapper in wrappers}
    new_material_names = {row['candidate'] for row in material_deltas}
    assert set(after['objects']) - set(before['objects']) == new_object_names
    assert set(after['collections']) - set(before['collections']) == new_collection_names
    assert set(after['materials']) - set(before['materials']) == new_material_names
    assert set(after['images']) - set(before['images']) == {image_name}
    assert set(before['objects']) <= set(after['objects'])
    assert set(before['collections']) <= set(after['collections'])
    assert set(before['materials']) <= set(after['materials'])
    assert set(before['images']) <= set(after['images'])

    normalized = copy.deepcopy(after)
    for name, row in binding_by_instance.items():
        obj = normalized['objects'][name]
        assert obj['instance'] == row['target_collection']
        obj['instance'] = row['source_collection']
    for name in new_object_names:
        del normalized['objects'][name]
    for name in new_collection_names:
        del normalized['collections'][name]
    for delta in material_deltas:
        source = delta['source']
        target = delta['candidate']
        assert before['materials'][source]['props'] == after['materials'][target]['props']
        values_before = copy.deepcopy(before['materials'][source]['values'])
        values_after = copy.deepcopy(after['materials'][target]['values'])
        for key in ('name', 'name_full'):
            assert values_before[key] == source and values_after[key] == target
            values_after[key] = values_before[key]
        assert values_before == values_after, ('Copied material values changed beyond identity', target)
        expected_graph = _expected_source_graph(before['materials'][source]['nodes'], delta, image_name,
                                                source_factor, candidate_factor)
        projected = delta['projected_graph']
        assert projected['base_albedo_graph'] == expected_graph
        # Projection is an additive coordinate-only graph change. Verify its
        # node/link contract in stage, then require the identical graph on audit.
        assert projected['projection']['world_space'] is True
        assert projected['projection']['tile_metres'] == projection_tile_metres
        assert projected['projection']['normal_axis'] == delta['axis']
        assert projected['final_graph'] == after['materials'][target]['nodes']
        assert projected['graph_before_projection'] == projected['base_albedo_graph']
        assert delta['candidate_pbr']['normal_linked'] is False
        assert math.isclose(delta['candidate_pbr']['roughness'], pbr_contract['roughness'], abs_tol=1e-6)
        assert math.isclose(delta['candidate_pbr']['metallic'], pbr_contract['metallic'], abs_tol=1e-6)
        del normalized['materials'][target]
    del normalized['images'][image_name]
    assert normalized == before, 'Source library inventory changed outside selected bindings and declared new IDs'
    image = after['images'][image_name]
    assert image['colorspace'] == 'sRGB' and image['packed_sha256'] == [image_sha]

    for wrapper in wrappers:
        assert after['collections'][wrapper['target']] == {
            'objects': sorted(part['target'] for part in wrapper['parts']), 'children': []}
        assert wrapper['collection_contract']['target']['objects'] == sorted(
            part['target'] for part in wrapper['parts'])
        source_values = copy.deepcopy(wrapper['collection_contract']['source']['values'])
        target_values = copy.deepcopy(wrapper['collection_contract']['target']['values'])
        for key in ('name', 'name_full'):
            if key in source_values and key in target_values:
                target_values[key] = source_values[key]
        assert source_values == target_values
        assert wrapper['collection_contract']['source']['props'] == wrapper['collection_contract']['target']['props']
        for part in wrapper['parts']:
            source = before['objects'][part['source']]
            target = after['objects'][part['target']]
            expected = copy.deepcopy(source)
            expected['collections'] = ['collection:' + wrapper['target']]
            expected['materials'] = [[slot['target_link'], slot['target_material']] for slot in part['slots']]
            assert target == expected, ('Wrapper object differs beyond collection/material binding', part['target'])
    return dict(new_wrapper_collections=len(new_collection_names), new_wrapper_objects=len(new_object_names),
                new_material_copies=len(new_material_names), packed_images=1,
                selected_placement_bindings=len(bindings))


def _safe_attempt_dir(output_root, library, attempt_id):
    assert re.fullmatch(r'[0-9a-f]{32}', attempt_id)
    root = rooted(output_root)
    path = (root / library / attempt_id).resolve()
    assert path.is_relative_to(root.resolve())
    return path


def _write_new(path, value):
    path = Path(path).resolve()
    output_root = rooted(path.parents[2].relative_to(ROOT).as_posix())
    assert path.is_relative_to(output_root.resolve())
    assert not path.exists(), ('Refuse receipt overwrite', str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    record = dict(value, schema=1, created_utc=datetime.now(timezone.utc).isoformat(),
                  tool_sha256=sha(TOOL_PATH))
    path.write_text(json.dumps(record, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    return dict(file=path.relative_to(ROOT).as_posix(), sha256=sha(path))


def stage(config_path, config_sha256, library):
    import bpy
    path, config = _config(config_path, config_sha256)
    assert library in config['libraries']
    auth = _authorization(config, library)
    inputs = _family_inputs(config)
    sync, materials, geometry, projection = _helpers(config)
    guards = _guard_inputs(config, sync, auth)
    fitted, selection, placements, axis_by_key, _projection_data = _load_contract(config, inputs, sync)
    library_row = config['libraries'][library]
    source_path = rooted(library_row['blend'])
    assert Path(bpy.data.filepath).resolve() == source_path.resolve()
    assert sha(source_path) == auth['source_blend_sha256']
    scene_names = config['family']['target_scenes']
    original_bindings = {name: materials.scene_bindings(bpy.data.scenes[name]) for name in scene_names}
    before_inventory, selected, bindings, groups, geometry_before = _snapshot(
        config, bpy, sync, geometry, selection['selected_source_keys'], placements, axis_by_key)
    assert len(bindings) == len(scene_names) * len(selection['selected_source_keys'])
    expected_group_count = config['family']['expected_partition_count']
    group_keys = set(groups)
    assert len(group_keys) == expected_group_count, ('Unexpected axis/source-collection partition count', group_keys)
    image_path = inputs['albedo']
    materials.MIX_FACTOR_SOURCE = config['family']['source_albedo_factor']
    materials.MIX_FACTOR_COMPARE = config['family']['candidate_albedo_factor']
    image = bpy.data.images.load(str(image_path), check_existing=False)
    image.name = config['family']['generated_name_prefix'] + 'PackedAlbedo'
    image.colorspace_settings.name = 'sRGB'
    image.pack()
    assert image.packed_file and sha(image_path) == config['family']['albedo_sha256']
    material_deltas, wrappers, binding_records, projection_records = [], [], [], []
    group_material_counts = {}
    for axis, collection_name in sorted(group_keys):
        group_rows = groups[(axis, collection_name)]
        materials.PREFIX = config['family']['generated_name_prefix'] + f'A{axis}_{collection_name}_'
        group_wrappers, copies, deltas, local_bindings = materials.make_wrappers(
            group_rows, config['family']['material_copy_stage'], image, sync)
        assert set(group_wrappers) == {collection_name}
        assert len(group_wrappers) == 1 and len(copies) == config['family']['materials_per_partition']
        wrapper = group_wrappers[collection_name]
        wrapper['target'].use_fake_user = wrapper['source'].use_fake_user
        for part in wrapper['parts']:
            bpy.data.objects[part['target']].use_fake_user = bpy.data.objects[part['source']].use_fake_user
        for source_name, candidate in copies.items():
            candidate.use_fake_user = bpy.data.materials[source_name].use_fake_user
        for delta in deltas:
            source_graph = before_inventory['materials'][delta['source']]['nodes']
            expected_graph = _expected_source_graph(source_graph, delta, image.name,
                config['family']['source_albedo_factor'], config['family']['candidate_albedo_factor'])
            assert sync.stable(materials.material_graph(sync, copies[delta['source']])) == expected_graph
            pbr = _check_pbr(copies[delta['source']], config['family']['pbr'])
            bsdf = next(n for n in copies[delta['source']].node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
            mix = bsdf.inputs['Base Color'].links[0].from_node
            image_node = mix.inputs[2].links[0].from_node
            assert image_node.type == 'TEX_IMAGE' and image_node.image == image
            graph_before_projection = sync.stable(materials.material_graph(sync, copies[delta['source']]))
            projection_contract = projection.add_blender(copies[delta['source']], image_node, axis,
                                                         tile_metres=config['family']['projection_tile_metres'])
            graph_after_projection = sync.stable(materials.material_graph(sync, copies[delta['source']]))
            assert projection_contract['world_space'] and projection_contract['normal_axis'] == axis
            assert projection_contract['tile_metres'] == config['family']['projection_tile_metres']
            delta = dict(delta, axis=axis, projected_graph=dict(base_albedo_graph=expected_graph,
                projection=projection_contract, graph_before_projection=graph_before_projection,
                final_graph=graph_after_projection), candidate_pbr=pbr)
            material_deltas.append(delta)
            projection_records.append(dict(material=delta['candidate'], axis=axis, **projection_contract))
        for value in group_wrappers.values():
            collection_contract = _verify_collection_copy(value['source'], value['target'], value['parts'], sync)
            wrappers.append(dict(source=value['source'].name, target=value['target'].name,
                                 parts=value['parts'], collection_contract=collection_contract))
        group_material_counts[f'{axis}|{collection_name}'] = len(copies)
        for binding in local_bindings:
            binding_records.append(dict(library=library, scene=next(
                name for name, rows in selected.items() if any(r['instance'].name == binding['instance'] for r in rows)),
                index=binding['placement_index'], instance=binding['instance'],
                source_collection=binding['source_collection'], target_collection=binding['target_collection'],
                axis=axis))
    assert len(wrappers) == expected_group_count
    assert len(material_deltas) == expected_group_count * config['family']['materials_per_partition']
    expected_bindings = len(scene_names) * len(selection['selected_source_keys'])
    assert len(binding_records) == expected_bindings
    for name in scene_names:
        expected = dict(original_bindings[name])
        expected.update({row['instance']: row['target_collection'] for row in binding_records if row['scene'] == name})
        assert materials.scene_bindings(bpy.data.scenes[name]) == expected
    after_inventory = stable(sync.inventory())
    inventory_counts = _validate_inventory_delta(before_inventory, after_inventory, binding_records,
        wrappers, material_deltas, image.name, config['family']['albedo_sha256'],
        config['family']['source_albedo_factor'], config['family']['candidate_albedo_factor'],
        config['family']['projection_tile_metres'], config['family']['pbr'])
    geometry_after = _geometry_by_scene(bpy, geometry, scene_names)
    assert geometry_after == geometry_before, 'Evaluated geometry/UV/placement changed'
    assert _guard_inputs(config, sync, auth) == guards, 'An immutable source/input changed during staging'
    attempt_id = uuid.uuid4().hex
    folder = _safe_attempt_dir(config['output_root'], library, attempt_id)
    assert not folder.exists()
    folder.mkdir(parents=True)
    staged = folder / f'{library}_{config["family_id"]}_Candidate.blend'
    assert not staged.exists()
    bpy.ops.wm.save_as_mainfile(filepath=str(staged), compress=True, relative_remap=False)
    assert staged.is_file() and sha(source_path) == auth['source_blend_sha256']
    assert _guard_inputs(config, sync, auth) == guards
    report = dict(status='DERIVED_LIBRARY_STAGE_REOPEN_AUDIT_REQUIRED', family_id=config['family_id'],
        library=library, attempt_id=attempt_id, config=path.relative_to(ROOT).as_posix(),
        config_sha256=sha(path), tool_path=TOOL_PATH.relative_to(ROOT).as_posix(),
        process_id=os.getpid(),
        accepted_source_guard_receipt={k:v for k,v in auth.items() if k != 'guard_table'},
        source_blend=library_row['blend'], source_blend_sha256=auth['source_blend_sha256'],
        staged_blend=staged.relative_to(ROOT).as_posix(), staged_blend_sha256=sha(staged),
        target_scenes=scene_names, selector_path=config['family']['selection']['path'],
        selector_sha256=config['family']['selection']['sha256'], selected_source_keys=selection['selected_source_keys'],
        selected_key_count=len(selection['selected_source_keys']), bindings=binding_records,
        source_collection_axis_groups=sorted(group_material_counts), group_material_counts=group_material_counts,
        wrappers=wrappers, candidate_materials=material_deltas, candidate_image=dict(name=image.name,
            path=config['family']['albedo']['path'], sha256=config['family']['albedo_sha256'], colorspace='sRGB', packed=True),
        projection_contracts=projection_records, inventory_counts=inventory_counts,
        inventory_before=before_inventory, inventory_after=after_inventory,
        geometry_before=geometry_before, geometry_after=geometry_after, immutable_file_guards=guards,
        boundary='New derived Blend only. Original libraries and source assets are not saved or promoted. Separate Blender process reopen audit required before any promotion or canonical library change.')
    receipt_path = folder / 'stage.json'
    return dict(status=report['status'], staged_blend=report['staged_blend'],
                staged_blend_sha256=report['staged_blend_sha256'], **_write_new(receipt_path, report))


def audit(config_path, config_sha256, library, stage_receipt, stage_receipt_sha256):
    import bpy
    path, config = _config(config_path, config_sha256)
    assert library in config['libraries']
    inputs = _family_inputs(config)
    sync, materials, geometry, _projection = _helpers(config)
    receipt_path = rooted(stage_receipt)
    output_root = rooted(config['output_root'])
    assert receipt_path.is_relative_to(output_root) and receipt_path.name == 'stage.json'
    assert sha(receipt_path) == stage_receipt_sha256
    record = read(receipt_path)
    assert record['status'] == 'DERIVED_LIBRARY_STAGE_REOPEN_AUDIT_REQUIRED'
    assert record['library'] == library and record['family_id'] == config['family_id']
    staged = rooted(record['staged_blend'])
    assert Path(bpy.data.filepath).resolve() == staged.resolve()
    assert sha(staged) == record['staged_blend_sha256']
    assert record['config_sha256'] == sha(path)
    assert record['process_id'] != os.getpid(), 'Reopen audit must run in a separate Blender process'
    assert record['accepted_source_guard_receipt']['sha256'] == config['stage_authorization']['accepted_guard_receipt']['sha256']
    guards = record['immutable_file_guards']
    assert _guard_inputs(config, sync, _authorization(config, library)) == guards
    current = stable(sync.inventory())
    assert current == record['inventory_after'], 'Reopened candidate inventory differs from stage receipt'
    _validate_inventory_delta(record['inventory_before'], current, record['bindings'], record['wrappers'],
        record['candidate_materials'], record['candidate_image']['name'], record['candidate_image']['sha256'],
        config['family']['source_albedo_factor'], config['family']['candidate_albedo_factor'],
        config['family']['projection_tile_metres'], config['family']['pbr'])
    for wrapper in record['wrappers']:
        source = bpy.data.collections.get(wrapper['source'])
        target = bpy.data.collections.get(wrapper['target'])
        assert source and target
        assert _collection_contract(source, sync) == wrapper['collection_contract']['source']
        assert _collection_contract(target, sync) == wrapper['collection_contract']['target']
    fitted, selection, placements, axis_by_key, _projection_data = _load_contract(config, inputs, sync)
    assert selection['selected_source_keys'] == record['selected_source_keys']
    scene_names = config['family']['target_scenes']
    for name in scene_names:
        scene = bpy.data.scenes[name]
        expected = {row['instance']: row['target_collection'] for row in record['bindings'] if row['scene'] == name}
        actual = materials.scene_bindings(scene)
        for instance, target in expected.items():
            assert actual[instance] == target
            binding = next(b for b in record['bindings'] if b['scene'] == name and b['instance'] == instance)
            row = placements[binding['index']]
            assert row['id'] in config['family']['placement_selector']['ids']
            sync.check_pose(bpy.data.objects[instance], row)
        # Full scene occupancy and all original non-target memberships are
        # already covered by exact inventory parity; this assertion confirms
        # that selected rows are exactly the configured source-key set.
        observed = {b['index'] for b in record['bindings'] if b['scene'] == name}
        assert observed == set(selection['selected_source_keys'])
    geometry_reopened = _geometry_by_scene(bpy, geometry, scene_names)
    assert geometry_reopened == record['geometry_before'] == record['geometry_after']
    for projection_row in record['projection_contracts']:
        contract = projection_row
        axis = contract['normal_axis']
        assert axis in (0,1) and contract['world_space'] is True
        assert contract['tile_metres'] == config['family']['projection_tile_metres']
        assert contract['tangent_axis'] == 1-axis and contract['vertical_axis'] == 2
    assert all(sha(rooted(rel)) == expected for rel, expected in guards.items())
    result = dict(status='SEPARATE_PROCESS_REOPEN_AUDIT_PASS', family_id=config['family_id'],
        library=library, stage_receipt=receipt_path.relative_to(ROOT).as_posix(),
        stage_receipt_sha256=stage_receipt_sha256, staged_blend=record['staged_blend'],
        staged_blend_sha256=record['staged_blend_sha256'], inventory_exact=True,
        geometry_exact=True, bindings_exact=True, immutable_file_guards_exact=True,
        boundary='Reopened derived Blend structural audit only; not an Unreal import, in-game visual acceptance, library promotion, or production integration.')
    audit_path = receipt_path.parent / 'reopen_audit.json'
    return dict(status=result['status'], **_write_new(audit_path, result))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--action', choices=('stage','audit'), required=True)
    parser.add_argument('--config', required=True)
    parser.add_argument('--config-sha256', required=True)
    parser.add_argument('--library', required=True)
    parser.add_argument('--stage-receipt')
    parser.add_argument('--stage-receipt-sha256')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else None)
    if args.action == 'stage':
        print(json.dumps(stage(args.config, args.config_sha256, args.library), sort_keys=True), flush=True)
    else:
        assert args.stage_receipt and args.stage_receipt_sha256
        print(json.dumps(audit(args.config, args.config_sha256, args.library,
            args.stage_receipt, args.stage_receipt_sha256), sort_keys=True), flush=True)


if __name__ == '__main__':
    main()
