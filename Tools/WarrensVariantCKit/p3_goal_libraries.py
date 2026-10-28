"""Stage the approved four P3 placements in a derived original-library copy.

Never saves an original Blend. Headless Blender stage and reopen are separate
processes. Catalogue, mesh, material, light and camera data remain unchanged.
"""
import argparse
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / 'Saved/WarrensCGameplay-20261024/P3GoalLibraryStage/r02'
SYNC_SHA = '5de7683ebf5829952c0b31b39d3d28ff34b070019ab61fc2da01462ca3bbbad6'
SOURCES = {
    'Diorama': '2fb8dfdfbf1a3ad1a5e019204fc679d827eda137381f4b86934fd7b71dbcc7dc',
    'KitLibrary': '28ae1af77e09a3dbb5377462861f171c56472f239b00eb4a2a913951fa038fa7',
}
SURVEY = ROOT / 'Saved/WarrensCGameplay-20261024/P3GoalWallSurvey/receipt.outer2.json'
SURVEY_SHA = '878aea3cebe41061f80d1e5b8615fe103226d9c320e6b2e2cc8c9e30fe675da9'
APPROVAL = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/P3_GOAL_CUE_ADOPTION_CONTRACT.md'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def write(path, value):
    assert not path.exists(), ('Preserve prior evidence', path)
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + '\n', encoding='utf-8')


def inventory_file(path, value):
    assert not path.exists()
    with gzip.open(path, 'wt', encoding='utf-8') as stream:
        json.dump(value, stream, sort_keys=True, separators=(',', ':'), allow_nan=False)


def tools():
    assert sha(HERE / 'sync_art_libraries.py') == SYNC_SHA, 'Frozen inventory dependency changed'
    return module('p3_library_sync', HERE / 'sync_art_libraries.py')


def contracts():
    assert sha(SURVEY) == SURVEY_SHA
    approval = APPROVAL.read_text(encoding='utf-8')
    assert 'APPROVED for the exact persistent paired placement' in approval
    assert '196 asset catalogue cards' in approval
    survey = json.loads(SURVEY.read_bytes())
    return survey, {str(HERE / ('Output/WarrensVariantC_' + k + '.blend')): v for k, v in SOURCES.items()}


