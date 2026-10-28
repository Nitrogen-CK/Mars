"""Prepared, NOT executed: P2 fixture-only stage 1, practical-light-only stage 2.

Root must review P2_READABILITY_PREVIEW.html, use a guarded external level load,
and inspect preflight() before apply(). This module never switches levels,
imports assets, recooks geometry, saves Main/config, or runs save-all.

First capture_mechanism() in Canal and capture_light_template() in Brineworks.
Their caches contain values only, no cross-level UObject references. Then use
preflight(tile, stage) and pass its package_sha256 explicitly to apply().
After an exception stop: discard unsaved changes, or close Unreal and restore
the exact per-stage checkpoint if a save completed. Do not rerun over dirt.
"""
import ast
import hashlib
import importlib.util
import json
import shutil
from pathlib import Path

import unreal as u

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RUN = ROOT / 'Saved/WarrensCGameplay-20261024/P2ReadabilityCheckpoint'
DELTA = HERE / 'readability_delta.json'
DELTA_SHA = '0d8487879ffb413e1ed9d1289126bc2ea1f76191b4f1ef414d40b32ffc8d13c0'
SECTION_AST_SHA = 'db202505cfea04611e53448b13fefdba49cabdee0de6e8c1de0958f74a9212da'
OWNER = 'Mars.WarrensC.P2Readability.Candidate.v1'
P2_OWNER = 'Mars.WarrensC.P2SlidingSpan.20261024'
PREFIX = 'WVC_P2Readable_'
MAPS = {tile: '/Game/Mars/Maps/Variants/v8c/LI_Warrens_' + suffix for tile, suffix in
        [('Canal', 'Canal'), ('WaterworksW', 'WaterworksW'), ('Brineworks', 'Brineworks')]}
EA = u.get_editor_subsystem(u.EditorActorSubsystem)
ED = u.get_editor_subsystem(u.UnrealEditorSubsystem)
LES = u.get_editor_subsystem(u.LevelEditorSubsystem)
_MECHANISM = None
_TEMPLATE = None
_TEMPLATE_RAW = None
LIGHT_PROPERTIES = ('intensity', 'attenuation_radius', 'intensity_units', 'use_inverse_squared_falloff',
                    'cast_shadows', 'source_radius', 'source_length', 'light_color', 'mobility')


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def disk(tile):
    return ROOT / ('Content/' + MAPS[tile].removeprefix('/Game/') + '.umap')


def tags(actor):
    return [str(tag) for tag in actor.tags]


def serial(value):
    if isinstance(value, (str, bool, int, float)) or value is None:
        return value
    return value.export_text() if hasattr(value, 'export_text') else str(value)


def asset_path(value):
    return value.get_path_name().split('.')[0] if value else None


def pose(actor):
    return [list(actor.get_actor_location().to_tuple()), list(actor.get_actor_rotation().to_tuple()),
            list(actor.get_actor_scale3d().to_tuple())]


def position(at, pivot):
    return u.Vector(*[(at[i] - pivot[i]) * 100 for i in range(3)])


def same_transform(transform, at, scale=(1, 1, 1), rotation=(0, 0, 0)):
    q = u.Rotator(pitch=rotation[0], yaw=rotation[1], roll=rotation[2]).quaternion()
    return ((transform.translation - at).length() < .1
            and (transform.scale3d - u.Vector(*scale)).length() < .001
            and transform.rotation.angular_distance(q) < .001)


def clean_context(tile):
    assert tile in MAPS, tile
    assert ED.get_game_world() is None, 'Stop PIE before authoring'
    assert ED.get_editor_world().get_path_name().split('.')[0] == MAPS[tile], 'Guarded load ' + MAPS[tile]
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages(), 'Unsaved maps'
    assert not u.EditorLoadingAndSavingUtils.get_dirty_content_packages(), 'Unsaved content'


def collision_guard():
    baseline = read(ROOT / 'Saved/WarrensCGameplay-20261024/StartupCheckpoint/collision_hashes.json')
    assert len(baseline) == 54, 'Reviewed collision roster has 54 files'
    directories = (ROOT / 'Content/CkJoltData/Mars/Maps/Warrens_VariantC_Mars_MAP',
                   ROOT / 'Content/CkJoltData/Mars/Maps/Variants/v8c')
    current = {p.relative_to(ROOT).as_posix() for directory in directories for p in directory.rglob('*') if p.is_file()}
    assert current == set(baseline), 'Collision file roster changed'
    for relative, expected in baseline.items():
        assert sha(ROOT / relative) == expected, 'Collision bytes changed: ' + relative
    return baseline


