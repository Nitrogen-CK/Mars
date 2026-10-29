"""Narrow, repeatable Camp integration. Requires Camp already open and PIE stopped.

Uses existing placement seams, grouped persistent HISM visuals, and existing
persistent collision proxies. Saves only Camp; source Spire levels stay unchanged.
"""
import json
import math
import sys
from pathlib import Path
import unreal as u

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
MAP = '/Game/Mars/Maps/Camp_Mars_MAP'
OWNER = 'Mars.StewardService.v1'
PREFIX = 'StewardService_'
EA = u.get_editor_subsystem(u.EditorActorSubsystem)
ED = u.get_editor_subsystem(u.UnrealEditorSubsystem)
LES = u.get_editor_subsystem(u.LevelEditorSubsystem)


def at(x, y, z):
    return u.Vector(float(x), float(y), float(z))


def ensure_assembly(spire, rows, prefix, collision=False):
    expected = {}
    for row in rows:
        label = 'SP_' + prefix + '_' + row['layer'] + '_' + row['asset']
        expected.setdefault(label, []).append(row)
    current = [a for a in EA.get_all_level_actors()
               if a.get_actor_label().startswith('SP_' + prefix + '_')]
    if not current:
        spire.instances(rows, prefix, collision)
        current = [a for a in EA.get_all_level_actors()
                   if a.get_actor_label().startswith('SP_' + prefix + '_')]
    labels = [a.get_actor_label() for a in current]
    assert len(labels) == len(set(labels)), 'Duplicate assembly labels: ' + prefix
    assert len(current) == len(expected), 'Wrong group count: ' + prefix
    current = dict(zip(labels, current))
    assert set(current) == set(expected), 'Partial or foreign assembly: ' + prefix
    assets = {asset['id']: asset for asset in spire.manifest()['assets']}
    for label, placements in expected.items():
        value = current[label]
        assert spire.OWNER in [str(t) for t in value.tags], 'Foreign group: ' + label
        components = value.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        assert len(components) == 1, 'Wrong HISM component count: ' + label
        component = components[0]
        assert component.get_instance_count() == len(placements), 'Wrong instance count: ' + label
        mesh = u.load_asset(spire.DEST + '/Meshes/' + assets[placements[0]['asset']]['name'])
        assert isinstance(mesh, u.StaticMesh) and component.static_mesh == mesh, 'Wrong mesh: ' + label
        assert str(component.get_collision_profile_name()) == ('BlockAll' if collision else 'NoCollision'), 'Wrong collision profile: ' + label
        enabled = u.CollisionEnabled.QUERY_AND_PHYSICS if collision else u.CollisionEnabled.NO_COLLISION
        assert component.get_collision_enabled() == enabled, 'Wrong collision enabled: ' + label
        # Match instances() insertion order and world-space transforms. Tolerances match the kit's saved-map audit.
        for index, row in enumerate(placements):
            transform = component.get_instance_transform(index, world_space=True)
            assert transform is not None, f'Missing transform: {label}[{index}]'
            assert all(abs(actual - wanted) <= 0.1 for actual, wanted in
                       zip(transform.translation.to_tuple(), row['at_cm'])), f'Wrong translation: {label}[{index}]'
            rotation = transform.rotation.rotator()
            assert all(abs((actual - wanted + 180.0) % 360.0 - 180.0) <= 0.01 for actual, wanted in
                       ((rotation.pitch, 0.0), (rotation.yaw, row['yaw_deg']), (rotation.roll, 0.0))), f'Wrong rotation: {label}[{index}]'
            assert all(abs(actual - wanted) <= 0.001 for actual, wanted in
                       zip(transform.scale3d.to_tuple(), row['scale'])), f'Wrong scale: {label}[{index}]'


def actor(label, cls, point, yaw=0, factory=False):
    matches = [a for a in EA.get_all_level_actors() if a.get_actor_label() == PREFIX + label]
    assert len(matches) <= 1, label
    if matches:
        result = matches[0]
        assert OWNER in [str(t) for t in result.tags], 'Foreign actor: ' + label
    else:
        result = (EA.spawn_actor_from_object if factory else EA.spawn_actor_from_class)(cls, point, u.Rotator(yaw=yaw))
        assert result, label
        result.set_actor_label(PREFIX + label)
        result.tags = [u.Name(OWNER)]
        result.set_folder_path('StewardService')
    result.set_actor_location(point, False, True)
    result.set_actor_rotation(u.Rotator(yaw=yaw), False)
    return result


