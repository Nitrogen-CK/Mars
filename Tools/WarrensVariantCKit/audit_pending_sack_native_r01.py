"""Finite, bijective native import correspondence; records every measured delta."""
import hashlib,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/sack-winding-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    source=DOC/'native_pending_geometry.json';r=json.loads(source.read_text());out=DOC/'native_finite_correspondence.json';assert not out.exists();checks=[]
    for kind in ['source','render']:
        remaining=list(enumerate(r['new'][kind]));maximum=[0.,0.,0.];normal_max=0.;matches=[];counts={0:0,1:0}
        assert len(r['old'][kind])==len(remaining)==320
        for old_id,old in enumerate(r['old'][kind]):
            ids=[2,1,0] if old['material']==0 else [0,1,2];ps=[old['positions'][i] for i in ids];uv=[old['uv'][i] for i in ids];ns=[[-x if old['material']==0 else x for x in old['normals'][i]] for i in ids];options=[]
            for j,new in remaining:
                if new['material']!=old['material']:continue
                for shift in range(3):
                    q=[(k+shift)%3 for k in range(3)]
                    if uv!=[new['uv'][k] for k in q]:continue
                    cost=sum((p[a]-new['positions'][k][a])**2 for p,k in zip(ps,q) for a in range(3));options.append((cost,j,q,new))
            assert options;options.sort(key=lambda x:x[0]);cost,j,q,new=options[0];assert len(options)==1 or options[1][0]>cost
            deltas=[]
            for p,n,k in zip(ps,ns,q):
                delta=[new['positions'][k][a]-p[a] for a in range(3)];deltas.append(delta)
                for a in range(3):maximum[a]=max(maximum[a],abs(delta[a]))
                normal_max=max(normal_max,math.dist(n,new['normals'][k]))
            matches.append(dict(original_triangle=old_id,candidate_triangle=j,material=old['material'],corner_order=q,position_delta_cm=deltas));counts[old['material']]+=1;remaining=[v for v in remaining if v[0]!=j]
        assert not remaining and counts=={0:128,1:192}
        assert maximum==[1.9073486328125e-06,2.1457672119140625e-06,0.0]
        assert normal_max==(9.340306487211477e-07 if kind=='source' else 0.)
        checks.append(dict(lod=kind,bijective_triangles=320,reversed_cloth=128,unchanged_tie_winding=192,all_UV_materials_exact=True,all_Z_exact=True,maximum_XYZ_delta_cm=maximum,maximum_corner_normal_delta=normal_max,matches=matches))
    out.write_text(json.dumps(dict(status='MEASURED_FINITE_NATIVE_IMPORT_XY_REPRESENTATION_CLOTH_REVERSAL_PASS',native_dump_sha256=sha(source),tool_sha256=sha(__file__),checks=checks,boundary='No exact native XY equality claimed. Every corresponding triangle/UV/material is accounted for bijectively after cloth reversal; measured XY differences <=2.146e-6 cm, all Z and render normals exact, source corner normal max9.341e-7. This frozen dump is the finite approval input; no broad geometry tolerance or native appearance acceptance.'),indent=2)+'\n');print('FINITE_NATIVE_AUDIT_PASS',sha(out))
if __name__=='__main__':main()
