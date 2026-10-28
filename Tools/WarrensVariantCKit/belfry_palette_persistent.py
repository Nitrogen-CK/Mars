"""Exact Belfry appearance projection and explicitly reviewed editor adoption.

No Unreal calls or writes on import. preflight() is observational; apply(name)
saves only two new owned materials and the already-open original Belfry LI.
Never run while PIE is active. Never rebuild gameplay, collision or geometry.
"""
from collections import defaultdict
import copy
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import runpy
import shutil
import uuid

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
DELTA = HERE/'belfry_palette_delta.json'
DELTA_SHA = '8fa05e25ded0ac2092d8b625d1ade54f466bf5ac66a8aa96b9ef58593ef32d4a'
OWNER = 'Mars.WarrensC.BelfryPalette.v1'
MAP = '/Game/Mars/Maps/Variants/v8c/LI_Warrens_Belfry'
MAP_FILE = ROOT/'Content/Mars/Maps/Variants/v8c/LI_Warrens_Belfry.umap'
INITIAL_MAP_SHA = '0cf37a3328b85625962ea463c9866caedd17187d50e5ccc2d8bb52d6528bc909'
RUN = ROOT/'Saved/WarrensCGameplay-20261024/BelfryPaletteCheckpoint'
NEW_ACTOR = 'WVC_BelfryPalette_WallBacking'
RECOVERY_SHA = 'ed1afe693e86e73e8cb925bdcb01432757b5f2b6dc6ddbb287e2a760c6c0dda2'


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def digest(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,allow_nan=False).encode()).hexdigest()


def _base():
    return runpy.run_path(str(HERE/'belfry_palette_unreal.py'))


def _write(path, value):
    assert path.resolve().is_relative_to(RUN.resolve())
    path.parent.mkdir(parents=True,exist_ok=True)
    assert not path.exists(), 'Never replace an adoption receipt'
    path.write_text(json.dumps(value,indent=2,sort_keys=True,allow_nan=False)+'\n',encoding='utf-8')


def contract():
    assert sha(DELTA)==DELTA_SHA, 'Canonical selection changed'
    delta = read(DELTA)
    assert delta['schema']==1 and delta['owner']==OWNER
    assert sha(ROOT/delta['source_ledger'])==delta['source_ledger_sha256']
    fit = read(ROOT/delta['source_ledger'])
    bindings = delta['bindings']
    assert len(bindings)==delta['selected_count']==2144 and digest(bindings)==delta['selection_sha256']
    assert len({r['source_key'] for r in bindings})==2144
    for record in bindings:
        row = fit['placements'][int(record['source_key'])]
        assert row==record['source_row'] and digest(row)==record['source_row_sha256'] and row['tile']=='Belfry'
        assert record['original_actor_label']=='WVC_'+row['id']
        assert len(record['slots'])==1 and record['slots'][0]['index']==0
        slot = record['slots'][0]
        assert slot['source_material_key'] in ('TX01','TX02')
        assert record['source_material_keys'][0]==slot['source_material_key']
        assert slot['target_material_path']==delta['materials'][slot['source_material_key']]['target_asset']
    for spec in delta['materials'].values():
        source_file = ROOT/('Content/'+spec['source_asset'].removeprefix('/Game/')+'.uasset')
        assert sha(source_file)==spec['source_asset_sha256']
        assert sha(ROOT/spec['source_graph_file'])==spec['source_graph_sha256']
    return delta


def selector_rows():
    return {r['source_key']:copy.deepcopy(r) for r in contract()['bindings']}


def appearance_projection(effective_rows):
    """Input/output (stable source_key, row) pairs. Geometry IDs stay intact."""
    selected = selector_rows()
    rows, seen = [], set()
    has_belfry = False
    for key,original in effective_rows:
        key = str(key)
        row = copy.deepcopy(original)
        has_belfry |= row['tile']=='Belfry'
        if key in selected:
            binding = selected[key]
            assert row==binding['source_row'] and key not in seen
            row['material_path'] = binding['slots'][0]['target_material_path']
            seen.add(key)
        rows.append((key,row))
    assert len(seen)==(2144 if has_belfry else 0), 'Partial/stale Belfry selection refused'
    return dict(rows=rows,selected_count=len(seen),appearance_sha256=digest(dict(delta=DELTA_SHA,rows=rows)),
        geometry_source_sha256=contract()['source_ledger_sha256'])


def material_signature_groups(projected_rows, registry):
    """Emit aliases for selected batches only; preserve canonical source IDs."""
    selected = selector_rows()
    output, paths, signatures = [],dict(registry),{}
    for key,original in projected_rows:
        row = copy.deepcopy(original)
        if str(key) in selected:
            binding = selected[str(key)]
            materials = ['/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'+k for k in binding['source_material_keys']]
            materials[0] = binding['slots'][0]['target_material_path']
            assert row['material_path']==materials[0]
            signature = dict(mesh=binding['mesh_path'],materials=materials,
                cast_shadow=not (binding['source_row']['id'].startswith('BACKING') or binding['source_row']['id']=='CCS61'))
            alias = binding['source_row']['id']+'__BelfryPalette_'+digest(signature)[:12]
            assert alias not in paths or paths[alias]==binding['mesh_path']
            paths[alias] = binding['mesh_path']
            signatures[alias] = signature
            row['id'] = alias
        output.append((str(key),row))
    return dict(rows=output,registry=paths,signatures=signatures)