def contract():
    assert sha(DELTA) == DELTA_SHA, 'Readability specification changed; re-review candidate'
    data = read(DELTA)
    # P4 may change later. Pin only the actual P2 SECTION_OVERRIDES expression,
    # not the whole C design file or unrelated map receipts/camera evidence.
    source = ROOT / 'Tools/LevelDesign/anchor_plans/design_warrens_v8c.py'
    node = next(n for n in ast.parse(source.read_text(encoding='utf-8-sig')).body if isinstance(n, ast.Assign)
                and any(isinstance(t, ast.Name) and t.id == 'SECTION_OVERRIDES' for t in n.targets))
    assert hashlib.sha256(ast.dump(node.value, include_attributes=False).encode()).hexdigest() == SECTION_AST_SHA
    skip = {'Tools/LevelDesign/anchor_plans/design_warrens_v8c.py'}
    for path, expected in data['source_guards'].items():
        if path in skip or path.startswith('Saved/') or path.endswith('.png'):
            continue
        assert sha(ROOT / path) == expected, 'P2 source changed: ' + path
    assert len(data['placements']) == 11 and len(data['lights']) == 4
    assert all(row['collision_profile'] == 'NoCollision' and row['material_override'] is None for row in data['placements'])
    assert all(not hits for hits in data['clearance_checks']['intersection_keys'].values())
    return data


def actors_by_label(label):
    return [actor for actor in EA.get_all_level_actors() if actor.get_actor_label() == label]


def bridge_snapshot(data):
    owners = actors_by_label('WVC_P2_SlidingSpan')
    assert len(owners) == 1 and P2_OWNER in tags(owners[0]), 'Exact P2 owner missing/duplicated'
    actor = owners[0]
    pivot = data['coordinate_contract']['tile_pivots_m']['Canal']
    wanted = position([79, 20, -2.2], pivot)
    assert (actor.get_actor_location() - wanted).length() < .1
    assert (actor.get_actor_scale3d() - u.Vector(1, 1, 1)).length() < .0001
    assert actor.get_actor_rotation().quaternion().angular_distance(u.Rotator(yaw=90).quaternion()) < .001
    script = actor.get_editor_property('_EntityScript')
    assert script.get_class().get_name() == 'Mars_SlidingBridge_EntityScript', 'No class-name fallback'
    bridge = script.get_editor_property('Bridge')
    scalars = dict(DeckLength=1050, DeckWidth=250, DeckThickness=20, Travel=1050, CageHeight=220,
                   CageWallThickness=10, CanopyThickness=8, TurnsToExtend=3, MoveDuration=1.5,
                   GuardWidth=230, GuardHeight=220, GuardThickness=8, GuardRaise=220, GuardMoveDuration=.8)
    for name, expected in scalars.items():
        assert abs(bridge.get_editor_property(name) - expected) < .0001, name
    assert same_transform(bridge.get_editor_property('WheelOffset'), u.Vector(-800, -4300, -30), rotation=(0, -180, 0))
    for name, expected in [('NearGuardOffset', (0, -1100, -30)), ('FarGuardOffset', (0, 1085, -30))]:
        assert (bridge.get_editor_property(name) - u.Vector(*expected)).length() < .001, name
    path = bridge.get_editor_property('DrivePath')
    expected = [u.Vector((y - 20) * 100, (79 - x) * 100, -22)
                for x, y in [(122, 12), (122, 15), (112, 16), (104, 19), (96, 20), (90, 20)]]
    assert len(path) == len(expected) and all((a - b).length() < .001 for a, b in zip(path, expected))
    for name, ident in [('DeckMeshOverride', 'P2S01_Deck'), ('CageMeshOverride', 'P2S02_Cage'), ('GuardMeshOverride', 'P2S03_Guard')]:
        expected_asset = '/Game/Mars/Environment/WarrensVariantCKit/P2SlidingSpan/WarrensC_' + ident + '_Mars_SM'
        assert asset_path(script.get_editor_property(name)) == expected_asset, name
    assert asset_path(script.get_editor_property('MaterialOverride')) == '/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX09'
    return dict(actor=actor.get_path_name(), pose=pose(actor), bridge=bridge.export_text(),
                source=serial(script.get_editor_property('Source')))


def capture_mechanism():
    """Read-only; call in guarded, clean Canal before visiting the other LIs."""
    global _MECHANISM
    clean_context('Canal')
    _MECHANISM = dict(package_sha256=sha(disk('Canal')), snapshot=bridge_snapshot(contract()))
    return _MECHANISM


def light_values(component):
    return {name: serial(component.get_editor_property(name)) for name in LIGHT_PROPERTIES}


