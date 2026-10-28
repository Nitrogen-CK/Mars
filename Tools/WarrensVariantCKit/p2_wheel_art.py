"""Source-bound CCS21 wheel previews for the assembled Warrens C map.

Call bind_preview() in the clean editor world, optionally run PIE and inspect_live(),
then stop PIE and call restore_preview(). staged_save_preview() is the separately
approved checkpointed Canal-only save path; it must not be called casually.
"""
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

import unreal as u


ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT / 'Saved/WarrensCGameplay-20261024'
CHECKPOINT = RUN / 'WheelArtCheckpoint'
RECEIPT = CHECKPOINT / 'p2_wheel_preview_r02.json'
COLLISION_HASHES = RUN / 'StartupCheckpoint/collision_hashes.json'
CANAL_PACKAGE = ROOT / 'Content/Mars/Maps/Variants/v8c/LI_Warrens_Canal.umap'
EXPECTED_CANAL_SHA = '001f554db780f507a568ee7c71ba106d904c3069e916915c852ef68f09fec5d8'
EXPECTED_EDITOR_WORLD = '/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'
CANAL_LEVEL_PREFIX = '/Game/Mars/Maps/Variants/v8c/LI_Warrens_Canal.'
ACTOR_LABEL = 'WVC_P2_SlidingSpan'
SCRIPT_CLASS = 'Mars_SlidingBridge_EntityScript'
MESH_PATH = '/Game/Mars/Environment/ChainCrossingKit/Meshes/WarrensC_CCS21_HandwheelBody_Mars_SM'
TX09_PATH = '/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX09'
ART_FIELDS = ('WheelMeshOverride', 'WheelMeshLocalTransform', 'WheelMaterialOverride')
MECHANISM_FIELDS = ('SpawnTransform', 'Bridge', 'Source', 'PromptText', 'DeckMeshOverride',
                    'CageMeshOverride', 'MaterialOverride', 'GuardMeshOverride')
EA = u.get_editor_subsystem(u.EditorActorSubsystem)
ED = u.get_editor_subsystem(u.UnrealEditorSubsystem)
_STATE = None


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def asset_path(value):
    return value.get_path_name().split('.')[0] if value else None


def serial(value):
    if isinstance(value, u.Transform):
        return dict(location=list(value.translation.to_tuple()), rotation_xyzw=list(value.rotation.to_tuple()), scale=list(value.scale3d.to_tuple()))
    if value is None or isinstance(value, (str, bool, int, float)):
        return value
    if hasattr(value, 'get_path_name'):
        return value.get_path_name()
    if hasattr(value, 'export_text'):
        return value.export_text()
    if isinstance(value, (list, tuple)):
        return [serial(item) for item in value]
    return str(value)


def pose(actor):
    return [list(actor.get_actor_location().to_tuple()), list(actor.get_actor_rotation().to_tuple()),
            list(actor.get_actor_scale3d().to_tuple())]


def collision_guard():
    expected = json.loads(COLLISION_HASHES.read_text(encoding='utf-8-sig'))
    actual = {relative: sha(ROOT / relative) for relative in expected}
    mismatches = {relative: dict(expected=expected[relative], actual=actual[relative])
                  for relative in expected if expected[relative] != actual[relative]}
    assert len(expected) == 54 and not mismatches, ('Protected collision package delta', mismatches)
    return dict(count=len(actual), files=actual, sha256=hashlib.sha256(
        json.dumps(actual, sort_keys=True).encode('utf-8')).hexdigest())


def dirty_status():
    return dict(maps=[str(item) for item in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()],
                content=[str(item) for item in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()])


def editor_context(require_clean):
    world = ED.get_editor_world()
    assert world and world.get_path_name().split('.')[0] == EXPECTED_EDITOR_WORLD, 'Expected assembled Warrens C editor world'
    assert ED.get_game_world() is None, 'Stop PIE before changing the unsaved preview'
    dirty = dirty_status()
    if require_clean:
        assert not dirty['maps'] and not dirty['content'], ('Unsaved packages before preview', dirty)
    assert CANAL_PACKAGE.exists() and sha(CANAL_PACKAGE) == EXPECTED_CANAL_SHA, 'Canal package changed since P2 receipt'
    return world


def source_actor(world):
    # Assembled-map actor enumeration excludes unopened LI source actors.
    # Follow the exact authored Canal instance instead of searching other worlds.
    _, source_world = canal_instance_source_world(world)
    rows = [actor for actor in u.GameplayStatics.get_all_actors_of_class(source_world, u.Actor)
            if actor.get_actor_label() == ACTOR_LABEL]
    assert len(rows) == 1, ('Expected exactly one source P2 owner', [a.get_path_name() for a in rows])
    actor = rows[0]
    assert actor.get_path_name().startswith(CANAL_LEVEL_PREFIX), actor.get_path_name()
    script = actor.get_editor_property('_EntityScript')
    assert script and script.get_class().get_name() == SCRIPT_CLASS, (
        actor.get_path_name(), script.get_class().get_name() if script else None)
    return actor, script


def canal_instance_source_world(main_world):
    instances = [actor for actor in EA.get_all_level_actors()
                 if actor.get_actor_label() == 'Warrens_LI_Canal']
    assert len(instances) == 1 and instances[0].get_class().get_name() == 'LevelInstance'
    source_world = instances[0].get_editor_property('world_asset')
    assert source_world and source_world.get_path_name().startswith(CANAL_LEVEL_PREFIX)
    return instances[0], source_world


def mechanism_snapshot(actor, script):
    return dict(actor=actor.get_path_name(), label=actor.get_actor_label(), tags=[str(tag) for tag in actor.tags],
                pose=pose(actor), properties={field: serial(script.get_editor_property(field))
                                              for field in MECHANISM_FIELDS})


def same_mechanism(actor, script, before):
    return mechanism_snapshot(actor, script) == before


def write_receipt(report):
    RECEIPT.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')


def active_receipt_path():
    if _STATE and _STATE.get('receipt_path'):
        return _STATE['receipt_path']
    return RECEIPT


