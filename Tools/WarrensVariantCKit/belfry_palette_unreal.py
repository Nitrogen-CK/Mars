"""Belfry TX01/TX02 inspection and explicit disposable PIE trial.

Offline: prepare_offline(). In Unreal: list_pie_levels(), then
preflight('pie', exact_reviewed_level_path), or preflight('source').
Inspection never changes bindings. apply_after_preflight()/restore_trial() are
explicit opt-in runtime mutations; no persistent asset creation or save.
"""
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import sys
import time
import types
import uuid

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
OUT = REVIEW / 'belfry-palette/unreal'
LI = '/Game/Mars/Maps/Variants/v8c/LI_Warrens_Belfry'
GAME = 'Warrens_VariantC_Mars_MAP'
OWNER = 'Mars.WarrensC.BelfryPalette.StoneOnly.Preview.v1'
OWNED_PATH = '/Game/Mars/ArtReview/Lookdev/BelfryPalette_20261025_StoneOnly_v1'
MATERIAL_ROOT = '/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'
COLORS = {'TX01': [0.2195262015, 0.3231432140, 0.3371636271],
          'TX02': [0.2831487358, 0.3419144154, 0.3094689250]}
GRAPH_BASELINE = '20261025_054317_b8c35586'
GRAPH_BASELINE_SHA = {'TX01':'1d5d90211707d95240fedba2c6c2ebc932e7a45558dcea15fb017b22b4a54741',
                      'TX02':'b7fe3f2994c31eedc15adb16361a3fadcb3ceac1f561f7399690c717799d5605'}
APPROVED_PREFLIGHT = 'pie_preflight_20261025_054444_c282d142.json'
APPROVED_PREFLIGHT_SHA = '1c081184e3a0e05962abcb6053713f4feb3a9158f1361f4af5056db41523bd84'
TRIAL_PREFIX = 'WVC_BelfryPaletteTrial_'
STATE_MODULE = '_mars_belfry_palette_trial_state'


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, allow_nan=False).encode()).hexdigest()


def write(name, value):
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT/name).write_text(json.dumps(value, sort_keys=True, indent=2, allow_nan=False)+'\n', encoding='utf-8')


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def package(obj):
    if not obj:
        return None
    path = obj.get_path_name()
    # Distinct unsaved material objects share one transient package.
    return path if path.startswith('/Engine/Transient.') else path.split('.')[0]


def source_data():
    receipt = read(REVIEW/'belfry-palette/candidate_receipt.json')
    fit = read(HERE/'Output/fitted_instances.json')
    approved = {b['source_key']:b for b in receipt['bindings']}
    paths = {}
    material_keys = {}
    for kit in ('ChainCrossingKit','PumpCisternKit','WarrensVariantCKit'):
        for row in read(HERE.parent/kit/'Output/asset_manifest.json')['assets']:
            paths[row['id']] = '/Game/Mars/Environment/'+kit+'/Meshes/'+row['name']
            material_keys[row['id']] = row['material_keys']
    paths.update({key:'/Engine/BasicShapes/Cube' for key in ('BACKING_TX01','BACKING_TX02','SOURCE_CUBE_TX01','SOURCE_CUBE_TX02')})
    rows = []
    for index, row in enumerate(fit['placements']):
        if row['tile'] != 'Belfry':
            continue
        key = str(index)
        ident = row.get('mesh_id',row['id'])
        if ident not in paths:
            assert row.get('material') and ident.startswith('SOURCE_CUBE_'), ident
            paths[ident] = '/Engine/BasicShapes/Cube'
        keys = list(material_keys.get(ident, [row.get('material')]))
        if row.get('material'):
            keys[0] = row['material']
        assert all(keys), row
        candidate_slots = [i for i,k in enumerate(keys) if key in approved and k in COLORS]
        if key in approved:
            assert approved[key]['source_row'] == row, key
        rows.append(dict(source_key=key, row=row, actor_label='WVC_'+row['id'], mesh=paths[ident],
            material_keys=keys, materials=[MATERIAL_ROOT+k for k in keys], candidate_slots=candidate_slots))
    assert len(rows) == 2984 and len(approved) == 2147
    assert sum(bool(r['candidate_slots']) for r in rows) == 2144
    return dict(pivot=fit['pivots']['Belfry'], rows=rows, approved_keys=sorted(approved))


def file_guards():
    # Original 555 guards remain a separate unchanged baseline, never rewritten.
    baseline = read(REVIEW/'belfry-palette/source_guards.json')
    assert len(baseline) == 555 and all(sha(ROOT/key)==value for key,value in baseline.items())
    result = dict(baseline)
    for path in (ROOT/'Content').rglob('*.umap'):
        result[path.relative_to(ROOT).as_posix()] = sha(path)
    for key in COLORS:
        path = ROOT/('Content/Mars/Environment/ChainCrossingKit/Materials/M_CCK_'+key+'.uasset')
        result[path.relative_to(ROOT).as_posix()] = sha(path)
    result[(OUT/'source_hism_roster.json').relative_to(ROOT).as_posix()] = sha(OUT/'source_hism_roster.json')
    return result


def prepare_offline():
    data = source_data()
    source = read(OUT/'source_hism_roster.json')
    assert len(source)==32 and sum(r['instances'] for r in source)==3537
    candidate = Counter(r['actor_label'] for r in data['rows'] if r['candidate_slots'])
    actual = {r['actor']:r for r in source}
    assert all(label in actual for label in candidate)
    summary = [dict(actor=label, approved_candidate_rows=count, actual_component_instances=actual[label]['instances'],
        protected_rows=actual[label]['instances']-count, mixed=count!=actual[label]['instances']) for label,count in sorted(candidate.items())]
    write('offline_scope.json', dict(status='OFFLINE_SCOPE_ONLY_NOT_LIVE_PREFLIGHT', candidate_instances=2144,
        deferred_wood_brass_only=3, all_art_rows=2984, source_hisms=32, source_instances=3537, groups=summary,
        proposed_assets={key:dict(source=MATERIAL_ROOT+key, owned_path=OWNED_PATH+'/M_BelfryPreview_'+key,
            owner_metadata=OWNER, candidate_lerp_a_linear=color, texture_weight=.12, roughness=.88,
            status='NOT_CREATED') for key,color in COLORS.items()},
        boundary='Counts compare source rows and root-supplied component roster only. No instance pose or live ownership has been proved. No Unreal calls.'))
    write('prepared_file_guards.json',file_guards())
    return summary


