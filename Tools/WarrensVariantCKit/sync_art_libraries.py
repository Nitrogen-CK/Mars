"""Opt-in, staged Blender presentation sync. Never writes original assets.

Standard Python can run --action projection. Blender runs inventory/stage/audit
and render; no generator, exporter, Unreal import or automatic apply on import.
"""
import argparse
from array import array
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RUN_ROOT = ROOT / 'Saved/WarrensCGameplay-20261024/ArtLibrarySyncCheckpoint'
REVIEW_ROOT = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/library-sync'
OWNER = 'Mars.WarrensC.ArtLibrarySync.v1'
SUPPLEMENT = 'ApprovedAssemblies_20261024'
TARGETS = {k: HERE / ('Output/WarrensVariantC_' + k + '.blend') for k in ('KitLibrary', 'Diorama')}
INPUTS = {
    'Output/fitted_instances.json': '67f8e8d87ab166ab7fd0cd5e285a08e02b8643c856de3bf028130271021b9d34',
    'Output/asset_manifest.json': '19eb309e0c686bd4917438422017a391a391288f715a992ad8b2c599875fd10d',
    'mill_art_delta.json': '94bd7be82dddc51dde2af84b8de73a494e32e5602278f133e20b1af7e8092ad9',
    'P2SlidingSpan/Output/art_delta.json': '4e56f203770f01b50c8a8518ff192b8f2c61531c76fb22fc23ae3cc1c1fb2d3d',
    'P2SlidingSpan/readability_delta.json': '0d8487879ffb413e1ed9d1289126bc2ea1f76191b4f1ef414d40b32ffc8d13c0',
    'P2SlidingSpan/Output/asset_manifest.json': '44f5237f8633c1b7f38cdd1916d2d4dc6acab12ffd22fac41970b8a270daac8a',
    'P2SlidingSpan/Output/P2_SlidingSpan.blend': '9389b4ba71c5b821e884537adc2dbbff0f07a106cedf787f41dac8fbb39984dc',
}
PRESENTATION_POLICY = dict(version=3, context='Static Blender cutaways and Unreal Diorama only; live LI source rows unchanged',
    omitted_semantic_keys=['p2_fixture_wheel_cage', 'p2_fixture_wheel_glass', 'p2_fixture_wheel_flame'],
    reason='The actual windlass fixed mount is runtime-owned and absent from the static cutaway. Do not display unsupported lantern geometry or invent a stand/control.',
    runtime_reference='docs/art/warrens-c-gameplay-review-20261024/ART_held_sluice.png',
    runtime_reference_sha256='b2f4354066e80543d57747e91f6695aab3a41df3536ee3893bbba7dc8a53b09c')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write(path, value):
    path = Path(path)
    assert path.resolve().is_relative_to(RUN_ROOT.resolve()) or path.resolve().is_relative_to(REVIEW_ROOT.resolve())
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n', encoding='utf-8')


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def visible(row):
    return 'ceiling' not in row['role'] and not row.get('context_proxy')


def key(row):
    """Already-normalized fit_art key. Never normalize aliases a second time."""
    pose = [row['at'], row['scale'], row.get('rotation', [0, row.get('yaw', 0), 0])]
    assert all(len(v) == 3 and all(math.isfinite(n) for n in v) for v in pose), row
    assert all(v > 0 for v in row['scale']), row
    return (row['tile'], row['id'], *(tuple(round(n, 6) for n in v) for v in pose), row.get('material'), row.get('material_path'))