def bind_preview():
    """Bind the approved mesh and adapter on the exact assembled C bridge, without saving."""
    global _STATE
    assert _STATE is None and not RECEIPT.exists(), 'Existing preview state found; restore or inspect it first'
    world = editor_context(require_clean=True)
    actor, script = source_actor(world)
    before = mechanism_snapshot(actor, script)
    old = {field: script.get_editor_property(field) for field in ART_FIELDS}
    transform = old['WheelMeshLocalTransform']
    old['WheelMeshLocalTransform'] = u.Transform(location=u.Vector(*transform.translation.to_tuple()), rotation=transform.rotation.rotator(), scale=u.Vector(*transform.scale3d.to_tuple()))
    assert old['WheelMeshOverride'] is None and old['WheelMaterialOverride'] is None, (
        'Existing wheel presentation override requires review', {k: serial(v) for k, v in old.items()})
    assert serial(old['WheelMeshLocalTransform']) == serial(u.Transform()), (
        'Existing wheel local transform requires review', serial(old['WheelMeshLocalTransform']))
    mesh = u.load_asset(MESH_PATH)
    assert mesh and mesh.get_path_name().split('.')[0] == MESH_PATH, ('CCS21 mesh unavailable', MESH_PATH)
    candidate_transform = u.Transform(location=u.Vector(0.0, 0.0, 0.0),
                                      rotation=u.Rotator(pitch=0.0, yaw=90.0, roll=0.0),
                                      scale=u.Vector(1.0, 1.0, 1.0))
    collision = collision_guard()
    _STATE = dict(actor=actor, script=script, old=old, before=before,
                  candidate=dict(WheelMeshOverride=mesh, WheelMeshLocalTransform=candidate_transform,
                                 WheelMaterialOverride=None))
    write_receipt(dict(status='PREVIEW_BINDING_STARTED', map=world.get_path_name(), canal_sha256=EXPECTED_CANAL_SHA,
                       source_actor=before['actor'], before_art_fields={k: serial(v) for k, v in old.items()},
                       mechanism_before=before, collision_files=collision, saved=False,
                       boundary='Pre-mutation recovery checkpoint; preview properties are not yet confirmed.'))
    before_record = CHECKPOINT / 'p2_wheel_preview_r02_before.json'
    assert not before_record.exists()
    before_record.write_bytes(RECEIPT.read_bytes())
    actor.modify()
    script.modify()
    script.set_editor_property('WheelMeshOverride', mesh)
    script.set_editor_property('WheelMeshLocalTransform', candidate_transform)
    assert script.get_editor_property('WheelMeshOverride') == mesh
    assert asset_path(script.get_editor_property('WheelMeshOverride')) == MESH_PATH
    assert serial(script.get_editor_property('WheelMeshLocalTransform')) == serial(candidate_transform)
    assert script.get_editor_property('WheelMaterialOverride') is None
    assert same_mechanism(actor, script, before), 'A non-art mechanism field, actor pose, tag or owner changed'
    report = dict(status='UNSAVED_PREVIEW_BOUND', map=world.get_path_name(), canal_sha256=EXPECTED_CANAL_SHA,
                  source_actor=before['actor'], script_class=SCRIPT_CLASS, before_art_fields={k: serial(v) for k, v in old.items()},
                  candidate_art_fields=dict(WheelMeshOverride=MESH_PATH,
                                            WheelMeshLocalTransform=serial(candidate_transform),
                                            WheelMaterialOverride=None),
                  mechanism_before=before, collision_files=collision, dirty_packages_after=dirty_status(),
                  saved=False, boundary='Only three nullable wheel visual properties were assigned; no package was saved.')
    write_receipt(report)
    print('P2_WHEEL_ART_UNSAVED_PREVIEW', report.get('status', 'recorded'))
    return report


def preview_tx09():
    """Optional unsaved wheel-only material comparison; remembers the prior candidate value."""
    global _STATE
    assert _STATE is not None, 'Call bind_preview() first in this Python session'
    world = editor_context(require_clean=False)
    actor, script = source_actor(world)
    assert actor == _STATE['actor'] and script == _STATE['script']
    assert same_mechanism(actor, script, _STATE['before'])
    previous = script.get_editor_property('WheelMaterialOverride')
    assert previous is None, ('Wheel material already changed; inspect before retry', serial(previous))
    material = u.load_asset(TX09_PATH)
    assert material and material.get_path_name().split('.')[0] == TX09_PATH
    script.modify()
    script.set_editor_property('WheelMaterialOverride', material)
    assert asset_path(script.get_editor_property('WheelMaterialOverride')) == TX09_PATH
    collision_guard()
    _STATE['candidate']['WheelMaterialOverride'] = material
    report = json.loads(RECEIPT.read_text(encoding='utf-8'))
    report['dirty_packages_before_tx09'] = dirty_status()
    report['material_trial'] = dict(previous_candidate_value=serial(previous), candidate_value=TX09_PATH,
                                    changed_field='WheelMaterialOverride')
    report['candidate_art_fields']['WheelMaterialOverride'] = TX09_PATH
    report['dirty_packages_after_tx09'] = dirty_status()
    report['saved'] = False
    write_receipt(report)
    print('P2_WHEEL_ART_TX09_PREVIEW', json.dumps(report['material_trial']))
    return report


def inspect_live():
    """Read the actual PIE wheel mesh part; this function never writes a component."""
    world = ED.get_game_world()
    assert world and 'UEDPIE' in world.get_path_name(), 'Start PIE with assembled C loaded'
    receipt_path = active_receipt_path()
    assert receipt_path.exists(), 'Bind the source preview first'
    preview = json.loads(receipt_path.read_text(encoding='utf-8'))
    assert preview['status'] in ('UNSAVED_PREVIEW_BOUND', 'STAGED_CANAL_SAVED'), (
        'Preview binding did not complete', preview['status'])
    rows = []
    for actor in u.GameplayStatics.get_all_actors_of_class(world, u.Actor):
        for component in actor.get_components_by_class(u.StaticMeshComponent):
            handle = u.Ck_Utils_UnrealComponent_UE.try_get_owning_handle_from_component(component)
            if not handle:
                continue
            debug_name = str(u.Ck_Utils_Handle_UE.get_debug_name(handle)).removeprefix('UnrealComponent: ')
            if debug_name != 'SlidingBridge_Wheel':
                continue
            mesh = component.static_mesh
            owner = component.get_owner()
            rows.append(dict(source_entity_part=debug_name, component=component.get_path_name(),
                             source_bound_owner=owner.get_path_name() if owner else None,
                             editor_source_owner=preview['source_actor'],
                             mesh=asset_path(mesh), material=asset_path(component.get_material(0)),
                             world_transform=serial(component.get_world_transform()),
                             collision_profile=str(component.get_collision_profile_name()),
                             collision_enabled=str(component.get_collision_enabled())))
    assert len(rows) == 1, ('Expected one runtime wheel component', rows)
    report = dict(status='PIE_COMPONENT_OBSERVED', world=world.get_path_name(), rows=rows,
                  saved=False, boundary='Read-only component inspection; source-bound owner is the UE component owner plus Ck part debug name.')
    print('P2_WHEEL_ART_LIVE_INSPECTION', report.get('status', 'recorded'))
    return report


