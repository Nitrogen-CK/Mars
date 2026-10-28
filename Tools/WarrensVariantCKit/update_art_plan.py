"""Promote only the eight approved P4 material bindings into canonical JSON.

Refuses any topology, gameplay or other-variant manifest delta. Does not apply
geometry or invoke Unreal. Existing generated files are checkpointed first.
"""
import copy
import hashlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLAN = ROOT / 'Tools/LevelDesign/anchor_plans'
OUT = ROOT / 'Saved/WarrensCGameplay-20261024/ArtPlan'
sys.path.insert(0, str(PLAN))
import design_warrens_v8_common as common
import design_warrens_v8c as variant
import build_warrens as builder


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    data_path = PLAN / 'data/warrens_v8c.json'
    manifest_path = ROOT / 'Saved/AnchorPlans/v8c-manifest.json'
    old_data = json.loads(data_path.read_text(encoding='utf-8'))
    old_manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    data = json.loads(json.dumps(common.build(variant)))
    # The builder's default global MAP targets live Warrens even with explicit
    # data. Bind the requested variant before emitting; never infer the target.
    builder.MAP = '/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'
    manifest, summary = builder.manifest(write=False, data=data)
    manifest = json.loads(json.dumps(manifest))
    assert sum(len(data['bellkeeper'][role]['materials']) for role in ('panel', 'clue')) == 8
    normalized = copy.deepcopy(data)
    for role in ('panel', 'clue'):
        normalized['bellkeeper'][role].pop('materials')
    assert normalized == old_data, 'Unexpected C plan change'
    normalized_manifest = copy.deepcopy(manifest)
    changed = []
    for entity in normalized_manifest['entities']:
        role = 'panel' if entity['cls'] == 'Mars_Bellkeeper_EntityScript' else 'clue' if entity['cls'] == 'Mars_BellkeeperClue_EntityScript' else None
        if role:
            for key, path in data['bellkeeper'][role]['materials'].items():
                assert entity['props'].pop(key) == dict(asset=path)
                changed.append((role, key, path))
    current_runtime_manifest = json.loads((ROOT / 'Saved/WarrensCGameplay-20261024/startup-manifest.json').read_text(encoding='utf-8'))
    assert len(changed) == 8 and normalized_manifest == current_runtime_manifest, 'Unexpected delta from implemented P2/startup manifest'
    others = {}
    for name in ('b', 'd'):
        module = __import__('design_warrens_v8' + name)
        other_data = common.build(module)
        saved = json.loads((ROOT / f'Saved/AnchorPlans/v8{name}-manifest.json').read_text(encoding='utf-8'))
        builder.MAP = saved['map']
        generated, _ = builder.manifest(write=False, data=other_data)
        generated = json.loads(json.dumps(generated))
        assert generated == saved, 'Other variant changed ' + name
        others[name] = True
    backups = OUT / 'GeneratedCheckpoint'
    rows = []
    for path, value in ((data_path, data), (manifest_path, manifest)):
        destination = backups / path.relative_to(ROOT)
        destination.parent.mkdir(parents=True, exist_ok=True)
        assert not destination.exists(), 'Keep first generated checkpoint immutable'
        shutil.copy2(path, destination)
        before = sha(path)
        path.write_text(json.dumps(value, indent=1), encoding='utf-8')
        rows.append(dict(path=path.relative_to(ROOT).as_posix(), before_sha256=before, after_sha256=sha(path), backup=destination.relative_to(ROOT).as_posix()))
    report = dict(status='UPDATED_EIGHT_P4_ART_PROPERTIES_ONLY', files=rows, bindings=changed, c_gameplay_topology_equal=True, other_variant_manifests_equal=others,
                  previous_canonical_missing_keys=sorted(set(current_runtime_manifest) - set(old_manifest)),
                  manifest_comparison_authority='Saved/WarrensCGameplay-20261024/startup-manifest.json',
                  boundary='Offline canonical plan: eight art fields only. Emitted canonical manifest also synchronizes already-implemented P2/startup metadata from its current authority; old canonical file checkpoint retained. No map apply, cook or new gameplay.')
    (OUT / 'CANONICAL_ART_UPDATE.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('CANONICAL_P4_ART_UPDATED', len(changed), others)


if __name__ == '__main__':
    main()