def _u():
    import unreal
    return unreal


def _world(mode):
    u = _u()
    ed = u.get_editor_subsystem(u.UnrealEditorSubsystem)
    if mode=='source':
        assert ed.get_game_world() is None, 'Source inspection requires PIE ended'
        world = ed.get_editor_world()
        assert package(world)==LI, 'Open the exact Belfry source LI first; this tool never loads levels'
    else:
        assert mode=='pie'
        world = ed.get_game_world()
        assert world and GAME in world.get_name(), 'Requires the actual C PIE game world'
    return world


def _actors(world):
    u = _u()
    return list(u.GameplayStatics.get_all_actors_of_class(world,u.Actor))


def list_pie_levels():
    world = _world('pie')
    groups = defaultdict(list)
    for actor in _actors(world):
        groups[actor.get_level().get_path_name()].append(actor)
    result = []
    for path, actors in sorted(groups.items()):
        if 'LI_Warrens_Belfry' in path:
            result.append(dict(level=path, outer=actors[0].get_level().get_outer().get_path_name(),
                persistent=actors[0].get_level().get_outer()==world,
                level_transform=_pose(actors[0].get_level_transform()), actors=len(actors),
                labels=sorted(a.get_actor_label() for a in actors)))
    write('pie_level_candidates.json',dict(world=world.get_path_name(),levels=result))
    return result


def _pose(value):
    return dict(at=list(value.translation.to_tuple()), scale=list(value.scale3d.to_tuple()),
        q=[value.rotation.x,value.rotation.y,value.rotation.z,value.rotation.w])


def _expected_pose(row, pivot, level_transform):
    u = _u()
    pitch,yaw,roll = row.get('rotation',[0,row.get('yaw',0),0])
    local = u.Transform(location=u.Vector(*[(row['at'][i]-pivot[i])*100 for i in range(3)]),
        rotation=u.Rotator(pitch=pitch,yaw=yaw,roll=roll),scale=u.Vector(*row['scale']))
    return u.MathLibrary.compose_transforms(local,level_transform)


def _near(actual, wanted):
    return ((actual.translation-wanted.translation).length()<.1 and
        (actual.scale3d-wanted.scale3d).length()<.001 and actual.rotation.angular_distance(wanted.rotation)<.001)


def _text_blocks(path):
    """Retain every serialized property; ignore only line/order presentation."""
    raw = Path(path).read_bytes()
    text = raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
    blocks, stack = {}, []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line.startswith('Begin Object '):
            name = re.search(r'\bName="([^"]+)"',line)
            assert name, 'Unexpected public text object header'
            stack.append(name.group(1))
            blocks.setdefault(tuple(stack),{})
        elif line=='End Object':
            assert stack
            stack.pop()
        elif line:
            assert stack and '=' in line, 'Unexpected public text property format'
            name,value = line.split('=',1)
            assert name not in blocks[tuple(stack)], 'Duplicate serialized property'
            blocks[tuple(stack)][name] = value
    assert not stack and blocks
    return {'/'.join(key):value for key,value in blocks.items()}


def _serialized_source_graphs(dump):
    snapshots = {}
    for key in COLORS:
        original = OUT/('source_graph_'+key+'_'+GRAPH_BASELINE+'.t3d')
        assert sha(original)==GRAPH_BASELINE_SHA[key], 'Immutable source graph baseline changed'
        observed = ROOT/dump['materials'][key]['file']
        assert sha(observed)==dump['materials'][key]['sha256']
        baseline, actual = _text_blocks(original), _text_blocks(observed)
        assert actual==baseline, 'Actual source serialized graph differs from approved original: '+key
        root = 'M_CCK_'+key
        lerp = actual[root+'/MaterialExpressionLinearInterpolate_0']
        editor = actual[root+'/'+root+'EditorOnlyData']
        inputs = {'Lerp.'+name:lerp[name] for name in ('A','B','Alpha')}
        inputs.update({name:editor[name] for name in ('BaseColor','Metallic','Roughness','Normal','AmbientOcclusion')})
        expected_ao = '(OutputIndex=1,Mask=1,MaskR=1)' if key=='TX01' else (
            '(Expression="/Script/Engine.MaterialExpressionTextureSample\'M_CCK_TX02:MaterialExpressionTextureSample_1\'",OutputIndex=1,Mask=1,MaskR=1)')
        assert inputs['AmbientOcclusion']==expected_ao
        snapshots[key] = dict(baseline_file=str(original.relative_to(ROOT)),baseline_sha256=GRAPH_BASELINE_SHA[key],
            observed_file=str(observed.relative_to(ROOT)),observed_sha256=sha(observed),
            all_serialized_object_properties=actual,raw_inputs=inputs,
            ao_mask=dict(output_index=1,mask=1,r=1,g=0,b=0,a=0,connected=key=='TX02'),
            exact_original_properties_unchanged=True,
            mask_boundary='Raw input strings match immutable public T3D baseline exactly, including disconnected TX01 AO/normal masks; omitted integer mask fields are zero per native FExpressionInput constructor.')
    return snapshots