def _u():
    import unreal
    return unreal


def _context(clean=True):
    u,b = _u(),_base()
    world = b['_world']('source')
    assert world.get_path_name().split('.')[0]==MAP
    if clean:
        assert b['_dirty']()==dict(maps=[],content=[]), 'Stop PIE and clear foreign dirty packages first'
    return u,b,world


def _guards(b):
    result = b['file_guards']()
    result.pop(MAP_FILE.relative_to(ROOT).as_posix())
    for kit in ('ChainCrossingKit','PumpCisternKit','WarrensVariantCKit'):
        for path in (ROOT/'Content/Mars/Environment'/kit/'Materials').rglob('*.uasset'):
            result[path.relative_to(ROOT).as_posix()] = sha(path)
    # These absent-before/new-after assets are the only permitted content additions.
    for spec in contract()['materials'].values():
        result.pop('Content/'+spec['target_asset'].removeprefix('/Game/')+'.uasset',None)
    result[DELTA.relative_to(ROOT).as_posix()] = sha(DELTA)
    return result


def _export(u, obj, path):
    assert not path.exists()
    path.parent.mkdir(parents=True,exist_ok=True)
    task = u.AssetExportTask()
    for key,value in dict(object=obj,exporter=u.ObjectExporterT3D(),filename=str(path),automated=True,
            prompt=False,selected=False,replace_identical=False,use_file_archive=False,write_empty_files=False).items():
        task.set_editor_property(key,value)
    assert u.Exporter.run_asset_export_task(task) and not list(task.get_editor_property('errors'))
    assert path.is_file() and path.stat().st_size>0
    return dict(file=str(path.relative_to(ROOT)),sha256=sha(path))


def _actors(u, world):
    return list(u.GameplayStatics.get_all_actors_of_class(world,u.Actor))


def _roster(u,b,world,folder):
    result = {}
    for actor in _actors(u,world):
        assert actor.get_world()==world and actor.get_level().get_outer()==world
        key = actor.get_name()
        assert key not in result
        components = {}
        for c in actor.get_components_by_class(u.ActorComponent):
            components[c.get_name()] = dict(type=c.get_class().get_path_name(),
                raw=_export(u,c,folder/(key+'__'+c.get_name()+'.t3d')))
            if isinstance(c,u.HierarchicalInstancedStaticMeshComponent):
                components[c.get_name()]['hism'] = b['_component'](c)
        result[key] = dict(label=actor.get_actor_label(),type=actor.get_class().get_path_name(),
            tags=sorted(str(t) for t in actor.tags),pose=b['_pose'](actor.get_actor_transform()),hidden=bool(actor.hidden),
            raw=_export(u,actor,folder/(key+'.t3d')),components=components)
    return result


def _match(u,b,world):
    data = b['source_data']()
    labels = defaultdict(list)
    for a in _actors(u,world):
        labels[a.get_actor_label()].append(a)
    expected = read(b['OUT']/'source_hism_roster.json')
    components,inventory = {},{}
    for item in expected:
        actor, = labels[item['actor']]
        c, = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        record = b['_component'](c)
        assert record['mesh']==item['mesh'].split('.')[0]
        assert record['materials']==[p.split('.')[0] for p in item['materials']]
        assert len(record['instances'])==item['instances'] and record['actor_tags']==sorted(item['tags'])
        components[item['actor']],inventory[item['actor']] = c,record
    all_hisms = [c for a in _actors(u,world) for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)]
    assert len(all_hisms)==32 and sum(c.get_instance_count() for c in all_hisms)==3537
    selected = selector_rows()
    matched,used = [],defaultdict(set)
    actual_poses = {label:[c.get_instance_transform(i,world_space=True) for i in range(c.get_instance_count())]
                    for label,c in components.items()}
    for record in data['rows']:
        c = components[record['actor_label']]
        wanted = b['_expected_pose'](record['row'],data['pivot'],c.get_owner().get_level_transform())
        indices = [i for i,pose in enumerate(actual_poses[record['actor_label']]) if b['_near'](pose,wanted)]
        assert len(indices)==1 and indices[0] not in used[record['actor_label']]
        used[record['actor_label']].add(indices[0])
        matched.append(dict(source_key=record['source_key'],actor=record['actor_label'],index=indices[0],
            selected=record['source_key'] in selected))
    assert sum(r['selected'] for r in matched)==2144 and len(matched)==2984
    for label,indices in used.items():
        assert len(indices)==components[label].get_instance_count()
    mixed = [r for r in matched if r['actor']=='WVC_BACKING_TX01']
    assert len(mixed)==702 and sum(r['selected'] for r in mixed)==590
    return components,inventory,matched


def _material_check(u,b,material,key,folder,changed):
    spec = contract()['materials'][key]
    report = _export(u,material,folder/(key+'.t3d'))
    expected,source_ids = b['_canonical_material'](b['_text_blocks'](ROOT/spec['source_graph_file']),
        'M_CCK_'+key,spec['source_asset']+'.M_CCK_'+key)
    actual,actual_ids = b['_canonical_material'](b['_text_blocks'](ROOT/report['file']),material.get_name(),material.get_path_name())
    if changed:
        expected['@M@/MaterialExpressionConstant3Vector_0']['Constant'] = '(R=%.6f,G=%.6f,B=%.6f,A=1.000000)'%tuple(spec['lerp_a_linear_rgba'][:3])
    assert actual==expected, 'Unauthorized material graph delta: '+key
    report.update(source_identities=source_ids,observed_identities=actual_ids,all_nine_nodes_and_masks_verified=True)
    return report


