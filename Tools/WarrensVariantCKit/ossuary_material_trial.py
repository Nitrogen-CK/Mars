"""Scoped PIE-only Ossuary material comparison with complete HISM restoration.

Import is inert. begin(B, C) records exact source placements before any override;
switch('A'/'B'/'C') changes material slots only. finish() restores and checks all
HISMs and all protected files. No map/asset, inventory, light or puzzle writes.
"""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryMaterialTrial'
CORE = HERE / 'bank_identity_unreal.py'
CORE_SHA = '4859e7ab71dc9e0a5d93b61511eb759ef741598af4821ba62df69cd8ee014619'
BASELINE = ROOT / 'Saved/WarrensCGameplay-20261024/MechanismLayoutCheckpoint/source_layout_20261025T090434_092884Z_1e6e87b9.json'
BASELINE_SHA = 'a23c2d371433c647061446bbcd822d138094bf2774f739d364622a8ea8ab260f'
FIT = HERE / 'Output/fitted_instances.json'
FIT_SHA = '67f8e8d87ab166ab7fd0cd5e285a08e02b8643c856de3bf028130271021b9d34'
SOURCE = '/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX01'
OWNED = '/Game/Mars/ArtReview/Lookdev/OssuaryPainterly_20261025/Materials/'
STATE = None


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def core():
    assert sha(CORE) == CORE_SHA
    name = '_ossuary_material_trial_frozen_collectors'
    if name not in sys.modules:
        spec = importlib.util.spec_from_file_location(name, CORE)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules[name] = module
    return sys.modules[name]


def write(phase, record):
    OUT.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ')
    path = OUT / ('pie_' + phase + '_' + stamp + '.json')
    assert not path.exists()
    path.write_text(json.dumps(dict(record, phase=phase, tool_sha256=sha(__file__)), indent=2) + '\n')
    return dict(receipt=str(path.relative_to(ROOT)), sha256=sha(path))


def world():
    import unreal as u
    value = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert value and 'UEDPIE_0_Warrens_VariantC_Mars_MAP' in value.get_path_name()
    return value


def file_guards():
    assert sha(BASELINE) == BASELINE_SHA and sha(FIT) == FIT_SHA
    expected = json.loads(BASELINE.read_bytes())['initial_614_guards']
    assert len(expected) == 614
    assert all(sha(ROOT / p) == h for p, h in expected.items()), 'Protected source files changed'
    return expected


def source_rows():
    data = json.loads(FIT.read_bytes())
    paths, materials = {}, {}
    for kit in ('ChainCrossingKit', 'PumpCisternKit', 'WarrensVariantCKit'):
        manifest = json.loads((HERE.parent / kit / 'Output/asset_manifest.json').read_bytes())
        for row in manifest['assets']:
            paths[row['id']] = '/Game/Mars/Environment/' + kit + '/Meshes/' + row['name']
            materials[row['id']] = row['material_keys']
    rows = []
    for index, row in enumerate(data['placements']):
        if row['tile'] != 'Ossuary':
            continue
        ident = row.get('mesh_id', row['id'])
        if ident not in paths:
            assert ident.startswith(('BACKING_', 'SOURCE_CUBE_'))
            paths[ident] = '/Engine/BasicShapes/Cube'
        keys = list(materials.get(ident, [row.get('material')]))
        if row.get('material'):
            keys[0] = row['material']
        assert all(keys)
        rows.append(dict(key=index, row=row, label='WVC_' + row['id'], mesh=paths[ident],
            materials=['/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_' + k for k in keys],
            target_slots=[i for i, key in enumerate(keys) if key == 'TX01']))
    assert len(rows) == 2218
    return data['pivots']['Ossuary'], rows