def prepare_dump():
    """Observe only the two source masters through public generic text export."""
    u = _u()
    before_files, before_dirty = file_guards(), _dirty()
    token = datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]
    report = dict(tool_sha256=sha(__file__), purpose='Read-only source graph/mask serialization', materials={})
    OUT.mkdir(parents=True, exist_ok=True)
    for key in COLORS:
        material = u.load_asset(MATERIAL_ROOT+key)
        assert material and package(material)==MATERIAL_ROOT+key
        target = OUT/('source_graph_'+key+'_'+token+'.t3d')
        assert not target.exists()
        exporter = u.ObjectExporterT3D()
        assert exporter.get_class().get_name()=='ObjectExporterT3D'
        task = u.AssetExportTask()
        for name,value in dict(object=material,exporter=exporter,filename=str(target),selected=False,
                replace_identical=False,prompt=False,automated=True,use_file_archive=False,write_empty_files=False).items():
            task.set_editor_property(name,value)
        assert u.Exporter.run_asset_export_task(task), list(task.get_editor_property('errors'))
        assert not list(task.get_editor_property('errors')) and target.is_file() and target.stat().st_size>0
        raw = target.read_bytes()
        text = raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
        report['materials'][key] = dict(asset=package(material),file=str(target.relative_to(ROOT)),sha256=sha(target),
            connection_lines=[line.strip() for line in text.splitlines() if 'Expression=' in line or 'AmbientOcclusion=' in line],
            raw_mask_status='Uninterpreted public text receipt; inspect actual format before asserting raw input masks')
    assert file_guards()==before_files, 'Source files changed during text observation'
    assert _dirty()==before_dirty, 'Package dirt changed during text observation'
    report.update(file_guards_unchanged=True,dirty_before=before_dirty,dirty_after=_dirty())
    name = 'source_graph_dump_'+token+'.json'
    report['receipt_file'] = str((OUT/name).relative_to(ROOT))
    write(name,report)
    return report


def _graph(material, key):
    """Inspect exact material-owned nodes and public root/input connections."""
    u = _u()
    mel = u.MaterialEditingLibrary
    outputs = {}
    output_names = {}
    for name in ('MP_BASE_COLOR','MP_ROUGHNESS','MP_METALLIC','MP_NORMAL','MP_AMBIENT_OCCLUSION','MP_EMISSIVE_COLOR',
                 'MP_OPACITY','MP_OPACITY_MASK','MP_WORLD_POSITION_OFFSET'):
        prop = getattr(u.MaterialProperty,name)
        node = mel.get_material_property_input_node(material,prop)
        outputs[name] = node.get_name() if node else None
        output_names[name] = str(mel.get_material_property_input_node_output_name(material,prop))
    owned = {node.get_name():node for node in u.ObjectIterator(u.MaterialExpression) if node.get_outer()==material}
    assert len(owned)==mel.get_num_material_expressions(material)==9, 'Persistent quiet-stone roster must contain the observed nine owned expressions'
    nodes = {}
    for node in owned.values():
        assert node is not None
        names = list(mel.get_material_expression_input_names(node))
        inputs = list(mel.get_inputs_for_material_expression(material,node))
        assert len(names)==len(inputs)
        assert all(value is None or value.get_outer()==material for value in inputs), 'External expression ownership'
        record = dict(type=node.get_class().get_name(), inputs={str(k):v.get_name() if v else None for k,v in zip(names,inputs)})
        nonnull = [value.get_name() for value in inputs if value is not None]
        assert len(nonnull)==len(set(nonnull)), 'Public output-name query is ambiguous for repeated upstream expressions'
        record['input_output_names'] = {}
        for name,value in zip(names,inputs):
            output = mel.get_input_node_output_name_for_material_expression(node,value) if value else None
            assert output is None or isinstance(output,str)
            assert value is None or output is not None, 'Connected expression output was not observable'
            record['input_output_names'][str(name)] = output
        if isinstance(node,u.MaterialExpressionConstant3Vector):
            c = node.get_editor_property('constant')
            record['constant'] = [c.r,c.g,c.b,c.a]
        elif isinstance(node,u.MaterialExpressionConstant):
            record['r'] = float(node.get_editor_property('r'))
        elif isinstance(node,u.MaterialExpressionTextureSample):
            record.update(texture=package(node.get_editor_property('texture')),
                sampler_type=str(node.get_editor_property('sampler_type')),sampler_source=str(node.get_editor_property('sampler_source')))
        elif isinstance(node,u.MaterialExpressionLinearInterpolate):
            record.update(const_a=float(node.get_editor_property('const_a')),const_b=float(node.get_editor_property('const_b')),
                const_alpha=float(node.get_editor_property('const_alpha')))
        else:
            raise AssertionError('Unexpected quiet-stone expression type: '+record['type'])
        nodes[node.get_name()] = record
    connected = set()
    frontier = [name for name in outputs.values() if name is not None]
    while frontier:
        name = frontier.pop()
        assert name in nodes
        if name not in connected:
            connected.add(name)
            frontier.extend(value for value in nodes[name]['inputs'].values() if value is not None)
    base = outputs['MP_BASE_COLOR']
    assert base and nodes[base]['type']=='MaterialExpressionLinearInterpolate'
    pins = nodes[base]['inputs']
    assert set(pins)=={'A','B','Alpha'} and all(pins.values())
    assert nodes[pins['A']]['type']=='MaterialExpressionConstant3Vector'
    spec = next(r for r in read(ROOT/'docs/art/warrens-c-dressing-r01/materials.json') if r['id']==key)
    c = spec['base_srgb_hex']
    srgb = [int(c[i:i+2],16)/255 for i in (1,3,5)]
    original_linear = [v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in srgb]+[1.0]
    assert max(abs(a-b) for a,b in zip(nodes[pins['A']]['constant'],original_linear))<.000001
    assert nodes[pins['B']]['type']=='MaterialExpressionTextureSample'
    assert nodes[pins['Alpha']]['type']=='MaterialExpressionConstant' and abs(nodes[pins['Alpha']]['r']-.12)<.000001
    assert key in ('TX01','TX02')
    expected_connected = 6 if key=='TX01' else 7
    assert len(connected)==expected_connected
    assert abs(nodes[outputs['MP_ROUGHNESS']]['r']-.88)<.000001
    assert nodes[outputs['MP_METALLIC']]['r']==0
    permitted = {'MP_BASE_COLOR','MP_ROUGHNESS','MP_METALLIC'}
    if key=='TX02':
        permitted.add('MP_AMBIENT_OCCLUSION')
    assert all(outputs[name] is None for name in outputs if name not in permitted)
    def texture(channel):
        return '/Game/Mars/Environment/ChainCrossingKit/Textures/T_CCK_'+Path(spec['maps'][channel]).stem
    assert nodes[pins['B']]['texture']==texture('BaseColor'), 'Connected sample differs from original BaseColor'
    assert nodes[base]['input_output_names']['B']=='RGB', 'Original BaseColor must retain RGB output'
    if key=='TX02':
        ao = outputs['MP_AMBIENT_OCCLUSION']
        assert ao and nodes[ao]['type']=='MaterialExpressionTextureSample'
        assert nodes[ao]['texture']==texture('ORM'), 'TX02 AO must retain the actual source ORM sample'
        assert not any(nodes[ao]['inputs'].values()), 'TX02 AO sample has unexpected upstream inputs'
        assert output_names['MP_AMBIENT_OCCLUSION']=='R', 'TX02 AO must retain the actual source R output'
    disconnected = {name:record for name,record in nodes.items() if name not in connected}
    assert len(disconnected)==9-expected_connected and all(r['type']=='MaterialExpressionTextureSample' for r in disconnected.values())
    assert all(not any(r['inputs'].values()) for r in disconnected.values()), 'Disconnected sample has unexpected upstream inputs'
    expected_disconnected = Counter([texture('BaseColor'),texture('ORM'),texture('NormalDX')] if key=='TX01' else
                                    [texture('ORM'),texture('NormalDX')])
    assert Counter(r['texture'] for r in disconnected.values())==expected_disconnected, 'Unexpected persistent disconnected texture multiset'
    return dict(asset=package(material),nodes=nodes,outputs=outputs,output_names=output_names,lerp_a_node=pins['A'],
        total_expression_count=9,observed_connected_nodes=len(connected),connected_node_names=sorted(connected),
        disconnected_node_names=sorted(disconnected),expected_disconnected_texture_multiset=dict(expected_disconnected),
        source_model_boundary='Importer authors eight nodes/three samples. Actual persistent graphs have nine nodes/four samples. TX01 has six connected and three disconnected; TX02 has seven connected including ORM R to AO and two disconnected. All observed nodes and hookups are preserved; historical origin is not asserted.',
        channel_observation_boundary='Public property-output names observe selected expression outputs. Raw input masks are not exposed by that getter and require the separate public text-serialization receipt before a candidate trial.',
        phys_material=package(material.get_editor_property('phys_material')),
        phys_material_mask=package(material.get_editor_property('phys_material_mask')),
        blend_mode=str(material.get_editor_property('blend_mode')),two_sided=material.get_editor_property('two_sided'),
        instanced_usage=material.get_editor_property('used_with_instanced_static_meshes'))


