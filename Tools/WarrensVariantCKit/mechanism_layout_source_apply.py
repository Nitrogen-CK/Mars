"""Sequential current-editor-source-level P1/P5 transfer for Warrens Variant C.

Import is inert. The editor operator opens the indicated source level between
phases and invokes each function from a separate callback. The intermediate
Reliquary save is intentionally incomplete: do not enter PIE until Belfry's
old P5 source is removed and Pit's P1 transform is saved. On any failure after
the first mutation, close the editor and restore all three PREPARED map files
as one rollback unit.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RUN = ROOT / 'Saved/WarrensCGameplay-20261024'
CHECKPOINT = RUN / 'MechanismLayoutCheckpoint'
CORE_PATH = HERE / 'bank_identity_unreal.py'
CORE_SHA256 = '4859e7ab71dc9e0a5d93b61511eb759ef741598af4821ba62df69cd8ee014619'
OLD_PATH = HERE / 'mechanism_layout_apply.py'
OLD_SHA256 = 'dad283fe064036a2cbaefede549174369c4a99b6770f9040604fc73c27b16e66'
RECOVERY = CHECKPOINT / 'mechanism_layout_20261025T084133_321578Z_be8b48cc.json'
RECOVERY_SHA256 = 'c6ae5f4a037b42693f86346ce8a14764ac3af2911dc9da996e0e8d8677b9294c'
PREPARED = CHECKPOINT / 'mechanism_layout_20261025T084421_368819Z_4178ed4a.json'
PREPARED_SHA256 = '7807d37b2cef468e39a565052eb31b839634668c89ab7b43e62bed0704e3083d'
REL_PROBE = CHECKPOINT / 'mechanism_layout_20261025T084445_414017Z_43a4dc31.json'
REL_PROBE_SHA256 = '0f825e146a30ee3409e9093cb91cc43c6bf764a59c3ab07d436a7b6ca4b57318'
COLLISION_HASHES = RUN / 'StartupCheckpoint/collision_hashes.json'
EXPECTED_MAIN = '/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'
STATE_MODULE = '_mars_warrensc_mechanism_layout_source_apply_state'

MAPS = {
    'Belfry': dict(package='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Belfry',
                   path='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Belfry.LI_Warrens_Belfry',
                   initial_sha256='cbdcbc49774b21ff706b5883d39c9a8377ac2fc85c2ee7c9f49e65966fd32c21',
                   label='Warrens_LI_Belfry'),
    'Reliquary': dict(package='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Reliquary',
                      path='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Reliquary.LI_Warrens_Reliquary',
                      initial_sha256='a479d5b40f3c39209248149011e9be84d8f1c265308923397eacc622d3ec663c',
                      label='Warrens_LI_Reliquary'),
    'Pit': dict(package='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Pit',
                path='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Pit.LI_Warrens_Pit',
                initial_sha256='9d85466d625ec46cbcbd840d28209b147c11e20e878860df440e01f2ae499afd',
                label='Warrens_LI_Pit'),
}
P5 = dict(label='Warrens_Mars_Lever_EntityScript_3', actor_name='Ck_EntitySpawner_UE_2',
          script_class='Mars_Lever_EntityScript', channel='Mechanism.Channel.Warrens.Puzzle.P5',
          fields=('SpawnTransform', 'Control', 'Source', 'PulledAngle', 'MoveDuration', 'PromptText'),
          destination='Reliquary', local=(1300.0, 750.0, 0.3), assembled=(2300.0, 1850.0, 250.3),
          yaw=0.0)
P1 = dict(label='Warrens_Mars_Sandbox_KeyLock_Red_EntityScript_5', actor_name='Ck_EntitySpawner_UE_2',
          script_class='Mars_Sandbox_KeyLock_Red_EntityScript',
          fields=('SpawnTransform', 'AcceptedKey', 'Release', 'Source'),
          destination='Pit', local=(4050.0, 3651.2, 100.0), assembled=(-1350.0, 351.2, -400.0),
          pitch=-90.0, yaw=90.0)

# These exact transient classes were observed in the current source-world editor
# and confirmed RF_Transient at the native declarations/call sites. They are
# tracked separately from serialized source actors; no other class is excluded.
TRANSIENT_CLASSES = {
    'Ck_EditorSelectionProxyHost_Actor_UE',
    'MassVisualizer',
    'GameplayDebuggerPlayerManager',
    'AbstractNavData',
    'SmartObjectSubsystemRenderingActor',
}
PROTOGRID_MATERIAL = '/Game/Mars/Materials/ProtoGrid/ProtoGrid_Interactable_Mars_MI.ProtoGrid_Interactable_Mars_MI'
P1_PRIMARY_COLORS = ((0.85, 0.08, 0.06, 1.0), (0.03, 0.03, 0.03, 1.0))


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _write(record):
    CHECKPOINT.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '_' + uuid.uuid4().hex[:8]
    path = CHECKPOINT / ('source_layout_' + stamp + '.json')
    assert not path.exists(), 'Refuse to overwrite a phase receipt'
    row = dict(record, schema=1, created_utc=datetime.now(timezone.utc).isoformat(),
               tool_sha256=_sha(__file__))
    path.write_text(json.dumps(row, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    return path


def _u():
    import unreal
    return unreal


def _old():
    assert _sha(OLD_PATH) == OLD_SHA256, 'Frozen prior helper changed'
    name = '_mars_warrensc_mechanism_layout_frozen_pure'
    module = sys.modules.get(name)
    if module is None:
        spec = importlib.util.spec_from_file_location(name, OLD_PATH)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules[name] = module
    return module


def _core():
    assert _sha(CORE_PATH) == CORE_SHA256, 'Frozen 614-file guard helper changed'
    name = '_mars_warrensc_mechanism_layout_source_guard'
    module = sys.modules.get(name)
    if module is None:
        spec = importlib.util.spec_from_file_location(name, CORE_PATH)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules[name] = module
    return module


def _state():
    if STATE_MODULE not in sys.modules:
        import types
        sys.modules[STATE_MODULE] = types.ModuleType(STATE_MODULE)
        sys.modules[STATE_MODULE].active = None
    return sys.modules[STATE_MODULE]


def _receipt(path, digest, phases):
    path = Path(path)
    if not path.is_absolute():
        path = ROOT / path
    path = path.resolve()
    try:
        path.relative_to(CHECKPOINT.resolve())
    except ValueError:
        raise AssertionError('Refuse receipt outside mechanism-layout checkpoint')
    assert path.is_file() and _sha(path) == digest, 'Receipt hash mismatch'
    row = _json(path)
    assert row.get('schema') == 1 and row.get('phase') in phases, (row.get('phase'), phases)
    inherited = row.get('inherited', {})
    assert isinstance(inherited, dict)
    for key, value in inherited.items():
        assert key not in row or row[key] == value, ('Conflicting inherited receipt value', key)
        row.setdefault(key, value)
    return path, row


def _inherit(report):
    """Carry the finite source-chain invariants through each immutable phase receipt."""
    keys = ('original_rosters', 'p5_source', 'p1_source', 'initial_614_guards', 'collision_54',
            'belfry_final_authored', 'reliquary_final_authored', 'pit_final_authored')
    return {key: report[key] for key in keys if key in report}


def _package_hashes():
    rows = {}
    for tile, spec in MAPS.items():
        path = ROOT / ('Content/' + spec['package'].removeprefix('/Game/') + '.umap')
        assert path.is_file(), ('Missing source map', tile)
        rows[tile] = _sha(path)
    return rows


def _dirty(u):
    def name(value):
        return value.get_path_name().split('.')[0] if hasattr(value, 'get_path_name') else str(value).split('.')[0]
    return dict(maps=sorted(name(x) for x in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()),
                content=sorted(name(x) for x in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()))


def _editor_world(u, tile, allow_target_dirty=False):
    editor = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    world = editor.get_editor_world()
    assert world, 'No current editor world'
    expected = MAPS[tile]['path']
    assert world.get_path_name() == expected, ('Open exact source level before this phase', tile, world.get_path_name())
    assert editor.get_game_world() is None, 'PIE must remain stopped throughout staged transfer'
    dirty = _dirty(u)
    allowed = {MAPS[tile]['package']} if allow_target_dirty else set()
    assert set(dirty['maps']) <= allowed and not dirty['content'], ('Unexpected dirty packages', dirty)
    return world, dirty


def _main_instance_worlds(u):
    editor = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    main = editor.get_editor_world()
    assert main and main.get_path_name().split('.')[0] == EXPECTED_MAIN
    assert editor.get_game_world() is None
    actors = u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
    out = {}
    instances = {}
    for tile, spec in MAPS.items():
        found = [actor for actor in actors if actor.get_actor_label() == spec['label']]
        assert len(found) == 1 and found[0].get_class().get_name() == 'LevelInstance'
        asset = found[0].get_editor_property('world_asset')
        assert asset and asset.get_path_name() == spec['path']
        out[tile] = asset
        instances[tile] = found[0]
    return main, out, instances


def _find_actor(u, world, spec):
    matches = [a for a in u.GameplayStatics.get_all_actors_of_class(world, u.Actor)
               if a.get_actor_label() == spec['label']]
    assert len(matches) == 1, ('Expected one mechanism actor', spec['label'], [a.get_path_name() for a in matches])
    actor = matches[0]
    assert actor.get_name() == spec['actor_name'] and actor.get_class().get_name() == 'Ck_EntitySpawner_UE'
    script = actor.get_editor_property('_EntityScript')
    assert script and script.get_class().get_name() == spec['script_class']
    assert script.get_outer() == actor
    return actor, script


def _all_actors(u, world):
    return list(u.GameplayStatics.get_all_actors_of_class(world, u.Actor))


def _rows(u, helper, world, expected_transient_classes=None):
    rows = helper._world_roster(u, world)
    actors = sorted(_all_actors(u, world), key=lambda a: a.get_path_name())
    authored, transient = [], []
    class_counts = {}
    for actor, row in zip(actors, rows):
        cls = actor.get_class().get_name()
        # The Python 5.7.4 UObject binding does not expose has_any_flags or
        # ObjectFlags. Classification is therefore limited to these five exact
        # native-proved RF_Transient classes and each full actor row is retained.
        if cls in TRANSIENT_CLASSES:
            if cls == 'Ck_EditorSelectionProxyHost_Actor_UE':
                components = {(component.get_name(), component.get_class().get_name()): component
                              for component in actor.get_components_by_class(u.ActorComponent)}
                for component_row in row['components']:
                    if component_row['class_name'] != 'StaticMeshComponent':
                        continue
                    component = components[(component_row['name'], component_row['class_name'])]
                    component_row['material_semantics'] = _component_material_semantics(u, component)
            transient.append(row)
            class_counts[cls] = class_counts.get(cls, 0) + 1
        else:
            authored.append(row)
    assert all(count == 1 for count in class_counts.values()), ('Duplicate editor-generated actor class', class_counts)
    assert set(class_counts) <= TRANSIENT_CLASSES, ('Unexpected generated actor class', class_counts)
    if expected_transient_classes is not None:
        assert class_counts == expected_transient_classes, ('Editor-generated actor roster changed', class_counts,
                                                             expected_transient_classes)
    return dict(authored=authored, transient=transient, transient_classes=class_counts, all=rows)


def _source_roster_state(u, helper, tile, world, expected_transient_classes=None):
    rows = _rows(u, helper, world, expected_transient_classes)
    return dict(tile=tile, world=world.get_path_name(), authored=rows['authored'],
                transient=rows['transient'], transient_classes=rows['transient_classes'], all=rows['all'])


def _assert_maps_and_guards(core, expected_maps, expected_guards, expected_collision):
    maps = _package_hashes()
    assert maps == expected_maps, ('Source map chain changed', maps, expected_maps)
    guards = core._content_guards()
    assert set(guards) == set(expected_guards), 'Protected file roster changed'
    assert guards == expected_guards, 'Protected 614-file hashes changed beyond approved staged maps'
    collision = _json(COLLISION_HASHES)
    assert len(collision) == 54
    current_collision = {rel: _sha(ROOT / rel) for rel in collision}
    assert current_collision == expected_collision == collision, 'Protected 54-file collision set changed'
    return guards, current_collision


def _allowed_guards(base, maps):
    allowed = dict(base)
    for tile, spec in MAPS.items():
        rel = 'Content/' + spec['package'].removeprefix('/Game/') + '.umap'
        assert rel in allowed
        allowed[rel] = maps[tile]
    return allowed


def _selection(u):
    subsystem = u.get_editor_subsystem(u.EditorActorSubsystem)
    assert hasattr(subsystem, 'get_selected_level_actors') and hasattr(subsystem, 'set_selected_level_actors'), (
        'Public editor selection snapshot/restore API unavailable')
    return subsystem, list(subsystem.get_selected_level_actors())


def _target_transform(u, spec):
    rot = u.Rotator(pitch=spec.get('pitch', 0.0), yaw=spec['yaw'], roll=0.0)
    return u.Transform(location=u.Vector(*spec['local']), rotation=rot, scale=u.Vector(1.0, 1.0, 1.0))


def _assert_transform(helper, actor, transform):
    helper._assert_actor_transform(actor, transform)


def _actor_key(row):
    return (row['path'], row['label'], row['cls'])


def _authored_delta(before, after, added=(), removed=(), modified=()):
    before_rows = {_actor_key(r): r for r in before}
    after_rows = {_actor_key(r): r for r in after}
    for key in added:
        assert key not in before_rows and key in after_rows, ('Missing expected added actor', key)
    for key in removed:
        assert key in before_rows and key not in after_rows, ('Unexpected expected removal', key)
    allowed = set(added) | set(removed) | set(modified)
    common = (set(before_rows) & set(after_rows)) - allowed
    assert all(before_rows[key] == after_rows[key] for key in common), 'Unrelated authored actor rows changed'
    assert set(after_rows) - set(before_rows) == set(added)
    assert set(before_rows) - set(after_rows) == set(removed)
    assert set(before_rows) & set(after_rows) >= set(modified)


def _proxy_actor(snapshot):
    hosts = [row for row in snapshot if row['cls'] == 'Ck_EditorSelectionProxyHost_Actor_UE']
    assert len(hosts) == 1, ('Expected one editor selection proxy host', [row['path'] for row in hosts])
    return hosts[0]


def _part_world_transform(u, root_transform, location, rotation, scale):
    local = u.Transform(location=u.Vector(*location), rotation=u.Rotator(**rotation), scale=u.Vector(*scale))
    return _old()._serial(u.MathLibrary.compose_transforms(local, root_transform))


def _transform_equal(actual, expected):
    if not isinstance(actual, dict) or not isinstance(expected, dict):
        return False
    return (all(abs(a-b) <= 0.02 for a, b in zip(actual.get('location', ()), expected.get('location', ())))
            and all(abs(a-b) <= 1.0e-5 for a, b in zip(actual.get('rotation_xyzw', ()), expected.get('rotation_xyzw', ())))
            and all(abs(a-b) <= 1.0e-5 for a, b in zip(actual.get('scale', ()), expected.get('scale', ()))))


def _component_base(component):
    row = dict(component)
    row.pop('world_transform', None)
    row.pop('relative_transform', None)
    return row


def _component_visual_contract(component):
    keys = ('class_name', 'mesh', 'collision_profile', 'collision', 'overlap', 'visible', 'shadow', 'mobility')
    return {key: component.get(key) for key in keys}


def _proxy_components(row):
    result = {}
    for component in row['components']:
        key = (component['name'], component['class_name'])
        assert key not in result, ('Duplicate proxy component key', key)
        result[key] = component
    return result


def _component_material_semantics(u, component):
    materials = []
    for slot, material in enumerate(component.get_materials()):
        assert material, ('Preview material slot is empty', component.get_path_name(), slot)
        dynamic = isinstance(material, u.MaterialInstanceDynamic)
        parent = material.get_editor_property('parent') if dynamic else material
        assert parent, ('Missing preview material parent', component.get_path_name(), slot)
        color = None
        if dynamic:
            value = material.get_vector_parameter_value('PrimaryColor')
            color = [float(value.r), float(value.g), float(value.b), float(value.a)]
        materials.append(dict(slot=slot, dynamic=dynamic, path=material.get_path_name(),
                              parent=parent.get_path_name(), primary_color=color))
    return materials


def _assert_preview_material(component, expected_color=None):
    semantics = component.get('material_semantics')
    assert isinstance(semantics, list) and len(semantics) == 1, ('Unexpected preview material slots', component)
    material = semantics[0]
    assert material['parent'] == PROTOGRID_MATERIAL, ('Unexpected preview material parent', material)
    if expected_color is None:
        assert material['dynamic'] is False and material['path'] == PROTOGRID_MATERIAL
        assert material['primary_color'] is None
    else:
        assert material['dynamic'] is True and material['primary_color'] is not None
        assert all(abs(a-b) <= 1.0e-4 for a, b in zip(material['primary_color'], expected_color)), (
            'Preview material PrimaryColor differs from source FMars_MeshPart', material, expected_color)


def _component_matches(component, mesh_suffix, transform):
    return (component['class_name'] == 'StaticMeshComponent'
            and str(component.get('mesh', '')).endswith(mesh_suffix)
            and bool(component.get('materials'))
            and _transform_equal(component.get('world_transform'), transform))


def _expected_p5_parts(u, actor_transform):
    return [
        ('Cylinder.Cylinder', _part_world_transform(u, actor_transform, (0.0, 0.0, 0.0),
            dict(pitch=0.0, yaw=0.0, roll=90.0), (0.24, 0.24, 0.5)), 'BlockAll'),
        ('LeverHandle_Mars_SM.LeverHandle_Mars_SM', _part_world_transform(u, actor_transform, (0.0, 0.0, 45.0),
            dict(pitch=0.0, yaw=0.0, roll=0.0), (0.08, 0.08, 0.9)), 'NoCollision'),
    ]


def _expected_p1_parts(u, actor_transform):
    return [
        ('Cube.Cube', _part_world_transform(u, actor_transform, (0.0, 0.0, 3.0),
            dict(pitch=0.0, yaw=0.0, roll=0.0), (0.4, 0.4, 0.06)), 'BlockAll', None),
        ('Cylinder.Cylinder', _part_world_transform(u, actor_transform, (0.0, 0.0, 7.0),
            dict(pitch=0.0, yaw=0.0, roll=0.0), (0.24, 0.24, 0.02)), 'NoCollision', P1_PRIMARY_COLORS[0]),
        ('Cube.Cube', _part_world_transform(u, actor_transform, (0.0, 0.0, 8.2),
            dict(pitch=0.0, yaw=0.0, roll=0.0), (0.04, 0.12, 0.01)), 'NoCollision', P1_PRIMARY_COLORS[1]),
    ]


def _pose_transform(u, pose):
    rotation = pose['rotation']  # Unreal Rotator.to_tuple() is roll, pitch, yaw.
    return u.Transform(location=u.Vector(*pose['location']),
                       rotation=u.Rotator(roll=rotation[0], pitch=rotation[1], yaw=rotation[2]),
                       scale=u.Vector(*pose['scale']))


def _validate_transient_delta(before_rows, after_rows, event, p1_before_pose=None, p5_before_pose=None):
    """Validate proxy-host StaticMeshComponents, not hypothetical HISM instances."""
    before = {row['path']: row for row in before_rows}
    after = {row['path']: row for row in after_rows}
    assert set(before) == set(after), 'Editor-generated actor roster/path changed'
    proxy_path = next(path for path, row in before.items() if row['cls'] == 'Ck_EditorSelectionProxyHost_Actor_UE')
    for path in before:
        if path != proxy_path:
            assert before[path] == after[path], ('Unrelated generated actor changed', path)
    old_proxy, new_proxy = before[proxy_path], after[proxy_path]
    old_comps, new_comps = _proxy_components(old_proxy), _proxy_components(new_proxy)
    if event in ('add_p5', 'remove_p5'):
        added_keys = set(new_comps) - set(old_comps)
        removed_keys = set(old_comps) - set(new_comps)
        assert len(added_keys) == (2 if event == 'add_p5' else 0)
        assert len(removed_keys) == (2 if event == 'remove_p5' else 0)
        for key in set(old_comps) & set(new_comps):
            assert old_comps[key] == new_comps[key], ('Existing preview component changed', key)
        actor_transform = (_target_transform(_u(), P5) if event == 'add_p5'
                           else _pose_transform(_u(), p5_before_pose))
        assert actor_transform, 'P5 removal requires pinned original actor pose'
        parts = _expected_p5_parts(_u(), actor_transform)
        changed = [new_comps[key] for key in added_keys] if event == 'add_p5' else [old_comps[key] for key in removed_keys]
        unmatched = list(changed)
        for mesh, transform, collision in parts:
            matches = [i for i, comp in enumerate(unmatched)
                       if _component_matches(comp, mesh, transform)
                       and comp['collision_profile'] == collision]
            assert len(matches) == 1, ('P5 preview mesh/material/pose/collision differs', mesh, transform, unmatched)
            match = unmatched.pop(matches[0])
            _assert_preview_material(match)
        assert not unmatched
        return dict(event=event, added_components=[new_comps[k] for k in sorted(added_keys)],
                    removed_components=[old_comps[k] for k in sorted(removed_keys)],
                    expected_parts=parts)
    assert event == 'move_p1' and p1_before_pose is not None
    old_root = _pose_transform(_u(), p1_before_pose)
    old_expected = _expected_p1_parts(_u(), old_root)
    new_expected = _expected_p1_parts(_u(), _target_transform(_u(), P1))
    removed_keys = set(old_comps) - set(new_comps)
    added_keys = set(new_comps) - set(old_comps)
    assert len(removed_keys) == 3 and len(added_keys) == 3, (
        'P1 PostEditMove must replace exactly its three preview components', removed_keys, added_keys)
    for key in set(old_comps) & set(new_comps):
        assert old_comps[key] == new_comps[key], ('Unrelated preview component changed', key)
    old_unused, new_unused = list(removed_keys), list(added_keys)
    replacements = []
    for (mesh, old_transform, collision, color), (new_mesh, new_transform, new_collision, new_color) in zip(old_expected, new_expected):
        assert mesh == new_mesh
        assert (collision, color) == (new_collision, new_color)
        candidates = [key for key in old_unused
                      if _component_matches(old_comps[key], mesh, old_transform)
                      and old_comps[key]['collision_profile'] == collision]
        assert len(candidates) == 1, ('Could not identify exact previous P1 preview component', mesh, old_transform)
        key = candidates[0]
        old_unused.remove(key)
        candidates = [candidate for candidate in new_unused
                      if _component_matches(new_comps[candidate], mesh, new_transform)
                      and new_comps[candidate]['collision_profile'] == collision]
        assert len(candidates) == 1, ('Could not identify exact rebuilt P1 preview component', mesh, new_transform)
        new_key = candidates[0]
        new_unused.remove(new_key)
        assert _component_visual_contract(old_comps[key]) == _component_visual_contract(new_comps[new_key]), (
            'P1 preview collision or mesh settings changed during rebuild', mesh)
        _assert_preview_material(old_comps[key], color)
        _assert_preview_material(new_comps[new_key], color)
        replacements.append((key, new_key))
    assert not old_unused and not new_unused
    assert len(replacements) == 3
    return dict(event=event, replaced_components=[dict(before=old_comps[old_key], after=new_comps[new_key])
                                                  for old_key, new_key in replacements],
                expected_old=old_expected, expected_new=new_expected)


def _current_saved_chain(receipt):
    return dict(receipt['current_map_sha256'])


def _base_guards(receipt):
    return dict(receipt['initial_614_guards'])


def _write_failure(phase, parent_path, parent_sha, error, extra=None):
    row = dict(phase=phase, parent_receipt=parent_path, parent_receipt_sha256=parent_sha,
               error=repr(error), recovery='Do not retry. Stop PIE/editor work and restore the three original PREPARED map checkpoints as one unit.')
    if extra:
        row.update(extra)
    return _write(row)


def prepare_reliquary(prepared_path=None, prepared_sha256=None, probe_path=None, probe_sha256=None):
    """Bind the accepted original checkpoint to the parent read-only Reliquary probe."""
    u = _u()
    state = _state()
    assert state.active is None, 'Previous source phase still retains editor objects'
    if prepared_path is None:
        prepared_path, prepared_sha256 = PREPARED, PREPARED_SHA256
    if probe_path is None:
        probe_path, probe_sha256 = REL_PROBE, REL_PROBE_SHA256
    prepared_file, prepared = _receipt(prepared_path, prepared_sha256, {'PREPARED'})
    probe_file, probe = _receipt(probe_path, probe_sha256, {'SOURCE_RELIQUARY_READONLY'})
    helper = _old()
    core = _core()
    recovery = _json(RECOVERY)
    assert _sha(RECOVERY) == RECOVERY_SHA256 and recovery['phase'] == 'FIRST_ATTEMPT_RESTORED'
    assert recovery['active_state'] is None
    assert recovery['all_614_file_guards_exact'] is True and recovery['all_three_source_rosters_exact'] is True
    assert recovery['dirty'] == dict(maps=[], content=[])
    assert recovery['source_roster_counts'] == {tile: len(rows) for tile, rows in prepared['source_rosters'].items()}
    assert recovery['prepared_receipt']['phase'] == 'PREPARED'
    recovery_prepared_path = ROOT / recovery['prepared_receipt']['path']
    assert _sha(recovery_prepared_path) == recovery['prepared_receipt']['sha256']
    recovery_prepared = _json(recovery_prepared_path)
    assert recovery_prepared['before_map_sha256'] == prepared['before_map_sha256']
    assert recovery_prepared['source_rosters'] == prepared['source_rosters']
    assert recovery['prepared_receipt']['maps_before'] == prepared['before_map_sha256']
    assert _sha(OLD_PATH) == OLD_SHA256
    assert _sha(CORE_PATH) == CORE_SHA256
    world, dirty = _editor_world(u, 'Reliquary')
    assert not dirty['maps'] and not dirty['content']
    maps = _package_hashes()
    assert maps == prepared['before_map_sha256']
    # Original authored maps and guards remain the initial C checkpoint.
    base_guards = prepared['guards']['protected_614']
    collision = prepared['guards']['collision_54']
    guards, collision_now = _assert_maps_and_guards(core, maps, base_guards, collision)
    rows = _source_roster_state(u, helper, 'Reliquary', world,
                                {name: 1 for name in TRANSIENT_CLASSES})
    expected_authored = prepared['source_rosters']['Reliquary']
    assert rows['authored'] == expected_authored and len(rows['authored']) == 30
    assert probe['world'] == MAPS['Reliquary']['path'] and probe['roster_count'] == 35
    # The probe is accepted only as corroboration of the actual live snapshot;
    # do not admit rows solely because they appear in its JSON.
    assert not probe['dirty']['maps'] and not probe['dirty']['content'] and probe['disk_guards_exact'] is True
    belfry_world = u.load_asset(MAPS['Belfry']['path'])
    pit_world = u.load_asset(MAPS['Pit']['path'])
    assert belfry_world and pit_world
    assert _find_actor(u, belfry_world, P5)[0].get_actor_label() == P5['label']
    assert _find_actor(u, pit_world, P1)[0].get_actor_label() == P1['label']
    inst_transform = world.get_path_name()
    record = dict(phase='RELIQUARY_READY', parent_prepared=prepared_file.relative_to(ROOT).as_posix(),
                  parent_prepared_sha256=prepared_sha256, source_probe=probe_file.relative_to(ROOT).as_posix(),
                  source_probe_sha256=probe_sha256, recovery_receipt=RECOVERY.relative_to(ROOT).as_posix(),
                  recovery_receipt_sha256=RECOVERY_SHA256, maps_before=maps, current_map_sha256=maps,
                  initial_614_guards=guards, collision_54=collision_now,
                  original_rosters=prepared['source_rosters'], current_reliquary=rows,
                  source_world=inst_transform, dirty_before=dirty,
                  transient_class_native_basis={
                      'Ck_EditorSelectionProxyHost_Actor_UE': 'CkEcsEditor_Subsystem.cpp:204 sets RF_Transient before host spawn',
                      'MassVisualizer': 'MassRepresentation/Public/MassVisualizer.h:17 UCLASS(Transient)',
                      'GameplayDebuggerPlayerManager': 'GameplayDebuggerPlayerManager.h:32 UCLASS(Transient)',
                      'AbstractNavData': 'NavigationSystem.cpp:1069 SetFlags(RF_Transient)',
                      'SmartObjectSubsystemRenderingActor': 'SmartObjectSubsystemRenderingActor.h:34 UCLASS(Transient)',
                  },
                  transient_policy='All five currently observed editor actors must each carry RF_Transient and be one of the exact listed classes. Authored rows are compared separately; no other class is filtered.',
                  p5_source=prepared['mechanisms_before']['P5'], p1_source=prepared['mechanisms_before']['P1'],
                  expected_current_editor_world=MAPS['Reliquary']['path'], map_save_performed=False,
                  completion='Prepared only; no source map mutated.')
    path = _write(record)
    return dict(status='RELIQUARY_READY', receipt=path.relative_to(ROOT).as_posix(), sha256=_sha(path),
                authored_actors=len(rows['authored']), transient_actors=len(rows['transient']))


def duplicate_p5_into_reliquary(receipt_path, receipt_sha256):
    """Duplicate the saved Belfry lever into the currently open Reliquary; never save here."""
    u = _u()
    state = _state()
    assert state.active is None, 'A source phase is already active'
    path, report = _receipt(receipt_path, receipt_sha256, {'RELIQUARY_READY'})
    helper, core = _old(), _core()
    world, dirty = _editor_world(u, 'Reliquary')
    assert not dirty['maps'] and not dirty['content']
    assert _package_hashes() == report['current_map_sha256']
    _assert_maps_and_guards(core, report['current_map_sha256'], report['initial_614_guards'], report['collision_54'])
    current = _source_roster_state(u, helper, 'Reliquary', world)
    assert current == report['current_reliquary'], 'Reliquary changed since its phase receipt'
    donor_world = u.load_asset(MAPS['Belfry']['path'])
    assert donor_world and donor_world.get_path_name() == MAPS['Belfry']['path']
    old_actor, old_script = _find_actor(u, donor_world, P5)
    old_roster = helper._world_roster(u, donor_world)
    expected_saved = report['original_rosters']['Belfry']
    assert old_roster == expected_saved, 'Belfry donor no longer matches accepted original checkpoint'
    source_fields = helper._script_fields(old_script, P5)
    assert source_fields == report['p5_source']['fields']
    source_identity = helper._actor_identity_projection(helper._actor_row(old_actor, True))
    assert source_identity == helper._actor_identity_projection(report['p5_source']['actor'])
    edactors, selected = _selection(u)
    # Retain references only while this current source level is open.
    state.active = dict(phase='DUPLICATING', receipt=str(path), receipt_sha256=receipt_sha256,
                       current_world=world, donor_world=donor_world, old_actor=old_actor, old_script=old_script,
                       source_fields=source_fields, source_identity=source_identity, selected=selected,
                       p5_actor=None, p5_script=None)
    started = _write(dict(phase='RELIQUARY_DUPLICATE_STARTED', parent_receipt=path.relative_to(ROOT).as_posix(),
                          parent_receipt_sha256=receipt_sha256, disk_maps_before=report['current_map_sha256'],
                          world=world.get_path_name(), donor_actor=old_actor.get_path_name(),
                          selected_before=[x.get_path_name() for x in selected], map_save_performed=False))
    try:
        editor_actor_subsystem = u.get_editor_subsystem(u.EditorActorSubsystem)
        returned = editor_actor_subsystem.duplicate_actor(old_actor, world, u.Vector(0.0, 0.0, 0.0))
        all_now = _all_actors(u, world)
        before_paths = {r['path'] for r in report['current_reliquary']['all']}
        added = [a for a in all_now if a.get_path_name() not in before_paths]
        assert len(added) == 1, ('Expected exactly one actor addition from duplicate', [a.get_path_name() for a in added])
        clone = added[0]
        state.active['p5_actor'] = clone
        assert clone.get_class().get_name() == old_actor.get_class().get_name() == 'Ck_EntitySpawner_UE'
        assert clone.get_level().get_path_name() == MAPS['Reliquary']['path'] + ':PersistentLevel'
        assert clone.get_path_name().startswith(MAPS['Reliquary']['path'] + ':PersistentLevel.')
        assert clone != old_actor
        if returned:
            assert returned == clone, ('DuplicateActor return does not match independently observed addition',
                                       returned.get_path_name(), clone.get_path_name())
        if clone.get_actor_label() != P5['label']:
            clone.set_actor_label(P5['label'])
        assert clone.get_actor_label() == P5['label']
        clone_script = clone.get_editor_property('_EntityScript')
        state.active['p5_script'] = clone_script
        assert clone_script and clone_script != old_script and clone_script.get_outer() == clone
        assert old_script.get_outer() == old_actor
        assert clone_script.get_class().get_name() == P5['script_class']
        assert helper._script_fields(clone_script, P5) == source_fields, 'Cloned non-pose script properties changed'
        assert helper._actor_identity_projection(helper._actor_row(clone, True)) == source_identity, (
            'Clone differs in non-pose tags, components, injection, channel, attachment, or ownership')
        assert clone.get_owner() is None and clone.get_attach_parent_actor() is None
        assert clone.get_editor_property('_InjectActorTransformToScriptProperty').export_text() == \
            old_actor.get_editor_property('_InjectActorTransformToScriptProperty').export_text()
        target = _target_transform(u, P5)
        clone.modify()
        clone_script.modify()
        clone_script.set_editor_property('SpawnTransform', target)
        assert edactors.set_actor_transform(clone, target), 'Editor transform route rejected P5 clone pose'
        assert helper._script_fields(clone_script, P5) == dict(source_fields, SpawnTransform=helper._serial(target))
        _assert_transform(helper, clone, target)
        new_selection = list(edactors.get_selected_level_actors())
        assert clone in new_selection, 'Destination clone was not selected in current editor world'
        edactors.set_selected_level_actors(selected)
        assert [x.get_path_name() for x in edactors.get_selected_level_actors()] == [x.get_path_name() for x in selected], (
            'Editor selection was not restored exactly')
        after = _source_roster_state(u, helper, 'Reliquary', world)
        assert len(after['authored']) == 31
        added_rows = [row for row in after['authored'] if row['path'] not in {r['path'] for r in current['authored']}]
        assert len(added_rows) == 1 and added_rows[0]['label'] == P5['label']
        staged = _write(dict(phase='RELIQUARY_CLONE_UNSAVED', parent_receipt=path.relative_to(ROOT).as_posix(),
                             parent_receipt_sha256=receipt_sha256,
                             inherited=_inherit(report),
                             started_receipt=started.relative_to(ROOT).as_posix(), started_receipt_sha256=_sha(started),
                             current_map_sha256=report['current_map_sha256'], current_reliquary=after,
                             reliquary_before=current, original_rosters=report['original_rosters'],
                             p5_source=report['p5_source'], p1_source=report['p1_source'],
                             initial_614_guards=report['initial_614_guards'], collision_54=report['collision_54'],
                             p5_clone_path=clone.get_path_name(), p5_script_path=clone_script.get_path_name(),
                             p5_fields=helper._script_fields(clone_script, P5), p5_identity=source_identity,
                             p5_target_local=helper._serial(target), selected_before=[x.get_path_name() for x in selected],
                             selected_restored=[x.get_path_name() for x in edactors.get_selected_level_actors()],
                             dirty_after=_dirty(u), map_save_performed=False,
                             completion='INCOMPLETE: original Belfry source still exists; no PIE or gameplay validation is allowed.'))
        state.active.update(phase='RELIQUARY_CLONE_UNSAVED', staged_path=str(staged), staged_sha256=_sha(staged))
        return dict(status='RELIQUARY_CLONE_UNSAVED', receipt=staged.relative_to(ROOT).as_posix(),
                    sha256=_sha(staged), p5_actor=clone.get_path_name(), save_performed=False)
    except Exception as error:
        failure = _write_failure('RELIQUARY_DUPLICATE_FAILED', path.relative_to(ROOT).as_posix(), receipt_sha256,
                                  error, dict(started_receipt=started.relative_to(ROOT).as_posix(),
                                              started_receipt_sha256=_sha(started),
                                              current_dirty=_dirty(u),
                                              current_roster=_source_roster_state(u, helper, 'Reliquary', world)))
        raise RuntimeError('Duplicate phase failed; inspect the immutable failure receipt and restore all three maps before retrying: ' + str(failure)) from error


def save_reliquary_incomplete(receipt_path, receipt_sha256):
    """Next callback: audit and save only Reliquary; the game remains incomplete."""
    u = _u()
    state = _state()
    assert state.active and state.active['phase'] == 'RELIQUARY_CLONE_UNSAVED'
    path, report = _receipt(receipt_path, receipt_sha256, {'RELIQUARY_CLONE_UNSAVED'})
    helper, core = _old(), _core()
    world, dirty = _editor_world(u, 'Reliquary', allow_target_dirty=True)
    assert _package_hashes() == report['current_map_sha256']
    allowed_dirty = {MAPS['Reliquary']['package']}
    assert set(dirty['maps']) <= allowed_dirty and not dirty['content'], ('Unexpected dirty package', dirty)
    rows = _source_roster_state(u, helper, 'Reliquary', world)
    before = report['reliquary_before']
    p5 = state.active['p5_actor']
    script = state.active['p5_script']
    assert p5 and script and p5.get_path_name() == report['p5_clone_path']
    assert p5.get_level().get_path_name() == MAPS['Reliquary']['path'] + ':PersistentLevel'
    assert script.get_outer() == p5 and script.get_path_name() == report['p5_script_path']
    assert helper._script_fields(script, P5) == report['p5_fields']
    target = _target_transform(u, P5)
    _assert_transform(helper, p5, target)
    after_authored = rows['authored']
    old_paths = {r['path'] for r in before['authored']}
    added_rows = [r for r in after_authored if r['path'] not in old_paths]
    assert len(added_rows) == 1 and added_rows[0]['path'] == p5.get_path_name()
    assert added_rows[0]['label'] == P5['label']
    _authored_delta(report['reliquary_before']['authored'], after_authored,
                    added={_actor_key(added_rows[0])})
    assert rows['transient_classes'] == before['transient_classes']
    generated_delta = _validate_transient_delta(report['reliquary_before']['transient'], rows['transient'], 'add_p5')
    assert helper._actor_identity_projection(added_rows[0]) == report['p5_identity']
    assert _p5_channel_sources(u, {'Reliquary': world}) == [('Reliquary', p5.get_path_name(), P5['label'])]
    guards_before = _core_guards(core, report, _package_hashes())
    assert guards_before == report['initial_614_guards']
    dirty = _dirty(u)
    assert set(dirty['maps']) == allowed_dirty and not dirty['content'], ('Only Reliquary must be dirty', dirty)
    settings_class = u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    assert settings_class and hasattr(u.EditorLoadingAndSavingUtils, 'save_map')
    settings = u.get_default_object(settings_class)
    old_cook = settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    assert hasattr(type(old_cook), 'DISABLE')
    save_start = _write(dict(phase='RELIQUARY_SAVE_STARTED', parent_receipt=path.relative_to(ROOT).as_posix(),
                             parent_receipt_sha256=receipt_sha256, current_roster=rows, dirty_before=dirty,
                             auto_cook_before=helper._serial(old_cook), map_save_performed=False,
                             completion='Incomplete checkpoint only; no PIE allowed.'))
    try:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(old_cook).DISABLE)
        assert u.EditorLoadingAndSavingUtils.save_map(world, MAPS['Reliquary']['package']), 'Reliquary save failed'
    except Exception as error:
        fail = _write_failure('RELIQUARY_SAVE_FAILED', path.relative_to(ROOT).as_posix(), receipt_sha256,
                              error, dict(save_started=save_start.relative_to(ROOT).as_posix(),
                                          save_started_sha256=_sha(save_start)))
        raise RuntimeError('Do not PIE; restore all three map checkpoints: ' + str(fail)) from error
    finally:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', old_cook)
    assert settings.get_editor_property('_AutoCookStaticWorldOnLevelSave') == old_cook
    after_maps = _package_hashes()
    assert after_maps['Reliquary'] != report['current_map_sha256']['Reliquary']
    expected_maps = dict(report['current_map_sha256'], Reliquary=after_maps['Reliquary'])
    expected_guards = _allowed_guards(report['initial_614_guards'], expected_maps)
    guards_after = core._content_guards()
    assert guards_after == expected_guards, '614 protected files changed beyond Reliquary source map'
    collision_now = {rel: _sha(ROOT / rel) for rel in report['collision_54']}
    assert collision_now == report['collision_54']
    dirty_after = _dirty(u)
    assert not dirty_after['maps'] and not dirty_after['content']
    final = _write(dict(phase='RELIQUARY_SAVED_INCOMPLETE', parent_receipt=path.relative_to(ROOT).as_posix(),
                        parent_receipt_sha256=receipt_sha256, save_started=save_start.relative_to(ROOT).as_posix(),
                        inherited=_inherit(report),
                        save_started_sha256=_sha(save_start), previous_map_sha256=report['current_map_sha256'],
                        current_map_sha256=after_maps, current_roster=_source_roster_state(
                            u, helper, 'Reliquary', world, report['reliquary_before']['transient_classes']),
                        reliquary_final_authored=report['current_reliquary']['authored'],
                        initial_reliquary_authored=report['reliquary_before']['authored'],
                        generated_preview_delta=generated_delta,
                        original_rosters=report['original_rosters'], p5_source=report['p5_source'],
                        p1_source=report['p1_source'], initial_614_guards=report['initial_614_guards'],
                        expected_614_guards=expected_guards, collision_54=collision_now,
                        auto_cook_restored=True, dirty_after=dirty_after, map_save_performed=True,
                        completion='INCOMPLETE: P5 source still exists in Belfry. Keep PIE stopped until Belfry removal and Pit move are saved.'))
    state.active = None
    import gc
    gc.collect()
    return dict(status='RELIQUARY_SAVED_INCOMPLETE', receipt=final.relative_to(ROOT).as_posix(),
                sha256=_sha(final), map_sha256=after_maps['Reliquary'], saved=['Reliquary'],
                next='Release editor references, open Belfry source as current editor world, then call prepare_belfry_removal.')


def _core_guards(core, report, maps):
    expected = _allowed_guards(report['initial_614_guards'], maps)
    actual = core._content_guards()
    assert actual == expected, '614-file protected roster differs from approved map hash chain'
    return actual


def _p5_channel_sources(u, current_worlds=None):
    if current_worlds is None:
        _, current_worlds, _ = _main_instance_worlds(u)
    matches = []
    helper = _old()
    for tile, world in current_worlds.items():
        for actor in _all_actors(u, world):
            try:
                script = actor.get_editor_property('_EntityScript')
            except Exception:
                continue
            if not script or script.get_class().get_name() != P5['script_class']:
                continue
            fields = helper._script_fields(script, P5)
            if P5['channel'] in json.dumps(fields, sort_keys=True):
                matches.append((tile, actor.get_path_name(), actor.get_actor_label()))
    return sorted(matches)


def prepare_belfry_removal(receipt_path, receipt_sha256):
    """After loading Belfry current, reacquire and verify original source before deletion."""
    u = _u()
    state = _state()
    assert state.active is None
    path, report = _receipt(receipt_path, receipt_sha256, {'RELIQUARY_SAVED_INCOMPLETE'})
    helper, core = _old(), _core()
    world, dirty = _editor_world(u, 'Belfry')
    assert not dirty['maps'] and not dirty['content']
    assert _package_hashes() == report['current_map_sha256']
    _core_guards(core, report, report['current_map_sha256'])
    donor, script = _find_actor(u, world, P5)
    original = report['original_rosters']['Belfry']
    current = _source_roster_state(u, helper, 'Belfry', world)
    assert current['authored'] == original
    worlds = _loaded_source_worlds(u)
    rel_clone_rows = [row for row in report['current_roster']['authored'] if row['label'] == P5['label']]
    assert len(rel_clone_rows) == 1
    expected_sources = sorted([('Belfry', donor.get_path_name(), P5['label']),
                               ('Reliquary', rel_clone_rows[0]['path'], P5['label'])])
    assert _p5_channel_sources(u, worlds) == expected_sources
    source_before = report['p5_source']
    assert helper._actor_row(donor, True) == source_before['actor']
    assert helper._script_fields(script, P5) == source_before['fields']
    record = _write(dict(phase='BELFRY_REMOVE_READY', parent_receipt=path.relative_to(ROOT).as_posix(),
                         parent_receipt_sha256=receipt_sha256, maps_before=report['current_map_sha256'],
                         inherited=_inherit(report),
                         current_roster=current, dirty_before=dirty, p5_source_path=donor.get_path_name(),
                         p5_source_script=script.get_path_name(), p5_source_actor=helper._actor_row(donor, True),
                         p5_source_fields=helper._script_fields(script, P5),
                         original_rosters=report['original_rosters'], p5_source=report['p5_source'],
                         p1_source=report['p1_source'], reliquary_final_authored=report['reliquary_final_authored'],
                         initial_614_guards=report['initial_614_guards'], collision_54=report['collision_54'],
                         map_save_performed=False))
    return dict(status='BELFRY_REMOVE_READY', receipt=record.relative_to(ROOT).as_posix(), sha256=_sha(record))


def remove_p5_from_belfry(receipt_path, receipt_sha256):
    """Current-world deletion only; do not save until the next callback audit."""
    u = _u()
    state = _state()
    assert state.active is None
    path, report = _receipt(receipt_path, receipt_sha256, {'BELFRY_REMOVE_READY'})
    helper, core = _old(), _core()
    world, dirty = _editor_world(u, 'Belfry')
    assert not dirty['maps'] and not dirty['content']
    assert _package_hashes() == report['maps_before']
    _core_guards(core, dict(initial_614_guards=report['initial_614_guards']), report['maps_before'])
    actor, script = _find_actor(u, world, P5)
    assert actor.get_path_name() == report['p5_source_path'] and script.get_path_name() == report['p5_source_script']
    assert helper._actor_row(actor, True) == report['p5_source_actor']
    state.active = dict(phase='BELFRY_REMOVING', actor=actor, script=script,
                        world=world, pre_rows=report['current_roster'])
    try:
        ok = u.get_editor_subsystem(u.EditorActorSubsystem).destroy_actor(actor)
        assert ok, 'Public current-editor-world DestroyActor rejected original P5'
        assert not u.SystemLibrary.is_valid(actor), 'P5 actor still valid immediately after deletion'
        started = _write(dict(phase='BELFRY_REMOVE_APPLIED_UNSAVED', parent_receipt=path.relative_to(ROOT).as_posix(),
                              parent_receipt_sha256=receipt_sha256, removed_actor=report['p5_source_path'],
                              inherited=_inherit(report),
                              maps_before=report['maps_before'], current_roster=report['current_roster'],
                              original_rosters=report['original_rosters'], p5_source=report['p5_source'],
                              p1_source=report['p1_source'], initial_614_guards=report['initial_614_guards'],
                              reliquary_final_authored=report['reliquary_final_authored'],
                              collision_54=report['collision_54'],
                              map_save_performed=False, completion='Await next callback roster audit before save.'))
        state.active.update(phase='BELFRY_REMOVE_APPLIED_UNSAVED', started_path=str(started), started_sha256=_sha(started))
        return dict(status='BELFRY_REMOVE_APPLIED_UNSAVED', receipt=started.relative_to(ROOT).as_posix(),
                    sha256=_sha(started), save_performed=False)
    except Exception as error:
        fail = _write_failure('BELFRY_REMOVE_FAILED', path.relative_to(ROOT).as_posix(), receipt_sha256,
                              error, dict(current_dirty=_dirty(u), current_roster=_source_roster_state(u, helper, 'Belfry', world)))
        raise RuntimeError('Stop; do not retry. Restore three original maps if mutation occurred: ' + str(fail)) from error


def save_belfry_removed(receipt_path, receipt_sha256):
    u = _u()
    state = _state()
    assert state.active and state.active['phase'] == 'BELFRY_REMOVE_APPLIED_UNSAVED'
    path, report = _receipt(receipt_path, receipt_sha256, {'BELFRY_REMOVE_APPLIED_UNSAVED'})
    helper, core = _old(), _core()
    world, dirty = _editor_world(u, 'Belfry', allow_target_dirty=True)
    assert _package_hashes() == report['maps_before']
    before = report['current_roster']
    current = _source_roster_state(u, helper, 'Belfry', world)
    target_rows = [r for r in before['authored'] if r['path'] == report['removed_actor']]
    assert len(target_rows) == 1 and target_rows[0]['label'] == P5['label']
    expected = [r for r in before['authored'] if r['path'] != report['removed_actor']]
    assert current['authored'] == expected and current['transient_classes'] == before['transient_classes']
    generated_delta = _validate_transient_delta(before['transient'], current['transient'], 'remove_p5',
                                                p5_before_pose=report['p5_source']['actor']['pose'])
    _authored_delta(before['authored'], current['authored'], removed={_actor_key(target_rows[0])})
    assert set(dirty['maps']) == {MAPS['Belfry']['package']} and not dirty['content']
    save_start = _write(dict(phase='BELFRY_SAVE_STARTED', parent_receipt=path.relative_to(ROOT).as_posix(),
                             parent_receipt_sha256=receipt_sha256, roster=current, dirty_before=dirty,
                             map_save_performed=False))
    _save_current_map(u, world, 'Belfry', path, receipt_sha256, save_start)
    after_maps = _package_hashes()
    expected_maps = dict(report['maps_before'], Belfry=after_maps['Belfry'])
    guards = _core_guards(core, dict(initial_614_guards=report['initial_614_guards']), expected_maps)
    collision = _collision_current(report['collision_54'])
    dirty_after = _dirty(u)
    assert not dirty_after['maps'] and not dirty_after['content']
    final = _write(dict(phase='BELFRY_SAVED_INCOMPLETE', parent_receipt=path.relative_to(ROOT).as_posix(),
                        parent_receipt_sha256=receipt_sha256, save_started=save_start.relative_to(ROOT).as_posix(),
                        inherited=_inherit(report),
                        save_started_sha256=_sha(save_start), previous_map_sha256=report['maps_before'],
                        current_map_sha256=after_maps, current_roster=current,
                        belfry_final_authored=current['authored'], generated_preview_delta=generated_delta,
                        reliquary_final_authored=report['reliquary_final_authored'],
                        original_rosters=report['original_rosters'], p5_source=report['p5_source'],
                        p1_source=report['p1_source'], initial_614_guards=report['initial_614_guards'],
                        expected_614_guards=guards,
                        collision_54=collision, dirty_after=dirty_after, auto_cook_restored=True,
                        map_save_performed=True,
                        completion='INCOMPLETE: P1 lock remains unmoved; do not run PIE.'))
    state.active = None
    import gc
    gc.collect()
    return dict(status='BELFRY_SAVED_INCOMPLETE', receipt=final.relative_to(ROOT).as_posix(),
                sha256=_sha(final), map_sha256=after_maps['Belfry'], saved=['Belfry'],
                next='Release references, open Pit current, then call prepare_pit_move.')


def prepare_pit_move(receipt_path, receipt_sha256):
    u = _u()
    state = _state()
    assert state.active is None
    path, report = _receipt(receipt_path, receipt_sha256, {'BELFRY_SAVED_INCOMPLETE'})
    helper, core = _old(), _core()
    world, dirty = _editor_world(u, 'Pit')
    assert not dirty['maps'] and not dirty['content']
    assert _package_hashes() == report['current_map_sha256']
    _core_guards(core, dict(initial_614_guards=report['expected_614_guards']), report['current_map_sha256'])
    actor, script = _find_actor(u, world, P1)
    assert helper._actor_row(actor, True) == report['original_rosters']['Pit'][
        next(i for i, r in enumerate(report['original_rosters']['Pit']) if r['label'] == P1['label'])]
    current = _source_roster_state(u, helper, 'Pit', world)
    assert current['authored'] == report['original_rosters']['Pit']
    assert helper._script_fields(script, P1) == report['p1_source']['fields']
    channel_worlds = _loaded_source_worlds(u)
    rel_clone_rows = [row for row in _source_roster_state(u, helper, 'Reliquary', channel_worlds['Reliquary'])['authored']
                      if row['label'] == P5['label']]
    assert len(rel_clone_rows) == 1
    assert _p5_channel_sources(u, channel_worlds) == [('Reliquary', rel_clone_rows[0]['path'], P5['label'])]
    ready = _write(dict(phase='PIT_MOVE_READY', parent_receipt=path.relative_to(ROOT).as_posix(),
                        parent_receipt_sha256=receipt_sha256, maps_before=report['current_map_sha256'],
                        inherited=_inherit(report),
                        current_roster=current, p1_source_path=actor.get_path_name(),
                        p1_source_script=script.get_path_name(), p1_source_actor=helper._actor_row(actor, True),
                        p1_source_fields=helper._script_fields(script, P1),
                        initial_614_guards=report['initial_614_guards'],
                        expected_614_guards=report['expected_614_guards'], collision_54=report['collision_54'],
                        original_rosters=report['original_rosters'], p5_source=report['p5_source'],
                        p1_source=report['p1_source'], belfry_final_authored=report['belfry_final_authored'],
                        reliquary_final_authored=report['reliquary_final_authored'],
                        map_save_performed=False))
    return dict(status='PIT_MOVE_READY', receipt=ready.relative_to(ROOT).as_posix(), sha256=_sha(ready))


def move_p1_in_pit(receipt_path, receipt_sha256):
    u = _u()
    state = _state()
    assert state.active is None
    path, report = _receipt(receipt_path, receipt_sha256, {'PIT_MOVE_READY'})
    helper, core = _old(), _core()
    world, dirty = _editor_world(u, 'Pit')
    assert not dirty['maps'] and not dirty['content']
    assert _package_hashes() == report['maps_before']
    _core_guards(core, dict(initial_614_guards=report['initial_614_guards']), report['maps_before'])
    actor, script = _find_actor(u, world, P1)
    assert actor.get_path_name() == report['p1_source_path'] and script.get_path_name() == report['p1_source_script']
    assert helper._actor_row(actor, True) == report['p1_source_actor']
    state.active = dict(phase='PIT_MOVE_STARTED', actor=actor, script=script, world=world)
    try:
        target = _target_transform(u, P1)
        actor.modify()
        script.modify()
        script.set_editor_property('SpawnTransform', target)
        assert u.get_editor_subsystem(u.EditorActorSubsystem).set_actor_transform(actor, target), (
            'Editor transform route rejected P1 lock pose')
        assert helper._script_fields(script, P1) == dict(report['p1_source_fields'], SpawnTransform=helper._serial(target))
        _assert_transform(helper, actor, target)
        applied = _write(dict(phase='PIT_MOVE_UNSAVED', parent_receipt=path.relative_to(ROOT).as_posix(),
                              parent_receipt_sha256=receipt_sha256, p1_source_path=actor.get_path_name(),
                              inherited=_inherit(report),
                              p1_source_script=script.get_path_name(), p1_target=helper._serial(target),
                              maps_before=report['maps_before'],
                              current_roster=_source_roster_state(u, helper, 'Pit', world,
                                  report['current_roster']['transient_classes']),
                              p1_source_actor=report['p1_source_actor'], p1_source_fields=report['p1_source_fields'],
                              initial_pit_roster=report['current_roster'], original_rosters=report['original_rosters'],
                              p5_source=report['p5_source'], p1_source=report['p1_source'],
                              belfry_final_authored=report['belfry_final_authored'],
                              reliquary_final_authored=report['reliquary_final_authored'],
                              initial_614_guards=report['initial_614_guards'], collision_54=report['collision_54'],
                              dirty_after=_dirty(u), map_save_performed=False,
                              completion='Await next callback audit before save.'))
        state.active.update(phase='PIT_MOVE_UNSAVED', staged_path=str(applied), staged_sha256=_sha(applied))
        return dict(status='PIT_MOVE_UNSAVED', receipt=applied.relative_to(ROOT).as_posix(), sha256=_sha(applied),
                    save_performed=False)
    except Exception as error:
        fail = _write_failure('PIT_MOVE_FAILED', path.relative_to(ROOT).as_posix(), receipt_sha256,
                              error, dict(current_dirty=_dirty(u), current_roster=_source_roster_state(u, helper, 'Pit', world)))
        raise RuntimeError('Stop; do not retry. Restore all three original maps if mutation occurred: ' + str(fail)) from error


def save_pit_moved(receipt_path, receipt_sha256):
    u = _u()
    state = _state()
    assert state.active and state.active['phase'] == 'PIT_MOVE_UNSAVED'
    path, report = _receipt(receipt_path, receipt_sha256, {'PIT_MOVE_UNSAVED'})
    helper, core = _old(), _core()
    world, dirty = _editor_world(u, 'Pit', allow_target_dirty=True)
    assert _package_hashes() == report['maps_before']
    actor, script = _find_actor(u, world, P1)
    assert actor.get_path_name() == report['p1_source_path'] and script.get_path_name() == report['p1_source_script']
    target = _target_transform(u, P1)
    _assert_transform(helper, actor, target)
    assert helper._script_fields(script, P1) == dict(report['p1_source_fields'], SpawnTransform=report['p1_target'])
    current = _source_roster_state(u, helper, 'Pit', world)
    before = report['current_roster']
    authored_before = report['initial_pit_roster']['authored']
    p1_key = (report['p1_source_actor']['path'], report['p1_source_actor']['label'],
              report['p1_source_actor']['cls'])
    _authored_delta(authored_before, current['authored'], modified={p1_key})
    p1_row = next(row for row in current['authored'] if row['path'] == report['p1_source_path'])
    assert helper._actor_identity_projection(p1_row) == helper._actor_identity_projection(report['p1_source_actor'])
    assert current['authored'] == report['current_roster']['authored']
    assert current['transient_classes'] == report['current_roster']['transient_classes']
    generated_delta = _validate_transient_delta(report['initial_pit_roster']['transient'],
                                                current['transient'], 'move_p1',
                                                report['p1_source_actor']['pose'])
    assert set(dirty['maps']) == {MAPS['Pit']['package']} and not dirty['content']
    save_start = _write(dict(phase='PIT_SAVE_STARTED', parent_receipt=path.relative_to(ROOT).as_posix(),
                             parent_receipt_sha256=receipt_sha256, roster=current, dirty_before=dirty,
                             map_save_performed=False))
    _save_current_map(u, world, 'Pit', path, receipt_sha256, save_start)
    after_maps = _package_hashes()
    expected_maps = dict(report['maps_before'], Pit=after_maps['Pit'])
    guards = _core_guards(core, dict(initial_614_guards=report['initial_614_guards']), expected_maps)
    collision = _collision_current(report['collision_54'])
    dirty_after = _dirty(u)
    assert not dirty_after['maps'] and not dirty_after['content']
    final = _write(dict(phase='ALL_SOURCES_SAVED_REOPEN_REQUIRED', parent_receipt=path.relative_to(ROOT).as_posix(),
                        parent_receipt_sha256=receipt_sha256, save_started=save_start.relative_to(ROOT).as_posix(),
                        inherited=_inherit(report),
                        save_started_sha256=_sha(save_start), previous_map_sha256=report['maps_before'],
                        current_map_sha256=after_maps, current_roster=current,
                        pit_final_authored=current['authored'], generated_preview_delta=generated_delta,
                        belfry_final_authored=report['belfry_final_authored'],
                        reliquary_final_authored=report['reliquary_final_authored'],
                        original_rosters=report['original_rosters'], p5_source=report['p5_source'],
                        p1_source=report['p1_source'], initial_614_guards=report['initial_614_guards'],
                        expected_614_guards=guards,
                        collision_54=collision, dirty_after=dirty_after, auto_cook_restored=True,
                        map_save_performed=True,
                        completion='Saved sources only. Reopen Main and read-only verify all three loaded source worlds before PIE.'))
    state.active = None
    import gc
    gc.collect()
    return dict(status='ALL_SOURCES_SAVED_REOPEN_REQUIRED', receipt=final.relative_to(ROOT).as_posix(),
                sha256=_sha(final), current_map_sha256=after_maps, saved=['Pit'],
                next='Release references and open Main fresh; call verify_main_sources.')


def _save_current_map(u, world, tile, parent_path, parent_sha, save_start):
    settings_class = u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    assert settings_class
    settings = u.get_default_object(settings_class)
    old_cook = settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    assert hasattr(type(old_cook), 'DISABLE')
    try:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(old_cook).DISABLE)
        assert u.EditorLoadingAndSavingUtils.save_map(world, MAPS[tile]['package']), (tile, 'source-map save failed')
    except Exception as error:
        fail = _write_failure(tile.upper() + '_SAVE_FAILED', parent_path, parent_sha, error,
                              dict(save_started=save_start.relative_to(ROOT).as_posix(), save_started_sha256=_sha(save_start)))
        raise RuntimeError('Do not continue or PIE; restore all three checkpoints: ' + str(fail)) from error
    finally:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', old_cook)
    assert settings.get_editor_property('_AutoCookStaticWorldOnLevelSave') == old_cook


def _collision_current(expected):
    current = {rel: _sha(ROOT / rel) for rel in expected}
    assert current == expected
    return current


def _loaded_source_worlds(u):
    worlds = {tile: u.load_asset(spec['path']) for tile, spec in MAPS.items()}
    assert all(world and world.get_path_name() == MAPS[tile]['path'] for tile, world in worlds.items())
    return worlds


def verify_main_sources(receipt_path, receipt_sha256):
    """Final read-only check after reopening assembled Main; still no PIE claim."""
    u = _u()
    state = _state()
    assert state.active is None, 'Release source UObject references before loading Main'
    path, report = _receipt(receipt_path, receipt_sha256, {'ALL_SOURCES_SAVED_REOPEN_REQUIRED'})
    helper, core = _old(), _core()
    main, worlds, instances = _main_instance_worlds(u)
    dirty = _dirty(u)
    assert not dirty['maps'] and not dirty['content']
    assert _package_hashes() == report['current_map_sha256']
    _assert_maps_and_guards(core, report['current_map_sha256'], report['expected_614_guards'], report['collision_54'])
    all_rows = {tile: _source_roster_state(u, helper, tile, worlds[tile]) for tile in MAPS}
    belfry = all_rows['Belfry']
    reliquary = all_rows['Reliquary']
    pit = all_rows['Pit']
    expected_authored = dict(Belfry=report['belfry_final_authored'],
                             Reliquary=report['reliquary_final_authored'],
                             Pit=report['pit_final_authored'])
    for tile in MAPS:
        assert all_rows[tile]['authored'] == expected_authored[tile], (
            'Reopened authored roster differs from saved phase audit', tile)
    assert len([r for r in belfry['authored'] if r['label'] == P5['label']]) == 0
    assert len([r for r in reliquary['authored'] if r['label'] == P5['label']]) == 1
    p5_actor, p5_script = _find_actor(u, worlds['Reliquary'], P5)
    p1_actor, p1_script = _find_actor(u, worlds['Pit'], P1)
    p5_target = _target_transform(u, P5)
    p1_target = _target_transform(u, P1)
    _assert_transform(helper, p5_actor, p5_target)
    _assert_transform(helper, p1_actor, p1_target)
    p5_fields = helper._script_fields(p5_script, P5)
    p1_fields = helper._script_fields(p1_script, P1)
    assert p5_fields == dict(report['p5_source']['fields'], SpawnTransform=helper._serial(p5_target))
    assert p1_fields == dict(report['p1_source']['fields'], SpawnTransform=helper._serial(p1_target))
    assert p5_script.get_outer() == p5_actor and p1_script.get_outer() == p1_actor
    source_matches = _p5_channel_sources(u, worlds)
    assert source_matches == [('Reliquary', p5_actor.get_path_name(), P5['label'])]
    p5_assembled = u.MathLibrary.compose_transforms(p5_actor.get_actor_transform(),
                                                     instances['Reliquary'].get_actor_transform())
    p1_assembled = u.MathLibrary.compose_transforms(p1_actor.get_actor_transform(),
                                                     instances['Pit'].get_actor_transform())
    p5_assembled_row = helper._serial(p5_assembled)
    p1_assembled_row = helper._serial(p1_assembled)
    assert all(abs(a-b) <= 0.02 for a, b in zip(p5_assembled.translation.to_tuple(), P5['assembled']))
    assert all(abs(a-b) <= 0.02 for a, b in zip(p1_assembled.translation.to_tuple(), P1['assembled']))
    final = _write(dict(phase='MAIN_REOPEN_VERIFIED', parent_receipt=path.relative_to(ROOT).as_posix(),
                        parent_receipt_sha256=receipt_sha256, main_world=main.get_path_name(),
                        source_worlds={tile: worlds[tile].get_path_name() for tile in MAPS},
                        maps=report['current_map_sha256'], expected_614_guards=report['expected_614_guards'],
                        collision_54=report['collision_54'], source_rosters=all_rows,
                        p5_channel_sources=source_matches,
                        targets=dict(P5=dict(actor=p5_actor.get_path_name(), local=helper._serial(p5_target),
                                             assembled=p5_assembled_row),
                                     P1=dict(actor=p1_actor.get_path_name(), local=helper._serial(p1_target),
                                             assembled=p1_assembled_row)),
                        dirty=dirty, map_save_performed=False,
                        runtime_claim='Source assets reopened and transforms/rosters verified only; no PIE or live input evidence.'))
    return dict(status='MAIN_REOPEN_VERIFIED', receipt=final.relative_to(ROOT).as_posix(), sha256=_sha(final),
                p5=p5_actor.get_path_name(), p1=p1_actor.get_path_name(), p5_sources=len(source_matches),
                runtime_verified=False)
