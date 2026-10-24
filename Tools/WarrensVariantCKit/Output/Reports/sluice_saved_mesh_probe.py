"""Read saved library geometry only; do not construct, update, or save assets."""
import json
import math
import copy
import hashlib
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Vector
from mathutils.bvhtree import BVHTree

OUT = Path(__file__).resolve().parent
HERE = OUT.parents[1]


def material_key(obj, index):
    mat = obj.data.materials[index]
    return str(mat.get('catalog_key', ''))


def mesh(ident):
    cols = [c for c in bpy.data.collections if c.name.startswith(ident + '_')]
    candidates = [(c, o) for c in cols for o in c.all_objects
                  if o.type == 'MESH' and o.get('catalog_id') == ident]
    assert candidates, ident
    c, o = candidates[0]
    assert all((o.matrix_world[i][j] - float(i == j)) ** 2 < 1e-12
               for i in range(4) for j in range(4)), ident
    faces = [p for p in o.data.polygons if material_key(o, p.material_index) == 'TX08']
    assert faces, (ident, [material_key(o, i) for i in range(len(o.data.materials))])
    used = sorted({i for p in faces for i in p.vertices})
    return dict(collection=c.name, object=o.name,
                vertices={str(i): list(o.data.vertices[i].co) for i in used},
                faces=[dict(index=p.index, vertices=list(p.vertices), normal=list(p.normal)) for p in faces],
                all_bounds=[[min(v.co[k] for v in o.data.vertices) for k in range(3)],
                            [max(v.co[k] for v in o.data.vertices) for k in range(3)]])


def main_component(m):
    remaining = {int(i) for i in m['vertices']}
    components = []
    while remaining:
        component = {remaining.pop()}
        while True:
            expanded = component | {i for f in m['faces'] if component.intersection(f['vertices']) for i in f['vertices']}
            if expanded == component:
                break
            component = expanded
        remaining -= component
        components.append(component)
    used = max(components, key=len)
    return {i: Vector(m['vertices'][str(i)]) for i in used}, [f for f in m['faces'] if set(f['vertices']).issubset(used)]


def matrix(row):
    # build_kit.py:69-72 uses [roll,-pitch,-yaw] Euler XYZ, then
    # Blender Y=-planY. Keep plan coordinates here by undoing that reflection.
    r = row.get('rotation')
    angles = [r[2], -r[0], -r[1]] if r else [0, 0, -row.get('yaw', 0)]
    rot = Euler(tuple(math.radians(a) for a in angles), 'XYZ').to_matrix()
    reflect = Matrix.Diagonal(Vector((1, -1, 1)))
    scale = Matrix.Diagonal(Vector(row.get('scale', (1, 1, 1))))
    return reflect @ rot @ scale


def transform(vertices, row):
    m = matrix(row)
    at = Vector(row['at'])
    return {i: at + m @ v for i, v in vertices.items()}


def surface(vertices, faces, row):
    points = transform(vertices, row)
    ids = sorted(points)
    remap = {j: i for i, j in enumerate(ids)}
    bvh = BVHTree.FromPolygons([points[i] for i in ids], [[remap[i] for i in f['vertices']] for f in faces])
    center = sum(points.values(), Vector()) / len(points)
    planes = []
    for f in faces:
        p = [points[i] for i in f['vertices']]
        normal = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
        midpoint = sum(p, Vector()) / len(p)
        if normal.dot(midpoint - center) < 0:
            normal.negate()
        planes.append((normal, p[0], f['index']))
    assert max(normal.dot(point - origin) for normal, origin, _ in planes for point in points.values()) < 3e-5, 'Support component is not convex'
    return bvh, planes, points


def cap_check(vertices, cap, row, target_vertices, target_faces, target_row):
    points = transform(vertices, row)
    bvh, planes, _ = surface(target_vertices, target_faces, target_row)
    records = []
    for i in cap['vertices']:
        point = points[i]
        signed = [(normal.dot(point - origin), index) for normal, origin, index in planes]
        nearest, normal, face, distance = bvh.find_nearest(point)
        records.append(dict(vertex=i, point_plan_m=list(point),
                            max_outward_plane_distance_m=max(d for d, _ in signed),
                            nearest_actual_wood_surface_m=distance,
                            nearest_point_plan_m=list(nearest), nearest_component_face=face))
    return dict(source_face=cap['index'], vertices=records,
                all_vertices_strictly_inside=all(r['max_outward_plane_distance_m'] < -1e-6 for r in records),
                minimum_actual_surface_distance_m=min(r['nearest_actual_wood_surface_m'] for r in records))