def _component(component):
    actor = component.get_owner()
    return dict(path=component.get_path_name(), actor=actor.get_actor_label(), level=actor.get_level().get_path_name(),
        actor_tags=sorted(str(t) for t in actor.tags), actor_hidden=bool(actor.get_editor_property('hidden')),
        mesh=package(component.static_mesh), materials=[package(m) for m in component.get_materials()],
        component_pose=_pose(component.get_world_transform()),visible=component.is_visible(),
        hidden_in_game=component.get_editor_property('hidden_in_game'),cast_shadow=component.cast_shadow,
        collision_profile=str(component.get_collision_profile_name()),collision_enabled=str(component.get_collision_enabled()),
        collision_object_type=str(component.get_collision_object_type()),
        body_instance=component.get_editor_property('body_instance').export_text(),
        overlaps=component.get_editor_property('generate_overlap_events'),
        custom_data_floats=component.get_editor_property('num_custom_data_floats'),
        random_seed=component.get_editor_property('instancing_random_seed'),
        cull_start=component.get_editor_property('instance_start_cull_distance'),cull_end=component.get_editor_property('instance_end_cull_distance'),
        instances=[_pose(component.get_instance_transform(i,world_space=True)) for i in range(component.get_instance_count())])


def _dirty():
    u = _u()
    return dict(maps=sorted(package(p) for p in u.EditorLoadingAndSavingUtils.get_dirty_map_packages()),
        content=sorted(package(p) for p in u.EditorLoadingAndSavingUtils.get_dirty_content_packages()))


