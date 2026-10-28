"""Headless, derived-only multi-height room study using accepted packed PBR.

The studio lighting and reconstructed source cubes are geometry review aids;
this does not claim native lighting, source prop, water or gameplay parity.
"""
import argparse
import collections
import hashlib
import importlib.util
import json
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev'


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def load_module(name):
    s = importlib.util.spec_from_file_location('_study_'+name, HERE/(name+'.py'))
    m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
    return m


def main():
    import bpy
    import bmesh
    from mathutils import Vector
    p = argparse.ArgumentParser(); p.add_argument('--regions', required=True); p.add_argument('--output', required=True)
    args = p.parse_args(sys.argv[sys.argv.index('--')+1:])
    manifest = (ROOT/args.regions).resolve(); out = (ROOT/args.output).resolve()
    assert manifest.is_relative_to(DOC.resolve()) and out.is_relative_to(DOC.resolve()) and not out.exists()
    r = json.loads(manifest.read_text(encoding='utf-8'))
    assert r['status'] == 'DERIVED_MULTI_ELEVATION_SOURCE_SUPPORTED_ROOM_REVIEW_REQUIRED'
    assert all(sha(ROOT/k) == v for k, v in r['inputs'].items())
    guard = load_module('room_art_capture_r33'); guard.guard()
    geometry = load_module('room_surface_regions_r03')
    source = HERE/'Output/WarrensVariantC_Diorama.blend'
    source_hash = sha(source)
    assert source_hash == 'dc5a4116558c47dc70e1da898179daf71993780e845c3f3bdb67b6d770dac44d'
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene; scene.name = r['room']['id'].title()+'_SourceSupported_Study_R01'
    material_names = ['CP21_CatacombPilot_R02_Paint_'+v for v in ('walls', 'floor', 'ceiling')]+['CP21_CatacombPilot_R02_QuietMortar']
    with bpy.data.libraries.load(str(source), link=False) as (available, data):
        assert all(v in available.materials for v in material_names)
        data.materials = material_names
    mats = dict(zip(('walls', 'floor', 'ceiling', 'mortar'), data.materials))
    assert all(im.packed_file for im in bpy.data.images if im.source == 'FILE')
    prefix = r['room']['id'].title()+'_SurfaceStudy_R01_'
    def neutral(name, colour, roughness=.9):
        m = bpy.data.materials.new(prefix+name); m.use_nodes = True
        bs = m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value = (*colour, 1); bs.inputs['Roughness'].default_value = roughness
        return m
    context_mat = neutral('SourceContext', (.11, .105, .09))
    source_objects = []
    for b in r['source_boxes']:
        at = [(a+c)/2 for a, c in zip(b['lo'], b['hi'])]
        bpy.ops.mesh.primitive_cube_add(size=1, location=(at[0]-58, 55-at[1], at[2]))
        o = bpy.context.object; o.name = prefix+'Source_'+b['key'].replace(':', '_')
        o.scale = tuple(c-a for a, c in zip(b['lo'], b['hi'])); o.data.materials.append(context_mat)
        source_objects.append(o.name)
    records = []; new_objects = []
    def build_family(family, groups, width, height, front, back):
        bm = bmesh.new(); uv = bm.loops.layers.uv.new('PigmentUV'); colour = bm.loops.layers.float_color.new('StoneTint')
        def position(a, b, depth, axis, sign, plane):
            if family in ('floor', 'ceiling'):
                return (a-58, 55-b, plane+sign*depth)
            v = [0, 0, b]; v[axis] = plane+sign*depth; v[1-axis] = a
            return (v[0]-58, 55-v[1], v[2])
        count = 0
        for gi, group in enumerate(groups):
            axis, sign, plane, rects = [group[k] for k in ('axis', 'sign', 'plane', 'rects')]
            lo = [min(v[k] for v in rects) for k in (0, 1)]; hi = [max(v[k] for v in rects) for k in (2, 3)]
            for iy in range(math.floor(lo[1]/height), math.ceil(hi[1]/height)):
                offset = (iy % 2)*width*.5 if family == 'walls' else 0
                for ix in range(math.floor((lo[0]-offset)/width), math.ceil((hi[0]-offset)/width)):
                    gap = .012
                    cell = [ix*width+offset+gap/2, iy*height+gap/2, (ix+1)*width+offset-gap/2, (iy+1)*height-gap/2]
                    pieces = [part for v in rects if (part := geometry.intersection(v, cell))]
                    if not pieces:
                        continue
                    sb = bmesh.new()
                    for v in pieces:
                        sb.faces.new([sb.verts.new((x-cell[0], y-cell[1], 0)) for x, y in ((v[0], v[1]), (v[2], v[1]), (v[2], v[3]), (v[0], v[3]))])
                    bmesh.ops.remove_doubles(sb, verts=list(sb.verts), dist=1e-6)
                    bmesh.ops.dissolve_limit(sb, angle_limit=.001, verts=list(sb.verts), edges=list(sb.edges), use_dissolve_boundaries=False)
                    rng = random.Random(f'{family}/{gi}/{ix}/{iy}')
                    tone = rng.uniform(.80, 1.12)*(.73 if family == 'ceiling' else 1)
                    tint = (tone*rng.uniform(.97, 1.03), tone*rng.uniform(.96, 1.02), tone*rng.uniform(.95, 1.02), 1)
                    phase = (rng.uniform(0, 8), rng.uniform(0, 8)); rot = rng.randrange(4)
                    for sf in sb.faces:
                        coords = [(float(v.co.x)+cell[0], float(v.co.y)+cell[1]) for v in sf.verts]
                        vertices0 = [bm.verts.new(position(a, b, back, axis, sign, plane)) for a, b in coords]
                        vertices1 = [bm.verts.new(position(a, b, front, axis, sign, plane)) for a, b in coords]
                        faces = [bm.faces.new(list(reversed(vertices0))), bm.faces.new(vertices1)]
                        for j in range(len(coords)):
                            k = (j+1) % len(coords)
                            faces.append(bm.faces.new((vertices0[j], vertices0[k], vertices1[k], vertices1[j])))
                        for face in faces:
                            for loop in face.loops:
                                co = loop.vert.co
                                a, b = (co.x+58, 55-co.y) if family != 'walls' else ((55-co.y if axis == 0 else co.x+58), co.z)
                                for unused in range(rot):
                                    a, b = -b, a
                                repeat = 1.8 if family == 'walls' else 1
                                loop[uv].uv = ((a+phase[0])/repeat, (b+phase[1])/repeat); loop[colour] = tint
                        count += 1
                    sb.free()
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        # Horizontal concave cell unions must keep their exact footprint.
        # BMesh bevel generated tiny corner triangles outside that union in
        # R02; controlled normals and the independent PBR carry floor detail.
        if family == 'walls':
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=.0025, segments=1, affect='EDGES', clamp_overlap=True)
        mesh = bpy.data.meshes.new(prefix+family+'_Mesh'); bm.to_mesh(mesh); bm.free(); mesh.update()
        if family in ('floor', 'ceiling'):
            for polygon in mesh.polygons:
                polygon.use_smooth = True
            mesh.normals_split_custom_set([(0, 0, 1 if family == 'floor' else -1)]*len(mesh.loops)); mesh.update()
        o = bpy.data.objects.new(prefix+family, mesh); scene.collection.objects.link(o); mesh.materials.append(mats[family]); new_objects.append(o)
        records.append(dict(family=family, name=o.name, stones=count, vertices=len(mesh.vertices), faces=len(mesh.polygons), groups=groups, front=front, back=back))
        verts = []; faces = []
        for group in groups:
            for rect in group['rects']:
                n = len(verts)
                quad = [position(a, b, back+.0001, group['axis'], group['sign'], group['plane']) for a, b in ((rect[0], rect[1]), (rect[2], rect[1]), (rect[2], rect[3]), (rect[0], rect[3]))]
                normal = (Vector(quad[1])-Vector(quad[0])).cross(Vector(quad[2])-Vector(quad[0]))
                expected = Vector((0, 0, group['sign'])) if family != 'walls' else Vector((group['sign'], 0, 0) if group['axis'] == 0 else (0, -group['sign'], 0))
                faces.append(tuple(n+i for i in ((0, 1, 2, 3) if normal.dot(expected) > 0 else (3, 2, 1, 0)))); verts += quad
        backing = bpy.data.meshes.new(prefix+family+'_BackingMesh'); backing.from_pydata(verts, [], faces); backing.update()
        o = bpy.data.objects.new(prefix+family+'_Backing', backing); scene.collection.objects.link(o); backing.materials.append(mats['mortar']); new_objects.append(o)
    wall_groups = collections.defaultdict(list)
    for f in r['wall_faces']:
        wall_groups[f['axis'], f['normal_sign'], f['plane']].append([f['tangent_bounds'][0], f['z_bounds'][0], f['tangent_bounds'][1], f['z_bounds'][1]])
    build_family('walls', [dict(axis=a, sign=s, plane=p, rects=rs) for (a, s, p), rs in sorted(wall_groups.items())], .9, .5, .018, .013)
    for family, field, sign, width, height, front, back in [('floor', 'admitted_floor_cells', 1, 1, .8, .012, .009), ('ceiling', 'ceiling_faces', -1, 1.2, .9, .018, .013)]:
        groups = collections.defaultdict(list)
        for c in r[field]:
            groups[c['z']].append(c['rect'])
        build_family(family, [dict(axis=2, sign=sign, plane=z, rects=rs) for z, rs in sorted(groups.items())], width, height, front, back)
    # Clearly marked geometry-study lights, not a proposed native light rig.
    for name, at, target, power, size in [('SurveyKey', [119, 38, 4], [120, 43, -1], 2200, 9), ('SurveyFill', [125, 43, 2], [118, 40, 0], 1000, 7), ('UpperSurvey', [117, 43, 9], [118, 44, 3], 1600, 8)]:
        d = bpy.data.lights.new(prefix+name, 'AREA'); d.energy = power; d.shape = 'DISK'; d.size = size
        o = bpy.data.objects.new(d.name, d); scene.collection.objects.link(o); o.location = (at[0]-58, 55-at[1], at[2]); o.rotation_euler = (Vector((target[0]-58, 55-target[1], target[2]))-o.location).to_track_quat('-Z', 'Y').to_euler()
    assert r['room']['id'] == 'larder', 'Review and declare room-specific cameras before using other rooms'
    views = [('arrival', [116, 35, -1.777], [122, 43, -.5]), ('bank_ledge', [124, 46, -1.777], [120, 51, -.4]), ('storage', [126.8, 37.5, -1.377], [134, 38, -.8]), ('upper_window', [120, 40, -1.777], [109.8, 46.3, 8])]
    scene.render.engine = 'BLENDER_EEVEE'; scene.eevee.taa_render_samples = 128; scene.eevee.shadow_ray_count = 4
    scene.render.resolution_x = 1250; scene.render.resolution_y = 813; scene.render.resolution_percentage = 100; scene.render.image_settings.file_format = 'PNG'
    scene.world = bpy.data.worlds.new(prefix+'World'); scene.world.use_nodes = True; scene.world.node_tree.nodes.get('Background').inputs['Color'].default_value = (.10, .12, .14, 1); scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value = .15
    scene.view_settings.view_transform = 'AgX'; scene.view_settings.look = 'AgX - Medium High Contrast'
    out.mkdir(parents=True); frames = []
    for label, at, target in views:
        d = bpy.data.cameras.new(prefix+label); d.type = 'PERSP'; d.lens = 18; d.sensor_width = 36; d.clip_start = .05; d.clip_end = 200
        o = bpy.data.objects.new(d.name, d); scene.collection.objects.link(o); o.location = (at[0]-58, 55-at[1], at[2]); o.rotation_euler = (Vector((target[0]-58, 55-target[1], target[2]))-o.location).to_track_quat('-Z', 'Y').to_euler(); scene.camera = o
        bpy.context.view_layer.update(); scene.render.filepath = str(out/(label+'.png')); bpy.ops.render.render(write_still=True)
        frames.append(dict(view=label, file=label+'.png', sha256=sha(out/(label+'.png')), camera_plan=at, target_plan=target, actual_matrix=[list(v) for v in o.matrix_world]))
        print('ROOM_STUDY_FRAME', label, flush=True)
    path = out/(r['room']['id'].title()+'_SurfaceStudy_R01.blend'); bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)
    guard.guard(); assert sha(source) == source_hash
    receipt = dict(status='DERIVED_SURFACE_STUDY_ONLY_NOT_COMPLETE_ROOM_OR_NATIVE_ACCEPTANCE', manifest=manifest.relative_to(ROOT).as_posix(), manifest_sha256=sha(manifest), canonical_source_sha256=source_hash, derived_sha256=sha(path), tool_sha256=sha(__file__), geometry=records, source_objects=source_objects, frames=frames,
                   boundary='New isolated scene, accepted packed PBR stone parents and controlled horizontal normals. Exact current-native greybox context; multi-elevation source-supported veneers. Studio survey light, no water sheet or props: bed and bank exposure is intentional geometry inspection. No original Blender/map/asset/lighting/collision modifications. Native appearance and source prop/water consistency remain unverified.')
    (out/'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8'); print('ROOM_STUDY_COMPLETE', sha(out/'receipt.json'), flush=True)


if __name__ == '__main__':
    main()