def open_camp_departure_seam(labels):
    # The saved camp's 4m end wall caps the surveyed east neck. Retain that
    # instance as a lintel rather than leaving a second barrier behind the gate.
    camp = labels['camp_chapel_open_Bellfold']
    components = [c for c in camp.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
                  if c.static_mesh and c.static_mesh.get_path_name() ==
                  '/Game/Mars/Environment/Meshes/Crypt/CryptWall4m_Mars_SM.CryptWall4m_Mars_SM']
    assert len(components) == 1, 'Expected the surveyed camp wall group'
    component = components[0]
    matches = []
    for index in range(component.get_instance_count()):
        transform = component.get_instance_transform(index, world_space=True)
        if (transform.translation - at(1640, -200, 0)).length() < .1 or (transform.translation - at(1640, -200, 360)).length() < .1:
            matches.append((index, transform))
    assert len(matches) == 1, 'Camp departure cap missing or duplicated'
    index, transform = matches[0]
    rotation = transform.rotation.rotator()
    assert abs(rotation.yaw - 90) < .01 and abs(rotation.pitch) < .01 and abs(rotation.roll) < .01
    assert (transform.scale3d - at(1, 1, 1)).length() < .001, 'Unexpected camp cap scale'
    if transform.translation.z < 1:
        camp.modify()
        component.modify()
        transform.translation = at(1640, -200, 360)
        assert component.update_instance_transform(index, transform, world_space=True,
                                                   mark_render_state_dirty=True, teleport=True)
    assert (component.get_instance_transform(index, world_space=True).translation - at(1640, -200, 360)).length() < .1


def replace_original_exit_overlays(labels):
    # Remove only the two surveyed overlays. The derived frame retains the original
    # stone trim/threshold but excludes the opaque panel and the permanent barred collider.
    camp = labels['camp_chapel_open_Bellfold']
    marker = OWNER + '.OpenOriginalArch'
    planned = []
    for mesh_name in ('CryptArchBarred2m4_Mars_SM', 'CryptExtractionArch_Mars_SM'):
        components = [c for c in camp.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
                      if c.static_mesh and c.static_mesh.get_name() == mesh_name]
        assert len(components) == 1, 'Original arch group missing/duplicated: ' + mesh_name
        component = components[0]
        if component.get_instance_count() == 0:
            assert marker in [str(tag) for tag in camp.tags], 'Foreign empty arch group: ' + mesh_name
            continue
        assert component.get_instance_count() == 1, 'Original arch group changed: ' + mesh_name
        transform = component.get_instance_transform(0, world_space=True)
        assert (transform.translation - at(1200, -200, 0)).length() < .1
        rotation = transform.rotation.rotator()
        assert abs(rotation.yaw - 90) < .01 and abs(rotation.pitch) < .01 and abs(rotation.roll) < .01
        assert (transform.scale3d - at(1, 1, 1)).length() < .001
        planned.append(component)
    # Validate both groups before modifying either, so foreign edits cannot cause a partial adaptation.
    for component in planned:
        camp.modify()
        component.modify()
        assert component.remove_instance(0), 'Failed to remove surveyed overlay'
    if marker not in [str(tag) for tag in camp.tags]:
        camp.tags = list(camp.tags) + [u.Name(marker)]
    frame = actor('CampArchTrim', u.StaticMeshActor, at(1200, -200, 0), 90)
    mesh = u.load_asset('/Game/Mars/Gameplay/Steward/Service/CampOpenArch_Mars_SM')
    assert mesh
    frame.static_mesh_component.set_static_mesh(mesh)
    frame.static_mesh_component.set_collision_profile_name('BlockAll')