def preflight(mode='source', exact_level_path=None):
    u = _u()
    before_files = file_guards()
    before_dirty = _dirty()
    data = source_data()
    expected_roster = {r['actor']:r for r in read(OUT/'source_hism_roster.json')}
    world = _world(mode)
    if mode=='source':
        levels = {a.get_level().get_path_name():a.get_level() for a in _actors(world) if a.get_level().get_outer()==world}
        assert len(levels)==1, 'Exact source LI must have one directly owned level'
        level = next(iter(levels.values()))
    else:
        assert exact_level_path, 'Review list_pie_levels() and supply the exact Belfry level path'
        levels = {a.get_level().get_path_name():a.get_level() for a in _actors(world)}
        assert exact_level_path in levels
        level = levels[exact_level_path]
        assert level.get_outer()!=world, 'Persistent components are not trial candidates'
        assert 'LI_Warrens_Belfry' in exact_level_path
    actors = [a for a in _actors(world) if a.get_level()==level]
    by_label = defaultdict(list)
    for actor in actors:
        by_label[actor.get_actor_label()].append(actor)
    components = {}
    inventories = {}
    errors = []
    for label, source in expected_roster.items():
        matches = by_label[label]
        if len(matches)!=1:
            errors.append(dict(actor=label,error='Missing/duplicate source actor',count=len(matches)))
            continue
        actor = matches[0]
        assert actor.get_world()==world
        hisms = list(actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent))
        if len(hisms)!=1:
            errors.append(dict(actor=label,error='Missing/duplicate HISM',count=len(hisms)))
            continue
        component = hisms[0]
        try:
            item = _component(component)
        except Exception as exc:
            errors.append(dict(actor=label,error='Component observation unavailable',detail=type(exc).__name__+': '+str(exc)))
            continue
        components[label] = component
        inventories[label] = item
        if item['mesh']!=source['mesh'].split('.')[0] or item['materials']!=[m.split('.')[0] for m in source['materials']] or len(item['instances'])!=source['instances'] or item['actor_tags']!=sorted(source['tags']):
            errors.append(dict(actor=label,error='Actual source roster mismatch'))
    all_hisms = [c for a in actors for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)]
    if len(all_hisms)!=32 or sum(c.get_instance_count() for c in all_hisms)!=3537:
        errors.append(dict(error='Unexpected complete level HISM roster',components=len(all_hisms),instances=sum(c.get_instance_count() for c in all_hisms)))
    rows = defaultdict(list)
    for row in data['rows']:
        rows[row['actor_label']].append(row)
    mixed = []
    matched = []
    for label, expected in rows.items():
        if label not in components:
            continue
        component = components[label]
        actual = [component.get_instance_transform(i,world_space=True) for i in range(component.get_instance_count())]
        used = set()
        candidates = []
        protected = []
        for record in expected:
            wanted = _expected_pose(record['row'],data['pivot'],component.get_owner().get_level_transform())
            indices = [i for i,value in enumerate(actual) if _near(value,wanted)]
            if len(indices)!=1 or indices[0] in used:
                errors.append(dict(actor=label,source_key=record['source_key'],error='Unmatched/duplicate instance pose',indices=indices))
                continue
            index = indices[0]
            used.add(index)
            if inventories[label]['mesh']!=record['mesh'] or inventories[label]['materials']!=record['materials']:
                errors.append(dict(actor=label,source_key=record['source_key'],error='Mesh/slot material differs from source row'))
            entry = dict(actor=label,component=component.get_path_name(),index=index,source_key=record['source_key'],
                role=record['row']['role'],candidate_slots=record['candidate_slots'],world_pose=_pose(actual[index]))
            matched.append(entry)
            (candidates if record['candidate_slots'] else protected).append(index)
        if len(used)!=len(actual):
            errors.append(dict(actor=label,error='Unaccounted live instances',unmatched=sorted(set(range(len(actual)))-used)))
        if candidates and protected:
            source = inventories[label]
            mixed.append(dict(actor=label,component=component.get_path_name(),candidate_indices=sorted(candidates),protected_indices=sorted(protected),
                no_collision=source['collision_profile']=='NoCollision' and component.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION,
                custom_data_floats=source['custom_data_floats'],
                proposal='Only after review: checkpoint original visibility/shadow/collision; keep membership/collision intact, hide original render, render two transient owned HISM subsets with exact source mesh/slots/poses/settings. Restore original render and tear down both on rollback. No removal by index.'))
            if not mixed[-1]['no_collision'] or source['custom_data_floats']!=0:
                errors.append(dict(actor=label,error='Mixed-group proposal requires actual NoCollision and zero per-instance custom data'))
    graph_reports = {}
    serialized = {}
    try:
        serialized = _serialized_source_graphs(prepare_dump())
    except Exception as exc:
        errors.append(dict(error='Serialized original graph/mask verification failed',detail=type(exc).__name__+': '+str(exc)))
    for key in COLORS:
        try:
            assert key in serialized, 'Missing exact serialized graph/mask evidence'
            graph_reports[key] = dict(status='OBSERVED',snapshot=_graph(u.load_asset(MATERIAL_ROOT+key),key),candidate_lerp_a_linear=COLORS[key])
            graph_reports[key]['snapshot']['serialized_source'] = serialized[key]
        except Exception as exc:
            graph_reports[key] = dict(status='BLOCKED_GRAPH_OBSERVATION',error=type(exc).__name__+': '+str(exc))
            errors.append(dict(material=key,error='Graph reflection/shape requires actual review',detail=str(exc)))
    after = {label:_component(c) for label,c in components.items()}
    assert after==inventories, 'Static source components changed during read-only observation'
    assert before_files==file_guards(), 'Original disk files changed during preflight'
    assert before_dirty==_dirty(), 'Read-only inspection changed dirty package state'
    candidate_count = sum(bool(r['candidate_slots']) for r in matched)
    if candidate_count!=2144:
        errors.append(dict(error='Stone candidate match count differs',count=candidate_count,expected=2144))
    visible = [dict(mesh=r['mesh'],materials=r['materials'],pose=pose,slots=len(r['materials']))
        for r in inventories.values() if r['visible'] and not r['hidden_in_game'] and not r['actor_hidden'] for pose in r['instances']]
    report = dict(status='BLOCKED_ERRORS' if errors else ('MATCHED_REPARTITION_REVIEW_REQUIRED' if mixed else 'MATCHED_BINDING_REVIEW_REQUIRED'),
        mode=mode,world=world.get_path_name(),level=level.get_path_name(),candidate_count=candidate_count,
        graph_reports=graph_reports,errors=errors,matched_rows=matched,components=inventories,mixed_groups=mixed,
        visible_instance_multiset=dict(count=len(visible),sha256=digest(sorted(visible,key=digest))),
        files_unchanged=len(before_files),original_555_unchanged=True,dirty_before_and_after=before_dirty,
        boundary='Read-only actual observation. No creation, binding, visibility, membership, collision or save change. Explicit apply_after_preflight remains a separate opt-in disposable PIE operation.')
    name = mode+'_preflight_'+datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]+'.json'
    assert not (OUT/name).exists()
    report['receipt_file'] = name
    report['tool_sha256'] = sha(__file__)
    write(name,report)
    return report


def _trial_state():
    if STATE_MODULE not in sys.modules:
        sys.modules[STATE_MODULE] = types.ModuleType(STATE_MODULE)
        sys.modules[STATE_MODULE].active = None
    return sys.modules[STATE_MODULE]


def _trial_receipt(state, stage, detail):
    name = 'trial_'+stage+'_'+state['token']+'_'+uuid.uuid4().hex[:8]+'.json'
    report = dict(stage=stage,world=state['world_path'],level=state['level_path'],tool_sha256=sha(__file__),
        approved_preflight=APPROVED_PREFLIGHT,fresh_preflight=state['baseline']['receipt_file'],
        retired_material_allowlist=state.get('retired',{}),detail=detail,receipt_file=name)
    write(name,report)
    return report


def _export_trial_material(material, key, stage, token):
    u = _u()
    target = OUT/('trial_graph_'+key+'_'+stage+'_'+token+'.t3d')
    assert not target.exists()
    task = u.AssetExportTask()
    for name,value in dict(object=material,exporter=u.ObjectExporterT3D(),filename=str(target),selected=False,
            replace_identical=False,prompt=False,automated=True,use_file_archive=False,write_empty_files=False).items():
        task.set_editor_property(name,value)
    assert u.Exporter.run_asset_export_task(task), list(task.get_editor_property('errors'))
    assert not list(task.get_editor_property('errors')) and target.is_file() and target.stat().st_size>0
    return target


