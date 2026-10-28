"""Read-only inspection of Ossuary TX01/TX02 bindings in the reviewed source Diorama Blend."""
import hashlib
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SOURCE = ROOT / 'Saved/WarrensCGameplay-20261024/BelfryPaletteCheckpoint/blender-stone-v1/r02_Diorama/Diorama.stone.blend'
EXPECTED_SOURCE_SHA256 = '2fb8dfdfbf1a3ad1a5e019204fc679d827eda137381f4b86934fd7b71dbcc7dc'
PLACEMENTS = HERE / 'Output/fitted_instances.json'
OUT = ROOT / 'Saved/WarrensCGameplay-20261024/OssuaryMaterialCandidate'
REPORT = OUT / 'report_uv_edges_r03.md'
RECEIPT = OUT / 'receipt_uv_edges_r03.json'
SCENES = ('02_VariantC_Cutaway', 'Zone_Ossuary')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def serial(value):
    if isinstance(value, (float, int)):
        return float(value)
    if hasattr(value, 'to_tuple'):
        return [serial(x) for x in value.to_tuple()]
    if isinstance(value, (list, tuple)):
        return [serial(x) for x in value]
    return str(value)


def socket_value(socket):
    if not hasattr(socket, 'default_value'):
        return None
    try:
        return serial(socket.default_value)
    except Exception:
        return str(socket.default_value)


def node_record(node):
    row = dict(name=node.name, label=node.label, bl_idname=node.bl_idname, type=node.type,
               inputs=[dict(name=s.name, identifier=s.identifier, linked=s.is_linked,
                            default_value=socket_value(s)) for s in node.inputs])
    if node.type == 'TEX_IMAGE' and node.image:
        image = node.image
        row['image'] = dict(name=image.name, filepath=image.filepath, source=image.source,
                            size=list(image.size), colorspace=image.colorspace_settings.name,
                            packed=bool(image.packed_file), channels=image.channels)
        row['sampling'] = dict(extension=node.extension, interpolation=node.interpolation,
                               projection=node.projection)
    if node.type == 'TEX_COORD':
        row['outputs'] = [s.name for s in node.outputs]
    if node.type == 'MAPPING':
        row['mapping'] = dict(vector_type=node.vector_type,
                              location=socket_value(node.inputs.get('Location')),
                              rotation=socket_value(node.inputs.get('Rotation')),
                              scale=socket_value(node.inputs.get('Scale')))
    return row


def material_record(material):
    tree = material.node_tree
    links = [] if tree is None else [dict(from_node=link.from_node.name, from_socket=link.from_socket.name,
                                           to_node=link.to_node.name, to_socket=link.to_socket.name)
                                     for link in tree.links]
    nodes = [] if tree is None else [node_record(node) for node in tree.nodes]
    properties = dict(name=material.name, catalog_key=material.get('catalog_key'),
                      diffuse_color=list(material.diffuse_color), use_nodes=material.use_nodes,
                      blend_method=getattr(material, 'blend_method', None),
                      surface_render_method=getattr(material, 'surface_render_method', None),
                      roughness=float(material.roughness), metallic=float(material.metallic),
                      alpha=float(material.diffuse_color[3]))
    return dict(properties=properties, nodes=nodes, links=links)


