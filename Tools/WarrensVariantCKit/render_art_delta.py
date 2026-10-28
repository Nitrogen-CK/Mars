"""Headless same-camera preview for small source-ledger art deltas.

Reusable for static dressing only. Never opens/saves Unreal or modifies input
Blends/placement ledgers. Does not synthesize runtime actors or controls.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
SOURCE = REVIEW / 'source_views/WarrensC_SourceViews.blend'
LEDGER = ROOT / 'Tools/WarrensVariantCKit/Output/fitted_instances.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def point(at):
    return Vector((at[0] - 58, 55 - at[1], at[2]))


def place(obj, row):
    obj.location = point(row['at'])
    obj.scale = row.get('scale', [1, 1, 1])
    rotation = row.get('rotation', [0, row.get('yaw', 0), 0])
    obj.rotation_euler = [math.radians(rotation[2]), math.radians(-rotation[0]), math.radians(-rotation[1])]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--delta', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    delta_path = ROOT / args.delta
    out = ROOT / args.out
    out.mkdir(parents=True, exist_ok=True)
    delta = json.loads(delta_path.read_text())
    ledger = json.loads(LEDGER.read_text())
    assert sha(LEDGER) == delta['source_ledger_sha256']
    source_hash = sha(SOURCE)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    scene = bpy.data.scenes['02_VariantC_Cutaway']
    bpy.context.window.scene = scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 650
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    fill = bpy.data.objects['SourceView_NeutralReviewFill']
    views = delta.get('preview_views', [])
    if not views:
        room = delta['tile'].lower()
        views = [{'id': 'overview', 'existing_camera': f'ROOM_{room}_A_Overview', 'target_plan': [95, 104, 6]},
                 {'id': 'standing', 'existing_camera': f'ROOM_{room}_B_Standing', 'target_plan': [95, 104, 6]}]
    cameras = []
    for view in views:
        if view.get('existing_camera'):
            camera = bpy.data.objects[view['existing_camera']]
        else:
            data = bpy.data.cameras.new('ArtDelta_' + view['id'])
            camera = bpy.data.objects.new(data.name, data)
            scene.collection.objects.link(camera)
            camera.location = point(view['eye_plan'])
            camera.rotation_euler = (point(view['target_plan']) - camera.location).to_track_quat('-Z', 'Y').to_euler()
            data.lens = 36 / (2 * math.tan(math.radians(view.get('fov_degrees', 90)) / 2))
            data.clip_start = .05
            data.clip_end = 180
        cameras.append((view, camera))
    records = []
    for state in ('before', 'candidate'):
        if state == 'candidate':
            for removal in delta['remove']:
                index, row = removal['source_index'], removal['row']
                assert ledger['placements'][index] == row
                obj = scene.objects.get(row['id'] + '_Assembly_' + str(index))
                assert obj and (obj.location - point(row['at'])).length < .00001
                obj.hide_render = True
            for index, row in enumerate(delta['add']):
                ident = row.get('mesh_id', row['id'])
                collections = [c for c in bpy.data.collections if c.name.startswith(ident + '_') and any(o.type == 'MESH' for o in c.objects)]
                assert collections, 'Missing existing library collection ' + ident
                obj = bpy.data.objects.new('ArtDelta_' + str(index) + '_' + row['id'], None)
                obj.instance_type = 'COLLECTION'
                obj.instance_collection = sorted(collections, key=lambda c: len(c.name))[0]
                scene.collection.objects.link(obj)
                place(obj, row)
        for view, camera in cameras:
            scene.camera = camera
            center = (camera.location + point(view['target_plan'])) * .5
            fill.location = center + Vector((0, 0, 8))
            fill.rotation_euler = (center - fill.location).to_track_quat('-Z', 'Y').to_euler()
            file = out / f"{state}_{view['id']}.png"
            scene.render.filepath = str(file)
            bpy.ops.render.render(write_still=True)
            records.append(dict(state=state, view=view['id'], file=file.name, sha256=sha(file), camera=[list(row) for row in camera.matrix_world], fill=list(fill.location)))
            print('ART_DELTA_RENDERED', file.name, flush=True)
    assert sha(SOURCE) == source_hash
    assert sha(LEDGER) == delta['source_ledger_sha256']
    bpy.ops.wm.save_as_mainfile(filepath=str(out / 'ArtDelta_Review.blend'), compress=True)
    report = dict(delta=str(delta_path.relative_to(ROOT)), delta_sha256=sha(delta_path), source_sha256=source_hash, renders=records,
                  evidence_boundary='Historical static source geometry; runtime forage, pickups, controls and game lighting absent. Only listed static dressing delta; same camera/fill/original materials. Offline appearance proposal, not collision or runtime acceptance.')
    (out / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print('ART_DELTA_PREVIEW_COMPLETE', flush=True)


if __name__ == '__main__':
    main()
