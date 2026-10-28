"""Export audited room studies without changing the saved study or native assets."""
import argparse
import hashlib
import json
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
    parser.add_argument('--study', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    folder = (ROOT/args.study).resolve()
    out = (ROOT/args.output).resolve()
    assert out.is_relative_to((ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev').resolve()) and not out.exists()
    receipt = json.loads((folder/'receipt.json').read_text())
    manifest = ROOT/receipt['manifest']
    assert sha(manifest) == receipt['manifest_sha256']
    regions = json.loads(manifest.read_text())
    room = regions['room']['id']
    source = folder/(room.title()+'_SurfaceStudy_R01.blend')
    assert Path(bpy.data.filepath).resolve() == source and sha(source) == receipt['derived_sha256']
    audit_path = folder/'full_triangle_coverage_r03.json'
    audit = json.loads(audit_path.read_text())
    assert audit['derived_sha256'] == sha(source) and audit['manifest_sha256'] == sha(manifest)
    assert len(audit['checks']) == 3 and all(v['all_triangles_inside_reviewed_shells_with_float32_boundary_budget'] for v in audit['checks'])
    for path, digest in regions['inputs'].items():
        assert sha(ROOT/path) == digest
    # Keep centimetre coordinates small. UVs are copied unchanged; only the
    # explicit Main-world placement is declared, with no guessed LI transform.
    polygon = regions['ownership'][0]['poly']
    plan_pivot = [round(sum(v[k] for v in polygon)/len(polygon)) for k in (0, 1)]+[regions['room']['z']]
    pivot = Vector((plan_pivot[0]-58, 55-plan_pivot[1], plan_pivot[2]))
    scene = bpy.data.scenes.new(room.title()+'_AuditedSurface_Export_R01')
    bpy.context.window.scene = scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = .01
    out.mkdir(parents=True)
    rows = []
    for record in receipt['geometry']:
        family = record['family']
        copies = []
        for name in (record['name'], record['name']+'_Backing'):
            original = bpy.data.objects[name]
            obj = original.copy()
            obj.data = original.data.copy()
            scene.collection.objects.link(obj)
            for vertex in obj.data.vertices:
                vertex.co = (vertex.co-pivot)*100
            for attribute in obj.data.color_attributes:
                if attribute.name == 'StoneTint':
                    for datum in attribute.data:
                        datum.color = tuple(v/1.2 for v in datum.color[:3])+(datum.color[3],)
            obj.select_set(True)
            copies.append(obj)
        bpy.context.view_layer.objects.active = copies[0]
        bpy.ops.object.join()
        obj = copies[0]
        obj.name = 'WVC_'+room.title()+'_'+family.title()+'_R01_SM'
        obj.data.name = obj.name
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        if family in ('floor', 'ceiling'):
            sign = 1 if family == 'floor' else -1
            for polygon in obj.data.polygons:
                polygon.use_smooth = True
            obj.data.normals_split_custom_set([(0, 0, sign)]*len(obj.data.loops))
            obj.data.update()
            assert all(n.vector.z*sign > .9999 for n in obj.data.corner_normals)
        obj.data.calc_loop_triangles()
        assert len(obj.data.materials) == 2 and len(obj.data.uv_layers) == 1
        low = [min(v.co[k] for v in obj.data.vertices) for k in range(3)]
        high = [max(v.co[k] for v in obj.data.vertices) for k in range(3)]
        path = out/(obj.name+'.fbx')
        bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={'MESH'}, global_scale=1, apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE', axis_forward='-Y', axis_up='Z', use_mesh_modifiers=False, mesh_smooth_type='FACE', use_triangles=False, bake_anim=False, path_mode='STRIP', use_custom_props=True, colors_type='LINEAR')
        rows.append(dict(family=family, name=obj.name, file=path.relative_to(ROOT).as_posix(), sha256=sha(path), vertices=len(obj.data.vertices), triangles=len(obj.data.loop_triangles), materials=[v.name for v in obj.data.materials], unreal_bounds_min_cm=[low[0], -high[1], low[2]], unreal_bounds_max_cm=[high[0], -low[1], high[2]], placement_plan=plan_pivot, placement_main_cm=[(plan_pivot[0]-70)*100, (plan_pivot[1]-55)*100, plan_pivot[2]*100], uv_channels=1, collision='NoCollision', vertex_color_gain=1/1.2))
        bpy.data.objects.remove(obj, do_unlink=True)
    assert sha(source) == receipt['derived_sha256']
    result = dict(status='DERIVED_FBX_ONLY_REQUIRES_FRESH_FBX_AND_NATIVE_REVIEW', room=room, study=folder.relative_to(ROOT).as_posix(), study_sha256=sha(source), receipt_sha256=sha(folder/'receipt.json'), manifest_sha256=sha(manifest), coverage_audit_sha256=sha(audit_path), tool_sha256=sha(__file__), exports=rows, boundary='Separate derived exports only. No import, source or library save. Saved study palette/PBR remains the material source; generic native materials do not automatically reproduce room palette. Original physical geometry, room ownership and connector exclusions remain unchanged. Shared/context finish is a separate unresolved rollout obligation.')
    (out/'export.json').write_text(json.dumps(result, indent=2)+'\n')
    print('AUDITED_ROOM_EXPORTED', room, [(v['family'], v['triangles']) for v in rows], flush=True)


if __name__ == '__main__':
    main()