def projection():
    for name, expected in INPUTS.items():
        assert sha(HERE / name) == expected, 'Stale approved input: ' + name
    base = read(HERE / 'Output/fitted_instances.json')
    delta = read(HERE / 'P2SlidingSpan/Output/art_delta.json')
    fixtures = read(HERE / 'P2SlidingSpan/readability_delta.json')
    mill = read(HERE / 'mill_art_delta.json')
    assert delta['source_ledger_sha256'] == mill['source_ledger_sha256'] == INPUTS['Output/fitted_instances.json']
    old = [(i, row) for i, row in enumerate(base['placements']) if visible(row)]
    lookup = defaultdict(list)
    for i, row in old:
        lookup[key(row)].append(i)
    removals = []
    for row in delta['removed']:
        if visible(row):
            matches = lookup[key(row)]
            assert len(matches) == 1, ('Ambiguous/missing source removal', row, matches)
            removals.append(matches[0])
    assert len(removals) == len(set(removals)) == 214
    additions = [('p2_fit_' + str(i), row) for i, row in enumerate(delta['added']) if visible(row)]
    assert len(additions) == 508
    assert len(mill['add']) == 1 and mill['remove'] == mill['move'] == mill['lights'] == []
    additions += [('mill_hopper', mill['add'][0])]
    omitted = []
    for row in fixtures['placements']:
        assert row['material_override'] is None and row['collision_profile'] == 'NoCollision'
        semantic_key = 'p2_fixture_' + row['key']
        if semantic_key in PRESENTATION_POLICY['omitted_semantic_keys']:
            omitted.append(dict(semantic_key=semantic_key, source_row=row, reason=PRESENTATION_POLICY['reason'],
                runtime_reference=PRESENTATION_POLICY['runtime_reference']))
            continue
        additions.append((semantic_key, dict(tile=row['tile'], id=row['mesh_id'], mesh_id=row['mesh_id'],
            at=row['at_plan_m'], scale=row['scale'], rotation=row['rotation_pitch_yaw_roll'], role=row['support'])))
    assert len(fixtures['placements']) == 11
    assert {r['semantic_key'] for r in omitted} == set(PRESENTATION_POLICY['omitted_semantic_keys']) and len(omitted) == 3
    assert sha(ROOT / PRESENTATION_POLICY['runtime_reference']) == PRESENTATION_POLICY['runtime_reference_sha256']
    for _, row in additions:
        key(row)
    effective = [(str(i), row) for i, row in old if i not in set(removals)] + additions
    assert len(old) == 32343 and len(additions) == 517 and len(effective) == 32646
    counts = dict(Counter(row['tile'] for _, row in effective))
    assert {t: counts[t] for t in ('Mill', 'Brineworks', 'Canal', 'WaterworksW')} == dict(Mill=801, Brineworks=3667, Canal=2272, WaterworksW=4854)
    return dict(base=base, old=old, removals=removals, additions=additions, effective=effective, zones=counts,
        lights=fixtures['lights'], presentation_policy=PRESENTATION_POLICY, omitted=omitted,
        spec_sha256=digest(dict(inputs=INPUTS, presentation_policy=PRESENTATION_POLICY)),
        boundary='Static art; P2 motion, windlass/mount and P4 state remain actual runtime owners. Three windlass lantern parts omitted in static cutaways with runtime reference. Light operations are metadata only.')


def immutable_files():
    paths = set(TARGETS.values()) | {HERE / name for name in INPUTS}
    paths.add(ROOT / PRESENTATION_POLICY['runtime_reference'])
    for kit in ('ChainCrossingKit', 'PumpCisternKit', 'WarrensVariantCKit'):
        folder = HERE.parent / kit / 'Output'
        paths |= set((folder / 'FBX').glob('*.fbx')) | {folder / 'asset_manifest.json'}
        paths |= set((ROOT / 'Content/Mars/Environment' / kit / 'Meshes').glob('*.uasset'))
    paths |= set((HERE / 'P2SlidingSpan/Output/FBX').glob('*.fbx'))
    paths |= set((ROOT / 'Content/Mars/Environment/WarrensVariantCKit/P2SlidingSpan').glob('*.uasset'))
    collision = read(ROOT / 'Saved/WarrensCGameplay-20261024/StartupCheckpoint/collision_hashes.json')
    actual = set()
    for name in ('Content/CkJoltData/Mars/Maps/Warrens_VariantC_Mars_MAP', 'Content/CkJoltData/Mars/Maps/Variants/v8c'):
        actual |= {p.relative_to(ROOT).as_posix() for p in (ROOT / name).rglob('*') if p.is_file()}
    assert len(collision) == 54 and actual == set(collision)
    assert all(sha(ROOT / name) == value for name, value in collision.items()), 'Collision baseline changed'
    paths |= {ROOT / name for name in collision}
    return {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(paths)}


def plain(value):
    if value is None or isinstance(value, (bool, int, str)):
        return value
    if isinstance(value, float):
        return value if math.isfinite(value) else str(value)
    if hasattr(value, 'name_full'):
        return value.name_full
    if hasattr(value, 'to_dict'):
        return plain(value.to_dict())
    if isinstance(value, dict):
        return {k: plain(v) for k, v in value.items()}
    return [plain(v) for v in value]


def props(value):
    return {k: plain(value[k]) for k in value.keys()}


def rna(value):
    return {p.identifier: plain(getattr(value, p.identifier)) for p in value.bl_rna.properties
        if p.type in ('BOOLEAN', 'INT', 'FLOAT', 'STRING', 'ENUM') and p.identifier != 'pixels'}


