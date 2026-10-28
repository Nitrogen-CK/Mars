"""Headless A/B/C previews from finite source-key manifests; original files stay intact."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
HELPERS = {'materials': ('build_ossuary_material_candidate.py', 'f8840b9e13f060c9c01ac83dc403e3fc30c8f574f2d1c9ce4d196f64d82f7948'),
           'sync': ('sync_art_libraries.py', '5de7683ebf5829952c0b31b39d3d28ff34b070019ab61fc2da01462ca3bbbad6'),
           'geometry': ('build_belfry_palette.py', 'eec406bdc6c887a9f2a11e0c29f78bba0abac819cade82926524a8691523b7dd')}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_helpers():
    result = {}
    for name, (filename, expected) in HELPERS.items():
        path = HERE / filename
        assert sha(path) == expected
        spec = importlib.util.spec_from_file_location('_surface_preview_' + name, path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        result[name] = module
    return result['materials'], result['sync'], result['geometry']


def main():
    import bpy
    from mathutils import Vector
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source-sha256','selection','selection-sha256','image','image-sha256','views','views-sha256','output'):
        parser.add_argument('--' + name, required=True)
    parser.add_argument('--projection-comparison', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    paths = {name: (ROOT / getattr(args, name)).resolve() for name in ('selection','image','views','output')}
    assert all(path.is_relative_to(ROOT) for path in paths.values())
    source = Path(bpy.data.filepath).resolve()
    assert source == (HERE / 'Output/WarrensVariantC_Diorama.blend').resolve()
    assert sha(source) == args.source_sha256
    guards = {source.relative_to(ROOT).as_posix(): args.source_sha256}
    for name in ('selection','image','views'):
        expected = getattr(args, name + '_sha256')
        assert sha(paths[name]) == expected
        guards[paths[name].relative_to(ROOT).as_posix()] = expected
    selection, views = [json.loads(paths[name].read_text()) for name in ('selection','views')]
    for path, expected in selection['inputs'].items():
        assert sha(ROOT / path) == expected
        guards[path] = expected
    materials, sync, geometry = load_helpers()
    guards.update(sync.immutable_files())
    output = paths['output']
    assert not output.exists()
    output.mkdir(parents=True)
    scene = bpy.data.scenes['02_VariantC_Cutaway']
    bpy.context.window.scene = scene
    bpy.context.view_layer.update()
    before_geometry = geometry.geometry_multiset()
    before_bindings = materials.scene_bindings(scene)
    before_materials = materials.source_material_snapshots(sync)
    fit = json.loads((HERE / 'Output/fitted_instances.json').read_text())['placements']
    by_name = {}
    for obj in scene.objects:
        if obj.instance_type == 'COLLECTION':
            by_name.setdefault(re.sub(r'\.\d{3}$', '', obj.name), []).append(obj)
    selected = []
    for key in selection['selected_source_keys']:
        row = fit[key]
        assert row['role'] in ('source exposed wall veneer','source wall seam backing')
        assert row['id'] in ('CCS15','BACKING_TX01')
        obj, = by_name[row['id'] + '_Assembly_' + str(key)]
        sync.check_pose(obj, row)
        collection = obj.instance_collection
        affected = [dict(part=part.name, mesh=part.data.name, slot=index, material=slot.material.name)
                    for part in collection.objects if part.type == 'MESH'
                    for index, slot in enumerate(part.material_slots)
                    if slot.material and slot.material.get('catalog_key') == 'TX01']
        assert affected and all(part['slot'] == 0 for part in affected)
        selected.append(dict(index=key, row=row, instance=obj, collection=collection, affected_parts=affected))
    assert len(selected) == len(set(selection['selected_source_keys'])) == selection['selected_wall_instances']
    materials.PREFIX = 'SurfacePreview_' + output.name + '_'
    image = bpy.data.images.load(str(paths['image']), check_existing=False)
    image.name = materials.PREFIX + 'Albedo'
    image.colorspace_settings.name = 'sRGB'
    image.pack()
    cameras = []
    for record in views['views']:
        if 'camera_record' in record:
            assert sha(ROOT / record['source_receipt']) == record['source_sha256']
            camera = materials.camera_from_record(scene, record['camera_record'], record['id'])
        else:
            data = bpy.data.cameras.new(materials.PREFIX + record['id'])
            data.lens, data.sensor_width, data.sensor_fit = record['lens_mm'], 36, 'HORIZONTAL'
            data.clip_start, data.clip_end = .05, 180
            camera = bpy.data.objects.new(data.name, data)
            scene.collection.objects.link(camera)
            eye, target = [Vector((p[0]-58,55-p[1],p[2])) for p in (record['eye_plan'],record['target_plan'])]
            camera.location = eye
            camera.rotation_euler = (target-eye).to_track_quat('-Z','Y').to_euler()
        cameras.append((record['id'], camera))
    fill = materials.add_review_fill(scene)
    bpy.context.view_layer.update()
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.image_settings.file_format = 'PNG'
    scene.render.resolution_x, scene.render.resolution_y = 1000,650
    scene.render.resolution_percentage = 100
    renders, changes = [], {}
    base_prefix = materials.PREFIX
    stages = ('C_mesh','D_world2m') if args.projection_comparison else ('A_current','B_source_mix60','C_r02_mix60')
    projection = None
    if args.projection_comparison:
        projection_file = HERE / 'physical_wall_projection.py'
        assert sha(projection_file) == 'e13fe14bf907ce3eb88b8a7c64323c3379eb80184bdf2a855616af3162549a85'
        spec = importlib.util.spec_from_file_location('_surface_preview_projection', projection_file)
        projection = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(projection)
        guards[projection_file.relative_to(ROOT).as_posix()] = sha(projection_file)
    for stage in stages:
        if stage != 'A_current':
            materials.PREFIX = base_prefix + stage + '_'
            if stage == 'D_world2m':
                axis_by_key = {key: pair['axis'] for pair in selection['pairs'] for key in pair['source_keys']}
                assert set(axis_by_key) == set(selection['selected_source_keys'])
                deltas, bindings, projected = [], [], []
                for axis in (0,1):
                    group = [r for r in selected if axis_by_key[r['index']] == axis]
                    if not group:
                        continue
                    materials.PREFIX = base_prefix + stage + '_Axis' + str(axis) + '_'
                    wrappers, copies, group_deltas, group_bindings = materials.make_wrappers(group, 'C_r02_mix60', image, sync)
                    for material in copies.values():
                        bsdf = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
                        mix = bsdf.inputs['Base Color'].links[0].from_node
                        assert mix.type == 'MIX_RGB' and abs(mix.inputs[0].default_value-.60) < 1e-6
                        image_node = mix.inputs[2].links[0].from_node
                        assert image_node.type == 'TEX_IMAGE' and image_node.image == image
                        before_graph = sync.nodes(material.node_tree)
                        contract = projection.add_blender(material, image_node, axis)
                        projected.append(dict(material=material.name, contract=contract,
                            graph_before=sync.stable(before_graph), graph_after=sync.stable(sync.nodes(material.node_tree))))
                    deltas += group_deltas
                    bindings += group_bindings
                expected = dict(before_bindings)
                expected.update({b['instance']: b['target_collection'] for b in bindings})
                assert materials.scene_bindings(scene) == expected
                changes[stage] = dict(material_deltas=deltas, bindings=bindings, projections=projected)
            else:
                helper_stage = 'C_r02_mix60' if stage == 'C_mesh' else stage
                wrappers, copies, deltas, bindings = materials.make_wrappers(selected, helper_stage, image, sync)
                materials.verify_bindings(scene, before_bindings, selected, wrappers, stage)
                changes[stage] = dict(material_deltas=deltas, bindings=bindings)
        else:
            assert materials.scene_bindings(scene) == before_bindings
        materials.assert_original_materials_unchanged(sync, before_materials)
        for label, camera in cameras:
            forward = camera.matrix_world.to_quaternion() @ Vector((0,0,-1))
            center = camera.location + forward*6
            center.z = 1
            materials.set_fill(fill, center, 8)
            scene.camera = camera
            path = output / (stage + '_' + label + '.png')
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            assert path.is_file()
            renders.append(dict(stage=stage, view=label, file=path.name, sha256=sha(path),
                camera_matrix=[list(row) for row in camera.matrix_world], fill_at=list(fill.location),
                fill_energy=fill.data.energy, fill_color=list(fill.data.color)))
            print('SURFACE_PREVIEW_FRAME', stage, label, flush=True)
    assert geometry.geometry_multiset() == before_geometry
    materials.assert_original_materials_unchanged(sync, before_materials)
    assert all(sha(ROOT / path) == expected for path,expected in guards.items())
    derived = output / 'SurfacePreview.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(derived), compress=True, relative_remap=False)
    assert all(sha(ROOT / path) == expected for path,expected in guards.items())
    receipt = dict(status='DERIVED_STATIC_SURFACE_PREVIEW_RENDERED', source=source.relative_to(ROOT).as_posix(),
        source_sha256=args.source_sha256, tool_sha256=sha(__file__), selected_source_keys=selection['selected_source_keys'],
        selected_wall_instances=len(selected), selection_sha256=args.selection_sha256, views_sha256=args.views_sha256,
        image_sha256=args.image_sha256, guards=guards, geometry_unchanged=before_geometry,
        changes=changes, renders=renders, derived_blend_sha256=sha(derived),
        projection_comparison=args.projection_comparison,
        boundary='Static source preview with identical neutral fill per view. Runtime mechanisms, held lantern and game lighting absent. Partial wall membership only; original surfaces/ceilings and source files unchanged. No level/library promotion.')
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    sections = []
    for label, camera in cameras:
        cards = ['<figure><figcaption>'+r['stage']+'</figcaption><a href="'+r['file']+'"><img src="'+r['file']+'"></a></figure>'
                 for r in renders if r['view'] == label]
        sections.append('<h2>'+label+'</h2><div class="grid">'+''.join(cards)+'</div>')
    count = str(len(selected))
    surface_label = selection.get('preview_label', 'Partial Hall / west-rim wall preview')
    scope_note = selection.get('preview_scope_note', 'West coverage is deliberately partial.')
    description = ('C_mesh: new pigment at.60 using existing UVs. D_world2m: same image/mix/'+count+'keys with fixed cardinal world-plane projection at2m. Only projection differs.' if args.projection_comparison else 'A: current albedo at.12. B: original at.60. C: new pigment at.60.')
    page = '<!doctype html><meta charset="utf-8"><title>Bounded wall material source preview</title><style>body{background:#172027;color:#e9e4d8;font:16px system-ui;margin:28px}.grid{display:grid;grid-template-columns:repeat('+str(len(stages))+',1fr);gap:14px}figure{margin:0}img{width:100%}a{color:#8ad0dc}</style><h1>'+surface_label+'</h1><p>'+description+' Exactly'+count+' selected wall/backing instances; ceilings and nonselected faces stay original. '+scope_note+' Camera contracts and additional inspection viewpoints are recorded in the view manifest. Neutral fill is not game lighting. No new geometry, props or gameplay is proposed.</p>' + ''.join(sections)
    (output / 'PREVIEW.html').write_text(page)
    print('SURFACE_PREVIEW_DONE', str(output / 'receipt.json'), sha(output / 'receipt.json'), flush=True)


if __name__ == '__main__':
    main()