def _canonical_material(blocks, name, path):
    normalized = {}
    identities = {}
    for object_path,properties in blocks.items():
        key = object_path.replace(name,'@M@')
        assert key not in normalized
        normalized[key] = {}
        for field,value in properties.items():
            if object_path==name and field in ('StateId','LightingGuid'):
                assert re.fullmatch('[0-9A-F]{32}',value)
                identities[field] = value
            else:
                normalized[key][field] = value.replace(path,'@M@').replace(name,'@M@')
    assert set(identities)=={'StateId','LightingGuid'}
    return normalized, identities


def _verify_material_copy(source, candidate, key, stage, state, changed_color):
    assert candidate.get_outer()==state['transient_package']
    expected,source_ids = _canonical_material(_text_blocks(OUT/('source_graph_'+key+'_'+GRAPH_BASELINE+'.t3d')),
        source.get_name(),source.get_path_name())
    exported = _export_trial_material(candidate,key,stage,state['token'])
    actual,candidate_ids = _canonical_material(_text_blocks(exported),candidate.get_name(),candidate.get_path_name())
    if changed_color:
        expected['@M@/MaterialExpressionConstant3Vector_0']['Constant'] = '(R=%.6f,G=%.6f,B=%.6f,A=1.000000)'%tuple(COLORS[key])
    assert actual==expected, 'Transient copy has an unauthorized serialized graph delta: '+key+' '+stage
    return dict(file=str(exported.relative_to(ROOT)),sha256=sha(exported),source_identities=source_ids,
        candidate_identities=candidate_ids,only_authored_delta='Lerp A color' if changed_color else 'None',
        normalization='Exact material outer/name and derived EditorOnlyData name; root StateId/LightingGuid only. Every other serialized property, node GUID and input mask is identical.')


def _make_trial_materials(state):
    u = _u()
    reports = {}
    for key in COLORS:
        _assert_setup_budget(state)
        source = u.load_asset(MATERIAL_ROOT+key)
        candidate = u.SystemLibrary.duplicate_object(source,state['transient_package'],TRIAL_PREFIX+key+'_'+state['token'])
        state['materials'][key] = candidate
        assert isinstance(candidate,u.Material) and candidate.get_outer()==state['transient_package']
        before = _verify_material_copy(source,candidate,key,'copied',state,False)
        root = u.MaterialEditingLibrary.get_material_property_input_node(candidate,u.MaterialProperty.MP_BASE_COLOR)
        names = list(u.MaterialEditingLibrary.get_material_expression_input_names(root))
        inputs = list(u.MaterialEditingLibrary.get_inputs_for_material_expression(candidate,root))
        assert names==['A','B','Alpha'] and len(inputs)==3
        constant = inputs[0]
        assert isinstance(constant,u.MaterialExpressionConstant3Vector) and constant.get_outer()==candidate
        constant.set_editor_property('constant',u.LinearColor(*COLORS[key],1.0))
        u.MaterialEditingLibrary.recompile_material(candidate)
        _assert_setup_budget(state)
        value = constant.get_editor_property('constant')
        assert max(abs(a-b) for a,b in zip((value.r,value.g,value.b,value.a),COLORS[key]+[1.0]))<.000001
        reports[key] = dict(before=before,after=_verify_material_copy(source,candidate,key,'compiled',state,True),
            path=candidate.get_path_name(),transient_outer=state['transient_package'].get_path_name(),
            recompile_material_called=True)
    return reports


def _component_roster(actors):
    u = _u()
    return sorted((c.get_path_name(),c.get_class().get_name()) for actor in actors for c in actor.get_components_by_class(u.ActorComponent))


def _visible_instances(inventories, aliases=None):
    aliases = aliases or {}
    rows = [dict(mesh=r['mesh'],materials=[aliases.get(m,m) for m in r['materials']],pose=pose,slots=len(r['materials']))
        for r in inventories if r['visible'] and not r['hidden_in_game'] and not r['actor_hidden'] for pose in r['instances']]
    return dict(count=len(rows),sha256=digest(sorted(rows,key=digest)))


def _assert_live_trial(state):
    world = _world('pie')
    assert world==state['world'] and world.get_path_name()==state['world_path'], 'PIE world changed; refuse stale references'
    for component in state['components'].values():
        assert component.get_world()==world and component.get_owner().get_level()==state['level']
        assert component.get_owner().get_level().get_outer()!=world, 'Persistent component refused'


def _assert_setup_budget(state):
    _assert_live_trial(state)
    assert time.monotonic()<=state['setup_deadline'], 'Trial setup budget exceeded; restore originals'


def _current_trial_inventory(state):
    return {label:_component(c) for label,c in state['components'].items()}


def _make_subset(state, source, indices, name, candidate_materials):
    u = _u()
    _assert_setup_budget(state)
    assert source.get_num_children_components()==0 and source.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION
    owner = source.get_owner()
    clone = u.SystemLibrary.duplicate_object(source,owner,TRIAL_PREFIX+name+'_'+state['token'])
    if clone is not None:
        state['clones'].append(clone)  # Retain before any setup/registration that can fail.
    assert isinstance(clone,u.HierarchicalInstancedStaticMeshComponent) and clone.get_outer()==owner
    assert clone.get_attach_parent()==source.get_attach_parent()
    clone.set_visibility(False,False)
    clone.clear_instances()
    local = [source.get_instance_transform(i,world_space=False) for i in indices]
    returned = list(clone.add_instances(local,True,False,False))
    assert returned==list(range(len(indices)))
    for slot,material in candidate_materials.items():
        clone.set_material(slot,material)
    owner.call_method('FinishAddComponent',args=(clone,True,source.get_relative_transform()))
    _assert_setup_budget(state)
    assert clone.get_world()==state['world'] and clone.get_owner()==owner
    expected = dict(state['baseline']['components'][owner.get_actor_label()])
    expected['path'] = clone.get_path_name()
    expected['visible'] = False
    expected['instances'] = [expected['instances'][i] for i in indices]
    expected['materials'] = list(expected['materials'])
    for slot,material in candidate_materials.items():
        expected['materials'][slot] = package(material)
    assert _component(clone)==expected, 'Owned subset differs from source settings/poses'
    return clone


