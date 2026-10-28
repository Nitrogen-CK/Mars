"""Fail-closed configured source-LI adoption for reviewed static wall families.

This is a config-driven source-LI adoption helper. Import is inert; it never
opens or unloads maps. Saving is limited to the already-open source LI and is
gated by an exact, later runtime-approval receipt in config.
"""
from __future__ import annotations

import copy
from collections import Counter
import hashlib
import importlib.util
import json
import shutil
import sys
import types
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
CONFIG = None
CONFIG_SPEC_SHA256 = None
BASE_FILE = HERE / 'cardinal_wall_family_persistent.py'
BASE_SHA256 = '6efebdb2b3fcb5cdea9aeded6cc0253a6ab40fc2cc4e0ebe965df11ce7233273'
CORE_FILE = HERE / 'bank_identity_unreal.py'
CORE_SHA256 = '4859e7ab71dc9e0a5d93b61511eb759ef741598af4821ba62df69cd8ee014619'
STATE_MODULE = '_mars_wvc_configured_wall_adoption_state'


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def _digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def _config_spec_digest(config):
    spec = {key: value for key, value in config.items() if key not in ('enabled', 'approval')}
    return _digest(spec)


def _run_dir(config=None):
    config = config or _json(CONFIG)
    path = (ROOT / config['run_directory']).resolve()
    assert path.is_relative_to(ROOT.resolve())
    return path


