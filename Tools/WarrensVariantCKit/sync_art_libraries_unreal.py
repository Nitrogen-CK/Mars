"""Guarded incremental static review-map adapter. No import-time mutation.

Requires explicit load, preflight, exact reviewed package SHA, then apply.
Gameplay LIs, imports, mesh data, collision cooks and existing lights are excluded.
"""
from collections import Counter, defaultdict
import importlib.util
import json
from pathlib import Path
import re
import shutil
import unreal as u
import sync_art_libraries as data

ROOT = data.ROOT
HERE = data.HERE
RUN = data.RUN_ROOT / 'unreal-v2'
OWNER = data.OWNER
OLD_OWNER = 'Mars.WarrensVariantCKit.Authoring.v1'
MILL_OWNER = 'Mars.WarrensC.LayoutArt.20261024'
MAPS = {k: '/Game/Mars/Environment/WarrensVariantCKit/Maps/WarrensVariantC_' + k + '_Mars_MAP'
        for k in ('Diorama', 'KitLibrary')}
EA = u.get_editor_subsystem(u.EditorActorSubsystem)
ED = u.get_editor_subsystem(u.UnrealEditorSubsystem)


def asset(value):
    return value.get_path_name().split('.')[0] if value else None


def disk(target):
    return ROOT / ('Content/' + MAPS[target].removeprefix('/Game/') + '.umap')


def tags(actor):
    return [str(t) for t in actor.tags]


def context(target):
    assert target in MAPS and ED.get_game_world() is None
    assert ED.get_editor_world().get_path_name().split('.')[0] == MAPS[target]
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
    assert not u.EditorLoadingAndSavingUtils.get_dirty_content_packages()


def transform(value):
    # Quantization is below0.01cm/0.00001 scale, for deterministic roster comparison.
    return dict(at=[round(v, 4) for v in value.translation.to_tuple()],
                q=[round(v, 7) for v in (value.rotation.x, value.rotation.y, value.rotation.z, value.rotation.w)],
                scale=[round(v, 6) for v in value.scale3d.to_tuple()])


def ordered(values):
    return sorted(values, key=lambda value: json.dumps(value, sort_keys=True))


def roster(exclude_sync=True):
    result = {}
    for actor in EA.get_all_level_actors():
        if exclude_sync and OWNER in tags(actor):
            continue
        record = dict(label=actor.get_actor_label(), type=actor.get_class().get_path_name(), tags=tags(actor),
                      pose=transform(actor.get_actor_transform()), hidden=actor.hidden, components={})
        for c in actor.get_components_by_class(u.StaticMeshComponent):
            item = dict(mesh=asset(c.static_mesh), materials=[asset(m) for m in c.get_materials()],
                        collision=str(c.get_collision_profile_name()), overlap=c.get_editor_property('generate_overlap_events'),
                        shadow=c.cast_shadow, visible=c.is_visible(), pose=transform(c.get_world_transform()))
            if isinstance(c, u.HierarchicalInstancedStaticMeshComponent):
                item['instances'] = ordered([transform(c.get_instance_transform(i, world_space=True)) for i in range(c.get_instance_count())])
            record['components'][c.get_name()] = item
        for c in actor.get_components_by_class(u.LightComponent):
            color = c.light_color
            record.setdefault('lights', {})[c.get_name()] = dict(intensity=c.intensity, color=[color.r, color.g, color.b, color.a],
                radius=c.attenuation_radius if hasattr(c, 'attenuation_radius') else None, shadow=c.cast_shadows,
                pose=transform(c.get_world_transform()))
        for c in actor.get_components_by_class(u.CameraComponent):
            record.setdefault('cameras', {})[c.get_name()] = dict(fov=c.field_of_view, pose=transform(c.get_world_transform()))
        assert actor.get_name() not in result
        result[actor.get_name()] = record
    return result


