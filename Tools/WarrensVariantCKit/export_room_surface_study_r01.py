"""Export only three audited derived room meshes; originals remain read-only."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    import bpy
    from mathutils import Vector
    p=argparse.ArgumentParser();p.add_argument('--study',required=True);p.add_argument('--output',required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);folder=(ROOT/a.study).resolve();out=(ROOT/a.output).resolve()
    assert out.is_relative_to((ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev').resolve()) and not out.exists()
    receipt=json.loads((folder/'receipt.json').read_text());source=folder/'Larder_SurfaceStudy_R01.blend';assert Path(bpy.data.filepath).resolve()==source and sha(source)==receipt['derived_sha256']
    audit_path=folder/'full_triangle_coverage_r02.json';audit=json.loads(audit_path.read_text());assert audit['derived_sha256']==sha(source) and audit['manifest_sha256']==receipt['manifest_sha256'] and len(audit['checks'])==3 and all(v['all_triangles_inside_reviewed_shells_with_float32_boundary_budget'] for v in audit['checks'])
    path=ROOT/receipt['manifest'];assert sha(path)==receipt['manifest_sha256'];r=json.loads(path.read_text())
    assert r['room']['id']=='larder';pivot=[120,40,-2.5];blender_pivot=Vector((pivot[0]-58,55-pivot[1],pivot[2]))
    export=bpy.data.scenes.new('Larder_RoomSurface_Export_R01');bpy.context.window.scene=export;export.unit_settings.system='METRIC';export.unit_settings.scale_length=.01
    out.mkdir(parents=True);rows=[]
    for record in receipt['geometry']:
        family=record['family'];copies=[]
        for name in (record['name'],record['name']+'_Backing'):
            original=bpy.data.objects[name];o=original.copy();o.data=original.data.copy();export.collection.objects.link(o)
            for v in o.data.vertices:v.co=(v.co-blender_pivot)*100
            for attr in o.data.color_attributes:
                if attr.name=='StoneTint':
                    for d in attr.data:d.color=tuple(v/1.2 for v in d.color[:3])+(d.color[3],)
            o.select_set(True);copies.append(o)
        bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();o=copies[0];o.name='WVC_Larder_'+family.title()+'_R01_SM';o.data.name=o.name;o.data.calc_loop_triangles()
        assert len(o.data.materials)==2
        lo=[min(v.co[k] for v in o.data.vertices) for k in range(3)];hi=[max(v.co[k] for v in o.data.vertices) for k in range(3)]
        path=out/(o.name+'.fbx');bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_NONE',axis_forward='-Y',axis_up='Z',use_mesh_modifiers=False,mesh_smooth_type='FACE',use_triangles=True,bake_anim=False,path_mode='STRIP',use_custom_props=True,colors_type='LINEAR')
        rows.append(dict(family=family,name=o.name,file=path.relative_to(ROOT).as_posix(),sha256=sha(path),vertices=len(o.data.vertices),triangles=len(o.data.loop_triangles),materials=[v.name for v in o.data.materials],unreal_bounds_min_cm=[lo[0],-hi[1],lo[2]],unreal_bounds_max_cm=[hi[0],-lo[1],hi[2]],placement_plan=pivot,placement_main_cm=[5000,-1500,-250],placement_brineworks_li_cm=[3200,3600,0],collision='NoCollision',uv_layers=[v.name for v in o.data.uv_layers],colours=[dict(name=v.name,type=v.data_type,domain=v.domain) for v in o.data.color_attributes],vertex_color_export_gain=1/1.2))
        bpy.data.objects.remove(o,do_unlink=True)
    assert sha(source)==receipt['derived_sha256']
    result=dict(status='AUDITED_DERIVED_FBX_EXPORT_ONLY_NOT_NATIVE_ACCEPTED',study_receipt_sha256=sha(folder/'receipt.json'),triangle_audit_sha256=sha(audit_path),manifest_sha256=receipt['manifest_sha256'],tool_sha256=sha(__file__),exports=rows,
                boundary='Three FBX files only, no original Blender save or native asset import. Joined backing and existing PBR-family stone, controlled horizontal normals and accepted native vertex colour normalization. Native bounds/triangle/slot/UV/normal/colour/no-collision readback and actual PIE review still required.')
    (out/'export.json').write_text(json.dumps(result,indent=2)+'\n');print('THREE_ROOM_FBX_EXPORTED',[(v['family'],v['triangles']) for v in rows],sha(out/'export.json'),flush=True)


if __name__=='__main__':main()