def run():
    assert not ED.get_game_world(), 'Stop PIE'
    assert ED.get_editor_world().get_path_name().split('.')[0] == MAP, 'Open Camp first'
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages(), 'Save/review existing map dirt first'
    labels = {a.get_actor_label(): a for a in EA.get_all_level_actors()}
    required = ['Camp_BoardAnchor_Contracts', 'Camp_Cam_Contracts',
                'Camp_BoardAnchor_Departure', 'Camp_Cam_Departure']
    assert all(name in labels for name in required), required
    needed = ['/Game/Mars/Gameplay/Steward/Service/ServiceParchment_Mars_SM',
              '/Game/Mars/Gameplay/Steward/Anims/Steward_Present_Mars_AS',
              '/Game/Mars/UI/Widgets/Steward/ServiceParchment_Mars_WBP',
              '/Game/Mars/Gameplay/Steward/Service/CampOpenArch_Mars_SM',
              '/Game/Mars/Maps/Spire/LI_Spire_Hearthscrew_Mars_MAP']
    assert all(u.EditorAssetLibrary.does_asset_exist(p) for p in needed), needed
    steward_cls = u.load_class(None, '/Script/Angelscript.Mars_Steward_EntityScript')
    gate_cls = u.load_class(None, '/Script/Angelscript.Mars_CampMissionGate_EntityScript')
    assert steward_cls and gate_cls, 'Scripts must compile first'

    open_camp_departure_seam(labels)
    replace_original_exit_overlays(labels)

    # Keep the old contract alcove and move only its board endpoint to the held scroll.
    steward = actor('Steward', steward_cls, at(0, -1110, 0), 90, factory=True)
    script = steward.get_editor_property('_EntityScript')
    script.set_editor_property('PresentsServices', True)
    # Setting the spawner property notifies its editor preview rebuild, after instance tuning.
    steward.set_editor_property('_EntityScript', script)
    board = labels['Camp_BoardAnchor_Contracts']
    board.set_actor_location(at(0, -1054.75, 156), False, True)
    board.set_actor_rotation(u.Rotator(yaw=90), False)
    board.set_actor_scale3d(at(.095, .095, .095))
    board.set_editor_property('DrawSize', u.IntPoint(800, 900))
    camera = labels['Camp_Cam_Contracts']
    camera.set_actor_location(at(0, -865, 179), False, True)
    camera.set_actor_rotation(u.MathLibrary.find_look_at_rotation(camera.get_actor_location(), at(0, -1055, 179)), False)

    # New entrance is the surveyed end of the camp departure neck, not the old inner arch.
    sys.path.insert(0, str(ROOT / 'Tools/SpireConnectorKit'))
    import unreal_scenes as spire
    # Jolt's current world-cook sweep validates even noncolliding LI actors' transient
    # level keys. Persistent HISM groups preserve instancing and stable cook identity.
    old_connector = labels.get(PREFIX + 'Spire_Hearthscrew')
    if old_connector:
        assert OWNER in [str(t) for t in old_connector.tags]
        assert EA.destroy_actor(old_connector), 'Could not remove owned LI prototype'
    data = spire.manifest()
    ensure_assembly(spire, [spire.shifted(row, (1640, 0, 0), 0) for row in data['assemblies']['HS']], 'StewardVisual_HS')
    ensure_assembly(spire, [spire.shifted(row, (1640, 0, 0), 0) for row in data['collision_assemblies']['HS']], 'StableCollision_HS', True)
    # Keep the source kit's functional lamp positions with the instanced assembly.
    source_spec = json.loads((ROOT / 'Docs/design/spire-blender-handoff-20261026/spire_spec.json').read_text(encoding='utf-8'))
    hearthscrew = next(c for c in source_spec['concepts'] if c['id'] == 'HS')
    for prop in hearthscrew['prop_instances']:
        if prop['asset'] != 'P08':
            continue
        x, y, z = prop['local_origin_cm']
        angle = math.radians(prop['yaw_outward_deg'])
        lamp = actor('SpireLamp_' + prop['id'], u.PointLight,
                     at(1640 + x - 12 * math.cos(angle), y - 12 * math.sin(angle), z + 21))
        light = lamp.point_light_component
        light.set_mobility(u.ComponentMobility.MOVABLE)
        light.set_intensity(12)
        light.set_attenuation_radius(700)
        light.set_light_color(u.LinearColor(1, .62, .28, 1))
    gate = actor('MissionGate', gate_cls, at(1220, 0, 0), factory=True)
    gate_script = gate.get_editor_property('_EntityScript')
    gate_script.set_editor_property('SpawnTransform', gate.get_actor_transform())
    spec = gate_script.get_editor_property('Spec')
    opening = spec.get_editor_property('Opening')
    opening.set_editor_property('Width', 240)
    opening.set_editor_property('Height', 300)
    spec.set_editor_property('Opening', opening)
    bars = spec.get_editor_property('Bars')
    bars.set_editor_property('Count', 12)
    spec.set_editor_property('Bars', bars)
    look = spec.get_editor_property('Look')
    # Existing kit iron look; no new material system or shared edits.
    iron = '/Game/Mars/Environment/SpireConnectorKit/Materials/M_Spire_M05'
    assert u.EditorAssetLibrary.does_asset_exist(iron), iron
    look.set_editor_property('Material', u.load_asset(iron))
    spec.set_editor_property('Look', look)
    gate_script.set_editor_property('Spec', spec)
    gate.set_editor_property('_EntityScript', gate_script)

    # The existing departure UI now marks the lower exit. Its host confirmation keeps travel authoritative.
    departure = labels['Camp_BoardAnchor_Departure']
    departure.set_actor_location(at(3090, 0, -1040), False, True)
    departure.set_actor_rotation(u.Rotator(yaw=180), False)
    departure.set_actor_scale3d(at(.16, .16, .16))
    depcam = labels['Camp_Cam_Departure']
    depcam.set_actor_location(at(2810, 0, -1035), False, True)
    depcam.set_actor_rotation(u.Rotator(yaw=0), False)
    sign = actor('LowerExitSign', u.TextRenderActor, at(3090, 0, -990), 180)
    text = sign.get_component_by_class(u.TextRenderComponent)
    text.set_text('DEPART FOR SERVICE')
    text.set_world_size(18)
    text.set_horizontal_alignment(u.HorizTextAligment.EHTA_CENTER)
    text.set_text_render_color(u.Color(228, 207, 158, 255))
    text.set_collision_profile_name('NoCollision')

    # Camp ends at its departure post; the separate Warrens map is reached by
    # server travel. Close the kit's unused receiving edge beyond that post.
    exit_wall = actor('LowerExitBackWall', u.StaticMeshActor, at(3140, -200, -1200), 90)
    wall_mesh = u.load_asset('/Game/Mars/Environment/Meshes/Crypt/CryptWall4m_Mars_SM')
    assert wall_mesh
    exit_wall.static_mesh_component.set_static_mesh(wall_mesh)
    exit_wall.static_mesh_component.set_collision_profile_name('BlockAll')

    # Warm light for the reading surface, independent of inherited camp exposure.
    lamp = actor('ReadingLight', u.PointLight, at(0, -905, 225))
    lamp.point_light_component.set_mobility(u.ComponentMobility.MOVABLE)
    lamp.point_light_component.set_intensity(4)
    lamp.point_light_component.set_attenuation_radius(380)
    lamp.point_light_component.set_light_color(u.LinearColor(1, .83, .61, 1))
    lamp.point_light_component.set_cast_shadows(False)

    # Normal save invokes the project's static Jolt cook for this stable persistent map.
    assert LES.save_current_level()
    rows = [dict(label=a.get_actor_label(), cls=a.get_class().get_name(),
                 at=list(a.get_actor_location().to_tuple()))
            for a in EA.get_all_level_actors()
            if a.get_actor_label().startswith(PREFIX) or a.get_actor_label().startswith(('SP_StableCollision_HS_', 'SP_StewardVisual_HS_'))]
    report = dict(map=MAP, placed=rows, count=len(rows), source_level=needed[-1])
    (HERE / 'Output/placement_report.json').write_text(json.dumps(report, indent=2))
    print('STEWARD_CAMP_PLACED', MAP, 'owned groups:', len(rows))
    return report


if __name__ == '__main__':
    run()