def _linked_receipt(file, expected_sha):
    path = (ROOT/file).resolve()
    assert path.is_relative_to(RUN.resolve()) and path.is_file() and sha(path)==expected_sha
    return read(path)


def _recovery(file, expected_sha):
    assert expected_sha==RECOVERY_SHA, 'Only the explicitly approved recovery receipt may admit existing materials'
    recovery = _linked_receipt(file,expected_sha)
    assert recovery['status']=='RESTORED_ORIGINAL_MAP_OWNED_MATERIALS_RETAINED'
    assert recovery['map_sha256']==INITIAL_MAP_SHA and recovery['dirty']==dict(maps=[],content=[])
    assert recovery['actors']==79 and recovery['hisms']==32 and recovery['total_instances']==3537
    assert len(recovery['guards'])==646 and len(recovery['inventory'])==32 and len(recovery['roster'])==79
    assert len(recovery['matched_rows'])==2984 and sum(r['selected'] for r in recovery['matched_rows'])==2144
    failure = _linked_receipt(recovery['failure_file'],recovery['failure_sha256'])
    checkpoint = _linked_receipt(recovery['checkpoint_file'],recovery['checkpoint_sha256'])
    original = _linked_receipt(recovery['preflight_file'],recovery['preflight_sha256'])
    material_checkpoint = _linked_receipt(recovery['material_checkpoint_file'],recovery['material_checkpoint_sha256'])
    assert failure['map_saved_sha256']==checkpoint['map_before']==original['map_sha256']==INITIAL_MAP_SHA
    assert failure['error']=="AttributeError: 'HierarchicalInstancedStaticMeshComponent' object has no attribute 'set_generate_overlap_events'"
    assert sha(ROOT/checkpoint['backup'])==INITIAL_MAP_SHA
    assert checkpoint['preflight_file']==recovery['preflight_file'] and checkpoint['preflight_sha256']==recovery['preflight_sha256']
    assert material_checkpoint['status']=='APPROVED_MATERIALS_SAVED_ORIGINAL_MAP_UNSAVED'
    assert material_checkpoint['failure_file']==recovery['failure_file'] and material_checkpoint['failure_sha256']==recovery['failure_sha256']
    assert material_checkpoint['preflight']==recovery['preflight_file'] and material_checkpoint['preflight_sha256']==recovery['preflight_sha256']
    assert material_checkpoint['original_79_actor_roster_unchanged'] is True
    assert recovery['inventory']==original['inventory'] and recovery['matched_rows']==original['matched_rows']
    assert recovery['guards']==checkpoint['guards']==original['guards']
    assert set(recovery['materials'])==set(contract()['materials'])==set(material_checkpoint['materials'])
    for key,spec in contract()['materials'].items():
        record = recovery['materials'][key]
        assert record['asset']==spec['target_asset'] and record['sha256']==material_checkpoint['materials'][key]['sha256']
        assert record['metadata']==dict(Owner=OWNER,DeltaSHA256=DELTA_SHA,SourceSHA256=spec['source_asset_sha256'])
        assert sha(ROOT/('Content/'+spec['target_asset'].removeprefix('/Game/')+'.uasset'))==record['sha256']
        for graph in (record['graph'],material_checkpoint['materials'][key]['graph']):
            assert graph['all_nine_nodes_and_masks_verified'] is True and sha(ROOT/graph['file'])==graph['sha256']
    return recovery


def _exact_roster(before,after):
    assert set(before)==set(after)
    for name,old in before.items():
        new = after[name]
        assert {k:v for k,v in old.items() if k not in ('raw','components')}=={k:v for k,v in new.items() if k not in ('raw','components')}
        assert old['raw']['sha256']==new['raw']['sha256']
        assert set(old['components'])==set(new['components'])
        for key,record in old['components'].items():
            current = new['components'][key]
            assert {k:v for k,v in record.items() if k!='raw'}=={k:v for k,v in current.items() if k!='raw'}
            assert record['raw']['sha256']==current['raw']['sha256']


def _owned_material(u,b,key,spec,recovery,folder):
    assert recovery is not None and key in recovery['materials'], 'Existing material has no explicit recovery admission'
    record = recovery['materials'][key]
    assert record['asset']==spec['target_asset']
    assert sha(ROOT/('Content/'+spec['target_asset'].removeprefix('/Game/')+'.uasset'))==record['sha256']
    material = u.load_asset(spec['target_asset'])
    assert isinstance(material,u.Material) and b['package'](material)==spec['target_asset']
    for tag,value in dict(Owner=OWNER,DeltaSHA256=DELTA_SHA,SourceSHA256=spec['source_asset_sha256']).items():
        assert u.EditorAssetLibrary.get_metadata_tag(material,tag)==value
    _material_check(u,b,material,key,folder,True)
    return material