def mesh_uv_profile(obj, slot_index, instance):
    mesh = obj.data
    uv_layers = []
    if not mesh.uv_layers:
        return uv_layers
    transform = instance.matrix_world @ obj.matrix_local
    world_points = [transform @ vertex.co for vertex in mesh.vertices]
    bounds = dict(min=[min(p[i] for p in world_points) for i in range(3)],
                  max=[max(p[i] for p in world_points) for i in range(3)])
    dims = [bounds['max'][i] - bounds['min'][i] for i in range(3)]
    for layer in mesh.uv_layers:
        values = [layer.data[loop_index].uv[:] for polygon in mesh.polygons if polygon.material_index == slot_index
                  for loop_index in polygon.loop_indices]
        if not values:
            continue
        uv_min = [min(v[i] for v in values) for i in range(2)]
        uv_max = [max(v[i] for v in values) for i in range(2)]
        uv_span = [uv_max[i] - uv_min[i] for i in range(2)]
        ratios = []
        for polygon in mesh.polygons:
            if polygon.material_index != slot_index or len(polygon.loop_indices) < 2:
                continue
            loop_ids = list(polygon.loop_indices)
            for i, loop_a in enumerate(loop_ids):
                loop_b = loop_ids[(i + 1) % len(loop_ids)]
                vertex_a = mesh.loops[loop_a].vertex_index
                vertex_b = mesh.loops[loop_b].vertex_index
                world_length_m = (world_points[vertex_a] - world_points[vertex_b]).length
                uv_length = (layer.data[loop_a].uv - layer.data[loop_b].uv).length
                if world_length_m > 1.0e-4:
                    ratios.append(uv_length / world_length_m)
        ratios.sort()
        if ratios:
            uv_layers.append(dict(name=layer.name, uv_min=uv_min, uv_max=uv_max, uv_span=uv_span,
                                  world_bounds_m=bounds, world_dimensions_m=dims,
                                  uv_per_world_m_edge_median=ratios[len(ratios)//2],
                                  uv_per_world_m_edge_min=ratios[0], uv_per_world_m_edge_max=ratios[-1],
                                  measured_non_degenerate_edge_count=len(ratios)))
    return uv_layers


def collect_materials(data):
    scene = bpy.data.scenes.get('02_VariantC_Cutaway')
    assert scene, 'Missing source cutaway scene'
    all_rows = [(index, row) for index, row in enumerate(data['placements']) if row.get('tile') == 'Ossuary']
    omitted = [(index, row) for index, row in all_rows
               if 'ceiling' in row.get('role', '').lower() or row.get('context_proxy')]
    rows = [(index, row) for index, row in all_rows if (index, row) not in omitted]
    instances = {obj.name: obj for obj in scene.objects if obj.instance_type == 'COLLECTION'}
    used = {'TX01': [], 'TX02': []}
    material_objects = {}
    for index, placement in rows:
        object_name = placement['id'] + '_Assembly_' + str(index)
        instance = instances.get(object_name)
        assert instance and instance.instance_collection, ('Missing exact source placement instance', object_name)
        collection = instance.instance_collection
        for part in collection.objects:
            if part.type != 'MESH':
                continue
            for slot_index, slot in enumerate(part.material_slots):
                material = slot.material
                key = material.get('catalog_key') if material else None
                if key not in used:
                    continue
                material_objects[key] = material
                used[key].append(dict(placement_index=index, placement_id=placement['id'], role=placement.get('role'),
                                      instance=instance.name, prototype_collection=collection.name,
                                      part=part.name, mesh=part.data.name, material_slot=slot_index,
                                      material_name=material.name, uv=mesh_uv_profile(part, slot_index, instance)))
    return all_rows, rows, omitted, used, material_objects


def camera_record(scene_name):
    scene = bpy.data.scenes.get(scene_name)
    if not scene:
        return dict(scene=scene_name, present=False)
    camera = scene.camera
    if not camera:
        return dict(scene=scene_name, present=True, camera=None)
    direction = camera.matrix_world.to_quaternion() @ Vector((0.0, 0.0, -1.0))
    data = camera.data
    return dict(scene=scene_name, present=True, camera=camera.name,
                location=list(camera.matrix_world.translation), rotation_euler=list(camera.rotation_euler),
                forward=list(direction), camera_type=data.type, lens_mm=float(data.lens),
                fov_horizontal_deg=float(data.angle_x * 180.0 / 3.141592653589793),
                ortho_scale=float(data.ortho_scale), resolution=[scene.render.resolution_x, scene.render.resolution_y],
                resolution_percentage=scene.render.resolution_percentage,
                view_transform=scene.view_settings.view_transform)


def main():
    assert SOURCE.is_file() and sha(SOURCE) == EXPECTED_SOURCE_SHA256, 'Source Diorama hash differs from reviewed input'
    assert PLACEMENTS.is_file()
    source_hash = sha(SOURCE)
    placement_hash = sha(PLACEMENTS)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    data = json.loads(PLACEMENTS.read_text(encoding='utf-8-sig'))
    ossuary_all_rows, ossuary_rows, omitted_rows, used, material_objects = collect_materials(data)
    assert used['TX01'] and used['TX02'], ('Expected both source materials on Ossuary placements',
                                           len(used['TX01']), len(used['TX02']))
    materials = {key: material_record(material) for key, material in material_objects.items()}
    uv_profiles = {}
    for key in ('TX01', 'TX02'):
        signatures = {}
        for usage in used[key]:
            for uv in usage['uv']:
                signature = (usage['mesh'], usage['material_slot'], uv['name'],
                             tuple(round(x, 5) for x in uv['world_dimensions_m']),
                             tuple(round(x, 5) for x in uv['uv_span']))
                signatures[str(signature)] = uv
        uv_profiles[key] = list(signatures.values())
    receipt = dict(schema=1, source_blend=str(SOURCE.relative_to(ROOT)), source_blend_sha256=source_hash,
                   placements_file=str(PLACEMENTS.relative_to(ROOT)), placements_sha256=placement_hash,
                   blend_scenes=sorted(scene.name for scene in bpy.data.scenes),
                   ossuary_source_placement_count=len(ossuary_all_rows),
                   ossuary_scene_instance_count=len(ossuary_rows),
                   omitted_by_builder=[dict(index=index, id=row['id'], role=row.get('role'))
                                        for index, row in omitted_rows],
                   ossuary_material_usage={key: dict(count=len(used[key]), usages=used[key],
                                                      distinct_mesh_slot_uv_profiles=uv_profiles[key])
                                           for key in ('TX01', 'TX02')},
                   material_graphs=materials,
                   original_cameras=[camera_record(name) for name in SCENES],
                   tiling_interpretation='UV spans and world dimensions are emitted per mesh/material slot. Repeat per 2 m is claimed only if the actual UV-to-world scale supports it; this inspection does not alter UVs or materials.')
    assert sha(SOURCE) == source_hash and sha(PLACEMENTS) == placement_hash, 'Read-only source changed during inspection'
    OUT.mkdir(parents=True, exist_ok=True)
    assert not RECEIPT.exists() and not REPORT.exists(), 'Refuse to overwrite prior inspection outputs'
    RECEIPT.write_text(json.dumps(receipt, sort_keys=True, indent=2, allow_nan=False) + '\n', encoding='utf-8')
    lines = ['# Ossuary TX01/TX02 source material inspection', '',
             f"Source: `{receipt['source_blend']}` ({source_hash})",
             f"Placements ledger: `{receipt['placements_file']}` ({placement_hash})",
             f"Ossuary source placement rows: {len(ossuary_all_rows)}; instantiated in cutaway: {len(ossuary_rows)}; omitted by builder: {len(omitted_rows)}.", '']
    for key in ('TX01', 'TX02'):
        graph = materials[key]['properties']
        lines += [f"## {key} — {graph['name']}", '',
             f"Usage slots: {len(used[key])}; distinct mesh/UV profiles: {len(uv_profiles[key])}.",
                  f"Graph nodes: {len(materials[key]['nodes'])}; links: {len(materials[key]['links'])}.", '']
        for node in materials[key]['nodes']:
            if 'image' in node:
                image = node['image']
                lines.append(f"- Image `{image['name']}`: {image['size']} px, {image['colorspace']}, extension {node['sampling']['extension']}, interpolation {node['sampling']['interpolation']}.")
            elif node['type'] in ('TEX_COORD', 'MAPPING'):
                lines.append(f"- {node['type']} `{node['name']}`: {json.dumps(node.get('mapping', node.get('outputs')), sort_keys=True)}")
        lines.append('')
        lines.append('Graph connections:')
        for link in materials[key]['links']:
            lines.append(f"- `{link['from_node']}.{link['from_socket']}` → `{link['to_node']}.{link['to_socket']}`")
        lines.append('')
        target_role = 'source floor veneer' if key == 'TX02' else 'source exposed wall veneer'
        examples = [usage for usage in used[key] if usage.get('role') == target_role and usage['uv']]
        if examples:
            sample = examples[0]
            uv = sample['uv'][0]
            lines.append(f"Representative `{target_role}`: `{sample['placement_id']}` / `{sample['prototype_collection']}` / `{sample['mesh']}`, bounds {uv['world_dimensions_m']} m, UV span {uv['uv_span']}, edge ratio median/min/max {uv['uv_per_world_m_edge_median']:.4g}/{uv['uv_per_world_m_edge_min']:.4g}/{uv['uv_per_world_m_edge_max']:.4g} UV/m ({uv['measured_non_degenerate_edge_count']} edges).")
        else:
            for uv in uv_profiles[key][:2]:
                lines.append(f"- UV `{uv['name']}` spans {uv['uv_span']}; edge-derived UV/world ratio median/min/max {uv['uv_per_world_m_edge_median']:.4g}/{uv['uv_per_world_m_edge_min']:.4g}/{uv['uv_per_world_m_edge_max']:.4g} UV/m from {uv['measured_non_degenerate_edge_count']} edges.")
        lines.append('')
    for camera in receipt['original_cameras']:
        if camera.get('camera'):
            lines += [f"- Camera `{camera['scene']}` / `{camera['camera']}`: location {camera['location']}, forward {camera['forward']}, projection {camera['camera_type']}."]
    lines += ['', 'No source blend or placement ledger was saved or modified. UV repeat is reported from observed data, not inferred from material names.']
    REPORT.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('OSSUARY_MATERIAL_INSPECTION_COMPLETE', len(ossuary_all_rows), len(ossuary_rows),
          len(used['TX01']), len(used['TX02']), flush=True)


main()