def nodes(tree):
    if tree is None:
        return None
    return dict(nodes={n.name: dict(type=n.bl_idname, values=rna(n), props=props(n),
        image=n.image.name if hasattr(n, 'image') and n.image else None,
        inputs={s.identifier: plain(s.default_value) for s in n.inputs if hasattr(s, 'default_value')}) for n in tree.nodes},
        links=sorted((l.from_node.name, l.from_socket.identifier, l.to_node.name, l.to_socket.identifier) for l in tree.links))


def mesh_hash(mesh):
    h = hashlib.sha256()
    for source, attribute, size, code in [(mesh.vertices, 'co', 3, 'f'), (mesh.edges, 'vertices', 2, 'i'),
            (mesh.loops, 'vertex_index', 1, 'i'), (mesh.polygons, 'loop_start', 1, 'i'),
            (mesh.polygons, 'loop_total', 1, 'i'), (mesh.polygons, 'material_index', 1, 'i'),
            (mesh.polygons, 'use_smooth', 1, 'b')]:
        values = array(code, [0]) * (len(source) * size)
        source.foreach_get(attribute, values)
        h.update(attribute.encode() + values.tobytes())
    uvs = {}
    for layer in mesh.uv_layers:
        values = array('f', [0]) * (len(layer.data) * 2)
        layer.data.foreach_get('uv', values)
        uvs[layer.name] = hashlib.sha256(values.tobytes()).hexdigest()
    return dict(geometry_sha256=h.hexdigest(), vertices=len(mesh.vertices), polygons=len(mesh.polygons), uv=uvs,
        materials=[m.name if m else None for m in mesh.materials], props=props(mesh))


def inventory():
    import bpy
    print('SYNC_INVENTORY_BEGIN', len(bpy.data.objects), flush=True)
    images = {}
    for image in bpy.data.images:
        packs = [hashlib.sha256(p.packed_file.data).hexdigest() for p in image.packed_files]
        if image.source == 'FILE':
            assert packs, 'Unpacked original image: ' + image.name
        images[image.name] = dict(properties=rna(image), colorspace=image.colorspace_settings.name, packed_sha256=packs, props=props(image))
    print('SYNC_PACKED_IMAGES', len(images), flush=True)
    memberships = defaultdict(list)
    for col in bpy.data.collections:
        for obj in col.objects:
            memberships[obj.name].append('collection:' + col.name)
    for scene in bpy.data.scenes:
        for obj in scene.collection.objects:
            memberships[obj.name].append('scene_root:' + scene.name)
    objects = {}
    for obj in bpy.data.objects:
        objects[obj.name] = dict(type=obj.type, matrix=[list(v) for v in obj.matrix_basis],
            data=obj.data.name if obj.data else None, instance=obj.instance_collection.name if obj.instance_collection else None,
            instance_type=obj.instance_type, parent=obj.parent.name if obj.parent else None,
            hide_render=obj.hide_render, hide_viewport=obj.hide_viewport, props=props(obj),
            collections=sorted(memberships[obj.name]), users=obj.users, use_fake_user=obj.use_fake_user,
            materials=[(slot.link, slot.material.name if slot.material else None) for slot in obj.material_slots],
            modifiers=[rna(v) for v in obj.modifiers], constraints=[rna(v) for v in obj.constraints])
    scenes = {}
    for scene in bpy.data.scenes:
        scenes[scene.name] = dict(objects=sorted(o.name for o in scene.objects), camera=scene.camera.name if scene.camera else None,
            world=scene.world.name if scene.world else None, render=rna(scene.render), view=rna(scene.view_settings),
            units=rna(scene.unit_settings), props=props(scene))
    print('SYNC_SCENE_OBJECTS', len(scenes), len(objects), flush=True)
    return dict(active_scene=bpy.context.window.scene.name, objects=objects, scenes=scenes,
        meshes={m.name: mesh_hash(m) for m in bpy.data.meshes},
        materials={m.name: dict(values=rna(m), props=props(m), nodes=nodes(m.node_tree)) for m in bpy.data.materials},
        images=images, lights={v.name: rna(v) for v in bpy.data.lights}, cameras={v.name: rna(v) for v in bpy.data.cameras},
        worlds={v.name: dict(values=rna(v), nodes=nodes(v.node_tree)) for v in bpy.data.worlds},
        collections={v.name: dict(objects=sorted(o.name for o in v.objects), children=sorted(c.name for c in v.children)) for v in bpy.data.collections})


def stable(value):
    """Keep captured runtime bookkeeping in reports, exclude it from file parity."""
    transient = {'session_uid', 'users', 'tag', 'has_data', 'is_dirty'}
    if isinstance(value, dict):
        return {k: stable(v) for k, v in value.items() if k not in transient}
    if isinstance(value, (list, tuple)):
        return [stable(v) for v in value]
    return value