def capture_light_template():
    """Read-only; capture scalar/enum/Color values before unloading Brineworks."""
    global _TEMPLATE, _TEMPLATE_RAW
    clean_context('Brineworks')
    contract()
    actor = chain_light()
    component = actor.point_light_component
    assert (component.get_editor_property('intensity'), component.get_editor_property('attenuation_radius')) in ((18, 550), (24, 600))
    assert component.get_editor_property('ies_texture') is None
    assert component.get_editor_property('light_function_material') is None
    names = ('intensity_units', 'use_inverse_squared_falloff', 'cast_shadows', 'source_radius', 'source_length')
    _TEMPLATE_RAW = {name: component.get_editor_property(name) for name in names}
    _TEMPLATE = dict(actor=actor.get_path_name(), properties={name: serial(value) for name, value in _TEMPLATE_RAW.items()})
    return _TEMPLATE


def chain_light():
    matches = actors_by_label('WVC_Practical_54')
    assert len(matches) == 1 and isinstance(matches[0], u.PointLight)
    actor = matches[0]
    assert 'Mars.WarrensVariantCKit.Authoring.v1' in tags(actor)
    at = position([109.78, 13.5, -.8], [88, 4, -2.5])
    assert (actor.get_actor_location() - at).length() < .1
    return actor


def asset_bounds_check(data):
    catalog = {row['id']: row for row in read(ROOT / 'Tools/ChainCrossingKit/Output/asset_manifest.json')['assets']}
    for ident in {row['mesh_id'] for row in data['placements']}:
        row = next(r for r in data['placements'] if r['mesh_id'] == ident)
        mesh = u.load_asset(row['mesh'])
        assert isinstance(mesh, u.StaticMesh), row['mesh']
        bounds = mesh.get_bounding_box()
        source = catalog[ident]
        # FBX import mirrors Blender Y. These four reused assets have symmetric
        # XY bounds; retain the general mirror formula rather than assuming it.
        lo = [source['bounds_min_cm'][0], -source['bounds_max_cm'][1], source['bounds_min_cm'][2]]
        hi = [source['bounds_max_cm'][0], -source['bounds_min_cm'][1], source['bounds_max_cm'][2]]
        assert all(abs(a - b) < .1 for a, b in zip(bounds.min.to_tuple(), lo)), ('Imported bounds changed', ident)
        assert all(abs(a - b) < .1 for a, b in zip(bounds.max.to_tuple(), hi)), ('Imported bounds changed', ident)


def primitive_roster(exclude_new=True, normalize_chain_light=False):
    """Existing actor/component/material/instance/light evidence, before vs after."""
    result = []
    for actor in EA.get_all_level_actors():
        if exclude_new and OWNER in tags(actor):
            continue
        item = dict(path=actor.get_path_name(), label=actor.get_actor_label(), cls=actor.get_class().get_path_name(),
                    pose=pose(actor), tags=tags(actor), meshes=[])
        for component in actor.get_components_by_class(u.StaticMeshComponent):
            mesh = dict(name=component.get_name(), asset=asset_path(component.get_editor_property('static_mesh')),
                        collision=str(component.get_collision_profile_name()),
                        materials=[asset_path(component.get_material(i)) for i in range(component.get_num_materials())],
                        relative=[serial(component.get_editor_property(name)) for name in
                                  ('relative_location', 'relative_rotation', 'relative_scale3d')])
            if isinstance(component, u.InstancedStaticMeshComponent):
                mesh['instances'] = [component.get_instance_transform(i, world_space=True).export_text()
                                     for i in range(component.get_instance_count())]
            item['meshes'].append(mesh)
        if isinstance(actor, u.PointLight):
            item['light'] = light_values(actor.point_light_component)
            if normalize_chain_light and actor.get_actor_label() == 'WVC_Practical_54':
                for name in ('intensity', 'attenuation_radius'):
                    item['light'].pop(name)
        result.append(item)
    return sorted(result, key=lambda row: row['path'])


def support_check(tile, data):
    if tile not in ('Canal', 'WaterworksW'):
        return
    center, size = ([68.175, 21.475, -.2], [1.65, .25, 4.6]) if tile == 'WaterworksW' else ([86.75, 21.475, -.2], [18.5, .25, 4.6])
    wanted = position(center, data['coordinate_contract']['tile_pivots_m'][tile])
    hits = []
    for actor in EA.get_all_level_actors():
        for component in actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent):
            if str(component.get_collision_profile_name()) == 'NoCollision':
                continue
            if asset_path(component.get_editor_property('static_mesh')) != '/Engine/BasicShapes/Cube':
                continue
            for index in range(component.get_instance_count()):
                if same_transform(component.get_instance_transform(index, world_space=True), wanted, size):
                    hits.append([actor.get_path_name(), component.get_name(), index])
    assert len(hits) == 1, ('Fixed source support mismatch', tile, hits)