def receipt_roster(value):
    """Read old receipts by exact color channels, excluding repr memory addresses.

    Historical receipt bytes stay intact. No other comparison field is relaxed.
    """
    result = json.loads(json.dumps(value))
    pattern = r"<Struct 'Color' \(0x[0-9A-Fa-f]+\) \{b: (\d+), g: (\d+), r: (\d+), a: (\d+)\}>"
    for actor in result.values():
        for light in actor.get('lights', {}).values():
            color = light['color']
            if isinstance(color, str):
                matched = re.fullmatch(pattern, color)
                assert matched, 'Unexpected legacy color representation'
                b, g, r, a = map(int, matched.groups())
                light['color'] = [r, g, b, a]
            assert len(light['color']) == 4 and all(type(c) is int and 0 <= c <= 255 for c in light['color'])
    return result


def registry(projection):
    paths = {}
    for kit in ('ChainCrossingKit', 'PumpCisternKit', 'WarrensVariantCKit'):
        for row in data.read(HERE.parent / kit / 'Output/asset_manifest.json')['assets']:
            paths[row['id']] = '/Game/Mars/Environment/' + kit + '/Meshes/' + row['name']
    for key in ('TX01', 'TX02', 'TX04', 'TX17'):
        paths['BACKING_' + key] = '/Engine/BasicShapes/Cube'
    paths.update(SOURCE_CUBE_TX01='/Engine/BasicShapes/Cube', SOURCE_CUBE_TX02='/Engine/BasicShapes/Cube')
    for row in projection['base']['placements'] + [r for _, r in projection['additions']]:
        if row.get('mesh_id'):
            paths[row['id']] = paths[row['mesh_id']]
    for row in data.read(HERE / 'P2SlidingSpan/Output/asset_manifest.json')['assets']:
        paths[row['id']] = '/Game/Mars/Environment/WarrensVariantCKit/P2SlidingSpan/' + row['name']
    return paths


def materials(row, mesh):
    expected = [asset(mesh.get_material(i)) for i in range(len(mesh.static_materials))]
    override = row.get('material_path') or ('/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_' + row['material'] if row.get('material') else None)
    if override:
        assert u.load_asset(override), override
        expected[0] = override
    return expected


def expected_pose(row, pivot=(58, 55, 0)):
    at = u.Vector(*[(row['at'][i] - pivot[i]) * 100 for i in range(3)])
    p, y, r = row.get('rotation', (0, row.get('yaw', 0), 0))
    return at, u.Rotator(pitch=p, yaw=y, roll=r).quaternion(), u.Vector(*row['scale'])


def match(row, component, pivot=(58, 55, 0)):
    at, rotation, scale = expected_pose(row, pivot)
    return [i for i in range(component.get_instance_count())
            if (component.get_instance_transform(i, world_space=True).translation - at).length() < .1
            and (component.get_instance_transform(i, world_space=True).scale3d - scale).length() < .001
            and component.get_instance_transform(i, world_space=True).rotation.angular_distance(rotation) < .001]