def scene_rows(data):
    return {'02_VariantC_Cutaway': data['old'], **{'Zone_' + tile: [(i, row) for i, row in data['old'] if row['tile'] == tile]
        for tile in data['base']['pivots']}}


def check_pose(obj, row):
    assert obj.parent is None and obj.instance_type == 'COLLECTION', obj.name
    rotation = row.get('rotation', [0, row.get('yaw', 0), 0])
    expected = [(row['at'][0] - 58, 55 - row['at'][1], row['at'][2]), row['scale'],
        [math.radians(v) for v in (rotation[2], -rotation[0], -rotation[1])]]
    for actual, wanted in zip((obj.location, obj.scale, obj.rotation_euler), expected):
        assert max(abs(a - b) for a, b in zip(actual, wanted)) < .00001, ('Pose mismatch', obj.name, list(actual), wanted)


def original_rows(data):
    """Resolve every baseline object, preserving multiplicity and actual aliases."""
    import bpy
    assert set(bpy.data.scenes) == set(bpy.data.scenes.get(n) for n in ['01_VariantCLibrary', *scene_rows(data)]), 'Unknown/missing original scene'
    resolved, aliases = {}, {}
    membership = Counter(o.name for scene in bpy.data.scenes for o in scene.objects)
    for scene_name, rows in scene_rows(data).items():
        scene = bpy.data.scenes[scene_name]
        indexed = defaultdict(list)
        for obj in scene.objects:
            if obj.instance_type == 'COLLECTION':
                indexed[re.sub(r'\.\d{3}$', '', obj.name)].append(obj)
        assert len(indexed) == len(rows) and sum(map(len, indexed.values())) == len(rows), ('Unexpected instance roster', scene_name)
        found = {}
        for i, row in rows:
            candidates = indexed[row['id'] + '_Assembly_' + str(i)]
            assert len(candidates) == 1, ('Missing/ambiguous saved row', scene_name, i)
            obj = candidates[0]
            check_pose(obj, row)
            assert membership[obj.name] == 1, ('Unexpected shared assembly object', obj.name)
            col = obj.instance_collection
            if row['id'] in aliases:
                assert aliases[row['id']] == col, ('Material alias differs by scene', row['id'])
            aliases[row['id']] = col
            found[i] = obj
        resolved[scene_name] = found
        print('SYNC_PREFLIGHT_SCENE', scene_name, len(found), flush=True)
    manifest = read(HERE / 'Output/asset_manifest.json')
    library = [o for o in bpy.data.scenes['01_VariantCLibrary'].objects if o.instance_type == 'COLLECTION']
    assert len(library) == 196
    expected_ids = {r['id'] for r in manifest['assets'] + manifest['shared_assets']}
    assert {o.name.removesuffix('_Library') for o in library} == expected_ids
    for obj in library:
        ident = obj.name.removesuffix('_Library')
        if ident in aliases:
            assert aliases[ident] == obj.instance_collection
        aliases[ident] = obj.instance_collection
    for _, row in data['additions']:
        assert row['id'] in aliases, ('Missing reviewed collection', row['id'])
        assert any(o.type == 'MESH' for o in aliases[row['id']].objects), row['id']
    return resolved, aliases


def add_instance(scene, col, name, row, semantic_key):
    import bpy
    assert bpy.data.objects.get(name) is None, 'Unrecorded sync object: ' + name
    obj = bpy.data.objects.new(name, None)
    obj.instance_type = 'COLLECTION'
    obj.instance_collection = col
    scene.collection.objects.link(obj)
    obj.location = (row['at'][0] - 58, 55 - row['at'][1], row['at'][2])
    obj.scale = row['scale']
    p, y, r = row.get('rotation', [0, row.get('yaw', 0), 0])
    obj.rotation_euler = [math.radians(v) for v in (r, -p, -y)]
    obj['sync_owner'] = OWNER
    obj['sync_key'] = semantic_key
    obj['source_mesh_id'] = row.get('mesh_id', row['id'])
    obj['source_row_sha256'] = digest(row)
    obj['collision_policy'] = 'Visual only; no rigid body or gameplay collision'
    check_pose(obj, row)
    return obj