def _reviewed_reload_roster(before,after,receipt_file,receipt_sha256,applied_file,applied_sha256,preflight_file,preflight_sha256):
    """Admit five concrete export hashes only, never discover/normalize new identities."""
    receipt = _linked_receipt(receipt_file,receipt_sha256)
    assert receipt['status']=='OBSERVED_RELOAD_IDENTITIES_REVIEW_REQUIRED'
    assert receipt['applied_file']==applied_file and receipt['applied_sha256']==applied_sha256
    assert receipt['preflight_file']==preflight_file and receipt['preflight_sha256']==preflight_sha256
    applied = _linked_receipt(applied_file,applied_sha256)
    _linked_receipt(preflight_file,preflight_sha256)
    assert receipt['map_sha256']==applied['map_after']==sha(MAP_FILE)
    host = 'Ck_EditorSelectionProxyHost_Actor_UE_0'
    mid = 'MID_M_WVC_BellkeeperPrimaryColor_0'
    components = ['StaticMeshComponent_'+str(i) for i in range(39,43)]
    assert before[host]['type']==after[host]['type']=='/Script/CkEcs.Ck_EditorSelectionProxyHost_Actor_UE'
    assert len(receipt['exports'])==5
    records = {r['component']:r for r in receipt['exports']}
    assert set(records)=={None,*components}
    expected = copy.deepcopy(before)
    b = _base()
    for component,record in records.items():
        assert record['actor']==host
        old = before[host]['raw'] if component is None else before[host]['components'][component]['raw']
        new = after[host]['raw'] if component is None else after[host]['components'][component]['raw']
        assert record['before']==old and record['after']['sha256']==new['sha256']
        for raw in (record['before'],record['after'],new):
            path = (ROOT/raw['file']).resolve()
            assert path.is_relative_to(RUN.resolve()) and sha(path)==raw['sha256']
        old_blocks = b['_text_blocks'](ROOT/old['file'])
        new_blocks = b['_text_blocks'](ROOT/new['file'])
        assert set(old_blocks)==set(new_blocks)
        expected_paths = [host+'/'+c+'/'+mid for c in components] if component is None else [component+'/'+mid]
        assert len(record['identities'])==len(expected_paths)
        identities = {r['object_path']:r for r in record['identities']}
        assert set(identities)==set(expected_paths)
        replaced = copy.deepcopy(old_blocks)
        old_bytes,new_bytes = (ROOT/old['file']).read_bytes(),(ROOT/new['file']).read_bytes()
        assert old_bytes.startswith((b'\xff\xfe',b'\xfe\xff'))==new_bytes.startswith((b'\xff\xfe',b'\xfe\xff'))
        encoding = 'utf-16' if old_bytes.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig'
        old_text,new_text = old_bytes.decode(encoding),new_bytes.decode(encoding)
        for object_path,identity in identities.items():
            source,target = old_blocks[object_path],new_blocks[object_path]
            assert source['Parent']==target['Parent']==identity['parent']==(
                '"/Script/Engine.Material\'/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_BellkeeperPrimaryColor.M_WVC_BellkeeperPrimaryColor\'"')
            vectors = {k:v for k,v in source.items() if k.startswith('VectorParameterValues(')}
            assert len(vectors)==3 and vectors==identity['vector_parameters']
            old_guid,new_guid = identity['before_guid'],identity['after_guid']
            assert old_guid!=new_guid and all(len(g)==32 and all(c in '0123456789ABCDEF' for c in g) for g in (old_guid,new_guid))
            assert source['LightingGuid']==old_guid and target['LightingGuid']==new_guid
            replaced[object_path]['LightingGuid'] = new_guid
            needle = 'LightingGuid='+old_guid
            assert old_text.count(needle)==1
            old_text = old_text.replace(needle,'LightingGuid='+new_guid)
        assert replaced==new_blocks and old_text==new_text, 'Reload export differs beyond the concrete reviewed identities'
        target_raw = expected[host]['raw'] if component is None else expected[host]['components'][component]['raw']
        target_raw['sha256'] = new['sha256']
    return expected


def preflight(recovery_file=None,recovery_sha256=None):
    delta = contract()
    u,b,world = _context()
    assert (recovery_file is None)==(recovery_sha256 is None)
    recovery = _recovery(recovery_file,recovery_sha256) if recovery_file is not None else None
    assert sha(MAP_FILE)==INITIAL_MAP_SHA, 'Belfry package differs from approved starting state'
    assert not any(OWNER in [str(t) for t in a.tags] or a.get_actor_label()==NEW_ACTOR for a in _actors(u,world))
    for spec in delta['materials'].values():
        if recovery is None:
            assert not u.EditorAssetLibrary.does_asset_exist(spec['target_asset']), 'Destination already exists; explicit recovery admission required'
            assert not (ROOT/('Content/'+spec['target_asset'].removeprefix('/Game/')+'.uasset')).exists()
    guards = _guards(b)
    token = datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]
    folder = RUN/token
    components,inventory,matched = _match(u,b,world)
    roster = _roster(u,b,world,folder/'before')
    if recovery is not None:
        assert inventory==recovery['inventory'] and matched==recovery['matched_rows'] and guards==recovery['guards']
        _exact_roster(recovery['roster'],roster)
        for key,spec in delta['materials'].items():
            _owned_material(u,b,key,spec,recovery,folder/'retained_materials')
    graphs = {key:_material_check(u,b,u.load_asset(spec['source_asset']),key,folder/'source_graphs',False)
              for key,spec in delta['materials'].items()}
    assert _guards(b)==guards and b['_dirty']()==dict(maps=[],content=[])
    report = dict(status='PREFLIGHT_REVIEW_REQUIRED',token=token,delta_sha256=DELTA_SHA,map=MAP,map_sha256=sha(MAP_FILE),
        materials=delta['materials'],guards=guards,inventory=inventory,matched_rows=matched,roster=roster,graphs=graphs,
        recovery=None if recovery is None else dict(file=recovery_file,sha256=recovery_sha256),
        visible_multiset=b['_visible_instances'](inventory.values()),
        proposed=dict(selected=2144,mixed_original_retained=112,new_owned_group=590,hisms_before=32,hisms_after=33,total_instances=3537))
    _write(folder/'preflight.json',report)
    return dict(file=str((folder/'preflight.json').relative_to(ROOT)),sha256=sha(folder/'preflight.json'),proposal=report['proposed'])


