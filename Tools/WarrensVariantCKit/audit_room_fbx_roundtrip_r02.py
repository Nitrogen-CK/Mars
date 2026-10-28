"""Fresh FBX triangle/corner correspondence against the audited study mesh."""
import argparse
import collections
import hashlib
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    import bpy
    import bmesh
    from mathutils import Vector
    parser = argparse.ArgumentParser()
    parser.add_argument('--export', required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    folder = (ROOT/args.export).resolve()
    manifest = json.loads((folder/'export.json').read_text())
    assert sha(ROOT/'Tools/WarrensVariantCKit/export_room_surface_study_r06.py') == manifest['tool_sha256']
    study = ROOT/manifest['study']
    receipt = json.loads((study/'receipt.json').read_text())
    assert sha(study/'receipt.json') == manifest['receipt_sha256']
    assert sha(bpy.data.filepath) == manifest['study_sha256']
    records = {r['family']: r for r in receipt['geometry']}
    results = []
    for row in manifest['exports']:
        assert sha(ROOT/row['file']) == row['sha256']
        family = row['family']
        scene = bpy.data.scenes.new('Expected_'+family)
        bpy.context.window.scene = scene
        pivot = row['placement_plan']
        pivot = Vector((pivot[0]-58, 55-pivot[1], pivot[2]))
        copies = []
        for name in (records[family]['name'], records[family]['name']+'_Backing'):
            original = bpy.data.objects[name]
            obj = original.copy()
            obj.data = original.data.copy()
            scene.collection.objects.link(obj)
            for vertex in obj.data.vertices:
                vertex.co = (vertex.co-pivot)*100
            for attribute in obj.data.color_attributes:
                if attribute.name == 'StoneTint':
                    for datum in attribute.data:
                        datum.color = tuple(v/1.2*row['palette_multiplier'][k] for k, v in enumerate(datum.color[:3]))+(datum.color[3],)
            obj.select_set(True)
            copies.append(obj)
        bpy.context.view_layer.objects.active = copies[0]
        bpy.ops.object.join()
        expected = copies[0]
        bm = bmesh.new()
        bm.from_mesh(expected.data)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bm.to_mesh(expected.data)
        bm.free()
        expected.data.update()
        expected.data.calc_loop_triangles()

        def triangles(obj):
            obj.data.calc_loop_triangles()
            uv = obj.data.uv_layers.active.data
            attribute = obj.data.color_attributes.get('StoneTint')
            if attribute is None:
                attribute = obj.data.color_attributes.active_color
            assert attribute is not None and attribute.domain == 'CORNER'
            rgba = attribute.data
            return [dict(points=[tuple(obj.matrix_world @ obj.data.vertices[v].co) for v in tri.vertices], uv=[tuple(uv[v].uv) for v in tri.loops], material=tri.material_index, rgba=[tuple(rgba[v].color) for v in tri.loops]) for tri in obj.data.loop_triangles]

        wanted = triangles(expected)
        expected_names = [m.name for m in expected.data.materials]
        imported_scene = bpy.data.scenes.new('FreshFBX_'+family)
        bpy.context.window.scene = imported_scene
        imported_scene.unit_settings.system = 'METRIC'
        imported_scene.unit_settings.scale_length = .01
        bpy.ops.import_scene.fbx(filepath=str(ROOT/row['file']), use_custom_normals=True, colors_type='LINEAR')
        actual, = [o for o in imported_scene.objects if o.type == 'MESH']
        identity = __import__('mathutils').Matrix.Identity(4)
        matrix_error = max(abs(actual.matrix_world[i][j]-identity[i][j]) for i in range(4) for j in range(4))
        assert matrix_error < 1e-6
        got = triangles(actual)
        assert len(wanted) == len(got) == row['triangles'] and len(actual.data.uv_layers) == 1
        # Material datablocks get .001 suffixes when the study remains loaded.
        assert [m.name.split('.')[0] for m in actual.data.materials] == [m.split('.')[0] for m in expected_names]
        def key(triangle):
            return triangle['material'], tuple(sorted(tuple(round(v*100) for v in p) for p in triangle['points']))
        buckets = collections.defaultdict(list)
        for index, triangle in enumerate(wanted):
            buckets[key(triangle)].append(index)
        maximum_position = maximum_uv = maximum_rgba = 0.
        mappings = []
        for index, triangle in enumerate(got):
            candidates = []
            for other in buckets[key(triangle)]:
                target = wanted[other]
                for shift in range(3):
                    pairs = [(i, (i+shift)%3) for i in range(3)]
                    position_error = max(math.dist(triangle['points'][i], target['points'][j]) for i, j in pairs)
                    uv_error = max(math.dist(triangle['uv'][i], target['uv'][j]) for i, j in pairs)
                    rgba_error = max(abs(triangle['rgba'][i][k]-target['rgba'][j][k]) for i, j in pairs for k in range(4))
                    candidates.append((position_error, uv_error, rgba_error, other, shift))
            position_error, uv_error, rgba_error, other, shift = min(candidates)
            assert position_error <= .001 and uv_error <= 1e-6 and rgba_error <= 1e-6, (family, index, position_error, uv_error)
            buckets[key(triangle)].remove(other)
            maximum_position = max(maximum_position, position_error)
            maximum_uv = max(maximum_uv, uv_error)
            maximum_rgba = max(maximum_rgba, rgba_error)
            mappings.append([index, other, shift, position_error, uv_error, rgba_error])
        assert not any(buckets.values())
        if family in ('floor', 'ceiling'):
            sign = 1 if family == 'floor' else -1
            assert all(n.vector.z*sign > .9999 for n in actual.data.corner_normals)
        result = dict(family=family, triangles=len(got), imported_matrix=list(map(list, actual.matrix_world)), maximum_imported_matrix_identity_error=matrix_error, cyclic_oriented_bijection=True, duplicate_multiplicity_preserved=True, material_associations=True, UV_channels=1, maximum_corner_displacement_cm=maximum_position, maximum_UV_displacement=maximum_uv, maximum_RGBA_displacement=maximum_rgba, palette_multiplier=row['palette_multiplier'], mappings=mappings)
        results.append(result)
        print('FRESH_FBX_CORRESPONDENCE', family, len(got), maximum_position, maximum_uv, maximum_rgba, flush=True)
    output = folder/'fresh_fbx_roundtrip.json'
    assert not output.exists()
    output.write_text(json.dumps(dict(status='FRESH_FBX_FINITE_CORRESPONDENCE_NOT_NATIVE_ACCEPTANCE', export_sha256=sha(folder/'export.json'), study_sha256=manifest['study_sha256'], tool_sha256=sha(__file__), checks=results, boundary='Every imported triangle and UV/material corner maps cyclically to the audited source study after the declared centimetre pivot conversion, including every RGBA corner after the declared room palette multiplication and1/1.2 vertex gain. Position limit .001cm and UV limit1e-6 are roundtrip correspondence checks, not a changed original footprint tolerance. Native appearance, palette bindings and shared context remain unverified.'), indent=2)+'\n')


if __name__ == '__main__':
    main()
