"""Oriented native/FBX bijection; explicitly enumerate only exact-zero FBX faces."""
import argparse
import collections
import hashlib
import json
import math
import struct
from pathlib import Path


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def cross_area_squared(triangle):
    a,b,c=triangle['positions']
    x=[b[i]-a[i] for i in range(3)];y=[c[i]-a[i] for i in range(3)]
    cross=[x[1]*y[2]-x[2]*y[1],x[2]*y[0]-x[0]*y[2],x[0]*y[1]-x[1]*y[0]]
    return sum(v*v for v in cross)


def half(value):
    return struct.unpack('e',struct.pack('e',struct.unpack('f',struct.pack('f',value))[0]))[0]


def compare(expected,native):
    expected_rows=expected['triangles'];native_rows=native['triangles']
    zero=[i for i,t in enumerate(expected_rows) if cross_area_squared(t)==0]
    assert len(native_rows)+len(zero)==len(expected_rows),(len(native_rows),len(zero),len(expected_rows))
    zero_set=set(zero)
    def corner_key(p):return tuple(round(v,2) for v in p)
    def key(t):return t['material'],tuple(sorted(corner_key(p) for p in t['positions']))
    buckets=collections.defaultdict(list)
    for i,t in enumerate(expected_rows):
        if i not in zero_set:buckets[key(t)].append((i,t))
    used=set();matches=[];maximum=[0.,0.,0.];maximum_length=0.
    for ni,t in enumerate(native_rows):
        assert cross_area_squared(t)>0
        candidates=buckets[key(t)]
        scored=[]
        for ei,row in candidates:
            for shift in range(3):
                ids=[(k+shift)%3 for k in range(3)]
                if all(t['uv'][k]==[half(v) for v in row['uv'][ids[k]]] for k in range(3)):
                    cost=sum(math.dist(t['positions'][k],row['positions'][ids[k]])**2 for k in range(3))
                    scored.append((cost,ei,shift,row,ids))
        assert scored,('NO_ORIENTED_MATCH',ni,key(t))
        _,ei,shift,row,ids=min(scored,key=lambda v:(v[0],v[1],v[2]))
        assert ei not in used;used.add(ei);candidates.remove((ei,row))
        deltas=[]
        for p,i in zip(t['positions'],ids):
            delta=[p[k]-row['positions'][i][k] for k in range(3)];deltas.append(delta)
            for k in range(3):maximum[k]=max(maximum[k],abs(delta[k]))
            maximum_length=max(maximum_length,math.dist(p,row['positions'][i]))
        matches.append(dict(native_triangle=ni,fbx_triangle=ei,material=t['material'],cyclic_corner_order=ids,position_deltas_cm=deltas))
    assert len(used)==len(native_rows) and not any(buckets.values())
    assert maximum_length < .001
    return dict(status='ALL_NONZERO_FBX_FACES_BIJECTIVE_ORIENTED_NATIVE_CORRESPONDENCE',FBX_triangles=len(expected_rows),native_triangles=len(native_rows),omitted_FBX_faces_exact_zero_area=len(zero),omitted_FBX_face_ids=zero,omitted_material_counts=dict(collections.Counter(expected_rows[i]['material'] for i in zero)),all_positive_area_faces_matched=True,duplicate_multiplicity_preserved=True,exact_cyclic_material_and_half_packed_UV=True,maximum_XYZ_delta_cm=maximum,maximum_corner_displacement_cm=maximum_length,matches=matches,boundary='Only explicitly listed mathematically exact-zero-area source faces may be omitted. Every positive-area native/source face has one cyclic position/material/half-packed UV correspondence, with all position deltas recorded. Quantized keys index candidates only. This does not change source-footprint or collision contracts or prove art appearance. Normal-field parity is not established by this positions/UV/material proof.')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--expected',required=True);parser.add_argument('--native',required=True);parser.add_argument('--out',required=True)
    args=parser.parse_args();ep=Path(args.expected);np=Path(args.native);out=Path(args.out);assert not out.exists()
    result=compare(json.loads(ep.read_text()),json.loads(np.read_text()))
    result.update(expected_sha256=sha(ep),native_sha256=sha(np),tool_sha256=sha(__file__))
    out.write_text(json.dumps(result,separators=(',',':'))+'\n')
    print('NATIVE_CORRESPONDENCE',result['native_triangles'],result['omitted_FBX_faces_exact_zero_area'],result['maximum_corner_displacement_cm'],sha(out))


if __name__=='__main__':main()
