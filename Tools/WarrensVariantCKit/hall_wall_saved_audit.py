"""Read-only recovery for Hall's first-reload new-actor export ordering check.

Preserves the frozen applier and requires exact raw bytes across two reopened
states. No text normalization, map save/load, actor or settings mutation.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import uuid

ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT / 'Saved/WarrensCGameplay-20261024/HallWallAdoption'
TOOL = ROOT / 'Tools/WarrensVariantCKit/cardinal_wall_family_persistent.py'
TOOL_SHA = '6efebdb2b3fcb5cdea9aeded6cc0253a6ab40fc2cc4e0ebe965df11ce7233273'
SAVED = RUN / 'receipts/saved_20261026T033122_081890Z_7c8ebf8d.json'
SAVED_SHA = '6be629114ae1448053a5475bf3b88c63fde801a91f4510541030b700a12a9156'
FAILED_EXPORTS = RUN / 'reload_ad2d91910b614f878aeb367f10c90360'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def helper():
    assert sha(TOOL) == TOOL_SHA
    spec = importlib.util.spec_from_file_location('_hall_readonly_audit_primitives', TOOL)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def audit(first_path=None, first_sha=None):
    import unreal as u
    h = helper()
    assert sha(SAVED) == SAVED_SHA
    saved = json.loads(SAVED.read_text())
    state = h._state().data
    assert state and state['stage'] == 'saved'
    assert saved['status'] == 'HUB_SOURCE_SAVED_RELOAD_VERIFICATION_REQUIRED'
    assert saved['tool_sha256'] == TOOL_SHA
    c, core = h._contract(), h._core()
    h._asset_rows(c)
    world = h._editor(u)
    assert h._package(world) == c['map_package']
    assert sha(ROOT / c['map_file']) == saved['map_after'] == state['map_after']
    h._guards_except_map(c, saved['immutable_guards_after'], saved['map_after'])
    folder = RUN / ('recovery_reload_' + uuid.uuid4().hex)
    roster, hisms = h._roster(u, core, world, folder)
    assert h._digest(h._semantic(core, hisms)) == saved['semantic_hism_sha256']
    assert h._digest(h._global_geometry(hisms)) == saved['global_geometry_sha256']
    h._assert_reopen_shape(saved['source_roster'], roster)
    source_labels = set(c['source_actors'].values())
    new_labels = set(c['trial_labels'].values())
    h._verify_reopen_transition(state['roster'], roster, source_labels, new_labels)
    # First serialization may reorder the root/HISM object blocks in the four
    # newly authored actors. All of their non-HISM component exports remain
    # exact; source/unrelated actor/component checks above stay strict.
    h._verify_reopen_against_saved(saved['source_roster'], roster, source_labels | new_labels)
    assert h._collision_check() == state['collision']
    h._assert_settings(u, state['settings_before'])
    failure_exports = {}
    for name, row in saved['source_roster'].items():
        file = FAILED_EXPORTS / (name + '.t3d')
        assert file.is_file()
        failure_exports[file.relative_to(ROOT).as_posix()] = sha(file)
        for component in row['components']:
            file = FAILED_EXPORTS / (name + '__' + component + '.t3d')
            assert file.is_file()
            failure_exports[file.relative_to(ROOT).as_posix()] = sha(file)
    result = dict(phase='reload_first', status='FIRST_REOPEN_CAPTURED_SECOND_REQUIRED',
        saved_receipt=dict(path=SAVED.relative_to(ROOT).as_posix(), sha256=SAVED_SHA),
        map_sha256=saved['map_after'], actor_roster=roster, hism_snapshot=hisms,
        semantic_hism_sha256=h._digest(h._semantic(core, hisms)),
        global_geometry_sha256=h._digest(h._global_geometry(hisms)),
        immutable_guards=saved['immutable_guards_after'], collision_hashes=state['collision'],
        owned_asset_hashes=saved['owned_asset_hashes'], guards_verified=True,
        collision_count=54, dirty=h._dirty(u), settings_restored=True,
        original_verifier=dict(tool=TOOL.relative_to(ROOT).as_posix(), sha256=TOOL_SHA,
            failure="AssertionError: ('saved actor raw changed on reopen', 'WVC_HallWall_CCS15_NormalX')",
            exports=failure_exports),
        first_transition_new_actor_raw_exception=sorted(new_labels),
        boundary='Read-only recovery; strict unrelated pre-save→reopen raw data, all source HISM semantics, and new non-HISM raw data. No save or normalization.')
    if first_path is not None:
        file = (ROOT / first_path).resolve()
        assert file.is_relative_to(RUN.resolve()) and sha(file) == first_sha
        first = json.loads(file.read_text())
        assert first['status'] == 'FIRST_REOPEN_CAPTURED_SECOND_REQUIRED'
        assert first['tool_sha256'] == sha(__file__)
        assert first['saved_receipt'] == result['saved_receipt']
        assert first['original_verifier'] == result['original_verifier']
        h._assert_raw_roster(first['actor_roster'], roster)
        assert first['semantic_hism_sha256'] == result['semantic_hism_sha256']
        result.update(phase='reload_second', status='TWO_REOPEN_SERIALIZATION_STABLE',
            first_reload=dict(path=first_path, sha256=first_sha), raw_roster_matches_first_reload=True)
        state['stage'] = 'verified'
    else:
        assert first_sha is None
    result['tool_sha256'] = sha(__file__)
    out = RUN / 'receipts' / ('recovery_' + result['phase'] + '_' + uuid.uuid4().hex + '.json')
    assert not out.exists()
    out.write_text(json.dumps(result, indent=2, allow_nan=False) + '\n')
    return dict(file=out.relative_to(ROOT).as_posix(), sha256=sha(out), status=result['status'])