def _write(kind, payload):
    folder = _run_dir() / 'receipts'
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / f'{kind}_{datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S_%fZ")}_{uuid.uuid4().hex[:8]}.json'
    assert not path.exists()
    c = _json(CONFIG)
    value = dict(payload, schema=1, created_utc=datetime.now(timezone.utc).isoformat(),
                 tool_sha256=_sha(__file__), config_sha256=_sha(CONFIG),
                 config_spec_sha256=_config_spec_digest(c))
    path.write_text(json.dumps(value, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    return dict(file=path.relative_to(ROOT).as_posix(), sha256=_sha(path), phase=value.get('phase'), status=value.get('status'))


def _state():
    if STATE_MODULE not in sys.modules:
        module = types.ModuleType(STATE_MODULE)
        module.data = None
        sys.modules[STATE_MODULE] = module
    return sys.modules[STATE_MODULE]


def _module(name, path, expected):
    assert _sha(path) == expected, f'Pinned generic helper changed: {path.name}'
    if name not in sys.modules:
        spec = importlib.util.spec_from_file_location(name, path)
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sys.modules[name] = module
    return sys.modules[name]


def _base():
    return _module('_mars_wvc_wall_adoption_generic_persistent', BASE_FILE, BASE_SHA256)


def _core():
    return _module('_mars_wvc_wall_adoption_generic_identity', CORE_FILE, CORE_SHA256)


def configure(path, digest):
    """Bind one reviewed family before any native source preflight or mutation."""
    global CONFIG, CONFIG_SPEC_SHA256
    assert CONFIG is None and _state().data is None
    file = (ROOT / path).resolve()
    assert file.is_relative_to((ROOT / 'Saved/WarrensCGameplay-20261024').resolve())
    assert file.is_file() and _sha(file) == digest
    c = _json(file)
    assert c['tool_sha256'] == _sha(__file__)
    CONFIG, CONFIG_SPEC_SHA256 = file, _config_spec_digest(c)
    _config()


def _config():
    assert CONFIG is not None
    c = _json(CONFIG)
    assert c['tool_sha256'] == _sha(__file__)
    assert _config_spec_digest(c) == CONFIG_SPEC_SHA256, 'Static wall adoption inputs changed; review them again'
    assert c.get('schema') == 1 and c.get('source_tile') and c.get('source_room')
    for relative, digest in c['input_hashes'].items():
        path = (ROOT / relative).resolve()
        assert path.is_relative_to(ROOT.resolve()) and path.is_file() and _sha(path) == digest, ('input drift', relative)
    assert isinstance(c.get('enabled'), bool)
    if c['enabled']:
        assert isinstance(c.get('approval'), dict), 'Enabled adoption requires a pinned runtime-approval receipt'
    else:
        assert c.get('approval') is None, 'Disabled preparation config must not carry an approval receipt'
    return c


def _u():
    import unreal
    return unreal


def _package(obj):
    return obj.get_path_name().split('.')[0] if obj else None


def _dirty(u):
    return dict(maps=sorted(_package(x) for x in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()),
                content=sorted(_package(x) for x in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()))


def _editor(u, c, allow_dirty=False):
    subsystem = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    world = subsystem.get_editor_world()
    assert subsystem.get_game_world() is None, 'Stop PIE before source-LI adoption operations'
    assert world and _package(world) == c['source_map']
    assert world.get_path_name() == c['source_map'] + '.' + c['source_world_name']
    dirty = _dirty(u)
    if not allow_dirty:
        assert dirty == dict(maps=[], content=[]), ('Editor must be clean', dirty)
    return world, dirty


def _source_world(u, c, allowed_dirty_maps=()):
    world, dirty = _editor(u, c, allow_dirty=True)
    # The caller must load this serialized Level Instance as the editor world.
    # Never mutate actors exposed through the assembled Main map's Level Instance.
    assert set(dirty['maps']).issubset(set(allowed_dirty_maps)) and dirty['content'] == [], dirty
    return world, dirty


def _verify_guards(guards, minimum_count):
    assert isinstance(guards, dict) and len(guards) >= minimum_count
    for relative, digest in guards.items():
        path = (ROOT / relative).resolve()
        assert path.is_relative_to(ROOT.resolve()) and path.is_file() and _sha(path) == digest, ('protected path changed', relative)


def _collision(guards, c):
    file = ROOT / c['guard_requirement']['collision_file']
    relative = file.relative_to(ROOT).as_posix()
    assert relative in guards and _sha(file) == guards[relative]
    rows = _json(file)
    assert isinstance(rows, dict) and len(rows) == c['guard_requirement']['collision_count']
    assert all(_sha(ROOT / path) == digest for path, digest in rows.items())
    return rows


def _guard(path, digest, c):
    file = Path(path)
    if not file.is_absolute():
        file = ROOT / file
    file = file.resolve()
    assert file.is_relative_to((ROOT / 'Saved/WarrensCGameplay-20261024').resolve())
    assert file.is_file() and _sha(file) == digest
    data = _json(file)
    assert data.get('status') == c['guard_requirement']['status'] == 'RELOAD_AUDITED'
    guards = data.get('immutable_guards')
    _verify_guards(guards, c['guard_requirement']['minimum_count'])
    collision = _collision(guards, c)
    assert len(collision) == c['guard_requirement']['collision_count']
    rel = c['source_map_file']
    assert rel in guards
    assert _sha(ROOT / rel) == guards[rel], 'Source LI bytes do not match fresh root guard'
    return file, data, guards, collision


def _asset_receipt(c, guards):
    # Share the already-reviewed pure role/preview/asset resolver with the runtime trial.
    resolver = _module('_configured_wall_adoption_asset_roles', HERE/'static_wall_family_runtime.py',
        '0178dcd79c21e7fdee1259d0c9e2fed84077280fa2b3e6637cc012607dbcbfd5')
    roles, materials, _texture = resolver._asset_rows(c, guards)
    assert c['asset_receipt']['mix'] == .60 and c['asset_receipt']['roughness'] == .88
    targets = {axis:dict(path=row['path'],sha256=row['package_sha256']) for axis,row in materials.items()}
    return roles, roles['owned_assets'], targets, roles['reused_parent']


def _selection(c):
    selection_path = ROOT / c['selection']['path']
    assert _sha(selection_path) == c['selection']['sha256']
    selection = _json(selection_path)
    assert selection.get('status') == c['selection']['status'] == 'SOURCE_SELECTION_REVIEW_REQUIRED'
    assert selection['selected_wall_instances'] == c['trial']['selected_count']
    assert selection['summary']['selected_pairs'] == c['trial']['pair_count']
    keys = selection['selected_source_keys']
    assert len(keys) == c['trial']['selected_count'] and len(set(keys)) == len(keys)
    fit_path = ROOT / c['fit_ledger']['path']
    assert _sha(fit_path) == c['fit_ledger']['sha256']
    fit = _json(fit_path)
    assert tuple(float(x) for x in fit['pivots'][c['source_tile']]) == tuple(c['fit_ledger']['pivot'])
    rows = {key: fit['placements'][key] for key in keys}
    pairs, paired = [], set()
    for key in sorted(keys):
        if key in paired:
            continue
        veneer_key, backing_key = _pair_keys(rows, key, c)
        assert veneer_key in rows and backing_key in rows
        veneer, backing = rows[veneer_key], rows[backing_key]
        assert veneer['id'] == c['pairing']['veneer_id']
        assert backing['id'] == c['pairing']['backing_id']
        assert veneer['role'] == c['source_components'][veneer['id']]['role']
        assert backing['role'] == c['source_components'][backing['id']]['role']
        assert veneer['tile'] == backing['tile'] == c['source_tile']
        assert veneer['yaw'] in (0, 90, 180, -90)
        axis = 0 if veneer['yaw'] in (90, -90) else 1
        pairs.append(dict(veneer_key=veneer_key, backing_key=backing_key, axis=axis))
        paired.update((veneer_key, backing_key))
    assert paired == set(keys) and len(pairs) == c['trial']['pair_count']
    counts = {f'{ident}:{axis}': sum(r['id'] == ident and _axis(rows, key, c) == axis
        for key, r in rows.items()) for ident in c['source_components'] for axis in (0, 1)}
    assert counts == c['trial']['per_group_counts'], counts
    return fit, rows, pairs, counts


def _pair_keys(rows, key, c):
    row = rows[key]
    if row['id'] == c['pairing']['veneer_id']:
        return key, key + 1
    assert row['id'] == c['pairing']['backing_id']
    return key - 1, key


def _axis(rows, key, c):
    veneer_key, _backing_key = _pair_keys(rows, key, c)
    yaw = rows[veneer_key]['yaw']
    assert yaw in (0, 90, 180, -90)
    return 0 if yaw in (90, -90) else 1


def _source_components(u, core, world, c):
    actors = list(u.GameplayStatics.get_all_actors_of_class(world, u.Actor))
    source_actors = [a for a in actors if c['source_map'].split('/')[-1] in a.get_level().get_path_name()]
    found = {}
    for ident, spec in c['source_components'].items():
        matches = [(a, comp) for a in source_actors if a.get_actor_label() == spec['actor_label']
                   for comp in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)]
        assert len(matches) == 1, ('Configured source HISM must be unique', ident, len(matches))
        actor, component = matches[0]
        assert _package(actor.get_level().get_outermost()) == c['source_map']
        row = core._component(component)
        assert row['owner_label'] == spec['actor_label'] and row['collision_profile'] == 'NoCollision'
        assert component.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
        found[ident] = dict(actor=actor, component=component, row=row)
    return found


def _match(u, core, c, fit, rows, sources):
    level_transform = sources[c['pairing']['veneer_id']]['actor'].get_level_transform()
    axis_by_key = {}
    for k, row in rows.items():
        axis_by_key[k] = _axis(rows, k, c)
    selected, used = [], {ident: set() for ident in sources}
    for key, row in rows.items():
        ident = row['id']; component = sources[ident]['component']
        wanted = core._row_transform(u, row, c['fit_ledger']['pivot'], level_transform)
        indices = [i for i in range(component.get_instance_count())
                   if core._near(component.get_instance_transform(i, world_space=True), wanted)]
        assert len(indices) == 1, ('Configured fit row missing or ambiguous in live source HISM', key, indices)
        index = indices[0]; assert index not in used[ident]
        used[ident].add(index)
        selected.append(dict(source_key=key, ident=ident, axis=axis_by_key[key], index=index,
            component_path=component.get_path_name(),world_pose=core._pose(component.get_instance_transform(index,world_space=True)),
            local_pose=core._pose(component.get_instance_transform(index,world_space=False))))
    assert len(selected) == c['trial']['selected_count'] and len({x['source_key'] for x in selected}) == len(selected)
    return selected


def _editor_source(u, c):
    main, dirty = _editor(u, c)
    assert _package(main) == c['source_map']
    return main


def _load_approval(c):
    approval = c.get('approval')
    if not c.get('enabled') or not approval:
        raise RuntimeError('Persistent source-LI adoption is disabled pending explicit runtime approval')
    path = (ROOT / approval['path']).resolve()
    assert path.is_relative_to(ROOT.resolve())
    assert path.is_file() and _sha(path) == approval['sha256']
    if approval['format'] == 'markdown':
        text = path.read_text(encoding='utf-8')
        assert approval['status'] == 'APPROVED' and approval['approval_phrase'] in text
        assert c['selection']['sha256'] in text and c['asset_receipt']['sha256'] in text
        data = dict(status=approval['status'], path=approval['path'], sha256=approval['sha256'],
                    selection_sha256=c['selection']['sha256'], asset_receipt_sha256=c['asset_receipt']['sha256'])
    else:
        data = _json(path)
        assert data.get('status') == approval['status'] and data.get('schema') is not None
    return data


def _guards_except_map(guards, map_file, current_map_sha=None):
    for relative, digest in guards.items():
        path = ROOT / relative
        actual = current_map_sha if relative == map_file and current_map_sha is not None else _sha(path)
        assert actual == digest, ('protected file changed', relative)


def _geometry(hisms):
    return _base()._global_geometry(hisms)


def _semantic(core, hisms):
    return _base()._semantic(core, hisms)


def _assets_unchanged(receipt, parent):
    for row in receipt:
        path = ROOT / ('Content/' + row['path'].removeprefix('/Game/') + '.uasset')
        assert path.is_file() and _sha(path) == row['package_sha256']
    path = ROOT / ('Content/' + parent['path'].removeprefix('/Game/') + '.uasset')
    assert path.is_file() and _sha(path) == parent['package_sha256']


def _source_receipt(path, digest, phase):
    file = Path(path)
    if not file.is_absolute(): file = ROOT / file
    file = file.resolve()
    assert file.is_relative_to((_run_dir() / 'receipts').resolve()) and file.is_file() and _sha(file) == digest
    data = _json(file)
    assert data.get('phase') == phase and data.get('tool_sha256') == _sha(__file__)
    assert data.get('config_spec_sha256') == CONFIG_SPEC_SHA256
    assert data['config_sha256'] == _sha(CONFIG), 'Configuration changed after this phase'
    return file, data


def preflight(guard_receipt_path, guard_receipt_sha256):
    """Read-only audit of the configured open source LI and selected wall family."""
    c = _config()
    guard_file, guard_data, guards, collision = _guard(guard_receipt_path, guard_receipt_sha256, c)
    receipt, owned_assets, targets, parent = _asset_receipt(c, guards)
    u, core, base = _u(), _core(), _base()
    world = _editor_source(u, c)
    assert _sha(ROOT / c['source_map_file']) == guards[c['source_map_file']]
    fit, rows, pairs, counts = _selection(c)
    sources = _source_components(u, core, world, c)
    matched = _match(u, core, c, fit, rows, sources)
    folder = _run_dir(c) / ('preflight_' + uuid.uuid4().hex)
    roster, hisms = base._roster(u, core, world, folder / 'actors')
    assert len({row['label'] for row in roster.values()}) == len(roster), 'Source actor labels must be unique for reopen audit'
    assert all(source['row']['path'] in hisms for source in sources.values())
    geometry = _geometry(hisms)
    report = dict(phase='preflight', status='SOURCE_MAP_REVIEW_REQUIRED', map=c['source_map'],map_file=c['source_map_file'],
        map_sha256=guards[c['source_map_file']], source_tile=c['source_tile'], pivot=c['fit_ledger']['pivot'],
        config_sha256=_sha(CONFIG), source_helper_sha256=_sha(BASE_FILE),core_sha256=_sha(CORE_FILE),
        guard_receipt=dict(path=guard_file.relative_to(ROOT).as_posix(),sha256=guard_receipt_sha256,
            status=guard_data['status'],guard_count=len(guards)),immutable_guards=guards,collision_hashes=collision,
        selection=dict(path=c['selection']['path'],sha256=c['selection']['sha256'],selected_count=len(matched),
            source_keys=sorted(x['source_key'] for x in matched),pair_count=len(pairs),group_counts=counts),
        asset_receipt=dict(path=c['asset_receipt']['path'],sha256=c['asset_receipt']['sha256'],status=receipt['status'],
            owned_assets=owned_assets,parent_asset=parent,target_materials={str(a):{'path':v['path'],'sha256':v['sha256']} for a,v in targets.items()}),
        source_components={k:v['row'] for k,v in sources.items()},selected_live_instances=matched,
        actor_component_roster=roster,hism_snapshot=hisms,hism_count=len(hisms),global_instance_count=len(geometry),
        global_geometry_sha256=_digest(geometry),semantic_hism_sha256=_digest(_semantic(core,hisms)),
        dirty=dict(maps=[],content=[]),approval_required=not c['enabled'],enabled=c['enabled'],
        approval=None if not c['approval'] else dict(path=c['approval']['path'],sha256=c['approval']['sha256'],status=c['approval']['status']))
    assert len(matched)==c['trial']['selected_count'] and len(pairs)==c['trial']['pair_count']
    return _write('preflight',report)


def _load_preflight(path, digest):
    file, data = _source_receipt(path,digest,'preflight')
    assert data.get('status')=='SOURCE_MAP_REVIEW_REQUIRED'
    c=_config()
    assert data['config_spec_sha256']==CONFIG_SPEC_SHA256 and data['map_sha256']==_sha(ROOT/c['source_map_file'])
    c=_config()
    _verify_guards(data['immutable_guards'], c['guard_requirement']['minimum_count']); _collision(data['immutable_guards'], c)
    return file,data


def _settings(u):
    editor_class=u.load_class(None,'/Script/UnrealEd.EditorLoadingSavingSettings')
    jolt_class=u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE')
    assert editor_class and jolt_class
    editor=u.get_default_object(editor_class); jolt=u.get_default_object(jolt_class)
    return dict(editor=editor,autosave=editor.get_editor_property('bAutoSaveEnable'),jolt=jolt,
                cook=jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave'))


def _restore_settings(u, before):
    current = _settings(u)
    current['editor'].set_editor_property('bAutoSaveEnable', before['autosave'])
    current['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave', before['cook'])
    _assert_settings(u, before)


def _assert_settings(u, before):
    current = _settings(u)
    assert current['editor'].get_editor_property('bAutoSaveEnable') == before['autosave']
    assert current['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave') == before['cook']


def _checkpoint(c, map_sha):
    folder=_run_dir(c)/('checkpoint_'+uuid.uuid4().hex); folder.mkdir(parents=True,exist_ok=False)
    backup=folder/(c['source_tile']+'.before.umap'); source=ROOT/c['source_map_file']; shutil.copy2(source,backup)
    assert _sha(backup)==map_sha
    return folder,backup


def apply(preflight_path,preflight_sha256):
    """Stage four source HISM partitions only when config carries exact runtime approval."""
    state=_state(); assert state.data is None,'A source wall adoption is already active'
    c=_config(); approval=_load_approval(c)
    pf_file,pf=_load_preflight(preflight_path,preflight_sha256)
    u,core,base=_u(),_core(),_base()
    world,dirty=_source_world(u,c,())
    assert dirty==dict(maps=[],content=[]) and _sha(ROOT/c['source_map_file'])==pf['map_sha256']
    guards=pf['immutable_guards']; _verify_guards(guards,c['guard_requirement']['minimum_count']); collision=_collision(guards,c)
    targets={int(axis):row for axis,row in pf['asset_receipt']['target_materials'].items()}
    sources=_source_components(u,core,world,c); fit,rows,pairs,_counts=_selection(c)
    matches=_match(u,core,c,fit,rows,sources)
    assert matches==pf['selected_live_instances']
    for ident in sources: assert sources[ident]['row']==pf['source_components'][ident]
    # Reject any whole-source drift before checkpointing, settings changes, or mutation.
    live_roster,live_hisms=base._roster(u,core,world,_run_dir(c)/('apply_before_'+uuid.uuid4().hex)/'actors')
    base._assert_raw_roster(pf['actor_component_roster'],live_roster)
    assert _digest(_semantic(core,live_hisms))==pf['semantic_hism_sha256']
    assert _digest(_geometry(live_hisms))==pf['global_geometry_sha256']
    folder,backup=_checkpoint(c,pf['map_sha256'])
    settings=_settings(u)
    checkpoint=_write('checkpoint',dict(phase='checkpoint',status='SOURCE_LI_CHECKPOINTED',
        map=c['source_map'],map_sha256=pf['map_sha256'],backup=backup.relative_to(ROOT).as_posix(),backup_sha256=_sha(backup),
        preflight=dict(path=pf_file.relative_to(ROOT).as_posix(),sha256=preflight_sha256),
        approval=dict(path=c['approval']['path'],sha256=c['approval']['sha256'],status=approval['status']),
        guard_count=len(guards),collision_count=len(collision),settings_before={'autosave':settings['autosave'],'jolt_auto_cook':str(settings['cook'])}))
    before_roster,before_hisms=live_roster,live_hisms
    state.data=dict(stage='mutating',world=world,before_roster=before_roster,before_hisms=before_hisms,
        before_geometry_sha256=pf['global_geometry_sha256'],guards=guards,collision=collision,settings_before=dict(autosave=settings['autosave'],cook=settings['cook']),
        backup=backup.relative_to(ROOT).as_posix(),map_before=pf['map_sha256'],checkpoint=checkpoint,
        preflight=dict(path=pf_file.relative_to(ROOT).as_posix(),sha256=preflight_sha256),approval=dict(path=c['approval']['path'],sha256=c['approval']['sha256']),
        source_labels={k:v['actor_label'] for k,v in c['source_components'].items()},created=[],native={},owned_assets=pf['asset_receipt']['owned_assets'],parent_asset=pf['asset_receipt']['parent_asset'])
    try:
        settings['editor'].set_editor_property('bAutoSaveEnable',False)
        settings['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave',type(settings['cook']).DISABLE)
        assert settings['editor'].get_editor_property('bAutoSaveEnable') is False
        assert settings['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave')==type(settings['cook']).DISABLE
        _assets_unchanged(state.data['owned_assets'],state.data['parent_asset'])
        mats={}
        for axis,spec in targets.items():
            path=ROOT/('Content/'+spec['path'].removeprefix('/Game/')+'.uasset')
            assert _sha(path)==spec['sha256']
            mats[axis]=u.load_asset(spec['path']); assert mats[axis] and _package(mats[axis])==spec['path']
        labels={(x['ident'],x['axis']):x['label'] for x in c['trial']['groups']}
        groups={ident:{axis:[] for axis in targets} for ident in sources}
        for item in matches: groups[item['ident']][item['axis']].append(item)
        created=[]
        for ident,source_data in sources.items():
            for axis in sorted(targets):
                chosen=groups[ident][axis]; assert chosen
                label=labels[(ident,axis)]
                actor,component,native=base._new_group(u,world,source_data['component'],[x['index'] for x in chosen],
                    mats[axis],label,c['trial']['owner'],c['trial']['folder'],folder/('native_'+label))
                state.data['created'].append(dict(label=label,ident=ident,axis=axis,actor=actor,component=component,selected=chosen,
                    source_path=source_data['component'].get_path_name()))
                state.data['native'][label]=native
                created.append(state.data['created'][-1])
        assert len(created)==c['trial']['new_actor_count']
        for ident,source_data in sources.items():
            component=source_data['component']; indices=[x['index'] for x in matches if x['ident']==ident]
            assert len(indices)==len(set(indices)); component.modify()
            for index in sorted(indices,reverse=True): assert component.remove_instance(index)
        staged_roster,staged_hisms=base._roster(u,core,world,folder/'staged')
        new_names=set(staged_roster)-set(before_roster); assert len(new_names)==c['trial']['new_actor_count']
        _verify_roster_transition(before_roster,staged_roster,set(state.data['source_labels'].values()),new_names,state.data['native'],c)
        expected=_expected_hisms(core,before_hisms,staged_hisms,matches,created,targets,c)
        assert _digest(_semantic(core,staged_hisms))==_digest(_semantic(core,expected))
        geometry=_geometry(staged_hisms)
        assert _digest(geometry)==pf['global_geometry_sha256']
        dirty_now=_dirty(u); assert dirty_now['maps']==[c['source_map']] and dirty_now['content']==[]
        _verify_guards(guards,c['guard_requirement']['minimum_count']); _collision(guards,c); _assets_unchanged(state.data['owned_assets'],state.data['parent_asset'])
        state.data.update(stage='staged',world=None,created=None,source_components=None,materials=None,
            post_roster=staged_roster,post_hisms=staged_hisms,expected_hisms=expected,new_names=sorted(new_names),
            geometry_sha256=_digest(geometry))
        result=_write('staged',dict(phase='staged',status='SOURCE_WALL_PARTITION_STAGED_UNSAVED',
            checkpoint=checkpoint,preflight=dict(path=pf_file.relative_to(ROOT).as_posix(),sha256=preflight_sha256),
            map=c['source_map'],selected_count=c['trial']['selected_count'],pair_count=c['trial']['pair_count'],actor_count_before=len(before_roster),actor_count_staged=len(staged_roster),
            hism_count_before=len(before_hisms),hism_count_staged=len(staged_hisms),global_geometry_sha256=_digest(geometry),
            new_actor_labels=sorted(x['label'] for x in created),dirty=dirty_now,map_saved=False,
            next='On a later editor callback call save_staged with this receipt.'))
        state.data['staged_receipt']=result; return result
    except Exception as exc:
        dirty_now=_dirty(u)
        if dirty_now==dict(maps=[],content=[]):
            _restore_settings(u,state.data['settings_before']); state.data=None
        else:
            state.data.update(stage='failed_dirty',world=None,created=None,source_components=None,materials=None)
            settings_readback={}
            try:
                editor=settings['editor']; jolt=settings['jolt']
                editor.set_editor_property('bAutoSaveEnable',False)
                jolt.set_editor_property('_AutoCookStaticWorldOnLevelSave',type(settings['cook']).DISABLE)
                settings_readback=dict(autosave=editor.get_editor_property('bAutoSaveEnable'),
                    jolt_auto_cook=str(jolt.get_editor_property('_AutoCookStaticWorldOnLevelSave')))
            except Exception as settings_exc:
                settings_readback=dict(error=type(settings_exc).__name__+': '+str(settings_exc))
        return _write('apply_failure',dict(phase='apply_failure',status='APPLY_FAILED_RECOVERY_INSPECTION_REQUIRED',
            checkpoint=checkpoint,error=type(exc).__name__+': '+str(exc),dirty=dirty_now,
            map_sha256_now=_sha(ROOT/c['source_map_file']),settings_readback=settings_readback if dirty_now!=dict(maps=[],content=[]) else None,map_saved=False,
            recovery='Do not save/retry. Keep autosave and Jolt disabled while dirty; root owns checkpoint recovery.'))


def _verify_roster_transition(before,after,changed_labels,new_names,native,c):
    assert set(after)==set(before)|set(new_names)
    for name,old in before.items():
        new=after[name]
        for field in ('label','type','tags','pose','hidden','folder'):
            assert old[field]==new[field],('existing actor metadata changed',name,field)
        changed=old['label'] in changed_labels
        if not changed: assert old['raw']['sha256']==new['raw']['sha256'],('unrelated actor export changed',name)
        assert set(old['components'])==set(new['components'])
        for component,entry in old['components'].items():
            actual=new['components'][component]
            assert entry['type']==actual['type']
            if changed and 'hism' in entry: continue
            assert entry['raw']['sha256']==actual['raw']['sha256'],('unrelated component changed',name,component)
    by_label={row['label']:(name,row) for name,row in after.items()}
    for group in c['trial']['groups']:
        assert group['label'] in by_label
        name,row=by_label[group['label']]
        assert row['type']=='/Script/Engine.Actor' and row['tags']==[c['trial']['owner']]
        assert row['hidden'] is False and row['pose']=={'at':[0.0,0.0,0.0],'scale':[1.0,1.0,1.0],'q':[0.0,0.0,0.0,1.0]}
        assert row['folder']==c['trial']['folder']
        baseline=native[group['label']]
        assert set(row['components'])==set(baseline)|{next(k for k,v in row['components'].items() if v.get('hism'))}
        for comp,prior in baseline.items():
            assert row['components'][comp]['type']==prior['type'] and row['components'][comp]['raw']['sha256']==prior['raw']['sha256']


def _expected_hisms(core,before,after,matches,created,targets,c):
    base=_base(); expected=copy.deepcopy(before)
    for ident,spec in c['source_components'].items():
        entries=[row for row in expected.values() if row['owner_label']==spec['actor_label']]
        assert len(entries)==1; row=entries[0]
        indices=[x['index'] for x in matches if x['ident']==ident]
        assert len(indices)==len(set(indices))
        for index in sorted(indices,reverse=True): row['instances'].pop(index)
    by_label={g['label']:g for g in c['trial']['groups']}
    new=[row for row in after.values() if row['owner_label'] in by_label]
    assert len(new)==c['trial']['new_hism_count'] and {x['owner_label'] for x in new}==set(by_label)
    for row in new:
        group=by_label[row['owner_label']]
        src=next(x for x in before.values() if x['owner_label']==c['source_components'][group['ident']]['actor_label'])
        want=copy.deepcopy(src); want['owner_label']=group['label']; want['materials'][0]=targets[group['axis']]['path']
        want['instances']=sorted([x['world_pose'] for x in matches if x['ident']==group['ident'] and x['axis']==group['axis']],
            key=lambda p:json.dumps(p,sort_keys=True,separators=(',',':')))
        assert base._canonical_component(row)==base._canonical_component(want),('new HISM outside finite source partition',group['label'])
        expected[row['path']]=row
    return expected


def _source_approval_guard(c):
    _load_approval(c)


def _map_save(u):
    subsystem=u.get_editor_subsystem(u.LevelEditorSubsystem)
    assert subsystem.save_current_level(),'Saving open source LI failed'


def _save_staged_impl(staged_path,staged_sha256):
    state=_state().data; assert state and state['stage']=='staged'
    file,staged=_source_receipt(staged_path,staged_sha256,'staged')
    assert state['staged_receipt']['file'] == file.relative_to(ROOT).as_posix()
    assert state['staged_receipt']['sha256'] == staged_sha256
    c=_config(); _source_approval_guard(c)
    assert state['approval'] == dict(path=c['approval']['path'],sha256=c['approval']['sha256'])
    u,core,base=_u(),_core(),_base(); world,dirty=_source_world(u,c,[c['source_map']])
    folder=_run_dir(c)/('save_check_'+uuid.uuid4().hex)
    roster,hisms=base._roster(u,core,world,folder)
    _verify_roster_transition(state['before_roster'],roster,set(state['source_labels'].values()),set(state['new_names']),state['native'],c)
    assert _digest(_semantic(core,hisms))==_digest(_semantic(core,state['post_hisms']))
    assert _digest(_geometry(hisms))==state['geometry_sha256'] and dirty['maps']==[c['source_map']] and dirty['content']==[]
    _verify_guards(state['guards'],c['guard_requirement']['minimum_count']); _collision(state['guards'],c); _assets_unchanged(state['owned_assets'],state['parent_asset'])
    current_settings = _settings(u)
    assert current_settings['autosave'] is False
    assert current_settings['cook'] == type(current_settings['cook']).DISABLE
    # Exactly one caller-opened source LI is dirty; save only this current level.
    _map_save(u)
    map_after=_sha(ROOT/c['source_map_file']); assert map_after!=state['map_before']
    assert _dirty(u)==dict(maps=[],content=[])
    guards_after=dict(state['guards']); guards_after[c['source_map_file']]=map_after
    _guards_except_map(guards_after,c['source_map_file'],map_after)
    post_roster,post_hisms=base._roster(u,core,world,_run_dir(c)/('post_save_'+uuid.uuid4().hex))
    _verify_roster_transition(state['before_roster'],post_roster,set(state['source_labels'].values()),set(state['new_names']),state['native'],c)
    assert _digest(_semantic(core,post_hisms))==_digest(_semantic(core,state['post_hisms']))
    assert _digest(_geometry(post_hisms))==state['geometry_sha256']
    collision_after=_collision(guards_after,c); assert collision_after==state['collision']
    _assets_unchanged(state['owned_assets'],state['parent_asset'])
    _restore_settings(u,state['settings_before']); _assert_settings(u,state['settings_before'])
    result=_write('saved',dict(phase='saved',status='SOURCE_LI_SAVED_RELOAD_VERIFICATION_REQUIRED',
        staged_receipt=dict(path=file.relative_to(ROOT).as_posix(),sha256=staged_sha256),
        map=c['source_map'],map_before=state['map_before'],map_after=map_after,checkpoint=state['checkpoint'],
        guard_count=len(state['guards']),collision_count=len(state['collision']),
        owned_assets=state['owned_assets'],parent_asset=state['parent_asset'],actor_roster=post_roster,hism_snapshot=post_hisms,
        actor_count=len(post_roster),hism_count=len(post_hisms),selected_count=c['trial']['selected_count'],
        semantic_hism_sha256=_digest(_semantic(core,post_hisms)),global_geometry_sha256=_digest(_geometry(post_hisms)),
        immutable_guards_after=guards_after,dirty=dict(maps=[],content=[]),settings_restored=True,map_saved=True))
    state.update(stage='saved',map_after=map_after,guards_after=guards_after,saved_receipt=result,post_roster=post_roster,post_hisms=post_hisms)
    return result


def save_staged(staged_path,staged_sha256):
    try:
        return _save_staged_impl(staged_path,staged_sha256)
    except Exception as error:
        state = _state().data
        if state is None:
            raise
        state.update(stage='failed_dirty', world=None, created=None, source_components=None, materials=None)
        u = _u()
        settings_readbacks = {}
        try:
            settings = _settings(u)
            settings['editor'].set_editor_property('bAutoSaveEnable', False)
            settings['jolt'].set_editor_property('_AutoCookStaticWorldOnLevelSave', type(settings['cook']).DISABLE)
            settings_readbacks = dict(autosave=settings['editor'].get_editor_property('bAutoSaveEnable'),
                jolt_auto_cook=str(settings['jolt'].get_editor_property('_AutoCookStaticWorldOnLevelSave')))
        except Exception as settings_error:
            settings_readbacks = dict(error=repr(settings_error))
        c = _json(CONFIG)
        return _write('save_failure', dict(phase='save_failure', status='SAVE_FAILED_RECOVERY_INSPECTION_REQUIRED',
            error=repr(error), checkpoint=state['checkpoint'], dirty=_dirty(u),
            map_sha256_now=_sha(ROOT/c['source_map_file']), settings_readbacks=settings_readbacks,
            original_settings=dict(autosave=state['settings_before']['autosave'],
                jolt_auto_cook=str(state['settings_before']['cook'])),
            recovery='No second save or retry. Inspect bytes, restore the exact source checkpoint, then restore settings explicitly.'))


def _receipt(path,digest,phase):
    file,data=_source_receipt(path,digest,phase); return file,data


def _assert_reopen(before_roster,after_roster,source_labels,new_labels,native,c):
    before_by={row['label']:(name,row) for name,row in before_roster.items()}
    after_by={row['label']:(name,row) for name,row in after_roster.items()}
    assert len(before_by)==len(before_roster) and len(after_by)==len(after_roster)
    assert set(after_by)==set(before_by)|set(new_labels)
    for label,(old_name,old) in before_by.items():
        new_name,new=after_by[label]
        for field in ('label','type','tags','pose','hidden','folder'):
            assert old[field]==new[field],('actor metadata changed after reopen',label,field)
        if label not in source_labels: assert old['raw']['sha256']==new['raw']['sha256'],('unrelated actor raw changed',label)
        assert set(old['components'])==set(new['components'])
        for component,entry in old['components'].items():
            current=new['components'][component]; assert entry['type']==current['type']
            if label in source_labels and 'hism' in entry: continue
            assert entry['raw']['sha256']==current['raw']['sha256'],('unrelated component raw changed',label,component)
    for label in new_labels:
        assert label in after_by
        _name,row=after_by[label]
        assert row['tags']==[c['trial']['owner']] and row['type']=='/Script/Engine.Actor' and row['hidden'] is False
        assert row['pose']=={'at':[0.0,0.0,0.0],'scale':[1.0,1.0,1.0],'q':[0.0,0.0,0.0,1.0]}
        assert row['folder']==c['trial']['folder']
        baseline=native[label]
        for component,entry in baseline.items():
            assert row['components'][component]['type']==entry['type']
            assert row['components'][component]['raw']['sha256']==entry['raw']['sha256']
        assert set(row['components'])==set(baseline)|{name for name,value in row['components'].items() if 'hism' in value}


def verify_reload(saved_path,saved_sha256,prior_reload_path=None,prior_reload_sha256=None):
    state=_state().data; assert state and state['stage']=='saved'
    saved_file,saved=_receipt(saved_path,saved_sha256,'saved'); c=_config()
    assert state['saved_receipt']['file'] == saved_file.relative_to(ROOT).as_posix()
    assert state['saved_receipt']['sha256'] == saved_sha256
    u,core,base=_u(),_core(),_base(); world,dirty=_editor(u,c)
    assert dirty==dict(maps=[],content=[])
    assert _sha(ROOT/c['source_map_file'])==state['map_after']==saved['map_after']
    _guards_except_map(state['guards_after'],c['source_map_file'],state['map_after'])
    roster,hisms=base._roster(u,core,world,_run_dir(c)/('reload_'+uuid.uuid4().hex))
    assert _digest(_semantic(core,hisms))==saved['semantic_hism_sha256']
    assert _digest(_geometry(hisms))==saved['global_geometry_sha256']
    source_labels=set(state['source_labels'].values())
    new_labels={row['label'] for row in c['trial']['groups']}
    _assert_reopen(state['before_roster'],roster,source_labels,new_labels,state['native'],c)
    base._verify_reopen_against_saved(saved['actor_roster'],roster,source_labels|new_labels)
    if prior_reload_path is None:
        saved_by_label = {row['label']: row for row in saved['actor_roster'].values()}
        current_by_label = {row['label']: row for row in roster.values()}
        for label in new_labels:
            before_raw = ROOT/saved_by_label[label]['raw']['file']
            after_raw = ROOT/current_by_label[label]['raw']['file']
            assert Counter(before_raw.read_bytes().splitlines(keepends=True)) == \
                   Counter(after_raw.read_bytes().splitlines(keepends=True)), \
                   ('New source actor raw line content changed on first reopen',label)
    assert _collision(state['guards_after'],c)==state['collision']
    _assets_unchanged(state['owned_assets'],state['parent_asset']); _assert_settings(u,state['settings_before'])
    if prior_reload_path is None:
        result=_write('reload_first',dict(phase='reload_first',status='FIRST_REOPEN_CAPTURED_SECOND_REQUIRED',
            saved_receipt=dict(path=saved_file.relative_to(ROOT).as_posix(),sha256=saved_sha256),map_sha256=state['map_after'],
            actor_roster=roster,hism_snapshot=hisms,semantic_hism_sha256=_digest(_semantic(core,hisms)),
            global_geometry_sha256=_digest(_geometry(hisms)),guards_verified=True,collision_count=len(state['collision']),dirty=dirty))
        state['reload_first']=result; return result
    first_file,first=_receipt(prior_reload_path,prior_reload_sha256,'reload_first')
    assert state.get('reload_first')==dict(file=first_file.relative_to(ROOT).as_posix(),sha256=prior_reload_sha256,
        phase=first['phase'],status=first['status'])
    assert _digest(_semantic(core,hisms))==_digest(_semantic(core,first['hism_snapshot']))
    assert _digest(_geometry(hisms))==first['global_geometry_sha256']
    base._assert_raw_roster(first['actor_roster'],roster)
    result=_write('reload_second',dict(phase='reload_second',status='TWO_REOPEN_SERIALIZATION_STABLE',
        saved_receipt=dict(path=saved_file.relative_to(ROOT).as_posix(),sha256=saved_sha256),
        first_reload=dict(path=first_file.relative_to(ROOT).as_posix(),sha256=prior_reload_sha256),
        map_sha256=state['map_after'],actor_roster=roster,hism_snapshot=hisms,
        semantic_hism_sha256=_digest(_semantic(core,hisms)),global_geometry_sha256=_digest(_geometry(hisms)),
        raw_roster_matches_first_reload=True,guards_verified=True,collision_count=len(state['collision']),dirty=dirty))
    _state().data=None
    return result


def restore_settings_after_manual_recovery():
    state=_state().data; assert state and state['stage']=='failed_dirty'
    c=_config(); u=_u(); world,dirty=_editor(u,c)
    assert _sha(ROOT/c['source_map_file'])==state['map_before']
    backup=ROOT/state['backup']; assert _sha(backup)==state['map_before']
    _verify_guards(state['guards'],c['guard_requirement']['minimum_count']); _restore_settings(u,state['settings_before'])
    _state().data=None
    return dict(status='SETTINGS_RESTORED_AFTER_MANUAL_SOURCE_LI_RECOVERY')

