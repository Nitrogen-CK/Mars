"""Derived, source-locked Well/Bell marker comparisons; never import or promote."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
OUT = REVIEW / 'bank-identity-preview/r01'
SOURCE = HERE / 'Output/WarrensVariantC_Diorama.blend'
SOURCE_SHA = '2fb8dfdfbf1a3ad1a5e019204fc679d827eda137381f4b86934fd7b71dbcc7dc'
ART = ROOT / 'docs/art/warrens-c-dressing-r01/art/painted'
PREFIX = 'BankIdentityPreview_'
MARKERS = {
    'Bell': dict(art='ART03_BellBankEmblem-r02.png', board=[92, 44.04, 1],
                 card=[92, 44.061, 1.1], yaw=0),
    'Well': dict(art='ART02_WellHoistEmblem.png', board=[29.04, 47.85, 1],
                 card=[29.061, 47.85, 1.1], yaw=-90),
}
VIEWS = {
    'bell_ford_approach': ([85, 50, 1.4], [104, 51.5, 1.5],
                         'Ford-side source standing eye/target; sign may lie outside the forward view.'),
    'bell_south_arrival': ([96, 45.5, 1.4], [98, 54, 2.5],
                         'Inside the south mouth, facing into the room; north-facing sign is behind this arrival.'),
    'well_rim_return': ([31, 50, 1.4], [25, 50, 1.4],
                       'Westward return toward the Hall; no aimed-at-sign claim.'),
    'well_hall_arrival': ([25, 50, 1.4], [31, 50, 1.4],
                         'Eastward Hall arrival; the sign faces away.'),
    'bell_attachment': ([93.4, 45.7, 1.5], [92, 44.04, 1.5],
                        'Deliberate close side inspection of actual wooden backing and wall separation.'),
    'well_attachment': ([30.7, 48.8, 1.45], [29.04, 47.85, 1.5],
                        'Deliberate close side inspection; opening clearance remains visible.'),
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def point(plan):
    return Vector((plan[0] - 58, 55 - plan[1], plan[2]))


def source_objects():
    return {o.name: dict(matrix=[list(v) for v in o.matrix_basis],
            data=o.data.name if o.data else None,
            instance=o.instance_collection.name if o.instance_collection else None,
            materials=[(s.link, s.material.name if s.material else None) for s in o.material_slots],
            hidden=(o.hide_render, o.hide_viewport))
            for o in bpy.data.objects if not o.name.startswith(PREFIX)}


def instance(scene, collection, name, at, scale, yaw):
    obj = bpy.data.objects.new(PREFIX + name, None)
    obj.instance_type = 'COLLECTION'
    obj.instance_collection = collection
    obj.location = point(at)
    obj.scale = scale
    obj.rotation_euler.z = math.radians(-yaw)
    scene.collection.objects.link(obj)
    return obj


def main():
    global OUT
    parser = argparse.ArgumentParser()
    parser.add_argument('--revision', choices=('r01', 'r02', 'r03'), default='r01')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    OUT = REVIEW / 'bank-identity-preview' / args.revision
    markers = {key: dict(spec) for key, spec in MARKERS.items()}
    views = dict(VIEWS)
    if args.revision in ('r02', 'r03'):
        markers = {'Bell': dict(MARKERS['Bell'], board=[93.7, 44.04, 1], card=[93.7, 44.061, 1.1])}
        views = {key: value for key, value in VIEWS.items() if key.startswith('bell_')}
        views['bell_shifted_attachment'] = ([95, 45.8, 1.5], [93.7, 44.04, 1.5],
            'Additional deliberate side inspection of the shifted marker; not an arrival comparison.')
    if args.revision == 'r03':
        markers['Bell'].update(board=[93.7, 44.027, 1], card=[93.7, 44.048, 1.1])
        views = {key: views[key] for key in ('bell_ford_approach', 'bell_shifted_attachment')}
    assert not OUT.exists(), 'Keep earlier candidates and receipts'
    assert sha(SOURCE) == SOURCE_SHA
    protected = {p: sha(p) for p in (SOURCE, HERE / 'Output/WarrensVariantC_KitLibrary.blend',
        HERE / 'Output/fitted_instances.json', REVIEW / 'BANK_IDENTITY_PREVIEW_REVIEW.md',
        *(ART / r['art'] for r in markers.values()))}
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    assert not any(o.name.startswith(PREFIX) for o in bpy.data.objects)
    source = bpy.data.scenes['02_VariantC_Cutaway']
    bpy.context.window.scene = source
    palette = load_module('bank_marker_source_geometry', HERE / 'build_belfry_palette.py')
    original_geometry = palette.geometry_multiset()
    original_objects = source_objects()
    fit_contacts = []
    if args.revision in ('r02', 'r03'):
        # Test the real fitted geometry on both sides of the source-wall seam.
        part = next(iter(bpy.data.collections['CCS78_MaintenanceNoticeBoard'].objects))
        wall_side = max(v.co.y for v in part.data.vertices)
        center = point(markers['Bell']['board'])
        graph = bpy.context.evaluated_depsgraph_get()
        for dx, z in ((-.44, 1.02), (.44, 1.02), (-.44, 1.98), (.44, 1.98), (0, 1.5)):
            origin = Vector((center.x + dx, center.y + wall_side - .1, z))
            hit, location, normal, index, obj, matrix = source.ray_cast(graph, origin, Vector((0, 1, 0)), distance=.2)
            assert hit and abs(normal.y) > .9, 'No fitted wall behind candidate backing'
            gap = (location - origin).length - .1
            assert -.001 <= gap <= .04, 'Backing intersects or floats away from fitted masonry'
            if args.revision == 'r03':
                assert abs(gap) < .0001, 'Measured flush correction did not reach the fitted wall'
            fit_contacts.append(dict(backing_point=[center.x + dx, center.y + wall_side, z],
                hit=list(location), normal=list(normal), source_object=obj.name, gap_metres=gap))
    scene = source.copy()
    scene.name = PREFIX + 'Comparison'
    bpy.context.window.scene = scene
    # Inherit all existing review lighting and color management; no new lights.
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x, scene.render.resolution_y = 1000, 650
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    board = bpy.data.collections['CCS78_MaintenanceNoticeBoard']
    card = bpy.data.collections['WVC083_EmblemSurfaceCarrier']
    assert len(card.objects) == len(board.objects) == 1
    template = bpy.data.materials['WarrensC_RoyalClocheCrest_Mars_MI']
    proposed, bindings = [], []
    for key, spec in markers.items():
        image = bpy.data.images.load(str(ART / spec['art']), check_existing=False)
        image.pack()
        material = template.copy()
        material.name = PREFIX + key + '_Material'
        texture, = [n for n in material.node_tree.nodes if n.type == 'TEX_IMAGE']
        texture.image = image
        variant = bpy.data.collections.new(PREFIX + key + '_Card')
        part = next(iter(card.objects)).copy()
        part.name = PREFIX + key + '_Surface'
        part.data = part.data.copy()
        part.data.materials[0] = material
        variant.objects.link(part)
        backing = instance(scene, board, key + '_Board', spec['board'], (1.3, 1, 1), spec['yaw'])
        surface = instance(scene, variant, key + '_Card', spec['card'], (4 / 3, 1, 1), spec['yaw'])
        proposed += [backing, surface]
        bindings.append(dict(key=key, **spec, image_sha256=sha(ART / spec['art']),
            backing_collection=board.name, surface_collection=variant.name,
            backing_instance=backing.name, surface_instance=surface.name,
            face='Original framed Blender -Y notice face; plan +Y reflects to Blender -Y'))
    OUT.mkdir(parents=True)
    renders = []
    for name, (eye, target, meaning) in views.items():
        data = bpy.data.cameras.new(PREFIX + name)
        camera = bpy.data.objects.new(PREFIX + name, data)
        scene.collection.objects.link(camera)
        camera.location = point(eye)
        camera.rotation_euler = (point(target) - camera.location).to_track_quat('-Z', 'Y').to_euler()
        data.sensor_width, data.lens, data.sensor_fit = 36, 18, 'HORIZONTAL'
        data.clip_start, data.clip_end = .05, 180
        scene.camera = camera
        for stage, hidden in (('before', True), ('candidate', False)):
            for obj in proposed:
                obj.hide_render = hidden
            bpy.context.view_layer.update()
            path = OUT / (name + '_' + stage + '.png')
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            renders.append(dict(view=name, state=stage, file=path.relative_to(ROOT).as_posix(),
                sha256=sha(path), eye=eye, target=target, horizontal_fov=90, meaning=meaning))
    bpy.context.window.scene = source
    bpy.context.view_layer.update()
    assert palette.geometry_multiset() == original_geometry
    assert source_objects() == original_objects
    assert all(sha(p) == value for p, value in protected.items())
    bpy.context.window.scene = scene
    preview = OUT / 'BankIdentity_SourcePreview.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(preview), compress=True, relative_remap=False)
    assert all(sha(p) == value for p, value in protected.items())
    report = dict(status='OFFLINE_CANDIDATE_REVIEW_REQUIRED', source=str(SOURCE.relative_to(ROOT)),
        source_sha256=SOURCE_SHA, source_geometry=original_geometry,
        original_objects_unchanged=len(original_objects), bindings=bindings, renders=renders,
        revision=args.revision, fitted_wall_contacts=fit_contacts,
        protected={p.relative_to(ROOT).as_posix(): h for p, h in protected.items()},
        preview=dict(file=preview.relative_to(ROOT).as_posix(), sha256=sha(preview)),
        boundary='Static source geometry and unchanged original neutral Diorama lighting. No new lights, emission, collision, focus affordances, import or live adoption. No runtime puzzle actors. Source standing-eye studies use 1.4m and 90-degree horizontal FOV; not actual played discovery.')
    (OUT / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('BANK_IDENTITY_PREVIEW_COMPLETE', len(renders), flush=True)


if __name__ == '__main__':
    main()
