"""Read-only verification of the saved wall partition after receipt serialization failed."""
import copy
from collections import Counter
import hashlib
import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RUN = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryWallMaterialCheckpoint'
APPLIER = HERE / 'ossuary_wall_material_persistent.py'
APPLIER_SHA = 'd0764069551d264fe8553849c64a1c6b49f453d57c93e41b0c2d78fa2cb0ead4'
PREFLIGHT = RUN / 'preflight_20261026T005158_884205Z_6eebcec5.json'
PREFLIGHT_SHA = 'a4f3fe2b04f32be56c43099207a7ee7d99d887e3b44cafda9e3badf46cd4fac8'
SAVED_MAP_SHA = '338f811c487450c070332d2848cc9992e8cdbccd960f40c984e3ada84ef6e7a6'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def geometry(roster):
    result = Counter()
    for actor in roster.values():
        for c in actor['components'].values():
            if 'hism' in c:
                h = c['hism']
                for pose in h['instances']:
                    result[json.dumps(dict(mesh=h['mesh'], pose=pose), sort_keys=True)] += 1
    return result


def audit(phase):
    import unreal as u
    assert phase in ('saved', 'reloaded')
    assert sha(APPLIER) == APPLIER_SHA and sha(PREFLIGHT) == PREFLIGHT_SHA
    spec = importlib.util.spec_from_file_location('_ossuary_failed_applier_readonly', APPLIER)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    _, core, persistent = helper._dependencies()
    before = json.loads(PREFLIGHT.read_text())
    assert sha(helper.MAP_FILE) == SAVED_MAP_SHA
    u, world = helper._context()
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ')
    folder = RUN / ('audit_' + phase + '_' + stamp)
    after = helper._roster(world, folder / 'roster')
    actors = {a.get_actor_label(): a for a in helper._actors(u, world)}
    new_actor = actors[helper.TARGET_LABEL]
    backing_actor = actors['WVC_BACKING_TX01']
    ccs_actor = actors['WVC_CCS15']
    backing, = backing_actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
    ccs, = ccs_actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
    candidate, = new_actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
    pivot, rows = helper._dependencies()[0].source_rows()
    wall_keys = {r['key'] for r in rows if r['row']['id'] == 'BACKING_TX01'
                 and r['row'].get('role') == 'source wall seam backing'}
    mapping = before['actor_rows']['WVC_BACKING_TX01']
    selected = sorted(mapping[str(k)] for k in wall_keys)
    retained = sorted(set(mapping.values()) - set(selected))
    assert len(selected) == 597 and len(retained) == 231
    expected_back = copy.deepcopy(before['source_hism']['WVC_BACKING_TX01'])
    expected_back['instances'] = [expected_back['instances'][i] for i in retained]
    assert core._component(backing) == expected_back
    expected_ccs = copy.deepcopy(before['source_hism']['WVC_CCS15'])
    expected_ccs['materials'][0] = helper.MATERIAL
    assert core._component(ccs) == expected_ccs
    expected_new = helper._expected_component(before['source_hism']['WVC_BACKING_TX01'], candidate.get_path_name(),
        new_actor.get_path_name(), helper.MATERIAL,
        [before['source_hism']['WVC_BACKING_TX01']['instances'][i] for i in selected])
    assert core._component(candidate) == expected_new
    changed = {backing_actor.get_name(): {backing.get_name()}, ccs_actor.get_name(): {ccs.get_name()}}
    helper._verify_roster(before['full_actor_component_roster'], after, changed, new_actor.get_name())
    assert geometry(before['full_actor_component_roster']) == geometry(after)
    new_record = after[new_actor.get_name()]
    assert new_record['label'] == helper.TARGET_LABEL and new_record['tags'] == [helper.TARGET_TAG]
    assert new_record['type'] == '/Script/Engine.Actor' and not new_record['hidden']
    assert new_record['pose'] == core._pose(u.Transform())
    native_names = {'DefaultSceneRoot', 'BillboardComponent_0'}
    assert set(new_record['components']) == native_names | {candidate.get_name()}
    for name in native_names:
        path = RUN / ('native_' + name + '.t3d')
        assert sha(path) == new_record['components'][name]['raw']['sha256']
    hisms = [c['hism'] for a in after.values() for c in a['components'].values() if 'hism' in c]
    assert len(hisms) == 22 and sum(len(c['instances']) for c in hisms) == 2710
    assert sum(len(c['instances']) for c in hisms if c['materials'][0] == helper.MATERIAL) == 1194
    ceiling = [c for c in hisms if c['owner_label'] in ('WVC_BACKING_TX01', 'WVC_CCS13_TX01')]
    assert len(ceiling) == 2 and all(c['materials'] == [helper._dependencies()[0].SOURCE] for c in ceiling)
    assert sum(len(c['instances']) for c in ceiling) == 462
    current_guards = {p: sha(ROOT / p) for p in before['protected_files']}
    changed_files = {p: digest for p, digest in current_guards.items() if digest != before['protected_files'][p]}
    assert changed_files == {helper.MAP_FILE.relative_to(ROOT).as_posix(): SAVED_MAP_SHA}
    collision = json.loads(helper.COLLISION.read_text())
    assert len(collision) == 54 and all(sha(ROOT / p) == digest for p, digest in collision.items())
    settings, autosave, jolt, cook = helper._settings(u)
    assert autosave == before['settings_readback']['editor_auto_save_enable']
    assert str(cook) == before['settings_readback']['jolt_auto_cook']
    result = dict(status='RECOVERED_AFTER_SERIALIZATION_FAILURE_' + phase.upper(), phase=phase,
        map=helper.MAP, map_sha256=SAVED_MAP_SHA, preflight=PREFLIGHT.relative_to(ROOT).as_posix(),
        preflight_sha256=PREFLIGHT_SHA, failed_applier_sha256=APPLIER_SHA,
        audit_tool_sha256=sha(__file__), source_actor_count=len(after), source_hism_count=22, instances=2710,
        wall_instances=1194, original_ceiling_instances=462, geometry_multiset_exact=True,
        unrelated_actor_component_exports_exact=True, source_roster_after=after,
        changed_components={k: sorted(v) for k, v in changed.items()},
        protected_files=current_guards, collision_hashes=collision,
        settings_restored=dict(auto_save=autosave, auto_cook=str(cook)), dirty=dict(maps=[], content=[]),
        boundary='Read-only reconstructed receipt. Original apply saved successfully, then failed JSON serialization. No repeated apply or save. Assembled PIE and art acceptance are separate.')
    path = folder / 'receipt.json'
    path.write_text(json.dumps(result, indent=2) + '\n')
    return dict(status=result['status'], receipt=path.relative_to(ROOT).as_posix(), sha256=sha(path))
