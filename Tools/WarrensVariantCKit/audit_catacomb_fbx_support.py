"""Import actual exported FBX into empty Blender and prove whole-triangle support."""
import argparse,hashlib,importlib.util,json,math,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def segment_rect(a,b,r):
    lo,hi=0.,1.
    for axis in (0,1):
        d=b[axis]-a[axis]
        if abs(d)<1e-12:
            if not r[axis]-2e-5<=a[axis]<=r[axis+2]+2e-5:return None
        else:
            x,y=sorted(((r[axis]-2e-5-a[axis])/d,(r[axis+2]+2e-5-a[axis])/d));lo=max(lo,x);hi=min(hi,y)
            if hi<lo:return None
    return lo,hi
def main():
    import bpy
    parser=argparse.ArgumentParser();parser.add_argument('--export',required=True);parser.add_argument('--study',required=True)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);export=(ROOT/args.export).resolve();study=(ROOT/args.study).resolve()
    assert export.is_relative_to(DOC.resolve()) and study.is_relative_to(DOC.resolve())
    spec=importlib.util.spec_from_file_location('_fbx_support_regions',HERE/'catacomb_pilot_manifest.py');geom=importlib.util.module_from_spec(spec);spec.loader.exec_module(geom)
    exp=read(export/'audit_export.json');manifest=read(DOC/'geometry-r05/room_geometry.json')
    frames=read(study/'receipt.json');assert all(sha(ROOT/k)==v for k,v in frames['guards'].items())
    groups={}
    for f in manifest['wall_faces']:
        key=(f['axis'],f['normal_sign'],f['plane']);groups.setdefault(key,[]).append([f['tangent_bounds'][0],f['z_bounds'][0],f['tangent_bounds'][1],f['z_bounds'][1]])
    floors=[c['rect'] for c in manifest['admitted_floor_cells']];ceilings={}
    for c in manifest['ceiling_faces']:ceilings.setdefault(c['z'],[]).append(c['rect'])
    def covered(triangle,rects):
        lo=[min(v[i] for v in triangle) for i in (0,1)];hi=[max(v[i] for v in triangle) for i in (0,1)]
        nearby=[r for r in rects if r[0]<=hi[0]+2e-5 and r[2]>=lo[0]-2e-5 and r[1]<=hi[1]+2e-5 and r[3]>=lo[1]-2e-5]
        area=geom.area(triangle)
        if area<1e-10:
            for a,b in zip(triangle,triangle[1:]+triangle[:1]):
                intervals=sorted(v for r in nearby if (v:=segment_rect(a,b,r)))
                end=0
                for x,y in intervals:
                    if x>end+1e-5:return False
                    end=max(end,y)
                if end<1-1e-5:return False
            return True
        actual=sum(geom.area(geom.clip(triangle,geom.rectpoly(r))) for r in nearby)
        perimeter=sum(math.dist(a,b) for a,b in zip(triangle,triangle[1:]+triangle[:1]))
        return actual>=area-2e-5*perimeter-1e-8
    results=[]
    for row in exp['exports']:
        path=ROOT/row['file'];assert sha(path)==row['sha256']
        before=set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=str(path),use_image_search=False,colors_type='LINEAR')
        objects=[o for o in bpy.data.objects if o not in before and o.type=='MESH'];assert len(objects)==1
        o=objects[0];mesh=o.data;mesh.calc_loop_triangles();points=[o.matrix_world@v.co for v in mesh.vertices]
        bbox=[[min(v[i] for v in points) for i in range(3)],[max(v[i] for v in points) for i in range(3)]]
        assert max(abs(a-b/100) for aa,bb in zip(bbox,row['blender_bounds_cm']) for a,b in zip(aa,bb))<.0001,(row['kind'],bbox,row['blender_bounds_cm'])
        failures=[];materials={};maximum_uv=0
        for ti,t in enumerate(mesh.loop_triangles):
            p=[[points[i].x-14,76-points[i].y,points[i].z] for i in t.vertices]
            mat=mesh.materials[t.material_index].name;materials[mat]=materials.get(mat,0)+1
            if row['kind']=='walls':
                candidates=[]
                for (axis,sign,plane),rects in groups.items():
                    if all(.0128-2e-5<=(v[axis]-plane)*sign<=.018+2e-5 for v in p):candidates.append((axis,rects))
                okay=any(covered([[v[1-axis],v[2]] for v in p],rs) for axis,rs in candidates)
            elif row['kind']=='floor':
                okay=all(.0088<=v[2]<=.0121 for v in p) and covered([v[:2] for v in p],floors)
            else:
                okay=any(all(.0128-2e-5<=z-v[2]<=.018+2e-5 for v in p) and covered([v[:2] for v in p],rs) for z,rs in ceilings.items())
            if not okay:failures.append(dict(triangle=ti,points=p,material=mat))
        attrs=mesh.color_attributes
        assert attrs and mesh.uv_layers
        color=next(v for v in attrs if v.name=='StoneTint')
        values=[c.color[:3] for c in color.data];minimum=min(min(v) for v in values);maximum=max(max(v) for v in values)
        assert minimum>=0 and maximum<=1.00001,(minimum,maximum)
        results.append(dict(kind=row['kind'],fbx_sha256=row['sha256'],imported_triangles=len(mesh.loop_triangles),material_triangles=materials,
            uv_layers=[u.name for u in mesh.uv_layers],color_attribute=dict(name=color.name,domain=color.domain,minimum=minimum,maximum=maximum,gain_required=1.2),
            complete_triangle_support_pass=not failures,failures=failures[:20],failure_count=len(failures)))
        print('FBX_TRIANGLE_SUPPORT',row['kind'],len(mesh.loop_triangles),'failures',len(failures),flush=True)
    report=dict(status='ACTUAL_FBX_TRIANGLE_SUPPORT_PASS' if all(r['complete_triangle_support_pass'] for r in results) else 'ACTUAL_FBX_TRIANGLE_SUPPORT_FAILED',
        export_receipt_sha256=sha(export/'audit_export.json'),manifest_sha256=sha(DOC/'geometry-r05/room_geometry.json'),results=results,
        proof='Each imported triangle, including bevels and backing sections, is projected into its exact source plane. Its entire projected area is clipped against the disjoint source-supported rectangles; degenerate projections use complete segment-union coverage.20micrometre edge numerical tolerance; no sampling-only interior test.',tool_sha256=sha(__file__))
    out=export/'fbx_triangle_support.json';assert not out.exists();out.write_text(json.dumps(report,indent=2)+'\n')
    assert report['status']=='ACTUAL_FBX_TRIANGLE_SUPPORT_PASS',report
    assert all(sha(ROOT/k)==v for k,v in frames['guards'].items())
    print('FBX_TRIANGLE_SUPPORT_PASS',sha(out),flush=True)
if __name__=='__main__':main()