def restore_preview():
    """Restore the exact pre-preview wheel properties after PIE, without saving or discarding packages."""
    global _STATE
    assert _STATE is not None, 'No live preview state in this Python session'
    assert not _STATE.get('staged_saved'), 'Staged Canal restore is handled from the owned checkpoint with Unreal closed'
    world = editor_context(require_clean=False)
    actor, script = source_actor(world)
    assert actor == _STATE['actor'] and script == _STATE['script'], 'Loaded P2 source actor changed'
    assert same_mechanism(actor, script, _STATE['before']), 'Non-art bridge invariants changed during preview'
    current = {field: script.get_editor_property(field) for field in ART_FIELDS}
    for field, expected in _STATE['candidate'].items():
        assert serial(current[field]) in (serial(expected), serial(_STATE['old'][field])), (
            'Preview art field changed unexpectedly', field, serial(current[field]),
            serial(expected), serial(_STATE['old'][field]))
    script.modify()
    for field, value in _STATE['old'].items():
        script.set_editor_property(field, value)
        assert serial(script.get_editor_property(field)) == serial(value), ('Failed to restore', field)
    assert same_mechanism(actor, script, _STATE['before'])
    assert collision_guard() == json.loads(RECEIPT.read_text(encoding='utf-8'))['collision_files']
    report = json.loads(RECEIPT.read_text(encoding='utf-8'))
    dirty_before_restore = dirty_status()
    report['restore'] = dict(status='PREVIEW_FIELDS_RESTORED', restored_fields={k: serial(v) for k, v in _STATE['old'].items()},
                             mechanism_unchanged=True, collision_files=collision_guard(),
                             dirty_packages_before=dirty_before_restore, dirty_packages_after=dirty_status(), saved=False)
    write_receipt(report)
    _STATE = None
    print('P2_WHEEL_ART_RESTORED', json.dumps(report['restore']))
    return report['restore']


def protected_file_paths():
    """All checkpointed project inputs/maps plus the wheel-only comparison assets."""
    paths = set()
    for manifest_path in (RUN / 'StartupCheckpoint/manifest.json', RUN / 'ArtCheckpoint/manifest.json'):
        manifest = json.loads(manifest_path.read_text(encoding='utf-8-sig'))
        paths.update(manifest.keys())
    for path in (ROOT / 'Content/Mars/Maps/Variants/v8c').glob('LI_Warrens_*.umap'):
        paths.add(path.relative_to(ROOT).as_posix())
    paths.add('Content/Mars/Maps/Warrens_VariantC_Mars_MAP.umap')
    for asset in (MESH_PATH, TX09_PATH):
        paths.add('Content/' + asset.removeprefix('/Game/') + '.uasset')
    result = {}
    for relative in sorted(paths):
        path = ROOT / relative
        assert path.is_file(), ('Missing protected source/map/asset', relative)
        result[relative] = sha(path)
    return result


def world_actor_rows(world):
    rows = []
    actors = u.GameplayStatics.get_all_actors_of_class(world, u.Actor)
    for actor in actors:
        components = []
        for component in actor.get_components_by_class(u.ActorComponent):
            item = dict(path=component.get_path_name(), name=component.get_name(),
                        class_path=component.get_class().get_path_name())
            if isinstance(component, u.SceneComponent):
                item['world_transform'] = serial(component.get_world_transform())
            if isinstance(component, u.StaticMeshComponent):
                item.update(mesh=asset_path(component.static_mesh),
                            materials=[asset_path(material) for material in component.get_materials()],
                            collision_profile=str(component.get_collision_profile_name()),
                            collision_enabled=str(component.get_collision_enabled()),
                            overlap=component.get_editor_property('generate_overlap_events'),
                            visible=component.is_visible(), shadow=component.cast_shadow)
                if isinstance(component, u.HierarchicalInstancedStaticMeshComponent):
                    item['instances'] = [serial(component.get_instance_transform(index, world_space=True))
                                         for index in range(component.get_instance_count())]
            if isinstance(component, u.LightComponent):
                color = component.light_color
                item['light'] = dict(intensity=component.intensity,
                                     color=[color.r, color.g, color.b, color.a],
                                     radius=component.attenuation_radius if hasattr(component, 'attenuation_radius') else None,
                                     shadow=component.cast_shadows,
                                     pose=serial(component.get_world_transform()))
            if isinstance(component, u.CameraComponent):
                item['camera'] = dict(fov=component.field_of_view,
                                      pose=serial(component.get_world_transform()))
            components.append(item)
        rows.append(dict(path=actor.get_path_name(), label=actor.get_actor_label(),
                         class_path=actor.get_class().get_path_name(), tags=sorted(str(tag) for tag in actor.tags),
                         pose=serial(actor.get_actor_transform()), hidden=actor.hidden,
                         components=sorted(components, key=lambda row: row['path'])))
    rows.sort(key=lambda row: row['path'])
    return rows


def source_world_snapshot(source_world, target_actor, target_script):
    rows = world_actor_rows(source_world)
    matches = [row for row in rows if row['path'] == target_actor.get_path_name()]
    assert len(matches) == 1, ('Target P2 actor missing from explicit Canal source-world roster', len(matches))
    target = matches[0]
    target['mechanism'] = mechanism_snapshot(target_actor, target_script)
    target['wheel_art'] = {field: serial(target_script.get_editor_property(field)) for field in ART_FIELDS}
    return dict(source_world=source_world.get_path_name(), actor_count=len(rows), actors=rows)


def non_wheel_visual_projection(snapshot):
    """Exclude only the approved wheel mesh and adapter; retain the material null invariant."""
    projected = json.loads(json.dumps(snapshot))
    for actor in projected['actors']:
        if actor['label'] == ACTOR_LABEL:
            assert actor['wheel_art']['WheelMaterialOverride'] is None
            del actor['wheel_art']['WheelMeshOverride']
            del actor['wheel_art']['WheelMeshLocalTransform']
    return projected


def dirty_package_names():
    def name(value):
        if hasattr(value, 'get_path_name'):
            return value.get_path_name().split('.')[0]
        return str(value).split('.')[0]
    return dict(maps=sorted(name(item) for item in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()),
                content=sorted(name(item) for item in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()))


