"""Full projected triangle coverage, including degenerate bevel edge segments.

Read-only saved study audit. This proves containment in the reviewed veneer
shells; it does not claim collision, lighting, water or gameplay acceptance.
"""
import argparse
import collections
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
TOL=3e-5


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def interval_in_rect(a,b,r):
    lo,hi=0.,1.
    for k in (0,1):
        d=b[k]-a[k]
        if abs(d)<1e-12:
            if not r[k]-TOL<=a[k]<=r[k+2]+TOL:return None
        else:
            x,y=sorted(((r[k]-TOL-a[k])/d,(r[k+2]+TOL-a[k])/d));lo=max(lo,x);hi=min(hi,y)
            if lo>hi:return None
    return lo,hi


def segment_covered(a,b,rects):
    intervals=sorted(v for r in rects if (v:=interval_in_rect(a,b,r)) is not None)
    end=0.
    for lo,hi in intervals:
        if lo>end+1e-7:return False
        end=max(end,hi)
    return end>=1-1e-7


def main():
    import bpy
    p=argparse.ArgumentParser();p.add_argument('--study',required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);folder=(ROOT/a.study).resolve()
    receipt=json.loads((folder/'receipt.json').read_text());derived=folder/'Larder_SurfaceStudy_R01.blend';assert Path(bpy.data.filepath).resolve()==derived and sha(derived)==receipt['derived_sha256']
    mp=ROOT/receipt['manifest'];assert sha(mp)==receipt['manifest_sha256'];r=json.loads(mp.read_text())
    hp=ROOT/'Tools/WarrensVariantCKit/catacomb_pilot_manifest.py';sp=importlib.util.spec_from_file_location('_audit_polygon',hp);g=importlib.util.module_from_spec(sp);sp.loader.exec_module(g)
    checks=[]
    for record in receipt['geometry']:
        family=record['family'];mesh=bpy.data.objects[record['name']].data;mesh.calc_loop_triangles();groups=collections.defaultdict(list)
        if family=='walls':
            for f in r['wall_faces']:groups[f['axis'],f['normal_sign'],f['plane']].append([f['tangent_bounds'][0],f['z_bounds'][0],f['tangent_bounds'][1],f['z_bounds'][1]])
        else:
            for c in r['admitted_floor_cells' if family=='floor' else 'ceiling_faces']:groups[2,1 if family=='floor' else -1,c['z']].append(c['rect'])
        points=[(v.co.x+58,55-v.co.y,v.co.z) for v in mesh.vertices];possible={};projected={}
        for key,rects in groups.items():
            axis,sign,plane=key
            for i,point in enumerate(points):
                if record['back']-TOL<=(point[axis]-plane)*sign<=record['front']+TOL:
                    possible.setdefault(i,set()).add(key)
        failures=[];degenerate=0;max_boundary_area_error=0.
        for tri in mesh.loop_triangles:
            ids=tuple(tri.vertices);keys=set.intersection(*(possible.get(i,set()) for i in ids));ok=False
            for key in keys:
                axis,sign,plane=key;xy=[(points[i][0],points[i][1]) if axis==2 else (points[i][1-axis],points[i][2]) for i in ids]
                lo=[min(p[k] for p in xy) for k in (0,1)];hi=[max(p[k] for p in xy) for k in (0,1)]
                rects=[v for v in groups[key] if all(v[k]<=hi[k]+TOL and v[k+2]>=lo[k]-TOL for k in (0,1))]
                area=g.area(xy)
                if area<1e-9:
                    valid=all(segment_covered(xy[i],xy[(i+1)%3],rects) for i in range(3))
                else:
                    covered=sum(g.area(g.clip(xy,g.rectpoly(v))) for v in rects)
                    perimeter=sum(sum((xy[i][k]-xy[(i+1)%3][k])**2 for k in (0,1))**.5 for i in range(3))
                    boundary_error=abs(covered-area)/max(perimeter,1e-12)
                    # Proven R02 failure: source Z4.6 becomes4.599999904632568
                    # in Blender float32. The232 deficits were <=5.613e-8m
                    # area/perimeter. Bound representation error at1e-7m;
                    # this does not inherit the much larger vertex-shell TOL.
                    valid=abs(covered-area)<=max(1e-10,perimeter*1e-7)
                    if valid:max_boundary_area_error=max(max_boundary_area_error,boundary_error)
                if not valid and area>=1e-9:
                    failures.append(dict(triangle=tri.index,key=key,vertices=[points[i] for i in ids],area=area,covered=covered,delta=area-covered,perimeter=sum(sum((xy[i][k]-xy[(i+1)%3][k])**2 for k in (0,1))**.5 for i in range(3))))
                if valid:
                    degenerate+=area<1e-9;ok=True;break
            if not ok and not any(f['triangle']==tri.index for f in failures[-len(keys or [None]):]):failures.append(dict(triangle=tri.index,vertices=[points[i] for i in ids]))
        if failures:
            out=folder/(family+'_triangle_failure_diagnosis_r01.json');assert not out.exists();out.write_text(json.dumps(dict(family=family,failures=failures),indent=2)+'\n')
            print('TRIANGLE_FAILURE_METRICS',family,len(failures),'max area deficit per perimeter',max(abs(f.get('delta',0))/max(f.get('perimeter',1),1e-12) for f in failures),flush=True)
        assert not failures,(family,len(failures),failures[:1])
        checks.append(dict(family=family,triangles=len(mesh.loop_triangles),degenerate_projected_triangles_segment_checked=degenerate,all_triangles_inside_reviewed_shells_with_float32_boundary_budget=True,area_perimeter_boundary_error_limit_metres=1e-7,max_measured_area_perimeter_boundary_error_metres=max_boundary_area_error))
        print('FULL_TRIANGLE_COVERAGE_PASS',checks[-1],flush=True)
    result=dict(status='FULL_PROJECTED_TRIANGLE_AND_EDGE_COVERAGE_PASS_NOT_NATIVE_ACCEPTANCE',derived_sha256=sha(derived),manifest_sha256=sha(mp),polygon_helper_sha256=sha(hp),tool_sha256=sha(__file__),checks=checks,
                boundary='All actual saved Blender triangles lie within reviewed physical support shells, including bevel edges; no hole bridged by a triangle with merely supported corners. This is prior to FBX export/reimport. Connector/window thickness, full source/library parity, actual native rendering and gameplay remain separate gates.')
    out=folder/'full_triangle_coverage_r02.json';assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print('AUDIT_RECEIPT',sha(out),flush=True)


if __name__=='__main__':main()
