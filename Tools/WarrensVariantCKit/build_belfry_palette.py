"""Offline, albedo-only Belfry preview. Never saves the source Blend."""
import argparse
import copy
from collections import Counter, defaultdict
import hashlib
import html
import importlib.util
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
OUT = REVIEW / 'belfry-palette'
SOURCE = REVIEW / 'final-room-plates/source_views/WarrensC_CurrentRoomViews.blend'
SCENE = '02_VariantC_Cutaway'
KEYS = ('TX01', 'TX02', 'TX08', 'TX10')
STONE_SRGB = {'TX01': '#819a9d', 'TX02': '#919e97'}
COLOR_TRANSFORM = {'TX08': dict(Hue=0.5, Saturation=1.15, Value=1.15),
                   'TX10': dict(Hue=0.5, Saturation=0.85, Value=0.93)}
ROLES = {
    'source exposed wall veneer', 'source wall seam backing', 'source floor veneer',
    'source floor seam backing', 'source ramp top veneer', 'source ramp seam backing',
    'bell tower corner pier course', 'fitted source gallery post', 'bell tower open crown',
    'supported bell yoke', 'source high landmark hollow bell', 'bone chime support beam',
}
DERIVED = OUT / 'WarrensC_BelfryPalette_Candidate.blend'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write(name, value):
    path = OUT / name
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n', encoding='utf-8')


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def sync_tools():
    return module('belfry_source_contract', HERE / 'sync_art_libraries.py')


def guards():
    result = sync_tools().immutable_files()
    paths = [SOURCE, REVIEW / 'ROOM_PLATES_ASTRA_REVIEW.md',
        ROOT / 'docs/art/warrens-c-dressing-r01/MATERIAL_GUIDE.md',
        ROOT / 'docs/art/warrens-c-dressing-r01/references/ENVC-02-belfry-on-the-other-bank.png']
    paths += [p for p in (REVIEW / 'final-room-plates').rglob('*') if p.is_file()]
    for path in paths:
        result[path.relative_to(ROOT).as_posix()] = sha(path)
    return result


def resolve_belfry():
    import bpy
    sync = sync_tools()
    rows = [(key, row) for key, row in sync.projection()['effective'] if row['tile'] == 'Belfry']
    assert len(rows) == 2760
    scene = bpy.data.scenes[SCENE]
    lookup = defaultdict(list)
    for obj in scene.objects:
        if obj.instance_type == 'COLLECTION':
            lookup[re.sub(r'\.\d{3}$', '', obj.name)].append(obj)
    resolved = []
    for key, row in rows:
        matches = lookup[row['id'] + '_Assembly_' + key]
        assert len(matches) == 1, ('Missing/ambiguous Belfry source row', key)
        obj = matches[0]
        sync.check_pose(obj, row)
        assert not obj.instance_collection.children, ('Nested prototype needs review', obj.name)
        parts = list(obj.instance_collection.objects)
        assert parts and all(p.type == 'MESH' for p in parts), ('Unexpected prototype', obj.name)
        resolved.append((key, row, obj))
    return resolved


def inspect():
    import bpy
    OUT.mkdir(parents=True, exist_ok=True)
    assert not (OUT / 'source_guards.json').exists(), 'Inspection already recorded'
    before = guards()
    write('source_guards.json', before)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    rows = []
    materials = {}
    for key, row, obj in resolve_belfry():
        parts = []
        for part in obj.instance_collection.objects:
            slots = []
            for index, slot in enumerate(part.material_slots):
                mat = slot.material
                catalog = mat.get('catalog_key') if mat else None
                slots.append(dict(index=index, material=mat.name if mat else None, catalog_key=catalog))
                if catalog in KEYS:
                    materials[mat.name] = dict(catalog_key=catalog, nodes=sync_tools().nodes(mat.node_tree))
            parts.append(dict(object=part.name, mesh=part.data.name, slots=slots))
        rows.append(dict(source_key=key, source_row=row, instance=obj.name, collection=obj.instance_collection.name, parts=parts))
    assert guards() == before
    write('ownership_inspection.json', dict(source=SOURCE.relative_to(ROOT).as_posix(), source_sha256=sha(SOURCE),
        owner_tile='Belfry', instance_count=len(rows), rows=rows, candidate_materials=materials,
        boundary='Read-only source inspection. No object/material/source writes.'))
    print('BELFRY_INSPECTED', len(rows), len(materials), flush=True)


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, allow_nan=False).encode()).hexdigest()