def staged_save_preview():
    """Checkpoint and save the exact Canal LI so assembled PIE reads the candidate source binding."""
    global _STATE
    assert _STATE is None, 'Unsaved preview state is active; restore it before staged saving'
    assert not ED.get_game_world(), 'Stop PIE before staged save'
    main_world = ED.get_editor_world()
    assert main_world and main_world.get_path_name().split('.')[0] == EXPECTED_EDITOR_WORLD
    dirty_before = dirty_package_names()
    assert not dirty_before['maps'] and not dirty_before['content'], ('Unrelated packages are dirty', dirty_before)
    assert sha(CANAL_PACKAGE) == EXPECTED_CANAL_SHA, 'Canal disk hash changed since reviewed P2 source receipt'
    instance, source_world = canal_instance_source_world(main_world)
    assert source_world.get_path_name().split('.')[0] == CANAL_LEVEL_PREFIX.rstrip('.')
    assert hasattr(u.EditorLoadingAndSavingUtils, 'save_map'), 'UE map-specific SaveMap binding is unavailable'
    settings_class = u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    assert settings_class
    settings = u.get_default_object(settings_class)
    old_cook_setting = settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    assert hasattr(type(old_cook_setting), 'DISABLE'), 'Expected supported auto-cook DISABLE enum'
    actor, script = source_actor(main_world)
    assert actor.get_path_name().startswith(CANAL_LEVEL_PREFIX)
    before_mechanism = mechanism_snapshot(actor, script)
    old = {field: script.get_editor_property(field) for field in ART_FIELDS}
    transform = old['WheelMeshLocalTransform']
    old['WheelMeshLocalTransform'] = u.Transform(location=u.Vector(*transform.translation.to_tuple()),
                                                  rotation=transform.rotation.rotator(),
                                                  scale=u.Vector(*transform.scale3d.to_tuple()))
    assert old['WheelMeshOverride'] is None and old['WheelMaterialOverride'] is None
    assert serial(old['WheelMeshLocalTransform']) == serial(u.Transform())
    mesh = u.load_asset(MESH_PATH)
    assert mesh and asset_path(mesh) == MESH_PATH
    candidate_transform = u.Transform(location=u.Vector(0.0, 0.0, 0.0),
                                      rotation=u.Rotator(pitch=0.0, yaw=90.0, roll=0.0),
                                      scale=u.Vector(1.0, 1.0, 1.0))
    before_snapshot = source_world_snapshot(source_world, actor, script)
    collision_before = collision_guard()
    protected_before = protected_file_paths()
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    checkpoint = CHECKPOINT / ('LI_Warrens_Canal.pre_wheel_' + stamp + '.umap')
    receipt_path = CHECKPOINT / ('p2_wheel_staged_' + stamp + '.json')
    assert not checkpoint.exists() and not receipt_path.exists()
    shutil.copy2(CANAL_PACKAGE, checkpoint)
    checkpoint_hash = sha(checkpoint)
    disk_before_hash = sha(CANAL_PACKAGE)
    assert checkpoint_hash == EXPECTED_CANAL_SHA and disk_before_hash == checkpoint_hash
    report = dict(status='PREPARED', timestamp_utc=stamp,
                  receipt=str(receipt_path.relative_to(ROOT).as_posix()),
                  target_package='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Canal',
                  source_world=source_world.get_path_name(), level_instance=instance.get_path_name(),
                  source_actor=actor.get_path_name(), script_class=SCRIPT_CLASS,
                  before_sha256=disk_before_hash, checkpoint=str(checkpoint.relative_to(ROOT).as_posix()),
                  checkpoint_sha256=checkpoint_hash, expected_before_sha256=EXPECTED_CANAL_SHA,
                  before_art_fields={field: serial(value) for field, value in old.items()},
                  candidate_art_fields=dict(WheelMeshOverride=MESH_PATH,
                                            WheelMeshLocalTransform=serial(candidate_transform),
                                            WheelMaterialOverride=None),
                  mechanism_before=before_mechanism, source_world_roster_before=before_snapshot,
                  collision_before=collision_before, protected_files_before=protected_before,
                  dirty_packages_before=dirty_before, auto_cook_setting_restored=False, saved=False,
                  save_api='UEditorLoadingAndSavingUtils.save_map(source_world, exact_Canal_package_path)')
    receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

    actor.modify()
    script.modify()
    script.set_editor_property('WheelMeshOverride', mesh)
    script.set_editor_property('WheelMeshLocalTransform', candidate_transform)
    assert asset_path(script.get_editor_property('WheelMeshOverride')) == MESH_PATH
    assert serial(script.get_editor_property('WheelMeshLocalTransform')) == serial(candidate_transform)
    assert script.get_editor_property('WheelMaterialOverride') is None
    assert mechanism_snapshot(actor, script) == before_mechanism
    dirty_pre_save = dirty_package_names()
    canal_package = '/Game/Mars/Maps/Variants/v8c/LI_Warrens_Canal'
    assert set(dirty_pre_save['maps']).issubset({canal_package}) and not dirty_pre_save['content'], (
        'Only the authorized Canal LI may be dirty before save', dirty_pre_save)
    report['dirty_packages_before_save'] = dirty_pre_save
    report['status'] = 'BINDING_APPLIED_SAVE_PENDING'
    receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

    save_succeeded = False
    try:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(old_cook_setting).DISABLE)
        report['save_attempted'] = True
        receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        save_succeeded = u.EditorLoadingAndSavingUtils.save_map(
            source_world, '/Game/Mars/Maps/Variants/v8c/LI_Warrens_Canal')
    finally:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', old_cook_setting)
    assert settings.get_editor_property('_AutoCookStaticWorldOnLevelSave') == old_cook_setting
    if not save_succeeded:
        report.update(status='CANAL_SAVE_FAILED', after_sha256=sha(CANAL_PACKAGE), saved=False,
                      auto_cook_setting_restored=True, dirty_packages_after=dirty_package_names())
        receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        raise AssertionError('UEditorLoadingAndSavingUtils.save_map returned false for Canal LI')

    after_hash = sha(CANAL_PACKAGE)
    after_snapshot = source_world_snapshot(source_world, actor, script)
    try:
        collision_after = collision_guard()
    except Exception as error:
        report.update(status='POST_SAVE_COLLISION_GUARD_FAILED', after_sha256=after_hash, saved=True,
                      source_world_roster_after=after_snapshot,
                      collision_after_error=repr(error), dirty_packages_after=dirty_package_names(),
                      auto_cook_setting_restored=True)
        receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        raise
    protected_after = protected_file_paths()
    canal_relative = CANAL_PACKAGE.relative_to(ROOT).as_posix()
    protected_unchanged = {relative: before_hash for relative, before_hash in protected_before.items()
                           if relative != canal_relative and protected_after.get(relative) == before_hash}
    protected_changed = {relative: dict(before=before_hash, after=protected_after.get(relative))
                         for relative, before_hash in protected_before.items()
                         if relative != canal_relative and protected_after.get(relative) != before_hash}
    dirty_after = dirty_package_names()
    report.update(status='POST_SAVE_CHECKS_PENDING', after_sha256=after_hash, saved=True,
                  source_world_roster_after=after_snapshot, collision_after=collision_after,
                  protected_files_after=protected_after, protected_unchanged_count=len(protected_unchanged),
                  protected_changes=protected_changed, dirty_packages_after=dirty_after,
                  auto_cook_setting_restored=True,
                  boundary='Only the checkpointed Canal Level Instance was saved; no Main, generated data, or library package was saved.')
    receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    assert after_hash != disk_before_hash, 'Canal bytes did not change; source-bound binding was not persisted'
    assert non_wheel_visual_projection(after_snapshot) == non_wheel_visual_projection(before_snapshot), (
        'Source-world actor/component/HISM/light roster or non-wheel mechanism property changed')
    assert asset_path(script.get_editor_property('WheelMeshOverride')) == MESH_PATH
    assert script.get_editor_property('WheelMaterialOverride') is None
    assert serial(script.get_editor_property('WheelMeshLocalTransform')) == serial(candidate_transform)
    assert collision_after == collision_before, 'Protected Jolt collision packages changed'
    assert not protected_changed, ('Unexpected non-Canal protected file change', protected_changed)
    assert set(dirty_after['maps']).issubset({canal_package}) and not dirty_after['content'], (
        'Unexpected dirty package after exact Canal save', dirty_after)
    report['status'] = 'STAGED_CANAL_SAVED'
    receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    _STATE = dict(actor=actor, script=script, old=old, before=before_mechanism,
                  candidate=dict(WheelMeshOverride=mesh, WheelMeshLocalTransform=candidate_transform,
                                 WheelMaterialOverride=None), receipt_path=receipt_path, staged_saved=True)
    print('P2_WHEEL_STAGED_SAVE', json.dumps(dict(status=report['status'], before_sha256=disk_before_hash,
                                                   after_sha256=after_hash, checkpoint_sha256=checkpoint_hash,
                                                   actors=after_snapshot['actor_count'],
                                                   protected_files=len(protected_after), collision_files=collision_after['count'],
                                                   dirty_packages_after=dirty_after)))
    return report


