"""Checkpointed C-only P1/P5 source-level staging helper.

Import is inert. In a clean assembled Variant C editor world call
prepare(), apply_staged(receipt, sha), then verify_and_save(receipt, sha)
from separate editor callbacks. The apply phase never saves: P5 clone callbacks
must settle before the next-frame audit. On failure, close the editor and restore
all three saved map checkpoints as one unit before reopening.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import shutil
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
APPROVAL = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/mechanism-layout-preview/r01/ASTRA_REVIEW.md'
APPROVAL_SHA256 = '4a203ccee764f35f10e5eeafffa8ad5ca059aa86039eaf4fa7b596562c4c56df'
PREVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/mechanism-layout-preview/r01/receipt_20261025T081555_b8f5e016.json'
PREVIEW_SHA256 = 'b128711935ac8dce5988d512cc6b3e0e6aceabf5970e05633e113d230cf22b01'
TRANSFER_REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/P5_OWNERSHIP_TRANSFER_REVIEW.md'
TRANSFER_REVIEW_SHA256 = '08c018d126dcd000ca3d89c17d80d70b7375ca3f05981f0b278fbb4e934ed8e7'
FIT = RUN / 'P1P5MechanismFit/receipt.corrected.json'
FIT_SHA256 = 'ebc3ef56c09eb0126fa35707c8b2f4a231aeb61a8df776a6debccdd2be6ea546'
FIT_INSTANCES = HERE / 'Output/fitted_instances.json'
FIT_INSTANCES_SHA256 = '67f8e8d87ab166ab7fd0cd5e285a08e02b8643c856de3bf028130271021b9d34'
COLLISION_HASHES = RUN / 'StartupCheckpoint/collision_hashes.json'
EXPECTED_EDITOR_WORLD = '/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'
MAPS = {
    'Belfry': dict(package='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Belfry',
                   path='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Belfry.LI_Warrens_Belfry',
                   sha256='cbdcbc49774b21ff706b5883d39c9a8377ac2fc85c2ee7c9f49e65966fd32c21',
                   label='Warrens_LI_Belfry', origin=[1400.0, -1700.0, 0.0]),
    'Reliquary': dict(package='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Reliquary',
                      path='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Reliquary.LI_Warrens_Reliquary',
                      sha256='a479d5b40f3c39209248149011e9be84d8f1c265308923397eacc622d3ec663c',
                      label='Warrens_LI_Reliquary', origin=[1000.0, 1100.0, 250.0]),
    'Pit': dict(package='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Pit',
                path='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Pit.LI_Warrens_Pit',
                sha256='9d85466d625ec46cbcbd840d28209b147c11e20e878860df440e01f2ae499afd',
                label='Warrens_LI_Pit', origin=[-5400.0, -3300.0, -500.0]),
}
P5 = dict(label='Warrens_Mars_Lever_EntityScript_3', actor_name='Ck_EntitySpawner_UE_2',
          script_class='Mars_Lever_EntityScript', channel='Mechanism.Channel.Warrens.Puzzle.P5',
          fields=('SpawnTransform', 'Control', 'Source', 'PulledAngle', 'MoveDuration', 'PromptText'),
          source='Belfry', destination='Reliquary', plan=[93.0, 73.5, 2.503], yaw=0.0)
P1 = dict(label='Warrens_Mars_Sandbox_KeyLock_Red_EntityScript_5', actor_name='Ck_EntitySpawner_UE_2',
          script_class='Mars_Sandbox_KeyLock_Red_EntityScript',
          fields=('SpawnTransform', 'AcceptedKey', 'Release', 'Source'),
          source='Pit', destination='Pit', plan=[56.5, 58.512, -4.0], pitch=-90.0, yaw=90.0)
STATE_MODULE = '_mars_warrensc_mechanism_layout_apply_state'


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _write_unique(record):
    CHECKPOINT.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '_' + uuid.uuid4().hex[:8]
    path = CHECKPOINT / ('mechanism_layout_' + stamp + '.json')
    assert not path.exists(), 'Refuse to overwrite a staging receipt'
    record.update(schema=1, created_utc=datetime.now(timezone.utc).isoformat(), tool_sha256=_sha(__file__))
    path.write_text(json.dumps(record, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    return path


def _u():
    import unreal
    return unreal


def _core():
    assert _sha(CORE_PATH) == CORE_SHA256, 'Frozen combined guard helper changed'
    name = '_mars_warrensc_mechanism_layout_guard_core'
    module = sys.modules.get(name)
    if module is None:
        spec = importlib.util.spec_from_file_location(name, CORE_PATH)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules[name] = module
    return module


def _package_hashes():
    result = {}
    for tile, row in MAPS.items():
        path = ROOT / ('Content/' + row['package'].removeprefix('/Game/') + '.umap')
        assert path.is_file(), ('Missing target map', tile, str(path))
        result[tile] = _sha(path)
    return result


def _guard_inputs(core):
    assert _sha(APPROVAL) == APPROVAL_SHA256 and _sha(PREVIEW) == PREVIEW_SHA256
    assert _sha(TRANSFER_REVIEW) == TRANSFER_REVIEW_SHA256 and _sha(FIT) == FIT_SHA256
    fit = _json(FIT)
    assert fit.get('p1', {}).get('candidate_mount') == [56.5, 58.512, -4.0]
    assert fit.get('p5', {}).get('proposed_lever_root') == [93.0, 73.5, 2.503]
    verifier = core._promotion_chain()
    assert _sha(FIT_INSTANCES) == FIT_INSTANCES_SHA256, 'Fitted placement ledger changed'
    placements = _json(FIT_INSTANCES)
    pivots = {tile: placements['pivots'][tile] for tile in ('Belfry', 'Reliquary', 'Pit')}
    assert pivots == {'Belfry': [84, 38, 0], 'Reliquary': [80, 66, 2.5], 'Pit': [16, 22, -5]}
    files = core._content_guards()
    assert len(files) == 614, ('Expected full retained-art roster', len(files))
    collision = _json(COLLISION_HASHES)
    assert len(collision) == 54
    current_collision = {rel: _sha(ROOT / rel) for rel in collision}
    assert current_collision == collision, 'One or more of the 54 protected collision files changed'
    return dict(approval_sha256=APPROVAL_SHA256, preview_sha256=PREVIEW_SHA256,
                ownership_review_sha256=TRANSFER_REVIEW_SHA256, fit_sha256=FIT_SHA256,
                fitted_instances_sha256=FIT_INSTANCES_SHA256, fit_pivots=pivots,
                current_library_verifier=verifier, protected_614=files,
                collision_54=current_collision)


def _editor_context(u, require_clean=True):
    ed = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    world = ed.get_editor_world()
    assert world and world.get_path_name().split('.')[0] == EXPECTED_EDITOR_WORLD, 'Expected assembled Variant C editor map'
    assert ed.get_game_world() is None, 'Stop PIE before mechanism staging'
    dirty = _dirty_names(u)
    if require_clean:
        assert not dirty['maps'] and not dirty['content'], ('Editor packages must be clean', dirty)
    return world, dirty


def _dirty_names(u):
    def package_name(value):
        if hasattr(value, 'get_path_name'):
            return value.get_path_name().split('.')[0]
        return str(value).split('.')[0]
    return dict(maps=sorted(package_name(x) for x in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()),
                content=sorted(package_name(x) for x in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()))


def _instances(u, main_world):
    actors = u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
    result = {}
    for tile, spec in MAPS.items():
        found = [a for a in actors if a.get_actor_label() == spec['label']]
        assert len(found) == 1 and found[0].get_class().get_name() == 'LevelInstance', (tile, [a.get_path_name() for a in found])
        asset = found[0].get_editor_property('world_asset')
        assert asset and asset.get_path_name() == spec['path'], (tile, asset.get_path_name() if asset else None)
        assert asset.get_path_name().split('.')[0] == spec['package']
        source_world = asset
        assert source_world.get_path_name().split('.')[0] == spec['package']
        result[tile] = dict(instance=found[0], world=source_world,
                            instance_transform=found[0].get_actor_transform())
        actual_translation = list(found[0].get_actor_transform().translation.to_tuple())
        assert all(abs(actual_translation[i] - spec['origin'][i]) < 0.01 for i in range(3)), (
            'LevelInstance transform changed', tile, actual_translation, spec['origin'])
    return result


def _source_actor(u, world, spec):
    rows = [a for a in u.GameplayStatics.get_all_actors_of_class(world, u.Actor)
            if a.get_actor_label() == spec['label']]
    assert len(rows) == 1, ('Expected exactly one authored mechanism', spec['label'], [a.get_path_name() for a in rows])
    actor = rows[0]
    assert actor.get_name() == spec['actor_name'] and actor.get_class().get_name() == 'Ck_EntitySpawner_UE'
    script = actor.get_editor_property('_EntityScript')
    assert script and script.get_class().get_name() == spec['script_class']
    assert script.get_outer() == actor, ('EntityScript Outer mismatch', actor.get_path_name(), script.get_path_name())
    return actor, script


def _persistent_level(u, source_world):
    levels = {actor.get_level().get_path_name(): actor.get_level()
              for actor in u.GameplayStatics.get_all_actors_of_class(source_world, u.Actor)}
    assert len(levels) == 1, ('Expected one existing persistent source level', source_world.get_path_name(), sorted(levels))
    level = next(iter(levels.values()))
    assert level.get_path_name() == source_world.get_path_name() + ':PersistentLevel'
    return level


def _p5_channel_sources(u, instances):
    matches = []
    for tile in ('Belfry', 'Reliquary', 'Pit'):
        actors = u.GameplayStatics.get_all_actors_of_class(instances[tile]['world'], u.Actor)
        for actor in actors:
            try:
                script = actor.get_editor_property('_EntityScript')
            except Exception:
                continue
            if not script or script.get_class().get_name() != P5['script_class']:
                continue
            source = _serial(script.get_editor_property('Source'))
            if 'Mechanism.Channel.Warrens.Puzzle.P5' in str(source):
                matches.append(actor.get_path_name())
    return sorted(matches)


def _serial(value):
    u = _u()
    if value is None or isinstance(value, (str, bool, int, float)):
        return value
    if hasattr(value, 'get_path_name'):
        return value.get_path_name()
    if isinstance(value, u.Transform):
        return dict(location=list(value.translation.to_tuple()), rotation_xyzw=list(value.rotation.to_tuple()),
                    scale=list(value.scale3d.to_tuple()))
    if isinstance(value, (list, tuple)):
        return [_serial(item) for item in value]
    if hasattr(value, 'export_text'):
        return value.export_text()
    return str(value)


def _pose(actor):
    return dict(location=list(actor.get_actor_location().to_tuple()), rotation=list(actor.get_actor_rotation().to_tuple()),
                scale=list(actor.get_actor_scale3d().to_tuple()))


def _assert_actor_transform(actor, expected):
    actual = actor.get_actor_transform()
    assert all(abs(a-b) < 0.01 for a, b in zip(actual.translation.to_tuple(), expected.translation.to_tuple())), (
        'Spawner actor transform location differs from injected script pose', actor.get_path_name())
    assert all(abs(a-b) < 1e-5 for a, b in zip(actual.scale3d.to_tuple(), expected.scale3d.to_tuple()))
    actual_rot = actual.rotation.rotator()
    expected_rot = expected.rotation.rotator()
    assert all(abs(a-b) < 1e-4 for a, b in zip((actual_rot.pitch, actual_rot.yaw, actual_rot.roll),
                                               (expected_rot.pitch, expected_rot.yaw, expected_rot.roll)))


def _components(actor):
    u = _u()
    rows = []
    for comp in actor.get_components_by_class(u.ActorComponent):
        row = dict(name=comp.get_name(), class_name=comp.get_class().get_name())
        if isinstance(comp, u.SceneComponent):
            row['world_transform'] = _serial(comp.get_world_transform())
            row['relative_transform'] = _serial(comp.get_relative_transform())
        if isinstance(comp, u.StaticMeshComponent):
            row['mesh'] = _serial(comp.static_mesh)
            row['materials'] = [_serial(m) for m in comp.get_materials()]
            row['collision_profile'] = str(comp.get_collision_profile_name())
            row['collision'] = str(comp.get_collision_enabled())
            row['overlap'] = bool(comp.get_editor_property('generate_overlap_events'))
            row['visible'] = bool(comp.is_visible())
            row['shadow'] = bool(comp.cast_shadow)
            row['mobility'] = str(comp.get_editor_property('mobility'))
        if isinstance(comp, u.LightComponent):
            c = comp.light_color
            row['light'] = dict(intensity=float(comp.intensity), color=[c.r, c.g, c.b, c.a],
                                radius=float(comp.attenuation_radius) if hasattr(comp, 'attenuation_radius') else None,
                                shadows=bool(comp.cast_shadows), world_transform=_serial(comp.get_world_transform()))
        if isinstance(comp, u.CameraComponent):
            row['camera'] = dict(fov=float(comp.field_of_view), world_transform=_serial(comp.get_world_transform()))
        if isinstance(comp, u.HierarchicalInstancedStaticMeshComponent):
            row['instances'] = [_serial(comp.get_instance_transform(i, world_space=True))
                                for i in range(comp.get_instance_count())]
        rows.append(row)
    return sorted(rows, key=lambda x: (x['name'], x['class_name']))


def _actor_row(actor, include_script=False):
    row = dict(path=actor.get_path_name(), name=actor.get_name(), label=actor.get_actor_label(),
               cls=actor.get_class().get_name(), tags=sorted(str(t) for t in actor.tags), pose=_pose(actor),
               folder=str(actor.get_folder_path()), hidden=bool(actor.hidden), components=_components(actor))
    root_component = actor.root_component
    row['root_component'] = root_component.get_name() if root_component else None
    owner = actor.get_owner()
    row['owner'] = owner.get_path_name() if owner else None
    parent = actor.get_attach_parent_actor()
    row['attach_parent'] = parent.get_path_name() if parent else None
    if actor.get_class().get_name() == 'Ck_EntitySpawner_UE':
        row['spawner'] = dict(
            replicated_channel=_serial(actor.get_editor_property('_ReplicatedChannelGroup')),
            transform_binding=_serial(actor.get_editor_property('_InjectActorTransformToScriptProperty')))
    if include_script:
        try:
            script = actor.get_editor_property('_EntityScript')
        except Exception:
            script = None
        row['script'] = dict(path=script.get_path_name() if script else None,
                             cls=script.get_class().get_name() if script else None,
                             outer=script.get_outer().get_path_name() if script and script.get_outer() else None)
    return row


def _actor_identity_projection(row):
    components = []
    for component in row['components']:
        projected = dict(component)
        projected.pop('world_transform', None)
        if projected['name'] == row['root_component']:
            # SceneRoot relative pose is the actor transform for Ck spawners;
            # the actor pose is checked independently against the approved target.
            projected.pop('relative_transform', None)
        if 'light' in projected:
            projected['light'] = dict(projected['light'])
            projected['light'].pop('world_transform', None)
        if 'camera' in projected:
            projected['camera'] = dict(projected['camera'])
            projected['camera'].pop('world_transform', None)
        components.append(projected)
    return dict(cls=row['cls'], label=row['label'], tags=row['tags'], folder=row['folder'],
                hidden=row['hidden'], owner=row['owner'], attach_parent=row['attach_parent'],
                root_component=row['root_component'], spawner=row.get('spawner'), components=components)


def _world_roster(u, world):
    return sorted((_actor_row(a, True) for a in u.GameplayStatics.get_all_actors_of_class(world, u.Actor)),
                  key=lambda x: x['path'])


def _script_fields(script, spec):
    return {field: _serial(script.get_editor_property(field)) for field in spec['fields']}


def _target_transform(u, spec, instances, core, pivots):
    tile = spec['destination']
    pivot = pivots[tile]
    plan = spec['plan']
    local = [(plan[i] - pivot[i]) * 100.0 for i in range(3)]
    transform = u.Transform(location=u.Vector(*local),
                            rotation=u.Rotator(pitch=spec.get('pitch', 0.0), yaw=spec['yaw'], roll=0.0),
                            scale=u.Vector(1.0, 1.0, 1.0))
    world_transform = u.MathLibrary.compose_transforms(transform, instances[tile]['instance_transform'])
    return transform, world_transform


def _find_unique_receipt(path, digest, phase):
    path = Path(path)
    if not path.is_absolute():
        path = ROOT / path
    path = path.resolve()
    try:
        path.relative_to(CHECKPOINT.resolve())
    except ValueError:
        raise AssertionError('Refuse receipt outside the mechanism-layout checkpoint')
    assert path.is_file() and _sha(path) == digest, 'Staging receipt hash mismatch'
    row = _json(path)
    assert row.get('phase') == phase and row.get('schema') == 1
    return path, row


def _state_module():
    if STATE_MODULE not in sys.modules:
        import types
        sys.modules[STATE_MODULE] = types.ModuleType(STATE_MODULE)
        sys.modules[STATE_MODULE].active = None
    return sys.modules[STATE_MODULE]


def prepare():
    """Verify source identities and checkpoint all three map files before mutation."""
    u = _u()
    assert _state_module().active is None, 'Previous mechanism staging still holds editor objects'
    _, dirty = _editor_context(u)
    core = _core()
    inputs = _guard_inputs(core)
    maps_before = _package_hashes()
    for tile, spec in MAPS.items():
        assert maps_before[tile] == spec['sha256'], ('Reviewed map changed', tile, maps_before[tile])
    inst = _instances(u, None)
    actors = {}
    scripts = {}
    for name, spec in (('P5', P5), ('P1', P1)):
        actors[name], scripts[name] = _source_actor(u, inst[spec['source']]['world'], spec)
    assert actors['P5'].get_level() == _persistent_level(u, inst['Belfry']['world'])
    assert actors['P1'].get_level() == _persistent_level(u, inst['Pit']['world'])
    rosters = {tile: _world_roster(u, inst[tile]['world']) for tile in MAPS}
    assert _p5_channel_sources(u, inst) == [actors['P5'].get_path_name()], 'Expected one original P5 source across the three staged LIs'
    assert not any(row['label'] == P5['label'] for row in rosters['Reliquary']), 'P5 destination already has the lever label'
    mechanism_before = {name: dict(actor=_actor_row(actors[name], True), fields=_script_fields(scripts[name], spec))
                        for name, spec in (('P5', P5), ('P1', P1))}
    assert 'Mechanism.Channel.Warrens.Puzzle.P5' in json.dumps(mechanism_before['P5']['fields'], sort_keys=True)
    for name, spec in (('P5', P5), ('P1', P1)):
        binding = str(mechanism_before[name]['actor']['spawner']['transform_binding'])
        assert binding in ('(_PropertyName="")', '(_PropertyName="SpawnTransform")'), (
            'Unexpected authored actor-transform injection binding', name, binding)
    target = {name: dict(local=_serial(_target_transform(u, spec, inst, core, inputs['fit_pivots'])[0]),
                         assembled=_serial(_target_transform(u, spec, inst, core, inputs['fit_pivots'])[1]))
              for name, spec in (('P5', P5), ('P1', P1))}
    checkpoint_files = {}
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ') + '_' + uuid.uuid4().hex[:8]
    backup_dir = CHECKPOINT / ('maps_' + stamp)
    backup_dir.mkdir(parents=True, exist_ok=False)
    for tile, spec in MAPS.items():
        source = ROOT / ('Content/' + spec['package'].removeprefix('/Game/') + '.umap')
        target_path = backup_dir / (tile + '.umap')
        shutil.copy2(source, target_path)
        assert _sha(source) == _sha(target_path) == maps_before[tile]
        checkpoint_files[tile] = dict(path=target_path.relative_to(ROOT).as_posix(), sha256=_sha(target_path))
    receipt = dict(phase='PREPARED', maps=MAPS, before_map_sha256=maps_before,
                   checkpoint_maps=checkpoint_files, guards=inputs, dirty_before=dirty,
                   source_worlds={tile: inst[tile]['world'].get_path_name() for tile in MAPS},
                   source_rosters=rosters, mechanisms_before=mechanism_before, targets=target,
                   compatibility='Fresh-expedition only. P5 SaveKey changes with destination package; no old-save migration is asserted.',
                   save_plan='After a separate next-frame audit, save only Belfry, Reliquary, Pit with _AutoCookStaticWorldOnLevelSave=DISABLE, restoring its prior value in finally.')
    path = _write_unique(receipt)
    return dict(path=path.relative_to(ROOT).as_posix(), sha256=_sha(path), phase='PREPARED', maps_before=maps_before)


def apply_staged(receipt_path, receipt_sha256):
    """Apply reversible in-memory transforms and the approved P5 source ownership transfer; never save."""
    u = _u()
    state = _state_module()
    assert state.active is None, 'Staging already active'
    path, report = _find_unique_receipt(receipt_path, receipt_sha256, 'PREPARED')
    _, dirty = _editor_context(u)
    core = _core()
    assert _package_hashes() == report['before_map_sha256']
    assert core._content_guards() == report['guards']['protected_614']
    inst = _instances(u, None)
    old_p5, old_p5_script = _source_actor(u, inst['Belfry']['world'], P5)
    p1_actor, p1_script = _source_actor(u, inst['Pit']['world'], P1)
    assert _world_roster(u, inst['Belfry']['world']) == report['source_rosters']['Belfry']
    assert _world_roster(u, inst['Reliquary']['world']) == report['source_rosters']['Reliquary']
    assert _world_roster(u, inst['Pit']['world']) == report['source_rosters']['Pit']
    subsystem = u.get_editor_subsystem(u.EditorActorSubsystem)
    pivots = report['guards']['fit_pivots']
    p5_local, p5_world = _target_transform(u, P5, inst, core, pivots)
    p1_local, p1_world = _target_transform(u, P1, inst, core, pivots)
    assert all(abs(x-y)<0.01 for x,y in zip(p5_world.translation.to_tuple(), (2300.0, 1850.0, 250.3)))
    assert all(abs(x-y)<0.01 for x,y in zip(p1_world.translation.to_tuple(), (-1350.0, 351.2, -400.0)))
    started = dict(report, phase='APPLY_STARTED', prepared_receipt=path.relative_to(ROOT).as_posix(),
                   prepared_receipt_sha256=receipt_sha256, p5_clone_path=None, map_save_performed=False)
    state.active = dict(phase='APPLY_STARTED', prepared=report, p5_actor=None, p5_script=None,
                        p1_actor=p1_actor, p1_script=p1_script, old_p5_actor=old_p5,
                        old_p5_script=old_p5_script, applied=False)
    started_path = _write_unique(started)
    try:
        new_p5 = subsystem.duplicate_actor(old_p5, inst['Reliquary']['world'], u.Vector(0.0, 0.0, 0.0))
        state.active['p5_actor'] = new_p5
        assert new_p5 and new_p5 != old_p5
        assert new_p5.get_level() == _persistent_level(u, inst['Reliquary']['world'])
        assert new_p5.get_path_name().startswith(MAPS['Reliquary']['path'] + ':PersistentLevel.')
        new_p5.set_actor_label(P5['label'])
        new_p5_script = new_p5.get_editor_property('_EntityScript')
        state.active['p5_script'] = new_p5_script
        assert new_p5_script and new_p5_script.get_outer() == new_p5
        assert new_p5_script != old_p5_script and old_p5_script.get_outer() == old_p5, (
            'Destination must own a distinct cloned EntityScript instance')
        assert new_p5_script.get_class().get_name() == P5['script_class']
        source_fields = _script_fields(old_p5_script, P5)
        duplicate_fields = _script_fields(new_p5_script, P5)
        assert source_fields == duplicate_fields, ('P5 duplicate changed non-pose authored fields', source_fields, duplicate_fields)
        old_row = _actor_row(old_p5, True)
        new_row = _actor_row(new_p5, True)
        assert _actor_identity_projection(old_row) == _actor_identity_projection(new_row), (
            'P5 duplicate changed actor tags, component roster, injection/channel, or component properties',
            _actor_identity_projection(old_row), _actor_identity_projection(new_row))
        new_p5.modify()
        new_p5_script.modify()
        new_p5.set_actor_transform(p5_local, False, False)
        new_p5_script.set_editor_property('SpawnTransform', p5_local)
        p1_actor.modify()
        p1_script.modify()
        p1_actor.set_actor_transform(p1_local, False, False)
        p1_script.set_editor_property('SpawnTransform', p1_local)
        assert _script_fields(new_p5_script, P5) == dict(source_fields, SpawnTransform=_serial(p5_local))
        assert _script_fields(p1_script, P1) == dict(report['mechanisms_before']['P1']['fields'], SpawnTransform=_serial(p1_local))
        _assert_actor_transform(new_p5, p5_local)
        _assert_actor_transform(p1_actor, p1_local)
        old_p5_path = old_p5.get_path_name()
        assert subsystem.destroy_actor(old_p5), 'Could not remove previous Belfry P5 spawner after clone validation'
        state.active['applied'] = True
        state.active['phase'] = 'STAGED_UNSAVED'
        staged = dict(report, phase='STAGED_UNSAVED', prepared_receipt=path.relative_to(ROOT).as_posix(),
                      prepared_receipt_sha256=receipt_sha256, apply_receipt=started_path.relative_to(ROOT).as_posix(),
                      apply_receipt_sha256=_sha(started_path), old_p5_removed=old_p5_path,
                      new_p5_actor=new_p5.get_path_name(), new_p5_script=new_p5_script.get_path_name(),
                      source_rosters_before=report['source_rosters'],
                  dirty_after=_dirty_names(u),
                      map_save_performed=False, applied_utc=datetime.now(timezone.utc).isoformat())
        staged_path = _write_unique(staged)
        state.active.update(staged_receipt_path=str(staged_path), staged_receipt_sha256=_sha(staged_path))
        return dict(status='STAGED_UNSAVED', receipt=staged_path.relative_to(ROOT).as_posix(),
                    receipt_sha256=_sha(staged_path), p5_new_actor=new_p5.get_path_name(),
                    p1_actor=p1_actor.get_path_name(), save_performed=False,
                    settle='Call verify_and_save from a later editor callback after end-of-frame.')
    except Exception as error:
        failure = dict(phase='STAGING_FAILED', prepared_receipt=path.relative_to(ROOT).as_posix(),
                       prepared_receipt_sha256=receipt_sha256, apply_receipt=started_path.relative_to(ROOT).as_posix(),
                       apply_receipt_sha256=_sha(started_path), p5_clone_path=(state.active['p5_actor'].get_path_name()
                                                                              if state.active['p5_actor'] else None),
                       error=repr(error), recover='Do not retry. Inspect current editor state; close editor and restore all three map backups if any mutation occurred.')
        _write_unique(failure)
        raise


def verify_and_save(receipt_path, receipt_sha256):
    """Reacquire source worlds next callback, verify exact roster deltas, then save only three maps."""
    u = _u()
    state = _state_module()
    assert state.active and state.active['applied'], 'No staged mechanism change is active'
    path, report = _find_unique_receipt(receipt_path, receipt_sha256, 'STAGED_UNSAVED')
    _, dirty = _editor_context(u, require_clean=False)
    core = _core()
    inst = _instances(u, None)
    assert _package_hashes() == report['before_map_sha256'], 'Disk maps changed before staged save'
    before_rosters = report['source_rosters']
    now = {tile: _world_roster(u, inst[tile]['world']) for tile in MAPS}
    expected = {tile: list(rows) for tile, rows in before_rosters.items()}
    expected['Belfry'] = [row for row in expected['Belfry'] if row['label'] != P5['label']]
    p5_row = _actor_row(state.active['p5_actor'], True)
    p5_before = next(row for row in before_rosters['Belfry'] if row['label'] == P5['label'])
    assert _actor_identity_projection(p5_row) == _actor_identity_projection(p5_before), (
        'P5 destination actor no longer matches the reviewed source actor configuration')
    assert p5_row['script']['cls'] == p5_before['script']['cls'] == P5['script_class']
    p5_local, _ = _target_transform(u, P5, inst, core, report['guards']['fit_pivots'])
    p1_local, _ = _target_transform(u, P1, inst, core, report['guards']['fit_pivots'])
    _assert_actor_transform(state.active['p5_actor'], p5_local)
    _assert_actor_transform(state.active['p1_actor'], p1_local)
    assert state.active['p5_actor'].get_level() == _persistent_level(u, inst['Reliquary']['world'])
    assert state.active['p1_actor'].get_level() == _persistent_level(u, inst['Pit']['world'])
    assert _p5_channel_sources(u, inst) == [state.active['p5_actor'].get_path_name()], (
        'Final authored source roster must have exactly one P5 channel source')
    assert state.active['p1_actor'].get_path_name() == report['mechanisms_before']['P1']['actor']['path'], (
        'P1 lock object identity changed during its in-place move')
    expected['Reliquary'].append(p5_row)
    expected['Reliquary'] = sorted(expected['Reliquary'], key=lambda x: x['path'])
    for tile in ('Belfry', 'Reliquary'):
        assert now[tile] == expected[tile], ('Unexpected actor/component roster delta', tile)
    changed_pit = [dict(row) for row in before_rosters['Pit']]
    original_p1 = report['mechanisms_before']['P1']['actor']['path']
    idx = next(i for i, row in enumerate(changed_pit) if row['path'] == original_p1)
    changed_pit[idx] = _actor_row(state.active['p1_actor'], True)
    p1_before = next(row for row in before_rosters['Pit'] if row['label'] == P1['label'])
    assert _actor_identity_projection(changed_pit[idx]) == _actor_identity_projection(p1_before), (
        'Moved P1 lock changed owner, injection, script identity or component configuration')
    assert changed_pit[idx]['script']['cls'] == p1_before['script']['cls'] == P1['script_class']
    assert sorted(changed_pit, key=lambda x: x['path']) == now['Pit'], 'Unexpected Pit roster or component change'
    p5_new_script = state.active['p5_script']
    p1_script = state.active['p1_script']
    assert p5_new_script.get_outer() == state.active['p5_actor'] and p1_script.get_outer() == state.active['p1_actor']
    assert _script_fields(p5_new_script, P5) == dict(report['mechanisms_before']['P5']['fields'],
                                                     SpawnTransform=report['targets']['P5']['local'])
    assert _script_fields(p1_script, P1) == dict(report['mechanisms_before']['P1']['fields'],
                                                 SpawnTransform=report['targets']['P1']['local'])
    # Find the actual channel among the cloned control/source specs; it must be unchanged.
    assert 'Mechanism.Channel.Warrens.Puzzle.P5' in json.dumps(_script_fields(p5_new_script, P5), sort_keys=True)
    inputs = _guard_inputs(core)
    assert inputs['protected_614'] == report['guards']['protected_614']
    assert inputs['collision_54'] == report['guards']['collision_54']
    allowed = {MAPS[tile]['package'] for tile in MAPS}
    dirty_now = _dirty_names(u)
    dirty_map_paths = set(dirty_now['maps'])
    dirty_content_paths = set(dirty_now['content'])
    assert dirty_map_paths == allowed and not dirty_content_paths, ('Exactly three source LIs must be dirty', dirty_now)
    settings_class = u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    assert settings_class and hasattr(u.EditorLoadingAndSavingUtils, 'save_map')
    settings = u.get_default_object(settings_class)
    old_cook = settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    assert hasattr(type(old_cook), 'DISABLE'), 'Auto-cook disable enum unavailable'
    saving = dict(report, phase='SAVING', dirty_before_save=dirty_now,
                  after_rosters=now, auto_cook_before=_serial(old_cook), save_attempted=[], saved_packages=[],
                  map_save_performed=False)
    saving_path = _write_unique(saving)
    attempted = []
    saved = []
    try:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(old_cook).DISABLE)
        for tile in ('Belfry', 'Reliquary', 'Pit'):
            world = inst[tile]['world']
            ok = u.EditorLoadingAndSavingUtils.save_map(world, MAPS[tile]['package'])
            attempted.append(tile)
            assert ok, ('Map save failed; close editor and restore all checkpoints', tile)
            saved.append(tile)
    except Exception as error:
        _write_unique(dict(phase='SAVE_FAILED', staged_receipt=path.relative_to(ROOT).as_posix(),
                           staged_receipt_sha256=receipt_sha256, save_receipt=saving_path.relative_to(ROOT).as_posix(),
                           save_receipt_sha256=_sha(saving_path), attempted=attempted, saved=saved,
                           error=repr(error), recover='Close editor and restore all three map checkpoints as one unit.'))
        raise
    finally:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', old_cook)
    assert settings.get_editor_property('_AutoCookStaticWorldOnLevelSave') == old_cook
    after = _package_hashes()
    assert all(after[tile] != report['before_map_sha256'][tile] for tile in ('Belfry', 'Reliquary', 'Pit'))
    try:
        final_guards = core._content_guards()
        expected_guards = dict(report['guards']['protected_614'])
        for tile, spec in MAPS.items():
            rel = 'Content/' + spec['package'].removeprefix('/Game/') + '.umap'
            assert rel in expected_guards
            expected_guards[rel] = after[tile]
        assert final_guards == expected_guards, 'Protected 614-file roster changed beyond the three approved maps'
        final_collision = {rel: _sha(ROOT / rel) for rel in _json(COLLISION_HASHES)}
        assert final_collision == report['guards']['collision_54'], 'Protected 54-file collision set changed'
        dirty_after = _dirty_names(u)
        assert not dirty_after['maps'] and not dirty_after['content'], ('Packages remain dirty after saving', dirty_after)
    except Exception as error:
        _write_unique(dict(phase='POST_SAVE_VERIFICATION_FAILED', staged_receipt=path.relative_to(ROOT).as_posix(),
                           staged_receipt_sha256=receipt_sha256, save_receipt=saving_path.relative_to(ROOT).as_posix(),
                           save_receipt_sha256=_sha(saving_path), after_map_sha256=after, error=repr(error),
                           recover='Do not enter PIE. Close editor and restore all three map checkpoints as one unit.'))
        raise
    final = dict(saving, phase='SAVED_REOPEN_REQUIRED', save_attempted=attempted, saved_packages=saved,
                 after_map_sha256=after, protected_614_after=final_guards,
                 collision_54_after=final_collision, auto_cook_restored=True, dirty_after=dirty_after,
                 map_save_performed=True,
                 runtime_claim='None. Reopen/reload source LIs and verify exact roster before PIE.')
    final_path = _write_unique(final)
    state.active = None
    return dict(status=final['phase'], receipt=final_path.relative_to(ROOT).as_posix(),
                receipt_sha256=_sha(final_path), saved=saved, after_map_sha256=after,
                auto_cook_restored=True, next='Close/reopen or reload and independently verify before PIE.')