def canonical_inventory(value):
    # Blender's unpacked Render Result VIEWER gains an extra cache user after render,
    # then loses it on reopen. This is not a source image/material/scene delta.
    def without_session_ids(item):
        if isinstance(item, dict):
            return {k:without_session_ids(v) for k,v in item.items() if k != 'session_uid'}
        if isinstance(item, (list, tuple)):
            return [without_session_ids(v) for v in item]
        return item
    result = without_session_ids(value)
    viewer = value['images']['Render Result']
    assert viewer['properties']['source'] == 'VIEWER' and viewer['packed_sha256'] == []
    result['images']['Render Result']['properties']['use_extra_user'] = False
    result['images']['Render Result']['properties']['users'] = 0
    return result


def selected_rows():
    result = []
    for key, row, obj in resolve_belfry():
        if row['role'] not in ROLES:
            continue
        if any(s.material and s.material.get('catalog_key') in KEYS
               for part in obj.instance_collection.objects for s in part.material_slots):
            result.append((key, row, obj))
    assert result
    return result


def linear_color(hex_value):
    channels = [int(hex_value[i:i+2], 16) / 255 for i in (1, 3, 5)]
    return [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in channels] + [1.0]


def copy_material(original):
    sync = sync_tools()
    key = original['catalog_key']
    result = original.copy()
    result.name = 'BelfryPreview_' + original.name
    bsdf = result.node_tree.nodes.get('Principled BSDF')
    assert bsdf and len(bsdf.inputs['Base Color'].links) == 1
    link = bsdf.inputs['Base Color'].links[0]
    old_link = [link.from_node.name, link.from_socket.identifier, link.to_node.name, link.to_socket.identifier]
    delta = dict(source=original.name, candidate=result.name, catalog_key=key, base_color_original_link=old_link)
    if key in STONE_SRGB:
        mix = link.from_node
        assert mix.type == 'MIX_RGB' and mix.blend_type == 'MIX'
        assert not mix.inputs[1].is_linked and abs(mix.inputs[0].default_value - .12) < .00001
        delta.update(kind='Existing quiet Mix Color1 only', node=mix.name, socket=mix.inputs[1].identifier,
            before=list(mix.inputs[1].default_value), after_srgb_hex=STONE_SRGB[key])
        mix.inputs[1].default_value = linear_color(STONE_SRGB[key])
        delta['after'] = list(mix.inputs[1].default_value)
    else:
        assert key in COLOR_TRANSFORM and link.from_node.type == 'TEX_IMAGE'
        source_socket = link.from_socket
        node = result.node_tree.nodes.new('ShaderNodeHueSaturation')
        node.name = 'Belfry_AlbedoOnly'
        for name, value in COLOR_TRANSFORM[key].items():
            node.inputs[name].default_value = value
        node.inputs['Fac'].default_value = 1.0
        result.node_tree.links.new(source_socket, node.inputs['Color'])
        result.node_tree.links.new(node.outputs['Color'], bsdf.inputs['Base Color'])
        delta.update(kind='Hue/Saturation transform of existing albedo image only', node=node.name,
            values={name: float(node.inputs[name].default_value) for name in COLOR_TRANSFORM[key]}, factor=1.0)
    delta['source_nodes_sha256'] = digest(sync.nodes(original.node_tree))
    delta['candidate_nodes_sha256'] = digest(sync.nodes(result.node_tree))
    return result, delta


