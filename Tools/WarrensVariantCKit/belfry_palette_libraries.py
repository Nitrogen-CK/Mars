"""Stage/reopen the approved stone-only palette in the original Blender libraries.

Prepare/promote run in ordinary Python. Build/reopen run in headless Blender.
The immutable source/reference atlas and the earlier four-family study remain untouched.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import uuid

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
WORK = ROOT / 'Saved/WarrensCGameplay-20261024/BelfryPaletteCheckpoint/blender-stone-v1'
TARGETS = {name: HERE / ('Output/WarrensVariantC_' + name + '.blend') for name in ('KitLibrary', 'Diorama')}
EXPECTED = {'KitLibrary': '50a54a4d7efbff84314cc6dfb303a2308fc801474ae8292d7cb050bfcfc388cf',
            'Diorama': 'ac79fa7e3636891688f95939815188e4cf92f67f607e139af28aeb6436500d5f'}
ATTEMPT = 'r02'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write(path, value):
    Path(path).write_text(json.dumps(value, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def tools():
    palette = module('belfry_stone_library_palette', HERE / 'build_belfry_palette.py')
    palette.KEYS = ('TX01', 'TX02')
    # The original libraries have no Render Result image. The earlier rendered
    # study's normalizer requires that cache; do not invent one in source files.
    def original_library_inventory(value):
        def strip_session(item):
            if isinstance(item, dict):
                return {k: strip_session(v) for k, v in item.items() if k != 'session_uid'}
            if isinstance(item, (list, tuple)):
                return [strip_session(v) for v in item]
            return item
        assert 'Render Result' not in value['images'], 'Unexpected render cache in original-library workflow'
        return strip_session(value)
    palette.canonical_inventory = original_library_inventory
    return palette, palette.sync_tools()


def target_dir(name):
    return WORK / (ATTEMPT + '_' + name)


def verify_selectors(bindings):
    selector = HERE / 'belfry_palette_delta.json'
    delta = read(selector)
    expected = {row['source_key']: row['source_row'] for row in delta['bindings']}
    assert len(expected) == delta['selected_count'] == 2144
    assert {row['source_key']: row['source_row'] for row in bindings} == expected
    assert all(row['slots'][0]['source_material_key'] in ('TX01', 'TX02') for row in delta['bindings'])
    return dict(path=selector.relative_to(ROOT).as_posix(), sha256=sha(selector), selection_sha256=delta['selection_sha256'])


def prepare():
    assert not WORK.exists(), 'Existing checkpoint/stage must be inspected; never overwrite it'
    palette, sync = tools()
    assert {name: sha(path) for name, path in TARGETS.items()} == EXPECTED
    review = REVIEW / 'BELFRY_PALETTE_REVIEW.md'
    assert 'stone/floor adoption approved' in review.read_text(encoding='utf-8')
    WORK.mkdir(parents=True)
    original = {}
    for name, path in TARGETS.items():
        backup = WORK / (name + '.before.blend')
        shutil.copy2(path, backup)
        assert sha(backup) == EXPECTED[name]
        original[name] = dict(path=path.relative_to(ROOT).as_posix(), sha256=sha(path),
                              checkpoint=backup.relative_to(ROOT).as_posix(), mtime_ns=path.stat().st_mtime_ns)
    baseline = dict(original=original, immutable=sync.immutable_files(),
        approval=dict(path=review.relative_to(ROOT).as_posix(), sha256=sha(review)),
        approved_preflight='docs/art/warrens-c-gameplay-review-20261024/belfry-palette/unreal/pie_preflight_20261025_054444_c282d142.json',
        scope='2144 Belfry instances, TX01/TX02 only; original global materials/catalog/geometry/cameras/lights preserved')
    baseline['approved_preflight_sha256'] = sha(ROOT / baseline['approved_preflight'])
    write(WORK / 'baseline.json', baseline)
    print('BELFRY_LIBRARY_CHECKPOINTED', flush=True)


def guard():
    baseline = read(WORK / 'baseline.json')
    assert all(sha(ROOT / name) == expected for name, expected in baseline['immutable'].items())
    assert sha(ROOT / baseline['approval']['path']) == baseline['approval']['sha256']
    assert sha(ROOT / baseline['approved_preflight']) == baseline['approved_preflight_sha256']
    return baseline


def geometry(palette):
    import bpy
    current = bpy.context.window.scene
    try:
        bpy.context.window.scene = bpy.data.scenes[palette.SCENE]
        bpy.context.view_layer.update()
        return palette.geometry_multiset()
    finally:
        bpy.context.window.scene = current


def build(name):
    import bpy
    baseline = guard()
    palette, sync = tools()
    out = target_dir(name)
    assert not out.exists()
    out.mkdir()
    palette.OUT = out
    bpy.ops.wm.open_mainfile(filepath=str(TARGETS[name]))
    assert not any(item.name.startswith(('BelfryPreview_', 'BelfryStone_'))
                   for collection in (bpy.data.objects, bpy.data.collections, bpy.data.materials) for item in collection)
    before = sync.inventory()
    write(out / 'before.json', before)
    before_geometry = geometry(palette)
    assert before_geometry['count'] == 32646
    selected = palette.selected_rows()
    preflight = read(ROOT / baseline['approved_preflight'])
    expected_keys = {r['source_key'] for r in preflight['matched_rows'] if r['candidate_slots']}
    assert len(selected) == 2144 and {row[0] for row in selected} == expected_keys
    bindings, wrappers, materials = palette.make_wrappers(selected)
    selector = verify_selectors(bindings)
    # Rename only newly created wrappers/copies; source IDs and catalog bindings stay intact.
    material_names = {}
    for record in materials:
        old = record['candidate']
        item = bpy.data.materials[old]
        item.name = old.replace('BelfryPreview_', 'BelfryStone_', 1)
        material_names[old] = item.name
        record['candidate'] = item.name
    collection_names = {}
    for wrapper in wrappers:
        old = wrapper['candidate']
        item = bpy.data.collections[old]
        item.name = old.replace('BelfryPreview_', 'BelfryStone_', 1)
        collection_names[old] = item.name
        wrapper['candidate'] = item.name
        for part in wrapper['parts']:
            item = bpy.data.objects[part['candidate']]
            item.name = item.name.replace('BelfryPreview_', 'BelfryStone_', 1)
            part['candidate'] = item.name
            for slot in part['slots']:
                slot['candidate_material'] = material_names.get(slot['candidate_material'], slot['candidate_material'])
    for binding in bindings:
        binding['candidate_collection'] = collection_names[binding['candidate_collection']]
    bpy.context.view_layer.update()
    after = sync.inventory()
    write(out / 'after.json', after)
    after_geometry = geometry(palette)
    assert before_geometry == after_geometry
    assert len(wrappers) == 7 and len(materials) == 4
    assert {r['catalog_key'] for r in materials} == {'TX01', 'TX02'}
    palette.verify_inventory(before, after, bindings, wrappers, materials)
    guard()
    write(out / 'receipt.json', dict(status='STAGED_NOT_PROMOTED', target=name, source=baseline['original'][name],
        tool_sha256=sha(__file__), selector=selector,
        geometry=before_geometry, bindings=bindings, wrappers=wrappers, material_deltas=materials,
        inventory_sha256=palette.digest(palette.canonical_inventory(after)),
        selected_instances=2144, copied_materials=4, material_families=['TX01', 'TX02'],
        boundary='Only Belfry collection bindings and owned material/collection/object copies change. Existing meshes/UVs/images/lighting/cameras/catalog remain unchanged.'))
    staged = out / (name + '.stone.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(staged), compress=True, relative_remap=False)
    guard()
    print('BELFRY_LIBRARY_STAGED', name, sha(staged), flush=True)


def reopen(name):
    import bpy
    guard()
    palette, sync = tools()
    out = target_dir(name)
    palette.OUT = out
    receipt = read(out / 'receipt.json')
    assert verify_selectors(receipt['bindings']) == receipt['selector']
    staged = out / (name + '.stone.blend')
    bpy.ops.wm.open_mainfile(filepath=str(staged))
    actual = sync.inventory()
    write(out / 'reopened.json', actual)
    assert palette.digest(palette.canonical_inventory(actual)) == receipt['inventory_sha256']
    palette.verify_inventory(read(out / 'before.json'), actual, receipt['bindings'], receipt['wrappers'], receipt['material_deltas'])
    assert geometry(palette) == receipt['geometry']
    guard()
    write(out / 'reopen.json', dict(status='REOPENED_STONE_ONLY_VERIFIED', target=name,
        stage_sha256=sha(staged), inventory_sha256=receipt['inventory_sha256'], geometry=receipt['geometry'],
        selected_instances=2144, wrappers=7, copied_materials=4))
    print('BELFRY_LIBRARY_REOPENED', name, flush=True)


def promote():
    baseline = guard()
    for name in TARGETS:
        check = read(target_dir(name) / 'reopen.json')
        assert check['status'] == 'REOPENED_STONE_ONLY_VERIFIED'
        assert sha(target_dir(name) / (name + '.stone.blend')) == check['stage_sha256']
    journal = WORK / 'promotion.json'
    assert not journal.exists()
    report = dict(status='PREPARED', originals=baseline['original'], targets={})
    write(journal, report)
    for name, target in TARGETS.items():
        staged = target_dir(name) / (name + '.stone.blend')
        assert sha(target) == EXPECTED[name]
        shutil.copy2(staged, target)
        assert sha(target) == read(target_dir(name) / 'reopen.json')['stage_sha256']
        report['targets'][name] = dict(path=target.relative_to(ROOT).as_posix(), before_sha256=EXPECTED[name],
            after_sha256=sha(target), checkpoint=baseline['original'][name]['checkpoint'])
        write(journal, report)
    remaining = {p: h for p, h in baseline['immutable'].items() if p not in {v['path'] for v in baseline['original'].values()}}
    assert all(sha(ROOT / p) == h for p, h in remaining.items())
    report.update(status='PROMOTED_STONE_ONLY', other_immutable_unchanged=len(remaining))
    write(journal, report)
    print('BELFRY_LIBRARY_PROMOTED', flush=True)


def audit_promoted(name):
    """Reopen the actual adopted original; never save or alter its contents."""
    import bpy
    baseline = read(WORK / 'baseline.json')
    promotion = read(WORK / 'promotion.json')
    assert promotion['status'] == 'PROMOTED_STONE_ONLY'
    assert set(promotion['targets']) == set(TARGETS)

    def promoted_guard():
        replacements = {row['path']: row['after_sha256'] for row in promotion['targets'].values()}
        for relative, original_hash in baseline['immutable'].items():
            assert sha(ROOT / relative) == replacements.get(relative, original_hash), relative
        for target, row in promotion['targets'].items():
            assert row['path'] == TARGETS[target].relative_to(ROOT).as_posix()
            assert row['before_sha256'] == EXPECTED[target] == sha(ROOT / row['checkpoint'])
            assert row['after_sha256'] == read(target_dir(target) / 'reopen.json')['stage_sha256']
        assert sha(ROOT / baseline['approval']['path']) == baseline['approval']['sha256']
        assert sha(ROOT / baseline['approved_preflight']) == baseline['approved_preflight_sha256']

    promoted_guard()
    palette, sync = tools()
    receipt = read(target_dir(name) / 'receipt.json')
    assert verify_selectors(receipt['bindings']) == receipt['selector']
    bpy.ops.wm.open_mainfile(filepath=str(TARGETS[name]))
    actual = sync.inventory()
    observed = WORK / 'promoted_observed' / (name + '_' + uuid.uuid4().hex[:8] + '.json')
    observed.parent.mkdir(parents=True, exist_ok=True)
    write(observed, actual)
    assert palette.digest(palette.canonical_inventory(actual)) == receipt['inventory_sha256']
    palette.verify_inventory(read(target_dir(name) / 'before.json'), actual,
                             receipt['bindings'], receipt['wrappers'], receipt['material_deltas'])
    assert geometry(palette) == receipt['geometry']
    promoted_guard()
    out = WORK / 'promoted_reopened' / (name + '.json')
    assert not out.exists(), 'Preserve prior promoted-library audits'
    out.parent.mkdir(parents=True, exist_ok=True)
    write(out, dict(status='PROMOTED_ORIGINAL_REOPENED_VERIFIED', target=name,
        source=promotion['targets'][name], inventory_sha256=receipt['inventory_sha256'],
        observed_inventory=dict(file=observed.relative_to(ROOT).as_posix(), sha256=sha(observed)),
        geometry=receipt['geometry'], selector=receipt['selector'], selected_instances=2144,
        scenes=len(actual['scenes']), objects=len(actual['objects']), images=len(actual['images']),
        material_families=['TX01', 'TX02'], existing_materials_and_meshes_preserved=True,
        read_only=True, source_sha256=sha(TARGETS[name])))
    print('BELFRY_PROMOTED_ORIGINAL_REOPENED', name, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('prepare', 'build', 'reopen', 'promote', 'audit-promoted'))
    parser.add_argument('--target', choices=tuple(TARGETS))
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else None)
    if args.action in ('build', 'reopen', 'audit-promoted'):
        assert args.target
        globals()[args.action.replace('-', '_')](args.target)
    else:
        globals()[args.action]()