def _verify_roster(before,after,changed_components,new_actor_name):
    assert set(after)==set(before)|{new_actor_name}
    for actor_name,old in before.items():
        new = after[actor_name]
        assert {k:v for k,v in old.items() if k not in ('raw','components')}=={k:v for k,v in new.items() if k not in ('raw','components')}
        assert set(new['components'])==set(old['components'])
        changed = changed_components.get(actor_name,set())
        if not changed:
            assert new['raw']['sha256']==old['raw']['sha256'], 'Unrelated actor changed: '+old['label']
        for name,record in old['components'].items():
            if name not in changed:
                assert new['components'][name]['raw']['sha256']==record['raw']['sha256'], 'Unrelated component changed'


def _new_group(u,b,world,source,indices,material):
    ea = u.get_editor_subsystem(u.EditorActorSubsystem)
    actor = ea.spawn_actor_from_class(u.Actor,u.Vector(),u.Rotator())
    assert actor and actor.get_world()==world and actor.get_level().get_outer()==world
    actor.set_actor_label(NEW_ACTOR)
    actor.tags = [u.Name(OWNER)]
    actor.set_folder_path('Warrens/BelfryPalette')
    assert actor.root_component
    actor.root_component.set_mobility(source.get_editor_property('mobility'))
    ss = u.get_engine_subsystem(u.SubobjectDataSubsystem)
    root = ss.k2_gather_subobject_data_for_instance(actor)[0]
    handle,reason = ss.add_new_subobject(u.AddNewSubobjectParams(parent_handle=root,new_class=u.HierarchicalInstancedStaticMeshComponent))
    component = u.SubobjectDataBlueprintFunctionLibrary.get_associated_object(u.SubobjectDataBlueprintFunctionLibrary.get_data(handle))
    assert isinstance(component,u.HierarchicalInstancedStaticMeshComponent), str(reason)
    component.set_mobility(source.get_editor_property('mobility'))
    assert component.set_static_mesh(source.static_mesh)
    component.set_world_transform(source.get_world_transform(),False,True)
    component.set_collision_profile_name(source.get_collision_profile_name())
    component.set_editor_property('generate_overlap_events',source.get_editor_property('generate_overlap_events'))
    component.set_cast_shadow(source.cast_shadow)
    component.set_hidden_in_game(source.get_editor_property('hidden_in_game'),False)
    component.set_editor_property('instancing_random_seed',source.get_editor_property('instancing_random_seed'))
    component.set_cull_distances(source.get_editor_property('instance_start_cull_distance'),source.get_editor_property('instance_end_cull_distance'))
    for slot,original in enumerate(source.get_materials()):
        component.set_material(slot,material if slot==0 else original)
    component.set_visibility(source.is_visible(),False)
    poses = [source.get_instance_transform(i,world_space=False) for i in indices]
    assert list(component.add_instances(poses,True,False,False))==list(range(590))
    return actor,component