def begin(material_b, material_c):
    import unreal as u
    global STATE
    assert STATE is None
    w = world()
    helper = core()
    assert helper._dirty() == dict(maps=[], content=[])
    guards = file_guards()
    assert material_b.startswith(OWNED) and material_c.startswith(OWNED) and material_b != material_c
    variants = {key: u.load_asset(path) for key, path in [('B', material_b), ('C', material_c)]}
    assert all(isinstance(value, u.Material) for value in variants.values())
    actors, before = helper._hism_snapshot(w)
    candidates = [a for a in actors if 'LI_Warrens_Ossuary' in a.get_level().get_path_name()]
    levels = {a.get_level().get_path_name() for a in candidates}
    assert len(levels) == 1 and candidates, ('Expected exactly one streamed Ossuary level', levels)
    assert all(a.get_level().get_outer() != w for a in candidates)
    by_label = {}
    for actor in candidates:
        by_label.setdefault(actor.get_actor_label(), []).append(actor)
    pivot, rows = source_rows()
    grouped = {}
    for row in rows:
        grouped.setdefault(row['label'], []).append(row)
    targets, matched = [], []
    for label, expected in grouped.items():
        found = by_label.get(label, [])
        assert len(found) == 1, ('Missing/duplicate original Ossuary art actor', label, len(found))
        actor = found[0]
        components = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        assert len(components) == 1
        component = components[0]
        snap = before[component.get_path_name()]
        assert snap['collision_profile'] == 'NoCollision'
        assert component.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
        assert snap['mesh'] == expected[0]['mesh']
        assert snap['materials'] == expected[0]['materials']
        assert len(snap['instances']) == len(expected)
        transforms = [component.get_instance_transform(i, world_space=True) for i in range(component.get_instance_count())]
        used = set()
        for record in expected:
            row = record['row']
            pitch, yaw, roll = row.get('rotation', [0, row.get('yaw', 0), 0])
            local = u.Transform(location=u.Vector(*[(row['at'][i]-pivot[i])*100 for i in range(3)]),
                rotation=u.Rotator(pitch=pitch, yaw=yaw, roll=roll), scale=u.Vector(*row['scale']))
            wanted = u.MathLibrary.compose_transforms(local, actor.get_level_transform())
            indices = [i for i, value in enumerate(transforms) if helper._near(value, wanted)]
            assert len(indices) == 1 and indices[0] not in used, ('Ossuary instance pose mismatch', record['key'], indices)
            used.add(indices[0])
            assert record['mesh'] == snap['mesh'] and record['materials'] == snap['materials']
            matched.append(dict(source_key=record['key'], component=component.get_path_name(), index=indices[0],
                                target_slots=record['target_slots']))
        assert len(used) == len(transforms)
        for slot in expected[0]['target_slots']:
            original = component.get_material(slot)
            assert helper._package(original) == SOURCE
            targets.append((component, slot, original))
    assert len(matched) == 2218 and targets
    full_room_hisms = [c for a in candidates for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)]
    # The original source also owns six authoritative greybox collision groups.
    # They remain in the complete before/after snapshot and are never targets.
    assert len(full_room_hisms) == 21 and sum(c.get_instance_count() for c in full_room_hisms) == 2710
    art_hisms = [c for a in candidates if a.get_actor_label().startswith('WVC_')
                 for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)]
    assert len(art_hisms) == len(grouped) == 15
    assert sum(c.get_instance_count() for c in art_hisms) == 2218
    state = dict(world=w, before=before, guards=guards, targets=targets, variants=variants, current='A')
    receipt = write('ready', dict(world=w.get_path_name(), level=next(iter(levels)), hism_count=len(before),
        matched_source_placements=matched, target_slots=[dict(component=c.get_path_name(), slot=i,
        material=helper._package(m), instances=c.get_instance_count()) for c, i, m in targets],
        material_variants={k: helper._package(v) for k, v in variants.items()}, baseline_hisms=before,
        protected_files=guards, dirty=helper._dirty(),
        boundary='Read-only live-roster preflight. Full source includes ceilings omitted from the Blender cutaway. No material, map, puzzle, inventory or light edit yet.'))
    STATE = state
    return dict(status='READY_UNMODIFIED', **receipt, components=len(targets), matched_instances=len(matched))


def verify():
    assert STATE and world() == STATE['world']
    _, actual = core()._hism_snapshot(STATE['world'])
    expected = copy.deepcopy(STATE['before'])
    for component, slot, original in STATE['targets']:
        material = original if STATE['current'] == 'A' else STATE['variants'][STATE['current']]
        expected[component.get_path_name()]['materials'][slot] = core()._package(material)
    assert actual == expected, 'Unexpected geometry, material, collision or unselected HISM change'
    assert file_guards() == STATE['guards']
    assert core()._dirty() == dict(maps=[], content=[])
    return dict(state=STATE['current'], hisms=len(actual), complete_hism_roster_matches=True,
                all_614_files_exact=True, dirty=core()._dirty())


def switch(stage):
    assert STATE and stage in ('A', 'B', 'C') and world() == STATE['world']
    for component, slot, original in STATE['targets']:
        component.set_material(slot, original if stage == 'A' else STATE['variants'][stage])
    STATE['current'] = stage
    result = verify()
    return dict(**result, **write('switch_' + stage, result))


def finish():
    global STATE
    result = switch('A')
    result.update(status='RESTORED_ALL_ORIGINAL_BINDINGS', **write('restored', result))
    STATE = None
    return result