def owned_fixtures(tile, data):
    expected = {row['mesh_id']: row for row in data['placements'] if row['tile'] == tile}
    actors = [a for a in EA.get_all_level_actors() if OWNER in tags(a) and not isinstance(a, u.PointLight)]
    assert len(actors) == len(expected), 'Unexpected/missing owned fixture groups'
    remaining = dict(expected)
    pivot = data['coordinate_contract']['tile_pivots_m'][tile]
    for actor in actors:
        assert actor.get_actor_label().startswith(PREFIX + 'Fixture_')
        components = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        assert len(components) == 1
        component = components[0]
        ident = actor.get_actor_label().removeprefix(PREFIX + 'Fixture_')
        assert ident in remaining
        row = remaining.pop(ident)
        assert str(component.get_collision_profile_name()) == 'NoCollision'
        assert not component.get_editor_property('generate_overlap_events')
        assert asset_path(component.get_editor_property('static_mesh')) == row['mesh']
        assert component.get_instance_count() == 1
        assert same_transform(component.get_instance_transform(0, world_space=True), position(row['at_plan_m'], pivot),
                              row['scale'], row['rotation_pitch_yaw_roll'])
    assert not remaining


def preflight(tile, stage):
    """Read-only report; caller reviews and supplies this exact SHA to apply()."""
    clean_context(tile)
    assert stage in (1, 2)
    data = contract()
    collision_guard()
    assert _MECHANISM and _MECHANISM['package_sha256'] == sha(disk('Canal')), 'Capture current Canal mechanism first'
    if tile == 'Canal':
        assert bridge_snapshot(data) == _MECHANISM['snapshot']
    assert _TEMPLATE_RAW and _TEMPLATE, 'Capture Brineworks light template first'
    support_check(tile, data)
    asset_bounds_check(data)
    receipts = RUN / ('stage' + str(stage) + '_' + tile + '.json')
    if receipts.exists():
        previous = read(receipts)
        assert previous['status'] == 'APPLIED' and previous['after_sha256'] == sha(disk(tile))
        assert previous['delta_sha256'] == DELTA_SHA
        owned_fixtures(tile, data)
        return dict(already_applied=True, package_sha256=sha(disk(tile)), receipt=str(receipts))
    if stage == 1:
        assert not any(OWNER in tags(actor) for actor in EA.get_all_level_actors()), 'Unrecorded owned actors'
    else:
        previous = read(RUN / ('stage1_' + tile + '.json'))
        assert previous['status'] == 'APPLIED' and previous['after_sha256'] == sha(disk(tile)), 'Stage 1 missing or changed'
        owned_fixtures(tile, data)
        assert not any(OWNER in tags(a) and isinstance(a, u.PointLight) for a in EA.get_all_level_actors())
        if tile == 'Brineworks':
            actor = chain_light()
            assert actor.point_light_component.get_editor_property('intensity') == 18
            assert actor.point_light_component.get_editor_property('attenuation_radius') == 550
            assert {name: serial(actor.point_light_component.get_editor_property(name)) for name in _TEMPLATE_RAW} == _TEMPLATE['properties']
    return dict(already_applied=False, tile=tile, stage=stage, package=MAPS[tile], package_sha256=sha(disk(tile)),
                delta_sha256=DELTA_SHA, mechanism=_MECHANISM, light_template=_TEMPLATE,
                collision_files_preserved=54,
                fixture_rows=sum(row['tile'] == tile for row in data['placements']) if stage == 1 else 0,
                added_lights=1 if stage == 2 else 0, modified_lights=1 if stage == 2 and tile == 'Brineworks' else 0)


def checkpoint(tile, stage, before, report):
    destination = RUN / ('stage' + str(stage)) / disk(tile).relative_to(ROOT)
    assert not destination.exists(), 'Checkpoint already exists without an applied receipt; inspect failed attempt'
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(disk(tile), destination)
    assert sha(destination) == before
    journal = RUN / ('stage' + str(stage) + '_' + tile + '.json')
    report.update(status='PREPARED', before_sha256=before, backup=destination.relative_to(ROOT).as_posix(),
                  applier_sha256=sha(Path(__file__)))
    journal.write_text(json.dumps(report, indent=2) + '\n')
    return journal


