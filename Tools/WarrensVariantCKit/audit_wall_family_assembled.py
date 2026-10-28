"""Read-only comparison of a saved source LI against assembled editor/PIE HISMs.

All receipt files are hash-bound. No actor, asset, map or settings writes.
"""
import copy
import hashlib
import importlib.util
import json
import math
import re
from pathlib import Path
import uuid

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def pinned(relative, digest):
    path = (ROOT / relative).resolve()
    assert path.is_relative_to(ROOT.resolve()) and sha(path) == digest
    return json.loads(path.read_text())


def helper():
    path = HERE / 'hall_wall_trial.py'
    assert sha(path) == '7cedf430c2aa09f6848d09d5e4e0b95f2b9fd6ffdb266b548ea9b21f5b38219c'
    spec = importlib.util.spec_from_file_location('_assembled_wall_primitives', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def transform(u, pose):
    return u.Transform(location=u.Vector(*pose['at']),
        rotation=u.Quat(*pose['q']).rotator(), scale=u.Vector(*pose['scale']))


def compare(base, actual, expected):
    a, e = base._canonical(actual), base._canonical(expected)
    poses_a, poses_e = a.pop('instances'), e.pop('instances')
    pose_a, pose_e = a.pop('pose'), e.pop('pose')
    assert a == e, ('HISM properties differ', a['owner_label'])
    assert base._pose_equivalent(pose_a, pose_e), ('component pose', a['owner_label'])
    assert len(poses_a) == len(poses_e)
    # Neighboring centimetre buckets preserve the established pose tolerance.
    # Identical pre-existing poses are legal, but every occurrence is consumed.
    buckets = {}
    for index, pose in enumerate(poses_a):
        key = tuple(math.floor(float(v)) for v in pose['at'])
        buckets.setdefault(key, []).append((index, pose))
    used = set()
    for pose in poses_e:
        key = tuple(math.floor(float(v)) for v in pose['at'])
        nearby = [item for x in (-1, 0, 1) for y in (-1, 0, 1) for z in (-1, 0, 1)
                  for item in buckets.get((key[0]+x, key[1]+y, key[2]+z), [])]
        candidates = [(index, item) for index, item in nearby
                      if index not in used and base._pose_equivalent(item, pose)]
        assert candidates, ('missing pose', a['owner_label'], pose)
        used.add(candidates[0][0])
    assert len(used) == len(poses_a)


def level_key(level):
    # Object names remain stable when the streaming package receives a PIE prefix.
    return re.sub(r'^UEDPIE_\d+_', '', level.split('.', 1)[1])


def audit(source_receipt, source_sha, saved_receipt, saved_sha,
          baseline_receipt, baseline_sha, source_tile, pie=False,
          extra_assets_receipt=None, extra_assets_sha=None):
    import unreal as u
    source = pinned(source_receipt, source_sha)
    saved = pinned(saved_receipt, saved_sha)
    baseline = pinned(baseline_receipt, baseline_sha)
    assert source['status'] == 'TWO_REOPEN_SERIALIZATION_STABLE'
    assert saved['status'] == 'HUB_SOURCE_SAVED_RELOAD_VERIFICATION_REQUIRED'
    assert source['saved_receipt']['path'] == saved_receipt
    assert source['saved_receipt']['sha256'] == saved_sha
    assert source['map_sha256'] == saved['map_after']
    assert source['semantic_hism_sha256'] == saved['semantic_hism_sha256']
    assert source_tile.isalnum() or source_tile.replace('-', '').isalnum()
    map_file = 'Content/' + saved['map'].removeprefix('/Game/') + '.umap'
    assert sha(ROOT / map_file) == saved['map_after']
    for relative, digest in saved['immutable_guards_after'].items():
        assert sha(ROOT / relative) == digest, ('guard drift', relative)
    asset_hashes = dict(saved['owned_asset_hashes'])
    if extra_assets_receipt is not None:
        extra = pinned(extra_assets_receipt, extra_assets_sha)
        for row in extra['owned_assets']:
            assert row['path'] not in asset_hashes
            asset_hashes[row['path']] = row['package_sha256']
    else:
        assert extra_assets_sha is None
    for asset, digest in asset_hashes.items():
        assert sha(ROOT / ('Content/' + asset.removeprefix('/Game/') + '.uasset')) == digest
    base = helper()
    core = base._core()
    editor = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    world = editor.get_game_world() if pie else editor.get_editor_world()
    assert world and 'Warrens_VariantC_Mars_MAP' in world.get_name()
    assert (editor.get_game_world() is not None) is bool(pie)
    assert base._dirty(u) == dict(maps=[], content=[])
    actors, current = core._hism_snapshot(world)
    marker = 'LI_Warrens_' + source_tile
    owners = [actor for actor in actors if marker in actor.get_level().get_path_name()]
    levels = {actor.get_level().get_path_name() for actor in owners}
    assert len(levels) == 1, ('source level must resolve uniquely', marker, levels)
    level_transform = owners[0].get_level_transform()
    assert all(core._near(actor.get_level_transform(), level_transform) for actor in owners)
    expected = [copy.deepcopy(row) for row in baseline['before_hisms'].values()
                if marker not in row['level']]
    source_rows = source['hism_snapshot']
    for original in source_rows.values():
        row = copy.deepcopy(original)
        row['pose'] = core._pose(u.MathLibrary.compose_transforms(transform(u, row['pose']), level_transform))
        row['instances'] = [core._pose(u.MathLibrary.compose_transforms(transform(u, p), level_transform))
                            for p in row['instances']]
        expected.append(row)
    assert len(current) == len(expected)
    consumed = set()
    for wanted in expected:
        # Repeated actor labels across LIs are legal. Never use a global fallback.
        matches = [(path, row) for path, row in current.items()
                   if path not in consumed and row['owner_label'] == wanted['owner_label']
                   and level_key(row['level']) == level_key(wanted['level'])]
        assert len(matches) == 1, ('world component ownership ambiguous', wanted['owner_label'], len(matches))
        path, actual = matches[0]
        compare(base, actual, wanted)
        consumed.add(path)
    assert len(consumed) == len(current)
    geometry = base._global_geometry(current)
    assert len(geometry) == baseline['before_global_instance_count']
    assert base._digest_rows(geometry) == baseline['before_global_geometry_sha256']
    for relative, digest in saved['immutable_guards_after'].items():
        assert sha(ROOT / relative) == digest, ('guard drift after inspection', relative)
    for asset, digest in asset_hashes.items():
        assert sha(ROOT / ('Content/' + asset.removeprefix('/Game/') + '.uasset')) == digest
    result = dict(status='ASSEMBLED_SAVED_SOURCE_AND_WORLD_HISMS_MATCH', pie=bool(pie),
        source_tile=source_tile, source_hism_count=len(source_rows), world_hism_count=len(current),
        global_instance_count=len(geometry), geometry_sha256=base._digest_rows(geometry),
        source_receipt=dict(path=source_receipt, sha256=source_sha),
        saved_receipt=dict(path=saved_receipt, sha256=saved_sha),
        baseline_receipt=dict(path=baseline_receipt, sha256=baseline_sha),
        level_transform=core._pose(level_transform), all_component_properties_and_poses_match=True,
        owned_asset_hashes=asset_hashes,
        extra_assets_receipt=dict(path=extra_assets_receipt, sha256=extra_assets_sha),
        guard_count=len(saved['immutable_guards_after']), dirty=base._dirty(u), tool_sha256=sha(__file__),
        boundary='Read-only native material/membership/flags/pose checks; appearance needs actual game-camera observation.')
    out = ROOT / 'Saved/WarrensCGameplay-20261024/WallFamilyAssembledAudit' / (uuid.uuid4().hex + '.json')
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2) + '\n')
    return dict(file=out.relative_to(ROOT).as_posix(), sha256=sha(out), status=result['status'])