def non_offset_visual_projection(snapshot):
    """Ignore only the approved local-X translation on the target wheel adapter."""
    projected = json.loads(json.dumps(snapshot))
    targets = [actor for actor in projected['actors'] if actor['label'] == ACTOR_LABEL]
    assert len(targets) == 1
    wheel_art = targets[0]['wheel_art']
    assert wheel_art['WheelMeshOverride'] == MESH_PATH + '.' + MESH_PATH.rsplit('/', 1)[1]
    assert wheel_art['WheelMaterialOverride'] is None
    transform = wheel_art['WheelMeshLocalTransform']
    assert transform['rotation_xyzw'] == [0.0, -0.0, 0.7071067690849304, 0.7071067690849304]
    assert transform['scale'] == [1.0, 1.0, 1.0]
    transform['location'] = [0.0, 0.0, 0.0]
    return projected


def staged_offset_preview(previousreceiptpath):
    """Checkpoint the accepted staged Canal map and save only a +2.5 cm wheel-node X offset."""
    global _STATE
    previous_path = Path(previousreceiptpath).resolve()
    expected_previous = (CHECKPOINT / 'p2_wheel_staged_20261025T052524814606Z.json').resolve()
    assert previous_path == expected_previous, ('Unexpected prior receipt; only the reviewed first stage may be chained',
                                                 str(previous_path))
    assert previous_path.is_file()
    previous = json.loads(previous_path.read_text(encoding='utf-8'))
    assert previous['status'] == 'STAGED_CANAL_SAVED'
    assert previous['after_sha256'] == '56e6c02ea2d835a08497910a0690e3885dfcc8c85301887532527020a7bb1b50'
    assert previous['before_sha256'] == EXPECTED_CANAL_SHA
    original_checkpoint = (ROOT / previous['checkpoint']).resolve()
    assert original_checkpoint.is_file() and sha(original_checkpoint) == EXPECTED_CANAL_SHA
    assert sha(CANAL_PACKAGE) == previous['after_sha256'], 'Canal is not at the accepted first-stage disk state'
    if _STATE is not None:
        assert _STATE.get('staged_saved') and Path(_STATE.get('receipt_path')).resolve() == previous_path, (
            'An unsaved preview is active or staged state does not match the chained receipt')

    assert not ED.get_game_world(), 'Stop PIE before staged offset save'
    main_world = ED.get_editor_world()
    assert main_world and main_world.get_path_name().split('.')[0] == EXPECTED_EDITOR_WORLD
    dirty_before = dirty_package_names()
    assert not dirty_before['maps'] and not dirty_before['content'], ('Packages are dirty before staged offset', dirty_before)
    instance, source_world = canal_instance_source_world(main_world)
    assert source_world.get_path_name().split('.')[0] == CANAL_LEVEL_PREFIX.rstrip('.')
    actor, script = source_actor(main_world)
    assert actor.get_path_name() == previous['source_actor']
    assert script.get_class().get_name() == SCRIPT_CLASS
    assert hasattr(u.EditorLoadingAndSavingUtils, 'save_map'), 'UE map-specific SaveMap binding is unavailable'

    mesh = script.get_editor_property('WheelMeshOverride')
    material = script.get_editor_property('WheelMaterialOverride')
    current_transform = script.get_editor_property('WheelMeshLocalTransform')
    assert asset_path(mesh) == MESH_PATH and material is None
    assert serial(current_transform) == previous['candidate_art_fields']['WheelMeshLocalTransform'], (
        'Current wheel transform differs from the reviewed first-stage receipt')
    assert list(current_transform.translation.to_tuple()) == [0.0, 0.0, 0.0], 'Expected zero X offset before this stage'
    before_mechanism = mechanism_snapshot(actor, script)
    assert before_mechanism == previous['mechanism_before']
    before_snapshot = source_world_snapshot(source_world, actor, script)
    assert before_snapshot == previous['source_world_roster_after'], 'Current 50-actor source roster differs from prior receipt'
    collision_before = collision_guard()
    assert collision_before == previous['collision_after'], 'Protected collision roster differs from first stage'
    protected_before = protected_file_paths()
    assert protected_before == previous['protected_files_after'], 'Protected source/map roster differs from first stage'

    transform = u.Transform(location=u.Vector(2.5, 0.0, 0.0),
                            rotation=u.Rotator(pitch=0.0, yaw=90.0, roll=0.0),
                            scale=u.Vector(1.0, 1.0, 1.0))
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    checkpoint = CHECKPOINT / ('LI_Warrens_Canal.pre_wheel_offset_' + stamp + '.umap')
    receipt_path = CHECKPOINT / ('p2_wheel_offset_staged_' + stamp + '.json')
    assert not checkpoint.exists() and not receipt_path.exists()
    shutil.copy2(CANAL_PACKAGE, checkpoint)
    checkpoint_hash = sha(checkpoint)
    disk_before_hash = sha(CANAL_PACKAGE)
    assert checkpoint_hash == previous['after_sha256'] == disk_before_hash

    report = dict(status='PREPARED', timestamp_utc=stamp,
                  receipt=str(receipt_path.relative_to(ROOT).as_posix()),
                  previous_receipt=str(previous_path.relative_to(ROOT).as_posix()),
                  previous_receipt_sha256=sha(previous_path),
                  target_package='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Canal',
                  source_world=source_world.get_path_name(), level_instance=instance.get_path_name(),
                  source_actor=actor.get_path_name(), script_class=SCRIPT_CLASS,
                  before_sha256=disk_before_hash, checkpoint=str(checkpoint.relative_to(ROOT).as_posix()),
                  checkpoint_sha256=checkpoint_hash, expected_before_sha256=previous['after_sha256'],
                  before_art_fields={field: serial(script.get_editor_property(field)) for field in ART_FIELDS},
                  candidate_art_fields=dict(WheelMeshOverride=MESH_PATH,
                                            WheelMeshLocalTransform=serial(transform),
                                            WheelMaterialOverride=None),
                  mechanism_before=before_mechanism, source_world_roster_before=before_snapshot,
                  collision_before=collision_before, protected_files_before=protected_before,
                  dirty_packages_before=dirty_before, auto_cook_setting_restored=False, saved=False,
                  allowed_delta='WheelMeshLocalTransform.translation: [0,0,0] -> [2.5,0,0] only',
                  save_api='UEditorLoadingAndSavingUtils.save_map(source_world, exact_Canal_package_path)')
    receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

    settings_class = u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    assert settings_class
    settings = u.get_default_object(settings_class)
    old_cook_setting = settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    assert hasattr(type(old_cook_setting), 'DISABLE'), 'Expected supported auto-cook DISABLE enum'
    actor.modify()
    script.modify()
    script.set_editor_property('WheelMeshLocalTransform', transform)
    assert asset_path(script.get_editor_property('WheelMeshOverride')) == MESH_PATH
    assert script.get_editor_property('WheelMaterialOverride') is None
    assert serial(script.get_editor_property('WheelMeshLocalTransform')) == serial(transform)
    assert mechanism_snapshot(actor, script) == before_mechanism
    dirty_pre_save = dirty_package_names()
    canal_package = '/Game/Mars/Maps/Variants/v8c/LI_Warrens_Canal'
    assert set(dirty_pre_save['maps']).issubset({canal_package}) and not dirty_pre_save['content'], (
        'Only the authorized Canal LI may be dirty before save', dirty_pre_save)
    report.update(status='BINDING_APPLIED_SAVE_PENDING', dirty_packages_before_save=dirty_pre_save)
    receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

    save_succeeded = False
    try:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(old_cook_setting).DISABLE)
        report['save_attempted'] = True
        receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        save_succeeded = u.EditorLoadingAndSavingUtils.save_map(
            source_world, '/Game/Mars/Maps/Variants/v8c/LI_Warrens_Canal')
    finally:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', old_cook_setting)
    assert settings.get_editor_property('_AutoCookStaticWorldOnLevelSave') == old_cook_setting
    if not save_succeeded:
        report.update(status='CANAL_OFFSET_SAVE_FAILED', after_sha256=sha(CANAL_PACKAGE), saved=False,
                      auto_cook_setting_restored=True, dirty_packages_after=dirty_package_names())
        receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        raise AssertionError('UEditorLoadingAndSavingUtils.save_map returned false for Canal offset stage')

    after_hash = sha(CANAL_PACKAGE)
    after_snapshot = source_world_snapshot(source_world, actor, script)
    collision_after = collision_guard()
    protected_after = protected_file_paths()
    canal_relative = CANAL_PACKAGE.relative_to(ROOT).as_posix()
    protected_changed = {relative: dict(before=before_hash, after=protected_after.get(relative))
                         for relative, before_hash in protected_before.items()
                         if relative != canal_relative and protected_after.get(relative) != before_hash}
    dirty_after = dirty_package_names()
    report.update(status='POST_SAVE_CHECKS_PENDING', after_sha256=after_hash, saved=True,
                  source_world_roster_after=after_snapshot, collision_after=collision_after,
                  protected_files_after=protected_after, protected_changes=protected_changed,
                  dirty_packages_after=dirty_after, auto_cook_setting_restored=True,
                  boundary='Only the checkpointed Canal Level Instance was saved; no Main, generated data, or library package was saved.')
    receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    assert after_hash != disk_before_hash, 'Canal bytes did not change; source-bound offset was not persisted'
    assert non_offset_visual_projection(after_snapshot) == non_offset_visual_projection(before_snapshot), (
        'Source roster or a field outside the approved local-X offset changed')
    assert asset_path(script.get_editor_property('WheelMeshOverride')) == MESH_PATH
    assert script.get_editor_property('WheelMaterialOverride') is None
    assert serial(script.get_editor_property('WheelMeshLocalTransform')) == serial(transform)
    assert collision_after == collision_before, 'Protected Jolt collision packages changed'
    assert not protected_changed, ('Unexpected non-Canal protected file change', protected_changed)
    assert set(dirty_after['maps']).issubset({canal_package}) and not dirty_after['content'], (
        'Unexpected dirty package after exact Canal save', dirty_after)
    report['status'] = 'STAGED_CANAL_OFFSET_SAVED'
    receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    _STATE = dict(actor=actor, script=script, old=None, before=before_mechanism,
                  candidate=dict(WheelMeshOverride=mesh, WheelMeshLocalTransform=transform,
                                 WheelMaterialOverride=None), receipt_path=receipt_path, staged_saved=True)
    print('P2_WHEEL_STAGED_OFFSET', json.dumps(dict(status=report['status'], before_sha256=disk_before_hash,
                                                    after_sha256=after_hash, checkpoint_sha256=checkpoint_hash,
                                                    actors=after_snapshot['actor_count'],
                                                    protected_files=len(protected_after), collision_files=collision_after['count'],
                                                    dirty_packages_after=dirty_after)))
    return report