def save_visual_only():
    settings = u.get_default_object(u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'))
    previous = settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    try:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(previous).DISABLE)
        assert LES.save_current_level(), 'Exact current LI save failed'
    finally:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', previous)
    assert settings.get_editor_property('_AutoCookStaticWorldOnLevelSave') == previous


def apply(tile, stage, reviewed_package_sha256):
    """Mutating entry point, NOT invoked by importing this module or by this task."""
    global _MECHANISM
    report = preflight(tile, stage)
    assert report['package_sha256'] == reviewed_package_sha256, 'Current package differs from reviewed preflight'
    if report['already_applied']:
        return read(Path(report['receipt']))
    data = contract()
    baseline = primitive_roster(normalize_chain_light=(stage == 2 and tile == 'Brineworks'))
    report['existing_roster_sha256'] = hashlib.sha256(json.dumps(baseline, sort_keys=True).encode()).hexdigest()
    journal = checkpoint(tile, stage, reviewed_package_sha256, report)
    pivot = data['coordinate_contract']['tile_pivots_m'][tile]
    try:
        if stage == 1:
            spec = importlib.util.spec_from_file_location('p2_readability_core', HERE.parents[1] / 'ChainCrossingKit/unreal_scenes.py')
            core = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(core)
            core.OWNER = OWNER
            core.PREFIX = PREFIX + 'Fixture_'
            core.FOLDER = 'Warrens/LayoutArt/P2Readability'
            rows = [dict(id=r['mesh_id'], at=r['at_plan_m'], scale=r['scale'], rotation=r['rotation_pitch_yaw_roll'])
                    for r in data['placements'] if r['tile'] == tile]
            registry = {r['mesh_id']: r['mesh'] for r in data['placements']}
            counts = core.add_instances(rows, pivot, True, registry, '/Game/Mars/Environment/ChainCrossingKit')
            report['added_fixture_instances'] = sum(counts.values())
            owned_fixtures(tile, data)
        else:
            row = next(r for r in data['lights'] if r['operation'] == 'add_point_light' and r['tile'] == tile)
            actor = EA.spawn_actor_from_class(u.PointLight, position(row['at_plan_m'], pivot), u.Rotator())
            assert actor
            actor.set_actor_label(PREFIX + row['key'])
            actor.tags = [u.Name(OWNER)]
            actor.set_folder_path('Warrens/LayoutArt/P2Readability')
            component = actor.point_light_component
            for name, value in _TEMPLATE_RAW.items():
                component.set_editor_property(name, value)
            component.set_mobility(u.ComponentMobility.MOVABLE)
            component.set_intensity(row['intensity'])
            component.set_attenuation_radius(row['attenuation_radius_cm'])
            component.set_light_color(u.LinearColor(*row['linear_color'], 1))
            report['added_light'] = dict(actor=actor.get_actor_label(), properties=light_values(component))
            if tile == 'Brineworks':
                existing = chain_light()
                existing.modify()
                existing.point_light_component.modify()
                report['modified_light_before'] = light_values(existing.point_light_component)
                existing.point_light_component.set_intensity(24)
                existing.point_light_component.set_attenuation_radius(600)
                report['modified_light_after'] = light_values(existing.point_light_component)
            owned_fixtures(tile, data)
        assert primitive_roster(normalize_chain_light=(stage == 2 and tile == 'Brineworks')) == baseline, 'Existing actor/geometry/material/other-light roster changed'
        if tile == 'Canal':
            assert bridge_snapshot(data) == _MECHANISM['snapshot'], 'P2 composition changed'
        collision_guard()
        save_visual_only()
        collision_guard()
        assert primitive_roster(normalize_chain_light=(stage == 2 and tile == 'Brineworks')) == baseline
        assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
        assert not u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
        report.update(status='APPLIED', after_sha256=sha(disk(tile)), collision_files_preserved=54,
                      auto_cook_setting_restored=True, boundary='Saved static visual candidate only; runtime lighting/traversal not accepted.')
        if tile == 'Canal':
            _MECHANISM['package_sha256'] = report['after_sha256']
        journal.write_text(json.dumps(report, indent=2) + '\n')
        return report
    except Exception as error:
        report.update(status='FAILED_REVIEW_REQUIRED', error=str(error), disk_sha256_now=sha(disk(tile)),
                      rollback='Do not retry. Discard unsaved map changes or close editor and restore this stage backup after reviewing the disk SHA.')
        journal.write_text(json.dumps(report, indent=2) + '\n')
        raise


if __name__ == '__main__':
    raise RuntimeError('Review P2_READABILITY_PREVIEW.html; use explicit preflight/apply from guarded editor Python. Nothing auto-applies.')
