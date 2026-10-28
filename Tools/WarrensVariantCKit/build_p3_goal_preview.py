"""Survey-pinned static P3 A/B. No Unreal, import, export or source Blend save."""
import argparse
import hashlib
import html
import json
import math
from pathlib import Path
import re
import sys

import bpy
from mathutils import Vector

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
SOURCE = HERE / 'Output/WarrensVariantC_Diorama.blend'
SOURCE_SHA = '2fb8dfdfbf1a3ad1a5e019204fc679d827eda137381f4b86934fd7b71dbcc7dc'
OUT = REVIEW / 'p3-goal-preview/r01'
PREFIX = 'P3GoalPreview_'
CAMERAS = {
    'plate_approach': 'ART_held_p3_plate_arrival',
    'cache_approach': 'ART_held_p3_cache_before',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write(path, value):
    assert Path(path).resolve().is_relative_to(OUT.resolve()) and not Path(path).exists()
    Path(path).write_text(json.dumps(value, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')


def scene_copy(source, name, excluded):
    """Fork collection links, retaining original mesh/material/object datablocks."""
    scene = source.copy()
    scene.name = PREFIX + name
    cache = {}

    def fork(original):
        if original.name in cache:
            return cache[original.name]
        copied = original.copy()
        copied.name = PREFIX + name + '_' + original.name
        cache[original.name] = copied
        for obj in list(copied.objects):
            if obj.name in excluded:
                copied.objects.unlink(obj)
        for child in list(copied.children):
            copied.children.unlink(child)
            copied.children.link(fork(child))
        return copied

    for child in list(scene.collection.children):
        scene.collection.children.unlink(child)
        scene.collection.children.link(fork(child))
    for obj in list(scene.collection.objects):
        if obj.name in excluded:
            scene.collection.objects.unlink(obj)
    return scene


def geometry(palette):
    return palette.geometry_multiset()


def source_inventory(sync, original_names):
    # Derived collection links add users, but cannot edit these original values.
    return dict(
        meshes={name: sync.mesh_hash(bpy.data.meshes[name]) for name in original_names['meshes']},
        materials={name: sync.nodes(bpy.data.materials[name].node_tree) for name in original_names['materials']},
        lights={name: sync.rna(bpy.data.lights[name]) for name in original_names['lights']},
        cameras={name: sync.rna(bpy.data.cameras[name]) for name in original_names['cameras']},
        collections={name: dict(objects=sorted(o.name for o in bpy.data.collections[name].objects),
                                children=sorted(c.name for c in bpy.data.collections[name].children))
                     for name in original_names['collections']})


def original_instance(scene, row, fit, sync):
    indices = [i for i, item in enumerate(fit['placements']) if item == row]
    key, = indices
    wanted = row['id'] + '_Assembly_' + str(key)
    obj, = [o for o in scene.objects if re.sub(r'\.\d{3}$', '', o.name) == wanted]
    assert obj.instance_type == 'COLLECTION' and obj.instance_collection
    sync.check_pose(obj, row)
    return obj, str(key)


def actual_view(stem):
    path = REVIEW / (stem + '.json')
    record = read(path)
    assert record['fov'] == 90 and abs(record['rotation_roll_pitch_yaw'][0]) < .000001
    assert sha(REVIEW / (stem + '.png')) == record['image_sha256']
    eye = [record['camera'][0] / 100 + 70, record['camera'][1] / 100 + 55, record['camera'][2] / 100]
    assert 1.10 < eye[2] - 2.5 < 1.14
    _, pitch, yaw = [math.radians(v) for v in record['rotation_roll_pitch_yaw']]
    direction = Vector((math.cos(pitch) * math.cos(yaw), -math.cos(pitch) * math.sin(yaw), math.sin(pitch)))
    return dict(eye=eye, direction=list(direction), metadata=path.relative_to(ROOT).as_posix(),
                metadata_sha256=sha(path), image=(REVIEW / (stem + '.png')).relative_to(ROOT).as_posix(),
                image_sha256=record['image_sha256'], meaning='Actual captured camera, unchanged orientation; no aim-at-marker adjustment.')


def deliberate_view(bank, label):
    at = bank['board']['at']
    yaw = math.radians(bank['board']['yaw'])
    normal = Vector((-math.sin(yaw), math.cos(yaw), 0))
    right = Vector((math.cos(yaw), math.sin(yaw), 0))
    center = Vector((at[0], at[1], at[2] + .5))
    eye = center + normal * 1.6 + right * .65
    return dict(eye=list(eye), target=list(center),
                meaning=label + ': deliberate attachment inspection, not an arrival or discovery camera.')


def make_camera(scene_before, scene_after, name, view, helpers):
    data = bpy.data.cameras.new(PREFIX + name)
    camera = bpy.data.objects.new(PREFIX + name, data)
    scene_before.collection.objects.link(camera)
    scene_after.collection.objects.link(camera)
    camera.location = helpers.point(view['eye'])
    direction = Vector(view['direction']) if 'direction' in view else helpers.point(view['target']) - camera.location
    camera.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    data.sensor_width, data.lens, data.sensor_fit = 36, 18, 'HORIZONTAL'
    data.clip_start, data.clip_end = .05, 180
    return camera


def review_html(report):
    pairs = []
    for view in report['views']:
        name = view['name']
        images = ''.join('<figure><img src="' + name + '_' + state + '.png"><figcaption>' + label + '</figcaption></figure>'
                         for state, label in [('before', 'A: current source'), ('after', 'B: surveyed two-marker candidate')])
        pairs.append('<section><h2>' + html.escape(name.replace('_', ' ')) + '</h2><p>' + html.escape(view['meaning']) + '</p><div class="pair">' + images + '</div></section>')
    insets = ''.join('<figure><img src="../../' + stem + '.png"><figcaption>Actual PIE: ' + html.escape(label) + '; held lantern and runtime mechanism. Separate evidence.</figcaption></figure>'
                     for label, stem in CAMERAS.items())
    page = '''<!doctype html><html lang="en"><meta charset="utf-8"><title>P3 surveyed goal markers</title>
<style>body{background:#181b20;color:#e4e0d8;font:16px/1.5 system-ui;margin:24px auto;max-width:1500px;padding:0 20px}h1,h2{font-weight:600}a{color:#b6d5e6}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{width:100%;display:block}figcaption{padding:8px;background:#242932}section{margin:30px 0}code{overflow-wrap:anywhere}@media(max-width:850px){.pair{grid-template-columns:1fr}}</style>
<h1>P3: same Mourner mark at plate and cache</h1><p>Offline source geometry comparison. Two reused CCS78 boards at scale 1 and existing WVC083 ART04 cards at scale 1. Original poster links disappear only from the derived after scene. No live placement is authorized.</p>
<p><strong>Static runtime plate and gate are absent.</strong> Neutral original source lighting is preserved; these are not game screenshots. Actual approach cameras retain their captured FOV 90, aspect 1.6 and approximately 1.12 m eye height. Attachment/removal views are explicitly deliberate inspections.</p>'''
    page += ''.join(pairs) + '<h2>Actual runtime context</h2><div class="pair">' + insets + '</div>'
    page += '<p><a href="receipt.json">Exact source, survey, camera and output hashes</a> | <a href="P3_Goal_SourcePreview.blend">Derived Blender file</a></p>'
    page += '<p>Tunable placements belong to the reviewed survey receipt; this tool never adjusts them to improve a camera. Existing behavior remains chef OR backpack occupancy, resetting slab and latched cache.</p></html>'
    (OUT / 'PREVIEW.html').write_text(page, encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--survey', required=True)
    parser.add_argument('--survey-sha256', required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    survey_path = (ROOT / args.survey).resolve()
    assert survey_path.is_relative_to((ROOT / 'Saved/WarrensCGameplay-20261024/P3GoalWallSurvey').resolve())
    assert sha(survey_path) == args.survey_sha256 and not OUT.exists()
    survey = read(survey_path)
    assert survey['status'] == 'SOURCE_GEOMETRY_SURVEY_COMPLETE'
    assert survey['source_sha256'] == sha(SOURCE) == SOURCE_SHA
    banks = {'plate': survey['candidate'], 'cache': survey['cache_candidate']}
    for bank in banks.values():
        assert bank['board']['mesh_id'] == 'CCS78' and bank['board']['scale'] == [1, 1, 1]
        assert bank['card']['mesh_id'] == 'WVC083_ART04' and bank['card']['scale'] == [1, 1, 1] and bank['card']['material'] == 'ART04'
        assert bank['board']['collision'] == bank['card']['collision'] == 'NoCollision'
    paths = [SOURCE, HERE / 'Output/WarrensVariantC_KitLibrary.blend', HERE / 'Output/fitted_instances.json',
             HERE / 'Output/asset_manifest.json', ROOT / 'Tools/ChainCrossingKit/Output/asset_manifest.json', survey_path,
             ROOT / 'docs/art/warrens-c-dressing-r01/art/painted/ART04_MournerServiceSeal.png']
    paths += [REVIEW / (stem + suffix) for stem in CAMERAS.values() for suffix in ('.json', '.png')]
    protected = {path: sha(path) for path in paths}
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    assert not any(o.name.startswith(PREFIX) for o in bpy.data.objects)
    helpers = __import__('importlib.util', fromlist=['util'])
    spec = helpers.spec_from_file_location('p3_bank_helpers', HERE / 'build_bank_marker_preview.py')
    helpers = helpers.module_from_spec(spec)
    spec.loader.exec_module(helpers)
    helpers.PREFIX = PREFIX
    palette = helpers.load_module('p3_geometry_inventory', HERE / 'build_belfry_palette.py')
    sync = palette.sync_tools()
    source = bpy.data.scenes['02_VariantC_Cutaway']
    bpy.context.window.scene = source
    original_geometry = geometry(palette)
    assert original_geometry['count'] == 32646
    names = {key: [v.name for v in getattr(bpy.data, key)] for key in ('meshes', 'materials', 'lights', 'cameras', 'collections')}
    original_inventory = source_inventory(sync, names)
    original_objects = helpers.source_objects()
    original_scene_members = sorted(o.name for o in source.objects)
    fit = read(HERE / 'Output/fitted_instances.json')
    old_board, board_key = original_instance(source, survey['source_board_row'], fit, sync)
    old_card, card_key = original_instance(source, survey['source_card_row'], fit, sync)
    assert board_key == '37274' and card_key == '37275'
    board_collection, card_collection = old_board.instance_collection, old_card.instance_collection
    assert len(board_collection.objects) == len(card_collection.objects) == 1
    card_part, = card_collection.objects
    assert len(card_part.material_slots) == 1 and card_part.material_slots[0].material
    art_material = card_part.material_slots[0].material
    image_nodes = [n for n in art_material.node_tree.nodes if n.type == 'TEX_IMAGE']
    assert len(image_nodes) == 1 and Path(image_nodes[0].image.name).stem.startswith('ART04_')
    before = scene_copy(source, 'Before', set())
    after = scene_copy(source, 'After', {old_board.name, old_card.name})
    assert old_board.name in before.objects and old_card.name in before.objects
    assert old_board.name not in after.objects and old_card.name not in after.objects
    bindings = []
    for key, bank in banks.items():
        for kind, collection in [('board', board_collection), ('card', card_collection)]:
            row = bank[kind]
            obj = helpers.instance(after, collection, key + '_' + kind, row['at'], row['scale'], row['yaw'])
            bindings.append(dict(bank=key, kind=kind, object=obj.name, collection=collection.name, row=row))
    views = {key: actual_view(stem) for key, stem in CAMERAS.items()}
    views.update(plate_attachment=deliberate_view(banks['plate'], 'Plate attachment'),
                 cache_attachment=deliberate_view(banks['cache'], 'Cache attachment'),
                 old_poster_removal=dict(eye=[54, 71, 3.62], target=[54, 68.331, 4.1],
                     meaning='Deliberate old-poster inspection; removal from after scene only. Not a player arrival.'))
    for scene in (before, after):
        scene.render.engine = 'BLENDER_EEVEE'
        scene.render.resolution_x, scene.render.resolution_y = 1280, 800
        scene.render.resolution_percentage = 100
        scene.render.image_settings.file_format = 'PNG'
    OUT.mkdir(parents=True)
    renders = []
    scene_geometry = {}
    for state, scene in [('before', before), ('after', after)]:
        bpy.context.window.scene = scene
        scene_geometry[state] = geometry(palette)
    assert scene_geometry['before'] == original_geometry and scene_geometry['after']['count'] == 32648
    for name, view in views.items():
        camera = make_camera(before, after, name, view, helpers)
        for state, scene in [('before', before), ('after', after)]:
            bpy.context.window.scene = scene
            scene.camera = camera
            path = OUT / (name + '_' + state + '.png')
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            renders.append(dict(view=name, state=state, file=path.relative_to(ROOT).as_posix(), sha256=sha(path),
                                camera_matrix=[list(v) for v in camera.matrix_world], horizontal_fov=90, aspect=1.6))
            print('P3_GOAL_RENDERED', name, state, flush=True)
    bpy.context.window.scene = source
    bpy.context.view_layer.update()
    assert geometry(palette) == original_geometry and helpers.source_objects() == original_objects
    assert source_inventory(sync, names) == original_inventory and sorted(o.name for o in source.objects) == original_scene_members
    assert all(sha(path) == expected for path, expected in protected.items())
    bpy.context.window.scene = after
    preview = OUT / 'P3_Goal_SourcePreview.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(preview), compress=True, relative_remap=False)
    assert all(sha(path) == expected for path, expected in protected.items())
    report = dict(status='OFFLINE_P3_GOAL_CANDIDATE_REVIEW_REQUIRED', source=SOURCE.relative_to(ROOT).as_posix(),
        source_sha256=SOURCE_SHA, tool_sha256=sha(__file__), survey=dict(file=args.survey, sha256=args.survey_sha256),
        old_pair=dict(source_keys=[board_key, card_key], objects=[old_board.name, old_card.name], removal='Derived after collection links only'),
        material=dict(name=art_material.name, image=image_nodes[0].image.name, reuse='Existing source material and collection; no copies or edits'),
        original_objects_unchanged=len(original_objects), original_inventory_sha256=palette.digest(original_inventory),
        source_geometry_unchanged=original_geometry, scene_geometry=scene_geometry, bindings=bindings,
        views=[dict(name=name, **view) for name, view in views.items()], renders=renders,
        protected={p.relative_to(ROOT).as_posix(): h for p, h in protected.items()},
        preview=dict(file=preview.relative_to(ROOT).as_posix(), sha256=sha(preview)),
        boundary='Static source geometry; runtime plate/gate absent. Original neutral source lights/materials retained. Actual approach cameras are fixed from separate runtime captures. Attachment views are deliberate. No live adoption or gameplay acceptance.')
    write(OUT / 'receipt.json', report)
    review_html(report)
    assert len(renders) == 10 and len(views) == 5
    print('P3_GOAL_PREVIEW_COMPLETE', str(OUT), sha(preview), flush=True)


if __name__ == '__main__':
    main()
