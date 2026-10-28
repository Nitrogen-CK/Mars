"""Build an offline, geometry-preserving Ossuary TX01 material comparison.

States A/B/C render the same static P3-derived source scene and fixed cameras.
Only selected Ossuary TX01 object-material slots change in the derived Blend.
No source Blend, fitted placement ledger, Unreal asset, or live map is written.
"""
import copy
import hashlib
import html
import importlib.util
import json
import math
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
LOOKDEV = REVIEW / 'lookdev/ossuary-painterly-r01'
OUT = LOOKDEV / 'room-preview-r02'
SOURCE = ROOT / 'Saved/WarrensCGameplay-20261024/P3GoalLibraryStage/r02/Diorama/WarrensVariantC_Diorama.blend'
SOURCE_SHA = '452772403a98c812d8582e88c045358332236db5158adacae64fba05aa090eb2'
PLACEMENTS = HERE / 'Output/fitted_instances.json'
PLACEMENTS_SHA = '67f8e8d87ab166ab7fd0cd5e285a08e02b8643c856de3bf028130271021b9d34'
PAINTERLY = LOOKDEV / 'Ossuary_PainterlyStone_Albedo_Quiet_r02.png'
PAINTERLY_SHA = '3ddb6bd818cb98422fd6594a0c6539455222e3b876f1a67cf3a91a540a4d127f'
INSPECTION = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryMaterialCandidate/receipt_uv_edges_r03.json'
INSPECTION_SHA = 'a8f4e3d90bba259d942274dac8bdcc246d31252a6d1a4269f23bf4e4d77d0970'
ROOM_VIEWS = REVIEW / 'final-room-plates/source_views/render_manifest.json'
ROOM_VIEWS_SHA = '1b99d74539eff7d8bde171aa8936656b9e3c18d0b58c996d152c0baa18311269'
ROOM_CAMERA_RECEIPT = REVIEW / 'final-room-plates/fresh_render_verification.json'
ROOM_CAMERA_SHA = '47040f50d2d32964eb7532dd871897fe84bc54e318b14649ab78d599a9e22ee8'
ROOM_SOURCE_BLEND = REVIEW / 'final-room-plates/source_views/WarrensC_CurrentRoomViews.blend'
ROOM_SOURCE_BLEND_SHA = '73585f452e76735c501bafecd8f8245a62d6d13e1a830a57068ee5a6f7b6e9f5'
P3_CAPTURE = REVIEW / 'ART_held_p3_pair_plate_after.json'
P3_CAPTURE_SHA = '305e511df8f5506ad6f1bf7ebd340eed60969b51d7d382c9a781c1531a527fc5'
P3_CAPTURE_IMAGE = REVIEW / 'ART_held_p3_pair_plate_after.png'
P3_CAPTURE_IMAGE_SHA = 'df8101a12f8de1af8abc130e74c47f16df08313e3c17512ea988a7304e56d6a9'
ROOMS_HELPER = REVIEW / 'source_views/render_source_views.py'
ROOMS_HELPER_SHA = '76f45d1772c3484d588de3598ea0a2c16ca9f66c1ccfffd1748df82255c9ce9a'
GEOMETRY_HELPER = HERE / 'build_belfry_palette.py'
GEOMETRY_HELPER_SHA = 'eec406bdc6c887a9f2a11e0c29f78bba0abac819cade82926524a8691523b7dd'
INVENTORY_HELPER = HERE / 'sync_art_libraries.py'
INVENTORY_HELPER_SHA = '5de7683ebf5829952c0b31b39d3d28ff34b070019ab61fc2da01462ca3bbbad6'
SCENE_NAME = '02_VariantC_Cutaway'
PREFIX = 'OssuaryMaterialPreview_'
MIX_FACTOR_SOURCE = 0.12
MIX_FACTOR_COMPARE = 0.60


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write(path, value):
    path = Path(path)
    assert path.resolve().is_relative_to(OUT.resolve()) and not path.exists(), ('Refuse output overwrite', path)
    path.write_text(json.dumps(value, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')


def import_file(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def input_guards():
    expected = {
        SOURCE: SOURCE_SHA,
        PLACEMENTS: PLACEMENTS_SHA,
        PAINTERLY: PAINTERLY_SHA,
        INSPECTION: INSPECTION_SHA,
        ROOM_VIEWS: ROOM_VIEWS_SHA,
        ROOM_CAMERA_RECEIPT: ROOM_CAMERA_SHA,
        ROOM_SOURCE_BLEND: ROOM_SOURCE_BLEND_SHA,
        ROOMS_HELPER: ROOMS_HELPER_SHA,
        P3_CAPTURE: P3_CAPTURE_SHA,
        P3_CAPTURE_IMAGE: P3_CAPTURE_IMAGE_SHA,
        GEOMETRY_HELPER: GEOMETRY_HELPER_SHA,
        INVENTORY_HELPER: INVENTORY_HELPER_SHA,
    }
    for path, wanted in expected.items():
        assert path.is_file() and sha(path) == wanted, ('Pinned input changed', str(path), wanted,
                                                        sha(path) if path.exists() else None)
    return {path.relative_to(ROOT).as_posix(): sha(path) for path in expected}


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def sync_tools():
    return import_file('ossuary_preview_sync', INVENTORY_HELPER)


def palette_tools():
    return import_file('ossuary_preview_geometry', GEOMETRY_HELPER)


def selected_rows(scene, placements, sync):
    by_name = {}
    for obj in scene.objects:
        if obj.instance_type == 'COLLECTION':
            by_name.setdefault(re.sub(r'\.\d{3}$', '', obj.name), []).append(obj)
    selected = []
    usages = []
    for index, row in enumerate(placements):
        if row.get('tile') != 'Ossuary' or 'ceiling' in row.get('role', '').lower() or row.get('context_proxy'):
            continue
        name = row['id'] + '_Assembly_' + str(index)
        matches = by_name.get(name, [])
        assert len(matches) == 1, ('Expected exact Ossuary source instance', index, name, len(matches))
        instance = matches[0]
        collection = instance.instance_collection
        assert collection and not collection.children, ('Unexpected nested prototype', instance.name)
        affected_parts = []
        for part in collection.objects:
            if part.type != 'MESH':
                continue
            for slot_index, slot in enumerate(part.material_slots):
                if slot.material and slot.material.get('catalog_key') == 'TX01':
                    usages.append(dict(placement_index=index, placement_id=row['id'], instance=instance.name,
                                       collection=collection.name, part=part.name, mesh=part.data.name,
                                       material_slot=slot_index, material=slot.material.name))
                    affected_parts.append(dict(part=part.name, mesh=part.data.name, slot=slot_index,
                                               material=slot.material.name))
        if affected_parts:
            # P3's two planned marker placements are intentionally moved in the
            # derived source. They are not TX01 targets; validate their presence
            # above, but enforce ledger poses only for rows this pass selects.
            sync.check_pose(instance, row)
            selected.append(dict(index=index, row=row, instance=instance, collection=collection,
                                 affected_parts=affected_parts))
    assert selected and usages, 'No Ossuary TX01 usage found'
    assert len({entry['placement_index'] for entry in usages}) == len(selected)
    return selected, usages


def material_graph(sync, material):
    return sync.nodes(material.node_tree)


def find_albedo_path(material):
    tree = material.node_tree
    bsdf = next((n for n in tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    assert bsdf and len(bsdf.inputs['Base Color'].links) == 1
    mix = bsdf.inputs['Base Color'].links[0].from_node
    assert mix.type == 'MIX_RGB' and mix.blend_type == 'MIX'
    factor = mix.inputs[0]
    assert not factor.is_linked and abs(float(factor.default_value) - MIX_FACTOR_SOURCE) < 1e-5
    image_link = next((link for link in tree.links if link.to_node == mix and link.to_socket == mix.inputs[2]), None)
    assert image_link and image_link.from_node.type == 'TEX_IMAGE' and image_link.from_node.image
    return mix, factor, image_link.from_node


def copy_state_material(original, stage, candidate_image, sync):
    result = original.copy()
    result.name = PREFIX + stage + '_' + original.name
    assert result.node_tree is not original.node_tree
    source_graph = material_graph(sync, original)
    mix, factor, image_node = find_albedo_path(result)
    factor.default_value = MIX_FACTOR_COMPARE
    if stage == 'C_r02_mix60':
        image_node.image = candidate_image
    assert abs(float(factor.default_value) - MIX_FACTOR_COMPARE) < 1e-6
    assert image_node.image == (candidate_image if stage == 'C_r02_mix60' else original.node_tree.nodes[image_node.name].image)
    candidate_graph = material_graph(sync, result)
    expected_graph = copy.deepcopy(source_graph)
    expected_graph['nodes'][mix.name]['inputs'][factor.identifier] = float(factor.default_value)
    if stage == 'C_r02_mix60':
        expected_graph['nodes'][image_node.name]['image'] = candidate_image.name
    assert candidate_graph == expected_graph, ('Unexpected copied material graph delta', original.name, stage)
    return result, dict(source=original.name, candidate=result.name, stage=stage,
                        source_graph_sha256=digest(source_graph), candidate_graph_sha256=digest(candidate_graph),
                        mix_node=mix.name, factor_socket=factor.identifier, source_factor=MIX_FACTOR_SOURCE,
                        candidate_factor=MIX_FACTOR_COMPARE,
                        source_albedo_image=original.node_tree.nodes[image_node.name].image.name,
                        candidate_albedo_image=image_node.image.name,
                        permitted_graph_changes=['Mix factor'] + (['BaseColor image reference'] if stage == 'C_r02_mix60' else []))


def make_wrappers(selected, stage, candidate_image, sync):
    import bpy
    wrappers = {}
    variant_materials = {}
    material_deltas = {}
    bindings = []
    for record in selected:
        source_collection = record['collection']
        if source_collection.name not in wrappers:
            target = source_collection.copy()
            target.name = PREFIX + stage + '_' + source_collection.name
            assert bpy.data.collections.get(target.name) == target
            originals = list(source_collection.objects)
            for old in list(target.objects):
                target.objects.unlink(old)
            part_rows = []
            for old in originals:
                assert old.type == 'MESH' and old.parent is None and not old.modifiers and not old.constraints, old.name
                part = old.copy()
                part.name = PREFIX + stage + '_' + old.name
                part.data = old.data
                target.objects.link(part)
                assert part.data is old.data and part.matrix_basis == old.matrix_basis
                slots = []
                for slot_index, slot in enumerate(part.material_slots):
                    source_slot = old.material_slots[slot_index]
                    source_material = source_slot.material
                    target_material = source_material
                    if source_material and source_material.get('catalog_key') == 'TX01':
                        key = source_material.name
                        if key not in variant_materials:
                            variant_materials[key], material_deltas[key] = copy_state_material(
                                source_material, stage, candidate_image, sync)
                        slot.link = 'OBJECT'
                        slot.material = variant_materials[key]
                        target_material = slot.material
                    else:
                        slot.link = source_slot.link
                        slot.material = source_material
                    slots.append(dict(index=slot_index, source_link=source_slot.link,
                                      target_link=slot.link, source_material=source_material.name if source_material else None,
                                      target_material=target_material.name if target_material else None))
                part_rows.append(dict(source=old.name, target=part.name, mesh=old.data.name, slots=slots))
            wrappers[source_collection.name] = dict(source=source_collection, target=target, parts=part_rows)
        wrapper = wrappers[source_collection.name]
        record['instance'].instance_collection = wrapper['target']
        bindings.append(dict(placement_index=record['index'], placement_id=record['row']['id'],
                            instance=record['instance'].name, source_collection=source_collection.name,
                            target_collection=wrapper['target'].name))
    return wrappers, variant_materials, list(material_deltas.values()), bindings


def camera_from_record(scene, record, name):
    import bpy
    from mathutils import Matrix
    data = bpy.data.cameras.new(PREFIX + name + '_Data')
    data.sensor_width = 36.0
    data.sensor_fit = 'HORIZONTAL'
    data.clip_start, data.clip_end = 0.05, 180.0
    data.type = record['camera_type']
    data.lens = float(record['lens_mm'])
    if record['camera_type'] == 'ORTHO':
        data.ortho_scale = float(record['ortho_scale'])
    obj = bpy.data.objects.new(PREFIX + name, data)
    scene.collection.objects.link(obj)
    obj.matrix_world = Matrix(record['camera_matrix'])
    return obj


def add_review_fill(scene):
    import bpy
    light_data = bpy.data.lights.new(PREFIX + 'NeutralReviewFill_Data', 'AREA')
    light_data.energy = 1800.0
    light_data.color = (1.0, 0.96, 0.9)
    light_data.shape = 'DISK'
    light_data.size = 12.0
    obj = bpy.data.objects.new(PREFIX + 'NeutralReviewFill', light_data)
    scene.collection.objects.link(obj)
    return obj


def set_fill(fill, center, height):
    from mathutils import Vector
    fill.location = (center[0], center[1], center[2] + height)
    fill.rotation_euler = (Vector(center) - fill.location).to_track_quat('-Z', 'Y').to_euler()


def add_p3_camera(scene, capture):
    import bpy
    from mathutils import Vector
    data = bpy.data.cameras.new(PREFIX + 'P3ActualCapturedView_Data')
    data.sensor_width = 36.0
    data.sensor_fit = 'HORIZONTAL'
    data.lens = 18.0  # Matches the captured horizontal FOV=90 with 36 mm sensor width.
    data.clip_start, data.clip_end = 0.05, 180.0
    obj = bpy.data.objects.new(PREFIX + 'P3ActualCapturedView', data)
    scene.collection.objects.link(obj)
    x, y, z = capture['camera']
    obj.location = (x / 100.0 + 12.0, -y / 100.0, z / 100.0)
    _, pitch_deg, yaw_deg = capture['rotation_roll_pitch_yaw']
    pitch, yaw = math.radians(pitch_deg), math.radians(yaw_deg)
    forward = Vector((math.cos(pitch) * math.cos(yaw), -math.cos(pitch) * math.sin(yaw), math.sin(pitch)))
    obj.rotation_euler = forward.to_track_quat('-Z', 'Y').to_euler()
    return obj, forward


def room_views():
    manifest = read(ROOM_VIEWS)
    records = [r for r in manifest['rooms'] if r['room_id'] == 'ROOM_ossuary']
    assert len(records) == 1 and records[0]['standing_eye_plan'] == [44.0, 65.0, 3.9]
    camera_receipt = read(ROOM_CAMERA_RECEIPT)
    rows = [r for r in camera_receipt['records'] if r['room_id'] == 'ROOM_ossuary']
    assert {r['view'] for r in rows} == {'overview', 'standing'}
    return records[0], {row['view']: row for row in rows}


def source_material_snapshots(sync):
    import bpy
    return {material.name: dict(graph=material_graph(sync, material), catalog_key=material.get('catalog_key'))
            for material in bpy.data.materials}


def assert_original_materials_unchanged(sync, snapshots):
    import bpy
    for name, expected in snapshots.items():
        material = bpy.data.materials.get(name)
        assert material is not None and material.get('catalog_key') == expected['catalog_key']
        assert material_graph(sync, material) == expected['graph'], ('Original material graph changed', name)


def scene_bindings(scene):
    return {obj.name: obj.instance_collection.name for obj in scene.objects
            if obj.instance_type == 'COLLECTION' and obj.instance_collection}


def verify_bindings(scene, before, selected, wrappers_by_stage, stage):
    actual = scene_bindings(scene)
    expected = dict(before)
    for record in selected:
        expected[record['instance'].name] = wrappers_by_stage[record['collection'].name]['target'].name
    assert actual == expected, ('Instance bindings changed outside the selected Ossuary TX01 set', stage)


def render_state(scene, state, cameras, fills, room_contract, view_record, capture, capture_forward):
    import bpy
    from mathutils import Vector
    output = []
    view = view_record
    eye = Vector((view['standing_eye_plan'][0] - 58, 55 - view['standing_eye_plan'][1], view['standing_eye_plan'][2]))
    target_plan = view['standing_target_plan']
    target = Vector((target_plan[0] - 58, 55 - target_plan[1], target_plan[2]))
    floor_z = view['source_floor_z_m']
    flat_delta = Vector((target.x - eye.x, target.y - eye.y, 0.0))
    if flat_delta.length > 18.0:
        center_xy = eye + flat_delta.normalized() * 9.0
    else:
        center_xy = Vector(((eye.x + target.x) * 0.5, (eye.y + target.y) * 0.5, 0.0))
    overview_center = Vector((center_xy.x, center_xy.y, floor_z + 1.0))
    standing_camera = cameras['standing']
    standing_center = (standing_camera.location + target) * 0.5
    actual_eye = cameras['p3'].location
    actual_center = actual_eye + capture_forward * 8.0
    render_contract = [
        ('overview', cameras['overview'], overview_center, 12.0, (1000, 650)),
        ('standing', cameras['standing'], standing_center, 8.0, (1000, 650)),
        ('p3_actual_camera_static_geometry', cameras['p3'], actual_center, 8.0, (1280, 800)),
    ]
    for label, camera, center, height, resolution in render_contract:
        set_fill(fills['main'], center, height)
        scene.camera = camera
        scene.render.resolution_x, scene.render.resolution_y = resolution
        scene.render.resolution_percentage = 100
        filename = state + '_' + label + '.png'
        filepath = OUT / filename
        scene.render.filepath = str(filepath)
        bpy.ops.render.render(write_still=True)
        assert filepath.is_file() and filepath.stat().st_size > 0
        output.append(dict(state=state, view=label, file=filename, sha256=sha(filepath),
                           camera=camera.name, matrix=[list(v) for v in camera.matrix_world],
                           resolution=list(resolution), neutral_fill_center=list(center),
                           neutral_fill_height=height,
                           camera_capture_source=(P3_CAPTURE.relative_to(ROOT).as_posix() if label.startswith('p3_') else None)))
        print('OSSUARY_PREVIEW_RENDERED', state, label, flush=True)
    return output


def preview_html(receipt):
    panels = []
    labels = {'A_current': 'A — current source material, Mix 0.12',
              'B_source_mix60': 'B — source albedo, Mix 0.60',
              'C_r02_mix60': 'C — R02 candidate albedo, Mix 0.60'}
    views = [
        ('overview', 'Current-source Ossuary overview camera'),
        ('standing', 'Current-source standing camera'),
        ('p3_actual_camera_static_geometry', 'Actual captured P3 camera transform on static geometry'),
    ]
    for view, heading in views:
        panels.append('<h2>' + html.escape(heading) + '</h2><div class="row">')
        for state in labels:
            image = next(r['file'] for r in receipt['renders'] if r['state'] == state and r['view'] == view)
            panels.append('<figure><img src="' + html.escape(image, quote=True) + '"><figcaption>' +
                          html.escape(labels[state]) + '</figcaption></figure>')
        panels.append('</div>')
    body = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Ossuary TX01 material comparison</title>
<style>body{background:#181b20;color:#e4e0d8;font:15px/1.5 system-ui;margin:22px auto;max-width:1500px;padding:0 20px}h1,h2{font-weight:500}h1{font-size:32px}h2{margin-top:32px;font-size:22px}.notice{padding:12px 16px;background:#2a3038;border-left:3px solid #d5b786}.row{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}figure{margin:0}img{width:100%;height:auto;display:block;background:#242932}figcaption{padding:7px;background:#242932;font-size:13px}a{color:#d9bd91}code{overflow-wrap:anywhere}@media(max-width:850px){.row{grid-template-columns:1fr}}</style>
<h1>Ossuary stone / controlled A–B–C</h1>
<p class="notice"><strong>Static Blender source preview, not game footage.</strong> The source is the P3-derived Diorama stage with planned P3 marker placements; runtime plate, gate, pawn, held lantern and puzzle state are not synthesized. The actual P3 capture is shown separately below as context. Review fill is neutral camera lighting, not validated gameplay lighting. The new 1254px image is an albedo candidate only; no seamlessness or production material acceptance is claimed.</p>'''
    body += ''.join(panels)
    body += '''<h2>Actual runtime context (separate source image)</h2><figure><a href="../../../ART_held_p3_pair_plate_after.png"><img src="../../../ART_held_p3_pair_plate_after.png" alt="Actual held lantern P3 plate view"></a><figcaption>Existing PIE capture with runtime pawn, held lantern, plate and seal. This is not an image of the A/B/C material renders.</figcaption></figure>
<h2>Only intended axes</h2><ul><li>A→B changes the existing TX01 Mix factor from 0.12 to 0.60.</li><li>B→C changes only the linked TX01 Base Color image to the R02 candidate; factor remains 0.60.</li><li>TX02, all non-TX01 materials, meshes, UVs, source material graphs, normal/roughness inputs and source files remain unchanged.</li><li>Each selected source placement uses a copied collection wrapper and object-slot material copy in the derived Blend. No shared source TX01 material is edited.</li></ul>
<p>Texture source: <a href="../Ossuary_PainterlyStone_Albedo_Quiet_r02.png">R02 painterly albedo</a> · <a href="../GENERATION.md">prompt and provenance</a> · <a href="assignments.json">selected source placements and assignments</a> · <a href="receipt.json">hashes and checks</a> · <a href="Ossuary_PainterlyStone_Candidate.blend">derived editable Blend</a>.</p></html>'''
    (OUT / 'PREVIEW.html').write_text(body, encoding='utf-8')


def main():
    import bpy
    from mathutils import Matrix, Vector
    assert not OUT.exists(), 'Refuse to overwrite a prior review output directory'
    guards = input_guards()
    assert sha(ROOMS_HELPER) == ROOMS_HELPER_SHA, ('Room render helper pin missing/stale', ROOMS_HELPER_SHA,
                                                  sha(ROOMS_HELPER))
    assert not OUT.exists()
    OUT.mkdir(parents=True)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    scene = bpy.data.scenes.get(SCENE_NAME)
    assert scene is not None, ('Missing source scene', SCENE_NAME)
    bpy.context.window.scene = scene
    sync = sync_tools()
    palette = palette_tools()
    placements = read(PLACEMENTS)['placements']
    selected, usages = selected_rows(scene, placements, sync)
    assert len(usages) == 1194, ('Unexpected TX01 slot usage count', len(usages))
    selected_names = {record['instance'].name for record in selected}
    original_bindings = scene_bindings(scene)
    original_materials = source_material_snapshots(sync)
    original_images = {image.name: (image.source, image.colorspace_settings.name,
                                    tuple(hashlib.sha256(packed.packed_file.data).hexdigest() for packed in image.packed_files))
                      for image in bpy.data.images}
    before_geometry = palette.geometry_multiset()
    view_record, camera_records = room_views()
    cameras = {key: camera_from_record(scene, camera_records[key], 'Ossuary_' + key)
               for key in ('overview', 'standing')}
    capture = read(P3_CAPTURE)
    assert capture['fov'] == 90.0 and capture['rotation_roll_pitch_yaw'][0] == 0.0
    cameras['p3'], capture_forward = add_p3_camera(scene, capture)
    fills = {'main': add_review_fill(scene)}
    room_helper = import_file('ossuary_source_room_views', ROOMS_HELPER)
    room_helper.setup_review_render(scene)
    scene.render.image_settings.file_format = 'PNG'
    scene.render.film_transparent = False
    bpy.context.view_layer.update()
    geometry_after_review_camera_setup = palette.geometry_multiset()
    assert geometry_after_review_camera_setup == before_geometry, 'Camera/fill setup changed source evaluated geometry'

    image = bpy.data.images.load(str(PAINTERLY), check_existing=False)
    assert image and tuple(image.size) == (1254, 1254), ('Unexpected candidate image dimensions', image.size[:])
    image.colorspace_settings.name = 'sRGB'
    image.pack()
    assert image.packed_file and sha(PAINTERLY) == PAINTERLY_SHA
    renders = []
    state_materials = {}
    state_wrappers = {}

    # State A is the original source material binding, rendered before making any copies.
    assert scene_bindings(scene) == original_bindings
    renders += render_state(scene, 'A_current', cameras, fills, None, view_record, capture, capture_forward)
    assert scene_bindings(scene) == original_bindings

    wrappers_b, materials_b, deltas_b, bindings_b = make_wrappers(selected, 'B_source_mix60', None, sync)
    state_wrappers['B_source_mix60'] = wrappers_b
    state_materials['B_source_mix60'] = dict(materials=materials_b, deltas=deltas_b,
                                              bindings=bindings_b, wrappers=wrappers_b)
    verify_bindings(scene, original_bindings, selected, wrappers_b, 'B_source_mix60')
    assert_original_materials_unchanged(sync, original_materials)
    assert {n: (v.source, v.colorspace_settings.name,
                tuple(hashlib.sha256(p.packed_file.data).hexdigest() for p in v.packed_files))
            for n, v in bpy.data.images.items() if n in original_images} == original_images
    assert palette.geometry_multiset() == before_geometry, 'B material change affected geometry'
    renders += render_state(scene, 'B_source_mix60', cameras, fills, None, view_record, capture, capture_forward)

    wrappers_c, materials_c, deltas_c, bindings_c = make_wrappers(selected, 'C_r02_mix60', image, sync)
    state_wrappers['C_r02_mix60'] = wrappers_c
    state_materials['C_r02_mix60'] = dict(materials=materials_c, deltas=deltas_c,
                                              bindings=bindings_c, wrappers=wrappers_c)
    verify_bindings(scene, original_bindings, selected, wrappers_c, 'C_r02_mix60')
    assert_original_materials_unchanged(sync, original_materials)
    assert {n: (v.source, v.colorspace_settings.name,
                tuple(hashlib.sha256(p.packed_file.data).hexdigest() for p in v.packed_files))
            for n, v in bpy.data.images.items() if n in original_images} == original_images
    after_geometry = palette.geometry_multiset()
    assert after_geometry == before_geometry, 'C material change affected evaluated geometry'
    renders += render_state(scene, 'C_r02_mix60', cameras, fills, None, view_record, capture, capture_forward)

    # The C state remains active in the editable derived Blend; source data was opened from a distinct pinned file.
    scene.camera = cameras['p3']
    scene.render.filepath = '//'
    derived = OUT / 'Ossuary_PainterlyStone_Candidate.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(derived), compress=True, relative_remap=False)
    assert derived.is_file() and sha(SOURCE) == SOURCE_SHA and sha(PLACEMENTS) == PLACEMENTS_SHA
    assert input_guards() == guards, 'A pinned source input changed during preview build'
    assert scene_bindings(scene) != original_bindings
    assert_original_materials_unchanged(sync, original_materials)
    assert palette.geometry_multiset() == before_geometry

    assignments = dict(source_blend=SOURCE.relative_to(ROOT).as_posix(), source_blend_sha256=SOURCE_SHA,
        tile='Ossuary', selected_instance_count=len(selected), tx01_material_slot_usage_count=len(usages),
        selected_instances=[dict(placement_index=r['index'], placement_id=r['row']['id'],
            instance=r['instance'].name, source_collection=r['collection'].name,
            affected_parts=r['affected_parts']) for r in selected],
        states={key: dict(binding_count=len(value['bindings']),
                          bindings=value['bindings'],
                          wrappers=[dict(source=name, candidate=info['target'].name,
                                         parts=info['parts']) for name, info in value['wrappers'].items()],
                          material_deltas=value['deltas'])
                for key, value in state_materials.items()},
        selected_source_instance_names=sorted(selected_names))
    write(OUT / 'assignments.json', assignments)
    receipt = dict(status='OFFLINE_STATIC_MATERIAL_COMPARISON_RENDERED', schema=1,
        source_guards=guards, candidate_blend=derived.name, candidate_blend_sha256=sha(derived),
        source_geometry_before=before_geometry, source_geometry_after=after_geometry,
        selected_instance_count=len(selected), tx01_material_slot_usage_count=len(usages),
        selected_instance_names=sorted(selected_names), states=[
            dict(id='A_current', change='Original source state; TX01 Mix factor 0.12.'),
            dict(id='B_source_mix60', change='Copied TX01 materials; existing albedo image; Mix factor 0.60.'),
            dict(id='C_r02_mix60', change='Copied TX01 materials; R02 albedo image; Mix factor 0.60.')],
        material_copy_deltas={key: value['deltas'] for key, value in state_materials.items()},
        renders=renders, image_candidate=dict(path=PAINTERLY.relative_to(ROOT).as_posix(), sha256=PAINTERLY_SHA,
            dimensions=list(image.size), colorspace=image.colorspace_settings.name,
            packed_in_candidate_blend=True),
        actual_runtime_context=dict(json=P3_CAPTURE.relative_to(ROOT).as_posix(), json_sha256=P3_CAPTURE_SHA,
            image=P3_CAPTURE_IMAGE.relative_to(ROOT).as_posix(), image_sha256=P3_CAPTURE_IMAGE_SHA,
            use='Separate existing PIE screenshot inset only; not the static render scene.'),
        evidence_boundary=['Static source Diorama geometry, including P3 planned art-library placements; not a live map or game capture.',
            'Runtime plate/gate, pawn, held lantern and puzzle state are not represented in the three rendered comparison states.',
            'Camera position/orientation for the plate view came from an actual capture; its Blender scene contains static geometry only.',
            'Neutral source review fill is not gameplay lighting. No seamlessness, import, normal/roughness, runtime or final-art acceptance is established.',
            'Only selected Ossuary TX01 instance collection bindings use copied wrappers/materials. TX02 and all original material IDs stay unchanged.'])
    write(OUT / 'receipt.json', receipt)
    preview_html(receipt)
    print('OSSUARY_MATERIAL_PREVIEW_COMPLETE', len(selected), len(usages), len(renders), flush=True)


if __name__ == '__main__':
    main()
