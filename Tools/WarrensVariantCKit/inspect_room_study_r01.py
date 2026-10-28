"""Read-only derived Blender reopen, geometry witness checks and diagnostic rays."""
import argparse
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    import bpy
    from mathutils import Vector
    p=argparse.ArgumentParser();p.add_argument('--study',required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
    study=(ROOT/a.study).resolve();receipt=json.loads((study/'receipt.json').read_text());source=study/'Larder_SurfaceStudy_R01.blend'
    assert Path(bpy.data.filepath).resolve()==source and sha(source)==receipt['derived_sha256']
    path=ROOT/receipt['manifest'];assert sha(path)==receipt['manifest_sha256'];r=json.loads(path.read_text());assert all(sha(ROOT/k)==v for k,v in r['inputs'].items())
    checks=[]
    for record in receipt['geometry']:
        o=bpy.data.objects[record['name']];failures=[];family=record['family']
        assert len(o.data.vertices)==record['vertices'] and len(o.data.polygons)==record['faces']
        for v in o.data.vertices:
            x,y,z=v.co.x+58,55-v.co.y,v.co.z
            if family=='walls':
                match=any(f['tangent_bounds'][0]-3e-5<=[x,y][1-f['axis']]<=f['tangent_bounds'][1]+3e-5 and f['z_bounds'][0]-3e-5<=z<=f['z_bounds'][1]+3e-5 and record['back']-3e-5<=([x,y][f['axis']]-f['plane'])*f['normal_sign']<=record['front']+3e-5 for f in r['wall_faces'])
            else:
                rows=r['admitted_floor_cells'] if family=='floor' else r['ceiling_faces'];sign=1 if family=='floor' else -1
                match=any(c['rect'][0]-3e-5<=x<=c['rect'][2]+3e-5 and c['rect'][1]-3e-5<=y<=c['rect'][3]+3e-5 and record['back']-3e-5<=(z-c['z'])*sign<=record['front']+3e-5 for c in rows)
            if not match:failures.append([x,y,z])
        assert not failures,(family,len(failures),failures[:3]);checks.append(dict(family=family,vertices=len(o.data.vertices),all_vertices_in_declared_supported_shell=True))
    scene=bpy.context.scene;camera=bpy.data.objects['Larder_SurfaceStudy_R01_upper_window'];scene.camera=camera;bpy.context.view_layer.update();frame=camera.data.view_frame(scene=scene);lo=[min(v[i] for v in frame) for i in (0,1)];hi=[max(v[i] for v in frame) for i in (0,1)];deps=bpy.context.evaluated_depsgraph_get();rays=[]
    for x,y in [(625,400),(660,430),(640,550),(600,350),(560,500),(700,370),(750,500)]:
        direction=Vector((lo[0]+(hi[0]-lo[0])*x/1250,lo[1]+(hi[1]-lo[1])*(1-y/813),frame[0].z));direction=(camera.matrix_world.to_3x3()@direction).normalized();hit,at,normal,index,obj,world=scene.ray_cast(deps,camera.location,direction)
        row=dict(pixel=[x,y],hit=hit)
        if hit:row.update(name=obj.name,plan_at=[at.x+58,55-at.y,at.z],normal=list(normal),polygon=index)
        rays.append(row)
    result=dict(status='INDEPENDENT_DERIVED_REOPEN_VERTEX_SHELL_CHECK_NOT_FULL_TRIANGLE_OR_CLEARANCE_ACCEPTANCE',study_receipt_sha256=sha(study/'receipt.json'),derived_sha256=sha(source),checks=checks,upper_window_diagnostic_rays=rays,polygon_helper_sha256=sha(ROOT/'Tools/WarrensVariantCKit/catacomb_pilot_manifest.py'),tool_sha256=sha(__file__))
    target=study/'independent_reopen_r01.json';assert not target.exists();target.write_text(json.dumps(result,indent=2)+'\n');print('DERIVED_REOPEN_PASS',checks,flush=True);print('DIAGNOSTIC_RAYS',rays,flush=True)


if __name__=='__main__':main()