def _restore_active(state):
    _assert_live_trial(state)
    for clone in state['clones']:
        if _u().SystemLibrary.is_valid(clone):
            clone.set_visibility(False,False)
    for label in reversed(state['touched']):
        component = state['components'][label]
        for slot,material in enumerate(state['original_materials'][label]):
            component.set_material(slot,material)
        component.set_visibility(state['baseline']['components'][label]['visible'],False)
    for clone in reversed(state['clones']):
        if _u().SystemLibrary.is_valid(clone):
            clone.destroy_component(clone.get_owner())
    state['clones'].clear()
    assert _current_trial_inventory(state)==state['baseline']['components'], 'Original component restore mismatch'
    assert _component_roster(state['actors'])==state['original_roster'], 'Original complete component roster not restored'
    assert _visible_instances(_current_trial_inventory(state).values())==state['baseline']['visible_instance_multiset']
    assert file_guards()==state['files'] and _dirty()==state['dirty'], 'Disk/dirt changed during trial/restore'
    _serialized_source_graphs(prepare_dump())
    return _trial_receipt(state,'restored',dict(original_components_restored=True,owned_components_destroyed=True,
        original_visible_multiset=state['baseline']['visible_instance_multiset'],files_unchanged=len(state['files']),
        dirty_before_and_after=state['dirty'],candidate_references_released_after_receipt=True))


def restore_trial():
    holder = _trial_state()
    assert holder.active is not None, 'No retained trial to restore'
    state = holder.active
    report = _restore_active(state)
    state['materials'].clear()
    holder.active = None
    return report


def _owned_receipt(name):
    assert isinstance(name,str) and Path(name).name==name, 'Receipt must be an explicit owned filename'
    path = OUT/name
    assert path.resolve().parent==OUT.resolve() and path.is_file()
    value = read(path)
    assert value['receipt_file']==name
    return value,sha(path)


def _retired_material_receipts(retired_trials, baseline):
    """Allow only explicit successful apply/restore chains, never a prefix alone."""
    allowed = {}
    for pair in retired_trials:
        assert isinstance(pair,(tuple,list)) and len(pair)==2, 'Supply (applied_filename, restored_filename) pairs'
        applied,applied_sha = _owned_receipt(pair[0])
        restored,restored_sha = _owned_receipt(pair[1])
        token = re.fullmatch(r'trial_applied_(\d{8}_\d{6}_[0-9a-f]{8})_[0-9a-f]{8}\.json',pair[0])
        assert token and re.fullmatch(r'trial_restored_'+token.group(1)+r'_[0-9a-f]{8}\.json',pair[1])
        assert applied['stage']=='applied' and restored['stage']=='restored'
        for field in ('approved_preflight','fresh_preflight','world','level','tool_sha256'):
            assert applied[field]==restored[field], 'Retired receipt chain differs: '+field
        assert applied['approved_preflight']==APPROVED_PREFLIGHT
        assert re.fullmatch('[0-9a-f]{64}',applied['tool_sha256'])
        assert applied['world']==baseline['world'] and applied['level']==baseline['level']
        original,_ = _owned_receipt(applied['fresh_preflight'])
        assert original['status']=='MATCHED_REPARTITION_REVIEW_REQUIRED' and not original['errors']
        assert original['candidate_count']==2144 and original['components']==baseline['components'], 'Current originals differ from the restored trial baseline'
        a,r = applied['detail'],restored['detail']
        assert a['candidates']==2144 and a['mixed_candidate_count']==590 and a['mixed_protected_count']==112
        assert a['original_collision_membership_unchanged'] is True
        assert r['original_components_restored'] is True and r['owned_components_destroyed'] is True
        assert r['candidate_references_released_after_receipt'] is True
        assert a['visible_multiset']==r['original_visible_multiset']==baseline['visible_instance_multiset']
        for detail in (a,r):
            assert detail['dirty_before_and_after']==dict(maps=[],content=[])
            assert detail['files_unchanged']==baseline['files_unchanged']
        assert set(a['materials'])==set(COLORS) and len(a['owned_components'])==2
        for key,record in a['materials'].items():
            path = '/Engine/Transient.'+TRIAL_PREFIX+key+'_'+token.group(1)
            assert record['path']==path and record['transient_outer']=='/Engine/Transient'
            assert record['recompile_material_called'] is True and path not in allowed
            for stage in ('before','after'):
                exported = (ROOT/record[stage]['file']).resolve()
                assert exported.parent==OUT.resolve() and exported.is_file()
                assert sha(exported)==record[stage]['sha256'], 'Retired material evidence changed'
            allowed[path] = dict(material=key,applied_receipt=pair[0],applied_sha256=applied_sha,
                restored_receipt=pair[1],restored_sha256=restored_sha,
                original_current_inventory_equal=True,policy='Retired unbound transient material only; never reused, assigned, edited or destroyed')
    return allowed


def _check_retired_objects(allowed, world):
    u = _u()
    assert not any(o.get_name().startswith(TRIAL_PREFIX) for o in u.ObjectIterator(u.ActorComponent)), 'Any preexisting trial component is refused'
    found = {o.get_path_name():o for o in u.ObjectIterator(u.Material) if o.get_name().startswith(TRIAL_PREFIX)}
    assert not set(found)-set(allowed), 'Unknown preexisting trial materials refused: '+str(sorted(set(found)-set(allowed)))
    transient = u.find_object(None,'/Engine/Transient')
    assert all(o.get_outer()==transient for o in found.values())
    for actor in _actors(world):
        for component in actor.get_components_by_class(u.MeshComponent):
            assert not set(package(m) for m in component.get_materials())&set(allowed), 'Retired material remains bound: '+component.get_path_name()
    return sorted(found)