def prepared(target):
    context(target)
    projection = data.projection()
    paths = registry(projection)
    latest = data.read(ROOT / ('Saved/WarrensCGameplay-20261024/ArtCheckpoint/applied_' + target + '.json'))
    assert latest['after_sha256'] == data.sha(disk(target)), 'Review map changed after approved Mill receipt'
    actors = EA.get_all_level_actors()
    assert all(set(tags(a)) & {OLD_OWNER, MILL_OWNER} for a in actors), 'Unexpected review-map owner'
    original_count = sum(c.get_instance_count() for a in actors if OLD_OWNER in tags(a)
                         for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent))
    assert original_count == (32343 if target == 'Diorama' else 196)
    mill = [a for a in actors if MILL_OWNER in tags(a)]
    assert sum(c.get_instance_count() for a in mill for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)) == (1 if target == 'Diorama' else 2)
    hopper = next(a for a in mill if a.get_actor_label() == 'WVC_LayoutArt_WVC062')
    component, = hopper.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
    mill_row = next(r for k, r in projection['additions'] if k == 'mill_hopper')
    if target == 'Diorama':
        assert match(mill_row, component) == [0], 'Corrected Mill hopper pose missing'
    else:
        local = dict(mill_row, at=[60, 0, mill_row['at'][2] - 5])
        assert match(local, component, (0, 0, 0)) == [0]
    assert str(component.get_collision_profile_name()) == 'NoCollision'
    removals = defaultdict(set)
    if target == 'Diorama':
        by_label = defaultdict(list)
        for a in actors:
            by_label[a.get_actor_label()].append(a)
        old = dict(projection['old'])
        for index in projection['removals']:
            row = old[index]
            actor, = by_label['WVC_' + row['id']]
            assert OLD_OWNER in tags(actor)
            c, = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
            mesh = u.load_asset(paths[row['id']])
            assert asset(c.static_mesh) == asset(mesh)
            assert [asset(m) for m in c.get_materials()] == materials(row, mesh)
            assert str(c.get_collision_profile_name()) == 'NoCollision'
            found = match(row, c)
            assert len(found) == 1 and found[0] not in removals[c], ('Ambiguous old row', index, found)
            removals[c].add(found[0])
        additions = [(k, r) for k, r in projection['additions'] if k != 'mill_hopper']
        assert len(additions) == 516
    else:
        additions = [('card_' + key, dict(id=key, at=[80 + 14 * i, 0, 0], scale=[1, 1, 1], yaw=0,
                      role='Supplemental isolated moving-mesh display; not a gameplay owner'))
                     for i, key in enumerate(('P2S01', 'P2S02', 'P2S03'))]
    for _, row in additions:
        mesh = u.load_asset(paths[row['id']])
        assert isinstance(mesh, u.StaticMesh)
        materials(row, mesh)
    return projection, paths, removals, additions


def preflight(target):
    context(target)
    receipt_path = RUN / (target + '.json')
    if receipt_path.exists():
        r = data.read(receipt_path)
        assert r['status'] == 'APPLIED' and r['after_sha256'] == data.sha(disk(target))
        assert r['spec_sha256'] == data.projection()['spec_sha256']
        assert roster() == receipt_roster(r['unchanged_roster']), 'Existing review content changed'
        assert sync_roster() == r['sync_roster'], 'Synced display changed'
        return dict(already_applied=True, package_sha256=r['after_sha256'], operations=0)
    projection, _, removals, additions = prepared(target)
    return dict(already_applied=False, package_sha256=data.sha(disk(target)),
                removed=sum(len(v) for v in removals.values()), added=len(additions), spec_sha256=projection['spec_sha256'])


def sync_roster():
    all_rows = roster(False)
    return {a.get_name(): all_rows[a.get_name()] for a in EA.get_all_level_actors() if OWNER in tags(a)}


def audit_new(target, additions, aliases, grouped, shadowless):
    expected = defaultdict(list)
    for row in grouped:
        at, q, scale = expected_pose(row, (58, 55, 0) if target == 'Diorama' else (0, 0, 0))
        p, y, r = row.get('rotation', (0, row.get('yaw', 0), 0))
        expected[row['id']].append(transform(u.Transform(location=at, rotation=u.Rotator(pitch=p, yaw=y, roll=r), scale=scale)))
    actual = {}
    for actor in EA.get_all_level_actors():
        if OWNER not in tags(actor):
            continue
        alias = actor.get_actor_label().removeprefix('WVC_ArtSync_')
        assert alias in expected and alias not in actual
        c, = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        assert asset(c.static_mesh) == aliases[alias]
        row = next(r for r in grouped if r['id'] == alias)
        assert [asset(m) for m in c.get_materials()] == materials(row, c.static_mesh)
        assert c.cast_shadow == (alias not in shadowless)
        assert str(c.get_collision_profile_name()) == 'NoCollision' and not c.get_editor_property('generate_overlap_events')
        actual[alias] = ordered([transform(c.get_instance_transform(i, world_space=True)) for i in range(c.get_instance_count())])
    assert actual == {k: ordered(v) for k, v in expected.items()}, 'New instance identities/poses differ'
    assert sum(len(v) for v in actual.values()) == len(additions)