def audit(result):
    beam_vertices, beam_faces = main_component(result['meshes']['CCS86'])
    brace_vertices, brace_faces = main_component(result['meshes']['CCS87'])
    min_x = min(v.x for v in brace_vertices.values())
    max_z = max(v.z for v in brace_vertices.values())
    low = [f for f in brace_faces if all(abs(brace_vertices[i].x - min_x) < 1e-6 for i in f['vertices'])]
    high = [f for f in brace_faces if all(abs(brace_vertices[i].z - max_z) < 1e-6 for i in f['vertices'])]
    assert len(low) == len(high) == 1, (low, high)
    rows = json.loads((HERE / 'Output/fitted_instances.json').read_text())['placements']
    posts = [r for r in rows if r['tile'] == 'Brineworks' and r['id'] == 'CCS86'
             and r.get('rotation') == [90, 0, 0] and r['at'][0] in [116, 120, 124, 128]]
    header = [r for r in rows if r['role'] == 'Sluice supported continuous timber header']
    assert len(posts) == 4 and len(header) == 1
    header = header[0]
    embed = .04  # visual join allowance chosen by main, not a structural requirement.
    checks = []
    braces = [r for r in rows if r['tile'] == 'Brineworks' and r['id'] == 'CCS87'
              and r['role'] == 'Sluice post-to-header brace']
    assert len(braces) == 4
    for post in sorted(posts, key=lambda r: r['at'][0]):
        px = post['at'][0]
        proposed = min(braces, key=lambda r: abs(r['at'][0] - px))
        _, _, world_post = surface(beam_vertices, beam_faces, post)
        right = px < 128
        side = max(v.x for v in world_post.values()) if right else min(v.x for v in world_post.values())
        recommendation = copy.deepcopy(proposed)
        # Source low end uses X=minX, high end uses Z=maxZ; the mirrored last
        # brace addresses the left side of the asymmetrically pivoted post.
        recommendation['at'][0] = side - embed - min_x if right else side + embed + min_x
        recommendation['at'][2] = header['at'][2] + embed - max_z
        before_low = cap_check(brace_vertices, low[0], proposed, beam_vertices, beam_faces, post)
        before_high = cap_check(brace_vertices, high[0], proposed, beam_vertices, beam_faces, header)
        after_low = cap_check(brace_vertices, low[0], recommendation, beam_vertices, beam_faces, post)
        after_high = cap_check(brace_vertices, high[0], recommendation, beam_vertices, beam_faces, header)
        assert after_low['all_vertices_strictly_inside'] and after_high['all_vertices_strictly_inside'], (px, after_low, after_high)
        checks.append(dict(post=post, provisional_brace=proposed, recommended_brace=recommendation,
                           post_contact_side_x_m=side,
                           provisional_low=before_low, provisional_high=before_high,
                           recommended_low=after_low, recommended_high=after_high))
        print('SLUICE_CONTACT', px, recommendation['at'],
              'min_actual_distance_low/high_m', after_low['minimum_actual_surface_distance_m'],
              after_high['minimum_actual_surface_distance_m'], flush=True)
    result['contact_audit'] = dict(axial_visual_embed_m=embed, header=header,
                                   beam_component_vertices=len(beam_vertices), beam_component_faces=len(beam_faces),
                                   brace_component_vertices=len(brace_vertices), brace_component_faces=len(brace_faces),
                                   low_endcap=low[0], header_endcap=high[0], checks=checks)


def main():
    result = dict(saved_blend=bpy.data.filepath, scenes=[s.name for s in bpy.data.scenes],
                  meshes={ident: mesh(ident) for ident in ['CCS86', 'CCS87']})
    result['saved_blend_sha256'] = hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()
    for ident, m in result['meshes'].items():
        points = list(m['vertices'].values())
        print(ident, 'TX08 bounds', [[min(p[k] for p in points) for k in range(3)],
                                   [max(p[k] for p in points) for k in range(3)]], flush=True)
    audit(result)
    (OUT / 'sluice_saved_mesh_geometry.json').write_text(json.dumps(result, indent=2))
    print('SLUICE_READ_ONLY_GEOMETRY_COMPLETE', flush=True)


if __name__ == '__main__':
    main()