def supplement(aliases):
    import bpy
    from mathutils import Vector
    assert bpy.data.scenes.get(SUPPLEMENT) is None
    scene = bpy.data.scenes.new(SUPPLEMENT)
    original = bpy.data.scenes['01_VariantCLibrary']
    scene.world = original.world
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
    scene.view_settings.view_transform = original.view_settings.view_transform
    scene.view_settings.look = original.view_settings.look
    # These are linked collection displays in a separate scene, not catalogue entries.
    mill_z = read(HERE / 'mill_art_delta.json')['add'][0]['at'][2] - 5
    for ident, z in [('WVC023', 0), ('WVC062', mill_z)]:
        row = dict(id=ident, at=[118, 55, z], scale=[1, 1, 1], yaw=0)
        add_instance(scene, aliases[ident], 'Sync_MillExample_' + ident, row, 'mill_example_' + ident)
    manifest = read(HERE / 'P2SlidingSpan/Output/asset_manifest.json')
    names = [row['name'] for row in manifest['assets']]
    with bpy.data.libraries.load(str(HERE / 'P2SlidingSpan/Output/P2_SlidingSpan.blend'), link=False) as (src, dst):
        assert all(n in src.objects for n in names)
        dst.objects = names
    for index, (asset, obj) in enumerate(zip(manifest['assets'], dst.objects)):
        assert obj and obj.type == 'MESH' and obj.name == asset['name']
        assert [m.get('catalog_key') for m in obj.data.materials] == asset['material_keys']
        bounds = [[min(v.co[k] for v in obj.data.vertices) * 100 for k in range(3)],
                  [max(v.co[k] for v in obj.data.vertices) * 100 for k in range(3)]]
        assert all(abs(a-b) < .001 for side, wanted in zip(bounds, (asset['bounds_min_cm'], asset['bounds_max_cm'])) for a,b in zip(side,wanted))
        col = bpy.data.collections.new('SyncCard_' + asset['id'])
        col.objects.link(obj)
        row = dict(id=asset['id'], at=[106 + 12*index, 37, 0], scale=[1, 1, 1], yaw=0)
        add_instance(scene, col, 'Sync_AssetCard_' + asset['id'], row, 'asset_card_' + asset['id'])
    for image in bpy.data.images:
        if image.source == 'FILE' and not image.packed_file:
            image.pack()
    # Supplemental display reuses original light datablocks, without changing them.
    for index, light in enumerate(o for o in original.objects if o.type == 'LIGHT'):
        obj = light.copy()
        obj.name = 'Sync_SupplementLight_' + str(index)
        obj['sync_owner'] = OWNER
        scene.collection.objects.link(obj)
    camera_data = bpy.data.cameras.new('Sync_SupplementCamera')
    camera = bpy.data.objects.new(camera_data.name, camera_data)
    scene.collection.objects.link(camera)
    camera.location = (83, -24, 36)
    camera.rotation_euler = (Vector((60, 8, 1)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = 45
    scene.camera = camera
    return scene


def retain_original_orphans():
    """Approved persistence repair: retain two existing unlinked utility objects."""
    import bpy
    names = {'Cube.002': 'Cube.255', 'Cube.003': 'Cube.256'}
    archive = bpy.data.collections.new('Sync_UnlinkedOriginalArchive')
    archive.use_fake_user = True
    for name, mesh in names.items():
        obj = bpy.data.objects[name]
        assert obj.users == 0 and not obj.use_fake_user and not obj.users_collection and not obj.users_scene
        assert obj.type == 'MESH' and obj.data.name == mesh
        archive.objects.link(obj)
        assert obj.users == 1
    return dict(collection=archive.name, objects=sorted(names), exemption='Only users0->1 and new unlinked archive membership; object data/materials/UV/transform remain exact.')


def unchanged_audit(before, after, changes):
    removed = set(changes['removed'])
    assert after['active_scene'] == before['active_scene']
    for name, old in before['objects'].items():
        if name in removed:
            assert name not in after['objects'], name
        else:
            expected = dict(old)
            if name in changes['archive']['objects']:
                assert old['users'] == 0 and after['objects'][name]['users'] == 1
                assert old['collections'] == []
                expected['collections'] = ['collection:' + changes['archive']['collection']]
            assert stable(after['objects'].get(name)) == stable(expected), ('Original object changed', name)
    for table in ('meshes', 'materials', 'images', 'lights', 'cameras', 'worlds', 'collections'):
        for name, old in before[table].items():
            assert stable(after[table].get(name)) == stable(old), ('Original data changed', table, name)
    for name, old in before['scenes'].items():
        current = after['scenes'][name]
        assert {k:v for k,v in current.items() if k != 'objects'} == {k:v for k,v in old.items() if k != 'objects'}, ('Scene settings changed', name)
        expected = (set(old['objects']) - removed) | set(changes['added_by_scene'].get(name, []))
        assert set(current['objects']) == expected, ('Scene roster differs', name)
    assert len(after['scenes']) == len(before['scenes']) + 1 and SUPPLEMENT in after['scenes']
    assert set(after['lights']) == set(before['lights']), 'Unexpected new light data'
    archive = after['collections'][changes['archive']['collection']]
    assert archive == dict(objects=changes['archive']['objects'], children=[])
    assert all(not set(changes['archive']['objects']) & set(v['objects']) for v in after['scenes'].values())
    return dict(unchanged_objects=len(before['objects'])-len(removed), original_meshes=len(before['meshes']),
        original_materials=len(before['materials']), original_packed_images=len(before['images']),
        original_lights=len(before['lights']), original_cameras=len(before['cameras']),
        retained_unlinked_archive=changes['archive'],
        excluded_runtime_bookkeeping=['session_uid', 'users', 'tag', 'has_data', 'is_dirty'])


def effective_audit(data, before, changes):
    import bpy
    counts = {}
    manifest = read(HERE / 'Output/asset_manifest.json')
    lib = bpy.data.scenes['01_VariantCLibrary']
    assert len([o for o in lib.objects if o.instance_type == 'COLLECTION']) == manifest['library_entries'] == 196
    for name, base_rows in scene_rows(data).items():
        scene = bpy.data.scenes[name]
        tile = None if name == '02_VariantC_Cutaway' else name.removeprefix('Zone_')
        expected = [(k,r) for k,r in data['effective'] if tile is None or r['tile'] == tile]
        instances = [o for o in scene.objects if o.instance_type == 'COLLECTION']
        assert len(instances) == len(expected), ('Effective count', name, len(instances), len(expected))
        by_key = defaultdict(list)
        for obj in instances:
            if obj.get('sync_owner') == OWNER:
                by_key[obj['sync_key']].append(obj)
        additions = [(k,r) for k,r in data['additions'] if tile is None or r['tile'] == tile]
        assert set(by_key) == {k for k,_ in additions}
        for k, row in additions:
            assert len(by_key[k]) == 1, ('Duplicated sync row', name, k)
            obj = by_key[k][0]
            check_pose(obj, row)
            assert obj['source_row_sha256'] == digest(row) and not obj.rigid_body
            assert obj.instance_collection.name == changes['aliases'][row['id']], ('Wrong material alias', obj.name)
        counts[name] = len(instances)
    after = inventory()
    report = unchanged_audit(before, after, changes)
    report.update(counts=counts, catalog_entries=196, supplemental_asset_cards=3, supplemental_mill_instances=2,
        new_light_datablocks=0, source_metadata_only=True)
    return report, after


def stage(data, folder, checkpoint):
    import bpy
    stage_path = folder / 'Staged' / Path(checkpoint['source']).name
    receipt_path = folder / 'stage.json'
    before = read(folder / 'original_inventory.json')
    assert sha(folder / 'original_inventory.json') == checkpoint['inventory_sha256']
    if receipt_path.exists():
        receipt = read(receipt_path)
        assert receipt['status'] == 'STAGED' and receipt['spec_sha256'] == data['spec_sha256'], 'Incomplete/stale stage; stop'
        assert sha(stage_path) == receipt['stage_sha256'] and receipt['tool_sha256'] == sha(__file__), 'Stage/tool changed'
        bpy.ops.wm.open_mainfile(filepath=str(stage_path))
        audit, _ = effective_audit(data, before, receipt['changes'])
        print('SYNC_STAGED_NOOP', json.dumps(dict(operations=0, audit=audit)), flush=True)
        return
    assert not stage_path.exists(), 'Unreceipted staged file'
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / checkpoint['source']))
    assert stable(inventory()) == stable(before), 'Original inventory changed since checkpoint'
    resolved, aliases = original_rows(data)
    assert not any(o.get('sync_owner') == OWNER for o in bpy.data.objects), 'Unrecorded sync ownership'
    changes = dict(removed=[], added_by_scene={}, aliases={k:v.name for k,v in aliases.items()})
    # Every original and collection has been validated before the first mutation.
    for name, objects in resolved.items():
        scene = bpy.data.scenes[name]
        tile = None if name == '02_VariantC_Cutaway' else name.removeprefix('Zone_')
        for i in data['removals']:
            if i in objects:
                obj = objects[i]
                changes['removed'].append(obj.name)
                bpy.data.objects.remove(obj, do_unlink=True)
        added = []
        for ident, row in data['additions']:
            if tile is not None and row['tile'] != tile:
                continue
            obj = add_instance(scene, aliases[row['id']], 'Sync_' + name + '_' + ident, row, ident)
            added.append(obj.name)
        changes['added_by_scene'][name] = added
    supplement(aliases)
    changes['archive'] = retain_original_orphans()
    metadata = bpy.data.texts.new('ArtLibrarySync_Metadata.json')
    metadata.write(json.dumps(dict(owner=OWNER, spec_sha256=data['spec_sha256'], lights=data['lights'],
        presentation_policy=data['presentation_policy'], omitted=data['omitted'],
        boundary=data['boundary'], p4_material_authority='Tools/WarrensVariantCKit/p4_art.py; ArtCheckpoint/P4_Belfry.json; actual runtime indicators only.'), indent=2))
    audit, _ = effective_audit(data, before, changes)
    write(receipt_path, dict(status='PREPARED', spec_sha256=data['spec_sha256'], changes=changes))
    stage_path.parent.mkdir(parents=True)
    assert 'relative_remap' in bpy.ops.wm.save_as_mainfile.get_rna_type().properties
    bpy.ops.wm.save_as_mainfile(filepath=str(stage_path), compress=True, relative_remap=False)
    bpy.ops.wm.open_mainfile(filepath=str(stage_path))
    reopened, snap = effective_audit(data, before, changes)
    assert audit == reopened
    assert immutable_files() == checkpoint['immutable'], 'Protected input changed'
    write(folder / 'staged_inventory.json', snap)
    receipt = dict(status='STAGED', stage_path=stage_path.relative_to(ROOT).as_posix(), stage_sha256=sha(stage_path),
        source_sha256=checkpoint['sha256'], spec_sha256=data['spec_sha256'], tool_sha256=sha(__file__), changes=changes,
        audit=reopened, boundary=data['boundary'])
    write(receipt_path, receipt)
    print('SYNC_STAGED', json.dumps({k:v for k,v in receipt.items() if k!='changes'}), flush=True)