def apply(reviewed_preflight_file, reviewed_sha256):
    path = (ROOT/reviewed_preflight_file).resolve()
    assert path.is_relative_to(RUN.resolve()) and path.name=='preflight.json' and sha(path)==reviewed_sha256
    old = read(path)
    assert old['status']=='PREFLIGHT_REVIEW_REQUIRED' and old['delta_sha256']==DELTA_SHA
    u,b,world = _context()
    delta = contract()
    admission = old.get('recovery')
    recovery = _recovery(admission['file'],admission['sha256']) if admission is not None else None
    assert sha(MAP_FILE)==old['map_sha256']==INITIAL_MAP_SHA and _guards(b)==old['guards']
    components,inventory,matched = _match(u,b,world)
    assert inventory==old['inventory'] and matched==old['matched_rows']
    folder = path.parent
    assert not (folder/'checkpoint.json').exists(), 'An earlier attempt exists; inspect its outcome before any retry'
    current = _roster(u,b,world,folder/'admission')
    _exact_roster(old['roster'],current)
    materials = {}
    if recovery is not None:
        assert inventory==recovery['inventory'] and matched==recovery['matched_rows'] and old['guards']==recovery['guards']
        _exact_roster(recovery['roster'],current)
        for key,spec in delta['materials'].items():
            materials[key] = _owned_material(u,b,key,spec,recovery,folder/'reuse_admission_graphs')
    else:
        for spec in delta['materials'].values():
            assert not u.EditorAssetLibrary.does_asset_exist(spec['target_asset']), 'Refuse existing destination without explicit recovery admission'
            assert not (ROOT/('Content/'+spec['target_asset'].removeprefix('/Game/')+'.uasset')).exists()
    assert b['_dirty']()==dict(maps=[],content=[]) and _guards(b)==old['guards']
    backup = folder/'LI_Warrens_Belfry.before.umap'
    assert not backup.exists()
    shutil.copy2(MAP_FILE,backup)
    assert sha(backup)==old['map_sha256']
    _write(folder/'checkpoint.json',dict(map_before=old['map_sha256'],backup=str(backup.relative_to(ROOT)),
        preflight_file=reviewed_preflight_file,preflight_sha256=reviewed_sha256,guards=old['guards'],
        recovery=admission,
        rollback='Close editor; restore only this Belfry .umap backup. Leave two owned material assets unreferenced for inspection; no automatic deletion.'))
    created,changed = [],defaultdict(set)
    try:
        for key,spec in delta['materials'].items():
            if recovery is not None:
                continue  # Receipt-certified saved copies are never edited, recompiled or saved again.
            assert not u.EditorAssetLibrary.does_asset_exist(spec['target_asset']), 'Refuse existing destination'
            material = u.EditorAssetLibrary.duplicate_asset(spec['source_asset'],spec['target_asset'])
            assert isinstance(material,u.Material)
            created.append(spec['target_asset'])
            u.EditorAssetLibrary.set_metadata_tag(material,'Owner',OWNER)
            u.EditorAssetLibrary.set_metadata_tag(material,'DeltaSHA256',DELTA_SHA)
            u.EditorAssetLibrary.set_metadata_tag(material,'SourceSHA256',spec['source_asset_sha256'])
            _material_check(u,b,material,key,folder/'copied_graphs',False)
            root = u.MaterialEditingLibrary.get_material_property_input_node(material,u.MaterialProperty.MP_BASE_COLOR)
            pins = dict(zip(u.MaterialEditingLibrary.get_material_expression_input_names(root),u.MaterialEditingLibrary.get_inputs_for_material_expression(material,root)))
            constant = pins['A']
            assert isinstance(constant,u.MaterialExpressionConstant3Vector) and constant.get_outer()==material
            constant.set_editor_property('constant',u.LinearColor(*spec['lerp_a_linear_rgba']))
            u.MaterialEditingLibrary.recompile_material(material)
            _material_check(u,b,material,key,folder/'compiled_graphs',True)
            materials[key] = material
        by_actor = defaultdict(list)
        for row in matched:
            by_actor[row['actor']].append(row)
        source = components['WVC_BACKING_TX01']
        assert source.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION and source.get_num_children_components()==0
        assert inventory['WVC_BACKING_TX01']['custom_data_floats']==0
        candidates = sorted(r['index'] for r in by_actor['WVC_BACKING_TX01'] if r['selected'])
        protected = sorted(r['index'] for r in by_actor['WVC_BACKING_TX01'] if not r['selected'])
        assert len(candidates)==590 and len(protected)==112
        actor,new_component = _new_group(u,b,world,source,candidates,materials['TX01'])
        expected_new = copy.deepcopy(inventory['WVC_BACKING_TX01'])
        expected_new.update(path=new_component.get_path_name(),actor=NEW_ACTOR,actor_tags=[OWNER],
            instances=[expected_new['instances'][i] for i in candidates],materials=[delta['materials']['TX01']['target_asset']])
        assert b['_component'](new_component)==expected_new, 'New group settings differ from source; no save permitted'
        for label,rows in by_actor.items():
            if label=='WVC_BACKING_TX01' or not any(r['selected'] for r in rows):
                continue
            assert all(r['selected'] for r in rows)
            c = components[label]
            c.modify()
            key = next(r for r in delta['bindings'] if r['original_actor_label']==label)['slots'][0]['source_material_key']
            c.set_material(0,materials[key])
            changed[c.get_owner().get_name()].add(c.get_name())
        poses = [source.get_instance_transform(i,world_space=False) for i in protected]
        source.modify()
        source.clear_instances()
        assert list(source.add_instances(poses,True,False,False))==list(range(112))
        changed[source.get_owner().get_name()].add(source.get_name())
        after = {label:b['_component'](c) for label,c in components.items()}
        for label,record in after.items():
            expected = copy.deepcopy(inventory[label])
            if label=='WVC_BACKING_TX01':
                expected['instances'] = [expected['instances'][i] for i in protected]
            elif any(r['selected'] for r in by_actor[label]):
                key = next(r for r in delta['bindings'] if r['original_actor_label']==label)['slots'][0]['source_material_key']
                expected['materials'][0] = delta['materials'][key]['target_asset']
            assert record==expected, 'Unexpected original component change: '+label
        aliases = {spec['target_asset']:spec['source_asset'] for spec in delta['materials'].values()}
        all_records = list(after.values())+[b['_component'](new_component)]
        assert sum(len(r['instances']) for r in all_records)==3537 and len(all_records)==33
        assert b['_visible_instances'](all_records,aliases)==old['visible_multiset']
        _verify_roster(old['roster'],_roster(u,b,world,folder/'before_save'),changed,actor.get_name())
        assert _guards(b)==old['guards'], 'Protected files changed before save'
        for key,material in materials.items():
            assert u.EditorAssetLibrary.get_metadata_tag(material,'Owner')==OWNER
            if recovery is None:
                assert u.EditorAssetLibrary.save_loaded_asset(material,only_if_is_dirty=False)
            else:
                assert sha(ROOT/('Content/'+delta['materials'][key]['target_asset'].removeprefix('/Game/')+'.uasset'))==recovery['materials'][key]['sha256']
        settings = u.get_default_object(u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE'))
        previous = settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
        try:
            settings.set_editor_property('_AutoCookStaticWorldOnLevelSave',type(previous).DISABLE)
            assert u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
        finally:
            settings.set_editor_property('_AutoCookStaticWorldOnLevelSave',previous)
        assert _guards(b)==old['guards'] and b['_dirty']()==dict(maps=[],content=[])
        for key,spec in delta['materials'].items():
            _material_check(u,b,u.load_asset(spec['source_asset']),key,folder/'source_graphs_after_save',False)
            if recovery is not None:
                _owned_material(u,b,key,spec,recovery,folder/'retained_graphs_after_save')
        result = dict(status='SAVED_RELOAD_AND_PIE_PENDING',delta_sha256=DELTA_SHA,map_before=old['map_sha256'],map_after=sha(MAP_FILE),
            created_materials={key:dict(asset=spec['target_asset'],sha256=sha(ROOT/('Content/'+spec['target_asset'].removeprefix('/Game/')+'.uasset'))) for key,spec in delta['materials'].items()},
            new_actor=actor.get_name(),new_component=new_component.get_name(),changed_components={k:sorted(v) for k,v in changed.items()},
            expected_inventory=after,expected_new=expected_new,visible_multiset=old['visible_multiset'],
            selected=2144,hisms=33,total_instances=3537,protected=112,new_group=590,
            recovery=admission,reused_material_paths=sorted(spec['target_asset'] for spec in delta['materials'].values()) if recovery is not None else [],
            source_graphs_unchanged=True,guards=old['guards'],checkpoint=str((folder/'checkpoint.json').relative_to(ROOT)))
        _write(folder/'applied.json',result)
        return dict(file=str((folder/'applied.json').relative_to(ROOT)),sha256=sha(folder/'applied.json'),status=result['status'])
    except Exception as exc:
        _write(folder/'FAILED.json',dict(status='STOP_CLOSE_EDITOR_RESTORE_CHECKPOINT',error=type(exc).__name__+': '+str(exc),
            recovery=admission,
            created_material_paths=created,map_saved_sha256=sha(MAP_FILE),checkpoint=str((folder/'checkpoint.json').relative_to(ROOT)),
            action='Do not save again. Preserve evidence, close editor and restore only the checkpointed Belfry map. Do not automatically delete owned assets or change other packages.'))
        raise


def audit_saved(applied_file, applied_sha256, reviewed_identity_file=None, reviewed_identity_sha256=None):
    path = (ROOT/applied_file).resolve()
    assert path.is_relative_to(RUN.resolve()) and path.name=='applied.json' and sha(path)==applied_sha256
    applied = read(path)
    u,b,world = _context()
    delta = contract()
    assert sha(MAP_FILE)==applied['map_after'] and _guards(b)==applied['guards']
    labels = defaultdict(list)
    for actor in _actors(u,world):
        labels[actor.get_actor_label()].append(actor)
    records = []
    for label,expected in applied['expected_inventory'].items():
        actor, = labels[label]
        component, = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        actual = b['_component'](component)
        assert actual==expected, 'Saved component differs: '+label
        records.append(actual)
    actor, = labels[NEW_ACTOR]
    component, = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
    assert b['_component'](component)==applied['expected_new']
    records.append(b['_component'](component))
    assert len([c for a in _actors(u,world) for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)])==33
    folder = path.parent/('reopened_'+uuid.uuid4().hex[:8])
    checkpoint = read(path.parent/'checkpoint.json')
    original_file = ROOT/checkpoint['preflight_file']
    assert sha(original_file)==checkpoint['preflight_sha256']
    original = read(original_file)
    actual_roster = _roster(u,b,world,folder/'roster')
    assert (reviewed_identity_file is None)==(reviewed_identity_sha256 is None)
    expected_roster = original['roster']
    if reviewed_identity_file is not None:
        expected_roster = _reviewed_reload_roster(expected_roster,actual_roster,
            reviewed_identity_file,reviewed_identity_sha256,applied_file,applied_sha256,
            checkpoint['preflight_file'],checkpoint['preflight_sha256'])
    _verify_roster(expected_roster,actual_roster,
        {key:set(value) for key,value in applied['changed_components'].items()},actor.get_name())
    graphs = {}
    for key,spec in delta['materials'].items():
        material = u.load_asset(spec['target_asset'])
        assert sha(ROOT/('Content/'+spec['target_asset'].removeprefix('/Game/')+'.uasset'))==applied['created_materials'][key]['sha256']
        assert u.EditorAssetLibrary.get_metadata_tag(material,'Owner')==OWNER
        assert u.EditorAssetLibrary.get_metadata_tag(material,'DeltaSHA256')==DELTA_SHA
        graphs[key] = _material_check(u,b,material,key,folder,True)
        _material_check(u,b,u.load_asset(spec['source_asset']),key,folder/'originals',False)
    aliases = {r['target_asset']:r['source_asset'] for r in delta['materials'].values()}
    assert b['_visible_instances'](records,aliases)==applied['visible_multiset']
    assert _guards(b)==applied['guards'] and b['_dirty']()==dict(maps=[],content=[])
    report = dict(status='SAVED_REOPEN_AUDITED_PIE_PENDING',selected=2144,hisms=33,instances=3537,graphs=graphs,
        reviewed_identity=None if reviewed_identity_file is None else dict(file=reviewed_identity_file,sha256=reviewed_identity_sha256),
        visible_multiset=applied['visible_multiset'],protected_original=112,new_owned=590,
        boundary='Editor reload audit only. Root must freshly observe assembled PIE material subsets and held panel/landing views.')
    _write(folder/'audit.json',report)
    return report