def check_color_delta(original_nodes, actual_nodes, delta):
    original_nodes = json.loads(json.dumps(original_nodes))
    normalized = json.loads(json.dumps(actual_nodes))
    if delta['catalog_key'] in STONE_SRGB:
        normalized['nodes'][delta['node']]['inputs'][delta['socket']] = delta['before']
    else:
        del normalized['nodes'][delta['node']]
        normalized['links'] = [link for link in normalized['links'] if delta['node'] not in (link[0], link[2])]
        normalized['links'].append(delta['base_color_original_link'])
        normalized['links'].sort()
    assert normalized == original_nodes, ('Non-albedo graph delta', delta['candidate'])


def geometry_multiset():
    import bpy
    sync = sync_tools()
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    mesh_cache = {}
    signatures = Counter()
    for inst in graph.object_instances:
        obj = inst.object
        if obj.type != 'MESH':
            continue
        mesh = obj.data
        if mesh.name not in mesh_cache:
            record = sync.mesh_hash(mesh)
            mesh_cache[mesh.name] = digest({k: record[k] for k in ('geometry_sha256', 'uv')})
        signatures[digest(dict(mesh=mesh_cache[mesh.name], matrix=[list(v) for v in inst.matrix_world],
            slots=len(obj.material_slots), hide_render=obj.hide_render))] += 1
    return dict(count=sum(signatures.values()), multiset_sha256=digest(dict(signatures)))


def verify_inventory(before, after, bindings, wrappers, materials):
    # Original IDs remain; only the enumerated EMPTY collection bindings change.
    before = json.loads(json.dumps(canonical_inventory(before)))
    after = json.loads(json.dumps(canonical_inventory(after)))
    normalized = copy.deepcopy(after)
    assert set(after['objects']) - set(before['objects']) == {p['candidate'] for w in wrappers for p in w['parts']}
    assert set(after['collections']) - set(before['collections']) == {w['candidate'] for w in wrappers}
    assert set(after['materials']) - set(before['materials']) == {m['candidate'] for m in materials}
    for binding in bindings:
        obj = normalized['objects'][binding['instance']]
        assert obj['instance'] == binding['candidate_collection']
        obj['instance'] = binding['source_collection']
    for name in set(after['objects']) - set(before['objects']):
        del normalized['objects'][name]
    for name in set(after['collections']) - set(before['collections']):
        del normalized['collections'][name]
    for delta in materials:
        check_color_delta(before['materials'][delta['source']]['nodes'], after['materials'][delta['candidate']]['nodes'], delta)
        del normalized['materials'][delta['candidate']]
    # Additional preview material references legitimately alter ID user counts only.
    for group, field in [('materials', 'values'), ('images', 'properties')]:
        for name, item in before[group].items():
            if 'users' in item[field]:
                normalized[group][name][field]['users'] = item[field]['users']
    if normalized != before:
        diffs = []
        def compare(a, b, path=''):
            if len(diffs) >= 30 or a == b:
                return
            if isinstance(a, dict) and isinstance(b, dict):
                for key in sorted(set(a) | set(b)):
                    if key not in a or key not in b:
                        diffs.append(dict(path=path+'/'+key, before=a.get(key), after=b.get(key)))
                    else:
                        compare(a[key], b[key], path+'/'+key)
            elif isinstance(a, list) and isinstance(b, list) and len(a) == len(b):
                for index, (x, y) in enumerate(zip(a, b)):
                    compare(x, y, path+'/'+str(index))
            else:
                diffs.append(dict(path=path, before=a, after=b))
        compare(before, normalized)
        write('inventory_mismatch.json', diffs)
        raise AssertionError('Undocumented source inventory change: '+str(diffs[:3]))