def stage(name):
    import bpy
    sync = tools()
    survey, source_guards = contracts()
    assert all(sha(p) == v for p, v in source_guards.items())
    folder = WORK / name
    assert not folder.exists(), 'Inspect existing stage before another attempt'
    folder.mkdir(parents=True)
    source = HERE / ('Output/WarrensVariantC_' + name + '.blend')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    before = sync.inventory()
    count_before = sum(o.instance_type == 'COLLECTION' for o in bpy.data.scenes['02_VariantC_Cutaway'].objects)
    assert count_before == 32646
    stable_before = sync.stable(before)
    original_scene = bpy.context.window.scene
    board = bpy.data.objects['CCS78_Assembly_37274']
    card = bpy.data.objects['WVC083_ART04_Assembly_37275']
    collections = {'board': board.instance_collection, 'card': card.instance_collection}
    assert collections['card'].name == 'Variant_WVC083_ART04'
    moved = []
    added = []
    for kind, source_name, source_row in (
        ('board', board.name, survey['source_board_row']),
        ('card', card.name, survey['source_card_row']),
    ):
        for scene_name in ('02_VariantC_Cutaway', 'Zone_Ossuary'):
            scene = bpy.data.scenes[scene_name]
            matches = [o for o in scene.objects if o.name == source_name or o.name == source_name + '.001']
            assert len(matches) == 1
            obj = matches[0]
            assert obj.instance_collection == collections[kind]
            sync.check_pose(obj, source_row)
            row = survey['candidate'][kind]
            obj.location = (row['at'][0] - 58, 55 - row['at'][1], row['at'][2])
            obj.scale = row['scale']
            import math
            obj.rotation_euler = (0, 0, -math.radians(row['yaw']))
            sync.check_pose(obj, row)
            moved.append(dict(object=obj.name, scene=scene_name, target=row))
        for scene_name in ('02_VariantC_Cutaway', 'Zone_Reliquary'):
            scene = bpy.data.scenes[scene_name]
            key = 'p3_goal_cache_' + kind
            obj_name = 'P3Goal_' + kind + '_' + scene_name
            row = dict(survey['cache_candidate'][kind], id=source_row['id'])
            obj = sync.add_instance(scene, collections[kind], obj_name, row, key)
            added.append(dict(object=obj.name, scene=scene_name, stable_key=key, target=row))
    bpy.context.window.scene = original_scene
    bpy.context.view_layer.update()
    after = sync.inventory()
    count_after = sum(o.instance_type == 'COLLECTION' for o in bpy.data.scenes['02_VariantC_Cutaway'].objects)
    assert count_after == 32648
    stable_after = sync.stable(after)
    assert len(moved) == len(added) == 4
    assert len(after['objects']) == len(before['objects']) + 4 == 65757
    expected = dict(stable_before)
    expected['objects'] = dict(stable_before['objects'])
    for row in moved:
        obj_name = row['object']
        wanted = dict(stable_before['objects'][obj_name])
        wanted['matrix'] = stable_after['objects'][obj_name]['matrix']
        assert wanted == stable_after['objects'][obj_name], ('Non-pose source change', obj_name)
        expected['objects'][obj_name] = wanted
    for row in added:
        assert row['object'] not in before['objects']
        expected['objects'][row['object']] = stable_after['objects'][row['object']]
    expected['scenes'] = {key: dict(value) for key, value in stable_before['scenes'].items()}
    for scene_name in ('02_VariantC_Cutaway', 'Zone_Reliquary'):
        expected['scenes'][scene_name]['objects'] = sorted(
            stable_before['scenes'][scene_name]['objects'] +
            [row['object'] for row in added if row['scene'] == scene_name])
    assert expected == stable_after, 'Changes exceeded four moved and four added scene objects'
    assert len(after['scenes']) == 15
    assert after['scenes']['01_VariantCLibrary'] == before['scenes']['01_VariantCLibrary']
    output = folder / source.name
    bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True, relative_remap=False)
    assert all(sha(p) == v for p, v in source_guards.items())
    inventory_file(folder / 'before.inventory.json.gz', before)
    inventory_file(folder / 'after.inventory.json.gz', after)
    write(folder / 'staged.json', dict(status='DERIVED_ONLY_REOPEN_REQUIRED', source=str(source),
        source_sha256=SOURCES[name], output=str(output), output_sha256=sha(output),
        tool_sha256=sha(__file__), inventory_tool_sha256=SYNC_SHA,
        approval_sha256=sha(APPROVAL), survey_sha256=SURVEY_SHA,
        before_inventory_sha256=sha(folder / 'before.inventory.json.gz'),
        after_inventory_sha256=sha(folder / 'after.inventory.json.gz'),
        moved=moved, added=added, original_files_unchanged=True,
        cutaway_geometry_count_before=count_before, cutaway_geometry_count_after=count_after,
        boundary='Derived candidate only. No original promotion or live-level claim.'))
    print('P3_LIBRARY_STAGED', name, sha(output), flush=True)


def reopen(name):
    import bpy
    sync = tools()
    folder = WORK / name
    report = json.loads((folder / 'staged.json').read_bytes())
    assert sha(__file__) == report['tool_sha256']
    assert report['inventory_tool_sha256'] == SYNC_SHA
    assert sha(report['output']) == report['output_sha256']
    assert sha(folder / 'after.inventory.json.gz') == report['after_inventory_sha256']
    with gzip.open(folder / 'after.inventory.json.gz', 'rt', encoding='utf-8') as stream:
        expected = json.load(stream)
    bpy.ops.wm.open_mainfile(filepath=report['output'])
    actual = sync.inventory()
    assert sync.stable(actual) == sync.stable(expected), 'Saved derived-library reopen differs'
    assert sha(report['source']) == report['source_sha256']
    for row in report['moved'] + report['added']:
        obj = bpy.data.objects[row['object']]
        sync.check_pose(obj, row['target'])
        assert obj.name in bpy.data.scenes[row['scene']].objects
    write(folder / 'reopened.json', dict(status='DERIVED_REOPEN_VERIFIED_NOT_PROMOTED',
        staged_sha256=sha(folder / 'staged.json'), output_sha256=report['output_sha256'],
        tool_sha256=sha(__file__), inventory_tool_sha256=SYNC_SHA,
        objects=len(actual['objects']), scenes=len(actual['scenes']),
        original_unchanged=True, mesh_material_light_camera_catalogue_parity=True))
    print('P3_LIBRARY_REOPEN_VERIFIED', name, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('stage', 'reopen'))
    parser.add_argument('name', choices=tuple(SOURCES))
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    globals()[args.action](args.name)