def inspect_pie(applied_file, applied_sha256):
    """Read-only assembled subset inspection; no light/item/puzzle assignment."""
    path = (ROOT/applied_file).resolve()
    assert path.is_relative_to(RUN.resolve()) and path.name=='applied.json' and sha(path)==applied_sha256
    applied = read(path)
    delta,u,b = contract(),_u(),_base()
    world = b['_world']('pie')
    assert sha(MAP_FILE)==applied['map_after'] and _guards(b)==applied['guards']
    owned = [a for a in _actors(u,world) if a.get_actor_label()==NEW_ACTOR and OWNER in [str(t) for t in a.tags]]
    actor, = owned
    level = actor.get_level()
    assert level.get_outer()!=world
    labels = defaultdict(list)
    for a in _actors(u,world):
        if a.get_level()==level:
            labels[a.get_actor_label()].append(a)
    hisms = [c for actors in labels.values() for a in actors for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)]
    assert len(hisms)==33 and sum(c.get_instance_count() for c in hisms)==3537
    selected,used,data = selector_rows(),defaultdict(set),b['source_data']()
    actual_poses = {c.get_path_name():[c.get_instance_transform(i,world_space=True) for i in range(c.get_instance_count())] for c in hisms}
    for record in data['rows']:
        key,label = record['source_key'],record['actor_label']
        if key in selected and label=='WVC_BACKING_TX01':
            label = NEW_ACTOR
        a, = labels[label]
        c, = a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        assert b['package'](c.static_mesh)==record['mesh']
        materials = list(record['materials'])
        if key in selected:
            materials[0] = selected[key]['slots'][0]['target_material_path']
        assert [b['package'](m) for m in c.get_materials()]==materials
        wanted = b['_expected_pose'](record['row'],data['pivot'],a.get_level_transform())
        indices = [i for i,pose in enumerate(actual_poses[c.get_path_name()]) if b['_near'](pose,wanted)]
        assert len(indices)==1 and indices[0] not in used[label]
        used[label].add(indices[0])
    assert sum(len(v) for v in used.values())==2984 and len(used['WVC_BACKING_TX01'])==112 and len(used[NEW_ACTOR])==590
    for label,indices in used.items():
        a, = labels[label]
        c, = a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        assert len(indices)==c.get_instance_count()
    matched_poses,visible_instances = 0,0
    for label,expected in list(applied['expected_inventory'].items())+[(NEW_ACTOR,applied['expected_new'])]:
        a, = labels[label]
        c, = a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        actual = b['_component'](c)
        for field in ('mesh','materials','actor_tags','visible','hidden_in_game','actor_hidden','cast_shadow','collision_profile',
                'collision_enabled','collision_object_type','body_instance','overlaps','custom_data_floats','random_seed','cull_start','cull_end'):
            assert actual[field]==expected[field], 'PIE component contract differs: '+label+' '+field
        poses = actual_poses[c.get_path_name()]
        assert len(poses)==len(expected['instances']), 'PIE instance count differs: '+label
        for index,(pose,saved) in enumerate(zip(poses,expected['instances'])):
            local = u.Transform()
            local.translation = u.Vector(*saved['at'])
            local.rotation = u.Quat(*saved['q'])
            local.scale3d = u.Vector(*saved['scale'])
            wanted = u.MathLibrary.compose_transforms(local,a.get_level_transform())
            assert b['_near'](pose,wanted), 'PIE saved instance pose differs: '+label+' ['+str(index)+']'
            matched_poses += 1
        if actual['visible'] and not actual['hidden_in_game'] and not actual['actor_hidden']:
            visible_instances += len(poses)
    assert matched_poses==3537 and visible_instances==applied['visible_multiset']['count']==3525
    assert _guards(b)==applied['guards']
    report = dict(status='PIE_SUBSETS_OBSERVED_HELD_VIEWS_PENDING',world=world.get_path_name(),level=level.get_path_name(),
        selected=2144,source_art_rows_pose_matched=2984,hisms=33,total_instances=3537,protected_original=112,new_owned=590,
        all_instance_poses_matched=matched_poses,visible_instances=visible_instances,
        pose_tolerances=dict(translation_cm=.1,scale=.001,rotation_radians=.001),
        materials={key:spec['target_asset'] for key,spec in delta['materials'].items()},
        boundary='Actual runtime source-row/slot/component-state and all saved instance poses observed in the Level Instance frame, including the 3525 visible-instance geometry contract. Held panel/landing pixels, physical traversal and novice discovery are separate evidence.')
    _write(path.parent/('PIE_audit_'+uuid.uuid4().hex[:8]+'.json'),report)
    return report