def non_material_visual_projection(snapshot, candidate_material_path):
    """Ignore only the target wheel's reviewed material override."""
    projected = json.loads(json.dumps(snapshot))
    targets = [actor for actor in projected['actors'] if actor['label'] == ACTOR_LABEL]
    assert len(targets) == 1
    wheel_art = targets[0]['wheel_art']
    assert wheel_art['WheelMeshOverride'] == MESH_PATH + '.' + MESH_PATH.rsplit('/', 1)[1]
    assert wheel_art['WheelMeshLocalTransform']['location'] == [2.5, 0.0, 0.0]
    assert wheel_art['WheelMeshLocalTransform']['rotation_xyzw'] == [0.0, -0.0, 0.7071067690849304, 0.7071067690849304]
    assert wheel_art['WheelMeshLocalTransform']['scale'] == [1.0, 1.0, 1.0]
    assert wheel_art['WheelMaterialOverride'] in (None, candidate_material_path)
    wheel_art['WheelMaterialOverride'] = None
    return projected


def staged_material_preview(offsetreceiptpath, postverifypath):
    """Checkpoint the verified offset stage and save only the approved TX09 wheel material."""
    global _STATE
    expected_offset = (CHECKPOINT / 'p2_wheel_offset_staged_20261025T054034254658Z.json').resolve()
    expected_postverify = (CHECKPOINT / 'p2_wheel_offset_staged_20261025T054034254658Z_postverify.json').resolve()
    offset_path = Path(offsetreceiptpath).resolve()
    postverify_path = Path(postverifypath).resolve()
    assert offset_path == expected_offset and postverify_path == expected_postverify, (
        'Only the reviewed offset stage and its independent post-save verification may be chained')
    assert offset_path.is_file() and postverify_path.is_file()
    offset = json.loads(offset_path.read_text(encoding='utf-8'))
    postverify = json.loads(postverify_path.read_text(encoding='utf-8'))
    assert postverify['status'] == 'STAGED_OFFSET_POST_SAVE_VERIFIED'
    assert postverify['stage_receipt_sha256'] == sha(offset_path)
    assert Path(postverify['stage_receipt']).resolve() == offset_path
    assert postverify['after_sha256'] == '62613e784da33bf1db8afb6e44d1a9071c82b1df5632d1dd7cc8fa8cf8d217c9'
    assert postverify['only_delta'] == 'WheelMeshLocalTransform.translation [0,0,0] to [2.5,0,0]'
    assert (postverify['actors'], postverify['collision_count'], postverify['other_protected_unchanged']) == (50, 54, 19)
    assert not postverify['dirty']['maps'] and not postverify['dirty']['content']
    assert offset['status'] == 'POST_SAVE_CHECKS_PENDING'
    assert offset['after_sha256'] == postverify['after_sha256']
    assert offset['source_world_roster_after']['actor_count'] == 50
    assert offset['collision_after']['count'] == 54 and not offset['protected_changes']
    assert offset['previous_receipt'] == 'Saved/WarrensCGameplay-20261024/WheelArtCheckpoint/p2_wheel_staged_20261025T052524814606Z.json'
    previous_path = (ROOT / offset['previous_receipt']).resolve()
    assert previous_path.is_file() and sha(previous_path) == offset['previous_receipt_sha256']
    previous = json.loads(previous_path.read_text(encoding='utf-8'))
    assert previous['status'] == 'STAGED_CANAL_SAVED'
    assert previous['after_sha256'] == offset['before_sha256']
    assert sha(ROOT / previous['checkpoint']) == EXPECTED_CANAL_SHA
    assert offset['candidate_art_fields']['WheelMeshOverride'] == MESH_PATH
    assert offset['candidate_art_fields']['WheelMaterialOverride'] is None
    assert offset['candidate_art_fields']['WheelMeshLocalTransform']['location'] == [2.5, 0.0, 0.0]

    assert sha(offset_path) == postverify['stage_receipt_sha256']
    assert sha(CANAL_PACKAGE) == postverify['after_sha256'], 'Canal disk hash differs from independently verified offset stage'
    if _STATE is not None:
        assert _STATE.get('staged_saved') and Path(_STATE.get('receipt_path')).resolve() in (offset_path, expected_offset), (
            'An unsaved preview is active or staged state does not match the verified offset receipt')
    assert not ED.get_game_world(), 'Stop PIE before staged material save'
    main_world = ED.get_editor_world()
    assert main_world and main_world.get_path_name().split('.')[0] == EXPECTED_EDITOR_WORLD
    dirty_before = dirty_package_names()
    assert not dirty_before['maps'] and not dirty_before['content'], ('Packages are dirty before staged material', dirty_before)
    instance, source_world = canal_instance_source_world(main_world)
    assert source_world.get_path_name().split('.')[0] == CANAL_LEVEL_PREFIX.rstrip('.')
    actor, script = source_actor(main_world)
    assert actor.get_path_name() == offset['source_actor']
    assert script.get_class().get_name() == SCRIPT_CLASS
    assert hasattr(u.EditorLoadingAndSavingUtils, 'save_map'), 'UE map-specific SaveMap binding is unavailable'

    mesh = script.get_editor_property('WheelMeshOverride')
    material = script.get_editor_property('WheelMaterialOverride')
    current_transform = script.get_editor_property('WheelMeshLocalTransform')
    assert asset_path(mesh) == MESH_PATH and material is None
    assert serial(current_transform) == offset['candidate_art_fields']['WheelMeshLocalTransform']
    assert list(current_transform.translation.to_tuple()) == [2.5, 0.0, 0.0]
    before_mechanism = mechanism_snapshot(actor, script)
    assert before_mechanism == offset['mechanism_before']
    before_snapshot = source_world_snapshot(source_world, actor, script)
    assert before_snapshot == offset['source_world_roster_after'], 'Current source roster differs from verified offset stage'
    collision_before = collision_guard()
    assert collision_before == offset['collision_after']
    protected_before = protected_file_paths()
    assert protected_before == offset['protected_files_after']

    tx09 = u.load_asset(TX09_PATH)
    assert tx09 and asset_path(tx09) == TX09_PATH
    tx09_object_path = tx09.get_path_name()
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    checkpoint = CHECKPOINT / ('LI_Warrens_Canal.pre_wheel_material_' + stamp + '.umap')
    receipt_path = CHECKPOINT / ('p2_wheel_material_staged_' + stamp + '.json')
    assert not checkpoint.exists() and not receipt_path.exists()
    shutil.copy2(CANAL_PACKAGE, checkpoint)
    checkpoint_hash = sha(checkpoint)
    disk_before_hash = sha(CANAL_PACKAGE)
    assert checkpoint_hash == postverify['after_sha256'] == disk_before_hash

    report = dict(status='PREPARED', timestamp_utc=stamp,
                  receipt=str(receipt_path.relative_to(ROOT).as_posix()),
                  offset_receipt=str(offset_path.relative_to(ROOT).as_posix()),
                  offset_receipt_sha256=sha(offset_path),
                  offset_postverify_receipt=str(postverify_path.relative_to(ROOT).as_posix()),
                  offset_postverify_receipt_sha256=sha(postverify_path),
                  target_package='/Game/Mars/Maps/Variants/v8c/LI_Warrens_Canal',
                  source_world=source_world.get_path_name(), level_instance=instance.get_path_name(),
                  source_actor=actor.get_path_name(), script_class=SCRIPT_CLASS,
                  before_sha256=disk_before_hash, checkpoint=str(checkpoint.relative_to(ROOT).as_posix()),
                  checkpoint_sha256=checkpoint_hash, expected_before_sha256=postverify['after_sha256'],
                  before_art_fields={field: serial(script.get_editor_property(field)) for field in ART_FIELDS},
                  candidate_art_fields=dict(WheelMeshOverride=MESH_PATH,
                                            WheelMeshLocalTransform=serial(current_transform),
                                            WheelMaterialOverride=tx09_object_path),
                  mechanism_before=before_mechanism, source_world_roster_before=before_snapshot,
                  collision_before=collision_before, protected_files_before=protected_before,
                  dirty_packages_before=dirty_before, auto_cook_setting_restored=False, saved=False,
                  allowed_delta='WheelMaterialOverride: null -> ' + TX09_PATH,
                  save_api='UEditorLoadingAndSavingUtils.save_map(source_world, exact_Canal_package_path)')
    receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

    settings_class = u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    assert settings_class
    settings = u.get_default_object(settings_class)
    old_cook_setting = settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    assert hasattr(type(old_cook_setting), 'DISABLE'), 'Expected supported auto-cook DISABLE enum'
    actor.modify()
    script.modify()
    script.set_editor_property('WheelMaterialOverride', tx09)
    assert asset_path(script.get_editor_property('WheelMeshOverride')) == MESH_PATH
    assert serial(script.get_editor_property('WheelMeshLocalTransform')) == serial(current_transform)
    assert asset_path(script.get_editor_property('WheelMaterialOverride')) == TX09_PATH
    assert mechanism_snapshot(actor, script) == before_mechanism
    dirty_pre_save = dirty_package_names()
    canal_package = '/Game/Mars/Maps/Variants/v8c/LI_Warrens_Canal'
    assert set(dirty_pre_save['maps']).issubset({canal_package}) and not dirty_pre_save['content'], (
        'Only the authorized Canal LI may be dirty before save', dirty_pre_save)
    report.update(status='BINDING_APPLIED_SAVE_PENDING', dirty_packages_before_save=dirty_pre_save)
    receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

    save_succeeded = False
    try:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(old_cook_setting).DISABLE)
        report['save_attempted'] = True
        receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        save_succeeded = u.EditorLoadingAndSavingUtils.save_map(
            source_world, '/Game/Mars/Maps/Variants/v8c/LI_Warrens_Canal')
    finally:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', old_cook_setting)
    assert settings.get_editor_property('_AutoCookStaticWorldOnLevelSave') == old_cook_setting
    if not save_succeeded:
        report.update(status='CANAL_MATERIAL_SAVE_FAILED', after_sha256=sha(CANAL_PACKAGE), saved=False,
                      auto_cook_setting_restored=True, dirty_packages_after=dirty_package_names())
        receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        raise AssertionError('UEditorLoadingAndSavingUtils.save_map returned false for Canal material stage')

    after_hash = sha(CANAL_PACKAGE)
    after_snapshot = source_world_snapshot(source_world, actor, script)
    collision_after = collision_guard()
    protected_after = protected_file_paths()
    canal_relative = CANAL_PACKAGE.relative_to(ROOT).as_posix()
    protected_changed = {relative: dict(before=before_hash, after=protected_after.get(relative))
                         for relative, before_hash in protected_before.items()
                         if relative != canal_relative and protected_after.get(relative) != before_hash}
    dirty_after = dirty_package_names()
    report.update(status='POST_SAVE_CHECKS_PENDING', after_sha256=after_hash, saved=True,
                  source_world_roster_after=after_snapshot, collision_after=collision_after,
                  protected_files_after=protected_after, protected_changes=protected_changed,
                  dirty_packages_after=dirty_after, auto_cook_setting_restored=True,
                  boundary='Only the checkpointed Canal Level Instance was saved; no Main, generated data, or library package was saved.')
    receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    assert after_hash != disk_before_hash, 'Canal bytes did not change; source-bound material was not persisted'
    assert non_material_visual_projection(after_snapshot, tx09_object_path) == non_material_visual_projection(before_snapshot, tx09_object_path), (
        'Source roster or a field outside the approved wheel material changed')
    assert asset_path(script.get_editor_property('WheelMeshOverride')) == MESH_PATH
    assert serial(script.get_editor_property('WheelMeshLocalTransform')) == serial(current_transform)
    assert asset_path(script.get_editor_property('WheelMaterialOverride')) == TX09_PATH
    assert collision_after == collision_before, 'Protected Jolt collision packages changed'
    assert not protected_changed, ('Unexpected non-Canal protected file change', protected_changed)
    assert set(dirty_after['maps']).issubset({canal_package}) and not dirty_after['content'], (
        'Unexpected dirty package after exact Canal save', dirty_after)
    report['status'] = 'STAGED_CANAL_MATERIAL_SAVED'
    receipt_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    _STATE = dict(actor=actor, script=script, old=None, before=before_mechanism,
                  candidate=dict(WheelMeshOverride=mesh, WheelMeshLocalTransform=current_transform,
                                 WheelMaterialOverride=tx09), receipt_path=receipt_path, staged_saved=True)
    print('P2_WHEEL_STAGED_MATERIAL', json.dumps(dict(status=report['status'], before_sha256=disk_before_hash,
                                                      after_sha256=after_hash, checkpoint_sha256=checkpoint_hash,
                                                      actors=after_snapshot['actor_count'],
                                                      protected_files=len(protected_after), collision_files=collision_after['count'],
                                                      dirty_packages_after=dirty_after)))
    return report