def render(args, folder, checkpoint):
    """Render temporary cameras only; never resave source or staged geometry."""
    import bpy
    from mathutils import Vector
    receipt = read(folder / 'stage.json')
    assert receipt['status'] == 'STAGED' and sha(ROOT / receipt['stage_path']) == receipt['stage_sha256']
    views = {
        'Mill_overview': ([102, 111, 11.5], [95, 100.5, 6.5]),
        'Mill_player': ([91.1439, 103.1008, 6.123], [94.9739, 99.8868, 5.06]),
        'Mill_stair': ([98, 106, 6.12], [93, 102, 6]),
        'P2_windlass': ([122, 9.7, -1.1], [122, 13, -1.2]),
        'P2_west': ([67.1, 20, -1.38], [71, 20, -1.3]),
        'P2_east': ([90.9, 20, -1.38], [86, 20, -1.3]),
    }
    wanted = args.views.split(',') if args.views else (list(views) if args.target == 'Diorama' else ['Assemblies'])
    assert set(wanted).issubset(set(views) | {'Assemblies'})
    out = REVIEW_ROOT / args.run / args.target
    out.mkdir(parents=True, exist_ok=True)
    records = []
    point = lambda at: Vector((at[0]-58, 55-at[1], at[2]))
    for state, path in [('before', ROOT / checkpoint['source']), ('staged', ROOT / receipt['stage_path'])]:
        bpy.ops.wm.open_mainfile(filepath=str(path))
        original = read(folder / 'original_inventory.json')
        if state == 'before':
            assert stable(inventory()) == stable(original)
        else:
            effective_audit(projection(), original, receipt['changes'])
        for name in wanted:
            if name == 'Assemblies' and state == 'before':
                continue
            scene = bpy.data.scenes[SUPPLEMENT if name == 'Assemblies' else '02_VariantC_Cutaway']
            bpy.context.window.scene = scene
            if name != 'Assemblies':
                data = bpy.data.cameras.new('Sync_RenderCamera_' + name)
                camera = bpy.data.objects.new(data.name, data)
                scene.collection.objects.link(camera)
                eye, target = views[name]
                camera.location = point(eye)
                camera.rotation_euler = (point(target)-camera.location).to_track_quat('-Z', 'Y').to_euler()
                data.angle = math.radians(90)
                data.clip_start = .05
                data.clip_end = 250
                scene.camera = camera
            scene.render.engine = 'BLENDER_EEVEE'
            scene.render.resolution_x = 1000
            scene.render.resolution_y = 650
            scene.render.resolution_percentage = 100
            scene.render.image_settings.file_format = 'PNG'
            file = out / (state + '_' + name + '.png')
            assert not file.exists(), 'Do not overwrite existing render evidence'
            scene.render.filepath = str(file)
            bpy.ops.render.render(write_still=True)
            records.append(dict(state=state, view=name, file=file.relative_to(ROOT).as_posix(), sha256=sha(file),
                camera_matrix=[list(v) for v in scene.camera.matrix_world], lens=scene.camera.data.lens,
                world=scene.world.name, lighting_sha256=digest(stable(dict(world=nodes(scene.world.node_tree),
                lights={o.name: dict(data=rna(o.data), matrix=[list(v) for v in o.matrix_world]) for o in scene.objects if o.type == 'LIGHT'})))))
            print('SYNC_RENDER', state, name, sha(file), flush=True)
    for name in wanted:
        pair = [row for row in records if row['view'] == name]
        if name != 'Assemblies':
            assert len(pair) == 2
            for field in ('camera_matrix', 'lens', 'world', 'lighting_sha256'):
                assert pair[0][field] == pair[1][field], ('Unmatched render context', name, field)
    assert immutable_files() == checkpoint['immutable'] and sha(ROOT / receipt['stage_path']) == receipt['stage_sha256']
    write(out / 'renders.json', dict(records=records, source_sha256=checkpoint['sha256'], stage_sha256=receipt['stage_sha256'],
        boundary='Actual source/staged static artwork, EEVEE with unchanged saved neutral world/lights/exposure and matched temporary cameras. No runtime actors, P2 moving span/guards/windlass, P4 state, practical-light trial or game-light proof. Render settings were not saved.'))
    print('SYNC_RENDER_COMPLETE', len(records), flush=True)


