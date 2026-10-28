"""Read-only recovery of the saved Diorama's post-Serialize export contract."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
FROZEN = HERE / 'ossuary_wall_diorama.py'
FROZEN_SHA = '54889153f61b1577ca17ef94659024f790698a1e7cdcfaa899d472a1ccafa3e0'
RUN = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryWallDioramaCheckpoint/9dc2e3b29d714ca787ea71ac27a494a2'
APPLIED_SHA = 'fb784d17b7af8f4cb6a1ab053a0ccc640abdd7eae7c93dbe5d93ad6ebce010fd'
MAP_SHA = '6da31db5fa00851b49eb5c6e1c712f5cd2c481f0a95397b6fd7a325277b290a0'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def deps():
    assert sha(FROZEN) == FROZEN_SHA
    spec = importlib.util.spec_from_file_location('_ossuary_diorama_frozen_recovery', FROZEN)
    old = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(old)
    assert sha(RUN / 'applied.json') == APPLIED_SHA
    applied = read(RUN / 'applied.json')
    assert applied['map_after'] == MAP_SHA
    _, sync, _, wall, core = old._deps()
    assert old.STATE is None
    assert old._guards(applied['immutable_guards_after'], map_sha=MAP_SHA)
    old._collision_exact(applied['collision_hashes_after'])
    return old, sync, wall, core, applied


def write(name, value):
    path = RUN / name
    assert not path.exists()
    value.update(tool_sha256=sha(__file__), applied_sha256=APPLIED_SHA, map_sha256=MAP_SHA)
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n')
    return dict(file=path.relative_to(ROOT).as_posix(), sha256=sha(path), status=value['status'])


def canonical_files(projection):
    result = []
    for actor, row in projection.items():
        result.append(actor + '.t3d')
        result += [actor + '__' + component + '.t3d' for component in row['components']]
    result.append('exposure_brush_geometry.t3d')
    assert len(result) == len(set(result))
    return sorted(result)


def reference():
    """Pin the actual first-reload raw files, without rewriting any of them."""
    old, sync, _, _, applied = deps()
    old._context(sync)
    roster = sync.roster(False)
    assert roster == applied['expected_roster_after'] == applied['observed_roster_after']
    assert len(roster) == 134
    projection = applied['full_actor_component_exports_after']
    assert len(projection) == 142
    files = canonical_files(projection)
    actual = {name: sha(RUN / 'audit_t3d' / name) for name in files}
    assert actual['exposure_brush_geometry.t3d'] == old.EXPOSURE_BRUSH_SHA256
    return write('recovery_reference.json', dict(status='FIRST_RELOAD_RAW_FILES_PINNED',
        actor_roster=roster, full_export_actor_count=142, canonical_exports=actual,
        immutable_guards=applied['immutable_guards_after'],
        reason='The original after-edit exports preceded persistent Serialize, which synchronously rebuilds HISM trees. Preserve the failed audit and compare a second actual reload against these first-reload raw bytes; no export text normalization.'))


def unloaded(reference_sha):
    old, sync, _, _, _ = deps()
    assert sha(RUN / 'recovery_reference.json') == reference_sha
    sync.context('KitLibrary')
    assert sync.u.find_object(None, old.MAP) is None
    return write('recovery_unloaded.json', dict(status='UNLOADED_OBSERVED',
        reference_sha256=reference_sha, target_world_absent=True))


def audit(reference_sha, unloaded_sha):
    old, sync, wall, core, applied = deps()
    assert sha(RUN / 'recovery_reference.json') == reference_sha
    assert sha(RUN / 'recovery_unloaded.json') == unloaded_sha
    ref = read(RUN / 'recovery_reference.json')
    unload = read(RUN / 'recovery_unloaded.json')
    assert unload['target_world_absent'] and unload['reference_sha256'] == reference_sha
    world = old._context(sync)
    roster = sync.roster(False)
    assert roster == ref['actor_roster'] == applied['expected_roster_after']
    assert sum(len(c.get('instances', [])) for a in roster.values() for c in a['components'].values()) == 32646
    exports = old._full_exports(wall, core, sync.u, world, RUN / 'recovery_audit_t3d')
    projection = old._export_projection(exports)
    assert len(projection) == 142
    files = canonical_files(projection)
    assert set(files) == set(ref['canonical_exports'])
    for name in files:
        assert sha(RUN / 'recovery_audit_t3d' / name) == ref['canonical_exports'][name], name
    # All explicit HISM settings, exact source poses, actor identities and brush
    # evidence still match the application. Only raw SHA references now refer
    # to the saved/reloaded native form, whose bytes were compared above.
    expected = copy.deepcopy(applied['full_actor_component_exports_after'])
    for actor, row in expected.items():
        row['export_sha256'] = ref['canonical_exports'][actor + '.t3d']
        for component, record in row['components'].items():
            record['export_sha256'] = ref['canonical_exports'][actor + '__' + component + '.t3d']
    assert projection == expected
    assert old._guards(ref['immutable_guards'], map_sha=MAP_SHA)
    old._collision_exact(applied['collision_hashes_after'])
    _, auto_save, _, cook = old._settings(sync.u)
    assert auto_save is True and cook == type(cook).ENABLE
    return write('audit_recovered.json', dict(status='RELOAD_AUDITED',
        recovery_reference_sha256=reference_sha, recovery_unloaded_sha256=unloaded_sha,
        actor_component_roster=roster, full_actor_component_exports=projection,
        canonical_raw_exports_exact_across_two_reloads=True, no_text_normalization=True,
        total_instances=32646, selected_wall_instances=1194, roster_actor_count=134,
        full_export_actor_count=142, immutable_guards=ref['immutable_guards'],
        collision_hashes=applied['collision_hashes_after'], settings_restored=True,
        boundary='Read-only saved Diorama audit. No reapply, additional save, gameplay or runtime-lighting claim.'))
