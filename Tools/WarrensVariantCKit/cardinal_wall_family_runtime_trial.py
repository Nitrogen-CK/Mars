"""Config-driven unsaved A/D PIE trial for one reviewed cardinal wall family.

The source Level Instance is untouched in the editor. Four NoCollision HISM
copies are staged in Main, admitted in PIE, then only the selected source rows
are removed in PIE before materials may be toggled. This module never saves,
loads, or discards a map; root owns explicit PIE stop and Main discard/reload.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
import types
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
CONFIG = ROOT / 'Saved/WarrensCGameplay-20261024/CellarWallTrial/config.json'
CONFIG_SHA256 = '0e2c0dbd220d3387dc58c7f6ed5306f030c86748ec77c9a7a2d00666ce34dbe0'
RUN = ROOT / 'Saved/WarrensCGameplay-20261024/CellarWallTrial'
CORE_FILE = HERE / 'bank_identity_unreal.py'
CORE_SHA256 = '4859e7ab71dc9e0a5d93b61511eb759ef741598af4821ba62df69cd8ee014619'
STATE_MODULE = '_mars_wvc_cardinal_wall_runtime_state'
MAIN_MAP = '/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'
COLLISION = ROOT / 'Saved/WarrensCGameplay-20261024/StartupCheckpoint/collision_hashes.json'


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def _write(kind, record):
    folder = RUN / 'receipts'
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / f'{kind}_{datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S_%fZ")}_{uuid.uuid4().hex[:8]}.json'
    assert not path.exists()
    data = dict(record, schema=1, created_utc=datetime.now(timezone.utc).isoformat(),
                tool_sha256=_sha(__file__), config_sha256=_sha(CONFIG))
    path.write_text(json.dumps(data, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    return dict(path=path.relative_to(ROOT).as_posix(), sha256=_sha(path), phase=data.get('phase'), status=data.get('status'))


def _state():
    if STATE_MODULE not in sys.modules:
        mod = types.ModuleType(STATE_MODULE)
        mod.active = None
        sys.modules[STATE_MODULE] = mod
    return sys.modules[STATE_MODULE]


def _load_module(name, path, expected):
    assert _sha(path) == expected, f'Pinned helper changed: {path.name}'
    if name not in sys.modules:
        spec = importlib.util.spec_from_file_location(name, path)
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules[name] = module
    return sys.modules[name]


def _core():
    return _load_module('_wvc_cellar_wall_identity_core', CORE_FILE, CORE_SHA256)


def _config():
    assert _sha(CONFIG) == CONFIG_SHA256, 'Cellar trial config changed; review again'
    c = _json(CONFIG)
    assert c.get('schema') == 1 and c.get('source_tile') == 'Brineworks' and c.get('source_room') == 'cellar'
    for rel, digest in c['inputs'].items():
        path = (ROOT / rel).resolve()
        assert path.is_relative_to(ROOT.resolve()) and path.is_file() and _sha(path) == digest, ('trial input drift', rel)
    return c


def _u():
    import unreal
    return unreal


def _package(obj):
    return obj.get_path_name().split('.')[0] if obj else None


def _dirty(u):
    return dict(maps=sorted(_package(x) for x in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()),
                content=sorted(_package(x) for x in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()))


def _editor(u, require_clean=True):
    subsystem=u.get_editor_subsystem(u.UnrealEditorSubsystem)
    world=subsystem.get_editor_world()
    assert world and _package(world)==MAIN_MAP,'Requires assembled Variant C Main editor world'
    assert subsystem.get_game_world() is None,'Stop PIE before this phase'
    dirty=_dirty(u)
    if require_clean: assert dirty==dict(maps=[],content=[]),('Editor is dirty',dirty)
    return world,dirty


def _settings(u):
    editor_cls=u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings')
    jolt_cls=u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    assert editor_cls and jolt_cls
    editor=u.get_default_object(editor_cls); jolt=u.get_default_object(jolt_cls)
    return dict(editor=editor,autosave=editor.get_editor_property('bAutoSaveEnable'),jolt=jolt,
                cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave'))


def _verify_guards(guards):
    assert isinstance(guards,dict) and len(guards)>=634
    for relative,digest in guards.items():
        path=(ROOT/relative).resolve()
        assert path.is_relative_to(ROOT.resolve()) and path.is_file() and _sha(path)==digest,('guard drift',relative)


def _collision_map(guards):
    rel=COLLISION.relative_to(ROOT).as_posix()
    assert rel in guards and _sha(COLLISION)==guards[rel]
    collision=_json(COLLISION)
    assert isinstance(collision,dict) and len(collision)==54
    for path,digest in collision.items(): assert _sha(ROOT/path)==digest,('collision guard drift',path)
    return collision


def _load_asset(u,path,digest):
    package=ROOT/('Content/'+path.removeprefix('/Game/')+'.uasset')
    assert package.is_file() and _sha(package)==digest,('owned asset changed',path)
    asset=u.load_asset(path)
    assert asset and _package(asset)==path
    return asset


def _snapshot(core, world):
    return core._hism_snapshot(world)[1]


def _all_geometry(core, snapshot):
    rows = [{'mesh': row['mesh'], 'pose': pose} for row in snapshot.values() for pose in row['instances']]
    rows.sort(key=_pose_key)
    return rows


def _pose_key(pose):
    return json.dumps(pose, sort_keys=True, separators=(',', ':'), allow_nan=False)


def _canonical_component(component):
    value = json.loads(json.dumps(component, sort_keys=True, allow_nan=False))
    for field in ('path', 'owner', 'level'):
        value.pop(field, None)
    value['instances'] = sorted(value['instances'], key=_pose_key)
    return value


def _semantic_rows(snapshot):
    return sorted((_canonical_component(row) for row in snapshot.values()), key=_pose_key)


def _assert_semantic(actual, expected, label):
    a, e = _semantic_rows(actual), _semantic_rows(expected)
    assert a == e, (label, 'semantic HISM multiset differs', len(a), len(e), _digest(a), _digest(e))


def _pose_equivalent(actual, expected):
    if sum((float(actual['at'][i]) - float(expected['at'][i])) ** 2 for i in range(3)) ** .5 >= .1:
        return False
    if sum((float(actual['scale'][i]) - float(expected['scale'][i])) ** 2 for i in range(3)) ** .5 >= .001:
        return False
    dot = abs(sum(float(actual['q'][i]) * float(expected['q'][i]) for i in range(4)))
    return dot >= 1.0 - 1e-7


def _source_actors(u, world, tile):
    actors = u.GameplayStatics.get_all_actors_of_class(world, u.Actor)
    marker = f'LI_Warrens_{tile}'
    return [actor for actor in actors if marker in actor.get_level().get_path_name()]


def _find_sources(u, core, world, config):
    actors, snapshot = core._hism_snapshot(world)
    tile_actors = _source_actors(u, world, config['source_tile'])
    assert tile_actors, 'Exact Brineworks source actors are absent from this world'
    found = {}
    for ident, spec in config['source_components'].items():
        matches = [(actor, comp) for actor in tile_actors if actor.get_actor_label() == spec['actor_label']
                   for comp in actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)]
        assert len(matches) == 1, ('source HISM must resolve exactly once in Brineworks', ident, len(matches))
        actor, component = matches[0]
        row = core._component(component)
        assert row['mesh'] and row['owner_label'] == spec['actor_label']
        assert component.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
        found[ident] = dict(actor=actor, component=component, row=row)
    return snapshot, found


def _catalog(config):
    selection = config['selection']
    selection_path = ROOT / selection['path']
    assert selection_path.is_file() and _sha(selection_path) == selection['sha256']
    selection_data = _json(selection_path)
    assert selection_data.get('status') == selection['status'] == 'SOURCE_SELECTION_REVIEW_REQUIRED'
    assert selection_data['summary']['selected_wall_instances'] == selection['count']
    assert selection_data['summary']['selected_pairs'] == selection['pairs']
    fit = _json(ROOT / config['fit_ledger']['path'])
    keys = selection_data['selected_source_keys']
    placements = fit['placements']
    assert tuple(float(x) for x in fit['pivots']['Brineworks']) == tuple(config['fit_ledger']['pivot'])
    assert len(keys) == config['trial']['selected_count'] == 88 and len(set(keys)) == 88
    rows = {k: placements[k] for k in keys}
    pair_members = set()
    pairs = []
    for key in sorted(keys):
        if key in pair_members:
            continue
        row = rows[key]
        if row.get('id') == 'CCS15':
            mate = key + 1
            veneer_key, backing_key = key, mate
        else:
            mate = key - 1
            veneer_key, backing_key = mate, key
        assert mate in rows
        veneer, backing = placements[veneer_key], placements[backing_key]
        assert veneer.get('id') == 'CCS15' and veneer.get('tile') == 'Brineworks'
        assert veneer.get('role') == config['source_components']['CCS15']['role']
        assert backing.get('id') == 'BACKING_TX01' and backing.get('tile') == 'Brineworks'
        assert backing.get('role') == config['source_components']['BACKING_TX01']['role']
        assert veneer.get('yaw') in (0, 90, 180, -90)
        axis = 0 if veneer['yaw'] in (90, -90) else 1
        pairs.append(dict(veneer_key=veneer_key, backing_key=backing_key, axis=axis))
        pair_members.update((veneer_key, backing_key))
    assert pair_members == set(keys) and len(pairs) == 44
    return fit, rows, pairs


def _matches(u, core, config, world, sources):
    fit, rows, pairs = _catalog(config)
    pivot = tuple(config['fit_ledger']['pivot'])
    transform = sources['CCS15']['actor'].get_level_transform()
    by_key = {}
    by_component = {ident: [] for ident in sources}
    axis_by_key = {p['veneer_key']: p['axis'] for p in pairs}
    axis_by_key.update({p['backing_key']: p['axis'] for p in pairs})
    for key, row in rows.items():
        ident = row['id']
        component = sources[ident]['component']
        wanted = core._row_transform(u, row, pivot, transform)
        found = [i for i in range(component.get_instance_count())
                 if core._near(component.get_instance_transform(i, world_space=True), wanted)]
        assert len(found) == 1, ('source placement missing/ambiguous', key, ident, found)
        index = found[0]
        assert index not in {item['index'] for item in by_component[ident]}, ('overlapping selected source rows', key)
        item = dict(source_key=key, ident=ident, axis=axis_by_key[key], index=index,
                    component_path=component.get_path_name(), world_pose=core._pose(
                        component.get_instance_transform(index, world_space=True)),
                    local_pose=core._pose(component.get_instance_transform(index, world_space=False)))
        by_key[key] = item
        by_component[ident].append(item)
    assert len(by_key) == 88
    return fit, rows, pairs, by_key, by_component


def _guard_data(path, digest, config):
    file = Path(path)
    if not file.is_absolute():
        file = ROOT / file
    file = file.resolve()
    assert file.is_relative_to((ROOT / 'Saved/WarrensCGameplay-20261024').resolve())
    assert file.is_file() and _sha(file) == digest
    data = _json(file)
    assert data.get('status') == config['guard_requirement']['status'] == 'RELOAD_AUDITED'
    guards = data.get('immutable_guards')
    assert isinstance(guards, dict) and len(guards) >= config['guard_requirement']['min_guard_count']
    _verify_guards(guards)
    collision = _collision_map(guards)
    map_rel = 'Content/Mars/Maps/Variants/v8c/LI_Warrens_Brineworks.umap'
    assert map_rel in guards and config['guard_requirement']['must_include_source_map']
    return file, data, guards, collision


def _asset_rows(config, guard_data):
    receipt_path = ROOT / config['asset_receipt']['path']
    rec = _json(receipt_path)
    assert rec.get('status') == config['asset_receipt']['status'] == 'THREE_OWNED_WALL_FAMILY_ASSETS_CREATED'
    for key in ('review','preview','selection'):
        assert rec['config'][key]['path']==config[key]['path']
        assert rec['config'][key]['sha256']==config[key]['sha256']
    assert rec['config']['image']['sha256']==config['inputs'][
        'docs/art/warrens-c-gameplay-review-20261024/lookdev/brineworks-painterly-r01/Cellar_PainterlyStone_Albedo_Plum_r01.png']
    assert len(rec['owned_assets']) == 3
    by_name = {Path(row['path']).name: row for row in rec['owned_assets']}
    assert set(by_name) == {'T_Cellar_Plum_R01_Albedo', 'MI_Cellar_Plum_R01_NormalX', 'MI_Cellar_Plum_R01_NormalY'}
    assert rec['reused_parent']['path'] == config['asset_receipt']['parent']
    assert rec['reused_parent']['package_sha256'] == config['asset_receipt']['parent_sha256']
    assert abs(float(rec['albedo_mix']) - .60) < 1e-6 and abs(float(rec['roughness']) - .88) < 1e-6
    for row in rec['owned_assets']:
        rel = 'Content/' + row['path'].removeprefix('/Game/') + '.uasset'
        path = ROOT / rel
        assert path.is_file() and _sha(path) == row['package_sha256']
        if rel in guard_data:
            assert guard_data[rel] == row['package_sha256'], ('candidate asset guard conflicts with owned asset receipt', rel)
    parent_rel='Content/'+rec['reused_parent']['path'].removeprefix('/Game/')+'.uasset'
    parent_path=ROOT/parent_rel
    assert parent_path.is_file() and _sha(parent_path)==rec['reused_parent']['package_sha256']
    if parent_rel in guard_data:
        assert guard_data[parent_rel]==rec['reused_parent']['package_sha256'],'shared Hall parent conflicts with fresh guard'
    assert rec['config']['normal_x']==by_name['MI_Cellar_Plum_R01_NormalX']['path']
    assert rec['config']['normal_y']==by_name['MI_Cellar_Plum_R01_NormalY']['path']
    return rec, {0: by_name['MI_Cellar_Plum_R01_NormalX'], 1: by_name['MI_Cellar_Plum_R01_NormalY']}, by_name['T_Cellar_Plum_R01_Albedo']


def _verify_asset_rows(rows):
    assert isinstance(rows, list) and len(rows) == 3 and len({row['path'] for row in rows}) == 3
    for row in rows:
        package = ROOT / ('Content/' + row['path'].removeprefix('/Game/') + '.uasset')
        assert package.is_file() and _sha(package) == row['package_sha256'], ('Cellar owned asset drift', row['path'])


def _verify_parent_asset(row):
    package=ROOT/('Content/'+row['path'].removeprefix('/Game/')+'.uasset')
    assert package.is_file() and _sha(package)==row['package_sha256'],('shared Hall parent drift',row['path'])


def _preflight_receipt(path, digest):
    file = Path(path)
    if not file.is_absolute():
        file = ROOT / file
    file = file.resolve()
    assert file.is_relative_to(RUN.resolve()) and file.is_file() and _sha(file) == digest
    data = _json(file)
    assert data.get('schema') == 1
    assert data.get('tool_sha256') == _sha(__file__) and data.get('config_sha256') == _sha(CONFIG)
    return file, data


def preflight(guard_receipt_path, guard_receipt_sha256):
    """Read-only check of live Main, exact Cellar placements, assets, and fresh guards."""
    c = _config()
    guard_file, guard_data, guards, collision = _guard_data(guard_receipt_path, guard_receipt_sha256, c)
    assets, materials, texture = _asset_rows(c, guards)
    u = _u()
    core = _core()
    world, dirty = _editor(u)
    before = _snapshot(core, world)
    sources_snapshot, sources = _find_sources(u, core, world, c)
    assert sources_snapshot == before
    fit, rows, pairs, matches, by_component = _matches(u, core, c, world, sources)
    trial_labels = c['trial']['groups']
    source_packages = sorted({_package(s['actor'].get_level().get_outermost()) for s in sources.values()})
    assert len(source_packages) == 1 and c['source_map'] in source_packages[0]
    map_rel = 'Content/Mars/Maps/Variants/v8c/LI_Warrens_Brineworks.umap'
    record = dict(phase='preflight', status='READ_ONLY_PREPARED', config=dict(path=CONFIG.relative_to(ROOT).as_posix(), sha256=_sha(CONFIG)),
        guard_receipt=dict(path=guard_file.relative_to(ROOT).as_posix(), sha256=guard_receipt_sha256,
            status=guard_data['status'], guard_count=len(guards), collision_count=len(collision)),
        source_map=c['source_map'], source_level_path=sources['CCS15']['actor'].get_level().get_path_name(),
        source_packages=source_packages, source_map_sha256=guards[map_rel], editor_dirty=dirty,
        before_hisms=before, before_hism_count=len(before), before_global_instance_count=len(_all_geometry(core,before)),
        before_global_geometry_sha256=_digest(_all_geometry(core,before)),
        selected_live_instances=[matches[k] for k in sorted(matches)],
        selected_by_source={k:v for k,v in by_component.items()},
        selected_source_count=len(matches), pair_count=len(pairs), pair_axes={str(a):sum(p['axis']==a for p in pairs) for a in (0,1)},
        source_components={ident:s['row'] for ident,s in sources.items()}, trial_labels=trial_labels,
        asset_receipt=dict(path=c['asset_receipt']['path'],sha256=c['asset_receipt']['sha256'],status=assets['status'],
            owned_assets=assets['owned_assets'],candidate_materials={str(a):r['path'] for a,r in materials.items()},
            candidate_package_hashes={str(a):r['package_sha256'] for a,r in materials.items()},
            parent_asset=dict(path=assets['reused_parent']['path'],package_sha256=assets['reused_parent']['package_sha256']),
            source_materials={ident:_package(s['component'].get_material(0)) for ident,s in sources.items()}),
        owned_asset_hashes={row['path']:row['package_sha256'] for row in assets['owned_assets']},
        immutable_guards=guards, collision_hashes=collision,
        expected_reported_dirty_maps=c['trial']['expected_dirty_maps'], expected_global_instance_count=len(_all_geometry(core,before)),
        map_saved=False)
    assert record['selected_source_count'] == 88 and all(record['pair_axes'].values())
    group_counts={(ident,axis):sum(item['ident']==ident and item['axis']==axis for item in matches.values())
                  for ident in c['source_components'] for axis in (0,1)}
    assert all(group_counts.values()), ('each of the four material partitions must be nonempty',group_counts)
    record['per_group_selected_counts']={f'{ident}:axis{axis}':count for (ident,axis),count in group_counts.items()}
    return _write('preflight', record)


def _resolve_receipt(path, digest, phase):
    file, data = _preflight_receipt(path, digest)
    assert data['phase'] == phase
    return file, data


def _spawn_group(u, world, source, selected, material, label, folder, owner):
    actor = u.get_editor_subsystem(u.EditorActorSubsystem).spawn_actor_from_class(u.Actor, u.Vector(), u.Rotator())
    assert actor and actor.get_world() == world and actor.get_level().get_outer() == world
    actor.set_actor_label(label)
    actor.tags = [u.Name(owner)]
    actor.set_folder_path(folder)
    actor.root_component.set_mobility(source.get_editor_property('mobility'))
    sub = u.get_engine_subsystem(u.SubobjectDataSubsystem)
    root = sub.k2_gather_subobject_data_for_instance(actor)[0]
    handle, reason = sub.add_new_subobject(u.AddNewSubobjectParams(parent_handle=root,
        new_class=u.HierarchicalInstancedStaticMeshComponent))
    comp = u.SubobjectDataBlueprintFunctionLibrary.get_associated_object(u.SubobjectDataBlueprintFunctionLibrary.get_data(handle))
    assert isinstance(comp, u.HierarchicalInstancedStaticMeshComponent), str(reason)
    comp.set_mobility(source.get_editor_property('mobility'))
    assert comp.set_static_mesh(source.static_mesh)
    comp.set_world_transform(source.get_world_transform(), False, True)
    comp.set_collision_profile_name(source.get_collision_profile_name())
    for field in ('generate_overlap_events','hidden_in_game','instancing_random_seed','instance_start_cull_distance',
                  'instance_end_cull_distance','num_custom_data_floats','body_instance'):
        comp.set_editor_property(field, source.get_editor_property(field))
    comp.set_cast_shadow(source.cast_shadow)
    comp.set_visibility(source.is_visible(), False)
    for slot, original in enumerate(source.get_materials()):
        comp.set_material(slot, material if slot == 0 else original)
    local = [source.get_instance_transform(item['index'], world_space=False) for item in selected]
    added = list(comp.add_instances(local, True, False, False))
    assert added == list(range(len(local)))
    comp.set_collision_enabled(u.CollisionEnabled.NO_COLLISION)
    assert comp.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
    return actor, comp


def _assert_trial_group(core, item, source_row):
    actor, component = item['actor'], item['component']
    label = item['label']
    assert actor.get_actor_label() == label
    assert sorted(str(tag) for tag in actor.tags) == [_config()['trial']['owner']]
    assert actor.get_editor_property('hidden') is False
    assert actor.root_component and actor.root_component.get_editor_property('mobility') == \
        item['source_component'].get_editor_property('mobility')
    actor_pose=core._pose(actor.get_actor_transform())
    assert actor_pose['at']==[0.0,0.0,0.0] and actor_pose['scale']==[1.0,1.0,1.0]
    assert actor_pose['q']==[0.0,0.0,0.0,1.0]
    assert component.get_editor_property('mobility')==item['source_component'].get_editor_property('mobility')
    expected = json.loads(json.dumps(source_row, sort_keys=True, allow_nan=False))
    expected['owner_label'] = label
    expected['materials'][0] = item['source_material_path']
    expected['instances'] = sorted((entry['world_pose'] for entry in item['selected']), key=_pose_key)
    actual = core._component(component)
    assert _canonical_component(actual) == _canonical_component(expected), \
        ('Trial component diverges from source beyond ownership/material-instance pose', label)


def _expected_duplicate_geometry(core, before, sources, selected):
    expected = _all_geometry(core, before)
    expected.extend({'mesh': sources[item['ident']]['row']['mesh'], 'pose': item['world_pose']} for item in selected)
    expected.sort(key=_pose_key)
    return expected


def stage(preflight_path, preflight_sha256):
    """Create four temporary Main HISM groups; leave Brineworks source untouched."""
    state = _state()
    assert state.active is None
    file, prior = _resolve_receipt(preflight_path, preflight_sha256, 'preflight')
    c = _config()
    u, core = _u(), _core()
    world, dirty = _editor(u)
    assert dirty == prior['editor_dirty'] == dict(maps=[], content=[])
    before, sources_snapshot = _snapshot(core, world), None
    _, sources = _find_sources(u, core, world, c)
    assert before == prior['before_hisms']
    settings = _settings(u)
    active = dict(stage='starting', world=world, pie_world=None, settings=settings,
        preflight=dict(path=file.relative_to(ROOT).as_posix(),sha256=preflight_sha256),
        original_snapshot=before, original_guards=prior['immutable_guards'],collision=prior['collision_hashes'],
        selections=prior['selected_live_instances'], source_components=sources, actors=[], components=[], created=[],
        candidate_material_paths={int(a):p for a,p in prior['asset_receipt']['candidate_materials'].items()},
        candidate_package_hashes={int(a):p for a,p in prior['asset_receipt']['candidate_package_hashes'].items()},
        owned_assets=prior['asset_receipt']['owned_assets'],parent_asset=prior['asset_receipt']['parent_asset'],
        phase_receipts=[dict(path=file.relative_to(ROOT).as_posix(),sha256=preflight_sha256)])
    state.active=active
    try:
        _verify_guards(active['original_guards']); _collision_map(active['original_guards'])
        _verify_asset_rows(active['owned_assets'])
        _verify_parent_asset(active['parent_asset'])
        loaded = {}
        for row in active['owned_assets']:
            loaded[row['path']] = _load_asset(u,row['path'],row['package_sha256'])
        axis_asset={0:loaded[active['candidate_material_paths'][0]],1:loaded[active['candidate_material_paths'][1]]}
        source_mats={ident:s['component'].get_material(0) for ident,s in sources.items()}
        active['source_materials_live']={f'WVC_CellarWall_{ident}_Axis{axis}_Trial':source_mats[ident]
            for ident in sources for axis in (0,1)}
        active['source_material_paths_live']={f'WVC_CellarWall_{ident}_Axis{axis}_Trial':
            prior['asset_receipt']['source_materials'][ident] for ident in sources for axis in (0,1)}
        active['materials']=axis_asset
        settings['editor'].set_editor_property('bAutoSaveEnable',False)
        settings['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave',type(settings['cook']).DISABLE)
        assert settings['editor'].get_editor_property('bAutoSaveEnable') is False
        assert settings['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave')==type(settings['cook']).DISABLE
        labels={(x['ident'],x['axis']):x['label'] for x in prior['trial_labels']}
        made=[]
        for ident,s in sources.items():
            for axis in (0,1):
                selected=[x for x in prior['selected_live_instances'] if x['ident']==ident and x['axis']==axis]
                if not selected: continue
                label=labels[(ident,axis)]
                actor,comp=_spawn_group(u,world,s['component'],selected,source_mats[ident],label,c['trial']['folder'],c['trial']['owner'])
                active['actors'].append(actor); active['components'].append(comp)
                made.append(dict(ident=ident,axis=axis,label=label,actor=actor,component=comp,selected=selected,
                    source_component=s['component'],source_material_path=prior['asset_receipt']['source_materials'][ident]))
        assert len(made)==4
        active['created']=made
        after=_snapshot(core,world)
        expected=json.loads(json.dumps(before))
        for item in made:
            _assert_trial_group(core,item,sources[item['ident']]['row'])
            row=core._component(item['component'])
            expected[item['component'].get_path_name()]=row
        _assert_semantic(after,expected,'Cellar editor duplicate stage')
        geo=_all_geometry(core,after)
        expected_geo=_expected_duplicate_geometry(core,before,sources,prior['selected_live_instances'])
        assert _digest(geo)==_digest(expected_geo) and len(geo)==prior['before_global_instance_count']+88
        dirty_now=_dirty(u)
        assert dirty_now['maps']==prior['expected_reported_dirty_maps'] and dirty_now['content']==[]
        _verify_guards(active['original_guards']); _collision_map(active['original_guards'])
        _verify_asset_rows(active['owned_assets']); _verify_parent_asset(active['parent_asset'])
        active['editor_expected']=after; active['stage']='editor_staged'
    except Exception as exc:
        result=_write('stage_failure',dict(phase='stage_failure',status='EDITOR_STAGE_FAILED_INSPECTION_REQUIRED',
            preflight=dict(path=file.relative_to(ROOT).as_posix(),sha256=preflight_sha256),error=repr(exc),
            dirty=_dirty(u),created_labels=[a.get_actor_label() for a in active['actors']],map_saved=False,
            recovery='Stop PIE if needed; prepare_failed_discard then root-owned discard/reload.'))
        active['stage']='stage_failure'; active['phase_receipts'].append(result); raise
    result=_write('editor_staged',dict(phase='editor_staged',status='FOUR_CELLAR_TRIAL_GROUPS_STAGED',
        preflight=dict(path=file.relative_to(ROOT).as_posix(),sha256=preflight_sha256),original_hism_count=len(before),
        editor_hism_count=len(after),selected_source_count=88,added_copies=88,
        global_instance_count=len(geo),global_geometry_sha256=_digest(geo),dirty=dirty_now,map_saved=False))
    active['phase_receipts'].append(result)
    return result


def _active_receipt(path,digest,phase):
    a=_state().active; assert a is not None
    f,d=_preflight_receipt(path,digest); assert d['phase']==phase
    assert d.get('tool_sha256')==_sha(__file__) and d.get('config_sha256')==_sha(CONFIG)
    return a,f,d


def _pie(u,config):
    game=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    assert game and 'Warrens_VariantC_Mars_MAP' in game.get_name()
    return game


def admit_pie(staged_path,staged_sha256):
    a,file,staged=_active_receipt(staged_path,staged_sha256,'editor_staged')
    u,core,c=_u(),_core(),_config(); game=None
    try:
        game=_pie(u,c); actual=_snapshot(core,game)
        _assert_semantic(actual,a['editor_expected'],'Cellar PIE duplicate admission')
        count=len(_all_geometry(core,actual)); prior=_json(ROOT/a['preflight']['path'])
        assert count==prior['before_global_instance_count']+88
        a['pie_world']=game; a['stage']='pie_admitted'; a['editor_duplicate_expected']=actual
        result=_write('pie_admitted',dict(phase='pie_admitted',status='PIE_MATCHES_EDITOR_DUPLICATE_ROSTER',
            staged_receipt=dict(path=file.relative_to(ROOT).as_posix(),sha256=staged_sha256),
            hism_count=len(actual),global_instance_count=count,saved=False))
        a['phase_receipts'].append(result); return result
    except Exception as exc:
        a['pie_world']=game; a['stage']='pie_admission_failure'
        result=_write('pie_admission_failure',dict(phase='pie_admission_failure',status='PIE_ADMISSION_FAILED_INSPECTION_REQUIRED',
            staged_receipt=dict(path=file.relative_to(ROOT).as_posix(),sha256=staged_sha256),error=repr(exc),saved=False,
            recovery='Stop PIE; prepare_failed_discard; root owns explicit discard/reload.'))
        a['phase_receipts'].append(result); raise


def _pie_sources(u,core,game,c):
    snap=_snapshot(core,game); actors=_source_actors(u,game,c['source_tile']); found={}
    for ident,spec in c['source_components'].items():
        matches=[(a,x) for a in actors if a.get_actor_label()==spec['actor_label']
                 for x in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)]
        assert len(matches)==1,(ident,len(matches))
        actor,comp=matches[0]; row=core._component(comp)
        assert row['collision_profile']=='NoCollision' and comp.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION
        found[ident]=dict(actor=actor,component=comp,row=row)
    return snap,found


def _partition_expected(core,original,source_paths,poses_by_ident):
    expected=json.loads(json.dumps(original))
    for ident,path in source_paths.items():
        keys=[k for k,row in expected.items() if row['path']==path]
        assert len(keys)==1,(ident,path,keys)
        row=expected[keys[0]]; remaining=list(row['instances'])
        for pose in poses_by_ident[ident]:
            found=[i for i,p in enumerate(remaining) if _pose_equivalent(p,pose)]
            assert len(found)==1,('selected source pose missing/ambiguous',ident,found)
            remaining.pop(found[0])
        row['instances']=remaining
    return expected


def partition_pie(admission_path,admission_sha256):
    a,file,_=_active_receipt(admission_path,admission_sha256,'pie_admitted')
    assert a['stage']=='pie_admitted'
    u,core,c=_u(),_core(),_config(); game=_pie(u,c)
    try:
        pre=_snapshot(core,game); _assert_semantic(pre,a['editor_duplicate_expected'],'pre-partition Cellar PIE')
        prior=_json(ROOT/a['preflight']['path']); _,rows,pairs,_,_= _matches_from_preflight(prior)
        _,sources=_pie_sources(u,core,game,c)
        pivot=tuple(c['fit_ledger']['pivot']); transform=sources['CCS15']['actor'].get_level_transform()
        grouped={ident:[] for ident in sources}; poses={ident:[] for ident in sources}; indexes={ident:[] for ident in sources}
        for item in prior['selected_live_instances']:
            row=rows[item['source_key']]; comp=sources[item['ident']]['component']
            wanted=core._row_transform(u,row,pivot,transform)
            found=[i for i in range(comp.get_instance_count()) if core._near(comp.get_instance_transform(i,world_space=True),wanted)]
            assert len(found)==1,('PIE source row rematch failure',item['source_key'],found)
            idx=found[0]; indexes[item['ident']].append(idx)
            poses[item['ident']].append(core._pose(comp.get_instance_transform(idx,world_space=True)))
            grouped[item['ident']].append(item)
        for ident, ids in indexes.items(): assert len(ids)==len(set(ids))
        paths={ident:s['component'].get_path_name() for ident,s in sources.items()}
        # All 88 unique source rows are proven before the first removal.
        a['stage']='partition_started'
        for ident,ids in indexes.items():
            comp=sources[ident]['component']; comp.modify()
            for idx in sorted(ids,reverse=True): assert comp.remove_instance(idx),(ident,idx)
        after=_snapshot(core,game)
        expected=_partition_expected(core,pre,paths,poses)
        _assert_semantic(after,expected,'partitioned Cellar PIE')
        geo=_all_geometry(core,after)
        assert len(geo)==prior['before_global_instance_count']
        assert _digest(geo)==prior['before_global_geometry_sha256'],'Partition changed global mesh/pose world'
        a['pie_partition_expected']=after; a['stage']='pie_partitioned_A'
        result=_write('pie_partitioned',dict(phase='pie_partitioned',status='PIE_CELLAR_SOURCE_PARTITION_ADMITTED',
            admission_receipt=dict(path=file.relative_to(ROOT).as_posix(),sha256=admission_sha256),
            removed_count=88,removed_by_component={k:len(v) for k,v in grouped.items()},
            hism_count=len(after),global_instance_count=len(geo),global_geometry_sha256=_digest(geo),saved=False))
        a['phase_receipts'].append(result); return result
    except Exception as exc:
        a['stage']='pie_partition_failure'
        result=_write('pie_partition_failure',dict(phase='pie_partition_failure',status='PIE_PARTITION_FAILED_INSPECTION_REQUIRED',
            admission_receipt=dict(path=file.relative_to(ROOT).as_posix(),sha256=admission_sha256),error=repr(exc),saved=False,
            recovery='Stop PIE immediately. No capture, toggle, or retry; use failed-discard path.'))
        a['phase_receipts'].append(result); raise


def _matches_from_preflight(prior):
    c=_config(); fit=_json(ROOT/c['fit_ledger']['path']); keys=[r['source_key'] for r in prior['selected_live_instances']]
    return fit,{k:fit['placements'][k] for k in keys},None,None,None


def _trial_labels(prior):
    return {x['label']:x for x in prior['trial_labels']}


def _expected_toggle(a,enabled):
    expected=json.loads(json.dumps(a['pie_partition_expected']))
    prior=_json(ROOT/a['preflight']['path']); labels=_trial_labels(prior)
    for row in expected.values():
        spec=labels.get(row['owner_label'])
        if spec:
            row['materials'][0]=a['candidate_material_paths'][spec['axis']] if enabled else a['source_material_paths_live'][row['owner_label']]
    return expected


def set_candidate(enabled,partition_path,partition_sha256):
    a,file,receipt=_active_receipt(partition_path,partition_sha256,'pie_partitioned')
    assert a['stage'] in ('pie_partitioned_A','pie_partitioned_D') and receipt['status']=='PIE_CELLAR_SOURCE_PARTITION_ADMITTED'
    u,core,c=_u(),_core(),_config(); game=_pie(u,c)
    before=_snapshot(core,game); _assert_semantic(before,_expected_toggle(a,a['stage']=='pie_partitioned_D'),'pre-toggle Cellar PIE')
    try:
        prior=_json(ROOT/a['preflight']['path']); labels=_trial_labels(prior)
        groups={}
        for actor in u.GameplayStatics.get_all_actors_of_class(game,u.Actor):
            if actor.get_actor_label() in labels:
                comps=actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
                assert len(comps)==1; groups[actor.get_actor_label()]=comps[0]
        assert set(groups)==set(labels)
        for label,spec in labels.items():
            path=a['candidate_material_paths'][spec['axis']] if enabled else a['source_material_paths_live'][label]
            material=u.load_asset(path); assert material and _package(material)==path
            groups[label].set_material(0,material)
        after=_snapshot(core,game); expected=_expected_toggle(a,bool(enabled))
        _assert_semantic(after,expected,'post-toggle Cellar PIE')
        a['stage']='pie_partitioned_D' if enabled else 'pie_partitioned_A'
        result=_write('pie_D' if enabled else 'pie_A_restore',dict(phase='pie_D' if enabled else 'pie_A_restore',
            status='FOUR_CELLAR_GROUPS_UPDATED' if enabled else 'CELLAR_STAGE_A_RESTORED',enabled=bool(enabled),
            semantic_sha256=_digest(_semantic_rows(after)),global_geometry_sha256=_digest(_all_geometry(core,after)),saved=False))
        a['phase_receipts'].append(result); return result
    except Exception as exc:
        a['stage']='candidate_failure'
        result=_write('candidate_failure',dict(phase='candidate_failure',status='PIE_CANDIDATE_SWITCH_FAILED_INSPECTION_REQUIRED',
            enabled=bool(enabled),error=repr(exc),saved=False,recovery='Stop PIE and use prepare_failed_discard; do not retry.'))
        a['phase_receipts'].append(result); raise


def prepare_exit_pie():
    a=_state().active; assert a and a['stage']=='pie_partitioned_A','Restore Stage A and verify partition before stopping PIE'
    u,core,c=_u(),_core(),_config(); game=_pie(u,c)
    now=_snapshot(core,game); _assert_semantic(now,a['pie_partition_expected'],'Cellar PIE Stage A before stop')
    geo=_all_geometry(core,now); prior=_json(ROOT/a['preflight']['path'])
    assert len(geo)==prior['before_global_instance_count'] and _digest(geo)==prior['before_global_geometry_sha256']
    result=_write('pie_exit_ready',dict(phase='pie_exit_ready',status='CELLAR_STAGE_A_READY_TO_STOP_PIE',
        global_instance_count=len(geo),global_geometry_sha256=_digest(geo),saved=False))
    a['stage']='pie_exit_ready'; a['phase_receipts'].append(result); return result


def _prepare_discard(failure_path=None,failure_sha256=None):
    a=_state().active; assert a is not None
    u,core=_u(),_core(); editor=u.get_editor_subsystem(u.UnrealEditorSubsystem)
    assert editor.get_game_world() is None,'Stop PIE before discard preparation'
    world,dirty=_editor(u,require_clean=False); assert world==a['world']
    current=_snapshot(core,world)
    expected=a.get('editor_expected')
    if expected is not None: _assert_semantic(current,expected,'Cellar editor staged state after PIE')
    else:
        labels={x['label'] for x in _json(ROOT/a['preflight']['path'])['trial_labels']}
        retained={path:row for path,row in current.items() if row['owner_label'] not in labels}
        _assert_semantic(retained,a['original_snapshot'],'Cellar original Main after partial stage failure')
        assert all(row['owner_label'] in labels for row in current.values() if row not in retained.values())
    prior=_json(ROOT/a['preflight']['path']); allowed=prior['expected_reported_dirty_maps']
    assert set(dirty['maps']).issubset(allowed) and dirty['content']==[],dirty
    _verify_guards(a['original_guards']); _collision_map(a['original_guards'])
    a['settings']['editor'].set_editor_property('bAutoSaveEnable',False)
    a['settings']['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave',type(a['settings']['cook']).DISABLE)
    assert a['settings']['editor'].get_editor_property('bAutoSaveEnable') is False
    assert a['settings']['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave')==type(a['settings']['cook']).DISABLE
    _verify_asset_rows(a['owned_assets']); _verify_parent_asset(a['parent_asset'])
    original=a['original_snapshot']; a['discard_expected_original']=original
    a['world']=a['pie_world']=a['actors']=a['components']=a['created']=a['source_components']=None
    a['materials']=a['source_materials_live']=a['source_material_paths_live']=a['editor_expected']=a['pie_partition_expected']=a['original_snapshot']=None
    a['stage']='ready_for_root_discard'
    result=_write('discard_ready',dict(phase='discard_ready',status='READY_FOR_EXPLICIT_MONOLITH_DISCARD',
        failure_receipt=dict(path=failure_path,sha256=failure_sha256) if failure_path else None,
        dirty=dirty,trial_maps=allowed,guards_verified=True,collision_count=len(a['collision']),map_saved=False,
        root_action='Use the approved Monolith load_level dirty_policy=discard wrapper; this helper never loads/discards.'))
    a['phase_receipts'].append(result); return result


def prepare_failed_discard(failure_path,failure_sha256):
    file=Path(failure_path)
    if not file.is_absolute(): file=ROOT/file
    file=file.resolve(); assert file.is_relative_to(RUN.resolve()) and _sha(file)==failure_sha256
    phase=_json(file).get('phase')
    assert phase in ('stage_failure','pie_admission_failure','pie_partition_failure','candidate_failure')
    return _prepare_discard(file.relative_to(ROOT).as_posix(),failure_sha256)


def prepare_discard(exit_path,exit_sha256):
    active,file,data=_active_receipt(exit_path,exit_sha256,'pie_exit_ready')
    return _prepare_discard(file.relative_to(ROOT).as_posix(),exit_sha256)


def after_root_discard_reload():
    a=_state().active; assert a and a['stage']=='ready_for_root_discard'
    u,core=_u(),_core(); world,dirty=_editor(u)
    current=_snapshot(core,world); _assert_semantic(current,a['discard_expected_original'],'Cellar Main after root discard/reload')
    _verify_guards(a['original_guards']); _collision_map(a['original_guards'])
    assert dirty==dict(maps=[],content=[])
    _verify_asset_rows(a['owned_assets'])
    _verify_parent_asset(a['parent_asset'])
    settings=a['settings']
    settings['editor'].set_editor_property('bAutoSaveEnable',settings['autosave'])
    settings['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave',settings['cook'])
    assert settings['editor'].get_editor_property('bAutoSaveEnable') == settings['autosave']
    assert settings['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave') == settings['cook']
    result=_write('after_discard_reload',dict(phase='after_discard_reload',status='ORIGINAL_CELLAR_MAIN_RESTORED',
        original_hism_count=len(current),global_instance_count=len(_all_geometry(core,current)),dirty=dirty,
        guards_verified=True,settings_restored=True))
    _state().active=None
    return result