def run(args):
    data = projection()
    if args.action == 'projection':
        print('SYNC_PROJECTION', json.dumps(dict(old=len(data['old']), remove=len(data['removals']), add=len(data['additions']), effective=len(data['effective']), zones=data['zones'])))
        return
    import bpy
    assert args.target and args.run and Path(args.run).name == args.run
    folder = RUN_ROOT / args.run / args.target
    source = TARGETS[args.target]
    assert args.source_sha and sha(source) == args.source_sha, 'Reviewed original hash required'
    if args.action == 'inventory':
        assert not folder.exists(), 'Inventory/checkpoint already exists; select a fresh run'
        before = immutable_files()
        bpy.ops.wm.open_mainfile(filepath=str(source))
        snap = inventory()
        folder.mkdir(parents=True)
        backup = folder / source.name
        shutil.copy2(source, backup)
        assert sha(backup) == args.source_sha
        write(folder / 'original_inventory.json', snap)
        write(folder / 'checkpoint.json', dict(source=source.relative_to(ROOT).as_posix(), sha256=args.source_sha,
            backup=str(backup.relative_to(ROOT)), inventory_sha256=sha(folder / 'original_inventory.json'), immutable=before))
        assert immutable_files() == before
        print('SYNC_INVENTORY', json.dumps(dict(target=args.target, active=snap['active_scene'], scenes={k: len(v['objects']) for k,v in snap['scenes'].items()},
            meshes=len(snap['meshes']), materials=len(snap['materials']), images=len(snap['images']), lights=len(snap['lights']), cameras=len(snap['cameras']))))
        return
    checkpoint = read(folder / 'checkpoint.json')
    assert checkpoint['sha256'] == args.source_sha and immutable_files() == checkpoint['immutable']
    if args.action == 'stage':
        stage(data, folder, checkpoint)
        return
    if args.action == 'audit':
        receipt = read(folder / 'stage.json')
        assert receipt['status'] == 'STAGED' and sha(ROOT / receipt['stage_path']) == receipt['stage_sha256']
        assert receipt['spec_sha256'] == data['spec_sha256']
        bpy.ops.wm.open_mainfile(filepath=str(ROOT / receipt['stage_path']))
        audit, _ = effective_audit(data, read(folder / 'original_inventory.json'), receipt['changes'])
        write(folder / 'reopened_audit.json', dict(stage_sha256=receipt['stage_sha256'], audit=audit, immutable=immutable_files()))
        print('SYNC_REOPENED_AUDIT', json.dumps(audit), flush=True)
        return
    if args.action == 'render':
        render(args, folder, checkpoint)
        return


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--action', required=True, choices=('projection', 'inventory', 'stage', 'audit', 'render'))
    parser.add_argument('--target', choices=tuple(TARGETS))
    parser.add_argument('--source-sha')
    parser.add_argument('--run')
    parser.add_argument('--views', help='Comma-separated known source views; render only, never saved')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else None)
    run(args)


if __name__ == '__main__':
    main()
