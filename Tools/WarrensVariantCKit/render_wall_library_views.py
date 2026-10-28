"""Render pinned review cameras from a staged library without saving the Blend."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / 'Tools/WarrensVariantCKit/build_surface_material_preview.py'
HELPER_SHA = '31ad11cc9c4943f97b08d2131bd87f2db83d4ecfb8fd7d6ef697b9e3fc1147a5'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def pinned(relative, expected):
    path = (ROOT / relative).resolve()
    assert path.is_relative_to(ROOT.resolve()) and sha(path) == expected
    return path, json.loads(path.read_text())


def main():
    import bpy
    from mathutils import Vector
    parser = argparse.ArgumentParser()
    for key in ('stage', 'stage-sha256', 'audit', 'audit-sha256', 'views', 'views-sha256', 'output'):
        parser.add_argument('--' + key, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    stage_path, stage = pinned(args.stage, args.stage_sha256)
    audit_path, audit = pinned(args.audit, args.audit_sha256)
    views_path, views = pinned(args.views, args.views_sha256)
    assert stage['status'] == 'DERIVED_LIBRARY_STAGE_REOPEN_AUDIT_REQUIRED'
    assert audit['status'] == 'SEPARATE_PROCESS_REOPEN_AUDIT_PASS'
    assert audit['stage_receipt_sha256'] == args.stage_sha256
    source = ROOT / stage['staged_blend']
    assert Path(bpy.data.filepath).resolve() == source.resolve()
    assert sha(source) == stage['staged_blend_sha256'] == audit['staged_blend_sha256']
    for path, digest in stage['immutable_file_guards'].items():
        assert sha(ROOT / path) == digest
    assert sha(HELPER) == HELPER_SHA
    spec = importlib.util.spec_from_file_location('_wall_library_view_primitives', HELPER)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    materials, sync, geometry = helper.load_helpers()
    materials.PREFIX = 'WallLibraryReview_' + stage['library'] + '_'
    scene = bpy.data.scenes['02_VariantC_Cutaway']
    bpy.context.window.scene = scene
    bpy.context.view_layer.update()
    before_geometry = geometry.geometry_multiset()
    before_bindings = materials.scene_bindings(scene)
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
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.image_settings.file_format = 'PNG'
    scene.render.resolution_x, scene.render.resolution_y = 1000, 650
    scene.render.resolution_percentage = 100
    output = (ROOT / args.output).resolve()
    assert output.is_relative_to(ROOT.resolve()) and not output.exists()
    output.mkdir(parents=True)
    frames = []
    for label, camera in cameras:
        bpy.context.view_layer.update()
        center = camera.location + (camera.matrix_world.to_quaternion() @ Vector((0,0,-1))) * 6
        center.z = 1
        materials.set_fill(fill, center, 8)
        scene.camera = camera
        file = output / (label + '.png')
        scene.render.filepath = str(file)
        bpy.ops.render.render(write_still=True)
        assert file.is_file()
        frames.append(dict(file=file.relative_to(ROOT).as_posix(), sha256=sha(file), view=label,
            camera_matrix=[list(row) for row in camera.matrix_world], fill_at=list(fill.location),
            fill_energy=fill.data.energy, fill_color=list(fill.data.color)))
        print('LIBRARY_FRAME_RENDERED', stage['library'], label, flush=True)
    assert geometry.geometry_multiset() == before_geometry
    assert materials.scene_bindings(scene) == before_bindings
    assert sha(source) == stage['staged_blend_sha256']
    for path, digest in stage['immutable_file_guards'].items():
        assert sha(ROOT / path) == digest
    receipt = output / 'SOURCE_VIEWS_VERIFIED.json'
    receipt.write_text(json.dumps(dict(status='MATCHED_LIBRARY_SOURCE_VIEWS_RENDERED',
        library=stage['library'], stage_receipt=dict(path=args.stage, sha256=args.stage_sha256),
        audit_receipt=dict(path=args.audit, sha256=args.audit_sha256),
        source=stage['staged_blend'], source_sha256=stage['staged_blend_sha256'],
        views=dict(path=args.views, sha256=args.views_sha256), frames=frames,
        geometry_unchanged=before_geometry, tool_sha256=sha(__file__), helper_sha256=HELPER_SHA,
        boundary='Temporary neutral review lighting/cameras; no source or candidate Blend saved. Exact preexisting selected bindings preserved. Runtime appearance is separate.'), indent=2) + '\n')
    print('LIBRARY_SOURCE_VIEWS_VERIFIED', receipt, sha(receipt), flush=True)


if __name__ == '__main__':
    main()