def apply_after_preflight(exact_level_path, max_setup_seconds=120.0, retired_trials=()):
    """Explicit, unsaved PIE-only trial after the reviewed ownership/mask gate."""
    u = _u()
    assert math.isfinite(max_setup_seconds) and max_setup_seconds>0
    holder = _trial_state()
    assert holder.active is None, 'An earlier trial must be restored first'
    assert sha(OUT/APPROVED_PREFLIGHT)==APPROVED_PREFLIGHT_SHA, 'Reviewed successful receipt changed'
    approved = read(OUT/APPROVED_PREFLIGHT)
    assert approved['status']=='MATCHED_REPARTITION_REVIEW_REQUIRED' and not approved['errors']
    assert approved['candidate_count']==2144
    assert not _dirty()['maps'] and not _dirty()['content'], 'Trial requires a clean package baseline'
    baseline = preflight('pie',exact_level_path)  # Resolve this world, never old receipt object addresses.
    assert baseline['status']=='MATCHED_REPARTITION_REVIEW_REQUIRED' and not baseline['errors']
    assert len(baseline['mixed_groups'])==1
    mixed = baseline['mixed_groups'][0]
    assert mixed['actor']=='WVC_BACKING_TX01' and mixed['no_collision'] and mixed['custom_data_floats']==0
    assert len(mixed['candidate_indices'])==590 and len(mixed['protected_indices'])==112
    world = _world('pie')
    retired = _retired_material_receipts(retired_trials,baseline)
    retired_found = _check_retired_objects(retired,world)
    actors = [a for a in _actors(world) if a.get_level().get_path_name()==exact_level_path]
    level = actors[0].get_level()
    components = {a.get_actor_label():c for a in actors for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)}
    assert set(components)==set(baseline['components']) and len(components)==32
    assert {label:_component(c) for label,c in components.items()}==baseline['components']
    transient = u.find_object(None,'/Engine/Transient')
    assert transient and isinstance(transient,u.Package)
    state = dict(token=datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8],
        baseline=baseline,world=world,world_path=world.get_path_name(),level=level,level_path=exact_level_path,
        actors=actors,components=components,original_roster=_component_roster(actors),transient_package=transient,
        original_materials={label:list(c.get_materials()) for label,c in components.items()},
        materials={},clones=[],touched=[],files=file_guards(),dirty=_dirty(),setup_deadline=time.monotonic()+max_setup_seconds,
        retired=dict(allowed=retired,actually_observed=retired_found,world_mesh_bindings_checked=True))
    holder.active = state  # Module retains Python wrappers across run_path/reloads and GC.
    try:
        material_reports = _make_trial_materials(state)
        by_actor = defaultdict(list)
        for row in baseline['matched_rows']:
            by_actor[row['actor']].append(row)
        source = components[mixed['actor']]
        assert baseline['components'][mixed['actor']]['cast_shadow'] is False
        candidate = _make_subset(state,source,mixed['candidate_indices'],'Candidate',{0:state['materials']['TX01']})
        protected = _make_subset(state,source,mixed['protected_indices'],'Protected',{})
        for label,rows in by_actor.items():
            _assert_setup_budget(state)
            if label==mixed['actor']:
                continue
            slots = {slot for row in rows for slot in row['candidate_slots']}
            if not slots:
                continue
            assert all(row['candidate_slots']==sorted(slots) for row in rows), 'Unreviewed additional mixed group'
            state['touched'].append(label)
            for slot in sorted(slots):
                key = baseline['components'][label]['materials'][slot].removeprefix(MATERIAL_ROOT)
                assert key in COLORS
                components[label].set_material(slot,state['materials'][key])
        # All owned clones are configured, registered and verified while still invisible.
        _assert_setup_budget(state)
        state['touched'].append(mixed['actor'])
        source.set_visibility(False,False)
        candidate.set_visibility(baseline['components'][mixed['actor']]['visible'],False)
        protected.set_visibility(baseline['components'][mixed['actor']]['visible'],False)
        aliases = {package(m):MATERIAL_ROOT+key for key,m in state['materials'].items()}
        current = _current_trial_inventory(state)
        for label,record in current.items():
            expected = dict(baseline['components'][label])
            if label==mixed['actor']:
                expected['visible'] = False
            expected['materials'] = list(expected['materials'])
            slots = {slot for row in by_actor[label] for slot in row['candidate_slots']} if label!=mixed['actor'] else set()
            for slot in slots:
                key = expected['materials'][slot].removeprefix(MATERIAL_ROOT)
                expected['materials'][slot] = package(state['materials'][key])
            assert record==expected, 'Unexpected source component delta: '+label
        inventories = list(current.values())+[_component(c) for c in state['clones']]
        assert _visible_instances(inventories,aliases)==baseline['visible_instance_multiset'], 'Visible instance mesh/pose/slot multiset differs'
        expected_roster = sorted(state['original_roster']+[(c.get_path_name(),c.get_class().get_name()) for c in state['clones']])
        assert _component_roster(actors)==expected_roster
        assert file_guards()==state['files'] and _dirty()==state['dirty']
        _serialized_source_graphs(prepare_dump())
        return _trial_receipt(state,'applied',dict(materials=material_reports,candidates=2144,
            mixed_candidate_count=590,mixed_protected_count=112,owned_components=[c.get_path_name() for c in state['clones']],
            visible_multiset=_visible_instances(inventories,aliases),original_collision_membership_unchanged=True,
            files_unchanged=len(state['files']),dirty_before_and_after=state['dirty'],restore_call='restore_trial()'))
    except Exception as exc:
        state['failure'] = type(exc).__name__+': '+str(exc)
        try:
            restored = restore_trial()
        except Exception as restore_error:
            _trial_receipt(state,'restore_required',dict(error=state['failure'],restore_error=type(restore_error).__name__+': '+str(restore_error),
                action='Retained state remains; retry restore only in the same PIE world, otherwise end/reset disposable PIE. Never save.'))
            raise RuntimeError('Trial failed and restore could not verify; retained state requires explicit restore or disposable PIE reset') from restore_error
        raise RuntimeError('Trial failed; exact original state restored. '+state['failure']+' Receipt: '+restored['receipt_file']) from exc


if __name__=='__main__':
    prepare_offline()
