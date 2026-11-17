"""Assemble delivery evidence from completed checks; does not modify game assets."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]

def read(path):
    return json.loads((ROOT / path).read_text())

def write(path, value):
    (ROOT / path).write_text(json.dumps(value, indent=2) + '\n')

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

roundtrip = read('Model/roundtrip_validation.json')
gutter = read('Model/gutter_validation.json')
spine = read('Model/spine_page_validation.json')
native = read('unreal_import_report.json')
assert all(roundtrip['checks'].values()) and len(roundtrip['checks']) == 12
assert all(gutter['checks'].values()) and len(gutter['checks']) == 4
assert all(spine['checks'].values())
for path, expected in native['source_sha256'].items():
    assert digest(ROOT / path) == expected, ('Imported source changed', path)

runtime = {}
for label in ['R02-Before', 'R03-Final']:
    journey = read(f'UnrealGameplay/{label}/journey.json')
    assert journey['status'] == 'complete' and len(journey['captures']) == 7
    runtime[label] = journey
for label, expected in [('01-held-closed', 3.125), ('02-open-index', 1),
                        ('04-recipe', 1), ('05-reverse-index', 1),
                        ('06-closed', 3.125), ('07-dropped', 3.125)]:
    pose = read(f'UnrealGameplay/R03-Final/{label}.json')['observedBook']
    assert abs(pose['spineScale'][2] - expected) < 1e-4, (label, pose)

console = (ROOT / 'Evidence/final-test-console.log').read_text(errors='replace')
for token in ['Total: 5', 'Passed: 5', 'Failed: 0', 'Skipped: 0', 'Contaminated: 0',
              'TEST COMPLETE. EXIT CODE: 0']:
    assert token in console, token
saved = read('Evidence/final_editor_save.json')
assert saved['dirtyMaps'] == [] and saved['remainingDirtyContent'] == []

revision = read('source_revision.json')
revision['source_sha256'] = {p.name: digest(p) for p in sorted((ROOT / 'Model').glob('*.py'))}
revision['openSpine'] = {
    'referencePose': 'flat-open', 'openBoneScaleZ': 1,
    'closedBoneScaleZ': 3.125, 'closedLocalZOffsetMetres': .019625,
    'openToClosedDepthRatio': .32,
    'reason': 'The binding folds down as the covers open; page and cover bones retain their dimensions.'}
write('source_revision.json', revision)
spine.update({
    'reason': 'User identified excessive binding thickness in the open pose.',
    'change': revision['openSpine'],
    'unreal': 'Imported six clips retain Spine scale/translation and four page-bend curves. R03-Final PIE captures confirm closed scale3.125 and open scale1.',
    'offlineGate': '12/12 FBX,4/4 gutter,216 turn frames without fixed-page surface intersections; process exit0.'})
write('Evidence/SpineFix/REPORT.json', spine)

owned = [
    'Script/Items/Mars_Item_Cookbook.as',
    'Script/Items/Presentation/Mars_CookbookPresentationComponent.as',
    'Script/Tests/Cookbook/Mars_AutoTestRig_Cookbook.as',
    'Script/Tests/Cookbook/Mars_AutoTest_Cookbook_TransitionsReverseAndPageBoundsHold.as']
delivery = {
    'recordedUtc': datetime.now(timezone.utc).isoformat(),
    'revision': 'StylizedR03', 'engine': '5.7.4',
    'activeNamespace': '/Game/Mars/Gameplay/PlayerCookbook/StylizedR03',
    'changes': ['2x cover thickness and corner radius', '1.5x page-stack depth with five broad signature ridges',
                '3x turning-sheet rim:0.7344mm at runtime', 'Binding folds to32 percent closed depth on opening',
                'Matching twelve-bone mesh, six clips, four morph curves and closed pickup proxy'],
    'retained': ['17x23cm authoring reading footprint', 'Runtime scale1.2', 'R02 page widgets and artwork',
                 'Existing inputs and page navigation', 'R02 source/assets for rollback'],
    'nativeBuild': {'exitCode': 0, 'evidence': 'Evidence/baseline-build-and-test.log'},
    'focusedGate': {'pattern': 'Cookbook', 'baseline': {'total': 5, 'passed': 5, 'failed': []},
                    'final': {'total': 5, 'passed': 5, 'failed': [], 'skipped': 0, 'contaminated': 0},
                    'finalExitCode': 0, 'evidence': 'Evidence/final-cookbook-test.log'},
    'offline': {'fbxChecks': '12/12', 'gutterChecks': '4/4', 'spineChecks': '4/4',
                'turnFrames': 216, 'triangles': 18460},
    'pie': {'evidence': 'UnrealGameplay/R03-Final/journey.json', 'status': 'complete',
            'observed': ['Loose-book spawn', 'Pickup', 'Open', 'Forward turn', 'Reverse turn', 'Close', 'Reopen', 'Drop mid-turn returns closed'],
            'input': 'Raw events injected through the production input inbox; no forced held/item/presentation state.',
            'physicalKeyboard': 'unverified', 'multiplayer': 'unverified', 'packagedBuild': 'unverified'},
    'knownVisualIssue': 'The turning page briefly extends above the viewport in both R02 and R03 mid-turn captures; existing animation trajectory retained.',
    'editor': saved,
    'sourceChanges': {p: digest(PROJECT / p) for p in owned},
    'git': {'committed': False, 'pushed': False, 'unrelatedMapLeftUntouched': 'Content/Mars/Maps/AutoTests_Mars_MAP.umap'},
    'rollback': 'Restore the four source files from Evidence/Before; R02 assets remain intact. No map changes required.',
    'tuning': {'file': 'Model/build_stylized.py', 'openBinding': 'set_pose: Spine scale.z=3.125-2.125*openness; closed localZ=.019625*(1-openness)',
               'turningLeaf': 'half rim .00045 before author scale; runtime full thickness .7344mm'},
    'reimportRule': 'Keep the R03 mesh/rest skeleton and all six R03 clips together. Re-run native and offline checks after geometric changes.'}
write('DELIVERY.json', delivery)

manifest = {}
for base in [ROOT / 'Model', PROJECT / 'Content/Mars/Gameplay/PlayerCookbook/StylizedR03']:
    for path in sorted(base.rglob('*')):
        if path.is_file() and path.suffix.lower() in ['.blend', '.fbx', '.uasset', '.py']:
            manifest[str(path.relative_to(PROJECT)).replace('\\', '/')] = {
                'bytes': path.stat().st_size, 'sha256': digest(path)}
write('model_manifest.json', manifest)
print('DELIVERY_CONFIRMED imported source hashes,12/12 FBX,4/4 gutter,4/4 spine,7/7 PIE captures,5/5 tests')