def make_wrappers(rows):
    import bpy
    sync = sync_tools()
    material_copies = {}
    deltas = []
    wrappers = []
    bindings = []
    cache = {}
    for key, row, instance in rows:
        source = instance.instance_collection
        signature = (source.name, tuple(sorted(s.material.name for p in source.objects for s in p.material_slots
            if s.material and s.material.get('catalog_key') in KEYS)))
        if signature not in cache:
            target = source.copy()
            target.name = 'BelfryPreview_' + source.name
            originals = list(source.objects)
            for obj in list(target.objects):
                target.objects.unlink(obj)
            parts = []
            for old in originals:
                assert old.parent is None and not old.constraints and not old.modifiers, old.name
                obj = old.copy()
                obj.name = 'BelfryPreview_' + old.name
                target.objects.link(obj)
                assert obj.data == old.data and obj.matrix_world == old.matrix_world
                slot_records = []
                for index, slot in enumerate(obj.material_slots):
                    mat = old.material_slots[index].material
                    if mat and mat.get('catalog_key') in KEYS:
                        if mat.name not in material_copies:
                            material_copies[mat.name], delta = copy_material(mat)
                            deltas.append(delta)
                        slot.link = 'OBJECT'
                        slot.material = material_copies[mat.name]
                    slot_records.append(dict(index=index, source_material=mat.name if mat else None,
                        candidate_material=slot.material.name if slot.material else None, link=slot.link))
                assert len(obj.material_slots) == len(old.material_slots)
                assert sync.mesh_hash(obj.data) == sync.mesh_hash(old.data)
                parts.append(dict(source=old.name, candidate=obj.name, linked_mesh=old.data.name, slots=slot_records))
            cache[signature] = target
            wrappers.append(dict(source=source.name, candidate=target.name, parts=parts))
        target = cache[signature]
        bindings.append(dict(source_key=key, source_row=row, instance=instance.name,
            source_collection=source.name, candidate_collection=target.name))
        instance.instance_collection = target
    return bindings, wrappers, deltas


def view_contracts():
    import bpy
    helper = module('belfry_camera_contract', REVIEW / 'source_views/render_source_views.py')
    record = next(r for r in read(REVIEW/'final-room-plates/source_views/render_manifest.json')['rooms'] if r['room_id']=='ROOM_belfry')
    eye = helper.world_point(record['standing_eye_plan'])
    target = helper.world_point(record['standing_target_plan'])
    center = helper.look_center(record['standing_eye_plan'], record['standing_target_plan'], record['source_floor_z_m'])
    return [('overview', bpy.data.objects[record['overview_camera']], center, 12),
            ('standing', bpy.data.objects[record['standing_camera']], (eye + target) * .5, 8)]


def render_views(state):
    import bpy
    helper = module('belfry_light_contract', REVIEW / 'source_views/render_source_views.py')
    scene = bpy.data.scenes[SCENE]
    fill = bpy.data.objects['SourceView_NeutralReviewFill']
    images = []
    for label, camera, center, height in view_contracts():
        helper.point_light(fill, center, height)
        scene.camera = camera
        scene.render.filepath = str(OUT/(state+'_'+label+'.png'))
        bpy.ops.render.render(write_still=True)
        images.append(dict(state=state, view=label, file=Path(scene.render.filepath).name,
            sha256=sha(scene.render.filepath), camera=camera.name, camera_matrix=[list(v) for v in camera.matrix_world],
            light_matrix=[list(v) for v in fill.matrix_world], light_data=sync_tools().rna(fill.data),
            exposure=scene.view_settings.exposure, gamma=scene.view_settings.gamma,
            view_transform=scene.view_settings.view_transform))
        print('BELFRY_RENDERED', state, label, flush=True)
    return images


