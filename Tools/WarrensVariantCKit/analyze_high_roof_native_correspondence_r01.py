"""Complete oriented native/FBX corner correspondence, measured exceptions only."""
import collections,hashlib,json,math,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/roof-completion-export-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def f32(v):return struct.unpack('f',struct.pack('f',v))[0]
def half(v):return struct.unpack('e',struct.pack('e',f32(v)))[0]
def main():
    ep=DOC/'actual_fbx_expected_geometry.json';np=DOC/'pending_native_geometry.json';e=json.loads(ep.read_text());n=json.loads(np.read_text());out=DOC/'finite_native_correspondence.json';assert not out.exists();expected=e['triangles'];native=n['triangles'];assert len(expected)==len(native)==7356
    def corner_key(p):return tuple(round(v,2) for v in p)
    def key(t):return t['material'],tuple(sorted(corner_key(p) for p in t['positions']))
    buckets=collections.defaultdict(list)
    for i,t in enumerate(expected):buckets[key(t)].append((i,t))
    maximum=[0.,0.,0.];maximum_length=0.;matches=[];used=set();uv_corners=0;counts=collections.Counter()
    for ni,t in enumerate(native):
        candidates=buckets[key(t)];assert candidates
        # Quantized positions index candidates only; every actual delta is
        # retained below, so this is not an equality or support tolerance.
        scored=[]
        for ei,row in candidates:
            km={corner_key(p):i for i,p in enumerate(row['positions'])};assert len(km)==3
            ids=[km[corner_key(p)] for p in t['positions']]
            cost=sum(math.dist(p,row['positions'][i])**2 for p,i in zip(t['positions'],ids));scored.append((cost,ei,row,ids))
        scored.sort(key=lambda v:v[0]);_,ei,row,ids=scored[0];assert len(scored)==1 or scored[1][0]>scored[0][0];assert tuple(ids) in [(0,1,2),(1,2,0),(2,0,1)] and ei not in used;used.add(ei);candidates.remove((ei,row));deltas=[]
        for p,uv,i in zip(t['positions'],t['uv'],ids):
            delta=[p[k]-row['positions'][i][k] for k in range(3)];deltas.append(delta)
            for k in range(3):maximum[k]=max(maximum[k],abs(delta[k]))
            maximum_length=max(maximum_length,math.dist(p,row['positions'][i]));want=[half(v) for v in row['uv'][i]];assert uv==want,(ni,uv,want);uv_corners+=1
        counts[t['material']]+=1;matches.append(dict(native_triangle=ni,fbx_triangle=ei,material=t['material'],cyclic_corner_order=ids,position_deltas_cm=deltas))
    assert len(used)==7356 and not any(buckets.values()) and uv_corners==22068
    result=dict(status='COMPLETE_ORIENTED_FBX_NATIVE_CORRESPONDENCE_MEASURED_REPRESENTATION_EXCEPTION_FOR_REVIEW',expected_file_sha256=sha(ep),native_file_sha256=sha(np),fbx_sha256=e['fbx_sha256'],tool_sha256=sha(__file__),triangles=7356,bijective=True,oriented_cyclic_correspondence=True,duplicate_multiplicity_preserved=True,material_counts=dict(counts),exact_UV_after_declared_float32_half_packing=True,UV_corners=uv_corners,maximum_XYZ_delta_cm=maximum,maximum_corner_displacement_cm=maximum_length,matches=matches,boundary='Original audited FBX footprint proof is unchanged. Native corners correspond bijectively with exact material/orientation/half-packed UV association; every position delta is recorded. This is a specific measured import-representation exception, not an increased footprint tolerance or confirmed common-transform cause. Save and native appearance remain unapproved until independent review.')
    out.write_text(json.dumps(result,indent=2)+'\n');print('COMPLETE_NATIVE_CORRESPONDENCE',maximum,maximum_length,'CM',sha(out))
if __name__=='__main__':main()
