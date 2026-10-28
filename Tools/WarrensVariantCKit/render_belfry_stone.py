"""Two exact-camera art-direction references from the reopened stone-only stage."""
import importlib.util
import hashlib
import json
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
STAGE = ROOT / 'Saved/WarrensCGameplay-20261024/BelfryPaletteCheckpoint/blender-stone-v1/r02_Diorama/Diorama.stone.blend'
OUT = REVIEW / 'belfry-palette/stone-only-source'
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


assert not OUT.exists(), 'Preserve previous source references'
check = json.loads(STAGE.with_name('reopen.json').read_text())
assert check['status'] == 'REOPENED_STONE_ONLY_VERIFIED' and sha(STAGE) == check['stage_sha256']
source_hash = sha(STAGE)
reference = REVIEW / 'final-room-plates/source_views/WarrensC_CurrentRoomViews.blend'
manifest = REVIEW / 'final-room-plates/source_views/render_manifest.json'
record = next(r for r in json.loads(manifest.read_text())['rooms'] if r['room_id'] == 'ROOM_belfry')
names = [record['overview_camera'], record['standing_camera'], 'SourceView_NeutralReviewFill']
bpy.ops.wm.open_mainfile(filepath=str(STAGE))
scene = bpy.data.scenes['02_VariantC_Cutaway']
bpy.context.window.scene = scene
palette = module('belfry_stone_render_contract', HERE / 'build_belfry_palette.py')
before = palette.geometry_multiset()
assert all(name not in bpy.data.objects for name in names)
with bpy.data.libraries.load(str(reference), link=False) as (available, loaded):
    assert set(names) <= set(available.objects)
    loaded.objects = list(names)
for obj in loaded.objects:
    assert obj and obj.name in names
    scene.collection.objects.link(obj)
helper = module('belfry_stone_neutral_render', REVIEW / 'source_views/render_source_views.py')
helper.setup_review_render(scene)
OUT.mkdir()
palette.OUT = OUT
renders = palette.render_views('stone_only')
assert palette.geometry_multiset() == before == check['geometry']
assert sha(STAGE) == source_hash
report = dict(status='STONE_ONLY_EXACT_SOURCE_REFERENCE', source=STAGE.relative_to(ROOT).as_posix(),
    source_sha256=source_hash, reference_camera_source=reference.relative_to(ROOT).as_posix(),
    reference_camera_source_sha256=sha(reference), reference_manifest_sha256=sha(manifest),
    geometry=before, renders=renders,
    boundary='Static geometry and accepted two-family palette only. Runtime mechanisms/props are absent. Neutral review fill is not game lighting. Original libraries and frozen reference atlas are unchanged.')
(OUT / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'WarrensC_BelfryStone_SourceViews.blend'), compress=True, relative_remap=False)
print('BELFRY_STONE_SOURCE_REFERENCES_RENDERED', flush=True)