def build():
    import bpy
    assert guards() == read(OUT/'source_guards.json')
    assert not DERIVED.exists(), 'Refuse to overwrite a prior candidate'
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    scene = bpy.data.scenes[SCENE]
    bpy.context.window.scene = scene
    sync = sync_tools()
    before = sync.inventory()
    write('source_inventory.json', before)
    geometry = geometry_multiset()
    camera = scene.camera
    filepath = scene.render.filepath
    fill = bpy.data.objects['SourceView_NeutralReviewFill']
    fill_matrix = fill.matrix_world.copy()
    current = render_views('A_current')
    bindings, wrappers, materials = make_wrappers(selected_rows())
    candidate = render_views('B_candidate')
    for a, b in zip(current, candidate):
        assert {k:v for k,v in a.items() if k not in ('state','file','sha256')} == {k:v for k,v in b.items() if k not in ('state','file','sha256')}
    scene.camera = camera
    scene.render.filepath = filepath
    fill.matrix_world = fill_matrix
    bpy.context.view_layer.update()
    after = sync.inventory()
    assert geometry_multiset() == geometry, 'Evaluated visible geometry/transform/slot multiset changed'
    verify_inventory(before, after, bindings, wrappers, materials)
    assert guards() == read(OUT/'source_guards.json')
    write('candidate_inventory.json', after)
    write('candidate_receipt.json', dict(source=SOURCE.relative_to(ROOT).as_posix(), source_sha256=sha(SOURCE),
        owner_tile='Belfry', allowed_roles=sorted(ROLES), material_deltas=materials, wrappers=wrappers,
        bindings=bindings, renders=current+candidate, geometry_before_and_after=geometry,
        source_inventory_sha256=digest(canonical_inventory(before)), candidate_inventory_sha256=digest(canonical_inventory(after)),
        render_transient_exception=dict(path='/images/Render Result/properties/{use_extra_user,users}', source='VIEWER', packed_images=False,
            reason='Unpacked render buffer cache-user flag changes during rendering/reopen; no asset image exception.'),
        inventory_digest_rules=dict(excluded_process_identity='session_uid', viewer_only_zero_fields=['use_extra_user','users']),
        boundary='Offline albedo-only candidate. Runtime P4 surfaces remain absent/separate; no Unreal or final art acceptance.'))
    bpy.ops.wm.save_as_mainfile(filepath=str(DERIVED), compress=True, relative_remap=False)
    print('BELFRY_CANDIDATE_SAVED', len(bindings), len(wrappers), len(materials), flush=True)


def diagnose():
    import bpy
    assert guards() == read(OUT/'source_guards.json')
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    scene = bpy.data.scenes[SCENE]
    bpy.context.window.scene = scene
    sync = sync_tools()
    before = sync.inventory()
    camera = scene.camera
    filepath = scene.render.filepath
    fill = bpy.data.objects['SourceView_NeutralReviewFill']
    matrix = fill.matrix_world.copy()
    helper = module('belfry_diagnostic_light_contract', REVIEW/'source_views/render_source_views.py')
    for label, view, center, height in view_contracts():
        scene.camera = view
        helper.point_light(fill, center, height)
    render_views('diagnostic')
    bindings, wrappers, materials = make_wrappers(selected_rows())
    scene.camera = camera
    scene.render.filepath = filepath
    fill.matrix_world = matrix
    bpy.context.view_layer.update()
    after = sync.inventory()
    verify_inventory(before, after, bindings, wrappers, materials)
    print('BELFRY_DIAGNOSTIC_AUDIT_PASSED', flush=True)


def reopen():
    import bpy
    assert guards() == read(OUT/'source_guards.json')
    receipt = read(OUT/'candidate_receipt.json')
    bpy.ops.wm.open_mainfile(filepath=str(DERIVED))
    bpy.context.window.scene = bpy.data.scenes[SCENE]
    after = sync_tools().inventory()
    write('reopened_inventory.json', after)
    expected = read(OUT/'candidate_inventory.json')
    differences = []
    def compare(a, b, path=''):
        if a == b:
            return
        if isinstance(a, dict) and isinstance(b, dict) and a.keys() == b.keys():
            for key in a:
                compare(a[key], b[key], path+'/'+key)
        elif isinstance(a, (list, tuple)) and isinstance(b, (list, tuple)) and len(a) == len(b):
            for index, (x,y) in enumerate(zip(a,b)):
                compare(x,y,path+'/'+str(index))
        else:
            differences.append(dict(path=path, before=a, after=b))
    compare(expected, json.loads(json.dumps(after)))
    assert all(d['path'].endswith('/session_uid') or d['path'] in (
        '/images/Render Result/properties/use_extra_user', '/images/Render Result/properties/users') for d in differences)
    write('reopen_difference_attribution.json', dict(counts=dict(Counter(d['path'].rsplit('/',1)[-1] for d in differences)),
        samples=differences[:20], all_non_session_differences=[d for d in differences if not d['path'].endswith('/session_uid')]))
    assert digest(canonical_inventory(after)) == receipt['candidate_inventory_sha256'], 'Reopened candidate inventory differs'
    verify_inventory(read(OUT/'source_inventory.json'), after, receipt['bindings'], receipt['wrappers'], receipt['material_deltas'])
    assert geometry_multiset() == receipt['geometry_before_and_after']
    assert guards() == read(OUT/'source_guards.json')
    for image in receipt['renders']:
        assert sha(OUT/image['file']) == image['sha256']
    write('verification.json', dict(status='REOPENED_DERIVED_ALBEDO_ONLY_VERIFIED', original_files_unchanged=len(guards()),
        candidate_blend_sha256=sha(DERIVED), selected_instances=len(receipt['bindings']), wrappers=len(receipt['wrappers']),
        copied_materials=len(receipt['material_deltas']), renders=4, evaluated_geometry=receipt['geometry_before_and_after'],
        render_transient_exception=receipt['render_transient_exception'],
        boundary=receipt['boundary']))
    print('BELFRY_REOPEN_VERIFIED', flush=True)