def apply(target, reviewed_sha):
    report = preflight(target)
    assert report['package_sha256'] == reviewed_sha
    if report['already_applied']:
        return report
    projection, paths, removals, additions = prepared(target)
    guard = data.immutable_files()
    before = roster()
    expected = json.loads(json.dumps(before))
    for component, indices in removals.items():
        entry = expected[component.get_owner().get_name()]['components'][component.get_name()]
        entry['instances'] = ordered([transform(component.get_instance_transform(i, world_space=True))
                                      for i in range(component.get_instance_count()) if i not in indices])
    RUN.mkdir(parents=True, exist_ok=True)
    backup = RUN / (target + '.umap')
    journal = RUN / (target + '.json')
    assert not backup.exists() and not journal.exists()
    shutil.copy2(disk(target), backup)
    assert data.sha(backup) == reviewed_sha
    report.update(status='PREPARED', before_sha256=reviewed_sha, backup=str(backup.relative_to(ROOT)),
                  tool_sha256=data.sha(Path(__file__)), source_spec=projection['spec_sha256'])
    journal.write_text(json.dumps(report, indent=2) + '\n')
    try:
        for c, indices in removals.items():
            c.modify()
            for i in sorted(indices, reverse=True):
                assert c.remove_instance(i)
        spec = importlib.util.spec_from_file_location('art_sync_core', HERE.parent / 'ChainCrossingKit/unreal_scenes.py')
        core = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(core)
        core.OWNER, core.PREFIX, core.FOLDER = OWNER, 'WVC_ArtSync_', 'Warrens/ApprovedArtSync'
        grouped, aliases, shadowless = [], {}, set()
        for semantic, row in additions:
            mesh = u.load_asset(paths[row['id']])
            signature = (paths[row['id']], tuple(materials(row, mesh)), row['id'].startswith('BACKING') or row['id'] == 'CCS61')
            alias = 'G_' + data.digest(signature)[:16]
            aliases[alias] = paths[row['id']]
            grouped.append(dict(row, id=alias))
            if signature[2]:
                shadowless.add(alias)
        counts = core.add_instances(grouped, (58, 55, 0) if target == 'Diorama' else (0, 0, 0), True,
                                    aliases, '/Game/Mars/Environment/ChainCrossingKit')
        for a in EA.get_all_level_actors():
            if OWNER in tags(a) and a.get_actor_label().removeprefix(core.PREFIX) in shadowless:
                for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent):
                    c.set_cast_shadow(False)
        audit_new(target, additions, aliases, grouped, shadowless)
        assert roster() == expected, 'Unapproved existing actor/component/light/camera change'
        # immutable_files excludes review-map packages, includes original Blends/FBX/imported meshes/collision.
        assert data.immutable_files() == guard
        from apply_art_delta import collision_guard
        collision_guard()
        settings = u.get_default_object(u.load_class(None, '/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'))
        original = settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
        try:
            settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', type(original).DISABLE)
            assert u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
        finally:
            settings.set_editor_property('_AutoCookStaticWorldOnLevelSave', original)
        assert roster() == expected and data.immutable_files() == guard
        audit_new(target, additions, aliases, grouped, shadowless)
        assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
        report.update(status='APPLIED', after_sha256=data.sha(disk(target)), spec_sha256=projection['spec_sha256'],
                      unchanged_roster=expected, sync_roster=sync_roster(), collision_files_preserved=54,
                      added_instances=sum(counts.values()), original_catalog_instances=196,
                      presentation_policy=projection['presentation_policy'], context_dependent_omissions=projection['omitted'],
                      light_operations_metadata_only=projection['lights'], p4='Live mechanism references only; no static replica',
                      boundary=projection['boundary'])
        journal.write_text(json.dumps(report, indent=2) + '\n')
        return {k: v for k, v in report.items() if k not in ('unchanged_roster', 'sync_roster')}
    except Exception as error:
        report.update(status='FAILED_REVIEW_REQUIRED', error=str(error))
        journal.write_text(json.dumps(report, indent=2) + '\n')
        raise