def report():
    assert guards() == read(OUT/'source_guards.json')
    receipt = read(OUT/'candidate_receipt.json')
    verified = read(OUT/'verification.json')
    assert verified['candidate_blend_sha256'] == sha(DERIVED)
    e = lambda value: html.escape(str(value), quote=True)
    body = '<p class="eyebrow">One offline material candidate / root and Astra review</p><h1>Belfry: cool stone,<br>warm timber, quiet brass.</h1><p class="notice">Actual deterministic Blender renders from the current promoted source review copy. Albedo/color only. No original asset or shared material update; no game-light, P4-state or final art acceptance.</p>'
    for view in ('overview', 'standing'):
        body += '<h2>'+view.title()+' / same camera and light</h2><div class="pair">'
        for state, label in [('A_current','A / current source'), ('B_candidate','B / albedo-only candidate')]:
            name = state+'_'+view+'.png'
            body += '<figure><a href="'+name+'"><img src="'+name+'" alt="'+e(label+' '+view)+'"></a><figcaption>'+label+' | unmodified 1000 x 650 render</figcaption></figure>'
        body += '</div>'
    body += '<h2>The single changed axis</h2><p>Cool mineral architectural stone replaces the warm olive/cream constant in the existing quiet stone mix. The source texture weight stays 0.12. Timber receives a mild saturation/value color transform; brass is slightly less saturated and darker. Both keep their original albedo image and all non-color maps. No face noise, mortar grid, directional shadow or new texture is introduced.</p><table><tr><th>Source / copied preview material</th><th>Exact color delta</th></tr>'
    for delta in receipt['material_deltas']:
        change = ('Mix Color1 linear '+str(delta['before'])+' to '+str(delta['after'])+'; target sRGB '+delta['after_srgb_hex']) if delta['catalog_key'] in STONE_SRGB else 'Existing albedo image through Hue/Saturation '+str(delta['values'])+'; factor 1.0'
        body += '<tr><td><code>'+e(delta['source'])+'</code><br><code>'+e(delta['candidate'])+'</code></td><td>'+e(change)+'</td></tr>'
    body += '</table><h2>Owned binding scope</h2><p>'+str(len(receipt['bindings']))+' source instances in the Belfry tile only; '+str(len(receipt['wrappers']))+' reused preview wrappers and '+str(len(receipt['material_deltas']))+' copied materials. Each wrapper retains the original linked mesh datablocks, local transforms, slot counts and collection offset. Only enumerated instance collection bindings and OBJECT-linked material slots change.</p><p>Included: architectural wall/floor/ramp stone, piers/gallery posts/crown, the bell, timber yoke and chime support. Excluded: retained clue housings, key plinth/story props, lamps/flames, bones, all iron and all other districts. Runtime glyph/disc/pointer/panel surfaces remain absent and separately owned.</p><p class="notice">The existing cameras do not frame the high bell equally well. Palette response in these neutral views does not prove bell silhouette, floor or glyph readability under actual game lighting. The next gate is a separately approved unsaved Unreal comparison at the real panel and close-clue views, with unchanged lighting/exposure and complete rollback.</p>'
    body += '<h2>Checks and exact receipts</h2><p>Reopened derived copy passed exact original inventory checks and evaluated geometry / visible world-transform / slot-count multiset equality. Original material node graphs, meshes/topology/UVs, packed image bytes, lights, exposure and camera data are unchanged. Reopen excludes process-local session IDs and the unpacked Render Result VIEWER buffer user/extra-user cache flags only; raw inventories and exact attribution are retained. Every protected file hash remains unchanged, including original Blends, previous frames, source ledgers, 199 FBX, 199 mesh packages and 54 collision files.</p><ul>'+''.join('<li><a href="'+name+'">'+label+'</a></li>' for name,label in [('candidate_receipt.json','Affected instance/part/material list and exact node deltas'),('verification.json','Reopen and unchanged-file verdict'),('source_guards.json','Protected file hashes'),('ownership_inspection.json','Actual source row / prototype ownership inspection'),('reopen_difference_attribution.json','Exact process/cache metadata differences'),('WarrensC_BelfryPalette_Candidate.blend','Derived native candidate Blend'),('build-r3.log','Successful build/render log'),('reopen.log','Independent reopen log')])+'</ul><p>Style/palette input: <a href="../../warrens-c-dressing-r01/references/ENVC-02-belfry-on-the-other-bank.png">ENVC-02</a>, used for color-family direction only, with no architecture, lighting, high key or route copied. <a href="../../warrens-c-dressing-r01/MATERIAL_GUIDE.md">Material guide</a>. <a href="../final-room-plates/rooms/belfry.html">Current-source Belfry plate</a>.</p>'
    css = 'body{margin:0;background:#18242a;color:#eee9de;font:16px/1.55 system-ui,sans-serif}main{max-width:1600px;margin:auto;padding:32px}h1,h2{font-family:Georgia,serif;font-weight:400}h1{font-size:52px;line-height:1.12}h2{margin-top:42px;font-size:30px}.eyebrow{color:#a6d1cf;letter-spacing:.1em;text-transform:uppercase;font-size:12px}.notice{border-left:3px solid #a6d1cf;padding:14px 20px;background:#25363c}.pair{display:grid;grid-template-columns:1fr 1fr;gap:18px}figure{margin:0}img{display:block;width:100%;height:auto}figcaption{color:#b5c4c5;padding:8px 0;font-size:13px}a{color:#e6bd7a}p{max-width:1200px}table{border-collapse:collapse;width:100%;font-size:13px}th,td{padding:12px;text-align:left;border-bottom:1px solid #4b6267;vertical-align:top}code{overflow-wrap:anywhere}@media(max-width:850px){.pair{grid-template-columns:1fr}main{padding:18px}h1{font-size:36px}}'
    (OUT/'PREVIEW.html').write_text('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Belfry albedo-only palette candidate</title><style>'+css+'</style></head><body><main>'+body+'</main></body></html>', encoding='utf-8')
    from html.parser import HTMLParser
    class Links(HTMLParser):
        def __init__(self):
            super().__init__()
            self.links=[]
        def handle_starttag(self, tag, attrs):
            self.links.extend(value for key,value in attrs if key in ('href','src'))
    content=(OUT/'PREVIEW.html').read_text(encoding='utf-8')
    links=Links()
    links.feed(content)
    for link in links.links:
        assert (OUT/link).resolve().is_file(), link
    assert '\ufffd' not in content and '\u00e2\u20ac' not in content
    for row in receipt['renders']:
        assert sha(OUT/row['file']) == row['sha256']
    write('presentation_verification.json',dict(local_links=len(links.links),utf8=True,source_guard_hashes_unchanged=True,
        builder_sha256=sha(__file__),render_hashes_matching=4,browser_layout_exercised=False))
    print('BELFRY_REPORT_READY', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--action', choices=('inspect', 'build', 'reopen', 'report', 'diagnose'), required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else None)
    if args.action == 'inspect':
        inspect()
    elif args.action == 'build':
        build()
    elif args.action == 'reopen':
        reopen()
    elif args.action == 'diagnose':
        diagnose()
    else:
        report()


if __name__ == '__main__':
    main()
